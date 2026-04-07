import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/morning_sovereign_report_service.dart';
import 'package:omnix_dashboard/ui/vehicle_bi_dashboard_panel.dart';

void main() {
  testWidgets('vehicle BI dashboard panel renders cards, chart, and funnel', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VehicleBiDashboardPanel(
            scopeLabel: 'Carwash demo',
            throughput: const SovereignReportVehicleThroughput(
              totalVisits: 24,
              entryCount: 24,
              serviceCount: 18,
              exitCount: 16,
              completedVisits: 16,
              activeVisits: 6,
              incompleteVisits: 2,
              uniqueVehicles: 20,
              repeatVehicles: 5,
              unknownVehicleEvents: 1,
              peakHourLabel: '10:00-11:00',
              peakHourVisitCount: 8,
              averageCompletedDwellMinutes: 14.5,
              suspiciousShortVisitCount: 1,
              loiteringVisitCount: 0,
              workflowHeadline: '16 completed visits reached EXIT',
              summaryLine:
                  'Visits 24 • Entry 24 • Completed 16 • Active 6 • Incomplete 2 • Unique 20 • Repeat 5',
              hourlyBreakdown: <int, int>{8: 4, 9: 7, 10: 8, 11: 5},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vehicle BI dashboard'), findsOneWidget);
    expect(find.text('Carwash demo'), findsOneWidget);
    expect(find.byKey(const ValueKey('vehicle-bi-total-vehicles-card')), findsOneWidget);
    expect(find.text('24'), findsWidgets);
    expect(find.text('14.5 min'), findsOneWidget);
    expect(find.text('25.0%'), findsOneWidget);
    expect(find.byKey(const ValueKey('vehicle-bi-hour-bar-8')), findsOneWidget);
    expect(find.byKey(const ValueKey('vehicle-bi-hour-bar-10')), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.byKey(const ValueKey('vehicle-bi-funnel-entry')), findsOneWidget);
    expect(find.byKey(const ValueKey('vehicle-bi-funnel-service')), findsOneWidget);
    expect(find.byKey(const ValueKey('vehicle-bi-funnel-exit')), findsOneWidget);
    expect(find.text('Entry -> Service -> Exit funnel'), findsOneWidget);
  });

  testWidgets('vehicle BI dashboard panel renders empty hourly state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VehicleBiDashboardPanel(
            throughput: const SovereignReportVehicleThroughput(
              totalVisits: 0,
              completedVisits: 0,
              activeVisits: 0,
              incompleteVisits: 0,
              uniqueVehicles: 0,
              repeatVehicles: 0,
              unknownVehicleEvents: 0,
              peakHourLabel: 'none',
              peakHourVisitCount: 0,
              averageCompletedDwellMinutes: 0,
              suspiciousShortVisitCount: 0,
              loiteringVisitCount: 0,
              workflowHeadline: '',
              summaryLine: '',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No hourly vehicle traffic recorded.'), findsOneWidget);
  });
}
