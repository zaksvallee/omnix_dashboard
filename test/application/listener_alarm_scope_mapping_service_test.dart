import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/listener_alarm_scope_mapping_service.dart';
import 'package:omnix_dashboard/application/listener_serial_ingestor.dart';

void main() {
  const service = ListenerAlarmScopeMappingService();

  ListenerSerialEnvelope buildEnvelope({
    String accountNumber = '1234',
    String partition = '01',
    String zone = '004',
    String siteId = 'SITE-RAW',
    String clientId = 'CLIENT-RAW',
    String regionId = 'REGION-RAW',
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
      siteId: siteId,
      clientId: clientId,
      regionId: regionId,
      occurredAtUtc: DateTime.utc(2026, 3, 16),
      metadata: const {'source': 'test'},
    );
  }

  test('resolves exact account partition and zone match first', () {
    final resolution = service.resolve(
      envelope: buildEnvelope(),
      entries: const [
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
        ListenerAlarmScopeMappingEntry(
          accountNumber: '1234',
          partition: '01',
          siteId: 'SITE-FALLBACK',
          siteName: 'Fallback Residence',
          clientId: 'CLIENT-FALLBACK',
          clientName: 'Fallback Tactical',
          regionId: 'REGION-GAUTENG',
        ),
      ],
    );

    expect(resolution, isNotNull);
    expect(
      resolution!.matchMode,
      ListenerAlarmScopeMatchMode.accountPartitionZone,
    );
    expect(resolution.entry.siteId, 'SITE-VALLEE');
    expect(resolution.resolvedZoneLabel, 'Front Gate');

    final remapped = resolution.remappedEnvelope();
    expect(remapped.siteId, 'SITE-VALLEE');
    expect(remapped.clientId, 'CLIENT-VALLEE');
    expect(remapped.regionId, 'REGION-GAUTENG');
    expect(remapped.metadata['alarm_scope_match_mode'], 'accountPartitionZone');
    expect(remapped.metadata['alarm_scope_zone_label'], 'Front Gate');
    expect(remapped.metadata['source'], 'test');
  });

  test('falls back to account partition then account zone then account only', () {
    final partitionResolution = service.resolve(
      envelope: buildEnvelope(zone: '999'),
      entries: const [
        ListenerAlarmScopeMappingEntry(
          accountNumber: '1234',
          partition: '01',
          siteId: 'SITE-PARTITION',
          siteName: 'Partition Site',
          clientId: 'CLIENT-PARTITION',
          clientName: 'Partition Tactical',
          regionId: 'REGION-GAUTENG',
        ),
        ListenerAlarmScopeMappingEntry(
          accountNumber: '1234',
          siteId: 'SITE-ACCOUNT',
          siteName: 'Account Site',
          clientId: 'CLIENT-ACCOUNT',
          clientName: 'Account Tactical',
          regionId: 'REGION-GAUTENG',
        ),
      ],
    );
    expect(
      partitionResolution!.matchMode,
      ListenerAlarmScopeMatchMode.accountPartition,
    );
    expect(partitionResolution.entry.siteId, 'SITE-PARTITION');

    final zoneResolution = service.resolve(
      envelope: buildEnvelope(partition: '09', zone: '004'),
      entries: const [
        ListenerAlarmScopeMappingEntry(
          accountNumber: '1234',
          zone: '004',
          zoneLabel: 'Perimeter',
          siteId: 'SITE-ZONE',
          siteName: 'Zone Site',
          clientId: 'CLIENT-ZONE',
          clientName: 'Zone Tactical',
          regionId: 'REGION-GAUTENG',
        ),
      ],
    );
    expect(
      zoneResolution!.matchMode,
      ListenerAlarmScopeMatchMode.accountZone,
    );
    expect(zoneResolution.entry.siteId, 'SITE-ZONE');

    final accountResolution = service.resolve(
      envelope: buildEnvelope(partition: '09', zone: '888'),
      entries: const [
        ListenerAlarmScopeMappingEntry(
          accountNumber: '1234',
          siteId: 'SITE-ACCOUNT',
          siteName: 'Account Site',
          clientId: 'CLIENT-ACCOUNT',
          clientName: 'Account Tactical',
          regionId: 'REGION-GAUTENG',
        ),
      ],
    );
    expect(
      accountResolution!.matchMode,
      ListenerAlarmScopeMatchMode.accountOnly,
    );
    expect(accountResolution.entry.siteId, 'SITE-ACCOUNT');
  });

  test('returns null when no scope entry matches account number', () {
    final resolution = service.resolve(
      envelope: buildEnvelope(accountNumber: '9999'),
      entries: const [
        ListenerAlarmScopeMappingEntry(
          accountNumber: '1234',
          siteId: 'SITE-VALLEE',
          siteName: 'Vallee Residence',
          clientId: 'CLIENT-VALLEE',
          clientName: 'Vision Tactical',
          regionId: 'REGION-GAUTENG',
        ),
      ],
    );

    expect(resolution, isNull);
  });

  test('mapping entries round-trip through json', () {
    const entry = ListenerAlarmScopeMappingEntry(
      accountNumber: '1234',
      partition: '01',
      zone: '004',
      zoneLabel: 'Front Gate',
      siteId: 'SITE-VALLEE',
      siteName: 'Vallee Residence',
      clientId: 'CLIENT-VALLEE',
      clientName: 'Vision Tactical',
      regionId: 'REGION-GAUTENG',
    );

    final decoded = ListenerAlarmScopeMappingEntry.fromJson(entry.toJson());

    expect(decoded.accountNumber, '1234');
    expect(decoded.partition, '01');
    expect(decoded.zone, '004');
    expect(decoded.zoneLabel, 'Front Gate');
    expect(decoded.siteName, 'Vallee Residence');
    expect(decoded.clientName, 'Vision Tactical');
  });
}
