class GuardPositionSummary {
  final String guardId;
  final String clientId;
  final String siteId;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime recordedAtUtc;

  const GuardPositionSummary({
    required this.guardId,
    required this.clientId,
    required this.siteId,
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    required this.recordedAtUtc,
  });

  factory GuardPositionSummary.fromHeartbeatPayload(
    Map<String, Object?> payload, {
    required String fallbackGuardId,
    required String fallbackClientId,
    required String fallbackSiteId,
    required DateTime fallbackRecordedAtUtc,
  }) {
    return GuardPositionSummary(
      guardId: _stringValue(payload['guard_id'], fallbackGuardId),
      clientId: _stringValue(payload['client_id'], fallbackClientId),
      siteId: _stringValue(payload['site_id'], fallbackSiteId),
      latitude: _doubleValue(payload['latitude']),
      longitude: _doubleValue(payload['longitude']),
      accuracyMeters: _nullableDoubleValue(payload['accuracy_meters']),
      recordedAtUtc:
          DateTime.tryParse((payload['recorded_at'] ?? '').toString())
              ?.toUtc() ??
          fallbackRecordedAtUtc,
    );
  }

  static String _stringValue(Object? raw, String fallback) {
    final normalized = (raw ?? '').toString().trim();
    return normalized.isEmpty ? fallback : normalized;
  }

  static double _doubleValue(Object? raw, {double fallback = 0}) {
    return _nullableDoubleValue(raw) ?? fallback;
  }

  static double? _nullableDoubleValue(Object? raw) {
    if (raw is num) {
      return raw.toDouble();
    }
    return double.tryParse((raw ?? '').toString().trim());
  }
}
