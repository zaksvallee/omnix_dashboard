import '../events/decision_created.dart';
import '../events/intelligence_received.dart';
import 'intel_ingestion.dart';

enum IntelligenceRecommendation { advisory, watch, dispatchCandidate }

extension IntelligenceRecommendationLabel on IntelligenceRecommendation {
  String get label {
    switch (this) {
      case IntelligenceRecommendation.advisory:
        return 'Advisory';
      case IntelligenceRecommendation.watch:
        return 'Watch';
      case IntelligenceRecommendation.dispatchCandidate:
        return 'Dispatch Candidate';
    }
  }
}

class IntelligenceTriageAssessment {
  final int predictiveScore;
  final IntelligenceRecommendation recommendation;
  final bool corroborated;
  final bool recentDispatchNearby;
  final bool shouldEscalate;
  final List<String> matchedSignals;
  final List<String> rationale;

  const IntelligenceTriageAssessment({
    required this.predictiveScore,
    required this.recommendation,
    required this.corroborated,
    required this.recentDispatchNearby,
    required this.shouldEscalate,
    this.matchedSignals = const [],
    this.rationale = const [],
  });
}

class IntelligenceTriagePolicy {
  final int watchThreshold;
  final int dispatchCandidateThreshold;
  final int weatherWatchThreshold;
  final int communityWatchThreshold;
  final int autoEscalateThreshold;
  final int corroboratedHighRiskThreshold;
  final Duration correlationWindow;
  final Duration dispatchCorrelationWindow;

  const IntelligenceTriagePolicy({
    this.watchThreshold = 60,
    this.dispatchCandidateThreshold = 80,
    this.weatherWatchThreshold = 70,
    this.communityWatchThreshold = 65,
    this.autoEscalateThreshold = 80,
    this.corroboratedHighRiskThreshold = 70,
    this.correlationWindow = const Duration(hours: 6),
    this.dispatchCorrelationWindow = const Duration(hours: 1),
  });

  IntelligenceTriageAssessment evaluateReceived({
    required IntelligenceReceived item,
    required List<IntelligenceReceived> allIntel,
    required List<DecisionCreated> decisions,
    bool pinnedWatch = false,
    bool dismissed = false,
  }) {
    final peers = allIntel
        .where((other) => other.intelligenceId != item.intelligenceId)
        .map(_ComparableIntel.fromReceived)
        .toList(growable: false);
    return _evaluate(
      sourceType: item.sourceType,
      provider: item.provider,
      externalId: item.externalId,
      headline: item.headline,
      summary: item.summary,
      riskScore: item.riskScore,
      occurredAtUtc: item.occurredAt.toUtc(),
      peers: peers,
      decisions: decisions,
      pinnedWatch: pinnedWatch,
      dismissed: dismissed,
    );
  }

  IntelligenceTriageAssessment evaluateNormalizedRecord({
    required NormalizedIntelRecord record,
    List<IntelligenceReceived> historicalIntel = const [],
    List<NormalizedIntelRecord> batchPeers = const [],
    List<DecisionCreated> decisions = const [],
  }) {
    final peers = [
      ...historicalIntel.map(_ComparableIntel.fromReceived),
      ...batchPeers.map(_ComparableIntel.fromNormalized),
    ];
    return _evaluate(
      sourceType: record.sourceType,
      provider: record.provider,
      externalId: record.externalId,
      headline: record.headline,
      summary: record.summary,
      riskScore: record.riskScore,
      occurredAtUtc: record.occurredAtUtc.toUtc(),
      peers: peers,
      decisions: decisions,
      pinnedWatch: false,
      dismissed: false,
    );
  }

  IntelligenceTriageAssessment _evaluate({
    required String sourceType,
    required String provider,
    required String externalId,
    required String headline,
    required String summary,
    required int riskScore,
    required DateTime occurredAtUtc,
    required List<_ComparableIntel> peers,
    required List<DecisionCreated> decisions,
    required bool pinnedWatch,
    required bool dismissed,
  }) {
    if (dismissed) {
      return const IntelligenceTriageAssessment(
        predictiveScore: 0,
        recommendation: IntelligenceRecommendation.advisory,
        corroborated: false,
        recentDispatchNearby: false,
        shouldEscalate: false,
        rationale: ['Signal dismissed by operator'],
      );
    }

    final signalTokens = _signalTokens(headline, summary);
    final corroboration = _corroborationFor(
      provider: provider,
      externalId: externalId,
      sourceType: sourceType,
      riskScore: riskScore,
      occurredAtUtc: occurredAtUtc,
      signalTokens: signalTokens,
      peers: peers,
      decisions: decisions,
    );
    final predictiveScore = _predictiveScore(
      riskScore: riskScore,
      corroborated: corroboration.corroborated,
      recentDispatchNearby: corroboration.recentDispatchNearby,
      matchedSignals: corroboration.matchedSignals.length,
      sourceType: sourceType,
    );

    IntelligenceRecommendation recommendation;
    if (pinnedWatch) {
      recommendation = IntelligenceRecommendation.watch;
    } else if (sourceType == 'weather') {
      recommendation = riskScore >= weatherWatchThreshold
          ? IntelligenceRecommendation.watch
          : IntelligenceRecommendation.advisory;
    } else if (sourceType == 'community') {
      recommendation =
          (corroboration.corroborated || riskScore >= communityWatchThreshold)
          ? IntelligenceRecommendation.watch
          : IntelligenceRecommendation.advisory;
    } else if (riskScore >= dispatchCandidateThreshold &&
        corroboration.corroborated) {
      recommendation = IntelligenceRecommendation.dispatchCandidate;
    } else if (riskScore >= watchThreshold || corroboration.corroborated) {
      recommendation = IntelligenceRecommendation.watch;
    } else {
      recommendation = IntelligenceRecommendation.advisory;
    }

    final shouldEscalate =
        recommendation == IntelligenceRecommendation.dispatchCandidate &&
        predictiveScore >= autoEscalateThreshold;
    final rationale = <String>[
      'base_risk:$riskScore',
      if (corroboration.corroborated)
        'corroborated:${corroboration.matchedSignals.join(",")}',
      if (corroboration.recentDispatchNearby) 'recent_dispatch_window',
      if (pinnedWatch) 'operator_pin_watch',
      'recommendation:${recommendation.label.toLowerCase()}',
    ];

    return IntelligenceTriageAssessment(
      predictiveScore: predictiveScore,
      recommendation: recommendation,
      corroborated: corroboration.corroborated,
      recentDispatchNearby: corroboration.recentDispatchNearby,
      shouldEscalate: shouldEscalate,
      matchedSignals: corroboration.matchedSignals,
      rationale: rationale,
    );
  }

  int _predictiveScore({
    required int riskScore,
    required bool corroborated,
    required bool recentDispatchNearby,
    required int matchedSignals,
    required String sourceType,
  }) {
    var score = riskScore;
    if (corroborated) {
      score += 10;
    }
    if (recentDispatchNearby) {
      score += 6;
    }
    score += (matchedSignals * 2).clamp(0, 8);
    if (sourceType == 'community') {
      score += 2;
    }
    if (sourceType == 'weather') {
      score -= 3;
    }
    return score.clamp(0, 100);
  }

  _IntelCorroboration _corroborationFor({
    required String provider,
    required String externalId,
    required String sourceType,
    required int riskScore,
    required DateTime occurredAtUtc,
    required Set<String> signalTokens,
    required List<_ComparableIntel> peers,
    required List<DecisionCreated> decisions,
  }) {
    final nearbyDecision = decisions.any(
      (decision) =>
          decision.occurredAt
              .toUtc()
              .isAfter(occurredAtUtc.subtract(dispatchCorrelationWindow)) &&
          decision.occurredAt
              .toUtc()
              .isBefore(occurredAtUtc.add(dispatchCorrelationWindow)),
    );

    if (nearbyDecision && riskScore >= corroboratedHighRiskThreshold) {
      return const _IntelCorroboration(
        corroborated: true,
        recentDispatchNearby: true,
        matchedSignals: ['dispatch_window'],
      );
    }

    final matchedSignals = <String>{};
    for (final other in peers) {
      if (other.provider == provider &&
          other.externalId == externalId &&
          other.occurredAtUtc == occurredAtUtc) {
        continue;
      }
      final withinWindow =
          occurredAtUtc.difference(other.occurredAtUtc).abs() <=
          correlationWindow;
      if (!withinWindow) {
        continue;
      }
      final overlap = _tokenOverlap(signalTokens, other.signalTokens);
      if (overlap.isEmpty) {
        continue;
      }
      matchedSignals.addAll(overlap.take(3));
      final corroboratedBySource =
          other.sourceType != sourceType || other.provider != provider;
      if (corroboratedBySource || other.riskScore >= corroboratedHighRiskThreshold) {
        return _IntelCorroboration(
          corroborated: true,
          recentDispatchNearby: nearbyDecision,
          matchedSignals: matchedSignals.toList(growable: false),
        );
      }
    }

    return _IntelCorroboration(
      corroborated: false,
      recentDispatchNearby: nearbyDecision,
      matchedSignals: matchedSignals.toList(growable: false),
    );
  }

  Set<String> _signalTokens(String headline, String summary) {
    return '$headline $summary'
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length >= 4)
        .where((token) => !_stopwords.contains(token))
        .toSet();
  }

  List<String> _tokenOverlap(Set<String> left, Set<String> right) {
    if (left.isEmpty || right.isEmpty) {
      return const [];
    }
    final overlap = <String>[];
    for (final token in left) {
      if (right.contains(token)) {
        overlap.add(token);
      }
    }
    overlap.sort();
    return overlap;
  }
}

class _ComparableIntel {
  final String provider;
  final String externalId;
  final String sourceType;
  final int riskScore;
  final DateTime occurredAtUtc;
  final Set<String> signalTokens;

  const _ComparableIntel({
    required this.provider,
    required this.externalId,
    required this.sourceType,
    required this.riskScore,
    required this.occurredAtUtc,
    required this.signalTokens,
  });

  factory _ComparableIntel.fromReceived(IntelligenceReceived item) {
    return _ComparableIntel(
      provider: item.provider,
      externalId: item.externalId,
      sourceType: item.sourceType,
      riskScore: item.riskScore,
      occurredAtUtc: item.occurredAt.toUtc(),
      signalTokens: _tokenize(item.headline, item.summary),
    );
  }

  factory _ComparableIntel.fromNormalized(NormalizedIntelRecord record) {
    return _ComparableIntel(
      provider: record.provider,
      externalId: record.externalId,
      sourceType: record.sourceType,
      riskScore: record.riskScore,
      occurredAtUtc: record.occurredAtUtc.toUtc(),
      signalTokens: _tokenize(record.headline, record.summary),
    );
  }

  static Set<String> _tokenize(String headline, String summary) {
    return '$headline $summary'
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length >= 4)
        .where((token) => !_stopwords.contains(token))
        .toSet();
  }
}

class _IntelCorroboration {
  final bool corroborated;
  final bool recentDispatchNearby;
  final List<String> matchedSignals;

  const _IntelCorroboration({
    required this.corroborated,
    required this.recentDispatchNearby,
    required this.matchedSignals,
  });
}

const _stopwords = {
  'about',
  'after',
  'alert',
  'from',
  'near',
  'news',
  'that',
  'this',
  'warn',
  'with',
};
