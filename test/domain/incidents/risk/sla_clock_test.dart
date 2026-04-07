import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/crm/sla_profile.dart';
import 'package:omnix_dashboard/domain/incidents/incident_enums.dart';
import 'package:omnix_dashboard/domain/incidents/incident_record.dart';
import 'package:omnix_dashboard/domain/incidents/risk/sla_clock.dart';

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
    required IncidentSeverity severity,
    required IncidentStatus status,
    required String detectedAt,
  }) {
    return IncidentRecord(
      incidentId: 'INC-1',
      type: IncidentType.alarmTrigger,
      severity: severity,
      status: status,
      detectedAt: detectedAt,
      classifiedAt: detectedAt,
      geoScopeRef: 'SITE-1',
      description: 'Alarm triggered',
    );
  }

  test('marks clock breached after the SLA due time', () {
    final clock = SLAClock.evaluate(
      record: buildRecord(
        severity: IncidentSeverity.high,
        status: IncidentStatus.classified,
        detectedAt: '2026-04-07T10:00:00.000Z',
      ),
      profile: profile,
      nowUtc: DateTime.parse('2026-04-07T10:16:00.000Z').toUtc(),
    );

    expect(clock.startedAt, '2026-04-07T10:00:00.000Z');
    expect(clock.dueAt, '2026-04-07T10:15:00.000Z');
    expect(clock.breached, isTrue);
  });

  test('suppresses breach when the incident is terminal', () {
    final clock = SLAClock.evaluate(
      record: buildRecord(
        severity: IncidentSeverity.critical,
        status: IncidentStatus.resolved,
        detectedAt: '2026-04-07T10:00:00.000Z',
      ),
      profile: profile,
      nowUtc: DateTime.parse('2026-04-07T10:45:00.000Z').toUtc(),
    );

    expect(clock.breached, isFalse);
    expect(clock.dueAt, '2026-04-07T10:05:00.000Z');
  });

  test('rejects detectedAt timestamps without a UTC Z suffix', () {
    expect(
      () => SLAClock.evaluate(
        record: buildRecord(
          severity: IncidentSeverity.high,
          status: IncidentStatus.classified,
          detectedAt: '2026-04-07T10:00:00.000',
        ),
        profile: profile,
        nowUtc: DateTime.parse('2026-04-07T10:16:00.000Z').toUtc(),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          contains('must be UTC and end with Z'),
        ),
      ),
    );
  });
}
