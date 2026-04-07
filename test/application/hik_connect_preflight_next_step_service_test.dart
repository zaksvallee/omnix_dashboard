import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/hik_connect_alarm_batch.dart';
import 'package:omnix_dashboard/application/hik_connect_alarm_smoke_service.dart';
import 'package:omnix_dashboard/application/hik_connect_bootstrap_orchestrator_service.dart';
import 'package:omnix_dashboard/application/hik_connect_camera_bootstrap_service.dart';
import 'package:omnix_dashboard/application/hik_connect_camera_catalog.dart';
import 'package:omnix_dashboard/application/hik_connect_preflight_next_step_service.dart';
import 'package:omnix_dashboard/application/hik_connect_video_session.dart';
import 'package:omnix_dashboard/application/hik_connect_video_smoke_service.dart';
import 'package:omnix_dashboard/domain/intelligence/intel_ingestion.dart';

void main() {
  test('builds concrete next steps for incomplete bundles', () {
    const service = HikConnectPreflightNextStepService();

    final steps = service.buildSteps(
      payloadInventory: const <Map<String, Object?>>[
        <String, Object?>{
          'key': 'camera',
          'status': 'configured_missing',
          'path': '/tmp/camera-pages.json',
        },
        <String, Object?>{
          'key': 'alarm',
          'status': 'unset',
          'path': '',
        },
      ],
      bootstrap: const HikConnectBootstrapRunResult(
        snapshot: HikConnectCameraBootstrapSnapshot(
          cameras: <HikConnectCameraResource>[],
          cameraLabelSeeds: <String, String>{},
          deviceSerials: <String>['SERIAL-1', 'SERIAL-2'],
          areaNames: <String>[],
        ),
        scopeConfigItem: <String, Object?>{},
        scopeConfigJson: '[]',
        pilotEnvBlock: '',
        operatorPacket: '',
        warnings: <String>['No area names were discovered from Hik-Connect.'],
      ),
      alarm: const HikConnectAlarmSmokeResult(
        batch: HikConnectAlarmBatch(batchId: 'batch-001', messages: <HikConnectAlarmMessage>[]),
        normalizedRecords: <NormalizedIntelRecord>[],
        droppedMessages: 1,
      ),
      video: const HikConnectVideoSmokeResult(
        liveAddress: HikConnectLiveAddressResponse(
          primaryUrl: '',
          urlsByKey: <String, String>{},
          rawData: <String, Object?>{},
        ),
        playbackCatalog: HikConnectRecordElementSearchResult(
          totalCount: 0,
          pageIndex: 1,
          pageSize: 50,
          records: <HikConnectRecordElement>[],
          rawData: <String, Object?>{},
        ),
        downloadResult: HikConnectVideoDownloadResult(
          downloadUrl: '',
          rawData: <String, Object?>{},
        ),
      ),
    );

    expect(
      steps,
      contains(
        'Provide the camera inventory payload at /tmp/camera-pages.json or update the bundle path.',
      ),
    );
    expect(
      steps,
      contains(
        'Capture or export a Hik-Connect alarm queue payload from mq/messages.',
      ),
    );
    expect(
      steps,
      contains(
        'Choose the preferred Hik-Connect device serial for the first pilot scope seed.',
      ),
    );
    expect(
      steps,
      contains(
        'Review camera bootstrap warning: No area names were discovered from Hik-Connect.',
      ),
    );
    expect(
      steps,
      contains(
        'Capture a live-address response with a usable stream URL for a representative camera.',
      ),
    );
  });

  test('returns ready step when nothing is missing', () {
    const service = HikConnectPreflightNextStepService();

    final steps = service.buildSteps(
      payloadInventory: const <Map<String, Object?>>[
        <String, Object?>{
          'key': 'camera',
          'status': 'found',
          'path': '/tmp/camera-pages.json',
        },
      ],
      bootstrap: const HikConnectBootstrapRunResult(
        snapshot: HikConnectCameraBootstrapSnapshot(
          cameras: <HikConnectCameraResource>[],
          cameraLabelSeeds: <String, String>{},
          deviceSerials: <String>['SERIAL-1'],
          areaNames: <String>['Area A'],
        ),
        scopeConfigItem: <String, Object?>{},
        scopeConfigJson: '[]',
        pilotEnvBlock: '',
        operatorPacket: '',
        warnings: <String>[],
      ),
    );

    expect(
      steps,
      contains('Bundle looks ready for the first Hik-Connect pilot run.'),
    );
  });
}
