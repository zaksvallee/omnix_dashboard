import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_watch_recovery_policy.dart';
import 'package:omnix_dashboard/application/monitoring_watch_recovery_store.dart';

void main() {
  group('MonitoringWatchRecoveryStore', () {
    const store = MonitoringWatchRecoveryStore(
      policy: MonitoringWatchRecoveryPolicy(),
    );

    test('parses persisted state and drops stale entries', () {
      final hydrated = store.parsePersistedState(
        raw: <String, Object?>{
          'CLIENT-A|SITE-A': <String, Object?>{
            'actor': 'ADMIN',
            'outcome': 'Resynced',
            'recorded_at_utc': '2026-03-14T10:00:00.000Z',
          },
          'CLIENT-B|SITE-B': <String, Object?>{
            'actor': 'DISPATCH',
            'outcome': 'Already aligned',
            'recorded_at_utc': '2026-03-14T03:30:00.000Z',
          },
        },
        nowUtc: DateTime.utc(2026, 3, 14, 12, 0),
      );

      expect(hydrated.stateByScope.keys, ['CLIENT-A|SITE-A']);
      expect(hydrated.removedStale, isTrue);
    });

    test('migrates most recent non-stale audit record by scope label', () {
      final migrated = store.migrateFromAuditHistory(
        auditHistory: const [
          'Resync • ADMIN • MS Vallee Residence • Resynced • 2026-03-14T10:08:00.000Z',
          'Resync • DISPATCH • Other Site • Already aligned • 2026-03-14T09:12:00.000Z',
        ],
        scopes: const [
          MonitoringWatchRecoveryScope(
            scopeKey: 'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE',
            siteLabel: 'MS Vallee Residence',
          ),
        ],
        nowUtc: DateTime.utc(2026, 3, 14, 12, 0),
      );

      expect(migrated, hasLength(1));
      expect(
        migrated['CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE']?.actor,
        'ADMIN',
      );
    });

    test('formats labels only for fresh recovery state', () {
      final fresh = store.labelForState(
        state: MonitoringWatchRecoveryState(
          actor: 'ADMIN',
          outcome: 'Resynced',
          recordedAtUtc: DateTime.utc(2026, 3, 14, 10, 8),
        ),
        nowUtc: DateTime.utc(2026, 3, 14, 12, 0),
      );
      final stale = store.labelForState(
        state: MonitoringWatchRecoveryState(
          actor: 'ADMIN',
          outcome: 'Resynced',
          recordedAtUtc: DateTime.utc(2026, 3, 14, 5, 59),
        ),
        nowUtc: DateTime.utc(2026, 3, 14, 12, 0),
      );

      expect(fresh, 'ADMIN • Resynced • 10:08 UTC');
      expect(stale, isNull);
    });

    test('records audit entry, dedupes history, and returns recovery state', () {
      final update = store.recordAudit(
        existingHistory: const [
          'Resync • DISPATCH • Other Site • Already aligned • 2026-03-14T09:12:00.000Z',
          'Resync • ADMIN • MS Vallee Residence • Resynced • 2026-03-14T08:00:00.000Z',
        ],
        siteLabel: 'MS Vallee Residence',
        actor: '',
        outcome: ' Resynced ',
        recordedAtUtc: DateTime.utc(2026, 3, 14, 10, 8),
      );

      expect(
        update.entry,
        'Resync • SYSTEM • MS Vallee Residence • Resynced • 2026-03-14T10:08:00.000Z',
      );
      expect(update.history, [
        'Resync • SYSTEM • MS Vallee Residence • Resynced • 2026-03-14T10:08:00.000Z',
        'Resync • DISPATCH • Other Site • Already aligned • 2026-03-14T09:12:00.000Z',
        'Resync • ADMIN • MS Vallee Residence • Resynced • 2026-03-14T08:00:00.000Z',
      ]);
      expect(
        update.summary,
        'Resync • SYSTEM • MS Vallee Residence • Resynced • 2026-03-14T10:08:00.000Z',
      );
      expect(update.recoveryState.actor, 'SYSTEM');
      expect(update.recoveryState.outcome, 'Resynced');
      expect(
        update.recoveryState.recordedAtUtc,
        DateTime.utc(2026, 3, 14, 10, 8),
      );
    });

    test('normalizes audit history and falls back to summary when empty', () {
      final normalized = store.normalizeAuditHistory(
        auditHistory: const [
          '  ',
          ' Entry A ',
          'Entry B',
          'Entry C',
          'Entry D',
          'Entry E',
          'Entry F',
        ],
        fallbackSummary: 'Fallback',
      );
      final fallbackOnly = store.normalizeAuditHistory(
        auditHistory: const [' ', ''],
        fallbackSummary: ' Fallback ',
      );

      expect(normalized.history, [
        'Entry A',
        'Entry B',
        'Entry C',
        'Entry D',
        'Entry E',
      ]);
      expect(normalized.summary, 'Entry A');
      expect(fallbackOnly.history, ['Fallback']);
      expect(fallbackOnly.summary, 'Fallback');
    });

    test('restores audit state from persisted history and summary', () {
      final restored = store.restoreAuditState(
        persistedHistory: const ['  Entry A ', 'Entry B'],
        persistedSummary: 'Fallback',
      );
      final fallbackOnly = store.restoreAuditState(
        persistedHistory: const [' ', ''],
        persistedSummary: ' Fallback ',
      );

      expect(restored.history, ['Entry A', 'Entry B']);
      expect(restored.summary, 'Entry A');
      expect(fallbackOnly.history, ['Fallback']);
      expect(fallbackOnly.summary, 'Fallback');
    });

    test(
      'restores from audit history when persisted recovery state is empty',
      () {
        final restored = store.restoreState(
          raw: const {},
          auditHistory: const [
            'Resync • ADMIN • MS Vallee Residence • Resynced • 2026-03-14T10:08:00.000Z',
          ],
          scopes: const [
            MonitoringWatchRecoveryScope(
              scopeKey: 'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE',
              siteLabel: 'MS Vallee Residence',
            ),
          ],
          nowUtc: DateTime.utc(2026, 3, 14, 12, 0),
        );

        expect(
          restored
              .stateByScope['CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE']
              ?.actor,
          'ADMIN',
        );
        expect(restored.restoredFromAuditHistory, isTrue);
        expect(restored.shouldPersist, isTrue);
      },
    );

    test('prepares persisted recovery state with stale entries removed', () {
      final prepared = store.preparePersistedState(
        stateByScope: {
          'CLIENT-A|SITE-A': MonitoringWatchRecoveryState(
            actor: 'ADMIN',
            outcome: 'Resynced',
            recordedAtUtc: DateTime.utc(2026, 3, 14, 10, 8),
          ),
          'CLIENT-B|SITE-B': MonitoringWatchRecoveryState(
            actor: 'DISPATCH',
            outcome: 'Already aligned',
            recordedAtUtc: DateTime.utc(2026, 3, 14, 5, 59),
          ),
        },
        nowUtc: DateTime.utc(2026, 3, 14, 12, 0),
      );

      expect(prepared.freshStateByScope.keys, ['CLIENT-A|SITE-A']);
      expect(prepared.serializedState.keys, ['CLIENT-A|SITE-A']);
      expect(prepared.shouldClear, isFalse);
    });

    test('normalizes audit summary before persistence', () {
      expect(store.normalizeAuditSummaryForPersist('  Hello  '), 'Hello');
      expect(store.normalizeAuditSummaryForPersist('   '), isNull);
      expect(store.normalizeAuditSummaryForPersist(null), isNull);
    });

    test('prepares audit history for persistence', () {
      final prepared = store.prepareAuditHistoryForPersist(
        auditHistory: const [
          '  Entry A ',
          '',
          'Entry B',
          'Entry C',
          'Entry D',
          'Entry E',
          'Entry F',
        ],
      );
      final empty = store.prepareAuditHistoryForPersist(
        auditHistory: const [' ', ''],
      );

      expect(prepared.history, [
        'Entry A',
        'Entry B',
        'Entry C',
        'Entry D',
        'Entry E',
      ]);
      expect(prepared.shouldClear, isFalse);
      expect(empty.history, isEmpty);
      expect(empty.shouldClear, isTrue);
    });
  });
}
