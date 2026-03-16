import '../domain/events/dispatch_event.dart';
import '../domain/events/intelligence_received.dart';
import 'monitoring_global_posture_service.dart';
import 'monitoring_scene_review_store.dart';

enum MonitoringWatchAutonomyPriority { critical, high, medium }

class MonitoringWatchAutonomyActionPlan {
  final String id;
  final String incidentId;
  final String siteId;
  final MonitoringWatchAutonomyPriority priority;
  final String actionType;
  final String description;
  final int countdownSeconds;
  final Map<String, String> metadata;

  const MonitoringWatchAutonomyActionPlan({
    required this.id,
    required this.incidentId,
    required this.siteId,
    required this.priority,
    required this.actionType,
    required this.description,
    required this.countdownSeconds,
    this.metadata = const <String, String>{},
  });
}

class MonitoringWatchAutonomyService {
  const MonitoringWatchAutonomyService();

  static const _globalPostureService = MonitoringGlobalPostureService();

  List<MonitoringWatchAutonomyActionPlan> buildPlans({
    required List<DispatchEvent> events,
    required Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId,
    String videoOpsLabel = 'CCTV',
  }) {
    if (sceneReviewByIntelligenceId.isEmpty) {
      return const <MonitoringWatchAutonomyActionPlan>[];
    }

    final snapshot = _globalPostureService.buildSnapshot(
      events: events,
      sceneReviewByIntelligenceId: sceneReviewByIntelligenceId,
    );

    final intelligenceEvents = events.whereType<IntelligenceReceived>().toList(
      growable: false,
    );
    final ranked = intelligenceEvents
        .where((event) => sceneReviewByIntelligenceId.containsKey(event.intelligenceId))
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
    final globalPlans = _buildGlobalPlans(snapshot, videoOpsLabel: videoOpsLabel);
    return [...globalPlans, ...plans]
      ..sort((a, b) {
        final priorityCompare = _priorityWeight(b.priority).compareTo(
          _priorityWeight(a.priority),
        );
        if (priorityCompare != 0) {
          return priorityCompare;
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
