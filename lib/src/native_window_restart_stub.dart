// ignore_for_file: implementation_imports, invalid_use_of_internal_member
import 'package:flutter/widgets.dart';
import 'package:flutter/src/widgets/_window.dart' as windowing;

void prepareNativeWindowRestart(windowing.WindowingOwner owner) {}

void positionGridWindowToRight(
  windowing.WindowController controller, {
  windowing.WindowController? relativeTo,
}) {}

windowing.WindowController createGridWindow({
  required bool launcher,
  required Size size,
  required BoxConstraints constraints,
  required String title,
  required windowing.WindowControllerDelegate delegate,
}) => windowing.WindowController(
  size: size,
  constraints: constraints,
  title: title,
  delegate: delegate,
);
