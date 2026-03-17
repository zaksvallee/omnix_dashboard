import 'mo_runtime_matching_service.dart';
import 'monitoring_global_posture_service.dart';

List<MonitoringGlobalSitePosture> sortShadowMoSites(
  Iterable<MonitoringGlobalSitePosture> sites,
) {
  final siteList = sites.toList(growable: true);
  siteList.sort((left, right) {
    final leftReviewed = left.moShadowReviewRefs.isNotEmpty ? 1 : 0;
    final rightReviewed = right.moShadowReviewRefs.isNotEmpty ? 1 : 0;
    final byReviewed = rightReviewed.compareTo(leftReviewed);
    if (byReviewed != 0) {
      return byReviewed;
    }
    final byReviewRefs = right.moShadowReviewRefs.length.compareTo(
      left.moShadowReviewRefs.length,
    );
    if (byReviewRefs != 0) {
      return byReviewRefs;
    }
    final byMatchCount = right.moShadowMatchCount.compareTo(
      left.moShadowMatchCount,
    );
    if (byMatchCount != 0) {
      return byMatchCount;
    }
    final byLeadScore = _leadMatchScore(right).compareTo(_leadMatchScore(left));
    if (byLeadScore != 0) {
      return byLeadScore;
    }
    final byActivity = right.activityScore.compareTo(left.activityScore);
    if (byActivity != 0) {
      return byActivity;
    }
    final byActivityTime = right.lastActivityAtUtc.compareTo(left.lastActivityAtUtc);
    if (byActivityTime != 0) {
      return byActivityTime;
    }
    return left.siteId.compareTo(right.siteId);
  });
  return siteList;
}

List<OnyxMoShadowMatch> sortShadowMoMatches(Iterable<OnyxMoShadowMatch> matches) {
  final matchList = matches.toList(growable: true);
  matchList.sort((left, right) {
    final byScore = right.matchScore.compareTo(left.matchScore);
    if (byScore != 0) {
      return byScore;
    }
    final byIndicators = right.matchedIndicators.length.compareTo(
      left.matchedIndicators.length,
    );
    if (byIndicators != 0) {
      return byIndicators;
    }
    final byActions = right.recommendedActionPlans.length.compareTo(
      left.recommendedActionPlans.length,
    );
    if (byActions != 0) {
      return byActions;
    }
    return left.title.compareTo(right.title);
  });
  return matchList;
}

Map<String, Object?> buildShadowMoSitePayload(
  MonitoringGlobalSitePosture site, {
  Map<String, Object?> metadata = const <String, Object?>{},
}) {
  final orderedMatches = sortShadowMoMatches(site.moShadowMatches);
  final orderedEventIds = _orderedEventIds(
    eventIds: site.moShadowEventIds,
    selectedEventId: site.moShadowSelectedEventId,
  );
  return <String, Object?>{
    ...metadata,
    'siteId': site.siteId,
    'regionId': site.regionId,
    'heatLevel': site.heatLevel.name,
    'matchCount': site.moShadowMatchCount,
    'summary': site.moShadowSummary,
    'eventIds': orderedEventIds,
    'selectedEventId': site.moShadowSelectedEventId,
    'reviewRefs': site.moShadowReviewRefs,
    'matches': orderedMatches
        .map(
          (match) => <String, Object?>{
            'moId': match.moId,
            'title': match.title,
            'incidentType': match.incidentType,
            'behaviorStage': match.behaviorStage,
            'validationStatus': match.validationStatus,
            'matchScore': match.matchScore,
            'matchedIndicators': match.matchedIndicators,
            'recommendedActionPlans': match.recommendedActionPlans,
          },
        )
        .toList(growable: false),
  };
}

Map<String, Object?> buildShadowMoDossierPayload({
  required Iterable<MonitoringGlobalSitePosture> sites,
  DateTime? generatedAtUtc,
  String countKey = 'siteCount',
  Map<String, Object?> metadata = const <String, Object?>{},
}) {
  final siteList = sortShadowMoSites(sites);
  return <String, Object?>{
    'generatedAtUtc': (generatedAtUtc ?? DateTime.now().toUtc()).toIso8601String(),
    countKey: siteList.length,
    ...metadata,
    'sites': siteList
        .map((site) => buildShadowMoSitePayload(site))
        .toList(growable: false),
  };
}

double _leadMatchScore(MonitoringGlobalSitePosture site) {
  if (site.moShadowMatches.isEmpty) {
    return 0;
  }
  return sortShadowMoMatches(site.moShadowMatches).first.matchScore;
}

List<String> _orderedEventIds({
  required Iterable<String> eventIds,
  required String? selectedEventId,
}) {
  final normalizedSelected = (selectedEventId ?? '').trim();
  final remaining = <String>[];
  for (final eventId in eventIds) {
    final normalized = eventId.trim();
    if (normalized.isEmpty || normalized == normalizedSelected) {
      continue;
    }
    remaining.add(normalized);
  }
  return [
    if (normalizedSelected.isNotEmpty) normalizedSelected,
    ...remaining,
  ];
}
