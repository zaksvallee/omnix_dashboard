class ClientPushDeliveryFreshness {
  static const Duration watchStartMaxAge = Duration(minutes: 45);
  static const Duration shiftSitrepMaxAge = Duration(hours: 2);

  static bool isFreshForExternalDelivery({
    required String messageKey,
    required String title,
    required DateTime occurredAtUtc,
    DateTime? nowUtc,
  }) {
    final age = (nowUtc ?? DateTime.now().toUtc()).difference(
      occurredAtUtc.toUtc(),
    );
    if (age.isNegative) {
      return true;
    }
    final normalizedKey = messageKey.trim().toLowerCase();
    final normalizedTitle = title.trim().toLowerCase();
    if (_isWatchStart(normalizedKey, normalizedTitle)) {
      return age <= watchStartMaxAge;
    }
    if (_isShiftSitrep(normalizedKey, normalizedTitle)) {
      return age <= shiftSitrepMaxAge;
    }
    return true;
  }

  static bool _isWatchStart(String messageKey, String title) {
    return messageKey.startsWith('tg-watch-start') ||
        messageKey.startsWith('tg-watch-auto-start') ||
        messageKey.startsWith('tg-watch-resync-start') ||
        title == 'monitoring watch active';
  }

  static bool _isShiftSitrep(String messageKey, String title) {
    return messageKey.startsWith('tg-watch-end') ||
        messageKey.startsWith('tg-watch-auto-end') ||
        messageKey.startsWith('tg-watch-resync-end') ||
        title == 'shift summary ready';
  }
}
