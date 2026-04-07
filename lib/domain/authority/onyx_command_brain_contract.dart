import 'onyx_task_protocol.dart';

enum OnyxSpecialist {
  dispatch,
  track,
  cctv,
  clientComms,
  reports,
  guardOps,
  policy,
}

extension OnyxSpecialistLabel on OnyxSpecialist {
  String get label => switch (this) {
    OnyxSpecialist.dispatch => 'Dispatch specialist',
    OnyxSpecialist.track => 'Track specialist',
    OnyxSpecialist.cctv => 'CCTV specialist',
    OnyxSpecialist.clientComms => 'Client Comms specialist',
    OnyxSpecialist.reports => 'Reports specialist',
    OnyxSpecialist.guardOps => 'Guard Ops specialist',
    OnyxSpecialist.policy => 'Policy specialist',
  };
}

enum SpecialistAssessmentPriority { low, medium, high, critical }

enum BrainDecisionMode {
  deterministic,
  corroboratedSynthesis,
  specialistConstraint,
}

extension BrainDecisionModeLabels on BrainDecisionMode {
  String get label => switch (this) {
    BrainDecisionMode.deterministic => 'deterministic hold',
    BrainDecisionMode.corroboratedSynthesis => 'corroborated synthesis',
    BrainDecisionMode.specialistConstraint => 'specialist constraint',
  };

  String get railLabel => switch (this) {
    BrainDecisionMode.deterministic => 'brain deterministic',
    BrainDecisionMode.corroboratedSynthesis => 'brain corroborated',
    BrainDecisionMode.specialistConstraint => 'brain constrained',
  };
}

enum BrainDecisionBiasSource { replayPolicy }

const Object _commandSurfaceMemorySentinel = Object();

extension BrainDecisionBiasSourceLabels on BrainDecisionBiasSource {
  String get label => switch (this) {
    BrainDecisionBiasSource.replayPolicy => 'Replay policy bias',
  };
}

enum BrainDecisionBiasScope {
  specialistDegradation,
  specialistConflict,
  specialistConstraint,
  sequenceFallback,
}

extension BrainDecisionBiasScopeLabels on BrainDecisionBiasScope {
  String get label => switch (this) {
    BrainDecisionBiasScope.specialistDegradation => 'specialist degradation',
    BrainDecisionBiasScope.specialistConflict => 'specialist conflict',
    BrainDecisionBiasScope.specialistConstraint => 'specialist constraint',
    BrainDecisionBiasScope.sequenceFallback => 'sequence fallback',
  };
}

class BrainDecisionBias {
  final BrainDecisionBiasSource source;
  final BrainDecisionBiasScope scope;
  final OnyxToolTarget preferredTarget;
  final String summary;
  final String baseSeverity;
  final String effectiveSeverity;
  final String policySourceLabel;

  const BrainDecisionBias({
    required this.source,
    required this.scope,
    required this.preferredTarget,
    required this.summary,
    this.baseSeverity = '',
    this.effectiveSeverity = '',
    this.policySourceLabel = '',
  });

  bool get policyPromoted =>
      baseSeverity.trim().toLowerCase() !=
      effectiveSeverity.trim().toLowerCase();

  bool get isPolicyEscalatedSequenceFallback =>
      source == BrainDecisionBiasSource.replayPolicy &&
      scope == BrainDecisionBiasScope.sequenceFallback &&
      policyPromoted;

  String get sourceLabel => source.label;

  String get displayLabel => isPolicyEscalatedSequenceFallback
      ? 'Replay policy escalation'
      : sourceLabel;

  String get scopeLabel => scope.label;

  String get severityPhrase {
    final normalizedBaseSeverity = baseSeverity.trim().toLowerCase();
    final normalizedEffectiveSeverity = effectiveSeverity.trim().toLowerCase();
    if (normalizedEffectiveSeverity.isEmpty) {
      return '';
    }
    if (!policyPromoted || normalizedBaseSeverity.isEmpty) {
      return normalizedEffectiveSeverity;
    }
    return 'promoted $normalizedBaseSeverity -> $normalizedEffectiveSeverity';
  }

  String get displaySummary {
    final normalizedSummary = summary.trim();
    if (normalizedSummary.isEmpty) {
      return displayLabel;
    }
    return '$displayLabel: $normalizedSummary';
  }

  String get railLabel => switch (source) {
    BrainDecisionBiasSource.replayPolicy => 'replay bias',
  };

  String get executionSourceLabel => isPolicyEscalatedSequenceFallback
      ? 'replay policy escalation'
      : 'replay policy bias';

  String get stackSignatureSegment =>
      '${source.name}:${scope.name}:${preferredTarget.name}';

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'source': source.name,
      'scope': scope.name,
      'preferredTarget': preferredTarget.name,
      'summary': summary,
      'baseSeverity': baseSeverity,
      'effectiveSeverity': effectiveSeverity,
      'policySourceLabel': policySourceLabel,
    };
  }

  factory BrainDecisionBias.fromJson(Map<String, Object?> json) {
    return BrainDecisionBias(
      source: _brainDecisionBiasSourceFromName(json['source']),
      scope: _brainDecisionBiasScopeFromName(json['scope']),
      preferredTarget: _toolTargetFromName(json['preferredTarget']),
      summary: (json['summary'] ?? '').toString().trim(),
      baseSeverity: (json['baseSeverity'] ?? '').toString().trim(),
      effectiveSeverity: (json['effectiveSeverity'] ?? '').toString().trim(),
      policySourceLabel: (json['policySourceLabel'] ?? '').toString().trim(),
    );
  }
}

class PlannerDisagreementTelemetry {
  final int conflictCount;
  final int routeClosedConflictCount;
  final Map<OnyxToolTarget, int> modelTargetCounts;
  final Map<OnyxToolTarget, int> typedTargetCounts;
  final String lastConflictSummary;

  const PlannerDisagreementTelemetry({
    this.conflictCount = 0,
    this.routeClosedConflictCount = 0,
    this.modelTargetCounts = const <OnyxToolTarget, int>{},
    this.typedTargetCounts = const <OnyxToolTarget, int>{},
    this.lastConflictSummary = '',
  });

  bool get hasData =>
      conflictCount > 0 ||
      routeClosedConflictCount > 0 ||
      modelTargetCounts.isNotEmpty ||
      typedTargetCounts.isNotEmpty ||
      lastConflictSummary.trim().isNotEmpty;

  OnyxToolTarget? get topModelTarget => _topCountedTarget(modelTargetCounts);

  int get topModelCount =>
      topModelTarget == null ? 0 : modelTargetCounts[topModelTarget] ?? 0;

  OnyxToolTarget? get topTypedTarget => _topCountedTarget(typedTargetCounts);

  int get topTypedCount =>
      topTypedTarget == null ? 0 : typedTargetCounts[topTypedTarget] ?? 0;

  String? get summaryLabel {
    if (!hasData) {
      return null;
    }
    return buildSecondLookTelemetryBannerLabel(
      conflictCount: conflictCount,
      lastConflictSummary: lastConflictSummary,
    );
  }

  List<String> contextHighlights() {
    if (!hasData) {
      return const <String>[];
    }
    final lines = <String>[];
    final trimmedSummary = summaryLabel?.trim() ?? '';
    if (trimmedSummary.isNotEmpty) {
      lines.add('Planner second look: $trimmedSummary');
    }
    if (topModelTarget case final target?) {
      lines.add(
        buildSecondLookPlannerTopModelDriftLabel(
          deskLabel: _deskLabel(target),
          count: topModelCount,
        ),
      );
    }
    if (topTypedTarget case final target?) {
      lines.add(
        buildSecondLookPlannerTopTypedHoldLabel(
          deskLabel: _deskLabel(target),
          count: topTypedCount,
        ),
      );
    }
    if (routeClosedConflictCount > 0) {
      lines.add(
        routeClosedConflictCount == 1
            ? 'Route safety held 1 route closed while second-look pressure disagreed.'
            : 'Route safety held $routeClosedConflictCount routes closed while second-look pressure disagreed.',
      );
    }
    return lines;
  }

  List<String> rationaleHighlights() {
    if (!hasData) {
      return const <String>[];
    }
    final lines = <String>[];
    final trimmedSummary = summaryLabel?.trim() ?? '';
    if (trimmedSummary.isNotEmpty) {
      lines.add('Planner disagreement telemetry: $trimmedSummary');
    }
    final trimmedLastConflictSummary = lastConflictSummary.trim();
    if (trimmedLastConflictSummary.isNotEmpty) {
      lines.add('Last planner disagreement: $trimmedLastConflictSummary');
    }
    if (routeClosedConflictCount > 0) {
      lines.add(
        routeClosedConflictCount == 1
            ? 'Planner safety kept 1 route closed while the second look disagreed.'
            : 'Planner safety kept $routeClosedConflictCount routes closed while the second look disagreed.',
      );
    }
    return lines;
  }

  String? followUpLabel() {
    if (!hasData) {
      return null;
    }
    return 'RECHECK SECOND LOOK';
  }

  String? followUpPrompt({required OnyxToolTarget baselineTarget}) {
    if (!hasData) {
      return null;
    }
    return 'Recheck the planner disagreement before widening beyond ${_deskLabel(baselineTarget)}.';
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'conflictCount': conflictCount,
      'routeClosedConflictCount': routeClosedConflictCount,
      'modelTargetCounts': _toolTargetCountMapToJson(modelTargetCounts),
      'typedTargetCounts': _toolTargetCountMapToJson(typedTargetCounts),
      if (lastConflictSummary.trim().isNotEmpty)
        'lastConflictSummary': lastConflictSummary.trim(),
    };
  }

  factory PlannerDisagreementTelemetry.fromJson(Map<String, Object?> json) {
    return PlannerDisagreementTelemetry(
      conflictCount: _intFromValue(json['conflictCount']),
      routeClosedConflictCount: _intFromValue(json['routeClosedConflictCount']),
      modelTargetCounts: _toolTargetCountMapFromValue(
        json['modelTargetCounts'],
      ),
      typedTargetCounts: _toolTargetCountMapFromValue(
        json['typedTargetCounts'],
      ),
      lastConflictSummary: (json['lastConflictSummary'] ?? '')
          .toString()
          .trim(),
    );
  }
}

String _deskLabel(OnyxToolTarget target) => switch (target) {
  OnyxToolTarget.dispatchBoard => 'Dispatch Board',
  OnyxToolTarget.tacticalTrack => 'Tactical Track',
  OnyxToolTarget.cctvReview => 'CCTV Review',
  OnyxToolTarget.clientComms => 'Client Comms',
  OnyxToolTarget.reportsWorkspace => 'Reports Workspace',
};

class SpecialistAssessment {
  final OnyxSpecialist specialist;
  final String sourceLabel;
  final String summary;
  final OnyxToolTarget? recommendedTarget;
  final double confidence;
  final SpecialistAssessmentPriority priority;
  final List<String> evidence;
  final List<String> missingInfo;
  final bool allowRouteExecution;
  final bool isHardConstraint;

  const SpecialistAssessment({
    required this.specialist,
    required this.summary,
    this.sourceLabel = '',
    this.recommendedTarget,
    this.confidence = 0.0,
    this.priority = SpecialistAssessmentPriority.medium,
    this.evidence = const <String>[],
    this.missingInfo = const <String>[],
    this.allowRouteExecution = true,
    this.isHardConstraint = false,
  });

  SpecialistAssessment copyWith({
    OnyxSpecialist? specialist,
    String? sourceLabel,
    String? summary,
    OnyxToolTarget? recommendedTarget,
    double? confidence,
    SpecialistAssessmentPriority? priority,
    List<String>? evidence,
    List<String>? missingInfo,
    bool? allowRouteExecution,
    bool? isHardConstraint,
  }) {
    return SpecialistAssessment(
      specialist: specialist ?? this.specialist,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      summary: summary ?? this.summary,
      recommendedTarget: recommendedTarget ?? this.recommendedTarget,
      confidence: confidence ?? this.confidence,
      priority: priority ?? this.priority,
      evidence: evidence ?? this.evidence,
      missingInfo: missingInfo ?? this.missingInfo,
      allowRouteExecution: allowRouteExecution ?? this.allowRouteExecution,
      isHardConstraint: isHardConstraint ?? this.isHardConstraint,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'specialist': specialist.name,
      'sourceLabel': sourceLabel,
      'summary': summary,
      if (recommendedTarget != null)
        'recommendedTarget': recommendedTarget!.name,
      'confidence': confidence,
      'priority': priority.name,
      'evidence': evidence,
      'missingInfo': missingInfo,
      'allowRouteExecution': allowRouteExecution,
      'isHardConstraint': isHardConstraint,
    };
  }

  factory SpecialistAssessment.fromJson(Map<String, Object?> json) {
    return SpecialistAssessment(
      specialist: _specialistFromName(json['specialist']),
      sourceLabel: (json['sourceLabel'] ?? '').toString().trim(),
      summary: (json['summary'] ?? '').toString().trim(),
      recommendedTarget: _optionalToolTargetFromName(json['recommendedTarget']),
      confidence: _confidenceFromValue(json['confidence']),
      priority: _priorityFromName(json['priority']),
      evidence: _stringListFromValue(json['evidence']),
      missingInfo: _stringListFromValue(json['missingInfo']),
      allowRouteExecution:
          (json['allowRouteExecution'] ?? true).toString().trim() != 'false',
      isHardConstraint:
          (json['isHardConstraint'] ?? false).toString().trim() == 'true',
    );
  }
}

class BrainDecision {
  final String workItemId;
  final BrainDecisionMode mode;
  final OnyxToolTarget target;
  final String nextMoveLabel;
  final String headline;
  final String detail;
  final String summary;
  final String evidenceHeadline;
  final String evidenceDetail;
  final String advisory;
  final double confidence;
  final String primaryPressure;
  final String rationale;
  final PlannerDisagreementTelemetry? plannerDisagreementTelemetry;
  final List<OnyxSpecialist> supportingSpecialists;
  final List<String> contextHighlights;
  final List<String> missingInfo;
  final String followUpLabel;
  final String followUpPrompt;
  final bool allowRouteExecution;
  final List<SpecialistAssessment> specialistAssessments;
  final BrainDecisionBias? decisionBias;
  final List<BrainDecisionBias> replayBiasStack;

  const BrainDecision({
    required this.workItemId,
    required this.mode,
    required this.target,
    required this.nextMoveLabel,
    required this.headline,
    required this.detail,
    required this.summary,
    required this.evidenceHeadline,
    required this.evidenceDetail,
    this.advisory = '',
    this.confidence = 0.0,
    this.primaryPressure = '',
    this.rationale = '',
    this.plannerDisagreementTelemetry,
    this.supportingSpecialists = const <OnyxSpecialist>[],
    this.contextHighlights = const <String>[],
    this.missingInfo = const <String>[],
    this.followUpLabel = '',
    this.followUpPrompt = '',
    this.allowRouteExecution = true,
    this.specialistAssessments = const <SpecialistAssessment>[],
    this.decisionBias,
    this.replayBiasStack = const <BrainDecisionBias>[],
  });

  BrainDecision copyWith({
    String? workItemId,
    BrainDecisionMode? mode,
    OnyxToolTarget? target,
    String? nextMoveLabel,
    String? headline,
    String? detail,
    String? summary,
    String? evidenceHeadline,
    String? evidenceDetail,
    String? advisory,
    double? confidence,
    String? primaryPressure,
    String? rationale,
    PlannerDisagreementTelemetry? plannerDisagreementTelemetry,
    List<OnyxSpecialist>? supportingSpecialists,
    List<String>? contextHighlights,
    List<String>? missingInfo,
    String? followUpLabel,
    String? followUpPrompt,
    bool? allowRouteExecution,
    List<SpecialistAssessment>? specialistAssessments,
    BrainDecisionBias? decisionBias,
    List<BrainDecisionBias>? replayBiasStack,
  }) {
    return BrainDecision(
      workItemId: workItemId ?? this.workItemId,
      mode: mode ?? this.mode,
      target: target ?? this.target,
      nextMoveLabel: nextMoveLabel ?? this.nextMoveLabel,
      headline: headline ?? this.headline,
      detail: detail ?? this.detail,
      summary: summary ?? this.summary,
      evidenceHeadline: evidenceHeadline ?? this.evidenceHeadline,
      evidenceDetail: evidenceDetail ?? this.evidenceDetail,
      advisory: advisory ?? this.advisory,
      confidence: confidence ?? this.confidence,
      primaryPressure: primaryPressure ?? this.primaryPressure,
      rationale: rationale ?? this.rationale,
      plannerDisagreementTelemetry:
          plannerDisagreementTelemetry ?? this.plannerDisagreementTelemetry,
      supportingSpecialists:
          supportingSpecialists ?? this.supportingSpecialists,
      contextHighlights: contextHighlights ?? this.contextHighlights,
      missingInfo: missingInfo ?? this.missingInfo,
      followUpLabel: followUpLabel ?? this.followUpLabel,
      followUpPrompt: followUpPrompt ?? this.followUpPrompt,
      allowRouteExecution: allowRouteExecution ?? this.allowRouteExecution,
      specialistAssessments:
          specialistAssessments ?? this.specialistAssessments,
      decisionBias: decisionBias ?? this.decisionBias,
      replayBiasStack: replayBiasStack ?? this.replayBiasStack,
    );
  }

  List<BrainDecisionBias> get orderedReplayBiasStack =>
      _mergedReplayBiasStack(decisionBias, replayBiasStack);

  String? get replayBiasStackSignature {
    final orderedBiases = orderedReplayBiasStack;
    if (orderedBiases.isEmpty) {
      return null;
    }
    return orderedBiases.map((bias) => bias.stackSignatureSegment).join(' -> ');
  }

  String? get replayBiasStackSummary {
    final orderedBiases = orderedReplayBiasStack;
    if (orderedBiases.isEmpty) {
      return null;
    }
    return orderedBiases
        .map((bias) => bias.displaySummary)
        .where((summary) => summary.trim().isNotEmpty)
        .join(' Then: ');
  }

  OnyxRecommendation toRecommendation() {
    return OnyxRecommendation(
      workItemId: workItemId,
      target: target,
      nextMoveLabel: nextMoveLabel,
      headline: headline,
      detail: detail,
      summary: summary,
      evidenceHeadline: evidenceHeadline,
      evidenceDetail: evidenceDetail,
      advisory: advisory,
      confidence: confidence,
      missingInfo: missingInfo,
      contextHighlights: contextHighlights,
      followUpLabel: followUpLabel,
      followUpPrompt: followUpPrompt,
      allowRouteExecution: allowRouteExecution,
    );
  }

  OnyxCommandBrainSnapshot toSnapshot() {
    return OnyxCommandBrainSnapshot.fromDecision(this);
  }

  Map<String, Object?> toJson() {
    final orderedBiases = orderedReplayBiasStack;
    return <String, Object?>{
      'workItemId': workItemId,
      'mode': mode.name,
      'target': target.name,
      'nextMoveLabel': nextMoveLabel,
      'headline': headline,
      'detail': detail,
      'summary': summary,
      'evidenceHeadline': evidenceHeadline,
      'evidenceDetail': evidenceDetail,
      'advisory': advisory,
      'confidence': confidence,
      'primaryPressure': primaryPressure,
      'rationale': rationale,
      if (plannerDisagreementTelemetry?.hasData == true)
        'plannerDisagreementTelemetry': plannerDisagreementTelemetry!.toJson(),
      'supportingSpecialists': supportingSpecialists
          .map((specialist) => specialist.name)
          .toList(growable: false),
      'contextHighlights': contextHighlights,
      'missingInfo': missingInfo,
      'followUpLabel': followUpLabel,
      'followUpPrompt': followUpPrompt,
      'allowRouteExecution': allowRouteExecution,
      'specialistAssessments': specialistAssessments
          .map((assessment) => assessment.toJson())
          .toList(growable: false),
      if (decisionBias != null) 'decisionBias': decisionBias!.toJson(),
      if (orderedBiases.isNotEmpty)
        'replayBiasStack': orderedBiases
            .map((bias) => bias.toJson())
            .toList(growable: false),
    };
  }

  factory BrainDecision.fromJson(Map<String, Object?> json) {
    final decisionBias = _optionalBrainDecisionBiasFromValue(
      json['decisionBias'],
    );
    final replayBiasStack = _brainDecisionBiasListFromValue(
      json['replayBiasStack'],
    );
    return BrainDecision(
      workItemId: (json['workItemId'] ?? '').toString().trim(),
      mode: _brainDecisionModeFromName(json['mode']),
      target: _toolTargetFromName(json['target']),
      nextMoveLabel: (json['nextMoveLabel'] ?? '').toString().trim(),
      headline: (json['headline'] ?? '').toString().trim(),
      detail: (json['detail'] ?? '').toString().trim(),
      summary: (json['summary'] ?? '').toString().trim(),
      evidenceHeadline: (json['evidenceHeadline'] ?? '').toString().trim(),
      evidenceDetail: (json['evidenceDetail'] ?? '').toString().trim(),
      advisory: (json['advisory'] ?? '').toString().trim(),
      confidence: _confidenceFromValue(json['confidence']),
      primaryPressure: (json['primaryPressure'] ?? '').toString().trim(),
      rationale: (json['rationale'] ?? '').toString().trim(),
      plannerDisagreementTelemetry:
          _optionalPlannerDisagreementTelemetryFromValue(
            json['plannerDisagreementTelemetry'],
          ),
      supportingSpecialists: _specialistListFromValue(
        json['supportingSpecialists'],
      ),
      contextHighlights: _stringListFromValue(json['contextHighlights']),
      missingInfo: _stringListFromValue(json['missingInfo']),
      followUpLabel: (json['followUpLabel'] ?? '').toString().trim(),
      followUpPrompt: (json['followUpPrompt'] ?? '').toString().trim(),
      allowRouteExecution:
          (json['allowRouteExecution'] ?? true).toString().trim() != 'false',
      specialistAssessments: _assessmentListFromValue(
        json['specialistAssessments'],
      ),
      decisionBias: decisionBias,
      replayBiasStack: _mergedReplayBiasStack(decisionBias, replayBiasStack),
    );
  }
}

class OnyxCommandBrainSnapshot {
  final String workItemId;
  final BrainDecisionMode mode;
  final OnyxToolTarget target;
  final String nextMoveLabel;
  final String headline;
  final String summary;
  final String advisory;
  final double confidence;
  final String primaryPressure;
  final String rationale;
  final PlannerDisagreementTelemetry? plannerDisagreementTelemetry;
  final List<OnyxSpecialist> supportingSpecialists;
  final List<String> contextHighlights;
  final List<String> missingInfo;
  final String followUpLabel;
  final String followUpPrompt;
  final bool allowRouteExecution;
  final List<SpecialistAssessment> specialistAssessments;
  final BrainDecisionBias? decisionBias;
  final List<BrainDecisionBias> replayBiasStack;

  const OnyxCommandBrainSnapshot({
    required this.workItemId,
    required this.mode,
    required this.target,
    required this.nextMoveLabel,
    required this.headline,
    required this.summary,
    this.advisory = '',
    this.confidence = 0.0,
    this.primaryPressure = '',
    this.rationale = '',
    this.plannerDisagreementTelemetry,
    this.supportingSpecialists = const <OnyxSpecialist>[],
    this.contextHighlights = const <String>[],
    this.missingInfo = const <String>[],
    this.followUpLabel = '',
    this.followUpPrompt = '',
    this.allowRouteExecution = true,
    this.specialistAssessments = const <SpecialistAssessment>[],
    this.decisionBias,
    this.replayBiasStack = const <BrainDecisionBias>[],
  });

  factory OnyxCommandBrainSnapshot.fromDecision(BrainDecision decision) {
    return OnyxCommandBrainSnapshot(
      workItemId: decision.workItemId,
      mode: decision.mode,
      target: decision.target,
      nextMoveLabel: decision.nextMoveLabel,
      headline: decision.headline,
      summary: decision.summary,
      advisory: decision.advisory,
      confidence: decision.confidence,
      primaryPressure: decision.primaryPressure,
      rationale: decision.rationale,
      plannerDisagreementTelemetry: decision.plannerDisagreementTelemetry,
      supportingSpecialists: decision.supportingSpecialists,
      contextHighlights: decision.contextHighlights,
      missingInfo: decision.missingInfo,
      followUpLabel: decision.followUpLabel,
      followUpPrompt: decision.followUpPrompt,
      allowRouteExecution: decision.allowRouteExecution,
      specialistAssessments: decision.specialistAssessments,
      decisionBias: decision.decisionBias,
      replayBiasStack: decision.orderedReplayBiasStack,
    );
  }

  factory OnyxCommandBrainSnapshot.fromRecommendation(
    OnyxRecommendation recommendation, {
    BrainDecisionMode mode = BrainDecisionMode.deterministic,
    String primaryPressure = '',
    String rationale = '',
    PlannerDisagreementTelemetry? plannerDisagreementTelemetry,
    List<OnyxSpecialist> supportingSpecialists = const <OnyxSpecialist>[],
    List<SpecialistAssessment> specialistAssessments =
        const <SpecialistAssessment>[],
    BrainDecisionBias? decisionBias,
    List<BrainDecisionBias> replayBiasStack = const <BrainDecisionBias>[],
  }) {
    final orderedReplayBiases = _mergedReplayBiasStack(
      decisionBias,
      replayBiasStack,
    );
    return OnyxCommandBrainSnapshot(
      workItemId: recommendation.workItemId,
      mode: mode,
      target: recommendation.target,
      nextMoveLabel: recommendation.nextMoveLabel,
      headline: recommendation.headline,
      summary: recommendation.summary,
      advisory: recommendation.advisory,
      confidence: recommendation.confidence,
      primaryPressure: primaryPressure,
      rationale: rationale,
      plannerDisagreementTelemetry: plannerDisagreementTelemetry,
      supportingSpecialists: supportingSpecialists,
      contextHighlights: recommendation.contextHighlights,
      missingInfo: recommendation.missingInfo,
      followUpLabel: recommendation.followUpLabel,
      followUpPrompt: recommendation.followUpPrompt,
      allowRouteExecution: recommendation.allowRouteExecution,
      specialistAssessments: specialistAssessments,
      decisionBias: decisionBias,
      replayBiasStack: orderedReplayBiases,
    );
  }

  factory OnyxCommandBrainSnapshot.fromJson(Map<String, Object?> json) {
    final decisionBias = _optionalBrainDecisionBiasFromValue(
      json['decisionBias'],
    );
    final replayBiasStack = _brainDecisionBiasListFromValue(
      json['replayBiasStack'],
    );
    return OnyxCommandBrainSnapshot(
      workItemId: (json['workItemId'] ?? '').toString().trim(),
      mode: _brainDecisionModeFromName(json['mode']),
      target: _toolTargetFromName(json['target']),
      nextMoveLabel: (json['nextMoveLabel'] ?? '').toString().trim(),
      headline: (json['headline'] ?? '').toString().trim(),
      summary: (json['summary'] ?? '').toString().trim(),
      advisory: (json['advisory'] ?? '').toString().trim(),
      confidence: _confidenceFromValue(json['confidence']),
      primaryPressure: (json['primaryPressure'] ?? '').toString().trim(),
      rationale: (json['rationale'] ?? '').toString().trim(),
      plannerDisagreementTelemetry:
          _optionalPlannerDisagreementTelemetryFromValue(
            json['plannerDisagreementTelemetry'],
          ),
      supportingSpecialists: _specialistListFromValue(
        json['supportingSpecialists'],
      ),
      contextHighlights: _stringListFromValue(json['contextHighlights']),
      missingInfo: _stringListFromValue(json['missingInfo']),
      followUpLabel: (json['followUpLabel'] ?? '').toString().trim(),
      followUpPrompt: (json['followUpPrompt'] ?? '').toString().trim(),
      allowRouteExecution:
          (json['allowRouteExecution'] ?? true).toString().trim() != 'false',
      specialistAssessments: _assessmentListFromValue(
        json['specialistAssessments'],
      ),
      decisionBias: decisionBias,
      replayBiasStack: _mergedReplayBiasStack(decisionBias, replayBiasStack),
    );
  }

  List<BrainDecisionBias> get orderedReplayBiasStack =>
      _mergedReplayBiasStack(decisionBias, replayBiasStack);

  BrainDecisionBias? get primaryReplayBias {
    final orderedBiases = orderedReplayBiasStack;
    if (orderedBiases.isEmpty) {
      return null;
    }
    return orderedBiases.first;
  }

  List<OnyxSpecialist> get orderedSpecialists {
    final seen = <OnyxSpecialist>{};
    return <OnyxSpecialist>[
      ...supportingSpecialists,
      ...specialistAssessments.map((assessment) => assessment.specialist),
    ].where((specialist) => seen.add(specialist)).toList(growable: false);
  }

  String get modeLabel => mode.label;

  String get modeRailLabel => mode.railLabel;

  String? get biasSummary => primaryReplayBias?.displaySummary;

  String? get biasRailLabel => primaryReplayBias?.railLabel;

  String? get replayPressureSummary =>
      _buildReplayPressureSummary(orderedReplayBiasStack);

  String? replayContextSummary({
    String rememberedReplayHistorySummary = '',
    bool preferRememberedContinuity = false,
  }) {
    final rememberedReplayContinuityLine = buildRememberedReplayContinuityLine(
      rememberedReplayHistorySummary,
    );
    if (preferRememberedContinuity && rememberedReplayContinuityLine != null) {
      return rememberedReplayContinuityLine;
    }
    final replayPressureSummary = this.replayPressureSummary?.trim() ?? '';
    if (replayPressureSummary.isNotEmpty) {
      return replayPressureSummary;
    }
    final biasSummary = this.biasSummary?.trim() ?? '';
    if (biasSummary.isNotEmpty) {
      return biasSummary;
    }
    return rememberedReplayContinuityLine;
  }

  List<String> commandSurfaceSummaryLines({
    String rememberedReplayHistorySummary = '',
    bool preferRememberedContinuity = false,
  }) {
    return <String>[
      'Command brain: $modeLabel.',
      ?(specialistSummary == null ? null : 'Specialists: $specialistSummary.'),
      ?replayContextSummary(
        rememberedReplayHistorySummary: rememberedReplayHistorySummary,
        preferRememberedContinuity: preferRememberedContinuity,
      ),
    ];
  }

  List<String> commandSurfaceStatusLines({
    String rememberedReplayHistorySummary = '',
    bool preferRememberedContinuity = false,
  }) {
    return <String>[
      'Brain: $modeLabel',
      ?(specialistSummary == null ? null : 'Specialists: $specialistSummary'),
      ?replayContextSummary(
        rememberedReplayHistorySummary: rememberedReplayHistorySummary,
        preferRememberedContinuity: preferRememberedContinuity,
      ),
    ];
  }

  String commandSurfaceSummaryLine({
    String rememberedReplayHistorySummary = '',
    bool preferRememberedContinuity = false,
  }) {
    return commandSurfaceSummaryLines(
      rememberedReplayHistorySummary: rememberedReplayHistorySummary,
      preferRememberedContinuity: preferRememberedContinuity,
    ).join(' ');
  }

  String? get replayBiasStackSummary {
    final orderedBiases = orderedReplayBiasStack;
    if (orderedBiases.isEmpty) {
      return null;
    }
    return orderedBiases
        .map((bias) => bias.displaySummary)
        .where((summary) => summary.trim().isNotEmpty)
        .join(' Then: ');
  }

  String? get replayBiasStackSignature {
    final orderedBiases = orderedReplayBiasStack;
    if (orderedBiases.isEmpty) {
      return null;
    }
    return orderedBiases.map((bias) => bias.stackSignatureSegment).join(' -> ');
  }

  String? get specialistSummary {
    final labels = orderedSpecialists
        .map((specialist) => specialist.label)
        .toList(growable: false);
    if (labels.isEmpty) {
      return null;
    }
    return labels.join(' | ');
  }

  String? get specialistRailLabel {
    final specialists = orderedSpecialists;
    if (specialists.isEmpty) {
      return null;
    }
    if (specialists.length == 1) {
      return specialists.single.label;
    }
    return 'mesh ${specialists.length}';
  }

  OnyxRecommendation toRecommendation() {
    return OnyxRecommendation(
      workItemId: workItemId,
      target: target,
      nextMoveLabel: nextMoveLabel,
      headline: headline,
      detail: '',
      summary: summary,
      evidenceHeadline: '',
      evidenceDetail: '',
      advisory: advisory,
      confidence: confidence,
      missingInfo: missingInfo,
      contextHighlights: contextHighlights,
      followUpLabel: followUpLabel,
      followUpPrompt: followUpPrompt,
      allowRouteExecution: allowRouteExecution,
    );
  }

  Map<String, Object?> toJson() {
    final orderedBiases = orderedReplayBiasStack;
    return <String, Object?>{
      'workItemId': workItemId,
      'mode': mode.name,
      'target': target.name,
      'nextMoveLabel': nextMoveLabel,
      'headline': headline,
      'summary': summary,
      'advisory': advisory,
      'confidence': confidence,
      'primaryPressure': primaryPressure,
      'rationale': rationale,
      if (plannerDisagreementTelemetry?.hasData == true)
        'plannerDisagreementTelemetry': plannerDisagreementTelemetry!.toJson(),
      'supportingSpecialists': supportingSpecialists
          .map((specialist) => specialist.name)
          .toList(growable: false),
      'contextHighlights': contextHighlights,
      'missingInfo': missingInfo,
      'followUpLabel': followUpLabel,
      'followUpPrompt': followUpPrompt,
      'allowRouteExecution': allowRouteExecution,
      'specialistAssessments': specialistAssessments
          .map((assessment) => assessment.toJson())
          .toList(growable: false),
      if (decisionBias != null) 'decisionBias': decisionBias!.toJson(),
      if (orderedBiases.isNotEmpty)
        'replayBiasStack': orderedBiases
            .map((bias) => bias.toJson())
            .toList(growable: false),
    };
  }
}

class OnyxCommandSurfaceMemory {
  final OnyxCommandBrainSnapshot? commandBrainSnapshot;
  final String replayHistorySummary;
  final OnyxCommandSurfacePreview? commandPreview;
  final OnyxCommandSurfaceReceiptMemory? commandReceipt;
  final OnyxCommandSurfaceOutcomeMemory? commandOutcome;

  const OnyxCommandSurfaceMemory({
    this.commandBrainSnapshot,
    this.replayHistorySummary = '',
    this.commandPreview,
    this.commandReceipt,
    this.commandOutcome,
  });

  bool get hasData =>
      commandBrainSnapshot != null ||
      replayHistorySummary.trim().isNotEmpty ||
      commandPreview?.hasData == true ||
      commandReceipt?.hasData == true ||
      commandOutcome?.hasData == true;

  OnyxCommandSurfaceMemory copyWith({
    Object? commandBrainSnapshot = _commandSurfaceMemorySentinel,
    String? replayHistorySummary,
    Object? commandPreview = _commandSurfaceMemorySentinel,
    Object? commandReceipt = _commandSurfaceMemorySentinel,
    Object? commandOutcome = _commandSurfaceMemorySentinel,
  }) {
    return OnyxCommandSurfaceMemory(
      commandBrainSnapshot:
          identical(commandBrainSnapshot, _commandSurfaceMemorySentinel)
          ? this.commandBrainSnapshot
          : commandBrainSnapshot as OnyxCommandBrainSnapshot?,
      replayHistorySummary: replayHistorySummary ?? this.replayHistorySummary,
      commandPreview: identical(commandPreview, _commandSurfaceMemorySentinel)
          ? this.commandPreview
          : commandPreview as OnyxCommandSurfacePreview?,
      commandReceipt: identical(commandReceipt, _commandSurfaceMemorySentinel)
          ? this.commandReceipt
          : commandReceipt as OnyxCommandSurfaceReceiptMemory?,
      commandOutcome: identical(commandOutcome, _commandSurfaceMemorySentinel)
          ? this.commandOutcome
          : commandOutcome as OnyxCommandSurfaceOutcomeMemory?,
    );
  }

  OnyxCommandSurfaceContinuityView continuityView({
    bool preferRememberedContinuity = false,
  }) {
    return OnyxCommandSurfaceContinuityView(
      commandBrainSnapshot: commandBrainSnapshot,
      replayHistorySummary: replayHistorySummary.trim(),
      replayContextLine: replayContextSummary(
        preferRememberedContinuity: preferRememberedContinuity,
      ),
      commandPreview: commandPreview,
      commandReceipt: commandReceipt,
      commandOutcome: commandOutcome,
      target:
          commandReceipt?.target ??
          commandBrainSnapshot?.target ??
          commandPreview?.commandBrainSnapshot?.target,
    );
  }

  String? replayContextSummary({bool preferRememberedContinuity = false}) {
    final snapshot =
        commandBrainSnapshot ?? commandPreview?.commandBrainSnapshot;
    if (snapshot != null) {
      return snapshot.replayContextSummary(
        rememberedReplayHistorySummary: replayHistorySummary,
        preferRememberedContinuity: preferRememberedContinuity,
      );
    }
    return buildRememberedReplayContinuityLine(replayHistorySummary);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (commandBrainSnapshot != null)
        'commandBrainSnapshot': commandBrainSnapshot!.toJson(),
      if (replayHistorySummary.trim().isNotEmpty)
        'replayHistorySummary': replayHistorySummary.trim(),
      if (commandPreview?.hasData == true)
        'commandPreview': commandPreview!.toJson(),
      if (commandReceipt?.hasData == true)
        'commandReceipt': commandReceipt!.toJson(),
      if (commandOutcome?.hasData == true)
        'commandOutcome': commandOutcome!.toJson(),
    };
  }

  factory OnyxCommandSurfaceMemory.fromJson(Map<String, Object?> json) {
    return OnyxCommandSurfaceMemory(
      commandBrainSnapshot: _optionalCommandBrainSnapshotFromValue(
        json['commandBrainSnapshot'],
      ),
      replayHistorySummary: (json['replayHistorySummary'] ?? '')
          .toString()
          .trim(),
      commandPreview: _optionalCommandSurfacePreviewFromValue(
        json['commandPreview'],
      ),
      commandReceipt: _optionalCommandSurfaceReceiptMemoryFromValue(
        json['commandReceipt'],
      ),
      commandOutcome: _optionalCommandSurfaceOutcomeMemoryFromValue(
        json['commandOutcome'],
      ),
    );
  }
}

class OnyxCommandSurfaceReceiptMemory {
  final String label;
  final String headline;
  final String detail;
  final OnyxToolTarget? target;

  const OnyxCommandSurfaceReceiptMemory({
    this.label = '',
    this.headline = '',
    this.detail = '',
    this.target,
  });

  bool get hasData =>
      label.trim().isNotEmpty ||
      headline.trim().isNotEmpty ||
      detail.trim().isNotEmpty ||
      target != null;

  String? continuityLine({
    String prefix = 'Last receipt',
    bool trailingPeriod = true,
  }) {
    final trimmedLabel = label.trim();
    final trimmedHeadline = headline.trim();
    if (trimmedLabel.isEmpty && trimmedHeadline.isEmpty) {
      return null;
    }
    final text = trimmedLabel.isEmpty
        ? trimmedHeadline
        : trimmedHeadline.isEmpty
        ? trimmedLabel
        : '$trimmedLabel - $trimmedHeadline';
    return _commandSurfaceContinuityLine(
      prefix: prefix,
      text: text,
      trailingPeriod: trailingPeriod,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (label.trim().isNotEmpty) 'label': label.trim(),
      if (headline.trim().isNotEmpty) 'headline': headline.trim(),
      if (detail.trim().isNotEmpty) 'detail': detail.trim(),
      if (target != null) 'target': target!.name,
    };
  }

  factory OnyxCommandSurfaceReceiptMemory.fromJson(Map<String, Object?> json) {
    return OnyxCommandSurfaceReceiptMemory(
      label: (json['label'] ?? '').toString().trim(),
      headline: (json['headline'] ?? '').toString().trim(),
      detail: (json['detail'] ?? '').toString().trim(),
      target: _optionalToolTargetFromName(json['target']),
    );
  }
}

class OnyxCommandSurfaceOutcomeMemory {
  final String headline;
  final String label;
  final String summary;

  const OnyxCommandSurfaceOutcomeMemory({
    this.headline = '',
    this.label = '',
    this.summary = '',
  });

  bool get hasData =>
      headline.trim().isNotEmpty ||
      label.trim().isNotEmpty ||
      summary.trim().isNotEmpty;

  String? get preferredSummaryText {
    final trimmedSummary = summary.trim();
    if (trimmedSummary.isNotEmpty) {
      return trimmedSummary;
    }
    final trimmedHeadline = headline.trim();
    return trimmedHeadline.isEmpty ? null : trimmedHeadline;
  }

  String? headlineContinuityLine({
    String prefix = 'Last command outcome',
    bool trailingPeriod = true,
  }) {
    final trimmedHeadline = headline.trim();
    if (trimmedHeadline.isEmpty) {
      return null;
    }
    return _commandSurfaceContinuityLine(
      prefix: prefix,
      text: trimmedHeadline,
      trailingPeriod: trailingPeriod,
    );
  }

  String? summaryContinuityLine({
    String prefix = 'Last command outcome',
    bool trailingPeriod = true,
  }) {
    final text = preferredSummaryText;
    if (text == null) {
      return null;
    }
    return _commandSurfaceContinuityLine(
      prefix: prefix,
      text: text,
      trailingPeriod: trailingPeriod,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (headline.trim().isNotEmpty) 'headline': headline.trim(),
      if (label.trim().isNotEmpty) 'label': label.trim(),
      if (summary.trim().isNotEmpty) 'summary': summary.trim(),
    };
  }

  factory OnyxCommandSurfaceOutcomeMemory.fromJson(Map<String, Object?> json) {
    return OnyxCommandSurfaceOutcomeMemory(
      headline: (json['headline'] ?? '').toString().trim(),
      label: (json['label'] ?? '').toString().trim(),
      summary: (json['summary'] ?? '').toString().trim(),
    );
  }
}

class OnyxCommandSurfaceContinuityView {
  final OnyxCommandBrainSnapshot? commandBrainSnapshot;
  final String replayHistorySummary;
  final String? replayContextLine;
  final OnyxCommandSurfacePreview? commandPreview;
  final OnyxCommandSurfaceReceiptMemory? commandReceipt;
  final OnyxCommandSurfaceOutcomeMemory? commandOutcome;
  final OnyxToolTarget? target;

  const OnyxCommandSurfaceContinuityView({
    this.commandBrainSnapshot,
    this.replayHistorySummary = '',
    this.replayContextLine,
    this.commandPreview,
    this.commandReceipt,
    this.commandOutcome,
    this.target,
  });

  bool get hasData =>
      commandBrainSnapshot != null ||
      replayHistorySummary.trim().isNotEmpty ||
      replayContextLine?.trim().isNotEmpty == true ||
      commandPreview?.hasData == true ||
      commandReceipt?.hasData == true ||
      commandOutcome?.hasData == true ||
      target != null;

  bool get hasPreview => commandPreview?.hasData == true;

  bool get hasReceipt => commandReceipt?.hasData == true;

  List<String> commandBrainSummaryLines() {
    final snapshot = commandBrainSnapshot;
    if (snapshot == null) {
      return const <String>[];
    }
    return <String>[
      'Command brain: ${snapshot.modeLabel}.',
      ?(snapshot.specialistSummary == null
          ? null
          : 'Specialists: ${snapshot.specialistSummary}.'),
      ?replayContextLine,
    ];
  }

  String? commandBrainSummaryLine() {
    final lines = commandBrainSummaryLines();
    if (lines.isEmpty) {
      return null;
    }
    return lines.join(' ');
  }

  List<String> commandBrainStatusLines() {
    final snapshot = commandBrainSnapshot;
    if (snapshot == null) {
      return const <String>[];
    }
    return <String>[
      'Brain: ${snapshot.modeLabel}',
      ?(snapshot.specialistSummary == null
          ? null
          : 'Specialists: ${snapshot.specialistSummary}'),
      ?replayContextLine,
    ];
  }

  List<String> commandBrainDecisionLines({
    String rationale = '',
    List<OnyxSpecialist> supportingSpecialists = const <OnyxSpecialist>[],
  }) {
    final snapshot = commandBrainSnapshot;
    if (snapshot == null) {
      return const <String>[];
    }
    return <String>[
      'Command brain mode: ${snapshot.modeLabel}.',
      ?replayContextLine,
      if (rationale.trim().isNotEmpty) 'Brain rationale: ${rationale.trim()}',
      if (supportingSpecialists.isNotEmpty)
        'Specialist support: ${supportingSpecialists.map((specialist) => specialist.label).join(' | ')}',
    ];
  }

  List<String> threadMemoryBannerLines({
    String? primaryPressureLabel,
    String? lastRecommendedDeskLabel,
    String? lastOpenedDeskLabel,
    Iterable<String> pendingConfirmations = const <String>[],
    String nextFollowUpLabel = '',
    String operatorFocusNote = '',
    String? secondLookTelemetryLabel,
    String advisory = '',
    String? previewSummary,
    String recommendationSummary = '',
  }) {
    final trimmedNextFollowUpLabel = nextFollowUpLabel.trim();
    final trimmedOperatorFocusNote = operatorFocusNote.trim();
    final trimmedSecondLookTelemetryLabel =
        secondLookTelemetryLabel?.trim() ?? '';
    final trimmedAdvisory = advisory.trim();
    final trimmedPreviewSummary = previewSummary?.trim() ?? '';
    final trimmedRecommendationSummary = recommendationSummary.trim();
    final normalizedPendingConfirmations = pendingConfirmations
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return <String>[
      if (primaryPressureLabel != null)
        'Primary pressure: ${primaryPressureLabel.trim()}.',
      ...commandBrainSummaryLines(),
      if (lastRecommendedDeskLabel != null)
        'Last recommendation: ${lastRecommendedDeskLabel.trim()}.',
      if (lastOpenedDeskLabel != null)
        'Last opened desk: ${lastOpenedDeskLabel.trim()}.',
      ?outcomeHeadlineLine(),
      ?receiptLine(),
      if (normalizedPendingConfirmations.isNotEmpty)
        'Still confirm ${normalizedPendingConfirmations.join(', ')}.',
      if (trimmedNextFollowUpLabel.isNotEmpty)
        'Next follow-up: $trimmedNextFollowUpLabel.',
      if (trimmedOperatorFocusNote.isNotEmpty)
        'Operator focus note: $trimmedOperatorFocusNote.',
      if (trimmedSecondLookTelemetryLabel.isNotEmpty)
        trimmedSecondLookTelemetryLabel,
      if (trimmedAdvisory.isNotEmpty)
        trimmedAdvisory
      else if (trimmedPreviewSummary.isNotEmpty)
        trimmedPreviewSummary,
      if (trimmedRecommendationSummary.isNotEmpty) trimmedRecommendationSummary,
    ];
  }

  List<String> threadMemoryRailTokens({
    String? primaryPressureLabel,
    String? lastRecommendedDeskLabel,
    String? lastOpenedDeskLabel,
    String? operatorFocusLabel,
    int pendingConfirmationCount = 0,
    bool hasReadyFollowUp = false,
    String? secondLookTelemetryLabel,
  }) {
    final snapshot = commandBrainSnapshot;
    final trimmedPrimaryPressureLabel = primaryPressureLabel?.trim();
    final trimmedLastRecommendedDeskLabel = lastRecommendedDeskLabel?.trim();
    final trimmedLastOpenedDeskLabel = lastOpenedDeskLabel?.trim();
    final trimmedOperatorFocusLabel = operatorFocusLabel?.trim();
    final trimmedSecondLookTelemetryLabel =
        secondLookTelemetryLabel?.trim() ?? '';
    return <String>[
      if (trimmedPrimaryPressureLabel != null &&
          trimmedPrimaryPressureLabel.isNotEmpty)
        trimmedPrimaryPressureLabel,
      ?snapshot?.modeRailLabel,
      ?snapshot?.specialistRailLabel,
      ?snapshot?.biasRailLabel,
      if (trimmedLastRecommendedDeskLabel != null &&
          trimmedLastRecommendedDeskLabel.isNotEmpty)
        'Rec $trimmedLastRecommendedDeskLabel',
      if (trimmedLastOpenedDeskLabel != null &&
          trimmedLastOpenedDeskLabel.isNotEmpty)
        'Open $trimmedLastOpenedDeskLabel',
      if (trimmedOperatorFocusLabel != null &&
          trimmedOperatorFocusLabel.isNotEmpty)
        trimmedOperatorFocusLabel,
      if (pendingConfirmationCount > 0)
        pendingConfirmationCount == 1
            ? '1 check pending'
            : '$pendingConfirmationCount checks pending',
      if (hasReadyFollowUp) 'follow-up ready',
      if (trimmedSecondLookTelemetryLabel.isNotEmpty)
        trimmedSecondLookTelemetryLabel,
    ];
  }

  List<String> threadMemoryReasoningLines({
    String? primaryPressureLabel,
    String? replayHistorySummary,
    String? lastRecommendedDeskLabel,
    String? lastOpenedDeskLabel,
    Iterable<String> pendingConfirmations = const <String>[],
    String nextFollowUpLabel = '',
    String operatorFocusNote = '',
    String? secondLookTelemetryLine,
    String advisory = '',
    Iterable<String> orderedContextHighlights = const <String>[],
    String recommendationSummary = '',
    String? previewSummary,
  }) {
    final snapshot = commandBrainSnapshot;
    final trimmedPrimaryPressureLabel = primaryPressureLabel?.trim();
    final trimmedReplayHistorySummary = replayHistorySummary?.trim();
    final trimmedLastRecommendedDeskLabel = lastRecommendedDeskLabel?.trim();
    final trimmedLastOpenedDeskLabel = lastOpenedDeskLabel?.trim();
    final trimmedNextFollowUpLabel = nextFollowUpLabel.trim();
    final trimmedOperatorFocusNote = operatorFocusNote.trim();
    final trimmedSecondLookTelemetryLine =
        secondLookTelemetryLine?.trim() ?? '';
    final trimmedAdvisory = advisory.trim();
    final trimmedRecommendationSummary = recommendationSummary.trim();
    final trimmedPreviewSummary = previewSummary?.trim() ?? '';
    final normalizedPendingConfirmations = pendingConfirmations
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final normalizedContextHighlights = orderedContextHighlights
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return <String>[
      if (trimmedPrimaryPressureLabel != null &&
          trimmedPrimaryPressureLabel.isNotEmpty)
        'Thread memory primary pressure: $trimmedPrimaryPressureLabel.',
      if (snapshot != null)
        'Thread memory command brain stayed in ${snapshot.modeLabel}.',
      if (snapshot?.specialistSummary case final summary?)
        'Thread memory specialist picture: $summary.',
      if (replayContextLine case final line?)
        'Thread memory replay context: $line.',
      if (trimmedLastRecommendedDeskLabel != null &&
          trimmedLastRecommendedDeskLabel.isNotEmpty)
        'Thread memory last recommended $trimmedLastRecommendedDeskLabel.',
      if (trimmedLastOpenedDeskLabel != null &&
          trimmedLastOpenedDeskLabel.isNotEmpty)
        'Thread memory last opened $trimmedLastOpenedDeskLabel.',
      ?outcomeSummaryLine(prefix: 'Thread memory last command outcome'),
      ?receiptLine(prefix: 'Thread memory last receipt'),
      if (normalizedPendingConfirmations.isNotEmpty)
        'Thread memory still needs ${normalizedPendingConfirmations.join(', ')}.',
      if (trimmedNextFollowUpLabel.isNotEmpty)
        'Thread memory next follow-up $trimmedNextFollowUpLabel.',
      if (trimmedReplayHistorySummary != null &&
          trimmedReplayHistorySummary.isNotEmpty)
        trimmedReplayHistorySummary,
      if (trimmedOperatorFocusNote.isNotEmpty)
        'Thread memory operator focus: $trimmedOperatorFocusNote.',
      if (trimmedSecondLookTelemetryLine.isNotEmpty)
        trimmedSecondLookTelemetryLine,
      if (trimmedAdvisory.isNotEmpty)
        'Thread memory advisory: $trimmedAdvisory.',
      if (normalizedContextHighlights.isNotEmpty)
        'Thread memory highlights: ${normalizedContextHighlights.join(' | ')}.',
      if (trimmedRecommendationSummary.isNotEmpty)
        'Thread memory summary: $trimmedRecommendationSummary.'
      else if (trimmedPreviewSummary.isNotEmpty)
        'Thread memory preview: $trimmedPreviewSummary.',
    ];
  }

  String get receiptLabel => commandReceipt?.label.trim() ?? '';

  String get receiptHeadline => commandReceipt?.headline.trim() ?? '';

  String get receiptDetail => commandReceipt?.detail.trim() ?? '';

  String? get preferredOutcomeSummaryText =>
      commandOutcome?.preferredSummaryText;

  String? outcomeHeadlineLine({
    String prefix = 'Last command outcome',
    bool trailingPeriod = true,
  }) {
    return commandOutcome?.headlineContinuityLine(
      prefix: prefix,
      trailingPeriod: trailingPeriod,
    );
  }

  String? outcomeSummaryLine({
    String prefix = 'Last command outcome',
    bool trailingPeriod = true,
  }) {
    return commandOutcome?.summaryContinuityLine(
      prefix: prefix,
      trailingPeriod: trailingPeriod,
    );
  }

  String? receiptLine({
    String prefix = 'Last receipt',
    bool trailingPeriod = true,
  }) {
    return commandReceipt?.continuityLine(
      prefix: prefix,
      trailingPeriod: trailingPeriod,
    );
  }
}

class OnyxThreadMemoryFollowUpCue {
  final String headline;
  final String lead;
  final String actionDetail;
  final String personaId;

  const OnyxThreadMemoryFollowUpCue({
    required this.headline,
    required this.lead,
    required this.actionDetail,
    required this.personaId,
  });

  factory OnyxThreadMemoryFollowUpCue.forSurfaceCount(int surfaceCount) {
    if (surfaceCount >= 2) {
      return const OnyxThreadMemoryFollowUpCue(
        headline: 'Escalation follow-up is now overdue',
        lead:
            'This follow-up has reopened multiple times without a confirmed update. Treat it as overdue until the next controller action is explicitly closed out.',
        actionDetail:
            'Escalate this overdue follow-up now or record why it can stay open.',
        personaId: 'escalation',
      );
    }
    if (surfaceCount >= 1) {
      return const OnyxThreadMemoryFollowUpCue(
        headline: 'Follow-up is still unresolved',
        lead:
            'The same follow-up came back again without a confirmed update. Tighten the next step now before this thread drifts further.',
        actionDetail:
            'Resume this unresolved follow-up now or record why it can wait.',
        personaId: 'proactive',
      );
    }
    return const OnyxThreadMemoryFollowUpCue(
      headline: 'Proactive follow-up is still pending',
      lead: 'This thread came back with an unresolved follow-up.',
      actionDetail:
          'Resume the pending operator follow-up from this thread memory checkpoint.',
      personaId: 'proactive',
    );
  }
}

String buildSecondLookTelemetryBannerLabel({
  required int conflictCount,
  String lastConflictSummary = '',
}) {
  final countLabel = conflictCount == 1
      ? '1 second-look disagreement recorded.'
      : '$conflictCount second-look disagreements recorded.';
  final trimmedSummary = lastConflictSummary.trim();
  return trimmedSummary.isEmpty
      ? countLabel
      : '$countLabel Last: $trimmedSummary';
}

String buildSecondLookTelemetryRailLabel({required int conflictCount}) {
  return conflictCount == 1
      ? '1 model conflict'
      : '$conflictCount model conflicts';
}

String buildThreadMemorySecondLookReasoningLine({
  required int conflictCount,
  String lastConflictSummary = '',
}) {
  final trimmedSummary = lastConflictSummary.trim();
  final countLabel = conflictCount == 1
      ? '1 second-look disagreement'
      : '$conflictCount second-look disagreements';
  if (trimmedSummary.isEmpty) {
    return 'Thread memory logged $countLabel.';
  }
  return 'Thread memory logged $countLabel. Last conflict: $trimmedSummary.';
}

String buildSecondLookPlannerSummaryLabel({
  required int totalConflictCount,
  required int impactedThreadCount,
  bool hasTuningSignals = false,
}) {
  if (totalConflictCount <= 0 && hasTuningSignals) {
    return 'No active second-look disagreements right now. The last flagged drift has eased.';
  }
  final threadLabel = impactedThreadCount == 1 ? 'thread' : 'threads';
  final conflictLabel = totalConflictCount == 1
      ? '1 second-look disagreement'
      : '$totalConflictCount second-look disagreements';
  return '$conflictLabel across $impactedThreadCount $threadLabel.';
}

String buildSecondLookPlannerTopModelDriftLabel({
  required String deskLabel,
  required int count,
}) {
  return 'Model drifted most toward ${deskLabel.trim()} ($count).';
}

String buildSecondLookPlannerTopTypedHoldLabel({
  required String deskLabel,
  required int count,
}) {
  return 'Typed planner held ${deskLabel.trim()} most often ($count).';
}

String buildPlannerRouteClosedSummaryLabel({required int count}) {
  return count == 1
      ? 'Safety kept routes closed 1 time.'
      : 'Safety kept routes closed $count times.';
}

String buildPlannerMaintenanceTrackedSummaryLabel({
  required bool fromArchivedWatch,
}) {
  return fromArchivedWatch
      ? 'Chronic drift from archived watch is still tracked'
      : 'Chronic drift is still tracked';
}

String buildPlannerMaintenanceBurnRateSummarySuffix({
  required int reopenedCount,
}) {
  if (reopenedCount <= 0) {
    return '';
  }
  final burnRateLabel = reopenedCount == 1
      ? 'review reopened 1 time'
      : 'review reopened $reopenedCount times';
  return ' Top burn rate: $burnRateLabel.';
}

String buildPlannerUrgentMaintenanceSummarySuffix({
  required bool hasUrgentReview,
}) {
  return hasUrgentReview ? ' Urgent review active.' : '';
}

String buildPlannerMaintenanceConflictSummaryLabel({
  required int activeCount,
  required int completedCount,
  required String severitySummary,
  required bool trackedFromArchivedWatch,
  int topBurnRateReopenedCount = 0,
  bool hasUrgentReview = false,
}) {
  final burnRateSummary = buildPlannerMaintenanceBurnRateSummarySuffix(
    reopenedCount: topBurnRateReopenedCount,
  );
  final urgentReviewSummary = buildPlannerUrgentMaintenanceSummarySuffix(
    hasUrgentReview: hasUrgentReview,
  );
  if (activeCount > 0) {
    final activeSummary = activeCount == 1
        ? '1 planner maintenance alert active.'
        : '$activeCount planner maintenance alerts active.';
    if (completedCount <= 0) {
      return '$activeSummary Highest severity: $severitySummary.$burnRateSummary$urgentReviewSummary';
    }
    final completedSummary = completedCount == 1
        ? '1 review completed.'
        : '$completedCount reviews completed.';
    return '$activeSummary $completedSummary Highest severity: $severitySummary.$burnRateSummary$urgentReviewSummary';
  }
  final trackedSummary = buildPlannerMaintenanceTrackedSummaryLabel(
    fromArchivedWatch: trackedFromArchivedWatch,
  );
  return completedCount == 1
      ? '1 planner maintenance review completed. $trackedSummary.'
      : '$completedCount planner maintenance reviews completed. $trackedSummary.';
}

String buildPlannerReactivationSummaryLabel({
  required int reactivationSignalCount,
  String highestSeverity = '',
}) {
  final trimmedHighestSeverity = highestSeverity.trim();
  final severitySuffix = trimmedHighestSeverity.isEmpty
      ? ''
      : ' Highest severity: $trimmedHighestSeverity.';
  return reactivationSignalCount == 1
      ? '1 archived planner item reactivated after the drift worsened.$severitySuffix'
      : '$reactivationSignalCount archived planner items reactivated after drift worsened.$severitySuffix';
}

String buildPlannerArchivedReviewedSummaryLabel({
  required int archivedReviewedCount,
}) {
  return archivedReviewedCount == 1
      ? '1 reviewed planner item is archived while drift stays flat.'
      : '$archivedReviewedCount reviewed planner items are archived while drift stays flat.';
}

enum OnyxPlannerFocusContext {
  summary,
  modelDriftDetail,
  typedHoldDetail,
  safetyHoldDetail,
  archiveLineageFromMaintenanceAlert,
  driftWatch,
  tuningCue,
  archivedRuleBucket,
  threadRail,
}

String buildPlannerFocusContextLabel(OnyxPlannerFocusContext context) {
  return switch (context) {
    OnyxPlannerFocusContext.summary => 'Focused from planner summary.',
    OnyxPlannerFocusContext.modelDriftDetail => 'Focused model drift detail.',
    OnyxPlannerFocusContext.typedHoldDetail => 'Focused typed hold detail.',
    OnyxPlannerFocusContext.safetyHoldDetail => 'Focused safety hold detail.',
    OnyxPlannerFocusContext.archiveLineageFromMaintenanceAlert =>
      'Focused archive lineage from maintenance alert.',
    OnyxPlannerFocusContext.driftWatch => 'Focused from drift watch.',
    OnyxPlannerFocusContext.tuningCue => 'Focused from planner tuning cue.',
    OnyxPlannerFocusContext.archivedRuleBucket =>
      'Focused archived rule bucket.',
    OnyxPlannerFocusContext.threadRail => 'Focused from the thread rail.',
  };
}

String buildPlannerArchivedBucketSummaryLabel({
  required int archivedReviewedCount,
}) {
  return archivedReviewedCount == 1
      ? '1 reviewed item is archived until the drift worsens again.'
      : '$archivedReviewedCount reviewed items are archived until the drift worsens again.';
}

class OnyxCommandSurfacePreview {
  final String eyebrow;
  final String headline;
  final String label;
  final String summary;
  final OnyxCommandBrainSnapshot? commandBrainSnapshot;

  const OnyxCommandSurfacePreview({
    required this.eyebrow,
    required this.headline,
    required this.label,
    required this.summary,
    this.commandBrainSnapshot,
  });

  bool get hasData =>
      eyebrow.trim().isNotEmpty ||
      headline.trim().isNotEmpty ||
      label.trim().isNotEmpty ||
      summary.trim().isNotEmpty ||
      commandBrainSnapshot != null;

  factory OnyxCommandSurfacePreview.routed(OnyxCommandBrainSnapshot snapshot) {
    final recommendation = snapshot.toRecommendation();
    return OnyxCommandSurfacePreview(
      eyebrow: snapshot.mode == BrainDecisionMode.deterministic
          ? 'ONYX ROUTED'
          : 'ONYX BRAIN',
      headline: recommendation.headline,
      label: recommendation.nextMoveLabel,
      summary: recommendation.summary,
      commandBrainSnapshot: snapshot,
    );
  }

  factory OnyxCommandSurfacePreview.clientDraftStaged() {
    return const OnyxCommandSurfacePreview(
      eyebrow: 'ONYX STAGED',
      headline: 'Client draft is staged in Client Comms',
      label: 'CLIENT DRAFT READY',
      summary: 'Scoped client update is waiting in Client Comms.',
    );
  }

  factory OnyxCommandSurfacePreview.answered({
    required String headline,
    required String label,
    required String summary,
  }) {
    return OnyxCommandSurfacePreview(
      eyebrow: 'ONYX ANSWERED',
      headline: headline,
      label: label,
      summary: summary,
    );
  }

  List<String> commandBrainStatusLines({
    String rememberedReplayHistorySummary = '',
    bool preferRememberedContinuity = false,
  }) {
    final snapshot = commandBrainSnapshot;
    if (snapshot == null) {
      return const <String>[];
    }
    return OnyxCommandSurfaceMemoryAdapter.continuityViewForSnapshot(
      snapshot,
      rememberedReplayHistorySummary: rememberedReplayHistorySummary,
      preferRememberedContinuity: preferRememberedContinuity,
    ).commandBrainStatusLines();
  }

  String detailLine({
    String lastCommand = '',
    required String emptyDetail,
    required String restoredDetail,
  }) {
    if (!hasData) {
      return emptyDetail;
    }
    final trimmedCommand = lastCommand.trim();
    if (trimmedCommand.isNotEmpty) {
      return 'Last command: "$trimmedCommand"';
    }
    return restoredDetail;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (eyebrow.trim().isNotEmpty) 'eyebrow': eyebrow.trim(),
      if (headline.trim().isNotEmpty) 'headline': headline.trim(),
      if (label.trim().isNotEmpty) 'label': label.trim(),
      if (summary.trim().isNotEmpty) 'summary': summary.trim(),
      if (commandBrainSnapshot != null)
        'commandBrainSnapshot': commandBrainSnapshot!.toJson(),
    };
  }

  factory OnyxCommandSurfacePreview.fromJson(Map<String, Object?> json) {
    return OnyxCommandSurfacePreview(
      eyebrow: (json['eyebrow'] ?? '').toString().trim(),
      headline: (json['headline'] ?? '').toString().trim(),
      label: (json['label'] ?? '').toString().trim(),
      summary: (json['summary'] ?? '').toString().trim(),
      commandBrainSnapshot: _optionalCommandBrainSnapshotFromValue(
        json['commandBrainSnapshot'],
      ),
    );
  }
}

class OnyxCommandSurfaceMemoryAdapter {
  const OnyxCommandSurfaceMemoryAdapter._();

  static OnyxCommandSurfaceMemory restore({
    OnyxCommandSurfaceMemory? persistedMemory,
    OnyxCommandBrainSnapshot? legacyCommandBrainSnapshot,
    String legacyReplayHistorySummary = '',
    OnyxCommandSurfaceReceiptMemory? legacyCommandReceipt,
    OnyxCommandSurfaceOutcomeMemory? legacyCommandOutcome,
  }) {
    if (persistedMemory != null && persistedMemory.hasData) {
      return persistedMemory;
    }
    final trimmedReplayHistorySummary = legacyReplayHistorySummary.trim();
    final normalizedLegacyCommandReceipt = legacyCommandReceipt?.hasData == true
        ? legacyCommandReceipt
        : null;
    final normalizedLegacyCommandOutcome = legacyCommandOutcome?.hasData == true
        ? legacyCommandOutcome
        : null;
    if (legacyCommandBrainSnapshot == null &&
        trimmedReplayHistorySummary.isEmpty &&
        normalizedLegacyCommandReceipt == null &&
        normalizedLegacyCommandOutcome == null) {
      return const OnyxCommandSurfaceMemory();
    }
    return OnyxCommandSurfaceMemory(
      commandBrainSnapshot: legacyCommandBrainSnapshot,
      replayHistorySummary: trimmedReplayHistorySummary,
      commandReceipt: normalizedLegacyCommandReceipt,
      commandOutcome: normalizedLegacyCommandOutcome,
    );
  }

  static OnyxCommandSurfaceMemory rememberReplayHistorySummary(
    OnyxCommandSurfaceMemory base,
    String replayHistorySummary,
  ) {
    return base.copyWith(replayHistorySummary: replayHistorySummary.trim());
  }

  static OnyxCommandSurfaceMemory rememberCommandBrainSnapshot(
    OnyxCommandSurfaceMemory base,
    OnyxCommandBrainSnapshot? commandBrainSnapshot, {
    String? replayHistorySummary,
  }) {
    return base.copyWith(
      commandBrainSnapshot: commandBrainSnapshot,
      replayHistorySummary: replayHistorySummary?.trim(),
    );
  }

  static OnyxCommandSurfaceContinuityView continuityViewForSnapshot(
    OnyxCommandBrainSnapshot snapshot, {
    String rememberedReplayHistorySummary = '',
    bool preferRememberedContinuity = false,
  }) {
    return OnyxCommandSurfaceMemory(
      commandBrainSnapshot: snapshot,
      replayHistorySummary: rememberedReplayHistorySummary.trim(),
    ).continuityView(preferRememberedContinuity: preferRememberedContinuity);
  }

  static OnyxCommandSurfaceMemory rememberCommandPreview(
    OnyxCommandSurfaceMemory base,
    OnyxCommandSurfacePreview? commandPreview,
  ) {
    return merge(
      base: base,
      replaceCommandPreview: true,
      commandPreview: commandPreview?.hasData == true ? commandPreview : null,
    );
  }

  static OnyxCommandSurfaceMemory merge({
    required OnyxCommandSurfaceMemory base,
    bool replaceCommandBrainSnapshot = false,
    OnyxCommandBrainSnapshot? commandBrainSnapshot,
    String? replayHistorySummary,
    bool replaceCommandPreview = false,
    OnyxCommandSurfacePreview? commandPreview,
    bool replaceCommandReceipt = false,
    OnyxCommandSurfaceReceiptMemory? commandReceipt,
    bool replaceCommandOutcome = false,
    OnyxCommandSurfaceOutcomeMemory? commandOutcome,
  }) {
    if (!replaceCommandBrainSnapshot &&
        replayHistorySummary == null &&
        !replaceCommandPreview &&
        !replaceCommandReceipt &&
        !replaceCommandOutcome) {
      return base;
    }
    return base.copyWith(
      commandBrainSnapshot: replaceCommandBrainSnapshot
          ? commandBrainSnapshot
          : _commandSurfaceMemorySentinel,
      replayHistorySummary: replayHistorySummary?.trim(),
      commandPreview: replaceCommandPreview
          ? commandPreview
          : _commandSurfaceMemorySentinel,
      commandReceipt: replaceCommandReceipt
          ? commandReceipt
          : _commandSurfaceMemorySentinel,
      commandOutcome: replaceCommandOutcome
          ? commandOutcome
          : _commandSurfaceMemorySentinel,
    );
  }

  static OnyxCommandSurfaceMemory rememberCommandReceipt(
    OnyxCommandSurfaceMemory base,
    OnyxCommandSurfaceReceiptMemory? commandReceipt, {
    bool replaceCommandBrainSnapshot = false,
    OnyxCommandBrainSnapshot? commandBrainSnapshot,
    String? replayHistorySummary,
    OnyxCommandSurfaceOutcomeMemory? commandOutcome,
  }) {
    return merge(
      base: base,
      replaceCommandBrainSnapshot: replaceCommandBrainSnapshot,
      commandBrainSnapshot: commandBrainSnapshot,
      replayHistorySummary: replayHistorySummary,
      replaceCommandReceipt: true,
      commandReceipt: commandReceipt?.hasData == true ? commandReceipt : null,
      replaceCommandOutcome: commandOutcome != null,
      commandOutcome: commandOutcome,
    );
  }

  static OnyxCommandSurfaceMemory rememberCommandOutcome(
    OnyxCommandSurfaceMemory base,
    OnyxCommandSurfaceOutcomeMemory? commandOutcome,
  ) {
    return merge(
      base: base,
      replaceCommandOutcome: true,
      commandOutcome: commandOutcome?.hasData == true ? commandOutcome : null,
    );
  }
}

String _commandSurfaceContinuityLine({
  required String prefix,
  required String text,
  required bool trailingPeriod,
}) {
  final trimmedPrefix = prefix.trim();
  final trimmedText = text.trim();
  if (trimmedText.isEmpty) {
    return '';
  }
  final normalizedText =
      trailingPeriod &&
          !trimmedText.endsWith('.') &&
          !trimmedText.endsWith('!') &&
          !trimmedText.endsWith('?')
      ? '$trimmedText.'
      : trimmedText;
  if (trimmedPrefix.isEmpty) {
    return normalizedText;
  }
  return '$trimmedPrefix: $normalizedText';
}

class OnyxCommandBrainTimelineEntry {
  final int sequence;
  final String stage;
  final String note;
  final OnyxCommandBrainSnapshot snapshot;

  const OnyxCommandBrainTimelineEntry({
    required this.sequence,
    required this.stage,
    required this.snapshot,
    this.note = '',
  });

  factory OnyxCommandBrainTimelineEntry.fromJson(Map<String, Object?> json) {
    return OnyxCommandBrainTimelineEntry(
      sequence: _intFromValue(json['sequence']),
      stage: (json['stage'] ?? '').toString().trim(),
      note: (json['note'] ?? '').toString().trim(),
      snapshot: OnyxCommandBrainSnapshot.fromJson(
        _objectMapFromValue(json['snapshot']),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'sequence': sequence,
      'stage': stage,
      if (note.trim().isNotEmpty) 'note': note,
      'snapshot': snapshot.toJson(),
    };
  }

  String get signatureSegment {
    final orderedReplayBiasStack = snapshot.orderedReplayBiasStack;
    if (orderedReplayBiasStack.length > 1 &&
        snapshot.replayBiasStackSignature != null) {
      return '$stage:${snapshot.target.name}:stack:${snapshot.replayBiasStackSignature!}';
    }
    final decisionBias = snapshot.primaryReplayBias;
    if (decisionBias == null) {
      return '$stage:${snapshot.target.name}';
    }
    return '$stage:${snapshot.target.name}:${decisionBias.source.name}:${decisionBias.scope.name}';
  }
}

OnyxSpecialist _specialistFromName(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  return OnyxSpecialist.values.firstWhere(
    (entry) => entry.name == normalized,
    orElse: () => OnyxSpecialist.policy,
  );
}

BrainDecisionMode _brainDecisionModeFromName(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  return BrainDecisionMode.values.firstWhere(
    (entry) => entry.name == normalized,
    orElse: () => BrainDecisionMode.deterministic,
  );
}

BrainDecisionBiasSource _brainDecisionBiasSourceFromName(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  return BrainDecisionBiasSource.values.firstWhere(
    (entry) => entry.name == normalized,
    orElse: () => BrainDecisionBiasSource.replayPolicy,
  );
}

BrainDecisionBiasScope _brainDecisionBiasScopeFromName(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  return BrainDecisionBiasScope.values.firstWhere(
    (entry) => entry.name == normalized,
    orElse: () => BrainDecisionBiasScope.specialistConflict,
  );
}

SpecialistAssessmentPriority _priorityFromName(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  return SpecialistAssessmentPriority.values.firstWhere(
    (entry) => entry.name == normalized,
    orElse: () => SpecialistAssessmentPriority.medium,
  );
}

OnyxToolTarget _toolTargetFromName(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  return OnyxToolTarget.values.firstWhere(
    (entry) => entry.name == normalized,
    orElse: () => OnyxToolTarget.dispatchBoard,
  );
}

OnyxToolTarget? _optionalToolTargetFromName(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  return OnyxToolTarget.values.firstWhere(
    (entry) => entry.name == normalized,
    orElse: () => OnyxToolTarget.dispatchBoard,
  );
}

double _confidenceFromValue(Object? value) {
  final parsed = switch (value) {
    final num numeric => numeric.toDouble(),
    _ => double.tryParse(value?.toString().trim() ?? ''),
  };
  if (parsed == null) {
    return 0.0;
  }
  if (parsed > 1) {
    return (parsed / 100).clamp(0.0, 1.0);
  }
  return parsed.clamp(0.0, 1.0);
}

int _intFromValue(Object? value) {
  return switch (value) {
    final int integer => integer,
    final num numeric => numeric.toInt(),
    _ => int.tryParse(value?.toString().trim() ?? '') ?? 0,
  };
}

Map<String, Object?> _objectMapFromValue(Object? value) {
  if (value is! Map) {
    return const <String, Object?>{};
  }
  return value.map<String, Object?>(
    (key, entryValue) => MapEntry(key.toString(), entryValue as Object?),
  );
}

BrainDecisionBias? _optionalBrainDecisionBiasFromValue(Object? value) {
  final map = _objectMapFromValue(value);
  if (map.isEmpty) {
    return null;
  }
  return BrainDecisionBias.fromJson(map);
}

PlannerDisagreementTelemetry? _optionalPlannerDisagreementTelemetryFromValue(
  Object? value,
) {
  final map = _objectMapFromValue(value);
  if (map.isEmpty) {
    return null;
  }
  final parsed = PlannerDisagreementTelemetry.fromJson(map);
  return parsed.hasData ? parsed : null;
}

OnyxCommandBrainSnapshot? _optionalCommandBrainSnapshotFromValue(
  Object? value,
) {
  final map = _objectMapFromValue(value);
  if (map.isEmpty) {
    return null;
  }
  return OnyxCommandBrainSnapshot.fromJson(map);
}

OnyxCommandSurfacePreview? _optionalCommandSurfacePreviewFromValue(
  Object? value,
) {
  final map = _objectMapFromValue(value);
  if (map.isEmpty) {
    return null;
  }
  final parsed = OnyxCommandSurfacePreview.fromJson(map);
  return parsed.hasData ? parsed : null;
}

Map<String, Object?> _toolTargetCountMapToJson(
  Map<OnyxToolTarget, int> counts,
) {
  return <String, Object?>{
    for (final entry in counts.entries)
      if (entry.value > 0) entry.key.name: entry.value,
  };
}

OnyxToolTarget? _topCountedTarget(Map<OnyxToolTarget, int> counts) {
  if (counts.isEmpty) {
    return null;
  }
  final sortedEntries = counts.entries.toList(growable: false)
    ..sort((left, right) {
      final byCount = right.value.compareTo(left.value);
      if (byCount != 0) {
        return byCount;
      }
      return left.key.index.compareTo(right.key.index);
    });
  final topEntry = sortedEntries.first;
  if (topEntry.value <= 0) {
    return null;
  }
  return topEntry.key;
}

Map<OnyxToolTarget, int> _toolTargetCountMapFromValue(Object? value) {
  final map = _objectMapFromValue(value);
  if (map.isEmpty) {
    return const <OnyxToolTarget, int>{};
  }
  final counts = <OnyxToolTarget, int>{};
  for (final entry in map.entries) {
    final normalizedTarget = entry.key.toString().trim();
    if (normalizedTarget.isEmpty ||
        !OnyxToolTarget.values.any(
          (candidate) => candidate.name == normalizedTarget,
        )) {
      continue;
    }
    final target = _toolTargetFromName(normalizedTarget);
    final count = _intFromValue(entry.value);
    if (count <= 0) {
      continue;
    }
    counts[target] = count;
  }
  return counts;
}

OnyxCommandSurfaceReceiptMemory? _optionalCommandSurfaceReceiptMemoryFromValue(
  Object? value,
) {
  final map = _objectMapFromValue(value);
  if (map.isEmpty) {
    return null;
  }
  final parsed = OnyxCommandSurfaceReceiptMemory.fromJson(map);
  return parsed.hasData ? parsed : null;
}

extension OnyxRecommendationCommandBodyLines on OnyxRecommendation {
  List<String> commandBodyContextLines({
    String? primaryPressureLine,
    String? operatorFocusLine,
    String? replayContextLine,
    List<String> orderedContextHighlights = const <String>[],
  }) {
    return <String>[
      ?primaryPressureLine,
      ?operatorFocusLine,
      ?replayContextLine,
      if (advisory.trim().isNotEmpty) 'Advisory: ${advisory.trim()}',
      if (orderedContextHighlights.isNotEmpty)
        'Context: ${orderedContextHighlights.join(' | ')}',
    ];
  }

  List<String> commandBodyClosingLines({required String confidenceLabel}) {
    return <String>[
      'Confidence: $confidenceLabel',
      if (missingInfo.isNotEmpty) 'Missing info: ${missingInfo.join(', ')}',
      if (followUpLabel.trim().isNotEmpty)
        'Next follow-up: ${followUpLabel.trim()}',
    ];
  }
}

List<String> buildPlannerCommandSupportLines({
  Iterable<String> backlog = const <String>[],
  Iterable<String> adjustments = const <String>[],
  Iterable<String> maintenance = const <String>[],
  Iterable<String> notes = const <String>[],
}) {
  return <String>[
    ..._prefixedCommandLines('Planner backlog', backlog),
    ..._prefixedCommandLines('Planner adjustment', adjustments),
    ..._prefixedCommandLines('Planner maintenance', maintenance),
    ..._prefixedCommandLines('Planner note', notes),
  ];
}

List<String> _prefixedCommandLines(String prefix, Iterable<String> lines) {
  return lines
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) => '$prefix: $line')
      .toList(growable: false);
}

String buildCommandBodyText(Iterable<String> lines, {String separator = '\n'}) {
  return lines
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .join(separator);
}

String buildCommandBodyFromSections(
  Iterable<Iterable<String>> sections, {
  String lineSeparator = '\n',
  String sectionSeparator = '\n',
}) {
  return sections
      .map((section) => buildCommandBodyText(section, separator: lineSeparator))
      .where((section) => section.isNotEmpty)
      .join(sectionSeparator);
}

OnyxCommandSurfaceOutcomeMemory? _optionalCommandSurfaceOutcomeMemoryFromValue(
  Object? value,
) {
  final map = _objectMapFromValue(value);
  if (map.isEmpty) {
    return null;
  }
  final parsed = OnyxCommandSurfaceOutcomeMemory.fromJson(map);
  return parsed.hasData ? parsed : null;
}

List<BrainDecisionBias> _brainDecisionBiasListFromValue(Object? value) {
  if (value is! List) {
    return const <BrainDecisionBias>[];
  }
  return value
      .map((entry) => _optionalBrainDecisionBiasFromValue(entry))
      .whereType<BrainDecisionBias>()
      .toList(growable: false);
}

List<BrainDecisionBias> _mergedReplayBiasStack(
  BrainDecisionBias? primaryBias,
  List<BrainDecisionBias> replayBiasStack,
) {
  final seen = <String>{};
  final orderedBiases = <BrainDecisionBias>[];
  for (final bias in <BrainDecisionBias>[
    ?primaryBias,
    ...replayBiasStack,
  ]) {
    if (!seen.add(bias.stackSignatureSegment)) {
      continue;
    }
    orderedBiases.add(bias);
  }
  return orderedBiases;
}

String? _buildReplayPressureSummary(List<BrainDecisionBias> replayBiasStack) {
  if (replayBiasStack.isEmpty) {
    return null;
  }
  if (replayBiasStack.length == 1) {
    return replayBiasStack.single.displaySummary;
  }
  final parts = replayBiasStack
      .asMap()
      .entries
      .map((entry) {
        final summary = entry.value.displaySummary.trim();
        if (summary.isEmpty) {
          return '';
        }
        final label = _replayPressureSlotLabel(entry.key);
        if (label == null) {
          return summary;
        }
        return '$label: $summary';
      })
      .where((part) => part.trim().isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return null;
  }
  return parts.join(' ');
}

String? buildRememberedReplayContinuityLine(String replayHistorySummary) {
  final normalizedReplayHistorySummary = replayHistorySummary.trim();
  if (normalizedReplayHistorySummary.isEmpty) {
    return null;
  }
  final firstSentence = normalizedReplayHistorySummary
      .split(RegExp(r'(?<=[.!?])\s+'))
      .first
      .trim();
  final summaryLead = firstSentence.isEmpty
      ? normalizedReplayHistorySummary
      : firstSentence;
  return 'Remembered replay continuity: $summaryLead';
}

String? _replayPressureSlotLabel(int index) {
  switch (index) {
    case 0:
      return 'Primary replay pressure';
    case 1:
      return 'Secondary replay pressure';
    case 2:
      return 'Tertiary replay pressure';
  }
  if (index < 0) {
    return null;
  }
  return 'Replay pressure ${index + 1}';
}

List<String> _stringListFromValue(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((entry) => entry?.toString().trim() ?? '')
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}

List<OnyxSpecialist> _specialistListFromValue(Object? value) {
  if (value is! List) {
    return const <OnyxSpecialist>[];
  }
  return value.map(_specialistFromName).toList(growable: false);
}

List<SpecialistAssessment> _assessmentListFromValue(Object? value) {
  if (value is! List) {
    return const <SpecialistAssessment>[];
  }
  return value
      .whereType<Map>()
      .map(
        (entry) => SpecialistAssessment.fromJson(
          entry.map((key, item) => MapEntry(key.toString(), item as Object?)),
        ),
      )
      .toList(growable: false);
}
