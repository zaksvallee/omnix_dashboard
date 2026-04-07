part of 'telegram_ai_assistant_service.dart';

String? _currentFrameMovementClarifierReply({
  required String normalizedMessage,
  required List<String> recentConversationTurns,
  required ClientCameraHealthFactPacket? cameraHealthFactPacket,
}) {
  final asksMovementCheck = _asksForCurrentFrameMovementCheck(
    normalizedMessage,
  );
  final asksPersonConfirmation = _asksForCurrentFramePersonConfirmation(
    normalizedMessage,
  );
  final asksSemanticMovementIdentification =
      _asksForSemanticMovementIdentification(normalizedMessage);
  final challengesMissedDetection = _challengesMissedMovementDetection(
    normalizedMessage,
    recentConversationTurns,
  );
  if (!asksMovementCheck &&
      !asksPersonConfirmation &&
      !asksSemanticMovementIdentification &&
      !challengesMissedDetection) {
    return null;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  final hasMotionTelemetry = _hasRecentMotionTelemetryContext(joined);
  final hasCurrentFrameContext = _hasCurrentFrameConversationContext(
    joined,
    cameraHealthFactPacket: cameraHealthFactPacket,
  );
  if (asksSemanticMovementIdentification) {
    return null;
  }
  if (!hasMotionTelemetry && !hasCurrentFrameContext) {
    return null;
  }
  if (hasMotionTelemetry) {
    final motionLabel = _recentMotionTelemetryLeadLabel(joined);
    if (challengesMissedDetection) {
      return 'ONYX did receive $motionLabel. It would be wrong to say nothing was picked up. What I cannot confirm from the current frame alone is who or what triggered those alerts.';
    }
    final areaLabel = _currentFrameConfirmationAreaLabel(normalizedMessage);
    if (areaLabel != null) {
      return 'ONYX did receive $motionLabel. What I cannot confirm from the current frame alone is whether that was a person in the $areaLabel.';
    }
    return 'ONYX did receive $motionLabel. What I cannot confirm from the current frame alone is who or what triggered those alerts.';
  }
  final areaLabel = _currentFrameConfirmationAreaLabel(normalizedMessage);
  if (areaLabel != null) {
    return 'Not confirmed from the current frame alone. I cannot confirm a person in the $areaLabel from a single image.';
  }
  return 'Not confirmed from the current frame alone. I cannot confirm movement from a single image.';
}

String? _semanticMovementIdentificationReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required ClientCameraHealthFactPacket? cameraHealthFactPacket,
}) {
  final packet = cameraHealthFactPacket;
  if (packet == null ||
      !_asksForSemanticMovementIdentification(normalizedMessage)) {
    return null;
  }
  final semanticActivity = _semanticActivityLabel(packet);
  final hotspot =
      packet.liveSiteMovementHotspotLabel ??
      packet.recentMovementHotspotLabel ??
      scope.siteReference;
  if (packet.hasOngoingContinuousVisualChange ||
      packet.liveSiteMovementStatus == ClientLiveSiteMovementStatus.active ||
      packet.liveSiteMovementStatus ==
          ClientLiveSiteMovementStatus.recentSignals) {
    if (semanticActivity == 'recent person activity' ||
        semanticActivity == 'recent vehicle activity') {
      return 'I am seeing $semanticActivity near $hotspot.';
    }
    return 'I am seeing activity near $hotspot, but I do not yet have a confirmed person or vehicle identification.';
  }
  if (packet.hasContinuousVisualCoverage) {
    return 'I am not seeing confirmed person or vehicle activity on site at ${scope.siteReference} right now.';
  }
  return 'I do not have confirmed person or vehicle activity on site at ${scope.siteReference} right now. ${_movementVisibilityBoundary(packet: packet, scope: scope)}';
}

String? _continuousVisualWatchMovementReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required List<String> recentConversationTurns,
  required ClientCameraHealthFactPacket? cameraHealthFactPacket,
}) {
  final packet = cameraHealthFactPacket;
  if (packet == null || !packet.hasOngoingContinuousVisualChange) {
    return null;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  final asksMovementCheck = _asksForCurrentFrameMovementCheck(
    normalizedMessage,
  );
  final asksPersonConfirmation = _asksForCurrentFramePersonConfirmation(
    normalizedMessage,
  );
  final genericStatusFollowUp =
      _isGenericStatusFollowUp(normalizedMessage) &&
      _hasRecentContinuousVisualActivityContext(joined);
  if (!asksMovementCheck && !asksPersonConfirmation && !genericStatusFollowUp) {
    return null;
  }
  if (_hasCurrentFrameConversationContext(
        joined,
        cameraHealthFactPacket: cameraHealthFactPacket,
      ) ||
      _hasRecentMotionTelemetryContext(joined)) {
    return null;
  }
  final hotspot = packet.continuousVisualHotspotLabel ?? scope.siteReference;
  final lead = packet.hasActiveContinuousVisualChange
      ? 'I am seeing live activity around $hotspot right now.'
      : 'I am seeing activity around $hotspot right now.';
  final boundary = _activeSceneChangeBoundary(packet);
  if (genericStatusFollowUp) {
    return 'Update: ${lead.substring(0, 1).toLowerCase()}${lead.substring(1)} $boundary';
  }
  return '$lead $boundary';
}

String _activeSceneChangeBoundary(ClientCameraHealthFactPacket packet) {
  final normalizedLabel = (packet.recentMovementObjectLabel ?? '')
      .trim()
      .toLowerCase();
  if (normalizedLabel == 'firearm' ||
      normalizedLabel == 'weapon' ||
      normalizedLabel == 'knife') {
    final threatLabel =
        _semanticActivityLabel(packet) ?? 'recent threat activity';
    return 'That means something active is happening there, and the latest detections are consistent with $threatLabel. Treat that as a potential threat until it is disproved.';
  }
  final semanticActivity = _semanticActivityLabel(packet);
  if (semanticActivity != null) {
    return 'That means something active is happening there, and the latest detections are consistent with $semanticActivity, but I cannot confirm from this signal alone whether this is a breach.';
  }
  return 'That means something active is happening there, but I cannot confirm from this signal alone whether it is a person, vehicle, or breach.';
}

String? _semanticActivityLabel(ClientCameraHealthFactPacket packet) {
  return switch ((packet.recentMovementObjectLabel ?? '')
      .trim()
      .toLowerCase()) {
    'person' => 'recent person activity',
    'vehicle' => 'recent vehicle activity',
    'animal' => 'recent animal activity',
    'backpack' => 'a recently detected backpack',
    'bag' => 'a recently detected bag',
    'knife' => 'recent knife activity',
    'weapon' => 'recent weapon activity',
    'firearm' => 'recent firearm activity',
    _ => null,
  };
}

String _recentMovementSignalsLead({
  required ClientCameraHealthFactPacket packet,
  required _TelegramAiScopeProfile scope,
}) {
  final signalLabel = (packet.recentMovementSignalLabel ?? '').trim();
  if (signalLabel.isEmpty) {
    return 'I am seeing recent activity at ${scope.siteReference}.';
  }
  if (signalLabel.contains('on site')) {
    return 'I am seeing $signalLabel.';
  }
  return 'I am seeing $signalLabel at ${scope.siteReference}.';
}

String _recentSiteIssueSignalsLead({
  required ClientCameraHealthFactPacket packet,
  required _TelegramAiScopeProfile scope,
}) {
  final signalLabel =
      (packet.recentIssueSignalLabel ?? packet.recentMovementSignalLabel ?? '')
          .trim();
  if (signalLabel.isEmpty) {
    return 'I am seeing recent activity at ${scope.siteReference}.';
  }
  if (signalLabel.contains('on site')) {
    return 'I am seeing $signalLabel.';
  }
  return 'I am seeing $signalLabel at ${scope.siteReference}.';
}

String _movementVisibilityBoundary({
  required ClientCameraHealthFactPacket packet,
  required _TelegramAiScopeProfile scope,
}) {
  if (packet.status == ClientCameraHealthStatus.live) {
    if (packet.path == ClientCameraHealthPath.legacyLocalProxy ||
        packet.reason == ClientCameraHealthReason.legacyProxyActive) {
      return 'We still have some visual coverage at ${scope.siteReference}, but I do not have a fresh movement confirmation to share right now.';
    }
    return 'I do not have a fresh movement confirmation to share right now.';
  }
  if (packet.status == ClientCameraHealthStatus.limited) {
    return 'Live camera visibility is limited right now, so I cannot verify movement visually at this moment.';
  }
  return 'Live camera visibility is unavailable right now, so I cannot verify movement visually at this moment.';
}

String _siteVisibilityBoundary({
  required ClientCameraHealthFactPacket packet,
  required _TelegramAiScopeProfile scope,
}) {
  if (packet.status == ClientCameraHealthStatus.live) {
    if (packet.path == ClientCameraHealthPath.legacyLocalProxy ||
        packet.reason == ClientCameraHealthReason.legacyProxyActive) {
      return 'We still have some visual coverage at ${scope.siteReference}, but I do not want to overstate the full picture from that alone.';
    }
    return 'I do not want to overstate the full picture beyond the signals I can verify right now.';
  }
  if (packet.status == ClientCameraHealthStatus.limited) {
    return 'Live camera visibility is limited right now, so I cannot verify the whole site visually at this moment.';
  }
  return 'Live camera visibility is unavailable right now, so I cannot verify the whole site visually at this moment.';
}

ClientLiveSiteIssueStatus _effectiveLiveSiteIssueStatus(
  ClientCameraHealthFactPacket packet,
) {
  if (packet.liveSiteIssueStatus != ClientLiveSiteIssueStatus.unknown) {
    return packet.liveSiteIssueStatus;
  }
  if (packet.hasOngoingContinuousVisualChange ||
      packet.liveSiteMovementStatus == ClientLiveSiteMovementStatus.active) {
    return ClientLiveSiteIssueStatus.activeSignals;
  }
  if (packet.liveSiteMovementStatus ==
      ClientLiveSiteMovementStatus.recentSignals) {
    return ClientLiveSiteIssueStatus.recentSignals;
  }
  if (packet.hasContinuousVisualCoverage || packet.hasNoConfirmedMovement) {
    return ClientLiveSiteIssueStatus.noConfirmedIssue;
  }
  return ClientLiveSiteIssueStatus.unknown;
}

String? _siteMovementStatusClarifierReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required List<String> recentConversationTurns,
  required ClientCameraHealthFactPacket? cameraHealthFactPacket,
}) {
  final packet = cameraHealthFactPacket;
  if (packet == null || !_asksForCurrentFrameMovementCheck(normalizedMessage)) {
    return null;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  final hasCurrentFrameContext = _hasCurrentFrameConversationContext(
    joined,
    cameraHealthFactPacket: cameraHealthFactPacket,
  );
  final hasMotionTelemetry = _hasRecentMotionTelemetryContext(joined);
  if (hasCurrentFrameContext || hasMotionTelemetry) {
    return null;
  }
  if (packet.liveSiteMovementStatus ==
      ClientLiveSiteMovementStatus.recentSignals) {
    return '${_recentMovementSignalsLead(packet: packet, scope: scope)} That means activity was picked up on site, but I still cannot confirm from the current view who or what is moving right now.';
  }
  if (packet.hasContinuousVisualCoverage) {
    return 'I am not seeing active movement on site at ${scope.siteReference} right now. That does not by itself prove the site is clear, and I do not have a fresh movement confirmation to share right now.';
  }
  final downCameraLabel = _recentThreadDownCameraLabel(recentConversationTurns);
  final recentUnusableCurrentImage = _recentThreadShowsUnusableCurrentImage(
    recentConversationTurns,
  );
  if (packet.status == ClientCameraHealthStatus.live) {
    if (recentUnusableCurrentImage) {
      return 'I do not have a usable current image to confirm movement from right now.';
    }
    if (downCameraLabel != null) {
      return '$downCameraLabel is down, but we still have some visual coverage at ${scope.siteReference}. I do not have a fresh movement confirmation to share right now.';
    }
    final lastVisualTimeLabel = _telegramCameraFactTimeLabel(
      packet.lastSuccessfulVisualAtUtc,
    );
    if (lastVisualTimeLabel != null) {
      return 'We currently have visual confirmation at ${scope.siteReference}. The last successful visual confirmation in ONYX was at $lastVisualTimeLabel, but I do not have a fresh movement confirmation to share right now.';
    }
    return 'We currently have visual confirmation at ${scope.siteReference}, but I do not have a fresh movement confirmation to share right now.';
  }
  return 'I do not have confirmed movement on site at ${scope.siteReference} from the current signals I can see right now. ${_movementVisibilityBoundary(packet: packet, scope: scope)}';
}

String? _siteIssueStatusClarifierReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required List<String> recentConversationTurns,
  required ClientCameraHealthFactPacket? cameraHealthFactPacket,
}) {
  final packet = cameraHealthFactPacket;
  if (packet == null || !_asksForCurrentSiteIssueCheck(normalizedMessage)) {
    return null;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  final effectiveIssueStatus = _effectiveLiveSiteIssueStatus(packet);
  if ((effectiveIssueStatus == ClientLiveSiteIssueStatus.noConfirmedIssue ||
          effectiveIssueStatus == ClientLiveSiteIssueStatus.unknown) &&
      (_hasRecentPresenceVerificationContext(joined) ||
          _hasTelemetrySummaryContext(joined))) {
    return null;
  }
  switch (effectiveIssueStatus) {
    case ClientLiveSiteIssueStatus.activeSignals:
      final hotspot =
          packet.liveSiteMovementHotspotLabel ?? scope.siteReference;
      return 'I am seeing live activity around $hotspot right now. ${_activeSceneChangeBoundary(packet)}';
    case ClientLiveSiteIssueStatus.recentSignals:
      return '${_recentSiteIssueSignalsLead(packet: packet, scope: scope)} That means a recent site signal was picked up, but I do not yet have a confirmed active issue from the current view alone.';
    case ClientLiveSiteIssueStatus.noConfirmedIssue:
      if (packet.hasContinuousVisualCoverage) {
        return 'I am not seeing active movement on site at ${scope.siteReference} right now. That does not by itself prove the site is clear, but nothing in the current signals confirms an active issue on site.';
      }
      return 'I do not have a confirmed active issue on site at ${scope.siteReference} from the current signals I can see right now. ${_siteVisibilityBoundary(packet: packet, scope: scope)}';
    case ClientLiveSiteIssueStatus.unknown:
      return 'I do not have a confirmed active issue on site at ${scope.siteReference} from the current signals I can see right now. ${_siteVisibilityBoundary(packet: packet, scope: scope)}';
  }
}

String? _presenceVerificationReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required TelegramAiDeliveryMode deliveryMode,
  required List<String> recentConversationTurns,
  required _PreferredReplyStyle preferredReplyStyle,
  required _ClientProfile clientProfile,
  required bool escalatedLane,
  required bool pressuredLane,
}) {
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  final telemetrySummaryVisible = _hasTelemetrySummaryContext(joined);
  final telemetryPresenceChallenge = _challengesTelemetryPresenceSummary(
    normalizedMessage,
  );
  final presenceFollowUp =
      _isGenericStatusFollowUp(normalizedMessage) &&
      _hasRecentPresenceVerificationContext(joined);
  if (!telemetryPresenceChallenge && !presenceFollowUp) {
    return null;
  }
  final verificationClosing = _clientFollowUpClosing(
    recentConversationTurns,
    mode: _FollowUpMode.step,
    deliveryMode: deliveryMode,
    preferredReplyStyle: preferredReplyStyle,
    clientProfile: clientProfile,
    escalated: escalatedLane,
    compressed: pressuredLane,
  );
  final explicitOnSitePresence = _hasExplicitCurrentOnSitePresence(joined);
  final explicitMovementConfirmation = _hasExplicitCurrentMovementConfirmation(
    joined,
  );
  if (explicitOnSitePresence) {
    return 'Update: A guard is confirmed on site at ${scope.siteReference}. ${_clientFollowUpClosing(recentConversationTurns, mode: _FollowUpMode.onsite, deliveryMode: deliveryMode, preferredReplyStyle: preferredReplyStyle, clientProfile: clientProfile, escalated: escalatedLane, compressed: pressuredLane)}';
  }
  if (explicitMovementConfirmation) {
    return 'Update: A response movement is confirmed toward ${scope.siteReference}, but I do not yet have a guard confirmed on site. $verificationClosing';
  }
  if (telemetryPresenceChallenge) {
    if (telemetrySummaryVisible) {
      return 'Understood. That earlier summary refers to recorded ONYX telemetry activity, not confirmed guards physically on site now. I do not have a confirmed guard on site at ${scope.siteReference} from that summary alone. If you want, I can verify the current response position and $verificationClosing';
    }
    return 'Understood. I do not have a confirmed guard on site at ${scope.siteReference} from the scoped record I can see right now. If you want, I can verify the current response position and $verificationClosing';
  }
  return 'Update: No guard is confirmed on site at ${scope.siteReference} yet from the scoped record I can see. I am waiting on a verified position update and will send that here as soon as it is confirmed.';
}

String? _cameraCoverageCorrectionReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required List<String> recentConversationTurns,
  required ClientCameraHealthFactPacket? cameraHealthFactPacket,
}) {
  final looksLikeCoverageCountCorrection =
      RegExp(r'\b\d+\s+cameras?\b').hasMatch(normalizedMessage) &&
      _containsAny(normalizedMessage, const ['in total', 'that leaves']);
  if (!looksLikeCoverageCountCorrection) {
    return null;
  }
  final downCameraLabel = _recentThreadDownCameraLabel(recentConversationTurns);
  if (downCameraLabel == null) {
    return null;
  }
  final packet = cameraHealthFactPacket;
  final bridgeLine =
      packet != null &&
          (packet.path == ClientCameraHealthPath.legacyLocalProxy ||
              packet.reason == ClientCameraHealthReason.legacyProxyActive)
      ? 'We still have some visual coverage at ${scope.siteReference}, but '
      : '';
  return 'You are right. ${bridgeLine.isEmpty ? '' : bridgeLine}$downCameraLabel is down. I do not want to overstate full-site visual coverage from camera counts alone.';
}

String? _currentSiteViewClarifierReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required List<String> recentConversationTurns,
  required ClientCameraHealthFactPacket? cameraHealthFactPacket,
}) {
  final packet = cameraHealthFactPacket;
  if (packet == null ||
      !asksForTelegramClientBroadStatusOrCurrentSiteView(normalizedMessage)) {
    return null;
  }
  final joinedContext = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  final guardOnSite = _hasExplicitCurrentOnSitePresence(joinedContext);
  final nextStepQuestion = guardOnSite
      ? 'Want me to check anything specific?'
      : 'Want me to flag your guard for a check?';
  final effectiveIssueStatus = _effectiveLiveSiteIssueStatus(packet);
  if (effectiveIssueStatus == ClientLiveSiteIssueStatus.activeSignals) {
    final hotspot = packet.continuousVisualHotspotLabel ?? scope.siteReference;
    return 'There is activity around $hotspot right now. It could still be routine, but I am checking it now.';
  }
  if (effectiveIssueStatus == ClientLiveSiteIssueStatus.recentSignals) {
    return 'Something was picked up at ${scope.siteReference} recently. It could be nothing, but I am checking the latest signals now.';
  }
  final downCameraLabel = _recentThreadDownCameraLabel(recentConversationTurns);
  final recentUnusableCurrentImage = _recentThreadShowsUnusableCurrentImage(
    recentConversationTurns,
  );
  if (recentUnusableCurrentImage) {
    return 'Remote monitoring is limited right now, so I do not want to overstate what I can see from here. $nextStepQuestion';
  }
  if (effectiveIssueStatus == ClientLiveSiteIssueStatus.noConfirmedIssue &&
      packet.hasContinuousVisualCoverage) {
    return 'Based on what I can see, there are no active alerts at ${scope.siteReference}. Monitoring looks normal right now. $nextStepQuestion';
  }
  if (downCameraLabel != null &&
      packet.status == ClientCameraHealthStatus.live) {
    return '$downCameraLabel is down, so remote monitoring is limited right now. I still have some coverage at ${scope.siteReference}. $nextStepQuestion';
  }
  if (packet.status == ClientCameraHealthStatus.live) {
    return 'Based on what I can see, there are no active alerts at ${scope.siteReference}. Monitoring looks normal right now. $nextStepQuestion';
  }
  if (packet.status == ClientCameraHealthStatus.limited) {
    return 'Based on what I can see, there are no active alerts at ${scope.siteReference}. My visual monitoring is limited right now. $nextStepQuestion';
  }
  return 'Based on what I can see, there are no active alerts at ${scope.siteReference}. I do not have live visual right now but I am monitoring all signals. $nextStepQuestion';
}
