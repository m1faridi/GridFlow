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
  final bool hasTitleBar; // فیلد جدید برای تنظیم تایتل‌بار

  DesktopApp({
    required this.title,
    required this.icon,
    Color? color,
    this.contentBuilder,
    this.connectionTag,
    this.isClosable = true,
    this.hasTitleBar = true, // مقدار پیش‌فرض true است (یعنی تایتل‌بار دارد)
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
  final bool hasTitleBar; // فیلد جدید در آیتم پنجره

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
    this.hasTitleBar = true, // دریافت مقدار
  });
}