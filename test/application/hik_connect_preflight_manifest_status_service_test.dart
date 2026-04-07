import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/hik_connect_payload_bundle_locator.dart';
import 'package:omnix_dashboard/application/hik_connect_preflight_manifest_status_service.dart';
import 'package:omnix_dashboard/application/hik_connect_preflight_runner_service.dart';

void main() {
  test('updates the bundle manifest with last preflight summary and artifact paths', () async {
    final directory = Directory.systemTemp.createTempSync(
      'hik-connect-manifest-status-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));

    final manifestPath =
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultManifestFileName}';
    await File(manifestPath).writeAsString(
      '''
      {
        "client_id": "CLIENT-MS-VALLEE",
        "region_id": "REGION-GAUTENG",
        "site_id": "SITE-MS-VALLEE-RESIDENCE"
      }
      ''',
    );

    const service = HikConnectPreflightManifestStatusService();
    final updatedPath = await service.updateBundleManifest(
      bundleDirectoryPath: directory.path,
      recordedAtUtc: DateTime.utc(2026, 3, 30, 1, 45, 0),
      result: const HikConnectPreflightRunResult(
        report: 'HIK-CONNECT PREFLIGHT REPORT',
        jsonReport: <String, Object?>{
          'rollout_readiness':
              'camera bootstrap ready | alarm normalization verified | video payloads verified',
          'camera_bootstrap': <String, Object?>{
            'ready_for_pilot': true,
            'camera_count': 8,
          },
          'alarm_smoke': <String, Object?>{
            'total_messages': 5,
            'normalized_messages': 4,
          },
          'video_smoke': <String, Object?>{
            'live_primary_url': 'wss://stream.example.com/live/token',
            'playback_total_count': 2,
            'download_url': 'https://stream.example.com/download/video.mp4',
          },
        },
        reportOutputPath: '/tmp/preflight-report.md',
        reportJsonOutputPath: '/tmp/preflight-report.json',
        scopeSeedOutputPath: '/tmp/scope-seed.json',
        pilotEnvOutputPath: '/tmp/pilot-env.sh',
        bootstrapPacketOutputPath: '/tmp/bootstrap-packet.md',
      ),
    );

    expect(updatedPath, manifestPath);

    final manifestJson = jsonDecode(
      File(manifestPath).readAsStringSync(),
    ) as Map<String, Object?>;
    expect(manifestJson['last_preflight_at_utc'], '2026-03-30T01:45:00.000Z');
    expect(
      manifestJson['last_rollout_readiness'],
      'camera bootstrap ready | alarm normalization verified | video payloads verified',
    );
    expect(manifestJson['last_report_path'], '/tmp/preflight-report.md');
    expect(
      manifestJson['last_report_json_path'],
      '/tmp/preflight-report.json',
    );
    expect(manifestJson['last_scope_seed_path'], '/tmp/scope-seed.json');
    expect(manifestJson['last_pilot_env_path'], '/tmp/pilot-env.sh');
    expect(
      manifestJson['last_bootstrap_packet_path'],
      '/tmp/bootstrap-packet.md',
    );
    expect(manifestJson['last_camera_ready_for_pilot'], isTrue);
    expect(manifestJson['last_camera_count'], 8);
    expect(manifestJson['last_alarm_total_messages'], 5);
    expect(manifestJson['last_alarm_normalized_messages'], 4);
    expect(manifestJson['last_video_live_available'], isTrue);
    expect(manifestJson['last_video_playback_records'], 2);
    expect(manifestJson['last_video_download_available'], isTrue);
  });
}
