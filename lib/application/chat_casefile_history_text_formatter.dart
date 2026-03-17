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
  for (final field in fields) {
    final value = field.value.trim();
    if (value.isEmpty) {
      continue;
    }
    buffer.writeln('${field.key}=$value');
  }
  return buffer.toString();
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
