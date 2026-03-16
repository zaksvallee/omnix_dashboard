import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/listener_alarm_advisory_pipeline_service.dart';
import 'package:omnix_dashboard/application/listener_alarm_partner_advisory_service.dart';
import 'package:omnix_dashboard/application/listener_alarm_scope_mapping_service.dart';
import 'package:omnix_dashboard/application/listener_alarm_scope_registry_repository.dart';
import 'package:omnix_dashboard/application/listener_serial_ingestor.dart';

void main() {
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
      metadata: const {'normalized_event_label': 'BURGLARY_ALARM'},
    );
  }

  ListenerAlarmScopeRegistryRepository buildRegistry() {
    return ListenerAlarmScopeRegistryRepository(
      seedEntries: const [
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
      ],
    );
  }

  test('process resolves advisory and normalized intel from registry scope', () {
    final service = ListenerAlarmAdvisoryPipelineService(
      registryRepository: buildRegistry(),
    );

    final result = service.process(
      envelope: buildEnvelope(),
      disposition: ListenerAlarmAdvisoryDisposition.clear,
      cctvSummary: 'Nothing suspicious to report',
    );

    expect(result, isNotNull);
    expect(result!.siteProfile.siteName, 'Vallee Residence');
    expect(result.resolution.envelope.siteId, 'SITE-VALLEE');
    expect(result.resolution.advisoryMessage, contains('Vallee Residence'));
    expect(result.normalizedIntel, isNotNull);
    expect(result.normalizedIntel!.siteId, 'SITE-VALLEE');
    expect(result.normalizedIntel!.clientId, 'CLIENT-VALLEE');
    expect(result.normalizedIntel!.objectLabel, 'BURGLARY_ALARM');
  });

  test('process returns null when registry cannot resolve alarm scope', () {
    final service = ListenerAlarmAdvisoryPipelineService(
      registryRepository: ListenerAlarmScopeRegistryRepository(),
    );

    final result = service.process(
      envelope: buildEnvelope(accountNumber: '9999'),
      disposition: ListenerAlarmAdvisoryDisposition.pending,
    );

    expect(result, isNull);
  });
}
