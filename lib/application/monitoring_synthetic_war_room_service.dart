import '../domain/events/dispatch_event.dart';
import 'hazard_response_directive_service.dart';
import 'monitoring_global_posture_service.dart';
import 'monitoring_orchestrator_service.dart';
import 'monitoring_scene_review_store.dart';
import 'monitoring_watch_action_plan.dart';

class MonitoringSyntheticWarRoomService {
  const MonitoringSyntheticWarRoomService();

  static const _globalPostureService = MonitoringGlobalPostureService();
  static const _orchestratorService = MonitoringOrchestratorService();
  static const _hazardDirectiveService = HazardResponseDirectiveService();
  static const _externalPressureSignals = <String>{
    'news_pressure',
    'community_watch',
    'weather_shift',
  };

  List<MonitoringWatchAutonomyActionPlan> buildSimulationPlans({
    required List<DispatchEvent> events,
    required Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId,
    String videoOpsLabel = 'CCTV',
  }) {
    final snapshot = _globalPostureService.buildSnapshot(
      events: events,
      sceneReviewByIntelligenceId: sceneReviewByIntelligenceId,
    );
    if (snapshot.totalSites == 0) {
      return const <MonitoringWatchAutonomyActionPlan>[];
    }

    final intents = _orchestratorService.buildActionIntents(
      events: events,
      sceneReviewByIntelligenceId: sceneReviewByIntelligenceId,
      videoOpsLabel: videoOpsLabel,
    );

    final plans = <MonitoringWatchAutonomyActionPlan>[];
    for (final region in snapshot.regions.take(2)) {
      if (region.heatLevel == MonitoringGlobalHeatLevel.stable ||
          region.topSites.isEmpty) {
        continue;
      }

      final leadSite = region.topSites.first;
      final regionalIntents = intents
          .where((entry) => entry.metadata['region'] == region.regionId)
          .toList(growable: false)
        ..sort(
          (a, b) => _priorityWeight(b.priority).compareTo(
            _priorityWeight(a.priority),
          ),
        );
      final topIntent = regionalIntents.isEmpty ? null : regionalIntents.first;
      final posturalEchoCount = regionalIntents
          .where((entry) => entry.actionType == 'POSTURAL ECHO')
          .length;
      final hasExternalPressure = leadSite.dominantSignals.any(
        _externalPressureSignals.contains,
      );
      final hasFirePressure = leadSite.dominantSignals.contains('fire');
      final hasWaterLeakPressure =
          leadSite.dominantSignals.contains('water_leak');
      final hasEnvironmentalHazardPressure =
          leadSite.dominantSignals.contains('environment_hazard');

      final rehearsalFocus = topIntent?.actionType.toLowerCase() ??
          '${videoOpsLabel.toLowerCase()} spillover containment';
      plans.add(
        MonitoringWatchAutonomyActionPlan(
          id: 'SIM-WAR-${region.regionId}',
          incidentId: leadSite.siteId,
          siteId: leadSite.siteId,
          priority: region.heatLevel == MonitoringGlobalHeatLevel.critical
              ? MonitoringWatchAutonomyPriority.high
              : MonitoringWatchAutonomyPriority.medium,
          actionType: 'SYNTHETIC WAR-ROOM',
          description:
              'Replay the next-shift posture around ${region.regionId} with ${leadSite.siteId} as the lead site and test whether $rehearsalFocus contains ${videoOpsLabel.toUpperCase()} pressure before operators are forced reactive.',
          countdownSeconds:
              region.heatLevel == MonitoringGlobalHeatLevel.critical ? 42 : 58,
          metadata: <String, String>{
            'mode': 'SIMULATION',
            'scope': 'SIMULATION',
            'region': region.regionId,
            'lead_site': leadSite.siteId,
            'heat': region.heatLevel.name.toUpperCase(),
            'simulated_sites': region.activeSiteCount.toString(),
            'postural_echo_count': posturalEchoCount.toString(),
            'top_intent': topIntent?.actionType ?? 'NONE',
            'external_pressure': hasExternalPressure ? 'YES' : 'NO',
            'dominant_signals': leadSite.dominantSignals.join(', '),
          },
        ),
      );

      if (region.heatLevel == MonitoringGlobalHeatLevel.critical ||
          hasExternalPressure ||
          posturalEchoCount > 0 ||
          hasFirePressure ||
          hasWaterLeakPressure ||
          hasEnvironmentalHazardPressure) {
        final hazardSignal = hasFirePressure
            ? 'fire'
            : hasWaterLeakPressure
            ? 'water_leak'
            : hasEnvironmentalHazardPressure
            ? 'environment_hazard'
            : '';
        final learningSignal = _learningSignalForRegion(
          region: region,
          posturalEchoCount: posturalEchoCount,
          hasExternalPressure: hasExternalPressure,
          hazardSignal: hazardSignal,
        );
        final recommendation = hazardSignal.isNotEmpty
            ? _hazardDirectiveService
                .buildForSignal(
                  signal: hazardSignal,
                  siteName: leadSite.siteId,
                )
                .syntheticRecommendation
            : hasExternalPressure
            ? 'earlier regional readiness before external pressure lands on-site'
            : posturalEchoCount > 0
                ? 'earlier postural echo propagation into sibling sites'
                : 'shorter review latency before critical posture compounds';
        plans.add(
          MonitoringWatchAutonomyActionPlan(
            id: 'SIM-POLICY-${region.regionId}',
            incidentId: leadSite.siteId,
            siteId: leadSite.siteId,
            priority: MonitoringWatchAutonomyPriority.medium,
            actionType: 'POLICY RECOMMENDATION',
            description:
                'Recommend rehearsing $recommendation across ${region.regionId} after simulation so tomorrow’s shift starts ahead of the posture curve. ${learningSignal.summary}',
            countdownSeconds: 64,
            metadata: <String, String>{
              'mode': 'SIMULATION',
              'scope': 'SIMULATION',
              'region': region.regionId,
              'lead_site': leadSite.siteId,
              'recommendation': recommendation,
              'learning_label': learningSignal.label,
              'learning_summary': learningSignal.summary,
              'top_intent': topIntent?.actionType ?? 'NONE',
              if (hazardSignal.isNotEmpty) 'hazard_signal': hazardSignal,
            },
          ),
        );
      }
    }

    final deduped = <String, MonitoringWatchAutonomyActionPlan>{};
    for (final plan in plans) {
      deduped.putIfAbsent(plan.id, () => plan);
    }
    return deduped.values.toList(growable: false);
  }

  int _priorityWeight(MonitoringWatchAutonomyPriority priority) {
    switch (priority) {
      case MonitoringWatchAutonomyPriority.critical:
        return 3;
      case MonitoringWatchAutonomyPriority.high:
        return 2;
      case MonitoringWatchAutonomyPriority.medium:
        return 1;
    }
  }

  _SyntheticLearningSignal _learningSignalForRegion({
    required MonitoringGlobalRegionPosture region,
    required int posturalEchoCount,
    required bool hasExternalPressure,
    required String hazardSignal,
  }) {
    if (hazardSignal == 'fire') {
      return const _SyntheticLearningSignal(
        label: 'ADVANCE FIRE',
        summary:
            'Learned bias: stage fire response one step earlier next shift.',
      );
    }
    if (hazardSignal == 'water_leak') {
      return const _SyntheticLearningSignal(
        label: 'ADVANCE LEAK',
        summary:
            'Learned bias: start leak containment checks before the first patrol gap next shift.',
      );
    }
    if (hazardSignal == 'environment_hazard') {
      return const _SyntheticLearningSignal(
        label: 'ADVANCE SAFETY',
        summary:
            'Learned bias: move site safety isolation checks earlier next shift.',
      );
    }
    if (hasExternalPressure) {
      return const _SyntheticLearningSignal(
        label: 'PRE-ARM REGION',
        summary:
            'Learned bias: raise regional readiness before external pressure lands on-site.',
      );
    }
    if (posturalEchoCount > 0) {
      return const _SyntheticLearningSignal(
        label: 'ECHO EARLIER',
        summary:
            'Learned bias: propagate postural echo into sibling sites earlier next shift.',
      );
    }
    if (region.heatLevel == MonitoringGlobalHeatLevel.critical) {
      return const _SyntheticLearningSignal(
        label: 'SHORTEN REVIEW',
        summary:
            'Learned bias: shorten review latency before posture compounds next shift.',
      );
    }
    return const _SyntheticLearningSignal(label: '', summary: '');
  }
}

class _SyntheticLearningSignal {
  final String label;
  final String summary;

  const _SyntheticLearningSignal({
    required this.label,
    required this.summary,
  });
}
