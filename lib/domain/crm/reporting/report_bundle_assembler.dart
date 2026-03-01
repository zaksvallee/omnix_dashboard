import '../../incidents/incident_event.dart';
import '../../crm/crm_event.dart';

import 'monthly_report_projection.dart';
import 'executive_summary_generator.dart';
import 'multi_site_comparison_projection.dart';
import 'escalation_trend_projection.dart';
import 'report_bundle.dart';

class ReportBundleAssembler {
  static ReportBundle build({
    required String clientId,
    required String currentMonth,
    required String previousMonth,
    required List<IncidentEvent> incidentEvents,
    required List<CRMEvent> crmEvents,
  }) {
    final monthlyReport = MonthlyReportProjection.build(
      clientId: clientId,
      month: currentMonth,
      incidentEvents: incidentEvents,
      crmEvents: crmEvents,
    );

    final executiveSummary =
        ExecutiveSummaryGenerator.generate(monthlyReport);

    final siteComparisons =
        MultiSiteComparisonProjection.build(
      month: currentMonth,
      incidentEvents: incidentEvents,
    );

    final escalationTrend =
        EscalationTrendProjection.build(
      clientId: clientId,
      currentMonth: currentMonth,
      previousMonth: previousMonth,
      incidentEvents: incidentEvents,
    );

    return ReportBundle(
      monthlyReport: monthlyReport,
      executiveSummary: executiveSummary,
      siteComparisons: siteComparisons,
      escalationTrend: escalationTrend,
    );
  }
}
