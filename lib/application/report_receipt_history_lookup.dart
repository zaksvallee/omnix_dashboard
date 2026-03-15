class ReportReceiptHistoryLookup {
  static T? findByEventId<T>(
    Iterable<T> rows,
    String? eventId,
    String Function(T row) eventIdOf,
  ) {
    final normalizedEventId = eventId?.trim();
    if (normalizedEventId == null || normalizedEventId.isEmpty) {
      return null;
    }
    for (final row in rows) {
      if (eventIdOf(row).trim() == normalizedEventId) {
        return row;
      }
    }
    return null;
  }
}
