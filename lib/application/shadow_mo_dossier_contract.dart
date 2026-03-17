import 'monitoring_global_posture_service.dart';

Map<String, Object?> buildShadowMoSitePayload(
  MonitoringGlobalSitePosture site, {
  Map<String, Object?> metadata = const <String, Object?>{},
}) {
  return <String, Object?>{
    ...metadata,
    'siteId': site.siteId,
    'regionId': site.regionId,
    'heatLevel': site.heatLevel.name,
    'matchCount': site.moShadowMatchCount,
    'summary': site.moShadowSummary,
    'matches': site.moShadowMatches
        .map(
          (match) => <String, Object?>{
            'moId': match.moId,
            'title': match.title,
            'incidentType': match.incidentType,
            'behaviorStage': match.behaviorStage,
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
  final siteList = sites.toList(growable: false);
  return <String, Object?>{
    'generatedAtUtc': (generatedAtUtc ?? DateTime.now().toUtc()).toIso8601String(),
    countKey: siteList.length,
    ...metadata,
    'sites': siteList
        .map((site) => buildShadowMoSitePayload(site))
        .toList(growable: false),
  };
}
