import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_watch_outcome_cue_store.dart';

void main() {
  group('MonitoringWatchOutcomeCueStore', () {
    const store = MonitoringWatchOutcomeCueStore();

    test('returns label only while cue is inside the 5 minute window', () {
      expect(
        store.labelForState(
          state: MonitoringWatchOutcomeCueState(
            label: 'Resynced',
            recordedAtUtc: DateTime.utc(2026, 3, 14, 10, 0),
          ),
          nowUtc: DateTime.utc(2026, 3, 14, 10, 5),
        ),
        'Resynced',
      );
      expect(
        store.labelForState(
          state: MonitoringWatchOutcomeCueState(
            label: 'Resynced',
            recordedAtUtc: DateTime.utc(2026, 3, 14, 10, 0),
          ),
          nowUtc: DateTime.utc(2026, 3, 14, 10, 6),
        ),
        isNull,
      );
    });

    test('prunes expired cue entries from runtime state', () {
      final fresh = store.freshState(
        stateByScope: {
          'CLIENT-A|SITE-A': MonitoringWatchOutcomeCueState(
            label: 'Resynced',
            recordedAtUtc: DateTime.utc(2026, 3, 14, 10, 2),
          ),
          'CLIENT-B|SITE-B': MonitoringWatchOutcomeCueState(
            label: 'Already aligned',
            recordedAtUtc: DateTime.utc(2026, 3, 14, 9, 55),
          ),
        },
        nowUtc: DateTime.utc(2026, 3, 14, 10, 5),
      );

      expect(fresh.keys, ['CLIENT-A|SITE-A']);
    });

    test('records cue after pruning stale entries and trims the label', () {
      final update = store.recordCue(
        stateByScope: {
          'CLIENT-A|SITE-A': MonitoringWatchOutcomeCueState(
            label: 'Old',
            recordedAtUtc: DateTime.utc(2026, 3, 14, 9, 55),
          ),
        },
        scopeKey: 'CLIENT-B|SITE-B',
        label: ' Resynced ',
        nowUtc: DateTime.utc(2026, 3, 14, 10, 5),
      );

      expect(update.changed, isTrue);
      expect(update.stateByScope.keys, ['CLIENT-B|SITE-B']);
      expect(update.stateByScope['CLIENT-B|SITE-B']?.label, 'Resynced');
    });

    test('ignores blank cue labels while still pruning stale entries', () {
      final update = store.recordCue(
        stateByScope: {
          'CLIENT-A|SITE-A': MonitoringWatchOutcomeCueState(
            label: 'Old',
            recordedAtUtc: DateTime.utc(2026, 3, 14, 9, 55),
          ),
        },
        scopeKey: 'CLIENT-B|SITE-B',
        label: '   ',
        nowUtc: DateTime.utc(2026, 3, 14, 10, 5),
      );

      expect(update.changed, isFalse);
      expect(update.stateByScope, isEmpty);
    });
  });
}
