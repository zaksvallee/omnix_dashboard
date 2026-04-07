import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:omnix_dashboard/application/hik_connect_bootstrap_runtime_config.dart';
import 'package:omnix_dashboard/application/hik_connect_openapi_client.dart';
import 'package:omnix_dashboard/application/hik_connect_openapi_config.dart';
import 'package:omnix_dashboard/application/hik_connect_payload_bundle_collector_service.dart';
import 'package:omnix_dashboard/application/hik_connect_payload_bundle_locator.dart';
import 'package:omnix_dashboard/application/hik_connect_preflight_manifest_status_service.dart';
import 'package:omnix_dashboard/application/hik_connect_preflight_runner_service.dart';

Future<void> main(List<String> args) async {
  final env = Platform.environment;
  final directoryPath = args.isNotEmpty
      ? args.first.trim()
      : (env['ONYX_DVR_PREFLIGHT_DIR'] ?? '').trim();
  if (directoryPath.isEmpty) {
    stderr.writeln(
      'Provide a target directory as the first argument or set ONYX_DVR_PREFLIGHT_DIR.',
    );
    stderr.writeln();
    stderr.writeln(
      'Example: dart run tool/hik_connect_collect_preflight.dart /absolute/path/to/bundle',
    );
    exitCode = 64;
    return;
  }

  final runtime = HikConnectBootstrapRuntimeConfig.fromEnvironment(env);
  if (!runtime.configured) {
    stderr.writeln(
      'Hik-Connect collect+preflight is missing configuration.',
    );
    stderr.writeln();
    for (final error in runtime.validationErrors) {
      stderr.writeln('- $error');
    }
    exitCode = 64;
    return;
  }

  const bundleLocator = HikConnectPayloadBundleLocator();
  final requestedBundle = bundleLocator.resolveFromEnvironment(<String, String>{
    ...env,
    'ONYX_DVR_PREFLIGHT_DIR': directoryPath,
  });
  final representativeCameraId = requestedBundle.representativeCameraId;
  final representativeDeviceSerial =
      requestedBundle.representativeDeviceSerialNo;

  final client = http.Client();
  try {
    final api = HikConnectOpenApiClient(
      config: HikConnectOpenApiConfig(
        clientId: runtime.clientId,
        regionId: runtime.regionId,
        siteId: runtime.siteId,
        baseUri: runtime.apiBaseUri,
        appKey: runtime.appKey,
        appSecret: runtime.appSecret,
        areaId: requestedBundle.areaId,
        includeSubArea: requestedBundle.includeSubArea,
        deviceSerialNo: requestedBundle.deviceSerialNo,
        alarmEventTypes: requestedBundle.alarmEventTypes,
        cameraLabels: requestedBundle.cameraLabels,
      ),
      client: client,
    );
    const collector = HikConnectPayloadBundleCollectorService();
    final collection = await collector.collect(
      api: api,
      directoryPath: directoryPath,
      clientId: runtime.clientId,
      regionId: runtime.regionId,
      siteId: runtime.siteId,
      representativeCameraId: representativeCameraId,
      representativeDeviceSerial: representativeDeviceSerial,
      pageSize: requestedBundle.pageSize,
      maxPages: requestedBundle.maxPages,
      playbackLookback: Duration(
        minutes: requestedBundle.playbackLookbackMinutes,
      ),
      playbackWindow: Duration(
        minutes: requestedBundle.playbackWindowMinutes,
      ),
    );

    final preflightEnv = <String, String>{
      ...env,
      'ONYX_DVR_PREFLIGHT_DIR': collection.directoryPath,
    };
    final bundle = bundleLocator.resolveFromEnvironment(preflightEnv);

    const runner = HikConnectPreflightRunnerService();
    final preflight = await runner.run(
      clientId: bundle.clientId,
      regionId: bundle.regionId,
      siteId: bundle.siteId,
      apiBaseUrl: bundle.apiBaseUrl.isEmpty
          ? 'https://api.hik-connect.example.com'
          : bundle.apiBaseUrl,
      provider: 'hik_connect_openapi',
      appKey: runtime.appKey,
      appSecret: runtime.appSecret,
      areaId: bundle.areaId,
      includeSubArea: bundle.includeSubArea,
      alarmEventTypes: bundle.alarmEventTypes,
      cameraLabels: bundle.cameraLabels,
      cameraPayloadPath: bundle.cameraPayloadPath,
      alarmPayloadPath: bundle.alarmPayloadPath,
      liveAddressPayloadPath: bundle.liveAddressPayloadPath,
      playbackPayloadPath: bundle.playbackPayloadPath,
      videoDownloadPayloadPath: bundle.videoDownloadPayloadPath,
      reportOutputPath: bundle.reportOutputPath,
      reportJsonOutputPath: bundle.reportJsonOutputPath,
      scopeSeedOutputPath: bundle.scopeSeedOutputPath,
      pilotEnvOutputPath: bundle.pilotEnvOutputPath,
      bootstrapPacketOutputPath: bundle.bootstrapPacketOutputPath,
    );
    const manifestStatusService = HikConnectPreflightManifestStatusService();
    await manifestStatusService.updateBundleManifest(
      bundleDirectoryPath: collection.directoryPath,
      result: preflight,
    );

    stdout.writeln('HIK-CONNECT BUNDLE COLLECTED');
    stdout.writeln(collection.directoryPath);
    stdout.writeln('- cameras: ${collection.cameraCount}');
    stdout.writeln('- alarm messages: ${collection.alarmMessageCount}');
    if (collection.representativeCameraId.isNotEmpty) {
      stdout.writeln(
        '- representative camera: ${collection.representativeCameraId}',
      );
    }
    if (collection.representativeDeviceSerial.isNotEmpty) {
      stdout.writeln(
        '- representative serial: ${collection.representativeDeviceSerial}',
      );
    }
    if (collection.warnings.isNotEmpty) {
      stdout.writeln();
      stdout.writeln('Collection Warnings');
      for (final warning in collection.warnings) {
        stdout.writeln('- $warning');
      }
    }
    stdout.writeln();
    stdout.writeln(preflight.report);
    if (preflight.reportOutputPath.isNotEmpty) {
      stdout.writeln();
      stdout.writeln('Saved report: ${preflight.reportOutputPath}');
    }
    if (preflight.reportJsonOutputPath.isNotEmpty) {
      stdout.writeln('Saved report JSON: ${preflight.reportJsonOutputPath}');
    }
    if (preflight.scopeSeedOutputPath.isNotEmpty) {
      stdout.writeln('Saved scope seed: ${preflight.scopeSeedOutputPath}');
    }
    if (preflight.pilotEnvOutputPath.isNotEmpty) {
      stdout.writeln('Saved pilot env: ${preflight.pilotEnvOutputPath}');
    }
    if (preflight.bootstrapPacketOutputPath.isNotEmpty) {
      stdout.writeln(
        'Saved bootstrap packet: ${preflight.bootstrapPacketOutputPath}',
      );
    }
  } on Object catch (error, stackTrace) {
    stderr.writeln('Hik-Connect collect+preflight failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  } finally {
    client.close();
  }
}
