import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../domain/intelligence/intel_ingestion.dart';

abstract class WearableBridgeService {
  Future<List<NormalizedIntelRecord>> fetchLatest({
    required String clientId,
    required String regionId,
    required String siteId,
  });
}

class UnconfiguredWearableBridgeService implements WearableBridgeService {
  const UnconfiguredWearableBridgeService();

  @override
  Future<List<NormalizedIntelRecord>> fetchLatest({
    required String clientId,
    required String regionId,
    required String siteId,
  }) async {
    return const [];
  }
}

class HttpWearableBridgeService implements WearableBridgeService {
  final String provider;
  final Uri eventsUri;
  final String? bearerToken;
  final Duration requestTimeout;
  final http.Client client;

  const HttpWearableBridgeService({
    required this.provider,
    required this.eventsUri,
    required this.client,
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
      throw FormatException('Wearable bridge HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final rows = _decodeRows(decoded);
    final normalized = <NormalizedIntelRecord>[];
    for (final row in rows) {
      final parsed = _normalizeEvent(
        payload: row,
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
    if (decoded is List) {
      return decoded.map(_toObjectMap).toList(growable: false);
    }
    if (decoded is Map) {
      final object = _toObjectMap(decoded);
      final items = object['items'];
      if (items is List) {
        return items.map(_toObjectMap).toList(growable: false);
      }
      final events = object['events'];
      if (events is List) {
        return events.map(_toObjectMap).toList(growable: false);
      }
      return [object];
    }
    return const [];
  }

  NormalizedIntelRecord? _normalizeEvent({
    required Map<String, Object?> payload,
    required String fallbackClientId,
    required String fallbackRegionId,
    required String fallbackSiteId,
  }) {
    final externalId = _stringValue(
      payload,
      keys: const ['event_id', 'alert_id', 'id', 'external_id'],
    );
    if (externalId.isEmpty) {
      return null;
    }
    final occurredAtUtc = _occurredAtUtc(payload);
    if (occurredAtUtc == null) {
      return null;
    }
    final eventType = _stringValue(
      payload,
      keys: const ['event_type', 'alert_type', 'type', 'status'],
    ).ifEmpty('telemetry_alert');
    final officerId = _stringValue(
      payload,
      keys: const [
        'officer_id',
        'guard_id',
        'wearer_id',
        'callsign',
        'device_id',
      ],
    );
    final heartRate = _intValue(
      payload,
      keys: const ['heart_rate', 'hr', 'pulse'],
    );
    final battery = _intValue(
      payload,
      keys: const ['battery_percent', 'battery', 'battery_level'],
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
      heartRate: heartRate,
      batteryPercent: battery,
    );
    final summaryBase = _stringValue(
      payload,
      keys: const ['summary', 'description', 'message', 'detail'],
    );
    final summary = _composeSummary(
      base: summaryBase,
      officerId: officerId,
      heartRate: heartRate,
      batteryPercent: battery,
    );

    return NormalizedIntelRecord(
      provider: provider.trim(),
      sourceType: 'wearable',
      externalId: externalId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      headline: '${provider.toUpperCase()} ${eventType.toUpperCase()}',
      summary: summary,
      riskScore: riskScore,
      occurredAtUtc: occurredAtUtc,
    );
  }

  int _riskScoreFor({
    required String eventType,
    required int? heartRate,
    required int? batteryPercent,
  }) {
    final type = eventType.toLowerCase();
    var score = switch (type) {
      'panic' => 98,
      'sos' => 98,
      'duress' => 98,
      'man_down' => 96,
      'fall' => 90,
      'geofence_breach' => 88,
      'off_route' => 86,
      'heart_rate_alert' => 84,
      'biometric_alert' => 82,
      'battery_low' => 66,
      'check_in' => 45,
      _ => 58,
    };
    if (heartRate != null && (heartRate > 130 || heartRate < 45)) {
      score += 8;
    }
    if (batteryPercent != null && batteryPercent <= 20) {
      score += 4;
    }
    return min(99, max(1, score));
  }

  String _composeSummary({
    required String base,
    required String officerId,
    required int? heartRate,
    required int? batteryPercent,
  }) {
    final chips = <String>[];
    if (officerId.isNotEmpty) {
      chips.add('officer:$officerId');
    }
    if (heartRate != null) {
      chips.add('HR:${heartRate}bpm');
    }
    if (batteryPercent != null) {
      chips.add('battery:$batteryPercent%');
    }
    final enrich = chips.isEmpty ? '' : ' • ${chips.join(' • ')}';
    if (base.trim().isEmpty) {
      return 'Wearable signal ingested$enrich';
    }
    return '${base.trim()}$enrich';
  }

  DateTime? _occurredAtUtc(Map<String, Object?> payload) {
    final raw = _stringValue(
      payload,
      keys: const ['occurred_at_utc', 'occurred_at', 'timestamp', 'created_at'],
    );
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
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
      final raw = map[key];
      if (raw is String && raw.trim().isNotEmpty) {
        return raw.trim();
      }
      if (raw is num) {
        return raw.toString();
      }
    }
    return '';
  }

  static int? _intValue(
    Map<String, Object?> map, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final raw = map[key];
      if (raw is int) {
        return raw;
      }
      if (raw is num) {
        return raw.round();
      }
      if (raw is String) {
        final parsed = int.tryParse(raw.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }
}

WearableBridgeService createWearableBridgeService({
  required String provider,
  required Uri? eventsUri,
  required String bearerToken,
  required http.Client client,
  Duration requestTimeout = const Duration(seconds: 12),
}) {
  final trimmedProvider = provider.trim();
  if (trimmedProvider.isEmpty || eventsUri == null) {
    return const UnconfiguredWearableBridgeService();
  }
  return HttpWearableBridgeService(
    provider: trimmedProvider,
    eventsUri: eventsUri,
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
}
