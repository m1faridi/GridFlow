// Experimental controllers expose their view identity through an internal API.
// ignore_for_file: invalid_use_of_internal_member

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_flow/grid_os.dart';
import 'package:grid_flow/src/window_widget.dart';

import 'native_windows_test.dart' show WindowTestBinding, windowTest;

Widget localized(ValueNotifier<String> language, Widget child) {
  // Keep the callback identity stable while the catalog changes.
  String translate(String source) => '${language.value}:$source';
  return ValueListenableBuilder<String>(
    valueListenable: language,
    builder: (context, value, _) =>
        GridLocalizedLabels(translate: translate, child: child),
  );
}

void main() {
  WindowTestBinding();

  testWidgets(
    'open captions and controls translate without replacing content',
    (tester) async {
      final language = ValueNotifier('en');
      addTearDown(language.dispose);
      var builds = 0;
      final app = DesktopApp(
        title: 'Editor',
        titleBuilder: (context) => GridLocalizedLabels.text(context, 'Editor'),
        windowSizeKey: 'editor-page',
        contentBuilder: (_) {
          builds++;
          return const TextField();
        },
      );
      await tester.pumpWidget(
        localized(language, MaterialApp(home: GridDesktop(apps: [app]))),
      );
      final desktop = tester
          .widget<DesktopProvider>(find.byType(DesktopProvider))
          .controller;
      final result = desktop.openApp(app);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Keep my draft');
      final window = tester.widget<FastWindow>(find.byType(FastWindow)).window;
      final rect = window.rect;

      for (final code in ['fa', 'ar', 'en']) {
        language.value = code;
        await tester.pumpAndSettle();
        expect(find.text('$code:Editor'), findsNWidgets(2));
        for (final label in [
          'Zoom in',
          'Zoom out',
          'Reset to 100%',
          'Fit all windows',
        ]) {
          expect(find.byTooltip('$code:$label'), findsOneWidget);
        }
        expect(find.text('Keep my draft'), findsOneWidget);
        expect(
          tester.widget<FastWindow>(find.byType(FastWindow)).window,
          same(window),
        );
        expect(window.rect, rect);
        expect(window.sizeStorageKey, 'editor-page');
        expect(builds, 1);
        expect(tester.takeException(), isNull);
      }
      desktop.closeWindow(window.id, 'saved');
      await tester.pumpAndSettle();
      expect(await result, 'saved');
    },
  );

  testWidgets('default content and minimized cards follow translated titles', (
    tester,
  ) async {
    final language = ValueNotifier('en');
    addTearDown(language.dispose);
    await tester.pumpWidget(
      localized(language, const MaterialApp(home: GridDesktop(apps: []))),
    );
    final desktop = tester
        .widget<DesktopProvider>(find.byType(DesktopProvider))
        .controller;
    desktop.openApp(
      DesktopApp(
        title: 'Empty',
        titleBuilder: (context) => GridLocalizedLabels.text(context, 'Empty'),
      ),
    );
    await tester.pumpAndSettle();
    language.value = 'fa';
    await tester.pumpAndSettle();
    expect(find.text('fa:Empty'), findsNWidgets(2));
    tester.widget<FastWindow>(find.byType(FastWindow)).onMinimize();
    await tester.pumpAndSettle();
    language.value = 'ar';
    await tester.pumpAndSettle();
    final card = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'ar:Restore ar:Empty',
    );
    expect(card, findsOneWidget);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('ar:Empty'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  windowTest(
    'native titles follow locale and retain their views and form state',
    (tester, h) async {
      final language = ValueNotifier('en');
      addTearDown(language.dispose);
      final desktop = await h.mount(
        tester,
        appBuilder: (child) => localized(language, MaterialApp(home: child)),
      );
      var builds = 0;
      final result = desktop.openApp(
        DesktopApp(
          title: 'Editor',
          titleBuilder: (context) =>
              GridLocalizedLabels.text(context, 'Editor'),
          contentBuilder: (_) {
            builds++;
            return const TextField();
          },
        ),
      );
      desktop.openApp(
        DesktopApp(
          title: 'Empty',
          titleBuilder: (context) => GridLocalizedLabels.text(context, 'Empty'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Keep my native draft');
      final editor = h.owner.windows[1];
      final empty = h.owner.windows[2];
      final view = editor.rootView;
      final size = editor.contentSize;
      for (final code in ['fa', 'ar', 'en']) {
        language.value = code;
        await tester.pumpAndSettle();
        expect(editor.title, '$code:Editor');
        expect(empty.title, '$code:Empty');
        expect(find.text('$code:Empty'), findsOneWidget);
        expect(find.text('Keep my native draft'), findsOneWidget);
        expect(editor.rootView, same(view));
        expect(editor.contentSize, size);
        expect(h.owner.windows, hasLength(3));
        expect(builds, 1);
        expect(tester.takeException(), isNull);
      }
      editor.requestClose();
      await tester.pumpAndSettle();
      expect(await result, isNull);
    },
  );
}
