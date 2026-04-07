import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:omnix_dashboard/application/hik_connect_bootstrap_orchestrator_service.dart';
import 'package:omnix_dashboard/application/hik_connect_bootstrap_runtime_config.dart';
import 'package:omnix_dashboard/application/hik_connect_camera_payload_loader.dart';
import 'package:omnix_dashboard/application/hik_connect_openapi_client.dart';

Future<void> main() async {
  final runtime = HikConnectBootstrapRuntimeConfig.fromEnvironment(
    Platform.environment,
  );
  if (!runtime.configured) {
    stderr.writeln('Hik-Connect bootstrap is missing required env values:');
    for (final error in runtime.validationErrors) {
      stderr.writeln('- $error');
    }
    stderr.writeln();
    stderr.writeln('Required env keys:');
    for (final key in HikConnectBootstrapRuntimeConfig.requiredEnvNames) {
      stderr.writeln('- $key');
    }
    stderr.writeln();
    stderr.writeln(
      'Then run: dart run tool/hik_connect_bootstrap.dart',
    );
    exitCode = 64;
    return;
  }

  try {
    const orchestrator = HikConnectBootstrapOrchestratorService();
    final result = await (() async {
      if (runtime.usesSavedCameraPayload) {
        const loader = HikConnectCameraPayloadLoader();
        final pages = await loader.loadPagesFromFile(runtime.cameraPayloadPath);
        return orchestrator.runFromPages(
          pages,
          clientId: runtime.clientId,
          regionId: runtime.regionId,
          siteId: runtime.siteId,
          apiBaseUrl: runtime.apiBaseUri.toString(),
          appKey: runtime.appKey.isEmpty ? 'replace-me' : runtime.appKey,
          appSecret: runtime.appSecret.isEmpty
              ? 'replace-me'
              : runtime.appSecret,
          areaId: runtime.areaId,
          includeSubArea: runtime.includeSubArea,
          alarmEventTypes: runtime.alarmEventTypes,
          provider: runtime.provider,
        );
      }

      final client = http.Client();
      try {
        final api = HikConnectOpenApiClient(
          config: runtime.toApiConfig(),
          client: client,
        );
        return await orchestrator.run(
          api,
          clientId: runtime.clientId,
          regionId: runtime.regionId,
          siteId: runtime.siteId,
          apiBaseUrl: runtime.apiBaseUri.toString(),
          appKey: runtime.appKey,
          appSecret: runtime.appSecret,
          areaId: runtime.areaId,
          includeSubArea: runtime.includeSubArea,
          alarmEventTypes: runtime.alarmEventTypes,
          provider: runtime.provider,
          pageSize: runtime.pageSize,
          maxPages: runtime.maxPages,
          deviceSerialNo: runtime.deviceSerialNo,
        );
      } finally {
        client.close();
      }
    })();

    stdout.writeln(result.readinessLabel);
    stdout.writeln(
      '${runtime.clientId} / ${runtime.siteId} • ${result.snapshot.summaryLabel}',
    );
    if (result.warnings.isNotEmpty) {
      stdout.writeln();
      stdout.writeln('Warnings');
      for (final warning in result.warnings) {
        stdout.writeln('- $warning');
      }
    }
    stdout.writeln();
    stdout.writeln(result.operatorPacket);
  } on Object catch (error, stackTrace) {
    stderr.writeln('Hik-Connect bootstrap failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}
