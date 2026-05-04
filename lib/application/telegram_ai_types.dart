/// Public types for the Telegram AI subsystem.
///
/// Extracted from `telegram_ai_assistant_service.dart` as Module 1
/// of the decomposition plan in
/// `audit/telegram_ai_service_decomposition_2026-05-04.md`.
///
/// These types are the public API surface for the subsystem —
/// imported by both internal modules (head, parts, intent_resolver)
/// and external consumers (telegram_client_quick_action_service,
/// onyx_telegram_operational_command_service, main.dart, etc.).
/// The head file re-exports this module to preserve existing
/// external consumer imports.
library;

enum TelegramAiAudience { admin, client }

enum TelegramAiDeliveryMode { telegramLive, approvalDraft, smsFallback }

class TelegramAiDraftReply {
  final String text;
  final bool usedFallback;
  final String providerLabel;
  final bool usedLearnedApprovalStyle;

  const TelegramAiDraftReply({
    required this.text,
    this.usedFallback = false,
    this.providerLabel = 'fallback',
    this.usedLearnedApprovalStyle = false,
  });
}

class TelegramAiSiteAwarenessSummary {
  final DateTime observedAtUtc;
  final bool perimeterClear;
  final int humanCount;
  final int vehicleCount;
  final int animalCount;
  final int motionCount;
  final int activeAlertCount;
  final List<String> knownFaultChannels;

  const TelegramAiSiteAwarenessSummary({
    required this.observedAtUtc,
    required this.perimeterClear,
    required this.humanCount,
    required this.vehicleCount,
    required this.animalCount,
    required this.motionCount,
    required this.activeAlertCount,
    this.knownFaultChannels = const <String>[],
  });

  String get watchStatusPromptValue => perimeterClear
      ? 'active from fresh live site snapshot'
      : 'active from fresh live site snapshot with a perimeter alert';

  String get cameraStatusPromptValue {
    if (knownFaultChannels.isEmpty) {
      return 'active from fresh live site snapshot';
    }
    return 'active from fresh live site snapshot with ${_channelFaultPromptLabel()}';
  }

  String get activeIncidentsPromptValue {
    if (activeAlertCount > 0 || !perimeterClear) {
      return '$activeAlertCount active - live site snapshot shows ${perimeterClear ? 'alerts on site' : 'a perimeter alert'}';
    }
    return '0 active - live site snapshot shows perimeter clear';
  }

  String get lastActivityPromptValue =>
      '${observedAtUtc.toUtc().toIso8601String()} - live site snapshot: ${_perimeterPromptLabel()}, ${_countLabel(humanCount, 'person')}, ${_countLabel(vehicleCount, 'vehicle')}, ${_countLabel(animalCount, 'animal')}';

  String get contextSummary =>
      '${_perimeterPromptLabel()}, ${_countLabel(humanCount, 'person')}, ${_countLabel(vehicleCount, 'vehicle')}, ${_countLabel(animalCount, 'animal')}, ${_countLabel(activeAlertCount, 'active alert')}, ${knownFaultChannels.isEmpty ? 'all reporting channels healthy' : _channelFaultPromptLabel()}';

  String clientMonitoringSummary({
    required String siteReference,
    String? extraDetail,
    String? nextStepQuestion,
  }) {
    final normalizedSiteReference = siteReference.trim().isEmpty
        ? 'the site'
        : siteReference.trim();
    final onSiteLabel = _presenceSummaryLabel();
    final channelLine = knownFaultChannels.isEmpty
        ? 'Channel status: All reporting channels healthy'
        : 'Channel status: ${_channelFaultStatusLine()}';
    final parts = <String>[
      'Monitoring active at $normalizedSiteReference.',
      'Perimeter: ${perimeterClear ? 'Clear' : 'Alert active'}',
      'On site: $onSiteLabel',
      'Active alerts: ${activeAlertCount == 0 ? 'None' : _countLabel(activeAlertCount, 'active alert')}',
      'Last update: ${_relativeAgeLabel()}',
      channelLine,
      if (extraDetail != null && extraDetail.trim().isNotEmpty)
        extraDetail.trim(),
      if (nextStepQuestion != null && nextStepQuestion.trim().isNotEmpty)
        nextStepQuestion.trim(),
    ];
    return parts.join(' ');
  }

  String _perimeterPromptLabel() =>
      perimeterClear ? 'perimeter clear' : 'perimeter alert active';

  String _channelFaultPromptLabel() {
    final labels = knownFaultChannels
        .map((value) => 'Channel $value')
        .join(', ');
    final noun = knownFaultChannels.length == 1
        ? 'known fault on'
        : 'known faults on';
    return '$noun $labels';
  }

  String _channelFaultStatusLine() {
    return knownFaultChannels
        .map((value) => 'Channel $value offline (known fault)')
        .join(' • ');
  }

  String _presenceSummaryLabel() {
    final parts = <String>[
      if (humanCount > 0) _countLabel(humanCount, 'person'),
      if (vehicleCount > 0) _countLabel(vehicleCount, 'vehicle'),
      if (animalCount > 0) _countLabel(animalCount, 'animal'),
    ];
    if (parts.isEmpty) {
      return 'No people detected';
    }
    return '${parts.join(' • ')} detected';
  }

  String _relativeAgeLabel() {
    final difference = DateTime.now().toUtc().difference(observedAtUtc).abs();
    if (difference < const Duration(minutes: 1)) {
      return 'just now';
    }
    if (difference < const Duration(hours: 1)) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    }
    if (difference < const Duration(days: 1)) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }
    final days = difference.inDays;
    return '$days ${days == 1 ? 'day' : 'days'} ago';
  }

  static String _countLabel(int count, String singular) {
    final plural = singular == 'person' ? 'people' : '${singular}s';
    final noun = count == 1 ? singular : plural;
    return '$count $noun';
  }
}
