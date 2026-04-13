import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/crm/reporting/report_section_configuration.dart';
import '../domain/evidence/evidence_provenance.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/guard_checked_in.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/partner_dispatch_status_declared.dart';
import '../domain/events/patrol_completed.dart';
import '../domain/events/report_generated.dart';
import '../domain/events/response_arrived.dart';
import '../domain/events/vehicle_visit_review_recorded.dart';
import '../application/report_entry_context.dart';
import 'components/onyx_status_banner.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';

const _eventsPanelColor = Color(0xFF13131E);
const _eventsPanelTint = Color(0xFF1A1A2E);
const _eventsPanelMuted = Color(0xFF1A1A2E);
const _eventsBorderColor = Color(0x269D4BFF);
const _eventsTitleColor = Color(0xFFE8E8F0);
const _eventsBodyColor = Color(0x80FFFFFF);
const _eventsMutedColor = Color(0x4DFFFFFF);
const _eventsAccentBlue = Color(0xFF9D4BFF);

class EventsPage extends StatefulWidget {
  final List<DispatchEvent> events;

  const EventsPage({super.key, required this.events});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  static const int _maxTimelineRows = 50;
  static const int _maxDetailRows = 24;
  static const double _spaceSm = 6;
  static const double _spaceMd = 8;
  String _typeFilter = _allValue;
  String _siteFilter = _allValue;
  String _guardFilter = _allValue;
  _TimeWindow _timeWindow = _TimeWindow.last24h;
  _EventLaneFilter _laneFilter = _EventLaneFilter.all;
  _EventWorkspaceView _workspaceView = _EventWorkspaceView.casefile;
  bool _showAdvancedFilters = false;
  String _lastActionFeedback = '';
  DispatchEvent? _selected;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _allValue = 'ALL';

  @override
  Widget build(BuildContext context) {
    final handsetLayout = isHandsetLayout(context);
    final timeline = [...widget.events]
      ..sort((a, b) => b.sequence.compareTo(a.sequence));
    final forensicRows = timeline.map(_toForensicRow).toList();

    final allTypes = _distinctValues(forensicRows.map((r) => r.info.label));
    final allSites = _distinctValues(forensicRows.map((r) => r.siteId));
    final allGuards = _distinctValues(forensicRows.map((r) => r.guardId));

    final filterNow = DateTime.now().toUtc();
    final filtered = forensicRows
        .where((row) => _matchesFilters(row, filterNow))
        .toList(growable: false);
    final laneFiltered = filtered
        .where((row) => _matchesLaneFilter(row, _laneFilter))
        .toList(growable: false);
    final visibleRows = laneFiltered
        .take(_maxTimelineRows)
        .toList(growable: false);
    final hiddenRows = laneFiltered.length - visibleRows.length;
    final selected = _selectedRowForVisibleRows(visibleRows);
    final relatedRows = selected == null
        ? const <_ForensicRow>[]
        : _relatedRows(filtered, selected);

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 980 || selected == null) {
            return const SizedBox.shrink();
          }
          return Drawer(
            width: 360,
            backgroundColor: _eventsPanelTint,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: _selectedEventWorkspace(
                  row: selected,
                  relatedRows: relatedRows,
                  useExpandedBody: false,
                ),
              ),
            ),
          );
        },
      ),
      body: OnyxPageScaffold(
        child: LayoutBuilder(
          builder: (context, viewport) {
            const contentPadding = EdgeInsets.all(16);
            final useScrollFallback =
                handsetLayout ||
                viewport.maxHeight < 680 ||
                viewport.maxWidth < 980;
            final boundedDesktopSurface =
                !useScrollFallback &&
                viewport.hasBoundedHeight &&
                viewport.maxHeight.isFinite;
            final ultrawideSurface = isUltrawideLayout(
              context,
              viewportWidth: viewport.maxWidth,
            );
            final widescreenSurface = isWidescreenLayout(
              context,
              viewportWidth: viewport.maxWidth,
            );
            final surfaceMaxWidth = ultrawideSurface
                ? viewport.maxWidth
                : widescreenSurface
                ? viewport.maxWidth
                : 1540.0;
            final mergeWorkspaceBannerIntoHero =
                boundedDesktopSurface && !handsetLayout;
            final chainIntegrityIssueCount = visibleRows
                .where(
                  (row) =>
                      row.event is ExecutionDenied ||
                      (row.event is ExecutionCompleted &&
                          !(row.event as ExecutionCompleted).success),
                )
                .length;
            final chainIntact = chainIntegrityIssueCount == 0;
            final chainIntegrityMessage = chainIntact
                ? 'Chain intact'
                : '$chainIntegrityIssueCount chain integrity issues need review';

            final hero = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OnyxPageHeader(
                  title: 'Events Scope',
                  subtitle: 'Event security and chain integrity.',
                  icon: Icons.event_note_rounded,
                  iconColor: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: _spaceSm),
                OnyxStatusBanner(
                  message: chainIntegrityMessage,
                  severity: chainIntact
                      ? OnyxSeverity.success
                      : OnyxSeverity.critical,
                ),
                const SizedBox(height: _spaceSm),
                _heroHeader(
                  context,
                  totalCount: forensicRows.length,
                  filteredCount: laneFiltered.length,
                  selectedCount: selected == null ? 0 : 1,
                  laneLabel: _laneFilter.label,
                  workspaceBanner: mergeWorkspaceBannerIntoHero
                      ? _workspaceStatusBanner(
                          context,
                          filteredRows: filtered,
                          visibleRows: visibleRows,
                          selected: selected,
                          relatedRows: relatedRows,
                          shellless: true,
                        )
                      : null,
                ),
              ],
            );

            Widget buildSurfaceBody({required bool expandedPanels}) {
              final content = <Widget>[
                if (!handsetLayout && !mergeWorkspaceBannerIntoHero) ...[
                  _workspaceStatusBanner(
                    context,
                    filteredRows: filtered,
                    visibleRows: visibleRows,
                    selected: selected,
                    relatedRows: relatedRows,
                  ),
                  const SizedBox(height: _spaceSm),
                ],
                _overviewGrid(
                  totalCount: forensicRows.length,
                  filteredCount: laneFiltered.length,
                  latestSequence: timeline.isEmpty
                      ? null
                      : timeline.first.sequence,
                  laneLabel: _laneFilter.label,
                  filteredRows: filtered,
                  selected: selected,
                  relatedRows: relatedRows,
                ),
                const SizedBox(height: _spaceSm),
              ];

              if (expandedPanels) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...content,
                    Expanded(
                      child: _eventsReviewWorkspace(
                        allTypes: allTypes,
                        allSites: allSites,
                        allGuards: allGuards,
                        filteredRows: filtered,
                        visibleRows: visibleRows,
                        relatedRows: relatedRows,
                        hiddenRows: hiddenRows,
                        selected: selected,
                        showSelectedWorkspace: true,
                        embedSelectedWorkspaceInFlow: false,
                        useExpandedPanels: true,
                      ),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...content,
                  _eventsReviewWorkspace(
                    allTypes: allTypes,
                    allSites: allSites,
                    allGuards: allGuards,
                    filteredRows: filtered,
                    visibleRows: visibleRows,
                    relatedRows: relatedRows,
                    hiddenRows: hiddenRows,
                    selected: selected,
                    showSelectedWorkspace: false,
                    embedSelectedWorkspaceInFlow: !handsetLayout,
                    useExpandedPanels: false,
                  ),
                ],
              );
            }

            return OnyxViewportWorkspaceLayout(
              padding: contentPadding,
              maxWidth: surfaceMaxWidth,
              lockToViewport: boundedDesktopSurface,
              spacing: 5,
              header: hero,
              body: buildSurfaceBody(expandedPanels: boundedDesktopSurface),
            );
          },
        ),
      ),
    );
  }

  _ForensicRow? _selectedRowForVisibleRows(List<_ForensicRow> visibleRows) {
    if (visibleRows.isEmpty) {
      if (_selected != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selected = null);
        });
      }
      return null;
    }
    final selectedEventId = _selected?.eventId;
    if (selectedEventId == null || selectedEventId.isEmpty) {
      final fallback = visibleRows.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selected = fallback.event);
      });
      return fallback;
    }
    final row = visibleRows.firstWhere(
      (row) => row.event.eventId == selectedEventId,
      orElse: () => visibleRows.first,
    );
    if (row.event.eventId != selectedEventId) {
      // Selected event no longer in visible rows — sync state to displayed row.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selected = row.event);
      });
    }
    return row;
  }

  Widget _heroHeader(
    BuildContext context, {
    required int totalCount,
    required int filteredCount,
    required int selectedCount,
    required String laneLabel,
    Widget? workspaceBanner,
  }) {
    final windowLabel = _timeWindow.label;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _eventsPanelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _eventsBorderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 920;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.timeline_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EVENT WAR ROOM',
                          style: GoogleFonts.inter(
                            color: _eventsTitleColor,
                            fontSize: compact ? 14 : 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pick the event. Check proof. Move fast.',
                          style: GoogleFonts.inter(
                            color: _eventsBodyColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _heroChip('Window', windowLabel),
                  _heroChip('Lane', laneLabel),
                  _heroChip('Filtered', '$filteredCount of $totalCount'),
                  _heroChip('Selected', '$selectedCount'),
                  _heroChip('Filters', '${_activeFilterCount()} active'),
                ],
              ),
            ],
          );
          final actions = Wrap(
            spacing: 5,
            runSpacing: 5,
            alignment: WrapAlignment.end,
            children: [
              _heroActionButton(
                key: const ValueKey('events-view-governance-button'),
                icon: Icons.open_in_new,
                label: 'OPEN GOVERNANCE DESK',
                accent: const Color(0xFF93C5FD),
                onPressed: () => _openGovernanceDialog(context),
              ),
              _heroActionButton(
                key: const ValueKey('events-view-ledger-button'),
                icon: Icons.account_tree_outlined,
                label: 'OPEN SOVEREIGN LEDGER',
                accent: const Color(0xFFA78BFA),
                onPressed: () => _openLedgerDialog(context),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 4),
                actions,
                if (workspaceBanner != null) ...[
                  const SizedBox(height: 4),
                  workspaceBanner,
                ],
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleBlock),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 208),
                    child: actions,
                  ),
                ],
              ),
              if (workspaceBanner != null) ...[
                const SizedBox(height: 4),
                workspaceBanner,
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _heroChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: _eventsPanelColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _eventsBorderColor),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.inter(
                color: _eventsMutedColor,
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: _eventsTitleColor,
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
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
    return FilledButton.tonalIcon(
      key: key,
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: accent.withValues(alpha: 0.12),
        foregroundColor: accent,
        side: BorderSide(color: accent.withValues(alpha: 0.28)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        textStyle: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }

  Widget _overviewGrid({
    required int totalCount,
    required int filteredCount,
    required int? latestSequence,
    required String laneLabel,
    required List<_ForensicRow> filteredRows,
    required _ForensicRow? selected,
    required List<_ForensicRow> relatedRows,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 4
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        final aspectRatio = constraints.maxWidth >= 1800
            ? 3.95
            : columns == 4
            ? 3.65
            : columns == 2
            ? 2.9
            : 2.2;
        return GridView.count(
          key: const ValueKey('events-overview-grid'),
          crossAxisCount: columns,
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
          childAspectRatio: aspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _overviewCard(
              title: 'Timeline Events',
              value: '$totalCount',
              detail:
                  'Immutable forensic rows available for review in this session.',
              icon: Icons.timeline_rounded,
              accent: const Color(0xFF63BDFF),
            ),
            _overviewCard(
              title: 'Visible Rows',
              value: '$filteredCount',
              detail:
                  '${_activeFilterCount()} active filters plus the $laneLabel lane are shaping the review.',
              icon: Icons.filter_alt_outlined,
              accent: const Color(0xFF59D79B),
            ),
            _selectedEventOverviewCard(
              filteredRows: filteredRows,
              selected: selected,
              relatedRows: relatedRows,
            ),
            _overviewCard(
              title: 'Latest Sequence',
              value: latestSequence == null ? 'None' : '$latestSequence',
              detail: 'Newest event sequence available for timeline replay.',
              icon: Icons.pin_outlined,
              accent: const Color(0xFFF6C067),
            ),
          ],
        );
      },
    );
  }

  Widget _selectedEventOverviewCard({
    required List<_ForensicRow> filteredRows,
    required _ForensicRow? selected,
    required List<_ForensicRow> relatedRows,
  }) {
    final hasScopedRowsOutsideLane =
        selected == null && filteredRows.isNotEmpty;
    final intelligenceCount = _laneCountForFilter(
      filteredRows,
      _EventLaneFilter.intelligence,
    );
    final canWidenWindow = _timeWindow != _TimeWindow.all;
    final canResetScope =
        _activeFilterCount() > 0 || _laneFilter != _EventLaneFilter.all;
    final accent =
        selected?.info.color ??
        (hasScopedRowsOutsideLane
            ? const Color(0xFF63BDFF)
            : const Color(0xFFF6C067));
    final title = selected == null
        ? 'GET A CASE BACK'
        : _eventNextMoveLabel(selected.event);
    final detail = selected == null
        ? hasScopedRowsOutsideLane
              ? 'Rows still sit outside this lane. Open the full stream or switch lanes to pin one fast.'
              : 'Nothing is pinned in this window. Widen the view or reset scope so the board can pull a live case back.'
        : '${selected.info.label} • ${_eventNextMoveDetail(selected.event)}';
    final actions = <Widget>[
      if (selected != null) ...[
        _overviewCardAction(
          key: const ValueKey('events-overview-selected-open-casefile'),
          label: 'Case File',
          accent: const Color(0xFFA78BFA),
          selected: _workspaceView == _EventWorkspaceView.casefile,
          onTap: () => _setWorkspaceView(_EventWorkspaceView.casefile),
        ),
        _overviewCardAction(
          key: const ValueKey('events-overview-selected-open-evidence'),
          label: 'Evidence',
          accent: const Color(0xFF63BDFF),
          selected: _workspaceView == _EventWorkspaceView.evidence,
          onTap: () => _setWorkspaceView(_EventWorkspaceView.evidence),
        ),
        if (relatedRows.isNotEmpty ||
            _workspaceView == _EventWorkspaceView.chain)
          _overviewCardAction(
            key: const ValueKey('events-overview-selected-open-chain'),
            label: 'Chain',
            accent: const Color(0xFF59D79B),
            selected: _workspaceView == _EventWorkspaceView.chain,
            onTap: () => _setWorkspaceView(_EventWorkspaceView.chain),
          ),
        if (_laneFilter != _EventLaneFilter.all)
          _overviewCardAction(
            key: const ValueKey('events-overview-selected-open-all-events'),
            label: 'All Events',
            accent: _EventLaneFilter.all.accent,
            onTap: () => _setLaneFilter(_EventLaneFilter.all),
          ),
      ] else ...[
        if (hasScopedRowsOutsideLane)
          _overviewCardAction(
            key: const ValueKey('events-overview-selected-open-all-events'),
            label: 'Open All Events',
            accent: _EventLaneFilter.all.accent,
            onTap: () => _setLaneFilter(_EventLaneFilter.all),
          ),
        if (intelligenceCount > 0 &&
            _laneFilter != _EventLaneFilter.intelligence)
          _overviewCardAction(
            key: const ValueKey('events-overview-selected-open-intelligence'),
            label: 'Intelligence Lane',
            accent: _EventLaneFilter.intelligence.accent,
            onTap: () => _setLaneFilter(_EventLaneFilter.intelligence),
          ),
        if (canWidenWindow)
          _overviewCardAction(
            key: const ValueKey('events-overview-selected-open-all-time'),
            label: 'All Time',
            accent: const Color(0xFFF6C067),
            onTap: () => _setTimeWindow(_TimeWindow.all),
          ),
        if (canResetScope)
          _overviewCardAction(
            key: const ValueKey('events-overview-selected-reset-scope'),
            label: 'Reset Scope',
            accent: const Color(0xFF59D79B),
            onTap: () => _resetForensicFilters(resetLane: true),
          ),
      ],
    ];

    return Container(
      key: const ValueKey('events-overview-selected-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.12), _eventsPanelColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    Icons.visibility_outlined,
                    color: accent,
                    size: 12,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    selected == null ? 'GET FOCUS BACK' : 'DO THIS NOW',
                    style: GoogleFonts.inter(
                      color: accent,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: _eventsTitleColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: _eventsBodyColor,
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 3,
              runSpacing: 3,
              children: [
                if (selected != null) ...[
                  _pill(selected.event.eventId, color: accent),
                  _pill(selected.info.label),
                  _pill('SEQ ${selected.event.sequence}'),
                  _pill('${relatedRows.length} linked'),
                ] else ...[
                  _pill(_laneFilter.label, color: _laneFilter.accent),
                  if (filteredRows.isNotEmpty)
                    _pill('${filteredRows.length} scoped'),
                  if (_activeFilterCount() > 0)
                    _pill('${_activeFilterCount()} filters'),
                ],
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 2),
              Wrap(spacing: 3, runSpacing: 3, children: actions),
            ],
          ],
        ),
      ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _eventsPanelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _eventsBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: accent, size: 10),
              ),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.robotoMono(
                  color: accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              color: _eventsMutedColor,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: _eventsBodyColor,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewCardAction({
    required Key key,
    required String label,
    required Color accent,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return TextButton(
      key: key,
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: selected ? const Color(0xFF08111E) : accent,
        backgroundColor: selected
            ? accent.withValues(alpha: 0.9)
            : accent.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w800),
      ),
    );
  }

  void _showSurfaceLinkDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _eventsPanelColor,
          title: Text(
            title,
            style: GoogleFonts.inter(
              color: _eventsTitleColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.inter(color: _eventsBodyColor, height: 1.45),
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

  void _openGovernanceDialog(BuildContext context) {
    _showSurfaceLinkDialog(
      context,
      title: 'Governance Desk Ready',
      message:
          'Use Governance Desk to review blocker posture, sovereign readiness, and compliance detail for the selected forensic scope.',
    );
  }

  void _openLedgerDialog(BuildContext context) {
    _showSurfaceLinkDialog(
      context,
      title: 'Sovereign Ledger Ready',
      message:
          'Use Sovereign Ledger to inspect provenance, evidence continuity, and immutable verification for the selected event chain.',
    );
  }

  Widget _workspaceStatusBanner(
    BuildContext context, {
    required List<_ForensicRow> filteredRows,
    required List<_ForensicRow> visibleRows,
    required _ForensicRow? selected,
    required List<_ForensicRow> relatedRows,
    bool shellless = false,
  }) {
    final bannerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _workspaceStatusPill(
              icon: Icons.timeline_outlined,
              label: '${visibleRows.length} Visible',
              accent: const Color(0xFF63BDFF),
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
              label: 'Focus ${selected?.event.eventId ?? 'None'}',
              accent: selected?.info.color ?? const Color(0xFF94A3B8),
            ),
            _workspaceStatusPill(
              icon: Icons.link_outlined,
              label: '${relatedRows.length} Linked',
              accent: relatedRows.isEmpty
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF59D79B),
            ),
            _workspaceStatusPill(
              icon: Icons.schedule_outlined,
              label: _timeWindow.label,
              accent: const Color(0xFFF6C067),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Pick one event. Check proof, check chain, then route to governance or ledger.',
          style: GoogleFonts.inter(
            color: _eventsBodyColor,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
    if (shellless) {
      return KeyedSubtree(
        key: const ValueKey('events-workspace-status-banner'),
        child: bannerContent,
      );
    }
    return Container(
      key: const ValueKey('events-workspace-status-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _eventsPanelColor,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _eventsBorderColor),
      ),
      child: bannerContent,
    );
  }

  Widget _workspaceStatusPill({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: _eventsPanelTint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: accent),
          const SizedBox(width: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              color: _eventsTitleColor,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventsReviewWorkspace({
    required List<String> allTypes,
    required List<String> allSites,
    required List<String> allGuards,
    required List<_ForensicRow> filteredRows,
    required List<_ForensicRow> visibleRows,
    required List<_ForensicRow> relatedRows,
    required int hiddenRows,
    required _ForensicRow? selected,
    required bool showSelectedWorkspace,
    required bool embedSelectedWorkspaceInFlow,
    required bool useExpandedPanels,
  }) {
    if (!showSelectedWorkspace) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eventLaneRail(
            filteredRows: filteredRows,
            visibleRows: visibleRows,
            hiddenRows: hiddenRows,
            openDrawerOnSelect: !embedSelectedWorkspaceInFlow,
            useExpandedList: false,
          ),
          if (embedSelectedWorkspaceInFlow) ...[
            const SizedBox(height: _spaceSm),
            selected == null
                ? _emptyDetailPane(filteredRows: filteredRows)
                : _selectedEventWorkspace(
                    row: selected,
                    relatedRows: relatedRows,
                    useExpandedBody: false,
                  ),
          ],
          const SizedBox(height: 5),
          _contextRail(
            allTypes: allTypes,
            allSites: allSites,
            allGuards: allGuards,
            filteredRows: filteredRows,
            selected: selected,
            relatedRows: relatedRows,
            filteredCount: visibleRows.length,
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final railWidth = constraints.maxWidth >= 1900
            ? 232.0
            : constraints.maxWidth >= 1460
            ? 224.0
            : 212.0;
        final contextWidth = constraints.maxWidth >= 1900
            ? 196.0
            : constraints.maxWidth >= 1460
            ? 188.0
            : 180.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: railWidth,
              child: _eventLaneRail(
                filteredRows: filteredRows,
                visibleRows: visibleRows,
                hiddenRows: hiddenRows,
                openDrawerOnSelect: false,
                useExpandedList: true,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: selected == null
                  ? _emptyDetailPane(filteredRows: filteredRows)
                  : _selectedEventWorkspace(
                      row: selected,
                      relatedRows: relatedRows,
                      useExpandedBody: useExpandedPanels,
                    ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: contextWidth,
              child: _contextRail(
                allTypes: allTypes,
                allSites: allSites,
                allGuards: allGuards,
                filteredRows: filteredRows,
                selected: selected,
                relatedRows: relatedRows,
                filteredCount: visibleRows.length,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _eventLaneRail({
    required List<_ForensicRow> filteredRows,
    required List<_ForensicRow> visibleRows,
    required int hiddenRows,
    required bool openDrawerOnSelect,
    required bool useExpandedList,
  }) {
    final timelineList = visibleRows.isEmpty
        ? _emptyState(filteredRows: filteredRows)
        : ListView.separated(
            shrinkWrap: !useExpandedList,
            primary: useExpandedList,
            physics: useExpandedList
                ? null
                : const NeverScrollableScrollPhysics(),
            itemCount: visibleRows.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: _spaceSm),
            itemBuilder: (context, index) {
              final row = visibleRows[index];
              return _eventLaneCard(
                row,
                openDrawerOnSelect: openDrawerOnSelect,
              );
            },
          );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: onyxForensicSurfaceCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF3C79BB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: _spaceSm),
          Text(
            'Review Lanes',
            style: GoogleFonts.inter(
              color: _eventsTitleColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lane-focused cards keep the triage rail readable while the selected event expands into a deeper case file.',
            style: GoogleFonts.inter(
              color: const Color(0xFF7E95B4),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: _spaceSm),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: _EventLaneFilter.values
                .map(
                  (filter) => _laneFilterChip(
                    filter: filter,
                    count: _laneCountForFilter(filteredRows, filter),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: _spaceSm),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _pill('${visibleRows.length} visible'),
              _pill('${_activeFilterCount()} advanced filters'),
              _pill(_laneFilter.label, color: _laneFilter.accent),
            ],
          ),
          const SizedBox(height: _spaceSm),
          if (useExpandedList)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: timelineList),
                  if (hiddenRows > 0) ...[
                    const SizedBox(height: _spaceSm),
                    OnyxTruncationHint(
                      visibleCount: visibleRows.length,
                      totalCount: visibleRows.length + hiddenRows,
                      subject: 'event rows',
                      hiddenDescriptor: 'additional rows',
                      color: const Color(0xFF8FA8CA),
                    ),
                  ],
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                timelineList,
                if (hiddenRows > 0) ...[
                  const SizedBox(height: _spaceSm),
                  OnyxTruncationHint(
                    visibleCount: visibleRows.length,
                    totalCount: visibleRows.length + hiddenRows,
                    subject: 'event rows',
                    hiddenDescriptor: 'additional rows',
                    color: const Color(0xFF8FA8CA),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _eventLaneCard(_ForensicRow row, {required bool openDrawerOnSelect}) {
    final event = row.event;
    final isSelected = _selected?.eventId == event.eventId;
    final timestampText = 'UTC ${event.occurredAt.toIso8601String()}';
    final chainLabel = _chainLabel(row);
    return InkWell(
      key: ValueKey('events-lane-card-${event.eventId}'),
      onTap: () => _selectEvent(event, openDrawer: openDrawerOnSelect),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: onyxForensicRowDecoration(isSelected: isSelected),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: row.info.color,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.info.label,
                        style: GoogleFonts.inter(
                          color: row.info.color,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timestampText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF89A0BE),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
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
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                _pill('SEQ ${event.sequence}'),
                if (row.siteId != null) _pill(row.siteId!),
                if (row.guardId != null) _pill(row.guardId!),
                _pill(chainLabel, color: row.info.color),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              row.info.summary,
              style: GoogleFonts.inter(
                color: _eventsBodyColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Event ID ${event.eventId}',
              style: GoogleFonts.inter(
                color: _eventsMutedColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contextRail({
    required List<String> allTypes,
    required List<String> allSites,
    required List<String> allGuards,
    required List<_ForensicRow> filteredRows,
    required _ForensicRow? selected,
    required List<_ForensicRow> relatedRows,
    required int filteredCount,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filterBar(
          allTypes: allTypes,
          allSites: allSites,
          allGuards: allGuards,
          filteredCount: filteredCount,
        ),
        const SizedBox(height: _spaceSm),
        _focusSnapshotCard(
          filteredRows: filteredRows,
          selected: selected,
          relatedRows: relatedRows,
          filteredCount: filteredCount,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) {
          return content;
        }
        return SingleChildScrollView(child: content);
      },
    );
  }

  Widget _focusSnapshotCard({
    required List<_ForensicRow> filteredRows,
    required _ForensicRow? selected,
    required List<_ForensicRow> relatedRows,
    required int filteredCount,
  }) {
    final focusEvent = selected?.event;
    final intelligenceCount = _laneCountForFilter(
      filteredRows,
      _EventLaneFilter.intelligence,
    );
    final canWidenWindow = _timeWindow != _TimeWindow.all;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _eventsPanelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _eventsBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF7FD0FF),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Scope Snapshot',
            style: GoogleFonts.inter(
              color: _eventsTitleColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            selected == null
                ? 'Select a row to pull site, dispatch, and evidence context into this rail.'
                : 'The current forensic focus keeps its lane, scope, and related chain within reach.',
            style: GoogleFonts.inter(
              color: _eventsBodyColor,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final useTwoColumns = constraints.maxWidth >= 220;
              final metricWidth = useTwoColumns
                  ? (constraints.maxWidth - 5) / 2
                  : constraints.maxWidth;
              final metrics = [
                _contextMetric(label: 'Lane', value: _laneFilter.label),
                _contextMetric(label: 'Visible Rows', value: '$filteredCount'),
                _contextMetric(
                  label: 'Site Scope',
                  value: selected?.siteId ?? 'No site selected',
                ),
                _contextMetric(
                  label: 'Dispatch Chain',
                  value: focusEvent == null
                      ? 'Awaiting selection'
                      : (_dispatchIdForEvent(focusEvent) ??
                            'No dispatch chain'),
                ),
                _contextMetric(
                  label: 'Linked Rows',
                  value: '${relatedRows.length}',
                ),
              ];
              return Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final metric in metrics)
                    SizedBox(width: metricWidth, child: metric),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              key: const ValueKey('events-context-focus-related-button'),
              onPressed: relatedRows.isEmpty
                  ? null
                  : () => _focusLinkedEvent(relatedRows),
              icon: const Icon(Icons.alt_route_rounded, size: 15),
              label: const Text('Focus Linked Event'),
            ),
          ),
          if (selected != null && relatedRows.isEmpty) ...[
            const SizedBox(height: 5),
            _forensicRecoveryDeck(
              key: const ValueKey('events-context-chain-recovery'),
              title: 'Chain Recovery Ready',
              detail:
                  'No additional rows share this site, guard, or dispatch inside the current filtered review window. Reopen the wider stream, widen the review horizon, or pivot evidence and ledger while keeping this case file pinned.',
              accent: selected.info.color,
              actions: [
                if (_laneFilter != _EventLaneFilter.all)
                  _forensicRecoveryAction(
                    key: const ValueKey('events-context-chain-open-all'),
                    label: 'Open All Events',
                    accent: _EventLaneFilter.all.accent,
                    onTap: () => _setLaneFilter(_EventLaneFilter.all),
                  ),
                if (intelligenceCount > 0 &&
                    _laneFilter != _EventLaneFilter.intelligence)
                  _forensicRecoveryAction(
                    key: const ValueKey(
                      'events-context-chain-open-intelligence',
                    ),
                    label: 'Intelligence Lane',
                    accent: _EventLaneFilter.intelligence.accent,
                    onTap: () => _setLaneFilter(_EventLaneFilter.intelligence),
                  ),
                if (canWidenWindow)
                  _forensicRecoveryAction(
                    key: const ValueKey('events-context-chain-open-all-time'),
                    label: 'All Time',
                    accent: const Color(0xFFF6C067),
                    onTap: () => _setTimeWindow(_TimeWindow.all),
                  ),
                _forensicRecoveryAction(
                  key: const ValueKey('events-context-chain-review-evidence'),
                  label: 'Review Evidence',
                  accent: _EventWorkspaceView.evidence.accent,
                  onTap: () => _setWorkspaceView(_EventWorkspaceView.evidence),
                ),
                _forensicRecoveryAction(
                  key: const ValueKey('events-context-chain-open-ledger'),
                  label: 'OPEN SOVEREIGN LEDGER',
                  accent: const Color(0xFFA78BFA),
                  onTap: () => _openLedgerDialog(context),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _contextMetric({required String label, required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _eventsPanelMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _eventsBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: _eventsMutedColor,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              color: _eventsTitleColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedEventWorkspace({
    required _ForensicRow row,
    required List<_ForensicRow> relatedRows,
    required bool useExpandedBody,
  }) {
    final workspacePanel = switch (_workspaceView) {
      _EventWorkspaceView.casefile => _casefilePanel(
        row,
        relatedRows: relatedRows,
        useScrollable: useExpandedBody,
      ),
      _EventWorkspaceView.evidence => _evidencePanel(
        row,
        relatedRows: relatedRows,
        useScrollable: useExpandedBody,
      ),
      _EventWorkspaceView.chain => _chainPanel(
        row,
        relatedRows: relatedRows,
        useScrollable: useExpandedBody,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: onyxForensicSurfaceCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOU ARE HERE',
            style: GoogleFonts.inter(
              color: _eventsTitleColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'One event. One proof trail. One next move.',
            style: GoogleFonts.inter(
              color: _eventsMutedColor,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          _selectedEventBanner(row, relatedRows),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _EventWorkspaceView.values
                .map((view) => _workspaceViewChip(view))
                .toList(),
          ),
          if (_lastActionFeedback.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              key: const ValueKey('events-last-action-feedback'),
              width: double.infinity,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0x122FD6A3),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0x402FD6A3)),
              ),
              child: Text(
                _lastActionFeedback,
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AF3D6),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          if (useExpandedBody)
            Expanded(child: workspacePanel)
          else
            workspacePanel,
        ],
      ),
    );
  }

  Widget _selectedEventBanner(
    _ForensicRow row,
    List<_ForensicRow> relatedRows,
  ) {
    final dispatchId = _dispatchIdForEvent(row.event);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [row.info.color.withValues(alpha: 0.12), _eventsPanelColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: row.info.color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DO THIS NOW',
            style: GoogleFonts.inter(
              color: row.info.color,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _eventNextMoveLabel(row.event),
            style: GoogleFonts.inter(
              color: _eventsTitleColor,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            row.info.label,
            style: GoogleFonts.inter(
              color: row.info.color.withValues(alpha: 0.92),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _eventNextMoveDetail(row.event),
            style: GoogleFonts.inter(
              color: _eventsBodyColor,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _pill('SEQ ${row.event.sequence}'),
              _pill('UTC ${row.event.occurredAt.toIso8601String()}'),
              if (row.siteId != null) _pill(row.siteId!),
              if (dispatchId != null) _pill(dispatchId, color: row.info.color),
            ],
          ),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final metricChildren = [
                _miniSignalCard(
                  label: 'Selected ID',
                  value: row.event.eventId,
                  accent: row.info.color,
                  valueKey: const ValueKey('events-selected-event-id'),
                ),
                _miniSignalCard(
                  label: 'Linked Rows',
                  value: '${relatedRows.length}',
                  accent: const Color(0xFF63BDFF),
                ),
                _miniSignalCard(
                  label: 'Review Lane',
                  value: _laneFilter.label,
                  accent: _laneFilter.accent,
                ),
              ];
              if (compact) {
                return Column(
                  children:
                      metricChildren
                          .expand(
                            (widget) => <Widget>[
                              widget,
                              const SizedBox(height: 4),
                            ],
                          )
                          .toList()
                        ..removeLast(),
                );
              }
              return Row(
                children:
                    metricChildren
                        .expand(
                          (widget) => <Widget>[
                            Expanded(child: widget),
                            const SizedBox(width: 4),
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

  Widget _miniSignalCard({
    required String label,
    required String value,
    required Color accent,
    Key? valueKey,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _eventsPanelMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: _eventsMutedColor,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            key: valueKey,
            style: GoogleFonts.inter(
              color: _eventsTitleColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _eventNextMoveLabel(DispatchEvent event) {
    if (event is IntelligenceReceived) return 'CHECK THE PROOF';
    if (event is DecisionCreated) return 'VERIFY THE CALL';
    if (event is ResponseArrived) return 'CLOSE THE LOOP';
    if (event is ExecutionDenied) return 'ESCALATE BLOCKER';
    if (event is ExecutionCompleted) return 'VERIFY OUTCOME';
    if (event is GuardCheckedIn) return 'CONFIRM FIELD STATUS';
    if (event is PartnerDispatchStatusDeclared) return 'CHECK PARTNER STATUS';
    if (event is PatrolCompleted) return 'CLOSE PATROL';
    if (event is IncidentClosed) return 'LOCK THE RECORD';
    if (event is ReportGenerated) return 'CHECK THE RECEIPT';
    if (event is VehicleVisitReviewRecorded) return 'REVIEW THE VISIT';
    return 'HOLD THE RECORD';
  }

  String _eventNextMoveDetail(DispatchEvent event) {
    if (event is IntelligenceReceived) {
      return 'Review the signal, verify the evidence, and decide if this turns into action.';
    }
    if (event is DecisionCreated) {
      return 'A command call was logged. Make sure the action path still fits the live board.';
    }
    if (event is ResponseArrived) {
      return 'Field response is on scene. Confirm outcome, update the client, and decide whether to close or escalate.';
    }
    if (event is ExecutionDenied) {
      return 'Something blocked execution. Open the chain, expose the blocker, and escalate fast.';
    }
    if (event is ExecutionCompleted) {
      return 'The action completed. Verify proof, capture the result, and lock the record.';
    }
    if (event is GuardCheckedIn) {
      return 'Field status just changed. Confirm the guard, the site, and whether this clears the watch gap.';
    }
    if (event is PartnerDispatchStatusDeclared) {
      return 'Partner posture moved. Check the handoff before the board drifts out of sync.';
    }
    if (event is PatrolCompleted) {
      return 'Patrol finished. Verify the result, keep the route covered, and archive the clean run.';
    }
    if (event is IncidentClosed) {
      return 'This incident is marked closed. Make sure the proof trail and audit chain are complete.';
    }
    if (event is ReportGenerated) {
      return 'A report receipt exists. Verify the artifact and move it to the right governance trail.';
    }
    if (event is VehicleVisitReviewRecorded) {
      return 'The visit review is in. Check the record, confirm outcome, and keep the chain intact.';
    }
    return 'Keep the record clean, confirm the proof, and route the case where it belongs.';
  }

  Widget _workspaceViewChip(_EventWorkspaceView view) {
    final selected = _workspaceView == view;
    return InkWell(
      key: ValueKey('events-workspace-view-${view.key}'),
      onTap: () => _setWorkspaceView(view),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? view.accent.withValues(alpha: 0.12)
              : _eventsPanelColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? view.accent.withValues(alpha: 0.45)
                : _eventsBorderColor,
          ),
        ),
        child: Text(
          view.label,
          style: GoogleFonts.inter(
            color: selected ? view.accent : _eventsBodyColor,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _casefilePanel(
    _ForensicRow row, {
    required List<_ForensicRow> relatedRows,
    required bool useScrollable,
  }) {
    final details = _detailsFor(row.event);
    final visibleDetails = details.take(_maxDetailRows).toList(growable: false);
    final hiddenDetails = details.length - visibleDetails.length;
    final content = <Widget>[
      _detailHero(row),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _miniSignalCard(
            label: 'Detail Rows',
            value: '${details.length}',
            accent: const Color(0xFF63BDFF),
          ),
          _miniSignalCard(
            label: 'Linked Chain',
            value: '${relatedRows.length}',
            accent: const Color(0xFF59D79B),
          ),
          _miniSignalCard(
            label: 'Scope',
            value: row.siteId ?? 'Unassigned',
            accent: row.info.color,
          ),
        ],
      ),
      if (row.event is IntelligenceReceived) ...[
        const SizedBox(height: 10),
        IntegrityCertificatePreviewCard(
          event: row.event as IntelligenceReceived,
        ),
      ],
      const SizedBox(height: 10),
      ...visibleDetails.expand(
        (item) => <Widget>[_kv(item.$1, item.$2), const SizedBox(height: 8)],
      ),
      if (hiddenDetails > 0)
        OnyxTruncationHint(
          visibleCount: visibleDetails.length,
          totalCount: details.length,
          subject: 'detail rows',
          color: _eventsMutedColor,
        ),
    ];

    return _workspacePanelContainer(
      key: const ValueKey('events-workspace-panel-casefile'),
      children: content,
      useScrollable: useScrollable,
      shellless: useScrollable,
    );
  }

  Widget _evidencePanel(
    _ForensicRow row, {
    required List<_ForensicRow> relatedRows,
    required bool useScrollable,
  }) {
    final intelligenceEvent = row.event is IntelligenceReceived
        ? row.event as IntelligenceReceived
        : null;
    final reportEvent = row.event is ReportGenerated
        ? row.event as ReportGenerated
        : null;
    final content = <Widget>[
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _miniSignalCard(
            label: 'Event ID',
            value: row.event.eventId,
            accent: row.info.color,
          ),
          _miniSignalCard(
            label: 'Chain Anchor',
            value: _dispatchIdForEvent(row.event) ?? 'No dispatch',
            accent: const Color(0xFF63BDFF),
          ),
          _miniSignalCard(
            label: 'Evidence Ready',
            value: intelligenceEvent != null
                ? _intelligenceEvidenceReadiness(intelligenceEvent)
                : reportEvent != null
                ? 'Receipt Captured'
                : 'Metadata Only',
            accent: const Color(0xFFF6C067),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (intelligenceEvent != null) ...[
        IntegrityCertificatePreviewCard(event: intelligenceEvent),
        const SizedBox(height: 10),
        _contextMetric(
          label: 'Canonical Hash',
          value: _shortValue(intelligenceEvent.canonicalHash),
        ),
        const SizedBox(height: 8),
        _contextMetric(
          label: 'Snapshot Reference',
          value: _shortValue(intelligenceEvent.snapshotReferenceHash ?? ''),
        ),
        const SizedBox(height: 8),
        _contextMetric(
          label: 'Clip Reference',
          value: _shortValue(intelligenceEvent.clipReferenceHash ?? ''),
        ),
      ] else if (reportEvent != null) ...[
        _contextMetric(
          label: 'Receipt Hash',
          value: _shortValue(reportEvent.contentHash),
        ),
        const SizedBox(height: 8),
        _contextMetric(
          label: 'PDF Hash',
          value: _shortValue(reportEvent.pdfHash),
        ),
        const SizedBox(height: 8),
        _contextMetric(
          label: 'Configuration',
          value: _reportSectionConfigurationHeadline(reportEvent),
        ),
        const SizedBox(height: 8),
        _contextMetric(
          label: 'Branding Mode',
          value: _reportBrandingModeLabel(reportEvent),
        ),
      ] else ...[
        _contextMetric(
          label: 'Provenance Note',
          value:
              'This event contributes operational metadata to the chain but does not carry asset-level evidence from this surface.',
        ),
      ],
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const ValueKey('events-copy-event-id-button'),
          onPressed: () => _copyEventId(row.event.eventId),
          icon: const Icon(Icons.content_copy_rounded, size: 18),
          label: const Text('Copy Event ID'),
        ),
      ),
      if (relatedRows.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          '${relatedRows.length} linked rows remain available from the same site or dispatch chain.',
          style: GoogleFonts.inter(
            color: _eventsBodyColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ],
    ];

    return _workspacePanelContainer(
      key: const ValueKey('events-workspace-panel-evidence'),
      children: content,
      useScrollable: useScrollable,
      shellless: useScrollable,
    );
  }

  Widget _chainPanel(
    _ForensicRow row, {
    required List<_ForensicRow> relatedRows,
    required bool useScrollable,
  }) {
    final content = <Widget>[
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _miniSignalCard(
            label: 'Anchor Site',
            value: row.siteId ?? 'Unassigned',
            accent: row.info.color,
          ),
          _miniSignalCard(
            label: 'Dispatch Chain',
            value: _dispatchIdForEvent(row.event) ?? 'None',
            accent: const Color(0xFF63BDFF),
          ),
          _miniSignalCard(
            label: 'Linked Rows',
            value: '${relatedRows.length}',
            accent: const Color(0xFF59D79B),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (relatedRows.isEmpty)
        _contextMetric(
          label: 'Chain Status',
          value:
              'No additional rows share this site, guard, or dispatch within the current filtered review window.',
        )
      else
        ...relatedRows.expand(
          (relatedRow) => <Widget>[
            Container(
              key: ValueKey('events-related-row-${relatedRow.event.eventId}'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _eventsPanelMuted,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _eventsBorderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: relatedRow.info.color,
                    ),
                  ),
                  const SizedBox(width: _spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          relatedRow.info.label,
                          style: GoogleFonts.inter(
                            color: relatedRow.info.color,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          relatedRow.info.summary,
                          style: GoogleFonts.inter(
                            color: _eventsBodyColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _pill('SEQ ${relatedRow.event.sequence}'),
                            _pill(relatedRow.event.eventId),
                            if (relatedRow.guardId != null)
                              _pill(relatedRow.guardId!),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    key: ValueKey(
                      'events-chain-focus-${relatedRow.event.eventId}',
                    ),
                    onPressed: () => _focusForensicRow(
                      relatedRow,
                      view: _EventWorkspaceView.casefile,
                    ),
                    child: Text(
                      'Focus',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
    ];

    return _workspacePanelContainer(
      key: const ValueKey('events-workspace-panel-chain'),
      children: content,
      useScrollable: useScrollable,
      shellless: useScrollable,
    );
  }

  Widget _workspacePanelContainer({
    required Key key,
    required List<Widget> children,
    required bool useScrollable,
    bool shellless = false,
  }) {
    final body = useScrollable
        ? ListView(children: children)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          );
    if (shellless) {
      return KeyedSubtree(key: key, child: body);
    }
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: _eventsPanelColor,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _eventsBorderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A081B33),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: KeyedSubtree(key: key, child: body),
    );
  }

  Widget _laneFilterChip({
    required _EventLaneFilter filter,
    required int count,
  }) {
    final selected = _laneFilter == filter;
    return InkWell(
      key: ValueKey('events-lane-filter-${filter.key}'),
      onTap: () => _setLaneFilter(filter),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? filter.accent.withValues(alpha: 0.12)
              : _eventsPanelColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? filter.accent.withValues(alpha: 0.45)
                : _eventsBorderColor,
          ),
        ),
        child: Text(
          '${filter.label} $count',
          style: GoogleFonts.inter(
            color: selected ? filter.accent : _eventsBodyColor,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _filterBar({
    required List<String> allTypes,
    required List<String> allSites,
    required List<String> allGuards,
    required int filteredCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _eventsPanelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _eventsBorderColor),
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
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF3C79BB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final compactHeader = constraints.maxWidth < 720;
              if (!compactHeader) {
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Forensic Filters",
                        style: GoogleFonts.inter(
                          color: _eventsTitleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _pill("$filteredCount visible"),
                    const SizedBox(width: 6),
                    _pill("${_activeFilterCount()} active"),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: _resetForensicFilters,
                      child: Text(
                        "Reset Filters",
                        style: GoogleFonts.inter(
                          color: _eventsAccentBlue,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Forensic Filters",
                    style: GoogleFonts.inter(
                      color: _eventsTitleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _pill("$filteredCount visible"),
                      _pill("${_activeFilterCount()} active"),
                      TextButton(
                        onPressed: _resetForensicFilters,
                        child: Text(
                          "Reset Filters",
                          style: GoogleFonts.inter(
                            color: _eventsAccentBlue,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: _showAdvancedFilters,
              onExpansionChanged: (expanded) {
                setState(() => _showAdvancedFilters = expanded);
              },
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              iconColor: _eventsAccentBlue,
              collapsedIconColor: _eventsAccentBlue,
              title: Text(
                "Advanced Filters",
                style: GoogleFonts.inter(
                  color: _eventsAccentBlue,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              children: [
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _dropdown(
                      label: "Type",
                      value: _typeFilter,
                      options: [_allValue, ...allTypes],
                      onChanged: (v) => setState(() => _typeFilter = v),
                    ),
                    _dropdown(
                      label: "Site",
                      value: _siteFilter,
                      options: [_allValue, ...allSites],
                      onChanged: (v) => setState(() => _siteFilter = v),
                    ),
                    _dropdown(
                      label: "Guard",
                      value: _guardFilter,
                      options: [_allValue, ...allGuards],
                      onChanged: (v) => setState(() => _guardFilter = v),
                    ),
                    _dropdown(
                      label: "Window",
                      value: _timeWindow.label,
                      options: _TimeWindow.values.map((v) => v.label).toList(),
                      onChanged: (v) {
                        setState(() {
                          _timeWindow = _TimeWindow.values.firstWhere(
                            (entry) => entry.label == v,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 170, maxWidth: 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: _eventsMutedColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: _eventsPanelTint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _eventsBorderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: _eventsPanelColor,
                style: GoogleFonts.inter(
                  color: _eventsTitleColor,
                  fontSize: 11,
                ),
                items: options
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: _eventsPanelMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _eventsBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key,
            style: GoogleFonts.inter(
              color: _eventsMutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.inter(
              color: _eventsTitleColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState({required List<_ForensicRow> filteredRows}) {
    final hasRowsOutsideLane = filteredRows.isNotEmpty;
    final canResetFilters = _activeFilterCount() > 0;
    final canWidenWindow = _timeWindow != _TimeWindow.all;
    final intelligenceCount = _laneCountForFilter(
      filteredRows,
      _EventLaneFilter.intelligence,
    );
    return Container(
      key: const ValueKey('events-empty-state'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _eventsPanelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _eventsBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasRowsOutsideLane
                ? 'No rows in the ${_laneFilter.label} lane.'
                : 'No events match current forensic filters.',
            style: GoogleFonts.inter(
              color: _eventsTitleColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasRowsOutsideLane
                ? '${filteredRows.length} scoped row${filteredRows.length == 1 ? '' : 's'} are still available outside this lane. Pivot back to the full review stream or jump straight into an intelligence-first pass.'
                : 'The current advanced filters and ${_timeWindow.label.toLowerCase()} window left the forensic rail empty. Reset the scope or widen the review horizon to recover the timeline.',
            style: GoogleFonts.inter(
              color: _eventsBodyColor,
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
              if (hasRowsOutsideLane)
                FilledButton.tonalIcon(
                  key: const ValueKey('events-empty-open-all-events'),
                  onPressed: () => _setLaneFilter(_EventLaneFilter.all),
                  icon: const Icon(Icons.reorder_rounded, size: 18),
                  label: const Text('All Events'),
                ),
              if (hasRowsOutsideLane &&
                  intelligenceCount > 0 &&
                  _laneFilter != _EventLaneFilter.intelligence)
                FilledButton.tonalIcon(
                  key: const ValueKey('events-empty-open-intelligence'),
                  onPressed: () =>
                      _setLaneFilter(_EventLaneFilter.intelligence),
                  icon: const Icon(Icons.psychology_alt_outlined, size: 18),
                  label: const Text('Intelligence Lane'),
                ),
              if (canResetFilters)
                OutlinedButton.icon(
                  key: const ValueKey('events-empty-reset-filters'),
                  onPressed: () => _resetForensicFilters(resetLane: true),
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                  label: const Text('Reset Filters'),
                ),
              if (!hasRowsOutsideLane && canWidenWindow)
                OutlinedButton.icon(
                  key: const ValueKey('events-empty-open-all-time'),
                  onPressed: () => _setTimeWindow(_TimeWindow.all),
                  icon: const Icon(Icons.history_toggle_off_rounded, size: 18),
                  label: const Text('All Time'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool _matchesFilters(_ForensicRow row, DateTime now) {
    if (_typeFilter != _allValue && row.info.label != _typeFilter) {
      return false;
    }
    if (_siteFilter != _allValue && row.siteId != _siteFilter) {
      return false;
    }
    if (_guardFilter != _allValue && row.guardId != _guardFilter) {
      return false;
    }

    final threshold = _timeWindow.threshold(now);
    if (threshold != null && row.event.occurredAt.isBefore(threshold)) {
      return false;
    }

    return true;
  }

  bool _matchesLaneFilter(_ForensicRow row, _EventLaneFilter filter) {
    final event = row.event;
    return switch (filter) {
      _EventLaneFilter.all => true,
      _EventLaneFilter.intelligence => event is IntelligenceReceived,
      _EventLaneFilter.response =>
        event is DecisionCreated ||
            event is ExecutionCompleted ||
            event is ExecutionDenied ||
            event is ResponseArrived ||
            event is IncidentClosed ||
            event is PartnerDispatchStatusDeclared,
      _EventLaneFilter.field =>
        event is GuardCheckedIn ||
            event is PatrolCompleted ||
            event is VehicleVisitReviewRecorded,
      _EventLaneFilter.reporting => event is ReportGenerated,
    };
  }

  int _laneCountForFilter(List<_ForensicRow> rows, _EventLaneFilter filter) {
    return rows.where((row) => _matchesLaneFilter(row, filter)).length;
  }

  _EventLaneFilter _laneForEvent(DispatchEvent event) {
    if (event is IntelligenceReceived) {
      return _EventLaneFilter.intelligence;
    }
    if (event is ReportGenerated) {
      return _EventLaneFilter.reporting;
    }
    if (event is GuardCheckedIn ||
        event is PatrolCompleted ||
        event is VehicleVisitReviewRecorded) {
      return _EventLaneFilter.field;
    }
    return _EventLaneFilter.response;
  }

  void _selectEvent(DispatchEvent event, {bool openDrawer = false}) {
    setState(() {
      _selected = event;
      _lastActionFeedback = '';
    });
    if (openDrawer) {
      _scaffoldKey.currentState?.openEndDrawer();
    }
  }

  void _setLaneFilter(_EventLaneFilter filter) {
    if (_laneFilter == filter) {
      return;
    }
    setState(() {
      _laneFilter = filter;
      _lastActionFeedback = '';
    });
  }

  void _resetForensicFilters({
    bool resetLane = false,
    _TimeWindow timeWindow = _TimeWindow.last24h,
  }) {
    setState(() {
      _typeFilter = _allValue;
      _siteFilter = _allValue;
      _guardFilter = _allValue;
      _timeWindow = timeWindow;
      if (resetLane) {
        _laneFilter = _EventLaneFilter.all;
      }
      _lastActionFeedback = '';
    });
  }

  void _setTimeWindow(_TimeWindow window) {
    if (_timeWindow == window) {
      return;
    }
    setState(() {
      _timeWindow = window;
      _lastActionFeedback = '';
    });
  }

  void _setWorkspaceView(_EventWorkspaceView view) {
    if (_workspaceView == view) {
      return;
    }
    setState(() {
      _workspaceView = view;
      _lastActionFeedback = '';
    });
  }

  void _focusForensicRow(
    _ForensicRow row, {
    required _EventWorkspaceView view,
    String? feedback,
  }) {
    setState(() {
      _laneFilter = _laneForEvent(row.event);
      _selected = row.event;
      _workspaceView = view;
      _lastActionFeedback = feedback ?? '';
    });
  }

  void _focusLinkedEvent(List<_ForensicRow> relatedRows) {
    if (relatedRows.isEmpty) {
      return;
    }
    final focusRow = relatedRows.first;
    _focusForensicRow(
      focusRow,
      view: _EventWorkspaceView.chain,
      feedback: 'Focused ${focusRow.event.eventId} from the linked chain.',
    );
  }

  Future<void> _copyEventId(String eventId) async {
    await Clipboard.setData(ClipboardData(text: eventId));
    if (!mounted) {
      return;
    }
    setState(() {
      _lastActionFeedback = 'Event ID $eventId copied to clipboard.';
    });
  }

  List<_ForensicRow> _relatedRows(
    List<_ForensicRow> rows,
    _ForensicRow selected,
  ) {
    final selectedDispatchId = _dispatchIdForEvent(selected.event);
    final selectedSiteId = selected.siteId;
    final selectedGuardId = selected.guardId;
    return rows
        .where((row) {
          if (row.event.eventId == selected.event.eventId) {
            return false;
          }
          final sameDispatch =
              selectedDispatchId != null &&
              _dispatchIdForEvent(row.event) == selectedDispatchId;
          final sameSite =
              selectedSiteId != null && row.siteId == selectedSiteId;
          final sameGuard =
              selectedGuardId != null && row.guardId == selectedGuardId;
          return sameDispatch || sameSite || sameGuard;
        })
        .take(8)
        .toList(growable: false);
  }

  String _chainLabel(_ForensicRow row) {
    final dispatchId = _dispatchIdForEvent(row.event);
    if (dispatchId != null) {
      return dispatchId;
    }
    if (row.event is IntelligenceReceived) {
      return 'INTEL';
    }
    if (row.event is ReportGenerated) {
      return 'REPORT';
    }
    return 'FORENSIC';
  }

  String? _dispatchIdForEvent(DispatchEvent event) {
    if (event is DecisionCreated) {
      return event.dispatchId;
    }
    if (event is ExecutionCompleted) {
      return event.dispatchId;
    }
    if (event is ExecutionDenied) {
      return event.dispatchId;
    }
    if (event is ResponseArrived) {
      return event.dispatchId;
    }
    if (event is PartnerDispatchStatusDeclared) {
      return event.dispatchId;
    }
    if (event is IncidentClosed) {
      return event.dispatchId;
    }
    return null;
  }

  String _intelligenceEvidenceReadiness(IntelligenceReceived event) {
    final readinessChecks = [
      event.evidenceRecordHash?.trim().isNotEmpty ?? false,
      event.snapshotReferenceHash?.trim().isNotEmpty ?? false,
      event.clipReferenceHash?.trim().isNotEmpty ?? false,
    ];
    final readyCount = readinessChecks.where((value) => value).length;
    return '$readyCount of ${readinessChecks.length} anchors';
  }

  String _shortValue(String value, {int maxLength = 18}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'none';
    }
    if (trimmed.length <= maxLength) {
      return trimmed;
    }
    return '${trimmed.substring(0, maxLength)}...';
  }

  _ForensicRow _toForensicRow(DispatchEvent event) {
    final info = _describe(event);

    String? siteId;
    String? guardId;

    if (event is DecisionCreated) {
      siteId = event.siteId;
    } else if (event is ExecutionCompleted) {
      siteId = event.siteId;
    } else if (event is ExecutionDenied) {
      siteId = event.siteId;
    } else if (event is GuardCheckedIn) {
      siteId = event.siteId;
      guardId = event.guardId;
    } else if (event is PatrolCompleted) {
      siteId = event.siteId;
      guardId = event.guardId;
    } else if (event is ResponseArrived) {
      siteId = event.siteId;
      guardId = event.guardId;
    } else if (event is PartnerDispatchStatusDeclared) {
      siteId = event.siteId;
      guardId = event.actorLabel;
    } else if (event is VehicleVisitReviewRecorded) {
      siteId = event.siteId;
      guardId = event.actorLabel;
    } else if (event is IncidentClosed) {
      siteId = event.siteId;
    } else if (event is ReportGenerated) {
      siteId = event.siteId;
    } else if (event is IntelligenceReceived) {
      siteId = event.siteId;
    }

    return _ForensicRow(
      event: event,
      info: info,
      siteId: siteId,
      guardId: guardId,
    );
  }

  List<String> _distinctValues(Iterable<String?> values) {
    return values.whereType<String>().toSet().toList()
      ..sort((a, b) => a.compareTo(b));
  }

  List<(String, String)> _detailsFor(DispatchEvent event) {
    final base = <(String, String)>[
      ("eventId", event.eventId),
      ("sequence", event.sequence.toString()),
      ("version", event.version.toString()),
      ("occurredAtUtc", event.occurredAt.toIso8601String()),
    ];

    if (event is DecisionCreated) {
      return [
        ...base,
        ("eventType", "DecisionCreated"),
        ("dispatchId", event.dispatchId),
        ("clientId", event.clientId),
        ("regionId", event.regionId),
        ("siteId", event.siteId),
      ];
    }
    if (event is ExecutionCompleted) {
      return [
        ...base,
        ("eventType", "ExecutionCompleted"),
        ("dispatchId", event.dispatchId),
        ("clientId", event.clientId),
        ("regionId", event.regionId),
        ("siteId", event.siteId),
        ("success", event.success.toString()),
      ];
    }
    if (event is ExecutionDenied) {
      return [
        ...base,
        ("eventType", "ExecutionDenied"),
        ("dispatchId", event.dispatchId),
        ("clientId", event.clientId),
        ("regionId", event.regionId),
        ("siteId", event.siteId),
        ("operatorId", event.operatorId),
        ("reason", event.reason),
      ];
    }
    if (event is GuardCheckedIn) {
      return [
        ...base,
        ("eventType", "GuardCheckedIn"),
        ("guardId", event.guardId),
        ("clientId", event.clientId),
        ("regionId", event.regionId),
        ("siteId", event.siteId),
      ];
    }
    if (event is PatrolCompleted) {
      return [
        ...base,
        ("eventType", "PatrolCompleted"),
        ("guardId", event.guardId),
        ("routeId", event.routeId),
        ("clientId", event.clientId),
        ("regionId", event.regionId),
        ("siteId", event.siteId),
        ("durationSeconds", event.durationSeconds.toString()),
      ];
    }
    if (event is ResponseArrived) {
      return [
        ...base,
        ("eventType", "ResponseArrived"),
        ("dispatchId", event.dispatchId),
        ("guardId", event.guardId),
        ("clientId", event.clientId),
        ("regionId", event.regionId),
        ("siteId", event.siteId),
      ];
    }
    if (event is PartnerDispatchStatusDeclared) {
      return [
        ...base,
        ("eventType", "PartnerDispatchStatusDeclared"),
        ("dispatchId", event.dispatchId),
        ("partnerLabel", event.partnerLabel),
        ("actorLabel", event.actorLabel),
        ("status", event.status.name),
        ("clientId", event.clientId),
        ("regionId", event.regionId),
        ("siteId", event.siteId),
        ("sourceChannel", event.sourceChannel),
        ("sourceMessageKey", event.sourceMessageKey),
      ];
    }
    if (event is IncidentClosed) {
      return [
        ...base,
        ("eventType", "IncidentClosed"),
        ("dispatchId", event.dispatchId),
        ("resolutionType", event.resolutionType),
        ("clientId", event.clientId),
        ("regionId", event.regionId),
        ("siteId", event.siteId),
      ];
    }
    if (event is VehicleVisitReviewRecorded) {
      return [
        ...base,
        ("eventType", "VehicleVisitReviewRecorded"),
        ("vehicleVisitKey", event.vehicleVisitKey),
        ("primaryEventId", event.primaryEventId),
        ("clientId", event.clientId),
        ("regionId", event.regionId),
        ("siteId", event.siteId),
        ("vehicleLabel", event.vehicleLabel),
        ("actorLabel", event.actorLabel),
        ("reviewed", event.reviewed.toString()),
        ("statusOverride", event.statusOverride),
        ("effectiveStatusLabel", event.effectiveStatusLabel),
        ("reasonLabel", event.reasonLabel),
        ("workflowSummary", event.workflowSummary),
        ("sourceSurface", event.sourceSurface),
      ];
    }
    if (event is ReportGenerated) {
      final includedSections = _includedReportSectionLabels(
        event.sectionConfiguration,
      );
      final omittedSections = _omittedReportSectionLabels(
        event.sectionConfiguration,
      );
      return [
        ...base,
        ("eventType", "ReportGenerated"),
        ("clientId", event.clientId),
        ("siteId", event.siteId),
        ("month", event.month),
        ("contentHash", event.contentHash),
        ("pdfHash", event.pdfHash),
        ("eventRangeStart", event.eventRangeStart.toString()),
        ("eventRangeEnd", event.eventRangeEnd.toString()),
        ("eventCount", event.eventCount.toString()),
        ("reportSchemaVersion", event.reportSchemaVersion.toString()),
        ("projectionVersion", event.projectionVersion.toString()),
        ("investigationContext", _reportInvestigationContextLabel(event)),
        (
          "investigationContextKey",
          event.investigationContextKey.trim().isEmpty
              ? "routine_review"
              : event.investigationContextKey.trim(),
        ),
        ("brandingMode", _reportBrandingModeLabel(event)),
        ("brandingSource", _reportBrandingSourceLabel(event)),
        ("brandingSummary", _reportBrandingDetail(event)),
        (
          "sectionConfigurationTracked",
          _hasTrackedReportSectionConfiguration(event).toString(),
        ),
        (
          "includedSections",
          _hasTrackedReportSectionConfiguration(event)
              ? (includedSections.isEmpty
                    ? "None"
                    : includedSections.join(", "))
              : "Legacy receipt",
        ),
        (
          "omittedSections",
          _hasTrackedReportSectionConfiguration(event)
              ? (omittedSections.isEmpty ? "None" : omittedSections.join(", "))
              : "Not captured",
        ),
        ("includeTimeline", event.includeTimeline.toString()),
        ("includeDispatchSummary", event.includeDispatchSummary.toString()),
        (
          "includeCheckpointCompliance",
          event.includeCheckpointCompliance.toString(),
        ),
        ("includeAiDecisionLog", event.includeAiDecisionLog.toString()),
        ("includeGuardMetrics", event.includeGuardMetrics.toString()),
      ];
    }
    if (event is IntelligenceReceived) {
      return [
        ...base,
        ("eventType", "IntelligenceReceived"),
        ("intelligenceId", event.intelligenceId),
        ("provider", event.provider),
        ("externalId", event.externalId),
        ("clientId", event.clientId),
        ("regionId", event.regionId),
        ("siteId", event.siteId),
        if ((event.cameraId ?? '').trim().isNotEmpty)
          ("cameraId", event.cameraId!.trim()),
        if ((event.zone ?? '').trim().isNotEmpty) ("zone", event.zone!.trim()),
        if ((event.objectLabel ?? '').trim().isNotEmpty)
          ("objectLabel", event.objectLabel!.trim()),
        if (event.objectConfidence != null)
          ("objectConfidence", event.objectConfidence!.toStringAsFixed(2)),
        ("riskScore", event.riskScore.toString()),
        ("headline", event.headline),
        ("summary", event.summary),
        if ((event.snapshotUrl ?? '').trim().isNotEmpty)
          ("snapshotUrl", event.snapshotUrl!.trim()),
        if ((event.clipUrl ?? '').trim().isNotEmpty)
          ("clipUrl", event.clipUrl!.trim()),
        if ((event.snapshotReferenceHash ?? '').trim().isNotEmpty)
          ("snapshotReferenceHash", event.snapshotReferenceHash!.trim()),
        if ((event.clipReferenceHash ?? '').trim().isNotEmpty)
          ("clipReferenceHash", event.clipReferenceHash!.trim()),
        if ((event.evidenceRecordHash ?? '').trim().isNotEmpty)
          ("evidenceRecordHash", event.evidenceRecordHash!.trim()),
        ("canonicalHash", event.canonicalHash),
      ];
    }

    return [...base, ("eventType", event.toAuditTypeKey())];
  }

  _EventInfo _describe(DispatchEvent event) {
    if (event is DecisionCreated) {
      return _EventInfo(
        label: 'DECISION',
        color: const Color(0xFF6BC6FF),
        summary:
            '${event.clientId}/${event.siteId} dispatch ${event.dispatchId} created',
      );
    }
    if (event is ExecutionCompleted) {
      return _EventInfo(
        label: event.success ? 'EXECUTION' : 'FAILED EXECUTION',
        color: event.success
            ? const Color(0xFF4ED4A3)
            : const Color(0xFFFF6676),
        summary:
            '${event.clientId}/${event.siteId} dispatch ${event.dispatchId}',
      );
    }
    if (event is ExecutionDenied) {
      return _EventInfo(
        label: 'DENIED',
        color: const Color(0xFFFFB44D),
        summary:
            '${event.clientId}/${event.siteId} dispatch ${event.dispatchId} denied by ${event.operatorId}',
      );
    }
    if (event is GuardCheckedIn) {
      return _EventInfo(
        label: 'GUARD CHECK-IN',
        color: const Color(0xFF2FD6FF),
        summary:
            '${event.guardId} checked in at ${event.clientId}/${event.siteId}',
      );
    }
    if (event is PatrolCompleted) {
      return _EventInfo(
        label: 'PATROL COMPLETED',
        color: const Color(0xFF65E8CF),
        summary:
            '${event.guardId} completed ${event.routeId} in ${event.durationSeconds}s at ${event.siteId}',
      );
    }
    if (event is ResponseArrived) {
      return _EventInfo(
        label: 'RESPONSE ARRIVED',
        color: const Color(0xFF74D1FF),
        summary:
            '${event.guardId} arrived for ${event.dispatchId} at ${event.siteId}',
      );
    }
    if (event is PartnerDispatchStatusDeclared) {
      return _EventInfo(
        label: 'PARTNER DECLARED',
        color: const Color(0xFF22C55E),
        summary:
            '${event.partnerLabel} declared ${event.status.name} for ${event.dispatchId} at ${event.siteId}',
      );
    }
    if (event is VehicleVisitReviewRecorded) {
      final summary = !event.reviewed && event.statusOverride.trim().isEmpty
          ? '${event.vehicleLabel} review cleared at ${event.siteId}'
          : event.statusOverride.trim().isNotEmpty
          ? '${event.vehicleLabel} marked ${event.effectiveStatusLabel} at ${event.siteId}'
          : '${event.vehicleLabel} marked reviewed at ${event.siteId}';
      return _EventInfo(
        label: 'VISIT REVIEW',
        color: const Color(0xFF38BDF8),
        summary: summary,
      );
    }
    if (event is IncidentClosed) {
      return _EventInfo(
        label: 'INCIDENT CLOSED',
        color: const Color(0xFF9FE06A),
        summary:
            '${event.dispatchId} closed (${event.resolutionType}) at ${event.siteId}',
      );
    }
    if (event is ReportGenerated) {
      final hasTrackedConfig = _hasTrackedReportSectionConfiguration(event);
      final omittedSections = _omittedReportSectionLabels(
        event.sectionConfiguration,
      );
      final brandingHeadline = _reportBrandingHeadline(event);
      final configurationSummary = !hasTrackedConfig
          ? 'legacy receipt configuration'
          : omittedSections.isEmpty
          ? 'all sections included'
          : '${omittedSections.length} sections omitted';
      final investigationHeadline = _reportInvestigationHeadline(event);
      return _EventInfo(
        label: 'REPORT GENERATED',
        color: const Color(0xFFAD8DFF),
        summary:
            '${event.clientId}/${event.siteId} ${event.month} • $configurationSummary${brandingHeadline == null ? '' : ' • $brandingHeadline'}${investigationHeadline == null ? '' : ' • $investigationHeadline'} • hash ${event.contentHash.substring(0, 12)}... range ${event.eventRangeStart}-${event.eventRangeEnd}',
      );
    }
    if (event is IntelligenceReceived) {
      return _EventInfo(
        label: 'INTEL RECEIVED',
        color: const Color(0xFFFFA34D),
        summary:
            '${event.provider}/${event.externalId} risk ${event.riskScore} at ${event.clientId}/${event.siteId}',
      );
    }

    return _EventInfo(
      label: 'EVENT',
      color: const Color(0xFF93A8C9),
      summary: event.eventId,
    );
  }

  Widget _pill(String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _eventsPanelColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _eventsBorderColor),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: color ?? _eventsBodyColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  int _activeFilterCount() {
    var count = 0;
    if (_typeFilter != _allValue) count += 1;
    if (_siteFilter != _allValue) count += 1;
    if (_guardFilter != _allValue) count += 1;
    if (_timeWindow != _TimeWindow.last24h) count += 1;
    return count;
  }

  Widget _emptyDetailPane({required List<_ForensicRow> filteredRows}) {
    final hasRowsOutsideLane = filteredRows.isNotEmpty;
    final intelligenceCount = _laneCountForFilter(
      filteredRows,
      _EventLaneFilter.intelligence,
    );
    final canWidenWindow = _timeWindow != _TimeWindow.all;
    final canResetScope =
        _activeFilterCount() > 0 || _laneFilter != _EventLaneFilter.all;
    return Container(
      key: const ValueKey('events-empty-detail-recovery'),
      padding: const EdgeInsets.all(10),
      decoration: onyxForensicSurfaceCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Forensic Focus Recovery',
            style: GoogleFonts.inter(
              color: _eventsTitleColor,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasRowsOutsideLane
                ? 'The current lane is empty, but scoped forensic rows still exist outside it. Recover the case board by reopening the full stream or pivoting straight into an intelligence-first pass.'
                : 'The current review scope is empty. Widen the window or reset the full forensic scope so the board can pull a live case file back into focus.',
            style: GoogleFonts.inter(
              color: const Color(0xFF8FA4C5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          _forensicRecoveryDeck(
            title: hasRowsOutsideLane
                ? 'Scoped Rows Still Available'
                : 'Review Horizon Empty',
            detail: hasRowsOutsideLane
                ? '${filteredRows.length} scoped row${filteredRows.length == 1 ? '' : 's'} remain available outside the active lane. Reopen the full stream or switch to intelligence-first review to anchor the workspace again.'
                : 'No visible rows remain inside the current window and filter stack. Use the actions below to widen the forensic horizon and restore a selected case file.',
            accent: hasRowsOutsideLane
                ? const Color(0xFF63BDFF)
                : const Color(0xFFF6C067),
            actions: [
              if (hasRowsOutsideLane)
                _forensicRecoveryAction(
                  key: const ValueKey('events-empty-detail-open-all'),
                  label: 'Open All Events',
                  accent: _EventLaneFilter.all.accent,
                  onTap: () => _setLaneFilter(_EventLaneFilter.all),
                ),
              if (intelligenceCount > 0 &&
                  _laneFilter != _EventLaneFilter.intelligence)
                _forensicRecoveryAction(
                  key: const ValueKey('events-empty-detail-open-intelligence'),
                  label: 'Intelligence Lane',
                  accent: _EventLaneFilter.intelligence.accent,
                  onTap: () => _setLaneFilter(_EventLaneFilter.intelligence),
                ),
              if (canWidenWindow)
                _forensicRecoveryAction(
                  key: const ValueKey('events-empty-detail-open-all-time'),
                  label: 'All Time',
                  accent: const Color(0xFFF6C067),
                  onTap: () => _setTimeWindow(_TimeWindow.all),
                ),
              if (canResetScope)
                _forensicRecoveryAction(
                  key: const ValueKey('events-empty-detail-reset-scope'),
                  label: 'Reset Scope',
                  accent: const Color(0xFF59D79B),
                  onTap: () => _resetForensicFilters(resetLane: true),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Selected case boards, evidence posture, and linked-chain context snap back automatically as soon as the rail has a viable row again.',
            style: GoogleFonts.inter(
              color: const Color(0xFF7289AA),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _forensicRecoveryDeck({
    Key? key,
    required String title,
    required String detail,
    required Color accent,
    required List<Widget> actions,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.14), _eventsPanelColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: _eventsBodyColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 5, runSpacing: 5, children: actions),
          ],
        ],
      ),
    );
  }

  Widget _forensicRecoveryAction({
    Key? key,
    required String label,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return TextButton(
      key: key,
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: accent,
        backgroundColor: accent.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _detailHero(_ForensicRow row) {
    final reportEvent = row.event is ReportGenerated
        ? row.event as ReportGenerated
        : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _eventsPanelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _eventsBorderColor),
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
          Container(
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              color: row.info.color.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: row.info.color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  row.info.label,
                  style: GoogleFonts.inter(
                    color: row.info.color,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _pill("SEQ ${row.event.sequence}"),
              _pill("v${row.event.version}"),
              if (row.siteId != null) _pill(row.siteId!),
              if (row.guardId != null) _pill(row.guardId!),
              if (reportEvent != null)
                _pill(
                  _hasTrackedReportSectionConfiguration(reportEvent)
                      ? 'Tracked Config'
                      : 'Legacy Config',
                  color: _reportSectionConfigurationAccent(reportEvent),
                ),
              if (reportEvent != null &&
                  reportEvent.brandingConfiguration.isConfigured)
                _pill(
                  reportEvent.brandingUsesOverride
                      ? 'Custom Branding'
                      : 'Default Branding',
                  color: _reportBrandingAccent(reportEvent),
                ),
              if (reportEvent != null &&
                  _hasTrackedReportSectionConfiguration(reportEvent))
                _pill(
                  _reportSectionConfigurationHeadline(reportEvent),
                  color: _reportSectionConfigurationAccent(reportEvent),
                ),
              if (reportEvent != null &&
                  _reportInvestigationContext(reportEvent) != null)
                _pill(
                  _reportInvestigationContextLabel(reportEvent),
                  color: const Color(0xFF5DC8FF),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            row.info.summary,
            style: GoogleFonts.inter(
              color: _eventsBodyColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (reportEvent != null) ...[
            const SizedBox(height: 6),
            Text(
              _reportBrandingAndSectionConfigurationDetail(reportEvent),
              style: GoogleFonts.inter(
                color: _eventsMutedColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
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
    final omitted = _omittedReportSectionLabels(event.sectionConfiguration);
    if (omitted.isEmpty) {
      return 'All Sections Included';
    }
    return '${omitted.length} Sections Omitted';
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

  String _reportBrandingModeLabel(ReportGenerated event) {
    if (!event.brandingConfiguration.isConfigured) {
      return 'Standard ONYX';
    }
    return event.brandingUsesOverride ? 'Custom Override' : 'Default Partner';
  }

  String _reportBrandingSourceLabel(ReportGenerated event) {
    final sourceLabel = event.brandingConfiguration.sourceLabel.trim();
    if (sourceLabel.isEmpty) {
      return event.brandingConfiguration.isConfigured
          ? 'Configured partner branding'
          : 'ONYX';
    }
    return sourceLabel;
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

  String _reportBrandingAndSectionConfigurationDetail(ReportGenerated event) {
    return '${_reportBrandingDetail(event)} ${_reportSectionConfigurationDetail(event)}';
  }

  Color _reportBrandingAccent(ReportGenerated event) {
    if (!event.brandingConfiguration.isConfigured) {
      return const Color(0xFF8EA5C6);
    }
    return event.brandingUsesOverride
        ? const Color(0xFFF6C067)
        : const Color(0xFF59D79B);
  }

  Color _reportSectionConfigurationAccent(ReportGenerated event) {
    if (!_hasTrackedReportSectionConfiguration(event)) {
      return const Color(0xFF8EA5C6);
    }
    return _omittedReportSectionLabels(event.sectionConfiguration).isEmpty
        ? const Color(0xFF59D79B)
        : const Color(0xFFF6C067);
  }
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

String _reportInvestigationContextLabel(ReportGenerated event) {
  return switch (_reportInvestigationContext(event)) {
    ReportEntryContext.governanceBrandingDrift => 'Governance Handoff',
    null => 'Routine Review',
  };
}

class _ForensicRow {
  final DispatchEvent event;
  final _EventInfo info;
  final String? siteId;
  final String? guardId;

  const _ForensicRow({
    required this.event,
    required this.info,
    required this.siteId,
    required this.guardId,
  });
}

class _EventInfo {
  final String label;
  final Color color;
  final String summary;

  const _EventInfo({
    required this.label,
    required this.color,
    required this.summary,
  });
}

class IntegrityCertificatePreviewCard extends StatelessWidget {
  final IntelligenceReceived event;

  const IntegrityCertificatePreviewCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final certificate = EvidenceProvenanceCertificate.fromIntelligence(event);
    final hasEvidence =
        certificate.evidenceRecordHash.trim().isNotEmpty ||
        certificate.snapshot.isPresent ||
        certificate.clip.isPresent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _eventsPanelColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _eventsBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Integrity Certificate',
                  style: GoogleFonts.inter(
                    color: _eventsTitleColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasEvidence
                      ? const Color(0x162FD6A3)
                      : const Color(0x16FF8C69),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: hasEvidence
                        ? const Color(0xFF2FD6A3)
                        : const Color(0xFFFF8C69),
                  ),
                ),
                child: Text(
                  hasEvidence ? 'READY' : 'EMPTY',
                  style: GoogleFonts.inter(
                    color: hasEvidence
                        ? const Color(0xFF9AF3D6)
                        : const Color(0xFFFFB6A1),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Preview the tamper-evident evidence certificate for this intelligence event, including the canonical hash and locator hashes.',
            style: GoogleFonts.inter(
              color: _eventsBodyColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _previewPill(
                'record ${_shortHash(certificate.evidenceRecordHash)}',
              ),
              _previewPill(
                'snapshot ${_shortHash(certificate.snapshot.locatorHash)}',
              ),
              _previewPill('clip ${_shortHash(certificate.clip.locatorHash)}'),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () => _showIntegrityCertificatePreview(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: _eventsTitleColor,
                side: const BorderSide(color: Color(0xFF7EA7D3)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              child: Text(
                'View Certificate',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showIntegrityCertificatePreview(BuildContext context) {
    final certificate = EvidenceProvenanceCertificate.fromIntelligence(event);
    final payload = <String, Object?>{
      'certificate_type': 'onyx_evidence_integrity_certificate_preview',
      'intelligence': certificate.toJson(),
      'ledger': {
        'sealed': false,
        'note':
            'Preview only. Ledger-backed export is available from the evidence export flow.',
      },
    };
    final prettyJson = const JsonEncoder.withIndent('  ').convert(payload);
    final markdown = _buildIntegrityCertificateMarkdown(certificate);

    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _eventsPanelColor,
        child: DefaultTabController(
          length: 2,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ONYX Evidence Integrity Certificate',
                    style: GoogleFonts.inter(
                      color: _eventsTitleColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Certificate preview for ${event.intelligenceId}. This view is derived from the staged evidence hashes currently stored on the event.',
                    style: GoogleFonts.inter(
                      color: _eventsBodyColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const TabBar(
                    tabs: [
                      Tab(text: 'JSON'),
                      Tab(text: 'Markdown'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _certificatePane(prettyJson),
                        _certificatePane(markdown),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: prettyJson),
                          );
                        },
                        icon: const Icon(Icons.content_copy_rounded, size: 16),
                        label: Text(
                          'Copy JSON',
                          style: GoogleFonts.inter(
                            color: _eventsTitleColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: markdown),
                          );
                        },
                        icon: const Icon(Icons.content_copy_rounded, size: 16),
                        label: Text(
                          'Copy Markdown',
                          style: GoogleFonts.inter(
                            color: _eventsTitleColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Close',
                          style: GoogleFonts.inter(
                            color: _eventsTitleColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _certificatePane(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _eventsPanelMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _eventsBorderColor),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          content,
          style: GoogleFonts.robotoMono(
            color: _eventsTitleColor,
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  String _buildIntegrityCertificateMarkdown(
    EvidenceProvenanceCertificate certificate,
  ) {
    return [
      '# ONYX Evidence Integrity Certificate',
      '',
      '- Intelligence ID: `${certificate.intelligenceId}`',
      '- Provider: `${certificate.provider}`',
      '- Source type: `${certificate.sourceType}`',
      '- External ID: `${certificate.externalId}`',
      '- Client / Site: `${certificate.clientId}` / `${certificate.siteId}`',
      '- Occurred at UTC: `${certificate.occurredAtUtc.toIso8601String()}`',
      '- Canonical hash: `${certificate.canonicalHash}`',
      '- Evidence record hash: `${certificate.evidenceRecordHash}`',
      '- Snapshot locator hash: `${certificate.snapshot.locatorHash}`',
      '- Clip locator hash: `${certificate.clip.locatorHash}`',
      '- Ledger sealed: `false`',
      '- Ledger note: `Preview only. Ledger-backed export is available from the evidence export flow.`',
    ].join('\n');
  }

  String _shortHash(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'none';
    }
    if (trimmed.length <= 12) {
      return trimmed;
    }
    return '${trimmed.substring(0, 12)}...';
  }

  Widget _previewPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _eventsPanelTint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBED2E8)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: _eventsTitleColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum _EventLaneFilter {
  all('All', 'all', Color(0xFF93A8C9)),
  intelligence('Intelligence', 'intelligence', Color(0xFFFFA34D)),
  response('Response', 'response', Color(0xFF63BDFF)),
  field('Field', 'field', Color(0xFF59D79B)),
  reporting('Reporting', 'reporting', Color(0xFFAD8DFF));

  final String label;
  final String key;
  final Color accent;

  const _EventLaneFilter(this.label, this.key, this.accent);
}

enum _EventWorkspaceView {
  casefile('Case File', 'casefile', Color(0xFF63BDFF)),
  evidence('Evidence', 'evidence', Color(0xFFF6C067)),
  chain('Chain', 'chain', Color(0xFF59D79B));

  final String label;
  final String key;
  final Color accent;

  const _EventWorkspaceView(this.label, this.key, this.accent);
}

enum _TimeWindow {
  last1h('Last 1h', Duration(hours: 1)),
  last6h('Last 6h', Duration(hours: 6)),
  last24h('Last 24h', Duration(hours: 24)),
  last7d('Last 7d', Duration(days: 7)),
  all('All time', null);

  final String label;
  final Duration? range;

  const _TimeWindow(this.label, this.range);

  DateTime? threshold(DateTime nowUtc) {
    if (range == null) return null;
    return nowUtc.subtract(range!);
  }
}
