import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/application/offline_incident_spool_service.dart';

void main() {
  group('OfflineIncidentSpoolService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('enqueue persists a queued incident entry and buffering state', () async {
      final persistence = await DispatchPersistenceService.create();
      final service = OfflineIncidentSpoolService(
        persistence: persistence,
        remote: _RecordingGateway(),
      );

      final entry = await service.enqueue(
        incidentReference: 'INC-001',
        sourceType: 'dvr',
        provider: 'hikvision_dvr',
        clientId: 'CLIENT-1',
        siteId: 'SITE-1',
        summary: 'Offline queue test',
        payload: const {'event_id': 'dvr-1'},
      );

      expect(entry.status, OfflineIncidentSpoolEntryStatus.queued);
      final queued = await service.readPendingEntries();
      expect(queued, hasLength(1));
      expect(queued.single.incidentReference, 'INC-001');

      final state = await service.readSyncState();
      expect(state.statusLabel, 'buffering');
      expect(state.pendingCount, 1);
      expect(state.history.single, contains('Queued INC-001'));
    });

    test('syncPendingEntries marks entries synced on success', () async {
      final persistence = await DispatchPersistenceService.create();
      final gateway = _RecordingGateway();
      final service = OfflineIncidentSpoolService(
        persistence: persistence,
        remote: gateway,
      );

      await service.enqueue(
        incidentReference: 'INC-002',
        sourceType: 'hardware',
        provider: 'frigate',
        clientId: 'CLIENT-1',
        siteId: 'SITE-1',
        summary: 'Sync success',
        payload: const {'event_id': 'intel-2'},
      );

      final result = await service.syncPendingEntries();

      expect(result.syncedCount, 1);
      expect(result.failedCount, 0);
      expect(result.pendingCount, 0);
      expect(gateway.batches, hasLength(1));
      expect(gateway.batches.single.single.incidentReference, 'INC-002');

      final recent = await service.readRecentEntries();
      expect(recent.single.status, OfflineIncidentSpoolEntryStatus.synced);

      final state = await service.readSyncState();
      expect(state.statusLabel, 'synced');
      expect(state.pendingCount, 0);
      expect(state.lastSyncedAtUtc, isNotNull);
    });

    test('syncPendingEntries marks entries failed on remote error', () async {
      final persistence = await DispatchPersistenceService.create();
      final service = OfflineIncidentSpoolService(
        persistence: persistence,
        remote: const _FailingGateway(),
      );

      await service.enqueue(
        incidentReference: 'INC-003',
        sourceType: 'dvr',
        provider: 'hikvision_dvr',
        clientId: 'CLIENT-1',
        siteId: 'SITE-1',
        summary: 'Sync failure',
        payload: const {'event_id': 'dvr-3'},
      );

      final result = await service.syncPendingEntries();

      expect(result.syncedCount, 0);
      expect(result.failedCount, 1);
      expect(result.pendingCount, 1);
      expect(result.failureReason, contains('network_down'));

      final recent = await service.readRecentEntries();
      expect(recent.single.status, OfflineIncidentSpoolEntryStatus.failed);
      expect(recent.single.failureReason, contains('network_down'));

      final state = await service.readSyncState();
      expect(state.statusLabel, 'failed');
      expect(state.failureReason, contains('network_down'));
    });

    test('retryFailedEntries requeues failed entries', () async {
      final persistence = await DispatchPersistenceService.create();
      final service = OfflineIncidentSpoolService(
        persistence: persistence,
        remote: const _FailingGateway(),
      );

      await service.enqueue(
        incidentReference: 'INC-004',
        sourceType: 'hardware',
        provider: 'frigate',
        clientId: 'CLIENT-1',
        siteId: 'SITE-1',
        summary: 'Retry flow',
        payload: const {'event_id': 'intel-4'},
      );
      await service.syncPendingEntries();

      final retried = await service.retryFailedEntries();

      expect(retried, 1);
      final pending = await service.readPendingEntries();
      expect(pending.single.status, OfflineIncidentSpoolEntryStatus.queued);
      expect(pending.single.retryCount, greaterThanOrEqualTo(2));
    });
  });
}

class _RecordingGateway implements OfflineIncidentSpoolRemoteGateway {
  final List<List<OfflineIncidentSpoolEntry>> batches =
      <List<OfflineIncidentSpoolEntry>>[];

  @override
  Future<void> flushEntries(List<OfflineIncidentSpoolEntry> entries) async {
    batches.add(entries);
  }
}

class _FailingGateway implements OfflineIncidentSpoolRemoteGateway {
  const _FailingGateway();

  @override
  Future<void> flushEntries(List<OfflineIncidentSpoolEntry> entries) async {
    throw StateError('network_down');
  }
}
