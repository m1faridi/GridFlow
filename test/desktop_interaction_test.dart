import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_flow/grid_os.dart';
import 'package:grid_flow/src/window_widget.dart';

Future<DesktopController> mountDesktop(
  WidgetTester tester, {
  bool hasTitleBar = true,
}) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: GridDesktop(apps: const [], hasTitleBar: hasTitleBar),
    ),
  );
  await tester.pump();
  return tester
      .widget<DesktopProvider>(find.byType(DesktopProvider))
      .controller;
}

FastWindow windowFor(WidgetTester tester, String title) => tester
    .widgetList<FastWindow>(find.byType(FastWindow))
    .singleWhere((widget) => widget.window.title == title);

ScrollController scrollFor(WidgetTester tester, Axis axis) => tester
    .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
    .singleWhere((view) => view.scrollDirection == axis)
    .controller!;

DesktopApp emptyApp(String title) =>
    DesktopApp(title: title, contentBuilder: (_) => const SizedBox.expand());

Future<void> pumpFrames(WidgetTester tester, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  for (final zoom in ['Zoom in', 'Zoom out']) {
    testWidgets('a pointer drag stays aligned after $zoom', (tester) async {
      final controller = await mountDesktop(tester);
      controller.openApp(emptyApp('Zoomed drag'));
      await tester.pumpAndSettle();
      windowFor(
        tester,
        'Zoomed drag',
      ).onUpdate(const Rect.fromLTWH(8200, 8200, 500, 350));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(zoom));
      await tester.pumpAndSettle();
      final title = find.text('Zoomed drag');
      final gesture = await tester.startGesture(tester.getCenter(title));
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      final before = tester.getCenter(title);
      await gesture.moveBy(const Offset(0, -24));
      await tester.pump();
      expect(
        tester.getCenter(title),
        offsetMoreOrLessEquals(before + const Offset(0, -24), epsilon: 0.01),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    });
  }

  testWidgets('moving a window does not rebuild or repaint app contents', (
    tester,
  ) async {
    final controller = await mountDesktop(tester);
    final builds = [0, 0, 0];
    final paints = [0, 0, 0];
    for (var i = 0; i < 3; i++) {
      controller.openApp(
        DesktopApp(
          title: 'Content $i',
          contentBuilder: (_) => Builder(
            builder: (_) {
              builds[i]++;
              return CustomPaint(
                painter: _CountingPainter(() => paints[i]++),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      );
    }
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      windowFor(
        tester,
        'Content $i',
      ).onUpdate(Rect.fromLTWH(8100 + i * 300, 8100, 260, 350));
    }
    scrollFor(tester, Axis.horizontal).jumpTo(8000);
    await tester.pumpAndSettle();
    final initialBuilds = List<int>.of(builds);
    final initialPaints = List<int>.of(paints);
    expect(paints.every((count) => count > 0), isTrue);
    final window = windowFor(tester, 'Content 2');
    window.onDragStart();
    for (var i = 0; i < 20; i++) {
      window.onDragUpdate(
        DragUpdateDetails(
          delta: const Offset(0, -2),
          globalPosition: Offset.zero,
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    window.onDragEnd();
    await tester.pumpAndSettle();
    expect(builds, initialBuilds);
    expect(paints, initialPaints);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a tall window scrolls upwards when dragged beyond the top', (
    tester,
  ) async {
    final controller = await mountDesktop(tester);
    controller.openApp(emptyApp('Tall'));
    await tester.pumpAndSettle();
    var window = windowFor(tester, 'Tall');
    window.onUpdate(const Rect.fromLTWH(8200, 7950, 500, 1100));
    await tester.pumpAndSettle();
    window = windowFor(tester, 'Tall');
    final vertical = scrollFor(tester, Axis.vertical);
    final before = vertical.offset;
    window.onDragStart();
    window.onDragUpdate(
      DragUpdateDetails(
        delta: const Offset(0, -30),
        globalPosition: Offset.zero,
      ),
    );
    await pumpFrames(tester);
    expect(vertical.offset, lessThan(before));
    window.onDragEnd();
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('an accepted drag preserves small movement deltas', (
    tester,
  ) async {
    final controller = await mountDesktop(tester);
    controller.openApp(emptyApp('Small movement'));
    await tester.pumpAndSettle();
    final window = windowFor(tester, 'Small movement');
    final before = window.window.rect;
    window.onDragStart();
    for (var i = 0; i < 5; i++) {
      window.onDragUpdate(
        DragUpdateDetails(
          delta: const Offset(1, 0),
          globalPosition: Offset.zero,
        ),
      );
    }
    window.onDragEnd();
    await tester.pumpAndSettle();
    expect(window.window.rect, before.shift(const Offset(5, 0)));
  });

  testWidgets('cancelling a title bar drag stops edge scrolling immediately', (
    tester,
  ) async {
    final controller = await mountDesktop(tester);
    controller.openApp(emptyApp('Cancel drag'));
    await tester.pumpAndSettle();
    windowFor(
      tester,
      'Cancel drag',
    ).onUpdate(const Rect.fromLTWH(8200, 8020, 500, 400));
    await tester.pumpAndSettle();
    final vertical = scrollFor(tester, Axis.vertical);
    final before = vertical.offset;
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Cancel drag')),
    );
    await gesture.moveBy(const Offset(0, -30));
    await gesture.moveBy(const Offset(0, -30));
    await pumpFrames(tester);
    expect(vertical.offset, lessThan(before));
    await gesture.cancel();
    final stopped = vertical.offset;
    await pumpFrames(tester, 20);
    expect(vertical.offset, stopped);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('minimize retains form state and pauses its animations', (
    tester,
  ) async {
    final controller = await mountDesktop(tester);
    var initializations = 0;
    var disposals = 0;
    var ticks = 0;
    controller.openApp(
      DesktopApp(
        title: 'Form',
        contentBuilder: (_) => _StatefulContent(
          onInit: () => initializations++,
          onDispose: () => disposals++,
          onTick: () => ticks++,
        ),
      ),
    );
    await pumpFrames(tester);
    await tester.enterText(find.byType(TextField), 'Keep this draft');
    windowFor(tester, 'Form').onMinimize();
    await pumpFrames(tester);
    final pausedTicks = ticks;
    await pumpFrames(tester, 20);
    expect(initializations, 1);
    expect(disposals, 0);
    expect(ticks, pausedTicks);
    expect(tester.binding.transientCallbackCount, 0);
    windowFor(tester, 'Form').onMinimize();
    await pumpFrames(tester);
    expect(find.text('Keep this draft'), findsOneWidget);
    expect(initializations, 1);
    expect(ticks, greaterThan(pausedTicks));
    controller.closeWindow(windowFor(tester, 'Form').window.id);
    await tester.pump();
    expect(disposals, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('minimizing a maximized window restores its maximized state', (
    tester,
  ) async {
    final controller = await mountDesktop(tester);
    controller.openApp(emptyApp('Maximized'));
    await tester.pumpAndSettle();
    final window = windowFor(tester, 'Maximized');
    final original = window.window.rect;
    window.onMaximize();
    await tester.pumpAndSettle();
    window.onMinimize();
    await tester.pumpAndSettle();
    window.onMinimize();
    await tester.pumpAndSettle();
    expect(window.window.isMaximized, isTrue);
    window.onMaximize();
    await tester.pumpAndSettle();
    expect(window.window.rect, original);
  });

  testWidgets('the first click in an inactive window activates its button', (
    tester,
  ) async {
    final controller = await mountDesktop(tester);
    var clicks = 0;
    controller.openApp(
      DesktopApp(
        title: 'First',
        contentBuilder: (_) => Center(
          child: ElevatedButton(
            onPressed: () => clicks++,
            child: const Text('Click once'),
          ),
        ),
      ),
    );
    controller.openApp(emptyApp('Second'));
    await tester.pumpAndSettle();
    expect(windowFor(tester, 'First').window.isFocused, isFalse);
    await tester.tap(find.text('Click once'));
    await tester.pumpAndSettle();
    expect(clicks, 1);
    expect(windowFor(tester, 'First').window.isFocused, isTrue);
  });

  testWidgets('a titleless window does not intercept controls at its top', (
    tester,
  ) async {
    final controller = await mountDesktop(tester, hasTitleBar: false);
    var clicks = 0;
    controller.openApp(
      DesktopApp(
        title: 'Titleless',
        contentBuilder: (_) => Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 28,
            child: TextButton(
              onPressed: () => clicks++,
              child: const Text('Top action'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top action'));
    await tester.pumpAndSettle();
    expect(clicks, 1);
  });

  testWidgets('scrolling app content does not scroll or zoom the desktop', (
    tester,
  ) async {
    final controller = await mountDesktop(tester);
    final contentScroll = ScrollController();
    addTearDown(contentScroll.dispose);
    controller.openApp(
      DesktopApp(
        title: 'Scrollable app',
        contentBuilder: (_) => ListView.builder(
          controller: contentScroll,
          itemExtent: 48,
          itemCount: 100,
          itemBuilder: (_, index) => Text('Item $index'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final horizontal = scrollFor(tester, Axis.horizontal);
    final vertical = scrollFor(tester, Axis.vertical);
    final before = Offset(horizontal.offset, vertical.offset);
    final position = tester.getCenter(find.text('Item 3'));
    await tester.sendEventToBinding(
      PointerScrollEvent(position: position, scrollDelta: const Offset(0, 100)),
    );
    await tester.pumpAndSettle();
    expect(contentScroll.offset, greaterThan(0));
    expect(Offset(horizontal.offset, vertical.offset), before);
    expect(windowFor(tester, 'Scrollable app').canvasScale, 1);
    final savedScrollOffset = contentScroll.offset;
    windowFor(tester, 'Scrollable app').onMinimize();
    await tester.pumpAndSettle();
    windowFor(tester, 'Scrollable app').onMinimize();
    await tester.pumpAndSettle();
    expect(contentScroll.offset, savedScrollOffset);
    expect(tester.takeException(), isNull);
  });
}

class _StatefulContent extends StatefulWidget {
  final VoidCallback onInit;
  final VoidCallback onDispose;
  final VoidCallback onTick;

  const _StatefulContent({
    required this.onInit,
    required this.onDispose,
    required this.onTick,
  });

  @override
  State<_StatefulContent> createState() => _StatefulContentState();
}

class _CountingPainter extends CustomPainter {
  final VoidCallback onPaint;

  _CountingPainter(this.onPaint);

  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.blue);
  }

  @override
  bool shouldRepaint(_CountingPainter oldDelegate) => false;
}

class _StatefulContentState extends State<_StatefulContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation;

  @override
  void initState() {
    super.initState();
    widget.onInit();
    animation =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(widget.onTick)
          ..repeat();
  }

  @override
  void dispose() {
    animation.dispose();
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Material(
    child: Align(alignment: Alignment.topCenter, child: TextField()),
  );
}
