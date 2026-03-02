import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;

import '../reporting/report_bundle.dart';

class PDFReportExporter {
  static Future<Uint8List> generate(ReportBundle bundle) async {
    final pdf = pw.Document();

    final logoBytes =
        await rootBundle.load('assets/images/onyx_logo.png');
    final logoImage =
        pw.MemoryImage(logoBytes.buffer.asUint8List());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            "Page ${context.pageNumber} of ${context.pagesCount}",
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        build: (context) => [

          _buildHeader(bundle, logoImage),
          pw.SizedBox(height: 25),
          _buildKPI(bundle),
          pw.SizedBox(height: 30),
          _buildExecutive(bundle),
          pw.SizedBox(height: 30),

          pw.Divider(),

          pw.Header(level: 1, text: "INCIDENT REGISTER"),
          bundle.incidentDetails.isEmpty
              ? pw.Text("No incidents recorded for this reporting period.")
              : _buildIncidentTable(bundle),

          pw.SizedBox(height: 25),

          pw.Header(level: 1, text: "SLA PERFORMANCE SUMMARY"),
          pw.Bullet(text: "Total SLA Breaches: ${bundle.monthlyReport.totalSlaBreaches}"),
          pw.Bullet(text: "Total SLA Overrides: ${bundle.monthlyReport.totalSlaOverrides}"),
          pw.Bullet(text: "Compliance Rate: ${(bundle.monthlyReport.slaComplianceRate * 100).toStringAsFixed(1)}%"),

          pw.SizedBox(height: 25),

          _buildPatrolSection(bundle),

          pw.SizedBox(height: 25),

          _buildGuardPerformanceSection(bundle),

          pw.SizedBox(height: 20),

          pw.Text(
            "Generated: ${DateTime.now().toUtc()}",
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            "Deterministic event-sourced projection.",
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildGuardPerformanceSection(ReportBundle bundle) {
    final guards = bundle.guardPerformance;

    if (guards.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Header(level: 1, text: "GUARD PERFORMANCE MATRIX"),
          pw.Text("No guard performance data recorded for this period."),
        ],
      );
    }

    final topGuard = guards.reduce((a, b) =>
        a.compliancePercentage > b.compliancePercentage ? a : b);

    final riskGuards = guards
        .where((g) => g.compliancePercentage < 80)
        .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 1, text: "GUARD PERFORMANCE MATRIX"),

        pw.TableHelper.fromTextArray(
          headers: [
            "Name",
            "ID",
            "PSIRA",
            "Rank",
            "Compliance %",
            "Escalations"
          ],
          data: guards.map((g) {
            return [
              g.guardName,
              g.idNumber,
              g.psiraNumber,
              g.rank,
              g.compliancePercentage.toStringAsFixed(1),
              g.escalationsHandled.toString(),
            ];
          }).toList(),
        ),

        pw.SizedBox(height: 12),

        pw.Text(
          "Top Operational Performer: ${topGuard.guardName} (${topGuard.compliancePercentage.toStringAsFixed(1)}% compliance)",
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),

        pw.SizedBox(height: 6),

        riskGuards.isEmpty
            ? pw.Text("No performance risk flags detected.")
            : pw.Text(
                "Performance Risk Flags: ${riskGuards.map((g) => g.guardName).join(', ')}",
                style: pw.TextStyle(color: PdfColors.red),
              ),
      ],
    );
  }

  static pw.Widget _buildPatrolSection(ReportBundle bundle) {
    final patrol = bundle.patrolPerformance;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 1, text: "PATROL EXECUTION SUMMARY"),
        pw.Bullet(text: "Scheduled Patrols: ${patrol.scheduledPatrols}"),
        pw.Bullet(text: "Completed Patrols: ${patrol.completedPatrols}"),
        pw.Bullet(text: "Missed Patrols: ${patrol.missedPatrols}"),
        pw.Bullet(
            text:
                "Patrol Compliance: ${(patrol.completionRate * 100).toStringAsFixed(1)}%"),
      ],
    );
  }

  static pw.Widget _buildHeader(
      ReportBundle bundle, pw.MemoryImage logo) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      color: PdfColors.blueGrey900,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Image(logo, height: 60),
          pw.SizedBox(width: 20),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("CONFIDENTIAL",
                  style: const pw.TextStyle(color: PdfColors.white)),
              pw.SizedBox(height: 8),
              pw.Text("OPERATIONAL INTELLIGENCE BRIEF",
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text(
                  "Client: ${bundle.clientSnapshot.clientId}",
                  style: const pw.TextStyle(color: PdfColors.white)),
              pw.Text(
                  "Reporting Period: ${bundle.clientSnapshot.reportingPeriod}",
                  style: const pw.TextStyle(color: PdfColors.white)),
              pw.Text(
                  "SLA Tier: ${bundle.clientSnapshot.slaTier}",
                  style: const pw.TextStyle(color: PdfColors.white)),
            ],
          )
        ],
      ),
    );
  }

  static pw.Widget _buildKPI(ReportBundle bundle) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _kpiBox("Incidents",
            bundle.monthlyReport.totalIncidents.toString()),
        _kpiBox("Escalations",
            bundle.monthlyReport.totalEscalations.toString()),
        _kpiBox(
            "Compliance",
            "${(bundle.monthlyReport.slaComplianceRate * 100).toStringAsFixed(1)}%"),
      ],
    );
  }

  static pw.Widget _buildExecutive(ReportBundle bundle) {
    final summary = bundle.executiveSummary;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 1, text: "EXECUTIVE SUMMARY"),
        pw.Paragraph(text: summary.headline),
        pw.Paragraph(text: summary.performanceSummary),
        pw.Paragraph(text: summary.slaSummary),
        pw.Paragraph(text: summary.riskSummary),
      ],
    );
  }

  static pw.Widget _buildIncidentTable(
      ReportBundle bundle) {
    return pw.TableHelper.fromTextArray(
      headers: [
        "Incident ID",
        "Risk",
        "Detected",
        "SLA Result",
        "Override"
      ],
      data: bundle.incidentDetails.map((i) {
        return [
          i.incidentId,
          i.riskCategory,
          i.detectedAt,
          i.slaResult,
          i.overrideApplied ? "YES" : "NO",
        ];
      }).toList(),
    );
  }

  static pw.Widget _kpiBox(
      String title, String value) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        children: [
          pw.Text(title,
              style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 6),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
