import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grid_flow/grid_os.dart';

void main() {
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
}
