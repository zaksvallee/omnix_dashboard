class ChatCaseFileHistoryField {
  final String inputKey;
  final String outputKey;

  const ChatCaseFileHistoryField({
    required this.inputKey,
    required this.outputKey,
  });
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
