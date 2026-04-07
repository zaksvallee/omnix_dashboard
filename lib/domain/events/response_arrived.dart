import 'dispatch_event.dart';

class ResponseArrived extends DispatchEvent {
  static const String auditTypeKey = 'response_arrived';
  final String dispatchId;
  final String guardId;
  final String clientId;
  final String regionId;
  final String siteId;

  const ResponseArrived({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.dispatchId,
    required this.guardId,
    required this.clientId,
    required this.regionId,
    required this.siteId,
  });

  @override
  ResponseArrived copyWithSequence(int sequence) {
    return ResponseArrived(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      dispatchId: dispatchId,
      guardId: guardId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );
  }

  @override
  String toAuditTypeKey() => auditTypeKey;
}
