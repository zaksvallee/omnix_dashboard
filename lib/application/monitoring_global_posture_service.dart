import '../domain/events/dispatch_event.dart';
import '../domain/events/intelligence_received.dart';
import 'monitoring_scene_review_store.dart';

enum MonitoringGlobalHeatLevel { stable, elevated, critical }

class MonitoringGlobalSitePosture {
  final String clientId;
  final String regionId;
  final String siteId;
  final MonitoringGlobalHeatLevel heatLevel;
  final int activityScore;
  final int intelligenceCount;
  final int escalationCount;
  final int repeatCount;
  final int suppressedCount;
  final int identitySignalCount;
  final String latestSummary;
  final DateTime lastActivityAtUtc;
  final List<String> dominantSignals;

  const MonitoringGlobalSitePosture({
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.heatLevel,
    required this.activityScore,
    required this.intelligenceCount,
    required this.escalationCount,
    required this.repeatCount,
    required this.suppressedCount,
    required this.identitySignalCount,
    required this.latestSummary,
    required this.lastActivityAtUtc,
    this.dominantSignals = const <String>[],
  });
}

class MonitoringGlobalRegionPosture {
  final String regionId;
  final MonitoringGlobalHeatLevel heatLevel;
  final int totalActivityScore;
  final int activeSiteCount;
  final int criticalSiteCount;
  final int elevatedSiteCount;
  final String summary;
  final List<MonitoringGlobalSitePosture> topSites;

  const MonitoringGlobalRegionPosture({
    required this.regionId,
    required this.heatLevel,
    required this.totalActivityScore,
    required this.activeSiteCount,
    required this.criticalSiteCount,
    required this.elevatedSiteCount,
    required this.summary,
    this.topSites = const <MonitoringGlobalSitePosture>[],
  });
}

class MonitoringGlobalPostureSnapshot {
  final DateTime generatedAtUtc;
  final int totalSites;
  final int criticalSiteCount;
  final int elevatedSiteCount;
  final List<MonitoringGlobalSitePosture> sites;
  final List<MonitoringGlobalRegionPosture> regions;

  const MonitoringGlobalPostureSnapshot({
    required this.generatedAtUtc,
    required this.totalSites,
    required this.criticalSiteCount,
    required this.elevatedSiteCount,
    this.sites = const <MonitoringGlobalSitePosture>[],
    this.regions = const <MonitoringGlobalRegionPosture>[],
  });
}

class MonitoringGlobalPostureService {
  const MonitoringGlobalPostureService();

  MonitoringGlobalPostureSnapshot buildSnapshot({
    required List<DispatchEvent> events,
    required Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId,
    DateTime? generatedAtUtc,
  }) {
    final intelligenceEvents = events
        .whereType<IntelligenceReceived>()
        .where((event) => sceneReviewByIntelligenceId.containsKey(event.intelligenceId))
        .toList(growable: false);

    if (intelligenceEvents.isEmpty) {
      return MonitoringGlobalPostureSnapshot(
        generatedAtUtc: (generatedAtUtc ?? DateTime.now()).toUtc(),
        totalSites: 0,
        criticalSiteCount: 0,
        elevatedSiteCount: 0,
      );
    }

    final siteBuckets = <String, List<_PostureItem>>{};
    for (final event in intelligenceEvents) {
      final review = sceneReviewByIntelligenceId[event.intelligenceId]!;
      final key = '${event.clientId}::${event.regionId}::${event.siteId}';
      siteBuckets.putIfAbsent(key, () => <_PostureItem>[]).add(
        _PostureItem(event: event, review: review, score: _score(event, review)),
      );
    }

    final sites = siteBuckets.entries
        .map((entry) => _buildSitePosture(entry.value))
        .toList(growable: false)
      ..sort((a, b) {
        final scoreCompare = b.activityScore.compareTo(a.activityScore);
        if (scoreCompare != 0) {
          return scoreCompare;
        }
        return b.lastActivityAtUtc.compareTo(a.lastActivityAtUtc);
      });

    final regionBuckets = <String, List<MonitoringGlobalSitePosture>>{};
    for (final site in sites) {
      regionBuckets.putIfAbsent(site.regionId, () => <MonitoringGlobalSitePosture>[]).add(site);
    }

    final regions = regionBuckets.entries
        .map((entry) => _buildRegionPosture(entry.key, entry.value))
        .toList(growable: false)
      ..sort((a, b) => b.totalActivityScore.compareTo(a.totalActivityScore));

    return MonitoringGlobalPostureSnapshot(
      generatedAtUtc: (generatedAtUtc ?? DateTime.now()).toUtc(),
      totalSites: sites.length,
      criticalSiteCount: sites.where((entry) => entry.heatLevel == MonitoringGlobalHeatLevel.critical).length,
      elevatedSiteCount: sites.where((entry) => entry.heatLevel == MonitoringGlobalHeatLevel.elevated).length,
      sites: sites,
      regions: regions,
    );
  }

  MonitoringGlobalSitePosture _buildSitePosture(List<_PostureItem> items) {
    final ordered = [...items]
      ..sort((a, b) => b.event.occurredAt.compareTo(a.event.occurredAt));
    final latest = ordered.first;
    final escalationCount = ordered
        .where((item) => item.review.decisionLabel.toLowerCase().contains('escalation'))
        .length;
    final repeatCount = ordered
        .where((item) => item.review.decisionLabel.toLowerCase().contains('repeat'))
        .length;
    final suppressedCount = ordered
        .where((item) => item.review.decisionLabel.toLowerCase().contains('suppress'))
        .length;
    final identitySignalCount = ordered
        .where(
          (item) =>
              (item.event.faceMatchId ?? '').trim().isNotEmpty ||
              (item.event.plateNumber ?? '').trim().isNotEmpty ||
              item.review.postureLabel.toLowerCase().contains('identity'),
        )
        .length;
    final activityScore = ordered.fold<int>(0, (sum, item) => sum + item.score);
    final heatLevel = _heatLevelFor(
      activityScore: activityScore,
      escalationCount: escalationCount,
      repeatCount: repeatCount,
    );

    final signalCounts = <String, int>{};
    for (final item in ordered) {
      for (final signal in _signalsFor(item)) {
        signalCounts.update(signal, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final dominantSignals = signalCounts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));

    return MonitoringGlobalSitePosture(
      clientId: latest.event.clientId,
      regionId: latest.event.regionId,
      siteId: latest.event.siteId,
      heatLevel: heatLevel,
      activityScore: activityScore,
      intelligenceCount: ordered.length,
      escalationCount: escalationCount,
      repeatCount: repeatCount,
      suppressedCount: suppressedCount,
      identitySignalCount: identitySignalCount,
      latestSummary: latest.review.decisionSummary.trim().isNotEmpty
          ? latest.review.decisionSummary.trim()
          : latest.review.summary.trim(),
      lastActivityAtUtc: latest.event.occurredAt.toUtc(),
      dominantSignals: dominantSignals.take(3).map((entry) => entry.key).toList(growable: false),
    );
  }

  MonitoringGlobalRegionPosture _buildRegionPosture(
    String regionId,
    List<MonitoringGlobalSitePosture> sites,
  ) {
    final totalActivityScore = sites.fold<int>(0, (sum, site) => sum + site.activityScore);
    final criticalSiteCount = sites.where((site) => site.heatLevel == MonitoringGlobalHeatLevel.critical).length;
    final elevatedSiteCount = sites.where((site) => site.heatLevel == MonitoringGlobalHeatLevel.elevated).length;
    final heatLevel = criticalSiteCount > 0
        ? MonitoringGlobalHeatLevel.critical
        : elevatedSiteCount > 1
            ? MonitoringGlobalHeatLevel.elevated
            : MonitoringGlobalHeatLevel.stable;
    final topSites = [...sites]
      ..sort((a, b) => b.activityScore.compareTo(a.activityScore));
    final summary = criticalSiteCount > 0
        ? '$criticalSiteCount critical site${criticalSiteCount == 1 ? '' : 's'} driving regional posture'
        : elevatedSiteCount > 0
            ? '$elevatedSiteCount elevated site${elevatedSiteCount == 1 ? '' : 's'} require active watch'
            : 'Regional posture stable across monitored sites';

    return MonitoringGlobalRegionPosture(
      regionId: regionId,
      heatLevel: heatLevel,
      totalActivityScore: totalActivityScore,
      activeSiteCount: sites.length,
      criticalSiteCount: criticalSiteCount,
      elevatedSiteCount: elevatedSiteCount,
      summary: summary,
      topSites: topSites.take(3).toList(growable: false),
    );
  }

  MonitoringGlobalHeatLevel _heatLevelFor({
    required int activityScore,
    required int escalationCount,
    required int repeatCount,
  }) {
    if (escalationCount > 0 || activityScore >= 180) {
      return MonitoringGlobalHeatLevel.critical;
    }
    if (repeatCount > 0 || activityScore >= 90) {
      return MonitoringGlobalHeatLevel.elevated;
    }
    return MonitoringGlobalHeatLevel.stable;
  }

  List<String> _signalsFor(_PostureItem item) {
    final signals = <String>{};
    final posture = item.review.postureLabel.toLowerCase();
    final decision = item.review.decisionLabel.toLowerCase();
    if (posture.contains('boundary')) {
      signals.add('boundary');
    }
    if (posture.contains('loiter')) {
      signals.add('loitering');
    }
    if (posture.contains('identity')) {
      signals.add('identity');
    }
    if ((item.event.faceMatchId ?? '').trim().isNotEmpty) {
      signals.add('face_match');
    }
    if ((item.event.plateNumber ?? '').trim().isNotEmpty) {
      signals.add('plate_match');
    }
    if (decision.contains('escalation')) {
      signals.add('escalation');
    } else if (decision.contains('repeat')) {
      signals.add('repeat');
    } else if (decision.contains('suppress')) {
      signals.add('suppressed');
    }
    return signals.toList(growable: false);
  }

  int _score(IntelligenceReceived event, MonitoringSceneReviewRecord review) {
    var score = event.riskScore.clamp(0, 100);
    final posture = review.postureLabel.toLowerCase();
    final decision = review.decisionLabel.toLowerCase();
    if (decision.contains('escalation')) {
      score += 50;
    } else if (decision.contains('repeat')) {
      score += 24;
    } else if (decision.contains('suppress')) {
      score -= 12;
    }
    if (posture.contains('boundary')) {
      score += 12;
    }
    if (posture.contains('loiter')) {
      score += 14;
    }
    if (posture.contains('identity')) {
      score += 10;
    }
    if ((event.faceMatchId ?? '').trim().isNotEmpty) {
      score += 10;
    }
    if ((event.plateNumber ?? '').trim().isNotEmpty) {
      score += 6;
    }
    return score;
  }
}

class _PostureItem {
  final IntelligenceReceived event;
  final MonitoringSceneReviewRecord review;
  final int score;

  const _PostureItem({
    required this.event,
    required this.review,
    required this.score,
  });
}
