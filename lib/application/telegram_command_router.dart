enum OnyxTelegramCommandType {
  liveStatus,
  gateAccess,
  incident,
  dispatch,
  guard,
  report,
  camera,
  intelligence,
  actionRequest,
  clientStatement,
  unknown,
}

class OnyxTelegramCommandRouter {
  const OnyxTelegramCommandRouter();

  static const Set<String> _liveStatusTriggers = <String>{
    'status',
    "what's happening",
    'whats happening',
    'any activity',
    'everything okay',
    'all good',
    'whats on site',
    "what's on site",
    'how many people',
    'how many',
    'count',
    'people on site',
    'anyone on site',
    'who is on site',
    'occupancy',
    'how many residents',
    'anyone home',
    'anyone there',
    'who is home',
  };

  static const Set<String> _gateAccessTriggers = <String>{
    'gate',
    'door',
    'locked',
    'closed',
    'open',
    'access',
    'entry',
  };

  static const Set<String> _incidentTriggers = <String>{
    'incident',
    'what happened',
    'last night',
    'today',
    'yesterday',
    'show incident',
  };

  static const Set<String> _dispatchTriggers = <String>{
    'response',
    'dispatch',
    'eta',
    'arrived',
    'who responded',
  };

  static const Set<String> _guardTriggers = <String>{
    'guard',
    'patrol',
    'checkpoint',
    'guard on site',
    'missed patrol',
  };

  static const Set<String> _reportTriggers = <String>{
    'report',
    'summary',
    'weekly',
    'monthly',
    'send report',
  };

  static const Set<String> _cameraTriggers = <String>{
    'show me',
    'camera',
    'visual',
    'clip',
    'what triggered',
  };

  static const Set<String> _intelligenceTriggers = <String>{
    'most risky',
    'worst day',
    'getting worse',
    'trends',
    'patterns',
    'unusual',
  };

  static const Set<String> _actionRequestTriggers = <String>{
    'send response',
    'escalate',
    'call guard',
    'dispatch',
  };

  // Phrases that identify possession/identity context ("is my dad", "are my kids").
  static const Set<String> _identityPhrases = <String>{
    'is my',
    'are my',
    'is our',
    'are our',
    'that was my',
    'that was our',
    'this is my',
    'that is my',
    'those are my',
    'those are our',
  };

  // Prefixes that signal an informational statement rather than a question.
  static const Set<String> _statementPrefixes = <String>{
    'the ',
    "that's ",
    'thats ',
    "it's ",
    'its ',
    'they ',
    'he ',
    'she ',
    'we ',
    'everyone ',
    'everyone is',
    'all ',
    'i have ',
    "i've ",
    'there is ',
    'there are ',
    'there will ',
    "there'll ",
  };

  static const Set<String> _skipClassificationPhrases = <String>{
    'yes',
    'no',
    'ok',
    'okay',
    'sure',
    'thanks',
    'thank you',
    'got it',
    'understood',
  };

  OnyxTelegramCommandType classify(String message) {
    final normalized = _normalize(message);
    if (normalized.isEmpty) {
      return OnyxTelegramCommandType.unknown;
    }
    if (_shouldSkipClassification(normalized)) {
      return OnyxTelegramCommandType.unknown;
    }
    // Statement check runs first — before topic classifiers — so phrases like
    // "the one person detected is my dad" don't leak into liveStatus/camera.
    if (_looksLikeClientStatement(normalized)) {
      return OnyxTelegramCommandType.clientStatement;
    }

    if (_looksLikeActionRequest(normalized)) {
      return OnyxTelegramCommandType.actionRequest;
    }
    if (_matchesAny(normalized, _intelligenceTriggers)) {
      return OnyxTelegramCommandType.intelligence;
    }
    if (_matchesAny(normalized, _cameraTriggers)) {
      return OnyxTelegramCommandType.camera;
    }
    if (_looksLikeDispatchQuery(normalized)) {
      return OnyxTelegramCommandType.dispatch;
    }
    if (_looksLikeGateAccessQuery(normalized)) {
      return OnyxTelegramCommandType.gateAccess;
    }
    if (_looksLikeIncidentQuery(normalized)) {
      return OnyxTelegramCommandType.incident;
    }
    if (_matchesAny(normalized, _reportTriggers)) {
      return OnyxTelegramCommandType.report;
    }
    if (_looksLikeLiveStatusQuery(normalized)) {
      return OnyxTelegramCommandType.liveStatus;
    }
    if (_looksLikeGuardQuery(normalized)) {
      return OnyxTelegramCommandType.guard;
    }
    return OnyxTelegramCommandType.unknown;
  }

  bool _looksLikeActionRequest(String normalized) {
    if (_matchesAny(normalized, _actionRequestTriggers)) {
      if (normalized == 'dispatch') {
        return true;
      }
      if (normalized.contains('send response') ||
          normalized.contains('send armed response') ||
          normalized.contains('call guard') ||
          normalized.contains('escalate')) {
        return true;
      }
    }
    return normalized.startsWith('dispatch ') ||
        normalized.contains('dispatch now') ||
        normalized.contains('dispatch response') ||
        normalized.contains('call the guard') ||
        normalized.contains('armed response');
  }

  bool _looksLikeDispatchQuery(String normalized) {
    if (normalized.contains('who responded') ||
        normalized.contains('response eta') ||
        normalized.contains('dispatch eta') ||
        normalized.contains('when did') && normalized.contains('arriv')) {
      return true;
    }
    if (_matchesAny(normalized, _dispatchTriggers)) {
      return normalized.contains('response') ||
          normalized.contains('dispatch') ||
          normalized.contains('eta') ||
          normalized.contains('arriv') ||
          normalized.contains('respond');
    }
    return false;
  }

  bool _looksLikeGuardQuery(String normalized) {
    if (normalized.contains('guard on site')) {
      return true;
    }
    return _matchesAny(normalized, _guardTriggers);
  }

  bool _looksLikeLiveStatusQuery(String normalized) {
    if (_matchesAny(normalized, _liveStatusTriggers)) {
      return true;
    }
    if (normalized == 'how many') {
      return true;
    }
    return normalized.contains('how many') &&
        (normalized.contains('people') ||
            normalized.contains('resident') ||
            normalized.contains('occupancy') ||
            normalized.contains('anyone') ||
            normalized.contains('home') ||
            normalized.contains('there') ||
            normalized.contains('on site'));
  }

  bool _looksLikeGateAccessQuery(String normalized) {
    if (_matchesAny(normalized, _gateAccessTriggers)) {
      final hasGateNoun =
          normalized.contains('gate') ||
          normalized.contains('door') ||
          normalized.contains('access') ||
          normalized.contains('entry');
      if (hasGateNoun) {
        return true;
      }
      return normalized.split(' ').where((value) => value.isNotEmpty).length <=
          2;
    }
    final hasGateNoun =
        normalized.contains('gate') ||
        normalized.contains('door') ||
        normalized.contains('access') ||
        normalized.contains('entry');
    if (hasGateNoun) {
      return true;
    }
    final hasStateWord =
        normalized.contains('locked') ||
        normalized.contains('closed') ||
        normalized.contains('open');
    if (!hasStateWord) {
      return false;
    }
    return normalized.split(' ').where((value) => value.isNotEmpty).length <= 2;
  }

  bool _looksLikeIncidentQuery(String normalized) {
    if (_matchesAny(normalized, _incidentTriggers)) {
      return true;
    }
    return normalized.contains('what happened') ||
        normalized.contains('show incident') ||
        normalized.contains('incident history');
  }

  bool _looksLikeClientStatement(String normalized) {
    // Never classify questions as statements.
    if (normalized.contains('?')) return false;
    const questionStarters = <String>[
      'what ', 'when ', 'where ', 'who ', 'why ', 'how ',
      'is ', 'are ', 'was ', 'were ', 'can ', 'could ',
      'did ', 'does ', 'do ', 'will ', 'would ', 'should ',
      'have ', 'has ', 'had ',
    ];
    for (final starter in questionStarters) {
      if (normalized.startsWith(starter)) return false;
    }
    // Statement starters.
    for (final prefix in _statementPrefixes) {
      if (normalized.startsWith(prefix)) return true;
    }
    // Identity/possession mid-sentence.
    if (_matchesAny(normalized, _identityPhrases)) return true;
    // Visitor/schedule announcements ("coming at 8pm", "arriving tonight").
    if ((normalized.contains('coming') ||
            normalized.contains('arriving') ||
            normalized.contains('visitor') ||
            normalized.contains('dropping by')) &&
        !normalized.startsWith('is ') &&
        !normalized.startsWith('are ')) {
      return true;
    }
    return false;
  }

  bool _matchesAny(String normalized, Set<String> phrases) {
    for (final phrase in phrases) {
      if (normalized.contains(phrase)) {
        return true;
      }
    }
    return false;
  }

  bool _shouldSkipClassification(String normalized) {
    if (_skipClassificationPhrases.contains(normalized)) {
      return true;
    }
    final words = normalized.split(' ').where((value) => value.isNotEmpty);
    return words.length == 1 && _skipClassificationPhrases.contains(normalized);
  }

  String _normalize(String message) {
    return message
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
