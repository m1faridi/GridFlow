import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart';

import 'models.dart';
import 'window_chrome.dart';

/// گریپ لمسی گوشهٔ پایین-راست: یک قوس نرم هم‌راستا با انحنای گوشهٔ پنجره
/// (سبک iPadOS)، فقط برای پلتفرم‌های تاچ.
class _ResizeGripPainter extends CustomPainter {
  final Color color;

  const _ResizeGripPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const double inset = 4.0;
    const double radius = 13.0;
    final Rect arcRect = Rect.fromCircle(
      center: Offset(size.width - inset - radius, size.height - inset - radius),
      radius: radius,
    );
    // زاویه‌ها بر حسب رادیان: ربع پایین-راست (شرق تا جنوب) با کمی فاصله از سرها
    const double startAngle = 8 * 3.1415926535 / 180;
    const double sweepAngle = 74 * 3.1415926535 / 180;

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawArc(arcRect, startAngle, sweepAngle, false, shadowPaint);

    final Paint gripPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, startAngle, sweepAngle, false, gripPaint);
  }

  @override
  bool shouldRepaint(covariant _ResizeGripPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class FastWindow extends StatelessWidget {
  // Resize grip style tokens (easy to customize in one place).

  final WindowItem window;
  final Rect? renderRect;
  final Size desktopSize;
  final EdgeInsets padding;
  final WindowChromeStyle? chromeStyle;

  /// مقیاس فعلی بوم؛ برای ثابت نگه داشتن اندازهٔ هندل‌های resize روی صفحه.
  final double canvasScale;
  final VoidCallback onFocus;
  final VoidCallback onClose;
  final VoidCallback onMaximize;
  final VoidCallback onMinimize;
  final Function(Rect) onUpdate;
  final VoidCallback onDragStart;
  final Function(DragUpdateDetails) onDragUpdate;
  final VoidCallback onDragEnd;

  const FastWindow({
    super.key,
    required this.window,
    this.renderRect,
    required this.desktopSize,
    required this.padding,
    this.chromeStyle,
    this.canvasScale = 1.0,
    required this.onFocus,
    required this.onClose,
    required this.onMaximize,
    required this.onMinimize,
    required this.onUpdate,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  Widget _buildBottomRightResizeGrip({
    required bool canResize,
    required double handleTapSize,
  }) {
    if (!canResize) return const SizedBox.expand();

    // هندل روی گوشهٔ پنجره سنتر شده؛ با این جابجایی، لنگر قوس دقیقاً
    // روی گوشهٔ واقعی پنجره می‌افتد و قوس داخل پنجره رسم می‌شود.
    return IgnorePointer(
      child: Transform.translate(
        offset: Offset(-handleTapSize / 2, -handleTapSize / 2),
        child: CustomPaint(
          size: Size(handleTapSize, handleTapSize),
          painter: _ResizeGripPainter(
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
      ),
    );
  }

  MouseCursor _cornerCursor(HandlePosition handle) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
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
    // روی دسکتاپ هندل‌ها کاملاً «بیرون» قاب پنجره قرار می‌گیرند (مثل فریم
    // نامرئی ویندوز): هیچ‌وقت روی نوار عنوان یا دکمه‌ها نمی‌افتند و کلیک
    // نمی‌دزدند. اندازه هم با زوم جبران می‌شود تا روی صفحه ثابت بماند.
    final double safeScale = canvasScale <= 0 ? 1.0 : canvasScale;
    final double resizeHandleTapSize = isDesktopPlatform
        ? (14.0 / safeScale).clamp(10.0, 36.0).toDouble()
        : 32;

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
        // با موس، کرسر resize کافی است و خط/گریپ لازم نیست؛
        // گریپ فقط برای پلتفرم‌های لمسی نمایش داده می‌شود.
        if (isDesktopPlatform) {
          return MouseRegion(
            cursor: _cornerCursor(handle),
            child: const SizedBox.expand(),
          );
        }
        return handle == HandlePosition.bottomRight
            ? _buildBottomRightResizeGrip(
                canResize: canResize,
                handleTapSize: resizeHandleTapSize,
              )
            : const SizedBox.expand();
      },
      sideHandleBuilder: (context, handle) => isDesktopPlatform
          ? MouseRegion(
              cursor: _sideCursor(handle),
              child: const SizedBox.expand(),
            )
          : const SizedBox.expand(),
      handleAlignment: isDesktopPlatform
          ? HandleAlignment.outside
          : HandleAlignment.center,
      handleTapSize: resizeHandleTapSize,
      draggable: false,
      allowFlippingWhileResizing: false,
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
            onPointerDown: (event) {
              if (event.kind == PointerDeviceKind.mouse &&
                  (event.buttons & kPrimaryMouseButton) == 0) {
                return;
              }
              if (!window.isFocused) onFocus();
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onMinimize,
                onPanStart: (_) {
                  onFocus();
                  onDragStart();
                },
                onPanUpdate: onDragUpdate,
                onPanEnd: (_) => onDragEnd(),
                child: Material(
                  color: Colors.transparent,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 220,
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
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
            ),
          );
        }

        // --- بخش ۲: بدنه پنجره ---
        final Widget windowBody = Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(
              // color: Colors.white,
              borderRadius: BorderRadius.circular(window.isMaximized ? 0 : 10),
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
            ),
            clipBehavior: Clip.hardEdge,
            child: window.hasTitleBar
                ? _buildWithTitleBar(scopedContent)
                : _buildWithoutTitleBar(scopedContent),
          ),
        );

        return Listener(
          behavior: HitTestBehavior.opaque,
          // فوکوس فوری با فشردن دکمهٔ اصلی ماوس، مثل سیستم‌عامل واقعی.
          // دکمهٔ وسط (پنِ بوم) نباید پنجره را جلو بیاورد.
          onPointerDown: (event) {
            if (event.kind == PointerDeviceKind.mouse &&
                (event.buttons & kPrimaryMouseButton) == 0) {
              return;
            }
            if (!window.isFocused) onFocus();
          },
          // RepaintBoundary: جابجایی یا انیمیشن پنجره‌های دیگر باعث
          // رندر دوباره این پنجره نمی‌شود.
          child: RepaintBoundary(child: windowBody),
        );
      },
    );
  }

  Widget _buildWithTitleBar(Widget scopedContent) {
    const double toolbarHeight = 34;
    const double titleFontSize = 12;
    final WindowChromeStyle style = chromeStyle ?? defaultWindowChromeStyle();
    final bool isFocused = window.isFocused;
    final Color titleBarBaseColor = isFocused
        ? const Color(0xFF2C313A)
        : const Color(0xFF1E232A);
    final Color titleBarTopColor = isFocused
        ? const Color(0xFF343A45)
        : const Color(0xFF262C35);
    final Color titleTextColor = isFocused
        ? const Color(0xFFE7EDF7)
        : const Color(0xFFA3ADBA);
    final Color iconColor = isFocused
        ? const Color(0xFFD9E2EE)
        : const Color(0xFF8793A3);

    final Widget captionControls = WindowCaptionControls(
      style: style,
      isFocused: isFocused,
      isMaximized: window.isMaximized,
      isClosable: window.isClosable,
      height: toolbarHeight,
      iconColor: iconColor,
      onMinimize: onMinimize,
      onMaximize: onMaximize,
      onClose: onClose,
    );

    final Widget titleText = Text(
      window.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: titleFontSize,
        fontWeight: FontWeight.w600,
        color: titleTextColor,
      ),
    );

    final Widget titleBarContent = style == WindowChromeStyle.macos
        ? Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 76),
                  child: Center(child: titleText),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: captionControls,
              ),
            ],
          )
        : Row(
            children: [
              const SizedBox(width: 12),
              Expanded(child: titleText),
              const SizedBox(width: 8),
              captionControls,
            ],
          );

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: onMaximize,
          onPanStart: (_) {
            onFocus();
            onDragStart();
          },
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
            ),
            child: titleBarContent,
          ),
        ),
        Expanded(
          child: AbsorbPointer(
            absorbing: !window.isFocused,
            child: scopedContent,
          ),
        ),
      ],
    );
  }

  Widget _buildWithoutTitleBar(Widget scopedContent) {
    return Stack(
      children: [
        Positioned.fill(
          child: AbsorbPointer(
            absorbing: !window.isFocused,
            child: scopedContent,
          ),
        ),

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 30,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTap: onMaximize,
            onPanStart: (_) {
              onFocus();
              onDragStart();
            },
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

  const WindowScope({super.key, required this.windowId, required super.child});

  static String? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<WindowScope>()?.windowId;
  }

  @override
  bool updateShouldNotify(WindowScope oldWidget) =>
      windowId != oldWidget.windowId;
}
