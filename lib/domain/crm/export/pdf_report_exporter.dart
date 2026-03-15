import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../reporting/report_branding_configuration.dart';
import '../reporting/report_bundle.dart';

class PDFReportExporter {
  static final PdfColor _bgDark = PdfColor.fromHex('#20303A');
  static final PdfColor _inkPrimary = PdfColor.fromHex('#1D2B36');
  static final PdfColor _inkSecondary = PdfColor.fromHex('#506273');
  static final PdfColor _line = PdfColor.fromHex('#D6DEE8');
  static final PdfColor _chipBlue = PdfColor.fromHex('#EAF4FF');
  static final PdfColor _chipBlueBorder = PdfColor.fromHex('#BED7F6');
  static final PdfColor _chipGreen = PdfColor.fromHex('#EDF9F0');
  static final PdfColor _chipGreenBorder = PdfColor.fromHex('#BEE7C7');
  static final PdfColor _chipAmber = PdfColor.fromHex('#FFF7E8');
  static final PdfColor _chipAmberBorder = PdfColor.fromHex('#F2DBA3');
  static final PdfColor _chipRed = PdfColor.fromHex('#FFF1F1');
  static final PdfColor _chipRedBorder = PdfColor.fromHex('#F4B8B8');
  static final PdfColor _chipSlate = PdfColor.fromHex('#F1F5F9');
  static final PdfColor _chipSlateBorder = PdfColor.fromHex('#CBD5E1');

  static Future<Uint8List> generate(ReportBundle bundle) async {
    final fontData = await rootBundle.load('assets/fonts/Inter-Variable.ttf');
    final font = pw.Font.ttf(fontData);
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: font,
        italic: font,
        boldItalic: font,
      ),
    );
    final logoBytes = await rootBundle.load('assets/images/onyx_logo.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(38, 34, 38, 34),
        footer: (context) =>
            _buildFooter(context, bundle.brandingConfiguration),
        build: (context) => [
          _buildCoverHeader(bundle, logoImage),
          pw.SizedBox(height: 16),
          _buildKpiRow(bundle),
          pw.SizedBox(height: 20),
          _buildSectionTitle('EXECUTIVE SUMMARY'),
          _buildExecutiveCard(bundle),
          if (bundle.sectionConfiguration.includeAiDecisionLog) ...[
            pw.SizedBox(height: 20),
            _buildSectionTitle('CCTV SCENE REVIEW'),
            _buildSceneReviewSection(bundle),
          ],
          if (bundle.sectionConfiguration.includeTimeline) ...[
            pw.SizedBox(height: 20),
            _buildSectionTitle('INCIDENT REGISTER'),
            bundle.incidentDetails.isEmpty
                ? _buildInfoCard(
                    'No incidents recorded for this reporting period.',
                  )
                : _buildIncidentTable(bundle),
          ],
          if (bundle.sectionConfiguration.includeDispatchSummary) ...[
            pw.SizedBox(height: 20),
            _buildSectionTitle('SLA PERFORMANCE SUMMARY'),
            _buildSlaSummary(bundle),
          ],
          if (bundle.sectionConfiguration.includeCheckpointCompliance) ...[
            pw.SizedBox(height: 20),
            _buildSectionTitle('PATROL EXECUTION SUMMARY'),
            _buildPatrolSummary(bundle),
          ],
          if (bundle.sectionConfiguration.includeGuardMetrics) ...[
            pw.SizedBox(height: 20),
            _buildSectionTitle('GUARD PERFORMANCE MATRIX'),
            _buildGuardPerformanceSection(bundle),
          ],
          pw.SizedBox(height: 18),
          _buildSectionTitle('OPERATIONAL APPENDIX'),
          _buildOperationalAppendix(bundle),
          pw.SizedBox(height: 12),
          pw.Text(
            'Deterministic event-sourced projection.',
            style: pw.TextStyle(fontSize: 9.5, color: _inkSecondary),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildFooter(
    pw.Context context,
    ReportBrandingConfiguration branding,
  ) {
    final footerLabel = branding.primaryLabel.trim().isNotEmpty
        ? branding.primaryLabel.trim()
        : 'ONYX SECURITY';
    final footerDetail = branding.endorsementLine.trim().isNotEmpty
        ? '$footerLabel • ${branding.endorsementLine.trim()}'
        : '$footerLabel - Operational Intelligence Brief';
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            footerDetail,
            style: pw.TextStyle(fontSize: 9.5, color: _inkSecondary),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 9.5, color: _inkSecondary),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCoverHeader(ReportBundle bundle, pw.MemoryImage logo) {
    final branding = bundle.brandingConfiguration;
    final hasPrimaryBrand = branding.primaryLabel.trim().isNotEmpty;
    final hasEndorsement = branding.endorsementLine.trim().isNotEmpty;
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: _bgDark,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 84,
            height: 84,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('#3F515E')),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            padding: const pw.EdgeInsets.all(10),
            child: pw.Image(logo),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CONFIDENTIAL',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 11.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                pw.SizedBox(height: 7),
                if (hasPrimaryBrand) ...[
                  pw.Text(
                    branding.primaryLabel.trim().toUpperCase(),
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                ],
                if (hasEndorsement) ...[
                  pw.Text(
                    branding.endorsementLine.trim(),
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('#BFD5EA'),
                      fontSize: 12.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                ],
                pw.Text(
                  'OPERATIONAL INTELLIGENCE BRIEF',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                _metaLine('Client', bundle.clientSnapshot.clientId),
                _metaLine(
                  'Reporting Period',
                  bundle.clientSnapshot.reportingPeriod,
                ),
                _metaLine('SLA Tier', bundle.clientSnapshot.slaTier),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _metaLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Text(
        '$label: $value',
        style: pw.TextStyle(color: PdfColor.fromHex('#E4ECF5'), fontSize: 12.5),
      ),
    );
  }

  static pw.Widget _buildKpiRow(ReportBundle bundle) {
    final incidents = bundle.monthlyReport.totalIncidents.toString();
    final escalations = bundle.monthlyReport.totalEscalations.toString();
    final compliance =
        '${(bundle.monthlyReport.slaComplianceRate * 100).toStringAsFixed(1)}%';

    return pw.Row(
      children: [
        pw.Expanded(
          child: _kpiCard('Incidents', incidents, _chipBlue, _chipBlueBorder),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _kpiCard(
            'Escalations',
            escalations,
            _chipAmber,
            _chipAmberBorder,
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _kpiCard(
            'Compliance',
            compliance,
            _chipGreen,
            _chipGreenBorder,
          ),
        ),
      ],
    );
  }

  static pw.Widget _kpiCard(
    String label,
    String value,
    PdfColor bg,
    PdfColor border,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: bg,
        border: pw.Border.all(color: border),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 11.5,
              color: _inkSecondary,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 22,
              color: _inkPrimary,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line, width: 1)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 16.5,
          fontWeight: pw.FontWeight.bold,
          color: _inkPrimary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  static pw.Widget _buildExecutiveCard(ReportBundle bundle) {
    final summary = bundle.executiveSummary;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F7FAFF'),
        border: pw.Border.all(color: _line),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _paragraph(summary.headline),
          pw.SizedBox(height: 6),
          _paragraph(summary.performanceSummary),
          pw.SizedBox(height: 6),
          _paragraph(summary.slaSummary),
          pw.SizedBox(height: 6),
          _paragraph(summary.riskSummary),
        ],
      ),
    );
  }

  static pw.Widget _paragraph(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(fontSize: 12.2, color: _inkPrimary, lineSpacing: 3),
    );
  }

  static pw.Widget _buildInfoCard(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F9FBFD'),
        border: pw.Border.all(color: _line),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 11.7, color: _inkPrimary),
      ),
    );
  }

  static pw.Widget _buildIncidentTable(ReportBundle bundle) {
    return pw.TableHelper.fromTextArray(
      headers: const [
        'Incident ID',
        'Risk',
        'Detected',
        'SLA Result',
        'Override',
      ],
      data: bundle.incidentDetails.map((i) {
        return [
          i.incidentId,
          i.riskCategory,
          i.detectedAt,
          i.slaResult,
          i.overrideApplied ? 'YES' : 'NO',
        ];
      }).toList(),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: _inkPrimary,
        fontSize: 10.5,
      ),
      cellStyle: pw.TextStyle(fontSize: 10, color: _inkPrimary),
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#EAF1F8')),
      oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F8FBFF')),
      border: pw.TableBorder.all(color: _line, width: 0.7),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    );
  }

  static pw.Widget _buildSlaSummary(ReportBundle bundle) {
    final breaches = bundle.monthlyReport.totalSlaBreaches;
    final overrides = bundle.monthlyReport.totalSlaOverrides;
    final compliance = (bundle.monthlyReport.slaComplianceRate * 100)
        .toStringAsFixed(1);

    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _metricPill(
          'Total SLA Breaches',
          breaches.toString(),
          _chipRed,
          _chipRedBorder,
        ),
        _metricPill(
          'Total SLA Overrides',
          overrides.toString(),
          _chipAmber,
          _chipAmberBorder,
        ),
        _metricPill(
          'Compliance Rate',
          '$compliance%',
          _chipGreen,
          _chipGreenBorder,
        ),
      ],
    );
  }

  static pw.Widget _buildSceneReviewSection(ReportBundle bundle) {
    final sceneReview = bundle.sceneReview;
    if (sceneReview.totalReviews == 0) {
      return _buildInfoCard(
        'No AI-reviewed CCTV scene assessments were recorded for this reporting period.',
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _metricPill(
              'Total Reviews',
              sceneReview.totalReviews.toString(),
              _chipBlue,
              _chipBlueBorder,
            ),
            _metricPill(
              'Model Reviews',
              sceneReview.modelReviews.toString(),
              _chipGreen,
              _chipGreenBorder,
            ),
            _metricPill(
              'Metadata Fallback',
              sceneReview.metadataFallbackReviews.toString(),
              _chipAmber,
              _chipAmberBorder,
            ),
            _metricPill(
              'Suppressed',
              sceneReview.suppressedActions.toString(),
              _chipSlate,
              _chipSlateBorder,
            ),
            _metricPill(
              'Alerts',
              sceneReview.incidentAlerts.toString(),
              _chipBlue,
              _chipBlueBorder,
            ),
            _metricPill(
              'Repeat Updates',
              sceneReview.repeatUpdates.toString(),
              _chipAmber,
              _chipAmberBorder,
            ),
            _metricPill(
              'Escalation Candidates',
              sceneReview.escalationCandidates.toString(),
              _chipRed,
              _chipRedBorder,
            ),
            _metricPill(
              'Top Posture',
              sceneReview.topPosture,
              _chipBlue,
              _chipBlueBorder,
            ),
          ],
        ),
        if (sceneReview.latestActionTaken.trim().isNotEmpty) ...[
          pw.SizedBox(height: 10),
          _buildInfoCard(
            'Latest action taken: ${sceneReview.latestActionTaken}',
          ),
        ],
        if (sceneReview.latestSuppressedPattern.trim().isNotEmpty) ...[
          pw.SizedBox(height: 10),
          _buildInfoCard(
            'Latest filtered pattern: ${sceneReview.latestSuppressedPattern}',
          ),
        ],
        if (sceneReview.highlights.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          pw.Text(
            'Notable Findings',
            style: pw.TextStyle(
              fontSize: 11.5,
              fontWeight: pw.FontWeight.bold,
              color: _inkPrimary,
            ),
          ),
          pw.SizedBox(height: 4),
          ...sceneReview.highlights.map((highlight) {
            final actionDetail = highlight.decisionSummary.trim().isNotEmpty
                ? ' • ${highlight.decisionSummary.trim()}'
                : '';
            return pw.Bullet(
              text:
                  '${highlight.detectedAt} • ${highlight.cameraLabel} • ${highlight.postureLabel} • ${highlight.decisionLabel.isEmpty ? 'Unspecified action' : highlight.decisionLabel}$actionDetail • ${highlight.summary}',
              style: pw.TextStyle(fontSize: 10.8, color: _inkPrimary),
            );
          }),
        ],
      ],
    );
  }

  static pw.Widget _buildPatrolSummary(ReportBundle bundle) {
    final patrol = bundle.patrolPerformance;
    final completionRate = (patrol.completionRate * 100).toStringAsFixed(1);

    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _metricPill(
          'Scheduled Patrols',
          patrol.scheduledPatrols.toString(),
          _chipBlue,
          _chipBlueBorder,
        ),
        _metricPill(
          'Completed Patrols',
          patrol.completedPatrols.toString(),
          _chipGreen,
          _chipGreenBorder,
        ),
        _metricPill(
          'Missed Patrols',
          patrol.missedPatrols.toString(),
          _chipAmber,
          _chipAmberBorder,
        ),
        _metricPill(
          'Patrol Compliance',
          '$completionRate%',
          _chipBlue,
          _chipBlueBorder,
        ),
      ],
    );
  }

  static pw.Widget _metricPill(
    String label,
    String value,
    PdfColor bg,
    PdfColor border,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: bg,
        border: pw.Border.all(color: border),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(
                fontSize: 10.5,
                color: _inkSecondary,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(
                fontSize: 11,
                color: _inkPrimary,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildGuardPerformanceSection(ReportBundle bundle) {
    final guards = bundle.guardPerformance;

    if (guards.isEmpty) {
      return _buildInfoCard(
        'No guard performance data recorded for this period.',
      );
    }

    final topGuard = guards.reduce(
      (a, b) => a.compliancePercentage > b.compliancePercentage ? a : b,
    );

    final riskGuards = guards
        .where((g) => g.compliancePercentage < 80)
        .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.TableHelper.fromTextArray(
          headers: const [
            'Name',
            'ID',
            'PSIRA',
            'Rank',
            'Compliance %',
            'Escalations',
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
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: _inkPrimary,
            fontSize: 10.5,
          ),
          cellStyle: pw.TextStyle(fontSize: 10, color: _inkPrimary),
          headerDecoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#EAF1F8'),
          ),
          oddRowDecoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F8FBFF'),
          ),
          border: pw.TableBorder.all(color: _line, width: 0.7),
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 5,
          ),
        ),
        pw.SizedBox(height: 10),
        _buildInfoCard(
          'Top Operational Performer: ${topGuard.guardName} (${topGuard.compliancePercentage.toStringAsFixed(1)}% compliance)',
        ),
        pw.SizedBox(height: 8),
        if (riskGuards.isNotEmpty)
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _chipRed,
              border: pw.Border.all(color: _chipRedBorder),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              'Performance Risk Flags: ${riskGuards.map((g) => g.guardName).join(', ')}',
              style: pw.TextStyle(
                color: PdfColor.fromHex('#9A2E2E'),
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildOperationalAppendix(ReportBundle bundle) {
    final highlights = bundle.companyAchievements.highlights;
    final threats = bundle.emergingThreats.patternsObserved;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildInfoCard(bundle.supervisorAssessment.operationalSummary),
        pw.SizedBox(height: 8),
        _buildInfoCard('Risk Trend: ${bundle.supervisorAssessment.riskTrend}'),
        pw.SizedBox(height: 8),
        _buildInfoCard(
          'Recommendations: ${bundle.supervisorAssessment.recommendations}',
        ),
        if (highlights.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          pw.Text(
            'Company Achievements',
            style: pw.TextStyle(
              fontSize: 11.5,
              fontWeight: pw.FontWeight.bold,
              color: _inkPrimary,
            ),
          ),
          pw.SizedBox(height: 4),
          ...highlights
              .take(4)
              .map(
                (line) => pw.Bullet(
                  text: line,
                  style: pw.TextStyle(fontSize: 10.8, color: _inkPrimary),
                ),
              ),
        ],
        if (threats.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text(
            'Emerging Threat Signals',
            style: pw.TextStyle(
              fontSize: 11.5,
              fontWeight: pw.FontWeight.bold,
              color: _inkPrimary,
            ),
          ),
          pw.SizedBox(height: 4),
          ...threats
              .take(4)
              .map(
                (line) => pw.Bullet(
                  text: line,
                  style: pw.TextStyle(fontSize: 10.8, color: _inkPrimary),
                ),
              ),
        ],
      ],
    );
  }
}
