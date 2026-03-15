import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_watch_outcome_cue_store.dart';
import 'package:omnix_dashboard/application/monitoring_watch_recovery_policy.dart';
import 'package:omnix_dashboard/application/monitoring_watch_recovery_store.dart';
import 'package:omnix_dashboard/application/monitoring_watch_resync_outcome_recorder.dart';

void main() {
  group('MonitoringWatchResyncOutcomeRecorder', () {
    const recorder = MonitoringWatchResyncOutcomeRecorder(
      outcomeCueStore: MonitoringWatchOutcomeCueStore(),
      recoveryStore: MonitoringWatchRecoveryStore(
        policy: MonitoringWatchRecoveryPolicy(),
      ),
    );

    test('records cue and audit state together for a resync outcome', () {
      final update = recorder.record(
        cueStateByScope: {
          'CLIENT-A|SITE-A': MonitoringWatchOutcomeCueState(
            label: 'Old',
            recordedAtUtc: DateTime.utc(2026, 3, 14, 9, 55),
          ),
        },
        auditHistory: const [
          'Resync • ADMIN • Other Site • Already aligned • 2026-03-14T09:12:00.000Z',
        ],
        scopeKey: 'CLIENT-B|SITE-B',
        siteLabel: 'MS Vallee Residence',
        actor: 'DISPATCH',
        outcome: 'Resynced',
        nowUtc: DateTime.utc(2026, 3, 14, 10, 5),
      );

      expect(update.cueStateByScope.keys, ['CLIENT-B|SITE-B']);
      expect(update.cueStateByScope['CLIENT-B|SITE-B']?.label, 'Resynced');
      expect(update.auditHistory.first, contains('MS Vallee Residence'));
      expect(update.auditHistory.first, contains('DISPATCH'));
      expect(update.auditSummary, update.auditHistory.first);
      expect(update.recoveryState.actor, 'DISPATCH');
      expect(update.recoveryState.outcome, 'Resynced');
    });
  });
}
