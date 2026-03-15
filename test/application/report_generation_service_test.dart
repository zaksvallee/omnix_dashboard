import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/application/report_generation_service.dart';
import 'package:omnix_dashboard/domain/crm/reporting/report_branding_configuration.dart';
import 'package:omnix_dashboard/domain/crm/reporting/report_section_configuration.dart';
import 'package:omnix_dashboard/domain/store/in_memory_event_store.dart';

import '../fixtures/report_test_intelligence.dart';
import '../fixtures/report_test_receipt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportGenerationService scene review receipt summary', () {
    test('generatePdfReport persists report section configuration', () async {
      final service = ReportGenerationService(store: InMemoryEventStore());

      final generated = await service.generatePdfReport(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        nowUtc: DateTime.utc(2026, 3, 15, 6, 0),
        brandingConfiguration: const ReportBrandingConfiguration(
          primaryLabel: 'VISION Tactical',
          endorsementLine: 'Powered by ONYX',
        ),
        sectionConfiguration: const ReportSectionConfiguration(
          includeTimeline: true,
          includeDispatchSummary: false,
          includeCheckpointCompliance: true,
          includeAiDecisionLog: false,
          includeGuardMetrics: true,
        ),
      );

      expect(generated.receiptEvent.reportSchemaVersion, 3);
      expect(generated.receiptEvent.primaryBrandLabel, 'VISION Tactical');
      expect(generated.receiptEvent.endorsementLine, 'Powered by ONYX');
      expect(generated.receiptEvent.includeTimeline, isTrue);
      expect(generated.receiptEvent.includeDispatchSummary, isFalse);
      expect(generated.receiptEvent.includeCheckpointCompliance, isTrue);
      expect(generated.receiptEvent.includeAiDecisionLog, isFalse);
      expect(generated.receiptEvent.includeGuardMetrics, isTrue);
      expect(generated.bundle.sectionConfiguration.includeTimeline, isTrue);
      expect(
        generated.bundle.sectionConfiguration.includeDispatchSummary,
        isFalse,
      );
      expect(
        generated.bundle.sectionConfiguration.includeCheckpointCompliance,
        isTrue,
      );
      expect(
        generated.bundle.sectionConfiguration.includeAiDecisionLog,
        isFalse,
      );
      expect(generated.bundle.sectionConfiguration.includeGuardMetrics, isTrue);
      expect(
        generated.bundle.brandingConfiguration.primaryLabel,
        'VISION Tactical',
      );
      expect(
        generated.bundle.brandingConfiguration.endorsementLine,
        'Powered by ONYX',
      );
    });

    test('returns embedded scene review metrics for schema v2 receipts', () {
      final store = InMemoryEventStore();
      store.append(
        buildTestIntelligenceReceived(
          eventId: 'evt-1',
          occurredAt: DateTime.utc(2026, 3, 14, 21, 18),
          intelligenceId: 'intel-1',
          cameraId: 'channel-1',
          headline: 'Repeat movement',
          summary: 'Repeat movement detected.',
          riskScore: 68,
        ),
      );

      final service = ReportGenerationService(
        store: store,
        sceneReviewByIntelligenceId: {
          'intel-1': MonitoringSceneReviewRecord(
            intelligenceId: 'intel-1',
            evidenceRecordHash: 'evidence-1',
            sourceLabel: 'openai:gpt-4.1-mini',
            postureLabel: 'escalation candidate',
            decisionLabel: 'Escalation Candidate',
            summary: 'Person visible near the boundary after repeat activity.',
            reviewedAtUtc: DateTime.utc(2026, 3, 14, 21, 18, 6),
          ),
        },
      );

      final summary = service.summarizeSceneReviewForReceipt(
        buildTestReportGenerated(
          eventId: 'RPT-1',
          occurredAt: DateTime.utc(2026, 3, 14, 22, 0),
          reportSchemaVersion: 2,
        ),
      );

      expect(summary.includedInReceipt, isTrue);
      expect(summary.totalReviews, 1);
      expect(summary.modelReviews, 1);
      expect(summary.suppressedActions, 0);
      expect(summary.incidentAlerts, 0);
      expect(summary.repeatUpdates, 0);
      expect(summary.escalationCandidates, 1);
      expect(summary.topPosture, 'escalation candidate');
      expect(
        summary.latestActionBucket,
        ReportReceiptLatestActionBucket.escalation,
      );
      expect(
        summary.latestActionTaken,
        '2026-03-14T21:18:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary after repeat activity.',
      );
      expect(summary.latestSuppressedPattern, isEmpty);
    });

    test('returns pending summary for pre-scene-review receipts', () {
      final service = ReportGenerationService(store: InMemoryEventStore());

      final summary = service.summarizeSceneReviewForReceipt(
        buildTestReportGenerated(
          eventId: 'RPT-LEGACY',
          occurredAt: DateTime.utc(2026, 3, 14, 22, 0),
          eventRangeStart: 0,
          eventRangeEnd: 0,
          eventCount: 0,
          reportSchemaVersion: 1,
        ),
      );

      expect(summary.includedInReceipt, isFalse);
      expect(summary.totalReviews, 0);
      expect(summary.suppressedActions, 0);
      expect(summary.topPosture, 'none');
      expect(summary.latestActionBucket, ReportReceiptLatestActionBucket.none);
      expect(summary.latestActionTaken, isEmpty);
      expect(summary.latestSuppressedPattern, isEmpty);
    });

    test('returns latest suppressed pattern for reviewed receipts', () {
      final store = InMemoryEventStore();
      store.append(
        buildTestIntelligenceReceived(
          eventId: 'evt-2',
          occurredAt: DateTime.utc(2026, 3, 14, 21, 16),
          intelligenceId: 'intel-2',
          cameraId: 'channel-3',
          headline: 'Low significance motion',
          summary: 'Low significance motion detected.',
          riskScore: 21,
        ),
      );

      final service = ReportGenerationService(
        store: store,
        sceneReviewByIntelligenceId: {
          'intel-2': MonitoringSceneReviewRecord(
            intelligenceId: 'intel-2',
            evidenceRecordHash: 'evidence-2',
            sourceLabel: 'metadata:fallback',
            postureLabel: 'reviewed',
            decisionLabel: 'Suppressed Review',
            decisionSummary: 'Vehicle remained below escalation threshold.',
            summary: 'Routine vehicle motion remained internal.',
            reviewedAtUtc: DateTime.utc(2026, 3, 14, 21, 16, 5),
          ),
        },
      );

      final summary = service.summarizeSceneReviewForReceipt(
        buildTestReportGenerated(
          eventId: 'RPT-2',
          occurredAt: DateTime.utc(2026, 3, 14, 22, 0),
          reportSchemaVersion: 2,
        ),
      );

      expect(summary.suppressedActions, 1);
      expect(
        summary.latestActionBucket,
        ReportReceiptLatestActionBucket.suppressed,
      );
      expect(summary.latestActionTaken, isEmpty);
      expect(
        summary.latestSuppressedPattern,
        '2026-03-14T21:16:00.000Z • Camera 3 • Vehicle remained below escalation threshold.',
      );
    });

    test('returns not included summary when ai decision log is disabled', () {
      final service = ReportGenerationService(store: InMemoryEventStore());

      final summary = service.summarizeSceneReviewForReceipt(
        buildTestReportGenerated(
          eventId: 'RPT-NO-AI-LOG',
          occurredAt: DateTime.utc(2026, 3, 14, 22, 0),
          reportSchemaVersion: 3,
          includeAiDecisionLog: false,
        ),
      );

      expect(summary.includedInReceipt, isFalse);
      expect(summary.totalReviews, 0);
      expect(summary.topPosture, 'not included');
      expect(summary.latestActionBucket, ReportReceiptLatestActionBucket.none);
    });
  });
}
