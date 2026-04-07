import '../ui/client_app_page.dart';
import 'client_conversation_repository.dart';

sealed class BackendProbeResult {
  const BackendProbeResult();
}

final class BackendProbeSuccess extends BackendProbeResult {
  final ClientPushSyncState updatedSyncState;

  const BackendProbeSuccess({required this.updatedSyncState});
}

final class BackendProbeRepoMissing extends BackendProbeResult {
  final ClientPushSyncState failedSyncState;
  final String reason;

  const BackendProbeRepoMissing({
    required this.failedSyncState,
    required this.reason,
  });
}

final class BackendProbeFailed extends BackendProbeResult {
  final ClientPushSyncState failedSyncState;
  final Object error;
  final bool persistedFailureState;

  const BackendProbeFailed({
    required this.failedSyncState,
    required this.error,
    required this.persistedFailureState,
  });
}

final class BackendProbeStateWriteFailed extends BackendProbeResult {
  final ClientPushSyncState updatedSyncState;
  final Object error;

  const BackendProbeStateWriteFailed({
    required this.updatedSyncState,
    required this.error,
  });
}

class ClientBackendProbeCoordinator {
  final Future<ClientConversationRepository?> Function({
    required String clientId,
    required String siteId,
  })
  repositoryResolver;
  final DateTime Function() nowUtc;

  const ClientBackendProbeCoordinator({
    required this.repositoryResolver,
    required this.nowUtc,
  });

  Future<BackendProbeResult> runBackendProbeForScope({
    required String clientId,
    required String siteId,
    required int queueSize,
    required ClientPushSyncState currentSyncState,
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    final conversation = await repositoryResolver(
      clientId: normalizedClientId,
      siteId: normalizedSiteId,
    );
    final probeTimestamp = nowUtc();

    if (conversation == null) {
      return BackendProbeRepoMissing(
        failedSyncState: _failedResultState(
          currentSyncState: currentSyncState,
          occurredAtUtc: probeTimestamp,
          failureReason: 'Scoped conversation repository unavailable.',
        ),
        reason: 'Scoped conversation repository unavailable.',
      );
    }

    ClientPushSyncState originalState;
    try {
      originalState = await conversation.readPushSyncState();
    } catch (error) {
      final failedSyncState = _failedResultState(
        currentSyncState: currentSyncState,
        occurredAtUtc: probeTimestamp,
        failureReason: error.toString(),
      );
      final persistedFailureState = await _tryPersistResultState(
        conversation: conversation,
        state: failedSyncState,
      );
      return BackendProbeFailed(
        failedSyncState: failedSyncState,
        error: error,
        persistedFailureState: persistedFailureState,
      );
    }

    final probeState = _probeMarkerState(
      originalState: originalState,
      occurredAtUtc: probeTimestamp,
      queueSize: queueSize,
    );

    try {
      await conversation.savePushSyncState(probeState);
      final restored = await conversation.readPushSyncState();
      if (restored.statusLabel != 'probe' || restored.history.isEmpty) {
        throw StateError('Probe readback did not return the expected marker.');
      }
      await conversation.savePushSyncState(originalState);
    } catch (error) {
      try {
        await conversation.savePushSyncState(originalState);
      } catch (_) {
        // Preserve the original probe failure.
      }
      final failedSyncState = _failedResultState(
        currentSyncState: currentSyncState,
        occurredAtUtc: probeTimestamp,
        failureReason: error.toString(),
      );
      final persistedFailureState = await _tryPersistResultState(
        conversation: conversation,
        state: failedSyncState,
      );
      if (!persistedFailureState) {
        return BackendProbeStateWriteFailed(
          updatedSyncState: failedSyncState,
          error: error,
        );
      }
      return BackendProbeFailed(
        failedSyncState: failedSyncState,
        error: error,
        persistedFailureState: true,
      );
    }

    final successSyncState = _successResultState(
      currentSyncState: currentSyncState,
      occurredAtUtc: probeTimestamp,
    );
    try {
      await conversation.savePushSyncState(successSyncState);
      return BackendProbeSuccess(updatedSyncState: successSyncState);
    } catch (error) {
      return BackendProbeStateWriteFailed(
        updatedSyncState: successSyncState,
        error: error,
      );
    }
  }

  ClientPushSyncState _probeMarkerState({
    required ClientPushSyncState originalState,
    required DateTime occurredAtUtc,
    required int queueSize,
  }) {
    return ClientPushSyncState(
      statusLabel: 'probe',
      lastSyncedAtUtc: occurredAtUtc,
      failureReason: null,
      retryCount: 0,
      history: <ClientPushSyncAttempt>[
        ClientPushSyncAttempt(
          occurredAt: occurredAtUtc,
          status: 'probe',
          queueSize: queueSize,
        ),
        ...originalState.history,
      ].take(20).toList(growable: false),
      telegramDeliveredMessageKeys: originalState.telegramDeliveredMessageKeys,
      backendProbeStatusLabel: originalState.backendProbeStatusLabel,
      backendProbeLastRunAtUtc: originalState.backendProbeLastRunAtUtc,
      backendProbeFailureReason: originalState.backendProbeFailureReason,
      backendProbeHistory: originalState.backendProbeHistory,
    );
  }

  ClientPushSyncState _successResultState({
    required ClientPushSyncState currentSyncState,
    required DateTime occurredAtUtc,
  }) {
    return ClientPushSyncState(
      statusLabel: currentSyncState.statusLabel,
      lastSyncedAtUtc: currentSyncState.lastSyncedAtUtc,
      failureReason: currentSyncState.failureReason,
      retryCount: currentSyncState.retryCount,
      history: currentSyncState.history,
      telegramDeliveredMessageKeys: currentSyncState.telegramDeliveredMessageKeys,
      backendProbeStatusLabel: 'ok',
      backendProbeLastRunAtUtc: occurredAtUtc,
      backendProbeFailureReason: null,
      backendProbeHistory: <ClientBackendProbeAttempt>[
        ClientBackendProbeAttempt(
          occurredAt: occurredAtUtc,
          status: 'ok',
        ),
        ...currentSyncState.backendProbeHistory,
      ].take(20).toList(growable: false),
    );
  }

  ClientPushSyncState _failedResultState({
    required ClientPushSyncState currentSyncState,
    required DateTime occurredAtUtc,
    required String failureReason,
  }) {
    return ClientPushSyncState(
      statusLabel: currentSyncState.statusLabel,
      lastSyncedAtUtc: currentSyncState.lastSyncedAtUtc,
      failureReason: currentSyncState.failureReason,
      retryCount: currentSyncState.retryCount,
      history: currentSyncState.history,
      telegramDeliveredMessageKeys: currentSyncState.telegramDeliveredMessageKeys,
      backendProbeStatusLabel: 'failed',
      backendProbeLastRunAtUtc: occurredAtUtc,
      backendProbeFailureReason: failureReason,
      backendProbeHistory: <ClientBackendProbeAttempt>[
        ClientBackendProbeAttempt(
          occurredAt: occurredAtUtc,
          status: 'failed',
          failureReason: failureReason,
        ),
        ...currentSyncState.backendProbeHistory,
      ].take(20).toList(growable: false),
    );
  }

  Future<bool> _tryPersistResultState({
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
