import '../domain/events/intelligence_received.dart';
import 'intelligence_event_object_semantics.dart';
import 'monitoring_scene_review_store.dart';

class MonitoringSiteNarrativeFieldActivity {
  final int count;
  final String latestSource;
  final String latestSummary;
  final List<String> activeSources;

  const MonitoringSiteNarrativeFieldActivity({
    required this.count,
    required this.latestSource,
    required this.latestSummary,
    this.activeSources = const <String>[],
  });
}

class MonitoringSiteNarrativeSnapshot {
  final String narrative;
  final String assessment;

  const MonitoringSiteNarrativeSnapshot({
    required this.narrative,
    required this.assessment,
  });
}

class MonitoringSiteNarrativeService {
  const MonitoringSiteNarrativeService();

  MonitoringSiteNarrativeSnapshot? buildSnapshot({
    required List<IntelligenceReceived> recentEvents,
    required String Function(String? cameraId) cameraLabelForId,
    MonitoringSiteNarrativeFieldActivity? fieldActivity,
    Map<String, MonitoringSceneReviewRecord> sceneReviewsByIntelligenceId =
        const <String, MonitoringSceneReviewRecord>{},
  }) {
    if (recentEvents.isEmpty) {
      return null;
    }
    final sortedEvents = recentEvents.toList(growable: false)
      ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));

    final objectCounts = <String, int>{};
    final objectCameras = <String, Set<String>>{};
    for (final event in sortedEvents) {
      final objectLabel = _normalizeObjectLabel(event);
      objectCounts.update(
        objectLabel,
        (existing) => existing + 1,
        ifAbsent: () => 1,
      );
      final cameraLabel = cameraLabelForId(event.cameraId);
      objectCameras.update(
        objectLabel,
        (existing) => <String>{...existing, cameraLabel},
        ifAbsent: () => <String>{cameraLabel},
      );
    }

    final leadingClauses = <String>[];
    for (final objectLabel in const <String>[
      'person',
      'vehicle',
      'animal',
      'movement',
    ]) {
      final count = objectCounts[objectLabel] ?? 0;
      final cameras = objectCameras[objectLabel];
      if (count <= 0 || cameras == null || cameras.isEmpty) {
        continue;
      }
      final signalLabel = switch (objectLabel) {
        'person' => count == 1 ? 'person signal' : 'person signals',
        'vehicle' => count == 1 ? 'vehicle signal' : 'vehicle signals',
        'animal' => count == 1 ? 'animal signal' : 'animal signals',
        _ => count == 1 ? 'movement signal' : 'movement signals',
      };
      leadingClauses.add(
        '$count $signalLabel across ${_joinLabels(cameras.toList(growable: false)..sort())}',
      );
    }
    if (leadingClauses.isEmpty) {
      return null;
    }

    final personCount = objectCounts['person'] ?? 0;
    final personCameraCount = objectCameras['person']?.length ?? 0;
    final totalCameraCount = objectCameras.values
        .expand((entry) => entry)
        .toSet()
        .length;
    final vehicleCount = objectCounts['vehicle'] ?? 0;
    final fieldSources = fieldActivity == null
        ? const <String>[]
        : _locationLikeSources(fieldActivity.activeSources);

    String assessment = 'multi-camera site activity under review';
    String? supportLine;
    final hasDistributedFieldZones = fieldSources.length >= 2;
    final mentionsYardCoverage =
        fieldSources.any((source) => source.toLowerCase().contains('front')) &&
        fieldSources.any((source) => source.toLowerCase().contains('back'));
    if (personCount >= 2 && personCameraCount >= 2 && fieldActivity != null) {
      assessment = mentionsYardCoverage
          ? 'likely routine on-site team activity across front and back yard'
          : 'likely routine on-site team activity';
      if (mentionsYardCoverage) {
        supportLine =
            'This overlaps with on-site team activity across Front Yard and Back Yard, so it looks routine.';
      } else if (hasDistributedFieldZones) {
        supportLine =
            'This overlaps with on-site team activity at ${_joinLabels(fieldSources)}, so it looks routine.';
      } else {
        supportLine =
            'This overlaps with on-site team activity, so it looks routine.';
      }
    } else if (personCount >= 2 && personCameraCount >= 2) {
      assessment = 'distributed movement across multiple cameras';
      supportLine =
          'The movement is spread across multiple cameras rather than one fixed point.';
    } else if (vehicleCount > 0 && personCount > 0 && totalCameraCount >= 2) {
      assessment = 'broad mixed site activity under review';
      supportLine =
          'People and vehicle movement are both active across the site.';
    }

    if (fieldActivity != null &&
        fieldActivity.latestSummary.trim().isNotEmpty &&
        fieldSources.length < 2 &&
        supportLine == null) {
      supportLine =
          'On-site team activity was also reported: ${_lowercaseSentence(fieldActivity.latestSummary)}';
    }

    final latestAtLocal = sortedEvents.first.occurredAt.toLocal();
    final body = StringBuffer()
      ..write('Recent camera review saw ${_joinClauses(leadingClauses)}. ');
    if (supportLine != null && supportLine.trim().isNotEmpty) {
      body.write('$supportLine ');
    }
    body.write('Latest signal landed at ${_timeLabel(latestAtLocal)}.');
    return MonitoringSiteNarrativeSnapshot(
      narrative: body.toString().trim(),
      assessment: assessment,
    );
  }

  String _normalizeObjectLabel(IntelligenceReceived event) {
    final directObjectLabel =
        _normalizedDirectObjectLabel(event.objectLabel) ?? '';
    final resolvedObjectLabel = resolveIdentityBackedObjectLabel(
      event: event,
      directObjectLabel: directObjectLabel,
    );
    return resolvedObjectLabel.isEmpty ? 'movement' : resolvedObjectLabel;
  }

  String? _normalizedDirectObjectLabel(String? rawLabel) {
    final raw = (rawLabel ?? '').trim().toLowerCase();
    if (raw == 'human' || raw == 'intruder' || raw == 'person') {
      return 'person';
    }
    if (raw == 'car' || raw == 'truck' || raw == 'vehicle') {
      return 'vehicle';
    }
    if (raw == 'animal' || raw == 'dog' || raw == 'cat' || raw == 'bird') {
      return 'animal';
    }
    return null;
  }

  String _joinLabels(List<String> labels) {
    if (labels.isEmpty) {
      return 'the site';
    }
    if (labels.length == 1) {
      return labels.first;
    }
    if (labels.length == 2) {
      return '${labels.first} and ${labels.last}';
    }
    return '${labels.sublist(0, labels.length - 1).join(', ')}, and ${labels.last}';
  }

  String _joinClauses(List<String> clauses) {
    if (clauses.length == 1) {
      return clauses.first;
    }
    if (clauses.length == 2) {
      return '${clauses.first}, plus ${clauses.last}';
    }
    return '${clauses.sublist(0, clauses.length - 1).join('; ')}; plus ${clauses.last}';
  }

  List<String> _locationLikeSources(List<String> sources) {
    const genericSources = <String>{
      'Guard check-in',
      'Checkpoint scan',
      'Patrol verification',
      'Field telemetry',
      'Response arrival',
      'Worker shift start',
      'Guard status update',
    };
    final seen = <String>{};
    final filtered = <String>[];
    for (final rawSource in sources) {
      final source = rawSource.trim();
      if (source.isEmpty ||
          genericSources.contains(source) ||
          source.startsWith('Guard ') ||
          source.startsWith('Patrol ') ||
          source.endsWith(' telemetry')) {
        continue;
      }
      if (seen.add(source)) {
        filtered.add(source);
      }
      if (filtered.length >= 3) {
        break;
      }
    }
    return filtered;
  }

  String _timeLabel(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _lowercaseSentence(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final normalized = trimmed.endsWith('.')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    return '${normalized[0].toLowerCase()}${normalized.substring(1)}.';
  }
}
