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
  String _selectedGuardId = 'GRD-441';

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
    final selected = _selectedGuard(filtered);
    final sites = _siteOptions();
    final headerGuard = selected ?? _guards.first;

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

    return OnyxPageScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(headerGuard),
                const SizedBox(height: 10),
                _kpis(
                  onDutyCount: onDutyCount,
                  offDutyCount: offDutyCount,
                  onBreakCount: onBreakCount,
                  offlineCount: offlineCount,
                ),
                const SizedBox(height: 10),
                wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _guardListPanel(
                              guards: filtered,
                              siteOptions: sites,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 4,
                            child: _guardDetailPanel(guard: selected),
                          ),
                          const SizedBox(width: 10),
                          Expanded(flex: 3, child: _activityPanel()),
                        ],
                      )
                    : Column(
                        children: [
                          _guardListPanel(guards: filtered, siteOptions: sites),
                          const SizedBox(height: 10),
                          _guardDetailPanel(guard: selected),
                          const SizedBox(height: 10),
                          _activityPanel(),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
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
          onPressed: scheduleAvailable
              ? () {
                  final callback = widget.onOpenGuardSchedule;
                  if (callback == null) {
                    return;
                  }
                  logUiAction('guards_schedule_opened');
                  callback();
                }
              : null,
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
      padding: const EdgeInsets.all(12),
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
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            spec.value,
            style: GoogleFonts.rajdhani(
              color: spec.color,
              fontSize: 34,
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
    required List<DropdownMenuItem<String>> siteOptions,
  }) {
    return _panelSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Active Guards'),
          const SizedBox(height: 8),
          _searchField(),
          const SizedBox(height: 8),
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
          const SizedBox(height: 10),
          if (guards.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1117),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x332B425F)),
              ),
              child: Text(
                'No guards match current filters.',
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
                  if (i != guards.length - 1) const SizedBox(height: 8),
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

    return InkWell(
      onTap: () => setState(() => _selectedGuardId = guard.id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? const Color(0x1A22D3EE) : const Color(0xFF0C1117),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0x8022D3EE) : const Color(0x332B425F),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
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
            const SizedBox(width: 10),
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
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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
                  const SizedBox(height: 4),
                  Text(
                    guard.site,
                    style: GoogleFonts.inter(
                      color: const Color(0xCCFFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
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
                    ],
                  ),
                  if (guard.clockInTime != null) ...[
                    const SizedBox(height: 5),
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
                        ],
                      ],
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

  Widget _guardDetailPanel({required _GuardRecord? guard}) {
    return _panelSurface(
      child: guard == null
          ? _emptyHint('Select a guard to view details.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Guard Profile'),
                const SizedBox(height: 10),
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: const Color(0xFF1A2A3D),
                        child: Text(
                          _initials(guard.name),
                          style: GoogleFonts.inter(
                            color: const Color(0xFF8FD1FF),
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        guard.name,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFEAF4FF),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        guard.employeeId,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF8EA4C2),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _statusChip(_statusStyle(guard.status)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _subPanel(
                  child: Column(
                    children: [
                      _kv('Current Site', guard.site),
                      _kv(
                        'Shift Hours',
                        '${guard.shiftStart} - ${guard.shiftEnd}',
                      ),
                      if (guard.clockInTime != null)
                        _kv(
                          'Clock In',
                          guard.clockInPhotoVerified
                              ? '${guard.clockInTime} • photo verified'
                              : guard.clockInTime!,
                          valueColor: const Color(0xFF10B981),
                        ),
                      _kv('Last Heartbeat', guard.lastHeartbeat),
                      _kv('Emergency', guard.emergencyContact),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _metricMini('Battery', '${guard.battery}%'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricMini('Signal', '${guard.signalStrength}%'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _subPanel(
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
                    const SizedBox(width: 8),
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
                const SizedBox(height: 10),
                _sectionTitle('Performance (24h)'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _metricMini('OB Entries', '${guard.obEntries}'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricMini('Incidents', '${guard.incidents}'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _metricMini('Patrols', '${guard.patrols}')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricMini(
                        'Compliance',
                        '${guard.compliance}%',
                        valueColor: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _subPanel(
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
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: guard.certifications
                            .map(
                              (cert) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x1A3B82F6),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0x553B82F6),
                                  ),
                                ),
                                child: Text(
                                  cert,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF8FD1FF),
                                    fontSize: 11,
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

  Widget _activityPanel() {
    return _panelSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Recent Activity'),
          const SizedBox(height: 8),
          Column(
            children: [
              for (int i = 0; i < _recentShiftChanges.length; i++) ...[
                _shiftChangeCard(_recentShiftChanges[i]),
                if (i != _recentShiftChanges.length - 1)
                  const SizedBox(height: 8),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: const Color(0x332B425F)),
          const SizedBox(height: 10),
          Text(
            'System Alerts',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _alertCard(
            title: 'Low Battery Alert',
            detail: 'Precious Sithole (GRD-447) - Battery at 12%',
            color: const Color(0xFFEF4444),
            icon: Icons.battery_alert_rounded,
          ),
          const SizedBox(height: 8),
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
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x332B425F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF151E2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(style.icon, color: style.color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  change.guardName,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 12,
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
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
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
      padding: const EdgeInsets.all(10),
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
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
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

  Widget _panelSurface({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: child,
    );
  }

  Widget _subPanel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(10),
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
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: 'Search by name, ID, or site...',
        hintStyle: GoogleFonts.inter(
          color: const Color(0x668EA4C2),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 18,
          color: Color(0xFF8EA4C2),
        ),
        filled: true,
        fillColor: const Color(0xFF0C1117),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
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
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF0C1117),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
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
        fontSize: 23,
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
            fontSize: 11,
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
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              color: valueColor ?? const Color(0xFFEAF4FF),
              fontSize: 28,
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

  void _showToast(String message) {
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
    _showToast('${guard.name} contact copied.');
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
    final primaryActionAvailable = isMessage ? clientLaneAvailable : voipAvailable;
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
                              _showToast(message);
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
