import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/onyx_agent_cloud_boost_service.dart';
import 'package:omnix_dashboard/application/onyx_command_brain_orchestrator.dart';
import 'package:omnix_dashboard/domain/authority/onyx_command_brain_contract.dart';
import 'package:omnix_dashboard/domain/authority/onyx_task_protocol.dart';

void main() {
  const orchestrator = OnyxCommandBrainOrchestrator();

  OnyxWorkItem buildItem({
    String prompt =
        'Triage the active incident and stage one obvious next move',
    DateTime? createdAt,
    int activeDispatchCount = 0,
    int dispatchesAwaitingResponseCount = 0,
    int responseCount = 0,
    int patrolCount = 0,
    int closedDispatchCount = 0,
    bool hasVisualSignal = false,
    String latestIntelligenceHeadline = '',
    int? latestIntelligenceRiskScore,
    String contextSummary = '',
    bool hasGuardWelfareRisk = false,
    String guardWelfareSignalLabel = '',
  }) {
    return OnyxWorkItem(
      id: 'work-item-1',
      intent: OnyxWorkIntent.triageIncident,
      prompt: prompt,
      clientId: 'CLIENT-001',
      siteId: 'SITE-SANDTON',
      incidentReference: 'INC-42',
      sourceRouteLabel: 'Command',
      createdAt: createdAt ?? DateTime.utc(2026, 4, 1, 8, 0),
      contextSummary: contextSummary,
      activeDispatchCount: activeDispatchCount,
      dispatchesAwaitingResponseCount: dispatchesAwaitingResponseCount,
      responseCount: responseCount,
      patrolCount: patrolCount,
      closedDispatchCount: closedDispatchCount,
      hasVisualSignal: hasVisualSignal,
      latestIntelligenceHeadline: latestIntelligenceHeadline,
      latestIntelligenceRiskScore: latestIntelligenceRiskScore,
      hasGuardWelfareRisk: hasGuardWelfareRisk,
      guardWelfareSignalLabel: guardWelfareSignalLabel,
    );
  }

  test(
    'keeps deterministic triage when no specialist or advisory overrides exist',
    () {
      final decision = orchestrator.decide(
        item: buildItem(
          responseCount: 1,
          patrolCount: 1,
          contextSummary: 'Responses moving: 1. Patrol completions: 1.',
        ),
      );

      expect(decision.mode, BrainDecisionMode.deterministic);
      expect(decision.target, OnyxToolTarget.tacticalTrack);
      expect(decision.summary, 'One next move is staged in Tactical Track.');
      expect(decision.supportingSpecialists, isEmpty);
      expect(decision.toRecommendation().target, OnyxToolTarget.tacticalTrack);
    },
  );

  test(
    'enriches deterministic triage with planner disagreement telemetry without retargeting',
    () {
      final decision = orchestrator.decide(
        item: buildItem(
          responseCount: 1,
          patrolCount: 1,
          contextSummary: 'Responses moving: 1. Patrol completions: 1.',
        ),
        plannerDisagreementTelemetry: const PlannerDisagreementTelemetry(
          conflictCount: 2,
          routeClosedConflictCount: 1,
          modelTargetCounts: <OnyxToolTarget, int>{
            OnyxToolTarget.cctvReview: 2,
          },
          typedTargetCounts: <OnyxToolTarget, int>{
            OnyxToolTarget.tacticalTrack: 1,
          },
          lastConflictSummary:
              'kept Tactical Track over CCTV Review while the route stayed closed.',
        ),
      );

      expect(decision.mode, BrainDecisionMode.deterministic);
      expect(decision.target, OnyxToolTarget.tacticalTrack);
      expect(
        decision.rationale,
        contains(
          'Planner disagreement telemetry: 2 second-look disagreements recorded.',
        ),
      );
      expect(
        decision.contextHighlights,
        contains('Model drifted most toward CCTV Review (2).'),
      );
      expect(
        decision.contextHighlights,
        contains('Typed planner held Tactical Track most often (1).'),
      );
      expect(decision.followUpLabel, 'RECHECK SECOND LOOK');
      expect(
        decision.followUpPrompt,
        'Recheck the planner disagreement before widening beyond Tactical Track.',
      );
      expect(decision.decisionBias, isNull);
      expect(decision.orderedReplayBiasStack, isEmpty);
    },
  );

  test(
    'promotes corroborated synthesis when brain and specialist align on a different desk',
    () {
      final decision = orchestrator.decide(
        item: buildItem(
          responseCount: 1,
          patrolCount: 1,
          hasVisualSignal: true,
          latestIntelligenceHeadline: 'Suspicious person near the south gate',
          latestIntelligenceRiskScore: 74,
          contextSummary:
              'Responses moving: 1. Patrol completions: 1. Fresh clip confirmation still pending.',
        ),
        advisory: const OnyxAgentBrainAdvisory(
          summary:
              'Fresh visual confirmation should land before field posture widens.',
          recommendedTarget: OnyxToolTarget.cctvReview,
          confidence: 0.84,
          why:
              'The visual signal still needs confirmation before route continuity becomes decisive.',
          missingInfo: <String>['fresh clip confirmation'],
          primaryPressure: 'active signal watch',
          contextHighlights: <String>[
            'Fresh clip confirmation is still pending',
          ],
          narrative: 'Hold CCTV Review open first.',
        ),
        specialistAssessments: const <SpecialistAssessment>[
          SpecialistAssessment(
            specialist: OnyxSpecialist.cctv,
            sourceLabel: 'scene-review',
            summary: 'Scene review still lacks fresh confirmation.',
            recommendedTarget: OnyxToolTarget.cctvReview,
            confidence: 0.91,
            priority: SpecialistAssessmentPriority.high,
            evidence: <String>['Scene review still lacks fresh confirmation.'],
            missingInfo: <String>['fresh clip confirmation'],
          ),
        ],
      );

      expect(decision.mode, BrainDecisionMode.corroboratedSynthesis);
      expect(decision.target, OnyxToolTarget.cctvReview);
      expect(decision.primaryPressure, 'active signal watch');
      expect(decision.supportingSpecialists, [OnyxSpecialist.cctv]);
      expect(
        decision.advisory,
        'Fresh visual confirmation should land before field posture widens.',
      );
      expect(
        decision.contextHighlights,
        contains('Fresh clip confirmation is still pending'),
      );
      expect(decision.missingInfo, contains('fresh clip confirmation'));
      expect(decision.nextMoveLabel, 'OPEN CCTV REVIEW');
      expect(decision.detail, contains('Confirm the scene visually'));
    },
  );

  test(
    'records replay policy bias when deterministic triage reopens recovery first',
    () {
      final decision = orchestrator.decide(
        item: buildItem(
          responseCount: 1,
          patrolCount: 1,
          contextSummary: 'Responses moving: 1. Patrol completions: 1.',
        ),
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
      );

      expect(decision.mode, BrainDecisionMode.deterministic);
      expect(decision.target, OnyxToolTarget.cctvReview);
      expect(decision.headline, 'CCTV Review is the replay recovery desk');
      expect(
        decision.summary,
        'Replay priority keeps CCTV Review in front while specialist conflict stays active.',
      );
      expect(decision.followUpLabel, 'RESOLVE SPECIALIST CONFLICT');
      expect(
        decision.advisory,
        'Replay history: specialist conflict promoted low -> medium via scenario set/category policy.',
      );
      expect(
        decision.decisionBias?.source,
        BrainDecisionBiasSource.replayPolicy,
      );
      expect(
        decision.rationale,
        contains('Replay policy bias kept CCTV Review in front'),
      );
    },
  );

  test('frames promoted sequence fallback as replay policy escalation', () {
    final decision = orchestrator.decide(
      item: buildItem(
        responseCount: 1,
        patrolCount: 1,
        contextSummary: 'Responses moving: 1. Patrol completions: 1.',
      ),
      decisionBias: const BrainDecisionBias(
        source: BrainDecisionBiasSource.replayPolicy,
        scope: BrainDecisionBiasScope.sequenceFallback,
        preferredTarget: OnyxToolTarget.tacticalTrack,
        summary:
            'Replay history: sequence fallback promoted high -> critical via scenario set/scenario policy.',
        baseSeverity: 'high',
        effectiveSeverity: 'critical',
        policySourceLabel: 'scenario set/scenario policy',
      ),
    );

    expect(decision.mode, BrainDecisionMode.deterministic);
    expect(decision.target, OnyxToolTarget.tacticalTrack);
    expect(decision.headline, 'Tactical Track is the replay escalation desk');
    expect(
      decision.summary,
      'Replay policy escalation keeps Tactical Track in front while sequence fallback stays active.',
    );
    expect(
      decision.detail,
      contains(
        'Replay policy escalation is still holding the safer sequence fallback.',
      ),
    );
    expect(
      decision.rationale,
      contains('Replay policy escalation kept Tactical Track in front'),
    );
  });

  test('carries secondary replay pressure into command-brain reasoning', () {
    final decision = orchestrator.decide(
      item: buildItem(
        responseCount: 1,
        patrolCount: 1,
        contextSummary: 'Responses moving: 1. Patrol completions: 1.',
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
    );

    expect(decision.target, OnyxToolTarget.tacticalTrack);
    expect(
      decision.advisory,
      contains(
        'Secondary replay pressure: Replay history: specialist conflict',
      ),
    );
    expect(
      decision.rationale,
      contains(
        'Secondary replay pressure remains on Replay history: specialist conflict',
      ),
    );
    expect(
      decision.contextHighlights,
      contains(
        'Secondary replay pressure: Replay history: specialist conflict promoted low -> medium via scenario set/category policy.',
      ),
    );
    expect(decision.orderedReplayBiasStack, hasLength(2));
    expect(
      decision.replayBiasStackSignature,
      'replayPolicy:sequenceFallback:tacticalTrack -> replayPolicy:specialistConflict:cctvReview',
    );
  });

  test('applies a hard specialist constraint before route execution', () {
    final decision = orchestrator.decide(
      item: buildItem(
        prompt: 'Client wants immediate dispatch',
        contextSummary:
            'Client anxiety is high but no live threat is verified.',
      ),
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
      specialistAssessments: const <SpecialistAssessment>[
        SpecialistAssessment(
          specialist: OnyxSpecialist.guardOps,
          sourceLabel: 'wearable-welfare',
          summary:
              'Possible guard distress pattern requires an operator-held welfare escalation.',
          recommendedTarget: OnyxToolTarget.dispatchBoard,
          confidence: 0.97,
          priority: SpecialistAssessmentPriority.critical,
          evidence: <String>[
            'Wearable telemetry shows a distress-shaped inactivity pattern.',
          ],
          missingInfo: <String>['fresh guard voice confirmation'],
          allowRouteExecution: false,
          isHardConstraint: true,
        ),
      ],
    );

    expect(decision.mode, BrainDecisionMode.specialistConstraint);
    expect(decision.target, OnyxToolTarget.dispatchBoard);
    expect(decision.allowRouteExecution, isFalse);
    expect(decision.supportingSpecialists, [OnyxSpecialist.guardOps]);
    expect(
      decision.summary,
      'ONYX command brain staged a constrained move in Dispatch Board.',
    );
    expect(
      decision.rationale,
      contains('Guard Ops specialist raised a hard constraint'),
    );
    expect(decision.decisionBias, isNull);
    expect(decision.missingInfo, contains('fresh guard voice confirmation'));
    expect(decision.toRecommendation().allowRouteExecution, isFalse);
  });
}
