import '../domain/events/dispatch_event.dart';
import '../domain/events/intelligence_received.dart';
import 'hazard_response_directive_service.dart';
import 'monitoring_global_posture_service.dart';
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
}
