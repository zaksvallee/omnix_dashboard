import '../domain/events/dispatch_event.dart';
import '../domain/events/intelligence_received.dart';
import 'monitoring_global_posture_service.dart';
import 'monitoring_scene_review_store.dart';
import 'monitoring_watch_action_plan.dart';

class MonitoringOrchestratorService {
  const MonitoringOrchestratorService();

  static const _globalPostureService = MonitoringGlobalPostureService();

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
