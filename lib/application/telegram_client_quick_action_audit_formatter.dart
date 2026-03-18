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
      TelegramClientQuickAction.sleepCheck => lines.take(7).join(' | '),
      TelegramClientQuickAction.status => lines.take(8).join(' | '),
    };
  }

  String _fullStatusPreview(List<String> lines) {
    const statusPrefixes = <String>[
      'Monitoring:',
      'Window:',
      'Reviewed activity:',
      'Latest activity source:',
      'Latest posture:',
      'Current assessment:',
      'Current site narrative:',
      'Latest review summary:',
      'Latest decision:',
      'Open follow-up actions:',
      'Monitoring availability:',
      'Last reviewed at:',
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
      if (selected.length >= 12) {
        break;
      }
    }
    return selected.join(' | ');
  }
}
