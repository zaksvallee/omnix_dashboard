import 'monitoring_watch_recovery_policy.dart';

class MonitoringWatchRecoveryState {
  final String actor;
  final String outcome;
  final DateTime recordedAtUtc;

  const MonitoringWatchRecoveryState({
    required this.actor,
    required this.outcome,
    required this.recordedAtUtc,
  });
}

class MonitoringWatchAuditRecord {
  final String action;
  final String actor;
  final String siteLabel;
  final String outcome;
  final DateTime? recordedAtUtc;

  const MonitoringWatchAuditRecord({
    required this.action,
    required this.actor,
    required this.siteLabel,
    required this.outcome,
    required this.recordedAtUtc,
  });

  bool get isValid =>
      action.isNotEmpty &&
      actor.isNotEmpty &&
      siteLabel.isNotEmpty &&
      outcome.isNotEmpty;
}

class MonitoringWatchRecoveryScope {
  final String scopeKey;
  final String siteLabel;

  const MonitoringWatchRecoveryScope({
    required this.scopeKey,
    required this.siteLabel,
  });
}

class MonitoringWatchRecoveryHydration {
  final Map<String, MonitoringWatchRecoveryState> stateByScope;
  final bool removedStale;

  const MonitoringWatchRecoveryHydration({
    required this.stateByScope,
    required this.removedStale,
  });
}

class MonitoringWatchRecoveryRestoreResult {
  final Map<String, MonitoringWatchRecoveryState> stateByScope;
  final bool shouldPersist;
  final bool restoredFromAuditHistory;

  const MonitoringWatchRecoveryRestoreResult({
    required this.stateByScope,
    required this.shouldPersist,
    required this.restoredFromAuditHistory,
  });
}

class MonitoringWatchAuditTrailUpdate {
  final String entry;
  final List<String> history;
  final String? summary;
  final MonitoringWatchRecoveryState recoveryState;

  const MonitoringWatchAuditTrailUpdate({
    required this.entry,
    required this.history,
    required this.summary,
    required this.recoveryState,
  });
}

class MonitoringWatchAuditHistoryState {
  final List<String> history;
  final String? summary;

  const MonitoringWatchAuditHistoryState({
    required this.history,
    required this.summary,
  });
}

class MonitoringWatchRecoveryPersistenceState {
  final Map<String, MonitoringWatchRecoveryState> freshStateByScope;
  final Map<String, Object?> serializedState;
  final bool shouldClear;

  const MonitoringWatchRecoveryPersistenceState({
    required this.freshStateByScope,
    required this.serializedState,
    required this.shouldClear,
  });
}

class MonitoringWatchAuditHistoryPersistenceState {
  final List<String> history;
  final bool shouldClear;

  const MonitoringWatchAuditHistoryPersistenceState({
    required this.history,
    required this.shouldClear,
  });
}

class MonitoringWatchRecoveryStore {
  final MonitoringWatchRecoveryPolicy policy;

  const MonitoringWatchRecoveryStore({required this.policy});

  MonitoringWatchRecoveryHydration parsePersistedState({
    required Map<String, Object?> raw,
    required DateTime nowUtc,
  }) {
    final restored = <String, MonitoringWatchRecoveryState>{};
    var removedStale = false;
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      final map = value.map(
        (key, item) => MapEntry(key.toString(), item as Object?),
      );
      final actor = (map['actor'] ?? '').toString().trim();
      final outcome = (map['outcome'] ?? '').toString().trim();
      final recordedAtRaw = (map['recorded_at_utc'] ?? '').toString().trim();
      final recordedAtUtc = DateTime.tryParse(recordedAtRaw)?.toUtc();
      if (actor.isEmpty || outcome.isEmpty || recordedAtUtc == null) {
        continue;
      }
      if (policy.isExpired(recordedAtUtc: recordedAtUtc, nowUtc: nowUtc)) {
        removedStale = true;
        continue;
      }
      restored[entry.key] = MonitoringWatchRecoveryState(
        actor: actor,
        outcome: outcome,
        recordedAtUtc: recordedAtUtc,
      );
    }
    return MonitoringWatchRecoveryHydration(
      stateByScope: restored,
      removedStale: removedStale,
    );
  }

  MonitoringWatchRecoveryRestoreResult restoreState({
    required Map<String, Object?> raw,
    required Iterable<String> auditHistory,
    required Iterable<MonitoringWatchRecoveryScope> scopes,
    required DateTime nowUtc,
  }) {
    final hydration = parsePersistedState(raw: raw, nowUtc: nowUtc);
    final restored = Map<String, MonitoringWatchRecoveryState>.from(
      hydration.stateByScope,
    );
    var restoredFromAuditHistory = false;
    if (restored.isEmpty) {
      final migrated = migrateFromAuditHistory(
        auditHistory: auditHistory,
        scopes: scopes,
        nowUtc: nowUtc,
      );
      if (migrated.isNotEmpty) {
        restored.addAll(migrated);
        restoredFromAuditHistory = true;
      }
    }
    return MonitoringWatchRecoveryRestoreResult(
      stateByScope: restored,
      shouldPersist: hydration.removedStale || restoredFromAuditHistory,
      restoredFromAuditHistory: restoredFromAuditHistory,
    );
  }

  Map<String, MonitoringWatchRecoveryState> freshState({
    required Map<String, MonitoringWatchRecoveryState> stateByScope,
    required DateTime nowUtc,
  }) {
    return Map<String, MonitoringWatchRecoveryState>.fromEntries(
      stateByScope.entries.where(
        (entry) => !policy.isExpired(
          recordedAtUtc: entry.value.recordedAtUtc,
          nowUtc: nowUtc,
        ),
      ),
    );
  }

  MonitoringWatchRecoveryPersistenceState preparePersistedState({
    required Map<String, MonitoringWatchRecoveryState> stateByScope,
    required DateTime nowUtc,
  }) {
    final fresh = freshState(stateByScope: stateByScope, nowUtc: nowUtc);
    return MonitoringWatchRecoveryPersistenceState(
      freshStateByScope: fresh,
      serializedState: serializeState(fresh),
      shouldClear: fresh.isEmpty,
    );
  }

  Map<String, Object?> serializeState(
    Map<String, MonitoringWatchRecoveryState> stateByScope,
  ) {
    final output = <String, Object?>{};
    for (final entry in stateByScope.entries) {
      output[entry.key] = <String, Object?>{
        'actor': entry.value.actor,
        'outcome': entry.value.outcome,
        'recorded_at_utc': entry.value.recordedAtUtc.toIso8601String(),
      };
    }
    return output;
  }

  MonitoringWatchAuditRecord? parseAuditRecord(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final parts = normalized.split(' • ');
    if (parts.length < 5) {
      return null;
    }
    return MonitoringWatchAuditRecord(
      action: parts.first.trim(),
      actor: parts[1].trim(),
      siteLabel: parts[2].trim(),
      outcome: parts[3].trim(),
      recordedAtUtc: DateTime.tryParse(parts.last.trim())?.toUtc(),
    );
  }

  Map<String, MonitoringWatchRecoveryState> migrateFromAuditHistory({
    required Iterable<String> auditHistory,
    required Iterable<MonitoringWatchRecoveryScope> scopes,
    required DateTime nowUtc,
  }) {
    final migrated = <String, MonitoringWatchRecoveryState>{};
    for (final scope in scopes) {
      for (final raw in auditHistory) {
        final record = parseAuditRecord(raw);
        if (record == null || !record.isValid || record.recordedAtUtc == null) {
          continue;
        }
        if (policy.isExpired(
          recordedAtUtc: record.recordedAtUtc!,
          nowUtc: nowUtc,
        )) {
          continue;
        }
        if (record.siteLabel != scope.siteLabel) {
          continue;
        }
        migrated[scope.scopeKey] = MonitoringWatchRecoveryState(
          actor: record.actor,
          outcome: record.outcome,
          recordedAtUtc: record.recordedAtUtc!,
        );
        break;
      }
    }
    return migrated;
  }

  String? labelForState({
    required MonitoringWatchRecoveryState? state,
    required DateTime nowUtc,
  }) {
    if (state == null) {
      return null;
    }
    if (policy.isExpired(recordedAtUtc: state.recordedAtUtc, nowUtc: nowUtc)) {
      return null;
    }
    return policy.formatLabel(
      actor: state.actor,
      outcome: state.outcome,
      recordedAtUtc: state.recordedAtUtc,
    );
  }

  MonitoringWatchAuditTrailUpdate recordAudit({
    required Iterable<String> existingHistory,
    required String siteLabel,
    required String actor,
    required String outcome,
    required DateTime recordedAtUtc,
    int maxEntries = 5,
  }) {
    final normalizedActor = actor.trim().isEmpty ? 'SYSTEM' : actor.trim();
    final normalizedSiteLabel = siteLabel.trim();
    final normalizedOutcome = outcome.trim();
    final entry =
        'Resync • $normalizedActor • $normalizedSiteLabel • $normalizedOutcome • ${recordedAtUtc.toIso8601String()}';
    final history = <String>[
      entry,
      ...existingHistory
          .map((item) => item.trim())
          .where((item) => item != entry),
    ].take(maxEntries).toList(growable: false);
    return MonitoringWatchAuditTrailUpdate(
      entry: entry,
      history: history,
      summary: history.isEmpty ? null : history.first,
      recoveryState: MonitoringWatchRecoveryState(
        actor: normalizedActor,
        outcome: normalizedOutcome,
        recordedAtUtc: recordedAtUtc,
      ),
    );
  }

  MonitoringWatchAuditHistoryState normalizeAuditHistory({
    required Iterable<String> auditHistory,
    String? fallbackSummary,
    int maxEntries = 5,
  }) {
    final normalizedHistory = auditHistory
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .take(maxEntries)
        .toList(growable: false);
    final trimmedFallback = (fallbackSummary ?? '').trim();
    final history = normalizedHistory.isNotEmpty
        ? normalizedHistory
        : (trimmedFallback.isEmpty ? const <String>[] : [trimmedFallback]);
    return MonitoringWatchAuditHistoryState(
      history: history,
      summary: history.isEmpty ? null : history.first,
    );
  }

  MonitoringWatchAuditHistoryState restoreAuditState({
    required Iterable<String> persistedHistory,
    String? persistedSummary,
    int maxEntries = 5,
  }) {
    return normalizeAuditHistory(
      auditHistory: persistedHistory,
      fallbackSummary: persistedSummary,
      maxEntries: maxEntries,
    );
  }

  MonitoringWatchAuditHistoryPersistenceState prepareAuditHistoryForPersist({
    required Iterable<String> auditHistory,
    int maxEntries = 5,
  }) {
    final normalized = normalizeAuditHistory(
      auditHistory: auditHistory,
      maxEntries: maxEntries,
    );
    return MonitoringWatchAuditHistoryPersistenceState(
      history: normalized.history,
      shouldClear: normalized.history.isEmpty,
    );
  }

  String? normalizeAuditSummaryForPersist(String? summary) {
    final trimmed = (summary ?? '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
