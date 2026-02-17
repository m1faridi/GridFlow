import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models.dart';
import 'painters.dart';
import 'window_widget.dart';
import 'snap_overlays.dart';

abstract class DesktopController {
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
  void closeById(String id, [dynamic result]) => _controller.closeWindow(id, result);
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
    final provider = context.dependOnInheritedWidgetOfExactType<DesktopProvider>();
    if (provider == null) return null;
    return DesktopHandle._(provider.controller, context);
  }

  @override
  bool updateShouldNotify(DesktopProvider oldWidget) => false;
}

class GridDesktop extends StatefulWidget {
  final List<DesktopApp> apps;
  final Widget? background;
  final List<DesktopApp>? autoStartApps;
  final bool isWindowMode;
  final bool hasTitleBar;

  const GridDesktop({
    super.key,
    required this.apps,
    this.background,
    this.autoStartApps,
    this.isWindowMode = false,
    this.hasTitleBar = true,
  });

  @override
  State<GridDesktop> createState() => _GridDesktopState();
}

class _GridDesktopState extends State<GridDesktop>
    with SingleTickerProviderStateMixin
    implements DesktopController {
  static const double _defaultWindowWidth = 500;
  static const double _defaultWindowHeight = 760;

  late final ScrollController _horizontalScrollController;
  late final ScrollController _verticalScrollController;

  List<WindowItem> windows = [];
  SnapRegion activeSnapRegion = SnapRegion.none;
  bool _isDragging = false;
  bool _showSnapBar = false;

  late AnimationController _lineAnimationController;

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
    _verticalScrollController = ScrollController();
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
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _lineAnimationController.dispose();
    super.dispose();
  }

  Rect _getSafeRect(
    Size screenSize,
    EdgeInsets padding, {
    double offsetX = 0,
    double offsetY = 0,
  }) {
    return Rect.fromLTWH(
      offsetX + padding.left,
      offsetY + padding.top,
      screenSize.width - padding.left - padding.right,
      screenSize.height - padding.top - padding.bottom,
    );
  }

  double _horizontalOffset() =>
      _horizontalScrollController.hasClients ? _horizontalScrollController.offset : 0;

  double _verticalOffset() =>
      _verticalScrollController.hasClients ? _verticalScrollController.offset : 0;

  void _panCanvas(DragUpdateDetails details) {
    if (_horizontalScrollController.hasClients) {
      final position = _horizontalScrollController.position;
      final target = (position.pixels - details.delta.dx)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if (target != position.pixels) {
        _horizontalScrollController.jumpTo(target);
      }
    }

    if (_verticalScrollController.hasClients) {
      final position = _verticalScrollController.position;
      final target = (position.pixels - details.delta.dy)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if (target != position.pixels) {
        _verticalScrollController.jumpTo(target);
      }
    }
  }

  void _ensureWindowVisible(Rect rect) {
    if (!mounted) return;

    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final viewportWidth = size.width - padding.left - padding.right;
    final viewportHeight = size.height - padding.top - padding.bottom;
    if (viewportWidth <= 0 || viewportHeight <= 0) return;

    const double margin = 24;

    if (_horizontalScrollController.hasClients) {
      final position = _horizontalScrollController.position;
      final visibleLeft = _horizontalOffset() + padding.left;
      final visibleRight = visibleLeft + viewportWidth;
      double target = position.pixels;

      if (rect.right + margin > visibleRight) {
        target = rect.right + margin - padding.left - viewportWidth;
      } else if (rect.left - margin < visibleLeft) {
        target = rect.left - margin - padding.left;
      }

      final clamped = target.clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
      if (clamped != position.pixels) {
        _horizontalScrollController.jumpTo(clamped);
      }
    }

    if (_verticalScrollController.hasClients) {
      final position = _verticalScrollController.position;
      final visibleTop = _verticalOffset() + padding.top;
      final visibleBottom = visibleTop + viewportHeight;
      double target = position.pixels;

      if (rect.bottom + margin > visibleBottom) {
        target = rect.bottom + margin - padding.top - viewportHeight;
      } else if (rect.top - margin < visibleTop) {
        target = rect.top - margin - padding.top;
      }

      final clamped = target.clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
      if (clamped != position.pixels) {
        _verticalScrollController.jumpTo(clamped);
      }
    }
  }

  WindowItem? _findParentWindow(String parentId) {
    for (final window in windows) {
      if (window.id == parentId) {
        return window;
      }
    }
    for (final window in windows.reversed) {
      if (window.connectionTag == parentId) {
        return window;
      }
    }
    return null;
  }

  @override
  Future<dynamic> openApp(DesktopApp app, {String? parentId}) {
    return _internalOpenWindow(
      app.title,
      app.color,
      parentId: parentId,
      customBodyBuilder: app.contentBuilder,
      connectionTag: app.connectionTag,
      isClosable: app.isClosable,
    );
  }

  Future<dynamic> _internalOpenWindow(
      String title,
      Color color, {
        String? parentId,
        Widget Function(String id)? customBodyBuilder,
        String? connectionTag,
        bool isClosable = true,
        bool appHasTitleBar = true,
      }) {
    final completer = Completer<dynamic>();
    Rect? openedRect;

    setState(() {
      final size = MediaQuery.of(context).size;
      final padding = MediaQuery.of(context).padding;
      final safeRect = _getSafeRect(
        size,
        padding,
        offsetX: _horizontalOffset(),
        offsetY: _verticalOffset(),
      );
      final String newId = DateTime.now().toIso8601String();

      final bool finalHasTitleBar = widget.hasTitleBar && appHasTitleBar;

      final bool isMobile = size.width < 700;
      bool startMaximized = isMobile;

      WindowItem? parentWindow;
      if (parentId != null) {
        parentWindow = _findParentWindow(parentId);
        if (parentWindow != null && parentWindow.isMaximized) {
          startMaximized = true;
        }
      } else if (windows.isNotEmpty && windows.last.isMaximized) {
        startMaximized = true;
      }

      double targetWidth = _defaultWindowWidth;
      double targetHeight = _defaultWindowHeight;
      WindowItem? referenceWindow = parentWindow ?? (windows.isNotEmpty ? windows.last : null);

      if (referenceWindow != null) {
        targetWidth = referenceWindow.rect.width;
        targetHeight = referenceWindow.rect.height;
      }

      final double maxWidth = (safeRect.width - 80).clamp(260.0, double.infinity).toDouble();
      final double maxHeight = (safeRect.height - 80).clamp(180.0, double.infinity).toDouble();
      targetWidth = targetWidth.clamp(260.0, maxWidth).toDouble();
      targetHeight = targetHeight.clamp(180.0, maxHeight).toDouble();

      Rect startRect;
      Rect savedRect;

      if (startMaximized) {
        startRect = safeRect;
        savedRect = Rect.fromLTWH(
          safeRect.left + 40,
          safeRect.top + 40,
          targetWidth,
          targetHeight,
        );
      } else {
        double startX = safeRect.left + 50;
        double startY = safeRect.top + 50;
        const double gap = 20.0;

        if (referenceWindow != null) {
          startX = referenceWindow.rect.right + gap;
          startY = referenceWindow.rect.top;
        }

        startRect = Rect.fromLTWH(startX, startY, targetWidth, targetHeight);
        savedRect = startRect;
      }
      openedRect = startRect;

      /// مهم‌ترین اصلاح:
      /// محتوای پنجره باید حتماً زیر WindowScope باشد تا WindowScope.of(context) در child null نشود.
      final Widget innerContent = (customBodyBuilder != null)
          ? customBodyBuilder(newId)
          : Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, color.withValues(alpha: 0.05)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      );

      final Widget content = WindowScope(
        windowId: newId,
        child: innerContent,
      );

      windows.add(
        WindowItem(
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
          hasTitleBar: finalHasTitleBar,
          completer: completer,
        ),
      );

      focusWindow(newId);
    });

    if (openedRect != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureWindowVisible(openedRect!);
      });
    }

    return completer.future;
  }

  @override
  void closeWindow(String id, [dynamic result]) {
    final index = windows.indexWhere((w) => w.id == id);
    if (index != -1) {
      final window = windows[index];
      if (window.completer != null && !window.completer!.isCompleted) {
        window.completer!.complete(result);
      }
      setState(() => windows.removeAt(index));
    }
  }

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
    final safeRect = _getSafeRect(
      screenSize,
      padding,
      offsetX: _horizontalOffset(),
      offsetY: _verticalOffset(),
    );
    setState(() {
      final window = windows[index];
      if (window.isMaximized) {
        window.rect = window.savedRect ??
            Rect.fromLTWH(
              safeRect.left + 50,
              safeRect.top + 50,
              _defaultWindowWidth,
              _defaultWindowHeight,
            );
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
        window.rect = window.preMinRect ??
            Rect.fromLTWH(100, 100, _defaultWindowWidth, _defaultWindowHeight);
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
      } else if (dx < edgeZone && !isMobile) region = SnapRegion.left;
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
      final double startX = _horizontalOffset() + padding.left;
      final double startY = _verticalOffset() + padding.top;

      final hw = safeW / 2;
      final hh = safeH / 2;
      final tw = safeW / 3;

      if (window.isMinimized) window.isMinimized = false;

      switch (activeSnapRegion) {
        case SnapRegion.left:
          window.rect = Rect.fromLTWH(startX, startY, hw, safeH);
          window.isMaximized = false;
          break;
        case SnapRegion.right:
          window.rect = Rect.fromLTWH(startX + hw, startY, hw, safeH);
          window.isMaximized = false;
          break;
        case SnapRegion.top:
          window.rect = Rect.fromLTWH(startX, startY, safeW, safeH);
          window.isMaximized = true;
          break;
        case SnapRegion.topLeft:
          window.rect = Rect.fromLTWH(startX, startY, hw, hh);
          window.isMaximized = false;
          break;
        case SnapRegion.topRight:
          window.rect = Rect.fromLTWH(startX + hw, startY, hw, hh);
          window.isMaximized = false;
          break;
        case SnapRegion.bottomLeft:
          window.rect = Rect.fromLTWH(startX, startY + hh, hw, hh);
          window.isMaximized = false;
          break;
        case SnapRegion.bottomRight:
          window.rect = Rect.fromLTWH(startX + hw, startY + hh, hw, hh);
          window.isMaximized = false;
          break;
        case SnapRegion.leftThird:
          window.rect = Rect.fromLTWH(startX, startY, tw, safeH);
          window.isMaximized = false;
          break;
        case SnapRegion.centerThird:
          window.rect = Rect.fromLTWH(startX + tw, startY, tw, safeH);
          window.isMaximized = false;
          break;
        case SnapRegion.rightThird:
          window.rect = Rect.fromLTWH(startX + tw * 2, startY, tw, safeH);
          window.isMaximized = false;
          break;
        default:
          break;
      }

      activeSnapRegion = SnapRegion.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DesktopProvider(
      controller: this,
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final desktopSize = Size(constraints.maxWidth, constraints.maxHeight);
            final padding = MediaQuery.of(context).padding;
            final safeRect = _getSafeRect(
              desktopSize,
              padding,
              offsetX: _horizontalOffset(),
              offsetY: _verticalOffset(),
            );
            final bool isMobile = desktopSize.width < 700;
            const double backgroundScrollbarThickness = 10;
            const double backgroundDragInset = backgroundScrollbarThickness + 4;
            double canvasWidth = math.max(desktopSize.width, safeRect.right);
            double canvasHeight = math.max(desktopSize.height, safeRect.bottom);
            for (final window in windows) {
              final rect = window.isMaximized ? safeRect : window.rect;
              canvasWidth = math.max(canvasWidth, rect.right + 200);
              canvasHeight = math.max(canvasHeight, rect.bottom + 200);
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                  RawScrollbar(
                    controller: _verticalScrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    interactive: true,
                    thickness: backgroundScrollbarThickness,
                    radius: const Radius.circular(10),
                    thumbColor: const Color(0xFF22C55E),
                    trackColor: const Color(0x3322C55E),
                    trackBorderColor: const Color(0x6622C55E),
                    child: SingleChildScrollView(
                      controller: _verticalScrollController,
                      physics: const ClampingScrollPhysics(),
                      scrollDirection: Axis.vertical,
                      child: RawScrollbar(
                        controller: _horizontalScrollController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        interactive: true,
                        scrollbarOrientation: ScrollbarOrientation.bottom,
                        thickness: backgroundScrollbarThickness,
                        radius: const Radius.circular(10),
                        thumbColor: const Color(0xFF22C55E),
                        trackColor: const Color(0x3322C55E),
                        trackBorderColor: const Color(0x6622C55E),
                        child: SingleChildScrollView(
                          controller: _horizontalScrollController,
                          physics: const ClampingScrollPhysics(),
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: canvasWidth,
                            height: canvasHeight,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Positioned.fill(
                                  child: widget.background ??
                                      Container(
                                        color: const Color(0xFF1E1E1E),
                                        child: CustomPaint(
                                          painter: GridPatternPainter(),
                                          size: Size.infinite,
                                        ),
                                      ),
                                ),
                                Positioned.fill(
                                  right: backgroundDragInset,
                                  bottom: backgroundDragInset,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onPanUpdate: _panCanvas,
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                                Positioned(
                                  top: padding.top + 50,
                                  left: 30,
                                  child: Column(
                                    children: widget.apps.map((app) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 30),
                                        child: AppIconLauncher(
                                          label: app.title,
                                          color: app.color,
                                          onTap: () => openApp(app),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: ConnectionsPainter(windows, _lineAnimationController),
                                    ),
                                  ),
                                ),
                                ...windows.map((window) {
                                  return FastWindow(
                                    key: ValueKey(window.id),
                                    window: window,
                                    renderRect: window.isMaximized ? safeRect : window.rect,
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
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (activeSnapRegion != SnapRegion.none)
                    SnapPreviewOverlay(region: activeSnapRegion, screenSize: desktopSize, padding: padding),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    top: isMobile ? 0 : (_isDragging && _showSnapBar ? padding.top + 10 : -150),
                    bottom: isMobile ? 0 : null,
                    left: isMobile ? (_isDragging && _showSnapBar ? 10 : -90) : 0,
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

class AppIconLauncher extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const AppIconLauncher({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              shadows: [Shadow(blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}
