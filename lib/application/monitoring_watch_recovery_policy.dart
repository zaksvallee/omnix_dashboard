class MonitoringWatchRecoveryPolicy {
  static const Duration recoveryWindow = Duration(hours: 6);

  const MonitoringWatchRecoveryPolicy();

  bool isExpired({required DateTime recordedAtUtc, required DateTime nowUtc}) {
    return nowUtc.difference(recordedAtUtc.toUtc()) > recoveryWindow;
  }

  String formatLabel({
    required String actor,
    required String outcome,
    required DateTime recordedAtUtc,
  }) {
    final normalizedActor = actor.trim();
    final normalizedOutcome = outcome.trim();
    final utc = recordedAtUtc.toUtc();
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    return '$normalizedActor • $normalizedOutcome • $hour:$minute UTC';
  }
}
