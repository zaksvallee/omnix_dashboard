import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/crm/reporting/dispatch_performance_projection.dart';
import 'package:omnix_dashboard/domain/crm/reporting/report_sections.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/guard_checked_in.dart';
import 'package:omnix_dashboard/domain/events/patrol_completed.dart';
import 'package:omnix_dashboard/domain/events/response_arrived.dart';

void main() {
  group('DispatchPerformanceProjection.buildGuardPerformance', () {
    test('omits fabricated compliance identifiers when directory data is missing', () {
      final snapshots = DispatchPerformanceProjection.buildGuardPerformance(
        clientId: 'CLIENT-1',
        month: '2026-04',
        events: _eventsForGuard('G-001'),
      );

      expect(snapshots, hasLength(1));
      expect(snapshots.first.guardName, 'G-001');
      expect(snapshots.first.idNumber, 'G-001');
      expect(snapshots.first.psiraNumber, isEmpty);
      expect(snapshots.first.rank, isEmpty);
      expect(snapshots.first.escalationsHandled, 1);
    });

    test('uses real guard directory data when it is available', () {
      final snapshots = DispatchPerformanceProjection.buildGuardPerformance(
        clientId: 'CLIENT-1',
        month: '2026-04',
        events: _eventsForGuard('G-001'),
        guardProfilesById: const <String, GuardReportingProfile>{
          'G-001': GuardReportingProfile(
            guardId: 'G-001',
            displayName: 'Lebo Mokoena',
            psiraNumber: 'PSIRA-441',
            rank: 'Supervisor',
          ),
        },
      );

      expect(snapshots, hasLength(1));
      expect(snapshots.first.guardName, 'Lebo Mokoena');
      expect(snapshots.first.idNumber, 'G-001');
      expect(snapshots.first.psiraNumber, 'PSIRA-441');
      expect(snapshots.first.rank, 'Supervisor');
    });
  });
}

List<DispatchEvent> _eventsForGuard(String guardId) {
  return <DispatchEvent>[
    GuardCheckedIn(
      eventId: 'evt-checkin',
      sequence: 1,
      version: 1,
      occurredAt: DateTime.utc(2026, 4, 7, 8, 0),
      guardId: guardId,
      clientId: 'CLIENT-1',
      regionId: 'REGION-1',
      siteId: 'SITE-1',
    ),
    PatrolCompleted(
      eventId: 'evt-patrol-1',
      sequence: 2,
      version: 1,
      occurredAt: DateTime.utc(2026, 4, 7, 8, 15),
      guardId: guardId,
      routeId: 'ROUTE-1',
      clientId: 'CLIENT-1',
      regionId: 'REGION-1',
      siteId: 'SITE-1',
      durationSeconds: 900,
    ),
    PatrolCompleted(
      eventId: 'evt-patrol-2',
      sequence: 3,
      version: 1,
      occurredAt: DateTime.utc(2026, 4, 7, 8, 30),
      guardId: guardId,
      routeId: 'ROUTE-1',
      clientId: 'CLIENT-1',
      regionId: 'REGION-1',
      siteId: 'SITE-1',
      durationSeconds: 900,
    ),
    ResponseArrived(
      eventId: 'evt-response',
      sequence: 4,
      version: 1,
      occurredAt: DateTime.utc(2026, 4, 7, 8, 45),
      dispatchId: 'DSP-1',
      guardId: guardId,
      clientId: 'CLIENT-1',
      regionId: 'REGION-1',
      siteId: 'SITE-1',
    ),
  ];
}
