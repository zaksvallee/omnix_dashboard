import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/morning_sovereign_report_service.dart';

void main() {
  test('pharmacy BI demo fixture parses into a sovereign report', () {
    final raw = File(
      '/Users/zaks/omnix_dashboard/test/fixtures/pharmacy_bi_demo_report.json',
    ).readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final report = SovereignReport.fromJson(
      decoded.map((key, value) => MapEntry(key, value)),
    );

    expect(report.date, '2026-04-06');
    expect(decoded['estimatedRevenue'], 14250);
    expect(decoded['repeatCustomerRate'], '33%');
    expect(report.receiptPolicy.generatedReports, 2);
    expect(report.receiptPolicy.headline, contains('2 BI reports'));
    expect(report.vehicleThroughput.totalVisits, 32);
    expect(report.vehicleThroughput.completedVisits, 28);
    expect(report.vehicleThroughput.repeatVehicles, 8);
    expect(report.vehicleThroughput.peakHourLabel, '17:00-18:00');
    expect(report.vehicleThroughput.peakHourVisitCount, 9);
    expect(report.vehicleThroughput.hourlyBreakdown[17], 9);
    expect(report.vehicleThroughput.scopeBreakdowns.single.siteId, 'SITE-PHARMACY-01');
    expect(report.vehicleThroughput.exceptionVisits, hasLength(2));
    expect(
      report.vehicleThroughput.exceptionVisits
          .map((visit) => visit.reasonLabel)
          .toSet(),
      containsAll(<String>{
        'After-hours loitering',
        'Extended curbside pickup',
      }),
    );
    expect(
      report.vehicleThroughput.exceptionVisits
          .expand((visit) => visit.zoneLabels)
          .toSet(),
      containsAll(<String>{'Curbside Bay', 'Rx Collection', 'Drive-thru'}),
    );
  });
}
