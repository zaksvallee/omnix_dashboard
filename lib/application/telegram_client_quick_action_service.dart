import 'monitoring_shift_notification_service.dart';
import 'monitoring_shift_schedule_service.dart';
import 'monitoring_watch_runtime_store.dart';

enum TelegramClientQuickAction { status, statusFull, sleepCheck }

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
    final snapshot = schedule.snapshotAt(nowLocal);
    final runtimeStartedLocal = runtime?.startedAtUtc.toLocal();
    final runtimeWindowEndLocal = runtimeStartedLocal == null
        ? null
        : (schedule.endForWindowStart(runtimeStartedLocal) ??
              snapshot.windowEndLocal);
    final runtimeActive = runtimeStartedLocal != null &&
        runtimeWindowEndLocal != null &&
        !nowLocal.isBefore(runtimeStartedLocal) &&
        nowLocal.isBefore(runtimeWindowEndLocal);
    final active = snapshot.active || runtimeActive;
    final windowStartLocal =
        runtimeActive ? runtimeStartedLocal : snapshot.windowStartLocal;
    final windowEndLocal =
        runtimeActive ? runtimeWindowEndLocal : snapshot.windowEndLocal;
    final reviewedEvents = (runtime?.reviewedEvents ?? 0) > 0
        ? runtime!.reviewedEvents
        : fallbackReviewedEvents;
    final latestActivity =
        _blankOr(fallbackActivitySource) ??
        _blankOr(runtime?.primaryActivitySource);
    final latestPosture =
        _blankOr(runtime?.latestSceneReviewPostureLabel) ??
        _blankOr(fallbackPostureLabel);
    final latestSummary =
        _blankOr(fallbackActivitySummary) ??
        _blankOr(runtime?.latestSceneReviewSummary);
    final currentAssessment = _blankOr(fallbackAssessmentLabel);
    final latestDecision = _blankOr(runtime?.latestSceneDecisionSummary);
    final narrativeSummary = _blankOr(fallbackNarrativeSummary);
    final unresolvedActions = runtime?.unresolvedActionCount ?? 0;
    final runtimeReviewedAtLocal = runtime?.latestSceneReviewUpdatedAtUtc
        ?.toLocal();
    final latestReviewedAtLocal =
        runtimeReviewedAtLocal == null
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
            'Monitoring: ${active ? 'ACTIVE' : 'STANDBY'}\n'
            '${_windowLine(windowStartLocal, windowEndLocal, active, snapshot.nextTransitionLocal)}\n'
            'Reviewed activity: $reviewedEvents\n'
            'Latest activity: ${latestActivity ?? 'No material activity logged'}\n'
            'Latest posture: ${latestPosture ?? (reviewedEvents > 0 ? 'field activity observed' : 'calm')}\n'
            '${currentAssessment == null ? '' : 'Current assessment: $currentAssessment\n'}'
            'Open follow-up actions: $unresolvedActions\n'
            '${_statusTail(active, unresolvedActions)}';
      case TelegramClientQuickAction.statusFull:
        return '🧾 ONYX STATUS (FULL)\n'
            '${site.siteName} | ${_timeLabel(nowLocal)}\n\n'
            'Monitoring: ${active ? 'ACTIVE' : 'STANDBY'}\n'
            '${_windowLine(windowStartLocal, windowEndLocal, active, snapshot.nextTransitionLocal)}\n'
            'Reviewed activity: $reviewedEvents\n'
            'Latest activity source: ${latestActivity ?? 'none logged'}\n'
            'Latest posture: ${latestPosture ?? (reviewedEvents > 0 ? 'field activity observed' : 'calm')}\n'
            '${currentAssessment == null ? '' : 'Current assessment: $currentAssessment\n'}'
            '${narrativeSummary == null ? '' : 'Current site narrative: $narrativeSummary\n'}'
            'Latest review summary: ${latestSummary ?? 'No review summary available'}\n'
            'Latest decision: ${latestDecision ?? 'No client-facing action has been required'}\n'
            'Open follow-up actions: $unresolvedActions\n'
            'Monitoring availability: ${runtime?.monitoringAvailable == false ? 'degraded' : 'available'}\n'
            'Last reviewed at: ${latestReviewedAtLocal == null ? 'not yet recorded' : _dateTimeLabel(latestReviewedAtLocal)}\n'
            'Local time: ${_dateTimeLabel(nowLocal)}';
      case TelegramClientQuickAction.sleepCheck:
        final safeToRest =
            active &&
            unresolvedActions <= 0 &&
            runtime?.monitoringAvailable != false;
        final reassurance = safeToRest
            ? 'All in order right now. Sleep well.'
            : active
            ? 'ONYX is still actively watching and will alert you if the posture changes.'
            : 'There is no active watch window right now, but ONYX will resume at the next scheduled start.';
        return '🌙 ONYX SLEEP CHECK\n'
            '${site.siteName} | ${_timeLabel(nowLocal)}\n\n'
            'Monitoring: ${active ? 'ACTIVE' : 'STANDBY'}\n'
            '${_windowLine(windowStartLocal, windowEndLocal, active, snapshot.nextTransitionLocal)}\n'
            'Latest activity: ${latestActivity ?? 'No material activity logged'}\n'
            'Latest posture: ${latestPosture ?? (reviewedEvents > 0 ? 'field activity observed' : 'calm')}\n'
            'Open follow-up actions: $unresolvedActions\n'
            '$reassurance';
    }
  }

  String _windowLine(
    DateTime? windowStartLocal,
    DateTime? windowEndLocal,
    bool active,
    DateTime? nextTransitionLocal,
  ) {
    if (windowStartLocal == null || windowEndLocal == null) {
      if (!active && nextTransitionLocal != null) {
        return 'Window: next watch starts ${_timeLabel(nextTransitionLocal)}';
      }
      return active
          ? 'Window: active now'
          : 'Window: next scheduled watch not available';
    }
    final isAllDayWindow =
        windowEndLocal.difference(windowStartLocal) >=
            const Duration(hours: 23, minutes: 59) &&
        windowStartLocal.hour == windowEndLocal.hour &&
        windowStartLocal.minute == windowEndLocal.minute;
    if (isAllDayWindow) {
      return 'Window: 24h watch (started ${_timeLabel(windowStartLocal)})';
    }
    return 'Window: ${_timeLabel(windowStartLocal)}-${_timeLabel(windowEndLocal)}';
  }

  String _statusTail(bool active, int unresolvedActions) {
    if (!active) {
      return 'No active monitoring window right now.';
    }
    if (unresolvedActions > 0) {
      return 'ONYX is managing follow-up actions and will update you if anything escalates.';
    }
    return 'ONYX is on active observation and will message only if the posture changes materially.';
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
