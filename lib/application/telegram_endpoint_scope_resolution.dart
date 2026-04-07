List<T> matchingTelegramEndpointEntries<T>({
  required Iterable<T> entries,
  required int? messageThreadId,
  required int? Function(T entry) threadIdOf,
}) {
  return entries
      .where((entry) {
        final candidateThreadId = threadIdOf(entry);
        if (messageThreadId != null) {
          return candidateThreadId == messageThreadId;
        }
        return candidateThreadId == null;
      })
      .toList(growable: false);
}

T? resolveUniqueTelegramEndpointEntry<T>({
  required Iterable<T> entries,
  required int? messageThreadId,
  required int? Function(T entry) threadIdOf,
}) {
  final matchingEntries = matchingTelegramEndpointEntries(
    entries: entries,
    messageThreadId: messageThreadId,
    threadIdOf: threadIdOf,
  );
  if (matchingEntries.length != 1) {
    return null;
  }
  return matchingEntries.single;
}

int countUniqueTelegramEndpointMappings<T>({
  required Iterable<T> entries,
  required String Function(T entry) chatIdOf,
  required int? Function(T entry) threadIdOf,
}) {
  final seen = <String>{};
  for (final entry in entries) {
    final chatId = chatIdOf(entry).trim();
    if (chatId.isEmpty) {
      continue;
    }
    seen.add('$chatId:${threadIdOf(entry) ?? ''}');
  }
  return seen.length;
}

bool hasAmbiguousTelegramEndpointMappings<T>({
  required Iterable<T> entries,
  required String Function(T entry) chatIdOf,
  required int? Function(T entry) threadIdOf,
}) {
  final counts = <String, int>{};
  for (final entry in entries) {
    final chatId = chatIdOf(entry).trim();
    if (chatId.isEmpty) {
      continue;
    }
    final key = '$chatId:${threadIdOf(entry) ?? ''}';
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts.values.any((count) => count > 1);
}

Map<String, dynamic>? resolveUniqueTelegramEndpointRow({
  required List<Map<String, dynamic>> rows,
  required int? messageThreadId,
  String threadField = 'telegram_thread_id',
}) {
  int? rowThread(Map<String, dynamic> row) {
    final raw = (row[threadField] ?? '').toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    return int.tryParse(raw);
  }

  return resolveUniqueTelegramEndpointEntry(
    entries: rows,
    messageThreadId: messageThreadId,
    threadIdOf: rowThread,
  );
}
