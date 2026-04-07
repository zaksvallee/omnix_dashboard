import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/alarms/contact_id_event.dart';
import 'package:omnix_dashboard/domain/incidents/incident_enums.dart';

void main() {
  test('contact id payload flags test signals and frame copy updates duplicate', () {
    const payload = ContactIdPayload(
      accountNumber: '1234',
      qualifier: ContactIdQualifier.status,
      eventCode: 601,
      partition: 0,
      zone: 0,
    );
    final frame = ContactIdFrame(
      accountNumber: '1234',
      receiverNumber: '0001',
      sequenceNumber: 12,
      isEncrypted: false,
      isDuplicate: false,
      payloadData: '123418601000000',
      receivedAtUtc: DateTime.utc(2026, 4, 7, 12),
      rawFrame: '00011234/0012(123418601000000)0000\\r\\n',
    );
    final event = ContactIdEvent(
      eventId: 'evt-1',
      accountNumber: '1234',
      receiverNumber: '0001',
      sequenceNumber: 12,
      payload: payload,
      incidentType: IncidentType.systemAnomaly,
      severity: IncidentSeverity.low,
      description: '[TEST] Contact ID test signal',
      isRestore: false,
      isTest: true,
      receivedAtUtc: DateTime.utc(2026, 4, 7, 12),
      rawFrame: '00011234/0012(123418601000000)0000\\r\\n',
    );

    expect(payload.isTestSignal, isTrue);
    expect(frame.copyWith(isDuplicate: true).isDuplicate, isTrue);
    expect(event.isTest, isTrue);
  });
}
