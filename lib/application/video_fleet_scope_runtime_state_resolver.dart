import 'dvr_scope_config.dart';
import 'monitoring_watch_outcome_cue_store.dart';
import 'monitoring_watch_recovery_store.dart';
import 'monitoring_watch_runtime_store.dart';
import 'video_fleet_scope_runtime_state.dart';

class VideoFleetScopeRuntimeStateResolver {
  final MonitoringWatchOutcomeCueStore outcomeCueStore;
  final MonitoringWatchRecoveryStore recoveryStore;

  const VideoFleetScopeRuntimeStateResolver({
    required this.outcomeCueStore,
    required this.recoveryStore,
  });

  Map<String, VideoFleetScopeRuntimeState> resolve({
    required Iterable<DvrScopeConfig> scopes,
    required Map<String, MonitoringWatchOutcomeCueState> outcomeCueStateByScope,
    required Map<String, MonitoringWatchRecoveryState> recoveryStateByScope,
    required Map<String, MonitoringWatchRuntimeState> watchRuntimeByScope,
    required DateTime nowUtc,
  }) {
    final output = <String, VideoFleetScopeRuntimeState>{};
    for (final scope in scopes) {
      final operatorOutcomeLabel = outcomeCueStore.labelForState(
        state: outcomeCueStateByScope[scope.scopeKey],
        nowUtc: nowUtc,
      );
      final lastRecoveryLabel = recoveryStore.labelForState(
        state: recoveryStateByScope[scope.scopeKey],
        nowUtc: nowUtc,
      );
      final watchRuntime = watchRuntimeByScope[scope.scopeKey];
      final latestSceneReviewSummary =
          watchRuntime?.latestSceneReviewSummary.trim() ?? '';
      final latestSceneReviewLabel = _sceneReviewLabel(watchRuntime);
      final latestSceneDecisionLabel =
          watchRuntime?.latestSceneDecisionLabel.trim() ?? '';
      final latestSceneDecisionSummary =
          watchRuntime?.latestSceneDecisionSummary.trim() ?? '';
      final latestClientDecisionLabel =
          watchRuntime?.latestClientDecisionLabel.trim() ?? '';
      final latestClientDecisionSummary =
          watchRuntime?.latestClientDecisionSummary.trim() ?? '';
      final latestClientDecisionAtUtc = watchRuntime?.latestClientDecisionAtUtc;
      final alertCount = watchRuntime?.alertCount ?? 0;
      final repeatCount = watchRuntime?.repeatCount ?? 0;
      final escalationCount = watchRuntime?.escalationCount ?? 0;
      final suppressedCount = watchRuntime?.suppressedCount ?? 0;
      final actionHistory =
          watchRuntime?.actionHistory
              .map((entry) => entry.trim())
              .where((entry) => entry.isNotEmpty)
              .toList(growable: false) ??
          const <String>[];
      final suppressedHistory =
          watchRuntime?.suppressedHistory
              .map((entry) => entry.trim())
              .where((entry) => entry.isNotEmpty)
              .toList(growable: false) ??
          const <String>[];
      if ((operatorOutcomeLabel ?? '').trim().isEmpty &&
          (lastRecoveryLabel ?? '').trim().isEmpty &&
          latestSceneReviewLabel == null &&
          latestSceneReviewSummary.isEmpty &&
          latestSceneDecisionLabel.isEmpty &&
          latestSceneDecisionSummary.isEmpty &&
          latestClientDecisionLabel.isEmpty &&
          latestClientDecisionSummary.isEmpty &&
          latestClientDecisionAtUtc == null &&
          alertCount == 0 &&
          repeatCount == 0 &&
          escalationCount == 0 &&
          suppressedCount == 0 &&
          actionHistory.isEmpty &&
          suppressedHistory.isEmpty) {
        continue;
      }
      output[scope.scopeKey] = VideoFleetScopeRuntimeState(
        monitoringAvailable: watchRuntime?.monitoringAvailable ?? true,
        monitoringAvailabilityDetail:
            (watchRuntime?.monitoringAvailabilityDetail.trim().isEmpty ?? true)
            ? null
            : watchRuntime!.monitoringAvailabilityDetail.trim(),
        operatorOutcomeLabel: operatorOutcomeLabel,
        lastRecoveryLabel: lastRecoveryLabel,
        latestSceneReviewLabel: latestSceneReviewLabel,
        latestSceneReviewSummary: latestSceneReviewSummary.isEmpty
            ? null
            : latestSceneReviewSummary,
        latestSceneDecisionLabel: latestSceneDecisionLabel.isEmpty
            ? null
            : latestSceneDecisionLabel,
        latestSceneDecisionSummary: latestSceneDecisionSummary.isEmpty
            ? null
            : latestSceneDecisionSummary,
        latestClientDecisionLabel: latestClientDecisionLabel.isEmpty
            ? null
            : latestClientDecisionLabel,
        latestClientDecisionSummary: latestClientDecisionSummary.isEmpty
            ? null
            : latestClientDecisionSummary,
        latestClientDecisionAtUtc: latestClientDecisionAtUtc,
        alertCount: alertCount,
        repeatCount: repeatCount,
        escalationCount: escalationCount,
        suppressedCount: suppressedCount,
        actionHistory: actionHistory,
        suppressedHistory: suppressedHistory,
      );
    }
    return output;
  }

  String? _sceneReviewLabel(MonitoringWatchRuntimeState? runtime) {
    if (runtime == null) {
      return null;
    }
    final source = runtime.latestSceneReviewSourceLabel.trim();
    final posture = runtime.latestSceneReviewPostureLabel.trim();
    final updatedAt = runtime.latestSceneReviewUpdatedAtUtc;
    if (source.isEmpty && posture.isEmpty && updatedAt == null) {
      return null;
    }
    final parts = <String>[];
    if (source.isNotEmpty) {
      parts.add(source);
    }
    if (posture.isNotEmpty) {
      parts.add(posture);
    }
    if (updatedAt != null) {
      final utc = updatedAt.toUtc();
      final time =
          '${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')} UTC';
      parts.add(time);
    }
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' • ');
  }
}
