import 'client_messaging_bridge_repository.dart';

class TelegramBridgeTarget {
  final String chatId;
  final int? threadId;
  final String label;

  const TelegramBridgeTarget({
    required this.chatId,
    this.threadId,
    required this.label,
  });
}

class TelegramBridgeResolver {
  final Future<List<ClientTelegramEndpointRecord>> Function({
    required String clientId,
    required String siteId,
  })
  readManagedTelegramEndpointRecordsForScope;
  final bool Function(String label) isPartnerEndpointLabel;
  final String Function(String label) normalizePartnerEndpointLabel;
  final String Function() resolvedTelegramClientChatId;
  final int? Function() resolvedTelegramClientThreadId;
  final String initialClientLaneClientId;
  final String initialClientLaneSiteId;
  final String Function() resolvedTelegramPartnerChatId;
  final int? Function() resolvedTelegramPartnerThreadId;
  final String Function() resolvedTelegramPartnerClientId;
  final String Function() resolvedTelegramPartnerSiteId;
  final String telegramPartnerLabelEnv;

  const TelegramBridgeResolver({
    required this.readManagedTelegramEndpointRecordsForScope,
    required this.isPartnerEndpointLabel,
    required this.normalizePartnerEndpointLabel,
    required this.resolvedTelegramClientChatId,
    required this.resolvedTelegramClientThreadId,
    required this.initialClientLaneClientId,
    required this.initialClientLaneSiteId,
    required this.resolvedTelegramPartnerChatId,
    required this.resolvedTelegramPartnerThreadId,
    required this.resolvedTelegramPartnerClientId,
    required this.resolvedTelegramPartnerSiteId,
    required this.telegramPartnerLabelEnv,
  });

  TelegramBridgeTarget? telegramFallbackTarget({
    String? clientId,
    String? siteId,
  }) {
    final fallbackChatId = resolvedTelegramClientChatId().trim();
    if (fallbackChatId.isEmpty) {
      return null;
    }
    final fallbackClientId = initialClientLaneClientId.trim();
    final fallbackSiteId = initialClientLaneSiteId.trim();
    if (fallbackClientId.isEmpty || fallbackSiteId.isEmpty) {
      return null;
    }
    if (clientId != null && fallbackClientId != clientId.trim()) {
      return null;
    }
    if (siteId != null && fallbackSiteId != siteId.trim()) {
      return null;
    }
    return TelegramBridgeTarget(
      chatId: fallbackChatId,
      threadId: resolvedTelegramClientThreadId(),
      label: 'env-fallback',
    );
  }

  TelegramBridgeTarget? telegramPartnerFallbackTarget({
    required String clientId,
    required String siteId,
  }) {
    final fallbackChatId = resolvedTelegramPartnerChatId().trim();
    if (fallbackChatId.isEmpty) {
      return null;
    }
    final fallbackClientId = resolvedTelegramPartnerClientId().trim();
    final fallbackSiteId = resolvedTelegramPartnerSiteId().trim();
    if (fallbackClientId.isEmpty || fallbackSiteId.isEmpty) {
      return null;
    }
    if (fallbackClientId != clientId.trim()) {
      return null;
    }
    if (fallbackSiteId != siteId.trim()) {
      return null;
    }
    return TelegramBridgeTarget(
      chatId: fallbackChatId,
      threadId: resolvedTelegramPartnerThreadId(),
      label: normalizePartnerEndpointLabel(telegramPartnerLabelEnv),
    );
  }

  Future<List<TelegramBridgeTarget>> resolveClientTargets({
    required String clientId,
    required String siteId,
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    final fallbackTarget = telegramFallbackTarget(
      clientId: normalizedClientId,
      siteId: normalizedSiteId,
    );
    try {
      final records = await readManagedTelegramEndpointRecordsForScope(
        clientId: normalizedClientId,
        siteId: normalizedSiteId,
      );
      final targets = selectTelegramTargetsForLane(
        records: records,
        partnerTargets: false,
        isPartnerLabel: isPartnerEndpointLabel,
      );
      if (targets.isNotEmpty) {
        return targets
            .map(
              (endpoint) => TelegramBridgeTarget(
                chatId: endpoint.chatId,
                threadId: endpoint.threadId,
                label: endpoint.displayLabel,
              ),
            )
            .toList(growable: false);
      }
    } catch (_) {
      // Fall back to environment-level target if directory lookup fails.
    }
    return fallbackTarget == null
        ? const <TelegramBridgeTarget>[]
        : <TelegramBridgeTarget>[fallbackTarget];
  }

  Future<List<TelegramBridgeTarget>> resolvePartnerTargets({
    required String clientId,
    required String siteId,
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    final fallbackTarget = telegramPartnerFallbackTarget(
      clientId: normalizedClientId,
      siteId: normalizedSiteId,
    );
    try {
      final records = await readManagedTelegramEndpointRecordsForScope(
        clientId: normalizedClientId,
        siteId: normalizedSiteId,
      );
      final targets = selectTelegramTargetsForLane(
        records: records,
        partnerTargets: true,
        isPartnerLabel: isPartnerEndpointLabel,
      );
      if (targets.isNotEmpty) {
        return targets
            .map(
              (endpoint) => TelegramBridgeTarget(
                chatId: endpoint.chatId,
                threadId: endpoint.threadId,
                label: endpoint.displayLabel,
              ),
            )
            .toList(growable: false);
      }
    } catch (_) {
      // Fall back to environment-level target if directory lookup fails.
    }
    return fallbackTarget == null
        ? const <TelegramBridgeTarget>[]
        : <TelegramBridgeTarget>[fallbackTarget];
  }
}
