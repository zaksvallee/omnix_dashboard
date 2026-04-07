import 'dart:convert';
import 'dart:io';

import 'hik_connect_payload_bundle_locator.dart';
import 'hik_connect_preflight_runner_service.dart';

class HikConnectPreflightManifestStatusService {
  const HikConnectPreflightManifestStatusService();

  Future<String> updateBundleManifest({
    required String bundleDirectoryPath,
    required HikConnectPreflightRunResult result,
    DateTime? recordedAtUtc,
  }) async {
    final bundleDirectory = bundleDirectoryPath.trim();
    if (bundleDirectory.isEmpty) {
      return '';
    }
    final manifestFile = File(
      '$bundleDirectory/${HikConnectPayloadBundleLocator.defaultManifestFileName}',
    );
    if (!manifestFile.existsSync()) {
      return '';
    }

    final raw = await manifestFile.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return '';
    }

    final manifest = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final jsonReport = result.jsonReport;
    final cameraBootstrap = _readMap(jsonReport['camera_bootstrap']);
    final alarmSmoke = _readMap(jsonReport['alarm_smoke']);
    final videoSmoke = _readMap(jsonReport['video_smoke']);

    manifest['last_preflight_at_utc'] =
        (recordedAtUtc ?? DateTime.now().toUtc()).toUtc().toIso8601String();
    manifest['last_rollout_readiness'] =
        (jsonReport['rollout_readiness'] ?? '').toString().trim();
    _writeStringField(
      manifest,
      'last_report_path',
      result.reportOutputPath,
    );
    _writeStringField(
      manifest,
      'last_report_json_path',
      result.reportJsonOutputPath,
    );
    _writeStringField(
      manifest,
      'last_scope_seed_path',
      result.scopeSeedOutputPath,
    );
    _writeStringField(
      manifest,
      'last_pilot_env_path',
      result.pilotEnvOutputPath,
    );
    _writeStringField(
      manifest,
      'last_bootstrap_packet_path',
      result.bootstrapPacketOutputPath,
    );
    manifest['last_camera_ready_for_pilot'] =
        cameraBootstrap['ready_for_pilot'] == true;
    manifest['last_camera_count'] = _readInt(cameraBootstrap['camera_count']);
    manifest['last_alarm_total_messages'] = _readInt(
      alarmSmoke['total_messages'],
    );
    manifest['last_alarm_normalized_messages'] = _readInt(
      alarmSmoke['normalized_messages'],
    );
    manifest['last_video_live_available'] =
        (videoSmoke['live_primary_url'] ?? '').toString().trim().isNotEmpty;
    manifest['last_video_playback_records'] = _readInt(
      videoSmoke['playback_total_count'],
    );
    manifest['last_video_download_available'] =
        (videoSmoke['download_url'] ?? '').toString().trim().isNotEmpty;

    final encoded = const JsonEncoder.withIndent('  ').convert(manifest);
    await manifestFile.writeAsString('$encoded\n');
    return manifestFile.path;
  }

  Map<String, Object?> _readMap(Object? raw) {
    if (raw is Map<String, Object?>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, Object?>{};
  }

  int _readInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse((raw ?? '').toString().trim()) ?? 0;
  }

  void _writeStringField(
    Map<String, Object?> manifest,
    String key,
    String value,
  ) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      manifest.remove(key);
      return;
    }
    manifest[key] = trimmed;
  }
}
