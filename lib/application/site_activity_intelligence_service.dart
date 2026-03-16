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
    required this.summaryLine,
  });
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

    final groupedTimes = <String, List<DateTime>>{};

    for (final event in scoped) {
      final objectLabel = _normalizedObjectLabel(event.objectLabel);
      final hasKnownIdentity =
          (event.faceMatchId ?? '').trim().isNotEmpty ||
          (event.plateNumber ?? '').trim().isNotEmpty;
      final signalText =
          '${event.headline} ${event.summary}'.trim().toLowerCase();
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
      }
      if (guardInteraction) {
        guardInteractionSignals += 1;
      }

      final groupingKey = _presenceGroupingKey(event, objectLabel);
      groupedTimes.putIfAbsent(groupingKey, () => <DateTime>[]).add(
        event.occurredAt.toUtc(),
      );
    }

    final longPresenceSignals = groupedTimes.values.where((times) {
      if (times.length < 2) {
        return false;
      }
      times.sort();
      return times.last.difference(times.first) >= const Duration(hours: 2);
    }).length;

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
}
