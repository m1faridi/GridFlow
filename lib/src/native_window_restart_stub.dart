// ignore_for_file: implementation_imports, invalid_use_of_internal_member
import 'package:flutter/widgets.dart';
import 'package:flutter/src/widgets/_window.dart' as windowing;

void prepareNativeWindowRestart(windowing.WindowingOwner owner) {}

windowing.RegularWindowController createGridRegularWindow({
  required bool launcher,
  required Size size,
  required BoxConstraints constraints,
  required String title,
  required windowing.RegularWindowControllerDelegate delegate,
}) => windowing.RegularWindowController(
  size: size,
  constraints: constraints,
  title: title,
  delegate: delegate,
);
