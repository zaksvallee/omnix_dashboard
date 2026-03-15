import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/report_receipt_scene_filter.dart';
import 'package:omnix_dashboard/presentation/reports/report_receipt_filter_banner.dart';

void main() {
  testWidgets('receipt filter banner shows status counts and triggers show all', (
    tester,
  ) async {
    var cleared = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportReceiptFilterBanner(
            filter: ReportReceiptSceneFilter.escalation,
            filteredRows: 2,
            totalRows: 5,
            onShowAll: () => cleared = true,
          ),
        ),
      ),
    );

    expect(find.text('Viewing Escalation receipts (2/5)'), findsOneWidget);

    await tester.tap(find.text('Show All'));
    await tester.pump();

    expect(cleared, isTrue);
  });

  testWidgets('receipt filter banner uses shared filter viewing copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ReportReceiptFilterBanner(
                filter: ReportReceiptSceneFilter.reviewed,
                filteredRows: 1,
                totalRows: 3,
                onShowAll: () {},
              ),
              ReportReceiptFilterBanner(
                filter: ReportReceiptSceneFilter.latestSuppressed,
                filteredRows: 0,
                totalRows: 3,
                onShowAll: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Viewing Reviewed receipts (1/3)'), findsOneWidget);
    expect(
      find.text('Viewing Latest Suppressed receipts (0/3)'),
      findsOneWidget,
    );
  });

  testWidgets('receipt filter banner uses semantic tint from filter family', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReportReceiptFilterBanner(
            filter: ReportReceiptSceneFilter.latestEscalation,
            filteredRows: 1,
            totalRows: 2,
            onShowAll: _noopOnShowAll,
          ),
        ),
      ),
    );

    final shell = tester.widget<Container>(
      find.byKey(const ValueKey('report-receipt-filter-banner-shell')),
    );
    final decoration = shell.decoration! as BoxDecoration;

    expect(
      decoration.color,
      ReportReceiptSceneFilter.latestEscalation.bannerBackgroundColor,
    );
    expect(
      (decoration.border! as Border).top.color,
      ReportReceiptSceneFilter.latestEscalation.bannerBorderColor,
    );
  });

  testWidgets('receipt filter banner shows focused shortcut for latest-action filters', (
    tester,
  ) async {
    var opened = false;
    var copied = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportReceiptFilterBanner(
            filter: ReportReceiptSceneFilter.latestAlerts,
            filteredRows: 1,
            totalRows: 2,
            onOpenFocusedReceipt: () => opened = true,
            onCopyFocusedReceipt: () => copied = true,
            onShowAll: () {},
          ),
        ),
      ),
    );

    expect(find.text('Open Focused Receipt'), findsOneWidget);
    expect(find.text('Copy Focused Receipt'), findsOneWidget);

    await tester.tap(find.text('Open Focused Receipt'));
    await tester.pump();

    expect(opened, isTrue);

    await tester.tap(find.text('Copy Focused Receipt'));
    await tester.pump();

    expect(copied, isTrue);
  });
}

void _noopOnShowAll() {}
