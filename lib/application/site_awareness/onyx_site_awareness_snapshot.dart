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

  const OnyxDetectionSummary({
    required this.humanCount,
    required this.vehicleCount,
    required this.animalCount,
    required this.motionCount,
    required this.lastUpdated,
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
    };
  }
}

class OnyxSiteAlert {
  final String alertId;
  final String channelId;
  final OnyxEventType eventType;
  final DateTime detectedAt;
  final bool isAcknowledged;

  const OnyxSiteAlert({
    required this.alertId,
    required this.channelId,
    required this.eventType,
    required this.detectedAt,
    this.isAcknowledged = false,
  });

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'alert_id': alertId,
      'channel_id': channelId,
      'event_type': eventType.name,
      'detected_at': detectedAt.toUtc().toIso8601String(),
      'is_acknowledged': isAcknowledged,
    };
  }
}

class OnyxSiteAwarenessEvent {
  final String channelId;
  final OnyxEventType eventType;
  final DateTime detectedAt;
  final String rawEventType;
  final String? targetType;
  final bool isKnownFaultChannel;

  const OnyxSiteAwarenessEvent({
    required this.channelId,
    required this.eventType,
    required this.detectedAt,
    required this.rawEventType,
    this.targetType,
    this.isKnownFaultChannel = false,
  });

  factory OnyxSiteAwarenessEvent.fromAlertXml(
    String payload, {
    Set<String> knownFaultChannels = const <String>{},
    DateTime Function()? clock,
  }) {
    final document = xml.XmlDocument.parse(payload);
    final channelId = _firstNonEmpty(
      _readTag(document, 'dynChannelID'),
      _readTag(document, 'channelID'),
      _readTag(document, 'channelId'),
    );
    final rawEventType = _firstNonEmpty(
      _readTag(document, 'eventType'),
      _readTag(document, 'eventDescription'),
    );
    final targetType = _readTag(document, 'targetType');
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
      isKnownFaultChannel: knownFaultChannels.contains(channelId),
    );
  }

  bool get shouldRaiseAlert {
    if (isKnownFaultChannel) {
      return false;
    }
    return eventType != OnyxEventType.unknown;
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
    this.detectionWindow = const Duration(minutes: 5),
    DateTime Function()? clock,
    math.Random? random,
  }) : knownFaultChannels = Set<String>.from(knownFaultChannels),
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
      _activeAlerts.add(
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

  OnyxSiteAwarenessSnapshot snapshot({DateTime? at}) {
    final now = (at ?? clock()).toUtc();
    _prune(now);

    var humanCount = 0;
    var vehicleCount = 0;
    var animalCount = 0;
    var motionCount = 0;
    for (final event in _recentEvents) {
      switch (event.eventType) {
        case OnyxEventType.humanDetected:
          humanCount += 1;
        case OnyxEventType.vehicleDetected:
          vehicleCount += 1;
        case OnyxEventType.animalDetected:
          animalCount += 1;
        case OnyxEventType.motionDetected:
          motionCount += 1;
        case OnyxEventType.perimeterBreach:
        case OnyxEventType.videoloss:
        case OnyxEventType.unknown:
          break;
      }
    }

    final hasRecentHumanOrVehicle = _recentEvents.any(
      (event) =>
          !event.isKnownFaultChannel &&
          (event.eventType == OnyxEventType.humanDetected ||
              event.eventType == OnyxEventType.vehicleDetected),
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
      ),
      perimeterClear: !hasRecentHumanOrVehicle,
      knownFaults: knownFaults,
      activeAlerts: activeAlerts,
    );
  }

  void _prune(DateTime nowUtc) {
    final cutoff = nowUtc.subtract(detectionWindow);
    _recentEvents.removeWhere((event) => event.detectedAt.isBefore(cutoff));
    _activeAlerts.removeWhere((alert) => alert.detectedAt.isBefore(cutoff));
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
