import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_flow/grid_os.dart';
import 'package:grid_flow/src/painters.dart';
import 'package:grid_flow/src/window_widget.dart';

void main() {
  for (final customBackground in [false, true]) {
    testWidgets(
      'connections and background track zoomed windows while scrolling '
      '(custom background: $customBackground)',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const firstContent = ValueKey('first-content');
        const secondContent = ValueKey('second-content');
        const backgroundKey = ValueKey('background');
        await tester.pumpWidget(
          MaterialApp(
            home: GridDesktop(
              apps: const [],
              hasTitleBar: false,
              background: customBackground
                  ? const SizedBox.expand(key: backgroundKey)
                  : null,
              autoStartApps: [
                DesktopApp(
                  title: 'First',
                  connectionTag: 'linked',
                  contentBuilder: (_) =>
                      const SizedBox.expand(key: firstContent),
                ),
                DesktopApp(
                  title: 'Second',
                  connectionTag: 'linked',
                  contentBuilder: (_) =>
                      const SizedBox.expand(key: secondContent),
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        ScrollController controllerFor(Axis axis) => tester
            .widgetList<SingleChildScrollView>(
              find.byType(SingleChildScrollView),
            )
            .singleWhere((scrollView) => scrollView.scrollDirection == axis)
            .controller!;
        final horizontal = controllerFor(Axis.horizontal);
        final vertical = controllerFor(Axis.vertical);
        final origin = Offset(horizontal.offset, vertical.offset);
        final windows = tester
            .widgetList<FastWindow>(find.byType(FastWindow))
            .toList();
        windows[0].onUpdate(
          Rect.fromLTWH(origin.dx + 180, origin.dy + 200, 240, 200),
        );
        windows[1].onUpdate(
          Rect.fromLTWH(origin.dx + 660, origin.dy + 280, 240, 200),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        void expectAligned() {
          final connectionFinder = find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint && widget.painter is ConnectionsPainter,
          );
          final connectionWidget = tester.widget<CustomPaint>(connectionFinder);
          final connectionPainter =
              connectionWidget.painter! as ConnectionsPainter;
          final connectionOrigin = tester.getTopLeft(connectionFinder);
          final connectionSize = tester.getSize(connectionFinder);
          expect(connectionSize, const Size(1200, 900));
          expect(connectionPainter.hasVisibleConnections, isTrue);

          final canvas = _AnchorCanvas();
          connectionPainter.paint(canvas, connectionSize);
          expect(canvas.anchors, hasLength(4));
          final firstRect = tester.getRect(find.byKey(firstContent));
          final secondRect = tester.getRect(find.byKey(secondContent));
          // Compare the actual painted anchors against the render-tree edges,
          // independently of the painter's viewport calculations.
          expect(
            canvas.anchors.first + connectionOrigin,
            offsetMoreOrLessEquals(firstRect.centerRight),
          );
          expect(
            canvas.anchors.last + connectionOrigin,
            offsetMoreOrLessEquals(secondRect.centerLeft),
          );

          final liveWindows = tester
              .widgetList<FastWindow>(find.byType(FastWindow))
              .toList();
          final Offset gridOrigin;
          final double gridScale;
          if (customBackground) {
            gridOrigin = tester.getTopLeft(find.byKey(backgroundKey));
            gridScale = liveWindows.first.canvasScale;
          } else {
            final gridFinder = find.byWidgetPredicate(
              (widget) =>
                  widget is CustomPaint && widget.painter is GridPatternPainter,
            );
            final gridPainter =
                tester.widget<CustomPaint>(gridFinder).painter!
                    as GridPatternPainter;
            gridOrigin =
                tester.getTopLeft(gridFinder) + gridPainter.translation;
            gridScale = gridPainter.scale;
          }
          for (var index = 0; index < liveWindows.length; index++) {
            final contentRect = index == 0 ? firstRect : secondRect;
            expect(
              gridOrigin + liveWindows[index].window.rect.topLeft * gridScale,
              offsetMoreOrLessEquals(contentRect.topLeft),
            );
          }
        }

        expectAligned();
        await tester.tap(find.byTooltip('Zoom in'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('125%'), findsOneWidget);
        expectAligned();

        horizontal.jumpTo(horizontal.offset + 73);
        vertical.jumpTo(vertical.offset + 41);
        await tester.pump();
        expectAligned();

        await tester.tap(find.byTooltip('Zoom out'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byTooltip('Zoom out'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('80%'), findsOneWidget);
        horizontal.jumpTo(horizontal.offset - 31);
        vertical.jumpTo(vertical.offset + 17);
        await tester.pump();
        expectAligned();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

/// Records anchor positions after the same canvas transforms used to paint.
class _AnchorCanvas implements Canvas {
  final anchors = <Offset>[];
  final _savedTransforms = <Matrix4>[];
  Matrix4 _transform = Matrix4.identity();

  @override
  void save() => _savedTransforms.add(Matrix4.copy(_transform));

  @override
  void restore() => _transform = _savedTransforms.removeLast();

  @override
  void scale(double sx, [double? sy]) {
    _transform.multiply(Matrix4.diagonal3Values(sx, sy ?? sx, 1));
  }

  @override
  void translate(double dx, double dy) {
    _transform.multiply(Matrix4.translationValues(dx, dy, 0));
  }

  @override
  void drawCircle(Offset center, double radius, Paint paint) {
    anchors.add(MatrixUtils.transformPoint(_transform, center));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
