import 'monitoring_shift_schedule_service.dart';

enum MonitoringWatchScheduleSyncAction { none, activate, deactivate }

class MonitoringWatchScheduleSyncPlan {
  final MonitoringWatchScheduleSyncAction action;
  final DateTime? startedAtUtc;
  final DateTime? endedAtUtc;
  final bool shouldNotify;

  const MonitoringWatchScheduleSyncPlan({
    required this.action,
    this.startedAtUtc,
    this.endedAtUtc,
    this.shouldNotify = false,
  });
}

class MonitoringWatchScheduleSyncPlanService {
  const MonitoringWatchScheduleSyncPlanService();

  MonitoringWatchScheduleSyncPlan resolve({
    required MonitoringShiftSchedule schedule,
    required MonitoringShiftScheduleSnapshot snapshot,
    required DateTime nowLocal,
    required DateTime nowUtc,
    required DateTime? activeWatchStartedAtUtc,
  }) {
    if (snapshot.active) {
      final windowStartLocal = snapshot.windowStartLocal;
      if (activeWatchStartedAtUtc == null && windowStartLocal != null) {
        final shouldNotify =
            nowLocal.difference(windowStartLocal) <=
                const Duration(minutes: 5) &&
            !nowLocal.isBefore(windowStartLocal);
        return MonitoringWatchScheduleSyncPlan(
          action: MonitoringWatchScheduleSyncAction.activate,
          startedAtUtc: windowStartLocal.toUtc(),
          shouldNotify: shouldNotify,
        );
      }
      return const MonitoringWatchScheduleSyncPlan(
        action: MonitoringWatchScheduleSyncAction.none,
      );
    }
    if (activeWatchStartedAtUtc != null) {
      return MonitoringWatchScheduleSyncPlan(
        action: MonitoringWatchScheduleSyncAction.deactivate,
        endedAtUtc:
            schedule
                .endForWindowStart(activeWatchStartedAtUtc.toLocal())
                ?.toUtc() ??
            nowUtc,
        shouldNotify: true,
      );
    }
    return const MonitoringWatchScheduleSyncPlan(
      action: MonitoringWatchScheduleSyncAction.none,
    );
  }
}
