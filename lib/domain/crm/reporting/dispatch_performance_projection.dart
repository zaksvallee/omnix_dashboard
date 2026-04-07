import '../../events/dispatch_event.dart';
import '../../events/guard_checked_in.dart';
import '../../events/patrol_completed.dart';
import '../../events/response_arrived.dart';
import 'report_sections.dart';

class DispatchPerformanceProjection {
  // TODO(zaks): Per-contract value — move to client configuration when contract data model is ready.
  static const int _expectedPatrolsPerCheckIn = 8;

  static List<GuardPerformanceSnapshot> buildGuardPerformance({
    required String clientId,
    required String month,
    required List<DispatchEvent> events,
    Map<String, GuardReportingProfile> guardProfilesById = const {},
  }) {
    final checkInsByGuard = <String, int>{};
    final patrolsByGuard = <String, int>{};
    final escalationsByGuard = <String, int>{};

    for (final event in events) {
      if (!_isInMonth(event.occurredAt, month)) continue;

      if (event is GuardCheckedIn && event.clientId == clientId) {
        checkInsByGuard.update(event.guardId, (v) => v + 1, ifAbsent: () => 1);
      }

      if (event is PatrolCompleted && event.clientId == clientId) {
        patrolsByGuard.update(event.guardId, (v) => v + 1, ifAbsent: () => 1);
      }

      if (event is ResponseArrived && event.clientId == clientId) {
        escalationsByGuard.update(
          event.guardId,
          (v) => v + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final guardIds = <String>{
      ...checkInsByGuard.keys,
      ...patrolsByGuard.keys,
      ...escalationsByGuard.keys,
    }.toList()..sort();

    return guardIds
        .map((guardId) {
          final checkIns = checkInsByGuard[guardId] ?? 0;
          final patrols = patrolsByGuard[guardId] ?? 0;
          final profile = guardProfilesById[guardId];
          final expectedPatrols = checkIns * _expectedPatrolsPerCheckIn;
          final baseline = expectedPatrols > patrols
              ? expectedPatrols
              : patrols;
          final compliance = baseline == 0 ? 0.0 : (patrols / baseline) * 100.0;

          return GuardPerformanceSnapshot(
            guardName: profile?.displayName.trim().isNotEmpty == true
                ? profile!.displayName.trim()
                : guardId,
            idNumber: guardId,
            psiraNumber: profile?.psiraNumber.trim() ?? '',
            rank: profile?.rank.trim() ?? '',
            compliancePercentage: compliance,
            escalationsHandled: escalationsByGuard[guardId] ?? 0,
          );
        })
        .toList(growable: false);
  }

  static PatrolPerformanceSnapshot buildPatrolPerformance({
    required String clientId,
    required String month,
    required List<DispatchEvent> events,
  }) {
    var checkIns = 0;
    var completed = 0;

    for (final event in events) {
      if (!_isInMonth(event.occurredAt, month)) continue;

      if (event is GuardCheckedIn && event.clientId == clientId) {
        checkIns += 1;
      }

      if (event is PatrolCompleted && event.clientId == clientId) {
        completed += 1;
      }
    }

    final scheduled = checkIns * _expectedPatrolsPerCheckIn;
    final missed = scheduled > completed ? scheduled - completed : 0;
    final rate = scheduled == 0 ? 0.0 : completed / scheduled;

    return PatrolPerformanceSnapshot(
      scheduledPatrols: scheduled,
      completedPatrols: completed,
      missedPatrols: missed,
      completionRate: rate,
    );
  }

  static bool _isInMonth(DateTime timestamp, String month) {
    final normalized =
        '${timestamp.toUtc().year.toString().padLeft(4, '0')}-${timestamp.toUtc().month.toString().padLeft(2, '0')}';
    return normalized == month;
  }
}
