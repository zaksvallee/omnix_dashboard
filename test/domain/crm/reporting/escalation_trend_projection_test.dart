import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/crm/reporting/escalation_trend_projection.dart';
import 'package:omnix_dashboard/domain/incidents/incident_event.dart';

void main() {
  test('returns zero deltas when no events exist', () {
    final trend = EscalationTrendProjection.build(
      clientId: 'CLIENT-1',
      currentMonth: '2026-04',
      previousMonth: '2026-03',
      incidentEvents: const <IncidentEvent>[],
    );

    expect(trend.currentEscalations, 0);
    expect(trend.previousEscalations, 0);
    expect(trend.escalationDeltaPercent, 0.0);
    expect(trend.currentSlaBreaches, 0);
    expect(trend.previousSlaBreaches, 0);
    expect(trend.breachDeltaPercent, 0.0);
  });

  test('treats a zero previous month as a full increase', () {
    final trend = EscalationTrendProjection.build(
      clientId: 'CLIENT-1',
      currentMonth: '2026-04',
      previousMonth: '2026-03',
      incidentEvents: const <IncidentEvent>[
        IncidentEvent(
          eventId: 'E-1',
          incidentId: 'INC-1',
          type: IncidentEventType.incidentEscalated,
          timestamp: '2026-04-07T10:00:00.000Z',
          metadata: <String, dynamic>{},
        ),
      ],
    );

    expect(trend.currentEscalations, 1);
    expect(trend.previousEscalations, 0);
    expect(trend.escalationDeltaPercent, 100.0);
  });

  test('counts only matching escalation and SLA breach events by month', () {
    final trend = EscalationTrendProjection.build(
      clientId: 'CLIENT-1',
      currentMonth: '2026-04',
      previousMonth: '2026-03',
      incidentEvents: const <IncidentEvent>[
        IncidentEvent(
          eventId: 'E-1',
          incidentId: 'INC-1',
          type: IncidentEventType.incidentEscalated,
          timestamp: '2026-04-07T10:00:00.000Z',
          metadata: <String, dynamic>{},
        ),
        IncidentEvent(
          eventId: 'E-2',
          incidentId: 'INC-2',
          type: IncidentEventType.incidentEscalated,
          timestamp: '2026-03-07T10:00:00.000Z',
          metadata: <String, dynamic>{},
        ),
        IncidentEvent(
          eventId: 'E-3',
          incidentId: 'INC-3',
          type: IncidentEventType.incidentSlaBreached,
          timestamp: '2026-04-08T10:00:00.000Z',
          metadata: <String, dynamic>{},
        ),
        IncidentEvent(
          eventId: 'E-4',
          incidentId: 'INC-4',
          type: IncidentEventType.incidentSlaBreached,
          timestamp: '2026-03-09T10:00:00.000Z',
          metadata: <String, dynamic>{},
        ),
        IncidentEvent(
          eventId: 'E-5',
          incidentId: 'INC-5',
          type: IncidentEventType.incidentDetected,
          timestamp: '2026-04-10T10:00:00.000Z',
          metadata: <String, dynamic>{},
        ),
      ],
    );

    expect(trend.currentEscalations, 1);
    expect(trend.previousEscalations, 1);
    expect(trend.escalationDeltaPercent, 0.0);
    expect(trend.currentSlaBreaches, 1);
    expect(trend.previousSlaBreaches, 1);
    expect(trend.breachDeltaPercent, 0.0);
  });
}
