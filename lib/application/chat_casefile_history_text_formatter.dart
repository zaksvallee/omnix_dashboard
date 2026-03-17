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

List<ChatCaseFileHeaderField> buildChatReviewHeaderFields({
  required String reportDate,
  String mode = '',
  String summary = '',
  String focusSummary = '',
  String learningSummary = '',
  String learningMemorySummary = '',
  String historyHeadline = '',
  String historySummary = '',
  String shadowSummary = '',
  String urgencySummary = '',
  String caseFileCommand = '',
  String governanceCommand = '',
  List<String>? reviewRefs,
  int? eventCount,
}) {
  return <ChatCaseFileHeaderField>[
    ChatCaseFileHeaderField(key: 'report_date', value: reportDate),
    ChatCaseFileHeaderField(key: 'mode', value: mode),
    ChatCaseFileHeaderField(key: 'summary', value: summary),
    ChatCaseFileHeaderField(key: 'focus_summary', value: focusSummary),
    ChatCaseFileHeaderField(key: 'learning_summary', value: learningSummary),
    ChatCaseFileHeaderField(
      key: 'learning_memory_summary',
      value: learningMemorySummary,
    ),
    ChatCaseFileHeaderField(key: 'history_headline', value: historyHeadline),
    ChatCaseFileHeaderField(key: 'history_summary', value: historySummary),
    ChatCaseFileHeaderField(key: 'shadow_summary', value: shadowSummary),
    ChatCaseFileHeaderField(key: 'urgency_summary', value: urgencySummary),
    if (reviewRefs != null)
      ChatCaseFileHeaderField(
        key: 'review_refs',
        value: reviewRefs.isEmpty ? 'n/a' : reviewRefs.join(', '),
      ),
    ChatCaseFileHeaderField(key: 'case_file_command', value: caseFileCommand),
    ChatCaseFileHeaderField(
      key: 'governance_command',
      value: governanceCommand,
    ),
    if (eventCount != null)
      ChatCaseFileHeaderField(key: 'events', value: eventCount.toString()),
  ];
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
