String normalizeTelegramClientPromptSignalText(String value) {
  final raw = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r"[’'`]"), '')
      .replaceAll(RegExp(r'[^a-z0-9_\s]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (raw.isEmpty) {
    return raw;
  }
  const replacements = <String, String>{
    'whats': 'what',
    'whts': 'what',
    'whatst': 'what',
    'happendin': 'happening',
    'happednin': 'happening',
    'hapening': 'happening',
    'hapenning': 'happening',
    'happenning': 'happening',
    'happenong': 'happening',
    'siter': 'site',
    'sitre': 'site',
    'stauts': 'status',
    'evrything': 'everything',
    'anyting': 'anything',
    'rong': 'wrong',
    'oky': 'okay',
  };
  return raw
      .split(' ')
      .where((token) => token.trim().isNotEmpty)
      .map((token) => replacements[token] ?? token)
      .join(' ');
}

bool asksForTelegramClientBroadStatusCheck(String normalizedMessage) {
  final normalized = normalizeTelegramClientPromptSignalText(normalizedMessage);
  return _containsAny(normalized, const [
    'hows everything',
    'how is everything',
    'everything okay',
    'everything is okay',
    'everything good',
    'everything is good',
    'all good',
    'site okay',
    'site is okay',
    'property okay',
    'check site status',
    'check the site status',
    'check status on site',
    'check status at site',
  ]);
}

bool asksForTelegramClientBroadStatusOrCurrentSiteView(
  String normalizedMessage,
) {
  return asksForTelegramClientBroadStatusCheck(normalizedMessage) ||
      asksForTelegramClientCurrentSiteView(normalizedMessage);
}

bool asksForTelegramClientBroadReassuranceCheck(String normalizedMessage) {
  final normalized = normalizeTelegramClientPromptSignalText(normalizedMessage);
  return asksForTelegramClientBroadStatusCheck(normalized) ||
      _containsAny(normalized, const [
        'safe',
        'secure',
        'you sure',
        'are you sure',
      ]);
}

bool asksForTelegramClientCurrentSiteIssueCheck(String normalizedMessage) {
  final normalized = normalizeTelegramClientPromptSignalText(normalizedMessage);
  return _containsAny(normalized, const [
    'is there an issue',
    'is there any issue',
    'is there a problem',
    'is there any problem',
    'is something wrong',
    'what is the issue',
    'what issue',
    'what problem',
    'issue at my site',
    'problem at my site',
  ]);
}

bool asksForTelegramClientMovementCheck(String normalizedMessage) {
  final normalized = normalizeTelegramClientPromptSignalText(normalizedMessage);
  return _containsAny(normalized, const [
    'any movement',
    'any movement detected',
    'is there movement',
    'is there any movement',
    'is there any movement detected',
    'do you see movement',
    'see movement',
    'movement there',
    'movement now',
    'movement detected',
    'movement detection',
    'has any movement been detected',
    'anything moving',
    'anyone moving',
    'movement on camera',
  ]);
}

bool asksForTelegramClientCurrentSiteView(String normalizedMessage) {
  final normalized = normalizeTelegramClientPromptSignalText(normalizedMessage);
  return _containsAny(normalized, const [
    'hows the site',
    'how is the site',
    'hows everything on site',
    'how is everything on site',
    'hows everything at the site',
    'how is everything at the site',
    'hows the property',
    'how is the property',
    'hows everything there',
    'how is everything there',
    'whats happening on site',
    'what is happening on site',
    'what happening on site',
    'whats happening at site',
    'what is happening at site',
    'what happening at site',
    'whats happening at the site',
    'what is happening at the site',
    'what happening at the site',
    'whats happening there',
    'what is happening there',
    'what happening there',
    'whats going on there',
    'what is going on there',
    'what going on there',
    'whats happening now',
    'what is happening now',
    'what happening now',
    'whats happening right now',
    'what is happening right now',
    'what happening right now',
    'whats going on now',
    'what is going on now',
    'what going on now',
    'what are you seeing on site now',
    'what are you seeing right now',
    'what are you seeing now',
    'what do you see on site now',
    'what do you see right now',
    'give me a current view of whats happening on site',
    'give me a current view of what is happening on site',
    'give me a current view',
    'current view of whats happening on site',
    'current view of what is happening on site',
  ]);
}

bool asksForTelegramClientGenericStatusFollowUp(String normalizedMessage) {
  final normalized = normalizeTelegramClientPromptSignalText(normalizedMessage);
  if (normalized.isEmpty) {
    return false;
  }
  if (_looksLikeShortTelegramClientFollowUp(normalized)) {
    return true;
  }
  return _containsAny(normalized, const [
    'whats the update',
    'what is the update',
    'live update',
    'give me an update',
    'give me a live update',
    'update on the site',
    'update on site',
    'update on the premises',
    'update on premises',
    'site update',
    'premises update',
    'property update',
  ]);
}

bool _looksLikeShortTelegramClientFollowUp(String normalizedMessage) {
  if (normalizedMessage.isEmpty) {
    return false;
  }
  if (normalizedMessage.split(RegExp(r'\s+')).length > 6) {
    return false;
  }
  return _containsAny(normalizedMessage, const [
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
