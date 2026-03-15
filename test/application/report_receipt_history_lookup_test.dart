import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/report_receipt_history_lookup.dart';

void main() {
  test('findByEventId returns null when event id is absent', () {
    final rows = [
      ('RPT-1', 'one'),
      ('RPT-2', 'two'),
    ];

    final match = ReportReceiptHistoryLookup.findByEventId<(String, String)>(
      rows,
      null,
      (row) => row.$1,
    );

    expect(match, isNull);
  });

  test('findByEventId returns matching row when present', () {
    final rows = [
      ('RPT-1', 'one'),
      ('RPT-2', 'two'),
    ];

    final match = ReportReceiptHistoryLookup.findByEventId<(String, String)>(
      rows,
      'RPT-2',
      (row) => row.$1,
    );

    expect(match, ('RPT-2', 'two'));
  });

  test('findByEventId ignores surrounding whitespace in lookup and row ids', () {
    final rows = [
      (' RPT-1 ', 'one'),
      ('RPT-2', 'two'),
    ];

    final match = ReportReceiptHistoryLookup.findByEventId<(String, String)>(
      rows,
      '  RPT-1  ',
      (row) => row.$1,
    );

    expect(match, (' RPT-1 ', 'one'));
  });
}
