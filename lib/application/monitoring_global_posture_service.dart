import '../domain/events/dispatch_event.dart';
import '../domain/events/intelligence_received.dart';
import 'hazard_response_directive_service.dart';
import 'mo_extraction_service.dart';
import 'mo_knowledge_repository.dart';
import 'mo_promotion_application_service.dart';
import 'mo_runtime_matching_service.dart';
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
  final int moShadowMatchCount;
  final String moShadowSummary;
  final List<OnyxMoShadowMatch> moShadowMatches;
  final int moShadowStrengthScore;
  final List<String> moShadowEventIds;
  final String? moShadowSelectedEventId;
  final List<String> moShadowReviewRefs;

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
    this.moShadowMatchCount = 0,
    this.moShadowSummary = '',
    this.moShadowMatches = const <OnyxMoShadowMatch>[],
    this.moShadowStrengthScore = 0,
    this.moShadowEventIds = const <String>[],
    this.moShadowSelectedEventId,
    this.moShadowReviewRefs = const <String>[],
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
  final MoRuntimeMatchingService moRuntimeMatchingService;

  const MonitoringGlobalPostureService({
    this.moRuntimeMatchingService = const MoRuntimeMatchingService(),
  });

  static const _hazardDirectiveService = HazardResponseDirectiveService();
  static const _moExtractionService = MoExtractionService();
  static const _moPromotionApplicationService = MoPromotionApplicationService();

  static const _externalSourceTypes = <String>{
    'news',
    'community',
    'weather',
  };

  MonitoringGlobalPostureSnapshot buildSnapshot({
    required List<DispatchEvent> events,
    required Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId,
    DateTime? generatedAtUtc,
  }) {
    final matchingService = _matchingServiceForEvents(events);
    final intelligenceEvents = events
        .whereType<IntelligenceReceived>()
        .where(
          (event) =>
              sceneReviewByIntelligenceId.containsKey(event.intelligenceId) ||
              _externalSourceTypes.contains(
                event.sourceType.trim().toLowerCase(),
              ),
        )
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
      final review = sceneReviewByIntelligenceId[event.intelligenceId];
      final moShadowMatches = matchingService.matchReviewedIncident(
        event: event,
        sceneReview: review,
      );
      final key = '${event.clientId}::${event.regionId}::${event.siteId}';
      siteBuckets.putIfAbsent(key, () => <_PostureItem>[]).add(
        _PostureItem(
          event: event,
          review: review,
          moShadowMatches: moShadowMatches,
          shadowStrengthScore: _shadowStrengthScore(moShadowMatches),
          score: _score(
            event,
            review,
            moShadowMatches,
          ),
        ),
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

  MoRuntimeMatchingService _matchingServiceForEvents(List<DispatchEvent> events) {
    if (moRuntimeMatchingService.repository.readAll().isNotEmpty) {
      return moRuntimeMatchingService;
    }
    final externalKnowledge = events
        .whereType<IntelligenceReceived>()
        .where(
          (event) => _externalSourceTypes.contains(
            event.sourceType.trim().toLowerCase(),
          ),
        )
        .map(
          (event) => _moExtractionService.extractExternalIncident(
            sourceId: event.intelligenceId,
            title: event.headline,
            summary: event.summary,
            sourceLabel: event.provider.trim().isEmpty
                ? event.sourceType
                : event.provider,
            environmentHint: '${event.siteId} ${event.regionId}',
            observedAtUtc: event.occurredAt,
            metadata: <String, Object?>{
              'client_id': event.clientId,
              'region_id': event.regionId,
              'site_id': event.siteId,
            },
          ),
        )
        .toList(growable: false);
    if (externalKnowledge.isEmpty) {
      return moRuntimeMatchingService;
    }
    final repository = InMemoryMoKnowledgeRepository();
    repository.upsertAll(externalKnowledge);
    _moPromotionApplicationService.applyOperatorDecisions(
      repository: repository,
    );
    return MoRuntimeMatchingService(repository: repository);
  }

  MonitoringGlobalSitePosture _buildSitePosture(List<_PostureItem> items) {
    final ordered = [...items]
      ..sort((a, b) => b.event.occurredAt.compareTo(a.event.occurredAt));
    final latest = ordered.first;
    final escalationCount = ordered
        .where((item) => _decisionLabelFor(item).contains('escalation'))
        .length;
    final repeatCount = ordered
        .where((item) => _decisionLabelFor(item).contains('repeat'))
        .length;
    final suppressedCount = ordered
        .where((item) => _decisionLabelFor(item).contains('suppress'))
        .length;
    final identitySignalCount = ordered
        .where(
          (item) =>
              (item.event.faceMatchId ?? '').trim().isNotEmpty ||
              (item.event.plateNumber ?? '').trim().isNotEmpty ||
              _postureLabelFor(item).contains('identity'),
        )
        .length;
    final activityScore = ordered.fold<int>(0, (sum, item) => sum + item.score);
    final moShadowStrengthScore = ordered.fold<int>(
      0,
      (sum, item) => sum + item.shadowStrengthScore,
    );
    final heatLevel = _heatLevelFor(
      activityScore: activityScore,
      escalationCount: escalationCount,
      repeatCount: repeatCount,
      moShadowStrengthScore: moShadowStrengthScore,
    );

    final signalCounts = <String, int>{};
    for (final item in ordered) {
      for (final signal in _signalsFor(item)) {
        signalCounts.update(signal, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final dominantSignals = signalCounts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    final moShadowMatches = ordered
        .expand((item) => item.moShadowMatches)
        .toList(growable: false);
    final moShadowEvidenceItems = ordered
        .where((item) => item.review != null && item.moShadowMatches.isNotEmpty)
        .toList(growable: false);
    final moShadowEventIds = moShadowEvidenceItems
        .map((item) => item.event.eventId.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final moShadowReviewRefs = moShadowEvidenceItems
        .map((item) => item.review!.intelligenceId.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

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
      latestSummary: _latestSummaryFor(latest),
      lastActivityAtUtc: latest.event.occurredAt.toUtc(),
      dominantSignals: dominantSignals.take(3).map((entry) => entry.key).toList(growable: false),
      moShadowMatchCount: moShadowMatches.length,
      moShadowSummary: moRuntimeMatchingService.shadowSummary(moShadowMatches),
      moShadowMatches: moShadowMatches,
      moShadowStrengthScore: moShadowStrengthScore,
      moShadowEventIds: moShadowEventIds,
      moShadowSelectedEventId: moShadowEventIds.isEmpty
          ? null
          : moShadowEventIds.first,
      moShadowReviewRefs: moShadowReviewRefs,
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
    required int moShadowStrengthScore,
  }) {
    if (escalationCount > 0 ||
        activityScore >= 180 ||
        moShadowStrengthScore >= 44) {
      return MonitoringGlobalHeatLevel.critical;
    }
    if (repeatCount > 0 ||
        activityScore >= 90 ||
        moShadowStrengthScore >= 22) {
      return MonitoringGlobalHeatLevel.elevated;
    }
    return MonitoringGlobalHeatLevel.stable;
  }

  List<String> _signalsFor(_PostureItem item) {
    final signals = <String>{};
    final posture = _postureLabelFor(item);
    final decision = _decisionLabelFor(item);
    final sourceType = item.event.sourceType.trim().toLowerCase();
    final hazardSignal = _hazardDirectiveService.hazardSignal(
      postureLabel: posture,
      objectLabel: (item.event.objectLabel ?? '').trim(),
    );
    if (posture.contains('boundary')) {
      signals.add('boundary');
    }
    if (posture.contains('loiter')) {
      signals.add('loitering');
    }
    if (posture.contains('identity')) {
      signals.add('identity');
    }
    if (hazardSignal.isNotEmpty) {
      signals.add(hazardSignal);
    }
    if ((item.event.faceMatchId ?? '').trim().isNotEmpty) {
      signals.add('face_match');
    }
    if ((item.event.plateNumber ?? '').trim().isNotEmpty) {
      signals.add('plate_match');
    }
    if (sourceType == 'news') {
      signals.add('news_pressure');
    } else if (sourceType == 'community') {
      signals.add('community_watch');
    } else if (sourceType == 'weather') {
      signals.add('weather_alert');
    }
    if (decision.contains('escalation')) {
      signals.add('escalation');
    } else if (decision.contains('repeat')) {
      signals.add('repeat');
    } else if (decision.contains('suppress')) {
      signals.add('suppressed');
    }
    if (item.moShadowMatches.isNotEmpty) {
      signals.add('mo_shadow');
    }
    return signals.toList(growable: false);
  }

  int _score(
    IntelligenceReceived event,
    MonitoringSceneReviewRecord? review,
    List<OnyxMoShadowMatch> moShadowMatches,
  ) {
    var score = event.riskScore.clamp(0, 100);
    final posture = (review?.postureLabel ?? '').toLowerCase();
    final decision = (review?.decisionLabel ?? '').toLowerCase();
    final sourceType = event.sourceType.trim().toLowerCase();
    final hazardSignal = _hazardDirectiveService.hazardSignal(
      postureLabel: review?.postureLabel ?? '',
      objectLabel: (event.objectLabel ?? '').trim(),
    );
    if (decision.contains('escalation')) {
      score += 50;
    } else if (decision.contains('repeat')) {
      score += 24;
    } else if (decision.contains('suppress')) {
      score -= 12;
    }
    if (sourceType == 'news') {
      score += 18;
    } else if (sourceType == 'community') {
      score += 14;
    } else if (sourceType == 'weather') {
      score += 10;
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
    if (hazardSignal == 'fire') {
      score += 36;
    }
    if (hazardSignal == 'water_leak') {
      score += 26;
    }
    if (hazardSignal == 'environment_hazard') {
      score += 18;
    }
    if ((event.faceMatchId ?? '').trim().isNotEmpty) {
      score += 10;
    }
    if ((event.plateNumber ?? '').trim().isNotEmpty) {
      score += 6;
    }
    score += _shadowStrengthScore(moShadowMatches);
    return score;
  }

  int _shadowStrengthScore(List<OnyxMoShadowMatch> matches) {
    if (matches.isEmpty) {
      return 0;
    }
    final lead = matches.first;
    final supportingScore = matches
        .skip(1)
        .take(2)
        .fold<double>(0, (sum, match) => sum + (match.matchScore * 0.5));
    var score = ((lead.matchScore * 28) + (supportingScore * 14)).round();
    final validationStatus = lead.validationStatus.trim();
    if (validationStatus == 'production') {
      score += 12;
    } else if (validationStatus == 'validated') {
      score += 8;
    }
    final runtimeBias = lead.runtimeMatchBias.trim();
    if (runtimeBias.startsWith('PROMOTED_')) {
      score += 6;
    }
    return score.clamp(0, 60);
  }

  String _decisionLabelFor(_PostureItem item) {
    if (item.review != null) {
      return item.review!.decisionLabel.toLowerCase();
    }
    final sourceType = item.event.sourceType.trim().toLowerCase();
    return switch (sourceType) {
      'news' || 'community' => 'external pressure',
      'weather' => 'weather pressure',
      _ => '',
    };
  }

  String _postureLabelFor(_PostureItem item) {
    if (item.review != null) {
      return item.review!.postureLabel.toLowerCase();
    }
    return switch (item.event.sourceType.trim().toLowerCase()) {
      'news' => 'regional news pressure',
      'community' => 'community watch escalation',
      'weather' => 'weather risk alert',
      _ => '',
    };
  }

  String _latestSummaryFor(_PostureItem item) {
    final review = item.review;
    if (review != null) {
      if (review.decisionSummary.trim().isNotEmpty) {
        return review.decisionSummary.trim();
      }
      if (review.summary.trim().isNotEmpty) {
        return review.summary.trim();
      }
    }
    final eventSummary = item.event.summary.trim();
    if (eventSummary.isNotEmpty) {
      return eventSummary;
    }
    return item.event.headline.trim();
  }
}

class _PostureItem {
  final IntelligenceReceived event;
  final MonitoringSceneReviewRecord? review;
  final List<OnyxMoShadowMatch> moShadowMatches;
  final int shadowStrengthScore;
  final int score;

  const _PostureItem({
    required this.event,
    required this.review,
    this.moShadowMatches = const <OnyxMoShadowMatch>[],
    this.shadowStrengthScore = 0,
    required this.score,
  });
}
