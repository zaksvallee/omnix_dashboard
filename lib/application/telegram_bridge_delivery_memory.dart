const int telegramDeliveredMessageKeyLimit = 200;

class TelegramBridgeDeliveryMemory {
  final int limit;

  const TelegramBridgeDeliveryMemory({
    this.limit = telegramDeliveredMessageKeyLimit,
  });

  List<String> mergeDeliveredMessageKeys({
    required Iterable<String> existingKeys,
    required Iterable<String> deliveredKeys,
  }) {
    return mergeTelegramDeliveredMessageKeys(
      existingKeys: existingKeys,
      deliveredKeys: deliveredKeys,
      limit: limit,
    );
  }
}

List<String> mergeTelegramDeliveredMessageKeys({
  required Iterable<String> existingKeys,
  required Iterable<String> deliveredKeys,
  int limit = telegramDeliveredMessageKeyLimit,
}) {
  final merged = <String>[];
  final seen = <String>{};

  void addAll(Iterable<String> values) {
    for (final value in values) {
      final normalized = value.trim();
      if (normalized.isEmpty || !seen.add(normalized)) {
        continue;
      }
      merged.add(normalized);
      if (merged.length >= limit) {
        return;
      }
    }
  }

  addAll(deliveredKeys);
  if (merged.length < limit) {
    addAll(existingKeys);
  }
  return merged.take(limit).toList(growable: false);
}
