import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class OperatorStreamEmbedView extends StatefulWidget {
  final Uri uri;

  const OperatorStreamEmbedView({
    super.key,
    required this.uri,
  });

  @override
  State<OperatorStreamEmbedView> createState() => _OperatorStreamEmbedViewState();
}

class _OperatorStreamEmbedViewState extends State<OperatorStreamEmbedView> {
  static int _nextViewId = 0;

  late String _viewType;

  @override
  void initState() {
    super.initState();
    _registerView(widget.uri);
  }

  @override
  void didUpdateWidget(covariant OperatorStreamEmbedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _registerView(widget.uri);
    }
  }

  void _registerView(Uri uri) {
    _viewType = 'onyx-operator-stream-${_nextViewId++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = uri.toString()
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'fullscreen';
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
