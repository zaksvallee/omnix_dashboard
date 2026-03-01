import '../incidents/incident_event.dart';
import '../crm/crm_event.dart';

class IncidentToCRMMapper {
  static CRMEvent? map({
    required IncidentEvent incidentEvent,
    required String clientId,
  }) {
    if (incidentEvent.type != IncidentEventType.incidentSlaBreached) {
      return null;
    }

    return CRMEvent(
      eventId: _generateId(clientId),
      aggregateId: clientId,
      type: CRMEventType.clientContactLogged,
      timestamp: incidentEvent.timestamp,
      payload: {
        'contact_id': _generateId(clientId),
        'channel': 'system_auto',
        'summary': 'SLA breach detected for incident ${incidentEvent.incidentId}',
      },
    );
  }

  static String _generateId(String clientId) {
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
    return 'CRM-$clientId-$ts';
  }
}
