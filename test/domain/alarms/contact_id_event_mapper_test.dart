import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/alarms/contact_id_event.dart';
import 'package:omnix_dashboard/domain/alarms/contact_id_event_mapper.dart';
import 'package:omnix_dashboard/domain/incidents/incident_enums.dart';

void main() {
  final frame = ContactIdFrame(
    accountNumber: '1234',
    receiverNumber: '0001',
    sequenceNumber: 42,
    isEncrypted: false,
    isDuplicate: false,
    payloadData: '123418113001003',
    receivedAtUtc: DateTime.utc(2026, 4, 7, 11, 45),
    rawFrame: '00011234/002A(123418113001003)ABCD\r\n',
  );
  final mapper = ContactIdEventMapper(
    eventIdBuilder: (_, payload) => 'evt-${payload.eventCode}',
  );

  test('ContactIdEventMapper maps the reference table ranges', () {
    final cases = <({int code, IncidentType type, IncidentSeverity severity})>[
      (code: 100, type: IncidentType.panicAlert, severity: IncidentSeverity.critical),
      (code: 111, type: IncidentType.alarmTrigger, severity: IncidentSeverity.critical),
      (code: 121, type: IncidentType.panicAlert, severity: IncidentSeverity.critical),
      (code: 130, type: IncidentType.intrusion, severity: IncidentSeverity.high),
      (code: 140, type: IncidentType.alarmTrigger, severity: IncidentSeverity.high),
      (code: 150, type: IncidentType.alarmTrigger, severity: IncidentSeverity.medium),
      (code: 161, type: IncidentType.equipmentFailure, severity: IncidentSeverity.medium),
      (code: 301, type: IncidentType.systemAnomaly, severity: IncidentSeverity.low),
      (code: 321, type: IncidentType.systemAnomaly, severity: IncidentSeverity.low),
      (code: 400, type: IncidentType.accessViolation, severity: IncidentSeverity.low),
      (code: 570, type: IncidentType.accessViolation, severity: IncidentSeverity.medium),
      (code: 601, type: IncidentType.systemAnomaly, severity: IncidentSeverity.low),
    ];

    for (final testCase in cases) {
      final event = mapper.map(
        frame: frame,
        payload: ContactIdPayload(
          accountNumber: '1234',
          qualifier: ContactIdQualifier.newEvent,
          eventCode: testCase.code,
          partition: 1,
          zone: 3,
        ),
      );

      expect(event.incidentType, testCase.type, reason: 'code ${testCase.code}');
      expect(event.severity, testCase.severity, reason: 'code ${testCase.code}');
    }
  });

  test('ContactIdEventMapper maps unknown codes to IncidentType.other', () {
    final event = mapper.map(
      frame: frame,
      payload: const ContactIdPayload(
        accountNumber: '1234',
        qualifier: ContactIdQualifier.newEvent,
        eventCode: 999,
        partition: 1,
        zone: 3,
      ),
    );

    expect(event.incidentType, IncidentType.other);
    expect(event.severity, IncidentSeverity.medium);
    expect(event.description, contains('999'));
  });

  test('ContactIdEventMapper marks restore events and lowers burglary severity', () {
    final event = mapper.map(
      frame: frame,
      payload: const ContactIdPayload(
        accountNumber: '1234',
        qualifier: ContactIdQualifier.restore,
        eventCode: 130,
        partition: 1,
        zone: 3,
      ),
    );

    expect(event.isRestore, isTrue);
    expect(event.severity, IncidentSeverity.medium);
    expect(event.description, startsWith('[RESTORE]'));
  });

  test('ContactIdEventMapper does not lower severity for critical restore', () {
    final event = mapper.map(
      frame: frame,
      payload: const ContactIdPayload(
        accountNumber: '1234',
        qualifier: ContactIdQualifier.restore,
        eventCode: 121,
        partition: 1,
        zone: 3,
      ),
    );

    expect(event.severity, IncidentSeverity.critical);
  });

  test('ContactIdEventMapper flags test signals without dispatch downgrade', () {
    final event = mapper.map(
      frame: frame,
      payload: const ContactIdPayload(
        accountNumber: '1234',
        qualifier: ContactIdQualifier.status,
        eventCode: 601,
        partition: 0,
        zone: 0,
      ),
    );

    expect(event.isTest, isTrue);
    expect(event.description, startsWith('[TEST]'));
  });
}
