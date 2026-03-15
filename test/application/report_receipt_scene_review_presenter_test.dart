import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/report_generation_service.dart';
import 'package:omnix_dashboard/application/report_receipt_scene_review_presenter.dart';

void main() {
  test('scene review presenter returns escalation accent for escalation receipts', () {
    const summary = ReportReceiptSceneReviewSummary(
      includedInReceipt: true,
      totalReviews: 3,
      modelReviews: 2,
      incidentAlerts: 1,
      repeatUpdates: 1,
      escalationCandidates: 1,
      topPosture: 'escalation candidate',
    );

    final color = ReportReceiptSceneReviewPresenter.accent(
      summary,
      neutralColor: const Color(0xFF111111),
      reviewedColor: const Color(0xFF222222),
      escalationColor: const Color(0xFF333333),
    );

    expect(color, const Color(0xFF333333));
    expect(
      ReportReceiptSceneReviewPresenter.narrative(summary),
      'Scene review flagged 1 escalation candidate in this report with 1 alert and 1 repeat update.',
    );
  });

  test('scene review presenter returns neutral narrative for pending schema', () {
    const summary = ReportReceiptSceneReviewSummary(
      includedInReceipt: false,
      totalReviews: 0,
      modelReviews: 0,
      suppressedActions: 0,
      incidentAlerts: 0,
      repeatUpdates: 0,
      escalationCandidates: 0,
      topPosture: 'pending',
    );

    final color = ReportReceiptSceneReviewPresenter.accent(
      summary,
      neutralColor: const Color(0xFF111111),
      reviewedColor: const Color(0xFF222222),
      escalationColor: const Color(0xFF333333),
    );

    expect(color, const Color(0xFF111111));
    expect(
      ReportReceiptSceneReviewPresenter.narrative(summary),
      'Scene review metrics are not embedded in this receipt schema yet.',
    );
  });

  test('scene review presenter returns reviewed narrative without escalation', () {
    const summary = ReportReceiptSceneReviewSummary(
      includedInReceipt: true,
      totalReviews: 3,
      modelReviews: 2,
      suppressedActions: 2,
      incidentAlerts: 1,
      escalationCandidates: 0,
      topPosture: 'reviewed',
      latestActionTaken:
          '2026-03-14T21:14:00.000Z • Camera 1 • Monitoring Alert • Vehicle remained visible in the monitored driveway.',
      latestSuppressedPattern:
          '2026-03-14T21:16:00.000Z • Camera 3 • Vehicle remained below escalation threshold.',
    );

    final color = ReportReceiptSceneReviewPresenter.accent(
      summary,
      neutralColor: const Color(0xFF111111),
      reviewedColor: const Color(0xFF222222),
      escalationColor: const Color(0xFF333333),
    );

    expect(color, const Color(0xFF222222));
    expect(
      ReportReceiptSceneReviewPresenter.narrative(summary),
      'Scene review stayed below escalation threshold across 3 reviewed CCTV events with 1 alert and 2 suppressed reviews. Latest action taken: 2026-03-14T21:14:00.000Z • Camera 1 • Monitoring Alert • Vehicle remained visible in the monitored driveway.',
    );
  });
}
