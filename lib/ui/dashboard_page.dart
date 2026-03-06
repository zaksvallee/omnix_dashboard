import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/dispatch_snapshot_file_service.dart';
import '../application/email_bridge_service.dart';
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
  });

  @override
  Widget build(BuildContext context) {
    final events = eventStore.allEvents();
    final snapshot = OperationsHealthProjection.build(events);
    final triage = _buildDashboardTriageSummary(events);
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
  });

  @override
  Widget build(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final railHeight = (viewportHeight - 190).clamp(520.0, 920.0);
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
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Keep the primary operational read path full-width on typical
          // desktop/laptop windows; only pin the right rail on very wide layouts.
          final stackRightRailBelow = constraints.maxWidth < 1560;

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
                          _SitePosturePanel(snapshot: snapshot, threat: threat),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 308,
                      height: railHeight,
                      child: rightRail,
                    ),
                  ],
                ),
            ],
          );
        },
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
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _ExecutiveSummary(snapshot: snapshot, threat: threat, triage: triage),
        const SizedBox(height: 10),
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
        ),
        const SizedBox(height: 12),
        _SignalAndFeedGrid(snapshot: snapshot),
        const SizedBox(height: 12),
        _SitePosturePanel(snapshot: snapshot, threat: threat),
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
        gradient: LinearGradient(
          colors: [Color(0x220D1F39), Color(0x000D1F39)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(bottom: BorderSide(color: Color(0xFF183354))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ONYX Command Dashboard',
                  style: GoogleFonts.rajdhani(
                    color: const Color(0xFFE8F1FF),
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Operational health, dispatch cadence, and site posture in one readable surface.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8EA4C2),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
          Container(
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
          ),
        ],
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
    return _DashboardCard(
      title: 'Operational Summary',
      subtitle:
          'A cleaner executive read of command volume, response timing, and current threat posture.',
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF102340),
                        threat.accent.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: const Color(0xFF1C3A63)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Controller Outlook',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF8EA4C2),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        threat.label,
                        style: GoogleFonts.rajdhani(
                          color: threat.accent,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.controllerPressureIndex >= 70
                            ? 'Controller load is elevated. Prioritise failed or denied dispatch review and allocate response support to stressed sites first.'
                            : 'Command load is stable. Maintain dispatch discipline, keep monitoring active, and continue regular patrol response cadence.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFD1DEEF),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetricTile(
                      label: 'Sites',
                      value: snapshot.totalSites.toString(),
                      accent: const Color(0xFF74C7FF),
                    ),
                    _MetricTile(
                      label: 'Decisions',
                      value: snapshot.totalDecisions.toString(),
                      accent: const Color(0xFF94B8FF),
                    ),
                    _MetricTile(
                      label: 'Executed',
                      value: snapshot.totalExecuted.toString(),
                      accent: const Color(0xFF7AF2B5),
                    ),
                    _MetricTile(
                      label: 'Denied',
                      value: snapshot.totalDenied.toString(),
                      accent: const Color(0xFFFFC27A),
                    ),
                    _MetricTile(
                      label: 'Failed',
                      value: snapshot.totalFailed.toString(),
                      accent: const Color(0xFFFF8D95),
                    ),
                    _MetricTile(
                      label: 'Intelligence',
                      value: snapshot.totalIntelligenceReceived.toString(),
                      accent: const Color(0xFFC0A7FF),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 10),
          _KpiBandTile(
            label: 'Triage Posture',
            value:
                'A ${triage.advisoryCount} • W ${triage.watchCount} • DC ${triage.dispatchCandidateCount} • Esc ${triage.escalateCount}',
            helper: 'Top triage signals: ${triage.topSignalsSummary}',
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _DashboardCard(
            title: 'Live Signals',
            subtitle: 'Recent intelligence, patrol, and field confirmations.',
            child: Column(
              children: [
                for (final row in snapshot.liveSignals.take(8)) ...[
                  _TimelineRow(accent: const Color(0xFF57C8FF), label: row),
                  const SizedBox(height: 10),
                ],
                if (snapshot.liveSignals.isEmpty)
                  _MutedLabel(label: 'No live signals yet.'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DashboardCard(
            title: 'Dispatch Feed',
            subtitle: 'Readable dispatch outcomes with quick priority color.',
            child: Column(
              children: [
                for (final row in snapshot.dispatchFeed.take(8)) ...[
                  _DispatchFeedRow(label: row),
                  const SizedBox(height: 8),
                ],
                if (snapshot.dispatchFeed.isEmpty)
                  _MutedLabel(label: 'No dispatch events yet.'),
              ],
            ),
          ),
        ),
      ],
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
          'A ranked site list is easier to scan than the previous decorative globe. Highest operational load is shown first.',
      child: Column(
        children: [
          for (final site in rankedSites.take(6)) ...[
            _SiteRow(site: site, threat: threat),
            const SizedBox(height: 12),
          ],
          if (rankedSites.isEmpty)
            const _MutedLabel(label: 'No site posture data available.'),
        ],
      ),
    );
  }
}

class _RightRail extends StatelessWidget {
  static const _snapshotFiles = DispatchSnapshotFileService();
  static const _textShare = TextShareService();
  static const _emailBridge = EmailBridgeService();

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

    return Scrollbar(
      child: SingleChildScrollView(
        child: Column(
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
                    SizedBox(
                      height: 210,
                      child: Scrollbar(
                        child: SingleChildScrollView(
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
                                value: guardCoachingSnoozeExpiryCount
                                    .toString(),
                              ),
                              if (guardOutcomePolicyDeniedLastReason != null &&
                                  guardOutcomePolicyDeniedLastReason!
                                      .isNotEmpty)
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
                                ...guardCoachingRecentHistory
                                    .take(3)
                                    .map(
                                      (entry) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 3,
                                        ),
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
                                          padding: const EdgeInsets.only(
                                            bottom: 3,
                                          ),
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
                                          padding: const EdgeInsets.only(
                                            bottom: 3,
                                          ),
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
                    SizedBox(
                      height: 500,
                      child: Scrollbar(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                        backgroundColor: const Color(
                                          0xFF0E203A,
                                        ),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Email bridge is only available on web',
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
                                      return;
                                    }
                                    final opened = await _emailBridge
                                        .openMailDraft(
                                          subject:
                                              'ONYX Guard Sync Failure Trace',
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
                                        backgroundColor: const Color(
                                          0xFF0E203A,
                                        ),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'File export is only available on web',
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
                                        backgroundColor: const Color(
                                          0xFF0E203A,
                                        ),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Share is not available in this environment',
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
                                        backgroundColor: const Color(
                                          0xFF0E203A,
                                        ),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
                                        backgroundColor: const Color(
                                          0xFF0E203A,
                                        ),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
                                        backgroundColor: const Color(
                                          0xFF0E203A,
                                        ),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'File export is only available on web',
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
                                        backgroundColor: const Color(
                                          0xFF0E203A,
                                        ),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'File export is only available on web',
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
                                        backgroundColor: const Color(
                                          0xFF0E203A,
                                        ),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Share is not available in this environment',
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
                                        backgroundColor: const Color(
                                          0xFF0E203A,
                                        ),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
                                        backgroundColor: const Color(
                                          0xFF0E203A,
                                        ),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
                                        backgroundColor: const Color(
                                          0xFF0E203A,
                                        ),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'File export is only available on web',
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
                                        backgroundColor: const Color(
                                          0xFF0E203A,
                                        ),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Share is not available in this environment',
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
                                        backgroundColor: const Color(
                                          0xFF0E203A,
                                        ),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
                            ],
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
        ),
      ),
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
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1A2D), Color(0xFF0B182B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF1E3D66)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 5),
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
        gradient: const LinearGradient(
          colors: [Color(0xFF0C182B), Color(0xFF091528)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1B395E)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 16,
            offset: Offset(0, 6),
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

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 138,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF0E1C31), Color(0xFF0B172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFF224267)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 10,
              offset: Offset(0, 6),
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
                color: accent.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF86A0C2),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.rajdhani(
                color: accent,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
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
        gradient: const LinearGradient(
          colors: [Color(0xFF0E1C31), Color(0xFF0B172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF224267)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, 6),
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
        color: const Color(0xFF0A1930),
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
        color: const Color(0xFF0A1830),
        border: Border.all(color: const Color(0xFF1A355A)),
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

String _formatTimestamp(DateTime value) {
  if (value.millisecondsSinceEpoch == 0) {
    return 'No events';
  }
  final utc = value.toUtc();
  final hour = utc.hour.toString().padLeft(2, '0');
  final minute = utc.minute.toString().padLeft(2, '0');
  return '$hour:$minute UTC';
}
