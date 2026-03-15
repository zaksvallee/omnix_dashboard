class VideoFleetScopeRuntimeState {
  final String? operatorOutcomeLabel;
  final String? lastRecoveryLabel;
  final String? latestSceneReviewLabel;
  final String? latestSceneReviewSummary;
  final String? latestSceneDecisionLabel;
  final String? latestSceneDecisionSummary;
  final String? latestClientDecisionLabel;
  final String? latestClientDecisionSummary;
  final DateTime? latestClientDecisionAtUtc;
  final int alertCount;
  final int repeatCount;
  final int escalationCount;
  final int suppressedCount;
  final List<String> actionHistory;
  final List<String> suppressedHistory;

  const VideoFleetScopeRuntimeState({
    this.operatorOutcomeLabel,
    this.lastRecoveryLabel,
    this.latestSceneReviewLabel,
    this.latestSceneReviewSummary,
    this.latestSceneDecisionLabel,
    this.latestSceneDecisionSummary,
    this.latestClientDecisionLabel,
    this.latestClientDecisionSummary,
    this.latestClientDecisionAtUtc,
    this.alertCount = 0,
    this.repeatCount = 0,
    this.escalationCount = 0,
    this.suppressedCount = 0,
    this.actionHistory = const <String>[],
    this.suppressedHistory = const <String>[],
  });
}
