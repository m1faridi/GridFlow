import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'painters.dart';
import 'window_widget.dart';
import 'snap_overlays.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'painters.dart';
import 'window_widget.dart';
import 'snap_overlays.dart';

class DesktopProvider extends InheritedWidget {
  final _GridDesktopState state;

  const DesktopProvider({
    super.key,
    required this.state,
    required super.child,
  });

  static DesktopProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DesktopProvider>();
  }

  void openApp(DesktopApp app, {String? parentId}) {
    state.openApp(app, parentId: parentId);
  }

  @override
  bool updateShouldNotify(DesktopProvider oldWidget) => false;
}

class GridDesktop extends StatefulWidget {
  final List<DesktopApp> apps;
  final Widget? background;
  final List<DesktopApp>? autoStartApps;

  // این دو پارامتر برای کنترل مود نمایش هستند
  final bool isWindowMode;
  final bool hasTitleBar; // اضافه شد: کنترل مستقیم نوار عنوان

  const GridDesktop({
    super.key,
    required this.apps,
    this.background,
    this.autoStartApps,
    this.isWindowMode = false,
    this.hasTitleBar = true, // مقدار پیش‌فرض true است
  });

  @override
  State<GridDesktop> createState() => _GridDesktopState();
}

class _GridDesktopState extends State<GridDesktop> with SingleTickerProviderStateMixin {
  List<WindowItem> windows = [];
  SnapRegion activeSnapRegion = SnapRegion.none;
  bool _isDragging = false;
  bool _showSnapBar = false;

  late AnimationController _lineAnimationController;

  @override
  void initState() {
    super.initState();
    _lineAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    if (widget.autoStartApps != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (var app in widget.autoStartApps!) {
          openApp(app);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant GridDesktop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasTitleBar != oldWidget.hasTitleBar || widget.isWindowMode != oldWidget.isWindowMode) {

      setState(() {
        for (var window in windows) {
          window.hasTitleBar = widget.hasTitleBar;

        }
      });
    }
  }

  @override
  void dispose() {
    _lineAnimationController.dispose();
    super.dispose();
  }

  Rect _getSafeRect(Size screenSize, EdgeInsets padding) {
    return Rect.fromLTWH(
      padding.left, padding.top,
      screenSize.width - padding.left - padding.right,
      screenSize.height - padding.top - padding.bottom,
    );
  }

  void openApp(DesktopApp app, {String? parentId}) {
    _internalOpenWindow(
      app.title,
      app.icon,
      app.color,
      parentId: parentId,
      customBodyBuilder: app.contentBuilder,
      connectionTag: app.connectionTag,
      isClosable: app.isClosable,
      // اگر اپلیکیشن خاصی تنظیم نکرده بود، از تنظیمات کلی دسکتاپ استفاده کن
    );
  }

  void _internalOpenWindow(
      String title,
      IconData icon,
      Color color,
      {
        String? parentId,
        Widget Function(String id)? customBodyBuilder,
        String? connectionTag,
        bool isClosable = true,
        bool appHasTitleBar = true, // دریافت تنظیمات خود اپ
      }) {
    setState(() {
      final size = MediaQuery.of(context).size;
      final padding = MediaQuery.of(context).padding;
      final safeRect = _getSafeRect(size, padding);
      final String newId = DateTime.now().toIso8601String();

      // لاجیک: اگر GridDesktop بگوید تایتل‌بار نداشته باشیم (false)، اولویت با آن است.
      // اگر GridDesktop بگوید true، آنگاه به تنظیمات خود App نگاه می‌کنیم.
      final bool finalHasTitleBar = widget.hasTitleBar && appHasTitleBar;

      final bool isMobile = size.width < 700;
      bool startMaximized = isMobile;

      WindowItem? parentWindow;
      if (parentId != null) {
        try {
          parentWindow = windows.firstWhere((w) => w.id == parentId);
          if (parentWindow.isMaximized) startMaximized = true;
        } catch (_) {}
      } else if (windows.isNotEmpty && windows.last.isMaximized) {
        startMaximized = true;
      }

      double targetWidth = 360;
      double targetHeight = 650;
      WindowItem? referenceWindow = parentWindow ?? (windows.isNotEmpty ? windows.last : null);

      if (referenceWindow != null) {
        targetWidth = referenceWindow.rect.width;
        targetHeight = referenceWindow.rect.height;
      }

      Rect startRect;
      Rect savedRect;

      if (startMaximized) {
        startRect = safeRect;
        savedRect = Rect.fromLTWH(safeRect.left + 40, safeRect.top + 40, targetWidth, targetHeight);
      } else {
        double startX = safeRect.left + 50;
        double startY = safeRect.top + 50;
        const double gap = 20.0;

        if (referenceWindow != null) {
          double potentialX = referenceWindow.rect.right + gap;
          double potentialY = referenceWindow.rect.top;
          if (potentialX + targetWidth <= safeRect.right) {
            startX = potentialX;
            startY = potentialY;
          } else {
            startX = safeRect.left + 50;
            double nextLineY = referenceWindow.rect.bottom + gap;
            if (nextLineY + targetHeight <= safeRect.bottom) {
              startY = nextLineY;
            } else {
              startX = safeRect.left + 50;
              startY = safeRect.top + 50;
            }
          }
        }
        startRect = Rect.fromLTWH(startX, startY, targetWidth, targetHeight);
        savedRect = startRect;
      }

      Widget content;
      if (customBodyBuilder != null) {
        content = customBodyBuilder(newId);
      } else {
        content = Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, color.withOpacity(0.05)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
              ),
            ],
          ),
        );
      }

      windows.add(WindowItem(
        id: newId,
        parentId: parentId,
        groupId: "default",
        title: title,
        themeColor: color,
        rect: startRect,
        savedRect: savedRect,
        isFocused: true,
        isMaximized: startMaximized,
        content: content,
        connectionTag: connectionTag,
        isClosable: isClosable,
        // تغییر مهم: استفاده از متغیر محاسبه شده به جای hardcode کردن
        hasTitleBar: finalHasTitleBar,
      ));

      focusWindow(newId);
    });
  }

  void closeWindow(String id) => setState(() => windows.removeWhere((w) => w.id == id));

  void focusWindow(String id) {
    final index = windows.indexWhere((w) => w.id == id);
    if (index != -1) {
      setState(() {
        final window = windows.removeAt(index);
        window.isFocused = true;
        for (var w in windows) w.isFocused = false;
        windows.add(window);
      });
    }
  }

  void toggleMaximize(String id, Size screenSize, EdgeInsets padding) {
    final index = windows.indexWhere((w) => w.id == id);
    if (index == -1) return;
    final safeRect = _getSafeRect(screenSize, padding);
    setState(() {
      final window = windows[index];
      if (window.isMaximized) {
        window.rect = window.savedRect ?? Rect.fromLTWH(safeRect.left + 50, safeRect.top + 50, 360, 650);
        window.isMaximized = false;
      } else {
        window.savedRect = window.rect;
        window.rect = safeRect;
        window.isMaximized = true;
      }
      focusWindow(id);
    });
  }

  void toggleMinimize(String id) {
    final index = windows.indexWhere((w) => w.id == id);
    if (index == -1) return;
    setState(() {
      final window = windows[index];
      if (window.isMinimized) {
        window.rect = window.preMinRect ?? const Rect.fromLTWH(100, 100, 360, 650);
        window.isMinimized = false;
        focusWindow(id);
      } else {
        window.preMinRect = window.rect;
        window.isMinimized = true;
        window.isMaximized = false;
        window.rect = Rect.fromLTWH(window.rect.left, window.rect.top, 220, 60);
      }
    });
  }

  void onWindowDragUpdate(String id, DragUpdateDetails details, Size screenSize, EdgeInsets padding) {
    final index = windows.indexWhere((w) => w.id == id);
    if (index == -1) return;
    final window = windows[index];

    if (!window.isMaximized) {
      setState(() {
        window.rect = window.rect.shift(details.delta);
        if (window.rect.top < padding.top) {
          window.rect = Rect.fromLTWH(window.rect.left, padding.top, window.rect.width, window.rect.height);
        }
        _isDragging = true;
      });
    }

    final double dx = details.globalPosition.dx;
    final double dy = details.globalPosition.dy;
    final double w = screenSize.width;
    final double h = screenSize.height;

    final bool isMobile = w < 700;
    bool shouldShowSnapBar = false;

    if (isMobile) {
      if (dx < 30) {
        shouldShowSnapBar = true;
      } else if (_showSnapBar && dx > 120) {
        shouldShowSnapBar = false;
      } else {
        shouldShowSnapBar = _showSnapBar;
      }
    } else {
      if (dy < padding.top + 10) {
        shouldShowSnapBar = true;
      } else if (_showSnapBar && dy > padding.top + 150) {
        shouldShowSnapBar = false;
      } else {
        shouldShowSnapBar = _showSnapBar;
      }
    }

    if (_showSnapBar != shouldShowSnapBar) {
      setState(() => _showSnapBar = shouldShowSnapBar);
    }

    SnapRegion region = SnapRegion.none;
    bool onSnapBar = false;

    if (_showSnapBar) {
      if (isMobile) {
        double barHeight = 400;
        double barTop = (h / 2) - (barHeight / 2);
        if (dx < 80 && dy > barTop && dy < barTop + barHeight) {
          onSnapBar = true;
          double relY = dy - barTop;
          if (relY < 50) region = SnapRegion.left;
          else if (relY < 100) region = SnapRegion.right;
          else if (relY < 130) region = SnapRegion.none;
          else if (relY < 180) region = SnapRegion.leftThird;
          else if (relY < 230) region = SnapRegion.centerThird;
          else if (relY < 280) region = SnapRegion.rightThird;
          else if (relY < 310) region = SnapRegion.none;
          else region = SnapRegion.top;
        }
      } else {
        double centerX = w / 2;
        double barWidth = 360;
        double barStart = centerX - (barWidth / 2);
        if (dy < padding.top + 100 && dx > barStart && dx < barStart + barWidth) {
          onSnapBar = true;
          double relX = dx - barStart;
          if (relX < 50) region = SnapRegion.left;
          else if (relX < 100) region = SnapRegion.right;
          else if (relX < 120) region = SnapRegion.none;
          else if (relX < 170) region = SnapRegion.leftThird;
          else if (relX < 220) region = SnapRegion.centerThird;
          else if (relX < 270) region = SnapRegion.rightThird;
          else if (relX < 290) region = SnapRegion.none;
          else region = SnapRegion.top;
        }
      }
    }

    if (!onSnapBar) {
      const double cornerZone = 50.0;
      const double edgeZone = 20.0;

      if (dx < cornerZone && dy < cornerZone + padding.top) region = SnapRegion.topLeft;
      else if (dx > w - cornerZone && dy < cornerZone + padding.top) region = SnapRegion.topRight;
      else if (dx < cornerZone && dy > h - cornerZone) region = SnapRegion.bottomLeft;
      else if (dx > w - cornerZone && dy > h - cornerZone) region = SnapRegion.bottomRight;
      else if (!isMobile && dy < padding.top + 5) region = SnapRegion.top;
      else if (dy > h - edgeZone) {
        if (dx < w * 0.3) region = SnapRegion.leftThird;
        else if (dx > w * 0.7) region = SnapRegion.rightThird;
        else region = SnapRegion.centerThird;
      }
      else if (dx < edgeZone && !isMobile) region = SnapRegion.left;
      else if (dx > w - edgeZone) region = SnapRegion.right;
    }

    if (activeSnapRegion != region) setState(() => activeSnapRegion = region);
  }

  void onWindowDragEnd(String id, Size screenSize, EdgeInsets padding) {
    setState(() {
      _isDragging = false;
      _showSnapBar = false;
    });

    if (activeSnapRegion == SnapRegion.none) return;
    final index = windows.indexWhere((w) => w.id == id);
    if (index == -1) return;

    setState(() {
      final window = windows[index];
      window.savedRect = window.rect;
      final double safeW = screenSize.width - padding.left - padding.right;
      final double safeH = screenSize.height - padding.top - padding.bottom;
      final double startX = padding.left;
      final double startY = padding.top;
      final hw = safeW/2;
      final hh = safeH/2;
      final tw = safeW/3;
      if (window.isMinimized) window.isMinimized = false;

      switch (activeSnapRegion) {
        case SnapRegion.left: window.rect = Rect.fromLTWH(startX, startY, hw, safeH); window.isMaximized = false; break;
        case SnapRegion.right: window.rect = Rect.fromLTWH(startX + hw, startY, hw, safeH); window.isMaximized = false; break;
        case SnapRegion.top: window.rect = Rect.fromLTWH(startX, startY, safeW, safeH); window.isMaximized = true; break;
        case SnapRegion.topLeft: window.rect = Rect.fromLTWH(startX, startY, hw, hh); window.isMaximized = false; break;
        case SnapRegion.topRight: window.rect = Rect.fromLTWH(startX + hw, startY, hw, hh); window.isMaximized = false; break;
        case SnapRegion.bottomLeft: window.rect = Rect.fromLTWH(startX, startY + hh, hw, hh); window.isMaximized = false; break;
        case SnapRegion.bottomRight: window.rect = Rect.fromLTWH(startX + hw, startY + hh, hw, hh); window.isMaximized = false; break;
        case SnapRegion.leftThird: window.rect = Rect.fromLTWH(startX, startY, tw, safeH); window.isMaximized = false; break;
        case SnapRegion.centerThird: window.rect = Rect.fromLTWH(startX + tw, startY, tw, safeH); window.isMaximized = false; break;
        case SnapRegion.rightThird: window.rect = Rect.fromLTWH(startX + tw*2, startY, tw, safeH); window.isMaximized = false; break;
        default: break;
      }
      activeSnapRegion = SnapRegion.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DesktopProvider(
      state: this,
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final desktopSize = Size(constraints.maxWidth, constraints.maxHeight);
            final padding = MediaQuery.of(context).padding;
            final safeRect = _getSafeRect(desktopSize, padding);
            final bool isMobile = desktopSize.width < 700;

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: widget.background ?? Container(
                    color: const Color(0xFF1E1E1E),
                    child: CustomPaint(painter: GridPatternPainter(), size: Size.infinite),
                  ),
                ),
                Positioned(
                  top: padding.top + 50, left: 30,
                  child: Column(
                    children: widget.apps.map((app) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 30),
                        child: AppIconLauncher(
                          label: app.title,
                          icon: app.icon,
                          color: app.color,
                          onTap: () => openApp(app),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Positioned.fill(child: IgnorePointer(
                    child: CustomPaint(
                        painter: ConnectionsPainter(windows, _lineAnimationController)
                    )
                )),
                if (activeSnapRegion != SnapRegion.none)
                  SnapPreviewOverlay(region: activeSnapRegion, screenSize: desktopSize, padding: padding),
                ...windows.map((window) {
                  if (window.isMaximized) window.rect = safeRect;
                  return FastWindow(
                    key: ValueKey(window.id),
                    window: window,
                    desktopSize: desktopSize,
                    padding: padding,
                    onFocus: () => focusWindow(window.id),
                    onClose: () => closeWindow(window.id),
                    onMaximize: () => toggleMaximize(window.id, desktopSize, padding),
                    onMinimize: () => toggleMinimize(window.id),
                    onUpdate: (rect) => setState(() => window.rect = rect),
                    onDragUpdate: (d) => onWindowDragUpdate(window.id, d, desktopSize, padding),
                    onDragEnd: () => onWindowDragEnd(window.id, desktopSize, padding),
                  );
                }),

                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  top: isMobile
                      ? 0
                      : (_isDragging && _showSnapBar ? padding.top + 10 : -150),
                  bottom: isMobile ? 0 : null,
                  left: isMobile
                      ? (_isDragging && _showSnapBar ? 10 : -90)
                      : 0,
                  right: isMobile ? null : 0,
                  child: Center(
                    child: StaticSnapBar(
                      activeRegion: activeSnapRegion,
                      isVertical: isMobile,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
// کلاس AppIconLauncher بدون تغییر باقی ماند
class AppIconLauncher extends StatelessWidget {
  final String label; final IconData icon; final Color color; final VoidCallback onTap;
  const AppIconLauncher({super.key, required this.label, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) { return GestureDetector(onTap: onTap, child: Column(children: [Container(width: 60, height: 60, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]), child: Icon(icon, color: Colors.white, size: 30)), const SizedBox(height: 8), Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500, shadows: [Shadow(blurRadius: 4)]))])); }
}