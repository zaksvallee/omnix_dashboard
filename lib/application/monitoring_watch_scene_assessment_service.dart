import '../domain/events/intelligence_received.dart';
import 'hazard_response_directive_service.dart';
import 'intelligence_event_object_semantics.dart';
import 'mo_runtime_matching_service.dart';
import 'monitoring_identity_policy_service.dart';
import 'monitoring_temporary_identity_approval_service.dart';
import 'monitoring_watch_runtime_store.dart';
import 'monitoring_watch_vision_review_service.dart';

enum MonitoringWatchSceneConfidence { low, medium, high }

enum MonitoringWatchTrackedPostureStage { none, innocent, suspicious, critical }

enum MonitoringWatchZoneSensitivity {
  none,
  publicApproach,
  managedApproach,
  restrictedZone,
  sensitiveZone,
}

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
  final String? trackId;
  final int trackedEventCount;
  final Duration trackedPresenceWindow;
  final MonitoringWatchTrackedPostureStage trackedPostureStage;
  final String trackedPostureLabel;
  final MonitoringWatchZoneSensitivity zoneSensitivity;
  final String zoneLabel;
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
  final List<String> moShadowMatchTitles;
  final String moShadowSummary;

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
    this.trackId,
    this.trackedEventCount = 1,
    this.trackedPresenceWindow = Duration.zero,
    this.trackedPostureStage = MonitoringWatchTrackedPostureStage.none,
    this.trackedPostureLabel = '',
    this.zoneSensitivity = MonitoringWatchZoneSensitivity.none,
    this.zoneLabel = '',
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
    this.moShadowMatchTitles = const <String>[],
    this.moShadowSummary = '',
  });
}

class MonitoringWatchSceneAssessmentService {
  static const _hazardDirectiveService = HazardResponseDirectiveService();

  final MonitoringIdentityPolicyService identityPolicyService;
  final MonitoringTemporaryIdentityApprovalService
  temporaryIdentityApprovalService;
  final MoRuntimeMatchingService moRuntimeMatchingService;

  const MonitoringWatchSceneAssessmentService({
    this.identityPolicyService = const MonitoringIdentityPolicyService(),
    this.temporaryIdentityApprovalService =
        const MonitoringTemporaryIdentityApprovalService(),
    this.moRuntimeMatchingService = const MoRuntimeMatchingService(),
  });

  MonitoringWatchSceneAssessment assess({
    required IntelligenceReceived event,
    required MonitoringWatchVisionReviewResult review,
    required int priorReviewedEvents,
    int groupedEventCount = 1,
    List<IntelligenceReceived> relatedEvents = const <IntelligenceReceived>[],
    MonitoringWatchTrackedSubjectState? persistedTrackedSubject,
  }) {
    final objectLabel = _resolvedObjectLabel(event, review);
    final zoneContext = _zoneContextFor(event);
    final trackedSubjectActivity = _trackedSubjectActivityFor(
      event: event,
      objectLabel: objectLabel,
      zoneSensitivity: zoneContext.sensitivity,
      relatedEvents: relatedEvents,
      persistedTrackedSubject: persistedTrackedSubject,
    );
    final repeatActivity =
        priorReviewedEvents > 0 ||
        (trackedSubjectActivity.repeatDetected &&
            trackedSubjectActivity.postureStage !=
                MonitoringWatchTrackedPostureStage.innocent);
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

    switch (zoneContext.sensitivity) {
      case MonitoringWatchZoneSensitivity.none:
        break;
      case MonitoringWatchZoneSensitivity.publicApproach:
        rationale.add('zone:public_approach');
        break;
      case MonitoringWatchZoneSensitivity.managedApproach:
        rationale.add('zone:managed_approach');
        break;
      case MonitoringWatchZoneSensitivity.restrictedZone:
        rationale.add('zone:restricted');
        break;
      case MonitoringWatchZoneSensitivity.sensitiveZone:
        rationale.add('zone:sensitive');
        break;
    }

    var weaponSignal = false;
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
    } else if (objectLabel == 'backpack' || objectLabel == 'bag') {
      score += 10;
      rationale.add('object:$objectLabel');
    } else if (objectLabel == 'knife') {
      weaponSignal = true;
      score += 30;
      rationale.add('object:knife');
    } else if (objectLabel == 'weapon' || objectLabel == 'firearm') {
      weaponSignal = true;
      score += 36;
      rationale.add('object:$objectLabel');
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
        review.indicatesLoitering ||
        signalText.contains('loiter') ||
        trackedSubjectActivity.loiteringConcern;
    if (loiteringConcern) {
      score += 10;
      rationale.add('signal:loiter');
    }
    final hazardSignal = _hazardSignalForAssessment(
      review: review,
      signalText: signalText,
      objectLabel: objectLabel,
    );
    final fireSignal = hazardSignal == 'fire';
    if (fireSignal) {
      score += 34;
      rationale.add('signal:fire');
    }
    final waterLeakSignal = hazardSignal == 'water_leak';
    if (waterLeakSignal) {
      score += 24;
      rationale.add('signal:water_leak');
    }
    final environmentHazardSignal = hazardSignal == 'environment_hazard';
    if (environmentHazardSignal) {
      score += 18;
      rationale.add('signal:environment_hazard');
    }
    if (review.indicatesEscalationCandidate) {
      score += 6;
      rationale.add('signal:review_escalation');
    }

    if (trackedSubjectActivity.repeatDetected) {
      final trackRepeatBoost = trackedSubjectActivity.eventCount >= 4 ? 8 : 6;
      score += trackRepeatBoost;
      rationale.add('track_repeat:${trackedSubjectActivity.eventCount}');
      if (trackedSubjectActivity.presenceWindow > Duration.zero) {
        rationale.add(
          'track_span:${trackedSubjectActivity.presenceWindow.inSeconds}s',
        );
      }
    }
    if (trackedSubjectActivity.loiteringConcern) {
      score += 4;
      rationale.add('track_loiter');
    }
    switch (trackedSubjectActivity.postureStage) {
      case MonitoringWatchTrackedPostureStage.none:
        break;
      case MonitoringWatchTrackedPostureStage.innocent:
        rationale.add('track_posture:passing_by');
        break;
      case MonitoringWatchTrackedPostureStage.suspicious:
        score += 8;
        rationale.add('track_posture:dwell_alert');
        break;
      case MonitoringWatchTrackedPostureStage.critical:
        score += 16;
        rationale.add('track_posture:loitering_staging');
        break;
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
    final moShadowMatches = moRuntimeMatchingService.matchObservedScene(
      event: event,
      review: review,
    );
    if (moShadowMatches.isNotEmpty) {
      rationale.add('mo_shadow:${moShadowMatches.first.moId}');
    }
    final shouldEscalate =
        fireSignal ||
        waterLeakSignal ||
        weaponSignal ||
        (trackedSubjectActivity.postureStage ==
                MonitoringWatchTrackedPostureStage.critical &&
            !identityAllowedSignal) ||
        (environmentHazardSignal && effectiveRiskScore >= 84) ||
        effectiveRiskScore >= 96 ||
        (repeatActivity && objectLabel == 'person' && effectiveRiskScore >= 90);
    final shouldNotifyClient =
        shouldEscalate ||
        fireSignal ||
        waterLeakSignal ||
        environmentHazardSignal ||
        repeatActivity ||
        (trackedSubjectActivity.postureStage ==
                MonitoringWatchTrackedPostureStage.suspicious &&
            !identityAllowedSignal) ||
        effectiveRiskScore >= 74;
    final postureLabel = _postureLabel(
      shouldEscalate: shouldEscalate,
      repeatActivity: repeatActivity,
      boundaryConcern: boundaryConcern,
      loiteringConcern: loiteringConcern,
      trackedPostureStage: trackedSubjectActivity.postureStage,
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
      trackId: trackedSubjectActivity.trackId,
      trackedEventCount: trackedSubjectActivity.eventCount,
      trackedPresenceWindow: trackedSubjectActivity.presenceWindow,
      trackedPostureStage: trackedSubjectActivity.postureStage,
      trackedPostureLabel: trackedSubjectActivity.postureLabel,
      zoneSensitivity: zoneContext.sensitivity,
      zoneLabel: zoneContext.label,
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
      moShadowMatchTitles: moShadowMatches
          .map((match) => match.title)
          .toList(growable: false),
      moShadowSummary: moRuntimeMatchingService.shadowSummary(moShadowMatches),
    );
  }

  String _hazardSignalForAssessment({
    required MonitoringWatchVisionReviewResult review,
    required String signalText,
    required String objectLabel,
  }) {
    if (objectLabel == 'firearm' ||
        objectLabel == 'weapon' ||
        objectLabel == 'knife') {
      return '';
    }
    if (review.indicatesFireSmoke) {
      return 'fire';
    }
    if (review.indicatesWaterLeak) {
      return 'water_leak';
    }
    if (review.indicatesEnvironmentHazard) {
      return 'environment_hazard';
    }
    final baseSignal = _hazardDirectiveService.hazardSignal(
      postureLabel: signalText,
      objectLabel: objectLabel,
    );
    if (baseSignal.isNotEmpty) {
      return baseSignal;
    }
    if (signalText.contains('flame')) {
      return 'fire';
    }
    if (signalText.contains('water leak') ||
        signalText.contains('burst pipe') ||
        signalText.contains('pipe burst')) {
      return 'water_leak';
    }
    if (signalText.contains('steam') ||
        signalText.contains('electrical') ||
        signalText.contains('equipment failure')) {
      return 'environment_hazard';
    }
    return '';
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
    final metadata = _semanticObjectLabelForEvent(event);
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

  String _semanticObjectLabelForEvent(IntelligenceReceived event) {
    final directLabel = _normalizedObjectLabel(event.objectLabel);
    return resolveIdentityBackedObjectLabel(
      event: event,
      directObjectLabel: directLabel,
    );
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
    required MonitoringWatchTrackedPostureStage trackedPostureStage,
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
    if (trackedPostureStage == MonitoringWatchTrackedPostureStage.critical &&
        boundaryConcern) {
      return 'critical boundary loitering/staging';
    }
    if (trackedPostureStage == MonitoringWatchTrackedPostureStage.critical) {
      return 'critical loitering/staging';
    }
    if (shouldEscalate) {
      return 'escalation candidate';
    }
    if (boundaryConcern && loiteringConcern) {
      return 'boundary loitering concern';
    }
    if (trackedPostureStage == MonitoringWatchTrackedPostureStage.suspicious &&
        boundaryConcern) {
      return 'boundary dwell alert';
    }
    if (trackedPostureStage == MonitoringWatchTrackedPostureStage.suspicious) {
      return 'dwell alert';
    }
    if (trackedPostureStage == MonitoringWatchTrackedPostureStage.innocent) {
      return 'passing by';
    }
    if (loiteringConcern) {
      return 'loitering concern';
    }
    if (repeatActivity) {
      return 'repeat monitored activity';
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

class _TrackedSubjectActivity {
  final String? trackId;
  final int eventCount;
  final Duration presenceWindow;
  final bool repeatDetected;
  final bool loiteringConcern;
  final MonitoringWatchTrackedPostureStage postureStage;
  final String postureLabel;

  const _TrackedSubjectActivity({
    this.trackId,
    this.eventCount = 1,
    this.presenceWindow = Duration.zero,
    this.repeatDetected = false,
    this.loiteringConcern = false,
    this.postureStage = MonitoringWatchTrackedPostureStage.none,
    this.postureLabel = '',
  });
}

extension on MonitoringWatchSceneAssessmentService {
  _ZoneContext _zoneContextFor(IntelligenceReceived event) {
    final zoneLabel = (event.zone ?? '').trim();
    final searchable = [
      zoneLabel,
      event.cameraId ?? '',
      event.headline,
      event.summary,
    ].join(' ').toLowerCase();
    if (searchable.trim().isEmpty) {
      return const _ZoneContext(
        sensitivity: MonitoringWatchZoneSensitivity.none,
      );
    }
    if (_containsAny(searchable, const [
      'generator room',
      'server room',
      'control room',
      'stock room',
      'cash office',
      'vault',
      'armory',
      'loading bay',
    ])) {
      return _ZoneContext(
        sensitivity: MonitoringWatchZoneSensitivity.sensitiveZone,
        label: zoneLabel,
      );
    }
    if (_containsAny(searchable, const [
      'front gate',
      'main gate',
      'back gate',
      'rear gate',
      'side gate',
      'pedestrian gate',
      'driveway gate',
      'perimeter',
      'boundary',
      'entrance',
      'fence line',
      'fence',
      'gate',
    ])) {
      return _ZoneContext(
        sensitivity: MonitoringWatchZoneSensitivity.restrictedZone,
        label: zoneLabel,
      );
    }
    if (_containsAny(searchable, const [
      'driveway lane',
      'public driveway',
      'public lane',
      'roadside',
      'street',
      'road',
      'curb',
      'sidewalk',
      'verge',
    ])) {
      return _ZoneContext(
        sensitivity: MonitoringWatchZoneSensitivity.publicApproach,
        label: zoneLabel,
      );
    }
    if (_containsAny(searchable, const [
      'driveway',
      'parking',
      'car park',
      'approach',
      'forecourt',
      'yard',
    ])) {
      return _ZoneContext(
        sensitivity: MonitoringWatchZoneSensitivity.managedApproach,
        label: zoneLabel,
      );
    }
    return _ZoneContext(
      sensitivity: MonitoringWatchZoneSensitivity.managedApproach,
      label: zoneLabel,
    );
  }

  _TrackedSubjectActivity _trackedSubjectActivityFor({
    required IntelligenceReceived event,
    required String objectLabel,
    required MonitoringWatchZoneSensitivity zoneSensitivity,
    required List<IntelligenceReceived> relatedEvents,
    MonitoringWatchTrackedSubjectState? persistedTrackedSubject,
  }) {
    final trackId = (event.trackId ?? '').trim();
    if (trackId.isEmpty) {
      return const _TrackedSubjectActivity();
    }
    final matched = <String, IntelligenceReceived>{};
    for (final candidate in <IntelligenceReceived>[event, ...relatedEvents]) {
      final candidateTrackId = (candidate.trackId ?? '').trim();
      if (candidateTrackId != trackId) {
        continue;
      }
      final dedupeKey = candidate.intelligenceId.trim().isNotEmpty
          ? candidate.intelligenceId.trim()
          : [
              candidate.externalId,
              candidate.occurredAt.toUtc().toIso8601String(),
            ].join('|');
      matched[dedupeKey] = candidate;
    }
    final events = matched.values.toList(growable: false)
      ..sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
    final persistedMatchesTrack =
        persistedTrackedSubject != null &&
        persistedTrackedSubject.trackId.trim() == trackId;
    if (events.isEmpty && !persistedMatchesTrack) {
      return _TrackedSubjectActivity(trackId: trackId);
    }
    var eventCount = events.length;
    DateTime? earliest = events.isEmpty
        ? null
        : events.first.occurredAt.toUtc();
    DateTime? latest = events.isEmpty ? null : events.last.occurredAt.toUtc();
    if (persistedMatchesTrack) {
      eventCount += persistedTrackedSubject.eventCount;
      earliest = earliest == null
          ? persistedTrackedSubject.firstSeenAtUtc
          : (earliest.isBefore(persistedTrackedSubject.firstSeenAtUtc)
                ? earliest
                : persistedTrackedSubject.firstSeenAtUtc);
      latest = latest == null
          ? persistedTrackedSubject.lastSeenAtUtc
          : (latest.isAfter(persistedTrackedSubject.lastSeenAtUtc)
                ? latest
                : persistedTrackedSubject.lastSeenAtUtc);
    }
    final presenceWindow = latest != null && earliest != null
        ? latest.difference(earliest)
        : Duration.zero;
    final normalizedObject = _normalizedObjectLabel(objectLabel);
    final postureStage = _trackedPostureStageFor(
      normalizedObject: normalizedObject,
      zoneSensitivity: zoneSensitivity,
      presenceWindow: presenceWindow,
      eventCount: eventCount,
    );
    final loiteringConcern = switch (normalizedObject) {
      'person' =>
        postureStage == MonitoringWatchTrackedPostureStage.critical ||
            (eventCount >= 2 && presenceWindow >= const Duration(minutes: 8)),
      'vehicle' =>
        postureStage == MonitoringWatchTrackedPostureStage.critical ||
            (eventCount >= 2 && presenceWindow >= const Duration(minutes: 10)),
      _ => false,
    };
    return _TrackedSubjectActivity(
      trackId: trackId,
      eventCount: eventCount,
      presenceWindow: presenceWindow,
      repeatDetected: eventCount > 1,
      loiteringConcern: loiteringConcern,
      postureStage: postureStage,
      postureLabel: switch (postureStage) {
        MonitoringWatchTrackedPostureStage.none => '',
        MonitoringWatchTrackedPostureStage.innocent => 'passing by',
        MonitoringWatchTrackedPostureStage.suspicious => 'dwell alert',
        MonitoringWatchTrackedPostureStage.critical => 'loitering/staging',
      },
    );
  }

  MonitoringWatchTrackedPostureStage _trackedPostureStageFor({
    required String normalizedObject,
    required MonitoringWatchZoneSensitivity zoneSensitivity,
    required Duration presenceWindow,
    required int eventCount,
  }) {
    if (normalizedObject != 'person' &&
        normalizedObject != 'vehicle' &&
        normalizedObject != 'unknown' &&
        normalizedObject != 'movement' &&
        normalizedObject != 'motion') {
      return MonitoringWatchTrackedPostureStage.none;
    }
    if (eventCount <= 1 && presenceWindow <= Duration.zero) {
      return MonitoringWatchTrackedPostureStage.none;
    }
    final suspiciousThreshold = switch (zoneSensitivity) {
      MonitoringWatchZoneSensitivity.sensitiveZone => const Duration(
        seconds: 45,
      ),
      MonitoringWatchZoneSensitivity.restrictedZone => const Duration(
        minutes: 1,
      ),
      MonitoringWatchZoneSensitivity.publicApproach => const Duration(
        minutes: 3,
      ),
      MonitoringWatchZoneSensitivity.managedApproach ||
      MonitoringWatchZoneSensitivity.none => const Duration(
        minutes: 1,
        seconds: 30,
      ),
    };
    final criticalThreshold = switch (zoneSensitivity) {
      MonitoringWatchZoneSensitivity.sensitiveZone => const Duration(
        minutes: 2,
      ),
      MonitoringWatchZoneSensitivity.restrictedZone => const Duration(
        minutes: 3,
      ),
      MonitoringWatchZoneSensitivity.publicApproach => const Duration(
        minutes: 7,
      ),
      MonitoringWatchZoneSensitivity.managedApproach ||
      MonitoringWatchZoneSensitivity.none => const Duration(minutes: 4),
    };
    if (presenceWindow >= criticalThreshold) {
      return MonitoringWatchTrackedPostureStage.critical;
    }
    if (presenceWindow >= suspiciousThreshold) {
      return MonitoringWatchTrackedPostureStage.suspicious;
    }
    return MonitoringWatchTrackedPostureStage.innocent;
  }

  bool _containsAny(String text, List<String> needles) {
    for (final needle in needles) {
      if (text.contains(needle)) {
        return true;
      }
    }
    return false;
  }
}

class _ZoneContext {
  final MonitoringWatchZoneSensitivity sensitivity;
  final String label;

  const _ZoneContext({required this.sensitivity, this.label = ''});
}
