import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/onyx_command_specialist_assessment_service.dart';
import 'package:omnix_dashboard/application/onyx_operator_orchestrator.dart';
import 'package:omnix_dashboard/domain/authority/onyx_command_brain_contract.dart';
import 'package:omnix_dashboard/domain/authority/onyx_task_protocol.dart';

void main() {
  const service = OnyxCommandSpecialistAssessmentService();
  const operator = OnyxOperatorOrchestrator();

  OnyxWorkItem buildItem({
    String prompt =
        'Triage the active incident and stage one obvious next move',
    int activeDispatchCount = 0,
    int dispatchesAwaitingResponseCount = 0,
    int responseCount = 0,
    int patrolCount = 0,
    int guardCheckInCount = 0,
    int closedDispatchCount = 0,
    bool hasVisualSignal = false,
    String latestIntelligenceHeadline = '',
    String latestIntelligenceSourceType = '',
    int? latestIntelligenceRiskScore,
    int repeatedFalseAlarmCount = 0,
    bool hasHumanSafetySignal = false,
    bool hasGuardWelfareRisk = false,
    String guardWelfareSignalLabel = '',
    DateTime? latestClosureAt,
  }) {
    return OnyxWorkItem(
      id: 'work-item-1',
      intent: OnyxWorkIntent.triageIncident,
      prompt: prompt,
      clientId: 'CLIENT-001',
      siteId: 'SITE-SANDTON',
      incidentReference: 'INC-42',
      sourceRouteLabel: 'Command',
      createdAt: DateTime.utc(2026, 4, 1, 8, 0),
      activeDispatchCount: activeDispatchCount,
      dispatchesAwaitingResponseCount: dispatchesAwaitingResponseCount,
      responseCount: responseCount,
      patrolCount: patrolCount,
      guardCheckInCount: guardCheckInCount,
      closedDispatchCount: closedDispatchCount,
      hasVisualSignal: hasVisualSignal,
      latestIntelligenceHeadline: latestIntelligenceHeadline,
      latestIntelligenceSourceType: latestIntelligenceSourceType,
      latestIntelligenceRiskScore: latestIntelligenceRiskScore,
      repeatedFalseAlarmCount: repeatedFalseAlarmCount,
      hasHumanSafetySignal: hasHumanSafetySignal,
      hasGuardWelfareRisk: hasGuardWelfareRisk,
      guardWelfareSignalLabel: guardWelfareSignalLabel,
      latestClosureAt: latestClosureAt,
    );
  }

  test(
    'emits CCTV corroboration when visual confirmation remains live beside field posture',
    () {
      final item = buildItem(
        responseCount: 1,
        patrolCount: 1,
        hasVisualSignal: true,
        latestIntelligenceHeadline: 'Confirmed movement near the west fence',
        latestIntelligenceSourceType: 'cctv',
        latestIntelligenceRiskScore: 84,
      );
      final deterministicRecommendation = operator.recommend(item);

      final assessments = service.assess(
        item: item,
        deterministicRecommendation: deterministicRecommendation,
      );

      expect(deterministicRecommendation.target, OnyxToolTarget.tacticalTrack);
      expect(
        assessments.any(
          (assessment) =>
              assessment.specialist == OnyxSpecialist.cctv &&
              assessment.recommendedTarget == OnyxToolTarget.cctvReview,
        ),
        isTrue,
      );
      expect(
        assessments.any(
          (assessment) =>
              assessment.specialist == OnyxSpecialist.track &&
              assessment.recommendedTarget == OnyxToolTarget.tacticalTrack,
        ),
        isTrue,
      );
    },
  );

  test(
    'does not add CCTV corroboration for low-pressure visual noise alone',
    () {
      final item = buildItem(
        hasVisualSignal: true,
        latestIntelligenceHeadline: 'Tree motion near the outer fence',
        latestIntelligenceSourceType: 'cctv',
        latestIntelligenceRiskScore: 24,
      );

      final assessments = service.assess(
        item: item,
        deterministicRecommendation: operator.recommend(item),
      );

      expect(
        assessments.where(
          (assessment) => assessment.specialist == OnyxSpecialist.cctv,
        ),
        isEmpty,
      );
    },
  );

  test(
    'does not add a hard guard constraint when deterministic triage already holds dispatch board',
    () {
      final item = buildItem(
        prompt: 'Status guard?',
        hasGuardWelfareRisk: true,
        guardWelfareSignalLabel: 'Possible guard distress detected.',
      );
      final deterministicRecommendation = operator.recommend(item);

      final assessments = service.assess(
        item: item,
        deterministicRecommendation: deterministicRecommendation,
      );

      expect(deterministicRecommendation.target, OnyxToolTarget.dispatchBoard);
      expect(
        assessments.where((assessment) => assessment.isHardConstraint),
        isEmpty,
      );
    },
  );

  test(
    'adds a hard guard constraint when dispatch is not already the held desk',
    () {
      final item = buildItem(
        hasGuardWelfareRisk: true,
        guardWelfareSignalLabel: 'Possible guard distress detected.',
      );

      final assessments = service.assess(
        item: item,
        deterministicRecommendation: const OnyxRecommendation(
          workItemId: 'work-item-1',
          target: OnyxToolTarget.tacticalTrack,
          nextMoveLabel: 'OPEN TACTICAL TRACK',
          headline: 'Tactical Track is the next move',
          detail: 'Hold field posture.',
          summary: 'One next move is staged in Tactical Track.',
          evidenceHeadline: 'Tactical Track handoff sealed.',
          evidenceDetail: 'Typed triage held Tactical Track first.',
        ),
      );

      final constraint = assessments.singleWhere(
        (assessment) => assessment.isHardConstraint,
      );
      expect(constraint.specialist, OnyxSpecialist.guardOps);
      expect(constraint.recommendedTarget, OnyxToolTarget.dispatchBoard);
      expect(constraint.allowRouteExecution, isFalse);
      expect(constraint.priority, SpecialistAssessmentPriority.critical);
      expect(constraint.missingInfo, contains('guard voice confirmation'));
    },
  );
}
