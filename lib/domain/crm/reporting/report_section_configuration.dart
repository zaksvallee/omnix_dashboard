class ReportSectionConfiguration {
  final bool includeTimeline;
  final bool includeDispatchSummary;
  final bool includeCheckpointCompliance;
  final bool includeAiDecisionLog;
  final bool includeGuardMetrics;

  const ReportSectionConfiguration({
    this.includeTimeline = true,
    this.includeDispatchSummary = true,
    this.includeCheckpointCompliance = true,
    this.includeAiDecisionLog = true,
    this.includeGuardMetrics = true,
  });

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'includeTimeline': includeTimeline,
      'includeDispatchSummary': includeDispatchSummary,
      'includeCheckpointCompliance': includeCheckpointCompliance,
      'includeAiDecisionLog': includeAiDecisionLog,
      'includeGuardMetrics': includeGuardMetrics,
    };
  }
}
