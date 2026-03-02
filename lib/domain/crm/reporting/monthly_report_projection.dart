import '../../incidents/incident_event.dart';
import '../../crm/crm_event.dart';
import '../../crm/sla_profile.dart';
import 'monthly_report.dart';
import 'sla_dashboard_projection.dart';

class MonthlyReportProjection {
  static MonthlyReport build({
    required String clientId,
    required String month,
    required SLAProfile slaProfile,
    required List<IncidentEvent> incidentEvents,
    required List<CRMEvent> crmEvents,
    required String slaTierName,
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

    final totalSlaOverrides = incidentsInMonth
        .where((e) => e.type == IncidentEventType.incidentSlaOverrideRecorded)
        .length;

    final totalClientContacts = crmInMonth
        .where((e) => e.type == CRMEventType.clientContactLogged)
        .length;

    final monthStart = DateTime.parse('$month-01T00:00:00Z');
    final monthEnd = monthStart
        .add(const Duration(days: 32))
        .copyWith(day: 1)
        .subtract(const Duration(seconds: 1));

    final slaSummary = SLADashboardProjection.build(
      clientId: clientId,
      profile: slaProfile,
      events: incidentsInMonth,
      fromUtc: monthStart,
      toUtc: monthEnd,
    );

    final slaComplianceRate =
        totalIncidents == 0 ? 1.0 : slaSummary.compliancePercentage / 100.0;

    return MonthlyReport(
      clientId: clientId,
      month: month,
      slaTierName: slaTierName,
      totalIncidents: totalIncidents,
      totalEscalations: totalEscalations,
      totalSlaBreaches: totalSlaBreaches,
      totalSlaOverrides: totalSlaOverrides,
      totalClientContacts: totalClientContacts,
      slaComplianceRate: slaComplianceRate,
    );
  }
}
