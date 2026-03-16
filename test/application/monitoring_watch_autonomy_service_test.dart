import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/application/monitoring_watch_autonomy_service.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  group('MonitoringWatchAutonomyService', () {
    const service = MonitoringWatchAutonomyService();

    test('builds escalation-first plans from scene reviews', () {
      final events = <DispatchEvent>[
        _intel(
          id: 'intel-escalate',
          riskScore: 91,
          siteId: 'SITE-VALLEE',
          cameraId: 'gate-cam',
          faceMatchId: 'PERSON-44',
        ),
        _intel(
          id: 'intel-repeat',
          riskScore: 80,
          siteId: 'SITE-VALLEE',
          cameraId: 'driveway-cam',
        ),
        _intel(
          id: 'intel-sandton',
          riskScore: 54,
          siteId: 'SITE-SANDTON',
          cameraId: 'lobby-cam',
        ),
      ];
      final reviews = <String, MonitoringSceneReviewRecord>{
        'intel-escalate': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-escalate',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'boundary loitering concern',
          decisionLabel: 'Escalation Candidate',
          decisionSummary:
              'Escalated for urgent review because person activity was detected.',
          summary: 'Person visible near the front gate.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 21, 15),
        ),
        'intel-repeat': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-repeat',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'repeat monitored activity',
          decisionLabel: 'Repeat Activity',
          decisionSummary:
              'Repeat activity update sent because vehicle activity repeated.',
          summary: 'Vehicle made multiple passes through the driveway.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 21, 16),
        ),
        'intel-sandton': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-sandton',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'monitored boundary watch',
          decisionLabel: 'Monitoring Alert',
          decisionSummary: 'Routine perimeter watch remains active.',
          summary: 'Sandton remains under active watch.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 21, 17),
        ),
      };

      final plans = service.buildPlans(
        events: events,
        sceneReviewByIntelligenceId: reviews,
        videoOpsLabel: 'Hikvision',
      );

      expect(
        plans.map((entry) => entry.actionType),
        containsAll(<String>[
          'PREPOSITION RESPONSE',
          'POSTURAL ECHO',
          'GLOBAL POSTURE SHIFT',
          'AUTO-DISPATCH HOLD',
          'PERSISTENCE SWEEP',
        ]),
      );
      final localEscalation = plans.firstWhere(
        (entry) => entry.actionType == 'AUTO-DISPATCH HOLD',
      );
      expect(localEscalation.description, contains('HIKVISION evidence lock'));
      expect(localEscalation.metadata['verdict'], 'Escalation Candidate');
      expect(localEscalation.metadata['camera'], 'gate-cam');
    });
  });
}

IntelligenceReceived _intel({
  required String id,
  required int riskScore,
  required String siteId,
  required String cameraId,
  String faceMatchId = '',
}) {
  return IntelligenceReceived(
    eventId: 'evt-$id',
    sequence: 1,
    version: 1,
    occurredAt: DateTime.utc(2026, 3, 16, 21, 14),
    intelligenceId: id,
    provider: 'hikvision_dvr_monitor_only',
    sourceType: 'dvr',
    externalId: 'ext-$id',
    clientId: 'CLIENT-VALLEE',
    regionId: 'REGION-GAUTENG',
    siteId: siteId,
    cameraId: cameraId,
    faceMatchId: faceMatchId.isEmpty ? null : faceMatchId,
    objectLabel: 'person',
    objectConfidence: 0.92,
    headline: 'HIKVISION LINE CROSSING',
    summary: 'Boundary activity detected',
    riskScore: riskScore,
    snapshotUrl: 'https://edge.example.com/$id.jpg',
    canonicalHash: 'hash-$id',
  );
}
