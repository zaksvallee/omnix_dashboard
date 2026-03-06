import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/guard/guard_sync_selection_scope.dart';

void main() {
  group('guardSyncSelectionScopeKey', () {
    test('scopes by history, mode, and facade id', () {
      final key = guardSyncSelectionScopeKey(
        historyFilter: 'failed',
        operationModeFilter: 'live',
        facadeId: 'fsk_live',
      );

      expect(key, 'failed|live|fsk_live');
    });

    test('uses all_facades sentinel when facade is empty', () {
      final key = guardSyncSelectionScopeKey(
        historyFilter: 'queued',
        operationModeFilter: 'all',
        facadeId: '  ',
      );

      expect(key, 'queued|all|all_facades');
    });
  });

  group('normalizeGuardSyncSelectionScopeKey', () {
    test('normalizes malformed scoped keys with defaults', () {
      expect(
        normalizeGuardSyncSelectionScopeKey('failed||'),
        'failed|all|all_facades',
      );
      expect(
        normalizeGuardSyncSelectionScopeKey('queued|live|'),
        'queued|live|all_facades',
      );
      expect(
        normalizeGuardSyncSelectionScopeKey('synced| |fsk_live'),
        'synced|all|fsk_live',
      );
    });

    test('returns null for blank history segment', () {
      expect(normalizeGuardSyncSelectionScopeKey(' |live|fsk'), isNull);
    });

    test('falls back to all for unknown history and mode values', () {
      expect(
        normalizeGuardSyncSelectionScopeKey('typo_history|typo_mode|fsk'),
        'all|all|fsk',
      );
    });
  });

  group('migrateLegacyGuardSyncSelectionScopes', () {
    test('migrates history-only keys into scoped keys', () {
      final migrated = migrateLegacyGuardSyncSelectionScopes({
        'failed': 'op-failed-1',
        'queued': 'op-queued-1',
      });

      expect(migrated['failed|all|all_facades'], 'op-failed-1');
      expect(migrated['queued|all|all_facades'], 'op-queued-1');
      expect(migrated.containsKey('failed'), isFalse);
    });

    test('preserves already-scoped keys and drops blank rows', () {
      final migrated = migrateLegacyGuardSyncSelectionScopes({
        'failed|live|fsk_live': 'op-live-1',
        'queued||': 'op-queued-1',
        '  ': 'ignored',
        'synced': '   ',
      });

      expect(migrated, {
        'failed|live|fsk_live': 'op-live-1',
        'queued|all|all_facades': 'op-queued-1',
      });
    });

    test('keeps fully scoped maps unchanged for hydrate no-op checks', () {
      const scoped = {
        'failed|live|fsk_live': 'op-live-1',
        'queued|stub|fsk_stub': 'op-stub-1',
      };
      final migrated = migrateLegacyGuardSyncSelectionScopes(scoped);

      expect(migrated, scoped);
      expect(guardSyncSelectionScopesEqual(migrated, scoped), isTrue);
    });

    test('preserves first value when normalized scoped keys collide', () {
      final migrated = migrateLegacyGuardSyncSelectionScopes({
        'failed||': 'first',
        'failed|all|all_facades': 'second',
      });

      expect(migrated['failed|all|all_facades'], 'first');
    });
  });

  group('guardSyncSelectionScopesEqual', () {
    test('returns true for equivalent maps', () {
      const a = {'failed|all|all_facades': 'op-1'};
      const b = {'failed|all|all_facades': 'op-1'};
      expect(guardSyncSelectionScopesEqual(a, b), isTrue);
    });

    test('returns false when values differ', () {
      const a = {'failed|all|all_facades': 'op-1'};
      const b = {'failed|all|all_facades': 'op-2'};
      expect(guardSyncSelectionScopesEqual(a, b), isFalse);
    });
  });

  group('setGuardSyncSelectionForScope', () {
    test('writes selected operation to exact scoped key', () {
      final next = setGuardSyncSelectionForScope(
        current: const {
          'failed|live|fsk_live': 'old-live',
          'failed|stub|fsk_stub': 'keep-stub',
        },
        scopeKey: 'failed|live|fsk_live',
        operationId: 'new-live',
      );

      expect(next['failed|live|fsk_live'], 'new-live');
      expect(next['failed|stub|fsk_stub'], 'keep-stub');
    });

    test('removes scoped key when operation id is blank', () {
      final next = setGuardSyncSelectionForScope(
        current: const {
          'failed|live|fsk_live': 'old-live',
          'failed|stub|fsk_stub': 'keep-stub',
        },
        scopeKey: 'failed|live|fsk_live',
        operationId: '   ',
      );

      expect(next.containsKey('failed|live|fsk_live'), isFalse);
      expect(next['failed|stub|fsk_stub'], 'keep-stub');
    });

    test('leaves map unchanged when scope key is blank', () {
      const current = {
        'failed|live|fsk_live': 'old-live',
        'failed|stub|fsk_stub': 'keep-stub',
      };
      final next = setGuardSyncSelectionForScope(
        current: current,
        scopeKey: '  ',
        operationId: 'new-live',
      );

      expect(next, current);
    });
  });

  group('pruneGuardSyncSelectionScopesByOperationIds', () {
    test('keeps only scoped selections with known operation ids', () {
      final pruned = pruneGuardSyncSelectionScopesByOperationIds(
        current: const {
          'failed|live|fsk_live': 'op-live-1',
          'failed|stub|fsk_stub': 'op-stub-1',
          'queued|all|all_facades': 'op-missing',
        },
        knownOperationIds: const {'op-live-1', 'op-stub-1'},
      );

      expect(pruned, {
        'failed|live|fsk_live': 'op-live-1',
        'failed|stub|fsk_stub': 'op-stub-1',
      });
    });

    test('returns empty map when no operation ids are known', () {
      final pruned = pruneGuardSyncSelectionScopesByOperationIds(
        current: const {'failed|live|fsk_live': 'op-live-1'},
        knownOperationIds: const {},
      );

      expect(pruned, isEmpty);
    });

    test('drops blank keys and values during prune', () {
      final pruned = pruneGuardSyncSelectionScopesByOperationIds(
        current: const {
          '  ': 'op-live-1',
          'failed|live|fsk_live': '   ',
          'failed|stub|fsk_stub': 'op-stub-1',
        },
        knownOperationIds: const {'op-live-1', 'op-stub-1'},
      );

      expect(pruned, {'failed|stub|fsk_stub': 'op-stub-1'});
    });
  });

  group('shouldPruneGuardSyncSelections', () {
    test('returns false when no known operation ids exist', () {
      expect(
        shouldPruneGuardSyncSelections(
          fetchedOperationCount: 20,
          fetchLimit: 500,
          hasKnownOperationIds: false,
        ),
        isFalse,
      );
    });

    test('returns true when fetch is complete and known ids exist', () {
      expect(
        shouldPruneGuardSyncSelections(
          fetchedOperationCount: 120,
          fetchLimit: 500,
          hasKnownOperationIds: true,
        ),
        isTrue,
      );
    });

    test('returns false when fetch is likely truncated at limit', () {
      expect(
        shouldPruneGuardSyncSelections(
          fetchedOperationCount: 500,
          fetchLimit: 500,
          hasKnownOperationIds: true,
        ),
        isFalse,
      );
    });

    test('treats non-positive limits as always pruneable when ids exist', () {
      expect(
        shouldPruneGuardSyncSelections(
          fetchedOperationCount: 0,
          fetchLimit: 0,
          hasKnownOperationIds: true,
        ),
        isTrue,
      );
    });
  });

  group('clearGuardSyncSelectionIfScopeOperationMissing', () {
    test('removes scoped selection when selected operation is absent', () {
      final next = clearGuardSyncSelectionIfScopeOperationMissing(
        current: const {
          'failed|live|fsk_live': 'op-live-1',
          'failed|stub|fsk_stub': 'op-stub-1',
        },
        scopeKey: 'failed|live|fsk_live',
        visibleOperationIds: const {'op-live-2'},
      );

      expect(next.containsKey('failed|live|fsk_live'), isFalse);
      expect(next['failed|stub|fsk_stub'], 'op-stub-1');
    });

    test('keeps scoped selection when operation remains visible', () {
      final next = clearGuardSyncSelectionIfScopeOperationMissing(
        current: const {'failed|live|fsk_live': 'op-live-1'},
        scopeKey: 'failed|live|fsk_live',
        visibleOperationIds: const {'op-live-1', 'op-live-2'},
      );

      expect(next['failed|live|fsk_live'], 'op-live-1');
    });

    test('normalizes incoming scope key before lookup', () {
      final next = clearGuardSyncSelectionIfScopeOperationMissing(
        current: const {'failed|all|all_facades': 'op-1'},
        scopeKey: 'failed||',
        visibleOperationIds: const {'op-missing'},
      );

      expect(next.containsKey('failed|all|all_facades'), isFalse);
    });
  });

  group('applyGuardSyncSelectionMaintenance', () {
    test('prunes globally and then clears active scope when missing', () {
      final next = applyGuardSyncSelectionMaintenance(
        current: const {
          'failed|live|fsk_live': 'op-live-1',
          'failed|stub|fsk_stub': 'op-stub-1',
        },
        knownOperationIds: const {'op-stub-1'},
        fetchedOperationCount: 10,
        fetchLimit: 500,
        activeScopeKey: 'failed|stub|fsk_stub',
        activeScopeVisibleOperationIds: const {'op-stub-2'},
      );

      expect(next, isEmpty);
    });

    test(
      'skips global prune on likely truncated read but clears active scope',
      () {
        final next = applyGuardSyncSelectionMaintenance(
          current: const {
            'failed|live|fsk_live': 'op-live-1',
            'failed|stub|fsk_stub': 'op-stub-1',
          },
          knownOperationIds: const {'op-stub-1'},
          fetchedOperationCount: 500,
          fetchLimit: 500,
          activeScopeKey: 'failed|stub|fsk_stub',
          activeScopeVisibleOperationIds: const {'op-stub-2'},
        );

        expect(next, {'failed|live|fsk_live': 'op-live-1'});
      },
    );

    test(
      'keeps selections when global prune skipped and active scope stays visible',
      () {
        final next = applyGuardSyncSelectionMaintenance(
          current: const {
            'failed|live|fsk_live': 'op-live-1',
            'failed|stub|fsk_stub': 'op-stub-1',
          },
          knownOperationIds: const {'op-stub-1'},
          fetchedOperationCount: 500,
          fetchLimit: 500,
          activeScopeKey: 'failed|stub|fsk_stub',
          activeScopeVisibleOperationIds: const {'op-stub-1'},
        );

        expect(next, {
          'failed|live|fsk_live': 'op-live-1',
          'failed|stub|fsk_stub': 'op-stub-1',
        });
      },
    );
  });
}
