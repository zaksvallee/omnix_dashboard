import '../domain/events/dispatch_event.dart';
import '../domain/events/intelligence_received.dart';

class SiteActivityIntelligenceSnapshot {
  final int totalSignals;
  final int personSignals;
  final int vehicleSignals;
  final int knownIdentitySignals;
  final int flaggedIdentitySignals;
  final int unknownPersonSignals;
  final int unknownVehicleSignals;
  final int longPresenceSignals;
  final int guardInteractionSignals;
  final String topFlaggedIdentitySummary;
  final String topLongPresenceSummary;
  final String topGuardInteractionSummary;
  final List<String> eventIds;
  final List<String> evidenceEventIds;
  final String? selectedEventId;
  final String summaryLine;

  const SiteActivityIntelligenceSnapshot({
    required this.totalSignals,
    required this.personSignals,
    required this.vehicleSignals,
    required this.knownIdentitySignals,
    required this.flaggedIdentitySignals,
    required this.unknownPersonSignals,
    required this.unknownVehicleSignals,
    required this.longPresenceSignals,
    required this.guardInteractionSignals,
    this.topFlaggedIdentitySummary = '',
    this.topLongPresenceSummary = '',
    this.topGuardInteractionSummary = '',
    this.eventIds = const <String>[],
    this.evidenceEventIds = const <String>[],
    this.selectedEventId,
    required this.summaryLine,
  });
}

class _PresenceAggregate {
  final String objectLabel;
  final String evidenceLabel;
  final String cameraId;
  DateTime firstSeenUtc;
  DateTime lastSeenUtc;
  String latestEventId;

  _PresenceAggregate({
    required this.objectLabel,
    required this.evidenceLabel,
    required this.cameraId,
    required this.firstSeenUtc,
    required this.lastSeenUtc,
    required this.latestEventId,
  });

  Duration get duration => lastSeenUtc.difference(firstSeenUtc);
}

class SiteActivityIntelligenceService {
  const SiteActivityIntelligenceService();

  SiteActivityIntelligenceSnapshot buildSnapshot({
    required List<DispatchEvent> events,
    DateTime? startUtc,
    DateTime? endUtc,
    String? clientId,
    String? siteId,
  }) {
    final scoped = events
        .whereType<IntelligenceReceived>()
        .where((event) {
          final occurredAt = event.occurredAt.toUtc();
          if (startUtc != null && occurredAt.isBefore(startUtc.toUtc())) {
            return false;
          }
          if (endUtc != null && occurredAt.isAfter(endUtc.toUtc())) {
            return false;
          }
          if (clientId != null && event.clientId != clientId) {
            return false;
          }
          if (siteId != null && event.siteId != siteId) {
            return false;
          }
          final source = event.sourceType.trim().toLowerCase();
          return source == 'dvr' || source == 'cctv';
        })
        .toList(growable: false);

    if (scoped.isEmpty) {
      return const SiteActivityIntelligenceSnapshot(
        totalSignals: 0,
        personSignals: 0,
        vehicleSignals: 0,
        knownIdentitySignals: 0,
        flaggedIdentitySignals: 0,
        unknownPersonSignals: 0,
        unknownVehicleSignals: 0,
        longPresenceSignals: 0,
        guardInteractionSignals: 0,
        topFlaggedIdentitySummary: '',
        topLongPresenceSummary: '',
        topGuardInteractionSummary: '',
        eventIds: <String>[],
        evidenceEventIds: <String>[],
        selectedEventId: null,
        summaryLine: 'No visitor or site-activity signals detected.',
      );
    }

    var personSignals = 0;
    var vehicleSignals = 0;
    var knownIdentitySignals = 0;
    var flaggedIdentitySignals = 0;
    var unknownPersonSignals = 0;
    var unknownVehicleSignals = 0;
    var guardInteractionSignals = 0;
    final eventEntries = <({String id, DateTime occurredAt})>[];
    IntelligenceReceived? topFlaggedIdentityEvent;
    IntelligenceReceived? topGuardInteractionEvent;

    final groupedPresence = <String, _PresenceAggregate>{};

    for (final event in scoped) {
      eventEntries.add((
        id: event.eventId,
        occurredAt: event.occurredAt.toUtc(),
      ));
      final objectLabel = _normalizedObjectLabel(event.objectLabel);
      final hasKnownIdentity =
          (event.faceMatchId ?? '').trim().isNotEmpty ||
          (event.plateNumber ?? '').trim().isNotEmpty;
      final signalText = '${event.headline} ${event.summary}'
          .trim()
          .toLowerCase();
      final flaggedIdentity =
          signalText.contains('watchlist') ||
          signalText.contains('unauthorized') ||
          signalText.contains('blacklist') ||
          signalText.contains('wanted') ||
          signalText.contains('stolen');
      final guardInteraction =
          signalText.contains('guard') &&
          (signalText.contains('talk') ||
              signalText.contains('conversation') ||
              signalText.contains('interaction') ||
              signalText.contains('meeting'));

      if (objectLabel == 'person') {
        personSignals += 1;
        if (hasKnownIdentity) {
          knownIdentitySignals += 1;
        } else {
          unknownPersonSignals += 1;
        }
      } else if (objectLabel == 'vehicle') {
        vehicleSignals += 1;
        if (hasKnownIdentity) {
          knownIdentitySignals += 1;
        } else {
          unknownVehicleSignals += 1;
        }
      }

      if (flaggedIdentity) {
        flaggedIdentitySignals += 1;
        if (_isStrongerEvidenceEvent(event, topFlaggedIdentityEvent)) {
          topFlaggedIdentityEvent = event;
        }
      }
      if (guardInteraction) {
        guardInteractionSignals += 1;
        if (_isStrongerEvidenceEvent(event, topGuardInteractionEvent)) {
          topGuardInteractionEvent = event;
        }
      }

      final groupingKey = _presenceGroupingKey(event, objectLabel);
      final occurredAt = event.occurredAt.toUtc();
      final aggregate = groupedPresence.putIfAbsent(
        groupingKey,
        () => _PresenceAggregate(
          objectLabel: objectLabel,
          evidenceLabel: _evidenceLabelFor(event, objectLabel),
          cameraId: (event.cameraId ?? '').trim(),
          firstSeenUtc: occurredAt,
          lastSeenUtc: occurredAt,
          latestEventId: event.eventId,
        ),
      );
      if (occurredAt.isBefore(aggregate.firstSeenUtc)) {
        aggregate.firstSeenUtc = occurredAt;
      }
      if (occurredAt.isAfter(aggregate.lastSeenUtc)) {
        aggregate.lastSeenUtc = occurredAt;
        aggregate.latestEventId = event.eventId;
      }
    }

    final longPresenceEntries =
        groupedPresence.values
            .where((entry) => entry.duration >= const Duration(hours: 2))
            .toList(growable: false)
          ..sort((left, right) => right.duration.compareTo(left.duration));
    final longPresenceSignals = longPresenceEntries.length;
    final topLongPresence = longPresenceEntries.isEmpty
        ? null
        : longPresenceEntries.first;
    eventEntries.sort((left, right) {
      final occurredCompare = left.occurredAt.compareTo(right.occurredAt);
      if (occurredCompare != 0) {
        return occurredCompare;
      }
      return left.id.compareTo(right.id);
    });
    final eventIds = eventEntries
        .map((entry) => entry.id.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final evidenceEventIds = <String>[
      if (topFlaggedIdentityEvent != null) topFlaggedIdentityEvent.eventId,
      if (topLongPresence != null) topLongPresence.latestEventId,
      if (topGuardInteractionEvent != null) topGuardInteractionEvent.eventId,
    ].where((value) => value.trim().isNotEmpty).toSet().toList(growable: false);

    final summaryParts = <String>[
      'Signals ${scoped.length}',
      if (vehicleSignals > 0) 'Vehicles $vehicleSignals',
      if (personSignals > 0) 'People $personSignals',
      if (knownIdentitySignals > 0) 'Known IDs $knownIdentitySignals',
      if (unknownPersonSignals > 0 || unknownVehicleSignals > 0)
        'Unknown ${unknownPersonSignals + unknownVehicleSignals}',
      if (longPresenceSignals > 0) 'Long presence $longPresenceSignals',
      if (guardInteractionSignals > 0)
        'Guard interactions $guardInteractionSignals',
      if (flaggedIdentitySignals > 0) 'Flagged IDs $flaggedIdentitySignals',
    ];

    return SiteActivityIntelligenceSnapshot(
      totalSignals: scoped.length,
      personSignals: personSignals,
      vehicleSignals: vehicleSignals,
      knownIdentitySignals: knownIdentitySignals,
      flaggedIdentitySignals: flaggedIdentitySignals,
      unknownPersonSignals: unknownPersonSignals,
      unknownVehicleSignals: unknownVehicleSignals,
      longPresenceSignals: longPresenceSignals,
      guardInteractionSignals: guardInteractionSignals,
      topFlaggedIdentitySummary: topFlaggedIdentityEvent == null
          ? ''
          : _flaggedIdentitySummaryFor(topFlaggedIdentityEvent),
      topLongPresenceSummary: topLongPresence == null
          ? ''
          : _longPresenceSummaryFor(topLongPresence),
      topGuardInteractionSummary: topGuardInteractionEvent == null
          ? ''
          : _guardInteractionSummaryFor(topGuardInteractionEvent),
      eventIds: eventIds,
      evidenceEventIds: evidenceEventIds,
      selectedEventId: eventIds.isEmpty ? null : eventIds.last,
      summaryLine: summaryParts.join(' • '),
    );
  }

  String _normalizedObjectLabel(String? raw) {
    final label = (raw ?? '').trim().toLowerCase();
    if (label == 'human' || label == 'intruder') {
      return 'person';
    }
    if (label == 'car' || label == 'truck') {
      return 'vehicle';
    }
    return label;
  }

  String _presenceGroupingKey(IntelligenceReceived event, String objectLabel) {
    final faceMatchId = (event.faceMatchId ?? '').trim();
    final plateNumber = (event.plateNumber ?? '').trim();
    final identity = faceMatchId.isNotEmpty
        ? 'face:$faceMatchId'
        : plateNumber.isNotEmpty
        ? 'plate:$plateNumber'
        : 'camera:${(event.cameraId ?? '').trim()}|object:$objectLabel';
    return '${event.clientId}|${event.siteId}|$identity';
  }

  bool _isStrongerEvidenceEvent(
    IntelligenceReceived candidate,
    IntelligenceReceived? current,
  ) {
    if (current == null) {
      return true;
    }
    if (candidate.riskScore != current.riskScore) {
      return candidate.riskScore > current.riskScore;
    }
    return candidate.occurredAt.isAfter(current.occurredAt);
  }

  String _evidenceLabelFor(IntelligenceReceived event, String objectLabel) {
    final faceMatchId = (event.faceMatchId ?? '').trim();
    if (faceMatchId.isNotEmpty) {
      return faceMatchId;
    }
    final plateNumber = (event.plateNumber ?? '').trim();
    if (plateNumber.isNotEmpty) {
      return plateNumber;
    }
    return switch (objectLabel) {
      'person' => 'Unknown person',
      'vehicle' => 'Unknown vehicle',
      _ => objectLabel.trim().isEmpty ? 'Unknown subject' : objectLabel,
    };
  }

  String _cameraLabel(String? raw) {
    final cameraId = (raw ?? '').trim();
    return cameraId.isEmpty ? 'site perimeter' : cameraId;
  }

  String _flaggedIdentitySummaryFor(IntelligenceReceived event) {
    final objectLabel = _normalizedObjectLabel(event.objectLabel);
    final evidence = _evidenceLabelFor(event, objectLabel);
    return '$evidence flagged near ${_cameraLabel(event.cameraId)}';
  }

  String _longPresenceSummaryFor(_PresenceAggregate entry) {
    return '${entry.evidenceLabel} remained near ${_cameraLabel(entry.cameraId)} for ${_durationLabel(entry.duration)}';
  }

  String _guardInteractionSummaryFor(IntelligenceReceived event) {
    return 'Guard interaction observed near ${_cameraLabel(event.cameraId)}';
  }

  String _durationLabel(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours <= 0) {
      return '${duration.inMinutes}m';
    }
    if (minutes <= 0) {
      return '${hours}h';
    }
    return '${hours}h ${minutes}m';
  }
}
