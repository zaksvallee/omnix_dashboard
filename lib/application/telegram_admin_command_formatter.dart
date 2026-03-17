class TelegramAdminCommandFormatter {
  const TelegramAdminCommandFormatter._();

  static String pollOps({
    required String pollResult,
    required String radioHealth,
    required String cctvHealth,
    String? cctvContext,
    String videoLabel = 'CCTV',
    required String wearableHealth,
    required String listenerHealth,
    required String newsHealth,
    required String utcStamp,
  }) {
    final cctvContextLine = _optionalLine(
      label: '<b>$videoLabel Context:</b>',
      value: cctvContext,
      separator: ' ',
    );
    return '📡 <b>ONYX POLLOPS</b>\n\n'
        '<b>Poll Result</b>\n'
        '$pollResult\n\n'
        '---\n\n'
        '<b>Integrations</b>\n'
        '• <b>Radio:</b> $radioHealth\n'
        '• <b>$videoLabel:</b> $cctvHealth\n'
        '$cctvContextLine'
        '• <b>Wearable:</b> $wearableHealth\n'
        '• <b>Listener Alarm:</b> $listenerHealth\n'
        '• <b>News:</b> $newsHealth\n'
        '\n---\n\n'
        '<b>Next</b>\n'
        '• If any source is failing, run <code>/bridges</code> for deeper diagnostics.\n'
        '\nUTC: $utcStamp';
  }

  static String bridges({
    required String telegramStatus,
    required String radioStatus,
    required String cctvStatus,
    String? cctvHealth,
    String? cctvRecent,
    String videoLabel = 'CCTV',
    required String wearableStatus,
    required String livePollingLabel,
    required String utcStamp,
  }) {
    final cctvHealthLine = _optionalLine(
      label: '$videoLabel Health:',
      value: cctvHealth,
      separator: ' ',
    );
    final cctvRecentLine = _optionalLine(
      label: '$videoLabel Recent:',
      value: cctvRecent,
      separator: ' ',
    );
    return 'ONYX BRIDGES\n'
        'Telegram: $telegramStatus\n'
        'Radio: $radioStatus\n'
        '$videoLabel: $cctvStatus\n'
        '$cctvHealthLine'
        '$cctvRecentLine'
        'Wearable: $wearableStatus\n'
        'Live polling: $livePollingLabel\n'
        'UTC: $utcStamp';
  }

  static String morningGovernance({
    required String signalHeader,
    required String reportDate,
    required String generatedAtUtc,
    required String sceneReviewSummary,
    required String siteActivityHeadline,
    required String siteActivitySummary,
    required String currentShiftReviewCommand,
    required String currentShiftCaseFileCommand,
    String? previousShiftReviewCommand,
    String? previousShiftCaseFileCommand,
    String? targetScope,
    required bool targetScopeRequired,
    required String utcStamp,
  }) {
    final normalizedTargetScope = targetScope?.trim() ?? '';
    final previousReview = previousShiftReviewCommand?.trim() ?? '';
    final previousCase = previousShiftCaseFileCommand?.trim() ?? '';
    final targetLine = normalizedTargetScope.isEmpty
        ? '• <b>Target scope:</b> required\n'
        : '• <b>Target scope:</b> <code>${_escapeHtml(normalizedTargetScope)}</code>\n';
    final targetHint = targetScopeRequired
        ? (normalizedTargetScope.isEmpty
              ? '• <b>Hint:</b> Run <code>/settarget CLIENT SITE</code> before the activity shortcuts.\n'
              : '• <b>Hint:</b> Activity shortcuts use the current target scope.\n')
        : '';
    final previousLines = previousReview.isEmpty
        ? ''
        : '• <b>Previous review:</b> <code>${_escapeHtml(previousReview)}</code>\n'
              '${previousCase.isEmpty ? '' : '• <b>Previous case:</b> <code>${_escapeHtml(previousCase)}</code>\n'}';
    return '🛰️ <b>ONYX MORNING GOVERNANCE</b>\n\n'
        '<b>Signal</b>\n'
        '<code>${_escapeHtml(signalHeader)}</code>\n\n'
        '---\n\n'
        '<b>Shift</b>\n'
        '• <b>Date:</b> ${_escapeHtml(reportDate)}\n'
        '• <b>Generated:</b> ${_escapeHtml(generatedAtUtc)}\n\n'
        '---\n\n'
        '<b>Oversight</b>\n'
        '• <b>Scene review:</b> ${_escapeHtml(sceneReviewSummary)}\n'
        '• <b>Site activity:</b> ${_escapeHtml(siteActivityHeadline)}\n'
        '• <b>Summary:</b> ${_escapeHtml(siteActivitySummary)}\n\n'
        '---\n\n'
        '<b>Activity Investigation</b>\n'
        '$targetLine'
        '• <b>Current review:</b> <code>${_escapeHtml(currentShiftReviewCommand)}</code>\n'
        '• <b>Current case:</b> <code>${_escapeHtml(currentShiftCaseFileCommand)}</code>\n'
        '$previousLines'
        '$targetHint'
        '\nUTC: ${_escapeHtml(utcStamp)}';
  }

  static String _optionalLine({
    required String label,
    String? value,
    String separator = ': ',
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '';
    }
    return '$label$separator$trimmed\n';
  }

  static String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}
