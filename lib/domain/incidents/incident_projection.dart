import 'incident_event.dart';
import 'incident_record.dart';
import 'incident_enums.dart';

class IncidentProjection {
  static IncidentRecord rebuild(List<IncidentEvent> events) {
    if (events.isEmpty) {
      throw Exception("Cannot rebuild incident without events");
    }

    late IncidentRecord record;

    for (final event in events) {
      switch (event.type) {
        case IncidentEventType.incidentDetected:
          record = IncidentRecord(
            incidentId: event.incidentId,
            type: event.metadata['type'] as IncidentType,
            severity: event.metadata['severity'] as IncidentSeverity,
            status: IncidentStatus.detected,
            detectedAt: event.timestamp,
            classifiedAt: event.timestamp,
            geoScopeRef: event.metadata['geo_scope'] as String,
            description: event.metadata['description'] as String,
          );
          break;

        case IncidentEventType.incidentClassified:
          record = record.transition(
            newStatus: IncidentStatus.classified,
          );
          break;

        case IncidentEventType.incidentLinkedToDispatch:
          record = record.transition(
            newStatus: IncidentStatus.dispatchLinked,
            linkedDispatchId: event.metadata['dispatch_id'] as String,
          );
          break;

        case IncidentEventType.incidentEscalated:
          record = record.transition(
            newStatus: IncidentStatus.escalated,
          );
          break;

        case IncidentEventType.incidentResolved:
          record = record.transition(
            newStatus: IncidentStatus.resolved,
            resolvedAt: event.timestamp,
          );
          break;

        case IncidentEventType.incidentClosed:
          record = record.transition(
            newStatus: IncidentStatus.closed,
            closedAt: event.timestamp,
          );
          break;

        case IncidentEventType.incidentSlaBreached:
          record = record.transition(
            newStatus: IncidentStatus.escalated,
          );
          break;
      }
    }

    return record;
  }
}
