import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/mo_knowledge_repository.dart';
import 'package:omnix_dashboard/application/mo_promotion_decision_store.dart';
import 'package:omnix_dashboard/application/mo_runtime_matching_service.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/intelligence/onyx_mo_record.dart';

void main() {
  const promotionDecisionStore = MoPromotionDecisionStore();

  setUp(() {
    promotionDecisionStore.reset();
  });

  test(
    'accepted promotions raise runtime shadow ranking for matching records',
    () {
      promotionDecisionStore.accept(
        moId: 'MO-VALIDATED',
        targetValidationStatus: 'validated',
      );
      final repository = InMemoryMoKnowledgeRepository(
        seedRecords: {
          'MO-VALIDATED': OnyxMoRecord(
            moId: 'MO-VALIDATED',
            title: 'Validated office impersonation pattern',
            environmentTypes: const ['office_building'],
            summary: 'Contractor impersonation moving floor to floor.',
            sourceType: OnyxMoSourceType.externalIncident,
            behaviorStage: 'inside_behavior',
            incidentType: 'deception_led_intrusion',
            entryIndicators: const ['spoofed_service_access'],
            insideBehaviorIndicators: const ['multi_zone_roaming'],
            deceptionIndicators: const ['maintenance_impersonation'],
            observableCues: const ['route_anomalies'],
            attackGoal: 'theft',
            observabilityScore: 0.82,
            localRelevanceScore: 0.88,
            riskWeight: 82,
            trendScore: 0.7,
            firstSeenUtc: DateTime.utc(2026, 3, 10),
            lastSeenUtc: DateTime.utc(2026, 3, 17),
            validationStatus: OnyxMoValidationStatus.shadowMode,
          ),
          'MO-SHADOW': OnyxMoRecord(
            moId: 'MO-SHADOW',
            title: 'Shadow office impersonation pattern',
            summary: 'Contractor impersonation moving floor to floor.',
            sourceType: OnyxMoSourceType.externalIncident,
            behaviorStage: 'inside_behavior',
            incidentType: 'deception_led_intrusion',
            entryIndicators: const ['spoofed_service_access'],
            insideBehaviorIndicators: const ['multi_zone_roaming'],
            deceptionIndicators: const ['maintenance_impersonation'],
            attackGoal: 'theft',
            observabilityScore: 0.4,
            localRelevanceScore: 0.4,
            riskWeight: 20,
            trendScore: 0.1,
            firstSeenUtc: DateTime.utc(2026, 3, 10),
            lastSeenUtc: DateTime.utc(2026, 3, 17),
            validationStatus: OnyxMoValidationStatus.shadowMode,
          ),
        },
      );
      final service = MoRuntimeMatchingService(repository: repository);

      final matches = service.matchReviewedIncident(
        event: _intel(),
        sceneReview: MonitoringSceneReviewRecord(
          intelligenceId: 'INT-OFFICE',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'service impersonation and roaming concern',
          decisionLabel: 'Escalation Candidate',
          decisionSummary:
              'Likely spoofed service access with abnormal roaming.',
          summary:
              'Likely maintenance impersonation moving across office zones.',
          reviewedAtUtc: DateTime.utc(2026, 3, 17, 6),
        ),
      );

      expect(matches, isNotEmpty);
      expect(matches.first.moId, 'MO-VALIDATED');
      expect(matches.first.validationStatus, 'validated');
      expect(matches.first.matchScore, greaterThan(matches[1].matchScore));
      expect(
        repository
            .readAll()
            .firstWhere((record) => record.moId == 'MO-VALIDATED')
            .metadata['runtime_match_weight'],
        0.08,
      );
    },
  );
}

IntelligenceReceived _intel() {
  return IntelligenceReceived(
    eventId: 'evt-INT-OFFICE',
    sequence: 1,
    version: 1,
    occurredAt: DateTime.utc(2026, 3, 17, 6, 0),
    intelligenceId: 'INT-OFFICE',
    provider: 'hikvision_dvr_monitor_only',
    sourceType: 'dvr',
    externalId: 'ext-INT-OFFICE',
    clientId: 'CLIENT-ALPHA',
    regionId: 'REGION-GAUTENG',
    siteId: 'SITE-ALPHA',
    cameraId: 'cam-office',
    objectLabel: 'person',
    objectConfidence: 0.94,
    headline: 'Maintenance-looking person roaming office floors',
    summary:
        'Contractor-like person moved floor to floor and tried several restricted doors.',
    riskScore: 83,
    canonicalHash: 'hash-office-1',
  );
}
