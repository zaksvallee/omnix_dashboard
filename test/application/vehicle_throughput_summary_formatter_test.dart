import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/vehicle_throughput_summary_formatter.dart';
import 'package:omnix_dashboard/application/vehicle_visit_ledger_projector.dart';

void main() {
  group('VehicleThroughputSummaryFormatter', () {
    const formatter = VehicleThroughputSummaryFormatter();

    test('formats throughput summary with operational highlights', () {
      final output = formatter.format(
        const VehicleThroughputSummary(
          totalVisits: 46,
          entryCount: 46,
          exitCount: 43,
          completedCount: 43,
          activeCount: 1,
          incompleteCount: 2,
          uniqueVehicles: 41,
          repeatVehicles: 5,
          unknownVehicleEvents: 3,
          averageCompletedDwellMinutes: 12.4,
          peakHourLabel: '11:00-12:00',
          peakHourVisitCount: 8,
          suspiciousShortVisitCount: 2,
          loiteringVisitCount: 1,
        ),
      );

      expect(
        output,
        'Visits 46 • Entry 46 • Completed 43 • Active 1 • Incomplete 2 • Unique 41 • Repeat 5 • Avg dwell 12.4m • Peak 11:00-12:00 (8) • Short visits 2 • Loitering 1 • Unknown vehicle events 3',
      );
    });
  });
}
