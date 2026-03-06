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

class GuardsPage extends StatefulWidget {
  final List<DispatchEvent> events;

  const GuardsPage({super.key, required this.events});

  @override
  State<GuardsPage> createState() => _GuardsPageState();
}

class _GuardsPageState extends State<GuardsPage> {
  static const int _maxRosterRows = 12;

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final guards = _buildGuardSnapshots(widget.events);

    if (guards.isEmpty) {
      return const OnyxPageScaffold(
        child: OnyxEmptyState(
          label: 'No guard events available in current projection.',
        ),
      );
    }

    final totalCheckIns = guards.fold<int>(
      0,
      (total, guard) => total + guard.checkIns,
    );
    final averageCompliance =
        guards.fold<double>(
          0,
          (total, guard) => total + guard.complianceScore,
        ) /
        guards.length;

    if (_selectedIndex >= guards.length) {
      _selectedIndex = guards.length - 1;
    }

    final selected = guards[_selectedIndex];

    return OnyxPageScaffold(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const OnyxPageHeader(
                  title: 'Field Team Console',
                  subtitle:
                      'Guard readiness, patrol discipline, and response exposure in one operational view.',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 236,
                      child: OnyxSummaryStat(
                        label: 'Active Guards',
                        value: guards.length.toString(),
                        accent: const Color(0xFF63BDFF),
                      ),
                    ),
                    SizedBox(
                      width: 236,
                      child: OnyxSummaryStat(
                        label: 'Total Check-Ins',
                        value: totalCheckIns.toString(),
                        accent: const Color(0xFF59D79B),
                      ),
                    ),
                    SizedBox(
                      width: 236,
                      child: OnyxSummaryStat(
                        label: 'Avg Compliance',
                        value: '${averageCompliance.toStringAsFixed(0)}%',
                        accent: const Color(0xFFF6C067),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: OnyxSectionCard(
                    title: 'Guard Operations Workspace',
                    subtitle:
                        'Track personnel on the left and inspect the selected guard profile on the right.',
                    padding: const EdgeInsets.all(10),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final stackVertically = constraints.maxWidth < 1320;

                        if (stackVertically) {
                          return SizedBox(
                            height: 640,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 216,
                                  child: _guardRoster(guards, selected),
                                ),
                                const SizedBox(height: 6),
                                Expanded(child: _guardDetail(selected)),
                              ],
                            ),
                          );
                        }

                        return SizedBox(
                          height: 508,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 268,
                                child: _guardRoster(guards, selected),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: _guardDetail(selected)),
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

  Widget _guardRoster(List<_GuardSnapshot> guards, _GuardSnapshot selected) {
    final visibleGuards = guards.take(_maxRosterRows).toList(growable: false);
    final hiddenGuards = guards.length - visibleGuards.length;
    return Container(
      decoration: _workspaceSurfaceDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
                        'Guard Roster',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.rajdhani(
                          color: const Color(0xFFDCEAFF),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${guards.length} active',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: visibleGuards.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final guard = visibleGuards[index];
                      final isSelected = guard.guardId == selected.guardId;
                      final complianceColor = guard.complianceScore >= 75
                          ? const Color(0xFF4CD88E)
                          : guard.complianceScore >= 50
                          ? const Color(0xFFF6B24A)
                          : const Color(0xFFFF6A78);

                      return InkWell(
                        onTap: () => setState(() => _selectedIndex = index),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: _rowSurfaceDecoration(
                            isSelected: isSelected,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                guard.guardId,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFE7F0FF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                guard.primaryAssignment,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF93AACE),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _tinyPill(
                                    'Check-Ins ${guard.checkIns}',
                                    const Color(0xFF4CB6FF),
                                  ),
                                  _tinyPill(
                                    'Compliance ${guard.complianceScore.toStringAsFixed(0)}%',
                                    complianceColor,
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
                if (hiddenGuards > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: OnyxTruncationHint(
                      visibleCount: visibleGuards.length,
                      totalCount: guards.length,
                      subject: 'guards',
                      hiddenDescriptor: 'additional guards',
                      color: const Color(0xFF86A2C8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _guardDetail(_GuardSnapshot guard) {
    final complianceColor = guard.complianceScore >= 75
        ? const Color(0xFF4CD88E)
        : guard.complianceScore >= 50
        ? const Color(0xFFF6B24A)
        : const Color(0xFFFF6A78);

    return Container(
      decoration: _workspaceSurfaceDecoration(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Guard ${guard.guardId}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE7F0FF),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: complianceColor.withValues(alpha: 0.14),
                    border: Border.all(
                      color: complianceColor.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Text(
                    'COMPLIANCE ${guard.complianceScore.toStringAsFixed(1)}%',
                    style: GoogleFonts.rajdhani(
                      color: complianceColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Primary Assignment: ${guard.primaryAssignment}',
              style: GoogleFonts.inter(
                color: const Color(0xFF97AECF),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _metricCard(
                  'Check-Ins',
                  guard.checkIns.toString(),
                  const Color(0xFF63BDFF),
                ),
                _metricCard(
                  'Patrols',
                  guard.patrols.toString(),
                  const Color(0xFF5CD59B),
                ),
                _metricCard(
                  'Responses',
                  guard.responses.toString(),
                  const Color(0xFF66C8FF),
                ),
                _metricCard(
                  'Avg Patrol',
                  '${guard.averagePatrolMinutes.toStringAsFixed(1)} min',
                  const Color(0xFF89D4FF),
                ),
                _metricCard(
                  'Decision Exposure',
                  guard.decisionExposure.toString(),
                  const Color(0xFF95AFFF),
                ),
                _metricCard(
                  'Last Activity',
                  _shortUtc(guard.lastActivityUtc),
                  const Color(0xFF9EC5EA),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _panel(
                    'Operational Ratios',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ratioBar(
                          'Patrols vs Expected',
                          guard.patrols,
                          guard.expectedPatrols,
                          const Color(0xFF4CD88E),
                        ),
                        _ratioBar(
                          'Response Participation',
                          guard.responses,
                          guard.decisionExposure,
                          const Color(0xFF4FB5FF),
                        ),
                        _ratioBar(
                          'Check-In Coverage',
                          guard.checkIns,
                          guard.checkIns + 1,
                          const Color(0xFF97AFFF),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _panel(
                    'Assignment Footprint',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _textLine(
                          'Sites Covered',
                          guard.assignments.length.toString(),
                        ),
                        _textLine('Primary Site', guard.primaryAssignment),
                        _textLine(
                          'Active Hours',
                          guard.activeHoursCount.toString(),
                        ),
                        _textLine(
                          'Event Count',
                          guard.recentTrace.length.toString(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _panel(
              'Recent Guard Event Trace',
              guard.recentTrace.isEmpty
                  ? Text(
                      'No guard event trace available.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8EA4C2),
                        fontSize: 13,
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      primary: false,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: guard.recentTrace.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final row = guard.recentTrace[index];
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
            if (guard.traceEventCount > guard.recentTrace.length)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: OnyxTruncationHint(
                  visibleCount: guard.recentTrace.length,
                  totalCount: guard.traceEventCount,
                  subject: 'guard events',
                  hiddenDescriptor: 'older events',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _ratioBar(String label, int value, int total, Color color) {
    final safeTotal = total <= 0 ? 1 : total;
    final ratio = (value / safeTotal).clamp(0.0, 1.0);
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
                '$value/$safeTotal',
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

  String _shortUtc(DateTime dt) {
    final z = dt.toUtc().toIso8601String();
    return z.length > 16 ? '${z.substring(0, 16)}Z' : z;
  }

  List<_GuardSnapshot> _buildGuardSnapshots(List<DispatchEvent> events) {
    final guards = <String, _GuardAccumulator>{};
    final dispatchGuard = <String, String>{};

    for (final event in events) {
      if (event is GuardCheckedIn) {
        final g = guards.putIfAbsent(
          event.guardId,
          () => _GuardAccumulator(event.guardId),
        );
        g.checkIns += 1;
        g.assignments.add('${event.clientId}/${event.siteId}');
        g.activeHours.add(event.occurredAt.toUtc().hour);
        g.lastActivityUtc = g.lastActivityUtc.isAfter(event.occurredAt)
            ? g.lastActivityUtc
            : event.occurredAt;
        g.recentTrace.add(
          '${_shortUtc(event.occurredAt)} • CHECK-IN at ${event.siteId}',
        );
      } else if (event is PatrolCompleted) {
        final g = guards.putIfAbsent(
          event.guardId,
          () => _GuardAccumulator(event.guardId),
        );
        g.patrols += 1;
        g.patrolDurationSeconds += event.durationSeconds;
        g.assignments.add('${event.clientId}/${event.siteId}');
        g.activeHours.add(event.occurredAt.toUtc().hour);
        g.lastActivityUtc = g.lastActivityUtc.isAfter(event.occurredAt)
            ? g.lastActivityUtc
            : event.occurredAt;
        g.recentTrace.add(
          '${_shortUtc(event.occurredAt)} • PATROL ${event.routeId} (${event.durationSeconds}s)',
        );
      } else if (event is ResponseArrived) {
        final g = guards.putIfAbsent(
          event.guardId,
          () => _GuardAccumulator(event.guardId),
        );
        g.responses += 1;
        g.assignments.add('${event.clientId}/${event.siteId}');
        g.activeHours.add(event.occurredAt.toUtc().hour);
        g.lastActivityUtc = g.lastActivityUtc.isAfter(event.occurredAt)
            ? g.lastActivityUtc
            : event.occurredAt;
        g.recentTrace.add(
          '${_shortUtc(event.occurredAt)} • RESPONSE for ${event.dispatchId}',
        );
        dispatchGuard[event.dispatchId] = event.guardId;
      } else if (event is DecisionCreated) {
        final guardId = dispatchGuard[event.dispatchId];
        if (guardId != null) {
          guards
                  .putIfAbsent(guardId, () => _GuardAccumulator(guardId))
                  .decisionExposure +=
              1;
        }
      } else if (event is ExecutionCompleted) {
        final guardId = dispatchGuard[event.dispatchId];
        if (guardId != null) {
          final g = guards.putIfAbsent(
            guardId,
            () => _GuardAccumulator(guardId),
          );
          g.recentTrace.add(
            '${_shortUtc(event.occurredAt)} • EXECUTION ${event.success ? 'SUCCESS' : 'FAILED'} ${event.dispatchId}',
          );
        }
      } else if (event is ExecutionDenied) {
        final guardId = dispatchGuard[event.dispatchId];
        if (guardId != null) {
          final g = guards.putIfAbsent(
            guardId,
            () => _GuardAccumulator(guardId),
          );
          g.recentTrace.add(
            '${_shortUtc(event.occurredAt)} • EXECUTION DENIED ${event.dispatchId}',
          );
        }
      } else if (event is IncidentClosed) {
        final guardId = dispatchGuard[event.dispatchId];
        if (guardId != null) {
          final g = guards.putIfAbsent(
            guardId,
            () => _GuardAccumulator(guardId),
          );
          g.recentTrace.add(
            '${_shortUtc(event.occurredAt)} • INCIDENT CLOSED ${event.dispatchId}',
          );
        }
      }
    }

    final snapshots = guards.values.map((acc) {
      final expectedPatrols = acc.checkIns * 8;
      final compliance = expectedPatrols == 0
          ? 0.0
          : ((acc.patrols / expectedPatrols) * 100.0).clamp(0.0, 100.0);
      final avgPatrol = acc.patrols == 0
          ? 0.0
          : (acc.patrolDurationSeconds / acc.patrols) / 60.0;
      final assignments = acc.assignments.toList()..sort();
      final primary = assignments.isEmpty ? 'Unknown' : assignments.first;
      final traceEventCount = acc.recentTrace.length;

      return _GuardSnapshot(
        guardId: acc.guardId,
        primaryAssignment: primary,
        assignments: assignments,
        checkIns: acc.checkIns,
        patrols: acc.patrols,
        responses: acc.responses,
        decisionExposure: acc.decisionExposure,
        expectedPatrols: expectedPatrols,
        complianceScore: compliance,
        averagePatrolMinutes: avgPatrol,
        activeHoursCount: acc.activeHours.length,
        lastActivityUtc: acc.lastActivityUtc,
        traceEventCount: traceEventCount,
        recentTrace: acc.recentTrace.reversed.take(10).toList(),
      );
    }).toList();

    snapshots.sort((a, b) {
      final scoreSort = b.complianceScore.compareTo(a.complianceScore);
      if (scoreSort != 0) return scoreSort;
      return b.lastActivityUtc.compareTo(a.lastActivityUtc);
    });

    return snapshots;
  }
}

class _GuardAccumulator {
  final String guardId;
  final Set<String> assignments = {};
  final Set<int> activeHours = {};
  final List<String> recentTrace = [];

  int checkIns = 0;
  int patrols = 0;
  int responses = 0;
  int decisionExposure = 0;
  int patrolDurationSeconds = 0;
  DateTime lastActivityUtc = DateTime.fromMillisecondsSinceEpoch(
    0,
    isUtc: true,
  );

  _GuardAccumulator(this.guardId);
}

class _GuardSnapshot {
  final String guardId;
  final String primaryAssignment;
  final List<String> assignments;
  final int checkIns;
  final int patrols;
  final int responses;
  final int decisionExposure;
  final int expectedPatrols;
  final double complianceScore;
  final double averagePatrolMinutes;
  final int activeHoursCount;
  final DateTime lastActivityUtc;
  final int traceEventCount;
  final List<String> recentTrace;

  const _GuardSnapshot({
    required this.guardId,
    required this.primaryAssignment,
    required this.assignments,
    required this.checkIns,
    required this.patrols,
    required this.responses,
    required this.decisionExposure,
    required this.expectedPatrols,
    required this.complianceScore,
    required this.averagePatrolMinutes,
    required this.activeHoursCount,
    required this.lastActivityUtc,
    required this.traceEventCount,
    required this.recentTrace,
  });
}
