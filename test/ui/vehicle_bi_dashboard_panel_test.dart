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

  testWidgets(
    'vehicle BI dashboard panel renders peak hour annotation and exception visits',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleBiDashboardPanel(
              scopeLabel: 'Pharmacy demo',
              throughput: SovereignReportVehicleThroughput(
                totalVisits: 32,
                entryCount: 32,
                serviceCount: 29,
                exitCount: 28,
                completedVisits: 28,
                activeVisits: 3,
                incompleteVisits: 1,
                uniqueVehicles: 24,
                repeatVehicles: 8,
                unknownVehicleEvents: 0,
                peakHourLabel: '17:00-18:00',
                peakHourVisitCount: 9,
                averageCompletedDwellMinutes: 11.8,
                suspiciousShortVisitCount: 1,
                loiteringVisitCount: 1,
                workflowHeadline: '28 completed visits reached EXIT',
                summaryLine:
                    'Visits 32 • Entry 32 • Completed 28 • Active 3 • Incomplete 1 • Unique 24 • Repeat 8',
                hourlyBreakdown: const <int, int>{15: 5, 16: 7, 17: 9, 18: 6},
                exceptionVisits: <SovereignReportVehicleVisitException>[
                  SovereignReportVehicleVisitException(
                    clientId: 'CLIENT-PHARMACY-DEMO',
                    siteId: 'SITE-PHARMACY-01',
                    vehicleLabel: 'CA 918-443',
                    statusLabel: 'WATCH',
                    reasonLabel: 'After-hours loitering',
                    workflowSummary: 'ENTRY -> CURBSIDE BAY (WATCH)',
                    primaryEventId: 'INT-PHARMACY-LOITER-1',
                    startedAtUtc: DateTime.utc(2026, 4, 8, 16, 52),
                    lastSeenAtUtc: DateTime.utc(2026, 4, 8, 17, 21),
                    dwellMinutes: 29,
                    zoneLabels: const <String>[
                      'Curbside Bay',
                      'Rx Collection',
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('vehicle-bi-exception-visits-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('vehicle-bi-peak-hour-summary')),
        findsOneWidget,
      );
      expect(find.text('Peak hour: 17:00-18:00 • 9 visits'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('vehicle-bi-peak-badge-17')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey(
            'vehicle-bi-exception-visit-INT-PHARMACY-LOITER-1',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('After-hours loitering'), findsOneWidget);
      expect(find.text('Curbside Bay • Rx Collection'), findsOneWidget);
    },
  );

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
