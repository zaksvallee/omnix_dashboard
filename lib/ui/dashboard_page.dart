import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/dispatch_snapshot_file_service.dart';
import '../application/email_bridge_service.dart';
import '../application/morning_sovereign_report_service.dart';
import '../application/site_activity_intelligence_service.dart';
import '../application/site_activity_telegram_formatter.dart';
import '../application/text_share_service.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/decision_created.dart';
import '../domain/guard/guard_ops_event.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/intelligence/triage_policy.dart';
import '../domain/projection/operations_health_projection.dart';
import '../domain/store/in_memory_event_store.dart';
import 'onyx_surface.dart';

class DashboardPage extends StatelessWidget {
  static const _siteActivityService = SiteActivityIntelligenceService();
  final InMemoryEventStore eventStore;
  final bool guardSyncBackendEnabled;
  final bool guardSyncInFlight;
  final int guardSyncQueueDepth;
  final int guardPendingEvents;
  final int guardPendingMedia;
  final int guardFailedEvents;
  final int guardFailedMedia;
  final int guardOutcomePolicyDeniedCount;
  final String? guardOutcomePolicyDeniedLastReason;
  final int guardOutcomePolicyDenied24h;
  final int guardOutcomePolicyDenied7d;
  final List<DateTime> guardOutcomePolicyDeniedHistoryUtc;
  final int guardCoachingAckCount;
  final int guardCoachingSnoozeCount;
  final int guardCoachingSnoozeExpiryCount;
  final List<String> guardCoachingRecentHistory;
  final String? guardSyncStatusLabel;
  final DateTime? guardLastSuccessfulSyncAtUtc;
  final String? guardLastFailureReason;
  final VoidCallback? onOpenGuardSync;
  final VoidCallback? onClearGuardOutcomePolicyTelemetry;
  final int guardFailureAlertThreshold;
  final int guardQueuePressureAlertThreshold;
  final int guardStaleSyncAlertMinutes;
  final List<GuardOpsEvent> guardRecentEvents;
  final List<GuardOpsMediaUpload> guardRecentMedia;
  final SovereignReport? morningSovereignReport;
  final List<SovereignReport> morningSovereignReportHistory;
  final String? morningSovereignReportAutoStatusLabel;
  final Future<void> Function()? onGenerateMorningSovereignReport;
  final void Function(List<String> eventIds, String? selectedEventId)?
  onOpenEventsForScope;

  const DashboardPage({
    super.key,
    required this.eventStore,
    this.guardSyncBackendEnabled = false,
    this.guardSyncInFlight = false,
    this.guardSyncQueueDepth = 0,
    this.guardPendingEvents = 0,
    this.guardPendingMedia = 0,
    this.guardFailedEvents = 0,
    this.guardFailedMedia = 0,
    this.guardOutcomePolicyDeniedCount = 0,
    this.guardOutcomePolicyDeniedLastReason,
    this.guardOutcomePolicyDenied24h = 0,
    this.guardOutcomePolicyDenied7d = 0,
    this.guardOutcomePolicyDeniedHistoryUtc = const [],
    this.guardCoachingAckCount = 0,
    this.guardCoachingSnoozeCount = 0,
    this.guardCoachingSnoozeExpiryCount = 0,
    this.guardCoachingRecentHistory = const [],
    this.guardSyncStatusLabel,
    this.guardLastSuccessfulSyncAtUtc,
    this.guardLastFailureReason,
    this.onOpenGuardSync,
    this.onClearGuardOutcomePolicyTelemetry,
    this.guardFailureAlertThreshold = 1,
    this.guardQueuePressureAlertThreshold = 25,
    this.guardStaleSyncAlertMinutes = 10,
    this.guardRecentEvents = const [],
    this.guardRecentMedia = const [],
    this.morningSovereignReport,
    this.morningSovereignReportHistory = const [],
    this.morningSovereignReportAutoStatusLabel,
    this.onGenerateMorningSovereignReport,
    this.onOpenEventsForScope,
  });

  @override
  Widget build(BuildContext context) {
    final events = eventStore.allEvents();
    final snapshot = OperationsHealthProjection.build(events);
    final triage = _buildDashboardTriageSummary(events);
    final siteActivity = _siteActivityService.buildSnapshot(events: events);
    final threat = _threat(snapshot);

    return OnyxPageScaffold(
      child: Column(
        children: [
          _TopBar(snapshot: snapshot, threat: threat),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 980) {
                  return _CompactDashboard(
                    snapshot: snapshot,
                    triage: triage,
                    threat: threat,
                    guardSyncBackendEnabled: guardSyncBackendEnabled,
                    guardSyncInFlight: guardSyncInFlight,
                    guardSyncQueueDepth: guardSyncQueueDepth,
                    guardPendingEvents: guardPendingEvents,
                    guardPendingMedia: guardPendingMedia,
                    guardFailedEvents: guardFailedEvents,
                    guardFailedMedia: guardFailedMedia,
                    guardOutcomePolicyDeniedCount:
                        guardOutcomePolicyDeniedCount,
                    guardOutcomePolicyDeniedLastReason:
                        guardOutcomePolicyDeniedLastReason,
                    guardOutcomePolicyDenied24h: guardOutcomePolicyDenied24h,
                    guardOutcomePolicyDenied7d: guardOutcomePolicyDenied7d,
                    guardOutcomePolicyDeniedHistoryUtc:
                        guardOutcomePolicyDeniedHistoryUtc,
                    guardCoachingAckCount: guardCoachingAckCount,
                    guardCoachingSnoozeCount: guardCoachingSnoozeCount,
                    guardCoachingSnoozeExpiryCount:
                        guardCoachingSnoozeExpiryCount,
                    guardCoachingRecentHistory: guardCoachingRecentHistory,
                    guardSyncStatusLabel: guardSyncStatusLabel,
                    guardLastSuccessfulSyncAtUtc: guardLastSuccessfulSyncAtUtc,
                    guardLastFailureReason: guardLastFailureReason,
                    onOpenGuardSync: onOpenGuardSync,
                    onClearGuardOutcomePolicyTelemetry:
                        onClearGuardOutcomePolicyTelemetry,
                    guardFailureAlertThreshold: guardFailureAlertThreshold,
                    guardQueuePressureAlertThreshold:
                        guardQueuePressureAlertThreshold,
                    guardStaleSyncAlertMinutes: guardStaleSyncAlertMinutes,
                    guardRecentEvents: guardRecentEvents,
                    guardRecentMedia: guardRecentMedia,
                    morningSovereignReport: morningSovereignReport,
                    morningSovereignReportHistory:
                        morningSovereignReportHistory,
                    morningSovereignReportAutoStatusLabel:
                        morningSovereignReportAutoStatusLabel,
                    siteActivity: siteActivity,
                    onGenerateMorningSovereignReport:
                        onGenerateMorningSovereignReport,
                    onOpenEventsForScope: onOpenEventsForScope,
                  );
                }
                return _DesktopDashboard(
                  snapshot: snapshot,
                  triage: triage,
                  threat: threat,
                  guardSyncBackendEnabled: guardSyncBackendEnabled,
                  guardSyncInFlight: guardSyncInFlight,
                  guardSyncQueueDepth: guardSyncQueueDepth,
                  guardPendingEvents: guardPendingEvents,
                  guardPendingMedia: guardPendingMedia,
                  guardFailedEvents: guardFailedEvents,
                  guardFailedMedia: guardFailedMedia,
                  guardOutcomePolicyDeniedCount: guardOutcomePolicyDeniedCount,
                  guardOutcomePolicyDeniedLastReason:
                      guardOutcomePolicyDeniedLastReason,
                  guardOutcomePolicyDenied24h: guardOutcomePolicyDenied24h,
                  guardOutcomePolicyDenied7d: guardOutcomePolicyDenied7d,
                  guardOutcomePolicyDeniedHistoryUtc:
                      guardOutcomePolicyDeniedHistoryUtc,
                  guardCoachingAckCount: guardCoachingAckCount,
                  guardCoachingSnoozeCount: guardCoachingSnoozeCount,
                  guardCoachingSnoozeExpiryCount:
                      guardCoachingSnoozeExpiryCount,
                  guardCoachingRecentHistory: guardCoachingRecentHistory,
                  guardSyncStatusLabel: guardSyncStatusLabel,
                  guardLastSuccessfulSyncAtUtc: guardLastSuccessfulSyncAtUtc,
                  guardLastFailureReason: guardLastFailureReason,
                  onOpenGuardSync: onOpenGuardSync,
                  onClearGuardOutcomePolicyTelemetry:
                      onClearGuardOutcomePolicyTelemetry,
                  guardFailureAlertThreshold: guardFailureAlertThreshold,
                  guardQueuePressureAlertThreshold:
                      guardQueuePressureAlertThreshold,
                  guardStaleSyncAlertMinutes: guardStaleSyncAlertMinutes,
                  guardRecentEvents: guardRecentEvents,
                  guardRecentMedia: guardRecentMedia,
                  morningSovereignReport: morningSovereignReport,
                  morningSovereignReportHistory: morningSovereignReportHistory,
                  morningSovereignReportAutoStatusLabel:
                      morningSovereignReportAutoStatusLabel,
                  siteActivity: siteActivity,
                  onGenerateMorningSovereignReport:
                      onGenerateMorningSovereignReport,
                  onOpenEventsForScope: onOpenEventsForScope,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  _ThreatState _threat(OperationsHealthSnapshot snapshot) {
    if (snapshot.totalFailed > 0 || snapshot.controllerPressureIndex >= 80) {
      return const _ThreatState(
        label: 'CRITICAL',
        accent: Color(0xFFFF6A6F),
        softAccent: Color(0xFFFFC2B8),
      );
    }
    if (snapshot.controllerPressureIndex >= 60 || snapshot.totalDenied > 0) {
      return const _ThreatState(
        label: 'ELEVATED',
        accent: Color(0xFFFFB44D),
        softAccent: Color(0xFFFFE2B5),
      );
    }
    return const _ThreatState(
      label: 'STABLE',
      accent: Color(0xFF49D2FF),
      softAccent: Color(0xFFB7EEFF),
    );
  }
}

class _DashboardTriageSummary {
  final int advisoryCount;
  final int watchCount;
  final int dispatchCandidateCount;
  final int escalateCount;
  final String topSignalsSummary;

  const _DashboardTriageSummary({
    required this.advisoryCount,
    required this.watchCount,
    required this.dispatchCandidateCount,
    required this.escalateCount,
    required this.topSignalsSummary,
  });
}

_DashboardTriageSummary _buildDashboardTriageSummary(
  List<DispatchEvent> events,
) {
  const triagePolicy = IntelligenceTriagePolicy();
  final allIntel = events.whereType<IntelligenceReceived>().toList(
    growable: false,
  )..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  final decisions = events.whereType<DecisionCreated>().toList(growable: false);
  if (allIntel.isEmpty) {
    return const _DashboardTriageSummary(
      advisoryCount: 0,
      watchCount: 0,
      dispatchCandidateCount: 0,
      escalateCount: 0,
      topSignalsSummary: 'none',
    );
  }

  var advisoryCount = 0;
  var watchCount = 0;
  var dispatchCandidateCount = 0;
  var escalateCount = 0;
  final rationaleCounts = <String, int>{};

  for (final item in allIntel) {
    final assessment = triagePolicy.evaluateReceived(
      item: item,
      allIntel: allIntel,
      decisions: decisions,
    );
    switch (assessment.recommendation) {
      case IntelligenceRecommendation.advisory:
        advisoryCount += 1;
        break;
      case IntelligenceRecommendation.watch:
        watchCount += 1;
        break;
      case IntelligenceRecommendation.dispatchCandidate:
        dispatchCandidateCount += 1;
        break;
    }
    if (assessment.shouldEscalate) {
      escalateCount += 1;
    }
    for (final reason in assessment.rationale) {
      final key = reason.split(':').first.trim();
      if (key.isEmpty || key == 'recommendation') {
        continue;
      }
      rationaleCounts.update(key, (value) => value + 1, ifAbsent: () => 1);
    }
  }

  final topSignals = rationaleCounts.entries.toList(growable: false)
    ..sort((left, right) {
      final byCount = right.value.compareTo(left.value);
      if (byCount != 0) {
        return byCount;
      }
      return left.key.compareTo(right.key);
    });
  final topSignalsSummary = topSignals.isEmpty
      ? 'none'
      : topSignals
            .take(3)
            .map((entry) => '${entry.key} ${entry.value}')
            .join(', ');

  return _DashboardTriageSummary(
    advisoryCount: advisoryCount,
    watchCount: watchCount,
    dispatchCandidateCount: dispatchCandidateCount,
    escalateCount: escalateCount,
    topSignalsSummary: topSignalsSummary,
  );
}

class _DesktopDashboard extends StatelessWidget {
  final OperationsHealthSnapshot snapshot;
  final _DashboardTriageSummary triage;
  final _ThreatState threat;
  final bool guardSyncBackendEnabled;
  final bool guardSyncInFlight;
  final int guardSyncQueueDepth;
  final int guardPendingEvents;
  final int guardPendingMedia;
  final int guardFailedEvents;
  final int guardFailedMedia;
  final int guardOutcomePolicyDeniedCount;
  final String? guardOutcomePolicyDeniedLastReason;
  final int guardOutcomePolicyDenied24h;
  final int guardOutcomePolicyDenied7d;
  final List<DateTime> guardOutcomePolicyDeniedHistoryUtc;
  final int guardCoachingAckCount;
  final int guardCoachingSnoozeCount;
  final int guardCoachingSnoozeExpiryCount;
  final List<String> guardCoachingRecentHistory;
  final String? guardSyncStatusLabel;
  final DateTime? guardLastSuccessfulSyncAtUtc;
  final String? guardLastFailureReason;
  final VoidCallback? onOpenGuardSync;
  final VoidCallback? onClearGuardOutcomePolicyTelemetry;
  final int guardFailureAlertThreshold;
  final int guardQueuePressureAlertThreshold;
  final int guardStaleSyncAlertMinutes;
  final List<GuardOpsEvent> guardRecentEvents;
  final List<GuardOpsMediaUpload> guardRecentMedia;
  final SovereignReport? morningSovereignReport;
  final List<SovereignReport> morningSovereignReportHistory;
  final String? morningSovereignReportAutoStatusLabel;
  final SiteActivityIntelligenceSnapshot siteActivity;
  final Future<void> Function()? onGenerateMorningSovereignReport;
  final void Function(List<String> eventIds, String? selectedEventId)?
  onOpenEventsForScope;

  const _DesktopDashboard({
    required this.snapshot,
    required this.triage,
    required this.threat,
    required this.guardSyncBackendEnabled,
    required this.guardSyncInFlight,
    required this.guardSyncQueueDepth,
    required this.guardPendingEvents,
    required this.guardPendingMedia,
    required this.guardFailedEvents,
    required this.guardFailedMedia,
    required this.guardOutcomePolicyDeniedCount,
    required this.guardOutcomePolicyDeniedLastReason,
    required this.guardOutcomePolicyDenied24h,
    required this.guardOutcomePolicyDenied7d,
    required this.guardOutcomePolicyDeniedHistoryUtc,
    required this.guardCoachingAckCount,
    required this.guardCoachingSnoozeCount,
    required this.guardCoachingSnoozeExpiryCount,
    required this.guardCoachingRecentHistory,
    required this.guardSyncStatusLabel,
    required this.guardLastSuccessfulSyncAtUtc,
    required this.guardLastFailureReason,
    required this.onOpenGuardSync,
    required this.onClearGuardOutcomePolicyTelemetry,
    required this.guardFailureAlertThreshold,
    required this.guardQueuePressureAlertThreshold,
    required this.guardStaleSyncAlertMinutes,
    required this.guardRecentEvents,
    required this.guardRecentMedia,
    required this.morningSovereignReport,
    required this.morningSovereignReportHistory,
    required this.morningSovereignReportAutoStatusLabel,
    required this.siteActivity,
    required this.onGenerateMorningSovereignReport,
    required this.onOpenEventsForScope,
  });

  @override
  Widget build(BuildContext context) {
    final rightRail = _RightRail(
      snapshot: snapshot,
      threat: threat,
      guardSyncBackendEnabled: guardSyncBackendEnabled,
      guardSyncInFlight: guardSyncInFlight,
      guardSyncQueueDepth: guardSyncQueueDepth,
      guardPendingEvents: guardPendingEvents,
      guardPendingMedia: guardPendingMedia,
      guardFailedEvents: guardFailedEvents,
      guardFailedMedia: guardFailedMedia,
      guardOutcomePolicyDeniedCount: guardOutcomePolicyDeniedCount,
      guardOutcomePolicyDeniedLastReason: guardOutcomePolicyDeniedLastReason,
      guardOutcomePolicyDenied24h: guardOutcomePolicyDenied24h,
      guardOutcomePolicyDenied7d: guardOutcomePolicyDenied7d,
      guardOutcomePolicyDeniedHistoryUtc: guardOutcomePolicyDeniedHistoryUtc,
      guardCoachingAckCount: guardCoachingAckCount,
      guardCoachingSnoozeCount: guardCoachingSnoozeCount,
      guardCoachingSnoozeExpiryCount: guardCoachingSnoozeExpiryCount,
      guardCoachingRecentHistory: guardCoachingRecentHistory,
      guardSyncStatusLabel: guardSyncStatusLabel,
      guardLastSuccessfulSyncAtUtc: guardLastSuccessfulSyncAtUtc,
      guardLastFailureReason: guardLastFailureReason,
      onOpenGuardSync: onOpenGuardSync,
      onClearGuardOutcomePolicyTelemetry: onClearGuardOutcomePolicyTelemetry,
      guardFailureAlertThreshold: guardFailureAlertThreshold,
      guardQueuePressureAlertThreshold: guardQueuePressureAlertThreshold,
      guardStaleSyncAlertMinutes: guardStaleSyncAlertMinutes,
      guardRecentEvents: guardRecentEvents,
      guardRecentMedia: guardRecentMedia,
      morningSovereignReport: morningSovereignReport,
      morningSovereignReportHistory: morningSovereignReportHistory,
      morningSovereignReportAutoStatusLabel:
          morningSovereignReportAutoStatusLabel,
      siteActivity: siteActivity,
      onGenerateMorningSovereignReport: onGenerateMorningSovereignReport,
      onOpenEventsForScope: onOpenEventsForScope,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1540),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Keep the primary operational read path full-width on typical
              // desktop/laptop windows; only pin the right rail on very wide layouts.
              final stackRightRailBelow = constraints.maxWidth < 1320;

              return Column(
                children: [
                  _ExecutiveSummary(
                    snapshot: snapshot,
                    threat: threat,
                    triage: triage,
                  ),
                  const SizedBox(height: 10),
                  if (stackRightRailBelow) ...[
                    _SignalAndFeedGrid(snapshot: snapshot),
                    const SizedBox(height: 10),
                    _SitePosturePanel(snapshot: snapshot, threat: threat),
                    const SizedBox(height: 10),
                    rightRail,
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: Column(
                            children: [
                              _SignalAndFeedGrid(snapshot: snapshot),
                              const SizedBox(height: 10),
                              _SitePosturePanel(
                                snapshot: snapshot,
                                threat: threat,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(width: 336, child: rightRail),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CompactDashboard extends StatelessWidget {
  final OperationsHealthSnapshot snapshot;
  final _DashboardTriageSummary triage;
  final _ThreatState threat;
  final bool guardSyncBackendEnabled;
  final bool guardSyncInFlight;
  final int guardSyncQueueDepth;
  final int guardPendingEvents;
  final int guardPendingMedia;
  final int guardFailedEvents;
  final int guardFailedMedia;
  final int guardOutcomePolicyDeniedCount;
  final String? guardOutcomePolicyDeniedLastReason;
  final int guardOutcomePolicyDenied24h;
  final int guardOutcomePolicyDenied7d;
  final List<DateTime> guardOutcomePolicyDeniedHistoryUtc;
  final int guardCoachingAckCount;
  final int guardCoachingSnoozeCount;
  final int guardCoachingSnoozeExpiryCount;
  final List<String> guardCoachingRecentHistory;
  final String? guardSyncStatusLabel;
  final DateTime? guardLastSuccessfulSyncAtUtc;
  final String? guardLastFailureReason;
  final VoidCallback? onOpenGuardSync;
  final VoidCallback? onClearGuardOutcomePolicyTelemetry;
  final int guardFailureAlertThreshold;
  final int guardQueuePressureAlertThreshold;
  final int guardStaleSyncAlertMinutes;
  final List<GuardOpsEvent> guardRecentEvents;
  final List<GuardOpsMediaUpload> guardRecentMedia;
  final SovereignReport? morningSovereignReport;
  final List<SovereignReport> morningSovereignReportHistory;
  final String? morningSovereignReportAutoStatusLabel;
  final SiteActivityIntelligenceSnapshot siteActivity;
  final Future<void> Function()? onGenerateMorningSovereignReport;
  final void Function(List<String> eventIds, String? selectedEventId)?
  onOpenEventsForScope;

  const _CompactDashboard({
    required this.snapshot,
    required this.triage,
    required this.threat,
    required this.guardSyncBackendEnabled,
    required this.guardSyncInFlight,
    required this.guardSyncQueueDepth,
    required this.guardPendingEvents,
    required this.guardPendingMedia,
    required this.guardFailedEvents,
    required this.guardFailedMedia,
    required this.guardOutcomePolicyDeniedCount,
    required this.guardOutcomePolicyDeniedLastReason,
    required this.guardOutcomePolicyDenied24h,
    required this.guardOutcomePolicyDenied7d,
    required this.guardOutcomePolicyDeniedHistoryUtc,
    required this.guardCoachingAckCount,
    required this.guardCoachingSnoozeCount,
    required this.guardCoachingSnoozeExpiryCount,
    required this.guardCoachingRecentHistory,
    required this.guardSyncStatusLabel,
    required this.guardLastSuccessfulSyncAtUtc,
    required this.guardLastFailureReason,
    required this.onOpenGuardSync,
    required this.onClearGuardOutcomePolicyTelemetry,
    required this.guardFailureAlertThreshold,
    required this.guardQueuePressureAlertThreshold,
    required this.guardStaleSyncAlertMinutes,
    required this.guardRecentEvents,
    required this.guardRecentMedia,
    required this.morningSovereignReport,
    required this.morningSovereignReportHistory,
    required this.morningSovereignReportAutoStatusLabel,
    required this.siteActivity,
    required this.onGenerateMorningSovereignReport,
    required this.onOpenEventsForScope,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _ExecutiveSummary(snapshot: snapshot, threat: threat, triage: triage),
        const SizedBox(height: 10),
        _SignalAndFeedGrid(snapshot: snapshot),
        const SizedBox(height: 12),
        _SitePosturePanel(snapshot: snapshot, threat: threat),
        const SizedBox(height: 12),
        _RightRail(
          snapshot: snapshot,
          threat: threat,
          guardSyncBackendEnabled: guardSyncBackendEnabled,
          guardSyncInFlight: guardSyncInFlight,
          guardSyncQueueDepth: guardSyncQueueDepth,
          guardPendingEvents: guardPendingEvents,
          guardPendingMedia: guardPendingMedia,
          guardFailedEvents: guardFailedEvents,
          guardFailedMedia: guardFailedMedia,
          guardOutcomePolicyDeniedCount: guardOutcomePolicyDeniedCount,
          guardOutcomePolicyDeniedLastReason:
              guardOutcomePolicyDeniedLastReason,
          guardOutcomePolicyDenied24h: guardOutcomePolicyDenied24h,
          guardOutcomePolicyDenied7d: guardOutcomePolicyDenied7d,
          guardOutcomePolicyDeniedHistoryUtc:
              guardOutcomePolicyDeniedHistoryUtc,
          guardCoachingAckCount: guardCoachingAckCount,
          guardCoachingSnoozeCount: guardCoachingSnoozeCount,
          guardCoachingSnoozeExpiryCount: guardCoachingSnoozeExpiryCount,
          guardCoachingRecentHistory: guardCoachingRecentHistory,
          guardSyncStatusLabel: guardSyncStatusLabel,
          guardLastSuccessfulSyncAtUtc: guardLastSuccessfulSyncAtUtc,
          guardLastFailureReason: guardLastFailureReason,
          onOpenGuardSync: onOpenGuardSync,
          onClearGuardOutcomePolicyTelemetry:
              onClearGuardOutcomePolicyTelemetry,
          guardFailureAlertThreshold: guardFailureAlertThreshold,
          guardQueuePressureAlertThreshold: guardQueuePressureAlertThreshold,
          guardStaleSyncAlertMinutes: guardStaleSyncAlertMinutes,
          guardRecentEvents: guardRecentEvents,
          guardRecentMedia: guardRecentMedia,
          morningSovereignReport: morningSovereignReport,
          morningSovereignReportHistory: morningSovereignReportHistory,
          morningSovereignReportAutoStatusLabel:
              morningSovereignReportAutoStatusLabel,
          siteActivity: siteActivity,
          onGenerateMorningSovereignReport: onGenerateMorningSovereignReport,
          onOpenEventsForScope: onOpenEventsForScope,
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final OperationsHealthSnapshot snapshot;
  final _ThreatState threat;

  const _TopBar({required this.snapshot, required this.threat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0D14),
        border: Border(bottom: BorderSide(color: Color(0xFF24354A))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1200;
          final headerTitle = Text(
            'Command Dashboard',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE8F1FF),
              fontSize: compact ? 22 : 26,
              fontWeight: FontWeight.w700,
            ),
          );
          final headerSubtitle = Text(
            'Real-time operational control • AI-powered human-parallel execution.',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          );
          final statusChip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: threat.accent.withValues(alpha: 0.8)),
              color: threat.accent.withValues(alpha: 0.12),
            ),
            child: Text(
              threat.label,
              style: GoogleFonts.rajdhani(
                color: threat.accent,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                fontSize: 16,
              ),
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerTitle,
                const SizedBox(height: 2),
                headerSubtitle,
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeaderStat(
                      label: 'Last Event',
                      value: _formatTimestamp(snapshot.lastEventAtUtc),
                    ),
                    _HeaderStat(
                      label: 'Pressure',
                      value: snapshot.controllerPressureIndex.toStringAsFixed(
                        1,
                      ),
                    ),
                    statusChip,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerTitle,
                    const SizedBox(height: 2),
                    headerSubtitle,
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _HeaderStat(
                label: 'Last Event',
                value: _formatTimestamp(snapshot.lastEventAtUtc),
              ),
              const SizedBox(width: 8),
              _HeaderStat(
                label: 'Pressure',
                value: snapshot.controllerPressureIndex.toStringAsFixed(1),
              ),
              const SizedBox(width: 8),
              statusChip,
            ],
          );
        },
      ),
    );
  }
}

class _ExecutiveSummary extends StatelessWidget {
  final OperationsHealthSnapshot snapshot;
  final _ThreatState threat;
  final _DashboardTriageSummary triage;

  const _ExecutiveSummary({
    required this.snapshot,
    required this.threat,
    required this.triage,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1200;
        return _DashboardCard(
          title: 'KPI Band',
          subtitle: 'Live operational indicators for command decisions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF223244)),
                  color: const Color(0xFF0E1A2B),
                ),
                child: Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    _SummaryStripItem(
                      label: 'Active Incidents',
                      value: snapshot.totalDecisions.toString(),
                      helper: '${snapshot.totalFailed} failed',
                    ),
                    _SummaryStripItem(
                      label: 'Guards On-Duty',
                      value: snapshot.totalCheckIns.toString(),
                      helper: '${snapshot.totalPatrols} patrols',
                    ),
                    _SummaryStripItem(
                      label: 'Response Time',
                      value:
                          '${snapshot.averageResponseMinutes.toStringAsFixed(1)}m',
                      helper: 'Average',
                    ),
                    _SummaryStripItem(
                      label: 'Triage Posture',
                      value: threat.label,
                      helper:
                          'Pressure ${snapshot.controllerPressureIndex.toStringAsFixed(1)}',
                      helperColor: threat.accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (compact) ...[
                _KpiBandTile(
                  label: 'Average Response',
                  value:
                      '${snapshot.averageResponseMinutes.toStringAsFixed(1)} min',
                  helper: 'Across all arrived dispatches',
                ),
                const SizedBox(height: 8),
                _KpiBandTile(
                  label: 'High-Risk Intel',
                  value: snapshot.highRiskIntelligence.toString(),
                  helper: 'Signals above 70 risk',
                ),
                const SizedBox(height: 8),
                _KpiBandTile(
                  label: 'Field Activity',
                  value:
                      '${snapshot.totalCheckIns} check-ins • ${snapshot.totalPatrols} patrols',
                  helper: 'Current field movement',
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: _KpiBandTile(
                        label: 'Average Response',
                        value:
                            '${snapshot.averageResponseMinutes.toStringAsFixed(1)} min',
                        helper: 'Across all arrived dispatches',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _KpiBandTile(
                        label: 'High-Risk Intel',
                        value: snapshot.highRiskIntelligence.toString(),
                        helper: 'Signals above 70 risk',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _KpiBandTile(
                        label: 'Field Activity',
                        value:
                            '${snapshot.totalCheckIns} check-ins • ${snapshot.totalPatrols} patrols',
                        helper: 'Current field movement',
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              _KpiBandTile(
                label: 'Triage Posture',
                value:
                    'A ${triage.advisoryCount} • W ${triage.watchCount} • DC ${triage.dispatchCandidateCount} • Esc ${triage.escalateCount}',
                helper: 'Top triage signals: ${triage.topSignalsSummary}',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryStripItem extends StatelessWidget {
  final String label;
  final String value;
  final String helper;
  final Color helperColor;

  const _SummaryStripItem({
    required this.label,
    required this.value,
    required this.helper,
    this.helperColor = const Color(0xFF90A7C5),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 206,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF8FA6C5),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE8F2FF),
              fontSize: 38,
              height: 0.88,
              fontWeight: FontWeight.w700,
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
}

class _SignalAndFeedGrid extends StatelessWidget {
  final OperationsHealthSnapshot snapshot;

  const _SignalAndFeedGrid({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final visibleSignals = snapshot.liveSignals.take(8).toList(growable: false);
    final visibleDispatchFeed = snapshot.dispatchFeed
        .take(8)
        .toList(growable: false);
    final hiddenSignals = snapshot.liveSignals.length - visibleSignals.length;
    final hiddenDispatches =
        snapshot.dispatchFeed.length - visibleDispatchFeed.length;

    final liveSignalsCard = _DashboardCard(
      title: 'Live Signals',
      subtitle:
          'Recent intelligence, patrol, and field confirmations • ${snapshot.liveSignals.length} total',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in visibleSignals) ...[
            _TimelineRow(accent: const Color(0xFF57C8FF), label: row),
            const SizedBox(height: 8),
          ],
          if (snapshot.liveSignals.isEmpty)
            const _MutedLabel(label: 'No live signals yet.')
          else if (hiddenSignals > 0)
            OnyxTruncationHint(
              visibleCount: visibleSignals.length,
              totalCount: snapshot.liveSignals.length,
              subject: 'signals',
              hiddenDescriptor: 'older signals',
            ),
        ],
      ),
    );
    final dispatchFeedCard = _DashboardCard(
      title: 'Dispatch Feed',
      subtitle:
          'Readable dispatch outcomes with quick priority color • ${snapshot.dispatchFeed.length} total',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in visibleDispatchFeed) ...[
            _DispatchFeedRow(label: row),
            const SizedBox(height: 6),
          ],
          if (snapshot.dispatchFeed.isEmpty)
            const _MutedLabel(label: 'No dispatch events yet.')
          else if (hiddenDispatches > 0)
            OnyxTruncationHint(
              visibleCount: visibleDispatchFeed.length,
              totalCount: snapshot.dispatchFeed.length,
              subject: 'dispatch rows',
              hiddenDescriptor: 'older rows',
            ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1200) {
          return Column(
            children: [
              liveSignalsCard,
              const SizedBox(height: 10),
              dispatchFeedCard,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: liveSignalsCard),
            const SizedBox(width: 10),
            Expanded(child: dispatchFeedCard),
          ],
        );
      },
    );
  }
}

class _SitePosturePanel extends StatelessWidget {
  final OperationsHealthSnapshot snapshot;
  final _ThreatState threat;

  const _SitePosturePanel({required this.snapshot, required this.threat});

  @override
  Widget build(BuildContext context) {
    final rankedSites = [...snapshot.sites]
      ..sort(
        (a, b) => (b.activeDispatches + b.failedCount + b.deniedCount)
            .compareTo(a.activeDispatches + a.failedCount + a.deniedCount),
      );

    return _DashboardCard(
      title: 'Site Posture',
      subtitle:
          'Security status by operational site • ${rankedSites.length} total sites',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final site in rankedSites.take(6)) ...[
            _SiteRow(site: site, threat: threat),
            const SizedBox(height: 10),
          ],
          if (rankedSites.isEmpty)
            const _MutedLabel(label: 'No site posture data available.'),
          if (rankedSites.length > 6)
            OnyxTruncationHint(
              visibleCount: 6,
              totalCount: rankedSites.length,
              subject: 'sites by operational load',
              hiddenDescriptor: 'additional sites',
            ),
        ],
      ),
    );
  }
}

class _RightRail extends StatelessWidget {
  static const _snapshotFiles = DispatchSnapshotFileService();
  static const _textShare = TextShareService();
  static const _emailBridge = EmailBridgeService();
  static const _siteActivityTelegram = SiteActivityTelegramFormatter();

  final OperationsHealthSnapshot snapshot;
  final _ThreatState threat;
  final bool guardSyncBackendEnabled;
  final bool guardSyncInFlight;
  final int guardSyncQueueDepth;
  final int guardPendingEvents;
  final int guardPendingMedia;
  final int guardFailedEvents;
  final int guardFailedMedia;
  final int guardOutcomePolicyDeniedCount;
  final String? guardOutcomePolicyDeniedLastReason;
  final int guardOutcomePolicyDenied24h;
  final int guardOutcomePolicyDenied7d;
  final List<DateTime> guardOutcomePolicyDeniedHistoryUtc;
  final int guardCoachingAckCount;
  final int guardCoachingSnoozeCount;
  final int guardCoachingSnoozeExpiryCount;
  final List<String> guardCoachingRecentHistory;
  final String? guardSyncStatusLabel;
  final DateTime? guardLastSuccessfulSyncAtUtc;
  final String? guardLastFailureReason;
  final VoidCallback? onOpenGuardSync;
  final VoidCallback? onClearGuardOutcomePolicyTelemetry;
  final int guardFailureAlertThreshold;
  final int guardQueuePressureAlertThreshold;
  final int guardStaleSyncAlertMinutes;
  final List<GuardOpsEvent> guardRecentEvents;
  final List<GuardOpsMediaUpload> guardRecentMedia;
  final SovereignReport? morningSovereignReport;
  final List<SovereignReport> morningSovereignReportHistory;
  final String? morningSovereignReportAutoStatusLabel;
  final SiteActivityIntelligenceSnapshot siteActivity;
  final Future<void> Function()? onGenerateMorningSovereignReport;
  final void Function(List<String> eventIds, String? selectedEventId)?
  onOpenEventsForScope;

  const _RightRail({
    required this.snapshot,
    required this.threat,
    required this.guardSyncBackendEnabled,
    required this.guardSyncInFlight,
    required this.guardSyncQueueDepth,
    required this.guardPendingEvents,
    required this.guardPendingMedia,
    required this.guardFailedEvents,
    required this.guardFailedMedia,
    required this.guardOutcomePolicyDeniedCount,
    required this.guardOutcomePolicyDeniedLastReason,
    required this.guardOutcomePolicyDenied24h,
    required this.guardOutcomePolicyDenied7d,
    required this.guardOutcomePolicyDeniedHistoryUtc,
    required this.guardCoachingAckCount,
    required this.guardCoachingSnoozeCount,
    required this.guardCoachingSnoozeExpiryCount,
    required this.guardCoachingRecentHistory,
    required this.guardSyncStatusLabel,
    required this.guardLastSuccessfulSyncAtUtc,
    required this.guardLastFailureReason,
    required this.onOpenGuardSync,
    required this.onClearGuardOutcomePolicyTelemetry,
    required this.guardFailureAlertThreshold,
    required this.guardQueuePressureAlertThreshold,
    required this.guardStaleSyncAlertMinutes,
    required this.guardRecentEvents,
    required this.guardRecentMedia,
    required this.morningSovereignReport,
    required this.morningSovereignReportHistory,
    required this.morningSovereignReportAutoStatusLabel,
    required this.siteActivity,
    required this.onGenerateMorningSovereignReport,
    required this.onOpenEventsForScope,
  });

  String _guardFailureTraceClipboard(
    List<String> recentFailureTraces,
    String? lastFailureReason,
  ) {
    final lines = <String>[
      'Guard Sync Failure Trace',
      if (lastFailureReason != null && lastFailureReason.trim().isNotEmpty)
        'Last failure: ${lastFailureReason.trim()}',
      if (recentFailureTraces.isNotEmpty) ...[
        'Recent failures:',
        ...recentFailureTraces,
      ] else
        'No recent failure trace.',
    ];
    return lines.join('\n');
  }

  _ReceiptPolicyTrend? _receiptPolicyTrendFor(SovereignReport report) {
    final baselineReports =
        morningSovereignReportHistory
            .where((item) => !_isSameSovereignReport(item, report))
            .toList(growable: false)
          ..sort(
            (left, right) =>
                right.generatedAtUtc.compareTo(left.generatedAtUtc),
          );
    if (baselineReports.isEmpty) {
      return null;
    }
    final baseline = baselineReports
        .take(3)
        .map((item) => item.receiptPolicy)
        .toList(growable: false);
    if (baseline.isEmpty) {
      return null;
    }
    final currentScore = _receiptPolicySeverityScore(report.receiptPolicy);
    final baselineScore =
        baseline
            .map(_receiptPolicySeverityScore)
            .reduce((left, right) => left + right) /
        baseline.length;
    final delta = currentScore - baselineScore;
    if (delta >= 0.75) {
      return _ReceiptPolicyTrend(
        label: 'SLIPPING',
        summary: _slippingReceiptPolicySummary(report.receiptPolicy, baseline),
      );
    }
    if (delta <= -0.75) {
      return _ReceiptPolicyTrend(
        label: 'IMPROVING',
        summary: _improvingReceiptPolicySummary(report.receiptPolicy, baseline),
      );
    }
    return _ReceiptPolicyTrend(
      label: 'STABLE',
      summary: _stableReceiptPolicySummary(report.receiptPolicy, baseline),
    );
  }

  _ReceiptPolicyTrend? _receiptInvestigationTrendFor(SovereignReport report) {
    final baselineReports =
        morningSovereignReportHistory
            .where((item) => !_isSameSovereignReport(item, report))
            .toList(growable: false)
          ..sort(
            (left, right) =>
                right.generatedAtUtc.compareTo(left.generatedAtUtc),
          );
    if (baselineReports.isEmpty) {
      return null;
    }
    final baseline = baselineReports
        .take(3)
        .map((item) => item.receiptPolicy)
        .toList(growable: false);
    if (baseline.isEmpty) {
      return null;
    }
    final currentGovernance = report.receiptPolicy.governanceHandoffReports
        .toDouble();
    final baselineGovernance =
        baseline
            .map((item) => item.governanceHandoffReports)
            .reduce((left, right) => left + right) /
        baseline.length;
    final delta = currentGovernance - baselineGovernance;
    if (delta >= 0.5) {
      return _ReceiptPolicyTrend(
        label: 'OVERSIGHT RISING',
        summary: _risingReceiptInvestigationSummary(
          report.receiptPolicy,
          baseline,
        ),
      );
    }
    if (delta <= -0.5) {
      return _ReceiptPolicyTrend(
        label: 'OVERSIGHT EASING',
        summary: _easingReceiptInvestigationSummary(
          report.receiptPolicy,
          baseline,
        ),
      );
    }
    return _ReceiptPolicyTrend(
      label: 'STABLE',
      summary: _stableReceiptInvestigationSummary(
        report.receiptPolicy,
        baseline,
      ),
    );
  }

  _ReceiptPolicyTrend? _siteActivityTrendFor(
    SovereignReport report,
    SiteActivityIntelligenceSnapshot currentActivity,
  ) {
    final baselineReports =
        morningSovereignReportHistory
            .where((item) => !_isSameSovereignReport(item, report))
            .toList(growable: false)
          ..sort(
            (left, right) =>
                right.generatedAtUtc.compareTo(left.generatedAtUtc),
          );
    if (baselineReports.isEmpty) {
      return null;
    }
    final baseline = baselineReports
        .take(3)
        .map((item) => item.siteActivity)
        .toList(growable: false);
    if (baseline.isEmpty) {
      return null;
    }
    final currentPressure =
        (currentActivity.flaggedIdentitySignals * 2.0) +
        (currentActivity.unknownPersonSignals +
            currentActivity.unknownVehicleSignals) +
        currentActivity.longPresenceSignals +
        (currentActivity.guardInteractionSignals * 0.5);
    final baselinePressure =
        baseline
            .map(
              (item) =>
                  (item.flaggedIdentitySignals * 2.0) +
                  item.unknownSignals +
                  item.longPresenceSignals +
                  (item.guardInteractionSignals * 0.5),
            )
            .reduce((left, right) => left + right) /
        baseline.length;
    final delta = currentPressure - baselinePressure;
    if (delta >= 1.0) {
      return _ReceiptPolicyTrend(
        label: 'ACTIVITY RISING',
        summary: _risingSiteActivitySummary(currentActivity, baseline),
      );
    }
    if (delta <= -1.0) {
      return _ReceiptPolicyTrend(
        label: 'ACTIVITY EASING',
        summary: _easingSiteActivitySummary(currentActivity, baseline),
      );
    }
    return _ReceiptPolicyTrend(
      label: 'STABLE',
      summary: _stableSiteActivitySummary(currentActivity, baseline),
    );
  }

  bool _isSameSovereignReport(SovereignReport left, SovereignReport right) {
    return left.generatedAtUtc == right.generatedAtUtc &&
        left.shiftWindowEndUtc == right.shiftWindowEndUtc &&
        left.date == right.date;
  }

  double _receiptPolicySeverityScore(SovereignReportReceiptPolicy policy) {
    if (policy.generatedReports <= 0) {
      return 0;
    }
    final omittedWeight =
        policy.reportsWithOmittedSections +
        policy.omittedAiDecisionLogReports +
        policy.omittedGuardMetricsReports;
    final brandingWeight =
        (policy.customBrandingOverrideReports * 2) +
        policy.defaultPartnerBrandingReports;
    return ((policy.legacyConfigurationReports * 3) + (omittedWeight * 2)) /
            policy.generatedReports +
        (brandingWeight / policy.generatedReports);
  }

  String _slippingReceiptPolicySummary(
    SovereignReportReceiptPolicy current,
    List<SovereignReportReceiptPolicy> baseline,
  ) {
    final baselineLegacy = baseline.fold<int>(
      0,
      (value, item) => value + item.legacyConfigurationReports,
    );
    final baselineOmitted = baseline.fold<int>(
      0,
      (value, item) => value + item.reportsWithOmittedSections,
    );
    if (current.legacyConfigurationReports > 0 && baselineLegacy == 0) {
      return 'Latest receipt fell back to legacy policy capture.';
    }
    final baselineCustomBranding = baseline.fold<int>(
      0,
      (value, item) => value + item.customBrandingOverrideReports,
    );
    if (current.customBrandingOverrideReports > baselineCustomBranding) {
      return 'Latest receipts introduced more custom branding overrides than recent baseline.';
    }
    if (current.reportsWithOmittedSections > baselineOmitted) {
      return 'Latest receipts omitted more sections than recent baseline.';
    }
    return 'Latest receipt posture weakened against recent policy baseline.';
  }

  String _improvingReceiptPolicySummary(
    SovereignReportReceiptPolicy current,
    List<SovereignReportReceiptPolicy> baseline,
  ) {
    final baselineLegacy = baseline.fold<int>(
      0,
      (value, item) => value + item.legacyConfigurationReports,
    );
    final baselineOmitted = baseline.fold<int>(
      0,
      (value, item) => value + item.reportsWithOmittedSections,
    );
    if (current.legacyConfigurationReports == 0 &&
        current.reportsWithOmittedSections == 0 &&
        (baselineLegacy > 0 || baselineOmitted > 0)) {
      return 'Latest receipt returned to full tracked policy.';
    }
    final baselineCustomBranding = baseline.fold<int>(
      0,
      (value, item) => value + item.customBrandingOverrideReports,
    );
    if (current.customBrandingOverrideReports == 0 &&
        baselineCustomBranding > 0) {
      return 'Latest receipts returned from custom branding overrides to baseline branding.';
    }
    return 'Latest receipt posture improved against recent policy baseline.';
  }

  String _stableReceiptPolicySummary(
    SovereignReportReceiptPolicy current,
    List<SovereignReportReceiptPolicy> baseline,
  ) {
    final baselineGenerated = baseline.fold<int>(
      0,
      (value, item) => value + item.generatedReports,
    );
    if (baselineGenerated <= 0 && current.generatedReports <= 0) {
      return 'No recent client-facing receipts to compare.';
    }
    if (current.legacyConfigurationReports > 0) {
      return 'Legacy policy capture remains in line with recent shifts.';
    }
    if (current.reportsWithOmittedSections > 0) {
      return 'Latest omission posture held close to recent policy baseline.';
    }
    return 'Latest receipts held close to recent policy baseline.';
  }

  String _risingReceiptInvestigationSummary(
    SovereignReportReceiptPolicy current,
    List<SovereignReportReceiptPolicy> baseline,
  ) {
    final baselineGovernance = baseline.fold<int>(
      0,
      (value, item) => value + item.governanceHandoffReports,
    );
    if (current.governanceHandoffReports > 0 && baselineGovernance == 0) {
      return 'Latest receipt reviews introduced Governance handoffs above recent routine baseline.';
    }
    return 'Governance-opened receipt reviews increased against recent shifts.';
  }

  String _easingReceiptInvestigationSummary(
    SovereignReportReceiptPolicy current,
    List<SovereignReportReceiptPolicy> baseline,
  ) {
    final baselineGovernance = baseline.fold<int>(
      0,
      (value, item) => value + item.governanceHandoffReports,
    );
    if (current.governanceHandoffReports == 0 && baselineGovernance > 0) {
      return 'Latest receipt reviews returned to routine handling with no Governance handoffs.';
    }
    return 'Governance-opened receipt reviews eased against recent shifts.';
  }

  String _stableReceiptInvestigationSummary(
    SovereignReportReceiptPolicy current,
    List<SovereignReportReceiptPolicy> baseline,
  ) {
    final baselineGenerated = baseline.fold<int>(
      0,
      (value, item) => value + item.generatedReports,
    );
    if (baselineGenerated <= 0 && current.generatedReports <= 0) {
      return 'No recent receipt investigations to compare.';
    }
    return 'Receipt investigation provenance held close to recent baseline.';
  }

  String _risingSiteActivitySummary(
    SiteActivityIntelligenceSnapshot current,
    List<SovereignReportSiteActivity> baseline,
  ) {
    final baselineFlagged = baseline.fold<int>(
      0,
      (value, item) => value + item.flaggedIdentitySignals,
    );
    if (current.flaggedIdentitySignals > 0 && baselineFlagged == 0) {
      return 'Flagged identity traffic appeared above the recent site baseline.';
    }
    return 'Unknown or flagged site activity increased against recent shifts.';
  }

  String _easingSiteActivitySummary(
    SiteActivityIntelligenceSnapshot current,
    List<SovereignReportSiteActivity> baseline,
  ) {
    final baselineUnknown = baseline.fold<int>(
      0,
      (value, item) => value + item.unknownSignals,
    );
    if ((current.unknownPersonSignals + current.unknownVehicleSignals) == 0 &&
        baselineUnknown > 0) {
      return 'Site activity returned to a cleaner flow with no unknown signals.';
    }
    return 'Site activity pressure eased against recent shifts.';
  }

  String _stableSiteActivitySummary(
    SiteActivityIntelligenceSnapshot current,
    List<SovereignReportSiteActivity> baseline,
  ) {
    final baselineSignals = baseline.fold<int>(
      0,
      (value, item) => value + item.totalSignals,
    );
    if (baselineSignals <= 0 && current.totalSignals <= 0) {
      return 'No recent site activity to compare.';
    }
    return 'Site activity truth is holding close to recent baseline.';
  }

  String _receiptPolicyRailSummary(SovereignReportReceiptPolicy policy) {
    final parts = <String>[
      if (policy.executiveSummary.trim().isNotEmpty)
        policy.executiveSummary
      else if (policy.headline.trim().isNotEmpty)
        policy.headline
      else if (policy.summaryLine.trim().isNotEmpty)
        policy.summaryLine,
      if (policy.brandingExecutiveSummary.trim().isNotEmpty)
        policy.brandingExecutiveSummary,
      if (policy.investigationExecutiveSummary.trim().isNotEmpty)
        policy.investigationExecutiveSummary,
    ]..removeWhere((part) => part.trim().isEmpty);
    return parts.join(' • ');
  }

  String _receiptInvestigationRailSummary(SovereignReportReceiptPolicy policy) {
    final parts = <String>[
      if (policy.investigationExecutiveSummary.trim().isNotEmpty)
        policy.investigationExecutiveSummary
      else
        'Governance ${policy.governanceHandoffReports} • Routine ${policy.routineReviewReports}',
      if (policy.latestInvestigationSummary.trim().isNotEmpty)
        policy.latestInvestigationSummary,
    ]..removeWhere((part) => part.trim().isEmpty);
    return parts.join(' • ');
  }

  String _guardFailureTraceText(
    List<String> recentFailureTraces,
    String? lastFailureReason,
  ) => _guardFailureTraceClipboard(recentFailureTraces, lastFailureReason);

  String _guardPolicyTelemetryJson() {
    final deniedEvents = [...guardOutcomePolicyDeniedHistoryUtc]
      ..sort((a, b) => b.compareTo(a));
    return const JsonEncoder.withIndent('  ').convert({
      'policyDenied': {
        'total': guardOutcomePolicyDeniedCount,
        'window24h': guardOutcomePolicyDenied24h,
        'window7d': guardOutcomePolicyDenied7d,
        'lastReason': guardOutcomePolicyDeniedLastReason,
        'deniedAtUtc': deniedEvents
            .map((entry) => entry.toUtc().toIso8601String())
            .toList(growable: false),
      },
    });
  }

  String _siteActivityTruthJson() {
    final sovereignReport = morningSovereignReport;
    final siteActivityTrend = sovereignReport == null
        ? null
        : _siteActivityTrendFor(sovereignReport, siteActivity);
    return const JsonEncoder.withIndent('  ').convert({
      'scope': {
        'reportDate': sovereignReport?.date,
        'generatedAtUtc': sovereignReport?.generatedAtUtc.toIso8601String(),
      },
      'siteActivity': {
        'totalSignals': siteActivity.totalSignals,
        'personSignals': siteActivity.personSignals,
        'vehicleSignals': siteActivity.vehicleSignals,
        'knownIdentitySignals': siteActivity.knownIdentitySignals,
        'flaggedIdentitySignals': siteActivity.flaggedIdentitySignals,
        'unknownSignals':
            siteActivity.unknownPersonSignals +
            siteActivity.unknownVehicleSignals,
        'longPresenceSignals': siteActivity.longPresenceSignals,
        'guardInteractionSignals': siteActivity.guardInteractionSignals,
        'summaryLine': siteActivity.summaryLine,
      },
      'trend': siteActivityTrend == null
          ? null
          : {
              'label': siteActivityTrend.label,
              'summary': siteActivityTrend.summary,
            },
    });
  }

  String _siteActivityTruthCsv() {
    final sovereignReport = morningSovereignReport;
    final siteActivityTrend = sovereignReport == null
        ? null
        : _siteActivityTrendFor(sovereignReport, siteActivity);
    return [
      'metric,value',
      'report_date,${sovereignReport?.date ?? ''}',
      'generated_at_utc,${sovereignReport?.generatedAtUtc.toIso8601String() ?? ''}',
      'site_activity_total_signals,${siteActivity.totalSignals}',
      'site_activity_people,${siteActivity.personSignals}',
      'site_activity_vehicles,${siteActivity.vehicleSignals}',
      'site_activity_known_ids,${siteActivity.knownIdentitySignals}',
      'site_activity_flagged_ids,${siteActivity.flaggedIdentitySignals}',
      'site_activity_unknown_signals,${siteActivity.unknownPersonSignals + siteActivity.unknownVehicleSignals}',
      'site_activity_long_presence,${siteActivity.longPresenceSignals}',
      'site_activity_guard_interactions,${siteActivity.guardInteractionSignals}',
      'site_activity_summary,"${siteActivity.summaryLine.replaceAll('"', '""')}"',
      'site_activity_trend_label,${siteActivityTrend?.label ?? ''}',
      'site_activity_trend_summary,"${(siteActivityTrend?.summary ?? '').replaceAll('"', '""')}"',
    ].join('\n');
  }

  String _siteActivityTelegramSummary() {
    final sovereignReport = morningSovereignReport;
    final siteActivityTrend = sovereignReport == null
        ? null
        : _siteActivityTrendFor(sovereignReport, siteActivity);
    return _siteActivityTelegram.formatSummary(
      snapshot: siteActivity,
      siteLabel: 'Dashboard scope',
      reportDate: sovereignReport?.date,
      trendLabel: siteActivityTrend?.label,
      trendSummary: siteActivityTrend?.summary,
    );
  }

  String _siteActivityReviewJson() {
    final sovereignReport = morningSovereignReport;
    return const JsonEncoder.withIndent('  ').convert({
      'scope': {
        'reportDate': sovereignReport?.date,
        'generatedAtUtc': sovereignReport?.generatedAtUtc.toIso8601String(),
      },
      'siteActivityReview': {
        'summaryLine': siteActivity.summaryLine,
        'eventIds': siteActivity.eventIds,
        'selectedEventId': siteActivity.selectedEventId,
        'evidenceEventIds': siteActivity.evidenceEventIds,
        'topFlaggedIdentitySummary': siteActivity.topFlaggedIdentitySummary,
        'topLongPresenceSummary': siteActivity.topLongPresenceSummary,
        'topGuardInteractionSummary': siteActivity.topGuardInteractionSummary,
      },
    });
  }

  void _openSiteActivityEventsReview(BuildContext context) {
    if (onOpenEventsForScope == null || siteActivity.eventIds.isEmpty) {
      return;
    }
    onOpenEventsForScope!(siteActivity.eventIds, siteActivity.selectedEventId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Opening Events Review for site activity truth.',
          style: GoogleFonts.inter(
            color: const Color(0xFFE7F0FF),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: const Color(0xFF0E203A),
      ),
    );
  }

  String _guardPolicyTelemetryCsv() {
    final deniedEvents = [...guardOutcomePolicyDeniedHistoryUtc]
      ..sort((a, b) => b.compareTo(a));
    final lines = <String>[
      'metric,value',
      'policy_denied_total,$guardOutcomePolicyDeniedCount',
      'policy_denied_24h,$guardOutcomePolicyDenied24h',
      'policy_denied_7d,$guardOutcomePolicyDenied7d',
      'policy_denied_last_reason,"${(guardOutcomePolicyDeniedLastReason ?? '').replaceAll('"', '""')}"',
      'denied_at_utc,count',
      ...deniedEvents.map((entry) => '${entry.toUtc().toIso8601String()},1'),
    ];
    return lines.join('\n');
  }

  String _guardCoachingTelemetryJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'coachingTelemetry': {
        'ackCount': guardCoachingAckCount,
        'snoozeCount': guardCoachingSnoozeCount,
        'snoozeExpiryCount': guardCoachingSnoozeExpiryCount,
        'recentHistory': guardCoachingRecentHistory,
      },
    });
  }

  String _guardCoachingTelemetryCsv() {
    final lines = <String>[
      'metric,value',
      'coaching_ack_count,$guardCoachingAckCount',
      'coaching_snooze_count,$guardCoachingSnoozeCount',
      'coaching_snooze_expiry_count,$guardCoachingSnoozeExpiryCount',
      'history_index,entry',
      ...guardCoachingRecentHistory.asMap().entries.map(
        (entry) => '${entry.key + 1},"${entry.value.replaceAll('"', '""')}"',
      ),
    ];
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = snapshot.sites
        .where((site) => site.activeDispatches > 0)
        .length;
    final guardAlerts = <({String label, Color color})>[
      if (guardFailedEvents + guardFailedMedia >= guardFailureAlertThreshold)
        (label: 'Failures', color: const Color(0xFFFF9AA3)),
      if (guardSyncQueueDepth >= guardQueuePressureAlertThreshold)
        (label: 'Queue Pressure', color: const Color(0xFFFFC983)),
      if (!guardSyncInFlight &&
          guardLastSuccessfulSyncAtUtc != null &&
          DateTime.now().toUtc().difference(guardLastSuccessfulSyncAtUtc!) >
              Duration(minutes: guardStaleSyncAlertMinutes))
        (label: 'Stale Sync', color: const Color(0xFFFFC983)),
      if (!guardSyncBackendEnabled)
        (label: 'Local Only', color: const Color(0xFFB0C3DE)),
      if (guardOutcomePolicyDeniedCount > 0)
        (label: 'Policy Denied', color: const Color(0xFFF5C27A)),
    ];
    final recentEventFailureTraces =
        (guardRecentEvents
                .where((event) => (event.failureReason ?? '').trim().isNotEmpty)
                .toList()
              ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt)))
            .take(2)
            .map(
              (event) =>
                  '[${_formatTimestamp(event.occurredAt)}] Event ${event.eventType.name} seq ${event.sequence}: ${event.failureReason}',
            )
            .toList(growable: false);
    final recentMediaFailureTraces =
        (guardRecentMedia
                .where((media) => (media.failureReason ?? '').trim().isNotEmpty)
                .toList()
              ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt)))
            .take(2)
            .map(
              (media) =>
                  '[${_formatTimestamp(media.capturedAt)}] Media ${media.bucket}: ${media.failureReason}',
            )
            .toList(growable: false);
    final recentFailureTraces = <String>[
      ...recentEventFailureTraces,
      ...recentMediaFailureTraces,
    ].toList(growable: false);
    final visibleCoachingHistory = guardCoachingRecentHistory
        .take(3)
        .toList(growable: false);
    final hiddenCoachingHistory =
        guardCoachingRecentHistory.length - visibleCoachingHistory.length;
    final sovereignReport = morningSovereignReport;
    final governanceGenerationEnabled =
        onGenerateMorningSovereignReport != null;
    final overrideReasonSummary = sovereignReport == null
        ? 'none'
        : (sovereignReport.aiHumanDelta.overrideReasons.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .take(3)
              .map((entry) => '${entry.key} ${entry.value}')
              .join(', ');
    final receiptPolicyTrend = sovereignReport == null
        ? null
        : _receiptPolicyTrendFor(sovereignReport);
    final receiptInvestigationTrend = sovereignReport == null
        ? null
        : _receiptInvestigationTrendFor(sovereignReport);
    final siteActivityTrend = sovereignReport == null
        ? null
        : _siteActivityTrendFor(sovereignReport, siteActivity);

    return Column(
      children: [
        _DashboardCard(
          title: 'Threat Readout',
          subtitle: 'Condensed command view with readable actions.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${threat.label} posture',
                style: GoogleFonts.rajdhani(
                  color: threat.accent,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                snapshot.totalFailed > 0
                    ? '${snapshot.totalFailed} failed executions need operator review before workload normalises.'
                    : 'No failed executions currently expanding operational risk.',
                style: GoogleFonts.inter(
                  color: const Color(0xFFD2DEEE),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              _RailMetricRow(
                label: 'Active sites',
                value: activeCount.toString(),
              ),
              _RailMetricRow(
                label: 'Pressure index',
                value: snapshot.controllerPressureIndex.toStringAsFixed(1),
              ),
              _RailMetricRow(
                label: 'Avg response',
                value:
                    '${snapshot.averageResponseMinutes.toStringAsFixed(1)} min',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _DashboardCard(
          title: 'Operational Mix',
          subtitle: 'Core signal buckets without visual clutter.',
          child: Column(
            children: [
              _MixBar(
                label: 'Executed',
                value: snapshot.totalExecuted,
                total: snapshot.totalDecisions,
                accent: const Color(0xFF7AF2B5),
              ),
              const SizedBox(height: 8),
              _MixBar(
                label: 'Denied',
                value: snapshot.totalDenied,
                total: snapshot.totalDecisions,
                accent: const Color(0xFFFFC27A),
              ),
              const SizedBox(height: 8),
              _MixBar(
                label: 'Failed',
                value: snapshot.totalFailed,
                total: snapshot.totalDecisions,
                accent: const Color(0xFFFF8D95),
              ),
              const SizedBox(height: 8),
              _MixBar(
                label: 'High-risk intel',
                value: snapshot.highRiskIntelligence,
                total: snapshot.totalIntelligenceReceived,
                accent: const Color(0xFFC0A7FF),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _DashboardCard(
          title: 'Guard Sync Health',
          subtitle: 'Queue pressure and failure trace from Android guard sync.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (guardAlerts.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: guardAlerts
                      .map(
                        (alert) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: alert.color.withValues(alpha: 0.12),
                            border: Border.all(
                              color: alert.color.withValues(alpha: 0.65),
                            ),
                          ),
                          child: Text(
                            alert.label,
                            style: GoogleFonts.inter(
                              color: alert.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 10),
              ],
              _RailMetricRow(
                label: 'Backend mode',
                value: guardSyncBackendEnabled ? 'Supabase+fallback' : 'local',
              ),
              _RailMetricRow(
                label: 'Sync state',
                value: guardSyncInFlight ? 'in-flight' : 'idle',
              ),
              _RailMetricRow(
                label: 'Queue depth',
                value: guardSyncQueueDepth.toString(),
              ),
              _RailMetricRow(
                label: 'Pending',
                value: 'events $guardPendingEvents • media $guardPendingMedia',
              ),
              _RailMetricRow(
                label: 'Failed',
                value: 'events $guardFailedEvents • media $guardFailedMedia',
              ),
              if (guardLastSuccessfulSyncAtUtc != null)
                _RailMetricRow(
                  label: 'Last success',
                  value: _formatTimestamp(guardLastSuccessfulSyncAtUtc!),
                ),
              if (guardSyncStatusLabel != null &&
                  guardSyncStatusLabel!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    guardSyncStatusLabel!,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8FD1FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (guardLastFailureReason != null &&
                  guardLastFailureReason!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Last failure: $guardLastFailureReason',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFFB2B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  iconColor: const Color(0xFF8FD1FF),
                  collapsedIconColor: const Color(0xFF7EA5CB),
                  title: Text(
                    'Diagnostics and coaching telemetry',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8FD1FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RailMetricRow(
                            label: 'Policy denied',
                            value: guardOutcomePolicyDeniedCount.toString(),
                          ),
                          _RailMetricRow(
                            label: 'Denied (24h)',
                            value: guardOutcomePolicyDenied24h.toString(),
                          ),
                          _RailMetricRow(
                            label: 'Denied (7d)',
                            value: guardOutcomePolicyDenied7d.toString(),
                          ),
                          _RailMetricRow(
                            label: 'Coaching Ack',
                            value: guardCoachingAckCount.toString(),
                          ),
                          _RailMetricRow(
                            label: 'Coaching Snooze',
                            value: guardCoachingSnoozeCount.toString(),
                          ),
                          _RailMetricRow(
                            label: 'Snooze Expiry',
                            value: guardCoachingSnoozeExpiryCount.toString(),
                          ),
                          if (guardOutcomePolicyDeniedLastReason != null &&
                              guardOutcomePolicyDeniedLastReason!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Policy denied (latest): $guardOutcomePolicyDeniedLastReason',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFF5C27A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (guardCoachingRecentHistory.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Recent Coaching Telemetry',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF8FD1FF),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ...visibleCoachingHistory.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  entry,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFB8CBE7),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            if (hiddenCoachingHistory > 0)
                              OnyxTruncationHint(
                                visibleCount: visibleCoachingHistory.length,
                                totalCount: guardCoachingRecentHistory.length,
                                subject: 'coaching rows',
                                hiddenDescriptor: 'additional rows',
                                fontSize: 10,
                                color: const Color(0xFF8EA5C6),
                              ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Recent Failure Trace',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF8FD1FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (recentFailureTraces.isEmpty)
                            Text(
                              'No recent failure trace.',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF95A9C6),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Events',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF9FB6D5),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (recentEventFailureTraces.isEmpty)
                                  Text(
                                    'No event failures.',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF95A9C6),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                else
                                  ...recentEventFailureTraces.map(
                                    (trace) => Padding(
                                      padding: const EdgeInsets.only(bottom: 3),
                                      child: Text(
                                        trace,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFFFC7CC),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  'Media',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF9FB6D5),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (recentMediaFailureTraces.isEmpty)
                                  Text(
                                    'No media failures.',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF95A9C6),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                else
                                  ...recentMediaFailureTraces.map(
                                    (trace) => Padding(
                                      padding: const EdgeInsets.only(bottom: 3),
                                      child: Text(
                                        trace,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFFFC7CC),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
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
              const SizedBox(height: 8),
              if (onOpenGuardSync != null ||
                  onClearGuardOutcomePolicyTelemetry != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (onOpenGuardSync != null)
                      OutlinedButton(
                        onPressed: onOpenGuardSync,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF23547C)),
                          foregroundColor: const Color(0xFF8FD1FF),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          textStyle: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Open Guard Sync'),
                      ),
                    if (onClearGuardOutcomePolicyTelemetry != null)
                      OutlinedButton(
                        onPressed: onClearGuardOutcomePolicyTelemetry,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF6D4B25)),
                          foregroundColor: const Color(0xFFF5C27A),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          textStyle: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Clear Policy Telemetry'),
                      ),
                  ],
                ),
              const SizedBox(height: 4),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  iconColor: const Color(0xFF8FD1FF),
                  collapsedIconColor: const Color(0xFF7EA5CB),
                  title: Text(
                    'Advanced export and share',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8FD1FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: siteActivity.eventIds.isEmpty
                                  ? null
                                  : () async {
                                      await Clipboard.setData(
                                        ClipboardData(
                                          text: _siteActivityReviewJson(),
                                        ),
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Site activity review JSON copied',
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFFE7F0FF),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          backgroundColor: const Color(
                                            0xFF0E203A,
                                          ),
                                        ),
                                      );
                                    },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Copy Site Activity Review JSON',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF8FD1FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          if (onOpenEventsForScope != null &&
                              siteActivity.eventIds.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: TextButton(
                                onPressed: () =>
                                    _openSiteActivityEventsReview(context),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Open Site Activity Events Review',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF8FD1FF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(
                                    text: _guardFailureTraceClipboard(
                                      recentFailureTraces,
                                      guardLastFailureReason,
                                    ),
                                  ),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Guard failure trace copied',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE7F0FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF0E203A),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Copy Failure Trace',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF8FD1FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: () async {
                                if (!_emailBridge.supported) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Email bridge is only available on web',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFE7F0FF),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFF0E203A),
                                    ),
                                  );
                                  return;
                                }
                                final opened = await _emailBridge.openMailDraft(
                                  subject: 'ONYX Guard Sync Failure Trace',
                                  body: _guardFailureTraceText(
                                    recentFailureTraces,
                                    guardLastFailureReason,
                                  ),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      opened
                                          ? 'Email draft opened for failure trace'
                                          : 'Email bridge unavailable',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE7F0FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF0E203A),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Email Failure Trace',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF8FD1FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: () async {
                                if (!_snapshotFiles.supported) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'File export is only available on web',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFE7F0FF),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFF0E203A),
                                    ),
                                  );
                                  return;
                                }
                                await _snapshotFiles.downloadTextFile(
                                  filename: 'guard-sync-failure-trace.txt',
                                  contents: _guardFailureTraceText(
                                    recentFailureTraces,
                                    guardLastFailureReason,
                                  ),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failure trace download started',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE7F0FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF0E203A),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Download Failure Trace',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF8FD1FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: () async {
                                if (!_textShare.supported) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Share is not available in this environment',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFE7F0FF),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFF0E203A),
                                    ),
                                  );
                                  return;
                                }
                                final shared = await _textShare.shareText(
                                  title: 'ONYX Guard Sync Failure Trace',
                                  text: _guardFailureTraceText(
                                    recentFailureTraces,
                                    guardLastFailureReason,
                                  ),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      shared
                                          ? 'Failure trace share started'
                                          : 'Failure trace share unavailable',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE7F0FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF0E203A),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Share Failure Trace',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF8FD1FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(
                                    text: _guardPolicyTelemetryJson(),
                                  ),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Policy telemetry JSON copied',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE7F0FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF0E203A),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Copy Policy Telemetry JSON',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFF5C27A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(
                                    text: _guardPolicyTelemetryCsv(),
                                  ),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Policy telemetry CSV copied',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE7F0FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF0E203A),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Copy Policy Telemetry CSV',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFF5C27A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: () async {
                                if (!_snapshotFiles.supported) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'File export is only available on web',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFE7F0FF),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFF0E203A),
                                    ),
                                  );
                                  return;
                                }
                                await _snapshotFiles.downloadJsonFile(
                                  filename: 'guard-policy-telemetry.json',
                                  contents: _guardPolicyTelemetryJson(),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Policy telemetry JSON download started',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE7F0FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF0E203A),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Download Policy JSON',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFF5C27A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: () async {
                                if (!_snapshotFiles.supported) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'File export is only available on web',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFE7F0FF),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFF0E203A),
                                    ),
                                  );
                                  return;
                                }
                                await _snapshotFiles.downloadTextFile(
                                  filename: 'guard-policy-telemetry.csv',
                                  contents: _guardPolicyTelemetryCsv(),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Policy telemetry CSV download started',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE7F0FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF0E203A),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Download Policy CSV',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFF5C27A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: () async {
                                if (!_textShare.supported) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Share is not available in this environment',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFE7F0FF),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFF0E203A),
                                    ),
                                  );
                                  return;
                                }
                                final shared = await _textShare.shareText(
                                  title: 'ONYX Guard Policy Telemetry',
                                  text: _guardPolicyTelemetryJson(),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      shared
                                          ? 'Policy telemetry share started'
                                          : 'Policy telemetry share unavailable',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE7F0FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF0E203A),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Share Policy Pack',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFF5C27A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(
                                    text: _guardCoachingTelemetryJson(),
                                  ),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Coaching telemetry JSON copied',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE7F0FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF0E203A),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Copy Coaching Telemetry JSON',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF8FD1FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(
                                    text: _guardCoachingTelemetryCsv(),
                                  ),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Coaching telemetry CSV copied',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE7F0FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF0E203A),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Copy Coaching Telemetry CSV',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF8FD1FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: () async {
                                if (!_snapshotFiles.supported) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'File export is only available on web',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFE7F0FF),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFF0E203A),
                                    ),
                                  );
                                  return;
                                }
                                await _snapshotFiles.downloadJsonFile(
                                  filename: 'guard-coaching-telemetry.json',
                                  contents: _guardCoachingTelemetryJson(),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Coaching telemetry JSON download started',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE7F0FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF0E203A),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Download Coaching JSON',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF8FD1FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: () async {
                                if (!_textShare.supported) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Share is not available in this environment',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFE7F0FF),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFF0E203A),
                                    ),
                                  );
                                  return;
                                }
                                final shared = await _textShare.shareText(
                                  title: 'ONYX Guard Coaching Telemetry',
                                  text: _guardCoachingTelemetryJson(),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      shared
                                          ? 'Coaching telemetry share started'
                                          : 'Coaching telemetry share unavailable',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE7F0FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF0E203A),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Share Coaching Pack',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF8FD1FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: _siteActivityTruthJson()),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Site activity truth JSON copied',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE7F0FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF0E203A),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Copy Site Activity JSON',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF8FD1FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: _siteActivityTruthCsv()),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Site activity truth CSV copied',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE7F0FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF0E203A),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Copy Site Activity CSV',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF8FD1FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: () async {
                                if (!_textShare.supported) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Share is not available in this environment',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFE7F0FF),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFF0E203A),
                                    ),
                                  );
                                  return;
                                }
                                final shared = await _textShare.shareText(
                                  title: 'ONYX Site Activity Truth',
                                  text: _siteActivityTruthJson(),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      shared
                                          ? 'Site activity truth share started'
                                          : 'Site activity truth share unavailable',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE7F0FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF0E203A),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Share Site Activity Pack',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF8FD1FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(
                                    text: _siteActivityTelegramSummary(),
                                  ),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Site activity Telegram summary copied',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE7F0FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF0E203A),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Copy Site Activity Telegram',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF8FD1FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: () async {
                                if (!_textShare.supported) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Share is not available in this environment',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFE7F0FF),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFF0E203A),
                                    ),
                                  );
                                  return;
                                }
                                final shared = await _textShare.shareText(
                                  title: 'ONYX Site Activity Telegram Summary',
                                  text: _siteActivityTelegramSummary(),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      shared
                                          ? 'Site activity Telegram share started'
                                          : 'Site activity Telegram share unavailable',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE7F0FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF0E203A),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Share Site Activity Telegram',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF8FD1FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _DashboardCard(
          title: 'Morning Sovereign Report',
          subtitle:
              'Automated 06:00 generation with forensic replay of the 22:00-06:00 command window.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sovereignReport == null)
                Text(
                  'No morning report generated yet.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF95A9C6),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else ...[
                _RailMetricRow(
                  label: 'Report date',
                  value: sovereignReport.date,
                ),
                _RailMetricRow(
                  label: 'Window (UTC)',
                  value:
                      '${_formatTimestamp(sovereignReport.shiftWindowStartUtc)} → ${_formatTimestamp(sovereignReport.shiftWindowEndUtc)}',
                ),
                _RailMetricRow(
                  label: 'Ledger integrity',
                  value:
                      '${sovereignReport.ledgerIntegrity.hashVerified ? 'VERIFIED' : 'COMPROMISED'} • ${sovereignReport.ledgerIntegrity.totalEvents} events',
                ),
                _RailMetricRow(
                  label: 'AI/Human delta',
                  value:
                      '${sovereignReport.aiHumanDelta.aiDecisions} decisions • ${sovereignReport.aiHumanDelta.humanOverrides} overrides',
                ),
                _RailMetricRow(
                  label: 'Override reasons',
                  value: overrideReasonSummary.isEmpty
                      ? 'none'
                      : overrideReasonSummary,
                ),
                _RailMetricRow(
                  label: 'Norm drift',
                  value:
                      '${sovereignReport.normDrift.driftDetected} sites • avg ${sovereignReport.normDrift.avgMatchScore.toStringAsFixed(1)}%',
                ),
                _RailMetricRow(
                  label: 'Compliance blockage',
                  value:
                      '${sovereignReport.complianceBlockage.totalBlocked} blocked',
                ),
                if ((sovereignReport.receiptPolicy.headline
                        .trim()
                        .isNotEmpty) ||
                    sovereignReport.receiptPolicy.executiveSummary
                        .trim()
                        .isNotEmpty ||
                    sovereignReport.receiptPolicy.brandingExecutiveSummary
                        .trim()
                        .isNotEmpty ||
                    sovereignReport.receiptPolicy.summaryLine.trim().isNotEmpty)
                  _RailMetricRow(
                    label: 'Receipt policy',
                    value: _receiptPolicyRailSummary(
                      sovereignReport.receiptPolicy,
                    ),
                  ),
                if (receiptPolicyTrend != null)
                  _RailMetricRow(
                    label: 'Receipt policy trend',
                    value:
                        '${receiptPolicyTrend.label} • ${receiptPolicyTrend.summary}',
                  ),
                if (sovereignReport.receiptPolicy.investigationExecutiveSummary
                        .trim()
                        .isNotEmpty ||
                    sovereignReport.receiptPolicy.governanceHandoffReports >
                        0 ||
                    sovereignReport.receiptPolicy.routineReviewReports > 0)
                  _RailMetricRow(
                    label: 'Receipt investigation',
                    value: _receiptInvestigationRailSummary(
                      sovereignReport.receiptPolicy,
                    ),
                  ),
                if (receiptInvestigationTrend != null)
                  _RailMetricRow(
                    label: 'Receipt investigation trend',
                    value:
                        '${receiptInvestigationTrend.label} • ${receiptInvestigationTrend.summary}',
                  ),
                if ((sovereignReport.vehicleThroughput.workflowHeadline
                        .trim()
                        .isNotEmpty) ||
                    sovereignReport.vehicleThroughput.summaryLine
                        .trim()
                        .isNotEmpty)
                  _RailMetricRow(
                    label: 'Vehicle throughput',
                    value:
                        sovereignReport.vehicleThroughput.workflowHeadline
                            .trim()
                            .isNotEmpty
                        ? sovereignReport.vehicleThroughput.workflowHeadline
                        : sovereignReport.vehicleThroughput.summaryLine,
                  ),
                if (siteActivity.totalSignals > 0)
                  _RailMetricRow(
                    label: 'Site activity',
                    value: siteActivity.summaryLine,
                  ),
                if (siteActivityTrend != null)
                  _RailMetricRow(
                    label: 'Site activity trend',
                    value:
                        '${siteActivityTrend.label} • ${siteActivityTrend.summary}',
                  ),
                if ((sovereignReport.partnerProgression.workflowHeadline
                        .trim()
                        .isNotEmpty) ||
                    sovereignReport.partnerProgression.performanceHeadline
                        .trim()
                        .isNotEmpty ||
                    sovereignReport.partnerProgression.slaHeadline
                        .trim()
                        .isNotEmpty ||
                    sovereignReport.partnerProgression.summaryLine
                        .trim()
                        .isNotEmpty)
                  _RailMetricRow(
                    label: 'Partner progression',
                    value:
                        sovereignReport.partnerProgression.performanceHeadline
                            .trim()
                            .isNotEmpty
                        ? sovereignReport.partnerProgression.performanceHeadline
                        : sovereignReport.partnerProgression.slaHeadline
                              .trim()
                              .isNotEmpty
                        ? sovereignReport.partnerProgression.slaHeadline
                        : sovereignReport.partnerProgression.workflowHeadline
                              .trim()
                              .isNotEmpty
                        ? sovereignReport.partnerProgression.workflowHeadline
                        : sovereignReport.partnerProgression.summaryLine,
                  ),
              ],
              if ((morningSovereignReportAutoStatusLabel ?? '')
                  .trim()
                  .isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    morningSovereignReportAutoStatusLabel!.trim(),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9FB6D5),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                governanceGenerationEnabled
                    ? 'Generation and delivery controls moved to Governance screen.'
                    : 'Governance screen is the control point for morning report generation and delivery.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9FB6D5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _DashboardCard(
          title: 'Command Notes',
          subtitle: 'Readable guidance instead of dense stacked labels.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NoteRow(
                label: 'Dispatch cadence',
                detail: snapshot.totalDenied > 0
                    ? 'Review denial causes and tighten authority routing.'
                    : 'Dispatch authority flow is clean.',
              ),
              const SizedBox(height: 10),
              _NoteRow(
                label: 'Field readiness',
                detail: snapshot.totalCheckIns > 0 || snapshot.totalPatrols > 0
                    ? 'Field teams are active and reporting.'
                    : 'No field check-ins or patrol completions yet.',
              ),
              const SizedBox(height: 10),
              _NoteRow(
                label: 'Intel posture',
                detail: snapshot.totalIntelligenceReceived > 0
                    ? '${snapshot.totalIntelligenceReceived} signals received, ${snapshot.highRiskIntelligence} high-risk.'
                    : 'No intelligence signals received yet.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF0E1A2B),
        border: Border.all(color: const Color(0xFF223244)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF56B9FF),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF7D93B1),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE7F0FF),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF243549)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF3C79BB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE8F1FF),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: const Color(0xFF7D93B1),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _KpiBandTile extends StatelessWidget {
  final String label;
  final String value;
  final String helper;

  const _KpiBandTile({
    required this.label,
    required this.value,
    required this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF0E1A2B),
        border: Border.all(color: const Color(0xFF223244)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF4C8AD1),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF8AA2C0),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFEAF2FF),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            helper,
            style: GoogleFonts.inter(
              color: const Color(0xFF7088A9),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final Color accent;
  final String label;

  const _TimelineRow({required this.accent, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFFD7E4F7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _DispatchFeedRow extends StatelessWidget {
  final String label;

  const _DispatchFeedRow({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDanger = label.contains('FAILED') || label.contains('DENIED');
    final isSuccess = label.contains('EXECUTED');
    final accent = isDanger
        ? const Color(0xFFFF8E9A)
        : isSuccess
        ? const Color(0xFF8EF3C0)
        : const Color(0xFF8FD1FF);
    final border = isDanger
        ? const Color(0xFF6B3040)
        : isSuccess
        ? const Color(0xFF225F4A)
        : const Color(0xFF21406F);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        color: const Color(0xFF0E1A2B),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: accent,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }
}

class _SiteRow extends StatelessWidget {
  final SiteHealthSnapshot site;
  final _ThreatState threat;

  const _SiteRow({required this.site, required this.threat});

  @override
  Widget build(BuildContext context) {
    final healthFraction = (site.healthScore / 100).clamp(0.0, 1.0);
    final stressColor = site.failedCount > 0
        ? const Color(0xFFFF7C88)
        : site.activeDispatches > 0
        ? const Color(0xFFFFC27A)
        : const Color(0xFF73D8FF);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF0E1A2B),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      site.siteId,
                      style: GoogleFonts.rajdhani(
                        color: const Color(0xFFE8F1FF),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${site.clientId} • ${site.regionId}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF7C93B2),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: threat.softAccent.withValues(alpha: 0.08),
                  border: Border.all(color: stressColor.withValues(alpha: 0.7)),
                ),
                child: Text(
                  site.healthStatus,
                  style: GoogleFonts.inter(
                    color: stressColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: healthFraction,
              minHeight: 6,
              backgroundColor: const Color(0xFF13253E),
              valueColor: AlwaysStoppedAnimation<Color>(stressColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _SiteStat(
                label: 'Health',
                value: site.healthScore.toStringAsFixed(0),
              ),
              _SiteStat(
                label: 'Active',
                value: site.activeDispatches.toString(),
              ),
              _SiteStat(label: 'Failed', value: site.failedCount.toString()),
              _SiteStat(
                label: 'Response',
                value: '${site.averageResponseMinutes.toStringAsFixed(1)}m',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SiteStat extends StatelessWidget {
  final String label;
  final String value;

  const _SiteStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF7F96B5),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFEAF2FF),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RailMetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _RailMetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF8AA2C0),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.rajdhani(
                color: const Color(0xFFEAF2FF),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MixBar extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color accent;

  const _MixBar({
    required this.label,
    required this.value,
    required this.total,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB0CC),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$value',
              style: GoogleFonts.rajdhani(
                color: accent,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: const Color(0xFF13253E),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
      ],
    );
  }
}

class _NoteRow extends StatelessWidget {
  final String label;
  final String detail;

  const _NoteRow({required this.label, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFFE8F1FF),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          detail,
          style: GoogleFonts.inter(
            color: const Color(0xFF8BA1BF),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _MutedLabel extends StatelessWidget {
  final String label;

  const _MutedLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(0xFF7D93B1),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ThreatState {
  final String label;
  final Color accent;
  final Color softAccent;

  const _ThreatState({
    required this.label,
    required this.accent,
    required this.softAccent,
  });
}

class _ReceiptPolicyTrend {
  final String label;
  final String summary;

  const _ReceiptPolicyTrend({required this.label, required this.summary});
}

String _formatTimestamp(DateTime value) {
  if (value.millisecondsSinceEpoch == 0) {
    return 'No events';
  }
  final utc = value.toUtc();
  final hour = utc.hour.toString().padLeft(2, '0');
  final minute = utc.minute.toString().padLeft(2, '0');
  return '$hour:$minute UTC';
}
