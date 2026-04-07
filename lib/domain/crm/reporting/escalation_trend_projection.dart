import '../../incidents/incident_event.dart';
import 'escalation_trend.dart';

class EscalationTrendProjection {
  static EscalationTrend build({
    required String clientId,
    required String currentMonth,
    required String previousMonth,
    required List<IncidentEvent> incidentEvents,
  }) {
    int countEscalations(String month) {
      return incidentEvents
          .where((e) =>
              e.timestamp.startsWith(month) &&
              e.type == IncidentEventType.incidentEscalated)
          .length;
    }

    int countBreaches(String month) {
      return incidentEvents
          .where((e) =>
              e.timestamp.startsWith(month) &&
              e.type == IncidentEventType.incidentSlaBreached)
          .length;
    }

    final currentEscalations = countEscalations(currentMonth);
    final previousEscalations = countEscalations(previousMonth);

    final currentBreaches = countBreaches(currentMonth);
    final previousBreaches = countBreaches(previousMonth);

    double delta(int current, int previous) {
      if (previous == 0) {
        return current == 0 ? 0.0 : 100.0;
      }
      return ((current - previous) / previous) * 100;
    }

    return EscalationTrend(
      clientId: clientId,
      currentMonth: currentMonth,
      previousMonth: previousMonth,
      currentEscalations: currentEscalations,
      previousEscalations: previousEscalations,
      escalationDeltaPercent:
          delta(currentEscalations, previousEscalations),
      currentSlaBreaches: currentBreaches,
      previousSlaBreaches: previousBreaches,
      breachDeltaPercent:
          delta(currentBreaches, previousBreaches),
    );
  }
}
