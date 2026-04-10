import 'dart:async';
import 'dart:math' as math;

enum OnyxAlertSensitivity { allMotion, suspiciousOnly, off }

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
    required DateTime detectedAt,
  }) async {
    final normalizedSiteId = siteId.trim();
    if (normalizedSiteId.isEmpty || channelId <= 0) {
      return;
    }
    final config =
        await readConfig(normalizedSiteId) ?? SiteAlertConfig.defaults(siteId);
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

    final withinAlertWindow = _isWithinAlertWindow(config, detectedAt);
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
    final occupancyWithinExpectedRange = _isOccupancyWithinExpectedRange(
      normalizedSiteId,
      detectedAt,
      config,
    );
    final shouldAlert = await _shouldAlert(
      config: config,
      zoneType: normalizedZoneType,
      isPerimeter: isPerimeter,
      isLoitering: loitering,
      isSequence: sequence,
      withinAlertWindow: withinAlertWindow,
      occupancyWithinExpectedRange: occupancyWithinExpectedRange,
    );
    if (!shouldAlert) {
      return;
    }

    final decision = OnyxProactiveAlertDecision(
      siteId: normalizedSiteId,
      channelId: channelId,
      zoneType: normalizedZoneType,
      zoneName: normalizedZoneName,
      isPerimeter: isPerimeter,
      isIndoor: isIndoor,
      detectedAt: detectedAt.toUtc(),
      withinAlertWindow: withinAlertWindow,
      isLoitering: loitering,
      isSequence: sequence,
      loiterMinutes: _loiteringDurationMinutes(
        normalizedSiteId,
        channelId,
        detectedAt,
        loiterWindowMinutes: loiterWindowMinutes,
      ),
      message: _buildAlertMessage(
        config: config,
        zoneName: normalizedZoneName,
        zoneType: normalizedZoneType,
        isPerimeter: isPerimeter,
        detectedAt: detectedAt.toUtc(),
        isLoitering: loitering,
        isSequence: sequence,
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

  bool _isWithinAlertWindow(SiteAlertConfig config, DateTime now) {
    final local = _siteLocalTime(config.timezone, now.toUtc());
    final start =
        _parseClock(config.alertWindowStart) ?? const _ClockTime(23, 0);
    final end = _parseClock(config.alertWindowEnd) ?? const _ClockTime(8, 0);
    final nowMinutes = (local.hour * 60) + local.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    if (startMinutes == endMinutes) {
      return true;
    }
    if (startMinutes < endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    }
    return nowMinutes >= startMinutes || nowMinutes < endMinutes;
  }

  Future<bool> _shouldAlert({
    required SiteAlertConfig config,
    required String zoneType,
    required bool isPerimeter,
    required bool isLoitering,
    required bool isSequence,
    required bool withinAlertWindow,
    required bool occupancyWithinExpectedRange,
  }) async {
    if (zoneType == 'indoor') {
      return false;
    }
    final isPrivateResidence = config.siteType == 'private_residence';
    if (!withinAlertWindow &&
        isPrivateResidence &&
        !isLoitering &&
        !isSequence) {
      return false;
    }
    if (!withinAlertWindow &&
        isPrivateResidence &&
        occupancyWithinExpectedRange) {
      return false;
    }
    final sensitivity = _effectiveSensitivity(
      config: config,
      zoneType: zoneType,
      isPerimeter: isPerimeter,
      withinAlertWindow: withinAlertWindow,
    );
    return switch (sensitivity) {
      OnyxAlertSensitivity.allMotion => true,
      OnyxAlertSensitivity.suspiciousOnly => isLoitering || isSequence,
      OnyxAlertSensitivity.off => false,
    };
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

  OnyxAlertSensitivity _effectiveSensitivity({
    required SiteAlertConfig config,
    required String zoneType,
    required bool isPerimeter,
    required bool withinAlertWindow,
  }) {
    if (zoneType == 'indoor') {
      return OnyxAlertSensitivity.off;
    }
    final isPrivateResidence = config.siteType == 'private_residence';
    if (withinAlertWindow && isPerimeter) {
      return config.quietHoursSensitivity;
    }
    if (!withinAlertWindow && isPrivateResidence) {
      if (isPerimeter || zoneType == 'perimeter') {
        return OnyxAlertSensitivity.suspiciousOnly;
      }
      if (zoneType == 'semi_perimeter') {
        return OnyxAlertSensitivity.suspiciousOnly;
      }
      return OnyxAlertSensitivity.off;
    }
    if (isPerimeter || zoneType == 'perimeter') {
      return _combineSensitivity(
        config.perimeterSensitivity,
        config.daySensitivity,
      );
    }
    if (zoneType == 'semi_perimeter') {
      return _combineSensitivity(
        config.semiPerimeterSensitivity,
        withinAlertWindow
            ? config.semiPerimeterSensitivity
            : config.daySensitivity,
      );
    }
    return config.indoorSensitivity;
  }

  OnyxAlertSensitivity _combineSensitivity(
    OnyxAlertSensitivity primary,
    OnyxAlertSensitivity secondary,
  ) {
    if (primary == OnyxAlertSensitivity.allMotion ||
        secondary == OnyxAlertSensitivity.allMotion) {
      return OnyxAlertSensitivity.allMotion;
    }
    if (primary == OnyxAlertSensitivity.suspiciousOnly ||
        secondary == OnyxAlertSensitivity.suspiciousOnly) {
      return OnyxAlertSensitivity.suspiciousOnly;
    }
    return OnyxAlertSensitivity.off;
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

  bool _isOccupancyWithinExpectedRange(
    String siteId,
    DateTime now,
    SiteAlertConfig config,
  ) {
    final expectedOccupancy = config.expectedOccupancy;
    if (expectedOccupancy <= 0) {
      return false;
    }
    final history = _detectionsBySite[siteId];
    if (history == null || history.isEmpty) {
      return true;
    }
    final cutoff = now.toUtc().subtract(const Duration(hours: 2));
    final distinctChannels = history
        .where((record) => !record.detectedAt.isBefore(cutoff))
        .map((record) => record.channelId)
        .toSet()
        .length;
    return distinctChannels <= expectedOccupancy;
  }

  String _buildAlertMessage({
    required SiteAlertConfig config,
    required String zoneName,
    required String zoneType,
    required bool isPerimeter,
    required DateTime detectedAt,
    required bool isLoitering,
    required bool isSequence,
    required int loiterMinutes,
  }) {
    final local = _siteLocalTime(config.timezone, detectedAt.toUtc());
    final timeLabel =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final lines = <String>['⚠️ $zoneName — $timeLabel'];
    if (isPerimeter || zoneType == 'perimeter') {
      lines.add('Perimeter camera detected movement.');
    } else {
      lines.add('Semi-perimeter camera detected movement.');
    }
    if (isLoitering) {
      lines.add('Same area active for $loiterMinutes minutes.');
    }
    if (isSequence) {
      lines.add('Movement detected across multiple perimeter points.');
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

  _ClockTime? _parseClock(String value) {
    final normalized = value.trim();
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(normalized);
    if (match == null) {
      return null;
    }
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return _ClockTime(hour, minute);
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
  final DateTime detectedAt;

  const _SiteDetectionRecord({
    required this.channelId,
    required this.zoneType,
    required this.zoneName,
    required this.isPerimeter,
    required this.isIndoor,
    required this.detectedAt,
  });
}

class _ClockTime {
  final int hour;
  final int minute;

  const _ClockTime(this.hour, this.minute);
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
