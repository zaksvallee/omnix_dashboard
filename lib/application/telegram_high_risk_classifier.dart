import 'telegram_client_prompt_signals.dart';

class TelegramHighRiskClassifier {
  const TelegramHighRiskClassifier();

  bool isHighRiskMessage(String text) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) {
      return false;
    }
    if (_looksLikeHistoricalIncidentReview(normalized)) {
      return false;
    }
    if (_looksLikeHypotheticalEscalationQuestion(normalized)) {
      return false;
    }
    if (_looksLikeLookupQuestion(normalized)) {
      return false;
    }
    return _highRiskKeywords.any(normalized.contains) ||
        _matchesEmergencyDistressPattern(normalized);
  }

  static const List<String> _highRiskKeywords = <String>[
    'panic',
    'duress',
    'armed',
    'gun',
    'weapon',
    'intruder',
    'break in',
    'breach',
    'fire',
    'medical',
    'ambulance',
    'ambulnce',
    'police',
    'hostage',
    'bomb',
  ];

  bool _looksLikeLookupQuestion(String normalized) {
    final compact = normalized
        .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (compact.isEmpty || !_highRiskKeywords.any(compact.contains)) {
      return false;
    }

    final startsLookupPrefix =
        compact.startsWith('check ') ||
        compact.startsWith('show ') ||
        compact.startsWith('any ') ||
        compact.startsWith('is there ') ||
        compact.startsWith('are there ') ||
        compact.startsWith('do we have ');
    final hasLookupCue =
        compact.contains(' status') ||
        compact.endsWith(' status') ||
        compact.contains(' update') ||
        compact.endsWith(' update') ||
        compact.contains(' here') ||
        compact.endsWith(' here') ||
        compact.contains(' now') ||
        compact.endsWith(' now');
    final bareQuestionLookup =
        normalized.trim().endsWith('?') &&
        const <String>{
          'fire',
          'medical',
          'ambulance',
          'ambulnce',
          'police',
          'breach',
          'breaches',
        }.contains(compact);
    final scopedQuestionLookup = _hasScopedQuestionLookupCue(
      normalized,
      compact,
    );
    final assertsActiveIncident =
        compact.startsWith('there is ') ||
        compact.startsWith('theres ') ||
        compact.startsWith('we have ') ||
        compact.contains('need ') ||
        compact.contains('send ') ||
        compact.contains('call ') ||
        compact.contains('help ') ||
        compact.contains('inside ');

    return !assertsActiveIncident &&
        (startsLookupPrefix ||
            hasLookupCue ||
            bareQuestionLookup ||
            scopedQuestionLookup);
  }

  bool _hasScopedQuestionLookupCue(String normalized, String compact) {
    final isQuestion = normalized.trim().endsWith('?');
    final hasScopeReference =
        compact.contains(' at ') ||
        compact.contains(' across ') ||
        compact.contains(' for ') ||
        compact.contains(' this site') ||
        compact.contains(' the site') ||
        compact.contains(' on site') ||
        compact.contains(' on the site');
    final hasMultiSiteScope =
        compact.contains(' sites') ||
        compact.contains(' properties') ||
        compact.contains(' estates') ||
        compact.contains(' residences');
    final hasLookupSummaryNoun =
        compact.contains('activity') ||
        compact.contains('issues') ||
        compact.contains('incident') ||
        compact.contains('incidents') ||
        compact.contains('alarm') ||
        compact.contains('alerts') ||
        compact.contains('breach') ||
        compact.contains('breaches');
    return isQuestion &&
        hasLookupSummaryNoun &&
        (hasScopeReference || hasMultiSiteScope);
  }

  bool _looksLikeHistoricalIncidentReview(String normalized) {
    final compact = normalized
        .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (compact.isEmpty) {
      return false;
    }
    final mentionsHistoricalIncident =
        compact.contains('robbery') ||
        compact.contains('robbed') ||
        compact.contains('theft') ||
        compact.contains('burglary') ||
        compact.contains('stolen');
    if (!mentionsHistoricalIncident) {
      return false;
    }
    final asksAwarenessOrReview =
        compact.contains('are you aware') ||
        compact.contains('were you aware') ||
        compact.contains('did you know about') ||
        compact.contains('asking if you were aware') ||
        compact.contains('asking if') ||
        compact.contains('what happened') ||
        compact.contains('review');
    final hasHistoricalCue =
        compact.contains('earlier today') ||
        compact.contains('earlier') ||
        compact.contains('took place') ||
        compact.contains('happened') ||
        compact.contains('that occurred');
    final framesCurrentDanger =
        compact.contains('being robbed now') ||
        compact.contains('i am being robbed') ||
        compact.contains('im being robbed') ||
        compact.contains('currently being robbed');
    return !framesCurrentDanger &&
        hasHistoricalCue &&
        asksAwarenessOrReview;
  }

  bool _looksLikeHypotheticalEscalationQuestion(String normalized) {
    final compact = normalized
        .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (compact.isEmpty) {
      return false;
    }
    final asksEscalationCapability =
        compact.contains('can you escalate') ||
        compact.contains('could you escalate') ||
        compact.contains('would you escalate') ||
        compact.contains('will you escalate') ||
        compact.contains('can onyx escalate') ||
        compact.contains('can you help if');
    final conditionalOrHypothetical =
        compact.startsWith('if ') ||
        compact.contains(' if ') ||
        compact.contains('if i need help') ||
        compact.contains('if i need urgent help') ||
        compact.contains('if i need assistance') ||
        compact.contains('if something happens') ||
        compact.contains('if theres a problem') ||
        compact.contains('if there is a problem');
    final asksAsQuestion = normalized.trim().endsWith('?');
    return asksEscalationCapability &&
        conditionalOrHypothetical &&
        asksAsQuestion;
  }

  bool _matchesEmergencyDistressPattern(String normalized) {
    final compact = normalized
        .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (compact.isEmpty) {
      return false;
    }
    final hearsGlassBreaking =
        compact.contains('glass breaking') ||
        compact.contains('glass break') ||
        compact.contains('breaking glass');
    final someoneInside =
        compact.contains('someone is in the house') ||
        compact.contains('someone in the house') ||
        compact.contains('in my house') ||
        compact.contains('inside the house');
    final robberyReport =
        compact.contains('got robbed') ||
        compact.contains('been robbed') ||
        compact.contains('i was robbed') ||
        compact.contains('being robbed') ||
        compact.contains('robbery');
    final distressHelp =
        compact == 'help' ||
        compact.startsWith('help ') ||
        compact.contains(' help ') ||
        normalized.contains('!') && compact.contains('help') ||
        normalized.contains('aaaa');
    return hearsGlassBreaking ||
        someoneInside ||
        robberyReport ||
        distressHelp;
  }

  String _normalize(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final hasQuestion = trimmed.endsWith('?');
    final hasExclamation = trimmed.contains('!');
    var normalized = normalizeTelegramClientPromptSignalText(trimmed)
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) {
      return normalized;
    }
    if (hasExclamation) {
      normalized = '$normalized !';
    }
    if (hasQuestion) {
      normalized = '$normalized ?';
    }
    return normalized.trim();
  }
}
