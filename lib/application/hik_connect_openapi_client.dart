import 'dart:convert';

import 'package:http/http.dart' as http;

import 'hik_connect_camera_catalog.dart';
import 'hik_connect_openapi_config.dart';
import 'hik_connect_video_session.dart';

class HikConnectOpenApiToken {
  final String value;
  final DateTime? expiresAtUtc;
  final String streamAreaDomain;

  const HikConnectOpenApiToken({
    required this.value,
    required this.expiresAtUtc,
    required this.streamAreaDomain,
  });

  bool get usable =>
      value.trim().isNotEmpty &&
      (expiresAtUtc == null ||
          expiresAtUtc!.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 5))));
}

class HikConnectOpenApiClient {
  final HikConnectOpenApiConfig config;
  final http.Client client;
  final Duration requestTimeout;

  HikConnectOpenApiToken? _cachedToken;

  HikConnectOpenApiClient({
    required this.config,
    required this.client,
    this.requestTimeout = const Duration(seconds: 12),
  });

  Future<HikConnectOpenApiToken> ensureToken({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedToken?.usable == true) {
      return _cachedToken!;
    }
    final response = await _postJson(
      '/api/hccgw/platform/v1/token/get',
      <String, Object?>{
        'appKey': config.appKey,
        'secretKey': config.appSecret,
      },
      includeToken: false,
    );
    final data = _asObjectMap(response['data']);
    final token = (data['appToken'] ?? '').toString().trim();
    final expireTimeRaw = (data['expireTime'] ?? '').toString().trim();
    final expireEpoch = int.tryParse(expireTimeRaw);
    final expiresAtUtc = expireEpoch == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(expireEpoch, isUtc: true);
    final resolved = HikConnectOpenApiToken(
      value: token,
      expiresAtUtc: expiresAtUtc,
      streamAreaDomain: (data['streamAreaDomain'] ?? '').toString().trim(),
    );
    _cachedToken = resolved;
    return resolved;
  }

  Future<void> subscribeAlarmQueue({
    List<int>? eventTypes,
    bool enabled = true,
  }) async {
    final configuredEventTypes = eventTypes ?? config.alarmEventTypes;
    final subscribeByType = configuredEventTypes.isNotEmpty;
    await _postJson(
      '/api/hccgw/alarm/v1/mq/subscribe',
      <String, Object?>{
        'subscribeType': enabled ? 1 : 0,
        'subscribeMode': subscribeByType ? 1 : 0,
        if (subscribeByType) 'eventType': configuredEventTypes,
      },
    );
  }

  Future<Map<String, Object?>> pullAlarmMessages({
    int maxNumberPerTime = 300,
  }) {
    return _postJson(
      '/api/hccgw/alarm/v1/mq/messages',
      <String, Object?>{'maxNumberPerTime': maxNumberPerTime},
    );
  }

  Future<void> completeAlarmBatch(String batchId) async {
    await _postJson(
      '/api/hccgw/alarm/v1/mq/messages/complete',
      <String, Object?>{'batchId': batchId},
    );
  }

  Future<Map<String, Object?>> getCameras({
    int pageIndex = 1,
    int pageSize = 200,
    String? areaId,
    bool? includeSubArea,
    String deviceSerialNo = '',
  }) {
    return _postJson(
      '/api/hccgw/resource/v1/areas/cameras/get',
      <String, Object?>{
        'pageIndex': pageIndex,
        'pageSize': pageSize,
        'filter': <String, Object?>{
          'areaID': areaId ?? config.areaId,
          'includeSubArea': (includeSubArea ?? config.includeSubArea) ? '1' : '0',
          'deviceID': '',
          'deviceSerialNo': deviceSerialNo.isEmpty
              ? config.deviceSerialNo
              : deviceSerialNo,
        },
      },
    );
  }

  Future<HikConnectCameraCatalogPage> getCameraCatalog({
    int pageIndex = 1,
    int pageSize = 200,
    String? areaId,
    bool? includeSubArea,
    String deviceSerialNo = '',
  }) async {
    final response = await getCameras(
      pageIndex: pageIndex,
      pageSize: pageSize,
      areaId: areaId,
      includeSubArea: includeSubArea,
      deviceSerialNo: deviceSerialNo,
    );
    return HikConnectCameraCatalogPage.fromApiResponse(
      response,
      cameraLabels: config.cameraLabels,
    );
  }

  Future<List<HikConnectCameraCatalogPage>> getAllCameraCatalogPages({
    int pageSize = 200,
    int maxPages = 20,
    String? areaId,
    bool? includeSubArea,
    String deviceSerialNo = '',
  }) async {
    final pages = <HikConnectCameraCatalogPage>[];
    for (var pageIndex = 1; pageIndex <= maxPages; pageIndex += 1) {
      final page = await getCameraCatalog(
        pageIndex: pageIndex,
        pageSize: pageSize,
        areaId: areaId,
        includeSubArea: includeSubArea,
        deviceSerialNo: deviceSerialNo,
      );
      pages.add(page);
      final loadedCount = pages.fold<int>(
        0,
        (sum, entry) => sum + entry.cameras.length,
      );
      final totalCount = page.totalCount;
      if (page.cameras.isEmpty ||
          totalCount <= 0 ||
          loadedCount >= totalCount ||
          page.cameras.length < pageSize) {
        break;
      }
    }
    return List<HikConnectCameraCatalogPage>.unmodifiable(pages);
  }

  Future<Map<String, Object?>> getLiveAddress({
    required String resourceId,
    required String deviceSerial,
    int type = 1,
    int protocol = 1,
    String quality = '1',
    String code = '',
  }) {
    return _postJson(
      '/api/hccgw/video/v1/live/address/get',
      <String, Object?>{
        'resourceId': resourceId,
        'deviceSerial': deviceSerial,
        'type': '$type',
        'protocol': protocol,
        'quality': quality,
        if (code.trim().isNotEmpty) 'code': code.trim(),
      },
    );
  }

  Future<HikConnectLiveAddressResponse> getLiveAddressResult({
    required String resourceId,
    required String deviceSerial,
    int type = 1,
    int protocol = 1,
    String quality = '1',
    String code = '',
  }) async {
    final response = await getLiveAddress(
      resourceId: resourceId,
      deviceSerial: deviceSerial,
      type: type,
      protocol: protocol,
      quality: quality,
      code: code,
    );
    return HikConnectLiveAddressResponse.fromApiResponse(response);
  }

  Future<Map<String, Object?>> searchRecordElements(
    Map<String, Object?> body,
  ) {
    return _postJson('/api/hccgw/video/v1/record/element/search', body);
  }

  Future<HikConnectRecordElementSearchResult> searchRecordCatalog(
    Map<String, Object?> body,
  ) async {
    final response = await searchRecordElements(body);
    return HikConnectRecordElementSearchResult.fromApiResponse(response);
  }

  Future<Map<String, Object?>> getVideoDownloadUrl(
    Map<String, Object?> body,
  ) {
    return _postJson('/api/hccgw/video/v1/video/download/url', body);
  }

  Future<HikConnectVideoDownloadResult> getVideoDownloadResult(
    Map<String, Object?> body,
  ) async {
    final response = await getVideoDownloadUrl(body);
    return HikConnectVideoDownloadResult.fromApiResponse(response);
  }

  Future<Map<String, Object?>> _postJson(
    String path,
    Map<String, Object?> body, {
    bool includeToken = true,
  }) async {
    final resolvedBaseUri = config.baseUri;
    if (resolvedBaseUri == null) {
      throw StateError('Hik-Connect OpenAPI base URI is not configured.');
    }
    final uri = resolvedBaseUri.resolve(path);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (includeToken) {
      final token = await ensureToken();
      headers['Token'] = token.value;
    }
    final response = await client
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException('Hik-Connect HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    throw const FormatException('Hik-Connect response was not an object.');
  }

  Map<String, Object?> _asObjectMap(Object? value) {
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
