import 'mo_runtime_matching_service.dart';
import 'monitoring_global_posture_service.dart';

class ShadowMoStrengthDriftSummary {
  final String summary;
  final String handoffSummary;

  const ShadowMoStrengthDriftSummary({
    required this.summary,
    this.handoffSummary = '',
  });
}

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
    final byActivityTime = right.lastActivityAtUtc.compareTo(
      left.lastActivityAtUtc,
    );
    if (byActivityTime != 0) {
      return byActivityTime;
    }
    return left.siteId.compareTo(right.siteId);
  });
  return siteList;
}

List<OnyxMoShadowMatch> sortShadowMoMatches(
  Iterable<OnyxMoShadowMatch> matches,
) {
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
            'runtimeMatchBias': match.runtimeMatchBias,
            'matchScore': match.matchScore,
            'strengthSummary': shadowMoStrengthSummary(match),
            'matchedIndicators': match.matchedIndicators,
            'recommendedActionPlans': match.recommendedActionPlans,
          },
        )
        .toList(growable: false),
  };
}

String shadowMoStrengthSummaryForSites(
  List<MonitoringGlobalSitePosture> sites,
) {
  if (sites.isEmpty) {
    return '';
  }
  final orderedSites = sortShadowMoSites(sites);
  if (orderedSites.isEmpty || orderedSites.first.moShadowMatches.isEmpty) {
    return '';
  }
  return shadowMoStrengthSummary(
    sortShadowMoMatches(orderedSites.first.moShadowMatches).first,
  );
}

ShadowMoStrengthDriftSummary buildShadowMoStrengthDriftSummary({
  required List<MonitoringGlobalSitePosture> currentSites,
  List<List<MonitoringGlobalSitePosture>> historySiteSets = const [],
}) {
  final currentStrength = _leadStrengthScore(currentSites);
  if (currentStrength <= 0) {
    return const ShadowMoStrengthDriftSummary(summary: '', handoffSummary: '');
  }
  final baselines = historySiteSets
      .map(_leadStrengthScore)
      .where((score) => score > 0)
      .take(3)
      .toList(growable: false);
  if (baselines.isEmpty) {
    return ShadowMoStrengthDriftSummary(
      summary:
          'Current strength ${currentStrength.toStringAsFixed(2)} • Baseline n/a • No prior shadow-MO strength history is available yet.',
      handoffSummary: 'strength new',
    );
  }
  final baselineAverage =
      baselines.reduce((left, right) => left + right) / baselines.length;
  final isRising = currentStrength > baselineAverage + 0.04;
  final isEasing = currentStrength < baselineAverage - 0.04;
  final reason = isRising
      ? 'Shadow-MO runtime strength is increasing against recent shifts.'
      : isEasing
      ? 'Shadow-MO runtime strength eased against recent shifts.'
      : 'Shadow-MO runtime strength is holding close to the recent baseline.';
  return ShadowMoStrengthDriftSummary(
    summary:
        'Current strength ${currentStrength.toStringAsFixed(2)} • Baseline ${baselineAverage.toStringAsFixed(2)} • $reason',
    handoffSummary: isRising
        ? 'strength rising'
        : isEasing
        ? 'strength easing'
        : 'strength stable',
  );
}

Map<String, Object?> buildShadowMoDossierPayload({
  required Iterable<MonitoringGlobalSitePosture> sites,
  DateTime? generatedAtUtc,
  String countKey = 'siteCount',
  Map<String, Object?> metadata = const <String, Object?>{},
}) {
  final siteList = sortShadowMoSites(sites);
  return <String, Object?>{
    'generatedAtUtc': (generatedAtUtc ?? DateTime.now().toUtc())
        .toIso8601String(),
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
  return [if (normalizedSelected.isNotEmpty) normalizedSelected, ...remaining];
}

String shadowMoStrengthSummary(OnyxMoShadowMatch match) {
  final bias = match.runtimeMatchBias.trim();
  final status = match.validationStatus.trim();
  final score = match.matchScore.toStringAsFixed(2);
  if (bias.isNotEmpty) {
    return '${_humanizeRuntimeMatchBias(bias)} • $score';
  }
  if (status.isNotEmpty) {
    return '${_humanizeValidationStatus(status)} • $score';
  }
  return 'MATCHED • $score';
}

double _leadStrengthScore(List<MonitoringGlobalSitePosture> sites) {
  if (sites.isEmpty) {
    return 0;
  }
  final orderedSites = sortShadowMoSites(sites);
  if (orderedSites.isEmpty || orderedSites.first.moShadowMatches.isEmpty) {
    return 0;
  }
  return sortShadowMoMatches(
    orderedSites.first.moShadowMatches,
  ).first.matchScore;
}

String _humanizeRuntimeMatchBias(String bias) {
  switch (bias) {
    case 'PROMOTED_PRODUCTION':
      return 'PROMOTED PRODUCTION';
    case 'PROMOTED_VALIDATED':
      return 'PROMOTED VALIDATED';
    case 'PROMOTED_SHADOW':
      return 'PROMOTED SHADOW';
    case 'PROMOTED_CANDIDATE':
      return 'PROMOTED CANDIDATE';
    case 'REVIEW_HOLD':
      return 'REVIEW HOLD';
    default:
      final normalized = bias.trim().replaceAll('_', ' ');
      return normalized.toUpperCase();
  }
}

String _humanizeValidationStatus(String status) {
  switch (status) {
    case 'shadowMode':
      return 'SHADOW MODE';
    case 'validated':
      return 'VALIDATED';
    case 'production':
      return 'PRODUCTION';
    case 'candidate':
      return 'CANDIDATE';
    default:
      return status.trim().toUpperCase();
  }
}
