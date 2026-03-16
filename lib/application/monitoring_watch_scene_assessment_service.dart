import '../domain/events/intelligence_received.dart';
import 'monitoring_identity_policy_service.dart';
import 'monitoring_temporary_identity_approval_service.dart';
import 'monitoring_watch_vision_review_service.dart';

enum MonitoringWatchSceneConfidence { low, medium, high }

class MonitoringWatchSceneAssessment {
  final String objectLabel;
  final int effectiveRiskScore;
  final MonitoringWatchSceneConfidence confidence;
  final String postureLabel;
  final bool shouldNotifyClient;
  final bool shouldEscalate;
  final bool repeatActivity;
  final bool boundaryConcern;
  final bool loiteringConcern;
  final bool fireSignal;
  final bool waterLeakSignal;
  final bool environmentHazardSignal;
  final String? faceMatchId;
  final double? faceConfidence;
  final String? plateNumber;
  final double? plateConfidence;
  final bool identityRiskSignal;
  final bool identityAllowedSignal;
  final bool temporaryIdentityAllowedSignal;
  final DateTime? temporaryIdentityValidUntilUtc;
  final int groupedEventCount;
  final List<String> rationale;

  const MonitoringWatchSceneAssessment({
    required this.objectLabel,
    required this.effectiveRiskScore,
    required this.confidence,
    required this.postureLabel,
    required this.shouldNotifyClient,
    required this.shouldEscalate,
    required this.repeatActivity,
    this.boundaryConcern = false,
    this.loiteringConcern = false,
    this.fireSignal = false,
    this.waterLeakSignal = false,
    this.environmentHazardSignal = false,
    this.faceMatchId,
    this.faceConfidence,
    this.plateNumber,
    this.plateConfidence,
    this.identityRiskSignal = false,
    this.identityAllowedSignal = false,
    this.temporaryIdentityAllowedSignal = false,
    this.temporaryIdentityValidUntilUtc,
    this.groupedEventCount = 1,
    this.rationale = const [],
  });
}

class MonitoringWatchSceneAssessmentService {
  final MonitoringIdentityPolicyService identityPolicyService;
  final MonitoringTemporaryIdentityApprovalService
  temporaryIdentityApprovalService;

  const MonitoringWatchSceneAssessmentService({
    this.identityPolicyService = const MonitoringIdentityPolicyService(),
    this.temporaryIdentityApprovalService =
        const MonitoringTemporaryIdentityApprovalService(),
  });

  MonitoringWatchSceneAssessment assess({
    required IntelligenceReceived event,
    required MonitoringWatchVisionReviewResult review,
    required int priorReviewedEvents,
    int groupedEventCount = 1,
  }) {
    final objectLabel = _resolvedObjectLabel(event, review);
    final repeatActivity = priorReviewedEvents > 0;
    var score = event.riskScore.clamp(1, 99);
    final rationale = <String>[
      'base:${event.riskScore.clamp(1, 99)}',
      'review:${review.sourceLabel}',
    ];

    if ((event.snapshotUrl ?? '').trim().isNotEmpty) {
      score += 2;
      rationale.add('snapshot');
    }

    if (review.riskDelta != 0) {
      score += review.riskDelta;
      rationale.add('review_delta:${review.riskDelta}');
    }

    final confidence = _confidenceBand(
      event.objectConfidence,
      score,
      review.confidence,
    );
    if (confidence == MonitoringWatchSceneConfidence.high) {
      score += 4;
      rationale.add('confidence:high');
    } else if (confidence == MonitoringWatchSceneConfidence.medium) {
      score += 2;
      rationale.add('confidence:medium');
    } else {
      score -= 4;
      rationale.add('confidence:low');
    }

    if (objectLabel == 'person' ||
        objectLabel == 'human' ||
        objectLabel == 'intruder') {
      score += 10;
      rationale.add('object:person');
    } else if (objectLabel == 'vehicle' ||
        objectLabel == 'car' ||
        objectLabel == 'truck') {
      score += 2;
      rationale.add('object:vehicle');
    } else if (objectLabel == 'animal' ||
        objectLabel == 'cat' ||
        objectLabel == 'dog' ||
        objectLabel == 'bird') {
      score -= 18;
      rationale.add('object:animal');
    } else if (objectLabel == 'fire' || objectLabel == 'smoke') {
      score += 28;
      rationale.add('object:fire');
    } else if (objectLabel == 'water' || objectLabel == 'leak') {
      score += 20;
      rationale.add('object:water');
    } else if (objectLabel == 'equipment') {
      score += 14;
      rationale.add('object:equipment');
    } else if (objectLabel == 'unknown' || objectLabel == 'motion') {
      score += 6;
      rationale.add('object:unknown');
    } else if (objectLabel.isNotEmpty) {
      rationale.add('object:$objectLabel');
    }

    final signalText = '${event.headline} ${event.summary}'
        .trim()
        .toLowerCase();
    final faceMatchId = (event.faceMatchId ?? '').trim();
    final plateNumber = (event.plateNumber ?? '').trim();
    final identityPolicy = identityPolicyService.policyFor(
      clientId: event.clientId,
      siteId: event.siteId,
    );
    final flaggedFaceMatch = identityPolicy.matchesFlaggedFace(faceMatchId);
    final flaggedPlateMatch = identityPolicy.matchesFlaggedPlate(plateNumber);
    final allowedFaceMatch =
        !flaggedFaceMatch && identityPolicy.matchesAllowedFace(faceMatchId);
    final allowedPlateMatch =
        !flaggedPlateMatch && identityPolicy.matchesAllowedPlate(plateNumber);
    final temporaryAllowedMatch = temporaryIdentityApprovalService.matchAllowed(
      clientId: event.clientId,
      siteId: event.siteId,
      faceMatchId: faceMatchId,
      plateNumber: plateNumber,
      atUtc: event.occurredAt,
    );
    final explicitFlaggedIdentitySignal = flaggedFaceMatch || flaggedPlateMatch;
    final explicitAllowedIdentitySignal =
        !explicitFlaggedIdentitySignal &&
        (allowedFaceMatch || allowedPlateMatch);
    final identityRiskKeywordSignal =
        signalText.contains('watchlist') ||
        signalText.contains('unauthorized') ||
        signalText.contains('blacklist') ||
        signalText.contains('wanted') ||
        signalText.contains('stolen');
    final identityRiskSignal =
        explicitFlaggedIdentitySignal || identityRiskKeywordSignal;
    final temporaryIdentityAllowedSignal =
        !explicitFlaggedIdentitySignal &&
        !explicitAllowedIdentitySignal &&
        temporaryAllowedMatch.matched;
    final identityAllowedSignal =
        explicitAllowedIdentitySignal || temporaryIdentityAllowedSignal;
    if (faceMatchId.isNotEmpty) {
      if (flaggedFaceMatch) {
        score += 18;
        rationale.add('face_match:flagged');
      } else if (allowedFaceMatch) {
        score -= 14;
        rationale.add('face_match:allowed');
      } else if (temporaryAllowedMatch.matchedFace) {
        score -= 12;
        rationale.add('face_match:temporary_allowed');
      } else {
        score += identityRiskSignal ? 14 : 8;
        rationale.add('face_match');
      }
      if (identityRiskSignal && !flaggedFaceMatch) {
        rationale.add('face_match:risk');
      }
    }
    if (plateNumber.isNotEmpty) {
      if (flaggedPlateMatch) {
        score += 16;
        rationale.add('plate_match:flagged');
      } else if (allowedPlateMatch) {
        score -= 12;
        rationale.add('plate_match:allowed');
      } else if (temporaryAllowedMatch.matchedPlate) {
        score -= 10;
        rationale.add('plate_match:temporary_allowed');
      } else {
        score += identityRiskSignal ? 12 : 6;
        rationale.add('plate_match');
      }
      if (identityRiskSignal && !flaggedPlateMatch) {
        rationale.add('plate_match:risk');
      }
    }
    if (identityRiskSignal) {
      score += 8;
      rationale.add('signal:identity_risk');
    } else if (identityAllowedSignal) {
      score -= 8;
      rationale.add(
        temporaryIdentityAllowedSignal
            ? 'signal:identity_allowed_temporary'
            : 'signal:identity_allowed',
      );
    }
    final boundaryConcern =
        review.indicatesBoundaryConcern ||
        signalText.contains('line_crossing') ||
        signalText.contains('line crossing') ||
        signalText.contains('intrusion');
    if (boundaryConcern) {
      score += 8;
      rationale.add('signal:boundary');
    }
    final loiteringConcern =
        review.indicatesLoitering || signalText.contains('loiter');
    if (loiteringConcern) {
      score += 10;
      rationale.add('signal:loiter');
    }
    final fireSignal =
        review.indicatesFireSmoke ||
        signalText.contains('fire') ||
        signalText.contains('smoke') ||
        signalText.contains('flame');
    if (fireSignal) {
      score += 34;
      rationale.add('signal:fire');
    }
    final waterLeakSignal =
        review.indicatesWaterLeak ||
        signalText.contains('water leak') ||
        signalText.contains('leak') ||
        signalText.contains('flood') ||
        signalText.contains('burst pipe') ||
        signalText.contains('pipe burst');
    if (waterLeakSignal) {
      score += 24;
      rationale.add('signal:water_leak');
    }
    final environmentHazardSignal =
        review.indicatesEnvironmentHazard ||
        signalText.contains('hazard') ||
        signalText.contains('steam') ||
        signalText.contains('electrical') ||
        signalText.contains('equipment failure');
    if (environmentHazardSignal) {
      score += 18;
      rationale.add('signal:environment_hazard');
    }
    if (review.indicatesEscalationCandidate) {
      score += 6;
      rationale.add('signal:review_escalation');
    }

    if (repeatActivity) {
      score += 6;
      rationale.add('repeat');
    }
    if (groupedEventCount > 1) {
      final groupedBoost = (groupedEventCount - 1) * 2;
      score += groupedBoost;
      rationale.add('grouped:$groupedEventCount');
    }

    final effectiveRiskScore = score.clamp(1, 99);
    final shouldEscalate =
        fireSignal ||
        waterLeakSignal ||
        (environmentHazardSignal && effectiveRiskScore >= 84) ||
        effectiveRiskScore >= 96 ||
        (repeatActivity && objectLabel == 'person' && effectiveRiskScore >= 90);
    final shouldNotifyClient =
        shouldEscalate ||
        fireSignal ||
        waterLeakSignal ||
        environmentHazardSignal ||
        repeatActivity ||
        effectiveRiskScore >= 74;
    final postureLabel = _postureLabel(
      shouldEscalate: shouldEscalate,
      repeatActivity: repeatActivity,
      boundaryConcern: boundaryConcern,
      loiteringConcern: loiteringConcern,
      fireSignal: fireSignal,
      waterLeakSignal: waterLeakSignal,
      environmentHazardSignal: environmentHazardSignal,
      identityRiskSignal: identityRiskSignal,
      identityAllowedSignal: identityAllowedSignal,
      effectiveRiskScore: effectiveRiskScore,
    );

    return MonitoringWatchSceneAssessment(
      objectLabel: objectLabel,
      effectiveRiskScore: effectiveRiskScore,
      confidence: confidence,
      postureLabel: postureLabel,
      shouldNotifyClient: shouldNotifyClient,
      shouldEscalate: shouldEscalate,
      repeatActivity: repeatActivity,
      boundaryConcern: boundaryConcern,
      loiteringConcern: loiteringConcern,
      fireSignal: fireSignal,
      waterLeakSignal: waterLeakSignal,
      environmentHazardSignal: environmentHazardSignal,
      faceMatchId: faceMatchId.isEmpty ? null : faceMatchId,
      faceConfidence: event.faceConfidence,
      plateNumber: plateNumber.isEmpty ? null : plateNumber,
      plateConfidence: event.plateConfidence,
      identityRiskSignal: identityRiskSignal,
      identityAllowedSignal: identityAllowedSignal,
      temporaryIdentityAllowedSignal: temporaryIdentityAllowedSignal,
      temporaryIdentityValidUntilUtc: temporaryAllowedMatch.validUntilUtc,
      groupedEventCount: groupedEventCount,
      rationale: rationale,
    );
  }

  MonitoringWatchSceneConfidence _confidenceBand(
    double? objectConfidence,
    int baseRiskScore,
    MonitoringWatchVisionConfidence reviewConfidence,
  ) {
    final confidence = objectConfidence ?? -1;
    if (reviewConfidence == MonitoringWatchVisionConfidence.high ||
        confidence >= 0.85 ||
        baseRiskScore >= 88) {
      return MonitoringWatchSceneConfidence.high;
    }
    if (reviewConfidence == MonitoringWatchVisionConfidence.medium ||
        confidence >= 0.55 ||
        baseRiskScore >= 70) {
      return MonitoringWatchSceneConfidence.medium;
    }
    return MonitoringWatchSceneConfidence.low;
  }

  String _resolvedObjectLabel(
    IntelligenceReceived event,
    MonitoringWatchVisionReviewResult review,
  ) {
    final metadata = _normalizedObjectLabel(event.objectLabel);
    final reviewed = _normalizedObjectLabel(review.primaryObjectLabel);
    if (reviewed == metadata) {
      return metadata;
    }
    if (metadata == 'movement' ||
        metadata == 'motion' ||
        metadata == 'unknown') {
      return reviewed;
    }
    if (review.confidence == MonitoringWatchVisionConfidence.high &&
        reviewed != 'movement' &&
        reviewed != 'unknown') {
      return reviewed;
    }
    return metadata;
  }

  String _normalizedObjectLabel(String? raw) {
    final label = (raw ?? '').trim().toLowerCase();
    if (label.isEmpty) {
      return 'movement';
    }
    if (label == 'car' || label == 'truck') {
      return 'vehicle';
    }
    if (label == 'human' || label == 'intruder') {
      return 'person';
    }
    return label;
  }

  String _postureLabel({
    required bool shouldEscalate,
    required bool repeatActivity,
    required bool boundaryConcern,
    required bool loiteringConcern,
    required bool fireSignal,
    required bool waterLeakSignal,
    required bool environmentHazardSignal,
    required bool identityRiskSignal,
    required bool identityAllowedSignal,
    required int effectiveRiskScore,
  }) {
    if (fireSignal) {
      return 'fire and smoke emergency';
    }
    if (waterLeakSignal) {
      return 'flood or leak emergency';
    }
    if (environmentHazardSignal) {
      return 'environmental hazard alert';
    }
    if (shouldEscalate) {
      return 'escalation candidate';
    }
    if (repeatActivity) {
      return 'repeat monitored activity';
    }
    if (boundaryConcern && loiteringConcern) {
      return 'boundary loitering concern';
    }
    if (loiteringConcern) {
      return 'loitering concern';
    }
    if (boundaryConcern) {
      return 'boundary movement concern';
    }
    if (identityRiskSignal) {
      return 'identity match concern';
    }
    if (identityAllowedSignal) {
      return 'known allowed identity';
    }
    if (effectiveRiskScore >= 84) {
      return 'elevated monitored activity';
    }
    return 'monitored movement alert';
  }
}
