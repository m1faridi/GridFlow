import 'package:flutter/material.dart';
import 'models.dart';

class GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const double step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ConnectionsPainter extends CustomPainter {
  final List<WindowItem> windows;
  ConnectionsPainter(this.windows);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final Set<String> groupIds = windows.map((w) => w.groupId).toSet();

    for (String gId in groupIds) {
      final List<WindowItem> groupMembers = windows.where((w) => w.groupId == gId).toList();
      if (groupMembers.length < 2) continue;

      for (int i = 0; i < groupMembers.length - 1; i++) {
        final current = groupMembers[i];
        final next = groupMembers[i + 1];
        double opacity = (current.isMinimized || next.isMinimized) ? 0.2 : 0.7;
        final Color linkColor = next.themeColor;
        final start = current.rect.center;
        final end = next.rect.center;

        final path = Path();
        path.moveTo(start.dx, start.dy);
        final controlPoint1 = Offset(start.dx, (start.dy + end.dy) / 2);
        final controlPoint2 = Offset(end.dx, (start.dy + end.dy) / 2);
        path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, end.dx, end.dy);

        canvas.drawPath(path, paint..color = Colors.black.withOpacity(0.5)..strokeWidth = 4);
        canvas.drawPath(path, paint..color = linkColor.withOpacity(opacity)..strokeWidth = 2.5);
        canvas.drawCircle(start, 4, Paint()..color = current.themeColor);
        canvas.drawCircle(end, 4, Paint()..color = next.themeColor);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ConnectionsPainter oldDelegate) => true;
}