import '../domain/events/intelligence_received.dart';
import '../ui/video_fleet_scope_health_view.dart';
import 'dvr_scope_config.dart';
import 'monitoring_shift_schedule_service.dart';
import 'monitoring_watch_outcome_cue_store.dart';
import 'monitoring_watch_recovery_store.dart';
import 'monitoring_watch_runtime_store.dart';
import 'video_fleet_scope_health_projector.dart';
import 'video_fleet_scope_runtime_state_resolver.dart';
import 'video_fleet_scope_summary_formatter.dart';

class VideoFleetScopePresentationService {
  final VideoFleetScopeRuntimeStateResolver runtimeStateResolver;
  final VideoFleetScopeSummaryFormatter summaryFormatter;
  final VideoFleetScopeHealthProjector healthProjector;

  const VideoFleetScopePresentationService({
    required this.runtimeStateResolver,
    this.summaryFormatter = const VideoFleetScopeSummaryFormatter(),
    this.healthProjector = const VideoFleetScopeHealthProjector(),
  });

  String formatSummary({
    required List<DvrScopeConfig> scopes,
    required Iterable<IntelligenceReceived> events,
    required DateTime nowUtc,
    required String Function(String clientId, String siteId) siteNameForScope,
    required String Function(Uri? eventsUri) endpointLabelForScope,
    int maxScopes = 3,
  }) {
    return summaryFormatter.format(
      scopes: scopes,
      events: events,
      nowUtc: nowUtc,
      siteNameForScope: siteNameForScope,
      endpointLabelForScope: endpointLabelForScope,
      maxScopes: maxScopes,
    );
  }

  List<VideoFleetScopeHealthView> projectHealth({
    required List<DvrScopeConfig> scopes,
    required Iterable<IntelligenceReceived> events,
    required DateTime nowUtc,
    required Set<String> activeWatchScopeKeys,
    required MonitoringShiftSchedule Function(String clientId, String siteId)
    scheduleForScope,
    required String Function(String clientId, String siteId) siteNameForScope,
    required String Function(Uri? eventsUri) endpointLabelForScope,
    required String Function(String? cameraId) cameraLabelForId,
    required Map<String, MonitoringWatchOutcomeCueState> outcomeCueStateByScope,
    required Map<String, MonitoringWatchRecoveryState> recoveryStateByScope,
    required Map<String, MonitoringWatchRuntimeState> watchRuntimeByScope,
  }) {
    final runtimeStateByScope = runtimeStateResolver.resolve(
      scopes: scopes,
      outcomeCueStateByScope: outcomeCueStateByScope,
      recoveryStateByScope: recoveryStateByScope,
      watchRuntimeByScope: watchRuntimeByScope,
      nowUtc: nowUtc,
    );
    return healthProjector.project(
      scopes: scopes,
      events: events,
      nowUtc: nowUtc,
      activeWatchScopeKeys: activeWatchScopeKeys,
      scheduleForScope: scheduleForScope,
      siteNameForScope: siteNameForScope,
      endpointLabelForScope: endpointLabelForScope,
      cameraLabelForId: cameraLabelForId,
      runtimeStateByScope: runtimeStateByScope,
    );
  }
}
