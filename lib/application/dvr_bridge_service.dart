import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/intelligence/intel_ingestion.dart';
import 'dvr_http_auth.dart';
import 'dvr_ingest_contract.dart';
import 'hik_connect_alarm_batch.dart';
import 'hik_connect_openapi_client.dart';
import 'hik_connect_openapi_config.dart';
import 'video_edge_ingest_contract.dart';

abstract class DvrBridgeService {
  Future<List<NormalizedIntelRecord>> fetchLatest({
    required String clientId,
    required String regionId,
    required String siteId,
  });

  DvrBridgeHealthSnapshot? healthSnapshot() => null;

  void dispose() {}
}

class DvrBridgeHealthSnapshot {
  final DateTime? lastHealthyAtUtc;
  final DateTime? lastAlertAtUtc;
  final String lastError;

  const DvrBridgeHealthSnapshot({
    this.lastHealthyAtUtc,
    this.lastAlertAtUtc,
    this.lastError = '',
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

  @override
  DvrBridgeHealthSnapshot? healthSnapshot() => null;

  @override
  void dispose() {}
}

class HttpDvrBridgeService implements DvrBridgeService {
  static const Duration _defaultAlertStreamIdleWindow = Duration(seconds: 8);
  static const Duration _defaultAlertStreamReconnectDelay = Duration(
    seconds: 2,
  );

  final DvrProviderProfile profile;
  final Uri eventsUri;
  final DvrHttpAuthMode authMode;
  final String? bearerToken;
  final String? username;
  final String? password;
  final Duration requestTimeout;
  final Duration alertStreamIdleWindow;
  final Duration alertStreamReconnectDelay;
  final http.Client client;

  final List<Object?> _bufferedAlertRows = <Object?>[];
  bool _alertStreamLoopRunning = false;
  bool _disposed = false;
  Completer<void>? _bufferedAlertRowsCompleter;
  Object? _lastBridgeError;
  DateTime? _lastHealthyAtUtc;
  DateTime? _lastAlertAtUtc;

  HttpDvrBridgeService({
    required this.profile,
    required this.eventsUri,
    required this.authMode,
    required this.client,
    this.bearerToken,
    this.username,
    this.password,
    this.requestTimeout = const Duration(seconds: 12),
    this.alertStreamIdleWindow = _defaultAlertStreamIdleWindow,
    this.alertStreamReconnectDelay = _defaultAlertStreamReconnectDelay,
  });

  @override
  Future<List<NormalizedIntelRecord>> fetchLatest({
    required String clientId,
    required String regionId,
    required String siteId,
  }) async {
    if (_disposed) {
      return const <NormalizedIntelRecord>[];
    }
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
      final error = FormatException('DVR bridge HTTP ${response.statusCode}');
      _lastBridgeError = error;
      throw error;
    }
    _lastBridgeError = null;
    _markHealthy();
    final decoded = jsonDecode(response.body);
    final rows = _decodeRows(decoded);
    if (rows.isNotEmpty) {
      _markAlertActivity();
    }
    return rows;
  }

  Future<List<Object?>> _fetchAlertStreamRows() async {
    if (!_alertStreamLoopRunning) {
      final initialRows = await _fetchAlertStreamRowsOnce();
      _ensureAlertStreamLoop();
      if (initialRows.isNotEmpty) {
        return initialRows;
      }
    } else if (_bufferedAlertRows.isNotEmpty) {
      return _drainBufferedAlertRows();
    }
    _ensureAlertStreamLoop();
    if (_bufferedAlertRows.isEmpty) {
      await _waitForBufferedAlertRows();
    }
    final rows = _drainBufferedAlertRows();
    if (rows.isNotEmpty) {
      return rows;
    }
    final lastError = _lastBridgeError;
    if (lastError is FormatException) {
      throw lastError;
    }
    if (lastError != null) {
      throw FormatException('DVR bridge alert stream failed: $lastError');
    }
    return const <Object?>[];
  }

  Future<List<Object?>> _fetchAlertStreamRowsOnce() async {
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
      final error = FormatException('DVR bridge HTTP ${response.statusCode}');
      _lastBridgeError = error;
      throw error;
    }
    _lastBridgeError = null;
    _markHealthy();
    final rows = await _readAlertStreamRowsOnce(response.stream).timeout(
      requestTimeout,
    );
    if (rows.isNotEmpty) {
      _markAlertActivity();
    }
    return rows;
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

  void _ensureAlertStreamLoop() {
    if (_alertStreamLoopRunning || _disposed) {
      return;
    }
    _alertStreamLoopRunning = true;
    unawaited(_runAlertStreamLoop());
  }

  Future<void> _runAlertStreamLoop() async {
    try {
      while (!_disposed) {
        try {
          final response = await _auth
              .send(
                client,
                'GET',
                eventsUri,
                headers: const <String, String>{
                  'Accept':
                      'multipart/x-mixed-replace, application/xml, text/xml',
                },
              )
              .timeout(requestTimeout);
          if (response.statusCode < 200 || response.statusCode >= 300) {
            _lastBridgeError = FormatException(
              'DVR bridge HTTP ${response.statusCode}',
            );
            await response.stream.drain<void>();
          } else {
            _lastBridgeError = null;
            _markHealthy();
            await _bufferAlertStreamRows(response.stream);
          }
        } catch (error) {
          _lastBridgeError = error;
        }
        if (_disposed) {
          break;
        }
        await Future<void>.delayed(alertStreamReconnectDelay);
      }
    } finally {
      _alertStreamLoopRunning = false;
    }
  }

  Future<List<Object?>> _readAlertStreamRowsOnce(Stream<List<int>> stream) {
    final completer = Completer<List<Object?>>();
    var buffer = '';
    StreamSubscription<List<int>>? subscription;
    Timer? idleTimer;

    void finish([List<Object?> rows = const <Object?>[]]) {
      idleTimer?.cancel();
      if (!completer.isCompleted) {
        completer.complete(rows);
      }
      unawaited(subscription?.cancel());
    }

    void armIdleTimer() {
      idleTimer?.cancel();
      idleTimer = Timer(alertStreamIdleWindow, () {
        finish(_extractAlertRowsWithRemainder(buffer).rows);
      });
    }

    subscription = stream.listen(
      (chunk) {
        buffer += utf8.decode(chunk, allowMalformed: true);
        final extraction = _extractAlertRowsWithRemainder(buffer);
        buffer = extraction.remainder;
        if (extraction.rows.isNotEmpty) {
          finish(extraction.rows);
          return;
        }
        armIdleTimer();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
      onDone: () => finish(_extractAlertRowsWithRemainder(buffer).rows),
      cancelOnError: true,
    );
    armIdleTimer();
    return completer.future;
  }

  Future<void> _bufferAlertStreamRows(Stream<List<int>> stream) {
    final completer = Completer<void>();
    var buffer = '';
    StreamSubscription<List<int>>? subscription;
    Timer? idleTimer;

    void finish() {
      idleTimer?.cancel();
      if (!completer.isCompleted) {
        completer.complete();
      }
      unawaited(subscription?.cancel());
    }

    void armIdleTimer() {
      idleTimer?.cancel();
      idleTimer = Timer(alertStreamIdleWindow, finish);
    }

    subscription = stream.listen(
      (chunk) {
        buffer += utf8.decode(chunk, allowMalformed: true);
        final extraction = _extractAlertRowsWithRemainder(buffer);
        buffer = extraction.remainder;
        if (extraction.rows.isNotEmpty) {
          _bufferedAlertRows.addAll(extraction.rows);
          _markAlertActivity();
          _notifyBufferedAlertRowsAvailable();
        }
        armIdleTimer();
      },
      onError: (Object error, StackTrace stackTrace) {
        _lastBridgeError = error;
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
      onDone: finish,
      cancelOnError: true,
    );
    armIdleTimer();
    return completer.future;
  }

  ({List<Object?> rows, String remainder}) _extractAlertRowsWithRemainder(
    String raw,
  ) {
    final matches = RegExp(
      r'<EventNotificationAlert\b[^>]*>[\s\S]*?</EventNotificationAlert>',
    ).allMatches(raw).toList(growable: false);
    if (matches.isEmpty) {
      return (rows: const <Object?>[], remainder: raw);
    }
    final rows = <Object?>[];
    for (final match in matches) {
      final payload = match.group(0);
      if (payload == null || payload.trim().isEmpty) {
        continue;
      }
      rows.add(_xmlAlertPayload(payload));
    }
    return (rows: rows, remainder: raw.substring(matches.last.end));
  }

  Future<void> _waitForBufferedAlertRows() async {
    if (_bufferedAlertRows.isNotEmpty) {
      return;
    }
    final completer = _bufferedAlertRowsCompleter ?? Completer<void>();
    _bufferedAlertRowsCompleter = completer;
    try {
      await completer.future.timeout(requestTimeout);
    } on TimeoutException {
      // Keep the bridge non-fatal when the alert stream is quiet.
    }
  }

  void _notifyBufferedAlertRowsAvailable() {
    final completer = _bufferedAlertRowsCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _bufferedAlertRowsCompleter = null;
  }

  List<Object?> _drainBufferedAlertRows() {
    if (_bufferedAlertRows.isEmpty) {
      return const <Object?>[];
    }
    final rows = List<Object?>.of(_bufferedAlertRows, growable: false);
    _bufferedAlertRows.clear();
    return rows;
  }

  @override
  void dispose() {
    _disposed = true;
    _notifyBufferedAlertRowsAvailable();
  }

  @override
  DvrBridgeHealthSnapshot? healthSnapshot() {
    return DvrBridgeHealthSnapshot(
      lastHealthyAtUtc: _lastHealthyAtUtc,
      lastAlertAtUtc: _lastAlertAtUtc,
      lastError: (_lastBridgeError ?? '').toString().trim(),
    );
  }

  void _markHealthy() {
    _lastHealthyAtUtc = DateTime.now().toUtc();
  }

  void _markAlertActivity() {
    final nowUtc = DateTime.now().toUtc();
    _lastHealthyAtUtc = nowUtc;
    _lastAlertAtUtc = nowUtc;
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

class HikConnectOpenApiDvrBridgeService implements DvrBridgeService {
  final DvrProviderProfile profile;
  final HikConnectOpenApiClient apiClient;

  bool _subscribed = false;
  DateTime? _lastHealthyAtUtc;
  Object? _lastBridgeError;

  HikConnectOpenApiDvrBridgeService({
    required this.profile,
    required this.apiClient,
  });

  @override
  Future<List<NormalizedIntelRecord>> fetchLatest({
    required String clientId,
    required String regionId,
    required String siteId,
  }) async {
    try {
      if (!_subscribed) {
        await apiClient.subscribeAlarmQueue();
        _subscribed = true;
      }
      final payload = await apiClient.pullAlarmMessages();
      final batch = HikConnectAlarmBatch.fromApiResponse(payload);
      final normalizer = DvrFixtureContractNormalizer(
        profile: profile,
        baseUri: apiClient.config.baseUri ?? Uri(),
      );
      final records = batch.messages
          .map<VideoEdgeEventContract?>(
            (message) => normalizer.normalize(
              payload: message.toPayloadMap(),
              clientId: clientId,
              regionId: regionId,
              siteId: siteId,
            ),
          )
          .whereType<VideoEdgeEventContract>()
          .map((entry) => entry.toNormalizedIntelRecord())
          .toList(growable: false);
      if (batch.batchId.isNotEmpty) {
        await apiClient.completeAlarmBatch(batch.batchId);
      }
      _lastBridgeError = null;
      _lastHealthyAtUtc = DateTime.now().toUtc();
      return records;
    } catch (error) {
      _lastBridgeError = error;
      rethrow;
    }
  }

  @override
  void dispose() {}

  @override
  DvrBridgeHealthSnapshot? healthSnapshot() {
    return DvrBridgeHealthSnapshot(
      lastHealthyAtUtc: _lastHealthyAtUtc,
      lastError: (_lastBridgeError ?? '').toString().trim(),
    );
  }
}

DvrBridgeService createDvrBridgeService({
  required String provider,
  required Uri? eventsUri,
  required String authMode,
  required String bearerToken,
  required String username,
  required String password,
  required http.Client client,
  Uri? apiBaseUri,
  String appKey = '',
  String appSecret = '',
  String areaId = '',
  bool includeSubArea = true,
  String deviceSerialNo = '',
  List<int> alarmEventTypes = const <int>[],
  Duration requestTimeout = const Duration(seconds: 12),
}) {
  final profile = DvrProviderProfile.fromProvider(provider);
  if (profile == null) {
    return const UnconfiguredDvrBridgeService();
  }
  if (profile.provider == DvrProviderProfile.hikConnectOpenApi.provider) {
    final config = HikConnectOpenApiConfig(
      clientId: '',
      regionId: '',
      siteId: '',
      baseUri: apiBaseUri,
      appKey: appKey,
      appSecret: appSecret,
      areaId: areaId,
      includeSubArea: includeSubArea,
      deviceSerialNo: deviceSerialNo,
      alarmEventTypes: alarmEventTypes,
      cameraLabels: const <String, String>{},
    );
    if (!config.configured) {
      return const UnconfiguredDvrBridgeService();
    }
    return HikConnectOpenApiDvrBridgeService(
      profile: profile,
      apiClient: HikConnectOpenApiClient(config: config, client: client),
    );
  }
  if (eventsUri == null) {
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
