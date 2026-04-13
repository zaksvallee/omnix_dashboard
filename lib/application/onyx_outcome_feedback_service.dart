import 'package:supabase/supabase.dart';

enum OnyxAlertOutcome {
  trueThreat,
  falseAlarm,
  unknown,
  guardDispatched,
  armedResponse,
  clientAcknowledged,
}

class OnyxZoneSignalAccuracy {
  final String zoneId;
  final String timeOfDay;
  final double falseAlarmRate;
  final double trueThreatRate;
  final double recommendedThresholdAdjustment;

  const OnyxZoneSignalAccuracy({
    required this.zoneId,
    required this.timeOfDay,
    required this.falseAlarmRate,
    required this.trueThreatRate,
    required this.recommendedThresholdAdjustment,
  });
}

class OnyxSignalAccuracySnapshot {
  final String siteId;
  final List<OnyxZoneSignalAccuracy> zoneBreakdown;
  final double falseAlarmRate;
  final double trueThreatRate;
  final List<String> topFalsePositiveZones;
  final List<String> topTruePositiveZones;
  final double recommendedThresholdAdjustment;
  final Map<String, double> zoneThresholds;

  const OnyxSignalAccuracySnapshot({
    required this.siteId,
    required this.zoneBreakdown,
    required this.falseAlarmRate,
    required this.trueThreatRate,
    required this.topFalsePositiveZones,
    required this.topTruePositiveZones,
    required this.recommendedThresholdAdjustment,
    required this.zoneThresholds,
  });
}

class OnyxOutcomeFeedbackService {
  final SupabaseClient _client;
  final DateTime Function() _clock;

  const OnyxOutcomeFeedbackService({
    required SupabaseClient client,
    DateTime Function()? clock,
  }) : _client = client,
       _clock = clock ?? DateTime.now;

  Future<void> recordOutcome(
    String alertId,
    OnyxAlertOutcome outcome,
    String operatorId,
    String? note, {
    String? siteId,
    String? clientId,
    String? zoneId,
    double? confidenceAtTime,
    String? powerModeAtTime,
  }) async {
    final normalizedAlertId = alertId.trim();
    if (normalizedAlertId.isEmpty) {
      return;
    }
    await _client.from('onyx_alert_outcomes').upsert(<String, Object?>{
      'alert_id': normalizedAlertId,
      'site_id': (siteId ?? '').trim(),
      'client_id': (clientId ?? '').trim(),
      'zone_id': (zoneId ?? '').trim(),
      'outcome': outcome.name,
      'operator_id': operatorId.trim(),
      'note': (note ?? '').trim().isEmpty ? null : note!.trim(),
      'occurred_at': _clock().toUtc().toIso8601String(),
      'confidence_at_time': confidenceAtTime,
      'power_mode_at_time': (powerModeAtTime ?? '').trim().isEmpty
          ? null
          : powerModeAtTime!.trim(),
    }, onConflict: 'alert_id');
  }

  Future<OnyxSignalAccuracySnapshot> getSignalAccuracy(String siteId) async {
    final normalizedSiteId = siteId.trim();
    if (normalizedSiteId.isEmpty) {
      return const OnyxSignalAccuracySnapshot(
        siteId: '',
        zoneBreakdown: <OnyxZoneSignalAccuracy>[],
        falseAlarmRate: 0,
        trueThreatRate: 0,
        topFalsePositiveZones: <String>[],
        topTruePositiveZones: <String>[],
        recommendedThresholdAdjustment: 0,
        zoneThresholds: <String, double>{},
      );
    }
    final sinceUtc = _clock().toUtc().subtract(const Duration(days: 7));
    final dynamic rows = await _client
        .from('onyx_alert_outcomes')
        .select()
        .eq('site_id', normalizedSiteId)
        .gte('occurred_at', sinceUtc.toIso8601String())
        .order('occurred_at', ascending: false)
        .limit(1000);
    final normalizedRows = rows is List
        ? rows
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    if (normalizedRows.isEmpty) {
      return OnyxSignalAccuracySnapshot(
        siteId: normalizedSiteId,
        zoneBreakdown: const <OnyxZoneSignalAccuracy>[],
        falseAlarmRate: 0,
        trueThreatRate: 0,
        topFalsePositiveZones: const <String>[],
        topTruePositiveZones: const <String>[],
        recommendedThresholdAdjustment: 0,
        zoneThresholds: const <String, double>{},
      );
    }

    final buckets = <String, List<Map<String, dynamic>>>{};
    var falseAlarmCount = 0;
    var trueThreatCount = 0;
    for (final row in normalizedRows) {
      final zoneId = (row['zone_id'] ?? '').toString().trim();
      if (zoneId.isEmpty) {
        continue;
      }
      final timeOfDay = _timeBucket(_date(row['occurred_at']) ?? sinceUtc);
      buckets
          .putIfAbsent('$zoneId|$timeOfDay', () => <Map<String, dynamic>>[])
          .add(row);
      final outcome = (row['outcome'] ?? '').toString().trim();
      if (outcome == OnyxAlertOutcome.falseAlarm.name) {
        falseAlarmCount += 1;
      }
      if (outcome == OnyxAlertOutcome.trueThreat.name ||
          outcome == OnyxAlertOutcome.armedResponse.name ||
          outcome == OnyxAlertOutcome.guardDispatched.name) {
        trueThreatCount += 1;
      }
    }

    final zoneBreakdown = <OnyxZoneSignalAccuracy>[];
    final falseByZone = <String, double>{};
    final trueByZone = <String, double>{};
    final thresholds = <String, double>{};
    for (final entry in buckets.entries) {
      final parts = entry.key.split('|');
      final zoneId = parts.first;
      final timeOfDay = parts.last;
      final total = entry.value.length;
      if (total <= 0) {
        continue;
      }
      final falseCount = entry.value
          .where(
            (row) =>
                (row['outcome'] ?? '').toString().trim() ==
                OnyxAlertOutcome.falseAlarm.name,
          )
          .length;
      final trueCount = entry.value.where((row) {
        final outcome = (row['outcome'] ?? '').toString().trim();
        return outcome == OnyxAlertOutcome.trueThreat.name ||
            outcome == OnyxAlertOutcome.armedResponse.name ||
            outcome == OnyxAlertOutcome.guardDispatched.name;
      }).length;
      final falseRate = falseCount / total;
      final trueRate = trueCount / total;
      final adjustment = _recommendedAdjustment(falseRate, trueRate);
      zoneBreakdown.add(
        OnyxZoneSignalAccuracy(
          zoneId: zoneId,
          timeOfDay: timeOfDay,
          falseAlarmRate: falseRate,
          trueThreatRate: trueRate,
          recommendedThresholdAdjustment: adjustment,
        ),
      );
      falseByZone.update(
        zoneId,
        (value) => value + falseRate,
        ifAbsent: () => falseRate,
      );
      trueByZone.update(
        zoneId,
        (value) => value + trueRate,
        ifAbsent: () => trueRate,
      );
      thresholds[zoneId] = (thresholds[zoneId] ?? 0) + adjustment;
    }

    final totalOutcomes = normalizedRows.length;
    final double recommendedThresholdAdjustment = zoneBreakdown.isEmpty
        ? 0
        : zoneBreakdown
                  .map((entry) => entry.recommendedThresholdAdjustment)
                  .reduce((a, b) => a + b) /
              zoneBreakdown.length;
    return OnyxSignalAccuracySnapshot(
      siteId: normalizedSiteId,
      zoneBreakdown: List<OnyxZoneSignalAccuracy>.unmodifiable(zoneBreakdown),
      falseAlarmRate: totalOutcomes == 0 ? 0 : falseAlarmCount / totalOutcomes,
      trueThreatRate: totalOutcomes == 0 ? 0 : trueThreatCount / totalOutcomes,
      topFalsePositiveZones: _topZones(falseByZone),
      topTruePositiveZones: _topZones(trueByZone),
      recommendedThresholdAdjustment: recommendedThresholdAdjustment,
      zoneThresholds: thresholds.map(
        (zoneId, adjustment) =>
            MapEntry(zoneId, _resolvedThreshold(adjustment)),
      ),
    );
  }

  Future<Map<String, double>> zoneThresholdsForSite(String siteId) async {
    final snapshot = await getSignalAccuracy(siteId);
    return snapshot.zoneThresholds;
  }

  double _recommendedAdjustment(double falseRate, double trueRate) {
    if (falseRate > 0.40) {
      return 0.05;
    }
    if (trueRate > 0.60) {
      return -0.05;
    }
    return 0;
  }

  double _resolvedThreshold(double adjustment) {
    final threshold = 0.55 + adjustment;
    if (threshold > 0.75) {
      return 0.75;
    }
    if (threshold < 0.45) {
      return 0.45;
    }
    return double.parse(threshold.toStringAsFixed(2));
  }

  List<String> _topZones(Map<String, double> rates) {
    final ordered = rates.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    return ordered.take(3).map((entry) => entry.key).toList(growable: false);
  }

  String _timeBucket(DateTime occurredAtUtc) {
    final hour = occurredAtUtc.toUtc().hour;
    if (hour < 6) {
      return 'overnight';
    }
    if (hour < 12) {
      return 'morning';
    }
    if (hour < 18) {
      return 'afternoon';
    }
    return 'evening';
  }
}

DateTime? _date(Object? value) =>
    DateTime.tryParse((value ?? '').toString().trim())?.toUtc();
