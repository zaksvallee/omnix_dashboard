import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/dvr_scope_config.dart';
import 'package:omnix_dashboard/application/monitoring_watch_continuous_visual_service.dart';
import 'package:omnix_dashboard/application/monitoring_yolo_semantic_probe_scheduler.dart';

void main() {
  group('MonitoringYoloSemanticProbeScheduler', () {
    test(
      'buildProbeRecords selects reachable camera snapshots and creates generic movement probes',
      () {
        final scheduler = MonitoringYoloSemanticProbeScheduler(
          cameraCooldown: const Duration(seconds: 24),
          maxCamerasPerSweep: 2,
        );
        final scope = DvrScopeConfig(
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          provider: 'hikvision_dvr_monitor_only',
          eventsUri: Uri.parse(
            'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
          ),
          authMode: 'digest',
          username: 'operator',
          password: 'secret',
          bearerToken: '',
        );
        final snapshot = MonitoringWatchContinuousVisualScopeSnapshot(
          scopeKey: scope.scopeKey,
          status: MonitoringWatchContinuousVisualStatus.active,
          cameras: <MonitoringWatchContinuousVisualCameraSnapshot>[
            MonitoringWatchContinuousVisualCameraSnapshot(
              cameraId: '11',
              cameraLabel: 'Front Gate',
              zoneLabel: 'Front Gate',
              areaLabel: 'Driveway',
              watchPriorityLabel: 'high',
              snapshotUri: Uri.parse(
                'http://127.0.0.1:11635/ISAPI/Streaming/channels/1101/picture',
              ),
              reachable: true,
              baselineReady: true,
              changeStage:
                  MonitoringWatchContinuousVisualChangeStage.persistent,
              changeStreakCount: 5,
            ),
            MonitoringWatchContinuousVisualCameraSnapshot(
              cameraId: '12',
              cameraLabel: 'Side Entrance',
              zoneLabel: 'Side Entrance',
              snapshotUri: Uri.parse(
                'http://127.0.0.1:11635/ISAPI/Streaming/channels/1201/picture',
              ),
              reachable: true,
              baselineReady: true,
              changeStage: MonitoringWatchContinuousVisualChangeStage.idle,
            ),
            MonitoringWatchContinuousVisualCameraSnapshot(
              cameraId: '13',
              cameraLabel: 'Back Garden',
              snapshotUri: Uri.parse(''),
              reachable: true,
              baselineReady: true,
            ),
          ],
        );

        final records = scheduler.buildProbeRecords(
          scope: scope,
          snapshot: snapshot,
          nowUtc: DateTime.utc(2026, 4, 4, 20, 35, 0),
        );

        expect(records, hasLength(2));
        expect(records.first.cameraId, '11');
        expect(records.first.objectLabel, 'movement');
        expect(records.first.headline, contains('Semantic watch probe'));
        expect(records.first.summary, contains('person, vehicle, or animal'));
        expect(records.first.snapshotUrl, contains('/1101/picture'));
        expect(records.last.cameraId, '12');
      },
    );

    test(
      'buildProbeRecords honors cooldown and rotates to cameras that have not been sampled recently',
      () {
        final scheduler = MonitoringYoloSemanticProbeScheduler(
          cameraCooldown: const Duration(seconds: 24),
          maxCamerasPerSweep: 2,
        );
        final scope = DvrScopeConfig(
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          provider: 'hikvision_dvr_monitor_only',
          eventsUri: Uri.parse(
            'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
          ),
          authMode: 'digest',
          username: 'operator',
          password: 'secret',
          bearerToken: '',
        );
        final snapshot = MonitoringWatchContinuousVisualScopeSnapshot(
          scopeKey: scope.scopeKey,
          status: MonitoringWatchContinuousVisualStatus.active,
          cameras: <MonitoringWatchContinuousVisualCameraSnapshot>[
            MonitoringWatchContinuousVisualCameraSnapshot(
              cameraId: '11',
              cameraLabel: 'Front Gate',
              snapshotUri: Uri.parse(
                'http://127.0.0.1:11635/ISAPI/Streaming/channels/1101/picture',
              ),
              reachable: true,
              baselineReady: true,
              changeStage: MonitoringWatchContinuousVisualChangeStage.sustained,
              changeStreakCount: 3,
            ),
            MonitoringWatchContinuousVisualCameraSnapshot(
              cameraId: '12',
              cameraLabel: 'Side Entrance',
              snapshotUri: Uri.parse(
                'http://127.0.0.1:11635/ISAPI/Streaming/channels/1201/picture',
              ),
              reachable: true,
              baselineReady: true,
            ),
            MonitoringWatchContinuousVisualCameraSnapshot(
              cameraId: '14',
              cameraLabel: 'Back Gate',
              snapshotUri: Uri.parse(
                'http://127.0.0.1:11635/ISAPI/Streaming/channels/1401/picture',
              ),
              reachable: true,
              baselineReady: true,
            ),
          ],
        );

        final firstBatch = scheduler.buildProbeRecords(
          scope: scope,
          snapshot: snapshot,
          nowUtc: DateTime.utc(2026, 4, 4, 20, 35, 0),
        );
        final secondBatch = scheduler.buildProbeRecords(
          scope: scope,
          snapshot: snapshot,
          nowUtc: DateTime.utc(2026, 4, 4, 20, 35, 12),
        );
        final thirdBatch = scheduler.buildProbeRecords(
          scope: scope,
          snapshot: snapshot,
          nowUtc: DateTime.utc(2026, 4, 4, 20, 35, 30),
        );

        expect(firstBatch.map((record) => record.cameraId), ['11', '12']);
        expect(secondBatch.map((record) => record.cameraId), ['14']);
        expect(thirdBatch.map((record) => record.cameraId), ['11', '12']);
      },
    );
  });
}
