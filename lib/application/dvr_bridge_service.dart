import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/intelligence/intel_ingestion.dart';
import 'dvr_ingest_contract.dart';
import 'video_edge_ingest_contract.dart';

abstract class DvrBridgeService {
  Future<List<NormalizedIntelRecord>> fetchLatest({
    required String clientId,
    required String regionId,
    required String siteId,
  });
}

class UnconfiguredDvrBridgeService implements DvrBridgeService {
  const UnconfiguredDvrBridgeService();

  @override
  Future<List<NormalizedIntelRecord>> fetchLatest({
    required String clientId,
    required String regionId,
    required String siteId,
  }) async {
    return const [];
  }
}

class HttpDvrBridgeService implements DvrBridgeService {
  final DvrProviderProfile profile;
  final Uri eventsUri;
  final String? bearerToken;
  final Duration requestTimeout;
  final http.Client client;

  const HttpDvrBridgeService({
    required this.profile,
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
      throw FormatException('DVR bridge HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final normalizer = DvrFixtureContractNormalizer(
      profile: profile,
      baseUri: eventsUri,
    );
    final contracts = _decodeRows(decoded)
        .map<VideoEdgeEventContract?>(
          (row) => normalizer.normalize(
            payload: row,
            clientId: clientId,
            regionId: regionId,
            siteId: siteId,
          ),
        )
        .whereType<VideoEdgeEventContract>()
        .map((entry) => entry.toNormalizedIntelRecord())
        .toList(growable: false);
    return contracts;
  }

  List<Object?> _decodeRows(Object? decoded) {
    if (decoded is List) {
      return decoded;
    }
    if (decoded is Map) {
      final object = _toObjectMap(decoded);
      final alertEnvelope = object['EventNotificationAlert'];
      if (alertEnvelope is Map) {
        return [object];
      }
      for (final key in const ['items', 'events', 'eventList', 'result']) {
        final value = object[key];
        if (value is List) {
          return value;
        }
      }
      return [object];
    }
    return const [];
  }

  Map<String, Object?> _toObjectMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, dynamicValue) => MapEntry(key.toString(), dynamicValue),
      );
    }
    return const <String, Object?>{};
  }
}

DvrBridgeService createDvrBridgeService({
  required String provider,
  required Uri? eventsUri,
  required String bearerToken,
  required http.Client client,
  Duration requestTimeout = const Duration(seconds: 12),
}) {
  final profile = DvrProviderProfile.fromProvider(provider);
  if (profile == null || eventsUri == null) {
    return const UnconfiguredDvrBridgeService();
  }
  final trimmedToken = bearerToken.trim();
  return HttpDvrBridgeService(
    profile: profile,
    eventsUri: eventsUri,
    bearerToken: trimmedToken.isEmpty ? null : trimmedToken,
    requestTimeout: requestTimeout,
    client: client,
  );
}
