import 'dart:math' as math;
import 'dart:ui';

/// Screen coordinates are physical pixels, including on secondary monitors.
Offset nativeWindowRightOrigin({
  required Rect anchor,
  required Rect workArea,
  required double scale,
}) {
  final gap = (5 * scale).roundToDouble();
  final drop = (32 * scale).roundToDouble();
  // Keep the title reachable near an edge instead of jumping to screen origin.
  final maxLeft = math.max(workArea.left, workArea.right - 160 * scale);
  final maxTop = math.max(workArea.top, workArea.bottom - 80 * scale);
  return Offset(
    (anchor.right + gap).clamp(workArea.left, maxLeft).roundToDouble(),
    (anchor.top + drop).clamp(workArea.top, maxTop).roundToDouble(),
  );
}
