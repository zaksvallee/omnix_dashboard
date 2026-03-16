import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/listener_alarm_scope_mapping_service.dart';
import 'package:omnix_dashboard/application/listener_alarm_scope_registry_repository.dart';

void main() {
  ListenerAlarmScopeMappingEntry buildEntry({
    String accountNumber = '1234',
    String partition = '',
    String zone = '',
    String siteId = 'SITE-VALLEE',
    String siteName = 'Vallee Residence',
    String clientId = 'CLIENT-VISION',
    String clientName = 'Vision Tactical',
    String regionId = 'REGION-GAUTENG',
    String zoneLabel = '',
  }) {
    return ListenerAlarmScopeMappingEntry(
      accountNumber: accountNumber,
      partition: partition,
      zone: zone,
      zoneLabel: zoneLabel,
      siteId: siteId,
      siteName: siteName,
      clientId: clientId,
      clientName: clientName,
      regionId: regionId,
    );
  }

  test('upsert replaces existing binding with same account partition and zone', () {
    final repository = ListenerAlarmScopeRegistryRepository(
      seedEntries: [
        buildEntry(partition: '01', zone: '004', zoneLabel: 'Front Gate'),
      ],
    );

    repository.upsert(
      buildEntry(
        partition: '01',
        zone: '004',
        zoneLabel: 'Main Gate',
        siteName: 'Vallee Main Residence',
      ),
    );

    final entries = repository.allEntries();
    expect(entries, hasLength(1));
    expect(entries.single.zoneLabel, 'Main Gate');
    expect(entries.single.siteName, 'Vallee Main Residence');
  });

  test('entriesForAccount returns all bindings for the account', () {
    final repository = ListenerAlarmScopeRegistryRepository(
      seedEntries: [
        buildEntry(accountNumber: '1234'),
        buildEntry(accountNumber: '1234', partition: '01', zone: '004'),
        buildEntry(accountNumber: '9999'),
      ],
    );

    final entries = repository.entriesForAccount('1234');

    expect(entries, hasLength(2));
    expect(entries.every((entry) => entry.accountNumber == '1234'), isTrue);
  });

  test('remove deletes exact binding key only', () {
    final repository = ListenerAlarmScopeRegistryRepository(
      seedEntries: [
        buildEntry(accountNumber: '1234'),
        buildEntry(accountNumber: '1234', partition: '01', zone: '004'),
      ],
    );

    final removed = repository.remove(
      accountNumber: '1234',
      partition: '01',
      zone: '004',
    );

    expect(removed, isTrue);
    expect(repository.allEntries(), hasLength(1));
    expect(repository.allEntries().single.partition, isEmpty);
  });

  test('export and import round-trip registry bindings', () {
    final repository = ListenerAlarmScopeRegistryRepository(
      seedEntries: [
        buildEntry(partition: '01', zone: '004', zoneLabel: 'Front Gate'),
        buildEntry(accountNumber: '5678', siteName: 'Oaklands Office'),
      ],
    );

    final exported = repository.exportJson();
    final restored = ListenerAlarmScopeRegistryRepository();
    restored.importJson(exported);

    expect(restored.allEntries(), hasLength(2));
    expect(restored.allEntries().first.zoneLabel, 'Front Gate');
    expect(restored.allEntries().last.siteName, 'Oaklands Office');
  });

  test('importJson rejects non-list payloads', () {
    final repository = ListenerAlarmScopeRegistryRepository();

    expect(
      () => repository.importJson('{"account_number":"1234"}'),
      throwsFormatException,
    );
  });
}
