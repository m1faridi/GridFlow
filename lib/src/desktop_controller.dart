import 'package:flutter/material.dart';

import 'models.dart';
import 'window_widget.dart' show WindowScope;

abstract class DesktopController {
  /// Completes when the window closes. Native windows outlive the desktop widget.
  Future<dynamic> openApp(DesktopApp app, {String? parentId});
  void closeWindow(String id, [dynamic result]);
}

/// یک Handle که هم state را دارد هم context مربوط به caller.
/// نتیجه: DesktopProvider.of(context)?.closeApp(true) دقیقاً مثل Navigator.pop(result)
class DesktopHandle {
  final DesktopController _controller;
  final BuildContext _ctx;
  final String? _sourceWindowId;

  DesktopHandle._(this._controller, this._ctx, this._sourceWindowId);

  Future<dynamic> openApp(DesktopApp app, {String? parentId}) {
    return _controller.openApp(app, parentId: parentId ?? _sourceWindowId);
  }

  void closeApp(dynamic result) {
    final id = WindowScope.of(_ctx);
    if (id == null) {
      // اگر اینجا null است یعنی محتوای پنجره زیر WindowScope نیست
      // یا context مربوط به دسکتاپ نیست.
      debugPrint('[DesktopProvider] closeApp failed: WindowScope is null');
      return;
    }
    _controller.closeWindow(id, result);
  }

  // اگر جایی هنوز close با id لازم داشتی:
  void closeById(String id, [dynamic result]) =>
      _controller.closeWindow(id, result);
}

/// Provider اصلی
class DesktopProvider extends InheritedWidget {
  final DesktopController controller;

  /// Native window that owns this provider; supplies the default opening parent.
  final String? sourceWindowId;

  const DesktopProvider({
    super.key,
    required this.controller,
    this.sourceWindowId,
    required super.child,
  });

  static DesktopHandle? of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<DesktopProvider>();
    if (provider == null) return null;
    return DesktopHandle._(
      provider.controller,
      context,
      provider.sourceWindowId,
    );
  }

  @override
  bool updateShouldNotify(DesktopProvider oldWidget) =>
      controller != oldWidget.controller ||
      sourceWindowId != oldWidget.sourceWindowId;
}
