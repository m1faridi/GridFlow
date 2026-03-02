import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'models.dart';
import 'painters.dart';
import 'window_widget.dart';

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
  static const double _minBackgroundScale = 0.1;
  static const double _maxBackgroundScale = 1.4;
  static const double _doubleTapZoomFactor = 1.18;
  static const double _canvasHeadroom = 8000.0;
  static const double _edgeAutoScrollBaseSpeed = 180.0;
  static const double _edgeAutoScrollMaxSpeed = 1080.0;
  static const double _edgeAutoScrollRampDistance = 180.0;
  static const double _edgeAutoScrollActivationEpsilon = 1.0;
  static const double _edgeAutoScrollAcceleration = 3400.0;
  static const double _edgeAutoScrollDeceleration = 4800.0;
  static const double _smallScreenEdgeAutoScrollMultiplier = 3.0;
  static const double _edgeDragVelocitySmoothing = 0.24;
  static const double _edgeDragVelocityDecayPerSecond = 6.0;
  static const double _edgeDragSpeedMin = 220.0;
  static const double _edgeDragSpeedMax = 2200.0;
  static const double _edgeDragInfluenceMax = 1.2;
  static const double _dragIntentActivationDistance = 10.0;

  late final ScrollController _horizontalScrollController;
  late final ScrollController _verticalScrollController;
  late final Listenable _backgroundMotionListenable;
  final GlobalKey _canvasViewportKey = GlobalKey();
  Timer? _edgeAutoScrollTimer;
  String? _activeDragWindowId;
  Size? _activeDragScreenSize;
  EdgeInsets? _activeDragPadding;
  String? _dragIntentWindowId;
  bool _dragIntentConfirmed = false;
  double _dragIntentTravel = 0.0;
  Offset _lastConfirmedDragDelta = Offset.zero;
  Offset _edgeAutoScrollVelocity = Offset.zero;
  DateTime? _edgeAutoScrollLastTickAt;
  Offset _edgeDragVelocity = Offset.zero;
  DateTime? _edgeDragLastSampleAt;

  double _backgroundScale = 1.0;
  Offset _backgroundOffset = Offset.zero;
  double _gestureStartBackgroundScale = 1.0;
  Offset _gestureSceneFocalPoint = Offset.zero;
  Offset _lastGlobalFocalPoint = Offset.zero;

  List<WindowItem> windows = [];
  bool _didSetInitialCanvasOffset = false;

  late AnimationController _lineAnimationController;

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
    _verticalScrollController = ScrollController();
    _backgroundMotionListenable = Listenable.merge([
      _horizontalScrollController,
      _verticalScrollController,
    ]);
    _lineAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureInitialCanvasOffset();
    });

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
    if (widget.hasTitleBar != oldWidget.hasTitleBar ||
        widget.isWindowMode != oldWidget.isWindowMode) {
      setState(() {
        for (var window in windows) {
          window.hasTitleBar = widget.hasTitleBar;
        }
      });
    }
  }

  @override
  void dispose() {
    _stopEdgeAutoScrollLoop();
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
    final double scale = _backgroundScale <= 0 ? 1.0 : _backgroundScale;
    final double left = (offsetX + padding.left - _backgroundOffset.dx) / scale;
    final double top = (offsetY + padding.top - _backgroundOffset.dy) / scale;
    final double right =
        (offsetX + screenSize.width - padding.right - _backgroundOffset.dx) /
        scale;
    final double bottom =
        (offsetY + screenSize.height - padding.bottom - _backgroundOffset.dy) /
        scale;

    return Rect.fromLTRB(left, top, right, bottom);
  }

  void _ensureInitialCanvasOffset() {
    if (!mounted || _didSetInitialCanvasOffset) return;

    if (_horizontalScrollController.hasClients) {
      final position = _horizontalScrollController.position;
      final target = _canvasHeadroom
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((position.pixels - target).abs() > 0.5) {
        _horizontalScrollController.jumpTo(target);
      }
    }

    if (_verticalScrollController.hasClients) {
      final position = _verticalScrollController.position;
      final target = _canvasHeadroom
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((position.pixels - target).abs() > 0.5) {
        _verticalScrollController.jumpTo(target);
      }
    }

    _didSetInitialCanvasOffset = true;
  }

  void _rebaseWorldIfNeeded() {
    if (!mounted || windows.isEmpty) return;

    const double rebaseThreshold = 800.0;
    double minLeft = double.infinity;
    double minTop = double.infinity;

    for (final window in windows) {
      minLeft = math.min(minLeft, window.rect.left);
      minTop = math.min(minTop, window.rect.top);

      if (window.savedRect != null) {
        minLeft = math.min(minLeft, window.savedRect!.left);
        minTop = math.min(minTop, window.savedRect!.top);
      }
      if (window.preMinRect != null) {
        minLeft = math.min(minLeft, window.preMinRect!.left);
        minTop = math.min(minTop, window.preMinRect!.top);
      }
    }

    final double shiftX = minLeft < rebaseThreshold
        ? (_canvasHeadroom - minLeft)
        : 0.0;
    final double shiftY = minTop < rebaseThreshold
        ? (_canvasHeadroom - minTop)
        : 0.0;

    if (shiftX == 0.0 && shiftY == 0.0) return;

    final Offset shift = Offset(shiftX, shiftY);
    setState(() {
      for (final window in windows) {
        window.rect = window.rect.shift(shift);
        if (window.savedRect != null) {
          window.savedRect = window.savedRect!.shift(shift);
        }
        if (window.preMinRect != null) {
          window.preMinRect = window.preMinRect!.shift(shift);
        }
      }
    });

    final double scale = _backgroundScale <= 0 ? 1.0 : _backgroundScale;

    if (_horizontalScrollController.hasClients && shiftX != 0.0) {
      final position = _horizontalScrollController.position;
      final target = (position.pixels + (shiftX * scale))
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((target - position.pixels).abs() > 0.5) {
        _horizontalScrollController.jumpTo(target);
      }
    }

    if (_verticalScrollController.hasClients && shiftY != 0.0) {
      final position = _verticalScrollController.position;
      final target = (position.pixels + (shiftY * scale))
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((target - position.pixels).abs() > 0.5) {
        _verticalScrollController.jumpTo(target);
      }
    }
  }

  double _horizontalOffset() => _horizontalScrollController.hasClients
      ? _horizontalScrollController.offset
      : 0;

  double _verticalOffset() => _verticalScrollController.hasClients
      ? _verticalScrollController.offset
      : 0;

  void _beginWindowDragGesture(String id) {
    _dragIntentWindowId = id;
    _dragIntentConfirmed = false;
    _dragIntentTravel = 0.0;
    _lastConfirmedDragDelta = Offset.zero;
    _activeDragWindowId = null;
    _activeDragScreenSize = null;
    _activeDragPadding = null;
    _edgeDragVelocity = Offset.zero;
    _edgeDragLastSampleAt = null;
  }

  void _panCanvasByDelta(Offset delta) {
    if (_horizontalScrollController.hasClients) {
      final position = _horizontalScrollController.position;
      final target = (position.pixels - delta.dx)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if (target != position.pixels) {
        _horizontalScrollController.jumpTo(target);
      }
    }

    if (_verticalScrollController.hasClients) {
      final position = _verticalScrollController.position;
      final target = (position.pixels - delta.dy)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if (target != position.pixels) {
        _verticalScrollController.jumpTo(target);
      }
    }
  }

  double _edgeScrollSpeedFromOverlap(double overlap) {
    if (overlap <= 0.0) return 0.0;
    final double t = (overlap / _edgeAutoScrollRampDistance)
        .clamp(0.0, 1.0)
        .toDouble();
    final double eased = Curves.easeOutCubic.transform(t);
    return _edgeAutoScrollBaseSpeed +
        ((_edgeAutoScrollMaxSpeed - _edgeAutoScrollBaseSpeed) * eased);
  }

  Rect _worldRectToViewportRect(Rect worldRect) {
    final double scale = _backgroundScale <= 0 ? 1.0 : _backgroundScale;
    final double left = (worldRect.left * scale) + _backgroundOffset.dx;
    final double top = (worldRect.top * scale) + _backgroundOffset.dy;
    final double right = (worldRect.right * scale) + _backgroundOffset.dx;
    final double bottom = (worldRect.bottom * scale) + _backgroundOffset.dy;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Offset _computeEdgeAutoScrollForWindow(
    Rect worldRect,
    Size screenSize,
    EdgeInsets padding,
  ) {
    double desiredDx = 0.0;
    double desiredDy = 0.0;
    final bool isSmallScreen = screenSize.width < 700;
    final double speedMultiplier = isSmallScreen
        ? _smallScreenEdgeAutoScrollMultiplier
        : 1.0;

    final Rect windowViewportRect = _worldRectToViewportRect(worldRect);
    final double visibleLeft = _horizontalOffset() + padding.left;
    final double visibleTop = _verticalOffset() + padding.top;
    final double visibleRight =
        visibleLeft + (screenSize.width - padding.left - padding.right);
    final double visibleBottom =
        visibleTop + (screenSize.height - padding.top - padding.bottom);

    final double triggerRight = visibleRight - _edgeAutoScrollActivationEpsilon;
    final double triggerLeft = visibleLeft + _edgeAutoScrollActivationEpsilon;
    final double triggerBottom =
        visibleBottom - _edgeAutoScrollActivationEpsilon;
    final double triggerTop = visibleTop + _edgeAutoScrollActivationEpsilon;

    if (windowViewportRect.right >= triggerRight) {
      final double overlap = windowViewportRect.right - triggerRight;
      desiredDx = _edgeScrollSpeedFromOverlap(overlap);
    } else if (windowViewportRect.left <= triggerLeft) {
      final double overlap = triggerLeft - windowViewportRect.left;
      desiredDx = -_edgeScrollSpeedFromOverlap(overlap);
    }

    if (windowViewportRect.bottom >= triggerBottom) {
      final double overlap = windowViewportRect.bottom - triggerBottom;
      desiredDy = _edgeScrollSpeedFromOverlap(overlap);
    } else if (windowViewportRect.top <= triggerTop) {
      final double overlap = triggerTop - windowViewportRect.top;
      desiredDy = -_edgeScrollSpeedFromOverlap(overlap);
    }

    return Offset(desiredDx * speedMultiplier, desiredDy * speedMultiplier);
  }

  Offset _applyViewportAutoScroll(Offset desiredDelta) {
    double appliedDx = 0.0;
    double appliedDy = 0.0;

    if (desiredDelta.dx != 0.0 && _horizontalScrollController.hasClients) {
      final pos = _horizontalScrollController.position;
      final target = (pos.pixels + desiredDelta.dx)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent)
          .toDouble();
      appliedDx = target - pos.pixels;
      if (appliedDx != 0.0) {
        _horizontalScrollController.jumpTo(target);
      }
    }

    if (desiredDelta.dy != 0.0 && _verticalScrollController.hasClients) {
      final pos = _verticalScrollController.position;
      final target = (pos.pixels + desiredDelta.dy)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent)
          .toDouble();
      appliedDy = target - pos.pixels;
      if (appliedDy != 0.0) {
        _verticalScrollController.jumpTo(target);
      }
    }

    return Offset(appliedDx, appliedDy);
  }

  bool _isNearZeroDelta(Offset value) {
    return value.dx.abs() < 0.01 && value.dy.abs() < 0.01;
  }

  bool _isNearZeroVelocity(Offset value) {
    return value.dx.abs() < 0.5 && value.dy.abs() < 0.5;
  }

  double _stepEdgeVelocity(double current, double target, double dtSeconds) {
    final double delta = target - current;
    if (delta == 0.0) return target;

    final bool accelerating =
        current.sign == target.sign && target.abs() > current.abs();
    final double maxDelta =
        (accelerating
                ? _edgeAutoScrollAcceleration
                : _edgeAutoScrollDeceleration) *
            dtSeconds;

    if (delta.abs() <= maxDelta) {
      return target;
    }
    return current + (delta.sign * maxDelta);
  }

  bool _rectNearlyEquals(Rect a, Rect b) {
    const double epsilon = 0.01;
    return (a.left - b.left).abs() < epsilon &&
        (a.top - b.top).abs() < epsilon &&
        (a.right - b.right).abs() < epsilon &&
        (a.bottom - b.bottom).abs() < epsilon;
  }

  void _ensureEdgeAutoScrollLoop() {
    _edgeAutoScrollLastTickAt ??= DateTime.now();
    _edgeAutoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _tickEdgeAutoScroll(),
    );
  }

  void _stopEdgeAutoScrollLoop() {
    _edgeAutoScrollTimer?.cancel();
    _edgeAutoScrollTimer = null;
    _activeDragWindowId = null;
    _activeDragScreenSize = null;
    _activeDragPadding = null;
    _edgeAutoScrollVelocity = Offset.zero;
    _edgeAutoScrollLastTickAt = null;
    _edgeDragVelocity = Offset.zero;
    _edgeDragLastSampleAt = null;
  }

  void _recordDragVelocity(Offset delta) {
    final DateTime now = DateTime.now();
    final DateTime? lastSampleAt = _edgeDragLastSampleAt;
    _edgeDragLastSampleAt = now;
    if (lastSampleAt == null) return;

    final double dtSeconds = (now.difference(lastSampleAt).inMicroseconds /
            1000000)
        .clamp(1 / 240, 1 / 20)
        .toDouble();
    final Offset sampleVelocity = Offset(
      delta.dx / dtSeconds,
      delta.dy / dtSeconds,
    );
    _edgeDragVelocity = Offset(
      _edgeDragVelocity.dx +
          ((sampleVelocity.dx - _edgeDragVelocity.dx) *
              _edgeDragVelocitySmoothing),
      _edgeDragVelocity.dy +
          ((sampleVelocity.dy - _edgeDragVelocity.dy) *
              _edgeDragVelocitySmoothing),
    );
  }

  double _dragSpeedMultiplierForTarget(Offset targetAutoScroll, DateTime now) {
    if (_isNearZeroVelocity(targetAutoScroll)) return 1.0;

    final DateTime? lastSampleAt = _edgeDragLastSampleAt;
    if (lastSampleAt == null) return 1.0;

    final double idleSeconds =
        (now.difference(lastSampleAt).inMicroseconds / 1000000)
            .clamp(0.0, 2.0)
            .toDouble();
    final double decay = math.exp(-idleSeconds * _edgeDragVelocityDecayPerSecond);
    final Offset decayedVelocity = Offset(
      _edgeDragVelocity.dx * decay,
      _edgeDragVelocity.dy * decay,
    );

    final double targetLength = targetAutoScroll.distance;
    if (targetLength <= 0.001) return 1.0;
    final Offset targetDirection = targetAutoScroll / targetLength;
    final double projectedForwardSpeed = math.max(
      0.0,
      (decayedVelocity.dx * targetDirection.dx) +
          (decayedVelocity.dy * targetDirection.dy),
    );
    final double normalized = ((projectedForwardSpeed - _edgeDragSpeedMin) /
            (_edgeDragSpeedMax - _edgeDragSpeedMin))
        .clamp(0.0, 1.0)
        .toDouble();
    return 1.0 + (normalized * _edgeDragInfluenceMax);
  }

  double _axisAutoScrollWithDragIntent(double targetAxis, double dragAxis) {
    if (targetAxis == 0.0) return 0.0;
    if (dragAxis.abs() < 0.01) return 0.0;
    return targetAxis.sign == dragAxis.sign ? targetAxis : 0.0;
  }

  Offset _applyDragDirectionGate(Offset targetAutoScroll) {
    return Offset(
      _axisAutoScrollWithDragIntent(
        targetAutoScroll.dx,
        _lastConfirmedDragDelta.dx,
      ),
      _axisAutoScrollWithDragIntent(
        targetAutoScroll.dy,
        _lastConfirmedDragDelta.dy,
      ),
    );
  }

  void _tickEdgeAutoScroll() {
    if (!mounted) {
      _stopEdgeAutoScrollLoop();
      return;
    }

    final String? id = _activeDragWindowId;
    final Size? screenSize = _activeDragScreenSize;
    final EdgeInsets? padding = _activeDragPadding;
    if (id == null || screenSize == null || padding == null) {
      return;
    }

    final int index = windows.indexWhere((w) => w.id == id);
    if (index == -1) {
      _stopEdgeAutoScrollLoop();
      return;
    }

    final WindowItem window = windows[index];
    if (window.isMaximized) return;

    final DateTime now = DateTime.now();
    final DateTime? previousTickAt = _edgeAutoScrollLastTickAt;
    _edgeAutoScrollLastTickAt = now;
    final double dtSeconds =
        (previousTickAt == null
                ? (1 / 60)
                : now.difference(previousTickAt).inMicroseconds / 1000000)
            .clamp(1 / 120, 1 / 20)
            .toDouble();

    final bool isMobile = screenSize.width < 700;
    final Offset edgeTargetAutoScroll = _computeEdgeAutoScrollForWindow(
      window.rect,
      screenSize,
      padding,
    );
    final Offset baseTargetAutoScroll = _applyDragDirectionGate(
      edgeTargetAutoScroll,
    );
    final double dragSpeedMultiplier = _dragSpeedMultiplierForTarget(
      baseTargetAutoScroll,
      now,
    );
    final Offset targetAutoScroll = baseTargetAutoScroll * dragSpeedMultiplier;
    _edgeAutoScrollVelocity = Offset(
      _stepEdgeVelocity(
        _edgeAutoScrollVelocity.dx,
        targetAutoScroll.dx,
        dtSeconds,
      ),
      _stepEdgeVelocity(
        _edgeAutoScrollVelocity.dy,
        targetAutoScroll.dy,
        dtSeconds,
      ),
    );

    if (_isNearZeroVelocity(targetAutoScroll) &&
        _isNearZeroVelocity(_edgeAutoScrollVelocity)) {
      return;
    }

    final Offset autoScroll = _applyViewportAutoScroll(
      Offset(
        _edgeAutoScrollVelocity.dx * dtSeconds,
        _edgeAutoScrollVelocity.dy * dtSeconds,
      ),
    );
    if (_isNearZeroDelta(autoScroll)) return;

    final double scale = _backgroundScale <= 0 ? 1.0 : _backgroundScale;
    final Offset autoWorldDelta = Offset(
      autoScroll.dx / scale,
      autoScroll.dy / scale,
    );

    Rect nextRect = window.rect.shift(autoWorldDelta);
    if (isMobile) {
      final Rect safeAfterScroll = _getSafeRect(
        screenSize,
        padding,
        offsetX: _horizontalOffset(),
        offsetY: _verticalOffset(),
      );
      nextRect = _fitRectInsideSafeRect(nextRect, safeAfterScroll);
    }
    if (_rectNearlyEquals(nextRect, window.rect)) return;

    setState(() {
      window.rect = nextRect;
    });

    if (!isMobile) {
      _rebaseWorldIfNeeded();
    }
  }

  Offset _clampBackgroundOffset(Offset offset, Size canvasSize, double scale) {
    if ((scale - 1.0).abs() < 0.0001) return Offset.zero;

    final double targetWidth = canvasSize.width * scale;
    final double targetHeight = canvasSize.height * scale;
    final double rawX = canvasSize.width - targetWidth;
    final double rawY = canvasSize.height - targetHeight;
    final double minX = math.min(0.0, rawX);
    final double maxX = math.max(0.0, rawX);
    final double minY = math.min(0.0, rawY);
    final double maxY = math.max(0.0, rawY);
    final double dx = offset.dx.clamp(minX, maxX).toDouble();
    final double dy = offset.dy.clamp(minY, maxY).toDouble();
    return Offset(dx, dy);
  }

  Offset _toCanvasViewportLocal(Offset globalPosition) {
    final BuildContext? viewportContext = _canvasViewportKey.currentContext;
    if (viewportContext == null) return globalPosition;
    final renderObject = viewportContext.findRenderObject();
    if (renderObject is! RenderBox) return globalPosition;
    return renderObject.globalToLocal(globalPosition);
  }

  void _onBackgroundScaleStart(ScaleStartDetails details) {
    _gestureStartBackgroundScale = _backgroundScale;
    _lastGlobalFocalPoint = details.focalPoint;
    final Offset focalInViewport = _toCanvasViewportLocal(details.focalPoint);
    _gestureSceneFocalPoint =
        (focalInViewport - _backgroundOffset) / _backgroundScale;
  }

  void _onBackgroundScaleUpdate(ScaleUpdateDetails details, Size canvasSize) {
    final bool isPinchGesture =
        details.pointerCount == 0 || details.pointerCount > 1;
    if (!isPinchGesture) {
      final Offset globalDelta = details.focalPoint - _lastGlobalFocalPoint;
      _lastGlobalFocalPoint = details.focalPoint;
      _panCanvasByDelta(globalDelta);
      return;
    }

    final double nextScale = (_gestureStartBackgroundScale * details.scale)
        .clamp(_minBackgroundScale, _maxBackgroundScale)
        .toDouble();
    final Offset focalInViewport = _toCanvasViewportLocal(details.focalPoint);

    final Offset rawOffset =
        focalInViewport - (_gestureSceneFocalPoint * nextScale);
    final Offset nextOffset = _clampBackgroundOffset(
      rawOffset,
      canvasSize,
      nextScale,
    );

    if (nextScale == _backgroundScale && nextOffset == _backgroundOffset)
      return;

    setState(() {
      _backgroundScale = nextScale;
      _backgroundOffset = nextOffset;
    });
  }

  void _onBackgroundPointerSignal(PointerSignalEvent event, Size canvasSize) {
    if (event is! PointerScrollEvent) return;
    if (event.scrollDelta.dy == 0) return;

    final double zoomFactor = math.exp(-event.scrollDelta.dy * 0.0015);
    final Offset focalInViewport = _toCanvasViewportLocal(event.position);
    _zoomBackgroundAtViewportPoint(focalInViewport, canvasSize, zoomFactor);
  }

  void _zoomBackgroundAtViewportPoint(
    Offset viewportPoint,
    Size canvasSize,
    double zoomFactor,
  ) {
    final double nextScale = (_backgroundScale * zoomFactor)
        .clamp(_minBackgroundScale, _maxBackgroundScale)
        .toDouble();
    if ((nextScale - _backgroundScale).abs() < 0.0001) return;

    final Offset scenePoint =
        (viewportPoint - _backgroundOffset) / _backgroundScale;
    final Offset rawOffset = viewportPoint - (scenePoint * nextScale);
    final Offset nextOffset = _clampBackgroundOffset(
      rawOffset,
      canvasSize,
      nextScale,
    );

    setState(() {
      _backgroundScale = nextScale;
      _backgroundOffset = nextOffset;
    });
  }

  void _onBackgroundDoubleTapDown(TapDownDetails details, Size canvasSize) {
    final Offset focalInViewport = _toCanvasViewportLocal(
      details.globalPosition,
    );
    _zoomBackgroundAtViewportPoint(
      focalInViewport,
      canvasSize,
      _doubleTapZoomFactor,
    );
  }

  Rect _fitRectInsideSafeRect(Rect rect, Rect safeRect) {
    final double minWidth = math.min(200.0, safeRect.width);
    final double minHeight = math.min(150.0, safeRect.height);
    final double fittedWidth = rect.width
        .clamp(minWidth, safeRect.width)
        .toDouble();
    final double fittedHeight = rect.height
        .clamp(minHeight, safeRect.height)
        .toDouble();
    final double maxLeft = safeRect.right - fittedWidth;
    final double maxTop = safeRect.bottom - fittedHeight;
    final double fittedLeft = rect.left
        .clamp(safeRect.left, maxLeft)
        .toDouble();
    final double fittedTop = rect.top.clamp(safeRect.top, maxTop).toDouble();
    return Rect.fromLTWH(fittedLeft, fittedTop, fittedWidth, fittedHeight);
  }

  void _ensureWindowVisible(
    Rect rect, {
    bool adjustHorizontal = true,
    bool adjustVertical = true,
  }) {
    if (!mounted) return;

    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final viewportWidth = size.width - padding.left - padding.right;
    final viewportHeight = size.height - padding.top - padding.bottom;
    if (viewportWidth <= 0 || viewportHeight <= 0) return;

    const double margin = 24;
    final double scale = _backgroundScale <= 0 ? 1.0 : _backgroundScale;
    final double translateX = _backgroundOffset.dx;
    final double translateY = _backgroundOffset.dy;

    if (adjustHorizontal && _horizontalScrollController.hasClients) {
      final position = _horizontalScrollController.position;
      final visibleLeft = _horizontalOffset() + padding.left;
      final visibleRight = visibleLeft + viewportWidth;
      final double rectLeft = (rect.left * scale) + translateX;
      final double rectRight = (rect.right * scale) + translateX;
      double target = position.pixels;

      if (rectRight + margin > visibleRight) {
        target = rectRight + margin - padding.left - viewportWidth;
      } else if (rectLeft - margin < visibleLeft) {
        target = rectLeft - margin - padding.left;
      }

      final clamped = target
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if (clamped != position.pixels) {
        _horizontalScrollController.jumpTo(clamped);
      }
    }

    if (adjustVertical && _verticalScrollController.hasClients) {
      final position = _verticalScrollController.position;
      final visibleTop = _verticalOffset() + padding.top;
      final visibleBottom = visibleTop + viewportHeight;
      final double rectTop = (rect.top * scale) + translateY;
      final double rectBottom = (rect.bottom * scale) + translateY;
      double target = position.pixels;

      if (rectBottom + margin > visibleBottom) {
        target = rectBottom + margin - padding.top - viewportHeight;
      } else if (rectTop - margin < visibleTop) {
        target = rectTop - margin - padding.top;
      }

      final clamped = target
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
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
    bool openedAsMaximized = false;

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
      bool startMaximized = isMobile && windows.isEmpty;

      WindowItem? parentWindow;
      if (parentId != null) {
        parentWindow = _findParentWindow(parentId);
        if (parentWindow != null && parentWindow.isMaximized) {
          startMaximized = true;
        } else if (windows.isNotEmpty && windows.last.isMaximized) {
          startMaximized = true;
        }
      } else if (windows.isNotEmpty && windows.last.isMaximized) {
        startMaximized = true;
      }

      double targetWidth = _defaultWindowWidth;
      double targetHeight = safeRect.height;
      WindowItem? referenceWindow =
          parentWindow ?? (windows.isNotEmpty ? windows.last : null);

      if (referenceWindow != null) {
        targetWidth = referenceWindow.rect.width;
        targetHeight = referenceWindow.rect.height;
      }

      final double maxWidth = (safeRect.width - 80)
          .clamp(260.0, double.infinity)
          .toDouble();
      final double maxHeight = safeRect.height
          .clamp(180.0, double.infinity)
          .toDouble();
      targetWidth = targetWidth.clamp(260.0, maxWidth).toDouble();
      targetHeight = targetHeight.clamp(180.0, maxHeight).toDouble();

      Rect startRect;
      Rect savedRect;

      if (startMaximized) {
        startRect = safeRect;
        savedRect = _fitRectInsideSafeRect(
          Rect.fromLTWH(
            safeRect.left + 24,
            safeRect.top + 24,
            targetWidth,
            targetHeight,
          ),
          safeRect,
        );
      } else {
        if (referenceWindow != null) {
          const double openGap = 18;
          final Rect rightOfCurrent = Rect.fromLTWH(
            referenceWindow.rect.right + openGap,
            referenceWindow.rect.top,
            targetWidth,
            targetHeight,
          );
          startRect = rightOfCurrent;
        } else {
          startRect = _fitRectInsideSafeRect(
            Rect.fromLTWH(
              safeRect.left,
              safeRect.top,
              targetWidth,
              targetHeight,
            ),
            safeRect,
          );
        }
        savedRect = startRect;
      }
      openedRect = startRect;
      openedAsMaximized = startMaximized;

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

      final Widget content = WindowScope(windowId: newId, child: innerContent);

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

    if (openedRect != null && !openedAsMaximized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureWindowVisible(
          openedRect!,
          adjustHorizontal: true,
          adjustVertical: false,
        );
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
        window.rect =
            window.savedRect ??
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
        window.rect =
            window.preMinRect ??
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

  void onWindowDragUpdate(
    String id,
    DragUpdateDetails details,
    Size screenSize,
    EdgeInsets padding,
  ) {
    if (_dragIntentWindowId != id) {
      _beginWindowDragGesture(id);
    }

    if (!_dragIntentConfirmed) {
      _dragIntentTravel += details.delta.distance;
      if (_dragIntentTravel < _dragIntentActivationDistance) {
        return;
      }
      _dragIntentConfirmed = true;
    }

    _activeDragWindowId = id;
    _activeDragScreenSize = screenSize;
    _activeDragPadding = padding;
    _lastConfirmedDragDelta = details.delta;
    _ensureEdgeAutoScrollLoop();
    _recordDragVelocity(details.delta);

    final index = windows.indexWhere((w) => w.id == id);
    if (index == -1) return;
    final window = windows[index];
    final bool isMobile = screenSize.width < 700;

    if (!window.isMaximized) {
      Rect nextRect = window.rect.shift(details.delta);

      if (isMobile) {
        final Rect safeAfterScroll = _getSafeRect(
          screenSize,
          padding,
          offsetX: _horizontalOffset(),
          offsetY: _verticalOffset(),
        );
        nextRect = _fitRectInsideSafeRect(nextRect, safeAfterScroll);
      }

      setState(() {
        window.rect = nextRect;
      });

      if (!isMobile) {
        _rebaseWorldIfNeeded();
      }
    }
  }

  void onWindowDragEnd(String id, Size screenSize, EdgeInsets padding) {
    _dragIntentWindowId = null;
    _dragIntentConfirmed = false;
    _dragIntentTravel = 0.0;
    _lastConfirmedDragDelta = Offset.zero;
    _stopEdgeAutoScrollLoop();
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
            final desktopSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final padding = MediaQuery.of(context).padding;
            final safeRect = _getSafeRect(
              desktopSize,
              padding,
              offsetX: _horizontalOffset(),
              offsetY: _verticalOffset(),
            );
            final bool isMobile = desktopSize.width < 700;
            final bool lockBackgroundScroll = windows.any(
              (window) => window.isMaximized && !window.isMinimized,
            );
            final bool blockBackgroundInput = lockBackgroundScroll;
            const double backgroundScrollbarThickness = 10;
            const double backgroundDragInset = backgroundScrollbarThickness + 4;
            const Color backgroundScrollbarThumbColor = Color(0xFF6B7078);
            const Color backgroundScrollbarTrackColor = Color(0x332F343C);
            const Color backgroundScrollbarTrackBorderColor = Color(0x66565C66);
            double canvasWidth = math.max(
              desktopSize.width + (_canvasHeadroom * 2),
              safeRect.right + _canvasHeadroom,
            );
            double canvasHeight = math.max(
              desktopSize.height + (_canvasHeadroom * 2),
              safeRect.bottom + _canvasHeadroom,
            );
            for (final window in windows) {
              final rect = window.isMaximized ? safeRect : window.rect;
              canvasWidth = math.max(canvasWidth, rect.right + 200);
              canvasHeight = math.max(canvasHeight, rect.bottom + 200);
            }
            final canvasSize = Size(canvasWidth, canvasHeight);
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _backgroundMotionListenable,
                      child: widget.background != null
                          ? SizedBox(
                              width: canvasWidth,
                              height: canvasHeight,
                              child: widget.background!,
                            )
                          : null,
                      builder: (context, backgroundChild) {
                        final Offset worldTranslation = Offset(
                          _backgroundOffset.dx -
                              (_horizontalOffset() * _backgroundScale),
                          _backgroundOffset.dy -
                              (_verticalOffset() * _backgroundScale),
                        );

                        if (widget.background != null) {
                          return ClipRect(
                            child: Transform(
                              transform:
                                  Matrix4.diagonal3Values(
                                    _backgroundScale,
                                    _backgroundScale,
                                    1.0,
                                  )..setTranslationRaw(
                                    worldTranslation.dx,
                                    worldTranslation.dy,
                                    0.0,
                                  ),
                              child: backgroundChild,
                            ),
                          );
                        }

                        return ColoredBox(
                          color: const Color(0xFF1E1E1E),
                          child: CustomPaint(
                            painter: GridPatternPainter(
                              scale: _backgroundScale,
                              translation: worldTranslation,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                RawScrollbar(
                  controller: _horizontalScrollController,
                  notificationPredicate: (notification) =>
                      notification.depth == 1 &&
                      notification.metrics.axis == Axis.horizontal,
                  thumbVisibility: !blockBackgroundInput && !isMobile,
                  trackVisibility: !blockBackgroundInput && !isMobile,
                  interactive: !blockBackgroundInput && !isMobile,
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  thickness: backgroundScrollbarThickness,
                  radius: const Radius.circular(10),
                  thumbColor: backgroundScrollbarThumbColor,
                  trackColor: backgroundScrollbarTrackColor,
                  trackBorderColor: backgroundScrollbarTrackBorderColor,
                  child: RawScrollbar(
                    controller: _verticalScrollController,
                    notificationPredicate: (notification) =>
                        notification.depth == 0 &&
                        notification.metrics.axis == Axis.vertical,
                    thumbVisibility: !blockBackgroundInput && !isMobile,
                    trackVisibility: !blockBackgroundInput && !isMobile,
                    interactive: !blockBackgroundInput && !isMobile,
                    thickness: backgroundScrollbarThickness,
                    radius: const Radius.circular(10),
                    thumbColor: backgroundScrollbarThumbColor,
                    trackColor: backgroundScrollbarTrackColor,
                    trackBorderColor: backgroundScrollbarTrackBorderColor,
                    child: SingleChildScrollView(
                      controller: _verticalScrollController,
                      physics: const NeverScrollableScrollPhysics(),
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        physics: const NeverScrollableScrollPhysics(),
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          key: _canvasViewportKey,
                          width: canvasWidth,
                          height: canvasHeight,
                          child: ClipRect(
                            child: Transform(
                              transform:
                                  Matrix4.diagonal3Values(
                                    _backgroundScale,
                                    _backgroundScale,
                                    1.0,
                                  )..setTranslationRaw(
                                    _backgroundOffset.dx,
                                    _backgroundOffset.dy,
                                    0.0,
                                  ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (!blockBackgroundInput)
                                    Positioned.fill(
                                      right: backgroundDragInset,
                                      bottom: backgroundDragInset,
                                      child: Listener(
                                        behavior: HitTestBehavior.opaque,
                                        onPointerSignal: (event) =>
                                            _onBackgroundPointerSignal(
                                              event,
                                              canvasSize,
                                            ),
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onScaleStart: _onBackgroundScaleStart,
                                          onScaleUpdate: (details) =>
                                              _onBackgroundScaleUpdate(
                                                details,
                                                canvasSize,
                                              ),
                                          onDoubleTapDown: (details) =>
                                              _onBackgroundDoubleTapDown(
                                                details,
                                                canvasSize,
                                              ),
                                          child: const SizedBox.expand(),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    top: padding.top + 50,
                                    left: 30,
                                    child: Column(
                                      children: widget.apps.map((app) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 30,
                                          ),
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
                                        painter: ConnectionsPainter(
                                          windows,
                                          _lineAnimationController,
                                        ),
                                      ),
                                    ),
                                  ),
                                  ...windows.map((window) {
                                    return FastWindow(
                                      key: ValueKey(window.id),
                                      window: window,
                                      renderRect: window.isMaximized
                                          ? safeRect
                                          : window.rect,
                                      desktopSize: desktopSize,
                                      padding: padding,
                                      onFocus: () => focusWindow(window.id),
                                      onClose: () => closeWindow(window.id),
                                      onMaximize: () => toggleMaximize(
                                        window.id,
                                        desktopSize,
                                        padding,
                                      ),
                                      onMinimize: () =>
                                          toggleMinimize(window.id),
                                      onUpdate: (rect) {
                                        setState(() {
                                          if (isMobile &&
                                              !window.isMaximized &&
                                              !window.isMinimized) {
                                            final Rect safe = _getSafeRect(
                                              desktopSize,
                                              padding,
                                              offsetX: _horizontalOffset(),
                                              offsetY: _verticalOffset(),
                                            );
                                            window.rect =
                                                _fitRectInsideSafeRect(
                                                  rect,
                                                  safe,
                                                );
                                          } else {
                                            window.rect = rect;
                                          }
                                        });
                                      },
                                      onDragStart: () =>
                                          _beginWindowDragGesture(window.id),
                                      onDragUpdate: (d) => onWindowDragUpdate(
                                        window.id,
                                        d,
                                        desktopSize,
                                        padding,
                                      ),
                                      onDragEnd: () => onWindowDragEnd(
                                        window.id,
                                        desktopSize,
                                        padding,
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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
