import 'dart:convert';

import 'hik_connect_camera_bootstrap_service.dart';

class HikConnectScopeSeedFormatter {
  const HikConnectScopeSeedFormatter();

  Map<String, Object?> buildScopeConfigItem({
    required HikConnectCameraBootstrapSnapshot snapshot,
    required String clientId,
    required String regionId,
    required String siteId,
    required String apiBaseUrl,
    String appKey = 'replace-me',
    String appSecret = 'replace-me',
    String areaId = '-1',
    bool includeSubArea = true,
    List<int> alarmEventTypes = const <int>[0, 1, 100657],
    String provider = 'hik_connect_openapi',
  }) {
    final normalizedApiBaseUrl = apiBaseUrl.trim();
    final item = <String, Object?>{
      'client_id': clientId.trim(),
      'region_id': regionId.trim(),
      'site_id': siteId.trim(),
      'provider': provider.trim(),
      'api_base_url': normalizedApiBaseUrl,
      'app_key': appKey.trim(),
      'app_secret': appSecret.trim(),
      'area_id': areaId.trim(),
      'include_sub_area': includeSubArea,
      'alarm_event_types': List<int>.from(alarmEventTypes),
      'camera_labels': _sortedCameraLabels(snapshot.cameraLabelSeeds),
    };
    final preferredSerial = snapshot.preferredDeviceSerialNo.trim();
    if (preferredSerial.isNotEmpty) {
      item['device_serial_no'] = preferredSerial;
    }
    return item;
  }

  String formatScopeConfigJson({
    required HikConnectCameraBootstrapSnapshot snapshot,
    required String clientId,
    required String regionId,
    required String siteId,
    required String apiBaseUrl,
    String appKey = 'replace-me',
    String appSecret = 'replace-me',
    String areaId = '-1',
    bool includeSubArea = true,
    List<int> alarmEventTypes = const <int>[0, 1, 100657],
    String provider = 'hik_connect_openapi',
  }) {
    final item = buildScopeConfigItem(
      snapshot: snapshot,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      apiBaseUrl: apiBaseUrl,
      appKey: appKey,
      appSecret: appSecret,
      areaId: areaId,
      includeSubArea: includeSubArea,
      alarmEventTypes: alarmEventTypes,
      provider: provider,
    );
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(<Map<String, Object?>>[item]);
  }

  static Map<String, String> _sortedCameraLabels(Map<String, String> raw) {
    final keys = raw.keys.toList(growable: false)..sort();
    return <String, String>{
      for (final key in keys) key: raw[key]!,
    };
  }
}
