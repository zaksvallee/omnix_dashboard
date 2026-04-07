import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/hik_connect_alarm_batch.dart';
import 'package:omnix_dashboard/application/hik_connect_alarm_smoke_service.dart';
import 'package:omnix_dashboard/application/hik_connect_bootstrap_orchestrator_service.dart';
import 'package:omnix_dashboard/application/hik_connect_camera_bootstrap_service.dart';
import 'package:omnix_dashboard/application/hik_connect_camera_catalog.dart';
import 'package:omnix_dashboard/application/hik_connect_preflight_report_service.dart';
import 'package:omnix_dashboard/application/hik_connect_video_session.dart';
import 'package:omnix_dashboard/application/hik_connect_video_smoke_service.dart';
import 'package:omnix_dashboard/domain/intelligence/intel_ingestion.dart';

void main() {
  test('builds a combined Hik-Connect preflight report', () {
    const reportService = HikConnectPreflightReportService();
    const bootstrap = HikConnectBootstrapRunResult(
      snapshot: HikConnectCameraBootstrapSnapshot(
        cameras: <HikConnectCameraResource>[
          HikConnectCameraResource(
            resourceId: 'camera-front',
            cameraName: 'Front Yard',
            displayName: 'Front Yard',
            deviceSerialNo: 'SERIAL-001',
            areaId: '',
            areaName: 'MS Vallee Residence',
          ),
        ],
        cameraLabelSeeds: <String, String>{'camera-front': 'Front Yard'},
        deviceSerials: <String>['SERIAL-001'],
        areaNames: <String>['MS Vallee Residence'],
      ),
      scopeConfigItem: <String, Object?>{},
      scopeConfigJson: '[]',
      pilotEnvBlock: '',
      operatorPacket: '',
      warnings: <String>[],
    );
    final alarm = HikConnectAlarmSmokeResult(
      batch: const HikConnectAlarmBatch(
        batchId: 'batch-001',
        messages: <HikConnectAlarmMessage>[
          HikConnectAlarmMessage(
            guid: 'hik-guid-1',
            systemId: '',
            msgType: '1',
            alarmState: '1',
            alarmSubCategory: '',
            timeInfo: HikConnectAlarmTimeInfo(
              startTime: '2026-03-30T00:10:00Z',
              startTimeLocal: '',
              endTime: '',
              endTimeLocal: '',
            ),
            eventSource: HikConnectAlarmSource(
              sourceId: 'camera-front',
              sourceName: 'Front Yard',
              areaName: 'MS Vallee Residence',
              eventType: '100657',
              deviceName: '',
            ),
            alarmRule: HikConnectAlarmRule(name: ''),
            anprInfo: HikConnectAnprInfo(licensePlate: 'CA123456'),
            fileInfo: HikConnectAlarmFileInfo(files: <HikConnectAlarmFile>[]),
          ),
        ],
      ),
      normalizedRecords: <NormalizedIntelRecord>[
        NormalizedIntelRecord(
          provider: 'hik_connect_openapi',
          sourceType: 'dvr',
          externalId: 'hik-guid-1',
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          cameraId: 'camera-front',
          zone: 'MS Vallee Residence',
          plateNumber: 'CA123456',
          headline: 'HIK_CONNECT_OPENAPI LPR_ALERT',
          summary: 'provider:hik_connect_openapi | area:MS Vallee Residence',
          riskScore: 84,
          occurredAtUtc: DateTime.utc(2026, 3, 30, 0, 10),
        ),
      ],
      droppedMessages: 0,
    );
    final video = HikConnectVideoSmokeResult(
      liveAddress: const HikConnectLiveAddressResponse(
        primaryUrl: 'wss://stream.example.com/live/token',
        urlsByKey: <String, String>{
          'url': 'wss://stream.example.com/live/token',
        },
        rawData: <String, Object?>{},
      ),
      playbackCatalog: const HikConnectRecordElementSearchResult(
        totalCount: 1,
        pageIndex: 1,
        pageSize: 50,
        records: <HikConnectRecordElement>[
          HikConnectRecordElement(
            recordId: 'record-001',
            beginTime: '2026-03-30T00:00:00Z',
            endTime: '2026-03-30T00:05:00Z',
            playbackUrl: 'https://stream.example.com/playback/record-001',
            raw: <String, Object?>{},
          ),
        ],
        rawData: <String, Object?>{},
      ),
      downloadResult: const HikConnectVideoDownloadResult(
        downloadUrl: 'https://stream.example.com/download/video.mp4',
        rawData: <String, Object?>{},
      ),
    );

    final report = reportService.buildReport(
      clientId: 'CLIENT-MS-VALLEE',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      bootstrap: bootstrap,
      alarm: alarm,
      video: video,
      bundleHealthNotes: const <String>[
        'Playback payload was present but did not expose any record windows.',
      ],
      payloadInventory: const <Map<String, Object?>>[
        <String, Object?>{
          'key': 'camera',
          'configured': true,
          'exists': true,
          'status': 'found',
          'path': '/tmp/camera-pages.json',
          'size_bytes': 128,
        },
        <String, Object?>{
          'key': 'alarm',
          'configured': true,
          'exists': false,
          'status': 'configured_missing',
          'path': '/tmp/alarm-messages.json',
          'size_bytes': 0,
        },
      ],
      rolloutArtifacts: const <Map<String, Object?>>[
        <String, Object?>{
          'key': 'scope_seed',
          'label': 'scope seed',
          'status': 'saved',
          'path': '/tmp/scope-seed.json',
        },
        <String, Object?>{
          'key': 'pilot_env',
          'label': 'pilot env',
          'status': 'saved',
          'path': '/tmp/pilot-env.sh',
        },
      ],
      nextSteps: const <String>[
        'Provide the alarm queue payload at /tmp/alarm-messages.json or update the bundle path.',
      ],
    );

    expect(report, contains('HIK-CONNECT PREFLIGHT REPORT'));
    expect(report, contains('Payload Inventory'));
    expect(
      report,
      contains('camera: found • 128 bytes • /tmp/camera-pages.json'),
    );
    expect(
      report,
      contains('alarm: configured but missing • /tmp/alarm-messages.json'),
    );
    expect(report, contains('Camera Bootstrap'));
    expect(report, contains('sample cameras: Front Yard'));
    expect(report, contains('Alarm Smoke'));
    expect(report, contains('HIK_CONNECT_OPENAPI LPR_ALERT'));
    expect(report, contains('Video Smoke'));
    expect(report, contains('Bundle Health'));
    expect(report, contains('Rollout Artifacts'));
    expect(report, contains('scope seed: /tmp/scope-seed.json'));
    expect(report, contains('pilot env: /tmp/pilot-env.sh'));
    expect(report, contains('Next Steps'));
    expect(
      report,
      contains(
        'Provide the alarm queue payload at /tmp/alarm-messages.json or update the bundle path.',
      ),
    );
    expect(report, contains('Rollout Readiness'));

    final jsonReport = reportService.buildJsonReport(
      clientId: 'CLIENT-MS-VALLEE',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      bootstrap: bootstrap,
      alarm: alarm,
      video: video,
      bundleHealthNotes: const <String>[
        'Playback payload was present but did not expose any record windows.',
      ],
      payloadInventory: const <Map<String, Object?>>[
        <String, Object?>{
          'key': 'camera',
          'configured': true,
          'exists': true,
          'status': 'found',
          'path': '/tmp/camera-pages.json',
          'size_bytes': 128,
        },
      ],
      rolloutArtifacts: const <Map<String, Object?>>[
        <String, Object?>{
          'key': 'bootstrap_packet',
          'label': 'bootstrap packet',
          'status': 'saved',
          'path': '/tmp/bootstrap-packet.md',
        },
      ],
      nextSteps: const <String>[
        'Bundle looks ready for the first Hik-Connect pilot run.',
      ],
    );

    expect(jsonReport['client_id'], 'CLIENT-MS-VALLEE');
    expect(
      (jsonReport['payload_inventory'] as List<Object?>).single,
      <String, Object?>{
        'key': 'camera',
        'configured': true,
        'exists': true,
        'status': 'found',
        'path': '/tmp/camera-pages.json',
        'size_bytes': 128,
      },
    );
    expect(
      (jsonReport['camera_bootstrap'] as Map<String, Object?>)['status'],
      'READY FOR PILOT',
    );
    expect(
      (jsonReport['camera_bootstrap']
          as Map<String, Object?>)['sample_cameras'],
      <String>['Front Yard'],
    );
    expect(
      (jsonReport['alarm_smoke']
          as Map<String, Object?>)['normalized_messages'],
      1,
    );
    expect(
      (jsonReport['video_smoke'] as Map<String, Object?>)['live_primary_url'],
      'wss://stream.example.com/live/token',
    );
    expect(
      jsonReport['bundle_health_notes'],
      contains(
        'Playback payload was present but did not expose any record windows.',
      ),
    );
    expect(jsonReport['rollout_artifacts'], <Map<String, Object?>>[
      <String, Object?>{
        'key': 'bootstrap_packet',
        'label': 'bootstrap packet',
        'status': 'saved',
        'path': '/tmp/bootstrap-packet.md',
      },
    ]);
    expect(
      jsonReport['next_steps'],
      contains('Bundle looks ready for the first Hik-Connect pilot run.'),
    );
    expect(jsonReport['rollout_readiness'], contains('camera bootstrap ready'));
  });
}
