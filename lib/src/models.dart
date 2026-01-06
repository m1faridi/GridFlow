import 'package:flutter/material.dart';

enum SnapRegion {
  none, left, right, top,
  topLeft, topRight, bottomLeft, bottomRight,
  leftThird, centerThird, rightThird
}

/// مدل برای اپلیکیشن‌هایی که در نوار سمت چپ (لانچر) قرار می‌گیرند
class DesktopApp {
  final String title;
  final IconData icon;
  final Color color;
  final Widget Function(String id)? contentBuilder; // محتوای سفارشی

  DesktopApp({
    required this.title,
    required this.icon,
    required this.color,
    this.contentBuilder,
  });
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
  });
}