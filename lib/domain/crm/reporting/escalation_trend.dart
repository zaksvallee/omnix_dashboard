class EscalationTrend {
  final String clientId;
  final String currentMonth;
  final String previousMonth;

  final int currentEscalations;
  final int previousEscalations;
  final double escalationDeltaPercent;

  final int currentSlaBreaches;
  final int previousSlaBreaches;
  final double breachDeltaPercent;

  const EscalationTrend({
    required this.clientId,
    required this.currentMonth,
    required this.previousMonth,
    required this.currentEscalations,
    required this.previousEscalations,
    required this.escalationDeltaPercent,
    required this.currentSlaBreaches,
    required this.previousSlaBreaches,
    required this.breachDeltaPercent,
  });
}
