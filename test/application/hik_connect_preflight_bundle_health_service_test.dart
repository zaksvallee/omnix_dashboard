import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/hik_connect_alarm_batch.dart';
import 'package:omnix_dashboard/application/hik_connect_alarm_smoke_service.dart';
import 'package:omnix_dashboard/application/hik_connect_bootstrap_orchestrator_service.dart';
import 'package:omnix_dashboard/application/hik_connect_camera_bootstrap_service.dart';
import 'package:omnix_dashboard/application/hik_connect_preflight_bundle_health_service.dart';
import 'package:omnix_dashboard/application/hik_connect_video_smoke_service.dart';

void main() {
  test('flags empty payload files that were still supplied', () {
    const service = HikConnectPreflightBundleHealthService();
    const bootstrap = HikConnectBootstrapRunResult(
      snapshot: HikConnectCameraBootstrapSnapshot(
        cameras: [],
        cameraLabelSeeds: <String, String>{},
        deviceSerials: <String>[],
        areaNames: <String>[],
      ),
      scopeConfigItem: <String, Object?>{},
      scopeConfigJson: '[]',
      pilotEnvBlock: '',
      operatorPacket: '',
      warnings: <String>[],
    );
    const alarm = HikConnectAlarmSmokeResult(
      batch: HikConnectAlarmBatch(
        batchId: '',
        messages: <HikConnectAlarmMessage>[],
      ),
      normalizedRecords: [],
      droppedMessages: 0,
    );
    const video = HikConnectVideoSmokeResult();

    final notes = service.buildNotes(
      cameraPayloadPath: '/tmp/camera-pages.json',
      alarmPayloadPath: '/tmp/alarm-messages.json',
      liveAddressPayloadPath: '/tmp/live-address.json',
      playbackPayloadPath: '/tmp/playback-search.json',
      videoDownloadPayloadPath: '/tmp/video-download.json',
      bootstrap: bootstrap,
      alarm: alarm,
      video: video,
    );

    expect(notes, contains('Camera payload was present but resolved to zero cameras.'));
    expect(notes, contains('Alarm payload was present but resolved to zero messages.'));
    expect(
      notes,
      contains(
        'Live-address payload was present but did not expose a usable stream URL.',
      ),
    );
    expect(
      notes,
      contains(
        'Playback payload was present but did not expose any record windows.',
      ),
    );
    expect(
      notes,
      contains(
        'Video-download payload was present but did not expose a download URL.',
      ),
    );
  });
}
