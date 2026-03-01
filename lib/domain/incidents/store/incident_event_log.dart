import '../incident_event.dart';

class IncidentEventLog {
  final List<IncidentEvent> _events = [];

  void append(IncidentEvent event) {
    _events.add(event);
  }

  List<IncidentEvent> all() {
    return List.unmodifiable(_events);
  }

  List<IncidentEvent> byIncident(String incidentId) {
    return _events
        .where((e) => e.incidentId == incidentId)
        .toList();
  }
}
