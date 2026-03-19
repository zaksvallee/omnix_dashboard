import '../domain/events/intelligence_received.dart';
import '../ui/video_fleet_scope_health_view.dart';
import 'video_fleet_scope_activity_projector.dart';
import 'dvr_scope_config.dart';
import 'monitoring_shift_schedule_service.dart';
import 'video_fleet_scope_runtime_state.dart';

class VideoFleetScopeHealthProjector {
  final VideoFleetScopeActivityProjector activityProjector;

  const VideoFleetScopeHealthProjector({
    this.activityProjector = const VideoFleetScopeActivityProjector(),
  });

  List<VideoFleetScopeHealthView> project({
    required List<DvrScopeConfig> scopes,
    required Iterable<IntelligenceReceived> events,
    required DateTime nowUtc,
    required Set<String> activeWatchScopeKeys,
    required MonitoringShiftSchedule Function(String clientId, String siteId)
    scheduleForScope,
    required String Function(String clientId, String siteId) siteNameForScope,
    required String Function(Uri? eventsUri) endpointLabelForScope,
    required String Function(String? cameraId) cameraLabelForId,
    required Map<String, VideoFleetScopeRuntimeState> runtimeStateByScope,
  }) {
    if (scopes.isEmpty) {
      return const [];
    }
    final activityByScope = activityProjector.project(
      scopes: scopes,
      events: events,
      nowUtc: nowUtc,
    );
    final output = <VideoFleetScopeHealthView>[];
    for (final scope in scopes) {
      final activity =
          activityByScope[scope.scopeKey] ??
          const VideoFleetScopeActivitySnapshot(
            recentEvents: 0,
            lastSeenAtUtc: null,
            latestEvent: null,
          );
      final recentEvents = activity.recentEvents;
      final lastSeenAtUtc = activity.lastSeenAtUtc;
      final latestEvent = activity.latestEvent;
      final watchActive = activeWatchScopeKeys.contains(scope.scopeKey);
      final runtimeState = runtimeStateByScope[scope.scopeKey];
      final monitoringLimited =
          watchActive && runtimeState?.monitoringAvailable == false;
      final schedule = scheduleForScope(scope.clientId, scope.siteId);
      final scheduleSnapshot = schedule.snapshotAt(nowUtc.toLocal());
      final watchActivationGapLabel = _watchActivationGapLabel(
        schedule: schedule,
        snapshot: scheduleSnapshot,
        watchActive: watchActive,
      );
      final freshnessLabel = _freshnessLabel(
        watchActive: watchActive,
        lastSeenAtUtc: lastSeenAtUtc,
        nowUtc: nowUtc,
      );
      final isStale = watchActive && freshnessLabel == 'Stale';
      output.add(
        VideoFleetScopeHealthView(
          clientId: scope.clientId,
          siteId: scope.siteId,
          siteName: siteNameForScope(scope.clientId, scope.siteId),
          endpointLabel: endpointLabelForScope(scope.eventsUri),
          statusLabel: monitoringLimited
              ? 'LIMITED WATCH'
              : watchActive
              ? (lastSeenAtUtc != null &&
                        nowUtc.difference(lastSeenAtUtc).inMinutes <= 30
                    ? 'LIVE'
                    : 'ACTIVE WATCH')
              : (schedule.enabled ? 'WATCH READY' : 'STANDBY'),
          watchLabel: monitoringLimited
              ? 'LIMITED'
              : watchActive
              ? 'ACTIVE'
              : (schedule.enabled ? 'SCHEDULED' : 'OFF'),
          recentEvents: recentEvents,
          lastSeenLabel: lastSeenAtUtc == null
              ? 'idle'
              : '${lastSeenAtUtc.toUtc().hour.toString().padLeft(2, '0')}:${lastSeenAtUtc.toUtc().minute.toString().padLeft(2, '0')} UTC',
          freshnessLabel: freshnessLabel,
          isStale: isStale,
          watchWindowLabel: _watchWindowLabel(schedule),
          watchWindowStateLabel: _watchWindowStateLabel(
            schedule,
            scheduleSnapshot,
            monitoringLimited: monitoringLimited,
          ),
          watchActivationGapLabel: watchActivationGapLabel,
          monitoringAvailabilityDetail:
              runtimeState?.monitoringAvailabilityDetail,
          operatorOutcomeLabel: runtimeState?.operatorOutcomeLabel,
          lastRecoveryLabel: runtimeState?.lastRecoveryLabel,
          latestSceneReviewLabel: runtimeState?.latestSceneReviewLabel,
          latestSceneReviewSummary: runtimeState?.latestSceneReviewSummary,
          latestSceneDecisionLabel: runtimeState?.latestSceneDecisionLabel,
          latestSceneDecisionSummary: runtimeState?.latestSceneDecisionSummary,
          latestClientDecisionLabel: runtimeState?.latestClientDecisionLabel,
          latestClientDecisionSummary:
              runtimeState?.latestClientDecisionSummary,
          latestClientDecisionAtUtc: runtimeState?.latestClientDecisionAtUtc,
          alertCount: runtimeState?.alertCount ?? 0,
          repeatCount: runtimeState?.repeatCount ?? 0,
          escalationCount: runtimeState?.escalationCount ?? 0,
          suppressedCount: runtimeState?.suppressedCount ?? 0,
          actionHistory: runtimeState?.actionHistory ?? const <String>[],
          suppressedHistory:
              runtimeState?.suppressedHistory ?? const <String>[],
          latestEventLabel: latestEvent?.headline,
          latestIncidentReference: latestEvent?.intelligenceId,
          latestEventTimeLabel: latestEvent == null
              ? null
              : '${latestEvent.occurredAt.toUtc().hour.toString().padLeft(2, '0')}:${latestEvent.occurredAt.toUtc().minute.toString().padLeft(2, '0')} UTC',
          latestCameraLabel: latestEvent == null
              ? null
              : cameraLabelForId(latestEvent.cameraId),
          latestRiskScore: latestEvent?.riskScore,
          latestFaceMatchId: latestEvent?.faceMatchId,
          latestFaceConfidence: latestEvent?.faceConfidence,
          latestPlateNumber: latestEvent?.plateNumber,
          latestPlateConfidence: latestEvent?.plateConfidence,
        ),
      );
    }
    output.sort((a, b) {
      final aGap = a.hasWatchActivationGap ? 1 : 0;
      final bGap = b.hasWatchActivationGap ? 1 : 0;
      if (aGap != bGap) {
        return bGap.compareTo(aGap);
      }
      final aActive = (a.watchLabel == 'ACTIVE' || a.watchLabel == 'LIMITED')
          ? 1
          : 0;
      final bActive = (b.watchLabel == 'ACTIVE' || b.watchLabel == 'LIMITED')
          ? 1
          : 0;
      if (aActive != bActive) {
        return bActive.compareTo(aActive);
      }
      final aStale = a.isStale ? 1 : 0;
      final bStale = b.isStale ? 1 : 0;
      if (aStale != bStale) {
        return bStale.compareTo(aStale);
      }
      final aRecovered = a.hasRecentRecovery ? 1 : 0;
      final bRecovered = b.hasRecentRecovery ? 1 : 0;
      if (aRecovered != bRecovered) {
        return bRecovered.compareTo(aRecovered);
      }
      if (a.recentEvents != b.recentEvents) {
        return b.recentEvents.compareTo(a.recentEvents);
      }
      return a.siteName.compareTo(b.siteName);
    });
    return output;
  }

  String? _watchWindowLabel(MonitoringShiftSchedule schedule) {
    if (!schedule.enabled) {
      return null;
    }
    final start = _clockLabel(schedule.startHour, schedule.startMinute);
    final end = _clockLabel(schedule.endHour, schedule.endMinute);
    if (start == end) {
      return '24h';
    }
    return '$start-$end';
  }

  String? _watchActivationGapLabel({
    required MonitoringShiftSchedule schedule,
    required MonitoringShiftScheduleSnapshot snapshot,
    required bool watchActive,
  }) {
    if (!schedule.enabled) {
      return null;
    }
    if (snapshot.active && !watchActive) {
      return 'MISSED START';
    }
    if (!snapshot.active && watchActive) {
      return 'OUTSIDE WINDOW';
    }
    return null;
  }

  String? _watchWindowStateLabel(
    MonitoringShiftSchedule schedule,
    MonitoringShiftScheduleSnapshot snapshot, {
    required bool monitoringLimited,
  }) {
    if (!schedule.enabled) {
      return null;
    }
    if (snapshot.active) {
      return monitoringLimited ? 'IN WINDOW • LIMITED' : 'IN WINDOW';
    }
    final next = snapshot.nextTransitionLocal;
    if (next == null) {
      return null;
    }
    return 'NEXT ${_clockLabel(next.hour, next.minute)}';
  }

  String _clockLabel(int hour, int minute) {
    return '${hour.clamp(0, 23).toString().padLeft(2, '0')}:${minute.clamp(0, 59).toString().padLeft(2, '0')}';
  }

  String _freshnessLabel({
    required bool watchActive,
    required DateTime? lastSeenAtUtc,
    required DateTime nowUtc,
  }) {
    if (lastSeenAtUtc == null) {
      return watchActive ? 'Quiet' : 'Idle';
    }
    final ageMinutes = nowUtc.difference(lastSeenAtUtc).inMinutes;
    if (ageMinutes <= 15) {
      return 'Fresh';
    }
    if (ageMinutes <= 60) {
      return 'Recent';
    }
    return watchActive ? 'Stale' : 'Idle';
  }
}
