enum IncidentEventType {
  incidentDetected,
  incidentClassified,
  incidentLinkedToDispatch,
  incidentEscalated,
  incidentResolved,
  incidentClosed,
  incidentSlaBreached
}

class IncidentEvent {
  final String eventId;
  final String incidentId;
  final IncidentEventType type;
  final String timestamp;
  final Map<String, dynamic> metadata;

  const IncidentEvent({
    required this.eventId,
    required this.incidentId,
    required this.type,
    required this.timestamp,
    required this.metadata,
  });
}
