import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/alarms/contact_id_event.dart';
import 'package:omnix_dashboard/infrastructure/alarm/contact_id_payload_parser.dart';

void main() {
  const parser = ContactIdPayloadParser();

  test('ContactIdPayloadParser parses qualifier code 1 as new event', () {
    final payload = parser.parse('123418113001003');

    expect(payload.accountNumber, '1234');
    expect(payload.qualifier, ContactIdQualifier.newEvent);
    expect(payload.eventCode, 130);
    expect(payload.partition, 1);
    expect(payload.zone, 3);
  });

  test('ContactIdPayloadParser parses qualifier code 3 as restore', () {
    final payload = parser.parse('123418313001003');

    expect(payload.qualifier, ContactIdQualifier.restore);
  });

  test('ContactIdPayloadParser parses qualifier code 6 as status', () {
    final payload = parser.parse('123418632100000');

    expect(payload.qualifier, ContactIdQualifier.status);
    expect(payload.zone, 0);
    expect(payload.eventCode, 321);
  });

  test('ContactIdPayloadParser preserves zone 000 as zero', () {
    final payload = parser.parse('123418601000000');

    expect(payload.zone, 0);
    expect(payload.partition, 0);
  });

  test('ContactIdPayloadParser rejects malformed payloads', () {
    expect(
      () => parser.parse('1234BAD'),
      throwsA(isA<ContactIdParseException>()),
    );
  });
}
