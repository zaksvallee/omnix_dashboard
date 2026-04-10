import 'dart:developer' as developer;

import 'package:supabase/supabase.dart';

import '../onyx_proactive_alert_service.dart';
import 'onyx_site_awareness_snapshot.dart';

class OnyxSiteOccupancyConfig {
  final String siteId;
  final int expectedOccupancy;
  final String occupancyLabel;
  final String siteType;
  final int resetHour;
  final bool hasGuard;
  final bool hasGateSensors;

  const OnyxSiteOccupancyConfig({
    required this.siteId,
    required this.expectedOccupancy,
    required this.occupancyLabel,
    required this.siteType,
    required this.resetHour,
    required this.hasGuard,
    required this.hasGateSensors,
  });

  factory OnyxSiteOccupancyConfig.fromRow(Map<String, dynamic> row) {
    return OnyxSiteOccupancyConfig(
      siteId: (row['site_id'] as String? ?? '').trim(),
      expectedOccupancy: _siteOccupancyInt(row['expected_occupancy']) ?? 0,
      occupancyLabel: (row['occupancy_label'] as String? ?? 'people').trim(),
      siteType: (row['site_type'] as String? ?? 'private_residence').trim(),
      resetHour: _siteOccupancyInt(row['reset_hour']) ?? 3,
      hasGuard: _siteOccupancyBool(row['has_guard']) ?? false,
      hasGateSensors: _siteOccupancyBool(row['has_gate_sensors']) ?? false,
    );
  }
}

class OnyxSiteOccupancySession {
  final String siteId;
  final String sessionDate;
  final int peakDetected;
  final DateTime? lastDetectionAt;
  final List<String> channelsWithDetections;

  const OnyxSiteOccupancySession({
    required this.siteId,
    required this.sessionDate,
    required this.peakDetected,
    required this.lastDetectionAt,
    required this.channelsWithDetections,
  });

  factory OnyxSiteOccupancySession.fromRow(Map<String, dynamic> row) {
    final rawChannels = row['channels_with_detections'];
    return OnyxSiteOccupancySession(
      siteId: (row['site_id'] as String? ?? '').trim(),
      sessionDate: (row['session_date'] as String? ?? '').trim(),
      peakDetected: _siteOccupancyInt(row['peak_detected']) ?? 0,
      lastDetectionAt: _siteOccupancyDate(row['last_detection_at']),
      channelsWithDetections: rawChannels is List
          ? rawChannels
                .map((value) => value.toString().trim())
                .where((value) => value.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
    );
  }
}

class OnyxSiteCameraZone {
  final String siteId;
  final String channelId;
  final String zoneName;
  final String zoneType;
  final bool isPerimeter;
  final bool isIndoor;
  final String? notes;

  const OnyxSiteCameraZone({
    required this.siteId,
    required this.channelId,
    required this.zoneName,
    required this.zoneType,
    required this.isPerimeter,
    required this.isIndoor,
    this.notes,
  });

  OnyxCameraZone toAwarenessZone() {
    return OnyxCameraZone(
      siteId: siteId,
      channelId: channelId,
      zoneName: zoneName,
      zoneType: zoneType,
      isPerimeter: isPerimeter,
      isIndoor: isIndoor,
      notes: notes,
    );
  }

  factory OnyxSiteCameraZone.fromRow(Map<String, dynamic> row) {
    final channelId = _siteCameraZoneChannelId(row['channel_id']);
    return OnyxSiteCameraZone(
      siteId: (row['site_id'] as String? ?? '').trim(),
      channelId: channelId,
      zoneName: (row['zone_name'] as String? ?? '').trim().isEmpty
          ? 'Channel $channelId'
          : (row['zone_name'] as String? ?? '').trim(),
      zoneType: (row['zone_type'] as String? ?? 'unmapped').trim(),
      isPerimeter: _siteOccupancyBool(row['is_perimeter']) ?? false,
      isIndoor: _siteOccupancyBool(row['is_indoor']) ?? false,
      notes: (row['notes'] as String?)?.trim().isEmpty == true
          ? null
          : (row['notes'] as String?)?.trim(),
    );
  }
}

class OnyxSiteAwarenessRepository {
  final SupabaseClient _client;
  final Map<String, OnyxSiteOccupancyConfig?> _occupancyConfigCache =
      <String, OnyxSiteOccupancyConfig?>{};
  final Map<String, SiteAlertConfig?> _alertConfigCache =
      <String, SiteAlertConfig?>{};
  final Map<String, Map<String, OnyxCameraZone>> _cameraZonesCache =
      <String, Map<String, OnyxCameraZone>>{};

  OnyxSiteAwarenessRepository(SupabaseClient client) : _client = client;

  Future<void> upsertSnapshot(OnyxSiteAwarenessSnapshot snapshot) async {
    try {
      await _client.from('site_awareness_snapshots').upsert(<String, Object?>{
        'site_id': snapshot.siteId,
        'client_id': snapshot.clientId,
        'snapshot_at': snapshot.snapshotAt.toUtc().toIso8601String(),
        'channels': snapshot.channels.map(
          (key, value) => MapEntry(key, value.toJsonMap()),
        ),
        'detections': snapshot.detections.toJsonMap(),
        'perimeter_clear': snapshot.perimeterClear,
        'known_faults': snapshot.knownFaults,
        'active_alerts': snapshot.activeAlerts
            .map((alert) => alert.toJsonMap())
            .toList(growable: false),
      }, onConflict: 'site_id');
    } catch (error, stackTrace) {
      developer.log(
        'Failed to upsert site awareness snapshot for ${snapshot.siteId}.',
        name: 'OnyxSiteAwarenessRepository',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      rethrow;
    }
  }

  Future<OnyxSiteOccupancyConfig?> readOccupancyConfig(String siteId) async {
    final normalizedSiteId = siteId.trim();
    if (normalizedSiteId.isEmpty) {
      return null;
    }
    if (_occupancyConfigCache.containsKey(normalizedSiteId)) {
      return _occupancyConfigCache[normalizedSiteId];
    }
    try {
      final rows = await _client
          .from('site_occupancy_config')
          .select(
            'site_id,expected_occupancy,occupancy_label,site_type,reset_hour,has_guard,has_gate_sensors',
          )
          .eq('site_id', normalizedSiteId)
          .limit(1);
      final config = rows.isEmpty
          ? null
          : OnyxSiteOccupancyConfig.fromRow(
              Map<String, dynamic>.from(rows.first as Map),
            );
      _occupancyConfigCache[normalizedSiteId] = config;
      return config;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to read occupancy config for $normalizedSiteId.',
        name: 'OnyxSiteAwarenessRepository',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      return null;
    }
  }

  Future<Map<String, OnyxCameraZone>> readCameraZones(String siteId) async {
    final normalizedSiteId = siteId.trim();
    if (normalizedSiteId.isEmpty) {
      return const <String, OnyxCameraZone>{};
    }
    if (_cameraZonesCache.containsKey(normalizedSiteId)) {
      return _cameraZonesCache[normalizedSiteId]!;
    }
    try {
      final rows = await _client
          .from('site_camera_zones')
          .select(
            'site_id,channel_id,zone_name,zone_type,is_perimeter,is_indoor,notes',
          )
          .eq('site_id', normalizedSiteId)
          .order('channel_id', ascending: true);
      final zones = <String, OnyxCameraZone>{};
      for (final row in rows) {
        final zone = OnyxSiteCameraZone.fromRow(
          Map<String, dynamic>.from(row as Map),
        ).toAwarenessZone();
        if (zone.channelId.trim().isEmpty) {
          continue;
        }
        zones[zone.channelId] = zone;
      }
      final frozen = Map<String, OnyxCameraZone>.unmodifiable(zones);
      _cameraZonesCache[normalizedSiteId] = frozen;
      return frozen;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to read camera zones for $normalizedSiteId.',
        name: 'OnyxSiteAwarenessRepository',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      return const <String, OnyxCameraZone>{};
    }
  }

  Future<SiteAlertConfig?> readAlertConfig(String siteId) async {
    final normalizedSiteId = siteId.trim();
    if (normalizedSiteId.isEmpty) {
      return null;
    }
    if (_alertConfigCache.containsKey(normalizedSiteId)) {
      return _alertConfigCache[normalizedSiteId];
    }
    try {
      final rows = await _client
          .from('site_alert_config')
          .select(
            'site_id,alert_window_start,alert_window_end,timezone,perimeter_sensitivity,semi_perimeter_sensitivity,indoor_sensitivity,loiter_detection_minutes,perimeter_sequence_alert,quiet_hours_sensitivity,day_sensitivity',
          )
          .eq('site_id', normalizedSiteId)
          .limit(1);
      final config = rows.isEmpty
          ? null
          : SiteAlertConfig.fromRow(
              Map<String, dynamic>.from(rows.first as Map),
            );
      _alertConfigCache[normalizedSiteId] = config;
      return config;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to read alert config for $normalizedSiteId.',
        name: 'OnyxSiteAwarenessRepository',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      return null;
    }
  }

  Future<void> recordHumanDetection({
    required String siteId,
    required String channelId,
    required DateTime detectedAt,
  }) async {
    final normalizedSiteId = siteId.trim();
    final normalizedChannelId = channelId.trim();
    if (normalizedSiteId.isEmpty || normalizedChannelId.isEmpty) {
      return;
    }
    try {
      final config = await readOccupancyConfig(normalizedSiteId);
      final sessionDate = _siteOccupancySessionDateValue(
        detectedAt.toLocal(),
        resetHour: config?.resetHour ?? 3,
      );
      final existing = await _readOccupancySession(
        siteId: normalizedSiteId,
        sessionDate: sessionDate,
      );
      final updatedChannels = <String>{
        ...?existing?.channelsWithDetections,
        normalizedChannelId,
      }.toList(growable: false)..sort();
      final peakDetected =
          updatedChannels.length > (existing?.peakDetected ?? 0)
          ? updatedChannels.length
          : (existing?.peakDetected ?? 0);
      await _client.from('site_occupancy_sessions').upsert(<String, Object?>{
        'site_id': normalizedSiteId,
        'session_date': sessionDate,
        'peak_detected': peakDetected,
        'last_detection_at': detectedAt.toUtc().toIso8601String(),
        'channels_with_detections': updatedChannels,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'site_id,session_date');
    } catch (error, stackTrace) {
      developer.log(
        'Failed to record occupancy signal for $normalizedSiteId channel $normalizedChannelId.',
        name: 'OnyxSiteAwarenessRepository',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      rethrow;
    }
  }

  Future<OnyxSiteOccupancySession?> _readOccupancySession({
    required String siteId,
    required String sessionDate,
  }) async {
    final rows = await _client
        .from('site_occupancy_sessions')
        .select(
          'site_id,session_date,peak_detected,last_detection_at,channels_with_detections',
        )
        .eq('site_id', siteId)
        .eq('session_date', sessionDate)
        .limit(1);
    if (rows.isEmpty) {
      return null;
    }
    return OnyxSiteOccupancySession.fromRow(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }
}

String _siteOccupancySessionDateValue(
  DateTime detectedAtLocal, {
  int resetHour = 3,
}) {
  final normalizedResetHour = resetHour.clamp(0, 23);
  final dayStart = DateTime(
    detectedAtLocal.year,
    detectedAtLocal.month,
    detectedAtLocal.day,
    normalizedResetHour,
  );
  final sessionLocalDate = detectedAtLocal.isBefore(dayStart)
      ? dayStart.subtract(const Duration(days: 1))
      : dayStart;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${sessionLocalDate.year.toString().padLeft(4, '0')}-${two(sessionLocalDate.month)}-${two(sessionLocalDate.day)}';
}

int? _siteOccupancyInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

DateTime? _siteOccupancyDate(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}

bool? _siteOccupancyBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    if (value == 1) {
      return true;
    }
    if (value == 0) {
      return false;
    }
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return null;
}

String _siteCameraZoneChannelId(Object? value) {
  if (value is int) {
    return value.toString();
  }
  if (value is num) {
    return value.toInt().toString();
  }
  return (value?.toString() ?? '').trim();
}
