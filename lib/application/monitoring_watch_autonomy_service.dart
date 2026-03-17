import '../domain/events/dispatch_event.dart';
import '../domain/events/intelligence_received.dart';
import 'hazard_response_directive_service.dart';
import 'monitoring_global_posture_service.dart';
import 'monitoring_orchestrator_service.dart';
import 'monitoring_scene_review_store.dart';
import 'monitoring_synthetic_war_room_service.dart';
import 'monitoring_watch_action_plan.dart';
import 'synthetic_promotion_summary_formatter.dart';

class MonitoringWatchAutonomyService {
  const MonitoringWatchAutonomyService();

  static const _globalPostureService = MonitoringGlobalPostureService();
  static const _orchestratorService = MonitoringOrchestratorService();
  static const _syntheticWarRoomService = MonitoringSyntheticWarRoomService();
  static const _hazardDirectiveService = HazardResponseDirectiveService();

  List<MonitoringWatchAutonomyActionPlan> buildPlans({
    required List<DispatchEvent> events,
    required Map<String, MonitoringSceneReviewRecord>
    sceneReviewByIntelligenceId,
    String videoOpsLabel = 'CCTV',
    List<String> historicalSyntheticLearningLabels = const <String>[],
    List<String> historicalShadowMoLabels = const <String>[],
    List<String> historicalShadowStrengthLabels = const <String>[],
  }) {
    if (events.isEmpty) {
      return const <MonitoringWatchAutonomyActionPlan>[];
    }

    final snapshot = _globalPostureService.buildSnapshot(
      events: events,
      sceneReviewByIntelligenceId: sceneReviewByIntelligenceId,
    );

    final intelligenceEvents = events.whereType<IntelligenceReceived>().toList(
      growable: false,
    );
    final ranked =
        intelligenceEvents
            .where(
              (event) =>
                  sceneReviewByIntelligenceId.containsKey(event.intelligenceId),
            )
            .map(
              (event) => _RankedAutonomyEvent(
                event: event,
                review: sceneReviewByIntelligenceId[event.intelligenceId]!,
                score: _rankScore(
                  event: event,
                  review: sceneReviewByIntelligenceId[event.intelligenceId]!,
                ),
              ),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final scoreCompare = b.score.compareTo(a.score);
            if (scoreCompare != 0) {
              return scoreCompare;
            }
            return b.event.occurredAt.compareTo(a.event.occurredAt);
          });

    final plans = ranked
        .take(4)
        .map((entry) => _buildPlan(entry, videoOpsLabel: videoOpsLabel))
        .toList(growable: false);
    final globalPlans = _buildGlobalPlans(
      snapshot,
      videoOpsLabel: videoOpsLabel,
    );
    final orchestratedPlans = _orchestratorService.buildActionIntents(
      events: events,
      sceneReviewByIntelligenceId: sceneReviewByIntelligenceId,
      videoOpsLabel: videoOpsLabel,
      historicalSyntheticLearningLabels: historicalSyntheticLearningLabels,
      historicalShadowMoLabels: historicalShadowMoLabels,
      historicalShadowStrengthLabels: historicalShadowStrengthLabels,
    );
    final syntheticPlans = _syntheticWarRoomService.buildSimulationPlans(
      events: events,
      sceneReviewByIntelligenceId: sceneReviewByIntelligenceId,
      videoOpsLabel: videoOpsLabel,
      historicalLearningLabels: historicalSyntheticLearningLabels,
      historicalShadowMoLabels: historicalShadowMoLabels,
    );
    final decoratedOrchestratedPlans = _attachSyntheticPromotionContext(
      orchestratedPlans,
      syntheticPlans,
    );
    return [
      ...decoratedOrchestratedPlans,
      ...syntheticPlans,
      ...globalPlans,
      ...plans,
    ]
      ..sort((a, b) {
        final rankCompare = _planRank(a).compareTo(_planRank(b));
        if (rankCompare != 0) {
          return rankCompare;
        }
        return a.countdownSeconds.compareTo(b.countdownSeconds);
      });
  }

  List<MonitoringWatchAutonomyActionPlan> _buildGlobalPlans(
    MonitoringGlobalPostureSnapshot snapshot, {
    required String videoOpsLabel,
  }) {
    final plans = <MonitoringWatchAutonomyActionPlan>[];
    for (final region in snapshot.regions.take(2)) {
      if (region.heatLevel == MonitoringGlobalHeatLevel.stable) {
        continue;
      }
      final leadSite = region.topSites.isEmpty ? null : region.topSites.first;
      plans.add(
        MonitoringWatchAutonomyActionPlan(
          id: 'GLOBAL-${region.regionId}',
          incidentId: leadSite?.siteId ?? region.regionId,
          siteId: leadSite?.siteId ?? region.regionId,
          priority: region.heatLevel == MonitoringGlobalHeatLevel.critical
              ? MonitoringWatchAutonomyPriority.critical
              : MonitoringWatchAutonomyPriority.high,
          actionType: 'GLOBAL POSTURE SHIFT',
          description:
              'Regional ${videoOpsLabel.toUpperCase()} posture is ${region.heatLevel.name.toUpperCase()}. ${region.summary}',
          countdownSeconds:
              region.heatLevel == MonitoringGlobalHeatLevel.critical ? 12 : 24,
          metadata: <String, String>{
            'mode': 'AUTO',
            'scope': 'GLOBAL',
            'region': region.regionId,
            'critical_sites': region.criticalSiteCount.toString(),
            'elevated_sites': region.elevatedSiteCount.toString(),
            if (leadSite != null) 'lead_site': leadSite.siteId,
          },
        ),
      );
    }
    return plans;
  }

  MonitoringWatchAutonomyActionPlan _buildPlan(
    _RankedAutonomyEvent entry, {
    required String videoOpsLabel,
  }) {
    final decisionLabel = entry.review.decisionLabel.trim().toLowerCase();
    final posture = entry.review.postureLabel.trim();
    final summary = entry.review.decisionSummary.trim().isNotEmpty
        ? entry.review.decisionSummary.trim()
        : entry.review.summary.trim();
    final camera = (entry.event.cameraId ?? '').trim();
    final metadata = <String, String>{
      'mode': 'AUTO',
      'verdict': entry.review.decisionLabel.trim().isEmpty
          ? 'Scene Review'
          : entry.review.decisionLabel.trim(),
      'posture': posture.isEmpty ? 'unlabeled posture' : posture,
      'risk': entry.event.riskScore.toString(),
      'camera': camera.isEmpty ? 'site-wide' : camera,
      'source': entry.review.sourceLabel.trim(),
    };
    final hazardDirectives = _hazardDirectiveService.build(
      postureLabel: posture,
      objectLabel: (entry.event.objectLabel ?? '').trim(),
      siteName: entry.event.siteId,
    );

    if (hazardDirectives.signal == 'fire') {
      return MonitoringWatchAutonomyActionPlan(
        id: 'AUTO-${entry.event.intelligenceId}',
        incidentId: entry.event.intelligenceId,
        siteId: entry.event.siteId,
        priority: MonitoringWatchAutonomyPriority.critical,
        actionType: hazardDirectives.localActionType,
        description:
            '${hazardDirectives.localPlanDescription.replaceAll('CCTV', videoOpsLabel.toUpperCase())} $summary',
        countdownSeconds: 8,
        metadata: metadata,
      );
    }
    if (hazardDirectives.signal == 'water_leak') {
      return MonitoringWatchAutonomyActionPlan(
        id: 'AUTO-${entry.event.intelligenceId}',
        incidentId: entry.event.intelligenceId,
        siteId: entry.event.siteId,
        priority: MonitoringWatchAutonomyPriority.critical,
        actionType: hazardDirectives.localActionType,
        description:
            '${hazardDirectives.localPlanDescription.replaceAll('CCTV', videoOpsLabel.toUpperCase())} $summary',
        countdownSeconds: 10,
        metadata: metadata,
      );
    }
    if (hazardDirectives.signal == 'environment_hazard') {
      return MonitoringWatchAutonomyActionPlan(
        id: 'AUTO-${entry.event.intelligenceId}',
        incidentId: entry.event.intelligenceId,
        siteId: entry.event.siteId,
        priority: MonitoringWatchAutonomyPriority.high,
        actionType: hazardDirectives.localActionType,
        description:
            '${hazardDirectives.localPlanDescription.replaceAll('CCTV', videoOpsLabel.toUpperCase())} $summary',
        countdownSeconds: 16,
        metadata: metadata,
      );
    }
    if (decisionLabel.contains('escalation')) {
      return MonitoringWatchAutonomyActionPlan(
        id: 'AUTO-${entry.event.intelligenceId}',
        incidentId: entry.event.intelligenceId,
        siteId: entry.event.siteId,
        priority: MonitoringWatchAutonomyPriority.critical,
        actionType: 'AUTO-DISPATCH HOLD',
        description:
            'Prepare nearest-response dispatch, partner escalation, and ${videoOpsLabel.toUpperCase()} evidence lock. $summary',
        countdownSeconds: 18,
        metadata: metadata,
      );
    }
    if (decisionLabel.contains('repeat')) {
      return MonitoringWatchAutonomyActionPlan(
        id: 'AUTO-${entry.event.intelligenceId}',
        incidentId: entry.event.intelligenceId,
        siteId: entry.event.siteId,
        priority: MonitoringWatchAutonomyPriority.high,
        actionType: 'PERSISTENCE SWEEP',
        description:
            'Run a multi-camera ${videoOpsLabel.toUpperCase()} sweep, keep the partner lane warm, and wait for corroboration. $summary',
        countdownSeconds: 32,
        metadata: metadata,
      );
    }
    if (decisionLabel.contains('suppress')) {
      return MonitoringWatchAutonomyActionPlan(
        id: 'AUTO-${entry.event.intelligenceId}',
        incidentId: entry.event.intelligenceId,
        siteId: entry.event.siteId,
        priority: MonitoringWatchAutonomyPriority.medium,
        actionType: 'AUTO-CLOSE WATCH',
        description:
            'Hold this scene as monitored movement only and archive it unless new corroborating signals arrive. $summary',
        countdownSeconds: 54,
        metadata: metadata,
      );
    }
    return MonitoringWatchAutonomyActionPlan(
      id: 'AUTO-${entry.event.intelligenceId}',
      incidentId: entry.event.intelligenceId,
      siteId: entry.event.siteId,
      priority: MonitoringWatchAutonomyPriority.high,
      actionType: 'CLIENT ALERT DRAFT',
      description:
          'Draft the client-facing monitoring alert with ${videoOpsLabel.toUpperCase()} evidence attached and keep human veto available. $summary',
      countdownSeconds: 40,
      metadata: metadata,
    );
  }

  int _rankScore({
    required IntelligenceReceived event,
    required MonitoringSceneReviewRecord review,
  }) {
    final decisionLabel = review.decisionLabel.trim().toLowerCase();
    final posture = review.postureLabel.trim().toLowerCase();
    var score = event.riskScore.clamp(0, 100);
    if (decisionLabel.contains('escalation')) {
      score += 120;
    } else if (decisionLabel.contains('repeat')) {
      score += 75;
    } else if (decisionLabel.contains('monitoring alert')) {
      score += 55;
    } else if (decisionLabel.contains('suppress')) {
      score += 10;
    }
    if (posture.contains('boundary')) {
      score += 14;
    }
    if (posture.contains('loiter')) {
      score += 18;
    }
    if (posture.contains('identity')) {
      score += 22;
    }
    if ((event.faceMatchId ?? '').trim().isNotEmpty) {
      score += 12;
    }
    if ((event.plateNumber ?? '').trim().isNotEmpty) {
      score += 8;
    }
    return score;
  }

  int _planRank(MonitoringWatchAutonomyActionPlan plan) {
    final priorityScore = switch (plan.priority) {
      MonitoringWatchAutonomyPriority.critical => 0,
      MonitoringWatchAutonomyPriority.high => 1,
      MonitoringWatchAutonomyPriority.medium => 2,
    };
    if (plan.actionType.trim().toUpperCase() == 'SHADOW READINESS BIAS') {
      return priorityScore - 3;
    }
    if (_hasPromotionExecutionBias(plan)) {
      return priorityScore - 2;
    }
    if ((plan.metadata['scope'] ?? '').trim().toUpperCase() == 'NEXT_SHIFT') {
      return priorityScore - 1;
    }
    return priorityScore + 3;
  }

  bool _hasPromotionExecutionBias(MonitoringWatchAutonomyActionPlan plan) {
    if (plan.actionType.trim().toUpperCase() != 'POLICY RECOMMENDATION') {
      return false;
    }
    if ((plan.metadata['mo_promotion_pressure_summary'] ?? '').trim().isNotEmpty) {
      return true;
    }
    return (plan.metadata['mo_promotion_priority_bias'] ?? '').trim().isNotEmpty ||
        (plan.metadata['mo_promotion_countdown_bias'] ?? '').trim().isNotEmpty;
  }

  List<MonitoringWatchAutonomyActionPlan> _attachSyntheticPromotionContext(
    List<MonitoringWatchAutonomyActionPlan> orchestratedPlans,
    List<MonitoringWatchAutonomyActionPlan> syntheticPlans,
  ) {
    if (orchestratedPlans.isEmpty || syntheticPlans.isEmpty) {
      return orchestratedPlans;
    }
    return orchestratedPlans.map((plan) {
      if ((plan.metadata['scope'] ?? '').trim().toUpperCase() != 'NEXT_SHIFT') {
        return plan;
      }
      final linkedPolicy = _linkedSyntheticPolicyForPlan(plan, syntheticPlans);
      if (linkedPolicy == null) {
        return plan;
      }
      final promotionPressureSummary =
          (linkedPolicy.metadata['mo_promotion_pressure_summary'] ?? '').trim();
      final promotionExecutionSummary =
          buildSyntheticPromotionExecutionBiasSummary(
            promotionPriorityBias:
                (linkedPolicy.metadata['mo_promotion_priority_bias'] ?? '')
                    .trim(),
            promotionCountdownBias:
                (linkedPolicy.metadata['mo_promotion_countdown_bias'] ?? '')
                    .trim(),
          );
      if (promotionPressureSummary.isEmpty && promotionExecutionSummary.isEmpty) {
        return plan;
      }
      return MonitoringWatchAutonomyActionPlan(
        id: plan.id,
        incidentId: plan.incidentId,
        siteId: plan.siteId,
        priority: plan.priority,
        actionType: plan.actionType,
        description: plan.description,
        countdownSeconds: plan.countdownSeconds,
        metadata: <String, String>{
          ...plan.metadata,
          if (promotionPressureSummary.isNotEmpty)
            'promotion_pressure_summary': promotionPressureSummary,
          if (promotionExecutionSummary.isNotEmpty)
            'promotion_execution_summary': promotionExecutionSummary,
        },
      );
    }).toList(growable: false);
  }

  MonitoringWatchAutonomyActionPlan? _linkedSyntheticPolicyForPlan(
    MonitoringWatchAutonomyActionPlan plan,
    List<MonitoringWatchAutonomyActionPlan> syntheticPlans,
  ) {
    final planLeadSite = (plan.metadata['lead_site'] ?? '').trim();
    final planRegion = (plan.metadata['region'] ?? '').trim();
    for (final syntheticPlan in syntheticPlans) {
      if (syntheticPlan.actionType.trim().toUpperCase() !=
          'POLICY RECOMMENDATION') {
        continue;
      }
      final syntheticLeadSite = (syntheticPlan.metadata['lead_site'] ?? '')
          .trim();
      final syntheticRegion = (syntheticPlan.metadata['region'] ?? '').trim();
      if (syntheticPlan.siteId.trim() == plan.siteId.trim() ||
          syntheticLeadSite == plan.siteId.trim() ||
          (planLeadSite.isNotEmpty && syntheticPlan.siteId.trim() == planLeadSite) ||
          (planLeadSite.isNotEmpty && syntheticLeadSite == planLeadSite) ||
          (planRegion.isNotEmpty && syntheticRegion == planRegion)) {
        return syntheticPlan;
      }
    }
    return null;
  }
}

class _RankedAutonomyEvent {
  final IntelligenceReceived event;
  final MonitoringSceneReviewRecord review;
  final int score;

  const _RankedAutonomyEvent({
    required this.event,
    required this.review,
    required this.score,
  });
}
