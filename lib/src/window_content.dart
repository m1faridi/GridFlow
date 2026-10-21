import 'package:flutter/widgets.dart';

/// Keeps window content stable during drag/resize, while allowing hot reload
/// to run its original builder again without replacing the window or its state.
class WindowContent extends StatefulWidget {
  WindowContent({super.key, required this.builder}) : _initialChild = builder();

  final Widget Function() builder;
  final Widget _initialChild;

  @override
  State<WindowContent> createState() => _WindowContentState();
}

class _WindowContentState extends State<WindowContent> {
  late Widget _child = widget._initialChild;
  bool _needsRefresh = false;

  @override
  void didUpdateWidget(WindowContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _child = widget._initialChild;
    _needsRefresh = false;
  }

  @override
  void reassemble() {
    super.reassemble();
    // Build after the tree has reassembled, using the reloaded callback. Keep
    // the same element position so Flutter can retain the child's State.
    _needsRefresh = true;
  }

  @override
  Widget build(BuildContext context) {
    if (_needsRefresh) {
      _child = widget.builder();
      _needsRefresh = false;
    }
    return _child;
  }
}
