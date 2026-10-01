// Run from example: flutter run -d windows -t lib/native_restart_smoke.dart
// Press R repeatedly, with r between restarts. Each run must report READY with
// the same launcher view and exactly two views. Close the windows to exit.
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:grid_flow/grid_os.dart';

String? _childId;
int? _launcherId;

void main() {
  GridNativeWindows.ensureInitialized();
  registerExtension('ext.gridflowSmoke.state', (_, _) async {
    return ServiceExtensionResponse.result(
      jsonEncode({
        'launcher': _launcherId,
        'views': ui.PlatformDispatcher.instance.views
            .map((v) => v.viewId)
            .toList(),
      }),
    );
  });
  registerExtension('ext.gridflowSmoke.finish', (_, _) async {
    if (_childId != null) GridNativeWindows.closeWindow(_childId!);
    Timer(const Duration(milliseconds: 300), () {
      GridNativeWindows.closeWindow('grid-flow-launcher');
    });
    return ServiceExtensionResponse.result('{"closing":true}');
  });
  GridNativeWindows.run(
    const MaterialApp(home: Scaffold(body: _Probe())),
    title: 'GridFlow restart regression',
    size: const Size(640, 480),
  );
}

void _expectViews(int expected) {
  final views = ui.PlatformDispatcher.instance.views.toList();
  if (views.length != expected || views.first.viewId != _launcherId) {
    throw StateError(
      'Expected $expected views and launcher $_launcherId; '
      'got ${views.map((v) => v.viewId).toList()}',
    );
  }
}

Future<dynamic> _openChild() => GridNativeWindows.openApp(
  DesktopApp(
    title: 'GridFlow restart child',
    color: Colors.blue,
    contentBuilder: (id) {
      _childId = id;
      return const Center(child: Text('This child is retired on hot restart.'));
    },
  ),
);

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _exercise());
  }

  Future<void> _exercise() async {
    try {
      _launcherId = View.of(context).viewId;
      _expectViews(1);
      GridNativeWindows.ensureInitialized();
      _expectViews(1);
      // Native window creation can pump Windows messages; leave the frame first.
      await Future<void>.delayed(Duration.zero);
      final closed = _openChild();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _expectViews(2);
      GridNativeWindows.closeWindow(_childId!, 'closed normally');
      final result = await closed.timeout(const Duration(seconds: 3));
      if (result != 'closed normally') throw StateError('Lost close result');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _expectViews(1);
      unawaited(_openChild());
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _expectViews(2);
      debugPrint(
        'GRIDFLOW_RESTART_READY launcher=$_launcherId views='
        '${ui.PlatformDispatcher.instance.views.map((v) => v.viewId).toList()}',
      );
    } catch (error, stack) {
      debugPrint('GRIDFLOW_RESTART_FAILED $error');
      Error.throwWithStackTrace(error, stack);
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Hot restart keeps this window and retires its old children.',
        ),
        const Text('Move or resize this window, then press R in the terminal.'),
        TextButton(
          onPressed: () => setState(() => _counter++),
          child: Text('Hot reload preserves this counter: $_counter'),
        ),
      ],
    ),
  );
}
