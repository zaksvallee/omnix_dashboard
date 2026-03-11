import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

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
  final http.Client client;

  const HttpCctvBridgeService({
    required this.provider,
    required this.eventsUri,
    required this.client,
    required this.liveMonitoringEnabled,
    required this.facialRecognitionEnabled,
    required this.licensePlateRecognitionEnabled,
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
      plate: plate,
      faceId: faceId,
      frConfidence: frConfidence,
      lprConfidence: lprConfidence,
    );

    final headline =
        '${providerLabel.toUpperCase()} ${eventType.toUpperCase()}';
    final summary = _composeSummary(
      base: summaryBase,
      providerLower: providerLower,
      eventType: eventType,
      cameraId: cameraId,
      plate: plate,
      faceId: faceId,
      frConfidence: frConfidence,
      lprConfidence: lprConfidence,
    );

    return NormalizedIntelRecord(
      provider: providerLabel,
      sourceType: 'hardware',
      externalId: resolvedExternalId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      headline: headline,
      summary: summary,
      riskScore: riskScore,
      occurredAtUtc: occurredAtUtc,
    );
  }

  int _riskScoreFor({
    required String eventType,
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
    required String plate,
    required String faceId,
    required double? frConfidence,
    required double? lprConfidence,
  }) {
    final chips = <String>[];
    if (cameraId.isNotEmpty) {
      chips.add('camera:$cameraId');
    }
    if (providerLower.contains('dahua')) {
      chips.add('provider:dahua');
    } else if (providerLower.contains('axis')) {
      chips.add('provider:axis');
    } else if (providerLower.contains('hikvision')) {
      chips.add('provider:hikvision');
    }
    if (faceId.isNotEmpty && facialRecognitionEnabled) {
      final confidence = frConfidence == null
          ? ''
          : ' ${frConfidence.toStringAsFixed(1)}%';
      chips.add('FR:$faceId$confidence');
    }
    if (plate.isNotEmpty && licensePlateRecognitionEnabled) {
      final confidence = lprConfidence == null
          ? ''
          : ' ${lprConfidence.toStringAsFixed(1)}%';
      chips.add('LPR:$plate$confidence');
    }
    final enrich = chips.isEmpty ? '' : ' • ${chips.join(' • ')}';
    if (base.trim().isEmpty) {
      return 'CCTV ${eventType.toLowerCase()} event ingested$enrich';
    }
    return '${base.trim()}$enrich';
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
    return _stringValue(
      payload,
      keys: const ['event_type', 'type', 'alarm_type', 'topic'],
    ).ifEmpty('intrusion');
  }

  DateTime? _occurredAtUtc(Map<String, Object?> payload) {
    final raw = _stringValue(
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
      ],
    );
    if (raw.isEmpty) {
      return null;
    }
    final numeric = int.tryParse(raw);
    if (numeric != null) {
      final millis = numeric > 9999999999 ? numeric : numeric * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    }
    return DateTime.tryParse(raw)?.toUtc();
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
      keys: const ['camera_id', 'device_id', 'channelID', 'channel'],
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
      final raw = _findByKey(map, key);
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
      final raw = _findByKey(map, key);
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
}

CctvBridgeService createCctvBridgeService({
  required String provider,
  required Uri? eventsUri,
  required String bearerToken,
  required bool liveMonitoringEnabled,
  required bool facialRecognitionEnabled,
  required bool licensePlateRecognitionEnabled,
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
