import 'package:omnix_dashboard/domain/crm/reporting/escalation_trend.dart';
import 'package:omnix_dashboard/domain/crm/reporting/executive_summary.dart';
import 'package:omnix_dashboard/domain/crm/reporting/monthly_report.dart';
import 'package:omnix_dashboard/domain/crm/reporting/report_branding_configuration.dart';
import 'package:omnix_dashboard/domain/crm/reporting/report_bundle.dart';
import 'package:omnix_dashboard/domain/crm/reporting/report_section_configuration.dart';
import 'package:omnix_dashboard/domain/crm/reporting/report_sections.dart';
import 'package:omnix_dashboard/domain/crm/reporting/site_performance.dart';

const String reportTestHighlightDetectedAt = '2026-03-14T21:18:00.000Z';

const String reportTestMonitoringAlertActionTaken =
    '2026-03-14T21:14:00.000Z • Camera 1 • Monitoring Alert • Vehicle remained visible in the monitored driveway.';

const String reportTestEscalationSummary =
    'Person visible near the boundary after repeat activity.';

const String reportTestSuppressedDecisionSummary =
    'Vehicle remained below escalation threshold.';

const String reportTestSuppressedSummary =
    'Low significance vehicle motion remained internal.';

const String reportTestLatestActionTaken =
    '2026-03-14T21:18:00.000Z • Camera 2 • Escalation Candidate • Escalated for urgent review because person activity was detected near the boundary.';

const String reportTestLatestSuppressedPattern =
    '2026-03-14T21:16:00.000Z • Camera 3 • Vehicle remained below escalation threshold.';

ReportBundle buildTestReportBundle({
  MonthlyReport monthlyReport = const MonthlyReport(
    clientId: 'CLIENT-MS-VALLEE',
    month: '2026-03',
    slaTierName: 'PROTECT',
    totalIncidents: 3,
    totalEscalations: 1,
    totalSlaBreaches: 0,
    totalSlaOverrides: 0,
    totalClientContacts: 1,
    slaComplianceRate: 1,
  ),
  ExecutiveSummary executiveSummary = const ExecutiveSummary(
    clientId: 'CLIENT-MS-VALLEE',
    month: '2026-03',
    headline: 'Stable watch period.',
    performanceSummary: 'Operators maintained normal posture.',
    slaSummary: 'No SLA breach recorded.',
    riskSummary: 'One elevated scene review required attention.',
  ),
  List<SitePerformance> siteComparisons = const [
    SitePerformance(
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      totalIncidents: 3,
      totalEscalations: 1,
      totalSlaBreaches: 0,
      slaComplianceRate: 1,
    ),
  ],
  EscalationTrend escalationTrend = const EscalationTrend(
    clientId: 'CLIENT-MS-VALLEE',
    currentMonth: '2026-03',
    previousMonth: '2026-02',
    currentEscalations: 1,
    previousEscalations: 0,
    escalationDeltaPercent: 100,
    currentSlaBreaches: 0,
    previousSlaBreaches: 0,
    breachDeltaPercent: 0,
  ),
  ClientSnapshot clientSnapshot = const ClientSnapshot(
    clientId: 'CLIENT-MS-VALLEE',
    clientName: 'MS Vallee Residence',
    siteName: 'MS Vallee Residence',
    slaTier: 'PROTECT',
    reportingPeriod: '2026-03',
  ),
  List<GuardPerformanceSnapshot> guardPerformance = const [],
  PatrolPerformanceSnapshot patrolPerformance = const PatrolPerformanceSnapshot(
    scheduledPatrols: 0,
    completedPatrols: 0,
    missedPatrols: 0,
    completionRate: 0,
  ),
  List<IncidentDetailSnapshot> incidentDetails = const [],
  SceneReviewSnapshot sceneReview = const SceneReviewSnapshot(
    totalReviews: 2,
    modelReviews: 1,
    metadataFallbackReviews: 1,
    suppressedActions: 0,
    incidentAlerts: 0,
    repeatUpdates: 1,
    escalationCandidates: 1,
    topPosture: 'escalation candidate',
    highlights: [
      SceneReviewHighlightSnapshot(
        intelligenceId: 'intel-2',
        detectedAt: reportTestHighlightDetectedAt,
        cameraLabel: 'Camera 2',
        sourceLabel: 'metadata:fallback',
        postureLabel: 'escalation candidate',
        decisionLabel: 'Escalation Candidate',
        decisionSummary:
            'Escalated for urgent review because person activity was detected near the boundary.',
        summary: reportTestEscalationSummary,
      ),
    ],
  ),
  ReportBrandingConfiguration brandingConfiguration =
      const ReportBrandingConfiguration(),
  ReportSectionConfiguration sectionConfiguration =
      const ReportSectionConfiguration(),
  SupervisorAssessment supervisorAssessment = const SupervisorAssessment(
    operationalSummary: 'Stable watch period.',
    riskTrend: 'Contained.',
    recommendations: 'Keep the active watch schedule aligned.',
  ),
  CompanyAchievementsSnapshot companyAchievements =
      const CompanyAchievementsSnapshot(highlights: []),
  EmergingThreatSnapshot emergingThreats = const EmergingThreatSnapshot(
    patternsObserved: [],
  ),
}) {
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
