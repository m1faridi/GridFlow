import 'package:flutter/material.dart';

enum SnapRegion {
  none, left, right, top,
  topLeft, topRight, bottomLeft, bottomRight,
  leftThird, centerThird, rightThird
}

class DesktopApp {
  final String title;
  final Color color;
  final Widget Function(String id)? contentBuilder;
  final String? connectionTag;

  // در کلاس App این‌ها می‌توانند final باشند چون فقط تنظیمات اولیه هستند
  final bool isClosable;

  DesktopApp({
    required this.title,
    Color? color,
    this.contentBuilder,
    this.connectionTag,
    this.isClosable = true,
  }) : color = color ?? (connectionTag != null ? _generateColorFromTag(connectionTag) : Colors.blueGrey);

  static Color _generateColorFromTag(String tag) {
    int hash = tag.hashCode;
    double hue = (hash % 360).abs().toDouble();
    double saturation = 0.65;
    double lightness = 0.75;
    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }
}

class WindowItem {
  final String id;
  final String? parentId;
  final String groupId;
  String title;
  Color themeColor;
  Widget content;
  Rect rect;
  Rect? savedRect;
  Rect? preMinRect;
  bool isFocused;
  bool isMaximized;
  bool isMinimized;
  final String? connectionTag;

  // *** تغییر مهم: final را از دو خط زیر حذف کردم ***
  bool isClosable;
  bool hasTitleBar;

  WindowItem({
    required this.id,
    this.parentId,
    required this.groupId,
    required this.title,
    required this.themeColor,
    required this.content,
    required this.rect,
    this.savedRect,
    this.preMinRect,
    this.isFocused = true,
    this.isMaximized = false,
    this.isMinimized = false,
    this.connectionTag,
    this.isClosable = true,   // مقدار اولیه
    this.hasTitleBar = true,  // مقدار اولیه
  });
}