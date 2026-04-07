import '../incidents/incident_event.dart';
import '../crm/crm_event.dart';

class IncidentToCRMMapper {
  static CRMEvent? map({
    required IncidentEvent incidentEvent,
    required String clientId,
    DateTime Function()? clock,
  }) {
    if (incidentEvent.type != IncidentEventType.incidentSlaBreached) {
      return null;
    }

    final nowUtc = (clock ?? DateTime.now).call().toUtc();

    return CRMEvent(
      eventId: _generateId(clientId, nowUtc),
      aggregateId: clientId,
      type: CRMEventType.clientContactLogged,
      timestamp: incidentEvent.timestamp,
      payload: {
        'contact_id': _generateId(clientId, nowUtc),
        'channel': 'system_auto',
        'summary':
            'SLA breach detected for incident ${incidentEvent.incidentId}',
      },
    );
  }

  static String _generateId(String clientId, DateTime nowUtc) {
    final ts = nowUtc.millisecondsSinceEpoch;
    return 'CRM-$clientId-$ts';
  }
}
