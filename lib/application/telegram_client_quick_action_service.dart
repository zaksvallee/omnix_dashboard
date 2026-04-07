import 'client_camera_health_fact_packet_service.dart';
import 'monitoring_shift_notification_service.dart';
import 'monitoring_shift_schedule_service.dart';
import 'monitoring_watch_runtime_store.dart';
import 'telegram_client_prompt_signals.dart';

enum TelegramClientQuickAction {
  status,
  statusFull,
  sleepCheck,
  cameraCheck,
  nextStep,
}

enum _QuickActionTonePack { standard, residential, enterprise }

class TelegramClientQuickActionService {
  const TelegramClientQuickActionService();

  TelegramClientQuickAction? parseInboundActionText(String text) {
    return parseExplicitShortcutText(text) ?? parseActionText(text);
  }

  TelegramClientQuickAction? parseExplicitShortcutText(String text) {
    final normalized = _normalizeActionText(text);
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized == 'client_quick_status') {
      return TelegramClientQuickAction.status;
    }
    if (normalized == 'client_quick_status_full') {
      return TelegramClientQuickAction.statusFull;
    }
    if (normalized == 'client_quick_sleep_check') {
      return TelegramClientQuickAction.sleepCheck;
    }
    if (normalized == 'status' ||
        normalized == 'status here' ||
        normalized == 'status now' ||
        normalized == 'site status' ||
        normalized == 'status full' ||
        normalized == 'full status' ||
        normalized == 'details' ||
        normalized == 'details here') {
      return normalized == 'status full' ||
              normalized == 'full status' ||
              normalized == 'details' ||
              normalized == 'details here'
          ? TelegramClientQuickAction.statusFull
          : TelegramClientQuickAction.status;
    }
    if (normalized == 'sleep check' ||
        normalized == 'all in order' ||
        normalized == 'bedtime check') {
      return TelegramClientQuickAction.sleepCheck;
    }
    return null;
  }

  Map<String, Object?> replyKeyboardMarkup() {
    return const <String, Object?>{
      'keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': 'Status'},
          <String, String>{'text': 'Details'},
        ],
        <Map<String, String>>[
          <String, String>{'text': 'Sleep check'},
        ],
      ],
      'resize_keyboard': true,
      'one_time_keyboard': false,
      'is_persistent': true,
      'input_field_placeholder': 'Tap Status, Details, or Sleep check',
    };
  }

  TelegramClientQuickAction? parseActionText(String text) {
    final normalized = _normalizeActionText(text);
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized == 'client_quick_status') {
      return TelegramClientQuickAction.status;
    }
    if (normalized == 'client_quick_status_full') {
      return TelegramClientQuickAction.statusFull;
    }
    if (normalized == 'status' ||
        normalized == 'status here' ||
        normalized == 'status now' ||
        normalized == 'site status' ||
        normalized == 'site stauts' ||
        normalized == 'status update' ||
        normalized == 'is my site secure' ||
        normalized == 'is the site secure' ||
        normalized == 'is my site secure now' ||
        normalized == 'is everything secure at the site' ||
        normalized == 'is everything okay' ||
        normalized == 'anything wrong there' ||
        asksForTelegramClientBroadStatusOrCurrentSiteView(normalized)) {
      return TelegramClientQuickAction.status;
    }
    if (normalized == 'details' ||
        normalized == 'status full' ||
        normalized == 'full status' ||
        normalized == 'details here') {
      return TelegramClientQuickAction.statusFull;
    }
    if (normalized == 'brief' ||
        normalized == 'brief this site' ||
        normalized == 'brief the site' ||
        normalized == 'give me the site brief' ||
        normalized == 'give me a site brief' ||
        normalized == 'brief here' ||
        normalized == 'site brief' ||
        normalized == 'give me a quick update' ||
        normalized == 'give me an update here' ||
        normalized == 'give me an update' ||
        normalized == 'any update on site' ||
        normalized == 'any update here' ||
        normalized == 'just update me' ||
        normalized == 'just update me here' ||
        normalized == 'update me here' ||
        normalized == 'quick update here' ||
        normalized == 'quick brief') {
      return TelegramClientQuickAction.status;
    }
    if (normalized == 'what changed since earlier' ||
        normalized == "what's changed since earlier" ||
        normalized == 'what changed since last check' ||
        normalized == 'what changed since last update' ||
        normalized == 'what changed since before' ||
        normalized == 'anything new there' ||
        normalized == 'anything else there' ||
        normalized == 'what changed here' ||
        normalized == 'what changed at the site' ||
        normalized == 'what changed on site' ||
        normalized == 'what changed tonight there') {
      return TelegramClientQuickAction.statusFull;
    }
    if (normalized == 'sleep check' ||
        normalized == 'client_quick_sleep_check' ||
        normalized == 'all in order' ||
        normalized == 'all in order?' ||
        normalized == 'bedtime check') {
      return TelegramClientQuickAction.sleepCheck;
    }
    if (normalized == 'check cameras' ||
        normalized == 'check camera' ||
        normalized == 'check the cameras' ||
        normalized == 'camera check' ||
        normalized == 'camera status' ||
        normalized == 'camera status here' ||
        normalized == 'camera update' ||
        normalized == 'what do cameras show' ||
        normalized == 'what do the cameras show' ||
        normalized == 'what do feeds show' ||
        normalized == 'what do the feeds show' ||
        normalized == 'review cameras' ||
        normalized == 'review the cameras' ||
        normalized == 'camera review' ||
        normalized == 'check the feeds' ||
        normalized == 'check feeds' ||
        normalized == 'review feeds' ||
        normalized == 'review cctv' ||
        normalized == 'check cctv') {
      return TelegramClientQuickAction.cameraCheck;
    }
    if (normalized == 'what should i do next' ||
        normalized == 'what do i do next' ||
        normalized == 'what next' ||
        normalized == 'next step' ||
        normalized == 'what should i do now') {
      return TelegramClientQuickAction.nextStep;
    }
    return null;
  }

  String _normalizeActionText(String text) {
    final raw = normalizeTelegramClientPromptSignalText(text);
    if (raw.isEmpty) {
      return raw;
    }
    const replacements = <String, String>{
      'pls': 'please',
      'plz': 'please',
      'cn': 'can',
      'u': 'you',
      'chek': 'check',
      'chekc': 'check',
    };
    return raw
        .split(' ')
        .where((token) => token.trim().isNotEmpty)
        .map((token) => replacements[token] ?? token)
        .where(
          (token) =>
              token.isNotEmpty &&
              token != 'please' &&
              token != 'can' &&
              token != 'you',
        )
        .join(' ');
  }

  String buildResponse({
    required TelegramClientQuickAction action,
    required MonitoringSiteProfile site,
    required MonitoringShiftSchedule schedule,
    required DateTime nowLocal,
    ClientCameraHealthFactPacket? cameraHealthFactPacket,
    MonitoringWatchRuntimeState? runtime,
    int fallbackReviewedEvents = 0,
    String? fallbackActivitySource,
    String? fallbackActivitySummary,
    String? fallbackNarrativeSummary,
    String? fallbackAssessmentLabel,
    String? fallbackPostureLabel,
    DateTime? fallbackReviewedAtLocal,
  }) {
    final tonePack = _tonePackFor(site);
    final snapshot = schedule.snapshotAt(nowLocal);
    final runtimeStartedLocal = runtime?.startedAtUtc.toLocal();
    final runtimeWindowEndLocal = runtimeStartedLocal == null
        ? null
        : (schedule.endForWindowStart(runtimeStartedLocal) ??
              snapshot.windowEndLocal);
    final runtimeActive =
        runtimeStartedLocal != null &&
        runtimeWindowEndLocal != null &&
        !nowLocal.isBefore(runtimeStartedLocal) &&
        nowLocal.isBefore(runtimeWindowEndLocal);
    final packetStatus = cameraHealthFactPacket?.status;
    final monitoringUnavailable = packetStatus != null
        ? packetStatus == ClientCameraHealthStatus.offline
        : !schedule.enabled && !runtimeActive;
    final monitoringLimited = packetStatus != null
        ? packetStatus == ClientCameraHealthStatus.limited
        : !monitoringUnavailable && runtime?.monitoringAvailable == false;
    final active = snapshot.active || runtimeActive;
    final windowStartLocal = runtimeActive
        ? runtimeStartedLocal
        : snapshot.windowStartLocal;
    final windowEndLocal = runtimeActive
        ? runtimeWindowEndLocal
        : snapshot.windowEndLocal;
    final reviewedEvents = (runtime?.reviewedEvents ?? 0) > 0
        ? runtime!.reviewedEvents
        : fallbackReviewedEvents;
    final latestActivity =
        _blankOr(fallbackActivitySource) ??
        _blankOr(runtime?.primaryActivitySource) ??
        _defaultActivityLabel(
          monitoringUnavailable: monitoringUnavailable,
          monitoringLimited: monitoringLimited,
        );
    final latestPosture =
        _blankOr(runtime?.latestSceneReviewPostureLabel) ??
        _blankOr(fallbackPostureLabel) ??
        _defaultPostureLabel(
          reviewedEvents: reviewedEvents,
          monitoringUnavailable: monitoringUnavailable,
          monitoringLimited: monitoringLimited,
        );
    final latestSummary =
        _blankOr(fallbackActivitySummary) ??
        _blankOr(runtime?.latestSceneReviewSummary) ??
        _defaultReviewSummary(
          monitoringUnavailable: monitoringUnavailable,
          monitoringLimited: monitoringLimited,
          monitoringAvailabilityDetail: runtime?.monitoringAvailabilityDetail,
        );
    final currentAssessment = _blankOr(fallbackAssessmentLabel);
    final latestDecision = _blankOr(runtime?.latestSceneDecisionSummary);
    final narrativeSummary = _blankOr(fallbackNarrativeSummary);
    final unresolvedActions = runtime?.unresolvedActionCount ?? 0;
    final monitoringStatusLabel = _monitoringStatusLabel(
      active: active,
      monitoringUnavailable: monitoringUnavailable,
      monitoringLimited: monitoringLimited,
    );
    final monitoringAvailabilityLabel = _monitoringAvailabilityLabel(
      runtime: runtime,
      monitoringUnavailable: monitoringUnavailable,
      monitoringLimited: monitoringLimited,
    );
    final runtimeReviewedAtLocal = runtime?.latestSceneReviewUpdatedAtUtc
        ?.toLocal();
    final latestReviewedAtLocal = runtimeReviewedAtLocal == null
        ? fallbackReviewedAtLocal
        : fallbackReviewedAtLocal == null
        ? runtimeReviewedAtLocal
        : fallbackReviewedAtLocal.isAfter(runtimeReviewedAtLocal)
        ? fallbackReviewedAtLocal
        : runtimeReviewedAtLocal;

    switch (action) {
      case TelegramClientQuickAction.status:
        return _conciseStatusResponse(
          site: site,
          active: active,
          monitoringUnavailable: monitoringUnavailable,
          monitoringLimited: monitoringLimited,
          cameraHealthFactPacket: cameraHealthFactPacket,
          reviewedEvents: reviewedEvents,
          latestPosture: latestPosture,
          currentAssessment: currentAssessment,
          unresolvedActions: unresolvedActions,
          tonePack: tonePack,
        );
      case TelegramClientQuickAction.statusFull:
        return '${site.siteName} is ${_statusLeadPhrase(monitoringStatusLabel)} as of ${_timeLabel(nowLocal)}. '
            '${_windowSentence(windowStartLocal, windowEndLocal, active, snapshot.nextTransitionLocal, monitoringUnavailable: monitoringUnavailable, monitoringLimited: monitoringLimited)} '
            'Remote watch is $monitoringAvailabilityLabel. '
            '${_latestSignalSentence(reviewedEvents: reviewedEvents, latestActivity: latestActivity, latestPosture: latestPosture)} '
            '${_labeledSentence('Assessment', currentAssessment)}'
            '${_labeledSentence('Summary', narrativeSummary)}'
            '${_labeledSentence('Review note', latestSummary)}'
            'Last check: ${latestReviewedAtLocal == null ? 'not yet recorded' : _dateTimeLabel(latestReviewedAtLocal)}. '
            'Open follow-ups: $unresolvedActions. '
            '${_labeledSentence('Current decision', latestDecision ?? 'No client-facing action has been required')}'
            '${_nextStepLine(active: active, monitoringUnavailable: monitoringUnavailable, monitoringLimited: monitoringLimited, unresolvedActions: unresolvedActions, tonePack: tonePack)}';
      case TelegramClientQuickAction.sleepCheck:
        final safeToRest =
            active &&
            !monitoringUnavailable &&
            !monitoringLimited &&
            unresolvedActions <= 0 &&
            runtime?.monitoringAvailable != false;
        final reassurance = safeToRest
            ? _sleepCheckSteadyLine(tonePack)
            : monitoringUnavailable
            ? 'Remote monitoring is currently unavailable for this site. If you need a manual follow-up, message here and control will pick it up.'
            : monitoringLimited
            ? 'Remote monitoring is still up, but it is limited right now. If you need a manual follow-up or welfare check, message here and control will pick it up.'
            : active
            ? _sleepCheckActiveLine(tonePack)
            : _sleepCheckInactiveLine(tonePack);
        return '${site.siteName} is ${_statusLeadPhrase(monitoringStatusLabel)} as of ${_timeLabel(nowLocal)}. '
            '${_windowSentence(windowStartLocal, windowEndLocal, active, snapshot.nextTransitionLocal, monitoringUnavailable: monitoringUnavailable, monitoringLimited: monitoringLimited)} '
            'Latest signal: $latestActivity. Current posture: $latestPosture. '
            'Open follow-ups: $unresolvedActions. '
            '$reassurance';
      case TelegramClientQuickAction.cameraCheck:
        return _cameraCheckResponse(
          site: site,
          active: active,
          monitoringUnavailable: monitoringUnavailable,
          monitoringLimited: monitoringLimited,
          cameraHealthFactPacket: cameraHealthFactPacket,
          reviewedEvents: reviewedEvents,
          latestActivity: latestActivity,
          latestPosture: latestPosture,
          latestSummary: latestSummary,
          currentAssessment: currentAssessment,
          latestReviewedAtLocal: latestReviewedAtLocal,
          unresolvedActions: unresolvedActions,
          tonePack: tonePack,
        );
      case TelegramClientQuickAction.nextStep:
        return '${site.siteName} is ${_statusLeadPhrase(monitoringStatusLabel)} right now. '
            'Open follow-ups: $unresolvedActions. '
            '${_labeledSentence('Assessment', currentAssessment)}'
            '${latestDecision == null ? '' : _labeledSentence('Current decision', latestDecision)}'
            '${_labeledSentence('Summary', narrativeSummary)}'
            '${_nextStepLine(active: active, monitoringUnavailable: monitoringUnavailable, monitoringLimited: monitoringLimited, unresolvedActions: unresolvedActions, tonePack: tonePack)}';
    }
  }

  String _statusLeadPhrase(String monitoringStatusLabel) {
    return switch (monitoringStatusLabel) {
      'ACTIVE' => 'under active watch',
      'LIMITED' => 'under watch with limited remote visibility',
      'UNAVAILABLE' => 'temporarily without remote monitoring',
      _ => 'outside an active watch window',
    };
  }

  String _conciseStatusResponse({
    required MonitoringSiteProfile site,
    required bool active,
    required bool monitoringUnavailable,
    required bool monitoringLimited,
    required ClientCameraHealthFactPacket? cameraHealthFactPacket,
    required int reviewedEvents,
    required String latestPosture,
    required String? currentAssessment,
    required int unresolvedActions,
    required _QuickActionTonePack tonePack,
  }) {
    final lead = monitoringUnavailable
        ? 'Remote monitoring is unavailable at ${site.siteName} right now.'
        : monitoringLimited
        ? '${site.siteName} is under watch, but remote visibility is limited right now.'
        : active
        ? '${site.siteName} is under active watch right now.'
        : '${site.siteName} is outside an active watch window right now.';
    final picture = _conciseStatusPictureSentence(
      monitoringUnavailable: monitoringUnavailable,
      monitoringLimited: monitoringLimited,
      cameraHealthFactPacket: cameraHealthFactPacket,
      reviewedEvents: reviewedEvents,
      latestPosture: latestPosture,
      currentAssessment: currentAssessment,
      unresolvedActions: unresolvedActions,
    );
    final next = _conciseStatusNextStep(
      active: active,
      monitoringUnavailable: monitoringUnavailable,
      monitoringLimited: monitoringLimited,
      unresolvedActions: unresolvedActions,
      tonePack: tonePack,
    );
    return '$lead $picture $next';
  }

  String _cameraCheckResponse({
    required MonitoringSiteProfile site,
    required bool active,
    required bool monitoringUnavailable,
    required bool monitoringLimited,
    required ClientCameraHealthFactPacket? cameraHealthFactPacket,
    required int reviewedEvents,
    required String latestActivity,
    required String latestPosture,
    required String latestSummary,
    required String? currentAssessment,
    required DateTime? latestReviewedAtLocal,
    required int unresolvedActions,
    required _QuickActionTonePack tonePack,
  }) {
    if (monitoringUnavailable || monitoringLimited) {
      final lead =
          cameraHealthFactPacket?.safeClientExplanation.trim().isNotEmpty == true
          ? cameraHealthFactPacket!.safeClientExplanation.trim()
          : monitoringUnavailable
          ? 'Live camera visibility at ${site.siteName} is unavailable right now.'
          : 'Live camera visibility at ${site.siteName} is limited right now.';
      final issueLabel = cameraHealthFactPacket?.operatorIssueSignalLabel();
      final currentSignalLine =
          issueLabel == null || issueLabel.trim().isEmpty
          ? ''
          : 'Current signal: ${issueLabel.trim()}. ';
      return '$lead $currentSignalLine${_nextStepLine(active: active, monitoringUnavailable: monitoringUnavailable, monitoringLimited: monitoringLimited, unresolvedActions: unresolvedActions, tonePack: tonePack)}';
    }
    return 'The latest camera picture for ${site.siteName} is based on $reviewedEvents reviewed ${reviewedEvents == 1 ? 'item' : 'items'}. '
        'Latest signal: $latestActivity. Current posture: $latestPosture. '
        '${_labeledSentence('Assessment', currentAssessment)}'
        '${_labeledSentence('Review note', latestSummary)}'
        'Last check: ${latestReviewedAtLocal == null ? 'not yet recorded' : _dateTimeLabel(latestReviewedAtLocal)}. '
        '${_nextStepLine(active: active, monitoringUnavailable: monitoringUnavailable, monitoringLimited: monitoringLimited, unresolvedActions: unresolvedActions, tonePack: tonePack)}';
  }

  String _conciseStatusPictureSentence({
    required bool monitoringUnavailable,
    required bool monitoringLimited,
    required ClientCameraHealthFactPacket? cameraHealthFactPacket,
    required int reviewedEvents,
    required String latestPosture,
    required String? currentAssessment,
    required int unresolvedActions,
  }) {
    final packetPicture = _packetizedConciseStatusPictureSentence(
      monitoringUnavailable: monitoringUnavailable,
      monitoringLimited: monitoringLimited,
      cameraHealthFactPacket: cameraHealthFactPacket,
    );
    if (packetPicture != null) {
      return packetPicture;
    }
    final assessment = (currentAssessment ?? '').trim().toLowerCase();
    final posture = latestPosture.trim().toLowerCase();
    if (monitoringUnavailable || monitoringLimited) {
      if (unresolvedActions > 0) {
        return 'I do not have full remote visibility, and there is site activity under review.';
      }
      return 'I do not have full remote visibility, and nothing here confirms an issue on site.';
    }
    if (unresolvedActions > 0) {
      return 'There is site activity under review right now.';
    }
    if (_containsAny(assessment, const [
      'routine',
      'calm',
      'normal',
      'steady',
    ])) {
      return 'Nothing here currently points to a confirmed issue on site.';
    }
    if (_containsAny(assessment, const [
          'under review',
          'activity',
          'movement',
        ]) ||
        _containsAny(posture, const ['under review', 'activity', 'movement'])) {
      return 'There is site activity under review right now.';
    }
    if (reviewedEvents > 0) {
      return 'I do not have a confirmed issue on site from the latest signals.';
    }
    return 'Nothing here currently points to a confirmed issue on site.';
  }

  String? _packetizedConciseStatusPictureSentence({
    required bool monitoringUnavailable,
    required bool monitoringLimited,
    required ClientCameraHealthFactPacket? cameraHealthFactPacket,
  }) {
    final packet = cameraHealthFactPacket;
    if (packet == null) {
      return null;
    }
    final issueLabel = packet.operatorIssueSignalLabel();
    if (issueLabel != null && issueLabel.trim().isNotEmpty) {
      final normalizedLabel = issueLabel.trim();
      if (monitoringUnavailable || monitoringLimited) {
        return 'I do not have full remote visibility, but the current signals still show $normalizedLabel.';
      }
      return 'The current signals still show $normalizedLabel.';
    }
    if (!packet.hasNoConfirmedSiteIssue) {
      return null;
    }
    if (monitoringUnavailable || monitoringLimited) {
      return 'I do not have full remote visibility, and nothing in the current signals confirms an issue on site.';
    }
    return 'Nothing in the current signals currently points to a confirmed issue on site.';
  }

  String _conciseStatusNextStep({
    required bool active,
    required bool monitoringUnavailable,
    required bool monitoringLimited,
    required int unresolvedActions,
    required _QuickActionTonePack tonePack,
  }) {
    if (monitoringUnavailable) {
      return switch (tonePack) {
        _QuickActionTonePack.residential =>
          'Message here if you want a manual follow-up.',
        _QuickActionTonePack.enterprise =>
          'Use this chat if you want a manual follow-up.',
        _QuickActionTonePack.standard =>
          'Message here if you want a manual follow-up.',
      };
    }
    if (monitoringLimited) {
      return unresolvedActions > 0
          ? 'ONYX will update you here with the next confirmed step.'
          : switch (tonePack) {
              _QuickActionTonePack.residential =>
                'I will update you here if anything needs your attention.',
              _QuickActionTonePack.enterprise =>
                'We will update you here if anything needs your attention.',
              _QuickActionTonePack.standard =>
                'I will update you here if anything needs your attention.',
            };
    }
    if (!active) {
      return switch (tonePack) {
        _QuickActionTonePack.residential =>
          'Message here if you want a manual follow-up before the next watch window.',
        _QuickActionTonePack.enterprise =>
          'Use this chat if you want a manual follow-up before the next watch window.',
        _QuickActionTonePack.standard =>
          'Message here if you want a manual follow-up before the next watch window.',
      };
    }
    if (unresolvedActions > 0) {
      return 'ONYX will update you here with the next confirmed step.';
    }
    return switch (tonePack) {
      _QuickActionTonePack.residential =>
        'ONYX will message you here only if something important changes.',
      _QuickActionTonePack.enterprise =>
        'ONYX will send an update here only if something important changes.',
      _QuickActionTonePack.standard =>
        'ONYX will message you here only if something important changes.',
    };
  }

  String _labeledSentence(String label, String? value) {
    final normalized = _sentence(value);
    if (normalized == null) {
      return '';
    }
    return '$label: $normalized ';
  }

  String? _sentence(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (RegExp(r'[.!?]$').hasMatch(trimmed)) {
      return trimmed;
    }
    return '$trimmed.';
  }

  String _windowSentence(
    DateTime? windowStartLocal,
    DateTime? windowEndLocal,
    bool active,
    DateTime? nextTransitionLocal, {
    required bool monitoringUnavailable,
    required bool monitoringLimited,
  }) {
    if (monitoringUnavailable) {
      return 'Remote watch is temporarily unavailable while the monitoring path is offline.';
    }
    if (monitoringLimited) {
      if (windowStartLocal == null || windowEndLocal == null) {
        return 'Watch coverage is active now, but remote visibility is limited.';
      }
      final isAllDayWindow =
          windowEndLocal.difference(windowStartLocal) >=
              const Duration(hours: 23, minutes: 59) &&
          windowStartLocal.hour == windowEndLocal.hour &&
          windowStartLocal.minute == windowEndLocal.minute;
      if (isAllDayWindow) {
        return 'The site is on a 24-hour watch cycle, although remote visibility is limited.';
      }
      return 'The current watch window runs ${_timeLabel(windowStartLocal)}-${_timeLabel(windowEndLocal)}, with limited remote visibility.';
    }
    if (windowStartLocal == null || windowEndLocal == null) {
      if (!active && nextTransitionLocal != null) {
        return 'The next scheduled watch starts at ${_timeLabel(nextTransitionLocal)}.';
      }
      return active
          ? 'The site is inside an active watch window.'
          : 'The next scheduled watch window is not available yet.';
    }
    final isAllDayWindow =
        windowEndLocal.difference(windowStartLocal) >=
            const Duration(hours: 23, minutes: 59) &&
        windowStartLocal.hour == windowEndLocal.hour &&
        windowStartLocal.minute == windowEndLocal.minute;
    if (isAllDayWindow) {
      return 'The site is on a 24-hour watch cycle.';
    }
    return 'The current watch window runs ${_timeLabel(windowStartLocal)}-${_timeLabel(windowEndLocal)}.';
  }

  String _latestSignalSentence({
    required int reviewedEvents,
    required String latestActivity,
    required String latestPosture,
  }) {
    if (reviewedEvents > 0) {
      return 'Items reviewed: $reviewedEvents. Latest signal: $latestActivity. Current posture: $latestPosture.';
    }
    return 'Items reviewed: 0. Latest signal: $latestActivity. Current posture: $latestPosture.';
  }

  String _nextStepLine({
    required bool active,
    required bool monitoringUnavailable,
    required bool monitoringLimited,
    required int unresolvedActions,
    required _QuickActionTonePack tonePack,
  }) {
    if (monitoringUnavailable) {
      return 'Next step: use this chat if you want a manual follow-up while remote monitoring is offline.';
    }
    if (monitoringLimited) {
      return switch (tonePack) {
        _QuickActionTonePack.residential =>
          'Next step: ONYX will keep watching, and we will use this chat if a manual follow-up or welfare check is needed.',
        _QuickActionTonePack.enterprise =>
          'Next step: ONYX will keep watching, and this chat will be used if manual follow-up is needed.',
        _QuickActionTonePack.standard =>
          'Next step: ONYX will keep watching, and this chat will be used if manual follow-up is needed.',
      };
    }
    if (!active) {
      return switch (tonePack) {
        _QuickActionTonePack.residential =>
          'Next step: monitoring resumes at the next scheduled window, or sooner if you ask here for a manual follow-up.',
        _QuickActionTonePack.enterprise =>
          'Next step: monitoring resumes at the next scheduled window, or earlier if you request manual follow-up in this chat.',
        _QuickActionTonePack.standard =>
          'Next step: monitoring resumes at the next scheduled window, or sooner if you ask for manual follow-up here.',
      };
    }
    if (unresolvedActions > 0) {
      return switch (tonePack) {
        _QuickActionTonePack.residential =>
          'Next step: ONYX is tracking the open follow-ups and will share the next confirmed change here.',
        _QuickActionTonePack.enterprise =>
          'Next step: ONYX is tracking the open follow-ups and will send the next confirmed change.',
        _QuickActionTonePack.standard =>
          'Next step: ONYX is tracking the open follow-ups and will send the next confirmed change.',
      };
    }
    return switch (tonePack) {
      _QuickActionTonePack.residential =>
        'Next step: ONYX remains on watch and will message here only if something important changes.',
      _QuickActionTonePack.enterprise =>
        'Next step: ONYX remains on watch and will send an update only if something important changes.',
      _QuickActionTonePack.standard =>
        'Next step: ONYX remains on watch and will send an update only if something important changes.',
    };
  }

  String _sleepCheckSteadyLine(_QuickActionTonePack tonePack) {
    return switch (tonePack) {
      _QuickActionTonePack.residential =>
        'All looks steady right now. Rest easy and we will message you only if the picture changes.',
      _QuickActionTonePack.enterprise =>
        'Everything looks steady right now. We will send an update only if the picture changes.',
      _QuickActionTonePack.standard =>
        'All looks steady right now. We will message you only if the picture changes.',
    };
  }

  String _sleepCheckActiveLine(_QuickActionTonePack tonePack) {
    return switch (tonePack) {
      _QuickActionTonePack.residential =>
        'ONYX is still actively watching and will let you know if the posture changes.',
      _QuickActionTonePack.enterprise =>
        'ONYX is actively watching and will send an update if the posture changes.',
      _QuickActionTonePack.standard =>
        'ONYX is still actively watching and will alert you if the posture changes.',
    };
  }

  String _sleepCheckInactiveLine(_QuickActionTonePack tonePack) {
    return switch (tonePack) {
      _QuickActionTonePack.residential =>
        'There is no active watch window right now. If you want a manual follow-up before the next window, message here and control will pick it up.',
      _QuickActionTonePack.enterprise =>
        'There is no active watch window right now. If you need a manual follow-up before the next window, use this chat and control will pick it up.',
      _QuickActionTonePack.standard =>
        'There is no active watch window right now. If you need a manual follow-up before the next window, message here and control will pick it up.',
    };
  }

  _QuickActionTonePack _tonePackFor(MonitoringSiteProfile site) {
    final joined = '${site.siteName} ${site.clientName}'.toLowerCase();
    if (_containsAny(joined, const [
      'residence',
      'residential',
      'estate',
      'villa',
      'home',
      'community',
      'vallee',
    ])) {
      return _QuickActionTonePack.residential;
    }
    if (_containsAny(joined, const [
      'tower',
      'campus',
      'office',
      'industrial',
      'business',
      'corporate',
      'enterprise',
      'park',
      'centre',
      'center',
    ])) {
      return _QuickActionTonePack.enterprise;
    }
    return _QuickActionTonePack.standard;
  }

  bool _containsAny(String text, List<String> needles) {
    for (final needle in needles) {
      if (text.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  String _monitoringStatusLabel({
    required bool active,
    required bool monitoringUnavailable,
    required bool monitoringLimited,
  }) {
    if (monitoringUnavailable) {
      return 'UNAVAILABLE';
    }
    if (monitoringLimited) {
      return 'LIMITED';
    }
    return active ? 'ACTIVE' : 'STANDBY';
  }

  String _monitoringAvailabilityLabel({
    required MonitoringWatchRuntimeState? runtime,
    required bool monitoringUnavailable,
    required bool monitoringLimited,
  }) {
    if (monitoringUnavailable) {
      return 'unavailable';
    }
    if (monitoringLimited || runtime?.monitoringAvailable == false) {
      return 'limited';
    }
    return 'available';
  }

  String _defaultActivityLabel({
    required bool monitoringUnavailable,
    required bool monitoringLimited,
  }) {
    if (monitoringUnavailable) {
      return 'Remote monitoring is offline for this site';
    }
    if (monitoringLimited) {
      return 'Remote monitoring is limited for this site';
    }
    return 'No material activity logged';
  }

  String _defaultPostureLabel({
    required int reviewedEvents,
    required bool monitoringUnavailable,
    required bool monitoringLimited,
  }) {
    if (monitoringUnavailable) {
      return 'remote monitoring unavailable';
    }
    if (monitoringLimited) {
      return 'remote monitoring limited';
    }
    return reviewedEvents > 0 ? 'field activity observed' : 'calm';
  }

  String _defaultReviewSummary({
    required bool monitoringUnavailable,
    required bool monitoringLimited,
    required String? monitoringAvailabilityDetail,
  }) {
    if (monitoringUnavailable) {
      return 'Remote monitoring is currently unavailable for this site.';
    }
    if (monitoringLimited) {
      final detail = (monitoringAvailabilityDetail ?? '').trim();
      if (detail.isNotEmpty) {
        return detail;
      }
      return 'Remote monitoring is active but limited for this site.';
    }
    return 'No review summary available';
  }

  String? _blankOr(String? value) {
    final trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _timeLabel(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _dateTimeLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year} ${_timeLabel(value)}';
  }
}
