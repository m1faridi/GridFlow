import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'models.dart';

class GridPatternPainter extends CustomPainter {
  final double scale;
  final Offset translation;
  final double baseStep;
  final Color lineColor;

  const GridPatternPainter({
    this.scale = 1.0,
    this.translation = Offset.zero,
    this.baseStep = 100.0,
    this.lineColor = const Color(0x08FFFFFF),
  });

  double _startLine(double offset, double step) {
    final double mod = (offset.isFinite ? offset : 0) % step;
    return mod <= 0 ? mod : mod - step;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.isFinite) return;
    final double normalizedScale = scale.isFinite && scale > 0 ? scale : 1.0;
    final double normalizedStep = baseStep.isFinite ? baseStep : 100.0;
    final double scaledStep = normalizedStep * normalizedScale;
    final double minorStep = scaledStep.isFinite ? max(6.0, scaledStep) : 100.0;
    final double majorStep = min(minorStep, double.maxFinite / 4) * 4;

    final Rect full = Offset.zero & size;
    final Paint basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF171B22), Color(0xFF11161D), Color(0xFF0D1118)],
        stops: [0.0, 0.45, 1.0],
      ).createShader(full);
    canvas.drawRect(full, basePaint);

    final Paint minorGridPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.50;

    final Paint majorGridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.01)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.15;

    final double minorStartX = _startLine(translation.dx, minorStep);
    final double minorStartY = _startLine(translation.dy, minorStep);

    for (double x = minorStartX; x <= size.width; x += minorStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorGridPaint);
    }
    for (double y = minorStartY; y <= size.height; y += minorStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minorGridPaint);
    }

    final double majorStartX = _startLine(translation.dx, majorStep);
    final double majorStartY = _startLine(translation.dy, majorStep);

    for (double x = majorStartX; x <= size.width; x += majorStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), majorGridPaint);
    }
    for (double y = majorStartY; y <= size.height; y += majorStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), majorGridPaint);
    }

    final Paint vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.05,
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.28)],
        stops: const [0.62, 1.0],
      ).createShader(full);
    canvas.drawRect(full, vignettePaint);
  }

  @override
  bool shouldRepaint(covariant GridPatternPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.translation != translation ||
        oldDelegate.baseStep != baseStep ||
        oldDelegate.lineColor != lineColor;
  }
}

typedef _ConnectionWindow = ({String id, String tag, Rect rect, Color color});

class ConnectionsPainter extends CustomPainter {
  final List<WindowItem> windows;
  final Animation<double> animation;

  /// The visible world rectangle, painted into the local viewport at [scale].
  /// Without a viewport, paths retain their original world coordinates.
  final Rect? viewport;
  final double scale;
  final List<_ConnectionWindow> _windowSnapshots;
  late final List<_ConnectionPath> _connections;
  late final List<_VisibleConnection> _visibleConnections = _findVisiblePaths();

  ConnectionsPainter(
    this.windows,
    this.animation, {
    this.viewport,
    this.scale = 1,
    ConnectionsPainter? previousPainter,
  }) : _windowSnapshots = [
         for (final window in windows)
           if (window.connectionTag != null &&
               !window.isMaximized &&
               window.rect.isFinite)
             (
               id: window.id,
               tag: window.connectionTag!,
               rect: window.rect,
               color: window.themeColor,
             ),
       ],
       super(repaint: animation) {
    // WindowItem is mutable: retain values rather than the model references so
    // moving a window invalidates the cache even when the list is unchanged.
    _connections =
        previousPainter != null &&
            listEquals(_windowSnapshots, previousPainter._windowSnapshots)
        ? previousPainter._connections
        : _buildConnections();
  }

  bool get hasVisibleConnections => _visibleConnections.isNotEmpty;

  double get _effectiveScale => scale.isFinite && scale > 0 ? scale : 1;

  List<_ConnectionPath> _buildConnections() {
    final groups = <String, List<_ConnectionWindow>>{};
    for (final window in _windowSnapshots) {
      (groups[window.tag] ??= []).add(window);
    }

    final connections = <_ConnectionPath>[];
    for (final members in groups.values) {
      if (members.length < 2) continue;
      members.sort(
        (a, b) =>
            (a.rect.top + a.rect.left).compareTo(b.rect.top + b.rect.left),
      );
      final pool = List<_ConnectionWindow>.of(members);
      var current = pool.removeAt(0);
      while (pool.isNotEmpty) {
        var nearestIndex = 0;
        var nearestDistance = double.infinity;
        for (var i = 0; i < pool.length; i++) {
          final distance =
              (current.rect.center - pool[i].rect.center).distanceSquared;
          if (distance < nearestDistance) {
            nearestIndex = i;
            nearestDistance = distance;
          }
        }
        final nearest = pool.removeAt(nearestIndex);
        connections.add(_makeConnection(current, nearest));
        current = nearest;
      }
    }
    return connections;
  }

  _ConnectionPath _makeConnection(
    _ConnectionWindow from,
    _ConnectionWindow to,
  ) {
    final anchors = _getSmartAnchors(from.rect, to.rect);
    final start = anchors.start;
    final end = anchors.end;
    final path = Path()..moveTo(start.dx, start.dy);
    final isHorizontal = (start.dx - end.dx).abs() > (start.dy - end.dy).abs();
    const curveAmount = 80.0;
    if ((start - end).distanceSquared < 150 * 150) {
      path.cubicTo(
        (start.dx + end.dx) / 2,
        start.dy,
        (start.dx + end.dx) / 2,
        end.dy,
        end.dx,
        end.dy,
      );
    } else if (isHorizontal) {
      final direction = end.dx > start.dx ? 1 : -1;
      path.cubicTo(
        start.dx + curveAmount * direction,
        start.dy,
        end.dx - curveAmount * direction,
        end.dy,
        end.dx,
        end.dy,
      );
    } else {
      final direction = end.dy > start.dy ? 1 : -1;
      path.cubicTo(
        start.dx,
        start.dy + curveAmount * direction,
        end.dx,
        end.dy - curveAmount * direction,
        end.dx,
        end.dy,
      );
    }
    return _ConnectionPath(path, start, end, from.color, to.color);
  }

  List<_VisibleConnection> _findVisiblePaths() {
    final visible = <_VisibleConnection>[];
    final clip = viewport?.inflate(16);
    if (clip != null && (!clip.isFinite || clip.isEmpty)) return visible;
    for (final connection in _connections) {
      final metric = connection.metric;
      if (metric == null || !metric.length.isFinite) continue;
      if (clip != null && !connection.bounds.overlaps(clip)) continue;

      var start = 0.0;
      var end = metric.length;
      final delta = connection.end - connection.start;
      final chordLength = delta.distance;
      if (clip != null && chordLength > 0) {
        final direction = delta / chordLength;
        var minProjection = double.infinity;
        var maxProjection = double.negativeInfinity;
        for (final corner in [
          clip.topLeft,
          clip.topRight,
          clip.bottomLeft,
          clip.bottomRight,
        ]) {
          final offset = corner - connection.start;
          final projection =
              offset.dx * direction.dx + offset.dy * direction.dy;
          minProjection = min(minProjection, projection);
          maxProjection = max(maxProjection, projection);
        }
        // For a point projected distance p along the chord, its arc distance s
        // obeys p <= s <= p + (pathLength - chordLength). This bounds dash work
        // to the visible part even when linked windows are very far apart.
        final excessLength = max(0.0, metric.length - chordLength);
        start = max(0.0, minProjection - 1);
        end = min(metric.length, maxProjection + excessLength + 1);
      }
      if (end > start) {
        visible.add(_VisibleConnection(connection, start, end));
      }
    }
    return visible;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_visibleConnections.isEmpty || size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (viewport case final viewport?) {
      canvas.scale(_effectiveScale);
      canvas.translate(-viewport.left, -viewport.top);
    }
    final value = animation.value;
    final phase = value.isFinite ? (value % 1) * 20 : 0.0;
    for (final visible in _visibleConnections) {
      final connection = visible.connection;
      canvas.drawPath(connection.path, connection.glowPaint);
      _drawAnimatedDashedLine(canvas, visible, phase);
      canvas.drawCircle(connection.start, 4, _ConnectionPath.anchorPaint);
      canvas.drawCircle(connection.start, 2, connection.startPaint);
      canvas.drawCircle(connection.end, 4, _ConnectionPath.anchorPaint);
      canvas.drawCircle(connection.end, 2, connection.endPaint);
    }
    canvas.restore();
  }

  void _drawAnimatedDashedLine(
    Canvas canvas,
    _VisibleConnection visible,
    double phase,
  ) {
    final connection = visible.connection;
    final metric = connection.metric!;
    const dashWidth = 10.0;
    const dashPeriod = 20.0;
    var offset =
        ((visible.start + phase) / dashPeriod).floor() * dashPeriod - phase;
    // One paint and one draw operation per connection, rather than a Paint and
    // canvas draw for every dash. Extracted fragments never leave the viewport.
    final dashes = Path();
    while (offset < visible.end) {
      final start = max(offset, visible.start);
      final end = min(offset + dashWidth, visible.end);
      if (end > start) {
        dashes.addPath(metric.extractPath(start, end), Offset.zero);
      }
      offset += dashPeriod;
    }
    canvas.drawPath(dashes, connection.dashPaint);
  }

  ({Offset start, Offset end}) _getSmartAnchors(Rect from, Rect to) {
    final delta = to.center - from.center;
    if (delta.dx.abs() > delta.dy.abs() * 1.2) {
      return delta.dx > 0
          ? (start: from.centerRight, end: to.centerLeft)
          : (start: from.centerLeft, end: to.centerRight);
    }
    return delta.dy > 0
        ? (start: from.bottomCenter, end: to.topCenter)
        : (start: from.topCenter, end: to.bottomCenter);
  }

  @override
  bool shouldRepaint(covariant ConnectionsPainter oldDelegate) {
    return viewport != oldDelegate.viewport ||
        _effectiveScale != oldDelegate._effectiveScale ||
        animation != oldDelegate.animation ||
        !listEquals(_windowSnapshots, oldDelegate._windowSnapshots);
  }
}

class _ConnectionPath {
  static final anchorPaint = Paint()..color = Colors.white;
  final Path path;
  final Offset start;
  final Offset end;
  final Rect bounds;
  final ui.PathMetric? metric;
  final Paint glowPaint;
  final Paint dashPaint;
  final Paint startPaint;
  final Paint endPaint;

  _ConnectionPath(
    this.path,
    this.start,
    this.end,
    Color startColor,
    Color endColor,
  ) : bounds = path.getBounds().inflate(16),
      metric = path.computeMetrics().firstOrNull,
      glowPaint = (Paint()
        ..color = endColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)),
      dashPaint = (Paint()
        ..color = endColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5),
      startPaint = (Paint()..color = startColor),
      endPaint = (Paint()..color = endColor);
}

class _VisibleConnection {
  final _ConnectionPath connection;
  final double start;
  final double end;

  const _VisibleConnection(this.connection, this.start, this.end);
}
