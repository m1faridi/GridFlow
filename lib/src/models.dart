import 'package:flutter/material.dart';

enum SnapRegion {
  none, left, right, top,
  topLeft, topRight, bottomLeft, bottomRight,
  leftThird, centerThird, rightThird
}

class DesktopApp {
  final String title;
  final IconData icon;
  final Color color;
  final Widget Function(String id)? contentBuilder;
  final String? connectionTag;
  final bool isClosable;
  DesktopApp({
    required this.title,
    required this.icon,
    Color? color, // ۱. این پارامتر را اختیاری کردیم (nullable)
    this.contentBuilder,
    this.connectionTag,
    this.isClosable = true,
  }) : color = color ?? (connectionTag != null ? _generateColorFromTag(connectionTag) : Colors.blueGrey);
  // ۲. در خط بالا گفتیم: اگر رنگ داده نشده بود، برو از روی تگ بساز. اگر تگ هم نبود، پیش‌فرض blueGrey بگذار.

  /// تابع تولید رنگ ثابت و روشن بر اساس متن
  static Color _generateColorFromTag(String tag) {
    // تبدیل رشته به یک عدد هش ثابت
    int hash = tag.hashCode;

    // تعیین Hue (چرخه رنگ) بین ۰ تا ۳۶۰
    double hue = (hash % 360).abs().toDouble();

    // Saturation (غلیظ بودن رنگ):
    // عدد ثابت ۰.۶۵ (۶۵٪) برای اینکه رنگ‌ها زنده باشند اما نه خیلی جیغ
    double saturation = 0.65;

    // Lightness (روشنایی):
    // عدد ثابت ۰.۷۵ (۷۵٪) برای اینکه رنگ‌ها روشن (Pastel/Light) باشند
    double lightness = 0.75;

    // استفاده از HSL برای ساخت رنگ
    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }
}

class WindowItem {
  final String id;
  final String? parentId;
  final String groupId;
  String title;
  IconData icon;
  Color themeColor;
  Widget content;
  Rect rect;
  Rect? savedRect;
  Rect? preMinRect;
  bool isFocused;
  bool isMaximized;
  bool isMinimized;
  final String? connectionTag;
  final bool isClosable;
  WindowItem({
    required this.id,
    this.parentId,
    required this.groupId,
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.content,
    required this.rect,
    this.savedRect,
    this.preMinRect,
    this.isFocused = true,
    this.isMaximized = false,
    this.isMinimized = false,
    this.connectionTag,
    this.isClosable = true,
  });
}