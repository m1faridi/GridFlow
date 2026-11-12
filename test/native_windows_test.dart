// ignore_for_file: implementation_imports, invalid_use_of_internal_member

import 'dart:ui' as ui;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/src/foundation/_features.dart' show isWindowingEnabled;
import 'package:flutter/src/widgets/_window.dart' as windowing;
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_flow/grid_os.dart';
import 'package:grid_flow/src/window_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WindowTestBinding extends AutomatedTestWidgetsFlutterBinding {
  int exits = 0;

  @override
  Future<ui.AppExitResponse> exitApplication(
    ui.AppExitType exitType, [
    int exitCode = 0,
  ]) async {
    exits++;
    return ui.AppExitResponse.exit;
  }
}

// Each controller must own a distinct view, just as it does in the engine.
class FakeView extends TestFlutterView {
  FakeView(TestFlutterView view, this.viewId)
    : super(
        view: view,
        platformDispatcher: view.platformDispatcher,
        display: view.display,
      );

  @override
  final int viewId;

  @override
  void render(ui.Scene scene, {Size? size}) {}

  @override
  void updateSemantics(ui.SemanticsUpdate update) {}
}

class FakeWindow extends windowing.WindowController {
  final windowing.WindowControllerDelegate delegate;
  @override
  String title;
  @override
  Size contentSize;
  bool destroyed = false;
  @override
  bool get isDestroyed => destroyed;
  bool released = false;
  int destroyCount = 0;

  FakeWindow(
    TestFlutterView view,
    int id,
    this.delegate,
    this.title,
    this.contentSize,
  ) : super.empty() {
    rootView = FakeView(view, id);
  }

  void requestClose() => delegate.onWindowCloseRequested(this);

  @override
  void destroy() {
    if (destroyed) return;
    destroyed = true;
    destroyCount++;
    // Match Flutter 3.50's native destruction notification order.
    notifyListeners();
    delegate.onWindowDestroyed();
  }

  @override
  void dispose() {
    released = true;
    super.dispose();
  }

  @override
  bool get isActivated => true;
  @override
  bool get isMaximized {
    if (destroyed) throw StateError('Window has been destroyed.');
    return false;
  }
  @override
  bool get isMinimized => false;
  @override
  bool get isFullscreen => false;
  @override
  void setSize(Size size) => contentSize = size;
  @override
  void setTitle(String value) => title = value;
  @override
  void setConstraints(BoxConstraints constraints) {}
  @override
  void activate() {}
  @override
  void setMaximized(bool maximized) {}
  @override
  void setMinimized(bool minimized) {}
  @override
  void setFullscreen(bool fullscreen, {ui.Display? display}) {}
}

class FakeWindowingOwner extends Fake implements windowing.WindowingOwner {
  final WidgetTester tester;
  final windows = <FakeWindow>[];
  bool failCreation = false;

  FakeWindowingOwner(this.tester);

  @override
  windowing.WindowController createWindowController({
    required windowing.WindowControllerDelegate delegate,
    required bool resizable,
    Size? size,
    BoxConstraints? constraints,
    String? title,
  }) {
    if (failCreation) throw StateError('Native creation failed');
    expectSync(resizable, isTrue);
    expectSync(constraints!.minWidth, 200);
    final window = FakeWindow(
      tester.view,
      windows.length + 100,
      delegate,
      title!,
      size!,
    );
    windows.add(window);
    return window;
  }
}

class SharedState extends InheritedNotifier<ValueNotifier<int>> {
  const SharedState({super.key, required super.notifier, required super.child});
}

class Harness {
  final FakeWindowingOwner owner;
  int get exits => (owner.tester.binding as WindowTestBinding).exits;

  Harness(this.owner);

  Future<DesktopController> mount(
    WidgetTester tester, {
    bool native = true,
    Map<String, NativeWindowBuilder> builders = const {},
    Widget Function(Widget)? appBuilder,
    ValueNotifier<int>? shared,
    Widget? launcher,
  }) async {
    Widget host = GridNativeWindowHost(
      builders: builders,
      appBuilder: appBuilder,
      launcher:
          launcher ??
          MaterialApp(
            home: GridDesktop(apps: const [], useNativeWindows: native),
          ),
    );
    if (shared != null) host = SharedState(notifier: shared, child: host);
    await tester.pumpWidget(host, wrapWithView: false);
    await tester.pumpAndSettle();
    return tester
        .widget<DesktopProvider>(find.byType(DesktopProvider).first)
        .controller;
  }
}

void windowTest(
  String description,
  Future<void> Function(WidgetTester, Harness) callback,
) {
  testWidgets(description, (tester) async {
    final oldEnabled = isWindowingEnabled;
    isWindowingEnabled = true;
    final oldOwner = tester.binding.windowingOwner;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final harness = Harness(FakeWindowingOwner(tester));
    tester.binding.windowingOwner = harness.owner;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    (tester.binding as WindowTestBinding).exits = 0;
    try {
      await callback(tester, harness);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      isWindowingEnabled = true;
      tester.binding.windowingOwner = oldOwner;
      isWindowingEnabled = oldEnabled;
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });
}

DesktopApp editor({Widget Function(String)? builder, bool closable = true}) =>
    DesktopApp(
      title: 'Editor',
      isClosable: closable,
      contentBuilder: builder ?? (_) => const Text('Editor content'),
    );

void main() {
  WindowTestBinding();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  windowTest('bootstrap preserves an already initialized windowing owner', (
    tester,
    h,
  ) async {
    expect(GridNativeWindows.ensureInitialized(), same(tester.binding));
    expect(GridNativeWindows.ensureInitialized(), same(tester.binding));
    final owner = tester.binding.windowingOwner;
    expect(owner, same(h.owner));
    GridNativeWindows.ensureInitialized();
    expect(tester.binding.windowingOwner, same(owner));
    final desktop = await h.mount(tester);
    desktop.openApp(editor());
    await tester.pumpAndSettle();
    expect(h.owner.windows, hasLength(2));
  });

  windowTest('mobile bootstrap leaves experimental windowing disabled', (
    tester,
    h,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    isWindowingEnabled = false;
    GridNativeWindows.run(const MaterialApp(home: Text('Mobile canvas')));
    await tester.pump();
    expect(isWindowingEnabled, isFalse);
    expect(GridNativeWindows.isSupported, isFalse);
    expect(find.text('Mobile canvas'), findsOneWidget);
    expect(h.owner.windows, isEmpty);
    isWindowingEnabled = true;
  });

  for (final kind in ['material', 'adaptive', 'cupertino', 'general']) {
    windowTest('$kind dialogs stay in their originating native view', (
      tester,
      h,
    ) async {
      final desktop = await h.mount(tester);
      Future<String?>? result;
      Widget dialog(BuildContext context) {
        expect(View.of(context), same(h.owner.windows.last.rootView));
        void confirm() => Navigator.of(context).pop('confirmed');
        return kind == 'cupertino'
            ? CupertinoAlertDialog(
                title: const Text('Dialog content'),
                actions: [
                  CupertinoDialogAction(
                    onPressed: confirm,
                    child: const Text('Confirm'),
                  ),
                ],
              )
            : AlertDialog(
                title: const Text('Dialog content'),
                actions: [
                  TextButton(onPressed: confirm, child: const Text('Confirm')),
                ],
              );
      }

      final childResult = desktop.openApp(
        editor(
          builder: (_) => Builder(
            builder: (context) => TextButton(
              onPressed: () {
                result = switch (kind) {
                  'material' => showDialog<String>(
                    context: context,
                    builder: dialog,
                  ),
                  'adaptive' => showAdaptiveDialog<String>(
                    context: context,
                    builder: dialog,
                  ),
                  'cupertino' => showCupertinoDialog<String>(
                    context: context,
                    builder: dialog,
                  ),
                  _ => showGeneralDialog<String>(
                    context: context,
                    pageBuilder: (context, _, _) => dialog(context),
                  ),
                };
              },
              child: const Text('Open dialog'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Dialog content'), findsOneWidget);
      expect(find.byType(ModalBarrier), findsWidgets);
      expect(h.owner.windows, hasLength(2));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(await result, 'confirmed');
      expect(find.text('Dialog content'), findsNothing);
      expect(h.owner.windows.last.destroyed, isFalse);
      h.owner.windows.last.requestClose();
      await tester.pumpAndSettle();
      expect(await childResult, isNull);
    });
  }

  windowTest(
    'native contentBuilder creates a second view and returns Dart objects',
    (tester, h) async {
      final desktop = await h.mount(tester);
      final value = Object();
      final result = desktop.openApp(
        editor(
          builder: (_) => Builder(
            builder: (context) => TextButton(
              onPressed: () => DesktopProvider.of(context)!.closeApp(value),
              child: const Text('Save'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(h.owner.windows, hasLength(2));
      expect(find.byType(windowing.Window), findsNWidgets(2));
      expect(find.byType(FastWindow), findsNothing);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(await result, same(value));
      expect(h.owner.windows.last.destroyCount, 1);
      expect(h.owner.windows.last.released, isTrue);
    },
  );

  windowTest(
    'canvas remains the default and changing the toggle only affects new opens',
    (tester, h) async {
      var desktop = await h.mount(tester, native: false);
      desktop.openApp(editor());
      await tester.pumpAndSettle();
      expect(find.byType(FastWindow), findsOneWidget);
      expect(h.owner.windows, hasLength(1));
      desktop = await h.mount(tester);
      final nativeResult = desktop.openApp(editor());
      await tester.pumpAndSettle();
      expect(find.byType(FastWindow), findsOneWidget);
      expect(h.owner.windows, hasLength(2));
      h.owner.windows.last.requestClose();
      await tester.pumpAndSettle();
      expect(await nativeResult, isNull);
    },
  );

  windowTest('feature flag and platform gate native routing', (
    tester,
    h,
  ) async {
    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(GridNativeWindows.isSupported, isTrue);
    }
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(GridNativeWindows.isSupported, isFalse);
    isWindowingEnabled = false;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(GridNativeWindows.isSupported, isFalse);
    await tester.pumpWidget(
      MaterialApp(home: GridDesktop(apps: const [], useNativeWindows: true)),
    );
    final desktop = tester
        .widget<DesktopProvider>(find.byType(DesktopProvider))
        .controller;
    desktop.openApp(editor());
    await tester.pumpAndSettle();
    expect(find.byType(FastWindow), findsOneWidget);
    expect(h.owner.windows, isEmpty);
    isWindowingEnabled = true;
  });

  windowTest('opening without the root host reports a bootstrap error', (
    tester,
    h,
  ) async {
    await expectLater(GridNativeWindows.openApp(editor()), throwsStateError);
    expect(h.owner.windows, isEmpty);
  });

  windowTest('registered builders receive parent and in-memory arguments', (
    tester,
    h,
  ) async {
    NativeWindowLaunch? launch;
    final value = Object();
    final desktop = await h.mount(
      tester,
      builders: {
        'editor': (data) {
          launch = data;
          return const Text('Registered editor');
        },
      },
    );
    final result = desktop.openApp(
      DesktopApp(
        title: 'Document',
        nativeId: 'editor',
        nativeArguments: {'model': value},
        nativeWindowSize: const Size(850, 650),
      ),
      parentId: 'grid-flow-launcher',
    );
    await tester.pumpAndSettle();
    expect(launch!.arguments['model'], same(value));
    expect(launch!.parentId, 'grid-flow-launcher');
    expect(h.owner.windows.last.contentSize, const Size(850, 650));
    expect(find.text('Registered editor'), findsOneWidget);
    GridNativeWindows.closeWindow(launch!.windowId, value);
    await tester.pumpAndSettle();
    expect(await result, same(value));
  });

  windowTest('burst opens keep independent results when closed out of order', (
    tester,
    h,
  ) async {
    final desktop = await h.mount(tester);
    final ids = <String>[];
    DesktopApp app() => editor(
      builder: (id) {
        ids.add(id);
        return const Text('Child');
      },
    );
    final first = desktop.openApp(app());
    final second = desktop.openApp(app());
    await tester.pumpAndSettle();
    GridNativeWindows.closeWindow(ids[1], 'second');
    GridNativeWindows.closeWindow(ids[0], 'first');
    GridNativeWindows.closeWindow(ids[0], 'duplicate');
    await tester.pumpAndSettle();
    expect(await first, 'first');
    expect(await second, 'second');
    expect(h.exits, 0);
  });

  windowTest(
    'OS close respects isClosable while programmatic close still works',
    (tester, h) async {
      final desktop = await h.mount(tester);
      late String id;
      final result = desktop.openApp(
        editor(
          closable: false,
          builder: (value) {
            id = value;
            return const Text('Locked');
          },
        ),
      );
      await tester.pumpAndSettle();
      h.owner.windows.last.requestClose();
      await tester.pumpAndSettle();
      expect(h.owner.windows.last.destroyed, isFalse);
      desktop.closeWindow(id, true);
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    },
  );

  windowTest(
    'closing the launcher preserves children and exits only after the last closes',
    (tester, h) async {
      final desktop = await h.mount(tester);
      final result = desktop.openApp(editor());
      await tester.pumpAndSettle();
      h.owner.windows.first.requestClose();
      await tester.pumpAndSettle();
      expect(find.text('Editor content'), findsOneWidget);
      expect(h.exits, 0);
      h.owner.windows.last.requestClose();
      await tester.pumpAndSettle();
      expect(await result, isNull);
      expect(h.exits, 1);
    },
  );

  windowTest('removing the canvas leaves independent windows alive', (
    tester,
    h,
  ) async {
    final desktop = await h.mount(tester);
    final result = desktop.openApp(editor());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      const GridNativeWindowHost(
        launcher: MaterialApp(home: Text('Replacement')),
      ),
      wrapWithView: false,
    );
    await tester.pumpAndSettle();
    expect(find.text('Editor content'), findsOneWidget);
    expect(h.owner.windows.last.destroyed, isFalse);
    h.owner.windows.last.requestClose();
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  windowTest(
    'native children can open more native windows after their opener closes',
    (tester, h) async {
      final desktop = await h.mount(tester);
      late DesktopHandle child;
      final parentResult = desktop.openApp(
        editor(
          builder: (_) => Builder(
            builder: (context) {
              child = DesktopProvider.of(context)!;
              return const Text('Parent');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final childResult = child.openApp(editor());
      await tester.pumpAndSettle();
      child.closeApp('parent result');
      await tester.pumpAndSettle();
      expect(await parentResult, 'parent result');
      expect(find.text('Editor content'), findsOneWidget);
      h.owner.windows.last.requestClose();
      await tester.pumpAndSettle();
      expect(await childResult, isNull);
    },
  );

  windowTest('windows share inherited state above the host', (tester, h) async {
    final shared = ValueNotifier(1);
    addTearDown(shared.dispose);
    final desktop = await h.mount(tester, shared: shared);
    desktop.openApp(
      editor(
        builder: (_) => Builder(
          builder: (context) {
            final state = context
                .dependOnInheritedWidgetOfExactType<SharedState>()!;
            return Text('Shared ${state.notifier!.value}');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Shared 1'), findsOneWidget);
    shared.value = 2;
    await tester.pumpAndSettle();
    expect(find.text('Shared 2'), findsOneWidget);
  });

  windowTest('invalid configuration and builder failures do not leak windows', (
    tester,
    h,
  ) async {
    final desktop = await h.mount(tester);
    await expectLater(
      desktop.openApp(DesktopApp(title: 'Missing', nativeId: 'unknown')),
      throwsArgumentError,
    );
    await expectLater(
      desktop.openApp(DesktopApp(title: 'Small', nativeWindowSize: Size.zero)),
      throwsArgumentError,
    );
    await expectLater(
      desktop.openApp(editor(builder: (_) => throw StateError('builder'))),
      throwsStateError,
    );
    await h.mount(tester, appBuilder: (_) => throw StateError('app builder'));
    await expectLater(desktop.openApp(editor()), throwsStateError);
    await h.mount(tester);
    h.owner.failCreation = true;
    await expectLater(desktop.openApp(editor()), throwsStateError);
    expect(h.owner.windows, hasLength(1));
    h.owner.failCreation = false;
    desktop.openApp(editor());
    await tester.pumpAndSettle();
    expect(find.text('Editor content'), findsOneWidget);
  });

  windowTest(
    'destruction notifications skip size reads and release the controller',
    (tester, h) async {
      final desktop = await h.mount(tester);
      final result = desktop.openApp(editor());
      await tester.pumpAndSettle();
      h.owner.windows.last.destroy();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(await result, isNull);
      expect(h.owner.windows.last.released, isTrue);
    },
  );

  windowTest('closing during the first child build detaches its view safely', (
    tester,
    h,
  ) async {
    final desktop = await h.mount(tester);
    final result = desktop.openApp(
      editor(
        builder: (_) => Builder(
          builder: (context) {
            DesktopProvider.of(context)!.closeApp('immediate');
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(await result, 'immediate');
    expect(find.byType(windowing.Window), findsOneWidget);
    expect(h.owner.windows.last.released, isTrue);
  });

  windowTest('closing all windows in one frame requests exit exactly once', (
    tester,
    h,
  ) async {
    final desktop = await h.mount(tester);
    desktop.openApp(editor());
    desktop.openApp(editor());
    await tester.pumpAndSettle();
    for (final window in h.owner.windows) {
      window.requestClose();
    }
    await tester.pumpAndSettle();
    expect(h.exits, 1);
    expect(h.owner.windows.every((window) => window.released), isTrue);
  });

  windowTest(
    'disposing the host resolves results and releases all native resources',
    (tester, h) async {
      final desktop = await h.mount(tester);
      final result = desktop.openApp(editor());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(await result, isNull);
      expect(
        h.owner.windows.every((window) => window.destroyed && window.released),
        isTrue,
      );
      expect(h.exits, 0);
      await expectLater(GridNativeWindows.openApp(editor()), throwsStateError);
    },
  );
}
