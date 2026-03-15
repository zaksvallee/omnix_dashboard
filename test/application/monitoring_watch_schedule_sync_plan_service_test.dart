import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_shift_schedule_service.dart';
import 'package:omnix_dashboard/application/monitoring_watch_schedule_sync_plan_service.dart';

void main() {
  group('MonitoringWatchScheduleSyncPlanService', () {
    const service = MonitoringWatchScheduleSyncPlanService();
    const schedule = MonitoringShiftSchedule(
      enabled: true,
      startHour: 18,
      startMinute: 0,
      endHour: 6,
      endMinute: 0,
    );

    test('activates and notifies when start is within five minutes', () {
      final nowLocal = DateTime(2026, 3, 14, 18, 3);
      final snapshot = schedule.snapshotAt(nowLocal);
      final plan = service.resolve(
        schedule: schedule,
        snapshot: snapshot,
        nowLocal: nowLocal,
        nowUtc: nowLocal.toUtc(),
        activeWatchStartedAtUtc: null,
      );

      expect(plan.action, MonitoringWatchScheduleSyncAction.activate);
      expect(plan.startedAtUtc, DateTime(2026, 3, 14, 18, 0).toUtc());
      expect(plan.shouldNotify, isTrue);
    });

    test('activates quietly when start is older than five minutes', () {
      final nowLocal = DateTime(2026, 3, 14, 18, 10);
      final snapshot = schedule.snapshotAt(nowLocal);
      final plan = service.resolve(
        schedule: schedule,
        snapshot: snapshot,
        nowLocal: nowLocal,
        nowUtc: nowLocal.toUtc(),
        activeWatchStartedAtUtc: null,
      );

      expect(plan.action, MonitoringWatchScheduleSyncAction.activate);
      expect(plan.shouldNotify, isFalse);
    });

    test('deactivates active watch outside window', () {
      final nowLocal = DateTime(2026, 3, 14, 10, 0);
      final startedAtUtc = DateTime.utc(2026, 3, 13, 16, 0);
      final snapshot = schedule.snapshotAt(nowLocal);
      final plan = service.resolve(
        schedule: schedule,
        snapshot: snapshot,
        nowLocal: nowLocal,
        nowUtc: nowLocal.toUtc(),
        activeWatchStartedAtUtc: startedAtUtc,
      );

      expect(plan.action, MonitoringWatchScheduleSyncAction.deactivate);
      expect(
        plan.endedAtUtc,
        schedule.endForWindowStart(startedAtUtc.toLocal())?.toUtc(),
      );
      expect(plan.shouldNotify, isTrue);
    });

    test('does nothing when aligned', () {
      final nowLocal = DateTime(2026, 3, 14, 10, 0);
      final snapshot = schedule.snapshotAt(nowLocal);
      final plan = service.resolve(
        schedule: schedule,
        snapshot: snapshot,
        nowLocal: nowLocal,
        nowUtc: nowLocal.toUtc(),
        activeWatchStartedAtUtc: null,
      );

      expect(plan.action, MonitoringWatchScheduleSyncAction.none);
      expect(plan.startedAtUtc, isNull);
      expect(plan.endedAtUtc, isNull);
      expect(plan.shouldNotify, isFalse);
    });
  });
}
