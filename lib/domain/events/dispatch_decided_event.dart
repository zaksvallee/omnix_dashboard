import 'dispatch_event.dart';
import '../models/dispatch_action.dart';

class DispatchDecidedEvent extends DispatchEvent {
  final DispatchAction action;

  const DispatchDecidedEvent({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.action,
  });

  @override
  DispatchDecidedEvent copyWithSequence(int sequence) {
    return DispatchDecidedEvent(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      action: action,
    );
  }
}
