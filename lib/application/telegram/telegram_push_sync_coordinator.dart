import '../../ui/client_app_page.dart';
import '../client_conversation_repository.dart';

sealed class PushSyncResult {
  const PushSyncResult();
}

final class PushSyncSuccess extends PushSyncResult {
  final List<ClientAppPushDeliveryItem> persistedQueue;
  final ClientPushSyncState updatedSyncState;

  const PushSyncSuccess({
    required this.persistedQueue,
    required this.updatedSyncState,
  });
}

final class PushSyncRepoMissing extends PushSyncResult {
  final ClientPushSyncState failedSyncState;
  final String reason;

  const PushSyncRepoMissing({
    required this.failedSyncState,
    required this.reason,
  });
}

final class PushSyncPersistFailed extends PushSyncResult {
  final List<ClientAppPushDeliveryItem> attemptedQueue;
  final ClientPushSyncState failedSyncState;
  final Object error;
  final bool persistedFailureState;

  const PushSyncPersistFailed({
    required this.attemptedQueue,
    required this.failedSyncState,
    required this.error,
    required this.persistedFailureState,
  });
}

final class PushSyncStateWriteFailed extends PushSyncResult {
  final List<ClientAppPushDeliveryItem> persistedQueue;
  final ClientPushSyncState failedSyncState;
  final Object error;
  final bool persistedFailureState;

  const PushSyncStateWriteFailed({
    required this.persistedQueue,
    required this.failedSyncState,
    required this.error,
    required this.persistedFailureState,
  });
}

class TelegramPushSyncCoordinator {
  final Future<ClientConversationRepository?> Function({
    required String clientId,
    required String siteId,
  })
  repositoryResolver;
  final DateTime Function() nowUtc;

  const TelegramPushSyncCoordinator({
    required this.repositoryResolver,
    required this.nowUtc,
  });

  Future<PushSyncResult> persistPushQueueForScope({
    required String clientId,
    required String siteId,
    required List<ClientAppPushDeliveryItem> updatedQueue,
    required ClientPushSyncState currentSyncState,
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    final normalizedQueue = List<ClientAppPushDeliveryItem>.from(updatedQueue);
    final conversation = await repositoryResolver(
      clientId: normalizedClientId,
      siteId: normalizedSiteId,
    );
    if (conversation == null) {
      return PushSyncRepoMissing(
        failedSyncState: _failedSyncState(
          currentSyncState: currentSyncState,
          occurredAtUtc: nowUtc(),
          queueSize: normalizedQueue.length,
          failureReason: 'Scoped conversation repository unavailable.',
        ),
        reason: 'Scoped conversation repository unavailable.',
      );
    }

    try {
      await conversation.savePushQueue(normalizedQueue);
    } catch (error) {
      final failedSyncState = _failedSyncState(
        currentSyncState: currentSyncState,
        occurredAtUtc: nowUtc(),
        queueSize: normalizedQueue.length,
        failureReason: error.toString(),
      );
      final persistedFailureState = await _tryPersistFailedState(
        conversation: conversation,
        state: failedSyncState,
      );
      return PushSyncPersistFailed(
        attemptedQueue: normalizedQueue,
        failedSyncState: failedSyncState,
        error: error,
        persistedFailureState: persistedFailureState,
      );
    }

    final syncedAtUtc = nowUtc();
    final successSyncState = _successSyncState(
      currentSyncState: currentSyncState,
      occurredAtUtc: syncedAtUtc,
      queueSize: normalizedQueue.length,
    );
    try {
      await conversation.savePushSyncState(successSyncState);
      return PushSyncSuccess(
        persistedQueue: normalizedQueue,
        updatedSyncState: successSyncState,
      );
    } catch (error) {
      final failedSyncState = _failedSyncState(
        currentSyncState: currentSyncState,
        occurredAtUtc: syncedAtUtc,
        queueSize: normalizedQueue.length,
        failureReason: error.toString(),
      );
      final persistedFailureState = await _tryPersistFailedState(
        conversation: conversation,
        state: failedSyncState,
      );
      return PushSyncStateWriteFailed(
        persistedQueue: normalizedQueue,
        failedSyncState: failedSyncState,
        error: error,
        persistedFailureState: persistedFailureState,
      );
    }
  }

  ClientPushSyncState _successSyncState({
    required ClientPushSyncState currentSyncState,
    required DateTime occurredAtUtc,
    required int queueSize,
  }) {
    return ClientPushSyncState(
      statusLabel: 'ok',
      lastSyncedAtUtc: occurredAtUtc,
      failureReason: null,
      retryCount: 0,
      history: <ClientPushSyncAttempt>[
        ClientPushSyncAttempt(
          occurredAt: occurredAtUtc,
          status: 'ok',
          queueSize: queueSize,
        ),
        ...currentSyncState.history,
      ].take(20).toList(growable: false),
      telegramDeliveredMessageKeys: currentSyncState.telegramDeliveredMessageKeys,
      backendProbeStatusLabel: currentSyncState.backendProbeStatusLabel,
      backendProbeLastRunAtUtc: currentSyncState.backendProbeLastRunAtUtc,
      backendProbeFailureReason: currentSyncState.backendProbeFailureReason,
      backendProbeHistory: currentSyncState.backendProbeHistory,
    );
  }

  ClientPushSyncState _failedSyncState({
    required ClientPushSyncState currentSyncState,
    required DateTime occurredAtUtc,
    required int queueSize,
    required String failureReason,
  }) {
    return ClientPushSyncState(
      statusLabel: 'failed',
      lastSyncedAtUtc: currentSyncState.lastSyncedAtUtc,
      failureReason: failureReason,
      retryCount: currentSyncState.retryCount + 1,
      history: <ClientPushSyncAttempt>[
        ClientPushSyncAttempt(
          occurredAt: occurredAtUtc,
          status: 'failed',
          failureReason: failureReason,
          queueSize: queueSize,
        ),
        ...currentSyncState.history,
      ].take(20).toList(growable: false),
      telegramDeliveredMessageKeys: currentSyncState.telegramDeliveredMessageKeys,
      backendProbeStatusLabel: currentSyncState.backendProbeStatusLabel,
      backendProbeLastRunAtUtc: currentSyncState.backendProbeLastRunAtUtc,
      backendProbeFailureReason: currentSyncState.backendProbeFailureReason,
      backendProbeHistory: currentSyncState.backendProbeHistory,
    );
  }

  Future<bool> _tryPersistFailedState({
    required ClientConversationRepository conversation,
    required ClientPushSyncState state,
  }) async {
    try {
      await conversation.savePushSyncState(state);
      return true;
    } catch (_) {
      return false;
    }
  }
}
