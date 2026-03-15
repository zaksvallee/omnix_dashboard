import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../application/monitoring_scene_review_store.dart';
import '../../application/report_generation_service.dart';
import '../../application/report_output_mode.dart';
import '../../application/report_receipt_export_payload.dart';
import '../../application/report_receipt_history_copy.dart';
import '../../application/report_receipt_history_lookup.dart';
import '../../application/report_receipt_history_presenter.dart';
import '../../application/report_receipt_scene_review_presenter.dart';
import '../../application/report_shell_binding.dart';
import '../../application/report_preview_surface.dart';
import '../../application/report_preview_request.dart';
import '../../application/report_receipt_scene_filter.dart';
import '../../application/report_shell_state.dart';
import '../../domain/events/report_generated.dart';
import '../../domain/store/in_memory_event_store.dart';
import '../../ui/onyx_surface.dart';
import 'report_preview_dock_card.dart';
import 'report_meta_pill.dart';
import 'report_preview_target_banner.dart';
import 'report_receipt_filter_banner.dart';
import 'report_receipt_filter_control.dart';
import 'report_shell_binding_host.dart';
import 'report_scene_review_narrative_box.dart';
import 'report_scene_review_pill_builder.dart';
import 'report_status_badge.dart';

class ReportTestHarnessPage extends StatefulWidget {
  final InMemoryEventStore store;
  final String selectedClient;
  final String selectedSite;
  final Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId;
  final ReportShellState reportShellState;
  final ValueChanged<ReportShellState>? onReportShellStateChanged;
  final ValueChanged<ReportPreviewRequest>? onRequestPreview;

  const ReportTestHarnessPage({
    super.key,
    required this.store,
    required this.selectedClient,
    required this.selectedSite,
    this.sceneReviewByIntelligenceId = const {},
    this.reportShellState = const ReportShellState(),
    this.onReportShellStateChanged,
    this.onRequestPreview,
  });

  @override
  State<ReportTestHarnessPage> createState() => _ReportTestHarnessPageState();
}

class _ReportTestHarnessPageState extends State<ReportTestHarnessPage>
    with ReportShellBindingHost<ReportTestHarnessPage> {
  static const int _maxHistoryRows = 24;

  bool _isGenerating = false;
  bool _verifyingHistory = false;
  String? _openingReceiptId;
  List<_ReportHistoryRow> _historyRows = const [];
  late ReportShellBinding _shellBinding;
  bool get _phoneLayout => MediaQuery.sizeOf(context).width < 900;

  ReportGenerationService get _service => ReportGenerationService(
    store: widget.store,
    sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
  );

  @override
  void initState() {
    super.initState();
    _shellBinding = ReportShellBinding.fromShellState(widget.reportShellState);
    _refreshHistory();
  }

  @override
  void didUpdateWidget(covariant ReportTestHarnessPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _shellBinding = _shellBinding.syncFromWidget(
      oldShellState: oldWidget.reportShellState,
      newShellState: widget.reportShellState,
    );
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

    focusReportReceiptWorkspace(generated.receiptEvent.eventId);
    setState(() => _isGenerating = false);
    if (!mounted) return;
    presentReportPreviewRequest(
      ReportPreviewRequest(
        bundle: generated.bundle,
        initialPdfBytes: generated.pdfBytes,
        receiptEvent: generated.receiptEvent,
        replayMatches: replayMatches,
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
      rows.add(
        _ReportHistoryRow(
          event: event,
          replayMatched: matched,
          sceneReviewSummary: _service.summarizeSceneReviewForReceipt(event),
        ),
      );
    }

    if (!mounted) return;
    syncPrunedReportShellBindingToReceiptIds(
      receiptEventIds: rows.map((row) => row.event.eventId),
      mutateLocalState: () {
        _historyRows = rows;
        _verifyingHistory = false;
      },
    );
  }

  Future<void> _openHistoryReceipt(_ReportHistoryRow row) async {
    focusReportReceiptWorkspace(row.event.eventId);
    setState(() => _openingReceiptId = row.event.eventId);

    final regenerated = await _service.regenerateFromReceipt(row.event);
    final replayMatches = await _service.verifyReportHash(row.event);
    if (!mounted) return;

    setState(() => _openingReceiptId = null);
    if (!mounted) return;
    presentReportPreviewRequest(
      ReportPreviewRequest(
        bundle: regenerated.bundle,
        initialPdfBytes: regenerated.pdfBytes,
        receiptEvent: row.event,
        replayMatches: replayMatches,
      ),
    );
  }

  void _exportHistoryReceipts(List<_ReportHistoryRow> rows) {
    if (rows.isEmpty) {
      _showHarnessFeedback('No receipts available to export.');
      return;
    }
    final focusedReceipt = _activeFilterShortcutRow(rows);
    final payload = ReportReceiptExportPayload.build(
      entries: rows.map(
        (row) => ReportReceiptExportEntry(
          receiptEvent: row.event,
          replayVerified: row.replayMatched,
          sceneReviewSummary: row.sceneReviewSummary,
        ),
      ),
      filter: _receiptFilter,
      selectedReceiptEventId: _selectedReceiptEventId,
      previewReceiptEventId: _previewReceiptEventId,
      focusedReceipt: focusedReceipt == null
          ? null
          : ReportReceiptExportEntry(
              receiptEvent: focusedReceipt.event,
              replayVerified: focusedReceipt.replayMatched,
              sceneReviewSummary: focusedReceipt.sceneReviewSummary,
            ),
    );
    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    Clipboard.setData(ClipboardData(text: encoded));
    _showHarnessFeedback(
      'Exported ${rows.length} receipt records to clipboard.',
    );
  }

  void _showHarnessFeedback(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _copyHistoryReceipt(_ReportHistoryRow row) {
    final payload = ReportReceiptExportPayload.buildSingle(
      entry: ReportReceiptExportEntry(
        receiptEvent: row.event,
        replayVerified: row.replayMatched,
        sceneReviewSummary: row.sceneReviewSummary,
      ),
      filter: _receiptFilter,
      selectedReceiptEventId: _selectedReceiptEventId,
      previewReceiptEventId: _previewReceiptEventId,
    );
    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    Clipboard.setData(ClipboardData(text: encoded));
    _showHarnessFeedback('Receipt export copied for ${row.event.eventId}.');
  }

  @override
  Widget build(BuildContext context) {
    final historyMetrics = _historyReceiptMetrics(_historyRows);
    final filteredHistoryRows = historyMetrics.filteredRows;
    final previewTargetRow = _targetRowByEventId(
      _historyRows,
      _previewReceiptEventId,
    );
    final focusedHistoryRow = _focusedVisibleHistoryRow(filteredHistoryRows);
    final reviewedCount = historyMetrics.reviewedCount;
    final alertReceiptCount = historyMetrics.alertCount;
    final repeatReceiptCount = historyMetrics.repeatCount;
    final escalationReceiptCount = historyMetrics.escalationCount;
    final suppressedReceiptCount = historyMetrics.suppressedCount;
    final pendingSceneCount = historyMetrics.pendingSceneCount;
    final reviewTargetRow =
        previewTargetRow ??
        focusedHistoryRow ??
        (filteredHistoryRows.isEmpty ? null : filteredHistoryRows.first);
    final reviewStatus = filteredHistoryRows.isEmpty
        ? 'IDLE'
        : previewTargetRow != null && _previewSurface == ReportPreviewSurface.dock
        ? 'DOCKED'
        : previewTargetRow != null
        ? 'TARGETED'
        : focusedHistoryRow == null
        ? 'READY'
        : 'FOCUSED';
    final reviewActionText = filteredHistoryRows.isEmpty
        ? 'No Receipt Selected'
        : previewTargetRow != null && _previewSurface == ReportPreviewSurface.dock
        ? 'Open Full Preview'
        : previewTargetRow != null
        ? 'Open Preview Target'
        : focusedHistoryRow == null
        ? 'Open Latest Receipt'
        : 'Open Selected Receipt';
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1540),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OnyxPageHeader(
                title: 'Client Intelligence Reports',
                subtitle: _pageSubtitle,
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
                  OutlinedButton.icon(
                    key: const ValueKey('report-harness-export-all-button'),
                    onPressed: () => _exportHistoryReceipts(filteredHistoryRows),
                    style: _headerSecondaryButtonStyle(),
                    icon: const Icon(Icons.copy_all_rounded),
                    label: Text(
                      'Export All',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _outputModeControl(),
              const SizedBox(height: 12),
              _previewSurfaceControl(),
              if (_previewReceiptEventId != null) ...[
                const SizedBox(height: 12),
                _previewTargetBanner(
                  eventId: _previewReceiptEventId!,
                  row: previewTargetRow,
                ),
              ],
              if (_previewSurface == ReportPreviewSurface.dock &&
                  previewTargetRow != null) ...[
                const SizedBox(height: 12),
                _previewDock(previewTargetRow),
              ],
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
                        child: _summaryFilterStat(
                          key: const ValueKey('report-harness-kpi-all'),
                          label: 'Receipts',
                          value: _historyRows.length.toString(),
                          accent: const Color(0xFF63BDFF),
                          isActive:
                              _receiptFilter == ReportReceiptSceneFilter.all,
                          onTap: () => toggleReportReceiptFilter(
                            ReportReceiptSceneFilter.all,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _summaryFilterStat(
                          key: const ValueKey('report-harness-kpi-reviewed'),
                          label: 'Reviewed',
                          value: reviewedCount.toString(),
                          accent: const Color(0xFF59D79B),
                          isActive:
                              _receiptFilter ==
                              ReportReceiptSceneFilter.reviewed,
                          onTap: () => toggleReportReceiptFilter(
                            ReportReceiptSceneFilter.reviewed,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _summaryFilterStat(
                          key: const ValueKey('report-harness-kpi-alerts'),
                          label: 'Alerts',
                          value: alertReceiptCount.toString(),
                          accent: const Color(0xFF63BDFF),
                          isActive:
                              _receiptFilter == ReportReceiptSceneFilter.alerts,
                          onTap: () => toggleReportReceiptFilter(
                            ReportReceiptSceneFilter.alerts,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _summaryFilterStat(
                          key: const ValueKey('report-harness-kpi-repeat'),
                          label: 'Repeat',
                          value: repeatReceiptCount.toString(),
                          accent: const Color(0xFFF6C067),
                          isActive:
                              _receiptFilter == ReportReceiptSceneFilter.repeat,
                          onTap: () => toggleReportReceiptFilter(
                            ReportReceiptSceneFilter.repeat,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _summaryFilterStat(
                          key: const ValueKey('report-harness-kpi-escalation'),
                          label: 'Escalation',
                          value: escalationReceiptCount.toString(),
                          accent: const Color(0xFFFF7A7A),
                          isActive:
                              _receiptFilter ==
                              ReportReceiptSceneFilter.escalation,
                          onTap: () => toggleReportReceiptFilter(
                            ReportReceiptSceneFilter.escalation,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _summaryFilterStat(
                          key: const ValueKey('report-harness-kpi-suppressed'),
                          label: 'Suppressed',
                          value: suppressedReceiptCount.toString(),
                          accent: const Color(0xFF8CA5C8),
                          isActive:
                              _receiptFilter ==
                              ReportReceiptSceneFilter.suppressed,
                          onTap: () => toggleReportReceiptFilter(
                            ReportReceiptSceneFilter.suppressed,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _summaryFilterStat(
                          key: const ValueKey(
                            'report-harness-kpi-scene-pending',
                          ),
                          label: 'Scene Pending',
                          value: pendingSceneCount.toString(),
                          accent: const Color(0xFF8CA5C8),
                          isActive:
                              _receiptFilter ==
                              ReportReceiptSceneFilter.pending,
                          onTap: () => toggleReportReceiptFilter(
                            ReportReceiptSceneFilter.pending,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              if (_phoneLayout)
                LayoutBuilder(
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
                            children: [
                              Expanded(
                                child: _MiniLaneCard(
                                  title: 'Generate',
                                  detail: 'Create PDF and receipt pair.',
                                  accent: const Color(0xFF63BDFF),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MiniLaneCard(
                                  title: 'Verify',
                                  detail:
                                      'Re-open receipts and confirm hashes.',
                                  accent: const Color(0xFF59D79B),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MiniLaneCard(
                                  title: 'Review',
                                  detail:
                                      'Open regenerated preview before release.',
                                  accent: const Color(0xFFF6C067),
                                  status: reviewStatus,
                                  actionText: reviewActionText,
                                  onTap: reviewTargetRow == null
                                      ? null
                                      : () => _openHistoryReceipt(reviewTargetRow),
                                  secondaryActionText: reviewTargetRow == null
                                      ? null
                                      : 'Copy Receipt',
                                  onSecondaryTap: reviewTargetRow == null
                                      ? null
                                      : () => _copyHistoryReceipt(
                                          reviewTargetRow,
                                        ),
                                  secondaryButtonKey: const ValueKey(
                                    'report-harness-review-copy-button',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                    final historyPane = _buildHistoryPane(
                      subtitle: _receiptHistorySubtitle,
                      flexibleChild: false,
                      showActiveFilterBanner: true,
                      useExpandedList: false,
                    );

                    if (stack) {
                      return Column(
                        children: [
                          leftPane,
                          const SizedBox(height: 10),
                          historyPane,
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
                )
              else
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
                              children: [
                                Expanded(
                                  child: _MiniLaneCard(
                                    title: 'Generate',
                                    detail: 'Create PDF and receipt pair.',
                                    accent: const Color(0xFF63BDFF),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _MiniLaneCard(
                                    title: 'Verify',
                                    detail:
                                        'Re-open receipts and confirm hashes.',
                                    accent: const Color(0xFF59D79B),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _MiniLaneCard(
                                    title: 'Review',
                                    detail:
                                        'Open regenerated preview before release.',
                                    accent: const Color(0xFFF6C067),
                                    status: reviewStatus,
                                    actionText: reviewActionText,
                                    onTap: reviewTargetRow == null
                                        ? null
                                        : () => _openHistoryReceipt(reviewTargetRow),
                                    secondaryActionText:
                                        reviewTargetRow == null
                                        ? null
                                        : 'Copy Receipt',
                                    onSecondaryTap: reviewTargetRow == null
                                        ? null
                                        : () => _copyHistoryReceipt(
                                            reviewTargetRow,
                                          ),
                                    secondaryButtonKey: const ValueKey(
                                      'report-harness-review-copy-button',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                      final historyPane = _buildHistoryPane(
                        subtitle:
                            'Open any generated receipt to regenerate the report and confirm replay integrity.',
                        flexibleChild: true,
                        showActiveFilterBanner: false,
                        useExpandedList: true,
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
    );
    return OnyxPageScaffold(
      child: _phoneLayout ? SingleChildScrollView(child: content) : content,
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
        color: const Color(0xFF0E1A2B),
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
        color: const Color(0xFF0E1A2B),
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

  Widget _historyMetaPill(
    String text,
    Color color, {
    bool isActive = false,
  }) {
    return ReportMetaPill(
      label: text,
      color: color,
      isActive: isActive,
      fontSize: 11,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      backgroundOpacity: 0.1,
      borderOpacity: 0.28,
    );
  }

  Widget _historyReceiptContent({
    required _ReportHistoryRow row,
    required bool isOpening,
    required bool isFocused,
  }) {
    final event = row.event;
    final replayMatched = row.replayMatched;
    final sceneAccent = _sceneReviewAccent(row.sceneReviewSummary);
    final sceneNarrative = _sceneReviewNarrative(row.sceneReviewSummary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                event.eventId,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: const Color(0xFFE5EFFF),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (isOpening)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (isOpening) const SizedBox(width: 8),
            if (isFocused) ...[
              const ReportStatusBadge(
                label: 'FOCUSED',
                textColor: Color(0xFF63BDFF),
                backgroundColor: Color(0x1463BDFF),
                borderColor: Color(0xFF63BDFF),
                fontSize: 10,
              ),
              const SizedBox(width: 8),
            ],
            _historyReplayBadge(replayMatched),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _historyMetaPill('Month ${event.month}', const Color(0xFF7FC7FF)),
            _historyMetaPill(
              'Seq ${event.eventRangeStart}-${event.eventRangeEnd}',
              const Color(0xFF8FA6C8),
            ),
            _historyMetaPill(
              'Count ${event.eventCount}',
              const Color(0xFF8FA6C8),
            ),
            ...ReportSceneReviewPillBuilder.build(
              summary: row.sceneReviewSummary,
              pillBuilder: _historyMetaPill,
              sceneIncludedColor: const Color(0xFF7FC7FF),
              scenePendingColor: const Color(0xFF8FA6C8),
              postureColor: const Color(0xFFF6C067),
              includeActionCounts: true,
              suppressedColor: const Color(0xFF8FA6C8),
              incidentAlertColor: const Color(0xFF7FC7FF),
              repeatUpdateColor: const Color(0xFFF6C067),
              includeLatestAction: true,
              onLatestActionFilterTap: setReportReceiptFilter,
              onLatestActionActiveTap: () => _openHistoryReceipt(row),
              activeLatestActionFilter: _receiptFilter,
              includePosture: true,
              posturePrefix: 'Posture ',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Hash ${_short(event.contentHash)} • PDF ${_short(event.pdfHash)}',
          style: GoogleFonts.inter(
            color: const Color(0xFF89A8CF),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Generated UTC ${_shortUtc(event.occurredAt)}',
          style: GoogleFonts.inter(
            color: const Color(0xFF89A8CF),
            fontSize: 12,
          ),
        ),
        if (sceneNarrative != null) ...[
          const SizedBox(height: 8),
          ReportSceneReviewNarrativeBox(
            narrative: sceneNarrative,
            accent: sceneAccent,
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: ValueKey('report-harness-receipt-copy-${row.event.eventId}'),
            onPressed: () => _copyHistoryReceipt(row),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: const Color(0xFF132947),
              foregroundColor: const Color(0xFFE8F1FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: const BorderSide(color: Color(0xFF2A4768)),
              ),
            ),
            icon: const Icon(Icons.copy_all_rounded, size: 15),
            label: Text(
              'Copy Receipt',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tap to open regenerated preview',
          style: GoogleFonts.inter(
            color: const Color(0xFF7FB0DE),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _historyReplayBadge(bool replayMatched) {
    return ReportStatusBadge(
      label: replayMatched ? 'REPLAY MATCHED' : 'REPLAY FAILED',
      textColor: replayMatched
          ? const Color(0xFF8FF3C9)
          : const Color(0xFFFF9AA7),
      backgroundColor: (replayMatched
              ? const Color(0xFF2AAC7D)
              : const Color(0xFFD05667))
          .withValues(alpha: 0.16),
      borderColor: replayMatched
          ? const Color(0xFF46DBA2)
          : const Color(0xFFFF7686),
      fontSize: 11,
    );
  }

  Widget _summaryFilterStat({
    required Key key,
    required String label,
    required String value,
    required Color accent,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? accent.withValues(alpha: 0.85)
                : Colors.transparent,
            width: isActive ? 1.4 : 1,
          ),
        ),
        child: Stack(
          children: [
            OnyxSummaryStat(label: label, value: value, accent: accent),
            if (isActive)
              Positioned(
                right: 8,
                top: 8,
                child: Text(
                  'ACTIVE',
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _previewSurfaceControl() {
    return OnyxSectionCard(
      title: 'Preview Surface',
      subtitle:
          'Choose whether report previews open on a route or stay docked in the workspace.',
      child: Row(
        children: [
          for (final surface in ReportPreviewSurface.values) ...[
            Expanded(
              child: _summaryFilterStat(
                key: ValueKey<String>(
                  'report-harness-preview-surface-${surface.name}',
                ),
                label: 'Surface',
                value: surface.label.toUpperCase(),
                accent: surface == ReportPreviewSurface.dock
                    ? const Color(0xFFF6C067)
                    : const Color(0xFF63BDFF),
                isActive: _previewSurface == surface,
                onTap: () => setReportPreviewSurface(surface),
              ),
            ),
            if (surface != ReportPreviewSurface.values.last)
              const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }

  Widget _outputModeControl() {
    return OnyxSectionCard(
      title: 'Output Format',
      subtitle:
          'Keep the harness aligned with the shared report workspace output mode.',
      child: Row(
        children: [
          for (final mode in ReportOutputMode.values) ...[
            Expanded(
              child: _summaryFilterStat(
                key: ValueKey<String>('report-harness-output-mode-${mode.name}'),
                label: 'Format',
                value: mode.label,
                accent: mode == ReportOutputMode.pdf
                    ? const Color(0xFF63BDFF)
                    : mode == ReportOutputMode.excel
                    ? const Color(0xFF59D79B)
                    : const Color(0xFFF6C067),
                isActive: _outputMode == mode,
                onTap: () => setReportOutputMode(mode),
              ),
            ),
            if (mode != ReportOutputMode.values.last)
              const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }

  Widget _receiptFilterControl({
    required ReportReceiptSceneFilter value,
    required ValueChanged<ReportReceiptSceneFilter> onChanged,
    required List<_ReportHistoryRow> rows,
  }) {
    final summaries = ReportReceiptHistoryPresenter.summariesOf<_ReportHistoryRow>(
      rows,
      (row) => row.sceneReviewSummary,
    );
    return ReportReceiptFilterControl(
      dropdownKey: const ValueKey('report-harness-receipt-filter'),
      value: value,
      onChanged: onChanged,
      summaries: summaries,
      onOpenFocusedReceipt: _activeFilterShortcutRow(rows) == null
          ? null
          : () => _openHistoryReceipt(_activeFilterShortcutRow(rows)!),
      alignment: Alignment.centerLeft,
      iconEnabledColor: const Color(0xFF8FA6C8),
      textColor: const Color(0xFFE5EFFF),
    );
  }

  Widget _buildHistoryPane({
    required String subtitle,
    required bool flexibleChild,
    required bool showActiveFilterBanner,
    required bool useExpandedList,
  }) {
    return OnyxSectionCard(
      title: 'Receipt History',
      subtitle: subtitle,
      flexibleChild: flexibleChild,
      child: _historyRows.isEmpty
          ? const OnyxEmptyState(label: 'No ReportGenerated receipts yet.')
          : Builder(
              builder: (context) {
                final filteredRows = _filteredHistoryRows;
                if (filteredRows.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _receiptFilterControl(
                        value: _receiptFilter,
                        onChanged: setReportReceiptFilter,
                        rows: _historyRows,
                      ),
                      if (showActiveFilterBanner &&
                          _receiptFilter != ReportReceiptSceneFilter.all) ...[
                        const SizedBox(height: 10),
                        _activeReceiptFilterBanner(
                          totalRows: _historyRows.length,
                          filteredRows: filteredRows.length,
                          rows: _historyRows,
                        ),
                      ],
                      const SizedBox(height: 10),
                      const OnyxEmptyState(
                        label: 'No receipts match the selected filter.',
                      ),
                    ],
                  );
                }

                final visibleRows = filteredRows
                    .take(_maxHistoryRows)
                    .toList(growable: false);
                final hiddenRows = filteredRows.length - visibleRows.length;
                final list = ListView.separated(
                  shrinkWrap: !useExpandedList,
                  primary: false,
                  physics: useExpandedList
                      ? null
                      : const NeverScrollableScrollPhysics(),
                  itemCount: visibleRows.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final row = visibleRows[index];
                    final isOpening = _openingReceiptId == row.event.eventId;
                    final isFocused = row.event.eventId == _selectedReceiptEventId;
                    final sceneAccent = _sceneReviewAccent(
                      row.sceneReviewSummary,
                    );

                    return InkWell(
                      onTap: isOpening ? null : () => _openHistoryReceipt(row),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isFocused
                              ? const Color(0xFF11243A)
                              : const Color(0xFF0E1A2B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isFocused
                                ? const Color(0xFF63BDFF)
                                : row.sceneReviewSummary?.includedInReceipt ==
                                      true
                                ? sceneAccent.withValues(alpha: 0.5)
                                : const Color(0xFF1F3855),
                            width: isFocused ? 1.4 : 1,
                          ),
                        ),
                        child: _historyReceiptContent(
                          row: row,
                          isOpening: isOpening,
                          isFocused: isFocused,
                        ),
                      ),
                    );
                  },
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _receiptFilterControl(
                      value: _receiptFilter,
                      onChanged: setReportReceiptFilter,
                      rows: _historyRows,
                    ),
                    if (showActiveFilterBanner &&
                        _receiptFilter != ReportReceiptSceneFilter.all) ...[
                      const SizedBox(height: 10),
                      _activeReceiptFilterBanner(
                        totalRows: _historyRows.length,
                        filteredRows: filteredRows.length,
                        rows: _historyRows,
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (useExpandedList) Expanded(child: list) else list,
                    if (hiddenRows > 0) ...[
                      const SizedBox(height: 8),
                      OnyxTruncationHint(
                        visibleCount: visibleRows.length,
                        totalCount: filteredRows.length,
                        subject: 'receipts',
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }

  List<_ReportHistoryRow> get _filteredHistoryRows =>
      _historyReceiptMetrics(_historyRows).filteredRows;

  ReportReceiptHistoryMetrics<_ReportHistoryRow> _historyReceiptMetrics(
    List<_ReportHistoryRow> rows,
  ) {
    return ReportReceiptHistoryPresenter.buildMetrics<_ReportHistoryRow>(
      rows: rows,
      filter: _receiptFilter,
      sceneSummaryOf: (row) => row.sceneReviewSummary,
    );
  }

  String get _pageSubtitle {
    return ReportReceiptHistoryCopy.pageSubtitle(
      scopeLabel: 'Client ${widget.selectedClient} • Site ${widget.selectedSite}',
      filter: _receiptFilter,
    );
  }

  String get _receiptHistorySubtitle {
    return ReportReceiptHistoryCopy.historySubtitle(
      base:
          'Open any generated receipt to regenerate the report and confirm replay integrity.',
      filter: _receiptFilter,
    );
  }

  Widget _activeReceiptFilterBanner({
    required int totalRows,
    required int filteredRows,
    required List<_ReportHistoryRow> rows,
  }) {
    final openRow = _activeFilterShortcutRow(rows);
    return ReportReceiptFilterBanner(
      filter: _receiptFilter,
      filteredRows: filteredRows,
      totalRows: totalRows,
      onOpenFocusedReceipt: openRow == null
          ? null
          : () => _openHistoryReceipt(openRow),
      onCopyFocusedReceipt: openRow == null
          ? null
          : () => _copyHistoryReceipt(openRow),
      onShowAll: () => setReportReceiptFilter(ReportReceiptSceneFilter.all),
    );
  }

  _ReportHistoryRow? _targetRowByEventId(
    List<_ReportHistoryRow> rows,
    String? eventId,
  ) {
    return ReportReceiptHistoryLookup.findByEventId<_ReportHistoryRow>(
      rows,
      eventId,
      (row) => row.event.eventId,
    );
  }

  _ReportHistoryRow? _focusedVisibleHistoryRow(List<_ReportHistoryRow> rows) {
    return _targetRowByEventId(rows, _selectedReceiptEventId);
  }

  _ReportHistoryRow? _activeFilterShortcutRow(List<_ReportHistoryRow> rows) {
    if (!_receiptFilter.isLatestActionFilter) {
      return null;
    }
    final filteredRows = _historyReceiptMetrics(rows).filteredRows;
    final previewTarget = _targetRowByEventId(filteredRows, _previewReceiptEventId);
    if (previewTarget != null) {
      return previewTarget;
    }
    final focused = _focusedVisibleHistoryRow(filteredRows);
    if (focused != null) {
      return focused;
    }
    if (filteredRows.length == 1) {
      return filteredRows.first;
    }
    return null;
  }

  Widget _previewTargetBanner({
    required String eventId,
    required _ReportHistoryRow? row,
  }) {
    return ReportPreviewTargetBanner(
      eventId: eventId,
      previewSurface: _previewSurface,
      surfaceLabelColor: const Color(0xFF8FA6C8),
      onOpen: row == null ? null : () => _openHistoryReceipt(row),
      onCopy: row == null ? null : () => _copyHistoryReceipt(row),
      onClear: clearReportPreviewTarget,
      openButtonKey: const ValueKey('report-harness-preview-target-open'),
      copyButtonKey: const ValueKey('report-harness-preview-target-copy'),
      clearButtonKey: const ValueKey('report-harness-preview-target-clear'),
    );
  }

  Widget _previewDock(_ReportHistoryRow row) {
    final sceneAccent = _sceneReviewAccent(row.sceneReviewSummary);
    return ReportPreviewDockCard(
      eventId: row.event.eventId,
      detail: 'Generated UTC ${_shortUtc(row.event.occurredAt)}',
      statusPills: [
        _historyMetaPill(
          row.replayMatched ? 'Replay Matched' : 'Replay Failed',
          row.replayMatched
              ? const Color(0xFF59D79B)
              : const Color(0xFFFF7A7A),
        ),
        if (row.sceneReviewSummary != null)
          _historyMetaPill(
            row.sceneReviewSummary!.includedInReceipt
                ? 'Scene ${row.sceneReviewSummary!.totalReviews}'
                : 'Scene Pending',
            row.sceneReviewSummary!.includedInReceipt
                ? sceneAccent
                : const Color(0xFF8FA6C8),
          ),
      ],
      primaryAction: ElevatedButton.icon(
        key: const ValueKey('report-harness-preview-dock-open'),
        onPressed: () => _openHistoryReceipt(row),
        style: _headerPrimaryButtonStyle(),
        icon: const Icon(Icons.open_in_new_rounded),
        label: const Text('Open Full Preview'),
      ),
      secondaryAction: OutlinedButton.icon(
        key: const ValueKey('report-harness-preview-dock-copy'),
        onPressed: () => _copyHistoryReceipt(row),
        style: _headerSecondaryButtonStyle(),
        icon: const Icon(Icons.copy_all_rounded),
        label: const Text('Copy Receipt'),
      ),
      tertiaryAction: OutlinedButton.icon(
        key: const ValueKey('report-harness-preview-dock-clear'),
        onPressed: clearReportPreviewTarget,
        style: _headerSecondaryButtonStyle(),
        icon: const Icon(Icons.close_rounded),
        label: const Text('Clear Dock Target'),
      ),
    );
  }

  @override
  ReportShellBinding get reportShellBinding => _shellBinding;

  @override
  set reportShellBinding(ReportShellBinding value) => _shellBinding = value;

  @override
  ReportShellState get reportShellBaseState => widget.reportShellState;

  @override
  ValueChanged<ReportShellState>? get onReportShellStateChanged =>
      widget.onReportShellStateChanged;

  @override
  ValueChanged<ReportPreviewRequest>? get onRequestPreview =>
      widget.onRequestPreview;

  ReportOutputMode get _outputMode => _shellBinding.outputMode;

  ReportReceiptSceneFilter get _receiptFilter => _shellBinding.receiptFilter;

  String? get _selectedReceiptEventId => _shellBinding.selectedReceiptEventId;

  String? get _previewReceiptEventId => _shellBinding.previewReceiptEventId;

  ReportPreviewSurface get _previewSurface => _shellBinding.previewSurface;

  String _short(String v) => v.length <= 16 ? v : '${v.substring(0, 16)}...';

  String _shortUtc(DateTime dt) {
    final z = dt.toUtc().toIso8601String();
    return z.length > 19 ? '${z.substring(0, 19)}Z' : z;
  }

  Color _sceneReviewAccent(ReportReceiptSceneReviewSummary? summary) {
    return ReportReceiptSceneReviewPresenter.accent(
      summary,
      neutralColor: const Color(0xFF8FA6C8),
      reviewedColor: const Color(0xFF7FC7FF),
      escalationColor: const Color(0xFFFF7A7A),
    );
  }

  String? _sceneReviewNarrative(ReportReceiptSceneReviewSummary? summary) {
    return ReportReceiptSceneReviewPresenter.narrative(summary);
  }

  ButtonStyle _headerPrimaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF225182),
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
  final String? status;
  final String? actionText;
  final VoidCallback? onTap;
  final String? secondaryActionText;
  final VoidCallback? onSecondaryTap;
  final Key? secondaryButtonKey;

  const _MiniLaneCard({
    required this.title,
    required this.detail,
    required this.accent,
    this.status,
    this.actionText,
    this.onTap,
    this.secondaryActionText,
    this.onSecondaryTap,
    this.secondaryButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (status != null)
                Text(
                  status!,
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
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
          if (actionText != null) ...[
            const SizedBox(height: 8),
            Text(
              actionText!,
              style: GoogleFonts.inter(
                color: onTap == null ? const Color(0xFF6E819C) : accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (secondaryActionText != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: secondaryButtonKey,
                onPressed: onSecondaryTap,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: const Color(0xFF132947),
                  foregroundColor: const Color(0xFFE8F1FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: const BorderSide(color: Color(0xFF2A4768)),
                  ),
                ),
                icon: const Icon(Icons.copy_all_rounded, size: 14),
                label: Text(
                  secondaryActionText!,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: card,
    );
  }
}

class _ReportHistoryRow {
  final ReportGenerated event;
  final bool replayMatched;
  final ReportReceiptSceneReviewSummary? sceneReviewSummary;

  const _ReportHistoryRow({
    required this.event,
    required this.replayMatched,
    this.sceneReviewSummary,
  });
}
