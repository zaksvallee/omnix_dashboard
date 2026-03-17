import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_orchestrator_service.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/application/monitoring_watch_action_plan.dart';
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

    test('emits hazard-specific response intents for fire posture', () {
      final events = <DispatchEvent>[
        _intel(
          id: 'intel-fire',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 88,
          cameraId: 'generator-room-cam',
          headline: 'HIKVISION FIRE ALERT',
          summary: 'Smoke visible in the generator room.',
        ),
      ];
      final reviews = <String, MonitoringSceneReviewRecord>{
        'intel-fire': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-fire',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'fire and smoke emergency',
          decisionLabel: 'Escalation Candidate',
          decisionSummary:
              'Escalated for urgent review because fire or smoke indicators were detected.',
          summary: 'Smoke plume visible inside the generator room.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 30),
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
          'ACTIVATE FIRE PLAYBOOK',
          'DISPATCH FIRE RESPONSE',
          'TRIGGER OCCUPANT WELFARE CHECK',
          'DRAFT SAFETY WARNING',
        ]),
      );
      final playbook = intents.firstWhere(
        (entry) => entry.actionType == 'ACTIVATE FIRE PLAYBOOK',
      );
      expect(playbook.priority, MonitoringWatchAutonomyPriority.critical);
      expect(playbook.metadata['hazard_signal'], 'fire');
      expect(
        playbook.description,
        'Lock HIKVISION fire verification on SITE-VALLEE, pre-stage emergency response, and raise a client safety warning before spread compounds.',
      );
      final dispatch = intents.firstWhere(
        (entry) => entry.actionType == 'DISPATCH FIRE RESPONSE',
      );
      expect(dispatch.priority, MonitoringWatchAutonomyPriority.critical);
      expect(dispatch.metadata['response_policy'], 'fire_emergency_dispatch');
      expect(
        dispatch.description,
        'Stage fire response for SITE-VALLEE, hold HIKVISION smoke verification, and keep the client safety call hot while spread risk is still containable.',
      );
      final welfare = intents.firstWhere(
        (entry) => entry.actionType == 'TRIGGER OCCUPANT WELFARE CHECK',
      );
      expect(welfare.metadata['response_policy'], 'occupant_welfare_check');
      expect(
        welfare.description,
        'Trigger immediate occupant welfare verification for SITE-VALLEE while fire response staging is underway.',
      );
      final safetyWarning = intents.firstWhere(
        (entry) => entry.actionType == 'DRAFT SAFETY WARNING',
      );
      expect(
        safetyWarning.description,
        'Prepare a client and operator fire safety warning for SITE-VALLEE with emergency evidence held for human veto.',
      );
    });

    test('drafts next-shift fire readiness when synthetic learning repeats', () {
      final events = <DispatchEvent>[
        _intel(
          id: 'intel-fire-draft',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 88,
          cameraId: 'generator-room-cam',
          headline: 'HIKVISION FIRE ALERT',
          summary: 'Smoke visible in the generator room.',
        ),
      ];
      final reviews = <String, MonitoringSceneReviewRecord>{
        'intel-fire-draft': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-fire-draft',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'fire and smoke emergency',
          decisionLabel: 'Escalation Candidate',
          decisionSummary:
              'Escalated for urgent review because fire or smoke indicators were detected.',
          summary: 'Smoke plume visible inside the generator room.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 30),
        ),
      };

      final intents = service.buildActionIntents(
        events: events,
        sceneReviewByIntelligenceId: reviews,
        videoOpsLabel: 'Hikvision',
        historicalSyntheticLearningLabels: const <String>[
          'ADVANCE FIRE',
          'ADVANCE FIRE',
        ],
      );

      final draft = intents.firstWhere(
        (entry) => entry.actionType == 'DRAFT NEXT-SHIFT FIRE READINESS',
      );
      expect(draft.priority, MonitoringWatchAutonomyPriority.critical);
      expect(draft.countdownSeconds, 18);
      expect(draft.metadata['scope'], 'NEXT_SHIFT');
      expect(draft.metadata['learning_label'], 'ADVANCE FIRE');
      expect(draft.metadata['learning_repeat_count'], '2');
      expect(
        draft.description,
        'Prebuild next-shift fire readiness for SITE-VALLEE with earlier fire brigade staging, occupant welfare checks, and fire spread rehearsal and hold HIKVISION verification tighter because the same synthetic lesson repeated across 2 recent shifts.',
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
