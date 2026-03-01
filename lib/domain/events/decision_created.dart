import 'dispatch_event.dart';

class DecisionCreated extends DispatchEvent {
  final String dispatchId;
  final String clientId;
  final String regionId;
  final String siteId;

  const DecisionCreated({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.dispatchId,
    required this.clientId,
    required this.regionId,
    required this.siteId,
  });

  @override
  DecisionCreated copyWithSequence(int sequence) {
    return DecisionCreated(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      dispatchId: dispatchId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );
  }
}
