import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_flow/grid_os.dart';
import 'package:grid_flow/src/painters.dart';
import 'package:grid_flow/src/window_widget.dart';

Future<DesktopController> mountDesktop(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const MaterialApp(home: GridDesktop(apps: [])));
  await tester.pump();
  return tester
      .widget<DesktopProvider>(find.byType(DesktopProvider))
      .controller;
}

DesktopApp app({String? tag}) => DesktopApp(
  title: 'Test app',
  connectionTag: tag,
  contentBuilder: (_) => const SizedBox.shrink(),
);

Future<void> finishTransitions(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 2),
  );
}

Finder get connectionsFinder => find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is ConnectionsPainter,
);

ConnectionsPainter connectionPainter(WidgetTester tester) =>
    tester.widget<CustomPaint>(connectionsFinder).painter!
        as ConnectionsPainter;

void main() {
  testWidgets('an empty desktop does not continuously schedule frames', (
    tester,
  ) async {
    await mountDesktop(tester);
    await finishTransitions(tester);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('unconnected windows leave the desktop idle', (tester) async {
    final controller = await mountDesktop(tester);
    for (var i = 0; i < 5; i++) {
      controller.openApp(app(tag: 'group-$i'));
    }
    await finishTransitions(tester);
    expect(find.byType(FastWindow), findsNWidgets(5));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('visible connections stay idle without repaint notifications', (
    tester,
  ) async {
    final controller = await mountDesktop(tester);
    controller.openApp(app(tag: 'linked'));
    controller.openApp(app(tag: 'linked'));
    await finishTransitions(tester);
    final painter = connectionPainter(tester);
    expect(painter.hasVisibleConnections, isTrue);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);

    var repaintNotifications = 0;
    void onRepaint() => repaintNotifications++;
    painter.addListener(onRepaint);
    addTearDown(() => painter.removeListener(onRepaint));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    }
    expect(repaintNotifications, 0);
    expect(connectionPainter(tester), same(painter));
  });

  testWidgets('connection painting is limited to the desktop viewport', (
    tester,
  ) async {
    final controller = await mountDesktop(tester);
    controller.openApp(app(tag: 'linked'));
    controller.openApp(app(tag: 'linked'));
    await finishTransitions(tester);
    expect(connectionsFinder, findsOneWidget);
    expect(tester.getSize(connectionsFinder), const Size(1200, 800));
    expect(connectionPainter(tester).hasVisibleConnections, isTrue);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('closing a connected window removes its static connection', (
    tester,
  ) async {
    final controller = await mountDesktop(tester);
    controller.openApp(app(tag: 'linked'));
    controller.openApp(app(tag: 'linked'));
    await finishTransitions(tester);
    expect(connectionPainter(tester).hasVisibleConnections, isTrue);
    expect(tester.binding.transientCallbackCount, 0);
    final id = tester
        .widgetList<FastWindow>(find.byType(FastWindow))
        .last
        .window
        .id;
    controller.closeWindow(id);
    await finishTransitions(tester);
    expect(connectionPainter(tester).hasVisibleConnections, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'disposing the desktop completes all outstanding window results',
    (tester) async {
      final controller = await mountDesktop(tester);
      final results = <dynamic>[];
      for (var i = 0; i < 3; i++) {
        controller.openApp(app()).then(results.add);
      }
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(results, [null, null, null]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('connections update when scrolled into view and remain idle', (
    tester,
  ) async {
    final controller = await mountDesktop(tester);
    controller.openApp(app(tag: 'linked'));
    controller.openApp(app(tag: 'linked'));
    await finishTransitions(tester);
    expect(connectionPainter(tester).hasVisibleConnections, isTrue);
    expect(tester.binding.transientCallbackCount, 0);
    final windows = tester
        .widgetList<FastWindow>(find.byType(FastWindow))
        .toList();
    for (var i = 0; i < windows.length; i++) {
      windows[i].onUpdate(Rect.fromLTWH(30000 + i * 600, 8200, 500, 400));
    }
    await finishTransitions(tester);
    expect(connectionPainter(tester).hasVisibleConnections, isFalse);
    expect(tester.binding.transientCallbackCount, 0);

    final scrollView = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .singleWhere((view) => view.scrollDirection == Axis.horizontal);
    scrollView.controller!.jumpTo(29900);
    await finishTransitions(tester);
    expect(connectionPainter(tester).hasVisibleConnections, isTrue);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('maximizing hides connections and restoring shows static lines', (
    tester,
  ) async {
    final controller = await mountDesktop(tester);
    controller.openApp(app(tag: 'linked'));
    controller.openApp(app(tag: 'linked'));
    await finishTransitions(tester);
    expect(connectionPainter(tester).hasVisibleConnections, isTrue);
    expect(tester.binding.transientCallbackCount, 0);
    tester.widgetList<FastWindow>(find.byType(FastWindow)).last.onMaximize();
    await finishTransitions(tester);
    expect(connectionsFinder, findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    tester.widgetList<FastWindow>(find.byType(FastWindow)).last.onMaximize();
    await finishTransitions(tester);
    expect(connectionPainter(tester).hasVisibleConnections, isTrue);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('burst opens have unique identities and independent results', (
    tester,
  ) async {
    final controller = await mountDesktop(tester);
    final ids = <String>[];
    final results = <int, dynamic>{};
    for (var i = 0; i < 30; i++) {
      controller
          .openApp(
            DesktopApp(
              title: 'Window $i',
              contentBuilder: (id) {
                ids.add(id);
                return const SizedBox.shrink();
              },
            ),
          )
          .then((value) => results[i] = value);
    }
    await tester.pump();
    expect(ids.toSet(), hasLength(30));
    expect(
      tester
          .widgetList<FastWindow>(find.byType(FastWindow))
          .where((window) => window.window.isFocused),
      hasLength(1),
    );
    for (var i = 0; i < ids.length; i++) {
      controller.closeWindow(ids[i], i);
    }
    await tester.pump();
    expect(results, {for (var i = 0; i < ids.length; i++) i: i});
    expect(find.byType(FastWindow), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edge scrolling stops on drag end and on window close', (
    tester,
  ) async {
    final controller = await mountDesktop(tester);
    controller.openApp(app());
    await finishTransitions(tester);
    var window = tester.widget<FastWindow>(find.byType(FastWindow));
    window.onUpdate(const Rect.fromLTWH(8200, 8200, 500, 400));
    await finishTransitions(tester);
    window = tester.widget<FastWindow>(find.byType(FastWindow));
    final horizontal = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .singleWhere((view) => view.scrollDirection == Axis.horizontal)
        .controller!;
    final initialOffset = horizontal.offset;
    window.onDragStart();
    window.onDragUpdate(
      DragUpdateDetails(
        delta: const Offset(600, 0),
        globalPosition: Offset.zero,
      ),
    );
    await tester.pump(const Duration(milliseconds: 48));
    expect(horizontal.offset, greaterThan(initialOffset));
    window.onDragEnd();
    final stoppedOffset = horizontal.offset;
    await tester.pump(const Duration(milliseconds: 200));
    expect(horizontal.offset, stoppedOffset);

    window = tester.widget<FastWindow>(find.byType(FastWindow));
    window.onDragStart();
    window.onDragUpdate(
      DragUpdateDetails(
        delta: const Offset(20, 0),
        globalPosition: Offset.zero,
      ),
    );
    await tester.pump(const Duration(milliseconds: 48));
    expect(horizontal.offset, greaterThan(stoppedOffset));
    controller.closeWindow(window.window.id);
    final closedOffset = horizontal.offset;
    await tester.pump(const Duration(milliseconds: 200));
    expect(horizontal.offset, closedOffset);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a retained controller is harmless after desktop disposal', (
    tester,
  ) async {
    final controller = await mountDesktop(tester);
    controller.openApp(app());
    await tester.pump();
    final id = tester.widget<FastWindow>(find.byType(FastWindow)).window.id;
    await tester.pumpWidget(const SizedBox.shrink());
    controller.closeWindow(id);
    expect(await controller.openApp(app()), isNull);
    expect(tester.takeException(), isNull);
  });
}
