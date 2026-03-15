import 'monthly_report.dart';
import 'executive_summary.dart';
import 'site_performance.dart';
import 'escalation_trend.dart';
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
  final SupervisorAssessment supervisorAssessment;
  final CompanyAchievementsSnapshot companyAchievements;
  final EmergingThreatSnapshot emergingThreats;

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
    required this.supervisorAssessment,
    required this.companyAchievements,
    required this.emergingThreats,
  });
}
