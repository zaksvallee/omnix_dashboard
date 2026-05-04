part of 'telegram_ai_assistant_service.dart';

String? _reassuranceClarifierReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required List<String> recentConversationTurns,
  required TelegramAiClientLaneStage laneStage,
  required _ClientTonePack tonePack,
  required _PreferredReplyStyle preferredReplyStyle,
  required _ClientProfile clientProfile,
  required TelegramAiDeliveryMode deliveryMode,
  required bool escalatedLane,
  required bool pressuredLane,
}) {
  final asksIfEverythingIsOkay =
      telegramAiIsBroadReassuranceAsk(normalizedMessage) ||
      telegramAiContainsAny(normalizedMessage, const [
        'all right',
        'alright',
        'all good',
        'sure?',
      ]);
  if (!asksIfEverythingIsOkay) {
    return null;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  final remoteMonitoringOffline = telegramAiContainsAny(joined, const [
    'temporarily without remote monitoring',
    'remote watch is temporarily unavailable',
    'remote monitoring is offline',
    'offline for this site',
    'monitoring path is offline',
  ]);
  final explicitOnSitePresence = telegramAiHasExplicitCurrentOnSitePresence(joined);
  final onlyGenericFieldActivity = telegramAiContainsAny(joined, const [
    'routine on-site team activity is visible',
    'field activity observed',
  ]);
  final telemetrySummaryVisible = telegramAiHasTelemetrySummaryContext(joined);
  final noOpenIncident = telegramAiContainsAny(joined, const [
    'not sitting as an open incident',
    'open follow-ups: 0',
    'no client-facing action has been required',
  ]);
  final latestResponseArrival =
      telemetrySummaryVisible && telegramAiHasTelemetryResponseArrivalSignal(joined);
  final onSiteNow =
      explicitOnSitePresence ||
      (laneStage == TelegramAiClientLaneStage.responderOnSite &&
          !remoteMonitoringOffline &&
          !onlyGenericFieldActivity);
  final fieldActivityVisible = telegramAiContainsAny(joined, const [
    'field activity observed',
    'routine on-site team activity is visible',
    'latest signal: response arrival',
    'latest signal: patrol',
  ]);
  final verificationClosing = _clientFollowUpClosing(
    recentConversationTurns,
    mode: onSiteNow ? TelegramAiFollowUpMode.onsite : TelegramAiFollowUpMode.step,
    deliveryMode: deliveryMode,
    preferredReplyStyle: preferredReplyStyle,
    clientProfile: clientProfile,
    escalated: escalatedLane,
    compressed: pressuredLane,
  );
  if (telemetrySummaryVisible && noOpenIncident) {
    final telemetryLead = latestResponseArrival
        ? 'The latest ONYX telemetry includes a response-arrival signal for ${scope.siteReference}'
        : 'The latest ONYX telemetry shows recent field activity at ${scope.siteReference}';
    return 'Not confirmed yet. $telemetryLead, and nothing is currently sitting as an open incident, but I do not have live visual confirmation right now. If you want a manual follow-up, message here and $verificationClosing';
  }
  if (telemetrySummaryVisible) {
    final telemetryLead = latestResponseArrival
        ? 'The latest ONYX telemetry includes a response-arrival signal for ${scope.siteReference}'
        : 'The latest ONYX telemetry shows recent field activity at ${scope.siteReference}';
    return 'Not confirmed yet. $telemetryLead, but I do not have live visual confirmation right now. If you want a manual follow-up, message here and $verificationClosing';
  }
  final recentCommunityReportVisible = telegramAiContainsAny(joined, const [
    'community reports',
    'suspicious vehicle scouting',
    'latest confirmed activity was',
    'latest confirmed report was',
  ]);
  final noLiveVisualConfirmation = telegramAiContainsAny(joined, const [
    'do not have live visual confirmation',
    'grounding this on the current operational picture rather than a live camera check',
  ]);
  if (recentCommunityReportVisible && noOpenIncident) {
    return 'Not confirmed visually yet. The latest logged report at ${scope.siteReference} was reviewed and is not sitting as an open incident now, but I do not have live visual confirmation right now. If you want, I can ask control for a manual follow-up and $verificationClosing';
  }
  if (recentCommunityReportVisible && noLiveVisualConfirmation) {
    return 'Not confirmed visually yet. The latest logged report at ${scope.siteReference} was reviewed, but I do not have live visual confirmation right now. If you want, I can ask control for a manual follow-up and $verificationClosing';
  }
  if (onSiteNow) {
    return 'Not confirmed yet. Security is already on site at ${scope.siteReference}, but I do not want to overstate that until control verifies everything is okay. $verificationClosing';
  }
  if (remoteMonitoringOffline && fieldActivityVisible) {
    return 'Not confirmed yet. Remote monitoring is offline, but the latest field signal still shows routine on-site activity at ${scope.siteReference} rather than a confirmed problem. $verificationClosing';
  }
  if (remoteMonitoringOffline) {
    return 'Not confirmed yet. Remote monitoring is offline at ${scope.siteReference}, so control is checking manually before I confirm everything is okay. $verificationClosing';
  }
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'Not confirmed yet. We are checking ${scope.siteReference} now before I say everything is okay. $verificationClosing';
    case _ClientTonePack.enterprise:
      return 'Not confirmed yet. We are checking ${scope.siteReference} now before confirming everything is okay. $verificationClosing';
    case _ClientTonePack.standard:
      return 'Not confirmed yet. We are checking ${scope.siteReference} now before I confirm everything is okay. $verificationClosing';
  }
}

String? _clientCorrectionClarifierReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required List<String> recentConversationTurns,
  required TelegramAiDeliveryMode deliveryMode,
  required _PreferredReplyStyle preferredReplyStyle,
  required _ClientProfile clientProfile,
  required bool escalatedLane,
  required bool pressuredLane,
}) {
  final camerasDown = telegramAiContainsAny(normalizedMessage, const [
    'my cameras are down',
    'cameras are down',
    'camera is down',
    'camera down',
    'cctv is down',
    'cctv down',
  ]);
  final securityNotOnSite = telegramAiContainsAny(normalizedMessage, const [
    'security is not on site',
    'security not on site',
    'security isnt on site',
    'security is not there',
    'security isnt there',
    'not on site',
  ]);
  final noUnitOnSite = telegramAiContainsAny(normalizedMessage, const [
    'there is no unit on site',
    'there isnt a unit on site',
    'there is not a unit on site',
    'there is no team on site',
    'there is no one on site',
    'nobody is on site',
    'no one is on site',
    'no unit on site',
  ]);
  if (!camerasDown && !securityNotOnSite && !noUnitOnSite) {
    return null;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  final verificationClosing = _clientFollowUpClosing(
    recentConversationTurns,
    mode: TelegramAiFollowUpMode.step,
    deliveryMode: deliveryMode,
    preferredReplyStyle: preferredReplyStyle,
    clientProfile: clientProfile,
    escalated: escalatedLane,
    compressed: pressuredLane,
  );
  if (noUnitOnSite && telegramAiHasTelemetrySummaryContext(joined)) {
    return 'Understood. I do not have a confirmed unit on site at ${scope.siteReference} from that earlier summary alone. That wording came from recorded ONYX field telemetry, not a confirmed current unit on site. If you want, I can ask control to confirm the current position, and $verificationClosing';
  }
  if (camerasDown && securityNotOnSite) {
    return 'Understood. If your cameras are down and security is not on site from your side, I cannot confirm this visually or call a unit on site. I am asking control to verify the current position at ${scope.siteReference} now, and $verificationClosing';
  }
  if (camerasDown) {
    return 'Understood. If your cameras are down, I do not have live visual confirmation from them right now. I am asking control to verify the current position at ${scope.siteReference} manually, and $verificationClosing';
  }
  return 'Understood. If security is not on site from your side, I will not call them on site. I am asking control to verify the current response position at ${scope.siteReference} now, and $verificationClosing';
}

String? _operationalPictureClarifierReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required List<String> recentConversationTurns,
}) {
  final asksAboutOperationalPicture = telegramAiContainsAny(normalizedMessage, const [
    'what current operational picture',
    'what operational picture',
    'what do you mean operational picture',
    'what picture',
  ]);
  if (!asksAboutOperationalPicture) {
    return null;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  final hasCommunityReport = telegramAiContainsAny(joined, const [
    'community reports',
    'suspicious vehicle scouting',
    'latest confirmed activity was',
    'latest confirmed report was',
  ]);
  final noOpenIncident = telegramAiContainsAny(joined, const [
    'not sitting as an open incident',
    'open follow-ups: 0',
  ]);
  if (hasCommunityReport && noOpenIncident) {
    return 'By current operational picture, I mean the latest logged report in ONYX and the fact that it is not sitting as an open incident now. For ${scope.siteReference}, that is the earlier suspicious-vehicle report, and I still do not have live visual confirmation from cameras right now.';
  }
  return 'By current operational picture, I mean the latest logged reports and incident status in ONYX, rather than a live camera view. I still do not have live visual confirmation for ${scope.siteReference} right now.';
}

String? _remoteMonitoringRestorationReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required List<String> recentConversationTurns,
}) {
  final asksAboutRestoration = telegramAiContainsAny(normalizedMessage, const [
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
  if (!asksAboutRestoration) {
    return null;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  final remoteMonitoringOffline = telegramAiContainsAny(joined, const [
    'temporarily without remote monitoring',
    'remote watch is temporarily unavailable',
    'remote monitoring is offline',
    'offline for this site',
    'monitoring path is offline',
  ]);
  if (!remoteMonitoringOffline) {
    return null;
  }
  return 'I do not have a confirmed time for remote monitoring to come back at ${scope.siteReference} yet. We will update you here as soon as the monitoring path is restored, and if you want a manual follow-up before then, message here and control will pick it up.';
}

String? _alertWatchAcknowledgementReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
}) {
  final gratitude = telegramAiContainsAny(normalizedMessage, const [
    'thank you',
    'thanks',
    'appreciate it',
    'appreciate your help',
    'thank you for assisting',
  ]);
  final alertWatch = telegramAiContainsAny(normalizedMessage, const [
    'keep me posted',
    'keep me updated',
    'let me know if anything changes',
    'let me know if anything serious',
    'serious alerts',
    'serious alert',
    'anything serious',
  ]);
  if (!gratitude || !alertWatch) {
    return null;
  }
  return 'You are welcome. I will keep you posted here if anything serious comes through at ${scope.siteReference}.';
}

String? _historicalAlarmReviewReply({
  required String normalizedMessage,
  required List<String> recentConversationTurns,
}) {
  final asksHistoricalReview = _asksForHistoricalAlarmReview(
    normalizedMessage,
    recentConversationTurns,
  );
  final asksHistoricalReviewStatus = _asksAboutHistoricalAlarmReviewStatus(
    normalizedMessage,
    recentConversationTurns,
  );
  final asksHistoricalReviewEscalation = _asksToEscalateHistoricalAlarmReview(
    normalizedMessage,
    recentConversationTurns,
  );
  if (!asksHistoricalReview &&
      !asksHistoricalReviewStatus &&
      !asksHistoricalReviewEscalation) {
    return null;
  }
  final reviewScope = _historicalAlarmReviewScopeLabel(recentConversationTurns);
  if (asksHistoricalReviewEscalation) {
    return 'Understood. You are asking for manual control review of the 4am alarm window. I do not have a confirmed historical review result for $reviewScope yet.';
  }
  if (asksHistoricalReviewStatus) {
    return 'Not yet confirmed. I do not have a confirmed historical review result for $reviewScope yet.';
  }
  return 'Understood. You are asking about the 4am window, not the current site status. I do not have a confirmed historical review result for $reviewScope yet.';
}

String? _eventVisualImageClarifierReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required List<String> recentConversationTurns,
  required ClientCameraHealthFactPacket? cameraHealthFactPacket,
}) {
  if (!telegramAiAsksWhyImageCannotBeSent(normalizedMessage)) {
    return null;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  final mentionsRecordedEventVisuals =
      normalizedMessage.contains('hikconnect') &&
          normalizedMessage.contains('visual') ||
      telegramAiRecentThreadMentionsRecordedEventVisuals(recentConversationTurns) ||
      telegramAiHasRecentMotionTelemetryContext(joined);
  if (!mentionsRecordedEventVisuals) {
    return null;
  }
  final packet = cameraHealthFactPacket;
  final bridgeLine =
      packet != null &&
          (packet.path == ClientCameraHealthPath.legacyLocalProxy ||
              packet.reason == ClientCameraHealthReason.legacyProxyActive)
      ? ' Recorder signals can still be logged, but that does not guarantee a usable exported image can be sent here every time.'
      : '';
  return 'I can see recorded event visuals were logged for ${scope.siteReference}, but I do not currently have a usable exported image from those events to send here.$bridgeLine';
}

String? _hypotheticalEscalationCapabilityReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
}) {
  if (!telegramAiAsksHypotheticalEscalationCapability(normalizedMessage)) {
    return null;
  }
  return 'Yes. If you need urgent help at ${scope.siteReference}, I can escalate this to the control room from here. This message has not triggered an escalation by itself. If there is immediate danger, message here and call SAPS or 112.';
}

String? _telemetryDispatchClarifierReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required List<String> recentConversationTurns,
  required TelegramAiDeliveryMode deliveryMode,
  required _PreferredReplyStyle preferredReplyStyle,
  required _ClientProfile clientProfile,
  required bool escalatedLane,
  required bool pressuredLane,
}) {
  final telemetryPresenceChallenge = telegramAiChallengesTelemetryPresenceSummary(
    normalizedMessage,
  );
  final asksWhySomeoneIsComing = telegramAiContainsAny(normalizedMessage, const [
    'why are they coming',
    'why are you coming',
    'why is someone coming',
    'why is anyone coming',
    'why are they on their way',
    'why are they moving',
    'why coming here',
    'who is coming',
    'who is moving',
  ]);
  final asksIfThereIsAnIssue = telegramAiAsksForCurrentSiteIssueCheck(normalizedMessage);
  final shortWhyFollowUp =
      normalizedMessage == 'why' || normalizedMessage == 'why?';
  if (!asksWhySomeoneIsComing &&
      !asksIfThereIsAnIssue &&
      !shortWhyFollowUp &&
      !telemetryPresenceChallenge) {
    return null;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  final telemetrySummaryVisible = telegramAiHasTelemetrySummaryContext(joined);
  final presenceVerificationContext = telegramAiHasRecentPresenceVerificationContext(
    joined,
  );
  final unconfirmedMovementNarrative = telegramAiContainsAny(joined, const [
    'on their way',
    'moving toward the site',
    'moving to the site',
    'moving toward',
    'next on-site step',
    'next on site step',
  ]);
  if (!telemetrySummaryVisible &&
      !unconfirmedMovementNarrative &&
      !presenceVerificationContext) {
    return null;
  }
  if (telegramAiHasExplicitCurrentMovementConfirmation(joined) ||
      telegramAiHasExplicitCurrentOnSitePresence(joined)) {
    return null;
  }
  final noOpenIncident = telegramAiContainsAny(joined, const [
    'not sitting as an open incident',
    'open follow-ups: 0',
    'no client-facing action has been required',
  ]);
  final verificationClosing = _clientFollowUpClosing(
    recentConversationTurns,
    mode: TelegramAiFollowUpMode.step,
    deliveryMode: deliveryMode,
    preferredReplyStyle: preferredReplyStyle,
    clientProfile: clientProfile,
    escalated: escalatedLane,
    compressed: pressuredLane,
  );
  if (asksWhySomeoneIsComing ||
      (shortWhyFollowUp && unconfirmedMovementNarrative)) {
    return 'I do not have a confirmed unit moving to ${scope.siteReference} right now. The earlier wording came from recorded ONYX field telemetry, not a confirmed active dispatch or unit on site. If you want, I can ask control to confirm the current position, and $verificationClosing';
  }
  final issueLead = noOpenIncident
      ? 'There is no confirmed active issue at ${scope.siteReference} right now.'
      : presenceVerificationContext
      ? 'I do not have a confirmed active issue at ${scope.siteReference} from the scoped record I can see right now.'
      : 'I do not have a confirmed active issue at ${scope.siteReference} from that earlier wording alone.';
  return '$issueLead The earlier wording came from recorded ONYX field telemetry, not a confirmed active dispatch or unit on site. If you want, I can ask control to confirm the current position, and $verificationClosing';
}
