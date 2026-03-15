import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_shift_schedule_service.dart';
import 'package:omnix_dashboard/application/monitoring_watch_resync_plan_service.dart';

void main() {
  group('MonitoringWatchResyncPlanService', () {
    const service = MonitoringWatchResyncPlanService();
    const schedule = MonitoringShiftSchedule(
      enabled: true,
      startHour: 18,
      startMinute: 0,
      endHour: 6,
      endMinute: 0,
    );

    test('activates when scope is in window but watch is missing', () {
      final snapshot = schedule.snapshotAt(DateTime(2026, 3, 14, 21, 0));
      final plan = service.resolve(
        schedule: schedule,
        snapshot: snapshot,
        nowUtc: DateTime.utc(2026, 3, 14, 19, 0),
        activeWatchStartedAtUtc: null,
      );

      expect(plan.action, MonitoringWatchResyncAction.activate);
      expect(plan.outcome, 'Resynced');
      expect(plan.startedAtUtc, DateTime(2026, 3, 14, 18, 0).toUtc());
    });

    test('does nothing when scope is already aligned in window', () {
      final snapshot = schedule.snapshotAt(DateTime(2026, 3, 14, 21, 0));
      final plan = service.resolve(
        schedule: schedule,
        snapshot: snapshot,
        nowUtc: DateTime.utc(2026, 3, 14, 19, 0),
        activeWatchStartedAtUtc: DateTime.utc(2026, 3, 14, 16, 0),
      );

      expect(plan.action, MonitoringWatchResyncAction.none);
      expect(plan.outcome, 'Already aligned');
    });

    test(
      'deactivates when scope is outside window but watch is still active',
      () {
        final snapshot = schedule.snapshotAt(DateTime(2026, 3, 14, 10, 0));
        final startedAtUtc = DateTime.utc(2026, 3, 13, 16, 0);
        final plan = service.resolve(
          schedule: schedule,
          snapshot: snapshot,
          nowUtc: DateTime.utc(2026, 3, 14, 8, 0),
          activeWatchStartedAtUtc: startedAtUtc,
        );

        expect(plan.action, MonitoringWatchResyncAction.deactivate);
        expect(plan.outcome, 'Resynced');
        expect(
          plan.endedAtUtc,
          schedule.endForWindowStart(startedAtUtc.toLocal())?.toUtc(),
        );
      },
    );

    test('does nothing when scope is already aligned outside window', () {
      final snapshot = schedule.snapshotAt(DateTime(2026, 3, 14, 10, 0));
      final plan = service.resolve(
        schedule: schedule,
        snapshot: snapshot,
        nowUtc: DateTime.utc(2026, 3, 14, 8, 0),
        activeWatchStartedAtUtc: null,
      );

      expect(plan.action, MonitoringWatchResyncAction.none);
      expect(plan.outcome, 'Already aligned');
    });
  });
}
