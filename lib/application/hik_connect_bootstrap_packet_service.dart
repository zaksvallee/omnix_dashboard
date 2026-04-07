import 'hik_connect_camera_bootstrap_service.dart';
import 'hik_connect_env_seed_formatter.dart';
import 'hik_connect_scope_seed_formatter.dart';

class HikConnectBootstrapPacketService {
  final HikConnectScopeSeedFormatter scopeSeedFormatter;
  final HikConnectEnvSeedFormatter envSeedFormatter;

  const HikConnectBootstrapPacketService({
    this.scopeSeedFormatter = const HikConnectScopeSeedFormatter(),
    this.envSeedFormatter = const HikConnectEnvSeedFormatter(),
  });

  String buildBootstrapPacket({
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
    final scopeJson = scopeSeedFormatter.formatScopeConfigJson(
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
    final envBlock = envSeedFormatter.formatEnvBlock(
      snapshot: snapshot,
      apiBaseUrl: apiBaseUrl,
      appKey: appKey,
      appSecret: appSecret,
      areaId: areaId,
      includeSubArea: includeSubArea,
      alarmEventTypes: alarmEventTypes,
      provider: provider,
    );

    final buffer = StringBuffer()
      ..writeln('HIK-CONNECT BOOTSTRAP PACKET')
      ..writeln(
        '${clientId.trim()} / ${siteId.trim()} • ${snapshot.summaryLabel}',
      )
      ..writeln();

    if (snapshot.areaNames.isNotEmpty) {
      buffer.writeln('Areas');
      for (final areaName in snapshot.areaNames) {
        buffer.writeln('- $areaName');
      }
      buffer.writeln();
    }

    if (snapshot.deviceSerials.isNotEmpty) {
      buffer.writeln('Device Serials');
      for (final serial in snapshot.deviceSerials) {
        buffer.writeln('- $serial');
      }
      buffer.writeln();
    }

    if (snapshot.cameras.isNotEmpty) {
      buffer.writeln('Discovered Cameras');
      for (final camera in snapshot.cameras) {
        final resourceId = camera.resourceId.trim().isEmpty
            ? 'resource-unset'
            : camera.resourceId.trim();
        final displayName = camera.displayName.trim().isEmpty
            ? resourceId
            : camera.displayName.trim();
        final serial = camera.deviceSerialNo.trim();
        final serialLabel = serial.isEmpty ? '' : ' • $serial';
        buffer.writeln('- $displayName [$resourceId]$serialLabel');
      }
      buffer.writeln();
    }

    buffer
      ..writeln('Recommended Next Step')
      ..writeln(
        '- Paste the scope JSON below into the ONYX DVR scope config, then run the first tenant smoke on queue alarms and live address lookup.',
      )
      ..writeln()
      ..writeln('Scope JSON')
      ..writeln('```json')
      ..writeln(scopeJson)
      ..writeln('```')
      ..writeln()
      ..writeln('Pilot Env Block')
      ..writeln('```sh')
      ..writeln(envBlock)
      ..writeln('```');

    return buffer.toString().trimRight();
  }
}
