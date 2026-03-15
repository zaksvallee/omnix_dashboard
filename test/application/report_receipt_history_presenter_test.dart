import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/report_generation_service.dart';
import 'package:omnix_dashboard/application/report_receipt_history_presenter.dart';
import 'package:omnix_dashboard/application/report_receipt_scene_filter.dart';

void main() {
  test('report receipt history presenter filters and counts scene posture', () {
    final rows = [
      _FakeReceiptRow(
        const ReportReceiptSceneReviewSummary(
          includedInReceipt: true,
          totalReviews: 2,
          modelReviews: 1,
          incidentAlerts: 1,
          escalationCandidates: 1,
          topPosture: 'escalation candidate',
        ),
      ),
      _FakeReceiptRow(
        const ReportReceiptSceneReviewSummary(
          includedInReceipt: true,
          totalReviews: 1,
          modelReviews: 1,
          repeatUpdates: 1,
          suppressedActions: 1,
          escalationCandidates: 0,
          topPosture: 'reviewed',
        ),
      ),
      _FakeReceiptRow(
        const ReportReceiptSceneReviewSummary(
          includedInReceipt: false,
          totalReviews: 0,
          modelReviews: 0,
          escalationCandidates: 0,
          topPosture: 'pending',
        ),
      ),
    ];

    final metrics = ReportReceiptHistoryPresenter.buildMetrics<_FakeReceiptRow>(
      rows: rows,
      filter: ReportReceiptSceneFilter.escalation,
      sceneSummaryOf: (row) => row.sceneReviewSummary,
    );

    expect(metrics.filteredRows, hasLength(1));
    expect(metrics.reviewedCount, 2);
    expect(metrics.alertCount, 1);
    expect(metrics.repeatCount, 1);
    expect(metrics.escalationCount, 1);
    expect(metrics.suppressedCount, 1);
    expect(metrics.pendingSceneCount, 1);
  });

  test('report receipt history presenter exposes summaries for count labels', () {
    final rows = [
      _FakeReceiptRow(
        const ReportReceiptSceneReviewSummary(
          includedInReceipt: true,
          totalReviews: 1,
          modelReviews: 1,
          escalationCandidates: 0,
          topPosture: 'reviewed',
        ),
      ),
      _FakeReceiptRow(null),
    ];

    final summaries = ReportReceiptHistoryPresenter.summariesOf<_FakeReceiptRow>(
      rows,
      (row) => row.sceneReviewSummary,
    ).toList(growable: false);

    expect(summaries, hasLength(2));
    expect(summaries.first?.includedInReceipt, isTrue);
    expect(summaries.last, isNull);
  });

  test('report receipt history presenter maps each row once while building metrics', () {
    final rows = [
      _FakeReceiptRow(
        const ReportReceiptSceneReviewSummary(
          includedInReceipt: true,
          totalReviews: 1,
          modelReviews: 1,
          escalationCandidates: 0,
          topPosture: 'reviewed',
        ),
      ),
      _FakeReceiptRow(null),
      _FakeReceiptRow(
        const ReportReceiptSceneReviewSummary(
          includedInReceipt: false,
          totalReviews: 0,
          modelReviews: 0,
          escalationCandidates: 0,
          topPosture: 'pending',
        ),
      ),
    ];
    var sceneSummaryCalls = 0;

    final metrics = ReportReceiptHistoryPresenter.buildMetrics<_FakeReceiptRow>(
      rows: rows,
      filter: ReportReceiptSceneFilter.reviewed,
      sceneSummaryOf: (row) {
        sceneSummaryCalls += 1;
        return row.sceneReviewSummary;
      },
    );

    expect(sceneSummaryCalls, rows.length);
    expect(metrics.filteredRows, hasLength(1));
    expect(metrics.reviewedCount, 1);
    expect(metrics.alertCount, 0);
    expect(metrics.repeatCount, 0);
    expect(metrics.suppressedCount, 0);
    expect(metrics.pendingSceneCount, 2);
  });
}

class _FakeReceiptRow {
  final ReportReceiptSceneReviewSummary? sceneReviewSummary;

  const _FakeReceiptRow(this.sceneReviewSummary);
}
