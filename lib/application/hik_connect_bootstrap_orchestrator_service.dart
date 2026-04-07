import 'hik_connect_bootstrap_packet_service.dart';
import 'hik_connect_camera_bootstrap_service.dart';
import 'hik_connect_camera_catalog.dart';
import 'hik_connect_env_seed_formatter.dart';
import 'hik_connect_openapi_client.dart';
import 'hik_connect_scope_seed_formatter.dart';

class HikConnectBootstrapRunResult {
  final HikConnectCameraBootstrapSnapshot snapshot;
  final Map<String, Object?> scopeConfigItem;
  final String scopeConfigJson;
  final String pilotEnvBlock;
  final String operatorPacket;
  final List<String> warnings;

  const HikConnectBootstrapRunResult({
    required this.snapshot,
    required this.scopeConfigItem,
    required this.scopeConfigJson,
    required this.pilotEnvBlock,
    required this.operatorPacket,
    required this.warnings,
  });

  bool get readyForPilot => snapshot.cameraCount > 0;

  String get readinessLabel => readyForPilot ? 'READY FOR PILOT' : 'INCOMPLETE';
}

class HikConnectBootstrapOrchestratorService {
  final HikConnectCameraBootstrapService bootstrapService;
  final HikConnectScopeSeedFormatter scopeSeedFormatter;
  final HikConnectEnvSeedFormatter envSeedFormatter;
  final HikConnectBootstrapPacketService packetService;

  const HikConnectBootstrapOrchestratorService({
    this.bootstrapService = const HikConnectCameraBootstrapService(),
    this.scopeSeedFormatter = const HikConnectScopeSeedFormatter(),
    this.envSeedFormatter = const HikConnectEnvSeedFormatter(),
    this.packetService = const HikConnectBootstrapPacketService(),
  });

  Future<HikConnectBootstrapRunResult> run(
    HikConnectOpenApiClient api, {
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
    int pageSize = 200,
    int maxPages = 20,
    String deviceSerialNo = '',
  }) async {
    final snapshot = await bootstrapService.fetchSnapshot(
      api,
      pageSize: pageSize,
      maxPages: maxPages,
      areaId: areaId,
      includeSubArea: includeSubArea,
      deviceSerialNo: deviceSerialNo,
    );
    return buildResultFromSnapshot(
      snapshot,
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
  }

  HikConnectBootstrapRunResult runFromPages(
    Iterable<HikConnectCameraCatalogPage> pages, {
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
    final snapshot = bootstrapService.buildSnapshotFromPages(pages);
    return buildResultFromSnapshot(
      snapshot,
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
  }

  HikConnectBootstrapRunResult buildResultFromSnapshot(
    HikConnectCameraBootstrapSnapshot snapshot, {
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
    final scopeConfigItem = scopeSeedFormatter.buildScopeConfigItem(
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
    final scopeConfigJson = scopeSeedFormatter.formatScopeConfigJson(
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
    final pilotEnvBlock = envSeedFormatter.formatEnvBlock(
      snapshot: snapshot,
      apiBaseUrl: apiBaseUrl,
      appKey: appKey,
      appSecret: appSecret,
      areaId: areaId,
      includeSubArea: includeSubArea,
      alarmEventTypes: alarmEventTypes,
      provider: provider,
    );
    final operatorPacket = packetService.buildBootstrapPacket(
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

    return HikConnectBootstrapRunResult(
      snapshot: snapshot,
      scopeConfigItem: scopeConfigItem,
      scopeConfigJson: scopeConfigJson,
      pilotEnvBlock: pilotEnvBlock,
      operatorPacket: operatorPacket,
      warnings: _buildWarnings(snapshot),
    );
  }

  List<String> _buildWarnings(HikConnectCameraBootstrapSnapshot snapshot) {
    final warnings = <String>[];
    if (snapshot.cameraCount == 0) {
      warnings.add(
        'No cameras were returned by Hik-Connect. Verify area scope, tenant access, and device enrollment before rollout.',
      );
    }
    if (snapshot.deviceSerials.length > 1) {
      warnings.add(
        'Multiple device serials were discovered. Keep `device_serial_no` blank for the first review or split the site into recorder-specific scopes if needed.',
      );
    }
    if (snapshot.deviceSerials.isEmpty) {
      warnings.add(
        'No device serials were returned. Live-address requests may need a real serial from the tenant inventory before operator playback can be verified.',
      );
    }
    if (snapshot.areaNames.isEmpty) {
      warnings.add(
        'Area names were empty in the bootstrap response. Keep the site mapping under review until the tenant inventory exposes stable area labels.',
      );
    }
    return List<String>.unmodifiable(warnings);
  }
}
