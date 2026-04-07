enum IncidentEventType {
  incidentDetected,
  incidentClassified,
  incidentLinkedToDispatch,
  incidentEscalated,
  incidentResolved,
  incidentClosed,
  incidentSlaBreached,
  incidentSlaClockDriftDetected,
  incidentSlaOverrideRecorded,
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

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'incidentId': incidentId,
    'type': type.name,
    'timestamp': timestamp,
    'metadata': metadata,
  };

  factory IncidentEvent.fromJson(Map<String, dynamic> json) {
    return IncidentEvent(
      eventId: json['eventId'],
      incidentId: json['incidentId'],
      type: IncidentEventType.values.firstWhere((e) => e.name == json['type']),
      timestamp: json['timestamp'],
      metadata: Map<String, dynamic>.from(json['metadata']),
    );
  }
}
