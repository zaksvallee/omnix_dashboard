import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/crm/reporting/sla_dashboard_projection.dart';
import 'package:omnix_dashboard/domain/crm/sla_profile.dart';
import 'package:omnix_dashboard/domain/incidents/incident_event.dart';

void main() {
  const profile = SLAProfile(
    slaId: 'SLA-1',
    clientId: 'CLIENT-001',
    lowMinutes: 60,
    mediumMinutes: 30,
    highMinutes: 15,
    criticalMinutes: 5,
    createdAt: '2026-04-07T00:00:00Z',
  );

  test(
    'SLADashboardProjection excludes overridden breaches from breached count and compliance loss',
    () {
      final summary = SLADashboardProjection.build(
        clientId: 'CLIENT-001',
        profile: profile,
        events: const <IncidentEvent>[
          IncidentEvent(
            eventId: 'evt-detected',
            incidentId: 'INC-1',
            type: IncidentEventType.incidentDetected,
            timestamp: '2026-04-07T08:00:00Z',
            metadata: <String, dynamic>{'severity': 'high'},
          ),
          IncidentEvent(
            eventId: 'evt-breach',
            incidentId: 'INC-1',
            type: IncidentEventType.incidentSlaBreached,
            timestamp: '2026-04-07T08:10:00Z',
            metadata: <String, dynamic>{},
          ),
          IncidentEvent(
            eventId: 'evt-override',
            incidentId: 'INC-1',
            type: IncidentEventType.incidentSlaOverrideRecorded,
            timestamp: '2026-04-07T08:11:00Z',
            metadata: <String, dynamic>{},
          ),
        ],
        fromUtc: DateTime.utc(2026, 4, 7, 0),
        toUtc: DateTime.utc(2026, 4, 7, 23, 59, 59),
      );

      expect(summary.totalIncidents, 1);
      expect(summary.breachedIncidents, 0);
      expect(summary.compliancePercentage, 100.0);
      expect(summary.breachesBySeverity, isEmpty);
    },
  );

  test(
    'SLADashboardProjection skips unknown severities instead of throwing',
    () {
      final summary = SLADashboardProjection.build(
        clientId: 'CLIENT-001',
        profile: profile,
        events: const <IncidentEvent>[
          IncidentEvent(
            eventId: 'evt-detected',
            incidentId: 'INC-1',
            type: IncidentEventType.incidentDetected,
            timestamp: '2026-04-07T08:00:00Z',
            metadata: <String, dynamic>{'severity': 'severe'},
          ),
          IncidentEvent(
            eventId: 'evt-breach',
            incidentId: 'INC-1',
            type: IncidentEventType.incidentSlaBreached,
            timestamp: '2026-04-07T08:10:00Z',
            metadata: <String, dynamic>{},
          ),
        ],
        fromUtc: DateTime.utc(2026, 4, 7, 0),
        toUtc: DateTime.utc(2026, 4, 7, 23, 59, 59),
      );

      expect(summary.totalIncidents, 0);
      expect(summary.breachedIncidents, 0);
      expect(summary.compliancePercentage, 100.0);
    },
  );
}
