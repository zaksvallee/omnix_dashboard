import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/client_conversation_repository.dart';
import 'package:omnix_dashboard/application/telegram/telegram_push_sync_coordinator.dart';
import 'package:omnix_dashboard/ui/client_app_page.dart';

void main() {
  group('TelegramPushSyncCoordinator', () {
    test('returns repo missing before any queue or state write', () async {
      final coordinator = TelegramPushSyncCoordinator(
        repositoryResolver:
            ({required String clientId, required String siteId}) async => null,
        nowUtc: () => DateTime.utc(2026, 4, 6, 22, 0),
      );

      final result = await coordinator.persistPushQueueForScope(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        updatedQueue: <ClientAppPushDeliveryItem>[_pushItem('dispatch-1')],
        currentSyncState: _currentSyncState(),
      );

      expect(result, isA<PushSyncRepoMissing>());
      final repoMissing = result as PushSyncRepoMissing;
      expect(repoMissing.reason, contains('Scoped conversation repository'));
      expect(repoMissing.failedSyncState.statusLabel, 'failed');
      expect(repoMissing.failedSyncState.retryCount, 3);
      expect(repoMissing.failedSyncState.history.first.status, 'failed');
    });

    test('persists queue and success sync state on success', () async {
      final repository = _FakeClientConversationRepository();
      final coordinator = TelegramPushSyncCoordinator(
        repositoryResolver:
            ({required String clientId, required String siteId}) async =>
                repository,
        nowUtc: () => DateTime.utc(2026, 4, 6, 22, 5),
      );

      final result = await coordinator.persistPushQueueForScope(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        updatedQueue: <ClientAppPushDeliveryItem>[_pushItem('dispatch-2')],
        currentSyncState: _currentSyncState(),
      );

      expect(result, isA<PushSyncSuccess>());
      final success = result as PushSyncSuccess;
      expect(
        repository.savedPushQueue.map((item) => item.messageKey),
        <String>['dispatch-2'],
      );
      expect(repository.savedPushSyncStates, hasLength(1));
      expect(success.updatedSyncState.statusLabel, 'ok');
      expect(success.updatedSyncState.retryCount, 0);
      expect(
        success.updatedSyncState.telegramDeliveredMessageKeys,
        <String>['older-key'],
      );
      expect(success.updatedSyncState.backendProbeStatusLabel, 'ok');
    });

    test('returns persist failed and records failed sync state when queue save throws',
        () async {
      final repository = _FakeClientConversationRepository(
        queueSaveError: StateError('queue write failed'),
      );
      final coordinator = TelegramPushSyncCoordinator(
        repositoryResolver:
            ({required String clientId, required String siteId}) async =>
                repository,
        nowUtc: () => DateTime.utc(2026, 4, 6, 22, 10),
      );

      final result = await coordinator.persistPushQueueForScope(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        updatedQueue: <ClientAppPushDeliveryItem>[_pushItem('dispatch-3')],
        currentSyncState: _currentSyncState(),
      );

      expect(result, isA<PushSyncPersistFailed>());
      final failure = result as PushSyncPersistFailed;
      expect(failure.error, isA<StateError>());
      expect(failure.persistedFailureState, isTrue);
      expect(failure.failedSyncState.statusLabel, 'failed');
      expect(failure.failedSyncState.failureReason, contains('queue write failed'));
      expect(repository.savedPushQueue, isEmpty);
      expect(repository.savedPushSyncStates, hasLength(1));
      expect(repository.savedPushSyncStates.single.statusLabel, 'failed');
    });

    test(
        'returns state write failed when sync state persistence fails after queue save',
        () async {
      final repository = _FakeClientConversationRepository(
        pushSyncStateFailures: <int>{1},
      );
      final coordinator = TelegramPushSyncCoordinator(
        repositoryResolver:
            ({required String clientId, required String siteId}) async =>
                repository,
        nowUtc: () => DateTime.utc(2026, 4, 6, 22, 15),
      );

      final result = await coordinator.persistPushQueueForScope(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        updatedQueue: <ClientAppPushDeliveryItem>[_pushItem('dispatch-4')],
        currentSyncState: _currentSyncState(),
      );

      expect(result, isA<PushSyncStateWriteFailed>());
      final failure = result as PushSyncStateWriteFailed;
      expect(failure.error, isA<StateError>());
      expect(failure.persistedFailureState, isTrue);
      expect(failure.failedSyncState.statusLabel, 'failed');
      expect(repository.savedPushQueue, hasLength(1));
      expect(repository.savedPushSyncStates, hasLength(1));
      expect(repository.savedPushSyncStates.single.statusLabel, 'failed');
    });
  });
}

ClientPushSyncState _currentSyncState() {
  return ClientPushSyncState(
    statusLabel: 'degraded',
    lastSyncedAtUtc: DateTime.utc(2026, 4, 6, 21, 30),
    failureReason: 'telegram blocked',
    retryCount: 2,
    history: <ClientPushSyncAttempt>[
      ClientPushSyncAttempt(
        occurredAt: DateTime.utc(2026, 4, 6, 21, 30),
        status: 'telegram-failed',
        failureReason: 'telegram blocked',
        queueSize: 1,
      ),
    ],
    telegramDeliveredMessageKeys: const <String>['older-key'],
    backendProbeStatusLabel: 'ok',
    backendProbeLastRunAtUtc: DateTime.utc(2026, 4, 6, 21, 0),
    backendProbeFailureReason: null,
    backendProbeHistory: <ClientBackendProbeAttempt>[
      ClientBackendProbeAttempt(
        occurredAt: DateTime.utc(2026, 4, 6, 21, 0),
        status: 'ok',
      ),
    ],
  );
}

ClientAppPushDeliveryItem _pushItem(String messageKey) {
  return ClientAppPushDeliveryItem(
    messageKey: messageKey,
    title: 'Dispatch created',
    body: 'Response team activated.',
    occurredAt: DateTime.utc(2026, 4, 6, 22, 0),
    clientId: 'CLIENT-MS-VALLEE',
    siteId: 'SITE-MS-VALLEE-RESIDENCE',
    targetChannel: ClientAppAcknowledgementChannel.client,
    deliveryProvider: ClientPushDeliveryProvider.telegram,
    priority: true,
    status: ClientPushDeliveryStatus.queued,
  );
}

class _FakeClientConversationRepository
    implements ClientConversationRepository {
  final Object? queueSaveError;
  final Set<int> pushSyncStateFailures;
  int _pushSyncSaveCount = 0;

  List<ClientAppPushDeliveryItem> savedPushQueue = const [];
  List<ClientPushSyncState> savedPushSyncStates = <ClientPushSyncState>[];

  _FakeClientConversationRepository({
    this.queueSaveError,
    this.pushSyncStateFailures = const <int>{},
  });

  @override
  Future<List<ClientAppAcknowledgement>> readAcknowledgements() async {
    return const <ClientAppAcknowledgement>[];
  }

  @override
  Future<List<ClientAppMessage>> readMessages() async {
    return const <ClientAppMessage>[];
  }

  @override
  Future<List<ClientAppPushDeliveryItem>> readPushQueue() async {
    return savedPushQueue;
  }

  @override
  Future<ClientPushSyncState> readPushSyncState() async {
    return savedPushSyncStates.isEmpty
        ? const ClientPushSyncState.idle()
        : savedPushSyncStates.last;
  }

  @override
  Future<void> saveAcknowledgements(
    List<ClientAppAcknowledgement> acknowledgements,
  ) async {}

  @override
  Future<void> saveMessages(List<ClientAppMessage> messages) async {}

  @override
  Future<void> savePushQueue(List<ClientAppPushDeliveryItem> pushQueue) async {
    if (queueSaveError != null) {
      throw queueSaveError!;
    }
    savedPushQueue = List<ClientAppPushDeliveryItem>.from(pushQueue);
  }

  @override
  Future<void> savePushSyncState(ClientPushSyncState state) async {
    _pushSyncSaveCount += 1;
    if (pushSyncStateFailures.contains(_pushSyncSaveCount)) {
      throw StateError('sync state write failed');
    }
    savedPushSyncStates = <ClientPushSyncState>[
      ...savedPushSyncStates,
      state,
    ];
  }
}
