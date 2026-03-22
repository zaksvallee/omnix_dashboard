import 'dart:math' as math;

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

bool isWidescreenLayout(
  BuildContext context, {
  double widthBreakpoint = 2200,
  double? viewportWidth,
}) {
  if (isHandsetLayout(context)) {
    return false;
  }
  final width = viewportWidth ?? MediaQuery.sizeOf(context).width;
  return width >= widthBreakpoint;
}

bool isUltrawideLayout(
  BuildContext context, {
  double widthBreakpoint = 3000,
  double? viewportWidth,
}) {
  if (isHandsetLayout(context)) {
    return false;
  }
  final width = viewportWidth ?? MediaQuery.sizeOf(context).width;
  return width >= widthBreakpoint;
}

double commandSurfaceMaxWidth(
  BuildContext context, {
  required double compactDesktopWidth,
  double? viewportWidth,
  double widescreenBreakpoint = 2200,
  double ultrawideBreakpoint = 3000,
  double widescreenFillFactor = 0.92,
}) {
  final width = viewportWidth ?? MediaQuery.sizeOf(context).width;
  if (isHandsetLayout(context)) {
    return width;
  }
  if (width >= ultrawideBreakpoint) {
    return width;
  }
  if (width >= widescreenBreakpoint) {
    return math.max(compactDesktopWidth, width * widescreenFillFactor);
  }
  return compactDesktopWidth;
}
