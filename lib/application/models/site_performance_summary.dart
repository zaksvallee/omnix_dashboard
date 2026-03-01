class SitePerformanceSummary {
  final double avgResponseMinutes;
  final double avgResolutionMinutes;
  final int incidentCount;
  final int slaBreaches;

  final double guardCompliancePercent;
  final double slaCompliancePercent;
  final double escalationTrendScore;

  const SitePerformanceSummary({
    required this.avgResponseMinutes,
    required this.avgResolutionMinutes,
    required this.incidentCount,
    required this.slaBreaches,
    required this.guardCompliancePercent,
    required this.slaCompliancePercent,
    required this.escalationTrendScore,
  });
}
