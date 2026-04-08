import 'dart:convert';
import 'dart:io';

import 'hik_connect_alarm_payload_loader.dart';
import 'hik_connect_alarm_smoke_service.dart';
import 'hik_connect_bootstrap_orchestrator_service.dart';
import 'hik_connect_camera_payload_loader.dart';
import 'hik_connect_preflight_bundle_health_service.dart';
import 'hik_connect_preflight_next_step_service.dart';
import 'hik_connect_preflight_payload_inventory_service.dart';
import 'hik_connect_preflight_report_service.dart';
import 'hik_connect_video_payload_loader.dart';
import 'hik_connect_video_smoke_service.dart';

class HikConnectPreflightRunResult {
  final String report;
  final Map<String, Object?> jsonReport;
  final String reportOutputPath;
  final String reportJsonOutputPath;
  final String scopeSeedOutputPath;
  final String pilotEnvOutputPath;
  final String bootstrapPacketOutputPath;

  const HikConnectPreflightRunResult({
    required this.report,
    required this.jsonReport,
    required this.reportOutputPath,
    required this.reportJsonOutputPath,
    required this.scopeSeedOutputPath,
    required this.pilotEnvOutputPath,
    required this.bootstrapPacketOutputPath,
  });
}

class HikConnectPreflightRunnerService {
  const HikConnectPreflightRunnerService();

  Future<HikConnectPreflightRunResult> run({
    required String clientId,
    required String regionId,
    required String siteId,
    required String apiBaseUrl,
    String provider = 'hik_connect_openapi',
    String appKey = '',
    String appSecret = '',
    String areaId = '-1',
    bool includeSubArea = true,
    List<int> alarmEventTypes = const <int>[0, 1, 100657],
    Map<String, String> cameraLabels = const <String, String>{},
    required String cameraPayloadPath,
    required String alarmPayloadPath,
    required String liveAddressPayloadPath,
    required String playbackPayloadPath,
    required String videoDownloadPayloadPath,
    required String reportOutputPath,
    required String reportJsonOutputPath,
    String scopeSeedOutputPath = '',
    String pilotEnvOutputPath = '',
    String bootstrapPacketOutputPath = '',
    bool writeOutputs = true,
  }) async {
    HikConnectBootstrapRunResult? bootstrap;
    HikConnectAlarmSmokeResult? alarm;
    HikConnectVideoSmokeResult? video;

    if (cameraPayloadPath.isNotEmpty) {
      const loader = HikConnectCameraPayloadLoader();
      const orchestrator = HikConnectBootstrapOrchestratorService();
      final pages = await loader.loadPagesFromFile(
        cameraPayloadPath,
        cameraLabels: cameraLabels,
      );
      bootstrap = orchestrator.runFromPages(
        pages,
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

    if (alarmPayloadPath.isNotEmpty) {
      const loader = HikConnectAlarmPayloadLoader();
      const service = HikConnectAlarmSmokeService();
      final batch = await loader.loadBatchFromFile(alarmPayloadPath);
      final baseUri = Uri.tryParse(apiBaseUrl.trim()) ?? Uri();
      alarm = service.evaluateBatch(
        batch,
        baseUri: baseUri,
        clientId: clientId,
        regionId: regionId,
        siteId: siteId,
      );
    }

    if (liveAddressPayloadPath.isNotEmpty ||
        playbackPayloadPath.isNotEmpty ||
        videoDownloadPayloadPath.isNotEmpty) {
      const loader = HikConnectVideoPayloadLoader();
      const service = HikConnectVideoSmokeService();
      final liveResponse = liveAddressPayloadPath.isEmpty
          ? null
          : await loader.loadResponseFromFile(liveAddressPayloadPath);
      final playbackResponse = playbackPayloadPath.isEmpty
          ? null
          : await loader.loadResponseFromFile(playbackPayloadPath);
      final downloadResponse = videoDownloadPayloadPath.isEmpty
          ? null
          : await loader.loadResponseFromFile(videoDownloadPayloadPath);
      video = service.evaluate(
        liveAddressResponse: liveResponse,
        playbackSearchResponse: playbackResponse,
        videoDownloadResponse: downloadResponse,
      );
    }

    const bundleHealthService = HikConnectPreflightBundleHealthService();
    final bundleHealthNotes = bundleHealthService.buildNotes(
      cameraPayloadPath: cameraPayloadPath,
      alarmPayloadPath: alarmPayloadPath,
      liveAddressPayloadPath: liveAddressPayloadPath,
      playbackPayloadPath: playbackPayloadPath,
      videoDownloadPayloadPath: videoDownloadPayloadPath,
      bootstrap: bootstrap,
      alarm: alarm,
      video: video,
    );
    const payloadInventoryService = HikConnectPreflightPayloadInventoryService();
    final payloadInventory = payloadInventoryService.buildInventory(
      cameraPayloadPath: cameraPayloadPath,
      alarmPayloadPath: alarmPayloadPath,
      liveAddressPayloadPath: liveAddressPayloadPath,
      playbackPayloadPath: playbackPayloadPath,
      videoDownloadPayloadPath: videoDownloadPayloadPath,
    );
    const nextStepService = HikConnectPreflightNextStepService();
    final nextSteps = nextStepService.buildSteps(
      payloadInventory: payloadInventory,
      bootstrap: bootstrap,
      alarm: alarm,
      video: video,
    );
    var savedScopeSeedOutputPath = '';
    var savedPilotEnvOutputPath = '';
    var savedBootstrapPacketOutputPath = '';

    if (writeOutputs && bootstrap != null) {
      savedScopeSeedOutputPath = await _writeTextArtifact(
        scopeSeedOutputPath,
        bootstrap.scopeConfigJson,
      );
      savedPilotEnvOutputPath = await _writeTextArtifact(
        pilotEnvOutputPath,
        bootstrap.pilotEnvBlock,
      );
      savedBootstrapPacketOutputPath = await _writeTextArtifact(
        bootstrapPacketOutputPath,
        bootstrap.operatorPacket,
      );
    }

    final rolloutArtifacts = _buildRolloutArtifacts(
      scopeSeedOutputPath: savedScopeSeedOutputPath,
      pilotEnvOutputPath: savedPilotEnvOutputPath,
      bootstrapPacketOutputPath: savedBootstrapPacketOutputPath,
    );

    const reportService = HikConnectPreflightReportService();
    final report = reportService.buildReport(
      clientId: clientId.isEmpty ? 'CLIENT-UNSET' : clientId,
      regionId: regionId.isEmpty ? 'REGION-UNSET' : regionId,
      siteId: siteId.isEmpty ? 'SITE-UNSET' : siteId,
      bootstrap: bootstrap,
      alarm: alarm,
      video: video,
      bundleHealthNotes: bundleHealthNotes,
      payloadInventory: payloadInventory,
      rolloutArtifacts: rolloutArtifacts,
      nextSteps: nextSteps,
    );
    final jsonReport = reportService.buildJsonReport(
      clientId: clientId.isEmpty ? 'CLIENT-UNSET' : clientId,
      regionId: regionId.isEmpty ? 'REGION-UNSET' : regionId,
      siteId: siteId.isEmpty ? 'SITE-UNSET' : siteId,
      bootstrap: bootstrap,
      alarm: alarm,
      video: video,
      bundleHealthNotes: bundleHealthNotes,
      payloadInventory: payloadInventory,
      rolloutArtifacts: rolloutArtifacts,
      nextSteps: nextSteps,
    );

    if (writeOutputs) {
      await _writeMarkdownReport(reportOutputPath, report);
      await _writeJsonReport(reportJsonOutputPath, jsonReport);
    }

    return HikConnectPreflightRunResult(
      report: report,
      jsonReport: jsonReport,
      reportOutputPath: reportOutputPath.trim(),
      reportJsonOutputPath: reportJsonOutputPath.trim(),
      scopeSeedOutputPath: savedScopeSeedOutputPath,
      pilotEnvOutputPath: savedPilotEnvOutputPath,
      bootstrapPacketOutputPath: savedBootstrapPacketOutputPath,
    );
  }

  Future<void> _writeMarkdownReport(String path, String report) async {
    await _writeTextArtifact(path, report);
  }

  Future<void> _writeJsonReport(
    String path,
    Map<String, Object?> jsonReport,
  ) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final outputFile = File(trimmed);
    final parent = outputFile.parent;
    if (!parent.existsSync()) {
      await parent.create(recursive: true);
    }
    final encoded = const JsonEncoder.withIndent('  ').convert(jsonReport);
    await outputFile.writeAsString('$encoded\n');
  }

  Future<String> _writeTextArtifact(String path, String contents) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final outputFile = File(trimmed);
    final parent = outputFile.parent;
    if (!parent.existsSync()) {
      await parent.create(recursive: true);
    }
    await outputFile.writeAsString('$contents\n');
    return outputFile.path;
  }

  List<Map<String, Object?>> _buildRolloutArtifacts({
    required String scopeSeedOutputPath,
    required String pilotEnvOutputPath,
    required String bootstrapPacketOutputPath,
  }) {
    final artifacts = <Map<String, Object?>>[];
    if (scopeSeedOutputPath.trim().isNotEmpty) {
      artifacts.add(<String, Object?>{
        'key': 'scope_seed',
        'label': 'scope seed',
        'status': 'saved',
        'path': scopeSeedOutputPath.trim(),
      });
    }
    if (pilotEnvOutputPath.trim().isNotEmpty) {
      artifacts.add(<String, Object?>{
        'key': 'pilot_env',
        'label': 'pilot env',
        'status': 'saved',
        'path': pilotEnvOutputPath.trim(),
      });
    }
    if (bootstrapPacketOutputPath.trim().isNotEmpty) {
      artifacts.add(<String, Object?>{
        'key': 'bootstrap_packet',
        'label': 'bootstrap packet',
        'status': 'saved',
        'path': bootstrapPacketOutputPath.trim(),
      });
    }
    return List<Map<String, Object?>>.unmodifiable(artifacts);
  }
}
