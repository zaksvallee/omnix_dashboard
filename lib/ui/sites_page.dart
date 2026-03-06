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
import 'onyx_surface.dart';

class SitesPage extends StatefulWidget {
  final List<DispatchEvent> events;

  const SitesPage({super.key, required this.events});

  @override
  State<SitesPage> createState() => _SitesPageState();
}

class _SitesPageState extends State<SitesPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final projection = OperationsHealthProjection.build(widget.events);
    final sites = _buildSiteDrillSnapshots(widget.events, projection);

    if (sites.isEmpty) {
      return const OnyxPageScaffold(
        child: OnyxEmptyState(
          label: 'No sites available in the current projection.',
        ),
      );
    }

    final activeDispatches = sites.fold<int>(
      0,
      (total, site) => total + site.activeDispatches,
    );
    final averageHealth =
        sites.fold<double>(0, (total, site) => total + site.healthScore) /
        sites.length;

    if (_selectedIndex >= sites.length) {
      _selectedIndex = sites.length - 1;
    }

    final selected = sites[_selectedIndex];

    return OnyxPageScaffold(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const OnyxPageHeader(
                  title: 'Site Command Grid',
                  subtitle:
                      'Estate-wide posture, dispatch exposure, and site-level operational pressure.',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 236,
                      child: OnyxSummaryStat(
                        label: 'Visible Sites',
                        value: sites.length.toString(),
                        accent: const Color(0xFF63BDFF),
                      ),
                    ),
                    SizedBox(
                      width: 236,
                      child: OnyxSummaryStat(
                        label: 'Active Dispatches',
                        value: activeDispatches.toString(),
                        accent: const Color(0xFF59D79B),
                      ),
                    ),
                    SizedBox(
                      width: 236,
                      child: OnyxSummaryStat(
                        label: 'Average Health',
                        value: averageHealth.toStringAsFixed(1),
                        accent: const Color(0xFFF6C067),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: OnyxSectionCard(
                    title: 'Site Operations Workspace',
                    subtitle:
                        'Review site posture on the left, then inspect operational detail for the selected site.',
                    padding: const EdgeInsets.all(12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final stackVertically = constraints.maxWidth < 1320;

                        if (stackVertically) {
                          return SizedBox(
                            height: 680,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 232,
                                  child: _siteRoster(sites, selected),
                                ),
                                const SizedBox(height: 6),
                                Expanded(child: _siteDetail(selected)),
                              ],
                            ),
                          );
                        }

                        return SizedBox(
                          height: 540,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 280,
                                child: _siteRoster(sites, selected),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: _siteDetail(selected)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _siteRoster(
    List<_SiteDrillSnapshot> sites,
    _SiteDrillSnapshot selected,
  ) {
    return Container(
      decoration: _workspaceSurfaceDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3C79BB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Site Roster',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.rajdhani(
                          color: const Color(0xFFDCEAFF),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${sites.length} total',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF86A2C8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF15305A)),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: sites.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final site = sites[index];
                final isSelected = site.siteKey == selected.siteKey;
                final statusColor = _statusColor(site.healthStatus);

                return InkWell(
                  onTap: () => setState(() => _selectedIndex = index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: _rowSurfaceDecoration(isSelected: isSelected),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          site.siteId,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFE7F0FF),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${site.clientId} / ${site.regionId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF93AACE),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _tinyPill(
                              'Health ${site.healthScore.toStringAsFixed(1)}',
                              statusColor,
                            ),
                            _tinyPill(
                              'Active ${site.activeDispatches}',
                              const Color(0xFF4EB8FF),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _siteDetail(_SiteDrillSnapshot site) {
    final statusColor = _statusColor(site.healthStatus);
    return Container(
      decoration: _workspaceSurfaceDecoration(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFF3C79BB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${site.clientId} / ${site.regionId} / ${site.siteId}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE7F0FF),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: statusColor.withValues(alpha: 0.15),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Text(
                    '${site.healthStatus} • ${site.healthScore.toStringAsFixed(1)}',
                    style: GoogleFonts.rajdhani(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
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
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _panel(
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
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _panel(
                    'Operational Pulse',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _textLine(
                          'Guards Engaged',
                          site.guardsEngaged.toString(),
                        ),
                        _textLine(
                          'Avg Patrol Duration',
                          '${site.averagePatrolMinutes.toStringAsFixed(1)} min',
                        ),
                        _textLine(
                          'Last Event UTC',
                          _formatUtc(site.lastEventAtUtc),
                        ),
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _panel(
              'Recent Site Event Trace',
              site.recentEvents.isEmpty
                  ? Text(
                      'No event trace available.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8EA4C2),
                        fontSize: 13,
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      primary: false,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: site.recentEvents.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final row = site.recentEvents[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 5),
                              child: Icon(
                                Icons.circle,
                                size: 7,
                                color: Color(0xFF4AAAFF),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                row,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFD2E2FA),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            if (site.traceEventCount > site.recentEvents.length)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Showing ${site.recentEvents.length} of ${site.traceEventCount} site events.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8EA4C2),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _ratioBar(String label, int value, int total, Color color) {
    final ratio = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: const Color(0xFF9FB5D4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$value/$total',
                style: GoogleFonts.inter(
                  color: const Color(0xFFD4E3F8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: ratio,
              backgroundColor: const Color(0xFF122441),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: const Color(0xFFD7E5F8),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel(String title, Widget child, {bool expandChild = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _panelSurfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF3C79BB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE4EEFF),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, Color accent) {
    return Container(
      width: 164,
      padding: const EdgeInsets.all(9),
      decoration: _panelSurfaceDecoration(radius: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 3,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              color: accent,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tinyPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  BoxDecoration _workspaceSurfaceDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0C1A2D), Color(0xFF0B1C33)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF1A3A60)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 10,
          offset: Offset(0, 5),
        ),
      ],
    );
  }

  BoxDecoration _rowSurfaceDecoration({required bool isSelected}) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: isSelected
            ? const [Color(0xFF10284B), Color(0xFF0E2341)]
            : const [Color(0xFF0C1C31), Color(0xFF0A172B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isSelected ? const Color(0xFF4E95FF) : const Color(0xFF24466F),
      ),
      boxShadow: isSelected
          ? const [
              BoxShadow(
                color: Color(0x16000000),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ]
          : null,
    );
  }

  BoxDecoration _panelSurfaceDecoration({double radius = 12}) {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0D1B31), Color(0xFF0B182C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFF203F66)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
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
        return const Color(0xFF40C6FF);
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
            ? 'EXECUTED'
            : 'FAILED';
        if (event.success) {
          acc.executed += 1;
          acc.recentTrace.add(
            _trace(event.occurredAt, 'EXECUTED ${event.dispatchId}'),
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
