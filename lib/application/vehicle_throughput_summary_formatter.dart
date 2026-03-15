import 'vehicle_visit_ledger_projector.dart';

class VehicleThroughputSummaryFormatter {
  const VehicleThroughputSummaryFormatter();

  String format(VehicleThroughputSummary summary) {
    final parts = <String>[
      'Visits ${summary.totalVisits}',
      'Entry ${summary.entryCount}',
      'Completed ${summary.completedCount}',
      'Active ${summary.activeCount}',
      'Incomplete ${summary.incompleteCount}',
      'Unique ${summary.uniqueVehicles}',
    ];
    if (summary.repeatVehicles > 0) {
      parts.add('Repeat ${summary.repeatVehicles}');
    }
    if (summary.averageCompletedDwellMinutes > 0) {
      parts.add(
        'Avg dwell ${summary.averageCompletedDwellMinutes.toStringAsFixed(1)}m',
      );
    }
    if (summary.peakHourVisitCount > 0) {
      parts.add(
        'Peak ${summary.peakHourLabel} (${summary.peakHourVisitCount})',
      );
    }
    if (summary.suspiciousShortVisitCount > 0) {
      parts.add('Short visits ${summary.suspiciousShortVisitCount}');
    }
    if (summary.loiteringVisitCount > 0) {
      parts.add('Loitering ${summary.loiteringVisitCount}');
    }
    if (summary.unknownVehicleEvents > 0) {
      parts.add('Unknown vehicle events ${summary.unknownVehicleEvents}');
    }
    return parts.join(' • ');
  }
}
