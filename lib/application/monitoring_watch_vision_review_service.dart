import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/events/intelligence_received.dart';
import 'dvr_http_auth.dart';
import 'hazard_response_directive_service.dart';

enum MonitoringWatchVisionConfidence { low, medium, high }

const _hazardDirectiveService = HazardResponseDirectiveService();

class MonitoringWatchVisionReviewResult {
  final String sourceLabel;
  final bool usedFallback;
  final String primaryObjectLabel;
  final MonitoringWatchVisionConfidence confidence;
  final bool indicatesPerson;
  final bool indicatesVehicle;
  final bool indicatesAnimal;
  final bool indicatesFireSmoke;
  final bool indicatesWaterLeak;
  final bool indicatesEnvironmentHazard;
  final bool indicatesLoitering;
  final bool indicatesBoundaryConcern;
  final bool indicatesEscalationCandidate;
  final int riskDelta;
  final String summary;
  final List<String> tags;

  const MonitoringWatchVisionReviewResult({
    required this.sourceLabel,
    required this.usedFallback,
    required this.primaryObjectLabel,
    required this.confidence,
    required this.indicatesPerson,
    required this.indicatesVehicle,
    required this.indicatesAnimal,
    this.indicatesFireSmoke = false,
    this.indicatesWaterLeak = false,
    this.indicatesEnvironmentHazard = false,
    required this.indicatesLoitering,
    required this.indicatesBoundaryConcern,
    required this.indicatesEscalationCandidate,
    required this.riskDelta,
    required this.summary,
    this.tags = const [],
  });
}

abstract class MonitoringWatchVisionReviewService {
  bool get isConfigured;

  Future<MonitoringWatchVisionReviewResult> review({
    required IntelligenceReceived event,
    required DvrHttpAuthConfig authConfig,
    int priorReviewedEvents = 0,
    int groupedEventCount = 1,
  });
}

class UnconfiguredMonitoringWatchVisionReviewService
    implements MonitoringWatchVisionReviewService {
  const UnconfiguredMonitoringWatchVisionReviewService();

  @override
  bool get isConfigured => false;

  @override
  Future<MonitoringWatchVisionReviewResult> review({
    required IntelligenceReceived event,
    required DvrHttpAuthConfig authConfig,
    int priorReviewedEvents = 0,
    int groupedEventCount = 1,
  }) async {
    return buildMetadataOnlyMonitoringWatchVisionReview(event);
  }
}

class OpenAiMonitoringWatchVisionReviewService
    implements MonitoringWatchVisionReviewService {
  final http.Client client;
  final String apiKey;
  final String model;
  final Uri endpoint;
  final Duration requestTimeout;
  final Duration snapshotTimeout;

  OpenAiMonitoringWatchVisionReviewService({
    required this.client,
    required this.apiKey,
    required this.model,
    Uri? endpoint,
    this.requestTimeout = const Duration(seconds: 20),
    this.snapshotTimeout = const Duration(seconds: 8),
  }) : endpoint = endpoint ?? Uri.parse('https://api.openai.com/v1/responses');

  @override
  bool get isConfigured => apiKey.trim().isNotEmpty && model.trim().isNotEmpty;

  @override
  Future<MonitoringWatchVisionReviewResult> review({
    required IntelligenceReceived event,
    required DvrHttpAuthConfig authConfig,
    int priorReviewedEvents = 0,
    int groupedEventCount = 1,
  }) async {
    final snapshotUrl = (event.snapshotUrl ?? '').trim();
    if (!isConfigured || snapshotUrl.isEmpty) {
      return buildMetadataOnlyMonitoringWatchVisionReview(event);
    }

    try {
      final snapshotDataUrl = await _fetchSnapshotDataUrl(
        snapshotUrl,
        authConfig: authConfig,
      );
      if (snapshotDataUrl == null) {
        return buildMetadataOnlyMonitoringWatchVisionReview(event);
      }

      final response = await client
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'model': model.trim(),
              'temperature': 0,
              'max_output_tokens': 240,
              'input': [
                {
                  'role': 'system',
                  'content': [
                    {
                      'type': 'input_text',
                      'text': _systemPrompt(),
                    },
                  ],
                },
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'input_text',
                      'text': _userPrompt(
                        event: event,
                        priorReviewedEvents: priorReviewedEvents,
                        groupedEventCount: groupedEventCount,
                      ),
                    },
                    {
                      'type': 'input_image',
                      'image_url': snapshotDataUrl,
                    },
                  ],
                },
              ],
            }),
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return buildMetadataOnlyMonitoringWatchVisionReview(event);
      }
      final text = _extractText(jsonDecode(response.body));
      if (text == null || text.trim().isEmpty) {
        return buildMetadataOnlyMonitoringWatchVisionReview(event);
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        return buildMetadataOnlyMonitoringWatchVisionReview(event);
      }
      return _parseModelReview(
        decoded.cast<Object?, Object?>(),
        event: event,
      );
    } catch (_) {
      return buildMetadataOnlyMonitoringWatchVisionReview(event);
    }
  }

  Future<String?> _fetchSnapshotDataUrl(
    String rawUrl, {
    required DvrHttpAuthConfig authConfig,
  }) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return null;
    }
    final response = await authConfig
        .get(
          client,
          uri,
          headers: const {'Accept': 'image/*'},
        )
        .timeout(snapshotTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      return null;
    }
    final contentType =
        (response.headers['content-type'] ?? 'image/jpeg')
            .split(';')
            .first
            .trim()
            .toLowerCase();
    if (!contentType.startsWith('image/')) {
      return null;
    }
    return 'data:$contentType;base64,${base64Encode(bytes)}';
  }

  MonitoringWatchVisionReviewResult _parseModelReview(
    Map<Object?, Object?> payload, {
    required IntelligenceReceived event,
  }) {
    String readString(String key) => (payload[key] ?? '').toString().trim();
    bool tagPresent(String tag, List<String> tags) =>
        tags.any((entry) => entry == tag);

    final tags =
        (payload['tags'] is List)
            ? (payload['tags'] as List)
                .map((entry) => entry.toString().trim().toLowerCase())
                .where((entry) => entry.isNotEmpty)
                .toList(growable: false)
            : const <String>[];
    final posture = readString('posture').toLowerCase();
    final primaryObject = _normalizeObjectLabel(
      readString('primary_object'),
      fallback: (event.objectLabel ?? '').trim(),
    );
    final riskDelta = _clampRiskDelta(payload['risk_delta']);
    final hazardSignal = _hazardSignalFromVisionReview(
      posture: posture,
      primaryObject: primaryObject,
      tags: tags,
    );
    final indicatesFireSmoke = hazardSignal == 'fire';
    final indicatesWaterLeak = hazardSignal == 'water_leak';
    final indicatesEnvironmentHazard = hazardSignal == 'environment_hazard';
    return MonitoringWatchVisionReviewResult(
      sourceLabel: 'openai:${model.trim()}',
      usedFallback: false,
      primaryObjectLabel: primaryObject,
      confidence: _parseConfidence(
        readString('confidence'),
        fallback: _confidenceFromMetadata(event.objectConfidence),
      ),
      indicatesPerson:
          primaryObject == 'person' || tagPresent('person', tags),
      indicatesVehicle:
          primaryObject == 'vehicle' || tagPresent('vehicle', tags),
      indicatesAnimal:
          primaryObject == 'animal' || tagPresent('animal', tags),
      indicatesFireSmoke: indicatesFireSmoke,
      indicatesWaterLeak: indicatesWaterLeak,
      indicatesEnvironmentHazard: indicatesEnvironmentHazard,
      indicatesLoitering:
          posture.contains('loiter') || tagPresent('loitering', tags),
      indicatesBoundaryConcern:
          posture.contains('boundary') ||
          tagPresent('boundary', tags) ||
          tagPresent('line_crossing', tags),
      indicatesEscalationCandidate:
          posture.contains('escalation') ||
          tagPresent('escalation_candidate', tags) ||
          hazardSignal.isNotEmpty,
      riskDelta: riskDelta,
      summary: readString('summary'),
      tags: tags,
    );
  }

  String _systemPrompt() {
    return 'You are ONYX CCTV scene review.\n'
        'Review one CCTV snapshot conservatively.\n'
        'Only describe what is visibly supported.\n'
        'Do not infer identity, intent, weapons, or breach status unless directly visible.\n'
        'Return JSON only with keys: '
        '"primary_object", "confidence", "posture", "risk_delta", "tags", "summary".\n'
        'Rules:\n'
        '- primary_object: person | vehicle | animal | smoke | fire | water | leak | equipment | movement | unknown\n'
        '- confidence: low | medium | high\n'
        '- posture: routine | monitored | repeat | boundary | loitering | fire | flood | leak | environment_hazard | escalation_candidate\n'
        '- risk_delta: integer between -20 and 20\n'
        '- tags: short lowercase tokens\n'
        '- summary: one short sentence.';
  }

  String _userPrompt({
    required IntelligenceReceived event,
    required int priorReviewedEvents,
    required int groupedEventCount,
  }) {
    final metadataLabel = (event.objectLabel ?? '').trim();
    final metadataConfidence = event.objectConfidence == null
        ? 'unset'
        : event.objectConfidence!.toStringAsFixed(2);
    return 'Event metadata:\n'
        '- headline: ${event.headline.trim()}\n'
        '- summary: ${event.summary.trim()}\n'
        '- object_label: ${metadataLabel.isEmpty ? 'unset' : metadataLabel}\n'
        '- object_confidence: $metadataConfidence\n'
        '- prior_reviewed_events: $priorReviewedEvents\n'
        '- grouped_event_count: $groupedEventCount\n'
        '- camera_id: ${(event.cameraId ?? '').trim().isEmpty ? 'unknown' : event.cameraId!.trim()}\n'
        '- risk_score: ${event.riskScore}\n'
        'Review the attached image and return only the requested JSON.';
  }
}

MonitoringWatchVisionReviewResult buildMetadataOnlyMonitoringWatchVisionReview(
  IntelligenceReceived event,
) {
  final objectLabel = _normalizeObjectLabel(
    (event.objectLabel ?? '').trim(),
    fallback: 'movement',
  );
  final signalText = '${event.headline} ${event.summary}'.toLowerCase();
  final hazardSignal = _hazardSignalFromMetadata(
    signalText: signalText,
    objectLabel: objectLabel,
  );
  return MonitoringWatchVisionReviewResult(
    sourceLabel: 'metadata-only',
    usedFallback: true,
    primaryObjectLabel: objectLabel,
    confidence: _confidenceFromMetadata(event.objectConfidence),
    indicatesPerson: objectLabel == 'person',
    indicatesVehicle: objectLabel == 'vehicle',
    indicatesAnimal: objectLabel == 'animal',
    indicatesFireSmoke: hazardSignal == 'fire',
    indicatesWaterLeak: hazardSignal == 'water_leak',
    indicatesEnvironmentHazard: hazardSignal == 'environment_hazard',
    indicatesLoitering: signalText.contains('loiter'),
    indicatesBoundaryConcern:
        signalText.contains('line_crossing') ||
        signalText.contains('line crossing') ||
        signalText.contains('intrusion'),
    indicatesEscalationCandidate: hazardSignal.isNotEmpty,
    riskDelta: 0,
    summary: 'Metadata-only review.',
    tags: const <String>['metadata'],
  );
}

MonitoringWatchVisionConfidence _confidenceFromMetadata(double? raw) {
  final confidence = raw ?? -1;
  if (confidence >= 0.85) {
    return MonitoringWatchVisionConfidence.high;
  }
  if (confidence >= 0.55) {
    return MonitoringWatchVisionConfidence.medium;
  }
  return MonitoringWatchVisionConfidence.low;
}

MonitoringWatchVisionConfidence _parseConfidence(
  String raw, {
  required MonitoringWatchVisionConfidence fallback,
}) {
  return switch (raw.trim().toLowerCase()) {
    'high' => MonitoringWatchVisionConfidence.high,
    'medium' => MonitoringWatchVisionConfidence.medium,
    'low' => MonitoringWatchVisionConfidence.low,
    _ => fallback,
  };
}

String _normalizeObjectLabel(String raw, {required String fallback}) {
  final normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) {
    return fallback;
  }
  if (normalized == 'car' || normalized == 'truck') {
    return 'vehicle';
  }
  if (normalized == 'human' || normalized == 'intruder') {
    return 'person';
  }
  if (normalized == 'smoke') {
    return 'smoke';
  }
  if (normalized == 'flame') {
    return 'fire';
  }
  if (normalized == 'flood' || normalized == 'burst_pipe') {
    return 'water';
  }
  if (normalized == 'cat' ||
      normalized == 'dog' ||
      normalized == 'bird' ||
      normalized == 'animal') {
    return 'animal';
  }
  return normalized;
}

int _clampRiskDelta(Object? raw) {
  final parsed = switch (raw) {
    int value => value,
    num value => value.round(),
    String value => int.tryParse(value.trim()) ?? 0,
    _ => 0,
  };
  if (parsed < -20) {
    return -20;
  }
  if (parsed > 20) {
    return 20;
  }
  return parsed;
}

String _hazardSignalFromVisionReview({
  required String posture,
  required String primaryObject,
  required List<String> tags,
}) {
  final baseSignal = _hazardDirectiveService.hazardSignal(
    postureLabel: posture,
    objectLabel: primaryObject,
  );
  if (baseSignal.isNotEmpty) {
    return baseSignal;
  }
  if (tags.any((entry) => entry == 'fire' || entry == 'smoke')) {
    return 'fire';
  }
  if (tags.any(
    (entry) =>
        entry == 'water' ||
        entry == 'flood' ||
        entry == 'leak' ||
        entry == 'pipe_burst',
  )) {
    return 'water_leak';
  }
  if (posture.contains('environment') ||
      tags.any(
        (entry) =>
            entry == 'hazard' ||
            entry == 'steam' ||
            entry == 'equipment_failure' ||
            entry == 'environmental_hazard',
      )) {
    return 'environment_hazard';
  }
  return '';
}

String _hazardSignalFromMetadata({
  required String signalText,
  required String objectLabel,
}) {
  final baseSignal = _hazardDirectiveService.hazardSignal(
    postureLabel: signalText,
    objectLabel: objectLabel,
  );
  if (baseSignal.isNotEmpty) {
    return baseSignal;
  }
  if (signalText.contains('burst pipe') ||
      signalText.contains('pipe burst') ||
      signalText.contains('water')) {
    return 'water_leak';
  }
  if (signalText.contains('steam') ||
      signalText.contains('equipment failure') ||
      signalText.contains('electrical')) {
    return 'environment_hazard';
  }
  return '';
}

String? _extractText(Object? decoded) {
  if (decoded is! Map) return null;
  final map = decoded.cast<Object?, Object?>();
  final outputText = map['output_text'];
  if (outputText is String && outputText.trim().isNotEmpty) {
    return outputText.trim();
  }
  final output = map['output'];
  if (output is List) {
    final chunks = <String>[];
    for (final item in output) {
      if (item is! Map) continue;
      final content = item['content'];
      if (content is! List) continue;
      for (final part in content) {
        if (part is! Map) continue;
        final text = (part['text'] ?? '').toString().trim();
        if (text.isNotEmpty) {
          chunks.add(text);
        }
      }
    }
    if (chunks.isNotEmpty) {
      return chunks.join('\n').trim();
    }
  }
  return null;
}
