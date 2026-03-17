import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/mo_extraction_service.dart';
import 'package:omnix_dashboard/application/mo_knowledge_repository.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/intelligence/news_item.dart';
import 'package:omnix_dashboard/domain/intelligence/onyx_mo_record.dart';

void main() {
  const service = MoExtractionService();

  test('extracts external incident MO records into shadow-mode candidates', () {
    final record = service.extractFromNewsItem(
      const NewsItem(
        id: 'news-1',
        title: 'Contractors returned to office park after hours',
        source: 'Industry Security Bulletin',
        summary:
            'Suspects posed as maintenance contractors, returned later after hours, moved floor to floor through restricted areas, and tried several doors before stealing devices.',
        riskScore: 82,
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'BUSINESS-PARK',
      ),
      observedAtUtc: DateTime.utc(2026, 3, 17, 6, 0),
    );

    expect(record.moId, 'MO-EXT-NEWS-1');
    expect(record.sourceType, OnyxMoSourceType.externalIncident);
    expect(record.validationStatus, OnyxMoValidationStatus.shadowMode);
    expect(record.environmentTypes, contains('office_building'));
    expect(record.deceptionIndicators, contains('maintenance_impersonation'));
    expect(record.entryIndicators, contains('spoofed_service_access'));
    expect(record.observableCues, contains('after_hours_presence'));
    expect(record.recommendedActionPlans, contains('PREPOSITION RESPONSE'));
    expect(record.siteTypeOverrides['office_building'], greaterThanOrEqualTo(70));
  });

  test('extracts internal incident MO records with high local relevance', () {
    final record = service.extractInternalIncident(
      event: IntelligenceReceived(
        eventId: 'INT-1',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 17, 1, 0),
        intelligenceId: 'INTEL-1',
        provider: 'hikvision',
        sourceType: 'dvr',
        externalId: 'ext-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-ALPHA',
        cameraId: 'lobby-cam',
        headline: 'Maintenance contractor probing doors',
        summary:
            'Maintenance-looking individual moved floor to floor and tried several restricted doors.',
        riskScore: 89,
        canonicalHash: 'hash-1',
      ),
      sceneReview: MonitoringSceneReviewRecord(
        intelligenceId: 'INTEL-1',
        sourceLabel: 'openai:gpt-5.4-mini',
        postureLabel: 'service impersonation and roaming concern',
        decisionLabel: 'Escalation Candidate',
        decisionSummary:
            'Escalate because spoofed service access and abnormal roaming were detected.',
        summary: 'Likely service impersonation moving across multiple zones.',
        reviewedAtUtc: DateTime.utc(2026, 3, 17, 1, 2),
      ),
    );

    expect(record.moId, 'MO-INT-INTEL-1');
    expect(record.sourceType, OnyxMoSourceType.internalIncident);
    expect(record.validationStatus, OnyxMoValidationStatus.validated);
    expect(record.localRelevanceScore, greaterThanOrEqualTo(0.85));
    expect(record.recommendedActionPlans, contains('FEED GLOBAL POSTURE'));
    expect(record.metadata['site_id'], 'SITE-ALPHA');
    expect(record.metadata['scene_decision_label'], 'Escalation Candidate');
  });

  test('stores and filters MO records by environment and validation state', () {
    final repository = InMemoryMoKnowledgeRepository();
    final external = service.extractFromNewsItem(
      const NewsItem(
        id: 'news-warehouse',
        title: 'Reconnaissance at logistics warehouse',
        source: 'Security Bulletin',
        summary:
            'Suspicious vehicle returned later, loitered near the perimeter fence, and mapped cameras at a logistics warehouse.',
        riskScore: 71,
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'WAREHOUSE-4',
      ),
      observedAtUtc: DateTime.utc(2026, 3, 17, 6, 0),
    );
    final internal = service.extractInternalIncident(
      event: IntelligenceReceived(
        eventId: 'INT-2',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 17, 2, 0),
        intelligenceId: 'INTEL-2',
        provider: 'hikvision',
        sourceType: 'dvr',
        externalId: 'ext-2',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-BRAVO',
        headline: 'Office impersonation alert',
        summary: 'Contractor-like person tried several office doors.',
        riskScore: 84,
        canonicalHash: 'hash-2',
      ),
      sceneReview: MonitoringSceneReviewRecord(
        intelligenceId: 'INTEL-2',
        sourceLabel: 'openai:gpt-5.4-mini',
        postureLabel: 'service impersonation concern',
        summary: 'Likely maintenance impersonation.',
        reviewedAtUtc: DateTime.utc(2026, 3, 17, 2, 1),
      ),
    );

    repository.upsertAll(<OnyxMoRecord>[external, internal]);

    expect(repository.readAll(), hasLength(2));
    expect(repository.readByEnvironmentType('warehouse'), hasLength(1));
    expect(
      repository.readByValidationStatus(OnyxMoValidationStatus.validated),
      hasLength(1),
    );
  });
}
