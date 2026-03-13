import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'cctv_false_positive_policy.dart';
import '../domain/intelligence/intel_ingestion.dart';

abstract class CctvBridgeService {
  Future<List<NormalizedIntelRecord>> fetchLatest({
    required String clientId,
    required String regionId,
    required String siteId,
  });
}

class UnconfiguredCctvBridgeService implements CctvBridgeService {
  const UnconfiguredCctvBridgeService();

  @override
  Future<List<NormalizedIntelRecord>> fetchLatest({
    required String clientId,
    required String regionId,
    required String siteId,
  }) async {
    return const [];
  }
}

class HttpCctvBridgeService implements CctvBridgeService {
  final String provider;
  final Uri eventsUri;
  final String? bearerToken;
  final Duration requestTimeout;
  final bool liveMonitoringEnabled;
  final bool facialRecognitionEnabled;
  final bool licensePlateRecognitionEnabled;
  final CctvFalsePositivePolicy falsePositivePolicy;
  final http.Client client;

  const HttpCctvBridgeService({
    required this.provider,
    required this.eventsUri,
    required this.client,
    required this.liveMonitoringEnabled,
    required this.facialRecognitionEnabled,
    required this.licensePlateRecognitionEnabled,
    this.falsePositivePolicy = const CctvFalsePositivePolicy(),
    this.bearerToken,
    this.requestTimeout = const Duration(seconds: 12),
  });

  @override
  Future<List<NormalizedIntelRecord>> fetchLatest({
    required String clientId,
    required String regionId,
    required String siteId,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    final token = bearerToken?.trim();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await client
        .get(eventsUri, headers: headers)
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException('CCTV bridge HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final rows = _decodeRows(decoded);
    final providerLower = _providerKey(provider);
    final normalized = <NormalizedIntelRecord>[];
    for (final row in rows) {
      final parsed = _normalizeEvent(
        payload: _flattenProviderEnvelope(providerLower, row),
        providerLower: providerLower,
        providerLabel: provider,
        fallbackClientId: clientId,
        fallbackRegionId: regionId,
        fallbackSiteId: siteId,
      );
      if (parsed == null) {
        continue;
      }
      normalized.add(parsed);
    }
    return normalized;
  }

  List<Map<String, Object?>> _decodeRows(Object? decoded) {
    final providerLower = _providerKey(provider);
    if (decoded is List) {
      return decoded
          .map(_toObjectMap)
          .map((entry) => _flattenProviderEnvelope(providerLower, entry))
          .toList(growable: false);
    }
    if (decoded is Map) {
      final object = _toObjectMap(decoded);
      final alertEnvelope = object['EventNotificationAlert'];
      if (alertEnvelope is Map) {
        return [
          _flattenProviderEnvelope(providerLower, {
            ...object,
            ..._toObjectMap(alertEnvelope),
          }),
        ];
      }
      final items = object['items'];
      if (items is List) {
        return items
            .map(_toObjectMap)
            .map((entry) => _flattenProviderEnvelope(providerLower, entry))
            .toList(growable: false);
      }
      final events = object['events'];
      if (events is List) {
        return events
            .map(_toObjectMap)
            .map((entry) => _flattenProviderEnvelope(providerLower, entry))
            .toList(growable: false);
      }
      final eventList = object['eventList'];
      if (eventList is List) {
        return eventList
            .map(_toObjectMap)
            .map((entry) => _flattenProviderEnvelope(providerLower, entry))
            .toList(growable: false);
      }
      final result = object['result'];
      if (result is List) {
        return result
            .map(_toObjectMap)
            .map((entry) => _flattenProviderEnvelope(providerLower, entry))
            .toList(growable: false);
      }
      if (result is Map) {
        return [_flattenProviderEnvelope(providerLower, _toObjectMap(result))];
      }
      return [_flattenProviderEnvelope(providerLower, object)];
    }
    return const [];
  }

  NormalizedIntelRecord? _normalizeEvent({
    required Map<String, Object?> payload,
    required String providerLower,
    required String providerLabel,
    required String fallbackClientId,
    required String fallbackRegionId,
    required String fallbackSiteId,
  }) {
    final externalId = _externalId(providerLower, payload);
    final resolvedExternalId = externalId.isEmpty
        ? _synthesizedExternalId(providerLower, payload)
        : externalId;
    if (resolvedExternalId.isEmpty) {
      return null;
    }
    final occurredAtUtc = _occurredAtUtc(payload);
    if (occurredAtUtc == null) {
      return null;
    }
    final eventType = _eventType(providerLower, payload);
    if (providerLower.contains('frigate') &&
        _boolValue(payload, keys: const ['false_positive', 'falsePositive']) ==
            true) {
      return null;
    }
    final cameraId = _stringValue(
      payload,
      keys: const [
        'camera_id',
        'device_id',
        'DeviceSerialNo',
        'source_name',
        'topicSource',
        'channelID',
        'channel',
        'camera',
        'device',
        'source',
      ],
    );
    final zone = _stringListValue(
      payload,
      keys: const ['entered_zones', 'current_zones', 'zones', 'zone'],
    ).join('/');
    final objectLabel = _stringValue(
      payload,
      keys: const [
        'label',
        'sub_label',
        'object_label',
        'objectType',
        'target_label',
      ],
    );
    final objectConfidence = _doubleValue(
      payload,
      keys: const ['top_score', 'score', 'object_score', 'scoreNormalized'],
    );
    final plate = _stringValue(
      payload,
      keys: const [
        'license_plate',
        'licensePlate',
        'PlateNumber',
        'plateNumber',
        'ObjectPlate',
        'plate',
        'plate_no',
        'lpr_plate',
      ],
    );
    final faceId = _stringValue(
      payload,
      keys: const [
        'face_match_id',
        'face_id',
        'person_id',
        'fr_match_id',
        'FaceID',
        'candidateId',
      ],
    );
    final frConfidence = _doubleValue(
      payload,
      keys: const [
        'fr_confidence',
        'face_confidence',
        'face_score',
        'Similarity',
        'candidateScore',
      ],
    );
    final lprConfidence = _doubleValue(
      payload,
      keys: const [
        'lpr_confidence',
        'plate_confidence',
        'plate_score',
        'confidence',
        'confidenceLevel',
      ],
    );

    final summaryBase = _stringValue(
      payload,
      keys: const [
        'summary',
        'description',
        'eventDescription',
        'Code',
        'Name',
        'topic',
        'message',
        'detail',
        'alarm_info',
      ],
    );
    final clientId = _stringValue(
      payload,
      keys: const ['client_id'],
    ).ifEmpty(fallbackClientId);
    final regionId = _stringValue(
      payload,
      keys: const ['region_id'],
    ).ifEmpty(fallbackRegionId);
    final siteId = _stringValue(
      payload,
      keys: const ['site_id'],
    ).ifEmpty(fallbackSiteId);

    final riskScore = _riskScoreFor(
      eventType: eventType,
      objectLabel: objectLabel,
      objectConfidence: objectConfidence,
      plate: plate,
      faceId: faceId,
      frConfidence: frConfidence,
      lprConfidence: lprConfidence,
    );
    if (falsePositivePolicy.shouldSuppress(
      zone: zone,
      objectLabel: objectLabel,
      objectConfidencePercent: _confidencePercent(objectConfidence),
      occurredAtUtc: occurredAtUtc,
    )) {
      return null;
    }

    final headline =
        '${providerLabel.toUpperCase()} ${eventType.toUpperCase()}';
    final snapshotUrl = _snapshotUrl(
      providerLower: providerLower,
      externalId: resolvedExternalId,
      payload: payload,
    );
    final clipUrl = _clipUrl(
      providerLower: providerLower,
      externalId: resolvedExternalId,
      payload: payload,
    );
    final summary = _composeSummary(
      base: summaryBase,
      providerLower: providerLower,
      eventType: eventType,
      cameraId: cameraId,
      zone: zone,
      objectLabel: objectLabel,
      objectConfidence: objectConfidence,
      plate: plate,
      faceId: faceId,
      frConfidence: frConfidence,
      lprConfidence: lprConfidence,
      hasSnapshot:
          _boolValue(payload, keys: const ['has_snapshot', 'hasSnapshot']) ==
          true,
      hasClip: _boolValue(payload, keys: const ['has_clip', 'hasClip']) == true,
    );

    return NormalizedIntelRecord(
      provider: providerLabel,
      sourceType: 'hardware',
      externalId: resolvedExternalId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      cameraId: cameraId.isEmpty ? null : cameraId,
      zone: zone.isEmpty ? null : zone,
      objectLabel: objectLabel.isEmpty ? null : objectLabel,
      objectConfidence: objectConfidence,
      headline: headline,
      summary: summary,
      riskScore: riskScore,
      occurredAtUtc: occurredAtUtc,
      snapshotUrl: snapshotUrl,
      clipUrl: clipUrl,
    );
  }

  int _riskScoreFor({
    required String eventType,
    required String objectLabel,
    required double? objectConfidence,
    required String plate,
    required String faceId,
    required double? frConfidence,
    required double? lprConfidence,
  }) {
    final type = eventType.toLowerCase();
    var risk = switch (type) {
      'intrusion' => 88,
      'breach' => 90,
      'line_crossing' => 84,
      'tamper' => 78,
      'fr_match' => 80,
      'lpr_alert' => 80,
      'motion' => 52,
      _ => 60,
    };
    if (liveMonitoringEnabled) {
      risk += 4;
    }
    if (eventType == 'intrusion' && objectLabel.trim().isNotEmpty) {
      risk += 3;
      if ((_confidencePercent(objectConfidence) ?? 0) >= 90) {
        risk += 2;
      }
    }
    if (facialRecognitionEnabled && faceId.isNotEmpty) {
      risk += 8;
      if ((frConfidence ?? 0) >= 90) {
        risk += 5;
      }
    }
    if (licensePlateRecognitionEnabled && plate.isNotEmpty) {
      risk += 8;
      if ((lprConfidence ?? 0) >= 90) {
        risk += 5;
      }
    }
    return min(99, max(1, risk));
  }

  String _composeSummary({
    required String base,
    required String providerLower,
    required String eventType,
    required String cameraId,
    required String zone,
    required String objectLabel,
    required double? objectConfidence,
    required String plate,
    required String faceId,
    required double? frConfidence,
    required double? lprConfidence,
    required bool hasSnapshot,
    required bool hasClip,
  }) {
    final chips = <String>[];
    if (cameraId.isNotEmpty) {
      chips.add('camera:$cameraId');
    }
    if (zone.isNotEmpty) {
      chips.add('zone:$zone');
    }
    if (objectLabel.isNotEmpty) {
      final confidenceLabel = _confidenceLabel(objectConfidence)?.trim();
      chips.add(
        confidenceLabel == null
            ? 'label:$objectLabel'
            : 'label:$objectLabel $confidenceLabel',
      );
    }
    if (providerLower.contains('dahua')) {
      chips.add('provider:dahua');
    } else if (providerLower.contains('axis')) {
      chips.add('provider:axis');
    } else if (providerLower.contains('hikvision')) {
      chips.add('provider:hikvision');
    } else if (providerLower.contains('frigate')) {
      chips.add('provider:frigate');
    }
    if (faceId.isNotEmpty && facialRecognitionEnabled) {
      final confidence = _confidenceLabel(frConfidence) ?? '';
      chips.add('FR:$faceId$confidence');
    }
    if (plate.isNotEmpty && licensePlateRecognitionEnabled) {
      final confidence = _confidenceLabel(lprConfidence) ?? '';
      chips.add('LPR:$plate$confidence');
    }
    if (hasSnapshot) {
      chips.add('snapshot:available');
    }
    if (hasClip) {
      chips.add('clip:available');
    }
    final enrich = chips.isEmpty ? '' : ' • ${chips.join(' • ')}';
    final trimmedBase = base.trim();
    if (trimmedBase.isEmpty) {
      if (objectLabel.isNotEmpty && zone.isNotEmpty) {
        return 'CCTV ${objectLabel.toLowerCase()} detected in $zone$enrich';
      }
      if (objectLabel.isNotEmpty) {
        return 'CCTV ${objectLabel.toLowerCase()} event ingested$enrich';
      }
      return 'CCTV ${eventType.toLowerCase()} event ingested$enrich';
    }
    return '$trimmedBase$enrich';
  }

  String _externalId(String providerLower, Map<String, Object?> payload) {
    if (providerLower.contains('hikvision')) {
      return _stringValue(
        payload,
        keys: const [
          'event_id',
          'eventId',
          'alarm_id',
          'id',
          'external_id',
          'activePostCount',
          'uuid',
        ],
      );
    }
    if (providerLower.contains('dahua')) {
      return _stringValue(
        payload,
        keys: const [
          'event_id',
          'EventID',
          'Index',
          'Code',
          'id',
          'external_id',
        ],
      );
    }
    if (providerLower.contains('axis')) {
      return _stringValue(
        payload,
        keys: const [
          'id',
          'event_id',
          'topic_id',
          'messageId',
          'sequence',
          'external_id',
        ],
      );
    }
    if (providerLower.contains('frigate')) {
      return _stringValue(
        payload,
        keys: const ['id', 'event_id', 'eventId', 'external_id'],
      );
    }
    return _stringValue(
      payload,
      keys: const ['event_id', 'id', 'external_id', 'message_id'],
    );
  }

  String _eventType(String providerLower, Map<String, Object?> payload) {
    if (providerLower.contains('hikvision')) {
      final raw = _stringValue(
        payload,
        keys: const [
          'event_type',
          'eventType',
          'alarm_type',
          'type',
          'eventTypeEx',
          'eventDescription',
          'eventState',
        ],
      ).ifEmpty('intrusion');
      return _mapHikvisionType(raw);
    }
    if (providerLower.contains('dahua')) {
      final raw = _stringValue(
        payload,
        keys: const ['event_type', 'Code', 'action', 'type'],
      ).ifEmpty('intrusion');
      return _mapDahuaType(raw);
    }
    if (providerLower.contains('axis')) {
      final raw = _stringValue(
        payload,
        keys: const ['event_type', 'topic', 'topic1', 'type', 'name'],
      ).ifEmpty('intrusion');
      return _mapAxisType(raw);
    }
    if (providerLower.contains('frigate')) {
      return _mapFrigateType(payload);
    }
    return _stringValue(
      payload,
      keys: const ['event_type', 'type', 'alarm_type', 'topic'],
    ).ifEmpty('intrusion');
  }

  DateTime? _occurredAtUtc(Map<String, Object?> payload) {
    final raw = _firstValue(
      payload,
      keys: const [
        'occurred_at_utc',
        'occurred_at',
        'timestamp',
        'UTC',
        'CurrentTime',
        'StartTime',
        'created_at',
        'dateTime',
        'eventTime',
        'start_time',
        'end_time',
      ],
    );
    return _parseOccurredAtUtc(raw);
  }

  String _mapHikvisionType(String raw) {
    final normalized = _normalizeKey(raw);
    return switch (normalized) {
      'linedetection' || 'linecrossing' => 'line_crossing',
      'fielddetection' ||
      'intrusion' ||
      'regionentrance' ||
      'regionexit' => 'intrusion',
      'tamperdetection' || 'tamper' => 'tamper',
      'facesnap' || 'facematch' || 'facedetection' => 'fr_match',
      'plate' || 'licenseplate' || 'vehicledetection' => 'lpr_alert',
      'motion' || 'videomotion' => 'motion',
      _ => raw.ifEmpty('intrusion').toLowerCase(),
    };
  }

  String _mapDahuaType(String raw) {
    final normalized = _normalizeKey(raw);
    return switch (normalized) {
      'crossline' || 'tripwire' || 'linecrossing' => 'line_crossing',
      'regionalintrusion' || 'intrusion' || 'alarmlocal' => 'intrusion',
      'videomotion' || 'motiondetect' || 'motion' => 'motion',
      'facedetection' || 'facerecognition' || 'facecompare' => 'fr_match',
      'trafficjunction' || 'trafficcrosslane' || 'trafficplate' => 'lpr_alert',
      'tamper' || 'videoblind' => 'tamper',
      _ => raw.ifEmpty('intrusion').toLowerCase(),
    };
  }

  String _mapAxisType(String raw) {
    final normalized = _normalizeKey(raw);
    if (normalized.contains('crossline') ||
        normalized.contains('linecrossing')) {
      return 'line_crossing';
    }
    if (normalized.contains('motion') || normalized.contains('vmd')) {
      return 'motion';
    }
    if (normalized.contains('fenceguard') || normalized.contains('intrusion')) {
      return 'intrusion';
    }
    if (normalized.contains('tamper')) {
      return 'tamper';
    }
    if (normalized.contains('face')) {
      return 'fr_match';
    }
    if (normalized.contains('licenseplate') || normalized.contains('lpr')) {
      return 'lpr_alert';
    }
    return raw.ifEmpty('intrusion').toLowerCase();
  }

  String _mapFrigateType(Map<String, Object?> payload) {
    final raw = _stringValue(
      payload,
      keys: const ['event_type', 'type', 'topic', 'name'],
    ).toLowerCase();
    final label = _stringValue(
      payload,
      keys: const ['label', 'sub_label', 'object_label'],
    ).toLowerCase();
    final zones = _stringListValue(
      payload,
      keys: const ['entered_zones', 'current_zones', 'zones', 'zone'],
    );
    if (label.contains('plate') ||
        raw.contains('plate') ||
        raw.contains('license')) {
      return 'lpr_alert';
    }
    if (label.contains('face') || raw.contains('face')) {
      return 'fr_match';
    }
    if (raw.contains('motion')) {
      return 'motion';
    }
    if (label.isNotEmpty || zones.isNotEmpty) {
      return 'intrusion';
    }
    return 'motion';
  }

  Map<String, Object?> _flattenProviderEnvelope(
    String providerLower,
    Map<String, Object?> object,
  ) {
    if (providerLower.contains('hikvision')) {
      return _hikvisionFlatten(object);
    }
    if (providerLower.contains('dahua')) {
      return _dahuaFlatten(object);
    }
    if (providerLower.contains('axis')) {
      return _axisFlatten(object);
    }
    if (providerLower.contains('frigate')) {
      return _frigateFlatten(object);
    }
    return object;
  }

  Map<String, Object?> _hikvisionFlatten(Map<String, Object?> object) {
    final alert = object['EventNotificationAlert'];
    if (alert is! Map) {
      return object;
    }
    final flat = <String, Object?>{
      for (final entry in object.entries)
        if (entry.key != 'EventNotificationAlert') entry.key: entry.value,
    };
    final alertMap = _toObjectMap(alert);
    flat.addAll(alertMap);
    return flat;
  }

  Map<String, Object?> _dahuaFlatten(Map<String, Object?> object) {
    final info = object['Info'];
    if (info is! Map) {
      return object;
    }
    final flat = <String, Object?>{
      for (final entry in object.entries)
        if (entry.key != 'Info') entry.key: entry.value,
    };
    flat.addAll(_toObjectMap(info));
    return flat;
  }

  Map<String, Object?> _axisFlatten(Map<String, Object?> object) {
    final message = object['message'];
    if (message is! Map) {
      return object;
    }
    final flat = <String, Object?>{
      for (final entry in object.entries)
        if (entry.key != 'message') entry.key: entry.value,
    };
    flat.addAll(_toObjectMap(message));
    return flat;
  }

  Map<String, Object?> _frigateFlatten(Map<String, Object?> object) {
    final after = object['after'];
    if (after is! Map) {
      return object;
    }
    final flat = <String, Object?>{
      for (final entry in object.entries)
        if (entry.key != 'after' && entry.key != 'before')
          entry.key: entry.value,
    };
    flat['frigate_event_type'] = object['type'];
    flat.addAll(_toObjectMap(after));
    return flat;
  }

  String _synthesizedExternalId(
    String providerLower,
    Map<String, Object?> payload,
  ) {
    final timestamp = _stringValue(
      payload,
      keys: const [
        'occurred_at_utc',
        'occurred_at',
        'timestamp',
        'created_at',
        'dateTime',
      ],
    );
    final eventType = _eventType(providerLower, payload);
    final camera = _stringValue(
      payload,
      keys: const ['camera_id', 'device_id', 'channelID', 'channel', 'camera'],
    );
    final marker = '$providerLower|$timestamp|$eventType|$camera';
    if (marker.trim().isEmpty) {
      return '';
    }
    final digest = sha256.convert(utf8.encode(marker)).toString();
    return 'CCTV-${digest.substring(0, 20)}';
  }

  static Map<String, Object?> _toObjectMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, entry) => MapEntry(key.toString(), entry as Object?),
      );
    }
    return const {};
  }

  static String _stringValue(
    Map<String, Object?> map, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final raw = _firstValue(map, keys: [key]);
      if (raw is String && raw.trim().isNotEmpty) {
        return raw.trim();
      }
      if (raw is num) {
        return raw.toString();
      }
    }
    return '';
  }

  static double? _doubleValue(
    Map<String, Object?> map, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final raw = _firstValue(map, keys: [key]);
      if (raw is num) {
        return raw.toDouble();
      }
      if (raw is String) {
        final parsed = double.tryParse(raw.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static bool? _boolValue(
    Map<String, Object?> map, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final raw = _firstValue(map, keys: [key]);
      if (raw is bool) {
        return raw;
      }
      if (raw is num) {
        return raw != 0;
      }
      if (raw is String) {
        final normalized = raw.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
          return true;
        }
        if (normalized == 'false' || normalized == '0' || normalized == 'no') {
          return false;
        }
      }
    }
    return null;
  }

  static List<String> _stringListValue(
    Map<String, Object?> map, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final raw = _firstValue(map, keys: [key]);
      if (raw is List) {
        final values = raw
            .map((entry) => entry?.toString().trim() ?? '')
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false);
        if (values.isNotEmpty) {
          return values;
        }
      }
      if (raw is String && raw.trim().isNotEmpty) {
        return [raw.trim()];
      }
    }
    return const [];
  }

  static Object? _firstValue(
    Map<String, Object?> map, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final raw = _findByKey(map, key);
      if (raw != null) {
        return raw;
      }
    }
    return null;
  }

  static DateTime? _parseOccurredAtUtc(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is num) {
      return _fromEpoch(raw.toDouble());
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      final numeric = double.tryParse(trimmed);
      if (numeric != null) {
        return _fromEpoch(numeric);
      }
      return DateTime.tryParse(trimmed)?.toUtc();
    }
    return null;
  }

  static DateTime _fromEpoch(double value) {
    final millis = value > 9999999999 ? value.round() : (value * 1000).round();
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  static double? _confidencePercent(double? value) {
    if (value == null) {
      return null;
    }
    if (value >= 0 && value <= 1) {
      return value * 100;
    }
    return value;
  }

  static String? _confidenceLabel(double? value) {
    final percent = _confidencePercent(value);
    if (percent == null) {
      return null;
    }
    return ' ${percent.toStringAsFixed(1)}%';
  }

  static Object? _findByKey(Object? node, String wantedKey) {
    final normalizedWanted = _normalizeKey(wantedKey);
    if (node is Map) {
      for (final entry in node.entries) {
        if (_normalizeKey(entry.key.toString()) == normalizedWanted) {
          return entry.value;
        }
      }
      for (final entry in node.entries) {
        final nested = _findByKey(entry.value, wantedKey);
        if (nested != null) {
          return nested;
        }
      }
      return null;
    }
    if (node is List) {
      for (final entry in node) {
        final nested = _findByKey(entry, wantedKey);
        if (nested != null) {
          return nested;
        }
      }
    }
    return null;
  }

  static String _normalizeKey(String raw) {
    return raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static String _providerKey(String raw) {
    return raw.trim().toLowerCase();
  }

  String? _snapshotUrl({
    required String providerLower,
    required String externalId,
    required Map<String, Object?> payload,
  }) {
    final explicit = _stringValue(
      payload,
      keys: const [
        'snapshot_url',
        'snapshotUrl',
        'snapshot_uri',
        'snapshotUri',
      ],
    );
    if (explicit.isNotEmpty) {
      return explicit;
    }
    final hasSnapshot = _boolValue(
      payload,
      keys: const ['has_snapshot', 'hasSnapshot'],
    );
    if (providerLower.contains('frigate') &&
        externalId.isNotEmpty &&
        hasSnapshot != false) {
      return _frigateMediaUrl(externalId, 'snapshot.jpg');
    }
    return null;
  }

  String? _clipUrl({
    required String providerLower,
    required String externalId,
    required Map<String, Object?> payload,
  }) {
    final explicit = _stringValue(
      payload,
      keys: const ['clip_url', 'clipUrl', 'clip_uri', 'clipUri'],
    );
    if (explicit.isNotEmpty) {
      return explicit;
    }
    final hasClip = _boolValue(payload, keys: const ['has_clip', 'hasClip']);
    if (providerLower.contains('frigate') &&
        externalId.isNotEmpty &&
        hasClip != false) {
      return _frigateMediaUrl(externalId, 'clip.mp4');
    }
    return null;
  }

  String _frigateMediaUrl(String externalId, String suffix) {
    final pathSegments = <String>['api', 'events', externalId, suffix];
    return eventsUri
        .replace(
          pathSegments: pathSegments,
          queryParameters: null,
          fragment: null,
        )
        .toString();
  }
}

CctvBridgeService createCctvBridgeService({
  required String provider,
  required Uri? eventsUri,
  required String bearerToken,
  required bool liveMonitoringEnabled,
  required bool facialRecognitionEnabled,
  required bool licensePlateRecognitionEnabled,
  CctvFalsePositivePolicy falsePositivePolicy = const CctvFalsePositivePolicy(),
  required http.Client client,
  Duration requestTimeout = const Duration(seconds: 12),
}) {
  final trimmedProvider = provider.trim();
  if (trimmedProvider.isEmpty || eventsUri == null) {
    return const UnconfiguredCctvBridgeService();
  }
  return HttpCctvBridgeService(
    provider: trimmedProvider,
    eventsUri: eventsUri,
    bearerToken: bearerToken.trim().isEmpty ? null : bearerToken.trim(),
    liveMonitoringEnabled: liveMonitoringEnabled,
    facialRecognitionEnabled: facialRecognitionEnabled,
    licensePlateRecognitionEnabled: licensePlateRecognitionEnabled,
    falsePositivePolicy: falsePositivePolicy,
    requestTimeout: requestTimeout,
    client: client,
  );
}

extension _StringExt on String {
  String ifEmpty(String fallback) {
    if (trim().isEmpty) {
      return fallback;
    }
    return this;
  }
}
