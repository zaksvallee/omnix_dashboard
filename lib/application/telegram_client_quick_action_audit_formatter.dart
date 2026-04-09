import 'telegram_client_quick_action_service.dart';

class TelegramClientQuickActionAuditFormatter {
  const TelegramClientQuickActionAuditFormatter();

  String buildPreview({
    required TelegramClientQuickAction action,
    required String responseText,
  }) {
    final lines = responseText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      return '(empty quick action reply)';
    }
    return switch (action) {
      TelegramClientQuickAction.statusFull => _fullStatusPreview(lines),
      TelegramClientQuickAction.sleepCheck => lines.take(8).join(' | '),
      TelegramClientQuickAction.cameraCheck => _fullStatusPreview(lines),
      TelegramClientQuickAction.nextStep => lines.take(10).join(' | '),
      TelegramClientQuickAction.status => lines.take(10).join(' | '),
      TelegramClientQuickAction.clear => 'alerts_cleared',
    };
  }

  String _fullStatusPreview(List<String> lines) {
    const statusPrefixes = <String>[
      'Current status',
      'What we see now',
      'Next',
      'Monitoring is ',
      'Remote monitoring is ',
      'Monitoring:',
      'Watch window:',
      'Items reviewed:',
      'Latest signal:',
      'Latest activity source:',
      'Current posture:',
      'Assessment:',
      'Summary:',
      'Review note:',
      'Current decision:',
      'Next step:',
      'Open follow-ups:',
      'Remote watch:',
      'Last check:',
    ];
    final selected = <String>[];
    for (final line in lines) {
      final shouldInclude =
          selected.length < 2 ||
          statusPrefixes.any((prefix) => line.startsWith(prefix));
      if (!shouldInclude) {
        continue;
      }
      selected.add(line);
      if (selected.length >= 20) {
        break;
      }
    }
    return selected.join(' | ');
  }
}
