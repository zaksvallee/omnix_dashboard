import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/crm/crm_event.dart';
import 'package:omnix_dashboard/domain/incidents/incident_event.dart';
import 'package:omnix_dashboard/domain/integration/incident_to_crm_mapper.dart';

void main() {
  test('IncidentToCRMMapper uses the injected clock for deterministic ids', () {
    final incidentEvent = IncidentEvent(
      eventId: 'INC-EVT-1',
      incidentId: 'INC-1',
      type: IncidentEventType.incidentSlaBreached,
      timestamp: '2026-04-07T09:30:00Z',
      metadata: const <String, dynamic>{},
    );

    final result = IncidentToCRMMapper.map(
      incidentEvent: incidentEvent,
      clientId: 'CLIENT-001',
      clock: () => DateTime.utc(2026, 4, 7, 9, 45, 30, 123),
    );

    expect(result, isNotNull);
    expect(result!.type, CRMEventType.clientContactLogged);
    expect(result.eventId, 'CRM-CLIENT-001-1775555130123');
    expect(result.payload['contact_id'], 'CRM-CLIENT-001-1775555130123');
    expect(result.timestamp, incidentEvent.timestamp);
  });
}
