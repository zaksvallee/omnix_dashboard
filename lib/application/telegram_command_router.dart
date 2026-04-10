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
  visitorRegistration,
  frOnboarding,
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
    'whos home',
    'which cars are home',
    'which car is home',
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
    'did guard patrol',
    'guard status',
  };

  static const Set<String> _reportTriggers = <String>{
    'report',
    'summary',
    'weekly',
    'monthly',
    'send report',
    'patrol report',
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

  static const Set<String> _visitorRegistrationTriggers = <String>{
    'cleaner is coming',
    'cleaner is here',
    'there is a cleaner',
    'cleaner on site',
    'expecting a visitor',
    'contractor coming tomorrow',
    'contractor is here',
    'gardener today',
    'cleaner came',
    'someone is working on site',
    'visitor coming',
    'delivery coming',
    'cleaner coming',
    'gardener coming',
    'contractor coming',
    'is here',
    'are here',
    'just arrived',
    'came in',
    'letting in',
    'opening for',
    'leaving now',
    'just left',
    'gone now',
  };

  static const Set<String> _frOnboardingTriggers = <String>{
    'add to the system',
    'add to onyx',
    'register as a resident',
    'register as resident',
    'register in the system',
    'enrol in the system',
    'enroll in the system',
    'add resident',
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
    if (_looksLikeFrOnboarding(normalized)) {
      return OnyxTelegramCommandType.frOnboarding;
    }
    if (_looksLikeVisitorRegistration(normalized)) {
      return OnyxTelegramCommandType.visitorRegistration;
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
    if (normalized.contains('how many') &&
        (normalized.contains('people') ||
            normalized.contains('resident') ||
            normalized.contains('occupancy') ||
            normalized.contains('anyone') ||
            normalized.contains('home') ||
            normalized.contains('there') ||
            normalized.contains('on site'))) {
      return true;
    }
    if (normalized.contains('which cars are home') ||
        normalized.contains('which car is home') ||
        normalized.contains('whos home')) {
      return true;
    }
    if (normalized.startsWith('is ') && normalized.endsWith(' home')) {
      return true;
    }
    if (normalized.startsWith('did ') && normalized.contains(' arrive')) {
      return true;
    }
    return false;
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

  bool _looksLikeVisitorRegistration(String normalized) {
    const questionStarters = <String>[
      'what ',
      'when ',
      'where ',
      'who ',
      'why ',
      'how ',
      'is ',
      'are ',
      'was ',
      'were ',
      'can ',
      'could ',
      'did ',
      'does ',
      'do ',
      'will ',
      'would ',
      'should ',
      'have ',
      'has ',
      'had ',
    ];
    for (final starter in questionStarters) {
      if (normalized.startsWith(starter)) {
        return false;
      }
    }
    if (_matchesAny(normalized, _visitorRegistrationTriggers)) {
      return true;
    }
    final isArrivalPhrase =
        normalized.contains(' is here') ||
        normalized.contains(' are here') ||
        normalized.contains(' just arrived') ||
        normalized.contains(' came in') ||
        normalized.contains(' arrived') ||
        normalized.contains(' letting in') ||
        normalized.contains(' opening for');
    final isDeparturePhrase =
        normalized.contains(' leaving now') ||
        normalized.contains(' just left') ||
        normalized.contains(' gone now') ||
        normalized.contains(' visitor gone') ||
        normalized.contains(' cleaner leaving');
    if (isDeparturePhrase) {
      return true;
    }
    final mentionsVisitorRole =
        normalized.contains('cleaner') ||
        normalized.contains('gardener') ||
        normalized.contains('contractor') ||
        normalized.contains('visitor') ||
        normalized.contains('delivery');
    final hasDurationHint =
        normalized.contains(' until ') ||
        RegExp(r'\bfor\s+\d+\s+hours?\b').hasMatch(normalized) ||
        normalized.contains('lunchtime');
    if (mentionsVisitorRole) {
      return normalized.contains('coming') ||
          normalized.contains('expecting') ||
          normalized.contains('today') ||
          normalized.contains('tomorrow') ||
          normalized.contains('arriving') ||
          normalized.contains('here') ||
          normalized.contains('on site') ||
          normalized.contains('working') ||
          hasDurationHint;
    }
    if (hasDurationHint && isArrivalPhrase) {
      return true;
    }
    return RegExp(r"^[a-z][a-z'-]*(?:\s+[a-z][a-z'-]*)?\s+is\s+here\b")
            .hasMatch(normalized) ||
        RegExp(r"^[a-z][a-z'-]*(?:\s+[a-z][a-z'-]*)?\s+just\s+arrived\b")
            .hasMatch(normalized);
  }

  bool _looksLikeFrOnboarding(String normalized) {
    if (_matchesAny(normalized, _frOnboardingTriggers)) {
      return true;
    }
    final includesAdd = normalized.contains('add ');
    final includesRegister =
        normalized.contains('register ') || normalized.contains('enroll ');
    final includesPersonContext =
        normalized.contains('resident') ||
        normalized.contains('staff') ||
        normalized.contains('guard') ||
        normalized.contains('visitor') ||
        normalized.contains('system') ||
        normalized.contains('recognition');
    return (includesAdd || includesRegister) && includesPersonContext;
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
