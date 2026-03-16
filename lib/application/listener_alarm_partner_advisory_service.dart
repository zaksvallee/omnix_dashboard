import 'monitoring_shift_notification_service.dart';

enum ListenerAlarmAdvisoryDisposition {
  clear,
  suspicious,
  unavailable,
  pending,
}

class ListenerAlarmPartnerAdvisoryContext {
  final MonitoringSiteProfile site;
  final String eventLabel;
  final DateTime occurredAtUtc;
  final ListenerAlarmAdvisoryDisposition disposition;
  final String zoneLabel;
  final String cctvSummary;
  final String recommendation;

  const ListenerAlarmPartnerAdvisoryContext({
    required this.site,
    required this.eventLabel,
    required this.occurredAtUtc,
    required this.disposition,
    this.zoneLabel = '',
    this.cctvSummary = '',
    this.recommendation = '',
  });
}

class ListenerAlarmPartnerAdvisoryService {
  const ListenerAlarmPartnerAdvisoryService();

  String formatPartnerAdvisory(ListenerAlarmPartnerAdvisoryContext context) {
    final siteName = context.site.siteName.trim().isEmpty
        ? 'the monitored site'
        : context.site.siteName.trim();
    final zoneLabel = context.zoneLabel.trim();
    final eventLabel = _eventLabel(context.eventLabel);
    final siteLead = 'Signal received from $siteName'
        '${zoneLabel.isEmpty ? '' : ' ($zoneLabel)'}'
        '${eventLabel.isEmpty ? '' : ' for $eventLabel'}.';
    final reviewLead = switch (context.disposition) {
      ListenerAlarmAdvisoryDisposition.clear =>
        'CCTV checked immediately. ${_summaryOrFallback(context.cctvSummary, 'Nothing suspicious to report.')}',
      ListenerAlarmAdvisoryDisposition.suspicious =>
        'CCTV checked immediately. ${_summaryOrFallback(context.cctvSummary, 'Suspicious activity confirmed.')}',
      ListenerAlarmAdvisoryDisposition.unavailable =>
        'Alarm signal received. CCTV review is currently unavailable.',
      ListenerAlarmAdvisoryDisposition.pending =>
        'CCTV review is underway.',
    };
    final recommendation = _recommendationFor(context);
    return [
      siteLead,
      reviewLead,
      if (recommendation.isNotEmpty) recommendation,
    ].join(' ');
  }

  String _eventLabel(String label) {
    final normalized = label.trim();
    if (normalized.isEmpty || normalized == 'LISTENER_EVENT') {
      return 'alarm signal';
    }
    return normalized
        .split('_')
        .map((segment) => segment.toLowerCase())
        .join(' ');
  }

  String _summaryOrFallback(String summary, String fallback) {
    final normalized = summary.trim();
    if (normalized.isEmpty) {
      return fallback;
    }
    return normalized.endsWith('.') ? normalized : '$normalized.';
  }

  String _recommendationFor(ListenerAlarmPartnerAdvisoryContext context) {
    final normalized = context.recommendation.trim();
    if (normalized.isNotEmpty) {
      return normalized.endsWith('.') ? normalized : '$normalized.';
    }
    switch (context.disposition) {
      case ListenerAlarmAdvisoryDisposition.clear:
        return '';
      case ListenerAlarmAdvisoryDisposition.suspicious:
        return 'Escalation recommended.';
      case ListenerAlarmAdvisoryDisposition.unavailable:
        return 'Manual verification recommended while CCTV access is restored.';
      case ListenerAlarmAdvisoryDisposition.pending:
        return 'Further update to follow.';
    }
  }
}
