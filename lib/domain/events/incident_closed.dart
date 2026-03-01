import 'dispatch_event.dart';

class IncidentClosed extends DispatchEvent {
  final String dispatchId;
  final String resolutionType;
  final String clientId;
  final String regionId;
  final String siteId;

  const IncidentClosed({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.dispatchId,
    required this.resolutionType,
    required this.clientId,
    required this.regionId,
    required this.siteId,
  });

  @override
  IncidentClosed copyWithSequence(int sequence) {
    return IncidentClosed(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      dispatchId: dispatchId,
      resolutionType: resolutionType,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );
  }
}
