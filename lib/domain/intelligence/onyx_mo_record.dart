enum OnyxMoSourceType {
  externalIncident,
  internalIncident,
  operatorOutcome,
}

enum OnyxMoValidationStatus {
  candidate,
  canonicalized,
  validated,
  shadowMode,
  production,
}

class OnyxMoRecord {
  final String moId;
  final String title;
  final List<String> environmentTypes;
  final String summary;
  final OnyxMoSourceType sourceType;
  final String sourceLabel;
  final String sourceConfidence;
  final String patternConfidence;
  final String behaviorStage;
  final String incidentType;
  final List<String> preIncidentIndicators;
  final List<String> entryIndicators;
  final List<String> insideBehaviorIndicators;
  final List<String> coordinationIndicators;
  final List<String> extractionIndicators;
  final List<String> deceptionIndicators;
  final List<String> systemPressureIndicators;
  final List<String> observableCues;
  final List<String> falsePositiveConflicts;
  final String attackGoal;
  final String evidenceQuality;
  final int riskWeight;
  final Map<String, int> siteTypeOverrides;
  final List<String> recommendedActionPlans;
  final double observabilityScore;
  final double localRelevanceScore;
  final DateTime firstSeenUtc;
  final DateTime lastSeenUtc;
  final double trendScore;
  final OnyxMoValidationStatus validationStatus;
  final Map<String, Object?> metadata;

  const OnyxMoRecord({
    required this.moId,
    required this.title,
    this.environmentTypes = const <String>[],
    required this.summary,
    required this.sourceType,
    this.sourceLabel = '',
    this.sourceConfidence = 'low',
    this.patternConfidence = 'low',
    this.behaviorStage = 'unknown',
    this.incidentType = 'unknown',
    this.preIncidentIndicators = const <String>[],
    this.entryIndicators = const <String>[],
    this.insideBehaviorIndicators = const <String>[],
    this.coordinationIndicators = const <String>[],
    this.extractionIndicators = const <String>[],
    this.deceptionIndicators = const <String>[],
    this.systemPressureIndicators = const <String>[],
    this.observableCues = const <String>[],
    this.falsePositiveConflicts = const <String>[],
    this.attackGoal = 'unknown',
    this.evidenceQuality = 'medium',
    this.riskWeight = 0,
    this.siteTypeOverrides = const <String, int>{},
    this.recommendedActionPlans = const <String>[],
    this.observabilityScore = 0,
    this.localRelevanceScore = 0,
    required this.firstSeenUtc,
    required this.lastSeenUtc,
    this.trendScore = 0,
    this.validationStatus = OnyxMoValidationStatus.candidate,
    this.metadata = const <String, Object?>{},
  });

  OnyxMoRecord copyWith({
    String? moId,
    String? title,
    List<String>? environmentTypes,
    String? summary,
    OnyxMoSourceType? sourceType,
    String? sourceLabel,
    String? sourceConfidence,
    String? patternConfidence,
    String? behaviorStage,
    String? incidentType,
    List<String>? preIncidentIndicators,
    List<String>? entryIndicators,
    List<String>? insideBehaviorIndicators,
    List<String>? coordinationIndicators,
    List<String>? extractionIndicators,
    List<String>? deceptionIndicators,
    List<String>? systemPressureIndicators,
    List<String>? observableCues,
    List<String>? falsePositiveConflicts,
    String? attackGoal,
    String? evidenceQuality,
    int? riskWeight,
    Map<String, int>? siteTypeOverrides,
    List<String>? recommendedActionPlans,
    double? observabilityScore,
    double? localRelevanceScore,
    DateTime? firstSeenUtc,
    DateTime? lastSeenUtc,
    double? trendScore,
    OnyxMoValidationStatus? validationStatus,
    Map<String, Object?>? metadata,
  }) {
    return OnyxMoRecord(
      moId: moId ?? this.moId,
      title: title ?? this.title,
      environmentTypes: environmentTypes ?? this.environmentTypes,
      summary: summary ?? this.summary,
      sourceType: sourceType ?? this.sourceType,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      sourceConfidence: sourceConfidence ?? this.sourceConfidence,
      patternConfidence: patternConfidence ?? this.patternConfidence,
      behaviorStage: behaviorStage ?? this.behaviorStage,
      incidentType: incidentType ?? this.incidentType,
      preIncidentIndicators:
          preIncidentIndicators ?? this.preIncidentIndicators,
      entryIndicators: entryIndicators ?? this.entryIndicators,
      insideBehaviorIndicators:
          insideBehaviorIndicators ?? this.insideBehaviorIndicators,
      coordinationIndicators:
          coordinationIndicators ?? this.coordinationIndicators,
      extractionIndicators:
          extractionIndicators ?? this.extractionIndicators,
      deceptionIndicators: deceptionIndicators ?? this.deceptionIndicators,
      systemPressureIndicators:
          systemPressureIndicators ?? this.systemPressureIndicators,
      observableCues: observableCues ?? this.observableCues,
      falsePositiveConflicts:
          falsePositiveConflicts ?? this.falsePositiveConflicts,
      attackGoal: attackGoal ?? this.attackGoal,
      evidenceQuality: evidenceQuality ?? this.evidenceQuality,
      riskWeight: riskWeight ?? this.riskWeight,
      siteTypeOverrides: siteTypeOverrides ?? this.siteTypeOverrides,
      recommendedActionPlans:
          recommendedActionPlans ?? this.recommendedActionPlans,
      observabilityScore: observabilityScore ?? this.observabilityScore,
      localRelevanceScore: localRelevanceScore ?? this.localRelevanceScore,
      firstSeenUtc: firstSeenUtc ?? this.firstSeenUtc,
      lastSeenUtc: lastSeenUtc ?? this.lastSeenUtc,
      trendScore: trendScore ?? this.trendScore,
      validationStatus: validationStatus ?? this.validationStatus,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'mo_id': moId,
      'title': title,
      'environment_types': environmentTypes,
      'summary': summary,
      'source_type': sourceType.name,
      'source_label': sourceLabel,
      'source_confidence': sourceConfidence,
      'pattern_confidence': patternConfidence,
      'behavior_stage': behaviorStage,
      'incident_type': incidentType,
      'pre_incident_indicators': preIncidentIndicators,
      'entry_indicators': entryIndicators,
      'inside_behavior_indicators': insideBehaviorIndicators,
      'coordination_indicators': coordinationIndicators,
      'extraction_indicators': extractionIndicators,
      'deception_indicators': deceptionIndicators,
      'system_pressure_indicators': systemPressureIndicators,
      'observable_cues': observableCues,
      'false_positive_conflicts': falsePositiveConflicts,
      'attack_goal': attackGoal,
      'evidence_quality': evidenceQuality,
      'risk_weight': riskWeight,
      'site_type_overrides': siteTypeOverrides.map(
        (key, value) => MapEntry(key, value),
      ),
      'recommended_action_plans': recommendedActionPlans,
      'observability_score': observabilityScore,
      'local_relevance_score': localRelevanceScore,
      'first_seen_utc': firstSeenUtc.toIso8601String(),
      'last_seen_utc': lastSeenUtc.toIso8601String(),
      'trend_score': trendScore,
      'validation_status': validationStatus.name,
      'metadata': metadata,
    };
  }

  static OnyxMoRecord fromMap(Map<String, Object?> map) {
    return OnyxMoRecord(
      moId: (map['mo_id'] ?? '').toString().trim(),
      title: (map['title'] ?? '').toString().trim(),
      environmentTypes: _stringList(map['environment_types']),
      summary: (map['summary'] ?? '').toString().trim(),
      sourceType: OnyxMoSourceType.values.firstWhere(
        (value) => value.name == (map['source_type'] ?? '').toString().trim(),
        orElse: () => OnyxMoSourceType.externalIncident,
      ),
      sourceLabel: (map['source_label'] ?? '').toString().trim(),
      sourceConfidence: (map['source_confidence'] ?? 'low').toString().trim(),
      patternConfidence:
          (map['pattern_confidence'] ?? 'low').toString().trim(),
      behaviorStage: (map['behavior_stage'] ?? '').toString().trim(),
      incidentType: (map['incident_type'] ?? '').toString().trim(),
      preIncidentIndicators: _stringList(map['pre_incident_indicators']),
      entryIndicators: _stringList(map['entry_indicators']),
      insideBehaviorIndicators:
          _stringList(map['inside_behavior_indicators']),
      coordinationIndicators: _stringList(map['coordination_indicators']),
      extractionIndicators: _stringList(map['extraction_indicators']),
      deceptionIndicators: _stringList(map['deception_indicators']),
      systemPressureIndicators:
          _stringList(map['system_pressure_indicators']),
      observableCues: _stringList(map['observable_cues']),
      falsePositiveConflicts: _stringList(map['false_positive_conflicts']),
      attackGoal: (map['attack_goal'] ?? 'unknown').toString().trim(),
      evidenceQuality: (map['evidence_quality'] ?? 'medium')
          .toString()
          .trim(),
      riskWeight: (map['risk_weight'] as num?)?.toInt() ?? 0,
      siteTypeOverrides: _intMap(map['site_type_overrides']),
      recommendedActionPlans: _stringList(map['recommended_action_plans']),
      observabilityScore:
          (map['observability_score'] as num?)?.toDouble() ?? 0,
      localRelevanceScore:
          (map['local_relevance_score'] as num?)?.toDouble() ?? 0,
      firstSeenUtc: DateTime.tryParse(
            (map['first_seen_utc'] ?? '').toString().trim(),
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lastSeenUtc: DateTime.tryParse(
            (map['last_seen_utc'] ?? '').toString().trim(),
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      trendScore: (map['trend_score'] as num?)?.toDouble() ?? 0,
      validationStatus: OnyxMoValidationStatus.values.firstWhere(
        (value) =>
            value.name == (map['validation_status'] ?? '').toString().trim(),
        orElse: () => OnyxMoValidationStatus.candidate,
      ),
      metadata: map['metadata'] is Map
          ? (map['metadata'] as Map).map(
              (key, value) => MapEntry(key.toString(), value as Object?),
            )
          : const <String, Object?>{},
    );
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) {
      return const <String>[];
    }
    return raw
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, int> _intMap(Object? raw) {
    if (raw is! Map) {
      return const <String, int>{};
    }
    final output = <String, int>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty) {
        continue;
      }
      final value = (entry.value as num?)?.toInt();
      if (value == null) {
        continue;
      }
      output[key] = value;
    }
    return output;
  }
}
