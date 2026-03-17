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
    String? sceneReviewTopPosture,
    String? globalReadinessHeadline,
    String? globalReadinessSummary,
    String? globalReadinessEchoSummary,
    String? globalReadinessTopIntentSummary,
    String? currentShiftReadinessFocusSummary,
    String? currentShiftReadinessReviewCommand,
    String? currentShiftReadinessCaseFileCommand,
    String? currentShiftReadinessGovernanceCommand,
    String? previousShiftReadinessFocusSummary,
    String? previousShiftReadinessReviewCommand,
    String? previousShiftReadinessCaseFileCommand,
    String? previousShiftReadinessGovernanceCommand,
    String? syntheticWarRoomHeadline,
    String? syntheticWarRoomSummary,
    String? syntheticWarRoomPolicySummary,
    String? syntheticWarRoomHistoryHeadline,
    String? syntheticWarRoomHistorySummary,
    String? currentShiftSyntheticFocusSummary,
    String? currentShiftSyntheticReviewCommand,
    String? currentShiftSyntheticCaseFileCommand,
    String? previousShiftSyntheticFocusSummary,
    String? previousShiftSyntheticReviewCommand,
    String? previousShiftSyntheticCaseFileCommand,
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
    final normalizedSceneReviewTopPosture =
        sceneReviewTopPosture?.trim().toLowerCase() ?? '';
    final previousReview = previousShiftReviewCommand?.trim() ?? '';
    final previousCase = previousShiftCaseFileCommand?.trim() ?? '';
    final readinessHeadline = globalReadinessHeadline?.trim() ?? '';
    final readinessSummary = globalReadinessSummary?.trim() ?? '';
    final readinessEchoSummary = globalReadinessEchoSummary?.trim() ?? '';
    final readinessTopIntentSummary =
        globalReadinessTopIntentSummary?.trim() ?? '';
    final readinessFocusSummary =
        currentShiftReadinessFocusSummary?.trim() ?? '';
    final readinessReview = currentShiftReadinessReviewCommand?.trim() ?? '';
    final readinessCase = currentShiftReadinessCaseFileCommand?.trim() ?? '';
    final readinessGovernance =
        currentShiftReadinessGovernanceCommand?.trim() ?? '';
    final previousReadinessFocusSummary =
        previousShiftReadinessFocusSummary?.trim() ?? '';
    final previousReadinessReview =
        previousShiftReadinessReviewCommand?.trim() ?? '';
    final previousReadinessCase =
        previousShiftReadinessCaseFileCommand?.trim() ?? '';
    final previousReadinessGovernance =
        previousShiftReadinessGovernanceCommand?.trim() ?? '';
    final warRoomHeadline = syntheticWarRoomHeadline?.trim() ?? '';
    final warRoomSummary = syntheticWarRoomSummary?.trim() ?? '';
    final warRoomPolicySummary = syntheticWarRoomPolicySummary?.trim() ?? '';
    final warRoomHistoryHeadline =
        syntheticWarRoomHistoryHeadline?.trim() ?? '';
    final warRoomHistorySummary =
        syntheticWarRoomHistorySummary?.trim() ?? '';
    final syntheticFocusSummary =
        currentShiftSyntheticFocusSummary?.trim() ?? '';
    final syntheticReview = currentShiftSyntheticReviewCommand?.trim() ?? '';
    final syntheticCase = currentShiftSyntheticCaseFileCommand?.trim() ?? '';
    final previousSyntheticFocusSummary =
        previousShiftSyntheticFocusSummary?.trim() ?? '';
    final previousSyntheticReview =
        previousShiftSyntheticReviewCommand?.trim() ?? '';
    final previousSyntheticCase =
        previousShiftSyntheticCaseFileCommand?.trim() ?? '';
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
    final readinessSection = readinessReview.isEmpty && readinessCase.isEmpty
        ? ''
        : '---\n\n'
              '<b>Global Readiness</b>\n'
              '${readinessHeadline.isEmpty ? '' : '• <b>Mode:</b> ${_escapeHtml(readinessHeadline)}\n'}'
              '${readinessSummary.isEmpty ? '' : '• <b>Summary:</b> ${_escapeHtml(readinessSummary)}\n'}'
              '${readinessFocusSummary.isEmpty ? '' : '• <b>Focus:</b> ${_escapeHtml(readinessFocusSummary)}\n'}'
              '${readinessEchoSummary.isEmpty ? '' : '• <b>Postural echo:</b> ${_escapeHtml(readinessEchoSummary)}\n'}'
              '${readinessTopIntentSummary.isEmpty ? '' : '• <b>Top intent:</b> ${_escapeHtml(readinessTopIntentSummary)}\n'}'
              '• <b>Current review:</b> <code>${_escapeHtml(readinessReview)}</code>\n'
              '${readinessCase.isEmpty ? '' : '• <b>Current case:</b> <code>${_escapeHtml(readinessCase)}</code>\n'}'
              '${readinessGovernance.isEmpty ? '' : '• <b>Open governance:</b> <code>${_escapeHtml(readinessGovernance)}</code>\n'}'
              '${previousReadinessFocusSummary.isEmpty ? '' : '• <b>Previous focus:</b> ${_escapeHtml(previousReadinessFocusSummary)}\n'}'
              '${previousReadinessReview.isEmpty ? '' : '• <b>Previous review:</b> <code>${_escapeHtml(previousReadinessReview)}</code>\n'}'
              '${previousReadinessCase.isEmpty ? '' : '• <b>Previous case:</b> <code>${_escapeHtml(previousReadinessCase)}</code>\n'}'
              '${previousReadinessGovernance.isEmpty ? '' : '• <b>Previous governance:</b> <code>${_escapeHtml(previousReadinessGovernance)}</code>\n'}'
              '\n';
    final warRoomSection = warRoomHeadline.isEmpty && warRoomSummary.isEmpty
        ? ''
        : '---\n\n'
              '<b>Synthetic War-Room</b>\n'
              '${warRoomHeadline.isEmpty ? '' : '• <b>Mode:</b> ${_escapeHtml(warRoomHeadline)}\n'}'
              '${warRoomSummary.isEmpty ? '' : '• <b>Summary:</b> ${_escapeHtml(warRoomSummary)}\n'}'
              '${warRoomPolicySummary.isEmpty ? '' : '• <b>Policy:</b> ${_escapeHtml(warRoomPolicySummary)}\n'}'
              '${syntheticFocusSummary.isEmpty ? '' : '• <b>Focus:</b> ${_escapeHtml(syntheticFocusSummary)}\n'}'
              '${warRoomHistoryHeadline.isEmpty ? '' : '• <b>Trend:</b> ${_escapeHtml(warRoomHistoryHeadline)}\n'}'
              '${warRoomHistorySummary.isEmpty ? '' : '• <b>History:</b> ${_escapeHtml(warRoomHistorySummary)}\n'}'
              '${syntheticReview.isEmpty ? '' : '• <b>Current review:</b> <code>${_escapeHtml(syntheticReview)}</code>\n'}'
              '${syntheticCase.isEmpty ? '' : '• <b>Current case:</b> <code>${_escapeHtml(syntheticCase)}</code>\n'}'
              '${previousSyntheticFocusSummary.isEmpty ? '' : '• <b>Previous focus:</b> ${_escapeHtml(previousSyntheticFocusSummary)}\n'}'
              '${previousSyntheticReview.isEmpty ? '' : '• <b>Previous review:</b> <code>${_escapeHtml(previousSyntheticReview)}</code>\n'}'
              '${previousSyntheticCase.isEmpty ? '' : '• <b>Previous case:</b> <code>${_escapeHtml(previousSyntheticCase)}</code>\n'}'
              '\n';
    return '🛰️ <b>ONYX MORNING GOVERNANCE</b>\n\n'
        '<b>Signal</b>\n'
        '<code>${_escapeHtml(signalHeader)}</code>\n\n'
        '---\n\n'
        '<b>Shift</b>\n'
        '• <b>Date:</b> ${_escapeHtml(reportDate)}\n'
        '• <b>Generated:</b> ${_escapeHtml(generatedAtUtc)}\n\n'
        '---\n\n'
        '<b>Oversight</b>\n'
        '• <b>Scene review:</b> ${_escapeHtml(_sceneReviewSummaryLine(sceneReviewSummary, normalizedSceneReviewTopPosture))}\n'
        '• <b>Site activity:</b> ${_escapeHtml(siteActivityHeadline)}\n'
        '• <b>Summary:</b> ${_escapeHtml(siteActivitySummary)}\n\n'
        '---\n\n'
        '<b>Activity Investigation</b>\n'
        '$targetLine'
        '• <b>Current review:</b> <code>${_escapeHtml(currentShiftReviewCommand)}</code>\n'
        '• <b>Current case:</b> <code>${_escapeHtml(currentShiftCaseFileCommand)}</code>\n'
        '$previousLines'
        '$targetHint'
        '$readinessSection'
        '$warRoomSection'
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

  static String _sceneReviewSummaryLine(String summary, String topPosture) {
    final trimmedSummary = summary.trim();
    if (trimmedSummary.isEmpty) {
      return 'No review actions recorded.';
    }
    final hazardLabel = _hazardSceneReviewLabel(topPosture);
    if (hazardLabel == null) {
      return trimmedSummary;
    }
    if (trimmedSummary.toLowerCase().contains(hazardLabel)) {
      return trimmedSummary;
    }
    return '${_titleCase(hazardLabel)} • $trimmedSummary';
  }

  static String? _hazardSceneReviewLabel(String topPosture) {
    if (topPosture.contains('fire') || topPosture.contains('smoke')) {
      return 'fire / smoke emergency';
    }
    if (topPosture.contains('flood') || topPosture.contains('leak')) {
      return 'flood / leak emergency';
    }
    if (topPosture.contains('hazard')) {
      return 'environmental hazard';
    }
    return null;
  }

  static String _titleCase(String value) {
    if (value.isEmpty) {
      return value;
    }
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
