import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_flow/src/models.dart';
import 'package:grid_flow/src/painters.dart';

WindowItem _window(String id, Rect rect, {String? tag = 'linked'}) {
  return WindowItem(
    id: id,
    groupId: id,
    title: id,
    themeColor: Colors.blue,
    content: const SizedBox.shrink(),
    rect: rect,
    connectionTag: tag,
  );
}

class _RecordingCanvas implements Canvas {
  final paths = <Path>[];
  final linePoints = <Offset>[];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    linePoints.addAll([p1, p2]);
  }

  @override
  void drawPath(Path path, Paint paint) => paths.add(path);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<List<int>> _render(
  List<WindowItem> windows,
  Rect viewport, {
  required bool cropped,
  double scale = 1,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(viewport.width * scale, viewport.height * scale);
  canvas.clipRect(Offset.zero & size);
  if (!cropped) {
    canvas.scale(scale);
    canvas.translate(-viewport.left, -viewport.top);
  }
  ConnectionsPainter(
    windows,
    viewport: cropped ? viewport : null,
    scale: scale,
  ).paint(canvas, cropped ? size : const Size(2000, 2000));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.ceil(), size.height.ceil());
  final bytes = await image.toByteData();
  final pixels = bytes!.buffer.asUint8List().toList();
  image.dispose();
  picture.dispose();
  return pixels;
}

void main() {
  test(
    'grid painting handles invalid camera values without unbounded loops',
    () {
      for (final painter in [
        const GridPatternPainter(scale: double.nan),
        const GridPatternPainter(scale: double.infinity),
        const GridPatternPainter(baseStep: double.infinity),
        const GridPatternPainter(scale: 1e308, baseStep: 1e308),
        const GridPatternPainter(baseStep: 1e308),
        const GridPatternPainter(
          translation: Offset(double.infinity, double.nan),
        ),
      ]) {
        final canvas = _RecordingCanvas();
        painter.paint(canvas, const Size(800, 600));
        expect(canvas.linePoints, isNotEmpty);
        expect(canvas.linePoints.every((point) => point.isFinite), isTrue);
        expect(canvas.linePoints.length, lessThan(1000));
      }
      final canvas = _RecordingCanvas();
      const GridPatternPainter().paint(canvas, Size.infinite);
      expect(canvas.linePoints, isEmpty);
    },
  );

  test('static connections reuse geometry and keep dash positions across paints and builds', () {
    final windows = [
      _window('a', const Rect.fromLTWH(0, 0, 100, 100)),
      _window('b', const Rect.fromLTWH(400, 200, 100, 100)),
    ];
    final first = ConnectionsPainter(windows);
    final firstCanvas = _RecordingCanvas();
    first.paint(firstCanvas, const Size(800, 600));
    first.paint(firstCanvas, const Size(800, 600));
    expect(firstCanvas.paths, hasLength(4));
    expect(identical(firstCanvas.paths[0], firstCanvas.paths[2]), isTrue);
    expect(identical(firstCanvas.paths[1], firstCanvas.paths[3]), isTrue);
    final firstDashes = firstCanvas.paths[1].computeMetrics().toList();
    final repeatedDashes = firstCanvas.paths[3].computeMetrics().toList();
    expect(repeatedDashes.length, firstDashes.length);
    for (var i = 0; i < firstDashes.length; i++) {
      expect(repeatedDashes[i].length, firstDashes[i].length);
      expect(
        repeatedDashes[i].getTangentForOffset(0)!.position,
        firstDashes[i].getTangentForOffset(0)!.position,
      );
    }

    windows.first.title = 'Renamed';
    final second = ConnectionsPainter(
      windows,
      previousPainter: first,
      viewport: const Rect.fromLTWH(0, 0, 800, 600),
    );
    final secondCanvas = _RecordingCanvas();
    second.paint(secondCanvas, const Size(800, 600));
    expect(identical(firstCanvas.paths[0], secondCanvas.paths[0]), isTrue);

    final equivalent = ConnectionsPainter(windows);
    expect(equivalent.shouldRepaint(first), isFalse);
    windows.first.rect = const Rect.fromLTWH(10, 10, 100, 100);
    final moved = ConnectionsPainter(windows, previousPainter: first);
    expect(moved.shouldRepaint(first), isTrue);
    final movedCanvas = _RecordingCanvas();
    moved.paint(movedCanvas, const Size(800, 600));
    expect(identical(firstCanvas.paths[0], movedCanvas.paths[0]), isFalse);
  });

  test('color changes invalidate cached connection geometry', () {
    final windows = [
      _window('a', const Rect.fromLTWH(0, 0, 100, 100)),
      _window('b', const Rect.fromLTWH(400, 200, 100, 100)),
    ];
    final before = ConnectionsPainter(windows);
    windows.last.themeColor = Colors.red;
    final after = ConnectionsPainter(windows, previousPainter: before);
    expect(after.shouldRepaint(before), isTrue);
  });

  test('offscreen and unconnected windows do not draw connections', () {
    const viewport = Rect.fromLTWH(0, 0, 800, 600);
    expect(
      ConnectionsPainter([], viewport: viewport).hasVisibleConnections,
      isFalse,
    );
    final windows = [
      _window('a', const Rect.fromLTWH(2000, 2000, 100, 100)),
      _window('b', const Rect.fromLTWH(2400, 2200, 100, 100)),
      _window('c', const Rect.fromLTWH(0, 0, 100, 100), tag: null),
    ];
    final painter = ConnectionsPainter(windows, viewport: viewport);
    expect(painter.hasVisibleConnections, isFalse);
    final canvas = _RecordingCanvas();
    painter.paint(canvas, viewport.size);
    expect(canvas.paths, isEmpty);
  });

  test('far apart links only generate dashes near the viewport', () {
    final painter = ConnectionsPainter([
      _window('a', const Rect.fromLTWH(0, 0, 100, 100)),
      _window('b', const Rect.fromLTWH(1000000, 0, 100, 100)),
    ], viewport: const Rect.fromLTWH(500000, 0, 800, 600));
    expect(painter.hasVisibleConnections, isTrue);
    final canvas = _RecordingCanvas();
    painter.paint(canvas, const Size(800, 600));
    expect(canvas.paths, hasLength(2));
    final dashes = canvas.paths.last;
    expect(dashes.computeMetrics().length, lessThan(50));
    expect(dashes.getBounds().left, greaterThanOrEqualTo(499980));
    expect(dashes.getBounds().right, lessThanOrEqualTo(500820));
  });

  testWidgets(
    'viewport cropping preserves curved connections at different scales',
    (tester) async {
      final windows = [
        _window('a', const Rect.fromLTWH(100, 100, 100, 100)),
        _window('b', const Rect.fromLTWH(650, 450, 100, 100)),
      ];
      for (final viewport in [
        const Rect.fromLTWH(200, 150, 150, 150),
        const Rect.fromLTWH(300, 250, 150, 150),
        const Rect.fromLTWH(500, 350, 150, 150),
      ]) {
        for (final scale in [0.5, 1.0, 2.0]) {
          final full = await tester.runAsync(
            () => _render(windows, viewport, cropped: false, scale: scale),
          );
          final cropped = await tester.runAsync(
            () => _render(windows, viewport, cropped: true, scale: scale),
          );
          final differences = List.generate(
            full!.length,
            (i) => (full[i] - cropped![i]).abs(),
          );
          final totalDifference = differences.fold<int>(
            0,
            (sum, value) => sum + value,
          );
          final maxDifference = differences.reduce((a, b) => a > b ? a : b);
          // Path batching can vary antialiasing slightly when offscreen dashes
          // are removed, while the visible geometry must stay the same.
          expect(
            totalDifference / differences.length,
            lessThan(0.1),
            reason: '$viewport at $scale; max $maxDifference',
          );
          expect(
            maxDifference,
            lessThanOrEqualTo(8),
            reason: '$viewport at $scale',
          );
        }
      }
    },
  );
}
