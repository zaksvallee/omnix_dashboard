import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/dispatch_snapshot_file_service.dart';
import '../application/email_bridge_service.dart';
import '../application/morning_sovereign_report_service.dart';
import '../application/review_shortcut_contract.dart';
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
import 'layout_breakpoints.dart';
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
                    allEvents: events,
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
                  allEvents: events,
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
  final List<DispatchEvent> allEvents;
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
    required this.allEvents,
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
      allEvents: allEvents,
      siteActivity: siteActivity,
      onGenerateMorningSovereignReport: onGenerateMorningSovereignReport,
      onOpenEventsForScope: onOpenEventsForScope,
    );

    return LayoutBuilder(
      builder: (context, viewport) {
        const contentPadding = EdgeInsets.all(10);
        final useScrollFallback =
            viewport.maxHeight < 720 || viewport.maxWidth < 1180;
        final boundedDesktopSurface =
            !useScrollFallback &&
            viewport.hasBoundedHeight &&
            viewport.maxHeight.isFinite;
        final ultrawideSurface = isUltrawideLayout(
          context,
          viewportWidth: viewport.maxWidth,
        );
        final widescreenSurface = isWidescreenLayout(
          context,
          viewportWidth: viewport.maxWidth,
        );
        final surfaceMaxWidth = ultrawideSurface
            ? viewport.maxWidth
            : widescreenSurface
            ? viewport.maxWidth * 0.94
            : 1540.0;

        Widget buildSurfaceBody({required bool embedScroll}) {
          final stackRightRailBelow = viewport.maxWidth < 1320;
          final workspace = _DashboardOperationsWorkspace(
            snapshot: snapshot,
            triage: triage,
            threat: threat,
          );
          if (stackRightRailBelow) {
            if (embedScroll) {
              return ListView(
                padding: EdgeInsets.zero,
                children: [workspace, const SizedBox(height: 10), rightRail],
              );
            }
            return Column(
              children: [workspace, const SizedBox(height: 10), rightRail],
            );
          }

          final railWidth = ultrawideSurface ? 380.0 : 336.0;
          final leftColumn = embedScroll
              ? SingleChildScrollView(primary: false, child: workspace)
              : workspace;
          final rightColumn = embedScroll
              ? SingleChildScrollView(primary: false, child: rightRail)
              : rightRail;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 8, child: leftColumn),
              const SizedBox(width: 10),
              SizedBox(width: railWidth, child: rightColumn),
            ],
          );
        }

        return OnyxViewportWorkspaceLayout(
          padding: contentPadding,
          maxWidth: surfaceMaxWidth,
          lockToViewport: boundedDesktopSurface,
          spacing: 10,
          header: _ExecutiveSummary(
            snapshot: snapshot,
            threat: threat,
            triage: triage,
          ),
          body: buildSurfaceBody(embedScroll: boundedDesktopSurface),
        );
      },
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
  final List<DispatchEvent> allEvents;
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
    required this.allEvents,
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
        _DashboardOperationsWorkspace(
          snapshot: snapshot,
          triage: triage,
          threat: threat,
        ),
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
          allEvents: allEvents,
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

class _DashboardOperationsWorkspace extends StatefulWidget {
  final OperationsHealthSnapshot snapshot;
  final _DashboardTriageSummary triage;
  final _ThreatState threat;

  const _DashboardOperationsWorkspace({
    required this.snapshot,
    required this.triage,
    required this.threat,
  });

  @override
  State<_DashboardOperationsWorkspace> createState() =>
      _DashboardOperationsWorkspaceState();
}

class _DashboardOperationsWorkspaceState
    extends State<_DashboardOperationsWorkspace> {
  _DashboardWorkspaceMode _mode = _DashboardWorkspaceMode.signals;
  _DashboardSignalLane _signalLane = _DashboardSignalLane.all;
  _DashboardDispatchLane _dispatchLane = _DashboardDispatchLane.all;
  _DashboardSiteLane _siteLane = _DashboardSiteLane.all;
  String? _selectedSignalId;
  String? _selectedDispatchId;
  String? _selectedSiteId;

  @override
  Widget build(BuildContext context) {
    final signalItems = _buildSignalItems(widget.snapshot.liveSignals);
    final dispatchItems = _buildDispatchItems(widget.snapshot.dispatchFeed);
    final siteItems = _buildSiteItems(widget.snapshot.sites);

    final visibleSignals = _filteredSignalItems(signalItems);
    final visibleDispatches = _filteredDispatchItems(dispatchItems);
    final visibleSites = _filteredSiteItems(siteItems);

    final selectedSignal = _resolveSignalSelection(visibleSignals);
    final selectedDispatch = _resolveDispatchSelection(visibleDispatches);
    final selectedSite = _resolveSiteSelection(visibleSites);

    final focus = switch (_mode) {
      _DashboardWorkspaceMode.signals => _signalFocusModel(
        selectedSignal,
        visibleSignals.length,
        signalItems.length,
      ),
      _DashboardWorkspaceMode.dispatch => _dispatchFocusModel(
        selectedDispatch,
        visibleDispatches.length,
        dispatchItems.length,
      ),
      _DashboardWorkspaceMode.sites => _siteFocusModel(
        selectedSite,
        visibleSites.length,
        siteItems.length,
      ),
    };

    return _DashboardCard(
      title: 'Command Workspace',
      subtitle:
          'Selectable operational lanes that turn the dashboard body into a live command board.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _workspaceFocusBanner(focus),
          const SizedBox(height: 12),
          _workspaceStatusBanner(
            signalItems: signalItems,
            dispatchItems: dispatchItems,
            siteItems: siteItems,
            visibleSignals: visibleSignals,
            visibleDispatches: visibleDispatches,
            visibleSites: visibleSites,
            selectedSignal: selectedSignal,
            selectedDispatch: selectedDispatch,
            selectedSite: selectedSite,
          ),
          const SizedBox(height: 10),
          _activeFilterRow(signalItems, dispatchItems, siteItems),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 1160;
              final lane = switch (_mode) {
                _DashboardWorkspaceMode.signals => _signalLanePane(
                  signalItems,
                  visibleSignals,
                  selectedSignal,
                ),
                _DashboardWorkspaceMode.dispatch => _dispatchLanePane(
                  dispatchItems,
                  visibleDispatches,
                  selectedDispatch,
                ),
                _DashboardWorkspaceMode.sites => _siteLanePane(
                  siteItems,
                  visibleSites,
                  selectedSite,
                ),
              };
              final detail = switch (_mode) {
                _DashboardWorkspaceMode.signals => _signalDetailPane(
                  signalItems,
                  visibleSignals,
                  selectedSignal,
                ),
                _DashboardWorkspaceMode.dispatch => _dispatchDetailPane(
                  dispatchItems,
                  visibleDispatches,
                  selectedDispatch,
                ),
                _DashboardWorkspaceMode.sites => _siteDetailPane(
                  siteItems,
                  visibleSites,
                  selectedSite,
                ),
              };
              if (stacked) {
                return Column(
                  children: [lane, const SizedBox(height: 10), detail],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: lane),
                  const SizedBox(width: 10),
                  Expanded(flex: 6, child: detail),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _setMode(_DashboardWorkspaceMode mode) {
    if (_mode == mode) {
      return;
    }
    setState(() {
      _mode = mode;
    });
  }

  void _focusSignalLaneAction(
    List<_DashboardSignalItem> items,
    _DashboardSignalLane lane,
  ) {
    final visible = _filteredSignalItems(items, lane: lane);
    setState(() {
      _mode = _DashboardWorkspaceMode.signals;
      _signalLane = lane;
      _selectedSignalId = visible.isEmpty ? null : visible.first.id;
    });
  }

  void _focusDispatchLaneAction(
    List<_DashboardDispatchItem> items,
    _DashboardDispatchLane lane,
  ) {
    final visible = _filteredDispatchItems(items, lane: lane);
    setState(() {
      _mode = _DashboardWorkspaceMode.dispatch;
      _dispatchLane = lane;
      _selectedDispatchId = visible.isEmpty ? null : visible.first.dispatchId;
    });
  }

  void _focusSiteLaneAction(
    List<SiteHealthSnapshot> items,
    _DashboardSiteLane lane,
  ) {
    final visible = _filteredSiteItems(items, lane: lane);
    setState(() {
      _mode = _DashboardWorkspaceMode.sites;
      _siteLane = lane;
      _selectedSiteId = visible.isEmpty ? null : visible.first.siteId;
    });
  }

  Widget _workspaceStatusBanner({
    required List<_DashboardSignalItem> signalItems,
    required List<_DashboardDispatchItem> dispatchItems,
    required List<SiteHealthSnapshot> siteItems,
    required List<_DashboardSignalItem> visibleSignals,
    required List<_DashboardDispatchItem> visibleDispatches,
    required List<SiteHealthSnapshot> visibleSites,
    required _DashboardSignalItem? selectedSignal,
    required _DashboardDispatchItem? selectedDispatch,
    required SiteHealthSnapshot? selectedSite,
  }) {
    final selectedLabel = switch (_mode) {
      _DashboardWorkspaceMode.signals => selectedSignal?.title ?? 'none',
      _DashboardWorkspaceMode.dispatch =>
        selectedDispatch?.dispatchId ?? 'none',
      _DashboardWorkspaceMode.sites => selectedSite?.siteId ?? 'none',
    };
    final activeLaneLabel = switch (_mode) {
      _DashboardWorkspaceMode.signals => switch (_signalLane) {
        _DashboardSignalLane.all => 'Signals • All',
        _DashboardSignalLane.intelligence => 'Signals • Intel',
        _DashboardSignalLane.field => 'Signals • Field',
        _DashboardSignalLane.closures => 'Signals • Closures',
      },
      _DashboardWorkspaceMode.dispatch => switch (_dispatchLane) {
        _DashboardDispatchLane.all => 'Dispatch • All',
        _DashboardDispatchLane.open => 'Dispatch • Open',
        _DashboardDispatchLane.risk => 'Dispatch • Risk',
        _DashboardDispatchLane.resolved => 'Dispatch • Resolved',
      },
      _DashboardWorkspaceMode.sites => switch (_siteLane) {
        _DashboardSiteLane.all => 'Sites • All',
        _DashboardSiteLane.active => 'Sites • Active',
        _DashboardSiteLane.watch => 'Sites • Watch',
        _DashboardSiteLane.strong => 'Sites • Strong',
      },
    };
    return Container(
      key: const ValueKey('dashboard-workspace-status-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1521),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF27425D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _workspaceStatusChip(
                label: activeLaneLabel,
                accent: const Color(0xFF8FD1FF),
              ),
              _workspaceStatusChip(
                label: 'Selected $selectedLabel',
                accent: const Color(0xFFF6C067),
              ),
              _workspaceStatusChip(
                label: 'Signals ${visibleSignals.length}/${signalItems.length}',
                accent: const Color(0xFF63BDFF),
              ),
              _workspaceStatusChip(
                label:
                    'Dispatch ${visibleDispatches.length}/${dispatchItems.length}',
                accent: const Color(0xFFFF8E9A),
              ),
              _workspaceStatusChip(
                label: 'Sites ${visibleSites.length}/${siteItems.length}',
                accent: const Color(0xFF8EF3C0),
              ),
              _workspaceStatusChip(
                label: 'Threat ${widget.threat.label}',
                accent: widget.threat.accent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _WorkspaceModeChip(
                widgetKey: const ValueKey('dashboard-workspace-mode-signals'),
                label: 'Signals',
                selected: _mode == _DashboardWorkspaceMode.signals,
                onTap: () => _setMode(_DashboardWorkspaceMode.signals),
              ),
              _WorkspaceModeChip(
                widgetKey: const ValueKey('dashboard-workspace-mode-dispatch'),
                label: 'Dispatch',
                selected: _mode == _DashboardWorkspaceMode.dispatch,
                onTap: () => _setMode(_DashboardWorkspaceMode.dispatch),
              ),
              _WorkspaceModeChip(
                widgetKey: const ValueKey('dashboard-workspace-mode-sites'),
                label: 'Sites',
                selected: _mode == _DashboardWorkspaceMode.sites,
                onTap: () => _setMode(_DashboardWorkspaceMode.sites),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _workspaceStatusAction(
                key: const ValueKey(
                  'dashboard-workspace-banner-open-live-intel',
                ),
                label: 'Live Intel',
                selected:
                    _mode == _DashboardWorkspaceMode.signals &&
                    _signalLane == _DashboardSignalLane.intelligence,
                accent: const Color(0xFF63BDFF),
                onTap: () => _focusSignalLaneAction(
                  signalItems,
                  _DashboardSignalLane.intelligence,
                ),
              ),
              _workspaceStatusAction(
                key: const ValueKey(
                  'dashboard-workspace-banner-open-dispatch-risk',
                ),
                label: 'Risk Dispatch',
                selected:
                    _mode == _DashboardWorkspaceMode.dispatch &&
                    _dispatchLane == _DashboardDispatchLane.risk,
                accent: const Color(0xFFFF8E9A),
                onTap: () => _focusDispatchLaneAction(
                  dispatchItems,
                  _DashboardDispatchLane.risk,
                ),
              ),
              _workspaceStatusAction(
                key: const ValueKey(
                  'dashboard-workspace-banner-open-site-watch',
                ),
                label: 'Watch Sites',
                selected:
                    _mode == _DashboardWorkspaceMode.sites &&
                    _siteLane == _DashboardSiteLane.watch,
                accent: const Color(0xFF8EF3C0),
                onTap: () =>
                    _focusSiteLaneAction(siteItems, _DashboardSiteLane.watch),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _workspaceStatusChip({required String label, required Color accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.38)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: accent,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _workspaceStatusAction({
    required Key key,
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.18)
              : const Color(0xFF10273D),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.5)
                : const Color(0xFF27425D),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? accent : const Color(0xFFEAF2FF),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _activeFilterRow(
    List<_DashboardSignalItem> signalItems,
    List<_DashboardDispatchItem> dispatchItems,
    List<SiteHealthSnapshot> siteItems,
  ) {
    return switch (_mode) {
      _DashboardWorkspaceMode.signals => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _WorkspaceFilterChip(
            widgetKey: const ValueKey('dashboard-signal-filter-all'),
            label: 'All',
            value: '${signalItems.length}',
            selected: _signalLane == _DashboardSignalLane.all,
            onTap: () => _setSignalLane(_DashboardSignalLane.all),
          ),
          _WorkspaceFilterChip(
            widgetKey: const ValueKey('dashboard-signal-filter-intel'),
            label: 'Intel',
            value:
                '${_signalCount(signalItems, _DashboardSignalLane.intelligence)}',
            selected: _signalLane == _DashboardSignalLane.intelligence,
            onTap: () => _setSignalLane(_DashboardSignalLane.intelligence),
          ),
          _WorkspaceFilterChip(
            widgetKey: const ValueKey('dashboard-signal-filter-field'),
            label: 'Field',
            value: '${_signalCount(signalItems, _DashboardSignalLane.field)}',
            selected: _signalLane == _DashboardSignalLane.field,
            onTap: () => _setSignalLane(_DashboardSignalLane.field),
          ),
          _WorkspaceFilterChip(
            widgetKey: const ValueKey('dashboard-signal-filter-closures'),
            label: 'Closures',
            value:
                '${_signalCount(signalItems, _DashboardSignalLane.closures)}',
            selected: _signalLane == _DashboardSignalLane.closures,
            onTap: () => _setSignalLane(_DashboardSignalLane.closures),
          ),
        ],
      ),
      _DashboardWorkspaceMode.dispatch => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _WorkspaceFilterChip(
            widgetKey: const ValueKey('dashboard-dispatch-filter-all'),
            label: 'All',
            value: '${dispatchItems.length}',
            selected: _dispatchLane == _DashboardDispatchLane.all,
            onTap: () => _setDispatchLane(_DashboardDispatchLane.all),
          ),
          _WorkspaceFilterChip(
            widgetKey: const ValueKey('dashboard-dispatch-filter-open'),
            label: 'Open',
            value:
                '${_dispatchCount(dispatchItems, _DashboardDispatchLane.open)}',
            selected: _dispatchLane == _DashboardDispatchLane.open,
            onTap: () => _setDispatchLane(_DashboardDispatchLane.open),
          ),
          _WorkspaceFilterChip(
            widgetKey: const ValueKey('dashboard-dispatch-filter-risk'),
            label: 'Risk',
            value:
                '${_dispatchCount(dispatchItems, _DashboardDispatchLane.risk)}',
            selected: _dispatchLane == _DashboardDispatchLane.risk,
            onTap: () => _setDispatchLane(_DashboardDispatchLane.risk),
          ),
          _WorkspaceFilterChip(
            widgetKey: const ValueKey('dashboard-dispatch-filter-resolved'),
            label: 'Resolved',
            value:
                '${_dispatchCount(dispatchItems, _DashboardDispatchLane.resolved)}',
            selected: _dispatchLane == _DashboardDispatchLane.resolved,
            onTap: () => _setDispatchLane(_DashboardDispatchLane.resolved),
          ),
        ],
      ),
      _DashboardWorkspaceMode.sites => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _WorkspaceFilterChip(
            widgetKey: const ValueKey('dashboard-site-filter-all'),
            label: 'All',
            value: '${siteItems.length}',
            selected: _siteLane == _DashboardSiteLane.all,
            onTap: () => _setSiteLane(_DashboardSiteLane.all),
          ),
          _WorkspaceFilterChip(
            widgetKey: const ValueKey('dashboard-site-filter-active'),
            label: 'Active',
            value: '${_siteCount(siteItems, _DashboardSiteLane.active)}',
            selected: _siteLane == _DashboardSiteLane.active,
            onTap: () => _setSiteLane(_DashboardSiteLane.active),
          ),
          _WorkspaceFilterChip(
            widgetKey: const ValueKey('dashboard-site-filter-watch'),
            label: 'Watch',
            value: '${_siteCount(siteItems, _DashboardSiteLane.watch)}',
            selected: _siteLane == _DashboardSiteLane.watch,
            onTap: () => _setSiteLane(_DashboardSiteLane.watch),
          ),
          _WorkspaceFilterChip(
            widgetKey: const ValueKey('dashboard-site-filter-strong'),
            label: 'Strong',
            value: '${_siteCount(siteItems, _DashboardSiteLane.strong)}',
            selected: _siteLane == _DashboardSiteLane.strong,
            onTap: () => _setSiteLane(_DashboardSiteLane.strong),
          ),
        ],
      ),
    };
  }

  void _setSignalLane(_DashboardSignalLane lane) {
    if (_signalLane == lane) {
      return;
    }
    setState(() {
      _signalLane = lane;
    });
  }

  void _setDispatchLane(_DashboardDispatchLane lane) {
    if (_dispatchLane == lane) {
      return;
    }
    setState(() {
      _dispatchLane = lane;
    });
  }

  void _setSiteLane(_DashboardSiteLane lane) {
    if (_siteLane == lane) {
      return;
    }
    setState(() {
      _siteLane = lane;
    });
  }

  List<_DashboardSignalItem> _buildSignalItems(List<String> rows) {
    return rows
        .map((row) {
          final riskMatch = RegExp(
            r'risk (\d+)',
            caseSensitive: false,
          ).firstMatch(row);
          final risk = riskMatch == null
              ? null
              : int.tryParse(riskMatch.group(1)!);
          final siteId = _siteTokenFromSummary(row);
          if (row.startsWith('Intel ')) {
            return _DashboardSignalItem(
              id: row,
              title: row.replaceFirst(RegExp(r'\.$'), ''),
              subtitle: siteId == null
                  ? 'Intelligence lane'
                  : 'Site $siteId • risk ${risk ?? 0}',
              detail: risk != null && risk >= 70
                  ? 'Escalate this intelligence packet into watch review before the next dispatch cycle.'
                  : 'Keep this intelligence signal in review and correlate it against field movement.',
              lane: _DashboardSignalLane.intelligence,
              badge: risk != null && risk >= 70 ? 'HIGH RISK' : 'INTEL',
              accent: risk != null && risk >= 70
                  ? const Color(0xFFFFB44D)
                  : const Color(0xFF63BDFF),
            );
          }
          if (row.startsWith('Incident ')) {
            return _DashboardSignalItem(
              id: row,
              title: row.replaceFirst(RegExp(r'\.$'), ''),
              subtitle: siteId == null
                  ? 'Incident closure lane'
                  : 'Site $siteId',
              detail:
                  'Incident closure is feeding the command ledger, so verify that the resolved trail is complete.',
              lane: _DashboardSignalLane.closures,
              badge: 'CLOSURE',
              accent: const Color(0xFF8EF3C0),
            );
          }
          return _DashboardSignalItem(
            id: row,
            title: row.replaceFirst(RegExp(r'\.$'), ''),
            subtitle: siteId == null ? 'Field operations lane' : 'Site $siteId',
            detail:
                'Field movement is reshaping live posture, so keep patrol and guard confirmations in the active read path.',
            lane: _DashboardSignalLane.field,
            badge: row.startsWith('Patrol ') ? 'PATROL' : 'FIELD',
            accent: row.startsWith('Patrol ')
                ? const Color(0xFF8EF3C0)
                : const Color(0xFF63BDFF),
          );
        })
        .toList(growable: false);
  }

  List<_DashboardDispatchItem> _buildDispatchItems(List<String> rows) {
    return rows
        .map((row) {
          final match = RegExp(r'Dispatch ([^ ]+) ([A-Z]+)').firstMatch(row);
          final dispatchId = match?.group(1) ?? row;
          final status = match?.group(2) ?? 'DECIDED';
          final scope = row.contains('•')
              ? row.split('•').last.trim()
              : 'Unknown scope';
          final lane = switch (status) {
            'EXECUTED' => _DashboardDispatchLane.resolved,
            'FAILED' || 'DENIED' => _DashboardDispatchLane.risk,
            _ => _DashboardDispatchLane.open,
          };
          final accent = switch (status) {
            'EXECUTED' => const Color(0xFF8EF3C0),
            'FAILED' => const Color(0xFFFF8E9A),
            'DENIED' => const Color(0xFFFFB44D),
            _ => const Color(0xFF63BDFF),
          };
          final directive = switch (status) {
            'EXECUTED' =>
              'Dispatch chain completed successfully. Hold the evidence trail and monitor follow-through.',
            'FAILED' =>
              'Dispatch failed in execution. Route this chain into rapid command review before pressure spreads.',
            'DENIED' =>
              'Dispatch was denied. Verify denial rationale and decide whether to reopen or suppress.',
            _ =>
              'Dispatch is still open. Keep acceptance and arrival pressure visible until the chain resolves.',
          };
          return _DashboardDispatchItem(
            dispatchId: dispatchId,
            status: status,
            scope: scope,
            summary: row,
            directive: directive,
            lane: lane,
            accent: accent,
          );
        })
        .toList(growable: false);
  }

  List<SiteHealthSnapshot> _buildSiteItems(List<SiteHealthSnapshot> sites) {
    final ranked = [...sites]
      ..sort(
        (left, right) =>
            _siteOperationalLoad(right).compareTo(_siteOperationalLoad(left)),
      );
    return ranked;
  }

  List<_DashboardSignalItem> _filteredSignalItems(
    List<_DashboardSignalItem> items, {
    _DashboardSignalLane? lane,
  }) {
    final activeLane = lane ?? _signalLane;
    return items
        .where((item) {
          return switch (activeLane) {
            _DashboardSignalLane.all => true,
            _DashboardSignalLane.intelligence =>
              item.lane == _DashboardSignalLane.intelligence,
            _DashboardSignalLane.field =>
              item.lane == _DashboardSignalLane.field,
            _DashboardSignalLane.closures =>
              item.lane == _DashboardSignalLane.closures,
          };
        })
        .toList(growable: false);
  }

  List<_DashboardDispatchItem> _filteredDispatchItems(
    List<_DashboardDispatchItem> items, {
    _DashboardDispatchLane? lane,
  }) {
    final activeLane = lane ?? _dispatchLane;
    return items
        .where((item) {
          return switch (activeLane) {
            _DashboardDispatchLane.all => true,
            _DashboardDispatchLane.open =>
              item.lane == _DashboardDispatchLane.open,
            _DashboardDispatchLane.risk =>
              item.lane == _DashboardDispatchLane.risk,
            _DashboardDispatchLane.resolved =>
              item.lane == _DashboardDispatchLane.resolved,
          };
        })
        .toList(growable: false);
  }

  List<SiteHealthSnapshot> _filteredSiteItems(
    List<SiteHealthSnapshot> items, {
    _DashboardSiteLane? lane,
  }) {
    final activeLane = lane ?? _siteLane;
    return items
        .where((item) {
          return switch (activeLane) {
            _DashboardSiteLane.all => true,
            _DashboardSiteLane.active => item.activeDispatches > 0,
            _DashboardSiteLane.watch =>
              item.failedCount > 0 ||
                  item.deniedCount > 0 ||
                  item.healthScore < 70,
            _DashboardSiteLane.strong => item.healthStatus == 'STRONG',
          };
        })
        .toList(growable: false);
  }

  int _signalCount(
    List<_DashboardSignalItem> items,
    _DashboardSignalLane lane,
  ) {
    return _filteredSignalItems(items, lane: lane).length;
  }

  int _dispatchCount(
    List<_DashboardDispatchItem> items,
    _DashboardDispatchLane lane,
  ) {
    return _filteredDispatchItems(items, lane: lane).length;
  }

  int _siteCount(List<SiteHealthSnapshot> items, _DashboardSiteLane lane) {
    return _filteredSiteItems(items, lane: lane).length;
  }

  _DashboardSignalItem? _resolveSignalSelection(
    List<_DashboardSignalItem> items,
  ) {
    if (items.isEmpty) {
      return null;
    }
    return items.firstWhere(
      (item) => item.id == _selectedSignalId,
      orElse: () => items.first,
    );
  }

  _DashboardDispatchItem? _resolveDispatchSelection(
    List<_DashboardDispatchItem> items,
  ) {
    if (items.isEmpty) {
      return null;
    }
    return items.firstWhere(
      (item) => item.dispatchId == _selectedDispatchId,
      orElse: () => items.first,
    );
  }

  SiteHealthSnapshot? _resolveSiteSelection(List<SiteHealthSnapshot> items) {
    if (items.isEmpty) {
      return null;
    }
    return items.firstWhere(
      (item) => item.siteId == _selectedSiteId,
      orElse: () => items.first,
    );
  }

  _DashboardFocusModel _signalFocusModel(
    _DashboardSignalItem? selected,
    int visibleCount,
    int totalCount,
  ) {
    final title = selected?.title ?? 'No live signals in this lane';
    final narrative =
        selected?.detail ??
        'Switch the signal lane to restore live command visibility.';
    return _DashboardFocusModel(
      eyebrow: 'SIGNAL COMMAND',
      title: title,
      narrative: narrative,
      accent: selected?.accent ?? widget.threat.accent,
      metrics: [
        _DashboardFocusMetric(
          label: 'Visible',
          value: '$visibleCount/$totalCount',
          accent: const Color(0xFF63BDFF),
        ),
        _DashboardFocusMetric(
          label: 'High Risk',
          value: '${widget.snapshot.highRiskIntelligence}',
          accent: const Color(0xFFFFB44D),
        ),
        _DashboardFocusMetric(
          label: 'Watch',
          value: '${widget.triage.watchCount}',
          accent: const Color(0xFF8EF3C0),
        ),
        _DashboardFocusMetric(
          label: 'Threat',
          value: widget.threat.label,
          accent: widget.threat.accent,
        ),
      ],
    );
  }

  _DashboardFocusModel _dispatchFocusModel(
    _DashboardDispatchItem? selected,
    int visibleCount,
    int totalCount,
  ) {
    final title = selected == null
        ? 'No dispatch chains in this lane'
        : '${selected.dispatchId} • ${selected.status}';
    final narrative =
        selected?.directive ??
        'Switch the dispatch lane to recover active chains and risk posture.';
    return _DashboardFocusModel(
      eyebrow: 'DISPATCH CONTROL',
      title: title,
      narrative: narrative,
      accent: selected?.accent ?? widget.threat.accent,
      metrics: [
        _DashboardFocusMetric(
          label: 'Visible',
          value: '$visibleCount/$totalCount',
          accent: const Color(0xFF63BDFF),
        ),
        _DashboardFocusMetric(
          label: 'Failed',
          value: '${widget.snapshot.totalFailed}',
          accent: const Color(0xFFFF8E9A),
        ),
        _DashboardFocusMetric(
          label: 'Denied',
          value: '${widget.snapshot.totalDenied}',
          accent: const Color(0xFFFFB44D),
        ),
        _DashboardFocusMetric(
          label: 'Executed',
          value: '${widget.snapshot.totalExecuted}',
          accent: const Color(0xFF8EF3C0),
        ),
      ],
    );
  }

  _DashboardFocusModel _siteFocusModel(
    SiteHealthSnapshot? selected,
    int visibleCount,
    int totalCount,
  ) {
    final averageHealth = totalCount == 0
        ? 0.0
        : widget.snapshot.sites.fold<double>(
                0,
                (sum, site) => sum + site.healthScore,
              ) /
              totalCount;
    final title = selected == null
        ? 'No sites in this lane'
        : '${selected.siteId} • ${selected.healthStatus}';
    final narrative = selected == null
        ? 'Switch the site lane to recover posture visibility.'
        : _siteNarrative(selected);
    return _DashboardFocusModel(
      eyebrow: 'SITE POSTURE',
      title: title,
      narrative: narrative,
      accent: selected == null
          ? widget.threat.accent
          : _siteAccent(selected, widget.threat),
      metrics: [
        _DashboardFocusMetric(
          label: 'Visible',
          value: '$visibleCount/$totalCount',
          accent: const Color(0xFF63BDFF),
        ),
        _DashboardFocusMetric(
          label: 'Watch',
          value:
              '${_siteCount(_buildSiteItems(widget.snapshot.sites), _DashboardSiteLane.watch)}',
          accent: const Color(0xFFFFB44D),
        ),
        _DashboardFocusMetric(
          label: 'Strong',
          value:
              '${_siteCount(_buildSiteItems(widget.snapshot.sites), _DashboardSiteLane.strong)}',
          accent: const Color(0xFF8EF3C0),
        ),
        _DashboardFocusMetric(
          label: 'Avg Health',
          value: averageHealth.toStringAsFixed(0),
          accent: const Color(0xFF7AD3FF),
        ),
      ],
    );
  }

  Widget _signalLanePane(
    List<_DashboardSignalItem> allItems,
    List<_DashboardSignalItem> visibleItems,
    _DashboardSignalItem? selected,
  ) {
    return _workspacePaneShell(
      key: const ValueKey('dashboard-workspace-panel-signals'),
      title: 'Signal Lane',
      subtitle:
          '${visibleItems.length} of ${allItems.length} signals are in the active live lane.',
      child: visibleItems.isEmpty
          ? const _MutedLabel(label: 'No signals match the active lane.')
          : Column(
              children: [
                for (final item in visibleItems.take(6)) ...[
                  _WorkspaceListCard(
                    widgetKey: ValueKey(
                      'dashboard-signal-card-${item.badge}-${item.id}',
                    ),
                    selected: selected?.id == item.id,
                    accent: item.accent,
                    eyebrow: item.badge,
                    title: item.title,
                    subtitle: item.subtitle,
                    trailing: item.lane.name.toUpperCase(),
                    onTap: () {
                      setState(() {
                        _selectedSignalId = item.id;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                if (visibleItems.length > 6)
                  OnyxTruncationHint(
                    visibleCount: visibleItems.take(6).length,
                    totalCount: visibleItems.length,
                    subject: 'signal cards',
                    hiddenDescriptor: 'additional cards',
                  ),
              ],
            ),
    );
  }

  Widget _dispatchLanePane(
    List<_DashboardDispatchItem> allItems,
    List<_DashboardDispatchItem> visibleItems,
    _DashboardDispatchItem? selected,
  ) {
    return _workspacePaneShell(
      key: const ValueKey('dashboard-workspace-panel-dispatch'),
      title: 'Dispatch Lane',
      subtitle:
          '${visibleItems.length} of ${allItems.length} dispatch chains are in the active command lane.',
      child: visibleItems.isEmpty
          ? const _MutedLabel(
              label: 'No dispatch chains match the active lane.',
            )
          : Column(
              children: [
                for (final item in visibleItems.take(6)) ...[
                  _WorkspaceListCard(
                    widgetKey: ValueKey(
                      'dashboard-dispatch-card-${item.dispatchId}',
                    ),
                    selected: selected?.dispatchId == item.dispatchId,
                    accent: item.accent,
                    eyebrow: item.status,
                    title: item.dispatchId,
                    subtitle: item.scope,
                    trailing: item.status,
                    onTap: () {
                      setState(() {
                        _selectedDispatchId = item.dispatchId;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                if (visibleItems.length > 6)
                  OnyxTruncationHint(
                    visibleCount: visibleItems.take(6).length,
                    totalCount: visibleItems.length,
                    subject: 'dispatch cards',
                    hiddenDescriptor: 'additional chains',
                  ),
              ],
            ),
    );
  }

  Widget _siteLanePane(
    List<SiteHealthSnapshot> allItems,
    List<SiteHealthSnapshot> visibleItems,
    SiteHealthSnapshot? selected,
  ) {
    return _workspacePaneShell(
      key: const ValueKey('dashboard-workspace-panel-sites'),
      title: 'Site Lane',
      subtitle:
          '${visibleItems.length} of ${allItems.length} sites are visible in the active posture lane.',
      child: visibleItems.isEmpty
          ? const _MutedLabel(label: 'No sites match the active posture lane.')
          : Column(
              children: [
                for (final item in visibleItems.take(5)) ...[
                  _WorkspaceListCard(
                    widgetKey: ValueKey('dashboard-site-card-${item.siteId}'),
                    selected: selected?.siteId == item.siteId,
                    accent: _siteAccent(item, widget.threat),
                    eyebrow: item.healthStatus,
                    title: item.siteId,
                    subtitle: '${item.clientId} • ${item.regionId}',
                    trailing: item.healthScore.toStringAsFixed(0),
                    onTap: () {
                      setState(() {
                        _selectedSiteId = item.siteId;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                if (visibleItems.length > 5)
                  OnyxTruncationHint(
                    visibleCount: visibleItems.take(5).length,
                    totalCount: visibleItems.length,
                    subject: 'site cards',
                    hiddenDescriptor: 'additional sites',
                  ),
              ],
            ),
    );
  }

  Widget _signalDetailPane(
    List<_DashboardSignalItem> allItems,
    List<_DashboardSignalItem> visibleItems,
    _DashboardSignalItem? selected,
  ) {
    return _workspacePaneShell(
      title: 'Signal Board',
      subtitle:
          'Selected signal context and operating guidance for the current live lane.',
      child: selected == null
          ? const _MutedLabel(
              label: 'Select a signal to inspect its command context.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _workspaceHeadlineCard(
                  accent: selected.accent,
                  eyebrow: selected.badge,
                  title: selected.title,
                  subtitle: selected.subtitle,
                  narrative: selected.detail,
                ),
                const SizedBox(height: 10),
                _workspaceMetricGrid([
                  _WorkspaceMetricTileData(
                    label: 'Visible signals',
                    value: '${visibleItems.length}',
                    helper: 'Live lane size',
                    accent: const Color(0xFF63BDFF),
                  ),
                  _WorkspaceMetricTileData(
                    label: 'High risk intel',
                    value: '${widget.snapshot.highRiskIntelligence}',
                    helper: 'Current queue',
                    accent: const Color(0xFFFFB44D),
                  ),
                  _WorkspaceMetricTileData(
                    label: 'Advisories',
                    value: '${widget.triage.advisoryCount}',
                    helper: 'Triage posture',
                    accent: const Color(0xFF8EF3C0),
                  ),
                  _WorkspaceMetricTileData(
                    label: 'Threat state',
                    value: widget.threat.label,
                    helper: 'Global command posture',
                    accent: widget.threat.accent,
                  ),
                ]),
                const SizedBox(height: 10),
                _workspaceNarrativeSplit(
                  leftTitle: 'Signal Directive',
                  leftBody: selected.detail,
                  rightTitle: 'Triage Pressure',
                  rightBody:
                      'A ${widget.triage.advisoryCount} • W ${widget.triage.watchCount} • DC ${widget.triage.dispatchCandidateCount} • Esc ${widget.triage.escalateCount}. Top signals: ${widget.triage.topSignalsSummary}.',
                ),
                const SizedBox(height: 10),
                _workspaceSupportList(
                  title: 'Supporting live reads',
                  rows: visibleItems
                      .where((item) => item.id != selected.id)
                      .take(3)
                      .map((item) => item.title)
                      .toList(growable: false),
                  emptyLabel: 'No supporting signals in this lane.',
                ),
              ],
            ),
    );
  }

  Widget _dispatchDetailPane(
    List<_DashboardDispatchItem> allItems,
    List<_DashboardDispatchItem> visibleItems,
    _DashboardDispatchItem? selected,
  ) {
    return _workspacePaneShell(
      title: 'Dispatch Board',
      subtitle:
          'Selected dispatch chain with the exact operational posture for this lane.',
      child: selected == null
          ? const _MutedLabel(
              label:
                  'Select a dispatch chain to inspect the current control posture.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _workspaceHeadlineCard(
                  accent: selected.accent,
                  eyebrow: selected.status,
                  title: selected.dispatchId,
                  subtitle: selected.scope,
                  narrative: selected.directive,
                ),
                const SizedBox(height: 10),
                _workspaceMetricGrid([
                  _WorkspaceMetricTileData(
                    label: 'Visible chains',
                    value: '${visibleItems.length}',
                    helper: 'Current lane',
                    accent: const Color(0xFF63BDFF),
                  ),
                  _WorkspaceMetricTileData(
                    label: 'Open',
                    value:
                        '${_dispatchCount(allItems, _DashboardDispatchLane.open)}',
                    helper: 'Awaiting closure',
                    accent: const Color(0xFF63BDFF),
                  ),
                  _WorkspaceMetricTileData(
                    label: 'Risk chains',
                    value:
                        '${_dispatchCount(allItems, _DashboardDispatchLane.risk)}',
                    helper: 'Failed or denied',
                    accent: const Color(0xFFFF8E9A),
                  ),
                  _WorkspaceMetricTileData(
                    label: 'Resolved',
                    value:
                        '${_dispatchCount(allItems, _DashboardDispatchLane.resolved)}',
                    helper: 'Closed successfully',
                    accent: const Color(0xFF8EF3C0),
                  ),
                ]),
                const SizedBox(height: 10),
                _workspaceNarrativeSplit(
                  leftTitle: 'Chain Summary',
                  leftBody: selected.summary,
                  rightTitle: 'Command Note',
                  rightBody:
                      'Controller pressure is ${widget.snapshot.controllerPressureIndex.toStringAsFixed(1)} with ${widget.snapshot.totalFailed} failed and ${widget.snapshot.totalDenied} denied dispatches in the broader board.',
                ),
                const SizedBox(height: 10),
                _workspaceSupportList(
                  title: 'Related dispatch context',
                  rows: visibleItems
                      .where((item) => item.dispatchId != selected.dispatchId)
                      .take(3)
                      .map((item) => item.summary)
                      .toList(growable: false),
                  emptyLabel: 'No related dispatch chains in this lane.',
                ),
              ],
            ),
    );
  }

  Widget _siteDetailPane(
    List<SiteHealthSnapshot> allItems,
    List<SiteHealthSnapshot> visibleItems,
    SiteHealthSnapshot? selected,
  ) {
    return _workspacePaneShell(
      title: 'Site Board',
      subtitle:
          'Selected site posture with deployment stress, response tempo, and lane context.',
      child: selected == null
          ? const _MutedLabel(
              label: 'Select a site to inspect its current posture board.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _workspaceHeadlineCard(
                  accent: _siteAccent(selected, widget.threat),
                  eyebrow: selected.healthStatus,
                  title: selected.siteId,
                  subtitle: '${selected.clientId} • ${selected.regionId}',
                  narrative: _siteNarrative(selected),
                ),
                const SizedBox(height: 10),
                _workspaceMetricGrid([
                  _WorkspaceMetricTileData(
                    label: 'Health',
                    value: selected.healthScore.toStringAsFixed(0),
                    helper: 'Operational score',
                    accent: _siteAccent(selected, widget.threat),
                  ),
                  _WorkspaceMetricTileData(
                    label: 'Active',
                    value: '${selected.activeDispatches}',
                    helper: 'Open dispatches',
                    accent: const Color(0xFFFFB44D),
                  ),
                  _WorkspaceMetricTileData(
                    label: 'Failed',
                    value: '${selected.failedCount}',
                    helper: 'Execution failures',
                    accent: const Color(0xFFFF8E9A),
                  ),
                  _WorkspaceMetricTileData(
                    label: 'Response',
                    value: _workspaceResponseLabel(
                      selected.averageResponseMinutes,
                    ),
                    helper: 'Average tempo',
                    accent: const Color(0xFF63BDFF),
                  ),
                ]),
                const SizedBox(height: 10),
                _workspaceNarrativeSplit(
                  leftTitle: 'Deployment Read',
                  leftBody: _siteNarrative(selected),
                  rightTitle: 'Board Context',
                  rightBody:
                      '${visibleItems.length} of ${allItems.length} sites are visible in the active lane. Patrols ${selected.patrolsCompleted} • Check-ins ${selected.guardCheckIns} • Closed incidents ${selected.incidentsClosed}.',
                ),
                const SizedBox(height: 10),
                _workspaceSupportList(
                  title: 'Adjacent site pressure',
                  rows: visibleItems
                      .where((item) => item.siteId != selected.siteId)
                      .take(3)
                      .map(
                        (item) =>
                            '${item.siteId} • ${item.healthStatus} • ${item.activeDispatches} active',
                      )
                      .toList(growable: false),
                  emptyLabel: 'No adjacent sites in this lane.',
                ),
              ],
            ),
    );
  }

  Widget _workspaceFocusBanner(_DashboardFocusModel model) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10273D), Color(0xFF0C1420)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF27425D)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 980;
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                model.eyebrow,
                style: GoogleFonts.inter(
                  color: const Color(0xFF8AA2C0),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                model.title,
                style: GoogleFonts.rajdhani(
                  color: const Color(0xFFEAF2FF),
                  fontSize: 30,
                  height: 0.95,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                model.narrative,
                style: GoogleFonts.inter(
                  color: const Color(0xFFD4E1F3),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ],
          );
          final metrics = Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              for (final metric in model.metrics)
                _focusMetricPill(metric: metric),
            ],
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summary, const SizedBox(height: 12), metrics],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: summary),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: metrics,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _focusMetricPill({required _DashboardFocusMetric metric}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x14000000),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: metric.accent.withValues(alpha: 0.45)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${metric.label} ',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: metric.value,
              style: GoogleFonts.inter(
                color: metric.accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _workspacePaneShell({
    Key? key,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1421),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF243549)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFEAF2FF),
              fontSize: 20,
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

  Widget _workspaceHeadlineCard({
    required Color accent,
    required String eyebrow,
    required String title,
    required String subtitle,
    required String narrative,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102337), Color(0xFF0C131C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF28415B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
            ),
            child: Text(
              eyebrow,
              style: GoogleFonts.inter(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFEAF2FF),
              fontSize: 28,
              height: 0.95,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: const Color(0xFF89A0BE),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            narrative,
            style: GoogleFonts.inter(
              color: const Color(0xFFD9E7FA),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceMetricGrid(List<_WorkspaceMetricTileData> metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cell = width < 760 ? (width - 8) / 2 : (width - 24) / 4;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final metric in metrics)
              _workspaceMetricTile(width: cell, metric: metric),
          ],
        );
      },
    );
  }

  Widget _workspaceMetricTile({
    required double width,
    required _WorkspaceMetricTileData metric,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111C2B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF243549)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: GoogleFonts.inter(
              color: const Color(0xFF8AA2C0),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric.value,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFEAF2FF),
              fontSize: 28,
              height: 0.95,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric.helper,
            style: GoogleFonts.inter(
              color: metric.accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceNarrativeSplit({
    required String leftTitle,
    required String leftBody,
    required String rightTitle,
    required String rightBody,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final left = _workspaceTextBlock(title: leftTitle, body: leftBody);
        final right = _workspaceTextBlock(title: rightTitle, body: rightBody);
        if (constraints.maxWidth < 820) {
          return Column(children: [left, const SizedBox(height: 8), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 8),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _workspaceTextBlock({required String title, required String body}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111C2B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF243549)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFFE8F1FF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.inter(
              color: const Color(0xFF8BA1BF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceSupportList({
    required String title,
    required List<String> rows,
    required String emptyLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111C2B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF243549)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFFE8F1FF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            _MutedLabel(label: emptyLabel)
          else
            for (final row in rows) ...[
              _workspaceSupportRow(row: row),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _workspaceSupportRow({required String row}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 4),
          decoration: const BoxDecoration(
            color: Color(0xFF63BDFF),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            row,
            style: GoogleFonts.inter(
              color: const Color(0xFFD7E4F7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  String? _siteTokenFromSummary(String summary) {
    final match = RegExp(r'at ([A-Z0-9\-]+)').firstMatch(summary);
    return match?.group(1);
  }

  int _siteOperationalLoad(SiteHealthSnapshot site) {
    return (site.activeDispatches * 4) +
        (site.failedCount * 5) +
        (site.deniedCount * 3) +
        (site.executedCount * 2);
  }

  Color _siteAccent(SiteHealthSnapshot site, _ThreatState threat) {
    if (site.failedCount > 0) {
      return const Color(0xFFFF8E9A);
    }
    if (site.activeDispatches > 0 || site.deniedCount > 0) {
      return const Color(0xFFFFB44D);
    }
    if (site.healthStatus == 'STRONG') {
      return const Color(0xFF8EF3C0);
    }
    return threat.softAccent;
  }

  String _siteNarrative(SiteHealthSnapshot site) {
    if (site.failedCount > 0) {
      return 'Execution failures are now shaping the posture at ${site.siteId}. Push command attention here before field pressure spreads.';
    }
    if (site.activeDispatches > 0) {
      return '${site.siteId} is carrying live dispatch load. Keep patrol coverage and response tempo in the front channel.';
    }
    if (site.deniedCount > 0) {
      return 'Denials are suppressing part of the response chain at ${site.siteId}, so verify whether the site is still carrying latent exposure.';
    }
    if (site.healthStatus == 'STRONG') {
      return '${site.siteId} is holding strong posture with clean patrol and response flow. Use it as a baseline lane.';
    }
    return '${site.siteId} is stable, but command should keep the next patrol loop and response tempo in view.';
  }

  String _workspaceResponseLabel(double minutes) {
    if (minutes <= 0) {
      return 'Pending';
    }
    return '${minutes.toStringAsFixed(1)}m';
  }
}

enum _DashboardWorkspaceMode { signals, dispatch, sites }

enum _DashboardSignalLane { all, intelligence, field, closures }

enum _DashboardDispatchLane { all, open, risk, resolved }

enum _DashboardSiteLane { all, active, watch, strong }

class _DashboardSignalItem {
  final String id;
  final String title;
  final String subtitle;
  final String detail;
  final _DashboardSignalLane lane;
  final String badge;
  final Color accent;

  const _DashboardSignalItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.lane,
    required this.badge,
    required this.accent,
  });
}

class _DashboardDispatchItem {
  final String dispatchId;
  final String status;
  final String scope;
  final String summary;
  final String directive;
  final _DashboardDispatchLane lane;
  final Color accent;

  const _DashboardDispatchItem({
    required this.dispatchId,
    required this.status,
    required this.scope,
    required this.summary,
    required this.directive,
    required this.lane,
    required this.accent,
  });
}

class _DashboardFocusModel {
  final String eyebrow;
  final String title;
  final String narrative;
  final Color accent;
  final List<_DashboardFocusMetric> metrics;

  const _DashboardFocusModel({
    required this.eyebrow,
    required this.title,
    required this.narrative,
    required this.accent,
    required this.metrics,
  });
}

class _DashboardFocusMetric {
  final String label;
  final String value;
  final Color accent;

  const _DashboardFocusMetric({
    required this.label,
    required this.value,
    required this.accent,
  });
}

class _WorkspaceMetricTileData {
  final String label;
  final String value;
  final String helper;
  final Color accent;

  const _WorkspaceMetricTileData({
    required this.label,
    required this.value,
    required this.helper,
    required this.accent,
  });
}

class _WorkspaceModeChip extends StatelessWidget {
  final Key widgetKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WorkspaceModeChip({
    required this.widgetKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: widgetKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF123244) : const Color(0xFF111C2B),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF3F87C9) : const Color(0xFF243549),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? const Color(0xFFEAF2FF) : const Color(0xFF8EA4C2),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _WorkspaceFilterChip extends StatelessWidget {
  final Key widgetKey;
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _WorkspaceFilterChip({
    required this.widgetKey,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: widgetKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF10273A) : const Color(0xFF111C2B),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF3F87C9) : const Color(0xFF243549),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: selected
                    ? const Color(0xFFEAF2FF)
                    : const Color(0xFF8EA4C2),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF0E1C2A)
                    : const Color(0xFF0B1421),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                value,
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF2FF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceListCard extends StatelessWidget {
  final Key widgetKey;
  final bool selected;
  final Color accent;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;

  const _WorkspaceListCard({
    required this.widgetKey,
    required this.selected,
    required this.accent,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: widgetKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF11273A), Color(0xFF0D1620)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : const Color(0xFF111C2B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : const Color(0xFF243549),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: GoogleFonts.inter(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF2FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8EA4C2),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              trailing,
              style: GoogleFonts.rajdhani(
                color: accent,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RightRail extends StatelessWidget {
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
  final List<DispatchEvent> allEvents;
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
    required this.allEvents,
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

  ({String clientId, String siteId})? _siteActivityCommandScope() {
    final scopedRows = allEvents
        .whereType<IntelligenceReceived>()
        .where((event) => siteActivity.eventIds.contains(event.eventId))
        .toList(growable: false);
    if (scopedRows.isEmpty) {
      return null;
    }
    final clientIds = scopedRows
        .map((event) => event.clientId.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final siteIds = scopedRows
        .map((event) => event.siteId.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (clientIds.length != 1 || siteIds.length != 1) {
      return null;
    }
    return (clientId: clientIds.first, siteId: siteIds.first);
  }

  List<String> _siteActivityHistoryDatesForScope(
    String clientId,
    String siteId,
  ) {
    final reportDates =
        allEvents
            .whereType<IntelligenceReceived>()
            .where(
              (event) =>
                  event.clientId.trim() == clientId &&
                  event.siteId.trim() == siteId &&
                  ((event.sourceType.trim().toLowerCase() == 'dvr') ||
                      (event.sourceType.trim().toLowerCase() == 'cctv')),
            )
            .map((event) {
              final utc = event.occurredAt.toUtc();
              String two(int value) => value.toString().padLeft(2, '0');
              return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-${two(utc.day)}';
            })
            .toSet()
            .toList(growable: false)
          ..sort((a, b) => b.compareTo(a));
    return reportDates;
  }

  String _siteActivityReviewCommand({
    required String clientId,
    required String siteId,
    required String reportDate,
  }) {
    return '/activityreview $clientId $siteId $reportDate';
  }

  String _siteActivityCaseFileCommand({
    required String clientId,
    required String siteId,
    required String reportDate,
  }) {
    return '/activitycase json $clientId $siteId $reportDate';
  }

  String _siteActivityTruthJson() {
    final sovereignReport = morningSovereignReport;
    final siteActivityTrend = sovereignReport == null
        ? null
        : _siteActivityTrendFor(sovereignReport, siteActivity);
    final scope = _siteActivityCommandScope();
    final historyDates = scope == null
        ? const <String>[]
        : _siteActivityHistoryDatesForScope(scope.clientId, scope.siteId);
    return const JsonEncoder.withIndent('  ').convert({
      'scope': {
        'reportDate': sovereignReport?.date,
        'generatedAtUtc': sovereignReport?.generatedAtUtc.toIso8601String(),
        if (scope != null) 'clientId': scope.clientId,
        if (scope != null) 'siteId': scope.siteId,
      },
      if (scope != null)
        'reviewShortcuts': buildReviewShortcuts(
          currentReportDate: historyDates.isEmpty ? '' : historyDates.first,
          previousReportDate: historyDates.length > 1 ? historyDates[1] : null,
          reviewCommandBuilder: (reportDate) => _siteActivityReviewCommand(
            clientId: scope.clientId,
            siteId: scope.siteId,
            reportDate: reportDate,
          ),
          caseFileCommandBuilder: (reportDate) => _siteActivityCaseFileCommand(
            clientId: scope.clientId,
            siteId: scope.siteId,
            reportDate: reportDate,
          ),
        ),
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
    final scope = _siteActivityCommandScope();
    final historyDates = scope == null
        ? const <String>[]
        : _siteActivityHistoryDatesForScope(scope.clientId, scope.siteId);
    return [
      'metric,value',
      'report_date,${sovereignReport?.date ?? ''}',
      'generated_at_utc,${sovereignReport?.generatedAtUtc.toIso8601String() ?? ''}',
      if (scope != null) 'client_id,${scope.clientId}',
      if (scope != null) 'site_id,${scope.siteId}',
      if (scope != null)
        ...buildReviewShortcutCsvRows(
          currentReportDate: historyDates.isEmpty ? '' : historyDates.first,
          previousReportDate: historyDates.length > 1 ? historyDates[1] : null,
          currentReviewMetric: 'current_review_command',
          currentCaseMetric: 'current_case_file_command',
          previousReviewMetric: 'previous_review_command',
          previousCaseMetric: 'previous_case_file_command',
          reviewCommandBuilder: (reportDate) => _siteActivityReviewCommand(
            clientId: scope.clientId,
            siteId: scope.siteId,
            reportDate: reportDate,
          ),
          caseFileCommandBuilder: (reportDate) => _siteActivityCaseFileCommand(
            clientId: scope.clientId,
            siteId: scope.siteId,
            reportDate: reportDate,
          ),
        ),
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

  void _openSiteActivityEventsReview() {
    if (onOpenEventsForScope == null || siteActivity.eventIds.isEmpty) {
      return;
    }
    onOpenEventsForScope!(siteActivity.eventIds, siteActivity.selectedEventId);
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
                    _DashboardAdvancedExportPanel(
                      canCopySiteActivityReview:
                          siteActivity.eventIds.isNotEmpty,
                      siteActivityReviewJson: _siteActivityReviewJson(),
                      onOpenSiteActivityEventsReview:
                          onOpenEventsForScope != null &&
                              siteActivity.eventIds.isNotEmpty
                          ? _openSiteActivityEventsReview
                          : null,
                      guardFailureTraceText: _guardFailureTraceText(
                        recentFailureTraces,
                        guardLastFailureReason,
                      ),
                      guardPolicyTelemetryJson: _guardPolicyTelemetryJson(),
                      guardPolicyTelemetryCsv: _guardPolicyTelemetryCsv(),
                      guardCoachingTelemetryJson: _guardCoachingTelemetryJson(),
                      guardCoachingTelemetryCsv: _guardCoachingTelemetryCsv(),
                      siteActivityTruthJson: _siteActivityTruthJson(),
                      siteActivityTruthCsv: _siteActivityTruthCsv(),
                      siteActivityTelegramSummary:
                          _siteActivityTelegramSummary(),
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

class _DashboardExportReceipt {
  final String headline;
  final String detail;
  final IconData icon;
  final Color accent;

  const _DashboardExportReceipt({
    required this.headline,
    required this.detail,
    required this.icon,
    required this.accent,
  });
}

class _DashboardAdvancedExportPanel extends StatefulWidget {
  final bool canCopySiteActivityReview;
  final String siteActivityReviewJson;
  final VoidCallback? onOpenSiteActivityEventsReview;
  final String guardFailureTraceText;
  final String guardPolicyTelemetryJson;
  final String guardPolicyTelemetryCsv;
  final String guardCoachingTelemetryJson;
  final String guardCoachingTelemetryCsv;
  final String siteActivityTruthJson;
  final String siteActivityTruthCsv;
  final String siteActivityTelegramSummary;

  const _DashboardAdvancedExportPanel({
    required this.canCopySiteActivityReview,
    required this.siteActivityReviewJson,
    required this.onOpenSiteActivityEventsReview,
    required this.guardFailureTraceText,
    required this.guardPolicyTelemetryJson,
    required this.guardPolicyTelemetryCsv,
    required this.guardCoachingTelemetryJson,
    required this.guardCoachingTelemetryCsv,
    required this.siteActivityTruthJson,
    required this.siteActivityTruthCsv,
    required this.siteActivityTelegramSummary,
  });

  @override
  State<_DashboardAdvancedExportPanel> createState() =>
      _DashboardAdvancedExportPanelState();
}

class _DashboardAdvancedExportPanelState
    extends State<_DashboardAdvancedExportPanel> {
  static const _snapshotFiles = DispatchSnapshotFileService();
  static const _textShare = TextShareService();
  static const _emailBridge = EmailBridgeService();

  static const _defaultReceipt = _DashboardExportReceipt(
    headline: 'Export relay ready',
    detail:
        'Copy, share, download, or open a scoped handoff from this console.',
    icon: Icons.hub_outlined,
    accent: Color(0xFF8FD1FF),
  );

  _DashboardExportReceipt _receipt = _defaultReceipt;

  void _setReceipt(_DashboardExportReceipt receipt) {
    if (!mounted) {
      return;
    }
    setState(() {
      _receipt = receipt;
    });
  }

  Future<void> _copyText({
    required String text,
    required _DashboardExportReceipt receipt,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    _setReceipt(receipt);
  }

  Future<void> _downloadJson({
    required String filename,
    required String contents,
    required _DashboardExportReceipt receipt,
  }) async {
    await _snapshotFiles.downloadJsonFile(
      filename: filename,
      contents: contents,
    );
    _setReceipt(receipt);
  }

  Future<void> _downloadText({
    required String filename,
    required String contents,
    required _DashboardExportReceipt receipt,
  }) async {
    await _snapshotFiles.downloadTextFile(
      filename: filename,
      contents: contents,
    );
    _setReceipt(receipt);
  }

  Future<void> _shareText({
    required String title,
    required String text,
    required _DashboardExportReceipt successReceipt,
    required _DashboardExportReceipt fallbackReceipt,
  }) async {
    if (_textShare.supported) {
      final shared = await _textShare.shareText(title: title, text: text);
      if (shared) {
        _setReceipt(successReceipt);
        return;
      }
    }
    await Clipboard.setData(ClipboardData(text: '$title\n\n$text'));
    _setReceipt(fallbackReceipt);
  }

  Future<void> _openMailDraft({
    required String subject,
    required String body,
    required _DashboardExportReceipt successReceipt,
    required _DashboardExportReceipt fallbackReceipt,
  }) async {
    if (_emailBridge.supported) {
      final opened = await _emailBridge.openMailDraft(
        subject: subject,
        body: body,
      );
      if (opened) {
        _setReceipt(successReceipt);
        return;
      }
    }
    await Clipboard.setData(ClipboardData(text: 'Subject: $subject\n\n$body'));
    _setReceipt(fallbackReceipt);
  }

  void _openSiteActivityEventsReview() {
    final callback = widget.onOpenSiteActivityEventsReview;
    if (callback == null) {
      return;
    }
    callback();
    _setReceipt(
      const _DashboardExportReceipt(
        headline: 'Events review opened',
        detail:
            'Scoped site activity evidence was handed off into the forensic lane.',
        icon: Icons.route_outlined,
        accent: Color(0xFF8FD1FF),
      ),
    );
  }

  Widget _section({
    required String title,
    required Color accent,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0x12000000),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required Future<void> Function()? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: TextButton(
        onPressed: onPressed == null ? null : () async => onPressed(),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _receiptPanel() {
    return Container(
      key: const ValueKey('dashboard-advanced-export-receipt'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _receipt.accent.withValues(alpha: 0.12),
        border: Border.all(color: _receipt.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _receipt.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _receipt.accent.withValues(alpha: 0.28),
              ),
            ),
            child: Icon(_receipt.icon, size: 16, color: _receipt.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last handoff',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9FB6D5),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _receipt.headline,
                  key: const ValueKey(
                    'dashboard-advanced-export-receipt-headline',
                  ),
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE7F0FF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _receipt.detail,
                  key: const ValueKey(
                    'dashboard-advanced-export-receipt-detail',
                  ),
                  style: GoogleFonts.inter(
                    color: const Color(0xFFB8CBE7),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF8FD1FF);
    const gold = Color(0xFFF5C27A);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _receiptPanel(),
          const SizedBox(height: 10),
          _section(
            title: 'Site Activity Handoff',
            accent: cyan,
            children: [
              _actionButton(
                label: 'Copy Site Activity Review JSON',
                color: cyan,
                onPressed: !widget.canCopySiteActivityReview
                    ? null
                    : () => _copyText(
                        text: widget.siteActivityReviewJson,
                        receipt: const _DashboardExportReceipt(
                          headline: 'Review JSON copied',
                          detail:
                              'Site activity review payload is staged on the command clipboard.',
                          icon: Icons.content_copy_outlined,
                          accent: cyan,
                        ),
                      ),
              ),
              _actionButton(
                label: 'Open Site Activity Events Review',
                color: cyan,
                onPressed: widget.onOpenSiteActivityEventsReview == null
                    ? null
                    : () async => _openSiteActivityEventsReview(),
              ),
              _actionButton(
                label: 'Copy Site Activity JSON',
                color: cyan,
                onPressed: () => _copyText(
                  text: widget.siteActivityTruthJson,
                  receipt: const _DashboardExportReceipt(
                    headline: 'Site activity JSON copied',
                    detail:
                        'Operational truth payload is staged for command review.',
                    icon: Icons.content_copy_outlined,
                    accent: cyan,
                  ),
                ),
              ),
              _actionButton(
                label: 'Copy Site Activity CSV',
                color: cyan,
                onPressed: () => _copyText(
                  text: widget.siteActivityTruthCsv,
                  receipt: const _DashboardExportReceipt(
                    headline: 'Site activity CSV copied',
                    detail: 'Flat export is ready for spreadsheet handoff.',
                    icon: Icons.table_chart_outlined,
                    accent: cyan,
                  ),
                ),
              ),
              _actionButton(
                label: 'Share Site Activity Pack',
                color: cyan,
                onPressed: () => _shareText(
                  title: 'ONYX Site Activity Truth',
                  text: widget.siteActivityTruthJson,
                  successReceipt: const _DashboardExportReceipt(
                    headline: 'Site activity pack shared',
                    detail:
                        'The command rail handed the site activity payload to a share target.',
                    icon: Icons.share_outlined,
                    accent: cyan,
                  ),
                  fallbackReceipt: const _DashboardExportReceipt(
                    headline: 'Site activity pack staged',
                    detail:
                        'Native share is unavailable, so the site activity payload was copied for manual handoff.',
                    icon: Icons.copy_all_outlined,
                    accent: cyan,
                  ),
                ),
              ),
              _actionButton(
                label: 'Copy Site Activity Telegram',
                color: cyan,
                onPressed: () => _copyText(
                  text: widget.siteActivityTelegramSummary,
                  receipt: const _DashboardExportReceipt(
                    headline: 'Telegram summary copied',
                    detail:
                        'Operator-ready messaging summary is staged on the clipboard.',
                    icon: Icons.send_outlined,
                    accent: cyan,
                  ),
                ),
              ),
              _actionButton(
                label: 'Share Site Activity Telegram',
                color: cyan,
                onPressed: () => _shareText(
                  title: 'ONYX Site Activity Telegram Summary',
                  text: widget.siteActivityTelegramSummary,
                  successReceipt: const _DashboardExportReceipt(
                    headline: 'Telegram summary shared',
                    detail:
                        'Client-ready summary left the command rail through a share target.',
                    icon: Icons.share_outlined,
                    accent: cyan,
                  ),
                  fallbackReceipt: const _DashboardExportReceipt(
                    headline: 'Telegram summary staged',
                    detail:
                        'Native share is unavailable, so the Telegram-ready summary was copied for operator handoff.',
                    icon: Icons.copy_all_outlined,
                    accent: cyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _section(
            title: 'Failure Trace',
            accent: cyan,
            children: [
              _actionButton(
                label: 'Copy Failure Trace',
                color: cyan,
                onPressed: () => _copyText(
                  text: widget.guardFailureTraceText,
                  receipt: const _DashboardExportReceipt(
                    headline: 'Failure trace copied',
                    detail:
                        'Latest guard sync failure evidence is staged for review.',
                    icon: Icons.content_copy_outlined,
                    accent: cyan,
                  ),
                ),
              ),
              _actionButton(
                label: 'Email Failure Trace',
                color: cyan,
                onPressed: () => _openMailDraft(
                  subject: 'ONYX Guard Sync Failure Trace',
                  body: widget.guardFailureTraceText,
                  successReceipt: const _DashboardExportReceipt(
                    headline: 'Failure trace mail opened',
                    detail:
                        'An email draft was staged with the guard sync trace.',
                    icon: Icons.mark_email_read_outlined,
                    accent: cyan,
                  ),
                  fallbackReceipt: const _DashboardExportReceipt(
                    headline: 'Failure trace mail staged',
                    detail:
                        'Mail bridge is unavailable, so a mail-ready failure trace draft was copied to the clipboard.',
                    icon: Icons.copy_all_outlined,
                    accent: cyan,
                  ),
                ),
              ),
              _actionButton(
                label: 'Download Failure Trace',
                color: cyan,
                onPressed: !_snapshotFiles.supported
                    ? null
                    : () => _downloadText(
                        filename: 'guard-sync-failure-trace.txt',
                        contents: widget.guardFailureTraceText,
                        receipt: const _DashboardExportReceipt(
                          headline: 'Failure trace download started',
                          detail:
                              'A text export of the guard sync trace is being saved.',
                          icon: Icons.download_outlined,
                          accent: cyan,
                        ),
                      ),
              ),
              _actionButton(
                label: 'Share Failure Trace',
                color: cyan,
                onPressed: () => _shareText(
                  title: 'ONYX Guard Sync Failure Trace',
                  text: widget.guardFailureTraceText,
                  successReceipt: const _DashboardExportReceipt(
                    headline: 'Failure trace shared',
                    detail:
                        'Guard sync trace left the dashboard through a share target.',
                    icon: Icons.share_outlined,
                    accent: cyan,
                  ),
                  fallbackReceipt: const _DashboardExportReceipt(
                    headline: 'Failure trace staged',
                    detail:
                        'Native share is unavailable, so the failure trace was copied for manual handoff.',
                    icon: Icons.copy_all_outlined,
                    accent: cyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _section(
            title: 'Policy Telemetry',
            accent: gold,
            children: [
              _actionButton(
                label: 'Copy Policy Telemetry JSON',
                color: gold,
                onPressed: () => _copyText(
                  text: widget.guardPolicyTelemetryJson,
                  receipt: const _DashboardExportReceipt(
                    headline: 'Policy telemetry JSON copied',
                    detail:
                        'Structured policy telemetry is staged for governance review.',
                    icon: Icons.content_copy_outlined,
                    accent: gold,
                  ),
                ),
              ),
              _actionButton(
                label: 'Copy Policy Telemetry CSV',
                color: gold,
                onPressed: () => _copyText(
                  text: widget.guardPolicyTelemetryCsv,
                  receipt: const _DashboardExportReceipt(
                    headline: 'Policy telemetry CSV copied',
                    detail:
                        'Flat policy metrics are ready for spreadsheet analysis.',
                    icon: Icons.table_chart_outlined,
                    accent: gold,
                  ),
                ),
              ),
              _actionButton(
                label: 'Download Policy JSON',
                color: gold,
                onPressed: !_snapshotFiles.supported
                    ? null
                    : () => _downloadJson(
                        filename: 'guard-policy-telemetry.json',
                        contents: widget.guardPolicyTelemetryJson,
                        receipt: const _DashboardExportReceipt(
                          headline: 'Policy JSON download started',
                          detail:
                              'Governance telemetry export is being saved to disk.',
                          icon: Icons.download_outlined,
                          accent: gold,
                        ),
                      ),
              ),
              _actionButton(
                label: 'Download Policy CSV',
                color: gold,
                onPressed: !_snapshotFiles.supported
                    ? null
                    : () => _downloadText(
                        filename: 'guard-policy-telemetry.csv',
                        contents: widget.guardPolicyTelemetryCsv,
                        receipt: const _DashboardExportReceipt(
                          headline: 'Policy CSV download started',
                          detail:
                              'Flat governance telemetry export is being saved to disk.',
                          icon: Icons.download_outlined,
                          accent: gold,
                        ),
                      ),
              ),
              _actionButton(
                label: 'Share Policy Pack',
                color: gold,
                onPressed: () => _shareText(
                  title: 'ONYX Guard Policy Telemetry',
                  text: widget.guardPolicyTelemetryJson,
                  successReceipt: const _DashboardExportReceipt(
                    headline: 'Policy pack shared',
                    detail:
                        'Governance telemetry left the dashboard through a share target.',
                    icon: Icons.share_outlined,
                    accent: gold,
                  ),
                  fallbackReceipt: const _DashboardExportReceipt(
                    headline: 'Policy pack staged',
                    detail:
                        'Native share is unavailable, so the policy telemetry pack was copied for governance handoff.',
                    icon: Icons.copy_all_outlined,
                    accent: gold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _section(
            title: 'Coaching Telemetry',
            accent: cyan,
            children: [
              _actionButton(
                label: 'Copy Coaching Telemetry JSON',
                color: cyan,
                onPressed: () => _copyText(
                  text: widget.guardCoachingTelemetryJson,
                  receipt: const _DashboardExportReceipt(
                    headline: 'Coaching telemetry JSON copied',
                    detail:
                        'Coaching feedback telemetry is staged for operator review.',
                    icon: Icons.content_copy_outlined,
                    accent: cyan,
                  ),
                ),
              ),
              _actionButton(
                label: 'Copy Coaching Telemetry CSV',
                color: cyan,
                onPressed: () => _copyText(
                  text: widget.guardCoachingTelemetryCsv,
                  receipt: const _DashboardExportReceipt(
                    headline: 'Coaching telemetry CSV copied',
                    detail:
                        'Flat coaching metrics are ready for spreadsheet analysis.',
                    icon: Icons.table_chart_outlined,
                    accent: cyan,
                  ),
                ),
              ),
              _actionButton(
                label: 'Download Coaching JSON',
                color: cyan,
                onPressed: !_snapshotFiles.supported
                    ? null
                    : () => _downloadJson(
                        filename: 'guard-coaching-telemetry.json',
                        contents: widget.guardCoachingTelemetryJson,
                        receipt: const _DashboardExportReceipt(
                          headline: 'Coaching JSON download started',
                          detail:
                              'Coaching telemetry export is being saved to disk.',
                          icon: Icons.download_outlined,
                          accent: cyan,
                        ),
                      ),
              ),
              _actionButton(
                label: 'Share Coaching Pack',
                color: cyan,
                onPressed: () => _shareText(
                  title: 'ONYX Guard Coaching Telemetry',
                  text: widget.guardCoachingTelemetryJson,
                  successReceipt: const _DashboardExportReceipt(
                    headline: 'Coaching pack shared',
                    detail:
                        'Coaching telemetry left the dashboard through a share target.',
                    icon: Icons.share_outlined,
                    accent: cyan,
                  ),
                  fallbackReceipt: const _DashboardExportReceipt(
                    headline: 'Coaching pack staged',
                    detail:
                        'Native share is unavailable, so the coaching telemetry pack was copied for operator handoff.',
                    icon: Icons.copy_all_outlined,
                    accent: cyan,
                  ),
                ),
              ),
            ],
          ),
        ],
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
