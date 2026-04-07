import 'telegram_client_quick_action_service.dart';
import 'telegram_client_prompt_signals.dart';

const _telegramClientQuickActionService = TelegramClientQuickActionService();

bool shouldPreferTelegramAiOverOnyxCommand({
  required String prompt,
  required List<String> recentContextTexts,
}) {
  final normalizedPrompt = _normalizeTelegramClientRouterText(prompt);
  final joinedContext = recentContextTexts
      .map(_normalizeTelegramClientRouterText)
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (normalizedPrompt.isEmpty) {
    return false;
  }
  if (_telegramClientQuickActionService.parseActionText(prompt) != null) {
    return true;
  }
  if (asksForTelegramClientBroadStatusOrCurrentSiteView(normalizedPrompt) ||
      asksForTelegramClientMovementCheck(normalizedPrompt) ||
      asksForTelegramClientCurrentSiteIssueCheck(normalizedPrompt)) {
    return true;
  }
  final gratitudeAlertWatch =
      _containsAny(normalizedPrompt, const [
        'thank you',
        'thanks',
        'appreciate it',
        'thank you for assisting',
      ]) &&
      _containsAny(normalizedPrompt, const [
        'keep me posted',
        'keep me updated',
        'serious alerts',
        'serious alert',
        'anything serious',
        'let me know if anything changes',
      ]);
  if (gratitudeAlertWatch) {
    return true;
  }
  final reassuranceAsk =
      asksForTelegramClientBroadReassuranceCheck(normalizedPrompt);
  final telemetryOrOfflineContext = _containsAny(joinedContext, const [
    'site activity summary',
    'field telemetry',
    'latest field signal',
    'not sitting as an open incident',
    'remote monitoring is offline',
    'temporarily without remote monitoring',
  ]);
  if (reassuranceAsk && telemetryOrOfflineContext) {
    return true;
  }
  final cameraReassuranceAsk =
      _containsAny(normalizedPrompt, const [
        'did you check cameras',
        'did you check the cameras',
        'did you check camera',
        'camera check',
      ]) &&
      _containsAny(normalizedPrompt, const [
        'all good',
        'everything good',
        'everything okay',
        'safe',
        'okay',
        'ok',
      ]);
  if (cameraReassuranceAsk) {
    return true;
  }
  final genericStatusFollowUp =
      asksForTelegramClientGenericStatusFollowUp(normalizedPrompt);
  final presenceVerificationContext = _containsAny(joinedContext, const [
    'site activity summary',
    'field telemetry',
    'latest field signal',
    'response-arrival signal',
    'recorded onyx telemetry activity',
    'recorded onyx field telemetry',
    'recorded guard or response activity signals',
    'not confirmed guards physically on site',
    'no guard is confirmed on site',
    'confirmed guard on site',
    'current response position',
    'verified position update',
    'there are no guards',
    'there is no guard',
    'no guards at',
    'no guards on',
    'security is not on site',
    'security not on site',
  ]);
  if (genericStatusFollowUp && presenceVerificationContext) {
    return true;
  }
  final issueClarifierAsk = _containsAny(normalizedPrompt, const [
    'is there an issue',
    'is there a problem',
    'is something wrong',
    'what is the issue',
    'what issue',
    'what problem',
    'issue at my site',
    'problem at my site',
  ]);
  if (issueClarifierAsk && presenceVerificationContext) {
    return true;
  }
  final continuousVisualWatchContext = _containsAny(joinedContext, const [
    'continuous visual watch',
    'live visual change',
    'active scene change',
  ]);
  if (genericStatusFollowUp && continuousVisualWatchContext) {
    return true;
  }
  final operationalPictureClarifier =
      _containsAny(normalizedPrompt, const [
        'what current operational picture',
        'what operational picture',
        'what do you mean operational picture',
      ]) &&
      _containsAny(joinedContext, const [
        'current operational picture',
        'live camera check',
        'community reports',
      ]);
  if (operationalPictureClarifier) {
    return true;
  }
  final clientCorrection = _containsAny(normalizedPrompt, const [
    'my cameras are down',
    'cameras are down',
    'camera is down',
    'camera down',
    'cctv is down',
    'cctv down',
    'cameras are online',
    'camera is online',
    'cameras online',
    'camera online',
    'cameras are not offline',
    'camera is not offline',
    'cameras are not down',
    'camera is not down',
    'bridge is online',
    'bridge online',
    'bridge is not offline',
    'security is not on site',
    'security not on site',
    'security isnt on site',
    'security is not there',
    'security isnt there',
    'there are no guards',
    'there is no guard',
    'no guards at',
    'no guards on',
  ]);
  if (clientCorrection) {
    return true;
  }
  return false;
}

bool _containsAny(String haystack, List<String> needles) {
  for (final needle in needles) {
    if (needle.isEmpty) {
      continue;
    }
    if (haystack.contains(needle)) {
      return true;
    }
  }
  return false;
}

String _normalizeTelegramClientRouterText(String value) {
  return normalizeTelegramClientPromptSignalText(value);
}
