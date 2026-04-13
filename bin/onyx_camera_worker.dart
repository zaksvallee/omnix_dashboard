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
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:omnix_dashboard/application/onyx_alert_reason_builder.dart';
import 'package:omnix_dashboard/application/onyx_awareness_latency_service.dart';
import 'package:omnix_dashboard/application/onyx_evidence_certificate_service.dart';
import 'package:omnix_dashboard/application/onyx_environment_engine.dart';
import 'package:omnix_dashboard/application/onyx_lpr_service.dart';
import 'package:omnix_dashboard/application/onyx_outcome_feedback_service.dart';
import 'package:omnix_dashboard/application/onyx_power_mode_service.dart';
import 'package:omnix_dashboard/application/onyx_proactive_alert_service.dart';
import 'package:omnix_dashboard/application/onyx_site_profile_service.dart';
import 'package:omnix_dashboard/application/site_awareness/onyx_live_snapshot_yolo_service.dart';
import 'package:omnix_dashboard/application/site_awareness/onyx_site_awareness_snapshot.dart'
    as awareness;
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
  final String? alertKind;
  final String? subjectLabel;
  final String? timeContext;
  final Map<String, Object?>? alertReason;
  final Map<String, Object?>? latency;
  final double? personConfidence;
  final String? powerMode;

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
    this.alertKind,
    this.subjectLabel,
    this.timeContext,
    this.alertReason,
    this.latency,
    this.personConfidence,
    this.powerMode,
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
      'alert_kind': alertKind,
      'subject_label': subjectLabel,
      'time_context': timeContext,
      'alert_reason': alertReason == null
          ? null
          : Map<String, Object?>.from(alertReason!),
      'latency': latency == null ? null : Map<String, Object?>.from(latency!),
      'person_confidence': personConfidence,
      'power_mode': powerMode,
    };
  }
}

class OnyxSiteAwarenessEvent {
  final String eventId;
  final String? siteId;
  final String? clientId;
  final String? cameraId;
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
  final double? personConfidence;
  final Uint8List? snapshotBytes;
  final String? zoneId;
  final String? incidentId;
  final String? certificateId;
  final Map<String, Object?>? alertReason;
  final OnyxLatencyRecord? latencyRecord;
  final bool unknownPerson;
  final bool isKnownFaultChannel;

  const OnyxSiteAwarenessEvent({
    required this.eventId,
    required this.channelId,
    required this.eventType,
    required this.detectedAt,
    required this.rawEventType,
    this.siteId,
    this.clientId,
    this.cameraId,
    this.targetType,
    this.plateNumber,
    this.faceMatchId,
    this.faceMatchName,
    this.faceMatchConfidence,
    this.faceMatchDistance,
    this.personConfidence,
    this.snapshotBytes,
    this.zoneId,
    this.incidentId,
    this.certificateId,
    this.alertReason,
    this.latencyRecord,
    this.unknownPerson = false,
    this.isKnownFaultChannel = false,
  });

  OnyxSiteAwarenessEvent copyWith({
    String? eventId,
    String? siteId,
    String? clientId,
    String? cameraId,
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
    double? personConfidence,
    Uint8List? snapshotBytes,
    String? zoneId,
    String? incidentId,
    String? certificateId,
    Map<String, Object?>? alertReason,
    OnyxLatencyRecord? latencyRecord,
    bool? unknownPerson,
    bool? isKnownFaultChannel,
  }) {
    return OnyxSiteAwarenessEvent(
      eventId: eventId ?? this.eventId,
      siteId: siteId ?? this.siteId,
      clientId: clientId ?? this.clientId,
      cameraId: cameraId ?? this.cameraId,
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
      personConfidence: personConfidence ?? this.personConfidence,
      snapshotBytes: snapshotBytes ?? this.snapshotBytes,
      zoneId: zoneId ?? this.zoneId,
      incidentId: incidentId ?? this.incidentId,
      certificateId: certificateId ?? this.certificateId,
      alertReason: alertReason ?? this.alertReason,
      latencyRecord: latencyRecord ?? this.latencyRecord,
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
      eventId: _defaultAwarenessEventId(
        channelId: channelId.isEmpty ? 'unknown' : channelId,
        eventType: rawEventType,
        detectedAt: detectedAt,
      ),
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

String _defaultAwarenessEventId({
  required String channelId,
  required String eventType,
  required DateTime detectedAt,
}) {
  final normalizedEventType = eventType.trim().isEmpty
      ? 'unknown'
      : eventType.trim();
  return 'EVT-${detectedAt.toUtc().microsecondsSinceEpoch}-${channelId.trim()}-$normalizedEventType';
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
          alertReason: event.alertReason,
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
        alertKind: _activeAlerts[i].alertKind,
        subjectLabel: _activeAlerts[i].subjectLabel,
        timeContext: _activeAlerts[i].timeContext,
        alertReason: _activeAlerts[i].alertReason,
        latency: _activeAlerts[i].latency,
        personConfidence: _activeAlerts[i].personConfidence,
        powerMode: _activeAlerts[i].powerMode,
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
        alertKind: alert.alertKind,
        subjectLabel: alert.subjectLabel,
        timeContext: alert.timeContext,
        alertReason: alert.alertReason,
        latency: alert.latency,
        personConfidence: alert.personConfidence,
        powerMode: alert.powerMode,
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
  return '';
}

bool _isPositiveChannelLabel(String value) {
  final parsed = int.tryParse(value.trim());
  return parsed != null && parsed > 0;
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
      vehicleDescription: (row['vehicle_description'] as String? ?? '').trim(),
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
  final String _supabaseUrl;
  final String _supabaseKey;
  final Duration requestTimeout;
  SupabaseClient _client;
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
  Completer<void>? _reconnectCompleter;
  DateTime? _lastSnapshotPersistAttemptAtUtc;
  DateTime? _lastSuccessfulSnapshotPersistAtUtc;
  DateTime? _firstSnapshotPersistFailureAtUtc;
  DateTime? _lastReconnectAtUtc;
  int _consecutiveSnapshotPersistFailures = 0;

  OnyxSiteAwarenessRepository({
    required String supabaseUrl,
    required String supabaseKey,
    this.requestTimeout = const Duration(seconds: 20),
  }) : _supabaseUrl = supabaseUrl.trim(),
       _supabaseKey = supabaseKey.trim(),
       _client = SupabaseClient(supabaseUrl.trim(), supabaseKey.trim());

  DateTime? get lastSnapshotPersistAttemptAtUtc =>
      _lastSnapshotPersistAttemptAtUtc;
  DateTime? get lastSuccessfulSnapshotPersistAtUtc =>
      _lastSuccessfulSnapshotPersistAtUtc;
  DateTime? get lastReconnectAtUtc => _lastReconnectAtUtc;
  int get consecutiveSnapshotPersistFailures =>
      _consecutiveSnapshotPersistFailures;

  bool isSnapshotPersistenceStale({
    required DateTime nowUtc,
    required Duration staleAfter,
  }) {
    final lastAttemptAtUtc = _lastSnapshotPersistAttemptAtUtc;
    if (lastAttemptAtUtc == null) {
      return false;
    }
    if (nowUtc.difference(lastAttemptAtUtc) > staleAfter) {
      return false;
    }
    final lastSuccessAtUtc = _lastSuccessfulSnapshotPersistAtUtc;
    if (lastSuccessAtUtc != null &&
        nowUtc.difference(lastSuccessAtUtc) <= staleAfter) {
      return false;
    }
    final firstFailureAtUtc = _firstSnapshotPersistFailureAtUtc;
    if (firstFailureAtUtc != null &&
        nowUtc.difference(firstFailureAtUtc) >= staleAfter) {
      return true;
    }
    return _consecutiveSnapshotPersistFailures >= 3;
  }

  Future<void> reconnect({required String reason}) async {
    final activeReconnect = _reconnectCompleter;
    if (activeReconnect != null) {
      await activeReconnect.future;
      return;
    }
    final completer = Completer<void>();
    _reconnectCompleter = completer;
    final previousClient = _client;
    try {
      developer.log(
        '[ONYX] Reconnecting Supabase client. Reason: $reason',
        name: 'OnyxSiteAwarenessRepository',
        level: 900,
      );
      _client = SupabaseClient(_supabaseUrl, _supabaseKey);
      _lastReconnectAtUtc = DateTime.now().toUtc();
      completer.complete();
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      developer.log(
        'Failed to reconnect Supabase client.',
        name: 'OnyxSiteAwarenessRepository',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      rethrow;
    } finally {
      _reconnectCompleter = null;
    }
    try {
      await previousClient.dispose();
    } catch (error, stackTrace) {
      developer.log(
        'Failed to dispose stale Supabase client after reconnect.',
        name: 'OnyxSiteAwarenessRepository',
        error: error,
        stackTrace: stackTrace,
        level: 900,
      );
    }
  }

  Future<void> upsertSnapshot(OnyxSiteAwarenessSnapshot snapshot) async {
    _lastSnapshotPersistAttemptAtUtc = DateTime.now().toUtc();
    try {
      await _runWriteWithReconnect(
        operationLabel:
            'upsert site awareness snapshot for ${snapshot.siteId} at '
            '${snapshot.snapshotAt.toUtc().toIso8601String()}',
        action: (client) =>
            client.from('site_awareness_snapshots').upsert(<String, Object?>{
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
            }, onConflict: 'site_id'),
      );
      _lastSuccessfulSnapshotPersistAtUtc = DateTime.now().toUtc();
      _firstSnapshotPersistFailureAtUtc = null;
      _consecutiveSnapshotPersistFailures = 0;
    } catch (error, stackTrace) {
      final failedAtUtc = DateTime.now().toUtc();
      _firstSnapshotPersistFailureAtUtc ??= failedAtUtc;
      _consecutiveSnapshotPersistFailures += 1;
      developer.log(
        'Failed to upsert site awareness snapshot for ${snapshot.siteId} at '
        '${snapshot.snapshotAt.toUtc().toIso8601String()}. '
        'Consecutive snapshot persist failures: '
        '$_consecutiveSnapshotPersistFailures. Last successful snapshot '
        'write: '
        '${_lastSuccessfulSnapshotPersistAtUtc?.toIso8601String() ?? 'never'}. '
        'Supabase error: ${_supabaseErrorSummary(error)}',
        name: 'OnyxSiteAwarenessRepository',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      rethrow;
    }
  }

  Future<void> _runWriteWithReconnect({
    required String operationLabel,
    required Future<void> Function(SupabaseClient client) action,
  }) async {
    try {
      await action(_client).timeout(requestTimeout);
      return;
    } catch (error, stackTrace) {
      developer.log(
        '[ONYX] Supabase write failed during $operationLabel. '
        '${_supabaseErrorSummary(error)}',
        name: 'OnyxSiteAwarenessRepository',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      await reconnect(reason: '$operationLabel failed');
      try {
        await action(_client).timeout(requestTimeout);
        developer.log(
          '[ONYX] Supabase write recovered after reconnect during '
          '$operationLabel.',
          name: 'OnyxSiteAwarenessRepository',
          level: 900,
        );
      } catch (retryError, retryStackTrace) {
        developer.log(
          '[ONYX] Supabase write retry failed during $operationLabel after '
          'reconnect. ${_supabaseErrorSummary(retryError)}',
          name: 'OnyxSiteAwarenessRepository',
          error: retryError,
          stackTrace: retryStackTrace,
          level: 1000,
        );
        rethrow;
      }
    }
  }

  String _supabaseErrorSummary(Object error) {
    if (error is TimeoutException) {
      return 'Request timed out after ${requestTimeout.inSeconds}s.';
    }
    if (error is SocketException) {
      return 'Socket error: ${error.message}';
    }
    if (error is PostgrestException) {
      final details = error.details?.toString().trim() ?? '';
      final hint = error.hint?.toString().trim() ?? '';
      final parts = <String>[
        if (error.code?.trim().isNotEmpty == true) 'code=${error.code}',
        if (error.message.trim().isNotEmpty) error.message.trim(),
        if (details.isNotEmpty) 'details=$details',
        if (hint.isNotEmpty) 'hint=$hint',
      ];
      return parts.isEmpty ? error.toString() : parts.join(' | ');
    }
    return error.toString();
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

  Future<List<Map<String, dynamic>>> readExpectedVisitorRows(
    String siteId,
  ) async {
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
      await _runWriteWithReconnect(
        operationLabel:
            'record occupancy signal for $normalizedSiteId channel '
            '$normalizedChannelId',
        action: (client) =>
            client.from('site_occupancy_sessions').upsert(<String, Object?>{
              'site_id': normalizedSiteId,
              'session_date': sessionDate,
              'peak_detected': peakDetected,
              'last_detection_at': detectedAt.toUtc().toIso8601String(),
              'channels_with_detections': updatedChannels,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }, onConflict: 'site_id,session_date'),
      );
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
      final ownerName = registryEntry?.ownerName.trim().isNotEmpty == true
          ? registryEntry!.ownerName.trim()
          : 'Unknown';
      final eventType = normalizedPlate.isEmpty
          ? 'detected'
          : recentPresence != null &&
                detectedAt.toUtc().difference(
                      recentPresence.occurredAt.toUtc(),
                    ) <
                    const Duration(minutes: 30)
          ? 'on_site'
          : 'arrived';
      await _runWriteWithReconnect(
        operationLabel:
            'record vehicle detection for $normalizedSiteId plate '
            '${normalizedPlate.isEmpty ? 'UNKNOWN' : normalizedPlate}',
        action: (client) =>
            client.from('site_vehicle_presence').insert(<String, Object?>{
              'site_id': normalizedSiteId,
              'plate_number': normalizedPlate.isEmpty
                  ? 'UNKNOWN'
                  : normalizedPlate,
              'owner_name': ownerName,
              'event_type': eventType,
              'channel_id': channelId > 0 ? channelId : null,
              'zone_name': zoneName.trim().isEmpty ? null : zoneName.trim(),
              'occurred_at': detectedAt.toUtc().toIso8601String(),
            }),
      );
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
      await _runWriteWithReconnect(
        operationLabel: 'record camera worker offline event for $siteId',
        action: (client) =>
            client.from('site_alarm_events').insert(<String, Object?>{
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
            }),
      );
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
  static const Duration _yoloStartupGracePeriod = Duration(seconds: 30);
  static const Duration _yoloHealthRetryDelay = Duration(seconds: 10);
  static const Duration _yoloHealthRecheckInterval = Duration(seconds: 30);
  static const int _yoloHealthFailureThreshold = 3;

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
  final OnyxEvidenceCertificateService? _evidenceCertificateService;
  final OnyxAlertReasonBuilder _alertReasonBuilder =
      const OnyxAlertReasonBuilder();
  final OnyxPowerModeService? _powerModeService;
  final OnyxEnvironmentEngine? _environmentEngine;

  final StreamController<OnyxSiteAwarenessSnapshot> _snapshotController =
      StreamController<OnyxSiteAwarenessSnapshot>.broadcast();

  StreamSubscription<List<int>>? _streamSubscription;
  StreamSubscription<OnyxProactiveAlertDecision>? _proactiveAlertSubscription;
  Timer? _publishTimer;
  Timer? _heartbeatTimer;
  Timer? _supabaseWatchdogTimer;
  Timer? _yoloHealthTimer;
  OnyxSiteAwarenessProjector? _projector;
  OnyxSiteAwarenessSnapshot? _latestSnapshot;
  bool _isConnected = false;
  bool _running = false;
  bool _disconnectAlertSent = false;
  bool _isYoloHealthy = false;
  bool _yoloHealthCheckInFlight = false;
  DateTime? _yoloStartupGraceUntilUtc;
  int _generation = 0;
  String _siteId = '';
  String _clientId = '';
  DateTime? _lastStreamEventAtUtc;
  final Map<String, Map<String, Object?>> _pendingAlertReasonsByDetectionKey =
      <String, Map<String, Object?>>{};
  final Map<String, OnyxLatencyRecord> _pendingLatencyByDetectionKey =
      <String, OnyxLatencyRecord>{};
  final Map<String, double> _pendingConfidenceByDetectionKey =
      <String, double>{};
  OnyxPowerMode _currentPowerMode = OnyxPowerMode.normal;

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
    OnyxEvidenceCertificateService? evidenceCertificateService,
    OnyxPowerModeService? powerModeService,
    OnyxEnvironmentEngine? environmentEngine,
  }) : _client = client ?? _buildIsapiHttpClient(),
       _repository = repository,
       _proactiveAlertService = proactiveAlertService,
       _clock = clock ?? DateTime.now,
       _sleep = sleep ?? Future<void>.delayed,
       _liveSnapshotYoloService = liveSnapshotYoloService,
       _lprService = lprService,
       _evidenceCertificateService = evidenceCertificateService,
       _powerModeService = powerModeService,
       _environmentEngine = environmentEngine;

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

  Uri get _systemStatusUri =>
      Uri(scheme: 'http', host: host, port: port, path: '/ISAPI/System/status');

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
      final alertReason = _alertReasonForDecision(decision);
      final alertLatency = _latencyRecordForDecision(decision);
      final alertConfidence = _confidenceForDecision(decision);
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
          alertKind: decision.telegramAlertKind.name,
          subjectLabel: decision.telegramSubjectLabel,
          timeContext: decision.withinAlertWindow ? 'after_hours' : 'daytime',
          alertReason: alertReason,
          latency: alertLatency?.toJsonMap(),
          personConfidence: alertConfidence,
          powerMode: _currentPowerMode.name,
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
    _yoloStartupGraceUntilUtc = _clock().toUtc().add(_yoloStartupGracePeriod);
    _startYoloHealthMonitor(_generation);
    _schedulePublishTimer();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      unawaited(_sendKeepaliveHeartbeat(_generation));
    });
    _supabaseWatchdogTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      unawaited(_runSupabaseWatchdog(_generation));
    });
    final powerModeService = _powerModeService;
    if (powerModeService != null) {
      unawaited(powerModeService.start());
    }
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
    _supabaseWatchdogTimer?.cancel();
    _supabaseWatchdogTimer = null;
    _yoloHealthTimer?.cancel();
    _yoloHealthTimer = null;
    final powerModeService = _powerModeService;
    if (powerModeService != null) {
      await powerModeService.stop();
    }
    _isYoloHealthy = false;
    _yoloHealthCheckInFlight = false;
    _yoloStartupGraceUntilUtc = null;
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

  void _startYoloHealthMonitor(int generation) {
    _yoloHealthTimer?.cancel();
    _yoloHealthTimer = null;
    _yoloHealthCheckInFlight = false;
    final liveSnapshotYoloService = _liveSnapshotYoloService;
    if (liveSnapshotYoloService == null ||
        !liveSnapshotYoloService.isConfigured) {
      _isYoloHealthy = false;
      return;
    }
    _isYoloHealthy = false;
    unawaited(_recheckYoloHealth(generation));
    _yoloHealthTimer = Timer.periodic(_yoloHealthRecheckInterval, (_) {
      unawaited(_recheckYoloHealth(generation));
    });
  }

  void _schedulePublishTimer() {
    _publishTimer?.cancel();
    _publishTimer = Timer.periodic(_publishIntervalForCurrentMode, (_) {
      _publishProjectedSnapshot();
    });
  }

  Duration get _publishIntervalForCurrentMode {
    return switch (_currentPowerMode) {
      OnyxPowerMode.normal => publishInterval,
      OnyxPowerMode.degraded => Duration(
        seconds: math.max(10, publishInterval.inSeconds ~/ 2),
      ),
      OnyxPowerMode.threat => const Duration(seconds: 5),
    };
  }

  bool get _isThreatMode => _currentPowerMode == OnyxPowerMode.threat;

  bool _isPriorityChannel(String channelId) {
    final zone = _projector?.cameraZones[channelId.trim()];
    if (zone == null) {
      return false;
    }
    final zoneType = zone.zoneType.trim().toLowerCase();
    return zone.isPerimeter ||
        zoneType.contains('perimeter') ||
        zoneType.contains('semi_perimeter') ||
        zoneType.contains('semi-perimeter');
  }

  Future<OnyxPowerHealthSnapshot> _readPowerHealthSnapshot() async {
    final projector = _projector;
    final channels =
        projector?.snapshot().channels ?? const <String, OnyxChannelStatus>{};
    final totalCameraCount = math.max(
      projector?.cameraZones.length ?? 0,
      channels.length,
    );
    final offlineCameraCount = channels.values
        .where((status) => status.status == OnyxChannelStatusType.videoloss)
        .length;
    return OnyxPowerHealthSnapshot(
      totalCameraCount: totalCameraCount,
      offlineCameraCount: offlineCameraCount,
      dvrReachable:
          _isConnected ||
          (_lastStreamEventAtUtc != null &&
              _clock().toUtc().difference(_lastStreamEventAtUtc!) <
                  const Duration(seconds: 75)),
      syntheticGuardConfigured: _envBool(
        'ONYX_SYNTHETIC_GUARD_AUTO_ENABLE',
        fallback: false,
      ),
      siteName: _siteId,
    );
  }

  Future<OnyxPowerHealthSnapshot> readPowerHealthSnapshot() {
    return _readPowerHealthSnapshot();
  }

  Future<void> _handlePowerModeChange(OnyxPowerModeChange change) async {
    _currentPowerMode = change.mode;
    _schedulePublishTimer();
    switch (change.mode) {
      case OnyxPowerMode.normal:
        developer.log(
          '[ONYX] Power mode: NORMAL — standard monitoring active',
          name: 'OnyxHikIsapiStream',
        );
        break;
      case OnyxPowerMode.degraded:
        developer.log(
          '[ONYX] Power mode: DEGRADED — priority monitoring active',
          name: 'OnyxHikIsapiStream',
          level: 900,
        );
        break;
      case OnyxPowerMode.threat:
        developer.log(
          '[ONYX] Power mode: THREAT — aggressive monitoring active',
          name: 'OnyxHikIsapiStream',
          level: 1000,
        );
        if (_envBool('ONYX_SYNTHETIC_GUARD_AUTO_ENABLE', fallback: false)) {
          developer.log(
            '[ONYX] Synthetic Guard auto-enabled for threat mode.',
            name: 'OnyxHikIsapiStream',
            level: 900,
          );
        }
        await _sendCameraWorkerThreatModeAlert(siteId: _siteId);
        break;
    }
  }

  Future<void> handlePowerModeChange(OnyxPowerModeChange change) {
    return _handlePowerModeChange(change);
  }

  Future<void> _recheckYoloHealth(int generation) async {
    if (_yoloHealthCheckInFlight || !_running || generation != _generation) {
      return;
    }
    final liveSnapshotYoloService = _liveSnapshotYoloService;
    if (liveSnapshotYoloService == null ||
        !liveSnapshotYoloService.isConfigured) {
      _isYoloHealthy = false;
      return;
    }
    _yoloHealthCheckInFlight = true;
    try {
      for (
        var attempt = 1;
        attempt <= _yoloHealthFailureThreshold;
        attempt += 1
      ) {
        final ready = await _isYoloReady(liveSnapshotYoloService);
        if (!_running || generation != _generation) {
          return;
        }
        if (ready) {
          if (!_isYoloHealthy) {
            _isYoloHealthy = true;
            developer.log(
              '[ONYX] YOLO recovered — resuming enrichment',
              name: 'OnyxHikIsapiStream',
            );
          }
          return;
        }
        if (attempt < _yoloHealthFailureThreshold) {
          developer.log(
            '[ONYX] YOLO unhealthy check $attempt/3 — waiting before marking dead',
            name: 'OnyxHikIsapiStream',
            level: 900,
          );
          await _sleep(_yoloHealthRetryDelay);
        }
      }
      _isYoloHealthy = false;
    } finally {
      _yoloHealthCheckInFlight = false;
    }
  }

  Future<bool> _isYoloReady(
    OnyxLiveSnapshotYoloService liveSnapshotYoloService,
  ) async {
    final healthEndpoint = liveSnapshotYoloService.endpoint.replace(
      path: '/health',
      query: null,
      fragment: null,
    );
    try {
      final response = await liveSnapshotYoloService.client
          .get(
            healthEndpoint,
            headers: <String, String>{
              'Accept': 'application/json',
              if (liveSnapshotYoloService.authToken.trim().isNotEmpty)
                'Authorization':
                    'Bearer ${liveSnapshotYoloService.authToken.trim()}',
            },
          )
          .timeout(liveSnapshotYoloService.requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return false;
      }
      final payload = decoded.cast<Object?, Object?>();
      return payload['ready'] == true ||
          (payload['status'] ?? '').toString().trim().toLowerCase() == 'ready';
    } catch (_) {
      return false;
    }
  }

  Future<List<int>?> fetchSnapshotBytes(String channelId) async {
    final rtspSnapshotBytes = await _liveSnapshotYoloService?.fetchRtspFrame(
      channelId.trim(),
    );
    if (rtspSnapshotBytes != null && rtspSnapshotBytes.isNotEmpty) {
      developer.log(
        '[ONYX] FR: Using HD frame from RTSP for CH${channelId.trim()} '
        '(${rtspSnapshotBytes.length} bytes).',
        name: 'OnyxHikIsapiStream',
      );
      return rtspSnapshotBytes;
    }
    try {
      developer.log(
        '[ONYX] FR: Falling back to ISAPI snapshot for CH${channelId.trim()}.',
        name: 'OnyxHikIsapiStream',
        level: 800,
      );
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
      final receivedAtUtc = _clock().toUtc();
      final parsedEvent = OnyxSiteAwarenessEvent.fromAlertXml(
        payload,
        knownFaultChannels: knownFaultChannels.toSet(),
        clock: _clock,
      );
      var event = parsedEvent.copyWith(
        siteId: _siteId,
        clientId: _clientId,
        cameraId: parsedEvent.channelId.trim(),
        latencyRecord: OnyxLatencyRecord(
          alertId: '',
          eventId: parsedEvent.eventId,
          siteId: _siteId,
          clientId: _clientId,
          dvrEventAt: receivedAtUtc,
        ),
      );
      if (event.channelId.trim() == '0') {
        developer.log(
          '[ONYX] Ignoring ghost CH0 event from Hikvision alert stream.',
          name: 'OnyxHikIsapiStream',
          level: 800,
        );
        return;
      }
      if (event.eventType == OnyxEventType.humanDetected) {
        final channelId = event.channelId.trim();
        if (_currentPowerMode == OnyxPowerMode.degraded &&
            !_isPriorityChannel(channelId)) {
          developer.log(
            '[ONYX] Degraded power mode: skipping non-priority human detection on CH$channelId.',
            name: 'OnyxHikIsapiStream',
            level: 800,
          );
          event = event.copyWith(eventType: OnyxEventType.motionDetected);
        }
        if (channelId.isNotEmpty &&
            channelId != 'unknown' &&
            event.eventType == OnyxEventType.humanDetected &&
            (event.snapshotBytes == null || event.snapshotBytes!.isEmpty)) {
          final snapshotBytes = await fetchSnapshotBytes(channelId);
          if (snapshotBytes != null && snapshotBytes.isNotEmpty) {
            event = event.copyWith(
              snapshotBytes: Uint8List.fromList(snapshotBytes),
              latencyRecord: _withSnapshotLatency(
                event.latencyRecord,
                _clock().toUtc(),
              ),
            );
          }
        }
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
    event = _attachAlertReason(event);
    final projector = _projector;
    if (projector == null) {
      return;
    }
    _cachePendingAlertReason(event);
    final snapshot = projector.ingest(event);
    _latestSnapshot = snapshot;
    final repository = _repository;
    if (repository != null && event.eventType == OnyxEventType.humanDetected) {
      unawaited(_persistOccupancy(repository, event));
    }
    if (repository != null &&
        event.eventType == OnyxEventType.vehicleDetected) {
      unawaited(_persistVehiclePresence(repository, event));
    }
    final proactiveAlertService = _proactiveAlertService;
    if (proactiveAlertService != null &&
        (event.eventType == OnyxEventType.humanDetected ||
            event.eventType == OnyxEventType.vehicleDetected)) {
      if (event.eventType == OnyxEventType.humanDetected &&
          (event.faceMatchId ?? '').trim().isNotEmpty &&
          !_isThreatMode) {
        developer.log(
          '[ONYX] Suppressing proactive alert for known person '
          '${event.faceMatchName ?? event.faceMatchId} on CH${event.channelId}.',
          name: 'OnyxHikIsapiStream',
        );
      } else {
        final zone = projector.cameraZones[event.channelId];
        if (_currentPowerMode == OnyxPowerMode.degraded &&
            !(zone?.isPerimeter ?? false) &&
            !((zone?.zoneType ?? '').toLowerCase().contains('perimeter'))) {
          developer.log(
            '[ONYX] Degraded power mode: skipping proactive alert evaluation for non-priority channel ${event.channelId}.',
            name: 'OnyxHikIsapiStream',
            level: 800,
          );
        } else {
          final channelId = int.tryParse(event.channelId.trim()) ?? 0;
          if (channelId <= 0) {
            developer.log(
              '[ONYX] Skipping proactive alert evaluation for invalid channel ${event.channelId}.',
              name: 'OnyxHikIsapiStream',
              level: 800,
            );
            return;
          }
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
    }
    if (event.shouldPublishImmediately || _isThreatMode) {
      _emitSnapshot(snapshot);
    }
  }

  Future<OnyxSiteAwarenessEvent> _enrichHumanDetectionEvent(
    OnyxSiteAwarenessEvent event,
  ) async {
    final liveSnapshotYoloService = _liveSnapshotYoloService;
    // ignore: avoid_print
    print(
      '[ONYX-DEBUG] _enrichHumanDetectionEvent called for CH${event.channelId}',
    );
    // ignore: avoid_print
    print(
      '[ONYX-DEBUG] liveSnapshotYoloService configured: '
      '${liveSnapshotYoloService?.isConfigured}',
    );
    if (liveSnapshotYoloService == null ||
        !liveSnapshotYoloService.isConfigured ||
        !_isYoloHealthy) {
      if (_isThreatMode) {
        developer.log(
          '[ONYX] Threat mode active — bypassing YOLO health suppression on CH${event.channelId}.',
          name: 'OnyxHikIsapiStream',
          level: 900,
        );
        return event.copyWith(
          siteId: _siteId,
          clientId: _clientId,
          cameraId: event.channelId.trim(),
          zoneId: _projector?.cameraZones[event.channelId.trim()]?.zoneName,
        );
      }
      if (_shouldAllowUnverifiedHumanAlert(liveSnapshotYoloService)) {
        developer.log(
          '[ONYX] Human detected (unverified) on CH${event.channelId} during YOLO startup grace.',
          name: 'OnyxHikIsapiStream',
          level: 800,
        );
        return event;
      }
      developer.log(
        '[ONYX] Alert suppressed — YOLO did not confirm human on CH${event.channelId}',
        name: 'OnyxHikIsapiStream',
        level: 800,
      );
      return event.copyWith(eventType: OnyxEventType.motionDetected);
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
    try {
      // ignore: avoid_print
      print('[ONYX-DEBUG] Attempting snapshot for CH$channelId...');
      developer.log(
        '[ONYX] Capturing snapshot from CH$snapshotChannelId for live FR...',
        name: 'OnyxHikIsapiStream',
      );
      final snapshotBytes =
          event.snapshotBytes != null && event.snapshotBytes!.isNotEmpty
          ? event.snapshotBytes!
          : await fetchSnapshotBytes(channelId);
      final snapshotAtUtc = _clock().toUtc();
      // ignore: avoid_print
      print(
        '[ONYX-DEBUG] Snapshot result: ${snapshotBytes?.length ?? 0} bytes',
      );
      if (snapshotBytes == null || snapshotBytes.isEmpty) {
        developer.log(
          '[ONYX] FR snapshot capture failed for CH$snapshotChannelId.',
          name: 'OnyxHikIsapiStream',
          level: 900,
        );
        if (_isThreatMode) {
          return event.copyWith(
            siteId: _siteId,
            clientId: _clientId,
            cameraId: channelId,
            latencyRecord: _withSnapshotLatency(
              event.latencyRecord,
              snapshotAtUtc,
            ),
            zoneId: _projector?.cameraZones[channelId]?.zoneName,
          );
        }
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
      final yoloAtUtc = _clock().toUtc();
      // ignore: avoid_print
      print('[ONYX-DEBUG] YOLO result: $result');
      if (result == null) {
        developer.log(
          '[ONYX] Alert suppressed — YOLO did not confirm human on CH$channelId',
          name: 'OnyxHikIsapiStream',
          level: 800,
        );
        return event.copyWith(eventType: OnyxEventType.motionDetected);
      }
      final primaryLabel = (result.primaryLabel ?? '').trim().toLowerCase();
      final personConfidence = result.personConfidence;
      final thresholdDecision = await _environmentEngine?.getThresholdDecision(
        _siteId,
        zone?.zoneName ?? '',
      );
      final effectiveThreshold =
          thresholdDecision?.adaptedThreshold ??
          switch (_currentPowerMode) {
            OnyxPowerMode.normal => 0.55,
            OnyxPowerMode.degraded => 0.45,
            OnyxPowerMode.threat => 0.40,
          };
      if (thresholdDecision != null) {
        developer.log(
          '[ONYX] Threshold for CH$channelId zone ${zone?.zoneName ?? 'unknown'}: '
          'base=${thresholdDecision.baseThreshold.toStringAsFixed(2)} '
          'power=${thresholdDecision.powerAdjustment >= 0 ? '+' : ''}${thresholdDecision.powerAdjustment.toStringAsFixed(2)} '
          'zone=${thresholdDecision.zoneAdjustment >= 0 ? '+' : ''}${thresholdDecision.zoneAdjustment.toStringAsFixed(2)} '
          'adapted=${thresholdDecision.adaptedThreshold.toStringAsFixed(2)} '
          'mode=${thresholdDecision.powerMode.name}',
          name: 'OnyxHikIsapiStream',
        );
      } else {
        developer.log(
          '[ONYX] Threshold for CH$channelId zone ${zone?.zoneName ?? 'unknown'}: '
          'base=0.55 power=${_currentPowerMode == OnyxPowerMode.normal
              ? '+0.00'
              : _currentPowerMode == OnyxPowerMode.degraded
              ? '-0.10'
              : '-0.15'} '
          'zone=+0.00 adapted=${effectiveThreshold.toStringAsFixed(2)} '
          'mode=${_currentPowerMode.name}',
          name: 'OnyxHikIsapiStream',
        );
      }
      if (!result.personDetected ||
          personConfidence == null ||
          personConfidence < effectiveThreshold) {
        if (primaryLabel == 'animal') {
          developer.log(
            '[ONYX] Animal detected on CH$channelId — suppressed.',
            name: 'OnyxHikIsapiStream',
          );
          return event.copyWith(eventType: OnyxEventType.animalDetected);
        }
        developer.log(
          '[ONYX] Alert suppressed — YOLO did not confirm human on CH$channelId',
          name: 'OnyxHikIsapiStream',
          level: 800,
        );
        if (_isThreatMode) {
          return event.copyWith(
            siteId: _siteId,
            clientId: _clientId,
            cameraId: channelId,
            personConfidence: personConfidence,
            snapshotBytes: Uint8List.fromList(snapshotBytes),
            zoneId: zone?.zoneName,
          );
        }
        return event.copyWith(eventType: OnyxEventType.motionDetected);
      }
      if (primaryLabel == 'animal') {
        developer.log(
          '[ONYX] Animal detected on CH$channelId — suppressed.',
          name: 'OnyxHikIsapiStream',
        );
        return event.copyWith(eventType: OnyxEventType.animalDetected);
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
        final label = (person?.displayName ?? '').trim().isNotEmpty
            ? person!.displayName.trim()
            : faceMatchId;
        developer.log(
          '[ONYX] FR match: $label detected on CH$channelId '
          '(confidence ${(result.faceConfidence ?? result.personConfidence ?? 0).toStringAsFixed(2)}, '
          'distance ${(result.faceDistance ?? 0).toStringAsFixed(2)})',
          name: 'OnyxHikIsapiStream',
        );
        final enrichedEvent = event.copyWith(
          siteId: _siteId,
          clientId: _clientId,
          cameraId: channelId,
          faceMatchId: faceMatchId,
          faceMatchName: person?.displayName,
          faceMatchConfidence: result.faceConfidence ?? result.personConfidence,
          faceMatchDistance: result.faceDistance,
          personConfidence: result.personConfidence,
          snapshotBytes: Uint8List.fromList(snapshotBytes),
          zoneId: zone?.zoneName,
          latencyRecord: _withYoloLatency(
            _withSnapshotLatency(event.latencyRecord, snapshotAtUtc),
            yoloAtUtc,
          ),
          unknownPerson: false,
        );
        return _attachEvidenceCertificateIfRequired(enrichedEvent);
      }
      if (result.personDetected) {
        developer.log(
          '[ONYX] FR: Unknown person on CH$channelId '
          '(confidence ${(result.personConfidence ?? 0).toStringAsFixed(2)})',
          name: 'OnyxHikIsapiStream',
        );
        final enrichedEvent = event.copyWith(
          siteId: _siteId,
          clientId: _clientId,
          cameraId: channelId,
          unknownPerson: true,
          personConfidence: result.personConfidence,
          faceMatchConfidence: result.personConfidence,
          snapshotBytes: Uint8List.fromList(snapshotBytes),
          zoneId: zone?.zoneName,
          latencyRecord: _withYoloLatency(
            _withSnapshotLatency(event.latencyRecord, snapshotAtUtc),
            yoloAtUtc,
          ),
        );
        return _attachEvidenceCertificateIfRequired(enrichedEvent);
      }
      developer.log(
        '[ONYX] FR: No person confirmed in CH$channelId snapshot '
        '(${(result.personConfidence ?? 0).toStringAsFixed(2)}).',
        name: 'OnyxHikIsapiStream',
      );
      developer.log(
        '[ONYX] Alert suppressed — YOLO did not confirm human on CH$channelId',
        name: 'OnyxHikIsapiStream',
        level: 800,
      );
      if (_isThreatMode) {
        return event.copyWith(
          siteId: _siteId,
          clientId: _clientId,
          cameraId: channelId,
          personConfidence: result.personConfidence,
          snapshotBytes: Uint8List.fromList(snapshotBytes),
          latencyRecord: _withYoloLatency(
            _withSnapshotLatency(event.latencyRecord, snapshotAtUtc),
            yoloAtUtc,
          ),
          zoneId: zone?.zoneName,
        );
      }
      return event.copyWith(eventType: OnyxEventType.motionDetected);
    } catch (error, stackTrace) {
      // ignore: avoid_print
      print('[ONYX-DEBUG] FR pipeline error on CH$channelId: $error');
      developer.log(
        '[ONYX] FR pipeline error on CH$channelId: $error',
        name: 'OnyxHikIsapiStream',
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
      if (_isThreatMode) {
        return event.copyWith(
          siteId: _siteId,
          clientId: _clientId,
          cameraId: channelId,
          zoneId: _projector?.cameraZones[channelId]?.zoneName,
        );
      }
      return event;
    }
  }

  Future<OnyxSiteAwarenessEvent> _attachEvidenceCertificateIfRequired(
    OnyxSiteAwarenessEvent event,
  ) async {
    if (!_requiresEvidenceCertificate(event)) {
      return event;
    }
    final service = _evidenceCertificateService;
    if (service == null) {
      return event;
    }
    try {
      final certificate = await service.generateCertificate(
        _toSharedAwarenessEvent(event),
      );
      return event.copyWith(
        certificateId: certificate.certificateId,
        incidentId: certificate.incidentId,
      );
    } catch (error, stackTrace) {
      developer.log(
        '[ONYX] Evidence certificate generation failed for ${event.eventId}: $error',
        name: 'OnyxHikIsapiStream',
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
      return event;
    }
  }

  bool _requiresEvidenceCertificate(OnyxSiteAwarenessEvent event) {
    if (event.eventType != OnyxEventType.humanDetected) {
      return false;
    }
    final faceMatchId = (event.faceMatchId ?? '').trim().toUpperCase();
    if (faceMatchId.contains('_RESIDENT_')) {
      return false;
    }
    return (event.siteId ?? '').trim().isNotEmpty &&
        (event.clientId ?? '').trim().isNotEmpty &&
        (event.cameraId ?? '').trim().isNotEmpty;
  }

  awareness.OnyxSiteAwarenessEvent _toSharedAwarenessEvent(
    OnyxSiteAwarenessEvent event,
  ) {
    return awareness.OnyxSiteAwarenessEvent(
      eventId: event.eventId,
      siteId: event.siteId,
      clientId: event.clientId,
      cameraId: event.cameraId,
      channelId: event.channelId,
      eventType: awareness.OnyxEventType.values.byName(event.eventType.name),
      detectedAt: event.detectedAt,
      rawEventType: event.rawEventType,
      targetType: event.targetType,
      plateNumber: event.plateNumber,
      faceMatchId: event.faceMatchId,
      faceMatchName: event.faceMatchName,
      faceMatchConfidence: event.faceMatchConfidence,
      faceMatchDistance: event.faceMatchDistance,
      personConfidence: event.personConfidence,
      snapshotBytes: event.snapshotBytes,
      zoneId: event.zoneId,
      incidentId: event.incidentId,
      certificateId: event.certificateId,
      alertReason: event.alertReason,
      latencyRecord: event.latencyRecord,
      unknownPerson: event.unknownPerson,
      isKnownFaultChannel: event.isKnownFaultChannel,
    );
  }

  OnyxSiteAwarenessEvent _attachAlertReason(OnyxSiteAwarenessEvent event) {
    if ((event.alertReason ?? const <String, Object?>{}).isNotEmpty) {
      return event;
    }
    if (event.eventType != OnyxEventType.humanDetected &&
        event.eventType != OnyxEventType.vehicleDetected &&
        event.eventType != OnyxEventType.perimeterBreach) {
      return event;
    }
    final reason = _alertReasonBuilder.buildReason(
      _toSharedAwarenessEvent(event),
    );
    return event.copyWith(alertReason: reason.toJsonMap());
  }

  void _cachePendingAlertReason(OnyxSiteAwarenessEvent event) {
    if (event.eventType != OnyxEventType.humanDetected &&
        event.eventType != OnyxEventType.vehicleDetected) {
      return;
    }
    final reason = event.alertReason;
    if (reason == null || reason.isEmpty) {
      return;
    }
    _prunePendingAlertReasons(event.detectedAt);
    _pendingAlertReasonsByDetectionKey[_alertReasonCacheKey(
      channelId: event.channelId,
      detectedAt: event.detectedAt,
    )] = Map<String, Object?>.from(
      reason,
    );
    final latency = event.latencyRecord;
    if (latency != null) {
      _pendingLatencyByDetectionKey[_alertReasonCacheKey(
            channelId: event.channelId,
            detectedAt: event.detectedAt,
          )] =
          latency;
    }
    final confidence = event.personConfidence;
    if (confidence != null) {
      _pendingConfidenceByDetectionKey[_alertReasonCacheKey(
            channelId: event.channelId,
            detectedAt: event.detectedAt,
          )] =
          confidence;
    }
  }

  Map<String, Object?> _alertReasonForDecision(
    OnyxProactiveAlertDecision decision,
  ) {
    final key = _alertReasonCacheKey(
      channelId: '${decision.channelId}',
      detectedAt: decision.detectedAt,
    );
    final reason = Map<String, Object?>.from(
      _pendingAlertReasonsByDetectionKey.remove(key) ??
          const <String, Object?>{},
    );
    final signals = _stringListFromReason(reason['signals']);
    if (decision.isLoitering) {
      signals.add('Presence for ${decision.loiterMinutes} minutes');
    }
    reason['signals'] = signals.toList(growable: false);
    final rules = _stringListFromReason(reason['rules_fired']);
    final zoneType = decision.zoneType.trim().toLowerCase();
    if ((zoneType.contains('semi-perimeter') ||
            zoneType.contains('semi_perimeter')) &&
        !rules.contains('Semi-perimeter zone activity')) {
      rules.add('Semi-perimeter zone activity');
    } else if (zoneType.contains('perimeter') &&
        !rules.contains('Perimeter zone violation')) {
      rules.add('Perimeter zone violation');
    }
    reason['rules_fired'] = rules.toList(growable: false);
    if ((reason['headline']?.toString().trim() ?? '').isEmpty) {
      reason['headline'] = decision.telegramAlertKind.name;
    }
    if ((reason['context_note']?.toString().trim() ?? '').isEmpty) {
      reason['context_note'] = decision.withinAlertWindow
          ? 'Detected outside active hours'
          : 'Detected during active hours';
    }
    return reason;
  }

  OnyxLatencyRecord? _latencyRecordForDecision(
    OnyxProactiveAlertDecision decision,
  ) {
    final key = _alertReasonCacheKey(
      channelId: '${decision.channelId}',
      detectedAt: decision.detectedAt,
    );
    final record = _pendingLatencyByDetectionKey.remove(key);
    if (record == null) {
      return null;
    }
    return record.copyWith(
      alertId:
          '${decision.siteId}:${decision.channelId}:${decision.detectedAt.microsecondsSinceEpoch}:${decision.isLoitering ? 'loiter' : 'motion'}:${decision.isSequence ? 'sequence' : 'single'}',
      siteId: decision.siteId.trim().isEmpty ? _siteId : decision.siteId.trim(),
      clientId: _clientId,
    );
  }

  double? _confidenceForDecision(OnyxProactiveAlertDecision decision) {
    final key = _alertReasonCacheKey(
      channelId: '${decision.channelId}',
      detectedAt: decision.detectedAt,
    );
    return _pendingConfidenceByDetectionKey.remove(key);
  }

  List<String> _stringListFromReason(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: true);
  }

  String _alertReasonCacheKey({
    required String channelId,
    required DateTime detectedAt,
  }) {
    return '${channelId.trim()}:${detectedAt.toUtc().microsecondsSinceEpoch}';
  }

  void _prunePendingAlertReasons(DateTime nowUtc) {
    final cutoffMicros = nowUtc
        .toUtc()
        .subtract(detectionWindow)
        .microsecondsSinceEpoch;
    _pendingAlertReasonsByDetectionKey.removeWhere((key, _) {
      final timestampPart = key.split(':').last;
      final micros = int.tryParse(timestampPart);
      final shouldRemove = micros == null || micros < cutoffMicros;
      if (shouldRemove) {
        _pendingLatencyByDetectionKey.remove(key);
        _pendingConfidenceByDetectionKey.remove(key);
      }
      return shouldRemove;
    });
  }

  OnyxLatencyRecord? _withSnapshotLatency(
    OnyxLatencyRecord? record,
    DateTime snapshotAtUtc,
  ) {
    if (record == null) {
      return null;
    }
    return record.copyWith(snapshotAt: snapshotAtUtc.toUtc());
  }

  OnyxLatencyRecord? _withYoloLatency(
    OnyxLatencyRecord? record,
    DateTime yoloAtUtc,
  ) {
    if (record == null) {
      return null;
    }
    return record.copyWith(yoloAt: yoloAtUtc.toUtc());
  }

  bool _shouldAllowUnverifiedHumanAlert(
    OnyxLiveSnapshotYoloService? liveSnapshotYoloService,
  ) {
    if (liveSnapshotYoloService == null ||
        !liveSnapshotYoloService.isConfigured ||
        _isYoloHealthy) {
      return false;
    }
    final graceUntilUtc = _yoloStartupGraceUntilUtc;
    return graceUntilUtc != null && _clock().toUtc().isBefore(graceUntilUtc);
  }

  Future<OnyxSiteAwarenessEvent> _enrichVehicleDetectionEvent(
    OnyxSiteAwarenessEvent event,
  ) async {
    final lprService = _lprService;
    if (lprService == null || !lprService.isConfigured || !_isYoloHealthy) {
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
        'Failed to persist site awareness snapshot for ${snapshot.siteId} at '
        '${snapshot.snapshotAt.toUtc().toIso8601String()}. Last successful '
        'Supabase snapshot write: '
        '${repository.lastSuccessfulSnapshotPersistAtUtc?.toIso8601String() ?? 'never'}.',
        name: 'OnyxHikIsapiStream',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    }
  }

  Future<void> _runSupabaseWatchdog(int generation) async {
    final repository = _repository;
    if (!_running ||
        generation != _generation ||
        !_isConnected ||
        repository == null) {
      return;
    }
    final nowUtc = _clock().toUtc();
    final staleAfter = Duration(
      seconds: math.max(_publishIntervalForCurrentMode.inSeconds * 4, 180),
    );
    if (!repository.isSnapshotPersistenceStale(
      nowUtc: nowUtc,
      staleAfter: staleAfter,
    )) {
      return;
    }
    final lastReconnectAtUtc = repository.lastReconnectAtUtc;
    if (lastReconnectAtUtc != null &&
        nowUtc.difference(lastReconnectAtUtc) < const Duration(minutes: 1)) {
      return;
    }
    developer.log(
      '[ONYX] Supabase snapshot persistence is stale while the camera stream '
      'is connected. Last success: '
      '${repository.lastSuccessfulSnapshotPersistAtUtc?.toIso8601String() ?? 'never'}, '
      'last attempt: '
      '${repository.lastSnapshotPersistAttemptAtUtc?.toIso8601String() ?? 'never'}, '
      'consecutive failures: ${repository.consecutiveSnapshotPersistFailures}. '
      'Reconnecting Supabase client.',
      name: 'OnyxHikIsapiStream',
      level: 900,
    );
    try {
      await repository.reconnect(
        reason:
            'snapshot persistence stale while camera stream remains connected',
      );
      final latestSnapshot = _latestSnapshot;
      if (latestSnapshot != null) {
        await _persistSnapshot(repository, latestSnapshot);
      }
    } catch (error, stackTrace) {
      developer.log(
        'Supabase watchdog reconnect failed.',
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
      if (channelId <= 0) {
        developer.log(
          '[ONYX] Skipping vehicle presence persistence for invalid channel ${event.channelId}.',
          name: 'OnyxHikIsapiStream',
          level: 800,
        );
        return;
      }
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

Future<void> _sendCameraWorkerThreatModeAlert({required String siteId}) async {
  final botToken = Platform.environment['ONYX_TELEGRAM_BOT_TOKEN'] ?? '';
  final chatId = Platform.environment['ONYX_TELEGRAM_ADMIN_CHAT_ID'] ?? '';
  final threadId = (Platform.environment['ONYX_TELEGRAM_ADMIN_THREAD_ID'] ?? '')
      .trim();
  if (botToken.isEmpty || chatId.isEmpty) {
    return;
  }
  final uri = Uri.https('api.telegram.org', '/bot$botToken/sendMessage');
  final body = <String, String>{
    'chat_id': chatId,
    'text': '⚡ ONYX THREAT MODE — Grid event detected at $siteId',
    'disable_notification': 'false',
  };
  if (threadId.isNotEmpty) {
    body['message_thread_id'] = threadId;
  }
  try {
    await http.post(uri, body: body).timeout(const Duration(seconds: 10));
  } catch (_) {}
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
  final rtspFrameServerEndpointRaw =
      Platform.environment['ONYX_RTSP_FRAME_SERVER_ENDPOINT'] ??
      'http://127.0.0.1:11638';
  final rtspFrameServerEndpoint = Uri.tryParse(
    rtspFrameServerEndpointRaw.trim(),
  );

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
  OnyxEvidenceCertificateService? evidenceCertificateService;
  OnyxOutcomeFeedbackService? outcomeFeedbackService;
  OnyxAwarenessLatencyService? awarenessLatencyService;
  OnyxPowerModeService? powerModeService;
  OnyxEnvironmentEngine? environmentEngine;
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    repository = OnyxSiteAwarenessRepository(
      supabaseUrl: supabaseUrl,
      supabaseKey: supabaseKey,
    );
    proactiveAlertService = OnyxProactiveAlertService(
      readConfig: repository.readAlertConfig,
      profileService: OnyxSiteProfileService(
        readProfileRow: repository.readSiteProfileRow,
        readZoneRuleRows: repository.readSiteZoneRuleRows,
        readExpectedVisitorRows: repository.readExpectedVisitorRows,
      ),
    );
    evidenceCertificateService = OnyxEvidenceCertificateService(
      client: SupabaseClient(supabaseUrl, supabaseKey),
    );
    outcomeFeedbackService = OnyxOutcomeFeedbackService(
      client: SupabaseClient(supabaseUrl, supabaseKey),
    );
    awarenessLatencyService = OnyxAwarenessLatencyService(
      client: SupabaseClient(supabaseUrl, supabaseKey),
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
          rtspFrameServerBaseUri: rtspFrameServerEndpoint,
        );

  late final OnyxHikIsapiStreamAwarenessService service;
  powerModeService = supabaseUrl.isEmpty || supabaseKey.isEmpty
      ? null
      : OnyxPowerModeService(
          siteId: siteId,
          supabaseClient: SupabaseClient(supabaseUrl, supabaseKey),
          readHealth: () => service.readPowerHealthSnapshot(),
          onModeChanged: (change) => service.handlePowerModeChange(change),
        );
  environmentEngine =
      powerModeService == null ||
          outcomeFeedbackService == null ||
          awarenessLatencyService == null
      ? null
      : OnyxEnvironmentEngine(
          powerModeService: powerModeService,
          outcomeFeedbackService: outcomeFeedbackService,
          awarenessLatencyService: awarenessLatencyService,
        );
  service = OnyxHikIsapiStreamAwarenessService(
    host: host,
    port: port,
    username: username,
    password: password,
    knownFaultChannels: knownFaultChannels,
    repository: repository,
    proactiveAlertService: proactiveAlertService,
    liveSnapshotYoloService: liveSnapshotYoloService,
    evidenceCertificateService: evidenceCertificateService,
    powerModeService: powerModeService,
    environmentEngine: environmentEngine,
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
    if (!_isPositiveChannelLabel(channelId)) {
      continue;
    }
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
    final validKnownFaults = snapshot.knownFaults
        .where(_isPositiveChannelLabel)
        .toList(growable: false);
    if (validKnownFaults.isNotEmpty) {
      parts.add('faults: ${validKnownFaults.join(',')}');
    }
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
