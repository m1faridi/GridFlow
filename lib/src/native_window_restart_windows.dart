// Adapter for Flutter 3.47.5's experimental Windows window controllers.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member
import 'dart:ffi' hide Size;
import 'dart:ui' show FlutterView;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/src/widgets/_window.dart' as windowing;
import 'package:flutter/src/widgets/_window_win32.dart' as win32;

import 'native_dialog_policy.dart';

bool _prepared = false;
_RestartLauncher? _previousLauncher;

win32.WindowingOwnerWin32? _windowsOwner(windowing.WindowingOwner owner) {
  if (!kDebugMode || !Platform.isWindows) return null;
  if (owner is GridDialogWindowingOwner) owner = owner.delegate;
  return owner is win32.WindowingOwnerWin32 ? owner : null;
}

/// Reattach the launcher after hot restart and retire only GridFlow's children.
/// Native HWND properties outlive the Dart isolate; Dart statics do not.
void prepareNativeWindowRestart(windowing.WindowingOwner owner) {
  final windowsOwner = _windowsOwner(owner);
  if (windowsOwner == null || _prepared) return;
  _prepared = true;
  final api = _WindowApi(windowsOwner.allocator);
  final views = PlatformDispatcher.instance.views.toList();
  for (final view in views) {
    final handle = api.handle(view);
    if (handle == nullptr) continue;
    final role = api.role(handle);
    if (role == 1) {
      final forwarding = _RestartDelegate();
      final controller = _ReattachedController(
        existing: view,
        owner: windowsOwner,
        delegate: forwarding,
        size: const Size(200, 150),
        constraints: const BoxConstraints(),
        title: '',
      );
      _previousLauncher = _RestartLauncher(controller, forwarding);
    } else if (role == 2) {
      // Install a delegate in this isolate before destroying the old window.
      final controller = _ReattachedController(
        existing: view,
        owner: windowsOwner,
        delegate: windowing.RegularWindowControllerDelegate(),
        size: const Size(200, 150),
        constraints: const BoxConstraints(),
        title: '',
      );
      controller.destroy();
      controller.dispose();
    }
  }
}

windowing.RegularWindowController createGridRegularWindow({
  required bool launcher,
  required Size size,
  required BoxConstraints constraints,
  required String title,
  required windowing.RegularWindowControllerDelegate delegate,
}) {
  final owner = _windowsOwner(WidgetsBinding.instance.windowingOwner);
  if (owner == null) {
    return windowing.RegularWindowController(
      size: size,
      constraints: constraints,
      title: title,
      delegate: delegate,
    );
  }
  final previous = launcher ? _previousLauncher : null;
  if (launcher) _previousLauncher = null;
  final controller = previous == null
      ? win32.RegularWindowControllerWin32(
          owner: owner,
          delegate: delegate,
          size: size,
          constraints: constraints,
          title: title,
          resizable: true,
        )
      : previous.controller;
  if (previous != null) previous.forwarding.target = delegate;
  final api = _WindowApi(owner.allocator);
  api.setRole(controller.windowHandle, launcher ? 1 : 2);
  if (previous != null) {
    controller.setTitle(title);
    controller.setConstraints(constraints);
  }
  return controller;
}

class _RestartLauncher {
  _RestartLauncher(this.controller, this.forwarding);
  final _ReattachedController controller;
  final _RestartDelegate forwarding;
}

class _RestartDelegate with windowing.RegularWindowControllerDelegate {
  windowing.RegularWindowControllerDelegate? target;
  @override
  void onWindowCloseRequested(windowing.RegularWindowController controller) =>
      target?.onWindowCloseRequested(controller);
  @override
  void onWindowDestroyed() => target?.onWindowDestroyed();
}

/// The SDK does not expose an adoption constructor. Let its constructor install
/// the current isolate's message handler, then redirect that handler to the
/// retained view and release the unused temporary view. Keeping the original
/// launcher also preserves its HWND, position and size across hot restart.
class _ReattachedController extends win32.RegularWindowControllerWin32 {
  _ReattachedController({
    required FlutterView existing,
    required win32.WindowingOwnerWin32 owner,
    required super.delegate,
    required super.size,
    required super.constraints,
    required super.title,
  }) : super(owner: owner, resizable: true) {
    final temporaryHandle = windowHandle;
    rootView = existing;
    _WindowApi(owner.allocator).destroy(temporaryHandle);
  }

  late FlutterView _activeView;

  @override
  FlutterView get rootView => _activeView;

  @override
  set rootView(FlutterView view) => _activeView = view;
}

class _WindowApi {
  _WindowApi(this.allocator);
  final Allocator allocator;
  static final _engine = DynamicLibrary.open('flutter_windows.dll');
  static final _user32 = DynamicLibrary.open('user32.dll');
  static final _handle = _engine
      .lookupFunction<
        Pointer<Void> Function(Int64, Int64),
        Pointer<Void> Function(int, int)
      >('InternalFlutterWindows_WindowManager_GetTopLevelWindowHandle');
  static final _destroy = _engine
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('InternalFlutterWindows_WindowManager_OnDestroyWindow');
  static final _getProp = _user32
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Pointer<Uint16>),
        Pointer<Void> Function(Pointer<Void>, Pointer<Uint16>)
      >('GetPropW');
  static final _setProp = _user32
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Uint16>, Pointer<Void>),
        int Function(Pointer<Void>, Pointer<Uint16>, Pointer<Void>)
      >('SetPropW');

  Pointer<Void> handle(FlutterView view) =>
      _handle(PlatformDispatcher.instance.engineId!, view.viewId);
  void destroy(Pointer<Void> handle) => _destroy(handle);

  T _withKey<T>(T Function(Pointer<Uint16>) action) {
    const name = 'GridFlow.RegularWindow.RestartRole.v1';
    final key = allocator<Uint16>(name.length + 1);
    try {
      key.asTypedList(name.length + 1).setAll(0, [...name.codeUnits, 0]);
      return action(key);
    } finally {
      allocator.free(key);
    }
  }

  int role(Pointer<Void> handle) =>
      _withKey((key) => _getProp(handle, key).address);
  void setRole(Pointer<Void> handle, int role) {
    final success = _withKey(
      (key) => _setProp(handle, key, Pointer<Void>.fromAddress(role)),
    );
    if (success == 0) {
      throw StateError('Could not mark a GridFlow native window.');
    }
  }
}
