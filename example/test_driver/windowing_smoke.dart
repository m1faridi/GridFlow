// Run with Flutter 3.50.0 stable: flutter run -d macos -t test_driver/windowing_smoke.dart
import 'dart:async';
import 'dart:ui' show AppExitType;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:grid_flow/grid_os.dart';

void main() {
  GridNativeWindows.run(const MaterialApp(home: _SmokeLauncher()));
}

class _SmokeLauncher extends StatefulWidget {
  const _SmokeLauncher();

  @override
  State<_SmokeLauncher> createState() => _SmokeLauncherState();
}

class _SmokeLauncherState extends State<_SmokeLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_exercise()));
  }

  Future<void> _exercise() async {
    try {
      // Allow flutter run to attach its VM service before this short test exits.
      await Future<void>.delayed(const Duration(seconds: 3));
      final ids = <String>[];
      DesktopHandle? childHandle;
      final payload = Object();
      final first = GridNativeWindows.openApp(
        DesktopApp(
          title: 'First independent window',
          contentBuilder: (id) {
            ids.add(id);
            return Builder(
              builder: (context) {
                childHandle = DesktopProvider.of(context);
                return const Center(child: Text('Native window smoke test'));
              },
            );
          },
        ),
      );
      await _settle();
      _check(childHandle != null, 'First native view did not build');
      final second = childHandle!.openApp(
        DesktopApp(
          title: 'Second independent window',
          contentBuilder: (id) {
            ids.add(id);
            return const Center(child: Text('Second native window'));
          },
        ),
      );
      await _settle();
      _check(
        _viewCount == 3,
        'Expected launcher and two native views, got $_viewCount',
      );
      GridNativeWindows.closeWindow('grid-flow-launcher');
      await _settle();
      _check(_viewCount == 2, 'Children did not survive launcher closure');
      GridNativeWindows.closeWindow(ids.first, payload);
      _check(
        identical(await first, payload),
        'Result lost its object identity',
      );
      await _settle();
      _check(_viewCount == 1, 'Remaining child did not survive opener closure');
      // Print success from the result callback before the last-view exit request.
      final checked = second.then((result) {
        _check(result == null, 'Expected a null close result');
        debugPrint('WINDOWING_SMOKE_OK');
      });
      GridNativeWindows.closeWindow(ids.last);
      await checked;
    } catch (error, stack) {
      debugPrint('WINDOWING_SMOKE_FAILED: $error\n$stack');
      await ServicesBinding.instance.exitApplication(AppExitType.required, 1);
    }
  }

  int get _viewCount {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    // macOS may retain an unattached implicit view even for a headless engine.
    // Count the explicit views owned by Flutter's window controllers.
    return dispatcher.views
        .where((view) => view != dispatcher.implicitView)
        .length;
  }

  Future<void> _settle() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await WidgetsBinding.instance.endOfFrame;
  }

  void _check(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Testing independent native windows…')),
  );
}
