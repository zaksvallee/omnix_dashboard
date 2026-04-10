import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/intelligence/intel_ingestion.dart';
import 'dvr_http_auth.dart';
import 'dvr_scope_config.dart';

abstract class MonitoringYoloDetectionService {
  bool get isConfigured;

  Future<List<NormalizedIntelRecord>> enrichRecords({
    required DvrScopeConfig scope,
    required Iterable<NormalizedIntelRecord> records,
  });
}

class UnconfiguredMonitoringYoloDetectionService
    implements MonitoringYoloDetectionService {
  const UnconfiguredMonitoringYoloDetectionService();

  @override
  bool get isConfigured => false;

  @override
  Future<List<NormalizedIntelRecord>> enrichRecords({
    required DvrScopeConfig scope,
    required Iterable<NormalizedIntelRecord> records,
  }) async {
    return const <NormalizedIntelRecord>[];
  }
}

class HttpMonitoringYoloDetectionService
    implements MonitoringYoloDetectionService {
  final http.Client client;
  final Uri endpoint;
  final String authToken;
  final Duration requestTimeout;
  final Duration snapshotTimeout;
  final int maxRecordsPerBatch;
  final double minimumConfidence;

  HttpMonitoringYoloDetectionService({
    required this.client,
    required this.endpoint,
    this.authToken = '',
    this.requestTimeout = const Duration(seconds: 20),
    this.snapshotTimeout = const Duration(seconds: 8),
    this.maxRecordsPerBatch = 4,
    this.minimumConfidence = 0.35,
  });

  @override
  bool get isConfigured => endpoint.toString().trim().isNotEmpty;

  @override
  Future<List<NormalizedIntelRecord>> enrichRecords({
    required DvrScopeConfig scope,
    required Iterable<NormalizedIntelRecord> records,
  }) async {
    if (!isConfigured) {
      return const <NormalizedIntelRecord>[];
    }
    final authConfig = DvrHttpAuthConfig(
      mode: parseDvrHttpAuthMode(scope.authMode),
      bearerToken: scope.bearerToken.trim().isEmpty ? null : scope.bearerToken,
      username: scope.username.trim().isEmpty ? null : scope.username,
      password: scope.password.isEmpty ? null : scope.password,
    );
    final candidates =
        records.where(_shouldEnrichRecord).toList(growable: false)..sort(
          (left, right) => right.occurredAtUtc.compareTo(left.occurredAtUtc),
        );
    if (candidates.isEmpty) {
      return const <NormalizedIntelRecord>[];
    }

    final payloadItems = <Map<String, Object?>>[];
    final recordsByKey = <String, NormalizedIntelRecord>{};
    for (final record in candidates.take(maxRecordsPerBatch)) {
      String? snapshotDataUrl;
      try {
        snapshotDataUrl = await _fetchSnapshotDataUrl(
          (record.snapshotUrl ?? '').trim(),
          authConfig: authConfig,
        );
      } catch (_) {
        snapshotDataUrl = null;
      }
      if (snapshotDataUrl == null) {
        continue;
      }
      final recordKey = _recordKeyFor(record);
      payloadItems.add(<String, Object?>{
        'record_key': recordKey,
        'provider': record.provider,
        'source_type': record.sourceType,
        'client_id': record.clientId,
        'region_id': record.regionId,
        'site_id': record.siteId,
        'camera_id': record.cameraId,
        'zone': record.zone,
        'headline': record.headline,
        'summary': record.summary,
        'object_label': record.objectLabel,
        'occurred_at_utc': record.occurredAtUtc.toUtc().toIso8601String(),
        'image_url': snapshotDataUrl,
      });
      recordsByKey[recordKey] = record;
    }
    if (payloadItems.isEmpty) {
      return const <NormalizedIntelRecord>[];
    }

    final response = await client
        .post(
          endpoint,
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (authToken.trim().isNotEmpty)
              'Authorization': 'Bearer ${authToken.trim()}',
          },
          body: jsonEncode(<String, Object?>{'items': payloadItems}),
        )
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException('YOLO detector HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final outputs = _parseResponse(decoded);
    if (outputs.isEmpty) {
      return const <NormalizedIntelRecord>[];
    }

    final semanticRecords = <NormalizedIntelRecord>[];
    for (final output in outputs) {
      final sourceRecord = recordsByKey[output.recordKey];
      if (sourceRecord == null) {
        continue;
      }
      semanticRecords.addAll(_recordsForOutput(sourceRecord, output));
    }
    return List<NormalizedIntelRecord>.unmodifiable(semanticRecords);
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
        .get(client, uri, headers: const <String, String>{'Accept': 'image/*'})
        .timeout(snapshotTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    if (response.bodyBytes.isEmpty) {
      return null;
    }
    final contentType = (response.headers['content-type'] ?? 'image/jpeg')
        .split(';')
        .first
        .trim()
        .toLowerCase();
    if (!contentType.startsWith('image/')) {
      return null;
    }
    return 'data:$contentType;base64,${base64Encode(response.bodyBytes)}';
  }

  List<_YoloDetectionOutput> _parseResponse(Object? decoded) {
    if (decoded is! Map) {
      return const <_YoloDetectionOutput>[];
    }
    final payload = decoded.cast<Object?, Object?>();
    final rawItems = switch (payload['results'] ?? payload['items']) {
      List value => value,
      _ => const <Object?>[],
    };
    final outputs = <_YoloDetectionOutput>[];
    for (final rawItem in rawItems.whereType<Map>()) {
      final item = rawItem.map((key, value) => MapEntry(key.toString(), value));
      final recordKey =
          (item['record_key'] ??
                  item['external_id'] ??
                  item['id'] ??
                  item['key'] ??
                  '')
              .toString()
              .trim();
      if (recordKey.isEmpty) {
        continue;
      }
      final primaryLabel = _primaryLabelFrom(item);
      final confidence =
          _doubleValue(item['confidence']) ??
          _doubleValue(item['score']) ??
          _doubleValue(item['primary_confidence']);
      final detections = _detectionsFrom(item);
      outputs.add(
        _YoloDetectionOutput(
          recordKey: recordKey,
          primaryLabel: primaryLabel,
          confidence: confidence,
          summary: (item['summary'] ?? item['description'] ?? '')
              .toString()
              .trim(),
          detections: detections,
          trackId: _normalizedString(item['track_id'] ?? item['trackId']),
          faceMatchId: _normalizedString(
            item['face_match_id'] ?? item['faceMatchId'],
          ),
          faceConfidence: _doubleValue(
            item['face_confidence'] ?? item['faceConfidence'],
          ),
          plateNumber: _normalizedString(
            item['plate_number'] ?? item['plateNumber'],
          ),
          plateConfidence: _doubleValue(
            item['plate_confidence'] ?? item['plateConfidence'],
          ),
        ),
      );
    }
    return outputs;
  }

  String _recordKeyFor(NormalizedIntelRecord record) {
    return [
      record.provider,
      record.sourceType,
      record.externalId,
      record.cameraId ?? '',
      record.occurredAtUtc.toUtc().toIso8601String(),
    ].join('|');
  }

  bool _shouldEnrichRecord(NormalizedIntelRecord record) {
    final snapshotUrl = (record.snapshotUrl ?? '').trim();
    if (snapshotUrl.isEmpty) {
      return false;
    }
    final normalizedObject = _normalizedSemanticLabel(record.objectLabel);
    if (normalizedObject == null) {
      final genericObjectLabel = (record.objectLabel ?? '')
          .trim()
          .toLowerCase();
      if (genericObjectLabel.isEmpty) {
        return true;
      }
      return _looksLikeGenericMovementLabel(genericObjectLabel);
    }
    if (normalizedObject == 'person' &&
        (record.faceMatchId ?? '').trim().isEmpty) {
      return true;
    }
    if (normalizedObject == 'vehicle' &&
        (record.plateNumber ?? '').trim().isEmpty) {
      return true;
    }
    return false;
  }

  bool _looksLikeGenericMovementLabel(String label) {
    return _containsAny(label, const <String>[
      'movement',
      'motion',
      'scene_change',
      'persistent_scene_change',
      'intrusion',
      'tripwire',
      'line_crossing',
      'line crossing',
      'perimeter',
      'activity',
      'unknown',
    ]);
  }

  List<NormalizedIntelRecord> _recordsForOutput(
    NormalizedIntelRecord sourceRecord,
    _YoloDetectionOutput output,
  ) {
    final records = <NormalizedIntelRecord>[];
    final detections = <_YoloDetectionResult>[
      ...output.detections,
      if (output.detections.isEmpty &&
          output.primaryLabel != null &&
          output.primaryLabel!.trim().isNotEmpty)
        _YoloDetectionResult(
          label: output.primaryLabel!,
          confidence: output.confidence ?? sourceRecord.objectConfidence ?? 0,
        ),
    ];
    final bestByLabel = <String, _YoloDetectionResult>{};
    for (final detection in detections) {
      final normalizedLabel = _normalizedSemanticLabel(detection.label);
      if (normalizedLabel == null) {
        continue;
      }
      final normalizedDetection = detection.copyWith(label: normalizedLabel);
      final trackKey = (normalizedDetection.trackId ?? '').trim();
      final dedupeKey = trackKey.isEmpty
          ? normalizedLabel
          : '$normalizedLabel#$trackKey';
      final current = bestByLabel[dedupeKey];
      if (current == null ||
          normalizedDetection.confidence > current.confidence) {
        bestByLabel[dedupeKey] = normalizedDetection;
      }
    }
    final orderedDetections = bestByLabel.values.toList(growable: false)
      ..sort((left, right) {
        final priorityCompare = _semanticPriority(
          right.label,
        ).compareTo(_semanticPriority(left.label));
        if (priorityCompare != 0) {
          return priorityCompare;
        }
        return right.confidence.compareTo(left.confidence);
      });

    var attachedFace = false;
    var attachedPlate = false;
    for (final detection in orderedDetections) {
      final confidence = detection.confidence;
      final attachFace =
          !attachedFace &&
          detection.label == 'person' &&
          output.faceMatchId != null &&
          output.faceMatchId!.isNotEmpty;
      final attachPlate =
          !attachedPlate &&
          detection.label == 'vehicle' &&
          output.plateNumber != null &&
          output.plateNumber!.isNotEmpty;
      if (confidence < minimumConfidence && !attachFace && !attachPlate) {
        continue;
      }
      records.add(
        _buildDetectionRecord(
          sourceRecord: sourceRecord,
          output: output,
          detection: detection,
          trackId: detection.trackId ?? output.trackId,
          faceMatchId: attachFace ? output.faceMatchId : null,
          faceConfidence: attachFace ? output.faceConfidence : null,
          plateNumber: attachPlate ? output.plateNumber : null,
          plateConfidence: attachPlate ? output.plateConfidence : null,
        ),
      );
      attachedFace = attachedFace || attachFace;
      attachedPlate = attachedPlate || attachPlate;
    }

    if (!attachedFace &&
        output.faceMatchId != null &&
        output.faceMatchId!.isNotEmpty) {
      records.add(
        _buildStandaloneFaceRecord(
          sourceRecord: sourceRecord,
          output: output,
          faceMatchId: output.faceMatchId!,
          faceConfidence: output.faceConfidence ?? 0,
        ),
      );
    }
    if (!attachedPlate &&
        output.plateNumber != null &&
        output.plateNumber!.isNotEmpty) {
      records.add(
        _buildStandalonePlateRecord(
          sourceRecord: sourceRecord,
          output: output,
          plateNumber: output.plateNumber!,
          plateConfidence: output.plateConfidence ?? 0,
        ),
      );
    }
    return records;
  }

  NormalizedIntelRecord _buildDetectionRecord({
    required NormalizedIntelRecord sourceRecord,
    required _YoloDetectionOutput output,
    required _YoloDetectionResult detection,
    String? trackId,
    String? faceMatchId,
    double? faceConfidence,
    String? plateNumber,
    double? plateConfidence,
  }) {
    final objectLabel = detection.label;
    final confidence = detection.confidence > 0
        ? detection.confidence
        : output.confidence ?? sourceRecord.objectConfidence ?? 0;
    final normalizedFaceMatchId = (faceMatchId ?? '').trim().isEmpty
        ? null
        : faceMatchId!.trim().toUpperCase();
    final normalizedPlateNumber = (plateNumber ?? '').trim().isEmpty
        ? null
        : _normalizedPlateNumber(plateNumber!);
    final normalizedTrackId = (trackId ?? '').trim().isEmpty
        ? null
        : trackId!.trim();
    return NormalizedIntelRecord(
      provider: '${sourceRecord.provider}_yolo',
      sourceType: sourceRecord.sourceType,
      externalId: _buildDetectionExternalId(
        sourceExternalId: sourceRecord.externalId,
        objectLabel: objectLabel,
        trackId: normalizedTrackId,
        faceMatchId: normalizedFaceMatchId,
        plateNumber: normalizedPlateNumber,
      ),
      clientId: sourceRecord.clientId,
      regionId: sourceRecord.regionId,
      siteId: sourceRecord.siteId,
      cameraId: sourceRecord.cameraId,
      zone: sourceRecord.zone,
      objectLabel: objectLabel,
      objectConfidence: confidence,
      trackId: normalizedTrackId,
      faceMatchId: normalizedFaceMatchId,
      faceConfidence: faceConfidence,
      plateNumber: normalizedPlateNumber,
      plateConfidence: plateConfidence,
      headline: _headlineFor(
        objectLabel: objectLabel,
        zone: sourceRecord.zone,
        cameraId: sourceRecord.cameraId,
        faceMatchId: normalizedFaceMatchId,
        plateNumber: normalizedPlateNumber,
      ),
      summary: _summaryFor(
        objectLabel: objectLabel,
        confidence: confidence,
        zone: sourceRecord.zone,
        sourceSummary: output.summary,
        faceMatchId: normalizedFaceMatchId,
        faceConfidence: faceConfidence,
        plateNumber: normalizedPlateNumber,
        plateConfidence: plateConfidence,
      ),
      riskScore: _riskScoreFor(
        objectLabel: objectLabel,
        confidence: confidence,
        baseRiskScore: sourceRecord.riskScore,
        faceMatchId: normalizedFaceMatchId,
        plateNumber: normalizedPlateNumber,
      ),
      occurredAtUtc: sourceRecord.occurredAtUtc,
      snapshotUrl: sourceRecord.snapshotUrl,
      clipUrl: sourceRecord.clipUrl,
    );
  }

  NormalizedIntelRecord _buildStandaloneFaceRecord({
    required NormalizedIntelRecord sourceRecord,
    required _YoloDetectionOutput output,
    required String faceMatchId,
    required double faceConfidence,
  }) {
    final normalizedMatch = faceMatchId.trim().toUpperCase();
    final boundedConfidence = faceConfidence.clamp(0, 1).toDouble();
    return NormalizedIntelRecord(
      provider: '${sourceRecord.provider}_fr',
      sourceType: sourceRecord.sourceType,
      externalId:
          '${sourceRecord.externalId}#fr:${_slugToken(normalizedMatch)}',
      clientId: sourceRecord.clientId,
      regionId: sourceRecord.regionId,
      siteId: sourceRecord.siteId,
      cameraId: sourceRecord.cameraId,
      zone: sourceRecord.zone,
      objectLabel: 'person',
      objectConfidence: boundedConfidence,
      faceMatchId: normalizedMatch,
      faceConfidence: boundedConfidence,
      headline: _headlineFor(
        objectLabel: 'person',
        zone: sourceRecord.zone,
        cameraId: sourceRecord.cameraId,
        faceMatchId: normalizedMatch,
      ),
      summary: _summaryFor(
        objectLabel: 'person',
        confidence: boundedConfidence,
        zone: sourceRecord.zone,
        sourceSummary: output.summary,
        faceMatchId: normalizedMatch,
        faceConfidence: boundedConfidence,
      ),
      riskScore: _riskScoreFor(
        objectLabel: 'person',
        confidence: boundedConfidence,
        baseRiskScore: sourceRecord.riskScore,
        faceMatchId: normalizedMatch,
      ),
      occurredAtUtc: sourceRecord.occurredAtUtc,
      snapshotUrl: sourceRecord.snapshotUrl,
      clipUrl: sourceRecord.clipUrl,
    );
  }

  NormalizedIntelRecord _buildStandalonePlateRecord({
    required NormalizedIntelRecord sourceRecord,
    required _YoloDetectionOutput output,
    required String plateNumber,
    required double plateConfidence,
  }) {
    final normalizedPlate = _normalizedPlateNumber(plateNumber);
    final boundedConfidence = plateConfidence.clamp(0, 1).toDouble();
    return NormalizedIntelRecord(
      provider: '${sourceRecord.provider}_lpr',
      sourceType: sourceRecord.sourceType,
      externalId:
          '${sourceRecord.externalId}#lpr:${_slugToken(normalizedPlate)}',
      clientId: sourceRecord.clientId,
      regionId: sourceRecord.regionId,
      siteId: sourceRecord.siteId,
      cameraId: sourceRecord.cameraId,
      zone: sourceRecord.zone,
      objectLabel: 'vehicle',
      objectConfidence: boundedConfidence,
      plateNumber: normalizedPlate,
      plateConfidence: boundedConfidence,
      headline: _headlineFor(
        objectLabel: 'vehicle',
        zone: sourceRecord.zone,
        cameraId: sourceRecord.cameraId,
        plateNumber: normalizedPlate,
      ),
      summary: _summaryFor(
        objectLabel: 'vehicle',
        confidence: boundedConfidence,
        zone: sourceRecord.zone,
        sourceSummary: output.summary,
        plateNumber: normalizedPlate,
        plateConfidence: boundedConfidence,
      ),
      riskScore: _riskScoreFor(
        objectLabel: 'vehicle',
        confidence: boundedConfidence,
        baseRiskScore: sourceRecord.riskScore,
        plateNumber: normalizedPlate,
      ),
      occurredAtUtc: sourceRecord.occurredAtUtc,
      snapshotUrl: sourceRecord.snapshotUrl,
      clipUrl: sourceRecord.clipUrl,
    );
  }

  String? _primaryLabelFrom(Map<String, Object?> item) {
    final direct = _normalizedSemanticLabel(
      (item['primary_label'] ??
              item['primary_object'] ??
              item['object_label'] ??
              item['label'] ??
              '')
          .toString(),
    );
    if (direct != null) {
      return direct;
    }
    final detections = _detectionsFrom(item);
    if (detections.isEmpty) {
      return null;
    }
    final best = detections.reduce((left, right) {
      final priorityCompare = _semanticPriority(
        right.label,
      ).compareTo(_semanticPriority(left.label));
      if (priorityCompare != 0) {
        return priorityCompare > 0 ? right : left;
      }
      return right.confidence >= left.confidence ? right : left;
    });
    return best.label;
  }

  List<_YoloDetectionResult> _detectionsFrom(Map<String, Object?> item) {
    final rawDetections = item['detections'];
    if (rawDetections is! List) {
      return const <_YoloDetectionResult>[];
    }
    final detections = <_YoloDetectionResult>[];
    for (final rawDetection in rawDetections.whereType<Map>()) {
      final detection = rawDetection.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final label = _normalizedSemanticLabel(
        (detection['label'] ?? detection['object_label'] ?? '').toString(),
      );
      final score =
          _doubleValue(detection['confidence']) ??
          _doubleValue(detection['score']) ??
          0;
      if (label == null) {
        continue;
      }
      detections.add(
        _YoloDetectionResult(
          label: label,
          confidence: score,
          trackId: _normalizedString(
            detection['track_id'] ?? detection['trackId'],
          ),
        ),
      );
    }
    return detections;
  }

  String? _normalizedSemanticLabel(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'unknown') {
      return null;
    }
    if (_containsAny(normalized, const <String>[
      'person',
      'human',
      'pedestrian',
      'intruder',
    ])) {
      return 'person';
    }
    if (_containsAny(normalized, const <String>[
      'vehicle',
      'car',
      'truck',
      'van',
      'motorbike',
      'motorcycle',
      'bus',
      'bakkie',
      'pickup',
      'suv',
    ])) {
      return 'vehicle';
    }
    if (_containsAny(normalized, const <String>[
      'animal',
      'dog',
      'cat',
      'horse',
      'bird',
    ])) {
      return 'animal';
    }
    if (_containsAny(normalized, const <String>[
      'backpack',
      'back pack',
      'rucksack',
    ])) {
      return 'backpack';
    }
    if (_containsAny(normalized, const <String>[
      'bag',
      'handbag',
      'purse',
      'duffel',
      'suitcase',
      'luggage',
      'satchel',
      'tote',
    ])) {
      return 'bag';
    }
    if (_containsAny(normalized, const <String>['knife', 'blade', 'machete'])) {
      return 'knife';
    }
    if (_containsAny(normalized, const <String>[
      'crowbar',
      'crow bar',
      'prybar',
      'pry bar',
    ])) {
      return 'weapon';
    }
    if (_containsAny(normalized, const <String>[
      'firearm',
      'pistol',
      'gun',
      'rifle',
      'shotgun',
      'revolver',
    ])) {
      return 'firearm';
    }
    if (normalized.contains('weapon')) {
      return 'weapon';
    }
    return null;
  }

  String _buildDetectionExternalId({
    required String sourceExternalId,
    required String objectLabel,
    String? trackId,
    String? faceMatchId,
    String? plateNumber,
  }) {
    final suffixParts = <String>['yolo:$objectLabel'];
    if ((trackId ?? '').trim().isNotEmpty) {
      suffixParts.add('track:${_slugToken(trackId!.trim())}');
    }
    if ((faceMatchId ?? '').trim().isNotEmpty) {
      suffixParts.add('face:${_slugToken(faceMatchId!.trim().toUpperCase())}');
    }
    if ((plateNumber ?? '').trim().isNotEmpty) {
      suffixParts.add(
        'plate:${_slugToken(_normalizedPlateNumber(plateNumber!))}',
      );
    }
    return '$sourceExternalId#${suffixParts.join(':')}';
  }

  String _headlineFor({
    required String objectLabel,
    required String? zone,
    required String? cameraId,
    String? faceMatchId,
    String? plateNumber,
  }) {
    final hotspot = (zone ?? '').trim().isNotEmpty
        ? zone!.trim()
        : (cameraId ?? '').trim().isNotEmpty
        ? 'Camera ${cameraId!.trim()}'
        : 'the site';
    if ((faceMatchId ?? '').trim().isNotEmpty) {
      return 'ONYX matched an enrolled person near $hotspot';
    }
    if ((plateNumber ?? '').trim().isNotEmpty) {
      return 'ONYX matched vehicle ${_normalizedPlateNumber(plateNumber!)} near $hotspot';
    }
    return 'ONYX observed ${_headlineObjectPhrase(objectLabel)} near $hotspot';
  }

  String _summaryFor({
    required String objectLabel,
    required double confidence,
    required String? zone,
    required String sourceSummary,
    String? faceMatchId,
    double? faceConfidence,
    String? plateNumber,
    double? plateConfidence,
  }) {
    final hotspot = (zone ?? '').trim();
    final baseLine = hotspot.isEmpty
        ? 'ONYX observed ${_summaryObjectPhrase(objectLabel)}.'
        : 'ONYX observed ${_summaryObjectPhrase(objectLabel)} near $hotspot.';
    final confidenceLine = ' Confidence ${confidence.toStringAsFixed(2)}.';
    final identityDetails = <String>[];
    if ((faceMatchId ?? '').trim().isNotEmpty) {
      final faceLine =
          ' ONYX matched an enrolled person'
          '${faceConfidence == null ? '' : ' at ${faceConfidence.toStringAsFixed(2)} confidence'}.';
      identityDetails.add(faceLine);
    }
    if ((plateNumber ?? '').trim().isNotEmpty) {
      final plateLine =
          ' ONYX read vehicle ${_normalizedPlateNumber(plateNumber!)}'
          '${plateConfidence == null ? '' : ' at ${plateConfidence.toStringAsFixed(2)} confidence'}.';
      identityDetails.add(plateLine);
    }
    return '$baseLine$confidenceLine${identityDetails.join()}'.trim();
  }

  int _riskScoreFor({
    required String objectLabel,
    required double confidence,
    required int baseRiskScore,
    String? faceMatchId,
    String? plateNumber,
  }) {
    final labelBoost = switch (objectLabel) {
      'firearm' => 34,
      'weapon' => 30,
      'knife' => 26,
      'person' => 16,
      'vehicle' => 10,
      'backpack' => 14,
      'bag' => 12,
      'animal' => 4,
      _ => 6,
    };
    var score =
        baseRiskScore + labelBoost + (confidence.clamp(0, 1) * 10).round();
    if ((faceMatchId ?? '').trim().isNotEmpty) {
      score += 10;
    }
    if ((plateNumber ?? '').trim().isNotEmpty) {
      score += 8;
    }
    return score.clamp(baseRiskScore, 98);
  }

  String _headlineObjectPhrase(String objectLabel) {
    return switch (objectLabel) {
      'person' => 'person activity',
      'vehicle' => 'vehicle activity',
      'animal' => 'animal activity',
      'backpack' => 'a backpack',
      'bag' => 'a bag',
      'knife' => 'a knife',
      'firearm' => 'a firearm',
      'weapon' => 'a weapon',
      _ => objectLabel,
    };
  }

  String _summaryObjectPhrase(String objectLabel) {
    return switch (objectLabel) {
      'person' => 'person activity',
      'vehicle' => 'vehicle activity',
      'animal' => 'animal activity',
      'backpack' => 'a backpack',
      'bag' => 'a bag',
      'knife' => 'a knife',
      'firearm' => 'a firearm',
      'weapon' => 'a weapon',
      _ => objectLabel,
    };
  }

  String _normalizedPlateNumber(String raw) {
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }

  String _slugToken(String raw) {
    final normalized = raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_').trim();
    return normalized.isEmpty ? 'unknown' : normalized;
  }

  String? _normalizedString(Object? value) {
    final normalized = (value ?? '').toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  int _semanticPriority(String label) {
    return switch (label) {
      'firearm' => 100,
      'weapon' => 96,
      'knife' => 90,
      'person' => 76,
      'vehicle' => 66,
      'backpack' => 54,
      'bag' => 50,
      'animal' => 18,
      _ => 0,
    };
  }

  double? _doubleValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse((value ?? '').toString().trim());
  }

  bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (needle.isEmpty) {
        continue;
      }
      if (haystack.contains(needle)) {
        return true;
      }
    }
    return false;
  }
}

class _YoloDetectionOutput {
  final String recordKey;
  final String? primaryLabel;
  final double? confidence;
  final String summary;
  final List<_YoloDetectionResult> detections;
  final String? trackId;
  final String? faceMatchId;
  final double? faceConfidence;
  final String? plateNumber;
  final double? plateConfidence;

  const _YoloDetectionOutput({
    required this.recordKey,
    required this.primaryLabel,
    this.confidence,
    this.summary = '',
    this.detections = const <_YoloDetectionResult>[],
    this.trackId,
    this.faceMatchId,
    this.faceConfidence,
    this.plateNumber,
    this.plateConfidence,
  });
}

class _YoloDetectionResult {
  final String label;
  final double confidence;
  final String? trackId;

  const _YoloDetectionResult({
    required this.label,
    required this.confidence,
    this.trackId,
  });

  _YoloDetectionResult copyWith({
    String? label,
    double? confidence,
    String? trackId,
  }) {
    return _YoloDetectionResult(
      label: label ?? this.label,
      confidence: confidence ?? this.confidence,
      trackId: trackId ?? this.trackId,
    );
  }
}
