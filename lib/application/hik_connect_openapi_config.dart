import 'dvr_scope_config.dart';

class HikConnectOpenApiConfig {
  final String clientId;
  final String regionId;
  final String siteId;
  final Uri? baseUri;
  final String appKey;
  final String appSecret;
  final String areaId;
  final bool includeSubArea;
  final String deviceSerialNo;
  final List<int> alarmEventTypes;
  final Map<String, String> cameraLabels;

  const HikConnectOpenApiConfig({
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.baseUri,
    required this.appKey,
    required this.appSecret,
    required this.areaId,
    required this.includeSubArea,
    required this.deviceSerialNo,
    required this.alarmEventTypes,
    required this.cameraLabels,
  });

  String get scopeKey => '${clientId.trim()}|${siteId.trim()}';

  bool get configured =>
      baseUri != null &&
      appKey.trim().isNotEmpty &&
      appSecret.trim().isNotEmpty;

  factory HikConnectOpenApiConfig.fromScope(DvrScopeConfig scope) {
    return HikConnectOpenApiConfig(
      clientId: scope.clientId,
      regionId: scope.regionId,
      siteId: scope.siteId,
      baseUri: scope.apiBaseUri,
      appKey: scope.appKey,
      appSecret: scope.appSecret,
      areaId: scope.areaId,
      includeSubArea: scope.includeSubArea,
      deviceSerialNo: scope.deviceSerialNo,
      alarmEventTypes: List<int>.unmodifiable(scope.alarmEventTypes),
      cameraLabels: Map<String, String>.unmodifiable(scope.cameraLabels),
    );
  }
}
