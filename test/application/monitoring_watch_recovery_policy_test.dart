import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_watch_recovery_policy.dart';

void main() {
  group('MonitoringWatchRecoveryPolicy', () {
    const policy = MonitoringWatchRecoveryPolicy();

    test('expires recovery strictly after the 6 hour window', () {
      final nowUtc = DateTime.utc(2026, 3, 14, 12, 0);

      expect(
        policy.isExpired(
          recordedAtUtc: nowUtc.subtract(
            MonitoringWatchRecoveryPolicy.recoveryWindow,
          ),
          nowUtc: nowUtc,
        ),
        isFalse,
      );
      expect(
        policy.isExpired(
          recordedAtUtc: nowUtc.subtract(
            MonitoringWatchRecoveryPolicy.recoveryWindow +
                const Duration(minutes: 1),
          ),
          nowUtc: nowUtc,
        ),
        isTrue,
      );
    });

    test('formats actor, outcome, and utc time for fleet labels', () {
      expect(
        policy.formatLabel(
          actor: 'ADMIN',
          outcome: 'Resynced',
          recordedAtUtc: DateTime.utc(2026, 3, 14, 10, 8),
        ),
        'ADMIN • Resynced • 10:08 UTC',
      );
    });
  });
}
