import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_flow/src/models.dart';
import 'package:grid_flow/src/window_widget.dart';

void main() {
  for (final hasTitleBar in [true, false]) {
    testWidgets(
      'focus and movement preserve content paints (title bar: $hasTitleBar)',
      (WidgetTester tester) async {
        int contentPaints = 0;
        final window = WindowItem(
          id: 'window',
          groupId: 'group',
          title: 'Window',
          themeColor: Colors.blue,
          hasTitleBar: hasTitleBar,
          content: CustomPaint(
            painter: _CountingPainter(() => contentPaints++),
            child: const SizedBox.expand(),
          ),
          rect: const Rect.fromLTWH(80, 80, 300, 240),
        );

        Widget buildDesktop() => MaterialApp(
          home: Stack(
            children: [
              FastWindow(
                window: window,
                desktopSize: const Size(800, 600),
                padding: EdgeInsets.zero,
                onFocus: () {},
                onClose: () {},
                onMaximize: () {},
                onMinimize: () {},
                onUpdate: (_) {},
                onDragStart: () {},
                onDragUpdate: (_) {},
                onDragEnd: () {},
              ),
            ],
          ),
        );

        await tester.pumpWidget(buildDesktop());
        await tester.pumpAndSettle();
        expect(contentPaints, greaterThan(0));
        final initialPaints = contentPaints;

        window.isFocused = false;
        await tester.pumpWidget(buildDesktop());
        for (int frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(contentPaints, initialPaints);

        window.rect = window.rect.shift(const Offset(30, 20));
        await tester.pumpWidget(buildDesktop());
        expect(contentPaints, initialPaints);

        window.rect = Rect.fromLTWH(
          window.rect.left,
          window.rect.top,
          window.rect.width + 40,
          window.rect.height + 20,
        );
        await tester.pumpWidget(buildDesktop());
        expect(contentPaints, greaterThan(initialPaints));
        expect(tester.takeException(), isNull);
      },
    );
  }
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
