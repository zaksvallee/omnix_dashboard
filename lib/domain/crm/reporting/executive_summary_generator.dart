import 'monthly_report.dart';
import 'executive_summary.dart';

class ExecutiveSummaryGenerator {
  static ExecutiveSummary generate(MonthlyReport report) {
    final headline = _buildHeadline(report);
    final performanceSummary = _buildPerformance(report);
    final slaSummary = _buildSlaSummary(report);
    final riskSummary = _buildRiskSummary(report);

    return ExecutiveSummary(
      clientId: report.clientId,
      month: report.month,
      headline: headline,
      performanceSummary: performanceSummary,
      slaSummary: slaSummary,
      riskSummary: riskSummary,
    );
  }

  static String _buildHeadline(MonthlyReport report) {
    if (report.slaComplianceRate >= 0.95) {
      return "Operational stability maintained with strong SLA adherence.";
    } else if (report.slaComplianceRate >= 0.85) {
      return "Operational performance stable with minor SLA variances.";
    } else {
      return "Operational pressure observed with SLA risk exposure.";
    }
  }

  static String _buildPerformance(MonthlyReport report) {
    return "A total of ${report.totalIncidents} incidents were recorded during ${report.month}, "
        "with ${report.totalEscalations} escalations requiring elevated attention.";
  }

  static String _buildSlaSummary(MonthlyReport report) {
    final compliancePercent =
        (report.slaComplianceRate * 100).toStringAsFixed(1);

    final tierLabel = report.slaTierName.toUpperCase();

    return "Client is operating under the $tierLabel SLA tier. "
        "SLA compliance for the reporting period was $compliancePercent%. "
        "${report.totalSlaBreaches} breach events were detected and logged, "
        "with ${report.totalSlaOverrides} override actions formally recorded.";
  }

  static String _buildRiskSummary(MonthlyReport report) {
    if (report.totalSlaBreaches == 0) {
      return "No structural SLA risk patterns detected during this period.";
    } else if (report.totalSlaBreaches <= 3) {
      return "Isolated SLA breaches occurred but remain within manageable tolerance.";
    } else {
      return "Repeated SLA breaches indicate systemic risk requiring review.";
    }
  }
}
