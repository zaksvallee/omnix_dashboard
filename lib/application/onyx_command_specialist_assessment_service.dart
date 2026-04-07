import '../domain/authority/onyx_command_brain_contract.dart';
import '../domain/authority/onyx_task_protocol.dart';

class OnyxCommandSpecialistAssessmentService {
  const OnyxCommandSpecialistAssessmentService();

  List<SpecialistAssessment> assess({
    required OnyxWorkItem item,
    OnyxRecommendation? deterministicRecommendation,
  }) {
    final normalizedPrompt = item.prompt.trim().toLowerCase();
    final deterministicTarget = deterministicRecommendation?.target;
    final assessments = <SpecialistAssessment>[];

    if (_shouldAddDispatchAssessment(item, normalizedPrompt)) {
      assessments.add(
        SpecialistAssessment(
          specialist: OnyxSpecialist.dispatch,
          sourceLabel: 'dispatch-board',
          summary: item.dispatchesAwaitingResponseCount > 0
              ? 'Dispatch ownership is still live and waiting for a responder.'
              : 'Dispatch activity is still active in the scoped incident picture.',
          recommendedTarget: OnyxToolTarget.dispatchBoard,
          confidence: item.dispatchesAwaitingResponseCount > 0 ? 0.88 : 0.74,
          priority: item.dispatchesAwaitingResponseCount > 0
              ? SpecialistAssessmentPriority.high
              : SpecialistAssessmentPriority.medium,
          evidence: <String>[
            if (item.dispatchesAwaitingResponseCount > 0)
              'Dispatches awaiting response: ${item.dispatchesAwaitingResponseCount}.',
            if (item.activeDispatchCount > 0)
              'Active dispatches in scope: ${item.activeDispatchCount}.',
          ],
          missingInfo: item.dispatchesAwaitingResponseCount > 0
              ? const <String>['current responder ETA']
              : const <String>[],
        ),
      );
    }

    if (_shouldAddTrackAssessment(item, normalizedPrompt)) {
      assessments.add(
        SpecialistAssessment(
          specialist: OnyxSpecialist.track,
          sourceLabel: 'field-posture',
          summary:
              'Field posture is still active enough that route continuity matters.',
          recommendedTarget: OnyxToolTarget.tacticalTrack,
          confidence: item.responseCount > 0 || item.patrolCount > 0
              ? 0.86
              : 0.72,
          priority: item.responseCount > 0 || item.patrolCount > 0
              ? SpecialistAssessmentPriority.high
              : SpecialistAssessmentPriority.medium,
          evidence: <String>[
            if (item.responseCount > 0)
              'Responses moving in scope: ${item.responseCount}.',
            if (item.patrolCount > 0)
              'Patrol completions in scope: ${item.patrolCount}.',
            if (item.guardCheckInCount > 0)
              'Guard check-ins in scope: ${item.guardCheckInCount}.',
            if (item.prioritySiteLabel.trim().isNotEmpty)
              'Priority site still centered on ${item.prioritySiteLabel.trim()}.',
          ],
        ),
      );
    }

    if (_shouldAddCctvAssessment(item, normalizedPrompt)) {
      assessments.add(
        SpecialistAssessment(
          specialist: OnyxSpecialist.cctv,
          sourceLabel: 'scene-review',
          summary: item.hasVisualSignal
              ? 'Fresh visual confirmation is still part of the decision picture.'
              : 'Scene review can narrow the next move before the desk widens.',
          recommendedTarget: OnyxToolTarget.cctvReview,
          confidence: (item.latestIntelligenceRiskScore ?? 0) >= 80
              ? 0.9
              : 0.78,
          priority: (item.latestIntelligenceRiskScore ?? 0) >= 80
              ? SpecialistAssessmentPriority.high
              : SpecialistAssessmentPriority.medium,
          evidence: <String>[
            if (item.hasVisualSignal)
              'Latest visual signal: ${item.latestIntelligenceHeadline.trim().isEmpty ? 'visual intelligence present' : item.latestIntelligenceHeadline.trim()}.',
            if (item.repeatedFalseAlarmCount > 0)
              'Repeated false-alarm pattern count: ${item.repeatedFalseAlarmCount}.',
          ],
          missingInfo: item.hasVisualSignal
              ? const <String>['fresh visual confirmation']
              : const <String>[],
        ),
      );
    }

    if (_shouldAddClientAssessment(item, normalizedPrompt)) {
      assessments.add(
        const SpecialistAssessment(
          specialist: OnyxSpecialist.clientComms,
          sourceLabel: 'client-lane',
          summary:
              'The request is leaning client-facing, so the operator update lane should stay ready.',
          recommendedTarget: OnyxToolTarget.clientComms,
          confidence: 0.72,
          priority: SpecialistAssessmentPriority.medium,
        ),
      );
    }

    if (_shouldAddReportsAssessment(item, normalizedPrompt)) {
      assessments.add(
        const SpecialistAssessment(
          specialist: OnyxSpecialist.reports,
          sourceLabel: 'closure-summary',
          summary:
              'The incident picture is already leaning into closure and record-preserving summary work.',
          recommendedTarget: OnyxToolTarget.reportsWorkspace,
          confidence: 0.84,
          priority: SpecialistAssessmentPriority.high,
        ),
      );
    }

    if (_shouldAddGuardConstraint(item, deterministicTarget)) {
      assessments.add(
        SpecialistAssessment(
          specialist: item.hasGuardWelfareRisk
              ? OnyxSpecialist.guardOps
              : OnyxSpecialist.policy,
          sourceLabel: item.hasGuardWelfareRisk
              ? 'guard-welfare'
              : 'human-safety',
          summary: item.hasGuardWelfareRisk
              ? 'Possible guard distress still requires a dispatch-held welfare escalation.'
              : 'Human safety signals keep the next move inside Dispatch Board until live status is confirmed.',
          recommendedTarget: OnyxToolTarget.dispatchBoard,
          confidence: 0.96,
          priority: SpecialistAssessmentPriority.critical,
          evidence: <String>[
            if (item.guardWelfareSignalLabel.trim().isNotEmpty)
              item.guardWelfareSignalLabel.trim()
            else if (item.hasHumanSafetySignal)
              'Human safety signal is active in the scoped context.',
          ],
          missingInfo: item.hasGuardWelfareRisk
              ? const <String>['guard voice confirmation']
              : const <String>['live welfare confirmation'],
          allowRouteExecution: false,
          isHardConstraint: true,
        ),
      );
    }

    return List<SpecialistAssessment>.unmodifiable(assessments);
  }

  bool _shouldAddDispatchAssessment(
    OnyxWorkItem item,
    String normalizedPrompt,
  ) {
    return item.dispatchesAwaitingResponseCount > 0 ||
        item.activeDispatchCount > 0 ||
        normalizedPrompt.contains('dispatch') ||
        normalizedPrompt.contains('alarm') ||
        normalizedPrompt.contains('response');
  }

  bool _shouldAddTrackAssessment(OnyxWorkItem item, String normalizedPrompt) {
    return item.responseCount > 0 ||
        item.patrolCount > 0 ||
        item.guardCheckInCount > 0 ||
        item.scopedSiteCount > 1 ||
        item.latestPartnerStatusLabel.toLowerCase().contains('onsite') ||
        normalizedPrompt.contains('track') ||
        normalizedPrompt.contains('patrol') ||
        normalizedPrompt.contains('guard') ||
        normalizedPrompt.contains('route');
  }

  bool _shouldAddCctvAssessment(OnyxWorkItem item, String normalizedPrompt) {
    final explicitVisualPrompt =
        normalizedPrompt.contains('camera') ||
        normalizedPrompt.contains('cctv') ||
        normalizedPrompt.contains('video') ||
        normalizedPrompt.contains('visual');
    final highPressureVisualSignal =
        item.hasVisualSignal && (item.latestIntelligenceRiskScore ?? 0) >= 60;
    return explicitVisualPrompt ||
        item.repeatedFalseAlarmCount > 0 ||
        highPressureVisualSignal;
  }

  bool _shouldAddClientAssessment(OnyxWorkItem item, String normalizedPrompt) {
    return item.closedDispatchCount == 0 &&
        (normalizedPrompt.contains('client') ||
            normalizedPrompt.contains('notify') ||
            normalizedPrompt.contains('message') ||
            normalizedPrompt.contains('update'));
  }

  bool _shouldAddReportsAssessment(OnyxWorkItem item, String normalizedPrompt) {
    return item.latestClosureAt != null ||
        item.latestEventLabel.toLowerCase().contains('incident closed') ||
        (item.closedDispatchCount > 0 &&
            item.activeDispatchCount == 0 &&
            !normalizedPrompt.contains('client'));
  }

  bool _shouldAddGuardConstraint(
    OnyxWorkItem item,
    OnyxToolTarget? deterministicTarget,
  ) {
    if (deterministicTarget == OnyxToolTarget.dispatchBoard) {
      return false;
    }
    return item.hasGuardWelfareRisk || item.hasHumanSafetySignal;
  }
}
