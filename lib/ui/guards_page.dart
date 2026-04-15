import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/guard_sync_repository.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/guard/guard_mobile_ops.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'theme/onyx_design_tokens.dart';
import 'ui_action_logger.dart';

// ── Colour aliases ──────────────────────────────────────────────────────────
const _bg = OnyxColorTokens.backgroundPrimary;
const _surface = OnyxColorTokens.backgroundSecondary;
const _titleColor = OnyxColorTokens.textPrimary;
const _bodyColor = OnyxColorTokens.textSecondary;
const _mutedColor = OnyxColorTokens.textMuted;
const _dividerColor = OnyxColorTokens.divider;
const _brand = OnyxColorTokens.brand;
const _selectedSurface = OnyxColorTokens.cyanSurface;
const _greenColor = OnyxColorTokens.accentGreen;
const _amberColor = OnyxColorTokens.accentAmber;
const _skyColor = OnyxColorTokens.accentSky;

// ── Enums ───────────────────────────────────────────────────────────────────

enum _GuardStatus { onDuty, offDuty }

enum _GuardContactMode { message, call }

enum _GuardsView { active, roster, history }

// ── Data models ─────────────────────────────────────────────────────────────

class _GuardRecord {
  final String id;
  final String displayName;
  final String contactName;
  final String employeeId;
  final String siteCode;
  final String siteName;
  final String routeSiteId;
  final String contactPhone;
  final _GuardStatus status;
  final bool hasSyncIssue;
  final String clockIn;
  final String shiftWindow;
  final String lastSync;
  final int obEntries;
  final int incidents;
  final String avgResponse;
  final String rating;
  final String shiftLabel;
  final String handler;
  final String? assignmentNote;

  const _GuardRecord({
    required this.id,
    required this.displayName,
    required this.contactName,
    required this.employeeId,
    required this.siteCode,
    required this.siteName,
    required this.routeSiteId,
    required this.contactPhone,
    required this.status,
    required this.hasSyncIssue,
    required this.clockIn,
    required this.shiftWindow,
    required this.lastSync,
    required this.obEntries,
    required this.incidents,
    required this.avgResponse,
    required this.rating,
    required this.shiftLabel,
    required this.handler,
    this.assignmentNote,
  });
}

class _ShiftBlock {
  final String label;
  final String time;
  final Color foreground;
  final Color background;
  final Color border;

  const _ShiftBlock({
    required this.label,
    required this.time,
    required this.foreground,
    required this.background,
    required this.border,
  });
}

class _ShiftRosterRow {
  final String displayName;
  final String employeeId;
  final String siteCode;
  final String siteName;
  final List<_ShiftBlock?> blocks;

  const _ShiftRosterRow({
    required this.displayName,
    required this.employeeId,
    required this.siteCode,
    required this.siteName,
    required this.blocks,
  });
}

class _ShiftHistoryRow {
  final String date;
  final String displayName;
  final String employeeId;
  final String siteCode;
  final String siteName;
  final String clockIn;
  final String clockOut;
  final String duration;
  final String statusLabel;
  final Color statusForeground;
  final Color statusBackground;
  final Color statusBorder;
  final String handledBy;

  const _ShiftHistoryRow({
    required this.date,
    required this.displayName,
    required this.employeeId,
    required this.siteCode,
    required this.siteName,
    required this.clockIn,
    required this.clockOut,
    required this.duration,
    required this.statusLabel,
    required this.statusForeground,
    required this.statusBackground,
    required this.statusBorder,
    required this.handledBy,
  });
}

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

// ── Widget ───────────────────────────────────────────────────────────────────

class GuardsPage extends StatefulWidget {
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

  const GuardsPage({
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
  State<GuardsPage> createState() => _GuardsPageState();
}

class _GuardsPageState extends State<GuardsPage> {
  // ── Static data ───────────────────────────────────────────────────────────

  static const _nightBlock = _ShiftBlock(
    label: 'NIGHT',
    time: '18:00 - 06:00',
    foreground: OnyxColorTokens.accentSky,
    background: OnyxColorTokens.purpleSurface,
    border: OnyxColorTokens.purpleBorder,
  );

  static const _dayBlock = _ShiftBlock(
    label: 'DAY',
    time: '06:00 - 18:00',
    foreground: OnyxColorTokens.accentAmber,
    background: OnyxColorTokens.amberSurface,
    border: OnyxColorTokens.amberBorder,
  );

  static const List<_GuardRecord> _guards = [
    _GuardRecord(
      id: 'GRD-441',
      displayName: 'T. Nkosi',
      contactName: 'Thabo Mokoena',
      employeeId: 'G-2441',
      siteCode: 'SE-01',
      siteName: 'Sandton Estate North',
      routeSiteId: 'WTF-MAIN',
      contactPhone: '+27 82 555 0441',
      status: _GuardStatus.onDuty,
      hasSyncIssue: false,
      clockIn: '18:00',
      shiftWindow: '18:00 - 06:00',
      lastSync: '5s ago',
      obEntries: 24,
      incidents: 8,
      avgResponse: '142s',
      rating: '4.8',
      shiftLabel: 'Night',
      handler: 'Emily Davis',
    ),
    _GuardRecord(
      id: 'GRD-442',
      displayName: 'J. van Wyk',
      contactName: 'Johan van Wyk',
      employeeId: 'G-2442',
      siteCode: 'WF-02',
      siteName: 'Waterfall Estate',
      routeSiteId: 'WF-02',
      contactPhone: '+27 83 222 0442',
      status: _GuardStatus.onDuty,
      hasSyncIssue: true,
      clockIn: '18:00',
      shiftWindow: '18:00 - 06:00',
      lastSync: '1m ago',
      obEntries: 18,
      incidents: 6,
      avgResponse: '151s',
      rating: '4.6',
      shiftLabel: 'Night',
      handler: 'Sarah J.',
    ),
    _GuardRecord(
      id: 'GRD-443',
      displayName: 'K. Dlamini',
      contactName: 'Kabelo Dlamini',
      employeeId: 'G-2443',
      siteCode: 'BR-03',
      siteName: 'Blue Ridge Residence',
      routeSiteId: 'BR-03',
      contactPhone: '+27 84 333 0443',
      status: _GuardStatus.onDuty,
      hasSyncIssue: false,
      clockIn: '18:00',
      shiftWindow: '18:00 - 06:00',
      lastSync: '9s ago',
      obEntries: 16,
      incidents: 5,
      avgResponse: '148s',
      rating: '4.7',
      shiftLabel: 'Night',
      handler: 'John S.',
    ),
    _GuardRecord(
      id: 'GRD-444',
      displayName: 'S. Mabaso',
      contactName: 'Sizwe Mabaso',
      employeeId: 'G-2444',
      siteCode: '--',
      siteName: 'No active assignment',
      routeSiteId: '',
      contactPhone: '+27 81 444 0444',
      status: _GuardStatus.offDuty,
      hasSyncIssue: false,
      clockIn: '--',
      shiftWindow: '--',
      lastSync: 'offline',
      obEntries: 9,
      incidents: 1,
      avgResponse: '--',
      rating: '4.5',
      shiftLabel: 'Off Duty',
      handler: 'Standby',
      assignmentNote: 'No active assignment',
    ),
    _GuardRecord(
      id: 'GRD-445',
      displayName: 'M. Pillay',
      contactName: 'Maya Pillay',
      employeeId: 'G-2445',
      siteCode: 'SE-01',
      siteName: 'Sandton Estate North',
      routeSiteId: 'SE-01',
      contactPhone: '+27 82 555 0445',
      status: _GuardStatus.onDuty,
      hasSyncIssue: false,
      clockIn: '06:00',
      shiftWindow: '06:00 - 18:00',
      lastSync: '12s ago',
      obEntries: 19,
      incidents: 3,
      avgResponse: '134s',
      rating: '4.9',
      shiftLabel: 'Day',
      handler: 'Mike W.',
    ),
    _GuardRecord(
      id: 'GRD-446',
      displayName: 'L. Ndlovu',
      contactName: 'Lerato Ndlovu',
      employeeId: 'G-2446',
      siteCode: 'WF-02',
      siteName: 'Waterfall Estate',
      routeSiteId: 'WF-02',
      contactPhone: '+27 82 555 0446',
      status: _GuardStatus.onDuty,
      hasSyncIssue: false,
      clockIn: '06:00',
      shiftWindow: '06:00 - 18:00',
      lastSync: '11s ago',
      obEntries: 14,
      incidents: 2,
      avgResponse: '139s',
      rating: '4.7',
      shiftLabel: 'Day',
      handler: 'Mike W.',
    ),
  ];

  static const List<_ShiftRosterRow> _shiftRosterRows = [
    _ShiftRosterRow(
      displayName: 'T. Nkosi',
      employeeId: 'G-2441',
      siteCode: 'SE-01',
      siteName: 'Sandton Estate North',
      blocks: [_nightBlock, _nightBlock, _nightBlock, _nightBlock, _nightBlock],
    ),
    _ShiftRosterRow(
      displayName: 'J. van Wyk',
      employeeId: 'G-2442',
      siteCode: 'WF-02',
      siteName: 'Waterfall Estate',
      blocks: [_nightBlock, _nightBlock, _nightBlock, _nightBlock, _nightBlock],
    ),
    _ShiftRosterRow(
      displayName: 'K. Dlamini',
      employeeId: 'G-2443',
      siteCode: 'BR-03',
      siteName: 'Blue Ridge Residence',
      blocks: [_nightBlock, _nightBlock, _nightBlock, _nightBlock, _nightBlock],
    ),
    _ShiftRosterRow(
      displayName: 'S. Mabaso',
      employeeId: 'G-2444',
      siteCode: '--',
      siteName: 'Unassigned',
      blocks: [null, null, null, null, null],
    ),
    _ShiftRosterRow(
      displayName: 'M. Pillay',
      employeeId: 'G-2445',
      siteCode: 'SE-01',
      siteName: 'Sandton Estate North',
      blocks: [_dayBlock, _dayBlock, _dayBlock, _dayBlock, _dayBlock],
    ),
    _ShiftRosterRow(
      displayName: 'L. Ndlovu',
      employeeId: 'G-2446',
      siteCode: 'WF-02',
      siteName: 'Waterfall Estate',
      blocks: [_dayBlock, _dayBlock, _dayBlock, _dayBlock, _dayBlock],
    ),
  ];

  static const List<_ShiftHistoryRow> _shiftHistoryRows = [
    _ShiftHistoryRow(
      date: '2026-03-25',
      displayName: 'T. Nkosi',
      employeeId: 'G-2441',
      siteCode: 'SE-01',
      siteName: 'Sandton Estate North',
      clockIn: '18:00',
      clockOut: 'In Progress',
      duration: '5h 42m',
      statusLabel: 'ACTIVE',
      statusForeground: OnyxColorTokens.accentCyanTrue,
      statusBackground: OnyxColorTokens.cyanSurface,
      statusBorder: OnyxColorTokens.cyanBorder,
      handledBy: 'Emily Davis',
    ),
    _ShiftHistoryRow(
      date: '2026-03-25',
      displayName: 'J. van Wyk',
      employeeId: 'G-2442',
      siteCode: 'WF-02',
      siteName: 'Waterfall Estate',
      clockIn: '18:00',
      clockOut: 'In Progress',
      duration: '5h 42m',
      statusLabel: 'ACTIVE',
      statusForeground: OnyxColorTokens.accentCyanTrue,
      statusBackground: OnyxColorTokens.cyanSurface,
      statusBorder: OnyxColorTokens.cyanBorder,
      handledBy: 'Sarah J.',
    ),
    _ShiftHistoryRow(
      date: '2026-03-25',
      displayName: 'K. Dlamini',
      employeeId: 'G-2443',
      siteCode: 'BR-03',
      siteName: 'Blue Ridge Residence',
      clockIn: '18:00',
      clockOut: 'In Progress',
      duration: '5h 42m',
      statusLabel: 'ACTIVE',
      statusForeground: OnyxColorTokens.accentCyanTrue,
      statusBackground: OnyxColorTokens.cyanSurface,
      statusBorder: OnyxColorTokens.cyanBorder,
      handledBy: 'John S.',
    ),
    _ShiftHistoryRow(
      date: '2026-03-25',
      displayName: 'M. Pillay',
      employeeId: 'G-2445',
      siteCode: 'SE-01',
      siteName: 'Sandton Estate North',
      clockIn: '06:00',
      clockOut: 'In Progress',
      duration: '17h 42m',
      statusLabel: 'ACTIVE',
      statusForeground: OnyxColorTokens.accentCyanTrue,
      statusBackground: OnyxColorTokens.cyanSurface,
      statusBorder: OnyxColorTokens.cyanBorder,
      handledBy: 'Mike W.',
    ),
    _ShiftHistoryRow(
      date: '2026-03-25',
      displayName: 'L. Ndlovu',
      employeeId: 'G-2446',
      siteCode: 'WF-02',
      siteName: 'Waterfall Estate',
      clockIn: '06:00',
      clockOut: 'In Progress',
      duration: '17h 42m',
      statusLabel: 'ACTIVE',
      statusForeground: OnyxColorTokens.accentCyanTrue,
      statusBackground: OnyxColorTokens.cyanSurface,
      statusBorder: OnyxColorTokens.cyanBorder,
      handledBy: 'Mike W.',
    ),
    _ShiftHistoryRow(
      date: '2026-03-24',
      displayName: 'T. Nkosi',
      employeeId: 'G-2441',
      siteCode: 'SE-01',
      siteName: 'Sandton Estate North',
      clockIn: '18:00',
      clockOut: '06:00',
      duration: '12h 00m',
      statusLabel: 'COMPLETED',
      statusForeground: OnyxColorTokens.accentGreen,
      statusBackground: OnyxColorTokens.greenSurface,
      statusBorder: OnyxColorTokens.greenBorder,
      handledBy: 'Sarah J.',
    ),
    _ShiftHistoryRow(
      date: '2026-03-24',
      displayName: 'J. van Wyk',
      employeeId: 'G-2442',
      siteCode: 'WF-02',
      siteName: 'Waterfall Estate',
      clockIn: '18:00',
      clockOut: '06:00',
      duration: '12h 00m',
      statusLabel: 'COMPLETED',
      statusForeground: OnyxColorTokens.accentGreen,
      statusBackground: OnyxColorTokens.greenSurface,
      statusBorder: OnyxColorTokens.greenBorder,
      handledBy: 'John S.',
    ),
    _ShiftHistoryRow(
      date: '2026-03-24',
      displayName: 'K. Dlamini',
      employeeId: 'G-2443',
      siteCode: 'BR-03',
      siteName: 'Blue Ridge Residence',
      clockIn: '18:00',
      clockOut: '06:00',
      duration: '12h 00m',
      statusLabel: 'COMPLETED',
      statusForeground: OnyxColorTokens.accentGreen,
      statusBackground: OnyxColorTokens.greenSurface,
      statusBorder: OnyxColorTokens.greenBorder,
      handledBy: 'Emily Davis',
    ),
    _ShiftHistoryRow(
      date: '2026-03-24',
      displayName: 'M. Pillay',
      employeeId: 'G-2445',
      siteCode: 'SE-01',
      siteName: 'Sandton Estate North',
      clockIn: '06:00',
      clockOut: '18:00',
      duration: '12h 00m',
      statusLabel: 'COMPLETED',
      statusForeground: OnyxColorTokens.accentGreen,
      statusBackground: OnyxColorTokens.greenSurface,
      statusBorder: OnyxColorTokens.greenBorder,
      handledBy: 'Mike W.',
    ),
    _ShiftHistoryRow(
      date: '2026-03-24',
      displayName: 'L. Ndlovu',
      employeeId: 'G-2446',
      siteCode: 'WF-02',
      siteName: 'Waterfall Estate',
      clockIn: '06:00',
      clockOut: '18:00',
      duration: '12h 00m',
      statusLabel: 'COMPLETED',
      statusForeground: OnyxColorTokens.accentGreen,
      statusBackground: OnyxColorTokens.greenSurface,
      statusBorder: OnyxColorTokens.greenBorder,
      handledBy: 'Mike W.',
    ),
  ];

  // ── State ─────────────────────────────────────────────────────────────────

  String _siteFilter = 'ALL';
  String _selectedGuardId = _guards.first.id;
  _GuardsView _selectedView = _GuardsView.active;
  List<_GuardRecord>? _liveGuards;
  GuardsEvidenceReturnReceipt? _activeEvidenceReturnReceipt;

  bool get _canOpenGuardSchedule =>
      widget.onOpenGuardScheduleForAction != null ||
      widget.onOpenGuardSchedule != null;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _siteFilter = _resolveSiteFilter(widget.initialSiteFilter);
    _ingestEvidenceReturnReceipt(widget.evidenceReturnReceipt);
    unawaited(_loadLiveGuards());
  }

  @override
  void didUpdateWidget(covariant GuardsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.evidenceReturnReceipt?.auditId !=
        widget.evidenceReturnReceipt?.auditId) {
      _ingestEvidenceReturnReceipt(
        widget.evidenceReturnReceipt,
        useSetState: true,
      );
    }
    if (oldWidget.guardSyncRepositoryFuture != widget.guardSyncRepositoryFuture) {
      unawaited(_loadLiveGuards());
    }
  }

  void _ingestEvidenceReturnReceipt(
    GuardsEvidenceReturnReceipt? receipt, {
    bool useSetState = false,
  }) {
    if (receipt == null) return;
    void apply() => _activeEvidenceReturnReceipt = receipt;
    if (useSetState) {
      setState(apply);
    } else {
      apply();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onConsumeEvidenceReturnReceipt?.call(receipt.auditId);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filteredGuards = _filteredGuards();
    final selectedGuard = _selectedGuard(filteredGuards);
    final effectiveGuards = _effectiveGuards;

    return OnyxPageScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1100;
          final ultrawideSurface = isUltrawideLayout(
            context,
            viewportWidth: constraints.maxWidth,
          );
          final surfaceMaxWidth = commandSurfaceMaxWidth(
            context,
            compactDesktopWidth: 1540,
            viewportWidth: constraints.maxWidth,
            widescreenFillFactor: ultrawideSurface ? 1 : 0.96,
          );

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: surfaceMaxWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _pageHeader(),
                    if (_activeEvidenceReturnReceipt != null) ...[
                      const SizedBox(height: 12),
                      _evidenceReturnBanner(_activeEvidenceReturnReceipt!),
                    ],
                    const SizedBox(height: 16),
                    _statusAndFiltersBar(filteredGuards, effectiveGuards),
                    const SizedBox(height: 16),
                    _viewTabs(),
                    const SizedBox(height: 16),
                    switch (_selectedView) {
                      _GuardsView.active => _activeGuardsView(
                        context,
                        guards: filteredGuards,
                        selectedGuard: selectedGuard,
                        wide: wide,
                      ),
                      _GuardsView.roster => _shiftRosterView(filteredGuards),
                      _GuardsView.history => _shiftHistoryView(),
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

  // ── Page header ───────────────────────────────────────────────────────────

  Widget _pageHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Guards & workforce',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _titleColor,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Roster management, shift tracking, and operational readiness',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: _bodyColor,
              ),
            ),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _exportTimesheets,
          icon: const Icon(Icons.download_rounded, size: 16),
          label: Text(
            'Export timesheets',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: OnyxColorTokens.borderSubtle),
            foregroundColor: _bodyColor,
            minimumSize: const Size(0, 34),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  void _exportTimesheets() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _surface,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Export feature coming soon',
          style: GoogleFonts.inter(color: _titleColor, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ── Workforce status bar ──────────────────────────────────────────────────

  Widget _statusAndFiltersBar(
    List<_GuardRecord> guards,
    List<_GuardRecord> effectiveGuards,
  ) {
    final onDutyCount = guards
        .where((g) => g.status == _GuardStatus.onDuty)
        .length;
    final activeShifts = onDutyCount;
    final syncIssues = guards.where((g) => g.hasSyncIssue).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _dividerColor),
        borderRadius: OnyxRadiusTokens.radiusMd,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 1080;
          final statusGroup = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('WORKFORCE STATUS:', style: _capsLabelStyle()),
              _statusPill('$onDutyCount on duty', OnyxDesignTokens.greenNominal),
              _statusPill('$activeShifts active shifts', OnyxDesignTokens.cyanInteractive),
              if (syncIssues > 0)
                _statusPill('$syncIssues sync issues', OnyxDesignTokens.amberWarning),
            ],
          );
          final filterGroup = Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('FILTER BY SITE:', style: _capsLabelStyle()),
              for (final code in _availableSiteFilters(effectiveGuards))
                _siteFilterChip(code),
            ],
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [statusGroup, const SizedBox(height: 10), filterGroup],
            );
          }
          return Row(
            children: [
              Expanded(child: statusGroup),
              const SizedBox(width: 16),
              Flexible(child: filterGroup),
            ],
          );
        },
      ),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _siteFilterChip(String code) {
    final selected = _siteFilter == code;
    final label = code == 'ALL' ? 'All Sites' : code;
    return InkWell(
      key: ValueKey('guards-site-filter-$code'),
      onTap: () => _setSiteFilter(code),
      borderRadius: BorderRadius.circular(OnyxRadiusTokens.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? _selectedSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(OnyxRadiusTokens.pill),
          border: Border.all(
            color: selected ? _brand : OnyxColorTokens.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: selected ? _titleColor : _bodyColor,
          ),
        ),
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────

  Widget _viewTabs() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _dividerColor)),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(OnyxRadiusTokens.md),
        ),
      ),
      child: Row(
        children: [
          _guardTab('Active guards', Icons.people_alt_rounded, _GuardsView.active),
          _guardTab('Shift roster', Icons.calendar_month_rounded, _GuardsView.roster),
          _guardTab('Shift history', Icons.history_rounded, _GuardsView.history),
        ],
      ),
    );
  }

  Widget _guardTab(String label, IconData icon, _GuardsView view) {
    final selected = _selectedView == view;
    return GestureDetector(
      onTap: () => _setView(view),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minWidth: 120),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? _bg : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? _brand : Colors.transparent,
              width: 2,
            ),
            bottom: BorderSide(
              color: selected ? _brand : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? _titleColor : _mutedColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? _titleColor : _mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 0 — Active Guards ─────────────────────────────────────────────────

  Widget _activeGuardsView(
    BuildContext context, {
    required List<_GuardRecord> guards,
    required _GuardRecord? selectedGuard,
    required bool wide,
  }) {
    if (selectedGuard == null) {
      return _panelContainer(
        child: Center(
          child: Text(
            'No guards match the selected site filter.',
            style: GoogleFonts.inter(fontSize: 13, color: _bodyColor),
          ),
        ),
      );
    }

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _guardRosterPanel(guards),
          const SizedBox(height: 16),
          _guardDetailPanel(context, selectedGuard),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 300, child: _guardRosterPanel(guards)),
        const SizedBox(width: 16),
        Expanded(child: _guardDetailPanel(context, selectedGuard)),
      ],
    );
  }

  Widget _guardRosterPanel(List<_GuardRecord> guards) {
    return _panelContainer(
      key: const ValueKey('guards-roster-panel'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text('GUARD ROSTER', style: _capsLabelStyle()),
                const Spacer(),
                Text(
                  '${guards.length} guards',
                  style: GoogleFonts.inter(fontSize: 11, color: _bodyColor),
                ),
              ],
            ),
          ),
          Divider(color: _dividerColor, height: 1),
          for (final guard in guards) _guardRosterRow(guard, guards),
        ],
      ),
    );
  }

  Widget _guardRosterRow(_GuardRecord guard, List<_GuardRecord> guards) {
    final selected = guard.id == (_selectedGuard(guards)?.id ?? '');
    final isOnDuty = guard.status == _GuardStatus.onDuty;
    final statusColor = isOnDuty ? _greenColor : _mutedColor;
    final statusLabel = isOnDuty ? 'ON DUTY' : 'OFFLINE';

    return GestureDetector(
      onTap: () => _selectGuard(guard.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _selectedSurface : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? _brand : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guard.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${guard.employeeId} · ${guard.siteCode == '--' ? 'Unassigned' : guard.siteCode}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _bodyColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _guardStatusBadge(statusLabel, statusColor),
          ],
        ),
      ),
    );
  }

  Widget _guardStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(OnyxRadiusTokens.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _guardDetailPanel(BuildContext context, _GuardRecord guard) {
    final active = guard.status == _GuardStatus.onDuty;
    final initials = guard.displayName
        .split(' ')
        .take(2)
        .map((p) => p.isNotEmpty ? p[0] : '')
        .join()
        .toUpperCase();
    final statusColor = active ? _greenColor : _mutedColor;
    final statusLabel = active ? 'ON DUTY' : 'OFFLINE';

    return _panelContainer(
      key: const ValueKey('guards-detail-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar + name + badge + clock-out
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: 0.10),
                  borderRadius: OnyxRadiusTokens.radiusSm,
                  border: Border.all(color: OnyxColorTokens.borderSubtle),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _brand,
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
                      guard.displayName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      guard.employeeId,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _bodyColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _guardStatusBadge(statusLabel, statusColor),
              if (active) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _showClockOutNotice(guard),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OnyxColorTokens.accentRed,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.logout_rounded, size: 14),
                      const SizedBox(width: 4),
                      const Text('Clock out'),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: _dividerColor, height: 1),
          const SizedBox(height: 16),
          // Stats row
          LayoutBuilder(
            builder: (context, constraints) {
              final twoCol = constraints.maxWidth >= 500;
              final currentSite = _detailStatCard('CURRENT SITE', guard.siteName);
              final clockedIn = _detailStatCard('CLOCKED IN', guard.clockIn == '--' ? '—' : guard.clockIn);
              if (twoCol) {
                return Row(
                  children: [
                    Expanded(child: currentSite),
                    const SizedBox(width: 12),
                    Expanded(child: clockedIn),
                  ],
                );
              }
              return Column(
                children: [currentSite, const SizedBox(height: 10), clockedIn],
              );
            },
          ),
          const SizedBox(height: 12),
          // Sync health
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: guard.hasSyncIssue ? OnyxColorTokens.amberSurface : OnyxColorTokens.greenSurface,
              borderRadius: OnyxRadiusTokens.radiusSm,
              border: Border.all(
                color: guard.hasSyncIssue ? OnyxColorTokens.amberBorder : OnyxColorTokens.greenBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  guard.hasSyncIssue ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                  size: 16,
                  color: guard.hasSyncIssue ? _amberColor : _greenColor,
                ),
                const SizedBox(width: 8),
                Text(
                  guard.hasSyncIssue ? 'Sync issue' : 'Sync healthy',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _titleColor,
                  ),
                ),
                const Spacer(),
                Text(
                  'Last sync: ${guard.lastSync}',
                  style: GoogleFonts.inter(fontSize: 11, color: _bodyColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Performance metrics
          Text('PERFORMANCE METRICS', style: _capsLabelStyle()),
          const SizedBox(height: 6),
          Text(
            'Current period operational stats',
            style: GoogleFonts.inter(fontSize: 12, color: _bodyColor),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final metrics = [
                _metricCard('OB ENTRIES', '${guard.obEntries}'),
                _metricCard('INCIDENTS', '${guard.incidents}'),
                _metricCard('AVG RESPONSE', guard.avgResponse),
                _metricCard('RATING', guard.rating),
              ];
              final cols = constraints.maxWidth >= 480 ? 4 : 2;
              if (cols == 4) {
                return Row(
                  children: [
                    for (int i = 0; i < metrics.length; i++) ...[
                      Expanded(child: metrics[i]),
                      if (i < metrics.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                );
              }
              return GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.0,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: metrics,
              );
            },
          ),
          const SizedBox(height: 16),
          // Quick actions
          Text('ACTIONS', style: _capsLabelStyle()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _compactAction(
                key: const ValueKey('guards-quick-schedule'),
                icon: Icons.calendar_month_rounded,
                label: 'Planner',
                onTap: !_canOpenGuardSchedule ? null : _openGuardSchedule,
              ),
              _compactAction(
                key: const ValueKey('guards-quick-reports'),
                icon: Icons.description_outlined,
                label: 'Reports',
                onTap: widget.onOpenGuardReportsForSite == null
                    ? null
                    : () => _openReportsForSite(context, guard),
              ),
              _compactAction(
                key: const ValueKey('guards-quick-contact'),
                icon: Icons.forum_outlined,
                label: 'Contact',
                onTap: () => _showGuardContactSheet(
                  guard,
                  initialMode: _GuardContactMode.message,
                ),
              ),
              _compactAction(
                key: const ValueKey('guards-quick-voip'),
                icon: Icons.phone_forwarded_rounded,
                label: 'VoIP',
                onTap: () => _showGuardContactSheet(
                  guard,
                  initialMode: _GuardContactMode.call,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: OnyxRadiusTokens.radiusSm,
        border: Border.all(color: _dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _capsLabelStyle()),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _titleColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: OnyxRadiusTokens.radiusSm,
        border: Border.all(color: _dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _capsLabelStyle()),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _titleColor,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactAction({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: OnyxColorTokens.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: enabled ? _brand : _mutedColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled ? _titleColor : _mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1 — Shift Roster ──────────────────────────────────────────────────

  Widget _shiftRosterView(List<_GuardRecord> guards) {
    final rosterRows = (_liveGuards?.isNotEmpty ?? false)
        ? _buildShiftRosterRows(_effectiveGuards)
        : _shiftRosterRows;
    final visibleCodes = guards.map((g) => g.siteCode).toSet();
    final rows = _siteFilter == 'ALL'
        ? rosterRows
        : rosterRows
              .where(
                (r) => r.siteCode == _siteFilter || visibleCodes.contains(r.siteCode),
              )
              .toList(growable: false);

    return _panelContainer(
      key: const ValueKey('guards-shift-roster-panel'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WEEKLY SHIFT ROSTER', style: _capsLabelStyle()),
                    const SizedBox(height: 2),
                    Text(
                      'Scheduled shifts for all guards',
                      style: GoogleFonts.inter(fontSize: 11, color: _bodyColor),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _canOpenGuardSchedule ? _openGuardSchedule : null,
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: Text(
                    'Add shift',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: _dividerColor, height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    decoration: BoxDecoration(
                      color: _bg,
                      border: Border(bottom: BorderSide(color: _dividerColor)),
                    ),
                    child: Row(
                      children: [
                        _rosterColHeader('GUARD', width: 160),
                        _rosterColHeader('SITE', width: 140),
                        _rosterColHeader('MON', width: 110, centered: true),
                        _rosterColHeader('TUE', width: 110, centered: true),
                        _rosterColHeader('WED', width: 110, centered: true),
                        _rosterColHeader('THU', width: 110, centered: true),
                        _rosterColHeader('FRI', width: 110, centered: true),
                      ],
                    ),
                  ),
                  // Data rows
                  for (int i = 0; i < rows.length; i++) ...[
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      decoration: BoxDecoration(
                        color: i.isOdd ? _bg : Colors.transparent,
                        border: Border(bottom: BorderSide(color: _dividerColor)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _rosterGuardCell(rows[i], width: 160),
                          _rosterSiteCell(rows[i], width: 140),
                          for (final block in rows[i].blocks)
                            _rosterShiftCell(block, width: 110),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rosterColHeader(String label, {required double width, bool centered = false}) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        textAlign: centered ? TextAlign.center : TextAlign.left,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _mutedColor,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _rosterGuardCell(_ShiftRosterRow row, {required double width}) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.displayName,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            row.employeeId,
            style: GoogleFonts.inter(fontSize: 11, color: _bodyColor),
          ),
        ],
      ),
    );
  }

  Widget _rosterSiteCell(_ShiftRosterRow row, {required double width}) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.siteCode,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            row.siteName,
            style: GoogleFonts.inter(fontSize: 11, color: _bodyColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _rosterShiftCell(_ShiftBlock? block, {required double width}) {
    return SizedBox(
      width: width,
      child: Center(
        child: block == null
            ? Text(
                '—',
                style: GoogleFonts.inter(fontSize: 10, color: _mutedColor),
                textAlign: TextAlign.center,
              )
            : Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: block.background,
                  borderRadius: OnyxRadiusTokens.radiusSm,
                  border: Border.all(color: block.border),
                ),
                child: Column(
                  children: [
                    Text(
                      block.label,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: block.foreground,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      block.time,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: _bodyColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Tab 2 — Shift History ─────────────────────────────────────────────────

  Widget _shiftHistoryView() {
    final historyRows = (_liveGuards?.isNotEmpty ?? false)
        ? _buildShiftHistoryRows(_effectiveGuards)
        : _shiftHistoryRows;
    final rows = _siteFilter == 'ALL'
        ? historyRows
        : historyRows
              .where((r) => r.siteCode == _siteFilter)
              .toList(growable: false);
    final activeCount = rows.where((r) => r.statusLabel == 'ACTIVE').length;
    final completedCount = rows.where((r) => r.statusLabel == 'COMPLETED').length;

    return _panelContainer(
      key: const ValueKey('guards-shift-history-panel'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SHIFT HISTORY & TIMESHEETS', style: _capsLabelStyle()),
                    const SizedBox(height: 2),
                    Text(
                      'All clock in/out events and shift records',
                      style: GoogleFonts.inter(fontSize: 11, color: _bodyColor),
                    ),
                  ],
                ),
                const Spacer(),
                _countBadge('$activeCount active', OnyxDesignTokens.cyanInteractive),
                const SizedBox(width: 8),
                _countBadge('$completedCount completed', _mutedColor),
              ],
            ),
          ),
          Divider(color: _dividerColor, height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    decoration: BoxDecoration(
                      color: _bg,
                      border: Border(bottom: BorderSide(color: _dividerColor)),
                    ),
                    child: Row(
                      children: [
                        _historyColHeader('DATE', width: 120),
                        _historyColHeader('GUARD', width: 160),
                        _historyColHeader('SITE', width: 150),
                        _historyColHeader('CLOCK IN', width: 100),
                        _historyColHeader('CLOCK OUT', width: 110),
                        _historyColHeader('DURATION', width: 110),
                        _historyColHeader('STATUS', width: 120),
                        _historyColHeader('HANDLED BY', width: 120),
                      ],
                    ),
                  ),
                  // Rows
                  for (int i = 0; i < rows.length; i++)
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      decoration: BoxDecoration(
                        color: i.isOdd ? _bg : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(color: _dividerColor),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _historyCell(
                            width: 120,
                            child: Text(rows[i].date, style: _historyBodyStyle()),
                          ),
                          _historyCell(
                            width: 160,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(rows[i].displayName, style: _historyStrongStyle()),
                                const SizedBox(height: 2),
                                Text(rows[i].employeeId, style: _historyBodyStyle()),
                              ],
                            ),
                          ),
                          _historyCell(
                            width: 150,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(rows[i].siteCode, style: _historyStrongStyle()),
                                const SizedBox(height: 2),
                                Text(
                                  rows[i].siteName,
                                  style: _historyBodyStyle(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          _historyCell(
                            width: 100,
                            child: Text(rows[i].clockIn, style: _historyBodyStyle()),
                          ),
                          _historyCell(
                            width: 110,
                            child: Text(rows[i].clockOut, style: _historyBodyStyle()),
                          ),
                          _historyCell(
                            width: 110,
                            child: Text(
                              rows[i].duration,
                              style: _historyStrongStyle(color: OnyxDesignTokens.cyanInfo),
                            ),
                          ),
                          _historyCell(
                            width: 120,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: rows[i].statusBackground,
                                borderRadius: BorderRadius.circular(OnyxRadiusTokens.pill),
                                border: Border.all(color: rows[i].statusBorder),
                              ),
                              child: Text(
                                rows[i].statusLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: rows[i].statusForeground,
                                ),
                              ),
                            ),
                          ),
                          _historyCell(
                            width: 120,
                            child: Text(rows[i].handledBy, style: _historyBodyStyle()),
                          ),
                        ],
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

  Widget _historyColHeader(String label, {required double width}) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _mutedColor,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _historyCell({required double width, required Widget child}) {
    return SizedBox(width: width, child: child);
  }

  TextStyle _historyBodyStyle() => GoogleFonts.inter(
    fontSize: 12,
    color: _bodyColor,
  );

  TextStyle _historyStrongStyle({Color? color}) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: color ?? _titleColor,
  );

  Widget _countBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  // ── Evidence return banner ────────────────────────────────────────────────

  Widget _evidenceReturnBanner(GuardsEvidenceReturnReceipt receipt) {
    return Container(
      key: const ValueKey('guards-evidence-return-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: receipt.accent.withValues(alpha: 0.12),
        borderRadius: OnyxRadiusTokens.radiusMd,
        border: Border.all(color: receipt.accent.withValues(alpha: 0.34)),
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
              color: _titleColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            receipt.detail,
            style: GoogleFonts.inter(
              color: _bodyColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared UI helpers ─────────────────────────────────────────────────────

  Widget _panelContainer({
    Key? key,
    EdgeInsetsGeometry? padding,
    required Widget child,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _dividerColor),
        borderRadius: OnyxRadiusTokens.radiusMd,
      ),
      child: child,
    );
  }

  TextStyle _capsLabelStyle() => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: _mutedColor,
    letterSpacing: 0.7,
  );

  // ── State helpers ─────────────────────────────────────────────────────────

  void _setView(_GuardsView view) {
    if (_selectedView == view) return;
    setState(() => _selectedView = view);
  }

  void _setSiteFilter(String siteCode) {
    if (_siteFilter == siteCode) return;
    setState(() {
      _siteFilter = siteCode;
      final visible = _filteredGuards(siteCodeOverride: siteCode);
      if (visible.isNotEmpty) {
        _selectedGuardId = visible.first.id;
      }
    });
  }

  void _selectGuard(String guardId) => setState(() => _selectedGuardId = guardId);

  List<_GuardRecord> _filteredGuards({String? siteCodeOverride}) {
    final filter = siteCodeOverride ?? _siteFilter;
    final guards = _effectiveGuards;
    if (filter == 'ALL') return guards;
    return guards
        .where((g) => g.siteCode == filter)
        .toList(growable: false);
  }

  _GuardRecord? _selectedGuard(List<_GuardRecord> visible) {
    if (visible.isEmpty) return null;
    for (final guard in visible) {
      if (guard.id == _selectedGuardId) return guard;
    }
    return visible.first;
  }

  String _resolveSiteFilter(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'all') return 'ALL';
    const aliases = <String, List<String>>{
      'SE-01': ['se-01', 'sandton estate north', 'wtf-main', 'waterfall estate main'],
      'WF-02': ['wf-02', 'waterfall estate', 'blue ridge security'],
      'BR-03': ['br-03', 'blue ridge residence', 'sdn-north'],
    };
    for (final entry in aliases.entries) {
      if (entry.value.contains(normalized)) return entry.key;
    }
    return 'ALL';
  }

  List<String> _availableSiteFilters(List<_GuardRecord> guards) {
    final codes = guards
        .map((g) => g.siteCode)
        .where((c) => c != '--')
        .toSet()
        .toList(growable: false)
      ..sort();
    return <String>['ALL', ...codes];
  }

  List<_GuardRecord> get _effectiveGuards {
    final liveGuards = _liveGuards;
    if (liveGuards == null || liveGuards.isEmpty) return _guards;
    return liveGuards;
  }

  // ── Guard schedule actions ────────────────────────────────────────────────

  void _openGuardSchedule() => _openGuardScheduleForAction('quick-schedule');

  void _openGuardScheduleForAction(String action, {DateTime? date}) {
    final actionCallback = widget.onOpenGuardScheduleForAction;
    final callback = widget.onOpenGuardSchedule;
    if (actionCallback == null && callback == null) return;
    logUiAction(
      'guards_schedule_opened',
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

  void _openReportsForSite(BuildContext context, _GuardRecord guard) {
    final callback = widget.onOpenGuardReportsForSite;
    if (callback == null) {
      _showReportsLinkDialog(context);
      return;
    }
    logUiAction(
      'guards_reports_opened',
      context: <String, Object?>{'site_id': guard.routeSiteId, 'guard_id': guard.id},
    );
    callback(guard.routeSiteId);
  }

  void _showReportsLinkDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        title: Text(
          'Reports Workspace Ready',
          style: GoogleFonts.inter(color: _titleColor, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Use Reports Workspace to review workforce documentation, schedule exports, and field-performance outputs tied to the selected guard or site.',
          style: GoogleFonts.inter(color: _bodyColor, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ── Clock-out ─────────────────────────────────────────────────────────────

  void _showClockOutNotice(_GuardRecord guard) {
    logUiAction(
      'guards_clock_out_requested',
      context: <String, Object?>{
        'guard_id': guard.id,
        'site_id': guard.routeSiteId,
      },
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _surface,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Clock-out flow for ${guard.displayName} is ready for the next wiring pass.',
          style: GoogleFonts.inter(color: _titleColor, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ── Contact sheet ─────────────────────────────────────────────────────────

  Future<void> _copyGuardContact(_GuardRecord guard) async {
    await Clipboard.setData(ClipboardData(text: guard.contactPhone));
    if (!mounted) return;
    logUiAction(
      'guard_contact_copied',
      context: <String, Object?>{'guard_id': guard.id, 'site_id': guard.routeSiteId},
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _surface,
        behavior: SnackBarBehavior.floating,
        content: Text(
          '${guard.contactName} contact copied.',
          style: GoogleFonts.inter(color: _titleColor, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _showGuardContactSheet(
    _GuardRecord guard, {
    required _GuardContactMode initialMode,
  }) async {
    final isMessage = initialMode == _GuardContactMode.message;
    final clientLaneAvailable = widget.onOpenClientLaneForSite != null;
    final voipAvailable = widget.onStageGuardVoipCall != null;
    final primaryActionAvailable = isMessage ? clientLaneAvailable : voipAvailable;
    final readinessNote = isMessage
        ? (clientLaneAvailable
              ? 'Open Client Comms to keep guard outreach warm, logged, and tied to the site thread.'
              : 'Client Comms routing is not connected in this session yet.')
        : (voipAvailable
              ? 'Stage the voice handoff now so control carries the right guard contact into the call flow.'
              : 'VoIP staging is not connected in this session yet.');

    logUiAction(
      'guard_contact_sheet_opened',
      context: <String, Object?>{
        'guard_id': guard.id,
        'site_id': guard.routeSiteId,
        'mode': initialMode.name,
      },
    );

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: _surface,
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
                isMessage ? 'Client Comms' : 'Voice Call Staging',
                style: GoogleFonts.inter(
                  color: _titleColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isMessage
                    ? 'Use Client Comms for warm, traceable outreach. Telegram stays primary and SMS remains fallback-only once delivery wiring is live.'
                    : 'Stage the voice handoff now so control has the right contact context ready when VoIP lands.',
                style: GoogleFonts.inter(color: _bodyColor, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _contactChip(
                    label: isMessage ? 'Telegram primary' : 'VoIP ready',
                    accent: _skyColor,
                  ),
                  _contactChip(label: 'SMS fallback standby', accent: _amberColor),
                  _contactChip(
                    label: '${guard.siteCode} · ${guard.siteName}',
                    accent: _greenColor,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _contactDetailRow('Guard', guard.contactName),
              _contactDetailRow('Employee', guard.employeeId),
              _contactDetailRow('Current Site', guard.siteName),
              _contactDetailRow('Contact', guard.contactPhone),
              const SizedBox(height: 8),
              Text(
                readinessNote,
                style: GoogleFonts.inter(
                  color: primaryActionAvailable ? _bodyColor : _amberColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('guards-contact-copy-button'),
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await _copyGuardContact(guard);
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: Text(
                        'Copy Contact',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _brand,
                        side: BorderSide(color: OnyxColorTokens.borderSubtle),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('guards-contact-primary-button'),
                      onPressed: primaryActionAvailable
                          ? () async {
                              Navigator.of(sheetContext).pop();
                              if (isMessage) {
                                logUiAction(
                                  'guard_message_lane_opened',
                                  context: <String, Object?>{
                                    'guard_id': guard.id,
                                    'site_id': guard.routeSiteId,
                                  },
                                );
                                widget.onOpenClientLaneForSite?.call(guard.routeSiteId);
                                return;
                              }
                              final stageCall = widget.onStageGuardVoipCall;
                              if (stageCall == null) return;
                              try {
                                final message = await stageCall(
                                  guard.id,
                                  guard.contactName,
                                  guard.routeSiteId,
                                  guard.contactPhone,
                                );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: _surface,
                                    behavior: SnackBarBehavior.floating,
                                    content: Text(
                                      message,
                                      style: GoogleFonts.inter(
                                        color: _titleColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              } catch (_) {}
                            }
                          : null,
                      icon: Icon(
                        isMessage ? Icons.forum_rounded : Icons.phone_forwarded_rounded,
                        size: 16,
                      ),
                      label: Text(
                        isMessage ? 'Open Client Comms' : 'Stage VoIP Call',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: OnyxDesignTokens.accentBlue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
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

  Widget _contactChip({required String label, required Color accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(OnyxRadiusTokens.pill),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _contactDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: GoogleFonts.inter(color: _mutedColor, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(color: _titleColor, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Live data loading ─────────────────────────────────────────────────────

  Future<void> _loadLiveGuards() async {
    final repositoryFuture = widget.guardSyncRepositoryFuture;
    if (repositoryFuture == null) {
      if (!mounted) return;
      setState(() => _liveGuards = null);
      return;
    }
    try {
      final repository = await repositoryFuture;
      final assignments = await repository.readAssignments();
      final operations = await repository.readOperations(
        statuses: Set<GuardSyncOperationStatus>.from(GuardSyncOperationStatus.values),
        limit: 500,
      );
      final liveGuards = _mergeLiveGuards(assignments, operations);
      if (!mounted) return;
      setState(() {
        _liveGuards = liveGuards.isEmpty ? null : liveGuards;
        final visible = _filteredGuards();
        if (visible.isNotEmpty &&
            !visible.any((g) => g.id == _selectedGuardId)) {
          _selectedGuardId = visible.first.id;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _liveGuards = null);
    }
  }

  List<_GuardRecord> _mergeLiveGuards(
    List<GuardAssignment> assignments,
    List<GuardSyncOperation> operations,
  ) {
    if (assignments.isEmpty && operations.isEmpty) return const <_GuardRecord>[];
    final assignmentsByGuard = <String, GuardAssignment>{};
    for (final assignment in assignments) {
      final guardId = assignment.guardId.trim();
      if (guardId.isEmpty) continue;
      final current = assignmentsByGuard[guardId];
      if (current == null || assignment.issuedAt.isAfter(current.issuedAt)) {
        assignmentsByGuard[guardId] = assignment;
      }
    }
    final operationsByGuard = <String, List<GuardSyncOperation>>{};
    for (final operation in operations) {
      final guardId = (operation.payload['guard_id'] ?? '').toString().trim();
      if (guardId.isEmpty) continue;
      operationsByGuard.putIfAbsent(guardId, () => <GuardSyncOperation>[]).add(operation);
    }
    for (final ops in operationsByGuard.values) {
      ops.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    final liveGuardIds = <String>{
      ...assignmentsByGuard.keys,
      ...operationsByGuard.keys,
    }.toList(growable: false)
      ..sort();

    final records = <_GuardRecord>[
      for (final guardId in liveGuardIds)
        _guardRecordFromLive(
          guardId: guardId,
          assignment: assignmentsByGuard[guardId],
          operations: operationsByGuard[guardId] ?? const <GuardSyncOperation>[],
        ),
      for (final seed in _guards)
        if (!liveGuardIds.contains(seed.id)) seed,
    ];
    records.sort((a, b) {
      final dutyCmp = (a.status == _GuardStatus.onDuty ? 0 : 1)
          .compareTo(b.status == _GuardStatus.onDuty ? 0 : 1);
      if (dutyCmp != 0) return dutyCmp;
      return a.displayName.compareTo(b.displayName);
    });
    return records;
  }

  _GuardRecord _guardRecordFromLive({
    required String guardId,
    required GuardAssignment? assignment,
    required List<GuardSyncOperation> operations,
  }) {
    final seed = _guards.cast<_GuardRecord?>().firstWhere(
      (g) => g != null && g.id == guardId,
      orElse: () => null,
    );
    final latestOperation = operations.isEmpty ? null : operations.first;
    final status = _guardStatusFromLive(
      assignment: assignment,
      operations: operations,
      seed: seed,
    );
    final routeSiteId = _guardRouteSiteId(
      assignment: assignment,
      operations: operations,
      seed: seed,
    );
    final siteSummary = _siteSummaryForRouteSiteId(routeSiteId, seed: seed);
    final clockInAt =
        assignment?.acknowledgedAt ?? assignment?.issuedAt ?? latestOperation?.createdAt;
    final shiftLabel = _shiftLabelFor(clockInAt, fallback: seed?.shiftLabel);
    final shiftWindow = status == _GuardStatus.onDuty ? _shiftWindowFor(shiftLabel) : '--';
    return _GuardRecord(
      id: guardId,
      displayName: seed?.displayName ?? _compactGuardLabel(guardId),
      contactName: seed?.contactName ?? _humanizeScopeLabel(guardId),
      employeeId: seed?.employeeId ?? 'EMP-${guardId.replaceAll(RegExp(r'[^0-9A-Za-z]'), '')}',
      siteCode: routeSiteId.isEmpty ? '--' : siteSummary.code,
      siteName: routeSiteId.isEmpty ? 'No active assignment' : siteSummary.name,
      routeSiteId: routeSiteId,
      contactPhone: seed?.contactPhone ?? '-',
      status: status,
      hasSyncIssue:
          operations.any((op) => op.status == GuardSyncOperationStatus.failed) ||
          (operations.isEmpty && (seed?.hasSyncIssue ?? false)),
      clockIn: clockInAt == null ? '--' : _timeLabel(clockInAt),
      shiftWindow: shiftWindow,
      lastSync: latestOperation == null
          ? (seed?.lastSync ?? 'offline')
          : _relativeTimeLabel(latestOperation.createdAt),
      obEntries: operations
          .where((op) => op.type == GuardSyncOperationType.checkpointScan)
          .length,
      incidents: operations
          .where(
            (op) =>
                op.type == GuardSyncOperationType.incidentCapture ||
                op.type == GuardSyncOperationType.panicSignal,
          )
          .length,
      avgResponse: _avgResponseLabel(
        assignment: assignment,
        operations: operations,
        fallback: seed?.avgResponse,
      ),
      rating: seed?.rating ?? '--',
      shiftLabel: shiftLabel,
      handler: seed?.handler ?? 'Control',
      assignmentNote: routeSiteId.isEmpty ? 'No active assignment' : null,
    );
  }

  _GuardStatus _guardStatusFromLive({
    required GuardAssignment? assignment,
    required List<GuardSyncOperation> operations,
    required _GuardRecord? seed,
  }) {
    for (final op in operations) {
      final status = _guardDutyStatusFromOperation(op);
      if (status == null) continue;
      return status == GuardDutyStatus.offline ? _GuardStatus.offDuty : _GuardStatus.onDuty;
    }
    final assignmentStatus = assignment?.status;
    if (assignmentStatus != null) {
      return assignmentStatus == GuardDutyStatus.offline
          ? _GuardStatus.offDuty
          : _GuardStatus.onDuty;
    }
    return seed?.status ?? _GuardStatus.offDuty;
  }

  GuardDutyStatus? _guardDutyStatusFromOperation(GuardSyncOperation operation) {
    final rawStatus = (operation.payload['status'] ?? '').toString().trim();
    return GuardDutyStatus.values.cast<GuardDutyStatus?>().firstWhere(
      (v) => v != null && v.name == rawStatus,
      orElse: () => null,
    );
  }

  String _guardRouteSiteId({
    required GuardAssignment? assignment,
    required List<GuardSyncOperation> operations,
    required _GuardRecord? seed,
  }) {
    final assignmentSiteId = assignment?.siteId.trim() ?? '';
    if (assignmentSiteId.isNotEmpty) return assignmentSiteId;
    for (final op in operations) {
      final siteId = (op.payload['site_id'] ?? '').toString().trim();
      if (siteId.isNotEmpty) return siteId;
    }
    return seed?.routeSiteId ?? '';
  }

  ({String code, String name}) _siteSummaryForRouteSiteId(
    String routeSiteId, {
    _GuardRecord? seed,
  }) {
    final normalized = routeSiteId.trim().toLowerCase();
    if (normalized.isEmpty) return (code: '--', name: 'No active assignment');
    for (final guard in _guards) {
      if (guard.routeSiteId.trim().toLowerCase() == normalized ||
          guard.siteCode.trim().toLowerCase() == normalized) {
        return (code: guard.siteCode, name: guard.siteName);
      }
    }
    if (seed != null && seed.siteCode != '--') {
      return (code: seed.siteCode, name: seed.siteName);
    }
    return (
      code: routeSiteId.trim().toUpperCase(),
      name: _humanizeScopeLabel(routeSiteId),
    );
  }

  String _shiftLabelFor(DateTime? startedAt, {String? fallback}) {
    if (startedAt == null) return fallback ?? 'Off Duty';
    final hour = startedAt.toUtc().hour;
    return (hour >= 6 && hour < 18) ? 'Day' : 'Night';
  }

  String _shiftWindowFor(String shiftLabel) =>
      shiftLabel == 'Day' ? '06:00 - 18:00' : '18:00 - 06:00';

  String _timeLabel(DateTime value) {
    final t = value.toUtc();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _relativeTimeLabel(DateTime value) {
    final elapsed = DateTime.now().toUtc().difference(value.toUtc());
    if (elapsed.inSeconds < 60) return '${elapsed.inSeconds.clamp(0, 59)}s ago';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';
    if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
    return '${elapsed.inDays}d ago';
  }

  String _avgResponseLabel({
    required GuardAssignment? assignment,
    required List<GuardSyncOperation> operations,
    required String? fallback,
  }) {
    if (assignment == null) return fallback ?? '--';
    for (final op in operations) {
      final status = _guardDutyStatusFromOperation(op);
      if (status != GuardDutyStatus.enRoute && status != GuardDutyStatus.onSite) continue;
      final delta = op.createdAt.difference(assignment.issuedAt);
      return '${delta.inSeconds.clamp(0, 99999)}s';
    }
    return fallback ?? '--';
  }

  String _compactGuardLabel(String guardId) {
    final normalized = guardId.trim();
    if (normalized.isEmpty) return 'Unknown Guard';
    final humanized = _humanizeScopeLabel(normalized);
    final parts = humanized
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
    if (parts.length >= 2) return '${parts.first[0]}. ${parts.last}';
    return humanized;
  }

  String _humanizeScopeLabel(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return '-';
    return normalized
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) {
          final lower = w.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  List<_ShiftRosterRow> _buildShiftRosterRows(List<_GuardRecord> guards) {
    return guards.map((guard) => _ShiftRosterRow(
      displayName: guard.displayName,
      employeeId: guard.employeeId,
      siteCode: guard.siteCode,
      siteName: guard.siteCode == '--' ? 'Unassigned' : guard.siteName,
      blocks: List<_ShiftBlock?>.filled(
        5,
        guard.status == _GuardStatus.onDuty
            ? (guard.shiftLabel == 'Day' ? _dayBlock : _nightBlock)
            : null,
      ),
    )).toList(growable: false);
  }

  List<_ShiftHistoryRow> _buildShiftHistoryRows(List<_GuardRecord> guards) {
    final nowUtc = DateTime.now().toUtc();
    final activeGuards = guards
        .where((g) => g.status == _GuardStatus.onDuty)
        .toList(growable: false);
    return <_ShiftHistoryRow>[
      for (final guard in activeGuards)
        _ShiftHistoryRow(
          date: _historyDateLabel(nowUtc),
          displayName: guard.displayName,
          employeeId: guard.employeeId,
          siteCode: guard.siteCode,
          siteName: guard.siteName,
          clockIn: guard.clockIn,
          clockOut: 'In Progress',
          duration: _activeShiftDurationLabel(guard.clockIn, nowUtc),
          statusLabel: 'ACTIVE',
          statusForeground: OnyxColorTokens.accentCyanTrue,
          statusBackground: OnyxColorTokens.cyanSurface,
          statusBorder: OnyxColorTokens.cyanBorder,
          handledBy: guard.handler,
        ),
      for (final guard in activeGuards)
        _ShiftHistoryRow(
          date: _historyDateLabel(nowUtc.subtract(const Duration(days: 1))),
          displayName: guard.displayName,
          employeeId: guard.employeeId,
          siteCode: guard.siteCode,
          siteName: guard.siteName,
          clockIn: guard.shiftLabel == 'Day' ? '06:00' : '18:00',
          clockOut: guard.shiftLabel == 'Day' ? '18:00' : '06:00',
          duration: '12h 00m',
          statusLabel: 'COMPLETED',
          statusForeground: OnyxColorTokens.accentGreen,
          statusBackground: OnyxColorTokens.greenSurface,
          statusBorder: OnyxColorTokens.greenBorder,
          handledBy: guard.handler,
        ),
    ];
  }

  String _historyDateLabel(DateTime value) {
    final utc = value.toUtc();
    return '${utc.year}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}';
  }

  String _activeShiftDurationLabel(String clockIn, DateTime nowUtc) {
    final parts = clockIn.split(':');
    if (parts.length != 2) return '--';
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    var startedAt = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, hour, minute);
    if (startedAt.isAfter(nowUtc)) {
      startedAt = startedAt.subtract(const Duration(days: 1));
    }
    final elapsed = nowUtc.difference(startedAt);
    return '${elapsed.inHours}h ${(elapsed.inMinutes % 60).toString().padLeft(2, '0')}m';
  }
}
