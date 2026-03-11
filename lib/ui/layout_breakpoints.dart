import 'package:flutter/widgets.dart';

bool isHandsetLayout(
  BuildContext context, {
  double widthBreakpoint = 900,
  double shortestSideBreakpoint = 700,
}) {
  final size = MediaQuery.sizeOf(context);
  return size.width < widthBreakpoint ||
      size.shortestSide < shortestSideBreakpoint;
}

bool allowEmbeddedPanelScroll(
  BuildContext context, {
  double minWidth = 1280,
  double minHeight = 820,
}) {
  final size = MediaQuery.sizeOf(context);
  if (isHandsetLayout(context)) {
    return false;
  }
  return size.width >= minWidth && size.height >= minHeight;
}
