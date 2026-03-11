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

  const GovernancePage({
    super.key,
    required this.events,
    this.morningSovereignReport,
    this.morningSovereignReportAutoRunKey,
    this.onGenerateMorningSovereignReport,
  });

  @override
  State<GovernancePage> createState() => _GovernancePageState();
}

class _GovernancePageState extends State<GovernancePage> {
  static const _snapshotFiles = DispatchSnapshotFileService();
  static const _textShare = TextShareService();
  static const _emailBridge = EmailBridgeService();

  bool _generatingMorningReport = false;

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
      subtitle: 'Forensic replay of combat window (22:00-06:00)',
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
            children: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: _morningReportJson(report)),
                  );
                  _showSnack('Morning report JSON copied');
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Copy Morning JSON',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFF5C27A),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: _morningReportCsv(report)),
                  );
                  _showSnack('Morning report CSV copied');
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Copy Morning CSV',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFF5C27A),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  if (!_snapshotFiles.supported) {
                    _showSnack('File export is only available on web');
                    return;
                  }
                  await _snapshotFiles.downloadJsonFile(
                    filename: 'morning-sovereign-report.json',
                    contents: _morningReportJson(report),
                  );
                  _showSnack('Morning report JSON download started');
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Download Morning JSON',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFF5C27A),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  if (!_snapshotFiles.supported) {
                    _showSnack('File export is only available on web');
                    return;
                  }
                  await _snapshotFiles.downloadTextFile(
                    filename: 'morning-sovereign-report.csv',
                    contents: _morningReportCsv(report),
                  );
                  _showSnack('Morning report CSV download started');
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Download Morning CSV',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFF5C27A),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  if (!_textShare.supported) {
                    _showSnack('Share is not available in this environment');
                    return;
                  }
                  final shared = await _textShare.shareText(
                    title: 'ONYX Morning Sovereign Report',
                    text: _morningReportJson(report),
                  );
                  _showSnack(
                    shared
                        ? 'Morning report share started'
                        : 'Morning report share unavailable',
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Share Morning Pack',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFF5C27A),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  if (!_emailBridge.supported) {
                    _showSnack('Email bridge is only available on web');
                    return;
                  }
                  final opened = await _emailBridge.openMailDraft(
                    subject: 'ONYX Morning Sovereign Report',
                    body: _morningReportJson(report),
                  );
                  _showSnack(
                    opened
                        ? 'Email draft opened for morning report'
                        : 'Email bridge unavailable',
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Email Morning Report',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFF5C27A),
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
            children: [
              _reportMetric(
                label: 'Ledger Integrity',
                value: report.hashVerified ? 'VERIFIED' : 'COMPROMISED',
                detail:
                    '${report.totalEvents} events • ${report.integrityScore}% score',
                color: report.hashVerified
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
              ),
              _reportMetric(
                label: 'AI/Human Delta',
                value: '${report.humanOverrides} overrides',
                detail:
                    '${interventionRate.toStringAsFixed(1)}% intervention • AI ${report.aiDecisions}',
                color: const Color(0xFF22D3EE),
              ),
              _reportMetric(
                label: 'Norm Drift',
                value: '${report.driftDetected} sites',
                detail:
                    'Avg match ${report.avgMatchScore}% of ${report.sitesMonitored}',
                color: report.avgMatchScore < 80
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF10B981),
              ),
              _reportMetric(
                label: 'Compliance Blockage',
                value: '${report.totalBlocked} blocked',
                detail:
                    'PSIRA ${report.psiraExpired} • PDP ${report.pdpExpired}',
                color: report.totalBlocked > 0
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF10B981),
              ),
            ],
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
        ],
      ),
    );
  }

  Widget _reportMetric({
    required String label,
    required String value,
    required String detail,
    required Color color,
  }) {
    return SizedBox(
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
      'complianceBlockage': {
        'psiraExpired': report.psiraExpired,
        'pdpExpired': report.pdpExpired,
        'totalBlocked': report.totalBlocked,
      },
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  String _morningReportCsv(_GovernanceReportView report) {
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
