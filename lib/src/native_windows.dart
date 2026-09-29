import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_controller.dart';
import 'models.dart';
import 'window_widget.dart' show WindowScope;

typedef NativeWindowBuilder = Widget Function(NativeWindowLaunch launch);

/// Initial data available in the new window's independent Flutter engine.
class NativeWindowLaunch {
  final String windowId;
  final String? appId;
  final String title;
  final String? parentId;
  final Map<String, dynamic> arguments;
  final Color color;
  final Size size;
  final bool isClosable;
  final String _ownerId;
  final String _requestId;

  NativeWindowLaunch._(this.windowId, Map<String, dynamic> data)
    : appId = data['appId'] as String?,
      title = data['title'] as String,
      parentId = data['parentId'] as String?,
      arguments = Map.unmodifiable(data['arguments'] as Map<String, dynamic>),
      color = Color(data['color'] as int),
      size = Size(
        (data['width'] as num).toDouble(),
        (data['height'] as num).toDouble(),
      ),
      isClosable = data['isClosable'] as bool,
      _ownerId = data['ownerId'] as String,
      _requestId = data['requestId'] as String;
}

/// Opt-in bootstrap for independent macOS and Windows windows.
///
/// Call [initialize] in every engine's main, before runApp. If it returns a
/// widget, run that widget instead of the launcher. Register the same builders
/// on every launch; closures and inherited state cannot cross engine boundaries.
class GridNativeWindows {
  GridNativeWindows._();

  static _NativeRuntime? _runtime;

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  /// Returns null for the main window and unsupported platforms. [appBuilder]
  /// can supply the MaterialApp, theme, localization and providers for children.
  static Future<Widget?> initialize({
    Map<String, NativeWindowBuilder> builders = const {},
    Widget Function(Widget child)? appBuilder,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (!isSupported) return null;
    if (_runtime != null) {
      throw StateError(
        'GridNativeWindows.initialize must be called once per engine.',
      );
    }
    final current = await WindowController.fromCurrentEngine();
    Map<String, dynamic>? data;
    if (current.arguments.isNotEmpty) {
      final decoded = jsonDecode(current.arguments);
      if (decoded is Map<String, dynamic> && decoded['gridFlow'] == 1) {
        data = decoded;
      }
    }
    final launch = data == null
        ? null
        : NativeWindowLaunch._(current.windowId, data);
    final runtime = _NativeRuntime(current, Map.unmodifiable(builders), launch);
    await runtime.initialize();
    _runtime = runtime;
    if (launch == null) return null;

    try {
      final builder = launch.appId == null ? null : builders[launch.appId];
      if (launch.appId != null && builder == null) {
        throw StateError('No native builder registered for "${launch.appId}".');
      }
      final content =
          builder?.call(launch) ?? Center(child: Text(launch.title));
      final host = _NativeWindowHost(runtime: runtime, child: content);
      return appBuilder?.call(host) ??
          MaterialApp(
            debugShowCheckedModeBanner: false,
            title: launch.title,
            theme: ThemeData(colorSchemeSeed: launch.color),
            home: host,
          );
    } catch (error, stack) {
      await runtime.failLaunch(error);
      Error.throwWithStackTrace(error, stack);
    }
  }

  static Future<dynamic> openApp(DesktopApp app, {String? parentId}) {
    final runtime = _runtime;
    if (runtime == null) {
      return Future.error(
        StateError(
          'Call GridNativeWindows.initialize in main before enabling useNativeWindows.',
        ),
      );
    }
    return runtime.openApp(app, parentId: parentId);
  }

  static bool ownsWindow(String id) => _runtime?.ownsWindow(id) ?? false;

  static void closeWindow(String id, [dynamic result]) {
    _runtime?.closeWindow(id, result);
  }

  /// Releases the Dart-side test runtime without changing any native windows.
  @visibleForTesting
  static Future<void> resetForTesting() async {
    final runtime = _runtime;
    _runtime = null;
    await runtime?.dispose();
  }
}

WindowMethodChannel _channelFor(String windowId) => WindowMethodChannel(
  'grid_flow/windows/$windowId',
  mode: ChannelMode.unidirectional,
);

void _reportNativeError(Object error, StackTrace stack) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'grid_flow',
      context: ErrorDescription('managing an independent desktop window'),
    ),
  );
}

class _PendingWindow {
  final result = Completer<dynamic>();
  String? windowId;
}

class _NativeRuntime with WindowListener implements DesktopController {
  final WindowController current;
  final Map<String, NativeWindowBuilder> builders;
  final NativeWindowLaunch? launch;
  final Map<String, _PendingWindow> _pending = {};
  StreamSubscription<void>? _windowEvents;
  int _nextRequest = 0;
  int _listRevision = 0;
  bool _closing = false;
  bool _disposed = false;
  bool _launcherHidden = false;

  _NativeRuntime(this.current, this.builders, this.launch);

  Future<void> initialize() async {
    await windowManager.ensureInitialized();
    await _channelFor(current.windowId).setMethodCallHandler(_handleCall);
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    _windowEvents = onWindowsChanged.listen((_) {
      unawaited(_refreshWindows().catchError(_reportNativeError));
    });
  }

  bool ownsWindow(String id) =>
      id == current.windowId ||
      _pending.values.any((pending) => pending.windowId == id);

  @override
  Future<dynamic> openApp(DesktopApp app, {String? parentId}) {
    if (_disposed || _closing) return Future.value(null);
    if ((app.contentBuilder != null && app.nativeId == null) ||
        (app.nativeId != null && !builders.containsKey(app.nativeId))) {
      return Future.error(
        ArgumentError(
          'Register a native builder and set DesktopApp.nativeId for "${app.title}".',
        ),
      );
    }
    if (!app.nativeWindowSize.isFinite ||
        app.nativeWindowSize.width < 200 ||
        app.nativeWindowSize.height < 150) {
      return Future.error(
        ArgumentError('nativeWindowSize must be at least 200 × 150.'),
      );
    }
    final requestId = '${current.windowId}:${_nextRequest++}';
    final String encoded;
    try {
      encoded = jsonEncode({
        'gridFlow': 1,
        'ownerId': current.windowId,
        'requestId': requestId,
        'appId': app.nativeId,
        'parentId': parentId,
        'title': app.title,
        'color': app.color.toARGB32(),
        'arguments': app.nativeArguments,
        'width': app.nativeWindowSize.width,
        'height': app.nativeWindowSize.height,
        'isClosable': app.isClosable,
      });
    } catch (error, stack) {
      return Future.error(error, stack);
    }
    final pending = _PendingWindow();
    _pending[requestId] = pending;
    unawaited(_create(requestId, encoded, pending));
    return pending.result.future;
  }

  Future<void> _create(
    String requestId,
    String encoded,
    _PendingWindow pending,
  ) async {
    try {
      final window = await WindowController.create(
        WindowConfiguration(arguments: encoded, hiddenAtLaunch: true),
      );
      pending.windowId = window.windowId;
      // A child can close before create() returns; reconcile that race too.
      await _refreshWindows();
    } catch (error, stack) {
      if (_pending.remove(requestId) != null && !pending.result.isCompleted) {
        pending.result.completeError(error, stack);
      }
    }
  }

  Future<dynamic> _handleCall(MethodCall call) async {
    switch (call.method) {
      case 'result':
      case 'launchError':
        final data = Map<String, dynamic>.from(call.arguments as Map);
        final pending = _pending.remove(data['requestId']);
        if (pending != null && !pending.result.isCompleted) {
          if (call.method == 'launchError') {
            pending.result.completeError(StateError(data['error'] as String));
          } else {
            pending.result.complete(data['result']);
          }
        }
        return null;
      case 'close':
        // Acknowledge the request before destroying the receiving engine.
        scheduleMicrotask(
          () => unawaited(
            _closeSelf(call.arguments).catchError(_reportNativeError),
          ),
        );
        return null;
      default:
        throw MissingPluginException('Unknown GridFlow method: ${call.method}');
    }
  }

  Future<void> _refreshWindows() async {
    if (_disposed) return;
    final revision = ++_listRevision;
    final all = await WindowController.getAll();
    if (_disposed || revision != _listRevision) return;
    final ids = all.map((window) => window.windowId).toSet();
    for (final entry in _pending.entries.toList()) {
      final id = entry.value.windowId;
      if (id != null && !ids.contains(id)) {
        _pending.remove(entry.key);
        if (!entry.value.result.isCompleted) entry.value.result.complete(null);
      }
    }
    if (_launcherHidden &&
        _pending.isEmpty &&
        !ids.any((id) => id != current.windowId)) {
      await _closeSelf(null);
    }
  }

  @override
  void closeWindow(String id, [dynamic result]) {
    // Check serializability before any window is closed.
    const StandardMethodCodec().encodeSuccessEnvelope(result);
    if (id == current.windowId) {
      unawaited(_closeSelf(result).catchError(_reportNativeError));
    } else {
      unawaited(
        _channelFor(
          id,
        ).invokeMethod<void>('close', result).catchError(_reportNativeError),
      );
    }
  }

  @override
  void onWindowClose() {
    if (launch != null) {
      if (launch!.isClosable) closeWindow(current.windowId);
    } else {
      unawaited(_closeLauncher().catchError(_reportNativeError));
    }
  }

  Future<void> _closeLauncher() async {
    final all = await WindowController.getAll();
    if (_pending.isNotEmpty ||
        all.any((window) => window.windowId != current.windowId)) {
      // Retain the launcher engine while child windows are alive, including on
      // Windows where destroying the runner's main window quits the process.
      _launcherHidden = true;
      await windowManager.hide();
      await _refreshWindows();
    } else {
      await _closeSelf(null);
    }
  }

  Future<void> _notifyOwner(String method, Map<String, dynamic> data) async {
    if (launch == null) return;
    try {
      await _channelFor(launch!._ownerId)
          .invokeMethod<void>(method, {
            'requestId': launch!._requestId,
            ...data,
          })
          .timeout(const Duration(seconds: 3));
    } on WindowChannelException {
      // The opener may have closed. Its child remains an independent window.
    } on TimeoutException {
      // A busy or unavailable opener must not prevent native window dismissal.
    }
  }

  Future<void> _closeSelf(dynamic result) async {
    if (_closing || _disposed) return;
    _closing = true;
    try {
      await _notifyOwner('result', {'result': result});
      await windowManager.setClosable(true);
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } catch (_) {
      _closing = false;
      rethrow;
    }
  }

  Future<void> failLaunch(Object error) async {
    await _notifyOwner('launchError', {'error': error.toString()});
    await _closeSelf(null);
  }

  Future<void> showChild() async {
    final config = launch!;
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: config.size,
        minimumSize: const Size(200, 150),
        center: true,
        title: config.title,
        titleBarStyle: TitleBarStyle.normal,
        windowButtonVisibility: true,
        skipTaskbar: false,
      ),
    );
    await windowManager.setClosable(config.isClosable);
    await current.show();
    await windowManager.focus();
  }

  Future<void> dispose() async {
    _disposed = true;
    windowManager.removeListener(this);
    await _windowEvents?.cancel();
    await _channelFor(current.windowId).setMethodCallHandler(null);
    for (final pending in _pending.values) {
      if (!pending.result.isCompleted) pending.result.complete(null);
    }
    _pending.clear();
  }
}

class _NativeWindowHost extends StatefulWidget {
  final _NativeRuntime runtime;
  final Widget child;

  const _NativeWindowHost({required this.runtime, required this.child});

  @override
  State<_NativeWindowHost> createState() => _NativeWindowHostState();
}

class _NativeWindowHostState extends State<_NativeWindowHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await widget.runtime.showChild();
      } catch (error, stack) {
        _reportNativeError(error, stack);
        await widget.runtime.failLaunch(error);
      }
    });
  }

  @override
  Widget build(BuildContext context) => DesktopProvider(
    controller: widget.runtime,
    child: WindowScope(
      windowId: widget.runtime.current.windowId,
      child: Scaffold(body: widget.child),
    ),
  );
}
