import 'dispatch_event.dart';

enum ExecutionOutcome {
  success,
  failure,
}

class ExecutionCompletedEvent extends DispatchEvent {
  final String dispatchId;
  final ExecutionOutcome outcome;
  final String? failureType;

  const ExecutionCompletedEvent({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.dispatchId,
    required this.outcome,
    this.failureType,
  });

  @override
  ExecutionCompletedEvent copyWithSequence(int sequence) {
    return ExecutionCompletedEvent(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      dispatchId: dispatchId,
      outcome: outcome,
      failureType: failureType,
    );
  }
}
