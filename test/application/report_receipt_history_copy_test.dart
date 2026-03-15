import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/report_receipt_history_copy.dart';
import 'package:omnix_dashboard/application/report_receipt_scene_filter.dart';

void main() {
  test('pageSubtitle returns scope only for all filter', () {
    expect(
      ReportReceiptHistoryCopy.pageSubtitle(
        scopeLabel: 'CLIENT-1 • SITE-1',
        filter: ReportReceiptSceneFilter.all,
      ),
      'CLIENT-1 • SITE-1',
    );
  });

  test('pageSubtitle appends active receipt filter label', () {
    expect(
      ReportReceiptHistoryCopy.pageSubtitle(
        scopeLabel: 'CLIENT-1 • SITE-1',
        filter: ReportReceiptSceneFilter.escalation,
      ),
      'CLIENT-1 • SITE-1 • Escalation receipts',
    );
  });

  test('pageSubtitle trims scope copy and avoids leading separator when blank', () {
    expect(
      ReportReceiptHistoryCopy.pageSubtitle(
        scopeLabel: '  CLIENT-1 • SITE-1  ',
        filter: ReportReceiptSceneFilter.reviewed,
      ),
      'CLIENT-1 • SITE-1 • Reviewed receipts',
    );

    expect(
      ReportReceiptHistoryCopy.pageSubtitle(
        scopeLabel: '   ',
        filter: ReportReceiptSceneFilter.reviewed,
      ),
      'Reviewed receipts',
    );
  });

  test('historySubtitle returns base copy for all filter', () {
    expect(
      ReportReceiptHistoryCopy.historySubtitle(
        base: 'Open generated receipts.',
        filter: ReportReceiptSceneFilter.all,
      ),
      'Open generated receipts.',
    );
  });

  test('historySubtitle adds lowercase viewing copy for active filter', () {
    expect(
      ReportReceiptHistoryCopy.historySubtitle(
        base: 'Open generated receipts.',
        filter: ReportReceiptSceneFilter.pending,
      ),
      'Open generated receipts. Viewing Scene Pending receipts.',
    );
  });

  test('historySubtitle trims base copy and avoids awkward blank-prefix output', () {
    expect(
      ReportReceiptHistoryCopy.historySubtitle(
        base: '  Open generated receipts.  ',
        filter: ReportReceiptSceneFilter.pending,
      ),
      'Open generated receipts. Viewing Scene Pending receipts.',
    );

    expect(
      ReportReceiptHistoryCopy.historySubtitle(
        base: '   ',
        filter: ReportReceiptSceneFilter.pending,
      ),
      'Viewing Scene Pending receipts.',
    );
  });
}
