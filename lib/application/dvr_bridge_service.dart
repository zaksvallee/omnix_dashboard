import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/intelligence/intel_ingestion.dart';
import 'dvr_http_auth.dart';
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
  final DvrHttpAuthMode authMode;
  final String? bearerToken;
  final String? username;
  final String? password;
  final Duration requestTimeout;
  final http.Client client;

  const HttpDvrBridgeService({
    required this.profile,
    required this.eventsUri,
    required this.authMode,
    required this.client,
    this.bearerToken,
    this.username,
    this.password,
    this.requestTimeout = const Duration(seconds: 12),
  });

  @override
  Future<List<NormalizedIntelRecord>> fetchLatest({
    required String clientId,
    required String regionId,
    required String siteId,
  }) async {
    final normalizer = DvrFixtureContractNormalizer(
      profile: profile,
      baseUri: eventsUri,
    );
    final rows = await _fetchRows();
    return rows
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
  }

  Future<List<Object?>> _fetchRows() async {
    return switch (profile.eventTransport) {
      'isapi_alert_stream' => _fetchAlertStreamRows(),
      _ => _fetchJsonRows(),
    };
  }

  Future<List<Object?>> _fetchJsonRows() async {
    final response = await _auth
        .get(
          client,
          eventsUri,
          headers: const <String, String>{'Accept': 'application/json'},
        )
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException('DVR bridge HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    return _decodeRows(decoded);
  }

  Future<List<Object?>> _fetchAlertStreamRows() async {
    final response = await _auth
        .send(
          client,
          'GET',
          eventsUri,
          headers: const <String, String>{
            'Accept': 'multipart/x-mixed-replace, application/xml, text/xml',
          },
        )
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException('DVR bridge HTTP ${response.statusCode}');
    }
    return _readAlertStreamRows(response.stream).timeout(requestTimeout);
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

  Future<List<Object?>> _readAlertStreamRows(Stream<List<int>> stream) {
    final completer = Completer<List<Object?>>();
    final buffer = StringBuffer();
    StreamSubscription<List<int>>? subscription;
    Timer? idleTimer;

    void finish([List<Object?> rows = const []]) {
      idleTimer?.cancel();
      if (!completer.isCompleted) {
        completer.complete(rows);
      }
      subscription?.cancel();
    }

    void armIdleTimer() {
      idleTimer?.cancel();
      idleTimer = Timer(const Duration(seconds: 2), () => finish());
    }

    subscription = stream.listen(
      (chunk) {
        buffer.write(utf8.decode(chunk, allowMalformed: true));
        final rows = _extractAlertRows(buffer.toString());
        if (rows.isNotEmpty) {
          finish(rows);
          return;
        }
        armIdleTimer();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
      onDone: () => finish(),
      cancelOnError: true,
    );
    armIdleTimer();
    return completer.future;
  }

  List<Object?> _extractAlertRows(String raw) {
    final matches = RegExp(
      r'<EventNotificationAlert\b[^>]*>[\s\S]*?</EventNotificationAlert>',
    ).allMatches(raw);
    final rows = <Object?>[];
    for (final match in matches) {
      final payload = match.group(0);
      if (payload == null || payload.trim().isEmpty) {
        continue;
      }
      rows.add(_xmlAlertPayload(payload));
    }
    return rows;
  }

  Map<String, Object?> _xmlAlertPayload(String xml) {
    return <String, Object?>{
      'EventNotificationAlert': <String, Object?>{
        for (final tag in const [
          'ipAddress',
          'portNo',
          'protocol',
          'macAddress',
          'channelID',
          'dynChannelID',
          'dateTime',
          'activePostCount',
          'eventType',
          'eventState',
          'eventDescription',
          'targetType',
        ])
          if (_xmlValue(xml, tag).isNotEmpty) tag: _xmlValue(xml, tag),
      },
    };
  }

  String _xmlValue(String xml, String tag) {
    final match = RegExp(
      '<$tag(?:\\s[^>]*)?>([\\s\\S]*?)</$tag>',
    ).firstMatch(xml);
    return match?.group(1)?.trim() ?? '';
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

  DvrHttpAuthConfig get _auth => DvrHttpAuthConfig(
    mode: authMode,
    bearerToken: bearerToken,
    username: username,
    password: password,
  );
}

DvrBridgeService createDvrBridgeService({
  required String provider,
  required Uri? eventsUri,
  required String authMode,
  required String bearerToken,
  required String username,
  required String password,
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
    authMode: parseDvrHttpAuthMode(authMode),
    bearerToken: trimmedToken.isEmpty ? null : trimmedToken,
    username: username.trim().isEmpty ? null : username.trim(),
    password: password.isEmpty ? null : password,
    requestTimeout: requestTimeout,
    client: client,
  );
}
