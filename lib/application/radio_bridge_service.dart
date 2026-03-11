import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class RadioTransmissionRecord {
  final String transmissionId;
  final String provider;
  final String channel;
  final String speakerRole;
  final String speakerId;
  final String transcript;
  final DateTime occurredAtUtc;
  final String clientId;
  final String regionId;
  final String siteId;
  final String? dispatchId;

  const RadioTransmissionRecord({
    required this.transmissionId,
    required this.provider,
    required this.channel,
    required this.speakerRole,
    required this.speakerId,
    required this.transcript,
    required this.occurredAtUtc,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    this.dispatchId,
  });
}

class RadioAutomatedResponse {
  final String transmissionId;
  final String provider;
  final String channel;
  final String clientId;
  final String regionId;
  final String siteId;
  final String? dispatchId;
  final String message;
  final String responseType;
  final String intent;

  const RadioAutomatedResponse({
    required this.transmissionId,
    required this.provider,
    required this.channel,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.message,
    this.dispatchId,
    this.responseType = 'AI_RADIO_ACK',
    this.intent = 'unknown',
  });

  factory RadioAutomatedResponse.fromJson(Map<String, Object?> json) {
    final rawResponseType = (json['response_type'] ?? '').toString().trim();
    final rawIntent = (json['intent'] ?? '').toString().trim();
    return RadioAutomatedResponse(
      transmissionId: (json['transmission_id'] ?? '').toString().trim(),
      provider: (json['provider'] ?? '').toString().trim(),
      channel: (json['channel'] ?? '').toString().trim(),
      clientId: (json['client_id'] ?? '').toString().trim(),
      regionId: (json['region_id'] ?? '').toString().trim(),
      siteId: (json['site_id'] ?? '').toString().trim(),
      dispatchId: (json['dispatch_id'] ?? '').toString().trim().nullIfEmpty,
      message: (json['message'] ?? '').toString().trim(),
      responseType: rawResponseType.isEmpty ? 'AI_RADIO_ACK' : rawResponseType,
      intent: rawIntent.isEmpty ? 'unknown' : rawIntent,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'transmission_id': transmissionId,
      'provider': provider,
      'channel': channel,
      'client_id': clientId,
      'region_id': regionId,
      'site_id': siteId,
      'dispatch_id': dispatchId,
      'message': message,
      'response_type': responseType,
      'intent': intent,
    };
  }
}

class RadioResponseSendResult {
  final List<RadioAutomatedResponse> sent;
  final List<RadioAutomatedResponse> failed;

  const RadioResponseSendResult({required this.sent, required this.failed});

  int get sentCount => sent.length;
}

abstract class RadioBridgeService {
  Future<List<RadioTransmissionRecord>> fetchLatest({
    required String clientId,
    required String regionId,
    required String siteId,
  });

  Future<RadioResponseSendResult> sendAutomatedResponses({
    required List<RadioAutomatedResponse> responses,
  });
}

class UnconfiguredRadioBridgeService implements RadioBridgeService {
  const UnconfiguredRadioBridgeService();

  @override
  Future<List<RadioTransmissionRecord>> fetchLatest({
    required String clientId,
    required String regionId,
    required String siteId,
  }) async {
    return const [];
  }

  @override
  Future<RadioResponseSendResult> sendAutomatedResponses({
    required List<RadioAutomatedResponse> responses,
  }) async {
    return RadioResponseSendResult(sent: const [], failed: responses);
  }
}

class HttpRadioBridgeService implements RadioBridgeService {
  final String provider;
  final Uri listenUri;
  final Uri? respondUri;
  final String? bearerToken;
  final Duration requestTimeout;
  final http.Client client;

  const HttpRadioBridgeService({
    required this.provider,
    required this.listenUri,
    required this.respondUri,
    required this.client,
    this.bearerToken,
    this.requestTimeout = const Duration(seconds: 12),
  });

  @override
  Future<List<RadioTransmissionRecord>> fetchLatest({
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
        .get(listenUri, headers: headers)
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException('Radio bridge HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final rows = _decodeRows(decoded);

    final transmissions = <RadioTransmissionRecord>[];
    for (final row in rows) {
      final map = Map<String, Object?>.from(
        row.map((key, value) => MapEntry(key.toString(), value)),
      );
      final transcript = _stringValue(
        map,
        keys: const ['transcript', 'message', 'text', 'body', 'content'],
      );
      if (transcript.isEmpty) {
        continue;
      }
      final transmissionId = _stringValue(
        map,
        keys: const [
          'transmission_id',
          'message_id',
          'id',
          'external_id',
          'uuid',
        ],
      );
      final resolvedTransmissionId = transmissionId.isEmpty
          ? _synthesizedTransmissionId(map, transcript: transcript)
          : transmissionId;
      if (resolvedTransmissionId.isEmpty) {
        continue;
      }
      final occurredAtUtc =
          _timestampValue(
            map,
            keys: const [
              'occurred_at_utc',
              'occurred_at',
              'timestamp',
              'created_at',
              'time',
              'sent_at',
            ],
          ) ??
          DateTime.now().toUtc();
      transmissions.add(
        RadioTransmissionRecord(
          transmissionId: resolvedTransmissionId,
          provider: provider.isEmpty ? 'radio' : provider,
          channel: _channelValue(map),
          speakerRole: _speakerRoleValue(map),
          speakerId: _speakerIdValue(map),
          transcript: transcript,
          occurredAtUtc: occurredAtUtc,
          clientId: _stringValue(
            map,
            keys: const ['client_id'],
          ).ifEmpty(clientId),
          regionId: _stringValue(
            map,
            keys: const ['region_id'],
          ).ifEmpty(regionId),
          siteId: _stringValue(map, keys: const ['site_id']).ifEmpty(siteId),
          dispatchId: _stringValue(
            map,
            keys: const ['dispatch_id', 'incident_id', 'inc_id'],
          ).nullIfEmpty,
        ),
      );
    }
    return transmissions;
  }

  @override
  Future<RadioResponseSendResult> sendAutomatedResponses({
    required List<RadioAutomatedResponse> responses,
  }) async {
    final targetUri = respondUri;
    if (targetUri == null || responses.isEmpty) {
      return RadioResponseSendResult(sent: const [], failed: responses);
    }
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final token = bearerToken?.trim();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final sent = <RadioAutomatedResponse>[];
    final failed = <RadioAutomatedResponse>[];
    for (final response in responses) {
      final payload = {
        'transmission_id': response.transmissionId,
        'provider': response.provider,
        'channel': response.channel,
        'client_id': response.clientId,
        'region_id': response.regionId,
        'site_id': response.siteId,
        'dispatch_id': response.dispatchId,
        'message': response.message,
        'response_type': response.responseType,
        'intent': response.intent,
        'occurred_at_utc': DateTime.now().toUtc().toIso8601String(),
      };
      try {
        final httpResponse = await client
            .post(targetUri, headers: headers, body: jsonEncode(payload))
            .timeout(requestTimeout);
        if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
          failed.add(response);
          continue;
        }
        sent.add(response);
      } catch (_) {
        failed.add(response);
      }
    }
    return RadioResponseSendResult(sent: sent, failed: failed);
  }

  List<Map<dynamic, dynamic>> _decodeRows(Object? decoded) {
    if (decoded is List) {
      return decoded.whereType<Map>().cast<Map<dynamic, dynamic>>().toList();
    }
    if (decoded is! Map) {
      return const [];
    }
    final asMap = Map<dynamic, dynamic>.from(decoded);
    final items = asMap['items'];
    if (items is List) {
      return items.whereType<Map>().cast<Map<dynamic, dynamic>>().toList();
    }
    final messages = asMap['messages'];
    if (messages is List) {
      return messages.whereType<Map>().cast<Map<dynamic, dynamic>>().toList();
    }
    final data = asMap['data'];
    if (data is Map) {
      final nested = data['messages'];
      if (nested is List) {
        return nested.whereType<Map>().cast<Map<dynamic, dynamic>>().toList();
      }
      final nestedItems = data['items'];
      if (nestedItems is List) {
        return nestedItems
            .whereType<Map>()
            .cast<Map<dynamic, dynamic>>()
            .toList();
      }
    }
    return [asMap];
  }

  String _channelValue(Map<String, Object?> map) {
    final direct = _stringValue(
      map,
      keys: const ['channel', 'room', 'group', 'channel_name'],
    );
    if (direct.isNotEmpty) {
      return direct;
    }
    final channelMap = _mapValue(map, keys: const ['channel', 'room', 'group']);
    if (channelMap.isEmpty) {
      return '';
    }
    return _stringValue(
      channelMap,
      keys: const ['name', 'label', 'id', 'channel_name'],
    );
  }

  String _speakerIdValue(Map<String, Object?> map) {
    final direct = _stringValue(
      map,
      keys: const ['speaker_id', 'sender_id', 'callsign', 'from', 'username'],
    );
    if (direct.isNotEmpty) {
      return direct;
    }
    final source = _mapValue(
      map,
      keys: const ['from', 'sender', 'speaker', 'user', 'origin'],
    );
    if (source.isEmpty) {
      return '';
    }
    return _stringValue(
      source,
      keys: const ['callsign', 'name', 'username', 'id'],
    );
  }

  String _speakerRoleValue(Map<String, Object?> map) {
    final direct = _stringValue(
      map,
      keys: const ['speaker_role', 'role', 'type'],
    );
    if (direct.isNotEmpty) {
      return direct;
    }
    final source = _mapValue(
      map,
      keys: const ['from', 'sender', 'speaker', 'user', 'origin'],
    );
    if (source.isEmpty) {
      return '';
    }
    return _stringValue(source, keys: const ['role', 'type']);
  }

  String _synthesizedTransmissionId(
    Map<String, Object?> map, {
    required String transcript,
  }) {
    final timestamp =
        _timestampValue(
          map,
          keys: const [
            'occurred_at_utc',
            'occurred_at',
            'timestamp',
            'created_at',
            'time',
          ],
        )?.toIso8601String() ??
        '';
    final speaker = _speakerIdValue(map);
    final channel = _channelValue(map);
    final canonical = '$provider|$timestamp|$speaker|$channel|$transcript';
    if (canonical.trim().isEmpty) {
      return '';
    }
    final digest = sha256.convert(utf8.encode(canonical)).toString();
    return 'RAD-${digest.substring(0, 20)}';
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

  static DateTime? _timestampValue(
    Map<String, Object?> map, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final raw = _findByKey(map, key);
      if (raw is num) {
        final millis = raw > 9999999999 ? raw.toInt() : raw.toInt() * 1000;
        return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      }
      if (raw is String) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        final numeric = int.tryParse(trimmed);
        if (numeric != null) {
          final millis = numeric > 9999999999 ? numeric : numeric * 1000;
          return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
        }
        final parsed = DateTime.tryParse(trimmed)?.toUtc();
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

  static Map<String, Object?> _mapValue(
    Map<String, Object?> map, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final raw = _findByKey(map, key);
      if (raw is Map<String, Object?>) {
        return raw;
      }
      if (raw is Map) {
        return raw.map(
          (entryKey, value) => MapEntry(entryKey.toString(), value as Object?),
        );
      }
    }
    return const {};
  }

  static String _normalizeKey(String raw) {
    return raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}

RadioBridgeService createRadioBridgeService({
  required String provider,
  required Uri? listenUri,
  required Uri? respondUri,
  required String bearerToken,
  required http.Client client,
  Duration requestTimeout = const Duration(seconds: 12),
}) {
  if (listenUri == null || provider.trim().isEmpty) {
    return const UnconfiguredRadioBridgeService();
  }
  return HttpRadioBridgeService(
    provider: provider.trim(),
    listenUri: listenUri,
    respondUri: respondUri,
    bearerToken: bearerToken.trim().isEmpty ? null : bearerToken.trim(),
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

  String? get nullIfEmpty {
    if (trim().isEmpty) {
      return null;
    }
    return this;
  }
}
