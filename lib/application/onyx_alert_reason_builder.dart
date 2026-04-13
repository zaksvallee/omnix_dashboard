import 'site_awareness/onyx_site_awareness_snapshot.dart';

class OnyxAlertReason {
  final String headline;
  final List<String> signals;
  final Map<String, double> scores;
  final List<String> rulesFired;
  final String contextNote;

  const OnyxAlertReason({
    required this.headline,
    this.signals = const <String>[],
    this.scores = const <String, double>{},
    this.rulesFired = const <String>[],
    this.contextNote = '',
  });

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'headline': headline,
      'signals': List<String>.from(signals),
      'scores': scores.map(
        (key, value) => MapEntry(key, value.isFinite ? value : 0),
      ),
      'rules_fired': List<String>.from(rulesFired),
      'context_note': contextNote,
    };
  }
}

class OnyxAlertReasonBuilder {
  const OnyxAlertReasonBuilder();

  OnyxAlertReason buildReason(OnyxSiteAwarenessEvent event) {
    final signals = <String>[];
    final scores = <String, double>{};
    final rulesFired = <String>[];
    final zoneLabel = (event.zoneId ?? '').trim().toLowerCase();
    final personConfidence = event.personConfidence;
    if (personConfidence != null) {
      scores['person_confidence'] = personConfidence;
      if (personConfidence >= 0.55) {
        signals.add(
          'Detection confirmed at ${(personConfidence * 100).round()}%',
        );
      }
    }

    final faceMatchId = (event.faceMatchId ?? '').trim().toUpperCase();
    if (faceMatchId.isEmpty && event.eventType == OnyxEventType.humanDetected) {
      signals.add('No resident or visitor match');
    } else if (faceMatchId.contains('FLAGGED')) {
      signals.add('Flagged individual identified');
    }

    if (zoneLabel.contains('perimeter')) {
      final perimeterRule =
          zoneLabel.contains('semi-perimeter') ||
              zoneLabel.contains('semi_perimeter')
          ? 'Semi-perimeter zone activity'
          : 'Perimeter zone violation';
      rulesFired.add(perimeterRule);
    }

    final afterHours = _isAfterHours(event.detectedAt);
    final contextParts = <String>[];
    if (afterHours) {
      contextParts.add('Detected outside active hours');
    }
    final zoneContext = (event.zoneId ?? '').trim();
    if (zoneContext.isNotEmpty) {
      contextParts.add('Zone: $zoneContext');
    }

    return OnyxAlertReason(
      headline: _headlineFor(event, zoneLabel: zoneLabel),
      signals: List<String>.unmodifiable(signals),
      scores: Map<String, double>.unmodifiable(scores),
      rulesFired: List<String>.unmodifiable(rulesFired),
      contextNote: contextParts.join(' • '),
    );
  }

  String _headlineFor(
    OnyxSiteAwarenessEvent event, {
    required String zoneLabel,
  }) {
    if ((event.faceMatchId ?? '').toUpperCase().contains('FLAGGED')) {
      return 'Flagged individual identified';
    }
    if (zoneLabel.contains('perimeter')) {
      return 'Perimeter breach detected';
    }
    return switch (event.eventType) {
      OnyxEventType.humanDetected => 'Human activity detected',
      OnyxEventType.vehicleDetected => 'Vehicle activity detected',
      OnyxEventType.animalDetected => 'Animal activity detected',
      OnyxEventType.motionDetected => 'Motion detected',
      OnyxEventType.perimeterBreach => 'Perimeter breach detected',
      OnyxEventType.videoloss => 'Video loss detected',
      OnyxEventType.unknown => 'Alert triggered',
    };
  }

  bool _isAfterHours(DateTime detectedAt) {
    final local = detectedAt.toLocal();
    return local.hour < 6 || local.hour >= 18;
  }
}
