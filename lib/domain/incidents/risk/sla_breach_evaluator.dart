import '../../crm/sla_profile.dart';
import '../incident_event.dart';
import '../incident_record.dart';
import 'sla_clock.dart';

class SLABreachEvaluator {
  static IncidentEvent? evaluate({
    required List<IncidentEvent> history,
    required IncidentRecord record,
    required SLAProfile profile,
    required DateTime nowUtc,
  }) {
    final alreadyBreached = history.any(
      (e) => e.type == IncidentEventType.incidentSlaBreached,
    );

    if (alreadyBreached) return null;

    final clock = SLAClock.evaluate(
      record: record,
      profile: profile,
      nowUtc: nowUtc,
    );

    if (!clock.breached) return null;

    return IncidentEvent(
      eventId: _generateId(record.incidentId),
      incidentId: record.incidentId,
      type: IncidentEventType.incidentSlaBreached,
      timestamp: nowUtc.toUtc().toIso8601String(),
      metadata: {
        'due_at': clock.dueAt,
        'severity': record.severity.name,
      },
    );
  }

  static String _generateId(String incidentId) {
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
    return 'SLA-$incidentId-$ts';
  }
}
