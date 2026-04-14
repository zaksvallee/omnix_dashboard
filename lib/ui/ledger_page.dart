import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/report_entry_context.dart';
import '../domain/crm/reporting/report_section_configuration.dart';
import '../domain/evidence/client_ledger_repository.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/guard_checked_in.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/patrol_completed.dart';
import '../domain/events/report_generated.dart';
import '../domain/events/response_arrived.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';

const _ledgerPanelColor = Color(0xFF13131E);
const _ledgerPanelTint = Color(0xFF1A1A2E);
const _ledgerPanelMuted = Color(0xFF1A1A2E);
const _ledgerBorderColor = Color(0x269D4BFF);
const _ledgerTitleColor = Color(0xFFE8E8F0);
const _ledgerBodyColor = Color(0x80FFFFFF);
const _ledgerMutedColor = Color(0x4DFFFFFF);

class LedgerPage extends StatefulWidget {
  final String clientId;
  final bool supabaseEnabled;
  final List<DispatchEvent> events;
  final ClientLedgerRepository? ledgerRepository;

  const LedgerPage({
    super.key,
    required this.clientId,
    required this.supabaseEnabled,
    required this.events,
    this.ledgerRepository,
  });

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  static const int _maxTimelineRows = 60;

  List<Map<String, dynamic>> _rows = [];
  late List<_LedgerTimelineRow> _fallbackRows;
  String? _verificationResult;
  String? _runtimeConfigHint;
  _LedgerLaneFilter _laneFilter = _LedgerLaneFilter.all;
  _LedgerWorkspaceView _workspaceView = _LedgerWorkspaceView.casefile;
  String? _selectedRowId;

  @override
  void initState() {
    super.initState();
    _fallbackRows = _buildFallbackRows(widget.events, widget.clientId);
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    if (!widget.supabaseEnabled) {
      if (!mounted) return;
      setState(() {
        _rows = const [];
        _runtimeConfigHint =
            'Supabase disabled. Running EventStore fallback timeline. '
            'Run with local defines: ./scripts/run_onyx_chrome_local.sh';
      });
      return;
    }

    final repository = widget.ledgerRepository;
    if (repository == null) {
      if (!mounted) return;
      setState(() {
        _rows = const [];
        _runtimeConfigHint =
            'Supabase ledger repository not injected. '
            'Running EventStore fallback timeline.';
      });
      return;
    }
    final data = await repository.listLedgerRows(widget.clientId);

    if (!mounted) return;
    setState(() {
      _rows = data
          .map(
            (row) => <String, dynamic>{
              'client_id': row.clientId,
              'dispatch_id': row.dispatchId,
              'canonical_json': row.canonicalJson,
              'hash': row.hash,
              'previous_hash': row.previousHash,
            },
          )
          .toList(growable: false);
      _runtimeConfigHint = null;
      _verificationResult = null;
    });
  }

  Future<void> _verifyChain() async {
    if (_rows.isEmpty) {
      if (_fallbackRows.isEmpty) {
        setState(() => _verificationResult = 'No evidence rows available.');
        return;
      }

      var ordered = true;
      for (int i = 1; i < _fallbackRows.length; i++) {
        if (_fallbackRows[i - 1].sequence <= _fallbackRows[i].sequence) {
          ordered = false;
          break;
        }
      }

      setState(() {
        _verificationResult = ordered
            ? 'In-memory evidence ordering VERIFIED'
            : 'In-memory evidence ordering FAILED';
      });
      return;
    }

    String? previousHash;
    for (final row in _rows) {
      final canonicalJson = row['canonical_json'];
      final storedHash = row['hash'];
      final combined = previousHash == null
          ? canonicalJson
          : canonicalJson + previousHash;
      final computedHash = sha256
          .convert(Uint8List.fromList(utf8.encode(combined)))
          .toString();

      if (computedHash != storedHash) {
        setState(() => _verificationResult = 'Chain integrity FAILED');
        return;
      }
      previousHash = storedHash;
    }

    setState(() => _verificationResult = 'Chain integrity VERIFIED');
  }

  @override
  Widget build(BuildContext context) {
    final showSupabaseRows = _rows.isNotEmpty;
    final sourceLabel = showSupabaseRows ? 'Supabase' : 'EventStore';
    final totalRows = showSupabaseRows ? _rows.length : _fallbackRows.length;
    final rowCount = totalRows > _maxTimelineRows
        ? _maxTimelineRows
        : totalRows;
    final hiddenRows = totalRows - rowCount;
    final reviewRows = _buildReviewRows(
      showSupabaseRows: showSupabaseRows,
      visibleRows: rowCount,
    );
    final filteredRows = reviewRows
        .where((row) => _matchesLaneFilter(row, _laneFilter))
        .toList(growable: false);
    final selected = _resolveSelectedRow(filteredRows);
    final relatedRows = selected == null
        ? const <_LedgerReviewRow>[]
        : _linkedRowsFor(selected, reviewRows);

    return OnyxPageScaffold(
      child: LayoutBuilder(
        builder: (context, viewport) {
          const contentPadding = EdgeInsets.all(16);
          final useScrollFallback =
              isHandsetLayout(context) ||
              viewport.maxHeight < 720 ||
              viewport.maxWidth < 980;
          final boundedDesktopSurface =
              !useScrollFallback &&
              viewport.hasBoundedHeight &&
              viewport.maxHeight.isFinite;
          final ultrawideSurface = isUltrawideLayout(
            context,
            viewportWidth: viewport.maxWidth,
          );
          final surfaceMaxWidth = commandSurfaceMaxWidth(
            context,
            compactDesktopWidth: 1540,
            viewportWidth: viewport.maxWidth,
            widescreenFillFactor: ultrawideSurface ? 1 : 0.96,
          );
          final mergeWorkspaceBannerIntoHero =
              !useScrollFallback && viewport.maxWidth >= 900;
          final scopeRows = filteredRows.isNotEmpty ? filteredRows : reviewRows;
          final chainIntegrityIssueCount = scopeRows
              .where((row) => row.needsAttention)
              .length;
          final chainIntact = chainIntegrityIssueCount == 0;
          final chainIntegrityMessage = chainIntact
              ? 'Chain intact'
              : '$chainIntegrityIssueCount chain integrity issues need review';

          Widget buildSurfaceBody({required bool embedScroll}) {
            final workspaceSection = LayoutBuilder(
              builder: (context, constraints) {
                final useThreeColumnLayout = constraints.maxWidth >= 1260;
                final useTwoColumnLayout = constraints.maxWidth >= 900;
                final useEmbeddedPanels = useTwoColumnLayout;
                final workspace = _ledgerWorkspace(
                  reviewRows: reviewRows,
                  filteredRows: filteredRows,
                  selected: selected,
                  relatedRows: relatedRows,
                  hiddenRows: hiddenRows,
                  useEmbeddedPanels: useEmbeddedPanels,
                  useThreeColumnLayout: useThreeColumnLayout,
                );
                if (!useTwoColumnLayout) {
                  return OnyxSectionCard(
                    title: 'Priority',
                    subtitle:
                        'Pick the row, check the chain, and move the case forward.',
                    flexibleChild: embedScroll,
                    child: workspace,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!mergeWorkspaceBannerIntoHero) ...[
                      _workspaceStatusBanner(
                        context,
                        reviewRows: reviewRows,
                        filteredRows: filteredRows,
                        selected: selected,
                        relatedRows: relatedRows,
                        sourceLabel: sourceLabel,
                      ),
                      SizedBox(height: embedScroll ? 8 : 10),
                    ],
                    if (embedScroll) Expanded(child: workspace) else workspace,
                  ],
                );
              },
            );

            if (embedScroll) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _integritySummaryBar(
                    sourceLabel: sourceLabel,
                    rowCount: rowCount,
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: workspaceSection),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _integritySummaryBar(
                  sourceLabel: sourceLabel,
                  rowCount: rowCount,
                ),
                const SizedBox(height: 10),
                workspaceSection,
                const SizedBox(height: 8),
                _overviewGrid(
                  sourceLabel: sourceLabel,
                  rowCount: rowCount,
                  totalRows: totalRows,
                ),
              ],
            );
          }

          return OnyxViewportWorkspaceLayout(
            padding: contentPadding,
            maxWidth: surfaceMaxWidth,
            lockToViewport: boundedDesktopSurface,
            spacing: 8,
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ledgerPageHeader(
                  chainIntegrityMessage: chainIntegrityMessage,
                  chainIntact: chainIntact,
                ),
                const SizedBox(height: 8),
                _heroHeader(
                  context,
                  workspaceBanner: mergeWorkspaceBannerIntoHero
                      ? _workspaceStatusBanner(
                          context,
                          reviewRows: reviewRows,
                          filteredRows: filteredRows,
                          selected: selected,
                          relatedRows: relatedRows,
                          sourceLabel: sourceLabel,
                          shellless: true,
                        )
                      : null,
                ),
              ],
            ),
            body: buildSurfaceBody(embedScroll: boundedDesktopSurface),
          );
        },
      ),
    );
  }

  Widget _ledgerPageHeader({
    required String chainIntegrityMessage,
    required bool chainIntact,
  }) {
    final statusColor = chainIntact
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    return Row(
      children: [
        Text(
          'Ledger',
          style: GoogleFonts.inter(
            color: _ledgerTitleColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _ledgerPanelColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                chainIntegrityMessage,
                style: GoogleFonts.inter(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroHeader(BuildContext context, {Widget? workspaceBanner}) {
    final integrityLabel = _verificationResult == null
        ? 'Pending'
        : _verificationResult!.contains('VERIFIED')
        ? 'Verified'
        : 'Failed';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _ledgerPanelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ledgerBorderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 920;
          final chips = Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _heroChip('Client', widget.clientId),
              _heroChip(
                'Source',
                widget.supabaseEnabled ? 'Supabase + Fallback' : 'EventStore',
              ),
              _heroChip('Integrity', integrityLabel),
            ],
          );
          final actions = Wrap(
            spacing: 5,
            runSpacing: 5,
            alignment: WrapAlignment.end,
            children: [
              _heroActionButton(
                key: const ValueKey('ledger-view-events-button'),
                icon: Icons.open_in_new,
                label: 'Events',
                accent: const Color(0xFF93C5FD),
                onPressed: () => _showEventsLinkDialog(context),
              ),
              _heroActionButton(
                key: const ValueKey('ledger-verify-chain-hero-button'),
                icon: Icons.verified_rounded,
                label: 'Verify',
                accent: const Color(0xFF34D399),
                onPressed: _verifyChain,
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                chips,
                const SizedBox(height: 6),
                if (workspaceBanner != null) ...[workspaceBanner, const SizedBox(height: 6)],
                actions,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: chips),
                  const SizedBox(width: 8),
                  actions,
                ],
              ),
              if (workspaceBanner != null) ...[const SizedBox(height: 8), workspaceBanner],
            ],
          );
        },
      ),
    );
  }


  Widget _heroChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _ledgerPanelColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _ledgerBorderColor),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.inter(
                color: _ledgerMutedColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: _ledgerTitleColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroActionButton({
    required Key key,
    required IconData icon,
    required String label,
    required Color accent,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 28,
      child: FilledButton.tonalIcon(
        key: key,
        onPressed: onPressed,
        icon: Icon(icon, size: 13),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: accent.withValues(alpha: 0.10),
          foregroundColor: accent,
          side: BorderSide(color: accent.withValues(alpha: 0.28)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _integritySummaryBar({
    required String sourceLabel,
    required int rowCount,
  }) {
    final integrityLabel = _verificationResult == null
        ? 'Pending'
        : _verificationResult!.contains('VERIFIED')
        ? 'Verified'
        : 'Failed';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _ledgerPanelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ledgerBorderColor),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'CHAIN READY',
            style: GoogleFonts.inter(
              color: const Color(0xFF6C8198),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          _statusPill(
            icon: Icons.storage_rounded,
            label: sourceLabel,
            accent: const Color(0xFF63BDFF),
          ),
          _statusPill(
            icon: Icons.format_list_numbered_rounded,
            label: '$rowCount Visible',
            accent: const Color(0xFF59D79B),
          ),
          _statusPill(
            icon: Icons.verified_outlined,
            label: integrityLabel,
            accent: integrityLabel == 'Verified'
                ? const Color(0xFF34D399)
                : integrityLabel == 'Failed'
                ? const Color(0xFFF87171)
                : const Color(0xFFF6C067),
          ),
        ],
      ),
    );
  }

  Widget _statusPill({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewGrid({
    required String sourceLabel,
    required int rowCount,
    required int totalRows,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 4
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        final aspectRatio = columns == 4
            ? 2.55
            : columns == 2
            ? 2.75
            : 2.35;
        return GridView.count(
          key: const ValueKey('ledger-overview-grid'),
          crossAxisCount: columns,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: aspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _overviewCard(
              title: 'Ledger Source',
              value: sourceLabel,
              detail: 'Evidence rows are loaded from the active ledger source.',
              icon: Icons.storage_rounded,
              accent: const Color(0xFF63BDFF),
            ),
            _overviewCard(
              title: 'Visible Rows',
              value: '$rowCount',
              detail: '$totalRows ledger rows are ready for review.',
              icon: Icons.view_list_outlined,
              accent: const Color(0xFF59D79B),
            ),
            _overviewCard(
              title: 'Integrity State',
              value: _verificationResult == null
                  ? 'Pending'
                  : _verificationResult!.contains('VERIFIED')
                  ? 'Verified'
                  : 'Failed',
              detail:
                  'Replay-safe verification can be rerun from the hero or header actions.',
              icon: Icons.verified_outlined,
              accent: _verificationResult == null
                  ? const Color(0xFFF6C067)
                  : _verificationResult!.contains('VERIFIED')
                  ? const Color(0xFF34D399)
                  : const Color(0xFFF87171),
            ),
            _overviewCard(
              title: 'Chain Mode',
              value: widget.supabaseEnabled ? 'Hybrid' : 'Fallback',
              detail: widget.supabaseEnabled
                  ? 'Supabase-backed verification with local fallback support.'
                  : 'EventStore-backed fallback timeline with in-memory checks.',
              icon: Icons.account_tree_outlined,
              accent: const Color(0xFFA78BFA),
            ),
          ],
        );
      },
    );
  }

  Widget _overviewCard({
    required String title,
    required String value,
    required String detail,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _ledgerPanelColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ledgerBorderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A081B33),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 14),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.robotoMono(
                    color: accent,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              color: _ledgerMutedColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: _ledgerBodyColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceStatusBanner(
    BuildContext context, {
    required List<_LedgerReviewRow> reviewRows,
    required List<_LedgerReviewRow> filteredRows,
    required _LedgerReviewRow? selected,
    required List<_LedgerReviewRow> relatedRows,
    required String sourceLabel,
    bool shellless = false,
  }) {
    final integrityLabel = _verificationResult == null
        ? 'Pending'
        : _verificationResult!.contains('VERIFIED')
        ? 'Verified'
        : 'Failed';
    final integrityAccent = _verificationResult == null
        ? const Color(0xFFF6C067)
        : _verificationResult!.contains('VERIFIED')
        ? const Color(0xFF34D399)
        : const Color(0xFFF87171);
    final bannerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _workspaceStatusPill(
              icon: Icons.storage_rounded,
              label: sourceLabel,
              accent: const Color(0xFF63BDFF),
            ),
            _workspaceStatusPill(
              icon: Icons.filter_list_rounded,
              label: '${filteredRows.length} Visible',
              accent: const Color(0xFF59D79B),
            ),
            _workspaceStatusPill(
              icon: Icons.radar_outlined,
              label: 'Lane ${_laneFilter.label}',
              accent: _laneFilter.accent,
            ),
            _workspaceStatusPill(
              icon: Icons.dashboard_customize_outlined,
              label: 'View ${_workspaceView.label}',
              accent: _workspaceView.accent,
            ),
            _workspaceStatusPill(
              icon: Icons.flag_outlined,
              label: 'Focus ${selected?.eventId ?? 'None'}',
              accent: selected?.color ?? const Color(0xFF94A3B8),
            ),
            _workspaceStatusPill(
              icon: Icons.verified_outlined,
              label: integrityLabel,
              accent: integrityAccent,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Pick the row, check the proof, and move the case where it belongs.',
          style: GoogleFonts.inter(
            color: _ledgerBodyColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
    if (shellless) {
      return KeyedSubtree(
        key: const ValueKey('ledger-workspace-status-banner'),
        child: bannerContent,
      );
    }
    return Container(
      key: const ValueKey('ledger-workspace-status-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _ledgerPanelColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ledgerBorderColor),
      ),
      child: bannerContent,
    );
  }

  Widget _ledgerWorkspace({
    required List<_LedgerReviewRow> reviewRows,
    required List<_LedgerReviewRow> filteredRows,
    required _LedgerReviewRow? selected,
    required List<_LedgerReviewRow> relatedRows,
    required int hiddenRows,
    required bool useEmbeddedPanels,
    required bool useThreeColumnLayout,
  }) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final ultrawideWorkspace = isUltrawideLayout(
      context,
      viewportWidth: viewportWidth,
    );
    final widescreenWorkspace = isWidescreenLayout(
      context,
      viewportWidth: viewportWidth,
    );
    final railGap = ultrawideWorkspace ? 10.0 : 8.0;
    final laneRailWidth = ultrawideWorkspace
        ? 292.0
        : widescreenWorkspace
        ? 280.0
        : 268.0;
    final contextRailWidth = ultrawideWorkspace
        ? 264.0
        : widescreenWorkspace
        ? 252.0
        : 240.0;

    if (useThreeColumnLayout && useEmbeddedPanels) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: laneRailWidth,
            child: _ledgerLaneRail(
              reviewRows: reviewRows,
              filteredRows: filteredRows,
              selectedId: selected?.id,
              hiddenRows: hiddenRows,
              useExpandedBody: true,
            ),
          ),
          SizedBox(width: railGap),
          Expanded(
            flex: 3,
            child: _selectedEntryWorkspace(
              reviewRows: reviewRows,
              selected: selected,
              relatedRows: relatedRows,
              useExpandedBody: true,
            ),
          ),
          SizedBox(width: railGap),
          SizedBox(
            width: contextRailWidth,
            child: _ledgerContextRail(
              reviewRows: reviewRows,
              filteredRows: filteredRows,
              selected: selected,
              relatedRows: relatedRows,
              hiddenRows: hiddenRows,
              useExpandedBody: true,
            ),
          ),
        ],
      );
    }

    if (useEmbeddedPanels) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: laneRailWidth,
            child: _ledgerLaneRail(
              reviewRows: reviewRows,
              filteredRows: filteredRows,
              selectedId: selected?.id,
              hiddenRows: hiddenRows,
              useExpandedBody: true,
            ),
          ),
          SizedBox(width: railGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _selectedEntryWorkspace(
                    reviewRows: reviewRows,
                    selected: selected,
                    relatedRows: relatedRows,
                    useExpandedBody: true,
                  ),
                ),
                SizedBox(height: railGap),
                SizedBox(
                  height: ultrawideWorkspace ? 188 : 180,
                  child: _ledgerContextRail(
                    reviewRows: reviewRows,
                    filteredRows: filteredRows,
                    selected: selected,
                    relatedRows: relatedRows,
                    hiddenRows: hiddenRows,
                    useExpandedBody: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ledgerLaneRail(
          reviewRows: reviewRows,
          filteredRows: filteredRows,
          selectedId: selected?.id,
          hiddenRows: hiddenRows,
          useExpandedBody: false,
        ),
        const SizedBox(height: 10),
        _selectedEntryWorkspace(
          reviewRows: reviewRows,
          selected: selected,
          relatedRows: relatedRows,
          useExpandedBody: false,
        ),
        const SizedBox(height: 10),
        _ledgerContextRail(
          reviewRows: reviewRows,
          filteredRows: filteredRows,
          selected: selected,
          relatedRows: relatedRows,
          hiddenRows: hiddenRows,
          useExpandedBody: false,
        ),
      ],
    );
  }

  Widget _ledgerLaneRail({
    required List<_LedgerReviewRow> reviewRows,
    required List<_LedgerReviewRow> filteredRows,
    required String? selectedId,
    required int hiddenRows,
    required bool useExpandedBody,
  }) {
    final list = filteredRows.isEmpty
        ? _emptyLaneState()
        : ListView.separated(
            shrinkWrap: !useExpandedBody,
            primary: useExpandedBody,
            physics: useExpandedBody
                ? null
                : const NeverScrollableScrollPhysics(),
            itemCount: filteredRows.length + (hiddenRows > 0 ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (hiddenRows > 0 && index == filteredRows.length) {
                return _hiddenRowsHint(
                  visibleRows: filteredRows.length,
                  totalRows: filteredRows.length + hiddenRows,
                );
              }
              final row = filteredRows[index];
              return _ledgerLaneCard(row, isSelected: row.id == selectedId);
            },
          );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: onyxWorkspaceSurfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LANE CONTROL',
            style: GoogleFonts.inter(
              color: const Color(0xFFE6F0FF),
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Filter rows by receipts, continuity, or attention first.',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA5C6),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _LedgerLaneFilter.values
                .map((filter) => _ledgerLaneChip(filter, reviewRows))
                .toList(),
          ),
          const SizedBox(height: 8),
          if (useExpandedBody) Expanded(child: list) else list,
        ],
      ),
    );
  }

  Widget _emptyLaneState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: onyxSelectableRowSurfaceDecoration(isSelected: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No rows in this lane yet.',
            style: GoogleFonts.inter(
              color: const Color(0xFFE6F0FF),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Open the full evidence stream to bring the board back.',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA5C6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (_laneFilter != _LedgerLaneFilter.all) ...[
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              key: const ValueKey('ledger-empty-reset-lane'),
              onPressed: () => _setLedgerLaneFilter(
                _LedgerLaneFilter.all,
                _buildReviewRows(
                  showSupabaseRows: _rows.isNotEmpty,
                  visibleRows: _rows.isNotEmpty
                      ? (_rows.length > _maxTimelineRows
                            ? _maxTimelineRows
                            : _rows.length)
                      : (_fallbackRows.length > _maxTimelineRows
                            ? _maxTimelineRows
                            : _fallbackRows.length),
                ),
              ),
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Reset Lane'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ledgerLaneChip(
    _LedgerLaneFilter filter,
    List<_LedgerReviewRow> rows,
  ) {
    final selected = _laneFilter == filter;
    final matchingRows = rows
        .where((row) => _matchesLaneFilter(row, filter))
        .toList(growable: false);
    return InkWell(
      key: ValueKey('ledger-lane-filter-${filter.key}'),
      onTap: () => _setLedgerLaneFilter(filter, rows),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? filter.accent.withValues(alpha: 0.16)
              : const Color(0xFF13131E),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? filter.accent.withValues(alpha: 0.42)
                : const Color(0xFFD4DFEA),
          ),
        ),
        child: Text(
          '${filter.label} ${matchingRows.length}',
          style: GoogleFonts.inter(
            color: selected ? filter.accent : _ledgerBodyColor,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _ledgerLaneCard(_LedgerReviewRow row, {required bool isSelected}) {
    return InkWell(
      key: ValueKey('ledger-lane-card-${row.id}'),
      onTap: () => _focusRow(row, view: _LedgerWorkspaceView.casefile),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: onyxSelectableRowSurfaceDecoration(isSelected: isSelected),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: row.color,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.typeLabel,
                        style: GoogleFonts.inter(
                          color: row.color,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'UTC ${_shortUtc(row.occurredAt)}',
                        style: GoogleFonts.inter(
                          color: _ledgerMutedColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x129FD9FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x409FD9FF)),
                    ),
                    child: Text(
                      'FOCUS',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF9FD9FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (row.sequence != null)
                  _ledgerPill(
                    'SEQ ${row.sequence}',
                    const Color(0xFF9FD7FF),
                    const Color(0xFF35679B),
                  ),
                if (row.dispatchId != null)
                  _ledgerPill(
                    row.dispatchId!,
                    row.color,
                    row.color.withValues(alpha: 0.45),
                  ),
                if (row.siteId != null)
                  _ledgerPill(
                    row.siteId!,
                    const Color(0xFFC8D5EA),
                    const Color(0xFF425B80),
                  ),
                if (row.needsAttention)
                  _ledgerPill(
                    'Attention',
                    const Color(0xFFFADFA4),
                    const Color(0xFF8A6A2A),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              row.summary,
              style: GoogleFonts.inter(
                color: _ledgerBodyColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              row.hash != null
                  ? 'Hash ${_short(row.hash!)}'
                  : 'Event ${row.eventId ?? row.id}',
              style: GoogleFonts.inter(
                color: _ledgerMutedColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedEntryWorkspace({
    required List<_LedgerReviewRow> reviewRows,
    required _LedgerReviewRow? selected,
    required List<_LedgerReviewRow> relatedRows,
    required bool useExpandedBody,
  }) {
    final panel = switch (_workspaceView) {
      _LedgerWorkspaceView.casefile => _ledgerCasefilePanel(
        selected,
        useScrollable: useExpandedBody,
      ),
      _LedgerWorkspaceView.integrity => _ledgerIntegrityPanel(
        selected,
        reviewRows: reviewRows,
        useScrollable: useExpandedBody,
      ),
      _LedgerWorkspaceView.trace => _ledgerTracePanel(
        selected,
        relatedRows: relatedRows,
        useScrollable: useExpandedBody,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: onyxWorkspaceSurfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOU ARE HERE',
            style: GoogleFonts.inter(
              color: _ledgerTitleColor,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'One row. One proof trail. One next move.',
            style: GoogleFonts.inter(
              color: _ledgerMutedColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          _selectedLedgerBanner(selected, relatedRows),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _LedgerWorkspaceView.values
                .map(_ledgerWorkspaceChip)
                .toList(),
          ),
          const SizedBox(height: 8),
          if (useExpandedBody) Expanded(child: panel) else panel,
        ],
      ),
    );
  }

  Widget _selectedLedgerBanner(
    _LedgerReviewRow? row,
    List<_LedgerReviewRow> relatedRows,
  ) {
    if (row == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _ledgerPanelColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _ledgerBorderColor),
        ),
        child: Text(
          'Select a row to load its proof, integrity posture, and linked continuity context.',
          style: GoogleFonts.inter(
            color: _ledgerBodyColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      );
    }

    final compactMetrics = [
      _miniLedgerMetric(
        label: 'Lane',
        value: _laneFilter.label,
        accent: _laneFilter.accent,
      ),
      _miniLedgerMetric(
        label: 'Linked Rows',
        value: '${relatedRows.length}',
        accent: const Color(0xFF63BDFF),
      ),
      _miniLedgerMetric(
        label: 'Integrity',
        value: row.needsAttention ? 'Attention' : 'Stable',
        accent: row.needsAttention
            ? const Color(0xFFF6C067)
            : const Color(0xFF34D399),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [row.color.withValues(alpha: 0.12), _ledgerPanelColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: row.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Priority',
            style: GoogleFonts.inter(
              color: row.color,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            row.title,
            style: GoogleFonts.inter(
              color: _ledgerTitleColor,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            row.sourceLabel == 'Supabase'
                ? 'Supabase-backed chain evidence is in focus for replay-safe review.'
                : 'Fallback EventStore evidence is in focus for receipt and continuity review.',
            style: GoogleFonts.inter(
              color: _ledgerBodyColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ledgerPill(
                'UTC ${_shortUtc(row.occurredAt)}',
                const Color(0xFF9FD7FF),
                const Color(0xFF35679B),
              ),
              _ledgerPill(
                row.sourceLabel,
                const Color(0xFF8FF3C9),
                const Color(0xFF2D7D63),
              ),
              if (row.siteId != null)
                _ledgerPill(
                  row.siteId!,
                  const Color(0xFFC8D5EA),
                  const Color(0xFF425B80),
                ),
              if (row.dispatchId != null)
                _ledgerPill(
                  row.dispatchId!,
                  row.color,
                  row.color.withValues(alpha: 0.4),
                ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              if (compact) {
                return Column(
                  children:
                      compactMetrics
                          .expand(
                            (widget) => <Widget>[
                              widget,
                              const SizedBox(height: 6),
                            ],
                          )
                          .toList()
                        ..removeLast(),
                );
              }
              return Row(
                children:
                    compactMetrics
                        .expand(
                          (widget) => <Widget>[
                            Expanded(child: widget),
                            const SizedBox(width: 6),
                          ],
                        )
                        .toList()
                      ..removeLast(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _miniLedgerMetric({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _ledgerPanelMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: _ledgerMutedColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              color: _ledgerTitleColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ledgerWorkspaceChip(_LedgerWorkspaceView view) {
    final selected = _workspaceView == view;
    return InkWell(
      key: ValueKey('ledger-workspace-view-${view.key}'),
      onTap: () => _setLedgerWorkspaceView(view),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? view.accent.withValues(alpha: 0.16)
              : _ledgerPanelColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? view.accent.withValues(alpha: 0.45)
                : _ledgerBorderColor,
          ),
        ),
        child: Text(
          view.label,
          style: GoogleFonts.inter(
            color: selected ? view.accent : _ledgerBodyColor,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _ledgerCasefilePanel(
    _LedgerReviewRow? row, {
    required bool useScrollable,
  }) {
    if (row == null) {
      return _workspacePanelContainer(
        key: const ValueKey('ledger-workspace-panel-casefile'),
        useScrollable: useScrollable,
        shellless: useScrollable,
        children: [
          _panelEmptyCopy(
            'No active case.',
            'Choose a row to pull its proof, scope, and chain context into this workspace.',
          ),
        ],
      );
    }

    return _workspacePanelContainer(
      key: const ValueKey('ledger-workspace-panel-casefile'),
      useScrollable: useScrollable,
      shellless: useScrollable,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _miniLedgerMetric(
              label: 'Entry ID',
              value: row.eventId ?? _short(row.id),
              accent: row.color,
            ),
            _miniLedgerMetric(
              label: 'Source',
              value: row.sourceLabel,
              accent: const Color(0xFF63BDFF),
            ),
            _miniLedgerMetric(
              label: 'Review Class',
              value: row.isReport ? 'Report receipt' : 'Operational event',
              accent: const Color(0xFF59D79B),
            ),
          ],
        ),
        if (row.configurationLabel != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _ledgerPanelMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: row.configurationBorderColor ?? const Color(0xFF425B80),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.configurationLabel!,
                  style: GoogleFonts.inter(
                    color: row.configurationTextColor ?? _ledgerTitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if ((row.detailSummary ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    row.detailSummary!,
                    style: GoogleFonts.inter(
                      color: _ledgerBodyColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ] else if ((row.detailSummary ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _detailNarrative(row.detailSummary!),
        ],
        const SizedBox(height: 10),
        _detailRow('Recorded', 'UTC ${_shortUtc(row.occurredAt)}'),
        _detailRow('Scope', row.siteId ?? 'Client-wide'),
        _detailRow(
          'Dispatch',
          row.dispatchId ?? 'No dispatch scope captured for this entry.',
        ),
        _detailRow(
          'Sequence',
          row.sequence?.toString() ?? 'External hash-backed ledger row',
        ),
        _detailRow('Attention Posture', row.attentionReason),
      ],
    );
  }

  Widget _ledgerIntegrityPanel(
    _LedgerReviewRow? row, {
    required List<_LedgerReviewRow> reviewRows,
    required bool useScrollable,
  }) {
    final attentionRow = _firstMatchingRow(
      reviewRows,
      (candidate) => candidate.needsAttention,
    );
    return _workspacePanelContainer(
      key: const ValueKey('ledger-workspace-panel-integrity'),
      useScrollable: useScrollable,
      shellless: useScrollable,
      children: [
        if (row == null)
          _panelEmptyCopy(
            'No integrity focus selected.',
            'Select a row to check its verification posture and continuity metadata.',
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniLedgerMetric(
                label: 'Check',
                value: _verificationResult == null
                    ? 'Pending'
                    : _verificationResult!.contains('VERIFIED')
                    ? 'Verified'
                    : 'Failed',
                accent: _verificationResult == null
                    ? const Color(0xFFF6C067)
                    : _verificationResult!.contains('VERIFIED')
                    ? const Color(0xFF34D399)
                    : const Color(0xFFF87171),
              ),
              _miniLedgerMetric(
                label: 'Hash',
                value: row.hash == null
                    ? 'Fallback ordering'
                    : _short(row.hash!),
                accent: row.color,
              ),
              _miniLedgerMetric(
                label: 'Prev',
                value: row.previousHash == null
                    ? 'Start of chain'
                    : _short(row.previousHash!),
                accent: const Color(0xFF63BDFF),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _detailNarrative(
            row.hash == null
                ? 'Fallback rows validate by sequence ordering rather than stored hashes. Use Check Chain to rerun the in-memory continuity check.'
                : 'Supabase rows preserve canonical payload hashes and previous-link references for replay-safe integrity checks.',
          ),
          const SizedBox(height: 10),
          _detailRow('Continuity', row.attentionReason),
          if (row.hash != null)
            _detailRow('Current Hash', row.hash!)
          else
            _detailRow('Chain Mode', 'Fallback EventStore ordering'),
          if (row.previousHash != null)
            _detailRow('Previous Hash', row.previousHash!),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('ledger-workspace-verify-chain'),
                onPressed: _verifyChain,
                icon: const Icon(Icons.verified_rounded, size: 18),
                label: const Text('Check Chain'),
              ),
              FilledButton.tonalIcon(
                key: const ValueKey('ledger-workspace-open-attention-lane'),
                onPressed: attentionRow == null
                    ? null
                    : () => _focusRow(
                        attentionRow,
                        lane: _LedgerLaneFilter.attention,
                        view: _LedgerWorkspaceView.integrity,
                      ),
                icon: const Icon(Icons.warning_amber_rounded, size: 18),
                label: const Text('Open Attention Lane'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _ledgerTracePanel(
    _LedgerReviewRow? row, {
    required List<_LedgerReviewRow> relatedRows,
    required bool useScrollable,
  }) {
    final content = <Widget>[
      if (row == null)
        _panelEmptyCopy(
          'No linked trace yet.',
          'Choose a row to inspect nearby proof context and related scope entries.',
        )
      else ...[
        _detailNarrative(
          relatedRows.isEmpty
              ? 'No linked rows were found inside the visible stack for this entry.'
              : 'Linked rows share the current dispatch or site scope and can be opened directly from this trace view.',
        ),
        const SizedBox(height: 10),
        if (relatedRows.isEmpty)
          _detailRow(
            'Linked Scope',
            'No additional rows in the current visible scope.',
          )
        else
          ...relatedRows
              .take(4)
              .expand(
                (related) => <Widget>[
                  InkWell(
                    key: ValueKey('ledger-trace-related-${related.id}'),
                    onTap: () => _focusRow(
                      related,
                      lane: _preferredLaneForRow(related),
                      view: _LedgerWorkspaceView.trace,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: onyxSelectableRowSurfaceDecoration(
                        isSelected: _selectedRowId == related.id,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            related.title,
                            style: GoogleFonts.inter(
                              color: _ledgerTitleColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            related.summary,
                            style: GoogleFonts.inter(
                              color: _ledgerBodyColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
      ],
    ];

    return _workspacePanelContainer(
      key: const ValueKey('ledger-workspace-panel-trace'),
      useScrollable: useScrollable,
      shellless: useScrollable,
      children: content,
    );
  }

  Widget _workspacePanelContainer({
    required Key key,
    required bool useScrollable,
    bool shellless = false,
    required List<Widget> children,
  }) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    if (shellless) {
      return KeyedSubtree(
        key: key,
        child: useScrollable ? SingleChildScrollView(child: body) : body,
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _ledgerPanelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ledgerBorderColor),
      ),
      child: KeyedSubtree(
        key: key,
        child: useScrollable ? SingleChildScrollView(child: body) : body,
      ),
    );
  }

  Widget _panelEmptyCopy(String title, String detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: _ledgerTitleColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          detail,
          style: GoogleFonts.inter(
            color: _ledgerBodyColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _detailNarrative(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _ledgerPanelMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ledgerBorderColor),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: _ledgerBodyColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _ledgerPanelMuted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _ledgerBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: _ledgerMutedColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                color: _ledgerTitleColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ledgerContextRail({
    required List<_LedgerReviewRow> reviewRows,
    required List<_LedgerReviewRow> filteredRows,
    required _LedgerReviewRow? selected,
    required List<_LedgerReviewRow> relatedRows,
    required int hiddenRows,
    required bool useExpandedBody,
  }) {
    final latestReport = _firstMatchingRow(reviewRows, (row) => row.isReport);
    final attentionRow = _firstMatchingRow(
      reviewRows,
      (row) => row.needsAttention,
    );
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: onyxWorkspaceSurfaceDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TRACE RAIL',
                style: GoogleFonts.inter(
                  color: const Color(0xFFE6F0FF),
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Live proof posture, scope stats, and lane handoffs for the active stack.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF8EA5C6),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              _detailRow('Lane Focus', _laneFilter.label),
              _detailRow('Visible Rows', '${filteredRows.length}'),
              _detailRow(
                'Selected Scope',
                selected?.siteId ?? 'No site selected',
              ),
              _detailRow('Linked Rows', '${relatedRows.length}'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  FilledButton.tonalIcon(
                    key: const ValueKey('ledger-context-focus-latest-report'),
                    onPressed: latestReport == null
                        ? null
                        : () => _focusRow(
                            latestReport,
                            lane: _LedgerLaneFilter.reports,
                            view: _LedgerWorkspaceView.casefile,
                          ),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('Open Latest Report'),
                  ),
                  FilledButton.tonalIcon(
                    key: const ValueKey('ledger-context-open-attention'),
                    onPressed: attentionRow == null
                        ? null
                        : () => _focusRow(
                            attentionRow,
                            lane: _LedgerLaneFilter.attention,
                            view: _LedgerWorkspaceView.integrity,
                          ),
                    icon: const Icon(Icons.warning_amber_rounded, size: 18),
                    label: const Text('Open Attention Lane'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_runtimeConfigHint != null) ...[
          const SizedBox(height: 10),
          _contextBanner(
            text: _runtimeConfigHint!,
            borderColor: const Color(0xFFF0C36C),
            textColor: const Color(0xFFFADFA4),
          ),
        ],
        if (_verificationResult != null) ...[
          const SizedBox(height: 10),
          _contextBanner(
            text: _verificationResult!,
            borderColor: _verificationResult!.contains('VERIFIED')
                ? const Color(0xFF46DBA2)
                : const Color(0xFFFF7686),
            textColor: _verificationResult!.contains('VERIFIED')
                ? const Color(0xFF8FF3C9)
                : const Color(0xFFFF9AA7),
          ),
        ],
        if (hiddenRows > 0) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: onyxWorkspaceSurfaceDecoration(),
            child: OnyxTruncationHint(
              visibleCount: filteredRows.length,
              totalCount: filteredRows.length + hiddenRows,
              subject: 'ledger rows',
              hiddenDescriptor: 'older rows',
              color: const Color(0xFF90A9CB),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );

    if (useExpandedBody) {
      return SingleChildScrollView(child: column);
    }
    return column;
  }

  Widget _contextBanner({
    required String text,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _ledgerPanelTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _workspaceStatusPill({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _ledgerPanelTint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: _ledgerTitleColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<_LedgerReviewRow> _buildReviewRows({
    required bool showSupabaseRows,
    required int visibleRows,
  }) {
    if (showSupabaseRows) {
      final visible = _rows.take(visibleRows).toList(growable: false);
      return visible.map(_mapSupabaseReviewRow).toList(growable: false);
    }
    return _fallbackRows
        .take(visibleRows)
        .map(_mapFallbackReviewRow)
        .toList(growable: false);
  }

  _LedgerReviewRow _mapSupabaseReviewRow(Map<String, dynamic> row) {
    final hash = (row['hash'] ?? '').toString().trim();
    final previousHash = (row['previous_hash'] ?? '').toString().trim();
    final dispatchId = (row['dispatch_id'] ?? '').toString().trim();
    final siteId = (row['site_id'] ?? '').toString().trim();
    final eventId = (row['event_id'] ?? '').toString().trim();
    final canonicalJson = (row['canonical_json'] ?? '').toString().trim();
    final rawCreatedAt = (row['created_at'] ?? row['occurred_at'] ?? '')
        .toString()
        .trim();
    final occurredAt =
        DateTime.tryParse(rawCreatedAt)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final sequenceValue = row['sequence'];
    final sequence = switch (sequenceValue) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value),
      _ => null,
    };
    final needsAttention =
        hash.isEmpty || previousHash.isEmpty || canonicalJson.isEmpty;
    final attentionReason = canonicalJson.isEmpty
        ? 'Canonical payload missing from the persisted ledger row.'
        : hash.isEmpty
        ? 'Stored hash is missing from this continuity record.'
        : previousHash.isEmpty
        ? 'Previous link is missing, so this row currently anchors the visible chain.'
        : 'Hash and previous-link metadata are available for replay-safe verification.';
    final resolvedId = eventId.isNotEmpty
        ? eventId
        : hash.isNotEmpty
        ? hash
        : '${dispatchId.isEmpty ? 'ledger' : dispatchId}-${occurredAt.microsecondsSinceEpoch}';
    return _LedgerReviewRow(
      id: resolvedId,
      typeLabel: 'LEDGER ENTRY',
      title: dispatchId.isEmpty
          ? 'Supabase evidence row'
          : 'Dispatch $dispatchId continuity record',
      summary: canonicalJson.isEmpty
          ? 'Stored continuity metadata is incomplete and needs operator review.'
          : 'Canonical payload and continuity metadata are ready for chain verification.',
      occurredAt: occurredAt,
      color: needsAttention ? const Color(0xFFF6C067) : const Color(0xFF63BDFF),
      sequence: sequence,
      sourceLabel: 'Supabase',
      eventId: eventId.isEmpty ? null : eventId,
      dispatchId: dispatchId.isEmpty ? null : dispatchId,
      siteId: siteId.isEmpty ? null : siteId,
      hash: hash.isEmpty ? null : hash,
      previousHash: previousHash.isEmpty ? null : previousHash,
      needsAttention: needsAttention,
      attentionReason: attentionReason,
    );
  }

  _LedgerReviewRow _mapFallbackReviewRow(_LedgerTimelineRow row) {
    final isFailure =
        row.type.contains('FAILED') || row.type.contains('DENIED');
    final isConfigurationException =
        row.configurationPillLabel == 'Custom Branding' ||
        row.configurationPillLabel == 'Legacy Config';
    final needsAttention = isFailure || isConfigurationException;
    final attentionReason = switch (row.configurationPillLabel) {
      'Custom Branding' =>
        'Report receipt used custom branding and should be reviewed for governance drift.',
      'Legacy Config' =>
        'Report receipt predates tracked section configuration capture.',
      _ when row.type.contains('DENIED') =>
        'Dispatch execution was denied and remains flagged for operator review.',
      _ when row.type.contains('FAILED') =>
        'Execution failed inside the visible chain and remains flagged for review.',
      _ => 'This EventStore row is stable inside the visible fallback chain.',
    };
    final summary = switch (row.type) {
      'REPORT GENERATED' =>
        'Generated report receipt ready for branding, section, and governance review.',
      'EXECUTION DENIED' =>
        'Execution denial remains visible for continuity review.',
      _ => row.title,
    };
    return _LedgerReviewRow(
      id: row.eventId,
      typeLabel: row.type,
      title: row.title,
      summary: summary,
      occurredAt: row.occurredAt,
      color: row.color,
      sequence: row.sequence,
      sourceLabel: 'EventStore',
      eventId: row.eventId,
      dispatchId: row.dispatchId,
      siteId: row.siteId,
      configurationLabel: row.configurationPillLabel,
      configurationTextColor: row.configurationPillTextColor,
      configurationBorderColor: row.configurationPillBorderColor,
      detailSummary: row.detailSummary,
      needsAttention: needsAttention,
      attentionReason: attentionReason,
    );
  }

  bool _matchesLaneFilter(_LedgerReviewRow row, _LedgerLaneFilter filter) {
    return switch (filter) {
      _LedgerLaneFilter.all => true,
      _LedgerLaneFilter.reports => row.isReport,
      _LedgerLaneFilter.continuity => !row.isReport || row.hash != null,
      _LedgerLaneFilter.attention => row.needsAttention,
    };
  }

  _LedgerReviewRow? _resolveSelectedRow(List<_LedgerReviewRow> filteredRows) {
    if (filteredRows.isEmpty) {
      return null;
    }
    for (final row in filteredRows) {
      if (row.id == _selectedRowId) {
        return row;
      }
    }
    return filteredRows.first;
  }

  List<_LedgerReviewRow> _linkedRowsFor(
    _LedgerReviewRow selected,
    List<_LedgerReviewRow> rows,
  ) {
    return rows
        .where((row) {
          if (row.id == selected.id) {
            return false;
          }
          if (selected.dispatchId != null &&
              row.dispatchId == selected.dispatchId) {
            return true;
          }
          if (selected.siteId != null && row.siteId == selected.siteId) {
            return true;
          }
          return false;
        })
        .toList(growable: false);
  }

  void _setLedgerLaneFilter(
    _LedgerLaneFilter filter,
    List<_LedgerReviewRow> rows,
  ) {
    if (_laneFilter == filter) {
      return;
    }
    final matchingRows = rows
        .where((row) => _matchesLaneFilter(row, filter))
        .toList(growable: false);
    setState(() {
      _laneFilter = filter;
      if (matchingRows.isNotEmpty &&
          !matchingRows.any((row) => row.id == _selectedRowId)) {
        _selectedRowId = matchingRows.first.id;
      }
    });
  }

  void _setLedgerWorkspaceView(_LedgerWorkspaceView view) {
    if (_workspaceView == view) {
      return;
    }
    setState(() {
      _workspaceView = view;
    });
  }

  void _focusRow(
    _LedgerReviewRow row, {
    _LedgerLaneFilter? lane,
    _LedgerWorkspaceView? view,
  }) {
    setState(() {
      _selectedRowId = row.id;
      _laneFilter =
          lane ??
          (_matchesLaneFilter(row, _laneFilter)
              ? _laneFilter
              : _preferredLaneForRow(row));
      if (view != null) {
        _workspaceView = view;
      }
    });
  }

  _LedgerLaneFilter _preferredLaneForRow(_LedgerReviewRow row) {
    if (row.isReport) {
      return _LedgerLaneFilter.reports;
    }
    if (row.needsAttention) {
      return _LedgerLaneFilter.attention;
    }
    return _LedgerLaneFilter.continuity;
  }

  _LedgerReviewRow? _firstMatchingRow(
    List<_LedgerReviewRow> rows,
    bool Function(_LedgerReviewRow row) test,
  ) {
    for (final row in rows) {
      if (test(row)) {
        return row;
      }
    }
    return null;
  }

  void _showEventsLinkDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _ledgerPanelColor,
          title: Text(
            'Events Scope Ready',
            style: GoogleFonts.inter(
              color: _ledgerTitleColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Use Events Scope to inspect the forensic timeline, selected event payloads, and the upstream chain that feeds this ledger view.',
            style: GoogleFonts.inter(color: _ledgerBodyColor, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _hiddenRowsHint({required int visibleRows, required int totalRows}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _timelineRowDecoration(),
      child: OnyxTruncationHint(
        visibleCount: visibleRows,
        totalCount: totalRows,
        subject: 'ledger rows',
        hiddenDescriptor: 'older rows',
        color: const Color(0xFF90A9CB),
        fontSize: 12,
      ),
    );
  }

  String _short(String v) => v.length <= 24 ? v : '${v.substring(0, 24)}...';

  Widget _ledgerPill(String text, Color textColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: borderColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  BoxDecoration _timelineRowDecoration() {
    return BoxDecoration(
      color: _ledgerPanelColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _ledgerBorderColor),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A081B33),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  String _shortUtc(DateTime dt) {
    final z = dt.toUtc().toIso8601String();
    return z.length > 19 ? '${z.substring(0, 19)}Z' : z;
  }

  List<_LedgerTimelineRow> _buildFallbackRows(
    List<DispatchEvent> events,
    String clientId,
  ) {
    final rows = <_LedgerTimelineRow>[];

    for (final event in events.reversed) {
      if (event is DecisionCreated && event.clientId == clientId) {
        rows.add(
          _LedgerTimelineRow(
            eventId: event.eventId,
            sequence: event.sequence,
            occurredAt: event.occurredAt,
            type: 'DECISION',
            title:
                '${event.clientId}/${event.siteId} dispatch ${event.dispatchId} created',
            color: const Color(0xFF68C9FF),
            dispatchId: event.dispatchId,
            siteId: event.siteId,
          ),
        );
      } else if (event is ExecutionCompleted && event.clientId == clientId) {
        rows.add(
          _LedgerTimelineRow(
            eventId: event.eventId,
            sequence: event.sequence,
            occurredAt: event.occurredAt,
            type: event.success ? 'EXECUTION' : 'EXECUTION FAILED',
            title: '${event.dispatchId} at ${event.siteId}',
            color: event.success
                ? const Color(0xFF5BDEA1)
                : const Color(0xFFFF7B88),
            dispatchId: event.dispatchId,
            siteId: event.siteId,
          ),
        );
      } else if (event is ExecutionDenied && event.clientId == clientId) {
        rows.add(
          _LedgerTimelineRow(
            eventId: event.eventId,
            sequence: event.sequence,
            occurredAt: event.occurredAt,
            type: 'EXECUTION DENIED',
            title: '${event.dispatchId} denied (${event.reason})',
            color: const Color(0xFFF4B658),
            dispatchId: event.dispatchId,
            siteId: event.siteId,
          ),
        );
      } else if (event is GuardCheckedIn && event.clientId == clientId) {
        rows.add(
          _LedgerTimelineRow(
            eventId: event.eventId,
            sequence: event.sequence,
            occurredAt: event.occurredAt,
            type: 'CHECK-IN',
            title: '${event.guardId} at ${event.siteId}',
            color: const Color(0xFF6DC7FF),
            siteId: event.siteId,
          ),
        );
      } else if (event is PatrolCompleted && event.clientId == clientId) {
        rows.add(
          _LedgerTimelineRow(
            eventId: event.eventId,
            sequence: event.sequence,
            occurredAt: event.occurredAt,
            type: 'PATROL',
            title: '${event.guardId} route ${event.routeId} at ${event.siteId}',
            color: const Color(0xFF68DDA3),
            siteId: event.siteId,
          ),
        );
      } else if (event is ResponseArrived && event.clientId == clientId) {
        rows.add(
          _LedgerTimelineRow(
            eventId: event.eventId,
            sequence: event.sequence,
            occurredAt: event.occurredAt,
            type: 'RESPONSE',
            title: '${event.guardId} for ${event.dispatchId}',
            color: const Color(0xFF6EC7FF),
            dispatchId: event.dispatchId,
            siteId: event.siteId,
          ),
        );
      } else if (event is IncidentClosed && event.clientId == clientId) {
        rows.add(
          _LedgerTimelineRow(
            eventId: event.eventId,
            sequence: event.sequence,
            occurredAt: event.occurredAt,
            type: 'INCIDENT CLOSED',
            title: '${event.dispatchId} (${event.resolutionType})',
            color: const Color(0xFFA5E86E),
            dispatchId: event.dispatchId,
            siteId: event.siteId,
          ),
        );
      } else if (event is ReportGenerated && event.clientId == clientId) {
        final tracked = _hasTrackedReportSectionConfiguration(event);
        final omittedSections = _omittedReportSectionLabels(
          event.sectionConfiguration,
        );
        final brandingHeadline = _reportBrandingHeadline(event);
        rows.add(
          _LedgerTimelineRow(
            eventId: event.eventId,
            sequence: event.sequence,
            occurredAt: event.occurredAt,
            type: 'REPORT GENERATED',
            title:
                '${event.siteId} ${event.month} • ${_reportSectionConfigurationHeadline(event)}${brandingHeadline == null ? '' : ' • $brandingHeadline'}${_reportInvestigationHeadline(event) == null ? '' : ' • ${_reportInvestigationHeadline(event)}'} • range ${event.eventRangeStart}-${event.eventRangeEnd}',
            color: const Color(0xFFC79CFF),
            configurationPillLabel: tracked
                ? event.brandingUsesOverride
                      ? 'Custom Branding'
                      : omittedSections.isEmpty
                      ? 'Tracked Config'
                      : '${omittedSections.length} Sections Omitted'
                : 'Legacy Config',
            configurationPillTextColor: event.brandingUsesOverride
                ? const Color(0xFFFADFA4)
                : tracked
                ? omittedSections.isEmpty
                      ? const Color(0xFF8FF3C9)
                      : const Color(0xFFFADFA4)
                : const Color(0xFFA8BEE0),
            configurationPillBorderColor: event.brandingUsesOverride
                ? const Color(0xFF8A6A2A)
                : tracked
                ? omittedSections.isEmpty
                      ? const Color(0xFF2D7D63)
                      : const Color(0xFF8A6A2A)
                : const Color(0xFF425B80),
            detailSummary:
                '${_reportBrandingDetail(event)} ${_reportSectionConfigurationDetail(event)} ${_reportInvestigationDetail(event)}',
            siteId: event.siteId,
          ),
        );
      }
    }

    return rows;
  }
}

class _LedgerTimelineRow {
  final String eventId;
  final int sequence;
  final DateTime occurredAt;
  final String type;
  final String title;
  final Color color;
  final String? dispatchId;
  final String? siteId;
  final String? configurationPillLabel;
  final Color? configurationPillTextColor;
  final Color? configurationPillBorderColor;
  final String? detailSummary;

  const _LedgerTimelineRow({
    required this.eventId,
    required this.sequence,
    required this.occurredAt,
    required this.type,
    required this.title,
    required this.color,
    this.dispatchId,
    this.siteId,
    this.configurationPillLabel,
    this.configurationPillTextColor,
    this.configurationPillBorderColor,
    this.detailSummary,
  });
}

enum _LedgerLaneFilter {
  all('All', 'all', Color(0xFF8EA5C6)),
  reports('Reports', 'reports', Color(0xFFC79CFF)),
  continuity('Continuity', 'continuity', Color(0xFF63BDFF)),
  attention('Attention', 'attention', Color(0xFFF6C067));

  const _LedgerLaneFilter(this.label, this.key, this.accent);

  final String label;
  final String key;
  final Color accent;
}

enum _LedgerWorkspaceView {
  casefile('Case File', 'casefile', Color(0xFF63BDFF)),
  integrity('Integrity', 'integrity', Color(0xFF34D399)),
  trace('Trace', 'trace', Color(0xFFC79CFF));

  const _LedgerWorkspaceView(this.label, this.key, this.accent);

  final String label;
  final String key;
  final Color accent;
}

class _LedgerReviewRow {
  final String id;
  final String typeLabel;
  final String title;
  final String summary;
  final DateTime occurredAt;
  final Color color;
  final int? sequence;
  final String sourceLabel;
  final String? eventId;
  final String? dispatchId;
  final String? siteId;
  final String? hash;
  final String? previousHash;
  final String? configurationLabel;
  final Color? configurationTextColor;
  final Color? configurationBorderColor;
  final String? detailSummary;
  final bool needsAttention;
  final String attentionReason;

  const _LedgerReviewRow({
    required this.id,
    required this.typeLabel,
    required this.title,
    required this.summary,
    required this.occurredAt,
    required this.color,
    required this.sourceLabel,
    required this.needsAttention,
    required this.attentionReason,
    this.sequence,
    this.eventId,
    this.dispatchId,
    this.siteId,
    this.hash,
    this.previousHash,
    this.configurationLabel,
    this.configurationTextColor,
    this.configurationBorderColor,
    this.detailSummary,
  });

  bool get isReport => typeLabel == 'REPORT GENERATED';
}

bool _hasTrackedReportSectionConfiguration(ReportGenerated event) {
  return event.reportSchemaVersion >= 3;
}

List<String> _includedReportSectionLabels(
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

List<String> _omittedReportSectionLabels(
  ReportSectionConfiguration configuration,
) {
  return <String>[
    if (!configuration.includeTimeline) 'Incident Timeline',
    if (!configuration.includeDispatchSummary) 'Dispatch Summary',
    if (!configuration.includeCheckpointCompliance) 'Checkpoint Compliance',
    if (!configuration.includeAiDecisionLog) 'AI Decision Log',
    if (!configuration.includeGuardMetrics) 'Guard Metrics',
  ];
}

String _reportSectionConfigurationHeadline(ReportGenerated event) {
  if (!_hasTrackedReportSectionConfiguration(event)) {
    return 'legacy receipt config';
  }
  final omitted = _omittedReportSectionLabels(event.sectionConfiguration);
  if (omitted.isEmpty) {
    return 'all sections included';
  }
  return '${omitted.length} sections omitted';
}

String _reportSectionConfigurationDetail(ReportGenerated event) {
  if (!_hasTrackedReportSectionConfiguration(event)) {
    return 'Legacy receipt. Per-section report configuration was not captured for this generated report.';
  }
  final included = _includedReportSectionLabels(event.sectionConfiguration);
  final omitted = _omittedReportSectionLabels(event.sectionConfiguration);
  final includedLabel = included.isEmpty ? 'None' : included.join(', ');
  final omittedLabel = omitted.isEmpty ? 'None' : omitted.join(', ');
  return 'Included: $includedLabel. Omitted: $omittedLabel.';
}

String? _reportBrandingHeadline(ReportGenerated event) {
  if (!event.brandingConfiguration.isConfigured) {
    return null;
  }
  return event.brandingUsesOverride
      ? 'custom branding override'
      : 'default partner branding';
}

String _reportBrandingDetail(ReportGenerated event) {
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

ReportEntryContext? _reportInvestigationContext(ReportGenerated event) {
  return ReportEntryContext.fromStorageValue(event.investigationContextKey);
}

String? _reportInvestigationHeadline(ReportGenerated event) {
  return switch (_reportInvestigationContext(event)) {
    ReportEntryContext.governanceBrandingDrift => 'governance handoff',
    null => null,
  };
}

String _reportInvestigationDetail(ReportGenerated event) {
  return switch (_reportInvestigationContext(event)) {
    ReportEntryContext.governanceBrandingDrift =>
      'Investigation: this receipt was generated from a Governance branding-drift handoff.',
    null => 'Investigation: routine report review.',
  };
}
