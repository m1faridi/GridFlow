// Adapter for Flutter 3.47.5's experimental macOS window controllers.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member
import 'dart:ffi' hide Size;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/src/widgets/_window.dart' as windowing;
import 'package:flutter/src/widgets/_window_macos.dart' as macos;

import 'native_window_placement.dart';

/// Flutter closes macOS windows before restarting the Dart isolate. Keep the
/// launcher NSWindow alive natively so its final frame is available to the next
/// isolate, without retaining Dart callbacks or changing cold-start placement.
void restoreGridLauncherAfterRestartMacOS(
  windowing.RegularWindowController controller,
) {
  if (!kDebugMode || controller is! macos.RegularWindowControllerMacOS) return;
  final engineId = WidgetsBinding.instance.platformDispatcher.engineId;
  if (engineId == null) return;
  _AppKitPlacementApi().restoreLauncherFrame(controller.windowHandle, engineId);
}

void positionGridWindowToRightMacOS(
  windowing.RegularWindowController controller, {
  windowing.RegularWindowController? relativeTo,
}) {
  if (controller is! macos.RegularWindowControllerMacOS ||
      relativeTo is! macos.RegularWindowControllerMacOS) {
    return;
  }
  final handle = controller.windowHandle;
  final anchorHandle = relativeTo.windowHandle;
  if (handle == nullptr || anchorHandle == nullptr) return;
  final api = _AppKitPlacementApi();
  final screen = api.screen(anchorHandle);
  if (screen == nullptr) return;
  final work = api.rect(screen, _AppKitPlacementApi.visibleFrameSelector);
  final frame = api.rect(handle, _AppKitPlacementApi.frameSelector);
  final content = controller.contentSize;
  final fittedSize = Size(
    math.min(
      content.width,
      math.max(200, work.width - (frame.width - content.width)),
    ),
    math.min(
      content.height,
      math.max(150, work.height - (frame.height - content.height)),
    ),
  );
  if (fittedSize != content) controller.setSize(fittedSize);
  final anchor = api.rect(anchorHandle, _AppKitPlacementApi.frameSelector);
  // AppKit uses logical points with Y increasing upwards, including on Retina
  // and secondary screens. Reflect Y to reuse the downward placement policy.
  final origin = nativeWindowRightOrigin(
    anchor: anchor.toDownwardRect(),
    workArea: work.toDownwardRect(),
    scale: 1,
  );
  api.setTopLeft(handle, Offset(origin.dx, -origin.dy));
}

final class _AppKitPoint extends Struct {
  @Double()
  external double x;
  @Double()
  external double y;
}

final class _AppKitRect extends Struct {
  @Double()
  external double x;
  @Double()
  external double y;
  @Double()
  external double width;
  @Double()
  external double height;

  Rect toDownwardRect() => Rect.fromLTWH(x, -y - height, width, height);
}

class _AppKitPlacementApi {
  static final _objc = DynamicLibrary.open('/usr/lib/libobjc.A.dylib');
  static final _libc = DynamicLibrary.process();
  static final _malloc = _libc
      .lookupFunction<
        Pointer<Void> Function(IntPtr),
        Pointer<Void> Function(int)
      >('malloc');
  static final _free = _libc
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('free');
  static final _registerName = _objc
      .lookupFunction<
        Pointer<Void> Function(Pointer<Uint8>),
        Pointer<Void> Function(Pointer<Uint8>)
      >('sel_registerName');
  static final _objectGetClass = _objc
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>)
      >('object_getClass');
  static final _getClass = _objc
      .lookupFunction<
        Pointer<Void> Function(Pointer<Uint8>),
        Pointer<Void> Function(Pointer<Uint8>)
      >('objc_getClass');
  static final _getAssociatedObject = _objc
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>, Pointer<Void>)
      >('objc_getAssociatedObject');
  static final _setAssociatedObject = _objc
      .lookupFunction<
        Void Function(Pointer<Void>, Pointer<Void>, Pointer<Void>, UintPtr),
        void Function(Pointer<Void>, Pointer<Void>, Pointer<Void>, int)
      >('objc_setAssociatedObject');
  static final _getImplementation = _objc
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>, Pointer<Void>)
      >('class_getMethodImplementation');

  static final frameSelector = _selector('frame');
  static final visibleFrameSelector = _selector('visibleFrame');
  static final _screenSelector = _selector('screen');
  static final _topLeftSelector = _selector('setFrameTopLeftPoint:');
  static final _setFrameSelector = _selector('setFrame:display:');

  static Pointer<Void> _selector(String name) => _withName(name, _registerName);

  static Pointer<Void> _withName(
    String name,
    Pointer<Void> Function(Pointer<Uint8>) callback,
  ) {
    final bytes = _malloc(name.length + 1).cast<Uint8>();
    if (bytes == nullptr) {
      throw StateError('Could not allocate AppKit selector.');
    }
    try {
      bytes.asTypedList(name.length + 1).setAll(0, [...name.codeUnits, 0]);
      return callback(bytes);
    } finally {
      _free(bytes.cast());
    }
  }

  // Call the typed method implementation directly so Dart FFI handles struct
  // returns on both Apple Silicon and Intel, without objc_msgSend_stret rules.
  Pointer<Void> _implementation(Pointer<Void> object, Pointer<Void> selector) =>
      _getImplementation(_objectGetClass(object), selector);

  Pointer<Void> _object(Pointer<Void> receiver, Pointer<Void> selector) =>
      _implementation(receiver, selector)
          .cast<
            NativeFunction<Pointer<Void> Function(Pointer<Void>, Pointer<Void>)>
          >()
          .asFunction<Pointer<Void> Function(Pointer<Void>, Pointer<Void>)>()(
        receiver,
        selector,
      );

  void restoreLauncherFrame(Pointer<Void> window, int engineId) {
    if (window == nullptr) return;
    final app = _object(
      _withName('NSApplication', _getClass),
      _selector('sharedApplication'),
    );
    // Objective-C selector identities and associations survive Dart restart.
    // Scope this to the engine so a different engine cannot inherit its frame.
    final key = _selector('gridFlowLauncherFrame$engineId');
    final previous = _getAssociatedObject(app, key);
    if (previous != nullptr && previous != window) {
      final frame = rect(previous, frameSelector);
      _implementation(window, _setFrameSelector)
          .cast<
            NativeFunction<
              Void Function(Pointer<Void>, Pointer<Void>, _AppKitRect, Bool)
            >
          >()
          .asFunction<
            void Function(Pointer<Void>, Pointer<Void>, _AppKitRect, bool)
          >()(window, _setFrameSelector, frame, false);
    }
    // RETAIN_NONATOMIC: keep just the current launcher. Replacing it releases
    // the previous closed window; no history or preferences accumulate.
    _setAssociatedObject(app, key, window, 1);
  }

  _AppKitRect rect(Pointer<Void> object, Pointer<Void> selector) =>
      _implementation(object, selector)
          .cast<
            NativeFunction<_AppKitRect Function(Pointer<Void>, Pointer<Void>)>
          >()
          .asFunction<_AppKitRect Function(Pointer<Void>, Pointer<Void>)>()(
        object,
        selector,
      );

  Pointer<Void> screen(Pointer<Void> window) =>
      _implementation(window, _screenSelector)
          .cast<
            NativeFunction<Pointer<Void> Function(Pointer<Void>, Pointer<Void>)>
          >()
          .asFunction<Pointer<Void> Function(Pointer<Void>, Pointer<Void>)>()(
        window,
        _screenSelector,
      );

  void setTopLeft(Pointer<Void> window, Offset origin) {
    final point = Struct.create<_AppKitPoint>()
      ..x = origin.dx
      ..y = origin.dy;
    _implementation(window, _topLeftSelector)
        .cast<
          NativeFunction<
            Void Function(Pointer<Void>, Pointer<Void>, _AppKitPoint)
          >
        >()
        .asFunction<
          void Function(Pointer<Void>, Pointer<Void>, _AppKitPoint)
        >()(window, _topLeftSelector, point);
  }
}
