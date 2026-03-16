import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/listener_alarm_advisory_resolution_service.dart';
import 'package:omnix_dashboard/application/listener_alarm_partner_advisory_service.dart';
import 'package:omnix_dashboard/application/listener_alarm_scope_mapping_service.dart';
import 'package:omnix_dashboard/application/listener_serial_ingestor.dart';

void main() {
  const service = ListenerAlarmAdvisoryResolutionService();

  ListenerSerialEnvelope buildEnvelope({
    String accountNumber = '1234',
    String partition = '01',
    String zone = '004',
  }) {
    return ListenerSerialEnvelope(
      provider: 'falcon_serial',
      transport: 'serial',
      externalId: 'evt-1',
      rawLine: '1130 01 004 1234 0001 2026-03-16T00:00:00Z',
      accountNumber: accountNumber,
      partition: partition,
      eventCode: '130',
      eventQualifier: '1',
      zone: zone,
      userCode: '0001',
      siteId: 'SITE-RAW',
      clientId: 'CLIENT-RAW',
      regionId: 'REGION-RAW',
      occurredAtUtc: DateTime.utc(2026, 3, 16),
      metadata: const {
        'normalized_event_label': 'BURGLARY_ALARM',
      },
    );
  }

  const entries = [
    ListenerAlarmScopeMappingEntry(
      accountNumber: '1234',
      partition: '01',
      zone: '004',
      zoneLabel: 'Front Gate',
      siteId: 'SITE-VALLEE',
      siteName: 'Vallee Residence',
      clientId: 'CLIENT-VALLEE',
      clientName: 'Vision Tactical',
      regionId: 'REGION-GAUTENG',
    ),
  ];

  test('builds resolved partner advisory from mapped alarm scope', () {
    final resolution = service.resolvePartnerAdvisory(
      envelope: buildEnvelope(),
      scopeEntries: entries,
      disposition: ListenerAlarmAdvisoryDisposition.suspicious,
      cctvSummary: 'Human movement confirmed near front gate',
    );

    expect(resolution, isNotNull);
    expect(resolution!.envelope.siteId, 'SITE-VALLEE');
    expect(resolution.envelope.clientId, 'CLIENT-VALLEE');
    expect(resolution.eventLabel, 'BURGLARY_ALARM');
    expect(resolution.scope.resolvedZoneLabel, 'Front Gate');
    expect(
      resolution.advisoryMessage,
      'Signal received from Vallee Residence (Front Gate) for burglary alarm. CCTV checked immediately. Human movement confirmed near front gate. Escalation recommended.',
    );
  });

  test('returns null when alarm scope cannot be resolved', () {
    final resolution = service.resolvePartnerAdvisory(
      envelope: buildEnvelope(accountNumber: '9999'),
      scopeEntries: entries,
      disposition: ListenerAlarmAdvisoryDisposition.clear,
      cctvSummary: 'Nothing suspicious to report',
    );

    expect(resolution, isNull);
  });

  test('falls back to event code mapping when metadata label is absent', () {
    final resolution = service.resolvePartnerAdvisory(
      envelope: buildEnvelope().copyWith(
        eventCode: '131',
        metadata: const {},
      ),
      scopeEntries: entries,
      disposition: ListenerAlarmAdvisoryDisposition.clear,
      cctvSummary: 'Nothing suspicious to report',
    );

    expect(resolution, isNotNull);
    expect(resolution!.eventLabel, 'PERIMETER_ALARM');
    expect(
      resolution.advisoryMessage,
      contains('for perimeter alarm.'),
    );
  });
}
