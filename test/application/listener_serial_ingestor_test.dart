import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/listener_serial_ingestor.dart';

void main() {
  test('tokenized serial line normalizes into listener envelope and intel', () {
    const ingestor = ListenerSerialIngestor();

    final envelope = ingestor.parseLine(
      line: '1130 01 004 1234 0001 2026-03-13T08:15:00Z',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(envelope, isNotNull);
    expect(envelope!.provider, 'falcon_serial');
    expect(envelope.accountNumber, '1234');
    expect(envelope.partition, '01');
    expect(envelope.zone, '004');
    expect(envelope.eventCode, '130');
    expect(envelope.eventQualifier, '1');

    final intel = ingestor.normalizeEnvelope(envelope);
    expect(intel, isNotNull);
    expect(intel!.provider, 'falcon_serial');
    expect(intel.objectLabel, 'BURGLARY_ALARM');
    expect(intel.zone, '004');
    expect(intel.riskScore, 96);
    expect(intel.summary, contains('acct 1234'));
  });

  test('json line round-trips canonical serial envelope', () {
    const ingestor = ListenerSerialIngestor();

    final envelope = ingestor.parseLine(
      line:
          '{"provider":"falcon_serial","transport":"serial","external_id":"falcon-evt-1","account_number":"1234","partition":"01","event_code":"301","event_qualifier":"3","zone":"001","user_code":"0002","site_id":"SITE-SANDTON","client_id":"CLIENT-001","region_id":"REGION-GAUTENG","occurred_at_utc":"2026-03-13T09:00:00Z","metadata":{"source":"bench"}}',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(envelope, isNotNull);
    expect(envelope!.externalId, 'falcon-evt-1');
    expect(envelope.metadata['source'], 'bench');

    final intel = ingestor.normalizeEnvelope(envelope);
    expect(intel, isNotNull);
    expect(intel!.objectLabel, 'OPENING');
    expect(intel.riskScore, 35);
  });

  test('bench parser rejects malformed lines and keeps valid ones', () {
    const ingestor = ListenerSerialIngestor();

    final result = ingestor.parseLines(
      lines: const [
        '1131 01 007 1234 0003 2026-03-13T10:00:00Z',
        'bad',
        '',
      ],
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(result.accepted, hasLength(1));
    expect(result.rejected, hasLength(1));
    expect(result.accepted.single.eventCode, '131');
  });
}
