import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/mo_promotion_decision_store.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/application/monitoring_synthetic_war_room_service.dart';
import 'package:omnix_dashboard/application/monitoring_watch_action_plan.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  group('MonitoringSyntheticWarRoomService', () {
    const service = MonitoringSyntheticWarRoomService();
    const promotionDecisionStore = MoPromotionDecisionStore();

    setUp(() {
      promotionDecisionStore.reset();
    });

    test('emits simulation and policy plans from heated regional posture', () {
      final events = <DispatchEvent>[
        _intel(
          id: 'intel-1',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 91,
          cameraId: 'gate-cam',
          faceMatchId: 'PERSON-44',
        ),
        _intel(
          id: 'intel-2',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 78,
          cameraId: 'driveway-cam',
        ),
        _intel(
          id: 'intel-3',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          riskScore: 57,
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

      final plans = service.buildSimulationPlans(
        events: events,
        sceneReviewByIntelligenceId: reviews,
        videoOpsLabel: 'Hikvision',
      );

      expect(
        plans.map((entry) => entry.actionType),
        containsAll(<String>['SYNTHETIC WAR-ROOM', 'POLICY RECOMMENDATION']),
      );
      final simulation = plans.firstWhere(
        (entry) => entry.actionType == 'SYNTHETIC WAR-ROOM',
      );
      expect(simulation.metadata['scope'], 'SIMULATION');
      expect(simulation.metadata['region'], 'REGION-GAUTENG');
      expect(simulation.metadata['lead_site'], 'SITE-VALLEE');
      expect(simulation.metadata['top_intent'], 'PREPOSITION RESPONSE');
    });

    test('uses external pressure in simulation recommendations', () {
      final events = <DispatchEvent>[
        _intel(
          id: 'news-1',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 79,
          cameraId: 'news-feed',
          sourceType: 'news',
          headline: 'Armed robbery cluster moving east',
          summary:
              'Regional robbery pressure is moving toward guarded estates.',
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

      final plans = service.buildSimulationPlans(
        events: events,
        sceneReviewByIntelligenceId:
            const <String, MonitoringSceneReviewRecord>{},
        videoOpsLabel: 'Hikvision',
      );

      expect(
        plans.any(
          (entry) =>
              entry.actionType == 'SYNTHETIC WAR-ROOM' &&
              entry.metadata['external_pressure'] == 'YES',
        ),
        isTrue,
      );
      expect(
        plans.any(
          (entry) =>
              entry.actionType == 'POLICY RECOMMENDATION' &&
              (entry.metadata['recommendation'] ?? '').contains(
                'external pressure',
              ),
        ),
        isTrue,
      );
    });

    test('uses hazard pressure in simulation recommendations', () {
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

      final plans = service.buildSimulationPlans(
        events: events,
        sceneReviewByIntelligenceId: reviews,
        videoOpsLabel: 'Hikvision',
      );

      expect(
        plans.any(
          (entry) =>
              entry.actionType == 'POLICY RECOMMENDATION' &&
              entry.metadata['hazard_signal'] == 'fire' &&
              (entry.metadata['recommendation'] ?? '').contains(
                'fire brigade staging',
              ),
        ),
        isTrue,
      );
      expect(
        plans.any(
          (entry) =>
              entry.actionType == 'POLICY RECOMMENDATION' &&
              (entry.metadata['recommendation'] ?? '').contains(
                'occupant welfare checks',
              ),
        ),
        isTrue,
      );
      final policy = plans.firstWhere(
        (entry) => entry.actionType == 'POLICY RECOMMENDATION',
      );
      expect(policy.metadata['learning_label'], 'ADVANCE FIRE');
      expect(
        policy.metadata['learning_summary'],
        'Learned bias: stage fire response one step earlier next shift.',
      );
      expect(
        policy.description,
        'Recommend rehearsing earlier fire brigade staging, occupant welfare checks, and fire spread rehearsal across REGION-GAUTENG after simulation so tomorrow’s shift starts ahead of the posture curve. Learned bias: stage fire response one step earlier next shift.',
      );
      expect(policy.countdownSeconds, 64);
      expect(policy.metadata['action_bias'], 'Recommend rehearsing');
      expect(policy.metadata['memory_countdown_bias'], '64');
    });

    test('boosts synthetic policy priority when memory bias repeats', () {
      final events = <DispatchEvent>[
        _intel(
          id: 'intel-fire-memory',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 90,
          cameraId: 'generator-room-cam',
          headline: 'HIKVISION FIRE ALERT',
          summary: 'Smoke visible in the generator room.',
        ),
      ];
      final reviews = <String, MonitoringSceneReviewRecord>{
        'intel-fire-memory': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-fire-memory',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'fire and smoke emergency',
          decisionLabel: 'Escalation Candidate',
          decisionSummary:
              'Escalated for urgent review because fire or smoke indicators were detected.',
          summary: 'Smoke plume visible inside the generator room.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 23, 0),
        ),
      };

      final plans = service.buildSimulationPlans(
        events: events,
        sceneReviewByIntelligenceId: reviews,
        videoOpsLabel: 'Hikvision',
        historicalLearningLabels: const <String>[
          'ADVANCE FIRE',
          'ADVANCE FIRE',
        ],
      );

      final policy = plans.firstWhere(
        (entry) => entry.actionType == 'POLICY RECOMMENDATION',
      );
      expect(policy.priority, MonitoringWatchAutonomyPriority.critical);
      expect(policy.countdownSeconds, 32);
      expect(
        policy.metadata['action_bias'],
        'Escalate rehearsal immediately for',
      );
      expect(policy.metadata['memory_repeat_count'], '2');
      expect(policy.metadata['memory_priority_boost'], 'CRITICAL');
      expect(policy.metadata['memory_countdown_bias'], '32');
      expect(
        policy.metadata['memory_summary'],
        'Memory bias: ADVANCE FIRE repeated in 2 recent shifts.',
      );
      expect(
        policy.description,
        'Escalate rehearsal immediately for earlier fire brigade staging, occupant welfare checks, and fire spread rehearsal across REGION-GAUTENG after simulation so tomorrow’s shift starts ahead of the posture curve. Learned bias: stage fire response one step earlier next shift. Memory bias: ADVANCE FIRE repeated in 2 recent shifts.',
      );
    });

    test('uses repeated shadow MO pressure to harden rehearsal policy', () {
      final events = <DispatchEvent>[
        _intel(
          id: 'news-office-pattern',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SEED',
          riskScore: 67,
          cameraId: 'news-feed',
          sourceType: 'news',
          headline: 'Contractors roamed office floors before device theft',
          summary:
              'Suspects posed as maintenance contractors, moved floor to floor, and checked restricted office doors.',
        ),
        _intel(
          id: 'intel-office',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 84,
          cameraId: 'office-cam',
          headline: 'Maintenance contractor probing office doors',
          summary:
              'Contractor-like person moved floor to floor and tried several restricted office doors.',
        ),
      ];
      final reviews = <String, MonitoringSceneReviewRecord>{
        'intel-office': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-office',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'service impersonation and roaming concern',
          decisionLabel: 'Escalation Candidate',
          decisionSummary:
              'Likely spoofed service access with abnormal roaming.',
          summary:
              'Likely maintenance impersonation moving across office zones.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 0),
        ),
      };

      final plans = service.buildSimulationPlans(
        events: events,
        sceneReviewByIntelligenceId: reviews,
        videoOpsLabel: 'Hikvision',
        historicalShadowMoLabels: const <String>['HARDEN ACCESS'],
        shadowValidationDriftSummary:
            'Validated 1 • Shadow mode 1 • Drift validated rising',
      );

      final policy = plans.firstWhere(
        (entry) => entry.actionType == 'POLICY RECOMMENDATION',
      );
      expect(policy.priority, MonitoringWatchAutonomyPriority.high);
      expect(policy.countdownSeconds, 48);
      expect(policy.metadata['shadow_mo_label'], 'HARDEN ACCESS');
      expect(policy.metadata['shadow_mo_repeat_count'], '1');
      expect(policy.metadata['memory_priority_boost'], 'HIGH');
      expect(policy.metadata['shadow_learning_label'], 'HARDEN ACCESS EARLIER');
      expect(
        policy.metadata['shadow_learning_summary'],
        'Learned shadow lesson: start access hardening and service-role checks one step earlier next shift.',
      );
      expect(policy.metadata['mo_promotion_id'], 'MO-EXT-NEWS-OFFICE-PATTERN');
      expect(policy.metadata['mo_promotion_target'], 'validated');
      expect(policy.metadata['mo_promotion_confidence_bias'], 'HIGH');
      expect(policy.metadata['mo_promotion_trend_bias'], '+0.20');
      expect(policy.metadata['mo_promotion_urgency_bias'], 'ACCELERATE');
      expect(
        policy.metadata['mo_promotion_validation_drift'],
        'Validated 1 • Shadow mode 1 • Drift validated rising',
      );
      expect(
        policy.metadata['mo_promotion_summary'],
        contains(
          'Accelerate MO-EXT-NEWS-OFFICE-PATTERN toward validated review',
        ),
      );
      expect(
        policy.metadata['shadow_memory_summary'],
        contains('Shadow bias: HARDEN ACCESS'),
      );
      expect(
        policy.metadata['shadow_recommendation'],
        contains('earlier access hardening rehearsal'),
      );
      expect(
        policy.description,
        contains('with earlier access hardening rehearsal'),
      );
      expect(policy.description, contains('Shadow bias: HARDEN ACCESS'));
    });

    test('uses high shadow posture weight to accelerate rehearsal policy', () {
      final events = <DispatchEvent>[
        _intel(
          id: 'news-office-posture',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SEED',
          riskScore: 67,
          cameraId: 'news-feed',
          sourceType: 'news',
          headline: 'Contractors roamed office floors before device theft',
          summary:
              'Suspects posed as maintenance contractors, moved floor to floor, and checked restricted office doors.',
        ),
        _intel(
          id: 'intel-office-posture-1',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 86,
          cameraId: 'office-cam-1',
          headline: 'Maintenance contractor probing office doors',
          summary:
              'Contractor-like person moved floor to floor and tried several restricted office doors.',
        ),
        _intel(
          id: 'intel-office-posture-2',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 87,
          cameraId: 'office-cam-2',
          headline: 'Maintenance contractor repeating office sweep',
          summary:
              'Contractor-like person moved floor to floor, returned to restricted office doors, and kept probing access.',
        ),
        _intel(
          id: 'intel-office-posture-3',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 89,
          cameraId: 'office-cam-3',
          headline: 'Contractor-like person revisits office floors',
          summary:
              'Service-looking person moved across multiple office zones and checked several restricted rooms again.',
        ),
      ];
      final reviews = <String, MonitoringSceneReviewRecord>{
        'intel-office-posture-1': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-office-posture-1',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'service impersonation and roaming concern',
          decisionLabel: 'Escalation Candidate',
          decisionSummary:
              'Likely spoofed service access with abnormal roaming.',
          summary:
              'Likely maintenance impersonation moving across office zones.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 0),
        ),
        'intel-office-posture-2': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-office-posture-2',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'service impersonation and roaming concern',
          decisionLabel: 'Escalation Candidate',
          decisionSummary:
              'Likely spoofed service access with abnormal roaming.',
          summary:
              'Likely maintenance impersonation moving across office zones again.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 5),
        ),
        'intel-office-posture-3': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-office-posture-3',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'service impersonation and roaming concern',
          decisionLabel: 'Escalation Candidate',
          decisionSummary:
              'Likely spoofed service access with abnormal roaming.',
          summary:
              'Likely maintenance impersonation moving across office zones repeatedly.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 10),
        ),
      };

      final plans = service.buildSimulationPlans(
        events: events,
        sceneReviewByIntelligenceId: reviews,
        videoOpsLabel: 'Hikvision',
      );

      final policy = plans.firstWhere(
        (entry) => entry.actionType == 'POLICY RECOMMENDATION',
      );
      expect(policy.priority, MonitoringWatchAutonomyPriority.critical);
      expect(policy.countdownSeconds, 28);
      expect(
        policy.metadata['shadow_posture_bias'],
        'POSTURE SURGE',
      );
      expect(
        policy.metadata['shadow_posture_priority'],
        'critical',
      );
      expect(
        policy.metadata['shadow_posture_countdown'],
        '28',
      );
      expect(
        int.parse(policy.metadata['shadow_posture_strength_score'] ?? '0'),
        greaterThanOrEqualTo(75),
      );
      expect(
        policy.metadata['shadow_posture_summary'],
        contains('weight '),
      );
      expect(
        policy.description,
        contains('Shadow posture weight at SITE-VALLEE is weight '),
      );
    });

    test('uses accepted promotion decisions to lock future promotion hints', () {
      promotionDecisionStore.accept(
        moId: 'MO-EXT-NEWS-OFFICE-PATTERN-ACCEPTED',
        targetValidationStatus: 'validated',
      );
      final events = <DispatchEvent>[
        _intel(
          id: 'news-office-pattern-accepted',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SEED',
          riskScore: 67,
          cameraId: 'news-feed',
          sourceType: 'news',
          headline: 'Contractors roamed office floors before device theft',
          summary:
              'Suspects posed as maintenance contractors, moved floor to floor, and checked restricted office doors.',
        ),
        _intel(
          id: 'intel-office-accepted',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 84,
          cameraId: 'office-cam',
          headline: 'Maintenance contractor probing office doors',
          summary:
              'Contractor-like person moved floor to floor and tried several restricted office doors.',
        ),
      ];
      final reviews = <String, MonitoringSceneReviewRecord>{
        'intel-office-accepted': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-office-accepted',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'service impersonation and roaming concern',
          decisionLabel: 'Escalation Candidate',
          decisionSummary:
              'Likely spoofed service access with abnormal roaming.',
          summary:
              'Likely maintenance impersonation moving across office zones.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 0),
        ),
      };

      final plans = service.buildSimulationPlans(
        events: events,
        sceneReviewByIntelligenceId: reviews,
        videoOpsLabel: 'Hikvision',
        historicalShadowMoLabels: const <String>['HARDEN ACCESS'],
      );

      final policy = plans.firstWhere(
        (entry) => entry.actionType == 'POLICY RECOMMENDATION',
      );
      expect(policy.metadata['mo_promotion_confidence_bias'], 'LOCKED');
      expect(policy.metadata['mo_promotion_trend_bias'], '+0.00');
      expect(
        policy.metadata['mo_promotion_summary'],
        contains('Promotion accepted for MO-EXT-NEWS-OFFICE-PATTERN-ACCEPTED'),
      );
    });

    test('holds rejected promotion hints until repeated shadow pressure grows', () {
      promotionDecisionStore.reject(
        moId: 'MO-EXT-NEWS-OFFICE-PATTERN-REJECTED',
        targetValidationStatus: 'validated',
      );
      final events = <DispatchEvent>[
        _intel(
          id: 'news-office-pattern-rejected',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SEED',
          riskScore: 67,
          cameraId: 'news-feed',
          sourceType: 'news',
          headline: 'Contractors roamed office floors before device theft',
          summary:
              'Suspects posed as maintenance contractors, moved floor to floor, and checked restricted office doors.',
        ),
        _intel(
          id: 'intel-office-rejected',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 84,
          cameraId: 'office-cam',
          headline: 'Maintenance contractor probing office doors',
          summary:
              'Contractor-like person moved floor to floor and tried several restricted office doors.',
        ),
      ];
      final reviews = <String, MonitoringSceneReviewRecord>{
        'intel-office-rejected': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-office-rejected',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'service impersonation and roaming concern',
          decisionLabel: 'Escalation Candidate',
          decisionSummary:
              'Likely spoofed service access with abnormal roaming.',
          summary:
              'Likely maintenance impersonation moving across office zones.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 0),
        ),
      };

      final plans = service.buildSimulationPlans(
        events: events,
        sceneReviewByIntelligenceId: reviews,
        videoOpsLabel: 'Hikvision',
        historicalShadowMoLabels: const <String>['HARDEN ACCESS'],
      );

      final policy = plans.firstWhere(
        (entry) => entry.actionType == 'POLICY RECOMMENDATION',
      );
      expect(policy.metadata['mo_promotion_confidence_bias'], 'HOLD');
      expect(policy.metadata['mo_promotion_trend_bias'], '+0.00');
      expect(
        policy.metadata['mo_promotion_summary'],
        contains(
          'Hold MO-EXT-NEWS-OFFICE-PATTERN-REJECTED after operator rejection',
        ),
      );
    });

    test('softens promotion hints when shadow validation drift is easing', () {
      final events = <DispatchEvent>[
        _intel(
          id: 'news-office-pattern-easing',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SEED',
          riskScore: 67,
          cameraId: 'news-feed',
          sourceType: 'news',
          headline: 'Contractors roamed office floors before device theft',
          summary:
              'Suspects posed as maintenance contractors, moved floor to floor, and checked restricted office doors.',
        ),
        _intel(
          id: 'intel-office-easing',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 84,
          cameraId: 'office-cam',
          headline: 'Maintenance contractor probing office doors',
          summary:
              'Contractor-like person moved floor to floor and tried several restricted office doors.',
        ),
      ];
      final reviews = <String, MonitoringSceneReviewRecord>{
        'intel-office-easing': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-office-easing',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'service impersonation and roaming concern',
          decisionLabel: 'Escalation Candidate',
          decisionSummary:
              'Likely spoofed service access with abnormal roaming.',
          summary:
              'Likely maintenance impersonation moving across office zones.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 0),
        ),
      };

      final plans = service.buildSimulationPlans(
        events: events,
        sceneReviewByIntelligenceId: reviews,
        videoOpsLabel: 'Hikvision',
        historicalShadowMoLabels: const <String>['HARDEN ACCESS'],
        shadowValidationDriftSummary:
            'Shadow mode 1 • Drift shadow mode easing',
      );

      final policy = plans.firstWhere(
        (entry) => entry.actionType == 'POLICY RECOMMENDATION',
      );
      expect(policy.metadata['mo_promotion_confidence_bias'], 'LOW');
      expect(policy.metadata['mo_promotion_trend_bias'], '+0.04');
      expect(policy.metadata['mo_promotion_urgency_bias'], 'SOFTEN');
      expect(
        policy.metadata['mo_promotion_summary'],
        contains(
          'Soften MO-EXT-NEWS-OFFICE-PATTERN-EASING toward validated review while shadow-mode validation drift eases',
        ),
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
