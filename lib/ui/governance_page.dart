import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/dispatch_snapshot_file_service.dart';
import '../application/email_bridge_service.dart';
import '../application/morning_sovereign_report_service.dart';
import '../application/text_share_service.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_denied.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';

enum _VigilanceStatus { green, orange, red }

enum _ComplianceSeverity { critical, warning, info }

enum GovernanceSceneActionFocus { latestAction, recentActions, filteredPattern }

class _GuardVigilance {
  final String callsign;
  final int checkInScheduleMinutes;
  final DateTime lastCheckIn;
  final List<int> sparklineData;

  const _GuardVigilance({
    required this.callsign,
    required this.checkInScheduleMinutes,
    required this.lastCheckIn,
    required this.sparklineData,
  });
}

class _ComplianceIssue {
  final String type;
  final String employeeName;
  final String employeeId;
  final DateTime expiryDate;
  final int daysRemaining;
  final bool blockingDispatch;

  const _ComplianceIssue({
    required this.type,
    required this.employeeName,
    required this.employeeId,
    required this.expiryDate,
    required this.daysRemaining,
    required this.blockingDispatch,
  });
}

class _FleetStatus {
  final int vehiclesReady;
  final int vehiclesMaintenance;
  final int vehiclesCritical;
  final int officersAvailable;
  final int officersDispatched;
  final int officersOffDuty;
  final int officersSuspended;

  const _FleetStatus({
    required this.vehiclesReady,
    required this.vehiclesMaintenance,
    required this.vehiclesCritical,
    required this.officersAvailable,
    required this.officersDispatched,
    required this.officersOffDuty,
    required this.officersSuspended,
  });
}

class _GovernanceReportView {
  final String reportDate;
  final int totalEvents;
  final bool hashVerified;
  final int integrityScore;
  final int aiDecisions;
  final int humanOverrides;
  final Map<String, int> overrideReasons;
  final int sitesMonitored;
  final int driftDetected;
  final int avgMatchScore;
  final int psiraExpired;
  final int pdpExpired;
  final int totalBlocked;
  final int sceneReviews;
  final int modelSceneReviews;
  final int metadataSceneReviews;
  final int sceneSuppressedActions;
  final int sceneIncidentAlerts;
  final int sceneRepeatUpdates;
  final int sceneEscalations;
  final String topScenePosture;
  final String sceneActionMixSummary;
  final int vehicleVisits;
  final int vehicleCompletedVisits;
  final int vehicleActiveVisits;
  final int vehicleIncompleteVisits;
  final int vehicleUniqueVehicles;
  final int vehicleUnknownEvents;
  final String vehiclePeakHourLabel;
  final int vehiclePeakHourVisitCount;
  final String vehicleSummary;
  final List<SovereignReportVehicleScopeBreakdown> vehicleScopeBreakdowns;
  final List<SovereignReportVehicleVisitException> vehicleExceptionVisits;
  final String latestActionTaken;
  final String recentActionsSummary;
  final String latestSuppressedPattern;
  final String overrideReasonSummary;
  final DateTime? generatedAtUtc;
  final DateTime? shiftWindowStartUtc;
  final DateTime? shiftWindowEndUtc;
  final bool fromCanonicalReport;

  const _GovernanceReportView({
    required this.reportDate,
    required this.totalEvents,
    required this.hashVerified,
    required this.integrityScore,
    required this.aiDecisions,
    required this.humanOverrides,
    required this.overrideReasons,
    required this.sitesMonitored,
    required this.driftDetected,
    required this.avgMatchScore,
    required this.psiraExpired,
    required this.pdpExpired,
    required this.totalBlocked,
    required this.sceneReviews,
    required this.modelSceneReviews,
    required this.metadataSceneReviews,
    required this.sceneSuppressedActions,
    required this.sceneIncidentAlerts,
    required this.sceneRepeatUpdates,
    required this.sceneEscalations,
    required this.topScenePosture,
    required this.sceneActionMixSummary,
    required this.vehicleVisits,
    required this.vehicleCompletedVisits,
    required this.vehicleActiveVisits,
    required this.vehicleIncompleteVisits,
    required this.vehicleUniqueVehicles,
    required this.vehicleUnknownEvents,
    required this.vehiclePeakHourLabel,
    required this.vehiclePeakHourVisitCount,
    required this.vehicleSummary,
    required this.vehicleScopeBreakdowns,
    required this.vehicleExceptionVisits,
    required this.latestActionTaken,
    required this.recentActionsSummary,
    required this.latestSuppressedPattern,
    required this.overrideReasonSummary,
    required this.generatedAtUtc,
    required this.shiftWindowStartUtc,
    required this.shiftWindowEndUtc,
    required this.fromCanonicalReport,
  });
}

class GovernancePage extends StatefulWidget {
  final List<DispatchEvent> events;
  final SovereignReport? morningSovereignReport;
  final String? morningSovereignReportAutoRunKey;
  final Future<void> Function()? onGenerateMorningSovereignReport;
  final ValueChanged<String>? onOpenVehicleExceptionEvent;
  final GovernanceSceneActionFocus? initialSceneActionFocus;
  final ValueChanged<GovernanceSceneActionFocus?>? onSceneActionFocusChanged;

  const GovernancePage({
    super.key,
    required this.events,
    this.morningSovereignReport,
    this.morningSovereignReportAutoRunKey,
    this.onGenerateMorningSovereignReport,
    this.onOpenVehicleExceptionEvent,
    this.initialSceneActionFocus,
    this.onSceneActionFocusChanged,
  });

  @override
  State<GovernancePage> createState() => _GovernancePageState();
}

class _GovernancePageState extends State<GovernancePage> {
  static const _snapshotFiles = DispatchSnapshotFileService();
  static const _textShare = TextShareService();
  static const _emailBridge = EmailBridgeService();

  bool _generatingMorningReport = false;
  GovernanceSceneActionFocus? _activeSceneActionFocus;
  String? _activeVehicleExceptionEventId;

  @override
  void initState() {
    super.initState();
    _activeSceneActionFocus = _validatedIncomingSceneActionFocus(
      widget.initialSceneActionFocus,
    );
  }

  @override
  void didUpdateWidget(covariant GovernancePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final validatedIncomingFocus = _validatedIncomingSceneActionFocus(
      widget.initialSceneActionFocus,
    );
    if (widget.initialSceneActionFocus != oldWidget.initialSceneActionFocus &&
        validatedIncomingFocus != _activeSceneActionFocus) {
      _activeSceneActionFocus = validatedIncomingFocus;
    }
    if (widget.morningSovereignReport != oldWidget.morningSovereignReport ||
        widget.events != oldWidget.events) {
      final report = _currentGovernanceReportForFocusValidation();
      final effectiveFocus = widget.initialSceneActionFocus != null
          ? _effectiveSceneActionFocus(
              report,
              candidate: widget.initialSceneActionFocus,
            )
          : _effectiveSceneActionFocus(report);
      if (effectiveFocus != _activeSceneActionFocus) {
        _activeSceneActionFocus = effectiveFocus;
        if (widget.onSceneActionFocusChanged != null &&
            effectiveFocus != widget.initialSceneActionFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            widget.onSceneActionFocusChanged!.call(effectiveFocus);
          });
        }
      }
      final activeExceptionId = _activeVehicleExceptionEventId?.trim() ?? '';
      if (activeExceptionId.isNotEmpty &&
          !report.vehicleExceptionVisits.any(
            (exception) => exception.primaryEventId.trim() == activeExceptionId,
          )) {
        _activeVehicleExceptionEventId = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final wide = allowEmbeddedPanelScroll(context);
    final vigilance = _buildVigilance(now);
    final compliance = _buildCompliance(now);
    final fleet = const _FleetStatus(
      vehiclesReady: 12,
      vehiclesMaintenance: 2,
      vehiclesCritical: 1,
      officersAvailable: 24,
      officersDispatched: 8,
      officersOffDuty: 3,
      officersSuspended: 2,
    );
    final report = _resolveReport(compliance);
    final complianceCritical = compliance
        .where(
          (issue) =>
              _severityFor(issue.daysRemaining) == _ComplianceSeverity.critical,
        )
        .length;
    final readiness = _readinessPercent(fleet: fleet, issues: compliance);

    return OnyxPageScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _topBar(
                  complianceCritical: complianceCritical,
                  readiness: readiness,
                  activeGuards: vigilance.length,
                  reportSource: report.fromCanonicalReport
                      ? 'PERSISTED'
                      : 'LIVE PROJECTION',
                ),
                const SizedBox(height: 12),
                wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _vigilanceCard(
                              vigilance: vigilance,
                              now: now,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 6,
                            child: _complianceCard(compliance: compliance),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _vigilanceCard(vigilance: vigilance, now: now),
                          const SizedBox(height: 12),
                          _complianceCard(compliance: compliance),
                        ],
                      ),
                const SizedBox(height: 12),
                _fleetCard(fleet: fleet),
                const SizedBox(height: 12),
                _morningReportCard(report: report),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generateMorningReport() async {
    final callback = widget.onGenerateMorningSovereignReport;
    if (callback == null || _generatingMorningReport) {
      return;
    }
    setState(() {
      _generatingMorningReport = true;
    });
    try {
      await callback();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Morning sovereign report generated.',
              style: GoogleFonts.inter(
                color: const Color(0xFFE7F0FF),
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: const Color(0xFF0E203A),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Morning sovereign report generation failed.',
              style: GoogleFonts.inter(
                color: const Color(0xFFFFC2C8),
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: const Color(0xFF3A0E14),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _generatingMorningReport = false;
        });
      }
    }
  }

  void _showSnack(
    String message, {
    Color background = const Color(0xFF0E203A),
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: const Color(0xFFE7F0FF),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: background,
      ),
    );
  }

  Widget _topBar({
    required int complianceCritical,
    required int readiness,
    required int activeGuards,
    required String reportSource,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'GOVERNANCE OVERVIEW',
            style: GoogleFonts.inter(
              color: const Color(0x66FFFFFF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          _topChip(
            'Compliance Status',
            complianceCritical == 0 ? 'STABLE' : 'AT RISK',
          ),
          _topChip('Critical Alerts', complianceCritical.toString()),
          _topChip('Readiness Posture', '$readiness%'),
          _topChip('Guards Monitored', activeGuards.toString()),
          _topChip('Report Source', reportSource),
        ],
      ),
    );
  }

  Widget _topChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x11000000),
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
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: const Color(0xFFE8F1FF),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vigilanceCard({
    required List<_GuardVigilance> vigilance,
    required DateTime now,
  }) {
    return _card(
      title: 'VIGILANCE MONITOR',
      subtitle: 'Guard decay tracking and escalation posture',
      child: Column(
        children: [
          for (int i = 0; i < vigilance.length; i++) ...[
            _guardRow(vigilance[i], now),
            if (i < vigilance.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
          _vigilanceSummary(vigilance, now),
        ],
      ),
    );
  }

  Widget _guardRow(_GuardVigilance guard, DateTime now) {
    final decay = _calculateDecayPercent(
      lastCheckIn: guard.lastCheckIn,
      scheduleMinutes: guard.checkInScheduleMinutes,
      now: now,
    );
    final status = _vigilanceStatus(decay);
    final color = _vigilanceColor(status);
    final actionLabel = switch (status) {
      _VigilanceStatus.green => 'NO ACTION',
      _VigilanceStatus.orange => 'NUDGE SENT',
      _VigilanceStatus.red => 'ESCALATION REQUIRED',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x14000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Guard: ${guard.callsign}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE8F1FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_minutesSince(guard.lastCheckIn, now)}m ago',
                style: GoogleFonts.inter(
                  color: const Color(0xFF8EA4C2),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _sparkline(guard.sparklineData, status)),
              const SizedBox(width: 10),
              Text(
                '$decay%',
                style: GoogleFonts.robotoMono(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Text(
                'Status: ${status.name.toUpperCase()}',
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  actionLabel,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: color.withValues(alpha: 0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sparkline(List<int> data, _VigilanceStatus status) {
    final color = _vigilanceColor(status);
    return SizedBox(
      height: 34,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data
            .map(
              (value) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Container(
                    height: value.clamp(10, 100).toDouble() * 0.24,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.9),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _vigilanceSummary(List<_GuardVigilance> guards, DateTime now) {
    final statusCounts = <_VigilanceStatus, int>{
      _VigilanceStatus.green: 0,
      _VigilanceStatus.orange: 0,
      _VigilanceStatus.red: 0,
    };
    for (final guard in guards) {
      final decay = _calculateDecayPercent(
        lastCheckIn: guard.lastCheckIn,
        scheduleMinutes: guard.checkInScheduleMinutes,
        now: now,
      );
      statusCounts[_vigilanceStatus(decay)] =
          (statusCounts[_vigilanceStatus(decay)] ?? 0) + 1;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x13000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        children: [
          _summaryTag(
            'GREEN',
            '${statusCounts[_VigilanceStatus.green] ?? 0}',
            const Color(0xFF10B981),
          ),
          _summaryTag(
            'ORANGE',
            '${statusCounts[_VigilanceStatus.orange] ?? 0}',
            const Color(0xFFF59E0B),
          ),
          _summaryTag(
            'RED',
            '${statusCounts[_VigilanceStatus.red] ?? 0}',
            const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  Widget _summaryTag(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.25,
        ),
      ),
    );
  }

  Widget _complianceCard({required List<_ComplianceIssue> compliance}) {
    return _card(
      title: 'COMPLIANCE ALERTS',
      subtitle: 'PSIRA, PDP, license, roadworthy, firearm competency',
      child: Column(
        children: [
          for (int i = 0; i < compliance.length; i++) ...[
            _complianceRow(compliance[i]),
            if (i < compliance.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _complianceRow(_ComplianceIssue issue) {
    final severity = _severityFor(issue.daysRemaining);
    final color = _severityColor(severity);
    final expiryLabel = issue.daysRemaining <= 0
        ? 'Expired ${issue.daysRemaining.abs()}d'
        : '${issue.daysRemaining}d remaining';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x14000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${issue.type} • ${issue.employeeName}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE8F1FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                expiryLabel,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${issue.employeeId} • Expires ${_dateLabel(issue.expiryDate)}',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (issue.blockingDispatch) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x22EF4444),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x55EF4444)),
              ),
              child: Text(
                'DISPATCH BLOCKED',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEF4444),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fleetCard({required _FleetStatus fleet}) {
    return _card(
      title: 'FLEET READINESS',
      subtitle: 'Vehicle and officer posture',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _fleetMetric(
                label: 'Vehicles Ready',
                value: fleet.vehiclesReady.toString(),
                color: const Color(0xFF10B981),
              ),
              _fleetMetric(
                label: 'Maintenance',
                value: fleet.vehiclesMaintenance.toString(),
                color: const Color(0xFFF59E0B),
              ),
              _fleetMetric(
                label: 'Critical',
                value: fleet.vehiclesCritical.toString(),
                color: const Color(0xFFEF4444),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _fleetMetric(
                label: 'Officers Available',
                value: fleet.officersAvailable.toString(),
                color: const Color(0xFF22D3EE),
              ),
              _fleetMetric(
                label: 'Dispatched',
                value: fleet.officersDispatched.toString(),
                color: const Color(0xFF8FD1FF),
              ),
              _fleetMetric(
                label: 'Off-Duty',
                value: fleet.officersOffDuty.toString(),
                color: const Color(0xFF8EA4C2),
              ),
              _fleetMetric(
                label: 'Suspended',
                value: fleet.officersSuspended.toString(),
                color: const Color(0xFFFFA2B2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fleetMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return SizedBox(
      width: 170,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: const Color(0x14000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x22FFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.rajdhani(
                color: color,
                fontSize: 30,
                height: 0.9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _morningReportCard({required _GovernanceReportView report}) {
    final interventionRate = report.aiDecisions == 0
        ? 0.0
        : (report.humanOverrides / report.aiDecisions) * 100;
    final autoStatus = _autoStatusLabel(
      widget.morningSovereignReportAutoRunKey,
    );
    return _card(
      title: 'MORNING SOVEREIGN REPORT (06:00)',
      subtitle: _morningReportSubtitle(report),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  autoStatus,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8EA4C2),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.onGenerateMorningSovereignReport != null)
                TextButton.icon(
                  onPressed: _generatingMorningReport
                      ? null
                      : _generateMorningReport,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF22D3EE),
                    backgroundColor: const Color(0x1A22D3EE),
                    side: const BorderSide(color: Color(0x4422D3EE)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  icon: _generatingMorningReport
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 14),
                  label: Text(
                    _generatingMorningReport ? 'Generating...' : 'Generate Now',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _morningReportActionChildren(report),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _summaryMetricChildren(report, interventionRate),
          ),
          const SizedBox(height: 8),
          Text(
            'Override Reasons: ${report.overrideReasonSummary}',
            style: GoogleFonts.inter(
              color: const Color(0xFF9CB2D1),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (report.generatedAtUtc != null &&
              report.shiftWindowStartUtc != null &&
              report.shiftWindowEndUtc != null) ...[
            const SizedBox(height: 4),
            Text(
              'Generated ${_timestampLabel(report.generatedAtUtc!)} • Window ${_timestampLabel(report.shiftWindowStartUtc!)} to ${_timestampLabel(report.shiftWindowEndUtc!)}',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (report.sceneActionMixSummary.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Action mix: ${report.sceneActionMixSummary}',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (report.vehicleScopeBreakdowns.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Vehicle site ledger',
              style: GoogleFonts.inter(
                color: const Color(0xFFEAF4FF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final scope in report.vehicleScopeBreakdowns)
                  _vehicleScopeCard(scope),
              ],
            ),
          ],
          if (report.vehicleExceptionVisits.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Vehicle exception review',
              style: GoogleFonts.inter(
                color: const Color(0xFFEAF4FF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            for (final exception in report.vehicleExceptionVisits) ...[
              _vehicleExceptionRow(exception),
              const SizedBox(height: 6),
            ],
          ] else if (report.vehicleVisits > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Vehicle exception review: no flagged visits in the last shift window.',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_hasSceneActionFocusOptions(report)) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sceneActionFocusChipChildren(report),
            ),
          ],
          if (_activeSceneActionFocus != null &&
              _focusedSceneActionLabel(report) != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x1422D3EE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x4422D3EE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Focused scene action: ${_focusedSceneActionLabel(report)!}',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFEAF4FF),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_focusedSceneActionDetailValue(report) != null) ...[
                          const SizedBox(height: 3),
                          InkWell(
                            key: const ValueKey(
                              'governance-focused-scene-detail-copy',
                            ),
                            onTap: () async {
                              final text = _focusedSceneActionClipboardText(
                                report,
                              );
                              if (text == null) {
                                return;
                              }
                              await Clipboard.setData(
                                ClipboardData(text: text),
                              );
                              _showSnack(
                                '${_focusedSceneActionLabel(report)!} detail copied',
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                _focusedSceneActionDetailValue(report)!,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF9FD8E8),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _setActiveSceneActionFocus(null);
                    },
                    child: Text(
                      'Clear',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF67E8F9),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          ..._sceneActionDetailChildren(report),
        ],
      ),
    );
  }

  bool _hasSceneActionFocusOptions(_GovernanceReportView report) {
    return report.latestActionTaken.trim().isNotEmpty ||
        report.recentActionsSummary.trim().isNotEmpty ||
        report.latestSuppressedPattern.trim().isNotEmpty;
  }

  String _sceneReviewMetricDetail(_GovernanceReportView report) {
    final focusedDetail = _focusedSceneActionMetricDetail(report);
    if (focusedDetail != null) {
      return focusedDetail;
    }
    return 'Model ${report.modelSceneReviews} • Alerts ${report.sceneIncidentAlerts} • Repeat ${report.sceneRepeatUpdates} • Escalations ${report.sceneEscalations} • Top ${report.topScenePosture}';
  }

  String? _focusedSceneActionMetricDetail(_GovernanceReportView report) {
    switch (_activeSceneActionFocus) {
      case GovernanceSceneActionFocus.latestAction:
        final value = report.latestActionTaken.trim();
        return value.isEmpty ? null : 'Focused latest action • $value';
      case GovernanceSceneActionFocus.recentActions:
        final value = report.recentActionsSummary.trim();
        return value.isEmpty ? null : 'Focused recent actions • $value';
      case GovernanceSceneActionFocus.filteredPattern:
        final value = report.latestSuppressedPattern.trim();
        return value.isEmpty ? null : 'Focused filtered pattern • $value';
      case null:
        return null;
    }
  }

  String _copyMorningJsonActionLabel(_GovernanceReportView report) {
    final focusLabel = _focusedSceneActionActionLabel(report);
    return focusLabel == null
        ? 'Copy Morning JSON'
        : 'Copy Morning JSON ($focusLabel)';
  }

  String _copyMorningCsvActionLabel(_GovernanceReportView report) {
    final focusLabel = _focusedSceneActionActionLabel(report);
    return focusLabel == null
        ? 'Copy Morning CSV'
        : 'Copy Morning CSV ($focusLabel)';
  }

  String _downloadMorningJsonActionLabel(_GovernanceReportView report) {
    final focusLabel = _focusedSceneActionActionLabel(report);
    return focusLabel == null
        ? 'Download Morning JSON'
        : 'Download Morning JSON ($focusLabel)';
  }

  String _downloadMorningCsvActionLabel(_GovernanceReportView report) {
    final focusLabel = _focusedSceneActionActionLabel(report);
    return focusLabel == null
        ? 'Download Morning CSV'
        : 'Download Morning CSV ($focusLabel)';
  }

  String _shareMorningPackActionLabel(_GovernanceReportView report) {
    final focusLabel = _focusedSceneActionActionLabel(report);
    return focusLabel == null
        ? 'Share Morning Pack'
        : 'Share Morning Pack ($focusLabel)';
  }

  String _emailMorningReportActionLabel(_GovernanceReportView report) {
    final focusLabel = _focusedSceneActionActionLabel(report);
    return focusLabel == null
        ? 'Email Morning Report'
        : 'Email Morning Report ($focusLabel)';
  }

  String _morningJsonFilename(_GovernanceReportView report) {
    final suffix = _focusedSceneActionFilenameSuffix(report);
    return suffix == null
        ? 'morning-sovereign-report.json'
        : 'morning-sovereign-report-$suffix-focus.json';
  }

  String _morningCsvFilename(_GovernanceReportView report) {
    final suffix = _focusedSceneActionFilenameSuffix(report);
    return suffix == null
        ? 'morning-sovereign-report.csv'
        : 'morning-sovereign-report-$suffix-focus.csv';
  }

  String _morningShareTitle(_GovernanceReportView report) {
    final focusLabel = _focusedSceneActionActionLabel(report);
    return focusLabel == null
        ? 'ONYX Morning Sovereign Report'
        : 'ONYX Morning Sovereign Report ($focusLabel)';
  }

  String _morningEmailSubject(_GovernanceReportView report) {
    final focusLabel = _focusedSceneActionActionLabel(report);
    return focusLabel == null
        ? 'ONYX Morning Sovereign Report'
        : 'ONYX Morning Sovereign Report ($focusLabel)';
  }

  String? _focusedSceneActionActionLabel(_GovernanceReportView report) {
    switch (_activeSceneActionFocus) {
      case GovernanceSceneActionFocus.latestAction:
        return report.latestActionTaken.trim().isEmpty ? null : 'Latest Action';
      case GovernanceSceneActionFocus.recentActions:
        return report.recentActionsSummary.trim().isEmpty
            ? null
            : 'Recent Actions';
      case GovernanceSceneActionFocus.filteredPattern:
        return report.latestSuppressedPattern.trim().isEmpty
            ? null
            : 'Filtered Pattern';
      case null:
        return null;
    }
  }

  String? _focusedSceneActionFilenameSuffix(_GovernanceReportView report) {
    switch (_activeSceneActionFocus) {
      case GovernanceSceneActionFocus.latestAction:
        return report.latestActionTaken.trim().isEmpty ? null : 'latest-action';
      case GovernanceSceneActionFocus.recentActions:
        return report.recentActionsSummary.trim().isEmpty
            ? null
            : 'recent-actions';
      case GovernanceSceneActionFocus.filteredPattern:
        return report.latestSuppressedPattern.trim().isEmpty
            ? null
            : 'filtered-pattern';
      case null:
        return null;
    }
  }

  String? _focusedSceneActionClipboardText(_GovernanceReportView report) {
    final label = _focusedSceneActionLabel(report);
    final detail = _focusedSceneActionDetailValue(report);
    if (label == null || detail == null) {
      return null;
    }
    return '$label: $detail';
  }

  String? _focusedSceneActionDetailValue(_GovernanceReportView report) {
    switch (_activeSceneActionFocus) {
      case GovernanceSceneActionFocus.latestAction:
        final value = report.latestActionTaken.trim();
        return value.isEmpty ? null : value;
      case GovernanceSceneActionFocus.recentActions:
        final value = report.recentActionsSummary.trim();
        return value.isEmpty ? null : value;
      case GovernanceSceneActionFocus.filteredPattern:
        final value = report.latestSuppressedPattern.trim();
        return value.isEmpty ? null : value;
      case null:
        return null;
    }
  }

  List<Widget> _morningReportActionChildren(_GovernanceReportView report) {
    return [
      if (_focusedSceneActionClipboardText(report) != null)
        _morningReportActionButton(
          key: const ValueKey('governance-copy-focused-detail-action'),
          label: _copyFocusedDetailActionLabel(report),
          onPressed: () async {
            final text = _focusedSceneActionClipboardText(report);
            if (text == null) {
              return;
            }
            await Clipboard.setData(ClipboardData(text: text));
            _showSnack('${_focusedSceneActionLabel(report)!} detail copied');
          },
        ),
      _morningReportActionButton(
        label: _copyMorningJsonActionLabel(report),
        onPressed: () async {
          await Clipboard.setData(
            ClipboardData(text: _morningReportJson(report)),
          );
          _showSnack(_copyMorningJsonSnackLabel(report));
        },
      ),
      _morningReportActionButton(
        label: _copyMorningCsvActionLabel(report),
        onPressed: () async {
          await Clipboard.setData(
            ClipboardData(text: _morningReportCsv(report)),
          );
          _showSnack(_copyMorningCsvSnackLabel(report));
        },
      ),
      _morningReportActionButton(
        label: _downloadMorningJsonActionLabel(report),
        onPressed: () async {
          if (!_snapshotFiles.supported) {
            _showSnack('File export is only available on web');
            return;
          }
          await _snapshotFiles.downloadJsonFile(
            filename: _morningJsonFilename(report),
            contents: _morningReportJson(report),
          );
          _showSnack('Morning report JSON download started');
        },
      ),
      _morningReportActionButton(
        label: _downloadMorningCsvActionLabel(report),
        onPressed: () async {
          if (!_snapshotFiles.supported) {
            _showSnack('File export is only available on web');
            return;
          }
          await _snapshotFiles.downloadTextFile(
            filename: _morningCsvFilename(report),
            contents: _morningReportCsv(report),
          );
          _showSnack('Morning report CSV download started');
        },
      ),
      _morningReportActionButton(
        label: _shareMorningPackActionLabel(report),
        onPressed: () async {
          if (!_textShare.supported) {
            _showSnack('Share is not available in this environment');
            return;
          }
          final shared = await _textShare.shareText(
            title: _morningShareTitle(report),
            text: _morningReportJson(report),
          );
          _showSnack(
            shared
                ? 'Morning report share started'
                : 'Morning report share unavailable',
          );
        },
      ),
      _morningReportActionButton(
        label: _emailMorningReportActionLabel(report),
        onPressed: () async {
          if (!_emailBridge.supported) {
            _showSnack('Email bridge is only available on web');
            return;
          }
          final opened = await _emailBridge.openMailDraft(
            subject: _morningEmailSubject(report),
            body: _morningReportJson(report),
          );
          _showSnack(
            opened
                ? 'Email draft opened for morning report'
                : 'Email bridge unavailable',
          );
        },
      ),
    ];
  }

  String _copyFocusedDetailActionLabel(_GovernanceReportView report) {
    final focusLabel = _focusedSceneActionActionLabel(report);
    return focusLabel == null
        ? 'Copy Focused Detail'
        : 'Copy $focusLabel Detail';
  }

  String _morningReportSubtitle(_GovernanceReportView report) {
    const base = 'Forensic replay of combat window (22:00-06:00)';
    final focusLabel = _focusedSceneActionActionLabel(report);
    return focusLabel == null ? base : '$base • Focused $focusLabel';
  }

  Widget _morningReportActionButton({
    Key? key,
    required String label,
    required Future<void> Function() onPressed,
  }) {
    return TextButton(
      key: key,
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(0xFFF5C27A),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _copyMorningJsonSnackLabel(_GovernanceReportView report) {
    final focusLabel = _focusedSceneActionLabel(report);
    return focusLabel == null
        ? 'Morning report JSON copied'
        : 'Morning report JSON copied with $focusLabel focus';
  }

  String _copyMorningCsvSnackLabel(_GovernanceReportView report) {
    final focusLabel = _focusedSceneActionLabel(report);
    return focusLabel == null
        ? 'Morning report CSV copied'
        : 'Morning report CSV copied with $focusLabel focus';
  }

  GovernanceSceneActionFocus? _effectiveSceneActionFocus(
    _GovernanceReportView report, {
    GovernanceSceneActionFocus? candidate,
  }) {
    final focus = candidate ?? _activeSceneActionFocus;
    switch (focus) {
      case GovernanceSceneActionFocus.latestAction:
        return report.latestActionTaken.trim().isEmpty ? null : focus;
      case GovernanceSceneActionFocus.recentActions:
        return report.recentActionsSummary.trim().isEmpty ? null : focus;
      case GovernanceSceneActionFocus.filteredPattern:
        return report.latestSuppressedPattern.trim().isEmpty ? null : focus;
      case null:
        return null;
    }
  }

  GovernanceSceneActionFocus? _validatedIncomingSceneActionFocus(
    GovernanceSceneActionFocus? candidate,
  ) {
    if (candidate == null) {
      return null;
    }
    final report = _currentGovernanceReportForFocusValidation();
    return _effectiveSceneActionFocus(report, candidate: candidate);
  }

  _GovernanceReportView _currentGovernanceReportForFocusValidation() {
    return _resolveReport(_buildCompliance(DateTime.now()));
  }

  void _setActiveSceneActionFocus(GovernanceSceneActionFocus? value) {
    if (_activeSceneActionFocus == value) {
      return;
    }
    setState(() {
      _activeSceneActionFocus = value;
    });
    widget.onSceneActionFocusChanged?.call(value);
  }

  List<Widget> _summaryMetricChildren(
    _GovernanceReportView report,
    double interventionRate,
  ) {
    final sceneReviewMetric = _reportMetric(
      key: const ValueKey('governance-metric-scene-review'),
      label: 'Scene Review',
      value: '${report.sceneReviews} reviews',
      detail: _sceneReviewMetricDetail(report),
      color: report.sceneEscalations > 0
          ? const Color(0xFFF59E0B)
          : const Color(0xFF22D3EE),
    );
    final remainingMetrics = <Widget>[
      _reportMetric(
        key: const ValueKey('governance-metric-ledger-integrity'),
        label: 'Ledger Integrity',
        value: report.hashVerified ? 'VERIFIED' : 'COMPROMISED',
        detail:
            '${report.totalEvents} events • ${report.integrityScore}% score',
        color: report.hashVerified
            ? const Color(0xFF10B981)
            : const Color(0xFFEF4444),
      ),
      _reportMetric(
        key: const ValueKey('governance-metric-ai-human-delta'),
        label: 'AI/Human Delta',
        value: '${report.humanOverrides} overrides',
        detail:
            '${interventionRate.toStringAsFixed(1)}% intervention • AI ${report.aiDecisions}',
        color: const Color(0xFF22D3EE),
      ),
      _reportMetric(
        key: const ValueKey('governance-metric-norm-drift'),
        label: 'Norm Drift',
        value: '${report.driftDetected} sites',
        detail:
            'Avg match ${report.avgMatchScore}% of ${report.sitesMonitored}',
        color: report.avgMatchScore < 80
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981),
      ),
      _reportMetric(
        key: const ValueKey('governance-metric-compliance-blockage'),
        label: 'Compliance Blockage',
        value: '${report.totalBlocked} blocked',
        detail: 'PSIRA ${report.psiraExpired} • PDP ${report.pdpExpired}',
        color: report.totalBlocked > 0
            ? const Color(0xFFEF4444)
            : const Color(0xFF10B981),
      ),
      _reportMetric(
        key: const ValueKey('governance-metric-vehicle-throughput'),
        label: 'Vehicle Throughput',
        value: '${report.vehicleVisits} visits',
        detail: report.vehicleSummary.trim().isNotEmpty
            ? report.vehicleSummary
            : 'Completed ${report.vehicleCompletedVisits} • Active ${report.vehicleActiveVisits} • Incomplete ${report.vehicleIncompleteVisits}',
        color: report.vehicleUnknownEvents > 0
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981),
      ),
    ];
    if (_effectiveSceneActionFocus(report) != null) {
      return [sceneReviewMetric, ...remainingMetrics];
    }
    return [...remainingMetrics, sceneReviewMetric];
  }

  String? _focusedSceneActionLabel(_GovernanceReportView report) {
    switch (_activeSceneActionFocus) {
      case GovernanceSceneActionFocus.latestAction:
        return report.latestActionTaken.trim().isEmpty ? null : 'Latest action';
      case GovernanceSceneActionFocus.recentActions:
        return report.recentActionsSummary.trim().isEmpty
            ? null
            : 'Recent actions';
      case GovernanceSceneActionFocus.filteredPattern:
        return report.latestSuppressedPattern.trim().isEmpty
            ? null
            : 'Filtered pattern';
      case null:
        return null;
    }
  }

  List<Widget> _sceneActionFocusChipChildren(_GovernanceReportView report) {
    final entries = <_SceneActionFocusChipEntry>[
      if (report.latestActionTaken.trim().isNotEmpty)
        const _SceneActionFocusChipEntry(
          key: ValueKey('governance-scene-focus-latest-action'),
          label: 'Latest Action',
          focus: GovernanceSceneActionFocus.latestAction,
          color: Color(0xFF67E8F9),
        ),
      if (report.recentActionsSummary.trim().isNotEmpty)
        const _SceneActionFocusChipEntry(
          key: ValueKey('governance-scene-focus-recent-actions'),
          label: 'Recent Actions',
          focus: GovernanceSceneActionFocus.recentActions,
          color: Color(0xFFFDE68A),
        ),
      if (report.latestSuppressedPattern.trim().isNotEmpty)
        const _SceneActionFocusChipEntry(
          key: ValueKey('governance-scene-focus-filtered-pattern'),
          label: 'Filtered Pattern',
          focus: GovernanceSceneActionFocus.filteredPattern,
          color: Color(0xFF9CB2D1),
        ),
    ];
    final activeFocus = _activeSceneActionFocus;
    if (activeFocus != null) {
      entries.sort((left, right) {
        final leftPriority = left.focus == activeFocus ? 0 : 1;
        final rightPriority = right.focus == activeFocus ? 0 : 1;
        return leftPriority.compareTo(rightPriority);
      });
    }
    return [
      for (final entry in entries)
        _sceneActionFocusChip(
          key: entry.key,
          label: entry.label,
          focus: entry.focus,
          color: entry.color,
        ),
    ];
  }

  Widget _sceneActionFocusChip({
    required Key key,
    required String label,
    required GovernanceSceneActionFocus focus,
    required Color color,
  }) {
    final isActive = _activeSceneActionFocus == focus;
    return InkWell(
      key: key,
      onTap: () {
        _setActiveSceneActionFocus(isActive ? null : focus);
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.16)
              : const Color(0x14000000),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.55),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _sceneActionDetail({
    required String label,
    required String value,
    required GovernanceSceneActionFocus focus,
  }) {
    final isActive = _activeSceneActionFocus == focus;
    final decoration = isActive
        ? BoxDecoration(
            color: const Color(0x1422D3EE),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x4422D3EE)),
          )
        : null;
    return InkWell(
      key: ValueKey<String>('governance-scene-detail-row-${focus.name}'),
      onTap: () {
        _setActiveSceneActionFocus(isActive ? null : focus);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        key: isActive
            ? ValueKey<String>('governance-scene-detail-${focus.name}')
            : null,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: decoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label: $value',
              style: GoogleFonts.inter(
                color: isActive
                    ? const Color(0xFFEAF4FF)
                    : const Color(0xFF8EA4C2),
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                isActive ? 'Tap to clear' : 'Tap to focus',
                style: GoogleFonts.inter(
                  color: isActive
                      ? const Color(0xFF67E8F9)
                      : const Color(0xFF6F86A6),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _sceneActionDetailChildren(_GovernanceReportView report) {
    final details = <_SceneActionDetailEntry>[
      if (report.latestActionTaken.trim().isNotEmpty)
        _SceneActionDetailEntry(
          label: 'Latest action taken',
          value: report.latestActionTaken,
          focus: GovernanceSceneActionFocus.latestAction,
        ),
      if (report.recentActionsSummary.trim().isNotEmpty)
        _SceneActionDetailEntry(
          label: 'Recent actions',
          value: report.recentActionsSummary,
          focus: GovernanceSceneActionFocus.recentActions,
        ),
      if (report.latestSuppressedPattern.trim().isNotEmpty)
        _SceneActionDetailEntry(
          label: 'Latest filtered pattern',
          value: report.latestSuppressedPattern,
          focus: GovernanceSceneActionFocus.filteredPattern,
        ),
    ];
    final activeFocus = _activeSceneActionFocus;
    if (activeFocus != null) {
      details.sort((left, right) {
        final leftPriority = left.focus == activeFocus ? 0 : 1;
        final rightPriority = right.focus == activeFocus ? 0 : 1;
        return leftPriority.compareTo(rightPriority);
      });
    }
    return [
      for (final detail in details) ...[
        const SizedBox(height: 4),
        _sceneActionDetail(
          label: detail.label,
          value: detail.value,
          focus: detail.focus,
        ),
      ],
    ];
  }

  Widget _reportMetric({
    Key? key,
    required String label,
    required String value,
    required String detail,
    required Color color,
  }) {
    return SizedBox(
      key: key,
      width: 255,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0x14000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x22FFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              style: GoogleFonts.inter(
                color: const Color(0xFF9CB2D1),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vehicleScopeCard(SovereignReportVehicleScopeBreakdown scope) {
    final scopeLabel = _vehicleScopeLabel(scope);
    return SizedBox(
      width: 280,
      child: Container(
        key: ValueKey<String>('governance-vehicle-scope-$scopeLabel'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0x14000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x22FFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              scopeLabel,
              style: GoogleFonts.inter(
                color: const Color(0xFFEAF4FF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              scope.summaryLine,
              style: GoogleFonts.inter(
                color: const Color(0xFF9CB2D1),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vehicleExceptionRow(SovereignReportVehicleVisitException exception) {
    final scopeLabel = '${exception.clientId}/${exception.siteId}';
    final zones = exception.zoneLabels.isEmpty
        ? 'no zones captured'
        : exception.zoneLabels.join(' -> ');
    final exceptionEventId = exception.primaryEventId.trim();
    final isActive =
        exceptionEventId.isNotEmpty &&
        _activeVehicleExceptionEventId == exceptionEventId;
    final canOpenEvent =
        widget.onOpenVehicleExceptionEvent != null &&
        exceptionEventId.isNotEmpty;
    return InkWell(
      key: ValueKey<String>(
        'governance-vehicle-exception-${exception.vehicleLabel}-${exception.siteId}',
      ),
      onTap: () {
        setState(() {
          _activeVehicleExceptionEventId = isActive ? null : exceptionEventId;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0x1822D3EE) : const Color(0x14151F2F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? const Color(0x5522D3EE) : const Color(0x335C728F),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${exception.reasonLabel} • ${exception.vehicleLabel}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF4FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  exception.statusLabel,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFDE68A),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$scopeLabel • dwell ${exception.dwellMinutes.toStringAsFixed(1)}m • last seen ${_timestampLabel(exception.lastSeenAtUtc)}',
              style: GoogleFonts.inter(
                color: const Color(0xFF9CB2D1),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Zones: $zones',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  isActive ? 'Tap to collapse' : 'Tap for visit detail',
                  style: GoogleFonts.inter(
                    color: isActive
                        ? const Color(0xFF67E8F9)
                        : const Color(0xFF6F86A6),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (canOpenEvent)
                  TextButton(
                    key: ValueKey<String>(
                      'governance-vehicle-exception-open-$exceptionEventId',
                    ),
                    onPressed: () => widget.onOpenVehicleExceptionEvent!.call(
                      exceptionEventId,
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF67E8F9),
                      minimumSize: const Size(0, 0),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Open Events Review',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF67E8F9),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x14151F2F),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x335C728F)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visit timeline',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _vehicleExceptionDetailLine(
                      'Started',
                      _timestampLabel(exception.startedAtUtc),
                    ),
                    _vehicleExceptionDetailLine(
                      'Last seen',
                      _timestampLabel(exception.lastSeenAtUtc),
                    ),
                    _vehicleExceptionDetailLine(
                      'Linked events',
                      exception.eventIds.isEmpty
                          ? 'none'
                          : exception.eventIds.join(', '),
                    ),
                    _vehicleExceptionDetailLine(
                      'Linked intel',
                      exception.intelligenceIds.isEmpty
                          ? 'none'
                          : exception.intelligenceIds.join(', '),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _vehicleExceptionDetailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: const Color(0xFF9CB2D1),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _vehicleScopeLabel(SovereignReportVehicleScopeBreakdown scope) {
    return '${scope.clientId}/${scope.siteId}';
  }

  String _vehicleScopeCsvSummary(SovereignReportVehicleScopeBreakdown scope) {
    return '${_vehicleScopeLabel(scope)} • ${scope.summaryLine}';
  }

  String _vehicleExceptionCsvSummary(
    SovereignReportVehicleVisitException exception,
  ) {
    final zones = exception.zoneLabels.isEmpty
        ? 'no zones captured'
        : exception.zoneLabels.join(' -> ');
    return '${exception.reasonLabel} • ${exception.statusLabel} • ${exception.vehicleLabel} • ${exception.clientId}/${exception.siteId} • dwell ${exception.dwellMinutes.toStringAsFixed(1)}m • zones $zones';
  }

  Widget _card({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0x66FFFFFF),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  List<_GuardVigilance> _buildVigilance(DateTime now) {
    return [
      _GuardVigilance(
        callsign: 'Echo-3',
        checkInScheduleMinutes: 20,
        lastCheckIn: now.subtract(const Duration(minutes: 9)),
        sparklineData: const [66, 70, 74, 69, 76, 71, 74, 79, 82, 85],
      ),
      _GuardVigilance(
        callsign: 'Bravo-2',
        checkInScheduleMinutes: 20,
        lastCheckIn: now.subtract(const Duration(minutes: 15)),
        sparklineData: const [52, 57, 60, 63, 65, 66, 70, 73, 74, 76],
      ),
      _GuardVigilance(
        callsign: 'Delta-1',
        checkInScheduleMinutes: 20,
        lastCheckIn: now.subtract(const Duration(minutes: 18)),
        sparklineData: const [44, 49, 52, 60, 66, 72, 79, 82, 89, 91],
      ),
      _GuardVigilance(
        callsign: 'Alpha-5',
        checkInScheduleMinutes: 20,
        lastCheckIn: now.subtract(const Duration(minutes: 22)),
        sparklineData: const [42, 45, 48, 54, 62, 69, 78, 86, 95, 100],
      ),
    ];
  }

  List<_ComplianceIssue> _buildCompliance(DateTime now) {
    return [
      _ComplianceIssue(
        type: 'PSIRA',
        employeeName: 'John Nkosi',
        employeeId: 'EMP-0912',
        expiryDate: now.subtract(const Duration(days: 3)),
        daysRemaining: -3,
        blockingDispatch: true,
      ),
      _ComplianceIssue(
        type: 'PDP',
        employeeName: 'Sizwe Moyo',
        employeeId: 'EMP-0417',
        expiryDate: now.add(const Duration(days: 3)),
        daysRemaining: 3,
        blockingDispatch: false,
      ),
      _ComplianceIssue(
        type: 'DRIVER_LICENSE',
        employeeName: 'Mandla Khumalo',
        employeeId: 'EMP-0288',
        expiryDate: now.add(const Duration(days: 6)),
        daysRemaining: 6,
        blockingDispatch: false,
      ),
      _ComplianceIssue(
        type: 'FIREARM',
        employeeName: 'Thato Dlamini',
        employeeId: 'EMP-1304',
        expiryDate: now,
        daysRemaining: 0,
        blockingDispatch: true,
      ),
    ];
  }

  _GovernanceReportView _resolveReport(List<_ComplianceIssue> compliance) {
    final canonical = widget.morningSovereignReport;
    if (canonical != null) {
      final reasons = canonical.aiHumanDelta.overrideReasons.entries.toList(
        growable: false,
      )..sort((a, b) => b.value.compareTo(a.value));
      final reasonSummary = reasons.isEmpty
          ? 'none'
          : reasons
                .take(3)
                .map((entry) => '${entry.key} (${entry.value})')
                .join(', ');
      return _GovernanceReportView(
        reportDate: canonical.date,
        totalEvents: canonical.ledgerIntegrity.totalEvents,
        hashVerified: canonical.ledgerIntegrity.hashVerified,
        integrityScore: canonical.ledgerIntegrity.integrityScore,
        aiDecisions: canonical.aiHumanDelta.aiDecisions,
        humanOverrides: canonical.aiHumanDelta.humanOverrides,
        overrideReasons: Map<String, int>.from(
          canonical.aiHumanDelta.overrideReasons,
        ),
        sitesMonitored: canonical.normDrift.sitesMonitored,
        driftDetected: canonical.normDrift.driftDetected,
        avgMatchScore: canonical.normDrift.avgMatchScore.round(),
        psiraExpired: canonical.complianceBlockage.psiraExpired,
        pdpExpired: canonical.complianceBlockage.pdpExpired,
        totalBlocked: canonical.complianceBlockage.totalBlocked,
        sceneReviews: canonical.sceneReview.totalReviews,
        modelSceneReviews: canonical.sceneReview.modelReviews,
        metadataSceneReviews: canonical.sceneReview.metadataFallbackReviews,
        sceneSuppressedActions: canonical.sceneReview.suppressedActions,
        sceneIncidentAlerts: canonical.sceneReview.incidentAlerts,
        sceneRepeatUpdates: canonical.sceneReview.repeatUpdates,
        sceneEscalations: canonical.sceneReview.escalationCandidates,
        topScenePosture: canonical.sceneReview.topPosture,
        sceneActionMixSummary: canonical.sceneReview.actionMixSummary,
        vehicleVisits: canonical.vehicleThroughput.totalVisits,
        vehicleCompletedVisits: canonical.vehicleThroughput.completedVisits,
        vehicleActiveVisits: canonical.vehicleThroughput.activeVisits,
        vehicleIncompleteVisits: canonical.vehicleThroughput.incompleteVisits,
        vehicleUniqueVehicles: canonical.vehicleThroughput.uniqueVehicles,
        vehicleUnknownEvents: canonical.vehicleThroughput.unknownVehicleEvents,
        vehiclePeakHourLabel: canonical.vehicleThroughput.peakHourLabel,
        vehiclePeakHourVisitCount:
            canonical.vehicleThroughput.peakHourVisitCount,
        vehicleSummary: canonical.vehicleThroughput.summaryLine,
        vehicleScopeBreakdowns: canonical.vehicleThroughput.scopeBreakdowns,
        vehicleExceptionVisits: canonical.vehicleThroughput.exceptionVisits,
        latestActionTaken: canonical.sceneReview.latestActionTaken,
        recentActionsSummary: canonical.sceneReview.recentActionsSummary,
        latestSuppressedPattern: canonical.sceneReview.latestSuppressedPattern,
        overrideReasonSummary: reasonSummary,
        generatedAtUtc: canonical.generatedAtUtc,
        shiftWindowStartUtc: canonical.shiftWindowStartUtc,
        shiftWindowEndUtc: canonical.shiftWindowEndUtc,
        fromCanonicalReport: true,
      );
    }
    return _fallbackReport(compliance);
  }

  _GovernanceReportView _fallbackReport(List<_ComplianceIssue> compliance) {
    final aiDecisions = widget.events.whereType<DecisionCreated>().length;
    final humanOverrides = widget.events.whereType<ExecutionDenied>().length;
    final overrideReasons = <String, int>{};
    for (final denied in widget.events.whereType<ExecutionDenied>()) {
      final reason = denied.reason.trim().isEmpty
          ? 'UNSPECIFIED'
          : denied.reason;
      overrideReasons[reason] = (overrideReasons[reason] ?? 0) + 1;
    }
    final reasonSummary = overrideReasons.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalBlocked = compliance
        .where((issue) => issue.blockingDispatch)
        .length;
    final psiraExpired = compliance
        .where((issue) => issue.type == 'PSIRA' && issue.daysRemaining <= 0)
        .length;
    final pdpExpired = compliance
        .where((issue) => issue.type == 'PDP' && issue.daysRemaining <= 0)
        .length;
    final integrityScore = widget.events.isEmpty
        ? 100
        : (99 - (widget.events.length % 3));
    return _GovernanceReportView(
      reportDate: _dateLabel(DateTime.now().toUtc()),
      totalEvents: widget.events.length,
      hashVerified: true,
      integrityScore: integrityScore.clamp(92, 100),
      aiDecisions: aiDecisions,
      humanOverrides: humanOverrides,
      overrideReasons: Map<String, int>.from(overrideReasons),
      sitesMonitored: 14,
      driftDetected: 2,
      avgMatchScore: 84,
      psiraExpired: psiraExpired,
      pdpExpired: pdpExpired,
      totalBlocked: totalBlocked,
      sceneReviews: 0,
      modelSceneReviews: 0,
      metadataSceneReviews: 0,
      sceneSuppressedActions: 0,
      sceneIncidentAlerts: 0,
      sceneRepeatUpdates: 0,
      sceneEscalations: 0,
      topScenePosture: 'none',
      sceneActionMixSummary: '',
      vehicleVisits: 0,
      vehicleCompletedVisits: 0,
      vehicleActiveVisits: 0,
      vehicleIncompleteVisits: 0,
      vehicleUniqueVehicles: 0,
      vehicleUnknownEvents: 0,
      vehiclePeakHourLabel: 'none',
      vehiclePeakHourVisitCount: 0,
      vehicleSummary: '',
      vehicleScopeBreakdowns: const <SovereignReportVehicleScopeBreakdown>[],
      vehicleExceptionVisits: const <SovereignReportVehicleVisitException>[],
      latestActionTaken: '',
      recentActionsSummary: '',
      latestSuppressedPattern: '',
      overrideReasonSummary: reasonSummary.isEmpty
          ? 'none'
          : reasonSummary
                .take(3)
                .map((entry) => '${entry.key} (${entry.value})')
                .join(', '),
      generatedAtUtc: null,
      shiftWindowStartUtc: null,
      shiftWindowEndUtc: null,
      fromCanonicalReport: false,
    );
  }

  String _morningReportJson(_GovernanceReportView report) {
    final focusedSceneAction = _focusedSceneActionExport(report);
    final sceneReview = <String, Object?>{
      'totalReviews': report.sceneReviews,
      'modelReviews': report.modelSceneReviews,
      'metadataFallbackReviews': report.metadataSceneReviews,
      'suppressedActions': report.sceneSuppressedActions,
      'incidentAlerts': report.sceneIncidentAlerts,
      'repeatUpdates': report.sceneRepeatUpdates,
      'escalationCandidates': report.sceneEscalations,
      'topPosture': report.topScenePosture,
      'actionMixSummary': report.sceneActionMixSummary,
      'latestActionTaken': report.latestActionTaken,
      'recentActionsSummary': report.recentActionsSummary,
      'latestSuppressedPattern': report.latestSuppressedPattern,
    };
    if (focusedSceneAction != null) {
      sceneReview['focusedLens'] = focusedSceneAction;
    }
    final payload = <String, Object?>{
      'date': report.reportDate,
      'generatedAtUtc': report.generatedAtUtc?.toIso8601String(),
      'shiftWindowStartUtc': report.shiftWindowStartUtc?.toIso8601String(),
      'shiftWindowEndUtc': report.shiftWindowEndUtc?.toIso8601String(),
      'source': report.fromCanonicalReport ? 'persisted' : 'live_projection',
      'ledgerIntegrity': {
        'totalEvents': report.totalEvents,
        'hashVerified': report.hashVerified,
        'integrityScore': report.integrityScore,
      },
      'aiHumanDelta': {
        'aiDecisions': report.aiDecisions,
        'humanOverrides': report.humanOverrides,
        'overrideReasons': report.overrideReasons,
      },
      'normDrift': {
        'sitesMonitored': report.sitesMonitored,
        'driftDetected': report.driftDetected,
        'avgMatchScore': report.avgMatchScore,
      },
      'sceneReview': sceneReview,
      'vehicleThroughput': {
        'totalVisits': report.vehicleVisits,
        'completedVisits': report.vehicleCompletedVisits,
        'activeVisits': report.vehicleActiveVisits,
        'incompleteVisits': report.vehicleIncompleteVisits,
        'uniqueVehicles': report.vehicleUniqueVehicles,
        'unknownVehicleEvents': report.vehicleUnknownEvents,
        'peakHourLabel': report.vehiclePeakHourLabel,
        'peakHourVisitCount': report.vehiclePeakHourVisitCount,
        'summaryLine': report.vehicleSummary,
        'scopeBreakdowns': report.vehicleScopeBreakdowns
            .map((scope) => scope.toJson())
            .toList(growable: false),
        'exceptionVisits': report.vehicleExceptionVisits
            .map((exception) => exception.toJson())
            .toList(growable: false),
      },
      'complianceBlockage': {
        'psiraExpired': report.psiraExpired,
        'pdpExpired': report.pdpExpired,
        'totalBlocked': report.totalBlocked,
      },
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  String _morningReportCsv(_GovernanceReportView report) {
    final focusedSceneAction = _focusedSceneActionExport(report);
    final reasons = report.overrideReasons.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    final lines = <String>[
      'metric,value',
      'report_date,${report.reportDate}',
      'generated_at_utc,${report.generatedAtUtc?.toIso8601String() ?? ''}',
      'window_start_utc,${report.shiftWindowStartUtc?.toIso8601String() ?? ''}',
      'window_end_utc,${report.shiftWindowEndUtc?.toIso8601String() ?? ''}',
      'source,${report.fromCanonicalReport ? 'persisted' : 'live_projection'}',
      'ledger_total_events,${report.totalEvents}',
      'ledger_hash_verified,${report.hashVerified}',
      'ledger_integrity_score,${report.integrityScore}',
      'ai_decisions,${report.aiDecisions}',
      'human_overrides,${report.humanOverrides}',
      'norm_sites_monitored,${report.sitesMonitored}',
      'norm_drift_detected,${report.driftDetected}',
      'norm_avg_match_score,${report.avgMatchScore}',
      'scene_total_reviews,${report.sceneReviews}',
      'scene_model_reviews,${report.modelSceneReviews}',
      'scene_metadata_fallback_reviews,${report.metadataSceneReviews}',
      'scene_suppressed_actions,${report.sceneSuppressedActions}',
      'scene_incident_alerts,${report.sceneIncidentAlerts}',
      'scene_repeat_updates,${report.sceneRepeatUpdates}',
      'scene_escalation_candidates,${report.sceneEscalations}',
      'scene_top_posture,"${report.topScenePosture.replaceAll('"', '""')}"',
      'scene_action_mix_summary,"${report.sceneActionMixSummary.replaceAll('"', '""')}"',
      'scene_latest_action_taken,"${report.latestActionTaken.replaceAll('"', '""')}"',
      'scene_recent_actions_summary,"${report.recentActionsSummary.replaceAll('"', '""')}"',
      'scene_latest_suppressed_pattern,"${report.latestSuppressedPattern.replaceAll('"', '""')}"',
      'vehicle_total_visits,${report.vehicleVisits}',
      'vehicle_completed_visits,${report.vehicleCompletedVisits}',
      'vehicle_active_visits,${report.vehicleActiveVisits}',
      'vehicle_incomplete_visits,${report.vehicleIncompleteVisits}',
      'vehicle_unique_vehicles,${report.vehicleUniqueVehicles}',
      'vehicle_unknown_events,${report.vehicleUnknownEvents}',
      'vehicle_peak_hour_label,${report.vehiclePeakHourLabel}',
      'vehicle_peak_hour_visit_count,${report.vehiclePeakHourVisitCount}',
      'vehicle_summary,"${report.vehicleSummary.replaceAll('"', '""')}"',
      for (var i = 0; i < report.vehicleScopeBreakdowns.length; i++)
        'vehicle_scope_${i + 1},"${_vehicleScopeCsvSummary(report.vehicleScopeBreakdowns[i]).replaceAll('"', '""')}"',
      for (var i = 0; i < report.vehicleExceptionVisits.length; i++)
        'vehicle_exception_${i + 1},"${_vehicleExceptionCsvSummary(report.vehicleExceptionVisits[i]).replaceAll('"', '""')}"',
      if (focusedSceneAction != null)
        'scene_focused_lens_key,${focusedSceneAction['key']}',
      if (focusedSceneAction != null)
        'scene_focused_lens_label,"${(focusedSceneAction['label'] as String).replaceAll('"', '""')}"',
      if (focusedSceneAction != null)
        'scene_focused_lens_detail,"${(focusedSceneAction['detail'] as String).replaceAll('"', '""')}"',
      'compliance_psira_expired,${report.psiraExpired}',
      'compliance_pdp_expired,${report.pdpExpired}',
      'compliance_total_blocked,${report.totalBlocked}',
      'override_reason,count',
      ...reasons.map(
        (entry) => '"${entry.key.replaceAll('"', '""')}",${entry.value}',
      ),
    ];
    return lines.join('\n');
  }

  Map<String, String>? _focusedSceneActionExport(_GovernanceReportView report) {
    final focus = _effectiveSceneActionFocus(report);
    if (focus == null) {
      return null;
    }
    final detail = switch (focus) {
      GovernanceSceneActionFocus.latestAction =>
        report.latestActionTaken.trim(),
      GovernanceSceneActionFocus.recentActions =>
        report.recentActionsSummary.trim(),
      GovernanceSceneActionFocus.filteredPattern =>
        report.latestSuppressedPattern.trim(),
    };
    if (detail.isEmpty) {
      return null;
    }
    final label = switch (focus) {
      GovernanceSceneActionFocus.latestAction => 'Latest action',
      GovernanceSceneActionFocus.recentActions => 'Recent actions',
      GovernanceSceneActionFocus.filteredPattern => 'Filtered pattern',
    };
    return <String, String>{
      'key': focus.name,
      'label': label,
      'detail': detail,
    };
  }

  _ComplianceSeverity _severityFor(int daysRemaining) {
    if (daysRemaining <= 0) {
      return _ComplianceSeverity.critical;
    }
    if (daysRemaining <= 7) {
      return _ComplianceSeverity.warning;
    }
    return _ComplianceSeverity.info;
  }

  Color _severityColor(_ComplianceSeverity severity) {
    return switch (severity) {
      _ComplianceSeverity.critical => const Color(0xFFEF4444),
      _ComplianceSeverity.warning => const Color(0xFFF59E0B),
      _ComplianceSeverity.info => const Color(0xFF3B82F6),
    };
  }

  _VigilanceStatus _vigilanceStatus(int decayPercent) {
    if (decayPercent <= 75) {
      return _VigilanceStatus.green;
    }
    if (decayPercent <= 90) {
      return _VigilanceStatus.orange;
    }
    return _VigilanceStatus.red;
  }

  Color _vigilanceColor(_VigilanceStatus status) {
    return switch (status) {
      _VigilanceStatus.green => const Color(0xFF10B981),
      _VigilanceStatus.orange => const Color(0xFFF59E0B),
      _VigilanceStatus.red => const Color(0xFFEF4444),
    };
  }

  int _calculateDecayPercent({
    required DateTime lastCheckIn,
    required int scheduleMinutes,
    required DateTime now,
  }) {
    final elapsedMillis = now.difference(lastCheckIn).inMilliseconds;
    final scheduleMillis = scheduleMinutes * 60 * 1000;
    if (scheduleMillis <= 0) {
      return 100;
    }
    final decay = ((elapsedMillis / scheduleMillis) * 100).round();
    return decay.clamp(0, 130);
  }

  int _minutesSince(DateTime lastCheckIn, DateTime now) {
    return now.difference(lastCheckIn).inMinutes.clamp(0, 999);
  }

  int _readinessPercent({
    required _FleetStatus fleet,
    required List<_ComplianceIssue> issues,
  }) {
    final blockers = issues.where((issue) => issue.blockingDispatch).length;
    final vehiclePenalty =
        fleet.vehiclesCritical * 6 + fleet.vehiclesMaintenance * 2;
    final officerPenalty = fleet.officersSuspended * 3;
    final compliancePenalty = blockers * 5;
    final score = 100 - vehiclePenalty - officerPenalty - compliancePenalty;
    return score.clamp(0, 100);
  }

  String _dateLabel(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _timestampLabel(DateTime value) {
    final utc = value.toUtc();
    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute UTC';
  }

  String _autoStatusLabel(String? autoRunKey) {
    final key = (autoRunKey ?? '').trim();
    if (key.isEmpty) {
      return 'Auto generation pending at 06:00 local.';
    }
    return 'Auto generated for shift ending $key. Next generation runs at 06:00 local.';
  }
}

class _SceneActionDetailEntry {
  final String label;
  final String value;
  final GovernanceSceneActionFocus focus;

  const _SceneActionDetailEntry({
    required this.label,
    required this.value,
    required this.focus,
  });
}

class _SceneActionFocusChipEntry {
  final ValueKey<String> key;
  final String label;
  final GovernanceSceneActionFocus focus;
  final Color color;

  const _SceneActionFocusChipEntry({
    required this.key,
    required this.label,
    required this.focus,
    required this.color,
  });
}
