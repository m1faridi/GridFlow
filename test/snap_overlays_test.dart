import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_flow/src/models.dart';
import 'package:grid_flow/src/snap_overlays.dart';

void main() {
  testWidgets(
    'snap previews stay valid when the viewport is smaller than the margins',
    (tester) async {
      for (final region in SnapRegion.values) {
        for (final size in [
          Size.zero,
          const Size(30, 30),
          const Size(800, 600),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Stack(
                children: [
                  SnapPreviewOverlay(
                    region: region,
                    screenSize: size,
                    padding: const EdgeInsets.all(20),
                  ),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$region at $size');
          final positioned = tester.widget<AnimatedPositioned>(
            find.byType(AnimatedPositioned),
          );
          expect(positioned.width, greaterThanOrEqualTo(0));
          expect(positioned.height, greaterThanOrEqualTo(0));
        }
      }
    },
  );
}
