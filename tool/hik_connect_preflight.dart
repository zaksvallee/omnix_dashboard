import 'dart:io';

import 'package:omnix_dashboard/application/hik_connect_payload_bundle_locator.dart';
import 'package:omnix_dashboard/application/hik_connect_preflight_manifest_status_service.dart';
import 'package:omnix_dashboard/application/hik_connect_preflight_runner_service.dart';

Future<void> main() async {
  final env = Platform.environment;
  const bundleLocator = HikConnectPayloadBundleLocator();
  final bundle = bundleLocator.resolveFromEnvironment(env);
  final bundleDirectoryPath = (env['ONYX_DVR_PREFLIGHT_DIR'] ?? '').trim();
  final clientId = bundle.clientId;
  final regionId = bundle.regionId;
  final siteId = bundle.siteId;
  final apiBaseUrl = bundle.apiBaseUrl.isEmpty
      ? 'https://api.hik-connect.example.com'
      : bundle.apiBaseUrl;
  final cameraPath = bundle.cameraPayloadPath;
  final alarmPath = bundle.alarmPayloadPath;
  final livePath = bundle.liveAddressPayloadPath;
  final playbackPath = bundle.playbackPayloadPath;
  final downloadPath = bundle.videoDownloadPayloadPath;
  final reportOutputPath = bundle.reportOutputPath;
  final reportJsonOutputPath = bundle.reportJsonOutputPath;
  final scopeSeedOutputPath = bundle.scopeSeedOutputPath;
  final pilotEnvOutputPath = bundle.pilotEnvOutputPath;
  final bootstrapPacketOutputPath = bundle.bootstrapPacketOutputPath;
  final provider = (env['ONYX_DVR_PROVIDER'] ?? 'hik_connect_openapi').trim();
  final appKey = (env['ONYX_DVR_APP_KEY'] ?? 'replace-me').trim();
  final appSecret = (env['ONYX_DVR_APP_SECRET'] ?? 'replace-me').trim();

  if (!bundle.hasAny) {
    stderr.writeln('Hik-Connect preflight is missing payload paths.');
    stderr.writeln();
    stderr.writeln('Provide at least one payload path or a bundle dir:');
    stderr.writeln('- ONYX_DVR_PREFLIGHT_DIR');
    stderr.writeln('- ONYX_DVR_CAMERA_PAYLOAD_PATH');
    stderr.writeln('- ONYX_DVR_ALARM_PAYLOAD_PATH');
    stderr.writeln('- ONYX_DVR_LIVE_ADDRESS_PAYLOAD_PATH');
    stderr.writeln('- ONYX_DVR_PLAYBACK_PAYLOAD_PATH');
    stderr.writeln('- ONYX_DVR_VIDEO_DOWNLOAD_PAYLOAD_PATH');
    stderr.writeln();
    stderr.writeln('Then run: dart run tool/hik_connect_preflight.dart');
    exitCode = 64;
    return;
  }

  if ((cameraPath.isNotEmpty || alarmPath.isNotEmpty) &&
      (clientId.isEmpty || regionId.isEmpty || siteId.isEmpty)) {
    stderr.writeln(
      'Client, region, and site ids are required when camera or alarm payloads are provided.',
    );
    stderr.writeln('- ONYX_DVR_CLIENT_ID');
    stderr.writeln('- ONYX_DVR_REGION_ID');
    stderr.writeln('- ONYX_DVR_SITE_ID');
    stderr.writeln('- or provide them in bundle-manifest.json');
    exitCode = 64;
    return;
  }

  try {
    const runner = HikConnectPreflightRunnerService();
    final result = await runner.run(
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      apiBaseUrl: apiBaseUrl,
      provider: provider.isEmpty ? 'hik_connect_openapi' : provider,
      appKey: appKey.isEmpty ? 'replace-me' : appKey,
      appSecret: appSecret.isEmpty ? 'replace-me' : appSecret,
      areaId: bundle.areaId,
      includeSubArea: bundle.includeSubArea,
      alarmEventTypes: bundle.alarmEventTypes,
      cameraLabels: bundle.cameraLabels,
      cameraPayloadPath: cameraPath,
      alarmPayloadPath: alarmPath,
      liveAddressPayloadPath: livePath,
      playbackPayloadPath: playbackPath,
      videoDownloadPayloadPath: downloadPath,
      reportOutputPath: reportOutputPath,
      reportJsonOutputPath: reportJsonOutputPath,
      scopeSeedOutputPath: scopeSeedOutputPath,
      pilotEnvOutputPath: pilotEnvOutputPath,
      bootstrapPacketOutputPath: bootstrapPacketOutputPath,
    );
    if (bundleDirectoryPath.isNotEmpty) {
      const manifestStatusService = HikConnectPreflightManifestStatusService();
      await manifestStatusService.updateBundleManifest(
        bundleDirectoryPath: bundleDirectoryPath,
        result: result,
      );
    }
    stdout.writeln(result.report);
    if (result.reportOutputPath.isNotEmpty) {
      stdout.writeln();
      stdout.writeln('Saved report: ${result.reportOutputPath}');
    }
    if (result.reportJsonOutputPath.isNotEmpty) {
      stdout.writeln('Saved report JSON: ${result.reportJsonOutputPath}');
    }
    if (result.scopeSeedOutputPath.isNotEmpty) {
      stdout.writeln('Saved scope seed: ${result.scopeSeedOutputPath}');
    }
    if (result.pilotEnvOutputPath.isNotEmpty) {
      stdout.writeln('Saved pilot env: ${result.pilotEnvOutputPath}');
    }
    if (result.bootstrapPacketOutputPath.isNotEmpty) {
      stdout.writeln(
        'Saved bootstrap packet: ${result.bootstrapPacketOutputPath}',
      );
    }
  } on Object catch (error, stackTrace) {
    stderr.writeln('Hik-Connect preflight failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}
