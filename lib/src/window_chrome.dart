import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// سبک ظاهری دکمه‌های کنترل پنجره (بستن/کمینه/بیشینه).
enum WindowChromeStyle {
  /// دکمه‌های مستطیلی سمت راست، مثل Windows 11 (هاور قرمز روی بستن).
  windows,

  /// چراغ‌های ترافیکی سمت چپ، مثل macOS.
  macos,
}

/// سبک پیش‌فرض بر اساس پلتفرم: macOS و Android چراغ ترافیکی، بقیه ویندوز.
WindowChromeStyle defaultWindowChromeStyle() {
  return defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.android
      ? WindowChromeStyle.macos
      : WindowChromeStyle.windows;
}

/// دکمه‌های کنترل نوار عنوان با رفتار هاور/کلیک نیتیو.
///
/// این ویجت درگ و دابل‌کلیک را می‌بلعد تا کشیدن ماوس از روی دکمه‌ها
/// هرگز پنجره را جابجا یا بیشینه نکند (مثل ویندوز و مک).
class WindowCaptionControls extends StatelessWidget {
  final WindowChromeStyle style;
  final bool isFocused;
  final bool isMaximized;
  final bool isClosable;
  final double height;
  final Color iconColor;
  final VoidCallback onMinimize;
  final VoidCallback onMaximize;
  final VoidCallback onClose;

  const WindowCaptionControls({
    super.key,
    required this.style,
    required this.isFocused,
    required this.isMaximized,
    required this.isClosable,
    required this.height,
    required this.iconColor,
    required this.onMinimize,
    required this.onMaximize,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final Widget controls = style == WindowChromeStyle.macos
        ? _MacTrafficLights(
            isFocused: isFocused,
            isMaximized: isMaximized,
            isClosable: isClosable,
            height: height,
            onClose: onClose,
            onMinimize: onMinimize,
            onMaximize: onMaximize,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WindowsCaptionButton(
                glyph: _CaptionGlyph.minimize,
                height: height,
                iconColor: iconColor,
                onPressed: onMinimize,
              ),
              _WindowsCaptionButton(
                glyph: isMaximized
                    ? _CaptionGlyph.restore
                    : _CaptionGlyph.maximize,
                height: height,
                iconColor: iconColor,
                onPressed: onMaximize,
              ),
              if (isClosable)
                _WindowsCaptionButton(
                  glyph: _CaptionGlyph.close,
                  height: height,
                  iconColor: iconColor,
                  isClose: true,
                  onPressed: onClose,
                ),
            ],
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {},
      onPanUpdate: (_) {},
      onPanEnd: (_) {},
      onDoubleTap: () {},
      child: controls,
    );
  }
}

// ---------------------------------------------------------------------------
// Windows 11 style
// ---------------------------------------------------------------------------

enum _CaptionGlyph { minimize, maximize, restore, close }

class _WindowsCaptionButton extends StatefulWidget {
  final _CaptionGlyph glyph;
  final double height;
  final Color iconColor;
  final bool isClose;
  final VoidCallback onPressed;

  const _WindowsCaptionButton({
    required this.glyph,
    required this.height,
    required this.iconColor,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  State<_WindowsCaptionButton> createState() => _WindowsCaptionButtonState();
}

class _WindowsCaptionButtonState extends State<_WindowsCaptionButton> {
  static const double _width = 44;
  bool _hovered = false;
  bool _pressed = false;

  void _handlePointerUp(PointerUpEvent event) {
    final bool wasPressed = _pressed;
    if (_pressed) setState(() => _pressed = false);
    final bool insideBounds =
        (Offset.zero & Size(_width, widget.height)).contains(
      event.localPosition,
    );
    if (wasPressed && insideBounds) widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    Color background = Colors.transparent;
    Color foreground = widget.iconColor;

    // حالت «فشرده» فقط وقتی نشانگر روی دکمه است نمایش داده می‌شود؛
    // ولی خودِ فشار با خروج موقت نشانگر از بین نمی‌رود (رفتار نیتیو ویندوز).
    if (widget.isClose) {
      if (_pressed && _hovered) {
        background = const Color(0xFFB7161F);
        foreground = Colors.white.withValues(alpha: 0.8);
      } else if (_hovered) {
        background = const Color(0xFFE81123);
        foreground = Colors.white;
      }
    } else {
      if (_pressed && _hovered) {
        background = Colors.white.withValues(alpha: 0.06);
        foreground = foreground.withValues(alpha: 0.7);
      } else if (_hovered) {
        background = Colors.white.withValues(alpha: 0.11);
      }
    }

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (event.kind == PointerDeviceKind.mouse &&
              (event.buttons & kPrimaryMouseButton) == 0) {
            return;
          }
          setState(() => _pressed = true);
        },
        onPointerUp: _handlePointerUp,
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          width: _width,
          height: widget.height,
          color: background,
          child: Center(
            child: CustomPaint(
              size: const Size(10, 10),
              painter: _CaptionGlyphPainter(
                glyph: widget.glyph,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptionGlyphPainter extends CustomPainter {
  final _CaptionGlyph glyph;
  final Color color;

  const _CaptionGlyphPainter({required this.glyph, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    switch (glyph) {
      case _CaptionGlyph.minimize:
        canvas.drawLine(
          Offset(0.5, size.height / 2),
          Offset(size.width - 0.5, size.height / 2),
          paint,
        );
      case _CaptionGlyph.maximize:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(0.5, 0.5, size.width - 0.5, size.height - 0.5),
            const Radius.circular(1.8),
          ),
          paint,
        );
      case _CaptionGlyph.restore:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(0.5, 2.5, size.width - 2.5, size.height - 0.5),
            const Radius.circular(1.5),
          ),
          paint,
        );
        final Path back = Path()
          ..moveTo(2.7, 0.9)
          ..lineTo(size.width - 2.1, 0.9)
          ..arcToPoint(
            Offset(size.width - 0.9, 2.1),
            radius: const Radius.circular(1.2),
          )
          ..lineTo(size.width - 0.9, size.height - 2.7);
        canvas.drawPath(back, paint);
      case _CaptionGlyph.close:
        canvas.drawLine(
          const Offset(0.8, 0.8),
          Offset(size.width - 0.8, size.height - 0.8),
          paint,
        );
        canvas.drawLine(
          Offset(size.width - 0.8, 0.8),
          Offset(0.8, size.height - 0.8),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _CaptionGlyphPainter oldDelegate) {
    return oldDelegate.glyph != glyph || oldDelegate.color != color;
  }
}

// ---------------------------------------------------------------------------
// macOS traffic lights
// ---------------------------------------------------------------------------

enum _TrafficLightKind { close, minimize, zoom }

class _MacTrafficLights extends StatefulWidget {
  final bool isFocused;
  final bool isMaximized;
  final bool isClosable;
  final double height;
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback onMaximize;

  const _MacTrafficLights({
    required this.isFocused,
    required this.isMaximized,
    required this.isClosable,
    required this.height,
    required this.onClose,
    required this.onMinimize,
    required this.onMaximize,
  });

  @override
  State<_MacTrafficLights> createState() => _MacTrafficLightsState();
}

class _MacTrafficLightsState extends State<_MacTrafficLights> {
  bool _groupHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _groupHovered = true),
      onExit: (_) => setState(() => _groupHovered = false),
      child: Padding(
        padding: const EdgeInsets.only(left: 7, right: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TrafficLightButton(
              kind: _TrafficLightKind.close,
              enabled: widget.isClosable,
              isFocused: widget.isFocused,
              isMaximized: widget.isMaximized,
              showGlyph: _groupHovered,
              height: widget.height,
              onPressed: widget.onClose,
            ),
            _TrafficLightButton(
              kind: _TrafficLightKind.minimize,
              enabled: true,
              isFocused: widget.isFocused,
              isMaximized: widget.isMaximized,
              showGlyph: _groupHovered,
              height: widget.height,
              onPressed: widget.onMinimize,
            ),
            _TrafficLightButton(
              kind: _TrafficLightKind.zoom,
              enabled: true,
              isFocused: widget.isFocused,
              isMaximized: widget.isMaximized,
              showGlyph: _groupHovered,
              height: widget.height,
              onPressed: widget.onMaximize,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrafficLightButton extends StatefulWidget {
  final _TrafficLightKind kind;
  final bool enabled;
  final bool isFocused;
  final bool isMaximized;
  final bool showGlyph;
  final double height;
  final VoidCallback onPressed;

  const _TrafficLightButton({
    required this.kind,
    required this.enabled,
    required this.isFocused,
    required this.isMaximized,
    required this.showGlyph,
    required this.height,
    required this.onPressed,
  });

  @override
  State<_TrafficLightButton> createState() => _TrafficLightButtonState();
}

class _TrafficLightButtonState extends State<_TrafficLightButton> {
  static const double _hitWidth = 20;
  static const double _diameter = 12;
  bool _pressed = false;

  Color get _fillColor {
    if (!widget.enabled) return const Color(0xFF44474C);
    // مثل مک: پنجره غیرفعال چراغ خاکستری دارد ولی با هاور رنگی می‌شود.
    if (!widget.isFocused && !widget.showGlyph) return const Color(0xFF4A4D52);
    switch (widget.kind) {
      case _TrafficLightKind.close:
        return const Color(0xFFFF5F57);
      case _TrafficLightKind.minimize:
        return const Color(0xFFFEBC2E);
      case _TrafficLightKind.zoom:
        return const Color(0xFF28C840);
    }
  }

  Color get _borderColor {
    if (!widget.enabled) return const Color(0xFF3A3D42);
    if (!widget.isFocused && !widget.showGlyph) return const Color(0xFF3A3D42);
    switch (widget.kind) {
      case _TrafficLightKind.close:
        return const Color(0xFFE0443E);
      case _TrafficLightKind.minimize:
        return const Color(0xFFDEA123);
      case _TrafficLightKind.zoom:
        return const Color(0xFF1AAB29);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    final bool wasPressed = _pressed;
    if (_pressed) setState(() => _pressed = false);
    final bool insideBounds =
        (Offset.zero & Size(_hitWidth, widget.height)).contains(
      event.localPosition,
    );
    if (wasPressed && insideBounds && widget.enabled) widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    Color fill = _fillColor;
    if (_pressed && widget.enabled) {
      fill = Color.alphaBlend(Colors.black.withValues(alpha: 0.25), fill);
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse &&
            (event.buttons & kPrimaryMouseButton) == 0) {
          return;
        }
        if (widget.enabled) setState(() => _pressed = true);
      },
      onPointerUp: _handlePointerUp,
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: SizedBox(
        width: _hitWidth,
        height: widget.height,
        child: Center(
          child: Container(
            width: _diameter,
            height: _diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(color: _borderColor, width: 0.5),
            ),
            child: widget.showGlyph && widget.enabled
                ? CustomPaint(
                    painter: _TrafficGlyphPainter(
                      kind: widget.kind,
                      isMaximized: widget.isMaximized,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _TrafficGlyphPainter extends CustomPainter {
  final _TrafficLightKind kind;
  final bool isMaximized;

  const _TrafficGlyphPainter({required this.kind, required this.isMaximized});

  @override
  void paint(Canvas canvas, Size size) {
    final Color glyphColor = Colors.black.withValues(alpha: 0.55);
    final Paint stroke = Paint()
      ..color = glyphColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    final Paint fill = Paint()
      ..color = glyphColor
      ..style = PaintingStyle.fill;

    switch (kind) {
      case _TrafficLightKind.close:
        canvas.drawLine(const Offset(3.4, 3.4), const Offset(7.6, 7.6), stroke);
        canvas.drawLine(const Offset(7.6, 3.4), const Offset(3.4, 7.6), stroke);
      case _TrafficLightKind.minimize:
        canvas.drawLine(const Offset(2.6, 5.5), const Offset(8.4, 5.5), stroke);
      case _TrafficLightKind.zoom:
        if (isMaximized) {
          // فلش‌ها رو به داخل: خروج از حالت بیشینه
          final Path a = Path()
            ..moveTo(5.4, 5.4)
            ..lineTo(5.4, 2.1)
            ..lineTo(2.1, 5.4)
            ..close();
          final Path b = Path()
            ..moveTo(5.6, 5.6)
            ..lineTo(5.6, 8.9)
            ..lineTo(8.9, 5.6)
            ..close();
          canvas.drawPath(a, fill);
          canvas.drawPath(b, fill);
        } else {
          // فلش‌ها رو به بیرون: بیشینه/تمام‌صفحه
          final Path a = Path()
            ..moveTo(2.4, 2.4)
            ..lineTo(6.0, 2.4)
            ..lineTo(2.4, 6.0)
            ..close();
          final Path b = Path()
            ..moveTo(8.6, 8.6)
            ..lineTo(5.0, 8.6)
            ..lineTo(8.6, 5.0)
            ..close();
          canvas.drawPath(a, fill);
          canvas.drawPath(b, fill);
        }
    }
  }

  @override
  bool shouldRepaint(covariant _TrafficGlyphPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.isMaximized != isMaximized;
  }
}
