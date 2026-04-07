import '../domain/authority/onyx_task_protocol.dart';
import 'telegram_client_prompt_signals.dart';

class OnyxOperatorOrchestrator {
  const OnyxOperatorOrchestrator();

  OnyxRecommendation recommend(OnyxWorkItem item) {
    final normalizedPrompt = normalizeTelegramClientPromptSignalText(
      item.prompt,
    );
    if (_shouldHoldForClarification(item, normalizedPrompt)) {
      final missingInfo = _missingInfoForClarification(normalizedPrompt);
      return OnyxRecommendation(
        workItemId: item.id,
        target: OnyxToolTarget.dispatchBoard,
        nextMoveLabel: 'CLARIFY FIRST',
        headline: 'ONYX needs one grounded detail first',
        detail:
            'I do not have enough verified context to act on this yet. Clarify the scope before I reopen a desk or imply a threat that is not loaded in the current signal picture.',
        summary: 'Clarification is staged before ONYX reopens a desk.',
        evidenceHeadline: 'Clarification checkpoint logged.',
        evidenceDetail:
            'ONYX held the typed triage handoff, avoided an unverified claim, and asked for the missing scope before any desk reopened.',
        advisory: _clarificationAdvisory(item, normalizedPrompt),
        confidence: _confidenceForRecommendation(
          item,
          normalizedPrompt: normalizedPrompt,
          target: OnyxToolTarget.dispatchBoard,
          allowRouteExecution: false,
        ),
        missingInfo: missingInfo,
        allowRouteExecution: false,
      );
    }
    if (_looksLikeRecentClosure(item, normalizedPrompt)) {
      return OnyxRecommendation(
        workItemId: item.id,
        target: OnyxToolTarget.reportsWorkspace,
        nextMoveLabel: 'OPEN REPORTS WORKSPACE',
        headline: 'Reports Workspace is holding the closure summary',
        detail:
            'The incident was closed moments ago for ${item.scopeLabel}. Keep it in summary mode instead of reopening the response desks. Capture the closure status, note the last verified outcome, and prepare the reporting handoff.',
        summary: 'Incident resolved and held in Reports Workspace.',
        evidenceHeadline: 'Closure summary checkpoint logged.',
        evidenceDetail:
            'ONYX detected a recent incident closure, kept the thread in reporting mode, and avoided reopening an already-resolved response lane.',
        advisory: 'Incident resolved.',
        confidence: 0.88,
        missingInfo: const <String>['final client-facing closure note'],
        allowRouteExecution: false,
      );
    }
    final target = _targetForWorkItem(item, normalizedPrompt);
    final scope = item.scopeLabel;
    final incident = item.incidentReference.trim().isEmpty
        ? 'the active incident'
        : item.incidentReference.trim();
    final rationale = _rationaleForTarget(item, target);
    final advisory = _advisoryForRecommendation(
      item: item,
      normalizedPrompt: normalizedPrompt,
      target: target,
    );
    final contextHighlights = _contextHighlightsForRecommendation(
      item: item,
      normalizedPrompt: normalizedPrompt,
      target: target,
    );
    final followUp = _followUpForRecommendation(
      item: item,
      normalizedPrompt: normalizedPrompt,
      target: target,
    );
    final confidence = _confidenceForRecommendation(
      item,
      normalizedPrompt: normalizedPrompt,
      target: target,
    );
    final missingInfo = _missingInfoForRecommendation(
      item: item,
      normalizedPrompt: normalizedPrompt,
      target: target,
    );
    return switch (target) {
      OnyxToolTarget.clientComms => OnyxRecommendation(
        workItemId: item.id,
        target: target,
        nextMoveLabel: 'OPEN CLIENT COMMS',
        headline: 'Client Comms is the next move',
        detail:
            'Work $incident inside Client Comms for $scope. $rationale Keep the operator update scoped, factual, and ready to send without reopening extra desks.',
        summary: 'One next move is staged in Client Comms.',
        evidenceHeadline: 'Client Comms handoff sealed.',
        evidenceDetail:
            'ONYX recorded the typed triage handoff for $incident and reopened Client Comms from an evidence-ready next step. ${_evidenceContext(item, target)}',
        advisory: advisory,
        confidence: confidence,
        missingInfo: missingInfo,
        contextHighlights: contextHighlights,
        followUpLabel: followUp.label,
        followUpPrompt: followUp.prompt,
      ),
      OnyxToolTarget.reportsWorkspace => OnyxRecommendation(
        workItemId: item.id,
        target: target,
        nextMoveLabel: 'OPEN REPORTS WORKSPACE',
        headline: 'Reports Workspace is the next move',
        detail:
            'Work $incident inside Reports Workspace for $scope. $rationale Keep the incident in summary mode, preserve the verified timeline, and avoid reopening resolved response lanes.',
        summary: 'One next move is staged in Reports Workspace.',
        evidenceHeadline: 'Reports Workspace handoff sealed.',
        evidenceDetail:
            'ONYX recorded the typed triage handoff for $incident and kept the reporting lane ready from an evidence-preserving next step. ${_evidenceContext(item, target)}',
        advisory: advisory,
        confidence: confidence,
        missingInfo: missingInfo,
        contextHighlights: contextHighlights,
        followUpLabel: followUp.label,
        followUpPrompt: followUp.prompt,
        allowRouteExecution: false,
      ),
      OnyxToolTarget.cctvReview => OnyxRecommendation(
        workItemId: item.id,
        target: target,
        nextMoveLabel: 'OPEN CCTV REVIEW',
        headline: 'CCTV Review is the next move',
        detail:
            'Work $incident inside CCTV Review for $scope. $rationale Confirm the visual context first so the next controller decision stays tied to real evidence.',
        summary: 'One next move is staged in CCTV Review.',
        evidenceHeadline: 'CCTV Review handoff sealed.',
        evidenceDetail:
            'ONYX recorded the typed triage handoff for $incident and reopened CCTV Review from an evidence-ready next step. ${_evidenceContext(item, target)}',
        advisory: advisory,
        confidence: confidence,
        missingInfo: missingInfo,
        contextHighlights: contextHighlights,
        followUpLabel: followUp.label,
        followUpPrompt: followUp.prompt,
      ),
      OnyxToolTarget.tacticalTrack => OnyxRecommendation(
        workItemId: item.id,
        target: target,
        nextMoveLabel: 'OPEN TACTICAL TRACK',
        headline: 'Tactical Track is the next move',
        detail:
            'Work $incident inside Tactical Track for $scope. $rationale Verify route continuity, responder posture, and field timing before you widen the response.',
        summary: 'One next move is staged in Tactical Track.',
        evidenceHeadline: 'Tactical Track handoff sealed.',
        evidenceDetail:
            'ONYX recorded the typed triage handoff for $incident and reopened Tactical Track from an evidence-ready next step. ${_evidenceContext(item, target)}',
        advisory: advisory,
        confidence: confidence,
        missingInfo: missingInfo,
        contextHighlights: contextHighlights,
        followUpLabel: followUp.label,
        followUpPrompt: followUp.prompt,
      ),
      OnyxToolTarget.dispatchBoard => OnyxRecommendation(
        workItemId: item.id,
        target: target,
        nextMoveLabel: 'OPEN DISPATCH BOARD',
        headline: 'Dispatch Board is the next move',
        detail:
            'Work $incident inside Dispatch Board for $scope. $rationale It is the fastest desk for confirming ownership, timing, and the next response step without losing the active signal.',
        summary: 'One next move is staged in Dispatch Board.',
        evidenceHeadline: 'Dispatch Board handoff sealed.',
        evidenceDetail:
            'ONYX recorded the typed triage handoff for $incident and reopened Dispatch Board from an evidence-ready next step. ${_evidenceContext(item, target)}',
        advisory: advisory,
        confidence: confidence,
        missingInfo: missingInfo,
        contextHighlights: contextHighlights,
        followUpLabel: followUp.label,
        followUpPrompt: followUp.prompt,
      ),
    };
  }

  OnyxToolTarget _targetForWorkItem(
    OnyxWorkItem item,
    String normalizedPrompt,
  ) {
    if (item.hasGuardWelfareRisk) {
      return OnyxToolTarget.dispatchBoard;
    }
    if (item.hasHumanSafetySignal) {
      return OnyxToolTarget.dispatchBoard;
    }
    if (_looksLikeStatusPrompt(normalizedPrompt) &&
        _isDelayedResponse(item, normalizedPrompt)) {
      return OnyxToolTarget.dispatchBoard;
    }
    if (_looksLikeClientPressurePrompt(normalizedPrompt) &&
        !_hasVerifiedThreat(item)) {
      return OnyxToolTarget.clientComms;
    }
    if (_looksLikeFalseAlarmPattern(item, normalizedPrompt)) {
      return OnyxToolTarget.cctvReview;
    }
    if (_shouldPrioritizePendingFollowUp(item, normalizedPrompt) &&
        item.pendingFollowUpTarget != null) {
      return item.pendingFollowUpTarget!;
    }
    if (_shouldPrioritizeHighestRiskSite(item, normalizedPrompt)) {
      return OnyxToolTarget.tacticalTrack;
    }

    final scores = <OnyxToolTarget, double>{
      OnyxToolTarget.dispatchBoard: 1,
      OnyxToolTarget.tacticalTrack: 0,
      OnyxToolTarget.cctvReview: 0,
      OnyxToolTarget.clientComms: 0,
      OnyxToolTarget.reportsWorkspace: 0,
    };

    if (_looksLikeClientPrompt(normalizedPrompt)) {
      scores[OnyxToolTarget.clientComms] =
          scores[OnyxToolTarget.clientComms]! + 5;
    }
    if (_looksLikeCameraPrompt(normalizedPrompt)) {
      scores[OnyxToolTarget.cctvReview] =
          scores[OnyxToolTarget.cctvReview]! + 5;
    }
    if (_looksLikeTrackPrompt(normalizedPrompt)) {
      scores[OnyxToolTarget.tacticalTrack] =
          scores[OnyxToolTarget.tacticalTrack]! + 4;
    }
    if (_looksLikeDispatchPrompt(normalizedPrompt)) {
      scores[OnyxToolTarget.dispatchBoard] =
          scores[OnyxToolTarget.dispatchBoard]! + 2;
    }
    if (normalizedPrompt.contains('report') ||
        normalizedPrompt.contains('update') ||
        normalizedPrompt.contains('notify')) {
      scores[OnyxToolTarget.clientComms] =
          scores[OnyxToolTarget.clientComms]! + 1.5;
    }

    if (item.hasVisualSignal) {
      scores[OnyxToolTarget.cctvReview] =
          scores[OnyxToolTarget.cctvReview]! +
          ((item.latestIntelligenceRiskScore ?? 0) >= 80 ? 3.5 : 2.5);
    }
    if (item.activeDispatchCount > 0) {
      scores[OnyxToolTarget.dispatchBoard] =
          scores[OnyxToolTarget.dispatchBoard]! + 1;
    }
    if (item.dispatchesAwaitingResponseCount > 0) {
      scores[OnyxToolTarget.dispatchBoard] =
          scores[OnyxToolTarget.dispatchBoard]! + 4;
    }
    if (item.responseCount > 0) {
      scores[OnyxToolTarget.tacticalTrack] =
          scores[OnyxToolTarget.tacticalTrack]! + 4;
    }
    if (item.patrolCount > 0) {
      scores[OnyxToolTarget.tacticalTrack] =
          scores[OnyxToolTarget.tacticalTrack]! + 3;
    }
    if (item.guardCheckInCount > 0) {
      scores[OnyxToolTarget.tacticalTrack] =
          scores[OnyxToolTarget.tacticalTrack]! + 2;
    }
    if (item.latestPartnerStatusLabel.toLowerCase().contains('onsite')) {
      scores[OnyxToolTarget.tacticalTrack] =
          scores[OnyxToolTarget.tacticalTrack]! + 2.5;
    }
    if (item.closedDispatchCount > 0 && item.activeDispatchCount == 0) {
      scores[OnyxToolTarget.clientComms] =
          scores[OnyxToolTarget.clientComms]! + 2.5;
    }
    if (item.closedDispatchCount > 0 && item.responseCount > 0) {
      scores[OnyxToolTarget.clientComms] =
          scores[OnyxToolTarget.clientComms]! + 1;
    }
    if (item.latestEventLabel.toLowerCase().contains('incident closed')) {
      scores[OnyxToolTarget.clientComms] =
          scores[OnyxToolTarget.clientComms]! + 1;
    }

    var bestTarget = OnyxToolTarget.dispatchBoard;
    var bestScore = scores[bestTarget]!;
    for (final target in OnyxToolTarget.values) {
      final score = scores[target]!;
      if (score > bestScore) {
        bestTarget = target;
        bestScore = score;
      }
    }
    return bestTarget;
  }

  String _rationaleForTarget(OnyxWorkItem item, OnyxToolTarget target) {
    final normalizedPrompt = normalizeTelegramClientPromptSignalText(
      item.prompt,
    );
    final parts = <String>[];
    if (_shouldPrioritizePendingFollowUp(item, normalizedPrompt)) {
      final followUpLabel = item.pendingFollowUpLabel.trim().isEmpty
          ? 'the outstanding follow-up'
          : item.pendingFollowUpLabel.trim();
      parts.add(
        item.hasOverduePendingFollowUp
            ? '$followUpLabel is still overdue from the previous thread cycle, so ONYX is keeping the earlier desk hot until someone explicitly closes that checkpoint.'
            : '$followUpLabel is still unresolved from the previous thread cycle, so ONYX is biasing the next move toward the same desk before the trail goes cold.',
      );
    }
    switch (target) {
      case OnyxToolTarget.clientComms:
        if (_looksLikeClientPressurePrompt(normalizedPrompt) &&
            !_hasVerifiedThreat(item)) {
          parts.add(
            'The client is asking for action, but the scoped signal picture does not show a verified threat yet.',
          );
          parts.add(
            'Client Comms is the safest lane for a factual reassurance update while ONYX avoids an integrity-breaking dispatch.',
          );
          break;
        }
        if (item.closedDispatchCount > 0 && item.activeDispatchCount == 0) {
          parts.add(
            'The live context already shows verified closure, so the next move can shift into a scoped operator update.',
          );
        } else if (_looksLikeClientPrompt(normalizedPrompt)) {
          parts.add(
            'The prompt itself is asking for client-facing comms, so ONYX is keeping the handoff inside the messaging lane.',
          );
        }
        break;
      case OnyxToolTarget.reportsWorkspace:
        if (_looksLikeRecentClosure(item, normalizedPrompt)) {
          parts.add(
            'The latest scoped event is a recent closure, so ONYX is preserving the summary and reporting path instead of reopening the incident.',
          );
        }
        break;
      case OnyxToolTarget.cctvReview:
        if (_looksLikeFalseAlarmPattern(item, item.prompt.toLowerCase())) {
          parts.add(
            'The latest motion pattern matches a repeated false-alarm shape, so ONYX is holding the work in CCTV instead of widening it into escalation.',
          );
          break;
        }
        if (item.hasVisualSignal) {
          final riskText = item.latestIntelligenceRiskScore == null
              ? ''
              : ' at risk ${item.latestIntelligenceRiskScore}';
          final headline = item.latestIntelligenceHeadline.trim().isEmpty
              ? 'the latest scoped intelligence'
              : item.latestIntelligenceHeadline.trim();
          parts.add(
            'The strongest scoped signal is visual: $headline$riskText.',
          );
        } else if (_looksLikeCameraPrompt(normalizedPrompt)) {
          parts.add(
            'The prompt is asking for visual confirmation, so ONYX is biasing toward CCTV first.',
          );
        }
        break;
      case OnyxToolTarget.tacticalTrack:
        if (_shouldPrioritizeHighestRiskSite(item, normalizedPrompt)) {
          final siteLabel = item.prioritySiteLabel.trim().isEmpty
              ? 'the highest-risk site'
              : item.prioritySiteLabel.trim();
          final reason = item.prioritySiteReason.trim().isEmpty
              ? 'the strongest live risk picture'
              : item.prioritySiteReason.trim();
          parts.add(
            'Multiple sites are in scope and $siteLabel is carrying $reason, so Tactical Track is the clearest overview lane for prioritizing it without losing the rest of the estate picture.',
          );
          break;
        }
        if (item.responseCount > 0) {
          parts.add(
            'Field movement is already underway, so the live responder picture matters more than another board-level pass.',
          );
        }
        if (item.patrolCount > 0 || item.guardCheckInCount > 0) {
          parts.add(
            'Recent patrol and guard activity make Tactical Track the cleanest place to confirm posture and continuity.',
          );
        }
        break;
      case OnyxToolTarget.dispatchBoard:
        if (item.hasGuardWelfareRisk) {
          final welfareLabel = item.guardWelfareSignalLabel.trim().isEmpty
              ? 'a possible guard distress pattern'
              : item.guardWelfareSignalLabel.trim();
          parts.add(
            '$welfareLabel is active in the scoped context, so ONYX is treating this as a welfare escalation and prioritizing the dispatch lane over quieter visuals.',
          );
          break;
        }
        if (item.hasHumanSafetySignal) {
          parts.add(
            'A human safety signal is live in the scoped context, so ONYX is prioritizing the guard-side risk even if the camera picture looks quiet or contradictory.',
          );
          break;
        }
        if (_looksLikeStatusPrompt(normalizedPrompt) &&
            _isDelayedResponse(item, normalizedPrompt)) {
          parts.add(
            'Dispatch is already in flight, the ETA window has stretched without an arrival event, and ONYX is treating that as a response-delay check.',
          );
          break;
        }
        if (item.dispatchesAwaitingResponseCount > 0) {
          parts.add(
            'The dispatch stack is still waiting on ownership or response timing, so the board stays the fastest next desk.',
          );
        } else if (item.activeDispatchCount > 0) {
          parts.add(
            'There is still an active dispatch in flight, and Dispatch Board is the best place to keep timing and ownership tight.',
          );
        } else if (item.contextSummary.trim().isNotEmpty) {
          parts.add(
            'No stronger specialist signal outranked the dispatch lane, so ONYX is keeping the next move in the controller board.',
          );
        }
        break;
    }

    if (parts.isEmpty && item.contextSummary.trim().isNotEmpty) {
      parts.add(
        'Scoped context is available and has been folded into this triage.',
      );
    }
    if (parts.isEmpty) {
      parts.add(
        'No stronger scoped signal is loaded yet, so ONYX is defaulting to the safest controller desk.',
      );
    }
    return parts.join(' ');
  }

  String _evidenceContext(OnyxWorkItem item, OnyxToolTarget target) {
    final normalizedPrompt = normalizeTelegramClientPromptSignalText(
      item.prompt,
    );
    if (_shouldPrioritizePendingFollowUp(item, normalizedPrompt)) {
      final deskLabel = item.pendingFollowUpTarget == null
          ? 'the previous desk'
          : switch (item.pendingFollowUpTarget!) {
              OnyxToolTarget.dispatchBoard => 'Dispatch Board',
              OnyxToolTarget.tacticalTrack => 'Tactical Track',
              OnyxToolTarget.cctvReview => 'CCTV Review',
              OnyxToolTarget.clientComms => 'Client Comms',
              OnyxToolTarget.reportsWorkspace => 'Reports Workspace',
            };
      return 'Thread memory kept $deskLabel hot because the previous follow-up is still unresolved.';
    }
    switch (target) {
      case OnyxToolTarget.clientComms:
        if (item.closedDispatchCount > 0) {
          return 'Closure evidence is already present in the scoped context.';
        }
        break;
      case OnyxToolTarget.reportsWorkspace:
        if (_looksLikeRecentClosure(item, normalizedPrompt)) {
          return 'A recent incident closure is the strongest scoped signal, so ONYX held the handoff in the reporting lane.';
        }
        break;
      case OnyxToolTarget.cctvReview:
        if (item.latestIntelligenceHeadline.trim().isNotEmpty) {
          return 'The latest scoped intelligence was ${item.latestIntelligenceHeadline.trim()}.';
        }
        break;
      case OnyxToolTarget.tacticalTrack:
        if (_shouldPrioritizeHighestRiskSite(item, normalizedPrompt)) {
          return 'Multiple sites are loaded and ${item.prioritySiteLabel.trim().isEmpty ? 'one site is clearly outranking the rest' : '${item.prioritySiteLabel.trim()} is clearly outranking the rest'}.';
        }
        if (item.responseCount > 0 || item.patrolCount > 0) {
          return 'Live field activity is already present in the scoped context.';
        }
        break;
      case OnyxToolTarget.dispatchBoard:
        if (item.hasGuardWelfareRisk) {
          return 'A guard welfare signal is outranking quieter visual context, so ONYX kept the dispatch escalation lane hot.';
        }
        if (item.dispatchesAwaitingResponseCount > 0) {
          return 'The scoped dispatch stack still has response pressure attached.';
        }
        break;
    }
    if (item.contextSummary.trim().isEmpty) {
      return 'No richer scoped event packet was loaded, so ONYX preserved the default typed handoff.';
    }
    return 'Scoped context was folded into the typed handoff before the desk reopened.';
  }

  String _advisoryForRecommendation({
    required OnyxWorkItem item,
    required String normalizedPrompt,
    required OnyxToolTarget target,
  }) {
    if (item.hasGuardWelfareRisk) {
      return 'Possible guard distress detected.';
    }
    if (_looksLikeClientPressurePrompt(normalizedPrompt) &&
        !_hasVerifiedThreat(item)) {
      return 'No verified threat is loaded in the scoped context.';
    }
    if (item.hasHumanSafetySignal) {
      return 'Human safety signal takes priority over the visual contradiction.';
    }
    if (_shouldPrioritizePendingFollowUp(item, normalizedPrompt)) {
      return item.hasOverduePendingFollowUp
          ? 'Outstanding follow-up is overdue.'
          : 'Outstanding follow-up is still unresolved.';
    }
    if (_shouldPrioritizeHighestRiskSite(item, normalizedPrompt)) {
      final siteLabel = item.prioritySiteLabel.trim().isEmpty
          ? 'highest-risk site'
          : item.prioritySiteLabel.trim();
      return 'Prioritize $siteLabel first.';
    }
    if (_looksLikeStatusPrompt(normalizedPrompt) &&
        _isDelayedResponse(item, normalizedPrompt)) {
      return 'Response delay detected.';
    }
    if (_looksLikeRecentClosure(item, normalizedPrompt)) {
      return 'Incident resolved.';
    }
    if (_looksLikeFalseAlarmPattern(item, normalizedPrompt)) {
      return 'Repeated false pattern detected.';
    }
    if (target == OnyxToolTarget.clientComms &&
        item.closedDispatchCount > 0 &&
        item.activeDispatchCount == 0) {
      return 'Incident resolved and ready for a controlled operator update.';
    }
    if (target == OnyxToolTarget.cctvReview && item.hasVisualSignal) {
      return 'Visual evidence is still the strongest grounded signal.';
    }
    if (target == OnyxToolTarget.tacticalTrack && item.responseCount > 0) {
      return 'Live field posture is already the strongest next read.';
    }
    if (target == OnyxToolTarget.dispatchBoard &&
        item.dispatchesAwaitingResponseCount > 0) {
      return 'Response timing pressure is still active.';
    }
    return 'Scoped context is driving the next operator move.';
  }

  List<String> _contextHighlightsForRecommendation({
    required OnyxWorkItem item,
    required String normalizedPrompt,
    required OnyxToolTarget target,
  }) {
    final highlights = <String>[];
    if (_shouldPrioritizePendingFollowUp(item, normalizedPrompt)) {
      highlights.add('Outstanding follow-up: ${item.pendingFollowUpLabel}');
      highlights.add(
        'Follow-up age: ${item.pendingFollowUpAgeMinutes} minutes'
        '${item.staleFollowUpSurfaceCount > 0 ? ' • reopen cycles ${item.staleFollowUpSurfaceCount}' : ''}',
      );
    }
    if (_shouldPrioritizeHighestRiskSite(item, normalizedPrompt) &&
        item.rankedSiteSummaries.isNotEmpty) {
      highlights.addAll(item.rankedSiteSummaries.take(3));
    }
    if (target == OnyxToolTarget.dispatchBoard &&
        _isDelayedResponse(item, normalizedPrompt) &&
        item.latestDispatchCreatedAt != null) {
      final elapsed = item.createdAt.difference(item.latestDispatchCreatedAt!);
      highlights.add(
        'Dispatch wait window: ${elapsed.inMinutes} minutes since the last dispatch was created.',
      );
    }
    if (item.hasGuardWelfareRisk &&
        item.guardWelfareSignalLabel.trim().isNotEmpty) {
      highlights.add(item.guardWelfareSignalLabel.trim());
    }
    return highlights;
  }

  ({String label, String prompt}) _followUpForRecommendation({
    required OnyxWorkItem item,
    required String normalizedPrompt,
    required OnyxToolTarget target,
  }) {
    final incident = item.incidentReference.trim();
    final scope = item.scopeLabel;
    if (_shouldPrioritizePendingFollowUp(item, normalizedPrompt)) {
      return (
        label: item.pendingFollowUpLabel.trim(),
        prompt: item.pendingFollowUpPrompt.trim(),
      );
    }
    if (target == OnyxToolTarget.dispatchBoard &&
        _isDelayedResponse(item, normalizedPrompt)) {
      final incidentLabel = incident.isEmpty ? scope : incident;
      return (
        label: 'RECHECK RESPONDER ETA',
        prompt:
            'Status? Recheck the delayed response for $incidentLabel. Confirm the current responder ETA and the latest dispatch-partner acknowledgment.',
      );
    }
    if (item.hasGuardWelfareRisk) {
      final incidentLabel = incident.isEmpty ? scope : incident;
      return (
        label: 'VERIFY GUARD WELFARE',
        prompt:
            'Status guard? Follow up on guard welfare for $incidentLabel. Confirm guard voice contact, nearest responder acknowledgment, and a fresh wearable telemetry sample.',
      );
    }
    if (_shouldPrioritizeHighestRiskSite(item, normalizedPrompt) &&
        item.prioritySiteLabel.trim().isNotEmpty) {
      final prioritySite = item.prioritySiteLabel.trim();
      return (
        label: 'RECHECK LOWER-PRIORITY SITES',
        prompt:
            'What\'s happening across sites? Recheck the lower-priority sites after prioritizing $prioritySite. Confirm that they remain stable and note any new signal changes.',
      );
    }
    return (label: '', prompt: '');
  }

  double _confidenceForRecommendation(
    OnyxWorkItem item, {
    required String normalizedPrompt,
    required OnyxToolTarget target,
    bool allowRouteExecution = true,
  }) {
    if (!allowRouteExecution) {
      if (_looksLikeThreatQuery(normalizedPrompt) &&
          !_hasAnyOperationalSignal(item)) {
        return 0.24;
      }
      return 0.31;
    }
    if (item.hasGuardWelfareRisk) {
      return 0.89;
    }
    if (item.hasHumanSafetySignal) {
      return 0.91;
    }
    if (_shouldPrioritizePendingFollowUp(item, normalizedPrompt)) {
      return item.hasOverduePendingFollowUp ? 0.87 : 0.81;
    }
    if (_looksLikeClientPressurePrompt(normalizedPrompt) &&
        !_hasVerifiedThreat(item)) {
      return 0.81;
    }
    if (_shouldPrioritizeHighestRiskSite(item, normalizedPrompt)) {
      return (item.prioritySiteRiskScore ?? 0) >= 80 ? 0.86 : 0.8;
    }
    if (_looksLikeFalseAlarmPattern(item, normalizedPrompt)) {
      return 0.78;
    }
    if (_looksLikeRecentClosure(item, normalizedPrompt)) {
      return 0.88;
    }
    return switch (target) {
      OnyxToolTarget.dispatchBoard =>
        _isDelayedResponse(item, normalizedPrompt)
            ? 0.86
            : item.dispatchesAwaitingResponseCount > 0
            ? 0.84
            : 0.68,
      OnyxToolTarget.tacticalTrack =>
        item.responseCount > 0 || item.patrolCount > 0 ? 0.83 : 0.72,
      OnyxToolTarget.cctvReview => item.hasVisualSignal ? 0.8 : 0.71,
      OnyxToolTarget.clientComms => item.closedDispatchCount > 0 ? 0.79 : 0.74,
      OnyxToolTarget.reportsWorkspace => 0.82,
    };
  }

  List<String> _missingInfoForRecommendation({
    required OnyxWorkItem item,
    required String normalizedPrompt,
    required OnyxToolTarget target,
  }) {
    if (_shouldPrioritizePendingFollowUp(item, normalizedPrompt) &&
        item.pendingConfirmations.isNotEmpty) {
      return List<String>.from(item.pendingConfirmations);
    }
    if (item.hasGuardWelfareRisk) {
      return const <String>[
        'guard voice confirmation',
        'nearest responder welfare acknowledgment',
        'fresh wearable telemetry sample',
      ];
    }
    if (_looksLikeClientPressurePrompt(normalizedPrompt) &&
        !_hasVerifiedThreat(item)) {
      return const <String>[
        'verified threat signal',
        'camera or guard evidence for dispatch',
      ];
    }
    if (_shouldPrioritizeHighestRiskSite(item, normalizedPrompt)) {
      return const <String>['fresh confirmation from lower-priority sites'];
    }
    if (_looksLikeFalseAlarmPattern(item, normalizedPrompt)) {
      return const <String>['fresh human confirmation if the scene changes'];
    }
    if (item.hasHumanSafetySignal && !item.hasVisualSignal) {
      return const <String>[
        'guard voice or welfare confirmation',
        'closest responder acknowledgment',
      ];
    }
    if (_isDelayedResponse(item, normalizedPrompt)) {
      return const <String>[
        'current responder ETA',
        'follow-up acknowledgment from dispatch partner',
      ];
    }
    if (_looksLikeRecentClosure(item, normalizedPrompt)) {
      return const <String>['final client-facing closure note'];
    }
    return const <String>[];
  }

  bool _shouldHoldForClarification(OnyxWorkItem item, String normalizedPrompt) {
    if (_looksLikeVaguePrompt(normalizedPrompt)) {
      return true;
    }
    return _looksLikeThreatQuery(normalizedPrompt) &&
        !_hasAnyOperationalSignal(item);
  }

  String _clarificationAdvisory(OnyxWorkItem item, String normalizedPrompt) {
    if (_looksLikeThreatQuery(normalizedPrompt) &&
        !_hasAnyOperationalSignal(item)) {
      return 'No signals detected for that threat in the current scoped context.';
    }
    return 'Clarify the request before ONYX assumes an incident, desk, or threat type.';
  }

  List<String> _missingInfoForClarification(String normalizedPrompt) {
    if (_looksLikeThreatQuery(normalizedPrompt)) {
      return const <String>[
        'site or incident reference',
        'signal source to verify',
      ];
    }
    return const <String>[
      'which incident, site, or device you mean',
      'what outcome you want checked',
    ];
  }

  bool _hasVerifiedThreat(OnyxWorkItem item) {
    if (item.hasHumanSafetySignal || item.hasGuardWelfareRisk) {
      return true;
    }
    if (item.dispatchesAwaitingResponseCount > 0 ||
        item.activeDispatchCount > 0 ||
        item.responseCount > 0) {
      return true;
    }
    if (item.hasVisualSignal && (item.latestIntelligenceRiskScore ?? 0) >= 70) {
      return true;
    }
    return false;
  }

  bool _hasAnyOperationalSignal(OnyxWorkItem item) {
    return item.totalScopedEvents > 0 ||
        item.activeDispatchCount > 0 ||
        item.dispatchesAwaitingResponseCount > 0 ||
        item.responseCount > 0 ||
        item.closedDispatchCount > 0 ||
        item.patrolCount > 0 ||
        item.guardCheckInCount > 0 ||
        item.hasVisualSignal ||
        item.hasHumanSafetySignal ||
        item.hasGuardWelfareRisk;
  }

  bool _shouldPrioritizeHighestRiskSite(
    OnyxWorkItem item,
    String normalizedPrompt,
  ) {
    return _looksLikeCrossSitePrompt(normalizedPrompt) &&
        item.scopedSiteCount > 1 &&
        item.prioritySiteLabel.trim().isNotEmpty;
  }

  bool _shouldPrioritizePendingFollowUp(
    OnyxWorkItem item,
    String normalizedPrompt,
  ) {
    if (!item.hasPendingFollowUp || item.pendingFollowUpTarget == null) {
      return false;
    }
    final isGenericNextStepPrompt =
        _looksLikeStatusPrompt(normalizedPrompt) ||
        normalizedPrompt.contains('what should i do') ||
        normalizedPrompt.contains('where do i go next') ||
        normalizedPrompt.contains('next move');
    if (!isGenericNextStepPrompt) {
      return false;
    }
    return item.hasUnresolvedPendingFollowUp;
  }

  bool _looksLikeClientPressurePrompt(String normalizedPrompt) {
    return normalizedPrompt.contains('client wants') ||
        normalizedPrompt.contains('client says') ||
        normalizedPrompt.contains('client is asking') ||
        normalizedPrompt.contains('immediate dispatch');
  }

  bool _looksLikeFalseAlarmPattern(OnyxWorkItem item, String normalizedPrompt) {
    if (item.repeatedFalseAlarmCount < 3 || !item.hasVisualSignal) {
      return false;
    }
    final headline = item.latestIntelligenceHeadline.toLowerCase();
    return normalizedPrompt.contains('breach') &&
        (headline.contains('tree') ||
            headline.contains('noise') ||
            headline.contains('foliage') ||
            headline.contains('wind') ||
            headline.contains('animal'));
  }

  bool _looksLikeVaguePrompt(String normalizedPrompt) {
    final trimmed = normalizedPrompt.trim();
    return trimmed == 'check that thing' ||
        trimmed == 'check that' ||
        trimmed == 'look into that' ||
        trimmed == 'what about that' ||
        trimmed == 'handle that';
  }

  bool _looksLikeThreatQuery(String normalizedPrompt) {
    if (asksForTelegramClientBroadStatusOrCurrentSiteView(normalizedPrompt)) {
      return false;
    }
    return normalizedPrompt.contains('is there a fire') ||
        normalizedPrompt.contains('is this a breach') ||
        normalizedPrompt.contains('is there a breach') ||
        normalizedPrompt.contains('any breaches') ||
        normalizedPrompt.contains('what is happening');
  }

  bool _looksLikeStatusPrompt(String normalizedPrompt) {
    return normalizedPrompt == 'status?' ||
        normalizedPrompt == 'status' ||
        normalizedPrompt.contains('status?') ||
        normalizedPrompt.contains('status guard') ||
        normalizedPrompt.contains('what is the status') ||
        asksForTelegramClientBroadStatusOrCurrentSiteView(normalizedPrompt) ||
        asksForTelegramClientCurrentSiteIssueCheck(normalizedPrompt) ||
        asksForTelegramClientMovementCheck(normalizedPrompt);
  }

  bool _isDelayedResponse(OnyxWorkItem item, String normalizedPrompt) {
    if (!_looksLikeStatusPrompt(normalizedPrompt)) {
      return false;
    }
    if (item.dispatchesAwaitingResponseCount <= 0 ||
        (item.latestDispatchCreatedAt ?? item.latestEventAt) == null) {
      return false;
    }
    final age = item.createdAt.difference(
      item.latestDispatchCreatedAt ?? item.latestEventAt!,
    );
    return age >= const Duration(minutes: 12);
  }

  bool _looksLikeRecentClosure(OnyxWorkItem item, String normalizedPrompt) {
    if (!_looksLikeStatusPrompt(normalizedPrompt) ||
        item.closedDispatchCount <= 0 ||
        item.activeDispatchCount > 0 ||
        (item.latestClosureAt ?? item.latestEventAt) == null) {
      return false;
    }
    if (item.latestEventLabel.toLowerCase() != 'incident closed') {
      return false;
    }
    final age = item.createdAt.difference(
      item.latestClosureAt ?? item.latestEventAt!,
    );
    return age <= const Duration(minutes: 5);
  }

  bool _looksLikeClientPrompt(String normalizedPrompt) {
    return normalizedPrompt.contains('client') ||
        normalizedPrompt.contains('reply') ||
        normalizedPrompt.contains('message') ||
        normalizedPrompt.contains('telegram') ||
        normalizedPrompt.contains('resident') ||
        normalizedPrompt.contains('comms');
  }

  bool _looksLikeCameraPrompt(String normalizedPrompt) {
    return normalizedPrompt.contains('camera') ||
        normalizedPrompt.contains('cctv') ||
        normalizedPrompt.contains('video') ||
        normalizedPrompt.contains('visual') ||
        normalizedPrompt.contains('feed');
  }

  bool _looksLikeTrackPrompt(String normalizedPrompt) {
    return normalizedPrompt.contains('track') ||
        normalizedPrompt.contains('telemetry') ||
        normalizedPrompt.contains('patrol') ||
        normalizedPrompt.contains('route') ||
        normalizedPrompt.contains('across sites') ||
        normalizedPrompt.contains('overview') ||
        normalizedPrompt.contains('heart rate') ||
        normalizedPrompt.contains('no movement') ||
        normalizedPrompt.contains('guard');
  }

  bool _looksLikeCrossSitePrompt(String normalizedPrompt) {
    return normalizedPrompt.contains('across sites') ||
        normalizedPrompt.contains('all sites') ||
        normalizedPrompt.contains('across the sites') ||
        normalizedPrompt.contains('estate-wide') ||
        normalizedPrompt.contains('overview');
  }

  bool _looksLikeDispatchPrompt(String normalizedPrompt) {
    return normalizedPrompt.contains('dispatch') ||
        normalizedPrompt.contains('alarm') ||
        normalizedPrompt.contains('incident') ||
        normalizedPrompt.contains('response') ||
        normalizedPrompt.contains('owner') ||
        normalizedPrompt.contains('ownership');
  }
}
