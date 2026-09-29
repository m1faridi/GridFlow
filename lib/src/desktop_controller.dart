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

  DesktopHandle._(this._controller, this._ctx);

  Future<dynamic> openApp(DesktopApp app, {String? parentId}) {
    return _controller.openApp(app, parentId: parentId);
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

  const DesktopProvider({
    super.key,
    required this.controller,
    required super.child,
  });

  static DesktopHandle? of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<DesktopProvider>();
    if (provider == null) return null;
    return DesktopHandle._(provider.controller, context);
  }

  @override
  bool updateShouldNotify(DesktopProvider oldWidget) =>
      controller != oldWidget.controller;
}
