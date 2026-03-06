import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../application/report_generation_service.dart';
import '../../domain/events/report_generated.dart';
import '../../domain/store/in_memory_event_store.dart';
import '../../ui/onyx_surface.dart';
import 'report_preview_page.dart';

class ReportTestHarnessPage extends StatefulWidget {
  final InMemoryEventStore store;
  final String selectedClient;
  final String selectedSite;

  const ReportTestHarnessPage({
    super.key,
    required this.store,
    required this.selectedClient,
    required this.selectedSite,
  });

  @override
  State<ReportTestHarnessPage> createState() => _ReportTestHarnessPageState();
}

class _ReportTestHarnessPageState extends State<ReportTestHarnessPage> {
  static const int _maxHistoryRows = 24;

  bool _isGenerating = false;
  bool _verifyingHistory = false;
  String? _openingReceiptId;
  List<_ReportHistoryRow> _historyRows = const [];

  ReportGenerationService get _service =>
      ReportGenerationService(store: widget.store);

  @override
  void initState() {
    super.initState();
    _refreshHistory();
  }

  Future<void> _generatePreview() async {
    setState(() => _isGenerating = true);
    final now = DateTime.now().toUtc();

    final generated = await _service.generatePdfReport(
      clientId: widget.selectedClient,
      siteId: widget.selectedSite,
      nowUtc: now,
    );
    final replayMatches = await _service.verifyReportHash(
      generated.receiptEvent,
    );

    await _refreshHistory();
    if (!mounted) return;

    setState(() => _isGenerating = false);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportPreviewPage(
          bundle: generated.bundle,
          initialPdfBytes: generated.pdfBytes,
          receiptEvent: generated.receiptEvent,
          replayMatches: replayMatches,
        ),
      ),
    );
  }

  Future<void> _refreshHistory() async {
    setState(() => _verifyingHistory = true);

    final events = widget.store.allEvents();
    final reportEvents =
        events
            .whereType<ReportGenerated>()
            .where(
              (e) =>
                  e.clientId == widget.selectedClient &&
                  e.siteId == widget.selectedSite,
            )
            .toList()
          ..sort((a, b) => b.sequence.compareTo(a.sequence));

    final rows = <_ReportHistoryRow>[];
    for (final event in reportEvents) {
      final matched = await _service.verifyReportHash(event);
      rows.add(_ReportHistoryRow(event: event, replayMatched: matched));
    }

    if (!mounted) return;
    setState(() {
      _historyRows = rows;
      _verifyingHistory = false;
    });
  }

  Future<void> _openHistoryReceipt(_ReportHistoryRow row) async {
    setState(() => _openingReceiptId = row.event.eventId);

    final regenerated = await _service.regenerateFromReceipt(row.event);
    final replayMatches = await _service.verifyReportHash(row.event);
    if (!mounted) return;

    setState(() => _openingReceiptId = null);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportPreviewPage(
          bundle: regenerated.bundle,
          initialPdfBytes: regenerated.pdfBytes,
          receiptEvent: row.event,
          replayMatches: replayMatches,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnyxPageScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1540),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OnyxPageHeader(
                  title: 'Client Intelligence Reports',
                  subtitle:
                      'Client ${widget.selectedClient} • Site ${widget.selectedSite}',
                  actions: [
                    ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _generatePreview,
                      style: _headerPrimaryButtonStyle(),
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: Text(
                        _isGenerating ? 'Generating...' : 'Preview Report',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _verifyingHistory ? null : _refreshHistory,
                      style: _headerSecondaryButtonStyle(),
                      icon: _verifyingHistory
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_rounded),
                      label: Text(
                        _verifyingHistory
                            ? 'Verifying...'
                            : 'Refresh Replay Verification',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 1120;
                    final cardWidth = compact
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 24) / 3;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: OnyxSummaryStat(
                            label: 'Receipts',
                            value: _historyRows.length.toString(),
                            accent: const Color(0xFF63BDFF),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: OnyxSummaryStat(
                            label: 'Replay State',
                            value: _historyRows.isEmpty
                                ? 'Pending'
                                : _historyRows.every((row) => row.replayMatched)
                                ? 'Matched'
                                : 'Review',
                            accent: _historyRows.isEmpty
                                ? const Color(0xFF8CA5C8)
                                : _historyRows.every((row) => row.replayMatched)
                                ? const Color(0xFF59D79B)
                                : const Color(0xFFF6C067),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: OnyxSummaryStat(
                            label: 'Output Mode',
                            value: 'PDF',
                            accent: const Color(0xFFF6C067),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final stack = constraints.maxWidth < 1280;
                      final leftPane = Column(
                        children: [
                          OnyxSectionCard(
                            title: 'Deterministic Report Generation',
                            subtitle:
                                'Generate PDF from projection snapshots, append a receipt, and verify replay-safe integrity before delivery.',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _scopeStatTile(
                                      label: 'Client Scope',
                                      value: widget.selectedClient,
                                      accent: const Color(0xFF63BDFF),
                                    ),
                                    _scopeStatTile(
                                      label: 'Site Scope',
                                      value: widget.selectedSite,
                                      accent: const Color(0xFF59D79B),
                                    ),
                                    _scopeStatTile(
                                      label: 'Replay Lane',
                                      value: _verifyingHistory
                                          ? 'Verifying'
                                          : 'Ready',
                                      accent: _verifyingHistory
                                          ? const Color(0xFFF6C067)
                                          : const Color(0xFF8CA5C8),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _infoStrip(
                                  'Use the actions above to generate a fresh preview or re-run receipt verification for the current client/site scope.',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          OnyxSectionCard(
                            title: 'Generation Lanes',
                            subtitle:
                                'Keep generation, replay, and operator review distinct during report handling.',
                            child: Row(
                              children: const [
                                Expanded(
                                  child: _MiniLaneCard(
                                    title: 'Generate',
                                    detail: 'Create PDF and receipt pair.',
                                    accent: Color(0xFF63BDFF),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: _MiniLaneCard(
                                    title: 'Verify',
                                    detail:
                                        'Re-open receipts and confirm hashes.',
                                    accent: Color(0xFF59D79B),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: _MiniLaneCard(
                                    title: 'Review',
                                    detail:
                                        'Open regenerated preview before release.',
                                    accent: Color(0xFFF6C067),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                      final historyPane = OnyxSectionCard(
                        title: 'Receipt History',
                        subtitle:
                            'Open any generated receipt to regenerate the report and confirm replay integrity.',
                        flexibleChild: true,
                        child: _historyRows.isEmpty
                            ? const OnyxEmptyState(
                                label: 'No ReportGenerated receipts yet.',
                              )
                            : Builder(
                                builder: (context) {
                                  final visibleRows = _historyRows
                                      .take(_maxHistoryRows)
                                      .toList(growable: false);
                                  final hiddenRows =
                                      _historyRows.length - visibleRows.length;
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: ListView.separated(
                                          itemCount: visibleRows.length,
                                          separatorBuilder: (context, index) =>
                                              const SizedBox(height: 10),
                                          itemBuilder: (context, index) {
                                            final row = visibleRows[index];
                                            final r = row.event;
                                            final ok = row.replayMatched;
                                            final isOpening =
                                                _openingReceiptId == r.eventId;

                                            return InkWell(
                                              onTap: isOpening
                                                  ? null
                                                  : () => _openHistoryReceipt(
                                                      row,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                        colors: [
                                                          Color(0xFF0B1A30),
                                                          Color(0xFF091424),
                                                        ],
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFF1C385C,
                                                    ),
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          r.eventId,
                                                          style:
                                                              GoogleFonts.inter(
                                                                color:
                                                                    const Color(
                                                                      0xFFE5EFFF,
                                                                    ),
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                        const Spacer(),
                                                        if (isOpening)
                                                          const SizedBox(
                                                            width: 14,
                                                            height: 14,
                                                            child:
                                                                CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2,
                                                                ),
                                                          ),
                                                        if (isOpening)
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 10,
                                                                vertical: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  999,
                                                                ),
                                                            color:
                                                                (ok
                                                                        ? const Color(
                                                                            0xFF2AAC7D,
                                                                          )
                                                                        : const Color(
                                                                            0xFFD05667,
                                                                          ))
                                                                    .withValues(
                                                                      alpha:
                                                                          0.16,
                                                                    ),
                                                            border: Border.all(
                                                              color: ok
                                                                  ? const Color(
                                                                      0xFF46DBA2,
                                                                    )
                                                                  : const Color(
                                                                      0xFFFF7686,
                                                                    ),
                                                            ),
                                                          ),
                                                          child: Text(
                                                            ok
                                                                ? 'REPLAY MATCHED'
                                                                : 'REPLAY FAILED',
                                                            style: GoogleFonts.inter(
                                                              color: ok
                                                                  ? const Color(
                                                                      0xFF8FF3C9,
                                                                    )
                                                                  : const Color(
                                                                      0xFFFF9AA7,
                                                                    ),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              fontSize: 11,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: [
                                                        _historyMetaPill(
                                                          'Month ${r.month}',
                                                          const Color(
                                                            0xFF7FC7FF,
                                                          ),
                                                        ),
                                                        _historyMetaPill(
                                                          'Seq ${r.eventRangeStart}-${r.eventRangeEnd}',
                                                          const Color(
                                                            0xFF8FA6C8,
                                                          ),
                                                        ),
                                                        _historyMetaPill(
                                                          'Count ${r.eventCount}',
                                                          const Color(
                                                            0xFF8FA6C8,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Hash ${_short(r.contentHash)} • PDF ${_short(r.pdfHash)}',
                                                      style: GoogleFonts.inter(
                                                        color: const Color(
                                                          0xFF89A8CF,
                                                        ),
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Generated UTC ${_shortUtc(r.occurredAt)}',
                                                      style: GoogleFonts.inter(
                                                        color: const Color(
                                                          0xFF89A8CF,
                                                        ),
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      'Tap to open regenerated preview',
                                                      style: GoogleFonts.inter(
                                                        color: const Color(
                                                          0xFF7FB0DE,
                                                        ),
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      if (hiddenRows > 0) ...[
                                        const SizedBox(height: 8),
                                        OnyxTruncationHint(
                                          visibleCount: visibleRows.length,
                                          totalCount: _historyRows.length,
                                          subject: 'receipts',
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                      );

                      if (stack) {
                        return Column(
                          children: [
                            leftPane,
                            const SizedBox(height: 10),
                            Expanded(child: historyPane),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 520, child: leftPane),
                          const SizedBox(width: 10),
                          Expanded(child: historyPane),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scopeStatTile({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      width: 164,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B182B), Color(0xFF091423)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF88A0C0),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoStrip(String text) {
    return Container(
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
        text,
        style: GoogleFonts.inter(
          color: const Color(0xFF9AB0CF),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _historyMetaPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _short(String v) => v.length <= 16 ? v : '${v.substring(0, 16)}...';

  String _shortUtc(DateTime dt) {
    final z = dt.toUtc().toIso8601String();
    return z.length > 19 ? '${z.substring(0, 19)}Z' : z;
  }

  ButtonStyle _headerPrimaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1B5DA1),
      foregroundColor: const Color(0xFFE6F1FF),
      minimumSize: const Size(0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  ButtonStyle _headerSecondaryButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF8FD1FF),
      side: const BorderSide(color: Color(0xFF2A5E97)),
      minimumSize: const Size(0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _MiniLaneCard extends StatelessWidget {
  final String title;
  final String detail;
  final Color accent;

  const _MiniLaneCard({
    required this.title,
    required this.detail,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B182B), Color(0xFF091423)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: const Color(0xFF8FA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportHistoryRow {
  final ReportGenerated event;
  final bool replayMatched;

  const _ReportHistoryRow({required this.event, required this.replayMatched});
}
