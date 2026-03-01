import 'monthly_report.dart';
import 'executive_summary.dart';
import 'site_performance.dart';
import 'escalation_trend.dart';

class ReportBundle {
  final MonthlyReport monthlyReport;
  final ExecutiveSummary executiveSummary;
  final List<SitePerformance> siteComparisons;
  final EscalationTrend escalationTrend;

  const ReportBundle({
    required this.monthlyReport,
    required this.executiveSummary,
    required this.siteComparisons,
    required this.escalationTrend,
  });
}
