import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/guard_sync_repository.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/guard/guard_mobile_ops.dart';
import 'components/onyx_status_banner.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'ui_action_logger.dart';

const _guardsPanelColor = Color(0xFFFFFFFF);
const _guardsPanelTint = Color(0xFFF5F7FB);
const _guardsPanelMuted = Color(0xFFEAF0F7);
const _guardsSelectedPanelColor = Color(0xFFE8F1FF);
const _guardsBorderColor = Color(0xFFD7E1EC);
const _guardsStrongBorderColor = Color(0xFFBFD0EA);
const _guardsTitleColor = Color(0xFF142235);
const _guardsBodyColor = Color(0xFF5B708B);
const _guardsMutedColor = Color(0xFF7A8EA8);
const _guardsAccentBlue = Color(0xFF365E94);

enum _GuardStatus { onDuty, offDuty }

enum _GuardContactMode { message, call }

enum _GuardsView { active, roster, history }

enum _RosterPlannerStatus { published, draft, gap }

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

class _RosterCalendarAssignment {
  final String guardName;
  final String siteCode;
  final String shiftLabel;
  final Color foreground;
  final Color background;
  final Color border;

  const _RosterCalendarAssignment({
    required this.guardName,
    required this.siteCode,
    required this.shiftLabel,
    required this.foreground,
    required this.background,
    required this.border,
  });
}

class _RosterCalendarDay {
  final DateTime date;
  final int assignedPosts;
  final int requiredPosts;
  final int openPosts;
  final _RosterPlannerStatus status;
  final List<_RosterCalendarAssignment> assignments;

  const _RosterCalendarDay({
    required this.date,
    required this.assignedPosts,
    required this.requiredPosts,
    required this.openPosts,
    required this.status,
    required this.assignments,
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
  static final DateTime _rosterMonth = DateTime.utc(2026, 3);
  static final DateTime _rosterReferenceDate = DateTime.utc(2026, 3, 27);
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

  bool get _canOpenGuardSchedule =>
      widget.onOpenGuardScheduleForAction != null ||
      widget.onOpenGuardSchedule != null;

  static const _nightBlock = _ShiftBlock(
    label: 'NIGHT',
    time: '18:00 - 06:00',
    foreground: Color(0xFFC8B8FF),
    background: Color(0x1A6D5AE6),
    border: Color(0x556D5AE6),
  );

  static const _dayBlock = _ShiftBlock(
    label: 'DAY',
    time: '06:00 - 18:00',
    foreground: Color(0xFFF6C067),
    background: Color(0x1AF6C067),
    border: Color(0x55F6C067),
  );

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
      statusForeground: Color(0xFF5BD4FF),
      statusBackground: Color(0x1A22D3EE),
      statusBorder: Color(0x5522D3EE),
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
      statusForeground: Color(0xFF5BD4FF),
      statusBackground: Color(0x1A22D3EE),
      statusBorder: Color(0x5522D3EE),
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
      statusForeground: Color(0xFF5BD4FF),
      statusBackground: Color(0x1A22D3EE),
      statusBorder: Color(0x5522D3EE),
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
      statusForeground: Color(0xFF5BD4FF),
      statusBackground: Color(0x1A22D3EE),
      statusBorder: Color(0x5522D3EE),
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
      statusForeground: Color(0xFF5BD4FF),
      statusBackground: Color(0x1A22D3EE),
      statusBorder: Color(0x5522D3EE),
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
      statusForeground: Color(0xFF63E6A1),
      statusBackground: Color(0x1A10B981),
      statusBorder: Color(0x5510B981),
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
      statusForeground: Color(0xFF63E6A1),
      statusBackground: Color(0x1A10B981),
      statusBorder: Color(0x5510B981),
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
      statusForeground: Color(0xFF63E6A1),
      statusBackground: Color(0x1A10B981),
      statusBorder: Color(0x5510B981),
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
      statusForeground: Color(0xFF63E6A1),
      statusBackground: Color(0x1A10B981),
      statusBorder: Color(0x5510B981),
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
      statusForeground: Color(0xFF63E6A1),
      statusBackground: Color(0x1A10B981),
      statusBorder: Color(0x5510B981),
      handledBy: 'Mike W.',
    ),
  ];

  String _siteFilter = 'ALL';
  String _selectedGuardId = _guards.first.id;
  _GuardsView _selectedView = _GuardsView.active;
  DateTime _selectedRosterDate = _rosterReferenceDate;
  List<_GuardRecord>? _liveGuards;
  GuardsEvidenceReturnReceipt? _activeEvidenceReturnReceipt;

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
    if (receipt == null) {
      return;
    }

    void apply() {
      _activeEvidenceReturnReceipt = receipt;
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

  @override
  Widget build(BuildContext context) {
    final filteredGuards = _filteredGuards();
    final selectedGuard = _selectedGuard(filteredGuards);
    final effectiveGuards = _effectiveGuards;
    final totalGuards = effectiveGuards.length;
    final onDutyCount = effectiveGuards
        .where((g) => g.status == _GuardStatus.onDuty)
        .length;
    final syncIssues = effectiveGuards
        .where((g) => g.hasSyncIssue)
        .length;
    final allDeployed = totalGuards > 0 && onDutyCount == totalGuards;
    final workforceSummary = syncIssues > 0
        ? '$syncIssues workforce gaps need review'
        : totalGuards == 0
        ? 'No guard workforce data'
        : allDeployed
        ? 'All $totalGuards guards deployed'
        : '$onDutyCount of $totalGuards guards deployed';
    final workforceSeverity = syncIssues > 0
        ? OnyxSeverity.warning
        : allDeployed
        ? OnyxSeverity.success
        : OnyxSeverity.info;

    return OnyxPageScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1160;
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
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OnyxPageHeader(
                      icon: Icons.shield_rounded,
                      iconColor: Theme.of(context).colorScheme.primary,
                      title: 'Guards & Workforce',
                      subtitle: 'Guard workforce status.',
                    ),
                    const SizedBox(height: 10),
                    OnyxStatusBanner(
                      message: workforceSummary,
                      severity: workforceSeverity,
                    ),
                    const SizedBox(height: 10),
                    _pageHeader(context),
                    if (_activeEvidenceReturnReceipt != null) ...[
                      const SizedBox(height: 12),
                      _evidenceReturnBanner(_activeEvidenceReturnReceipt!),
                    ],
                    const SizedBox(height: 18),
                    _statusAndFiltersBar(filteredGuards, effectiveGuards),
                    const SizedBox(height: 18),
                    _viewTabs(),
                    const SizedBox(height: 18),
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

  Widget _pageHeader(BuildContext context) {
    final exportEnabled = widget.onOpenGuardReportsForSite != null;
    final titleBlock = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF7A18), Color(0xFFE11D48)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x44FFFFFF)),
          ),
          child: const Icon(
            Icons.groups_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Guards & Workforce',
                style: GoogleFonts.inter(
                  color: _guardsTitleColor,
                  fontSize: MediaQuery.sizeOf(context).width >= 900 ? 34 : 30,
                  fontWeight: FontWeight.w700,
                  height: 0.92,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Who is on now, who is missing, and who works next.',
                style: GoogleFonts.inter(
                  color: _guardsBodyColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final exportButton = FilledButton.tonalIcon(
      key: const ValueKey('guards-view-reports-button'),
      onPressed: exportEnabled
          ? () => _openReportsForSelectedSite(context)
          : null,
      icon: const Icon(Icons.download_rounded, size: 18),
      label: const Text('OPEN REPORTS WORKSPACE'),
      style: FilledButton.styleFrom(
        backgroundColor: _guardsPanelColor,
        foregroundColor: _guardsTitleColor,
        disabledBackgroundColor: _guardsPanelTint,
        disabledForegroundColor: const Color(0xFF66778E),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _guardsStrongBorderColor),
        ),
      ),
    );

    if (MediaQuery.sizeOf(context).width >= 900) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: titleBlock),
          const SizedBox(width: 16),
          exportButton,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titleBlock,
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: exportButton),
      ],
    );
  }

  Widget _evidenceReturnBanner(GuardsEvidenceReturnReceipt receipt) {
    return Container(
      key: const ValueKey('guards-evidence-return-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: receipt.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
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
              color: _guardsTitleColor,
              fontSize: 13.2,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            receipt.detail,
            style: GoogleFonts.inter(
              color: _guardsBodyColor,
              fontSize: 11.6,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusAndFiltersBar(
    List<_GuardRecord> guards,
    List<_GuardRecord> effectiveGuards,
  ) {
    final onDutyCount = guards
        .where((guard) => guard.status == _GuardStatus.onDuty)
        .length;
    final activeShifts = onDutyCount;
    final syncIssues = guards.where((guard) => guard.hasSyncIssue).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _guardsPanelTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _guardsBorderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 1080;
          final statusWrap = Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'WORKFORCE STATUS:',
                style: GoogleFonts.inter(
                  color: _guardsMutedColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
              _pill(
                icon: Icons.check_circle_outline,
                label: '$onDutyCount On Duty',
                foreground: const Color(0xFF63E6A1),
                background: const Color(0x1A10B981),
                border: const Color(0x5510B981),
              ),
              _pill(
                icon: Icons.timelapse_rounded,
                label: '$activeShifts Active Shifts',
                foreground: const Color(0xFF54C8FF),
                background: const Color(0x1A22D3EE),
                border: const Color(0x5522D3EE),
              ),
              _pill(
                icon: Icons.warning_amber_rounded,
                label: '$syncIssues Sync Issues',
                foreground: const Color(0xFFF6C067),
                background: const Color(0x1AF59E0B),
                border: const Color(0x55F59E0B),
              ),
            ],
          );

          final filterWrap = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'FILTER BY SITE:',
                style: GoogleFonts.inter(
                  color: _guardsMutedColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
              for (final code in _availableSiteFilters(effectiveGuards))
                _siteFilterChip(code),
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [statusWrap, const SizedBox(height: 14), filterWrap],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: statusWrap),
              const SizedBox(width: 16),
              Flexible(child: filterWrap),
            ],
          );
        },
      ),
    );
  }

  Widget _viewTabs() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _guardsPanelTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _guardsBorderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 500;
          return Row(
            children: [
              Expanded(
                child: _viewTab(
                  key: const ValueKey('guards-view-tab-active'),
                  label: 'Active Now',
                  icon: Icons.groups_rounded,
                  compact: compact,
                  selected: _selectedView == _GuardsView.active,
                  onTap: () => _setView(_GuardsView.active),
                ),
              ),
              Expanded(
                child: _viewTab(
                  key: const ValueKey('guards-view-tab-roster'),
                  label: 'Month Planner',
                  icon: Icons.calendar_month_rounded,
                  compact: compact,
                  selected: _selectedView == _GuardsView.roster,
                  onTap: () => _setView(_GuardsView.roster),
                ),
              ),
              Expanded(
                child: _viewTab(
                  key: const ValueKey('guards-view-tab-history'),
                  label: 'History',
                  icon: Icons.history_rounded,
                  compact: compact,
                  selected: _selectedView == _GuardsView.history,
                  onTap: () => _setView(_GuardsView.history),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _activeGuardsView(
    BuildContext context, {
    required List<_GuardRecord> guards,
    required _GuardRecord? selectedGuard,
    required bool wide,
  }) {
    final detail = selectedGuard;
    if (detail == null) {
      return _panel(
        child: Text(
          'No guards match the selected site filter.',
          style: GoogleFonts.inter(
            color: _guardsBodyColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (!wide) {
      return Column(
        children: [
          _guardRosterPanel(guards),
          const SizedBox(height: 18),
          _selectedGuardPanel(context, detail),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 360, child: _guardRosterPanel(guards)),
        const SizedBox(width: 18),
        Expanded(child: _selectedGuardPanel(context, detail)),
      ],
    );
  }

  Widget _guardRosterPanel(List<_GuardRecord> guards) {
    final embeddedScroll = allowEmbeddedPanelScroll(context);
    return _panel(
      key: const ValueKey('guards-roster-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0x1A9A3412),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: Color(0xFFF6C067),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GUARD ROSTER',
                      style: GoogleFonts.inter(
                        color: _guardsTitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    Text(
                      '${guards.length} guards',
                      style: GoogleFonts.inter(
                        color: _guardsBodyColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: embeddedScroll ? 520 : null,
            child: Scrollbar(
              thumbVisibility: embeddedScroll,
              child: ListView.separated(
                primary: !embeddedScroll,
                shrinkWrap: !embeddedScroll,
                itemCount: guards.length,
                itemBuilder: (context, index) =>
                    _guardRosterCard(guards[index]),
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _guardRosterCard(_GuardRecord guard) {
    final selected =
        guard.id == _selectedGuardId ||
        (_selectedGuard(_filteredGuards())?.id == guard.id &&
            _selectedGuardId.isEmpty);
    final active = guard.status == _GuardStatus.onDuty;
    final statusForeground = active
        ? const Color(0xFF63E6A1)
        : const Color(0xFF98A6BA);
    final statusBackground = active
        ? const Color(0x1A10B981)
        : const Color(0x1A64748B);
    final statusBorder = active
        ? const Color(0x5510B981)
        : const Color(0x5564748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('guards-roster-card-${guard.id}'),
        onTap: () => _selectGuard(guard.id),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? _guardsSelectedPanelColor : _guardsPanelColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _guardsStrongBorderColor : _guardsBorderColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      guard.displayName,
                      style: GoogleFonts.inter(
                        color: _guardsTitleColor,
                        fontSize: 26 / 2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (guard.hasSyncIssue)
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFF6C067),
                      size: 16,
                    )
                  else if (guard.status == _GuardStatus.onDuty)
                    const Icon(
                      Icons.wifi_rounded,
                      color: Color(0xFF63E6A1),
                      size: 16,
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBackground,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: statusBorder),
                    ),
                    child: Text(
                      active ? 'ON DUTY' : 'OFF DUTY',
                      style: GoogleFonts.inter(
                        color: statusForeground,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                guard.employeeId,
                style: GoogleFonts.robotoMono(
                  color: _guardsMutedColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                guard.siteCode == '--'
                    ? guard.assignmentNote ?? 'No active assignment'
                    : '${guard.siteCode} • ${guard.siteName}',
                style: GoogleFonts.inter(
                  color: _guardsBodyColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (guard.assignmentNote != null && guard.siteCode != '--') ...[
                const SizedBox(height: 4),
                Text(
                  guard.assignmentNote!,
                  style: GoogleFonts.inter(
                    color: _guardsMutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectedGuardPanel(BuildContext context, _GuardRecord guard) {
    final active = guard.status == _GuardStatus.onDuty;

    return Column(
      children: [
        _panel(
          key: const ValueKey('guards-selected-guard-panel'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compactHeader = constraints.maxWidth < 760;
                  final identityBlock = Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF7A18), Color(0xFFFF4D15)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              guard.displayName,
                              style: GoogleFonts.inter(
                                color: _guardsTitleColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  guard.employeeId,
                                  style: GoogleFonts.robotoMono(
                                    color: _guardsMutedColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? const Color(0x1A10B981)
                                        : const Color(0x1A64748B),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: active
                                          ? const Color(0x5510B981)
                                          : const Color(0x5564748B),
                                    ),
                                  ),
                                  child: Text(
                                    active ? 'ON DUTY' : 'OFF DUTY',
                                    style: GoogleFonts.inter(
                                      color: active
                                          ? const Color(0xFF63E6A1)
                                          : const Color(0xFF98A6BA),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final actionButton = FilledButton.icon(
                    key: const ValueKey('guards-clock-out-button'),
                    onPressed: active ? () => _showClockOutNotice(guard) : null,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Clock Out'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5B2D),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _guardsPanelTint,
                      disabledForegroundColor: const Color(0xFF66778E),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      textStyle: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  );

                  if (compactHeader) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        identityBlock,
                        const SizedBox(height: 14),
                        SizedBox(width: double.infinity, child: actionButton),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: identityBlock),
                      const SizedBox(width: 16),
                      actionButton,
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 820;
                  final items = [
                    _detailTile(
                      title: 'CURRENT SITE',
                      value: guard.siteCode,
                      detail: guard.siteName,
                    ),
                    _detailTile(
                      title: 'CLOCKED IN',
                      value: guard.clockIn,
                      detail: guard.shiftWindow,
                    ),
                  ];

                  if (stacked) {
                    return Column(
                      children: [
                        items[0],
                        const SizedBox(height: 14),
                        items[1],
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: items[0]),
                      const SizedBox(width: 14),
                      Expanded(child: items[1]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3FBF7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCFE6DA)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.wifi_rounded,
                      color: Color(0xFF63E6A1),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guard.hasSyncIssue ? 'Sync Watch' : 'Sync Healthy',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF215D47),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Last sync: ${guard.lastSync}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF4E816A),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: guard.hasSyncIssue
                            ? const Color(0x1AF59E0B)
                            : const Color(0x1A10B981),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: guard.hasSyncIssue
                              ? const Color(0x55F59E0B)
                              : const Color(0x5510B981),
                        ),
                      ),
                      child: Text(
                        guard.hasSyncIssue ? 'WATCH' : 'HEALTHY',
                        style: GoogleFonts.inter(
                          color: guard.hasSyncIssue
                              ? const Color(0xFFF6C067)
                              : const Color(0xFF63E6A1),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _panel(
          key: const ValueKey('guards-performance-panel'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PERFORMANCE METRICS',
                style: GoogleFonts.inter(
                  color: _guardsTitleColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Current period operational stats',
                style: GoogleFonts.inter(
                  color: _guardsBodyColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 620;
                  final compact = constraints.maxWidth < 940;
                  final tiles = [
                    _metricTile('OB ENTRIES', '${guard.obEntries}'),
                    _metricTile('INCIDENTS', '${guard.incidents}'),
                    _metricTile('AVG RESPONSE', guard.avgResponse),
                    _metricTile('RATING', guard.rating),
                  ];

                  if (stacked) {
                    return Column(
                      children: [
                        for (int index = 0; index < tiles.length; index++) ...[
                          tiles[index],
                          if (index != tiles.length - 1)
                            const SizedBox(height: 14),
                        ],
                      ],
                    );
                  }

                  if (compact) {
                    return GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.9,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      children: tiles,
                    );
                  }

                  return Row(
                    children: [
                      for (int index = 0; index < tiles.length; index++) ...[
                        Expanded(child: tiles[index]),
                        if (index != tiles.length - 1)
                          const SizedBox(width: 14),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _panel(
          key: const ValueKey('guards-quick-actions-panel'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QUICK ACTIONS',
                style: GoogleFonts.inter(
                  color: _guardsTitleColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Operational controls',
                style: GoogleFonts.inter(
                  color: _guardsBodyColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 860;
                  final actions = [
                    _quickActionTile(
                      key: const ValueKey('guards-quick-schedule'),
                      icon: Icons.calendar_month_rounded,
                      label: 'Month Planner',
                      onTap: !_canOpenGuardSchedule ? null : _openGuardSchedule,
                    ),
                    _quickActionTile(
                      key: const ValueKey('guards-quick-reports'),
                      icon: Icons.description_outlined,
                      label: 'Reports Workspace',
                      onTap: widget.onOpenGuardReportsForSite == null
                          ? null
                          : () => _openReportsForSite(context, guard),
                    ),
                    _quickActionTile(
                      key: const ValueKey('guards-quick-client-lane'),
                      icon: Icons.forum_outlined,
                      label: 'Client Comms',
                      onTap: () => _showGuardContactSheet(
                        guard,
                        initialMode: _GuardContactMode.message,
                      ),
                    ),
                    _quickActionTile(
                      key: const ValueKey('guards-quick-stage-voip'),
                      icon: Icons.phone_forwarded_rounded,
                      label: 'Stage VoIP',
                      onTap: () => _showGuardContactSheet(
                        guard,
                        initialMode: _GuardContactMode.call,
                      ),
                    ),
                  ];

                  if (compact) {
                    return Column(
                      children: [
                        for (int i = 0; i < actions.length; i++) ...[
                          actions[i],
                          if (i != actions.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    );
                  }

                  return GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 3.2,
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    children: actions,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _shiftRosterView(List<_GuardRecord> guards) {
    final rosterRows = (_liveGuards?.isNotEmpty ?? false)
        ? _buildShiftRosterRows(_effectiveGuards)
        : _shiftRosterRows;
    final visibleCodes = guards.map((guard) => guard.siteCode).toSet();
    final rows = _siteFilter == 'ALL'
        ? rosterRows
        : rosterRows
              .where(
                (row) =>
                    row.siteCode == _siteFilter ||
                    visibleCodes.contains(row.siteCode),
              )
              .toList(growable: false);
    final calendarDays = _buildRosterCalendarDays(guards);
    final selectedDay = calendarDays.firstWhere(
      (day) => _sameRosterDate(day.date, _selectedRosterDate),
      orElse: () => calendarDays.first,
    );
    final openPosts = calendarDays.fold<int>(
      0,
      (total, day) => total + day.openPosts,
    );
    final draftDays = calendarDays
        .where((day) => day.status == _RosterPlannerStatus.draft)
        .length;
    final gapDays = calendarDays.where((day) => day.openPosts > 0).length;
    final calendarPanel = _rosterCalendarPanel(calendarDays);
    final detailPanel = _selectedRosterDayPanel(selectedDay);

    return _panel(
      key: const ValueKey('guards-shift-roster-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MONTH PLANNER',
                      style: GoogleFonts.inter(
                        color: _guardsTitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Fill gaps, move guards, and publish the month.',
                      style: GoogleFonts.inter(
                        color: _guardsBodyColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _rosterPlannerActionButton(
                    key: const ValueKey('guards-roster-create-button'),
                    icon: Icons.add_rounded,
                    label: 'Create Month',
                    emphasized: true,
                    onPressed: !_canOpenGuardSchedule
                        ? null
                        : () => _openGuardScheduleForAction('create-roster'),
                  ),
                  _rosterPlannerActionButton(
                    key: const ValueKey('guards-roster-edit-button'),
                    icon: Icons.edit_calendar_rounded,
                    label: 'Fill Gaps',
                    onPressed: !_canOpenGuardSchedule
                        ? null
                        : () => _openGuardScheduleForAction(
                            'edit-roster',
                            date: selectedDay.date,
                          ),
                  ),
                  _rosterPlannerActionButton(
                    key: const ValueKey('guards-roster-publish-button'),
                    icon: Icons.publish_rounded,
                    label: 'Publish Now',
                    onPressed: !_canOpenGuardSchedule
                        ? null
                        : () => _openGuardScheduleForAction(
                            'publish-roster',
                            date: selectedDay.date,
                          ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _rosterPlannerCommandCard(
            openPosts: openPosts,
            gapDays: gapDays,
            selectedDay: selectedDay,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _countPill(
                '${calendarDays.length} Days Planned',
                const Color(0xFF7DDCFF),
                const Color(0x1A22D3EE),
                const Color(0x5522D3EE),
              ),
              _countPill(
                '$draftDays Draft Days',
                const Color(0xFFF6C067),
                const Color(0x1AF59E0B),
                const Color(0x55F59E0B),
              ),
              _countPill(
                '$gapDays Gap Days',
                const Color(0xFFFF8E8E),
                const Color(0x1AF43F5E),
                const Color(0x55F43F5E),
              ),
              _countPill(
                '$openPosts Open Posts',
                const Color(0xFF63E6A1),
                const Color(0x1A10B981),
                const Color(0x5510B981),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 1120;
              if (stacked) {
                return Column(
                  children: [
                    calendarPanel,
                    const SizedBox(height: 16),
                    detailPanel,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: calendarPanel),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: detailPanel),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _weeklyRosterSnapshot(rows),
        ],
      ),
    );
  }

  Widget _rosterPlannerCommandCard({
    required int openPosts,
    required int gapDays,
    required _RosterCalendarDay selectedDay,
  }) {
    final ready = openPosts == 0;
    final accent = ready ? const Color(0xFF63E6A1) : const Color(0xFFFFC247);
    final background = ready
        ? const Color(0x1A10B981)
        : const Color(0x1AF59E0B);
    final border = ready ? const Color(0x5510B981) : const Color(0x55F59E0B);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 860;
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DO THIS NOW',
                style: GoogleFonts.inter(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ready ? 'MONTH READY TO PUBLISH' : 'FILL $openPosts OPEN POSTS',
                style: GoogleFonts.inter(
                  color: _guardsTitleColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 0.92,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ready
                    ? 'All required posts are covered. Publish the month or keep editing the selected day.'
                    : '$gapDays day${gapDays == 1 ? '' : 's'} still have coverage gaps. Open the planner and fix the shortfalls fast.',
                style: GoogleFonts.inter(
                  color: _guardsBodyColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _rosterPlannerActionButton(
                key: const ValueKey('guards-roster-open-planner-button'),
                icon: Icons.calendar_month_rounded,
                label: 'OPEN MONTH PLANNER',
                emphasized: true,
                onPressed: !_canOpenGuardSchedule
                    ? null
                    : () => _openGuardScheduleForAction(
                        'open-month-planner',
                        date: selectedDay.date,
                      ),
              ),
              _rosterPlannerActionButton(
                key: const ValueKey('guards-roster-publish-now-button'),
                icon: Icons.publish_rounded,
                label: 'Publish Now',
                onPressed: !_canOpenGuardSchedule
                    ? null
                    : () => _openGuardScheduleForAction(
                        'publish-roster',
                        date: selectedDay.date,
                      ),
              ),
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summary, const SizedBox(height: 14), actions],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: summary),
              const SizedBox(width: 18),
              Flexible(child: actions),
            ],
          );
        },
      ),
    );
  }

  Widget _rosterCalendarPanel(List<_RosterCalendarDay> days) {
    const weekdayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final offset = _rosterMonth.weekday - 1;
    final cells = <Widget>[
      for (int i = 0; i < offset; i++) _rosterCalendarPlaceholderCell(),
      for (final day in days)
        _rosterCalendarDayCell(
          key: ValueKey(
            'guards-roster-day-${day.date.year.toString().padLeft(4, '0')}-${day.date.month.toString().padLeft(2, '0')}-${day.date.day.toString().padLeft(2, '0')}',
          ),
          day: day,
          selected: _sameRosterDate(day.date, _selectedRosterDate),
          onTap: () => _selectRosterDate(day.date),
        ),
    ];

    return Container(
      key: const ValueKey('guards-roster-calendar-panel'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _guardsPanelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _guardsBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'March 2026',
                style: GoogleFonts.inter(
                  color: _guardsTitleColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 0.96,
                ),
              ),
              const SizedBox(width: 12),
              _pill(
                icon: Icons.calendar_month_rounded,
                label: _siteFilter == 'ALL' ? 'All Sites' : _siteFilter,
                foreground: const Color(0xFF7DDCFF),
                background: const Color(0x1A22D3EE),
                border: const Color(0x5522D3EE),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Month view for controller planning, conflict detection, and shift publishing.',
            style: GoogleFonts.inter(
              color: _guardsBodyColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            itemCount: weekdayLabels.length,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 22,
            ),
            itemBuilder: (context, index) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                weekdayLabels[index],
                style: GoogleFonts.inter(
                  color: _guardsMutedColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            itemCount: cells.length,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 116,
            ),
            itemBuilder: (context, index) => cells[index],
          ),
        ],
      ),
    );
  }

  Widget _rosterCalendarPlaceholderCell() {
    return Container(
      decoration: BoxDecoration(
        color: _guardsPanelMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _guardsBorderColor),
      ),
    );
  }

  Widget _rosterCalendarDayCell({
    Key? key,
    required _RosterCalendarDay day,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final hasAssignments = day.assignments.isNotEmpty;
    final isToday = _sameRosterDate(day.date, _rosterReferenceDate);
    final accent = switch (day.status) {
      _RosterPlannerStatus.published => const Color(0xFF41F28A),
      _RosterPlannerStatus.draft => const Color(0xFF55C2FF),
      _RosterPlannerStatus.gap => const Color(0xFFFFC247),
    };
    final background = selected
        ? _guardsSelectedPanelColor
        : Color.alphaBlend(accent.withValues(alpha: 0.08), _guardsPanelColor);
    final borderColor = selected
        ? _guardsStrongBorderColor
        : accent.withValues(alpha: hasAssignments ? 0.55 : 0.22);
    final statusLabel = switch (day.status) {
      _RosterPlannerStatus.published => 'Covered',
      _RosterPlannerStatus.draft => 'Draft',
      _RosterPlannerStatus.gap => 'Gap',
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF55C2FF).withValues(alpha: 0.18),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${day.date.day}',
                      style: GoogleFonts.inter(
                        color: _guardsTitleColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 0.95,
                      ),
                    ),
                    const Spacer(),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x1F55C2FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x6655C2FF)),
                        ),
                        child: Text(
                          'TODAY',
                          style: GoogleFonts.inter(
                            color: _guardsAccentBlue,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.inter(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  hasAssignments
                      ? '${day.assignments.length} assignment${day.assignments.length == 1 ? '' : 's'}'
                      : 'No assignments',
                  style: GoogleFonts.inter(
                    color: hasAssignments
                        ? _guardsTitleColor
                        : _guardsBodyColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasAssignments
                      ? '${day.openPosts} open post${day.openPosts == 1 ? '' : 's'}'
                      : 'Tap to plan coverage',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: day.openPosts > 0
                        ? const Color(0xFFFFC247)
                        : const Color(0xFF6F859F),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectedRosterDayPanel(_RosterCalendarDay day) {
    return Container(
      key: const ValueKey('guards-roster-day-detail-panel'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _guardsPanelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _guardsBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Day',
            style: GoogleFonts.inter(
              color: _guardsMutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _formatRosterDate(day.date),
            style: GoogleFonts.inter(
              color: _guardsTitleColor,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 0.96,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _countPill(
                '${day.assignedPosts}/${day.requiredPosts} Filled',
                const Color(0xFF63E6A1),
                const Color(0x1A10B981),
                const Color(0x5510B981),
              ),
              _rosterStatusPill(day),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            day.openPosts == 0
                ? 'All required posts are covered for the selected day.'
                : '${day.openPosts} open post${day.openPosts == 1 ? '' : 's'} still need assignment before publish.',
            style: GoogleFonts.inter(
              color: _guardsBodyColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Assignments',
            style: GoogleFonts.inter(
              color: _guardsTitleColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 10),
          if (day.assignments.isEmpty)
            Text(
              'No assignments staged yet.',
              style: GoogleFonts.inter(
                color: _guardsBodyColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < day.assignments.length; i++) ...[
                  _rosterAssignmentRow(day.assignments[i]),
                  if (i != day.assignments.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _weeklyRosterSnapshot(List<_ShiftRosterRow> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _guardsPanelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _guardsBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURRENT WEEK SNAPSHOT',
            style: GoogleFonts.inter(
              color: _guardsTitleColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Keep the week matrix visible while the month calendar drives planning.',
            style: GoogleFonts.inter(
              color: _guardsBodyColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1120),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: _guardsBorderColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        _rosterHeaderCell('GUARD', width: 170),
                        _rosterHeaderCell('SITE', width: 170),
                        for (final day in ['MON', 'TUE', 'WED', 'THU', 'FRI'])
                          _rosterHeaderCell(day, width: 156, centered: true),
                      ],
                    ),
                  ),
                  for (int index = 0; index < rows.length; index++) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 170,
                            child: _rosterGuardCell(rows[index]),
                          ),
                          SizedBox(
                            width: 170,
                            child: _rosterSiteCell(rows[index]),
                          ),
                          for (final block in rows[index].blocks)
                            SizedBox(
                              width: 156,
                              child: block == null
                                  ? _emptyRosterBlock()
                                  : _rosterBlock(block),
                            ),
                        ],
                      ),
                    ),
                    if (index != rows.length - 1) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rosterPlannerActionButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool emphasized = false,
  }) {
    final foreground = emphasized ? Colors.white : _guardsTitleColor;
    final background = emphasized ? const Color(0xFF356CFF) : _guardsPanelColor;
    final disabledBackground = emphasized
        ? const Color(0xFFBFD0EA)
        : _guardsPanelTint;
    return FilledButton.tonalIcon(
      key: key,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: disabledBackground,
        disabledForegroundColor: const Color(0xFF66778E),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: emphasized
              ? BorderSide.none
              : const BorderSide(color: _guardsStrongBorderColor),
        ),
      ),
    );
  }

  Widget _shiftHistoryView() {
    final historyRows = (_liveGuards?.isNotEmpty ?? false)
        ? _buildShiftHistoryRows(_effectiveGuards)
        : _shiftHistoryRows;
    final rows = _siteFilter == 'ALL'
        ? historyRows
        : historyRows
              .where((row) => row.siteCode == _siteFilter)
              .toList(growable: false);
    final activeCount = rows.where((row) => row.statusLabel == 'ACTIVE').length;
    final completeCount = rows
        .where((row) => row.statusLabel == 'COMPLETED')
        .length;

    return _panel(
      key: const ValueKey('guards-shift-history-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SHIFT HISTORY & TIMESHEETS',
                      style: GoogleFonts.inter(
                        color: _guardsTitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'All clock in/out events and shift records',
                      style: GoogleFonts.inter(
                        color: _guardsBodyColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _countPill(
                '$activeCount Active',
                const Color(0xFF54C8FF),
                const Color(0x1A22D3EE),
                const Color(0x5522D3EE),
              ),
              const SizedBox(width: 8),
              _countPill(
                '$completeCount Completed',
                const Color(0xFF63E6A1),
                const Color(0x1A10B981),
                const Color(0x5510B981),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1160),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: _guardsBorderColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        _historyHeaderCell('DATE', width: 130),
                        _historyHeaderCell('GUARD', width: 170),
                        _historyHeaderCell('SITE', width: 170),
                        _historyHeaderCell('CLOCK IN', width: 110),
                        _historyHeaderCell('CLOCK OUT', width: 120),
                        _historyHeaderCell('DURATION', width: 120),
                        _historyHeaderCell('STATUS', width: 130),
                        _historyHeaderCell('HANDLED BY', width: 120),
                      ],
                    ),
                  ),
                  for (int index = 0; index < rows.length; index++) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _historyCell(
                            width: 130,
                            child: _historyText(rows[index].date),
                          ),
                          _historyCell(
                            width: 170,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _historyStrongText(rows[index].displayName),
                                const SizedBox(height: 4),
                                _historyText(rows[index].employeeId),
                              ],
                            ),
                          ),
                          _historyCell(
                            width: 170,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _historyStrongText(rows[index].siteCode),
                                const SizedBox(height: 4),
                                _historyText(rows[index].siteName),
                              ],
                            ),
                          ),
                          _historyCell(
                            width: 110,
                            child: _historyText(rows[index].clockIn),
                          ),
                          _historyCell(
                            width: 120,
                            child: _historyText(rows[index].clockOut),
                          ),
                          _historyCell(
                            width: 120,
                            child: _historyStrongText(
                              rows[index].duration,
                              color: const Color(0xFF54C8FF),
                            ),
                          ),
                          _historyCell(
                            width: 130,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: rows[index].statusBackground,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: rows[index].statusBorder,
                                ),
                              ),
                              child: Text(
                                rows[index].statusLabel,
                                style: GoogleFonts.inter(
                                  color: rows[index].statusForeground,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          _historyCell(
                            width: 120,
                            child: _historyText(rows[index].handledBy),
                          ),
                        ],
                      ),
                    ),
                    if (index != rows.length - 1) const SizedBox(height: 6),
                  ],
                ],
              ),
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
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _guardsSelectedPanelColor : _guardsPanelColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? _guardsStrongBorderColor : _guardsBorderColor,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? _guardsAccentBlue : _guardsTitleColor,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _viewTab({
    required Key key,
    required String label,
    required IconData icon,
    required bool compact,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 14,
            vertical: compact ? 16 : 18,
          ),
          decoration: BoxDecoration(
            color: selected ? _guardsSelectedPanelColor : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _guardsStrongBorderColor : Colors.transparent,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final hideIcon = compact || constraints.maxWidth < 132;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!hideIcon) ...[
                    Icon(
                      icon,
                      size: 18,
                      color: selected ? _guardsAccentBlue : _guardsBodyColor,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: selected ? _guardsAccentBlue : _guardsBodyColor,
                        fontSize: compact ? 12 : 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _detailTile({
    required String title,
    required String value,
    required String detail,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _guardsPanelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _guardsBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: _guardsMutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.inter(
              color: _guardsTitleColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: _guardsBodyColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _guardsPanelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _guardsBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: _guardsMutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.inter(
              color: _guardsTitleColor,
              fontSize: value.length > 6 ? 30 : 36,
              fontWeight: FontWeight.w700,
              height: 0.92,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionTile({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: _guardsPanelColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _guardsBorderColor),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: enabled ? _guardsAccentBlue : const Color(0xFF66778E),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: enabled
                        ? _guardsTitleColor
                        : const Color(0xFF66778E),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: enabled ? _guardsBodyColor : const Color(0xFF556273),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel({Key? key, required Widget child}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _guardsPanelColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _guardsBorderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D1726),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required Color foreground,
    required Color background,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _countPill(
    String label,
    Color foreground,
    Color background,
    Color border,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _rosterStatusPill(_RosterCalendarDay day) {
    final (label, foreground, background, border) = switch (day.status) {
      _RosterPlannerStatus.published => (
        'Published',
        const Color(0xFF63E6A1),
        const Color(0x1A10B981),
        const Color(0x5510B981),
      ),
      _RosterPlannerStatus.draft => (
        'Draft',
        const Color(0xFFF6C067),
        const Color(0x1AF59E0B),
        const Color(0x55F59E0B),
      ),
      _RosterPlannerStatus.gap => (
        'Gap',
        const Color(0xFFFF8E8E),
        const Color(0x1AF43F5E),
        const Color(0x55F43F5E),
      ),
    };
    return _countPill(label, foreground, background, border);
  }

  Widget _rosterHeaderCell(
    String label, {
    required double width,
    bool centered = false,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        textAlign: centered ? TextAlign.center : TextAlign.left,
        style: GoogleFonts.inter(
          color: _guardsMutedColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _rosterGuardCell(_ShiftRosterRow row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.displayName,
          style: GoogleFonts.inter(
            color: _guardsTitleColor,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          row.employeeId,
          style: GoogleFonts.robotoMono(
            color: _guardsMutedColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _rosterSiteCell(_ShiftRosterRow row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.siteCode,
          style: GoogleFonts.inter(
            color: _guardsTitleColor,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          row.siteName,
          style: GoogleFonts.inter(
            color: _guardsBodyColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _rosterBlock(_ShiftBlock block) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: block.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: block.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              block.label,
              style: GoogleFonts.inter(
                color: block.foreground,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              block.time,
              style: GoogleFonts.inter(
                color: _guardsBodyColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyRosterBlock() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: Text(
        '-',
        style: GoogleFonts.inter(
          color: const Color(0xFF66778E),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _rosterAssignmentRow(_RosterCalendarAssignment assignment) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: assignment.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: assignment.border),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: assignment.foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment.guardName,
                  style: GoogleFonts.inter(
                    color: _guardsTitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${assignment.siteCode} • ${assignment.shiftLabel}',
                  style: GoogleFonts.inter(
                    color: _guardsBodyColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyHeaderCell(String label, {required double width}) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: _guardsMutedColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _historyCell({required double width, required Widget child}) {
    return SizedBox(width: width, child: child);
  }

  Widget _historyText(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: _guardsBodyColor,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _historyStrongText(String text, {Color? color}) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: color ?? _guardsTitleColor,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _setView(_GuardsView view) {
    if (_selectedView == view) {
      return;
    }
    setState(() => _selectedView = view);
  }

  void _setSiteFilter(String siteCode) {
    if (_siteFilter == siteCode) {
      return;
    }
    setState(() {
      _siteFilter = siteCode;
      final visible = _filteredGuards(siteCodeOverride: siteCode);
      if (visible.isNotEmpty) {
        _selectedGuardId = visible.first.id;
      }
    });
  }

  void _selectGuard(String guardId) {
    setState(() => _selectedGuardId = guardId);
  }

  List<_GuardRecord> _filteredGuards({String? siteCodeOverride}) {
    final filter = siteCodeOverride ?? _siteFilter;
    final guards = _effectiveGuards;
    if (filter == 'ALL') {
      return guards;
    }
    return guards
        .where((guard) => guard.siteCode == filter)
        .toList(growable: false);
  }

  _GuardRecord? _selectedGuard(List<_GuardRecord> visible) {
    if (visible.isEmpty) {
      return null;
    }
    for (final guard in visible) {
      if (guard.id == _selectedGuardId) {
        return guard;
      }
    }
    return visible.first;
  }

  String _resolveSiteFilter(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'all') {
      return 'ALL';
    }

    const aliases = <String, List<String>>{
      'SE-01': [
        'se-01',
        'sandton estate north',
        'wtf-main',
        'waterfall estate main',
      ],
      'WF-02': ['wf-02', 'waterfall estate', 'blue ridge security'],
      'BR-03': ['br-03', 'blue ridge residence', 'sdn-north'],
    };

    for (final entry in aliases.entries) {
      if (entry.value.contains(normalized)) {
        return entry.key;
      }
    }
    return 'ALL';
  }

  void _openGuardSchedule() {
    _openGuardScheduleForAction('quick-schedule');
  }

  void _openGuardScheduleForAction(String action, {DateTime? date}) {
    final actionCallback = widget.onOpenGuardScheduleForAction;
    final callback = widget.onOpenGuardSchedule;
    if (actionCallback == null && callback == null) {
      return;
    }
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

  List<_GuardRecord> get _effectiveGuards {
    final liveGuards = _liveGuards;
    if (liveGuards == null || liveGuards.isEmpty) {
      return _guards;
    }
    return liveGuards;
  }

  List<_RosterCalendarDay> _buildRosterCalendarDays(List<_GuardRecord> guards) {
    final allOnDuty = _effectiveGuards
        .where((guard) => guard.status == _GuardStatus.onDuty)
        .toList(growable: false);
    final scopedOnDuty = guards
        .where((guard) => guard.status == _GuardStatus.onDuty)
        .toList(growable: false);
    final planningPool = scopedOnDuty.isEmpty ? allOnDuty : scopedOnDuty;
    if (planningPool.isEmpty) {
      return const <_RosterCalendarDay>[];
    }

    final daysInMonth = DateUtils.getDaysInMonth(
      _rosterMonth.year,
      _rosterMonth.month,
    );
    return List<_RosterCalendarDay>.generate(daysInMonth, (index) {
      final dayNumber = index + 1;
      final date = DateTime.utc(
        _rosterMonth.year,
        _rosterMonth.month,
        dayNumber,
      );
      final isWeekend = date.weekday >= DateTime.saturday;
      final requiredPosts = _siteFilter == 'ALL'
          ? (isWeekend ? 3 : 5)
          : (isWeekend ? 1 : 2);
      final futureDay = date.isAfter(_rosterReferenceDate);
      final extraGap = futureDay && dayNumber % 6 == 0 ? 1 : 0;
      final assignedPosts = (requiredPosts - extraGap).clamp(
        0,
        planningPool.length,
      );
      final assignments = List<_RosterCalendarAssignment>.generate(
        assignedPosts,
        (assignmentIndex) {
          final guard =
              planningPool[(index + assignmentIndex) % planningPool.length];
          final shiftIsDay = isWeekend
              ? assignmentIndex.isEven
              : guard.shiftLabel == 'Day';
          final shiftBlock = shiftIsDay ? _dayBlock : _nightBlock;
          return _RosterCalendarAssignment(
            guardName: guard.contactName,
            siteCode: guard.siteCode,
            shiftLabel: shiftBlock.time,
            foreground: shiftBlock.foreground,
            background: shiftBlock.background,
            border: shiftBlock.border,
          );
        },
        growable: false,
      );
      final openPosts = requiredPosts - assignedPosts;
      final status = openPosts > 0
          ? _RosterPlannerStatus.gap
          : futureDay
          ? _RosterPlannerStatus.draft
          : _RosterPlannerStatus.published;
      return _RosterCalendarDay(
        date: date,
        assignedPosts: assignedPosts,
        requiredPosts: requiredPosts,
        openPosts: openPosts,
        status: status,
        assignments: assignments,
      );
    }, growable: false);
  }

  bool _sameRosterDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  void _selectRosterDate(DateTime date) {
    setState(() {
      _selectedRosterDate = date;
    });
  }

  String _formatRosterDate(DateTime date) {
    const months = <int, String>{
      1: 'Jan',
      2: 'Feb',
      3: 'Mar',
      4: 'Apr',
      5: 'May',
      6: 'Jun',
      7: 'Jul',
      8: 'Aug',
      9: 'Sep',
      10: 'Oct',
      11: 'Nov',
      12: 'Dec',
    };
    const weekdays = <int, String>{
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Sunday',
    };
    return '${weekdays[date.weekday]} ${date.day} ${months[date.month]}';
  }

  void _openReportsForSelectedSite(BuildContext context) {
    final guard = _selectedGuard(_filteredGuards());
    if (guard == null) {
      return;
    }
    _openReportsForSite(context, guard);
  }

  void _openReportsForSite(BuildContext context, _GuardRecord guard) {
    final callback = widget.onOpenGuardReportsForSite;
    if (callback == null) {
      _showReportsLinkDialog(context);
      return;
    }
    logUiAction(
      'guards_reports_opened',
      context: <String, Object?>{
        'site_id': guard.routeSiteId,
        'guard_id': guard.id,
      },
    );
    callback(guard.routeSiteId);
  }

  void _showReportsLinkDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFFFF),
          title: Text(
            'Reports Workspace Ready',
            style: GoogleFonts.inter(
              color: _guardsTitleColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Use Reports Workspace to review workforce documentation, schedule exports, and field-performance outputs tied to the selected guard or site.',
            style: GoogleFonts.inter(color: _guardsBodyColor, height: 1.45),
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

  Future<void> _loadLiveGuards() async {
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
      final operations = await repository.readOperations(
        statuses: Set<GuardSyncOperationStatus>.from(
          GuardSyncOperationStatus.values,
        ),
        limit: 500,
      );
      final liveGuards = _mergeLiveGuards(assignments, operations);
      if (!mounted) {
        return;
      }
      setState(() {
        _liveGuards = liveGuards.isEmpty ? null : liveGuards;
        final visible = _filteredGuards();
        if (visible.isNotEmpty &&
            !visible.any((guard) => guard.id == _selectedGuardId)) {
          _selectedGuardId = visible.first.id;
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

  List<_GuardRecord> _mergeLiveGuards(
    List<GuardAssignment> assignments,
    List<GuardSyncOperation> operations,
  ) {
    if (assignments.isEmpty && operations.isEmpty) {
      return const <_GuardRecord>[];
    }
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
    final operationsByGuard = <String, List<GuardSyncOperation>>{};
    for (final operation in operations) {
      final guardId = (operation.payload['guard_id'] ?? '').toString().trim();
      if (guardId.isEmpty) {
        continue;
      }
      operationsByGuard.putIfAbsent(guardId, () => <GuardSyncOperation>[]).add(
        operation,
      );
    }
    for (final guardOperations in operationsByGuard.values) {
      guardOperations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
      final dutyCmp = (a.status == _GuardStatus.onDuty ? 0 : 1).compareTo(
        b.status == _GuardStatus.onDuty ? 0 : 1,
      );
      if (dutyCmp != 0) {
        return dutyCmp;
      }
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
      (guard) => guard != null && guard.id == guardId,
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
        assignment?.acknowledgedAt ??
        assignment?.issuedAt ??
        latestOperation?.createdAt;
    final shiftLabel = _shiftLabelFor(clockInAt, fallback: seed?.shiftLabel);
    final shiftWindow = status == _GuardStatus.onDuty
        ? _shiftWindowFor(shiftLabel)
        : '--';
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
          operations.any(
            (operation) => operation.status == GuardSyncOperationStatus.failed,
          ) ||
          (operations.isEmpty && (seed?.hasSyncIssue ?? false)),
      clockIn: clockInAt == null ? '--' : _timeLabel(clockInAt),
      shiftWindow: shiftWindow,
      lastSync: latestOperation == null
          ? (seed?.lastSync ?? 'offline')
          : _relativeTimeLabel(latestOperation.createdAt),
      obEntries: operations
          .where(
            (operation) =>
                operation.type == GuardSyncOperationType.checkpointScan,
          )
          .length,
      incidents: operations
          .where(
            (operation) =>
                operation.type == GuardSyncOperationType.incidentCapture ||
                operation.type == GuardSyncOperationType.panicSignal,
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
    for (final operation in operations) {
      final status = _guardDutyStatusFromOperation(operation);
      if (status == null) {
        continue;
      }
      return status == GuardDutyStatus.offline
          ? _GuardStatus.offDuty
          : _GuardStatus.onDuty;
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
      (value) => value != null && value.name == rawStatus,
      orElse: () => null,
    );
  }

  String _guardRouteSiteId({
    required GuardAssignment? assignment,
    required List<GuardSyncOperation> operations,
    required _GuardRecord? seed,
  }) {
    final assignmentSiteId = assignment?.siteId.trim() ?? '';
    if (assignmentSiteId.isNotEmpty) {
      return assignmentSiteId;
    }
    for (final operation in operations) {
      final siteId = (operation.payload['site_id'] ?? '').toString().trim();
      if (siteId.isNotEmpty) {
        return siteId;
      }
    }
    return seed?.routeSiteId ?? '';
  }

  ({String code, String name}) _siteSummaryForRouteSiteId(
    String routeSiteId, {
    _GuardRecord? seed,
  }) {
    final normalizedRouteSiteId = routeSiteId.trim().toLowerCase();
    if (normalizedRouteSiteId.isEmpty) {
      return (code: '--', name: 'No active assignment');
    }
    for (final guard in _guards) {
      if (guard.routeSiteId.trim().toLowerCase() == normalizedRouteSiteId ||
          guard.siteCode.trim().toLowerCase() == normalizedRouteSiteId) {
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
    if (startedAt == null) {
      return fallback ?? 'Off Duty';
    }
    final hour = startedAt.toUtc().hour;
    if (hour >= 6 && hour < 18) {
      return 'Day';
    }
    return 'Night';
  }

  String _shiftWindowFor(String shiftLabel) {
    return shiftLabel == 'Day' ? '06:00 - 18:00' : '18:00 - 06:00';
  }

  String _timeLabel(DateTime value) {
    final time = value.toUtc();
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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

  String _avgResponseLabel({
    required GuardAssignment? assignment,
    required List<GuardSyncOperation> operations,
    required String? fallback,
  }) {
    if (assignment == null) {
      return fallback ?? '--';
    }
    for (final operation in operations) {
      final status = _guardDutyStatusFromOperation(operation);
      if (status != GuardDutyStatus.enRoute && status != GuardDutyStatus.onSite) {
        continue;
      }
      final delta = operation.createdAt.difference(assignment.issuedAt);
      return '${delta.inSeconds.clamp(0, 99999)}s';
    }
    return fallback ?? '--';
  }

  String _compactGuardLabel(String guardId) {
    final normalized = guardId.trim();
    if (normalized.isEmpty) {
      return 'Unknown Guard';
    }
    final humanized = _humanizeScopeLabel(normalized);
    final parts = humanized
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length >= 2) {
      return '${parts.first[0]}. ${parts.last}';
    }
    return humanized;
  }

  List<String> _availableSiteFilters(List<_GuardRecord> guards) {
    final codes = guards
        .map((guard) => guard.siteCode)
        .where((code) => code != '--')
        .toSet()
        .toList(growable: false)
      ..sort();
    return <String>['ALL', ...codes];
  }

  List<_ShiftRosterRow> _buildShiftRosterRows(List<_GuardRecord> guards) {
    return guards
        .map(
          (guard) => _ShiftRosterRow(
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
          ),
        )
        .toList(growable: false);
  }

  List<_ShiftHistoryRow> _buildShiftHistoryRows(List<_GuardRecord> guards) {
    final nowUtc = DateTime.now().toUtc();
    final activeGuards = guards
        .where((guard) => guard.status == _GuardStatus.onDuty)
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
          statusForeground: const Color(0xFF5BD4FF),
          statusBackground: const Color(0x1A22D3EE),
          statusBorder: const Color(0x5522D3EE),
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
          statusForeground: const Color(0xFF63E6A1),
          statusBackground: const Color(0x1A10B981),
          statusBorder: const Color(0x5510B981),
          handledBy: guard.handler,
        ),
    ];
  }

  String _historyDateLabel(DateTime value) {
    final utc = value.toUtc();
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    return '${utc.year}-$month-$day';
  }

  String _activeShiftDurationLabel(String clockIn, DateTime nowUtc) {
    final parts = clockIn.split(':');
    if (parts.length != 2) {
      return '--';
    }
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    var startedAt = DateTime.utc(
      nowUtc.year,
      nowUtc.month,
      nowUtc.day,
      hour,
      minute,
    );
    if (startedAt.isAfter(nowUtc)) {
      startedAt = startedAt.subtract(const Duration(days: 1));
    }
    final elapsed = nowUtc.difference(startedAt);
    return '${elapsed.inHours}h ${(elapsed.inMinutes % 60).toString().padLeft(2, '0')}m';
  }

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
        backgroundColor: _guardsPanelColor,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Clock-out flow for ${guard.displayName} is ready for the next wiring pass.',
          style: GoogleFonts.inter(
            color: _guardsTitleColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _copyGuardContact(_GuardRecord guard) async {
    await Clipboard.setData(ClipboardData(text: guard.contactPhone));
    if (!mounted) {
      return;
    }
    logUiAction(
      'guard_contact_copied',
      context: <String, Object?>{
        'guard_id': guard.id,
        'site_id': guard.routeSiteId,
      },
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _guardsPanelColor,
        behavior: SnackBarBehavior.floating,
        content: Text(
          '${guard.contactName} contact copied.',
          style: GoogleFonts.inter(
            color: _guardsTitleColor,
            fontWeight: FontWeight.w700,
          ),
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
    final primaryActionAvailable = isMessage
        ? clientLaneAvailable
        : voipAvailable;
    final primaryStatusLabel = isMessage
        ? (clientLaneAvailable ? 'Client Comms ready' : 'Client Comms offline')
        : (voipAvailable ? 'VoIP ready' : 'VoIP offline');
    final readinessNote = isMessage
        ? (clientLaneAvailable
              ? 'Open Client Comms to keep guard outreach warm, logged, and tied to the site thread.'
              : 'Client Comms routing is not connected in this session yet, so this handoff stays view-only for now.')
        : (voipAvailable
              ? 'Stage the voice handoff now so control carries the right guard contact into the call flow.'
              : 'VoIP staging is not connected in this session yet, so this handoff stays view-only for now.');

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
      backgroundColor: const Color(0xFFFFFFFF),
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
                  color: _guardsTitleColor,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isMessage
                    ? 'Use Client Comms for warm, traceable outreach. Telegram stays primary and SMS remains fallback-only once delivery wiring is live.'
                    : 'Stage the voice handoff now so control has the right contact context ready when VoIP lands.',
                style: GoogleFonts.inter(
                  color: _guardsBodyColor,
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
                    label: '${guard.siteCode} • ${guard.siteName}',
                    accent: const Color(0xFF10B981),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _contactDetailRow('Guard', guard.contactName),
              _contactDetailRow('Employee', guard.employeeId),
              _contactDetailRow('Current Site', guard.siteName),
              _contactDetailRow('Contact', guard.contactPhone),
              const SizedBox(height: 14),
              Text(
                readinessNote,
                style: GoogleFonts.inter(
                  color: primaryActionAvailable
                      ? _guardsBodyColor
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
                      key: const ValueKey('guards-contact-copy-button'),
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await _copyGuardContact(guard);
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _guardsAccentBlue,
                        side: const BorderSide(color: _guardsStrongBorderColor),
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
                      key: const ValueKey('guards-contact-primary-button'),
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
                                    'site_id': guard.routeSiteId,
                                  },
                                );
                                callback(guard.routeSiteId);
                                return;
                              }
                              final callback = widget.onStageGuardVoipCall;
                              if (callback == null) {
                                return;
                              }
                              final message = await callback(
                                guard.id,
                                guard.contactName,
                                guard.routeSiteId,
                                guard.contactPhone,
                              );
                              if (!mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: _guardsPanelColor,
                                  behavior: SnackBarBehavior.floating,
                                  content: Text(
                                    message,
                                    style: GoogleFonts.inter(
                                      color: _guardsTitleColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              );
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2B5E93),
                        foregroundColor: Colors.white,
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
                        isMessage ? 'OPEN CLIENT COMMS' : 'Stage VoIP Call',
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
                color: _guardsMutedColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: _guardsTitleColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _humanizeScopeLabel(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return '-';
    }
    final words = normalized
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) {
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .toList(growable: false);
    return words.join(' ');
  }
}
