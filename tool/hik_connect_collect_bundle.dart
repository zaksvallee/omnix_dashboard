import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:omnix_dashboard/application/hik_connect_bootstrap_runtime_config.dart';
import 'package:omnix_dashboard/application/hik_connect_openapi_client.dart';
import 'package:omnix_dashboard/application/hik_connect_openapi_config.dart';
import 'package:omnix_dashboard/application/hik_connect_payload_bundle_collector_service.dart';
import 'package:omnix_dashboard/application/hik_connect_payload_bundle_locator.dart';

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
      'Example: dart run tool/hik_connect_collect_bundle.dart /absolute/path/to/bundle',
    );
    exitCode = 64;
    return;
  }

  final runtime = HikConnectBootstrapRuntimeConfig.fromEnvironment(env);
  if (!runtime.configured) {
    stderr.writeln('Hik-Connect bundle collection is missing configuration.');
    stderr.writeln();
    for (final error in runtime.validationErrors) {
      stderr.writeln('- $error');
    }
    exitCode = 64;
    return;
  }

  const bundleLocator = HikConnectPayloadBundleLocator();
  final bundle = bundleLocator.resolveFromEnvironment(<String, String>{
    ...env,
    'ONYX_DVR_PREFLIGHT_DIR': directoryPath,
  });
  final representativeCameraId = bundle.representativeCameraId;
  final representativeDeviceSerial = bundle.representativeDeviceSerialNo;

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
        areaId: bundle.areaId,
        includeSubArea: bundle.includeSubArea,
        deviceSerialNo: bundle.deviceSerialNo,
        alarmEventTypes: bundle.alarmEventTypes,
        cameraLabels: bundle.cameraLabels,
      ),
      client: client,
    );
    const service = HikConnectPayloadBundleCollectorService();
    final result = await service.collect(
      api: api,
      directoryPath: directoryPath,
      clientId: runtime.clientId,
      regionId: runtime.regionId,
      siteId: runtime.siteId,
      representativeCameraId: representativeCameraId,
      representativeDeviceSerial: representativeDeviceSerial,
      pageSize: bundle.pageSize,
      maxPages: bundle.maxPages,
      playbackLookback: Duration(minutes: bundle.playbackLookbackMinutes),
      playbackWindow: Duration(minutes: bundle.playbackWindowMinutes),
    );

    stdout.writeln('HIK-CONNECT BUNDLE COLLECTED');
    stdout.writeln(result.directoryPath);
    stdout.writeln('- cameras: ${result.cameraCount}');
    stdout.writeln('- alarm messages: ${result.alarmMessageCount}');
    if (result.representativeCameraId.isNotEmpty) {
      stdout.writeln('- representative camera: ${result.representativeCameraId}');
    }
    if (result.representativeDeviceSerial.isNotEmpty) {
      stdout.writeln(
        '- representative serial: ${result.representativeDeviceSerial}',
      );
    }
    for (final entry in result.outputPaths.entries) {
      stdout.writeln('- ${entry.key}: ${entry.value}');
    }
    if (result.warnings.isNotEmpty) {
      stdout.writeln();
      stdout.writeln('Warnings');
      for (final warning in result.warnings) {
        stdout.writeln('- $warning');
      }
    }
    stdout.writeln();
    stdout.writeln(
      'Next: ONYX_DVR_PREFLIGHT_DIR="${result.directoryPath}" dart run tool/hik_connect_preflight.dart',
    );
  } on Object catch (error, stackTrace) {
    stderr.writeln('Hik-Connect bundle collection failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  } finally {
    client.close();
  }
}
