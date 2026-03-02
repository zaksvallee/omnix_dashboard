class MonthlyReport {
  final String clientId;
  final String month; // YYYY-MM

  final String slaTierName;

  final int totalIncidents;
  final int totalEscalations;
  final int totalSlaBreaches;
  final int totalSlaOverrides;
  final int totalClientContacts;

  final double slaComplianceRate; // 0.0 – 1.0

  const MonthlyReport({
    required this.clientId,
    required this.month,
    required this.slaTierName,
    required this.totalIncidents,
    required this.totalEscalations,
    required this.totalSlaBreaches,
    required this.totalSlaOverrides,
    required this.totalClientContacts,
    required this.slaComplianceRate,
  });
}
