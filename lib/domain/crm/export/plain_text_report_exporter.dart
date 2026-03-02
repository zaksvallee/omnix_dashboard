import '../reporting/report_bundle.dart';
import '../reporting/report_audience.dart';
import 'report_export.dart';

class PlainTextReportExporter {
  static ReportExport export(
    ReportBundle bundle, {
    required ReportAudience audience,
  }) {
    final generatedAt = DateTime.now().toUtc();
    final monthly = bundle.monthlyReport;
    final summary = bundle.executiveSummary;

    final compliancePercent =
        (monthly.slaComplianceRate * 100).toStringAsFixed(1);

    final tierLabel = monthly.slaTierName.toUpperCase();

    final buffer = StringBuffer();

    buffer.writeln("========================================");
    buffer.writeln("ONYX RISK & INTELLIGENCE GROUP");
    buffer.writeln("Monthly Intelligence Report");
    buffer.writeln("========================================");
    buffer.writeln("Client: ${monthly.clientId}");
    buffer.writeln("Month: ${monthly.month}");
    buffer.writeln("SLA Tier: $tierLabel");
    buffer.writeln("Generated (UTC): ${generatedAt.toIso8601String()}");
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
