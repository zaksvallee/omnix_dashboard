import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/vehicle_visit_ledger_projector.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  group('VehicleVisitLedgerProjector', () {
    const projector = VehicleVisitLedgerProjector();

    test('builds completed and incomplete plate-backed visits by scope', () {
      final snapshots = projector.projectByScope(
        events: [
          _vehicleEvent(
            clientId: 'CLIENT-A',
            siteId: 'SITE-A',
            intelligenceId: 'INTEL-1',
            occurredAt: DateTime.utc(2026, 3, 15, 8, 0),
            plateNumber: 'CA 123456',
            zone: 'Entry Lane',
          ),
          _vehicleEvent(
            clientId: 'CLIENT-A',
            siteId: 'SITE-A',
            intelligenceId: 'INTEL-2',
            occurredAt: DateTime.utc(2026, 3, 15, 8, 9),
            plateNumber: 'CA123456',
            zone: 'Wash Bay 1',
          ),
          _vehicleEvent(
            clientId: 'CLIENT-A',
            siteId: 'SITE-A',
            intelligenceId: 'INTEL-3',
            occurredAt: DateTime.utc(2026, 3, 15, 8, 14),
            plateNumber: 'CA123456',
            zone: 'Exit Lane',
          ),
          _vehicleEvent(
            clientId: 'CLIENT-A',
            siteId: 'SITE-A',
            intelligenceId: 'INTEL-4',
            occurredAt: DateTime.utc(2026, 3, 15, 9, 0),
            plateNumber: 'ND777777',
            zone: 'Entry Gate',
          ),
          _vehicleEvent(
            clientId: 'CLIENT-A',
            siteId: 'SITE-A',
            intelligenceId: 'INTEL-5',
            occurredAt: DateTime.utc(2026, 3, 15, 9, 42),
            plateNumber: '',
            zone: 'Entry Gate',
          ),
        ],
        nowUtc: DateTime.utc(2026, 3, 15, 10, 0),
      );

      final snapshot = snapshots['CLIENT-A|SITE-A'];
      expect(snapshot, isNotNull);
      expect(snapshot!.visits, hasLength(2));

      final latestVisit = snapshot.visits.first;
      expect(latestVisit.plateNumber, 'ND777777');
      expect(
        latestVisit.statusAt(DateTime.utc(2026, 3, 15, 10, 0)),
        VehicleVisitStatus.incomplete,
      );

      final completedVisit = snapshot.visits.last;
      expect(completedVisit.plateNumber, 'CA123456');
      expect(completedVisit.sawEntry, isTrue);
      expect(completedVisit.sawService, isTrue);
      expect(completedVisit.sawExit, isTrue);
      expect(completedVisit.eventCount, 3);
      expect(completedVisit.dwell, const Duration(minutes: 14));

      expect(snapshot.summary.totalVisits, 2);
      expect(snapshot.summary.entryCount, 2);
      expect(snapshot.summary.exitCount, 1);
      expect(snapshot.summary.completedCount, 1);
      expect(snapshot.summary.incompleteCount, 1);
      expect(snapshot.summary.activeCount, 0);
      expect(snapshot.summary.uniqueVehicles, 2);
      expect(snapshot.summary.repeatVehicles, 0);
      expect(snapshot.summary.unknownVehicleEvents, 1);
      expect(snapshot.summary.averageCompletedDwellMinutes, 14);
      expect(snapshot.summary.peakHourLabel, '08:00-09:00');
      expect(snapshot.summary.peakHourVisitCount, 1);
    });

    test('counts repeat vehicles and short visits as anomalies', () {
      final snapshots = projector.projectByScope(
        events: [
          _vehicleEvent(
            clientId: 'CLIENT-A',
            siteId: 'SITE-A',
            intelligenceId: 'INTEL-1',
            occurredAt: DateTime.utc(2026, 3, 15, 8, 0),
            plateNumber: 'CA123456',
            zone: 'Entry Lane',
          ),
          _vehicleEvent(
            clientId: 'CLIENT-A',
            siteId: 'SITE-A',
            intelligenceId: 'INTEL-2',
            occurredAt: DateTime.utc(2026, 3, 15, 8, 1),
            plateNumber: 'CA123456',
            zone: 'Exit Lane',
          ),
          _vehicleEvent(
            clientId: 'CLIENT-A',
            siteId: 'SITE-A',
            intelligenceId: 'INTEL-3',
            occurredAt: DateTime.utc(2026, 3, 15, 11, 0),
            plateNumber: 'CA123456',
            zone: 'Entry Lane',
          ),
          _vehicleEvent(
            clientId: 'CLIENT-A',
            siteId: 'SITE-A',
            intelligenceId: 'INTEL-4',
            occurredAt: DateTime.utc(2026, 3, 15, 11, 45),
            plateNumber: 'CA123456',
            zone: 'Exit Lane',
          ),
        ],
        nowUtc: DateTime.utc(2026, 3, 15, 12, 0),
      );

      final summary = snapshots['CLIENT-A|SITE-A']!.summary;
      expect(summary.totalVisits, 2);
      expect(summary.uniqueVehicles, 1);
      expect(summary.repeatVehicles, 1);
      expect(summary.completedCount, 2);
      expect(summary.suspiciousShortVisitCount, 1);
      expect(summary.loiteringVisitCount, 1);
    });
  });
}

IntelligenceReceived _vehicleEvent({
  required String clientId,
  required String siteId,
  required String intelligenceId,
  required DateTime occurredAt,
  required String plateNumber,
  required String zone,
}) {
  return IntelligenceReceived(
    eventId: 'EVT-$intelligenceId',
    sequence: 1,
    version: 1,
    occurredAt: occurredAt,
    intelligenceId: intelligenceId,
    provider: 'generic_dvr',
    sourceType: 'dvr',
    externalId: 'external-$intelligenceId',
    clientId: clientId,
    regionId: 'REGION-GAUTENG',
    siteId: siteId,
    cameraId: 'CAM-ENTRY',
    zone: zone,
    objectLabel: 'vehicle',
    objectConfidence: 0.94,
    faceMatchId: null,
    faceConfidence: null,
    plateNumber: plateNumber,
    plateConfidence: plateNumber.isEmpty ? null : 98.2,
    headline: 'Vehicle detected',
    summary: 'Vehicle observed in $zone',
    riskScore: 32,
    snapshotUrl: null,
    clipUrl: null,
    canonicalHash: 'hash-$intelligenceId',
    snapshotReferenceHash: null,
    clipReferenceHash: null,
    evidenceRecordHash: null,
  );
}
