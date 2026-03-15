import 'monitoring_watch_outcome_cue_store.dart';
import 'monitoring_watch_recovery_store.dart';

class MonitoringWatchResyncOutcomeRecord {
  final Map<String, MonitoringWatchOutcomeCueState> cueStateByScope;
  final List<String> auditHistory;
  final String? auditSummary;
  final MonitoringWatchRecoveryState recoveryState;

  const MonitoringWatchResyncOutcomeRecord({
    required this.cueStateByScope,
    required this.auditHistory,
    required this.auditSummary,
    required this.recoveryState,
  });
}

class MonitoringWatchResyncOutcomeRecorder {
  final MonitoringWatchOutcomeCueStore outcomeCueStore;
  final MonitoringWatchRecoveryStore recoveryStore;

  const MonitoringWatchResyncOutcomeRecorder({
    required this.outcomeCueStore,
    required this.recoveryStore,
  });

  MonitoringWatchResyncOutcomeRecord record({
    required Map<String, MonitoringWatchOutcomeCueState> cueStateByScope,
    required Iterable<String> auditHistory,
    required String scopeKey,
    required String siteLabel,
    required String actor,
    required String outcome,
    required DateTime nowUtc,
  }) {
    final cueUpdate = outcomeCueStore.recordCue(
      stateByScope: cueStateByScope,
      scopeKey: scopeKey,
      label: outcome,
      nowUtc: nowUtc,
    );
    final auditUpdate = recoveryStore.recordAudit(
      existingHistory: auditHistory,
      siteLabel: siteLabel,
      actor: actor,
      outcome: outcome,
      recordedAtUtc: nowUtc,
    );
    return MonitoringWatchResyncOutcomeRecord(
      cueStateByScope: cueUpdate.stateByScope,
      auditHistory: auditUpdate.history,
      auditSummary: auditUpdate.summary,
      recoveryState: auditUpdate.recoveryState,
    );
  }
}
