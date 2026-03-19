import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/dvr_scope_config.dart';
import 'package:omnix_dashboard/application/monitoring_shift_schedule_service.dart';
import 'package:omnix_dashboard/application/monitoring_watch_outcome_cue_store.dart';
import 'package:omnix_dashboard/application/monitoring_watch_recovery_policy.dart';
import 'package:omnix_dashboard/application/monitoring_watch_recovery_store.dart';
import 'package:omnix_dashboard/application/monitoring_watch_runtime_store.dart';
import 'package:omnix_dashboard/application/video_fleet_scope_presentation_service.dart';
import 'package:omnix_dashboard/application/video_fleet_scope_runtime_state_resolver.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  group('VideoFleetScopePresentationService', () {
    const service = VideoFleetScopePresentationService(
      runtimeStateResolver: VideoFleetScopeRuntimeStateResolver(
        outcomeCueStore: MonitoringWatchOutcomeCueStore(),
        recoveryStore: MonitoringWatchRecoveryStore(
          policy: MonitoringWatchRecoveryPolicy(),
        ),
      ),
    );
    const schedule = MonitoringShiftSchedule(
      enabled: true,
      startHour: 18,
      startMinute: 0,
      endHour: 6,
      endMinute: 0,
    );

    test('formats summary and projects health with resolved runtime labels', () {
      final scopes = [
        _scope(clientId: 'CLIENT-A', siteId: 'SITE-A', host: '192.168.8.105'),
        _scope(clientId: 'CLIENT-B', siteId: 'SITE-B', host: '192.168.8.106'),
      ];
      final events = [
        _intel(
          clientId: 'CLIENT-A',
          siteId: 'SITE-A',
          occurredAt: DateTime.utc(2026, 3, 14, 11, 55),
          cameraId: 'channel-2',
          headline: 'Vehicle motion',
          riskScore: 72,
        ),
      ];
      final nowUtc = DateTime.utc(2026, 3, 14, 12, 0);

      final summary = service.formatSummary(
        scopes: scopes,
        events: events,
        nowUtc: nowUtc,
        siteNameForScope: (clientId, siteId) => '$clientId/$siteId',
        endpointLabelForScope: (uri) => uri?.host ?? '',
        maxScopes: 2,
      );
      final health = service.projectHealth(
        scopes: scopes,
        events: events,
        nowUtc: nowUtc,
        activeWatchScopeKeys: const {'CLIENT-A|SITE-A'},
        scheduleForScope: (clientId, siteId) => schedule,
        siteNameForScope: (clientId, siteId) => '$clientId/$siteId',
        endpointLabelForScope: (uri) => uri?.host ?? '',
        cameraLabelForId: (cameraId) => 'Camera ${cameraId?.split('-').last}',
        outcomeCueStateByScope: {
          'CLIENT-B|SITE-B': MonitoringWatchOutcomeCueState(
            label: 'Resynced',
            recordedAtUtc: DateTime.utc(2026, 3, 14, 11, 58),
          ),
        },
        recoveryStateByScope: {
          'CLIENT-B|SITE-B': MonitoringWatchRecoveryState(
            actor: 'ADMIN',
            outcome: 'Already aligned',
            recordedAtUtc: DateTime.utc(2026, 3, 14, 11, 30),
          ),
        },
        watchRuntimeByScope: {
          'CLIENT-A|SITE-A': MonitoringWatchRuntimeState(
            startedAtUtc: DateTime.utc(2026, 3, 14, 11, 0),
            alertCount: 1,
            repeatCount: 1,
            escalationCount: 0,
            suppressedCount: 3,
            actionHistory: const [
              '11:55 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
              '11:49 UTC • Camera 1 • Repeat Activity • Repeat activity update sent because vehicle activity repeated.',
            ],
            suppressedHistory: const [
              '11:54 UTC • Camera 2 • Suppressed because the activity remained below the client notification threshold.',
              '11:48 UTC • Camera 1 • Suppressed because motion remained low-significance.',
            ],
            latestSceneReviewSourceLabel: 'openai:gpt-4.1-mini',
            latestSceneReviewPostureLabel: 'monitored movement alert',
            latestSceneDecisionLabel: 'Monitoring Alert',
            latestSceneDecisionSummary:
                'Client alert sent because vehicle activity was detected and confidence remained medium.',
            latestSceneReviewSummary:
                'Vehicle remains visible in the monitored approach lane.',
            latestSceneReviewUpdatedAtUtc: DateTime.utc(2026, 3, 14, 11, 55),
          ),
        },
      );

      expect(
        summary,
        'fleet 2 scope(s) • CLIENT-A/SITE-A 1/6h @ 192.168.8.105 • last 11:55 • CLIENT-B/SITE-B 0/6h @ 192.168.8.106 • last idle',
      );
      final quietScope = health.firstWhere((entry) => entry.siteId == 'SITE-B');
      expect(quietScope.operatorOutcomeLabel, 'Resynced');
      expect(
        quietScope.lastRecoveryLabel,
        'ADMIN • Already aligned • 11:30 UTC',
      );
      expect(quietScope.watchActivationGapLabel, isNull);
      expect(quietScope.watchWindowStateLabel, 'NEXT 18:00');
      final activeScope = health.firstWhere((entry) => entry.siteId == 'SITE-A');
      expect(
        activeScope.sceneDecisionText,
        'Scene action: Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
      );
      expect(
        activeScope.noteText,
        'Suppressed in watch: 3 reviews filtered.\nAction mix in watch: Alert 1 • Repeat 1 • Suppressed 3.\nLatest filtered: 11:54 UTC • Camera 2 • Suppressed because the activity remained below the client notification threshold. (+1 more)\nScene action: Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.\nScene review: openai:gpt-4.1-mini • monitored movement alert • 11:55 UTC • Vehicle remains visible in the monitored approach lane.',
      );
    });
  });
}

DvrScopeConfig _scope({
  required String clientId,
  required String siteId,
  required String host,
}) {
  return DvrScopeConfig(
    clientId: clientId,
    regionId: 'REGION-GAUTENG',
    siteId: siteId,
    provider: 'hikvision_dvr_monitor_only',
    eventsUri: Uri.parse('http://$host/ISAPI/Event/notification/alertStream'),
    authMode: 'digest',
    username: 'onyx',
    password: 'secret',
    bearerToken: '',
  );
}

IntelligenceReceived _intel({
  required String clientId,
  required String siteId,
  required DateTime occurredAt,
  required String headline,
  required int riskScore,
  String? cameraId,
}) {
  return IntelligenceReceived(
    eventId: 'evt-$clientId-$siteId-${occurredAt.microsecondsSinceEpoch}',
    sequence: 1,
    version: 1,
    occurredAt: occurredAt,
    intelligenceId:
        'intel-$clientId-$siteId-${occurredAt.microsecondsSinceEpoch}',
    provider: 'hikvision_dvr_monitor_only',
    sourceType: 'dvr',
    externalId: 'external-${occurredAt.microsecondsSinceEpoch}',
    clientId: clientId,
    regionId: 'REGION-GAUTENG',
    siteId: siteId,
    cameraId: cameraId,
    zone: null,
    objectLabel: 'vehicle',
    objectConfidence: 0.91,
    headline: headline,
    summary: headline,
    riskScore: riskScore,
    snapshotUrl: null,
    clipUrl: null,
    canonicalHash: 'hash-${occurredAt.microsecondsSinceEpoch}',
    snapshotReferenceHash: null,
    clipReferenceHash: null,
    evidenceRecordHash: null,
  );
}
