import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

void logUiAction(String action, {Map<String, Object?> context = const {}}) {
  final sanitizedContext = <String, Object?>{};
  for (final entry in context.entries) {
    final value = entry.value;
    if (value == null ||
        value is num ||
        value is bool ||
        value is String ||
        value is List ||
        value is Map) {
      sanitizedContext[entry.key] = value;
    } else {
      sanitizedContext[entry.key] = value.toString();
    }
  }

  final payload = <String, Object?>{
    'action': action,
    if (sanitizedContext.isNotEmpty) 'context': sanitizedContext,
    'captured_at_utc': DateTime.now().toUtc().toIso8601String(),
  };
  final message = jsonEncode(payload);
  developer.log(message, name: 'ONYX_UI_ACTION');
  debugPrint('ONYX_UI_ACTION $message');
}
