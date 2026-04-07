import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/crm/crm_event.dart';
import 'package:omnix_dashboard/domain/crm/sla_profile.dart';
import 'package:omnix_dashboard/domain/crm/store/crm_event_log.dart';
import 'package:omnix_dashboard/domain/incidents/client/client_incident_log_projection.dart';
import 'package:omnix_dashboard/domain/incidents/incident_enums.dart';
import 'package:omnix_dashboard/domain/incidents/incident_event.dart';
import 'package:omnix_dashboard/domain/incidents/incident_projection.dart';
import 'package:omnix_dashboard/domain/incidents/incident_service.dart';
import 'package:omnix_dashboard/domain/incidents/store/incident_event_log.dart';
import 'package:omnix_dashboard/domain/incidents/store/incident_state_storage.dart';

void main() {
  test('incident SLA breach preserves status and sets breach flag', () async {
    final incidentLog = IncidentEventLog();
    final crmLog = CRMEventLog();
    final storage = _FakeLocalEventStorage();
    final service = IncidentService(
      incidentLog,
      crmLog,
      storage,
      clock: () => DateTime.utc(2020, 1, 1, 0, 6),
    );

    incidentLog.append(
      IncidentEvent(
        eventId: 'INC-1-DETECTED',
        incidentId: 'INC-1',
        type: IncidentEventType.incidentDetected,
        timestamp: DateTime.utc(2020, 1, 1, 0, 0).toIso8601String(),
        metadata: {
          'type': IncidentType.intrusion,
          'severity': IncidentSeverity.high,
          'geo_scope': 'SITE-NORTH',
          'description': 'Perimeter breach',
        },
      ),
    );

    final emitted = await service.handle(
      IncidentEvent(
        eventId: 'INC-1-LINKED',
        incidentId: 'INC-1',
        type: IncidentEventType.incidentLinkedToDispatch,
        timestamp: DateTime.utc(2020, 1, 1, 0, 1).toIso8601String(),
        metadata: const {'dispatch_id': 'DSP-9'},
      ),
      slaProfile: const SLAProfile(
        slaId: 'SLA-1',
        clientId: 'CLIENT-1',
        lowMinutes: 5,
        mediumMinutes: 5,
        highMinutes: 5,
        criticalMinutes: 5,
        createdAt: '2020-01-01T00:00:00Z',
      ),
    );

    expect(
      emitted.map((event) => event.type),
      contains(IncidentEventType.incidentSlaBreached),
    );

    final record = IncidentProjection.rebuild(incidentLog.byIncident('INC-1'));
    expect(record.status, IncidentStatus.dispatchLinked);
    expect(record.slaBreached, isTrue);
    expect(record.linkedDispatchId, 'DSP-9');

    expect(crmLog.all(), hasLength(1));
    expect(crmLog.all().single.payload['summary'], contains('SLA breach'));
  });

  test('client incident log does not treat SLA breach as escalation', () {
    final log = ClientIncidentLogProjection.build([
      IncidentEvent(
        eventId: 'INC-2-DETECTED',
        incidentId: 'INC-2',
        type: IncidentEventType.incidentDetected,
        timestamp: DateTime.utc(2026, 4, 7, 7, 0).toIso8601String(),
        metadata: {
          'type': IncidentType.intrusion,
          'severity': IncidentSeverity.medium,
          'geo_scope': 'SITE-SOUTH',
          'description': 'Motion review',
        },
      ),
      IncidentEvent(
        eventId: 'INC-2-SLA',
        incidentId: 'INC-2',
        type: IncidentEventType.incidentSlaBreached,
        timestamp: DateTime.utc(2026, 4, 7, 7, 10).toIso8601String(),
        metadata: const {'severity': 'medium'},
      ),
    ]);

    expect(log.status, IncidentStatus.detected.name);
  });

  test(
    'initialize retroactively breaches overdue open incidents on restart',
    () async {
      final incidentLog = IncidentEventLog();
      final crmLog = CRMEventLog();
      final storage = _FakeLocalEventStorage(
        incidents: <IncidentEvent>[
          IncidentEvent(
            eventId: 'INC-3-DETECTED',
            incidentId: 'INC-3',
            type: IncidentEventType.incidentDetected,
            timestamp: '2026-04-07T10:00:00.000Z',
            metadata: {
              'type': IncidentType.intrusion,
              'severity': IncidentSeverity.high,
              'geo_scope': 'SITE-EAST',
              'description': 'Perimeter breach',
            },
          ),
        ],
      );
      final service = IncidentService(
        incidentLog,
        crmLog,
        storage,
        clock: () => DateTime.utc(2026, 4, 7, 10, 20),
      );

      await service.initialize(
        slaProfile: const SLAProfile(
          slaId: 'SLA-1',
          clientId: 'CLIENT-1',
          lowMinutes: 60,
          mediumMinutes: 30,
          highMinutes: 15,
          criticalMinutes: 5,
          createdAt: '2026-04-07T00:00:00Z',
        ),
      );

      final history = incidentLog.byIncident('INC-3');
      expect(
        history.where(
          (event) => event.type == IncidentEventType.incidentSlaBreached,
        ),
        hasLength(1),
      );
      final breach = history.last;
      expect(breach.metadata['retroactive'], isTrue);
      expect(breach.metadata['offline_duration_minutes'], 20);
    },
  );

  test(
    'initialize does not double-fire when the incident is already breached',
    () async {
      final incidentLog = IncidentEventLog();
      final crmLog = CRMEventLog();
      final storage = _FakeLocalEventStorage(
        incidents: <IncidentEvent>[
          IncidentEvent(
            eventId: 'INC-4-DETECTED',
            incidentId: 'INC-4',
            type: IncidentEventType.incidentDetected,
            timestamp: '2026-04-07T10:00:00.000Z',
            metadata: {
              'type': IncidentType.intrusion,
              'severity': IncidentSeverity.high,
              'geo_scope': 'SITE-EAST',
              'description': 'Perimeter breach',
            },
          ),
          IncidentEvent(
            eventId: 'INC-4-SLA',
            incidentId: 'INC-4',
            type: IncidentEventType.incidentSlaBreached,
            timestamp: '2026-04-07T10:16:00.000Z',
            metadata: const {
              'due_at': '2026-04-07T10:15:00.000Z',
              'severity': 'high',
            },
          ),
        ],
      );
      final service = IncidentService(
        incidentLog,
        crmLog,
        storage,
        clock: () => DateTime.utc(2026, 4, 7, 10, 30),
      );

      await service.initialize(
        slaProfile: const SLAProfile(
          slaId: 'SLA-1',
          clientId: 'CLIENT-1',
          lowMinutes: 60,
          mediumMinutes: 30,
          highMinutes: 15,
          criticalMinutes: 5,
          createdAt: '2026-04-07T00:00:00Z',
        ),
      );

      final breaches = incidentLog
          .byIncident('INC-4')
          .where((event) => event.type == IncidentEventType.incidentSlaBreached)
          .toList(growable: false);
      expect(breaches, hasLength(1));
    },
  );
}

class _FakeLocalEventStorage implements IncidentStateStorage {
  List<IncidentEvent> savedIncidents;
  List<CRMEvent> savedCrm;

  _FakeLocalEventStorage({
    List<IncidentEvent> incidents = const <IncidentEvent>[],
    List<CRMEvent> crm = const <CRMEvent>[],
  }) : savedIncidents = List<IncidentEvent>.from(incidents),
       savedCrm = List<CRMEvent>.from(crm);

  @override
  Future<void> saveIncidents(List<IncidentEvent> events) async {
    savedIncidents = List<IncidentEvent>.from(events);
  }

  @override
  Future<void> saveCrm(List<CRMEvent> events) async {
    savedCrm = List<CRMEvent>.from(events);
  }

  @override
  Future<List<IncidentEvent>> loadIncidents() async {
    return List<IncidentEvent>.from(savedIncidents);
  }

  @override
  Future<List<CRMEvent>> loadCrm() async {
    return List<CRMEvent>.from(savedCrm);
  }
}
