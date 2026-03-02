class SLADashboardSummary {
  final String clientId;
  final String fromUtc;
  final String toUtc;

  final int totalIncidents;
  final int breachedIncidents;

  final double compliancePercentage;

  final Map<String, int> incidentsBySeverity;
  final Map<String, int> breachesBySeverity;

  const SLADashboardSummary({
    required this.clientId,
    required this.fromUtc,
    required this.toUtc,
    required this.totalIncidents,
    required this.breachedIncidents,
    required this.compliancePercentage,
    required this.incidentsBySeverity,
    required this.breachesBySeverity,
  });
}
