import '../ui/client_app_page.dart';
import 'telegram_bridge_delivery_memory.dart';
import 'telegram_bridge_resolver.dart';
import 'telegram_bridge_service.dart';

class TelegramPushDispatchResult {
  final bool noop;
  final String healthLabel;
  final String? healthDetail;
  final bool fallbackToInApp;
  final DateTime occurredAtUtc;
  final String attemptStatus;
  final String? attemptFailureReason;
  final int attemptQueueSize;
  final List<ClientAppPushDeliveryItem> smsFallbackCandidates;
  final String? smsFallbackReason;
  final Map<String, List<String>> deliveredMessageKeysByScope;

  const TelegramPushDispatchResult({
    required this.noop,
    required this.healthLabel,
    this.healthDetail,
    required this.fallbackToInApp,
    required this.occurredAtUtc,
    required this.attemptStatus,
    this.attemptFailureReason,
    required this.attemptQueueSize,
    required this.smsFallbackCandidates,
    this.smsFallbackReason,
    this.deliveredMessageKeysByScope = const <String, List<String>>{},
  });

  factory TelegramPushDispatchResult.noop() {
    return TelegramPushDispatchResult(
      noop: true,
      healthLabel: 'idle',
      fallbackToInApp: false,
      occurredAtUtc: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      attemptStatus: 'noop',
      attemptQueueSize: 0,
      smsFallbackCandidates: const <ClientAppPushDeliveryItem>[],
    );
  }
}

class TelegramPushCoordinator {
  final TelegramBridgeService telegramBridge;
  final TelegramBridgeResolver telegramBridgeResolver;
  final TelegramBridgeDeliveryMemory deliveryMemory;
  final String Function(ClientAppPushDeliveryItem item) messageBodyForItem;
  final Map<String, Object?>? Function(ClientAppPushDeliveryItem item)
  replyMarkupForItem;
  final bool Function(ClientAppPushDeliveryItem item)
  isFreshExternalPushCandidate;
  final bool Function(String raw) isBlockedReason;
  final DateTime Function() nowUtc;

  const TelegramPushCoordinator({
    required this.telegramBridge,
    required this.telegramBridgeResolver,
    required this.deliveryMemory,
    required this.messageBodyForItem,
    required this.replyMarkupForItem,
    required this.isFreshExternalPushCandidate,
    required this.isBlockedReason,
    required this.nowUtc,
  });

  List<ClientAppPushDeliveryItem> selectNewTelegramBridgeCandidates({
    required List<ClientAppPushDeliveryItem> previousQueue,
    required List<ClientAppPushDeliveryItem> currentQueue,
    required bool bridgeFallbackToInApp,
    bool forceResend = false,
  }) {
    if (!telegramBridge.isConfigured) {
      return const <ClientAppPushDeliveryItem>[];
    }
    if (bridgeFallbackToInApp && !forceResend) {
      return const <ClientAppPushDeliveryItem>[];
    }
    final telegramQueue = currentQueue
        .where(
          (item) =>
              item.status == ClientPushDeliveryStatus.queued &&
              (item.deliveryProvider == ClientPushDeliveryProvider.telegram ||
                  item.deliveryProvider == ClientPushDeliveryProvider.inApp),
        )
        .where(isFreshExternalPushCandidate)
        .toList(growable: false);
    if (forceResend) {
      return telegramQueue;
    }
    final previousKeys = previousQueue.map(_pushDeliveryBridgeKey).toSet();
    return telegramQueue
        .where((item) => !previousKeys.contains(_pushDeliveryBridgeKey(item)))
        .toList(growable: false);
  }

  Future<TelegramPushDispatchResult> forwardPushQueueToTelegram({
    required List<ClientAppPushDeliveryItem> candidates,
    required bool allowPreviouslyDelivered,
    required String defaultClientId,
    required String defaultSiteId,
    required String Function(String clientId, String siteId) scopeKeyFor,
    required Set<String> Function(String clientId, String siteId)
    deliveredMessageKeysForScope,
  }) async {
    if (!telegramBridge.isConfigured) {
      return TelegramPushDispatchResult(
        noop: false,
        healthLabel: 'disabled',
        healthDetail: 'Telegram bridge disabled or missing bot token.',
        fallbackToInApp: false,
        occurredAtUtc: nowUtc(),
        attemptStatus: 'telegram-disabled',
        attemptQueueSize: candidates.length,
        smsFallbackCandidates: candidates,
        smsFallbackReason: 'telegram disabled',
      );
    }
    if (candidates.isEmpty) {
      return TelegramPushDispatchResult.noop();
    }

    final targetCache = <String, List<TelegramBridgeTarget>>{};
    final deliveredMessageKeysCache = <String, Set<String>>{};
    final skippedNoTargetContexts = <String>{};
    final skippedNoTargetItemsByBridgeKey =
        <String, ClientAppPushDeliveryItem>{};
    final outbound = <TelegramBridgeMessage>[];
    final outboundItemsByMessageKey = <String, ClientAppPushDeliveryItem>{};
    final outboundScopeByMessageKey = <String, String>{};

    for (final item in candidates) {
      final targetClientId = (item.clientId ?? '').trim().isNotEmpty
          ? item.clientId!.trim()
          : defaultClientId.trim();
      final targetSiteId = (item.siteId ?? '').trim().isNotEmpty
          ? item.siteId!.trim()
          : defaultSiteId.trim();
      final scopeKey = scopeKeyFor(targetClientId, targetSiteId);
      final targets = targetCache.containsKey(scopeKey)
          ? targetCache[scopeKey]!
          : await telegramBridgeResolver.resolveClientTargets(
              clientId: targetClientId,
              siteId: targetSiteId,
            );
      targetCache[scopeKey] = targets;
      final deliveredMessageKeys = allowPreviouslyDelivered
          ? const <String>{}
          : deliveredMessageKeysCache.putIfAbsent(
              scopeKey,
              () => deliveredMessageKeysForScope(targetClientId, targetSiteId),
            );
      if (targets.isEmpty) {
        skippedNoTargetContexts.add('$targetClientId/$targetSiteId');
        skippedNoTargetItemsByBridgeKey[_pushDeliveryBridgeKey(item)] = item;
        continue;
      }
      for (final target in targets) {
        final messageKey =
            '${_pushDeliveryBridgeKey(item)}:${target.chatId}:${target.threadId ?? ''}';
        if (!allowPreviouslyDelivered &&
            deliveredMessageKeys.contains(messageKey)) {
          continue;
        }
        outboundItemsByMessageKey[messageKey] = item;
        outboundScopeByMessageKey[messageKey] = scopeKey;
        outbound.add(
          TelegramBridgeMessage(
            messageKey: messageKey,
            chatId: target.chatId,
            messageThreadId: target.threadId,
            text: messageBodyForItem(item),
            replyMarkup: replyMarkupForItem(item),
          ),
        );
      }
    }

    if (outbound.isEmpty) {
      if (skippedNoTargetItemsByBridgeKey.isEmpty) {
        return TelegramPushDispatchResult.noop();
      }
      final noTargetLabel = skippedNoTargetContexts.isEmpty
          ? 'No active Telegram endpoint for $defaultClientId / $defaultSiteId.'
          : 'No active Telegram endpoint for ${skippedNoTargetContexts.join(', ')}.';
      return TelegramPushDispatchResult(
        noop: false,
        healthLabel: 'no-target',
        healthDetail: noTargetLabel,
        fallbackToInApp: true,
        occurredAtUtc: nowUtc(),
        attemptStatus: 'telegram-skipped',
        attemptFailureReason: noTargetLabel,
        attemptQueueSize: candidates.length,
        smsFallbackCandidates: skippedNoTargetItemsByBridgeKey.values.toList(
          growable: false,
        ),
        smsFallbackReason: 'telegram target failure',
      );
    }

    final sentAt = nowUtc();
    TelegramBridgeSendResult result;
    try {
      result = await telegramBridge.sendMessages(messages: outbound);
    } catch (error) {
      return TelegramPushDispatchResult(
        noop: false,
        healthLabel: 'degraded',
        healthDetail: error.toString(),
        fallbackToInApp: false,
        occurredAtUtc: sentAt,
        attemptStatus: 'telegram-failed',
        attemptFailureReason: error.toString(),
        attemptQueueSize: outbound.length,
        smsFallbackCandidates: outboundItemsByMessageKey.values.toSet().toList(
          growable: false,
        ),
        smsFallbackReason: 'telegram transport failure',
      );
    }

    final deliveredMessageKeysByScope = _mergeDeliveredMessageKeysByScope(
      sentMessageKeys: result.sent.map((message) => message.messageKey),
      scopeByMessageKey: outboundScopeByMessageKey,
      deliveredMessageKeysForScope: deliveredMessageKeysForScope,
    );
    if (result.failedCount == 0) {
      return TelegramPushDispatchResult(
        noop: false,
        healthLabel: 'ok',
        healthDetail: 'Last Telegram delivery succeeded.',
        fallbackToInApp: false,
        occurredAtUtc: sentAt,
        attemptStatus: 'telegram-ok',
        attemptQueueSize: outbound.length,
        smsFallbackCandidates: const <ClientAppPushDeliveryItem>[],
        deliveredMessageKeysByScope: deliveredMessageKeysByScope,
      );
    }

    final reasonValues = result.failureReasonsByMessageKey.values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final failedItems = result.failed
        .map((message) => outboundItemsByMessageKey[message.messageKey])
        .whereType<ClientAppPushDeliveryItem>()
        .toSet()
        .toList(growable: false);
    final blocked = reasonValues.any(isBlockedReason);
    final reasonSuffix = reasonValues.isEmpty
        ? ''
        : ' Reasons: ${reasonValues.take(2).join(' | ')}';
    final failureLabel =
        'Telegram bridge failed for ${result.failedCount}/${outbound.length} message(s).$reasonSuffix';
    return TelegramPushDispatchResult(
      noop: false,
      healthLabel: blocked ? 'blocked' : 'degraded',
      healthDetail: failureLabel,
      fallbackToInApp: blocked,
      occurredAtUtc: sentAt,
      attemptStatus: blocked ? 'telegram-blocked' : 'telegram-failed',
      attemptFailureReason: failureLabel,
      attemptQueueSize: outbound.length,
      smsFallbackCandidates: failedItems.isEmpty ? candidates : failedItems,
      smsFallbackReason: blocked ? 'telegram blocked' : 'telegram degraded',
      deliveredMessageKeysByScope: deliveredMessageKeysByScope,
    );
  }

  Map<String, List<String>> _mergeDeliveredMessageKeysByScope({
    required Iterable<String> sentMessageKeys,
    required Map<String, String> scopeByMessageKey,
    required Set<String> Function(String clientId, String siteId)
    deliveredMessageKeysForScope,
  }) {
    final sentKeysByScope = <String, List<String>>{};
    for (final sentMessageKey in sentMessageKeys) {
      final normalizedKey = sentMessageKey.trim();
      if (normalizedKey.isEmpty) {
        continue;
      }
      final scopeKey = scopeByMessageKey[normalizedKey];
      if (scopeKey == null || scopeKey.trim().isEmpty) {
        continue;
      }
      sentKeysByScope
          .putIfAbsent(scopeKey, () => <String>[])
          .add(normalizedKey);
    }
    if (sentKeysByScope.isEmpty) {
      return const <String, List<String>>{};
    }
    final merged = <String, List<String>>{};
    for (final entry in sentKeysByScope.entries) {
      final parts = entry.key.split('|');
      if (parts.length != 2) {
        continue;
      }
      final clientId = parts.first.trim();
      final siteId = parts.last.trim();
      if (clientId.isEmpty || siteId.isEmpty) {
        continue;
      }
      merged[entry.key] = deliveryMemory.mergeDeliveredMessageKeys(
        existingKeys: deliveredMessageKeysForScope(clientId, siteId),
        deliveredKeys: entry.value,
      );
    }
    return merged;
  }

  String _pushDeliveryBridgeKey(ClientAppPushDeliveryItem item) {
    return '${item.messageKey}:${item.deliveryProvider.code}';
  }
}
