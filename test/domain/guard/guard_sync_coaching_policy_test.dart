import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/guard/guard_ops_event.dart';
import 'package:omnix_dashboard/domain/guard/guard_sync_coaching_policy.dart';

void main() {
  final policy = const GuardSyncCoachingPolicy();
  final now = DateTime.utc(2026, 3, 5, 10, 0);

  GuardOpsEvent wearableAt(DateTime at) => GuardOpsEvent(
    eventId: 'EVT-${at.millisecondsSinceEpoch}',
    guardId: 'GUARD-001',
    siteId: 'SITE-SANDTON',
    shiftId: 'SHIFT-1',
    eventType: GuardOpsEventType.wearableHeartbeat,
    sequence: 1,
    occurredAt: at,
    deviceId: 'DEVICE-1',
    appVersion: '1.0.0',
    payload: const {},
  );

  GuardOpsEvent shiftStartAt(DateTime at) => GuardOpsEvent(
    eventId: 'SHIFT-START-${at.millisecondsSinceEpoch}',
    guardId: 'GUARD-001',
    siteId: 'SITE-SANDTON',
    shiftId: 'SHIFT-1',
    eventType: GuardOpsEventType.shiftStart,
    sequence: 1,
    occurredAt: at,
    deviceId: 'DEVICE-1',
    appVersion: '1.0.0',
    payload: const {},
  );

  GuardOpsEvent shiftEndAt(DateTime at) => GuardOpsEvent(
    eventId: 'SHIFT-END-${at.millisecondsSinceEpoch}',
    guardId: 'GUARD-001',
    siteId: 'SITE-SANDTON',
    shiftId: 'SHIFT-1',
    eventType: GuardOpsEventType.shiftEnd,
    sequence: 2,
    occurredAt: at,
    deviceId: 'DEVICE-1',
    appVersion: '1.0.0',
    payload: const {},
  );

  test('returns local-only coaching when backend is disabled', () {
    final prompt = policy.evaluate(
      syncBackendEnabled: false,
      pendingEventCount: 0,
      pendingMediaCount: 0,
      failedEventCount: 0,
      failedMediaCount: 0,
      recentEvents: const [],
      nowUtc: now,
    );
    expect(prompt.ruleId, 'local_only_backend');
    expect(prompt.priority, GuardCoachingPriority.medium);
  });

  test('returns failure backlog coaching at high failure counts', () {
    final prompt = policy.evaluate(
      syncBackendEnabled: true,
      pendingEventCount: 0,
      pendingMediaCount: 0,
      failedEventCount: 2,
      failedMediaCount: 1,
      recentEvents: const [],
      nowUtc: now,
    );
    expect(prompt.ruleId, 'high_failure_backlog');
    expect(prompt.priority, GuardCoachingPriority.high);
  });

  test('returns wearable stale coaching when heartbeat is missing', () {
    final prompt = policy.evaluate(
      syncBackendEnabled: true,
      pendingEventCount: 1,
      pendingMediaCount: 1,
      failedEventCount: 0,
      failedMediaCount: 0,
      recentEvents: [wearableAt(now.subtract(const Duration(hours: 2)))],
      nowUtc: now,
    );
    expect(prompt.ruleId, 'wearable_stale');
    expect(prompt.priority, GuardCoachingPriority.medium);
  });

  test('returns open-shift coaching when shift start has no close event', () {
    final prompt = policy.evaluate(
      syncBackendEnabled: true,
      pendingEventCount: 0,
      pendingMediaCount: 0,
      failedEventCount: 0,
      failedMediaCount: 0,
      recentEvents: [
        shiftStartAt(now.subtract(const Duration(hours: 13))),
        wearableAt(now.subtract(const Duration(minutes: 5))),
      ],
      nowUtc: now,
    );
    expect(prompt.ruleId, 'shift_open_without_end');
    expect(prompt.priority, GuardCoachingPriority.medium);
  });

  test('does not return open-shift coaching when shift is closed', () {
    final prompt = policy.evaluate(
      syncBackendEnabled: true,
      pendingEventCount: 0,
      pendingMediaCount: 0,
      failedEventCount: 0,
      failedMediaCount: 0,
      recentEvents: [
        shiftStartAt(now.subtract(const Duration(hours: 13))),
        shiftEndAt(now.subtract(const Duration(hours: 1))),
        wearableAt(now.subtract(const Duration(minutes: 5))),
      ],
      nowUtc: now,
    );
    expect(prompt.ruleId, 'steady_state');
  });

  test('returns steady-state coaching when signals are healthy', () {
    final prompt = policy.evaluate(
      syncBackendEnabled: true,
      pendingEventCount: 1,
      pendingMediaCount: 1,
      failedEventCount: 0,
      failedMediaCount: 0,
      recentEvents: [wearableAt(now.subtract(const Duration(minutes: 10)))],
      nowUtc: now,
    );
    expect(prompt.ruleId, 'steady_state');
    expect(prompt.priority, GuardCoachingPriority.low);
  });

  test('snooze rules require supervisor for high-priority prompts', () {
    const highPrompt = GuardCoachingPrompt(
      ruleId: 'high_failure_backlog',
      headline: 'Resolve Sync Failures',
      message: 'High backlog',
      priority: GuardCoachingPriority.high,
    );
    expect(
      policy.canSnooze(
        prompt: highPrompt,
        actorRole: GuardCoachingActorRole.guard,
      ),
      isFalse,
    );
    expect(
      policy.canSnooze(
        prompt: highPrompt,
        actorRole: GuardCoachingActorRole.supervisor,
      ),
      isTrue,
    );
  });
}
