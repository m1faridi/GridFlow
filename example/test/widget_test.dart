import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gridflow/main.dart';

void main() {
  testWidgets('Example app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyDesktop()));
    expect(find.byType(MyDesktop), findsOneWidget);
  });
}
