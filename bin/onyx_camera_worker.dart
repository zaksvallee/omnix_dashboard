// ONYX Camera Worker — standalone Dart CLI process for site awareness streaming.
//
// Run with:
//   ONYX_HIK_PASSWORD=yourpassword dart run bin/onyx_camera_worker.dart
//
// All other config is read from environment variables or dart-define defaults.
// Never hardcode the password — pass it via the environment only.
//
// Full env vars:
//   ONYX_HIK_HOST                 Camera host (default: 192.168.0.117)
//   ONYX_HIK_PORT                 Camera port (default: 80)
//   ONYX_HIK_USERNAME             Camera username (default: admin)
//   ONYX_HIK_PASSWORD             Camera password — REQUIRED, no default
//   ONYX_HIK_KNOWN_FAULT_CHANNELS Comma-separated fault channel IDs (default: 11)
//   ONYX_SUPABASE_URL             Supabase project URL
//   ONYX_SUPABASE_SERVICE_KEY     Supabase service role key (bypasses RLS — preferred)
//   SUPABASE_ANON_KEY             Supabase anon key (fallback if service key absent)
//   ONYX_CLIENT_ID                Client ID (default: CLIENT-MS-VALLEE)
//   ONYX_SITE_ID                  Site ID (default: SITE-MS-VALLEE-RESIDENCE)

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:omnix_dashboard/application/onyx_lpr_service.dart';
import 'package:omnix_dashboard/application/onyx_proactive_alert_service.dart';
import 'package:omnix_dashboard/application/onyx_site_profile_service.dart';
import 'package:omnix_dashboard/application/site_awareness/onyx_live_snapshot_yolo_service.dart';
import 'package:supabase/supabase.dart';
import 'package:xml/xml.dart' as xml;

// ─── Inlined from lib/application/site_awareness/onyx_site_awareness_snapshot.dart ───

enum OnyxChannelStatusType { active, idle, videoloss, unknown }

enum OnyxEventType {
  humanDetected,
  vehicleDetected,
  animalDetected,
  motionDetected,
  perimeterBreach,
  videoloss,
  unknown,
}

class OnyxCameraZone {
  final String siteId;
  final String channelId;
  final String zoneName;
  final String zoneType;
  final bool isPerimeter;
  final bool isIndoor;
  final String? notes;

  const OnyxCameraZone({
    required this.siteId,
    required this.channelId,
    required this.zoneName,
    required this.zoneType,
    this.isPerimeter = false,
    this.isIndoor = false,
    this.notes,
  });
}

class OnyxSiteAwarenessSnapshot {
  final String siteId;
  final String clientId;
  final DateTime snapshotAt;
  final Map<String, OnyxChannelStatus> channels;
  final OnyxDetectionSummary detections;
  final bool perimeterClear;
  final List<String> knownFaults;
  final List<OnyxSiteAlert> activeAlerts;

  OnyxSiteAwarenessSnapshot({
    required this.siteId,
    required this.clientId,
    required this.snapshotAt,
    required Map<String, OnyxChannelStatus> channels,
    required this.detections,
    required this.perimeterClear,
    List<String> knownFaults = const <String>[],
    List<OnyxSiteAlert> activeAlerts = const <OnyxSiteAlert>[],
  }) : channels = Map.unmodifiable(
         Map<String, OnyxChannelStatus>.from(channels),
       ),
       knownFaults = List.unmodifiable(List<String>.from(knownFaults)),
       activeAlerts = List.unmodifiable(List<OnyxSiteAlert>.from(activeAlerts));

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'site_id': siteId,
      'client_id': clientId,
      'snapshot_at': snapshotAt.toUtc().toIso8601String(),
      'channels': channels.map(
        (key, value) => MapEntry(key, value.toJsonMap()),
      ),
      'detections': detections.toJsonMap(),
      'perimeter_clear': perimeterClear,
      'known_faults': knownFaults,
      'active_alerts': activeAlerts
          .map((alert) => alert.toJsonMap())
          .toList(growable: false),
    };
  }
}

class OnyxChannelStatus {
  final String channelId;
  final OnyxChannelStatusType status;
  final OnyxEventType? lastEventType;
  final DateTime? lastEventAt;
  final bool isFault;
  final String? faultReason;

  const OnyxChannelStatus({
    required this.channelId,
    required this.status,
    this.lastEventType,
    this.lastEventAt,
    this.isFault = false,
    this.faultReason,
  });

  OnyxChannelStatus copyWith({
    String? channelId,
    OnyxChannelStatusType? status,
    OnyxEventType? lastEventType,
    DateTime? lastEventAt,
    bool? isFault,
    String? faultReason,
  }) {
    return OnyxChannelStatus(
      channelId: channelId ?? this.channelId,
      status: status ?? this.status,
      lastEventType: lastEventType ?? this.lastEventType,
      lastEventAt: lastEventAt ?? this.lastEventAt,
      isFault: isFault ?? this.isFault,
      faultReason: faultReason ?? this.faultReason,
    );
  }

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'channel_id': channelId,
      'status': status.name,
      'last_event_type': lastEventType?.name,
      'last_event_at': lastEventAt?.toUtc().toIso8601String(),
      'is_fault': isFault,
      'fault_reason': faultReason,
    };
  }
}

class OnyxDetectionSummary {
  final int humanCount;
  final int vehicleCount;
  final int animalCount;
  final int motionCount;
  final DateTime lastUpdated;
  final List<OnyxDetectionZone> humanZones;

  const OnyxDetectionSummary({
    required this.humanCount,
    required this.vehicleCount,
    required this.animalCount,
    required this.motionCount,
    required this.lastUpdated,
    this.humanZones = const <OnyxDetectionZone>[],
  });

  factory OnyxDetectionSummary.empty(DateTime at) {
    return OnyxDetectionSummary(
      humanCount: 0,
      vehicleCount: 0,
      animalCount: 0,
      motionCount: 0,
      lastUpdated: at.toUtc(),
    );
  }

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'human_count': humanCount,
      'vehicle_count': vehicleCount,
      'animal_count': animalCount,
      'motion_count': motionCount,
      'last_updated': lastUpdated.toUtc().toIso8601String(),
      'human_zones': humanZones
          .map((zone) => zone.toJsonMap())
          .toList(growable: false),
    };
  }
}

class OnyxDetectionZone {
  final String channelId;
  final String zoneName;
  final String zoneType;
  final bool isPerimeter;
  final bool isIndoor;
  final DateTime lastDetectedAt;
  final String? knownPersonId;
  final String? knownPersonName;
  final bool unknownPerson;
  final double? faceMatchConfidence;
  final double? faceMatchDistance;

  const OnyxDetectionZone({
    required this.channelId,
    required this.zoneName,
    required this.zoneType,
    required this.isPerimeter,
    required this.isIndoor,
    required this.lastDetectedAt,
    this.knownPersonId,
    this.knownPersonName,
    this.unknownPerson = false,
    this.faceMatchConfidence,
    this.faceMatchDistance,
  });

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'channel_id': channelId,
      'zone_name': zoneName,
      'zone_type': zoneType,
      'is_perimeter': isPerimeter,
      'is_indoor': isIndoor,
      'last_detected_at': lastDetectedAt.toUtc().toIso8601String(),
      'known_person_id': knownPersonId,
      'known_person_name': knownPersonName,
      'unknown_person': unknownPerson,
      'face_match_confidence': faceMatchConfidence,
      'face_match_distance': faceMatchDistance,
    };
  }
}

class OnyxSiteAlert {
  final String alertId;
  final String channelId;
  final OnyxEventType eventType;
  final DateTime detectedAt;
  final bool isAcknowledged;
  final String? zoneName;
  final String? zoneType;
  final String? message;
  final bool isLoitering;
  final bool isSequence;
  final String? alertSource;

  const OnyxSiteAlert({
    required this.alertId,
    required this.channelId,
    required this.eventType,
    required this.detectedAt,
    this.isAcknowledged = false,
    this.zoneName,
    this.zoneType,
    this.message,
    this.isLoitering = false,
    this.isSequence = false,
    this.alertSource,
  });

  String get deduplicationKey {
    return <String>[
      channelId,
      eventType.name,
      (zoneName ?? '').trim(),
      (zoneType ?? '').trim(),
      isLoitering ? 'loiter' : 'single',
      isSequence ? 'sequence' : 'local',
      (alertSource ?? '').trim(),
    ].join('|');
  }

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'alert_id': alertId,
      'channel_id': channelId,
      'event_type': eventType.name,
      'detected_at': detectedAt.toUtc().toIso8601String(),
      'is_acknowledged': isAcknowledged,
      'zone_name': zoneName,
      'zone_type': zoneType,
      'message': message,
      'is_loitering': isLoitering,
      'is_sequence': isSequence,
      'alert_source': alertSource,
    };
  }
}

class OnyxSiteAwarenessEvent {
  final String channelId;
  final OnyxEventType eventType;
  final DateTime detectedAt;
  final String rawEventType;
  final String? targetType;
  final String? plateNumber;
  final String? faceMatchId;
  final String? faceMatchName;
  final double? faceMatchConfidence;
  final double? faceMatchDistance;
  final bool unknownPerson;
  final bool isKnownFaultChannel;

  const OnyxSiteAwarenessEvent({
    required this.channelId,
    required this.eventType,
    required this.detectedAt,
    required this.rawEventType,
    this.targetType,
    this.plateNumber,
    this.faceMatchId,
    this.faceMatchName,
    this.faceMatchConfidence,
    this.faceMatchDistance,
    this.unknownPerson = false,
    this.isKnownFaultChannel = false,
  });

  OnyxSiteAwarenessEvent copyWith({
    String? channelId,
    OnyxEventType? eventType,
    DateTime? detectedAt,
    String? rawEventType,
    String? targetType,
    String? plateNumber,
    String? faceMatchId,
    String? faceMatchName,
    double? faceMatchConfidence,
    double? faceMatchDistance,
    bool? unknownPerson,
    bool? isKnownFaultChannel,
  }) {
    return OnyxSiteAwarenessEvent(
      channelId: channelId ?? this.channelId,
      eventType: eventType ?? this.eventType,
      detectedAt: detectedAt ?? this.detectedAt,
      rawEventType: rawEventType ?? this.rawEventType,
      targetType: targetType ?? this.targetType,
      plateNumber: plateNumber ?? this.plateNumber,
      faceMatchId: faceMatchId ?? this.faceMatchId,
      faceMatchName: faceMatchName ?? this.faceMatchName,
      faceMatchConfidence: faceMatchConfidence ?? this.faceMatchConfidence,
      faceMatchDistance: faceMatchDistance ?? this.faceMatchDistance,
      unknownPerson: unknownPerson ?? this.unknownPerson,
      isKnownFaultChannel: isKnownFaultChannel ?? this.isKnownFaultChannel,
    );
  }

  factory OnyxSiteAwarenessEvent.fromAlertXml(
    String payload, {
    Set<String> knownFaultChannels = const <String>{},
    DateTime Function()? clock,
  }) {
    final document = xml.XmlDocument.parse(payload);
    final channelId = _resolvedAlertChannelId(
      _readTag(document, 'channelID'),
      _readTag(document, 'channelId'),
      _readTag(document, 'dynChannelID'),
    );
    final rawEventType = _firstNonEmpty(
      _readTag(document, 'eventType'),
      _readTag(document, 'eventDescription'),
    );
    final targetType = _readTag(document, 'targetType');
    final plateNumber = _firstNonEmpty(
      _readTag(document, 'licensePlate'),
      _readTag(document, 'plateNumber'),
      _readTag(document, 'licensePlateNumber'),
    );
    final detectedAt =
        DateTime.tryParse(_readTag(document, 'dateTime'))?.toUtc() ??
        (clock ?? DateTime.now).call().toUtc();
    return OnyxSiteAwarenessEvent(
      channelId: channelId.isEmpty ? 'unknown' : channelId,
      eventType: mapOnyxEventType(
        rawEventType: rawEventType,
        targetType: targetType,
      ),
      detectedAt: detectedAt,
      rawEventType: rawEventType,
      targetType: targetType.isEmpty ? null : targetType,
      plateNumber: plateNumber.isEmpty ? null : plateNumber,
      isKnownFaultChannel: knownFaultChannels.contains(channelId),
    );
  }

  bool get shouldRaiseAlert {
    if (isKnownFaultChannel) {
      return false;
    }
    return eventType == OnyxEventType.perimeterBreach;
  }

  bool get shouldPublishImmediately {
    if (eventType == OnyxEventType.perimeterBreach) {
      return true;
    }
    return !isKnownFaultChannel && eventType == OnyxEventType.humanDetected;
  }
}

class OnyxSiteAwarenessProjector {
  final String siteId;
  final String clientId;
  final Set<String> knownFaultChannels;
  final Map<String, OnyxCameraZone> cameraZones;
  final Duration detectionWindow;
  final DateTime Function() clock;
  final math.Random _random;

  final Map<String, OnyxChannelStatus> _channels =
      <String, OnyxChannelStatus>{};
  final List<OnyxSiteAwarenessEvent> _recentEvents = <OnyxSiteAwarenessEvent>[];
  final List<OnyxSiteAlert> _activeAlerts = <OnyxSiteAlert>[];

  OnyxSiteAwarenessProjector({
    required this.siteId,
    required this.clientId,
    Set<String> knownFaultChannels = const <String>{},
    Map<String, OnyxCameraZone> cameraZones = const <String, OnyxCameraZone>{},
    this.detectionWindow = const Duration(minutes: 5),
    DateTime Function()? clock,
    math.Random? random,
  }) : knownFaultChannels = Set<String>.from(knownFaultChannels),
       cameraZones = Map<String, OnyxCameraZone>.unmodifiable(
         Map<String, OnyxCameraZone>.from(cameraZones),
       ),
       clock = clock ?? DateTime.now,
       _random = random ?? math.Random.secure();

  OnyxSiteAwarenessSnapshot ingest(OnyxSiteAwarenessEvent event) {
    _prune(event.detectedAt);
    _recentEvents.add(event);
    _channels[event.channelId] = OnyxChannelStatus(
      channelId: event.channelId,
      status: event.eventType == OnyxEventType.videoloss
          ? OnyxChannelStatusType.videoloss
          : OnyxChannelStatusType.active,
      lastEventType: event.eventType,
      lastEventAt: event.detectedAt.toUtc(),
      isFault: event.eventType == OnyxEventType.videoloss,
      faultReason: event.eventType == OnyxEventType.videoloss
          ? event.isKnownFaultChannel
                ? 'Known wiring fault channel is reporting video loss.'
                : 'Video loss detected on the channel.'
          : null,
    );
    if (event.shouldRaiseAlert) {
      _upsertAlert(
        OnyxSiteAlert(
          alertId: _uuidV4(_random),
          channelId: event.channelId,
          eventType: event.eventType,
          detectedAt: event.detectedAt.toUtc(),
          isAcknowledged: false,
        ),
      );
    }
    return snapshot(at: event.detectedAt);
  }

  OnyxSiteAwarenessSnapshot ingestSiteAlert(OnyxSiteAlert alert) {
    _prune(alert.detectedAt);
    _upsertAlert(alert);
    return snapshot(at: alert.detectedAt);
  }

  OnyxSiteAwarenessSnapshot snapshot({DateTime? at}) {
    final now = (at ?? clock()).toUtc();
    _prune(now);

    // Count distinct channels that reported each detection type within the
    // window — prevents one camera firing 20 VMD events from inflating counts.
    final humanChannels = <String>{};
    final vehicleChannels = <String>{};
    final animalChannels = <String>{};
    final motionChannels = <String>{};
    for (final event in _recentEvents) {
      switch (event.eventType) {
        case OnyxEventType.humanDetected:
          humanChannels.add(event.channelId);
        case OnyxEventType.vehicleDetected:
          vehicleChannels.add(event.channelId);
        case OnyxEventType.animalDetected:
          animalChannels.add(event.channelId);
        case OnyxEventType.motionDetected:
          motionChannels.add(event.channelId);
        case OnyxEventType.perimeterBreach:
        case OnyxEventType.videoloss:
        case OnyxEventType.unknown:
          break;
      }
    }
    final humanCount = humanChannels.length;
    final vehicleCount = vehicleChannels.length;
    final animalCount = animalChannels.length;
    final motionCount = motionChannels.length;
    final humanZones = _latestDetectionZonesForType(
      OnyxEventType.humanDetected,
    );

    final hasRecentPerimeterBreach = _recentEvents.any(
      (event) =>
          !event.isKnownFaultChannel &&
          event.eventType == OnyxEventType.perimeterBreach,
    );

    final sortedChannelIds = _channels.keys.toList(growable: false)..sort();
    final channelMap = <String, OnyxChannelStatus>{};
    for (final channelId in sortedChannelIds) {
      final status = _channels[channelId]!;
      channelMap[channelId] = _resolvedChannelStatus(status, now);
    }

    final knownFaults =
        channelMap.values
            .where(
              (status) =>
                  knownFaultChannels.contains(status.channelId) &&
                  status.status == OnyxChannelStatusType.videoloss,
            )
            .map((status) => status.channelId)
            .toList(growable: false)
          ..sort();

    final activeAlerts = List<OnyxSiteAlert>.from(_activeAlerts)
      ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));

    final detectionLastUpdated = _recentEvents.isEmpty
        ? now
        : _recentEvents
              .map((event) => event.detectedAt)
              .reduce(
                (latest, candidate) =>
                    candidate.isAfter(latest) ? candidate : latest,
              );

    return OnyxSiteAwarenessSnapshot(
      siteId: siteId,
      clientId: clientId,
      snapshotAt: now,
      channels: channelMap,
      detections: OnyxDetectionSummary(
        humanCount: humanCount,
        vehicleCount: vehicleCount,
        animalCount: animalCount,
        motionCount: motionCount,
        lastUpdated: detectionLastUpdated,
        humanZones: humanZones,
      ),
      perimeterClear: !hasRecentPerimeterBreach,
      knownFaults: knownFaults,
      activeAlerts: activeAlerts,
    );
  }

  /// Marks all active alerts as acknowledged and returns the updated snapshot.
  /// Call this when an operator sends a "clear" command via Telegram.
  OnyxSiteAwarenessSnapshot acknowledgeAllAlerts() {
    for (var i = 0; i < _activeAlerts.length; i++) {
      _activeAlerts[i] = OnyxSiteAlert(
        alertId: _activeAlerts[i].alertId,
        channelId: _activeAlerts[i].channelId,
        eventType: _activeAlerts[i].eventType,
        detectedAt: _activeAlerts[i].detectedAt,
        isAcknowledged: true,
        zoneName: _activeAlerts[i].zoneName,
        zoneType: _activeAlerts[i].zoneType,
        message: _activeAlerts[i].message,
        isLoitering: _activeAlerts[i].isLoitering,
        isSequence: _activeAlerts[i].isSequence,
        alertSource: _activeAlerts[i].alertSource,
      );
    }
    return snapshot();
  }

  void _prune(DateTime nowUtc) {
    final cutoff = nowUtc.subtract(detectionWindow);
    _recentEvents.removeWhere((event) => event.detectedAt.isBefore(cutoff));
    _activeAlerts.removeWhere((alert) => alert.detectedAt.isBefore(cutoff));
  }

  void _upsertAlert(OnyxSiteAlert alert) {
    final deduplicationKey = alert.deduplicationKey;
    final dupIndex = _activeAlerts.indexWhere(
      (existing) =>
          !existing.isAcknowledged &&
          existing.deduplicationKey == deduplicationKey,
    );
    if (dupIndex >= 0) {
      _activeAlerts[dupIndex] = OnyxSiteAlert(
        alertId: _activeAlerts[dupIndex].alertId,
        channelId: alert.channelId,
        eventType: alert.eventType,
        detectedAt: alert.detectedAt.toUtc(),
        isAcknowledged: false,
        zoneName: alert.zoneName,
        zoneType: alert.zoneType,
        message: alert.message,
        isLoitering: alert.isLoitering,
        isSequence: alert.isSequence,
        alertSource: alert.alertSource,
      );
      return;
    }
    _activeAlerts.add(alert);
  }

  OnyxChannelStatus _resolvedChannelStatus(
    OnyxChannelStatus status,
    DateTime nowUtc,
  ) {
    if (status.status == OnyxChannelStatusType.videoloss) {
      return status;
    }
    final lastEventAt = status.lastEventAt;
    if (lastEventAt == null) {
      return status.copyWith(status: OnyxChannelStatusType.unknown);
    }
    if (nowUtc.difference(lastEventAt) >= detectionWindow) {
      return status.copyWith(status: OnyxChannelStatusType.idle);
    }
    return status.copyWith(status: OnyxChannelStatusType.active);
  }

  List<OnyxDetectionZone> _latestDetectionZonesForType(OnyxEventType type) {
    final latestByChannel = <String, OnyxSiteAwarenessEvent>{};
    for (final event in _recentEvents) {
      if (event.eventType != type) {
        continue;
      }
      final current = latestByChannel[event.channelId];
      if (current == null || event.detectedAt.isAfter(current.detectedAt)) {
        latestByChannel[event.channelId] = event;
      }
    }
    final latestEvents = latestByChannel.values.toList(growable: false)
      ..sort((left, right) {
        final stampCompare = right.detectedAt.compareTo(left.detectedAt);
        if (stampCompare != 0) {
          return stampCompare;
        }
        return left.channelId.compareTo(right.channelId);
      });
    return latestEvents
        .map((event) {
          final zone = cameraZones[event.channelId];
          return OnyxDetectionZone(
            channelId: event.channelId,
            zoneName: zone?.zoneName ?? 'Channel ${event.channelId}',
            zoneType: zone?.zoneType ?? 'unmapped',
            isPerimeter: zone?.isPerimeter ?? false,
            isIndoor: zone?.isIndoor ?? false,
            lastDetectedAt: event.detectedAt,
            knownPersonId: event.faceMatchId,
            knownPersonName: event.faceMatchName,
            unknownPerson: event.unknownPerson,
            faceMatchConfidence: event.faceMatchConfidence,
            faceMatchDistance: event.faceMatchDistance,
          );
        })
        .toList(growable: false);
  }
}

String _resolvedAlertChannelId(
  String primaryChannelId,
  String secondaryChannelId,
  String dynamicChannelId,
) {
  final candidates = <String>[
    primaryChannelId.trim(),
    secondaryChannelId.trim(),
    dynamicChannelId.trim(),
  ];
  for (final candidate in candidates) {
    final parsed = int.tryParse(candidate);
    if (parsed != null && parsed > 0) {
      return candidate;
    }
  }
  return _firstNonEmpty(primaryChannelId, secondaryChannelId, dynamicChannelId);
}

OnyxEventType mapOnyxEventType({
  required String rawEventType,
  String? targetType,
}) {
  final normalizedEvent = _normalizeToken(rawEventType);
  final normalizedTarget = _normalizeToken(targetType ?? '');

  if (normalizedEvent == 'videoloss') {
    return OnyxEventType.videoloss;
  }
  if (normalizedEvent == 'linedetection' ||
      normalizedEvent == 'fielddetection') {
    return OnyxEventType.perimeterBreach;
  }
  if (normalizedEvent == 'vmd' ||
      normalizedEvent == 'motion' ||
      normalizedEvent == 'motiondetected' ||
      normalizedEvent == 'motiondetection') {
    return switch (normalizedTarget) {
      'human' || 'person' => OnyxEventType.humanDetected,
      'vehicle' || 'car' || 'truck' => OnyxEventType.vehicleDetected,
      'animal' => OnyxEventType.animalDetected,
      _ => OnyxEventType.motionDetected,
    };
  }
  return OnyxEventType.unknown;
}

String _firstNonEmpty(String first, String second, [String third = '']) {
  for (final candidate in <String>[first, second, third]) {
    if (candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
  }
  return '';
}

String _readTag(xml.XmlDocument document, String tagName) {
  final normalizedTag = tagName.toLowerCase();
  for (final element in document.descendants.whereType<xml.XmlElement>()) {
    if (element.name.local.toLowerCase() == normalizedTag) {
      return element.innerText.trim();
    }
  }
  return '';
}

String _normalizeToken(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String _uuidV4(math.Random random) {
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return [
    hex.substring(0, 8),
    hex.substring(8, 12),
    hex.substring(12, 16),
    hex.substring(16, 20),
    hex.substring(20, 32),
  ].join('-');
}

// ─── Inlined from lib/application/site_awareness/onyx_site_awareness_service.dart ───

abstract class OnyxSiteAwarenessService {
  Future<void> start({required String siteId, required String clientId});
  Future<void> stop();
  OnyxSiteAwarenessSnapshot? get latestSnapshot;
  Stream<OnyxSiteAwarenessSnapshot> get snapshots;
  bool get isConnected;
}

// ─── Inlined from lib/application/dvr_http_auth.dart ───

enum DvrHttpAuthMode { none, bearer, digest }

DvrHttpAuthMode parseDvrHttpAuthMode(String raw) {
  final normalized = raw.trim().toLowerCase().replaceAll('-', '_');
  return switch (normalized) {
    'bearer' => DvrHttpAuthMode.bearer,
    'digest' => DvrHttpAuthMode.digest,
    _ => DvrHttpAuthMode.none,
  };
}

class DvrHttpAuthConfig {
  final DvrHttpAuthMode mode;
  final String? bearerToken;
  final String? username;
  final String? password;

  const DvrHttpAuthConfig({
    required this.mode,
    this.bearerToken,
    this.username,
    this.password,
  });

  bool get configured {
    return switch (mode) {
      DvrHttpAuthMode.bearer => (bearerToken ?? '').trim().isNotEmpty,
      DvrHttpAuthMode.digest =>
        (username ?? '').trim().isNotEmpty && (password ?? '').isNotEmpty,
      DvrHttpAuthMode.none => false,
    };
  }

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'auth_mode': mode.name,
      'bearer_token': (bearerToken ?? '').trim().isEmpty
          ? null
          : bearerToken!.trim(),
      'username': (username ?? '').trim().isEmpty ? null : username!.trim(),
      'password': (password ?? '').isEmpty ? null : password,
    };
  }

  factory DvrHttpAuthConfig.fromJsonObject(Object? raw) {
    if (raw is! Map) {
      return const DvrHttpAuthConfig(mode: DvrHttpAuthMode.none);
    }
    final json = raw.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
    final bearerToken = (json['bearer_token'] ?? '').toString().trim();
    final username = (json['username'] ?? '').toString().trim();
    final password = (json['password'] ?? '').toString();
    return DvrHttpAuthConfig(
      mode: parseDvrHttpAuthMode((json['auth_mode'] ?? '').toString()),
      bearerToken: bearerToken.isEmpty ? null : bearerToken,
      username: username.isEmpty ? null : username,
      password: password.isEmpty ? null : password,
    );
  }

  Future<http.Response> get(
    http.Client client,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    final response = await send(client, 'GET', uri, headers: headers);
    return http.Response.fromStream(response);
  }

  Future<http.Response> head(
    http.Client client,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    final response = await send(client, 'HEAD', uri, headers: headers);
    return http.Response.fromStream(response);
  }

  Future<http.StreamedResponse> send(
    http.Client client,
    String method,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) async {
    final baseHeaders = _withBearer(headers);
    final initialRequest = http.Request(method, uri)
      ..headers.addAll(baseHeaders);
    _applyBody(initialRequest, body);
    final initialResponse = await client.send(initialRequest);
    if (mode != DvrHttpAuthMode.digest || initialResponse.statusCode != 401) {
      return initialResponse;
    }

    final challenge = initialResponse.headers['www-authenticate'] ?? '';
    final digestHeader = _buildDigestAuthorization(
      challenge,
      method: method,
      uri: uri,
    );
    if (digestHeader == null) {
      return initialResponse;
    }

    await initialResponse.stream.drain<void>();
    final retryRequest = http.Request(method, uri)
      ..headers.addAll(baseHeaders)
      ..headers['Authorization'] = digestHeader;
    _applyBody(retryRequest, body);
    return client.send(retryRequest);
  }

  void _applyBody(http.Request request, Object? body) {
    if (body == null) {
      return;
    }
    if (body is String) {
      request.body = body;
      return;
    }
    if (body is List<int>) {
      request.bodyBytes = body;
      return;
    }
    if (body is Map<String, String>) {
      request.bodyFields = body;
      return;
    }
    request.body = body.toString();
  }

  Map<String, String> _withBearer(Map<String, String> headers) {
    final resolved = <String, String>{...headers};
    final token = bearerToken?.trim();
    if (mode == DvrHttpAuthMode.bearer &&
        token != null &&
        token.isNotEmpty &&
        !resolved.containsKey('Authorization')) {
      resolved['Authorization'] = 'Bearer $token';
    }
    return resolved;
  }

  String? _buildDigestAuthorization(
    String challenge, {
    required String method,
    required Uri uri,
  }) {
    final user = username?.trim() ?? '';
    final pass = password ?? '';
    if (user.isEmpty || pass.isEmpty) {
      return null;
    }
    final attributes = _parseDigestChallenge(challenge);
    final realm = attributes['realm'];
    final nonce = attributes['nonce'];
    if (realm == null || nonce == null || realm.isEmpty || nonce.isEmpty) {
      return null;
    }

    final uriPath = uri.path.isEmpty
        ? '/'
        : uri.path + (uri.hasQuery ? '?${uri.query}' : '');
    final qop =
        (attributes['qop'] ?? '')
            .split(',')
            .map((entry) => entry.trim())
            .contains('auth')
        ? 'auth'
        : '';
    const nc = '00000001';
    final cnonce = md5
        .convert(
          utf8.encode(
            '${DateTime.now().microsecondsSinceEpoch}|$uriPath|${math.Random().nextInt(1 << 32)}',
          ),
        )
        .toString()
        .substring(0, 16);
    final ha1 = md5.convert(utf8.encode('$user:$realm:$pass')).toString();
    final ha2 = md5
        .convert(utf8.encode('${method.toUpperCase()}:$uriPath'))
        .toString();
    final response = qop.isNotEmpty
        ? md5
              .convert(utf8.encode('$ha1:$nonce:$nc:$cnonce:$qop:$ha2'))
              .toString()
        : md5.convert(utf8.encode('$ha1:$nonce:$ha2')).toString();

    final parts = <String>[
      'Digest username="$user"',
      'realm="$realm"',
      'nonce="$nonce"',
      'uri="$uriPath"',
      if ((attributes['opaque'] ?? '').isNotEmpty)
        'opaque="${attributes['opaque']}"',
      if ((attributes['algorithm'] ?? '').isNotEmpty)
        'algorithm=${attributes['algorithm']}',
      if (qop.isNotEmpty) 'qop=$qop',
      if (qop.isNotEmpty) 'nc=$nc',
      if (qop.isNotEmpty) 'cnonce="$cnonce"',
      'response="$response"',
    ];
    return parts.join(', ');
  }

  Map<String, String> _parseDigestChallenge(String challenge) {
    final normalized = challenge.trim();
    if (!normalized.toLowerCase().startsWith('digest')) {
      return const <String, String>{};
    }
    final matches = RegExp(
      r'(\w+)=(?:"([^"]*)"|([^,\s]+))',
    ).allMatches(normalized);
    final values = <String, String>{};
    for (final match in matches) {
      final key = match.group(1)?.trim();
      final quoted = match.group(2);
      final plain = match.group(3);
      if (key == null || key.isEmpty) {
        continue;
      }
      values[key.toLowerCase()] = (quoted ?? plain ?? '').trim();
    }
    return values;
  }
}

// ─── Inlined from lib/application/site_awareness/onyx_site_awareness_repository.dart ───

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

class OnyxSiteVehicleRegistryEntry {
  final String siteId;
  final String plateNumber;
  final String vehicleDescription;
  final String ownerName;
  final String ownerRole;
  final bool isActive;
  final String visitType;

  const OnyxSiteVehicleRegistryEntry({
    required this.siteId,
    required this.plateNumber,
    required this.vehicleDescription,
    required this.ownerName,
    required this.ownerRole,
    required this.isActive,
    required this.visitType,
  });

  factory OnyxSiteVehicleRegistryEntry.fromRow(Map<String, dynamic> row) {
    return OnyxSiteVehicleRegistryEntry(
      siteId: (row['site_id'] as String? ?? '').trim(),
      plateNumber: _normalizeVehiclePlate(row['plate_number']),
      vehicleDescription:
          (row['vehicle_description'] as String? ?? '').trim(),
      ownerName: (row['owner_name'] as String? ?? '').trim(),
      ownerRole: (row['owner_role'] as String? ?? '').trim(),
      isActive: _siteOccupancyBool(row['is_active']) ?? true,
      visitType: (row['visit_type'] as String? ?? '').trim(),
    );
  }
}

class OnyxSiteVehiclePresenceEvent {
  final String id;
  final String siteId;
  final String plateNumber;
  final String ownerName;
  final String eventType;
  final int? channelId;
  final String? zoneName;
  final DateTime occurredAt;

  const OnyxSiteVehiclePresenceEvent({
    required this.id,
    required this.siteId,
    required this.plateNumber,
    required this.ownerName,
    required this.eventType,
    required this.channelId,
    required this.zoneName,
    required this.occurredAt,
  });

  factory OnyxSiteVehiclePresenceEvent.fromRow(Map<String, dynamic> row) {
    return OnyxSiteVehiclePresenceEvent(
      id: (row['id'] as String? ?? '').trim(),
      siteId: (row['site_id'] as String? ?? '').trim(),
      plateNumber: _normalizeVehiclePlate(row['plate_number']),
      ownerName: (row['owner_name'] as String? ?? '').trim(),
      eventType: (row['event_type'] as String? ?? '').trim(),
      channelId: _siteOccupancyInt(row['channel_id']),
      zoneName: (row['zone_name'] as String?)?.trim(),
      occurredAt:
          _siteOccupancyDate(row['occurred_at']) ?? DateTime.now().toUtc(),
    );
  }
}

class OnyxFrPersonRegistryEntry {
  final String siteId;
  final String personId;
  final String displayName;
  final String role;
  final bool isEnrolled;
  final bool isActive;

  const OnyxFrPersonRegistryEntry({
    required this.siteId,
    required this.personId,
    required this.displayName,
    required this.role,
    required this.isEnrolled,
    required this.isActive,
  });

  factory OnyxFrPersonRegistryEntry.fromRow(Map<String, dynamic> row) {
    return OnyxFrPersonRegistryEntry(
      siteId: (row['site_id'] as String? ?? '').trim(),
      personId: (row['person_id'] as String? ?? '').trim().toUpperCase(),
      displayName: (row['display_name'] as String? ?? '').trim(),
      role: (row['role'] as String? ?? '').trim(),
      isEnrolled: _siteOccupancyBool(row['is_enrolled']) ?? false,
      isActive: _siteOccupancyBool(row['is_active']) ?? true,
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
  final Map<String, List<OnyxSiteVehicleRegistryEntry>> _vehicleRegistryCache =
      <String, List<OnyxSiteVehicleRegistryEntry>>{};
  final Map<String, List<OnyxFrPersonRegistryEntry>> _frRegistryCache =
      <String, List<OnyxFrPersonRegistryEntry>>{};

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
      final occupancyConfig = await readOccupancyConfig(normalizedSiteId);
      final rows = await _client
          .from('site_alert_config')
          .select(
            'site_id,alert_window_start,alert_window_end,timezone,perimeter_sensitivity,semi_perimeter_sensitivity,indoor_sensitivity,loiter_detection_minutes,perimeter_sequence_alert,quiet_hours_sensitivity,day_sensitivity,vehicle_daytime_threshold',
          )
          .eq('site_id', normalizedSiteId)
          .limit(1);
      final config = rows.isEmpty
          ? null
          : SiteAlertConfig.fromRow(<String, dynamic>{
              ...Map<String, dynamic>.from(rows.first as Map),
              if (occupancyConfig != null) ...<String, dynamic>{
                'site_type': occupancyConfig.siteType,
                'expected_occupancy': occupancyConfig.expectedOccupancy,
              },
            });
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

  Future<Map<String, dynamic>?> readSiteProfileRow(String siteId) async {
    final normalizedSiteId = siteId.trim();
    if (normalizedSiteId.isEmpty) {
      return null;
    }
    try {
      final rows = await _client
          .from('site_intelligence_profiles')
          .select(
            'site_id,industry_type,operating_hours_start,operating_hours_end,operating_days,timezone,is_24h_operation,expected_staff_count,expected_resident_count,expected_vehicle_count,has_guard,has_armed_response,after_hours_sensitivity,during_hours_sensitivity,monitor_staff_activity,inactive_staff_alert_minutes,monitor_till_attendance,till_unattended_minutes,monitor_restricted_zones,monitor_vehicle_movement,after_hours_vehicle_alert,send_shift_start_briefing,send_shift_end_report,send_daily_summary,daily_summary_time,custom_rules',
          )
          .eq('site_id', normalizedSiteId)
          .limit(1);
      if (rows.isEmpty) {
        return null;
      }
      return Map<String, dynamic>.from(rows.first as Map);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to read site intelligence profile row for $normalizedSiteId.',
        name: 'OnyxSiteAwarenessRepository',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> readSiteZoneRuleRows(String siteId) async {
    final normalizedSiteId = siteId.trim();
    if (normalizedSiteId.isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    try {
      final rows = await _client
          .from('site_zone_rules')
          .select(
            'site_id,zone_name,zone_type,allowed_roles,access_hours_start,access_hours_end,access_days,violation_action,max_dwell_minutes,requires_escort,is_restricted',
          )
          .eq('site_id', normalizedSiteId);
      return rows
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to read site zone rules for $normalizedSiteId.',
        name: 'OnyxSiteAwarenessRepository',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> readExpectedVisitorRows(String siteId) async {
    final normalizedSiteId = siteId.trim();
    if (normalizedSiteId.isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    try {
      await _expireOnDemandExpectedVisitors(normalizedSiteId);
      final rows = await _client
          .from('site_expected_visitors')
          .select(
            'site_id,visitor_name,visitor_role,visit_type,visit_days,visit_start,visit_end,is_active,notes,visit_date,expires_at',
          )
          .eq('site_id', normalizedSiteId)
          .eq('is_active', true)
          .order('created_at', ascending: false);
      return rows
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to read expected visitors for $normalizedSiteId.',
        name: 'OnyxSiteAwarenessRepository',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<OnyxSiteVehicleRegistryEntry>> readVehicleRegistry(
    String siteId,
  ) async {
    final normalizedSiteId = siteId.trim();
    if (normalizedSiteId.isEmpty) {
      return const <OnyxSiteVehicleRegistryEntry>[];
    }
    if (_vehicleRegistryCache.containsKey(normalizedSiteId)) {
      return _vehicleRegistryCache[normalizedSiteId]!;
    }
    try {
      final rows = await _client
          .from('site_vehicle_registry')
          .select(
            'site_id,plate_number,vehicle_description,owner_name,owner_role,is_active,visit_type',
          )
          .eq('site_id', normalizedSiteId)
          .eq('is_active', true)
          .order('owner_name', ascending: true);
      final vehicles = rows
          .map(
            (row) => OnyxSiteVehicleRegistryEntry.fromRow(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .where((entry) => entry.plateNumber.isNotEmpty)
          .toList(growable: false);
      _vehicleRegistryCache[normalizedSiteId] =
          List<OnyxSiteVehicleRegistryEntry>.unmodifiable(vehicles);
      return _vehicleRegistryCache[normalizedSiteId]!;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to read vehicle registry for $normalizedSiteId.',
        name: 'OnyxSiteAwarenessRepository',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      return const <OnyxSiteVehicleRegistryEntry>[];
    }
  }

  Future<OnyxSiteVehicleRegistryEntry?> readVehicleRegistryEntry({
    required String siteId,
    required String plateNumber,
  }) async {
    final normalizedPlate = _normalizeVehiclePlate(plateNumber);
    if (normalizedPlate.isEmpty) {
      return null;
    }
    final registry = await readVehicleRegistry(siteId);
    for (final entry in registry) {
      if (entry.plateNumber == normalizedPlate) {
        return entry;
      }
    }
    return null;
  }

  Future<List<OnyxFrPersonRegistryEntry>> readFrRegistry(String siteId) async {
    final normalizedSiteId = siteId.trim();
    if (normalizedSiteId.isEmpty) {
      return const <OnyxFrPersonRegistryEntry>[];
    }
    if (_frRegistryCache.containsKey(normalizedSiteId)) {
      return _frRegistryCache[normalizedSiteId]!;
    }
    try {
      final rows = await _client
          .from('fr_person_registry')
          .select('site_id,person_id,display_name,role,is_enrolled,is_active')
          .eq('site_id', normalizedSiteId)
          .eq('is_active', true)
          .eq('is_enrolled', true)
          .order('display_name', ascending: true);
      final people = rows
          .map(
            (row) => OnyxFrPersonRegistryEntry.fromRow(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .where((entry) => entry.personId.isNotEmpty)
          .toList(growable: false);
      _frRegistryCache[normalizedSiteId] =
          List<OnyxFrPersonRegistryEntry>.unmodifiable(people);
      return _frRegistryCache[normalizedSiteId]!;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to read FR registry for $normalizedSiteId.',
        name: 'OnyxSiteAwarenessRepository',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      return const <OnyxFrPersonRegistryEntry>[];
    }
  }

  Future<OnyxFrPersonRegistryEntry?> readFrPerson({
    required String siteId,
    required String personId,
  }) async {
    final normalizedPersonId = personId.trim().toUpperCase();
    if (normalizedPersonId.isEmpty) {
      return null;
    }
    final registry = await readFrRegistry(siteId);
    for (final entry in registry) {
      if (entry.personId == normalizedPersonId) {
        return entry;
      }
    }
    return null;
  }

  Future<void> _expireOnDemandExpectedVisitors(String siteId) async {
    try {
      await _client
          .from('site_expected_visitors')
          .update(<String, Object?>{'is_active': false})
          .eq('site_id', siteId)
          .eq('visit_type', 'on_demand')
          .eq('is_active', true)
          .lte('expires_at', DateTime.now().toUtc().toIso8601String());
    } catch (_) {
      // Best-effort cleanup only.
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
      final rawPeakDetected =
          updatedChannels.length > (existing?.peakDetected ?? 0)
          ? updatedChannels.length
          : (existing?.peakDetected ?? 0);
      final expectedOccupancy = config?.expectedOccupancy ?? 0;
      final peakDetected = expectedOccupancy > 0
          ? math.min(rawPeakDetected, expectedOccupancy)
          : rawPeakDetected;
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

  Future<void> recordVehicleDetection({
    required String siteId,
    required String plateNumber,
    required int channelId,
    required String zoneName,
    required DateTime detectedAt,
  }) async {
    final normalizedSiteId = siteId.trim();
    final normalizedPlate = _normalizeVehiclePlate(plateNumber);
    if (normalizedSiteId.isEmpty) {
      return;
    }
    try {
      final registryEntry = normalizedPlate.isEmpty
          ? null
          : await readVehicleRegistryEntry(
              siteId: normalizedSiteId,
              plateNumber: normalizedPlate,
            );
      final recentPresence = await _readLatestVehiclePresence(
        siteId: normalizedSiteId,
        plateNumber: normalizedPlate,
      );
      final ownerName =
          registryEntry?.ownerName.trim().isNotEmpty == true
          ? registryEntry!.ownerName.trim()
          : 'Unknown';
      final eventType =
          normalizedPlate.isEmpty
          ? 'detected'
          : recentPresence != null &&
                detectedAt
                        .toUtc()
                        .difference(recentPresence.occurredAt.toUtc()) <
                    const Duration(minutes: 30)
          ? 'on_site'
          : 'arrived';
      await _client.from('site_vehicle_presence').insert(<String, Object?>{
        'site_id': normalizedSiteId,
        'plate_number': normalizedPlate.isEmpty ? 'UNKNOWN' : normalizedPlate,
        'owner_name': ownerName,
        'event_type': eventType,
        'channel_id': channelId > 0 ? channelId : null,
        'zone_name': zoneName.trim().isEmpty ? null : zoneName.trim(),
        'occurred_at': detectedAt.toUtc().toIso8601String(),
      });
      developer.log(
        normalizedPlate.isEmpty
            ? 'Unknown vehicle detected on $normalizedSiteId.'
            : registryEntry == null
            ? 'Unknown vehicle detected: $normalizedPlate'
            : 'Known vehicle detected: $normalizedPlate — ${registryEntry.ownerName}',
        name: 'OnyxSiteAwarenessRepository',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to record vehicle detection for $normalizedSiteId plate ${plateNumber.trim()}.',
        name: 'OnyxSiteAwarenessRepository',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      rethrow;
    }
  }

  Future<void> recordCameraWorkerOffline({
    required String siteId,
    required String deviceId,
    required DateTime occurredAt,
    required int consecutiveFailures,
    required Duration nextRetryDelay,
    required String host,
    required int port,
  }) async {
    try {
      await _client.from('site_alarm_events').insert(<String, Object?>{
        'site_id': siteId.trim(),
        'device_id': deviceId.trim(),
        'event_type': 'camera_worker_offline',
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'raw_payload': <String, Object?>{
          'host': host,
          'port': port,
          'consecutive_failures': consecutiveFailures,
          'next_retry_seconds': nextRetryDelay.inSeconds,
        },
      });
    } catch (error, stackTrace) {
      developer.log(
        'Failed to record camera worker offline event for $siteId.',
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

  Future<OnyxSiteVehiclePresenceEvent?> _readLatestVehiclePresence({
    required String siteId,
    required String plateNumber,
  }) async {
    final normalizedPlate = _normalizeVehiclePlate(plateNumber);
    if (siteId.trim().isEmpty || normalizedPlate.isEmpty) {
      return null;
    }
    final rows = await _client
        .from('site_vehicle_presence')
        .select(
          'id,site_id,plate_number,owner_name,event_type,channel_id,zone_name,occurred_at',
        )
        .eq('site_id', siteId.trim())
        .eq('plate_number', normalizedPlate)
        .order('occurred_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) {
      return null;
    }
    return OnyxSiteVehiclePresenceEvent.fromRow(
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

String _normalizeVehiclePlate(Object? value) {
  final raw = value?.toString().trim().toUpperCase() ?? '';
  if (raw.isEmpty) {
    return '';
  }
  return raw.replaceAll(RegExp(r'[^A-Z0-9]'), '');
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

String _snapshotStreamChannelId(String channelId) {
  final trimmed = channelId.trim();
  final parsed = int.tryParse(trimmed);
  if (parsed == null || parsed <= 0) {
    return trimmed;
  }
  if (trimmed.length > 2 && trimmed.endsWith('01')) {
    return trimmed;
  }
  return '${parsed}01';
}

// ─── Inlined from lib/application/site_awareness/onyx_hik_isapi_stream_awareness_service.dart ───

http.Client _buildIsapiHttpClient() {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  return IOClient(client);
}

class OnyxHikIsapiStreamAwarenessService implements OnyxSiteAwarenessService {
  final String host;
  final int port;
  final String username;
  final String password;
  final List<String> knownFaultChannels;
  final http.Client _client;
  final OnyxSiteAwarenessRepository? _repository;
  final OnyxProactiveAlertService? _proactiveAlertService;
  final Duration requestTimeout;
  final Duration publishInterval;
  final Duration detectionWindow;
  final Duration initialRetryDelay;
  final Duration maxRetryDelay;
  final DateTime Function() _clock;
  final Future<void> Function(Duration duration) _sleep;
  final Future<void> Function(
    String siteId,
    int consecutiveFailures,
    Duration nextRetryDelay,
  )?
  onReconnectFailure;
  final OnyxLiveSnapshotYoloService? _liveSnapshotYoloService;
  final OnyxLprService? _lprService;

  final StreamController<OnyxSiteAwarenessSnapshot> _snapshotController =
      StreamController<OnyxSiteAwarenessSnapshot>.broadcast();

  StreamSubscription<List<int>>? _streamSubscription;
  StreamSubscription<OnyxProactiveAlertDecision>? _proactiveAlertSubscription;
  Timer? _publishTimer;
  Timer? _heartbeatTimer;
  OnyxSiteAwarenessProjector? _projector;
  OnyxSiteAwarenessSnapshot? _latestSnapshot;
  bool _isConnected = false;
  bool _running = false;
  bool _disconnectAlertSent = false;
  int _generation = 0;
  String _siteId = '';
  String _clientId = '';
  DateTime? _lastStreamEventAtUtc;

  OnyxHikIsapiStreamAwarenessService({
    required this.host,
    this.port = 80,
    required this.username,
    required this.password,
    this.knownFaultChannels = const <String>[],
    http.Client? client,
    OnyxSiteAwarenessRepository? repository,
    OnyxProactiveAlertService? proactiveAlertService,
    this.requestTimeout = const Duration(seconds: 15),
    this.publishInterval = const Duration(seconds: 30),
    this.detectionWindow = const Duration(minutes: 5),
    this.initialRetryDelay = const Duration(seconds: 1),
    this.maxRetryDelay = const Duration(seconds: 60),
    DateTime Function()? clock,
    Future<void> Function(Duration duration)? sleep,
    this.onReconnectFailure,
    OnyxLiveSnapshotYoloService? liveSnapshotYoloService,
    OnyxLprService? lprService,
  }) : _client = client ?? _buildIsapiHttpClient(),
       _repository = repository,
       _proactiveAlertService = proactiveAlertService,
       _clock = clock ?? DateTime.now,
       _sleep = sleep ?? Future<void>.delayed,
       _liveSnapshotYoloService = liveSnapshotYoloService,
       _lprService = lprService;

  @override
  OnyxSiteAwarenessSnapshot? get latestSnapshot => _latestSnapshot;

  @override
  Stream<OnyxSiteAwarenessSnapshot> get snapshots => _snapshotController.stream;

  @override
  bool get isConnected => _isConnected;

  Uri get _alertStreamUri => Uri(
    scheme: 'http',
    host: host,
    port: port,
    path: '/ISAPI/Event/notification/alertStream',
  );

  Uri get _systemStatusUri => Uri(
    scheme: 'http',
    host: host,
    port: port,
    path: '/ISAPI/System/status',
  );

  Uri _snapshotUriForChannel(String channelId) {
    final normalizedChannelId = _snapshotStreamChannelId(channelId);
    return Uri(
      scheme: 'http',
      host: host,
      port: port,
      path: '/ISAPI/Streaming/channels/$normalizedChannelId/picture',
    );
  }

  @override
  Future<void> start({required String siteId, required String clientId}) async {
    await stop();
    _siteId = siteId.trim();
    _clientId = clientId.trim();
    final cameraZones = _repository == null
        ? const <String, OnyxCameraZone>{}
        : await _repository.readCameraZones(_siteId);
    _projector = OnyxSiteAwarenessProjector(
      siteId: _siteId,
      clientId: _clientId,
      knownFaultChannels: knownFaultChannels.toSet(),
      cameraZones: cameraZones,
      detectionWindow: detectionWindow,
      clock: _clock,
    );
    _proactiveAlertService?.resetSite(_siteId);
    await _proactiveAlertSubscription?.cancel();
    _proactiveAlertSubscription = _proactiveAlertService?.alerts.listen((
      decision,
    ) {
      if (decision.siteId.trim() != _siteId.trim()) {
        return;
      }
      final projector = _projector;
      if (projector == null) {
        return;
      }
      final snapshot = projector.ingestSiteAlert(
        OnyxSiteAlert(
          alertId:
              '${decision.siteId}:${decision.channelId}:${decision.detectedAt.microsecondsSinceEpoch}:${decision.isLoitering ? 'loiter' : 'motion'}:${decision.isSequence ? 'sequence' : 'single'}',
          channelId: '${decision.channelId}',
          eventType: OnyxEventType.humanDetected,
          detectedAt: decision.detectedAt,
          zoneName: decision.zoneName,
          zoneType: decision.zoneType,
          message: decision.message,
          isLoitering: decision.isLoitering,
          isSequence: decision.isSequence,
          alertSource: 'proactive_detection',
        ),
      );
      _emitSnapshot(snapshot);
    });
    _latestSnapshot = null;
    _isConnected = false;
    _disconnectAlertSent = false;
    _running = true;
    _generation += 1;
    _lastStreamEventAtUtc = _clock().toUtc();
    _publishTimer = Timer.periodic(publishInterval, (_) {
      _publishProjectedSnapshot();
    });
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      unawaited(_sendKeepaliveHeartbeat(_generation));
    });
    unawaited(_runConnectionLoop(_generation));
  }

  @override
  Future<void> stop() async {
    _running = false;
    _generation += 1;
    _isConnected = false;
    _disconnectAlertSent = false;
    _publishTimer?.cancel();
    _publishTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _lastStreamEventAtUtc = null;
    final subscription = _streamSubscription;
    _streamSubscription = null;
    final proactiveAlertSubscription = _proactiveAlertSubscription;
    _proactiveAlertSubscription = null;
    if (subscription != null) {
      try {
        await subscription.cancel();
      } catch (error, stackTrace) {
        developer.log(
          'Failed to cancel Hikvision alert stream subscription cleanly.',
          name: 'OnyxHikIsapiStream',
          error: error,
          stackTrace: stackTrace,
          level: 1000,
        );
      }
    }
    if (proactiveAlertSubscription != null) {
      try {
        await proactiveAlertSubscription.cancel();
      } catch (error, stackTrace) {
        developer.log(
          'Failed to cancel proactive alert subscription cleanly.',
          name: 'OnyxHikIsapiStream',
          error: error,
          stackTrace: stackTrace,
          level: 1000,
        );
      }
    }
  }

  Future<List<int>?> fetchSnapshotBytes(String channelId) async {
    try {
      final response = await _auth
          .get(
            _client,
            _snapshotUriForChannel(channelId.trim()),
            headers: const <String, String>{'Accept': 'image/jpeg,image/*,*/*'},
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        developer.log(
          'Snapshot request returned HTTP ${response.statusCode} for channel $channelId.',
          name: 'OnyxHikIsapiStream',
          level: 900,
        );
        return null;
      }
      return response.bodyBytes;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to fetch on-demand channel snapshot for $channelId.',
        name: 'OnyxHikIsapiStream',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      return null;
    }
  }

  Future<void> _runConnectionLoop(int generation) async {
    var retryAttempt = 0;
    while (_running && generation == _generation) {
      String? disconnectReason;
      Object? disconnectError;
      StackTrace? disconnectStackTrace;
      var disconnectLogLevel = 1000;
      try {
        await _primeSocketConnection();
        final response = await _auth
            .send(
              _client,
              'GET',
              _alertStreamUri,
              headers: const <String, String>{
                'Accept':
                    'multipart/x-mixed-replace, application/xml, text/xml',
              },
            )
            .timeout(requestTimeout);
        if (!_running || generation != _generation) {
          await response.stream.drain<void>();
          break;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          _isConnected = false;
          disconnectReason =
              'Alert stream returned HTTP ${response.statusCode}.';
          disconnectLogLevel = 900;
          await response.stream.drain<void>();
        } else {
          final resumedAfterFailures = retryAttempt > 0 || _disconnectAlertSent;
          _isConnected = true;
          _lastStreamEventAtUtc = _clock().toUtc();
          retryAttempt = 0;
          _disconnectAlertSent = false;
          if (resumedAfterFailures) {
            developer.log(
              '[ONYX] Camera stream reconnected.',
              name: 'OnyxHikIsapiStream',
            );
          }
          final projector = _projector;
          if (projector != null) {
            _emitSnapshot(projector.snapshot());
          }
          await _consumeAlertStream(response.stream, generation);
          if (_running && generation == _generation) {
            _isConnected = false;
            disconnectReason = 'Alert stream closed unexpectedly.';
          }
        }
      } catch (error, stackTrace) {
        _isConnected = false;
        disconnectReason = 'Site awareness stream connection failed.';
        disconnectError = error;
        disconnectStackTrace = stackTrace;
      }
      if (!_running || generation != _generation) {
        break;
      }
      if (disconnectReason == null) {
        continue;
      }
      final nextAttempt = retryAttempt + 1;
      final delay = _retryDelayFor(retryAttempt);
      developer.log(
        '[ONYX] ⚠️ Camera stream disconnected from $host:$port — reconnecting in '
        '${delay.inSeconds}s (attempt $nextAttempt). $disconnectReason',
        name: 'OnyxHikIsapiStream',
        error: disconnectError,
        stackTrace: disconnectStackTrace,
        level: disconnectLogLevel,
      );
      if (nextAttempt >= 3 &&
          !_disconnectAlertSent &&
          onReconnectFailure != null) {
        try {
          await onReconnectFailure!(_siteId, nextAttempt, delay);
          _disconnectAlertSent = true;
        } catch (error, stackTrace) {
          developer.log(
            'Failed to dispatch camera reconnect alert.',
            name: 'OnyxHikIsapiStream',
            error: error,
            stackTrace: stackTrace,
            level: 1000,
          );
        }
      }
      if (nextAttempt >= 3) {
        developer.log(
          '[ONYX] Camera worker terminating after 3 failures',
          name: 'OnyxHikIsapiStream',
          level: 1000,
        );
        await stop();
        exit(1);
      }
      retryAttempt += 1;
      await _sleep(delay);
    }
    if (generation == _generation) {
      _isConnected = false;
    }
  }

  Future<void> _consumeAlertStream(
    Stream<List<int>> stream,
    int generation,
  ) async {
    var buffer = '';
    try {
      await for (final chunk in stream) {
        if (!_running || generation != _generation) {
          break;
        }
        _lastStreamEventAtUtc = _clock().toUtc();
        buffer += utf8.decode(chunk, allowMalformed: true);
        final extraction = _extractAlertXml(buffer);
        buffer = extraction.remainder;
        for (final payload in extraction.payloads) {
          await _ingestAlertPayload(
            payload,
            errorLabel:
                'Failed to parse Hikvision EventNotificationAlert payload.',
          );
        }
      }
    } catch (error, stackTrace) {
      _isConnected = false;
      developer.log(
        'Alert stream subscription reported an error.',
        name: 'OnyxHikIsapiStream',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    } finally {
      _isConnected = false;
      final extraction = _extractAlertXml(buffer);
      for (final payload in extraction.payloads) {
        await _ingestAlertPayload(
          payload,
          errorLabel: 'Failed to parse trailing Hikvision alert payload.',
        );
      }
      if (generation == _generation) {
        _streamSubscription = null;
      }
    }
  }

  Future<void> _sendKeepaliveHeartbeat(int generation) async {
    if (!_running || !_isConnected || generation != _generation) {
      return;
    }
    final lastEventAtUtc = _lastStreamEventAtUtc;
    if (lastEventAtUtc != null &&
        _clock().toUtc().difference(lastEventAtUtc) <
            const Duration(seconds: 60)) {
      return;
    }
    try {
      await _primeSocketConnection();
      final response = await _auth
          .head(
            _client,
            _systemStatusUri,
            headers: const <String, String>{'Accept': '*/*'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _lastStreamEventAtUtc = _clock().toUtc();
      } else {
        developer.log(
          'ISAPI keepalive heartbeat returned HTTP ${response.statusCode}.',
          name: 'OnyxHikIsapiStream',
          level: 900,
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'ISAPI keepalive heartbeat failed.',
        name: 'OnyxHikIsapiStream',
        error: error,
        stackTrace: stackTrace,
        level: 900,
      );
    }
  }

  Future<void> _primeSocketConnection() async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 10),
      );
      socket.setOption(SocketOption.tcpNoDelay, true);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to prime TCP socket before ISAPI request.',
        name: 'OnyxHikIsapiStream',
        error: error,
        stackTrace: stackTrace,
        level: 900,
      );
    } finally {
      await socket?.close();
    }
  }

  Future<void> _ingestAlertPayload(
    String payload, {
    required String errorLabel,
  }) async {
    try {
      var event = OnyxSiteAwarenessEvent.fromAlertXml(
        payload,
        knownFaultChannels: knownFaultChannels.toSet(),
        clock: _clock,
      );
      if (event.eventType == OnyxEventType.humanDetected) {
        event = await _enrichHumanDetectionEvent(event);
      } else if (event.eventType == OnyxEventType.vehicleDetected) {
        event = await _enrichVehicleDetectionEvent(event);
      }
      await _ingestEvent(event);
    } catch (error, stackTrace) {
      developer.log(
        errorLabel,
        name: 'OnyxHikIsapiStream',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    }
  }

  Future<void> _ingestEvent(OnyxSiteAwarenessEvent event) async {
    final projector = _projector;
    if (projector == null) {
      return;
    }
    final snapshot = projector.ingest(event);
    _latestSnapshot = snapshot;
    final repository = _repository;
    if (repository != null && event.eventType == OnyxEventType.humanDetected) {
      unawaited(_persistOccupancy(repository, event));
    }
    if (repository != null && event.eventType == OnyxEventType.vehicleDetected) {
      unawaited(_persistVehiclePresence(repository, event));
    }
    final proactiveAlertService = _proactiveAlertService;
    if (proactiveAlertService != null &&
        (event.eventType == OnyxEventType.humanDetected ||
            event.eventType == OnyxEventType.vehicleDetected)) {
      if (event.eventType == OnyxEventType.humanDetected &&
          (event.faceMatchId ?? '').trim().isNotEmpty) {
        developer.log(
          '[ONYX] Suppressing proactive alert for known person '
          '${event.faceMatchName ?? event.faceMatchId} on CH${event.channelId}.',
          name: 'OnyxHikIsapiStream',
        );
      } else {
        final zone = projector.cameraZones[event.channelId];
        final channelId = int.tryParse(event.channelId.trim()) ?? 0;
        unawaited(
          proactiveAlertService.evaluateDetection(
            siteId: _siteId,
            channelId: channelId,
            zoneType:
                zone?.zoneType ??
                (zone?.isPerimeter == true ? 'perimeter' : 'semi_perimeter'),
            zoneName: zone?.zoneName ?? 'Channel ${event.channelId}',
            isPerimeter: zone?.isPerimeter ?? false,
            detectionKind: event.eventType == OnyxEventType.vehicleDetected
                ? OnyxProactiveDetectionKind.vehicle
                : OnyxProactiveDetectionKind.human,
            detectedAt: event.detectedAt,
          ),
        );
      }
    }
    if (event.shouldPublishImmediately) {
      _emitSnapshot(snapshot);
    }
  }

  Future<OnyxSiteAwarenessEvent> _enrichHumanDetectionEvent(
    OnyxSiteAwarenessEvent event,
  ) async {
    final liveSnapshotYoloService = _liveSnapshotYoloService;
    // ignore: avoid_print
    print('[ONYX-DEBUG] _enrichHumanDetectionEvent called for CH${event.channelId}');
    // ignore: avoid_print
    print(
      '[ONYX-DEBUG] liveSnapshotYoloService configured: '
      '${liveSnapshotYoloService?.isConfigured}',
    );
    if (liveSnapshotYoloService == null || !liveSnapshotYoloService.isConfigured) {
      developer.log(
        '[ONYX] FR snapshot skipped for CH${event.channelId}: YOLO/FR endpoint is not configured.',
        name: 'OnyxHikIsapiStream',
        level: 800,
      );
      return event;
    }
    final channelId = event.channelId.trim();
    if (channelId.isEmpty || channelId == 'unknown') {
      developer.log(
        '[ONYX] FR snapshot skipped: human detection has no usable channel ID.',
        name: 'OnyxHikIsapiStream',
        level: 800,
      );
      return event;
    }
    final snapshotChannelId = _snapshotStreamChannelId(channelId);
    developer.log(
      '[ONYX] Capturing snapshot from CH$snapshotChannelId for live FR...',
      name: 'OnyxHikIsapiStream',
    );
    final snapshotBytes = await fetchSnapshotBytes(channelId);
    if (snapshotBytes == null || snapshotBytes.isEmpty) {
      developer.log(
        '[ONYX] FR snapshot capture failed for CH$snapshotChannelId.',
        name: 'OnyxHikIsapiStream',
        level: 900,
      );
      return event;
    }
    final zone = _projector?.cameraZones[channelId];
    developer.log(
      '[ONYX] Sending CH$snapshotChannelId snapshot to YOLO/FR (${snapshotBytes.length} bytes)...',
      name: 'OnyxHikIsapiStream',
    );
    final result = await liveSnapshotYoloService.detectSnapshot(
      recordKey:
          '${_siteId}_${channelId}_${event.detectedAt.toUtc().microsecondsSinceEpoch}',
      provider: 'hikvision_isapi',
      sourceType: 'site_awareness_snapshot',
      clientId: _clientId,
      siteId: _siteId,
      cameraId: channelId,
      zone: zone?.zoneName ?? 'Channel $channelId',
      occurredAtUtc: event.detectedAt.toUtc(),
      imageBytes: snapshotBytes,
    );
    if (result == null) {
      return event;
    }
    if ((result.error ?? '').trim().isNotEmpty) {
      developer.log(
        'YOLO snapshot detect returned an error for CH$channelId: ${result.error}',
        name: 'OnyxHikIsapiStream',
        level: 900,
      );
    }
    final faceMatchId = (result.faceMatchId ?? '').trim().toUpperCase();
    if (faceMatchId.isNotEmpty) {
      final person = _repository == null
          ? null
          : await _repository.readFrPerson(
              siteId: _siteId,
              personId: faceMatchId,
            );
      final label =
          (person?.displayName ?? '').trim().isNotEmpty
          ? person!.displayName.trim()
          : faceMatchId;
      developer.log(
        '[ONYX] FR match: $label detected on CH$channelId '
        '(confidence ${(result.faceConfidence ?? result.personConfidence ?? 0).toStringAsFixed(2)}, '
        'distance ${(result.faceDistance ?? 0).toStringAsFixed(2)})',
        name: 'OnyxHikIsapiStream',
      );
      return event.copyWith(
        faceMatchId: faceMatchId,
        faceMatchName: person?.displayName,
        faceMatchConfidence: result.faceConfidence ?? result.personConfidence,
        faceMatchDistance: result.faceDistance,
        unknownPerson: false,
      );
    }
    if (result.personDetected) {
      developer.log(
        '[ONYX] FR: Unknown person on CH$channelId '
        '(confidence ${(result.personConfidence ?? 0).toStringAsFixed(2)})',
        name: 'OnyxHikIsapiStream',
      );
      return event.copyWith(
        unknownPerson: true,
        faceMatchConfidence: result.personConfidence,
      );
    }
    developer.log(
      '[ONYX] FR: No person confirmed in CH$channelId snapshot '
      '(${(result.personConfidence ?? 0).toStringAsFixed(2)}).',
      name: 'OnyxHikIsapiStream',
    );
    return event;
  }

  Future<OnyxSiteAwarenessEvent> _enrichVehicleDetectionEvent(
    OnyxSiteAwarenessEvent event,
  ) async {
    final lprService = _lprService;
    if (lprService == null || !lprService.isConfigured) {
      return event;
    }
    final channelId = event.channelId.trim();
    if (channelId.isEmpty || channelId == 'unknown') {
      return event;
    }
    final snapshotChannelId = _snapshotStreamChannelId(channelId);
    developer.log(
      '[ONYX] Capturing vehicle snapshot from CH$snapshotChannelId for live LPR...',
      name: 'OnyxHikIsapiStream',
    );
    final snapshotBytes = await fetchSnapshotBytes(channelId);
    if (snapshotBytes == null || snapshotBytes.isEmpty) {
      developer.log(
        '[ONYX] LPR snapshot capture failed for CH$snapshotChannelId.',
        name: 'OnyxHikIsapiStream',
        level: 900,
      );
      return event;
    }
    final zone = _projector?.cameraZones[channelId];
    final result = await lprService.detectPlate(
      recordKey:
          '${_siteId}_${channelId}_${event.detectedAt.toUtc().microsecondsSinceEpoch}_vehicle',
      provider: 'hikvision_isapi',
      sourceType: 'site_awareness_vehicle_snapshot',
      clientId: _clientId,
      siteId: _siteId,
      cameraId: channelId,
      zone: zone?.zoneName ?? 'Channel $channelId',
      occurredAtUtc: event.detectedAt.toUtc(),
      imageBytes: snapshotBytes,
    );
    if (result == null) {
      return event;
    }
    if ((result.error ?? '').trim().isNotEmpty) {
      developer.log(
        'YOLO vehicle snapshot detect returned an error for CH$channelId: ${result.error}',
        name: 'OnyxHikIsapiStream',
        level: 900,
      );
    }
    final detectedPlate = _normalizeVehiclePlate(
      result.plateNumber ?? event.plateNumber ?? '',
    );
    if (detectedPlate.isEmpty) {
      developer.log(
        '[ONYX] LPR: No readable plate on CH$channelId.',
        name: 'OnyxHikIsapiStream',
      );
      return event;
    }
    final registryEntry = _repository == null
        ? null
        : await _repository.readVehicleRegistryEntry(
            siteId: _siteId,
            plateNumber: detectedPlate,
          );
    developer.log(
      registryEntry == null
          ? '[ONYX] LPR: Unknown plate — $detectedPlate at CH$channelId'
          : '[ONYX] LPR: Plate detected — $detectedPlate → ${registryEntry.ownerName}',
      name: 'OnyxHikIsapiStream',
    );
    return event.copyWith(plateNumber: detectedPlate);
  }

  void _publishProjectedSnapshot() {
    final projector = _projector;
    if (!_running || !_isConnected || projector == null) {
      return;
    }
    try {
      final snapshot = projector.snapshot();
      _emitSnapshot(snapshot);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to publish site awareness snapshot.',
        name: 'OnyxHikIsapiStream',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    }
  }

  void _emitSnapshot(OnyxSiteAwarenessSnapshot snapshot) {
    _latestSnapshot = snapshot;
    if (!_snapshotController.isClosed) {
      _snapshotController.add(snapshot);
    }
    final repository = _repository;
    if (repository != null) {
      unawaited(_persistSnapshot(repository, snapshot));
    }
  }

  Future<void> _persistSnapshot(
    OnyxSiteAwarenessRepository repository,
    OnyxSiteAwarenessSnapshot snapshot,
  ) async {
    try {
      await repository.upsertSnapshot(snapshot);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to persist site awareness snapshot.',
        name: 'OnyxHikIsapiStream',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    }
  }

  Future<void> _persistOccupancy(
    OnyxSiteAwarenessRepository repository,
    OnyxSiteAwarenessEvent event,
  ) async {
    try {
      await repository.recordHumanDetection(
        siteId: _siteId,
        channelId: event.channelId,
        detectedAt: event.detectedAt,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to persist site occupancy session.',
        name: 'OnyxHikIsapiStream',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    }
  }

  Future<void> _persistVehiclePresence(
    OnyxSiteAwarenessRepository repository,
    OnyxSiteAwarenessEvent event,
  ) async {
    try {
      final channelId = int.tryParse(event.channelId.trim()) ?? 0;
      final zone = _projector?.cameraZones[event.channelId];
      await repository.recordVehicleDetection(
        siteId: _siteId,
        plateNumber: event.plateNumber ?? '',
        channelId: channelId,
        zoneName: zone?.zoneName ?? 'Channel ${event.channelId}',
        detectedAt: event.detectedAt,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to persist vehicle presence event.',
        name: 'OnyxHikIsapiStream',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    }
  }

  ({List<String> payloads, String remainder}) _extractAlertXml(String raw) {
    final matches = RegExp(
      r'<EventNotificationAlert\b[^>]*>[\s\S]*?</EventNotificationAlert>',
    ).allMatches(raw).toList(growable: false);
    if (matches.isEmpty) {
      return (payloads: const <String>[], remainder: raw);
    }
    final payloads = matches
        .map((match) => match.group(0) ?? '')
        .where((payload) => payload.trim().isNotEmpty)
        .toList(growable: false);
    return (payloads: payloads, remainder: raw.substring(matches.last.end));
  }

  Duration _retryDelayFor(int attempt) {
    const retryScheduleSeconds = <int>[5, 10, 30, 60];
    final seconds =
        retryScheduleSeconds[math.min<int>(
          attempt,
          retryScheduleSeconds.length - 1,
        )];
    return Duration(seconds: math.min(seconds, maxRetryDelay.inSeconds));
  }

  DvrHttpAuthConfig get _auth => DvrHttpAuthConfig(
    mode: DvrHttpAuthMode.digest,
    username: username,
    password: password,
  );
}

// ─── Non-secret config baked in at compile time via dart-define ───

const String _defaultHost = String.fromEnvironment(
  'ONYX_HIK_HOST',
  defaultValue: '192.168.0.117',
);
const int _defaultPort = int.fromEnvironment('ONYX_HIK_PORT', defaultValue: 80);
const String _defaultUsername = String.fromEnvironment(
  'ONYX_HIK_USERNAME',
  defaultValue: 'admin',
);
const String _defaultKnownFaultChannels = String.fromEnvironment(
  'ONYX_HIK_KNOWN_FAULT_CHANNELS',
  defaultValue: '11',
);
const String _defaultClientId = String.fromEnvironment(
  'ONYX_CLIENT_ID',
  defaultValue: 'CLIENT-MS-VALLEE',
);
const String _defaultSiteId = String.fromEnvironment(
  'ONYX_SITE_ID',
  defaultValue: 'SITE-MS-VALLEE-RESIDENCE',
);
const String _defaultYoloEndpoint = String.fromEnvironment(
  'ONYX_MONITORING_YOLO_ENDPOINT',
  defaultValue: 'http://127.0.0.1:11636/detect',
);

bool _envBool(String name, {bool fallback = false}) {
  final raw = Platform.environment[name];
  if (raw == null || raw.trim().isEmpty) {
    return fallback;
  }
  switch (raw.trim().toLowerCase()) {
    case '1':
    case 'true':
    case 'yes':
    case 'on':
      return true;
    case '0':
    case 'false':
    case 'no':
    case 'off':
      return false;
    default:
      return fallback;
  }
}

Future<void> _sendCameraWorkerReconnectAlert({
  required String siteId,
  required String host,
  required int port,
  required int consecutiveFailures,
  required Duration nextRetryDelay,
}) async {
  final botToken = Platform.environment['ONYX_TELEGRAM_BOT_TOKEN'] ?? '';
  final chatId = Platform.environment['ONYX_TELEGRAM_ADMIN_CHAT_ID'] ?? '';
  final threadId = (Platform.environment['ONYX_TELEGRAM_ADMIN_THREAD_ID'] ?? '')
      .trim();
  final adminEnabled = _envBool(
    'ONYX_TELEGRAM_ADMIN_CONTROL_ENABLED',
    fallback: true,
  );
  final criticalPushEnabled = _envBool(
    'ONYX_TELEGRAM_ADMIN_CRITICAL_PUSH_ENABLED',
    fallback: true,
  );
  if (!adminEnabled ||
      !criticalPushEnabled ||
      botToken.isEmpty ||
      chatId.isEmpty) {
    developer.log(
      'Camera reconnect alert skipped because admin Telegram push is not configured.',
      name: 'OnyxHikIsapiStream',
      level: 900,
    );
    return;
  }

  final uri = Uri.https('api.telegram.org', '/bot$botToken/sendMessage');
  final body = <String, String>{
    'chat_id': chatId,
    'text':
        '⚠️ ONYX camera stream disconnected for $siteId and has failed '
        'to reconnect after $consecutiveFailures attempts. '
        'Target: $host:$port. '
        'Next retry in ${nextRetryDelay.inSeconds}s.',
    'disable_notification': 'false',
  };
  if (threadId.isNotEmpty) {
    body['message_thread_id'] = threadId;
  }

  try {
    final response = await http
        .post(uri, body: body)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      developer.log(
        'Camera reconnect alert failed with HTTP ${response.statusCode}.',
        name: 'OnyxHikIsapiStream',
        error: response.body,
        level: 1000,
      );
      return;
    }
    developer.log(
      'Camera reconnect alert sent to Telegram admin chat.',
      name: 'OnyxHikIsapiStream',
    );
  } catch (error, stackTrace) {
    developer.log(
      'Camera reconnect alert failed to send.',
      name: 'OnyxHikIsapiStream',
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }
}

Future<void> main() async {
  // Password must come from the runtime environment — never compiled in.
  final password = Platform.environment['ONYX_HIK_PASSWORD'] ?? '';
  if (password.isEmpty) {
    stderr.writeln(
      '[ONYX] ERROR: ONYX_HIK_PASSWORD is not set.\n'
      '  Set it in your shell before running:\n'
      '    export ONYX_HIK_PASSWORD=yourpassword\n'
      '    dart run bin/onyx_camera_worker.dart',
    );
    exit(1);
  }

  final host = Platform.environment['ONYX_HIK_HOST'] ?? _defaultHost;
  final port =
      int.tryParse(Platform.environment['ONYX_HIK_PORT'] ?? '') ?? _defaultPort;
  final username =
      Platform.environment['ONYX_HIK_USERNAME'] ?? _defaultUsername;
  final clientId = Platform.environment['ONYX_CLIENT_ID'] ?? _defaultClientId;
  final siteId = Platform.environment['ONYX_SITE_ID'] ?? _defaultSiteId;
  final yoloEndpointRaw =
      Platform.environment['ONYX_MONITORING_YOLO_ENDPOINT'] ??
      _defaultYoloEndpoint;
  final yoloAuthToken =
      Platform.environment['ONYX_MONITORING_YOLO_AUTH_TOKEN'] ?? '';
  final yoloEndpoint = Uri.tryParse(yoloEndpointRaw.trim());

  final rawFaultChannels =
      Platform.environment['ONYX_HIK_KNOWN_FAULT_CHANNELS'] ??
      _defaultKnownFaultChannels;
  final knownFaultChannels = rawFaultChannels
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);

  // Build Supabase client using pure Dart package (no Flutter dependency).
  // Service key is preferred — it bypasses RLS for server-side writes.
  final supabaseUrl = Platform.environment['ONYX_SUPABASE_URL'] ?? '';
  final serviceKey = Platform.environment['ONYX_SUPABASE_SERVICE_KEY'] ?? '';
  final anonKey = Platform.environment['SUPABASE_ANON_KEY'] ?? '';
  final supabaseKey = serviceKey.isNotEmpty ? serviceKey : anonKey;

  OnyxSiteAwarenessRepository? repository;
  OnyxProactiveAlertService? proactiveAlertService;
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    final supabaseClient = SupabaseClient(supabaseUrl, supabaseKey);
    repository = OnyxSiteAwarenessRepository(supabaseClient);
    proactiveAlertService = OnyxProactiveAlertService(
      readConfig: repository.readAlertConfig,
      profileService: OnyxSiteProfileService(
        readProfileRow: repository.readSiteProfileRow,
        readZoneRuleRows: repository.readSiteZoneRuleRows,
        readExpectedVisitorRows: repository.readExpectedVisitorRows,
      ),
    );
    stdout.writeln(
      '[ONYX] Supabase: $supabaseUrl '
      '(${serviceKey.isNotEmpty ? 'service key' : 'anon key'})',
    );
  } else {
    stdout.writeln(
      '[ONYX] Supabase: not configured — snapshot persistence disabled.',
    );
  }

  stdout.writeln('[ONYX] Camera worker starting.');
  stdout.writeln('[ONYX] Target: $host:$port  user=$username');
  stdout.writeln('[ONYX] Scope:  client=$clientId  site=$siteId');
  stdout.writeln('[ONYX] Fault channels: ${knownFaultChannels.join(', ')}');
  stdout.writeln(
    '[ONYX] YOLO/FR: ${yoloEndpoint == null ? 'disabled' : yoloEndpoint.toString()}',
  );
  final yoloHttpClient = http.Client();
  final liveSnapshotYoloService = yoloEndpoint == null
      ? null
      : OnyxLiveSnapshotYoloService(
          client: yoloHttpClient,
          endpoint: yoloEndpoint,
          authToken: yoloAuthToken,
        );

  final service = OnyxHikIsapiStreamAwarenessService(
    host: host,
    port: port,
    username: username,
    password: password,
    knownFaultChannels: knownFaultChannels,
    repository: repository,
    proactiveAlertService: proactiveAlertService,
    liveSnapshotYoloService: liveSnapshotYoloService,
    lprService: liveSnapshotYoloService == null
        ? null
        : OnyxLprService(detector: liveSnapshotYoloService),
    onReconnectFailure: (alertSiteId, consecutiveFailures, nextRetryDelay) {
      return Future.wait<void>(<Future<void>>[
        if (repository != null)
          repository.recordCameraWorkerOffline(
            siteId: alertSiteId,
            deviceId: 'hikvision:$host:$port',
            occurredAt: DateTime.now().toUtc(),
            consecutiveFailures: consecutiveFailures,
            nextRetryDelay: nextRetryDelay,
            host: host,
            port: port,
          ),
        _sendCameraWorkerReconnectAlert(
          siteId: alertSiteId,
          host: host,
          port: port,
          consecutiveFailures: consecutiveFailures,
          nextRetryDelay: nextRetryDelay,
        ),
      ]);
    },
  );

  // Subscribe before starting so no events are missed.
  final subscription = service.snapshots.listen(
    (snapshot) {
      try {
        _printSnapshot(snapshot);
      } catch (error) {
        stderr.writeln('[ONYX] Failed to format snapshot: $error');
      }
    },
    onError: (Object error) {
      stderr.writeln('[ONYX] Snapshot stream error: $error');
    },
  );

  await service.start(siteId: siteId, clientId: clientId);
  stdout.writeln('[ONYX] Connected — listening for events.');

  // Handle Ctrl+C gracefully.
  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('\n[ONYX] Shutting down...');
    try {
      await subscription.cancel();
      await service.stop();
      yoloHttpClient.close();
      await proactiveAlertService?.dispose();
    } catch (error) {
      stderr.writeln('[ONYX] Error during shutdown: $error');
    }
    stdout.writeln('[ONYX] Done.');
    exit(0);
  });

  // Keep the process alive — the service owns its own connection/retry loop.
  await Future<void>.delayed(const Duration(days: 36500));
}

/// Prints a one-line summary of [snapshot] to stdout.
///
/// Example:
///   [19:37] CH5: human detected | CH11: videoloss (fault) | perimeter: clear | humans:1 vehicles:0 animals:0
void _printSnapshot(OnyxSiteAwarenessSnapshot snapshot) {
  final now = snapshot.snapshotAt.toLocal();
  final time =
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

  final channelParts = <String>[];
  final sortedChannels = snapshot.channels.keys.toList(growable: false)..sort();
  for (final channelId in sortedChannels) {
    final ch = snapshot.channels[channelId]!;
    final statusLabel = switch (ch.status) {
      OnyxChannelStatusType.active =>
        ch.lastEventType != null ? _eventLabel(ch.lastEventType!) : 'active',
      OnyxChannelStatusType.idle => 'idle',
      OnyxChannelStatusType.videoloss => 'videoloss',
      OnyxChannelStatusType.unknown => 'unknown',
    };
    final faultTag = ch.isFault ? ' (fault)' : '';
    channelParts.add('CH$channelId: $statusLabel$faultTag');
  }

  final perimeterLabel = snapshot.perimeterClear ? 'clear' : 'BREACHED';
  final d = snapshot.detections;
  final detectLabel =
      'humans:${d.humanCount} vehicles:${d.vehicleCount} animals:${d.animalCount}';

  final parts = <String>[
    '[$time]',
    if (channelParts.isNotEmpty) channelParts.join(' | '),
    'perimeter: $perimeterLabel',
    detectLabel,
  ];

  if (snapshot.knownFaults.isNotEmpty) {
    parts.add('faults: ${snapshot.knownFaults.join(',')}');
  }
  if (snapshot.activeAlerts.isNotEmpty) {
    parts.add('alerts: ${snapshot.activeAlerts.length}');
  }

  stdout.writeln(parts.join(' | '));
}

String _eventLabel(OnyxEventType type) {
  return switch (type) {
    OnyxEventType.humanDetected => 'human detected',
    OnyxEventType.vehicleDetected => 'vehicle detected',
    OnyxEventType.animalDetected => 'animal detected',
    OnyxEventType.motionDetected => 'motion detected',
    OnyxEventType.perimeterBreach => 'perimeter breach',
    OnyxEventType.videoloss => 'videoloss',
    OnyxEventType.unknown => 'unknown event',
  };
}
