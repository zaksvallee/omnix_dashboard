import '../domain/events/intelligence_received.dart';
import '../domain/intelligence/onyx_mo_record.dart';
import 'mo_extraction_service.dart';
import 'mo_knowledge_repository.dart';
import 'mo_promotion_application_service.dart';
import 'monitoring_scene_review_store.dart';
import 'monitoring_watch_vision_review_service.dart';

class OnyxMoShadowMatch {
  final String moId;
  final String title;
  final String incidentType;
  final String behaviorStage;
  final String validationStatus;
  final double matchScore;
  final List<String> matchedIndicators;
  final List<String> recommendedActionPlans;

  const OnyxMoShadowMatch({
    required this.moId,
    required this.title,
    required this.incidentType,
    required this.behaviorStage,
    this.validationStatus = '',
    required this.matchScore,
    this.matchedIndicators = const <String>[],
    this.recommendedActionPlans = const <String>[],
  });
}

class EmptyMoKnowledgeRepository implements MoKnowledgeRepository {
  const EmptyMoKnowledgeRepository();

  @override
  List<OnyxMoRecord> readAll() => const <OnyxMoRecord>[];

  @override
  List<OnyxMoRecord> readByEnvironmentType(String environmentType) =>
      const <OnyxMoRecord>[];

  @override
  List<OnyxMoRecord> readByValidationStatus(
    OnyxMoValidationStatus validationStatus,
  ) => const <OnyxMoRecord>[];

  @override
  void upsert(OnyxMoRecord record) {}

  @override
  void upsertAll(Iterable<OnyxMoRecord> records) {}
}

class MoRuntimeMatchingService {
  final MoKnowledgeRepository repository;
  final MoExtractionService extractionService;
  final MoPromotionApplicationService promotionApplicationService;

  const MoRuntimeMatchingService({
    this.repository = const EmptyMoKnowledgeRepository(),
    this.extractionService = const MoExtractionService(),
    this.promotionApplicationService = const MoPromotionApplicationService(),
  });

  List<OnyxMoShadowMatch> matchObservedScene({
    required IntelligenceReceived event,
    required MonitoringWatchVisionReviewResult review,
  }) {
    final observedRecord = extractionService.extractObservedScene(
      event: event,
      review: review,
    );
    return _matchRecord(observedRecord);
  }

  List<OnyxMoShadowMatch> matchReviewedIncident({
    required IntelligenceReceived event,
    required MonitoringSceneReviewRecord? sceneReview,
  }) {
    final internalRecord = extractionService.extractInternalIncident(
      event: event,
      sceneReview: sceneReview,
    );
    return _matchRecord(internalRecord);
  }

  String shadowSummary(List<OnyxMoShadowMatch> matches) {
    if (matches.isEmpty) {
      return '';
    }
    final lead = matches.first;
    final indicators = lead.matchedIndicators.take(2).join(', ');
    return indicators.isEmpty
        ? '${lead.title} (${lead.matchScore.toStringAsFixed(2)})'
        : '${lead.title} (${lead.matchScore.toStringAsFixed(2)}) • $indicators';
  }

  List<OnyxMoShadowMatch> _matchRecord(OnyxMoRecord record) {
    promotionApplicationService.applyOperatorDecisions(repository: repository);
    final knowledge = repository.readAll().where((candidate) {
      return candidate.validationStatus == OnyxMoValidationStatus.shadowMode ||
          candidate.validationStatus == OnyxMoValidationStatus.validated ||
          candidate.validationStatus == OnyxMoValidationStatus.production;
    });
    final matches = <OnyxMoShadowMatch>[];
    for (final candidate in knowledge) {
      final indicators = <String>{
        ..._overlap(
          record.preIncidentIndicators,
          candidate.preIncidentIndicators,
        ),
        ..._overlap(record.entryIndicators, candidate.entryIndicators),
        ..._overlap(
          record.insideBehaviorIndicators,
          candidate.insideBehaviorIndicators,
        ),
        ..._overlap(
          record.coordinationIndicators,
          candidate.coordinationIndicators,
        ),
        ..._overlap(
          record.extractionIndicators,
          candidate.extractionIndicators,
        ),
        ..._overlap(record.deceptionIndicators, candidate.deceptionIndicators),
        ..._overlap(
          record.systemPressureIndicators,
          candidate.systemPressureIndicators,
        ),
        ..._overlap(record.observableCues, candidate.observableCues),
        ..._overlap(record.environmentTypes, candidate.environmentTypes),
      };
      var score = indicators.length * 0.12;
      if (record.incidentType.isNotEmpty &&
          record.incidentType == candidate.incidentType) {
        score += 0.14;
      }
      if (record.behaviorStage.isNotEmpty &&
          record.behaviorStage == candidate.behaviorStage) {
        score += 0.12;
      }
      if (record.attackGoal.isNotEmpty &&
          record.attackGoal == candidate.attackGoal) {
        score += 0.12;
      }
      score += candidate.observabilityScore * 0.15;
      score += candidate.localRelevanceScore * 0.1;
      score += _validationStatusScoreBonus(candidate.validationStatus);
      score += _runtimeMatchWeight(candidate);
      score += _trendScoreWeight(candidate.trendScore);
      score += _riskWeightScore(candidate.riskWeight);
      if (score < 0.45) {
        continue;
      }
      matches.add(
        OnyxMoShadowMatch(
          moId: candidate.moId,
          title: candidate.title,
          incidentType: candidate.incidentType,
          behaviorStage: candidate.behaviorStage,
          validationStatus: candidate.validationStatus.name,
          matchScore: score > 1 ? 1 : score,
          matchedIndicators: indicators.toList(growable: false)..sort(),
          recommendedActionPlans: candidate.recommendedActionPlans,
        ),
      );
    }
    matches.sort((left, right) => right.matchScore.compareTo(left.matchScore));
    return matches.take(3).toList(growable: false);
  }

  Iterable<String> _overlap(List<String> left, List<String> right) {
    final rightSet = right.map((value) => value.trim().toLowerCase()).toSet();
    return left
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty && rightSet.contains(value));
  }

  double _validationStatusScoreBonus(OnyxMoValidationStatus status) {
    switch (status) {
      case OnyxMoValidationStatus.production:
        return 0.08;
      case OnyxMoValidationStatus.validated:
        return 0.04;
      case OnyxMoValidationStatus.shadowMode:
      case OnyxMoValidationStatus.candidate:
      case OnyxMoValidationStatus.canonicalized:
        return 0;
    }
  }

  double _runtimeMatchWeight(OnyxMoRecord record) {
    final raw = record.metadata['runtime_match_weight'];
    final parsed = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
    final decisionStatus = (record.metadata['promotion_decision_status'] ?? '')
        .toString()
        .trim();
    if (decisionStatus == 'rejected') {
      return 0;
    }
    return parsed.clamp(0, 0.15);
  }

  double _trendScoreWeight(double trendScore) {
    if (trendScore <= 0) {
      return 0;
    }
    return (trendScore * 0.05).clamp(0, 0.06);
  }

  double _riskWeightScore(int riskWeight) {
    if (riskWeight <= 0) {
      return 0;
    }
    return (riskWeight / 1000).clamp(0, 0.08);
  }
}
