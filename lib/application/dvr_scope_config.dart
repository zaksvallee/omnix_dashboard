import 'dart:convert';

class DvrScopeConfig {
  final String clientId;
  final String regionId;
  final String siteId;
  final String provider;
  final Uri? eventsUri;
  final Uri? apiBaseUri;
  final String authMode;
  final String username;
  final String password;
  final String bearerToken;
  final String appKey;
  final String appSecret;
  final String areaId;
  final bool includeSubArea;
  final String deviceSerialNo;
  final List<int> alarmEventTypes;
  final Map<String, String> cameraLabels;

  const DvrScopeConfig({
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.provider,
    required this.eventsUri,
    this.apiBaseUri,
    required this.authMode,
    required this.username,
    required this.password,
    required this.bearerToken,
    this.appKey = '',
    this.appSecret = '',
    this.areaId = '',
    this.includeSubArea = true,
    this.deviceSerialNo = '',
    this.alarmEventTypes = const <int>[],
    this.cameraLabels = const <String, String>{},
  });

  String get scopeKey => '${clientId.trim()}|${siteId.trim()}';

  bool get configured =>
      clientId.trim().isNotEmpty &&
      regionId.trim().isNotEmpty &&
      siteId.trim().isNotEmpty &&
      provider.trim().isNotEmpty &&
      eventsUri != null;

  bool get hikConnectConfigured =>
      clientId.trim().isNotEmpty &&
      regionId.trim().isNotEmpty &&
      siteId.trim().isNotEmpty &&
      provider.trim().isNotEmpty &&
      apiBaseUri != null &&
      appKey.trim().isNotEmpty &&
      appSecret.trim().isNotEmpty;

  static List<DvrScopeConfig> parseJson(
    String rawJson, {
    required String fallbackClientId,
    required String fallbackRegionId,
    required String fallbackSiteId,
    required String fallbackProvider,
    required Uri? fallbackEventsUri,
    Uri? fallbackApiBaseUri,
    required String fallbackAuthMode,
    required String fallbackUsername,
    required String fallbackPassword,
    required String fallbackBearerToken,
    String fallbackAppKey = '',
    String fallbackAppSecret = '',
    String fallbackAreaId = '',
    bool fallbackIncludeSubArea = true,
    String fallbackDeviceSerialNo = '',
    List<int> fallbackAlarmEventTypes = const <int>[],
  }) {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(trimmed);
    final rawItems = switch (decoded) {
      List value => value,
      Map value => value['items'] is List ? value['items'] as List : const [],
      _ => const [],
    };
    final configs = <DvrScopeConfig>[];
    for (final item in rawItems.whereType<Map>()) {
      String readString(String key, {String fallback = ''}) {
        return (item[key] ?? fallback).toString().trim();
      }

      Map<String, String> readCameraLabels() {
        final raw = item['camera_labels'];
        if (raw is! Map) {
          return const <String, String>{};
        }
        final output = <String, String>{};
        for (final entry in raw.entries) {
          final key = entry.key.toString().trim().toLowerCase();
          final value = entry.value.toString().trim();
          if (key.isEmpty || value.isEmpty) {
            continue;
          }
          output[key] = value;
        }
        return output;
      }

      bool readBool(String key, {bool fallback = false}) {
        final raw = item[key];
        if (raw is bool) {
          return raw;
        }
        final normalized = (raw ?? '').toString().trim().toLowerCase();
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

      List<int> readAlarmEventTypes() {
        final raw = item['alarm_event_types'];
        if (raw is! List) {
          return const <int>[];
        }
        final output = <int>[];
        for (final entry in raw) {
          final parsed = int.tryParse(entry.toString().trim());
          if (parsed != null) {
            output.add(parsed);
          }
        }
        return output;
      }

      Uri? readUri(String value) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) {
          return null;
        }
        return Uri.tryParse(trimmed);
      }

      final provider = readString('provider', fallback: fallbackProvider);
      final normalizedProvider = provider.toLowerCase().replaceAll('-', '_');
      final usesHikConnectOpenApi =
          normalizedProvider.contains('hik_connect') ||
          normalizedProvider.contains('hikconnect') ||
          normalizedProvider.contains('hikcentral_connect');
      final eventsUrl = readString(
        'events_url',
        fallback: usesHikConnectOpenApi
            ? ''
            : fallbackEventsUri?.toString() ?? '',
      );
      final apiBaseUrl = readString(
        'api_base_url',
        fallback: fallbackApiBaseUri?.toString() ?? '',
      );
      final alarmEventTypes = readAlarmEventTypes();
      configs.add(
        DvrScopeConfig(
          clientId: readString('client_id', fallback: fallbackClientId),
          regionId: readString('region_id', fallback: fallbackRegionId),
          siteId: readString('site_id', fallback: fallbackSiteId),
          provider: provider,
          eventsUri: readUri(eventsUrl),
          apiBaseUri: readUri(apiBaseUrl),
          authMode: readString('auth_mode', fallback: fallbackAuthMode),
          username: readString('username', fallback: fallbackUsername),
          password: readString('password', fallback: fallbackPassword),
          bearerToken: readString(
            'bearer_token',
            fallback: fallbackBearerToken,
          ),
          appKey: readString('app_key', fallback: fallbackAppKey),
          appSecret: readString('app_secret', fallback: fallbackAppSecret),
          areaId: readString('area_id', fallback: fallbackAreaId),
          includeSubArea: readBool(
            'include_sub_area',
            fallback: fallbackIncludeSubArea,
          ),
          deviceSerialNo: readString(
            'device_serial_no',
            fallback: fallbackDeviceSerialNo,
          ),
          alarmEventTypes: alarmEventTypes.isEmpty
              ? fallbackAlarmEventTypes
              : alarmEventTypes,
          cameraLabels: readCameraLabels(),
        ),
      );
    }
    return configs
        .where((entry) => entry.configured || entry.hikConnectConfigured)
        .toList(growable: false);
  }
}
