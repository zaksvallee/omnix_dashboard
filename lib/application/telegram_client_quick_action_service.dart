import 'monitoring_shift_notification_service.dart';
import 'monitoring_shift_schedule_service.dart';
import 'monitoring_watch_runtime_store.dart';

enum TelegramClientQuickAction { status, statusFull, sleepCheck }

enum _QuickActionTonePack { standard, residential, enterprise }

class TelegramClientQuickActionService {
  const TelegramClientQuickActionService();

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
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized == 'client_quick_status') {
      return TelegramClientQuickAction.status;
    }
    if (normalized == 'client_quick_status_full') {
      return TelegramClientQuickAction.statusFull;
    }
    if (normalized == 'status') {
      return TelegramClientQuickAction.status;
    }
    if (normalized == 'details' ||
        normalized == 'status full' ||
        normalized == 'full status') {
      return TelegramClientQuickAction.statusFull;
    }
    if (normalized == 'sleep check' ||
        normalized == 'client_quick_sleep_check' ||
        normalized == 'all in order' ||
        normalized == 'all in order?' ||
        normalized == 'bedtime check') {
      return TelegramClientQuickAction.sleepCheck;
    }
    return null;
  }

  String buildResponse({
    required TelegramClientQuickAction action,
    required MonitoringSiteProfile site,
    required MonitoringShiftSchedule schedule,
    required DateTime nowLocal,
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
    final monitoringUnavailable = !schedule.enabled && !runtimeActive;
    final monitoringLimited =
        !monitoringUnavailable && runtime?.monitoringAvailable == false;
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
        return '🛡️ ONYX STATUS\n'
            '${site.siteName} | ${_timeLabel(nowLocal)}\n\n'
            'Current status\n'
            '${_statusLine(monitoringStatusLabel)}\n'
            '${_windowLine(windowStartLocal, windowEndLocal, active, snapshot.nextTransitionLocal, monitoringUnavailable: monitoringUnavailable, monitoringLimited: monitoringLimited)}\n\n'
            'What we see now\n'
            'Items reviewed: $reviewedEvents\n'
            'Latest signal: $latestActivity\n'
            'Current posture: $latestPosture\n'
            '${currentAssessment == null ? '' : 'Assessment: $currentAssessment\n'}'
            '\n'
            'Next\n'
            'Open follow-ups: $unresolvedActions\n'
            '${_statusTail(active, unresolvedActions, monitoringUnavailable: monitoringUnavailable, monitoringLimited: monitoringLimited, tonePack: tonePack)}';
      case TelegramClientQuickAction.statusFull:
        return '🧾 ONYX STATUS (FULL)\n'
            '${site.siteName} | ${_timeLabel(nowLocal)}\n\n'
            'Current status\n'
            '${_statusLine(monitoringStatusLabel)}\n'
            '${_windowLine(windowStartLocal, windowEndLocal, active, snapshot.nextTransitionLocal, monitoringUnavailable: monitoringUnavailable, monitoringLimited: monitoringLimited)}\n'
            'Remote watch: $monitoringAvailabilityLabel\n\n'
            'What we see now\n'
            'Items reviewed: $reviewedEvents\n'
            'Latest signal: $latestActivity\n'
            'Current posture: $latestPosture\n'
            '${currentAssessment == null ? '' : 'Assessment: $currentAssessment\n'}'
            '${narrativeSummary == null ? '' : 'Summary: $narrativeSummary\n'}'
            'Review note: $latestSummary\n'
            'Last check: ${latestReviewedAtLocal == null ? 'not yet recorded' : _dateTimeLabel(latestReviewedAtLocal)}\n\n'
            'Next\n'
            'Open follow-ups: $unresolvedActions\n'
            'Current decision: ${latestDecision ?? 'No client-facing action has been required'}\n'
            '${_nextStepLine(active: active, monitoringUnavailable: monitoringUnavailable, monitoringLimited: monitoringLimited, unresolvedActions: unresolvedActions, tonePack: tonePack)}\n'
            'Local time: ${_dateTimeLabel(nowLocal)}';
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
        return '🌙 ONYX SLEEP CHECK\n'
            '${site.siteName} | ${_timeLabel(nowLocal)}\n\n'
            'Current status\n'
            '${_statusLine(monitoringStatusLabel)}\n'
            '${_windowLine(windowStartLocal, windowEndLocal, active, snapshot.nextTransitionLocal, monitoringUnavailable: monitoringUnavailable, monitoringLimited: monitoringLimited)}\n\n'
            'What we see now\n'
            'Latest signal: $latestActivity\n'
            'Current posture: $latestPosture\n'
            'Open follow-ups: $unresolvedActions\n\n'
            'Next\n'
            '$reassurance';
    }
  }

  String _statusLine(String monitoringStatusLabel) {
    return switch (monitoringStatusLabel) {
      'ACTIVE' => 'Monitoring is active.',
      'LIMITED' => 'Remote monitoring is active but limited.',
      'UNAVAILABLE' => 'Remote monitoring is currently unavailable.',
      _ => 'Monitoring is on standby.',
    };
  }

  String _windowLine(
    DateTime? windowStartLocal,
    DateTime? windowEndLocal,
    bool active,
    DateTime? nextTransitionLocal, {
    required bool monitoringUnavailable,
    required bool monitoringLimited,
  }) {
    if (monitoringUnavailable) {
      return 'Watch window: remote monitoring is currently unavailable for this site';
    }
    if (monitoringLimited) {
      if (windowStartLocal == null || windowEndLocal == null) {
        return 'Watch window: active now with limited remote visibility';
      }
      final isAllDayWindow =
          windowEndLocal.difference(windowStartLocal) >=
              const Duration(hours: 23, minutes: 59) &&
          windowStartLocal.hour == windowEndLocal.hour &&
          windowStartLocal.minute == windowEndLocal.minute;
      if (isAllDayWindow) {
        return 'Watch window: 24h watch with limited remote visibility';
      }
      return 'Watch window: ${_timeLabel(windowStartLocal)}-${_timeLabel(windowEndLocal)} with limited remote visibility';
    }
    if (windowStartLocal == null || windowEndLocal == null) {
      if (!active && nextTransitionLocal != null) {
        return 'Watch window: next watch starts ${_timeLabel(nextTransitionLocal)}';
      }
      return active
          ? 'Watch window: active now'
          : 'Watch window: next scheduled watch not available';
    }
    final isAllDayWindow =
        windowEndLocal.difference(windowStartLocal) >=
            const Duration(hours: 23, minutes: 59) &&
        windowStartLocal.hour == windowEndLocal.hour &&
        windowStartLocal.minute == windowEndLocal.minute;
    if (isAllDayWindow) {
      return 'Watch window: 24h watch (started ${_timeLabel(windowStartLocal)})';
    }
    return 'Watch window: ${_timeLabel(windowStartLocal)}-${_timeLabel(windowEndLocal)}';
  }

  String _statusTail(
    bool active,
    int unresolvedActions, {
    required bool monitoringUnavailable,
    required bool monitoringLimited,
    required _QuickActionTonePack tonePack,
  }) {
    if (monitoringUnavailable) {
      return 'Remote monitoring is currently unavailable for this site. If you need a manual follow-up or welfare check, message here and control will pick it up.';
    }
    if (monitoringLimited) {
      return switch (tonePack) {
        _QuickActionTonePack.residential =>
          'Remote monitoring is limited right now. We can still watch the site, but a manual follow-up may be needed if anything feels off.',
        _QuickActionTonePack.enterprise =>
          'Remote monitoring is limited right now. The site is still under watch, but manual follow-up may be needed if conditions change.',
        _QuickActionTonePack.standard =>
          'Remote monitoring is limited right now. The site is still under watch, but manual follow-up may be needed if conditions change.',
      };
    }
    if (!active) {
      return switch (tonePack) {
        _QuickActionTonePack.residential =>
          'There is no active monitoring window right now. Message here if you want a manual follow-up before the next one starts.',
        _QuickActionTonePack.enterprise =>
          'There is no active monitoring window right now. Use this chat if you need a manual follow-up before the next one starts.',
        _QuickActionTonePack.standard =>
          'There is no active monitoring window right now. Message here if you need a manual follow-up before the next one starts.',
      };
    }
    if (unresolvedActions > 0) {
      return switch (tonePack) {
        _QuickActionTonePack.residential =>
          'ONYX is handling the open follow-ups and will update you if anything changes.',
        _QuickActionTonePack.enterprise =>
          'ONYX is managing the open follow-ups and will update you if anything escalates.',
        _QuickActionTonePack.standard =>
          'ONYX is managing the open follow-ups and will update you if anything escalates.',
      };
    }
    return switch (tonePack) {
      _QuickActionTonePack.residential =>
        'ONYX stays close on watch and will message you only if something important changes.',
      _QuickActionTonePack.enterprise =>
        'ONYX remains on watch and will send an update only if something important changes.',
      _QuickActionTonePack.standard =>
        'ONYX stays on watch and will message you only if something important changes.',
    };
  }

  String _nextStepLine({
    required bool active,
    required bool monitoringUnavailable,
    required bool monitoringLimited,
    required int unresolvedActions,
    required _QuickActionTonePack tonePack,
  }) {
    if (monitoringUnavailable) {
      return 'Next step: use this chat for any manual follow-up while the site is offline.';
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
