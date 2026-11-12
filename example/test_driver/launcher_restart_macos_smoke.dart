// flutter run -d macos -t test_driver/launcher_restart_macos_smoke.dart
// Press R repeatedly. Each restart must print GRIDFLOW_MACOS_RESTART_OK.
// The probe moves/resizes the launcher after each check to test the latest frame.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member
import 'dart:async';
import 'dart:convert';
import 'dart:ffi' hide Size;
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/src/widgets/_window.dart' as windowing;
import 'package:flutter/src/widgets/_window_macos.dart' as macos;
import 'package:grid_flow/grid_os.dart';

void main() => GridNativeWindows.run(
  const MaterialApp(home: Scaffold(body: _Probe())),
  title: 'GridFlow macOS restart geometry',
  size: const Size(640, 480),
);

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final _expected = File(
    '${Directory.systemTemp.path}/gridflow-macos-restart-$pid.json',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_exercise()));
  }

  Future<void> _exercise() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final controller =
        windowing.WindowScope.of(context) as macos.WindowControllerMacOS;
    final handle = controller.windowHandle;
    var generation = 0;
    if (await _expected.exists()) {
      final expected = jsonDecode(await _expected.readAsString()) as Map;
      generation = expected['generation'] as int;
      final actual = _frame(handle).values;
      final previous = (expected['frame'] as List).cast<num>();
      if (!List.generate(
        4,
        (i) => i,
      ).every((i) => (actual[i] - previous[i]).abs() <= 1)) {
        throw StateError(
          'GRIDFLOW_MACOS_RESTART_FAILED '
          'expected=$previous actual=$actual',
        );
      }
      debugPrint('GRIDFLOW_MACOS_RESTART_OK frame=$actual');
    }
    generation++;
    final screen = _object(handle, 'screen');
    final work = _rect(screen, 'visibleFrame');
    controller.setSize(Size(500 + generation * 20, 340 + generation * 10));
    _move(
      handle,
      work.x + 80 + generation * 30,
      work.y + work.height - 70 - generation * 20,
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final frame = _frame(handle).values;
    await _expected.writeAsString(
      jsonEncode({'generation': generation, 'frame': frame}),
    );
    // Match an IDE-triggered restart, where the app is not the key window.
    // This SDK otherwise sends resign-key to an already detached view on close.
    _resignKey(handle);
    debugPrint(
      'GRIDFLOW_MACOS_RESTART_READY generation=$generation frame=$frame',
    );
  }

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () async {
        if (await _expected.exists()) await _expected.delete();
        GridNativeWindows.closeWindow('grid-flow-launcher');
      },
      child: const Text(
        'Press R in the terminal to restart. Click here to finish.',
      ),
    ),
  );
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

  List<double> get values => [x, y, width, height];
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

_Rect _frame(Pointer<Void> window) => _rect(window, 'frame');

_Rect _rect(Pointer<Void> object, String name) {
  final selector = _selector(name);
  return _method(_classFor(object), selector)
      .cast<NativeFunction<_Rect Function(Pointer<Void>, Pointer<Void>)>>()
      .asFunction<_Rect Function(Pointer<Void>, Pointer<Void>)>()(
    object,
    selector,
  );
}

Pointer<Void> _object(Pointer<Void> object, String name) {
  final selector = _selector(name);
  return _method(_classFor(object), selector)
      .cast<
        NativeFunction<Pointer<Void> Function(Pointer<Void>, Pointer<Void>)>
      >()
      .asFunction<Pointer<Void> Function(Pointer<Void>, Pointer<Void>)>()(
    object,
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

void _resignKey(Pointer<Void> window) {
  final selector = _selector('resignKeyWindow');
  _method(_classFor(window), selector)
      .cast<NativeFunction<Void Function(Pointer<Void>, Pointer<Void>)>>()
      .asFunction<void Function(Pointer<Void>, Pointer<Void>)>()(
    window,
    selector,
  );
}
