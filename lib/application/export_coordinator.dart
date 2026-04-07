import 'dart:convert';

import 'package:flutter/services.dart';

import '../ui/ui_action_logger.dart';

class ExportCoordinator {
  static const JsonEncoder _prettyEncoder = JsonEncoder.withIndent('  ');

  const ExportCoordinator();

  Future<void> copyJson(dynamic data, {String? label}) {
    return copyText(
      _prettyEncoder.convert(data),
      label: label ?? 'export.copy_json',
    );
  }

  Future<void> copyCsv(List<String> lines, {String? label}) {
    return copyText(
      lines.join('\n'),
      label: label ?? 'export.copy_csv',
    );
  }

  Future<void> copyText(String text, {String? label}) async {
    await Clipboard.setData(ClipboardData(text: text));
    logUiAction(label?.trim().isNotEmpty == true ? label! : 'export.copy_text');
  }
}
