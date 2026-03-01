import '../../incidents/incident_event.dart';
import '../../crm/crm_event.dart';
import 'monthly_report.dart';

class MonthlyReportProjection {
  static MonthlyReport build({
    required String clientId,
    required String month,
    required List<IncidentEvent> incidentEvents,
    required List<CRMEvent> crmEvents,
  }) {
    final incidentsInMonth = incidentEvents.where((e) {
      return e.timestamp.startsWith(month);
    }).toList();

    final crmInMonth = crmEvents.where((e) {
      return e.timestamp.startsWith(month);
    }).toList();

    final totalIncidents = incidentsInMonth
        .where((e) => e.type == IncidentEventType.incidentDetected)
        .length;

    final totalEscalations = incidentsInMonth
        .where((e) =>
            e.type == IncidentEventType.incidentEscalated ||
            e.type == IncidentEventType.incidentSlaBreached)
        .length;

    final totalSlaBreaches = incidentsInMonth
        .where((e) => e.type == IncidentEventType.incidentSlaBreached)
        .length;

    final totalClientContacts = crmInMonth
        .where((e) => e.type == CRMEventType.clientContactLogged)
        .length;

    final slaComplianceRate = totalIncidents == 0
        ? 1.0
        : 1.0 - (totalSlaBreaches / totalIncidents);

    return MonthlyReport(
      clientId: clientId,
      month: month,
      totalIncidents: totalIncidents,
      totalEscalations: totalEscalations,
      totalSlaBreaches: totalSlaBreaches,
      totalClientContacts: totalClientContacts,
      slaComplianceRate: slaComplianceRate,
    );
  }
}
