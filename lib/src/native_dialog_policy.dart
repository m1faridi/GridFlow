// Flutter's experimental windowing API is isolated here alongside native_windows.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter/foundation.dart' show FlutterExceptionHandler;
import 'package:flutter/widgets.dart';
import 'package:flutter/src/widgets/_window_positioner.dart'
    show WindowPositioner;
import 'package:flutter/src/widgets/_window.dart' as windowing;

/// Keeps Flutter dialogs as navigator overlays while delegating other windows.
///
/// Flutter 3.47.5 has no independent switch for native dialogs. showRawDialog
/// explicitly falls back to its supplied dialog route on UnsupportedError.
/// Use that fallback instead of disabling windowing or replacing showDialog.
class GridDialogWindowingOwner implements windowing.WindowingOwner {
  GridDialogWindowingOwner(this.delegate);

  final windowing.WindowingOwner delegate;

  @override
  windowing.DialogWindowController createDialogWindowController({
    required windowing.DialogWindowControllerDelegate delegate,
    Size? size,
    BoxConstraints? constraints,
    required bool resizable,
    windowing.BaseWindowController? parent,
    String? title,
  }) {
    final signal = _UseOverlayDialog();
    final previousHandler = FlutterError.onError;
    late FlutterExceptionHandler fallbackHandler;
    void restoreHandler() {
      if (identical(FlutterError.onError, fallbackHandler)) {
        FlutterError.onError = previousHandler;
      }
    }

    // Flutter reports the expected fallback as an error. Consume only this
    // exact signal, synchronously, and preserve every unrelated error/handler.
    fallbackHandler = (details) {
      restoreHandler();
      if (identical(details.exception, signal) &&
          details.library == 'widgets library') {
        return;
      }
      previousHandler?.call(details);
    };
    FlutterError.onError = fallbackHandler;
    // Also restore if a caller invokes the controller directly and catches it.
    scheduleMicrotask(restoreHandler);
    throw signal;
  }

  @override
  windowing.RegularWindowController createRegularWindowController({
    required windowing.RegularWindowControllerDelegate delegate,
    Size? size,
    BoxConstraints? constraints,
    required bool resizable,
    String? title,
  }) => this.delegate.createRegularWindowController(
    delegate: delegate,
    size: size,
    constraints: constraints,
    resizable: resizable,
    title: title,
  );

  @override
  windowing.TooltipWindowController createTooltipWindowController({
    required windowing.TooltipWindowControllerDelegate delegate,
    required BoxConstraints constraints,
    required Rect anchorRect,
    required WindowPositioner positioner,
    required windowing.BaseWindowController parent,
  }) => this.delegate.createTooltipWindowController(
    delegate: delegate,
    constraints: constraints,
    anchorRect: anchorRect,
    positioner: positioner,
    parent: parent,
  );

  @override
  windowing.PopupWindowController createPopupWindowController({
    required windowing.PopupWindowControllerDelegate delegate,
    required BoxConstraints constraints,
    required Rect anchorRect,
    required WindowPositioner positioner,
    required windowing.BaseWindowController parent,
  }) => this.delegate.createPopupWindowController(
    delegate: delegate,
    constraints: constraints,
    anchorRect: anchorRect,
    positioner: positioner,
    parent: parent,
  );

  @override
  windowing.SatelliteWindowController createSatelliteWindowController({
    required windowing.SatelliteWindowControllerDelegate delegate,
    required windowing.BaseWindowController parent,
    required WindowPositioner initialPositioner,
    Rect? initialAnchorRect,
    Size? size,
    BoxConstraints? constraints,
    required bool resizable,
    String? title,
  }) => this.delegate.createSatelliteWindowController(
    delegate: delegate,
    parent: parent,
    initialPositioner: initialPositioner,
    initialAnchorRect: initialAnchorRect,
    size: size,
    constraints: constraints,
    resizable: resizable,
    title: title,
  );
}

class _UseOverlayDialog extends UnsupportedError {
  _UseOverlayDialog() : super('GridFlow displays dialogs in their navigator.');
}
