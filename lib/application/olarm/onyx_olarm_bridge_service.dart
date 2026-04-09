import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';

import 'onyx_olarm_device.dart';
import 'onyx_olarm_exceptions.dart';
import 'onyx_olarm_mqtt_client_factory.dart';
import 'onyx_olarm_service.dart';

class OnyxOlarmBridgeService implements OnyxOlarmService {
  static const String _baseUrl = 'https://api.olarm.com/api/v4';
  static const String _mqttBrokerUrl = 'wss://mqtt-pubapi.olarm.com/mqtt';
  static const String _mqttUsername = 'public-api-user-v1';
  static const int _mqttPort = 443;
  static const int _mqttKeepAliveSeconds = 30;

  final String apiKey;
  final String siteId;
  final String? deviceId;
  final List<String> perimeterZoneIds;
  final http.Client client;

  final StreamController<OnyxOlarmEvent> _eventsController =
      StreamController<OnyxOlarmEvent>.broadcast();
  final Map<String, OnyxOlarmDevice> _deviceCache =
      <String, OnyxOlarmDevice>{};
  final Set<String> _subscribedDeviceIds = <String>{};

  MqttClient? _mqttClient;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage?>>>?
  _updatesSubscription;
  Timer? _reconnectTimer;
  Future<void>? _connectFuture;
  bool _manualDisconnect = false;
  bool _isConnected = false;
  int _reconnectAttempts = 0;

  OnyxOlarmBridgeService({
    required this.apiKey,
    required this.siteId,
    this.deviceId,
    this.perimeterZoneIds = const <String>[],
    http.Client? client,
  }) : client = client ?? http.Client();

  @override
  Stream<OnyxOlarmEvent> get events => _eventsController.stream;

  @override
  bool get isConnected {
    final client = _mqttClient;
    final state = client?.connectionStatus?.state;
    return _isConnected && state == MqttConnectionState.connected;
  }

  @override
  Future<List<OnyxOlarmDevice>> getDevices() async {
    try {
      final payload = await _requestJson(
        method: 'GET',
        path: '/devices',
        queryParameters: const <String, String>{
          'deviceApiAccessOnly': '1',
        },
      );
      final rows = _extractDeviceRows(payload);
      final devices = rows
          .map(
            (row) => OnyxOlarmDevice.fromJson(
              row,
              perimeterZoneIds: perimeterZoneIds,
            ),
          )
          .where((device) => device.deviceId.trim().isNotEmpty)
          .toList(growable: false);
      for (final device in devices) {
        _deviceCache[device.deviceId] = device;
      }
      return devices;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to fetch Olarm devices.',
        name: 'OnyxOlarmBridgeService',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      rethrow;
    }
  }

  @override
  Future<OnyxOlarmDevice> getDevice(String deviceId) async {
    final normalizedDeviceId = deviceId.trim();
    if (normalizedDeviceId.isEmpty) {
      throw const OnyxOlarmDeviceNotFoundException('Olarm device id missing.');
    }
    try {
      final payload = await _requestJson(
        method: 'GET',
        path: '/devices/$normalizedDeviceId',
        queryParameters: const <String, String>{
          'deviceApiAccessOnly': '1',
        },
      );
      final row = _extractSingleDeviceRow(payload);
      final device = OnyxOlarmDevice.fromJson(
        row,
        perimeterZoneIds: perimeterZoneIds,
      );
      if (device.deviceId.trim().isEmpty) {
        throw OnyxOlarmApiException(
          'Olarm device payload did not include a device id.',
        );
      }
      _deviceCache[device.deviceId] = device;
      return device;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to fetch Olarm device $normalizedDeviceId.',
        name: 'OnyxOlarmBridgeService',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      rethrow;
    }
  }

  @override
  Future<void> armArea(String deviceId, String areaId) =>
      _sendAreaAction(deviceId, areaId, actionCmd: 'area-arm');

  @override
  Future<void> disarmArea(String deviceId, String areaId) =>
      _sendAreaAction(deviceId, areaId, actionCmd: 'area-disarm');

  @override
  Future<void> stayArea(String deviceId, String areaId) =>
      _sendAreaAction(deviceId, areaId, actionCmd: 'area-stay');

  @override
  Future<void> connect() {
    _manualDisconnect = false;
    return _connectFuture ??=
        _connectInternal().whenComplete(() => _connectFuture = null);
  }

  @override
  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _isConnected = false;
    try {
      await _updatesSubscription?.cancel();
      _updatesSubscription = null;
      _mqttClient?.disconnect();
      _mqttClient = null;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to disconnect Olarm MQTT client cleanly.',
        name: 'OnyxOlarmBridgeService',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    }
  }

  Future<void> _connectInternal() async {
    try {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      final targetDeviceIds = await _prepareDeviceIdsForSubscription();
      if (targetDeviceIds.isEmpty) {
        throw const OnyxOlarmDeviceNotFoundException(
          'No Olarm devices are available for subscription.',
        );
      }
      await _updatesSubscription?.cancel();
      _updatesSubscription = null;
      _mqttClient?.disconnect();
      _mqttClient = null;

      final clientId = _mqttClientIdentifier();
      final mqttClient = createOnyxOlarmMqttClient(
        brokerUrl: _mqttBrokerUrl,
        clientIdentifier: clientId,
        port: _mqttPort,
      )
        ..logging(on: false)
        ..setProtocolV311()
        ..keepAlivePeriod = _mqttKeepAliveSeconds
        ..connectTimeoutPeriod = 5000
        ..websocketProtocols = MqttClientConstants.protocolsSingleDefault
        ..onConnected = _handleMqttConnected
        ..onDisconnected = _handleMqttDisconnected
        ..onSubscribed = _handleMqttSubscribed
        ..pongCallback = _handleMqttPong
        ..connectionMessage = MqttConnectMessage()
            .withClientIdentifier(clientId)
            .authenticateAs(_mqttUsername, apiKey.trim())
            .startClean();

      final status = await mqttClient.connect(_mqttUsername, apiKey.trim());
      final state = status?.state ?? mqttClient.connectionStatus?.state;
      if (state != MqttConnectionState.connected) {
        mqttClient.disconnect();
        throw OnyxOlarmMqttException(
          'Olarm MQTT connection failed with state ${state?.name ?? 'unknown'}.',
        );
      }
      _mqttClient = mqttClient;
      _isConnected = true;
      _reconnectAttempts = 0;
      _updatesSubscription = mqttClient.updates?.listen(
        _handleMqttUpdates,
        onError: (Object error, StackTrace stackTrace) {
          developer.log(
            'Olarm MQTT updates stream failed.',
            name: 'OnyxOlarmBridgeService',
            error: error,
            stackTrace: stackTrace,
            level: 1000,
          );
          _scheduleReconnect();
        },
      );
      _subscribedDeviceIds
        ..clear()
        ..addAll(targetDeviceIds);
      for (final subscribedDeviceId in targetDeviceIds) {
        mqttClient.subscribe(
          'v4/devices/$subscribedDeviceId',
          MqttQos.atLeastOnce,
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'Failed to connect Olarm bridge.',
        name: 'OnyxOlarmBridgeService',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      if (!_manualDisconnect) {
        _scheduleReconnect();
      }
      rethrow;
    }
  }

  Future<List<String>> _prepareDeviceIdsForSubscription() async {
    final preferredDeviceId = deviceId?.trim() ?? '';
    if (preferredDeviceId.isNotEmpty) {
      if (!_deviceCache.containsKey(preferredDeviceId)) {
        await getDevice(preferredDeviceId);
      }
      return <String>[preferredDeviceId];
    }
    final devices = await getDevices();
    return devices
        .map((device) => device.deviceId.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _sendAreaAction(
    String deviceId,
    String areaId, {
    required String actionCmd,
  }) async {
    final normalizedDeviceId = deviceId.trim();
    final normalizedAreaId = areaId.trim();
    if (normalizedDeviceId.isEmpty || normalizedAreaId.isEmpty) {
      throw const OnyxOlarmException('Olarm device id and area id are required.');
    }
    try {
      final actionNum = _resolveAreaActionNumber(
        normalizedDeviceId,
        normalizedAreaId,
      );
      await _requestJson(
        method: 'POST',
        path: '/devices/$normalizedDeviceId/actions',
        body: <String, Object?>{
          'actionCmd': actionCmd,
          'actionNum': actionNum,
        },
      );
      await getDevice(normalizedDeviceId);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to send Olarm area action $actionCmd for $normalizedDeviceId/$normalizedAreaId.',
        name: 'OnyxOlarmBridgeService',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      rethrow;
    }
  }

  int _resolveAreaActionNumber(String deviceId, String areaId) {
    final direct = int.tryParse(areaId);
    if (direct != null && direct > 0) {
      return direct;
    }
    final cachedDevice = _deviceCache[deviceId];
    final cachedArea = cachedDevice?.areaById(areaId);
    final cachedParsed = int.tryParse(cachedArea?.areaId ?? '');
    if (cachedParsed != null && cachedParsed > 0) {
      return cachedParsed;
    }
    final digits = RegExp(r'(\d+)').firstMatch(areaId)?.group(1);
    final extracted = int.tryParse(digits ?? '');
    if (extracted != null && extracted > 0) {
      return extracted;
    }
    throw OnyxOlarmException(
      'Olarm area id "$areaId" could not be converted into an action number.',
    );
  }

  Future<Map<String, dynamic>> _requestJson({
    required String method,
    required String path,
    Map<String, String>? queryParameters,
    Map<String, Object?>? body,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: queryParameters);
    http.Response response;
    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await client.get(
            uri,
            headers: _requestHeaders(),
          );
          break;
        case 'POST':
          response = await client.post(
            uri,
            headers: _requestHeaders(),
            body: jsonEncode(body ?? const <String, Object?>{}),
          );
          break;
        default:
          throw OnyxOlarmApiException('Unsupported Olarm HTTP method: $method');
      }
    } catch (error, stackTrace) {
      developer.log(
        'Olarm HTTP request failed for $uri.',
        name: 'OnyxOlarmBridgeService',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      throw OnyxOlarmApiException(
        'Olarm request failed for ${uri.path}.',
        cause: error,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapHttpError(response);
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
      if (decoded is List) {
        return <String, dynamic>{'items': decoded};
      }
      return <String, dynamic>{'value': decoded};
    } catch (error, stackTrace) {
      developer.log(
        'Olarm response decode failed for $uri.',
        name: 'OnyxOlarmBridgeService',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      throw OnyxOlarmApiException(
        'Olarm returned a non-JSON response for ${uri.path}.',
        statusCode: response.statusCode,
        cause: error,
      );
    }
  }

  Map<String, String> _requestHeaders() {
    return <String, String>{
      'Authorization': 'Bearer ${apiKey.trim()}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  OnyxOlarmException _mapHttpError(http.Response response) {
    final body = response.body.trim();
    return switch (response.statusCode) {
      401 || 403 => OnyxOlarmUnauthorizedException(
        body.isEmpty ? 'Olarm rejected the API key.' : body,
      ),
      404 => OnyxOlarmDeviceNotFoundException(
        body.isEmpty ? 'Olarm device was not found.' : body,
      ),
      429 => OnyxOlarmRateLimitedException(
        body.isEmpty ? 'Olarm rate limit reached.' : body,
      ),
      _ => OnyxOlarmApiException(
        body.isEmpty
            ? 'Olarm request failed with HTTP ${response.statusCode}.'
            : body,
        statusCode: response.statusCode,
      ),
    };
  }

  List<Map<String, dynamic>> _extractDeviceRows(Map<String, dynamic> payload) {
    final candidates = <Object?>[
      payload['items'],
      payload['devices'],
      payload['results'],
      payload['data'],
      payload['value'],
      _asMap(payload['data'])?['items'],
      _asMap(payload['data'])?['devices'],
      _asMap(payload['data'])?['results'],
    ];
    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: false);
      }
    }
    if (_looksLikeDeviceRow(payload)) {
      return <Map<String, dynamic>>[payload];
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _extractSingleDeviceRow(Map<String, dynamic> payload) {
    if (_looksLikeDeviceRow(payload)) {
      return payload;
    }
    for (final candidate in <Object?>[
      payload['data'],
      payload['device'],
      payload['item'],
      payload['result'],
      _asMap(payload['data']),
    ]) {
      if (candidate is Map) {
        final row = Map<String, dynamic>.from(candidate);
        if (_looksLikeDeviceRow(row)) {
          return row;
        }
      }
    }
    final rows = _extractDeviceRows(payload);
    if (rows.isNotEmpty) {
      return rows.first;
    }
    throw const OnyxOlarmApiException('Olarm did not return a usable device payload.');
  }

  bool _looksLikeDeviceRow(Map<String, dynamic> row) {
    return row.containsKey('deviceId') ||
        row.containsKey('device_id') ||
        row.containsKey('areas') ||
        row.containsKey('zones');
  }

  String _mqttClientIdentifier() {
    final randomSeed = math.Random().nextInt(1000000) + 1;
    final stamp = DateTime.now().microsecondsSinceEpoch.remainder(1000000);
    return 'onyx-$stamp-$randomSeed';
  }

  void _handleMqttConnected() {
    _isConnected = true;
    _reconnectAttempts = 0;
    developer.log(
      'Olarm MQTT connected for site $siteId.',
      name: 'OnyxOlarmBridgeService',
    );
  }

  void _handleMqttDisconnected() {
    _isConnected = false;
    developer.log(
      'Olarm MQTT disconnected for site $siteId.',
      name: 'OnyxOlarmBridgeService',
      level: 900,
    );
    if (_manualDisconnect) {
      return;
    }
    _scheduleReconnect();
  }

  void _handleMqttSubscribed(String topic) {
    developer.log(
      'Olarm MQTT subscribed to $topic.',
      name: 'OnyxOlarmBridgeService',
    );
  }

  void _handleMqttPong() {
    developer.log(
      'Olarm MQTT keepalive pong received.',
      name: 'OnyxOlarmBridgeService',
    );
  }

  void _scheduleReconnect() {
    if (_manualDisconnect || _reconnectTimer != null) {
      return;
    }
    final delaySeconds = math.min(60, math.max(2, 1 << _reconnectAttempts));
    _reconnectAttempts += 1;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectTimer = null;
      unawaited(
        connect().catchError((Object error, StackTrace stackTrace) {
          developer.log(
            'Olarm MQTT reconnect attempt failed.',
            name: 'OnyxOlarmBridgeService',
            error: error,
            stackTrace: stackTrace,
            level: 1000,
          );
        }),
      );
    });
    developer.log(
      'Scheduling Olarm MQTT reconnect in $delaySeconds seconds.',
      name: 'OnyxOlarmBridgeService',
      level: 900,
    );
  }

  void _handleMqttUpdates(List<MqttReceivedMessage<MqttMessage?>> messages) {
    for (final entry in messages) {
      try {
        final payloadMessage = entry.payload;
        if (payloadMessage is! MqttPublishMessage) {
          continue;
        }
        final rawJson = MqttPublishPayload.bytesToStringAsString(
          payloadMessage.payload.message,
        );
        final decoded = jsonDecode(rawJson);
        if (decoded is! Map) {
          continue;
        }
        final payload = Map<String, dynamic>.from(decoded);
        final event = _eventFromPayload(
          topic: entry.topic,
          payload: payload,
        );
        _eventsController.add(event);
      } catch (error, stackTrace) {
        developer.log(
          'Failed to process Olarm MQTT message.',
          name: 'OnyxOlarmBridgeService',
          error: error,
          stackTrace: stackTrace,
          level: 1000,
        );
      }
    }
  }

  OnyxOlarmEvent _eventFromPayload({
    required String topic,
    required Map<String, dynamic> payload,
  }) {
    final normalizedTopic = topic.trim();
    final zone = _asMap(payload['zone']);
    final area = _asMap(payload['area']);
    final device = _asMap(payload['device']);
    final resolvedDeviceId =
        _stringFromAny(
          payload['deviceId'],
          payload['device_id'],
          payload['deviceUuid'],
          device?['deviceId'],
          device?['id'],
        ) ??
        _deviceIdFromTopic(normalizedTopic) ??
        (deviceId?.trim() ?? '');
    final cachedDevice = _deviceCache[resolvedDeviceId];
    final zoneId =
        _stringFromAny(
          payload['zoneId'],
          payload['zone_id'],
          payload['zoneNum'],
          payload['zone_num'],
          zone?['zoneId'],
          zone?['id'],
          zone?['num'],
        ) ??
        '';
    final areaId =
        _stringFromAny(
          payload['areaId'],
          payload['area_id'],
          payload['areaNum'],
          payload['area_num'],
          area?['areaId'],
          area?['id'],
          area?['num'],
        ) ??
        '';
    final cachedZone = cachedDevice?.zoneById(zoneId);
    final cachedArea = cachedDevice?.areaById(areaId);
    final zoneName =
        _stringFromAny(
          payload['zoneName'],
          payload['zone_name'],
          zone?['zoneName'],
          zone?['name'],
          zone?['label'],
        ) ??
        cachedZone?.zoneName;
    final areaName =
        _stringFromAny(
          payload['areaName'],
          payload['area_name'],
          area?['areaName'],
          area?['name'],
          area?['label'],
        ) ??
        cachedArea?.areaName;
    final occurredAt =
        _dateFromAny(
          payload['occurredAt'],
          payload['occurred_at'],
          payload['timestamp'],
          payload['createdAt'],
          payload['created_at'],
          payload['eventTime'],
          payload['event_time'],
        ) ??
        DateTime.now().toUtc();
    final eventType = _eventTypeFromPayload(
      payload: payload,
      zoneId: zoneId,
      areaId: areaId,
    );
    final isPerimeter =
        _boolFromAny(
          payload['isPerimeter'],
          payload['is_perimeter'],
          zone?['isPerimeter'],
          zone?['is_perimeter'],
        ) ??
        cachedZone?.isPerimeter ??
        false;
    final armedState = _armedStateFromPayload(
      payload: payload,
      area: cachedArea,
      eventType: eventType,
    );
    final normalizedPayload = Map<String, dynamic>.from(payload)
      ..['onyx_normalized'] = <String, dynamic>{
        'topic': normalizedTopic,
        'site_id': siteId,
        if ((zoneName ?? '').isNotEmpty) 'zone_name': zoneName,
        if ((areaName ?? '').isNotEmpty) 'area_name': areaName,
        if ((armedState ?? '').isNotEmpty) 'armed_state': armedState,
        'is_perimeter': isPerimeter,
      };
    return OnyxOlarmEvent(
      deviceId: resolvedDeviceId,
      eventType: eventType,
      zoneId: zoneId.isEmpty ? null : zoneId,
      areaId: areaId.isEmpty ? null : areaId,
      occurredAt: occurredAt.toUtc(),
      rawPayload: normalizedPayload,
    );
  }

  String? _deviceIdFromTopic(String topic) {
    final match = RegExp(r'v4/devices/([^/]+)', caseSensitive: false).firstMatch(
      topic,
    );
    return match?.group(1)?.trim();
  }

  OnyxOlarmEventType _eventTypeFromPayload({
    required Map<String, dynamic> payload,
    required String zoneId,
    required String areaId,
  }) {
    final normalized = _flattenPayload(payload);
    final hasZoneContext =
        zoneId.trim().isNotEmpty || normalized.contains(' zone ');
    final hasAreaContext =
        areaId.trim().isNotEmpty || normalized.contains(' area ');
    if (normalized.contains('power failure') ||
        normalized.contains('mains fail') ||
        normalized.contains('ac fail')) {
      return OnyxOlarmEventType.powerFailure;
    }
    if (normalized.contains('tamper')) {
      return OnyxOlarmEventType.tamper;
    }
    if (hasAreaContext &&
        (normalized.contains('trigger') || normalized.contains('alarm'))) {
      return OnyxOlarmEventType.areaTriggered;
    }
    if (hasAreaContext &&
        (normalized.contains('disarm') || normalized.contains('unset'))) {
      return OnyxOlarmEventType.areaDisarmed;
    }
    if (hasAreaContext &&
        (normalized.contains('arm') ||
            normalized.contains('stay') ||
            normalized.contains('sleep'))) {
      return OnyxOlarmEventType.areaArmed;
    }
    if (hasZoneContext &&
        (normalized.contains('closed') ||
            normalized.contains('restore') ||
            normalized.contains('normal') ||
            normalized.contains('secure'))) {
      return OnyxOlarmEventType.zoneClosed;
    }
    if (hasZoneContext &&
        (normalized.contains('open') ||
            normalized.contains('violat') ||
            normalized.contains('alarm') ||
            normalized.contains('trigger'))) {
      return OnyxOlarmEventType.zoneOpen;
    }
    if (normalized.contains('disarm')) {
      return OnyxOlarmEventType.areaDisarmed;
    }
    if (normalized.contains('arm') || normalized.contains('stay')) {
      return OnyxOlarmEventType.areaArmed;
    }
    return OnyxOlarmEventType.unknown;
  }

  String? _armedStateFromPayload({
    required Map<String, dynamic> payload,
    required OnyxOlarmArea? area,
    required OnyxOlarmEventType eventType,
  }) {
    final fromPayload = _stringFromAny(
      payload['armedState'],
      payload['armed_state'],
      payload['armStatus'],
      payload['arm_status'],
      payload['state'],
      payload['status'],
    );
    if (fromPayload != null && fromPayload.isNotEmpty) {
      return fromPayload;
    }
    return switch (eventType) {
      OnyxOlarmEventType.areaDisarmed => 'disarmed',
      OnyxOlarmEventType.areaArmed => area?.areaStatus.name ?? 'armed',
      OnyxOlarmEventType.areaTriggered => 'triggered',
      _ => area?.areaStatus.name,
    };
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(value);
  }

  String _flattenPayload(Map<String, dynamic> payload) {
    final buffer = StringBuffer();
    void visit(Object? value) {
      if (value == null) {
        return;
      }
      if (value is Map) {
        for (final entry in value.entries) {
          visit(entry.key);
          visit(entry.value);
        }
        return;
      }
      if (value is List) {
        for (final entry in value) {
          visit(entry);
        }
        return;
      }
      buffer.write(' ${value.toString().trim().toLowerCase()} ');
    }

    visit(payload);
    return buffer.toString();
  }

  String? _stringFromAny(
    Object? raw1, [
    Object? raw2,
    Object? raw3,
    Object? raw4,
    Object? raw5,
    Object? raw6,
    Object? raw7,
  ]) {
    for (final raw in <Object?>[raw1, raw2, raw3, raw4, raw5, raw6, raw7]) {
      if (raw == null) {
        continue;
      }
      final value = raw.toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  bool? _boolFromAny(
    Object? raw1, [
    Object? raw2,
    Object? raw3,
    Object? raw4,
  ]) {
    for (final raw in <Object?>[raw1, raw2, raw3, raw4]) {
      if (raw is bool) {
        return raw;
      }
      if (raw is num) {
        if (raw == 1) {
          return true;
        }
        if (raw == 0) {
          return false;
        }
      }
      if (raw is String) {
        final normalized = raw.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
          return true;
        }
        if (normalized == 'false' ||
            normalized == '0' ||
            normalized == 'no') {
          return false;
        }
      }
    }
    return null;
  }

  DateTime? _dateFromAny(
    Object? raw1, [
    Object? raw2,
    Object? raw3,
    Object? raw4,
    Object? raw5,
    Object? raw6,
    Object? raw7,
  ]) {
    for (final raw in <Object?>[
      raw1,
      raw2,
      raw3,
      raw4,
      raw5,
      raw6,
      raw7,
    ]) {
      if (raw == null) {
        continue;
      }
      if (raw is int) {
        final milliseconds = raw > 9999999999 ? raw : raw * 1000;
        return DateTime.fromMillisecondsSinceEpoch(
          milliseconds,
          isUtc: true,
        );
      }
      final parsed = DateTime.tryParse(raw.toString().trim());
      if (parsed != null) {
        return parsed.toUtc();
      }
    }
    return null;
  }
}
