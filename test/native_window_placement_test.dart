import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:grid_flow/src/native_window_placement.dart';

void main() {
  test('opens beside the current outer frame with a gap and downward step', () {
    expect(
      nativeWindowRightOrigin(
        anchor: const Rect.fromLTWH(100, 80, 400, 300),
        workArea: const Rect.fromLTWH(0, 24, 1920, 1016),
        scale: 1,
      ),
      const Offset(505, 112),
    );
  });

  test('Windows physical pixels scale the gap and title visibility limits', () {
    expect(
      nativeWindowRightOrigin(
        anchor: const Rect.fromLTWH(200, 160, 800, 600),
        workArea: const Rect.fromLTWH(0, 48, 3840, 2032),
        scale: 2,
      ),
      const Offset(1010, 224),
    );
    expect(
      nativeWindowRightOrigin(
        anchor: const Rect.fromLTWH(3000, 1900, 800, 600),
        workArea: const Rect.fromLTWH(0, 48, 3840, 2032),
        scale: 2,
      ),
      const Offset(3520, 1920),
    );
  });

  test('screen edges retain a reachable title without jumping to origin', () {
    expect(
      nativeWindowRightOrigin(
        anchor: const Rect.fromLTWH(1600, 950, 400, 300),
        workArea: const Rect.fromLTWH(0, 24, 1920, 1016),
        scale: 1,
      ),
      const Offset(1760, 960),
    );
  });

  test('macOS reflected Y coordinates keep placement on the opener screen', () {
    // A secondary screen lies left of and above the main display. Its AppKit
    // visible frame (-1920, 1080, 1920, 1056) is reflected into downward Y.
    expect(
      nativeWindowRightOrigin(
        anchor: const Rect.fromLTWH(-1700, -2000, 400, 300),
        workArea: const Rect.fromLTWH(-1920, -2136, 1920, 1056),
        scale: 1,
      ),
      const Offset(-1295, -1968),
    );
    expect(
      nativeWindowRightOrigin(
        anchor: const Rect.fromLTWH(-300, -1120, 400, 300),
        workArea: const Rect.fromLTWH(-1920, -2136, 1920, 1056),
        scale: 1,
      ),
      const Offset(-160, -1160),
    );
  });
}
