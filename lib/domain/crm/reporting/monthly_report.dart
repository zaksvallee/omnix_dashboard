class MonthlyReport {
  final String clientId;
  final String month; // YYYY-MM

  final int totalIncidents;
  final int totalEscalations;
  final int totalSlaBreaches;
  final int totalClientContacts;

  final double slaComplianceRate; // 0.0 – 1.0

  const MonthlyReport({
    required this.clientId,
    required this.month,
    required this.totalIncidents,
    required this.totalEscalations,
    required this.totalSlaBreaches,
    required this.totalClientContacts,
    required this.slaComplianceRate,
  });
}
