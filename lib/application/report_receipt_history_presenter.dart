import 'report_generation_service.dart';
import 'report_receipt_scene_filter.dart';

class ReportReceiptHistoryMetrics<T> {
  final List<T> filteredRows;
  final int reviewedCount;
  final int alertCount;
  final int repeatCount;
  final int escalationCount;
  final int suppressedCount;
  final int pendingSceneCount;

  const ReportReceiptHistoryMetrics({
    required this.filteredRows,
    required this.reviewedCount,
    required this.alertCount,
    required this.repeatCount,
    required this.escalationCount,
    required this.suppressedCount,
    required this.pendingSceneCount,
  });
}

class ReportReceiptHistoryPresenter {
  const ReportReceiptHistoryPresenter._();

  static ReportReceiptHistoryMetrics<T> buildMetrics<T>({
    required List<T> rows,
    required ReportReceiptSceneFilter filter,
    required ReportReceiptSceneReviewSummary? Function(T row) sceneSummaryOf,
  }) {
    final filteredRows = <T>[];
    var reviewedCount = 0;
    var alertCount = 0;
    var repeatCount = 0;
    var escalationCount = 0;
    var suppressedCount = 0;
    var pendingSceneCount = 0;

    for (final row in rows) {
      final summary = sceneSummaryOf(row);
      if (filter.matches(summary)) {
        filteredRows.add(row);
      }
      if (summary?.includedInReceipt == true) {
        reviewedCount += 1;
      } else {
        pendingSceneCount += 1;
      }
      if ((summary?.escalationCandidates ?? 0) > 0) {
        escalationCount += 1;
      }
      if ((summary?.incidentAlerts ?? 0) > 0) {
        alertCount += 1;
      }
      if ((summary?.repeatUpdates ?? 0) > 0) {
        repeatCount += 1;
      }
      if ((summary?.suppressedActions ?? 0) > 0) {
        suppressedCount += 1;
      }
    }

    return ReportReceiptHistoryMetrics(
      filteredRows: List.unmodifiable(filteredRows),
      reviewedCount: reviewedCount,
      alertCount: alertCount,
      repeatCount: repeatCount,
      escalationCount: escalationCount,
      suppressedCount: suppressedCount,
      pendingSceneCount: pendingSceneCount,
    );
  }

  static Iterable<ReportReceiptSceneReviewSummary?> summariesOf<T>(
    Iterable<T> rows,
    ReportReceiptSceneReviewSummary? Function(T row) sceneSummaryOf,
  ) {
    return rows.map(sceneSummaryOf);
  }
}
