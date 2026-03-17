import '../domain/events/dispatch_event.dart';
import '../domain/events/intelligence_received.dart';
import 'hazard_response_directive_service.dart';
import 'monitoring_global_posture_service.dart';
import 'mo_runtime_matching_service.dart';
import 'monitoring_scene_review_store.dart';
import 'monitoring_watch_action_plan.dart';

class MonitoringOrchestratorService {
  const MonitoringOrchestratorService();

  static const _globalPostureService = MonitoringGlobalPostureService();
  static const _hazardDirectiveService = HazardResponseDirectiveService();

  List<MonitoringWatchAutonomyActionPlan> buildActionIntents({
    required List<DispatchEvent> events,
    required Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId,
    String videoOpsLabel = 'CCTV',
    List<String> historicalSyntheticLearningLabels = const <String>[],
    List<String> historicalShadowMoLabels = const <String>[],
  }) {
    final snapshot = _globalPostureService.buildSnapshot(
      events: events,
      sceneReviewByIntelligenceId: sceneReviewByIntelligenceId,
    );
    if (snapshot.totalSites == 0) {
      return const <MonitoringWatchAutonomyActionPlan>[];
    }

    final actionIntents = <MonitoringWatchAutonomyActionPlan>[];
    final intelligenceBySite = <String, List<IntelligenceReceived>>{};
    for (final event in events.whereType<IntelligenceReceived>()) {
      intelligenceBySite.putIfAbsent(event.siteId, () => <IntelligenceReceived>[]).add(event);
    }

    for (final region in snapshot.regions.take(2)) {
      if (region.heatLevel == MonitoringGlobalHeatLevel.stable ||
          region.topSites.isEmpty) {
        continue;
      }
      final leadSite = region.topSites.first;
      final latestSiteEvent = (intelligenceBySite[leadSite.siteId] ?? const <IntelligenceReceived>[])
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      final latest = latestSiteEvent.isEmpty ? null : latestSiteEvent.first;
      final hasIdentityPressure = leadSite.identitySignalCount > 0;
      final hasFirePressure = leadSite.dominantSignals.contains('fire');
      final hasWaterLeakPressure =
          leadSite.dominantSignals.contains('water_leak');
      final hasEnvironmentalHazardPressure =
          leadSite.dominantSignals.contains('environment_hazard');
      final hazardSignal = hasFirePressure
          ? 'fire'
          : hasWaterLeakPressure
          ? 'water_leak'
          : hasEnvironmentalHazardPressure
          ? 'environment_hazard'
          : '';
      final hazardDirectives = _hazardDirectiveService.buildForSignal(
        signal: hazardSignal,
        siteName: leadSite.siteId,
      );
      final nextShiftLearningLabel = _nextShiftLearningLabelForRegion(
        heatLevel: region.heatLevel,
        posturalEchoTargets: region.topSites.length - 1,
        hasExternalPressure: leadSite.dominantSignals.any(
          (signal) => const <String>{
            'news_pressure',
            'community_watch',
            'weather_shift',
          }.contains(signal),
        ),
        hazardSignal: hazardSignal,
      );
      final repeatedLearningCount = nextShiftLearningLabel.isEmpty
          ? 0
          : historicalSyntheticLearningLabels
              .where((label) => label.trim() == nextShiftLearningLabel)
              .length;
      final nextShiftShadowLabel = shadowDraftLabelForSite(leadSite);
      final repeatedShadowCount = nextShiftShadowLabel.isEmpty
          ? 0
          : historicalShadowMoLabels
              .where((label) => label.trim() == nextShiftShadowLabel)
              .length;

      if (hasFirePressure || hasWaterLeakPressure || hasEnvironmentalHazardPressure) {
        actionIntents.add(
          MonitoringWatchAutonomyActionPlan(
            id: 'ORCH-HAZARD-${region.regionId}',
            incidentId: latest?.intelligenceId ?? leadSite.siteId,
            siteId: leadSite.siteId,
            priority: MonitoringWatchAutonomyPriority.critical,
            actionType: hazardDirectives.playbookActionType,
            description: hazardDirectives.playbookDescription.replaceAll(
              'CCTV',
              videoOpsLabel.toUpperCase(),
            ),
            countdownSeconds: hasFirePressure
                ? 6
                : hasWaterLeakPressure
                ? 8
                : 12,
            metadata: <String, String>{
              'mode': 'AUTO',
              'scope': 'ORCHESTRATOR',
              'region': region.regionId,
              'lead_site': leadSite.siteId,
              'heat': region.heatLevel.name.toUpperCase(),
              'hazard_signal': hazardSignal,
              'signals': leadSite.dominantSignals.join(', '),
            },
          ),
        );

        actionIntents.add(
          MonitoringWatchAutonomyActionPlan(
            id: 'ORCH-HAZARD-DISPATCH-${region.regionId}',
            incidentId: latest?.intelligenceId ?? leadSite.siteId,
            siteId: leadSite.siteId,
            priority: MonitoringWatchAutonomyPriority.critical,
            actionType: hazardDirectives.dispatchActionType,
            description: hazardDirectives.dispatchPlanDescription.replaceAll(
              'CCTV',
              videoOpsLabel.toUpperCase(),
            ),
            countdownSeconds: hasFirePressure
                ? 4
                : hasWaterLeakPressure
                ? 6
                : 9,
            metadata: <String, String>{
              'mode': 'AUTO',
              'scope': 'ORCHESTRATOR',
              'region': region.regionId,
              'lead_site': leadSite.siteId,
              'hazard_signal': hazardSignal,
              'response_policy': hazardDirectives.responsePolicy,
            },
          ),
        );

        actionIntents.add(
          MonitoringWatchAutonomyActionPlan(
            id: 'ORCH-HAZARD-WELFARE-${region.regionId}',
            incidentId: latest?.intelligenceId ?? leadSite.siteId,
            siteId: leadSite.siteId,
            priority: MonitoringWatchAutonomyPriority.high,
            actionType: 'TRIGGER OCCUPANT WELFARE CHECK',
            description: hazardDirectives.welfarePlanDescription,
            countdownSeconds: hasFirePressure
                ? 7
                : hasWaterLeakPressure
                ? 9
                : 12,
            metadata: <String, String>{
              'mode': 'AUTO',
              'scope': 'ORCHESTRATOR',
              'region': region.regionId,
              'lead_site': leadSite.siteId,
              'hazard_signal': hazardSignal,
              'response_policy': 'occupant_welfare_check',
            },
          ),
        );
      }

      if (repeatedLearningCount > 0) {
        final draftPriority = repeatedLearningCount >= 2
            ? MonitoringWatchAutonomyPriority.critical
            : MonitoringWatchAutonomyPriority.high;
        final draftCountdown = repeatedLearningCount >= 2 ? 18 : 30;
        final draftActionType = _nextShiftDraftActionType(
          learningLabel: nextShiftLearningLabel,
        );
        final draftDescription = _nextShiftDraftDescription(
          learningLabel: nextShiftLearningLabel,
          siteId: leadSite.siteId,
          regionId: region.regionId,
          videoOpsLabel: videoOpsLabel,
          hazardDirectives: hazardDirectives,
          repeatedLearningCount: repeatedLearningCount,
        );
        if (draftActionType.isNotEmpty && draftDescription.isNotEmpty) {
          actionIntents.add(
            MonitoringWatchAutonomyActionPlan(
              id: 'ORCH-NEXT-SHIFT-${region.regionId}-$nextShiftLearningLabel',
              incidentId: latest?.intelligenceId ?? leadSite.siteId,
              siteId: leadSite.siteId,
              priority: draftPriority,
              actionType: draftActionType,
              description: draftDescription,
              countdownSeconds: draftCountdown,
              metadata: <String, String>{
                'mode': 'DRAFT',
                'scope': 'NEXT_SHIFT',
                'region': region.regionId,
                'lead_site': leadSite.siteId,
                'learning_label': nextShiftLearningLabel,
                'learning_repeat_count': repeatedLearningCount.toString(),
                'draft_bias': 'REPEATED_SYNTHETIC_LEARNING',
                'draft_countdown': draftCountdown.toString(),
                if (hazardSignal.isNotEmpty) 'hazard_signal': hazardSignal,
              },
            ),
          );
        }
      }

      if (repeatedShadowCount > 0) {
        final leadShadowMatch = leadSite.moShadowMatches.isEmpty
            ? null
            : leadSite.moShadowMatches.first;
        final biasPriority = repeatedShadowCount >= 2
            ? MonitoringWatchAutonomyPriority.critical
            : MonitoringWatchAutonomyPriority.high;
        final biasCountdown = repeatedShadowCount >= 2 ? 12 : 20;
        final biasDescription = _shadowReadinessBiasDescription(
          shadowLabel: nextShiftShadowLabel,
          siteId: leadSite.siteId,
          regionId: region.regionId,
          repeatedShadowCount: repeatedShadowCount,
          leadShadowMatch: leadShadowMatch,
        );
        if (biasDescription.isNotEmpty) {
          actionIntents.add(
            MonitoringWatchAutonomyActionPlan(
              id: 'ORCH-SHADOW-BIAS-${region.regionId}-$nextShiftShadowLabel',
              incidentId: latest?.intelligenceId ?? leadSite.siteId,
              siteId: leadSite.siteId,
              priority: biasPriority,
              actionType: 'SHADOW READINESS BIAS',
              description: biasDescription,
              countdownSeconds: biasCountdown,
              metadata: <String, String>{
                'mode': 'AUTO',
                'scope': 'READINESS',
                'region': region.regionId,
                'lead_site': leadSite.siteId,
                'shadow_mo_label': nextShiftShadowLabel,
                'shadow_mo_repeat_count': repeatedShadowCount.toString(),
                'readiness_bias': 'ACTIVE',
                if (leadShadowMatch != null) 'shadow_mo_title': leadShadowMatch.title,
                if (leadShadowMatch != null)
                  'shadow_mo_indicators': leadShadowMatch.matchedIndicators.join(', '),
              },
            ),
          );
        }
        final draftPriority = repeatedShadowCount >= 2
            ? MonitoringWatchAutonomyPriority.critical
            : MonitoringWatchAutonomyPriority.high;
        final draftCountdown = repeatedShadowCount >= 2 ? 16 : 28;
        final draftActionType = _nextShiftShadowDraftActionType(
          shadowLabel: nextShiftShadowLabel,
        );
        final draftDescription = _nextShiftShadowDraftDescription(
          shadowLabel: nextShiftShadowLabel,
          siteId: leadSite.siteId,
          regionId: region.regionId,
          videoOpsLabel: videoOpsLabel,
          repeatedShadowCount: repeatedShadowCount,
          leadShadowMatch: leadShadowMatch,
        );
        if (draftActionType.isNotEmpty && draftDescription.isNotEmpty) {
          actionIntents.add(
            MonitoringWatchAutonomyActionPlan(
              id: 'ORCH-NEXT-SHIFT-SHADOW-${region.regionId}-$nextShiftShadowLabel',
              incidentId: latest?.intelligenceId ?? leadSite.siteId,
              siteId: leadSite.siteId,
              priority: draftPriority,
              actionType: draftActionType,
              description: draftDescription,
              countdownSeconds: draftCountdown,
              metadata: <String, String>{
                'mode': 'DRAFT',
                'scope': 'NEXT_SHIFT',
                'region': region.regionId,
                'lead_site': leadSite.siteId,
                'shadow_mo_label': nextShiftShadowLabel,
                'shadow_mo_repeat_count': repeatedShadowCount.toString(),
                'draft_bias': 'REPEATED_SHADOW_MO',
                'draft_countdown': draftCountdown.toString(),
                if (leadShadowMatch != null) 'shadow_mo_title': leadShadowMatch.title,
                if (leadShadowMatch != null)
                  'shadow_mo_indicators': leadShadowMatch.matchedIndicators.join(', '),
              },
            ),
          );
        }
      }

      actionIntents.add(
        MonitoringWatchAutonomyActionPlan(
          id: 'ORCH-PREPOSITION-${region.regionId}',
          incidentId: latest?.intelligenceId ?? leadSite.siteId,
          siteId: leadSite.siteId,
          priority: region.heatLevel == MonitoringGlobalHeatLevel.critical
              ? MonitoringWatchAutonomyPriority.critical
              : MonitoringWatchAutonomyPriority.high,
          actionType: 'PREPOSITION RESPONSE',
          description:
              'Shift response posture toward ${leadSite.siteId} while ${videoOpsLabel.toUpperCase()} pressure builds across ${region.regionId}.',
          countdownSeconds:
              region.heatLevel == MonitoringGlobalHeatLevel.critical ? 10 : 20,
          metadata: <String, String>{
            'mode': 'AUTO',
            'scope': 'ORCHESTRATOR',
            'region': region.regionId,
            'lead_site': leadSite.siteId,
            'heat': region.heatLevel.name.toUpperCase(),
            'signals': leadSite.dominantSignals.join(', '),
          },
        ),
      );

      actionIntents.add(
        MonitoringWatchAutonomyActionPlan(
          id: 'ORCH-PARTNER-${region.regionId}',
          incidentId: latest?.intelligenceId ?? leadSite.siteId,
          siteId: leadSite.siteId,
          priority: MonitoringWatchAutonomyPriority.high,
          actionType: 'RAISE PARTNER READINESS',
          description:
              'Warm the partner lane for ${leadSite.siteId} with a regional readiness brief before human escalation is needed.',
          countdownSeconds: 28,
          metadata: <String, String>{
            'mode': 'AUTO',
            'scope': 'ORCHESTRATOR',
            'region': region.regionId,
            'lead_site': leadSite.siteId,
            'critical_sites': region.criticalSiteCount.toString(),
            'elevated_sites': region.elevatedSiteCount.toString(),
          },
        ),
      );

      final echoTargets = region.topSites
          .where((site) => site.siteId != leadSite.siteId)
          .take(region.heatLevel == MonitoringGlobalHeatLevel.critical ? 2 : 1)
          .toList(growable: false);
      for (final target in echoTargets) {
        final targetPriority =
            target.heatLevel == MonitoringGlobalHeatLevel.elevated
            ? MonitoringWatchAutonomyPriority.critical
            : MonitoringWatchAutonomyPriority.high;
        actionIntents.add(
          MonitoringWatchAutonomyActionPlan(
            id: 'ORCH-ECHO-${region.regionId}-${target.siteId}',
            incidentId: latest?.intelligenceId ?? leadSite.siteId,
            siteId: target.siteId,
            priority: targetPriority,
            actionType: 'POSTURAL ECHO',
            description:
                'Raise ${videoOpsLabel.toUpperCase()} perimeter attention at ${target.siteId} because ${leadSite.siteId} is driving ${region.regionId} into ${region.heatLevel.name.toUpperCase()} posture.',
            countdownSeconds: region.heatLevel == MonitoringGlobalHeatLevel.critical
                ? 14
                : 22,
            metadata: <String, String>{
              'mode': 'AUTO',
              'scope': 'ORCHESTRATOR',
              'region': region.regionId,
              'lead_site': leadSite.siteId,
              'echo_target': target.siteId,
              'echo_heat': target.heatLevel.name.toUpperCase(),
              'echo_signals': target.dominantSignals.join(', '),
            },
          ),
        );
      }

      if (hasIdentityPressure || leadSite.escalationCount > 0) {
        actionIntents.add(
          MonitoringWatchAutonomyActionPlan(
            id: 'ORCH-CLIENT-${region.regionId}',
            incidentId: latest?.intelligenceId ?? leadSite.siteId,
            siteId: leadSite.siteId,
            priority: MonitoringWatchAutonomyPriority.high,
            actionType: 'DRAFT CLIENT WARNING',
            description:
                'Prepare a client-facing caution for ${leadSite.siteId} with identity and boundary evidence held for human veto.',
            countdownSeconds: 34,
            metadata: <String, String>{
              'mode': 'AUTO',
              'scope': 'ORCHESTRATOR',
              'region': region.regionId,
              'lead_site': leadSite.siteId,
              'identity_pressure': hasIdentityPressure ? 'YES' : 'NO',
            },
          ),
        );
      }

      if (hasFirePressure || hasWaterLeakPressure || hasEnvironmentalHazardPressure) {
        actionIntents.add(
          MonitoringWatchAutonomyActionPlan(
            id: 'ORCH-SAFETY-${region.regionId}',
            incidentId: latest?.intelligenceId ?? leadSite.siteId,
            siteId: leadSite.siteId,
            priority: MonitoringWatchAutonomyPriority.high,
            actionType: 'DRAFT SAFETY WARNING',
            description: hazardDirectives.safetyWarningDescription,
            countdownSeconds: hasFirePressure
                ? 10
                : hasWaterLeakPressure
                ? 12
                : 16,
            metadata: <String, String>{
              'mode': 'AUTO',
              'scope': 'ORCHESTRATOR',
              'region': region.regionId,
              'lead_site': leadSite.siteId,
              'hazard_signal': hazardSignal,
            },
          ),
        );
      }
    }

    for (final site in snapshot.sites.take(3)) {
      if (site.repeatCount <= 0 || site.heatLevel == MonitoringGlobalHeatLevel.stable) {
        continue;
      }
      actionIntents.add(
        MonitoringWatchAutonomyActionPlan(
          id: 'ORCH-REVIEW-${site.siteId}',
          incidentId: site.siteId,
          siteId: site.siteId,
          priority: MonitoringWatchAutonomyPriority.high,
          actionType: 'PROMOTE SCENE REVIEW',
          description:
              'Promote ${site.siteId} to a faster review cadence because repeated activity is compounding into posture drift.',
          countdownSeconds: 26,
          metadata: <String, String>{
            'mode': 'AUTO',
            'scope': 'ORCHESTRATOR',
            'region': site.regionId,
            'repeat_count': site.repeatCount.toString(),
            'activity_score': site.activityScore.toString(),
          },
        ),
      );
    }

    final deduped = <String, MonitoringWatchAutonomyActionPlan>{};
    for (final plan in actionIntents) {
      deduped.putIfAbsent(plan.id, () => plan);
    }
    return deduped.values.toList(growable: false);
  }

  String shadowDraftLabelForSite(MonitoringGlobalSitePosture site) {
    if (site.moShadowMatches.isEmpty) {
      return '';
    }
    final leadMatch = site.moShadowMatches.first;
    final incidentType = leadMatch.incidentType.trim().toLowerCase();
    final indicators = leadMatch.matchedIndicators
        .map((value) => value.trim().toLowerCase())
        .toSet();
    if (incidentType.contains('maintenance_impersonation') ||
        incidentType.contains('service_impersonation') ||
        indicators.contains('spoofed_service_access')) {
      return 'HARDEN ACCESS';
    }
    if (indicators.contains('perimeter_scan') ||
        indicators.contains('repeat_visitation') ||
        indicators.contains('route_anomalies')) {
      return 'ADVANCE RECON';
    }
    return 'PREARM SHADOW';
  }

  String _nextShiftLearningLabelForRegion({
    required MonitoringGlobalHeatLevel heatLevel,
    required int posturalEchoTargets,
    required bool hasExternalPressure,
    required String hazardSignal,
  }) {
    if (hazardSignal == 'fire') {
      return 'ADVANCE FIRE';
    }
    if (hazardSignal == 'water_leak') {
      return 'ADVANCE LEAK';
    }
    if (hazardSignal == 'environment_hazard') {
      return 'ADVANCE SAFETY';
    }
    if (hasExternalPressure) {
      return 'PRE-ARM REGION';
    }
    if (posturalEchoTargets > 0) {
      return 'ECHO EARLIER';
    }
    if (heatLevel == MonitoringGlobalHeatLevel.critical) {
      return 'SHORTEN REVIEW';
    }
    return '';
  }

  String _nextShiftDraftActionType({required String learningLabel}) {
    return switch (learningLabel.trim()) {
      'ADVANCE FIRE' => 'DRAFT NEXT-SHIFT FIRE READINESS',
      'ADVANCE LEAK' => 'DRAFT NEXT-SHIFT LEAK READINESS',
      'ADVANCE SAFETY' => 'DRAFT NEXT-SHIFT SAFETY READINESS',
      'PRE-ARM REGION' => 'DRAFT NEXT-SHIFT REGIONAL READINESS',
      'ECHO EARLIER' => 'DRAFT NEXT-SHIFT ECHO READINESS',
      'SHORTEN REVIEW' => 'DRAFT NEXT-SHIFT REVIEW ACCELERATION',
      _ => '',
    };
  }

  String _nextShiftDraftDescription({
    required String learningLabel,
    required String siteId,
    required String regionId,
    required String videoOpsLabel,
    required HazardResponseDirectives hazardDirectives,
    required int repeatedLearningCount,
  }) {
    final repeatSummary = repeatedLearningCount >= 2
        ? 'because the same synthetic lesson repeated across $repeatedLearningCount recent shifts'
        : 'because the same synthetic lesson repeated in the previous shift';
    return switch (learningLabel.trim()) {
      'ADVANCE FIRE' =>
        'Prebuild next-shift fire readiness for $siteId with ${hazardDirectives.syntheticRecommendation} and hold ${videoOpsLabel.toUpperCase()} verification tighter $repeatSummary.',
      'ADVANCE LEAK' =>
        'Prebuild next-shift leak readiness for $siteId with ${hazardDirectives.syntheticRecommendation} and hold ${videoOpsLabel.toUpperCase()} verification tighter $repeatSummary.',
      'ADVANCE SAFETY' =>
        'Prebuild next-shift safety readiness for $siteId with ${hazardDirectives.syntheticRecommendation} and hold ${videoOpsLabel.toUpperCase()} verification tighter $repeatSummary.',
      'PRE-ARM REGION' =>
        'Pre-arm regional readiness across $regionId for the next shift so $siteId starts ahead of incoming external pressure $repeatSummary.',
      'ECHO EARLIER' =>
        'Draft next-shift echo readiness from $siteId into sibling sites across $regionId so ${videoOpsLabel.toUpperCase()} attention rises earlier $repeatSummary.',
      'SHORTEN REVIEW' =>
        'Draft a faster next-shift review cadence for $siteId across $regionId so posture pressure is met earlier $repeatSummary.',
      _ => '',
    };
  }

  String _nextShiftShadowDraftActionType({required String shadowLabel}) {
    return switch (shadowLabel.trim()) {
      'HARDEN ACCESS' => 'DRAFT NEXT-SHIFT ACCESS HARDENING',
      'ADVANCE RECON' => 'DRAFT NEXT-SHIFT RECON WATCH',
      'PREARM SHADOW' => 'DRAFT NEXT-SHIFT SHADOW WATCH',
      _ => '',
    };
  }

  String _nextShiftShadowDraftDescription({
    required String shadowLabel,
    required String siteId,
    required String regionId,
    required String videoOpsLabel,
    required int repeatedShadowCount,
    required OnyxMoShadowMatch? leadShadowMatch,
  }) {
    final repeatSummary = repeatedShadowCount >= 2
        ? 'because the same shadow MO repeated across $repeatedShadowCount recent shifts'
        : 'because the same shadow MO repeated in the previous shift';
    final title = leadShadowMatch?.title.trim() ?? '';
    final indicatorSummary = leadShadowMatch == null
        ? ''
        : leadShadowMatch.matchedIndicators.take(3).join(', ');
    return switch (shadowLabel.trim()) {
      'HARDEN ACCESS' =>
        'Prebuild next-shift access hardening for $siteId across $regionId so ${videoOpsLabel.toUpperCase()} verification, service-role checks, and restricted-zone review tighten earlier ${title.isEmpty ? repeatSummary : 'around "$title" $repeatSummary'}.',
      'ADVANCE RECON' =>
        'Prebuild next-shift reconnaissance watch for $siteId across $regionId so ${videoOpsLabel.toUpperCase()} can challenge early probing${indicatorSummary.isEmpty ? '' : ' on $indicatorSummary'} $repeatSummary.',
      'PREARM SHADOW' =>
        'Pre-arm next-shift shadow watch for $siteId across $regionId so repeated MO pressure is challenged earlier${title.isEmpty ? '' : ' around "$title"'} $repeatSummary.',
      _ => '',
    };
  }

  String _shadowReadinessBiasDescription({
    required String shadowLabel,
    required String siteId,
    required String regionId,
    required int repeatedShadowCount,
    required OnyxMoShadowMatch? leadShadowMatch,
  }) {
    final repeatSummary = repeatedShadowCount >= 2
        ? 'because the same shadow MO repeated across $repeatedShadowCount recent shifts'
        : 'because the same shadow MO repeated in the previous shift';
    final title = leadShadowMatch?.title.trim() ?? '';
    return switch (shadowLabel.trim()) {
      'HARDEN ACCESS' =>
        'Bias readiness toward earlier access hardening at $siteId across $regionId ${title.isEmpty ? repeatSummary : 'around "$title" $repeatSummary'}.',
      'ADVANCE RECON' =>
        'Bias readiness toward earlier reconnaissance watch at $siteId across $regionId ${title.isEmpty ? repeatSummary : 'around "$title" $repeatSummary'}.',
      'PREARM SHADOW' =>
        'Bias readiness toward pre-armed shadow watch at $siteId across $regionId ${title.isEmpty ? repeatSummary : 'around "$title" $repeatSummary'}.',
      _ => '',
    };
  }
}
