abstract class DispatchEvent {
  final String eventId;
  final int sequence; // Assigned ONLY by EventStore
  final int version;  // Schema version
  final DateTime occurredAt;

  const DispatchEvent({
    required this.eventId,
    required this.sequence,
    required this.version,
    required this.occurredAt,
  });

  DispatchEvent copyWithSequence(int sequence);

  String toAuditTypeKey();
}
