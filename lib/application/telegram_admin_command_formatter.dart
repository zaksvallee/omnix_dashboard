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
}
