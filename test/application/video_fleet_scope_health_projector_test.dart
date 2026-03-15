import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/dvr_scope_config.dart';
import 'package:omnix_dashboard/application/monitoring_shift_schedule_service.dart';
import 'package:omnix_dashboard/application/video_fleet_scope_health_projector.dart';
import 'package:omnix_dashboard/application/video_fleet_scope_runtime_state.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  group('VideoFleetScopeHealthProjector', () {
    const projector = VideoFleetScopeHealthProjector();
    const activeSchedule = MonitoringShiftSchedule(
      enabled: true,
      startHour: 18,
      startMinute: 0,
      endHour: 6,
      endMinute: 0,
    );
    const disabledSchedule = MonitoringShiftSchedule(
      enabled: false,
      startHour: 18,
      startMinute: 0,
      endHour: 6,
      endMinute: 0,
    );

    test('projects latest event context and freshness per scope', () {
      final output = projector.project(
        scopes: [
          _scope(clientId: 'CLIENT-A', siteId: 'SITE-A', host: '192.168.8.105'),
          _scope(clientId: 'CLIENT-B', siteId: 'SITE-B', host: '192.168.8.106'),
        ],
        events: [
          _intel(
            clientId: 'CLIENT-A',
            siteId: 'SITE-A',
            occurredAt: DateTime.utc(2026, 3, 13, 21, 10),
            cameraId: 'channel-1',
            headline: 'Vehicle motion',
            riskScore: 72,
          ),
          _intel(
            clientId: 'CLIENT-A',
            siteId: 'SITE-A',
            occurredAt: DateTime.utc(2026, 3, 13, 21, 45),
            cameraId: 'channel-3',
            headline: 'Repeat vehicle motion',
            riskScore: 84,
            faceMatchId: 'PERSON-44',
            faceConfidence: 91.2,
            plateNumber: 'CA123456',
            plateConfidence: 96.4,
          ),
          _intel(
            clientId: 'CLIENT-B',
            siteId: 'SITE-B',
            occurredAt: DateTime.utc(2026, 3, 13, 20, 10),
            cameraId: 'channel-2',
            headline: 'Perimeter motion',
            riskScore: 32,
          ),
        ],
        nowUtc: DateTime.utc(2026, 3, 13, 22, 0),
        activeWatchScopeKeys: {'CLIENT-A|SITE-A'},
        scheduleForScope: (clientId, siteId) => activeSchedule,
        siteNameForScope: (clientId, siteId) => '$clientId/$siteId',
        endpointLabelForScope: (uri) => uri?.host ?? '',
        cameraLabelForId: (cameraId) => cameraId == null
            ? 'Camera 1'
            : 'Camera ${cameraId.split('-').last}',
        runtimeStateByScope: const {
          'CLIENT-B|SITE-B': VideoFleetScopeRuntimeState(
            operatorOutcomeLabel: 'Resynced',
            lastRecoveryLabel: 'Already aligned • 21:40 UTC',
            latestClientDecisionLabel: 'Client Approved',
            latestClientDecisionSummary:
                'Client confirmed the unidentified person was expected.',
            latestClientDecisionAtUtc: DateTime.utc(2026, 3, 13, 21, 46),
            alertCount: 1,
            repeatCount: 2,
            escalationCount: 1,
            suppressedCount: 2,
            actionHistory: [
              '21:44 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
              '21:38 UTC • Camera 1 • Repeat Activity • Repeat activity update sent because vehicle activity repeated.',
            ],
            suppressedHistory: [
              '21:42 UTC • Camera 2 • Suppressed because the activity remained below the client notification threshold.',
              '21:31 UTC • Camera 2 • Suppressed because motion remained low-significance.',
            ],
            latestSceneReviewLabel:
                'openai:gpt-4.1-mini • monitored movement alert • 21:44 UTC',
            latestSceneDecisionLabel: 'Monitoring Alert',
            latestSceneDecisionSummary:
                'Client alert sent because vehicle activity was detected and confidence remained medium.',
            latestSceneReviewSummary:
                'Vehicle remains visible in the perimeter approach lane.',
          ),
        },
      );

      expect(output, hasLength(2));
      final clientA = output.firstWhere(
        (entry) => entry.clientId == 'CLIENT-A',
      );
      final clientB = output.firstWhere(
        (entry) => entry.clientId == 'CLIENT-B',
      );

      expect(clientA.statusLabel, 'LIVE');
      expect(clientA.watchLabel, 'ACTIVE');
      expect(clientA.recentEvents, 2);
      expect(clientA.latestEventLabel, 'Repeat vehicle motion');
      expect(clientA.latestIncidentReference, isNotEmpty);
      expect(clientA.latestCameraLabel, 'Camera 3');
      expect(clientA.latestRiskScore, 84);
      expect(clientA.latestFaceMatchId, 'PERSON-44');
      expect(clientA.latestPlateNumber, 'CA123456');
      expect(
        clientA.identityMatchText,
        'Identity match: Face PERSON-44 91.2% • Plate CA123456 96.4%',
      );
      expect(clientA.freshnessLabel, 'Fresh');
      expect(clientA.isStale, isFalse);
      expect(clientA.endpointLabel, '192.168.8.105');
      expect(clientA.watchWindowLabel, '18:00-06:00');
      expect(clientA.watchWindowStateLabel, 'IN WINDOW');
      expect(clientA.watchActivationGapLabel, isNull);

      expect(clientB.statusLabel, 'WATCH READY');
      expect(clientB.watchLabel, 'SCHEDULED');
      expect(clientB.freshnessLabel, 'Idle');
      expect(clientB.latestCameraLabel, 'Camera 2');
      expect(clientB.watchWindowLabel, '18:00-06:00');
      expect(clientB.watchWindowStateLabel, 'IN WINDOW');
      expect(clientB.watchActivationGapLabel, 'MISSED START');
      expect(clientB.operatorOutcomeLabel, 'Resynced');
      expect(clientB.lastRecoveryLabel, 'Already aligned • 21:40 UTC');
      expect(clientB.suppressedCount, 2);
      expect(
        clientB.watchActionMixText,
        'Action mix in watch: Alert 1 • Repeat 2 • Escalated 1 • Suppressed 2.',
      );
      expect(
        clientB.sceneDecisionText,
        'Scene action: Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
      );
      expect(clientB.clientDecisionChipValue, 'Approved');
      expect(
        clientB.clientDecisionText,
        'Client decision: 21:46 UTC • Client Approved • Client confirmed the unidentified person was expected.',
      );
      expect(
        clientB.prominentLatestText,
        'Recent action: 21:44 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium. (+1 more)',
      );
      expect(
        clientB.noteText,
        'Suppressed in watch: 2 reviews filtered.\nAction mix in watch: Alert 1 • Repeat 2 • Escalated 1 • Suppressed 2.\nLatest filtered: 21:42 UTC • Camera 2 • Suppressed because the activity remained below the client notification threshold. (+1 more)\nScene action: Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.\nScene review: openai:gpt-4.1-mini • monitored movement alert • 21:44 UTC • Vehicle remains visible in the perimeter approach lane.',
      );
    });

    test('sorts watch-activation gaps ahead of active and quieter scopes', () {
      final output = projector.project(
        scopes: [
          _scope(clientId: 'CLIENT-A', siteId: 'SITE-A', host: '192.168.8.105'),
          _scope(clientId: 'CLIENT-B', siteId: 'SITE-B', host: '192.168.8.106'),
          _scope(clientId: 'CLIENT-C', siteId: 'SITE-C', host: '192.168.8.107'),
        ],
        events: [
          _intel(
            clientId: 'CLIENT-A',
            siteId: 'SITE-A',
            occurredAt: DateTime.utc(2026, 3, 13, 20, 0),
            headline: 'Older active event',
            riskScore: 55,
          ),
          _intel(
            clientId: 'CLIENT-B',
            siteId: 'SITE-B',
            occurredAt: DateTime.utc(2026, 3, 13, 21, 55),
            headline: 'Fresh active event',
            riskScore: 20,
          ),
        ],
        nowUtc: DateTime.utc(2026, 3, 13, 22, 30),
        activeWatchScopeKeys: {'CLIENT-A|SITE-A'},
        scheduleForScope: (clientId, siteId) =>
            siteId == 'SITE-C' ? disabledSchedule : activeSchedule,
        siteNameForScope: (clientId, siteId) => siteId,
        endpointLabelForScope: (uri) => uri?.host ?? '',
        cameraLabelForId: (cameraId) => 'Camera 1',
        runtimeStateByScope: const {
          'CLIENT-C|SITE-C': VideoFleetScopeRuntimeState(
            lastRecoveryLabel: 'Resynced • 21:00 UTC',
          ),
        },
      );

      expect(output.map((entry) => entry.siteId), [
        'SITE-B',
        'SITE-A',
        'SITE-C',
      ]);
      expect(output.first.watchActivationGapLabel, 'MISSED START');
      expect(output.first.watchWindowStateLabel, 'IN WINDOW');
      expect(output[1].freshnessLabel, 'Stale');
      expect(output[1].isStale, isTrue);
      expect(output[2].statusLabel, 'STANDBY');
      expect(output[2].watchLabel, 'OFF');
      expect(output[2].lastRecoveryLabel, 'Resynced • 21:00 UTC');
      expect(output[2].watchWindowLabel, isNull);
      expect(output[2].watchWindowStateLabel, isNull);
      expect(output[2].watchActivationGapLabel, isNull);
    });

    test('projects next window opening when scope is outside schedule', () {
      final output = projector.project(
        scopes: [
          _scope(clientId: 'CLIENT-D', siteId: 'SITE-D', host: '192.168.8.108'),
        ],
        events: const [],
        nowUtc: DateTime.utc(2026, 3, 13, 10, 0),
        activeWatchScopeKeys: const {},
        scheduleForScope: (clientId, siteId) => activeSchedule,
        siteNameForScope: (clientId, siteId) => '$clientId/$siteId',
        endpointLabelForScope: (uri) => uri?.host ?? '',
        cameraLabelForId: (cameraId) => 'Camera 1',
        runtimeStateByScope: const {
          'CLIENT-D|SITE-D': VideoFleetScopeRuntimeState(
            lastRecoveryLabel: 'Already aligned • 09:15 UTC',
          ),
        },
      );

      expect(output.single.watchLabel, 'SCHEDULED');
      expect(output.single.lastRecoveryLabel, 'Already aligned • 09:15 UTC');
      expect(output.single.watchWindowLabel, '18:00-06:00');
      expect(output.single.watchWindowStateLabel, 'NEXT 18:00');
      expect(output.single.watchActivationGapLabel, isNull);
    });

    test('projects same-day daytime watch window for ms vallee style scope', () {
      const daytimeSchedule = MonitoringShiftSchedule(
        enabled: true,
        startHour: 6,
        startMinute: 0,
        endHour: 18,
        endMinute: 0,
      );

      final inWindow = projector.project(
        scopes: [
          _scope(
            clientId: 'CLIENT-MS-VALLEE',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            host: '192.168.8.105',
          ),
        ],
        events: const [],
        nowUtc: DateTime.utc(2026, 3, 13, 10, 0),
        activeWatchScopeKeys: const {},
        scheduleForScope: (clientId, siteId) => daytimeSchedule,
        siteNameForScope: (clientId, siteId) => 'MS Vallee Residence',
        endpointLabelForScope: (uri) => uri?.host ?? '',
        cameraLabelForId: (cameraId) => 'Camera 1',
        runtimeStateByScope: const {},
      );

      expect(inWindow.single.watchLabel, 'SCHEDULED');
      expect(inWindow.single.watchWindowLabel, '06:00-18:00');
      expect(inWindow.single.watchWindowStateLabel, 'IN WINDOW');
      expect(inWindow.single.watchActivationGapLabel, 'MISSED START');

      final afterHours = projector.project(
        scopes: [
          _scope(
            clientId: 'CLIENT-MS-VALLEE',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            host: '192.168.8.105',
          ),
        ],
        events: const [],
        nowUtc: DateTime.utc(2026, 3, 13, 20, 0),
        activeWatchScopeKeys: const {},
        scheduleForScope: (clientId, siteId) => daytimeSchedule,
        siteNameForScope: (clientId, siteId) => 'MS Vallee Residence',
        endpointLabelForScope: (uri) => uri?.host ?? '',
        cameraLabelForId: (cameraId) => 'Camera 1',
        runtimeStateByScope: const {},
      );

      expect(afterHours.single.watchLabel, 'SCHEDULED');
      expect(afterHours.single.watchWindowLabel, '06:00-18:00');
      expect(afterHours.single.watchWindowStateLabel, 'NEXT 06:00');
      expect(afterHours.single.watchActivationGapLabel, isNull);
    });

    test(
      'sorts recent recovery scopes ahead of quieter non-recovered scopes',
      () {
        final output = projector.project(
          scopes: [
            _scope(
              clientId: 'CLIENT-A',
              siteId: 'SITE-A',
              host: '192.168.8.105',
            ),
            _scope(
              clientId: 'CLIENT-B',
              siteId: 'SITE-B',
              host: '192.168.8.106',
            ),
          ],
          events: const [],
          nowUtc: DateTime.utc(2026, 3, 13, 22, 0),
          activeWatchScopeKeys: const {},
          scheduleForScope: (clientId, siteId) => activeSchedule,
          siteNameForScope: (clientId, siteId) => siteId,
          endpointLabelForScope: (uri) => uri?.host ?? '',
          cameraLabelForId: (cameraId) => 'Camera 1',
          runtimeStateByScope: const {
            'CLIENT-B|SITE-B': VideoFleetScopeRuntimeState(
              lastRecoveryLabel: 'ADMIN • Resynced • 21:08 UTC',
            ),
          },
        );

        expect(output.map((entry) => entry.siteId), ['SITE-B', 'SITE-A']);
        expect(output.first.hasRecentRecovery, isTrue);
        expect(output.last.hasRecentRecovery, isFalse);
      },
    );
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
  String? cameraId,
  required String headline,
  required int riskScore,
  String? faceMatchId,
  double? faceConfidence,
  String? plateNumber,
  double? plateConfidence,
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
    faceMatchId: faceMatchId,
    faceConfidence: faceConfidence,
    plateNumber: plateNumber,
    plateConfidence: plateConfidence,
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
