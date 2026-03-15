import 'monitoring_shift_schedule_service.dart';

enum MonitoringWatchResyncAction { none, activate, deactivate }

class MonitoringWatchResyncPlan {
  final MonitoringWatchResyncAction action;
  final String outcome;
  final DateTime? startedAtUtc;
  final DateTime? endedAtUtc;

  const MonitoringWatchResyncPlan({
    required this.action,
    required this.outcome,
    this.startedAtUtc,
    this.endedAtUtc,
  });
}

class MonitoringWatchResyncPlanService {
  const MonitoringWatchResyncPlanService();

  MonitoringWatchResyncPlan resolve({
    required MonitoringShiftSchedule schedule,
    required MonitoringShiftScheduleSnapshot snapshot,
    required DateTime nowUtc,
    required DateTime? activeWatchStartedAtUtc,
  }) {
    if (snapshot.active) {
      final windowStartLocal = snapshot.windowStartLocal;
      if (activeWatchStartedAtUtc == null && windowStartLocal != null) {
        return MonitoringWatchResyncPlan(
          action: MonitoringWatchResyncAction.activate,
          outcome: 'Resynced',
          startedAtUtc: windowStartLocal.toUtc(),
        );
      }
      return const MonitoringWatchResyncPlan(
        action: MonitoringWatchResyncAction.none,
        outcome: 'Already aligned',
      );
    }
    if (activeWatchStartedAtUtc != null) {
      return MonitoringWatchResyncPlan(
        action: MonitoringWatchResyncAction.deactivate,
        outcome: 'Resynced',
        endedAtUtc:
            schedule
                .endForWindowStart(activeWatchStartedAtUtc.toLocal())
                ?.toUtc() ??
            nowUtc,
      );
    }
    return const MonitoringWatchResyncPlan(
      action: MonitoringWatchResyncAction.none,
      outcome: 'Already aligned',
    );
  }
}
