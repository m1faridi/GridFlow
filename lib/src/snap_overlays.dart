import 'dart:ui'; // برای استفاده از ImageFilter
import 'package:flutter/material.dart';
import 'models.dart';

class SnapPreviewOverlay extends StatelessWidget {
  final SnapRegion region;
  final Size screenSize;
  final EdgeInsets padding;

  const SnapPreviewOverlay({
    super.key,
    required this.region,
    required this.screenSize,
    required this.padding
  });

  @override
  Widget build(BuildContext context) {
    Rect target;
    final w = screenSize.width - padding.left - padding.right;
    final h = screenSize.height - padding.top - padding.bottom;
    final startX = padding.left;
    final startY = padding.top;
    final hw = w / 2, hh = h / 2, tw = w / 3;
    const p = 12.0;

    switch (region) {
      case SnapRegion.left: target = Rect.fromLTWH(startX + p, startY + p, hw - 2 * p, h - 2 * p); break;
      case SnapRegion.right: target = Rect.fromLTWH(startX + hw + p, startY + p, hw - 2 * p, h - 2 * p); break;
      case SnapRegion.top: target = Rect.fromLTWH(startX + p, startY + p, w - 2 * p, h - 2 * p); break;
      case SnapRegion.topLeft: target = Rect.fromLTWH(startX + p, startY + p, hw - 2 * p, hh - 2 * p); break;
      case SnapRegion.topRight: target = Rect.fromLTWH(startX + hw + p, startY + p, hw - 2 * p, hh - 2 * p); break;
      case SnapRegion.bottomLeft: target = Rect.fromLTWH(startX + p, startY + hh + p, hw - 2 * p, hh - 2 * p); break;
      case SnapRegion.bottomRight: target = Rect.fromLTWH(startX + hw + p, startY + hh + p, hw - 2 * p, hh - 2 * p); break;
      case SnapRegion.leftThird: target = Rect.fromLTWH(startX + p, startY + p, tw - 2 * p, h - 2 * p); break;
      case SnapRegion.centerThird: target = Rect.fromLTWH(startX + tw + p, startY + p, tw - 2 * p, h - 2 * p); break;
      case SnapRegion.rightThird: target = Rect.fromLTWH(startX + tw * 2 + p, startY + p, tw - 2 * p, h - 2 * p); break;
      default: target = Rect.zero;
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutQuad,
      left: target.left,
      top: target.top,
      width: target.width,
      height: target.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15), // شیشه‌ای روشن برای پیش‌نمایش
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

class StaticSnapBar extends StatelessWidget {
  final SnapRegion activeRegion;
  final bool isVertical;

  const StaticSnapBar({
    super.key,
    required this.activeRegion,
    this.isVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    // لیست آیتم‌ها
    final items = [
      SnapIcon(Icons.splitscreen, SnapRegion.left, activeRegion),
      const SizedBox(width: 4, height: 4),
      SnapIcon(Icons.splitscreen, SnapRegion.right, activeRegion, rotate: true),

      // خط جداکننده شیشه‌ای
      Container(
        height: isVertical ? 1 : 24,
        width: isVertical ? 24 : 1,
        color: Colors.white.withOpacity(0.3), // رنگ خط مات‌تر
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      SnapIcon(Icons.view_column, SnapRegion.leftThird, activeRegion),
      const SizedBox(width: 4, height: 4),
      SnapIcon(Icons.view_week, SnapRegion.centerThird, activeRegion),
      const SizedBox(width: 4, height: 4),
      SnapIcon(Icons.view_column, SnapRegion.rightThird, activeRegion, rotate: true),

      Container(
        height: isVertical ? 1 : 24,
        width: isVertical ? 24 : 1,
        color: Colors.white.withOpacity(0.3),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      SnapIcon(Icons.crop_square, SnapRegion.top, activeRegion),
    ];

    // --- پیاده‌سازی افکت Glassmorphism ---
    return ClipRRect(
      borderRadius: BorderRadius.circular(24), // گوشه‌های گردتر مثل اپل
      child: BackdropFilter(
        // مقدار تاری پس‌زمینه (Blur)
        filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            // رنگ سفید با شفافیت کم
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(24),
            // حاشیه سفید خیلی ظریف برای براق نشان دادن لبه‌ها
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            // سایه نرم و گسترده
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Flex(
            direction: isVertical ? Axis.vertical : Axis.horizontal,
            mainAxisSize: MainAxisSize.min,
            children: items,
          ),
        ),
      ),
    );
  }
}

class SnapIcon extends StatelessWidget {
  final IconData icon;
  final SnapRegion targetRegion;
  final SnapRegion activeRegion;
  final bool rotate;

  const SnapIcon(this.icon, this.targetRegion, this.activeRegion, {super.key, this.rotate = false});

  @override
  Widget build(BuildContext context) {
    final bool isActive = targetRegion == activeRegion;

    // رنگ‌ها برای حالت شیشه‌ای باید کمی زنده‌تر باشند
    final Color activeBg = Colors.white.withOpacity(0.4);
    final Color activeBorder = Colors.white.withOpacity(0.8);
    final Color inactiveIcon = Colors.black.withOpacity(0.6); // آیکون تیره روی شیشه روشن
    final Color activeIconColor = Colors.black87;

    return AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isActive ? activeBorder : Colors.transparent,
              width: 1.5
          ),
          // سایه ملایم وقتی انتخاب می‌شود
          boxShadow: isActive ? [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, spreadRadius: 1)
          ] : [],
        ),
        child: Transform.rotate(
            angle: rotate ? 3.14 : 0,
            child: Icon(
                icon,
                color: isActive ? activeIconColor : inactiveIcon,
                size: 22
            )
        )
    );
  }
}