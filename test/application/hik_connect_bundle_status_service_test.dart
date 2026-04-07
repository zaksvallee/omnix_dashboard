import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/hik_connect_bundle_status_service.dart';
import 'package:omnix_dashboard/application/hik_connect_payload_bundle_locator.dart';

void main() {
  test('loads a bundle manifest and formats the last preflight summary', () async {
    final directory = Directory.systemTemp.createTempSync(
      'hik-connect-bundle-status-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));

    final cameraPath =
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultCameraFileName}';
    final alarmPath =
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultAlarmFileName}';
    final manifestPath =
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultManifestFileName}';
    final scopeSeedPath = '${directory.path}/scope-seed.json';
    final pilotEnvPath = '${directory.path}/pilot-env.sh';
    final bootstrapPacketPath = '${directory.path}/bootstrap-packet.md';
    await File(cameraPath).writeAsString('{"pages": []}\n');
    await File(alarmPath).writeAsString('{"data": {"alarmMsg": []}}\n');
    await File(scopeSeedPath).writeAsString('[]\n');
    await File(pilotEnvPath).writeAsString("export ONYX_DVR_PROVIDER='hik_connect_openapi'\n");
    await File(bootstrapPacketPath).writeAsString(
      'HIK-CONNECT BOOTSTRAP PACKET\n',
    );
    final fileModifiedAtUtc = DateTime.utc(2026, 3, 30, 3, 0, 0);
    await File(cameraPath).setLastModified(fileModifiedAtUtc);
    await File(alarmPath).setLastModified(fileModifiedAtUtc);
    await File(scopeSeedPath).setLastModified(fileModifiedAtUtc);
    await File(pilotEnvPath).setLastModified(fileModifiedAtUtc);
    await File(bootstrapPacketPath).setLastModified(fileModifiedAtUtc);
    await File(manifestPath).writeAsString(
      '''
      {
        "client_id": "CLIENT-MS-VALLEE",
        "region_id": "REGION-GAUTENG",
        "site_id": "SITE-MS-VALLEE-RESIDENCE",
        "area_id": "AREA-001",
        "include_sub_area": false,
        "device_serial_no": "SERIAL-FILTER",
        "representative_camera_id": "camera-front",
        "representative_device_serial_no": "SERIAL-001",
        "alarm_event_types": [100657, 42],
        "camera_labels": {
          "camera-front": "Front Gate",
          "camera-back": "Back Gate"
        },
        "page_size": 125,
        "max_pages": 7,
        "playback_lookback_minutes": 90,
        "playback_window_minutes": 12,
        "camera_payload_path": "camera-pages.json",
        "alarm_payload_path": "alarm-messages.json",
        "scope_seed_path": "scope-seed.json",
        "pilot_env_path": "pilot-env.sh",
        "bootstrap_packet_path": "bootstrap-packet.md",
        "last_preflight_at_utc": "2026-03-30T02:10:00.000Z",
        "last_rollout_readiness": "camera bootstrap ready | alarm normalization verified | video payloads verified",
        "last_collection_at_utc": "2026-03-30T00:30:00.000Z",
        "last_collection_camera_count": 8,
        "last_collection_alarm_message_count": 5,
        "last_collection_representative_camera_id": "camera-front",
        "last_collection_representative_device_serial_no": "SERIAL-001",
        "last_collection_warnings": [
          "Playback search returned no record windows for the representative camera."
        ],
        "last_report_path": "/tmp/preflight-report.md",
        "last_report_json_path": "/tmp/preflight-report.json",
        "last_scope_seed_path": "$scopeSeedPath",
        "last_pilot_env_path": "$pilotEnvPath",
        "last_bootstrap_packet_path": "$bootstrapPacketPath",
        "last_camera_count": 8,
        "last_alarm_total_messages": 5,
        "last_alarm_normalized_messages": 4,
        "last_video_live_available": true,
        "last_video_playback_records": 2,
        "last_video_download_available": true
      }
      ''',
    );

    const service = HikConnectBundleStatusService();
    final result = await service.load(
      bundleDirectoryPath: directory.path,
      maxAllowedAgeHours: 1,
      nowUtc: DateTime.utc(2026, 3, 30, 4, 10, 0),
    );

    expect(result.clientId, 'CLIENT-MS-VALLEE');
    expect(result.lastPreflightAtUtc, '2026-03-30T02:10:00.000Z');
    expect(result.areaId, 'AREA-001');
    expect(result.includeSubArea, isFalse);
    expect(result.deviceSerialNo, 'SERIAL-FILTER');
    expect(result.representativeCameraId, 'camera-front');
    expect(result.representativeDeviceSerialNo, 'SERIAL-001');
    expect(result.alarmEventTypes, <int>[100657, 42]);
    expect(result.cameraLabelsCount, 2);
    expect(result.pageSize, 125);
    expect(result.maxPages, 7);
    expect(result.playbackLookbackMinutes, 90);
    expect(result.playbackWindowMinutes, 12);
    expect(result.lastCollectionAtUtc, '2026-03-30T00:30:00.000Z');
    expect(result.lastCollectionAgeHours, 3);
    expect(result.collectionStale, isTrue);
    expect(result.lastCollectionCameraCount, 8);
    expect(result.lastCollectionAlarmMessageCount, 5);
    expect(result.lastCollectionRepresentativeCameraId, 'camera-front');
    expect(result.lastCollectionRepresentativeDeviceSerialNo, 'SERIAL-001');
    expect(
      result.lastCollectionWarnings,
      <String>[
        'Playback search returned no record windows for the representative camera.',
      ],
    );
    expect(result.cameraCount, 8);
    expect(result.alarmNormalizedMessages, 4);
    expect(result.videoLiveAvailable, isTrue);
    expect(result.preflightAgeHours, 2);
    expect(result.stale, isTrue);
    expect(result.payloadFiles, hasLength(2));
    expect(result.artifactFiles, hasLength(5));
    expect(result.payloadFiles.first.summaryLine, contains('camera: found'));
    expect(
      result.payloadFiles.first.summaryLine,
      contains('updated 2026-03-30T03:00:00.000Z'),
    );
    expect(result.payloadFiles.first.summaryLine, contains('1h old'));
    expect(result.payloadFiles.first.summaryLine, contains(cameraPath));
    expect(
      result.artifactFiles.singleWhere((entry) => entry.label == 'scope seed').summaryLine,
      contains('scope-seed.json'),
    );
    expect(
      result.toJson(),
      containsPair('has_last_preflight_summary', true),
    );
    expect(
      result.toJson(),
      containsPair('bundle_health_label', 'STALE'),
    );
    expect(
      result.toJson(),
      containsPair('collection_stale', true),
    );
    expect(
      result.toJson(),
      containsPair('strict_ready', false),
    );
    expect(
      result.toJson(),
      containsPair('preflight_age_hours', 2),
    );
    expect(
      result.toJson(),
      containsPair('stale', true),
    );
    expect(
      result.toJson(),
      containsPair('camera_count', 8),
    );
    expect(
      result.toJson(),
      containsPair(
        'scope_settings',
        <String, Object?>{
          'area_id': 'AREA-001',
          'include_sub_area': false,
          'device_serial_no': 'SERIAL-FILTER',
          'representative_camera_id': 'camera-front',
          'representative_device_serial_no': 'SERIAL-001',
          'alarm_event_types': <int>[100657, 42],
          'camera_labels_count': 2,
          'page_size': 125,
          'max_pages': 7,
          'playback_lookback_minutes': 90,
          'playback_window_minutes': 12,
        },
      ),
    );
    expect(
      result.toJson(),
      containsPair(
        'last_collection',
        <String, Object?>{
          'recorded_at_utc': '2026-03-30T00:30:00.000Z',
          'age_hours': 3,
          'stale': true,
          'camera_count': 8,
          'alarm_message_count': 5,
          'representative_camera_id': 'camera-front',
          'representative_device_serial_no': 'SERIAL-001',
          'warnings': <String>[
            'Playback search returned no record windows for the representative camera.',
          ],
        },
      ),
    );
    expect(
      result.toJson(),
      containsPair('video_live_available', true),
    );
    expect(
      (result.toJson()['payload_files'] as List<Object?>).length,
      2,
    );
    expect(
      (result.toJson()['payload_files'] as List<Object?>).first,
      containsPair('modified_at_utc', '2026-03-30T03:00:00.000Z'),
    );
    expect(
      (result.toJson()['payload_files'] as List<Object?>).first,
      containsPair('age_hours', 1),
    );
    expect(
      (result.toJson()['artifact_files'] as List<Object?>).length,
      5,
    );
    expect(
      result.warnings,
      contains('Last preflight summary is stale at 2h old (limit 1h).'),
    );
    expect(
      result.warnings,
      contains('Last collection snapshot is stale at 3h old (limit 1h).'),
    );
    expect(
      result.warnings,
      contains('2 artifact files are missing.'),
    );
    expect(
      result.nextSteps,
      contains(
        'Rerun bundle preflight because the saved readiness snapshot is older than the allowed max age.',
      ),
    );
    expect(
      result.nextSteps,
      contains(
        'Recollect the bundle payloads because the saved collection snapshot is older than the allowed max age.',
      ),
    );
    expect(
      result.nextSteps,
      contains(
        'Rerun bundle preflight so the missing report or rollout artifact files are regenerated.',
      ),
    );
    expect(
      result.toJson(),
      containsPair(
        'next_steps',
        contains(
          'Rerun bundle preflight so the missing report or rollout artifact files are regenerated.',
        ),
      ),
    );

    final summary = result.buildSummary();
    expect(summary, contains('HIK-CONNECT BUNDLE STATUS'));
    expect(summary, contains('Bundle Health'));
    expect(summary, contains('status: STALE'));
    expect(summary, contains('warning: Last preflight summary is stale at 2h old (limit 1h).'));
    expect(summary, contains('warning: Last collection snapshot is stale at 3h old (limit 1h).'));
    expect(summary, contains('warning: 2 artifact files are missing.'));
    expect(summary, contains('Scope Settings'));
    expect(summary, contains('area: AREA-001 • include sub-area no'));
    expect(summary, contains('device serial filter: SERIAL-FILTER'));
    expect(summary, contains('representative camera: camera-front'));
    expect(summary, contains('representative serial: SERIAL-001'));
    expect(summary, contains('alarm event types: 100657, 42'));
    expect(summary, contains('camera labels: 2'));
    expect(
      summary,
      contains('collection: page size 125 • max pages 7 • playback lookback 90m • playback window 12m'),
    );
    expect(summary, contains('Last Collection'));
    expect(summary, contains('recorded at: 2026-03-30T00:30:00.000Z'));
    expect(summary, contains('age: 3h (limit 1h)'));
    expect(summary, contains('cameras: 8 • alarm messages: 5'));
    expect(
      summary,
      contains('collection warning: Playback search returned no record windows for the representative camera.'),
    );
    expect(
      summary,
      contains('CLIENT-MS-VALLEE / SITE-MS-VALLEE-RESIDENCE / REGION-GAUTENG'),
    );
    expect(summary, contains('Payload Files'));
    expect(summary, contains('camera: found'));
    expect(summary, contains('updated 2026-03-30T03:00:00.000Z'));
    expect(summary, contains('1h old'));
    expect(summary, contains('alarm: found'));
    expect(summary, contains('Artifact Files'));
    expect(summary, contains('scope seed: found'));
    expect(summary, contains('Next'));
    expect(summary, contains('age: 2h (limit 1h)'));
    expect(
      summary,
      contains(
        'Rerun bundle preflight because the saved readiness snapshot is older than the allowed max age.',
      ),
    );
    expect(
      summary,
      contains(
        'Recollect the bundle payloads because the saved collection snapshot is older than the allowed max age.',
      ),
    );
    expect(
      summary,
      contains(
        'Rerun bundle preflight so the missing report or rollout artifact files are regenerated.',
      ),
    );
    expect(summary, contains('recorded at: 2026-03-30T02:10:00.000Z'));
    expect(summary, contains('camera bootstrap: 8 cameras'));
    expect(summary, contains('alarms: 4/5 normalized'));
    expect(summary, contains('video: live yes'));
    expect(summary, contains('scope seed: $scopeSeedPath'));
    expect(summary, contains('bootstrap packet: $bootstrapPacketPath'));
  });

  test('formats a next-step prompt when no preflight summary exists yet', () async {
    final directory = Directory.systemTemp.createTempSync(
      'hik-connect-bundle-status-empty-',
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

    const service = HikConnectBundleStatusService();
    final result = await service.load(bundleDirectoryPath: directory.path);

    expect(result.hasLastPreflightSummary, isFalse);
    expect(result.strictReady, isFalse);
    expect(
      result.toJson(),
      containsPair('has_last_preflight_summary', false),
    );
    expect(
      result.toJson(),
      containsPair('bundle_health_label', 'PENDING'),
    );
    expect(
      result.toJson(),
      containsPair('strict_ready', false),
    );
    expect(
      result.warnings,
      contains('No preflight summary is recorded in this bundle yet.'),
    );
    expect(
      result.nextSteps,
      contains(
        'Run ONYX_DVR_PREFLIGHT_DIR="${directory.path}" dart run tool/hik_connect_preflight.dart to record the first bundle summary.',
      ),
    );
    expect(
      result.buildSummary(),
      contains('No preflight summary is recorded in this bundle yet.'),
    );
    expect(result.artifactFiles, hasLength(5));
    expect(
      result.buildSummary(),
      contains('Artifact Files'),
    );
    expect(
      result.buildSummary(),
      contains('status: PENDING'),
    );
    expect(
      result.buildSummary(),
      contains('report: missing'),
    );
    expect(
      result.buildSummary(),
      contains('Run ONYX_DVR_PREFLIGHT_DIR="${directory.path}" dart run tool/hik_connect_preflight.dart to record the first bundle summary.'),
    );
    expect(
      result.buildSummary(),
      contains('dart run tool/hik_connect_preflight.dart'),
    );
  });
}
