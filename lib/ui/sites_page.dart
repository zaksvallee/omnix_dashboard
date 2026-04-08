import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/guard_checked_in.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/patrol_completed.dart';
import '../domain/events/response_arrived.dart';
import '../domain/projection/operations_health_projection.dart';
import 'components/onyx_status_banner.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';

// Fallback response scores used when averageResponseMinutes has not yet been
// sampled (e.g. a new site or a very recent shift start).
// Derived from the formula `100 - ((minutes - 4) * 8)`:
//   _kResponseScoreNoDataActive ≈ 8-minute equivalent (units live, no timing yet)
//   _kResponseScoreNoDataQuiet  ≈ 4-minute equivalent (baseline, nothing active)
const _kResponseScoreNoDataActive = 42;
const _kResponseScoreNoDataQuiet = 86;

class SitesPage extends StatefulWidget {
  final List<DispatchEvent> events;

  const SitesPage({super.key, required this.events});

  @override
  State<SitesPage> createState() => _SitesPageState();
}

enum _SiteLaneFilter { all, watch, active, strong }

enum _SiteWorkspaceView { command, outcomes, trace }

class _SitesPageState extends State<SitesPage> {
  static const int _maxRosterRows = 12;
  static const double _spaceXs = 4;

  String? _selectedSiteKey;
  _SiteLaneFilter _siteLaneFilter = _SiteLaneFilter.all;
  _SiteWorkspaceView _workspaceView = _SiteWorkspaceView.command;
  bool get _desktopEmbeddedScroll => allowEmbeddedPanelScroll(context);

  @override
  Widget build(BuildContext context) {
    final projection = OperationsHealthProjection.build(widget.events);
    final allSites = _buildSiteDrillSnapshots(widget.events, projection);

    if (allSites.isEmpty) {
      return const OnyxPageScaffold(
        child: OnyxEmptyState(
          label: 'No sites available in the current projection.',
        ),
      );
    }

    final sites = _filteredSites(allSites);
    final selectedPool = sites.isEmpty ? allSites : sites;

    _selectedSiteKey ??= selectedPool.first.siteKey;
    final selected = selectedPool.firstWhere(
      (site) => site.siteKey == _selectedSiteKey,
      orElse: () => selectedPool.first,
    );

    final activeDispatches = allSites.fold<int>(
      0,
      (total, site) => total + site.activeDispatches,
    );
    final averageHealth =
        allSites.fold<double>(0, (total, site) => total + site.healthScore) /
        allSites.length;
    final boundedDesktopSurface = _desktopEmbeddedScroll;
    const contentPadding = EdgeInsets.fromLTRB(0.65, 0.65, 0.65, 1.45);
    final ultrawideSurface = isUltrawideLayout(context);
    final widescreenSurface = isWidescreenLayout(context);
    final surfaceMaxWidth = ultrawideSurface
        ? MediaQuery.sizeOf(context).width
        : widescreenSurface
        ? MediaQuery.sizeOf(context).width * 0.94
        : 1540.0;

    Widget buildHeaderStack({
      required bool compactForViewport,
      required bool mergeWorkspaceBannerIntoHero,
    }) {
      final criticalCount = _siteCountForFilter(
        allSites,
        _SiteLaneFilter.active,
      );
      final atRiskCount = _siteCountForFilter(
        allSites,
        _SiteLaneFilter.watch,
      );
      final anyAlert = criticalCount > 0 || atRiskCount > 0;
      final sitePostureSummary = allSites.isEmpty
          ? 'Posture nominal'
          : anyAlert
          ? '$atRiskCount sites need posture review'
          : 'All sites monitored';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnyxPageHeader(
            icon: Icons.location_on_rounded,
            iconColor: Theme.of(context).colorScheme.primary,
            title: 'Sites & Deployment',
            subtitle: 'Site coverage and posture.',
          ),
          const SizedBox(height: 10),
          OnyxStatusBanner(
            message: sitePostureSummary,
            severity: anyAlert ? OnyxSeverity.warning : OnyxSeverity.info,
          ),
          const SizedBox(height: 10),
          _heroHeader(
            context,
            sites: allSites,
            selected: selected,
            activeDispatches: activeDispatches,
            averageHealth: averageHealth,
            workspaceBanner: mergeWorkspaceBannerIntoHero
                ? _workspaceStatusBanner(
                    context,
                    allSites: allSites,
                    visibleSites: sites,
                    selected: selected,
                    shellless: true,
                    summaryOnly: true,
                  )
                : null,
          ),
          if (!compactForViewport) ...[
            const SizedBox(height: 1.0),
            _overviewGrid(
              sites: allSites,
              activeDispatches: activeDispatches,
              averageHealth: averageHealth,
            ),
          ],
        ],
      );
    }

    Widget buildWorkspaceSection({required bool lockToViewport}) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final stackVertically = constraints.maxWidth < 1320;
          final boundedHeight =
              constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
          final allowEmbeddedWorkspace = lockToViewport && boundedHeight;
          final canStretchWorkspace = allowEmbeddedWorkspace;
          final mergeWorkspaceBannerIntoHero =
              lockToViewport && !stackVertically;

          Widget buildVerticalWorkspace({required bool embeddedScroll}) {
            if (!embeddedScroll) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _siteRoster(allSites, sites, selected, embeddedScroll: false),
                  const SizedBox(height: _spaceXs),
                  _siteWorkspace(
                    allSites,
                    sites,
                    selected,
                    embeddedScroll: false,
                  ),
                ],
              );
            }
            final workspaceColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 212,
                  child: _siteRoster(
                    allSites,
                    sites,
                    selected,
                    embeddedScroll: true,
                  ),
                ),
                const SizedBox(height: 3.0),
                Expanded(
                  child: _siteWorkspace(
                    allSites,
                    sites,
                    selected,
                    embeddedScroll: true,
                  ),
                ),
              ],
            );
            return workspaceColumn;
          }

          Widget buildHorizontalWorkspace({required bool embeddedScroll}) {
            final ultrawideWorkspace = isUltrawideLayout(
              context,
              viewportWidth: constraints.maxWidth,
            );
            final widescreenWorkspace = isWidescreenLayout(
              context,
              viewportWidth: constraints.maxWidth,
            );
            final rosterWidth = ultrawideWorkspace
                ? 184.0
                : widescreenWorkspace
                ? 172.0
                : 160.0;
            final workspaceRow = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: rosterWidth,
                  child: _siteRoster(
                    allSites,
                    sites,
                    selected,
                    embeddedScroll: embeddedScroll,
                  ),
                ),
                const SizedBox(width: _spaceXs),
                Expanded(
                  child: _siteWorkspace(
                    allSites,
                    sites,
                    selected,
                    embeddedScroll: embeddedScroll,
                  ),
                ),
              ],
            );
            return workspaceRow;
          }

          final workspaceShell = stackVertically
              ? buildVerticalWorkspace(embeddedScroll: allowEmbeddedWorkspace)
              : buildHorizontalWorkspace(
                  embeddedScroll: allowEmbeddedWorkspace,
                );

          final sectionBody = stackVertically
              ? workspaceShell
              : canStretchWorkspace
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!mergeWorkspaceBannerIntoHero) ...[
                      _workspaceStatusBanner(
                        context,
                        allSites: allSites,
                        visibleSites: sites,
                        selected: selected,
                      ),
                      const SizedBox(height: 2.5),
                    ],
                    Expanded(child: workspaceShell),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!mergeWorkspaceBannerIntoHero) ...[
                      _workspaceStatusBanner(
                        context,
                        allSites: allSites,
                        visibleSites: sites,
                        selected: selected,
                      ),
                      const SizedBox(height: 2.5),
                    ],
                    workspaceShell,
                  ],
                );

          if (!stackVertically) {
            return sectionBody;
          }
          return OnyxSectionCard(
            title: 'Site Operations Workspace',
            subtitle:
                'Hold a selected site in focus and inspect command, outcome, or trace context.',
            padding: const EdgeInsets.all(1.5),
            flexibleChild: lockToViewport,
            child: sectionBody,
          );
        },
      );
    }

    return OnyxPageScaffold(
      child: OnyxViewportWorkspaceLayout(
        padding: contentPadding,
        maxWidth: surfaceMaxWidth,
        spacing: 3.5,
        lockToViewport: boundedDesktopSurface,
        header: LayoutBuilder(
          builder: (context, headerConstraints) {
            final compactHeaderForViewport = headerConstraints.maxWidth >= 1280;
            final mergeWorkspaceBannerIntoHero =
                boundedDesktopSurface && headerConstraints.maxWidth >= 1320;
            return buildHeaderStack(
              compactForViewport: compactHeaderForViewport,
              mergeWorkspaceBannerIntoHero: mergeWorkspaceBannerIntoHero,
            );
          },
        ),
        body: buildWorkspaceSection(lockToViewport: boundedDesktopSurface),
      ),
    );
  }

  Widget _heroHeader(
    BuildContext context, {
    required List<_SiteDrillSnapshot> sites,
    required _SiteDrillSnapshot selected,
    required int activeDispatches,
    required double averageHealth,
    Widget? workspaceBanner,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(1.1),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF7FAFF), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(4.75),
        border: Border.all(color: const Color(0xFFD6E1EC)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final showHeroChipRow = compact;
          final heroSummaryLine =
              '${sites.length} sites • ${_laneLabel(_siteLaneFilter)} lane • '
              '$activeDispatches dispatches • health ${averageHealth.toStringAsFixed(1)}';
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF06B6D4), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.business_outlined,
                      color: Colors.white,
                      size: 9.4,
                    ),
                  ),
                  const SizedBox(width: 2.25),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sites & Deployment',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF172638),
                            fontSize: compact ? 10.9 : 12.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 0.4),
                        Text(
                          'Site management, watch posture, and operational readiness.',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF556B80),
                            fontSize: 5.9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 0.18),
                        Text(
                          heroSummaryLine,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF7A8FA4),
                            fontSize: 5.6,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (showHeroChipRow) ...[
                const SizedBox(height: 0.5),
                Wrap(
                  spacing: 0.55,
                  runSpacing: 0.55,
                  children: [
                    _heroChip('Sites', '${sites.length}'),
                    _heroChip('Lane', _laneLabel(_siteLaneFilter)),
                    _heroChip('Dispatches', '$activeDispatches'),
                    _heroChip('Health', averageHealth.toStringAsFixed(1)),
                  ],
                ),
              ],
            ],
          );
          final actions = Wrap(
            spacing: 2,
            runSpacing: 2,
            alignment: WrapAlignment.end,
            children: [
              _heroActionButton(
                key: const ValueKey('sites-view-tactical-button'),
                icon: Icons.open_in_new,
                label: 'View Tactical',
                accent: const Color(0xFF93C5FD),
                onPressed: () => _showTacticalLinkDialog(context),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 0.85),
                actions,
                if (workspaceBanner != null) ...[
                  const SizedBox(height: 1.0),
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
                  const SizedBox(width: 0.75),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 98),
                    child: actions,
                  ),
                ],
              ),
              if (workspaceBanner != null) ...[
                const SizedBox(height: 1.0),
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
      padding: const EdgeInsets.symmetric(horizontal: 3.25, vertical: 1.2),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD6E1EC)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.inter(
                color: const Color(0xFF7A8FA4),
                fontSize: 6.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: const Color(0xFF172638),
                fontSize: 6.8,
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
      icon: Icon(icon, size: 9.5),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: accent.withValues(alpha: 0.12),
        foregroundColor: accent,
        side: BorderSide(color: accent.withValues(alpha: 0.28)),
        padding: const EdgeInsets.symmetric(horizontal: 3.25, vertical: 2.2),
        textStyle: GoogleFonts.inter(
          fontSize: 7.0,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5.25),
        ),
      ),
    );
  }

  Widget _statusPill({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9.0, color: accent),
          const SizedBox(width: 1.5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 7.3,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewGrid({
    required List<_SiteDrillSnapshot> sites,
    required int activeDispatches,
    required double averageHealth,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 3
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        return GridView.count(
          key: const ValueKey('sites-overview-grid'),
          crossAxisCount: columns,
          mainAxisSpacing: 1.75,
          crossAxisSpacing: 1.75,
          childAspectRatio: columns == 2 ? 5.0 : 3.7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _overviewCard(
              title: 'Visible Sites',
              value: '${sites.length}',
              detail: 'Deployment footprint currently surfaced in the roster.',
              icon: Icons.apartment_rounded,
              accent: const Color(0xFF63BDFF),
            ),
            _overviewCard(
              title: 'Active Dispatches',
              value: '$activeDispatches',
              detail:
                  'Open response activity attached to the visible site set.',
              icon: Icons.local_shipping_outlined,
              accent: const Color(0xFF59D79B),
            ),
            _overviewCard(
              title: 'Average Health',
              value: averageHealth.toStringAsFixed(1),
              detail:
                  'Composite posture score across the current site footprint.',
              icon: Icons.health_and_safety_outlined,
              accent: const Color(0xFFF6C067),
            ),
          ],
        );
      },
    );
  }

  Widget _selectedSiteOverviewCard({required _SiteDrillSnapshot selected}) {
    final statusColor = _statusColor(selected.healthStatus);
    final responseScore = _responseScore(selected);

    return Container(
      key: const ValueKey('sites-overview-selected-card'),
      padding: const EdgeInsets.all(1.25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.12),
            const Color(0xFFFFFFFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(4.25),
        border: Border.all(color: statusColor.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10.5,
                height: 10.5,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Icon(
                  Icons.visibility_outlined,
                  color: statusColor,
                  size: 6.3,
                ),
              ),
              const SizedBox(width: 1.0),
              Expanded(
                child: Text(
                  'SITE IN FOCUS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: statusColor,
                    fontSize: 5.7,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 0.4),
          _tinyPill('Health ${selected.healthStatus}', statusColor),
          const SizedBox(height: 0.5),
          Text(
            selected.siteId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF172638),
              fontSize: 8.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 0.2),
          Text(
            '${selected.clientId} / ${selected.regionId}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF556B80),
              fontSize: 5.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 0.5),
          Wrap(
            spacing: 0.55,
            runSpacing: 0.55,
            children: [
              _tinyPill('Response $responseScore%', const Color(0xFF63BDFF)),
              _workspaceBannerAction(
                key: const ValueKey('sites-overview-selected-open-trace'),
                label: 'Trace',
                selected: _workspaceView == _SiteWorkspaceView.trace,
                accent: _workspaceAccent(_SiteWorkspaceView.trace),
                onTap: () => _setWorkspaceView(_SiteWorkspaceView.trace),
              ),
              _workspaceBannerAction(
                key: const ValueKey('sites-overview-selected-open-tactical'),
                label: 'Tactical',
                selected: false,
                accent: const Color(0xFF93C5FD),
                onTap: () => _showTacticalLinkDialog(context),
              ),
            ],
          ),
        ],
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
      padding: const EdgeInsets.all(2.25),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(4.25),
        border: Border.all(color: const Color(0xFFD6E1EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(3.5),
                ),
                child: Icon(icon, color: accent, size: 8.4),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFF172638),
                    fontSize: 10.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 1.5),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              color: const Color(0xFF7A8FA4),
              fontSize: 6.6,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 0.2),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF556B80),
              fontSize: 6.4,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  void _showTacticalLinkDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFFFF),
          title: Text(
            'Tactical Link Ready',
            style: GoogleFonts.inter(
              color: const Color(0xFF172638),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Use Tactical to inspect watch posture, limited coverage, responder context, and map-driven site actions for the selected deployment.',
            style: GoogleFonts.inter(
              color: const Color(0xFF556B80),
              height: 1.45,
            ),
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

  Widget _workspaceStatusBanner(
    BuildContext context, {
    required List<_SiteDrillSnapshot> allSites,
    required List<_SiteDrillSnapshot> visibleSites,
    required _SiteDrillSnapshot selected,
    bool shellless = false,
    bool summaryOnly = false,
  }) {
    final watchCount = _siteCountForFilter(allSites, _SiteLaneFilter.watch);
    return LayoutBuilder(
      builder: (context, constraints) {
        final showInlineFocusCard = constraints.maxWidth >= 1120;
        final controls = Wrap(
          spacing: 0.75,
          runSpacing: 0.75,
          children: [
            _statusPill(
              icon: Icons.apartment_rounded,
              label: '${visibleSites.length} Visible',
              accent: const Color(0xFF63BDFF),
            ),
            _statusPill(
              icon: Icons.warning_amber_rounded,
              label: '$watchCount Watch',
              accent: watchCount > 0
                  ? const Color(0xFFF6C067)
                  : const Color(0xFF94A3B8),
            ),
            _workspaceBannerAction(
              key: const ValueKey('sites-workspace-banner-open-all'),
              label: 'All',
              selected: _siteLaneFilter == _SiteLaneFilter.all,
              accent: _laneAccent(_SiteLaneFilter.all),
              onTap: () => _setSiteLaneFilter(allSites, _SiteLaneFilter.all),
            ),
            _workspaceBannerAction(
              key: const ValueKey('sites-workspace-banner-open-watch'),
              label: 'Watch',
              selected: _siteLaneFilter == _SiteLaneFilter.watch,
              accent: _laneAccent(_SiteLaneFilter.watch),
              onTap: watchCount == 0
                  ? null
                  : () => _setSiteLaneFilter(allSites, _SiteLaneFilter.watch),
            ),
            _workspaceBannerAction(
              key: const ValueKey('sites-workspace-banner-open-command'),
              label: 'Command',
              selected: _workspaceView == _SiteWorkspaceView.command,
              accent: _workspaceAccent(_SiteWorkspaceView.command),
              onTap: () => _setWorkspaceView(_SiteWorkspaceView.command),
            ),
            _workspaceBannerAction(
              key: const ValueKey('sites-workspace-banner-open-outcomes'),
              label: 'Outcomes',
              selected: _workspaceView == _SiteWorkspaceView.outcomes,
              accent: _workspaceAccent(_SiteWorkspaceView.outcomes),
              onTap: () => _setWorkspaceView(_SiteWorkspaceView.outcomes),
            ),
            _workspaceBannerAction(
              key: const ValueKey('sites-workspace-banner-open-trace'),
              label: 'Trace',
              selected: _workspaceView == _SiteWorkspaceView.trace,
              accent: _workspaceAccent(_SiteWorkspaceView.trace),
              onTap: () => _setWorkspaceView(_SiteWorkspaceView.trace),
            ),
            _workspaceBannerAction(
              key: const ValueKey('sites-workspace-banner-open-tactical'),
              label: 'Tactical',
              selected: false,
              accent: const Color(0xFF93C5FD),
              onTap: () => _showTacticalLinkDialog(context),
            ),
          ],
        );
        final focusCard = _selectedSiteOverviewCard(selected: selected);
        final bannerChild = showInlineFocusCard
            ? summaryOnly
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 0.75,
                                runSpacing: 0.75,
                                children: [
                                  _statusPill(
                                    icon: Icons.apartment_rounded,
                                    label: '${visibleSites.length} Visible',
                                    accent: const Color(0xFF63BDFF),
                                  ),
                                  _statusPill(
                                    icon: Icons.warning_amber_rounded,
                                    label: '$watchCount Watch',
                                    accent: watchCount > 0
                                        ? const Color(0xFFF6C067)
                                        : const Color(0xFF94A3B8),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 0.9),
                              Text(
                                'Lane pivots stay pinned in the site roster, while command, outcomes, trace, and tactical handoff stay anchored to the selected-site board below.',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF556B80),
                                  fontSize: 6.7,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 1.25),
                        SizedBox(width: 118, child: focusCard),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: controls),
                        const SizedBox(width: 1.25),
                        SizedBox(width: 118, child: focusCard),
                      ],
                    )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [controls, const SizedBox(height: 1.0), focusCard],
              );
        if (shellless) {
          return KeyedSubtree(
            key: const ValueKey('sites-workspace-status-banner'),
            child: bannerChild,
          );
        }
        return Container(
          key: const ValueKey('sites-workspace-status-banner'),
          width: double.infinity,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(4.25),
            border: Border.all(color: const Color(0xFFD6E1EC)),
          ),
          child: bannerChild,
        );
      },
    );
  }

  Widget _siteRoster(
    List<_SiteDrillSnapshot> allSites,
    List<_SiteDrillSnapshot> sites,
    _SiteDrillSnapshot selected, {
    bool embeddedScroll = true,
  }) {
    final visibleSites = sites.take(_maxRosterRows).toList(growable: false);
    final hiddenSites = sites.length - visibleSites.length;
    final list = ListView.separated(
      padding: const EdgeInsets.all(_spaceXs),
      itemCount: visibleSites.length,
      shrinkWrap: !embeddedScroll,
      primary: embeddedScroll,
      physics: embeddedScroll ? null : const NeverScrollableScrollPhysics(),
      separatorBuilder: (context, index) => const SizedBox(height: _spaceXs),
      itemBuilder: (context, index) {
        final site = visibleSites[index];
        final isSelected = site.siteKey == selected.siteKey;
        return _siteRosterCard(site, selected: isSelected);
      },
    );
    return Container(
      decoration: onyxWorkspaceSurfaceDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2.75, 2.75, 2.75, 1.25),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3C79BB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: _spaceXs),
                      Text(
                        'Site Roster',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF172638),
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 1.75),
                Text(
                  '${sites.length}/${allSites.length}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF86A2C8),
                    fontSize: 7.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(2.75, 0, 2.75, 2.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sites.isEmpty
                      ? 'No sites match the active lane. Switch lanes to recover the roster.'
                      : '${sites.length} sites are visible in the ${_laneLabel(_siteLaneFilter).toLowerCase()} lane.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF556B80),
                    fontSize: 6.8,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 1.75),
                Wrap(
                  spacing: 2.0,
                  runSpacing: 2.0,
                  children: [
                    _laneFilterChip(
                      key: const ValueKey('sites-roster-filter-all'),
                      label: 'All',
                      count: allSites.length,
                      selected: _siteLaneFilter == _SiteLaneFilter.all,
                      onTap: () =>
                          _setSiteLaneFilter(allSites, _SiteLaneFilter.all),
                    ),
                    _laneFilterChip(
                      key: const ValueKey('sites-roster-filter-watch'),
                      label: 'Watch',
                      count: _siteCountForFilter(
                        allSites,
                        _SiteLaneFilter.watch,
                      ),
                      selected: _siteLaneFilter == _SiteLaneFilter.watch,
                      onTap: () =>
                          _setSiteLaneFilter(allSites, _SiteLaneFilter.watch),
                    ),
                    _laneFilterChip(
                      key: const ValueKey('sites-roster-filter-active'),
                      label: 'Active',
                      count: _siteCountForFilter(
                        allSites,
                        _SiteLaneFilter.active,
                      ),
                      selected: _siteLaneFilter == _SiteLaneFilter.active,
                      onTap: () =>
                          _setSiteLaneFilter(allSites, _SiteLaneFilter.active),
                    ),
                    _laneFilterChip(
                      key: const ValueKey('sites-roster-filter-strong'),
                      label: 'Strong',
                      count: _siteCountForFilter(
                        allSites,
                        _SiteLaneFilter.strong,
                      ),
                      selected: _siteLaneFilter == _SiteLaneFilter.strong,
                      onTap: () =>
                          _setSiteLaneFilter(allSites, _SiteLaneFilter.strong),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF223244)),
          if (embeddedScroll)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: sites.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(5),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                'No sites are visible in this lane. Use another lane to continue.',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF7D93B1),
                                  fontSize: 8.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        : list,
                  ),
                  if (hiddenSites > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 2.5),
                      child: OnyxTruncationHint(
                        visibleCount: visibleSites.length,
                        totalCount: sites.length,
                        subject: 'sites',
                        hiddenDescriptor: 'additional sites',
                        color: const Color(0xFF86A2C8),
                      ),
                    ),
                ],
              ),
            )
          else ...[
            if (sites.isEmpty)
              Padding(
                padding: EdgeInsets.all(5),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    'No sites are visible in this lane. Use another lane to continue.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF7D93B1),
                      fontSize: 8.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              list,
            if (hiddenSites > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 3.5),
                child: OnyxTruncationHint(
                  visibleCount: visibleSites.length,
                  totalCount: sites.length,
                  subject: 'sites',
                  hiddenDescriptor: 'additional sites',
                  color: const Color(0xFF86A2C8),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _siteRosterCard(_SiteDrillSnapshot site, {required bool selected}) {
    final statusColor = _statusColor(site.healthStatus);
    final pressureColor = site.failedCount > 0
        ? const Color(0xFFFF6A78)
        : site.activeDispatches > 0
        ? const Color(0xFF6FB5FF)
        : statusColor;
    return InkWell(
      key: ValueKey('sites-roster-card-${site.siteId}'),
      onTap: () => _selectSite(site),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFF7FAFF), Color(0xFFFFFFFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: selected ? const Color(0xFF3476B1) : const Color(0xFFD6E1EC),
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
                        site.siteId,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF172638),
                          fontSize: 9.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 0.85),
                      Text(
                        '${site.clientId} / ${site.regionId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF556B80),
                          fontSize: 7.7,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _siteStatusBadge(site),
              ],
            ),
            const SizedBox(height: 1.75),
            Wrap(
              spacing: 1.75,
              runSpacing: 1.75,
              children: [
                _tinyPill(
                  'Health ${site.healthScore.toStringAsFixed(0)}',
                  statusColor,
                ),
                _tinyPill(
                  'Active ${site.activeDispatches}',
                  const Color(0xFF4EB8FF),
                ),
                _tinyPill(
                  'Guards ${site.guardsEngaged}',
                  const Color(0xFF65D5A5),
                ),
              ],
            ),
            const SizedBox(height: 1.75),
            _miniProgressBar(
              label: 'Response tempo',
              value: _responseScore(site),
              color: pressureColor,
            ),
            const SizedBox(height: 1.75),
            _miniProgressBar(
              label: 'Patrol coverage',
              value: _patrolCoverageScore(site),
              color: statusColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _siteWorkspace(
    List<_SiteDrillSnapshot> allSites,
    List<_SiteDrillSnapshot> visibleSites,
    _SiteDrillSnapshot site, {
    bool embeddedScroll = true,
  }) {
    final statusColor = _statusColor(site.healthStatus);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3C79BB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 1.5),
                  Text(
                    '${site.clientId} / ${site.regionId} / ${site.siteId}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE7F0FF),
                      fontSize: 9.7,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 0.4),
                  Text(
                    '${visibleSites.length}/${allSites.length} visible • ${_workspaceViewLabel(_workspaceView)}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF93AACE),
                      fontSize: 5.9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 2.0),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 3.25,
                vertical: 1.2,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: statusColor.withValues(alpha: 0.15),
                border: Border.all(color: statusColor.withValues(alpha: 0.8)),
              ),
              child: Text(
                '${site.healthStatus} • ${site.healthScore.toStringAsFixed(1)}',
                style: GoogleFonts.inter(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 7.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 0.85),
        _siteFocusBanner(site),
        const SizedBox(height: 0.85),
        Wrap(
          spacing: 1.0,
          runSpacing: 1.0,
          children: [
            _workspaceViewChip(
              key: const ValueKey('sites-workspace-view-command'),
              label: 'Command',
              selected: _workspaceView == _SiteWorkspaceView.command,
              onTap: () => _setWorkspaceView(_SiteWorkspaceView.command),
            ),
            _workspaceViewChip(
              key: const ValueKey('sites-workspace-view-outcomes'),
              label: 'Outcomes',
              selected: _workspaceView == _SiteWorkspaceView.outcomes,
              onTap: () => _setWorkspaceView(_SiteWorkspaceView.outcomes),
            ),
            _workspaceViewChip(
              key: const ValueKey('sites-workspace-view-trace'),
              label: 'Trace',
              selected: _workspaceView == _SiteWorkspaceView.trace,
              onTap: () => _setWorkspaceView(_SiteWorkspaceView.trace),
            ),
          ],
        ),
        const SizedBox(height: 0.85),
        _workspaceDeck(site),
      ],
    );
    return Container(
      decoration: onyxWorkspaceSurfaceDecoration(),
      child: embeddedScroll
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(1.35),
              child: content,
            )
          : Padding(padding: const EdgeInsets.all(1.35), child: content),
    );
  }

  Widget _workspaceDeck(_SiteDrillSnapshot site) {
    return switch (_workspaceView) {
      _SiteWorkspaceView.command => _commandWorkspace(site),
      _SiteWorkspaceView.outcomes => _outcomesWorkspace(site),
      _SiteWorkspaceView.trace => _traceWorkspace(site),
    };
  }

  Widget _commandWorkspace(_SiteDrillSnapshot site) {
    return Column(
      key: const ValueKey('sites-workspace-panel-command'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 3,
          children: [
            _metricCard(
              'Decisions',
              site.decisions.toString(),
              const Color(0xFF58B7FF),
            ),
            _metricCard(
              'Executed',
              site.executedCount.toString(),
              const Color(0xFF4CDD8A),
            ),
            _metricCard(
              'Denied',
              site.deniedCount.toString(),
              const Color(0xFFF6B24A),
            ),
            _metricCard(
              'Failed',
              site.failedCount.toString(),
              const Color(0xFFFF6A78),
            ),
            _metricCard(
              'Active',
              site.activeDispatches.toString(),
              const Color(0xFF7CA2FF),
            ),
            _metricCard(
              'Check-Ins',
              site.guardCheckIns.toString(),
              const Color(0xFF68CBFF),
            ),
            _metricCard(
              'Patrols',
              site.patrolsCompleted.toString(),
              const Color(0xFF65D5A5),
            ),
            _metricCard(
              'Avg Response',
              '${site.averageResponseMinutes.toStringAsFixed(1)} min',
              const Color(0xFF8FD0FF),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 920;
            final outcomePanel = _panel(
              'Dispatch Outcome Mix',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ratioBar(
                    'Executed',
                    site.executedCount,
                    site.decisions,
                    const Color(0xFF45D58D),
                  ),
                  _ratioBar(
                    'Denied',
                    site.deniedCount,
                    site.decisions,
                    const Color(0xFFF0B24C),
                  ),
                  _ratioBar(
                    'Failed',
                    site.failedCount,
                    site.decisions,
                    const Color(0xFFFF6A78),
                  ),
                  _ratioBar(
                    'Still Active',
                    site.activeDispatches,
                    site.decisions,
                    const Color(0xFF6FB5FF),
                  ),
                ],
              ),
              shellless: !stacked,
            );
            final pulsePanel = _panel(
              'Operational Pulse',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _textLine('Guards Engaged', site.guardsEngaged.toString()),
                  _textLine(
                    'Avg Patrol Duration',
                    '${site.averagePatrolMinutes.toStringAsFixed(1)} min',
                  ),
                  _textLine('Last Event UTC', _formatUtc(site.lastEventAtUtc)),
                  _textLine(
                    'Recent Event Count',
                    site.recentEvents.length.toString(),
                  ),
                  _textLine(
                    'Denied Reason Trend',
                    site.deniedReasons.isEmpty
                        ? 'No denials recorded'
                        : site.deniedReasons.first,
                  ),
                ],
              ),
              shellless: !stacked,
            );
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [outcomePanel, const SizedBox(height: 5), pulsePanel],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: outcomePanel),
                const SizedBox(width: 4),
                Expanded(child: pulsePanel),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 920;
            final directivePanel = _panel(
              'Command Directive',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _siteDirective(site),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF556B80),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _textLine(
                    'Watch posture',
                    _siteNeedsWatch(site)
                        ? 'Active monitoring required'
                        : 'Stable command hold',
                  ),
                  _textLine(
                    'Lead pressure',
                    site.failedCount > 0
                        ? 'Execution failure'
                        : site.activeDispatches > 0
                        ? 'Open dispatch exposure'
                        : 'Routine patrol rhythm',
                  ),
                ],
              ),
              shellless: !stacked,
            );
            final tracePanel = _eventTracePanel(
              site,
              previewOnly: true,
              shellless: !stacked,
            );
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  directivePanel,
                  const SizedBox(height: 5),
                  tracePanel,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: directivePanel),
                const SizedBox(width: 5),
                Expanded(child: tracePanel),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _outcomesWorkspace(_SiteDrillSnapshot site) {
    return Column(
      key: const ValueKey('sites-workspace-panel-outcomes'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 5,
          runSpacing: 4,
          children: [
            _metricCard(
              'Executed',
              site.executedCount.toString(),
              const Color(0xFF4CDD8A),
            ),
            _metricCard(
              'Denied',
              site.deniedCount.toString(),
              const Color(0xFFF6B24A),
            ),
            _metricCard(
              'Failed',
              site.failedCount.toString(),
              const Color(0xFFFF6A78),
            ),
            _metricCard(
              'Active',
              site.activeDispatches.toString(),
              const Color(0xFF7CA2FF),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 920;
            final outcomePanel = _panel(
              'Dispatch Outcome Mix',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ratioBar(
                    'Executed',
                    site.executedCount,
                    site.decisions,
                    const Color(0xFF45D58D),
                  ),
                  _ratioBar(
                    'Denied',
                    site.deniedCount,
                    site.decisions,
                    const Color(0xFFF0B24C),
                  ),
                  _ratioBar(
                    'Failed',
                    site.failedCount,
                    site.decisions,
                    const Color(0xFFFF6A78),
                  ),
                  _ratioBar(
                    'Still Active',
                    site.activeDispatches,
                    site.decisions,
                    const Color(0xFF6FB5FF),
                  ),
                ],
              ),
              shellless: !stacked,
            );
            final pressurePanel = _panel(
              'Outcome Pressure',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _textLine('Decision Volume', site.decisions.toString()),
                  _textLine(
                    'Closed Incidents',
                    site.incidentsClosed.toString(),
                  ),
                  _textLine(
                    'Denied Reason Trend',
                    site.deniedReasons.isEmpty
                        ? 'No denials recorded'
                        : site.deniedReasons.first,
                  ),
                  _textLine(
                    'Outcome Read',
                    site.failedCount > 0
                        ? 'Failures require immediate review'
                        : site.deniedCount > 0
                        ? 'Denials need operator validation'
                        : 'Outcome flow is under control',
                  ),
                ],
              ),
              shellless: !stacked,
            );
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  outcomePanel,
                  const SizedBox(height: 5),
                  pressurePanel,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: outcomePanel),
                const SizedBox(width: 5),
                Expanded(child: pressurePanel),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _traceWorkspace(_SiteDrillSnapshot site) {
    return Column(
      key: const ValueKey('sites-workspace-panel-trace'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 920;
            final tracePanel = _eventTracePanel(site, shellless: !stacked);
            final reviewPanel = _panel(
              'Trace Review',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _textLine('Last Event UTC', _formatUtc(site.lastEventAtUtc)),
                  _textLine('Trace Count', site.traceEventCount.toString()),
                  _textLine('Guards Engaged', site.guardsEngaged.toString()),
                  _textLine(
                    'Latest Denial',
                    site.deniedReasons.isEmpty
                        ? 'No denials recorded'
                        : site.deniedReasons.first,
                  ),
                ],
              ),
              shellless: !stacked,
            );
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [tracePanel, const SizedBox(height: 5), reviewPanel],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: tracePanel),
                const SizedBox(width: 5),
                Expanded(flex: 4, child: reviewPanel),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _eventTracePanel(
    _SiteDrillSnapshot site, {
    bool previewOnly = false,
    bool shellless = false,
  }) {
    final rows = previewOnly
        ? site.recentEvents.take(4).toList()
        : site.recentEvents;
    return _panel(
      'Recent Site Event Trace',
      rows.isEmpty
          ? Text(
              'No event trace available.',
              style: GoogleFonts.inter(
                color: const Color(0xFF556B80),
                fontSize: 12,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  primary: false,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rows.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 5),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(
                            Icons.circle,
                            size: 6,
                            color: Color(0xFF4AAAFF),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            row,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF556B80),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (site.traceEventCount > rows.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: OnyxTruncationHint(
                      visibleCount: rows.length,
                      totalCount: site.traceEventCount,
                      subject: 'site events',
                      hiddenDescriptor: 'older events',
                    ),
                  ),
              ],
            ),
      shellless: shellless,
    );
  }

  List<_SiteDrillSnapshot> _filteredSites(
    List<_SiteDrillSnapshot> sites, {
    _SiteLaneFilter? filter,
  }) {
    final activeFilter = filter ?? _siteLaneFilter;
    return sites
        .where((site) {
          return switch (activeFilter) {
            _SiteLaneFilter.all => true,
            _SiteLaneFilter.watch => _siteNeedsWatch(site),
            _SiteLaneFilter.active => site.activeDispatches > 0,
            _SiteLaneFilter.strong =>
              site.healthStatus == 'STRONG' &&
                  site.failedCount == 0 &&
                  site.deniedCount == 0 &&
                  site.activeDispatches == 0,
          };
        })
        .toList(growable: false);
  }

  int _siteCountForFilter(
    List<_SiteDrillSnapshot> sites,
    _SiteLaneFilter filter,
  ) {
    return _filteredSites(sites, filter: filter).length;
  }

  void _setSiteLaneFilter(
    List<_SiteDrillSnapshot> sites,
    _SiteLaneFilter filter,
  ) {
    if (_siteLaneFilter == filter) {
      return;
    }
    final filtered = _filteredSites(sites, filter: filter);
    final nextSelected = filtered.isEmpty
        ? _selectedSiteKey
        : filtered.any((site) => site.siteKey == _selectedSiteKey)
        ? _selectedSiteKey
        : filtered.first.siteKey;
    setState(() {
      _siteLaneFilter = filter;
      _selectedSiteKey = nextSelected;
    });
  }

  void _setWorkspaceView(_SiteWorkspaceView view) {
    if (_workspaceView == view) {
      return;
    }
    setState(() {
      _workspaceView = view;
    });
  }

  void _selectSite(_SiteDrillSnapshot site) {
    if (_selectedSiteKey == site.siteKey) {
      return;
    }
    setState(() {
      _selectedSiteKey = site.siteKey;
    });
  }

  bool _siteNeedsWatch(_SiteDrillSnapshot site) {
    return site.healthStatus == 'CRITICAL' ||
        site.healthStatus == 'WARNING' ||
        site.failedCount > 0 ||
        site.deniedCount > 0;
  }

  String _laneLabel(_SiteLaneFilter filter) {
    return switch (filter) {
      _SiteLaneFilter.all => 'All Sites',
      _SiteLaneFilter.watch => 'Watch Lane',
      _SiteLaneFilter.active => 'Active Lane',
      _SiteLaneFilter.strong => 'Strong Lane',
    };
  }

  Color _laneAccent(_SiteLaneFilter filter) {
    return switch (filter) {
      _SiteLaneFilter.all => const Color(0xFF63BDFF),
      _SiteLaneFilter.watch => const Color(0xFFF6C067),
      _SiteLaneFilter.active => const Color(0xFF59D79B),
      _SiteLaneFilter.strong => const Color(0xFF34D399),
    };
  }

  String _workspaceViewLabel(_SiteWorkspaceView view) {
    return switch (view) {
      _SiteWorkspaceView.command => 'Command Board',
      _SiteWorkspaceView.outcomes => 'Outcome Board',
      _SiteWorkspaceView.trace => 'Trace Board',
    };
  }

  Color _workspaceAccent(_SiteWorkspaceView view) {
    return switch (view) {
      _SiteWorkspaceView.command => const Color(0xFF63BDFF),
      _SiteWorkspaceView.outcomes => const Color(0xFF59D79B),
      _SiteWorkspaceView.trace => const Color(0xFFA78BFA),
    };
  }

  String _siteDirective(_SiteDrillSnapshot site) {
    if (site.failedCount > 0) {
      return 'Execution failures are shaping posture at ${site.siteId}. Hold this site in command focus until the broken chain is explained.';
    }
    if (site.activeDispatches > 0) {
      return '${site.siteId} is carrying active response load. Keep patrol visibility and responder tempo in the front channel.';
    }
    if (site.deniedCount > 0) {
      return 'Denied actions are suppressing part of the response path. Validate the operator rationale before pressure returns.';
    }
    if (site.healthStatus == 'STRONG') {
      return '${site.siteId} is holding a strong deployment posture. Use it as the clean benchmark lane.';
    }
    return '${site.siteId} is stable, but the next patrol loop should still be kept in view for early drift.';
  }

  int _responseScore(_SiteDrillSnapshot site) {
    if (site.averageResponseMinutes <= 0) {
      return site.activeDispatches > 0
          ? _kResponseScoreNoDataActive
          : _kResponseScoreNoDataQuiet;
    }
    final score =
        100 - (((site.averageResponseMinutes - 4).clamp(0.0, 12.0)) * 8);
    return score.round().clamp(0, 100);
  }

  int _patrolCoverageScore(_SiteDrillSnapshot site) {
    final score =
        (site.patrolsCompleted * 14) +
        (site.guardCheckIns * 10) +
        (site.guardsEngaged * 8);
    return score.clamp(0, 100);
  }

  Widget _siteStatusBadge(_SiteDrillSnapshot site) {
    final color = _statusColor(site.healthStatus);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Text(
        site.healthStatus,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _miniProgressBar({
    required String label,
    required int value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: const Color(0xFF7A8FA4),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$value%',
              style: GoogleFonts.inter(
                color: const Color(0xFF172638),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 3,
            value: value / 100,
            backgroundColor: const Color(0xFFE6EEF6),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _laneFilterChip({
    required Key key,
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.75),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEDF6FF) : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF3F87C9) : const Color(0xFFD6E1EC),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: selected
                    ? const Color(0xFF2F6AA3)
                    : const Color(0xFF7A8FA4),
                fontSize: 6.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 3),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 4.5,
                vertical: 1.75,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFDCEBFA)
                    : const Color(0xFFF4F8FC),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  color: const Color(0xFF172638),
                  fontSize: 6.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _workspaceViewChip({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 3.25, vertical: 1.75),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEDF6FF) : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF3F87C9) : const Color(0xFFD6E1EC),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? const Color(0xFF2F6AA3) : const Color(0xFF7A8FA4),
            fontSize: 6.8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _workspaceBannerAction({
    required Key key,
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3.25, vertical: 1.75),
        decoration: BoxDecoration(
          color: !enabled
              ? const Color(0xFFF1F5F9)
              : selected
              ? accent.withValues(alpha: 0.2)
              : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: !enabled
                ? const Color(0xFFD6E1EC)
                : selected
                ? accent.withValues(alpha: 0.75)
                : accent.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: !enabled ? const Color(0xFF7A8FA4) : const Color(0xFF172638),
            fontSize: 6.6,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _siteFocusBanner(_SiteDrillSnapshot site) {
    final statusColor = _statusColor(site.healthStatus);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF7FAFF), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(5.0),
        border: Border.all(color: const Color(0xFFD6E1EC)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 920;
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SITE COMMAND FOCUS',
                style: GoogleFonts.inter(
                  color: const Color(0xFF7A8FA4),
                  fontSize: 6.3,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 0.5),
              Text(
                _siteDirective(site),
                style: GoogleFonts.inter(
                  color: const Color(0xFF172638),
                  fontSize: 7.0,
                  fontWeight: FontWeight.w600,
                  height: 1.36,
                ),
              ),
            ],
          );
          final metrics = Wrap(
            spacing: 1.5,
            runSpacing: 1.5,
            children: [
              _tinyPill(
                'Health ${site.healthScore.toStringAsFixed(0)}',
                statusColor,
              ),
              _tinyPill(
                'Response ${_responseScore(site)}%',
                const Color(0xFF8FD0FF),
              ),
              _tinyPill(
                'Patrol ${_patrolCoverageScore(site)}%',
                const Color(0xFF65D5A5),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summary, const SizedBox(height: 1.0), metrics],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: summary),
              const SizedBox(width: 0.85),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 144),
                child: metrics,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ratioBar(String label, int value, int total, Color color) {
    final ratio = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: const Color(0xFF7A8FA4),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$value/$total',
                style: GoogleFonts.inter(
                  color: const Color(0xFF172638),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: ratio,
              backgroundColor: const Color(0xFFE6EEF6),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.5),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.inter(
                color: const Color(0xFF7A8FA4),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: const Color(0xFF172638),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel(
    String title,
    Widget child, {
    bool expandChild = false,
    bool shellless = false,
  }) {
    if (shellless) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFF8FD1FF),
              fontSize: 8.9,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          if (expandChild) Expanded(child: child) else child,
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: onyxPanelSurfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF3C79BB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 1.5),
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFF172638),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, Color accent) {
    return Container(
      width: 112,
      padding: const EdgeInsets.all(3),
      decoration: onyxPanelSurfaceDecoration(radius: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 3,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF7A8FA4),
              fontSize: 7,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 0.5),
          Text(
            value,
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tinyPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.75),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 7.6,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'CRITICAL':
        return const Color(0xFFFF6575);
      case 'WARNING':
        return const Color(0xFFF6B24A);
      case 'STABLE':
        return const Color(0xFF47D49B);
      default:
        return const Color(0xFF8EA4C2);
    }
  }

  String _formatUtc(DateTime dt) {
    final z = dt.toUtc().toIso8601String();
    return z.length > 19 ? '${z.substring(0, 19)}Z' : z;
  }

  List<_SiteDrillSnapshot> _buildSiteDrillSnapshots(
    List<DispatchEvent> events,
    OperationsHealthSnapshot projection,
  ) {
    final bySite = <String, _SiteAccumulator>{};
    final decisionTimes = <String, DateTime>{};
    final decisionSite = <String, String>{};
    final terminalDispatches = <String, String>{};

    for (final event in events) {
      final siteKey = _siteKeyFromEvent(event);
      if (siteKey == null) continue;

      final acc = bySite.putIfAbsent(siteKey, () => _SiteAccumulator(siteKey));
      acc.lastEventAtUtc = acc.lastEventAtUtc.isAfter(event.occurredAt)
          ? acc.lastEventAtUtc
          : event.occurredAt;

      if (event is DecisionCreated) {
        decisionTimes[event.dispatchId] = event.occurredAt;
        decisionSite[event.dispatchId] = siteKey;
        acc.decisions += 1;
        acc.recentTrace.add(
          _trace(event.occurredAt, 'DECISION ${event.dispatchId} created'),
        );
      } else if (event is ExecutionCompleted) {
        terminalDispatches[event.dispatchId] = event.success
            ? 'CONFIRMED'
            : 'FAILED';
        if (event.success) {
          acc.executed += 1;
          acc.recentTrace.add(
            _trace(event.occurredAt, 'CONFIRMED ${event.dispatchId}'),
          );
        } else {
          acc.failed += 1;
          acc.recentTrace.add(
            _trace(event.occurredAt, 'FAILED ${event.dispatchId}'),
          );
        }
      } else if (event is ExecutionDenied) {
        terminalDispatches[event.dispatchId] = 'DENIED';
        acc.denied += 1;
        acc.deniedReasons.add(event.reason);
        acc.recentTrace.add(
          _trace(
            event.occurredAt,
            'DENIED ${event.dispatchId} (${event.reason})',
          ),
        );
      } else if (event is GuardCheckedIn) {
        acc.checkIns += 1;
        acc.guards.add(event.guardId);
        acc.recentTrace.add(
          _trace(event.occurredAt, 'GUARD CHECK-IN ${event.guardId}'),
        );
      } else if (event is PatrolCompleted) {
        acc.patrols += 1;
        acc.guards.add(event.guardId);
        acc.patrolDurationSeconds += event.durationSeconds;
        acc.recentTrace.add(
          _trace(event.occurredAt, 'PATROL ${event.routeId} completed'),
        );
      } else if (event is IncidentClosed) {
        acc.incidents += 1;
        acc.recentTrace.add(
          _trace(
            event.occurredAt,
            'INCIDENT ${event.dispatchId} closed (${event.resolutionType})',
          ),
        );
      } else if (event is ResponseArrived) {
        acc.guards.add(event.guardId);
        final decisionAt = decisionTimes[event.dispatchId];
        if (decisionAt != null) {
          acc.responseDeltaMinutes.add(
            event.occurredAt.difference(decisionAt).inMilliseconds / 60000.0,
          );
        }
        acc.recentTrace.add(
          _trace(
            event.occurredAt,
            'RESPONSE ${event.dispatchId} by ${event.guardId}',
          ),
        );
      }
    }

    for (final entry in decisionSite.entries) {
      final siteKey = entry.value;
      final dispatchId = entry.key;
      final state = terminalDispatches[dispatchId];
      if (state == null) {
        bySite[siteKey]?.active += 1;
      }
    }

    final projectionBySite = {
      for (final site in projection.sites)
        '${site.clientId}|${site.regionId}|${site.siteId}': site,
    };

    final snapshots = <_SiteDrillSnapshot>[];
    for (final acc in bySite.values) {
      final parts = acc.siteKey.split('|');
      if (parts.length != 3) continue;

      final projectionSite = projectionBySite[acc.siteKey];
      final avgResponse = acc.responseDeltaMinutes.isEmpty
          ? (projectionSite?.averageResponseMinutes ?? 0.0)
          : acc.responseDeltaMinutes.reduce((a, b) => a + b) /
                acc.responseDeltaMinutes.length;

      final avgPatrol = acc.patrols == 0
          ? 0.0
          : (acc.patrolDurationSeconds / acc.patrols) / 60.0;

      snapshots.add(
        _SiteDrillSnapshot(
          siteKey: acc.siteKey,
          clientId: parts[0],
          regionId: parts[1],
          siteId: parts[2],
          decisions: acc.decisions,
          executedCount: projectionSite?.executedCount ?? acc.executed,
          deniedCount: projectionSite?.deniedCount ?? acc.denied,
          failedCount: projectionSite?.failedCount ?? acc.failed,
          activeDispatches: projectionSite?.activeDispatches ?? acc.active,
          guardCheckIns: projectionSite?.guardCheckIns ?? acc.checkIns,
          patrolsCompleted: projectionSite?.patrolsCompleted ?? acc.patrols,
          incidentsClosed: projectionSite?.incidentsClosed ?? acc.incidents,
          averageResponseMinutes: avgResponse,
          averagePatrolMinutes: avgPatrol,
          guardsEngaged: acc.guards.length,
          deniedReasons: acc.deniedReasons.reversed.take(3).toList(),
          healthScore: projectionSite?.healthScore ?? 0.0,
          healthStatus: projectionSite?.healthStatus ?? 'STABLE',
          lastEventAtUtc: acc.lastEventAtUtc,
          traceEventCount: acc.recentTrace.length,
          recentEvents: acc.recentTrace.reversed.take(10).toList(),
        ),
      );
    }

    snapshots.sort((a, b) {
      final scoreSort = a.healthScore.compareTo(b.healthScore);
      if (scoreSort != 0) return scoreSort;
      return b.lastEventAtUtc.compareTo(a.lastEventAtUtc);
    });

    return snapshots;
  }

  String? _siteKeyFromEvent(DispatchEvent event) {
    if (event is DecisionCreated) {
      return '${event.clientId}|${event.regionId}|${event.siteId}';
    }
    if (event is ExecutionCompleted) {
      return '${event.clientId}|${event.regionId}|${event.siteId}';
    }
    if (event is ExecutionDenied) {
      return '${event.clientId}|${event.regionId}|${event.siteId}';
    }
    if (event is GuardCheckedIn) {
      return '${event.clientId}|${event.regionId}|${event.siteId}';
    }
    if (event is PatrolCompleted) {
      return '${event.clientId}|${event.regionId}|${event.siteId}';
    }
    if (event is ResponseArrived) {
      return '${event.clientId}|${event.regionId}|${event.siteId}';
    }
    if (event is IncidentClosed) {
      return '${event.clientId}|${event.regionId}|${event.siteId}';
    }
    return null;
  }

  String _trace(DateTime ts, String message) {
    final z = _formatUtc(ts);
    return '$z • $message';
  }
}

class _SiteAccumulator {
  final String siteKey;

  int decisions = 0;
  int executed = 0;
  int denied = 0;
  int failed = 0;
  int active = 0;
  int checkIns = 0;
  int patrols = 0;
  int incidents = 0;
  int patrolDurationSeconds = 0;
  final List<double> responseDeltaMinutes = [];
  final Set<String> guards = {};
  final List<String> deniedReasons = [];
  final List<String> recentTrace = [];
  DateTime lastEventAtUtc = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  _SiteAccumulator(this.siteKey);
}

class _SiteDrillSnapshot {
  final String siteKey;
  final String clientId;
  final String regionId;
  final String siteId;
  final int decisions;
  final int executedCount;
  final int deniedCount;
  final int failedCount;
  final int activeDispatches;
  final int guardCheckIns;
  final int patrolsCompleted;
  final int incidentsClosed;
  final double averageResponseMinutes;
  final double averagePatrolMinutes;
  final int guardsEngaged;
  final List<String> deniedReasons;
  final double healthScore;
  final String healthStatus;
  final DateTime lastEventAtUtc;
  final int traceEventCount;
  final List<String> recentEvents;

  const _SiteDrillSnapshot({
    required this.siteKey,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.decisions,
    required this.executedCount,
    required this.deniedCount,
    required this.failedCount,
    required this.activeDispatches,
    required this.guardCheckIns,
    required this.patrolsCompleted,
    required this.incidentsClosed,
    required this.averageResponseMinutes,
    required this.averagePatrolMinutes,
    required this.guardsEngaged,
    required this.deniedReasons,
    required this.healthScore,
    required this.healthStatus,
    required this.lastEventAtUtc,
    required this.traceEventCount,
    required this.recentEvents,
  });
}
