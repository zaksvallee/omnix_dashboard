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
    expect(envelope.metadata['timestamp_source'], 'embedded_token');
    expect(envelope.metadata['timestamp_token'], '2026-03-13T08:15:00Z');

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
    expect(envelope.metadata['parse_mode'], 'json_line');
    expect(envelope.metadata['timestamp_source'], 'embedded_json');
    expect(envelope.metadata['timestamp_field'], 'occurred_at_utc');
    expect(
      envelope.metadata['capture_signature'],
      'json_line|timestamp=embedded_json|timestamp_field=occurred_at_utc|partition=present|zone=present|user=present|qualifier=present',
    );

    final intel = ingestor.normalizeEnvelope(envelope);
    expect(intel, isNotNull);
    expect(intel!.objectLabel, 'OPENING');
    expect(intel.riskScore, 35);
  });

  test('bench parser rejects malformed lines and keeps valid ones', () {
    const ingestor = ListenerSerialIngestor();

    final result = ingestor.parseLines(
      lines: const [
        '# comment',
        '1131 01 007 1234 0003 2026-03-13T10:00:00Z',
        'bad',
        '{"provider":"falcon_serial","account_number":"1234"}',
        '',
      ],
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(result.accepted, hasLength(1));
    expect(result.rejectedEntries, hasLength(2));
    expect(result.rejected, hasLength(2));
    expect(result.accepted.single.eventCode, '131');
    expect(result.rejectedEntries.first.reason, 'insufficient_tokens');
    expect(result.rejectedEntries.last.reason, 'json_missing_timestamp');
    expect(result.rejectReasonCounts['insufficient_tokens'], 1);
    expect(result.rejectReasonCounts['json_missing_timestamp'], 1);
    expect(result.timestampSourceCounts['embedded_token'], 1);
    expect(result.parseModeCounts['tokenized'], 1);
    expect(result.eventCodeCounts['131'], 1);
    expect(result.qualifierCounts['1'], 1);
    expect(
      result.captureSignatureCounts[
          'tokenized|tokens=6|timestamp=embedded_token|partition=present|zone=present|user=present|qualifier=present'],
      1,
    );
  });

  test('parseLineDetailed classifies tokenized numeric validation failures', () {
    const ingestor = ListenerSerialIngestor();

    final invalidZone = ingestor.parseLineDetailed(
      line: '1130 01 ZONE 1234 0001 2026-03-13T08:15:00Z',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );
    final invalidAccount = ingestor.parseLineDetailed(
      line: '1130 01 004 acct 0001 2026-03-13T08:15:00Z',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(invalidZone.envelope, isNull);
    expect(invalidZone.rejectReason, 'invalid_zone');
    expect(invalidAccount.envelope, isNull);
    expect(invalidAccount.rejectReason, 'invalid_account_number');
  });

  test('parseLineDetailed classifies JSON numeric validation failures', () {
    const ingestor = ListenerSerialIngestor();

    final result = ingestor.parseLineDetailed(
      line:
          '{"provider":"falcon_serial","transport":"serial","account_number":"acct","event_code":"130","occurred_at_utc":"2026-03-13T09:00:00Z"}',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(result.envelope, isNull);
    expect(result.rejectReason, 'json_invalid_numeric_fields');
  });

  test('parseLineDetailed classifies JSON qualifier validation failures', () {
    const ingestor = ListenerSerialIngestor();

    final result = ingestor.parseLineDetailed(
      line:
          '{"provider":"falcon_serial","transport":"serial","account_number":"1234","event_code":"130","event_qualifier":"A","occurred_at_utc":"2026-03-13T09:00:00Z"}',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(result.envelope, isNull);
    expect(result.rejectReason, 'json_invalid_qualifier');
  });

  test('tokenized line without timestamp records fallback timestamp source', () {
    const ingestor = ListenerSerialIngestor();

    final envelope = ingestor.parseLine(
      line: '1130 01 004 1234 0001',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(envelope, isNotNull);
    expect(envelope!.metadata['timestamp_source'], 'fallback_now');
    expect(envelope.metadata.containsKey('timestamp_token'), isFalse);
  });

  test('unknown event code is preserved with normalization warning', () {
    const ingestor = ListenerSerialIngestor();

    final envelope = ingestor.parseLine(
      line: '1999 01 004 1234 0001 2026-03-13T08:15:00Z',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(envelope, isNotNull);
    expect(envelope!.metadata['normalized_event_label'], 'LISTENER_EVENT');
    expect(envelope.metadata['normalization_status'], 'warning');
    expect(envelope.metadata['normalization_warning'], 'unknown_event_code');
    expect(
      envelope.metadata['normalization_warnings'],
      ['unknown_event_code'],
    );

    final intel = ingestor.normalizeEnvelope(envelope);
    expect(intel, isNotNull);
    expect(intel!.objectLabel, 'LISTENER_EVENT');
    expect(intel.riskScore, 55);
  });

  test('nonstandard qualifier is preserved with qualifier warning', () {
    const ingestor = ListenerSerialIngestor();

    final envelope = ingestor.parseLine(
      line: '9130 01 004 1234 0001 2026-03-13T08:15:00Z',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(envelope, isNotNull);
    expect(envelope!.metadata['normalized_event_label'], 'BURGLARY_ALARM');
    expect(envelope.metadata['normalization_status'], 'warning');
    expect(
      envelope.metadata['normalization_warning'],
      'nonstandard_event_qualifier',
    );
    expect(
      envelope.metadata['normalization_warnings'],
      ['nonstandard_event_qualifier'],
    );

    final intel = ingestor.normalizeEnvelope(envelope);
    expect(intel, isNotNull);
    expect(intel!.objectLabel, 'BURGLARY_ALARM');
    expect(intel.riskScore, 96);
  });

  test('bench parser aggregates warning and profile counts', () {
    const ingestor = ListenerSerialIngestor();

    final result = ingestor.parseLines(
      lines: const [
        '9130 01 004 1234 0001 2026-03-13T08:15:00Z',
        '1130 01 004 1234 0001',
        '{"provider":"falcon_serial","transport":"serial","account_number":"1234","event_code":"999","event_qualifier":"3","occurred_at_utc":"2026-03-13T09:00:00Z"}',
      ],
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(result.accepted, hasLength(3));
    expect(result.warningCounts['nonstandard_event_qualifier'], 1);
    expect(result.warningCounts['unknown_event_code'], 1);
    expect(result.timestampSourceCounts['embedded_token'], 1);
    expect(result.timestampSourceCounts['fallback_now'], 1);
    expect(result.timestampSourceCounts['embedded_json'], 1);
    expect(result.eventCodeCounts['130'], 2);
    expect(result.eventCodeCounts['999'], 1);
    expect(result.qualifierCounts['9'], 1);
    expect(result.qualifierCounts['1'], 1);
    expect(result.qualifierCounts['3'], 1);
    expect(result.parseModeCounts['tokenized'], 2);
    expect(result.parseModeCounts['json_line'], 1);
    expect(
      result.captureSignatureCounts[
          'tokenized|tokens=6|timestamp=embedded_token|partition=present|zone=present|user=present|qualifier=present'],
      1,
    );
    expect(
      result.captureSignatureCounts[
          'tokenized|tokens=5|timestamp=fallback_now|partition=present|zone=present|user=present|qualifier=present'],
      1,
    );
    expect(
      result.captureSignatureCounts[
          'json_line|timestamp=embedded_json|timestamp_field=occurred_at_utc|partition=absent|zone=absent|user=absent|qualifier=present'],
      1,
    );
  });
}
