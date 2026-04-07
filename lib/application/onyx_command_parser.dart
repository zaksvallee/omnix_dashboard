import '../domain/authority/onyx_command_intent.dart';
import 'telegram_client_prompt_signals.dart';

class OnyxCommandParser {
  const OnyxCommandParser();

  OnyxParsedCommand parse(String prompt) {
    final trimmedPrompt = prompt.trim();
    final hasQuestion = trimmedPrompt.endsWith('?');
    var normalizedPrompt = normalizeTelegramClientPromptSignalText(
      trimmedPrompt.replaceAll(RegExp(r"[’'`]"), ''),
    )
        .replaceAll('tonight s', 'tonights')
        .replaceAll('today s', 'todays');
    if (hasQuestion) {
      normalizedPrompt = '$normalizedPrompt ?';
    }
    final intent = _intentForPrompt(normalizedPrompt);
    return OnyxParsedCommand(intent: intent, prompt: trimmedPrompt);
  }

  OnyxCommandIntent _intentForPrompt(String normalizedPrompt) {
    if (_looksLikeClientDraftPrompt(normalizedPrompt)) {
      return OnyxCommandIntent.draftClientUpdate;
    }
    if (_looksLikePatrolReportPrompt(normalizedPrompt)) {
      return OnyxCommandIntent.patrolReportLookup;
    }
    if (_looksLikeGuardStatusPrompt(normalizedPrompt)) {
      return OnyxCommandIntent.guardStatusLookup;
    }
    if (_looksLikeSiteAlertLeaderPrompt(normalizedPrompt)) {
      return OnyxCommandIntent.showSiteMostAlertsThisWeek;
    }
    if (_looksLikeLastNightIncidentPrompt(normalizedPrompt)) {
      return OnyxCommandIntent.showIncidentsLastNight;
    }
    if (_looksLikeTodayDispatchPrompt(normalizedPrompt)) {
      return OnyxCommandIntent.showDispatchesToday;
    }
    if (_looksLikeUnresolvedIncidentPrompt(normalizedPrompt)) {
      return OnyxCommandIntent.showUnresolvedIncidents;
    }
    if (_looksLikeIncidentSummaryPrompt(normalizedPrompt)) {
      return OnyxCommandIntent.summarizeIncident;
    }
    return OnyxCommandIntent.triageNextMove;
  }

  bool _looksLikeClientDraftPrompt(String normalizedPrompt) {
    final hasDraftVerb =
        normalizedPrompt.contains('draft') ||
        normalizedPrompt.contains('write') ||
        normalizedPrompt.contains('compose') ||
        normalizedPrompt.contains('prepare');
    final hasClientUpdatePhrase =
        normalizedPrompt.contains('client update') ||
        normalizedPrompt.contains('update client') ||
        normalizedPrompt.contains('update the client') ||
        normalizedPrompt.contains('message client') ||
        normalizedPrompt.contains('message the client') ||
        normalizedPrompt.contains('notify client') ||
        normalizedPrompt.contains('inform client');
    final hasClientContext =
        normalizedPrompt.contains('client') ||
        normalizedPrompt.contains('resident') ||
        normalizedPrompt.contains('telegram') ||
        normalizedPrompt.contains('sms') ||
        normalizedPrompt.contains('comms') ||
        normalizedPrompt.contains('message') ||
        normalizedPrompt.contains('update');
    return hasClientUpdatePhrase || (hasDraftVerb && hasClientContext);
  }

  bool _looksLikeGuardStatusPrompt(String normalizedPrompt) {
    final asksAboutGuard =
        normalizedPrompt.contains('guard') ||
        normalizedPrompt.contains('patrol') ||
        normalizedPrompt.contains('check-in') ||
        normalizedPrompt.contains('check in');
    final genericGuardStatusAsk =
        (normalizedPrompt.contains('check status of') ||
            normalizedPrompt.contains('status of')) &&
        !normalizedPrompt.contains('client') &&
        !normalizedPrompt.contains('incident') &&
        !normalizedPrompt.contains('dispatch') &&
        !normalizedPrompt.contains('camera') &&
        !normalizedPrompt.contains('cctv') &&
        !normalizedPrompt.contains('site');
    final asksForState =
        normalizedPrompt.contains('status') ||
        normalizedPrompt.contains('where') ||
        normalizedPrompt.contains('route') ||
        normalizedPrompt.contains('last patrol') ||
        normalizedPrompt.contains('last check') ||
        normalizedPrompt.contains('check');
    return (asksAboutGuard && asksForState) || genericGuardStatusAsk;
  }

  bool _looksLikePatrolReportPrompt(String normalizedPrompt) {
    final asksAboutPatrol =
        normalizedPrompt.contains('patrol') ||
        normalizedPrompt.contains('checkpoint');
    final asksForReport =
        normalizedPrompt.contains('report') ||
        normalizedPrompt.contains('proof') ||
        normalizedPrompt.contains('completed') ||
        normalizedPrompt.contains('completion');
    final asksForRecent =
        normalizedPrompt.contains('last') ||
        normalizedPrompt.contains('latest') ||
        normalizedPrompt.contains('recent') ||
        normalizedPrompt.contains('show') ||
        normalizedPrompt.contains('provide');
    return asksAboutPatrol && asksForReport && asksForRecent;
  }

  bool _looksLikeIncidentSummaryPrompt(String normalizedPrompt) {
    final asksAboutIncident =
        normalizedPrompt.contains('incident') ||
        normalizedPrompt.contains('alarm') ||
        normalizedPrompt.contains('signal') ||
        normalizedPrompt.contains('robbery') ||
        normalizedPrompt.contains('robbed') ||
        normalizedPrompt.contains('theft') ||
        normalizedPrompt.contains('burglary');
    final asksForSummary =
        normalizedPrompt.contains('summary') ||
        normalizedPrompt.contains('summarize') ||
        normalizedPrompt.contains('brief') ||
        normalizedPrompt.contains('what happened') ||
        normalizedPrompt.contains('recap') ||
        normalizedPrompt.contains('aware of') ||
        normalizedPrompt.contains('were you aware') ||
        normalizedPrompt.contains('are you aware');
    return _looksLikeHistoricalIncidentReviewPrompt(normalizedPrompt) ||
        (asksAboutIncident && asksForSummary);
  }

  bool _looksLikeHistoricalIncidentReviewPrompt(String normalizedPrompt) {
    final compactPrompt = normalizedPrompt
        .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final mentionsHistoricalIncident =
        compactPrompt.contains('robbery') ||
        compactPrompt.contains('robbed') ||
        compactPrompt.contains('theft') ||
        compactPrompt.contains('burglary') ||
        compactPrompt.contains('stolen');
    final hasHistoricalCue =
        compactPrompt.contains('earlier today') ||
        compactPrompt.contains('earlier') ||
        compactPrompt.contains('took place') ||
        compactPrompt.contains('happened') ||
        compactPrompt.contains('that occurred');
    final asksAwarenessOrReview =
        compactPrompt.contains('are you aware') ||
        compactPrompt.contains('were you aware') ||
        compactPrompt.contains('did you know about') ||
        compactPrompt.contains('asking if you were aware') ||
        compactPrompt.contains('asking if') ||
        compactPrompt.contains('what happened') ||
        compactPrompt.contains('review') ||
        compactPrompt.contains('recap');
    return mentionsHistoricalIncident &&
        hasHistoricalCue &&
        asksAwarenessOrReview;
  }

  bool _looksLikeUnresolvedIncidentPrompt(String normalizedPrompt) {
    final compactPrompt = normalizedPrompt
        .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final asksAboutIncidents =
        compactPrompt.contains('incident') ||
        compactPrompt.contains('incidents') ||
        compactPrompt.contains('alarm') ||
        compactPrompt.contains('alerts') ||
        compactPrompt.contains('fire') ||
        compactPrompt.contains('medical') ||
        compactPrompt.contains('ambulance') ||
        compactPrompt.contains('ambulnce') ||
        compactPrompt.contains('police') ||
        compactPrompt.contains('breach') ||
        compactPrompt.contains('breaches');
    final asksForList =
        compactPrompt.contains('show') ||
        compactPrompt.contains('list') ||
        compactPrompt.contains('which') ||
        compactPrompt.contains('check') ||
        compactPrompt.contains('status') ||
        compactPrompt.contains('update') ||
        compactPrompt.contains('here') ||
        compactPrompt.contains('now') ||
        compactPrompt.contains('any ');
    final asksForOpenItems =
        compactPrompt.contains('unresolved') ||
        compactPrompt.contains('open incidents') ||
        compactPrompt.contains('active incidents') ||
        compactPrompt.contains('still open');
    final startsQueryStyleLookup =
        compactPrompt.startsWith('is there ') ||
        compactPrompt.startsWith('are there ') ||
        compactPrompt.startsWith('do we have ');
    final bareQuestionLookup =
        normalizedPrompt.trim().endsWith('?') &&
        const <String>{
          'fire',
          'medical',
          'ambulance',
          'ambulnce',
          'police',
          'breach',
          'breaches',
        }.contains(compactPrompt);
    final scopedQuestionLookup = _hasScopedQuestionLookupCue(
      normalizedPrompt,
      compactPrompt,
    );
    return asksAboutIncidents &&
        (asksForOpenItems ||
            asksForList ||
            startsQueryStyleLookup ||
            bareQuestionLookup ||
            scopedQuestionLookup);
  }

  bool _looksLikeTodayDispatchPrompt(String normalizedPrompt) {
    final asksAboutDispatch =
        normalizedPrompt.contains('dispatch') ||
        normalizedPrompt.contains('dispatches');
    final asksAboutToday =
        normalizedPrompt.contains('today') ||
        normalizedPrompt.contains("today's") ||
        normalizedPrompt.contains('todays');
    final asksForList =
        normalizedPrompt.contains('show') ||
        normalizedPrompt.contains('list') ||
        normalizedPrompt.contains('what') ||
        normalizedPrompt.contains('which') ||
        normalizedPrompt.contains('check') ||
        normalizedPrompt.startsWith('dispatch') ||
        normalizedPrompt.startsWith('today') ||
        normalizedPrompt.startsWith('todays');
    return asksAboutDispatch && asksAboutToday && asksForList;
  }

  bool _looksLikeSiteAlertLeaderPrompt(String normalizedPrompt) {
    final asksAboutSites =
        normalizedPrompt.contains('site') ||
        normalizedPrompt.contains('sites') ||
        normalizedPrompt.contains('estate') ||
        normalizedPrompt.contains('residence');
    final asksAboutAlerts =
        normalizedPrompt.contains('alert') ||
        normalizedPrompt.contains('alerts') ||
        normalizedPrompt.contains('alarm') ||
        normalizedPrompt.contains('alarms') ||
        normalizedPrompt.contains('intel') ||
        normalizedPrompt.contains('intelligence');
    final asksTopSite =
        normalizedPrompt.contains('top site') ||
        normalizedPrompt.contains('top property') ||
        normalizedPrompt.contains('top estate') ||
        normalizedPrompt.contains('top residence');
    final asksAboutThisWeek =
        normalizedPrompt.contains('this week') ||
        normalizedPrompt.contains('weekly');
    final asksForLeader =
        normalizedPrompt.contains('which site has most') ||
        normalizedPrompt.contains('site has most') ||
        normalizedPrompt.contains('most alerts') ||
        normalizedPrompt.contains('highest alerts') ||
        asksTopSite;
    return asksAboutSites &&
        (asksAboutAlerts || asksTopSite) &&
        asksAboutThisWeek &&
        asksForLeader;
  }

  bool _looksLikeLastNightIncidentPrompt(String normalizedPrompt) {
    final compactPrompt = normalizedPrompt
        .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final asksAboutIncidents =
        compactPrompt.contains('incident') ||
        compactPrompt.contains('incidents') ||
        compactPrompt.contains('alarm') ||
        compactPrompt.contains('alerts') ||
        compactPrompt.contains('breach') ||
        compactPrompt.contains('breaches') ||
        compactPrompt.contains('fire') ||
        compactPrompt.contains('medical') ||
        compactPrompt.contains('ambulance') ||
        compactPrompt.contains('ambulnce') ||
        compactPrompt.contains('police');
    final asksForOvernightUpdate =
        normalizedPrompt.contains('changed') ||
        normalizedPrompt.contains('happened');
    final asksForQueryStyleLookup =
        normalizedPrompt.startsWith('is there ') ||
        normalizedPrompt.startsWith('are there ') ||
        normalizedPrompt.startsWith('do we have ');
    final asksAboutLastNight =
        normalizedPrompt.contains('last night') ||
        normalizedPrompt.contains('overnight') ||
        normalizedPrompt.contains('tonight') ||
        normalizedPrompt.contains("tonight's") ||
        normalizedPrompt.contains('tonights');
    final asksForList =
        normalizedPrompt.contains('show') ||
        normalizedPrompt.contains('list') ||
        normalizedPrompt.contains('what') ||
        normalizedPrompt.contains('which') ||
        normalizedPrompt.contains('changed') ||
        normalizedPrompt.contains('happened') ||
        normalizedPrompt.contains('check') ||
        normalizedPrompt.contains('any ') ||
        normalizedPrompt.startsWith('tonight') ||
        normalizedPrompt.startsWith('last night') ||
        normalizedPrompt.startsWith('overnight');
    final scopedQuestionLookup = _hasScopedQuestionLookupCue(
      normalizedPrompt,
      compactPrompt,
    );
    return (asksAboutIncidents || asksForOvernightUpdate) &&
        asksAboutLastNight &&
        (asksForList || asksForQueryStyleLookup || scopedQuestionLookup);
  }

  bool _hasScopedQuestionLookupCue(
    String normalizedPrompt,
    String compactPrompt,
  ) {
    final isQuestion = normalizedPrompt.trim().endsWith('?');
    final hasScopeReference =
        compactPrompt.contains(' at ') ||
        compactPrompt.contains(' across ') ||
        compactPrompt.contains(' for ') ||
        compactPrompt.contains(' this site') ||
        compactPrompt.contains(' the site') ||
        compactPrompt.contains(' on site') ||
        compactPrompt.contains(' on the site');
    final hasMultiSiteScope =
        compactPrompt.contains(' sites') ||
        compactPrompt.contains(' properties') ||
        compactPrompt.contains(' estates') ||
        compactPrompt.contains(' residences');
    final hasLookupSummaryNoun =
        compactPrompt.contains('activity') ||
        compactPrompt.contains('issues') ||
        compactPrompt.contains('incident') ||
        compactPrompt.contains('incidents') ||
        compactPrompt.contains('alarm') ||
        compactPrompt.contains('alerts') ||
        compactPrompt.contains('breach') ||
        compactPrompt.contains('breaches');
    return isQuestion &&
        hasLookupSummaryNoun &&
        (hasScopeReference || hasMultiSiteScope);
  }
}
