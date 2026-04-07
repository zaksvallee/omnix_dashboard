import 'monthly_report.dart';
import 'executive_summary.dart';
import 'site_performance.dart';
import 'escalation_trend.dart';
import 'report_branding_configuration.dart';
import 'client_narrative_result.dart';
import 'report_section_configuration.dart';
import 'report_sections.dart';

class ReportBundle {
  final MonthlyReport monthlyReport;
  final ExecutiveSummary executiveSummary;

  // Existing analytics
  final List<SitePerformance> siteComparisons;
  final EscalationTrend escalationTrend;

  // Structured Intelligence Sections
  final ClientSnapshot clientSnapshot;
  final List<GuardPerformanceSnapshot> guardPerformance;
  final PatrolPerformanceSnapshot patrolPerformance;
  final List<IncidentDetailSnapshot> incidentDetails;
  final SceneReviewSnapshot sceneReview;
  final ReportBrandingConfiguration brandingConfiguration;
  final ReportSectionConfiguration sectionConfiguration;
  final SupervisorAssessment supervisorAssessment;
  final CompanyAchievementsSnapshot companyAchievements;
  final EmergingThreatSnapshot emergingThreats;
  final ReportNarrativeRequest? narrativeRequest;

  const ReportBundle({
    required this.monthlyReport,
    required this.executiveSummary,
    required this.siteComparisons,
    required this.escalationTrend,
    required this.clientSnapshot,
    required this.guardPerformance,
    required this.patrolPerformance,
    required this.incidentDetails,
    required this.sceneReview,
    this.brandingConfiguration = const ReportBrandingConfiguration(),
    this.sectionConfiguration = const ReportSectionConfiguration(),
    required this.supervisorAssessment,
    required this.companyAchievements,
    required this.emergingThreats,
    this.narrativeRequest,
  });

  ReportBundle withNarrative(ClientNarrativeResult narrative) {
    return ReportBundle(
      monthlyReport: monthlyReport,
      executiveSummary: ExecutiveSummary(
        clientId: executiveSummary.clientId,
        month: executiveSummary.month,
        headline: narrative.executiveHeadline.isNotEmpty
            ? narrative.executiveHeadline
            : executiveSummary.headline,
        performanceSummary: narrative.executivePerformanceSummary.isNotEmpty
            ? narrative.executivePerformanceSummary
            : executiveSummary.performanceSummary,
        slaSummary: narrative.executiveSlaSummary.isNotEmpty
            ? narrative.executiveSlaSummary
            : executiveSummary.slaSummary,
        riskSummary: narrative.executiveRiskSummary.isNotEmpty
            ? narrative.executiveRiskSummary
            : executiveSummary.riskSummary,
      ),
      siteComparisons: siteComparisons,
      escalationTrend: escalationTrend,
      clientSnapshot: clientSnapshot,
      guardPerformance: guardPerformance,
      patrolPerformance: patrolPerformance,
      incidentDetails: incidentDetails,
      sceneReview: sceneReview,
      brandingConfiguration: brandingConfiguration,
      sectionConfiguration: sectionConfiguration,
      supervisorAssessment: SupervisorAssessment(
        operationalSummary: narrative.supervisorOperationalSummary.isNotEmpty
            ? narrative.supervisorOperationalSummary
            : supervisorAssessment.operationalSummary,
        riskTrend: narrative.supervisorRiskTrend.isNotEmpty
            ? narrative.supervisorRiskTrend
            : supervisorAssessment.riskTrend,
        recommendations: narrative.supervisorRecommendations.isNotEmpty
            ? narrative.supervisorRecommendations
            : supervisorAssessment.recommendations,
      ),
      companyAchievements: narrative.companyAchievements.isNotEmpty
          ? CompanyAchievementsSnapshot(
              highlights: narrative.companyAchievements,
            )
          : companyAchievements,
      emergingThreats: narrative.emergingThreats.isNotEmpty
          ? EmergingThreatSnapshot(patternsObserved: narrative.emergingThreats)
          : emergingThreats,
      narrativeRequest: narrativeRequest,
    );
  }
}
