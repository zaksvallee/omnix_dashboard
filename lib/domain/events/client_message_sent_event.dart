import 'dispatch_event.dart';

class ClientMessageSentEvent extends DispatchEvent {
  static const String auditTypeKey = 'client_message_sent';

  final String messageKey;
  final String clientId;
  final String regionId;
  final String siteId;
  final String author;
  final String channel;
  final String provider;
  final String incidentStatusLabel;
  final String summary;

  const ClientMessageSentEvent({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.messageKey,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.author,
    required this.channel,
    required this.provider,
    required this.incidentStatusLabel,
    required this.summary,
  });

  @override
  ClientMessageSentEvent copyWithSequence(int sequence) {
    return ClientMessageSentEvent(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      messageKey: messageKey,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      author: author,
      channel: channel,
      provider: provider,
      incidentStatusLabel: incidentStatusLabel,
      summary: summary,
    );
  }

  @override
  String toAuditTypeKey() => auditTypeKey;
}
