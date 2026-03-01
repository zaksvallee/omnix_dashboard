import '../reporting/report_bundle.dart';
import 'report_export.dart';

class PlainTextReportExporter {
  static ReportExport export(ReportBundle bundle) {
    final generatedAt = DateTime.now().toUtc();

    final monthly = bundle.monthlyReport;
    final summary = bundle.executiveSummary;

    final buffer = StringBuffer();

    buffer.writeln("========================================");
    buffer.writeln("ONYX RISK & INTELLIGENCE GROUP");
    buffer.writeln("Monthly Intelligence Report");
    buffer.writeln("========================================");
    buffer.writeln("Client: ${monthly.clientId}");
    buffer.writeln("Month: ${monthly.month}");
    buffer.writeln("Generated (UTC): ${generatedAt.toIso8601String()}");
    buffer.writeln("Evidence Mode: Event-Sourced Deterministic Projection");
    buffer.writeln("----------------------------------------");
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

    return ReportExport(
      clientId: monthly.clientId,
      month: monthly.month,
      content: buffer.toString(),
    );
  }
}
