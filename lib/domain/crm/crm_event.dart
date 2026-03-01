enum CRMEventType {
  clientCreated,
  siteAdded,
  slaProfileAttached,
  slaProfileUpdated,
  clientContactLogged,
}

class CRMEvent {
  final String eventId;
  final String aggregateId;
  final CRMEventType type;
  final String timestamp;
  final Map<String, dynamic> payload;

  const CRMEvent({
    required this.eventId,
    required this.aggregateId,
    required this.type,
    required this.timestamp,
    required this.payload,
  });

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'aggregateId': aggregateId,
        'type': type.name,
        'timestamp': timestamp,
        'payload': payload,
      };

  factory CRMEvent.fromJson(Map<String, dynamic> json) {
    return CRMEvent(
      eventId: json['eventId'],
      aggregateId: json['aggregateId'],
      type: CRMEventType.values
          .firstWhere((e) => e.name == json['type']),
      timestamp: json['timestamp'],
      payload: Map<String, dynamic>.from(json['payload']),
    );
  }
}
