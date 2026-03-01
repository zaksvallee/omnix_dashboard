import '../incident_event.dart';
import '../incident_enums.dart';
import '../timeline/incident_timeline_builder.dart';
import 'client_incident_log.dart';

class ClientIncidentLogProjection {
  static ClientIncidentLog build(List<IncidentEvent> events) {
    if (events.isEmpty) {
      throw Exception("Cannot build client log without events");
    }

    final timeline = IncidentTimelineBuilder.build(events);

    final first = events.first;
    final last = events.last;

    final type = first.metadata['type']?.toString() ?? 'unknown';
    final severity = first.metadata['severity']?.toString() ?? 'unknown';

    IncidentStatus status = IncidentStatus.detected;

    for (final event in events) {
      switch (event.type) {
        case IncidentEventType.incidentResolved:
          status = IncidentStatus.resolved;
          break;
        case IncidentEventType.incidentClosed:
          status = IncidentStatus.closed;
          break;
        case IncidentEventType.incidentEscalated:
        case IncidentEventType.incidentSlaBreached:
          status = IncidentStatus.escalated;
          break;
        default:
          break;
      }
    }

    final resolvedEvent = events.firstWhere(
      (e) =>
          e.type == IncidentEventType.incidentResolved ||
          e.type == IncidentEventType.incidentClosed,
      orElse: () => last,
    );

    return ClientIncidentLog(
      incidentId: first.incidentId,
      type: type,
      severity: severity,
      status: status.name,
      detectedAt: first.timestamp,
      resolvedAt: resolvedEvent.type == IncidentEventType.incidentResolved ||
              resolvedEvent.type == IncidentEventType.incidentClosed
          ? resolvedEvent.timestamp
          : null,
      geoScope: first.metadata['geo_scope']?.toString() ?? 'unspecified',
      actions: timeline.map((t) => t.label).toList(),
    );
  }
}
