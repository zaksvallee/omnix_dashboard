import '../domain/events/intelligence_received.dart';
import '../domain/intelligence/news_item.dart';
import '../domain/intelligence/onyx_mo_record.dart';
import 'mo_ontology_service.dart';
import 'monitoring_scene_review_store.dart';
import 'monitoring_watch_vision_review_service.dart';

class MoExtractionService {
  final MoOntologyService ontologyService;

  const MoExtractionService({
    this.ontologyService = const MoOntologyService(),
  });

  OnyxMoRecord extractFromNewsItem(
    NewsItem item, {
    DateTime? observedAtUtc,
  }) {
    return extractExternalIncident(
      sourceId: item.id,
      title: item.title,
      summary: item.summary,
      sourceLabel: item.source,
      environmentHint: '${item.siteId} ${item.regionId}',
      observedAtUtc: observedAtUtc,
      metadata: <String, Object?>{
        'client_id': item.clientId,
        'region_id': item.regionId,
        'site_id': item.siteId,
        'risk_score': item.riskScore,
      },
    );
  }

  OnyxMoRecord extractExternalIncident({
    required String sourceId,
    required String title,
    required String summary,
    required String sourceLabel,
    String environmentHint = '',
    DateTime? observedAtUtc,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    final observedAt = (observedAtUtc ?? DateTime.now()).toUtc();
    final profile = ontologyService.profile(
      title: title,
      summary: summary,
      environmentHint: environmentHint,
    );
    final sourceConfidence = _externalSourceConfidence(sourceLabel);
    final validationStatus =
        profile.observabilityScore >= 0.15 &&
            sourceConfidence != 'low' &&
            profile.recommendedActionPlans.isNotEmpty
        ? OnyxMoValidationStatus.shadowMode
        : OnyxMoValidationStatus.canonicalized;
    return OnyxMoRecord(
      moId: 'MO-EXT-${_normalizeId(sourceId)}',
      title: title.trim(),
      environmentTypes: profile.environmentTypes,
      summary: _singleLine(summary),
      sourceType: OnyxMoSourceType.externalIncident,
      sourceLabel: sourceLabel.trim(),
      sourceConfidence: sourceConfidence,
      patternConfidence: profile.patternConfidence,
      behaviorStage: profile.behaviorStage,
      incidentType: profile.incidentType,
      preIncidentIndicators: profile.preIncidentIndicators,
      entryIndicators: profile.entryIndicators,
      insideBehaviorIndicators: profile.insideBehaviorIndicators,
      coordinationIndicators: profile.coordinationIndicators,
      extractionIndicators: profile.extractionIndicators,
      deceptionIndicators: profile.deceptionIndicators,
      systemPressureIndicators: profile.systemPressureIndicators,
      observableCues: profile.observableCues,
      falsePositiveConflicts: profile.falsePositiveConflicts,
      attackGoal: profile.attackGoal,
      evidenceQuality: profile.evidenceQuality,
      riskWeight: profile.riskWeight,
      siteTypeOverrides: profile.siteTypeOverrides,
      recommendedActionPlans: profile.recommendedActionPlans,
      observabilityScore: profile.observabilityScore,
      localRelevanceScore: profile.localRelevanceScore,
      firstSeenUtc: observedAt,
      lastSeenUtc: observedAt,
      trendScore: 0,
      validationStatus: validationStatus,
      metadata: <String, Object?>{
        'source_id': sourceId.trim(),
        ...metadata,
      },
    );
  }

  OnyxMoRecord extractInternalIncident({
    required IntelligenceReceived event,
    MonitoringSceneReviewRecord? sceneReview,
  }) {
    final sceneSummary = <String>[
      event.headline.trim(),
      event.summary.trim(),
      (sceneReview?.postureLabel ?? '').trim(),
      (sceneReview?.decisionSummary ?? '').trim(),
      (sceneReview?.summary ?? '').trim(),
    ].where((value) => value.isNotEmpty).join(' ');
    final profile = ontologyService.profile(
      title: event.headline,
      summary: sceneSummary,
      environmentHint: '${event.siteId} ${event.regionId}',
    );
    final observedAt = event.occurredAt.toUtc();
    return OnyxMoRecord(
      moId: 'MO-INT-${_normalizeId(event.intelligenceId)}',
      title: event.headline.trim(),
      environmentTypes: profile.environmentTypes,
      summary: _singleLine(sceneSummary),
      sourceType: OnyxMoSourceType.internalIncident,
      sourceLabel: '${event.provider.trim()}:${event.sourceType.trim()}',
      sourceConfidence: sceneReview == null ? 'medium' : 'high',
      patternConfidence: profile.patternConfidence == 'low'
          ? 'medium'
          : profile.patternConfidence,
      behaviorStage: profile.behaviorStage,
      incidentType: profile.incidentType,
      preIncidentIndicators: profile.preIncidentIndicators,
      entryIndicators: profile.entryIndicators,
      insideBehaviorIndicators: profile.insideBehaviorIndicators,
      coordinationIndicators: profile.coordinationIndicators,
      extractionIndicators: profile.extractionIndicators,
      deceptionIndicators: profile.deceptionIndicators,
      systemPressureIndicators: profile.systemPressureIndicators,
      observableCues: profile.observableCues,
      falsePositiveConflicts: profile.falsePositiveConflicts,
      attackGoal: profile.attackGoal,
      evidenceQuality: 'high',
      riskWeight: profile.riskWeight,
      siteTypeOverrides: profile.siteTypeOverrides,
      recommendedActionPlans: {
        ...profile.recommendedActionPlans,
        if (profile.recommendedActionPlans.isNotEmpty) 'FEED GLOBAL POSTURE',
      }.toList(growable: false),
      observabilityScore: profile.observabilityScore,
      localRelevanceScore: profile.localRelevanceScore < 0.85
          ? 0.85
          : profile.localRelevanceScore,
      firstSeenUtc: observedAt,
      lastSeenUtc: observedAt,
      trendScore: event.riskScore / 100,
      validationStatus: OnyxMoValidationStatus.validated,
      metadata: <String, Object?>{
        'intelligence_id': event.intelligenceId,
        'client_id': event.clientId,
        'region_id': event.regionId,
        'site_id': event.siteId,
        'camera_id': event.cameraId ?? '',
        'provider': event.provider,
        'source_type': event.sourceType,
        'scene_posture_label': sceneReview?.postureLabel ?? '',
        'scene_decision_label': sceneReview?.decisionLabel ?? '',
      },
    );
  }

  OnyxMoRecord extractObservedScene({
    required IntelligenceReceived event,
    required MonitoringWatchVisionReviewResult review,
  }) {
    final sceneSummary = <String>[
      event.headline.trim(),
      event.summary.trim(),
      review.summary.trim(),
      review.tags.join(' ').trim(),
    ].where((value) => value.isNotEmpty).join(' ');
    final profile = ontologyService.profile(
      title: event.headline,
      summary: sceneSummary,
      environmentHint: '${event.siteId} ${event.regionId}',
    );
    final observedAt = event.occurredAt.toUtc();
    return OnyxMoRecord(
      moId: 'MO-OBS-${_normalizeId(event.intelligenceId)}',
      title: event.headline.trim(),
      environmentTypes: profile.environmentTypes,
      summary: _singleLine(sceneSummary),
      sourceType: OnyxMoSourceType.internalIncident,
      sourceLabel: review.sourceLabel.trim(),
      sourceConfidence: review.usedFallback ? 'medium' : 'high',
      patternConfidence: profile.patternConfidence == 'low'
          ? 'medium'
          : profile.patternConfidence,
      behaviorStage: profile.behaviorStage,
      incidentType: profile.incidentType,
      preIncidentIndicators: profile.preIncidentIndicators,
      entryIndicators: profile.entryIndicators,
      insideBehaviorIndicators: profile.insideBehaviorIndicators,
      coordinationIndicators: profile.coordinationIndicators,
      extractionIndicators: profile.extractionIndicators,
      deceptionIndicators: profile.deceptionIndicators,
      systemPressureIndicators: profile.systemPressureIndicators,
      observableCues: profile.observableCues,
      falsePositiveConflicts: profile.falsePositiveConflicts,
      attackGoal: profile.attackGoal,
      evidenceQuality: review.usedFallback ? 'medium' : 'high',
      riskWeight: profile.riskWeight,
      siteTypeOverrides: profile.siteTypeOverrides,
      recommendedActionPlans: profile.recommendedActionPlans,
      observabilityScore: profile.observabilityScore,
      localRelevanceScore: profile.localRelevanceScore,
      firstSeenUtc: observedAt,
      lastSeenUtc: observedAt,
      trendScore: event.riskScore / 100,
      validationStatus: OnyxMoValidationStatus.validated,
      metadata: <String, Object?>{
        'intelligence_id': event.intelligenceId,
        'client_id': event.clientId,
        'region_id': event.regionId,
        'site_id': event.siteId,
        'camera_id': event.cameraId ?? '',
        'review_tags': review.tags,
      },
    );
  }

  String _externalSourceConfidence(String sourceLabel) {
    final normalized = sourceLabel.trim().toLowerCase();
    if (normalized.contains('police') ||
        normalized.contains('security') ||
        normalized.contains('insurance') ||
        normalized.contains('public alert')) {
      return 'high';
    }
    if (normalized.contains('social')) {
      return 'low';
    }
    return 'medium';
  }

  String _normalizeId(String value) {
    final normalized = value.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]+'),
      '-',
    );
    return normalized.isEmpty ? 'UNKNOWN' : normalized;
  }

  String _singleLine(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
