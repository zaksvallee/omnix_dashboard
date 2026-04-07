import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/alarms/contact_id_event.dart';
import 'package:omnix_dashboard/domain/alarms/contact_id_event_mapper.dart';
import 'package:omnix_dashboard/domain/incidents/incident_enums.dart';
import 'package:omnix_dashboard/infrastructure/alarm/contact_id_payload_parser.dart';
import 'package:omnix_dashboard/infrastructure/alarm/sia_dc09_frame_parser.dart';

void main() {
  final aesKey = Uint8List.fromList(List<int>.generate(16, (index) => index + 1));

  test('Contact ID pipeline maps a valid frame into an incident event', () {
    final frameParser = SiaDc09FrameParser(
      now: () => DateTime.utc(2026, 4, 7, 12, 30),
    );
    const payloadParser = ContactIdPayloadParser();
    final eventMapper = ContactIdEventMapper(
      eventIdBuilder: (_, payload) => 'evt-${payload.eventCode}',
    );
    final rawFrame = SiaDc09FrameParser.appendCrc(
      '00011234/002A(123418113001003)',
    );

    final frameResult = frameParser.parse(rawFrame, aesKey);

    expect(frameResult, isA<ContactIdFrame>());
    final frame = frameResult as ContactIdFrame;
    final payload = payloadParser.parse(frame.payloadData);
    final event = eventMapper.map(frame: frame, payload: payload);

    expect(event.eventId, 'evt-130');
    expect(event.accountNumber, '1234');
    expect(event.receiverNumber, '0001');
    expect(event.sequenceNumber, 42);
    expect(event.incidentType, IncidentType.intrusion);
    expect(event.severity, IncidentSeverity.high);
    expect(event.isRestore, isFalse);
    expect(event.isTest, isFalse);
    expect(event.description, contains('Burglary - perimeter'));
    expect(event.receivedAtUtc, DateTime.utc(2026, 4, 7, 12, 30));
  });
}
