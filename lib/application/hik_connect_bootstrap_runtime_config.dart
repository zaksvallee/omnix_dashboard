import 'hik_connect_openapi_config.dart';

class HikConnectBootstrapRuntimeConfig {
  static const List<String> requiredEnvNames = <String>[
    'ONYX_DVR_CLIENT_ID',
    'ONYX_DVR_REGION_ID',
    'ONYX_DVR_SITE_ID',
    'ONYX_DVR_API_BASE_URL',
  ];

  static const List<int> defaultAlarmEventTypes = <int>[0, 1, 100657];
  static const int defaultPageSize = 200;
  static const int defaultMaxPages = 20;

  final String clientId;
  final String regionId;
  final String siteId;
  final String provider;
  final Uri? apiBaseUri;
  final String appKey;
  final String appSecret;
  final String areaId;
  final bool includeSubArea;
  final String deviceSerialNo;
  final List<int> alarmEventTypes;
  final int pageSize;
  final int maxPages;
  final String cameraPayloadPath;

  const HikConnectBootstrapRuntimeConfig({
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.provider,
    required this.apiBaseUri,
    required this.appKey,
    required this.appSecret,
    required this.areaId,
    required this.includeSubArea,
    required this.deviceSerialNo,
    required this.alarmEventTypes,
    required this.pageSize,
    required this.maxPages,
    required this.cameraPayloadPath,
  });

  factory HikConnectBootstrapRuntimeConfig.fromEnvironment(
    Map<String, String> env,
  ) {
    String readString(String key, {String fallback = ''}) {
      return (env[key] ?? fallback).trim();
    }

    bool readBool(String key, {bool fallback = false}) {
      final normalized = readString(key).toLowerCase();
      if (normalized.isEmpty) {
        return fallback;
      }
      if (normalized == '1' || normalized == 'true' || normalized == 'yes') {
        return true;
      }
      if (normalized == '0' || normalized == 'false' || normalized == 'no') {
        return false;
      }
      return fallback;
    }

    int readInt(String key, {required int fallback}) {
      final parsed = int.tryParse(readString(key));
      if (parsed == null || parsed <= 0) {
        return fallback;
      }
      return parsed;
    }

    List<int> readAlarmEventTypes(String key) {
      final raw = readString(key);
      if (raw.isEmpty) {
        return defaultAlarmEventTypes;
      }
      final output = <int>[];
      for (final token in raw.split(RegExp(r'[\s,]+'))) {
        final trimmed = token.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        final parsed = int.tryParse(trimmed);
        if (parsed != null) {
          output.add(parsed);
        }
      }
      if (output.isEmpty) {
        return defaultAlarmEventTypes;
      }
      return List<int>.unmodifiable(output);
    }

    Uri? readUri(String key) {
      final raw = readString(key);
      if (raw.isEmpty) {
        return null;
      }
      return Uri.tryParse(raw);
    }

    return HikConnectBootstrapRuntimeConfig(
      clientId: readString('ONYX_DVR_CLIENT_ID'),
      regionId: readString('ONYX_DVR_REGION_ID'),
      siteId: readString('ONYX_DVR_SITE_ID'),
      provider: readString(
        'ONYX_DVR_PROVIDER',
        fallback: 'hik_connect_openapi',
      ),
      apiBaseUri: readUri('ONYX_DVR_API_BASE_URL'),
      appKey: readString('ONYX_DVR_APP_KEY'),
      appSecret: readString('ONYX_DVR_APP_SECRET'),
      areaId: readString('ONYX_DVR_AREA_ID', fallback: '-1'),
      includeSubArea: readBool(
        'ONYX_DVR_INCLUDE_SUB_AREA',
        fallback: true,
      ),
      deviceSerialNo: readString('ONYX_DVR_DEVICE_SERIAL_NO'),
      alarmEventTypes: readAlarmEventTypes('ONYX_DVR_ALARM_EVENT_TYPES'),
      pageSize: readInt(
        'ONYX_DVR_PAGE_SIZE',
        fallback: defaultPageSize,
      ),
      maxPages: readInt(
        'ONYX_DVR_MAX_PAGES',
        fallback: defaultMaxPages,
      ),
      cameraPayloadPath: readString('ONYX_DVR_CAMERA_PAYLOAD_PATH'),
    );
  }

  bool get usesSavedCameraPayload => cameraPayloadPath.trim().isNotEmpty;

  List<String> get validationErrors {
    final errors = <String>[];
    if (clientId.isEmpty) {
      errors.add('Missing ONYX_DVR_CLIENT_ID.');
    }
    if (regionId.isEmpty) {
      errors.add('Missing ONYX_DVR_REGION_ID.');
    }
    if (siteId.isEmpty) {
      errors.add('Missing ONYX_DVR_SITE_ID.');
    }
    if (apiBaseUri == null ||
        !apiBaseUri!.hasScheme ||
        apiBaseUri!.host.trim().isEmpty) {
      errors.add(
        'Missing or invalid ONYX_DVR_API_BASE_URL. Use a full HTTPS base URL.',
      );
    }
    if (!usesSavedCameraPayload && appKey.isEmpty) {
      errors.add('Missing ONYX_DVR_APP_KEY.');
    }
    if (!usesSavedCameraPayload && appSecret.isEmpty) {
      errors.add('Missing ONYX_DVR_APP_SECRET.');
    }
    final normalizedProvider = provider.trim().toLowerCase();
    if (normalizedProvider.isNotEmpty &&
        !normalizedProvider.contains('hik_connect') &&
        !normalizedProvider.contains('hikconnect')) {
      errors.add(
        'ONYX_DVR_PROVIDER must target Hik-Connect OpenAPI for this bootstrap tool.',
      );
    }
    return List<String>.unmodifiable(errors);
  }

  bool get configured => validationErrors.isEmpty;

  HikConnectOpenApiConfig toApiConfig() {
    return HikConnectOpenApiConfig(
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      baseUri: apiBaseUri,
      appKey: appKey,
      appSecret: appSecret,
      areaId: areaId,
      includeSubArea: includeSubArea,
      deviceSerialNo: deviceSerialNo,
      alarmEventTypes: alarmEventTypes,
      cameraLabels: const <String, String>{},
    );
  }
}
