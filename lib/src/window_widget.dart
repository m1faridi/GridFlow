import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart';
import 'models.dart';

class FastWindow extends StatelessWidget {
  final WindowItem window;
  final Size desktopSize;
  final EdgeInsets padding;
  final VoidCallback onFocus;
  final VoidCallback onClose;
  final VoidCallback onMaximize;
  final VoidCallback onMinimize;
  final Function(Rect) onUpdate;
  final Function(DragUpdateDetails) onDragUpdate;
  final VoidCallback onDragEnd;

  const FastWindow({
    super.key,
    required this.window,
    required this.desktopSize,
    required this.padding,
    required this.onFocus,
    required this.onClose,
    required this.onMaximize,
    required this.onMinimize,
    required this.onUpdate,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final bool canResize = window.isFocused && !window.isMaximized && !window.isMinimized;
    final Set<HandlePosition> allHandles = {
      HandlePosition.topLeft, HandlePosition.topRight, HandlePosition.bottomLeft,
      HandlePosition.bottomRight, HandlePosition.top, HandlePosition.bottom,
      HandlePosition.left, HandlePosition.right
    };

    return TransformableBox(
      rect: window.rect,
      constraints: window.isMinimized ? BoxConstraints.tight(const Size(220, 60)) : const BoxConstraints(minWidth: 200, minHeight: 150),
      enabledHandles: canResize ? allHandles : {},
      visibleHandles: {},
      handleAlignment: HandleAlignment.inside,
      handleTapSize: 20,
      onChanged: (result, event) { if (!window.isMaximized && !window.isMinimized) onUpdate(result.rect); },
      contentBuilder: (context, rect, flip) {
        if (window.isMinimized) {
          return GestureDetector(
            onTap: onMinimize, onPanStart: (_) => onFocus(), onPanUpdate: onDragUpdate, onPanEnd: (_) => onDragEnd(),
            child: Material(
              color: Colors.transparent, elevation: 8, borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 220, height: 60, padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: window.themeColor, width: 2)),
                child: Row(children: [Icon(window.icon, color: window.themeColor, size: 24), const SizedBox(width: 10), Expanded(child: Text(window.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)), const SizedBox(width: 4), const Icon(CupertinoIcons.chevron_up, size: 16, color: Colors.grey)]),
              ),
            ),
          );
        }
        return Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(window.isMaximized ? 0 : 16), boxShadow: window.isFocused && !window.isMaximized ? [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 30, spreadRadius: 0)] : [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)], border: Border.all(color: (window.isFocused && !window.isMaximized) ? Colors.blueAccent.withOpacity(0.3) : Colors.transparent, width: 1.5)),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) { if (!window.isFocused) onFocus(); },
                onDoubleTap: onMaximize,
                onPanStart: (_) => onFocus(),
                onPanUpdate: onDragUpdate,
                onPanEnd: (_) => onDragEnd(),
                child: Container(height: 45, color: window.isFocused ? const Color(0xFFEFF2F9) : const Color(0xFFF7F7F7), padding: const EdgeInsets.symmetric(horizontal: 14), child: Row(children: [Icon(window.icon, size: 16, color: window.themeColor), const SizedBox(width: 10), Expanded(child: Text(window.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: window.isFocused ? Colors.black87 : Colors.grey[500]))), IconButton(icon: const Icon(CupertinoIcons.minus, size: 18), onPressed: onMinimize), IconButton(icon: Icon(window.isMaximized ? CupertinoIcons.arrow_down_right_arrow_up_left : CupertinoIcons.crop, size: 17), onPressed: onMaximize), IconButton(icon: const Icon(CupertinoIcons.xmark, size: 18), onPressed: onClose)])),
              ),
              const Divider(height: 1, thickness: 0.5),
              Expanded(
                  child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: (_) { if (!window.isFocused) onFocus(); },
                      onPanStart: (_) {}, onPanUpdate: (_) {}, onPanEnd: (_) {},
                      child: AbsorbPointer(absorbing: !window.isFocused, child: window.content)
                  )
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ویجت پیش‌فرض برای محتوای خالی
class DefaultWindowContent extends StatelessWidget {
  final String title; final IconData icon; final Color color; final VoidCallback onOpenChild;
  const DefaultWindowContent({super.key, required this.title, required this.icon, required this.color, required this.onOpenChild});
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 45, color: color.withOpacity(0.5)),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onOpenChild,
            icon: const Icon(Icons.add_link, size: 18),
            label: const Text("Open Child Window"),
            style: ElevatedButton.styleFrom(
              backgroundColor: color, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )
        ],
      ),
    );
  }
}
class WindowScope extends InheritedWidget {
  final String windowId;

  const WindowScope({
    super.key,
    required this.windowId,
    required super.child,
  });

  /// این متد جادویی است که آیدی پنجره فعلی را پیدا می‌کند
  static String? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<WindowScope>()?.windowId;
  }

  @override
  bool updateShouldNotify(WindowScope oldWidget) => windowId != oldWidget.windowId;
}