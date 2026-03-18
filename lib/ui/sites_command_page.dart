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
import 'onyx_surface.dart';
import 'ui_action_logger.dart';

class SitesCommandPage extends StatefulWidget {
  final List<DispatchEvent> events;
  final VoidCallback? onAddSite;
  final void Function(String siteId, String siteName)? onOpenMapForSite;
  final void Function(String siteId, String siteName)? onOpenSiteSettings;
  final void Function(String siteId, String siteName)? onOpenGuardRoster;

  const SitesCommandPage({
    super.key,
    required this.events,
    this.onAddSite,
    this.onOpenMapForSite,
    this.onOpenSiteSettings,
    this.onOpenGuardRoster,
  });

  @override
  State<SitesCommandPage> createState() => _SitesCommandPageState();
}

class _SitesCommandPageState extends State<SitesCommandPage> {
  String? _selectedSiteId;

  @override
  Widget build(BuildContext context) {
    final projected = _siteRowsFromEvents(widget.events);
    final sites = projected.isEmpty ? _seedSites() : projected;

    _selectedSiteId ??= sites.first.id;
    final selected = sites.firstWhere(
      (site) => site.id == _selectedSiteId,
      orElse: () => sites.first,
    );

    final strongCount = sites
        .where((site) => site.status == _SiteStatus.strong)
        .length;
    final atRiskCount = sites
        .where(
          (site) =>
              site.status == _SiteStatus.atRisk ||
              site.status == _SiteStatus.critical,
        )
        .length;
    final totalGuards = sites.fold<int>(
      0,
      (sum, site) => sum + site.guardsActive,
    );

    return OnyxPageScaffold(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1540),
            child: ListView(
              children: [
                Text(
                  'SITE COMMAND GRID',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE8EEF7),
                    fontSize: 49,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.9,
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;
                    final width = maxWidth < 920
                        ? (maxWidth - 8) / 2
                        : (maxWidth - 24) / 4;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _kpiCard(
                          width: width,
                          label: 'TOTAL SITES',
                          value: '${sites.length}',
                          icon: Icons.apartment_rounded,
                          iconColor: const Color(0xFF22D3EE),
                        ),
                        _kpiCard(
                          width: width,
                          label: 'STRONG POSTURE',
                          value: '$strongCount',
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: const Color(0xFF22D3EE),
                        ),
                        _kpiCard(
                          width: width,
                          label: 'AT RISK',
                          value: '$atRiskCount',
                          icon: Icons.warning_amber_rounded,
                          iconColor: const Color(0xFF22D3EE),
                        ),
                        _kpiCard(
                          width: width,
                          label: 'TOTAL GUARDS',
                          value: '$totalGuards',
                          icon: Icons.shield_outlined,
                          iconColor: const Color(0xFF22D3EE),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 1240;
                    final roster = _rosterPane(sites);
                    final workspace = _workspacePane(selected);
                    if (stacked) {
                      return Column(
                        children: [
                          roster,
                          const SizedBox(height: 8),
                          workspace,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: roster),
                        const SizedBox(width: 8),
                        Expanded(flex: 8, child: workspace),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kpiCard({
    required double width,
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E141C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2A3A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF6F839C),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF1FB),
                    fontSize: 54,
                    height: 0.95,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF142132),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _rosterPane(List<_SiteViewModel> sites) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E141C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2A3A)),
      ),
      child: Column(
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
                borderRadius: BorderRadius.circular(8),
                onTap: widget.onAddSite == null
                    ? null
                    : () {
                        logUiAction(
                          'sites.add_site',
                          context: {'selected_site_id': _selectedSiteId},
                        );
                        widget.onAddSite!.call();
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: widget.onAddSite == null
                        ? const Color(0xFF1D2937)
                        : const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.onAddSite == null
                          ? const Color(0xFF314154)
                          : const Color(0x80448FFF),
                    ),
                  ),
                  child: Text(
                    'ADD SITE',
                    style: GoogleFonts.inter(
                      color: widget.onAddSite == null
                          ? const Color(0xFF8EA4C2)
                          : const Color(0xFFEAF1FB),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final site in sites) ...[
            _rosterRow(site),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _rosterRow(_SiteViewModel site) {
    final selected = site.id == _selectedSiteId;
    final status = _statusColor(site.status);
    return InkWell(
      onTap: () => setState(() => _selectedSiteId = site.id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF10333B) : const Color(0xFF0D131A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF1F7F95) : const Color(0xFF1F2B3B),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: status.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _statusIcon(site.status),
                color: const Color(0xFFEAF1FB),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    site.displayName,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF1FB),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    site.location,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9BB0C8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Guards: ${site.guardsActive}/${site.guardsTotal}    Incidents: ${site.incidentsToday}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8EA4C2),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 18,
              height: 8,
              decoration: BoxDecoration(
                color: status.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: status.withValues(alpha: 0.45)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _workspacePane(_SiteViewModel site) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E141C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2A3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SITE OPERATIONS WORKSPACE',
            style: GoogleFonts.inter(
              color: const Color(0xFF7B8FA8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            site.displayName,
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF1FB),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            site.location,
            style: GoogleFonts.inter(
              color: const Color(0xFFA5B6CB),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniButton(
                'VIEW ON MAP',
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
                'SITE SETTINGS',
                key: const ValueKey('sites-site-settings-button'),
                enabled: widget.onOpenSiteSettings != null,
                onTap: () {
                  logUiAction(
                    'sites.open_settings',
                    context: {
                      'site_id': site.id,
                      'site_name': site.displayName,
                    },
                  );
                  widget.onOpenSiteSettings!.call(site.id, site.displayName);
                },
              ),
              _miniButton(
                'GUARD ROSTER',
                key: const ValueKey('sites-guard-roster-button'),
                enabled: widget.onOpenGuardRoster != null,
                onTap: () {
                  logUiAction(
                    'sites.open_guard_roster',
                    context: {
                      'site_id': site.id,
                      'site_name': site.displayName,
                    },
                  );
                  widget.onOpenGuardRoster!.call(site.id, site.displayName);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final cell = width < 760 ? (width - 8) / 2 : (width - 24) / 4;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _smallKpiCard(
                    width: cell,
                    title: 'ACTIVE GUARDS',
                    value: '${site.guardsActive}/${site.guardsTotal}',
                    helper: 'Full strength',
                    helperColor: const Color(0xFF00D084),
                  ),
                  _smallKpiCard(
                    width: cell,
                    title: 'INCIDENTS TODAY',
                    value: '${site.incidentsToday}',
                    helper: 'Last: ${site.lastIncident}',
                    helperColor: const Color(0xFF8EA4C2),
                  ),
                  _smallKpiCard(
                    width: cell,
                    title: 'RESPONSE RATE',
                    value: '${site.responseRate.toStringAsFixed(0)}%',
                    helper: '+2% vs avg',
                    helperColor: const Color(0xFF00D084),
                  ),
                  _smallKpiCard(
                    width: cell,
                    title: 'CHECKPOINTS',
                    value:
                        '${site.checkpointsCompleted}/${site.checkpointsTotal}',
                    helper:
                        '${((site.checkpointsCompleted / (site.checkpointsTotal <= 0 ? 1 : site.checkpointsTotal)) * 100).round()}% complete',
                    helperColor: const Color(0xFF8EA4C2),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          _panelCard(
            title: 'DISPATCH OUTCOME MIX (30 DAYS)',
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
          const SizedBox(height: 8),
          _panelCard(
            title: 'OPERATIONAL PULSE',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 780;
                final left = _pulseColumn([
                  const _PulseMetric(
                    'Patrol Coverage',
                    '96%',
                    Color(0xFF10B981),
                  ),
                  const _PulseMetric(
                    'Checkpoint Compliance',
                    '98%',
                    Color(0xFF10B981),
                  ),
                  const _PulseMetric(
                    'Avg Response Time',
                    '4.2 min',
                    Color(0xFF38BDF8),
                  ),
                ]);
                final right = _pulseColumn([
                  const _PulseMetric(
                    'Client Satisfaction',
                    '4.8/5.0',
                    Color(0xFF10B981),
                  ),
                  const _PulseMetric(
                    'Guard Vigilance',
                    'Strong',
                    Color(0xFF10B981),
                  ),
                  const _PulseMetric(
                    'Equipment Status',
                    'Optimal',
                    Color(0xFF10B981),
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
      ),
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: enabled
              ? (primary ? const Color(0xFF3B82F6) : const Color(0xFF111822))
              : const Color(0xFF1D2937),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? (primary
                      ? const Color(0xFF4E8FFF)
                      : const Color(0xFF2A374A))
                : const Color(0xFF314154),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: enabled
                ? const Color(0xFFEAF1FB)
                : const Color(0xFF8EA4C2),
            fontSize: 11,
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
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111822),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A374A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFF7D93B1),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF1FB),
              fontSize: 41,
              height: 0.95,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            helper,
            style: GoogleFonts.inter(
              color: helperColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF111822),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A374A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFF9BB0CE),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
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
                color: const Color(0xFFD9E7FA),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '$percent%',
              style: GoogleFonts.inter(
                color: const Color(0xFFEAF1FB),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 8,
            child: LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: const Color(0xFF0A0E14),
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
                    color: const Color(0xFFA5B6CB),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                metric.value,
                style: GoogleFonts.inter(
                  color: metric.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _PulseMetric {
  final String label;
  final String value;
  final Color color;

  const _PulseMetric(this.label, this.value, this.color);
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
