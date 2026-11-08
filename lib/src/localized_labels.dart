import 'package:flutter/widgets.dart';

/// Translates GridFlow's default labels using the application's own catalog.
/// Place this above GridDesktop and inside each native appBuilder as needed.
/// Rebuilding the scope refreshes labels without replacing open window content.
class GridLocalizedLabels extends InheritedWidget {
  const GridLocalizedLabels({
    super.key,
    required this.translate,
    required super.child,
  });

  final String Function(String source) translate;

  static String text(BuildContext context, String source) =>
      context
          .dependOnInheritedWidgetOfExactType<GridLocalizedLabels>()
          ?.translate(source) ??
      source;

  // A stable callback may read a catalog that changed with the app's locale.
  @override
  bool updateShouldNotify(GridLocalizedLabels oldWidget) => true;
}
