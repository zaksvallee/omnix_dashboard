import 'dart:convert';

import '../../domain/intelligence/intel_ingestion.dart';
import 'generic_feed_adapter.dart';

class LiveFeedBatch {
  final List<NormalizedIntelRecord> records;
  final Map<String, int> feedDistribution;
  final bool isConfigured;
  final String sourceLabel;

  const LiveFeedBatch({
    required this.records,
    required this.feedDistribution,
    required this.isConfigured,
    required this.sourceLabel,
  });

  int get feedCount => feedDistribution.length;
}

class ConfiguredLiveFeedService {
  static const _payloadEnvKey = 'ONYX_LIVE_FEED_JSON';
  static const _providerEnvKey = 'ONYX_LIVE_FEED_PROVIDER';

  const ConfiguredLiveFeedService();

  LiveFeedBatch? loadFromEnvironment() {
    const rawPayload = String.fromEnvironment(_payloadEnvKey);
    final trimmedPayload = rawPayload.trim();
    if (trimmedPayload.isEmpty) {
      return null;
    }
    return parseJson(trimmedPayload);
  }

  LiveFeedBatch parseJson(String rawPayload) {
    final decoded = jsonDecode(rawPayload);
    final records = <NormalizedIntelRecord>[];
    final feedDistribution = <String, int>{};

    void ingestFeed(String providerName, List<Map<String, Object?>> payloads) {
      final adapter = GenericFeedAdapter(providerName: providerName);
      final normalized = adapter.normalizeBatch(payloads);
      if (normalized.isEmpty) {
        return;
      }
      records.addAll(normalized);
      feedDistribution.update(
        providerName,
        (value) => value + normalized.length,
        ifAbsent: () => normalized.length,
      );
    }

    if (decoded is List) {
      final payloads = decoded.map(_asPayloadMap).toList(growable: false);
      final providerName = _defaultProviderName(payloads);
      ingestFeed(providerName, payloads);
    } else if (decoded is Map) {
      final map = _asObjectMap(decoded);
      final feeds = map['feeds'];
      if (feeds is List) {
        for (final entry in feeds) {
          final feed = _asObjectMap(entry);
          final providerName = _providerNameForFeed(
            _asString(feed['provider']),
            const String.fromEnvironment(_providerEnvKey),
          );
          final payloads = _asObjectList(
            feed['payloads'],
          ).map(_asPayloadMap).toList(growable: false);
          ingestFeed(providerName, payloads);
        }
      } else if (map['payloads'] is List) {
        final providerName = _providerNameForFeed(
          _asString(map['provider']),
          const String.fromEnvironment(_providerEnvKey),
        );
        final payloads = _asObjectList(
          map['payloads'],
        ).map(_asPayloadMap).toList(growable: false);
        ingestFeed(providerName, payloads);
      } else {
        final payload = _asPayloadMap(map);
        final providerName = _providerNameForFeed(
          _asString(payload['provider']),
          const String.fromEnvironment(_providerEnvKey),
        );
        ingestFeed(providerName, [payload]);
      }
    } else {
      throw const FormatException(
        'ONYX_LIVE_FEED_JSON must decode to a JSON object or array.',
      );
    }

    if (records.isEmpty) {
      throw const FormatException(
        'ONYX_LIVE_FEED_JSON did not contain any valid ingestible records.',
      );
    }

    return LiveFeedBatch(
      records: records,
      feedDistribution: feedDistribution,
      isConfigured: true,
      sourceLabel: 'configured feed',
    );
  }

  String _defaultProviderName(List<Map<String, Object?>> payloads) {
    if (payloads.isEmpty) {
      return _providerNameForFeed(
        '',
        const String.fromEnvironment(_providerEnvKey),
      );
    }
    return _providerNameForFeed(
      _asString(payloads.first['provider']),
      const String.fromEnvironment(_providerEnvKey),
    );
  }

  String _providerNameForFeed(String explicitProvider, String envProvider) {
    final trimmedExplicit = explicitProvider.trim();
    if (trimmedExplicit.isNotEmpty) {
      return trimmedExplicit;
    }
    final trimmedEnv = envProvider.trim();
    if (trimmedEnv.isNotEmpty) {
      return trimmedEnv;
    }
    return 'external-feed';
  }

  Map<String, Object?> _asPayloadMap(Object? value) {
    final map = _asObjectMap(value);
    return {
      for (final entry in map.entries)
        entry.key:
            entry.value is num || entry.value is bool || entry.value == null
            ? entry.value
            : entry.value.toString(),
    };
  }

  Map<String, Object?> _asObjectMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, entry) => MapEntry(key.toString(), entry as Object?),
      );
    }
    throw FormatException('Expected a JSON object in $_payloadEnvKey.');
  }

  List<Object?> _asObjectList(Object? value) {
    if (value is List<Object?>) {
      return value;
    }
    if (value is List) {
      return List<Object?>.from(value);
    }
    throw FormatException('Expected a JSON array in $_payloadEnvKey.');
  }

  String _asString(Object? value) => value is String ? value : '';
}
