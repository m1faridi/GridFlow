import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'models.dart';

class GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03) // کمرنگ‌تر و شیک‌تر
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const double step = 40.0;

    // کشیدن نقاط تقاطع به جای خط کامل (مثل طراحی‌های مدرن)
    // یا خطوط خیلی محو
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
  final Animation<double> animation; // دریافت انیمیشن برای حرکت جریان

  ConnectionsPainter(this.windows, this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. گروه‌بندی پنجره‌ها
    final Map<String, List<WindowItem>> groups = {};
    for (var w in windows) {
      if (w.connectionTag != null) {
        if (!groups.containsKey(w.connectionTag!)) {
          groups[w.connectionTag!] = [];
        }
        groups[w.connectionTag!]!.add(w);
      }
    }

    // 2. رسم خطوط
    groups.forEach((tag, groupMembers) {
      if (groupMembers.length < 2) return;

      // مرتب‌سازی بر اساس موقعیت برای پیدا کردن بهترین مسیر
      groupMembers.sort((a, b) => (a.rect.top + a.rect.left).compareTo(b.rect.top + b.rect.left));

      // الگوریتم "نزدیک‌ترین همسایه" (Nearest Neighbor)
      // این بخش تضمین می‌کند خطوط کوتاه و مرتب باشند
      List<WindowItem> pathNodes = [];
      List<WindowItem> pool = List.from(groupMembers);
      WindowItem current = pool.removeAt(0);
      pathNodes.add(current);

      while (pool.isNotEmpty) {
        WindowItem? nearest;
        double minDistance = double.infinity;
        for (var candidate in pool) {
          double d = (current.rect.center - candidate.rect.center).distance;
          if (d < minDistance) {
            minDistance = d;
            nearest = candidate;
          }
        }
        if (nearest != null) {
          pathNodes.add(nearest);
          pool.remove(nearest);
          current = nearest;
        } else {
          break;
        }
      }

      // رسم مسیر
      for (int i = 0; i < pathNodes.length - 1; i++) {
        final startWin = pathNodes[i];
        final endWin = pathNodes[i + 1];

        // محاسبه نقاط اتصال هوشمند
        final anchors = _getSmartAnchors(startWin.rect, endWin.rect);
        final start = anchors.start;
        final end = anchors.end;

        // ساخت منحنی Bezier
        final path = Path();
        path.moveTo(start.dx, start.dy);

        bool isHorizontal = (start.dx - end.dx).abs() > (start.dy - end.dy).abs();
        double curveAmount = 80.0; // انحنای بیشتر برای نرمی بیشتر
        Offset c1, c2;

        if (isHorizontal) {
          double dir = (end.dx > start.dx) ? 1 : -1;
          c1 = Offset(start.dx + (curveAmount * dir), start.dy);
          c2 = Offset(end.dx - (curveAmount * dir), end.dy);
        } else {
          double dir = (end.dy > start.dy) ? 1 : -1;
          c1 = Offset(start.dx, start.dy + (curveAmount * dir));
          c2 = Offset(end.dx, end.dy - (curveAmount * dir));
        }

        // اگر خیلی نزدیک باشند، انحنا را اصلاح می‌کنیم
        if ((start - end).distance < 150) {
          path.cubicTo(
              (start.dx + end.dx) / 2, start.dy,
              (start.dx + end.dx) / 2, end.dy,
              end.dx, end.dy
          );
        } else {
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
        }

        // --- افکت‌های گرافیکی حرفه‌ای ---

        // 1. Glow Effect (سایه نئونی زیر خط)
        // رنگی همرنگ تم پنجره ولی شفاف‌تر و پهن‌تر
        final glowPaint = Paint()
          ..color = endWin.themeColor.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4); // بلور کردن برای افکت نئون

        canvas.drawPath(path, glowPaint);

        // 2. Animated Gradient Flow (جریان متحرک)
        // این گرادینت باعث می‌شود به نظر برسد دیتا دارد حرکت می‌کند
        final Rect pathBounds = path.getBounds();

        // ایجاد یک Shader متحرک
        // با استفاده از animation.value موقعیت رنگ‌ها را تغییر می‌دهیم
        final List<Color> colors = [
          endWin.themeColor,
          Colors.white,
          endWin.themeColor,
        ];

        // محاسبه Shift برای حرکت
        final double shift = animation.value;
        final List<double> stops = [
          0.0,
          shift, // رنگ سفید در طول خط حرکت می‌کند
          1.0,
        ];

        // اگر بخواهیم خیلی حرفه‌ای شود، از createShader روی خود Path استفاده می‌کنیم
        // اما Linear ساده‌تر و سریع‌تر است
        final mainPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(
              start,
              end,
              [endWin.themeColor, Colors.white.withOpacity(0.8), endWin.themeColor],
              [0.0, animation.value, 1.0], // انیمیشن ساده
              TileMode.clamp
          );

        // روش پیشرفته‌تر: Flow Animation (تکه‌های متحرک)
        // اگر بخواهیم خط‌چین‌های متحرک داشته باشیم:
        _drawAnimatedDashedLine(canvas, path, endWin.themeColor, animation.value);

        // دایره‌های اتصال (Anchor Points)
        canvas.drawCircle(start, 4, Paint()..color = Colors.white);
        canvas.drawCircle(start, 2, Paint()..color = startWin.themeColor);

        canvas.drawCircle(end, 4, Paint()..color = Colors.white);
        canvas.drawCircle(end, 2, Paint()..color = endWin.themeColor);
      }
    });
  }

  // متد کمکی برای رسم خط‌چین‌های متحرک روی مسیر منحنی
  void _drawAnimatedDashedLine(Canvas canvas, Path path, Color color, double animValue) {
    // متریک مسیر برای محاسبه طول
    final ui.PathMetrics pathMetrics = path.computeMetrics();

    for (ui.PathMetric metric in pathMetrics) {
      final double length = metric.length;
      const double dashWidth = 10.0;
      const double dashSpace = 10.0;

      // محاسبه آفست شروع بر اساس انیمیشن
      // animValue بین 0 و 1 است. ضرب در (dashWidth + dashSpace) باعث حرکت نرم می‌شود
      double startOffset = -(animValue * (dashWidth + dashSpace));

      while (startOffset < length) {
        // فقط اگر داخل محدوده مسیر است رسم کن
        double drawStart = max(startOffset, 0.0);
        double drawEnd = min(startOffset + dashWidth, length);

        if (drawEnd > drawStart) {
          final Path dashPath = metric.extractPath(drawStart, drawEnd);
          canvas.drawPath(dashPath, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.5);
        }
        startOffset += (dashWidth + dashSpace);
      }
    }
  }

  ({Offset start, Offset end}) _getSmartAnchors(Rect from, Rect to) {
    Offset centerFrom = from.center;
    Offset centerTo = to.center;

    double dx = centerTo.dx - centerFrom.dx;
    double dy = centerTo.dy - centerFrom.dy;

    Offset startPoint;
    Offset endPoint;

    // تشخیص جهت با حاشیه اطمینان (Hysteresis) برای جلوگیری از پرش‌های ناگهانی
    if (dx.abs() > dy.abs() * 1.2) { // اگر تفاوت افقی معنادار است
      if (dx > 0) {
        startPoint = from.centerRight;
        endPoint = to.centerLeft;
      } else {
        startPoint = from.centerLeft;
        endPoint = to.centerRight;
      }
    } else {
      if (dy > 0) {
        startPoint = from.bottomCenter;
        endPoint = to.topCenter;
      } else {
        startPoint = from.topCenter;
        endPoint = to.bottomCenter;
      }
    }
    return (start: startPoint, end: endPoint);
  }

  @override
  bool shouldRepaint(covariant ConnectionsPainter oldDelegate) => true; // چون انیمیشن داریم باید ریپینت شود
}