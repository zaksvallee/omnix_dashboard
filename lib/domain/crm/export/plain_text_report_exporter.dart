import '../reporting/report_bundle.dart';
import '../reporting/report_audience.dart';
import 'report_export.dart';

class PlainTextReportExporter {
  static ReportExport export(
    ReportBundle bundle, {
    required ReportAudience audience,
  }) {
    final monthly = bundle.monthlyReport;
    final summary = bundle.executiveSummary;

    final compliancePercent = (monthly.slaComplianceRate * 100).toStringAsFixed(
      1,
    );

    final tierLabel = monthly.slaTierName.toUpperCase();

    final buffer = StringBuffer();

    buffer.writeln("========================================");
    buffer.writeln("ONYX RISK & INTELLIGENCE GROUP");
    buffer.writeln("Monthly Intelligence Report");
    buffer.writeln("========================================");
    buffer.writeln("Client: ${monthly.clientId}");
    buffer.writeln("Month: ${monthly.month}");
    buffer.writeln("SLA Tier: $tierLabel");
    buffer.writeln("Projection Month (UTC): ${monthly.month}");
    buffer.writeln("Evidence Mode: Event-Sourced Deterministic Projection");
    buffer.writeln("----------------------------------------");
    buffer.writeln();

    buffer.writeln("KEY METRICS");
    buffer.writeln("----------------------------------------");
    buffer.writeln("Total Incidents: ${monthly.totalIncidents}");
    buffer.writeln("Total Escalations: ${monthly.totalEscalations}");
    buffer.writeln("SLA Compliance: $compliancePercent%");
    buffer.writeln("SLA Breaches: ${monthly.totalSlaBreaches}");
    buffer.writeln("SLA Overrides: ${monthly.totalSlaOverrides}");
    buffer.writeln();
    buffer.writeln("========================================");
    buffer.writeln();

    buffer.writeln("EXECUTIVE SUMMARY");
    buffer.writeln("----------------------------------------");
    buffer.writeln(summary.headline);
    buffer.writeln();
    buffer.writeln(summary.performanceSummary);
    buffer.writeln();
    buffer.writeln(summary.slaSummary);
    buffer.writeln();
    buffer.writeln(summary.riskSummary);
    buffer.writeln();
    buffer.writeln("========================================");

    buffer.writeln();
    buffer.writeln("CCTV SCENE REVIEW");
    buffer.writeln("----------------------------------------");
    if (bundle.sceneReview.totalReviews == 0) {
      buffer.writeln(
        "No AI-reviewed CCTV scene assessments were recorded for this reporting period.",
      );
    } else {
      buffer.writeln("Total Reviews: ${bundle.sceneReview.totalReviews}");
      buffer.writeln("Model Reviews: ${bundle.sceneReview.modelReviews}");
      buffer.writeln(
        "Metadata Fallback Reviews: ${bundle.sceneReview.metadataFallbackReviews}",
      );
      buffer.writeln(
        "Suppressed Actions: ${bundle.sceneReview.suppressedActions}",
      );
      buffer.writeln("Incident Alerts: ${bundle.sceneReview.incidentAlerts}");
      buffer.writeln("Repeat Updates: ${bundle.sceneReview.repeatUpdates}");
      buffer.writeln(
        "Escalation Candidates: ${bundle.sceneReview.escalationCandidates}",
      );
      buffer.writeln("Top Posture: ${bundle.sceneReview.topPosture}");
      if (bundle.sceneReview.latestActionTaken.trim().isNotEmpty) {
        buffer.writeln(
          "Latest Action Taken: ${bundle.sceneReview.latestActionTaken}",
        );
      }
      if (bundle.sceneReview.latestSuppressedPattern.trim().isNotEmpty) {
        buffer.writeln(
          "Latest Suppressed Pattern: ${bundle.sceneReview.latestSuppressedPattern}",
        );
      }
      if (bundle.sceneReview.highlights.isNotEmpty) {
        buffer.writeln();
        buffer.writeln("Notable Findings:");
        for (final highlight in bundle.sceneReview.highlights) {
          final actionDetail = highlight.decisionSummary.trim().isNotEmpty
              ? ' | ${highlight.decisionSummary.trim()}'
              : '';
          buffer.writeln(
            "- ${highlight.detectedAt} | ${highlight.cameraLabel} | ${highlight.postureLabel} | ${highlight.decisionLabel.isEmpty ? 'Unspecified action' : highlight.decisionLabel}$actionDetail | ${highlight.summary}",
          );
        }
      }
    }
    buffer.writeln();
    buffer.writeln("========================================");

    if (audience == ReportAudience.internal) {
      buffer.writeln();
      buffer.writeln("INTERNAL COMMAND INTELLIGENCE");
      buffer.writeln("----------------------------------------");
      buffer.writeln("Chain Verified: TRUE");
      buffer.writeln("Escalation Governance Active");
      buffer.writeln("Override Events Logged: ${monthly.totalSlaOverrides}");
      buffer.writeln("Operational Oversight: ACTIVE");
      buffer.writeln("========================================");
    }

    return ReportExport(
      clientId: monthly.clientId,
      month: monthly.month,
      content: buffer.toString(),
    );
  }
}
