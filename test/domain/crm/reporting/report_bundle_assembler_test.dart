import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/crm/crm_event.dart';
import 'package:omnix_dashboard/domain/crm/reporting/report_bundle_assembler.dart';
import 'package:omnix_dashboard/domain/crm/reporting/report_sections.dart';

void main() {
  test(
    'report bundle assembler leaves narratives empty and builds a request',
    () {
      final bundle = ReportBundleAssembler.build(
        clientId: 'CLIENT-MS-VALLEE',
        currentMonth: '2026-04',
        previousMonth: '2026-03',
        incidentEvents: const [],
        crmEvents: const [],
        dispatchEvents: const [],
        sceneReview: const SceneReviewSnapshot(
          totalReviews: 0,
          modelReviews: 0,
          metadataFallbackReviews: 0,
          escalationCandidates: 0,
          topPosture: 'routine',
          highlights: <SceneReviewHighlightSnapshot>[],
        ),
      );

      expect(bundle.supervisorAssessment.operationalSummary, isEmpty);
      expect(bundle.supervisorAssessment.riskTrend, isEmpty);
      expect(bundle.supervisorAssessment.recommendations, isEmpty);
      expect(bundle.companyAchievements.highlights, isEmpty);
      expect(bundle.emergingThreats.patternsObserved, isEmpty);
      expect(bundle.narrativeRequest, isNotNull);
      expect(bundle.narrativeRequest!.clientId, 'CLIENT-MS-VALLEE');
      expect(bundle.narrativeRequest!.reportPeriod, '2026-04');
      expect(bundle.narrativeRequest!.incidentSummary, isNotEmpty);
      expect(
        bundle.narrativeRequest!.slaComplianceRate,
        inInclusiveRange(0.0, 1.0),
      );
    },
  );

  test('report bundle assembler falls back when crm events omit sla profile', () {
    final bundle = ReportBundleAssembler.build(
      clientId: 'CLIENT-CRM-1',
      currentMonth: '2026-04',
      previousMonth: '2026-03',
      incidentEvents: const [],
      crmEvents: const <CRMEvent>[
        CRMEvent(
          eventId: 'crm-1',
          aggregateId: 'CLIENT-CRM-1',
          type: CRMEventType.clientCreated,
          timestamp: '2026-04-01T08:00:00.000Z',
          payload: <String, dynamic>{'name': 'Fallback Client'},
        ),
        CRMEvent(
          eventId: 'crm-2',
          aggregateId: 'CLIENT-CRM-1',
          type: CRMEventType.siteAdded,
          timestamp: '2026-04-01T08:05:00.000Z',
          payload: <String, dynamic>{
            'site_id': 'SITE-1',
            'name': 'North Gate',
            'geo_reference': 'NORTH-GATE',
          },
        ),
      ],
      dispatchEvents: const [],
      sceneReview: const SceneReviewSnapshot(
        totalReviews: 0,
        modelReviews: 0,
        metadataFallbackReviews: 0,
        escalationCandidates: 0,
        topPosture: 'routine',
        highlights: <SceneReviewHighlightSnapshot>[],
      ),
    );

    expect(bundle.clientSnapshot.clientName, 'Fallback Client');
    expect(bundle.clientSnapshot.siteName, 'North Gate');
    expect(bundle.clientSnapshot.slaTier, 'PROTECT');
    expect(bundle.monthlyReport.slaTierName, 'PROTECT');
    expect(bundle.narrativeRequest, isNotNull);
  });
}
