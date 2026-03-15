import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/report_generation_service.dart';
import 'package:omnix_dashboard/application/report_receipt_scene_filter.dart';
import 'package:omnix_dashboard/presentation/reports/report_receipt_filter_control.dart';

void main() {
  testWidgets('receipt filter control renders count label and changes value', (
    tester,
  ) async {
    var value = ReportReceiptSceneFilter.all;
    final summaries = [
      const ReportReceiptSceneReviewSummary(
        includedInReceipt: true,
        totalReviews: 1,
        modelReviews: 1,
        escalationCandidates: 0,
        topPosture: 'reviewed',
        latestActionBucket: ReportReceiptLatestActionBucket.alerts,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: ReportReceiptFilterControl(
                dropdownKey: const ValueKey('receipt-filter'),
                value: value,
                onChanged: (next) => setState(() => value = next),
                summaries: summaries,
                iconEnabledColor: const Color(0xFF8EA4C2),
                textColor: const Color(0xFFE8F1FF),
              ),
            );
          },
        ),
      ),
    );

    expect(find.textContaining('All Receipts'), findsOneWidget);
    expect(find.text('All Receipts (1)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('receipt-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Latest Alert').last);
    await tester.pumpAndSettle();

    expect(value, ReportReceiptSceneFilter.latestAlerts);
    expect(find.text('Latest Alert receipts'), findsOneWidget);
  });

  testWidgets('receipt filter control materializes summaries only once', (
    tester,
  ) async {
    var iterationCount = 0;
    final summaries = _SinglePassIterable([
      const ReportReceiptSceneReviewSummary(
        includedInReceipt: true,
        totalReviews: 1,
        modelReviews: 1,
        escalationCandidates: 0,
        topPosture: 'reviewed',
      ),
    ], onIterate: () => iterationCount += 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportReceiptFilterControl(
            value: ReportReceiptSceneFilter.all,
            onChanged: (_) {},
            summaries: summaries,
            iconEnabledColor: const Color(0xFF8EA4C2),
            textColor: const Color(0xFFE8F1FF),
          ),
        ),
      ),
    );

    expect(iterationCount, 1);
    expect(find.textContaining('All Receipts'), findsOneWidget);
  });

  testWidgets('receipt filter control shows subtle active accent for non-all filters', (
    tester,
  ) async {
    const summaries = [
      ReportReceiptSceneReviewSummary(
        includedInReceipt: true,
        totalReviews: 1,
        modelReviews: 1,
        incidentAlerts: 1,
        escalationCandidates: 0,
        topPosture: 'reviewed',
        latestActionBucket: ReportReceiptLatestActionBucket.alerts,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReportReceiptFilterControl(
            value: ReportReceiptSceneFilter.latestAlerts,
            onChanged: _noopOnChanged,
            summaries: summaries,
            iconEnabledColor: Color(0xFF8EA4C2),
            textColor: Color(0xFFE8F1FF),
          ),
        ),
      ),
    );

    final shell = tester.widget<Container>(
      find.byKey(const ValueKey('report-receipt-filter-control-shell')),
    );
    final decoration = shell.decoration! as BoxDecoration;

    expect(
      decoration.color,
      ReportReceiptSceneFilter.latestAlerts.activeBackgroundColor,
    );
    expect(decoration.border, isNotNull);
    expect(
      (decoration.border! as Border).top.color,
      ReportReceiptSceneFilter.latestAlerts.activeBorderColor,
    );
    expect(find.text('Alert receipts'), findsNothing);
    expect(find.text('Latest Alert receipts'), findsOneWidget);
  });

  testWidgets('receipt filter control shows focused shortcut for active latest-action filters', (
    tester,
  ) async {
    var opened = false;
    const summaries = [
      ReportReceiptSceneReviewSummary(
        includedInReceipt: true,
        totalReviews: 1,
        modelReviews: 1,
        incidentAlerts: 1,
        escalationCandidates: 0,
        topPosture: 'reviewed',
        latestActionBucket: ReportReceiptLatestActionBucket.alerts,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportReceiptFilterControl(
            value: ReportReceiptSceneFilter.latestAlerts,
            onChanged: _noopOnChanged,
            summaries: summaries,
            onOpenFocusedReceipt: () => opened = true,
            iconEnabledColor: const Color(0xFF8EA4C2),
            textColor: const Color(0xFFE8F1FF),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('report-receipt-filter-control-open-focused')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('report-receipt-filter-control-open-focused')),
    );
    await tester.pump();

    expect(opened, isTrue);
  });

  test('receipt filter exposes semantic active accent colors by filter family', () {
    expect(
      ReportReceiptSceneFilter.latestAlerts.activeBackgroundColor,
      isNot(ReportReceiptSceneFilter.latestSuppressed.activeBackgroundColor),
    );
    expect(
      ReportReceiptSceneFilter.latestEscalation.activeBorderColor,
      isNot(ReportReceiptSceneFilter.latestRepeat.activeBorderColor),
    );
    expect(
      ReportReceiptSceneFilter.reviewed.activeBorderColor,
      const Color(0xFF4A74A0),
    );
    expect(
      ReportReceiptSceneFilter.pending.activeBackgroundColor,
      const Color(0xFF233042),
    );
  });
}

void _noopOnChanged(ReportReceiptSceneFilter _) {}

class _SinglePassIterable extends Iterable<ReportReceiptSceneReviewSummary?> {
  final List<ReportReceiptSceneReviewSummary?> _items;
  final VoidCallback onIterate;
  bool _iterated = false;

  _SinglePassIterable(this._items, {required this.onIterate});

  @override
  Iterator<ReportReceiptSceneReviewSummary?> get iterator {
    if (_iterated) {
      throw StateError('Iterable consumed more than once.');
    }
    _iterated = true;
    onIterate();
    return _items.iterator;
  }
}
