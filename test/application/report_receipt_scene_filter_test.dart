import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/report_generation_service.dart';
import 'package:omnix_dashboard/application/report_receipt_scene_filter.dart';

void main() {
  test('status labels keep latest-action and pending copy aligned', () {
    expect(
      ReportReceiptSceneFilter.latestAlerts.statusLabel,
      'Latest Alert receipts',
    );
    expect(
      ReportReceiptSceneFilter.latestSuppressed.statusLabel,
      'Latest Suppressed receipts',
    );
    expect(
      ReportReceiptSceneFilter.pending.statusLabel,
      'Scene Pending receipts',
    );
    expect(
      ReportReceiptSceneFilter.latestAlerts.viewingLabel,
      'Viewing Latest Alert receipts',
    );
    expect(
      ReportReceiptSceneFilter.pending.viewingSentence,
      'Viewing Scene Pending receipts.',
    );
  });

  test('reviewed filter matches only included receipts with one or more reviews', () {
    const reviewed = ReportReceiptSceneReviewSummary(
      includedInReceipt: true,
      totalReviews: 2,
      modelReviews: 1,
      escalationCandidates: 0,
      topPosture: 'reviewed',
    );
    const zeroReviewIncluded = ReportReceiptSceneReviewSummary(
      includedInReceipt: true,
      totalReviews: 0,
      modelReviews: 0,
      escalationCandidates: 0,
      topPosture: 'none',
    );
    const pending = ReportReceiptSceneReviewSummary(
      includedInReceipt: false,
      totalReviews: 0,
      modelReviews: 0,
      escalationCandidates: 0,
      topPosture: 'pending',
    );

    expect(ReportReceiptSceneFilter.reviewed.matches(reviewed), isTrue);
    expect(
      ReportReceiptSceneFilter.reviewed.matches(zeroReviewIncluded),
      isFalse,
    );
    expect(ReportReceiptSceneFilter.reviewed.matches(pending), isFalse);
  });

  test('pending filter matches missing or schema-pending scene review summaries', () {
    const pending = ReportReceiptSceneReviewSummary(
      includedInReceipt: false,
      totalReviews: 0,
      modelReviews: 0,
      escalationCandidates: 0,
      topPosture: 'pending',
    );
    const reviewed = ReportReceiptSceneReviewSummary(
      includedInReceipt: true,
      totalReviews: 1,
      modelReviews: 1,
      escalationCandidates: 0,
      topPosture: 'reviewed',
    );

    expect(ReportReceiptSceneFilter.pending.matches(null), isTrue);
    expect(ReportReceiptSceneFilter.pending.matches(pending), isTrue);
    expect(ReportReceiptSceneFilter.pending.matches(reviewed), isFalse);
  });

  test('suppressed filter matches included receipts with suppressed actions', () {
    const suppressed = ReportReceiptSceneReviewSummary(
      includedInReceipt: true,
      totalReviews: 2,
      modelReviews: 1,
      suppressedActions: 1,
      escalationCandidates: 0,
      topPosture: 'reviewed',
    );
    const unsuppressed = ReportReceiptSceneReviewSummary(
      includedInReceipt: true,
      totalReviews: 2,
      modelReviews: 1,
      suppressedActions: 0,
      escalationCandidates: 0,
      topPosture: 'reviewed',
    );

    expect(ReportReceiptSceneFilter.suppressed.matches(suppressed), isTrue);
    expect(ReportReceiptSceneFilter.suppressed.matches(unsuppressed), isFalse);
  });

  test('alerts and repeat filters match included receipts by action mix', () {
    const alert = ReportReceiptSceneReviewSummary(
      includedInReceipt: true,
      totalReviews: 1,
      modelReviews: 1,
      incidentAlerts: 1,
      escalationCandidates: 0,
      topPosture: 'reviewed',
      latestActionBucket: ReportReceiptLatestActionBucket.alerts,
    );
    const repeat = ReportReceiptSceneReviewSummary(
      includedInReceipt: true,
      totalReviews: 1,
      modelReviews: 1,
      repeatUpdates: 1,
      escalationCandidates: 0,
      topPosture: 'repeat activity',
      latestActionBucket: ReportReceiptLatestActionBucket.repeat,
    );

    expect(ReportReceiptSceneFilter.alerts.matches(alert), isTrue);
    expect(ReportReceiptSceneFilter.alerts.matches(repeat), isFalse);
    expect(ReportReceiptSceneFilter.repeat.matches(repeat), isTrue);
    expect(ReportReceiptSceneFilter.repeat.matches(alert), isFalse);
  });

  test('latest action filters match included receipts by latest action bucket', () {
    const latestAlert = ReportReceiptSceneReviewSummary(
      includedInReceipt: true,
      totalReviews: 1,
      modelReviews: 1,
      incidentAlerts: 1,
      escalationCandidates: 0,
      topPosture: 'reviewed',
      latestActionBucket: ReportReceiptLatestActionBucket.alerts,
    );
    const latestSuppressed = ReportReceiptSceneReviewSummary(
      includedInReceipt: true,
      totalReviews: 1,
      modelReviews: 0,
      suppressedActions: 1,
      escalationCandidates: 0,
      topPosture: 'reviewed',
      latestActionBucket: ReportReceiptLatestActionBucket.suppressed,
    );

    expect(
      ReportReceiptSceneFilter.latestAlerts.matches(latestAlert),
      isTrue,
    );
    expect(
      ReportReceiptSceneFilter.latestRepeat.matches(latestAlert),
      isFalse,
    );
    expect(
      ReportReceiptSceneFilter.latestSuppressed.matches(latestSuppressed),
      isTrue,
    );
    expect(
      ReportReceiptSceneFilter.latestEscalation.matches(latestSuppressed),
      isFalse,
    );
  });

  test('countLabel reports filtered totals using filter-specific matching rules', () {
    const summaries = <ReportReceiptSceneReviewSummary?>[
      ReportReceiptSceneReviewSummary(
        includedInReceipt: true,
        totalReviews: 2,
        modelReviews: 1,
        escalationCandidates: 1,
        topPosture: 'escalation candidate',
        latestActionBucket: ReportReceiptLatestActionBucket.escalation,
      ),
      ReportReceiptSceneReviewSummary(
        includedInReceipt: true,
        totalReviews: 1,
        modelReviews: 1,
        escalationCandidates: 0,
        topPosture: 'reviewed',
        latestActionBucket: ReportReceiptLatestActionBucket.alerts,
      ),
      ReportReceiptSceneReviewSummary(
        includedInReceipt: false,
        totalReviews: 0,
        modelReviews: 0,
        escalationCandidates: 0,
        topPosture: 'pending',
      ),
      null,
    ];

    expect(
      ReportReceiptSceneFilter.escalation.countLabel(summaries),
      'Escalation (1)',
    );
    expect(
      ReportReceiptSceneFilter.alerts.countLabel(summaries),
      'Alerts (0)',
    );
    expect(
      ReportReceiptSceneFilter.repeat.countLabel(summaries),
      'Repeat (0)',
    );
    expect(
      ReportReceiptSceneFilter.latestEscalation.countLabel(summaries),
      'Latest Escalation (1)',
    );
    expect(
      ReportReceiptSceneFilter.latestAlerts.countLabel(summaries),
      'Latest Alert (1)',
    );
    expect(
      ReportReceiptSceneFilter.latestSuppressed.countLabel(summaries),
      'Latest Suppressed (0)',
    );
    expect(
      ReportReceiptSceneFilter.reviewed.countLabel(summaries),
      'Reviewed (2)',
    );
    expect(
      ReportReceiptSceneFilter.suppressed.countLabel(summaries),
      'Suppressed (0)',
    );
    expect(
      ReportReceiptSceneFilter.pending.countLabel(summaries),
      'Pending (2)',
    );
    expect(
      ReportReceiptSceneFilter.all.countLabel(summaries),
      'All Receipts (4)',
    );
  });
}
