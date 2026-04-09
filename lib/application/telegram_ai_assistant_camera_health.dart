part of 'telegram_ai_assistant_service.dart';

String? _cameraStatusClarifierReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required List<String> recentConversationTurns,
  required TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
}) {
  final asksCameraCheck = _containsAny(normalizedMessage, const [
    'did you check cameras',
    'did you check the cameras',
    'did you check camera',
    'camera check',
    'check cameras',
  ]);
  if (!asksCameraCheck) {
    return null;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  final remoteMonitoringOffline = _containsAny(joined, const [
    'temporarily without remote monitoring',
    'remote watch is temporarily unavailable',
    'remote monitoring is offline',
    'offline for this site',
    'monitoring path is offline',
  ]);
  final telemetrySummaryVisible = _containsAny(joined, const [
    'site activity summary',
    'field telemetry',
    'latest field signal:',
    'guard or response-team activity signals were logged through onyx field telemetry',
    'guard or response-team activity signal was logged through onyx field telemetry',
  ]);
  final noOpenIncident = _containsAny(joined, const [
    'not sitting as an open incident',
    'open follow-ups: 0',
    'no client-facing action has been required',
  ]);
  if (!remoteMonitoringOffline &&
      !(telemetrySummaryVisible && noOpenIncident)) {
    return null;
  }
  if (siteAwarenessSummary != null) {
    return siteAwarenessSummary.clientMonitoringSummary(
      siteReference: scope.siteReference,
      nextStepQuestion:
          'If you want, I can check anything specific from the latest monitoring view.',
    );
  }
  if (remoteMonitoringOffline) {
    return 'I do not have live camera confirmation for ${scope.siteReference} right now, so I cannot call it all clear from a camera check. If you want, I can arrange a manual follow-up and update you here with the next confirmed step.';
  }
  return 'I do not have a live camera check to call ${scope.siteReference} all clear right now. The latest operational picture does not show an open incident, and if you want, I can arrange a manual follow-up and update you here with the next confirmed step.';
}

String? _cameraConnectionClarifierReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required List<String> recentConversationTurns,
  required TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
}) {
  final asksWhyNoCameras = _asksWhyNoLiveCameraAccess(normalizedMessage);
  final asksForUrgentCameraRepair = _containsAny(normalizedMessage, const [
    'rewire cameras',
    'rewire camera',
    'fix the cameras',
    'fix the camera',
    'check asap',
    'check as soon as possible',
    'repair the cameras',
    'repair the camera',
    'sort out the cameras',
    'sort out the camera',
  ]);
  final asksIfConnectionIsFixed = _asksIfConnectionOrBridgeIsFixed(
    normalizedMessage,
  );
  if (!asksWhyNoCameras &&
      !asksForUrgentCameraRepair &&
      !asksIfConnectionIsFixed) {
    return null;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  final remoteMonitoringOffline = _containsAny(joined, const [
    'temporarily without remote monitoring',
    'remote watch is temporarily unavailable',
    'remote monitoring is offline',
    'monitoring connection is offline',
    'offline for this site',
    'monitoring path is offline',
    'do not have live camera confirmation',
    'do not have live visual confirmation',
    'camera connection issue',
    'connection issue',
    'camera bridge is offline',
    'local camera bridge is offline',
    'camera bridge is not responding',
    'local camera bridge is not responding',
    'bridge offline',
  ]);
  if (!remoteMonitoringOffline) {
    return null;
  }
  if (siteAwarenessSummary != null) {
    return siteAwarenessSummary.clientMonitoringSummary(
      siteReference: scope.siteReference,
      nextStepQuestion: 'Want me to check anything specific?',
    );
  }
  if (asksWhyNoCameras) {
    return 'I cannot see live cameras for ${scope.siteReference} right now because the monitoring connection is offline. I will update you here as soon as live camera access is confirmed again.';
  }
  if (asksForUrgentCameraRepair) {
    return 'Understood. I am asking control to check the camera connection at ${scope.siteReference} as a priority. If an on-site fix is needed, I will update you here with the next confirmed step.';
  }
  return 'Not confirmed yet. I still do not have live camera confirmation for ${scope.siteReference}, so I cannot say the connection is restored yet. I will update you here as soon as that is confirmed.';
}

String? _cameraHealthFactPacketReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required TelegramAiDeliveryMode deliveryMode,
  required List<String> recentConversationTurns,
  required _PreferredReplyStyle preferredReplyStyle,
  required _ClientProfile clientProfile,
  required bool escalatedLane,
  required bool pressuredLane,
  required ClientCameraHealthFactPacket? cameraHealthFactPacket,
  required TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
}) {
  final packet = cameraHealthFactPacket;
  if (packet == null) {
    return null;
  }
  final asksWhyNoCameras = _asksWhyNoLiveCameraAccess(normalizedMessage);
  final asksForUrgentCameraRepair = _containsAny(normalizedMessage, const [
    'rewire cameras',
    'rewire camera',
    'fix the cameras',
    'fix the camera',
    'check asap',
    'check as soon as possible',
    'repair the cameras',
    'repair the camera',
    'sort out the cameras',
    'sort out the camera',
    'reconnect cameras',
    'reconnect camera',
  ]);
  final asksIfConnectionIsFixed = _asksIfConnectionOrBridgeIsFixed(
    normalizedMessage,
  );
  final assertsLiveVisualAccess = _assertsLiveVisualAccessState(
    normalizedMessage,
  );
  final asksOvernightAlerting = _asksOvernightAlertingSupport(
    normalizedMessage,
  );
  final asksBaselineSweep = _asksForBaselineSweep(normalizedMessage);
  final asksBaselineSweepStatus = _asksAboutBaselineSweepStatus(
    normalizedMessage,
    recentConversationTurns,
  );
  final asksBaselineSweepEta = _asksAboutBaselineSweepEta(
    normalizedMessage,
    recentConversationTurns,
  );
  final asksWholeSiteBreachReview = _asksForWholeSiteBreachReview(
    normalizedMessage,
    recentConversationTurns,
  );
  final asksWholeSiteBreachReviewStatus = _asksAboutWholeSiteBreachReviewStatus(
    normalizedMessage,
    recentConversationTurns,
  );
  final asksWholeSiteBreachReviewEta = _asksAboutWholeSiteBreachReviewEta(
    normalizedMessage,
    recentConversationTurns,
  );
  final asksCameraCheck = _containsAny(normalizedMessage, const [
    'did you check cameras',
    'did you check the cameras',
    'did you check camera',
    'camera check',
    'check cameras',
  ]);
  final asksAboutRestoration = _containsAny(normalizedMessage, const [
    'when will remote monitoring be back',
    'when will remote monitoring be back up',
    'when will remote monitoring be back online',
    'when will monitoring be back',
    'when will monitoring be back up',
    'when will monitoring be back online',
    'when will remote watch be back',
    'how long until remote monitoring',
    'how long until monitoring',
    'when is remote monitoring back',
  ]);
  final camerasDown = _containsAny(normalizedMessage, const [
    'my cameras are down',
    'cameras are down',
    'camera is down',
    'camera down',
    'cctv is down',
    'cctv down',
  ]);
  if (!asksWhyNoCameras &&
      !asksForUrgentCameraRepair &&
      !asksIfConnectionIsFixed &&
      !assertsLiveVisualAccess &&
      !asksOvernightAlerting &&
      !asksBaselineSweep &&
      !asksBaselineSweepStatus &&
      !asksBaselineSweepEta &&
      !asksWholeSiteBreachReview &&
      !asksWholeSiteBreachReviewStatus &&
      !asksWholeSiteBreachReviewEta &&
      !asksCameraCheck &&
      !asksAboutRestoration &&
      !camerasDown) {
    return null;
  }
  final safeClientExplanation = _clientSafeCameraExplanationText(
    packet.safeClientExplanation,
    siteReference: scope.siteReference,
    status: packet.status,
  );

  if (assertsLiveVisualAccess) {
    if (packet.status == ClientCameraHealthStatus.live) {
      return 'Yes. We currently have visual confirmation at ${scope.siteReference}.';
    }
    return 'Not confirmed yet. $safeClientExplanation';
  }

  final stepClosing = _clientFollowUpClosing(
    recentConversationTurns,
    mode: _FollowUpMode.step,
    deliveryMode: deliveryMode,
    preferredReplyStyle: preferredReplyStyle,
    clientProfile: clientProfile,
    escalated: escalatedLane,
    compressed: pressuredLane,
  );
  final visualClosing = _clientFollowUpClosing(
    recentConversationTurns,
    mode: _FollowUpMode.visual,
    deliveryMode: deliveryMode,
    preferredReplyStyle: preferredReplyStyle,
    clientProfile: clientProfile,
    escalated: escalatedLane,
    compressed: pressuredLane,
  );

  if (asksOvernightAlerting) {
    return 'Yes. If ONYX receives a confirmed alert for ${scope.siteReference}, we will message you here right away.';
  }

  if (siteAwarenessSummary != null) {
    if (assertsLiveVisualAccess) {
      return 'Yes. ${siteAwarenessSummary.clientMonitoringSummary(siteReference: scope.siteReference)}';
    }
    if (asksWhyNoCameras ||
        asksIfConnectionIsFixed ||
        asksAboutRestoration ||
        asksCameraCheck ||
        camerasDown) {
      return siteAwarenessSummary.clientMonitoringSummary(
        siteReference: scope.siteReference,
        nextStepQuestion: visualClosing,
      );
    }
    if (asksBaselineSweep) {
      return 'Yes. ${siteAwarenessSummary.clientMonitoringSummary(siteReference: scope.siteReference, nextStepQuestion: visualClosing)}';
    }
  }

  if (asksBaselineSweep) {
    if (packet.status == ClientCameraHealthStatus.live) {
      return 'Yes. I can do a quick camera check and send you the confirmed result here.';
    }
    return 'I do not want to call the baseline normal for ${scope.siteReference} without confirmed visual access. $safeClientExplanation';
  }

  if (asksBaselineSweepStatus) {
    return 'Not yet confirmed. I do not have a baseline result to send you yet.';
  }

  if (asksBaselineSweepEta) {
    if (packet.status == ClientCameraHealthStatus.live) {
      return 'A quick camera check should only take a few minutes. I will send the result here once it is confirmed.';
    }
    return 'I do not have a confirmed timing for that yet. I will send the result here once it is confirmed.';
  }

  if (asksWholeSiteBreachReview) {
    return 'Yes. I can review the site signals and send you the confirmed result here.';
  }

  if (asksWholeSiteBreachReviewStatus) {
    return 'Not yet confirmed. I do not have a full-site breach result to send you yet.';
  }

  if (asksWholeSiteBreachReviewEta) {
    return 'I do not have a confirmed timing for that yet. I will send the result here once it is confirmed.';
  }

  if (asksIfConnectionIsFixed) {
    if (packet.status == ClientCameraHealthStatus.live) {
      return 'Yes. We currently have live visual access at ${scope.siteReference}.';
    }
    return 'Not confirmed yet. $safeClientExplanation I will update you here as soon as live camera access is confirmed again.';
  }

  if (asksWhyNoCameras) {
    if (packet.status == ClientCameraHealthStatus.live) {
      return 'We can currently verify ${scope.siteReference} visually.';
    }
    return '$safeClientExplanation I will update you here as soon as live camera access is confirmed again.';
  }

  if (asksAboutRestoration && packet.status != ClientCameraHealthStatus.live) {
    return 'I do not have a confirmed time for full live camera access to return at ${scope.siteReference} yet. $safeClientExplanation I will update you here as soon as that is confirmed.';
  }

  if (asksForUrgentCameraRepair) {
    switch (packet.reason) {
      case ClientCameraHealthReason.credentialsMissing:
        return 'Understood. The current next step for ${scope.siteReference} is to keep the interim path stable while the approved Hik-Connect credentials are completed. If an on-site step is actually confirmed, I will update you here.';
      case ClientCameraHealthReason.bridgeOffline:
        return 'Understood. I am asking control to restore the current camera bridge at ${scope.siteReference} now. If an on-site step is actually confirmed, I will update you here with the next confirmed step.';
      case ClientCameraHealthReason.recorderUnreachable:
        return 'Understood. I am asking control to verify the recorder path at ${scope.siteReference} now. If an on-site step is actually confirmed, I will update you here with the next confirmed step.';
      case ClientCameraHealthReason.legacyProxyActive:
        return 'We currently have visual confirmation at ${scope.siteReference}. If that changes, I will update you here with the next confirmed step.';
      case ClientCameraHealthReason.unknown:
        return 'Understood. I am asking control to check the current camera path at ${scope.siteReference} now. If an on-site step is actually confirmed, I will update you here with the next confirmed step.';
    }
  }

  if (asksCameraCheck) {
    if (packet.status == ClientCameraHealthStatus.live) {
      final lastVisualTimeLabel = _telegramCameraFactTimeLabel(
        packet.lastSuccessfulVisualAtUtc,
      );
      if (lastVisualTimeLabel != null) {
        return 'We currently have visual confirmation at ${scope.siteReference}. The last successful visual confirmation in ONYX was at $lastVisualTimeLabel.';
      }
      return 'We currently have visual confirmation at ${scope.siteReference}.';
    }
    return 'I do not have live camera confirmation for ${scope.siteReference} right now. $safeClientExplanation If you want, I can arrange a manual follow-up and $visualClosing';
  }

  if (camerasDown) {
    return 'Understood. $safeClientExplanation I am asking control to verify the current position at ${scope.siteReference} manually, and $stepClosing';
  }

  return null;
}

String? _cameraOfflineSignalClarifierReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required List<String> recentConversationTurns,
  required ClientCameraHealthFactPacket? cameraHealthFactPacket,
  required TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
}) {
  final mentionsOfflineCamera =
      normalizedMessage.contains('camera') &&
      _containsAny(normalizedMessage, const [
        'currently offline',
        'is offline',
        'offline now',
        'camera offline',
      ]);
  final asksHowSignalWasDetected = _containsAny(normalizedMessage, const [
    'how did you detect a signal',
    'how did you detect signal',
    'how did you detect a trigger',
    'how did you detect a event',
    'how did you detect an event',
    'how did you pick up a signal',
    'how did you pick that up',
    'how did you detect that',
  ]);
  if (!mentionsOfflineCamera || !asksHowSignalWasDetected) {
    return null;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  final packet = cameraHealthFactPacket;
  final usesLegacyRecorderBridge =
      packet?.path == ClientCameraHealthPath.legacyLocalProxy ||
      packet?.reason == ClientCameraHealthReason.legacyProxyActive;
  final mentionsRecorderSignal = _containsAny(joined, const [
    'latest logged signal was a recorder event',
    'latest verified activity near',
    'recent motion alerts',
    'temporary local recorder bridge',
    'usable current verified image',
  ]);
  if (!usesLegacyRecorderBridge && !mentionsRecorderSignal) {
    return null;
  }
  if (siteAwarenessSummary != null) {
    return siteAwarenessSummary.clientMonitoringSummary(
      siteReference: scope.siteReference,
      extraDetail:
          'The latest signal was still captured through the live site-awareness snapshot pipeline.',
    );
  }
  return 'A signal can still be logged from the recorder even if Camera 11 is not giving us a usable live picture right now. For ${scope.siteReference}, that update came from recorder telemetry, not a clean current view from Camera 11.';
}

String? _cameraHealthStatusUpdateReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required TelegramAiDeliveryMode deliveryMode,
  required List<String> recentConversationTurns,
  required _PreferredReplyStyle preferredReplyStyle,
  required _ClientProfile clientProfile,
  required bool escalatedLane,
  required bool pressuredLane,
  required ClientCameraHealthFactPacket? cameraHealthFactPacket,
}) {
  final packet = cameraHealthFactPacket;
  if (packet == null || !_isGenericStatusFollowUp(normalizedMessage)) {
    return null;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (!_hasRecentCameraStatusContext(joined)) {
    return null;
  }
  final safeClientExplanation = _clientSafeCameraExplanationText(
    packet.safeClientExplanation,
    siteReference: scope.siteReference,
    status: packet.status,
  );

  if (packet.status == ClientCameraHealthStatus.live) {
    final lastVisualTimeLabel = _telegramCameraFactTimeLabel(
      packet.lastSuccessfulVisualAtUtc,
    );
    if (lastVisualTimeLabel != null) {
      return 'Update: We currently have visual confirmation at ${scope.siteReference}. The last successful visual confirmation in ONYX was at $lastVisualTimeLabel.';
    }
    return 'Update: We currently have visual confirmation at ${scope.siteReference}.';
  }

  final stepClosing = _clientFollowUpClosing(
    recentConversationTurns,
    mode: _FollowUpMode.step,
    deliveryMode: deliveryMode,
    preferredReplyStyle: preferredReplyStyle,
    clientProfile: clientProfile,
    escalated: escalatedLane,
    compressed: pressuredLane,
  );
  return 'Update: $safeClientExplanation $stepClosing';
}

String? _cameraHealthReassuranceReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required TelegramAiDeliveryMode deliveryMode,
  required List<String> recentConversationTurns,
  required _PreferredReplyStyle preferredReplyStyle,
  required _ClientProfile clientProfile,
  required bool escalatedLane,
  required bool pressuredLane,
  required ClientCameraHealthFactPacket? cameraHealthFactPacket,
}) {
  final packet = cameraHealthFactPacket;
  final broadReassuranceAsk = _isBroadReassuranceAsk(normalizedMessage);
  final comfortMonitoringAsk = _asksComfortOrMonitoringSupport(
    normalizedMessage,
  );
  if (packet == null || (!broadReassuranceAsk && !comfortMonitoringAsk)) {
    return null;
  }
  final safeClientExplanation = _clientSafeCameraExplanationText(
    packet.safeClientExplanation,
    siteReference: scope.siteReference,
    status: packet.status,
  );
  final verificationClosing = _clientFollowUpClosing(
    recentConversationTurns,
    mode: _FollowUpMode.step,
    deliveryMode: deliveryMode,
    preferredReplyStyle: preferredReplyStyle,
    clientProfile: clientProfile,
    escalated: escalatedLane,
    compressed: pressuredLane,
  );
  final downCameraLabel = _recentThreadDownCameraLabel(recentConversationTurns);
  final recentUnusableCurrentImage = _recentThreadShowsUnusableCurrentImage(
    recentConversationTurns,
  );
  final effectiveIssueStatus = _effectiveLiveSiteIssueStatus(packet);
  final reassuranceHotspot =
      packet.liveSiteMovementHotspotLabel ??
      packet.recentMovementHotspotLabel ??
      scope.siteReference;
  if (effectiveIssueStatus == ClientLiveSiteIssueStatus.activeSignals) {
    if (comfortMonitoringAsk) {
      return 'I am seeing live activity around $reassuranceHotspot right now. That means the site is not clear from current signals alone, and I will keep watching and $verificationClosing';
    }
    return 'Not confirmed yet. I am seeing live activity around $reassuranceHotspot right now. That means the site is not clear from current signals alone, and $verificationClosing';
  }
  if (effectiveIssueStatus == ClientLiveSiteIssueStatus.recentSignals) {
    final reassuranceLead = _recentMovementSignalsLead(
      packet: packet,
      scope: scope,
    );
    if (comfortMonitoringAsk) {
      return '$reassuranceLead Nothing in the current signals confirms a threat right now, and I will keep watching and $verificationClosing';
    }
    return 'Not confirmed yet. $reassuranceLead Nothing in the current signals confirms a threat right now, and $verificationClosing';
  }
  if (packet.status == ClientCameraHealthStatus.live) {
    if (downCameraLabel != null) {
      final partialCoverageLine =
          'We still have some visual coverage at ${scope.siteReference}, but $downCameraLabel is down.';
      if (comfortMonitoringAsk) {
        return 'Nothing I can see right now confirms the site is unsafe, but I do not want to overpromise from partial camera coverage alone. $partialCoverageLine I will keep watching and $verificationClosing';
      }
      return 'Not confirmed yet. $partialCoverageLine I do not want to overstate the site status from partial camera coverage alone. $verificationClosing';
    }
    if (recentUnusableCurrentImage) {
      const imageLimitLine =
          'I do not have a usable current image to share right now.';
      if (comfortMonitoringAsk) {
        return 'Nothing I can see right now confirms the site is unsafe, but I do not want to overpromise from that alone. $imageLimitLine I will keep watching and $verificationClosing';
      }
      return 'Not confirmed yet. $imageLimitLine I do not want to overstate the site status from that alone. $verificationClosing';
    }
    if (comfortMonitoringAsk) {
      return 'Nothing I can see right now confirms the site is unsafe, but I do not want to overpromise from telemetry alone. $safeClientExplanation I will keep watching and $verificationClosing';
    }
    return 'Not confirmed yet. $safeClientExplanation I do not want to overstate the site status from telemetry alone. $verificationClosing';
  }
  return 'Not confirmed yet. $safeClientExplanation I do not have live visual confirmation right now. $verificationClosing';
}

String _clientSafeCameraExplanationText(
  String value, {
  required String siteReference,
  ClientCameraHealthStatus? status,
}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  final resolvedSiteReference = siteReference.trim().isEmpty
      ? 'the site'
      : siteReference.trim();
  final lowered = trimmed.toLowerCase();
  if (status == ClientCameraHealthStatus.live &&
      (lowered.contains('visual confirmation') ||
          lowered.contains('live camera access') ||
          lowered.contains('live visual access'))) {
    return 'We currently have visual confirmation at $resolvedSiteReference.';
  }
  if (status == ClientCameraHealthStatus.limited ||
      lowered.contains('visibility is limited') ||
      lowered.contains('visibility remains limited') ||
      lowered.contains('limited right now')) {
    return 'Live camera visibility at $resolvedSiteReference is limited right now.';
  }
  if (lowered.contains('currently unavailable') ||
      lowered.contains('camera bridge is offline') ||
      lowered.contains('bridge is not responding') ||
      lowered.contains('camera visibility')) {
    return 'Live camera visibility at $resolvedSiteReference is unavailable right now.';
  }
  if (lowered.contains('recorder event signals') ||
      lowered.contains('site signals')) {
    return 'I still have site signals for $resolvedSiteReference, but I am verifying the latest visual view before I overstate what I can confirm.';
  }
  if (lowered.contains('visual confirmation') ||
      lowered.contains('live camera access') ||
      lowered.contains('live visual access')) {
    return 'We currently have visual confirmation at $resolvedSiteReference.';
  }
  return trimmed
      .replaceAll(
        RegExp(
          r'\s*through (?:a |the )?temporary local recorder bridge',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(
        RegExp(r'\s*on the current monitoring path', caseSensitive: false),
        '',
      )
      .replaceAll(
        RegExp(
          r'\s*while the newer api credentials are still pending',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(' .', '.')
      .trim();
}
