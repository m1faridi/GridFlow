// Flutter's experimental windowing API is intentionally isolated in this file.
// Targets Flutter 3.47.5 stable; internal names may change between SDK releases.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/src/foundation/_features.dart' show isWindowingEnabled;
import 'package:flutter/src/widgets/_window.dart' as windowing;

import 'desktop_controller.dart';
import 'models.dart';
import 'window_widget.dart' show WindowScope;

typedef NativeWindowBuilder = Widget Function(NativeWindowLaunch launch);

/// Initial data for a window in the application's existing Dart isolate.
class NativeWindowLaunch {
  final String windowId;
  final String? appId;
  final String title;
  final String? parentId;
  final Map<String, dynamic> arguments;
  final Color color;
  final Size size;
  final bool isClosable;

  NativeWindowLaunch._(this.windowId, DesktopApp app, this.parentId)
    : appId = app.nativeId,
      title = app.title,
      arguments = Map.unmodifiable(app.nativeArguments),
      color = app.color,
      size = app.nativeWindowSize,
      isClosable = app.isClosable;
}

/// Bootstrap for Flutter's experimental, single-engine desktop windows.
class GridNativeWindows {
  GridNativeWindows._();

  static _NativeRuntime? _runtime;

  static bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Whether Flutter windowing is initialized on a desktop platform.
  static bool get isSupported => _isDesktop && isWindowingEnabled;

  /// Initializes the experimental API bundled with Flutter 3.47.5 stable.
  ///
  /// That SDK's CLI ignores enable-windowing on stable. Opt in here and replace
  /// the unsupported owner installed by an earlier ensureInitialized call.
  /// This changes only this application's runtime, not the SDK or its channel.
  /// Call this before runWidget when using [GridNativeWindowHost] directly.
  static WidgetsBinding ensureInitialized() {
    final binding = WidgetsFlutterBinding.ensureInitialized();
    if (_isDesktop && !isWindowingEnabled) {
      isWindowingEnabled = true;
      try {
        binding.windowingOwner = windowing.createDefaultWindowingOwner();
      } catch (_) {
        isWindowingEnabled = false;
        rethrow;
      }
    }
    return binding;
  }

  /// Runs the launcher and its independent windows in one widget tree.
  ///
  /// Enables the bundled experimental API on desktop. On mobile/web, uses
  /// Flutter's normal runApp.
  /// To share inherited state, instead call runWidget with providers above a
  /// [GridNativeWindowHost]. Providers inside [launcher] belong to that view.
  static void run(
    Widget launcher, {
    String title = 'GridFlow',
    Size size = const Size(1440, 900),
    Map<String, NativeWindowBuilder> builders = const {},
    Widget Function(Widget child)? appBuilder,
  }) {
    ensureInitialized();
    if (!isSupported) {
      if (WidgetsBinding.instance.platformDispatcher.implicitView == null) {
        throw StateError(
          'No implicit view is available on this platform. Use a supported '
          'desktop runner or provide an implicit view for runApp.',
        );
      }
      runApp(launcher);
      return;
    }
    runWidget(
      GridNativeWindowHost(
        title: title,
        size: size,
        builders: builders,
        appBuilder: appBuilder,
        launcher: launcher,
      ),
    );
  }

  static Future<dynamic> openApp(DesktopApp app, {String? parentId}) {
    final runtime = _runtime;
    if (runtime == null) {
      return Future.error(
        StateError(
          'Call GridNativeWindows.run or mount GridNativeWindowHost first.',
        ),
      );
    }
    return runtime.openApp(app, parentId: parentId);
  }

  static bool ownsWindow(String id) => _runtime?.ownsWindow(id) ?? false;

  static void closeWindow(String id, [dynamic result]) {
    _runtime?.closeWindow(id, result);
  }
}

/// Root used with runWidget, outside any MaterialApp or View.
///
/// All native views inherit providers placed above this widget. Each child has
/// its own MaterialApp by default; [appBuilder] can customize that wrapper.
/// Removing a GridDesktop does not close its native windows. Removing this host
/// releases every window and completes pending results with null.
class GridNativeWindowHost extends StatefulWidget {
  final Widget launcher;
  final String title;
  final Size size;
  final Map<String, NativeWindowBuilder> builders;
  final Widget Function(Widget child)? appBuilder;

  const GridNativeWindowHost({
    super.key,
    required this.launcher,
    this.title = 'GridFlow',
    this.size = const Size(1440, 900),
    this.builders = const {},
    this.appBuilder,
  });

  @override
  State<GridNativeWindowHost> createState() => _GridNativeWindowHostState();
}

class _GridNativeWindowHostState extends State<GridNativeWindowHost> {
  _NativeRuntime? _ownedRuntime;
  _NativeRuntime get _runtime => _ownedRuntime!;

  @override
  void initState() {
    super.initState();
    GridNativeWindows.ensureInitialized();
    if (!GridNativeWindows.isSupported) {
      throw StateError(
        'GridNativeWindowHost requires a supported desktop platform.',
      );
    }
    if (GridNativeWindows._runtime != null) {
      throw StateError(
        'Only one GridNativeWindowHost may be mounted at a time.',
      );
    }
    _ownedRuntime = _NativeRuntime(widget.builders, widget.appBuilder);
    _runtime.addLauncher(widget.launcher, widget.title, widget.size);
    GridNativeWindows._runtime = _runtime;
  }

  @override
  void didUpdateWidget(GridNativeWindowHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _runtime.builders = Map.unmodifiable(widget.builders);
    _runtime.appBuilder = widget.appBuilder;
    _runtime.updateLauncher(
      widget.launcher,
      widget.title,
      widget.size == oldWidget.size ? null : widget.size,
    );
  }

  @override
  void dispose() {
    if (identical(GridNativeWindows._runtime, _ownedRuntime)) {
      GridNativeWindows._runtime = null;
    }
    _ownedRuntime?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _runtime,
    builder: (context, _) => ViewCollection(
      views: [
        for (final entry in _runtime.windows)
          if (!entry.closing)
            windowing.RegularWindow(
              key: ValueKey(entry.id),
              controller: entry.controller,
              child: entry.child,
            ),
      ],
    ),
  );
}

class _NativeWindow {
  final String id;
  final bool isClosable;
  final Completer<dynamic>? result;
  late final windowing.RegularWindowController controller;
  Widget child;
  bool closing = false;
  bool destroyed = false;
  bool released = false;
  dynamic closeResult;

  _NativeWindow(this.id, this.child, {this.isClosable = true, this.result});
}

class _WindowDelegate with windowing.RegularWindowControllerDelegate {
  final VoidCallback onClose;
  final VoidCallback onDestroyed;

  _WindowDelegate({required this.onClose, required this.onDestroyed});

  @override
  void onWindowCloseRequested(windowing.RegularWindowController controller) =>
      onClose();

  @override
  void onWindowDestroyed() => onDestroyed();
}

class _NativeRuntime extends ChangeNotifier implements DesktopController {
  Map<String, NativeWindowBuilder> builders;
  Widget Function(Widget child)? appBuilder;
  final Map<String, _NativeWindow> _windows = {};
  int _nextId = 0;
  bool _disposed = false;
  bool _notificationScheduled = false;
  bool _exitRequested = false;

  _NativeRuntime(Map<String, NativeWindowBuilder> builders, this.appBuilder)
    : builders = Map.unmodifiable(builders);

  Iterable<_NativeWindow> get windows => _windows.values;

  void _validateSize(Size size) {
    if (!size.isFinite || size.width < 200 || size.height < 150) {
      throw ArgumentError(
        'Native window size must be finite and at least 200 × 150.',
      );
    }
  }

  void _create(_NativeWindow entry, String title, Size size) {
    _validateSize(size);
    entry.controller = windowing.RegularWindowController(
      title: title,
      size: size,
      constraints: const BoxConstraints(minWidth: 200, minHeight: 150),
      delegate: _WindowDelegate(
        onClose: () {
          if (entry.isClosable) closeWindow(entry.id);
        },
        onDestroyed: () => _onDestroyed(entry),
      ),
    );
    _windows[entry.id] = entry;
  }

  void addLauncher(Widget child, String title, Size size) {
    _create(_NativeWindow('grid-flow-launcher', child), title, size);
  }

  void updateLauncher(Widget child, String title, Size? size) {
    final entry = _windows['grid-flow-launcher'];
    if (entry == null || entry.closing) return;
    if (size != null) {
      _validateSize(size);
      entry.controller.setSize(size);
    }
    entry.child = child;
    if (entry.controller.title != title) entry.controller.setTitle(title);
  }

  bool ownsWindow(String id) => _windows.containsKey(id);

  @override
  Future<dynamic> openApp(DesktopApp app, {String? parentId}) {
    if (_disposed || _exitRequested) return Future.value(null);
    try {
      _validateSize(app.nativeWindowSize);
      final builder = app.nativeId == null ? null : builders[app.nativeId];
      if (app.nativeId != null && builder == null) {
        throw ArgumentError(
          'No native builder registered for "${app.nativeId}".',
        );
      }
      final id = 'grid-flow-window-${_nextId++}';
      final launch = NativeWindowLaunch._(id, app, parentId);
      final content =
          builder?.call(launch) ??
          app.contentBuilder?.call(id) ??
          Center(child: Text(app.title));
      final host = DesktopProvider(
        controller: this,
        child: WindowScope(
          windowId: id,
          child: Scaffold(body: content),
        ),
      );
      final child =
          appBuilder?.call(host) ??
          MaterialApp(
            debugShowCheckedModeBanner: false,
            title: app.title,
            theme: ThemeData(colorSchemeSeed: app.color),
            home: host,
          );
      final entry = _NativeWindow(
        id,
        child,
        isClosable: app.isClosable,
        result: Completer<dynamic>(),
      );
      _create(entry, app.title, app.nativeWindowSize);
      _changed();
      return entry.result!.future;
    } catch (error, stack) {
      return Future.error(error, stack);
    }
  }

  @override
  void closeWindow(String id, [dynamic result]) {
    final entry = _windows[id];
    if (_disposed || entry == null || entry.closing) return;
    entry.closing = true;
    entry.closeResult = result;
    _changed();
    // Detach the View before destroying its native surface.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      _afterFrame(() => _afterFrame(() => _destroy(entry)));
    } else {
      _afterFrame(() => _destroy(entry));
    }
  }

  void _destroy(_NativeWindow entry) {
    if (!entry.destroyed) entry.controller.destroy();
  }

  void _onDestroyed(_NativeWindow entry) {
    if (entry.destroyed) return;
    entry.destroyed = true;
    _windows.remove(entry.id);
    if (!(entry.result?.isCompleted ?? true)) {
      entry.result!.complete(entry.closeResult);
    }
    if (!_disposed) _changed();
    // The last native view may no longer deliver frames. Do not wait for a
    // frame to request exit, and coalesce simultaneous window destruction.
    scheduleMicrotask(() {
      if (!_disposed && !_exitRequested && _windows.isEmpty) {
        _exitRequested = true;
        unawaited(
          ServicesBinding.instance.exitApplication(AppExitType.required),
        );
      }
    });
    _afterFrame(() {
      if (!entry.released) {
        entry.released = true;
        entry.controller.dispose();
      }
    });
  }

  void _changed() {
    if (_disposed) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_notificationScheduled) return;
      _notificationScheduled = true;
      _afterFrame(() {
        _notificationScheduled = false;
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  void _afterFrame(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final entry in _windows.values.toList()) {
      if (!(entry.result?.isCompleted ?? true)) entry.result!.complete(null);
      _afterFrame(() {
        if (!entry.destroyed) entry.controller.destroy();
      });
    }
    super.dispose();
  }
}
