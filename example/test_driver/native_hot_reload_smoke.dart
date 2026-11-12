// flutter run -d macos -t test_driver/native_hot_reload_smoke.dart
// Change the string returned by revision, save, then hot reload repeatedly.
// Each reload must print GRIDFLOW_RELOAD_OK and keep all three native views.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:grid_flow/grid_os.dart';

String get revision => 'revision 1';

final _contentKey = GlobalKey<_CounterState>();
final _registeredKey = GlobalKey<_CounterState>();

void main() {
  GridNativeWindows.run(
    const MaterialApp(home: Scaffold(body: _Launcher())),
    title: 'GridFlow hot reload regression',
    size: const Size(500, 400),
    builders: {
      'counter': (_) => _Counter(key: _registeredKey, label: revision),
    },
    appBuilder: (child) => MaterialApp(title: revision, home: child),
  );
}

class _Launcher extends StatefulWidget {
  const _Launcher();

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  List<int>? _originalViews;
  List<_CounterState>? _originalStates;

  List<int> get _views {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    return dispatcher.views
        .where((view) => view != dispatcher.implicitView)
        .map((view) => view.viewId)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_open()));
  }

  Future<void> _open() async {
    await Future<void>.delayed(Duration.zero);
    unawaited(
      GridNativeWindows.openApp(
        DesktopApp(
          title: 'contentBuilder',
          nativeWindowSize: const Size(420, 300),
          contentBuilder: (_) => _Counter(key: _contentKey, label: revision),
        ),
      ),
    );
    unawaited(
      GridNativeWindows.openApp(
        DesktopApp(
          title: 'Registered builder',
          nativeId: 'counter',
          nativeWindowSize: const Size(420, 300),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 1));
    _originalViews = _views;
    _originalStates = [_contentKey.currentState!, _registeredKey.currentState!];
    if (_originalViews!.length != 3) {
      throw StateError('Expected three views');
    }
    debugPrint(
      'GRIDFLOW_RELOAD_READY views=$_originalViews revision=$revision',
    );
  }

  @override
  void reassemble() {
    super.reassemble();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final states = [_contentKey.currentState, _registeredKey.currentState];
      final valid =
          _originalStates != null &&
          _views.toString() == _originalViews.toString() &&
          List.generate(2, (i) => i).every(
            (i) =>
                identical(states[i], _originalStates![i]) &&
                states[i]!.widget.label == revision &&
                states[i]!.context
                        .findAncestorWidgetOfExactType<MaterialApp>()
                        ?.title ==
                    revision &&
                states[i]!.controller.text == 'Keep this draft',
          );
      debugPrint(
        'GRIDFLOW_RELOAD_${valid ? 'OK' : 'FAILED'} '
        'views=$_views revision=$revision '
        'labels=${states.map((state) => state?.widget.label).toList()}',
      );
      if (!valid) {
        throw StateError('Hot reload did not preserve/update content');
      }
    });
  }

  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Edit revision in the smoke test and hot reload.'),
  );
}

class _Counter extends StatefulWidget {
  const _Counter({super.key, required this.label});
  final String label;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  final controller = TextEditingController(text: 'Keep this draft');

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(widget.label),
      TextField(controller: controller),
    ],
  );
}
