import '../domain/events/dispatch_event.dart';
import 'hazard_response_directive_service.dart';
import 'mo_feedback_learning_service.dart';
import 'mo_runtime_matching_service.dart';
import 'monitoring_global_posture_service.dart';
import 'monitoring_orchestrator_service.dart';
import 'monitoring_scene_review_store.dart';
import 'monitoring_watch_action_plan.dart';

class MonitoringSyntheticWarRoomService {
  const MonitoringSyntheticWarRoomService();

  static const _globalPostureService = MonitoringGlobalPostureService();
  static const _orchestratorService = MonitoringOrchestratorService();
  static const _hazardDirectiveService = HazardResponseDirectiveService();
  static const _moFeedbackLearningService = MoFeedbackLearningService();
  static const _externalPressureSignals = <String>{
    'news_pressure',
    'community_watch',
    'weather_shift',
  };

  List<MonitoringWatchAutonomyActionPlan> buildSimulationPlans({
    required List<DispatchEvent> events,
    required Map<String, MonitoringSceneReviewRecord>
    sceneReviewByIntelligenceId,
    String videoOpsLabel = 'CCTV',
    List<String> historicalLearningLabels = const <String>[],
    List<String> historicalShadowMoLabels = const <String>[],
    String shadowValidationDriftSummary = '',
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
      final regionalIntents =
          intents
              .where((entry) => entry.metadata['region'] == region.regionId)
              .toList(growable: false)
            ..sort(
              (a, b) => _priorityWeight(
                b.priority,
              ).compareTo(_priorityWeight(a.priority)),
            );
      final topIntent = regionalIntents.isEmpty ? null : regionalIntents.first;
      final posturalEchoCount = regionalIntents
          .where((entry) => entry.actionType == 'POSTURAL ECHO')
          .length;
      final hasExternalPressure = leadSite.dominantSignals.any(
        _externalPressureSignals.contains,
      );
      final hasFirePressure = leadSite.dominantSignals.contains('fire');
      final hasWaterLeakPressure = leadSite.dominantSignals.contains(
        'water_leak',
      );
      final hasEnvironmentalHazardPressure = leadSite.dominantSignals.contains(
        'environment_hazard',
      );
      final leadShadowMatch = leadSite.moShadowMatches.isEmpty
          ? null
          : leadSite.moShadowMatches.first;
      final shadowLabel = leadSite.moShadowMatches.isEmpty
          ? ''
          : _orchestratorService.shadowDraftLabelForSite(leadSite);

      final rehearsalFocus =
          topIntent?.actionType.toLowerCase() ??
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
        final repeatedLearningCount = learningSignal.label.trim().isEmpty
            ? 0
            : historicalLearningLabels
                  .where((label) => label.trim() == learningSignal.label)
                  .length;
        final repeatedShadowCount = shadowLabel.isEmpty
            ? 0
            : historicalShadowMoLabels
                  .where((label) => label.trim() == shadowLabel)
                  .length;
        final effectiveMemoryCount =
            repeatedLearningCount >= repeatedShadowCount
            ? repeatedLearningCount
            : repeatedShadowCount;
        final policyPriority = effectiveMemoryCount >= 2
            ? MonitoringWatchAutonomyPriority.critical
            : effectiveMemoryCount == 1
            ? MonitoringWatchAutonomyPriority.high
            : MonitoringWatchAutonomyPriority.medium;
        final countdownSeconds = effectiveMemoryCount >= 2
            ? 32
            : effectiveMemoryCount == 1
            ? 48
            : 64;
        final actionBias = effectiveMemoryCount >= 2
            ? 'Escalate rehearsal immediately for'
            : effectiveMemoryCount == 1
            ? 'Advance rehearsal earlier for'
            : 'Recommend rehearsing';
        final memorySummary = repeatedLearningCount <= 0
            ? ''
            : repeatedLearningCount == 1
            ? 'Memory bias: ${learningSignal.label} repeated in the previous shift.'
            : 'Memory bias: ${learningSignal.label} repeated in $repeatedLearningCount recent shifts.';
        final shadowMemorySummary = _shadowMemorySummary(
          shadowLabel: shadowLabel,
          repeatedShadowCount: repeatedShadowCount,
          leadShadowMatch: leadShadowMatch,
        );
        final promotionGuidance = _moFeedbackLearningService
            .buildShadowPromotionGuidance(
              matches: leadSite.moShadowMatches,
              repeatedShadowCount: repeatedShadowCount,
              shadowValidationDriftSummary: shadowValidationDriftSummary,
            );
        final shadowLearningLabel = _shadowLearningLabel(
          shadowLabel: shadowLabel,
        );
        final shadowLearningSummary = _shadowLearningSummary(
          shadowLabel: shadowLabel,
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
        final shadowRecommendation = _shadowRecommendation(
          shadowLabel: shadowLabel,
          leadShadowMatch: leadShadowMatch,
        );
        plans.add(
          MonitoringWatchAutonomyActionPlan(
            id: 'SIM-POLICY-${region.regionId}',
            incidentId: leadSite.siteId,
            siteId: leadSite.siteId,
            priority: policyPriority,
            actionType: 'POLICY RECOMMENDATION',
            description:
                '$actionBias $recommendation${shadowRecommendation.isEmpty ? '' : ' with $shadowRecommendation'} across ${region.regionId} after simulation so tomorrow’s shift starts ahead of the posture curve. ${learningSignal.summary}${memorySummary.isEmpty ? '' : ' $memorySummary'}${shadowMemorySummary.isEmpty ? '' : ' $shadowMemorySummary'}',
            countdownSeconds: countdownSeconds,
            metadata: <String, String>{
              'mode': 'SIMULATION',
              'scope': 'SIMULATION',
              'region': region.regionId,
              'lead_site': leadSite.siteId,
              'recommendation': recommendation,
              if (shadowRecommendation.isNotEmpty)
                'shadow_recommendation': shadowRecommendation,
              'action_bias': actionBias,
              'learning_label': learningSignal.label,
              'learning_summary': learningSignal.summary,
              'memory_repeat_count': repeatedLearningCount.toString(),
              'memory_priority_boost': effectiveMemoryCount <= 0
                  ? 'NONE'
                  : policyPriority.name.toUpperCase(),
              'memory_countdown_bias': countdownSeconds.toString(),
              if (memorySummary.isNotEmpty) 'memory_summary': memorySummary,
              if (shadowLabel.isNotEmpty) 'shadow_mo_label': shadowLabel,
              if (leadShadowMatch != null)
                'shadow_mo_title': leadShadowMatch.title,
              'shadow_mo_repeat_count': repeatedShadowCount.toString(),
              if (shadowLearningLabel.isNotEmpty)
                'shadow_learning_label': shadowLearningLabel,
              if (shadowLearningSummary.isNotEmpty)
                'shadow_learning_summary': shadowLearningSummary,
              if (effectiveMemoryCount > 0)
                'memory_source': repeatedShadowCount > repeatedLearningCount
                    ? 'SHADOW'
                    : 'LEARNING',
              if (shadowMemorySummary.isNotEmpty)
                'shadow_memory_summary': shadowMemorySummary,
              if (promotionGuidance != null)
                'mo_promotion_id': promotionGuidance.moId,
              if (promotionGuidance != null)
                'mo_promotion_target': promotionGuidance.targetValidationStatus,
              if (promotionGuidance != null)
                'mo_promotion_confidence_bias':
                    promotionGuidance.confidenceBias,
              if (promotionGuidance != null)
                'mo_promotion_trend_bias': promotionGuidance.trendBias,
              if (promotionGuidance != null)
                'mo_promotion_urgency_bias': promotionGuidance.urgencyBias,
              if (promotionGuidance != null &&
                  promotionGuidance.validationDriftSummary.isNotEmpty)
                'mo_promotion_validation_drift':
                    promotionGuidance.validationDriftSummary,
              if (promotionGuidance != null)
                'mo_promotion_summary': promotionGuidance.summary,
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

  String _shadowRecommendation({
    required String shadowLabel,
    required OnyxMoShadowMatch? leadShadowMatch,
  }) {
    final title = leadShadowMatch?.title.trim() ?? '';
    return switch (shadowLabel.trim()) {
      'HARDEN ACCESS' =>
        title.isEmpty
            ? 'earlier access hardening rehearsal'
            : 'earlier access hardening rehearsal around "$title"',
      'ADVANCE RECON' =>
        title.isEmpty
            ? 'earlier reconnaissance challenge rehearsal'
            : 'earlier reconnaissance challenge rehearsal around "$title"',
      'PREARM SHADOW' =>
        title.isEmpty
            ? 'earlier shadow-watch rehearsal'
            : 'earlier shadow-watch rehearsal around "$title"',
      _ => '',
    };
  }

  String _shadowLearningLabel({required String shadowLabel}) {
    return switch (shadowLabel.trim()) {
      'HARDEN ACCESS' => 'HARDEN ACCESS EARLIER',
      'ADVANCE RECON' => 'ADVANCE RECON WATCH',
      'PREARM SHADOW' => 'PREARM SHADOW WATCH',
      _ => '',
    };
  }

  String _shadowLearningSummary({required String shadowLabel}) {
    return switch (shadowLabel.trim()) {
      'HARDEN ACCESS' =>
        'Learned shadow lesson: start access hardening and service-role checks one step earlier next shift.',
      'ADVANCE RECON' =>
        'Learned shadow lesson: move reconnaissance challenge watch earlier next shift.',
      'PREARM SHADOW' =>
        'Learned shadow lesson: pre-arm shadow-watch posture earlier next shift.',
      _ => '',
    };
  }

  String _shadowMemorySummary({
    required String shadowLabel,
    required int repeatedShadowCount,
    required OnyxMoShadowMatch? leadShadowMatch,
  }) {
    if (shadowLabel.trim().isEmpty || repeatedShadowCount <= 0) {
      return '';
    }
    final title = leadShadowMatch?.title.trim() ?? '';
    final labelSummary = title.isEmpty
        ? shadowLabel
        : '$shadowLabel around "$title"';
    return repeatedShadowCount == 1
        ? 'Shadow bias: $labelSummary repeated in the previous shift.'
        : 'Shadow bias: $labelSummary repeated in $repeatedShadowCount recent shifts.';
  }
}

class _SyntheticLearningSignal {
  final String label;
  final String summary;

  const _SyntheticLearningSignal({required this.label, required this.summary});
}
