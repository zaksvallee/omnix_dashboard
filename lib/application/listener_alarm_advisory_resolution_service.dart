import 'listener_alarm_partner_advisory_service.dart';
import 'listener_alarm_scope_mapping_service.dart';
import 'listener_serial_ingestor.dart';

class ListenerAlarmAdvisoryResolution {
  final ListenerAlarmScopeResolution scope;
  final ListenerSerialEnvelope envelope;
  final String eventLabel;
  final String advisoryMessage;
  final ListenerAlarmAdvisoryDisposition disposition;

  const ListenerAlarmAdvisoryResolution({
    required this.scope,
    required this.envelope,
    required this.eventLabel,
    required this.advisoryMessage,
    required this.disposition,
  });
}

class ListenerAlarmAdvisoryResolutionService {
  final ListenerAlarmScopeMappingService scopeMappingService;
  final ListenerAlarmPartnerAdvisoryService advisoryService;

  const ListenerAlarmAdvisoryResolutionService({
    this.scopeMappingService = const ListenerAlarmScopeMappingService(),
    this.advisoryService = const ListenerAlarmPartnerAdvisoryService(),
  });

  ListenerAlarmAdvisoryResolution? resolvePartnerAdvisory({
    required ListenerSerialEnvelope envelope,
    required List<ListenerAlarmScopeMappingEntry> scopeEntries,
    required ListenerAlarmAdvisoryDisposition disposition,
    String cctvSummary = '',
    String recommendation = '',
  }) {
    final scope = scopeMappingService.resolve(
      envelope: envelope,
      entries: scopeEntries,
    );
    if (scope == null) {
      return null;
    }

    final remappedEnvelope = scope.remappedEnvelope();
    final eventLabel = _eventLabelFor(remappedEnvelope);
    final advisoryMessage = advisoryService.formatPartnerAdvisory(
      ListenerAlarmPartnerAdvisoryContext(
        site: scope.siteProfile,
        eventLabel: eventLabel,
        occurredAtUtc: remappedEnvelope.occurredAtUtc,
        disposition: disposition,
        zoneLabel: scope.resolvedZoneLabel,
        cctvSummary: cctvSummary,
        recommendation: recommendation,
      ),
    );

    return ListenerAlarmAdvisoryResolution(
      scope: scope,
      envelope: remappedEnvelope,
      eventLabel: eventLabel,
      advisoryMessage: advisoryMessage,
      disposition: disposition,
    );
  }

  String _eventLabelFor(ListenerSerialEnvelope envelope) {
    final metadataLabel =
        envelope.metadata['normalized_event_label']?.toString().trim() ?? '';
    if (metadataLabel.isNotEmpty) {
      return metadataLabel;
    }
    switch (envelope.eventCode.trim()) {
      case '130':
        return 'BURGLARY_ALARM';
      case '131':
        return 'PERIMETER_ALARM';
      case '140':
        return 'GENERAL_ALARM';
      case '301':
        return 'OPENING';
      case '302':
        return 'CLOSING';
      default:
        return 'LISTENER_EVENT';
    }
  }
}
