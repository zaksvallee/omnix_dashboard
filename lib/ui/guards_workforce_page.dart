import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/guard_sync_repository.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/guard/guard_mobile_ops.dart';
import '../domain/guard/guard_position_summary.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'theme/onyx_design_tokens.dart';
import 'theme/onyx_theme.dart';
import 'ui_action_logger.dart';

const _workforceCanvas = OnyxDesignTokens.backgroundPrimary;
const _workforceSurface = OnyxDesignTokens.backgroundSecondary;
const _workforceInset = OnyxDesignTokens.surfaceInset;
const _workforceElevated = OnyxDesignTokens.surfaceElevated;
const _workforceBorder = OnyxDesignTokens.divider;
const _workforceBorderSubtle = OnyxDesignTokens.borderSubtle;
const _workforceTitle = OnyxDesignTokens.textPrimary;
const _workforceBody = OnyxDesignTokens.textSecondary;
const _workforceMuted = OnyxDesignTokens.textMuted;
const _workforcePurple = OnyxDesignTokens.accentPurple;
const _workforceGreen = OnyxDesignTokens.greenNominal;
const _workforceAmber = OnyxDesignTokens.amberWarning;
const _workforceRed = OnyxDesignTokens.redCritical;
const _workforceSky = OnyxDesignTokens.accentSky;

enum _WorkforceTab { activeGuards, shiftRoster, shiftHistory }

enum _GuardOperationalStatus { ready, engaged, offline, unavailable }

enum _CoverageState { full, thin, gap }

enum _SignalState { strong, degraded, lost }

enum _HistoryFlag { lateStart, extendedShift, noMovement, highActivity }

class GuardsEvidenceReturnReceipt {
  final String auditId;
  final String label;
  final String headline;
  final String detail;
  final Color accent;

  const GuardsEvidenceReturnReceipt({
    required this.auditId,
    required this.label,
    required this.headline,
    required this.detail,
    required this.accent,
  });
}

class _WorkforceGuard {
  final String id;
  final String fullName;
  final String callsign;
  final String employeeId;
  final String siteCode;
  final String siteName;
  final String routeSiteId;
  final String contactPhone;
  final String handler;
  final String shiftLabel;
  final String shiftWindow;
  final String clockInLabel;
  final _GuardOperationalStatus status;
  final _SignalState signalState;
  final bool hasSyncIssue;
  final String lastSyncLabel;
  final String assignmentLabel;
  final String readinessLabel;
  final String readinessDetail;
  final String locationLabel;
  final String lastMovementLabel;
  final String avgResponseLabel;
  final int obEntries;
  final int incidents;
  final String ratingLabel;
  final String performanceNote;
  final String zaraHeadline;
  final String zaraDetail;
  final DateTime? lastSyncAtUtc;
  final DateTime? clockInAtUtc;
  final GuardPositionSummary? lastPosition;

  const _WorkforceGuard({
    required this.id,
    required this.fullName,
    required this.callsign,
    required this.employeeId,
    required this.siteCode,
    required this.siteName,
    required this.routeSiteId,
    required this.contactPhone,
    required this.handler,
    required this.shiftLabel,
    required this.shiftWindow,
    required this.clockInLabel,
    required this.status,
    required this.signalState,
    required this.hasSyncIssue,
    required this.lastSyncLabel,
    required this.assignmentLabel,
    required this.readinessLabel,
    required this.readinessDetail,
    required this.locationLabel,
    required this.lastMovementLabel,
    required this.avgResponseLabel,
    required this.obEntries,
    required this.incidents,
    required this.ratingLabel,
    required this.performanceNote,
    required this.zaraHeadline,
    required this.zaraDetail,
    this.lastSyncAtUtc,
    this.clockInAtUtc,
    this.lastPosition,
  });

  _WorkforceGuard copyWith({
    String? siteCode,
    String? siteName,
    String? routeSiteId,
    String? shiftLabel,
    String? shiftWindow,
    String? clockInLabel,
    _GuardOperationalStatus? status,
    _SignalState? signalState,
    bool? hasSyncIssue,
    String? lastSyncLabel,
    String? assignmentLabel,
    String? readinessLabel,
    String? readinessDetail,
    String? locationLabel,
    String? lastMovementLabel,
    String? avgResponseLabel,
    int? obEntries,
    int? incidents,
    String? ratingLabel,
    String? performanceNote,
    String? zaraHeadline,
    String? zaraDetail,
    DateTime? lastSyncAtUtc,
    DateTime? clockInAtUtc,
    GuardPositionSummary? lastPosition,
  }) {
    return _WorkforceGuard(
      id: id,
      fullName: fullName,
      callsign: callsign,
      employeeId: employeeId,
      siteCode: siteCode ?? this.siteCode,
      siteName: siteName ?? this.siteName,
      routeSiteId: routeSiteId ?? this.routeSiteId,
      contactPhone: contactPhone,
      handler: handler,
      shiftLabel: shiftLabel ?? this.shiftLabel,
      shiftWindow: shiftWindow ?? this.shiftWindow,
      clockInLabel: clockInLabel ?? this.clockInLabel,
      status: status ?? this.status,
      signalState: signalState ?? this.signalState,
      hasSyncIssue: hasSyncIssue ?? this.hasSyncIssue,
      lastSyncLabel: lastSyncLabel ?? this.lastSyncLabel,
      assignmentLabel: assignmentLabel ?? this.assignmentLabel,
      readinessLabel: readinessLabel ?? this.readinessLabel,
      readinessDetail: readinessDetail ?? this.readinessDetail,
      locationLabel: locationLabel ?? this.locationLabel,
      lastMovementLabel: lastMovementLabel ?? this.lastMovementLabel,
      avgResponseLabel: avgResponseLabel ?? this.avgResponseLabel,
      obEntries: obEntries ?? this.obEntries,
      incidents: incidents ?? this.incidents,
      ratingLabel: ratingLabel ?? this.ratingLabel,
      performanceNote: performanceNote ?? this.performanceNote,
      zaraHeadline: zaraHeadline ?? this.zaraHeadline,
      zaraDetail: zaraDetail ?? this.zaraDetail,
      lastSyncAtUtc: lastSyncAtUtc ?? this.lastSyncAtUtc,
      clockInAtUtc: clockInAtUtc ?? this.clockInAtUtc,
      lastPosition: lastPosition ?? this.lastPosition,
    );
  }
}

class _CoverageCell {
  final String dayLabel;
  final _CoverageState state;
  final List<String> assignments;
  final String note;

  const _CoverageCell({
    required this.dayLabel,
    required this.state,
    required this.assignments,
    required this.note,
  });
}

class _CoverageLane {
  final String siteCode;
  final String siteName;
  final String zoneLabel;
  final _CoverageState quality;
  final List<_CoverageCell> days;

  const _CoverageLane({
    required this.siteCode,
    required this.siteName,
    required this.zoneLabel,
    required this.quality,
    required this.days,
  });
}

class _HistoryEntry {
  final String shiftDateLabel;
  final String guardName;
  final String callsign;
  final String siteLabel;
  final String shiftWindow;
  final String durationLabel;
  final String startLabel;
  final String endLabel;
  final String movementLabel;
  final String activityLabel;
  final List<_HistoryFlag> flags;
  final String zaraNote;

  const _HistoryEntry({
    required this.shiftDateLabel,
    required this.guardName,
    required this.callsign,
    required this.siteLabel,
    required this.shiftWindow,
    required this.durationLabel,
    required this.startLabel,
    required this.endLabel,
    required this.movementLabel,
    required this.activityLabel,
    required this.flags,
    required this.zaraNote,
  });
}

class GuardsWorkforcePage extends StatefulWidget {
  final List<DispatchEvent> events;
  final String initialSiteFilter;
  final Future<GuardSyncRepository>? guardSyncRepositoryFuture;
  final GuardsEvidenceReturnReceipt? evidenceReturnReceipt;
  final ValueChanged<String>? onConsumeEvidenceReturnReceipt;
  final VoidCallback? onOpenGuardSchedule;
  final void Function(String action, {DateTime? date})?
  onOpenGuardScheduleForAction;
  final ValueChanged<String>? onOpenGuardReportsForSite;
  final ValueChanged<String>? onOpenClientLaneForSite;
  final Future<String> Function(
    String guardId,
    String guardName,
    String siteId,
    String phone,
  )?
  onStageGuardVoipCall;

  const GuardsWorkforcePage({
    super.key,
    required this.events,
    this.initialSiteFilter = 'ALL',
    this.guardSyncRepositoryFuture,
    this.evidenceReturnReceipt,
    this.onConsumeEvidenceReturnReceipt,
    this.onOpenGuardSchedule,
    this.onOpenGuardScheduleForAction,
    this.onOpenGuardReportsForSite,
    this.onOpenClientLaneForSite,
    this.onStageGuardVoipCall,
  });

  @override
  State<GuardsWorkforcePage> createState() => _GuardsWorkforcePageState();
}

class _GuardsWorkforcePageState extends State<GuardsWorkforcePage>
    with SingleTickerProviderStateMixin {
  static const List<_WorkforceGuard> _seedGuards = <_WorkforceGuard>[
    _WorkforceGuard(
      id: 'GRD-441',
      fullName: 'Thabo Mokoena',
      callsign: 'Echo-3',
      employeeId: 'G-2441',
      siteCode: 'SE-01',
      siteName: 'Sandton Estate North',
      routeSiteId: 'SE-01',
      contactPhone: '+27 82 555 0441',
      handler: 'Emily Davis',
      shiftLabel: 'Night',
      shiftWindow: '18:00 - 06:00',
      clockInLabel: '18:00',
      status: _GuardOperationalStatus.ready,
      signalState: _SignalState.strong,
      hasSyncIssue: false,
      lastSyncLabel: '12s ago',
      assignmentLabel: 'Perimeter sweep · North boulevard',
      readinessLabel: 'Ready for incident handoff',
      readinessDetail: 'Nearest response-ready unit to Sandton north gate.',
      locationLabel: 'North gate patrol loop',
      lastMovementLabel: 'Checkpoint Delta · 3m ago',
      avgResponseLabel: '02m 18s',
      obEntries: 24,
      incidents: 3,
      ratingLabel: '4.8',
      performanceNote: 'High patrol discipline and consistent checkpoint cadence.',
      zaraHeadline: 'Echo-3 is the fastest clean-response option on this site.',
      zaraDetail:
          'No fatigue markers detected. Recommend Echo-3 for first dispatch on Sandton alarms.',
    ),
    _WorkforceGuard(
      id: 'GRD-442',
      fullName: 'Johan van Wyk',
      callsign: 'Tango-1',
      employeeId: 'G-2442',
      siteCode: 'WF-02',
      siteName: 'Waterfall Estate',
      routeSiteId: 'WF-02',
      contactPhone: '+27 83 222 0442',
      handler: 'Sarah Jacobs',
      shiftLabel: 'Night',
      shiftWindow: '18:00 - 06:00',
      clockInLabel: '18:00',
      status: _GuardOperationalStatus.engaged,
      signalState: _SignalState.degraded,
      hasSyncIssue: true,
      lastSyncLabel: '2m ago',
      assignmentLabel: 'Escort in progress · South river approach',
      readinessLabel: 'Engaged on live task',
      readinessDetail: 'Assignable after current escort closes or a second unit backfills.',
      locationLabel: 'South river fence line',
      lastMovementLabel: 'Vehicle gate Bravo · 9m ago',
      avgResponseLabel: '03m 01s',
      obEntries: 18,
      incidents: 5,
      ratingLabel: '4.6',
      performanceNote: 'High activity load with one telemetry retry required.',
      zaraHeadline: 'Tango-1 remains reliable but should not take another hot task yet.',
      zaraDetail:
          'Signal degradation is likely environmental. Hold as secondary until sync stabilises.',
    ),
    _WorkforceGuard(
      id: 'GRD-443',
      fullName: 'Kabelo Dlamini',
      callsign: 'Sierra-2',
      employeeId: 'G-2443',
      siteCode: 'BR-03',
      siteName: 'Blue Ridge Residence',
      routeSiteId: 'BR-03',
      contactPhone: '+27 84 333 0443',
      handler: 'John Smith',
      shiftLabel: 'Night',
      shiftWindow: '18:00 - 06:00',
      clockInLabel: '18:00',
      status: _GuardOperationalStatus.ready,
      signalState: _SignalState.strong,
      hasSyncIssue: false,
      lastSyncLabel: '19s ago',
      assignmentLabel: 'West perimeter watch',
      readinessLabel: 'Ready with thin-site dependency',
      readinessDetail: 'Primary responder on Blue Ridge until backup rotates in.',
      locationLabel: 'West perimeter lane',
      lastMovementLabel: 'Checkpoint Lima · 4m ago',
      avgResponseLabel: '02m 31s',
      obEntries: 16,
      incidents: 2,
      ratingLabel: '4.7',
      performanceNote: 'Steady patrol cadence with low incident noise.',
      zaraHeadline: 'Blue Ridge is covered, but only just.',
      zaraDetail:
          'Recommend maintaining Sierra-2 on site and layering backup before next shift rollover.',
    ),
    _WorkforceGuard(
      id: 'GRD-444',
      fullName: 'Sizwe Mabaso',
      callsign: 'Atlas-5',
      employeeId: 'G-2444',
      siteCode: '--',
      siteName: 'Standby pool',
      routeSiteId: '',
      contactPhone: '+27 81 444 0444',
      handler: 'Standby Desk',
      shiftLabel: 'Standby',
      shiftWindow: '--',
      clockInLabel: '--',
      status: _GuardOperationalStatus.unavailable,
      signalState: _SignalState.lost,
      hasSyncIssue: false,
      lastSyncLabel: 'offline',
      assignmentLabel: 'Standby pool',
      readinessLabel: 'Unavailable until reassigned',
      readinessDetail: 'No active assignment or duty confirmation in the current window.',
      locationLabel: 'No live telemetry',
      lastMovementLabel: 'No movement recorded',
      avgResponseLabel: '--',
      obEntries: 9,
      incidents: 1,
      ratingLabel: '4.5',
      performanceNote: 'Available for future roster staging, not current response.',
      zaraHeadline: 'Atlas-5 should stay out of live dispatch decisions until shift confirmation.',
      zaraDetail:
          'Use Atlas-5 for coverage planning, not immediate incident response.',
    ),
    _WorkforceGuard(
      id: 'GRD-445',
      fullName: 'Maya Pillay',
      callsign: 'Echo-7',
      employeeId: 'G-2445',
      siteCode: 'SE-01',
      siteName: 'Sandton Estate North',
      routeSiteId: 'SE-01',
      contactPhone: '+27 82 555 0445',
      handler: 'Mike Wills',
      shiftLabel: 'Day',
      shiftWindow: '06:00 - 18:00',
      clockInLabel: '06:00',
      status: _GuardOperationalStatus.ready,
      signalState: _SignalState.strong,
      hasSyncIssue: false,
      lastSyncLabel: '15s ago',
      assignmentLabel: 'Lobby and resident access control',
      readinessLabel: 'Ready with full access picture',
      readinessDetail: 'Best positioned to support resident verification and access incidents.',
      locationLabel: 'Main lobby control',
      lastMovementLabel: 'Resident desk · 2m ago',
      avgResponseLabel: '02m 11s',
      obEntries: 19,
      incidents: 1,
      ratingLabel: '4.9',
      performanceNote: 'Excellent response tempo and high-confidence access logging.',
      zaraHeadline: 'Echo-7 is the cleanest escalation partner for Sandton access events.',
      zaraDetail:
          'No delay indicators. Strong choice for controlled handoffs and resident communication.',
    ),
    _WorkforceGuard(
      id: 'GRD-446',
      fullName: 'Lerato Ndlovu',
      callsign: 'Tango-4',
      employeeId: 'G-2446',
      siteCode: 'WF-02',
      siteName: 'Waterfall Estate',
      routeSiteId: 'WF-02',
      contactPhone: '+27 82 555 0446',
      handler: 'Mike Wills',
      shiftLabel: 'Day',
      shiftWindow: '06:00 - 18:00',
      clockInLabel: '06:00',
      status: _GuardOperationalStatus.ready,
      signalState: _SignalState.strong,
      hasSyncIssue: false,
      lastSyncLabel: '27s ago',
      assignmentLabel: 'Gatehouse and CCTV cross-check',
      readinessLabel: 'Ready with responder depth',
      readinessDetail: 'Can backfill Tango-1 immediately if Waterfall load increases.',
      locationLabel: 'Gatehouse Alpha',
      lastMovementLabel: 'Guardhouse exterior · 5m ago',
      avgResponseLabel: '02m 24s',
      obEntries: 14,
      incidents: 2,
      ratingLabel: '4.7',
      performanceNote: 'Consistent gate coverage and resilient telemetry signal.',
      zaraHeadline: 'Tango-4 is the preferred Waterfall fallback while Tango-1 is engaged.',
      zaraDetail:
          'Coverage remains intact if Tango-4 stays anchored to gatehouse response lanes.',
    ),
  ];

  late final TabController _tabController;
  _WorkforceTab _selectedTab = _WorkforceTab.activeGuards;
  String _siteFilter = 'ALL';
  String _selectedGuardId = _seedGuards.first.id;
  List<_WorkforceGuard>? _liveGuards;
  GuardsEvidenceReturnReceipt? _activeEvidenceReturnReceipt;

  bool get _canOpenGuardSchedule =>
      widget.onOpenGuardScheduleForAction != null ||
      widget.onOpenGuardSchedule != null;

  @override
  void initState() {
    super.initState();
    _siteFilter = _resolveSiteFilter(widget.initialSiteFilter);
    _tabController = TabController(length: _WorkforceTab.values.length, vsync: this)
      ..addListener(_handleTabChange);
    _ingestEvidenceReturnReceipt(widget.evidenceReturnReceipt);
    unawaited(_loadWorkforce());
  }

  @override
  void didUpdateWidget(covariant GuardsWorkforcePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.evidenceReturnReceipt?.auditId !=
        widget.evidenceReturnReceipt?.auditId) {
      _ingestEvidenceReturnReceipt(
        widget.evidenceReturnReceipt,
        useSetState: true,
      );
    }
    if (oldWidget.guardSyncRepositoryFuture != widget.guardSyncRepositoryFuture) {
      unawaited(_loadWorkforce());
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!mounted || _tabController.indexIsChanging) {
      return;
    }
    final nextTab = _WorkforceTab.values[_tabController.index];
    if (_selectedTab == nextTab) {
      return;
    }
    setState(() {
      _selectedTab = nextTab;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme.merge(OnyxTheme.dark().textTheme);
    final guards = _filteredGuards();
    final selectedGuard = _resolveSelectedGuard(guards);
    final coverageRows = _buildCoverageRows(guards);
    final historyEntries = _buildHistoryEntries(guards);

    return OnyxPageScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ultrawideSurface = isUltrawideLayout(
            context,
            viewportWidth: constraints.maxWidth,
          );
          final surfaceMaxWidth = commandSurfaceMaxWidth(
            context,
            compactDesktopWidth: 1600,
            viewportWidth: constraints.maxWidth,
            widescreenFillFactor: ultrawideSurface ? 1 : 0.96,
          );
          final wide = constraints.maxWidth >= 1220;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: surfaceMaxWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _pageHeader(textTheme),
                    if (_activeEvidenceReturnReceipt != null) ...[
                      const SizedBox(height: 12),
                      _evidenceReturnBanner(_activeEvidenceReturnReceipt!),
                    ],
                    const SizedBox(height: 14),
                    _zaraSummaryStrip(guards, coverageRows, historyEntries, textTheme),
                    const SizedBox(height: 12),
                    _workforceStatusBar(guards, textTheme),
                    const SizedBox(height: 12),
                    _tabBar(textTheme),
                    const SizedBox(height: 14),
                    switch (_selectedTab) {
                      _WorkforceTab.activeGuards => _activeGuardsTab(
                        guards: guards,
                        selectedGuard: selectedGuard,
                        textTheme: textTheme,
                        wide: wide,
                      ),
                      _WorkforceTab.shiftRoster => _shiftRosterTab(
                        coverageRows: coverageRows,
                        guards: guards,
                        textTheme: textTheme,
                      ),
                      _WorkforceTab.shiftHistory => _shiftHistoryTab(
                        historyEntries: historyEntries,
                        textTheme: textTheme,
                      ),
                    },
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pageHeader(TextTheme textTheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Guards & Workforce',
                style: textTheme.headlineMedium?.copyWith(
                  color: _workforceTitle,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Operational readiness intelligence for live guards, coverage depth, and shift anomalies.',
                style: textTheme.bodyMedium?.copyWith(
                  color: _workforceBody,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _exportWorkforceSnapshot,
          icon: const Icon(Icons.download_rounded, size: 16),
          label: Text(
            'Export snapshot',
            style: textTheme.labelLarge?.copyWith(
              color: _workforceTitle,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: _workforceTitle,
            side: const BorderSide(color: _workforceBorderSubtle),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _zaraSummaryStrip(
    List<_WorkforceGuard> guards,
    List<_CoverageLane> coverageRows,
    List<_HistoryEntry> historyEntries,
    TextTheme textTheme,
  ) {
    final readyCount = guards.where((guard) => guard.status == _GuardOperationalStatus.ready).length;
    final engagedCount = guards.where((guard) => guard.status == _GuardOperationalStatus.engaged).length;
    final syncIssues = guards.where((guard) => guard.hasSyncIssue).length;
    final gaps = coverageRows.where((lane) => lane.quality == _CoverageState.gap).length;
    final thin = coverageRows.where((lane) => lane.quality == _CoverageState.thin).length;
    final anomalyCount = historyEntries.where((entry) => entry.flags.isNotEmpty).length;

    late final List<(Color, String)> lines;
    late final String postureLabel;
    late final Color postureColor;

    switch (_selectedTab) {
      case _WorkforceTab.activeGuards:
        lines = <(Color, String)>[
          (
            _workforceGreen,
            '$readyCount guards ready for immediate response across ${_visibleSiteCount(guards)} active sites.',
          ),
          (
            engagedCount > 0 ? _workforceAmber : _workforceGreen,
            engagedCount > 0
                ? '$engagedCount guard engaged on a live task. Queue handoff should prefer the next ready unit.'
                : 'All active guards are available for controlled dispatch handoff.',
          ),
          (
            syncIssues > 0 ? _workforcePurple : _workforceGreen,
            syncIssues > 0
                ? '$syncIssues sync issue flagged. Verify telemetry before rotating that guard into the next incident.'
                : 'Telemetry is stable. Real-time guard position hooks are ready for live map binding.',
          ),
        ];
        postureLabel = engagedCount > 0 ? 'CONTROLLED RESPONSE' : 'WORKFORCE READY';
        postureColor = engagedCount > 0 ? _workforceAmber : _workforceGreen;
      case _WorkforceTab.shiftRoster:
        lines = <(Color, String)>[
          (
            gaps > 0 ? _workforceRed : _workforceGreen,
            gaps > 0
                ? '$gaps site coverage gap${gaps == 1 ? '' : 's'} detected in the current seven-day layer.'
                : 'Coverage grid is fully staffed across the current seven-day horizon.',
          ),
          (
            thin > 0 ? _workforceAmber : _workforceGreen,
            thin > 0
                ? '$thin site lane${thin == 1 ? '' : 's'} running thin. Add a coverage layer before shift rollover.'
                : 'No thin lanes detected. Each site keeps at least two operational names on the board.',
          ),
          (
            _workforcePurple,
            'Zara recommends reviewing Blue Ridge and Waterfall first before the next night turnover.',
          ),
        ];
        postureLabel = gaps > 0 || thin > 0 ? 'COVERAGE WATCH' : 'COVERAGE STABLE';
        postureColor = gaps > 0 || thin > 0 ? _workforceAmber : _workforceGreen;
      case _WorkforceTab.shiftHistory:
        final extended = historyEntries
            .where((entry) => entry.flags.contains(_HistoryFlag.extendedShift))
            .length;
        final noMovement = historyEntries
            .where((entry) => entry.flags.contains(_HistoryFlag.noMovement))
            .length;
        lines = <(Color, String)>[
          (
            anomalyCount > 0 ? _workforceAmber : _workforceGreen,
            anomalyCount > 0
                ? '$anomalyCount shift timeline entries include operational flags worth review.'
                : 'No operational anomalies surfaced in the current history window.',
          ),
          (
            extended > 0 ? _workforceAmber : _workforceGreen,
            extended > 0
                ? '$extended extended shift${extended == 1 ? '' : 's'} detected. Watch fatigue on the next roster layer.'
                : 'No fatigue markers detected from the current shift durations.',
          ),
          (
            noMovement > 0 ? _workforcePurple : _workforceGreen,
            noMovement > 0
                ? '$noMovement no-movement flag${noMovement == 1 ? '' : 's'} surfaced. Cross-check patrol continuity against CCTV.'
                : 'Movement patterns remain healthy across logged shifts.',
          ),
        ];
        postureLabel = anomalyCount > 0 ? 'PERFORMANCE WATCH' : 'TRENDLINE CLEAN';
        postureColor = anomalyCount > 0 ? _workforceAmber : _workforceGreen;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _workforceSurface,
        border: Border.all(color: _workforcePurple.withValues(alpha: 0.20)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 960;
          final summary = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _workforcePurple.withValues(alpha: 0.15),
                  border: Border.all(
                    color: _workforcePurple.withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(
                  child: Text(
                    'Z',
                    style: textTheme.titleMedium?.copyWith(
                      color: _workforcePurple,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ZARA · WORKFORCE SUMMARY',
                      style: textTheme.labelSmall?.copyWith(
                        color: _workforcePurple.withValues(alpha: 0.60),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final line in lines) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: line.$1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              line.$2,
                              style: textTheme.bodyMedium?.copyWith(
                                color: _workforceBody,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (line != lines.last) const SizedBox(height: 5),
                    ],
                  ],
                ),
              ),
            ],
          );

          final posture = Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: postureColor.withValues(alpha: 0.10),
              border: Border.all(color: postureColor.withValues(alpha: 0.25)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              postureLabel,
              style: textTheme.labelSmall?.copyWith(
                color: postureColor,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                summary,
                const SizedBox(height: 12),
                posture,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: summary),
              const SizedBox(width: 16),
              posture,
            ],
          );
        },
      ),
    );
  }

  Widget _workforceStatusBar(List<_WorkforceGuard> guards, TextTheme textTheme) {
    final readyCount = guards.where((guard) => guard.status == _GuardOperationalStatus.ready).length;
    final activeCount = guards
        .where(
          (guard) =>
              guard.status == _GuardOperationalStatus.ready ||
              guard.status == _GuardOperationalStatus.engaged,
        )
        .length;
    final syncIssues = guards.where((guard) => guard.hasSyncIssue).length;
    final siteFilters = _availableSiteFilters(_effectiveGuards);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _workforceSurface,
        border: Border.all(color: _workforceBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 1040;
          final counts = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusMetricChip('$readyCount READY', _workforceGreen, textTheme),
              _statusMetricChip('$activeCount ACTIVE SHIFTS', _workforcePurple, textTheme),
              _statusMetricChip(
                '$syncIssues SYNC ISSUE${syncIssues == 1 ? '' : 'S'}',
                syncIssues > 0 ? _workforceAmber : _workforceGreen,
                textTheme,
              ),
            ],
          );
          final filters = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Text('SITE FILTER', style: _sectionLabelStyle(textTheme)),
              for (final siteCode in siteFilters) _siteFilterChip(siteCode, textTheme),
            ],
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                counts,
                const SizedBox(height: 10),
                filters,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: counts),
              const SizedBox(width: 12),
              Flexible(child: filters),
            ],
          );
        },
      ),
    );
  }

  Widget _tabBar(TextTheme textTheme) {
    return Container(
      decoration: BoxDecoration(
        color: _workforceSurface,
        border: Border.all(color: _workforceBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            color: _workforcePurple,
            width: 2,
          ),
        ),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: _workforcePurple,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          color: _workforceMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'Active Guards'),
          Tab(text: 'Shift Roster'),
          Tab(text: 'Shift History'),
        ],
      ),
    );
  }

  Widget _activeGuardsTab({
    required List<_WorkforceGuard> guards,
    required _WorkforceGuard? selectedGuard,
    required TextTheme textTheme,
    required bool wide,
  }) {
    if (guards.isEmpty || selectedGuard == null) {
      return _panel(
        child: Center(
          child: Text(
            'No guards match the current site filter.',
            style: textTheme.bodyMedium?.copyWith(
              color: _workforceBody,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _guardListPanel(guards, textTheme),
          const SizedBox(height: 12),
          _guardDetailPanel(selectedGuard, textTheme),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 330, child: _guardListPanel(guards, textTheme)),
        const SizedBox(width: 12),
        Expanded(child: _guardDetailPanel(selectedGuard, textTheme)),
      ],
    );
  }

  Widget _guardListPanel(List<_WorkforceGuard> guards, TextTheme textTheme) {
    return _panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              children: [
                Text('ACTIVE GUARDS', style: _sectionLabelStyle(textTheme)),
                const Spacer(),
                Text(
                  '${guards.length} visible',
                  style: textTheme.bodySmall?.copyWith(
                    color: _workforceMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: _workforceBorder, height: 1),
          for (final guard in guards) _guardListRow(guard, textTheme),
        ],
      ),
    );
  }

  Widget _guardListRow(_WorkforceGuard guard, TextTheme textTheme) {
    final selected = guard.id == _selectedGuardId;
    final accent = _statusColor(guard.status);
    return InkWell(
      onTap: () => _selectGuard(guard.id),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: selected
              ? _workforcePurple.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: _workforceBorder),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 46,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${guard.callsign} · ${guard.fullName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            color: _workforceTitle,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusBadge(
                        _guardStatusLabel(guard.status),
                        accent,
                        textTheme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${guard.employeeId} · ${guard.siteCode == '--' ? 'Standby pool' : guard.siteCode} · ${guard.siteName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: _workforceBody,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _signalIndicator(guard.signalState, textTheme),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          guard.lastSyncLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: _workforceMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _guardDetailPanel(_WorkforceGuard guard, TextTheme textTheme) {
    final accent = _statusColor(guard.status);
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _workforcePurple.withValues(alpha: 0.12),
                  border: Border.all(
                    color: _workforcePurple.withValues(alpha: 0.24),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    guard.callsign.split('-').first.substring(0, 1),
                    style: textTheme.headlineSmall?.copyWith(
                      color: _workforcePurple,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${guard.callsign} · ${guard.fullName}',
                      style: textTheme.headlineSmall?.copyWith(
                        color: _workforceTitle,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${guard.employeeId} · ${guard.siteName}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: _workforceBody,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _statusBadge(_guardStatusLabel(guard.status), accent, textTheme),
                        _statusBadge(_signalLabel(guard.signalState), _signalColor(guard.signalState), textTheme),
                        _tonalChip(guard.shiftWindow, _workforceSky, textTheme),
                        _tonalChip(guard.assignmentLabel, _workforcePurple, textTheme),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 980
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _detailCard(
                      title: 'IDENTITY',
                      child: _detailList(
                        textTheme,
                        <(String, String)>[
                          ('Guard', '${guard.fullName} · ${guard.callsign}'),
                          ('Employee', guard.employeeId),
                          ('Handler', guard.handler),
                          ('Contact', guard.contactPhone),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _detailCard(
                      title: 'ASSIGNMENT',
                      child: _detailList(
                        textTheme,
                        <(String, String)>[
                          ('Site', guard.siteName),
                          ('Coverage', guard.assignmentLabel),
                          ('Shift', guard.shiftWindow),
                          ('Clock in', guard.clockInLabel),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _detailCard(
                      title: 'READINESS',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guard.readinessLabel,
                            style: textTheme.titleSmall?.copyWith(
                              color: accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            guard.readinessDetail,
                            style: textTheme.bodySmall?.copyWith(
                              color: _workforceBody,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _detailCard(
                      title: 'LIVE SIGNAL',
                      child: _detailList(
                        textTheme,
                        <(String, String)>[
                          ('Signal', _signalLabel(guard.signalState)),
                          ('Last sync', guard.lastSyncLabel),
                          ('Position', guard.locationLabel),
                          ('Last movement', guard.lastMovementLabel),
                        ],
                        accentKey: 'Signal',
                        accentColor: _signalColor(guard.signalState),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth,
                    child: _detailCard(
                      title: 'PERFORMANCE',
                      child: Row(
                        children: [
                          Expanded(
                            child: _metricTile(
                              'AVG RESPONSE',
                              guard.avgResponseLabel,
                              _workforcePurple,
                              textTheme,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metricTile(
                              'OB ENTRIES',
                              '${guard.obEntries}',
                              _workforceGreen,
                              textTheme,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metricTile(
                              'INCIDENTS',
                              '${guard.incidents}',
                              _workforceAmber,
                              textTheme,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metricTile(
                              'RATING',
                              guard.ratingLabel,
                              _workforceSky,
                              textTheme,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _workforcePurple.withValues(alpha: 0.08),
                        border: Border.all(
                          color: _workforcePurple.withValues(alpha: 0.18),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _workforcePurple.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Text(
                                'Z',
                                style: textTheme.labelSmall?.copyWith(
                                  color: _workforcePurple,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ZARA INSIGHT',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: _workforcePurple.withValues(alpha: 0.68),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  guard.zaraHeadline,
                                  style: textTheme.titleSmall?.copyWith(
                                    color: _workforceTitle,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  guard.zaraDetail,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: _workforceBody,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    height: 1.45,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _actionBar(guard, textTheme),
        ],
      ),
    );
  }

  Widget _shiftRosterTab({
    required List<_CoverageLane> coverageRows,
    required List<_WorkforceGuard> guards,
    required TextTheme textTheme,
  }) {
    final fullCount = coverageRows.where((lane) => lane.quality == _CoverageState.full).length;
    final thinCount = coverageRows.where((lane) => lane.quality == _CoverageState.thin).length;
    final gapCount = coverageRows.where((lane) => lane.quality == _CoverageState.gap).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ZARA · COVERAGE SUMMARY', style: _sectionLabelStyle(textTheme).copyWith(color: _workforcePurple.withValues(alpha: 0.65))),
                    const SizedBox(height: 8),
                    _summaryLine(
                      gapCount > 0 ? _workforceRed : _workforceGreen,
                      gapCount > 0
                          ? '$gapCount coverage gap${gapCount == 1 ? '' : 's'} require immediate layering before the next shift handoff.'
                          : 'No hard gaps detected in the current weekly coverage layer.',
                      textTheme,
                    ),
                    const SizedBox(height: 5),
                    _summaryLine(
                      thinCount > 0 ? _workforceAmber : _workforceGreen,
                      thinCount > 0
                          ? '$thinCount thin lane${thinCount == 1 ? '' : 's'} identified. Waterfall and Blue Ridge should be reinforced first.'
                          : 'All site lanes maintain healthy responder depth through the current week.',
                      textTheme,
                    ),
                    const SizedBox(height: 5),
                    _summaryLine(
                      _workforcePurple,
                      'Predictive view: ${guards.where((guard) => guard.status == _GuardOperationalStatus.ready).length} guards are available to support a new coverage layer.',
                      textTheme,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _statusMetricChip('$fullCount FULLY COVERED', _workforceGreen, textTheme),
                        _statusMetricChip('$thinCount THIN', _workforceAmber, textTheme),
                        _statusMetricChip('$gapCount GAP', _workforceRed, textTheme),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _canOpenGuardSchedule
                    ? () => _openGuardScheduleForAction('coverage-layer')
                    : null,
                icon: const Icon(Icons.add_chart_rounded, size: 16),
                label: Text(
                  'Add Coverage Layer',
                  style: textTheme.labelLarge?.copyWith(
                    color: _workforceTitle,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _workforcePurple,
                  foregroundColor: _workforceTitle,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: const BoxDecoration(
                      color: _workforceInset,
                      border: Border(
                        bottom: BorderSide(color: _workforceBorder),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 220,
                          child: Text('COVERAGE GRID', style: _sectionLabelStyle(textTheme)),
                        ),
                        for (final day in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
                          SizedBox(
                            width: 120,
                            child: Text(
                              day,
                              textAlign: TextAlign.center,
                              style: _sectionLabelStyle(textTheme),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final lane in coverageRows) _coverageLaneRow(lane, textTheme),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _shiftHistoryTab({
    required List<_HistoryEntry> historyEntries,
    required TextTheme textTheme,
  }) {
    final extendedCount = historyEntries
        .where((entry) => entry.flags.contains(_HistoryFlag.extendedShift))
        .length;
    final noMovementCount = historyEntries
        .where((entry) => entry.flags.contains(_HistoryFlag.noMovement))
        .length;
    final highActivityCount = historyEntries
        .where((entry) => entry.flags.contains(_HistoryFlag.highActivity))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ZARA · PERFORMANCE SUMMARY',
                style: _sectionLabelStyle(textTheme).copyWith(
                  color: _workforcePurple.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 8),
              _summaryLine(
                extendedCount > 0 ? _workforceAmber : _workforceGreen,
                extendedCount > 0
                    ? '$extendedCount extended shift${extendedCount == 1 ? '' : 's'} detected. Evaluate fatigue before the next dispatch assignment.'
                    : 'No extended-shift fatigue markers surfaced in this history window.',
                textTheme,
              ),
              const SizedBox(height: 5),
              _summaryLine(
                noMovementCount > 0 ? _workforceAmber : _workforceGreen,
                noMovementCount > 0
                    ? '$noMovementCount no-movement flag${noMovementCount == 1 ? '' : 's'} need patrol continuity review.'
                    : 'No patrol continuity gaps surfaced in the current timeline.',
                textTheme,
              ),
              const SizedBox(height: 5),
              _summaryLine(
                highActivityCount > 0 ? _workforcePurple : _workforceGreen,
                highActivityCount > 0
                    ? '$highActivityCount high-activity shift${highActivityCount == 1 ? '' : 's'} may drive future coverage rebalancing.'
                    : 'Activity load remains balanced across current guards and sites.',
                textTheme,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: const BoxDecoration(
                      color: _workforceInset,
                      border: Border(
                        bottom: BorderSide(color: _workforceBorder),
                      ),
                    ),
                    child: Row(
                      children: [
                        _historyHeaderCell('SHIFT', 120, textTheme),
                        _historyHeaderCell('GUARD', 180, textTheme),
                        _historyHeaderCell('SITE', 170, textTheme),
                        _historyHeaderCell('WINDOW', 110, textTheme),
                        _historyHeaderCell('DURATION', 110, textTheme),
                        _historyHeaderCell('MOVEMENT', 120, textTheme),
                        _historyHeaderCell('ACTIVITY', 120, textTheme),
                        _historyHeaderCell('FLAGS', 250, textTheme),
                      ],
                    ),
                  ),
                  for (int index = 0; index < historyEntries.length; index++)
                    _historyRow(historyEntries[index], index, textTheme),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _coverageLaneRow(_CoverageLane lane, TextTheme textTheme) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _workforceBorder),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${lane.siteCode} · ${lane.siteName}',
                  style: textTheme.titleSmall?.copyWith(
                    color: _workforceTitle,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Risk area · ${lane.zoneLabel}',
                  style: textTheme.bodySmall?.copyWith(
                    color: _workforceMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _statusBadge(
                  _coverageLabel(lane.quality),
                  _coverageColor(lane.quality),
                  textTheme,
                ),
              ],
            ),
          ),
          for (final day in lane.days)
            SizedBox(
              width: 120,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _workforceCanvas,
                  border: Border.all(color: _workforceBorderSubtle),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statusBadge(
                      _coverageLabel(day.state),
                      _coverageColor(day.state),
                      textTheme,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      day.assignments.isEmpty ? 'Unassigned' : day.assignments.join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: _workforceTitle,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      day.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: _workforceMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _historyRow(_HistoryEntry entry, int index, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: index.isOdd ? _workforceCanvas.withValues(alpha: 0.55) : Colors.transparent,
        border: const Border(
          bottom: BorderSide(color: _workforceBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _historyBodyCell(entry.shiftDateLabel, 120, textTheme),
          SizedBox(
            width: 180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.guardName,
                  style: textTheme.bodyMedium?.copyWith(
                    color: _workforceTitle,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.callsign,
                  style: textTheme.bodySmall?.copyWith(
                    color: _workforceMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _historyBodyCell(entry.siteLabel, 170, textTheme),
          _historyBodyCell(entry.shiftWindow, 110, textTheme),
          _historyBodyCell(entry.durationLabel, 110, textTheme, accent: _workforcePurple),
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.movementLabel,
                  style: textTheme.bodyMedium?.copyWith(
                    color: _workforceTitle,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.startLabel} → ${entry.endLabel}',
                  style: textTheme.bodySmall?.copyWith(
                    color: _workforceMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _historyBodyCell(entry.activityLabel, 120, textTheme),
          SizedBox(
            width: 250,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: entry.flags.isEmpty
                      ? <Widget>[
                          _statusBadge('CLEAR', _workforceGreen, textTheme),
                        ]
                      : entry.flags
                            .map((flag) => _statusBadge(_historyFlagLabel(flag), _historyFlagColor(flag), textTheme))
                            .toList(growable: false),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.zaraNote,
                  style: textTheme.bodySmall?.copyWith(
                    color: _workforceMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBar(_WorkforceGuard guard, TextTheme textTheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        final buttons = <Widget>[
          _actionButton(
            label: 'Dispatch to Incident',
            sublabel: 'Queue/dispatch handoff',
            accent: _workforcePurple,
            textTheme: textTheme,
            onTap: () => _showDispatchReadySnack(guard),
          ),
          _actionButton(
            label: 'Contact Guard',
            sublabel: 'Voice or client lane',
            accent: _workforceGreen,
            textTheme: textTheme,
            onTap: () => _showGuardContactSheet(guard),
          ),
          _actionButton(
            label: 'View Live Location',
            sublabel: 'Position bridge ready',
            accent: _workforceSky,
            textTheme: textTheme,
            onTap: () => _showLiveLocation(guard),
          ),
          _actionButton(
            label: 'Review Activity',
            sublabel: 'Reports and audit trail',
            accent: _workforceAmber,
            textTheme: textTheme,
            onTap: () => _openReportsForGuard(guard),
          ),
        ];
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int index = 0; index < buttons.length; index++) ...[
                buttons[index],
                if (index < buttons.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (int index = 0; index < buttons.length; index++) ...[
              Expanded(child: buttons[index]),
              if (index < buttons.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }

  Widget _actionButton({
    required String label,
    required String sublabel,
    required Color accent,
    required TextTheme textTheme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          border: Border.all(color: accent.withValues(alpha: 0.24)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sublabel,
              style: textTheme.bodySmall?.copyWith(
                color: accent.withValues(alpha: 0.70),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _workforceCanvas,
        border: Border.all(color: _workforceBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: _workforceMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _detailList(
    TextTheme textTheme,
    List<(String, String)> items, {
    String? accentKey,
    Color? accentColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 78,
                child: Text(
                  item.$1,
                  style: textTheme.bodySmall?.copyWith(
                    color: _workforceMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  item.$2,
                  style: textTheme.bodySmall?.copyWith(
                    color: item.$1 == accentKey ? accentColor ?? _workforceTitle : _workforceTitle,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          if (item != items.last) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _metricTile(
    String label,
    String value,
    Color accent,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _workforceElevated,
        border: Border.all(color: _workforceBorderSubtle),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: _workforceMuted,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: textTheme.titleSmall?.copyWith(
              color: accent,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusMetricChip(String label, Color color, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _statusBadge(String label, Color color, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _tonalChip(String label, Color color, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: textTheme.bodySmall?.copyWith(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _signalIndicator(_SignalState signalState, TextTheme textTheme) {
    final color = _signalColor(signalState);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int index = 0; index < 3; index++) ...[
          Container(
            width: 4,
            height: 10 + (index * 3),
            decoration: BoxDecoration(
              color: index < _signalBars(signalState)
                  ? color
                  : _workforceMuted.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          if (index < 2) const SizedBox(width: 2),
        ],
        const SizedBox(width: 6),
        Text(
          _signalLabel(signalState),
          style: textTheme.bodySmall?.copyWith(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _siteFilterChip(String siteCode, TextTheme textTheme) {
    final selected = _siteFilter == siteCode;
    return InkWell(
      onTap: () => _setSiteFilter(siteCode),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? _workforcePurple.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? _workforcePurple.withValues(alpha: 0.24)
                : _workforceBorderSubtle,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          siteCode == 'ALL' ? 'All Sites' : siteCode,
          style: textTheme.bodySmall?.copyWith(
            color: selected ? _workforceTitle : _workforceBody,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _historyHeaderCell(String label, double width, TextTheme textTheme) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: _sectionLabelStyle(textTheme),
      ),
    );
  }

  Widget _historyBodyCell(
    String label,
    double width,
    TextTheme textTheme, {
    Color? accent,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: textTheme.bodyMedium?.copyWith(
          color: accent ?? _workforceBody,
          fontSize: 10,
          fontWeight: accent == null ? FontWeight.w600 : FontWeight.w700,
        ),
      ),
    );
  }

  Widget _summaryLine(Color accent, String text, TextTheme textTheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodyMedium?.copyWith(
              color: _workforceBody,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _panel({
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _workforceSurface,
        border: Border.all(color: _workforceBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  TextStyle _sectionLabelStyle(TextTheme textTheme) {
    return textTheme.labelSmall?.copyWith(
          color: _workforceMuted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
        ) ??
        GoogleFonts.inter(
          color: _workforceMuted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
        );
  }

  Widget _evidenceReturnBanner(GuardsEvidenceReturnReceipt receipt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: receipt.accent.withValues(alpha: 0.12),
        border: Border.all(color: receipt.accent.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            receipt.label,
            style: GoogleFonts.inter(
              color: receipt.accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            receipt.headline,
            style: GoogleFonts.inter(
              color: _workforceTitle,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            receipt.detail,
            style: GoogleFonts.inter(
              color: _workforceBody,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  void _ingestEvidenceReturnReceipt(
    GuardsEvidenceReturnReceipt? receipt, {
    bool useSetState = false,
  }) {
    if (receipt == null) {
      return;
    }
    void apply() => _activeEvidenceReturnReceipt = receipt;
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

  Future<void> _loadWorkforce() async {
    final repositoryFuture = widget.guardSyncRepositoryFuture;
    if (repositoryFuture == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _liveGuards = null;
      });
      return;
    }
    try {
      final repository = await repositoryFuture;
      final assignments = await repository.readAssignments();
      final positions = await repository.readLatestGuardPositions();
      final operations = await repository.readOperations(
        statuses: Set<GuardSyncOperationStatus>.from(
          GuardSyncOperationStatus.values,
        ),
        limit: 500,
      );
      final merged = _mergeLiveGuards(assignments, positions, operations);
      if (!mounted) {
        return;
      }
      setState(() {
        _liveGuards = merged;
        final filtered = _filteredGuards();
        if (filtered.isNotEmpty &&
            !filtered.any((guard) => guard.id == _selectedGuardId)) {
          _selectedGuardId = filtered.first.id;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _liveGuards = null;
      });
    }
  }

  List<_WorkforceGuard> get _effectiveGuards {
    final live = _liveGuards;
    if (live == null || live.isEmpty) {
      return _seedGuards;
    }
    return live;
  }

  List<_WorkforceGuard> _filteredGuards({String? siteCodeOverride}) {
    final filter = siteCodeOverride ?? _siteFilter;
    final guards = _effectiveGuards;
    if (filter == 'ALL') {
      return guards;
    }
    return guards
        .where((guard) => guard.siteCode == filter)
        .toList(growable: false);
  }

  _WorkforceGuard? _resolveSelectedGuard(List<_WorkforceGuard> guards) {
    if (guards.isEmpty) {
      return null;
    }
    for (final guard in guards) {
      if (guard.id == _selectedGuardId) {
        return guard;
      }
    }
    return guards.first;
  }

  String _resolveSiteFilter(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'all') {
      return 'ALL';
    }
    const aliases = <String, List<String>>{
      'SE-01': <String>[
        'se-01',
        'sandton estate north',
        'sandton',
      ],
      'WF-02': <String>[
        'wf-02',
        'waterfall estate',
        'waterfall',
      ],
      'BR-03': <String>[
        'br-03',
        'blue ridge residence',
        'blue ridge',
      ],
    };
    for (final entry in aliases.entries) {
      if (entry.value.contains(normalized)) {
        return entry.key;
      }
    }
    return 'ALL';
  }

  List<String> _availableSiteFilters(List<_WorkforceGuard> guards) {
    final codes = guards
        .map((guard) => guard.siteCode)
        .where((code) => code != '--')
        .toSet()
        .toList(growable: false)
      ..sort();
    return <String>['ALL', ...codes];
  }

  int _visibleSiteCount(List<_WorkforceGuard> guards) {
    return guards
        .where((guard) => guard.siteCode != '--')
        .map((guard) => guard.siteCode)
        .toSet()
        .length;
  }

  List<_WorkforceGuard> _mergeLiveGuards(
    List<GuardAssignment> assignments,
    List<GuardPositionSummary> positions,
    List<GuardSyncOperation> operations,
  ) {
    final assignmentsByGuard = <String, GuardAssignment>{};
    for (final assignment in assignments) {
      final guardId = assignment.guardId.trim();
      if (guardId.isEmpty) {
        continue;
      }
      final current = assignmentsByGuard[guardId];
      if (current == null || assignment.issuedAt.isAfter(current.issuedAt)) {
        assignmentsByGuard[guardId] = assignment;
      }
    }

    final latestPositionByGuard = <String, GuardPositionSummary>{};
    for (final position in positions) {
      final guardId = position.guardId.trim();
      if (guardId.isEmpty) {
        continue;
      }
      final current = latestPositionByGuard[guardId];
      if (current == null ||
          position.recordedAtUtc.isAfter(current.recordedAtUtc)) {
        latestPositionByGuard[guardId] = position;
      }
    }

    final operationsByGuard = <String, List<GuardSyncOperation>>{};
    for (final operation in operations) {
      final guardId = (operation.payload['guard_id'] ?? '').toString().trim();
      if (guardId.isEmpty) {
        continue;
      }
      operationsByGuard.putIfAbsent(guardId, () => <GuardSyncOperation>[]).add(operation);
    }
    for (final ops in operationsByGuard.values) {
      ops.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    }

    return _seedGuards.map((seed) {
      final assignment = assignmentsByGuard[seed.id];
      final latestPosition = latestPositionByGuard[seed.id];
      final guardOperations = operationsByGuard[seed.id] ?? const <GuardSyncOperation>[];
      if (assignment == null && latestPosition == null && guardOperations.isEmpty) {
        return seed;
      }
      final status = _guardStatusFromLive(
        assignment: assignment,
        operations: guardOperations,
        fallback: seed.status,
      );
      final hasSyncIssue = guardOperations.any(
        (operation) => operation.status == GuardSyncOperationStatus.failed,
      );
      final clockInAtUtc =
          assignment?.acknowledgedAt ??
          assignment?.issuedAt ??
          seed.clockInAtUtc;
      final clockInLabel =
          clockInAtUtc == null ? seed.clockInLabel : _timeLabel(clockInAtUtc);
      final shiftLabel = _shiftLabelFor(clockInAtUtc, seed.shiftLabel);
      final shiftWindow = status == _GuardOperationalStatus.offline ||
              status == _GuardOperationalStatus.unavailable
          ? '--'
          : _shiftWindowFor(shiftLabel);
      final lastSyncAtUtc = latestPosition?.recordedAtUtc ??
          (guardOperations.isEmpty ? null : guardOperations.first.createdAt.toUtc()) ??
          seed.lastSyncAtUtc;
      final signalState = _signalStateFromLive(
        status: status,
        latestPosition: latestPosition,
        operations: guardOperations,
        hasSyncIssue: hasSyncIssue,
        fallback: seed.signalState,
      );
      final siteSummary = _siteSummary(
        assignment?.siteId.trim() ?? seed.routeSiteId,
        seed,
      );
      final incidents = guardOperations
          .where(
            (operation) =>
                operation.type == GuardSyncOperationType.incidentCapture ||
                operation.type == GuardSyncOperationType.panicSignal,
          )
          .length;
      final obEntries = guardOperations
          .where((operation) => operation.type == GuardSyncOperationType.checkpointScan)
          .length;
      final assignmentLabel = _assignmentLabelForStatus(status, seed.siteName);
      final readinessLabel = _readinessLabel(status);
      final readinessDetail = _readinessDetail(status, hasSyncIssue, siteSummary.name);
      final locationLabel = latestPosition == null
          ? seed.locationLabel
          : '${latestPosition.latitude.toStringAsFixed(4)}, ${latestPosition.longitude.toStringAsFixed(4)}';
      final lastMovementLabel = latestPosition == null
          ? seed.lastMovementLabel
          : 'Position update · ${_relativeTimeLabel(latestPosition.recordedAtUtc)}';
      final avgResponse = _avgResponseLabel(
        assignment: assignment,
        operations: guardOperations,
        fallback: seed.avgResponseLabel,
      );
      final zaraHeadline = _zaraHeadline(status, hasSyncIssue, seed.callsign);
      final zaraDetail = _zaraDetail(status, hasSyncIssue, siteSummary.name);
      return seed.copyWith(
        siteCode: siteSummary.code,
        siteName: siteSummary.name,
        routeSiteId: siteSummary.routeSiteId,
        shiftLabel: shiftLabel,
        shiftWindow: shiftWindow,
        clockInLabel: clockInLabel,
        status: status,
        signalState: signalState,
        hasSyncIssue: hasSyncIssue,
        lastSyncLabel: lastSyncAtUtc == null
            ? seed.lastSyncLabel
            : _relativeTimeLabel(lastSyncAtUtc),
        assignmentLabel: assignmentLabel,
        readinessLabel: readinessLabel,
        readinessDetail: readinessDetail,
        locationLabel: locationLabel,
        lastMovementLabel: lastMovementLabel,
        avgResponseLabel: avgResponse,
        obEntries: obEntries == 0 ? seed.obEntries : obEntries,
        incidents: incidents == 0 ? seed.incidents : incidents,
        performanceNote: hasSyncIssue
            ? 'Telemetry retries detected. Hold as secondary until sync stabilises.'
            : seed.performanceNote,
        zaraHeadline: zaraHeadline,
        zaraDetail: zaraDetail,
        lastSyncAtUtc: lastSyncAtUtc,
        clockInAtUtc: clockInAtUtc,
        lastPosition: latestPosition,
      );
    }).toList(growable: false);
  }

  _GuardOperationalStatus _guardStatusFromLive({
    required GuardAssignment? assignment,
    required List<GuardSyncOperation> operations,
    required _GuardOperationalStatus fallback,
  }) {
    for (final operation in operations) {
      final status = _guardDutyStatusFromOperation(operation);
      if (status == null) {
        continue;
      }
      return _guardOperationalStatusFromDutyStatus(status);
    }
    if (assignment != null) {
      return _guardOperationalStatusFromDutyStatus(assignment.status);
    }
    return fallback;
  }

  GuardDutyStatus? _guardDutyStatusFromOperation(GuardSyncOperation operation) {
    final rawStatus = (operation.payload['status'] ?? '').toString().trim();
    return GuardDutyStatus.values.cast<GuardDutyStatus?>().firstWhere(
      (value) => value != null && value.name == rawStatus,
      orElse: () => null,
    );
  }

  _GuardOperationalStatus _guardOperationalStatusFromDutyStatus(
    GuardDutyStatus status,
  ) {
    return switch (status) {
      GuardDutyStatus.available || GuardDutyStatus.clear =>
        _GuardOperationalStatus.ready,
      GuardDutyStatus.enRoute ||
      GuardDutyStatus.onSite ||
      GuardDutyStatus.panic =>
        _GuardOperationalStatus.engaged,
      GuardDutyStatus.offline => _GuardOperationalStatus.offline,
    };
  }

  _SignalState _signalStateFromLive({
    required _GuardOperationalStatus status,
    required GuardPositionSummary? latestPosition,
    required List<GuardSyncOperation> operations,
    required bool hasSyncIssue,
    required _SignalState fallback,
  }) {
    if (status == _GuardOperationalStatus.offline ||
        status == _GuardOperationalStatus.unavailable) {
      return _SignalState.lost;
    }
    if (hasSyncIssue) {
      return _SignalState.degraded;
    }
    final referenceTime = latestPosition?.recordedAtUtc ??
        (operations.isEmpty ? null : operations.first.createdAt.toUtc());
    if (referenceTime == null) {
      return fallback;
    }
    final elapsed = DateTime.now().toUtc().difference(referenceTime);
    if (elapsed.inMinutes >= 5) {
      return _SignalState.degraded;
    }
    return _SignalState.strong;
  }

  ({String code, String name, String routeSiteId}) _siteSummary(
    String routeSiteId,
    _WorkforceGuard seed,
  ) {
    final normalized = routeSiteId.trim().toLowerCase();
    if (normalized.isEmpty) {
      return (code: seed.siteCode, name: seed.siteName, routeSiteId: seed.routeSiteId);
    }
    for (final guard in _seedGuards) {
      if (guard.routeSiteId.trim().toLowerCase() == normalized ||
          guard.siteCode.trim().toLowerCase() == normalized) {
        return (
          code: guard.siteCode,
          name: guard.siteName,
          routeSiteId: guard.routeSiteId,
        );
      }
    }
    return (
      code: normalized.toUpperCase(),
      name: _humanizeScopeLabel(routeSiteId),
      routeSiteId: routeSiteId,
    );
  }

  String _shiftLabelFor(DateTime? startedAtUtc, String fallback) {
    if (startedAtUtc == null) {
      return fallback;
    }
    final hour = startedAtUtc.toUtc().hour;
    return hour >= 6 && hour < 18 ? 'Day' : 'Night';
  }

  String _shiftWindowFor(String shiftLabel) {
    return shiftLabel == 'Day' ? '06:00 - 18:00' : '18:00 - 06:00';
  }

  String _timeLabel(DateTime value) {
    final utc = value.toUtc();
    return '${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')}';
  }

  String _relativeTimeLabel(DateTime value) {
    final elapsed = DateTime.now().toUtc().difference(value.toUtc());
    if (elapsed.inSeconds < 60) {
      return '${elapsed.inSeconds.clamp(0, 59)}s ago';
    }
    if (elapsed.inMinutes < 60) {
      return '${elapsed.inMinutes}m ago';
    }
    if (elapsed.inHours < 24) {
      return '${elapsed.inHours}h ago';
    }
    return '${elapsed.inDays}d ago';
  }

  String _assignmentLabelForStatus(
    _GuardOperationalStatus status,
    String siteName,
  ) {
    return switch (status) {
      _GuardOperationalStatus.ready => 'Coverage live · $siteName',
      _GuardOperationalStatus.engaged => 'Dispatch-linked task · $siteName',
      _GuardOperationalStatus.offline => 'Telemetry lost · $siteName',
      _GuardOperationalStatus.unavailable => 'Standby pool',
    };
  }

  String _readinessLabel(_GuardOperationalStatus status) {
    return switch (status) {
      _GuardOperationalStatus.ready => 'Ready',
      _GuardOperationalStatus.engaged => 'Engaged',
      _GuardOperationalStatus.offline => 'Offline',
      _GuardOperationalStatus.unavailable => 'Unavailable',
    };
  }

  String _readinessDetail(
    _GuardOperationalStatus status,
    bool hasSyncIssue,
    String siteName,
  ) {
    if (hasSyncIssue) {
      return 'Sync issue present. Verify telemetry before rotating this guard into a new incident.';
    }
    return switch (status) {
      _GuardOperationalStatus.ready =>
        'Immediate response candidate for $siteName with clean patrol posture.',
      _GuardOperationalStatus.engaged =>
        'Currently working a live assignment. Use as secondary until the task closes.',
      _GuardOperationalStatus.offline =>
        'Connection lost. Do not use for dispatch until contact and telemetry recover.',
      _GuardOperationalStatus.unavailable =>
        'Not rostered into the current live workforce layer.',
    };
  }

  String _avgResponseLabel({
    required GuardAssignment? assignment,
    required List<GuardSyncOperation> operations,
    required String fallback,
  }) {
    if (assignment == null) {
      return fallback;
    }
    for (final operation in operations) {
      final status = _guardDutyStatusFromOperation(operation);
      if (status != GuardDutyStatus.enRoute && status != GuardDutyStatus.onSite) {
        continue;
      }
      final delta = operation.createdAt.difference(assignment.issuedAt);
      return '${delta.inMinutes.clamp(0, 99)}m ${delta.inSeconds.remainder(60).toString().padLeft(2, '0')}s';
    }
    return fallback;
  }

  String _zaraHeadline(
    _GuardOperationalStatus status,
    bool hasSyncIssue,
    String callsign,
  ) {
    if (hasSyncIssue) {
      return '$callsign is still operational, but Zara wants telemetry confidence restored before escalation.';
    }
    return switch (status) {
      _GuardOperationalStatus.ready =>
        '$callsign is a strong responder candidate for the next verified incident.',
      _GuardOperationalStatus.engaged =>
        '$callsign is already committed to live work and should be treated as depth only.',
      _GuardOperationalStatus.offline =>
        '$callsign should stay out of dispatch decisions until the signal returns.',
      _GuardOperationalStatus.unavailable =>
        '$callsign remains useful for planning, not the live response loop.',
    };
  }

  String _zaraDetail(
    _GuardOperationalStatus status,
    bool hasSyncIssue,
    String siteName,
  ) {
    if (hasSyncIssue) {
      return 'Use another ready guard for $siteName and hold this unit in reserve while sync retries continue.';
    }
    return switch (status) {
      _GuardOperationalStatus.ready =>
        'Position, response cadence, and current workload support immediate use at $siteName.',
      _GuardOperationalStatus.engaged =>
        'Protect current task integrity first, then reintroduce this guard once the current incident stabilises.',
      _GuardOperationalStatus.offline =>
        'Fallback to another unit and run a contact check before trusting this guard as available.',
      _GuardOperationalStatus.unavailable =>
        'Keep this guard in future coverage planning rather than the live incident queue.',
    };
  }

  String _humanizeScopeLabel(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return '-';
    }
    return normalized
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          final lower = part.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  List<_CoverageLane> _buildCoverageRows(List<_WorkforceGuard> guards) {
    final grouped = <String, List<_WorkforceGuard>>{};
    for (final guard in guards.where((guard) => guard.siteCode != '--')) {
      grouped.putIfAbsent(guard.siteCode, () => <_WorkforceGuard>[]).add(guard);
    }
    final siteCodes = grouped.keys.toList(growable: false)..sort();
    return siteCodes.map((siteCode) {
      final siteGuards = grouped[siteCode]!;
      final siteName = siteGuards.first.siteName;
      final zoneLabel = switch (siteCode) {
        'SE-01' => 'North boulevard',
        'WF-02' => 'Gatehouse and south river',
        'BR-03' => 'West perimeter',
        _ => 'Primary zone',
      };
      final days = List<_CoverageCell>.generate(7, (index) {
        final assignments = _coverageAssignmentsForDay(siteGuards, siteCode, index);
        final state = assignments.isEmpty
            ? _CoverageState.gap
            : assignments.length == 1
                ? _CoverageState.thin
                : _CoverageState.full;
        final note = switch (state) {
          _CoverageState.full => 'Fully covered',
          _CoverageState.thin => 'Thin layer',
          _CoverageState.gap => 'Gap',
        };
        return _CoverageCell(
          dayLabel: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][index],
          state: state,
          assignments: assignments,
          note: note,
        );
      });
      final quality = days.any((day) => day.state == _CoverageState.gap)
          ? _CoverageState.gap
          : days.any((day) => day.state == _CoverageState.thin)
              ? _CoverageState.thin
              : _CoverageState.full;
      return _CoverageLane(
        siteCode: siteCode,
        siteName: siteName,
        zoneLabel: zoneLabel,
        quality: quality,
        days: days,
      );
    }).toList(growable: false);
  }

  List<String> _coverageAssignmentsForDay(
    List<_WorkforceGuard> siteGuards,
    String siteCode,
    int dayIndex,
  ) {
    final callsigns = siteGuards
        .where((guard) => guard.status != _GuardOperationalStatus.unavailable)
        .map((guard) => guard.callsign)
        .toList(growable: false);
    if (callsigns.isEmpty) {
      return const <String>[];
    }
    if (siteCode == 'BR-03' && (dayIndex == 2 || dayIndex == 5)) {
      return <String>[callsigns.first];
    }
    if (siteCode == 'WF-02' && dayIndex == 4) {
      return const <String>[];
    }
    if (siteCode == 'SE-01' && dayIndex == 6) {
      return callsigns.take(1).toList(growable: false);
    }
    return callsigns.take(2).toList(growable: false);
  }

  List<_HistoryEntry> _buildHistoryEntries(List<_WorkforceGuard> guards) {
    final nowUtc = DateTime.now().toUtc();
    return guards
        .where((guard) => guard.siteCode != '--')
        .map((guard) {
          final flags = <_HistoryFlag>[
            if (_isLateStart(guard.clockInLabel, guard.shiftLabel)) _HistoryFlag.lateStart,
            if (_isExtendedShift(guard, nowUtc)) _HistoryFlag.extendedShift,
            if (_hasNoMovement(guard)) _HistoryFlag.noMovement,
            if (_hasHighActivity(guard)) _HistoryFlag.highActivity,
          ];
          return _HistoryEntry(
            shiftDateLabel: _historyDateLabel(nowUtc),
            guardName: guard.fullName,
            callsign: guard.callsign,
            siteLabel: '${guard.siteCode} · ${guard.siteName}',
            shiftWindow: guard.shiftWindow,
            durationLabel: _durationLabelForGuard(guard, nowUtc),
            startLabel: guard.clockInLabel,
            endLabel: guard.status == _GuardOperationalStatus.engaged ||
                    guard.status == _GuardOperationalStatus.ready
                ? 'Live'
                : '--',
            movementLabel: guard.lastMovementLabel,
            activityLabel: '${guard.obEntries} OB · ${guard.incidents} incident',
            flags: flags,
            zaraNote: _historyZaraNote(flags, guard),
          );
        })
        .toList(growable: false)
      ..sort((left, right) => right.flags.length.compareTo(left.flags.length));
  }

  bool _isLateStart(String clockInLabel, String shiftLabel) {
    if (clockInLabel == '--') {
      return false;
    }
    final parts = clockInLabel.split(':');
    if (parts.length != 2) {
      return false;
    }
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = int.tryParse(parts.last) ?? 0;
    final scheduledHour = shiftLabel == 'Day' ? 6 : 18;
    return hour > scheduledHour || (hour == scheduledHour && minute >= 10);
  }

  bool _isExtendedShift(_WorkforceGuard guard, DateTime nowUtc) {
    if (guard.clockInAtUtc == null) {
      return guard.shiftLabel == 'Day';
    }
    return nowUtc.difference(guard.clockInAtUtc!.toUtc()).inHours >= 12;
  }

  bool _hasNoMovement(_WorkforceGuard guard) {
    return guard.signalState != _SignalState.strong ||
        guard.lastMovementLabel.toLowerCase().contains('no movement');
  }

  bool _hasHighActivity(_WorkforceGuard guard) {
    return guard.obEntries >= 18 || guard.incidents >= 4;
  }

  String _historyDateLabel(DateTime utc) {
    return '${utc.year}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}';
  }

  String _durationLabelForGuard(_WorkforceGuard guard, DateTime nowUtc) {
    if (guard.clockInAtUtc == null) {
      return guard.shiftLabel == 'Standby' ? '--' : '12h 00m';
    }
    final elapsed = nowUtc.difference(guard.clockInAtUtc!.toUtc());
    return '${elapsed.inHours}h ${elapsed.inMinutes.remainder(60).toString().padLeft(2, '0')}m';
  }

  String _historyZaraNote(List<_HistoryFlag> flags, _WorkforceGuard guard) {
    if (flags.isEmpty) {
      return 'Pattern stable. ${guard.callsign} is tracking within expected workforce norms.';
    }
    if (flags.contains(_HistoryFlag.extendedShift)) {
      return 'Fatigue watch recommended before ${guard.callsign} takes another live dispatch.';
    }
    if (flags.contains(_HistoryFlag.noMovement)) {
      return 'Cross-check ${guard.callsign} with CCTV to confirm patrol continuity.';
    }
    if (flags.contains(_HistoryFlag.highActivity)) {
      return 'High event load suggests ${guard.callsign} may need relief on the next coverage layer.';
    }
    return 'Late-start marker detected. Review roster staging for ${guard.callsign}.';
  }

  Color _statusColor(_GuardOperationalStatus status) {
    return switch (status) {
      _GuardOperationalStatus.ready => _workforceGreen,
      _GuardOperationalStatus.engaged => _workforcePurple,
      _GuardOperationalStatus.offline => _workforceRed,
      _GuardOperationalStatus.unavailable => _workforceAmber,
    };
  }

  String _guardStatusLabel(_GuardOperationalStatus status) {
    return switch (status) {
      _GuardOperationalStatus.ready => 'READY',
      _GuardOperationalStatus.engaged => 'ENGAGED',
      _GuardOperationalStatus.offline => 'OFFLINE',
      _GuardOperationalStatus.unavailable => 'UNAVAILABLE',
    };
  }

  Color _signalColor(_SignalState signalState) {
    return switch (signalState) {
      _SignalState.strong => _workforceGreen,
      _SignalState.degraded => _workforceAmber,
      _SignalState.lost => _workforceRed,
    };
  }

  String _signalLabel(_SignalState signalState) {
    return switch (signalState) {
      _SignalState.strong => 'STRONG',
      _SignalState.degraded => 'DEGRADED',
      _SignalState.lost => 'LOST',
    };
  }

  int _signalBars(_SignalState signalState) {
    return switch (signalState) {
      _SignalState.strong => 3,
      _SignalState.degraded => 2,
      _SignalState.lost => 1,
    };
  }

  Color _coverageColor(_CoverageState state) {
    return switch (state) {
      _CoverageState.full => _workforceGreen,
      _CoverageState.thin => _workforceAmber,
      _CoverageState.gap => _workforceRed,
    };
  }

  String _coverageLabel(_CoverageState state) {
    return switch (state) {
      _CoverageState.full => 'FULL',
      _CoverageState.thin => 'THIN',
      _CoverageState.gap => 'GAP',
    };
  }

  Color _historyFlagColor(_HistoryFlag flag) {
    return switch (flag) {
      _HistoryFlag.lateStart => _workforceAmber,
      _HistoryFlag.extendedShift => _workforceRed,
      _HistoryFlag.noMovement => _workforcePurple,
      _HistoryFlag.highActivity => _workforceGreen,
    };
  }

  String _historyFlagLabel(_HistoryFlag flag) {
    return switch (flag) {
      _HistoryFlag.lateStart => 'LATE START',
      _HistoryFlag.extendedShift => 'EXTENDED SHIFT',
      _HistoryFlag.noMovement => 'NO MOVEMENT',
      _HistoryFlag.highActivity => 'HIGH ACTIVITY',
    };
  }

  void _setSiteFilter(String siteCode) {
    if (_siteFilter == siteCode) {
      return;
    }
    setState(() {
      _siteFilter = siteCode;
      final filtered = _filteredGuards(siteCodeOverride: siteCode);
      if (filtered.isNotEmpty) {
        _selectedGuardId = filtered.first.id;
      }
    });
  }

  void _selectGuard(String guardId) {
    if (_selectedGuardId == guardId) {
      return;
    }
    setState(() {
      _selectedGuardId = guardId;
    });
  }

  void _exportWorkforceSnapshot() {
    _showSnack('Workforce snapshot export is ready for the next wiring pass.');
  }

  void _openGuardScheduleForAction(String action, {DateTime? date}) {
    final actionCallback = widget.onOpenGuardScheduleForAction;
    final callback = widget.onOpenGuardSchedule;
    if (actionCallback == null && callback == null) {
      return;
    }
    logUiAction(
      'guards_workforce_schedule_opened',
      context: <String, Object?>{
        'action': action,
        if (date != null) 'date': date.toIso8601String(),
        'site_filter': _siteFilter,
      },
    );
    if (actionCallback != null) {
      actionCallback(action, date: date);
      return;
    }
    callback?.call();
  }

  Future<void> _copyGuardContact(_WorkforceGuard guard) async {
    await Clipboard.setData(ClipboardData(text: guard.contactPhone));
    if (!mounted) {
      return;
    }
    _showSnack('${guard.fullName} contact copied.');
  }

  Future<void> _showGuardContactSheet(_WorkforceGuard guard) async {
    final clientLaneAvailable = widget.onOpenClientLaneForSite != null;
    final voipAvailable = widget.onStageGuardVoipCall != null;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: _workforceSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final textTheme = Theme.of(sheetContext).textTheme.merge(
              OnyxTheme.dark().textTheme,
            );
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Guard Contact',
                style: textTheme.headlineSmall?.copyWith(
                  color: _workforceTitle,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${guard.callsign} · ${guard.fullName}',
                style: textTheme.bodyMedium?.copyWith(
                  color: _workforceBody,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _detailList(
                textTheme,
                <(String, String)>[
                  ('Contact', guard.contactPhone),
                  ('Site', guard.siteName),
                  ('Status', _guardStatusLabel(guard.status)),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _tonalChip(
                    clientLaneAvailable ? 'Client lane ready' : 'Client lane offline',
                    clientLaneAvailable ? _workforceGreen : _workforceAmber,
                    textTheme,
                  ),
                  _tonalChip(
                    voipAvailable ? 'VoIP staging ready' : 'VoIP staging offline',
                    voipAvailable ? _workforceSky : _workforceAmber,
                    textTheme,
                  ),
                ],
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
                      label: Text(
                        'Copy Contact',
                        style: textTheme.labelLarge?.copyWith(
                          color: _workforceTitle,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _workforceTitle,
                        side: const BorderSide(color: _workforceBorderSubtle),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: clientLaneAvailable || voipAvailable
                          ? () async {
                              Navigator.of(sheetContext).pop();
                              if (clientLaneAvailable) {
                                widget.onOpenClientLaneForSite?.call(guard.routeSiteId);
                                return;
                              }
                              final stageCall = widget.onStageGuardVoipCall;
                              if (stageCall == null) {
                                return;
                              }
                              try {
                                final message = await stageCall(
                                  guard.id,
                                  guard.fullName,
                                  guard.routeSiteId,
                                  guard.contactPhone,
                                );
                                if (!mounted) {
                                  return;
                                }
                                _showSnack(message);
                              } catch (_) {
                                if (!mounted) {
                                  return;
                                }
                                _showSnack('VoIP staging failed for ${guard.callsign}.');
                              }
                            }
                          : null,
                      icon: const Icon(Icons.phone_forwarded_rounded, size: 16),
                      label: Text(
                        clientLaneAvailable ? 'Open Client Lane' : 'Stage VoIP',
                        style: textTheme.labelLarge?.copyWith(
                          color: _workforceTitle,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _workforcePurple,
                        foregroundColor: _workforceTitle,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
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

  void _openReportsForGuard(_WorkforceGuard guard) {
    final callback = widget.onOpenGuardReportsForSite;
    if (callback == null) {
      _showSnack('Activity review workspace is ready for ${guard.callsign}.');
      return;
    }
    callback(guard.routeSiteId);
  }

  void _showDispatchReadySnack(_WorkforceGuard guard) {
    logUiAction(
      'guards_workforce_dispatch_ready',
      context: <String, Object?>{
        'guard_id': guard.id,
        'site_id': guard.routeSiteId,
      },
    );
    _showSnack(
      'Dispatch hook ready: ${guard.callsign} can be handed into Queue/Dispatch when that binding lands.',
    );
  }

  void _showLiveLocation(_WorkforceGuard guard) {
    final position = guard.lastPosition;
    if (position == null) {
      _showSnack('Live position bridge is ready for ${guard.callsign}, but no coordinates are available yet.');
      return;
    }
    _showSnack(
      '${guard.callsign} live position: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _workforceSurface,
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: _workforceTitle,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
