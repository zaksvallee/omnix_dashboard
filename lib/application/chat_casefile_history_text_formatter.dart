class ChatCaseFileHistoryField {
  final String inputKey;
  final String outputKey;

  const ChatCaseFileHistoryField({
    required this.inputKey,
    required this.outputKey,
  });
}

class ChatCaseFileHeaderField {
  final String key;
  final String value;

  const ChatCaseFileHeaderField({
    required this.key,
    required this.value,
  });
}

String buildChatCaseFileHeader({
  required String title,
  required List<ChatCaseFileHeaderField> fields,
}) {
  final buffer = StringBuffer('$title\n');
  buffer.write(buildChatCaseFileFieldText(fields: fields));
  return buffer.toString();
}

String buildChatCaseFileFieldText({
  required List<ChatCaseFileHeaderField> fields,
  String linePrefix = '',
}) {
  final buffer = StringBuffer();
  for (final field in fields) {
    final value = field.value.trim();
    if (value.isEmpty) {
      continue;
    }
    buffer.write('$linePrefix${field.key}=$value\n');
  }
  return buffer.toString();
}

List<ChatCaseFileHeaderField> buildPromotionShadowHeaderFields({
  required Map<String, Object?> payload,
  String keyPrefix = 'promotion_',
}) {
  return <ChatCaseFileHeaderField>[
    ChatCaseFileHeaderField(
      key: '${keyPrefix}current_validation_status',
      value: (payload['promotionCurrentValidationStatus'] ?? '')
          .toString()
          .trim(),
    ),
    ChatCaseFileHeaderField(
      key: '${keyPrefix}current_strength_summary',
      value: (payload['promotionCurrentStrengthSummary'] ?? '')
          .toString()
          .trim(),
    ),
    ChatCaseFileHeaderField(
      key: '${keyPrefix}shadow_selected_event_id',
      value: (payload['promotionShadowSelectedEventId'] ?? '')
          .toString()
          .trim(),
    ),
    ChatCaseFileHeaderField(
      key: '${keyPrefix}shadow_review_refs',
      value: (payload['promotionShadowReviewRefs'] ?? '').toString().trim(),
    ),
    ChatCaseFileHeaderField(
      key: '${keyPrefix}shadow_review_command',
      value: (payload['promotionShadowReviewCommand'] ?? '')
          .toString()
          .trim(),
    ),
    ChatCaseFileHeaderField(
      key: '${keyPrefix}shadow_case_file_command',
      value: (payload['promotionShadowCaseFileCommand'] ?? '')
          .toString()
          .trim(),
    ),
  ];
}

String buildPromotionShadowFieldText({
  required Map<String, Object?> payload,
  String keyPrefix = 'promotion_',
  String linePrefix = '',
}) {
  return buildChatCaseFileFieldText(
    fields: buildPromotionShadowHeaderFields(
      payload: payload,
      keyPrefix: keyPrefix,
    ),
    linePrefix: linePrefix,
  );
}

String buildChatCaseFileHistoryText({
  required List<Map<String, Object?>> rows,
  required List<ChatCaseFileHistoryField> fields,
}) {
  return rows.asMap().entries.map((entry) {
    final index = entry.key + 1;
    final row = entry.value;
    final buffer = StringBuffer();
    for (final field in fields) {
      final value = (row[field.inputKey] ?? '').toString().trim();
      if (value.isEmpty) {
        continue;
      }
      buffer.write('history_${index}_${field.outputKey}=$value\n');
    }
    return buffer.toString();
  }).join();
}
