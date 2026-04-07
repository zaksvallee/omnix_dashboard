import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/client_backend_probe_coordinator.dart';
import 'package:omnix_dashboard/application/client_conversation_repository.dart';
import 'package:omnix_dashboard/ui/client_app_page.dart';

void main() {
  group('ClientBackendProbeCoordinator', () {
    test('returns repo missing before any repository writes', () async {
      final coordinator = ClientBackendProbeCoordinator(
        repositoryResolver:
            ({required String clientId, required String siteId}) async => null,
        nowUtc: () => DateTime.utc(2026, 4, 6, 23, 0),
      );

      final result = await coordinator.runBackendProbeForScope(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        queueSize: 2,
        currentSyncState: _currentSyncState(),
      );

      expect(result, isA<BackendProbeRepoMissing>());
      final repoMissing = result as BackendProbeRepoMissing;
      expect(repoMissing.reason, contains('Scoped conversation repository'));
      expect(repoMissing.failedSyncState.backendProbeStatusLabel, 'failed');
      expect(repoMissing.failedSyncState.backendProbeHistory.first.status, 'failed');
    });

    test('persists successful backend probe result state', () async {
      final repository = _FakeClientConversationRepository(
        originalState: _originalRepositoryState(),
      );
      final coordinator = ClientBackendProbeCoordinator(
        repositoryResolver:
            ({required String clientId, required String siteId}) async =>
                repository,
        nowUtc: () => DateTime.utc(2026, 4, 6, 23, 5),
      );

      final result = await coordinator.runBackendProbeForScope(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        queueSize: 3,
        currentSyncState: _currentSyncState(),
      );

      expect(result, isA<BackendProbeSuccess>());
      final success = result as BackendProbeSuccess;
      expect(success.updatedSyncState.backendProbeStatusLabel, 'ok');
      expect(success.updatedSyncState.backendProbeFailureReason, isNull);
      expect(success.updatedSyncState.backendProbeHistory.first.status, 'ok');
      expect(repository.savedPushSyncStates, hasLength(3));
      expect(repository.savedPushSyncStates.last.backendProbeStatusLabel, 'ok');
    });

    test('returns failed result when probe marker save throws', () async {
      final repository = _FakeClientConversationRepository(
        originalState: _originalRepositoryState(),
        saveFailures: <int>{1},
      );
      final coordinator = ClientBackendProbeCoordinator(
        repositoryResolver:
            ({required String clientId, required String siteId}) async =>
                repository,
        nowUtc: () => DateTime.utc(2026, 4, 6, 23, 10),
      );

      final result = await coordinator.runBackendProbeForScope(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        queueSize: 4,
        currentSyncState: _currentSyncState(),
      );

      expect(result, isA<BackendProbeFailed>());
      final failure = result as BackendProbeFailed;
      expect(failure.error, isA<StateError>());
      expect(failure.persistedFailureState, isTrue);
      expect(failure.failedSyncState.backendProbeStatusLabel, 'failed');
      expect(
        failure.failedSyncState.backendProbeFailureReason,
        contains('probe save failed'),
      );
      expect(repository.savedPushSyncStates, hasLength(2));
      expect(repository.savedPushSyncStates.last.backendProbeStatusLabel, 'failed');
    });

    test(
        'returns state write failed when final backend probe result write throws',
        () async {
      final repository = _FakeClientConversationRepository(
        originalState: _originalRepositoryState(),
        saveFailures: <int>{3},
      );
      final coordinator = ClientBackendProbeCoordinator(
        repositoryResolver:
            ({required String clientId, required String siteId}) async =>
                repository,
        nowUtc: () => DateTime.utc(2026, 4, 6, 23, 15),
      );

      final result = await coordinator.runBackendProbeForScope(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        queueSize: 5,
        currentSyncState: _currentSyncState(),
      );

      expect(result, isA<BackendProbeStateWriteFailed>());
      final failure = result as BackendProbeStateWriteFailed;
      expect(failure.error, isA<StateError>());
      expect(failure.updatedSyncState.backendProbeStatusLabel, 'ok');
      expect(failure.updatedSyncState.backendProbeHistory.first.status, 'ok');
      expect(repository.savedPushSyncStates, hasLength(2));
      expect(repository.savedPushSyncStates.last.backendProbeStatusLabel, 'degraded');
    });
  });
}

ClientPushSyncState _currentSyncState() {
  return ClientPushSyncState(
    statusLabel: 'degraded',
    lastSyncedAtUtc: DateTime.utc(2026, 4, 6, 22, 30),
    failureReason: 'telegram degraded',
    retryCount: 2,
    history: <ClientPushSyncAttempt>[
      ClientPushSyncAttempt(
        occurredAt: DateTime.utc(2026, 4, 6, 22, 30),
        status: 'telegram-degraded',
        failureReason: 'telegram degraded',
        queueSize: 2,
      ),
    ],
    telegramDeliveredMessageKeys: const <String>['older-key'],
    backendProbeStatusLabel: 'idle',
    backendProbeLastRunAtUtc: null,
    backendProbeFailureReason: null,
    backendProbeHistory: const <ClientBackendProbeAttempt>[],
  );
}

ClientPushSyncState _originalRepositoryState() {
  return ClientPushSyncState(
    statusLabel: 'degraded',
    lastSyncedAtUtc: DateTime.utc(2026, 4, 6, 22, 25),
    failureReason: 'telegram degraded',
    retryCount: 2,
    history: <ClientPushSyncAttempt>[
      ClientPushSyncAttempt(
        occurredAt: DateTime.utc(2026, 4, 6, 22, 25),
        status: 'queued',
        queueSize: 1,
      ),
    ],
    telegramDeliveredMessageKeys: const <String>['older-key'],
    backendProbeStatusLabel: 'degraded',
    backendProbeLastRunAtUtc: DateTime.utc(2026, 4, 6, 21, 0),
    backendProbeFailureReason: 'stale note',
    backendProbeHistory: <ClientBackendProbeAttempt>[
      ClientBackendProbeAttempt(
        occurredAt: DateTime.utc(2026, 4, 6, 21, 0),
        status: 'failed',
        failureReason: 'stale note',
      ),
    ],
  );
}

class _FakeClientConversationRepository
    implements ClientConversationRepository {
  final ClientPushSyncState originalState;
  final Set<int> saveFailures;
  int _saveCount = 0;
  bool _probeSaved = false;

  List<ClientPushSyncState> savedPushSyncStates = <ClientPushSyncState>[];

  _FakeClientConversationRepository({
    required this.originalState,
    this.saveFailures = const <int>{},
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
    return const <ClientAppPushDeliveryItem>[];
  }

  @override
  Future<ClientPushSyncState> readPushSyncState() async {
    if (_probeSaved) {
      return savedPushSyncStates.last;
    }
    return originalState;
  }

  @override
  Future<void> saveAcknowledgements(
    List<ClientAppAcknowledgement> acknowledgements,
  ) async {}

  @override
  Future<void> saveMessages(List<ClientAppMessage> messages) async {}

  @override
  Future<void> savePushQueue(List<ClientAppPushDeliveryItem> pushQueue) async {}

  @override
  Future<void> savePushSyncState(ClientPushSyncState state) async {
    _saveCount += 1;
    if (saveFailures.contains(_saveCount)) {
      if (_saveCount == 1) {
        throw StateError('probe save failed');
      }
      if (_saveCount == 3) {
        throw StateError('final result state write failed');
      }
      throw StateError('push sync state write failed');
    }
    _probeSaved = state.statusLabel == 'probe';
    if (state.statusLabel != 'probe') {
      _probeSaved = false;
    }
    savedPushSyncStates = <ClientPushSyncState>[
      ...savedPushSyncStates,
      state,
    ];
  }
}
