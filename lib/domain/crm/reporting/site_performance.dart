class SitePerformance {
  final String siteId;
  final int totalIncidents;
  final int totalEscalations;
  final int totalSlaBreaches;
  final double slaComplianceRate;

  const SitePerformance({
    required this.siteId,
    required this.totalIncidents,
    required this.totalEscalations,
    required this.totalSlaBreaches,
    required this.slaComplianceRate,
  });
}
