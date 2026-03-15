import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/report_generation_service.dart';
import 'package:omnix_dashboard/application/report_receipt_scene_filter.dart';
import 'package:omnix_dashboard/presentation/reports/report_meta_pill.dart';
import 'package:omnix_dashboard/presentation/reports/report_scene_review_pill_builder.dart';

void main() {
  testWidgets('scene review pill builder renders full client summary strip', (
    tester,
  ) async {
    const summary = ReportReceiptSceneReviewSummary(
      includedInReceipt: true,
      totalReviews: 3,
      modelReviews: 2,
      incidentAlerts: 1,
      repeatUpdates: 1,
      escalationCandidates: 1,
      topPosture: 'escalation candidate',
      latestActionBucket: ReportReceiptLatestActionBucket.alerts,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: ReportSceneReviewPillBuilder.build(
              summary: summary,
              pillBuilder: _pill,
              sceneIncludedColor: const Color(0xFF63BDFF),
              scenePendingColor: const Color(0xFF8EA4C2),
              postureColor: const Color(0xFF8EA4C2),
              includeModelCount: true,
              modelColor: const Color(0xFF59D79B),
              includeActionCounts: true,
              incidentAlertColor: const Color(0xFF63BDFF),
              repeatUpdateColor: const Color(0xFFF6C067),
              suppressedColor: const Color(0xFF8EA4C2),
              includeEscalationCount: true,
              escalationAlertColor: const Color(0xFFFF7A7A),
              escalationNeutralColor: const Color(0xFFF6C067),
              includeLatestAction: true,
              includePosture: true,
              uppercasePosture: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Scene 3'), findsOneWidget);
    expect(find.text('Model 2'), findsOneWidget);
    expect(find.text('Alert 1'), findsOneWidget);
    expect(find.text('Repeat 1'), findsOneWidget);
    expect(find.text('Esc 1'), findsOneWidget);
    expect(find.text('Latest Alert'), findsOneWidget);
    expect(find.text('ESCALATION CANDIDATE'), findsOneWidget);
  });

  testWidgets('scene review pill builder renders compact posture strip', (
    tester,
  ) async {
    const summary = ReportReceiptSceneReviewSummary(
      includedInReceipt: true,
      totalReviews: 1,
      modelReviews: 1,
      suppressedActions: 2,
      escalationCandidates: 0,
      topPosture: '',
      latestActionBucket: ReportReceiptLatestActionBucket.suppressed,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: ReportSceneReviewPillBuilder.build(
              summary: summary,
              pillBuilder: _pill,
              sceneIncludedColor: const Color(0xFF7FC7FF),
              scenePendingColor: const Color(0xFF8FA6C8),
              postureColor: const Color(0xFFF6C067),
              includeActionCounts: true,
              suppressedColor: const Color(0xFF8FA6C8),
              includeLatestAction: true,
              includePosture: true,
              posturePrefix: 'Posture ',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Scene 1'), findsOneWidget);
    expect(find.text('Supp 2'), findsOneWidget);
    expect(find.text('Latest Supp'), findsOneWidget);
    expect(find.text('Posture none'), findsOneWidget);
  });

  testWidgets('scene review pill builder normalizes posture prefix spacing', (
    tester,
  ) async {
    const summary = ReportReceiptSceneReviewSummary(
      includedInReceipt: true,
      totalReviews: 1,
      modelReviews: 0,
      escalationCandidates: 0,
      topPosture: 'reviewed',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: ReportSceneReviewPillBuilder.build(
              summary: summary,
              pillBuilder: _pill,
              sceneIncludedColor: const Color(0xFF7FC7FF),
              scenePendingColor: const Color(0xFF8FA6C8),
              postureColor: const Color(0xFFF6C067),
              includePosture: true,
              posturePrefix: '  Posture  ',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Posture reviewed'), findsOneWidget);
    expect(find.text('Posturereviewed'), findsNothing);
  });

  testWidgets('scene review pill builder latest action pill triggers filter callback', (
    tester,
  ) async {
    ReportReceiptSceneFilter? selectedFilter;
    const summary = ReportReceiptSceneReviewSummary(
      includedInReceipt: true,
      totalReviews: 1,
      modelReviews: 1,
      incidentAlerts: 1,
      escalationCandidates: 0,
      topPosture: 'reviewed',
      latestActionBucket: ReportReceiptLatestActionBucket.alerts,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: ReportSceneReviewPillBuilder.build(
              summary: summary,
              pillBuilder: _pill,
              sceneIncludedColor: const Color(0xFF63BDFF),
              scenePendingColor: const Color(0xFF8EA4C2),
              postureColor: const Color(0xFF8EA4C2),
              incidentAlertColor: const Color(0xFF63BDFF),
              includeLatestAction: true,
              onLatestActionFilterTap: (filter) => selectedFilter = filter,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Latest Alert'));
    await tester.pumpAndSettle();

    expect(selectedFilter, ReportReceiptSceneFilter.latestAlerts);
  });

  testWidgets('scene review pill builder marks latest action pill active for matching filter', (
    tester,
  ) async {
    const summary = ReportReceiptSceneReviewSummary(
      includedInReceipt: true,
      totalReviews: 1,
      modelReviews: 1,
      incidentAlerts: 1,
      escalationCandidates: 0,
      topPosture: 'reviewed',
      latestActionBucket: ReportReceiptLatestActionBucket.alerts,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: ReportSceneReviewPillBuilder.build(
              summary: summary,
              pillBuilder: _pill,
              sceneIncludedColor: const Color(0xFF63BDFF),
              scenePendingColor: const Color(0xFF8EA4C2),
              postureColor: const Color(0xFF8EA4C2),
              incidentAlertColor: const Color(0xFF63BDFF),
              includeLatestAction: true,
              activeLatestActionFilter: ReportReceiptSceneFilter.latestAlerts,
            ),
          ),
        ),
      ),
    );

    final latestAlertPill = tester.widget<ReportMetaPill>(
      find.widgetWithText(ReportMetaPill, 'Latest Alert'),
    );
    expect(latestAlertPill.isActive, isTrue);
    expect(
      latestAlertPill.color,
      ReportReceiptSceneFilter.latestAlerts.activeBorderColor,
    );
  });

  testWidgets('scene review pill builder active latest action pill uses shortcut tap', (
    tester,
  ) async {
    ReportReceiptSceneFilter? selectedFilter;
    var shortcutTapCount = 0;
    const summary = ReportReceiptSceneReviewSummary(
      includedInReceipt: true,
      totalReviews: 1,
      modelReviews: 1,
      incidentAlerts: 1,
      escalationCandidates: 0,
      topPosture: 'reviewed',
      latestActionBucket: ReportReceiptLatestActionBucket.alerts,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: ReportSceneReviewPillBuilder.build(
              summary: summary,
              pillBuilder: _pill,
              sceneIncludedColor: const Color(0xFF63BDFF),
              scenePendingColor: const Color(0xFF8EA4C2),
              postureColor: const Color(0xFF8EA4C2),
              incidentAlertColor: const Color(0xFF63BDFF),
              includeLatestAction: true,
              onLatestActionFilterTap: (filter) => selectedFilter = filter,
              onLatestActionActiveTap: () => shortcutTapCount += 1,
              activeLatestActionFilter: ReportReceiptSceneFilter.latestAlerts,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Latest Alert'));
    await tester.pumpAndSettle();

    expect(shortcutTapCount, 1);
    expect(selectedFilter, isNull);
  });
}

Widget _pill(String label, Color color, {bool isActive = false}) {
  return ReportMetaPill(label: label, color: color, isActive: isActive);
}
