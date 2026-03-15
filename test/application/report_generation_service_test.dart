import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/application/report_generation_service.dart';
import 'package:omnix_dashboard/domain/store/in_memory_event_store.dart';

import '../fixtures/report_test_intelligence.dart';
import '../fixtures/report_test_receipt.dart';

void main() {
  group('ReportGenerationService scene review receipt summary', () {
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
            decisionSummary:
                'Vehicle remained below escalation threshold.',
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
  });
}
