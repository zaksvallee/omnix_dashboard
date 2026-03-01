import '../incident_event.dart';
import 'timeline_entry.dart';

class IncidentTimelineBuilder {
  static List<TimelineEntry> build(List<IncidentEvent> events) {
    final sorted = [...events]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final timeline = <TimelineEntry>[];

    for (final event in sorted) {
      switch (event.type) {
        case IncidentEventType.incidentDetected:
          timeline.add(
            TimelineEntry(
              label: 'Incident Detected',
              timestamp: event.timestamp,
              metadata: {
                'type': event.metadata['type']?.toString(),
                'severity': event.metadata['severity']?.toString(),
                'geo_scope': event.metadata['geo_scope'],
              },
            ),
          );
          break;

        case IncidentEventType.incidentClassified:
          timeline.add(
            TimelineEntry(
              label: 'Incident Classified',
              timestamp: event.timestamp,
              metadata: {},
            ),
          );
          break;

        case IncidentEventType.incidentLinkedToDispatch:
          timeline.add(
            TimelineEntry(
              label: 'Dispatch Linked',
              timestamp: event.timestamp,
              metadata: {
                'dispatch_id': event.metadata['dispatch_id'],
              },
            ),
          );
          break;

        case IncidentEventType.incidentEscalated:
          timeline.add(
            TimelineEntry(
              label: 'Escalated',
              timestamp: event.timestamp,
              metadata: {},
            ),
          );
          break;

        case IncidentEventType.incidentSlaBreached:
          timeline.add(
            TimelineEntry(
              label: 'SLA Breached',
              timestamp: event.timestamp,
              metadata: {
                'due_at': event.metadata['due_at'],
              },
            ),
          );
          break;

        case IncidentEventType.incidentResolved:
          timeline.add(
            TimelineEntry(
              label: 'Resolved',
              timestamp: event.timestamp,
              metadata: {},
            ),
          );
          break;

        case IncidentEventType.incidentClosed:
          timeline.add(
            TimelineEntry(
              label: 'Closed',
              timestamp: event.timestamp,
              metadata: {},
            ),
          );
          break;
      }
    }

    return timeline;
  }
}
