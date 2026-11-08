import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_flow/grid_os.dart';
import 'package:grid_flow/src/window_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_windows_test.dart' show WindowTestBinding, windowTest;

Future<void> reload(WidgetTester tester) async {
  unawaited(tester.binding.reassembleApplication());
  await tester.pumpAndSettle();
}

Widget form(String label) => Column(children: [Text(label), const TextField()]);

void main() {
  WindowTestBinding();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('canvas hot reload refreshes content and retains window state', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: GridDesktop(apps: const [])));
    final desktop = tester
        .widget<DesktopProvider>(find.byType(DesktopProvider))
        .controller;
    var label = 'Before reload';
    var builds = 0;
    final result = desktop.openApp(
      DesktopApp(
        title: 'Editor',
        contentBuilder: (_) {
          builds++;
          return form(label);
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Keep this draft');
    final window = tester.widget<FastWindow>(find.byType(FastWindow));
    final rect = window.window.rect;
    expect(builds, 1);
    window.onUpdate(rect.shift(const Offset(20, 10)));
    await tester.pumpAndSettle();
    expect(builds, 1, reason: 'Moving a window must not rerun its builder');
    final movedRect = window.window.rect;
    label = 'After reload';

    await reload(tester);

    expect(find.text('After reload'), findsOneWidget);
    expect(find.text('Before reload'), findsNothing);
    expect(find.text('Keep this draft'), findsOneWidget);
    expect(builds, 2);
    expect(
      tester.widget<FastWindow>(find.byType(FastWindow)).window,
      same(window.window),
    );
    expect(window.window.rect, movedRect);
    desktop.closeWindow(window.window.id, 'saved');
    await tester.pumpAndSettle();
    expect(await result, 'saved');
  });

  windowTest('native hot reload refreshes content and app wrapper in place', (
    tester,
    h,
  ) async {
    var label = 'Before reload';
    var builds = 0;
    var wrapperBuilds = 0;
    final desktop = await h.mount(
      tester,
      appBuilder: (child) {
        wrapperBuilds++;
        return MaterialApp(title: label, home: child);
      },
    );
    final result = desktop.openApp(
      DesktopApp(
        title: 'Editor',
        contentBuilder: (_) {
          builds++;
          return form(label);
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Keep this draft');
    final nativeWindow = h.owner.windows.last;
    expect(builds, 1);
    expect(wrapperBuilds, 1);
    label = 'After reload';

    await reload(tester);

    expect(find.text('After reload'), findsOneWidget);
    expect(find.text('Keep this draft'), findsOneWidget);
    expect(builds, 2);
    expect(wrapperBuilds, 2);
    expect(
      tester.widgetList<MaterialApp>(find.byType(MaterialApp)).last.title,
      'After reload',
    );
    expect(h.owner.windows, hasLength(2));
    expect(h.owner.windows.last, same(nativeWindow));
    expect(nativeWindow.destroyed, isFalse);
    nativeWindow.requestClose();
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  windowTest('registered native builders refresh during repeated hot reloads', (
    tester,
    h,
  ) async {
    var label = 'Version 1';
    final launches = <NativeWindowLaunch>[];
    final desktop = await h.mount(
      tester,
      builders: {
        'editor': (launch) {
          launches.add(launch);
          return form(label);
        },
      },
    );
    unawaited(desktop.openApp(DesktopApp(title: 'Editor', nativeId: 'editor')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Keep this draft');
    for (final version in ['Version 2', 'Version 3']) {
      label = version;
      await reload(tester);
      expect(find.text(version), findsOneWidget);
      expect(find.text('Keep this draft'), findsOneWidget);
      expect(h.owner.windows, hasLength(2));
    }
    expect(launches, hasLength(3));
    expect(
      launches.every((launch) => identical(launch, launches.first)),
      isTrue,
    );
  });
}
