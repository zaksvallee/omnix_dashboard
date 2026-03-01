import 'dispatch_event.dart';

class ExecutionCompleted extends DispatchEvent {
  final String dispatchId;
  final String clientId;
  final String regionId;
  final String siteId;
  final bool success;

  const ExecutionCompleted({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.dispatchId,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.success,
  });

  @override
  ExecutionCompleted copyWithSequence(int sequence) {
    return ExecutionCompleted(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      dispatchId: dispatchId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      success: success,
    );
  }
}
