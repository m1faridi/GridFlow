import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grid_flow/grid_os.dart';
import 'package:grid_flow/src/window_chrome.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('opens a desktop app from launcher', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GridDesktop(
          apps: [
            DesktopApp(
              title: 'Test App',
              color: Colors.blue,
              contentBuilder: (_) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Test App'), findsOneWidget);

    await tester.tap(find.text('Test App'));
    await tester.pump();

    expect(find.text('Test App'), findsNWidgets(2));
  });

  testWidgets('Android uses macOS controls and a compact minimized card', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GridDesktop(
          apps: [
            DesktopApp(
              title: 'Test App',
              color: Colors.blue,
              contentBuilder: (_) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Test App'));
    await tester.pump();

    final controls = tester.widget<WindowCaptionControls>(
      find.byType(WindowCaptionControls),
    );
    expect(controls.style, WindowChromeStyle.macos);

    controls.onMinimize();
    await tester.pump();

    final minimizedCard = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.label == 'Restore Test App',
      description: 'compact minimized window card',
    );
    expect(minimizedCard, findsOneWidget);
    expect(tester.getSize(minimizedCard), const Size(196, 46));

    await tester.tap(minimizedCard);
    await tester.pump();
    expect(minimizedCard, findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
