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
import '../domain/events/partner_dispatch_status_declared.dart';
import '../domain/events/vehicle_visit_review_recorded.dart';
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

class _VehicleExceptionReviewOverride {
  final bool reviewed;
  final DateTime reviewedAtUtc;
  final String statusOverride;

  const _VehicleExceptionReviewOverride({
    required this.reviewed,
    required this.reviewedAtUtc,
    this.statusOverride = '',
  });

  _VehicleExceptionReviewOverride copyWith({
    bool? reviewed,
    DateTime? reviewedAtUtc,
    String? statusOverride,
  }) {
    return _VehicleExceptionReviewOverride(
      reviewed: reviewed ?? this.reviewed,
      reviewedAtUtc: reviewedAtUtc ?? this.reviewedAtUtc,
      statusOverride: statusOverride ?? this.statusOverride,
    );
  }
}

class _PartnerTrendRow {
  final String clientId;
  final String siteId;
  final String partnerLabel;
  final int reportDays;
  final int dispatchCount;
  final int strongCount;
  final int onTrackCount;
  final int watchCount;
  final int criticalCount;
  final double averageAcceptedDelayMinutes;
  final double averageOnSiteDelayMinutes;
  final String currentScoreLabel;
  final String trendLabel;
  final String trendReason;
  final String summaryLine;

  const _PartnerTrendRow({
    required this.clientId,
    required this.siteId,
    required this.partnerLabel,
    required this.reportDays,
    required this.dispatchCount,
    required this.strongCount,
    required this.onTrackCount,
    required this.watchCount,
    required this.criticalCount,
    required this.averageAcceptedDelayMinutes,
    required this.averageOnSiteDelayMinutes,
    required this.currentScoreLabel,
    required this.trendLabel,
    required this.trendReason,
    required this.summaryLine,
  });

  Map<String, Object?> toJson() {
    return {
      'clientId': clientId,
      'siteId': siteId,
      'partnerLabel': partnerLabel,
      'reportDays': reportDays,
      'dispatchCount': dispatchCount,
      'strongCount': strongCount,
      'onTrackCount': onTrackCount,
      'watchCount': watchCount,
      'criticalCount': criticalCount,
      'averageAcceptedDelayMinutes': averageAcceptedDelayMinutes,
      'averageOnSiteDelayMinutes': averageOnSiteDelayMinutes,
      'currentScoreLabel': currentScoreLabel,
      'trendLabel': trendLabel,
      'trendReason': trendReason,
      'summaryLine': summaryLine,
    };
  }
}

class _PartnerTrendAggregate {
  final String clientId;
  final String siteId;
  final String partnerLabel;
  final Set<String> reportDates = <String>{};
  int dispatchCount = 0;
  int strongCount = 0;
  int onTrackCount = 0;
  int watchCount = 0;
  int criticalCount = 0;
  double acceptedDelayWeightedSum = 0;
  double acceptedDelayWeight = 0;
  double onSiteDelayWeightedSum = 0;
  double onSiteDelayWeight = 0;
  final List<double> priorSeverityScores = <double>[];
  final List<double> priorAcceptedDelayMinutes = <double>[];
  final List<double> priorOnSiteDelayMinutes = <double>[];
  SovereignReportPartnerScoreboardRow? currentRow;

  _PartnerTrendAggregate({
    required this.clientId,
    required this.siteId,
    required this.partnerLabel,
  });
}

class _PartnerScoreboardHistoryPoint {
  final String reportDate;
  final SovereignReportPartnerScoreboardRow row;
  final bool current;

  const _PartnerScoreboardHistoryPoint({
    required this.reportDate,
    required this.row,
    required this.current,
  });

  Map<String, Object?> toJson() {
    return {'reportDate': reportDate, 'current': current, 'row': row.toJson()};
  }
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
  final String vehicleWorkflowHeadline;
  final String vehicleSummary;
  final List<SovereignReportVehicleScopeBreakdown> vehicleScopeBreakdowns;
  final List<SovereignReportVehicleVisitException> vehicleExceptionVisits;
  final int partnerDispatches;
  final int partnerDeclarations;
  final int partnerAccepted;
  final int partnerOnSite;
  final int partnerAllClear;
  final int partnerCancelled;
  final String partnerWorkflowHeadline;
  final String partnerPerformanceHeadline;
  final String partnerSlaHeadline;
  final String partnerSummary;
  final List<SovereignReportPartnerScopeBreakdown> partnerScopeBreakdowns;
  final List<SovereignReportPartnerScoreboardRow> partnerScoreboardRows;
  final List<_PartnerScoreboardHistoryPoint> partnerScoreboardHistory;
  final List<_PartnerTrendRow> partnerTrendRows;
  final List<SovereignReportPartnerDispatchChain> partnerDispatchChains;
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
    required this.vehicleWorkflowHeadline,
    required this.vehicleSummary,
    required this.vehicleScopeBreakdowns,
    required this.vehicleExceptionVisits,
    required this.partnerDispatches,
    required this.partnerDeclarations,
    required this.partnerAccepted,
    required this.partnerOnSite,
    required this.partnerAllClear,
    required this.partnerCancelled,
    required this.partnerWorkflowHeadline,
    required this.partnerPerformanceHeadline,
    required this.partnerSlaHeadline,
    required this.partnerSummary,
    required this.partnerScopeBreakdowns,
    required this.partnerScoreboardRows,
    required this.partnerScoreboardHistory,
    required this.partnerTrendRows,
    required this.partnerDispatchChains,
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
  final List<SovereignReport> morningSovereignReportHistory;
  final String? morningSovereignReportAutoRunKey;
  final String? initialPartnerScopeClientId;
  final String? initialPartnerScopeSiteId;
  final String? initialPartnerScopePartnerLabel;
  final Future<void> Function()? onGenerateMorningSovereignReport;
  final ValueChanged<SovereignReport>? onMorningSovereignReportChanged;
  final ValueChanged<String>? onOpenVehicleExceptionEvent;
  final ValueChanged<SovereignReportVehicleVisitException>?
  onOpenVehicleExceptionVisit;
  final void Function(String clientId, String siteId, String partnerLabel)?
  onOpenReportsForPartnerScope;
  final GovernanceSceneActionFocus? initialSceneActionFocus;
  final ValueChanged<GovernanceSceneActionFocus?>? onSceneActionFocusChanged;

  const GovernancePage({
    super.key,
    required this.events,
    this.morningSovereignReport,
    this.morningSovereignReportHistory = const <SovereignReport>[],
    this.morningSovereignReportAutoRunKey,
    this.initialPartnerScopeClientId,
    this.initialPartnerScopeSiteId,
    this.initialPartnerScopePartnerLabel,
    this.onGenerateMorningSovereignReport,
    this.onMorningSovereignReportChanged,
    this.onOpenVehicleExceptionEvent,
    this.onOpenVehicleExceptionVisit,
    this.onOpenReportsForPartnerScope,
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
  Map<String, _VehicleExceptionReviewOverride>
  _vehicleExceptionReviewOverrides =
      const <String, _VehicleExceptionReviewOverride>{};

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
      final validExceptionKeys = report.vehicleExceptionVisits
          .map(_vehicleExceptionReviewKey)
          .toSet();
      _vehicleExceptionReviewOverrides =
          Map<String, _VehicleExceptionReviewOverride>.from(
            _vehicleExceptionReviewOverrides,
          )..removeWhere((key, _) => !validExceptionKeys.contains(key));
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
          if (_hasPartnerScopeFocus) ...[
            const SizedBox(height: 8),
            Container(
              key: const ValueKey('governance-partner-scope-banner'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x141C3C57),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x4435506F)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Partner scope focus active',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8FD1FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_partnerScopeClientId!}/${_partnerScopeSiteId!} • ${_partnerScopePartnerLabel!}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF4FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          if (report.partnerScopeBreakdowns.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Partner dispatch sites',
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
                for (final scope in report.partnerScopeBreakdowns)
                  _partnerScopeCard(scope),
              ],
            ),
          ],
          if (report.partnerScoreboardRows.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Partner scoreboard',
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
                for (final row in report.partnerScoreboardRows)
                  _partnerScoreboardCard(row),
              ],
            ),
          ],
          if (report.partnerTrendRows.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Partner trends (7 days)',
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
                for (final row in report.partnerTrendRows)
                  _partnerTrendCard(row),
              ],
            ),
          ],
          if (report.partnerDispatchChains.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Partner dispatch progression',
              style: GoogleFonts.inter(
                color: const Color(0xFFEAF4FF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            if (report.partnerPerformanceHeadline.trim().isNotEmpty) ...[
              Text(
                report.partnerPerformanceHeadline,
                style: GoogleFonts.inter(
                  color: const Color(0xFFFDE68A),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (report.partnerWorkflowHeadline.trim().isNotEmpty) ...[
              Text(
                report.partnerWorkflowHeadline,
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (report.partnerSlaHeadline.trim().isNotEmpty) ...[
              Text(
                report.partnerSlaHeadline,
                style: GoogleFonts.inter(
                  color: const Color(0xFF67E8F9),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
            ],
            for (final chain in report.partnerDispatchChains.take(6)) ...[
              _partnerDispatchChainRow(chain),
              const SizedBox(height: 6),
            ],
          ] else if (report.partnerDispatches > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Partner dispatch progression is available, but no chain details were retained in this report.',
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

  String? get _partnerScopeClientId {
    final value = widget.initialPartnerScopeClientId?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  String? get _partnerScopeSiteId {
    final value = widget.initialPartnerScopeSiteId?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  String? get _partnerScopePartnerLabel {
    final value = widget.initialPartnerScopePartnerLabel?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  bool get _hasPartnerScopeFocus =>
      _partnerScopeClientId != null &&
      _partnerScopeSiteId != null &&
      _partnerScopePartnerLabel != null;

  bool _partnerScopeMatches({
    required String clientId,
    required String siteId,
    required String partnerLabel,
  }) {
    return clientId.trim() == _partnerScopeClientId &&
        siteId.trim() == _partnerScopeSiteId &&
        partnerLabel.trim().toUpperCase() ==
            (_partnerScopePartnerLabel ?? '').toUpperCase();
  }

  bool _partnerScopeBreakdownMatches(
    SovereignReportPartnerScopeBreakdown scope,
  ) {
    return scope.clientId.trim() == _partnerScopeClientId &&
        scope.siteId.trim() == _partnerScopeSiteId;
  }

  _GovernanceReportView _applyPartnerScopeFilter(_GovernanceReportView report) {
    if (!_hasPartnerScopeFocus) {
      return report;
    }
    final filteredScopeBreakdowns = report.partnerScopeBreakdowns
        .where(_partnerScopeBreakdownMatches)
        .toList(growable: false);
    final filteredScoreboardRows = report.partnerScoreboardRows
        .where(
          (row) => _partnerScopeMatches(
            clientId: row.clientId,
            siteId: row.siteId,
            partnerLabel: row.partnerLabel,
          ),
        )
        .toList(growable: false);
    final filteredDispatchChains = report.partnerDispatchChains
        .where(
          (chain) => _partnerScopeMatches(
            clientId: chain.clientId,
            siteId: chain.siteId,
            partnerLabel: chain.partnerLabel,
          ),
        )
        .toList(growable: false);
    final filteredScoreboardHistory = _partnerScoreboardHistoryRows(
      currentReportDate: report.reportDate,
      currentRows: filteredScoreboardRows,
    );
    final filteredTrendRows = _partnerTrendRows(
      currentReportDate: report.reportDate,
      currentRows: filteredScoreboardRows,
    );
    final acceptedDelayMinutes = [
      for (final chain in filteredDispatchChains)
        if (chain.acceptedDelayMinutes != null) chain.acceptedDelayMinutes!,
    ];
    final onSiteDelayMinutes = [
      for (final chain in filteredDispatchChains)
        if (chain.onSiteDelayMinutes != null) chain.onSiteDelayMinutes!,
    ];
    final dispatchCount = filteredDispatchChains.isNotEmpty
        ? filteredDispatchChains.length
        : filteredScoreboardRows.fold<int>(
            0,
            (sum, row) => sum + row.dispatchCount,
          );
    final declarationCount = filteredDispatchChains.isNotEmpty
        ? filteredDispatchChains.fold<int>(
            0,
            (sum, chain) => sum + chain.declarationCount,
          )
        : filteredScopeBreakdowns.fold<int>(
            0,
            (sum, scope) => sum + scope.declarationCount,
          );
    final acceptedCount = filteredDispatchChains
        .where((chain) => chain.acceptedAtUtc != null)
        .length;
    final onSiteCount = filteredDispatchChains
        .where((chain) => chain.onSiteAtUtc != null)
        .length;
    final allClearCount = filteredDispatchChains
        .where((chain) => chain.allClearAtUtc != null)
        .length;
    final cancelledCount = filteredDispatchChains
        .where((chain) => chain.cancelledAtUtc != null)
        .length;
    final performanceHeadline = filteredDispatchChains.isNotEmpty
        ? _partnerPerformanceHeadline(filteredDispatchChains)
        : _partnerPerformanceHeadlineFromScoreboardRows(filteredScoreboardRows);
    final slaHeadline = filteredDispatchChains.isNotEmpty
        ? _partnerSlaHeadline(
            acceptedDelayMinutes: acceptedDelayMinutes,
            onSiteDelayMinutes: onSiteDelayMinutes,
          )
        : _partnerSlaHeadlineFromScoreboardRows(filteredScoreboardRows);
    return _GovernanceReportView(
      reportDate: report.reportDate,
      totalEvents: report.totalEvents,
      hashVerified: report.hashVerified,
      integrityScore: report.integrityScore,
      aiDecisions: report.aiDecisions,
      humanOverrides: report.humanOverrides,
      overrideReasons: report.overrideReasons,
      sitesMonitored: report.sitesMonitored,
      driftDetected: report.driftDetected,
      avgMatchScore: report.avgMatchScore,
      psiraExpired: report.psiraExpired,
      pdpExpired: report.pdpExpired,
      totalBlocked: report.totalBlocked,
      sceneReviews: report.sceneReviews,
      modelSceneReviews: report.modelSceneReviews,
      metadataSceneReviews: report.metadataSceneReviews,
      sceneSuppressedActions: report.sceneSuppressedActions,
      sceneIncidentAlerts: report.sceneIncidentAlerts,
      sceneRepeatUpdates: report.sceneRepeatUpdates,
      sceneEscalations: report.sceneEscalations,
      topScenePosture: report.topScenePosture,
      sceneActionMixSummary: report.sceneActionMixSummary,
      vehicleVisits: report.vehicleVisits,
      vehicleCompletedVisits: report.vehicleCompletedVisits,
      vehicleActiveVisits: report.vehicleActiveVisits,
      vehicleIncompleteVisits: report.vehicleIncompleteVisits,
      vehicleUniqueVehicles: report.vehicleUniqueVehicles,
      vehicleUnknownEvents: report.vehicleUnknownEvents,
      vehiclePeakHourLabel: report.vehiclePeakHourLabel,
      vehiclePeakHourVisitCount: report.vehiclePeakHourVisitCount,
      vehicleWorkflowHeadline: report.vehicleWorkflowHeadline,
      vehicleSummary: report.vehicleSummary,
      vehicleScopeBreakdowns: report.vehicleScopeBreakdowns,
      vehicleExceptionVisits: report.vehicleExceptionVisits,
      partnerDispatches: dispatchCount,
      partnerDeclarations: declarationCount,
      partnerAccepted: acceptedCount,
      partnerOnSite: onSiteCount,
      partnerAllClear: allClearCount,
      partnerCancelled: cancelledCount,
      partnerWorkflowHeadline: filteredDispatchChains.isEmpty
          ? ''
          : _partnerWorkflowHeadline(filteredDispatchChains),
      partnerPerformanceHeadline: performanceHeadline,
      partnerSlaHeadline: slaHeadline,
      partnerSummary:
          'Dispatches $dispatchCount • Declarations $declarationCount • Accept $acceptedCount • On site $onSiteCount • All clear $allClearCount • Cancelled $cancelledCount',
      partnerScopeBreakdowns: filteredScopeBreakdowns,
      partnerScoreboardRows: filteredScoreboardRows,
      partnerScoreboardHistory: filteredScoreboardHistory,
      partnerTrendRows: filteredTrendRows,
      partnerDispatchChains: filteredDispatchChains,
      latestActionTaken: report.latestActionTaken,
      recentActionsSummary: report.recentActionsSummary,
      latestSuppressedPattern: report.latestSuppressedPattern,
      overrideReasonSummary: report.overrideReasonSummary,
      generatedAtUtc: report.generatedAtUtc,
      shiftWindowStartUtc: report.shiftWindowStartUtc,
      shiftWindowEndUtc: report.shiftWindowEndUtc,
      fromCanonicalReport: report.fromCanonicalReport,
    );
  }

  String _vehicleExceptionReviewKey(
    SovereignReportVehicleVisitException exception,
  ) => sovereignReportVehicleVisitExceptionKey(exception);

  SovereignReportVehicleVisitException _applyVehicleExceptionReviewOverlay(
    SovereignReportVehicleVisitException exception,
  ) {
    final override =
        _vehicleExceptionReviewOverrides[_vehicleExceptionReviewKey(exception)];
    final storedStatusOverride = exception.operatorStatusOverride
        .trim()
        .toUpperCase();
    final overrideStatus = override?.statusOverride.trim().toUpperCase() ?? '';
    final effectiveStatusOverride = overrideStatus.isNotEmpty
        ? overrideStatus
        : storedStatusOverride;
    final effectiveReviewed = override?.reviewed ?? exception.operatorReviewed;
    final effectiveReviewedAtUtc =
        override?.reviewedAtUtc.toUtc() ??
        exception.operatorReviewedAtUtc?.toUtc();
    if (override == null &&
        storedStatusOverride.isEmpty &&
        !exception.operatorReviewed) {
      return exception;
    }
    final effectiveStatus = effectiveStatusOverride.isEmpty
        ? exception.statusLabel.trim()
        : effectiveStatusOverride;
    final effectiveWorkflow = _applyStatusToWorkflowSummary(
      exception.workflowSummary,
      effectiveStatus,
    );
    return exception.copyWith(
      statusLabel: effectiveStatus,
      workflowSummary: effectiveWorkflow,
      operatorReviewed: effectiveReviewed,
      operatorReviewedAtUtc: effectiveReviewed ? effectiveReviewedAtUtc : null,
      clearOperatorReviewedAtUtc: !effectiveReviewed,
      operatorStatusOverride: effectiveStatusOverride,
    );
  }

  String _applyStatusToWorkflowSummary(String summary, String statusLabel) {
    final normalizedStatus = statusLabel.trim().toUpperCase();
    if (normalizedStatus.isEmpty) {
      return summary.trim();
    }
    final trimmed = summary.trim();
    if (trimmed.isEmpty) {
      return 'OBSERVED ($normalizedStatus)';
    }
    final statusPattern = RegExp(r'\s*\([A-Z_]+\)\s*$');
    if (statusPattern.hasMatch(trimmed)) {
      return trimmed.replaceFirst(statusPattern, ' ($normalizedStatus)');
    }
    return '$trimmed ($normalizedStatus)';
  }

  void _setVehicleExceptionReviewed(
    SovereignReportVehicleVisitException exception, {
    String? statusOverride,
  }) {
    final reviewedAtUtc = DateTime.now().toUtc();
    final key = _vehicleExceptionReviewKey(exception);
    final existing = _vehicleExceptionReviewOverrides[key];
    final nextStatus =
        statusOverride ??
        existing?.statusOverride ??
        exception.operatorStatusOverride;
    setState(() {
      _vehicleExceptionReviewOverrides =
          Map<String, _VehicleExceptionReviewOverride>.from(
              _vehicleExceptionReviewOverrides,
            )
            ..[key] = _VehicleExceptionReviewOverride(
              reviewed: true,
              reviewedAtUtc: reviewedAtUtc,
              statusOverride: nextStatus.trim().toUpperCase(),
            );
    });
    _publishCanonicalVehicleExceptionReview(
      exception,
      reviewed: true,
      reviewedAtUtc: reviewedAtUtc,
      statusOverride: nextStatus.trim().toUpperCase(),
    );
  }

  void _clearVehicleExceptionReview(
    SovereignReportVehicleVisitException exception,
  ) {
    final key = _vehicleExceptionReviewKey(exception);
    final hasLocalOverride = _vehicleExceptionReviewOverrides.containsKey(key);
    final hasStoredReview =
        exception.operatorReviewed ||
        exception.operatorStatusOverride.trim().isNotEmpty;
    if (!hasLocalOverride && !hasStoredReview) {
      return;
    }
    setState(() {
      _vehicleExceptionReviewOverrides =
          Map<String, _VehicleExceptionReviewOverride>.from(
            _vehicleExceptionReviewOverrides,
          )..remove(key);
    });
    _publishCanonicalVehicleExceptionReview(
      exception,
      reviewed: false,
      reviewedAtUtc: null,
      statusOverride: '',
    );
  }

  void _publishCanonicalVehicleExceptionReview(
    SovereignReportVehicleVisitException exception, {
    required bool reviewed,
    required DateTime? reviewedAtUtc,
    required String statusOverride,
  }) {
    final canonical = widget.morningSovereignReport;
    final callback = widget.onMorningSovereignReportChanged;
    if (canonical == null || callback == null) {
      return;
    }
    final exceptionKey = _vehicleExceptionReviewKey(exception);
    final updatedExceptions = canonical.vehicleThroughput.exceptionVisits
        .map((candidate) {
          if (_vehicleExceptionReviewKey(candidate) != exceptionKey) {
            return candidate;
          }
          return candidate.copyWith(
            operatorReviewed: reviewed,
            operatorReviewedAtUtc: reviewedAtUtc?.toUtc(),
            clearOperatorReviewedAtUtc: !reviewed,
            operatorStatusOverride: statusOverride.trim().toUpperCase(),
          );
        })
        .toList(growable: false);
    callback(
      canonical.copyWith(
        vehicleThroughput: canonical.vehicleThroughput.copyWith(
          exceptionVisits: updatedExceptions,
        ),
      ),
    );
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
        detail: report.vehicleWorkflowHeadline.trim().isNotEmpty
            ? report.vehicleWorkflowHeadline
            : report.vehicleSummary.trim().isNotEmpty
            ? report.vehicleSummary
            : 'Completed ${report.vehicleCompletedVisits} • Active ${report.vehicleActiveVisits} • Incomplete ${report.vehicleIncompleteVisits}',
        color: report.vehicleUnknownEvents > 0
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981),
      ),
      _reportMetric(
        key: const ValueKey('governance-metric-partner-progression'),
        label: 'Partner Progression',
        value: '${report.partnerDispatches} dispatches',
        detail: report.partnerPerformanceHeadline.trim().isNotEmpty
            ? report.partnerPerformanceHeadline
            : report.partnerSlaHeadline.trim().isNotEmpty
            ? report.partnerSlaHeadline
            : report.partnerWorkflowHeadline.trim().isNotEmpty
            ? report.partnerWorkflowHeadline
            : report.partnerSummary.trim().isNotEmpty
            ? report.partnerSummary
            : 'Accept ${report.partnerAccepted} • On site ${report.partnerOnSite} • All clear ${report.partnerAllClear}',
        color: report.partnerCancelled > 0
            ? const Color(0xFFF59E0B)
            : report.partnerDispatches > 0
            ? const Color(0xFF22D3EE)
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
    final workflow = exception.workflowSummary.trim().isEmpty
        ? 'OBSERVED (${exception.statusLabel})'
        : exception.workflowSummary;
    final exceptionEventId = exception.primaryEventId.trim();
    final isActive =
        exceptionEventId.isNotEmpty &&
        _activeVehicleExceptionEventId == exceptionEventId;
    final canOpenEvent =
        widget.onOpenVehicleExceptionEvent != null &&
        exceptionEventId.isNotEmpty;
    final hasStatusOverride = exception.operatorStatusOverride
        .trim()
        .isNotEmpty;
    final reviewAuditEvents = _vehicleReviewAuditEventsFor(exception);
    final reviewAuditSummary = _vehicleReviewAuditSummary(reviewAuditEvents);
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
                if (exception.operatorReviewed) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x2210B981),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x6610B981)),
                    ),
                    child: Text(
                      'REVIEWED',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF10B981),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (hasStatusOverride) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x2222D3EE),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x6622D3EE)),
                    ),
                    child: Text(
                      'OVERRIDE',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF22D3EE),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  exception.statusLabel,
                  style: GoogleFonts.inter(
                    color: hasStatusOverride
                        ? const Color(0xFF67E8F9)
                        : const Color(0xFFFDE68A),
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
            const SizedBox(height: 2),
            Text(
              'Workflow: $workflow',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (reviewAuditSummary.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Review audit: $reviewAuditSummary',
                style: GoogleFonts.inter(
                  color: const Color(0xFF67E8F9),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
                    onPressed: () {
                      final openVisit = widget.onOpenVehicleExceptionVisit;
                      if (openVisit != null) {
                        openVisit.call(exception);
                        return;
                      }
                      widget.onOpenVehicleExceptionEvent!.call(
                        exceptionEventId,
                      );
                    },
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
                    _vehicleExceptionDetailLine('Workflow', workflow),
                    if (exception.operatorReviewed)
                      _vehicleExceptionDetailLine(
                        'Reviewed at',
                        exception.operatorReviewedAtUtc == null
                            ? 'session review'
                            : _timestampLabel(exception.operatorReviewedAtUtc!),
                      ),
                    if (hasStatusOverride)
                      _vehicleExceptionDetailLine(
                        'Status override',
                        exception.operatorStatusOverride,
                      ),
                    if (reviewAuditEvents.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Review audit',
                        key: ValueKey<String>(
                          'governance-vehicle-review-audit-${exceptionEventId.isEmpty ? _vehicleExceptionReviewKey(exception) : exceptionEventId}',
                        ),
                        style: GoogleFonts.inter(
                          color: const Color(0xFFEAF4FF),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final event in reviewAuditEvents)
                        _vehicleReviewAuditEntry(
                          event: event,
                          key: ValueKey<String>(
                            'governance-vehicle-review-audit-entry-${event.eventId}',
                          ),
                        ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Operator review',
                      key: ValueKey<String>(
                        'governance-vehicle-review-${exceptionEventId.isEmpty ? _vehicleExceptionReviewKey(exception) : exceptionEventId}',
                      ),
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _vehicleReviewAction(
                          actionKey: ValueKey<String>(
                            'governance-vehicle-review-mark-${exceptionEventId.isEmpty ? _vehicleExceptionReviewKey(exception) : exceptionEventId}',
                          ),
                          label: exception.operatorReviewed
                              ? 'Reviewed'
                              : 'Mark Reviewed',
                          active: exception.operatorReviewed,
                          onTap: () => _setVehicleExceptionReviewed(exception),
                        ),
                        _vehicleReviewAction(
                          actionKey: ValueKey<String>(
                            'governance-vehicle-review-completed-${exceptionEventId.isEmpty ? _vehicleExceptionReviewKey(exception) : exceptionEventId}',
                          ),
                          label: 'Set Completed',
                          active: exception.statusLabel == 'COMPLETED',
                          onTap: () => _setVehicleExceptionReviewed(
                            exception,
                            statusOverride: 'COMPLETED',
                          ),
                        ),
                        _vehicleReviewAction(
                          actionKey: ValueKey<String>(
                            'governance-vehicle-review-active-${exceptionEventId.isEmpty ? _vehicleExceptionReviewKey(exception) : exceptionEventId}',
                          ),
                          label: 'Set Active',
                          active: exception.statusLabel == 'ACTIVE',
                          onTap: () => _setVehicleExceptionReviewed(
                            exception,
                            statusOverride: 'ACTIVE',
                          ),
                        ),
                        _vehicleReviewAction(
                          actionKey: ValueKey<String>(
                            'governance-vehicle-review-incomplete-${exceptionEventId.isEmpty ? _vehicleExceptionReviewKey(exception) : exceptionEventId}',
                          ),
                          label: 'Set Incomplete',
                          active: exception.statusLabel == 'INCOMPLETE',
                          onTap: () => _setVehicleExceptionReviewed(
                            exception,
                            statusOverride: 'INCOMPLETE',
                          ),
                        ),
                        if (hasStatusOverride)
                          _vehicleReviewAction(
                            actionKey: ValueKey<String>(
                              'governance-vehicle-review-inferred-${exceptionEventId.isEmpty ? _vehicleExceptionReviewKey(exception) : exceptionEventId}',
                            ),
                            label: 'Use Inferred',
                            active: false,
                            onTap: () => _setVehicleExceptionReviewed(
                              exception,
                              statusOverride: '',
                            ),
                          ),
                        if (exception.operatorReviewed || hasStatusOverride)
                          _vehicleReviewAction(
                            actionKey: ValueKey<String>(
                              'governance-vehicle-review-clear-${exceptionEventId.isEmpty ? _vehicleExceptionReviewKey(exception) : exceptionEventId}',
                            ),
                            label: 'Clear Review',
                            active: false,
                            onTap: () =>
                                _clearVehicleExceptionReview(exception),
                          ),
                      ],
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

  Widget _vehicleReviewAction({
    Key? actionKey,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: actionKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0x1A22D3EE) : const Color(0x14151F2F),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? const Color(0x6622D3EE) : const Color(0x335C728F),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: active ? const Color(0xFF67E8F9) : const Color(0xFF9CB2D1),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  List<VehicleVisitReviewRecorded> _vehicleReviewAuditEventsFor(
    SovereignReportVehicleVisitException exception,
  ) {
    final exceptionKey = _vehicleExceptionReviewKey(exception);
    final history =
        widget.events
            .whereType<VehicleVisitReviewRecorded>()
            .where((event) => event.vehicleVisitKey.trim() == exceptionKey)
            .toList(growable: false)
          ..sort((a, b) {
            final occurredCompare = b.occurredAt.compareTo(a.occurredAt);
            if (occurredCompare != 0) {
              return occurredCompare;
            }
            return b.sequence.compareTo(a.sequence);
          });
    return history;
  }

  String _vehicleReviewAuditSummary(List<VehicleVisitReviewRecorded> history) {
    if (history.isEmpty) {
      return '';
    }
    final latest = history.first;
    final action = _vehicleReviewAuditActionLabel(latest);
    final countLabel = history.length == 1
        ? '1 action'
        : '${history.length} actions';
    return '$countLabel • latest ${_timestampLabel(latest.occurredAt)} • $action';
  }

  String _vehicleReviewAuditActionLabel(VehicleVisitReviewRecorded event) {
    if (!event.reviewed && event.statusOverride.trim().isEmpty) {
      return '${event.actorLabel} cleared review';
    }
    if (event.statusOverride.trim().isNotEmpty) {
      return '${event.actorLabel} set ${event.effectiveStatusLabel}';
    }
    return '${event.actorLabel} marked reviewed';
  }

  Widget _vehicleReviewAuditEntry({
    Key? key,
    required VehicleVisitReviewRecorded event,
  }) {
    final action = _vehicleReviewAuditActionLabel(event);
    final detailParts = <String>[
      _timestampLabel(event.occurredAt),
      if (event.reasonLabel.trim().isNotEmpty) event.reasonLabel.trim(),
      if (event.workflowSummary.trim().isNotEmpty) event.workflowSummary.trim(),
    ];
    return Container(
      key: key,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0x10151F2F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x335C728F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            action,
            style: GoogleFonts.inter(
              color: const Color(0xFF67E8F9),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            detailParts.join(' • '),
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _vehicleScopeLabel(SovereignReportVehicleScopeBreakdown scope) {
    return '${scope.clientId}/${scope.siteId}';
  }

  String _vehicleScopeCsvSummary(SovereignReportVehicleScopeBreakdown scope) {
    return '${_vehicleScopeLabel(scope)} • ${scope.summaryLine}';
  }

  List<_PartnerTrendRow> _partnerTrendRows({
    required String currentReportDate,
    required List<SovereignReportPartnerScoreboardRow> currentRows,
  }) {
    final scoreboardRowsByDate =
        <String, List<SovereignReportPartnerScoreboardRow>>{};
    for (final report in widget.morningSovereignReportHistory) {
      final reportDate = report.date.trim();
      if (reportDate.isEmpty) {
        continue;
      }
      scoreboardRowsByDate[reportDate] =
          report.partnerProgression.scoreboardRows;
    }
    if (currentReportDate.trim().isNotEmpty && currentRows.isNotEmpty) {
      scoreboardRowsByDate[currentReportDate.trim()] = currentRows;
    }
    if (scoreboardRowsByDate.isEmpty) {
      return const <_PartnerTrendRow>[];
    }
    final aggregates = <String, _PartnerTrendAggregate>{};
    for (final entry in scoreboardRowsByDate.entries) {
      final reportDate = entry.key.trim();
      final isCurrent = reportDate == currentReportDate.trim();
      for (final row in entry.value) {
        final key = _partnerTrendKey(
          row.clientId,
          row.siteId,
          row.partnerLabel,
        );
        final aggregate = aggregates.putIfAbsent(
          key,
          () => _PartnerTrendAggregate(
            clientId: row.clientId,
            siteId: row.siteId,
            partnerLabel: row.partnerLabel,
          ),
        );
        aggregate.reportDates.add(reportDate);
        aggregate.dispatchCount += row.dispatchCount;
        aggregate.strongCount += row.strongCount;
        aggregate.onTrackCount += row.onTrackCount;
        aggregate.watchCount += row.watchCount;
        aggregate.criticalCount += row.criticalCount;
        if (row.averageAcceptedDelayMinutes > 0) {
          aggregate.acceptedDelayWeightedSum +=
              row.averageAcceptedDelayMinutes * row.dispatchCount;
          aggregate.acceptedDelayWeight += row.dispatchCount;
        }
        if (row.averageOnSiteDelayMinutes > 0) {
          aggregate.onSiteDelayWeightedSum +=
              row.averageOnSiteDelayMinutes * row.dispatchCount;
          aggregate.onSiteDelayWeight += row.dispatchCount;
        }
        if (isCurrent) {
          aggregate.currentRow = row;
        } else {
          aggregate.priorSeverityScores.add(_partnerSeverityScore(row));
          if (row.averageAcceptedDelayMinutes > 0) {
            aggregate.priorAcceptedDelayMinutes.add(
              row.averageAcceptedDelayMinutes,
            );
          }
          if (row.averageOnSiteDelayMinutes > 0) {
            aggregate.priorOnSiteDelayMinutes.add(
              row.averageOnSiteDelayMinutes,
            );
          }
        }
      }
    }
    final rows = <_PartnerTrendRow>[];
    for (final aggregate in aggregates.values) {
      final currentRow = aggregate.currentRow;
      if (currentRow == null) {
        continue;
      }
      final acceptedAverage = aggregate.acceptedDelayWeight == 0
          ? 0.0
          : aggregate.acceptedDelayWeightedSum / aggregate.acceptedDelayWeight;
      final onSiteAverage = aggregate.onSiteDelayWeight == 0
          ? 0.0
          : aggregate.onSiteDelayWeightedSum / aggregate.onSiteDelayWeight;
      final trendLabel = _partnerTrendLabel(
        currentRow,
        aggregate.priorSeverityScores,
      );
      final trendReason = _partnerTrendReason(
        currentRow: currentRow,
        priorSeverityScores: aggregate.priorSeverityScores,
        priorAcceptedDelayMinutes: aggregate.priorAcceptedDelayMinutes,
        priorOnSiteDelayMinutes: aggregate.priorOnSiteDelayMinutes,
      );
      final acceptedLabel = acceptedAverage > 0
          ? acceptedAverage.toStringAsFixed(1)
          : 'n/a';
      final onSiteLabel = onSiteAverage > 0
          ? onSiteAverage.toStringAsFixed(1)
          : 'n/a';
      rows.add(
        _PartnerTrendRow(
          clientId: aggregate.clientId,
          siteId: aggregate.siteId,
          partnerLabel: aggregate.partnerLabel,
          reportDays: aggregate.reportDates.length,
          dispatchCount: aggregate.dispatchCount,
          strongCount: aggregate.strongCount,
          onTrackCount: aggregate.onTrackCount,
          watchCount: aggregate.watchCount,
          criticalCount: aggregate.criticalCount,
          averageAcceptedDelayMinutes: double.parse(
            acceptedAverage.toStringAsFixed(1),
          ),
          averageOnSiteDelayMinutes: double.parse(
            onSiteAverage.toStringAsFixed(1),
          ),
          currentScoreLabel: _partnerDominantScoreLabel(currentRow),
          trendLabel: trendLabel,
          trendReason: trendReason,
          summaryLine:
              'Days ${aggregate.reportDates.length} • Dispatches ${aggregate.dispatchCount} • Strong ${aggregate.strongCount} • On track ${aggregate.onTrackCount} • Watch ${aggregate.watchCount} • Critical ${aggregate.criticalCount} • Avg accept ${acceptedLabel}m • Avg on site ${onSiteLabel}m',
        ),
      );
    }
    rows.sort((a, b) {
      final criticalCompare = b.criticalCount.compareTo(a.criticalCount);
      if (criticalCompare != 0) {
        return criticalCompare;
      }
      final slippingCompare = _partnerTrendPriority(
        b.trendLabel,
      ).compareTo(_partnerTrendPriority(a.trendLabel));
      if (slippingCompare != 0) {
        return slippingCompare;
      }
      final dispatchCompare = b.dispatchCount.compareTo(a.dispatchCount);
      if (dispatchCompare != 0) {
        return dispatchCompare;
      }
      return a.partnerLabel.compareTo(b.partnerLabel);
    });
    return rows;
  }

  List<_PartnerScoreboardHistoryPoint> _partnerScoreboardHistoryRows({
    required String currentReportDate,
    required List<SovereignReportPartnerScoreboardRow> currentRows,
  }) {
    final scopeKeys = <String>{
      for (final row in currentRows)
        _partnerTrendKey(row.clientId, row.siteId, row.partnerLabel),
    };
    if (scopeKeys.isEmpty) {
      return const <_PartnerScoreboardHistoryPoint>[];
    }
    final byDateAndScope = <String, _PartnerScoreboardHistoryPoint>{};
    for (final report in widget.morningSovereignReportHistory) {
      final reportDate = report.date.trim();
      if (reportDate.isEmpty) {
        continue;
      }
      for (final row in report.partnerProgression.scoreboardRows) {
        final scopeKey = _partnerTrendKey(
          row.clientId,
          row.siteId,
          row.partnerLabel,
        );
        if (!scopeKeys.contains(scopeKey)) {
          continue;
        }
        byDateAndScope['$reportDate::$scopeKey'] =
            _PartnerScoreboardHistoryPoint(
              reportDate: reportDate,
              row: row,
              current: false,
            );
      }
    }
    for (final row in currentRows) {
      final scopeKey = _partnerTrendKey(
        row.clientId,
        row.siteId,
        row.partnerLabel,
      );
      final reportDate = currentReportDate.trim();
      if (reportDate.isEmpty) {
        continue;
      }
      byDateAndScope['$reportDate::$scopeKey'] = _PartnerScoreboardHistoryPoint(
        reportDate: reportDate,
        row: row,
        current: true,
      );
    }
    final rows = byDateAndScope.values.toList(growable: false)
      ..sort((a, b) {
        final dateCompare = b.reportDate.compareTo(a.reportDate);
        if (dateCompare != 0) {
          return dateCompare;
        }
        final scopeCompare = a.row.clientId.compareTo(b.row.clientId);
        if (scopeCompare != 0) {
          return scopeCompare;
        }
        final siteCompare = a.row.siteId.compareTo(b.row.siteId);
        if (siteCompare != 0) {
          return siteCompare;
        }
        return a.row.partnerLabel.compareTo(b.row.partnerLabel);
      });
    return rows;
  }

  String _partnerTrendKey(String clientId, String siteId, String partnerLabel) {
    return '${clientId.trim()}::${siteId.trim()}::${partnerLabel.trim().toUpperCase()}';
  }

  double _partnerSeverityScore(SovereignReportPartnerScoreboardRow row) {
    final dispatchCount = row.dispatchCount <= 0 ? 1 : row.dispatchCount;
    final rawScore = (row.criticalCount * 3) + row.watchCount - row.strongCount;
    return rawScore / dispatchCount;
  }

  String _partnerDominantScoreLabel(SovereignReportPartnerScoreboardRow row) {
    if (row.criticalCount > 0) {
      return 'CRITICAL';
    }
    if (row.watchCount > 0) {
      return 'WATCH';
    }
    if (row.onTrackCount > 0) {
      return 'ON TRACK';
    }
    if (row.strongCount > 0) {
      return 'STRONG';
    }
    return '';
  }

  String _partnerTrendLabel(
    SovereignReportPartnerScoreboardRow currentRow,
    List<double> priorSeverityScores,
  ) {
    if (priorSeverityScores.isEmpty) {
      return 'NEW';
    }
    final priorAverage =
        priorSeverityScores.reduce((left, right) => left + right) /
        priorSeverityScores.length;
    final currentScore = _partnerSeverityScore(currentRow);
    if (currentScore <= priorAverage - 0.35) {
      return 'IMPROVING';
    }
    if (currentScore >= priorAverage + 0.35) {
      return 'SLIPPING';
    }
    return 'STABLE';
  }

  String _partnerTrendReason({
    required SovereignReportPartnerScoreboardRow currentRow,
    required List<double> priorSeverityScores,
    required List<double> priorAcceptedDelayMinutes,
    required List<double> priorOnSiteDelayMinutes,
  }) {
    if (priorSeverityScores.isEmpty) {
      return 'First recorded shift in the 7-day scoreboard window.';
    }
    final trendLabel = _partnerTrendLabel(currentRow, priorSeverityScores);
    final priorAcceptedAverage = priorAcceptedDelayMinutes.isEmpty
        ? null
        : priorAcceptedDelayMinutes.reduce((left, right) => left + right) /
              priorAcceptedDelayMinutes.length;
    final priorOnSiteAverage = priorOnSiteDelayMinutes.isEmpty
        ? null
        : priorOnSiteDelayMinutes.reduce((left, right) => left + right) /
              priorOnSiteDelayMinutes.length;
    switch (trendLabel) {
      case 'IMPROVING':
        if (priorAcceptedAverage != null &&
            currentRow.averageAcceptedDelayMinutes > 0 &&
            currentRow.averageAcceptedDelayMinutes <=
                priorAcceptedAverage - 2.0) {
          return 'Acceptance timing improved against the prior 7-day average.';
        }
        if (priorOnSiteAverage != null &&
            currentRow.averageOnSiteDelayMinutes > 0 &&
            currentRow.averageOnSiteDelayMinutes <= priorOnSiteAverage - 2.0) {
          return 'On-site timing improved against the prior 7-day average.';
        }
        return 'Current shift severity improved against the prior 7-day average.';
      case 'SLIPPING':
        if (priorAcceptedAverage != null &&
            currentRow.averageAcceptedDelayMinutes >=
                priorAcceptedAverage + 2.0) {
          return 'Acceptance timing slipped beyond the prior 7-day average.';
        }
        if (priorOnSiteAverage != null &&
            currentRow.averageOnSiteDelayMinutes >= priorOnSiteAverage + 2.0) {
          return 'On-site timing slipped beyond the prior 7-day average.';
        }
        return 'Current shift severity slipped against the prior 7-day average.';
      case 'STABLE':
      case 'NEW':
        return 'Current shift is holding close to the prior 7-day performance.';
    }
    return '';
  }

  int _partnerTrendPriority(String label) {
    switch (label.trim().toUpperCase()) {
      case 'SLIPPING':
        return 4;
      case 'NEW':
        return 3;
      case 'STABLE':
        return 2;
      case 'IMPROVING':
        return 1;
      default:
        return 0;
    }
  }

  String _partnerScopeLabel(SovereignReportPartnerScopeBreakdown scope) {
    return '${scope.clientId}/${scope.siteId}';
  }

  String _partnerScopeCsvSummary(SovereignReportPartnerScopeBreakdown scope) {
    return '${_partnerScopeLabel(scope)} • ${scope.summaryLine}';
  }

  String _partnerScoreboardCsvSummary(SovereignReportPartnerScoreboardRow row) {
    return '${row.clientId}/${row.siteId} • ${row.partnerLabel} • ${row.summaryLine}';
  }

  String _partnerScoreboardHistoryCsvSummary(
    _PartnerScoreboardHistoryPoint point,
  ) {
    final currentLabel = point.current ? 'CURRENT' : 'HISTORY';
    return '${point.reportDate} • $currentLabel • ${_partnerScoreboardCsvSummary(point.row)}';
  }

  String _partnerTrendCsvSummary(_PartnerTrendRow row) {
    final currentScore = row.currentScoreLabel.trim().isEmpty
        ? ''
        : ' • current ${row.currentScoreLabel.trim()}';
    return '${row.clientId}/${row.siteId} • ${row.partnerLabel} • ${row.summaryLine} • trend ${row.trendLabel}$currentScore • ${row.trendReason}';
  }

  String _partnerChainCsvSummary(SovereignReportPartnerDispatchChain chain) {
    final timing = _partnerChainTimingLabel(chain);
    final timingSuffix = timing.isEmpty ? '' : ' • $timing';
    final scoreLabel = chain.scoreLabel.trim().isEmpty
        ? ''
        : ' • ${chain.scoreLabel.trim()}';
    final scoreReason = chain.scoreReason.trim().isEmpty
        ? ''
        : ' • ${chain.scoreReason.trim()}';
    return '${chain.partnerLabel} • ${chain.dispatchId} • ${chain.clientId}/${chain.siteId} • ${chain.workflowSummary}$scoreLabel • latest ${_partnerStatusLabel(chain.latestStatus)} @ ${_timestampLabel(chain.latestOccurredAtUtc)}$timingSuffix$scoreReason';
  }

  String _vehicleExceptionCsvSummary(
    SovereignReportVehicleVisitException exception,
  ) {
    final zones = exception.zoneLabels.isEmpty
        ? 'no zones captured'
        : exception.zoneLabels.join(' -> ');
    final workflow = exception.workflowSummary.trim().isEmpty
        ? 'OBSERVED (${exception.statusLabel})'
        : exception.workflowSummary;
    final review = exception.operatorReviewed
        ? ' • reviewed ${exception.operatorReviewedAtUtc == null ? 'session' : _timestampLabel(exception.operatorReviewedAtUtc!)}${exception.operatorStatusOverride.trim().isNotEmpty ? ' • override ${exception.operatorStatusOverride}' : ''}'
        : '';
    return '${exception.reasonLabel} • ${exception.statusLabel} • ${exception.vehicleLabel} • ${exception.clientId}/${exception.siteId} • dwell ${exception.dwellMinutes.toStringAsFixed(1)}m • workflow $workflow • zones $zones$review';
  }

  Widget _partnerScopeCard(SovereignReportPartnerScopeBreakdown scope) {
    final scopeLabel = _partnerScopeLabel(scope);
    return SizedBox(
      width: 280,
      child: Container(
        key: ValueKey<String>('governance-partner-scope-$scopeLabel'),
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

  Widget _partnerScoreboardCard(SovereignReportPartnerScoreboardRow row) {
    final scopeLabel = '${row.clientId}/${row.siteId}';
    return SizedBox(
      width: 320,
      child: InkWell(
        key: ValueKey<String>(
          'governance-partner-scoreboard-$scopeLabel-${row.partnerLabel}',
        ),
        onTap: () => _showPartnerScoreboardDrillIn(row: row),
        borderRadius: BorderRadius.circular(8),
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
                '$scopeLabel • ${row.partnerLabel}',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                row.summaryLine,
                style: GoogleFonts.inter(
                  color: const Color(0xFF9CB2D1),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap to drill in',
                style: GoogleFonts.inter(
                  color: const Color(0xFF8FD1FF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _partnerTrendCard(_PartnerTrendRow row) {
    final scopeLabel = '${row.clientId}/${row.siteId}';
    final trendColor = _partnerTrendColor(row.trendLabel);
    final currentScoreColor = _partnerScoreColor(row.currentScoreLabel);
    return SizedBox(
      width: 340,
      child: InkWell(
        key: ValueKey<String>(
          'governance-partner-trend-$scopeLabel-${row.partnerLabel}',
        ),
        onTap: () => _showPartnerScoreboardDrillIn(
          row: SovereignReportPartnerScoreboardRow(
            clientId: row.clientId,
            siteId: row.siteId,
            partnerLabel: row.partnerLabel,
            dispatchCount: row.dispatchCount,
            strongCount: row.strongCount,
            onTrackCount: row.onTrackCount,
            watchCount: row.watchCount,
            criticalCount: row.criticalCount,
            averageAcceptedDelayMinutes: row.averageAcceptedDelayMinutes,
            averageOnSiteDelayMinutes: row.averageOnSiteDelayMinutes,
            summaryLine: row.summaryLine,
          ),
          trendRow: row,
        ),
        borderRadius: BorderRadius.circular(8),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$scopeLabel • ${row.partnerLabel}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (row.currentScoreLabel.trim().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: currentScoreColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: currentScoreColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        row.currentScoreLabel,
                        style: GoogleFonts.inter(
                          color: currentScoreColor,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: trendColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: trendColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      row.trendLabel,
                      style: GoogleFonts.inter(
                        color: trendColor,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                row.summaryLine,
                style: GoogleFonts.inter(
                  color: const Color(0xFF9CB2D1),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                row.trendReason,
                style: GoogleFonts.inter(
                  color: trendColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap to drill in',
                style: GoogleFonts.inter(
                  color: const Color(0xFF8FD1FF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _partnerTrendMetricChip({
    required String label,
    required String value,
    Color color = const Color(0xFF8FD1FF),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _showPartnerScoreboardDrillIn({
    required SovereignReportPartnerScoreboardRow row,
    _PartnerTrendRow? trendRow,
  }) {
    final report = _currentGovernanceReportForFocusValidation();
    final history = _partnerScoreboardHistory(
      report: report,
      clientId: row.clientId,
      siteId: row.siteId,
      partnerLabel: row.partnerLabel,
    );
    final chains = report.partnerDispatchChains
        .where(
          (chain) =>
              chain.clientId.trim() == row.clientId.trim() &&
              chain.siteId.trim() == row.siteId.trim() &&
              chain.partnerLabel.trim().toUpperCase() ==
                  row.partnerLabel.trim().toUpperCase(),
        )
        .toList(growable: false);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF08111B),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                key: const ValueKey('governance-partner-scoreboard-dialog'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PARTNER SCORECARD DRILL-IN',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFEAF4FF),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${row.clientId}/${row.siteId} • ${row.partnerLabel}',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF9CB2D1),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close, color: Color(0xFFEAF4FF)),
                      ),
                    ],
                  ),
                  if (trendRow != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0x14000000),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x22FFFFFF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _partnerTrendMetricChip(
                                label: 'Trend',
                                value:
                                    '${trendRow.trendLabel} • ${trendRow.reportDays}d',
                                color: _partnerTrendColor(trendRow.trendLabel),
                              ),
                              if (trendRow.currentScoreLabel.trim().isNotEmpty)
                                _partnerTrendMetricChip(
                                  label: 'Score',
                                  value: trendRow.currentScoreLabel,
                                  color: _partnerScoreColor(
                                    trendRow.currentScoreLabel,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            trendRow.trendReason,
                            style: GoogleFonts.inter(
                              color: _partnerTrendColor(trendRow.trendLabel),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (widget.onOpenReportsForPartnerScope != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const ValueKey(
                          'governance-partner-scorecard-open-reports-scope',
                        ),
                        onPressed: () {
                          widget.onOpenReportsForPartnerScope!(
                            row.clientId,
                            row.siteId,
                            row.partnerLabel,
                          );
                          Navigator.of(dialogContext).pop();
                          _showSnack(
                            'Opening Reports for ${row.siteId} • ${row.partnerLabel}',
                          );
                        },
                        icon: const Icon(Icons.assessment_rounded, size: 16),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFFDDAA),
                          side: const BorderSide(color: Color(0xFF5B3A16)),
                        ),
                        label: Text(
                          'Open Reports Scope',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '7-day scoreboard history',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFEAF4FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (final point in history) ...[
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: point.current
                                    ? const Color(0x1A0EA5E9)
                                    : const Color(0x14000000),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: point.current
                                      ? const Color(0x550EA5E9)
                                      : const Color(0x22FFFFFF),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    point.current
                                        ? '${point.reportDate} • CURRENT'
                                        : point.reportDate,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFFEAF4FF),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    point.row.summaryLine,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF9CB2D1),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Current dispatch chains',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFEAF4FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (chains.isEmpty)
                            Text(
                              'No current dispatch chains for this partner scope.',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF9CB2D1),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            for (final chain in chains) ...[
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0x14000000),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0x22FFFFFF),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${chain.dispatchId} • ${chain.scoreLabel.isEmpty ? _partnerStatusLabel(chain.latestStatus) : chain.scoreLabel}',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFEAF4FF),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      chain.workflowSummary.isEmpty
                                          ? chain.scoreReason
                                          : chain.workflowSummary,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF9CB2D1),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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
            ),
          ),
        );
      },
    );
  }

  List<_PartnerScoreboardHistoryPoint> _partnerScoreboardHistory({
    required _GovernanceReportView report,
    required String clientId,
    required String siteId,
    required String partnerLabel,
  }) {
    final byDate = <String, _PartnerScoreboardHistoryPoint>{};
    for (final historicalReport in widget.morningSovereignReportHistory) {
      final reportDate = historicalReport.date.trim();
      if (reportDate.isEmpty) {
        continue;
      }
      for (final row in historicalReport.partnerProgression.scoreboardRows) {
        if (!_partnerScoreboardScopeMatches(
          row,
          clientId: clientId,
          siteId: siteId,
          partnerLabel: partnerLabel,
        )) {
          continue;
        }
        byDate[reportDate] = _PartnerScoreboardHistoryPoint(
          reportDate: reportDate,
          row: row,
          current: false,
        );
      }
    }
    for (final row in report.partnerScoreboardRows) {
      if (!_partnerScoreboardScopeMatches(
        row,
        clientId: clientId,
        siteId: siteId,
        partnerLabel: partnerLabel,
      )) {
        continue;
      }
      byDate[report.reportDate.trim()] = _PartnerScoreboardHistoryPoint(
        reportDate: report.reportDate.trim(),
        row: row,
        current: true,
      );
    }
    final points = byDate.values.toList(growable: false)
      ..sort((a, b) => b.reportDate.compareTo(a.reportDate));
    return points;
  }

  bool _partnerScoreboardScopeMatches(
    SovereignReportPartnerScoreboardRow row, {
    required String clientId,
    required String siteId,
    required String partnerLabel,
  }) {
    return row.clientId.trim() == clientId.trim() &&
        row.siteId.trim() == siteId.trim() &&
        row.partnerLabel.trim().toUpperCase() ==
            partnerLabel.trim().toUpperCase();
  }

  Widget _partnerDispatchChainRow(SovereignReportPartnerDispatchChain chain) {
    return Container(
      key: ValueKey<String>('governance-partner-chain-${chain.dispatchId}'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x14151F2F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x335C728F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${chain.partnerLabel} • ${chain.dispatchId}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _partnerStatusColor(
                    chain.latestStatus,
                  ).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _partnerStatusColor(
                      chain.latestStatus,
                    ).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  _partnerStatusLabel(chain.latestStatus),
                  style: GoogleFonts.inter(
                    color: _partnerStatusColor(chain.latestStatus),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (chain.scoreLabel.trim().isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _partnerScoreColor(
                      chain.scoreLabel,
                    ).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _partnerScoreColor(
                        chain.scoreLabel,
                      ).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    chain.scoreLabel,
                    style: GoogleFonts.inter(
                      color: _partnerScoreColor(chain.scoreLabel),
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${chain.clientId}/${chain.siteId} • ${chain.declarationCount} declarations • latest ${_timestampLabel(chain.latestOccurredAtUtc)}',
            style: GoogleFonts.inter(
              color: const Color(0xFF9CB2D1),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Workflow: ${chain.workflowSummary}',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_partnerChainTimingLabel(chain).isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'SLA: ${_partnerChainTimingLabel(chain)}',
              style: GoogleFonts.inter(
                color: const Color(0xFF67E8F9),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (chain.scoreReason.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Scorecard: ${chain.scoreReason}',
              style: GoogleFonts.inter(
                color: const Color(0xFFFDE68A),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _partnerChainTimingLabel(SovereignReportPartnerDispatchChain chain) {
    final parts = <String>[];
    if (chain.acceptedDelayMinutes != null) {
      parts.add(
        'accepted in ${chain.acceptedDelayMinutes!.toStringAsFixed(1)}m',
      );
    }
    if (chain.onSiteDelayMinutes != null) {
      parts.add('on site in ${chain.onSiteDelayMinutes!.toStringAsFixed(1)}m');
    }
    return parts.join(' • ');
  }

  Color _partnerScoreColor(String scoreLabel) {
    return switch (scoreLabel.trim().toUpperCase()) {
      'STRONG' => const Color(0xFF10B981),
      'ON TRACK' => const Color(0xFF38BDF8),
      'WATCH' => const Color(0xFFF59E0B),
      'CRITICAL' => const Color(0xFFEF4444),
      _ => const Color(0xFF9CB2D1),
    };
  }

  Color _partnerTrendColor(String trendLabel) {
    return switch (trendLabel.trim().toUpperCase()) {
      'IMPROVING' => const Color(0xFF10B981),
      'STABLE' => const Color(0xFF38BDF8),
      'SLIPPING' => const Color(0xFFF97316),
      'NEW' => const Color(0xFFFDE68A),
      _ => const Color(0xFF9CB2D1),
    };
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
      final reviewedExceptions = canonical.vehicleThroughput.exceptionVisits
          .map(_applyVehicleExceptionReviewOverlay)
          .toList(growable: false);
      final reasons = canonical.aiHumanDelta.overrideReasons.entries.toList(
        growable: false,
      )..sort((a, b) => b.value.compareTo(a.value));
      final reasonSummary = reasons.isEmpty
          ? 'none'
          : reasons
                .take(3)
                .map((entry) => '${entry.key} (${entry.value})')
                .join(', ');
      final partnerTrendRows = _partnerTrendRows(
        currentReportDate: canonical.date,
        currentRows: canonical.partnerProgression.scoreboardRows,
      );
      final partnerScoreboardHistory = _partnerScoreboardHistoryRows(
        currentReportDate: canonical.date,
        currentRows: canonical.partnerProgression.scoreboardRows,
      );
      return _applyPartnerScopeFilter(
        _GovernanceReportView(
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
          vehicleUnknownEvents:
              canonical.vehicleThroughput.unknownVehicleEvents,
          vehiclePeakHourLabel: canonical.vehicleThroughput.peakHourLabel,
          vehiclePeakHourVisitCount:
              canonical.vehicleThroughput.peakHourVisitCount,
          vehicleWorkflowHeadline: canonical.vehicleThroughput.workflowHeadline,
          vehicleSummary: canonical.vehicleThroughput.summaryLine,
          vehicleScopeBreakdowns: canonical.vehicleThroughput.scopeBreakdowns,
          vehicleExceptionVisits: reviewedExceptions,
          partnerDispatches: canonical.partnerProgression.dispatchCount,
          partnerDeclarations: canonical.partnerProgression.declarationCount,
          partnerAccepted: canonical.partnerProgression.acceptedCount,
          partnerOnSite: canonical.partnerProgression.onSiteCount,
          partnerAllClear: canonical.partnerProgression.allClearCount,
          partnerCancelled: canonical.partnerProgression.cancelledCount,
          partnerWorkflowHeadline:
              canonical.partnerProgression.workflowHeadline,
          partnerPerformanceHeadline:
              canonical.partnerProgression.performanceHeadline,
          partnerSlaHeadline: canonical.partnerProgression.slaHeadline,
          partnerSummary: canonical.partnerProgression.summaryLine,
          partnerScopeBreakdowns: canonical.partnerProgression.scopeBreakdowns,
          partnerScoreboardRows: canonical.partnerProgression.scoreboardRows,
          partnerScoreboardHistory: partnerScoreboardHistory,
          partnerTrendRows: partnerTrendRows,
          partnerDispatchChains: canonical.partnerProgression.dispatchChains,
          latestActionTaken: canonical.sceneReview.latestActionTaken,
          recentActionsSummary: canonical.sceneReview.recentActionsSummary,
          latestSuppressedPattern:
              canonical.sceneReview.latestSuppressedPattern,
          overrideReasonSummary: reasonSummary,
          generatedAtUtc: canonical.generatedAtUtc,
          shiftWindowStartUtc: canonical.shiftWindowStartUtc,
          shiftWindowEndUtc: canonical.shiftWindowEndUtc,
          fromCanonicalReport: true,
        ),
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
    final partnerSummary = _fallbackPartnerProgression(
      widget.events,
      widget.events.whereType<DecisionCreated>().toList(growable: false),
    );
    final fallbackReportDate = _dateLabel(DateTime.now().toUtc());
    final partnerTrendRows = _partnerTrendRows(
      currentReportDate: fallbackReportDate,
      currentRows: partnerSummary.scoreboardRows,
    );
    final partnerScoreboardHistory = _partnerScoreboardHistoryRows(
      currentReportDate: fallbackReportDate,
      currentRows: partnerSummary.scoreboardRows,
    );
    final integrityScore = widget.events.isEmpty
        ? 100
        : (99 - (widget.events.length % 3));
    return _applyPartnerScopeFilter(
      _GovernanceReportView(
        reportDate: fallbackReportDate,
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
        vehicleWorkflowHeadline: '',
        vehicleSummary: '',
        vehicleScopeBreakdowns: const <SovereignReportVehicleScopeBreakdown>[],
        vehicleExceptionVisits: const <SovereignReportVehicleVisitException>[],
        partnerDispatches: partnerSummary.dispatchCount,
        partnerDeclarations: partnerSummary.declarationCount,
        partnerAccepted: partnerSummary.acceptedCount,
        partnerOnSite: partnerSummary.onSiteCount,
        partnerAllClear: partnerSummary.allClearCount,
        partnerCancelled: partnerSummary.cancelledCount,
        partnerWorkflowHeadline: partnerSummary.workflowHeadline,
        partnerPerformanceHeadline: partnerSummary.performanceHeadline,
        partnerSlaHeadline: partnerSummary.slaHeadline,
        partnerSummary: partnerSummary.summaryLine,
        partnerScopeBreakdowns: partnerSummary.scopeBreakdowns,
        partnerScoreboardRows: partnerSummary.scoreboardRows,
        partnerScoreboardHistory: partnerScoreboardHistory,
        partnerTrendRows: partnerTrendRows,
        partnerDispatchChains: partnerSummary.dispatchChains,
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
      ),
    );
  }

  SovereignReportPartnerProgression _fallbackPartnerProgression(
    List<DispatchEvent> events,
    List<DecisionCreated> decisions,
  ) {
    final declarations = events
        .whereType<PartnerDispatchStatusDeclared>()
        .toList(growable: false);
    if (declarations.isEmpty) {
      return const SovereignReportPartnerProgression(
        dispatchCount: 0,
        declarationCount: 0,
        acceptedCount: 0,
        onSiteCount: 0,
        allClearCount: 0,
        cancelledCount: 0,
        workflowHeadline: '',
        performanceHeadline: '',
        slaHeadline: '',
        summaryLine: '',
        scopeBreakdowns: <SovereignReportPartnerScopeBreakdown>[],
        scoreboardRows: <SovereignReportPartnerScoreboardRow>[],
        dispatchChains: <SovereignReportPartnerDispatchChain>[],
      );
    }
    final groupedByDispatch = <String, List<PartnerDispatchStatusDeclared>>{};
    for (final declaration in declarations) {
      final dispatchId = declaration.dispatchId.trim();
      if (dispatchId.isEmpty) {
        continue;
      }
      groupedByDispatch
          .putIfAbsent(dispatchId, () => <PartnerDispatchStatusDeclared>[])
          .add(declaration);
    }
    if (groupedByDispatch.isEmpty) {
      return const SovereignReportPartnerProgression(
        dispatchCount: 0,
        declarationCount: 0,
        acceptedCount: 0,
        onSiteCount: 0,
        allClearCount: 0,
        cancelledCount: 0,
        workflowHeadline: '',
        performanceHeadline: '',
        slaHeadline: '',
        summaryLine: '',
        scopeBreakdowns: <SovereignReportPartnerScopeBreakdown>[],
        scoreboardRows: <SovereignReportPartnerScoreboardRow>[],
        dispatchChains: <SovereignReportPartnerDispatchChain>[],
      );
    }
    final dispatchCreatedAtUtcByDispatchId = <String, DateTime>{
      for (final decision in decisions)
        if (decision.dispatchId.trim().isNotEmpty)
          decision.dispatchId.trim(): decision.occurredAt.toUtc(),
    };
    var acceptedCount = 0;
    var onSiteCount = 0;
    var allClearCount = 0;
    var cancelledCount = 0;
    final acceptedDelayMinutes = <double>[];
    final onSiteDelayMinutes = <double>[];
    final scopeDeclarations = <String, List<PartnerDispatchStatusDeclared>>{};
    final chains = <SovereignReportPartnerDispatchChain>[];
    for (final entry in groupedByDispatch.entries) {
      final ordered = [...entry.value]
        ..sort((a, b) {
          final occurredAtCompare = a.occurredAt.compareTo(b.occurredAt);
          if (occurredAtCompare != 0) {
            return occurredAtCompare;
          }
          return a.sequence.compareTo(b.sequence);
        });
      final first = ordered.first;
      final latest = ordered.last;
      final dispatchCreatedAtUtc = dispatchCreatedAtUtcByDispatchId[entry.key];
      final firstOccurrenceByStatus = <PartnerDispatchStatus, DateTime>{};
      for (final declaration in ordered) {
        firstOccurrenceByStatus.putIfAbsent(
          declaration.status,
          () => declaration.occurredAt.toUtc(),
        );
        final scopeKey = _partnerScopeKey(
          declaration.clientId,
          declaration.siteId,
        );
        scopeDeclarations
            .putIfAbsent(scopeKey, () => <PartnerDispatchStatusDeclared>[])
            .add(declaration);
      }
      if (firstOccurrenceByStatus.containsKey(PartnerDispatchStatus.accepted)) {
        acceptedCount += 1;
      }
      if (firstOccurrenceByStatus.containsKey(PartnerDispatchStatus.onSite)) {
        onSiteCount += 1;
      }
      if (firstOccurrenceByStatus.containsKey(PartnerDispatchStatus.allClear)) {
        allClearCount += 1;
      }
      if (firstOccurrenceByStatus.containsKey(
        PartnerDispatchStatus.cancelled,
      )) {
        cancelledCount += 1;
      }
      final acceptedDelay = _partnerDelayMinutes(
        dispatchCreatedAtUtc,
        firstOccurrenceByStatus[PartnerDispatchStatus.accepted],
      );
      final onSiteDelay = _partnerDelayMinutes(
        dispatchCreatedAtUtc,
        firstOccurrenceByStatus[PartnerDispatchStatus.onSite],
      );
      if (acceptedDelay != null) {
        acceptedDelayMinutes.add(acceptedDelay);
      }
      if (onSiteDelay != null) {
        onSiteDelayMinutes.add(onSiteDelay);
      }
      final scoreLabel = _partnerDispatchScoreLabel(
        latestStatus: latest.status,
        acceptedDelayMinutes: acceptedDelay,
        onSiteDelayMinutes: onSiteDelay,
      );
      final scoreReason = _partnerDispatchScoreReason(
        latestStatus: latest.status,
        acceptedDelayMinutes: acceptedDelay,
        onSiteDelayMinutes: onSiteDelay,
      );
      chains.add(
        SovereignReportPartnerDispatchChain(
          dispatchId: entry.key,
          clientId: first.clientId,
          siteId: first.siteId,
          partnerLabel: first.partnerLabel,
          declarationCount: ordered.length,
          latestStatus: latest.status,
          latestOccurredAtUtc: latest.occurredAt.toUtc(),
          dispatchCreatedAtUtc: dispatchCreatedAtUtc,
          acceptedAtUtc:
              firstOccurrenceByStatus[PartnerDispatchStatus.accepted],
          onSiteAtUtc: firstOccurrenceByStatus[PartnerDispatchStatus.onSite],
          allClearAtUtc:
              firstOccurrenceByStatus[PartnerDispatchStatus.allClear],
          cancelledAtUtc:
              firstOccurrenceByStatus[PartnerDispatchStatus.cancelled],
          acceptedDelayMinutes: acceptedDelay,
          onSiteDelayMinutes: onSiteDelay,
          scoreLabel: scoreLabel,
          scoreReason: scoreReason,
          workflowSummary: _partnerWorkflowSummary(
            firstOccurrenceByStatus: firstOccurrenceByStatus,
            latestStatus: latest.status,
          ),
        ),
      );
    }
    chains.sort(
      (a, b) => b.latestOccurredAtUtc.compareTo(a.latestOccurredAtUtc),
    );
    final scopeBreakdowns = <SovereignReportPartnerScopeBreakdown>[];
    for (final entry in scopeDeclarations.entries) {
      final ordered = [...entry.value]
        ..sort((a, b) {
          final occurredAtCompare = a.occurredAt.compareTo(b.occurredAt);
          if (occurredAtCompare != 0) {
            return occurredAtCompare;
          }
          return a.sequence.compareTo(b.sequence);
        });
      final latest = ordered.last;
      final split = _partnerScopeSplit(entry.key);
      final dispatchIds = ordered
          .map((declaration) => declaration.dispatchId.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      scopeBreakdowns.add(
        SovereignReportPartnerScopeBreakdown(
          clientId: split.$1,
          siteId: split.$2,
          dispatchCount: dispatchIds.length,
          declarationCount: ordered.length,
          latestStatus: latest.status,
          latestOccurredAtUtc: latest.occurredAt.toUtc(),
          summaryLine:
              'Dispatches ${dispatchIds.length} • Declarations ${ordered.length} • Latest ${_partnerStatusLabel(latest.status)} @ ${_timestampLabel(latest.occurredAt.toUtc())}',
        ),
      );
    }
    scopeBreakdowns.sort((a, b) {
      final dispatchCompare = b.dispatchCount.compareTo(a.dispatchCount);
      if (dispatchCompare != 0) {
        return dispatchCompare;
      }
      return b.latestOccurredAtUtc.compareTo(a.latestOccurredAtUtc);
    });
    return SovereignReportPartnerProgression(
      dispatchCount: chains.length,
      declarationCount: declarations.length,
      acceptedCount: acceptedCount,
      onSiteCount: onSiteCount,
      allClearCount: allClearCount,
      cancelledCount: cancelledCount,
      workflowHeadline: _partnerWorkflowHeadline(chains),
      performanceHeadline: _partnerPerformanceHeadline(chains),
      slaHeadline: _partnerSlaHeadline(
        acceptedDelayMinutes: acceptedDelayMinutes,
        onSiteDelayMinutes: onSiteDelayMinutes,
      ),
      summaryLine:
          'Dispatches ${chains.length} • Declarations ${declarations.length} • Accept $acceptedCount • On site $onSiteCount • All clear $allClearCount • Cancelled $cancelledCount',
      scopeBreakdowns: scopeBreakdowns,
      scoreboardRows: _partnerScoreboardRows(chains),
      dispatchChains: chains,
    );
  }

  String _partnerScopeKey(String clientId, String siteId) {
    return '${clientId.trim()}::${siteId.trim()}';
  }

  (String, String) _partnerScopeSplit(String scopeKey) {
    final separator = scopeKey.indexOf('::');
    if (separator == -1) {
      return ('', '');
    }
    return (
      scopeKey.substring(0, separator).trim(),
      scopeKey.substring(separator + 2).trim(),
    );
  }

  String _partnerWorkflowHeadline(
    List<SovereignReportPartnerDispatchChain> chains,
  ) {
    if (chains.isEmpty) {
      return '';
    }
    final counts = <PartnerDispatchStatus, int>{};
    for (final chain in chains) {
      counts.update(
        chain.latestStatus,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final parts = <String>[];
    final allClearCount = counts[PartnerDispatchStatus.allClear] ?? 0;
    final onSiteCount = counts[PartnerDispatchStatus.onSite] ?? 0;
    final acceptedCount = counts[PartnerDispatchStatus.accepted] ?? 0;
    final cancelledCount = counts[PartnerDispatchStatus.cancelled] ?? 0;
    if (allClearCount > 0) {
      parts.add(
        allClearCount == 1
            ? '1 partner dispatch reached ALL CLEAR'
            : '$allClearCount partner dispatches reached ALL CLEAR',
      );
    }
    if (onSiteCount > 0) {
      parts.add(
        onSiteCount == 1
            ? '1 partner dispatch remains ON SITE'
            : '$onSiteCount partner dispatches remain ON SITE',
      );
    }
    if (acceptedCount > 0) {
      parts.add(
        acceptedCount == 1
            ? '1 partner dispatch is ACCEPTED'
            : '$acceptedCount partner dispatches are ACCEPTED',
      );
    }
    if (cancelledCount > 0) {
      parts.add(
        cancelledCount == 1
            ? '1 partner dispatch was CANCELLED'
            : '$cancelledCount partner dispatches were CANCELLED',
      );
    }
    return parts.join(' • ');
  }

  String _partnerPerformanceHeadline(
    List<SovereignReportPartnerDispatchChain> chains,
  ) {
    if (chains.isEmpty) {
      return '';
    }
    final counts = <String, int>{};
    for (final chain in chains) {
      final label = chain.scoreLabel.trim().toUpperCase();
      if (label.isEmpty) {
        continue;
      }
      counts.update(label, (value) => value + 1, ifAbsent: () => 1);
    }
    final orderedLabels = ['STRONG', 'ON TRACK', 'WATCH', 'CRITICAL'];
    final parts = <String>[];
    for (final label in orderedLabels) {
      final count = counts[label] ?? 0;
      if (count == 0) {
        continue;
      }
      final noun = switch (label) {
        'STRONG' => count == 1 ? 'strong response' : 'strong responses',
        'ON TRACK' => count == 1 ? 'on-track response' : 'on-track responses',
        'WATCH' => count == 1 ? 'watch response' : 'watch responses',
        'CRITICAL' => count == 1 ? 'critical response' : 'critical responses',
        _ => count == 1 ? 'response' : 'responses',
      };
      parts.add('$count $noun');
    }
    return parts.join(' • ');
  }

  String _partnerPerformanceHeadlineFromScoreboardRows(
    List<SovereignReportPartnerScoreboardRow> rows,
  ) {
    if (rows.isEmpty) {
      return '';
    }
    var strongCount = 0;
    var onTrackCount = 0;
    var watchCount = 0;
    var criticalCount = 0;
    for (final row in rows) {
      strongCount += row.strongCount;
      onTrackCount += row.onTrackCount;
      watchCount += row.watchCount;
      criticalCount += row.criticalCount;
    }
    final parts = <String>[];
    if (strongCount > 0) {
      parts.add(
        strongCount == 1
            ? '1 strong response'
            : '$strongCount strong responses',
      );
    }
    if (onTrackCount > 0) {
      parts.add(
        onTrackCount == 1
            ? '1 on-track response'
            : '$onTrackCount on-track responses',
      );
    }
    if (watchCount > 0) {
      parts.add(
        watchCount == 1 ? '1 watch response' : '$watchCount watch responses',
      );
    }
    if (criticalCount > 0) {
      parts.add(
        criticalCount == 1
            ? '1 critical response'
            : '$criticalCount critical responses',
      );
    }
    return parts.join(' • ');
  }

  List<SovereignReportPartnerScoreboardRow> _partnerScoreboardRows(
    List<SovereignReportPartnerDispatchChain> chains,
  ) {
    if (chains.isEmpty) {
      return const <SovereignReportPartnerScoreboardRow>[];
    }
    final grouped = <String, List<SovereignReportPartnerDispatchChain>>{};
    for (final chain in chains) {
      final key =
          '${chain.clientId.trim()}::${chain.siteId.trim()}::${chain.partnerLabel.trim().toUpperCase()}';
      grouped
          .putIfAbsent(key, () => <SovereignReportPartnerDispatchChain>[])
          .add(chain);
    }
    final rows = <SovereignReportPartnerScoreboardRow>[];
    for (final chainsForRow in grouped.values) {
      final first = chainsForRow.first;
      var strongCount = 0;
      var onTrackCount = 0;
      var watchCount = 0;
      var criticalCount = 0;
      final acceptedDelays = <double>[];
      final onSiteDelays = <double>[];
      for (final chain in chainsForRow) {
        switch (chain.scoreLabel.trim().toUpperCase()) {
          case 'STRONG':
            strongCount += 1;
          case 'ON TRACK':
            onTrackCount += 1;
          case 'WATCH':
            watchCount += 1;
          case 'CRITICAL':
            criticalCount += 1;
        }
        if (chain.acceptedDelayMinutes != null) {
          acceptedDelays.add(chain.acceptedDelayMinutes!);
        }
        if (chain.onSiteDelayMinutes != null) {
          onSiteDelays.add(chain.onSiteDelayMinutes!);
        }
      }
      final averageAcceptedDelayMinutes = _averageMinutes(acceptedDelays) ?? 0;
      final averageOnSiteDelayMinutes = _averageMinutes(onSiteDelays) ?? 0;
      rows.add(
        SovereignReportPartnerScoreboardRow(
          clientId: first.clientId,
          siteId: first.siteId,
          partnerLabel: first.partnerLabel,
          dispatchCount: chainsForRow.length,
          strongCount: strongCount,
          onTrackCount: onTrackCount,
          watchCount: watchCount,
          criticalCount: criticalCount,
          averageAcceptedDelayMinutes: double.parse(
            averageAcceptedDelayMinutes.toStringAsFixed(1),
          ),
          averageOnSiteDelayMinutes: double.parse(
            averageOnSiteDelayMinutes.toStringAsFixed(1),
          ),
          summaryLine:
              'Dispatches ${chainsForRow.length} • Strong $strongCount • On track $onTrackCount • Watch $watchCount • Critical $criticalCount • Avg accept ${averageAcceptedDelayMinutes.toStringAsFixed(1)}m • Avg on site ${averageOnSiteDelayMinutes.toStringAsFixed(1)}m',
        ),
      );
    }
    rows.sort((a, b) {
      final criticalCompare = b.criticalCount.compareTo(a.criticalCount);
      if (criticalCompare != 0) {
        return criticalCompare;
      }
      final dispatchCompare = b.dispatchCount.compareTo(a.dispatchCount);
      if (dispatchCompare != 0) {
        return dispatchCompare;
      }
      return a.partnerLabel.compareTo(b.partnerLabel);
    });
    return rows;
  }

  String _partnerWorkflowSummary({
    required Map<PartnerDispatchStatus, DateTime> firstOccurrenceByStatus,
    required PartnerDispatchStatus latestStatus,
  }) {
    final steps = <String>[];
    if (firstOccurrenceByStatus.containsKey(PartnerDispatchStatus.accepted)) {
      steps.add('ACCEPT');
    }
    if (firstOccurrenceByStatus.containsKey(PartnerDispatchStatus.onSite)) {
      steps.add('ON SITE');
    }
    if (firstOccurrenceByStatus.containsKey(PartnerDispatchStatus.allClear)) {
      steps.add('ALL CLEAR');
    }
    if (firstOccurrenceByStatus.containsKey(PartnerDispatchStatus.cancelled)) {
      steps.add('CANCELLED');
    }
    if (steps.isEmpty) {
      steps.add(_partnerStatusLabel(latestStatus));
    }
    return '${steps.join(' -> ')} (LATEST ${_partnerStatusLabel(latestStatus)})';
  }

  String _partnerSlaHeadline({
    required List<double> acceptedDelayMinutes,
    required List<double> onSiteDelayMinutes,
  }) {
    final parts = <String>[];
    final acceptedAverage = _averageMinutes(acceptedDelayMinutes);
    final onSiteAverage = _averageMinutes(onSiteDelayMinutes);
    if (acceptedAverage != null) {
      parts.add('Avg accept ${acceptedAverage.toStringAsFixed(1)}m');
    }
    if (onSiteAverage != null) {
      parts.add('Avg on site ${onSiteAverage.toStringAsFixed(1)}m');
    }
    return parts.join(' • ');
  }

  String _partnerSlaHeadlineFromScoreboardRows(
    List<SovereignReportPartnerScoreboardRow> rows,
  ) {
    if (rows.isEmpty) {
      return '';
    }
    var acceptedDelayWeight = 0;
    var acceptedDelayWeightedSum = 0.0;
    var onSiteDelayWeight = 0;
    var onSiteDelayWeightedSum = 0.0;
    for (final row in rows) {
      if (row.averageAcceptedDelayMinutes > 0 && row.dispatchCount > 0) {
        acceptedDelayWeight += row.dispatchCount;
        acceptedDelayWeightedSum +=
            row.averageAcceptedDelayMinutes * row.dispatchCount;
      }
      if (row.averageOnSiteDelayMinutes > 0 && row.dispatchCount > 0) {
        onSiteDelayWeight += row.dispatchCount;
        onSiteDelayWeightedSum +=
            row.averageOnSiteDelayMinutes * row.dispatchCount;
      }
    }
    final acceptedAverage = acceptedDelayWeight == 0
        ? null
        : acceptedDelayWeightedSum / acceptedDelayWeight;
    final onSiteAverage = onSiteDelayWeight == 0
        ? null
        : onSiteDelayWeightedSum / onSiteDelayWeight;
    final parts = <String>[];
    if (acceptedAverage != null) {
      parts.add('Avg accept ${acceptedAverage.toStringAsFixed(1)}m');
    }
    if (onSiteAverage != null) {
      parts.add('Avg on site ${onSiteAverage.toStringAsFixed(1)}m');
    }
    return parts.join(' • ');
  }

  String _partnerDispatchScoreLabel({
    required PartnerDispatchStatus latestStatus,
    required double? acceptedDelayMinutes,
    required double? onSiteDelayMinutes,
  }) {
    if (latestStatus == PartnerDispatchStatus.cancelled) {
      return 'CRITICAL';
    }
    if (latestStatus == PartnerDispatchStatus.allClear) {
      if ((acceptedDelayMinutes ?? double.infinity) <= 5 &&
          (onSiteDelayMinutes ?? double.infinity) <= 15) {
        return 'STRONG';
      }
      return 'WATCH';
    }
    if (latestStatus == PartnerDispatchStatus.onSite) {
      if ((acceptedDelayMinutes ?? double.infinity) <= 5 &&
          (onSiteDelayMinutes ?? double.infinity) <= 15) {
        return 'ON TRACK';
      }
      return 'WATCH';
    }
    return 'WATCH';
  }

  String _partnerDispatchScoreReason({
    required PartnerDispatchStatus latestStatus,
    required double? acceptedDelayMinutes,
    required double? onSiteDelayMinutes,
  }) {
    if (latestStatus == PartnerDispatchStatus.cancelled) {
      return 'Dispatch was cancelled before the partner completed the response chain.';
    }
    if (latestStatus == PartnerDispatchStatus.allClear) {
      if ((acceptedDelayMinutes ?? double.infinity) <= 5 &&
          (onSiteDelayMinutes ?? double.infinity) <= 15) {
        return 'Partner reached ALL CLEAR inside target acceptance and on-site windows.';
      }
      return 'Partner completed the response chain, but one or more response windows drifted beyond target.';
    }
    if (latestStatus == PartnerDispatchStatus.onSite) {
      if ((acceptedDelayMinutes ?? double.infinity) <= 5 &&
          (onSiteDelayMinutes ?? double.infinity) <= 15) {
        return 'Partner is on site inside target windows and the response remains active.';
      }
      return 'Partner is on site, but the approach timing drifted beyond target windows.';
    }
    return 'Partner acknowledged the dispatch, but on-site confirmation has not been declared yet.';
  }

  double? _partnerDelayMinutes(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) {
      return null;
    }
    final duration = endUtc.difference(startUtc);
    if (duration.isNegative) {
      return null;
    }
    return double.parse((duration.inSeconds / 60.0).toStringAsFixed(1));
  }

  double? _averageMinutes(List<double> values) {
    if (values.isEmpty) {
      return null;
    }
    return values.reduce((left, right) => left + right) / values.length;
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
        'workflowHeadline': report.vehicleWorkflowHeadline,
        'summaryLine': report.vehicleSummary,
        'scopeBreakdowns': report.vehicleScopeBreakdowns
            .map((scope) => scope.toJson())
            .toList(growable: false),
        'exceptionVisits': report.vehicleExceptionVisits
            .map((exception) => exception.toJson())
            .toList(growable: false),
      },
      'partnerProgression': {
        'dispatchCount': report.partnerDispatches,
        'declarationCount': report.partnerDeclarations,
        'acceptedCount': report.partnerAccepted,
        'onSiteCount': report.partnerOnSite,
        'allClearCount': report.partnerAllClear,
        'cancelledCount': report.partnerCancelled,
        'workflowHeadline': report.partnerWorkflowHeadline,
        'performanceHeadline': report.partnerPerformanceHeadline,
        'slaHeadline': report.partnerSlaHeadline,
        'summaryLine': report.partnerSummary,
        'scopeBreakdowns': report.partnerScopeBreakdowns
            .map((scope) => scope.toJson())
            .toList(growable: false),
        'scoreboardRows': report.partnerScoreboardRows
            .map((row) => row.toJson())
            .toList(growable: false),
        'scoreboardHistory': report.partnerScoreboardHistory
            .map((point) => point.toJson())
            .toList(growable: false),
        'trendRows': report.partnerTrendRows
            .map((row) => row.toJson())
            .toList(growable: false),
        'dispatchChains': report.partnerDispatchChains
            .map((chain) => chain.toJson())
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
      'vehicle_workflow_headline,"${report.vehicleWorkflowHeadline.replaceAll('"', '""')}"',
      'vehicle_summary,"${report.vehicleSummary.replaceAll('"', '""')}"',
      for (var i = 0; i < report.vehicleScopeBreakdowns.length; i++)
        'vehicle_scope_${i + 1},"${_vehicleScopeCsvSummary(report.vehicleScopeBreakdowns[i]).replaceAll('"', '""')}"',
      for (var i = 0; i < report.vehicleExceptionVisits.length; i++)
        'vehicle_exception_${i + 1},"${_vehicleExceptionCsvSummary(report.vehicleExceptionVisits[i]).replaceAll('"', '""')}"',
      'partner_dispatch_count,${report.partnerDispatches}',
      'partner_declaration_count,${report.partnerDeclarations}',
      'partner_accepted_count,${report.partnerAccepted}',
      'partner_on_site_count,${report.partnerOnSite}',
      'partner_all_clear_count,${report.partnerAllClear}',
      'partner_cancelled_count,${report.partnerCancelled}',
      'partner_workflow_headline,"${report.partnerWorkflowHeadline.replaceAll('"', '""')}"',
      'partner_performance_headline,"${report.partnerPerformanceHeadline.replaceAll('"', '""')}"',
      'partner_sla_headline,"${report.partnerSlaHeadline.replaceAll('"', '""')}"',
      'partner_summary,"${report.partnerSummary.replaceAll('"', '""')}"',
      for (var i = 0; i < report.partnerScopeBreakdowns.length; i++)
        'partner_scope_${i + 1},"${_partnerScopeCsvSummary(report.partnerScopeBreakdowns[i]).replaceAll('"', '""')}"',
      for (var i = 0; i < report.partnerScoreboardRows.length; i++)
        'partner_scoreboard_${i + 1},"${_partnerScoreboardCsvSummary(report.partnerScoreboardRows[i]).replaceAll('"', '""')}"',
      for (var i = 0; i < report.partnerScoreboardHistory.length; i++)
        'partner_scoreboard_history_${i + 1},"${_partnerScoreboardHistoryCsvSummary(report.partnerScoreboardHistory[i]).replaceAll('"', '""')}"',
      for (var i = 0; i < report.partnerTrendRows.length; i++)
        'partner_trend_${i + 1},"${_partnerTrendCsvSummary(report.partnerTrendRows[i]).replaceAll('"', '""')}"',
      for (var i = 0; i < report.partnerDispatchChains.length; i++)
        'partner_chain_${i + 1},"${_partnerChainCsvSummary(report.partnerDispatchChains[i]).replaceAll('"', '""')}"',
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

String _partnerStatusLabel(PartnerDispatchStatus status) {
  return switch (status) {
    PartnerDispatchStatus.accepted => 'ACCEPT',
    PartnerDispatchStatus.onSite => 'ON SITE',
    PartnerDispatchStatus.allClear => 'ALL CLEAR',
    PartnerDispatchStatus.cancelled => 'CANCELLED',
  };
}

Color _partnerStatusColor(PartnerDispatchStatus status) {
  return switch (status) {
    PartnerDispatchStatus.accepted => const Color(0xFF38BDF8),
    PartnerDispatchStatus.onSite => const Color(0xFFF59E0B),
    PartnerDispatchStatus.allClear => const Color(0xFF10B981),
    PartnerDispatchStatus.cancelled => const Color(0xFFEF4444),
  };
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
