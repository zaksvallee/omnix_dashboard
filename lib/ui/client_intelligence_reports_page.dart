import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/morning_sovereign_report_service.dart';
import '../application/monitoring_scene_review_store.dart';
import '../application/report_entry_context.dart';
import '../application/report_output_mode.dart';
import '../application/report_partner_comparison_window.dart';
import '../application/report_receipt_export_payload.dart';
import '../application/report_receipt_history_copy.dart';
import '../application/report_receipt_history_lookup.dart';
import '../application/report_receipt_history_presenter.dart';
import '../application/report_receipt_scene_review_presenter.dart';
import '../application/report_shell_binding.dart';
import '../application/report_preview_request.dart';
import '../application/report_preview_surface.dart';
import '../application/report_generation_service.dart';
import '../application/report_receipt_scene_filter.dart';
import '../application/report_shell_state.dart';
import '../domain/crm/reporting/report_branding_configuration.dart';
import '../domain/crm/reporting/report_section_configuration.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/partner_dispatch_status_declared.dart';
import '../domain/events/report_generated.dart';
import '../domain/store/in_memory_event_store.dart';
import '../presentation/reports/report_preview_dock_card.dart';
import '../presentation/reports/report_meta_pill.dart';
import '../presentation/reports/report_receipt_filter_control.dart';
import '../presentation/reports/report_receipt_filter_banner.dart';
import '../presentation/reports/report_shell_binding_host.dart';
import '../presentation/reports/report_scene_review_narrative_box.dart';
import '../presentation/reports/report_scene_review_pill_builder.dart';
import '../presentation/reports/report_preview_target_banner.dart';
import '../presentation/reports/report_status_badge.dart';
import 'onyx_surface.dart';
import 'ui_action_logger.dart';

class ClientIntelligenceReportsPage extends StatefulWidget {
  final InMemoryEventStore store;
  final String selectedClient;
  final String selectedSite;
  final List<SovereignReport> morningSovereignReportHistory;
  final String? initialPartnerScopeClientId;
  final String? initialPartnerScopeSiteId;
  final String? initialPartnerScopePartnerLabel;
  final Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId;
  final ReportShellState reportShellState;
  final ValueChanged<ReportShellState>? onReportShellStateChanged;
  final ValueChanged<ReportPreviewRequest>? onRequestPreview;
  final void Function(String clientId, String siteId, String partnerLabel)?
  onOpenGovernanceForPartnerScope;
  final void Function(List<String> eventIds, String selectedEventId)?
  onOpenEventsForScope;

  const ClientIntelligenceReportsPage({
    super.key,
    required this.store,
    required this.selectedClient,
    required this.selectedSite,
    this.morningSovereignReportHistory = const <SovereignReport>[],
    this.initialPartnerScopeClientId,
    this.initialPartnerScopeSiteId,
    this.initialPartnerScopePartnerLabel,
    this.sceneReviewByIntelligenceId = const {},
    this.reportShellState = const ReportShellState(),
    this.onReportShellStateChanged,
    this.onRequestPreview,
    this.onOpenGovernanceForPartnerScope,
    this.onOpenEventsForScope,
  });

  @override
  State<ClientIntelligenceReportsPage> createState() =>
      _ClientIntelligenceReportsPageState();
}

class _ClientIntelligenceReportsPageState
    extends State<ClientIntelligenceReportsPage>
    with ReportShellBindingHost<ClientIntelligenceReportsPage> {
  bool _isGenerating = false;
  bool _isRefreshing = false;
  List<_ReceiptRow> _receipts = const [];
  late ReportShellBinding _shellBinding;
  String _selectedScope = 'Sandton Estate North';
  DateTime _startDate = DateTime.utc(2024, 3, 1);
  DateTime _endDate = DateTime.utc(2024, 3, 10);

  ReportGenerationService get _service => ReportGenerationService(
    store: widget.store,
    sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
  );

  @override
  void initState() {
    super.initState();
    _shellBinding = ReportShellBinding.fromShellState(widget.reportShellState);
    _syncFocusedPartnerScopeFromWidget(deferEmit: true);
    _loadReceipts();
  }

  @override
  void didUpdateWidget(covariant ClientIntelligenceReportsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _shellBinding = _shellBinding.syncFromWidget(
      oldShellState: oldWidget.reportShellState,
      newShellState: widget.reportShellState,
    );
    if (oldWidget.initialPartnerScopeClientId !=
            widget.initialPartnerScopeClientId ||
        oldWidget.initialPartnerScopeSiteId !=
            widget.initialPartnerScopeSiteId ||
        oldWidget.initialPartnerScopePartnerLabel !=
            widget.initialPartnerScopePartnerLabel) {
      _syncFocusedPartnerScopeFromWidget();
    }
  }

  Future<void> _loadReceipts() async {
    setState(() => _isRefreshing = true);
    final rows = <_ReceiptRow>[];
    final reportEvents =
        widget.store
            .allEvents()
            .whereType<ReportGenerated>()
            .where(
              (event) =>
                  event.clientId == widget.selectedClient &&
                  event.siteId == widget.selectedSite,
            )
            .toList()
          ..sort((a, b) => b.sequence.compareTo(a.sequence));

    for (final event in reportEvents) {
      final replayVerified = await _service.verifyReportHash(event);
      rows.add(
        _ReceiptRow(
          event: event,
          replayVerified: replayVerified,
          sceneReviewSummary: _service.summarizeSceneReviewForReceipt(event),
        ),
      );
    }

    if (!mounted) {
      return;
    }

    syncPrunedReportShellBindingToReceiptIds(
      receiptEventIds: rows.map((row) => row.event.eventId),
      mutateLocalState: () {
        _receipts = rows;
        _isRefreshing = false;
      },
    );
  }

  Future<void> _generateReport() async {
    setState(() => _isGenerating = true);
    final generated = await _service.generatePdfReport(
      clientId: widget.selectedClient,
      siteId: widget.selectedSite,
      nowUtc: DateTime.now().toUtc(),
      brandingConfiguration: _currentBrandingConfiguration,
      sectionConfiguration: _currentSectionConfiguration,
      investigationContextKey: _entryContext?.storageValue ?? '',
    );
    final replayMatches = await _service.verifyReportHash(
      generated.receiptEvent,
    );
    await _loadReceipts();
    if (!mounted) {
      return;
    }
    focusReportReceiptWorkspace(generated.receiptEvent.eventId);
    setState(() => _isGenerating = false);
    presentReportPreviewRequest(
      ReportPreviewRequest(
        bundle: generated.bundle,
        initialPdfBytes: generated.pdfBytes,
        receiptEvent: generated.receiptEvent,
        replayMatches: replayMatches,
        entryContext: _effectiveEntryContextForReceipt(generated.receiptEvent),
      ),
    );
  }

  Future<void> _openReceipt(_ReceiptRow row) async {
    focusReportReceiptWorkspace(row.event.eventId);
    final regenerated = await _service.regenerateFromReceipt(row.event);
    final replayMatches = await _service.verifyReportHash(row.event);
    if (!mounted) {
      return;
    }
    presentReportPreviewRequest(
      ReportPreviewRequest(
        bundle: regenerated.bundle,
        initialPdfBytes: regenerated.pdfBytes,
        receiptEvent: row.event,
        replayMatches: replayMatches,
        entryContext: _effectiveEntryContextForReceipt(row.event),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportRows = _receipts.isNotEmpty ? _receipts : _sampleReceipts;
    final receiptMetrics = _receiptHistoryMetrics(reportRows);
    final visibleReceipts = receiptMetrics.filteredRows;
    final previewTargetReceipt = _targetReceiptByEventId(
      reportRows,
      _previewReceiptEventId,
    );
    final focusedReceipt = _focusedVisibleReceipt(visibleReceipts);
    final verifiedCount = _receipts.where((row) => row.replayVerified).length;
    final pendingCount = _receipts.length - verifiedCount;
    final reviewedCount = receiptMetrics.reviewedCount;
    final alertReceiptCount = receiptMetrics.alertCount;
    final repeatReceiptCount = receiptMetrics.repeatCount;
    final escalationReceiptCount = receiptMetrics.escalationCount;
    final suppressedReceiptCount = receiptMetrics.suppressedCount;
    final pendingSceneCount = receiptMetrics.pendingSceneCount;
    final governanceInvestigationCount = _receiptGovernanceHandoffCount(
      reportRows,
    );
    final routineInvestigationCount = _receiptRoutineReviewCount(reportRows);
    final investigationTrendLabel = _receiptInvestigationTrendLabel(reportRows);
    final replayState = _isRefreshing
        ? 'RUNNING'
        : pendingCount == 0 && _receipts.isNotEmpty
        ? 'VERIFIED'
        : 'READY';

    return OnyxPageScaffold(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1540),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  OnyxPageHeader(
                    title: 'CLIENT INTELLIGENCE REPORTS',
                    subtitle: _pageSubtitle,
                    actions: [
                      _actionButton(
                        label: _isGenerating
                            ? 'Generating...'
                            : 'Preview Report',
                        icon: Icons.picture_as_pdf_rounded,
                        onTap: _isGenerating ? null : _generateReport,
                      ),
                      _actionButton(
                        label: _isRefreshing
                            ? 'Refreshing...'
                            : 'Refresh Replay Verification',
                        icon: Icons.verified_rounded,
                        onTap: _isRefreshing ? null : _loadReceipts,
                      ),
                    ],
                  ),
                  if (_previewReceiptEventId != null) ...[
                    const SizedBox(height: 8),
                    _previewTargetBanner(
                      eventId: _previewReceiptEventId!,
                      row: previewTargetReceipt,
                      hasLiveReceipts: _receipts.isNotEmpty,
                    ),
                  ],
                  if (_previewSurface == ReportPreviewSurface.dock &&
                      previewTargetReceipt != null) ...[
                    const SizedBox(height: 8),
                    _previewDock(
                      row: previewTargetReceipt,
                      hasLiveReceipts: _receipts.isNotEmpty,
                    ),
                  ],
                  if (_sitePartnerScoreboardRows.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _partnerComparisonCard(),
                    const SizedBox(height: 8),
                    _partnerScorecardLanesCard(),
                  ],
                  if (reportRows.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _receiptPolicyHistoryCard(reportRows),
                  ],
                  if (_hasPartnerScopeFocus) ...[
                    const SizedBox(height: 8),
                    _partnerScopeCard(),
                  ],
                  const SizedBox(height: 8),
                  _kpiBand(
                    totalReceipts: _receipts.length,
                    verifiedCount: verifiedCount,
                    pendingCount: pendingCount,
                    reviewedCount: reviewedCount,
                    alertReceiptCount: alertReceiptCount,
                    repeatReceiptCount: repeatReceiptCount,
                    escalationReceiptCount: escalationReceiptCount,
                    suppressedReceiptCount: suppressedReceiptCount,
                    pendingSceneCount: pendingSceneCount,
                    governanceInvestigationCount: governanceInvestigationCount,
                    routineInvestigationCount: routineInvestigationCount,
                    investigationTrendLabel: investigationTrendLabel,
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 1240;
                      final controls = Column(
                        children: [
                          OnyxSectionCard(
                            title: 'Deterministic Generation',
                            subtitle:
                                'Generate PDF from projection snapshots, append a receipt, and verify replay-safe integrity before delivery.',
                            child: _buildDeterministicControls(),
                          ),
                          const SizedBox(height: 8),
                          OnyxSectionCard(
                            title: 'Generation Lanes',
                            subtitle:
                                'Keep generation, replay, and operator review distinct during report handling.',
                            child: Column(
                              children: [
                                _generationLane(
                                  color: const Color(0xFF63BDFF),
                                  icon: Icons.description_rounded,
                                  title: 'Generate',
                                  detail: 'Create PDF and receipt pair.',
                                  status: 'READY',
                                  actionText: 'Generate Now',
                                  onTap: _isGenerating ? null : _generateReport,
                                ),
                                const SizedBox(height: 8),
                                _generationLane(
                                  color: const Color(0xFF59D79B),
                                  icon: Icons.verified_rounded,
                                  title: 'Verify',
                                  detail:
                                      'Re-open receipts and confirm hash chain replay.',
                                  status: replayState,
                                  actionText: 'Refresh Replay Verification',
                                  onTap: _isRefreshing ? null : _loadReceipts,
                                ),
                                const SizedBox(height: 8),
                                _generationLane(
                                  color: const Color(0xFFF6C067),
                                  icon: Icons.visibility_rounded,
                                  title: 'Review',
                                  detail:
                                      'Open regenerated preview before release.',
                                  status: visibleReceipts.isEmpty
                                      ? 'IDLE'
                                      : previewTargetReceipt != null &&
                                            _previewSurface ==
                                                ReportPreviewSurface.dock
                                      ? 'DOCKED'
                                      : previewTargetReceipt != null
                                      ? 'TARGETED'
                                      : focusedReceipt == null
                                      ? 'READY'
                                      : 'FOCUSED',
                                  actionText: visibleReceipts.isEmpty
                                      ? 'No Receipt Selected'
                                      : previewTargetReceipt != null &&
                                            _previewSurface ==
                                                ReportPreviewSurface.dock
                                      ? 'Open Full Preview'
                                      : previewTargetReceipt != null
                                      ? 'Open Preview Target'
                                      : focusedReceipt == null
                                      ? 'Open Latest Receipt'
                                      : 'Open Selected Receipt',
                                  onTap: visibleReceipts.isEmpty
                                      ? null
                                      : () => _previewReceipt(
                                          previewTargetReceipt ??
                                              focusedReceipt ??
                                              visibleReceipts.first,
                                          _receipts.isNotEmpty,
                                        ),
                                  secondaryActionText: visibleReceipts.isEmpty
                                      ? null
                                      : 'Copy Receipt',
                                  onSecondaryTap: visibleReceipts.isEmpty
                                      ? null
                                      : () => _copyReceipt(
                                          previewTargetReceipt ??
                                              focusedReceipt ??
                                              visibleReceipts.first,
                                        ),
                                  secondaryButtonKey: const ValueKey(
                                    'reports-review-copy-button',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          OnyxSectionCard(
                            title: 'Report Configuration',
                            subtitle:
                                'Select the operational sections included in each generated client report.',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_currentBrandingConfiguration
                                    .isConfigured) ...[
                                  Container(
                                    key: const ValueKey(
                                      'reports-branding-summary-card',
                                    ),
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF102337),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFF29425F),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Client-facing branding',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF8FD1FF),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _currentBrandingConfiguration
                                              .primaryLabel,
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFFE8F1FF),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _receiptSceneReviewPill(
                                              _hasBrandingOverride
                                                  ? 'Brand Override Active'
                                                  : 'Default Partner Branding',
                                              _hasBrandingOverride
                                                  ? const Color(0xFFF6C067)
                                                  : const Color(0xFF63BDFF),
                                            ),
                                          ],
                                        ),
                                        if (_currentBrandingConfiguration
                                            .endorsementLine
                                            .trim()
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            _currentBrandingConfiguration
                                                .endorsementLine,
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF9CB2D1),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _actionButton(
                                              key: const ValueKey(
                                                'reports-branding-edit-button',
                                              ),
                                              label: 'Edit Branding',
                                              icon: Icons.edit_rounded,
                                              onTap: _editBrandingOverrides,
                                            ),
                                            if (_hasBrandingOverride)
                                              _actionButton(
                                                key: const ValueKey(
                                                  'reports-branding-reset-button',
                                                ),
                                                label: 'Reset Branding',
                                                icon: Icons.restore_rounded,
                                                onTap: _resetBrandingOverrides,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                _toggle(
                                  label: 'Include incident timeline',
                                  value: _includeTimeline,
                                  onChanged: (value) =>
                                      setReportSectionConfiguration(
                                        includeTimeline: value,
                                      ),
                                ),
                                _toggle(
                                  label: 'Include dispatch summary',
                                  value: _includeDispatchSummary,
                                  onChanged: (value) =>
                                      setReportSectionConfiguration(
                                        includeDispatchSummary: value,
                                      ),
                                ),
                                _toggle(
                                  label: 'Include checkpoint compliance',
                                  value: _includeCheckpointCompliance,
                                  onChanged: (value) =>
                                      setReportSectionConfiguration(
                                        includeCheckpointCompliance: value,
                                      ),
                                ),
                                _toggle(
                                  label: 'Include AI decision log',
                                  value: _includeAiDecisionLog,
                                  onChanged: (value) =>
                                      setReportSectionConfiguration(
                                        includeAiDecisionLog: value,
                                      ),
                                ),
                                _toggle(
                                  label: 'Include guard performance metrics',
                                  value: _includeGuardMetrics,
                                  onChanged: (value) =>
                                      setReportSectionConfiguration(
                                        includeGuardMetrics: value,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                      final history = OnyxSectionCard(
                        title: 'Receipt History',
                        subtitle: _receiptHistorySubtitle,
                        child: _buildReceiptHistory(),
                      );

                      if (stacked) {
                        return Column(
                          children: [
                            controls,
                            const SizedBox(height: 8),
                            history,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: controls),
                          const SizedBox(width: 8),
                          Expanded(flex: 7, child: history),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _kpiBand({
    required int totalReceipts,
    required int verifiedCount,
    required int pendingCount,
    required int reviewedCount,
    required int alertReceiptCount,
    required int repeatReceiptCount,
    required int escalationReceiptCount,
    required int suppressedReceiptCount,
    required int pendingSceneCount,
    required int governanceInvestigationCount,
    required int routineInvestigationCount,
    required String investigationTrendLabel,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _kpiCard(
            key: const ValueKey('reports-kpi-all'),
            label: 'TOTAL RECEIPTS',
            value: '$totalReceipts',
            accent: const Color(0xFF63BDFF),
            icon: Icons.description_rounded,
            isActive: _receiptFilter == ReportReceiptSceneFilter.all,
            onTap: () =>
                toggleReportReceiptFilter(ReportReceiptSceneFilter.all),
          ),
          _kpiCard(
            label: 'VERIFIED REPORTS',
            value: '$verifiedCount',
            accent: const Color(0xFF59D79B),
            icon: Icons.verified_rounded,
          ),
          _kpiCard(
            label: 'PENDING VERIFICATION',
            value: '$pendingCount',
            accent: const Color(0xFFF6C067),
            icon: Icons.pending_actions_rounded,
          ),
          _kpiCard(
            key: const ValueKey('reports-kpi-reviewed'),
            label: 'REVIEWED',
            value: '$reviewedCount',
            accent: const Color(0xFF59D79B),
            icon: Icons.visibility_rounded,
            isActive: _receiptFilter == ReportReceiptSceneFilter.reviewed,
            onTap: () =>
                toggleReportReceiptFilter(ReportReceiptSceneFilter.reviewed),
          ),
          _kpiCard(
            key: const ValueKey('reports-kpi-alerts'),
            label: 'ALERTS',
            value: '$alertReceiptCount',
            accent: const Color(0xFF63BDFF),
            icon: Icons.notifications_active_rounded,
            isActive: _receiptFilter == ReportReceiptSceneFilter.alerts,
            onTap: () =>
                toggleReportReceiptFilter(ReportReceiptSceneFilter.alerts),
          ),
          _kpiCard(
            key: const ValueKey('reports-kpi-repeat'),
            label: 'REPEAT',
            value: '$repeatReceiptCount',
            accent: const Color(0xFFF6C067),
            icon: Icons.repeat_rounded,
            isActive: _receiptFilter == ReportReceiptSceneFilter.repeat,
            onTap: () =>
                toggleReportReceiptFilter(ReportReceiptSceneFilter.repeat),
          ),
          _kpiCard(
            key: const ValueKey('reports-kpi-escalation'),
            label: 'ESCALATION',
            value: '$escalationReceiptCount',
            accent: const Color(0xFFFF7A7A),
            icon: Icons.priority_high_rounded,
            isActive: _receiptFilter == ReportReceiptSceneFilter.escalation,
            onTap: () =>
                toggleReportReceiptFilter(ReportReceiptSceneFilter.escalation),
          ),
          _kpiCard(
            key: const ValueKey('reports-kpi-suppressed'),
            label: 'SUPPRESSED',
            value: '$suppressedReceiptCount',
            accent: const Color(0xFF8EA4C2),
            icon: Icons.visibility_off_rounded,
            isActive: _receiptFilter == ReportReceiptSceneFilter.suppressed,
            onTap: () =>
                toggleReportReceiptFilter(ReportReceiptSceneFilter.suppressed),
          ),
          _kpiCard(
            key: const ValueKey('reports-kpi-scene-pending'),
            label: 'SCENE PENDING',
            value: '$pendingSceneCount',
            accent: const Color(0xFF8EA4C2),
            icon: Icons.hourglass_bottom_rounded,
            isActive: _receiptFilter == ReportReceiptSceneFilter.pending,
            onTap: () =>
                toggleReportReceiptFilter(ReportReceiptSceneFilter.pending),
          ),
          _kpiCard(
            key: const ValueKey('reports-kpi-investigation-governance'),
            label: 'OVERSIGHT HANDOFFS',
            value: '$governanceInvestigationCount',
            accent: const Color(0xFF5DC8FF),
            icon: Icons.manage_search_rounded,
          ),
          _kpiCard(
            key: const ValueKey('reports-kpi-investigation-routine'),
            label: 'ROUTINE REVIEW',
            value: '$routineInvestigationCount',
            accent: const Color(0xFF8EA4C2),
            icon: Icons.rule_rounded,
          ),
          _kpiCard(
            key: const ValueKey('reports-kpi-investigation-trend'),
            label: 'INVESTIGATION DRIFT',
            value: investigationTrendLabel,
            accent: _receiptInvestigationTrendColor(investigationTrendLabel),
            icon: Icons.insights_rounded,
          ),
          _kpiCard(
            label: 'OUTPUT MODE',
            value: _outputMode.label,
            accent: const Color(0xFFE8F1FF),
            icon: Icons.download_rounded,
          ),
        ];

        if (constraints.maxWidth < 1180) {
          return Wrap(spacing: 8, runSpacing: 8, children: cards);
        }

        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < cards.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }

  Widget _partnerScopeCard() {
    final historyPoints = _partnerScopeHistoryPoints();
    final latestPoint = historyPoints.isEmpty ? null : historyPoints.first;
    final currentChains = _partnerScopeDispatchChains();
    final trendLabel = _partnerScopeTrendLabel(historyPoints);
    final trendReason = _partnerScopeTrendReason(historyPoints);
    final receiptRows = _partnerScopeReceiptRows();
    final receiptInvestigationTrendLabel = _receiptInvestigationTrendLabel(
      receiptRows,
    );
    final receiptInvestigationComparison =
        _receiptInvestigationComparison(receiptRows);
    return OnyxSectionCard(
      title: 'Partner Scorecard Focus',
      subtitle:
          'Scoped responder reporting for the active partner lane in Reports.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: const ValueKey('reports-partner-scope-banner'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF102337),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF29425F)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PARTNER SCOPE ACTIVE',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8FD1FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_partnerScopeClientId!}/${_partnerScopeSiteId!} • ${_partnerScopePartnerLabel!}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE8F1FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  latestPoint?.row.summaryLine ??
                      'No morning partner scorecard data has been recorded yet for this scope.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9CB2D1),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (trendLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _partnerScopeChip(
                        label: trendLabel,
                        color: _partnerTrendColor(trendLabel),
                      ),
                      _partnerScopeChip(
                        label:
                            '${historyPoints.length} day${historyPoints.length == 1 ? '' : 's'}',
                      ),
                      _partnerScopeChip(
                        label:
                            '${currentChains.length} chain${currentChains.length == 1 ? '' : 's'}',
                      ),
                    ],
                  ),
                ],
                if (trendReason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    trendReason,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8EA4C2),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (receiptRows.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _partnerScopeChip(
                        label:
                            'Receipt ${receiptInvestigationTrendLabel.toUpperCase()}',
                        color: _receiptInvestigationTrendColor(
                          receiptInvestigationTrendLabel,
                        ),
                      ),
                      _partnerScopeChip(
                        label:
                            'Current Governance: ${receiptInvestigationComparison.currentGovernanceCount}',
                        color: const Color(0xFF5DC8FF),
                      ),
                      _partnerScopeChip(
                        label:
                            'Current Routine: ${receiptInvestigationComparison.currentRoutineCount}',
                        color: const Color(0xFF8EA4C2),
                      ),
                      _partnerScopeChip(
                        label:
                            'Baseline Governance: ${receiptInvestigationComparison.baselineGovernanceAverage.toStringAsFixed(1)}',
                        color: const Color(0xFF4F87BE),
                      ),
                      _partnerScopeChip(
                        label:
                            'Baseline Routine: ${receiptInvestigationComparison.baselineRoutineAverage.toStringAsFixed(1)}',
                        color: const Color(0xFF7087A8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _receiptInvestigationTrendReason(receiptRows),
                    style: GoogleFonts.inter(
                      color: _receiptInvestigationTrendColor(
                        receiptInvestigationTrendLabel,
                      ),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton(
                key: const ValueKey('reports-partner-scorecard-copy-json'),
                label: 'Copy Partner JSON',
                icon: Icons.copy_all_rounded,
                onTap: _copyPartnerScopeJson,
              ),
              _actionButton(
                key: const ValueKey('reports-partner-scorecard-copy-csv'),
                label: 'Copy Partner CSV',
                icon: Icons.table_chart_rounded,
                onTap: _copyPartnerScopeCsv,
              ),
              _actionButton(
                key: const ValueKey('reports-partner-scorecard-open-drill-in'),
                label: 'Open Drill-In',
                icon: Icons.manage_search_rounded,
                onTap: _openPartnerScopeDrillIn,
              ),
              _actionButton(
                key: const ValueKey('reports-partner-scorecard-clear-focus'),
                label: 'Clear Focus',
                icon: Icons.filter_alt_off_rounded,
                onTap: _clearPartnerScopeFocus,
              ),
              if (widget.onOpenGovernanceForPartnerScope != null)
                _actionButton(
                  key: const ValueKey(
                    'reports-partner-scorecard-open-governance',
                  ),
                  label: 'Open Governance Scope',
                  icon: Icons.verified_user_rounded,
                  onTap: () {
                    widget.onOpenGovernanceForPartnerScope!(
                      _partnerScopeClientId!,
                      _partnerScopeSiteId!,
                      _partnerScopePartnerLabel!,
                    );
                    _showReceiptActionFeedback(
                      'Opening Governance for ${_partnerScopeSiteId!} • ${_partnerScopePartnerLabel!}.',
                    );
                  },
                ),
              if (widget.onOpenEventsForScope != null &&
                  currentChains.isNotEmpty)
                _actionButton(
                  key: const ValueKey('reports-partner-scorecard-open-events'),
                  label: 'Open Events Review',
                  icon: Icons.rule_folder_rounded,
                  onTap: () =>
                      _openEventsForPartnerDispatchChain(currentChains.first),
                ),
            ],
          ),
          if (historyPoints.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Scorecard history',
              style: GoogleFonts.inter(
                color: const Color(0xFFE8F1FF),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            for (final point in historyPoints.take(4)) ...[
              _partnerScopeHistoryRow(point),
              const SizedBox(height: 6),
            ],
          ],
          if (currentChains.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Current dispatch chains',
              style: GoogleFonts.inter(
                color: const Color(0xFFE8F1FF),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            for (var index = 0; index < currentChains.length; index++) ...[
              _partnerScopeDispatchChainRow(currentChains[index]),
              if (index < currentChains.length - 1) const SizedBox(height: 6),
            ],
          ],
        ],
      ),
    );
  }

  Widget _partnerScorecardLanesCard() {
    return OnyxSectionCard(
      title: 'Partner Scorecard Lanes',
      subtitle:
          'Enter a responder scorecard focus directly from Reports for this client and site.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (
            var index = 0;
            index < _sitePartnerScoreboardRows.length;
            index++
          ) ...[
            _partnerScorecardLaneRow(_sitePartnerScoreboardRows[index]),
            if (index < _sitePartnerScoreboardRows.length - 1)
              const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _partnerComparisonCard() {
    final comparisons = _sitePartnerComparisonRows;
    final receiptRows = _siteScopeReceiptRows();
    final receiptInvestigationComparison =
        _receiptInvestigationComparison(receiptRows);
    final receiptInvestigationTrendLabel = _receiptInvestigationTrendLabel(
      receiptRows,
    );
    return OnyxSectionCard(
      title: 'Partner Comparison',
      subtitle:
          _partnerComparisonWindow == ReportPartnerComparisonWindow.latestShift
          ? 'Current-shift comparison for responder lanes on this site, ranked against the strongest scorecard.'
          : 'Three-shift baseline comparison for responder lanes on this site, using recent scorecard history.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pillActionButton(
                buttonKey: const ValueKey(
                  'reports-partner-comparison-window-latest',
                ),
                label: 'Latest Shift',
                icon: Icons.bolt_rounded,
                filled:
                    _partnerComparisonWindow ==
                    ReportPartnerComparisonWindow.latestShift,
                onTap:
                    _partnerComparisonWindow ==
                        ReportPartnerComparisonWindow.latestShift
                    ? null
                    : () => setReportPartnerComparisonWindow(
                        ReportPartnerComparisonWindow.latestShift,
                      ),
              ),
              _pillActionButton(
                buttonKey: const ValueKey(
                  'reports-partner-comparison-window-baseline',
                ),
                label: '3-Shift Baseline',
                icon: Icons.timeline_rounded,
                filled:
                    _partnerComparisonWindow ==
                    ReportPartnerComparisonWindow.baseline3Shift,
                onTap:
                    _partnerComparisonWindow ==
                        ReportPartnerComparisonWindow.baseline3Shift
                    ? null
                    : () => setReportPartnerComparisonWindow(
                        ReportPartnerComparisonWindow.baseline3Shift,
                      ),
              ),
            ],
          ),
          if (receiptRows.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _partnerScopeChip(
                  label:
                      'Receipt ${receiptInvestigationTrendLabel.toUpperCase()}',
                  color: _receiptInvestigationTrendColor(
                    receiptInvestigationTrendLabel,
                  ),
                ),
                _partnerScopeChip(
                  label:
                      'Current Governance: ${receiptInvestigationComparison.currentGovernanceCount}',
                  color: const Color(0xFF5DC8FF),
                ),
                _partnerScopeChip(
                  label:
                      'Current Routine: ${receiptInvestigationComparison.currentRoutineCount}',
                  color: const Color(0xFF8EA4C2),
                ),
                _partnerScopeChip(
                  label:
                      'Baseline Governance: ${receiptInvestigationComparison.baselineGovernanceAverage.toStringAsFixed(1)}',
                  color: const Color(0xFF4F87BE),
                ),
                _partnerScopeChip(
                  label:
                      'Baseline Routine: ${receiptInvestigationComparison.baselineRoutineAverage.toStringAsFixed(1)}',
                  color: const Color(0xFF7087A8),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _receiptInvestigationTrendReason(receiptRows),
              style: GoogleFonts.inter(
                color: _receiptInvestigationTrendColor(
                  receiptInvestigationTrendLabel,
                ),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton(
                key: const ValueKey('reports-partner-comparison-copy-json'),
                label: 'Copy Comparison JSON',
                icon: Icons.copy_all_rounded,
                onTap: _copyPartnerComparisonJson,
              ),
              _actionButton(
                key: const ValueKey('reports-partner-comparison-copy-csv'),
                label: 'Copy Comparison CSV',
                icon: Icons.table_chart_rounded,
                onTap: _copyPartnerComparisonCsv,
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < comparisons.length; index++) ...[
            _partnerComparisonRow(comparisons[index]),
            if (index < comparisons.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _receiptPolicyHistoryCard(List<_ReceiptRow> rows) {
    final trendLabel = _receiptPolicyTrendLabel(rows);
    final trendReason = _receiptPolicyTrendReason(rows);
    final investigationTrendLabel = _receiptInvestigationTrendLabel(rows);
    final investigationTrendReason = _receiptInvestigationTrendReason(rows);
    final governanceCount = _receiptGovernanceHandoffCount(rows);
    final routineCount = _receiptRoutineReviewCount(rows);
    final investigationComparison = _receiptInvestigationComparison(rows);
    final current = rows.isEmpty ? null : rows.first;
    final activeEntryContext = _activeReceiptPolicyEntryContext(rows);
    return OnyxSectionCard(
      title: 'Receipt Policy History',
      subtitle:
          'Recent generated receipts for this client and site, showing tracked policy capture, branding mode, and drift over time.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activeEntryContext != null) ...[
            _receiptPolicyEntryContextBanner(activeEntryContext),
            const SizedBox(height: 10),
          ],
          if (current != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _partnerScopeChip(
                  label: _receiptPolicyStateChipLabel(current.event),
                  color: _receiptPolicyAccent(current.event),
                ),
                _partnerScopeChip(
                  label: _receiptPolicyBrandingChipLabel(current.event),
                  color: _receiptPolicyBrandingAccent(current.event),
                ),
                _partnerScopeChip(
                  label: trendLabel,
                  color: _receiptPolicyTrendColor(trendLabel),
                ),
                _partnerScopeChip(
                  label: investigationTrendLabel,
                  color: _receiptInvestigationTrendColor(
                    investigationTrendLabel,
                  ),
                ),
                _partnerScopeChip(
                  label: '$governanceCount oversight',
                  color: const Color(0xFF5DC8FF),
                ),
                _partnerScopeChip(
                  label: '$routineCount routine',
                  color: const Color(0xFF8EA4C2),
                ),
                _partnerScopeChip(
                  label: '${rows.length} receipts',
                  color: const Color(0xFF8FD1FF),
                ),
              ],
            ),
          if (current != null) ...[
            const SizedBox(height: 8),
            Text(
              _receiptPolicyHistoryHeadline(current.event),
              style: GoogleFonts.inter(
                color: const Color(0xFFE8F1FF),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (trendReason.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              trendReason,
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (investigationTrendReason.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              investigationTrendReason,
              style: GoogleFonts.inter(
                color: _receiptInvestigationTrendColor(investigationTrendLabel),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          _receiptPolicyInvestigationLensCard(activeEntryContext),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _partnerScopeChip(
                  label:
                      'Current Governance: ${investigationComparison.currentGovernanceCount}',
                  color: const Color(0xFF5DC8FF),
                ),
                _partnerScopeChip(
                  label:
                      'Current Routine: ${investigationComparison.currentRoutineCount}',
                  color: const Color(0xFF8EA4C2),
                ),
                _partnerScopeChip(
                  label:
                      'Baseline Governance: ${investigationComparison.baselineGovernanceAverage.toStringAsFixed(1)}',
                  color: const Color(0xFF4F87BE),
                ),
                _partnerScopeChip(
                  label:
                      'Baseline Routine: ${investigationComparison.baselineRoutineAverage.toStringAsFixed(1)}',
                  color: const Color(0xFF7087A8),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton(
                key: const ValueKey(
                  'reports-receipt-policy-open-investigation-history',
                ),
                label: 'Open Investigation History',
                icon: Icons.manage_search_rounded,
                onTap: () => _openReceiptInvestigationHistory(rows),
              ),
              _actionButton(
                key: const ValueKey('reports-receipt-policy-copy-json'),
                label: 'Copy Policy JSON',
                icon: Icons.copy_all_rounded,
                onTap: () => _copyReceiptPolicyHistoryJson(rows),
              ),
              _actionButton(
                key: const ValueKey('reports-receipt-policy-copy-csv'),
                label: 'Copy Policy CSV',
                icon: Icons.table_chart_rounded,
                onTap: () => _copyReceiptPolicyHistoryCsv(rows),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < rows.length && index < 4; index++) ...[
            _receiptPolicyHistoryRow(rows[index], current: index == 0),
            if (index < rows.length - 1 && index < 3) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Future<void> _openReceiptInvestigationHistory(List<_ReceiptRow> rows) async {
    final trendLabel = _receiptInvestigationTrendLabel(rows);
    final trendReason = _receiptInvestigationTrendReason(rows);
    final governanceCount = _receiptGovernanceHandoffCount(rows);
    final routineCount = _receiptRoutineReviewCount(rows);
    final investigationComparison = _receiptInvestigationComparison(rows);
    final activeEntryContext = _activeReceiptPolicyEntryContext(rows);
    final current = rows.isEmpty ? null : rows.first;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF08111F),
          title: Text(
            'Receipt Investigation History',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE8F1FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (activeEntryContext != null) ...[
                    _receiptPolicyEntryContextBanner(activeEntryContext),
                    const SizedBox(height: 12),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _partnerScopeChip(
                        label: trendLabel,
                        color: _receiptInvestigationTrendColor(trendLabel),
                      ),
                      _partnerScopeChip(
                        label: '$governanceCount oversight',
                        color: const Color(0xFF5DC8FF),
                      ),
                      _partnerScopeChip(
                        label: '$routineCount routine',
                        color: const Color(0xFF8EA4C2),
                      ),
                      _partnerScopeChip(
                        label:
                            activeEntryContext ==
                                ReportEntryContext.governanceBrandingDrift
                            ? 'OVERSIGHT HANDOFF'
                            : 'ROUTINE REVIEW',
                        color:
                            activeEntryContext ==
                                ReportEntryContext.governanceBrandingDrift
                            ? const Color(0xFF5DC8FF)
                            : const Color(0xFF8EA4C2),
                      ),
                      _partnerScopeChip(
                        label: '${rows.length} receipts',
                        color: const Color(0xFF8FD1FF),
                      ),
                    ],
                  ),
                  if (current != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _receiptPolicyHistoryHeadline(current.event),
                      style: GoogleFonts.inter(
                        color: const Color(0xFFE8F1FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (rows.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _partnerScopeChip(
                          label:
                              'Current Governance: ${investigationComparison.currentGovernanceCount}',
                          color: const Color(0xFF5DC8FF),
                        ),
                        _partnerScopeChip(
                          label:
                              'Current Routine: ${investigationComparison.currentRoutineCount}',
                          color: const Color(0xFF8EA4C2),
                        ),
                        _partnerScopeChip(
                          label:
                              'Baseline Governance: ${investigationComparison.baselineGovernanceAverage.toStringAsFixed(1)}',
                          color: const Color(0xFF4F87BE),
                        ),
                        _partnerScopeChip(
                          label:
                              'Baseline Routine: ${investigationComparison.baselineRoutineAverage.toStringAsFixed(1)}',
                          color: const Color(0xFF7087A8),
                        ),
                        _partnerScopeChip(
                          label:
                              'Baseline Receipts: ${investigationComparison.baselineReceiptCount}',
                          color: const Color(0xFF8FD1FF),
                        ),
                      ],
                    ),
                  ],
                  if (trendReason.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      trendReason,
                      style: GoogleFonts.inter(
                        color: _receiptInvestigationTrendColor(trendLabel),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  for (var index = 0; index < rows.length; index++) ...[
                    _receiptPolicyHistoryRow(rows[index], current: index == 0),
                    if (index < rows.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey(
                'reports-receipt-policy-investigation-history-close',
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openPartnerScopeDrillIn() async {
    if (!_hasPartnerScopeFocus) {
      return;
    }
    await _openPartnerDrillIn(
      clientId: _partnerScopeClientId!,
      siteId: _partnerScopeSiteId!,
      partnerLabel: _partnerScopePartnerLabel!,
    );
  }

  Future<void> _openPartnerDrillIn({
    required String clientId,
    required String siteId,
    required String partnerLabel,
  }) async {
    final historyPoints = _partnerScopeHistoryPointsFor(
      clientId: clientId,
      siteId: siteId,
      partnerLabel: partnerLabel,
    );
    final currentChains = _partnerDispatchChainsForScope(
      clientId: clientId,
      siteId: siteId,
      partnerLabel: partnerLabel,
    );
    final receiptRows = _partnerReceiptRowsForScope(
      clientId: clientId,
      siteId: siteId,
    );
    final trendLabel = _partnerScopeTrendLabel(historyPoints);
    final trendReason = _partnerScopeTrendReason(historyPoints);
    final receiptInvestigationTrendLabel = _receiptInvestigationTrendLabel(
      receiptRows,
    );
    final receiptInvestigationComparison =
        _receiptInvestigationComparison(receiptRows);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF08111F),
          title: Text(
            'Partner Scorecard Drill-In',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE8F1FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$clientId/$siteId • $partnerLabel',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE8F1FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (trendLabel.isNotEmpty)
                        _partnerScopeChip(
                          label: trendLabel,
                          color: _partnerTrendColor(trendLabel),
                        ),
                      _partnerScopeChip(
                        label:
                            '${historyPoints.length} day${historyPoints.length == 1 ? '' : 's'}',
                      ),
                      _partnerScopeChip(
                        label:
                            '${currentChains.length} chain${currentChains.length == 1 ? '' : 's'}',
                      ),
                    ],
                  ),
                  if (trendReason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      trendReason,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8EA4C2),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (receiptRows.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Receipt provenance by shift',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFE8F1FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _partnerScopeChip(
                          label:
                              'Receipt ${receiptInvestigationTrendLabel.toUpperCase()}',
                          color: _receiptInvestigationTrendColor(
                            receiptInvestigationTrendLabel,
                          ),
                        ),
                        _partnerScopeChip(
                          label:
                              'Current Governance: ${receiptInvestigationComparison.currentGovernanceCount}',
                          color: const Color(0xFF5DC8FF),
                        ),
                        _partnerScopeChip(
                          label:
                              'Current Routine: ${receiptInvestigationComparison.currentRoutineCount}',
                          color: const Color(0xFF8EA4C2),
                        ),
                        _partnerScopeChip(
                          label:
                              'Baseline Governance: ${receiptInvestigationComparison.baselineGovernanceAverage.toStringAsFixed(1)}',
                          color: const Color(0xFF4F87BE),
                        ),
                        _partnerScopeChip(
                          label:
                              'Baseline Routine: ${receiptInvestigationComparison.baselineRoutineAverage.toStringAsFixed(1)}',
                          color: const Color(0xFF7087A8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _receiptInvestigationTrendReason(receiptRows),
                      style: GoogleFonts.inter(
                        color: _receiptInvestigationTrendColor(
                          receiptInvestigationTrendLabel,
                        ),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (historyPoints.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Scorecard history',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFE8F1FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (var index = 0; index < historyPoints.length; index++) ...[
                      _partnerScopeHistoryRow(
                        historyPoints[index],
                        onOpenShift: () =>
                            _openPartnerShiftDetail(historyPoints[index]),
                      ),
                      if (index < historyPoints.length - 1)
                        const SizedBox(height: 6),
                    ],
                  ],
                  if (currentChains.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Dispatch chains',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFE8F1FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (var index = 0; index < currentChains.length; index++) ...[
                      _partnerScopeDispatchChainRow(currentChains[index]),
                      if (index < currentChains.length - 1)
                        const SizedBox(height: 6),
                    ],
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('reports-partner-scorecard-drill-in-copy-json'),
              onPressed: () => _copyPartnerDrillInJson(
                clientId: clientId,
                siteId: siteId,
                partnerLabel: partnerLabel,
              ),
              child: const Text('Copy JSON'),
            ),
            TextButton(
              key: const ValueKey('reports-partner-scorecard-drill-in-copy-csv'),
              onPressed: () => _copyPartnerDrillInCsv(
                clientId: clientId,
                siteId: siteId,
                partnerLabel: partnerLabel,
              ),
              child: const Text('Copy CSV'),
            ),
            TextButton(
              key: const ValueKey('reports-partner-scorecard-drill-in-close'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openPartnerShiftDetail(
    _PartnerScopeHistoryPoint point,
  ) async {
    final receiptRows = _partnerReceiptRowsForScopeDate(
      clientId: point.row.clientId,
      siteId: point.row.siteId,
      reportDate: point.reportDate,
    );
    final chains = _partnerDispatchChainsForScopeDate(
      clientId: point.row.clientId,
      siteId: point.row.siteId,
      partnerLabel: point.row.partnerLabel,
      reportDate: point.reportDate,
    );
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF08111F),
          title: Text(
            'Partner Shift Detail',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE8F1FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${point.reportDate} • ${point.row.clientId}/${point.row.siteId} • ${point.row.partnerLabel}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE8F1FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _partnerScopeChip(
                        label: point.current ? 'CURRENT SHIFT' : 'SHIFT SNAPSHOT',
                        color: point.current
                            ? const Color(0xFF8FD1FF)
                            : const Color(0xFF8EA4C2),
                      ),
                      _partnerScopeChip(
                        label: _partnerScoreboardPrimaryLabel(point.row),
                        color: _partnerTrendColor(
                          _partnerScoreboardPrimaryLabel(point.row),
                        ),
                      ),
                      _partnerScopeChip(
                        label:
                            '${receiptRows.length} receipt${receiptRows.length == 1 ? '' : 's'}',
                        color: const Color(0xFF5DC8FF),
                      ),
                      _partnerScopeChip(
                        label:
                            '${chains.length} chain${chains.length == 1 ? '' : 's'}',
                        color: const Color(0xFF8EA4C2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    point.row.summaryLine,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9CB2D1),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (point.receiptInvestigationSummary != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      point.receiptInvestigationSummary!.summaryLine,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8FD1FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Shift receipts',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE8F1FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (receiptRows.isEmpty)
                    Text(
                      'No generated receipts were recorded for this shift.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8EA4C2),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    for (var index = 0; index < receiptRows.length; index++) ...[
                      _receiptPolicyHistoryRow(
                        receiptRows[index],
                        current: index == 0,
                      ),
                      if (index < receiptRows.length - 1)
                        const SizedBox(height: 8),
                    ],
                  const SizedBox(height: 12),
                  Text(
                    'Shift dispatch chains',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE8F1FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (chains.isEmpty)
                    Text(
                      'No partner dispatch chains were recorded for this shift.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8EA4C2),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    for (var index = 0; index < chains.length; index++) ...[
                      _partnerScopeDispatchChainRow(chains[index]),
                      if (index < chains.length - 1) const SizedBox(height: 6),
                    ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _actionButton(
                        key: ValueKey<String>(
                          'reports-partner-shift-copy-json-${point.reportDate}',
                        ),
                        label: 'Copy Shift JSON',
                        icon: Icons.copy_all_rounded,
                        onTap: () => _copyPartnerShiftJson(point),
                      ),
                      _actionButton(
                        key: ValueKey<String>(
                          'reports-partner-shift-copy-csv-${point.reportDate}',
                        ),
                        label: 'Copy Shift CSV',
                        icon: Icons.table_chart_rounded,
                        onTap: () => _copyPartnerShiftCsv(point),
                      ),
                    ],
                  ),
                  if (widget.onOpenEventsForScope != null &&
                      _partnerShiftEventIdsForScopeDate(
                        clientId: point.row.clientId,
                        siteId: point.row.siteId,
                        partnerLabel: point.row.partnerLabel,
                        reportDate: point.reportDate,
                      ).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _actionButton(
                      key: ValueKey<String>(
                        'reports-partner-shift-open-events-${point.reportDate}',
                      ),
                      label: 'Open Events Review',
                      icon: Icons.rule_folder_rounded,
                      onTap: () {
                        Navigator.of(context).pop();
                        _openEventsForPartnerShift(point);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('reports-partner-shift-detail-close'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _receiptPolicyInvestigationLensCard(
    ReportEntryContext? activeEntryContext,
  ) {
    final governanceContext =
        activeEntryContext == ReportEntryContext.governanceBrandingDrift;
    final activeLabel = governanceContext
        ? 'OVERSIGHT HANDOFF'
        : 'ROUTINE REVIEW';
    final activeColor = governanceContext
        ? const Color(0xFF5DC8FF)
        : const Color(0xFF8EA4C2);
    final activeDetail = governanceContext
        ? 'This receipt investigation was opened from Governance branding drift, so operators can compare the current lane against the normal Reports receipt baseline.'
        : 'This receipt investigation was opened directly in Reports without a Governance oversight handoff.';
    final baselineDetail = governanceContext
        ? 'Routine review is the default receipt-policy baseline when operators enter Reports without an oversight handoff.'
        : 'Governance-launched investigations will be labeled separately when a branding-drift handoff opens this lane.';
    return Container(
      key: const ValueKey('reports-receipt-policy-investigation-lens'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E31),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF253B57)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Investigation Lens',
            style: GoogleFonts.inter(
              color: const Color(0xFF8FD1FF),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _partnerScopeChip(label: activeLabel, color: activeColor),
              _partnerScopeChip(
                label: 'ROUTINE BASELINE',
                color: const Color(0xFF8EA4C2),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            activeDetail,
            style: GoogleFonts.inter(
              color: const Color(0xFFE8F1FF),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            baselineDetail,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptPolicyEntryContextBanner(ReportEntryContext entryContext) {
    final previewReceiptEventId = _previewReceiptEventId?.trim();
    return Container(
      key: const ValueKey('reports-receipt-policy-entry-context-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF102337),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF29425F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entryContext.bannerTitle,
            style: GoogleFonts.inter(
              color: const Color(0xFF8FD1FF),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entryContext.bannerDetail,
            style: GoogleFonts.inter(
              color: const Color(0xFFE8F1FF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (previewReceiptEventId != null && previewReceiptEventId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _partnerScopeChip(
                    label: 'Receipt • $previewReceiptEventId',
                    color: const Color(0xFF8FD1FF),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          _actionButton(
            key: const ValueKey('reports-receipt-policy-entry-context-clear'),
            label: 'Dismiss Context',
            icon: Icons.subdirectory_arrow_left_rounded,
            onTap: () {
              clearReportEntryContext();
              _showReceiptActionFeedback(
                'Governance branding-drift context cleared.',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _receiptPolicyHistoryRow(_ReceiptRow row, {required bool current}) {
    final event = row.event;
    final accent = _receiptPolicyAccent(event);
    final focused = _receiptPolicyRowMatchesPreviewTarget(row);
    final investigationContext = _storedEntryContextForReceipt(event);
    final backgroundColor = focused
        ? const Color(0x1428C3FF)
        : current
        ? const Color(0x1A0EA5E9)
        : const Color(0xFF0E1A2B);
    final borderColor = focused
        ? const Color(0xFF5DC8FF)
        : current
        ? const Color(0x550EA5E9)
        : const Color(0xFF223244);
    return Container(
      key: ValueKey<String>('reports-receipt-policy-row-${event.eventId}'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${event.eventId} • ${_formatUtc(event.occurredAt)}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFE8F1FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _receiptPolicyHistoryHeadline(event),
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (current)
                _partnerScopeChip(
                  label: 'CURRENT',
                  color: const Color(0xFF8FD1FF),
                ),
              if (focused) ...[
                if (current) const SizedBox(width: 6),
                _partnerScopeChip(
                  label:
                      _effectiveEntryContextForReceipt(event) ==
                          ReportEntryContext.governanceBrandingDrift
                      ? 'GOVERNANCE TARGET'
                      : 'FOCUSED',
                  color: const Color(0xFF5DC8FF),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _partnerScopeChip(
                label: _receiptPolicyStateChipLabel(event),
                color: accent,
              ),
              _partnerScopeChip(
                label: _receiptPolicyBrandingChipLabel(event),
                color: _receiptPolicyBrandingAccent(event),
              ),
              if (investigationContext != null)
                _partnerScopeChip(
                  label:
                      investigationContext ==
                          ReportEntryContext.governanceBrandingDrift
                      ? 'OVERSIGHT HANDOFF'
                      : 'ROUTINE REVIEW',
                  color:
                      investigationContext ==
                          ReportEntryContext.governanceBrandingDrift
                      ? const Color(0xFF5DC8FF)
                      : const Color(0xFF8EA4C2),
                ),
              _partnerScopeChip(
                label: '${event.eventCount} events',
                color: const Color(0xFF8EA4C2),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _receiptPolicyHistoryDetail(event),
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.onOpenEventsForScope != null) ...[
            const SizedBox(height: 8),
            _actionButton(
              key: ValueKey<String>(
                'reports-receipt-policy-open-events-${event.eventId}',
              ),
              label: 'Open Events Review',
              icon: Icons.rule_folder_rounded,
              onTap: () => _openEventsForReceiptPolicyRow(row),
            ),
          ],
        ],
      ),
    );
  }

  bool _receiptPolicyRowMatchesPreviewTarget(_ReceiptRow row) {
    final previewReceiptEventId = _previewReceiptEventId?.trim();
    if (previewReceiptEventId == null || previewReceiptEventId.isEmpty) {
      return false;
    }
    return row.event.eventId.trim() == previewReceiptEventId;
  }

  Widget _kpiCard({
    Key? key,
    required String label,
    required String value,
    required Color accent,
    required IconData icon,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    final card = Container(
      key: key,
      constraints: const BoxConstraints(minHeight: 108, minWidth: 220),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF11243A) : const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? accent.withValues(alpha: 0.85)
              : const Color(0xFF223244),
          width: isActive ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 3,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Spacer(),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF16273D),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF7D93B1),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              color: accent,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 8),
            Text(
              'ACTIVE FILTER',
              style: GoogleFonts.inter(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
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

  Widget _partnerScopeChip({
    required String label,
    Color color = const Color(0xFF8FD1FF),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _partnerScopeHistoryRow(
    _PartnerScopeHistoryPoint point, {
    VoidCallback? onOpenShift,
  }) {
    return Container(
      key: ValueKey<String>(
        'reports-partner-scope-history-${point.reportDate}',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: point.current
            ? const Color(0x1A0EA5E9)
            : const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: point.current
              ? const Color(0x550EA5E9)
              : const Color(0xFF223244),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            point.current ? '${point.reportDate} • CURRENT' : point.reportDate,
            style: GoogleFonts.inter(
              color: const Color(0xFFE8F1FF),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            point.row.summaryLine,
            style: GoogleFonts.inter(
              color: const Color(0xFF9CB2D1),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (point.receiptInvestigationSummary != null) ...[
            const SizedBox(height: 4),
            Text(
              point.receiptInvestigationSummary!.summaryLine,
              style: GoogleFonts.inter(
                color: const Color(0xFF8FD1FF),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (onOpenShift != null) ...[
            const SizedBox(height: 8),
            _actionButton(
              key: ValueKey<String>(
                'reports-partner-scope-history-open-${point.reportDate}',
              ),
              label: 'Open Shift',
              icon: Icons.timeline_rounded,
              onTap: onOpenShift,
            ),
          ],
        ],
      ),
    );
  }

  Widget _partnerComparisonRow(_PartnerComparisonRow comparison) {
    final row = comparison.row;
    final isActive = _partnerScoreboardMatchesFocus(row);
    final deltaParts = <String>[
      if (!comparison.isLeader && comparison.acceptDeltaMinutes != null)
        'Accept +${comparison.acceptDeltaMinutes!.toStringAsFixed(1)}m',
      if (!comparison.isLeader && comparison.onSiteDeltaMinutes != null)
        'On site +${comparison.onSiteDeltaMinutes!.toStringAsFixed(1)}m',
    ];
    return Container(
      key: ValueKey<String>(
        'reports-partner-comparison-${row.clientId}/${row.siteId}/${row.partnerLabel}',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? const Color(0x1418D39E) : const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFF59D79B) : const Color(0xFF223244),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.partnerLabel,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFE8F1FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comparison.summaryLine,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF9CB2D1),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _partnerScopeChip(
                    label: comparison.isLeader
                        ? 'LEADER'
                        : comparison.trendLabel,
                    color: comparison.isLeader
                        ? const Color(0xFF59D79B)
                        : _partnerTrendColor(comparison.trendLabel),
                  ),
                  if (isActive)
                    _partnerScopeChip(
                      label: 'ACTIVE',
                      color: const Color(0xFF59D79B),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comparison.isLeader
                ? _partnerComparisonWindow ==
                          ReportPartnerComparisonWindow.latestShift
                      ? 'Best current scorecard for this site.'
                      : 'Best recent baseline for this site.'
                : (deltaParts.isEmpty
                      ? comparison.trendReason
                      : '${deltaParts.join(' • ')} vs leader'),
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!comparison.isLeader && comparison.trendReason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              comparison.trendReason,
              style: GoogleFonts.inter(
                color: const Color(0xFF7D93B1),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (comparison.historyPoints.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Recent shifts',
              style: GoogleFonts.inter(
                color: const Color(0xFFE8F1FF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final point in comparison.historyPoints.take(3))
                  _partnerComparisonHistoryChip(
                    point,
                    onTap: () => _openPartnerShiftDetail(point),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton(
                key: ValueKey<String>(
                  'reports-partner-comparison-copy-json-${row.clientId}/${row.siteId}/${row.partnerLabel}',
                ),
                label: 'Copy JSON',
                icon: Icons.data_object_rounded,
                onTap: () => _copyPartnerDrillInJson(
                  clientId: row.clientId,
                  siteId: row.siteId,
                  partnerLabel: row.partnerLabel,
                ),
              ),
              _actionButton(
                key: ValueKey<String>(
                  'reports-partner-comparison-copy-csv-${row.clientId}/${row.siteId}/${row.partnerLabel}',
                ),
                label: 'Copy CSV',
                icon: Icons.table_chart_rounded,
                onTap: () => _copyPartnerDrillInCsv(
                  clientId: row.clientId,
                  siteId: row.siteId,
                  partnerLabel: row.partnerLabel,
                ),
              ),
              _actionButton(
                key: ValueKey<String>(
                  'reports-partner-comparison-open-events-${row.clientId}/${row.siteId}/${row.partnerLabel}',
                ),
                label: 'Open Events',
                icon: Icons.timeline_rounded,
                onTap: comparison.historyPoints.isEmpty
                    ? null
                    : () => _openEventsForPartnerShift(
                        comparison.historyPoints.first,
                      ),
              ),
              _actionButton(
                key: ValueKey<String>(
                  'reports-partner-comparison-open-latest-shift-${row.clientId}/${row.siteId}/${row.partnerLabel}',
                ),
                label: 'Open Latest Shift',
                icon: Icons.schedule_rounded,
                onTap: comparison.historyPoints.isEmpty
                    ? null
                    : () => _openPartnerShiftDetail(
                        comparison.historyPoints.first,
                      ),
              ),
              _actionButton(
                key: ValueKey<String>(
                  'reports-partner-comparison-open-drill-in-${row.clientId}/${row.siteId}/${row.partnerLabel}',
                ),
                label: 'Open Drill-In',
                icon: Icons.manage_search_rounded,
                onTap: () => _openPartnerDrillIn(
                  clientId: row.clientId,
                  siteId: row.siteId,
                  partnerLabel: row.partnerLabel,
                ),
              ),
              _actionButton(
                key: ValueKey<String>(
                  'reports-partner-comparison-focus-${row.clientId}/${row.siteId}/${row.partnerLabel}',
                ),
                label: isActive ? 'Focused' : 'Focus Lane',
                icon: isActive
                    ? Icons.check_circle_rounded
                    : Icons.filter_center_focus_rounded,
                onTap: isActive
                    ? null
                    : () => _setPartnerScopeFocus(
                        clientId: row.clientId,
                        siteId: row.siteId,
                        partnerLabel: row.partnerLabel,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _partnerComparisonHistoryChip(
    _PartnerScopeHistoryPoint point, {
    VoidCallback? onTap,
  }) {
    final summary = _partnerComparisonHistorySummary(point.row);
    final chip = Container(
      key: ValueKey<String>(
        'reports-partner-comparison-history-${point.row.clientId}/${point.row.siteId}/${point.row.partnerLabel}-${point.reportDate}',
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: point.current
            ? const Color(0x1A0EA5E9)
            : const Color(0xFF102337),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: point.current
              ? const Color(0x550EA5E9)
              : const Color(0xFF223244),
        ),
      ),
      child: Text(
        '${point.reportDate} • $summary',
        style: GoogleFonts.inter(
          color: point.current
              ? const Color(0xFFE8F1FF)
              : const Color(0xFF9CB2D1),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (onTap == null) {
      return chip;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: chip,
    );
  }

  Widget _partnerScorecardLaneRow(SovereignReportPartnerScoreboardRow row) {
    final historyPoints = _partnerScopeHistoryPointsFor(
      clientId: row.clientId,
      siteId: row.siteId,
      partnerLabel: row.partnerLabel,
    );
    final trendLabel = _partnerScopeTrendLabel(historyPoints);
    final trendReason = _partnerScopeTrendReason(historyPoints);
    final isActive = _partnerScoreboardMatchesFocus(row);
    return Container(
      key: ValueKey<String>(
        'reports-partner-lane-${row.clientId}/${row.siteId}/${row.partnerLabel}',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? const Color(0x1418D39E) : const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFF59D79B) : const Color(0xFF223244),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.partnerLabel,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFE8F1FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${row.clientId}/${row.siteId}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF7D93B1),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _partnerScopeChip(
                label: isActive ? 'ACTIVE' : trendLabel,
                color: isActive
                    ? const Color(0xFF59D79B)
                    : _partnerTrendColor(trendLabel),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            row.summaryLine,
            style: GoogleFonts.inter(
              color: const Color(0xFF9CB2D1),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (trendReason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              trendReason,
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton(
                key: ValueKey<String>(
                  'reports-partner-lane-focus-${row.clientId}/${row.siteId}/${row.partnerLabel}',
                ),
                label: isActive ? 'Focused' : 'Focus Lane',
                icon: isActive
                    ? Icons.check_circle_rounded
                    : Icons.filter_center_focus_rounded,
                onTap: isActive
                    ? null
                    : () => _setPartnerScopeFocus(
                        clientId: row.clientId,
                        siteId: row.siteId,
                        partnerLabel: row.partnerLabel,
                      ),
              ),
              if (widget.onOpenGovernanceForPartnerScope != null)
                _actionButton(
                  key: ValueKey<String>(
                    'reports-partner-lane-open-governance-${row.clientId}/${row.siteId}/${row.partnerLabel}',
                  ),
                  label: 'Open Governance',
                  icon: Icons.verified_user_rounded,
                  onTap: () {
                    widget.onOpenGovernanceForPartnerScope!(
                      row.clientId,
                      row.siteId,
                      row.partnerLabel,
                    );
                    _showReceiptActionFeedback(
                      'Opening Governance for ${row.siteId} • ${row.partnerLabel}.',
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _partnerScopeDispatchChainRow(
    SovereignReportPartnerDispatchChain chain,
  ) {
    final acceptedDelay = chain.acceptedDelayMinutes;
    final onSiteDelay = chain.onSiteDelayMinutes;
    final timingParts = <String>[
      if (acceptedDelay != null && acceptedDelay > 0)
        'Accepted ${acceptedDelay.toStringAsFixed(1)}m',
      if (onSiteDelay != null && onSiteDelay > 0)
        'On site ${onSiteDelay.toStringAsFixed(1)}m',
    ];
    return Container(
      key: ValueKey<String>('reports-partner-scope-chain-${chain.dispatchId}'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  chain.dispatchId,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE8F1FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _partnerScopeChip(
                label: chain.scoreLabel.trim().isEmpty
                    ? chain.latestStatus.name.toUpperCase()
                    : chain.scoreLabel.trim().toUpperCase(),
                color: _partnerTrendColor(
                  chain.scoreLabel.trim().toUpperCase(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            chain.workflowSummary.trim().isEmpty
                ? 'Latest ${chain.latestStatus.name.toUpperCase()}'
                : chain.workflowSummary.trim(),
            style: GoogleFonts.inter(
              color: const Color(0xFF9CB2D1),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (timingParts.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              timingParts.join(' • '),
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (chain.scoreReason.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              chain.scoreReason.trim(),
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (widget.onOpenEventsForScope != null &&
              _partnerDispatchChainEventIds(chain).isNotEmpty) ...[
            const SizedBox(height: 8),
            _actionButton(
              key: ValueKey<String>(
                'reports-partner-chain-open-events-${chain.dispatchId}',
              ),
              label: 'Open Events Review',
              icon: Icons.rule_folder_rounded,
              onTap: () => _openEventsForPartnerDispatchChain(chain),
            ),
          ],
        ],
      ),
    );
  }

  List<_PartnerScopeHistoryPoint> _partnerScopeHistoryPoints() {
    return _partnerScopeHistoryPointsFor(
      clientId: _partnerScopeClientId,
      siteId: _partnerScopeSiteId,
      partnerLabel: _partnerScopePartnerLabel,
    );
  }

  List<_PartnerScopeHistoryPoint> _partnerScopeHistoryPointsFor({
    required String? clientId,
    required String? siteId,
    required String? partnerLabel,
  }) {
    if (clientId == null || siteId == null || partnerLabel == null) {
      return const <_PartnerScopeHistoryPoint>[];
    }
    final reports = [...widget.morningSovereignReportHistory]
      ..sort((a, b) {
        final generatedCompare = b.generatedAtUtc.compareTo(a.generatedAtUtc);
        if (generatedCompare != 0) {
          return generatedCompare;
        }
        return b.date.compareTo(a.date);
      });
    if (reports.isEmpty) {
      return const <_PartnerScopeHistoryPoint>[];
    }
    final latestDate = reports.first.date.trim();
    final rows = <_PartnerScopeHistoryPoint>[];
    for (final report in reports) {
      final reportDate = report.date.trim();
      if (reportDate.isEmpty) {
        continue;
      }
      for (final row in report.partnerProgression.scoreboardRows) {
        if (!_partnerScoreboardMatchesScopeValues(
          row,
          clientId: clientId,
          siteId: siteId,
          partnerLabel: partnerLabel,
        )) {
          continue;
        }
        rows.add(
          _PartnerScopeHistoryPoint(
            reportDate: reportDate,
            row: row,
            current: reportDate == latestDate,
            receiptInvestigationSummary: _receiptInvestigationHistorySummaryFor(
              clientId: clientId,
              siteId: siteId,
              reportDate: reportDate,
            ),
          ),
        );
      }
    }
    return rows;
  }

  List<_PartnerComparisonRow> get _sitePartnerComparisonRows {
    final rows =
        _sitePartnerScoreboardRows
            .map((row) {
              final historyPoints = _partnerScopeHistoryPointsFor(
                clientId: row.clientId,
                siteId: row.siteId,
                partnerLabel: row.partnerLabel,
              );
              return _PartnerComparisonRow(
                row: row,
                trendLabel: _partnerScopeTrendLabel(historyPoints),
                trendReason: _partnerScopeTrendReason(historyPoints),
                historyPoints: historyPoints,
                summaryLine: _partnerComparisonSummaryLine(
                  row,
                  historyPoints: historyPoints,
                ),
                metricAcceptedDelayMinutes: _partnerComparisonAcceptedDelay(
                  row,
                  historyPoints: historyPoints,
                ),
                metricOnSiteDelayMinutes: _partnerComparisonOnSiteDelay(
                  row,
                  historyPoints: historyPoints,
                ),
                metricSeverityScore: _partnerComparisonSeverityScore(
                  row,
                  historyPoints: historyPoints,
                ),
                isLeader: false,
                acceptDeltaMinutes: null,
                onSiteDeltaMinutes: null,
              );
            })
            .toList(growable: true)
          ..sort((a, b) {
            final severityCompare = a.metricSeverityScore.compareTo(
              b.metricSeverityScore,
            );
            if (severityCompare != 0) {
              return severityCompare;
            }
            final acceptedCompare = a.metricAcceptedDelayMinutes.compareTo(
              b.metricAcceptedDelayMinutes,
            );
            if (acceptedCompare != 0) {
              return acceptedCompare;
            }
            final onSiteCompare = a.metricOnSiteDelayMinutes.compareTo(
              b.metricOnSiteDelayMinutes,
            );
            if (onSiteCompare != 0) {
              return onSiteCompare;
            }
            return a.row.partnerLabel.compareTo(b.row.partnerLabel);
          });
    if (rows.isEmpty) {
      return const <_PartnerComparisonRow>[];
    }
    final leader = rows.first;
    return rows
        .map((comparison) {
          final acceptDelta = identical(comparison, leader)
              ? null
              : (comparison.metricAcceptedDelayMinutes -
                    leader.metricAcceptedDelayMinutes);
          final onSiteDelta = identical(comparison, leader)
              ? null
              : (comparison.metricOnSiteDelayMinutes -
                    leader.metricOnSiteDelayMinutes);
          return comparison.copyWith(
            isLeader: identical(comparison, leader),
            acceptDeltaMinutes: acceptDelta != null && acceptDelta > 0
                ? double.parse(acceptDelta.toStringAsFixed(1))
                : null,
            onSiteDeltaMinutes: onSiteDelta != null && onSiteDelta > 0
                ? double.parse(onSiteDelta.toStringAsFixed(1))
                : null,
          );
        })
        .toList(growable: false);
  }

  List<SovereignReportPartnerDispatchChain> _partnerScopeDispatchChains() {
    if (!_hasPartnerScopeFocus) {
      return const <SovereignReportPartnerDispatchChain>[];
    }
    return _partnerDispatchChainsForScope(
      clientId: _partnerScopeClientId!,
      siteId: _partnerScopeSiteId!,
      partnerLabel: _partnerScopePartnerLabel!,
    );
  }

  List<SovereignReportPartnerDispatchChain> _partnerDispatchChainsForScope({
    required String clientId,
    required String siteId,
    required String partnerLabel,
  }) {
    final reports = [...widget.morningSovereignReportHistory]
      ..sort((a, b) {
        final generatedCompare = b.generatedAtUtc.compareTo(a.generatedAtUtc);
        if (generatedCompare != 0) {
          return generatedCompare;
        }
        return b.date.compareTo(a.date);
      });
    if (reports.isEmpty) {
      return const <SovereignReportPartnerDispatchChain>[];
    }
    return reports.first.partnerProgression.dispatchChains
        .where(
          (chain) => _partnerDispatchChainMatchesScopeValues(
            chain,
            clientId: clientId,
            siteId: siteId,
            partnerLabel: partnerLabel,
          ),
        )
        .toList(growable: false);
  }

  List<PartnerDispatchStatusDeclared> _partnerDispatchChainEvents(
    SovereignReportPartnerDispatchChain chain,
  ) {
    final dispatchId = chain.dispatchId.trim();
    if (dispatchId.isEmpty) {
      return const <PartnerDispatchStatusDeclared>[];
    }
    final partnerLabel = chain.partnerLabel.trim().toUpperCase();
    final matched =
        widget.store
            .allEvents()
            .whereType<PartnerDispatchStatusDeclared>()
            .where(
              (event) =>
                  event.dispatchId.trim() == dispatchId &&
                  event.clientId.trim() == chain.clientId.trim() &&
                  event.siteId.trim() == chain.siteId.trim() &&
                  event.partnerLabel.trim().toUpperCase() == partnerLabel,
            )
            .toList(growable: false)
          ..sort(_compareDispatchEventsByOccurredAtThenSequence);
    return matched;
  }

  List<String> _partnerDispatchChainEventIds(
    SovereignReportPartnerDispatchChain chain,
  ) {
    return _partnerDispatchChainEvents(chain)
        .map((event) => event.eventId.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  void _openEventsForPartnerDispatchChain(
    SovereignReportPartnerDispatchChain chain,
  ) {
    final eventIds = _partnerDispatchChainEventIds(chain);
    if (widget.onOpenEventsForScope == null || eventIds.isEmpty) {
      return;
    }
    widget.onOpenEventsForScope!(eventIds, eventIds.last);
    _showReceiptActionFeedback(
      'Opening Events Review for ${chain.dispatchId} • ${chain.partnerLabel}.',
    );
  }

  bool _partnerScoreboardMatchesScope(SovereignReportPartnerScoreboardRow row) {
    return _partnerScoreboardMatchesScopeValues(
      row,
      clientId: _partnerScopeClientId,
      siteId: _partnerScopeSiteId,
      partnerLabel: _partnerScopePartnerLabel,
    );
  }

  bool _partnerScoreboardMatchesFocus(SovereignReportPartnerScoreboardRow row) {
    return _partnerScoreboardMatchesScope(row);
  }

  bool _partnerScoreboardMatchesScopeValues(
    SovereignReportPartnerScoreboardRow row, {
    required String? clientId,
    required String? siteId,
    required String? partnerLabel,
  }) {
    return clientId != null &&
        siteId != null &&
        partnerLabel != null &&
        row.clientId.trim() == clientId &&
        row.siteId.trim() == siteId &&
        row.partnerLabel.trim().toUpperCase() == partnerLabel.toUpperCase();
  }

  bool _partnerDispatchChainMatchesScopeValues(
    SovereignReportPartnerDispatchChain chain, {
    required String? clientId,
    required String? siteId,
    required String? partnerLabel,
  }) {
    return clientId != null &&
        siteId != null &&
        partnerLabel != null &&
        chain.clientId.trim() == clientId &&
        chain.siteId.trim() == siteId &&
        chain.partnerLabel.trim().toUpperCase() == partnerLabel.toUpperCase();
  }

  String _partnerScopeTrendLabel(List<_PartnerScopeHistoryPoint> points) {
    if (points.isEmpty) {
      return '';
    }
    final current = points.firstWhere(
      (point) => point.current,
      orElse: () => points.first,
    );
    final priorRows = points
        .where((point) => !point.current)
        .map((point) => point.row)
        .toList(growable: false);
    if (priorRows.isEmpty) {
      return 'NEW';
    }
    final priorAverage =
        priorRows
            .map((row) => _partnerSeverityScore(row))
            .reduce((left, right) => left + right) /
        priorRows.length;
    final currentScore = _partnerSeverityScore(current.row);
    if (currentScore <= priorAverage - 0.35) {
      return 'IMPROVING';
    }
    if (currentScore >= priorAverage + 0.35) {
      return 'SLIPPING';
    }
    return 'STABLE';
  }

  String _partnerScopeTrendReason(List<_PartnerScopeHistoryPoint> points) {
    if (points.isEmpty) {
      return '';
    }
    final current = points.firstWhere(
      (point) => point.current,
      orElse: () => points.first,
    );
    final priorRows = points
        .where((point) => !point.current)
        .map((point) => point.row)
        .toList(growable: false);
    if (priorRows.isEmpty) {
      return 'First recorded shift in the available scorecard history.';
    }
    final trendLabel = _partnerScopeTrendLabel(points);
    final priorAcceptedRows = priorRows
        .where((row) => row.averageAcceptedDelayMinutes > 0)
        .toList(growable: false);
    final priorOnSiteRows = priorRows
        .where((row) => row.averageOnSiteDelayMinutes > 0)
        .toList(growable: false);
    final priorAcceptedAverage = priorAcceptedRows.isEmpty
        ? null
        : priorAcceptedRows
                  .map((row) => row.averageAcceptedDelayMinutes)
                  .reduce((left, right) => left + right) /
              priorAcceptedRows.length;
    final priorOnSiteAverage = priorOnSiteRows.isEmpty
        ? null
        : priorOnSiteRows
                  .map((row) => row.averageOnSiteDelayMinutes)
                  .reduce((left, right) => left + right) /
              priorOnSiteRows.length;
    switch (trendLabel) {
      case 'IMPROVING':
        if (priorAcceptedAverage != null &&
            current.row.averageAcceptedDelayMinutes > 0 &&
            current.row.averageAcceptedDelayMinutes <=
                priorAcceptedAverage - 2.0) {
          return 'Acceptance timing improved against the prior scorecard average.';
        }
        if (priorOnSiteAverage != null &&
            current.row.averageOnSiteDelayMinutes > 0 &&
            current.row.averageOnSiteDelayMinutes <= priorOnSiteAverage - 2.0) {
          return 'On-site timing improved against the prior scorecard average.';
        }
        return 'Current shift severity improved against prior scorecards.';
      case 'SLIPPING':
        if (priorAcceptedAverage != null &&
            current.row.averageAcceptedDelayMinutes >=
                priorAcceptedAverage + 2.0) {
          return 'Acceptance timing slipped beyond the prior scorecard average.';
        }
        if (priorOnSiteAverage != null &&
            current.row.averageOnSiteDelayMinutes >= priorOnSiteAverage + 2.0) {
          return 'On-site timing slipped beyond the prior scorecard average.';
        }
        return 'Current shift severity slipped against prior scorecards.';
      case 'STABLE':
      case 'NEW':
        return 'Current shift is holding close to the recent scorecard baseline.';
    }
    return '';
  }

  bool _hasTrackedReceiptPolicy(ReportGenerated event) {
    return event.reportSchemaVersion >= 3;
  }

  List<String> _receiptIncludedSectionLabels(ReportGenerated event) {
    return <String>[
      if (event.includeTimeline) 'Incident Timeline',
      if (event.includeDispatchSummary) 'Dispatch Summary',
      if (event.includeCheckpointCompliance) 'Checkpoint Compliance',
      if (event.includeAiDecisionLog) 'AI Decision Log',
      if (event.includeGuardMetrics) 'Guard Metrics',
    ];
  }

  List<String> _receiptOmittedSectionLabels(ReportGenerated event) {
    return <String>[
      if (!event.includeTimeline) 'Incident Timeline',
      if (!event.includeDispatchSummary) 'Dispatch Summary',
      if (!event.includeCheckpointCompliance) 'Checkpoint Compliance',
      if (!event.includeAiDecisionLog) 'AI Decision Log',
      if (!event.includeGuardMetrics) 'Guard Metrics',
    ];
  }

  Color _receiptPolicyAccent(ReportGenerated event) {
    if (event.brandingUsesOverride) {
      return const Color(0xFFF6C067);
    }
    if (!_hasTrackedReceiptPolicy(event)) {
      return const Color(0xFF8EA5C6);
    }
    return _receiptOmittedSectionLabels(event).isEmpty
        ? const Color(0xFF59D79B)
        : const Color(0xFFF6C067);
  }

  String _receiptPolicyStateChipLabel(ReportGenerated event) {
    if (!_hasTrackedReceiptPolicy(event)) {
      return 'LEGACY';
    }
    final omitted = _receiptOmittedSectionLabels(event);
    if (omitted.isEmpty) {
      return 'FULL POLICY';
    }
    return '${omitted.length} OMITTED';
  }

  String _receiptPolicyHistoryHeadline(ReportGenerated event) {
    final brandingHeadline = _receiptPolicyBrandingHeadline(event);
    if (!_hasTrackedReceiptPolicy(event)) {
      return brandingHeadline == null
          ? 'Legacy receipt configuration'
          : 'Legacy receipt configuration • $brandingHeadline';
    }
    final omitted = _receiptOmittedSectionLabels(event);
    final policyHeadline = omitted.isEmpty
        ? 'All sections included'
        : 'Omitted ${omitted.join(', ')}';
    return brandingHeadline == null
        ? policyHeadline
        : '$policyHeadline • $brandingHeadline';
  }

  String _receiptPolicyHistoryDetail(ReportGenerated event) {
    final brandingSummary = _receiptPolicyBrandingSummary(event);
    if (!_hasTrackedReceiptPolicy(event)) {
      return '$brandingSummary Per-section report configuration was not captured for this receipt. Replay policy drift must be inferred from legacy behavior.';
    }
    final included = _receiptIncludedSectionLabels(event);
    final omitted = _receiptOmittedSectionLabels(event);
    final includedLabel = included.isEmpty ? 'None' : included.join(', ');
    final omittedLabel = omitted.isEmpty ? 'None' : omitted.join(', ');
    return '$brandingSummary Included: $includedLabel. Omitted: $omittedLabel.';
  }

  double _receiptPolicySeverityScore(ReportGenerated event) {
    if (!_hasTrackedReceiptPolicy(event)) {
      return 3.0 + _receiptPolicyBrandingSeverityScore(event);
    }
    final omitted = _receiptOmittedSectionLabels(event);
    if (omitted.isEmpty) {
      return 1.0 + _receiptPolicyBrandingSeverityScore(event);
    }
    return 1.5 + omitted.length + _receiptPolicyBrandingSeverityScore(event);
  }

  String _receiptPolicyTrendLabel(List<_ReceiptRow> rows) {
    if (rows.isEmpty) {
      return 'NO DATA';
    }
    if (rows.length == 1) {
      return 'NEW';
    }
    final currentScore = _receiptPolicySeverityScore(rows.first.event);
    final priorScores = rows
        .skip(1)
        .map((row) => _receiptPolicySeverityScore(row.event))
        .toList(growable: false);
    final priorAverage =
        priorScores.reduce((left, right) => left + right) / priorScores.length;
    if (currentScore <= priorAverage - 0.35) {
      return 'IMPROVING';
    }
    if (currentScore >= priorAverage + 0.35) {
      return 'SLIPPING';
    }
    return 'STABLE';
  }

  String _receiptPolicyTrendReason(List<_ReceiptRow> rows) {
    if (rows.isEmpty) {
      return 'No generated receipts are available for this client and site.';
    }
    if (rows.length == 1) {
      return 'This is the first recorded receipt policy snapshot for this client and site.';
    }
    final current = rows.first.event;
    final trend = _receiptPolicyTrendLabel(rows);
    switch (trend) {
      case 'IMPROVING':
        if (!current.brandingUsesOverride &&
            rows.skip(1).any((row) => row.event.brandingUsesOverride)) {
          return 'The latest receipt returned from custom branding overrides to baseline branding.';
        }
        if (_hasTrackedReceiptPolicy(current) &&
            _receiptOmittedSectionLabels(current).isEmpty) {
          return 'The latest receipt returned to full tracked policy coverage.';
        }
        return 'The latest receipt reduced omitted-section or legacy risk against recent history.';
      case 'SLIPPING':
        if (current.brandingUsesOverride &&
            rows.skip(1).every((row) => !row.event.brandingUsesOverride)) {
          return 'The latest receipt introduced a custom branding override against the recent receipt baseline.';
        }
        if (!_hasTrackedReceiptPolicy(current)) {
          return 'The latest receipt fell back to legacy policy capture.';
        }
        return 'The latest receipt omitted more sections than the recent receipt baseline.';
      case 'STABLE':
        return 'The latest receipt is holding close to the recent policy baseline.';
      case 'NEW':
      case 'NO DATA':
        return 'This is the first recorded receipt policy snapshot for this client and site.';
    }
    return '';
  }

  double _receiptInvestigationSeverityScore(ReportGenerated event) {
    return _storedEntryContextForReceipt(event) ==
            ReportEntryContext.governanceBrandingDrift
        ? 1.0
        : 0.0;
  }

  int _receiptGovernanceHandoffCount(List<_ReceiptRow> rows) {
    return rows
        .where(
          (row) =>
              _storedEntryContextForReceipt(row.event) ==
              ReportEntryContext.governanceBrandingDrift,
        )
        .length;
  }

  int _receiptRoutineReviewCount(List<_ReceiptRow> rows) {
    return rows.length - _receiptGovernanceHandoffCount(rows);
  }

  _ReceiptInvestigationComparison _receiptInvestigationComparison(
    List<_ReceiptRow> rows,
  ) {
    if (rows.isEmpty) {
      return const _ReceiptInvestigationComparison(
        currentGovernanceCount: 0,
        currentRoutineCount: 0,
        baselineGovernanceAverage: 0,
        baselineRoutineAverage: 0,
        baselineReceiptCount: 0,
      );
    }
    final currentContext = _storedEntryContextForReceipt(rows.first.event);
    final baselineRows = rows.skip(1).toList(growable: false);
    if (baselineRows.isEmpty) {
      return _ReceiptInvestigationComparison(
        currentGovernanceCount:
            currentContext == ReportEntryContext.governanceBrandingDrift
            ? 1
            : 0,
        currentRoutineCount:
            currentContext == ReportEntryContext.governanceBrandingDrift
            ? 0
            : 1,
        baselineGovernanceAverage: 0,
        baselineRoutineAverage: 0,
        baselineReceiptCount: 0,
      );
    }
    final baselineGovernanceCount =
        baselineRows
            .where(
              (row) =>
                  _storedEntryContextForReceipt(row.event) ==
                  ReportEntryContext.governanceBrandingDrift,
            )
            .length;
    final baselineRoutineCount = baselineRows.length - baselineGovernanceCount;
    return _ReceiptInvestigationComparison(
      currentGovernanceCount:
          currentContext == ReportEntryContext.governanceBrandingDrift ? 1 : 0,
      currentRoutineCount:
          currentContext == ReportEntryContext.governanceBrandingDrift ? 0 : 1,
      baselineGovernanceAverage:
          baselineGovernanceCount / baselineRows.length,
      baselineRoutineAverage: baselineRoutineCount / baselineRows.length,
      baselineReceiptCount: baselineRows.length,
    );
  }

  String _receiptInvestigationTrendLabel(List<_ReceiptRow> rows) {
    if (rows.isEmpty) {
      return 'NO DATA';
    }
    if (rows.length == 1) {
      return 'NEW';
    }
    final currentScore = _receiptInvestigationSeverityScore(rows.first.event);
    final priorScores = rows
        .skip(1)
        .map((row) => _receiptInvestigationSeverityScore(row.event))
        .toList(growable: false);
    final priorAverage =
        priorScores.reduce((left, right) => left + right) / priorScores.length;
    if (currentScore >= priorAverage + 0.35) {
      return 'OVERSIGHT RISING';
    }
    if (currentScore <= priorAverage - 0.35) {
      return 'OVERSIGHT EASING';
    }
    return 'STABLE';
  }

  String _receiptInvestigationTrendReason(List<_ReceiptRow> rows) {
    if (rows.isEmpty) {
      return 'No receipt investigation provenance is available for this client and site.';
    }
    if (rows.length == 1) {
      return 'This is the first recorded receipt investigation snapshot for this client and site.';
    }
    final current = rows.first.event;
    final currentContext = _storedEntryContextForReceipt(current);
    final trend = _receiptInvestigationTrendLabel(rows);
    switch (trend) {
      case 'OVERSIGHT RISING':
        return currentContext == ReportEntryContext.governanceBrandingDrift
            ? 'The latest receipt entered Reports through a Governance branding-drift handoff against a more routine recent baseline.'
            : 'Governance-opened receipt investigations increased against the recent baseline.';
      case 'OVERSIGHT EASING':
        return currentContext == ReportEntryContext.governanceBrandingDrift
            ? 'Governance-opened receipt investigations eased against recent history.'
            : 'The latest receipt returned to routine review without a Governance handoff.';
      case 'STABLE':
        return 'Receipt investigation provenance is holding close to the recent baseline.';
      case 'NEW':
      case 'NO DATA':
        return 'This is the first recorded receipt investigation snapshot for this client and site.';
    }
    return '';
  }

  String _receiptPolicyBrandingChipLabel(ReportGenerated event) {
    if (!event.brandingConfiguration.isConfigured) {
      return 'STANDARD BRANDING';
    }
    return event.brandingUsesOverride ? 'CUSTOM BRANDING' : 'DEFAULT BRANDING';
  }

  Color _receiptPolicyBrandingAccent(ReportGenerated event) {
    if (!event.brandingConfiguration.isConfigured) {
      return const Color(0xFF8EA5C6);
    }
    return event.brandingUsesOverride
        ? const Color(0xFFF6C067)
        : const Color(0xFF63BDFF);
  }

  String? _receiptPolicyBrandingHeadline(ReportGenerated event) {
    if (!event.brandingConfiguration.isConfigured) {
      return null;
    }
    return event.brandingUsesOverride ? 'Custom branding' : 'Default branding';
  }

  String _receiptPolicyBrandingSummary(ReportGenerated event) {
    if (!event.brandingConfiguration.isConfigured) {
      return 'Branding: standard ONYX identity.';
    }
    final sourceLabel = event.brandingConfiguration.sourceLabel.trim();
    if (event.brandingUsesOverride) {
      return sourceLabel.isNotEmpty
          ? 'Branding: custom override from default partner lane $sourceLabel.'
          : 'Branding: custom override was used for this receipt.';
    }
    return sourceLabel.isNotEmpty
        ? 'Branding: default partner lane $sourceLabel.'
        : 'Branding: configured partner label was used.';
  }

  double _receiptPolicyBrandingSeverityScore(ReportGenerated event) {
    if (!event.brandingConfiguration.isConfigured) {
      return 0;
    }
    return event.brandingUsesOverride ? 1.0 : 0.25;
  }

  Color _receiptPolicyTrendColor(String trendLabel) {
    switch (trendLabel) {
      case 'IMPROVING':
        return const Color(0xFF59D79B);
      case 'SLIPPING':
        return const Color(0xFFF6C067);
      case 'STABLE':
        return const Color(0xFF8FD1FF);
      case 'NEW':
        return const Color(0xFF8EA5C6);
      case 'NO DATA':
      default:
        return const Color(0xFF8EA4C2);
    }
  }

  Color _receiptInvestigationTrendColor(String trendLabel) {
    switch (trendLabel) {
      case 'OVERSIGHT RISING':
        return const Color(0xFFF6C067);
      case 'OVERSIGHT EASING':
        return const Color(0xFF59D79B);
      case 'STABLE':
        return const Color(0xFF8FD1FF);
      case 'NEW':
        return const Color(0xFF8EA5C6);
      case 'NO DATA':
      default:
        return const Color(0xFF8EA4C2);
    }
  }

  void _openEventsForReceiptPolicyRow(_ReceiptRow row) {
    final eventId = row.event.eventId.trim();
    if (widget.onOpenEventsForScope == null || eventId.isEmpty) {
      return;
    }
    widget.onOpenEventsForScope!(<String>[eventId], eventId);
    _showReceiptActionFeedback(
      'Opening Events Review for ${row.event.eventId}.',
    );
  }

  double _partnerSeverityScore(SovereignReportPartnerScoreboardRow row) {
    final dispatchCount = row.dispatchCount <= 0 ? 1 : row.dispatchCount;
    final rawScore = (row.criticalCount * 3) + row.watchCount - row.strongCount;
    return rawScore / dispatchCount;
  }

  double _partnerComparisonSeverityScore(
    SovereignReportPartnerScoreboardRow row, {
    required List<_PartnerScopeHistoryPoint> historyPoints,
  }) {
    if (_partnerComparisonWindow == ReportPartnerComparisonWindow.latestShift) {
      return _partnerSeverityScore(row);
    }
    final sample = historyPoints.take(3).map((point) => point.row).toList();
    if (sample.isEmpty) {
      return _partnerSeverityScore(row);
    }
    final total = sample
        .map((item) => _partnerSeverityScore(item))
        .reduce((left, right) => left + right);
    return total / sample.length;
  }

  double _partnerComparisonAcceptedDelay(
    SovereignReportPartnerScoreboardRow row, {
    required List<_PartnerScopeHistoryPoint> historyPoints,
  }) {
    if (_partnerComparisonWindow == ReportPartnerComparisonWindow.latestShift) {
      return row.averageAcceptedDelayMinutes;
    }
    final sample = historyPoints.take(3).map((point) => point.row).toList();
    if (sample.isEmpty) {
      return row.averageAcceptedDelayMinutes;
    }
    return sample
            .map((item) => item.averageAcceptedDelayMinutes)
            .reduce((left, right) => left + right) /
        sample.length;
  }

  double _partnerComparisonOnSiteDelay(
    SovereignReportPartnerScoreboardRow row, {
    required List<_PartnerScopeHistoryPoint> historyPoints,
  }) {
    if (_partnerComparisonWindow == ReportPartnerComparisonWindow.latestShift) {
      return row.averageOnSiteDelayMinutes;
    }
    final sample = historyPoints.take(3).map((point) => point.row).toList();
    if (sample.isEmpty) {
      return row.averageOnSiteDelayMinutes;
    }
    return sample
            .map((item) => item.averageOnSiteDelayMinutes)
            .reduce((left, right) => left + right) /
        sample.length;
  }

  String _partnerComparisonSummaryLine(
    SovereignReportPartnerScoreboardRow row, {
    required List<_PartnerScopeHistoryPoint> historyPoints,
  }) {
    if (_partnerComparisonWindow == ReportPartnerComparisonWindow.latestShift) {
      return row.summaryLine;
    }
    final sample = historyPoints.take(3).map((point) => point.row).toList();
    if (sample.isEmpty) {
      return row.summaryLine;
    }
    final averageAccept = _partnerComparisonAcceptedDelay(
      row,
      historyPoints: historyPoints,
    );
    final averageOnSite = _partnerComparisonOnSiteDelay(
      row,
      historyPoints: historyPoints,
    );
    final strongCount = sample
        .map((item) => item.strongCount)
        .reduce((left, right) => left + right);
    final onTrackCount = sample
        .map((item) => item.onTrackCount)
        .reduce((left, right) => left + right);
    final watchCount = sample
        .map((item) => item.watchCount)
        .reduce((left, right) => left + right);
    final criticalCount = sample
        .map((item) => item.criticalCount)
        .reduce((left, right) => left + right);
    return '3-shift baseline • Strong $strongCount • On track $onTrackCount • Watch $watchCount • Critical $criticalCount • Avg accept ${averageAccept.toStringAsFixed(1)}m • Avg on site ${averageOnSite.toStringAsFixed(1)}m';
  }

  String _partnerComparisonHistorySummary(
    SovereignReportPartnerScoreboardRow row,
  ) {
    if (row.criticalCount > 0) {
      return '${row.criticalCount} critical';
    }
    if (row.watchCount > 0) {
      return '${row.watchCount} watch';
    }
    if (row.onTrackCount > 0) {
      return '${row.onTrackCount} on track';
    }
    if (row.strongCount > 0) {
      return '${row.strongCount} strong';
    }
    return '${row.dispatchCount} dispatches';
  }

  String _partnerScoreboardPrimaryLabel(
    SovereignReportPartnerScoreboardRow row,
  ) {
    if (row.criticalCount > 0) {
      return 'CRITICAL';
    }
    if (row.watchCount > 0) {
      return 'WATCH';
    }
    if (row.onTrackCount > 0) {
      return 'ON TRACK';
    }
    if (row.strongCount > 0) {
      return 'STRONG';
    }
    return 'NO SCORE';
  }

  Color _partnerTrendColor(String label) {
    switch (label.trim().toUpperCase()) {
      case 'STRONG':
        return const Color(0xFF59D79B);
      case 'ON TRACK':
        return const Color(0xFF8FD1FF);
      case 'WATCH':
        return const Color(0xFFF6C067);
      case 'CRITICAL':
        return const Color(0xFFFF7A7A);
      case 'IMPROVING':
        return const Color(0xFF59D79B);
      case 'SLIPPING':
        return const Color(0xFFFF7A7A);
      case 'STABLE':
        return const Color(0xFF8FD1FF);
      case 'NEW':
        return const Color(0xFFF6C067);
      default:
        return const Color(0xFF8EA4C2);
    }
  }

  Widget _buildDeterministicControls() {
    final scopes = <String>[
      'Sandton Estate North',
      'Waterfall Estate Main',
      'Blue Ridge Security',
      'Midrand Industrial Park',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Client / Site'),
        const SizedBox(height: 4),
        _dropdownField(
          value: _selectedScope,
          items: scopes,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => _selectedScope = value);
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _dateField(
                label: 'Start Date',
                date: _startDate,
                onTap: () => _pickDate(
                  initial: _startDate,
                  first: DateTime.utc(2020, 1, 1),
                  last: _endDate,
                  onSelected: (picked) => setState(() => _startDate = picked),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _dateField(
                label: 'End Date',
                date: _endDate,
                onTap: () => _pickDate(
                  initial: _endDate,
                  first: _startDate,
                  last: DateTime.now().toUtc().add(const Duration(days: 365)),
                  onSelected: (picked) => setState(() => _endDate = picked),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _fieldLabel('Output Format'),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final mode in ReportOutputMode.values) ...[
              Expanded(
                child: _outputModeChip(
                  key: ValueKey<String>('reports-output-mode-${mode.name}'),
                  label: mode.label,
                  selected: _outputMode == mode,
                  onTap: () => setReportOutputMode(mode),
                ),
              ),
              if (mode != ReportOutputMode.values.last)
                const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 8),
        _fieldLabel('Preview Surface'),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final surface in ReportPreviewSurface.values) ...[
              Expanded(
                child: _outputModeChip(
                  key: ValueKey<String>(
                    'reports-preview-surface-${surface.name}',
                  ),
                  label: surface.label,
                  selected: _previewSurface == surface,
                  onTap: () => setReportPreviewSurface(surface),
                ),
              ),
              if (surface != ReportPreviewSurface.values.last)
                const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildReceiptHistory() {
    final hasLiveReceipts = _receipts.isNotEmpty;
    final rows = hasLiveReceipts ? _receipts : _sampleReceipts;
    final filteredRows = _receiptHistoryMetrics(rows).filteredRows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              hasLiveReceipts ? 'Live Receipts' : 'Sample Receipts',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            _receiptFilterControl(
              value: _receiptFilter,
              onChanged: setReportReceiptFilter,
              rows: rows,
            ),
            const SizedBox(width: 8),
            _pillActionButton(
              label: 'Export All',
              icon: Icons.download_rounded,
              buttonKey: const ValueKey('reports-export-all-button'),
              onTap: () => _exportAllReceipts(filteredRows),
            ),
          ],
        ),
        if (_receiptFilter != ReportReceiptSceneFilter.all) ...[
          const SizedBox(height: 8),
          _activeReceiptFilterBanner(
            totalRows: rows.length,
            filteredRows: filteredRows.length,
            rows: rows,
            hasLiveReceipts: hasLiveReceipts,
          ),
        ],
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const OnyxEmptyState(label: 'No ReportGenerated receipts yet.')
        else if (filteredRows.isEmpty)
          const OnyxEmptyState(label: 'No receipts match the selected filter.')
        else
          for (var i = 0; i < filteredRows.length; i++) ...[
            _receiptCard(filteredRows[i], hasLiveReceipts: hasLiveReceipts),
            if (i < filteredRows.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _generationLane({
    required Color color,
    required IconData icon,
    required String title,
    required String detail,
    required String status,
    required String actionText,
    required VoidCallback? onTap,
    String? secondaryActionText,
    VoidCallback? onSecondaryTap,
    Key? secondaryButtonKey,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF10233A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.rajdhani(
                        color: const Color(0xFFE8F1FF),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      detail,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8EA4C2),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: 8),
          if (secondaryActionText == null)
            _pillActionButton(
              label: actionText,
              icon: Icons.play_arrow_rounded,
              onTap: onTap,
            )
          else
            Row(
              children: [
                Expanded(
                  child: _pillActionButton(
                    label: actionText,
                    icon: Icons.play_arrow_rounded,
                    onTap: onTap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _pillActionButton(
                    label: secondaryActionText,
                    icon: Icons.copy_all_rounded,
                    buttonKey: secondaryButtonKey,
                    onTap: onSecondaryTap,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _receiptCard(_ReceiptRow row, {required bool hasLiveReceipts}) {
    final statusLabel = row.replayVerified ? 'VERIFIED' : 'PENDING';
    final statusColor = row.replayVerified
        ? const Color(0xFF59D79B)
        : const Color(0xFFF6C067);

    final clientName = _humanizeClient(row.event.clientId);
    final siteName = _humanizeSite(row.event.siteId);
    final period = _periodFromMonth(row.event.month);
    final generatedAt = _formatUtc(row.event.occurredAt);
    final fileSize =
        '${(1.6 + (row.event.eventCount / 1400)).toStringAsFixed(1)} MB';
    final sceneReviewSummary = row.sceneReviewSummary;
    final sceneAccent = _sceneReviewAccent(sceneReviewSummary);
    final sceneNarrative = _sceneReviewNarrative(sceneReviewSummary);
    final isSelected = row.event.eventId == _selectedReceiptEventId;
    final hasTrackedSectionConfiguration = _hasTrackedSectionConfiguration(
      row.event,
    );
    final sectionSummary = _receiptSectionConfigurationSummary(row.event);
    final sectionColor = _receiptSectionConfigurationAccent(row.event);
    final omittedSections = _omittedSectionLabels(
      row.event.sectionConfiguration,
    );
    final brandingSummary = _receiptBrandingSummary(row.event);
    final brandingAccent = _receiptBrandingAccent(row.event);
    final brandingLabel = _receiptBrandingLabel(row.event);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF11243A) : const Color(0xFF10233A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF63BDFF)
              : sceneReviewSummary?.includedInReceipt == true
              ? sceneAccent.withValues(alpha: 0.5)
              : statusColor.withValues(alpha: 0.45),
          width: isSelected ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: GoogleFonts.rajdhani(
                        color: const Color(0xFFE8F1FF),
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      siteName,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8EA4C2),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ReportStatusBadge(
                label: statusLabel,
                textColor: statusColor,
                backgroundColor: statusColor.withValues(alpha: 0.18),
                borderColor: statusColor.withValues(alpha: 0.5),
                fontSize: 10,
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                const ReportStatusBadge(
                  label: 'FOCUSED',
                  textColor: Color(0xFF63BDFF),
                  backgroundColor: Color(0x1463BDFF),
                  borderColor: Color(0xFF63BDFF),
                  fontSize: 10,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _receiptMeta('Report ID', row.event.eventId),
              _receiptMeta('File Size', fileSize),
              _receiptMeta('Period', period),
              _receiptMeta('Events', '${row.event.eventCount}'),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            key: ValueKey<String>('report-receipt-config-${row.event.eventId}'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1A2B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sectionColor.withValues(alpha: 0.38)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report Configuration',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE8F1FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (row.event.brandingConfiguration.isConfigured)
                      _receiptSceneReviewPill(
                        row.event.brandingConfiguration.primaryLabel,
                        const Color(0xFF63BDFF),
                      ),
                    if (row.event.brandingConfiguration.isConfigured)
                      _receiptSceneReviewPill(brandingLabel, brandingAccent),
                    _receiptSceneReviewPill(
                      hasTrackedSectionConfiguration
                          ? 'Tracked Config'
                          : 'Legacy Config',
                      sectionColor,
                    ),
                    if (hasTrackedSectionConfiguration)
                      _receiptSceneReviewPill(
                        omittedSections.isEmpty
                            ? 'All Sections Included'
                            : '${omittedSections.length} Sections Omitted',
                        omittedSections.isEmpty
                            ? const Color(0xFF59D79B)
                            : const Color(0xFFF6C067),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  row.event.brandingConfiguration.isConfigured
                      ? '${row.event.brandingConfiguration.primaryLabel}${row.event.endorsementLine.trim().isNotEmpty ? ' • ${row.event.endorsementLine.trim()}' : ''}\n$brandingSummary\n$sectionSummary'
                      : sectionSummary,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9CB2D1),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (sceneReviewSummary != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ReportSceneReviewPillBuilder.build(
                summary: sceneReviewSummary,
                pillBuilder: _receiptSceneReviewPill,
                sceneIncludedColor: const Color(0xFF63BDFF),
                scenePendingColor: const Color(0xFF8EA4C2),
                postureColor: const Color(0xFF8EA4C2),
                includeModelCount: true,
                modelColor: const Color(0xFF59D79B),
                includeActionCounts: true,
                suppressedColor: const Color(0xFF8EA4C2),
                incidentAlertColor: const Color(0xFF63BDFF),
                repeatUpdateColor: const Color(0xFFF6C067),
                includeEscalationCount: true,
                escalationAlertColor: const Color(0xFFFF7A7A),
                escalationNeutralColor: const Color(0xFFF6C067),
                includeLatestAction: true,
                onLatestActionFilterTap: setReportReceiptFilter,
                onLatestActionActiveTap: () =>
                    _previewReceipt(row, hasLiveReceipts),
                activeLatestActionFilter: _receiptFilter,
                includePosture: true,
                uppercasePosture: true,
              ),
            ),
            if (sceneNarrative != null) ...[
              const SizedBox(height: 8),
              ReportSceneReviewNarrativeBox(
                narrative: sceneNarrative,
                accent: sceneAccent,
              ),
            ],
          ],
          const SizedBox(height: 8),
          Text(
            'Generated: $generatedAt',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _pillActionButton(
                  label: 'Preview',
                  icon: Icons.visibility_rounded,
                  buttonKey: ValueKey<String>(
                    'report-receipt-preview-${row.event.eventId}',
                  ),
                  onTap: () => _previewReceipt(row, hasLiveReceipts),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _pillActionButton(
                  label: 'Copy',
                  icon: Icons.copy_all_rounded,
                  buttonKey: ValueKey<String>(
                    'report-receipt-copy-${row.event.eventId}',
                  ),
                  onTap: () => _copyReceipt(row),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _pillActionButton(
                  label: 'Download',
                  icon: Icons.download_rounded,
                  buttonKey: ValueKey<String>(
                    'report-receipt-download-${row.event.eventId}',
                  ),
                  onTap: () => _downloadReceipt(row, hasLiveReceipts),
                  filled: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _receiptMeta(String label, String value) {
    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: GoogleFonts.inter(
              color: const Color(0xFFD9E7FA),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptSceneReviewPill(
    String label,
    Color color, {
    bool isActive = false,
  }) {
    return ReportMetaPill(
      label: label,
      color: color,
      isActive: isActive,
      fontSize: 10,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      backgroundOpacity: 0.14,
      borderOpacity: 0.42,
    );
  }

  Widget _receiptFilterControl({
    required ReportReceiptSceneFilter value,
    required ValueChanged<ReportReceiptSceneFilter> onChanged,
    required List<_ReceiptRow> rows,
  }) {
    final summaries = ReportReceiptHistoryPresenter.summariesOf<_ReceiptRow>(
      rows,
      (row) => row.sceneReviewSummary,
    );
    return ReportReceiptFilterControl(
      dropdownKey: const ValueKey('reports-receipt-filter'),
      value: value,
      onChanged: onChanged,
      summaries: summaries,
      onOpenFocusedReceipt: _activeFilterShortcutRow(rows) == null
          ? null
          : () => _previewReceipt(
              _activeFilterShortcutRow(rows)!,
              _receipts.isNotEmpty,
            ),
      iconEnabledColor: const Color(0xFF8EA4C2),
      textColor: const Color(0xFFE8F1FF),
    );
  }

  ReportReceiptHistoryMetrics<_ReceiptRow> _receiptHistoryMetrics(
    List<_ReceiptRow> rows,
  ) {
    return ReportReceiptHistoryPresenter.buildMetrics<_ReceiptRow>(
      rows: rows,
      filter: _receiptFilter,
      sceneSummaryOf: (row) => row.sceneReviewSummary,
    );
  }

  String? get _partnerScopeClientId {
    final value = _shellBinding.partnerScopeClientId?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  String? get _partnerScopeSiteId {
    final value = _shellBinding.partnerScopeSiteId?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  String? get _partnerScopePartnerLabel {
    final value = _shellBinding.partnerScopePartnerLabel?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  bool get _hasPartnerScopeFocus =>
      _partnerScopeClientId != null &&
      _partnerScopeSiteId != null &&
      _partnerScopePartnerLabel != null;

  String? get _brandingPrimaryLabelOverride {
    final value = _shellBinding.brandingPrimaryLabelOverride?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  String? get _brandingEndorsementLineOverride =>
      _shellBinding.brandingEndorsementLineOverride;

  bool get _hasBrandingOverride =>
      _brandingPrimaryLabelOverride != null ||
      _brandingEndorsementLineOverride != null;

  List<SovereignReportPartnerScoreboardRow> get _sitePartnerScoreboardRows {
    final reports = [...widget.morningSovereignReportHistory]
      ..sort((a, b) {
        final generatedCompare = b.generatedAtUtc.compareTo(a.generatedAtUtc);
        if (generatedCompare != 0) {
          return generatedCompare;
        }
        return b.date.compareTo(a.date);
      });
    if (reports.isEmpty) {
      return const <SovereignReportPartnerScoreboardRow>[];
    }
    return reports.first.partnerProgression.scoreboardRows
        .where(
          (row) =>
              row.clientId.trim() == widget.selectedClient &&
              row.siteId.trim() == widget.selectedSite,
        )
        .toList(growable: false);
  }

  String get _pageSubtitle {
    final scopeLabel = _hasPartnerScopeFocus
        ? '${widget.selectedClient} • ${widget.selectedSite} • ${_partnerScopePartnerLabel!}'
        : '${widget.selectedClient} • ${widget.selectedSite}';
    return ReportReceiptHistoryCopy.pageSubtitle(
      scopeLabel: scopeLabel,
      filter: _receiptFilter,
    );
  }

  void _syncFocusedPartnerScopeFromWidget({bool deferEmit = false}) {
    final clientId = widget.initialPartnerScopeClientId?.trim() ?? '';
    final siteId = widget.initialPartnerScopeSiteId?.trim() ?? '';
    final partnerLabel = widget.initialPartnerScopePartnerLabel?.trim() ?? '';
    if (clientId.isEmpty && siteId.isEmpty && partnerLabel.isEmpty) {
      return;
    }
    final nextBinding =
        clientId.isNotEmpty && siteId.isNotEmpty && partnerLabel.isNotEmpty
        ? _shellBinding.withPartnerScopeFocus(
            clientId: clientId,
            siteId: siteId,
            partnerLabel: partnerLabel,
          )
        : _shellBinding.clearingPartnerScopeFocus();
    if (nextBinding == _shellBinding) {
      return;
    }
    _shellBinding = nextBinding;
    if (deferEmit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _shellBinding != nextBinding) {
          return;
        }
        emitProjectedReportShellState(nextBinding);
      });
      return;
    }
    setState(() => _shellBinding = nextBinding);
    emitProjectedReportShellState(nextBinding);
  }

  void _setPartnerScopeFocus({
    required String clientId,
    required String siteId,
    required String partnerLabel,
  }) {
    setReportPartnerScopeFocus(
      clientId: clientId.trim(),
      siteId: siteId.trim(),
      partnerLabel: partnerLabel.trim(),
    );
    _showReceiptActionFeedback('Focused Reports on $siteId • $partnerLabel.');
  }

  void _clearPartnerScopeFocus() {
    if (!_hasPartnerScopeFocus) {
      return;
    }
    clearReportPartnerScopeFocus();
    _showReceiptActionFeedback('Partner scorecard focus cleared.');
  }

  Future<void> _editBrandingOverrides() async {
    if (!_hasPartnerScopeFocus) {
      return;
    }
    final defaults = _defaultBrandingConfiguration;
    var draftPrimary = _currentBrandingConfiguration.primaryLabel;
    var draftEndorsement = _currentBrandingConfiguration.endorsementLine;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF08111F),
          title: Text(
            'Edit Client Branding',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE8F1FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Default partner branding uses ${defaults.primaryLabel} with ${defaults.endorsementLine}.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9CB2D1),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('reports-branding-primary-field'),
                  initialValue: draftPrimary,
                  onChanged: (value) => draftPrimary = value,
                  decoration: const InputDecoration(
                    labelText: 'Primary client-facing label',
                    hintText: 'VISION Tactical',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('reports-branding-endorsement-field'),
                  initialValue: draftEndorsement,
                  onChanged: (value) => draftEndorsement = value,
                  decoration: const InputDecoration(
                    labelText: 'Endorsement line',
                    hintText: 'Powered by ONYX',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('reports-branding-save-button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (saved != true) {
      return;
    }
    final nextPrimary = draftPrimary.trim();
    final nextEndorsement = draftEndorsement.trim();

    final primaryOverride =
        nextPrimary.isEmpty || nextPrimary == defaults.primaryLabel
        ? null
        : nextPrimary;
    final endorsementOverride = nextEndorsement == defaults.endorsementLine
        ? null
        : nextEndorsement;
    setReportBrandingOverrides(
      primaryLabelOverride: primaryOverride,
      clearPrimaryLabelOverride: primaryOverride == null,
      endorsementLineOverride: endorsementOverride,
      clearEndorsementLineOverride: endorsementOverride == null,
    );
    _showReceiptActionFeedback(
      primaryOverride == null && endorsementOverride == null
          ? 'Partner branding reset to defaults.'
          : 'Client-facing report branding updated.',
    );
  }

  void _resetBrandingOverrides() {
    if (!_hasBrandingOverride) {
      return;
    }
    setReportBrandingOverrides(
      clearPrimaryLabelOverride: true,
      clearEndorsementLineOverride: true,
    );
    _showReceiptActionFeedback('Partner branding reset to defaults.');
  }

  String get _receiptHistorySubtitle {
    return ReportReceiptHistoryCopy.historySubtitle(
      base:
          'Open generated receipts to regenerate reports and confirm replay integrity.',
      filter: _receiptFilter,
    );
  }

  Widget _activeReceiptFilterBanner({
    required int totalRows,
    required int filteredRows,
    required List<_ReceiptRow> rows,
    required bool hasLiveReceipts,
  }) {
    final openRow = _activeFilterShortcutRow(rows);
    return ReportReceiptFilterBanner(
      filter: _receiptFilter,
      filteredRows: filteredRows,
      totalRows: totalRows,
      onOpenFocusedReceipt: openRow == null
          ? null
          : () => _previewReceipt(openRow, hasLiveReceipts),
      onCopyFocusedReceipt: openRow == null
          ? null
          : () => _copyReceipt(openRow),
      onShowAll: () => setReportReceiptFilter(ReportReceiptSceneFilter.all),
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

  ReportReceiptSceneFilter get _receiptFilter => _shellBinding.receiptFilter;

  ReportOutputMode get _outputMode => _shellBinding.outputMode;

  ReportPartnerComparisonWindow get _partnerComparisonWindow =>
      _shellBinding.partnerComparisonWindow;

  String? get _selectedReceiptEventId => _shellBinding.selectedReceiptEventId;

  String? get _previewReceiptEventId => _shellBinding.previewReceiptEventId;

  ReportEntryContext? get _entryContext => _shellBinding.entryContext;

  ReportPreviewSurface get _previewSurface => _shellBinding.previewSurface;

  ReportEntryContext? _storedEntryContextForReceipt(ReportGenerated event) {
    return ReportEntryContext.fromStorageValue(event.investigationContextKey);
  }

  ReportEntryContext? _effectiveEntryContextForReceipt(ReportGenerated event) {
    return _entryContext ?? _storedEntryContextForReceipt(event);
  }

  ReportEntryContext? _activeReceiptPolicyEntryContext(List<_ReceiptRow> rows) {
    if (_entryContext != null) {
      return _entryContext;
    }
    final previewTarget = _targetReceiptByEventId(rows, _previewReceiptEventId);
    if (previewTarget != null) {
      return _storedEntryContextForReceipt(previewTarget.event);
    }
    if (rows.isEmpty) {
      return null;
    }
    return _storedEntryContextForReceipt(rows.first.event);
  }

  ReportSectionConfiguration get _currentSectionConfiguration =>
      ReportSectionConfiguration(
        includeTimeline: _includeTimeline,
        includeDispatchSummary: _includeDispatchSummary,
        includeCheckpointCompliance: _includeCheckpointCompliance,
        includeAiDecisionLog: _includeAiDecisionLog,
        includeGuardMetrics: _includeGuardMetrics,
      );

  ReportBrandingConfiguration get _defaultBrandingConfiguration =>
      _hasPartnerScopeFocus
      ? ReportBrandingConfiguration(
          primaryLabel: _partnerScopePartnerLabel!,
          endorsementLine: 'Powered by ONYX',
          sourceLabel: _partnerScopePartnerLabel!,
        )
      : const ReportBrandingConfiguration();

  ReportBrandingConfiguration get _currentBrandingConfiguration {
    final defaults = _defaultBrandingConfiguration;
    if (!defaults.isConfigured) {
      return defaults;
    }
    return ReportBrandingConfiguration(
      primaryLabel: _brandingPrimaryLabelOverride ?? defaults.primaryLabel,
      endorsementLine:
          _brandingEndorsementLineOverride ?? defaults.endorsementLine,
      sourceLabel: defaults.sourceLabel,
      usesOverride: _hasBrandingOverride,
    );
  }

  bool get _includeTimeline => _shellBinding.includeTimeline;

  bool get _includeDispatchSummary => _shellBinding.includeDispatchSummary;

  bool get _includeCheckpointCompliance =>
      _shellBinding.includeCheckpointCompliance;

  bool get _includeAiDecisionLog => _shellBinding.includeAiDecisionLog;

  bool get _includeGuardMetrics => _shellBinding.includeGuardMetrics;

  _ReceiptRow? _focusedVisibleReceipt(List<_ReceiptRow> rows) {
    return ReportReceiptHistoryLookup.findByEventId<_ReceiptRow>(
      rows,
      _selectedReceiptEventId,
      (row) => row.event.eventId,
    );
  }

  _ReceiptRow? _targetReceiptByEventId(
    List<_ReceiptRow> rows,
    String? eventId,
  ) {
    return ReportReceiptHistoryLookup.findByEventId<_ReceiptRow>(
      rows,
      eventId,
      (row) => row.event.eventId,
    );
  }

  _ReceiptRow? _activeFilterShortcutRow(List<_ReceiptRow> rows) {
    if (!_receiptFilter.isLatestActionFilter) {
      return null;
    }
    final filteredRows = _receiptHistoryMetrics(rows).filteredRows;
    final previewTarget = _targetReceiptByEventId(
      filteredRows,
      _previewReceiptEventId,
    );
    if (previewTarget != null) {
      return previewTarget;
    }
    final focused = _focusedVisibleReceipt(filteredRows);
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
    required _ReceiptRow? row,
    required bool hasLiveReceipts,
  }) {
    return ReportPreviewTargetBanner(
      eventId: eventId,
      previewSurface: _previewSurface,
      surfaceLabelColor: const Color(0xFF8EA4C2),
      onOpen: row == null ? null : () => _previewReceipt(row, hasLiveReceipts),
      onCopy: row == null ? null : () => _copyReceipt(row),
      onClear: clearReportPreviewTarget,
      openButtonKey: const ValueKey('reports-preview-target-open'),
      copyButtonKey: const ValueKey('reports-preview-target-copy'),
      clearButtonKey: const ValueKey('reports-preview-target-clear'),
    );
  }

  Widget _previewDock({
    required _ReceiptRow row,
    required bool hasLiveReceipts,
  }) {
    final sceneSummary = row.sceneReviewSummary;
    final sceneAccent = _sceneReviewAccent(sceneSummary);
    final siteName = _humanizeSite(row.event.siteId);
    final period = _periodFromMonth(row.event.month);

    return ReportPreviewDockCard(
      eventId: row.event.eventId,
      detail: '$siteName • $period',
      contextTitle: _entryContext?.bannerTitle,
      contextDetail: _entryContext?.bannerDetail,
      statusPills: [
        _receiptSceneReviewPill(
          row.replayVerified ? 'Replay Verified' : 'Replay Pending',
          row.replayVerified
              ? const Color(0xFF59D79B)
              : const Color(0xFFF6C067),
        ),
        if (sceneSummary != null)
          _receiptSceneReviewPill(
            sceneSummary.includedInReceipt
                ? 'Scene ${sceneSummary.totalReviews}'
                : 'Scene Pending',
            sceneSummary.includedInReceipt
                ? sceneAccent
                : const Color(0xFF8EA4C2),
          ),
        _receiptSceneReviewPill(
          _receiptSectionConfigurationDockLabel(row.event),
          _receiptSectionConfigurationAccent(row.event),
        ),
      ],
      primaryAction: _pillActionButton(
        label: 'Open Full Preview',
        icon: Icons.open_in_new_rounded,
        buttonKey: const ValueKey('reports-preview-dock-open'),
        onTap: () => _previewReceipt(row, hasLiveReceipts),
      ),
      secondaryAction: _pillActionButton(
        label: 'Copy Receipt',
        icon: Icons.copy_all_rounded,
        buttonKey: const ValueKey('reports-preview-dock-copy'),
        onTap: () => _copyReceipt(row),
      ),
      tertiaryAction: _pillActionButton(
        label: 'Clear Dock Target',
        icon: Icons.close_rounded,
        buttonKey: const ValueKey('reports-preview-dock-clear'),
        onTap: clearReportPreviewTarget,
      ),
    );
  }

  Color _sceneReviewAccent(ReportReceiptSceneReviewSummary? summary) {
    return ReportReceiptSceneReviewPresenter.accent(
      summary,
      neutralColor: const Color(0xFF8EA4C2),
      reviewedColor: const Color(0xFF63BDFF),
      escalationColor: const Color(0xFFFF7A7A),
    );
  }

  String? _sceneReviewNarrative(ReportReceiptSceneReviewSummary? summary) {
    return ReportReceiptSceneReviewPresenter.narrative(summary);
  }

  bool _hasTrackedSectionConfiguration(ReportGenerated event) {
    return event.reportSchemaVersion >= 3;
  }

  List<String> _includedSectionLabels(
    ReportSectionConfiguration configuration,
  ) {
    return <String>[
      if (configuration.includeTimeline) 'Incident Timeline',
      if (configuration.includeDispatchSummary) 'Dispatch Summary',
      if (configuration.includeCheckpointCompliance) 'Checkpoint Compliance',
      if (configuration.includeAiDecisionLog) 'AI Decision Log',
      if (configuration.includeGuardMetrics) 'Guard Metrics',
    ];
  }

  List<String> _omittedSectionLabels(ReportSectionConfiguration configuration) {
    return <String>[
      if (!configuration.includeTimeline) 'Incident Timeline',
      if (!configuration.includeDispatchSummary) 'Dispatch Summary',
      if (!configuration.includeCheckpointCompliance) 'Checkpoint Compliance',
      if (!configuration.includeAiDecisionLog) 'AI Decision Log',
      if (!configuration.includeGuardMetrics) 'Guard Metrics',
    ];
  }

  String _receiptSectionConfigurationSummary(ReportGenerated event) {
    if (!_hasTrackedSectionConfiguration(event)) {
      return 'Legacy receipt. Per-section report configuration was not captured for this generation.';
    }
    final included = _includedSectionLabels(event.sectionConfiguration);
    final omitted = _omittedSectionLabels(event.sectionConfiguration);
    final includedLabel = included.isEmpty ? 'None' : included.join(', ');
    final omittedLabel = omitted.isEmpty ? 'None' : omitted.join(', ');
    return 'Included: $includedLabel. Omitted: $omittedLabel.';
  }

  String _receiptSectionConfigurationDockLabel(ReportGenerated event) {
    if (!_hasTrackedSectionConfiguration(event)) {
      return 'Legacy Config';
    }
    final omitted = _omittedSectionLabels(event.sectionConfiguration);
    if (omitted.isEmpty) {
      return 'All Sections Included';
    }
    return '${omitted.length} Sections Omitted';
  }

  Color _receiptSectionConfigurationAccent(ReportGenerated event) {
    if (!_hasTrackedSectionConfiguration(event)) {
      return const Color(0xFF8EA4C2);
    }
    return _omittedSectionLabels(event.sectionConfiguration).isEmpty
        ? const Color(0xFF59D79B)
        : const Color(0xFFF6C067);
  }

  String _receiptBrandingLabel(ReportGenerated event) {
    if (!event.brandingConfiguration.isConfigured) {
      return 'ONYX Standard';
    }
    return event.brandingUsesOverride ? 'Custom Branding' : 'Default Branding';
  }

  String _receiptBrandingSummary(ReportGenerated event) {
    if (!event.brandingConfiguration.isConfigured) {
      return 'Branding: standard ONYX identity.';
    }
    final source = event.brandingConfiguration.sourceLabel.trim();
    if (event.brandingUsesOverride) {
      return source.isNotEmpty
          ? 'Branding: custom override from default partner lane $source.'
          : 'Branding: custom override was used for this receipt.';
    }
    return source.isNotEmpty
        ? 'Branding: default partner lane $source.'
        : 'Branding: configured partner label was used.';
  }

  Color _receiptBrandingAccent(ReportGenerated event) {
    if (!event.brandingConfiguration.isConfigured) {
      return const Color(0xFF8EA4C2);
    }
    return event.brandingUsesOverride
        ? const Color(0xFFF6C067)
        : const Color(0xFF59D79B);
  }

  Widget _fieldLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.inter(
        color: const Color(0xFF8EA4C2),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _dropdownField({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: ValueKey<String>(value),
      initialValue: value,
      onChanged: onChanged,
      iconEnabledColor: const Color(0xFF8EA4C2),
      dropdownColor: const Color(0xFF0E1A2B),
      style: GoogleFonts.inter(
        color: const Color(0xFFE8F1FF),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFF0A0E14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF223244)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3C79BB)),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF223244)),
            ),
            child: Text(
              _formatDate(date),
              style: GoogleFonts.inter(
                color: const Color(0xFFE8F1FF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _outputModeChip({
    Key? key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0x2230C8FF) : const Color(0xFF0A0E14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF3FA7D6) : const Color(0xFF223244),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: selected
                  ? const Color(0xFF63BDFF)
                  : const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: (next) => onChanged(next ?? false),
      dense: true,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      activeColor: const Color(0xFF3FA7D6),
      checkColor: const Color(0xFF040A16),
      title: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(0xFFD9E7FA),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statusChip(String label) {
    Color color;
    switch (label) {
      case 'VERIFIED':
      case 'READY':
        color = const Color(0xFF59D79B);
        break;
      case 'RUNNING':
        color = const Color(0xFF63BDFF);
        break;
      case 'PENDING':
        color = const Color(0xFFF6C067);
        break;
      default:
        color = const Color(0xFF8EA4C2);
    }
    return ReportStatusBadge(
      label: label,
      textColor: color,
      backgroundColor: color.withValues(alpha: 0.16),
      borderColor: color.withValues(alpha: 0.45),
      fontSize: 10,
    );
  }

  Widget _pillActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    Key? buttonKey,
    bool filled = false,
  }) {
    return TextButton.icon(
      key: buttonKey,
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        backgroundColor: filled
            ? const Color(0xFF2A5D95)
            : const Color(0xFF132947),
        foregroundColor: const Color(0xFFE8F1FF),
        disabledBackgroundColor: const Color(0xFF101A28),
        disabledForegroundColor: const Color(0xFF5E738F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: Color(0xFF2A4768)),
        ),
      ),
      icon: Icon(icon, size: 15),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  void _exportAllReceipts(List<_ReceiptRow> rows) {
    if (rows.isEmpty) {
      logUiAction('reports.export_all', context: {'rows': 0});
      _showReceiptActionFeedback('No receipts available to export.');
      return;
    }
    final focusedReceipt = _activeFilterShortcutRow(rows);
    final payload = ReportReceiptExportPayload.build(
      entries: rows.map(
        (row) => ReportReceiptExportEntry(
          receiptEvent: row.event,
          replayVerified: row.replayVerified,
          sceneReviewSummary: row.sceneReviewSummary,
        ),
      ),
      filter: _receiptFilter,
      selectedReceiptEventId: _selectedReceiptEventId,
      previewReceiptEventId: _previewReceiptEventId,
      activeSectionConfiguration: _currentSectionConfiguration.toJson(),
      entryContext: _entryContext,
      focusedReceipt: focusedReceipt == null
          ? null
          : ReportReceiptExportEntry(
              receiptEvent: focusedReceipt.event,
              replayVerified: focusedReceipt.replayVerified,
              sceneReviewSummary: focusedReceipt.sceneReviewSummary,
            ),
    );
    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    Clipboard.setData(ClipboardData(text: encoded));
    logUiAction('reports.export_all', context: {'rows': rows.length});
    _showReceiptActionFeedback(
      'Exported ${rows.length} receipt records to clipboard.',
    );
  }

  void _copyPartnerScopeJson() {
    final payload = _partnerScopeExportPayload();
    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    Clipboard.setData(ClipboardData(text: encoded));
    logUiAction(
      'reports.copy_partner_scorecard_json',
      context: <String, Object?>{
        'client_id': _partnerScopeClientId,
        'site_id': _partnerScopeSiteId,
        'partner_label': _partnerScopePartnerLabel,
      },
    );
    _showReceiptActionFeedback('Partner scorecard JSON copied.');
  }

  void _copyPartnerScopeCsv() {
    final encoded = _partnerScopeExportCsv();
    Clipboard.setData(ClipboardData(text: encoded));
    logUiAction(
      'reports.copy_partner_scorecard_csv',
      context: <String, Object?>{
        'client_id': _partnerScopeClientId,
        'site_id': _partnerScopeSiteId,
        'partner_label': _partnerScopePartnerLabel,
      },
    );
    _showReceiptActionFeedback('Partner scorecard CSV copied.');
  }

  void _copyPartnerDrillInJson({
    required String clientId,
    required String siteId,
    required String partnerLabel,
  }) {
    final payload = _partnerScopeExportPayloadFor(
      clientId: clientId,
      siteId: siteId,
      partnerLabel: partnerLabel,
    );
    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    Clipboard.setData(ClipboardData(text: encoded));
    logUiAction(
      'reports.copy_partner_drill_in_json',
      context: <String, Object?>{
        'client_id': clientId,
        'site_id': siteId,
        'partner_label': partnerLabel,
      },
    );
    _showReceiptActionFeedback('Partner drill-in JSON copied.');
  }

  void _copyPartnerDrillInCsv({
    required String clientId,
    required String siteId,
    required String partnerLabel,
  }) {
    final encoded = _partnerScopeExportCsvFor(
      clientId: clientId,
      siteId: siteId,
      partnerLabel: partnerLabel,
    );
    Clipboard.setData(ClipboardData(text: encoded));
    logUiAction(
      'reports.copy_partner_drill_in_csv',
      context: <String, Object?>{
        'client_id': clientId,
        'site_id': siteId,
        'partner_label': partnerLabel,
      },
    );
    _showReceiptActionFeedback('Partner drill-in CSV copied.');
  }

  void _copyPartnerComparisonJson() {
    final payload = _partnerComparisonExportPayload();
    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    Clipboard.setData(ClipboardData(text: encoded));
    logUiAction(
      'reports.copy_partner_comparison_json',
      context: <String, Object?>{
        'client_id': widget.selectedClient,
        'site_id': widget.selectedSite,
        'rows': _sitePartnerComparisonRows.length,
      },
    );
    _showReceiptActionFeedback('Partner comparison JSON copied.');
  }

  void _copyPartnerComparisonCsv() {
    final encoded = _partnerComparisonExportCsv();
    Clipboard.setData(ClipboardData(text: encoded));
    logUiAction(
      'reports.copy_partner_comparison_csv',
      context: <String, Object?>{
        'client_id': widget.selectedClient,
        'site_id': widget.selectedSite,
        'rows': _sitePartnerComparisonRows.length,
      },
    );
    _showReceiptActionFeedback('Partner comparison CSV copied.');
  }

  void _copyReceiptPolicyHistoryJson(List<_ReceiptRow> rows) {
    final payload = _receiptPolicyHistoryExportPayload(rows);
    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    Clipboard.setData(ClipboardData(text: encoded));
    logUiAction(
      'reports.copy_receipt_policy_json',
      context: <String, Object?>{
        'client_id': widget.selectedClient,
        'site_id': widget.selectedSite,
        'rows': rows.length,
      },
    );
    _showReceiptActionFeedback('Receipt policy JSON copied.');
  }

  void _copyReceiptPolicyHistoryCsv(List<_ReceiptRow> rows) {
    final encoded = _receiptPolicyHistoryExportCsv(rows);
    Clipboard.setData(ClipboardData(text: encoded));
    logUiAction(
      'reports.copy_receipt_policy_csv',
      context: <String, Object?>{
        'client_id': widget.selectedClient,
        'site_id': widget.selectedSite,
        'rows': rows.length,
      },
    );
    _showReceiptActionFeedback('Receipt policy CSV copied.');
  }

  void _copyPartnerShiftJson(_PartnerScopeHistoryPoint point) {
    final payload = _partnerShiftExportPayload(point);
    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    Clipboard.setData(ClipboardData(text: encoded));
    logUiAction(
      'reports.copy_partner_shift_json',
      context: <String, Object?>{
        'client_id': point.row.clientId,
        'site_id': point.row.siteId,
        'partner_label': point.row.partnerLabel,
        'report_date': point.reportDate,
      },
    );
    _showReceiptActionFeedback('Partner shift JSON copied.');
  }

  void _copyPartnerShiftCsv(_PartnerScopeHistoryPoint point) {
    final encoded = _partnerShiftExportCsv(point);
    Clipboard.setData(ClipboardData(text: encoded));
    logUiAction(
      'reports.copy_partner_shift_csv',
      context: <String, Object?>{
        'client_id': point.row.clientId,
        'site_id': point.row.siteId,
        'partner_label': point.row.partnerLabel,
        'report_date': point.reportDate,
      },
    );
    _showReceiptActionFeedback('Partner shift CSV copied.');
  }

  Map<String, Object?> _partnerScopeExportPayload() {
    final clientId = _partnerScopeClientId;
    final siteId = _partnerScopeSiteId;
    final partnerLabel = _partnerScopePartnerLabel;
    if (clientId == null || siteId == null || partnerLabel == null) {
      return const <String, Object?>{
        'scope': <String, Object?>{},
        'historyRows': <Object?>[],
        'dispatchChains': <Object?>[],
      };
    }
    return _partnerScopeExportPayloadFor(
      clientId: clientId,
      siteId: siteId,
      partnerLabel: partnerLabel,
    );
  }

  Map<String, Object?> _partnerScopeExportPayloadFor({
    required String clientId,
    required String siteId,
    required String partnerLabel,
  }) {
    final historyPoints = _partnerScopeHistoryPointsFor(
      clientId: clientId,
      siteId: siteId,
      partnerLabel: partnerLabel,
    );
    final receiptRows = _partnerReceiptRowsForScope(
      clientId: clientId,
      siteId: siteId,
    );
    final receiptInvestigationComparison =
        _receiptInvestigationComparison(receiptRows);
    _PartnerScopeHistoryPoint? currentPoint;
    for (final point in historyPoints) {
      if (point.current) {
        currentPoint = point;
        break;
      }
    }
    currentPoint ??= historyPoints.isEmpty ? null : historyPoints.first;
    final chains = _partnerDispatchChainsForScope(
      clientId: clientId,
      siteId: siteId,
      partnerLabel: partnerLabel,
    );
    return <String, Object?>{
      'scope': <String, Object?>{
        'clientId': clientId,
        'siteId': siteId,
        'partnerLabel': partnerLabel,
      },
      'trendLabel': _partnerScopeTrendLabel(historyPoints),
      'trendReason': _partnerScopeTrendReason(historyPoints),
      if (receiptRows.isNotEmpty)
        'receiptInvestigation': <String, Object?>{
          'trendLabel': _receiptInvestigationTrendLabel(receiptRows),
          'trendReason': _receiptInvestigationTrendReason(receiptRows),
          'currentGovernanceHandoffCount':
              receiptInvestigationComparison.currentGovernanceCount,
          'currentRoutineReviewCount':
              receiptInvestigationComparison.currentRoutineCount,
          'baselineGovernanceAverage':
              receiptInvestigationComparison.baselineGovernanceAverage,
          'baselineRoutineAverage':
              receiptInvestigationComparison.baselineRoutineAverage,
          'baselineReceiptCount':
              receiptInvestigationComparison.baselineReceiptCount,
        },
      'currentRow': currentPoint?.toJson(),
      'historyRows': historyPoints
          .map((point) => point.toJson())
          .toList(growable: false),
      'dispatchChains': chains
          .map((chain) => chain.toJson())
          .toList(growable: false),
    };
  }

  Map<String, Object?> _partnerShiftExportPayload(
    _PartnerScopeHistoryPoint point,
  ) {
    final receiptRows = _partnerReceiptRowsForScopeDate(
      clientId: point.row.clientId,
      siteId: point.row.siteId,
      reportDate: point.reportDate,
    );
    final chains = _partnerDispatchChainsForScopeDate(
      clientId: point.row.clientId,
      siteId: point.row.siteId,
      partnerLabel: point.row.partnerLabel,
      reportDate: point.reportDate,
    );
    final eventIds = _partnerShiftEventIdsForScopeDate(
      clientId: point.row.clientId,
      siteId: point.row.siteId,
      partnerLabel: point.row.partnerLabel,
      reportDate: point.reportDate,
    );
    return <String, Object?>{
      'scope': <String, Object?>{
        'clientId': point.row.clientId,
        'siteId': point.row.siteId,
        'partnerLabel': point.row.partnerLabel,
      },
      'reportDate': point.reportDate,
      'current': point.current,
      'primaryLabel': _partnerScoreboardPrimaryLabel(point.row),
      'summaryLine': point.row.summaryLine,
      'scoreboardRow': point.row.toJson(),
      if (point.receiptInvestigationSummary != null)
        'receiptInvestigation': point.receiptInvestigationSummary!.toJson(),
      'receipts': receiptRows
          .map(
            (row) => <String, Object?>{
              'eventId': row.event.eventId,
              'occurredAtUtc': row.event.occurredAt.toIso8601String(),
              'stateLabel': _receiptPolicyStateChipLabel(row.event),
              'brandingLabel': _receiptPolicyBrandingChipLabel(row.event),
              'investigationContextKey': row.event.investigationContextKey,
              'headline': _receiptPolicyHistoryHeadline(row.event),
              'detail': _receiptPolicyHistoryDetail(row.event),
              'eventCount': row.event.eventCount,
            },
          )
          .toList(growable: false),
      'dispatchChains': chains.map((chain) => chain.toJson()).toList(
        growable: false,
      ),
      'eventIds': eventIds,
    };
  }

  List<_ReceiptRow> _partnerScopeReceiptRows() {
    final clientId = _partnerScopeClientId;
    final siteId = _partnerScopeSiteId;
    if (clientId == null || siteId == null) {
      return const [];
    }
    return _partnerReceiptRowsForScope(clientId: clientId, siteId: siteId);
  }

  List<_ReceiptRow> _partnerReceiptRowsForScope({
    required String clientId,
    required String siteId,
  }) {
    final rows = _receipts.isNotEmpty ? _receipts : _sampleReceipts;
    return rows
        .where(
          (row) =>
              row.event.clientId.trim() == clientId &&
              row.event.siteId.trim() == siteId,
        )
        .toList(growable: false);
  }

  List<_ReceiptRow> _partnerReceiptRowsForScopeDate({
    required String clientId,
    required String siteId,
    required String reportDate,
  }) {
    final rows = _receipts.isNotEmpty ? _receipts : _sampleReceipts;
    return rows
        .where(
          (row) =>
              row.event.clientId.trim() == clientId &&
              row.event.siteId.trim() == siteId &&
              _formatDate(row.event.occurredAt.toUtc()) == reportDate,
        )
        .toList(growable: false);
  }

  List<SovereignReportPartnerDispatchChain> _partnerDispatchChainsForScopeDate({
    required String clientId,
    required String siteId,
    required String partnerLabel,
    required String reportDate,
  }) {
    final reports = [...widget.morningSovereignReportHistory]
      ..sort((a, b) {
        final generatedCompare = b.generatedAtUtc.compareTo(a.generatedAtUtc);
        if (generatedCompare != 0) {
          return generatedCompare;
        }
        return b.date.compareTo(a.date);
      });
    if (reports.isEmpty) {
      return const <SovereignReportPartnerDispatchChain>[];
    }
    return reports.first.partnerProgression.dispatchChains
        .where(
          (chain) => _partnerDispatchChainMatchesScopeValues(
            chain,
            clientId: clientId,
            siteId: siteId,
            partnerLabel: partnerLabel,
          ),
        )
        .where((chain) {
          final milestoneDates = <String>{
            _formatDate(chain.latestOccurredAtUtc.toUtc()),
            if (chain.dispatchCreatedAtUtc != null)
              _formatDate(chain.dispatchCreatedAtUtc!.toUtc()),
            if (chain.acceptedAtUtc != null)
              _formatDate(chain.acceptedAtUtc!.toUtc()),
            if (chain.onSiteAtUtc != null)
              _formatDate(chain.onSiteAtUtc!.toUtc()),
            if (chain.allClearAtUtc != null)
              _formatDate(chain.allClearAtUtc!.toUtc()),
            if (chain.cancelledAtUtc != null)
              _formatDate(chain.cancelledAtUtc!.toUtc()),
          };
          return milestoneDates.contains(reportDate);
        })
        .toList(growable: false);
  }

  List<String> _partnerShiftEventIdsForScopeDate({
    required String clientId,
    required String siteId,
    required String partnerLabel,
    required String reportDate,
  }) {
    final eventEntries = <({String id, DateTime occurredAt})>[];
    final seenIds = <String>{};

    for (final row in _partnerReceiptRowsForScopeDate(
      clientId: clientId,
      siteId: siteId,
      reportDate: reportDate,
    )) {
      final eventId = row.event.eventId.trim();
      if (eventId.isEmpty || !seenIds.add(eventId)) {
        continue;
      }
      eventEntries.add((id: eventId, occurredAt: row.event.occurredAt.toUtc()));
    }

    for (final chain in _partnerDispatchChainsForScopeDate(
      clientId: clientId,
      siteId: siteId,
      partnerLabel: partnerLabel,
      reportDate: reportDate,
    )) {
      for (final event in _partnerDispatchChainEvents(chain)) {
        final eventId = event.eventId.trim();
        if (eventId.isEmpty || !seenIds.add(eventId)) {
          continue;
        }
        eventEntries.add((id: eventId, occurredAt: event.occurredAt.toUtc()));
      }
    }

    eventEntries.sort((a, b) {
      final occurredCompare = a.occurredAt.compareTo(b.occurredAt);
      if (occurredCompare != 0) {
        return occurredCompare;
      }
      return a.id.compareTo(b.id);
    });

    return eventEntries.map((entry) => entry.id).toList(growable: false);
  }

  void _openEventsForPartnerShift(_PartnerScopeHistoryPoint point) {
    final eventIds = _partnerShiftEventIdsForScopeDate(
      clientId: point.row.clientId,
      siteId: point.row.siteId,
      partnerLabel: point.row.partnerLabel,
      reportDate: point.reportDate,
    );
    if (widget.onOpenEventsForScope == null || eventIds.isEmpty) {
      return;
    }
    widget.onOpenEventsForScope!(eventIds, eventIds.last);
    _showReceiptActionFeedback(
      'Opening Events Review for ${point.reportDate} • ${point.row.partnerLabel}.',
    );
  }

  String _partnerShiftExportCsv(_PartnerScopeHistoryPoint point) {
    final receiptRows = _partnerReceiptRowsForScopeDate(
      clientId: point.row.clientId,
      siteId: point.row.siteId,
      reportDate: point.reportDate,
    );
    final chains = _partnerDispatchChainsForScopeDate(
      clientId: point.row.clientId,
      siteId: point.row.siteId,
      partnerLabel: point.row.partnerLabel,
      reportDate: point.reportDate,
    );
    final eventIds = _partnerShiftEventIdsForScopeDate(
      clientId: point.row.clientId,
      siteId: point.row.siteId,
      partnerLabel: point.row.partnerLabel,
      reportDate: point.reportDate,
    );
    final lines = <String>[
      'metric,value',
      'client_id,${point.row.clientId}',
      'site_id,${point.row.siteId}',
      'partner_label,"${point.row.partnerLabel.replaceAll('"', '""')}"',
      'report_date,${point.reportDate}',
      'current_shift,${point.current}',
      'primary_label,${_partnerScoreboardPrimaryLabel(point.row)}',
      'summary_line,"${point.row.summaryLine.replaceAll('"', '""')}"',
      'dispatch_count,${point.row.dispatchCount}',
      'strong_count,${point.row.strongCount}',
      'on_track_count,${point.row.onTrackCount}',
      'watch_count,${point.row.watchCount}',
      'critical_count,${point.row.criticalCount}',
      'average_accepted_delay_minutes,${point.row.averageAcceptedDelayMinutes.toStringAsFixed(1)}',
      'average_on_site_delay_minutes,${point.row.averageOnSiteDelayMinutes.toStringAsFixed(1)}',
      if (point.receiptInvestigationSummary != null)
        'receipt_investigation_summary,"${point.receiptInvestigationSummary!.summaryLine.replaceAll('"', '""')}"',
      for (var index = 0; index < receiptRows.length; index++)
        'receipt_${index + 1},"${receiptRows[index].event.eventId.replaceAll('"', '""')}",state=${_receiptPolicyStateChipLabel(receiptRows[index].event)},branding=${_receiptPolicyBrandingChipLabel(receiptRows[index].event)},headline=${_receiptPolicyHistoryHeadline(receiptRows[index].event).replaceAll('"', '""')}"',
      for (var index = 0; index < chains.length; index++)
        'dispatch_chain_${index + 1},"${_partnerScopeChainCsvSummary(chains[index]).replaceAll('"', '""')}"',
      for (var index = 0; index < eventIds.length; index++)
        'event_id_${index + 1},${eventIds[index]}',
    ];
    return lines.join('\n');
  }

  List<_ReceiptRow> _siteScopeReceiptRows() {
    final rows = _receipts.isNotEmpty ? _receipts : _sampleReceipts;
    return rows
        .where(
          (row) =>
              row.event.clientId.trim() == widget.selectedClient &&
              row.event.siteId.trim() == widget.selectedSite,
        )
        .toList(growable: false);
  }

  _ReceiptInvestigationHistorySummary? _receiptInvestigationHistorySummaryFor({
    required String clientId,
    required String siteId,
    required String reportDate,
  }) {
    final rows = (_receipts.isNotEmpty ? _receipts : _sampleReceipts)
        .where(
          (row) =>
              row.event.clientId.trim() == clientId &&
              row.event.siteId.trim() == siteId &&
              _formatDate(row.event.occurredAt.toUtc()) == reportDate,
        )
        .toList(growable: false);
    if (rows.isEmpty) {
      return null;
    }
    final governanceHandoffCount = _receiptGovernanceHandoffCount(rows);
    final routineReviewCount = _receiptRoutineReviewCount(rows);
    final modeLabel = governanceHandoffCount > 0 && routineReviewCount > 0
        ? 'MIXED REVIEW'
        : governanceHandoffCount > 0
        ? 'OVERSIGHT HANDOFF'
        : 'ROUTINE REVIEW';
    return _ReceiptInvestigationHistorySummary(
      governanceHandoffCount: governanceHandoffCount,
      routineReviewCount: routineReviewCount,
      modeLabel: modeLabel,
    );
  }

  Map<String, Object?> _partnerComparisonExportPayload() {
    final comparisons = _sitePartnerComparisonRows;
    final receiptRows = _siteScopeReceiptRows();
    final receiptInvestigationComparison =
        _receiptInvestigationComparison(receiptRows);
    return <String, Object?>{
      'scope': <String, Object?>{
        'clientId': widget.selectedClient,
        'siteId': widget.selectedSite,
      },
      'comparisonWindow': _partnerComparisonWindow.name,
      'activePartnerLabel': _partnerScopePartnerLabel,
      if (receiptRows.isNotEmpty)
        'receiptInvestigation': <String, Object?>{
          'trendLabel': _receiptInvestigationTrendLabel(receiptRows),
          'trendReason': _receiptInvestigationTrendReason(receiptRows),
          'currentGovernanceHandoffCount':
              receiptInvestigationComparison.currentGovernanceCount,
          'currentRoutineReviewCount':
              receiptInvestigationComparison.currentRoutineCount,
          'baselineGovernanceAverage':
              receiptInvestigationComparison.baselineGovernanceAverage,
          'baselineRoutineAverage':
              receiptInvestigationComparison.baselineRoutineAverage,
          'baselineReceiptCount':
              receiptInvestigationComparison.baselineReceiptCount,
        },
      'comparisons': comparisons
          .map(
            (comparison) => <String, Object?>{
              'partnerLabel': comparison.row.partnerLabel,
              'isLeader': comparison.isLeader,
              'trendLabel': comparison.trendLabel,
              'trendReason': comparison.trendReason,
              'summaryLine': comparison.summaryLine,
              'metricAcceptedDelayMinutes':
                  comparison.metricAcceptedDelayMinutes,
              'metricOnSiteDelayMinutes': comparison.metricOnSiteDelayMinutes,
              'metricSeverityScore': comparison.metricSeverityScore,
              'acceptDeltaMinutes': comparison.acceptDeltaMinutes,
              'onSiteDeltaMinutes': comparison.onSiteDeltaMinutes,
              'row': comparison.row.toJson(),
              'history': comparison.historyPoints
                  .map((point) => point.toJson())
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
    };
  }

  Map<String, Object?> _receiptPolicyHistoryExportPayload(
    List<_ReceiptRow> rows,
  ) {
    final activeEntryContext = _activeReceiptPolicyEntryContext(rows);
    final investigationTrendLabel = _receiptInvestigationTrendLabel(rows);
    final investigationTrendReason = _receiptInvestigationTrendReason(rows);
    final governanceCount = _receiptGovernanceHandoffCount(rows);
    final routineCount = _receiptRoutineReviewCount(rows);
    final investigationComparison = _receiptInvestigationComparison(rows);
    return <String, Object?>{
      'scope': <String, Object?>{
        'clientId': widget.selectedClient,
        'siteId': widget.selectedSite,
      },
      if (activeEntryContext != null)
        'entryContext': <String, Object?>{
          'key': activeEntryContext.storageValue,
          'title': activeEntryContext.bannerTitle,
          'detail': activeEntryContext.bannerDetail,
        },
      'investigationLens': <String, Object?>{
        'modeKey': activeEntryContext?.storageValue ?? 'routine_review',
        'modeLabel':
            activeEntryContext == ReportEntryContext.governanceBrandingDrift
            ? 'OVERSIGHT HANDOFF'
            : 'ROUTINE REVIEW',
        'modeDetail':
            activeEntryContext == ReportEntryContext.governanceBrandingDrift
            ? 'This receipt investigation was opened from Governance branding drift, so operators can compare the current lane against the normal Reports receipt baseline.'
            : 'This receipt investigation was opened directly in Reports without a Governance oversight handoff.',
        'baselineLabel': 'ROUTINE BASELINE',
        'baselineDetail':
            activeEntryContext == ReportEntryContext.governanceBrandingDrift
            ? 'Routine review is the default receipt-policy baseline when operators enter Reports without an oversight handoff.'
            : 'Governance-launched investigations will be labeled separately when a branding-drift handoff opens this lane.',
      },
      'investigationBreakdown': <String, Object?>{
        'governanceHandoffCount': governanceCount,
        'routineReviewCount': routineCount,
      },
      'investigationComparison': <String, Object?>{
        'currentGovernanceHandoffCount':
            investigationComparison.currentGovernanceCount,
        'currentRoutineReviewCount':
            investigationComparison.currentRoutineCount,
        'baselineGovernanceAverage':
            investigationComparison.baselineGovernanceAverage,
        'baselineRoutineAverage':
            investigationComparison.baselineRoutineAverage,
        'baselineReceiptCount': investigationComparison.baselineReceiptCount,
      },
      'trendLabel': _receiptPolicyTrendLabel(rows),
      'trendReason': _receiptPolicyTrendReason(rows),
      'investigationTrend': <String, Object?>{
        'label': investigationTrendLabel,
        'reason': investigationTrendReason,
      },
      'receipts': rows
          .map(
            (row) => <String, Object?>{
              'eventId': row.event.eventId,
              'occurredAtUtc': row.event.occurredAt.toIso8601String(),
              'month': row.event.month,
              'reportSchemaVersion': row.event.reportSchemaVersion,
              'stateLabel': _receiptPolicyStateChipLabel(row.event),
              'brandingMode': _receiptPolicyBrandingChipLabel(row.event),
              'headline': _receiptPolicyHistoryHeadline(row.event),
              'detail': _receiptPolicyHistoryDetail(row.event),
              'brandingSummary': _receiptPolicyBrandingSummary(row.event),
              'investigationContextKey':
                  row.event.investigationContextKey.trim().isEmpty
                  ? 'routine_review'
                  : row.event.investigationContextKey.trim(),
              'investigationContextLabel':
                  _storedEntryContextForReceipt(row.event) ==
                      ReportEntryContext.governanceBrandingDrift
                  ? 'OVERSIGHT HANDOFF'
                  : 'ROUTINE REVIEW',
              'includedSections': _receiptIncludedSectionLabels(row.event),
              'omittedSections': _receiptOmittedSectionLabels(row.event),
              'eventCount': row.event.eventCount,
            },
          )
          .toList(growable: false),
    };
  }

  String _partnerScopeExportCsv() {
    final clientId = _partnerScopeClientId;
    final siteId = _partnerScopeSiteId;
    final partnerLabel = _partnerScopePartnerLabel;
    if (clientId == null || siteId == null || partnerLabel == null) {
      return 'metric,value';
    }
    return _partnerScopeExportCsvFor(
      clientId: clientId,
      siteId: siteId,
      partnerLabel: partnerLabel,
    );
  }

  String _partnerScopeExportCsvFor({
    required String clientId,
    required String siteId,
    required String partnerLabel,
  }) {
    final historyPoints = _partnerScopeHistoryPointsFor(
      clientId: clientId,
      siteId: siteId,
      partnerLabel: partnerLabel,
    );
    final chains = _partnerDispatchChainsForScope(
      clientId: clientId,
      siteId: siteId,
      partnerLabel: partnerLabel,
    );
    final receiptRows = _partnerReceiptRowsForScope(
      clientId: clientId,
      siteId: siteId,
    );
    final receiptInvestigationComparison =
        _receiptInvestigationComparison(receiptRows);
    final lines = <String>[
      'metric,value',
      'client_id,$clientId',
      'site_id,$siteId',
      'partner_label,"${partnerLabel.replaceAll('"', '""')}"',
      'trend_label,${_partnerScopeTrendLabel(historyPoints)}',
      'trend_reason,"${_partnerScopeTrendReason(historyPoints).replaceAll('"', '""')}"',
      if (receiptRows.isNotEmpty)
        'receipt_investigation_trend_label,"${_receiptInvestigationTrendLabel(receiptRows).replaceAll('"', '""')}"',
      if (receiptRows.isNotEmpty)
        'receipt_investigation_trend_reason,"${_receiptInvestigationTrendReason(receiptRows).replaceAll('"', '""')}"',
      if (receiptRows.isNotEmpty)
        'receipt_investigation_current_governance_handoff_count,${receiptInvestigationComparison.currentGovernanceCount}',
      if (receiptRows.isNotEmpty)
        'receipt_investigation_current_routine_review_count,${receiptInvestigationComparison.currentRoutineCount}',
      if (receiptRows.isNotEmpty)
        'receipt_investigation_baseline_governance_average,${receiptInvestigationComparison.baselineGovernanceAverage.toStringAsFixed(1)}',
      if (receiptRows.isNotEmpty)
        'receipt_investigation_baseline_routine_average,${receiptInvestigationComparison.baselineRoutineAverage.toStringAsFixed(1)}',
      if (receiptRows.isNotEmpty)
        'receipt_investigation_baseline_receipt_count,${receiptInvestigationComparison.baselineReceiptCount}',
      for (var i = 0; i < historyPoints.length; i++)
        'history_row_${i + 1},"${historyPoints[i].toCsvSummary().replaceAll('"', '""')}"',
      for (var i = 0; i < chains.length; i++)
        'dispatch_chain_${i + 1},"${_partnerScopeChainCsvSummary(chains[i]).replaceAll('"', '""')}"',
    ];
    return lines.join('\n');
  }

  String _partnerComparisonExportCsv() {
    final comparisons = _sitePartnerComparisonRows;
    final receiptRows = _siteScopeReceiptRows();
    final receiptInvestigationComparison =
        _receiptInvestigationComparison(receiptRows);
    final lines = <String>[
      'metric,value',
      'client_id,${widget.selectedClient}',
      'site_id,${widget.selectedSite}',
      'comparison_window,${_partnerComparisonWindow.name}',
      'active_partner_label,"${(_partnerScopePartnerLabel ?? '').replaceAll('"', '""')}"',
      if (receiptRows.isNotEmpty)
        'receipt_investigation_trend_label,"${_receiptInvestigationTrendLabel(receiptRows).replaceAll('"', '""')}"',
      if (receiptRows.isNotEmpty)
        'receipt_investigation_trend_reason,"${_receiptInvestigationTrendReason(receiptRows).replaceAll('"', '""')}"',
      if (receiptRows.isNotEmpty)
        'receipt_investigation_current_governance_handoff_count,${receiptInvestigationComparison.currentGovernanceCount}',
      if (receiptRows.isNotEmpty)
        'receipt_investigation_current_routine_review_count,${receiptInvestigationComparison.currentRoutineCount}',
      if (receiptRows.isNotEmpty)
        'receipt_investigation_baseline_governance_average,${receiptInvestigationComparison.baselineGovernanceAverage.toStringAsFixed(1)}',
      if (receiptRows.isNotEmpty)
        'receipt_investigation_baseline_routine_average,${receiptInvestigationComparison.baselineRoutineAverage.toStringAsFixed(1)}',
      if (receiptRows.isNotEmpty)
        'receipt_investigation_baseline_receipt_count,${receiptInvestigationComparison.baselineReceiptCount}',
    ];
    for (var index = 0; index < comparisons.length; index++) {
      final comparison = comparisons[index];
      final prefix = 'comparison_${index + 1}';
      lines.add(
        '$prefix,"${comparison.row.partnerLabel.replaceAll('"', '""')}",leader=${comparison.isLeader},trend=${comparison.trendLabel},metric_accept=${comparison.metricAcceptedDelayMinutes.toStringAsFixed(1)},metric_on_site=${comparison.metricOnSiteDelayMinutes.toStringAsFixed(1)},accept_delta=${comparison.acceptDeltaMinutes?.toStringAsFixed(1) ?? ''},on_site_delta=${comparison.onSiteDeltaMinutes?.toStringAsFixed(1) ?? ''}',
      );
      for (
        var historyIndex = 0;
        historyIndex < comparison.historyPoints.length;
        historyIndex++
      ) {
        final point = comparison.historyPoints[historyIndex];
        lines.add(
          '${prefix}_history_${historyIndex + 1},"${point.toCsvSummary().replaceAll('"', '""')}"',
        );
      }
    }
    return lines.join('\n');
  }

  String _receiptPolicyHistoryExportCsv(List<_ReceiptRow> rows) {
    final activeEntryContext = _activeReceiptPolicyEntryContext(rows);
    final investigationTrendLabel = _receiptInvestigationTrendLabel(rows);
    final investigationTrendReason = _receiptInvestigationTrendReason(rows);
    final governanceCount = _receiptGovernanceHandoffCount(rows);
    final routineCount = _receiptRoutineReviewCount(rows);
    final investigationComparison = _receiptInvestigationComparison(rows);
    final lines = <String>[
      'metric,value',
      'client_id,${widget.selectedClient}',
      'site_id,${widget.selectedSite}',
      if (activeEntryContext != null)
        'entry_context,${activeEntryContext.storageValue}',
      if (activeEntryContext != null)
        'entry_context_title,"${activeEntryContext.bannerTitle.replaceAll('"', '""')}"',
      if (activeEntryContext != null)
        'entry_context_detail,"${activeEntryContext.bannerDetail.replaceAll('"', '""')}"',
      'investigation_mode,${activeEntryContext?.storageValue ?? 'routine_review'}',
      'investigation_mode_label,"${(activeEntryContext == ReportEntryContext.governanceBrandingDrift ? 'OVERSIGHT HANDOFF' : 'ROUTINE REVIEW').replaceAll('"', '""')}"',
      'investigation_baseline_label,"ROUTINE BASELINE"',
      'investigation_governance_handoff_count,$governanceCount',
      'investigation_routine_review_count,$routineCount',
      'investigation_current_governance_handoff_count,${investigationComparison.currentGovernanceCount}',
      'investigation_current_routine_review_count,${investigationComparison.currentRoutineCount}',
      'investigation_baseline_governance_average,${investigationComparison.baselineGovernanceAverage.toStringAsFixed(1)}',
      'investigation_baseline_routine_average,${investigationComparison.baselineRoutineAverage.toStringAsFixed(1)}',
      'investigation_baseline_receipt_count,${investigationComparison.baselineReceiptCount}',
      'trend_label,${_receiptPolicyTrendLabel(rows)}',
      'trend_reason,"${_receiptPolicyTrendReason(rows).replaceAll('"', '""')}"',
      'investigation_trend_label,"${investigationTrendLabel.replaceAll('"', '""')}"',
      'investigation_trend_reason,"${investigationTrendReason.replaceAll('"', '""')}"',
    ];
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      lines.add(
        'receipt_${index + 1},"${row.event.eventId.replaceAll('"', '""')}",state=${_receiptPolicyStateChipLabel(row.event)},branding=${_receiptPolicyBrandingChipLabel(row.event)},investigation=${(row.event.investigationContextKey.trim().isEmpty ? 'routine_review' : row.event.investigationContextKey.trim())},headline=${_receiptPolicyHistoryHeadline(row.event).replaceAll('"', '""')},event_count=${row.event.eventCount}',
      );
      lines.add(
        'receipt_${index + 1}_detail,"${_receiptPolicyHistoryDetail(row.event).replaceAll('"', '""')}"',
      );
    }
    return lines.join('\n');
  }

  String _partnerScopeChainCsvSummary(
    SovereignReportPartnerDispatchChain chain,
  ) {
    final parts = <String>[
      chain.dispatchId,
      chain.workflowSummary,
      if (chain.scoreLabel.trim().isNotEmpty) chain.scoreLabel.trim(),
      if (chain.scoreReason.trim().isNotEmpty) chain.scoreReason.trim(),
    ];
    return parts.join(' • ');
  }

  void _showReceiptActionFeedback(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _copyReceipt(_ReceiptRow row) {
    final payload = ReportReceiptExportPayload.buildSingle(
      entry: ReportReceiptExportEntry(
        receiptEvent: row.event,
        replayVerified: row.replayVerified,
        sceneReviewSummary: row.sceneReviewSummary,
      ),
      filter: _receiptFilter,
      selectedReceiptEventId: _selectedReceiptEventId,
      previewReceiptEventId: _previewReceiptEventId,
      activeSectionConfiguration: _currentSectionConfiguration.toJson(),
      entryContext: _effectiveEntryContextForReceipt(row.event),
    );
    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    Clipboard.setData(ClipboardData(text: encoded));
    logUiAction(
      'reports.copy_receipt',
      context: {'event_id': row.event.eventId},
    );
    _showReceiptActionFeedback(
      'Receipt export copied for ${row.event.eventId}.',
    );
  }

  Future<void> _previewReceipt(_ReceiptRow row, bool hasLiveReceipts) async {
    if (!hasLiveReceipts) {
      logUiAction(
        'reports.preview_sample_receipt',
        context: {'event_id': row.event.eventId},
      );
      _showReceiptActionFeedback(
        'Sample receipt preview unavailable. Generate a live report first.',
      );
      return;
    }
    logUiAction(
      'reports.preview_live_receipt',
      context: {'event_id': row.event.eventId},
    );
    await _openReceipt(row);
  }

  Future<void> _downloadReceipt(_ReceiptRow row, bool hasLiveReceipts) async {
    if (!hasLiveReceipts) {
      final payload = ReportReceiptExportPayload.buildSingle(
        entry: ReportReceiptExportEntry(
          receiptEvent: row.event,
          sceneReviewSummary: row.sceneReviewSummary,
        ),
        filter: _receiptFilter,
        selectedReceiptEventId: _selectedReceiptEventId,
        previewReceiptEventId: _previewReceiptEventId,
        activeSectionConfiguration: _currentSectionConfiguration.toJson(),
        entryContext: _effectiveEntryContextForReceipt(row.event),
      );
      final encoded = const JsonEncoder.withIndent('  ').convert(payload);
      Clipboard.setData(ClipboardData(text: encoded));
      logUiAction(
        'reports.download_sample_receipt',
        context: {'event_id': row.event.eventId},
      );
      _showReceiptActionFeedback(
        'Sample receipt metadata copied for ${row.event.eventId}.',
      );
      return;
    }
    logUiAction(
      'reports.download_live_receipt',
      context: {'event_id': row.event.eventId},
    );
    await _openReceipt(row);
  }

  Widget _actionButton({
    Key? key,
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return TextButton.icon(
      key: key,
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFF194E87),
        foregroundColor: const Color(0xFFE8F1FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: Color(0xFF2A4768)),
        ),
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _pickDate({
    required DateTime initial,
    required DateTime first,
    required DateTime last,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Select report date',
    );
    if (picked == null) {
      return;
    }
    onSelected(DateTime.utc(picked.year, picked.month, picked.day));
  }

  String _humanizeClient(String clientId) {
    final normalized = clientId.replaceAll('_', '-').toUpperCase();
    if (normalized == 'CLIENT-001') {
      return 'Sandton Estate HOA';
    }
    return normalized;
  }

  String _humanizeSite(String siteId) {
    final normalized = siteId.replaceAll('_', '-').toUpperCase();
    if (normalized == 'SITE-SANDTON') {
      return 'Sandton Estate North';
    }
    return normalized;
  }

  String _periodFromMonth(String month) {
    final parts = month.split('-');
    if (parts.length != 2) {
      return month;
    }
    final year = int.tryParse(parts[0]);
    final monthIndex = int.tryParse(parts[1]);
    if (year == null ||
        monthIndex == null ||
        monthIndex < 1 ||
        monthIndex > 12) {
      return month;
    }
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${monthNames[monthIndex - 1]} $year';
  }

  String _formatUtc(DateTime dateTime) {
    final value = dateTime.toUtc();
    final yy = value.year.toString().padLeft(4, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$yy-$mm-$dd $hh:$min UTC';
  }

  String _formatDate(DateTime dateTime) {
    final yy = dateTime.year.toString().padLeft(4, '0');
    final mm = dateTime.month.toString().padLeft(2, '0');
    final dd = dateTime.day.toString().padLeft(2, '0');
    return '$yy-$mm-$dd';
  }

  List<_ReceiptRow> get _sampleReceipts => [
    _ReceiptRow(
      event: ReportGenerated(
        eventId: 'RPT-2024-03-10-001',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2024, 3, 10, 22, 15),
        clientId: 'Sandton Estate HOA',
        siteId: 'Sandton Estate North',
        month: '2024-03',
        contentHash: 'sample',
        pdfHash: 'sample',
        eventRangeStart: 1,
        eventRangeEnd: 1247,
        eventCount: 1247,
        reportSchemaVersion: 1,
        projectionVersion: 1,
      ),
      replayVerified: true,
      sceneReviewSummary: const ReportReceiptSceneReviewSummary(
        includedInReceipt: false,
        totalReviews: 0,
        modelReviews: 0,
        escalationCandidates: 0,
        topPosture: 'none',
      ),
    ),
    _ReceiptRow(
      event: ReportGenerated(
        eventId: 'RPT-2024-03-10-002',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2024, 3, 10, 22, 10),
        clientId: 'Waterfall Security Board',
        siteId: 'Waterfall Estate Main',
        month: '2024-03',
        contentHash: 'sample',
        pdfHash: 'sample',
        eventRangeStart: 1,
        eventRangeEnd: 1856,
        eventCount: 1856,
        reportSchemaVersion: 1,
        projectionVersion: 1,
      ),
      replayVerified: true,
      sceneReviewSummary: const ReportReceiptSceneReviewSummary(
        includedInReceipt: false,
        totalReviews: 0,
        modelReviews: 0,
        escalationCandidates: 0,
        topPosture: 'none',
      ),
    ),
    _ReceiptRow(
      event: ReportGenerated(
        eventId: 'RPT-2024-03-09-002',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2024, 3, 9, 23, 40),
        clientId: 'Midrand Industrial Trust',
        siteId: 'Midrand Industrial Park',
        month: '2024-03',
        contentHash: 'sample',
        pdfHash: 'sample',
        eventRangeStart: 1,
        eventRangeEnd: 1134,
        eventCount: 1134,
        reportSchemaVersion: 1,
        projectionVersion: 1,
      ),
      replayVerified: false,
      sceneReviewSummary: const ReportReceiptSceneReviewSummary(
        includedInReceipt: false,
        totalReviews: 0,
        modelReviews: 0,
        escalationCandidates: 0,
        topPosture: 'none',
      ),
    ),
  ];
}

class _ReceiptRow {
  final ReportGenerated event;
  final bool replayVerified;
  final ReportReceiptSceneReviewSummary? sceneReviewSummary;

  const _ReceiptRow({
    required this.event,
    required this.replayVerified,
    this.sceneReviewSummary,
  });
}

class _ReceiptInvestigationComparison {
  final int currentGovernanceCount;
  final int currentRoutineCount;
  final double baselineGovernanceAverage;
  final double baselineRoutineAverage;
  final int baselineReceiptCount;

  const _ReceiptInvestigationComparison({
    required this.currentGovernanceCount,
    required this.currentRoutineCount,
    required this.baselineGovernanceAverage,
    required this.baselineRoutineAverage,
    required this.baselineReceiptCount,
  });
}

class _PartnerScopeHistoryPoint {
  final String reportDate;
  final SovereignReportPartnerScoreboardRow row;
  final bool current;
  final _ReceiptInvestigationHistorySummary? receiptInvestigationSummary;

  const _PartnerScopeHistoryPoint({
    required this.reportDate,
    required this.row,
    required this.current,
    this.receiptInvestigationSummary,
  });

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'reportDate': reportDate,
      'current': current,
      'row': row.toJson(),
      if (receiptInvestigationSummary != null)
        'receiptInvestigation': receiptInvestigationSummary!.toJson(),
    };
  }

  String toCsvSummary() {
    final currentLabel = current ? 'CURRENT' : 'HISTORY';
    final receiptSummary = receiptInvestigationSummary?.summaryLine;
    return [
      '$reportDate • $currentLabel • ${row.clientId}/${row.siteId} • ${row.partnerLabel} • ${row.summaryLine}',
      if (receiptSummary != null && receiptSummary.trim().isNotEmpty)
        receiptSummary,
    ].join(' • ');
  }
}

class _ReceiptInvestigationHistorySummary {
  final int governanceHandoffCount;
  final int routineReviewCount;
  final String modeLabel;

  const _ReceiptInvestigationHistorySummary({
    required this.governanceHandoffCount,
    required this.routineReviewCount,
    required this.modeLabel,
  });

  String get summaryLine =>
      'Receipt $modeLabel • Governance $governanceHandoffCount • Routine $routineReviewCount';

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'modeLabel': modeLabel,
      'governanceHandoffCount': governanceHandoffCount,
      'routineReviewCount': routineReviewCount,
      'summaryLine': summaryLine,
    };
  }
}

class _PartnerComparisonRow {
  final SovereignReportPartnerScoreboardRow row;
  final bool isLeader;
  final String trendLabel;
  final String trendReason;
  final List<_PartnerScopeHistoryPoint> historyPoints;
  final String summaryLine;
  final double metricAcceptedDelayMinutes;
  final double metricOnSiteDelayMinutes;
  final double metricSeverityScore;
  final double? acceptDeltaMinutes;
  final double? onSiteDeltaMinutes;

  const _PartnerComparisonRow({
    required this.row,
    required this.isLeader,
    required this.trendLabel,
    required this.trendReason,
    required this.historyPoints,
    required this.summaryLine,
    required this.metricAcceptedDelayMinutes,
    required this.metricOnSiteDelayMinutes,
    required this.metricSeverityScore,
    required this.acceptDeltaMinutes,
    required this.onSiteDeltaMinutes,
  });

  _PartnerComparisonRow copyWith({
    bool? isLeader,
    double? acceptDeltaMinutes,
    double? onSiteDeltaMinutes,
  }) {
    return _PartnerComparisonRow(
      row: row,
      isLeader: isLeader ?? this.isLeader,
      trendLabel: trendLabel,
      trendReason: trendReason,
      historyPoints: historyPoints,
      summaryLine: summaryLine,
      metricAcceptedDelayMinutes: metricAcceptedDelayMinutes,
      metricOnSiteDelayMinutes: metricOnSiteDelayMinutes,
      metricSeverityScore: metricSeverityScore,
      acceptDeltaMinutes: acceptDeltaMinutes,
      onSiteDeltaMinutes: onSiteDeltaMinutes,
    );
  }
}

int _compareDispatchEventsByOccurredAtThenSequence(
  DispatchEvent a,
  DispatchEvent b,
) {
  final occurredAtCompare = a.occurredAt.compareTo(b.occurredAt);
  if (occurredAtCompare != 0) {
    return occurredAtCompare;
  }
  return a.sequence.compareTo(b.sequence);
}
