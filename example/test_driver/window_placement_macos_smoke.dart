// Run from example: flutter run -d macos -t test_driver/window_placement_macos_smoke.dart
// Checks actual NSWindow frames rather than Flutter's placement calculations.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member
import 'dart:async';
import 'dart:ffi' hide Size;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/src/widgets/_window_macos.dart' as macos;
import 'package:grid_flow/grid_os.dart';

void main() => GridNativeWindows.run(
  const MaterialApp(home: _PlacementProbe()),
  title: 'Placement launcher',
  size: const Size(320, 240),
);

class _PlacementProbe extends StatefulWidget {
  const _PlacementProbe();
  @override
  State<_PlacementProbe> createState() => _PlacementProbeState();
}

class _PlacementProbeState extends State<_PlacementProbe> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_exercise()));
  }

  Future<void> _exercise() async {
    try {
      await Future<void>.delayed(const Duration(seconds: 3));
      final launcher = View.of(context);
      final handle = macos.WindowingOwnerMacOS.getWindowHandle(launcher);
      final work = _readRect(_screen(handle), 'visibleFrame');
      _move(handle, work.x + 40, work.y + work.height - 40);
      await _settle();
      final first = await _open(launcher);
      _checkPlacement(launcher, first.view);

      // Moving the child before it opens another window must change the anchor.
      _move(first.handle, work.x + 80, work.y + work.height - 100);
      await _settle();
      final second = await _open(first.view, opener: first.desktop);
      _checkPlacement(first.view, second.view);

      // A launcher request keeps its own anchor after children take focus.
      _move(handle, work.x + 120, work.y + work.height - 60);
      await _settle();
      final third = await _open(launcher);
      _checkPlacement(launcher, third.view);

      // Near the edge, retain the title bar on this screen and fit oversized
      // remembered content to the visible area, excluding decorations.
      _move(handle, work.x + work.width - 340, work.y + 280);
      await _settle();
      final edge = await _open(launcher, size: const Size(5000, 5000));
      _checkPlacement(launcher, edge.view);
      final edgeFrame = _readRect(edge.handle, 'frame');
      _check(
        edgeFrame.width <= work.width + 1,
        'Oversized width was not fitted',
      );
      _check(
        edgeFrame.height <= work.height + 1,
        'Oversized height was not fitted',
      );

      for (final child in [first, second, third, edge]) {
        GridNativeWindows.closeWindow(child.id);
        await child.result;
      }
      debugPrint('WINDOW_PLACEMENT_MACOS_SMOKE_OK');
      GridNativeWindows.closeWindow('grid-flow-launcher');
    } catch (error, stack) {
      debugPrint('WINDOW_PLACEMENT_MACOS_SMOKE_FAILED: $error\n$stack');
      await ServicesBinding.instance.exitApplication(
        ui.AppExitType.required,
        1,
      );
    }
  }

  Future<_Child> _open(
    ui.FlutterView source, {
    DesktopHandle? opener,
    Size size = const Size(300, 200),
  }) async {
    final before = ui.PlatformDispatcher.instance.views.toSet();
    String? id;
    DesktopHandle? desktop;
    final app = DesktopApp(
      title: 'Placement child',
      windowSizeKey: 'placement-smoke-${DateTime.now().microsecondsSinceEpoch}',
      nativeWindowSize: size,
      contentBuilder: (windowId) {
        id = windowId;
        return Builder(
          builder: (context) {
            desktop = DesktopProvider.of(context);
            return const Center(
              child: Text('Checking native window placement'),
            );
          },
        );
      },
    );
    final result = opener == null
        ? GridNativeWindows.openApp(app, context: context)
        : opener.openApp(app);
    await _settle();
    final view = ui.PlatformDispatcher.instance.views.singleWhere(
      (view) => !before.contains(view),
    );
    _check(id != null && desktop != null, 'Child did not build');
    _check(view != source, 'Expected a distinct native view');
    return _Child(id!, view, desktop!, result);
  }

  Future<void> _settle() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await WidgetsBinding.instance.endOfFrame;
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Testing macOS native placement…')),
  );
}

class _Child {
  _Child(this.id, this.view, this.desktop, this.result);
  final String id;
  final ui.FlutterView view;
  final DesktopHandle desktop;
  final Future<dynamic> result;
  Pointer<Void> get handle => macos.WindowingOwnerMacOS.getWindowHandle(view);
}

void _checkPlacement(ui.FlutterView opener, ui.FlutterView child) {
  final anchorHandle = macos.WindowingOwnerMacOS.getWindowHandle(opener);
  final anchor = _readRect(anchorHandle, 'frame');
  final childHandle = macos.WindowingOwnerMacOS.getWindowHandle(child);
  final frame = _readRect(childHandle, 'frame');
  final work = _readRect(_screen(anchorHandle), 'visibleFrame');
  final expectedX = (anchor.x + anchor.width + 5)
      .clamp(work.x, work.x + work.width - 160)
      .roundToDouble();
  final expectedTop = (anchor.y + anchor.height - 32)
      .clamp(work.y + 80, work.y + work.height)
      .roundToDouble();
  _check(
    (frame.x - expectedX).abs() <= 1,
    'Wrong X: ${frame.x}, expected $expectedX',
  );
  _check(
    (frame.y + frame.height - expectedTop).abs() <= 1,
    'Wrong top: ${frame.y + frame.height}, expected $expectedTop',
  );
  debugPrint(
    'PLACEMENT_OK opener=${opener.viewId} child=${child.viewId} '
    'x=${frame.x} top=${frame.y + frame.height} '
    'scale=${opener.devicePixelRatio}',
  );
}

void _check(bool value, String message) {
  if (!value) throw StateError(message);
}

final class _Point extends Struct {
  @Double()
  external double x;
  @Double()
  external double y;
}

final class _Rect extends Struct {
  @Double()
  external double x;
  @Double()
  external double y;
  @Double()
  external double width;
  @Double()
  external double height;
}

@Native<Pointer<Void> Function(IntPtr)>(symbol: 'malloc')
external Pointer<Void> _malloc(int size);
@Native<Void Function(Pointer<Void>)>(symbol: 'free')
external void _free(Pointer<Void> pointer);
@Native<Pointer<Void> Function(Pointer<Uint8>)>(symbol: 'sel_registerName')
external Pointer<Void> _registerName(Pointer<Uint8> name);
@Native<Pointer<Void> Function(Pointer<Void>)>(symbol: 'object_getClass')
external Pointer<Void> _classFor(Pointer<Void> object);
@Native<Pointer<Void> Function(Pointer<Void>, Pointer<Void>)>(
  symbol: 'class_getMethodImplementation',
)
external Pointer<Void> _method(Pointer<Void> cls, Pointer<Void> selector);

Pointer<Void> _selector(String name) {
  final bytes = _malloc(name.length + 1).cast<Uint8>();
  try {
    bytes.asTypedList(name.length + 1).setAll(0, [...name.codeUnits, 0]);
    return _registerName(bytes);
  } finally {
    _free(bytes.cast());
  }
}

_Rect _readRect(Pointer<Void> object, String name) {
  final selector = _selector(name);
  return _method(_classFor(object), selector)
      .cast<NativeFunction<_Rect Function(Pointer<Void>, Pointer<Void>)>>()
      .asFunction<_Rect Function(Pointer<Void>, Pointer<Void>)>()(
    object,
    selector,
  );
}

Pointer<Void> _screen(Pointer<Void> window) {
  final selector = _selector('screen');
  return _method(_classFor(window), selector)
      .cast<
        NativeFunction<Pointer<Void> Function(Pointer<Void>, Pointer<Void>)>
      >()
      .asFunction<Pointer<Void> Function(Pointer<Void>, Pointer<Void>)>()(
    window,
    selector,
  );
}

void _move(Pointer<Void> window, double x, double top) {
  final selector = _selector('setFrameTopLeftPoint:');
  final point = Struct.create<_Point>()
    ..x = x
    ..y = top;
  _method(_classFor(window), selector)
      .cast<
        NativeFunction<Void Function(Pointer<Void>, Pointer<Void>, _Point)>
      >()
      .asFunction<void Function(Pointer<Void>, Pointer<Void>, _Point)>()(
    window,
    selector,
    point,
  );
}
