import 'dart:async';
import 'dart:math' as math;

import 'onyx_site_profile_service.dart';

enum OnyxAlertSensitivity { allMotion, suspiciousOnly, off }

enum OnyxProactiveDetectionKind { human, vehicle }

class SiteAlertConfig {
  final String siteId;
  final String siteType;
  final int expectedOccupancy;
  final String alertWindowStart;
  final String alertWindowEnd;
  final String timezone;
  final OnyxAlertSensitivity perimeterSensitivity;
  final OnyxAlertSensitivity semiPerimeterSensitivity;
  final OnyxAlertSensitivity indoorSensitivity;
  final int loiterDetectionMinutes;
  final bool perimeterSequenceAlert;
  final OnyxAlertSensitivity quietHoursSensitivity;
  final OnyxAlertSensitivity daySensitivity;
  final String vehicleDaytimeThreshold;

  const SiteAlertConfig({
    required this.siteId,
    required this.siteType,
    required this.expectedOccupancy,
    required this.alertWindowStart,
    required this.alertWindowEnd,
    required this.timezone,
    required this.perimeterSensitivity,
    required this.semiPerimeterSensitivity,
    required this.indoorSensitivity,
    required this.loiterDetectionMinutes,
    required this.perimeterSequenceAlert,
    required this.quietHoursSensitivity,
    required this.daySensitivity,
    required this.vehicleDaytimeThreshold,
  });

  factory SiteAlertConfig.fromRow(Map<String, dynamic> row) {
    return SiteAlertConfig(
      siteId: (row['site_id'] as String? ?? '').trim(),
      siteType: (row['site_type'] as String? ?? 'private_residence')
          .trim()
          .toLowerCase(),
      expectedOccupancy: _parseInt(row['expected_occupancy']) ?? 0,
      alertWindowStart:
          (row['alert_window_start'] as String? ?? '23:00').trim().isEmpty
          ? '23:00'
          : (row['alert_window_start'] as String? ?? '23:00').trim(),
      alertWindowEnd:
          (row['alert_window_end'] as String? ?? '08:00').trim().isEmpty
          ? '08:00'
          : (row['alert_window_end'] as String? ?? '08:00').trim(),
      timezone:
          (row['timezone'] as String? ?? 'Africa/Johannesburg').trim().isEmpty
          ? 'Africa/Johannesburg'
          : (row['timezone'] as String? ?? 'Africa/Johannesburg').trim(),
      perimeterSensitivity: _parseSensitivity(
        row['perimeter_sensitivity'],
        fallback: OnyxAlertSensitivity.suspiciousOnly,
      ),
      semiPerimeterSensitivity: _parseSensitivity(
        row['semi_perimeter_sensitivity'],
        fallback: OnyxAlertSensitivity.suspiciousOnly,
      ),
      indoorSensitivity: _parseSensitivity(
        row['indoor_sensitivity'],
        fallback: OnyxAlertSensitivity.off,
      ),
      loiterDetectionMinutes: _parseInt(row['loiter_detection_minutes']) ?? 3,
      perimeterSequenceAlert:
          _parseBool(row['perimeter_sequence_alert']) ?? true,
      quietHoursSensitivity: _parseSensitivity(
        row['quiet_hours_sensitivity'],
        fallback: OnyxAlertSensitivity.allMotion,
      ),
      daySensitivity: _parseSensitivity(
        row['day_sensitivity'],
        fallback: OnyxAlertSensitivity.suspiciousOnly,
      ),
      vehicleDaytimeThreshold:
          (row['vehicle_daytime_threshold'] as String? ?? 'quiet_hours_only')
              .trim()
              .toLowerCase(),
    );
  }

  factory SiteAlertConfig.defaults(String siteId) {
    return SiteAlertConfig(
      siteId: siteId.trim(),
      siteType: 'private_residence',
      expectedOccupancy: 0,
      alertWindowStart: '23:00',
      alertWindowEnd: '08:00',
      timezone: 'Africa/Johannesburg',
      perimeterSensitivity: OnyxAlertSensitivity.suspiciousOnly,
      semiPerimeterSensitivity: OnyxAlertSensitivity.suspiciousOnly,
      indoorSensitivity: OnyxAlertSensitivity.off,
      loiterDetectionMinutes: 3,
      perimeterSequenceAlert: true,
      quietHoursSensitivity: OnyxAlertSensitivity.allMotion,
      daySensitivity: OnyxAlertSensitivity.suspiciousOnly,
      vehicleDaytimeThreshold: 'quiet_hours_only',
    );
  }
}

class OnyxProactiveAlertDecision {
  final String siteId;
  final int channelId;
  final String zoneType;
  final String zoneName;
  final bool isPerimeter;
  final bool isIndoor;
  final OnyxProactiveDetectionKind detectionKind;
  final DateTime detectedAt;
  final bool withinAlertWindow;
  final bool isLoitering;
  final bool isSequence;
  final int loiterMinutes;
  final String message;

  const OnyxProactiveAlertDecision({
    required this.siteId,
    required this.channelId,
    required this.zoneType,
    required this.zoneName,
    required this.isPerimeter,
    required this.isIndoor,
    required this.detectionKind,
    required this.detectedAt,
    required this.withinAlertWindow,
    required this.isLoitering,
    required this.isSequence,
    required this.loiterMinutes,
    required this.message,
  });

  String get deduplicationKey {
    return <String>[
      siteId,
      '$channelId',
      zoneType,
      zoneName,
      detectionKind.name,
      isPerimeter ? 'perimeter' : 'non-perimeter',
      isIndoor ? 'indoor' : 'non-indoor',
      withinAlertWindow ? 'quiet' : 'day',
      isLoitering ? 'loiter' : 'single',
      isSequence ? 'sequence' : 'local',
    ].join('|');
  }
}

class OnyxProactiveAlertService {
  final Future<SiteAlertConfig?> Function(String siteId) readConfig;
  final OnyxSiteProfileService profileService;
  final Duration sequenceWindow;
  final Duration alertCooldown;
  final StreamController<OnyxProactiveAlertDecision> _alertController =
      StreamController<OnyxProactiveAlertDecision>.broadcast();
  final Map<String, List<_SiteDetectionRecord>> _detectionsBySite =
      <String, List<_SiteDetectionRecord>>{};
  final Map<String, DateTime> _lastAlertAtByDeduplicationKey =
      <String, DateTime>{};

  OnyxProactiveAlertService({
    required this.readConfig,
    required this.profileService,
    this.sequenceWindow = const Duration(minutes: 5),
    this.alertCooldown = const Duration(minutes: 2),
  });

  Stream<OnyxProactiveAlertDecision> get alerts => _alertController.stream;

  Future<void> evaluateDetection({
    required String siteId,
    required int channelId,
    required String zoneType,
    required String zoneName,
    required bool isPerimeter,
    required OnyxProactiveDetectionKind detectionKind,
    required DateTime detectedAt,
  }) async {
    final normalizedSiteId = siteId.trim();
    if (normalizedSiteId.isEmpty || channelId <= 0) {
      return;
    }
    final config =
        await readConfig(normalizedSiteId) ?? SiteAlertConfig.defaults(siteId);
    final profile = await profileService.loadProfile(normalizedSiteId);
    final normalizedZoneType = _normalizeZoneType(zoneType, isPerimeter);
    final normalizedZoneName = zoneName.trim().isEmpty
        ? 'Channel $channelId'
        : zoneName.trim();
    final isIndoor = normalizedZoneType == 'indoor';
    final record = _SiteDetectionRecord(
      channelId: channelId,
      zoneType: normalizedZoneType,
      zoneName: normalizedZoneName,
      isPerimeter: isPerimeter,
      isIndoor: isIndoor,
      detectionKind: detectionKind,
      detectedAt: detectedAt.toUtc(),
    );
    final history = _detectionsBySite.putIfAbsent(
      normalizedSiteId,
      () => <_SiteDetectionRecord>[],
    );
    history.add(record);
    _pruneDetections(
      siteId: normalizedSiteId,
      now: detectedAt.toUtc(),
      config: config,
    );

    final loiterWindowMinutes = math.max(config.loiterDetectionMinutes, 1);
    final loitering = _isLoitering(
      normalizedSiteId,
      channelId,
      detectedAt,
      loiterWindowMinutes: loiterWindowMinutes,
    );
    final sequence =
        config.perimeterSequenceAlert &&
        _isPerimeterSequence(normalizedSiteId, detectedAt);
    final observedDistinctPresenceCount = _recentDistinctPresenceCount(
      normalizedSiteId,
      detectedAt,
    );
    final profileDecision = await profileService.evaluateDetection(
      siteId: normalizedSiteId,
      event: DetectionEvent(
        siteId: normalizedSiteId,
        channelId: channelId,
        zoneName: normalizedZoneName,
        zoneType: normalizedZoneType,
        isPerimeter: isPerimeter,
        isIndoor: isIndoor,
        detectionKind: detectionKind,
        detectedAtUtc: detectedAt.toUtc(),
        isLoitering: loitering,
        isPerimeterSequence: sequence,
        observedDistinctPresenceCount: observedDistinctPresenceCount,
      ),
      profile: profile,
    );
    if (!profileDecision.shouldAlert) {
      return;
    }
    final afterHours = profileDecision.afterHours;
    final decision = OnyxProactiveAlertDecision(
      siteId: normalizedSiteId,
      channelId: channelId,
      zoneType: normalizedZoneType,
      zoneName: normalizedZoneName,
      isPerimeter: isPerimeter,
      isIndoor: isIndoor,
      detectionKind: detectionKind,
      detectedAt: detectedAt.toUtc(),
      withinAlertWindow: afterHours,
      isLoitering: loitering,
      isSequence: sequence,
      loiterMinutes: _loiteringDurationMinutes(
        normalizedSiteId,
        channelId,
        detectedAt,
        loiterWindowMinutes: loiterWindowMinutes,
      ),
      message: _buildAlertMessage(
        profile: profile,
        zoneName: normalizedZoneName,
        zoneType: normalizedZoneType,
        isPerimeter: isPerimeter,
        detectionKind: detectionKind,
        detectedAt: detectedAt.toUtc(),
        isLoitering: loitering,
        isSequence: sequence,
        alertDecision: profileDecision,
        loiterMinutes: _loiteringDurationMinutes(
          normalizedSiteId,
          channelId,
          detectedAt,
          loiterWindowMinutes: loiterWindowMinutes,
        ),
      ),
    );
    final lastAlertAt =
        _lastAlertAtByDeduplicationKey[decision.deduplicationKey];
    if (lastAlertAt != null &&
        detectedAt.toUtc().difference(lastAlertAt) < alertCooldown) {
      return;
    }
    _lastAlertAtByDeduplicationKey[decision.deduplicationKey] = detectedAt
        .toUtc();
    if (!_alertController.isClosed) {
      _alertController.add(decision);
    }
  }

  bool _isLoitering(
    String siteId,
    int channelId,
    DateTime now, {
    required int loiterWindowMinutes,
  }) {
    final history = _detectionsBySite[siteId];
    if (history == null || history.isEmpty) {
      return false;
    }
    final cutoff = now.toUtc().subtract(Duration(minutes: loiterWindowMinutes));
    final matchingEvents = history.where(
      (record) =>
          record.channelId == channelId && !record.detectedAt.isBefore(cutoff),
    );
    return matchingEvents.length >= 3;
  }

  bool _isPerimeterSequence(String siteId, DateTime now) {
    final history = _detectionsBySite[siteId];
    if (history == null || history.isEmpty) {
      return false;
    }
    final cutoff = now.toUtc().subtract(sequenceWindow);
    final recentChannels = history
        .where(
          (record) =>
              !record.detectedAt.isBefore(cutoff) &&
              (record.isPerimeter || record.zoneType == 'semi_perimeter'),
        )
        .map((record) => record.channelId)
        .toSet();
    return recentChannels.length >= 3;
  }

  void resetSite(String siteId) {
    final normalizedSiteId = siteId.trim();
    if (normalizedSiteId.isEmpty) {
      return;
    }
    _detectionsBySite.remove(normalizedSiteId);
    _lastAlertAtByDeduplicationKey.removeWhere(
      (key, _) => key.startsWith('$normalizedSiteId|'),
    );
  }

  Future<void> dispose() async {
    await _alertController.close();
    _detectionsBySite.clear();
    _lastAlertAtByDeduplicationKey.clear();
  }

  void _pruneDetections({
    required String siteId,
    required DateTime now,
    required SiteAlertConfig config,
  }) {
    final history = _detectionsBySite[siteId];
    if (history == null || history.isEmpty) {
      return;
    }
    final retention = Duration(
      minutes:
          math.max(
            math.max(config.loiterDetectionMinutes, sequenceWindow.inMinutes),
            config.expectedOccupancy > 0 ? 120 : 0,
          ) +
          2,
    );
    final cutoff = now.toUtc().subtract(retention);
    history.removeWhere((record) => record.detectedAt.isBefore(cutoff));
  }

  int _loiteringDurationMinutes(
    String siteId,
    int channelId,
    DateTime now, {
    required int loiterWindowMinutes,
  }) {
    final history = _detectionsBySite[siteId];
    if (history == null || history.isEmpty) {
      return loiterWindowMinutes;
    }
    final cutoff = now.toUtc().subtract(Duration(minutes: loiterWindowMinutes));
    final matching =
        history
            .where(
              (record) =>
                  record.channelId == channelId &&
                  !record.detectedAt.isBefore(cutoff),
            )
            .toList(growable: false)
          ..sort((left, right) => left.detectedAt.compareTo(right.detectedAt));
    if (matching.length < 2) {
      return loiterWindowMinutes;
    }
    final elapsed = now.toUtc().difference(matching.first.detectedAt);
    return math.max(1, elapsed.inMinutes);
  }

  int _recentDistinctPresenceCount(String siteId, DateTime now) {
    final history = _detectionsBySite[siteId];
    if (history == null || history.isEmpty) {
      return 0;
    }
    final cutoff = now.toUtc().subtract(const Duration(hours: 2));
    return history
        .where((record) => !record.detectedAt.isBefore(cutoff))
        .map((record) => record.channelId)
        .toSet()
        .length;
  }

  String _buildAlertMessage({
    required SiteIntelligenceProfile profile,
    required String zoneName,
    required String zoneType,
    required bool isPerimeter,
    required OnyxProactiveDetectionKind detectionKind,
    required DateTime detectedAt,
    required bool isLoitering,
    required bool isSequence,
    required AlertDecision alertDecision,
    required int loiterMinutes,
  }) {
    final local = _siteLocalTime(profile.timezone, detectedAt.toUtc());
    final timeLabel =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final lines = <String>['⚠️ $zoneName — $timeLabel'];
    final subjectLabel = detectionKind == OnyxProactiveDetectionKind.vehicle
        ? 'vehicle'
        : 'movement';
    if (isPerimeter || zoneType == 'perimeter') {
      lines.add('Perimeter camera detected $subjectLabel.');
    } else {
      lines.add('Semi-perimeter camera detected $subjectLabel.');
    }
    if (isLoitering) {
      lines.add('Same area active for $loiterMinutes minutes.');
    }
    if (isSequence) {
      lines.add('Movement detected across multiple perimeter points.');
    }
    if (alertDecision.suggestedAction != null &&
        alertDecision.suggestedAction!.trim().isNotEmpty) {
      lines.add(alertDecision.suggestedAction!.trim());
    }
    if (alertDecision.contextNote != null &&
        alertDecision.contextNote!.trim().isNotEmpty) {
      lines.add(alertDecision.contextNote!.trim());
    }
    return lines.join('\n');
  }

  DateTime _siteLocalTime(String timezone, DateTime utc) {
    final normalized = timezone.trim();
    if (normalized == 'Africa/Johannesburg') {
      return utc.toUtc().add(const Duration(hours: 2));
    }
    if (normalized.toUpperCase() == 'UTC') {
      return utc.toUtc();
    }
    return utc.toLocal();
  }

  String _normalizeZoneType(String zoneType, bool isPerimeter) {
    final normalized = zoneType.trim().toLowerCase().replaceAll('-', '_');
    if (normalized == 'indoor') {
      return 'indoor';
    }
    if (isPerimeter || normalized == 'perimeter') {
      return 'perimeter';
    }
    if (normalized == 'semi_perimeter' || normalized == 'semi perimeter') {
      return 'semi_perimeter';
    }
    return 'semi_perimeter';
  }
}

class _SiteDetectionRecord {
  final int channelId;
  final String zoneType;
  final String zoneName;
  final bool isPerimeter;
  final bool isIndoor;
  final OnyxProactiveDetectionKind detectionKind;
  final DateTime detectedAt;

  const _SiteDetectionRecord({
    required this.channelId,
    required this.zoneType,
    required this.zoneName,
    required this.isPerimeter,
    required this.isIndoor,
    required this.detectionKind,
    required this.detectedAt,
  });
}

OnyxAlertSensitivity _parseSensitivity(
  Object? raw, {
  required OnyxAlertSensitivity fallback,
}) {
  final normalized = (raw?.toString() ?? '').trim().toLowerCase().replaceAll(
    '-',
    '_',
  );
  return switch (normalized) {
    'all_motion' => OnyxAlertSensitivity.allMotion,
    'suspicious_only' => OnyxAlertSensitivity.suspiciousOnly,
    'off' => OnyxAlertSensitivity.off,
    _ => fallback,
  };
}

int? _parseInt(Object? raw) {
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  if (raw is String) {
    return int.tryParse(raw.trim());
  }
  return null;
}

bool? _parseBool(Object? raw) {
  if (raw is bool) {
    return raw;
  }
  if (raw is num) {
    if (raw == 1) {
      return true;
    }
    if (raw == 0) {
      return false;
    }
  }
  if (raw is String) {
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return null;
}
