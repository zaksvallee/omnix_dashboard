import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/application/monitoring_synthetic_war_room_service.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  group('MonitoringSyntheticWarRoomService', () {
    const service = MonitoringSyntheticWarRoomService();

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

      final plans = service.buildSimulationPlans(
        events: events,
        sceneReviewByIntelligenceId: const <String, MonitoringSceneReviewRecord>{},
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
