import 'dart:math' as math;

import 'package:xml/xml.dart' as xml;

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
