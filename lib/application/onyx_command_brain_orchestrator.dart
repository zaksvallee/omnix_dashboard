import '../domain/authority/onyx_command_brain_contract.dart';
import '../domain/authority/onyx_task_protocol.dart';
import 'onyx_agent_cloud_boost_service.dart';
import 'onyx_operator_orchestrator.dart';

class OnyxCommandBrainOrchestrator {
  const OnyxCommandBrainOrchestrator({
    this.operatorOrchestrator = const OnyxOperatorOrchestrator(),
  });

  final OnyxOperatorOrchestrator operatorOrchestrator;

  BrainDecision decide({
    required OnyxWorkItem item,
    OnyxAgentBrainAdvisory? advisory,
    BrainDecisionBias? decisionBias,
    List<BrainDecisionBias> replayBiasStack = const <BrainDecisionBias>[],
    List<SpecialistAssessment> specialistAssessments =
        const <SpecialistAssessment>[],
    PlannerDisagreementTelemetry? plannerDisagreementTelemetry,
  }) {
    final deterministic = operatorOrchestrator.recommend(item);
    final orderedAssessments = specialistAssessments.toList(growable: false)
      ..sort(_compareAssessments);
    final orderedReplayBiases = _orderedReplayBiases(
      primaryBias: decisionBias,
      replayBiasStack: replayBiasStack,
    );
    final primaryReplayBias = orderedReplayBiases.isEmpty
        ? null
        : orderedReplayBiases.first;
    final secondaryReplayBiases = orderedReplayBiases.length <= 1
        ? const <BrainDecisionBias>[]
        : orderedReplayBiases.sublist(1);
    final secondaryReplayPressureSummary = _secondaryReplayPressureSummary(
      secondaryReplayBiases,
    );
    final plannerDisagreementContextHighlights =
        plannerDisagreementTelemetry?.contextHighlights() ?? const <String>[];
    final plannerDisagreementRationaleHighlights =
        plannerDisagreementTelemetry?.rationaleHighlights() ?? const <String>[];
    final plannerDisagreementFollowUpLabel =
        plannerDisagreementTelemetry?.followUpLabel() ?? '';
    final plannerDisagreementFollowUpPrompt =
        plannerDisagreementTelemetry?.followUpPrompt(
          baselineTarget: deterministic.target,
        ) ??
        '';

    var target = deterministic.target;
    var mode = BrainDecisionMode.deterministic;
    var allowRouteExecution = deterministic.allowRouteExecution;
    var advisoryText = deterministic.advisory.trim();
    var confidence = deterministic.confidence.clamp(0.0, 1.0);
    BrainDecisionBias? appliedBias;
    final supportingSpecialists = <OnyxSpecialist>[];
    final rationaleParts = <String>[
      'Deterministic triage selected ${_deskLabel(deterministic.target)} first.',
    ];

    final specialistConstraint = orderedAssessments.firstWhere(
      (assessment) =>
          assessment.isHardConstraint && assessment.recommendedTarget != null,
      orElse: () => const SpecialistAssessment(
        specialist: OnyxSpecialist.policy,
        summary: '',
      ),
    );
    if (specialistConstraint.summary.trim().isNotEmpty &&
        specialistConstraint.recommendedTarget != null) {
      target = specialistConstraint.recommendedTarget!;
      mode = BrainDecisionMode.specialistConstraint;
      allowRouteExecution =
          allowRouteExecution && specialistConstraint.allowRouteExecution;
      supportingSpecialists.add(specialistConstraint.specialist);
      confidence = _mergedConfidence(
        confidence,
        specialistConstraint.confidence,
      );
      if (advisoryText.isEmpty) {
        advisoryText = specialistConstraint.summary.trim();
      }
      rationaleParts.add(
        '${specialistConstraint.specialist.label} raised a hard constraint and redirected the move to ${_deskLabel(target)}.',
      );
      rationaleParts.add(specialistConstraint.summary.trim());
    } else {
      final corroboratedAssessments = _corroboratingAssessments(
        orderedAssessments,
        advisory,
      );
      if (advisory?.recommendedTarget != null &&
          advisory!.recommendedTarget != deterministic.target &&
          corroboratedAssessments.isNotEmpty) {
        target = advisory.recommendedTarget!;
        mode = BrainDecisionMode.corroboratedSynthesis;
        allowRouteExecution =
            allowRouteExecution &&
            corroboratedAssessments.every(
              (assessment) => assessment.allowRouteExecution,
            );
        supportingSpecialists.addAll(
          corroboratedAssessments
              .map((assessment) => assessment.specialist)
              .toSet(),
        );
        confidence = _mergedConfidence(
          confidence,
          advisory.confidence,
          corroboratedAssessments.first.confidence,
        );
        if (advisory.summary.trim().isNotEmpty) {
          advisoryText = advisory.summary.trim();
        }
        rationaleParts.add(
          'Brain synthesis and ${_specialistLabelList(corroboratedAssessments)} aligned on ${_deskLabel(target)}.',
        );
        if (advisory.why.trim().isNotEmpty) {
          rationaleParts.add(advisory.why.trim());
        }
      } else if (primaryReplayBias != null) {
        target = primaryReplayBias.preferredTarget;
        appliedBias = primaryReplayBias;
        confidence = _replayBiasConfidenceFloor(confidence);
        if (primaryReplayBias.summary.trim().isNotEmpty) {
          advisoryText = primaryReplayBias.summary.trim();
        }
        rationaleParts.add(
          '${primaryReplayBias.displayLabel} kept ${_deskLabel(target)} in front while ${primaryReplayBias.scopeLabel} stayed active.',
        );
        if (secondaryReplayPressureSummary != null) {
          rationaleParts.add(
            'Secondary replay pressure remains on $secondaryReplayPressureSummary.',
          );
        }
      }
    }
    if (plannerDisagreementRationaleHighlights.isNotEmpty) {
      rationaleParts.addAll(plannerDisagreementRationaleHighlights);
    }

    final primaryPressure = advisory?.primaryPressure.trim() ?? '';
    final contextHighlights = _mergeUniqueStrings(<String>[
      ...deterministic.contextHighlights,
      ...?advisory?.contextHighlights,
      ...orderedAssessments.expand((assessment) => assessment.evidence),
      ...plannerDisagreementContextHighlights,
      if (secondaryReplayPressureSummary != null)
        'Secondary replay pressure: $secondaryReplayPressureSummary',
    ]);
    final missingInfo = _mergeUniqueStrings(<String>[
      ...deterministic.missingInfo,
      ...?advisory?.missingInfo,
      ...orderedAssessments.expand((assessment) => assessment.missingInfo),
    ]);
    final followUpLabel = deterministic.followUpLabel.trim().isNotEmpty
        ? deterministic.followUpLabel.trim()
        : advisory?.followUpLabel.trim().isNotEmpty == true
        ? advisory!.followUpLabel.trim()
        : plannerDisagreementFollowUpLabel;
    final followUpPrompt = deterministic.followUpPrompt.trim().isNotEmpty
        ? deterministic.followUpPrompt.trim()
        : advisory?.followUpPrompt.trim().isNotEmpty == true
        ? advisory!.followUpPrompt.trim()
        : plannerDisagreementFollowUpPrompt;
    final rationale = rationaleParts
        .where((part) => part.trim().isNotEmpty)
        .join(' ');

    if (mode == BrainDecisionMode.deterministic &&
        target == deterministic.target &&
        appliedBias == null) {
      return BrainDecision(
        workItemId: deterministic.workItemId,
        mode: mode,
        target: target,
        nextMoveLabel: deterministic.nextMoveLabel,
        headline: deterministic.headline,
        detail: deterministic.detail,
        summary: deterministic.summary,
        evidenceHeadline: deterministic.evidenceHeadline,
        evidenceDetail: deterministic.evidenceDetail,
        advisory: deterministic.advisory,
        confidence: deterministic.confidence,
        primaryPressure: primaryPressure,
        rationale: rationale,
        plannerDisagreementTelemetry: plannerDisagreementTelemetry,
        supportingSpecialists: supportingSpecialists,
        contextHighlights: contextHighlights,
        missingInfo: missingInfo,
        followUpLabel: followUpLabel,
        followUpPrompt: followUpPrompt,
        allowRouteExecution: deterministic.allowRouteExecution,
        specialistAssessments: orderedAssessments,
        decisionBias: null,
        replayBiasStack: orderedReplayBiases,
      );
    }

    final composed =
        mode == BrainDecisionMode.deterministic && appliedBias != null
        ? _composeReplayBiasedDecision(
            item: item,
            deterministic: deterministic,
            bias: appliedBias,
            rationale: rationale,
            confidence: confidence,
            primaryPressure: primaryPressure,
            contextHighlights: contextHighlights,
            missingInfo: missingInfo,
            specialistAssessments: orderedAssessments,
            secondaryReplayPressureSummary: secondaryReplayPressureSummary,
            replayBiasStack: orderedReplayBiases,
            plannerDisagreementTelemetry: plannerDisagreementTelemetry,
          )
        : _composeRetargetedDecision(
            item: item,
            target: target,
            mode: mode,
            rationale: rationale,
            advisoryText: advisoryText,
            confidence: confidence,
            primaryPressure: primaryPressure,
            contextHighlights: contextHighlights,
            missingInfo: missingInfo,
            followUpLabel: followUpLabel,
            followUpPrompt: followUpPrompt,
            allowRouteExecution: allowRouteExecution,
            supportingSpecialists: supportingSpecialists,
            specialistAssessments: orderedAssessments,
            decisionBias: appliedBias,
            replayBiasStack: orderedReplayBiases,
            plannerDisagreementTelemetry: plannerDisagreementTelemetry,
          );
    return composed;
  }

  List<SpecialistAssessment> _corroboratingAssessments(
    List<SpecialistAssessment> assessments,
    OnyxAgentBrainAdvisory? advisory,
  ) {
    final recommendedTarget = advisory?.recommendedTarget;
    if (recommendedTarget == null) {
      return const <SpecialistAssessment>[];
    }
    return assessments
        .where(
          (assessment) => assessment.recommendedTarget == recommendedTarget,
        )
        .toList(growable: false);
  }

  BrainDecision _composeRetargetedDecision({
    required OnyxWorkItem item,
    required OnyxToolTarget target,
    required BrainDecisionMode mode,
    required String rationale,
    required String advisoryText,
    required double confidence,
    required String primaryPressure,
    required List<String> contextHighlights,
    required List<String> missingInfo,
    required String followUpLabel,
    required String followUpPrompt,
    required bool allowRouteExecution,
    required List<OnyxSpecialist> supportingSpecialists,
    required List<SpecialistAssessment> specialistAssessments,
    BrainDecisionBias? decisionBias,
    List<BrainDecisionBias> replayBiasStack = const <BrainDecisionBias>[],
    PlannerDisagreementTelemetry? plannerDisagreementTelemetry,
  }) {
    final deskLabel = _deskLabel(target);
    final incidentReference = item.incidentReference.trim().isEmpty
        ? 'the active incident'
        : item.incidentReference.trim();
    final summary = switch (mode) {
      BrainDecisionMode.deterministic =>
        'One next move is staged in $deskLabel.',
      BrainDecisionMode.corroboratedSynthesis =>
        'ONYX command brain staged a corroborated move in $deskLabel.',
      BrainDecisionMode.specialistConstraint =>
        'ONYX command brain staged a constrained move in $deskLabel.',
    };
    final detail = switch (target) {
      OnyxToolTarget.clientComms =>
        'Work $incidentReference inside $deskLabel for ${item.scopeLabel}. $rationale Keep the client lane factual, calm, and tightly scoped to verified context.',
      OnyxToolTarget.reportsWorkspace =>
        'Work $incidentReference inside $deskLabel for ${item.scopeLabel}. $rationale Preserve the reporting posture and avoid implying any new live action before the record is settled.',
      OnyxToolTarget.cctvReview =>
        'Work $incidentReference inside $deskLabel for ${item.scopeLabel}. $rationale Confirm the scene visually before widening the next controller move.',
      OnyxToolTarget.tacticalTrack =>
        'Work $incidentReference inside $deskLabel for ${item.scopeLabel}. $rationale Hold field continuity, responder posture, and site prioritization in one place.',
      OnyxToolTarget.dispatchBoard =>
        'Work $incidentReference inside $deskLabel for ${item.scopeLabel}. $rationale Keep dispatch ownership, timing, and escalation discipline tight on the controller board.',
    };
    final evidenceDetail = switch (mode) {
      BrainDecisionMode.deterministic =>
        'ONYX command brain preserved the deterministic triage path before reopening $deskLabel.',
      BrainDecisionMode.corroboratedSynthesis =>
        'ONYX command brain fused deterministic triage, corroborating specialist evidence, and synthesis before reopening $deskLabel.',
      BrainDecisionMode.specialistConstraint =>
        'ONYX command brain accepted a hard specialist constraint and held the decision inside $deskLabel with deterministic safety rails still applied.',
    };
    return BrainDecision(
      workItemId: item.id,
      mode: mode,
      target: target,
      nextMoveLabel: _nextMoveLabel(target),
      headline: '$deskLabel is the next move',
      detail: detail,
      summary: summary,
      evidenceHeadline: '$deskLabel handoff sealed.',
      evidenceDetail: evidenceDetail,
      advisory: advisoryText,
      confidence: confidence.clamp(0.0, 1.0),
      primaryPressure: primaryPressure,
      rationale: rationale,
      supportingSpecialists: supportingSpecialists,
      contextHighlights: contextHighlights,
      missingInfo: missingInfo,
      followUpLabel: followUpLabel,
      followUpPrompt: followUpPrompt,
      allowRouteExecution: allowRouteExecution,
      specialistAssessments: specialistAssessments,
      decisionBias: decisionBias,
      replayBiasStack: replayBiasStack,
      plannerDisagreementTelemetry: plannerDisagreementTelemetry,
    );
  }

  BrainDecision _composeReplayBiasedDecision({
    required OnyxWorkItem item,
    required OnyxRecommendation deterministic,
    required BrainDecisionBias bias,
    required String rationale,
    required double confidence,
    required String primaryPressure,
    required List<String> contextHighlights,
    required List<String> missingInfo,
    required List<SpecialistAssessment> specialistAssessments,
    String? secondaryReplayPressureSummary,
    List<BrainDecisionBias> replayBiasStack = const <BrainDecisionBias>[],
    PlannerDisagreementTelemetry? plannerDisagreementTelemetry,
  }) {
    final target = bias.preferredTarget;
    final prioritizedDesk = _deskLabel(target);
    final baselineDesk = _deskLabel(deterministic.target);
    final incidentReference = item.incidentReference.trim().isEmpty
        ? 'the active incident'
        : item.incidentReference.trim();
    final policyEscalatedSequenceFallback =
        bias.isPolicyEscalatedSequenceFallback;
    final followUpLabel = switch (bias.scope) {
      BrainDecisionBiasScope.specialistConstraint => 'CLEAR HARD CONSTRAINT',
      BrainDecisionBiasScope.specialistConflict =>
        'RESOLVE SPECIALIST CONFLICT',
      BrainDecisionBiasScope.specialistDegradation =>
        'RESTORE SPECIALIST SIGNAL',
      BrainDecisionBiasScope.sequenceFallback => '',
    };
    final followUpPrompt = switch (bias.scope) {
      BrainDecisionBiasScope.specialistConstraint =>
        'Clear the replay hard specialist constraint for $incidentReference before resuming $baselineDesk.',
      BrainDecisionBiasScope.specialistConflict =>
        'Resolve the replay specialist conflict for $incidentReference before widening beyond $prioritizedDesk.',
      BrainDecisionBiasScope.specialistDegradation =>
        'Restore the replay specialist signal for $incidentReference before widening beyond $baselineDesk.',
      BrainDecisionBiasScope.sequenceFallback => '',
    };
    final detailLead = switch (bias.scope) {
      BrainDecisionBiasScope.specialistConstraint =>
        'Replay history is still showing a blocking specialist constraint.',
      BrainDecisionBiasScope.specialistConflict =>
        'Replay history is still showing unresolved specialist conflict.',
      BrainDecisionBiasScope.specialistDegradation =>
        'Replay history is still showing unresolved specialist degradation.',
      BrainDecisionBiasScope.sequenceFallback =>
        policyEscalatedSequenceFallback
            ? 'Replay policy escalation is still holding the safer sequence fallback.'
            : 'Replay policy is still holding the safer sequence fallback.',
    };
    final detail =
        bias.scope == BrainDecisionBiasScope.sequenceFallback &&
            policyEscalatedSequenceFallback
        ? '$detailLead Open $prioritizedDesk first and satisfy the replay policy escalation before widening back to $baselineDesk.'
        : '$detailLead Open $prioritizedDesk first and clear the replay risk before widening back to $baselineDesk.';
    final summary =
        bias.scope == BrainDecisionBiasScope.sequenceFallback &&
            policyEscalatedSequenceFallback
        ? 'Replay policy escalation keeps $prioritizedDesk in front while ${bias.scopeLabel} stays active.'
        : 'Replay priority keeps $prioritizedDesk in front while ${bias.scopeLabel} stays active.';
    final evidenceDetail = switch (bias.scope) {
      BrainDecisionBiasScope.sequenceFallback =>
        policyEscalatedSequenceFallback
            ? 'ONYX routed you into $prioritizedDesk to honor the replay policy escalation before widening $incidentReference back toward $baselineDesk.'
            : 'ONYX routed you into $prioritizedDesk to clear ${bias.scopeLabel} pressure for $incidentReference.',
      _ =>
        'ONYX routed you into $prioritizedDesk to clear ${bias.scopeLabel} pressure for $incidentReference.',
    };
    final advisoryText = secondaryReplayPressureSummary == null
        ? bias.summary.trim()
        : '${bias.summary.trim()} Secondary replay pressure: $secondaryReplayPressureSummary.';
    return BrainDecision(
      workItemId: item.id,
      mode: BrainDecisionMode.deterministic,
      target: target,
      nextMoveLabel: _nextMoveLabel(target),
      headline:
          bias.scope == BrainDecisionBiasScope.sequenceFallback &&
              policyEscalatedSequenceFallback
          ? '$prioritizedDesk is the replay escalation desk'
          : '$prioritizedDesk is the replay recovery desk',
      detail: detail,
      summary: summary,
      evidenceHeadline: '$prioritizedDesk handoff sealed.',
      evidenceDetail: evidenceDetail,
      advisory: advisoryText,
      confidence: confidence.clamp(0.0, 1.0),
      primaryPressure: primaryPressure,
      rationale: rationale,
      supportingSpecialists: const <OnyxSpecialist>[],
      contextHighlights: _mergeUniqueStrings(<String>[
        ...contextHighlights,
        bias.summary,
        if (secondaryReplayPressureSummary != null)
          'Secondary replay pressure: $secondaryReplayPressureSummary',
      ]),
      missingInfo: missingInfo,
      followUpLabel: followUpLabel,
      followUpPrompt: followUpPrompt,
      allowRouteExecution: true,
      specialistAssessments: specialistAssessments,
      decisionBias: bias,
      replayBiasStack: replayBiasStack,
      plannerDisagreementTelemetry: plannerDisagreementTelemetry,
    );
  }

  List<BrainDecisionBias> _orderedReplayBiases({
    BrainDecisionBias? primaryBias,
    required List<BrainDecisionBias> replayBiasStack,
  }) {
    final ordered = <BrainDecisionBias>[
      ?primaryBias,
      ...replayBiasStack,
    ];
    final seen = <String>{};
    final deduplicated = <BrainDecisionBias>[];
    for (final bias in ordered) {
      final signature = _replayBiasSignature(bias);
      if (!seen.add(signature)) {
        continue;
      }
      deduplicated.add(bias);
    }
    return deduplicated;
  }

  String? _secondaryReplayPressureSummary(List<BrainDecisionBias> biases) {
    if (biases.isEmpty) {
      return null;
    }
    final summaries = biases
        .map((bias) {
          final normalizedSummary = bias.summary.trim();
          if (normalizedSummary.isNotEmpty) {
            return normalizedSummary;
          }
          return '${bias.displayLabel} kept ${_deskLabel(bias.preferredTarget)} in front while ${bias.scopeLabel} stayed active.';
        })
        .where((summary) => summary.trim().isNotEmpty)
        .toList(growable: false);
    if (summaries.isEmpty) {
      return null;
    }
    return summaries.join(' Then: ');
  }

  String _replayBiasSignature(BrainDecisionBias bias) {
    return [
      bias.source.name,
      bias.scope.name,
      bias.preferredTarget.name,
      bias.summary.trim().toLowerCase(),
    ].join(':');
  }

  int _compareAssessments(
    SpecialistAssessment left,
    SpecialistAssessment right,
  ) {
    final hardConstraintCompare = (right.isHardConstraint ? 1 : 0).compareTo(
      left.isHardConstraint ? 1 : 0,
    );
    if (hardConstraintCompare != 0) {
      return hardConstraintCompare;
    }
    final priorityCompare = _priorityWeight(
      right.priority,
    ).compareTo(_priorityWeight(left.priority));
    if (priorityCompare != 0) {
      return priorityCompare;
    }
    return right.confidence.compareTo(left.confidence);
  }
}

double _replayBiasConfidenceFloor(double base) => base < 0.74 ? 0.74 : base;

int _priorityWeight(SpecialistAssessmentPriority priority) =>
    switch (priority) {
      SpecialistAssessmentPriority.low => 0,
      SpecialistAssessmentPriority.medium => 1,
      SpecialistAssessmentPriority.high => 2,
      SpecialistAssessmentPriority.critical => 3,
    };

double _mergedConfidence(double base, [double? left, double? right]) {
  final values = <double>[
    base,
    ?left,
    ?right,
  ].map((entry) => entry.clamp(0.0, 1.0)).toList(growable: false);
  if (values.isEmpty) {
    return 0.0;
  }
  final total = values.reduce((sum, entry) => sum + entry);
  return (total / values.length).clamp(0.0, 1.0);
}

List<String> _mergeUniqueStrings(List<String> input) {
  final seen = <String>{};
  final output = <String>[];
  for (final entry in input) {
    final trimmed = entry.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final normalized = trimmed.toLowerCase();
    if (!seen.add(normalized)) {
      continue;
    }
    output.add(trimmed);
  }
  return List<String>.unmodifiable(output);
}

String _specialistLabelList(List<SpecialistAssessment> assessments) {
  final labels = assessments
      .map((assessment) => assessment.specialist.label)
      .toSet()
      .toList(growable: false);
  if (labels.length == 1) {
    return labels.single;
  }
  if (labels.length == 2) {
    return '${labels.first} and ${labels.last}';
  }
  final leading = labels.take(labels.length - 1).join(', ');
  return '$leading, and ${labels.last}';
}

String _deskLabel(OnyxToolTarget target) => switch (target) {
  OnyxToolTarget.dispatchBoard => 'Dispatch Board',
  OnyxToolTarget.tacticalTrack => 'Tactical Track',
  OnyxToolTarget.cctvReview => 'CCTV Review',
  OnyxToolTarget.clientComms => 'Client Comms',
  OnyxToolTarget.reportsWorkspace => 'Reports Workspace',
};

String _nextMoveLabel(OnyxToolTarget target) => switch (target) {
  OnyxToolTarget.dispatchBoard => 'OPEN DISPATCH BOARD',
  OnyxToolTarget.tacticalTrack => 'OPEN TACTICAL TRACK',
  OnyxToolTarget.cctvReview => 'OPEN CCTV REVIEW',
  OnyxToolTarget.clientComms => 'OPEN CLIENT COMMS',
  OnyxToolTarget.reportsWorkspace => 'OPEN REPORTS WORKSPACE',
};
