/// Intent-resolution and semantic-ask predicates for the Telegram AI
/// subsystem.
///
/// Extracted from `telegram_ai_assistant_service.dart` as Module 5 of the
/// decomposition plan in
/// `audit/telegram_ai_service_decomposition_2026-05-04.md`.
///
/// All symbols here are pure functions or value-type enums with no
/// internal state. They are called by the legacy reply-shaping engine
/// (during the migration period) and will be called by Zara's prompt
/// builder after Module 7 ships.
library;

import 'client_camera_health_fact_packet_service.dart';
import 'telegram_ai_text_utils.dart';
import 'telegram_client_prompt_signals.dart';

enum TelegramAiFollowUpMode { general, eta, step, movement, visual, onsite }

enum TelegramAiClientReplyIntent {
  general,
  worried,
  access,
  eta,
  movement,
  visual,
  status,
}

enum TelegramAiClientLaneStage { reassurance, escalated, responderOnSite, closure }

TelegramAiFollowUpMode telegramAiFollowUpModeFromReplyText(
  String text, {
  required TelegramAiClientLaneStage laneStage,
}) {
  final normalized = text.trim().toLowerCase();
  if (laneStage == TelegramAiClientLaneStage.responderOnSite &&
      telegramAiContainsAny(normalized, const ['on site', 'on-site'])) {
    return TelegramAiFollowUpMode.onsite;
  }
  if (telegramAiContainsAny(normalized, const ['eta', 'live movement', 'arrival'])) {
    return TelegramAiFollowUpMode.eta;
  }
  if (telegramAiContainsAny(normalized, const ['access status', 'gate', 'access'])) {
    return TelegramAiFollowUpMode.step;
  }
  if (telegramAiContainsAny(normalized, const [
    'responder status',
    'movement',
    'armed response',
    'officer',
  ])) {
    return TelegramAiFollowUpMode.movement;
  }
  if (telegramAiContainsAny(normalized, const [
    'camera',
    'visual',
    'cctv',
    'footage',
    'latest view',
  ])) {
    return TelegramAiFollowUpMode.visual;
  }
  if (laneStage == TelegramAiClientLaneStage.responderOnSite) {
    return TelegramAiFollowUpMode.onsite;
  }
  return TelegramAiFollowUpMode.general;
}

bool telegramAiIsEscalatedLaneContext({
  required String normalizedMessage,
  required List<String> recentConversationTurns,
}) {
  if (telegramAiContainsAny(normalizedMessage, const [
    'help me',
    'please help',
    'panic',
    'unsafe',
    'emergency',
    'intruder',
    'break in',
    'break-in',
    'attack',
    'gun',
    'weapon',
    'threat',
  ])) {
    return true;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (joined.isEmpty) {
    return false;
  }
  return telegramAiContainsAny(joined, const [
    'escalated',
    'client escalated',
    'high-priority',
    'high priority',
    'alert received',
    'verification requested',
    'control room',
    'policy:high-risk',
  ]);
}

bool telegramAiIsPressuredLaneContext({
  required String normalizedMessage,
  required List<String> recentConversationTurns,
}) {
  var pressureSignals = 0;
  if (telegramAiContainsAny(normalizedMessage, const [
    'worried',
    'scared',
    'afraid',
    'panic',
    'unsafe',
    'help',
    'any update',
    'still waiting',
    'still no',
    'anything yet',
    'what now',
  ])) {
    pressureSignals += 1;
  }
  for (final turn in recentConversationTurns.take(6)) {
    final normalizedTurn = turn.trim().toLowerCase();
    if (normalizedTurn.isEmpty) {
      continue;
    }
    if (telegramAiContainsAny(normalizedTurn, const [
      'worried',
      'scared',
      'afraid',
      'panic',
      'unsafe',
      'please help',
      'help me',
      'any update',
      'still waiting',
      'still no',
      'anything yet',
      'what now',
      'update?',
      'yet?',
    ])) {
      pressureSignals += 1;
    }
  }
  return pressureSignals >= 2;
}

TelegramAiClientLaneStage telegramAiResolveClientLaneStage({
  required String normalizedMessage,
  required List<String> recentConversationTurns,
}) {
  final joined = recentConversationTurns
      .map(telegramAiNormalizeReplyHeuristicText)
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (telegramAiContainsAny(joined, const [
    'incident resolved',
    'site secured',
    'resolved',
    'all clear',
    'closed out',
    'closure',
  ])) {
    return TelegramAiClientLaneStage.closure;
  }
  if (telegramAiContainsAny(joined, const [
    'responder on site',
    'security response activated',
    'partner dispatch sent',
    'response activated',
    'security is already on site',
    'security already on site',
    'response unit is on site',
    'guard is on site',
    'officer is on site',
  ])) {
    return TelegramAiClientLaneStage.responderOnSite;
  }
  if (telegramAiIsEscalatedLaneContext(
    normalizedMessage: normalizedMessage,
    recentConversationTurns: recentConversationTurns,
  )) {
    return TelegramAiClientLaneStage.escalated;
  }
  return TelegramAiClientLaneStage.reassurance;
}

String telegramAiRecentConversationContextSnippet(List<String> recentConversationTurns) {
  final trimmed = recentConversationTurns
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .take(6)
      .toList(growable: false);
  if (trimmed.isEmpty) {
    return 'none';
  }
  return trimmed.join('\n');
}

TelegramAiClientReplyIntent telegramAiResolveClientReplyIntent(
  String normalizedMessage,
  List<String> recentConversationTurns,
) {
  if (telegramAiContainsAny(normalizedMessage, const [
    'worried',
    'scared',
    'afraid',
    'panic',
    'panicking',
    'nervous',
    'unsafe',
    'can i sleep',
    'sleep peacefully',
    'rest easy',
    'help me',
    'please help',
  ])) {
    return TelegramAiClientReplyIntent.worried;
  }
  if (telegramAiContainsAny(normalizedMessage, const [
    'gate',
    'access',
    'cant get in',
    'can\'t get in',
    'cant get out',
    'can\'t get out',
    'stuck outside',
    'stuck inside',
  ])) {
    return TelegramAiClientReplyIntent.access;
  }
  if (telegramAiContainsAny(normalizedMessage, const [
    'eta',
    'arrival',
    'arrive',
    'how far',
    'how long',
  ])) {
    return TelegramAiClientReplyIntent.eta;
  }
  if (telegramAiContainsAny(normalizedMessage, const [
    'guard',
    'officer',
    'response unit',
    'responder',
    'armed response',
    'police',
    'who is coming',
  ])) {
    return TelegramAiClientReplyIntent.movement;
  }
  if (telegramAiContainsAny(normalizedMessage, const [
    'camera',
    'cctv',
    'video',
    'footage',
    'see on camera',
    'what do you see',
    'daylight',
  ])) {
    return TelegramAiClientReplyIntent.visual;
  }
  if (telegramAiContainsAny(normalizedMessage, const [
    'status',
    'update',
    'progress',
    'news',
    'happening',
  ])) {
    return TelegramAiClientReplyIntent.status;
  }
  if (telegramAiLooksLikeShortFollowUp(normalizedMessage)) {
    return telegramAiIntentFromRecentConversation(recentConversationTurns);
  }
  return TelegramAiClientReplyIntent.general;
}

bool telegramAiLooksLikeShortFollowUp(String normalizedMessage) {
  if (normalizedMessage.isEmpty) {
    return false;
  }
  if (normalizedMessage.split(RegExp(r'\s+')).length > 6) {
    return false;
  }
  return telegramAiContainsAny(normalizedMessage, const [
    'still waiting',
    'anything yet',
    'any update',
    'update',
    'check now',
    'check again',
    'check again now',
    'check it now',
    'can you check now',
    'and now',
    'what now',
    'latest',
    'still',
    'yet',
    'still no',
  ]);
}

TelegramAiClientReplyIntent telegramAiIntentFromRecentConversation(
  List<String> recentConversationTurns,
) {
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (joined.isEmpty) {
    return TelegramAiClientReplyIntent.status;
  }
  if (telegramAiContainsAny(joined, const [
    'latest camera view',
    'confirmed visual update',
  ])) {
    return TelegramAiClientReplyIntent.visual;
  }
  if (telegramAiContainsAny(joined, const ['live movement', 'eta'])) {
    return TelegramAiClientReplyIntent.eta;
  }
  if (telegramAiContainsAny(joined, const ['access status', 'confirmed step'])) {
    return TelegramAiClientReplyIntent.access;
  }
  if (telegramAiContainsAny(joined, const ['responder status', 'movement update'])) {
    return TelegramAiClientReplyIntent.movement;
  }
  if (telegramAiContainsAny(joined, const [
    'treating this as live',
    'you are not alone',
  ])) {
    return TelegramAiClientReplyIntent.worried;
  }
  return TelegramAiClientReplyIntent.status;
}

bool telegramAiHasTelemetrySummaryContext(String joinedContext) {
  return telegramAiContainsAny(joinedContext, const [
    'site activity summary',
    'field telemetry',
    'latest field signal:',
    'guard or response-team activity signals were logged through onyx field telemetry',
    'guard or response-team activity signal was logged through onyx field telemetry',
    'guard or response team activity signals were logged through onyx field telemetry',
    'guard or response team activity signal was logged through onyx field telemetry',
  ]);
}

bool telegramAiHasTelemetryResponseArrivalSignal(String joinedContext) {
  return telegramAiContainsAny(joinedContext, const [
    'field response unit arrived on site',
    'latest field signal: a field response unit arrived on site',
    'response arrival signal',
    'latest field signal: a response-arrival signal was logged through onyx field telemetry',
    'latest field signal: response arrival',
  ]);
}

bool telegramAiHasExplicitCurrentOnSitePresence(String joinedContext) {
  return telegramAiContainsAny(joinedContext, const [
    'responder on site',
    'security is already on site',
    'security already on site',
    'response unit is on site',
    'guard is on site',
    'officer is on site',
  ]);
}

bool telegramAiHasExplicitCurrentMovementConfirmation(String joinedContext) {
  return telegramAiContainsAny(joinedContext, const [
    'partner dispatch sent',
    'security response activated',
    'response activated',
    'dispatch en route',
    'unit en route',
    'on the way',
    'eta confirmed',
  ]);
}

bool telegramAiAsksWhyNoLiveCameraAccess(String normalizedMessage) {
  return telegramAiContainsAny(normalizedMessage, const [
    'why cant you see my cameras',
    'why can you not see my cameras',
    'why cant you see the cameras',
    'why can you not see the cameras',
    'why cant you see cameras',
    'why can you not see cameras',
    'why cant you see my camera',
    'why can you not see my camera',
    'why cant we view live',
    'why can we not view live',
    'why cant we see live',
    'why can we not see live',
    'why cant we view live cameras',
    'why can we not view live cameras',
    'why cant we see live cameras',
    'why can we not see live cameras',
    'why cant we view the cameras live',
    'why can we not view the cameras live',
  ]);
}

bool telegramAiAsksIfConnectionOrBridgeIsFixed(String normalizedMessage) {
  return telegramAiContainsAny(normalizedMessage, const [
    'is the connection fixed',
    'is the camera connection fixed',
    'is the connection back',
    'are the cameras back',
    'is it fixed',
    'is it back up',
    'is monitoring back up',
    'is the bridge restored',
    'is the bridge back',
    'is the bridge fixed',
    'is the bridge online',
    'is the local camera bridge restored',
    'is the local camera bridge back',
  ]);
}

bool telegramAiAssertsLiveVisualAccessState(String normalizedMessage) {
  return telegramAiContainsAny(normalizedMessage, const [
    'live visual are active',
    'live visual is active',
    'live visuals are active',
    'live visuals is active',
    'live visual active',
    'live visuals active',
    'visual confirmation is active',
    'visual confirmation active',
    'live camera is active',
    'live cameras are active',
    'live camera active',
    'live cameras active',
    'cameras are online',
    'camera is online',
    'cameras online',
    'camera online',
    'cameras are not offline',
    'camera is not offline',
    'cameras arent offline',
    'camera isnt offline',
    'cameras are not down',
    'camera is not down',
    'cameras arent down',
    'camera isnt down',
    'cctv is online',
    'cctv online',
    'bridge is online',
    'bridge online',
    'bridge is not offline',
    'bridge isnt offline',
    'camera bridge is online',
    'local camera bridge is online',
    'camera bridge is not offline',
    'local camera bridge is not offline',
    'cameras are back',
    'camera is back',
  ]);
}

bool telegramAiAsksHypotheticalEscalationCapability(String normalizedMessage) {
  final asksEscalationCapability = telegramAiContainsAny(normalizedMessage, const [
    'can you escalate',
    'could you escalate',
    'would you escalate',
    'will you escalate',
    'can onyx escalate',
  ]);
  final conditionalHelpAsk = telegramAiContainsAny(normalizedMessage, const [
    'if i need help',
    'if i need urgent help',
    'if i need assistance',
    'if something happens',
    'if there is a problem',
    'if theres a problem',
  ]);
  return asksEscalationCapability && conditionalHelpAsk;
}

bool telegramAiAsksForCurrentSiteIssueCheck(String normalizedMessage) {
  return asksForTelegramClientCurrentSiteIssueCheck(normalizedMessage);
}

bool telegramAiAsksForCurrentFrameMovementCheck(String normalizedMessage) {
  return asksForTelegramClientMovementCheck(normalizedMessage);
}

bool telegramAiAsksForSemanticMovementIdentification(String normalizedMessage) {
  final asksMovement = telegramAiContainsAny(normalizedMessage, const [
    'any movement',
    'movement',
    'identify',
    'identifying',
    'detected',
    'detection',
    'see',
  ]);
  final asksSemanticObject = telegramAiContainsAny(normalizedMessage, const [
    'vehicle or human',
    'vehicles or humans',
    'vehicle or person',
    'person or vehicle',
    'persons or vehicles',
    'human or vehicle',
    'humans or vehicles',
    'vehicle or people',
    'people or vehicle',
    'vehicles or people',
    'person or human',
    'human or person',
    'human',
    'humans',
    'person',
    'persons',
    'people',
    'vehicle',
    'vehicles',
  ]);
  if (!asksSemanticObject) {
    return false;
  }
  return asksMovement ||
      telegramAiContainsAny(normalizedMessage, const [
        'what is moving',
        'who is moving',
        'what do you see',
        'what are you seeing',
      ]);
}

bool telegramAiAsksForCurrentFramePersonConfirmation(String normalizedMessage) {
  final explicitSighting = telegramAiContainsAny(normalizedMessage, const [
    'i see someone',
    'i can see someone',
    'someone there',
    'person there',
  ]);
  final explicitConfirmation = telegramAiContainsAny(normalizedMessage, const [
    'can you confirm',
    'please confirm',
    'confirm that',
    'confirm this',
  ]);
  final referencesPerson = telegramAiContainsAny(normalizedMessage, const [
    'someone',
    'person',
  ]);
  final referencesArea = telegramAiContainsAny(normalizedMessage, const [
    'backyard',
    'back yard',
    'front yard',
    'frontyard',
    'driveway',
    'gate',
  ]);
  return ((explicitSighting || explicitConfirmation) &&
          referencesPerson &&
          (referencesArea || explicitSighting)) ||
      telegramAiContainsAny(normalizedMessage, const [
        'someone in backyard',
        'someone in the backyard',
        'person in backyard',
        'person in the backyard',
      ]);
}

bool telegramAiHasCurrentFrameConversationContext(
  String joinedContext, {
  required ClientCameraHealthFactPacket? cameraHealthFactPacket,
}) {
  if (cameraHealthFactPacket?.hasCurrentVisualConfirmation == true) {
    return true;
  }
  return telegramAiContainsAny(joinedContext, const [
    'current verified frame from',
    '[image] current verified frame from',
    'latest verified frame',
    'latest camera picture',
    'visual confirmation at',
  ]);
}

bool telegramAiHasRecentMotionTelemetryContext(String joinedContext) {
  return telegramAiContainsAny(joinedContext, const [
    'motion detection alarm',
    'motion alarm',
    'recent motion alerts',
    'recent movement alerts',
    'detected movement on camera',
    'identified repeat movement activity on',
    'movement activity on camera',
  ]);
}

String telegramAiRecentMotionTelemetryLeadLabel(String joinedContext) {
  final cameraMatch = RegExp(
    r'camera\s+(\d+)',
    caseSensitive: false,
  ).firstMatch(joinedContext);
  final cameraDigits = cameraMatch?.group(1) ?? '';
  if (cameraDigits.isNotEmpty) {
    return 'recent motion alerts on Camera $cameraDigits';
  }
  return 'recent motion alerts';
}

bool telegramAiChallengesTelemetryPresenceSummary(String normalizedMessage) {
  final challengesExplicitCount = telegramAiContainsAny(normalizedMessage, const [
    'there isnt 19 guard',
    'there is not 19 guard',
    'there arent 19 guard',
    'there are not 19 guard',
    'not 19 guards',
    'not 19 response teams',
    '19 guards or response teams on site',
    '19 guard or response teams on site',
    'people on site',
  ]);
  final mentionsPresenceTarget =
      normalizedMessage.contains('guard') ||
      normalizedMessage.contains('response team') ||
      normalizedMessage.contains('people');
  final mentionsSiteOrPremises =
      normalizedMessage.contains('site') ||
      normalizedMessage.contains('there') ||
      normalizedMessage.contains('premis');
  final deniesPresence = telegramAiContainsAny(normalizedMessage, const [
    'there are no',
    'there is no',
    'there arent',
    'there are not',
    'there isnt',
    'no guards',
    'no guard',
    'no one',
    'nobody',
    'not on site',
    'not there',
  ]);
  return challengesExplicitCount ||
      (mentionsPresenceTarget && mentionsSiteOrPremises && deniesPresence);
}

bool telegramAiHasRecentPresenceVerificationContext(String joinedContext) {
  return telegramAiContainsAny(joinedContext, const [
    'site activity summary',
    'field telemetry',
    'latest field signal',
    'response-arrival signal',
    'recorded onyx telemetry activity',
    'recorded onyx field telemetry',
    'recorded guard or response activity signals',
    'not confirmed guards physically on site',
    'not 19 people physically on site',
    'no guard is confirmed on site',
    'current response position',
    'verified position update',
    'there are no guards',
    'there is no guard',
    'no guards at',
    'no guards on',
    'security is not on site',
    'security not on site',
  ]);
}

bool telegramAiHasRecentContinuousVisualActivityContext(String joinedContext) {
  return telegramAiContainsAny(joinedContext, const [
    'live visual change',
    'continuous visual watch',
    'active scene change',
    'scene change is being tracked',
    'i am seeing live activity around',
    'i am seeing activity around',
    'something active is happening there',
  ]);
}

bool telegramAiChallengesMissedMovementDetection(
  String normalizedMessage,
  List<String> recentConversationTurns,
) {
  final directChallenge = telegramAiContainsAny(normalizedMessage, const [
    'picked up nothing',
    'you picked up nothing',
    'detected nothing',
    'you detected nothing',
    'saw nothing',
    'you saw nothing',
    'nothing was picked up',
  ]);
  final walkedPastCameras =
      telegramAiContainsAny(normalizedMessage, const [
        'i just walked past',
        'i walked past',
        'walked past',
      ]) &&
      normalizedMessage.contains('camera');
  final cameraCountCorrection = RegExp(
    r'^(?:\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+cameras?$',
  ).hasMatch(normalizedMessage);
  if (directChallenge || walkedPastCameras) {
    return true;
  }
  if (!cameraCountCorrection) {
    return false;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  return telegramAiContainsAny(joined, const [
    'picked up nothing',
    'you picked up nothing',
    'walked past',
  ]);
}

String? telegramAiCurrentFrameConfirmationAreaLabel(String normalizedMessage) {
  if (telegramAiContainsAny(normalizedMessage, const ['backyard', 'back yard'])) {
    return 'backyard';
  }
  if (telegramAiContainsAny(normalizedMessage, const ['front yard', 'frontyard'])) {
    return 'front yard';
  }
  if (normalizedMessage.contains('driveway')) {
    return 'driveway';
  }
  if (normalizedMessage.contains('gate')) {
    return 'gate area';
  }
  return null;
}

bool telegramAiIsGenericStatusFollowUp(String normalizedMessage) {
  return asksForTelegramClientGenericStatusFollowUp(normalizedMessage) ||
      (normalizedMessage.split(RegExp(r'\s+')).length <= 4 &&
          telegramAiContainsAny(normalizedMessage, const ['status', 'anything new']));
}

bool telegramAiHasRecentCameraStatusContext(String joinedContext) {
  return telegramAiContainsAny(joinedContext, const [
    'live camera access',
    'live visual access',
    'live camera confirmation',
    'live visual confirmation',
    'visual confirmation at',
    'live camera visibility',
    'camera bridge',
    'local camera bridge',
    'temporary local recorder bridge',
    'remote monitoring',
    'remote watch',
    'monitoring connection',
    'monitoring path',
    'camera connection',
    'camera access',
    'cameras back',
    'bridge is offline',
    'bridge is not responding',
    'bridge offline',
  ]);
}

bool telegramAiRecentThreadShowsUnusableCurrentImage(
  List<String> recentConversationTurns,
) {
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (joined.isEmpty) {
    return false;
  }
  return telegramAiContainsAny(joined, const [
    'do not have a usable current verified image',
    'do not have a usable current image',
    'could not attach the current frame',
    'do not have a current verified image to send right now',
  ]);
}

String? telegramAiRecentThreadDownCameraLabel(List<String> recentConversationTurns) {
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (joined.isEmpty) {
    return null;
  }
  final match = RegExp(
    r'camera\s+(\d+)\s+(?:(?:is|was)\s+)?(?:currently\s+)?(?:down|offline)',
  ).firstMatch(joined);
  final digits = match?.group(1) ?? '';
  if (digits.isEmpty) {
    return null;
  }
  return 'Camera $digits';
}

bool telegramAiRecentThreadMentionsRecordedEventVisuals(
  List<String> recentConversationTurns,
) {
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (joined.isEmpty) {
    return false;
  }
  return telegramAiContainsAny(joined, const [
    'latest event image',
    'event image from camera',
    'motion detection alarm',
    'verification image has been retrieved',
    'recent event image',
    'with visuals',
    'hikconnect',
  ]);
}

bool telegramAiIsBroadReassuranceAsk(String normalizedMessage) {
  return asksForTelegramClientBroadReassuranceCheck(normalizedMessage);
}

bool telegramAiAsksComfortOrMonitoringSupport(String normalizedMessage) {
  return telegramAiContainsAny(normalizedMessage, const [
    'can i sleep peacefully',
    'can i sleep',
    'can i rest easy',
    'can i rest',
    'will you monitor',
    'will you keep monitoring',
    'will you keep watch',
    'will you watch',
    'watch the site',
    'monitor the site',
    'keep monitoring',
    'keep watch',
  ]);
}

bool telegramAiAsksForCurrentSiteView(String normalizedMessage) {
  return asksForTelegramClientCurrentSiteView(normalizedMessage);
}

bool telegramAiAsksWhyImageCannotBeSent(String normalizedMessage) {
  return telegramAiContainsAny(normalizedMessage, const [
    'why cant you send me one',
    'why cant you send one',
    'why cant you send me an image',
    'why cant you send me a picture',
    'why cant you send me a photo',
    'why cant you send it',
    'why cant you send one then',
    'why can t you send me one',
    'why can t you send one',
    'why cant we view live',
  ]);
}

bool telegramAiContainsCameraCoverageCountClaim(String text) {
  return RegExp(r'\b\d+\s+(?:other\s+)?cameras?\b').hasMatch(text);
}

bool telegramAiAsksOvernightAlertingSupport(String normalizedMessage) {
  return telegramAiContainsAny(normalizedMessage, const [
    'if im asleep and something happens',
    'if i am asleep and something happens',
    'if something happens while im asleep',
    'if something happens while i am asleep',
    'will you alert me right',
    'will you alert me',
    'alert me right',
    'alert me if something happens',
    'wake me if something happens',
  ]);
}

bool telegramAiAsksForBaselineSweep(String normalizedMessage) {
  return telegramAiContainsAny(normalizedMessage, const [
    'quick sweep',
    'do a quick sweep',
    'can you do a quick sweep',
    'baseline is normal',
    'baseline normal',
    'check the baseline',
    'see that the site is normal',
    'see that the sites baseline is normal',
    'quick baseline check',
  ]);
}

bool telegramAiAsksAboutBaselineSweepStatus(
  String normalizedMessage,
  List<String> recentConversationTurns,
) {
  if (!telegramAiHasRecentBaselineSweepContext(recentConversationTurns)) {
    return false;
  }
  return telegramAiContainsAny(normalizedMessage, const [
    'did you check',
    'have you checked',
    'have you checked yet',
    'did you sweep',
    'did you do the sweep',
    'did you do a sweep',
    'did you do the check',
    'did you check yet',
  ]);
}

bool telegramAiAsksAboutBaselineSweepEta(
  String normalizedMessage,
  List<String> recentConversationTurns,
) {
  if (!telegramAiHasRecentBaselineSweepContext(recentConversationTurns)) {
    return false;
  }
  return telegramAiContainsAny(normalizedMessage, const [
    'how long will you take',
    'how long will this take',
    'how long will it take',
    'how long',
    'when will you finish',
  ]);
}

bool telegramAiHasRecentBaselineSweepContext(List<String> recentConversationTurns) {
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (joined.isEmpty) {
    return false;
  }
  return telegramAiContainsAny(joined, const [
    'quick camera check',
    'quick sweep',
    'baseline result',
    'baseline normal',
    'checking the baseline',
  ]);
}

bool telegramAiAsksForWholeSiteBreachReview(
  String normalizedMessage,
  List<String> recentConversationTurns,
) {
  final asksToCheck = telegramAiContainsAny(normalizedMessage, const [
    'check every area',
    'check all areas',
    'review every area',
    'review all areas',
    'verify every area',
    'verify all areas',
    'check the whole site',
    'check the whole property',
    'check the entire site',
    'check the entire property',
  ]);
  if (!asksToCheck) {
    return false;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  return telegramAiContainsAny('$normalizedMessage\n$joined', const [
    'alarm',
    'breach',
    'what happened',
    '4am',
    '04 00',
    '04:00',
  ]);
}

bool telegramAiAsksAboutWholeSiteBreachReviewStatus(
  String normalizedMessage,
  List<String> recentConversationTurns,
) {
  if (!telegramAiHasRecentWholeSiteBreachReviewContext(recentConversationTurns)) {
    return false;
  }
  return telegramAiContainsAny(normalizedMessage, const [
    'did you check',
    'did you check yet',
    'have you checked',
    'have you checked yet',
    'did you review it',
    'did you review the site',
    'any result yet',
  ]);
}

bool telegramAiAsksAboutWholeSiteBreachReviewEta(
  String normalizedMessage,
  List<String> recentConversationTurns,
) {
  if (!telegramAiHasRecentWholeSiteBreachReviewContext(recentConversationTurns)) {
    return false;
  }
  return telegramAiContainsAny(normalizedMessage, const [
    'how long will you take',
    'how long will this take',
    'how long will it take',
    'how long',
    'when will you finish',
  ]);
}

bool telegramAiHasRecentWholeSiteBreachReviewContext(
  List<String> recentConversationTurns,
) {
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (joined.isEmpty) {
    return false;
  }
  return telegramAiContainsAny(joined, const [
        'check every area',
        'check all areas',
        'review the site signals',
        'full-site breach result',
        'full site breach result',
      ]) &&
      telegramAiContainsAny(joined, const ['alarm', 'breach', '4am', '04:00']);
}

