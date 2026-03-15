import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';

import '../../domain/crm/reporting/report_branding_configuration.dart';
import '../../domain/crm/export/pdf_report_exporter.dart';
import '../../domain/crm/reporting/report_bundle.dart';
import '../../domain/events/report_generated.dart';
import '../../ui/onyx_surface.dart';

class ReportPreviewPage extends StatefulWidget {
  final ReportBundle bundle;
  final Uint8List? initialPdfBytes;
  final ReportGenerated? receiptEvent;
  final bool? replayMatches;

  const ReportPreviewPage({
    super.key,
    required this.bundle,
    this.initialPdfBytes,
    this.receiptEvent,
    this.replayMatches,
  });

  @override
  State<ReportPreviewPage> createState() => _ReportPreviewPageState();
}

class _ReportPreviewPageState extends State<ReportPreviewPage> {
  Uint8List? _pdfBytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final bytes =
        widget.initialPdfBytes ??
        await PDFReportExporter.generate(widget.bundle);
    setState(() {
      _pdfBytes = bytes;
      _loading = false;
    });
  }

  String _shortHash(String hash) {
    if (hash.length <= 20) return hash;
    return '${hash.substring(0, 20)}...';
  }

  ReportBrandingConfiguration get _brandingConfiguration =>
      widget.receiptEvent?.brandingConfiguration ??
      widget.bundle.brandingConfiguration;

  String get _pdfFileName {
    final primaryLabel = _brandingConfiguration.primaryLabel
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (primaryLabel.isEmpty) {
      return 'onyx_intelligence_report.pdf';
    }
    return '${primaryLabel}_intelligence_report.pdf';
  }

  Widget _brandingPane() {
    final branding = _brandingConfiguration;
    if (!branding.isConfigured) {
      return const SizedBox.shrink();
    }
    return OnyxSectionCard(
      title: 'Branding',
      subtitle:
          'Client-facing cover identity that will be stamped onto this generated PDF.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1A2B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF17324F)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              branding.primaryLabel,
              style: GoogleFonts.rajdhani(
                color: const Color(0xFFE8F1FF),
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (branding.endorsementLine.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                branding.endorsementLine,
                style: GoogleFonts.inter(
                  color: const Color(0xFF8FD1FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sceneReviewPane() {
    final sceneReview = widget.bundle.sceneReview;
    final highlights = sceneReview.highlights;
    final aiDecisionLogIncluded =
        widget.bundle.sectionConfiguration.includeAiDecisionLog;
    return OnyxSectionCard(
      title: 'Scene Review Brief',
      subtitle: aiDecisionLogIncluded
          ? 'CCTV review posture used to shape this report before PDF distribution.'
          : 'This section was omitted from the generated PDF by the active report configuration.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!aiDecisionLogIncluded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1A2B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF17324F)),
              ),
              child: Text(
                'AI decision log was disabled for this report. The generated PDF excludes CCTV scene review details even if operator review data exists in the workspace.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF94ABCB),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  'Reviews',
                  '${sceneReview.totalReviews}',
                  const Color(0xFF63BDFF),
                ),
                _chip(
                  'Model',
                  '${sceneReview.modelReviews}',
                  const Color(0xFF79D89A),
                ),
                _chip(
                  'Fallback',
                  '${sceneReview.metadataFallbackReviews}',
                  const Color(0xFFF6C067),
                ),
                _chip(
                  'Suppressed',
                  '${sceneReview.suppressedActions}',
                  const Color(0xFF9AA7BA),
                ),
                _chip(
                  'Alerts',
                  '${sceneReview.incidentAlerts}',
                  const Color(0xFF63BDFF),
                ),
                _chip(
                  'Repeat',
                  '${sceneReview.repeatUpdates}',
                  const Color(0xFFF6C067),
                ),
                _chip(
                  'Escalations',
                  '${sceneReview.escalationCandidates}',
                  sceneReview.escalationCandidates > 0
                      ? const Color(0xFFFF7A7A)
                      : const Color(0xFF8AA4C9),
                ),
                _chip(
                  'Top Posture',
                  sceneReview.topPosture.toUpperCase(),
                  const Color(0xFF8AA4C9),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sceneReview.totalReviews == 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1A2B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF17324F)),
                ),
                child: Text(
                  'No AI-reviewed CCTV scene assessments were recorded for this reporting period.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94ABCB),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sceneReview.latestActionTaken.trim().isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1A2B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF17324F)),
                      ),
                      child: Text(
                        'Latest action taken: ${sceneReview.latestActionTaken}',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFB9C8DA),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (sceneReview.latestSuppressedPattern
                      .trim()
                      .isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1A2B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF17324F)),
                      ),
                      child: Text(
                        'Latest filtered pattern: ${sceneReview.latestSuppressedPattern}',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFB9C8DA),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    'Notable Findings',
                    style: GoogleFonts.rajdhani(
                      color: const Color(0xFFE8F1FF),
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final highlight in highlights)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1A2B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF17324F)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _chip(
                                  'Camera',
                                  highlight.cameraLabel,
                                  const Color(0xFF63BDFF),
                                ),
                                _chip(
                                  'Posture',
                                  highlight.postureLabel.toUpperCase(),
                                  const Color(0xFFF6C067),
                                ),
                                _chip(
                                  'Action',
                                  highlight.decisionLabel.trim().isEmpty
                                      ? 'Unspecified action'
                                      : highlight.decisionLabel,
                                  _decisionColor(highlight.decisionLabel),
                                ),
                                _chip(
                                  'Source',
                                  highlight.sourceLabel,
                                  const Color(0xFF8AA4C9),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (highlight.decisionSummary
                                .trim()
                                .isNotEmpty) ...[
                              Text(
                                'ONYX action: ${highlight.decisionSummary}',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFB9C8DA),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              highlight.summary,
                              style: GoogleFonts.inter(
                                color: const Color(0xFFD9E7FA),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Detected ${highlight.detectedAt}',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF8EA4C2),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _reportConfigurationPane() {
    final config = widget.bundle.sectionConfiguration;
    return OnyxSectionCard(
      title: 'Report Configuration',
      subtitle: 'Included and omitted sections for this generated brief.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _configurationChip(
            'Incident Timeline',
            enabled: config.includeTimeline,
          ),
          _configurationChip(
            'Dispatch Summary',
            enabled: config.includeDispatchSummary,
          ),
          _configurationChip(
            'Checkpoint Compliance',
            enabled: config.includeCheckpointCompliance,
          ),
          _configurationChip(
            'AI Decision Log',
            enabled: config.includeAiDecisionLog,
          ),
          _configurationChip(
            'Guard Metrics',
            enabled: config.includeGuardMetrics,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const OnyxPageScaffold(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final phoneLayout = MediaQuery.sizeOf(context).width < 900;
    final receipt = widget.receiptEvent;
    final replayMatched = widget.replayMatches == true;
    final receiptSummary = receipt == null
        ? const SizedBox.shrink()
        : LayoutBuilder(
            builder: (context, constraints) {
              if (!phoneLayout) {
                return Row(
                  children: [
                    Expanded(
                      child: OnyxSummaryStat(
                        label: 'Receipt',
                        value: receipt.eventId,
                        accent: const Color(0xFF63BDFF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OnyxSummaryStat(
                        label: 'Replay',
                        value: replayMatched ? 'Matched' : 'Failed',
                        accent: replayMatched
                            ? const Color(0xFF59D79B)
                            : const Color(0xFFFF7A7A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OnyxSummaryStat(
                        label: 'Range',
                        value:
                            '${receipt.eventRangeStart}-${receipt.eventRangeEnd}',
                        accent: const Color(0xFFF6C067),
                      ),
                    ),
                  ],
                );
              }
              final spacing = 10.0;
              final cardWidth = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: OnyxSummaryStat(
                      label: 'Receipt',
                      value: receipt.eventId,
                      accent: const Color(0xFF63BDFF),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: OnyxSummaryStat(
                      label: 'Replay',
                      value: replayMatched ? 'Matched' : 'Failed',
                      accent: replayMatched
                          ? const Color(0xFF59D79B)
                          : const Color(0xFFFF7A7A),
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth,
                    child: OnyxSummaryStat(
                      label: 'Range',
                      value:
                          '${receipt.eventRangeStart}-${receipt.eventRangeEnd}',
                      accent: const Color(0xFFF6C067),
                    ),
                  ),
                ],
              );
            },
          );
    final previewPane = OnyxSectionCard(
      title: 'PDF Preview',
      subtitle:
          'Use this viewer as the final operator checkpoint before print or distribution.',
      flexibleChild: !phoneLayout,
      child: phoneLayout
          ? SizedBox(
              height: 560,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: PdfPreview(
                  pdfFileName: _pdfFileName,
                  canDebug: false,
                  useActions: false,
                  allowPrinting: false,
                  allowSharing: false,
                  build: (format) async => _pdfBytes!,
                ),
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: PdfPreview(
                pdfFileName: _pdfFileName,
                canDebug: false,
                useActions: false,
                allowPrinting: false,
                allowSharing: false,
                build: (format) async => _pdfBytes!,
              ),
            ),
    );

    return OnyxPageScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: phoneLayout
            ? SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OnyxPageHeader(
                      title: _brandingConfiguration.isConfigured
                          ? '${_brandingConfiguration.primaryLabel} PDF'
                          : 'Operational Intelligence PDF',
                      subtitle:
                          'Preview, verify, print, and distribute deterministic report output.',
                      actions: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF0E1A2B),
                            side: const BorderSide(color: Color(0xFF1C3153)),
                          ),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFFBFD2EE),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await Printing.layoutPdf(
                              onLayout: (format) async => _pdfBytes!,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8AD6FF),
                            side: const BorderSide(color: Color(0xFF286AB8)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                          icon: const Icon(Icons.print_rounded),
                          label: const Text('Print'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await Printing.sharePdf(
                              bytes: _pdfBytes!,
                              filename: _pdfFileName,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF225182),
                            foregroundColor: const Color(0xFFE6F1FF),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Download'),
                        ),
                      ],
                    ),
                    if (_brandingConfiguration.isConfigured) ...[
                      const SizedBox(height: 14),
                      _brandingPane(),
                    ],
                    if (receipt != null) ...[
                      const SizedBox(height: 14),
                      receiptSummary,
                      const SizedBox(height: 14),
                      OnyxSectionCard(
                        title: 'Receipt Integrity',
                        subtitle:
                            'Current report receipt, content hash, event range, and replay match state.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _chip(
                                  'Receipt',
                                  receipt.eventId,
                                  const Color(0xFF7BD0FF),
                                ),
                                _chip(
                                  'Hash',
                                  _shortHash(receipt.contentHash),
                                  const Color(0xFF8AA4C9),
                                ),
                                _chip(
                                  'Range',
                                  '${receipt.eventRangeStart}-${receipt.eventRangeEnd}',
                                  const Color(0xFF8AA4C9),
                                ),
                                _chip(
                                  'Replay',
                                  replayMatched ? 'MATCHED' : 'FAILED',
                                  replayMatched
                                      ? const Color(0xFF79D89A)
                                      : const Color(0xFFFF7A7A),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E1A2B),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF17324F),
                                ),
                              ),
                              child: Text(
                                'Receipt integrity is tied to the generated content hash and event range. Re-open this receipt from the harness to prove replay-safe regeneration before delivery.',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF94ABCB),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _reportConfigurationPane(),
                    const SizedBox(height: 14),
                    _sceneReviewPane(),
                    const SizedBox(height: 14),
                    previewPane,
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OnyxPageHeader(
                    title: _brandingConfiguration.isConfigured
                        ? '${_brandingConfiguration.primaryLabel} PDF'
                        : 'Operational Intelligence PDF',
                    subtitle:
                        'Preview, verify, print, and distribute deterministic report output.',
                    actions: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF0E1A2B),
                          side: const BorderSide(color: Color(0xFF1C3153)),
                        ),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Color(0xFFBFD2EE),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Printing.layoutPdf(
                            onLayout: (format) async => _pdfBytes!,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8AD6FF),
                          side: const BorderSide(color: Color(0xFF286AB8)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                        icon: const Icon(Icons.print_rounded),
                        label: const Text('Print'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await Printing.sharePdf(
                            bytes: _pdfBytes!,
                            filename: _pdfFileName,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF225182),
                          foregroundColor: const Color(0xFFE6F1FF),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Download'),
                      ),
                    ],
                  ),
                  if (_brandingConfiguration.isConfigured) ...[
                    const SizedBox(height: 14),
                    _brandingPane(),
                  ],
                  if (receipt != null) ...[
                    const SizedBox(height: 14),
                    receiptSummary,
                    const SizedBox(height: 14),
                    OnyxSectionCard(
                      title: 'Receipt Integrity',
                      subtitle:
                          'Current report receipt, content hash, event range, and replay match state.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _chip(
                                'Receipt',
                                receipt.eventId,
                                const Color(0xFF7BD0FF),
                              ),
                              _chip(
                                'Hash',
                                _shortHash(receipt.contentHash),
                                const Color(0xFF8AA4C9),
                              ),
                              _chip(
                                'Range',
                                '${receipt.eventRangeStart}-${receipt.eventRangeEnd}',
                                const Color(0xFF8AA4C9),
                              ),
                              _chip(
                                'Replay',
                                replayMatched ? 'MATCHED' : 'FAILED',
                                replayMatched
                                    ? const Color(0xFF79D89A)
                                    : const Color(0xFFFF7A7A),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E1A2B),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF17324F),
                              ),
                            ),
                            child: Text(
                              'Receipt integrity is tied to the generated content hash and event range. Re-open this receipt from the harness to prove replay-safe regeneration before delivery.',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF94ABCB),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _reportConfigurationPane(),
                  const SizedBox(height: 14),
                  _sceneReviewPane(),
                  const SizedBox(height: 14),
                  Expanded(child: previewPane),
                ],
              ),
      ),
    );
  }

  Color _decisionColor(String decisionLabel) {
    final normalized = decisionLabel.trim().toLowerCase();
    if (normalized.contains('escalation')) {
      return const Color(0xFFFF7A7A);
    }
    if (normalized.contains('repeat')) {
      return const Color(0xFFF6C067);
    }
    if (normalized.contains('alert') || normalized.contains('incident')) {
      return const Color(0xFF63BDFF);
    }
    if (normalized.contains('suppress')) {
      return const Color(0xFF9AA7BA);
    }
    return const Color(0xFF8AA4C9);
  }

  Widget _chip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF20406B)),
      ),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(fontSize: 12),
          children: [
            const TextSpan(text: ''),
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Color(0xFF8EA4C2),
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _configurationChip(String label, {required bool enabled}) {
    return _chip(
      label,
      enabled ? 'INCLUDED' : 'OMITTED',
      enabled ? const Color(0xFF79D89A) : const Color(0xFFF6C067),
    );
  }
}
