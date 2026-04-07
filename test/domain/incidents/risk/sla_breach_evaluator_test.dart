import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/crm/sla_profile.dart';
import 'package:omnix_dashboard/domain/incidents/incident_enums.dart';
import 'package:omnix_dashboard/domain/incidents/incident_event.dart';
import 'package:omnix_dashboard/domain/incidents/incident_record.dart';
import 'package:omnix_dashboard/domain/incidents/risk/sla_breach_evaluator.dart';

void main() {
  const profile = SLAProfile(
    slaId: 'SLA-1',
    clientId: 'CLIENT-1',
    lowMinutes: 60,
    mediumMinutes: 30,
    highMinutes: 15,
    criticalMinutes: 5,
    createdAt: '2026-04-07T00:00:00.000Z',
  );

  IncidentRecord buildRecord({
    IncidentStatus status = IncidentStatus.classified,
  }) {
    return IncidentRecord(
      incidentId: 'INC-1',
      type: IncidentType.perimeterBreach,
      severity: IncidentSeverity.high,
      status: status,
      detectedAt: '2026-04-07T10:00:00.000Z',
      classifiedAt: '2026-04-07T10:00:00.000Z',
      geoScopeRef: 'SITE-1',
      description: 'Perimeter breach',
    );
  }

  test('emits a breach event once the incident is overdue', () {
    final event = SLABreachEvaluator.evaluate(
      history: const <IncidentEvent>[],
      record: buildRecord(),
      profile: profile,
      nowUtc: DateTime.parse('2026-04-07T10:16:00.000Z').toUtc(),
    );

    expect(event, isNotNull);
    expect(event!.type, IncidentEventType.incidentSlaBreached);
    expect(event.incidentId, 'INC-1');
    expect(event.metadata['due_at'], '2026-04-07T10:15:00.000Z');
    expect(event.metadata['severity'], IncidentSeverity.high.name);
  });

  test('does not emit a duplicate SLA breach event', () {
    final event = SLABreachEvaluator.evaluate(
      history: const <IncidentEvent>[
        IncidentEvent(
          eventId: 'SLA-INC-1-1',
          incidentId: 'INC-1',
          type: IncidentEventType.incidentSlaBreached,
          timestamp: '2026-04-07T10:16:00.000Z',
          metadata: <String, dynamic>{},
        ),
      ],
      record: buildRecord(),
      profile: profile,
      nowUtc: DateTime.parse('2026-04-07T10:18:00.000Z').toUtc(),
    );

    expect(event, isNull);
  });

  test('does not emit a breach event for a resolved incident', () {
    final event = SLABreachEvaluator.evaluate(
      history: const <IncidentEvent>[],
      record: buildRecord(status: IncidentStatus.resolved),
      profile: profile,
      nowUtc: DateTime.parse('2026-04-07T10:45:00.000Z').toUtc(),
    );

    expect(event, isNull);
  });

  test('130-second clock jump emits drift event instead of breach', () {
    final event = SLABreachEvaluator.evaluate(
      history: const <IncidentEvent>[],
      record: buildRecord(),
      profile: profile,
      nowUtc: DateTime.parse('2026-04-07T10:16:00.000Z').toUtc(),
      previousEvaluationAtUtc: DateTime.parse(
        '2026-04-07T10:13:50.000Z',
      ).toUtc(),
    );

    expect(event, isNotNull);
    expect(event!.type, IncidentEventType.incidentSlaClockDriftDetected);
    expect(event.metadata['jump_seconds'], 130);
    expect(
      event.metadata['sla_state'],
      IncidentRecord.slaStatusUnverifiableClockEvent,
    );
  });

  test('90-second clock jump still evaluates the SLA normally', () {
    final event = SLABreachEvaluator.evaluate(
      history: const <IncidentEvent>[],
      record: buildRecord(),
      profile: profile,
      nowUtc: DateTime.parse('2026-04-07T10:16:00.000Z').toUtc(),
      previousEvaluationAtUtc: DateTime.parse(
        '2026-04-07T10:14:30.000Z',
      ).toUtc(),
    );

    expect(event, isNotNull);
    expect(event!.type, IncidentEventType.incidentSlaBreached);
  });
}
