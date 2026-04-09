enum OnyxTelegramCommandType {
  liveStatus,
  incident,
  dispatch,
  guard,
  report,
  camera,
  intelligence,
  actionRequest,
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
    'on site',
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

  OnyxTelegramCommandType classify(String message) {
    final normalized = _normalize(message);
    if (normalized.isEmpty) {
      return OnyxTelegramCommandType.unknown;
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
    if (_looksLikeGuardQuery(normalized)) {
      return OnyxTelegramCommandType.guard;
    }
    if (_looksLikeIncidentQuery(normalized)) {
      return OnyxTelegramCommandType.incident;
    }
    if (_matchesAny(normalized, _reportTriggers)) {
      return OnyxTelegramCommandType.report;
    }
    if (_matchesAny(normalized, _liveStatusTriggers)) {
      return OnyxTelegramCommandType.liveStatus;
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
    if (normalized == 'on site') {
      return true;
    }
    if (normalized.contains('guard on site')) {
      return true;
    }
    return _matchesAny(normalized, _guardTriggers);
  }

  bool _looksLikeIncidentQuery(String normalized) {
    if (_matchesAny(normalized, _incidentTriggers)) {
      return true;
    }
    return normalized.contains('what happened') ||
        normalized.contains('show incident') ||
        normalized.contains('incident history');
  }

  bool _matchesAny(String normalized, Set<String> phrases) {
    for (final phrase in phrases) {
      if (normalized.contains(phrase)) {
        return true;
      }
    }
    return false;
  }

  String _normalize(String message) {
    return message
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
