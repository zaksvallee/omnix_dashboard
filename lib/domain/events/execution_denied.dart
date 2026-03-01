import 'dispatch_event.dart';

class ExecutionDenied extends DispatchEvent {
  final String dispatchId;
  final String clientId;
  final String regionId;
  final String siteId;
  final String operatorId;
  final String reason;

  const ExecutionDenied({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.dispatchId,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.operatorId,
    required this.reason,
  });

  @override
  ExecutionDenied copyWithSequence(int sequence) {
    return ExecutionDenied(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      dispatchId: dispatchId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      operatorId: operatorId,
      reason: reason,
    );
  }
}
