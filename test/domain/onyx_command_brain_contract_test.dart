import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/authority/onyx_command_brain_contract.dart';
import 'package:omnix_dashboard/domain/authority/onyx_task_protocol.dart';

void main() {
  test('BrainDecision contract round-trips through json and recommendation', () {
    final decision = BrainDecision(
      workItemId: 'brain-work-1',
      mode: BrainDecisionMode.corroboratedSynthesis,
      target: OnyxToolTarget.cctvReview,
      nextMoveLabel: 'OPEN CCTV REVIEW',
      headline: 'CCTV Review is the next move',
      detail: 'Confirm the scene visually before widening the controller move.',
      summary: 'ONYX command brain staged a corroborated move in CCTV Review.',
      evidenceHeadline: 'CCTV Review handoff sealed.',
      evidenceDetail:
          'ONYX fused deterministic triage and corroborating specialist evidence.',
      advisory: 'Visual confirmation still outranks field continuity.',
      confidence: 0.86,
      primaryPressure: 'active signal watch',
      rationale:
          'Deterministic triage selected Tactical Track first. Brain synthesis and CCTV specialist aligned on CCTV Review.',
      plannerDisagreementTelemetry: const PlannerDisagreementTelemetry(
        conflictCount: 2,
        routeClosedConflictCount: 1,
        modelTargetCounts: <OnyxToolTarget, int>{OnyxToolTarget.cctvReview: 2},
        typedTargetCounts: <OnyxToolTarget, int>{
          OnyxToolTarget.tacticalTrack: 1,
        },
        lastConflictSummary:
            'kept Tactical Track over CCTV Review while the route stayed closed.',
      ),
      supportingSpecialists: const <OnyxSpecialist>[OnyxSpecialist.cctv],
      contextHighlights: const <String>[
        'Fresh clip confirmation is still pending',
      ],
      missingInfo: const <String>['fresh clip confirmation'],
      followUpLabel: 'RECHECK CCTV CONFIRMATION',
      followUpPrompt:
          'Recheck the fresh clip confirmation before widening the response.',
      allowRouteExecution: true,
      decisionBias: const BrainDecisionBias(
        source: BrainDecisionBiasSource.replayPolicy,
        scope: BrainDecisionBiasScope.specialistConflict,
        preferredTarget: OnyxToolTarget.cctvReview,
        summary:
            'Replay history: specialist conflict promoted low -> medium via scenario set/category policy.',
        baseSeverity: 'low',
        effectiveSeverity: 'medium',
        policySourceLabel: 'scenario set/category policy',
      ),
      replayBiasStack: const <BrainDecisionBias>[
        BrainDecisionBias(
          source: BrainDecisionBiasSource.replayPolicy,
          scope: BrainDecisionBiasScope.sequenceFallback,
          preferredTarget: OnyxToolTarget.tacticalTrack,
          summary:
              'Replay history: sequence fallback promoted high -> critical via scenario set/scenario policy.',
          baseSeverity: 'high',
          effectiveSeverity: 'critical',
          policySourceLabel: 'scenario set/scenario policy',
        ),
      ],
      specialistAssessments: const <SpecialistAssessment>[
        SpecialistAssessment(
          specialist: OnyxSpecialist.cctv,
          sourceLabel: 'scene-review',
          summary: 'Scene review still lacks fresh confirmation.',
          recommendedTarget: OnyxToolTarget.cctvReview,
          confidence: 0.91,
          priority: SpecialistAssessmentPriority.high,
          evidence: <String>['Fresh clip confirmation is still pending'],
          missingInfo: <String>['fresh clip confirmation'],
        ),
      ],
    );

    final restored = BrainDecision.fromJson(decision.toJson());

    expect(restored.mode, BrainDecisionMode.corroboratedSynthesis);
    expect(restored.target, OnyxToolTarget.cctvReview);
    expect(restored.primaryPressure, 'active signal watch');
    expect(restored.supportingSpecialists, [OnyxSpecialist.cctv]);
    expect(restored.specialistAssessments, hasLength(1));
    expect(restored.decisionBias?.source, BrainDecisionBiasSource.replayPolicy);
    expect(
      restored.decisionBias?.scope,
      BrainDecisionBiasScope.specialistConflict,
    );
    expect(
      restored.decisionBias?.displaySummary,
      contains('Replay history: specialist conflict promoted low -> medium'),
    );
    expect(restored.plannerDisagreementTelemetry?.conflictCount, 2);
    expect(restored.plannerDisagreementTelemetry?.routeClosedConflictCount, 1);
    expect(
      restored.plannerDisagreementTelemetry?.topModelTarget,
      OnyxToolTarget.cctvReview,
    );
    expect(
      restored.plannerDisagreementTelemetry?.topTypedTarget,
      OnyxToolTarget.tacticalTrack,
    );
    expect(
      restored.plannerDisagreementTelemetry?.summaryLabel,
      contains('2 second-look disagreements recorded.'),
    );
    expect(restored.orderedReplayBiasStack, hasLength(2));
    expect(
      restored.replayBiasStackSignature,
      'replayPolicy:specialistConflict:cctvReview -> replayPolicy:sequenceFallback:tacticalTrack',
    );
    expect(
      restored.specialistAssessments.single.recommendedTarget,
      OnyxToolTarget.cctvReview,
    );
    expect(
      restored.specialistAssessments.single.evidence,
      contains('Fresh clip confirmation is still pending'),
    );

    final recommendation = restored.toRecommendation();
    expect(recommendation.target, OnyxToolTarget.cctvReview);
    expect(recommendation.nextMoveLabel, 'OPEN CCTV REVIEW');
    expect(recommendation.followUpLabel, 'RECHECK CCTV CONFIRMATION');
    expect(recommendation.missingInfo, contains('fresh clip confirmation'));
  });

  test('command brain snapshot round-trips through json and recommendation', () {
    final snapshot = OnyxCommandBrainSnapshot.fromRecommendation(
      const OnyxRecommendation(
        workItemId: 'brain-snapshot-1',
        target: OnyxToolTarget.tacticalTrack,
        nextMoveLabel: 'OPEN TACTICAL TRACK',
        headline: 'Tactical Track is the next move',
        detail: 'unused in snapshot replay',
        summary: 'One next move is staged in Tactical Track.',
        evidenceHeadline: 'unused',
        evidenceDetail: 'unused',
        advisory: 'Track continuity is the best next move.',
        confidence: 0.79,
        contextHighlights: <String>[
          'Sequence replay executed CCTV review before the next desk.',
        ],
      ),
      primaryPressure: 'active signal watch',
      rationale:
          'Scenario replay preserved the live-ops sequence contract and applied the Track fallback when dispatch availability failed.',
      plannerDisagreementTelemetry: const PlannerDisagreementTelemetry(
        conflictCount: 1,
        routeClosedConflictCount: 1,
        modelTargetCounts: <OnyxToolTarget, int>{
          OnyxToolTarget.dispatchBoard: 1,
        },
        typedTargetCounts: <OnyxToolTarget, int>{
          OnyxToolTarget.tacticalTrack: 1,
        },
        lastConflictSummary:
            'kept Tactical Track over Dispatch Board while routes stayed closed.',
      ),
      supportingSpecialists: const <OnyxSpecialist>[OnyxSpecialist.cctv],
      decisionBias: const BrainDecisionBias(
        source: BrainDecisionBiasSource.replayPolicy,
        scope: BrainDecisionBiasScope.specialistConstraint,
        preferredTarget: OnyxToolTarget.dispatchBoard,
        summary:
            'Replay history: specialist constraint promoted low -> medium via category policy.',
        baseSeverity: 'low',
        effectiveSeverity: 'medium',
        policySourceLabel: 'category policy',
      ),
    );

    final restored = OnyxCommandBrainSnapshot.fromJson(snapshot.toJson());

    expect(restored.mode, BrainDecisionMode.deterministic);
    expect(restored.target, OnyxToolTarget.tacticalTrack);
    expect(restored.modeLabel, 'deterministic hold');
    expect(restored.specialistSummary, 'CCTV specialist');
    expect(
      restored.biasSummary,
      contains('Replay history: specialist constraint promoted low -> medium'),
    );
    expect(
      restored.plannerDisagreementTelemetry?.summaryLabel,
      contains('1 second-look disagreement recorded.'),
    );
    expect(
      restored.plannerDisagreementTelemetry?.topModelTarget,
      OnyxToolTarget.dispatchBoard,
    );
    expect(restored.biasRailLabel, 'replay bias');
    expect(restored.orderedReplayBiasStack, hasLength(1));
    expect(
      restored.replayBiasStackSignature,
      'replayPolicy:specialistConstraint:dispatchBoard',
    );
    expect(
      restored.commandSurfaceStatusLines(
        rememberedReplayHistorySummary:
            'Replay history: replay bias stack drift critical.',
      ),
      <String>[
        'Brain: deterministic hold',
        'Specialists: CCTV specialist',
        'Replay policy bias: Replay history: specialist constraint promoted low -> medium via category policy.',
      ],
    );
    expect(
      restored.commandSurfaceSummaryLine(
        rememberedReplayHistorySummary:
            'Replay history: replay bias stack drift critical.',
      ),
      'Command brain: deterministic hold. Specialists: CCTV specialist. Replay policy bias: Replay history: specialist constraint promoted low -> medium via category policy.',
    );
    expect(
      restored.contextHighlights,
      contains('Sequence replay executed CCTV review before the next desk.'),
    );

    final recommendation = restored.toRecommendation();
    expect(recommendation.target, OnyxToolTarget.tacticalTrack);
    expect(recommendation.nextMoveLabel, 'OPEN TACTICAL TRACK');
    expect(
      recommendation.summary,
      'One next move is staged in Tactical Track.',
    );
  });

  test('thread memory follow-up and second-look helpers format shared labels', () {
    final pendingCue = OnyxThreadMemoryFollowUpCue.forSurfaceCount(0);
    final unresolvedCue = OnyxThreadMemoryFollowUpCue.forSurfaceCount(1);
    final overdueCue = OnyxThreadMemoryFollowUpCue.forSurfaceCount(2);

    expect(pendingCue.headline, 'Proactive follow-up is still pending');
    expect(
      pendingCue.actionDetail,
      'Resume the pending operator follow-up from this thread memory checkpoint.',
    );
    expect(unresolvedCue.headline, 'Follow-up is still unresolved');
    expect(unresolvedCue.personaId, 'proactive');
    expect(overdueCue.headline, 'Escalation follow-up is now overdue');
    expect(overdueCue.personaId, 'escalation');

    expect(
      buildSecondLookTelemetryBannerLabel(
        conflictCount: 1,
        lastConflictSummary: 'kept Tactical Track over CCTV Review.',
      ),
      '1 second-look disagreement recorded. Last: kept Tactical Track over CCTV Review.',
    );
    expect(
      buildSecondLookTelemetryRailLabel(conflictCount: 2),
      '2 model conflicts',
    );
    expect(
      buildThreadMemorySecondLookReasoningLine(
        conflictCount: 2,
        lastConflictSummary: 'kept Tactical Track over CCTV Review.',
      ),
      'Thread memory logged 2 second-look disagreements. Last conflict: kept Tactical Track over CCTV Review..',
    );
    expect(
      buildThreadMemorySecondLookReasoningLine(conflictCount: 1),
      'Thread memory logged 1 second-look disagreement.',
    );
    expect(
      buildSecondLookPlannerSummaryLabel(
        totalConflictCount: 2,
        impactedThreadCount: 2,
      ),
      '2 second-look disagreements across 2 threads.',
    );
    expect(
      buildSecondLookPlannerSummaryLabel(
        totalConflictCount: 0,
        impactedThreadCount: 0,
        hasTuningSignals: true,
      ),
      'No active second-look disagreements right now. The last flagged drift has eased.',
    );
    expect(
      buildSecondLookPlannerTopModelDriftLabel(
        deskLabel: 'CCTV Review',
        count: 2,
      ),
      'Model drifted most toward CCTV Review (2).',
    );
    expect(
      buildSecondLookPlannerTopTypedHoldLabel(
        deskLabel: 'Tactical Track',
        count: 2,
      ),
      'Typed planner held Tactical Track most often (2).',
    );
    expect(
      buildPlannerRouteClosedSummaryLabel(count: 1),
      'Safety kept routes closed 1 time.',
    );
    expect(
      buildPlannerRouteClosedSummaryLabel(count: 3),
      'Safety kept routes closed 3 times.',
    );
    expect(
      buildPlannerMaintenanceTrackedSummaryLabel(fromArchivedWatch: false),
      'Chronic drift is still tracked',
    );
    expect(
      buildPlannerMaintenanceTrackedSummaryLabel(fromArchivedWatch: true),
      'Chronic drift from archived watch is still tracked',
    );
    expect(
      buildPlannerMaintenanceBurnRateSummarySuffix(reopenedCount: 2),
      ' Top burn rate: review reopened 2 times.',
    );
    expect(
      buildPlannerUrgentMaintenanceSummarySuffix(hasUrgentReview: true),
      ' Urgent review active.',
    );
    expect(
      buildPlannerMaintenanceConflictSummaryLabel(
        activeCount: 1,
        completedCount: 0,
        severitySummary: 'chronic drift from archived watch',
        trackedFromArchivedWatch: true,
        topBurnRateReopenedCount: 2,
        hasUrgentReview: true,
      ),
      '1 planner maintenance alert active. Highest severity: chronic drift from archived watch. Top burn rate: review reopened 2 times. Urgent review active.',
    );
    expect(
      buildPlannerMaintenanceConflictSummaryLabel(
        activeCount: 0,
        completedCount: 1,
        severitySummary: 'chronic drift',
        trackedFromArchivedWatch: false,
      ),
      '1 planner maintenance review completed. Chronic drift is still tracked.',
    );
    expect(
      buildPlannerReactivationSummaryLabel(
        reactivationSignalCount: 1,
        highestSeverity: 'flapping',
      ),
      '1 archived planner item reactivated after the drift worsened. Highest severity: flapping.',
    );
    expect(
      buildPlannerReactivationSummaryLabel(
        reactivationSignalCount: 2,
        highestSeverity: '',
      ),
      '2 archived planner items reactivated after drift worsened.',
    );
    expect(
      buildPlannerArchivedReviewedSummaryLabel(archivedReviewedCount: 1),
      '1 reviewed planner item is archived while drift stays flat.',
    );
    expect(
      buildPlannerArchivedReviewedSummaryLabel(archivedReviewedCount: 3),
      '3 reviewed planner items are archived while drift stays flat.',
    );
    expect(
      buildPlannerFocusContextLabel(OnyxPlannerFocusContext.summary),
      'Focused from planner summary.',
    );
    expect(
      buildPlannerFocusContextLabel(OnyxPlannerFocusContext.modelDriftDetail),
      'Focused model drift detail.',
    );
    expect(
      buildPlannerFocusContextLabel(OnyxPlannerFocusContext.typedHoldDetail),
      'Focused typed hold detail.',
    );
    expect(
      buildPlannerFocusContextLabel(OnyxPlannerFocusContext.safetyHoldDetail),
      'Focused safety hold detail.',
    );
    expect(
      buildPlannerFocusContextLabel(
        OnyxPlannerFocusContext.archiveLineageFromMaintenanceAlert,
      ),
      'Focused archive lineage from maintenance alert.',
    );
    expect(
      buildPlannerFocusContextLabel(OnyxPlannerFocusContext.driftWatch),
      'Focused from drift watch.',
    );
    expect(
      buildPlannerFocusContextLabel(OnyxPlannerFocusContext.tuningCue),
      'Focused from planner tuning cue.',
    );
    expect(
      buildPlannerFocusContextLabel(OnyxPlannerFocusContext.archivedRuleBucket),
      'Focused archived rule bucket.',
    );
    expect(
      buildPlannerFocusContextLabel(OnyxPlannerFocusContext.threadRail),
      'Focused from the thread rail.',
    );
    expect(
      buildPlannerArchivedBucketSummaryLabel(archivedReviewedCount: 1),
      '1 reviewed item is archived until the drift worsens again.',
    );
    expect(
      buildPlannerArchivedBucketSummaryLabel(archivedReviewedCount: 3),
      '3 reviewed items are archived until the drift worsens again.',
    );
  });

  test(
    'command brain snapshot can prefer remembered replay continuity over stored replay bias wording',
    () {
      final snapshot = OnyxCommandBrainSnapshot.fromRecommendation(
        const OnyxRecommendation(
          workItemId: 'brain-snapshot-memory-1',
          target: OnyxToolTarget.tacticalTrack,
          nextMoveLabel: 'OPEN TACTICAL TRACK',
          headline: 'Tactical Track is the next move',
          detail: 'unused in snapshot replay',
          summary: 'One next move is staged in Tactical Track.',
          evidenceHeadline: 'unused',
          evidenceDetail: 'unused',
          advisory: 'Track continuity is the best next move.',
          confidence: 0.79,
        ),
        decisionBias: const BrainDecisionBias(
          source: BrainDecisionBiasSource.replayPolicy,
          scope: BrainDecisionBiasScope.sequenceFallback,
          preferredTarget: OnyxToolTarget.tacticalTrack,
          summary:
              'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
        ),
      );

      expect(
        snapshot.replayContextSummary(
          rememberedReplayHistorySummary:
              'Primary replay pressure: Replay history: sequence fallback low. Secondary replay pressure: Replay history: specialist conflict medium.',
          preferRememberedContinuity: true,
        ),
        'Remembered replay continuity: Primary replay pressure: Replay history: sequence fallback low.',
      );
      expect(
        snapshot.replayContextSummary(
          rememberedReplayHistorySummary:
              'Replay history: replay bias stack drift critical.',
        ),
        'Replay policy bias: Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
      );

      final continuityView =
          OnyxCommandSurfaceMemoryAdapter.continuityViewForSnapshot(
            snapshot,
            rememberedReplayHistorySummary:
                'Primary replay pressure: Replay history: sequence fallback low. Secondary replay pressure: Replay history: specialist conflict medium.',
            preferRememberedContinuity: true,
          );
      expect(
        continuityView.replayContextLine,
        'Remembered replay continuity: Primary replay pressure: Replay history: sequence fallback low.',
      );
      expect(
        continuityView.commandBrainSnapshot?.target,
        OnyxToolTarget.tacticalTrack,
      );
    },
  );

  test('command surface preview can be built from a routed snapshot', () {
    final snapshot = OnyxCommandBrainSnapshot.fromRecommendation(
      const OnyxRecommendation(
        workItemId: 'brain-preview-1',
        target: OnyxToolTarget.tacticalTrack,
        nextMoveLabel: 'OPEN TACTICAL TRACK',
        headline: 'Tactical Track is the replay recovery desk',
        detail: 'unused in preview',
        summary:
            'Replay priority keeps Tactical Track in front while sequence fallback stays active.',
        evidenceHeadline: 'unused',
        evidenceDetail: 'unused',
        advisory: 'Track continuity is the best next move.',
        confidence: 0.79,
      ),
    );

    final preview = OnyxCommandSurfacePreview.routed(snapshot);

    expect(preview.eyebrow, 'ONYX ROUTED');
    expect(preview.headline, 'Tactical Track is the replay recovery desk');
    expect(preview.label, 'OPEN TACTICAL TRACK');
    expect(
      preview.summary,
      'Replay priority keeps Tactical Track in front while sequence fallback stays active.',
    );
    expect(preview.commandBrainSnapshot?.target, OnyxToolTarget.tacticalTrack);
  });

  test('command brain timeline entry round-trips through json', () {
    final entry = OnyxCommandBrainTimelineEntry(
      sequence: 2,
      stage: 'open_track_handoff',
      note: 'Track fallback staged after dispatch availability failed.',
      snapshot: OnyxCommandBrainSnapshot.fromRecommendation(
        const OnyxRecommendation(
          workItemId: 'brain-timeline-1',
          target: OnyxToolTarget.tacticalTrack,
          nextMoveLabel: 'OPEN TACTICAL TRACK',
          headline: 'Tactical Track is the next move',
          detail: 'unused',
          summary: 'One next move is staged in Tactical Track.',
          evidenceHeadline: 'unused',
          evidenceDetail: 'unused',
          advisory:
              'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
          confidence: 0.81,
        ),
        primaryPressure: 'active signal watch',
        rationale:
            'Scenario replay preserved the live-ops sequence contract and applied the Track fallback when dispatch availability failed.',
        supportingSpecialists: const <OnyxSpecialist>[
          OnyxSpecialist.cctv,
          OnyxSpecialist.track,
        ],
        decisionBias: const BrainDecisionBias(
          source: BrainDecisionBiasSource.replayPolicy,
          scope: BrainDecisionBiasScope.sequenceFallback,
          preferredTarget: OnyxToolTarget.tacticalTrack,
          summary:
              'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
          policySourceLabel: 'scenario sequence policy',
        ),
        replayBiasStack: const <BrainDecisionBias>[
          BrainDecisionBias(
            source: BrainDecisionBiasSource.replayPolicy,
            scope: BrainDecisionBiasScope.specialistConflict,
            preferredTarget: OnyxToolTarget.cctvReview,
            summary:
                'Replay history: specialist conflict promoted low -> medium via scenario set/category policy.',
            baseSeverity: 'low',
            effectiveSeverity: 'medium',
            policySourceLabel: 'scenario set/category policy',
          ),
        ],
      ),
    );

    final restored = OnyxCommandBrainTimelineEntry.fromJson(entry.toJson());

    expect(restored.sequence, 2);
    expect(restored.stage, 'open_track_handoff');
    expect(restored.snapshot.target, OnyxToolTarget.tacticalTrack);
    expect(
      restored.snapshot.replayPressureSummary,
      'Primary replay pressure: Replay policy bias: Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track. Secondary replay pressure: Replay policy bias: Replay history: specialist conflict promoted low -> medium via scenario set/category policy.',
    );
    expect(
      restored.signatureSegment,
      'open_track_handoff:tacticalTrack:stack:replayPolicy:sequenceFallback:tacticalTrack -> replayPolicy:specialistConflict:cctvReview',
    );
  });

  test('command surface memory round-trips through json', () {
    final memory = OnyxCommandSurfaceMemory(
      commandBrainSnapshot: OnyxCommandBrainSnapshot.fromRecommendation(
        const OnyxRecommendation(
          workItemId: 'surface-memory-1',
          target: OnyxToolTarget.tacticalTrack,
          nextMoveLabel: 'OPEN TACTICAL TRACK',
          headline: 'Tactical Track is the next move',
          detail: 'unused',
          summary: 'One next move is staged in Tactical Track.',
          evidenceHeadline: 'unused',
          evidenceDetail: 'unused',
          advisory: 'Track continuity is the best next move.',
          confidence: 0.74,
        ),
        decisionBias: const BrainDecisionBias(
          source: BrainDecisionBiasSource.replayPolicy,
          scope: BrainDecisionBiasScope.sequenceFallback,
          preferredTarget: OnyxToolTarget.tacticalTrack,
          summary: 'Replay history: sequence fallback low.',
        ),
      ),
      replayHistorySummary:
          'Replay history: replay bias stack drift critical. Previous pressure moved off Dispatch Board.',
      commandPreview: OnyxCommandSurfacePreview.routed(
        OnyxCommandBrainSnapshot.fromRecommendation(
          const OnyxRecommendation(
            workItemId: 'surface-preview-1',
            target: OnyxToolTarget.tacticalTrack,
            nextMoveLabel: 'OPEN TACTICAL TRACK',
            headline: 'Tactical Track is the replay recovery desk',
            detail: 'unused',
            summary:
                'Replay priority keeps Tactical Track in front while sequence fallback stays active.',
            evidenceHeadline: 'unused',
            evidenceDetail: 'unused',
            advisory: 'Track continuity is the best next move.',
            confidence: 0.78,
          ),
          decisionBias: const BrainDecisionBias(
            source: BrainDecisionBiasSource.replayPolicy,
            scope: BrainDecisionBiasScope.sequenceFallback,
            preferredTarget: OnyxToolTarget.tacticalTrack,
            summary: 'Replay history: sequence fallback low.',
          ),
        ),
      ),
      commandReceipt: const OnyxCommandSurfaceReceiptMemory(
        label: 'EVIDENCE RECEIPT',
        headline: 'Tactical Track handoff sealed.',
        detail: 'ONYX recorded the typed triage handoff for Tactical Track.',
        target: OnyxToolTarget.tacticalTrack,
      ),
      commandOutcome: const OnyxCommandSurfaceOutcomeMemory(
        headline: 'Tactical Track opened from typed triage.',
        label: 'OPEN TACTICAL TRACK',
        summary: 'One next move is staged in Tactical Track.',
      ),
    );

    final restored = OnyxCommandSurfaceMemory.fromJson(memory.toJson());
    final continuityView = restored.continuityView();

    expect(restored.commandBrainSnapshot?.target, OnyxToolTarget.tacticalTrack);
    expect(
      restored.commandPreview?.headline,
      'Tactical Track is the replay recovery desk',
    );
    expect(restored.commandPreview?.label, 'OPEN TACTICAL TRACK');
    expect(
      restored.commandPreview?.summary,
      'Replay priority keeps Tactical Track in front while sequence fallback stays active.',
    );
    expect(
      restored.commandPreview?.commandBrainSnapshot?.target,
      OnyxToolTarget.tacticalTrack,
    );
    expect(restored.commandReceipt?.label, 'EVIDENCE RECEIPT');
    expect(restored.commandReceipt?.target, OnyxToolTarget.tacticalTrack);
    expect(continuityView.hasPreview, isTrue);
    expect(
      continuityView.commandPreview?.headline,
      'Tactical Track is the replay recovery desk',
    );
    expect(continuityView.target, OnyxToolTarget.tacticalTrack);
    expect(continuityView.receiptHeadline, 'Tactical Track handoff sealed.');
    expect(
      continuityView.preferredOutcomeSummaryText,
      'One next move is staged in Tactical Track.',
    );
    expect(
      restored.commandReceipt?.continuityLine(),
      'Last receipt: EVIDENCE RECEIPT - Tactical Track handoff sealed.',
    );
    expect(
      restored.commandOutcome?.headline,
      'Tactical Track opened from typed triage.',
    );
    expect(
      restored.commandOutcome?.headlineContinuityLine(),
      'Last command outcome: Tactical Track opened from typed triage.',
    );
    expect(
      restored.commandOutcome?.summaryContinuityLine(
        prefix: 'Thread memory last command outcome',
      ),
      'Thread memory last command outcome: One next move is staged in Tactical Track.',
    );
    expect(
      restored.replayContextSummary(preferRememberedContinuity: true),
      'Remembered replay continuity: Replay history: replay bias stack drift critical.',
    );
    expect(
      restored.replayContextSummary(),
      'Replay policy bias: Replay history: sequence fallback low.',
    );
    expect(
      restored
          .continuityView(preferRememberedContinuity: true)
          .replayContextLine,
      'Remembered replay continuity: Replay history: replay bias stack drift critical.',
    );
    expect(
      continuityView.commandBrainSummaryLine(),
      'Command brain: deterministic hold. Replay policy bias: Replay history: sequence fallback low.',
    );
    expect(continuityView.commandBrainStatusLines(), <String>[
      'Brain: deterministic hold',
      'Replay policy bias: Replay history: sequence fallback low.',
    ]);
    expect(
      restored.commandPreview?.commandBrainStatusLines(
        rememberedReplayHistorySummary:
            'Replay history: replay bias stack drift critical.',
        preferRememberedContinuity: true,
      ),
      <String>[
        'Brain: deterministic hold',
        'Remembered replay continuity: Replay history: replay bias stack drift critical.',
      ],
    );
    expect(
      restored.commandPreview?.detailLine(
        lastCommand: 'open tactical track',
        emptyDetail: 'unused',
        restoredDetail: 'unused',
      ),
      'Last command: "open tactical track"',
    );
    expect(
      restored.commandPreview?.detailLine(
        emptyDetail: 'unused',
        restoredDetail: 'Last command preview restored from command memory.',
      ),
      'Last command preview restored from command memory.',
    );
    expect(
      continuityView.commandBrainDecisionLines(
        rationale: 'Replay fallback stayed in front.',
        supportingSpecialists: const <OnyxSpecialist>[OnyxSpecialist.cctv],
      ),
      <String>[
        'Command brain mode: deterministic hold.',
        'Replay policy bias: Replay history: sequence fallback low.',
        'Brain rationale: Replay fallback stayed in front.',
        'Specialist support: CCTV specialist',
      ],
    );
    expect(
      continuityView.threadMemoryBannerLines(
        primaryPressureLabel: 'operator focus hold',
        lastRecommendedDeskLabel: 'Tactical Track',
        lastOpenedDeskLabel: 'CCTV Review',
        pendingConfirmations: const <String>['caller confirmation'],
        nextFollowUpLabel: 'RECHECK TRACK',
        operatorFocusNote: 'manual context preserved on the active thread',
        secondLookTelemetryLabel: '1 second-look disagreement recorded.',
        advisory: 'Track continuity is the best next move.',
        previewSummary: 'Unused preview summary.',
        recommendationSummary: 'One next move is staged in Tactical Track.',
      ),
      <String>[
        'Primary pressure: operator focus hold.',
        'Command brain: deterministic hold.',
        'Replay policy bias: Replay history: sequence fallback low.',
        'Last recommendation: Tactical Track.',
        'Last opened desk: CCTV Review.',
        'Last command outcome: Tactical Track opened from typed triage.',
        'Last receipt: EVIDENCE RECEIPT - Tactical Track handoff sealed.',
        'Still confirm caller confirmation.',
        'Next follow-up: RECHECK TRACK.',
        'Operator focus note: manual context preserved on the active thread.',
        '1 second-look disagreement recorded.',
        'Track continuity is the best next move.',
        'One next move is staged in Tactical Track.',
      ],
    );
    expect(
      continuityView.threadMemoryRailTokens(
        primaryPressureLabel: 'primary operator focus',
        lastRecommendedDeskLabel: 'Tactical Track',
        lastOpenedDeskLabel: 'CCTV Review',
        operatorFocusLabel: 'manual focus held',
        pendingConfirmationCount: 2,
        hasReadyFollowUp: true,
        secondLookTelemetryLabel: '1 model conflict',
      ),
      <String>[
        'primary operator focus',
        'brain deterministic',
        'replay bias',
        'Rec Tactical Track',
        'Open CCTV Review',
        'manual focus held',
        '2 checks pending',
        'follow-up ready',
        '1 model conflict',
      ],
    );
    expect(
      continuityView.threadMemoryReasoningLines(
        primaryPressureLabel: 'unresolved follow-up',
        replayHistorySummary:
            'Primary replay pressure: sequence fallback -> Tactical Track.',
        lastRecommendedDeskLabel: 'CCTV Review',
        lastOpenedDeskLabel: 'Dispatch Board',
        pendingConfirmations: const <String>['fresh clip confirmation'],
        nextFollowUpLabel: 'RECHECK CCTV CONFIRMATION',
        operatorFocusNote: 'manual context preserved on the active thread',
        secondLookTelemetryLine:
            'Thread memory logged 2 second-look disagreements. Last conflict: kept Tactical Track over CCTV Review.',
        advisory: 'Verify CCTV context first',
        orderedContextHighlights: const <String>[
          'Outstanding visual confirmation before escalation',
          'Track continuity remains warm',
        ],
        recommendationSummary: 'Hold CCTV Review in front',
      ),
      <String>[
        'Thread memory primary pressure: unresolved follow-up.',
        'Thread memory command brain stayed in deterministic hold.',
        'Thread memory replay context: Replay policy bias: Replay history: sequence fallback low..',
        'Thread memory last recommended CCTV Review.',
        'Thread memory last opened Dispatch Board.',
        'Thread memory last command outcome: One next move is staged in Tactical Track.',
        'Thread memory last receipt: EVIDENCE RECEIPT - Tactical Track handoff sealed.',
        'Thread memory still needs fresh clip confirmation.',
        'Thread memory next follow-up RECHECK CCTV CONFIRMATION.',
        'Primary replay pressure: sequence fallback -> Tactical Track.',
        'Thread memory operator focus: manual context preserved on the active thread.',
        'Thread memory logged 2 second-look disagreements. Last conflict: kept Tactical Track over CCTV Review.',
        'Thread memory advisory: Verify CCTV context first.',
        'Thread memory highlights: Outstanding visual confirmation before escalation | Track continuity remains warm.',
        'Thread memory summary: Hold CCTV Review in front.',
      ],
    );
    const recommendationBody = OnyxRecommendation(
      workItemId: 'command-body-lines-1',
      target: OnyxToolTarget.tacticalTrack,
      nextMoveLabel: 'OPEN TACTICAL TRACK',
      headline: 'Tactical Track is the next move',
      detail: 'unused',
      summary: 'One next move is staged in Tactical Track.',
      evidenceHeadline: 'unused',
      evidenceDetail: 'unused',
      advisory: 'Track continuity is the best next move.',
      confidence: 0.78,
      missingInfo: <String>['caller confirmation'],
      followUpLabel: 'RECHECK TRACK',
    );
    expect(
      recommendationBody.commandBodyContextLines(
        primaryPressureLine: 'Primary pressure: active signal watch.',
        operatorFocusLine: 'Operator focus preserved on the active thread.',
        replayContextLine:
            'Remembered replay continuity: Replay history: replay bias stack drift critical.',
        orderedContextHighlights: const <String>[
          'Outstanding visual confirmation before escalation',
        ],
      ),
      <String>[
        'Primary pressure: active signal watch.',
        'Operator focus preserved on the active thread.',
        'Remembered replay continuity: Replay history: replay bias stack drift critical.',
        'Advisory: Track continuity is the best next move.',
        'Context: Outstanding visual confirmation before escalation',
      ],
    );
    expect(
      recommendationBody.commandBodyClosingLines(
        confidenceLabel: '78% medium confidence',
      ),
      <String>[
        'Confidence: 78% medium confidence',
        'Missing info: caller confirmation',
        'Next follow-up: RECHECK TRACK',
      ],
    );
    expect(
      buildPlannerCommandSupportLines(
        backlog: const <String>['Priority 91: Tactical Track weighting'],
        adjustments: const <String>['Increase CCTV review threshold'],
        maintenance: const <String>[
          'Maintenance review completed for chronic drift.',
        ],
        notes: const <String>['Revisit Track vs CCTV posture rule.'],
      ),
      <String>[
        'Planner backlog: Priority 91: Tactical Track weighting',
        'Planner adjustment: Increase CCTV review threshold',
        'Planner maintenance: Maintenance review completed for chronic drift.',
        'Planner note: Revisit Track vs CCTV posture rule.',
      ],
    );
    expect(
      buildCommandBodyText(const <String>[
        ' Command brain mode: deterministic hold. ',
        '',
        ' Replay policy bias: Replay history: sequence fallback low. ',
      ]),
      'Command brain mode: deterministic hold.\nReplay policy bias: Replay history: sequence fallback low.',
    );
    expect(
      buildCommandBodyText(const <String>[
        'Verify CCTV context first.',
        'Source: openai:gpt-4.1-mini',
      ], separator: '\n\n'),
      'Verify CCTV context first.\n\nSource: openai:gpt-4.1-mini',
    );
    expect(
      buildCommandBodyFromSections(const <Iterable<String>>[
        <String>[' Command brain mode: deterministic hold. ', ''],
        <String>[
          ' Replay policy bias: Replay history: sequence fallback low. ',
          'Confidence: 81% high confidence',
        ],
      ]),
      'Command brain mode: deterministic hold.\nReplay policy bias: Replay history: sequence fallback low.\nConfidence: 81% high confidence',
    );
    expect(
      buildCommandBodyFromSections(const <Iterable<String>>[
        <String>['Verify CCTV context first.'],
        <String>['Source: openai:gpt-4.1-mini'],
      ], sectionSeparator: '\n\n'),
      'Verify CCTV context first.\n\nSource: openai:gpt-4.1-mini',
    );
  });

  test(
    'command surface continuity view falls back to preview brain snapshot for replay context and target',
    () {
      final previewSnapshot = OnyxCommandBrainSnapshot.fromRecommendation(
        const OnyxRecommendation(
          workItemId: 'surface-preview-only-1',
          target: OnyxToolTarget.tacticalTrack,
          nextMoveLabel: 'OPEN TACTICAL TRACK',
          headline: 'Tactical Track is the replay recovery desk',
          detail: 'unused',
          summary:
              'Replay priority keeps Tactical Track in front while sequence fallback stays active.',
          evidenceHeadline: 'unused',
          evidenceDetail: 'unused',
          advisory: 'Track continuity is the best next move.',
          confidence: 0.8,
        ),
        decisionBias: const BrainDecisionBias(
          source: BrainDecisionBiasSource.replayPolicy,
          scope: BrainDecisionBiasScope.sequenceFallback,
          preferredTarget: OnyxToolTarget.tacticalTrack,
          summary: 'Replay history: sequence fallback low.',
        ),
      );
      final memory = OnyxCommandSurfaceMemory(
        commandPreview: OnyxCommandSurfacePreview.routed(previewSnapshot),
      );

      final continuityView = memory.continuityView();

      expect(continuityView.hasPreview, isTrue);
      expect(continuityView.target, OnyxToolTarget.tacticalTrack);
      expect(
        continuityView.replayContextLine,
        'Replay policy bias: Replay history: sequence fallback low.',
      );
    },
  );

  test(
    'command surface memory adapter restores legacy continuity and merges updates',
    () {
      final legacySnapshot = OnyxCommandBrainSnapshot.fromRecommendation(
        const OnyxRecommendation(
          workItemId: 'surface-memory-legacy-1',
          target: OnyxToolTarget.cctvReview,
          nextMoveLabel: 'OPEN CCTV REVIEW',
          headline: 'CCTV Review is the next move',
          detail: 'unused',
          summary: 'One next move is staged in CCTV Review.',
          evidenceHeadline: 'unused',
          evidenceDetail: 'unused',
          advisory: 'Visual confirmation is still required.',
          confidence: 0.71,
        ),
      );

      final restored = OnyxCommandSurfaceMemoryAdapter.restore(
        legacyCommandBrainSnapshot: legacySnapshot,
        legacyReplayHistorySummary:
            '  Replay history: replay bias stack drift critical.  ',
        legacyCommandReceipt: const OnyxCommandSurfaceReceiptMemory(
          label: 'EVIDENCE READY',
          headline: 'Typed next move held for review.',
          detail: 'Dispatch stayed staged for operator review.',
          target: OnyxToolTarget.dispatchBoard,
        ),
        legacyCommandOutcome: const OnyxCommandSurfaceOutcomeMemory(
          headline: 'Dispatch Board stayed staged from typed triage.',
          label: 'OPEN DISPATCH BOARD',
          summary: 'One next move is staged in Dispatch Board.',
        ),
      );

      expect(restored.commandBrainSnapshot?.target, OnyxToolTarget.cctvReview);
      expect(
        restored.replayHistorySummary,
        'Replay history: replay bias stack drift critical.',
      );
      expect(
        restored.commandReceipt?.headline,
        'Typed next move held for review.',
      );
      expect(
        restored.commandOutcome?.summary,
        'One next move is staged in Dispatch Board.',
      );

      final merged = OnyxCommandSurfaceMemoryAdapter.merge(
        base: restored,
        replayHistorySummary: '  Replay history: sequence fallback low.  ',
        replaceCommandPreview: true,
        commandPreview: OnyxCommandSurfacePreview.answered(
          headline: 'CCTV Review remains the next move',
          label: 'OPEN CCTV REVIEW',
          summary: 'Visual confirmation stays in front after continuity merge.',
        ),
        replaceCommandReceipt: true,
        commandReceipt: const OnyxCommandSurfaceReceiptMemory(
          label: 'EVIDENCE RECEIPT',
          headline: 'CCTV Review handoff sealed.',
          detail: 'ONYX recorded the visual review handoff.',
          target: OnyxToolTarget.cctvReview,
        ),
        replaceCommandOutcome: true,
        commandOutcome: const OnyxCommandSurfaceOutcomeMemory(
          headline: 'CCTV Review opened from typed triage.',
          label: 'OPEN CCTV REVIEW',
          summary: 'One next move is staged in CCTV Review.',
        ),
      );

      expect(merged.commandBrainSnapshot?.target, OnyxToolTarget.cctvReview);
      expect(
        merged.replayHistorySummary,
        'Replay history: sequence fallback low.',
      );
      expect(
        merged.commandPreview?.headline,
        'CCTV Review remains the next move',
      );
      expect(merged.commandReceipt?.headline, 'CCTV Review handoff sealed.');
      expect(
        merged.commandOutcome?.headline,
        'CCTV Review opened from typed triage.',
      );
      expect(
        const OnyxCommandSurfaceOutcomeMemory(
          headline: 'Dispatch Board opened from typed triage.',
        ).preferredSummaryText,
        'Dispatch Board opened from typed triage.',
      );

      final preferredPersisted = const OnyxCommandSurfaceMemory(
        replayHistorySummary: 'Replay history: specialist conflict medium.',
      );
      final restoredPreferred = OnyxCommandSurfaceMemoryAdapter.restore(
        persistedMemory: preferredPersisted,
        legacyCommandBrainSnapshot: legacySnapshot,
        legacyReplayHistorySummary: 'Replay history: sequence fallback low.',
      );
      expect(
        restoredPreferred.replayHistorySummary,
        'Replay history: specialist conflict medium.',
      );
      expect(restoredPreferred.commandBrainSnapshot, isNull);
    },
  );

  test(
    'BrainDecisionBias labels promoted sequence fallback as replay policy escalation',
    () {
      const bias = BrainDecisionBias(
        source: BrainDecisionBiasSource.replayPolicy,
        scope: BrainDecisionBiasScope.sequenceFallback,
        preferredTarget: OnyxToolTarget.tacticalTrack,
        summary:
            'Replay history: sequence fallback promoted high -> critical via scenario set/scenario policy.',
        baseSeverity: 'high',
        effectiveSeverity: 'critical',
        policySourceLabel: 'scenario set/scenario policy',
      );

      expect(bias.isPolicyEscalatedSequenceFallback, isTrue);
      expect(bias.displayLabel, 'Replay policy escalation');
      expect(bias.executionSourceLabel, 'replay policy escalation');
      expect(
        bias.displaySummary,
        'Replay policy escalation: Replay history: sequence fallback promoted high -> critical via scenario set/scenario policy.',
      );
    },
  );
}
