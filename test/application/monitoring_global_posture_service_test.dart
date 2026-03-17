import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/mo_knowledge_repository.dart';
import 'package:omnix_dashboard/application/mo_runtime_matching_service.dart';
import 'package:omnix_dashboard/application/monitoring_global_posture_service.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/intelligence/onyx_mo_record.dart';

void main() {
  group('MonitoringGlobalPostureService', () {
    const service = MonitoringGlobalPostureService();

    test('builds regional heat from site scene reviews', () {
      final events = <DispatchEvent>[
        _intel(
          id: 'intel-1',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 88,
          cameraId: 'gate-cam',
          faceMatchId: 'PERSON-1',
        ),
        _intel(
          id: 'intel-2',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 74,
          cameraId: 'driveway-cam',
        ),
        _intel(
          id: 'intel-3',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          riskScore: 48,
          cameraId: 'lobby-cam',
        ),
      ];

      final reviews = <String, MonitoringSceneReviewRecord>{
        'intel-1': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-1',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'boundary identity concern',
          decisionLabel: 'Escalation Candidate',
          decisionSummary: 'Person at the gate requires response review.',
          summary: 'Boundary concern near gate.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 0),
        ),
        'intel-2': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-2',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'repeat monitored activity',
          decisionLabel: 'Repeat Activity',
          decisionSummary: 'Vehicle activity repeated on driveway.',
          summary: 'Driveway activity repeated.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 1),
        ),
        'intel-3': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-3',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'monitored movement',
          decisionLabel: 'Suppressed',
          decisionSummary: 'Routine monitored movement only.',
          summary: 'No escalation needed.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 2),
        ),
      };

      final snapshot = service.buildSnapshot(
        events: events,
        sceneReviewByIntelligenceId: reviews,
        generatedAtUtc: DateTime.utc(2026, 3, 16, 22, 5),
      );

      expect(snapshot.totalSites, 2);
      expect(snapshot.criticalSiteCount, 1);
      expect(snapshot.regions, hasLength(1));
      expect(
        snapshot.regions.first.heatLevel,
        MonitoringGlobalHeatLevel.critical,
      );
      expect(snapshot.sites.first.siteId, 'SITE-VALLEE');
      expect(
        snapshot.sites.first.heatLevel,
        MonitoringGlobalHeatLevel.critical,
      );
      expect(snapshot.sites.first.dominantSignals, contains('boundary'));
    });

    test('includes news and community pressure in regional posture', () {
      final events = <DispatchEvent>[
        _intel(
          id: 'news-1',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 79,
          cameraId: 'news-feed',
          sourceType: 'news',
          headline: 'Armed robbery pattern escalates in nearby suburb',
          summary: 'Police report a robbery cluster moving toward the estate.',
        ),
        _intel(
          id: 'community-1',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          riskScore: 76,
          cameraId: 'community-feed',
          sourceType: 'community',
          headline: 'Neighborhood watch reports suspicious vehicle',
          summary: 'A suspicious vehicle was seen circling nearby estates.',
        ),
      ];

      final snapshot = service.buildSnapshot(
        events: events,
        sceneReviewByIntelligenceId: const <String, MonitoringSceneReviewRecord>{},
        generatedAtUtc: DateTime.utc(2026, 3, 16, 22, 10),
      );

      expect(snapshot.totalSites, 2);
      expect(snapshot.elevatedSiteCount, 2);
      expect(snapshot.regions, hasLength(1));
      expect(
        snapshot.regions.first.heatLevel,
        MonitoringGlobalHeatLevel.elevated,
      );
      expect(snapshot.sites.first.dominantSignals, contains('news_pressure'));
      expect(
        snapshot.sites.map((site) => site.dominantSignals.join(',')),
        anyElement(contains('community_watch')),
      );
    });

    test('uses shared hazard signals for regional fire pressure', () {
      final events = <DispatchEvent>[
        _intel(
          id: 'intel-fire',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 82,
          cameraId: 'generator-room-cam',
          objectLabel: 'smoke',
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
          decisionSummary: 'Fire posture requires urgent escalation.',
          summary: 'Smoke plume visible inside the generator room.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 3),
        ),
      };

      final snapshot = service.buildSnapshot(
        events: events,
        sceneReviewByIntelligenceId: reviews,
        generatedAtUtc: DateTime.utc(2026, 3, 16, 22, 10),
      );

      expect(snapshot.criticalSiteCount, 1);
      expect(snapshot.sites.first.dominantSignals, contains('fire'));
      expect(snapshot.regions.first.heatLevel, MonitoringGlobalHeatLevel.critical);
    });

    test('surfaces MO shadow signals in site posture without changing heat logic', () {
      final moAwareService = MonitoringGlobalPostureService(
        moRuntimeMatchingService: MoRuntimeMatchingService(
          repository: InMemoryMoKnowledgeRepository(
            seedRecords: {
              'MO-EXT-OFFICE': OnyxMoRecord(
                moId: 'MO-EXT-OFFICE',
                title: 'Office contractor impersonation pattern',
                environmentTypes: const ['office_building'],
                summary: 'Contractor impersonation moving floor to floor.',
                sourceType: OnyxMoSourceType.externalIncident,
                sourceLabel: 'Security Bulletin',
                sourceConfidence: 'high',
                patternConfidence: 'high',
                behaviorStage: 'inside_behavior',
                incidentType: 'deception_led_intrusion',
                entryIndicators: const ['spoofed_service_access'],
                insideBehaviorIndicators: const [
                  'multi_zone_roaming',
                  'room_probing',
                ],
                deceptionIndicators: const ['maintenance_impersonation'],
                observableCues: const ['route_anomalies'],
                attackGoal: 'theft',
                evidenceQuality: 'high',
                riskWeight: 82,
                recommendedActionPlans: const [
                  'PROMOTE SCENE REVIEW',
                  'RAISE READINESS',
                ],
                observabilityScore: 0.82,
                localRelevanceScore: 0.88,
                firstSeenUtc: DateTime.utc(2026, 3, 10),
                lastSeenUtc: DateTime.utc(2026, 3, 17),
                validationStatus: OnyxMoValidationStatus.shadowMode,
              ),
            },
          ),
        ),
      );
      final events = <DispatchEvent>[
        _intel(
          id: 'intel-office',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 83,
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
          decisionSummary: 'Likely spoofed service access with abnormal roaming.',
          summary: 'Likely maintenance impersonation moving across office zones.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 0),
        ),
      };

      final snapshot = moAwareService.buildSnapshot(
        events: events,
        sceneReviewByIntelligenceId: reviews,
        generatedAtUtc: DateTime.utc(2026, 3, 16, 22, 5),
      );

      expect(snapshot.sites.first.dominantSignals, contains('mo_shadow'));
      expect(snapshot.sites.first.moShadowMatchCount, greaterThan(0));
      expect(
        snapshot.sites.first.moShadowSummary,
        contains('Office contractor impersonation pattern'),
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
  String objectLabel = 'person',
  String sourceType = 'dvr',
  String headline = 'HIKVISION ALERT',
  String summary = 'Alert summary',
}) {
  return IntelligenceReceived(
    eventId: 'evt-$id',
    sequence: 1,
    version: 1,
    occurredAt: DateTime.utc(2026, 3, 16, 21, 55),
    intelligenceId: id,
    provider: 'hikvision_dvr_monitor_only',
    sourceType: sourceType,
    externalId: 'ext-$id',
    clientId: 'CLIENT-TEST',
    regionId: regionId,
    siteId: siteId,
    cameraId: cameraId,
    faceMatchId: faceMatchId.isEmpty ? null : faceMatchId,
    objectLabel: objectLabel,
    objectConfidence: 0.91,
    headline: headline,
    summary: summary,
    riskScore: riskScore,
    snapshotUrl: 'https://edge.example.com/$id.jpg',
    canonicalHash: 'hash-$id',
  );
}
