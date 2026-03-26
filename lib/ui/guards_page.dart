import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/events/dispatch_event.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'ui_action_logger.dart';

enum _GuardStatus { onDuty, offDuty, onBreak, offline }

enum _ShiftChangeType { clockIn, clockOut, breakStart, breakEnd }

enum _GuardContactMode { call, message }

enum _GuardLaneFilter { all, deployed, attention, reserve }

enum _GuardWorkspaceView { command, readiness, trace }

class _GuardRecord {
  final String id;
  final String name;
  final String employeeId;
  final _GuardStatus status;
  final String site;
  final String siteId;
  final String shiftStart;
  final String shiftEnd;
  final String? clockInTime;
  final bool clockInPhotoVerified;
  final String lastHeartbeat;
  final double lat;
  final double lng;
  final String locationAccuracy;
  final int battery;
  final int signalStrength;
  final int obEntries;
  final int incidents;
  final int patrols;
  final int compliance;
  final List<String> certifications;
  final String emergencyContact;

  const _GuardRecord({
    required this.id,
    required this.name,
    required this.employeeId,
    required this.status,
    required this.site,
    required this.siteId,
    required this.shiftStart,
    required this.shiftEnd,
    this.clockInTime,
    required this.clockInPhotoVerified,
    required this.lastHeartbeat,
    required this.lat,
    required this.lng,
    required this.locationAccuracy,
    required this.battery,
    required this.signalStrength,
    required this.obEntries,
    required this.incidents,
    required this.patrols,
    required this.compliance,
    required this.certifications,
    required this.emergencyContact,
  });
}

class _ShiftChangeRecord {
  final String guardId;
  final String guardName;
  final _ShiftChangeType type;
  final String site;
  final String timestamp;
  final bool photoVerified;
  final String location;
  final bool verified;

  const _ShiftChangeRecord({
    required this.guardId,
    required this.guardName,
    required this.type,
    required this.site,
    required this.timestamp,
    required this.photoVerified,
    required this.location,
    required this.verified,
  });
}

class _GuardCommandReceipt {
  final String label;
  final String headline;
  final String detail;
  final Color accent;

  const _GuardCommandReceipt({
    required this.label,
    required this.headline,
    required this.detail,
    required this.accent,
  });
}

class GuardsPage extends StatefulWidget {
  final List<DispatchEvent> events;
  final String initialSiteFilter;
  final VoidCallback? onOpenGuardSchedule;
  final ValueChanged<String>? onOpenGuardReportsForSite;
  final ValueChanged<String>? onOpenClientLaneForSite;
  final Future<String> Function(
    String guardId,
    String guardName,
    String siteId,
    String phone,
  )?
  onStageGuardVoipCall;

  const GuardsPage({
    super.key,
    required this.events,
    this.initialSiteFilter = 'ALL',
    this.onOpenGuardSchedule,
    this.onOpenGuardReportsForSite,
    this.onOpenClientLaneForSite,
    this.onStageGuardVoipCall,
  });

  @override
  State<GuardsPage> createState() => _GuardsPageState();
}

class _GuardsPageState extends State<GuardsPage> {
  static const _defaultCommandReceipt = _GuardCommandReceipt(
    label: 'ACTIVITY RAIL',
    headline: 'Guard workspace ready',
    detail:
        'Contact handoffs, workforce trace, and route-level actions stay visible in the activity rail.',
    accent: Color(0xFF63BDFF),
  );
  static const List<_GuardRecord> _guards = [
    _GuardRecord(
      id: 'GRD-441',
      name: 'Thabo Mokoena',
      employeeId: 'EMP-441',
      status: _GuardStatus.onDuty,
      site: 'Waterfall Estate Main',
      siteId: 'WTF-MAIN',
      shiftStart: '18:00',
      shiftEnd: '06:00',
      clockInTime: '17:52',
      clockInPhotoVerified: true,
      lastHeartbeat: '2s ago',
      lat: -26.0285,
      lng: 28.1122,
      locationAccuracy: '4m',
      battery: 87,
      signalStrength: 94,
      obEntries: 14,
      incidents: 2,
      patrols: 8,
      compliance: 98,
      certifications: ['PSIRA', 'Armed Response', 'First Aid'],
      emergencyContact: '+27 82 555 0441',
    ),
    _GuardRecord(
      id: 'GRD-442',
      name: 'Sipho Ndlovu',
      employeeId: 'EMP-442',
      status: _GuardStatus.onDuty,
      site: 'Blue Ridge Security',
      siteId: 'BLR-MAIN',
      shiftStart: '18:00',
      shiftEnd: '06:00',
      clockInTime: '17:55',
      clockInPhotoVerified: true,
      lastHeartbeat: '5s ago',
      lat: -26.1234,
      lng: 28.0567,
      locationAccuracy: '6m',
      battery: 92,
      signalStrength: 88,
      obEntries: 18,
      incidents: 3,
      patrols: 12,
      compliance: 96,
      certifications: ['PSIRA', 'Armed Response', 'Fire Safety'],
      emergencyContact: '+27 83 444 0442',
    ),
    _GuardRecord(
      id: 'GRD-443',
      name: 'Nomsa Khumalo',
      employeeId: 'EMP-443',
      status: _GuardStatus.onBreak,
      site: 'Sandton Estate North',
      siteId: 'SDN-NORTH',
      shiftStart: '06:00',
      shiftEnd: '18:00',
      clockInTime: '05:58',
      clockInPhotoVerified: false,
      lastHeartbeat: '12s ago',
      lat: -26.0789,
      lng: 28.0456,
      locationAccuracy: '8m',
      battery: 64,
      signalStrength: 76,
      obEntries: 22,
      incidents: 1,
      patrols: 15,
      compliance: 99,
      certifications: ['PSIRA', 'First Aid', 'CPR'],
      emergencyContact: '+27 84 333 0443',
    ),
    _GuardRecord(
      id: 'GRD-444',
      name: 'Johan van Zyl',
      employeeId: 'EMP-444',
      status: _GuardStatus.onDuty,
      site: 'Centurion Tech Park',
      siteId: 'CNT-TECH',
      shiftStart: '06:00',
      shiftEnd: '18:00',
      clockInTime: '06:02',
      clockInPhotoVerified: false,
      lastHeartbeat: '3s ago',
      lat: -25.8612,
      lng: 28.1890,
      locationAccuracy: '5m',
      battery: 78,
      signalStrength: 91,
      obEntries: 16,
      incidents: 4,
      patrols: 10,
      compliance: 94,
      certifications: ['PSIRA', 'Armed Response', 'Advanced Driving'],
      emergencyContact: '+27 81 222 0444',
    ),
    _GuardRecord(
      id: 'GRD-445',
      name: 'Zanele Dube',
      employeeId: 'EMP-445',
      status: _GuardStatus.offDuty,
      site: 'Rosebank Complex',
      siteId: 'RSB-CMPLX',
      shiftStart: '18:00',
      shiftEnd: '06:00',
      clockInTime: null,
      clockInPhotoVerified: false,
      lastHeartbeat: '4h ago',
      lat: -26.1445,
      lng: 28.0426,
      locationAccuracy: 'N/A',
      battery: 0,
      signalStrength: 0,
      obEntries: 20,
      incidents: 2,
      patrols: 14,
      compliance: 97,
      certifications: ['PSIRA', 'First Aid'],
      emergencyContact: '+27 82 111 0445',
    ),
    _GuardRecord(
      id: 'GRD-446',
      name: 'Michael Botha',
      employeeId: 'EMP-446',
      status: _GuardStatus.onDuty,
      site: 'Midrand Business Park',
      siteId: 'MDR-BIZ',
      shiftStart: '18:00',
      shiftEnd: '06:00',
      clockInTime: '17:58',
      clockInPhotoVerified: false,
      lastHeartbeat: '8s ago',
      lat: -25.9956,
      lng: 28.1234,
      locationAccuracy: '7m',
      battery: 81,
      signalStrength: 85,
      obEntries: 12,
      incidents: 5,
      patrols: 9,
      compliance: 91,
      certifications: ['PSIRA', 'Armed Response', 'K9 Handler'],
      emergencyContact: '+27 83 999 0446',
    ),
    _GuardRecord(
      id: 'GRD-447',
      name: 'Precious Sithole',
      employeeId: 'EMP-447',
      status: _GuardStatus.offline,
      site: 'Hyde Park Estate',
      siteId: 'HYD-EST',
      shiftStart: '06:00',
      shiftEnd: '18:00',
      clockInTime: '06:01',
      clockInPhotoVerified: false,
      lastHeartbeat: '8m ago',
      lat: -26.1123,
      lng: 28.0445,
      locationAccuracy: 'N/A',
      battery: 12,
      signalStrength: 0,
      obEntries: 19,
      incidents: 1,
      patrols: 13,
      compliance: 95,
      certifications: ['PSIRA', 'First Aid'],
      emergencyContact: '+27 84 777 0447',
    ),
  ];

  static const List<_ShiftChangeRecord> _recentShiftChanges = [
    _ShiftChangeRecord(
      guardId: 'GRD-444',
      guardName: 'Johan van Zyl',
      type: _ShiftChangeType.clockIn,
      site: 'Centurion Tech Park',
      timestamp: '06:02',
      photoVerified: true,
      location: 'On-site verified',
      verified: true,
    ),
    _ShiftChangeRecord(
      guardId: 'GRD-441',
      guardName: 'Thabo Mokoena',
      type: _ShiftChangeType.clockIn,
      site: 'Waterfall Estate Main',
      timestamp: '17:52',
      photoVerified: true,
      location: 'On-site verified',
      verified: true,
    ),
    _ShiftChangeRecord(
      guardId: 'GRD-442',
      guardName: 'Sipho Ndlovu',
      type: _ShiftChangeType.clockIn,
      site: 'Blue Ridge Security',
      timestamp: '17:55',
      photoVerified: true,
      location: 'On-site verified',
      verified: true,
    ),
    _ShiftChangeRecord(
      guardId: 'GRD-443',
      guardName: 'Nomsa Khumalo',
      type: _ShiftChangeType.breakStart,
      site: 'Sandton Estate North',
      timestamp: '12:15',
      photoVerified: false,
      location: 'Break room verified',
      verified: true,
    ),
    _ShiftChangeRecord(
      guardId: 'GRD-446',
      guardName: 'Michael Botha',
      type: _ShiftChangeType.clockIn,
      site: 'Midrand Business Park',
      timestamp: '17:58',
      photoVerified: true,
      location: 'On-site verified',
      verified: true,
    ),
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  String _siteFilter = 'ALL';
  _GuardLaneFilter _laneFilter = _GuardLaneFilter.all;
  _GuardWorkspaceView _workspaceView = _GuardWorkspaceView.command;
  String _selectedGuardId = 'GRD-441';
  _GuardCommandReceipt _commandReceipt = _defaultCommandReceipt;
  bool _desktopWorkspaceActive = false;

  @override
  void initState() {
    super.initState();
    _siteFilter = _resolveSiteFilter(widget.initialSiteFilter);
  }

  @override
  void didUpdateWidget(covariant GuardsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSiteFilter != widget.initialSiteFilter) {
      _siteFilter = _resolveSiteFilter(widget.initialSiteFilter);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredGuards();
    final laneFiltered = filtered
        .where((guard) => _matchesLaneFilter(guard, _laneFilter))
        .toList(growable: false);
    final selected = _selectedGuard(laneFiltered);
    final sites = _siteOptions();
    final headerGuard = selected ?? _selectedGuard(filtered) ?? _guards.first;

    final onDutyCount = _guards
        .where((guard) => guard.status == _GuardStatus.onDuty)
        .length;
    final offDutyCount = _guards
        .where((guard) => guard.status == _GuardStatus.offDuty)
        .length;
    final onBreakCount = _guards
        .where((guard) => guard.status == _GuardStatus.onBreak)
        .length;
    final offlineCount = _guards
        .where((guard) => guard.status == _GuardStatus.offline)
        .length;

    final wide = allowEmbeddedPanelScroll(context);
    _desktopWorkspaceActive = wide;
    const contentPadding = EdgeInsets.fromLTRB(10, 10, 10, 12);

    Widget buildWorkspacePanels({required bool embedScroll}) {
      if (wide) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (embedScroll)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _guardListPanel(
                        guards: laneFiltered,
                        scopedGuards: filtered,
                        siteOptions: sites,
                        embedScroll: true,
                        shellless: true,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 6,
                      child: _guardDetailPanel(
                        guard: selected,
                        scopedGuards: filtered,
                        embedScroll: true,
                        shellless: true,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 4,
                      child: _activityPanel(
                        guard: selected,
                        scopedGuards: filtered,
                        embedScroll: true,
                        shellless: true,
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _guardListPanel(
                      guards: laneFiltered,
                      scopedGuards: filtered,
                      siteOptions: sites,
                      shellless: true,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 6,
                    child: _guardDetailPanel(
                      guard: selected,
                      scopedGuards: filtered,
                      shellless: true,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: _activityPanel(
                      guard: selected,
                      scopedGuards: filtered,
                      shellless: true,
                    ),
                  ),
                ],
              ),
          ],
        );
      }

      return Column(
        children: [
          _guardListPanel(
            guards: laneFiltered,
            scopedGuards: filtered,
            siteOptions: sites,
          ),
          const SizedBox(height: 8),
          _guardDetailPanel(guard: selected, scopedGuards: filtered),
          const SizedBox(height: 8),
          _activityPanel(guard: selected, scopedGuards: filtered),
        ],
      );
    }

    Widget buildSurfaceBody({required bool embedScroll}) {
      final content = <Widget>[
        _workforceSummaryBar(
          onDutyCount: onDutyCount,
          offlineCount: offlineCount,
          activeSiteCount: sites.length - 1,
        ),
        const SizedBox(height: 8),
        _overviewGrid(
          selectedGuard: headerGuard,
          onDutyCount: onDutyCount,
          offlineCount: offlineCount,
        ),
        if (!wide) ...[const SizedBox(height: 8), _header(headerGuard)],
        const SizedBox(height: 8),
      ];

      if (embedScroll) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...content,
            Expanded(child: buildWorkspacePanels(embedScroll: true)),
            const SizedBox(height: 8),
            _kpis(
              onDutyCount: onDutyCount,
              offDutyCount: offDutyCount,
              onBreakCount: onBreakCount,
              offlineCount: offlineCount,
            ),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...content,
          buildWorkspacePanels(embedScroll: false),
          const SizedBox(height: 8),
          _kpis(
            onDutyCount: onDutyCount,
            offDutyCount: offDutyCount,
            onBreakCount: onBreakCount,
            offlineCount: offlineCount,
          ),
        ],
      );
    }

    return OnyxPageScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boundedDesktopSurface =
              wide &&
              constraints.hasBoundedHeight &&
              constraints.maxHeight.isFinite;
          final ultrawideSurface = isUltrawideLayout(
            context,
            viewportWidth: constraints.maxWidth,
          );
          final widescreenSurface = isWidescreenLayout(
            context,
            viewportWidth: constraints.maxWidth,
          );
          final surfaceMaxWidth = ultrawideSurface
              ? constraints.maxWidth
              : widescreenSurface
              ? constraints.maxWidth * 0.94
              : 1500.0;
          return OnyxViewportWorkspaceLayout(
            padding: contentPadding,
            maxWidth: surfaceMaxWidth,
            lockToViewport: boundedDesktopSurface,
            spacing: 6,
            header: _heroHeader(
              selectedGuard: headerGuard,
              onDutyCount: onDutyCount,
              workspaceBanner: wide
                  ? _workspaceStatusBanner(
                      context: context,
                      selectedGuard: headerGuard,
                      visibleGuards: laneFiltered,
                      scopedGuards: filtered,
                      shellless: true,
                    )
                  : null,
            ),
            body: buildSurfaceBody(embedScroll: boundedDesktopSurface),
          );
        },
      ),
    );
  }

  Widget _workspaceStatusBanner({
    required BuildContext context,
    required _GuardRecord selectedGuard,
    required List<_GuardRecord> visibleGuards,
    required List<_GuardRecord> scopedGuards,
    bool shellless = false,
  }) {
    final attentionCount = _laneCountForFilter(
      scopedGuards,
      _GuardLaneFilter.attention,
    );
    final deployedCount = _laneCountForFilter(
      scopedGuards,
      _GuardLaneFilter.deployed,
    );
    final reserveCount = _laneCountForFilter(
      scopedGuards,
      _GuardLaneFilter.reserve,
    );
    final siteLabel = _siteFilter == 'ALL' ? 'All Sites' : _siteFilter;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _statusPill(
              icon: Icons.group_outlined,
              label: '${visibleGuards.length} Visible',
              accent: const Color(0xFF63BDFF),
            ),
            _statusPill(
              icon: Icons.tune_rounded,
              label: 'Lane ${_laneLabel(_laneFilter)}',
              accent: _laneAccent(_laneFilter),
            ),
            _statusPill(
              icon: Icons.dashboard_customize_outlined,
              label: 'View ${_workspaceLabel(_workspaceView)}',
              accent: _workspaceAccent(_workspaceView),
            ),
            _statusPill(
              icon: Icons.person_outline_rounded,
              label: 'Focus ${selectedGuard.employeeId}',
              accent: const Color(0xFFF6C067),
            ),
            _statusPill(
              icon: Icons.location_on_outlined,
              label: siteLabel,
              accent: const Color(0xFFA78BFA),
            ),
            _statusPill(
              icon: Icons.warning_amber_rounded,
              label: '$attentionCount Attention',
              accent: attentionCount > 0
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF94A3B8),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Deployed $deployedCount • Reserve $reserveCount • Attention $attentionCount. Selected scope stays anchored to ${selectedGuard.name} at ${selectedGuard.site}. Lane pivots, workspace views, reports, and schedule actions stay pinned in the focused boards below.',
          style: GoogleFonts.inter(
            color: const Color(0xFF9AB1CF),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ],
    );
    if (shellless) {
      return KeyedSubtree(
        key: const ValueKey('guards-workspace-status-banner'),
        child: content,
      );
    }
    return Container(
      key: const ValueKey('guards-workspace-status-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: content,
    );
  }

  Widget _workspaceBannerAction({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: onTap == null
              ? const Color(0xFF111827)
              : selected
              ? accent.withValues(alpha: 0.16)
              : const Color(0xFF131B24),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: onTap == null
                ? const Color(0x332B425F)
                : selected
                ? accent.withValues(alpha: 0.46)
                : const Color(0x332B425F),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: onTap == null
                ? const Color(0xFF6C829D)
                : selected
                ? accent
                : const Color(0xFFEAF4FF),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _heroHeader({
    required _GuardRecord selectedGuard,
    required int onDutyCount,
    Widget? workspaceBanner,
  }) {
    return OnyxStoryHero(
      eyebrow: 'WORKFORCE',
      title: 'Guards & Workforce',
      subtitle:
          'See who is on duty, who needs follow-up, and what is affecting patrol flow right now.',
      icon: Icons.groups_rounded,
      gradientColors: const [Color(0xFF2C1B12), Color(0xFF1B1110)],
      metrics: [
        OnyxStoryMetric(
          value: '$onDutyCount',
          label: 'on duty',
          foreground: const Color(0xFF34D399),
          background: const Color(0x1A34D399),
          border: const Color(0x6634D399),
        ),
        OnyxStoryMetric(
          value: selectedGuard.employeeId,
          label: 'focus',
          foreground: const Color(0xFFEAF4FF),
          background: const Color(0x14000000),
          border: const Color(0x335B3021),
        ),
        OnyxStoryMetric(
          value: selectedGuard.siteId,
          label: 'site',
          foreground: const Color(0xFF8FD1FF),
          background: const Color(0x1A8FD1FF),
          border: const Color(0x668FD1FF),
        ),
        OnyxStoryMetric(
          value: selectedGuard.lastHeartbeat,
          label: 'sync',
          foreground: const Color(0xFFF59E0B),
          background: const Color(0x1AF59E0B),
          border: const Color(0x66F59E0B),
        ),
      ],
      actions: [
        _heroActionButton(
          key: const ValueKey('guards-view-reports-button'),
          icon: Icons.open_in_new,
          label: 'View Reports',
          accent: const Color(0xFF93C5FD),
          onPressed: () => _openReportsForSite(context, selectedGuard),
        ),
      ],
      banner: workspaceBanner,
    );
  }

  Widget _heroChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x14000000),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x33000000)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: const Color(0xFFE8F1FF),
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _workspaceCommandReceipt(_GuardRecord? focusGuard) {
    final receipt = _commandReceipt;
    final defaultDetail = focusGuard == null
        ? _defaultCommandReceipt.detail
        : 'Selected scope stays anchored to ${focusGuard.name} at ${focusGuard.site} while command actions remain in view.';
    final detail = receipt == _defaultCommandReceipt
        ? defaultDetail
        : receipt.detail;
    return Container(
      key: const ValueKey('guards-workspace-command-receipt'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: receipt.accent.withValues(alpha: 0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LATEST COMMAND',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: receipt.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: receipt.accent.withValues(alpha: 0.45)),
            ),
            child: Text(
              receipt.label,
              style: GoogleFonts.inter(
                color: receipt.accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            receipt.headline,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFEAF4FF),
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
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
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: accent.withValues(alpha: 0.12),
        foregroundColor: accent,
        side: BorderSide(color: accent.withValues(alpha: 0.28)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _workforceSummaryBar({
    required int onDutyCount,
    required int offlineCount,
    required int activeSiteCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF151619),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3D2A24)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'WORKFORCE STATUS',
            style: GoogleFonts.inter(
              color: const Color(0x669BB0CE),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          _statusPill(
            icon: Icons.check_circle_outline,
            label: '$onDutyCount On Duty',
            accent: const Color(0xFF34D399),
          ),
          _statusPill(
            icon: Icons.location_city_outlined,
            label: '$activeSiteCount Sites',
            accent: const Color(0xFF63BDFF),
          ),
          _statusPill(
            icon: Icons.wifi_off_rounded,
            label: '$offlineCount Sync Issues',
            accent: const Color(0xFFF6C067),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewGrid({
    required _GuardRecord selectedGuard,
    required int onDutyCount,
    required int offlineCount,
  }) {
    return LayoutBuilder(
      builder: (layoutContext, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 4
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        final aspectRatio = columns == 4
            ? 2.7
            : columns == 2
            ? 2.45
            : 1.85;
        return GridView.count(
          key: const ValueKey('guards-overview-grid'),
          crossAxisCount: columns,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: aspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _overviewCard(
              title: 'On Duty',
              value: '$onDutyCount',
              detail:
                  'Active field roster currently available across visible sites.',
              icon: Icons.shield_outlined,
              accent: const Color(0xFF34D399),
            ),
            _overviewCard(
              title: 'Sync Issues',
              value: '$offlineCount',
              detail:
                  'Guards needing follow-up for heartbeat, sync, or device state.',
              icon: Icons.wifi_off_rounded,
              accent: const Color(0xFFF6C067),
            ),
            _selectedGuardOverviewCard(
              layoutContext,
              selectedGuard: selectedGuard,
            ),
            _overviewCard(
              title: 'Primary Site',
              value: selectedGuard.siteId,
              detail:
                  '${selectedGuard.site} is the current field deployment focus.',
              icon: Icons.location_on_outlined,
              accent: const Color(0xFFA78BFA),
            ),
          ],
        );
      },
    );
  }

  Widget _selectedGuardOverviewCard(
    BuildContext context, {
    required _GuardRecord selectedGuard,
  }) {
    final statusStyle = _statusStyle(selectedGuard.status);
    final laneAction =
        _guardNeedsAttention(selectedGuard) &&
            _laneFilter != _GuardLaneFilter.attention
        ? _GuardLaneFilter.attention
        : (selectedGuard.status == _GuardStatus.onDuty ||
                  selectedGuard.status == _GuardStatus.onBreak) &&
              _laneFilter != _GuardLaneFilter.deployed
        ? _GuardLaneFilter.deployed
        : selectedGuard.status == _GuardStatus.offDuty &&
              _laneFilter != _GuardLaneFilter.reserve
        ? _GuardLaneFilter.reserve
        : _laneFilter != _GuardLaneFilter.all
        ? _GuardLaneFilter.all
        : null;
    final laneActionLabel = switch (laneAction) {
      _GuardLaneFilter.attention => 'Attention Lane',
      _GuardLaneFilter.deployed => 'Deployed Lane',
      _GuardLaneFilter.reserve => 'Reserve Lane',
      _GuardLaneFilter.all => 'All Guards',
      null => null,
    };
    final directive = _guardNeedsAttention(selectedGuard)
        ? _attentionReason(selectedGuard)
        : '${selectedGuard.shiftStart} - ${selectedGuard.shiftEnd} remains anchored at ${selectedGuard.site} while sync last landed ${selectedGuard.lastHeartbeat}.';

    return Container(
      key: const ValueKey('guards-overview-selected-card'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusStyle.foreground.withValues(alpha: 0.16),
            const Color(0xFF101A2B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusStyle.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: statusStyle.foreground.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.badge_outlined,
                    color: statusStyle.foreground,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GUARD IN FOCUS',
                        style: GoogleFonts.inter(
                          color: statusStyle.foreground,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Selected Guard',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF8EA4C2),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusChip(statusStyle),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              selectedGuard.employeeId,
              style: GoogleFonts.rajdhani(
                color: const Color(0xFFF4F8FF),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${selectedGuard.name} stays pinned while ${_workspaceLabel(_workspaceView).toLowerCase()} remains live for ${selectedGuard.siteId}.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: const Color(0xFFD5E1F2),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                _heroChip('Site', selectedGuard.siteId),
                _heroChip('Battery', '${selectedGuard.battery}%'),
                _heroChip('Signal', '${selectedGuard.signalStrength}%'),
                _heroChip('Compliance', '${selectedGuard.compliance}%'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              directive,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: const Color(0xFF9AB1CF),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                if (laneAction != null && laneActionLabel != null)
                  _workspaceBannerAction(
                    key: const ValueKey('guards-overview-selected-open-lane'),
                    label: laneActionLabel,
                    selected: false,
                    accent: _laneAccent(laneAction),
                    onTap: () => _setRosterLane(laneAction),
                  ),
                _workspaceBannerAction(
                  key: const ValueKey('guards-overview-selected-open-command'),
                  label: 'Command',
                  selected: _workspaceView == _GuardWorkspaceView.command,
                  accent: _workspaceAccent(_GuardWorkspaceView.command),
                  onTap: () => _setWorkspaceView(_GuardWorkspaceView.command),
                ),
                _workspaceBannerAction(
                  key: const ValueKey(
                    'guards-overview-selected-open-readiness',
                  ),
                  label: 'Readiness',
                  selected: _workspaceView == _GuardWorkspaceView.readiness,
                  accent: _workspaceAccent(_GuardWorkspaceView.readiness),
                  onTap: () => _setWorkspaceView(_GuardWorkspaceView.readiness),
                ),
                _workspaceBannerAction(
                  key: const ValueKey('guards-overview-selected-open-trace'),
                  label: 'Trace',
                  selected: _workspaceView == _GuardWorkspaceView.trace,
                  accent: _workspaceAccent(_GuardWorkspaceView.trace),
                  onTap: () => _setWorkspaceView(_GuardWorkspaceView.trace),
                ),
                _workspaceBannerAction(
                  key: const ValueKey('guards-overview-selected-open-reports'),
                  label: 'Reports',
                  selected: false,
                  accent: const Color(0xFF93C5FD),
                  onTap: () => _openReportsForSite(context, selectedGuard),
                ),
              ],
            ),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accent, size: 16),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFFF4F8FF),
                    fontSize: 16,
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
              color: const Color(0xFF93A5BF),
              fontSize: 9.5,
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
              color: const Color(0xFFD5E1F2),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  void _showReportsLinkDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111827),
          title: Text(
            'Reports Link Ready',
            style: GoogleFonts.inter(
              color: const Color(0xFFF6FBFF),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Use Reports to review workforce documentation, schedule exports, and field-performance outputs tied to the selected guard or site.',
            style: GoogleFonts.inter(
              color: const Color(0xFFD6E2F2),
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

  void _openReportsForSite(BuildContext context, _GuardRecord selectedGuard) {
    final callback = widget.onOpenGuardReportsForSite;
    if (callback == null) {
      _showReportsLinkDialog(context);
      return;
    }
    logUiAction(
      'guards_hero_report_opened',
      context: <String, Object?>{
        'site_id': selectedGuard.siteId,
        'site_name': selectedGuard.site,
        'guard_id': selectedGuard.id,
      },
    );
    callback(selectedGuard.siteId);
  }

  void _openGuardSchedule() {
    final callback = widget.onOpenGuardSchedule;
    if (callback == null) {
      return;
    }
    logUiAction('guards_schedule_opened');
    callback();
  }

  Widget _header(_GuardRecord selectedGuard) {
    final reportsAvailable = widget.onOpenGuardReportsForSite != null;
    final scheduleAvailable = widget.onOpenGuardSchedule != null;
    return OnyxPageHeader(
      title: 'Guards',
      subtitle:
          'Real-time guard monitoring, shift verification, and performance tracking.',
      actions: [
        OutlinedButton.icon(
          onPressed: reportsAvailable
              ? () {
                  final callback = widget.onOpenGuardReportsForSite;
                  if (callback == null) {
                    return;
                  }
                  logUiAction(
                    'guards_export_report_opened',
                    context: <String, Object?>{
                      'site_id': selectedGuard.siteId,
                      'site_name': selectedGuard.site,
                      'guard_id': selectedGuard.id,
                    },
                  );
                  callback(selectedGuard.siteId);
                }
              : null,
          icon: const Icon(Icons.download_rounded, size: 16),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF8FD1FF),
            side: const BorderSide(color: Color(0xFF35506F)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          label: Text(
            'Export Report',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        FilledButton.icon(
          onPressed: scheduleAvailable ? _openGuardSchedule : null,
          icon: const Icon(Icons.people_rounded, size: 16),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2B5E93),
            foregroundColor: const Color(0xFFEAF4FF),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          label: Text(
            'Manage Schedule',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _kpis({
    required int onDutyCount,
    required int offDutyCount,
    required int onBreakCount,
    required int offlineCount,
  }) {
    final cards = [
      _KpiSpec(
        'On Duty',
        '$onDutyCount',
        const Color(0xFF10B981),
        Icons.shield,
      ),
      _KpiSpec(
        'Off Duty',
        '$offDutyCount',
        const Color(0xFF94A3B8),
        Icons.people,
      ),
      _KpiSpec(
        'On Break',
        '$onBreakCount',
        const Color(0xFFF59E0B),
        Icons.schedule,
      ),
      _KpiSpec(
        'Offline Alert',
        '$offlineCount',
        const Color(0xFFEF4444),
        Icons.error_outline_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1200;
        if (compact) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                _kpiCard(cards[i]),
                if (i != cards.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: _kpiCard(cards[i])),
              if (i != cards.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }

  Widget _kpiCard(_KpiSpec spec) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: spec.color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(spec.icon, size: 16, color: spec.color),
              const SizedBox(width: 6),
              Text(
                spec.label,
                style: GoogleFonts.inter(
                  color: const Color(0x99FFFFFF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            spec.value,
            style: GoogleFonts.rajdhani(
              color: spec.color,
              fontSize: 24,
              height: 0.9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _guardListPanel({
    required List<_GuardRecord> guards,
    required List<_GuardRecord> scopedGuards,
    required List<DropdownMenuItem<String>> siteOptions,
    bool embedScroll = false,
    bool shellless = false,
  }) {
    return _panelSurface(
      embedScroll: embedScroll,
      shellless: shellless,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Active Guards'),
          const SizedBox(height: 4),
          Text(
            'Lane-led roster control for fast deployment triage, staffing attention, and site-scoped search.',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _GuardLaneFilter.values
                .map(
                  (lane) =>
                      _laneChip(lane, _laneCountForFilter(scopedGuards, lane)),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 6),
          _searchField(),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _selectField(
                  value: _statusFilter,
                  options: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'ON_DUTY', child: Text('On Duty')),
                    DropdownMenuItem(
                      value: 'OFF_DUTY',
                      child: Text('Off Duty'),
                    ),
                    DropdownMenuItem(
                      value: 'ON_BREAK',
                      child: Text('On Break'),
                    ),
                    DropdownMenuItem(value: 'OFFLINE', child: Text('Offline')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _statusFilter = value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _selectField(
                  value: _siteFilter,
                  options: siteOptions,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _siteFilter = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _statusPill(
                icon: Icons.visibility_outlined,
                label: '${guards.length} Visible',
                accent: const Color(0xFF63BDFF),
              ),
              _statusPill(
                icon: Icons.tune_rounded,
                label: _laneLabel(_laneFilter),
                accent: _laneAccent(_laneFilter),
              ),
              if (_searchQuery.isNotEmpty)
                _statusPill(
                  icon: Icons.search_rounded,
                  label: 'Query ${_searchQuery.toUpperCase()}',
                  accent: const Color(0xFFF6C067),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (guards.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1117),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x332B425F)),
              ),
              child: Text(
                'No guards match the current roster lane and filters.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB1CF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < guards.length; i++) ...[
                  _guardCard(guards[i]),
                  if (i != guards.length - 1) const SizedBox(height: 6),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _guardCard(_GuardRecord guard) {
    final selected = guard.id == _selectedGuardId;
    final statusStyle = _statusStyle(guard.status);
    final needsAttention = _guardNeedsAttention(guard);

    return InkWell(
      key: ValueKey('guards-roster-card-${guard.id}'),
      onTap: () => _selectGuard(guard.id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? const Color(0x1A22D3EE) : const Color(0xFF0C1117),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? const Color(0x8022D3EE) : const Color(0x332B425F),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF1A2A3D),
              child: Text(
                _initials(guard.name),
                style: GoogleFonts.inter(
                  color: const Color(0xFF8FD1FF),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          guard.name,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFEAF4FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (needsAttention)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x1AEF4444),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0x66EF4444)),
                          ),
                          child: Text(
                            'ATTN',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFFA3A3),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0x668EA4C2),
                        size: 18,
                      ),
                    ],
                  ),
                  Text(
                    guard.employeeId,
                    style: GoogleFonts.robotoMono(
                      color: const Color(0xFF8EA4C2),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    guard.site,
                    style: GoogleFonts.inter(
                      color: const Color(0xCCFFFFFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Shift ${guard.shiftStart} - ${guard.shiftEnd} • ${guard.lastHeartbeat}',
                    style: GoogleFonts.inter(
                      color: const Color(0x998EA4C2),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _statusChip(statusStyle),
                      if (guard.status != _GuardStatus.offDuty)
                        _iconMeta(
                          Icons.battery_5_bar_rounded,
                          '${guard.battery}%',
                          guard.battery <= 20
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF9AB1CF),
                        ),
                      if (guard.status != _GuardStatus.offDuty)
                        _iconMeta(
                          Icons.network_cell_rounded,
                          '${guard.signalStrength}%',
                          guard.signalStrength <= 20
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF9AB1CF),
                        ),
                      _iconMeta(
                        Icons.verified_user_outlined,
                        '${guard.compliance}%',
                        guard.compliance >= 95
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                  if (guard.clockInTime != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: Color(0x668EA4C2),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Clocked in at ${guard.clockInTime}',
                          style: GoogleFonts.inter(
                            color: const Color(0x998EA4C2),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (guard.clockInPhotoVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.camera_alt_rounded,
                            size: 13,
                            color: Color(0xFF10B981),
                          ),
                        ] else ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 13,
                            color: Color(0xFFF59E0B),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (needsAttention) ...[
                    const SizedBox(height: 5),
                    Text(
                      _attentionReason(guard),
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFFC8B5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _guardDetailPanel({
    required _GuardRecord? guard,
    required List<_GuardRecord> scopedGuards,
    bool embedScroll = false,
    bool shellless = false,
  }) {
    return _panelSurface(
      embedScroll: embedScroll,
      shellless: shellless,
      child: guard == null
          ? _emptyHint('Select a guard lane with an available roster entry.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Guard Profile'),
                const SizedBox(height: 3),
                Text(
                  'A selected-guard command board with field posture, readiness checks, and workforce trace.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8EA4C2),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                _guardFocusBanner(guard),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _GuardWorkspaceView.values
                      .map((view) => _workspaceChip(view))
                      .toList(growable: false),
                ),
                const SizedBox(height: 8),
                switch (_workspaceView) {
                  _GuardWorkspaceView.command => _guardCommandPanel(guard),
                  _GuardWorkspaceView.readiness => _guardReadinessPanel(guard),
                  _GuardWorkspaceView.trace => _guardTracePanel(
                    guard,
                    scopedGuards,
                  ),
                },
              ],
            ),
    );
  }

  Widget _activityPanel({
    required _GuardRecord? guard,
    required List<_GuardRecord> scopedGuards,
    bool embedScroll = false,
    bool shellless = false,
  }) {
    final focusGuard = guard ?? _selectedGuard(scopedGuards);
    final scopedChanges = focusGuard == null
        ? _recentShiftChanges
        : _changesForGuard(focusGuard);
    return _panelSurface(
      embedScroll: embedScroll,
      shellless: shellless,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Recent Activity'),
          const SizedBox(height: 3),
          Text(
            'Context rail for shift moves, system risk, and route-level workforce handoff.',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          if (focusGuard != null) ...[
            _subPanel(
              shellless: _desktopWorkspaceActive,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Scope',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9AB1CF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _kv('Guard', focusGuard.name),
                  _kv('Lane', _laneLabel(_laneFilter)),
                  _kv('Site', focusGuard.site),
                  _kv(
                    'Watch Status',
                    _guardNeedsAttention(focusGuard)
                        ? 'Attention required'
                        : 'Nominal',
                    valueColor: _guardNeedsAttention(focusGuard)
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            FilledButton.tonalIcon(
              key: const ValueKey('guards-activity-focus-attention'),
              onPressed: () => _focusAttentionLane(scopedGuards),
              icon: const Icon(Icons.warning_amber_rounded, size: 18),
              label: const Text('Focus Attention Lane'),
            ),
            const SizedBox(height: 8),
          ],
          _workspaceCommandReceipt(focusGuard),
          const SizedBox(height: 8),
          Column(
            children: [
              for (int i = 0; i < scopedChanges.length; i++) ...[
                _shiftChangeCard(scopedChanges[i]),
                if (i != scopedChanges.length - 1) const SizedBox(height: 6),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: const Color(0x332B425F)),
          const SizedBox(height: 8),
          Text(
            'System Alerts',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          _alertCard(
            title: 'Low Battery Alert',
            detail: 'Precious Sithole (GRD-447) - Battery at 12%',
            color: const Color(0xFFEF4444),
            icon: Icons.battery_alert_rounded,
          ),
          const SizedBox(height: 6),
          _alertCard(
            title: 'Signal Lost',
            detail: 'Precious Sithole (GRD-447) - Last contact 8 min ago',
            color: const Color(0xFFF59E0B),
            icon: Icons.network_check_rounded,
          ),
        ],
      ),
    );
  }

  Widget _shiftChangeCard(_ShiftChangeRecord change) {
    final style = _shiftStyle(change.type);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x332B425F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFF151E2A),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(style.icon, color: style.color, size: 14),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  change.guardName,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${style.label} • ${change.site}',
                  style: GoogleFonts.inter(
                    color: const Color(0x99FFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _iconMeta(
                      Icons.schedule_rounded,
                      change.timestamp,
                      const Color(0xFF8EA4C2),
                    ),
                    if (change.photoVerified)
                      _iconMeta(
                        Icons.camera_alt_rounded,
                        'Photo',
                        const Color(0xFF10B981),
                      ),
                    if (change.verified)
                      _iconMeta(
                        Icons.check_circle_rounded,
                        'Verified',
                        const Color(0xFF10B981),
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

  Widget _alertCard({
    required String title,
    required String detail,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: const Color(0xB3FFFFFF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _laneChip(_GuardLaneFilter lane, int count) {
    final selected = _laneFilter == lane;
    final accent = _laneAccent(lane);
    return InkWell(
      key: ValueKey('guards-roster-lane-${_laneKey(lane)}'),
      onTap: () {
        _setRosterLane(lane);
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.16)
              : const Color(0xFF0C1117),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.42)
                : const Color(0x332B425F),
          ),
        ),
        child: Text(
          '${_laneLabel(lane)} $count',
          style: GoogleFonts.inter(
            color: selected ? accent : const Color(0xFF9AB1CF),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _guardFocusBanner(_GuardRecord guard) {
    final statusStyle = _statusStyle(guard.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusStyle.foreground.withValues(alpha: 0.16),
            const Color(0xFF101A2B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusStyle.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF1A2A3D),
                child: Text(
                  _initials(guard.name),
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8FD1FF),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTIVE WORKFORCE PROFILE',
                      style: GoogleFonts.inter(
                        color: statusStyle.foreground,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      guard.name,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${guard.employeeId} • ${guard.siteId}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8EA4C2),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(statusStyle),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _heroChip('Site', guard.site),
              _heroChip('Shift', '${guard.shiftStart} - ${guard.shiftEnd}'),
              _heroChip('Sync', guard.lastHeartbeat),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _metricMini('Battery', '${guard.battery}%')),
              const SizedBox(width: 6),
              Expanded(
                child: _metricMini('Signal', '${guard.signalStrength}%'),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _metricMini(
                  'Compliance',
                  '${guard.compliance}%',
                  valueColor: guard.compliance >= 95
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _workspaceChip(_GuardWorkspaceView view) {
    final selected = _workspaceView == view;
    final accent = _workspaceAccent(view);
    return InkWell(
      key: ValueKey('guards-workspace-view-${_workspaceKey(view)}'),
      onTap: () {
        _setWorkspaceView(view);
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.16)
              : const Color(0xFF0C1117),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.42)
                : const Color(0x332B425F),
          ),
        ),
        child: Text(
          _workspaceLabel(view),
          style: GoogleFonts.inter(
            color: selected ? accent : const Color(0xFF9AB1CF),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _guardCommandPanel(_GuardRecord guard) {
    return Container(
      key: const ValueKey('guards-workspace-panel-command'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subPanel(
            shellless: _desktopWorkspaceActive,
            child: Column(
              children: [
                _kv('Current Site', guard.site),
                _kv('Shift Hours', '${guard.shiftStart} - ${guard.shiftEnd}'),
                if (guard.clockInTime != null)
                  _kv(
                    'Clock In',
                    guard.clockInPhotoVerified
                        ? '${guard.clockInTime} • photo verified'
                        : '${guard.clockInTime} • awaiting review',
                    valueColor: guard.clockInPhotoVerified
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                  ),
                _kv('Last Heartbeat', guard.lastHeartbeat),
                _kv('Emergency', guard.emergencyContact),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _subPanel(
            shellless: _desktopWorkspaceActive,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Location',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9AB1CF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${guard.lat.toStringAsFixed(6)}, ${guard.lng.toStringAsFixed(6)}',
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFFDDEBFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Accuracy: ${guard.locationAccuracy}',
                  style: GoogleFonts.inter(
                    color: const Color(0x998EA4C2),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _secondaryButton(
                  'Call',
                  Icons.phone_rounded,
                  () => _showGuardContactSheet(
                    guard,
                    initialMode: _GuardContactMode.call,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _secondaryButton(
                  'Message',
                  Icons.message_rounded,
                  () => _showGuardContactSheet(
                    guard,
                    initialMode: _GuardContactMode.message,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Performance (24h)',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFEAF4FF),
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _metricMini('OB Entries', '${guard.obEntries}')),
              const SizedBox(width: 6),
              Expanded(child: _metricMini('Incidents', '${guard.incidents}')),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _metricMini('Patrols', '${guard.patrols}')),
              const SizedBox(width: 6),
              Expanded(
                child: _metricMini(
                  'Site Pulse',
                  _guardNeedsAttention(guard) ? 'Watch' : 'Stable',
                  valueColor: _guardNeedsAttention(guard)
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _guardReadinessPanel(_GuardRecord guard) {
    return Container(
      key: const ValueKey('guards-workspace-panel-readiness'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subPanel(
            shellless: _desktopWorkspaceActive,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shift Verification',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9AB1CF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                _kv(
                  'Photo Verification',
                  guard.clockInPhotoVerified ? 'Verified' : 'Pending review',
                  valueColor: guard.clockInPhotoVerified
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                ),
                _kv('Location Accuracy', guard.locationAccuracy),
                _kv('Status', _statusStyle(guard.status).label),
                _kv('Readiness Note', _attentionReason(guard)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _metricMini(
                  'Battery',
                  '${guard.battery}%',
                  valueColor: guard.battery <= 20
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFEAF4FF),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _metricMini(
                  'Signal',
                  '${guard.signalStrength}%',
                  valueColor: guard.signalStrength <= 20
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFEAF4FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _subPanel(
            shellless: _desktopWorkspaceActive,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Certifications',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9AB1CF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: guard.certifications
                      .map(
                        (cert) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x1A3B82F6),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0x553B82F6)),
                          ),
                          child: Text(
                            cert,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF8FD1FF),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _guardTracePanel(_GuardRecord guard, List<_GuardRecord> scopedGuards) {
    final peers = scopedGuards
        .where(
          (candidate) =>
              candidate.id != guard.id && candidate.siteId == guard.siteId,
        )
        .toList(growable: false);
    final changes = _changesForGuard(guard);
    return Container(
      key: const ValueKey('guards-workspace-panel-trace'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Site Peers',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFEAF4FF),
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (peers.isEmpty)
            _emptyHint('No other visible guards share this site scope.')
          else
            Column(
              children: [
                for (int i = 0; i < peers.length; i++) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C1117),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: const Color(0x332B425F)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                peers[i].name,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFEAF4FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${peers[i].employeeId} • ${_statusStyle(peers[i].status).label}',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF8EA4C2),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _selectGuard(peers[i].id),
                          child: Text(
                            'Focus',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i != peers.length - 1) const SizedBox(height: 6),
                ],
              ],
            ),
          const SizedBox(height: 8),
          Text(
            'Verification Trace',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFEAF4FF),
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Column(
            children: [
              for (int i = 0; i < changes.length; i++) ...[
                _shiftChangeCard(changes[i]),
                if (i != changes.length - 1) const SizedBox(height: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _panelSurface({
    required Widget child,
    bool embedScroll = false,
    bool shellless = false,
  }) {
    if (shellless) {
      if (!embedScroll) {
        return child;
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final canEmbedScroll = constraints.hasBoundedHeight;
          return canEmbedScroll
              ? SingleChildScrollView(primary: false, child: child)
              : child;
        },
      );
    }
    if (!embedScroll) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1A2B),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFF223244)),
        ),
        child: child,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final canEmbedScroll = constraints.hasBoundedHeight;
        return Container(
          width: double.infinity,
          height: canEmbedScroll ? constraints.maxHeight : null,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1A2B),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFF223244)),
          ),
          child: canEmbedScroll
              ? SingleChildScrollView(primary: false, child: child)
              : child,
        );
      },
    );
  }

  Widget _subPanel({required Widget child, bool shellless = false}) {
    if (shellless) {
      return child;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x332B425F)),
      ),
      child: child,
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value.trim()),
      style: GoogleFonts.inter(
        color: const Color(0xFFEAF4FF),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: 'Search by name, ID, or site...',
        hintStyle: GoogleFonts.inter(
          color: const Color(0x668EA4C2),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 18,
          color: Color(0xFF8EA4C2),
        ),
        filled: true,
        fillColor: const Color(0xFF0C1117),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0x332B425F)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0x332B425F)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0x8022D3EE)),
        ),
      ),
    );
  }

  Widget _selectField({
    required String value,
    required List<DropdownMenuItem<String>> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      menuMaxHeight: 340,
      onChanged: onChanged,
      dropdownColor: const Color(0xFF0E1A2B),
      style: GoogleFonts.inter(
        color: const Color(0xFFEAF4FF),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF0C1117),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0x332B425F)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0x332B425F)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0x8022D3EE)),
        ),
      ),
      items: options,
    );
  }

  Widget _sectionTitle(String label) {
    return Text(
      label,
      style: GoogleFonts.rajdhani(
        color: const Color(0xFFEAF4FF),
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _statusChip(_GuardStatusStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.border),
      ),
      child: Text(
        style.label,
        style: GoogleFonts.inter(
          color: style.foreground,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _iconMeta(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          value,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _metricMini(String label, String value, {Color? valueColor}) {
    return _subPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0x998EA4C2),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              color: valueColor ?? const Color(0xFFEAF4FF),
              fontSize: 20,
              height: 0.9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _secondaryButton(String label, IconData icon, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF8FD1FF),
        side: const BorderSide(color: Color(0xFF35506F)),
        minimumSize: const Size.fromHeight(40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _kv(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0x998EA4C2),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                color: valueColor ?? const Color(0xFFEAF4FF),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyHint(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x332B425F)),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          color: const Color(0xFF9AB1CF),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _selectGuard(String guardId) {
    setState(() => _selectedGuardId = guardId);
  }

  void _setRosterLane(_GuardLaneFilter lane) {
    if (_laneFilter == lane) {
      return;
    }
    setState(() {
      _laneFilter = lane;
    });
  }

  void _setWorkspaceView(_GuardWorkspaceView view) {
    if (_workspaceView == view) {
      return;
    }
    setState(() {
      _workspaceView = view;
    });
  }

  void _focusAttentionLane(List<_GuardRecord> scopedGuards) {
    final attentionGuards = scopedGuards
        .where(
          (candidate) =>
              _matchesLaneFilter(candidate, _GuardLaneFilter.attention),
        )
        .toList(growable: false);
    setState(() {
      _laneFilter = _GuardLaneFilter.attention;
      if (attentionGuards.isNotEmpty) {
        _selectedGuardId = attentionGuards.first.id;
      }
    });
  }

  bool _matchesLaneFilter(_GuardRecord guard, _GuardLaneFilter lane) {
    return switch (lane) {
      _GuardLaneFilter.all => true,
      _GuardLaneFilter.deployed =>
        guard.status == _GuardStatus.onDuty ||
            guard.status == _GuardStatus.onBreak,
      _GuardLaneFilter.attention => _guardNeedsAttention(guard),
      _GuardLaneFilter.reserve => guard.status == _GuardStatus.offDuty,
    };
  }

  bool _guardNeedsAttention(_GuardRecord guard) {
    if (guard.status == _GuardStatus.offline ||
        guard.status == _GuardStatus.onBreak) {
      return true;
    }
    return !guard.clockInPhotoVerified ||
        guard.battery <= 20 ||
        guard.signalStrength <= 20 ||
        guard.compliance < 95;
  }

  int _laneCountForFilter(List<_GuardRecord> guards, _GuardLaneFilter lane) {
    return guards.where((guard) => _matchesLaneFilter(guard, lane)).length;
  }

  String _laneLabel(_GuardLaneFilter lane) {
    return switch (lane) {
      _GuardLaneFilter.all => 'All',
      _GuardLaneFilter.deployed => 'Deployed',
      _GuardLaneFilter.attention => 'Attention',
      _GuardLaneFilter.reserve => 'Reserve',
    };
  }

  String _laneKey(_GuardLaneFilter lane) {
    return switch (lane) {
      _GuardLaneFilter.all => 'all',
      _GuardLaneFilter.deployed => 'deployed',
      _GuardLaneFilter.attention => 'attention',
      _GuardLaneFilter.reserve => 'reserve',
    };
  }

  Color _laneAccent(_GuardLaneFilter lane) {
    return switch (lane) {
      _GuardLaneFilter.all => const Color(0xFF93A8C9),
      _GuardLaneFilter.deployed => const Color(0xFF10B981),
      _GuardLaneFilter.attention => const Color(0xFFF59E0B),
      _GuardLaneFilter.reserve => const Color(0xFF94A3B8),
    };
  }

  String _workspaceLabel(_GuardWorkspaceView view) {
    return switch (view) {
      _GuardWorkspaceView.command => 'Command',
      _GuardWorkspaceView.readiness => 'Readiness',
      _GuardWorkspaceView.trace => 'Trace',
    };
  }

  String _workspaceKey(_GuardWorkspaceView view) {
    return switch (view) {
      _GuardWorkspaceView.command => 'command',
      _GuardWorkspaceView.readiness => 'readiness',
      _GuardWorkspaceView.trace => 'trace',
    };
  }

  Color _workspaceAccent(_GuardWorkspaceView view) {
    return switch (view) {
      _GuardWorkspaceView.command => const Color(0xFF63BDFF),
      _GuardWorkspaceView.readiness => const Color(0xFF10B981),
      _GuardWorkspaceView.trace => const Color(0xFFF59E0B),
    };
  }

  String _attentionReason(_GuardRecord guard) {
    if (guard.status == _GuardStatus.offline) {
      return 'Device heartbeat lost and field sync follow-up is required.';
    }
    if (guard.battery <= 20) {
      return 'Battery is below operating tolerance for the active shift.';
    }
    if (guard.signalStrength <= 20) {
      return 'Signal strength is weak enough to threaten live field visibility.';
    }
    if (!guard.clockInPhotoVerified) {
      return 'Clock-in proof still needs image verification or supervisor review.';
    }
    if (guard.compliance < 95) {
      return 'Recent compliance has dipped below the target operating threshold.';
    }
    if (guard.status == _GuardStatus.onBreak) {
      return 'Guard is on break and requires coverage awareness for the post.';
    }
    return 'Field posture is nominal for the current deployment window.';
  }

  List<_ShiftChangeRecord> _changesForGuard(_GuardRecord guard) {
    final scoped = _recentShiftChanges
        .where(
          (change) => change.guardId == guard.id || change.site == guard.site,
        )
        .toList(growable: false);
    if (scoped.isNotEmpty) {
      return scoped;
    }
    return _recentShiftChanges.take(4).toList(growable: false);
  }

  _GuardStatusStyle _statusStyle(_GuardStatus status) {
    switch (status) {
      case _GuardStatus.onDuty:
        return const _GuardStatusStyle(
          label: 'ON DUTY',
          foreground: Color(0xFF10B981),
          background: Color(0x1A10B981),
          border: Color(0x6610B981),
        );
      case _GuardStatus.offDuty:
        return const _GuardStatusStyle(
          label: 'OFF DUTY',
          foreground: Color(0xFF94A3B8),
          background: Color(0x1A94A3B8),
          border: Color(0x6694A3B8),
        );
      case _GuardStatus.onBreak:
        return const _GuardStatusStyle(
          label: 'ON BREAK',
          foreground: Color(0xFFF59E0B),
          background: Color(0x1AF59E0B),
          border: Color(0x66F59E0B),
        );
      case _GuardStatus.offline:
        return const _GuardStatusStyle(
          label: 'OFFLINE',
          foreground: Color(0xFFEF4444),
          background: Color(0x1AEF4444),
          border: Color(0x66EF4444),
        );
    }
  }

  _ShiftStyle _shiftStyle(_ShiftChangeType type) {
    return switch (type) {
      _ShiftChangeType.clockIn => const _ShiftStyle(
        label: 'CLOCK IN',
        icon: Icons.login_rounded,
        color: Color(0xFF10B981),
      ),
      _ShiftChangeType.clockOut => const _ShiftStyle(
        label: 'CLOCK OUT',
        icon: Icons.logout_rounded,
        color: Color(0xFF94A3B8),
      ),
      _ShiftChangeType.breakStart => const _ShiftStyle(
        label: 'BREAK START',
        icon: Icons.coffee_rounded,
        color: Color(0xFFF59E0B),
      ),
      _ShiftChangeType.breakEnd => const _ShiftStyle(
        label: 'BREAK END',
        icon: Icons.play_circle_rounded,
        color: Color(0xFF3B82F6),
      ),
    };
  }

  _GuardRecord? _selectedGuard(List<_GuardRecord> filtered) {
    if (filtered.isEmpty) return null;
    for (final guard in filtered) {
      if (guard.id == _selectedGuardId) {
        return guard;
      }
    }
    return filtered.first;
  }

  List<_GuardRecord> _filteredGuards() {
    return _guards
        .where((guard) {
          final query = _searchQuery.toLowerCase();
          final matchesSearch =
              query.isEmpty ||
              guard.name.toLowerCase().contains(query) ||
              guard.employeeId.toLowerCase().contains(query) ||
              guard.site.toLowerCase().contains(query);
          final matchesStatus =
              _statusFilter == 'ALL' ||
              _statusCode(guard.status) == _statusFilter;
          final matchesSite =
              _siteFilter == 'ALL' || guard.siteId == _siteFilter;
          return matchesSearch && matchesStatus && matchesSite;
        })
        .toList(growable: false);
  }

  String _statusCode(_GuardStatus status) {
    return switch (status) {
      _GuardStatus.onDuty => 'ON_DUTY',
      _GuardStatus.offDuty => 'OFF_DUTY',
      _GuardStatus.onBreak => 'ON_BREAK',
      _GuardStatus.offline => 'OFFLINE',
    };
  }

  List<DropdownMenuItem<String>> _siteOptions() {
    final sorted =
        _guards
            .map((guard) => (id: guard.siteId, site: guard.site))
            .toSet()
            .toList(growable: false)
          ..sort((a, b) => a.site.compareTo(b.site));

    return [
      const DropdownMenuItem(value: 'ALL', child: Text('All Sites')),
      ...sorted.map(
        (site) =>
            DropdownMenuItem<String>(value: site.id, child: Text(site.site)),
      ),
    ];
  }

  String _resolveSiteFilter(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.toUpperCase() == 'ALL') {
      return 'ALL';
    }
    final exactId = _guards.cast<_GuardRecord?>().firstWhere(
      (guard) => guard != null && guard.siteId == trimmed,
      orElse: () => null,
    );
    if (exactId != null) {
      return exactId.siteId;
    }
    final normalized = _normalizedSiteToken(trimmed);
    final exactSiteName = _guards.cast<_GuardRecord?>().firstWhere(
      (guard) =>
          guard != null && _normalizedSiteToken(guard.site) == normalized,
      orElse: () => null,
    );
    if (exactSiteName != null) {
      return exactSiteName.siteId;
    }
    final partialMatch = _guards.cast<_GuardRecord?>().firstWhere(
      (guard) =>
          guard != null &&
          (_normalizedSiteToken(guard.site).contains(normalized) ||
              normalized.contains(_normalizedSiteToken(guard.site))),
      orElse: () => null,
    );
    return partialMatch?.siteId ?? 'ALL';
  }

  String _normalizedSiteToken(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  String _initials(String name) {
    final parts = name.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'G';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  void _showGuardFeedback(
    String message, {
    String label = 'CONTACT HANDOFF',
    String? detail,
    Color accent = const Color(0xFF63BDFF),
  }) {
    if (_desktopWorkspaceActive) {
      setState(() {
        _commandReceipt = _GuardCommandReceipt(
          label: label,
          headline: message,
          detail:
              detail ??
              'The latest guard workflow action stays pinned in the activity rail while the selected scope remains active.',
          accent: accent,
        );
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F1419),
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _copyGuardContact(_GuardRecord guard) async {
    await Clipboard.setData(ClipboardData(text: guard.emergencyContact));
    if (!mounted) return;
    logUiAction(
      'guard_contact_copied',
      context: <String, Object?>{
        'guard_id': guard.id,
        'site_id': guard.siteId,
        'contact': guard.emergencyContact,
      },
    );
    _showGuardFeedback(
      '${guard.name} contact copied.',
      label: 'CONTACT COPIED',
      detail:
          'The copied guard contact stays visible in the activity rail while message and voice handoffs remain available.',
      accent: const Color(0xFF8FD1FF),
    );
  }

  Future<void> _showGuardContactSheet(
    _GuardRecord guard, {
    required _GuardContactMode initialMode,
  }) async {
    logUiAction(
      'guard_contact_sheet_opened',
      context: <String, Object?>{
        'guard_id': guard.id,
        'site_id': guard.siteId,
        'mode': initialMode.name,
      },
    );
    final isMessage = initialMode == _GuardContactMode.message;
    final clientLaneAvailable = widget.onOpenClientLaneForSite != null;
    final voipAvailable = widget.onStageGuardVoipCall != null;
    final primaryActionAvailable = isMessage
        ? clientLaneAvailable
        : voipAvailable;
    final primaryStatusLabel = isMessage
        ? (clientLaneAvailable ? 'Client lane ready' : 'Client lane offline')
        : (voipAvailable ? 'VoIP ready' : 'VoIP offline');
    final readinessNote = isMessage
        ? (clientLaneAvailable
              ? 'Open the client lane to keep guard outreach warm, logged, and tied to the site thread.'
              : 'Client lane routing is not connected in this session yet, so this handoff stays view-only for now.')
        : (voipAvailable
              ? 'Stage the voice handoff now so control carries the right guard contact into the call flow.'
              : 'VoIP staging is not connected in this session yet, so this handoff stays view-only for now.');
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF0B1117),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMessage ? 'Message Guard Lane' : 'Voice Call Staging',
                style: GoogleFonts.rajdhani(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isMessage
                    ? 'Use the command lane for warm, traceable outreach. Telegram stays primary and SMS remains fallback-only once delivery wiring is live.'
                    : 'Stage the voice handoff now so control has the right contact context ready when VoIP lands.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB1CF),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _contactLaneChip(
                    label: isMessage ? 'Telegram primary' : primaryStatusLabel,
                    accent: const Color(0xFF8FD1FF),
                  ),
                  _contactLaneChip(
                    label: 'SMS fallback standby',
                    accent: const Color(0xFFF59E0B),
                  ),
                  _contactLaneChip(
                    label: guard.site,
                    accent: const Color(0xFF10B981),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _contactDetailRow('Guard', guard.name),
              _contactDetailRow('Employee', guard.employeeId),
              _contactDetailRow('Current Site', guard.site),
              _contactDetailRow('Contact', guard.emergencyContact),
              const SizedBox(height: 14),
              Text(
                readinessNote,
                style: GoogleFonts.inter(
                  color: primaryActionAvailable
                      ? const Color(0xFF9AB1CF)
                      : const Color(0xFFFACC15),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await _copyGuardContact(guard);
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8FD1FF),
                        side: const BorderSide(color: Color(0xFF35506F)),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      label: Text(
                        'Copy Contact',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: primaryActionAvailable
                          ? () async {
                              Navigator.of(sheetContext).pop();
                              if (isMessage) {
                                final callback = widget.onOpenClientLaneForSite;
                                if (callback == null) {
                                  return;
                                }
                                logUiAction(
                                  'guard_message_lane_opened',
                                  context: <String, Object?>{
                                    'guard_id': guard.id,
                                    'site_id': guard.siteId,
                                  },
                                );
                                callback(guard.siteId);
                                return;
                              }
                              final callback = widget.onStageGuardVoipCall;
                              if (callback == null) {
                                return;
                              }
                              final message = await callback(
                                guard.id,
                                guard.name,
                                guard.siteId,
                                guard.emergencyContact,
                              );
                              if (!mounted) {
                                return;
                              }
                              _showGuardFeedback(
                                message,
                                label: 'VOIP STAGING',
                                detail:
                                    'The staged call handoff stays pinned in the activity rail while the guard workspace remains in focus.',
                                accent: const Color(0xFF10B981),
                              );
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2B5E93),
                        foregroundColor: const Color(0xFFEAF4FF),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: Icon(
                        isMessage
                            ? Icons.forum_rounded
                            : Icons.phone_forwarded_rounded,
                        size: 16,
                      ),
                      label: Text(
                        isMessage ? 'Open Client Lane' : 'Stage VoIP Call',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _contactLaneChip({required String label, required Color accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _contactDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0x998EA4C2),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: const Color(0xFFEAF4FF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiSpec {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _KpiSpec(this.label, this.value, this.color, this.icon);
}

class _GuardStatusStyle {
  final String label;
  final Color foreground;
  final Color background;
  final Color border;

  const _GuardStatusStyle({
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
  });
}

class _ShiftStyle {
  final String label;
  final IconData icon;
  final Color color;

  const _ShiftStyle({
    required this.label,
    required this.icon,
    required this.color,
  });
}
