import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_orchestrator_service.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  group('MonitoringOrchestratorService', () {
    const service = MonitoringOrchestratorService();

    test('emits regional action intents from heated posture', () {
      final events = <DispatchEvent>[
        _intel(
          id: 'intel-1',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 92,
          cameraId: 'gate-cam',
          faceMatchId: 'PERSON-44',
        ),
        _intel(
          id: 'intel-2',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 80,
          cameraId: 'driveway-cam',
        ),
        _intel(
          id: 'intel-3',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          riskScore: 52,
          cameraId: 'lobby-cam',
        ),
      ];
      final reviews = <String, MonitoringSceneReviewRecord>{
        'intel-1': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-1',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'boundary identity concern',
          decisionLabel: 'Escalation Candidate',
          decisionSummary: 'Escalation posture requires response review.',
          summary: 'Boundary activity at gate.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 30),
        ),
        'intel-2': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-2',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'repeat monitored activity',
          decisionLabel: 'Repeat Activity',
          decisionSummary: 'Driveway activity repeated.',
          summary: 'Vehicle repeating at driveway.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 31),
        ),
        'intel-3': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-3',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'monitored boundary watch',
          decisionLabel: 'Monitoring Alert',
          decisionSummary: 'Sandton perimeter is still calm but active.',
          summary: 'Routine watch remains active at Sandton.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 32),
        ),
      };

      final intents = service.buildActionIntents(
        events: events,
        sceneReviewByIntelligenceId: reviews,
        videoOpsLabel: 'Hikvision',
      );

      expect(
        intents.map((entry) => entry.actionType),
        containsAll(<String>[
          'PREPOSITION RESPONSE',
          'POSTURAL ECHO',
          'RAISE PARTNER READINESS',
          'DRAFT CLIENT WARNING',
          'PROMOTE SCENE REVIEW',
        ]),
      );
      expect(intents.first.metadata['scope'], 'ORCHESTRATOR');
      expect(
        intents.any(
          (entry) =>
              entry.actionType == 'POSTURAL ECHO' &&
              entry.metadata['echo_target'] == 'SITE-SANDTON',
        ),
        isTrue,
      );
    });

    test('uses external news pressure to raise readiness intents', () {
      final events = <DispatchEvent>[
        _intel(
          id: 'news-1',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 79,
          cameraId: 'news-feed',
          sourceType: 'news',
          headline: 'Armed robbery cluster moving east',
          summary: 'Regional robbery pressure is moving toward guarded estates.',
        ),
        _intel(
          id: 'community-1',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          riskScore: 76,
          cameraId: 'community-feed',
          sourceType: 'community',
          headline: 'Neighborhood watch reports suspicious vehicle',
          summary: 'Suspicious vehicle is probing estates in the same region.',
        ),
      ];

      final intents = service.buildActionIntents(
        events: events,
        sceneReviewByIntelligenceId: const <String, MonitoringSceneReviewRecord>{},
        videoOpsLabel: 'Hikvision',
      );

      expect(
        intents.map((entry) => entry.actionType),
        containsAll(<String>[
          'PREPOSITION RESPONSE',
          'RAISE PARTNER READINESS',
          'POSTURAL ECHO',
        ]),
      );
      expect(
        intents.any((entry) => entry.metadata['echo_target'] == 'SITE-SANDTON'),
        isTrue,
      );
    });
  });
}

IntelligenceReceived _intel({
  required String id,
  required String regionId,
  required String siteId,
  required int riskScore,
  required String cameraId,
  String faceMatchId = '',
  String sourceType = 'dvr',
  String headline = 'HIKVISION ALERT',
  String summary = 'Boundary activity detected',
}) {
  return IntelligenceReceived(
    eventId: 'evt-$id',
    sequence: 1,
    version: 1,
    occurredAt: DateTime.utc(2026, 3, 16, 22, 25),
    intelligenceId: id,
    provider: 'hikvision_dvr_monitor_only',
    sourceType: sourceType,
    externalId: 'ext-$id',
    clientId: 'CLIENT-VALLEE',
    regionId: regionId,
    siteId: siteId,
    cameraId: cameraId,
    faceMatchId: faceMatchId.isEmpty ? null : faceMatchId,
    objectLabel: 'person',
    objectConfidence: 0.94,
    headline: headline,
    summary: summary,
    riskScore: riskScore,
    snapshotUrl: 'https://edge.example.com/$id.jpg',
    canonicalHash: 'hash-$id',
  );
}
