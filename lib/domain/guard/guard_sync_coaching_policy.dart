import 'guard_ops_event.dart';

enum GuardCoachingPriority { low, medium, high }

enum GuardCoachingActorRole { guard, supervisor }

class GuardCoachingPrompt {
  final String ruleId;
  final String headline;
  final String message;
  final GuardCoachingPriority priority;

  const GuardCoachingPrompt({
    required this.ruleId,
    required this.headline,
    required this.message,
    required this.priority,
  });
}

class GuardSyncCoachingPolicy {
  const GuardSyncCoachingPolicy();

  bool canSnooze({
    required GuardCoachingPrompt prompt,
    required GuardCoachingActorRole actorRole,
  }) {
    switch (prompt.priority) {
      case GuardCoachingPriority.low:
      case GuardCoachingPriority.medium:
        return true;
      case GuardCoachingPriority.high:
        return actorRole == GuardCoachingActorRole.supervisor;
    }
  }

  Duration defaultSnoozeWindow(GuardCoachingPrompt prompt) {
    switch (prompt.priority) {
      case GuardCoachingPriority.low:
        return const Duration(minutes: 20);
      case GuardCoachingPriority.medium:
        return const Duration(minutes: 15);
      case GuardCoachingPriority.high:
        return const Duration(minutes: 10);
    }
  }

  GuardCoachingPrompt evaluate({
    required bool syncBackendEnabled,
    required int pendingEventCount,
    required int pendingMediaCount,
    required int failedEventCount,
    required int failedMediaCount,
    required List<GuardOpsEvent> recentEvents,
    required DateTime nowUtc,
  }) {
    if (!syncBackendEnabled) {
      return const GuardCoachingPrompt(
        ruleId: 'local_only_backend',
        headline: 'Local Sync Mode',
        message:
            'Backend sync is disabled. Keep queue depth low and escalate to control if this persists.',
        priority: GuardCoachingPriority.medium,
      );
    }

    final totalFailed = failedEventCount + failedMediaCount;
    if (totalFailed >= 3) {
      return const GuardCoachingPrompt(
        ruleId: 'high_failure_backlog',
        headline: 'Resolve Sync Failures',
        message:
            'High failure backlog detected. Retry failed rows and notify control before closing patrol cycle.',
        priority: GuardCoachingPriority.high,
      );
    }

    final totalPending = pendingEventCount + pendingMediaCount;
    if (totalPending >= 12) {
      return const GuardCoachingPrompt(
        ruleId: 'queue_pressure',
        headline: 'Queue Pressure Rising',
        message:
            'Queue depth is rising. Trigger manual sync and confirm network quality in your patrol zone.',
        priority: GuardCoachingPriority.medium,
      );
    }

    final latestShiftStart = recentEvents
        .where((event) => event.eventType == GuardOpsEventType.shiftStart)
        .map((event) => event.occurredAt.toUtc())
        .fold<DateTime?>(
          null,
          (latest, current) =>
              latest == null || current.isAfter(latest) ? current : latest,
        );
    final latestShiftEnd = recentEvents
        .where((event) => event.eventType == GuardOpsEventType.shiftEnd)
        .map((event) => event.occurredAt.toUtc())
        .fold<DateTime?>(
          null,
          (latest, current) =>
              latest == null || current.isAfter(latest) ? current : latest,
        );
    final hasOpenShift =
        latestShiftStart != null &&
        (latestShiftEnd == null || latestShiftStart.isAfter(latestShiftEnd));
    if (hasOpenShift &&
        nowUtc.difference(latestShiftStart) > const Duration(hours: 12)) {
      return const GuardCoachingPrompt(
        ruleId: 'shift_open_without_end',
        headline: 'Close Guard Shift',
        message:
            'Shift start is still open without a closing event. Queue SHIFT_END or escalate to control.',
        priority: GuardCoachingPriority.medium,
      );
    }

    final latestWearable = recentEvents
        .where(
          (event) => event.eventType == GuardOpsEventType.wearableHeartbeat,
        )
        .map((event) => event.occurredAt)
        .fold<DateTime?>(
          null,
          (latest, current) =>
              latest == null || current.isAfter(latest) ? current : latest,
        );
    if (latestWearable == null ||
        nowUtc.difference(latestWearable.toUtc()) >
            const Duration(minutes: 30)) {
      return const GuardCoachingPrompt(
        ruleId: 'wearable_stale',
        headline: 'Refresh Wearable Telemetry',
        message:
            'No recent wearable heartbeat. Queue a wearable heartbeat to keep welfare supervision current.',
        priority: GuardCoachingPriority.medium,
      );
    }

    return const GuardCoachingPrompt(
      ruleId: 'steady_state',
      headline: 'Sync Steady',
      message:
          'Sync lane is healthy. Continue checkpoint cadence and keep telemetry flowing.',
      priority: GuardCoachingPriority.low,
    );
  }
}
