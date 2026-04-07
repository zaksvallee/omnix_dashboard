import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/admin/admin_directory_service.dart';
import '../application/export_coordinator.dart';
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
import '../application/review_shortcut_contract.dart';
import '../application/site_activity_intelligence_service.dart';
import '../domain/crm/reporting/report_branding_configuration.dart';
import '../domain/crm/reporting/report_section_configuration.dart';
import '../domain/crm/reporting/report_sections.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/guard_checked_in.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/partner_dispatch_status_declared.dart';
import '../domain/events/patrol_completed.dart';
import '../domain/events/report_generated.dart';
import '../domain/events/response_arrived.dart';
import '../domain/store/event_store.dart';
import '../presentation/reports/report_preview_dock_card.dart';
import '../presentation/reports/report_meta_pill.dart';
import '../presentation/reports/report_receipt_filter_control.dart';
import '../presentation/reports/report_receipt_filter_banner.dart';
import '../presentation/reports/report_shell_binding_host.dart';
import '../presentation/reports/report_scene_review_narrative_box.dart';
import '../presentation/reports/report_scene_review_pill_builder.dart';
import '../presentation/reports/report_preview_target_banner.dart';
import '../presentation/reports/report_status_badge.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'theme/onyx_design_tokens.dart';
import 'ui_action_logger.dart';

const _reportsPanelColor = OnyxDesignTokens.cardSurface;
const _reportsPanelAltColor = OnyxDesignTokens.backgroundSecondary;
const _reportsPanelTintColor = OnyxDesignTokens.surfaceInset;
const _reportsBorderColor = OnyxDesignTokens.borderSubtle;
const _reportsTitleColor = OnyxDesignTokens.textPrimary;
const _reportsBodyColor = OnyxDesignTokens.textSecondary;
const _reportsMutedColor = OnyxDesignTokens.textMuted;
const _reportsShadowColor = Color(0x0D000000);
const _reportsAccentSky = OnyxDesignTokens.accentSky;

class ClientIntelligenceReportsPage extends StatefulWidget {
  final EventStore store;
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
  final void Function(String clientId, String siteId)? onOpenGovernanceForScope;
  final void Function(String clientId, String siteId, String partnerLabel)?
  onOpenGovernanceForPartnerScope;
  final void Function(List<String> eventIds, String selectedEventId)?
  onOpenEventsForScope;
  final ReportsEvidenceReturnReceipt? evidenceReturnReceipt;
  final ValueChanged<String>? onConsumeEvidenceReturnReceipt;

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
    this.onOpenGovernanceForScope,
    this.onOpenGovernanceForPartnerScope,
    this.onOpenEventsForScope,
    this.evidenceReturnReceipt,
    this.onConsumeEvidenceReturnReceipt,
  });

  @override
  State<ClientIntelligenceReportsPage> createState() =>
      _ClientIntelligenceReportsPageState();
}

class _ReportsCommandReceipt {
  final String label;
  final String message;
  final String detail;
  final Color accent;

  const _ReportsCommandReceipt({
    required this.label,
    required this.message,
    required this.detail,
    required this.accent,
  });
}

class ReportsEvidenceReturnReceipt {
  final String auditId;
  final String label;
  final String message;
  final String detail;
  final Color accent;

  const ReportsEvidenceReturnReceipt({
    required this.auditId,
    required this.label,
    required this.message,
    required this.detail,
    required this.accent,
  });
}

class _ClientIntelligenceReportsPageState
    extends State<ClientIntelligenceReportsPage>
    with ReportShellBindingHost<ClientIntelligenceReportsPage> {
  static const _exportCoordinator = ExportCoordinator();
  static const _siteActivityService = SiteActivityIntelligenceService();
  static const _defaultCommandReceipt = _ReportsCommandReceipt(
    label: 'REPORTS READY',
    message: 'Pick the right receipt and move it out fast.',
    detail:
        'Preview, governance handoff, and receipt proof stay pinned here so the next move is obvious.',
    accent: _reportsAccentSky,
  );
  bool _isGenerating = false;
  bool _isRefreshing = false;
  List<_ReceiptRow> _receipts = const [];
  late ReportShellBinding _shellBinding;
  late ReportGenerationService _service;
  String _selectedScope = 'Sandton Estate North';
  DateTime _startDate = DateTime.utc(2024, 3, 1);
  DateTime _endDate = DateTime.utc(2024, 3, 10);
  _ReportsCommandReceipt _commandReceipt = _defaultCommandReceipt;
  bool _desktopWorkspaceActive = false;

  VoidCallback? _openGovernanceScopeAction({
    String clientId = '',
    String siteId = '',
  }) {
    final scopedCallback = widget.onOpenGovernanceForScope;
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    if (scopedCallback != null &&
        normalizedClientId.isNotEmpty &&
        normalizedSiteId.isNotEmpty) {
      return () => scopedCallback(normalizedClientId, normalizedSiteId);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _service = _createReportGenerationService();
    _shellBinding = ReportShellBinding.fromShellState(widget.reportShellState);
    _syncFocusedPartnerScopeFromWidget(deferEmit: true);
    _loadReceipts();
    _ingestEvidenceReturnReceipt(widget.evidenceReturnReceipt);
  }

  @override
  void didUpdateWidget(covariant ClientIntelligenceReportsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store ||
        oldWidget.sceneReviewByIntelligenceId !=
            widget.sceneReviewByIntelligenceId) {
      _service = _createReportGenerationService();
    }
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
    if (oldWidget.evidenceReturnReceipt?.auditId !=
        widget.evidenceReturnReceipt?.auditId) {
      _ingestEvidenceReturnReceipt(
        widget.evidenceReturnReceipt,
        useSetState: true,
      );
    }
  }

  void _ingestEvidenceReturnReceipt(
    ReportsEvidenceReturnReceipt? receipt, {
    bool useSetState = false,
  }) {
    if (receipt == null) {
      return;
    }

    void apply() {
      _commandReceipt = _ReportsCommandReceipt(
        label: receipt.label,
        message: receipt.message,
        detail: receipt.detail,
        accent: receipt.accent,
      );
    }

    if (useSetState) {
      setState(apply);
    } else {
      apply();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onConsumeEvidenceReturnReceipt?.call(receipt.auditId);
    });
  }

  ReportGenerationService _createReportGenerationService() {
    return ReportGenerationService(
      store: widget.store,
      sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
      guardProfilesLoader: () async {
        final snapshot = await const AdminDirectoryService().loadDirectory(
          supabase: Supabase.instance.client,
        );
        return <String, GuardReportingProfile>{
          for (final guard in snapshot.guards)
            guard.id: GuardReportingProfile(
              guardId: guard.id,
              displayName: guard.name,
              psiraNumber: guard.psiraNumber,
              rank: guard.role,
            ),
        };
      },
    );
  }

  DateTime _reportGenerationNowUtc() {
    DateTime? latestOccurredAtUtc;
    for (final event in widget.store.allEvents()) {
      final occurredAtUtc = switch (event) {
        GuardCheckedIn value
            when value.clientId == widget.selectedClient &&
                value.siteId == widget.selectedSite =>
          value.occurredAt.toUtc(),
        PatrolCompleted value
            when value.clientId == widget.selectedClient &&
                value.siteId == widget.selectedSite =>
          value.occurredAt.toUtc(),
        DecisionCreated value
            when value.clientId == widget.selectedClient &&
                value.siteId == widget.selectedSite =>
          value.occurredAt.toUtc(),
        ResponseArrived value
            when value.clientId == widget.selectedClient &&
                value.siteId == widget.selectedSite =>
          value.occurredAt.toUtc(),
        IncidentClosed value
            when value.clientId == widget.selectedClient &&
                value.siteId == widget.selectedSite =>
          value.occurredAt.toUtc(),
        IntelligenceReceived value
            when value.clientId == widget.selectedClient &&
                value.siteId == widget.selectedSite =>
          value.occurredAt.toUtc(),
        ExecutionCompleted value
            when value.clientId == widget.selectedClient &&
                value.siteId == widget.selectedSite =>
          value.occurredAt.toUtc(),
        ExecutionDenied value
            when value.clientId == widget.selectedClient &&
                value.siteId == widget.selectedSite =>
          value.occurredAt.toUtc(),
        _ => null,
      };
      if (occurredAtUtc == null) {
        continue;
      }
      if (latestOccurredAtUtc == null ||
          occurredAtUtc.isAfter(latestOccurredAtUtc)) {
        latestOccurredAtUtc = occurredAtUtc;
      }
    }
    return latestOccurredAtUtc ?? _endDate.toUtc();
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
      nowUtc: _reportGenerationNowUtc(),
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
    if (!mounted) {
      return;
    }
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
    final activeReceipt =
        focusedReceipt ??
        (visibleReceipts.isNotEmpty ? visibleReceipts.first : null);
    final supplementalDeck = _reportsSupplementalDeck(
      reportRows: reportRows,
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
    );
    return OnyxPageScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useDesktopWorkspace = constraints.maxWidth >= 1360;
          final useEmbeddedPanels =
              useDesktopWorkspace && allowEmbeddedPanelScroll(context);
          final useUltrawideWorkspace = isUltrawideLayout(
            context,
            viewportWidth: constraints.maxWidth,
          );
          final useWidescreenWorkspace = isWidescreenLayout(
            context,
            viewportWidth: constraints.maxWidth,
          );
          final surfaceMaxWidth = useUltrawideWorkspace
              ? constraints.maxWidth
              : useWidescreenWorkspace
              ? constraints.maxWidth * 0.92
              : 1760.0;
          final mergeWorkspaceBannerIntoHero = useDesktopWorkspace;
          return OnyxViewportWorkspaceLayout(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            maxWidth: surfaceMaxWidth,
            spacing: 6,
            lockToViewport: useEmbeddedPanels,
            header: _heroHeader(
              totalReceipts: reportRows.length,
              verifiedCount: verifiedCount,
              pendingCount: pendingCount,
              reviewedCount: reviewedCount,
              pendingSceneCount: pendingSceneCount,
              workspaceBanner: mergeWorkspaceBannerIntoHero
                  ? _reportsWorkspaceStatusBanner(
                      reportRows: reportRows,
                      visibleReceipts: visibleReceipts,
                      activeReceipt: activeReceipt,
                      previewTargetReceipt: previewTargetReceipt,
                      hasLiveReceipts: _receipts.isNotEmpty,
                      summaryOnly: true,
                      shellless: true,
                    )
                  : null,
            ),
            body: useDesktopWorkspace
                ? _reportsCommandWorkspace(
                    reportRows: reportRows,
                    visibleReceipts: visibleReceipts,
                    previewTargetReceipt: previewTargetReceipt,
                    activeReceipt: activeReceipt,
                    hasLiveReceipts: _receipts.isNotEmpty,
                    useEmbeddedPanels: useEmbeddedPanels,
                    mergeWorkspaceBannerIntoHero: mergeWorkspaceBannerIntoHero,
                    desktopSupplementalDeck: supplementalDeck,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _reportsCommandWorkspace(
                        reportRows: reportRows,
                        visibleReceipts: visibleReceipts,
                        previewTargetReceipt: previewTargetReceipt,
                        activeReceipt: activeReceipt,
                        hasLiveReceipts: _receipts.isNotEmpty,
                        useEmbeddedPanels: false,
                        mergeWorkspaceBannerIntoHero: false,
                      ),
                      const SizedBox(height: 8),
                      supplementalDeck,
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _reportsCommandWorkspace({
    required List<_ReceiptRow> reportRows,
    required List<_ReceiptRow> visibleReceipts,
    required _ReceiptRow? previewTargetReceipt,
    required _ReceiptRow? activeReceipt,
    required bool hasLiveReceipts,
    required bool useEmbeddedPanels,
    required bool mergeWorkspaceBannerIntoHero,
    Widget? desktopSupplementalDeck,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 1360;
        const receiptRailFlex = 3;
        const selectedBoardFlex = 9;
        const contextRailFlex = 2;
        const workspaceGap = 6.0;
        final stretchPanels =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        _desktopWorkspaceActive = !stacked;
        final receiptRail = _workspaceDeckPanel(
          key: const ValueKey('reports-workspace-panel-receipts'),
          title: 'PICK A RECEIPT',
          subtitle: 'Filter the receipt board and open the right report fast.',
          shellless: !stacked,
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _reportsWorkspaceCommandStrip(
                      visibleReceipts: visibleReceipts,
                      totalReceipts: reportRows.length,
                      activeReceipt: activeReceipt,
                    ),
                    const SizedBox(height: 8),
                    _reportWorkbenchSurface(
                      visibleReceipts: visibleReceipts,
                      totalReceipts: reportRows.length,
                      hasLiveReceipts: hasLiveReceipts,
                      activeReceipt: activeReceipt,
                    ),
                  ],
                )
              : _reportWorkbenchSurface(
                  visibleReceipts: visibleReceipts,
                  totalReceipts: reportRows.length,
                  hasLiveReceipts: hasLiveReceipts,
                  activeReceipt: activeReceipt,
                  includeWorkspaceControls: true,
                  shellless: true,
                ),
        );
        final selectedBoard = _workspaceDeckPanel(
          key: const ValueKey('reports-workspace-panel-selected'),
          title: 'DO THIS NOW',
          subtitle: 'Keep one receipt in focus and decide the next move.',
          shellless: !stacked,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reportsWorkspaceFocusBanner(
                reportRows: reportRows,
                activeReceipt: activeReceipt,
                previewTargetReceipt: previewTargetReceipt,
                visibleReceipts: visibleReceipts,
                hasLiveReceipts: hasLiveReceipts,
                shellless: !stacked,
              ),
              const SizedBox(height: 8),
              _selectedReportSurface(
                row: activeReceipt,
                hasLiveReceipts: hasLiveReceipts,
                shellless: !stacked,
              ),
              if (useEmbeddedPanels && desktopSupplementalDeck != null) ...[
                const SizedBox(height: 8),
                desktopSupplementalDeck,
              ],
            ],
          ),
        );
        final contextRail = _workspaceDeckPanel(
          key: const ValueKey('reports-workspace-panel-context'),
          title: 'HANDOFFS',
          subtitle: 'Preview, governance, and output moves live here.',
          shellless: !stacked,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reportsWorkspaceContextSnapshot(
                reportRows: reportRows,
                activeReceipt: activeReceipt,
                previewTargetReceipt: previewTargetReceipt,
                hasLiveReceipts: hasLiveReceipts,
                includeCommandReceipt: _desktopWorkspaceActive,
                summaryOnly: !stacked,
                shellless: !stacked,
              ),
              const SizedBox(height: 6),
              _reportPreviewSurface(
                previewTargetReceipt: previewTargetReceipt,
                activeReceipt: activeReceipt,
                hasLiveReceipts: hasLiveReceipts,
                shellless: !stacked,
              ),
              const SizedBox(height: 6),
              _reportOperationsSurface(
                activeReceipt: activeReceipt,
                hasLiveReceipts: hasLiveReceipts,
                shellless: !stacked,
              ),
            ],
          ),
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              receiptRail,
              const SizedBox(height: 8),
              selectedBoard,
              const SizedBox(height: 8),
              contextRail,
            ],
          );
        }

        final workspaceRow = Row(
          crossAxisAlignment: stretchPanels
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
          children: [
            Expanded(flex: receiptRailFlex, child: receiptRail),
            SizedBox(width: workspaceGap),
            Expanded(flex: selectedBoardFlex, child: selectedBoard),
            SizedBox(width: workspaceGap),
            Expanded(flex: contextRailFlex, child: contextRail),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mergeWorkspaceBannerIntoHero) ...[
              _reportsWorkspaceStatusBanner(
                reportRows: reportRows,
                visibleReceipts: visibleReceipts,
                activeReceipt: activeReceipt,
                previewTargetReceipt: previewTargetReceipt,
                hasLiveReceipts: hasLiveReceipts,
              ),
              const SizedBox(height: 8),
            ],
            if (useEmbeddedPanels)
              Expanded(child: workspaceRow)
            else
              workspaceRow,
            if (!useEmbeddedPanels && desktopSupplementalDeck != null) ...[
              const SizedBox(height: 8),
              desktopSupplementalDeck,
            ],
          ],
        );
      },
    );
  }

  Widget _workspaceDeckPanel({
    Key? key,
    required String title,
    required String subtitle,
    bool shellless = false,
    required Widget child,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (shellless) {
          return SizedBox(
            key: key,
            width: double.infinity,
            child: onyxBoundedPanelBody(
              context: context,
              constraints: constraints,
              child: child,
            ),
          );
        }
        return Container(
          key: key,
          width: double.infinity,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _reportsPanelColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _reportsBorderColor),
            boxShadow: const [
              BoxShadow(
                color: _reportsShadowColor,
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: _reportsTitleColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: _reportsBodyColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _reportsPanelAltColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _reportsBorderColor),
                ),
                child: onyxBoundedPanelBody(
                  context: context,
                  constraints: constraints,
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _reportsSupplementalDeck({
    required List<_ReceiptRow> reportRows,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  Widget _reportsWorkspaceStatusBanner({
    required List<_ReceiptRow> reportRows,
    required List<_ReceiptRow> visibleReceipts,
    required _ReceiptRow? activeReceipt,
    required _ReceiptRow? previewTargetReceipt,
    required bool hasLiveReceipts,
    bool summaryOnly = false,
    bool shellless = false,
  }) {
    final hasPartnerLane = _sitePartnerScoreboardRows.isNotEmpty;
    final bannerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            _partnerScopeChip(
              label: hasLiveReceipts ? 'Live receipts' : 'Sample receipts',
              color: hasLiveReceipts
                  ? const Color(0xFF59D79B)
                  : const Color(0xFF8EA4C2),
            ),
            _partnerScopeChip(
              label: '${reportRows.length} total',
              color: const Color(0xFF8FD1FF),
            ),
            _partnerScopeChip(
              label: '${visibleReceipts.length} visible',
              color: const Color(0xFF59D79B),
            ),
            if (activeReceipt != null)
              _partnerScopeChip(
                label: 'Focused ${activeReceipt.event.eventId}',
                color: const Color(0xFF8FD1FF),
              ),
            if (previewTargetReceipt != null)
              _partnerScopeChip(
                label: 'Preview ${previewTargetReceipt.event.eventId}',
                color: const Color(0xFF59D79B),
              ),
            _partnerScopeChip(
              label: _receiptFilter.viewingLabel,
              color: _receiptFilter.bannerBorderColor,
            ),
            if (_hasPartnerScopeFocus)
              _partnerScopeChip(
                label: 'Partner scope active',
                color: const Color(0xFF59D79B),
              ),
          ],
        ),
        const SizedBox(height: 5),
        if (summaryOnly)
          Text(
            hasPartnerLane
                ? 'Filter the receipt board, keep the right report in focus, and route it without losing partner scope.'
                : 'Filter the receipt board, keep the right report in focus, and route it fast.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9CB2D1),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          )
        else
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _workspaceStatusAction(
                key: const ValueKey('reports-workspace-banner-filter-all'),
                label: 'All Receipts',
                selected: _receiptFilter == ReportReceiptSceneFilter.all,
                accent: const Color(0xFF8FD1FF),
                onTap: () =>
                    toggleReportReceiptFilter(ReportReceiptSceneFilter.all),
              ),
              _workspaceStatusAction(
                key: const ValueKey('reports-workspace-banner-filter-alerts'),
                label: 'Focus Alerts',
                selected: _receiptFilter == ReportReceiptSceneFilter.alerts,
                accent: const Color(0xFF60A5FA),
                onTap: () =>
                    toggleReportReceiptFilter(ReportReceiptSceneFilter.alerts),
              ),
              _workspaceStatusAction(
                key: const ValueKey(
                  'reports-workspace-banner-filter-scene-pending',
                ),
                label: 'Scene Pending',
                selected: _receiptFilter == ReportReceiptSceneFilter.pending,
                accent: const Color(0xFF59D79B),
                onTap: () =>
                    toggleReportReceiptFilter(ReportReceiptSceneFilter.pending),
              ),
              _workspaceStatusAction(
                key: const ValueKey('reports-workspace-banner-partner-focus'),
                label: _hasPartnerScopeFocus
                    ? 'Clear Partner Focus'
                    : 'Focus Top Partner',
                selected: _hasPartnerScopeFocus,
                accent: const Color(0xFF67E8F9),
                onTap: _hasPartnerScopeFocus
                    ? _clearPartnerScopeFocus
                    : hasPartnerLane
                    ? () {
                        final lane = _sitePartnerScoreboardRows.first;
                        _setPartnerScopeFocus(
                          clientId: lane.clientId,
                          siteId: lane.siteId,
                          partnerLabel: lane.partnerLabel,
                        );
                      }
                    : null,
              ),
              _workspaceStatusAction(
                key: const ValueKey('reports-workspace-banner-open-governance'),
                label: 'Governance Scope',
                selected: true,
                accent: const Color(0xFF22D3EE),
                onTap: _openGovernanceScopeAction(
                  clientId: widget.selectedClient,
                  siteId: widget.selectedSite,
                ),
              ),
              _workspaceStatusAction(
                key: const ValueKey('reports-workspace-banner-open-preview'),
                label: previewTargetReceipt != null
                    ? 'OPEN PREVIEW TARGET'
                    : activeReceipt != null
                    ? 'Open Active Receipt'
                    : 'Recover Receipt Board',
                selected: previewTargetReceipt != null || activeReceipt != null,
                accent: const Color(0xFF59D79B),
                onTap: previewTargetReceipt != null
                    ? () =>
                          _previewReceipt(previewTargetReceipt, hasLiveReceipts)
                    : activeReceipt != null
                    ? () => _previewReceipt(activeReceipt, hasLiveReceipts)
                    : reportRows.isEmpty
                    ? null
                    : () => _recoverReceiptWorkspace(
                        reportRows,
                        filter: ReportReceiptSceneFilter.all,
                      ),
              ),
            ],
          ),
      ],
    );
    if (shellless) {
      return KeyedSubtree(
        key: const ValueKey('reports-workspace-status-banner'),
        child: bannerContent,
      );
    }
    return Container(
      key: const ValueKey('reports-workspace-status-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1DCE8)),
      ),
      child: bannerContent,
    );
  }

  Widget _reportsWorkspaceCommandReceipt({bool shellless = false}) {
    final receipt = _commandReceipt;
    final titleColor = shellless ? receipt.accent : const Color(0xFF33506E);
    final labelColor = shellless ? _reportsTitleColor : const Color(0xFF10243A);
    final messageColor = shellless
        ? _reportsTitleColor
        : const Color(0xFF18304A);
    final detailColor = shellless ? _reportsBodyColor : const Color(0xFF5B7086);
    final receiptContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LAST MOVE',
          style: GoogleFonts.inter(
            color: titleColor,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          receipt.label,
          style: GoogleFonts.inter(
            color: labelColor,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          receipt.message,
          style: GoogleFonts.inter(
            color: messageColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          receipt.detail,
          style: GoogleFonts.inter(
            color: detailColor,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    if (shellless) {
      return KeyedSubtree(
        key: const ValueKey('reports-workspace-command-receipt'),
        child: receiptContent,
      );
    }
    return Container(
      key: const ValueKey('reports-workspace-command-receipt'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: receipt.accent.withValues(alpha: 0.24)),
      ),
      child: receiptContent,
    );
  }

  Widget _workspaceStatusAction({
    required Key key,
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: onTap == null
              ? const Color(0xFFE3EAF2)
              : selected
              ? accent.withValues(alpha: 0.18)
              : const Color(0xFFE9F1F8),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: onTap == null
                ? const Color(0xFFC7D5E3)
                : selected
                ? accent.withValues(alpha: 0.52)
                : const Color(0xFFC7D5E3),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: onTap == null
                ? const Color(0xFF7A8CA1)
                : selected
                ? accent
                : const Color(0xFF18304A),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _reportsWorkspaceCommandStrip({
    required List<_ReceiptRow> visibleReceipts,
    required int totalReceipts,
    required _ReceiptRow? activeReceipt,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: _reportsPanelColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _reportsBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECEIPT LANE',
            style: GoogleFonts.inter(
              color: const Color(0xFF8FD1FF),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _partnerScopeChip(
                label: '${visibleReceipts.length} of $totalReceipts visible',
                color: const Color(0xFF59D79B),
              ),
              _partnerScopeChip(
                label: _receiptFilter.viewingLabel,
                color: _receiptFilter.bannerBorderColor,
              ),
              if (activeReceipt != null)
                _partnerScopeChip(
                  label: 'Focused ${activeReceipt.event.eventId}',
                  color: const Color(0xFFF6C067),
                ),
            ],
          ),
          const SizedBox(height: 5),
          _reportsWorkspaceCommandActions(),
        ],
      ),
    );
  }

  Widget _reportsWorkspaceCommandActions() {
    final hasPartnerLane = _sitePartnerScoreboardRows.isNotEmpty;
    final partnerFocusLabel = _hasPartnerScopeFocus
        ? 'Clear Partner Focus'
        : 'Focus Top Partner';
    final partnerFocusAction = _hasPartnerScopeFocus
        ? _clearPartnerScopeFocus
        : hasPartnerLane
        ? () {
            final lane = _sitePartnerScoreboardRows.first;
            _setPartnerScopeFocus(
              clientId: lane.clientId,
              siteId: lane.siteId,
              partnerLabel: lane.partnerLabel,
            );
          }
        : null;
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        _workspaceQuickButton(
          key: const ValueKey('reports-workspace-filter-all'),
          label: 'All Receipts',
          onTap: () => toggleReportReceiptFilter(ReportReceiptSceneFilter.all),
        ),
        _workspaceQuickButton(
          key: const ValueKey('reports-workspace-filter-alerts'),
          label: 'Focus Alerts',
          onTap: () =>
              toggleReportReceiptFilter(ReportReceiptSceneFilter.alerts),
        ),
        _workspaceQuickButton(
          key: const ValueKey('reports-workspace-filter-scene-pending'),
          label: 'Scene Pending',
          onTap: () =>
              toggleReportReceiptFilter(ReportReceiptSceneFilter.pending),
        ),
        _workspaceQuickButton(
          key: const ValueKey('reports-workspace-partner-focus'),
          label: partnerFocusLabel,
          onTap: partnerFocusAction,
        ),
      ],
    );
  }

  Widget _reportsWorkspaceFocusBanner({
    required List<_ReceiptRow> reportRows,
    required _ReceiptRow? activeReceipt,
    required _ReceiptRow? previewTargetReceipt,
    required List<_ReceiptRow> visibleReceipts,
    required bool hasLiveReceipts,
    bool shellless = false,
  }) {
    final recoveryFilters = _receiptHistoryRecoveryFilters(reportRows);
    final sceneCount = activeReceipt?.sceneReviewSummary?.totalReviews ?? 0;
    final activeAccent = activeReceipt == null
        ? const Color(0xFF8FD1FF)
        : activeReceipt.replayVerified
        ? const Color(0xFF59D79B)
        : const Color(0xFFF6C067);
    final governanceAction = _openGovernanceScopeAction(
      clientId: widget.selectedClient,
      siteId: widget.selectedSite,
    );
    final activeAction = activeReceipt == null
        ? reportRows.isEmpty
              ? null
              : () => _recoverReceiptWorkspace(
                  reportRows,
                  filter: ReportReceiptSceneFilter.all,
                )
        : () => _previewReceipt(activeReceipt, hasLiveReceipts);
    final activeLabel = activeReceipt == null
        ? 'Recover Active Board'
        : 'Open Active Receipt';
    final recoveryHeadline = recoveryFilters.isEmpty
        ? '${reportRows.length} receipts remain in scope for this board.'
        : '${reportRows.length} receipts remain in scope outside ${_receiptFilter.label.toLowerCase()}. Pivot back into the full board or jump straight into ${recoveryFilters.first.label.toLowerCase()}.';
    final summaryOnly = shellless && activeReceipt != null;
    final focusContent = summaryOnly
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  _partnerScopeChip(
                    label: activeReceipt.event.eventId,
                    color: activeAccent,
                  ),
                  _partnerScopeChip(
                    label: activeReceipt.replayVerified
                        ? 'Verified'
                        : 'Pending',
                    color: activeReceipt.replayVerified
                        ? const Color(0xFF59D79B)
                        : const Color(0xFFF6C067),
                  ),
                  if (previewTargetReceipt != null)
                    _partnerScopeChip(
                      label: 'Preview ${previewTargetReceipt.event.eventId}',
                      color: const Color(0xFFF6C067),
                    ),
                  _partnerScopeChip(
                    label: 'Scenes: $sceneCount',
                    color: activeAccent,
                  ),
                  _partnerScopeChip(
                    label: 'Output: ${_outputMode.label}',
                    color: const Color(0xFFB9C6D8),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                previewTargetReceipt != null
                    ? 'Focused receipt ${activeReceipt.event.eventId} stays anchored to the selected board while preview target ${previewTargetReceipt.event.eventId} remains staged for ${_previewSurface.label.toLowerCase()} below.'
                    : 'Focused receipt ${activeReceipt.event.eventId} stays anchored to the selected board, while events handoff, receipt copy, and governance review stay pinned to the board and context surfaces below.',
                style: GoogleFonts.inter(
                  color: _reportsBodyColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: activeAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      activeReceipt == null
                          ? Icons.restore_rounded
                          : Icons.description_rounded,
                      color: activeAccent,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DO THIS NOW',
                          style: GoogleFonts.inter(
                            color: activeAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activeReceipt == null
                              ? 'GET A RECEIPT BACK'
                              : activeReceipt.event.eventId,
                          style: GoogleFonts.inter(
                            color: _reportsTitleColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            height: 0.95,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (activeReceipt != null)
                    _partnerScopeChip(
                      label: activeReceipt.replayVerified
                          ? 'Verified'
                          : 'Pending',
                      color: activeReceipt.replayVerified
                          ? const Color(0xFF59D79B)
                          : const Color(0xFFF6C067),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                activeReceipt == null
                    ? 'Receipt board recovery ready.'
                    : _receiptPolicyHistoryHeadline(activeReceipt.event),
                style: GoogleFonts.inter(
                  color: _reportsTitleColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  if (activeReceipt == null)
                    _partnerScopeChip(
                      label: '${reportRows.length} scoped',
                      color: _reportsAccentSky,
                    ),
                  if (previewTargetReceipt != null)
                    _partnerScopeChip(
                      label: 'Preview: ${previewTargetReceipt.event.eventId}',
                      color: const Color(0xFFF6C067),
                    ),
                  _partnerScopeChip(
                    label: 'Scenes: $sceneCount',
                    color: activeReceipt == null
                        ? const Color(0xFF59D79B)
                        : activeAccent,
                  ),
                  _partnerScopeChip(
                    label: 'Output: ${_outputMode.label}',
                    color: const Color(0xFFB9C6D8),
                  ),
                  if (activeReceipt == null)
                    _partnerScopeChip(
                      label: '${visibleReceipts.length} board rows',
                      color: const Color(0xFF8EA4C2),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                activeReceipt == null
                    ? recoveryHeadline
                    : previewTargetReceipt != null
                    ? 'Preview target ${previewTargetReceipt.event.eventId} is staged for ${_previewSurface.label.toLowerCase()} while ${activeReceipt.event.eventId} stays pinned for operator review.'
                    : 'Focused receipt ${activeReceipt.event.eventId} is ready for preview, events handoff, and governance review from this board.',
                style: GoogleFonts.inter(
                  color: _reportsBodyColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              if (activeReceipt == null)
                Wrap(
                  key: const ValueKey('reports-workspace-focus-recovery'),
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    _workspaceStatusAction(
                      key: const ValueKey(
                        'reports-workspace-focus-open-active',
                      ),
                      label: activeLabel,
                      selected: false,
                      accent: activeAction != null
                          ? const Color(0xFF59D79B)
                          : const Color(0xFF8EA4C2),
                      onTap: activeAction,
                    ),
                    _workspaceStatusAction(
                      key: const ValueKey(
                        'reports-workspace-focus-open-governance',
                      ),
                      label: 'Governance Scope',
                      selected: governanceAction != null,
                      accent: governanceAction != null
                          ? const Color(0xFF22D3EE)
                          : const Color(0xFF8EA4C2),
                      onTap: governanceAction,
                    ),
                    _workspaceStatusAction(
                      key: const ValueKey(
                        'reports-workspace-focus-recover-all',
                      ),
                      label: 'All Receipts',
                      selected: _receiptFilter == ReportReceiptSceneFilter.all,
                      accent: _reportsAccentSky,
                      onTap: reportRows.isEmpty
                          ? null
                          : () => _recoverReceiptWorkspace(
                              reportRows,
                              filter: ReportReceiptSceneFilter.all,
                            ),
                    ),
                    for (final filter in recoveryFilters.take(2))
                      _workspaceStatusAction(
                        key: ValueKey<String>(
                          'reports-workspace-focus-recover-${filter.name}',
                        ),
                        label: filter.label,
                        selected: _receiptFilter == filter,
                        accent: filter.bannerBorderColor,
                        onTap: () => _recoverReceiptWorkspace(
                          reportRows,
                          filter: filter,
                        ),
                      ),
                  ],
                )
              else
                Text(
                  previewTargetReceipt != null
                      ? 'Events handoff, receipt copy, and staged preview target stay pinned in the context rail and preview target surfaces below.'
                      : 'Events handoff and receipt copy stay pinned in the context rail, while governance and active-board pivots stay anchored to the selected receipt board.',
                  style: GoogleFonts.inter(
                    color: _reportsMutedColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
            ],
          );
    if (shellless) {
      return KeyedSubtree(
        key: const ValueKey('reports-workspace-focus-card'),
        child: focusContent,
      );
    }
    return Container(
      key: const ValueKey('reports-workspace-focus-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            activeAccent.withValues(alpha: 0.16),
            const Color(0xFFF2F6FB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: activeAccent.withValues(alpha: 0.28)),
      ),
      child: focusContent,
    );
  }

  Widget _reportsWorkspaceContextSnapshot({
    required List<_ReceiptRow> reportRows,
    required _ReceiptRow? activeReceipt,
    required _ReceiptRow? previewTargetReceipt,
    required bool hasLiveReceipts,
    bool includeCommandReceipt = false,
    bool summaryOnly = false,
    bool shellless = false,
  }) {
    final governanceAction = _openGovernanceScopeAction(
      clientId: widget.selectedClient,
      siteId: widget.selectedSite,
    );
    final recoveryFilters = _receiptHistoryRecoveryFilters(reportRows);
    final activeAction = activeReceipt == null
        ? reportRows.isEmpty
              ? null
              : () => _recoverReceiptWorkspace(
                  reportRows,
                  filter: ReportReceiptSceneFilter.all,
                )
        : () => _previewReceipt(activeReceipt, hasLiveReceipts);
    final contextContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (includeCommandReceipt) ...[
          _reportsWorkspaceCommandReceipt(shellless: true),
          const SizedBox(height: 5),
        ],
        Text(
          'HANDOFF SNAPSHOT',
          style: GoogleFonts.inter(
            color: const Color(0xFF8FD1FF),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            _partnerScopeChip(
              label: _previewSurface.label,
              color: const Color(0xFF59D79B),
            ),
            _partnerScopeChip(
              label:
                  _partnerComparisonWindow ==
                      ReportPartnerComparisonWindow.latestShift
                  ? 'Latest shift'
                  : '3-shift baseline',
              color: const Color(0xFFF6C067),
            ),
            if (_hasPartnerScopeFocus)
              _partnerScopeChip(
                label: 'Partner scope active',
                color: const Color(0xFF59D79B),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          previewTargetReceipt != null
              ? 'Preview target ${previewTargetReceipt.event.eventId} is staged and ready to open.'
              : activeReceipt != null
              ? 'Focused receipt ${activeReceipt.event.eventId} is ready for preview and governance handoff.'
              : recoveryFilters.isEmpty
              ? '${reportRows.length} scoped receipts remain available on this receipt board.'
              : '${reportRows.length} scoped receipts remain outside ${_receiptFilter.label.toLowerCase()}. Reopen the board or pivot into ${recoveryFilters.first.label.toLowerCase()}.',
          style: GoogleFonts.inter(
            color: const Color(0xFF9CB2D1),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 5),
        if (!summaryOnly || activeReceipt == null)
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _workspaceQuickButton(
                key: const ValueKey('reports-workspace-open-governance'),
                label: 'OPEN GOVERNANCE DESK',
                onTap: governanceAction,
              ),
              _workspaceQuickButton(
                key: const ValueKey('reports-workspace-open-active'),
                label: activeReceipt == null
                    ? 'Recover Active Board'
                    : 'Open Active Receipt',
                onTap: activeAction,
              ),
              _workspaceQuickButton(
                key: const ValueKey('reports-workspace-open-preview-target'),
                label: 'OPEN PREVIEW TARGET',
                onTap: previewTargetReceipt == null
                    ? null
                    : () => _previewReceipt(
                        previewTargetReceipt,
                        hasLiveReceipts,
                      ),
              ),
            ],
          )
        else
          Text(
            previewTargetReceipt != null
                ? 'Governance Desk stays pinned in the page header, while the selected receipt and staged target stay anchored to the board and preview surfaces below.'
                : 'Governance Desk stays pinned in the page header, while selected receipt review stays anchored to the board and preview surfaces below.',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
      ],
    );
    if (shellless) {
      return KeyedSubtree(
        key: const ValueKey('reports-workspace-context-snapshot'),
        child: contextContent,
      );
    }
    return Container(
      key: const ValueKey('reports-workspace-context-snapshot'),
      width: double.infinity,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1DCE8)),
      ),
      child: contextContent,
    );
  }

  Widget _workspaceQuickButton({
    required Key key,
    required String label,
    required VoidCallback? onTap,
  }) {
    return FilledButton(
      key: key,
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF28527D),
        side: const BorderSide(color: Color(0xFF8EC8FF)),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(0xFFEAF3FF),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _heroHeader({
    required int totalReceipts,
    required int verifiedCount,
    required int pendingCount,
    required int reviewedCount,
    required int pendingSceneCount,
    Widget? workspaceBanner,
  }) {
    final governanceAction = _openGovernanceScopeAction(
      clientId: widget.selectedClient,
      siteId: widget.selectedSite,
    );
    return OnyxStoryHero(
      eyebrow: 'WAR ROOM',
      title: 'Reports & Documentation',
      subtitle: 'Pick the right receipt, preview it, and move it out cleanly.',
      icon: Icons.description_rounded,
      gradientColors: const [_reportsPanelAltColor, _reportsPanelTintColor],
      metrics: [
        OnyxStoryMetric(
          value: widget.selectedClient,
          label: 'client',
          foreground: const Color(0xFF8FD1FF),
          background: const Color(0x1A8FD1FF),
          border: const Color(0x668FD1FF),
        ),
        OnyxStoryMetric(
          value: widget.selectedSite,
          label: 'site',
          foreground: const Color(0xFFCCFBF1),
          background: const Color(0x1A14B8A6),
          border: const Color(0x6614B8A6),
        ),
        OnyxStoryMetric(
          value: '$pendingCount',
          label: 'building',
          foreground: pendingCount > 0
              ? const Color(0xFF7DD3FC)
              : const Color(0xFF9AB1CF),
          background: pendingCount > 0
              ? const Color(0x1438BDF8)
              : const Color(0x1494A3B8),
          border: pendingCount > 0
              ? const Color(0x6638BDF8)
              : const Color(0x6694A3B8),
        ),
        OnyxStoryMetric(
          value: '$verifiedCount',
          label: 'verified',
          foreground: const Color(0xFF59D79B),
          background: const Color(0x1A59D79B),
          border: const Color(0x6659D79B),
        ),
        OnyxStoryMetric(
          value: '${reviewedCount + pendingSceneCount}',
          label: 'review desk',
          foreground: const Color(0xFF172638),
          background: const Color(0xFFF5F8FC),
          border: const Color(0xFFD4DFEA),
        ),
        OnyxStoryMetric(
          value: '$totalReceipts',
          label: 'reports',
          foreground: const Color(0xFF172638),
          background: const Color(0xFFF5F8FC),
          border: const Color(0xFFD4DFEA),
        ),
      ],
      actions: [
        _heroActionButton(
          key: const ValueKey('reports-routed-view-governance-button'),
          icon: Icons.open_in_new,
          label: 'OPEN GOVERNANCE DESK',
          accent: const Color(0xFF93C5FD),
          onPressed: governanceAction,
        ),
        _heroActionButton(
          key: const ValueKey('reports-routed-generate-button'),
          icon: Icons.picture_as_pdf_rounded,
          label: _isGenerating ? 'Generating...' : 'Generate New Report',
          accent: const Color(0xFF59D79B),
          onPressed: _isGenerating ? null : _generateReport,
        ),
      ],
      banner: workspaceBanner,
    );
  }

  Widget _heroActionButton({
    required Key key,
    required IconData icon,
    required String label,
    required Color accent,
    required VoidCallback? onPressed,
  }) {
    return FilledButton.tonalIcon(
      key: key,
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: accent.withValues(alpha: 0.12),
        foregroundColor: accent,
        disabledBackgroundColor: const Color(0xFFF0F5FB),
        disabledForegroundColor: const Color(0x667A8CA8),
        side: BorderSide(color: accent.withValues(alpha: 0.28)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        textStyle: GoogleFonts.inter(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _reportWorkbenchSurface({
    required List<_ReceiptRow> visibleReceipts,
    required int totalReceipts,
    required bool hasLiveReceipts,
    required _ReceiptRow? activeReceipt,
    bool includeWorkspaceControls = false,
    bool shellless = false,
  }) {
    final workbenchBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (includeWorkspaceControls) ...[
          _reportsWorkspaceCommandActions(),
          const SizedBox(height: 6),
        ],
        Text(
          '${visibleReceipts.length} visible receipt${visibleReceipts.length == 1 ? '' : 's'} of $totalReceipts total',
          style: GoogleFonts.inter(
            color: _reportsMutedColor,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (includeWorkspaceControls && activeReceipt != null) ...[
          const SizedBox(height: 4),
          Text(
            'Focused receipt ${activeReceipt.event.eventId} stays pinned in the selected board while this rail keeps lane filters and receipt history together.',
            style: GoogleFonts.inter(
              color: _reportsBodyColor,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 6),
        if (_previewReceiptEventId != null) ...[
          _previewTargetBanner(
            eventId: _previewReceiptEventId!,
            row: _targetReceiptByEventId(
              hasLiveReceipts ? _receipts : _sampleReceipts,
              _previewReceiptEventId,
            ),
            hasLiveReceipts: hasLiveReceipts,
          ),
          const SizedBox(height: 8),
        ],
        _buildReceiptHistory(),
      ],
    );
    if (shellless) {
      return workbenchBody;
    }
    return OnyxSectionCard(
      title: 'REPORT WORKBENCH',
      subtitle: _receiptHistorySubtitle,
      child: workbenchBody,
    );
  }

  Widget _selectedReportSurface({
    required _ReceiptRow? row,
    required bool hasLiveReceipts,
    bool shellless = false,
  }) {
    if (row == null) {
      final rows = hasLiveReceipts ? _receipts : _sampleReceipts;
      final recoverySurface = _selectedReportRecoverySurface(
        rows: rows,
        hasLiveReceipts: hasLiveReceipts,
      );
      if (shellless) {
        return recoverySurface;
      }
      return OnyxSectionCard(
        title: 'SELECTED REPORT',
        subtitle: 'Focused receipt preview and verification',
        child: recoverySurface,
      );
    }
    final sceneSummary = row.sceneReviewSummary;
    final sceneCount = sceneSummary?.totalReviews ?? 0;
    final period = _periodFromMonth(row.event.month);
    final generatedAt = _formatUtc(row.event.occurredAt);
    final sectionSummary = _receiptSectionConfigurationSummary(row.event);
    final previewSummary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _receiptSceneReviewPill(
              row.replayVerified ? 'Replay Verified' : 'Replay Pending',
              row.replayVerified
                  ? const Color(0xFF59D79B)
                  : const Color(0xFFF6C067),
            ),
            _receiptSceneReviewPill(
              _receiptBrandingLabel(row.event),
              _receiptBrandingAccent(row.event),
            ),
            _receiptSceneReviewPill(
              sectionSummary,
              _receiptSectionConfigurationAccent(row.event),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _receiptBrandingSummary(row.event),
          style: GoogleFonts.inter(
            color: _reportsBodyColor,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
      ],
    );
    final reportBody = Column(
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
                    _receiptPolicyHistoryHeadline(row.event),
                    style: GoogleFonts.inter(
                      color: _reportsTitleColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Generated $generatedAt',
                    style: GoogleFonts.inter(
                      color: _reportsMutedColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _pillActionButton(
              label: row.replayVerified ? 'Verified' : 'Verify Report',
              icon: row.replayVerified
                  ? Icons.verified_rounded
                  : Icons.pending_actions_rounded,
              buttonKey: const ValueKey('reports-selected-verify-button'),
              filled: row.replayVerified,
              onTap: _isRefreshing ? null : _loadReceipts,
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 780;
            final cards = [
              _selectedReportMetric('LINKED EVENTS', '${row.event.eventCount}'),
              _selectedReportMetric('SCENE REVIEWS', '$sceneCount'),
              _selectedReportMetric('OUTPUT MODE', _outputMode.label),
            ];
            if (compact) {
              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    cards[i],
                    if (i < cards.length - 1) const SizedBox(height: 6),
                  ],
                ],
              );
            }
            return Row(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  Expanded(child: cards[i]),
                  if (i < cards.length - 1) const SizedBox(width: 6),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        if (_desktopWorkspaceActive)
          previewSummary
        else
          OnyxSectionCard(
            title: 'REPORT PREVIEW',
            subtitle: 'Section completion status and current delivery shape',
            child: previewSummary,
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _pillActionButton(
                label: 'OPEN PREVIEW TARGET',
                icon: Icons.visibility_rounded,
                buttonKey: const ValueKey('reports-selected-preview-button'),
                onTap: () => _previewReceipt(row, hasLiveReceipts),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _pillActionButton(
                label: 'Copy Receipt',
                icon: Icons.copy_all_rounded,
                buttonKey: const ValueKey('reports-selected-copy-button'),
                onTap: () => _copyReceipt(row),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _pillActionButton(
                label: 'Download Receipt',
                icon: Icons.download_rounded,
                buttonKey: const ValueKey('reports-selected-download-button'),
                filled: true,
                onTap: () => _downloadReceipt(row, hasLiveReceipts),
              ),
            ),
          ],
        ),
      ],
    );
    if (shellless) {
      return reportBody;
    }
    return OnyxSectionCard(
      title: 'Morning Sovereign Report • $period',
      subtitle:
          '${_humanizeClient(row.event.clientId)} • ${_humanizeSite(row.event.siteId)}',
      child: reportBody,
    );
  }

  Widget _selectedReportRecoverySurface({
    required List<_ReceiptRow> rows,
    required bool hasLiveReceipts,
  }) {
    final recoveryFilters = _receiptHistoryRecoveryFilters(rows);
    final availableCount = rows.length;
    final receiptLabel =
        '${hasLiveReceipts ? 'live' : 'sample'} receipt${availableCount == 1 ? '' : 's'}';
    final leadRecoveryFilter = recoveryFilters.isEmpty
        ? null
        : recoveryFilters.first.label.toLowerCase();
    final detail = rows.isEmpty
        ? 'Generate a receipt to reopen the preview workspace and restore the delivery handoff.'
        : leadRecoveryFilter == null
        ? '$availableCount $receiptLabel are still staged in this Reports Workspace. Reopen the full history stream to restore the preview workspace.'
        : '$availableCount $receiptLabel are still staged in this Reports Workspace. Reopen the full history stream or pivot straight into $leadRecoveryFilter to restore the preview workspace.';

    return Container(
      key: const ValueKey('reports-selected-recovery-surface'),
      width: double.infinity,
      padding: const EdgeInsets.all(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No Receipt Selected',
            style: GoogleFonts.inter(
              color: _reportsTitleColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: _reportsBodyColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 780;
              final cards = [
                _selectedReportMetric('VISIBLE', '0'),
                _selectedReportMetric('SCOPED RECEIPTS', '$availableCount'),
                _selectedReportMetric('FILTER', _receiptFilter.label),
              ];
              if (compact) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      cards[i],
                      if (i < cards.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                );
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
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('reports-selected-recovery-open-all'),
                onPressed: rows.isEmpty
                    ? null
                    : () =>
                          setReportReceiptFilter(ReportReceiptSceneFilter.all),
                icon: const Icon(Icons.reorder_rounded, size: 18),
                label: const Text('All Receipts'),
              ),
              for (final filter in recoveryFilters.take(2))
                OutlinedButton.icon(
                  key: ValueKey<String>(
                    'reports-selected-recovery-open-${filter.name}',
                  ),
                  onPressed: () => setReportReceiptFilter(filter),
                  icon: Icon(_receiptFilterIcon(filter), size: 18),
                  label: Text(filter.label),
                ),
              FilledButton.icon(
                key: const ValueKey('reports-selected-recovery-generate'),
                onPressed: _isGenerating ? null : _generateReport,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: Text(
                  _isGenerating ? 'Generating...' : 'Generate New Report',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _selectedReportMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _reportsPanelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _reportsBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: _reportsMutedColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              color: _reportsTitleColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportPreviewSurface({
    required _ReceiptRow? previewTargetReceipt,
    required _ReceiptRow? activeReceipt,
    required bool hasLiveReceipts,
    bool shellless = false,
  }) {
    final summaryOnly = shellless;
    final previewBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_previewSurface == ReportPreviewSurface.dock &&
            previewTargetReceipt != null) ...[
          _previewDock(
            row: previewTargetReceipt,
            hasLiveReceipts: hasLiveReceipts,
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (!summaryOnly)
              _actionButton(
                key: const ValueKey('reports-related-governance-button'),
                label: 'OPEN GOVERNANCE DESK',
                icon: Icons.open_in_new_rounded,
                onTap: _openGovernanceScopeAction(
                  clientId: widget.selectedClient,
                  siteId: widget.selectedSite,
                ),
              ),
            _actionButton(
              key: const ValueKey('reports-related-events-button'),
              label: 'OPEN EVENTS SCOPE',
              icon: Icons.rule_folder_rounded,
              onTap: activeReceipt == null
                  ? null
                  : () => _openEventsForReceiptPolicyRow(activeReceipt),
            ),
            if (!summaryOnly)
              _actionButton(
                key: const ValueKey('reports-related-generate-button'),
                label: _isGenerating ? 'Generating...' : 'Preview Report',
                icon: Icons.picture_as_pdf_rounded,
                onTap: _isGenerating ? null : _generateReport,
              ),
            if (!summaryOnly)
              _actionButton(
                key: const ValueKey('reports-related-refresh-button'),
                label: _isRefreshing
                    ? 'Refreshing...'
                    : 'Refresh Replay Verification',
                icon: Icons.verified_rounded,
                onTap: _isRefreshing ? null : _loadReceipts,
              ),
            if (!summaryOnly)
              _actionButton(
                key: const ValueKey('reports-review-copy-button'),
                label: 'Copy Receipt',
                icon: Icons.copy_all_rounded,
                onTap: activeReceipt == null
                    ? null
                    : () => _copyReceipt(activeReceipt),
              ),
          ],
        ),
        if (summaryOnly) ...[
          const SizedBox(height: 6),
          Text(
            'Governance Desk and Reports Workspace delivery stay pinned in the page header, while verification and receipt copy stay anchored to the selected board below.',
            style: GoogleFonts.inter(
              color: _reportsMutedColor,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
    if (shellless) {
      return previewBody;
    }
    return OnyxSectionCard(
      title: 'RELATED VIEWS',
      subtitle: 'Preview routing, governance handoff, and operational controls',
      child: previewBody,
    );
  }

  Widget _reportOperationsSurface({
    required _ReceiptRow? activeReceipt,
    required bool hasLiveReceipts,
    bool shellless = false,
  }) {
    final summaryOnly = shellless && activeReceipt != null;
    final operationsBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDeterministicControls(),
        const SizedBox(height: 8),
        if (_currentBrandingConfiguration.isConfigured)
          Container(
            key: const ValueKey('reports-branding-summary-card'),
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _reportsPanelAltColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _reportsBorderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Client-facing branding',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8FD1FF),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _currentBrandingConfiguration.primaryLabel,
                  style: GoogleFonts.inter(
                    color: _reportsTitleColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_currentBrandingConfiguration.endorsementLine
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _currentBrandingConfiguration.endorsementLine,
                    style: GoogleFonts.inter(
                      color: _reportsBodyColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _actionButton(
                      key: const ValueKey('reports-branding-edit-button'),
                      label: 'Edit Branding',
                      icon: Icons.edit_rounded,
                      onTap: _editBrandingOverrides,
                    ),
                    if (_hasBrandingOverride)
                      _actionButton(
                        key: const ValueKey('reports-branding-reset-button'),
                        label: 'Reset Branding',
                        icon: Icons.restore_rounded,
                        onTap: _resetBrandingOverrides,
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (_currentBrandingConfiguration.isConfigured)
          const SizedBox(height: 8),
        Text(
          'SECTION CONFIGURATION',
          style: GoogleFonts.inter(
            color: const Color(0xFF7F92AE),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        _toggle(
          label: 'Include incident timeline',
          value: _includeTimeline,
          onChanged: (value) =>
              setReportSectionConfiguration(includeTimeline: value),
        ),
        _toggle(
          label: 'Include dispatch summary',
          value: _includeDispatchSummary,
          onChanged: (value) =>
              setReportSectionConfiguration(includeDispatchSummary: value),
        ),
        _toggle(
          label: 'Include checkpoint compliance',
          value: _includeCheckpointCompliance,
          onChanged: (value) =>
              setReportSectionConfiguration(includeCheckpointCompliance: value),
        ),
        _toggle(
          label: 'Include AI decision log',
          value: _includeAiDecisionLog,
          onChanged: (value) =>
              setReportSectionConfiguration(includeAiDecisionLog: value),
        ),
        _toggle(
          label: 'Include guard performance metrics',
          value: _includeGuardMetrics,
          onChanged: (value) =>
              setReportSectionConfiguration(includeGuardMetrics: value),
        ),
        if (activeReceipt != null && !summaryOnly) ...[
          const SizedBox(height: 10),
          _generationLane(
            color: const Color(0xFF59D79B),
            icon: Icons.visibility_rounded,
            title: 'Selected Receipt',
            detail: _receiptPolicyHistoryHeadline(activeReceipt.event),
            status: activeReceipt.replayVerified ? 'VERIFIED' : 'PENDING',
            actionText: 'Open Preview',
            onTap: () => _previewReceipt(activeReceipt, hasLiveReceipts),
            secondaryActionText: 'Copy Receipt',
            onSecondaryTap: () => _copyReceipt(activeReceipt),
            secondaryButtonKey: const ValueKey('reports-selected-copy-inline'),
          ),
        ] else if (summaryOnly) ...[
          const SizedBox(height: 10),
          Text(
            'Selected receipt preview and copy stay anchored to the focused board, while this rail keeps generation scope, branding, and preview surface controls together.',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
    if (shellless) {
      return operationsBody;
    }
    return OnyxSectionCard(
      title: 'DELIVERY CONTROLS',
      subtitle: 'Generation scope, output mode, preview surface, and branding',
      child: operationsBody,
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
    final siteActivity = _siteActivitySnapshot(
      clientId: _partnerScopeClientId,
      siteId: _partnerScopeSiteId,
      reportDate: latestPoint?.reportDate,
    );
    final openReceiptLaneAction = receiptRows.isEmpty
        ? null
        : () {
            setReportReceiptFilter(ReportReceiptSceneFilter.all);
            focusReportReceiptWorkspace(receiptRows.first.event.eventId);
            _showReceiptActionFeedback(
              'Recovered pending partner scorecard scope around ${receiptRows.first.event.eventId}.',
            );
          };
    final genericGovernanceAction = _openGovernanceScopeAction(
      clientId: _partnerScopeClientId!,
      siteId: _partnerScopeSiteId!,
    );
    final openGovernanceAction = widget.onOpenGovernanceForPartnerScope != null
        ? () {
            widget.onOpenGovernanceForPartnerScope!(
              _partnerScopeClientId!,
              _partnerScopeSiteId!,
              _partnerScopePartnerLabel!,
            );
            _showReceiptActionFeedback(
              'Opening Governance for ${_partnerScopeSiteId!} • ${_partnerScopePartnerLabel!}.',
            );
          }
        : genericGovernanceAction == null
        ? null
        : () {
            genericGovernanceAction();
            _showReceiptActionFeedback(
              'Opening Governance for ${_partnerScopeSiteId!}.',
            );
          };
    final receiptInvestigationTrendLabel = _receiptInvestigationTrendLabel(
      receiptRows,
    );
    final receiptInvestigationComparison = _receiptInvestigationComparison(
      receiptRows,
    );
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
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD6E1EC)),
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
                    color: const Color(0xFF172638),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  latestPoint?.row.summaryLine ??
                      'Morning partner scorecard sync pending for this scope.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF556B80),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (latestPoint == null) ...[
                  const SizedBox(height: 10),
                  _partnerScopePendingRecoveryCard(
                    hasScopedReceipts: receiptRows.isNotEmpty,
                    activitySignals: siteActivity.totalSignals,
                    canOpenGovernance: openGovernanceAction != null,
                    onOpenReceiptLane: openReceiptLaneAction,
                    onOpenActivityTruth: _openPartnerScopeActivityTruth,
                    onOpenGovernance: openGovernanceAction,
                    onClearFocus: _clearPartnerScopeFocus,
                  ),
                ],
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
                if (siteActivity.totalSignals > 0) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _partnerScopeChip(
                        label: 'Site Activity',
                        color: const Color(0xFF59D79B),
                      ),
                      _partnerScopeChip(
                        label: '${siteActivity.totalSignals} signals',
                        color: const Color(0xFF8FD1FF),
                      ),
                      if (siteActivity.vehicleSignals > 0)
                        _partnerScopeChip(
                          label: '${siteActivity.vehicleSignals} vehicles',
                          color: const Color(0xFFF6C067),
                        ),
                      if (siteActivity.personSignals > 0)
                        _partnerScopeChip(
                          label: '${siteActivity.personSignals} people',
                          color: const Color(0xFF8EA4C2),
                        ),
                      if (siteActivity.knownIdentitySignals > 0)
                        _partnerScopeChip(
                          label:
                              '${siteActivity.knownIdentitySignals} known IDs',
                          color: const Color(0xFF5DC8FF),
                        ),
                      if (siteActivity.flaggedIdentitySignals > 0)
                        _partnerScopeChip(
                          label:
                              '${siteActivity.flaggedIdentitySignals} flagged',
                          color: const Color(0xFFFF7A7A),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    siteActivity.summaryLine,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9CB2D1),
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
                key: const ValueKey('reports-partner-scorecard-open-activity'),
                label: 'OPEN ACTIVITY TRUTH DESK',
                icon: Icons.groups_rounded,
                onTap: _openPartnerScopeActivityTruth,
              ),
              _actionButton(
                key: const ValueKey('reports-partner-scorecard-open-drill-in'),
                label: 'OPEN PARTNER DRILL-IN',
                icon: Icons.manage_search_rounded,
                onTap: _openPartnerScopeDrillIn,
              ),
              _actionButton(
                key: const ValueKey('reports-partner-scorecard-clear-focus'),
                label: 'Clear Focus',
                icon: Icons.filter_alt_off_rounded,
                onTap: _clearPartnerScopeFocus,
              ),
              if (openGovernanceAction != null)
                _actionButton(
                  key: const ValueKey(
                    'reports-partner-scorecard-open-governance',
                  ),
                  label: 'OPEN GOVERNANCE DESK',
                  icon: Icons.verified_user_rounded,
                  onTap: openGovernanceAction,
                ),
              if (widget.onOpenEventsForScope != null &&
                  currentChains.isNotEmpty)
                _actionButton(
                  key: const ValueKey('reports-partner-scorecard-open-events'),
                  label: 'OPEN EVENTS SCOPE',
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
                color: const Color(0xFF172638),
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
                color: const Color(0xFF172638),
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
    final rows = _sitePartnerScoreboardRows;
    final comparisons = _sitePartnerComparisonRows;
    _PartnerComparisonRow? leaderComparison;
    for (final comparison in comparisons) {
      if (comparison.isLeader) {
        leaderComparison = comparison;
        break;
      }
    }
    final recoveryComparison = comparisons
        .where((comparison) => comparison.historyPoints.length <= 1)
        .cast<_PartnerComparisonRow?>()
        .firstWhere((comparison) => comparison != null, orElse: () => null);
    final activeLane = rows
        .cast<SovereignReportPartnerScoreboardRow?>()
        .firstWhere(
          (row) => row != null && _partnerScoreboardMatchesFocus(row),
          orElse: () => null,
        );
    final receiptRows = _siteScopeReceiptRows();
    final siteActivity = _siteActivitySnapshot(
      clientId: widget.selectedClient,
      siteId: widget.selectedSite,
    );
    final openGovernanceScopeAction = _openGovernanceScopeAction(
      clientId: widget.selectedClient,
      siteId: widget.selectedSite,
    );
    return OnyxSectionCard(
      title: 'Partner Scorecard Lanes',
      subtitle:
          'Enter a responder scorecard focus directly from Reports for this client and site.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _partnerLaneCommandBanner(
            leaderComparison: leaderComparison,
            recoveryComparison: recoveryComparison,
            activeLane: activeLane,
            laneCount: rows.length,
            receiptCount: receiptRows.length,
            activitySignals: siteActivity.totalSignals,
            canOpenGovernance: openGovernanceScopeAction != null,
            onFocusLeader:
                leaderComparison == null ||
                    _partnerScoreboardMatchesFocus(leaderComparison.row)
                ? null
                : () => _setPartnerScopeFocus(
                    clientId: leaderComparison!.row.clientId,
                    siteId: leaderComparison.row.siteId,
                    partnerLabel: leaderComparison.row.partnerLabel,
                  ),
            onFocusRecovery:
                recoveryComparison == null ||
                    _partnerScoreboardMatchesFocus(recoveryComparison.row) ||
                    (leaderComparison != null &&
                        recoveryComparison.row.partnerLabel ==
                            leaderComparison.row.partnerLabel)
                ? null
                : () => _setPartnerScopeFocus(
                    clientId: recoveryComparison.row.clientId,
                    siteId: recoveryComparison.row.siteId,
                    partnerLabel: recoveryComparison.row.partnerLabel,
                  ),
            onOpenReceiptLane: receiptRows.isEmpty
                ? null
                : () {
                    setReportReceiptFilter(ReportReceiptSceneFilter.all);
                    focusReportReceiptWorkspace(
                      receiptRows.first.event.eventId,
                    );
                    _showReceiptActionFeedback(
                      'Recovered scorecard lanes around ${receiptRows.first.event.eventId}.',
                    );
                  },
            onOpenActivityTruth: () => _openSiteActivityTruth(
              clientId: widget.selectedClient,
              siteId: widget.selectedSite,
            ),
            onOpenGovernance: openGovernanceScopeAction == null
                ? null
                : () {
                    openGovernanceScopeAction();
                    _showReceiptActionFeedback(
                      'Opening Governance for scorecard lanes ${widget.selectedSite}.',
                    );
                  },
            onClearFocus: activeLane == null ? null : _clearPartnerScopeFocus,
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < rows.length; index++) ...[
            _partnerScorecardLaneRow(rows[index]),
            if (index < rows.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _partnerLaneCommandBanner({
    required _PartnerComparisonRow? leaderComparison,
    required _PartnerComparisonRow? recoveryComparison,
    required SovereignReportPartnerScoreboardRow? activeLane,
    required int laneCount,
    required int receiptCount,
    required int activitySignals,
    required bool canOpenGovernance,
    required VoidCallback? onFocusLeader,
    required VoidCallback? onFocusRecovery,
    required VoidCallback? onOpenReceiptLane,
    required VoidCallback onOpenActivityTruth,
    required VoidCallback? onOpenGovernance,
    required VoidCallback? onClearFocus,
  }) {
    final pendingCount = recoveryComparison == null
        ? 0
        : recoveryComparison.historyPoints.isEmpty
        ? 1
        : 0;
    final formingCount = recoveryComparison == null
        ? 0
        : recoveryComparison.historyPoints.length == 1
        ? 1
        : 0;
    final detail = activeLane != null
        ? 'The lane rail is anchored on ${activeLane.partnerLabel}. Recover receipts, pivot into activity truth, or clear focus without leaving the scorecard rail.'
        : pendingCount > 0
        ? 'A responder lane is already visible before its first scored shift lands. Focus that lane, recover the receipt rail, or open activity truth while the scorecard settles in.'
        : formingCount > 0
        ? 'A responder lane is still building its baseline from one scored shift. Focus it directly or recover the adjacent operator rails while the baseline matures.'
        : 'The lane rail is fully live. Focus the leader, recover receipts, or pivot into activity truth and governance from the same command surface.';

    return Container(
      key: const ValueKey('reports-partner-lanes-command-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _reportsPanelColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _reportsBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _partnerScopeChip(
                label: 'SCORECARD COMMAND',
                color: _reportsAccentSky,
              ),
              _partnerScopeChip(
                label: '$laneCount lane${laneCount == 1 ? '' : 's'}',
                color: const Color(0xFF5DC8FF),
              ),
              if (leaderComparison != null)
                _partnerScopeChip(
                  label: 'Leader: ${leaderComparison.row.partnerLabel}',
                  color: const Color(0xFF59D79B),
                ),
              if (activeLane != null)
                _partnerScopeChip(
                  label: 'Active: ${activeLane.partnerLabel}',
                  color: const Color(0xFF59D79B),
                )
              else if (pendingCount > 0)
                _partnerScopeChip(
                  label: '$pendingCount pending',
                  color: const Color(0xFFF6C067),
                )
              else if (formingCount > 0)
                _partnerScopeChip(
                  label: '$formingCount forming',
                  color: _reportsAccentSky,
                ),
              if (receiptCount > 0)
                _partnerScopeChip(
                  label: '$receiptCount receipts',
                  color: const Color(0xFF5DC8FF),
                ),
              _partnerScopeChip(
                label: activitySignals > 0
                    ? '$activitySignals live signals'
                    : 'Activity truth ready',
                color: activitySignals > 0
                    ? const Color(0xFF59D79B)
                    : const Color(0xFF8EA4C2),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: const Color(0xFF556B80),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onFocusLeader != null)
                _actionButton(
                  key: const ValueKey(
                    'reports-partner-lanes-command-focus-leader',
                  ),
                  label: 'Focus Leader Lane',
                  icon: Icons.workspace_premium_rounded,
                  onTap: onFocusLeader,
                ),
              if (onFocusRecovery != null)
                _actionButton(
                  key: const ValueKey(
                    'reports-partner-lanes-command-focus-recovery',
                  ),
                  label: pendingCount > 0
                      ? 'Focus Pending Lane'
                      : 'Focus Forming Lane',
                  icon: Icons.filter_center_focus_rounded,
                  onTap: onFocusRecovery,
                ),
              if (onOpenReceiptLane != null)
                _actionButton(
                  key: const ValueKey(
                    'reports-partner-lanes-command-open-receipts',
                  ),
                  label: 'Open Receipt Board',
                  icon: Icons.receipt_long_rounded,
                  onTap: onOpenReceiptLane,
                ),
              _actionButton(
                key: const ValueKey(
                  'reports-partner-lanes-command-open-activity',
                ),
                label: 'OPEN ACTIVITY TRUTH DESK',
                icon: Icons.groups_rounded,
                onTap: onOpenActivityTruth,
              ),
              if (canOpenGovernance)
                _actionButton(
                  key: const ValueKey(
                    'reports-partner-lanes-command-open-governance',
                  ),
                  label: 'OPEN GOVERNANCE DESK',
                  icon: Icons.verified_user_rounded,
                  onTap: onOpenGovernance,
                ),
              if (onClearFocus != null)
                _actionButton(
                  key: const ValueKey(
                    'reports-partner-lanes-command-clear-focus',
                  ),
                  label: 'Clear Focus',
                  icon: Icons.filter_alt_off_rounded,
                  onTap: onClearFocus,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _partnerComparisonCard() {
    final comparisons = _sitePartnerComparisonRows;
    final receiptRows = _siteScopeReceiptRows();
    final siteActivity = _siteActivitySnapshot(
      clientId: widget.selectedClient,
      siteId: widget.selectedSite,
    );
    _PartnerComparisonRow? leaderComparison;
    for (final comparison in comparisons) {
      if (comparison.isLeader) {
        leaderComparison = comparison;
        break;
      }
    }
    final thinComparisons = comparisons
        .where((comparison) => comparison.historyPoints.length <= 1)
        .toList(growable: false);
    final pendingComparisons = thinComparisons
        .where((comparison) => comparison.historyPoints.isEmpty)
        .toList(growable: false);
    final formingComparisons = thinComparisons
        .where((comparison) => comparison.historyPoints.length == 1)
        .toList(growable: false);
    final recoveryComparison = thinComparisons.isEmpty
        ? null
        : thinComparisons.first;
    final openReceiptLaneAction = receiptRows.isEmpty
        ? null
        : () {
            setReportReceiptFilter(ReportReceiptSceneFilter.all);
            focusReportReceiptWorkspace(receiptRows.first.event.eventId);
            _showReceiptActionFeedback(
              'Recovered comparison shell around ${receiptRows.first.event.eventId}.',
            );
          };
    final openGovernanceScopeAction = _openGovernanceScopeAction(
      clientId: widget.selectedClient,
      siteId: widget.selectedSite,
    );
    final receiptInvestigationComparison = _receiptInvestigationComparison(
      receiptRows,
    );
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
          if (comparisons.isNotEmpty) ...[
            const SizedBox(height: 10),
            _partnerComparisonCommandBanner(
              leaderComparison: leaderComparison,
              recoveryComparison: recoveryComparison,
              pendingCount: pendingComparisons.length,
              formingCount: formingComparisons.length,
              receiptCount: receiptRows.length,
              activitySignals: siteActivity.totalSignals,
              canOpenGovernance: openGovernanceScopeAction != null,
              onOpenReceiptLane: openReceiptLaneAction,
              onOpenActivityTruth: () => _openSiteActivityTruth(
                clientId: widget.selectedClient,
                siteId: widget.selectedSite,
              ),
              onOpenGovernance: openGovernanceScopeAction == null
                  ? null
                  : () {
                      openGovernanceScopeAction();
                      _showReceiptActionFeedback(
                        'Opening Governance for comparison shell ${widget.selectedSite}.',
                      );
                    },
              onFocusLeader:
                  leaderComparison == null ||
                      _partnerScoreboardMatchesFocus(leaderComparison.row)
                  ? null
                  : () => _setPartnerScopeFocus(
                      clientId: leaderComparison!.row.clientId,
                      siteId: leaderComparison.row.siteId,
                      partnerLabel: leaderComparison.row.partnerLabel,
                    ),
              onFocusRecovery:
                  recoveryComparison == null ||
                      (leaderComparison != null &&
                          recoveryComparison.row.partnerLabel ==
                              leaderComparison.row.partnerLabel) ||
                      _partnerScoreboardMatchesFocus(recoveryComparison.row)
                  ? null
                  : () => _setPartnerScopeFocus(
                      clientId: recoveryComparison.row.clientId,
                      siteId: recoveryComparison.row.siteId,
                      partnerLabel: recoveryComparison.row.partnerLabel,
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
          if (siteActivity.totalSignals > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _partnerScopeChip(
                  label: 'Site Activity',
                  color: const Color(0xFF59D79B),
                ),
                _partnerScopeChip(
                  label: '${siteActivity.totalSignals} signals',
                  color: const Color(0xFF8FD1FF),
                ),
                if (siteActivity.vehicleSignals > 0)
                  _partnerScopeChip(
                    label: '${siteActivity.vehicleSignals} vehicles',
                    color: const Color(0xFFF6C067),
                  ),
                if (siteActivity.personSignals > 0)
                  _partnerScopeChip(
                    label: '${siteActivity.personSignals} people',
                    color: const Color(0xFF8EA4C2),
                  ),
                if (siteActivity.knownIdentitySignals > 0)
                  _partnerScopeChip(
                    label: '${siteActivity.knownIdentitySignals} known IDs',
                    color: const Color(0xFF5DC8FF),
                  ),
                if (siteActivity.flaggedIdentitySignals > 0)
                  _partnerScopeChip(
                    label: '${siteActivity.flaggedIdentitySignals} flagged',
                    color: const Color(0xFFFF7A7A),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              siteActivity.summaryLine,
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
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
              _actionButton(
                key: const ValueKey('reports-partner-comparison-open-activity'),
                label: 'OPEN ACTIVITY TRUTH DESK',
                icon: Icons.groups_rounded,
                onTap: () => _openSiteActivityTruth(
                  clientId: widget.selectedClient,
                  siteId: widget.selectedSite,
                ),
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
          backgroundColor: _reportsPanelColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: _reportsBorderColor),
          ),
          title: Text(
            'Receipt Investigation History',
            style: GoogleFonts.inter(
              color: _reportsTitleColor,
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
                        color: _reportsTitleColor,
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

  Future<void> _openPartnerScopeActivityTruth() async {
    if (!_hasPartnerScopeFocus) {
      return;
    }
    await _openSiteActivityTruth(
      clientId: _partnerScopeClientId!,
      siteId: _partnerScopeSiteId!,
      partnerLabel: _partnerScopePartnerLabel,
    );
  }

  Future<void> _openSiteActivityTruth({
    required String clientId,
    required String siteId,
    String? partnerLabel,
  }) async {
    final historyPoints = _siteActivityHistoryPointsFor(
      clientId: clientId,
      siteId: siteId,
    );
    final scopedReceiptRows = _partnerReceiptRowsForScope(
      clientId: clientId,
      siteId: siteId,
    );
    final currentPoint = historyPoints.isEmpty ? null : historyPoints.first;
    await showDialog<void>(
      context: context,
      builder: (context) {
        final normalizedPartnerLabel = partnerLabel?.trim();
        final partnerGovernanceAction =
            widget.onOpenGovernanceForPartnerScope != null &&
                normalizedPartnerLabel != null &&
                normalizedPartnerLabel.isNotEmpty
            ? () => widget.onOpenGovernanceForPartnerScope!(
                clientId,
                siteId,
                normalizedPartnerLabel,
              )
            : null;
        final genericGovernanceAction = _openGovernanceScopeAction(
          clientId: clientId,
          siteId: siteId,
        );
        final canOpenGovernance =
            partnerGovernanceAction != null || genericGovernanceAction != null;
        return AlertDialog(
          backgroundColor: _reportsPanelColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: _reportsBorderColor),
          ),
          title: Text(
            'Visitor / Activity Truth',
            style: GoogleFonts.inter(
              color: _reportsTitleColor,
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
                    partnerLabel == null || partnerLabel.trim().isEmpty
                        ? '$clientId/$siteId'
                        : '$clientId/$siteId • $partnerLabel',
                    style: GoogleFonts.inter(
                      color: _reportsTitleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (currentPoint != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _partnerScopeChip(
                          label: currentPoint.current
                              ? 'CURRENT TRUTH'
                              : 'LATEST TRUTH',
                          color: const Color(0xFF59D79B),
                        ),
                        _partnerScopeChip(
                          label: currentPoint.reportDate,
                          color: const Color(0xFF8FD1FF),
                        ),
                        _partnerScopeChip(
                          label:
                              '${currentPoint.snapshot.totalSignals} signals',
                          color: const Color(0xFF8FD1FF),
                        ),
                        if (currentPoint.snapshot.vehicleSignals > 0)
                          _partnerScopeChip(
                            label:
                                '${currentPoint.snapshot.vehicleSignals} vehicles',
                            color: const Color(0xFFF6C067),
                          ),
                        if (currentPoint.snapshot.personSignals > 0)
                          _partnerScopeChip(
                            label:
                                '${currentPoint.snapshot.personSignals} people',
                            color: const Color(0xFF8EA4C2),
                          ),
                        if (currentPoint.snapshot.knownIdentitySignals > 0)
                          _partnerScopeChip(
                            label:
                                '${currentPoint.snapshot.knownIdentitySignals} known IDs',
                            color: const Color(0xFF5DC8FF),
                          ),
                        if (currentPoint.snapshot.flaggedIdentitySignals > 0)
                          _partnerScopeChip(
                            label:
                                '${currentPoint.snapshot.flaggedIdentitySignals} flagged',
                            color: const Color(0xFFFF7A7A),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentPoint.snapshot.summaryLine,
                      style: GoogleFonts.inter(
                        color: _reportsBodyColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    _siteActivityQuietScopeRecoveryCard(
                      clientId: clientId,
                      siteId: siteId,
                      partnerLabel: normalizedPartnerLabel,
                      hasScopedReceipts: scopedReceiptRows.isNotEmpty,
                      canOpenGovernance: canOpenGovernance,
                      onOpenReceiptLane: scopedReceiptRows.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              setReportReceiptFilter(
                                ReportReceiptSceneFilter.all,
                              );
                              focusReportReceiptWorkspace(
                                scopedReceiptRows.first.event.eventId,
                              );
                              _showReceiptActionFeedback(
                                'Focused quiet activity scope on receipt board ${scopedReceiptRows.first.event.eventId}.',
                              );
                            },
                      onOpenGovernance: !canOpenGovernance
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              if (partnerGovernanceAction != null) {
                                partnerGovernanceAction();
                              } else if (genericGovernanceAction != null) {
                                genericGovernanceAction();
                              }
                              _showReceiptActionFeedback(
                                normalizedPartnerLabel == null ||
                                        normalizedPartnerLabel.isEmpty
                                    ? 'Opening Governance for quiet activity scope $siteId.'
                                    : 'Opening Governance for quiet activity scope $siteId • $normalizedPartnerLabel.',
                              );
                            },
                    ),
                  ],
                  if (historyPoints.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Activity truth by shift',
                      style: GoogleFonts.inter(
                        color: _reportsTitleColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (
                      var index = 0;
                      index < historyPoints.length;
                      index++
                    ) ...[
                      _siteActivityHistoryRow(historyPoints[index]),
                      if (index < historyPoints.length - 1)
                        const SizedBox(height: 6),
                    ],
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('reports-site-activity-truth-copy-json'),
              onPressed: () => _copySiteActivityTruthJson(
                clientId: clientId,
                siteId: siteId,
                partnerLabel: partnerLabel,
              ),
              child: const Text('Copy JSON'),
            ),
            TextButton(
              key: const ValueKey('reports-site-activity-truth-copy-csv'),
              onPressed: () => _copySiteActivityTruthCsv(
                clientId: clientId,
                siteId: siteId,
                partnerLabel: partnerLabel,
              ),
              child: const Text('Copy CSV'),
            ),
            TextButton(
              key: const ValueKey('reports-site-activity-truth-close'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _siteActivityQuietScopeRecoveryCard({
    required String clientId,
    required String siteId,
    required String? partnerLabel,
    required bool hasScopedReceipts,
    required bool canOpenGovernance,
    required VoidCallback? onOpenReceiptLane,
    required VoidCallback? onOpenGovernance,
  }) {
    final detail = hasScopedReceipts
        ? 'This scope is quiet so far. Visitor and site-activity signals have not landed yet, but the Reports Workspace is still live for $siteId. Reopen the receipt board or pivot into Governance Desk while the activity stream warms up.'
        : 'This scope is quiet so far. Visitor and site-activity signals have not landed yet, so use Governance Desk to keep the operating picture moving while the activity stream warms up.';

    return Container(
      key: ValueKey<String>(
        'reports-site-activity-quiet-recovery-$clientId/$siteId/${partnerLabel ?? 'scope'}',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _reportsPanelAltColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _reportsBorderColor),
        boxShadow: const [
          BoxShadow(
            color: _reportsShadowColor,
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This scope is quiet so far.',
            style: GoogleFonts.inter(
              color: _reportsTitleColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: _reportsBodyColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasScopedReceipts)
                _actionButton(
                  key: ValueKey<String>(
                    'reports-site-activity-quiet-open-receipts-$clientId/$siteId/${partnerLabel ?? 'scope'}',
                  ),
                  label: 'Open Receipt Board',
                  icon: Icons.receipt_long_rounded,
                  onTap: onOpenReceiptLane,
                ),
              if (canOpenGovernance)
                _actionButton(
                  key: ValueKey<String>(
                    'reports-site-activity-quiet-open-governance-$clientId/$siteId/${partnerLabel ?? 'scope'}',
                  ),
                  label: 'OPEN GOVERNANCE DESK',
                  icon: Icons.verified_user_rounded,
                  onTap: onOpenGovernance,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _partnerScopePendingRecoveryCard({
    required bool hasScopedReceipts,
    required int activitySignals,
    required bool canOpenGovernance,
    required VoidCallback? onOpenReceiptLane,
    required VoidCallback onOpenActivityTruth,
    required VoidCallback? onOpenGovernance,
    required VoidCallback onClearFocus,
  }) {
    final hasActivitySignals = activitySignals > 0;
    final detail = hasScopedReceipts || hasActivitySignals
        ? 'The partner scope is already live, but the morning scorecard snapshot has not landed yet. Reopen the receipt board, inspect activity truth, or pivot into Governance Desk while the scorecard sync catches up.'
        : 'The partner scope is selected, but the morning scorecard has not landed yet. Open activity truth, pivot into Governance Desk, or clear focus while this scope catches up.';

    return Container(
      key: const ValueKey('reports-partner-scope-recovery-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _reportsPanelAltColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _reportsBorderColor),
        boxShadow: const [
          BoxShadow(
            color: _reportsShadowColor,
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _partnerScopeChip(
                label: 'SCORECARD PENDING',
                color: const Color(0xFFF6C067),
              ),
              _partnerScopeChip(
                label: hasScopedReceipts
                    ? 'Receipt board live'
                    : 'Receipt board idle',
                color: hasScopedReceipts
                    ? const Color(0xFF5DC8FF)
                    : const Color(0xFF7A8EA8),
              ),
              _partnerScopeChip(
                label: hasActivitySignals
                    ? '$activitySignals live signals'
                    : 'Activity truth ready',
                color: hasActivitySignals
                    ? const Color(0xFF59D79B)
                    : const Color(0xFF8EA4C2),
              ),
              if (canOpenGovernance)
                _partnerScopeChip(
                  label: 'Governance bridge ready',
                  color: const Color(0xFF8FD1FF),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: _reportsBodyColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasScopedReceipts)
                _actionButton(
                  key: const ValueKey(
                    'reports-partner-scope-recovery-open-receipts',
                  ),
                  label: 'Open Receipt Board',
                  icon: Icons.receipt_long_rounded,
                  onTap: onOpenReceiptLane,
                ),
              _actionButton(
                key: const ValueKey(
                  'reports-partner-scope-recovery-open-activity',
                ),
                label: 'OPEN ACTIVITY TRUTH DESK',
                icon: Icons.groups_rounded,
                onTap: onOpenActivityTruth,
              ),
              if (canOpenGovernance)
                _actionButton(
                  key: const ValueKey(
                    'reports-partner-scope-recovery-open-governance',
                  ),
                  label: 'OPEN GOVERNANCE DESK',
                  icon: Icons.verified_user_rounded,
                  onTap: onOpenGovernance,
                ),
              _actionButton(
                key: const ValueKey(
                  'reports-partner-scope-recovery-clear-focus',
                ),
                label: 'Clear Focus',
                icon: Icons.filter_alt_off_rounded,
                onTap: onClearFocus,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _partnerDrillInRecoveryCard({
    required bool hasScopedReceipts,
    required int activitySignals,
    required bool canOpenGovernance,
    required bool showClearFocus,
    required VoidCallback? onOpenReceiptLane,
    required VoidCallback onOpenActivityTruth,
    required VoidCallback? onOpenGovernance,
    required VoidCallback? onClearFocus,
  }) {
    final hasActivitySignals = activitySignals > 0;
    final detail = hasScopedReceipts || hasActivitySignals
        ? 'No scorecard history has landed for this partner scope yet, but the scope already has live receipt or activity context. Reopen the receipt board, inspect activity truth, or bridge into Governance Desk while the scorecard history sync catches up.'
        : 'No scorecard history has landed for this partner scope yet. Use activity truth or Governance Desk to keep the scope moving while scorecard history catches up.';

    return Container(
      key: const ValueKey('reports-partner-drill-in-recovery-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _reportsPanelAltColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _reportsBorderColor),
        boxShadow: const [
          BoxShadow(
            color: _reportsShadowColor,
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No scorecard history has landed for this partner scope yet.',
            style: GoogleFonts.inter(
              color: _reportsTitleColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _partnerScopeChip(
                label: 'DRILL-IN READY',
                color: const Color(0xFFF6C067),
              ),
              _partnerScopeChip(
                label: hasScopedReceipts
                    ? 'Receipt board live'
                    : 'Receipt board idle',
                color: hasScopedReceipts
                    ? const Color(0xFF5DC8FF)
                    : const Color(0xFF7A8EA8),
              ),
              _partnerScopeChip(
                label: hasActivitySignals
                    ? '$activitySignals live signals'
                    : 'Activity truth ready',
                color: hasActivitySignals
                    ? const Color(0xFF59D79B)
                    : const Color(0xFF8EA4C2),
              ),
              if (canOpenGovernance)
                _partnerScopeChip(
                  label: 'Governance bridge ready',
                  color: const Color(0xFF8FD1FF),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: _reportsBodyColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasScopedReceipts)
                _actionButton(
                  key: const ValueKey(
                    'reports-partner-drill-in-recovery-open-receipts',
                  ),
                  label: 'Open Receipt Board',
                  icon: Icons.receipt_long_rounded,
                  onTap: onOpenReceiptLane,
                ),
              _actionButton(
                key: const ValueKey(
                  'reports-partner-drill-in-recovery-open-activity',
                ),
                label: 'OPEN ACTIVITY TRUTH DESK',
                icon: Icons.groups_rounded,
                onTap: onOpenActivityTruth,
              ),
              if (canOpenGovernance)
                _actionButton(
                  key: const ValueKey(
                    'reports-partner-drill-in-recovery-open-governance',
                  ),
                  label: 'OPEN GOVERNANCE DESK',
                  icon: Icons.verified_user_rounded,
                  onTap: onOpenGovernance,
                ),
              if (showClearFocus)
                _actionButton(
                  key: const ValueKey(
                    'reports-partner-drill-in-recovery-clear-focus',
                  ),
                  label: 'Clear Focus',
                  icon: Icons.filter_alt_off_rounded,
                  onTap: onClearFocus,
                ),
            ],
          ),
        ],
      ),
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
    final siteActivity = _siteActivitySnapshot(
      clientId: clientId,
      siteId: siteId,
    );
    final trendLabel = _partnerScopeTrendLabel(historyPoints);
    final trendReason = _partnerScopeTrendReason(historyPoints);
    final receiptInvestigationTrendLabel = _receiptInvestigationTrendLabel(
      receiptRows,
    );
    final receiptInvestigationComparison = _receiptInvestigationComparison(
      receiptRows,
    );
    await showDialog<void>(
      context: context,
      builder: (context) {
        final partnerGovernanceAction =
            widget.onOpenGovernanceForPartnerScope != null
            ? () => widget.onOpenGovernanceForPartnerScope!(
                clientId,
                siteId,
                partnerLabel,
              )
            : null;
        final genericGovernanceAction = _openGovernanceScopeAction(
          clientId: clientId,
          siteId: siteId,
        );
        final canOpenGovernance =
            partnerGovernanceAction != null || genericGovernanceAction != null;
        final isFocusedScope =
            _hasPartnerScopeFocus &&
            _partnerScopeClientId == clientId &&
            _partnerScopeSiteId == siteId &&
            _partnerScopePartnerLabel == partnerLabel;
        return AlertDialog(
          backgroundColor: _reportsPanelColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: _reportsBorderColor),
          ),
          title: Text(
            'Partner Scorecard Drill-In',
            style: GoogleFonts.inter(
              color: _reportsTitleColor,
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
                      color: _reportsTitleColor,
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
                        color: _reportsMutedColor,
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
                        color: _reportsTitleColor,
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
                  if (historyPoints.isEmpty) ...[
                    const SizedBox(height: 12),
                    _partnerDrillInRecoveryCard(
                      hasScopedReceipts: receiptRows.isNotEmpty,
                      activitySignals: siteActivity.totalSignals,
                      canOpenGovernance: canOpenGovernance,
                      showClearFocus: isFocusedScope,
                      onOpenReceiptLane: receiptRows.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              setReportReceiptFilter(
                                ReportReceiptSceneFilter.all,
                              );
                              focusReportReceiptWorkspace(
                                receiptRows.first.event.eventId,
                              );
                              _showReceiptActionFeedback(
                                'Recovered partner drill-in around ${receiptRows.first.event.eventId}.',
                              );
                            },
                      onOpenActivityTruth: () {
                        Navigator.of(context).pop();
                        _openSiteActivityTruth(
                          clientId: clientId,
                          siteId: siteId,
                          partnerLabel: partnerLabel,
                        );
                      },
                      onOpenGovernance: !canOpenGovernance
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              if (partnerGovernanceAction != null) {
                                partnerGovernanceAction();
                              } else if (genericGovernanceAction != null) {
                                genericGovernanceAction();
                              }
                              _showReceiptActionFeedback(
                                'Opening Governance for drill-in scope $siteId • $partnerLabel.',
                              );
                            },
                      onClearFocus: !isFocusedScope
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              _clearPartnerScopeFocus();
                            },
                    ),
                  ],
                  if (historyPoints.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Scorecard history',
                      style: GoogleFonts.inter(
                        color: _reportsTitleColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (
                      var index = 0;
                      index < historyPoints.length;
                      index++
                    ) ...[
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
                        color: _reportsTitleColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (
                      var index = 0;
                      index < currentChains.length;
                      index++
                    ) ...[
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
              key: const ValueKey(
                'reports-partner-scorecard-drill-in-copy-json',
              ),
              onPressed: () => _copyPartnerDrillInJson(
                clientId: clientId,
                siteId: siteId,
                partnerLabel: partnerLabel,
              ),
              child: const Text('Copy JSON'),
            ),
            TextButton(
              key: const ValueKey(
                'reports-partner-scorecard-drill-in-copy-csv',
              ),
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

  Future<void> _openPartnerShiftDetail(_PartnerScopeHistoryPoint point) async {
    final scopedReceiptRows = _partnerReceiptRowsForScope(
      clientId: point.row.clientId,
      siteId: point.row.siteId,
    );
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
    await showDialog<void>(
      context: context,
      builder: (context) {
        final genericGovernanceAction = _openGovernanceScopeAction(
          clientId: point.row.clientId,
          siteId: point.row.siteId,
        );
        final canOpenGovernance =
            widget.onOpenGovernanceForPartnerScope != null ||
            genericGovernanceAction != null;
        return AlertDialog(
          backgroundColor: _reportsPanelColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: _reportsBorderColor),
          ),
          title: Text(
            'Partner Shift Detail',
            style: GoogleFonts.inter(
              color: _reportsTitleColor,
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
                      color: _reportsTitleColor,
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
                        label: point.current
                            ? 'CURRENT SHIFT'
                            : 'SHIFT SNAPSHOT',
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
                      color: _reportsBodyColor,
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
                      color: _reportsTitleColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (receiptRows.isEmpty)
                    _partnerShiftEmptyReceiptsRecoveryCard(
                      point: point,
                      hasScopedReceipts: scopedReceiptRows.isNotEmpty,
                      hasEvents: eventIds.isNotEmpty,
                      canOpenGovernance: canOpenGovernance,
                      onOpenReceiptLane: scopedReceiptRows.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              setReportReceiptFilter(
                                ReportReceiptSceneFilter.all,
                              );
                              focusReportReceiptWorkspace(
                                scopedReceiptRows.first.event.eventId,
                              );
                              _showReceiptActionFeedback(
                                'Focused shift receipt board for ${point.reportDate} • ${point.row.partnerLabel}.',
                              );
                            },
                      onOpenGovernance: !canOpenGovernance
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              if (widget.onOpenGovernanceForPartnerScope !=
                                  null) {
                                widget.onOpenGovernanceForPartnerScope!(
                                  point.row.clientId,
                                  point.row.siteId,
                                  point.row.partnerLabel,
                                );
                              } else if (genericGovernanceAction != null) {
                                genericGovernanceAction();
                              }
                              _showReceiptActionFeedback(
                                'Opening Governance for ${point.reportDate} • ${point.row.partnerLabel}.',
                              );
                            },
                      onOpenEvents: eventIds.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              _openEventsForPartnerShift(point);
                            },
                    )
                  else
                    for (
                      var index = 0;
                      index < receiptRows.length;
                      index++
                    ) ...[
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
                      color: _reportsTitleColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (chains.isEmpty)
                    _partnerShiftEmptyChainsRecoveryCard(
                      point: point,
                      hasReceipts: receiptRows.isNotEmpty,
                      hasEvents: eventIds.isNotEmpty,
                      canOpenGovernance: canOpenGovernance,
                      onOpenReceipts: receiptRows.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              setReportReceiptFilter(
                                ReportReceiptSceneFilter.all,
                              );
                              focusReportReceiptWorkspace(
                                receiptRows.first.event.eventId,
                              );
                              _showReceiptActionFeedback(
                                'Focused shift receipts for ${point.reportDate} • ${point.row.partnerLabel}.',
                              );
                            },
                      onOpenGovernance: !canOpenGovernance
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              if (widget.onOpenGovernanceForPartnerScope !=
                                  null) {
                                widget.onOpenGovernanceForPartnerScope!(
                                  point.row.clientId,
                                  point.row.siteId,
                                  point.row.partnerLabel,
                                );
                              } else if (genericGovernanceAction != null) {
                                genericGovernanceAction();
                              }
                              _showReceiptActionFeedback(
                                'Opening Governance for ${point.reportDate} • ${point.row.partnerLabel}.',
                              );
                            },
                      onOpenEvents: eventIds.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              _openEventsForPartnerShift(point);
                            },
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
                      label: 'OPEN EVENTS SCOPE',
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

  Widget _partnerShiftEmptyReceiptsRecoveryCard({
    required _PartnerScopeHistoryPoint point,
    required bool hasScopedReceipts,
    required bool hasEvents,
    required bool canOpenGovernance,
    required VoidCallback? onOpenReceiptLane,
    required VoidCallback? onOpenGovernance,
    required VoidCallback? onOpenEvents,
  }) {
    final detail = hasScopedReceipts
        ? 'No generated receipts landed in this shift window, but this client/site scope still has report receipts outside the current shift. Reopen the receipt board, pivot into Governance Desk, or review the scoped event trail to keep the handoff moving.'
        : 'No generated receipts landed in this shift window. Pivot into Governance Desk or the scoped event trail to keep the scope moving while the receipt history catches up.';

    return Container(
      key: ValueKey<String>(
        'reports-partner-shift-empty-receipts-recovery-${point.reportDate}',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _reportsPanelAltColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _reportsBorderColor),
        boxShadow: const [
          BoxShadow(
            color: _reportsShadowColor,
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No generated receipts landed in this shift window.',
            style: GoogleFonts.inter(
              color: _reportsTitleColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: _reportsBodyColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasScopedReceipts)
                _actionButton(
                  key: ValueKey<String>(
                    'reports-partner-shift-empty-receipts-open-lane-${point.reportDate}',
                  ),
                  label: 'Open Receipt Board',
                  icon: Icons.receipt_long_rounded,
                  onTap: onOpenReceiptLane,
                ),
              if (canOpenGovernance)
                _actionButton(
                  key: ValueKey<String>(
                    'reports-partner-shift-empty-receipts-open-governance-${point.reportDate}',
                  ),
                  label: 'OPEN GOVERNANCE DESK',
                  icon: Icons.verified_user_rounded,
                  onTap: onOpenGovernance,
                ),
              if (hasEvents)
                _actionButton(
                  key: ValueKey<String>(
                    'reports-partner-shift-empty-receipts-open-events-${point.reportDate}',
                  ),
                  label: 'OPEN EVENTS SCOPE',
                  icon: Icons.rule_folder_rounded,
                  onTap: onOpenEvents,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _partnerShiftEmptyChainsRecoveryCard({
    required _PartnerScopeHistoryPoint point,
    required bool hasReceipts,
    required bool hasEvents,
    required bool canOpenGovernance,
    required VoidCallback? onOpenReceipts,
    required VoidCallback? onOpenGovernance,
    required VoidCallback? onOpenEvents,
  }) {
    final detail = hasReceipts
        ? 'Shift receipts are still staged for this partner lane even though no dispatch chain milestones landed in the current window. Reopen the receipt board, pivot into governance, or review the scoped event trail to keep the handoff moving.'
        : 'No dispatch chain milestones landed in the current window. Pivot into governance or the scoped event trail to keep the lane moving while telemetry catches up.';

    return Container(
      key: ValueKey<String>(
        'reports-partner-shift-empty-chains-recovery-${point.reportDate}',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _reportsPanelAltColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _reportsBorderColor),
        boxShadow: const [
          BoxShadow(
            color: _reportsShadowColor,
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No partner dispatch chains formed during this shift window.',
            style: GoogleFonts.inter(
              color: _reportsTitleColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: _reportsBodyColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasReceipts)
                _actionButton(
                  key: ValueKey<String>(
                    'reports-partner-shift-empty-chains-open-receipts-${point.reportDate}',
                  ),
                  label: 'Open Shift Receipts',
                  icon: Icons.receipt_long_rounded,
                  onTap: onOpenReceipts,
                ),
              if (canOpenGovernance)
                _actionButton(
                  key: ValueKey<String>(
                    'reports-partner-shift-empty-chains-open-governance-${point.reportDate}',
                  ),
                  label: 'OPEN GOVERNANCE DESK',
                  icon: Icons.verified_user_rounded,
                  onTap: onOpenGovernance,
                ),
              if (hasEvents)
                _actionButton(
                  key: ValueKey<String>(
                    'reports-partner-shift-empty-chains-open-events-${point.reportDate}',
                  ),
                  label: 'OPEN EVENTS SCOPE',
                  icon: Icons.rule_folder_rounded,
                  onTap: onOpenEvents,
                ),
            ],
          ),
        ],
      ),
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
        color: _reportsPanelAltColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _reportsBorderColor),
        boxShadow: const [
          BoxShadow(
            color: _reportsShadowColor,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Investigation Lens',
            style: GoogleFonts.inter(
              color: const Color(0xFF2F6E9C),
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
              color: _reportsTitleColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            baselineDetail,
            style: GoogleFonts.inter(
              color: _reportsBodyColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_openGovernanceScopeAction(
                clientId: widget.selectedClient,
                siteId: widget.selectedSite,
              ) !=
              null) ...[
            const SizedBox(height: 10),
            _actionButton(
              key: const ValueKey('reports-receipt-policy-open-governance'),
              label: 'OPEN GOVERNANCE DESK',
              icon: Icons.verified_user_rounded,
              onTap: () {
                _openGovernanceScopeAction(
                  clientId: widget.selectedClient,
                  siteId: widget.selectedSite,
                )?.call();
                _showReceiptActionFeedback(
                  'Opening Governance for ${widget.selectedSite}.',
                );
              },
            ),
          ],
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
        color: _reportsPanelAltColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _reportsBorderColor),
        boxShadow: const [
          BoxShadow(
            color: _reportsShadowColor,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entryContext.bannerTitle,
            style: GoogleFonts.inter(
              color: const Color(0xFF2F6E9C),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entryContext.bannerDetail,
            style: GoogleFonts.inter(
              color: _reportsTitleColor,
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_openGovernanceScopeAction(
                    clientId: widget.selectedClient,
                    siteId: widget.selectedSite,
                  ) !=
                  null)
                _actionButton(
                  key: const ValueKey(
                    'reports-receipt-policy-entry-context-open-governance',
                  ),
                  label: 'OPEN GOVERNANCE DESK',
                  icon: Icons.verified_user_rounded,
                  onTap: () {
                    _openGovernanceScopeAction(
                      clientId: widget.selectedClient,
                      siteId: widget.selectedSite,
                    )?.call();
                    _showReceiptActionFeedback(
                      'Opening Governance for ${widget.selectedSite}.',
                    );
                  },
                ),
              _actionButton(
                key: const ValueKey(
                  'reports-receipt-policy-entry-context-clear',
                ),
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
        ],
      ),
    );
  }

  Widget _siteActivityHistoryRow(_SiteActivityHistoryPoint point) {
    return Container(
      key: ValueKey<String>(
        'reports-site-activity-history-${point.clientId}/${point.siteId}/${point.reportDate}',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _reportsDrillInCardDecoration(
        highlighted: point.current,
        accent: const Color(0xFF59D79B),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _partnerScopeChip(
                label: point.current ? 'CURRENT' : 'HISTORY',
                color: point.current
                    ? const Color(0xFF59D79B)
                    : const Color(0xFF8EA4C2),
              ),
              _partnerScopeChip(
                label: point.reportDate,
                color: const Color(0xFF8FD1FF),
              ),
              _partnerScopeChip(
                label: '${point.snapshot.totalSignals} signals',
                color: const Color(0xFF8FD1FF),
              ),
              if (point.snapshot.vehicleSignals > 0)
                _partnerScopeChip(
                  label: '${point.snapshot.vehicleSignals} vehicles',
                  color: const Color(0xFFF6C067),
                ),
              if (point.snapshot.personSignals > 0)
                _partnerScopeChip(
                  label: '${point.snapshot.personSignals} people',
                  color: const Color(0xFF8EA4C2),
                ),
              if (point.snapshot.knownIdentitySignals > 0)
                _partnerScopeChip(
                  label: '${point.snapshot.knownIdentitySignals} known IDs',
                  color: const Color(0xFF5DC8FF),
                ),
              if (point.snapshot.flaggedIdentitySignals > 0)
                _partnerScopeChip(
                  label: '${point.snapshot.flaggedIdentitySignals} flagged',
                  color: const Color(0xFFFF7A7A),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            point.snapshot.summaryLine,
            style: GoogleFonts.inter(
              color: _reportsBodyColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.onOpenEventsForScope != null &&
              point.eventIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: _pillActionButton(
                buttonKey: ValueKey<String>(
                  'reports-site-activity-open-events-${point.reportDate}',
                ),
                label: 'OPEN EVENTS SCOPE',
                icon: Icons.rule_folder_rounded,
                filled: false,
                onTap: () => _openEventsForSiteActivityPoint(point),
              ),
            ),
          ],
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
        ? const Color(0x1A5DC8FF)
        : current
        ? const Color(0x1A0EA5E9)
        : _reportsPanelAltColor;
    final borderColor = focused
        ? const Color(0xFF5DC8FF)
        : current
        ? const Color(0x550EA5E9)
        : _reportsBorderColor;
    return Container(
      key: ValueKey<String>('reports-receipt-policy-row-${event.eventId}'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: _reportsShadowColor,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
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
                        color: _reportsTitleColor,
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
              color: _reportsMutedColor,
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
              label: 'OPEN EVENTS SCOPE',
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
        color: isActive
            ? accent.withValues(alpha: 0.12)
            : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? accent.withValues(alpha: 0.85)
              : const Color(0xFFD6E1EC),
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
                  color: const Color(0xFFF3F8FD),
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
              color: const Color(0xFF7A8FA4),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
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
    Color color = _reportsAccentSky,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  BoxDecoration _reportsDrillInCardDecoration({
    bool highlighted = false,
    Color accent = _reportsAccentSky,
    double radius = 12,
  }) {
    return BoxDecoration(
      color: highlighted
          ? accent.withValues(alpha: 0.1)
          : _reportsPanelAltColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: highlighted
            ? accent.withValues(alpha: 0.3)
            : _reportsBorderColor,
      ),
      boxShadow: const [
        BoxShadow(
          color: _reportsShadowColor,
          blurRadius: 12,
          offset: Offset(0, 6),
        ),
      ],
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
      decoration: _reportsDrillInCardDecoration(
        highlighted: point.current,
        accent: const Color(0xFF0EA5E9),
        radius: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            point.current ? '${point.reportDate} • CURRENT' : point.reportDate,
            style: GoogleFonts.inter(
              color: _reportsTitleColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            point.row.summaryLine,
            style: GoogleFonts.inter(
              color: _reportsBodyColor,
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
    final scopedReceiptRows = _partnerReceiptRowsForScope(
      clientId: row.clientId,
      siteId: row.siteId,
    );
    final latestPoint = comparison.historyPoints.isEmpty
        ? null
        : comparison.historyPoints.first;
    final siteActivity = _siteActivitySnapshot(
      clientId: row.clientId,
      siteId: row.siteId,
      reportDate: latestPoint?.reportDate,
    );
    final partnerGovernanceAction =
        widget.onOpenGovernanceForPartnerScope != null
        ? () => widget.onOpenGovernanceForPartnerScope!(
            row.clientId,
            row.siteId,
            row.partnerLabel,
          )
        : null;
    final genericGovernanceAction = _openGovernanceScopeAction(
      clientId: row.clientId,
      siteId: row.siteId,
    );
    final openGovernanceAction =
        partnerGovernanceAction ??
        (genericGovernanceAction == null
            ? null
            : () {
                genericGovernanceAction();
              });
    final hasThinHistory = comparison.historyPoints.length <= 1;
    final latestShiftPrimaryLabel = latestPoint == null
        ? 'NO SCORE'
        : _partnerScoreboardPrimaryLabel(latestPoint.row);
    final latestShiftStripColor = comparison.isLeader
        ? const Color(0x1436C690)
        : comparison.trendLabel.trim().toUpperCase() == 'SLIPPING'
        ? const Color(0x14FF7A7A)
        : const Color(0xFF102337);
    final latestShiftStripBorderColor = comparison.isLeader
        ? const Color(0xFF59D79B)
        : comparison.trendLabel.trim().toUpperCase() == 'SLIPPING'
        ? const Color(0xFFFF7A7A)
        : const Color(0xFF223244);
    final latestShiftLensLabel = comparison.isLeader
        ? 'BEST CURRENT'
        : comparison.trendLabel.trim().isEmpty
        ? 'ACTIVE LANE'
        : '${comparison.trendLabel.trim().toUpperCase()} LANE';
    final latestShiftPostureLabel = _partnerLatestShiftPostureLabel(
      isLeader: comparison.isLeader,
      primaryLabel: latestShiftPrimaryLabel,
    );
    final latestShiftPostureSummary = _partnerLatestShiftPostureSummary(
      isLeader: comparison.isLeader,
      primaryLabel: latestShiftPrimaryLabel,
    );
    final latestShiftGapDriverLabel = _partnerLatestShiftGapDriverLabel(
      comparison,
      latestPoint,
    );
    final latestShiftGapDriverSummary = _partnerLatestShiftGapDriverSummary(
      comparison,
      latestPoint,
    );
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
        color: isActive ? const Color(0x1418D39E) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFF59D79B) : const Color(0xFFD6E1EC),
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
                        color: const Color(0xFF172638),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comparison.summaryLine,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF556B80),
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
              color: const Color(0xFF556B80),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!comparison.isLeader && comparison.trendReason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              comparison.trendReason,
              style: GoogleFonts.inter(
                color: const Color(0xFF7A8FA4),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (latestPoint != null) ...[
            const SizedBox(height: 10),
            Container(
              key: ValueKey<String>(
                'reports-partner-comparison-latest-shift-${row.clientId}/${row.siteId}/${row.partnerLabel}',
              ),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: latestShiftStripColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: latestShiftStripBorderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Latest shift',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFE8F1FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      _partnerScopeChip(
                        label: latestPoint.reportDate,
                        color: const Color(0xFF8FD1FF),
                      ),
                      _partnerScopeChip(
                        label: latestShiftLensLabel,
                        color: latestShiftStripBorderColor,
                      ),
                      _partnerScopeChip(
                        label: latestShiftPrimaryLabel,
                        color: _partnerTrendColor(latestShiftPrimaryLabel),
                      ),
                      _partnerScopeChip(
                        label: latestShiftPostureLabel,
                        color: _partnerTrendColor(latestShiftPrimaryLabel),
                      ),
                      if (latestShiftGapDriverLabel.isNotEmpty)
                        _partnerScopeChip(
                          label: latestShiftGapDriverLabel,
                          color: const Color(0xFFF6C067),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    latestPoint.row.summaryLine,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9CB2D1),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _partnerScopeChip(
                        label: '${latestPoint.row.dispatchCount} dispatches',
                        color: const Color(0xFF8FD1FF),
                      ),
                      if (latestPoint.row.averageAcceptedDelayMinutes > 0)
                        _partnerScopeChip(
                          label:
                              'Accept ${latestPoint.row.averageAcceptedDelayMinutes.toStringAsFixed(1)}m',
                          color: const Color(0xFFF6C067),
                        ),
                      if (!comparison.isLeader &&
                          comparison.acceptDeltaMinutes != null)
                        _partnerScopeChip(
                          label:
                              'Accept Δ +${comparison.acceptDeltaMinutes!.toStringAsFixed(1)}m',
                          color: const Color(0xFFFF7A7A),
                        ),
                      if (latestPoint.row.averageOnSiteDelayMinutes > 0)
                        _partnerScopeChip(
                          label:
                              'On site ${latestPoint.row.averageOnSiteDelayMinutes.toStringAsFixed(1)}m',
                          color: const Color(0xFFFFB86C),
                        ),
                      if (!comparison.isLeader &&
                          comparison.onSiteDeltaMinutes != null)
                        _partnerScopeChip(
                          label:
                              'On site Δ +${comparison.onSiteDeltaMinutes!.toStringAsFixed(1)}m',
                          color: const Color(0xFFFF7A7A),
                        ),
                      if (latestPoint.receiptInvestigationSummary != null) ...[
                        _partnerScopeChip(
                          label:
                              'Gov ${latestPoint.receiptInvestigationSummary!.governanceHandoffCount}',
                          color: const Color(0xFFFF7A7A),
                        ),
                        _partnerScopeChip(
                          label:
                              'Routine ${latestPoint.receiptInvestigationSummary!.routineReviewCount}',
                          color: const Color(0xFF8EA4C2),
                        ),
                      ],
                    ],
                  ),
                  if (latestShiftPostureSummary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      latestShiftPostureSummary,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8EA4C2),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (latestShiftGapDriverSummary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      latestShiftGapDriverSummary,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8EA4C2),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (latestPoint.receiptInvestigationSummary != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      latestPoint.receiptInvestigationSummary!.summaryLine,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF7D93B1),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (hasThinHistory) ...[
            const SizedBox(height: 10),
            _partnerComparisonRecoveryCard(
              row: row,
              latestPoint: latestPoint,
              hasScopedReceipts: scopedReceiptRows.isNotEmpty,
              activitySignals: siteActivity.totalSignals,
              canOpenGovernance: openGovernanceAction != null,
              showFocusAction: !isActive,
              onOpenReceiptLane: scopedReceiptRows.isEmpty
                  ? null
                  : () {
                      setReportReceiptFilter(ReportReceiptSceneFilter.all);
                      focusReportReceiptWorkspace(
                        scopedReceiptRows.first.event.eventId,
                      );
                      _showReceiptActionFeedback(
                        'Recovered comparison lane around ${scopedReceiptRows.first.event.eventId}.',
                      );
                    },
              onOpenActivityTruth: () => _openSiteActivityTruth(
                clientId: row.clientId,
                siteId: row.siteId,
                partnerLabel: row.partnerLabel,
              ),
              onOpenGovernance: openGovernanceAction == null
                  ? null
                  : () {
                      openGovernanceAction();
                      _showReceiptActionFeedback(
                        'Opening Governance for comparison lane ${row.siteId} • ${row.partnerLabel}.',
                      );
                    },
              onFocusLane: isActive
                  ? null
                  : () => _setPartnerScopeFocus(
                      clientId: row.clientId,
                      siteId: row.siteId,
                      partnerLabel: row.partnerLabel,
                    ),
            ),
          ],
          if (comparison.historyPoints.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Recent shifts',
              style: GoogleFonts.inter(
                color: const Color(0xFF172638),
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
          const SizedBox(height: 10),
          Text(
            'Investigate',
            style: GoogleFonts.inter(
              color: const Color(0xFF172638),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton(
                key: ValueKey<String>(
                  'reports-partner-comparison-open-events-${row.clientId}/${row.siteId}/${row.partnerLabel}',
                ),
                label: 'OPEN EVENTS SCOPE',
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
                label: 'OPEN PARTNER DRILL-IN',
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
          const SizedBox(height: 10),
          Text(
            'Export',
            style: GoogleFonts.inter(
              color: const Color(0xFF556B80),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _partnerComparisonRecoveryCard({
    required SovereignReportPartnerScoreboardRow row,
    required _PartnerScopeHistoryPoint? latestPoint,
    required bool hasScopedReceipts,
    required int activitySignals,
    required bool canOpenGovernance,
    required bool showFocusAction,
    required VoidCallback? onOpenReceiptLane,
    required VoidCallback onOpenActivityTruth,
    required VoidCallback? onOpenGovernance,
    required VoidCallback? onFocusLane,
  }) {
    final hasActivitySignals = activitySignals > 0;
    final detail = latestPoint == null
        ? 'This comparison board is visible before scorecard history has landed. Use the receipt board, activity truth, or Governance Desk to keep the scope moving while the first scorecard arrives.'
        : 'This comparison board is still building its baseline from a single scored shift. Use the receipt board, activity truth, or Governance Desk to keep the operator picture rich while the next scorecard lands.';

    return Container(
      key: ValueKey<String>(
        'reports-partner-comparison-recovery-${row.clientId}/${row.siteId}/${row.partnerLabel}',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _reportsPanelColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _reportsBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _partnerScopeChip(
                label: latestPoint == null
                    ? 'SCORE PENDING'
                    : 'BASELINE FORMING',
                color: const Color(0xFFF6C067),
              ),
              _partnerScopeChip(
                label: latestPoint == null
                    ? 'Waiting on first shift'
                    : '${latestPoint.reportDate} first shift',
                color: _reportsAccentSky,
              ),
              _partnerScopeChip(
                label: hasScopedReceipts
                    ? 'Receipt board live'
                    : 'Receipt board idle',
                color: hasScopedReceipts
                    ? const Color(0xFF5DC8FF)
                    : const Color(0xFF7A8EA8),
              ),
              _partnerScopeChip(
                label: hasActivitySignals
                    ? '$activitySignals live signals'
                    : 'Activity truth ready',
                color: hasActivitySignals
                    ? const Color(0xFF59D79B)
                    : const Color(0xFF8EA4C2),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: const Color(0xFF556B80),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasScopedReceipts)
                _actionButton(
                  key: ValueKey<String>(
                    'reports-partner-comparison-recovery-open-receipts-${row.clientId}/${row.siteId}/${row.partnerLabel}',
                  ),
                  label: 'Open Receipt Board',
                  icon: Icons.receipt_long_rounded,
                  onTap: onOpenReceiptLane,
                ),
              _actionButton(
                key: ValueKey<String>(
                  'reports-partner-comparison-recovery-open-activity-${row.clientId}/${row.siteId}/${row.partnerLabel}',
                ),
                label: 'OPEN ACTIVITY TRUTH DESK',
                icon: Icons.groups_rounded,
                onTap: onOpenActivityTruth,
              ),
              if (canOpenGovernance)
                _actionButton(
                  key: ValueKey<String>(
                    'reports-partner-comparison-recovery-open-governance-${row.clientId}/${row.siteId}/${row.partnerLabel}',
                  ),
                  label: 'OPEN GOVERNANCE DESK',
                  icon: Icons.verified_user_rounded,
                  onTap: onOpenGovernance,
                ),
              if (showFocusAction)
                _actionButton(
                  key: ValueKey<String>(
                    'reports-partner-comparison-recovery-focus-${row.clientId}/${row.siteId}/${row.partnerLabel}',
                  ),
                  label: 'Focus Lane',
                  icon: Icons.filter_center_focus_rounded,
                  onTap: onFocusLane,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _partnerComparisonCommandBanner({
    required _PartnerComparisonRow? leaderComparison,
    required _PartnerComparisonRow? recoveryComparison,
    required int pendingCount,
    required int formingCount,
    required int receiptCount,
    required int activitySignals,
    required bool canOpenGovernance,
    required VoidCallback? onOpenReceiptLane,
    required VoidCallback onOpenActivityTruth,
    required VoidCallback? onOpenGovernance,
    required VoidCallback? onFocusLeader,
    required VoidCallback? onFocusRecovery,
  }) {
    final pendingLabel = pendingCount > 0
        ? '$pendingCount pending'
        : formingCount > 0
        ? '$formingCount forming'
        : 'All boards anchored';
    final detail = pendingCount > 0
        ? '$pendingCount comparison board${pendingCount == 1 ? '' : 's'} are visible before the first scorecard lands. Keep receipts, activity truth, and Governance Desk moving while the ladder fills in.'
        : formingCount > 0
        ? '$formingCount comparison board${formingCount == 1 ? '' : 's'} are still building a baseline from one scored shift. Focus a board or open activity truth to anchor decisions while the baseline matures.'
        : 'The comparison ladder is anchored. Use leader focus, receipts, and Governance Desk to move from site posture into a scoped operator board.';

    return Container(
      key: const ValueKey('reports-partner-comparison-command-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _reportsPanelColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _reportsBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _partnerScopeChip(
                label: 'COMPARISON COMMAND',
                color: _reportsAccentSky,
              ),
              if (leaderComparison != null)
                _partnerScopeChip(
                  label: 'Leader: ${leaderComparison.row.partnerLabel}',
                  color: const Color(0xFF59D79B),
                ),
              _partnerScopeChip(
                label: pendingLabel,
                color: pendingCount > 0
                    ? const Color(0xFFF6C067)
                    : formingCount > 0
                    ? _reportsAccentSky
                    : const Color(0xFF59D79B),
              ),
              if (receiptCount > 0)
                _partnerScopeChip(
                  label: '$receiptCount receipts',
                  color: const Color(0xFF5DC8FF),
                ),
              _partnerScopeChip(
                label: activitySignals > 0
                    ? '$activitySignals live signals'
                    : 'Activity truth ready',
                color: activitySignals > 0
                    ? const Color(0xFF59D79B)
                    : const Color(0xFF8EA4C2),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: const Color(0xFF556B80),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onFocusLeader != null)
                _actionButton(
                  key: const ValueKey(
                    'reports-partner-comparison-command-focus-leader',
                  ),
                  label: 'Focus Leader Lane',
                  icon: Icons.workspace_premium_rounded,
                  onTap: onFocusLeader,
                ),
              if (onFocusRecovery != null && recoveryComparison != null)
                _actionButton(
                  key: const ValueKey(
                    'reports-partner-comparison-command-focus-recovery',
                  ),
                  label: recoveryComparison.historyPoints.isEmpty
                      ? 'Focus Pending Lane'
                      : 'Focus Forming Lane',
                  icon: Icons.filter_center_focus_rounded,
                  onTap: onFocusRecovery,
                ),
              if (onOpenReceiptLane != null)
                _actionButton(
                  key: const ValueKey(
                    'reports-partner-comparison-command-open-receipts',
                  ),
                  label: 'Open Receipt Board',
                  icon: Icons.receipt_long_rounded,
                  onTap: onOpenReceiptLane,
                ),
              _actionButton(
                key: const ValueKey(
                  'reports-partner-comparison-command-open-activity',
                ),
                label: 'OPEN ACTIVITY TRUTH DESK',
                icon: Icons.groups_rounded,
                onTap: onOpenActivityTruth,
              ),
              if (canOpenGovernance)
                _actionButton(
                  key: const ValueKey(
                    'reports-partner-comparison-command-open-governance',
                  ),
                  label: 'OPEN GOVERNANCE DESK',
                  icon: Icons.verified_user_rounded,
                  onTap: onOpenGovernance,
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
    final scopedReceiptRows = _partnerReceiptRowsForScope(
      clientId: row.clientId,
      siteId: row.siteId,
    );
    final currentChains = _partnerDispatchChainsForScope(
      clientId: row.clientId,
      siteId: row.siteId,
      partnerLabel: row.partnerLabel,
    );
    final siteActivity = _siteActivitySnapshot(
      clientId: row.clientId,
      siteId: row.siteId,
      reportDate: historyPoints.isEmpty ? null : historyPoints.first.reportDate,
    );
    final trendLabel = _partnerScopeTrendLabel(historyPoints);
    final trendReason = _partnerScopeTrendReason(historyPoints);
    final laneReason = trendReason.isNotEmpty
        ? trendReason
        : historyPoints.isEmpty
        ? 'No scored shift has landed yet. Use receipts, activity truth, or governance to anchor this lane while the first scorecard arrives.'
        : historyPoints.length == 1
        ? 'Single scored shift on record. Use the drill-in and receipts while this lane builds a baseline.'
        : '';
    final isActive = _partnerScoreboardMatchesFocus(row);
    final partnerGovernanceAction =
        widget.onOpenGovernanceForPartnerScope != null
        ? () => widget.onOpenGovernanceForPartnerScope!(
            row.clientId,
            row.siteId,
            row.partnerLabel,
          )
        : null;
    final genericGovernanceAction = _openGovernanceScopeAction(
      clientId: row.clientId,
      siteId: row.siteId,
    );
    final latestReceiptSummary = historyPoints.isEmpty
        ? null
        : historyPoints.first.receiptInvestigationSummary;
    final openReceiptLane = scopedReceiptRows.isEmpty
        ? null
        : () {
            setReportReceiptFilter(ReportReceiptSceneFilter.all);
            focusReportReceiptWorkspace(scopedReceiptRows.first.event.eventId);
            _showReceiptActionFeedback(
              'Recovered lane ${row.partnerLabel} around ${scopedReceiptRows.first.event.eventId}.',
            );
          };
    void openActivityTruth() => _openSiteActivityTruth(
      clientId: row.clientId,
      siteId: row.siteId,
      partnerLabel: row.partnerLabel,
    );
    void openDrillIn() => _openPartnerDrillIn(
      clientId: row.clientId,
      siteId: row.siteId,
      partnerLabel: row.partnerLabel,
    );
    final openEvents =
        widget.onOpenEventsForScope != null && currentChains.isNotEmpty
        ? () => _openEventsForPartnerDispatchChain(currentChains.first)
        : null;
    final openGovernance =
        partnerGovernanceAction != null || genericGovernanceAction != null
        ? () {
            if (partnerGovernanceAction != null) {
              partnerGovernanceAction();
            } else if (genericGovernanceAction != null) {
              genericGovernanceAction();
            }
            _showReceiptActionFeedback(
              'Opening Governance for ${row.siteId} • ${row.partnerLabel}.',
            );
          }
        : null;
    late final String primaryActionLabel;
    late final String primaryActionReason;
    late final IconData primaryActionIcon;
    late final VoidCallback primaryAction;
    if (latestReceiptSummary != null &&
        latestReceiptSummary.governanceHandoffCount >
            latestReceiptSummary.routineReviewCount &&
        openGovernance != null) {
      primaryActionLabel = 'Governance Desk';
      primaryActionReason =
          'Latest receipt pressure leans toward Governance Desk for this scope.';
      primaryActionIcon = Icons.verified_user_rounded;
      primaryAction = openGovernance;
    } else if (openEvents != null) {
      primaryActionLabel = 'Open Live Events';
      primaryActionReason =
          'A current dispatch chain is already active for this responder scope.';
      primaryActionIcon = Icons.timeline_rounded;
      primaryAction = openEvents;
    } else if (openReceiptLane != null) {
      primaryActionLabel = 'Open Receipt Board';
      primaryActionReason =
          'Receipts are already live for this scope, so the review rail is the fastest next move.';
      primaryActionIcon = Icons.receipt_long_rounded;
      primaryAction = openReceiptLane;
    } else if (siteActivity.totalSignals > 0) {
      primaryActionLabel = 'OPEN ACTIVITY TRUTH DESK';
      primaryActionReason =
          'Live activity signals are already present for this lane.';
      primaryActionIcon = Icons.groups_rounded;
      primaryAction = openActivityTruth;
    } else {
      primaryActionLabel = 'OPEN PARTNER DRILL-IN';
      primaryActionReason =
          'Use the drill-in to anchor this lane while deeper scorecard context forms.';
      primaryActionIcon = Icons.manage_search_rounded;
      primaryAction = openDrillIn;
    }
    return Container(
      key: ValueKey<String>(
        'reports-partner-lane-${row.clientId}/${row.siteId}/${row.partnerLabel}',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? const Color(0x1418D39E) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFF59D79B) : const Color(0xFFD6E1EC),
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
                        color: const Color(0xFF172638),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${row.clientId}/${row.siteId}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF7A8FA4),
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
              color: const Color(0xFF556B80),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _partnerScopeChip(
                label:
                    '${historyPoints.length} shift${historyPoints.length == 1 ? '' : 's'}',
                color: const Color(0xFF8FD1FF),
              ),
              if (scopedReceiptRows.isNotEmpty)
                _partnerScopeChip(
                  label:
                      '${scopedReceiptRows.length} receipt${scopedReceiptRows.length == 1 ? '' : 's'}',
                  color: const Color(0xFF5DC8FF),
                ),
              if (currentChains.isNotEmpty)
                _partnerScopeChip(
                  label:
                      '${currentChains.length} chain${currentChains.length == 1 ? '' : 's'}',
                  color: const Color(0xFFF6C067),
                ),
              _partnerScopeChip(
                label: siteActivity.totalSignals > 0
                    ? '${siteActivity.totalSignals} live signals'
                    : 'Activity truth ready',
                color: siteActivity.totalSignals > 0
                    ? const Color(0xFF59D79B)
                    : const Color(0xFF8EA4C2),
              ),
            ],
          ),
          if (laneReason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              laneReason,
              style: GoogleFonts.inter(
                color: const Color(0xFF556B80),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            key: ValueKey<String>(
              'reports-partner-lane-primary-${row.clientId}/${row.siteId}/${row.partnerLabel}',
            ),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFD),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD6E1EC)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommended next move',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF8FD1FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        primaryActionReason,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF556B80),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _actionButton(
                  key: ValueKey<String>(
                    'reports-partner-lane-primary-action-${row.clientId}/${row.siteId}/${row.partnerLabel}',
                  ),
                  label: primaryActionLabel,
                  icon: primaryActionIcon,
                  onTap: primaryAction,
                ),
              ],
            ),
          ),
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
              if (scopedReceiptRows.isNotEmpty)
                _actionButton(
                  key: ValueKey<String>(
                    'reports-partner-lane-open-receipts-${row.clientId}/${row.siteId}/${row.partnerLabel}',
                  ),
                  label: 'Open Receipt Board',
                  icon: Icons.receipt_long_rounded,
                  onTap: openReceiptLane,
                ),
              _actionButton(
                key: ValueKey<String>(
                  'reports-partner-lane-open-activity-${row.clientId}/${row.siteId}/${row.partnerLabel}',
                ),
                label: 'OPEN ACTIVITY TRUTH DESK',
                icon: Icons.groups_rounded,
                onTap: openActivityTruth,
              ),
              _actionButton(
                key: ValueKey<String>(
                  'reports-partner-lane-open-drill-in-${row.clientId}/${row.siteId}/${row.partnerLabel}',
                ),
                label: 'OPEN PARTNER DRILL-IN',
                icon: Icons.manage_search_rounded,
                onTap: openDrillIn,
              ),
              if (widget.onOpenEventsForScope != null &&
                  currentChains.isNotEmpty)
                _actionButton(
                  key: ValueKey<String>(
                    'reports-partner-lane-open-events-${row.clientId}/${row.siteId}/${row.partnerLabel}',
                  ),
                  label: 'OPEN EVENTS SCOPE',
                  icon: Icons.timeline_rounded,
                  onTap: openEvents,
                ),
              if (partnerGovernanceAction != null ||
                  genericGovernanceAction != null)
                _actionButton(
                  key: ValueKey<String>(
                    'reports-partner-lane-open-governance-${row.clientId}/${row.siteId}/${row.partnerLabel}',
                  ),
                  label: 'OPEN GOVERNANCE DESK',
                  icon: Icons.verified_user_rounded,
                  onTap: openGovernance,
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
      decoration: _reportsDrillInCardDecoration(radius: 10),
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
                    color: _reportsTitleColor,
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
              color: _reportsBodyColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (timingParts.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              timingParts.join(' • '),
              style: GoogleFonts.inter(
                color: _reportsMutedColor,
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
                color: _reportsMutedColor,
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
              label: 'OPEN EVENTS SCOPE',
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
    final reportDate = _formatDate(chain.latestOccurredAtUtc.toUtc());
    final eventIds = _partnerShiftEventIdsForScopeDate(
      clientId: chain.clientId,
      siteId: chain.siteId,
      partnerLabel: chain.partnerLabel,
      reportDate: reportDate,
    );
    final scopedEventIds = eventIds.isNotEmpty
        ? eventIds
        : _partnerDispatchChainEventIds(chain);
    final selectedEventId = scopedEventIds.isNotEmpty
        ? scopedEventIds.last
        : '';
    if (widget.onOpenEventsForScope == null || selectedEventId.isEmpty) {
      return;
    }
    widget.onOpenEventsForScope!(scopedEventIds, selectedEventId);
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
      return 'Receipt history is still forming for this client and site.';
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
    final baselineGovernanceCount = baselineRows
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
      baselineGovernanceAverage: baselineGovernanceCount / baselineRows.length,
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
      return 'Receipt investigation provenance has not been captured for this client and site yet.';
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
            : 'Governance Desk-routed receipt investigations increased against the recent baseline.';
      case 'OVERSIGHT EASING':
        return currentContext == ReportEntryContext.governanceBrandingDrift
            ? 'Governance Desk-routed receipt investigations eased against recent history.'
            : 'The latest receipt returned to routine review without a Governance Desk handoff.';
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
        return _reportsAccentSky;
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
        return _reportsAccentSky;
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

  String _partnerLatestShiftPostureLabel({
    required bool isLeader,
    required String primaryLabel,
  }) {
    switch (primaryLabel.trim().toUpperCase()) {
      case 'CRITICAL':
        return 'ACTION NOW';
      case 'WATCH':
        return 'WATCH CLOSELY';
      case 'ON TRACK':
        return isLeader ? 'PACE SETTER' : 'STEADY SHIFT';
      case 'STRONG':
        return isLeader ? 'BEST SHIFT' : 'SOLID SHIFT';
      default:
        return isLeader ? 'LEAD SHIFT' : 'OPEN SHIFT';
    }
  }

  String _partnerLatestShiftPostureSummary({
    required bool isLeader,
    required String primaryLabel,
  }) {
    switch (primaryLabel.trim().toUpperCase()) {
      case 'CRITICAL':
        return 'Latest shift needs immediate review before the lane slips further.';
      case 'WATCH':
        return 'Latest shift is still serviceable, but it needs closer supervision.';
      case 'ON TRACK':
        return isLeader
            ? 'Latest shift is setting the steady site baseline.'
            : 'Latest shift is stable, but still trails the site leader.';
      case 'STRONG':
        return isLeader
            ? 'Latest shift is currently setting the site pace.'
            : 'Latest shift is strong and worth comparing against the leader.';
      default:
        return isLeader
            ? 'Latest shift is leading with an incomplete score picture.'
            : 'Latest shift is active, but still needs score confirmation.';
    }
  }

  String _partnerLatestShiftGapDriverLabel(
    _PartnerComparisonRow comparison,
    _PartnerScopeHistoryPoint? latestPoint,
  ) {
    if (comparison.isLeader) {
      return 'SITE PACE';
    }
    final receiptSummary = latestPoint?.receiptInvestigationSummary;
    if (receiptSummary != null &&
        receiptSummary.governanceHandoffCount >
            receiptSummary.routineReviewCount) {
      return 'OVERSIGHT PRESSURE';
    }
    final acceptDelta = comparison.acceptDeltaMinutes ?? 0;
    final onSiteDelta = comparison.onSiteDeltaMinutes ?? 0;
    if (acceptDelta >= onSiteDelta && acceptDelta >= 2) {
      return 'ACCEPT LAG';
    }
    if (onSiteDelta > acceptDelta && onSiteDelta >= 2) {
      return 'ON-SITE LAG';
    }
    switch (comparison.trendLabel.trim().toUpperCase()) {
      case 'SLIPPING':
        return 'GAP OPENING';
      case 'IMPROVING':
        return 'GAP CLOSING';
      default:
        return 'BASELINE HOLD';
    }
  }

  String _partnerLatestShiftGapDriverSummary(
    _PartnerComparisonRow comparison,
    _PartnerScopeHistoryPoint? latestPoint,
  ) {
    if (comparison.isLeader) {
      return 'This lane is currently defining the site comparison pace.';
    }
    final receiptSummary = latestPoint?.receiptInvestigationSummary;
    if (receiptSummary != null &&
        receiptSummary.governanceHandoffCount >
            receiptSummary.routineReviewCount) {
      return 'Receipt investigations are leaning toward the Governance Desk on this shift.';
    }
    final acceptDelta = comparison.acceptDeltaMinutes ?? 0;
    final onSiteDelta = comparison.onSiteDeltaMinutes ?? 0;
    if (acceptDelta >= onSiteDelta && acceptDelta >= 2) {
      return 'The largest current gap versus the leader is acceptance timing.';
    }
    if (onSiteDelta > acceptDelta && onSiteDelta >= 2) {
      return 'The largest current gap versus the leader is on-site timing.';
    }
    switch (comparison.trendLabel.trim().toUpperCase()) {
      case 'SLIPPING':
        return 'The lane is slipping without one dominant timing culprit yet.';
      case 'IMPROVING':
        return 'The lane is closing the gap against the current leader.';
      default:
        return 'The lane is holding close to the current site baseline.';
    }
  }

  Color _partnerTrendColor(String label) {
    switch (label.trim().toUpperCase()) {
      case 'STRONG':
        return const Color(0xFF59D79B);
      case 'ON TRACK':
        return _reportsAccentSky;
      case 'WATCH':
        return const Color(0xFFF6C067);
      case 'CRITICAL':
        return const Color(0xFFFF7A7A);
      case 'IMPROVING':
        return const Color(0xFF59D79B);
      case 'SLIPPING':
        return const Color(0xFFFF7A7A);
      case 'STABLE':
        return _reportsAccentSky;
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
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 920;
            final title = Text(
              hasLiveReceipts ? 'Live Receipts' : 'Sample Receipts',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            );
            final controls = Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _receiptFilterControl(
                  value: _receiptFilter,
                  onChanged: setReportReceiptFilter,
                  rows: rows,
                ),
                _pillActionButton(
                  label: 'Export All',
                  icon: Icons.download_rounded,
                  buttonKey: const ValueKey('reports-export-all-button'),
                  onTap: () => _exportAllReceipts(filteredRows),
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 8), controls],
              );
            }
            return Row(
              children: [
                title,
                const Spacer(),
                Flexible(child: controls),
              ],
            );
          },
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
          const OnyxEmptyState(
            label:
                'Live report receipts will appear here once this board starts publishing them.',
          )
        else if (filteredRows.isEmpty)
          _filteredReceiptEmptyState(
            rows: rows,
            hasLiveReceipts: hasLiveReceipts,
          )
        else
          for (var i = 0; i < filteredRows.length; i++) ...[
            _receiptCard(filteredRows[i], hasLiveReceipts: hasLiveReceipts),
            if (i < filteredRows.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _filteredReceiptEmptyState({
    required List<_ReceiptRow> rows,
    required bool hasLiveReceipts,
  }) {
    final availableCount = rows.length;
    final recoveryFilters = _receiptHistoryRecoveryFilters(rows);
    final receiptLabel =
        '${hasLiveReceipts ? 'live' : 'sample'} receipt${availableCount == 1 ? '' : 's'}';
    final focusLabel = recoveryFilters.isEmpty
        ? null
        : recoveryFilters.first.label.toLowerCase();
    final detail = focusLabel == null
        ? '$availableCount $receiptLabel are still available in this Reports Workspace. Reset the receipt filter to recover the preview and delivery handoff.'
        : '$availableCount $receiptLabel are still available in this Reports Workspace. Reset the filter or pivot straight into $focusLabel to keep the preview and delivery handoff moving.';

    return Container(
      key: const ValueKey('reports-history-empty-state'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _receiptFilter.bannerBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _receiptFilter.bannerBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No receipts fit the current filter right now.',
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF1FB),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: const Color(0xFF9DB1CF),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('reports-history-empty-open-all'),
                onPressed: () =>
                    setReportReceiptFilter(ReportReceiptSceneFilter.all),
                icon: const Icon(Icons.reorder_rounded, size: 18),
                label: const Text('All Receipts'),
              ),
              for (final filter in recoveryFilters.take(2))
                OutlinedButton.icon(
                  key: ValueKey<String>(
                    'reports-history-empty-open-${filter.name}',
                  ),
                  onPressed: () => setReportReceiptFilter(filter),
                  icon: Icon(_receiptFilterIcon(filter), size: 18),
                  label: Text(filter.label),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<ReportReceiptSceneFilter> _receiptHistoryRecoveryFilters(
    List<_ReceiptRow> rows,
  ) {
    const candidates = [
      ReportReceiptSceneFilter.reviewed,
      ReportReceiptSceneFilter.alerts,
      ReportReceiptSceneFilter.repeat,
      ReportReceiptSceneFilter.escalation,
      ReportReceiptSceneFilter.suppressed,
      ReportReceiptSceneFilter.pending,
    ];
    final scored =
        <({ReportReceiptSceneFilter filter, int count, int order})>[];
    for (var index = 0; index < candidates.length; index++) {
      final filter = candidates[index];
      if (filter == _receiptFilter) {
        continue;
      }
      final count = _receiptCountForFilter(rows, filter);
      if (count > 0) {
        scored.add((filter: filter, count: count, order: index));
      }
    }
    scored.sort((a, b) {
      final countCompare = b.count.compareTo(a.count);
      if (countCompare != 0) {
        return countCompare;
      }
      return a.order.compareTo(b.order);
    });
    return scored.map((entry) => entry.filter).toList();
  }

  int _receiptCountForFilter(
    List<_ReceiptRow> rows,
    ReportReceiptSceneFilter filter,
  ) {
    return rows.where((row) => filter.matches(row.sceneReviewSummary)).length;
  }

  IconData _receiptFilterIcon(ReportReceiptSceneFilter filter) {
    return switch (filter) {
      ReportReceiptSceneFilter.all => Icons.reorder_rounded,
      ReportReceiptSceneFilter.alerts ||
      ReportReceiptSceneFilter.latestAlerts => Icons.warning_amber_rounded,
      ReportReceiptSceneFilter.repeat ||
      ReportReceiptSceneFilter.latestRepeat => Icons.autorenew_rounded,
      ReportReceiptSceneFilter.escalation ||
      ReportReceiptSceneFilter.latestEscalation => Icons.north_rounded,
      ReportReceiptSceneFilter.suppressed ||
      ReportReceiptSceneFilter.latestSuppressed => Icons.visibility_off_rounded,
      ReportReceiptSceneFilter.reviewed => Icons.fact_check_rounded,
      ReportReceiptSceneFilter.pending => Icons.pending_actions_rounded,
    };
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
                      style: GoogleFonts.inter(
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
        color: isSelected ? const Color(0xFFF7FBFF) : const Color(0xFFF1F6FB),
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
                      style: GoogleFonts.inter(
                        color: const Color(0xFF10233A),
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      siteName,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF5F7388),
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
              color: const Color(0xFFE3ECF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sectionColor.withValues(alpha: 0.38)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report Configuration',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF10233A),
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
                    color: const Color(0xFF52667C),
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
              color: const Color(0xFF5F7388),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final governanceReceiptActions =
                  _entryContext == ReportEntryContext.governanceBrandingDrift;
              final previewLabel = governanceReceiptActions
                  ? 'Governance Preview'
                  : 'Preview';
              final copyLabel = governanceReceiptActions
                  ? 'Governance Copy'
                  : 'Copy';
              final downloadLabel = governanceReceiptActions
                  ? 'Governance Download'
                  : 'Download';
              return Row(
                children: [
                  Expanded(
                    child: _pillActionButton(
                      label: previewLabel,
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
                      label: copyLabel,
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
                      label: downloadLabel,
                      icon: Icons.download_rounded,
                      buttonKey: ValueKey<String>(
                        'report-receipt-download-${row.event.eventId}',
                      ),
                      onTap: () => _downloadReceipt(row, hasLiveReceipts),
                      filled: true,
                    ),
                  ),
                ],
              );
            },
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
      textColor: _reportsTitleColor,
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
          backgroundColor: _reportsPanelColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: _reportsBorderColor),
          ),
          title: Text(
            'Edit Client Branding',
            style: GoogleFonts.inter(
              color: _reportsTitleColor,
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
                    color: _reportsBodyColor,
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
                  style: GoogleFonts.inter(
                    color: _reportsTitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Primary client-facing label',
                    hintText: 'VISION Tactical',
                    filled: true,
                    fillColor: _reportsPanelAltColor,
                    labelStyle: GoogleFonts.inter(
                      color: _reportsMutedColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    hintStyle: GoogleFonts.inter(
                      color: _reportsMutedColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _reportsBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF7EA9D0)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('reports-branding-endorsement-field'),
                  initialValue: draftEndorsement,
                  onChanged: (value) => draftEndorsement = value,
                  style: GoogleFonts.inter(
                    color: _reportsTitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Endorsement line',
                    hintText: 'Powered by ONYX',
                    filled: true,
                    fillColor: _reportsPanelAltColor,
                    labelStyle: GoogleFonts.inter(
                      color: _reportsMutedColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    hintStyle: GoogleFonts.inter(
                      color: _reportsMutedColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _reportsBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF7EA9D0)),
                    ),
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
    if (!mounted || saved != true) {
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

  _ReceiptRow? _receiptWorkspaceRecoveryTarget(
    List<_ReceiptRow> rows, {
    required ReportReceiptSceneFilter filter,
  }) {
    final scopedRows = filter == ReportReceiptSceneFilter.all
        ? rows
        : rows
              .where((row) => filter.matches(row.sceneReviewSummary))
              .toList(growable: false);
    if (scopedRows.isEmpty) {
      return null;
    }
    return _targetReceiptByEventId(scopedRows, _previewReceiptEventId) ??
        _targetReceiptByEventId(scopedRows, _selectedReceiptEventId) ??
        scopedRows.first;
  }

  void _recoverReceiptWorkspace(
    List<_ReceiptRow> rows, {
    required ReportReceiptSceneFilter filter,
  }) {
    final target = _receiptWorkspaceRecoveryTarget(rows, filter: filter);
    if (target == null) {
      return;
    }
    setReportReceiptFilter(filter);
    focusReportReceiptWorkspace(target.event.eventId);
    _showReceiptActionFeedback(
      filter == ReportReceiptSceneFilter.all
          ? 'Receipt board recovered around ${target.event.eventId}.'
          : '${filter.label} board opened around ${target.event.eventId}.',
    );
  }

  Widget _previewTargetBanner({
    required String eventId,
    required _ReceiptRow? row,
    required bool hasLiveReceipts,
  }) {
    final governanceTarget =
        _entryContext == ReportEntryContext.governanceBrandingDrift;
    return ReportPreviewTargetBanner(
      eventId: eventId,
      previewSurface: _previewSurface,
      surfaceLabelColor: const Color(0xFF8EA4C2),
      onOpen: row == null ? null : () => _previewReceipt(row, hasLiveReceipts),
      onCopy: row == null ? null : () => _copyReceipt(row),
      onClear: clearReportPreviewTarget,
      openLabel: governanceTarget
          ? 'OPEN GOVERNANCE PREVIEW DOCK'
          : 'OPEN PREVIEW TARGET',
      copyLabel: governanceTarget ? 'Copy Governance Receipt' : null,
      clearLabel: governanceTarget ? 'Clear Governance Target' : null,
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
    final governanceDock =
        _entryContext == ReportEntryContext.governanceBrandingDrift;
    final openLabel = governanceDock
        ? 'OPEN GOVERNANCE PREVIEW DOCK'
        : 'OPEN PREVIEW DOCK';
    final copyLabel = governanceDock
        ? 'Copy Governance Receipt'
        : 'Copy Receipt';
    final downloadLabel = governanceDock
        ? 'Download Governance PDF'
        : 'Download Receipt';

    return ReportPreviewDockCard(
      eventId: row.event.eventId,
      detail: '$siteName • $period',
      title: governanceDock ? 'Governance Preview Dock' : null,
      subtitle: governanceDock
          ? 'Governance Desk preview target held in the Reports Workspace.'
          : null,
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
        label: openLabel,
        icon: Icons.open_in_new_rounded,
        buttonKey: const ValueKey('reports-preview-dock-open'),
        onTap: () => _previewReceipt(row, hasLiveReceipts),
      ),
      secondaryAction: _pillActionButton(
        label: copyLabel,
        icon: Icons.copy_all_rounded,
        buttonKey: const ValueKey('reports-preview-dock-copy'),
        onTap: () => _copyReceipt(row),
      ),
      tertiaryAction: _pillActionButton(
        label: downloadLabel,
        icon: Icons.download_rounded,
        buttonKey: const ValueKey('reports-preview-dock-download'),
        onTap: () => _downloadReceipt(row, hasLiveReceipts),
      ),
      quaternaryAction: _pillActionButton(
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
      isExpanded: true,
      onChanged: onChanged,
      iconEnabledColor: const Color(0xFF8EA4C2),
      dropdownColor: _reportsPanelColor,
      style: GoogleFonts.inter(
        color: _reportsTitleColor,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: _reportsPanelAltColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _reportsBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: OnyxDesignTokens.accentBlue),
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
              color: _reportsPanelColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _reportsBorderColor),
            ),
            child: Text(
              _formatDate(date),
              style: GoogleFonts.inter(
                color: _reportsTitleColor,
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
          color: selected ? OnyxDesignTokens.cyanSurface : _reportsPanelColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? OnyxDesignTokens.cyanBorder : _reportsBorderColor,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: selected ? OnyxDesignTokens.accentBlue : _reportsBodyColor,
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
      activeColor: OnyxDesignTokens.accentBlue,
      checkColor: OnyxDesignTokens.textPrimary,
      title: Text(
        label,
        style: GoogleFonts.inter(
          color: _reportsTitleColor,
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
            ? OnyxDesignTokens.accentBlue
            : OnyxDesignTokens.cyanSurface,
        foregroundColor: filled
            ? OnyxDesignTokens.textPrimary
            : OnyxDesignTokens.accentBlue,
        disabledBackgroundColor: _reportsPanelAltColor,
        disabledForegroundColor: _reportsMutedColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: filled ? OnyxDesignTokens.accentBlue : _reportsBorderColor,
          ),
        ),
      ),
      icon: Icon(icon, size: 15),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _exportAllReceipts(List<_ReceiptRow> rows) async {
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
    await _exportCoordinator.copyJson(payload, label: 'reports.export_all');
    _showReceiptActionFeedback(
      'Exported ${rows.length} receipt records to clipboard.',
    );
  }

  Future<void> _copyPartnerScopeJson() async {
    final payload = _partnerScopeExportPayload();
    await _exportCoordinator.copyJson(
      payload,
      label: 'reports.copy_partner_scorecard_json',
    );
    _showReceiptActionFeedback('Partner scorecard JSON copied.');
  }

  Future<void> _copyPartnerScopeCsv() async {
    await _exportCoordinator.copyCsv(
      LineSplitter.split(_partnerScopeExportCsv()).toList(growable: false),
      label: 'reports.copy_partner_scorecard_csv',
    );
    _showReceiptActionFeedback('Partner scorecard CSV copied.');
  }

  Future<void> _copyPartnerDrillInJson({
    required String clientId,
    required String siteId,
    required String partnerLabel,
  }) async {
    final payload = _partnerScopeExportPayloadFor(
      clientId: clientId,
      siteId: siteId,
      partnerLabel: partnerLabel,
    );
    await _exportCoordinator.copyJson(
      payload,
      label: 'reports.copy_partner_drill_in_json',
    );
    _showReceiptActionFeedback('Partner drill-in JSON copied.');
  }

  Future<void> _copyPartnerDrillInCsv({
    required String clientId,
    required String siteId,
    required String partnerLabel,
  }) async {
    await _exportCoordinator.copyCsv(
      LineSplitter.split(
        _partnerScopeExportCsvFor(
          clientId: clientId,
          siteId: siteId,
          partnerLabel: partnerLabel,
        ),
      ).toList(growable: false),
      label: 'reports.copy_partner_drill_in_csv',
    );
    _showReceiptActionFeedback('Partner drill-in CSV copied.');
  }

  Future<void> _copyPartnerComparisonJson() async {
    final payload = _partnerComparisonExportPayload();
    await _exportCoordinator.copyJson(
      payload,
      label: 'reports.copy_partner_comparison_json',
    );
    _showReceiptActionFeedback('Partner comparison JSON copied.');
  }

  Future<void> _copyPartnerComparisonCsv() async {
    await _exportCoordinator.copyCsv(
      LineSplitter.split(_partnerComparisonExportCsv()).toList(growable: false),
      label: 'reports.copy_partner_comparison_csv',
    );
    _showReceiptActionFeedback('Partner comparison CSV copied.');
  }

  Future<void> _copyReceiptPolicyHistoryJson(List<_ReceiptRow> rows) async {
    final payload = _receiptPolicyHistoryExportPayload(rows);
    await _exportCoordinator.copyJson(
      payload,
      label: 'reports.copy_receipt_policy_json',
    );
    _showReceiptActionFeedback('Receipt policy JSON copied.');
  }

  Future<void> _copyReceiptPolicyHistoryCsv(List<_ReceiptRow> rows) async {
    await _exportCoordinator.copyCsv(
      LineSplitter.split(
        _receiptPolicyHistoryExportCsv(rows),
      ).toList(growable: false),
      label: 'reports.copy_receipt_policy_csv',
    );
    _showReceiptActionFeedback('Receipt policy CSV copied.');
  }

  Future<void> _copyPartnerShiftJson(_PartnerScopeHistoryPoint point) async {
    final payload = _partnerShiftExportPayload(point);
    await _exportCoordinator.copyJson(
      payload,
      label: 'reports.copy_partner_shift_json',
    );
    _showReceiptActionFeedback('Partner shift JSON copied.');
  }

  Future<void> _copyPartnerShiftCsv(_PartnerScopeHistoryPoint point) async {
    await _exportCoordinator.copyCsv(
      LineSplitter.split(_partnerShiftExportCsv(point)).toList(growable: false),
      label: 'reports.copy_partner_shift_csv',
    );
    _showReceiptActionFeedback('Partner shift CSV copied.');
  }

  Future<void> _copySiteActivityTruthJson({
    required String clientId,
    required String siteId,
    String? partnerLabel,
  }) async {
    final payload = _siteActivityTruthExportPayload(
      clientId: clientId,
      siteId: siteId,
      partnerLabel: partnerLabel,
    );
    await _exportCoordinator.copyJson(
      payload,
      label: 'reports.copy_site_activity_truth_json',
    );
    _showReceiptActionFeedback('Activity truth JSON copied.');
  }

  Future<void> _copySiteActivityTruthCsv({
    required String clientId,
    required String siteId,
    String? partnerLabel,
  }) async {
    await _exportCoordinator.copyCsv(
      LineSplitter.split(
        _siteActivityTruthExportCsv(
          clientId: clientId,
          siteId: siteId,
          partnerLabel: partnerLabel,
        ),
      ).toList(growable: false),
      label: 'reports.copy_site_activity_truth_csv',
    );
    _showReceiptActionFeedback('Activity truth CSV copied.');
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
    final receiptInvestigationComparison = _receiptInvestigationComparison(
      receiptRows,
    );
    _PartnerScopeHistoryPoint? currentPoint;
    for (final point in historyPoints) {
      if (point.current) {
        currentPoint = point;
        break;
      }
    }
    currentPoint ??= historyPoints.isEmpty ? null : historyPoints.first;
    final siteActivity = _siteActivitySnapshot(
      clientId: clientId,
      siteId: siteId,
      reportDate: currentPoint?.reportDate,
    );
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
      'siteActivity': _siteActivitySnapshotJson(siteActivity),
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
    final siteActivity = _siteActivitySnapshot(
      clientId: point.row.clientId,
      siteId: point.row.siteId,
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
      'siteActivity': _siteActivitySnapshotJson(siteActivity),
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
      'dispatchChains': chains
          .map((chain) => chain.toJson())
          .toList(growable: false),
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
    final siteActivity = _siteActivitySnapshot(
      clientId: point.row.clientId,
      siteId: point.row.siteId,
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
      'site_activity_total_signals,${siteActivity.totalSignals}',
      'site_activity_people,${siteActivity.personSignals}',
      'site_activity_vehicles,${siteActivity.vehicleSignals}',
      'site_activity_known_ids,${siteActivity.knownIdentitySignals}',
      'site_activity_flagged_ids,${siteActivity.flaggedIdentitySignals}',
      'site_activity_unknown_signals,${siteActivity.unknownPersonSignals + siteActivity.unknownVehicleSignals}',
      'site_activity_long_presence,${siteActivity.longPresenceSignals}',
      'site_activity_guard_interactions,${siteActivity.guardInteractionSignals}',
      'site_activity_summary,"${siteActivity.summaryLine.replaceAll('"', '""')}"',
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

  List<_SiteActivityHistoryPoint> _siteActivityHistoryPointsFor({
    required String clientId,
    required String siteId,
  }) {
    final scopedEvents = widget.store
        .allEvents()
        .whereType<IntelligenceReceived>()
        .where(
          (event) =>
              event.clientId.trim() == clientId &&
              event.siteId.trim() == siteId &&
              ((event.sourceType.trim().toLowerCase() == 'dvr') ||
                  (event.sourceType.trim().toLowerCase() == 'cctv')),
        )
        .toList(growable: false);
    if (scopedEvents.isEmpty) {
      return const <_SiteActivityHistoryPoint>[];
    }
    final grouped = <String, List<IntelligenceReceived>>{};
    for (final event in scopedEvents) {
      final reportDate = _formatDate(event.occurredAt.toUtc());
      grouped
          .putIfAbsent(reportDate, () => <IntelligenceReceived>[])
          .add(event);
    }
    final reportDates = grouped.keys.toList(growable: false)
      ..sort((a, b) => b.compareTo(a));
    final latestDate = reportDates.first;
    return reportDates
        .map((reportDate) {
          final snapshot = _siteActivitySnapshot(
            clientId: clientId,
            siteId: siteId,
            reportDate: reportDate,
          );
          final eventIds = grouped[reportDate]!.toList(growable: false)
            ..sort(
              (a, b) => _compareDispatchEventsByOccurredAtThenSequence(a, b),
            );
          return _SiteActivityHistoryPoint(
            reportDate: reportDate,
            clientId: clientId,
            siteId: siteId,
            current: reportDate == latestDate,
            snapshot: snapshot,
            eventIds: eventIds
                .map((event) => event.eventId)
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  SiteActivityIntelligenceSnapshot _siteActivitySnapshot({
    required String? clientId,
    required String? siteId,
    String? reportDate,
  }) {
    final scopedClientId = clientId?.trim();
    final scopedSiteId = siteId?.trim();
    if (scopedClientId == null ||
        scopedClientId.isEmpty ||
        scopedSiteId == null ||
        scopedSiteId.isEmpty) {
      return const SiteActivityIntelligenceSnapshot(
        totalSignals: 0,
        personSignals: 0,
        vehicleSignals: 0,
        knownIdentitySignals: 0,
        flaggedIdentitySignals: 0,
        unknownPersonSignals: 0,
        unknownVehicleSignals: 0,
        longPresenceSignals: 0,
        guardInteractionSignals: 0,
        summaryLine:
            'No visitor or site-activity signals landed in this window.',
      );
    }
    DateTime? startUtc;
    DateTime? endUtc;
    final trimmedDate = reportDate?.trim();
    if (trimmedDate != null && trimmedDate.isNotEmpty) {
      final parsed = DateTime.tryParse(trimmedDate);
      if (parsed != null) {
        startUtc = DateTime.utc(parsed.year, parsed.month, parsed.day);
        endUtc = startUtc.add(const Duration(days: 1));
      }
    }
    return _siteActivityService.buildSnapshot(
      events: widget.store.allEvents(),
      startUtc: startUtc,
      endUtc: endUtc,
      clientId: scopedClientId,
      siteId: scopedSiteId,
    );
  }

  void _openEventsForSiteActivityPoint(_SiteActivityHistoryPoint point) {
    if (widget.onOpenEventsForScope == null || point.eventIds.isEmpty) {
      return;
    }
    widget.onOpenEventsForScope!(point.eventIds, point.eventIds.last);
    _showReceiptActionFeedback(
      'Opening Events Review for ${point.reportDate} site activity.',
    );
  }

  Map<String, Object?> _siteActivitySnapshotJson(
    SiteActivityIntelligenceSnapshot snapshot,
  ) {
    return <String, Object?>{
      'totalSignals': snapshot.totalSignals,
      'personSignals': snapshot.personSignals,
      'vehicleSignals': snapshot.vehicleSignals,
      'knownIdentitySignals': snapshot.knownIdentitySignals,
      'flaggedIdentitySignals': snapshot.flaggedIdentitySignals,
      'unknownSignals':
          snapshot.unknownPersonSignals + snapshot.unknownVehicleSignals,
      'unknownPersonSignals': snapshot.unknownPersonSignals,
      'unknownVehicleSignals': snapshot.unknownVehicleSignals,
      'longPresenceSignals': snapshot.longPresenceSignals,
      'guardInteractionSignals': snapshot.guardInteractionSignals,
      'summaryLine': snapshot.summaryLine,
    };
  }

  String _siteActivityReviewCommand({
    required String clientId,
    required String siteId,
    required String reportDate,
  }) {
    return '/activityreview $clientId $siteId $reportDate';
  }

  String _siteActivityCaseFileCommand({
    required String clientId,
    required String siteId,
    required String reportDate,
  }) {
    return '/activitycase json $clientId $siteId $reportDate';
  }

  Map<String, Object?> _siteActivityTruthExportPayload({
    required String clientId,
    required String siteId,
    String? partnerLabel,
  }) {
    final historyPoints = _siteActivityHistoryPointsFor(
      clientId: clientId,
      siteId: siteId,
    );
    final currentPoint = historyPoints.isEmpty ? null : historyPoints.first;
    final previousPoint = historyPoints.length > 1 ? historyPoints[1] : null;
    return <String, Object?>{
      'scope': <String, Object?>{
        'clientId': clientId,
        'siteId': siteId,
        if (partnerLabel != null && partnerLabel.trim().isNotEmpty)
          'partnerLabel': partnerLabel,
      },
      'reviewShortcuts': buildReviewShortcuts(
        currentReportDate: currentPoint?.reportDate ?? '',
        previousReportDate: previousPoint?.reportDate,
        reviewCommandBuilder: (reportDate) => _siteActivityReviewCommand(
          clientId: clientId,
          siteId: siteId,
          reportDate: reportDate,
        ),
        caseFileCommandBuilder: (reportDate) => _siteActivityCaseFileCommand(
          clientId: clientId,
          siteId: siteId,
          reportDate: reportDate,
        ),
      ),
      'currentTruth': currentPoint == null
          ? null
          : <String, Object?>{
              'reportDate': currentPoint.reportDate,
              'current': currentPoint.current,
              'snapshot': _siteActivitySnapshotJson(currentPoint.snapshot),
              'eventIds': currentPoint.eventIds,
              ...buildReviewCommandPair(
                reportDate: currentPoint.reportDate,
                reviewCommandBuilder: (reportDate) =>
                    _siteActivityReviewCommand(
                      clientId: clientId,
                      siteId: siteId,
                      reportDate: reportDate,
                    ),
                caseFileCommandBuilder: (reportDate) =>
                    _siteActivityCaseFileCommand(
                      clientId: clientId,
                      siteId: siteId,
                      reportDate: reportDate,
                    ),
              ),
            },
      'history': historyPoints
          .map(
            (point) => <String, Object?>{
              'reportDate': point.reportDate,
              'current': point.current,
              'snapshot': _siteActivitySnapshotJson(point.snapshot),
              'eventIds': point.eventIds,
              ...buildReviewCommandPair(
                reportDate: point.reportDate,
                reviewCommandBuilder: (reportDate) =>
                    _siteActivityReviewCommand(
                      clientId: clientId,
                      siteId: siteId,
                      reportDate: reportDate,
                    ),
                caseFileCommandBuilder: (reportDate) =>
                    _siteActivityCaseFileCommand(
                      clientId: clientId,
                      siteId: siteId,
                      reportDate: reportDate,
                    ),
              ),
            },
          )
          .toList(growable: false),
    };
  }

  String _siteActivityTruthExportCsv({
    required String clientId,
    required String siteId,
    String? partnerLabel,
  }) {
    final historyPoints = _siteActivityHistoryPointsFor(
      clientId: clientId,
      siteId: siteId,
    );
    final currentPoint = historyPoints.isEmpty ? null : historyPoints.first;
    final previousPoint = historyPoints.length > 1 ? historyPoints[1] : null;
    final lines = <String>[
      'metric,value',
      'client_id,$clientId',
      'site_id,$siteId',
      if (partnerLabel != null && partnerLabel.trim().isNotEmpty)
        'partner_label,"${partnerLabel.replaceAll('"', '""')}"',
      if (currentPoint != null)
        'current_report_date,${currentPoint.reportDate}',
      ...buildReviewShortcutCsvRows(
        currentReportDate: currentPoint?.reportDate ?? '',
        previousReportDate: previousPoint?.reportDate,
        currentReviewMetric: 'current_review_command',
        currentCaseMetric: 'current_case_file_command',
        previousReviewMetric: 'previous_review_command',
        previousCaseMetric: 'previous_case_file_command',
        reviewCommandBuilder: (reportDate) => _siteActivityReviewCommand(
          clientId: clientId,
          siteId: siteId,
          reportDate: reportDate,
        ),
        caseFileCommandBuilder: (reportDate) => _siteActivityCaseFileCommand(
          clientId: clientId,
          siteId: siteId,
          reportDate: reportDate,
        ),
      ),
      if (previousPoint != null)
        'previous_report_date,${previousPoint.reportDate}',
      if (currentPoint != null)
        'current_total_signals,${currentPoint.snapshot.totalSignals}',
      if (currentPoint != null)
        'current_people,${currentPoint.snapshot.personSignals}',
      if (currentPoint != null)
        'current_vehicles,${currentPoint.snapshot.vehicleSignals}',
      if (currentPoint != null)
        'current_known_ids,${currentPoint.snapshot.knownIdentitySignals}',
      if (currentPoint != null)
        'current_flagged_ids,${currentPoint.snapshot.flaggedIdentitySignals}',
      if (currentPoint != null)
        'current_unknown_signals,${currentPoint.snapshot.unknownPersonSignals + currentPoint.snapshot.unknownVehicleSignals}',
      if (currentPoint != null)
        'current_long_presence,${currentPoint.snapshot.longPresenceSignals}',
      if (currentPoint != null)
        'current_guard_interactions,${currentPoint.snapshot.guardInteractionSignals}',
      if (currentPoint != null)
        'current_summary,"${currentPoint.snapshot.summaryLine.replaceAll('"', '""')}"',
    ];
    for (var index = 0; index < historyPoints.length; index++) {
      final point = historyPoints[index];
      lines.add(
        'history_${index + 1},"${point.reportDate} • ${point.current ? 'CURRENT' : 'HISTORY'} • ${point.snapshot.summaryLine.replaceAll('"', '""')}"',
      );
      for (
        var eventIndex = 0;
        eventIndex < point.eventIds.length;
        eventIndex++
      ) {
        lines.add(
          'history_${index + 1}_event_${eventIndex + 1},${point.eventIds[eventIndex]}',
        );
      }
      lines.add(
        'history_${index + 1}_review_command,${_siteActivityReviewCommand(clientId: clientId, siteId: siteId, reportDate: point.reportDate)}',
      );
      lines.addAll(
        buildHistoryReviewCommandCsvRows(
          row: index + 1,
          reportDate: point.reportDate,
          reviewCommandBuilder: (reportDate) => _siteActivityReviewCommand(
            clientId: clientId,
            siteId: siteId,
            reportDate: reportDate,
          ),
          caseFileCommandBuilder: (reportDate) => _siteActivityCaseFileCommand(
            clientId: clientId,
            siteId: siteId,
            reportDate: reportDate,
          ),
        ).skip(1),
      );
    }
    return lines.join('\n');
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
    final siteActivity = _siteActivitySnapshot(
      clientId: widget.selectedClient,
      siteId: widget.selectedSite,
    );
    final receiptInvestigationComparison = _receiptInvestigationComparison(
      receiptRows,
    );
    return <String, Object?>{
      'scope': <String, Object?>{
        'clientId': widget.selectedClient,
        'siteId': widget.selectedSite,
      },
      'comparisonWindow': _partnerComparisonWindow.name,
      'activePartnerLabel': _partnerScopePartnerLabel,
      'siteActivity': _siteActivitySnapshotJson(siteActivity),
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
    _PartnerScopeHistoryPoint? currentPoint;
    for (final point in historyPoints) {
      if (point.current) {
        currentPoint = point;
        break;
      }
    }
    currentPoint ??= historyPoints.isEmpty ? null : historyPoints.first;
    final siteActivity = _siteActivitySnapshot(
      clientId: clientId,
      siteId: siteId,
      reportDate: currentPoint?.reportDate,
    );
    final receiptInvestigationComparison = _receiptInvestigationComparison(
      receiptRows,
    );
    final lines = <String>[
      'metric,value',
      'client_id,$clientId',
      'site_id,$siteId',
      'partner_label,"${partnerLabel.replaceAll('"', '""')}"',
      'trend_label,${_partnerScopeTrendLabel(historyPoints)}',
      'trend_reason,"${_partnerScopeTrendReason(historyPoints).replaceAll('"', '""')}"',
      'site_activity_total_signals,${siteActivity.totalSignals}',
      'site_activity_people,${siteActivity.personSignals}',
      'site_activity_vehicles,${siteActivity.vehicleSignals}',
      'site_activity_known_ids,${siteActivity.knownIdentitySignals}',
      'site_activity_flagged_ids,${siteActivity.flaggedIdentitySignals}',
      'site_activity_unknown_signals,${siteActivity.unknownPersonSignals + siteActivity.unknownVehicleSignals}',
      'site_activity_long_presence,${siteActivity.longPresenceSignals}',
      'site_activity_guard_interactions,${siteActivity.guardInteractionSignals}',
      'site_activity_summary,"${siteActivity.summaryLine.replaceAll('"', '""')}"',
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
    final siteActivity = _siteActivitySnapshot(
      clientId: widget.selectedClient,
      siteId: widget.selectedSite,
    );
    final receiptInvestigationComparison = _receiptInvestigationComparison(
      receiptRows,
    );
    final lines = <String>[
      'metric,value',
      'client_id,${widget.selectedClient}',
      'site_id,${widget.selectedSite}',
      'comparison_window,${_partnerComparisonWindow.name}',
      'active_partner_label,"${(_partnerScopePartnerLabel ?? '').replaceAll('"', '""')}"',
      'site_activity_total_signals,${siteActivity.totalSignals}',
      'site_activity_people,${siteActivity.personSignals}',
      'site_activity_vehicles,${siteActivity.vehicleSignals}',
      'site_activity_known_ids,${siteActivity.knownIdentitySignals}',
      'site_activity_flagged_ids,${siteActivity.flaggedIdentitySignals}',
      'site_activity_unknown_signals,${siteActivity.unknownPersonSignals + siteActivity.unknownVehicleSignals}',
      'site_activity_long_presence,${siteActivity.longPresenceSignals}',
      'site_activity_guard_interactions,${siteActivity.guardInteractionSignals}',
      'site_activity_summary,"${siteActivity.summaryLine.replaceAll('"', '""')}"',
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

  void _showReceiptActionFeedback(
    String message, {
    String label = 'REPORTS ACTION',
    String? detail,
    Color accent = _reportsAccentSky,
  }) {
    if (!mounted) {
      return;
    }
    if (_desktopWorkspaceActive) {
      setState(() {
        _commandReceipt = _ReportsCommandReceipt(
          label: label,
          message: message,
          detail:
              detail ??
              'The latest reports command remains pinned in the delivery rail while you continue working the receipt board.',
          accent: accent,
        );
      });
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: _reportsPanelColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _reportsBorderColor),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: _reportsTitleColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _receiptExportFeedbackPrefix(ReportGenerated event) {
    return _effectiveEntryContextForReceipt(event) ==
            ReportEntryContext.governanceBrandingDrift
        ? 'Governance receipt export'
        : 'Receipt export';
  }

  String _receiptMetadataFeedbackPrefix(ReportGenerated event) {
    return _effectiveEntryContextForReceipt(event) ==
            ReportEntryContext.governanceBrandingDrift
        ? 'Governance receipt metadata'
        : 'Sample receipt metadata';
  }

  Future<void> _copyReceipt(_ReceiptRow row) async {
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
    await _exportCoordinator.copyJson(
      payload,
      label: 'reports.copy_receipt',
    );
    _showReceiptActionFeedback(
      '${_receiptExportFeedbackPrefix(row.event)} copied for command review: ${row.event.eventId}.',
    );
  }

  Future<void> _previewReceipt(_ReceiptRow row, bool hasLiveReceipts) async {
    if (!hasLiveReceipts) {
      logUiAction(
        'reports.preview_sample_receipt',
        context: {'event_id': row.event.eventId},
      );
      _showReceiptActionFeedback(
        'Receipt preview will unlock once the first live report lands on this board.',
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
      await _exportCoordinator.copyJson(
        payload,
        label: 'reports.download_sample_receipt',
      );
      _showReceiptActionFeedback(
        '${_receiptMetadataFeedbackPrefix(row.event)} copied for command review: ${row.event.eventId}.',
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
        backgroundColor: OnyxDesignTokens.cyanSurface,
        foregroundColor: OnyxDesignTokens.accentBlue,
        disabledBackgroundColor: _reportsPanelAltColor,
        disabledForegroundColor: _reportsMutedColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: _reportsBorderColor),
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
    if (!mounted || picked == null) {
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

class _SiteActivityHistoryPoint {
  final String reportDate;
  final String clientId;
  final String siteId;
  final bool current;
  final SiteActivityIntelligenceSnapshot snapshot;
  final List<String> eventIds;

  const _SiteActivityHistoryPoint({
    required this.reportDate,
    required this.clientId,
    required this.siteId,
    required this.current,
    required this.snapshot,
    required this.eventIds,
  });
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
