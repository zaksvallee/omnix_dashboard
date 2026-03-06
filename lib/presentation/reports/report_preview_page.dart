import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';

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
    final bytes = widget.initialPdfBytes ??
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const OnyxPageScaffold(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final receipt = widget.receiptEvent;
    final replayMatched = widget.replayMatches == true;

    return OnyxPageScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OnyxPageHeader(
              title: 'Operational Intelligence PDF',
              subtitle:
                  'Preview, verify, print, and distribute deterministic report output.',
              actions: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF0A142A),
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
                      filename: 'onyx_intelligence_report.pdf',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5DA1),
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
            if (receipt != null) ...[
              const SizedBox(height: 14),
              Row(
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
              ),
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0B182B), Color(0xFF091423)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF17324F)),
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
            Expanded(
              child: OnyxSectionCard(
                title: 'PDF Preview',
                subtitle:
                    'Use this viewer as the final operator checkpoint before print or distribution.',
                flexibleChild: true,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: PdfPreview(
                    pdfFileName: 'onyx_intelligence_report.pdf',
                    canDebug: false,
                    useActions: false,
                    allowPrinting: false,
                    allowSharing: false,
                    build: (format) async => _pdfBytes!,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B182B), Color(0xFF091423)],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF20406B)),
      ),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(fontSize: 12),
          children: [
            const TextSpan(
              text: '',
            ),
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
}
