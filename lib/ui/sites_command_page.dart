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
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'theme/onyx_design_tokens.dart';
import 'ui_action_logger.dart';

class SitesAutoAuditReceipt {
  final String auditId;
  final String label;
  final String headline;
  final String detail;
  final Color accent;

  const SitesAutoAuditReceipt({
    required this.auditId,
    required this.label,
    required this.headline,
    required this.detail,
    required this.accent,
  });
}

class SitesCommandPage extends StatefulWidget {
  final List<DispatchEvent> events;
  final VoidCallback? onAddSite;
  final void Function(String siteId, String siteName)? onOpenMapForSite;
  final void Function(String siteId, String siteName)? onOpenSiteSettings;
  final void Function(String siteId, String siteName)? onOpenGuardRoster;
  final SitesAutoAuditReceipt? latestAutoAuditReceipt;
  final VoidCallback? onOpenLatestAudit;

  const SitesCommandPage({
    super.key,
    required this.events,
    this.onAddSite,
    this.onOpenMapForSite,
    this.onOpenSiteSettings,
    this.onOpenGuardRoster,
    this.latestAutoAuditReceipt,
    this.onOpenLatestAudit,
  });

  @override
  State<SitesCommandPage> createState() => _SitesCommandPageState();
}

enum _SiteLaneFilter { all, healthy, watch, strong }

enum _SiteWorkspaceView { response, coverage, checkpoints }

class _SitesCommandPageState extends State<SitesCommandPage> {
  String? _selectedSiteId;
  _SiteLaneFilter _siteLaneFilter = _SiteLaneFilter.all;
  _SiteWorkspaceView _workspaceView = _SiteWorkspaceView.response;

  @override
  Widget build(BuildContext context) {
    final projected = _siteRowsFromEvents(widget.events);
    final allSites = projected.isEmpty ? _seedSites() : projected;
    final filteredSites = _filteredSites(allSites);
    final selectedPool = filteredSites.isEmpty ? allSites : filteredSites;
    final selectedSiteId =
        selectedPool.any((site) => site.id == _selectedSiteId)
        ? _selectedSiteId
        : selectedPool.first.id;

    _selectedSiteId ??= selectedPool.first.id;
    final selected = selectedPool.firstWhere(
      (site) => site.id == selectedSiteId,
      orElse: () => selectedPool.first,
    );

    final strongCount = allSites
        .where((site) => site.status == _SiteStatus.strong)
        .length;
    final atRiskCount = allSites
        .where(
          (site) =>
              site.status == _SiteStatus.atRisk ||
              site.status == _SiteStatus.critical,
        )
        .length;
    final totalGuards = allSites.fold<int>(
      0,
      (sum, site) => sum + site.guardsActive,
    );

    return OnyxPageScaffold(
      child: LayoutBuilder(
        builder: (context, viewport) {
          const contentPadding = EdgeInsets.all(16);
          final useScrollFallback =
              isHandsetLayout(context) ||
              viewport.maxHeight < 700 ||
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
              ? viewport.maxWidth * 0.94
              : 1540.0;

          Widget buildSurfaceBody({required bool expandedPanels}) {
            Widget buildWorkspaceShell({required bool expandedPanels}) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 1240;
                  final roster = _rosterPane(
                    allSites,
                    filteredSites,
                    shellless: !stacked,
                  );
                  final workspace = _workspacePane(
                    selected,
                    filteredSites.length,
                    allSites.length,
                    shellless: !stacked,
                  );

                  if (stacked) {
                    if (expandedPanels) {
                      return ListView(
                        children: [
                          roster,
                          const SizedBox(height: 5),
                          workspace,
                        ],
                      );
                    }
                    return Column(
                      children: [roster, const SizedBox(height: 5), workspace],
                    );
                  }

                  final workspaceShell = Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: expandedPanels
                            ? SingleChildScrollView(child: roster)
                            : roster,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        flex: 8,
                        child: expandedPanels
                            ? SingleChildScrollView(child: workspace)
                            : workspace,
                      ),
                    ],
                  );
                  if (expandedPanels) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (stacked) ...[
                          _workspaceStatusBanner(
                            context: context,
                            allSites: allSites,
                            visibleSites: filteredSites,
                            selected: selected,
                          ),
                          const SizedBox(height: 5),
                        ],
                        Expanded(child: workspaceShell),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (stacked) ...[
                        _workspaceStatusBanner(
                          context: context,
                          allSites: allSites,
                          visibleSites: filteredSites,
                          selected: selected,
                        ),
                        const SizedBox(height: 5),
                      ],
                      workspaceShell,
                    ],
                  );
                },
              );
            }

            if (expandedPanels) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: buildWorkspaceShell(expandedPanels: true)),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [buildWorkspaceShell(expandedPanels: false)],
            );
          }

          final wideDesktopWorkspace = viewport.maxWidth >= 1240;

          return OnyxViewportWorkspaceLayout(
            padding: contentPadding,
            maxWidth: surfaceMaxWidth,
            lockToViewport: boundedDesktopSurface,
            spacing: 8,
            header: _heroHeader(
              selected: selected,
              totalSites: allSites.length,
              strongCount: strongCount,
              atRiskCount: atRiskCount,
              totalGuards: totalGuards,
              workspaceBanner: wideDesktopWorkspace
                  ? _workspaceStatusBanner(
                      context: context,
                      allSites: allSites,
                      visibleSites: filteredSites,
                      selected: selected,
                      shellless: true,
                    )
                  : null,
            ),
            body: buildSurfaceBody(expandedPanels: boundedDesktopSurface),
          );
        },
      ),
    );
  }

  List<_SiteViewModel> _filteredSites(
    List<_SiteViewModel> sites, {
    _SiteLaneFilter? filter,
  }) {
    final activeFilter = filter ?? _siteLaneFilter;
    return sites
        .where((site) {
          return switch (activeFilter) {
            _SiteLaneFilter.all => true,
            _SiteLaneFilter.healthy =>
              site.status == _SiteStatus.strong ||
                  site.status == _SiteStatus.stable,
            _SiteLaneFilter.watch =>
              site.status == _SiteStatus.atRisk ||
                  site.status == _SiteStatus.critical,
            _SiteLaneFilter.strong => site.status == _SiteStatus.strong,
          };
        })
        .toList(growable: false);
  }

  int _siteCountForFilter(List<_SiteViewModel> sites, _SiteLaneFilter filter) {
    return _filteredSites(sites, filter: filter).length;
  }

  void _setSiteLaneFilter(List<_SiteViewModel> sites, _SiteLaneFilter filter) {
    if (_siteLaneFilter == filter) {
      return;
    }
    final filteredSites = _filteredSites(sites, filter: filter);
    final nextSelectedSiteId = filteredSites.isEmpty
        ? (_selectedSiteId ?? (sites.isEmpty ? null : sites.first.id))
        : filteredSites.any((site) => site.id == _selectedSiteId)
        ? _selectedSiteId
        : filteredSites.first.id;
    setState(() {
      _siteLaneFilter = filter;
      _selectedSiteId = nextSelectedSiteId;
    });
    logUiAction(
      'sites.filter_lane',
      context: {'filter': filter.name, 'selected_site_id': nextSelectedSiteId},
    );
  }

  void _setWorkspaceView(_SiteWorkspaceView view) {
    if (_workspaceView == view) {
      return;
    }
    setState(() {
      _workspaceView = view;
    });
    logUiAction(
      'sites.workspace_view',
      context: {'view': view.name, 'selected_site_id': _selectedSiteId},
    );
  }

  void _openAddSite() {
    final callback = widget.onAddSite;
    if (callback == null) {
      return;
    }
    logUiAction(
      'sites.add_site',
      context: {'selected_site_id': _selectedSiteId},
    );
    callback();
  }

  void _openSiteSettings(_SiteViewModel site) {
    final callback = widget.onOpenSiteSettings;
    if (callback == null) {
      return;
    }
    logUiAction(
      'sites.open_settings',
      context: {'site_id': site.id, 'site_name': site.displayName},
    );
    callback(site.id, site.displayName);
  }

  void _openGuardRoster(_SiteViewModel site) {
    final callback = widget.onOpenGuardRoster;
    if (callback == null) {
      return;
    }
    logUiAction(
      'sites.open_guard_roster',
      context: {'site_id': site.id, 'site_name': site.displayName},
    );
    callback(site.id, site.displayName);
  }

  Widget _workspaceStatusBanner({
    required BuildContext context,
    required List<_SiteViewModel> allSites,
    required List<_SiteViewModel> visibleSites,
    required _SiteViewModel selected,
    bool shellless = false,
  }) {
    final watchCount = _siteCountForFilter(allSites, _SiteLaneFilter.watch);
    final strongCount = _siteCountForFilter(allSites, _SiteLaneFilter.strong);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            _workspaceStatusPill(
              icon: Icons.apartment_rounded,
              label: '${visibleSites.length} Visible',
              accent: const Color(0xFF63BDFF),
            ),
            _workspaceStatusPill(
              icon: Icons.radar_outlined,
              label: 'Scope ${_laneLabel(_siteLaneFilter)}',
              accent: _laneAccent(_siteLaneFilter),
            ),
            _workspaceStatusPill(
              icon: Icons.flag_outlined,
              label: 'Focus ${selected.id}',
              accent: _statusColor(selected.status),
            ),
            _workspaceStatusPill(
              icon: Icons.warning_amber_rounded,
              label: '$watchCount Watch',
              accent: watchCount > 0
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF94A3B8),
            ),
            _workspaceStatusPill(
              icon: Icons.verified_outlined,
              label: '$strongCount Strong',
              accent: const Color(0xFF22D3EE),
            ),
          ],
        ),
      ],
    );
    if (shellless) {
      return KeyedSubtree(
        key: const ValueKey('sites-workspace-status-banner'),
        child: content,
      );
    }
    return Container(
      key: const ValueKey('sites-workspace-status-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: content,
    );
  }

  Widget _heroHeader({
    required _SiteViewModel selected,
    required int totalSites,
    required int strongCount,
    required int atRiskCount,
    required int totalGuards,
    Widget? workspaceBanner,
  }) {
    final heroActions = <Widget>[
      _heroActionButton(
        key: const ValueKey('sites-view-tactical-button'),
        icon: Icons.map_outlined,
        label: 'OPEN SITE MAP',
        accent: const Color(0xFF93C5FD),
        onPressed: () => _openTacticalForSite(context, selected),
      ),
      if (widget.onOpenSiteSettings != null)
        _heroActionButton(
          key: const ValueKey('sites-hero-edit-site-button'),
          icon: Icons.edit_outlined,
          label: 'OPEN SITE SETTINGS',
          accent: const Color(0xFF7FD8A5),
          onPressed: () => _openSiteSettings(selected),
        ),
      if (widget.onOpenGuardRoster != null)
        _heroActionButton(
          key: const ValueKey('sites-hero-assign-guards-button'),
          icon: Icons.badge_outlined,
          label: 'OPEN GUARD ROSTER',
          accent: const Color(0xFFF6C067),
          onPressed: () => _openGuardRoster(selected),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: OnyxColorTokens.backgroundSecondary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: OnyxColorTokens.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  _siteMetricChip('Focus', selected.id),
                  _siteMetricChip('Strong', '$strongCount'),
                  _siteMetricChip(
                    'Review',
                    '$atRiskCount',
                  ),
                  _siteMetricChip('Guards', '$totalGuards'),
                  _siteMetricChip('Sites', '$totalSites'),
                ],
              ),
              if (heroActions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: heroActions),
              ],
              if (workspaceBanner != null) ...[
                const SizedBox(height: 6),
                workspaceBanner,
              ],
            ],
          ),
        ),
        if (widget.latestAutoAuditReceipt != null) ...[
          const SizedBox(height: 8),
          _SitesAuditReceipt(
            receipt: widget.latestAutoAuditReceipt!,
            onOpenLatestAudit: widget.onOpenLatestAudit,
          ),
        ],
      ],
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
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: accent.withValues(alpha: 0.12),
        foregroundColor: accent,
        side: BorderSide(color: accent.withValues(alpha: 0.28)),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        textStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }

  void _openTacticalForSite(BuildContext context, _SiteViewModel site) {
    final callback = widget.onOpenMapForSite;
    if (callback == null) {
      _showTacticalLinkDialog(context);
      return;
    }
    logUiAction(
      'sites.hero_view_tactical',
      context: <String, Object?>{
        'site_id': site.id,
        'site_name': site.displayName,
      },
    );
    callback(site.id, site.displayName);
  }

  void _showTacticalLinkDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: OnyxColorTokens.backgroundSecondary,
          title: Text(
            'Site Map Ready',
            style: GoogleFonts.inter(
              color: const Color(0xFF172638),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Use Site Map to inspect watch posture, limited coverage, and deployment context for the selected site.',
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

  Widget _rosterPane(
    List<_SiteViewModel> allSites,
    List<_SiteViewModel> visibleSites, {
    bool shellless = false,
  }) {
    final watchingCount = _siteCountForFilter(allSites, _SiteLaneFilter.watch);
    final visibleCount = visibleSites.length;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'SITE ROSTER',
              style: GoogleFonts.inter(
                color: const Color(0xFF7B8FA8),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const Spacer(),
            InkWell(
              key: const ValueKey('sites-add-site-button'),
              borderRadius: BorderRadius.circular(10),
              onTap: widget.onAddSite == null ? null : _openAddSite,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.onAddSite == null
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.onAddSite == null
                        ? OnyxColorTokens.divider
                        : const Color(0x80448FFF),
                  ),
                ),
                child: Text(
                  'OPEN SITE DESK',
                  style: GoogleFonts.inter(
                    color: widget.onAddSite == null
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFFEAF1FB),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
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
            _rosterFilterChip(
              key: const ValueKey('sites-roster-filter-all'),
              label: 'All',
              count: allSites.length,
              selected: _siteLaneFilter == _SiteLaneFilter.all,
              onTap: () => _setSiteLaneFilter(allSites, _SiteLaneFilter.all),
            ),
            _rosterFilterChip(
              key: const ValueKey('sites-roster-filter-healthy'),
              label: 'Healthy',
              count: _siteCountForFilter(allSites, _SiteLaneFilter.healthy),
              selected: _siteLaneFilter == _SiteLaneFilter.healthy,
              onTap: () =>
                  _setSiteLaneFilter(allSites, _SiteLaneFilter.healthy),
            ),
            _rosterFilterChip(
              key: const ValueKey('sites-roster-filter-watch'),
              label: 'Watch',
              count: watchingCount,
              selected: _siteLaneFilter == _SiteLaneFilter.watch,
              onTap: () => _setSiteLaneFilter(allSites, _SiteLaneFilter.watch),
            ),
            _rosterFilterChip(
              key: const ValueKey('sites-roster-filter-strong'),
              label: 'Strong',
              count: _siteCountForFilter(allSites, _SiteLaneFilter.strong),
              selected: _siteLaneFilter == _SiteLaneFilter.strong,
              onTap: () => _setSiteLaneFilter(allSites, _SiteLaneFilter.strong),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: OnyxColorTokens.backgroundSecondary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: OnyxColorTokens.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: _rosterSignal(
                  label: 'WATCH POSTS',
                  value: '$watchingCount',
                  accent: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _rosterSignal(
                  label: 'VISIBLE NOW',
                  value: '$visibleCount',
                  accent: const Color(0xFF38BDF8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (visibleSites.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: OnyxColorTokens.backgroundSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: OnyxColorTokens.divider),
            ),
            child: Text(
              'No sites are currently in this scope. Choose another scope to continue issuing commands.',
              style: GoogleFonts.inter(
                color: const Color(0xFF556B80),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          )
        else
          for (final site in visibleSites) ...[
            _rosterRow(site),
            const SizedBox(height: 5),
          ],
      ],
    );
    if (shellless) {
      return Padding(padding: const EdgeInsets.all(2), child: body);
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: body,
    );
  }

  Widget _rosterRow(_SiteViewModel site) {
    final selected = site.id == _selectedSiteId;
    final status = _statusColor(site.status);
    final guardFill = _percent(site.guardsActive, site.guardsTotal);
    final checkpointFill = _percent(
      site.checkpointsCompleted,
      site.checkpointsTotal,
    );
    return InkWell(
      key: ValueKey('sites-roster-card-${site.id}'),
      onTap: () {
        setState(() => _selectedSiteId = site.id);
        logUiAction(
          'sites.select_site',
          context: {'site_id': site.id, 'site_name': site.displayName},
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? status.withValues(alpha: 0.08)
              : OnyxColorTokens.backgroundSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? status.withValues(alpha: 0.40)
                : OnyxColorTokens.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: status.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    _statusIcon(site.status),
                    color: status,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        site.displayName,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF172638),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        site.location,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF556B80),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        site.id,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF7A8FA4),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                _statusBadge(site.status),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _siteMetricChip(
                  'Guards',
                  '${site.guardsActive}/${site.guardsTotal}',
                ),
                _siteMetricChip('Incidents', '${site.incidentsToday}'),
                _siteMetricChip('Response', '${site.responseRate.round()}%'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _progressMeter(
                    label: 'Coverage',
                    percent: guardFill,
                    color: const Color(0xFF22D3EE),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _progressMeter(
                    label: 'Checkpoints',
                    percent: checkpointFill,
                    color: status,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _workspacePane(
    _SiteViewModel site,
    int visibleSiteCount,
    int totalSiteCount, {
    bool shellless = false,
  }) {
    final guardFill = _percent(site.guardsActive, site.guardsTotal);
    final checkpointFill = _percent(
      site.checkpointsCompleted,
      site.checkpointsTotal,
    );
    final focusCopy = visibleSiteCount == 0
        ? 'No sites match this scope right now. Holding ${site.displayName} in focus so command context stays intact.'
        : '$visibleSiteCount of $totalSiteCount sites are visible in the current scope. ${_siteDirective(site)}';
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 980;
            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SITE DESK',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7B8FA8),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        site.displayName,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF172638),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    _statusBadge(site.status),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${site.location}  •  ${site.id}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF556B80),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _miniButton(
                  'OPEN SITE MAP',
                  key: const ValueKey('sites-view-on-map-button'),
                  primary: true,
                  enabled: widget.onOpenMapForSite != null,
                  onTap: () {
                    logUiAction(
                      'sites.view_on_map',
                      context: {
                        'site_id': site.id,
                        'site_name': site.displayName,
                      },
                    );
                    widget.onOpenMapForSite!.call(site.id, site.displayName);
                  },
                ),
                _miniButton(
                  'OPEN SITE SETTINGS',
                  key: const ValueKey('sites-site-settings-button'),
                  enabled: widget.onOpenSiteSettings != null,
                  onTap: () => _openSiteSettings(site),
                ),
                _miniButton(
                  'OPEN GUARD ROSTER',
                  key: const ValueKey('sites-guard-roster-button'),
                  enabled: widget.onOpenGuardRoster != null,
                  onTap: () => _openGuardRoster(site),
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 8), actions],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: title),
                const SizedBox(width: 7),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 336),
                  child: actions,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _statusColor(site.status).withValues(alpha: 0.14),
                const Color(0xFF1A1A2E),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: OnyxColorTokens.divider),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 920;
              final overview = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Priority',
                    style: GoogleFonts.inter(
                      color: _statusColor(site.status),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _siteNextMoveLabel(site),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF172638),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 0.92,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _siteNextMoveDetail(site),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF556B80),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _siteMetricChip('Focus', _statusLabel(site.status)),
                      _siteMetricChip(
                        'Response',
                        '${site.responseRate.round()}%',
                      ),
                      _siteMetricChip('Coverage', '$guardFill%'),
                      _siteMetricChip('Checkpoints', '$checkpointFill%'),
                    ],
                  ),
                ],
              );
              final directive = Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: OnyxColorTokens.backgroundSecondary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: OnyxColorTokens.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _commandDetailRow(
                      label: 'Scope',
                      value: focusCopy,
                      accent: _statusColor(site.status),
                    ),
                    const SizedBox(height: 6),
                    _commandDetailRow(
                      label: 'Desk View',
                      value: _workspaceViewTitle(_workspaceView),
                      accent: const Color(0xFF38BDF8),
                    ),
                    const SizedBox(height: 6),
                    _commandDetailRow(
                      label: 'Watchline',
                      value: _siteRiskNarrative(site),
                      accent: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              );
              if (compact) {
                return Column(
                  children: [overview, const SizedBox(height: 6), directive],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: overview),
                  const SizedBox(width: 7),
                  Expanded(flex: 4, child: directive),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _workspaceViewChip(
              key: const ValueKey('sites-workspace-view-response'),
              label: 'Response',
              selected: _workspaceView == _SiteWorkspaceView.response,
              onTap: () => _setWorkspaceView(_SiteWorkspaceView.response),
            ),
            _workspaceViewChip(
              key: const ValueKey('sites-workspace-view-coverage'),
              label: 'Coverage',
              selected: _workspaceView == _SiteWorkspaceView.coverage,
              onTap: () => _setWorkspaceView(_SiteWorkspaceView.coverage),
            ),
            _workspaceViewChip(
              key: const ValueKey('sites-workspace-view-checkpoints'),
              label: 'Checkpoints',
              selected: _workspaceView == _SiteWorkspaceView.checkpoints,
              onTap: () => _setWorkspaceView(_SiteWorkspaceView.checkpoints),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final shelllessSections = constraints.maxWidth >= 980;
            return _workspaceDeck(
              site,
              visibleSiteCount,
              totalSiteCount,
              shelllessSections: shelllessSections,
            );
          },
        ),
      ],
    );
    if (shellless) {
      return Padding(padding: const EdgeInsets.all(2), child: body);
    }
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: body,
    );
  }

  Widget _workspaceDeck(
    _SiteViewModel site,
    int visibleSiteCount,
    int totalSiteCount, {
    required bool shelllessSections,
  }) {
    return switch (_workspaceView) {
      _SiteWorkspaceView.response => _responseWorkspace(
        site,
        visibleSiteCount,
        totalSiteCount,
        shelllessSections: shelllessSections,
      ),
      _SiteWorkspaceView.coverage => _coverageWorkspace(
        site,
        visibleSiteCount,
        totalSiteCount,
        shelllessSections: shelllessSections,
      ),
      _SiteWorkspaceView.checkpoints => _checkpointWorkspace(
        site,
        visibleSiteCount,
        totalSiteCount,
        shelllessSections: shelllessSections,
      ),
    };
  }

  Widget _responseWorkspace(
    _SiteViewModel site,
    int visibleSiteCount,
    int totalSiteCount, {
    required bool shelllessSections,
  }) {
    final guardFill = _percent(site.guardsActive, site.guardsTotal);
    final checkpointFill = _percent(
      site.checkpointsCompleted,
      site.checkpointsTotal,
    );
    return Column(
      key: const ValueKey('sites-workspace-panel-response'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _workspaceKpiRow([
          _WorkspaceKpi(
            title: 'ACTIVE GUARDS',
            value: '${site.guardsActive}/${site.guardsTotal}',
            helper: guardFill >= 95 ? 'Full strength' : '$guardFill% staffed',
            helperColor: guardFill >= 95
                ? const Color(0xFF00D084)
                : const Color(0xFFF59E0B),
          ),
          _WorkspaceKpi(
            title: 'INCIDENTS TODAY',
            value: '${site.incidentsToday}',
            helper: 'Last: ${site.lastIncident}',
            helperColor: site.incidentsToday <= 1
                ? const Color(0xFF8EA4C2)
                : const Color(0xFFF59E0B),
          ),
          _WorkspaceKpi(
            title: 'RESPONSE RATE',
            value: '${site.responseRate.toStringAsFixed(0)}%',
            helper: '$visibleSiteCount of $totalSiteCount visible',
            helperColor: const Color(0xFF38BDF8),
          ),
          _WorkspaceKpi(
            title: 'CHECKPOINTS',
            value: '${site.checkpointsCompleted}/${site.checkpointsTotal}',
            helper: '$checkpointFill% complete',
            helperColor: const Color(0xFF8EA4C2),
          ),
        ]),
        const SizedBox(height: 10),
        _workspaceSplitCards(
          left: _panelCard(
            title: 'RESPONSE BOARD',
            shellless: shelllessSections,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _commandDetailRow(
                  label: 'Current posture',
                  value: _siteDirective(site),
                  accent: _statusColor(site.status),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _progressMeter(
                        label: 'Guard fill',
                        percent: guardFill,
                        color: const Color(0xFF22D3EE),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _progressMeter(
                        label: 'Checkpoint closure',
                        percent: checkpointFill,
                        color: _statusColor(site.status),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _siteMetricChip('Visible Sites', '$visibleSiteCount'),
                    _siteMetricChip('Escalations', '${site.mixEscalated}%'),
                    _siteMetricChip(
                      'Resolved On-Site',
                      '${site.mixResolvedOnsite}%',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _siteRiskNarrative(site),
                  style: GoogleFonts.inter(
                    color: const Color(0xFFD6E2F2),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          right: _panelCard(
            title: 'DISPATCH OUTCOME MIX (30 DAYS)',
            shellless: shelllessSections,
            child: Column(
              children: [
                _outcomeBar(
                  'False Alarms',
                  site.mixFalseAlarms,
                  const Color(0xFFF59E0B),
                ),
                const SizedBox(height: 8),
                _outcomeBar(
                  'Resolved On-Site',
                  site.mixResolvedOnsite,
                  const Color(0xFF10B981),
                ),
                const SizedBox(height: 8),
                _outcomeBar(
                  'Escalated to SAPS',
                  site.mixEscalated,
                  const Color(0xFFEF4444),
                ),
                const SizedBox(height: 8),
                _outcomeBar(
                  'Preventative Action',
                  site.mixPreventative,
                  const Color(0xFF22D3EE),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _panelCard(
          title: 'OPERATIONAL PULSE',
          shellless: shelllessSections,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 780;
              final left = _pulseColumn([
                _PulseMetric(
                  'Patrol Coverage',
                  '$guardFill%',
                  guardFill >= 95
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                ),
                _PulseMetric(
                  'Checkpoint Compliance',
                  '$checkpointFill%',
                  checkpointFill >= 95
                      ? const Color(0xFF10B981)
                      : const Color(0xFF38BDF8),
                ),
                _PulseMetric(
                  'Avg Response Tempo',
                  '${(6.4 - (site.responseRate / 100) * 2.1).toStringAsFixed(1)} min',
                  const Color(0xFF38BDF8),
                ),
              ]);
              final right = _pulseColumn([
                _PulseMetric(
                  'Client Confidence',
                  site.incidentsToday >= 3 ? 'Watching' : 'Stable',
                  site.incidentsToday >= 3
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF10B981),
                ),
                _PulseMetric(
                  'Guard Vigilance',
                  _statusLabel(site.status),
                  _statusColor(site.status),
                ),
                _PulseMetric(
                  'Visible Sites',
                  '$visibleSiteCount/$totalSiteCount',
                  const Color(0xFF8EA4C2),
                ),
              ]);
              if (stacked) {
                return Column(
                  children: [left, const SizedBox(height: 8), right],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 18),
                  Expanded(child: right),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _coverageWorkspace(
    _SiteViewModel site,
    int visibleSiteCount,
    int totalSiteCount, {
    required bool shelllessSections,
  }) {
    final guardFill = _percent(site.guardsActive, site.guardsTotal);
    final checkpointFill = _percent(
      site.checkpointsCompleted,
      site.checkpointsTotal,
    );
    final reserveUnits = site.guardsTotal > site.guardsActive
        ? site.guardsTotal - site.guardsActive
        : 0;
    final perimeterCoverage = _boundedPercent(
      ((guardFill + site.responseRate) / 2).round(),
    );
    final accessCoverage = _boundedPercent(checkpointFill + 4);
    final mobileCoverage = _boundedPercent(site.responseRate.round() - 3);
    final reserveCoverage = site.guardsTotal == 0
        ? 0
        : _boundedPercent(((reserveUnits / site.guardsTotal) * 100).round());
    return Column(
      key: const ValueKey('sites-workspace-panel-coverage'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _workspaceKpiRow([
          _WorkspaceKpi(
            title: 'COVERAGE ARC',
            value: '$perimeterCoverage%',
            helper: 'Perimeter stabilized',
            helperColor: const Color(0xFF38BDF8),
          ),
          _WorkspaceKpi(
            title: 'ACTIVE POSTS',
            value: '${site.guardsActive}',
            helper: '${site.guardsTotal} total assigned',
            helperColor: const Color(0xFF8EA4C2),
          ),
          _WorkspaceKpi(
            title: 'MOBILE UNITS',
            value: '${reserveUnits <= 0 ? 1 : reserveUnits}',
            helper: reserveUnits == 0
                ? 'No reserve slack'
                : 'Reserve available',
            helperColor: reserveUnits == 0
                ? const Color(0xFFF59E0B)
                : const Color(0xFF00D084),
          ),
          _WorkspaceKpi(
            title: 'VISIBLE SITES',
            value: '$visibleSiteCount/$totalSiteCount',
            helper: 'Network scope',
            helperColor: const Color(0xFF8EA4C2),
          ),
        ]),
        const SizedBox(height: 10),
        _workspaceSplitCards(
          left: _panelCard(
            title: 'COVERAGE GRID',
            shellless: shelllessSections,
            child: Column(
              children: [
                _progressMeter(
                  label: 'Perimeter watch',
                  percent: perimeterCoverage,
                  color: const Color(0xFF22D3EE),
                ),
                const SizedBox(height: 10),
                _progressMeter(
                  label: 'Access control',
                  percent: accessCoverage,
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(height: 10),
                _progressMeter(
                  label: 'Mobile patrol sweep',
                  percent: mobileCoverage,
                  color: const Color(0xFF38BDF8),
                ),
                const SizedBox(height: 10),
                _progressMeter(
                  label: 'Reserve buffer',
                  percent: reserveCoverage,
                  color: reserveCoverage == 0
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF10B981),
                ),
              ],
            ),
          ),
          right: _panelCard(
            title: 'SHIFT DISTRIBUTION',
            shellless: shelllessSections,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _commandDetailRow(
                  label: 'Primary watch',
                  value:
                      '${site.guardsActive} guards covering the main response ring',
                  accent: const Color(0xFF38BDF8),
                ),
                const SizedBox(height: 10),
                _commandDetailRow(
                  label: 'Pressure point',
                  value: reserveUnits == 0
                      ? 'No spare guard buffer for relief rotation.'
                      : '$reserveUnits reserve guard(s) can reinforce the watchline.',
                  accent: reserveUnits == 0
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF10B981),
                ),
                const SizedBox(height: 10),
                _commandDetailRow(
                  label: 'Coverage note',
                  value: _siteRiskNarrative(site),
                  accent: _statusColor(site.status),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _panelCard(
          title: 'FIELD READINESS',
          shellless: shelllessSections,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 780;
              final left = _pulseColumn([
                _PulseMetric(
                  'Guard Fill',
                  '$guardFill%',
                  guardFill >= 95
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                ),
                _PulseMetric(
                  'Checkpoint Carry',
                  '$checkpointFill%',
                  const Color(0xFF38BDF8),
                ),
                _PulseMetric(
                  'Response Support',
                  reserveUnits == 0 ? 'Tight' : 'Available',
                  reserveUnits == 0
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF10B981),
                ),
              ]);
              final right = _pulseColumn([
                _PulseMetric(
                  'Command Scope',
                  '$visibleSiteCount/$totalSiteCount',
                  const Color(0xFF8EA4C2),
                ),
                _PulseMetric(
                  'Status',
                  _statusLabel(site.status),
                  _statusColor(site.status),
                ),
                _PulseMetric(
                  'Last Incident',
                  site.lastIncident,
                  const Color(0xFFD9E7FA),
                ),
              ]);
              if (stacked) {
                return Column(
                  children: [left, const SizedBox(height: 8), right],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 18),
                  Expanded(child: right),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _checkpointWorkspace(
    _SiteViewModel site,
    int visibleSiteCount,
    int totalSiteCount, {
    required bool shelllessSections,
  }) {
    final checkpointFill = _percent(
      site.checkpointsCompleted,
      site.checkpointsTotal,
    );
    final remainingCheckpoints =
        site.checkpointsTotal > site.checkpointsCompleted
        ? site.checkpointsTotal - site.checkpointsCompleted
        : 0;
    final assuranceScore = _boundedPercent(
      ((checkpointFill + site.responseRate.round()) / 2).round(),
    );
    final exceptionRate = _boundedPercent(100 - checkpointFill);
    return Column(
      key: const ValueKey('sites-workspace-panel-checkpoints'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _workspaceKpiRow([
          _WorkspaceKpi(
            title: 'COMPLETED',
            value: '${site.checkpointsCompleted}',
            helper: '${site.checkpointsTotal} scheduled',
            helperColor: const Color(0xFF8EA4C2),
          ),
          _WorkspaceKpi(
            title: 'REMAINING',
            value: '$remainingCheckpoints',
            helper: remainingCheckpoints == 0
                ? 'No backlog'
                : 'Pending field closeout',
            helperColor: remainingCheckpoints == 0
                ? const Color(0xFF00D084)
                : const Color(0xFFF59E0B),
          ),
          _WorkspaceKpi(
            title: 'ASSURANCE',
            value: '$assuranceScore%',
            helper: '$visibleSiteCount/$totalSiteCount in scope',
            helperColor: const Color(0xFF38BDF8),
          ),
          _WorkspaceKpi(
            title: 'LAST INCIDENT',
            value: site.lastIncident,
            helper: 'Most recent alert',
            helperColor: const Color(0xFF8EA4C2),
          ),
        ]),
        const SizedBox(height: 10),
        _workspaceSplitCards(
          left: _panelCard(
            title: 'CHECKPOINT BOARD',
            shellless: shelllessSections,
            child: Column(
              children: [
                _progressMeter(
                  label: 'Completed route',
                  percent: checkpointFill,
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(height: 10),
                _progressMeter(
                  label: 'Remaining route',
                  percent: exceptionRate,
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(height: 10),
                _progressMeter(
                  label: 'Assurance confidence',
                  percent: assuranceScore,
                  color: const Color(0xFF38BDF8),
                ),
                const SizedBox(height: 12),
                Text(
                  remainingCheckpoints == 0
                      ? 'All checkpoints are closed. Hold the current cadence and keep the watchline in place.'
                      : '$remainingCheckpoints checkpoint(s) still need a physical closeout before the route is considered sealed.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFD6E2F2),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          right: _panelCard(
            title: 'ASSURANCE TRACK',
            shellless: shelllessSections,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _commandDetailRow(
                  label: 'Checkpoint state',
                  value: checkpointFill >= 95
                      ? 'Closed and verified'
                      : 'Active follow-through required',
                  accent: checkpointFill >= 95
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                ),
                const SizedBox(height: 10),
                _commandDetailRow(
                  label: 'Field note',
                  value: _siteRiskNarrative(site),
                  accent: _statusColor(site.status),
                ),
                const SizedBox(height: 10),
                _commandDetailRow(
                  label: 'Checkpoint scope',
                  value:
                      '$visibleSiteCount of $totalSiteCount sites are visible in this checkpoint scope.',
                  accent: const Color(0xFF38BDF8),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _panelCard(
          title: 'FOLLOW-THROUGH',
          shellless: shelllessSections,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 780;
              final left = _pulseColumn([
                _PulseMetric(
                  'Completion',
                  '$checkpointFill%',
                  checkpointFill >= 95
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                ),
                _PulseMetric(
                  'Exceptions',
                  '$exceptionRate%',
                  const Color(0xFFF59E0B),
                ),
                _PulseMetric(
                  'Response Overlay',
                  '${site.responseRate.round()}%',
                  const Color(0xFF38BDF8),
                ),
              ]);
              final right = _pulseColumn([
                _PulseMetric(
                  'Active Site',
                  site.displayName,
                  const Color(0xFFD9E7FA),
                ),
                _PulseMetric(
                  'Status',
                  _statusLabel(site.status),
                  _statusColor(site.status),
                ),
                _PulseMetric(
                  'Visible Scope',
                  '$visibleSiteCount/$totalSiteCount',
                  const Color(0xFF8EA4C2),
                ),
              ]);
              if (stacked) {
                return Column(
                  children: [left, const SizedBox(height: 8), right],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 18),
                  Expanded(child: right),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _workspaceKpiRow(List<_WorkspaceKpi> metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cell = width < 760 ? (width - 6) / 2 : (width - 18) / 4;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final metric in metrics)
              _smallKpiCard(
                width: cell,
                title: metric.title,
                value: metric.value,
                helper: metric.helper,
                helperColor: metric.helperColor,
              ),
          ],
        );
      },
    );
  }

  Widget _workspaceSplitCards({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 980;
        if (stacked) {
          return Column(children: [left, const SizedBox(height: 7), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: left),
            const SizedBox(width: 7),
            Expanded(flex: 4, child: right),
          ],
        );
      },
    );
  }

  Widget _rosterFilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0x1A9D4BFF) : OnyxColorTokens.backgroundSecondary,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF7DB6D1) : OnyxColorTokens.divider,
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
                    : const Color(0xFF556B80),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFD9EEF9)
                    : const Color(0xFFF4F8FC),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  color: const Color(0xFF172638),
                  fontSize: 9.5,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0x1A9D4BFF) : OnyxColorTokens.backgroundSecondary,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF7DB6D1) : OnyxColorTokens.divider,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? const Color(0xFF2F6AA3) : const Color(0xFF556B80),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _rosterSignal({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF6F839C),
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            color: accent,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(_SiteStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _statusLabel(status).toUpperCase(),
        style: GoogleFonts.inter(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _siteMetricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: GoogleFonts.inter(
                color: const Color(0xFF7A8FA4),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: const Color(0xFF172638),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressMeter({
    required String label,
    required int percent,
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
                  color: const Color(0xFF556B80),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: GoogleFonts.inter(
                color: const Color(0xFF172638),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: const Color(0xFFE3EBF3),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }

  Widget _commandDetailRow({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            color: const Color(0xFF6F839C),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            color: const Color(0xFF172638),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 54,
          height: 3,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }

  Widget _workspaceStatusPill({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF172638),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _laneLabel(_SiteLaneFilter filter) {
    return switch (filter) {
      _SiteLaneFilter.all => 'All Sites',
      _SiteLaneFilter.healthy => 'Healthy',
      _SiteLaneFilter.watch => 'Watch',
      _SiteLaneFilter.strong => 'Strong',
    };
  }

  Color _laneAccent(_SiteLaneFilter filter) {
    return switch (filter) {
      _SiteLaneFilter.all => const Color(0xFF63BDFF),
      _SiteLaneFilter.healthy => const Color(0xFF22D3EE),
      _SiteLaneFilter.watch => const Color(0xFFF59E0B),
      _SiteLaneFilter.strong => const Color(0xFF34D399),
    };
  }

  String _workspaceViewTitle(_SiteWorkspaceView view) {
    return switch (view) {
      _SiteWorkspaceView.response => 'Response Board',
      _SiteWorkspaceView.coverage => 'Coverage Grid',
      _SiteWorkspaceView.checkpoints => 'Checkpoint Board',
    };
  }

  String _siteDirective(_SiteViewModel site) {
    return switch (site.status) {
      _SiteStatus.strong =>
        'Hold a steady watchline and preserve rapid-response reserve at ${site.displayName}.',
      _SiteStatus.stable =>
        'Maintain current patrol rhythm and reinforce the next available sweep window.',
      _SiteStatus.atRisk =>
        'Reinforce the active perimeter and tighten supervisor visibility before the next incident cycle.',
      _SiteStatus.critical =>
        'Escalate field oversight immediately and rebalance guard coverage across the exposed site perimeter.',
    };
  }

  String _siteNextMoveLabel(_SiteViewModel site) {
    return switch (site.status) {
      _SiteStatus.strong => 'HOLD THE SITE',
      _SiteStatus.stable => 'KEEP PATROL MOVING',
      _SiteStatus.atRisk => 'CHECK COVERAGE',
      _SiteStatus.critical => 'ESCALATE NOW',
    };
  }

  String _siteNextMoveDetail(_SiteViewModel site) {
    return switch (site.status) {
      _SiteStatus.strong =>
        'Posture is controlled. Keep the watchline clean and preserve the reserve.',
      _SiteStatus.stable =>
        'The site is holding. Keep patrol rhythm tight and stay ahead of the next gap.',
      _SiteStatus.atRisk =>
        'Coverage or checkpoint pressure is building. Open the map or move guards before the next alert.',
      _SiteStatus.critical =>
        'This site needs immediate command attention. Open the map, tighten the scope, and rebalance guard coverage now.',
    };
  }

  String _siteRiskNarrative(_SiteViewModel site) {
    if (site.incidentsToday >= 4) {
      return 'Incident load is elevated today, so the site should stay on a short operational leash until closeout improves.';
    }
    if (site.guardsActive < site.guardsTotal) {
      return 'Guard coverage is below planned strength, which increases response pressure if another alert arrives.';
    }
    if (site.checkpointsCompleted < site.checkpointsTotal) {
      return 'Checkpoint follow-through is still open, so assurance depends on the next patrol loop closing cleanly.';
    }
    return 'Current posture is controlled. Keep the same deployment tempo and continue monitoring the wider site network.';
  }

  String _statusLabel(_SiteStatus status) {
    return switch (status) {
      _SiteStatus.strong => 'Strong',
      _SiteStatus.stable => 'Stable',
      _SiteStatus.atRisk => 'Watch',
      _SiteStatus.critical => 'Critical',
    };
  }

  int _percent(int part, int total) {
    if (total <= 0) {
      return 0;
    }
    return _boundedPercent(((part / total) * 100).round());
  }

  int _boundedPercent(int value) {
    if (value < 0) {
      return 0;
    }
    if (value > 100) {
      return 100;
    }
    return value;
  }

  Widget _miniButton(
    String text, {
    Key? key,
    bool primary = false,
    bool enabled = true,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: enabled
              ? (primary ? const Color(0xFF9D4BFF) : const Color(0xFF1A1A2E))
              : OnyxColorTokens.backgroundSecondary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? (primary ? const Color(0xFF9D4BFF) : const Color(0x269D4BFF))
                : const Color(0x269D4BFF),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: enabled
                ? (primary ? Colors.white : const Color(0xFF9D4BFF))
                : const Color(0x4DFFFFFF),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _smallKpiCard({
    required double width,
    required String title,
    required String value,
    required String helper,
    required Color helperColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(7, 7, 7, 7),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFF7A8FA4),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: GoogleFonts.inter(
              color: const Color(0xFF172638),
              fontSize: 30,
              height: 0.95,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            helper,
            style: GoogleFonts.inter(
              color: helperColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelCard({
    required String title,
    required Widget child,
    bool shellless = false,
  }) {
    if (shellless) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFF7A8FA4),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
          child,
        ],
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFF7A8FA4),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
          child,
        ],
      ),
    );
  }

  Widget _outcomeBar(String label, int percent, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF172638),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '$percent%',
              style: GoogleFonts.inter(
                color: const Color(0xFF172638),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 7,
            child: LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: const Color(0xFFE3EBF3),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pulseColumn(List<_PulseMetric> metrics) {
    return Column(
      children: [
        for (final metric in metrics) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  metric.label,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF556B80),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                metric.value,
                style: GoogleFonts.inter(
                  color: metric.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
        ],
      ],
    );
  }
}

class _SitesAuditReceipt extends StatelessWidget {
  final SitesAutoAuditReceipt receipt;
  final VoidCallback? onOpenLatestAudit;

  const _SitesAuditReceipt({required this.receipt, this.onOpenLatestAudit});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('sites-latest-audit-panel'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LATEST COMMAND',
            style: GoogleFonts.inter(
              color: const Color(0xFF6B7F93),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: receipt.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: receipt.accent.withValues(alpha: 0.45)),
            ),
            child: Text(
              receipt.label,
              style: GoogleFonts.inter(
                color: receipt.accent,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            receipt.headline,
            style: GoogleFonts.inter(
              color: const Color(0xFF172638),
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 0.96,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            receipt.detail,
            style: GoogleFonts.inter(
              color: const Color(0xFF556B80),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          if (onOpenLatestAudit != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('sites-view-latest-audit-button'),
              onPressed: onOpenLatestAudit,
              icon: const Icon(Icons.verified_rounded, size: 16),
              label: const Text('OPEN SIGNED AUDIT'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1C8E60),
                side: const BorderSide(color: Color(0xFF63E6A1)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                textStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PulseMetric {
  final String label;
  final String value;
  final Color color;

  const _PulseMetric(this.label, this.value, this.color);
}

class _WorkspaceKpi {
  final String title;
  final String value;
  final String helper;
  final Color helperColor;

  const _WorkspaceKpi({
    required this.title,
    required this.value,
    required this.helper,
    required this.helperColor,
  });
}

enum _SiteStatus { strong, stable, atRisk, critical }

class _SiteViewModel {
  final String id;
  final String displayName;
  final String location;
  final _SiteStatus status;
  final int guardsActive;
  final int guardsTotal;
  final int incidentsToday;
  final String lastIncident;
  final double responseRate;
  final int checkpointsCompleted;
  final int checkpointsTotal;
  final int mixFalseAlarms;
  final int mixResolvedOnsite;
  final int mixEscalated;
  final int mixPreventative;

  const _SiteViewModel({
    required this.id,
    required this.displayName,
    required this.location,
    required this.status,
    required this.guardsActive,
    required this.guardsTotal,
    required this.incidentsToday,
    required this.lastIncident,
    required this.responseRate,
    required this.checkpointsCompleted,
    required this.checkpointsTotal,
    required this.mixFalseAlarms,
    required this.mixResolvedOnsite,
    required this.mixEscalated,
    required this.mixPreventative,
  });
}

List<_SiteViewModel> _seedSites() {
  return const [
    _SiteViewModel(
      id: 'SITE-001',
      displayName: 'Sandton Estate North',
      location: 'Sandton, Johannesburg',
      status: _SiteStatus.strong,
      guardsActive: 6,
      guardsTotal: 6,
      incidentsToday: 2,
      lastIncident: '22:14',
      responseRate: 98,
      checkpointsCompleted: 48,
      checkpointsTotal: 50,
      mixFalseAlarms: 12,
      mixResolvedOnsite: 68,
      mixEscalated: 8,
      mixPreventative: 12,
    ),
    _SiteViewModel(
      id: 'SITE-002',
      displayName: 'Waterfall Estate Main',
      location: 'Midrand, Gauteng',
      status: _SiteStatus.strong,
      guardsActive: 8,
      guardsTotal: 8,
      incidentsToday: 1,
      lastIncident: '22:08',
      responseRate: 100,
      checkpointsCompleted: 64,
      checkpointsTotal: 64,
      mixFalseAlarms: 10,
      mixResolvedOnsite: 70,
      mixEscalated: 7,
      mixPreventative: 13,
    ),
    _SiteViewModel(
      id: 'SITE-003',
      displayName: 'Blue Ridge Security',
      location: 'Centurion, Gauteng',
      status: _SiteStatus.atRisk,
      guardsActive: 3,
      guardsTotal: 4,
      incidentsToday: 4,
      lastIncident: '21:56',
      responseRate: 85,
      checkpointsCompleted: 28,
      checkpointsTotal: 32,
      mixFalseAlarms: 16,
      mixResolvedOnsite: 59,
      mixEscalated: 11,
      mixPreventative: 14,
    ),
    _SiteViewModel(
      id: 'SITE-004',
      displayName: 'Midrand Industrial Park',
      location: 'Midrand, Gauteng',
      status: _SiteStatus.stable,
      guardsActive: 4,
      guardsTotal: 5,
      incidentsToday: 1,
      lastIncident: '21:45',
      responseRate: 92,
      checkpointsCompleted: 38,
      checkpointsTotal: 40,
      mixFalseAlarms: 13,
      mixResolvedOnsite: 66,
      mixEscalated: 8,
      mixPreventative: 13,
    ),
  ];
}

List<_SiteViewModel> _siteRowsFromEvents(List<DispatchEvent> events) {
  final bySite = <String, List<DispatchEvent>>{};
  for (final event in events) {
    bySite.putIfAbsent(_eventSiteId(event), () => <DispatchEvent>[]).add(event);
  }
  if (bySite.isEmpty) {
    return const [];
  }

  final rows = <_SiteViewModel>[];
  for (final entry in bySite.entries) {
    final siteEvents = [...entry.value]
      ..sort((a, b) => b.sequence.compareTo(a.sequence));
    final first = siteEvents.first;

    final guards = <String>{
      for (final event in siteEvents)
        if (event is GuardCheckedIn)
          event.guardId
        else if (event is ResponseArrived)
          event.guardId
        else if (event is PatrolCompleted)
          event.guardId,
    }..removeWhere((id) => id.trim().isEmpty);

    final decisions = siteEvents.whereType<DecisionCreated>().length;
    final denied = siteEvents.whereType<ExecutionDenied>().length;
    final closed = siteEvents.whereType<IncidentClosed>().length;
    final incidentsToday = decisions + denied + closed;

    final executed = siteEvents
        .whereType<ExecutionCompleted>()
        .where((event) => event.success)
        .length;
    final totalDispatches = decisions <= 0 ? 1 : decisions;
    final responseRate = ((executed / totalDispatches) * 100)
        .clamp(0, 100)
        .toDouble();

    final status = responseRate >= 95
        ? _SiteStatus.strong
        : responseRate >= 85
        ? _SiteStatus.stable
        : responseRate >= 70
        ? _SiteStatus.atRisk
        : _SiteStatus.critical;

    final falseAlarms = totalDispatches == 0
        ? 0
        : ((denied / totalDispatches) * 100).round().clamp(0, 100);
    final resolved = totalDispatches == 0
        ? 0
        : ((executed / totalDispatches) * 100).round().clamp(0, 100);
    final escalated = (incidentsToday > 0 ? 8 : 0).clamp(0, 100);
    final preventative = (100 - falseAlarms - resolved - escalated).clamp(
      0,
      100,
    );

    final checkpointsCompleted = siteEvents.whereType<GuardCheckedIn>().length;
    final checkpointsTotal = checkpointsCompleted == 0
        ? 1
        : checkpointsCompleted + 2;

    rows.add(
      _SiteViewModel(
        id: _eventSiteId(first),
        displayName: _humanizeSiteName(_eventSiteId(first)),
        location: _humanizeLocation(_eventRegionId(first)),
        status: status,
        guardsActive: guards.isEmpty ? 1 : guards.length,
        guardsTotal: guards.isEmpty ? 1 : guards.length,
        incidentsToday: incidentsToday,
        lastIncident: _hhmm(siteEvents.first.occurredAt),
        responseRate: responseRate,
        checkpointsCompleted: checkpointsCompleted,
        checkpointsTotal: checkpointsTotal,
        mixFalseAlarms: falseAlarms,
        mixResolvedOnsite: resolved,
        mixEscalated: escalated,
        mixPreventative: preventative,
      ),
    );
  }

  rows.sort((a, b) => a.id.compareTo(b.id));
  return rows;
}

Color _statusColor(_SiteStatus status) {
  return switch (status) {
    _SiteStatus.strong => const Color(0xFF10B981),
    _SiteStatus.stable => const Color(0xFF06B6D4),
    _SiteStatus.atRisk => const Color(0xFFF59E0B),
    _SiteStatus.critical => const Color(0xFFEF4444),
  };
}

IconData _statusIcon(_SiteStatus status) {
  return switch (status) {
    _SiteStatus.strong => Icons.check_circle_outline_rounded,
    _SiteStatus.stable => Icons.show_chart_rounded,
    _SiteStatus.atRisk => Icons.warning_amber_rounded,
    _SiteStatus.critical => Icons.report_gmailerrorred_rounded,
  };
}

String _eventSiteId(DispatchEvent event) {
  if (event is DecisionCreated) return event.siteId;
  if (event is ExecutionCompleted) return event.siteId;
  if (event is ExecutionDenied) return event.siteId;
  if (event is GuardCheckedIn) return event.siteId;
  if (event is PatrolCompleted) return event.siteId;
  if (event is ResponseArrived) return event.siteId;
  if (event is IncidentClosed) return event.siteId;
  return 'SITE-UNKNOWN';
}

String _eventRegionId(DispatchEvent event) {
  if (event is DecisionCreated) return event.regionId;
  if (event is ExecutionCompleted) return event.regionId;
  if (event is ExecutionDenied) return event.regionId;
  if (event is GuardCheckedIn) return event.regionId;
  if (event is PatrolCompleted) return event.regionId;
  if (event is ResponseArrived) return event.regionId;
  if (event is IncidentClosed) return event.regionId;
  return 'REGION-UNKNOWN';
}

String _hhmm(DateTime value) {
  final utc = value.toUtc();
  final hh = utc.hour.toString().padLeft(2, '0');
  final mm = utc.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

String _humanizeSiteName(String siteId) {
  final clean = siteId.replaceAll('_', '-');
  final stripped = clean.replaceFirst(RegExp(r'^SITE-'), '');
  final words = stripped
      .split('-')
      .where((segment) => segment.trim().isNotEmpty)
      .map((segment) {
        final lower = segment.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .toList(growable: false);
  if (words.isEmpty) {
    return siteId;
  }
  return words.join(' ');
}

String _humanizeLocation(String regionId) {
  final clean = regionId.replaceAll('_', '-');
  final stripped = clean.replaceFirst(RegExp(r'^REGION-'), '');
  final words = stripped
      .split('-')
      .where((segment) => segment.trim().isNotEmpty)
      .map((segment) {
        final lower = segment.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
  if (words.isEmpty) {
    return regionId;
  }
  return '$words, Gauteng';
}
