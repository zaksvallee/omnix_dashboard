import '../../incidents/incident_event.dart';
import '../../crm/crm_event.dart';
import '../../crm/sla_profile.dart';
import '../../crm/client.dart';
import '../../crm/client_aggregate.dart';
import '../../crm/sla_tier.dart';
import '../../events/dispatch_event.dart';

import 'monthly_report_projection.dart';
import 'executive_summary_generator.dart';
import 'multi_site_comparison_projection.dart';
import 'escalation_trend_projection.dart';
import 'dispatch_performance_projection.dart';
import 'report_branding_configuration.dart';
import 'report_bundle.dart';
import 'report_section_configuration.dart';
import 'report_sections.dart';

class ReportBundleAssembler {
  static ReportBundle build({
    required String clientId,
    required String currentMonth,
    required String previousMonth,
    required List<IncidentEvent> incidentEvents,
    required List<CRMEvent> crmEvents,
    required List<DispatchEvent> dispatchEvents,
    required SceneReviewSnapshot sceneReview,
    ReportBrandingConfiguration brandingConfiguration =
        const ReportBrandingConfiguration(),
    ReportSectionConfiguration sectionConfiguration =
        const ReportSectionConfiguration(),
  }) {
    ClientAggregate aggregate;

    if (crmEvents.isEmpty) {
      aggregate = ClientAggregate(
        client: Client(
          clientId: clientId,
          name: "Preview Client",
          createdAt: DateTime.now().toUtc().toIso8601String(),
        ),
        sites: const [],
        slaProfile: SLAProfile(
          slaId: 'PREVIEW-SLA',
          clientId: clientId,
          lowMinutes: 60,
          mediumMinutes: 45,
          highMinutes: 30,
          criticalMinutes: 15,
          createdAt: DateTime.now().toUtc().toIso8601String(),
        ),
        slaTier: SLATier.protect,
        contacts: const [],
      );
    } else {
      aggregate = ClientAggregate.rebuild(crmEvents);
    }

    final monthlyReport = MonthlyReportProjection.build(
      clientId: clientId,
      month: currentMonth,
      slaProfile: aggregate.slaProfile!,
      incidentEvents: incidentEvents,
      crmEvents: crmEvents,
      slaTierName: aggregate.slaTier?.name.toUpperCase() ?? "PROTECT",
    );

    final executiveSummary = ExecutiveSummaryGenerator.generate(monthlyReport);

    final siteComparisons = MultiSiteComparisonProjection.build(
      month: currentMonth,
      incidentEvents: incidentEvents,
    );

    final escalationTrend = EscalationTrendProjection.build(
      clientId: clientId,
      currentMonth: currentMonth,
      previousMonth: previousMonth,
      incidentEvents: incidentEvents,
    );

    // ================================
    // NEW STRUCTURED SECTIONS
    // ================================

    final clientSnapshot = ClientSnapshot(
      clientId: aggregate.client.clientId,
      clientName: aggregate.client.name,
      siteName: aggregate.sites.isNotEmpty
          ? aggregate.sites.first.name
          : "Primary Site",
      slaTier: aggregate.slaTier?.name.toUpperCase() ?? "PROTECT",
      reportingPeriod: currentMonth,
    );

    final guardPerformance =
        DispatchPerformanceProjection.buildGuardPerformance(
          clientId: clientId,
          month: currentMonth,
          events: dispatchEvents,
        );

    final patrolPerformance =
        DispatchPerformanceProjection.buildPatrolPerformance(
          clientId: clientId,
          month: currentMonth,
          events: dispatchEvents,
        );

    final incidentDetails = incidentEvents.map((e) {
      return IncidentDetailSnapshot(
        incidentId: e.eventId,
        riskCategory: e.metadata['risk']?.toString() ?? "UNCLASSIFIED",
        detectedAt: e.timestamp,
        slaResult: e.type.name,
        overrideApplied:
            e.type == IncidentEventType.incidentSlaOverrideRecorded,
      );
    }).toList();

    final supervisorAssessment = SupervisorAssessment(
      operationalSummary:
          "Operational stability maintained under structured event review.",
      riskTrend: monthlyReport.totalSlaBreaches == 0
          ? "No negative SLA trend detected."
          : "Elevated SLA pressure observed.",
      recommendations:
          "Continue structured patrol execution and escalation discipline.",
    );

    final companyAchievements = CompanyAchievementsSnapshot(
      highlights: const [
        "Maintained deterministic event-sourced reporting integrity.",
        "SLA adherence monitoring enhanced.",
        "Operational transparency improved through structured projections.",
      ],
    );

    final emergingThreats = EmergingThreatSnapshot(
      patternsObserved: const [
        "Monitor escalation timing drift.",
        "Observe repeat low-level incident clustering.",
      ],
    );

    return ReportBundle(
      monthlyReport: monthlyReport,
      executiveSummary: executiveSummary,
      siteComparisons: siteComparisons,
      escalationTrend: escalationTrend,
      clientSnapshot: clientSnapshot,
      guardPerformance: guardPerformance,
      patrolPerformance: patrolPerformance,
      incidentDetails: incidentDetails,
      sceneReview: sceneReview,
      brandingConfiguration: brandingConfiguration,
      sectionConfiguration: sectionConfiguration,
      supervisorAssessment: supervisorAssessment,
      companyAchievements: companyAchievements,
      emergingThreats: emergingThreats,
    );
  }
}
