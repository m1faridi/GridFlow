import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart';

import 'models.dart';

class FastWindow extends StatelessWidget {
  final WindowItem window;
  final Rect? renderRect;
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
    this.renderRect,
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

  MouseCursor _cornerCursor(HandlePosition handle) {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      switch (handle) {
        case HandlePosition.topLeft:
        case HandlePosition.topRight:
          return SystemMouseCursors.resizeUp;
        case HandlePosition.bottomLeft:
        case HandlePosition.bottomRight:
          return SystemMouseCursors.resizeDown;
        default:
          return SystemMouseCursors.basic;
      }
    }

    switch (handle) {
      case HandlePosition.topLeft:
      case HandlePosition.bottomRight:
      // این برای خط مورب \ است (مثل عکس شما)
        return SystemMouseCursors.resizeUpLeftDownRight;

      case HandlePosition.topRight:
      case HandlePosition.bottomLeft:
      // این برای خط مورب / است
        return SystemMouseCursors.resizeUpRightDownLeft;

      default:
        return SystemMouseCursors.basic;
    }
  }

  MouseCursor _sideCursor(HandlePosition handle) {
    switch (handle) {
      case HandlePosition.top:
      case HandlePosition.bottom:
        return SystemMouseCursors.resizeUpDown;
      case HandlePosition.left:
      case HandlePosition.right:
        return SystemMouseCursors.resizeLeftRight;
      default:
        return SystemMouseCursors.basic;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktopPlatform =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    final bool canResize = !window.isMaximized && !window.isMinimized;
    final double resizeHandleTapSize = isDesktopPlatform ? 20 : 28;

    final Set<HandlePosition> allHandles = {
      HandlePosition.topLeft,
      HandlePosition.topRight,
      HandlePosition.bottomLeft,
      HandlePosition.bottomRight,
      HandlePosition.top,
      HandlePosition.bottom,
      HandlePosition.left,
      HandlePosition.right,
    };
    final Set<HandlePosition> mobileHandles = {
      HandlePosition.topLeft,
      HandlePosition.topRight,
      HandlePosition.bottomLeft,
      HandlePosition.bottomRight,
    };
    // مهم‌ترین اصلاح:
    // محتوای پنجره را با WindowScope wrap می‌کنیم تا داخل محتوا WindowScope.of(context) کار کند.
    final Widget scopedContent = WindowScope(
      windowId: window.id,
      child: window.content,
    );

    return TransformableBox(
      rect: renderRect ?? window.rect,
      constraints: window.isMinimized
          ? BoxConstraints.tight(const Size(220, 60))
          : const BoxConstraints(minWidth: 200, minHeight: 150),
      enabledHandles: canResize
          ? (isDesktopPlatform ? allHandles : mobileHandles)
          : {},
      visibleHandles: canResize
          ? (isDesktopPlatform ? allHandles : mobileHandles)
          : const {},
      cornerHandleBuilder: (context, handle) {
        if (isDesktopPlatform) {
          return MouseRegion(
            cursor: _cornerCursor(handle),
            child: const SizedBox.expand(),
          );
        }
        return const SizedBox.expand();
      },
      sideHandleBuilder: (context, handle) => isDesktopPlatform
          ? MouseRegion(
              cursor: _sideCursor(handle),
              child: const SizedBox.expand(),
            )
          : const SizedBox.expand(),
      handleAlignment: HandleAlignment.center,
      handleTapSize: resizeHandleTapSize,
      draggable: false,
      onResizeStart: (_, event) {
        if (!window.isFocused) {
          onFocus();
        }
      },
      onChanged: (result, event) {
        if (!window.isMaximized && !window.isMinimized) {
          onUpdate(result.rect);
        }
      },
      contentBuilder: (context, rect, flip) {
        // --- بخش ۱: حالت مینیمایز ---
        if (window.isMinimized) {
          return Listener(
            behavior: HitTestBehavior.opaque,
            child: GestureDetector(
              onTap: onMinimize,
              onPanStart: (_) => onFocus(),
              onPanUpdate: onDragUpdate,
              onPanEnd: (_) => onDragEnd(),
              child: Material(
                color: Colors.transparent,
                elevation: 8,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 220,
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: window.themeColor, width: 2),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          window.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        CupertinoIcons.chevron_up,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // --- بخش ۲: بدنه پنجره ---
        final Widget windowBody = Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(window.isMaximized ? 0 : 16),
              boxShadow: window.isFocused && !window.isMaximized
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 30,
                        spreadRadius: 0,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                      ),
                    ],
              border: Border.all(
                color: (window.isFocused && !window.isMaximized)
                    ? Colors.blueAccent.withValues(alpha: 0.3)
                    : Colors.transparent,
                width: 0,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: window.hasTitleBar
                ? _buildWithTitleBar(scopedContent)
                : _buildWithoutTitleBar(scopedContent),
          ),
        );

        return Listener(
          behavior: HitTestBehavior.opaque,
          child: windowBody,
        );
      },
    );
  }

  Widget _buildWithTitleBar(Widget scopedContent) {
    const double toolbarHeight = 30;
    const double toolbarHorizontalPadding = 8;
    const double titleFontSize = 12;
    const double controlButtonSize = 24;
    const double controlIconSize = 14;
    const double maximizeIconSize = 13;
    final bool isDesktopPlatform =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    final double controlButtonGap = isDesktopPlatform ? 5 : 2;
    final bool isFocused = window.isFocused;
    final Color titleBarBaseColor =
        isFocused ? const Color(0xFF2C313A) : const Color(0xFF1E232A);
    final Color titleBarTopColor =
        isFocused ? const Color(0xFF343A45) : const Color(0xFF262C35);
    final Color titleTextColor =
        isFocused ? const Color(0xFFE7EDF7) : const Color(0xFFA3ADBA);
    final Color iconColor =
        isFocused ? const Color(0xFFD9E2EE) : const Color(0xFF8793A3);
    final Color bottomLineColor = isFocused
        ? window.themeColor.withValues(alpha: 0.55)
        : const Color(0xFF353C47);

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            if (!window.isFocused) onFocus();
          },
          onDoubleTap: onMaximize,
          onPanStart: (_) => onFocus(),
          onPanUpdate: onDragUpdate,
          onPanEnd: (_) => onDragEnd(),
          child: Container(
            height: toolbarHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [titleBarTopColor, titleBarBaseColor],
              ),
              border: Border(
                bottom: BorderSide(color: bottomLineColor, width: 1),
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: toolbarHorizontalPadding),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    window.title,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w600,
                      color: titleTextColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    CupertinoIcons.minus,
                    size: controlIconSize,
                    color: iconColor,
                  ),
                  visualDensity: VisualDensity.compact,
                  constraints: BoxConstraints.tightFor(
                    width: controlButtonSize,
                    height: controlButtonSize,
                  ),
                  padding: EdgeInsets.zero,
                  splashRadius: controlButtonSize / 2,
                  onPressed: onMinimize,
                ),
                SizedBox(width: controlButtonGap),
                IconButton(
                  icon: Icon(
                    window.isMaximized
                        ? CupertinoIcons.arrow_down_right_arrow_up_left
                        : CupertinoIcons.crop,
                    color: iconColor,
                    size: maximizeIconSize,
                  ),
                  visualDensity: VisualDensity.compact,
                  constraints: BoxConstraints.tightFor(
                    width: controlButtonSize,
                    height: controlButtonSize,
                  ),
                  padding: EdgeInsets.zero,
                  splashRadius: controlButtonSize / 2,
                  onPressed: onMaximize,
                ),
                if (window.isClosable) ...[
                  SizedBox(width: controlButtonGap),
                  IconButton(
                    icon: Icon(
                      CupertinoIcons.xmark,
                      color: iconColor,
                      size: controlIconSize,
                    ),
                    visualDensity: VisualDensity.compact,
                    constraints: BoxConstraints.tightFor(
                      width: controlButtonSize,
                      height: controlButtonSize,
                    ),
                    padding: EdgeInsets.zero,
                    splashRadius: controlButtonSize / 2,
                    onPressed: onClose,
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (_) {
              if (!window.isFocused) onFocus();
            },
            child: AbsorbPointer(
              absorbing: !window.isFocused,
              child: scopedContent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWithoutTitleBar(Widget scopedContent) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (_) {
              if (!window.isFocused) onFocus();
            },
            child: AbsorbPointer(
              absorbing: !window.isFocused,
              child: scopedContent,
            ),
          ),
        ),

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 30,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (_) {
              if (!window.isFocused) onFocus();
            },
            onDoubleTap: onMaximize,
            onPanStart: (_) => onFocus(),
            onPanUpdate: onDragUpdate,
            onPanEnd: (_) => onDragEnd(),
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }
}

class DefaultWindowContent extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onOpenChild;

  const DefaultWindowContent({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onOpenChild,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 45, color: color.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onOpenChild,
            icon: const Icon(Icons.add_link, size: 18),
            label: const Text("Open Child Window"),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
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

  static String? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<WindowScope>()?.windowId;
  }

  @override
  bool updateShouldNotify(WindowScope oldWidget) => windowId != oldWidget.windowId;
}
