import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omnix_dashboard/application/guard_ops_repository.dart';
import 'package:omnix_dashboard/domain/guard/guard_ops_event.dart';

void main() {
  group('SharedPrefsGuardOpsRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'enqueues append-only events with deterministic per-shift sequence',
      () async {
        final repository = await SharedPrefsGuardOpsRepository.create(
          remote: _FakeGuardOpsRemoteGateway(),
        );

        final first = await repository.enqueueEvent(
          guardId: 'GUARD-001',
          siteId: 'SITE-SANDTON',
          shiftId: 'SHIFT-20260304-1',
          eventType: GuardOpsEventType.shiftStart,
          deviceId: 'DEVICE-1',
          appVersion: '1.0.0',
          payload: const {'source': 'test'},
        );
        final second = await repository.enqueueEvent(
          guardId: 'GUARD-001',
          siteId: 'SITE-SANDTON',
          shiftId: 'SHIFT-20260304-1',
          eventType: GuardOpsEventType.statusChanged,
          deviceId: 'DEVICE-1',
          appVersion: '1.0.0',
          payload: const {'status': 'enRoute'},
        );
        final third = await repository.enqueueEvent(
          guardId: 'GUARD-001',
          siteId: 'SITE-SANDTON',
          shiftId: 'SHIFT-20260304-2',
          eventType: GuardOpsEventType.shiftStart,
          deviceId: 'DEVICE-1',
          appVersion: '1.0.0',
          payload: const {'source': 'test'},
        );

        expect(first.sequence, 1);
        expect(second.sequence, 2);
        expect(third.sequence, 1);

        final pending = await repository.pendingEvents();
        expect(pending, hasLength(3));
        expect(pending.first.shiftId, 'SHIFT-20260304-1');
        expect(pending.first.sequence, 1);
        expect(pending[1].sequence, 2);
        expect(pending[2].shiftId, 'SHIFT-20260304-2');
        expect(pending[2].sequence, 1);
      },
    );

    test(
      'critical event flow gate covers enqueue, sync, and idempotency across event matrix',
      () async {
        final gateway = _FakeGuardOpsRemoteGateway();
        final repository = await SharedPrefsGuardOpsRepository.create(
          remote: gateway,
        );

        const shiftId = 'SHIFT-FLOW-GATE-1';
        final recordedEvents = <GuardOpsEvent>[];
        final matrixTypes = GuardOpsEventType.values;

        for (var i = 0; i < matrixTypes.length; i += 1) {
          final type = matrixTypes[i];
          final event = await repository.enqueueEvent(
            guardId: 'GUARD-001',
            siteId: 'SITE-SANDTON',
            shiftId: shiftId,
            eventType: type,
            deviceId: 'DEVICE-1',
            appVersion: '1.0.0',
            payload: {
              'flow_gate': true,
              'event_type': type.name,
              'matrix_index': i + 1,
            },
          );
          recordedEvents.add(event);
          expect(event.sequence, i + 1);
          expect(event.eventType, type);
        }

        final pendingBeforeSync = await repository.pendingEvents();
        expect(pendingBeforeSync, hasLength(matrixTypes.length));
        for (var i = 0; i < matrixTypes.length; i += 1) {
          expect(pendingBeforeSync[i].eventType, matrixTypes[i]);
          expect(pendingBeforeSync[i].sequence, i + 1);
          expect(pendingBeforeSync[i].payload['flow_gate'], isTrue);
        }
        expect(
          await repository.shiftSequenceWatermark(shiftId),
          matrixTypes.length,
        );

        var totalSynced = 0;
        GuardOpsSyncResult lastResult = const GuardOpsSyncResult(
          syncedCount: 0,
          failedCount: 0,
          pendingCount: 0,
        );
        for (var i = 0; i < 8; i += 1) {
          lastResult = await repository.syncPendingEvents(batchSize: 7);
          totalSynced += lastResult.syncedCount;
          if (lastResult.pendingCount == 0) {
            break;
          }
        }

        expect(totalSynced, matrixTypes.length);
        expect(lastResult.failedCount, 0);
        expect(lastResult.pendingCount, 0);
        expect(await repository.pendingEvents(), isEmpty);

        expect(gateway.syncedEvents, hasLength(matrixTypes.length));
        final syncedIds = gateway.syncedEvents
            .map((event) => event.eventId)
            .toSet();
        expect(syncedIds, hasLength(matrixTypes.length));
        expect(
          syncedIds,
          equals(recordedEvents.map((event) => event.eventId).toSet()),
        );

        final idempotent = await repository.syncPendingEvents();
        expect(idempotent.syncedCount, 0);
        expect(idempotent.failedCount, 0);
        expect(idempotent.pendingCount, 0);
      },
    );

    test(
      'syncPendingEvents marks events synced when remote succeeds',
      () async {
        final gateway = _FakeGuardOpsRemoteGateway();
        final repository = await SharedPrefsGuardOpsRepository.create(
          remote: gateway,
        );

        await repository.enqueueEvent(
          guardId: 'GUARD-001',
          siteId: 'SITE-SANDTON',
          shiftId: 'SHIFT-1',
          eventType: GuardOpsEventType.dispatchAcknowledged,
          deviceId: 'DEVICE-1',
          appVersion: '1.0.0',
          payload: const {'dispatch_id': 'DISP-1'},
        );

        final result = await repository.syncPendingEvents();

        expect(result.syncedCount, 1);
        expect(result.failedCount, 0);
        expect(result.pendingCount, 0);
        expect(gateway.syncedEvents, hasLength(1));
        expect(await repository.pendingEvents(), isEmpty);
      },
    );

    test(
      'syncPendingEvents increments retry and keeps pending on failure',
      () async {
        final gateway = _FakeGuardOpsRemoteGateway(throwOnEventSync: true);
        final repository = await SharedPrefsGuardOpsRepository.create(
          remote: gateway,
        );

        await repository.enqueueEvent(
          guardId: 'GUARD-001',
          siteId: 'SITE-SANDTON',
          shiftId: 'SHIFT-1',
          eventType: GuardOpsEventType.panicTriggered,
          deviceId: 'DEVICE-1',
          appVersion: '1.0.0',
          payload: const {'reason': 'unit test'},
        );

        final result = await repository.syncPendingEvents();

        expect(result.syncedCount, 0);
        expect(result.failedCount, 1);
        final pending = await repository.pendingEvents();
        expect(pending, hasLength(1));
        expect(pending.single.retryCount, 1);
        expect(pending.single.failureReason, contains('event sync failed'));
      },
    );

    test('syncPendingEvents does not resend already-synced events', () async {
      final gateway = _FakeGuardOpsRemoteGateway();
      final repository = await SharedPrefsGuardOpsRepository.create(
        remote: gateway,
      );

      await repository.enqueueEvent(
        guardId: 'GUARD-001',
        siteId: 'SITE-SANDTON',
        shiftId: 'SHIFT-1',
        eventType: GuardOpsEventType.statusChanged,
        deviceId: 'DEVICE-1',
        appVersion: '1.0.0',
        payload: const {'status': 'onSite'},
      );

      final first = await repository.syncPendingEvents();
      final second = await repository.syncPendingEvents();

      expect(first.syncedCount, 1);
      expect(second.syncedCount, 0);
      expect(gateway.syncedEvents, hasLength(1));
    });

    test('syncPendingEvents succeeds after remote recovery', () async {
      final gateway = _FakeGuardOpsRemoteGateway(throwOnEventSync: true);
      final repository = await SharedPrefsGuardOpsRepository.create(
        remote: gateway,
      );

      await repository.enqueueEvent(
        guardId: 'GUARD-001',
        siteId: 'SITE-SANDTON',
        shiftId: 'SHIFT-1',
        eventType: GuardOpsEventType.panicTriggered,
        deviceId: 'DEVICE-1',
        appVersion: '1.0.0',
        payload: const {'reason': 'reconnect'},
      );

      final failed = await repository.syncPendingEvents();
      expect(failed.failedCount, 1);

      gateway.throwOnEventSync = false;
      final recovered = await repository.syncPendingEvents();

      expect(recovered.syncedCount, 1);
      expect(recovered.failedCount, 0);
      expect(await repository.pendingEvents(), isEmpty);
      expect(gateway.syncedEvents, hasLength(1));
    });

    test(
      'airplane-mode flow syncs queued events and media after reconnect without duplicates',
      () async {
        final gateway = _FakeGuardOpsRemoteGateway(
          throwOnEventSync: true,
          throwOnMediaUpload: true,
        );
        final repository = await SharedPrefsGuardOpsRepository.create(
          remote: gateway,
        );

        final event = await repository.enqueueEvent(
          guardId: 'GUARD-001',
          siteId: 'SITE-SANDTON',
          shiftId: 'SHIFT-AIRPLANE-1',
          eventType: GuardOpsEventType.checkpointScanned,
          deviceId: 'DEVICE-1',
          appVersion: '1.0.0',
          payload: const {'checkpoint_id': 'GATE-A'},
        );
        await repository.enqueueMedia(
          GuardOpsMediaUpload(
            mediaId: 'MEDIA-AIRPLANE-1',
            eventId: event.eventId,
            guardId: event.guardId,
            siteId: event.siteId,
            shiftId: event.shiftId,
            bucket: 'guard-patrol-images',
            path: 'guard/GUARD-001/airplane-1.jpg',
            localPath: '/tmp/airplane-1.jpg',
            capturedAt: DateTime.utc(2026, 3, 5, 6, 30),
          ),
        );

        final failedEvents = await repository.syncPendingEvents();
        final failedMedia = await repository.uploadPendingMedia();
        expect(failedEvents.failedCount, 1);
        expect(failedMedia.failedCount, 1);
        expect(await repository.pendingEvents(), hasLength(1));
        expect(await repository.pendingMedia(), isEmpty);
        expect(await repository.failedMedia(), hasLength(1));

        gateway.throwOnEventSync = false;
        gateway.throwOnMediaUpload = false;
        final retriedMediaCount = await repository.retryFailedMedia();
        expect(retriedMediaCount, 1);

        final recoveredEvents = await repository.syncPendingEvents();
        final recoveredMedia = await repository.uploadPendingMedia();
        expect(recoveredEvents.syncedCount, 1);
        expect(recoveredMedia.syncedCount, 1);
        expect(await repository.pendingEvents(), isEmpty);
        expect(await repository.pendingMedia(), isEmpty);

        final idempotentEvents = await repository.syncPendingEvents();
        final idempotentMedia = await repository.uploadPendingMedia();
        expect(idempotentEvents.syncedCount, 0);
        expect(idempotentMedia.syncedCount, 0);
        expect(gateway.syncedEvents, hasLength(1));
        expect(gateway.uploadedMedia, hasLength(1));
      },
    );

    test(
      'uploadPendingMedia marks uploads complete when remote succeeds',
      () async {
        final gateway = _FakeGuardOpsRemoteGateway();
        final repository = await SharedPrefsGuardOpsRepository.create(
          remote: gateway,
        );

        await repository.enqueueMedia(
          GuardOpsMediaUpload(
            mediaId: 'MEDIA-1',
            eventId: 'EVENT-1',
            guardId: 'GUARD-001',
            siteId: 'SITE-SANDTON',
            shiftId: 'SHIFT-1',
            bucket: 'guard-patrol-images',
            path: 'guard/GUARD-001/media-1.jpg',
            localPath: '/tmp/media-1.jpg',
            capturedAt: DateTime.utc(2026, 3, 4, 11, 0),
            visualNorm: const GuardVisualNormMetadata(
              mode: GuardVisualNormMode.night,
              baselineId: 'NORM-PATROL-GATE-A-V1',
              captureProfile: 'patrol_verification',
              minMatchScore: 86,
              irRequired: false,
              combatWindow: true,
            ),
          ),
        );

        final result = await repository.uploadPendingMedia();

        expect(result.syncedCount, 1);
        expect(result.failedCount, 0);
        expect(result.pendingCount, 0);
        expect(gateway.uploadedMedia, hasLength(1));
        expect(
          gateway.uploadedMedia.single.visualNorm.mode,
          GuardVisualNormMode.night,
        );
        expect(await repository.pendingMedia(), isEmpty);
      },
    );

    test(
      'uploadPendingMedia returns failed result when remote upload fails',
      () async {
        final gateway = _FakeGuardOpsRemoteGateway(throwOnMediaUpload: true);
        final repository = await SharedPrefsGuardOpsRepository.create(
          remote: gateway,
        );

        await repository.enqueueMedia(
          GuardOpsMediaUpload(
            mediaId: 'MEDIA-FAIL-1',
            eventId: 'EVENT-FAIL-1',
            guardId: 'GUARD-001',
            siteId: 'SITE-SANDTON',
            shiftId: 'SHIFT-1',
            bucket: 'guard-patrol-images',
            path: 'guard/GUARD-001/media-fail-1.jpg',
            localPath: '/tmp/media-fail-1.jpg',
            capturedAt: DateTime.utc(2026, 3, 4, 11, 5),
          ),
        );

        final result = await repository.uploadPendingMedia();

        expect(result.syncedCount, 0);
        expect(result.failedCount, 1);
        expect(result.failureReason, contains('media upload failed'));
      },
    );

    test('uploadPendingMedia does not reupload already-synced media', () async {
      final gateway = _FakeGuardOpsRemoteGateway();
      final repository = await SharedPrefsGuardOpsRepository.create(
        remote: gateway,
      );

      await repository.enqueueMedia(
        GuardOpsMediaUpload(
          mediaId: 'MEDIA-IDEMPOTENT-1',
          eventId: 'EVENT-IDEMPOTENT-1',
          guardId: 'GUARD-001',
          siteId: 'SITE-SANDTON',
          shiftId: 'SHIFT-1',
          bucket: 'guard-patrol-images',
          path: 'guard/GUARD-001/media-idempotent-1.jpg',
          localPath: '/tmp/media-idempotent-1.jpg',
          capturedAt: DateTime.utc(2026, 3, 4, 11, 7),
        ),
      );

      final first = await repository.uploadPendingMedia();
      final second = await repository.uploadPendingMedia();

      expect(first.syncedCount, 1);
      expect(second.syncedCount, 0);
      expect(gateway.uploadedMedia, hasLength(1));
    });

    test('retry helpers requeue failed records', () async {
      final gateway = _FakeGuardOpsRemoteGateway(
        throwOnEventSync: true,
        throwOnMediaUpload: true,
      );
      final repository = await SharedPrefsGuardOpsRepository.create(
        remote: gateway,
      );

      await repository.enqueueEvent(
        guardId: 'GUARD-001',
        siteId: 'SITE-SANDTON',
        shiftId: 'SHIFT-1',
        eventType: GuardOpsEventType.panicTriggered,
        deviceId: 'DEVICE-1',
        appVersion: '1.0.0',
        payload: const {'reason': 'retry-test'},
      );
      await repository.enqueueMedia(
        GuardOpsMediaUpload(
          mediaId: 'MEDIA-RETRY-1',
          eventId: 'EVENT-RETRY-1',
          guardId: 'GUARD-001',
          siteId: 'SITE-SANDTON',
          shiftId: 'SHIFT-1',
          bucket: 'guard-patrol-images',
          path: 'guard/GUARD-001/media-retry-1.jpg',
          localPath: '/tmp/media-retry-1.jpg',
          capturedAt: DateTime.utc(2026, 3, 4, 11, 9),
        ),
      );

      await repository.syncPendingEvents();
      await repository.uploadPendingMedia();
      expect(await repository.failedEvents(), hasLength(1));
      expect(await repository.failedMedia(), hasLength(1));

      final retriedEvents = await repository.retryFailedEvents();
      final retriedMedia = await repository.retryFailedMedia();

      expect(retriedEvents, 1);
      expect(retriedMedia, 1);
      expect(await repository.failedEvents(), isEmpty);
      expect(await repository.failedMedia(), isEmpty);
      expect(await repository.pendingMedia(), hasLength(1));
    });
  });
}

class _FakeGuardOpsRemoteGateway implements GuardOpsRemoteGateway {
  bool throwOnEventSync;
  bool throwOnMediaUpload;
  final List<GuardOpsEvent> syncedEvents = <GuardOpsEvent>[];
  final List<GuardOpsMediaUpload> uploadedMedia = <GuardOpsMediaUpload>[];

  _FakeGuardOpsRemoteGateway({
    this.throwOnEventSync = false,
    this.throwOnMediaUpload = false,
  });

  @override
  Future<void> upsertEvents(List<GuardOpsEvent> events) async {
    if (throwOnEventSync) {
      throw StateError('event sync failed');
    }
    syncedEvents.addAll(events);
  }

  @override
  Future<void> upsertMediaMetadata(List<GuardOpsMediaUpload> media) async {
    if (throwOnMediaUpload) {
      throw StateError('media upload failed');
    }
    uploadedMedia.addAll(media);
  }
}
