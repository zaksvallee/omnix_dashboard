import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/guard/guard_mobile_ops.dart';
import 'package:omnix_dashboard/domain/guard/operational_tiers.dart';

void main() {
  GuardAssignment assignment() {
    return GuardAssignment(
      assignmentId: 'ASSIGN-001',
      dispatchId: 'DISP-001',
      clientId: 'CLIENT-001',
      siteId: 'SITE-SANDTON',
      guardId: 'GUARD-001',
      issuedAt: DateTime.utc(2026, 3, 4, 12),
    );
  }

  test('acknowledging assignment enqueues en-route status update', () async {
    final queue = InMemoryGuardMobileSyncQueue();
    final service = GuardMobileOpsService(
      tierProfile: GuardOperationalTierCatalog.profile(
        GuardOperationalTier.tier1VerifiedOperations,
      ),
      syncQueue: queue,
    );

    final updated = await service.acknowledgeAssignment(
      assignment(),
      acknowledgedAt: DateTime.utc(2026, 3, 4, 12, 1),
    );
    final queued = await queue.peekBatch();

    expect(updated.status, GuardDutyStatus.enRoute);
    expect(updated.acknowledgedAt, DateTime.utc(2026, 3, 4, 12, 1));
    expect(queued, hasLength(1));
    expect(queued.first.type, GuardSyncOperationType.statusUpdate);
    expect(queued.first.payload['status'], GuardDutyStatus.enRoute.name);
  });

  test('recording heartbeat enqueues location operation', () async {
    final queue = InMemoryGuardMobileSyncQueue();
    final service = GuardMobileOpsService(
      tierProfile: GuardOperationalTierCatalog.profile(
        GuardOperationalTier.tier1VerifiedOperations,
      ),
      syncQueue: queue,
    );

    await service.recordLocationHeartbeat(
      GuardLocationHeartbeat(
        guardId: 'GUARD-001',
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        latitude: -26.1076,
        longitude: 28.0567,
        accuracyMeters: 7.5,
        recordedAt: DateTime.utc(2026, 3, 4, 12, 2),
      ),
    );
    final queued = await queue.peekBatch();

    expect(queued, hasLength(1));
    expect(queued.first.type, GuardSyncOperationType.locationHeartbeat);
    expect(queued.first.payload['latitude'], -26.1076);
    expect(queued.first.payload['longitude'], 28.0567);
  });

  test('operation context builder is attached to queued payloads', () async {
    final queue = InMemoryGuardMobileSyncQueue();
    final service = GuardMobileOpsService(
      tierProfile: GuardOperationalTierCatalog.profile(
        GuardOperationalTier.tier1VerifiedOperations,
      ),
      syncQueue: queue,
      operationContextBuilder: () => const {
        'telemetry_adapter_label': 'native_sdk:fsk_sdk',
        'telemetry_facade_id': 'fsk_sdk_facade_live',
        'telemetry_facade_live_mode': true,
        'telemetry_facade_toggle_source': 'build_config',
      },
    );

    await service.triggerPanic(
      GuardPanicSignal(
        signalId: 'PANIC-CONTEXT-1',
        guardId: 'GUARD-001',
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        latitude: -26.1077,
        longitude: 28.0565,
        triggeredAt: DateTime.utc(2026, 3, 4, 12, 5),
      ),
    );
    final queued = await queue.peekBatch();
    expect(queued, hasLength(1));
    final runtimeContext = queued.first.payload['onyx_runtime_context'] as Map;
    expect(runtimeContext['telemetry_adapter_label'], 'native_sdk:fsk_sdk');
    expect(runtimeContext['telemetry_facade_id'], 'fsk_sdk_facade_live');
    expect(runtimeContext['telemetry_facade_live_mode'], isTrue);
    expect(runtimeContext['telemetry_facade_toggle_source'], 'build_config');
  });

  test('checkpoint scan is enqueued for baseline tier', () async {
    final queue = InMemoryGuardMobileSyncQueue();
    final service = GuardMobileOpsService(
      tierProfile: GuardOperationalTierCatalog.profile(
        GuardOperationalTier.tier1VerifiedOperations,
      ),
      syncQueue: queue,
    );

    await service.recordCheckpointScan(
      GuardCheckpointScan(
        scanId: 'SCAN-1',
        guardId: 'GUARD-001',
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        checkpointId: 'CP-01',
        nfcTagId: 'NFC-CP-01',
        latitude: -26.1076,
        longitude: 28.0567,
        scannedAt: DateTime.utc(2026, 3, 4, 12, 3),
      ),
    );
    final queued = await queue.peekBatch();

    expect(queued, hasLength(1));
    expect(queued.first.type, GuardSyncOperationType.checkpointScan);
    expect(queued.first.payload['checkpoint_id'], 'CP-01');
    expect(queued.first.payload['nfc_tag_id'], 'NFC-CP-01');
  });

  test('tier 1 blocks video capture, tier 2 allows it', () async {
    final tier1Queue = InMemoryGuardMobileSyncQueue();
    final tier1Service = GuardMobileOpsService(
      tierProfile: GuardOperationalTierCatalog.profile(
        GuardOperationalTier.tier1VerifiedOperations,
      ),
      syncQueue: tier1Queue,
    );

    final videoCapture = GuardIncidentCapture(
      captureId: 'CAP-1',
      guardId: 'GUARD-001',
      clientId: 'CLIENT-001',
      siteId: 'SITE-SANDTON',
      mediaType: GuardMediaType.video,
      localReference: 'file:///capture/video1.mp4',
      dispatchId: 'DISP-001',
      capturedAt: DateTime.utc(2026, 3, 4, 12, 4),
    );

    await expectLater(
      () => tier1Service.captureIncidentMedia(videoCapture),
      throwsA(isA<StateError>()),
    );
    expect(await tier1Queue.peekBatch(), isEmpty);

    final tier2Queue = InMemoryGuardMobileSyncQueue();
    final tier2Service = GuardMobileOpsService(
      tierProfile: GuardOperationalTierCatalog.profile(
        GuardOperationalTier.tier2EvidenceGuard,
      ),
      syncQueue: tier2Queue,
    );

    await tier2Service.captureIncidentMedia(videoCapture);
    final queued = await tier2Queue.peekBatch();

    expect(queued, hasLength(1));
    expect(queued.first.type, GuardSyncOperationType.incidentCapture);
    expect(queued.first.payload['media_type'], GuardMediaType.video.name);
  });

  test('panic signal is enqueued as high-priority operation type', () async {
    final queue = InMemoryGuardMobileSyncQueue();
    final service = GuardMobileOpsService(
      tierProfile: GuardOperationalTierCatalog.profile(
        GuardOperationalTier.tier1VerifiedOperations,
      ),
      syncQueue: queue,
    );

    await service.triggerPanic(
      GuardPanicSignal(
        signalId: 'PANIC-1',
        guardId: 'GUARD-001',
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        latitude: -26.1077,
        longitude: 28.0565,
        triggeredAt: DateTime.utc(2026, 3, 4, 12, 5),
      ),
    );
    final queued = await queue.peekBatch();

    expect(queued, hasLength(1));
    expect(queued.first.type, GuardSyncOperationType.panicSignal);
    expect(queued.first.payload['signal_id'], 'PANIC-1');
  });

  test('synced operations are removed from in-memory queue', () async {
    final queue = InMemoryGuardMobileSyncQueue();
    final service = GuardMobileOpsService(
      tierProfile: GuardOperationalTierCatalog.profile(
        GuardOperationalTier.tier1VerifiedOperations,
      ),
      syncQueue: queue,
    );

    await service.updateStatus(
      assignment: assignment(),
      status: GuardDutyStatus.onSite,
      occurredAt: DateTime.utc(2026, 3, 4, 12, 6),
    );
    final queued = await queue.peekBatch();
    expect(queued, hasLength(1));

    await queue.markSynced([queued.first.operationId]);
    expect(await queue.peekBatch(), isEmpty);
  });
}
