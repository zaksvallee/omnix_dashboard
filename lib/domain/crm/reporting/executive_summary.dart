class ExecutiveSummary {
  final String clientId;
  final String month;
  final String headline;
  final String performanceSummary;
  final String slaSummary;
  final String riskSummary;

  const ExecutiveSummary({
    required this.clientId,
    required this.month,
    required this.headline,
    required this.performanceSummary,
    required this.slaSummary,
    required this.riskSummary,
  });
}
