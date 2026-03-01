import 'dispatch_event.dart';

class IntelligenceReceived extends DispatchEvent {
  final String intelligenceId;

  const IntelligenceReceived({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.intelligenceId,
  });

  @override
  IntelligenceReceived copyWithSequence(int sequence) {
    return IntelligenceReceived(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      intelligenceId: intelligenceId,
    );
  }
}
