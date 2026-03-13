class TelegramAdminCommandFormatter {
  const TelegramAdminCommandFormatter._();

  static String pollOps({
    required String pollResult,
    required String radioHealth,
    required String cctvHealth,
    String? cctvContext,
    required String wearableHealth,
    required String newsHealth,
    required String utcStamp,
  }) {
    final cctvContextLine = _optionalLine(
      label: '<b>CCTV Context:</b>',
      value: cctvContext,
      separator: ' ',
    );
    return '📡 <b>ONYX POLLOPS</b>\n\n'
        '<b>Poll Result</b>\n'
        '$pollResult\n\n'
        '---\n\n'
        '<b>Integrations</b>\n'
        '• <b>Radio:</b> $radioHealth\n'
        '• <b>CCTV:</b> $cctvHealth\n'
        '$cctvContextLine'
        '• <b>Wearable:</b> $wearableHealth\n'
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
    required String wearableStatus,
    required String livePollingLabel,
    required String utcStamp,
  }) {
    final cctvHealthLine = _optionalLine(
      label: 'CCTV Health:',
      value: cctvHealth,
      separator: ' ',
    );
    final cctvRecentLine = _optionalLine(
      label: 'CCTV Recent:',
      value: cctvRecent,
      separator: ' ',
    );
    return 'ONYX BRIDGES\n'
        'Telegram: $telegramStatus\n'
        'Radio: $radioStatus\n'
        'CCTV: $cctvStatus\n'
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
