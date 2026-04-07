import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/morning_sovereign_report_service.dart';

void main() {
  test('carwash BI demo fixture parses into a sovereign report', () {
    final raw = File(
      '/Users/zaks/omnix_dashboard/test/fixtures/carwash_bi_demo_report.json',
    ).readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final report = SovereignReport.fromJson(
      decoded.map((key, value) => MapEntry(key, value)),
    );

    expect(report.date, '2026-04-04');
    expect(decoded['estimatedRevenue'], 3895);
    expect(decoded['repeatCustomerRate'], '27%');
    expect(report.receiptPolicy.generatedReports, 3);
    expect(report.receiptPolicy.governanceHandoffReports, 1);
    expect(report.receiptPolicy.headline, contains('3 BI reports'));
    expect(report.vehicleThroughput.totalVisits, 47);
    expect(report.vehicleThroughput.entryCount, 47);
    expect(report.vehicleThroughput.serviceCount, 43);
    expect(report.vehicleThroughput.exitCount, 41);
    expect(report.vehicleThroughput.repeatVehicles, 10);
    expect(report.vehicleThroughput.suspiciousShortVisitCount, 2);
    expect(report.vehicleThroughput.loiteringVisitCount, 2);
    expect(report.vehicleThroughput.hourlyBreakdown[10], 12);
    expect(report.vehicleThroughput.hourlyBreakdown[11], 10);
    expect(
      report.vehicleThroughput.scopeBreakdowns.single.siteId,
      'SITE-CARWASH-01',
    );
    expect(report.vehicleThroughput.exceptionVisits, hasLength(2));
    expect(
      report.vehicleThroughput.exceptionVisits
          .every((visit) => visit.statusLabel == 'RESOLVED'),
      isTrue,
    );
    expect(
      report.vehicleThroughput.exceptionVisits
          .every((visit) => visit.operatorReviewedAtUtc != null),
      isTrue,
    );
    expect(
      report.vehicleThroughput.exceptionVisits
          .expand((visit) => visit.zoneLabels)
          .toSet(),
      containsAll(<String>{'Wash Bay 1', 'Entry Lane', 'Exit Lane'}),
    );
  });
}
