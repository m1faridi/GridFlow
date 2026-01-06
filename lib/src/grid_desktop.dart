import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'painters.dart';
import 'window_widget.dart';
import 'snap_overlays.dart';

class GridDesktop extends StatefulWidget {
  /// لیست اپلیکیشن‌هایی که در نوار ابزار (Taskbar) نمایش داده می‌شوند
  final List<DesktopApp> apps;
  final Widget? background;

  const GridDesktop({
    super.key,
    required this.apps,
    this.background,
  });

  @override
  State<GridDesktop> createState() => _GridDesktopState();
}

class _GridDesktopState extends State<GridDesktop> {
  List<WindowItem> windows = [];
  SnapRegion activeSnapRegion = SnapRegion.none;
  bool _isDragging = false;

  Rect _getSafeRect(Size screenSize, EdgeInsets padding) {
    return Rect.fromLTWH(
      padding.left, padding.top,
      screenSize.width - padding.left - padding.right,
      screenSize.height - padding.top - padding.bottom,
    );
  }

  void openApp(DesktopApp app, {String? parentId}) {
    // اگر اپلیکیشن محتوا نداشت، محتوای پیش‌فرض ایجاد کن
    _internalOpenWindow(
        app.title,
        app.icon,
        app.color,
        parentId: parentId,
        customBodyBuilder: app.contentBuilder
    );
  }

  void _internalOpenWindow(String title, IconData icon, Color color, {String? parentId, Widget Function(String id)? customBodyBuilder}) {
    setState(() {
      final size = MediaQuery.of(context).size;
      final padding = MediaQuery.of(context).padding;
      final safeRect = _getSafeRect(size, padding);
      final bool isMobile = size.width < 700;

      WindowItem? parentWindow;
      String currentGroupId;

      if (parentId != null) {
        try {
          parentWindow = windows.firstWhere((w) => w.id == parentId);
          currentGroupId = parentWindow.groupId;
        } catch (_) {
          currentGroupId = DateTime.now().toIso8601String();
        }
      } else {
        currentGroupId = DateTime.now().toIso8601String();
      }

      Rect startRect;
      bool startMaximized = false;
      const double offsetStep = 30.0;

      if (parentWindow != null) {
        if (parentWindow.isMaximized) {
          startRect = safeRect;
          startMaximized = true;
        } else {
          startRect = parentWindow.rect.shift(const Offset(offsetStep, offsetStep));
          startMaximized = false;
          if (startRect.top > size.height - 100) {
            startRect = Rect.fromLTWH(safeRect.left + 20, safeRect.top + 20, startRect.width, startRect.height);
          }
        }
      } else {
        startRect = Rect.fromLTWH(safeRect.left + 40, safeRect.top + 60, 340, 500);
        if (isMobile) {
          startRect = safeRect;
          startMaximized = true;
        }
      }

      final String newId = DateTime.now().toIso8601String();
      for (var w in windows) w.isFocused = false;

      // ساخت محتوا
      Widget content;
      if (customBodyBuilder != null) {
        content = customBodyBuilder(newId);
      } else {
        content = DefaultWindowContent(
          title: title,
          icon: icon,
          color: color,
          onOpenChild: () => _internalOpenWindow("Child of $title", Icons.subdirectory_arrow_right, color, parentId: newId),
        );
      }

      windows.add(WindowItem(
        id: newId,
        parentId: parentId,
        groupId: currentGroupId,
        title: title,
        icon: icon,
        themeColor: color,
        rect: startRect,
        savedRect: startMaximized ? Rect.fromLTWH(safeRect.left + 40, safeRect.top + 60, 340, 500) : startRect,
        isMaximized: startMaximized,
        content: content,
      ));
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
        window.rect = window.savedRect ?? Rect.fromLTWH(safeRect.left + 40, safeRect.top + 60, 340, 500);
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
        window.rect = window.preMinRect ?? const Rect.fromLTWH(100, 100, 350, 500);
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

    SnapRegion region = SnapRegion.none;
    const double cornerZone = 80.0;
    const double edgeZone = 20.0;
    double centerX = w / 2;
    double barWidth = 360;
    double barStart = centerX - (barWidth / 2);
    double barEnd = centerX + (barWidth / 2);
    bool onSnapBar = dx > barStart && dx < barEnd && dy > padding.top && dy < padding.top + 80;

    if (dx < cornerZone && dy < cornerZone + padding.top) region = SnapRegion.topLeft;
    else if (dx > w - cornerZone && dy < cornerZone + padding.top) region = SnapRegion.topRight;
    else if (dx < cornerZone && dy > h - cornerZone) region = SnapRegion.bottomLeft;
    else if (dx > w - cornerZone && dy > h - cornerZone) region = SnapRegion.bottomRight;
    else if (onSnapBar) {
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
    else if (dy < padding.top + 10) {
      region = SnapRegion.top;
    }
    else {
      if (dx < edgeZone) region = SnapRegion.left;
      else if (dx > w - edgeZone) region = SnapRegion.right;
      else if (dy > h - edgeZone) region = SnapRegion.centerThird;
    }

    if (activeSnapRegion != region) setState(() => activeSnapRegion = region);
  }

  void onWindowDragEnd(String id, Size screenSize, EdgeInsets padding) {
    setState(() => _isDragging = false);
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
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktopSize = Size(constraints.maxWidth, constraints.maxHeight);
          final padding = MediaQuery.of(context).padding;
          final safeRect = _getSafeRect(desktopSize, padding);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Background
              Positioned.fill(
                child: widget.background ?? Container(
                  color: const Color(0xFF1E1E1E),
                  child: CustomPaint(painter: GridPatternPainter(), size: Size.infinite),
                ),
              ),

              // Launcher / Taskbar
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

              // Connections
              Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: ConnectionsPainter(windows)))),

              // Snap Preview
              if (activeSnapRegion != SnapRegion.none)
                SnapPreviewOverlay(region: activeSnapRegion, screenSize: desktopSize, padding: padding),

              // Windows
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

              // Snap Bar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                top: _isDragging ? padding.top + 10 : -150,
                left: 0, right: 0,
                child: Center(child: StaticSnapBar(activeRegion: activeSnapRegion)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AppIconLauncher extends StatelessWidget {
  final String label; final IconData icon; final Color color; final VoidCallback onTap;
  const AppIconLauncher({super.key, required this.label, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) { return GestureDetector(onTap: onTap, child: Column(children: [Container(width: 60, height: 60, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]), child: Icon(icon, color: Colors.white, size: 30)), const SizedBox(height: 8), Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500, shadows: [Shadow(blurRadius: 4)]))])); }
}