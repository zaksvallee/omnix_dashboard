import 'dart:convert';

class CctvFalsePositiveRule {
  final String zone;
  final String objectLabel;
  final int startHourLocal;
  final int endHourLocal;
  final double? minConfidencePercent;

  const CctvFalsePositiveRule({
    required this.zone,
    required this.objectLabel,
    required this.startHourLocal,
    required this.endHourLocal,
    this.minConfidencePercent,
  });

  factory CctvFalsePositiveRule.fromJson(Map<String, Object?> json) {
    final startHour = _asInt(json['start_hour_local']);
    final endHour = _asInt(json['end_hour_local']);
    return CctvFalsePositiveRule(
      zone: (json['zone'] ?? '').toString().trim().toLowerCase(),
      objectLabel: (json['object_label'] ?? '').toString().trim().toLowerCase(),
      startHourLocal: startHour.clamp(0, 23),
      endHourLocal: endHour.clamp(0, 23),
      minConfidencePercent: _asDouble(json['min_confidence_percent']),
    );
  }

  bool matches({
    required String zoneValue,
    required String objectLabelValue,
    required double? objectConfidencePercent,
    required DateTime occurredAtUtc,
  }) {
    final normalizedZone = zoneValue.trim().toLowerCase();
    final normalizedLabel = objectLabelValue.trim().toLowerCase();
    if (zone.isNotEmpty && normalizedZone != zone) {
      return false;
    }
    if (objectLabel.isNotEmpty && normalizedLabel != objectLabel) {
      return false;
    }
    final confidence = objectConfidencePercent ?? 0;
    if (minConfidencePercent != null && confidence < minConfidencePercent!) {
      return false;
    }
    final localHour = occurredAtUtc.toLocal().hour;
    if (startHourLocal == endHourLocal) {
      return true;
    }
    if (startHourLocal < endHourLocal) {
      return localHour >= startHourLocal && localHour < endHourLocal;
    }
    return localHour >= startHourLocal || localHour < endHourLocal;
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }
}

class CctvFalsePositivePolicy {
  final List<CctvFalsePositiveRule> rules;

  const CctvFalsePositivePolicy({this.rules = const []});

  factory CctvFalsePositivePolicy.fromJsonString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const CctvFalsePositivePolicy();
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) {
        return const CctvFalsePositivePolicy();
      }
      final rules = decoded
          .whereType<Map>()
          .map(
            (entry) => CctvFalsePositiveRule.fromJson(
              entry.map(
                (key, value) => MapEntry(key.toString(), value as Object?),
              ),
            ),
          )
          .toList(growable: false);
      return CctvFalsePositivePolicy(rules: rules);
    } catch (_) {
      return const CctvFalsePositivePolicy();
    }
  }

  bool get enabled => rules.isNotEmpty;

  bool shouldSuppress({
    required String zone,
    required String objectLabel,
    required double? objectConfidencePercent,
    required DateTime occurredAtUtc,
  }) {
    if (!enabled) {
      return false;
    }
    return rules.any(
      (rule) => rule.matches(
        zoneValue: zone,
        objectLabelValue: objectLabel,
        objectConfidencePercent: objectConfidencePercent,
        occurredAtUtc: occurredAtUtc,
      ),
    );
  }

  String summaryLabel() {
    if (rules.isEmpty) {
      return 'rules 0';
    }
    final distinctZones = rules
        .map((rule) => rule.zone)
        .where((zone) => zone.isNotEmpty)
        .toSet()
        .length;
    return 'rules ${rules.length} • zones $distinctZones';
  }
}
