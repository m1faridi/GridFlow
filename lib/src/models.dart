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

  // این همان چیزی است که می‌خواهید
  // هر اپلیکیشنی که این مقدارش یکی باشد، به هم وصل می‌شوند
  final String? connectionTag;

  DesktopApp({
    required this.title,
    required this.icon,
    required this.color,
    this.contentBuilder,
    this.connectionTag, // <--- فیلد جدید
  });
}

class WindowItem {
  final String id; // آیدی یونیک خود سیستم (دست نزنید)
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

  // ذخیره تگ اتصال در پنجره باز شده
  final String? connectionTag;

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
    this.connectionTag, // <--- دریافت مقدار
  });
}