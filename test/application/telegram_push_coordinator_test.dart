import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/client_messaging_bridge_repository.dart';
import 'package:omnix_dashboard/application/telegram_bridge_delivery_memory.dart';
import 'package:omnix_dashboard/application/telegram_bridge_resolver.dart';
import 'package:omnix_dashboard/application/telegram_bridge_service.dart';
import 'package:omnix_dashboard/application/telegram_push_coordinator.dart';
import 'package:omnix_dashboard/ui/client_app_page.dart';

void main() {
  group('TelegramPushCoordinator', () {
    test('selects only new fresh queued telegram candidates', () {
      final coordinator = TelegramPushCoordinator(
        telegramBridge: _ConfiguredTelegramBridgeStub(),
        telegramBridgeResolver: _resolver(),
        deliveryMemory: const TelegramBridgeDeliveryMemory(),
        messageBodyForItem: (item) => item.body,
        replyMarkupForItem: (_) => null,
        isFreshExternalPushCandidate: (item) => item.messageKey != 'stale',
        isBlockedReason: (_) => false,
        nowUtc: () => DateTime.utc(2026, 4, 6, 20, 0),
      );

      final previousQueue = <ClientAppPushDeliveryItem>[
        _pushItem(messageKey: 'already-bridged'),
      ];
      final currentQueue = <ClientAppPushDeliveryItem>[
        _pushItem(messageKey: 'already-bridged'),
        _pushItem(messageKey: 'fresh'),
        _pushItem(messageKey: 'stale'),
        _pushItem(
          messageKey: 'acknowledged',
          status: ClientPushDeliveryStatus.acknowledged,
        ),
      ];

      final result = coordinator.selectNewTelegramBridgeCandidates(
        previousQueue: previousQueue,
        currentQueue: currentQueue,
        bridgeFallbackToInApp: false,
      );

      expect(result.map((item) => item.messageKey).toList(), <String>['fresh']);
    });

    test('skips already delivered telegram message keys unless resend is forced',
        () async {
      final bridge = _ConfiguredTelegramBridgeStub();
      final coordinator = TelegramPushCoordinator(
        telegramBridge: bridge,
        telegramBridgeResolver: _resolver(
          clientTargets: const <TelegramBridgeTarget>[
            TelegramBridgeTarget(
              chatId: 'client-chat',
              threadId: 11,
              label: 'Client Lane',
            ),
          ],
        ),
        deliveryMemory: const TelegramBridgeDeliveryMemory(),
        messageBodyForItem: (item) => item.body,
        replyMarkupForItem: (_) => null,
        isFreshExternalPushCandidate: (_) => true,
        isBlockedReason: (_) => false,
        nowUtc: () => DateTime.utc(2026, 4, 6, 20, 1),
      );

      final item = _pushItem(messageKey: 'dispatch-created');
      final deliveredKey = 'dispatch-created:telegram:client-chat:11';

      final skipped = await coordinator.forwardPushQueueToTelegram(
        candidates: <ClientAppPushDeliveryItem>[item],
        allowPreviouslyDelivered: false,
        defaultClientId: 'CLIENT-MS-VALLEE',
        defaultSiteId: 'SITE-MS-VALLEE-RESIDENCE',
        scopeKeyFor: (clientId, siteId) => '$clientId|$siteId',
        deliveredMessageKeysForScope: (_, _) => <String>{deliveredKey},
      );

      expect(skipped.noop, isTrue);
      expect(bridge.sentMessages, isEmpty);

      final resent = await coordinator.forwardPushQueueToTelegram(
        candidates: <ClientAppPushDeliveryItem>[item],
        allowPreviouslyDelivered: true,
        defaultClientId: 'CLIENT-MS-VALLEE',
        defaultSiteId: 'SITE-MS-VALLEE-RESIDENCE',
        scopeKeyFor: (clientId, siteId) => '$clientId|$siteId',
        deliveredMessageKeysForScope: (_, _) => <String>{deliveredKey},
      );

      expect(resent.noop, isFalse);
      expect(bridge.sentMessages, hasLength(1));
      expect(bridge.sentMessages.single.messageKey, deliveredKey);
    });

    test('returns merged delivery memory and sms fallback on target failure',
        () async {
      final coordinator = TelegramPushCoordinator(
        telegramBridge: _ConfiguredTelegramBridgeStub(),
        telegramBridgeResolver: _resolver(clientTargets: const <TelegramBridgeTarget>[]),
        deliveryMemory: const TelegramBridgeDeliveryMemory(),
        messageBodyForItem: (item) => item.body,
        replyMarkupForItem: (_) => null,
        isFreshExternalPushCandidate: (_) => true,
        isBlockedReason: (_) => false,
        nowUtc: () => DateTime.utc(2026, 4, 6, 20, 2),
      );

      final result = await coordinator.forwardPushQueueToTelegram(
        candidates: <ClientAppPushDeliveryItem>[
          _pushItem(messageKey: 'dispatch-created'),
        ],
        allowPreviouslyDelivered: false,
        defaultClientId: 'CLIENT-MS-VALLEE',
        defaultSiteId: 'SITE-MS-VALLEE-RESIDENCE',
        scopeKeyFor: (clientId, siteId) => '$clientId|$siteId',
        deliveredMessageKeysForScope: (_, _) => <String>{},
      );

      expect(result.noop, isFalse);
      expect(result.healthLabel, 'no-target');
      expect(result.smsFallbackReason, 'telegram target failure');
      expect(
        result.smsFallbackCandidates.map((item) => item.messageKey).toList(),
        <String>['dispatch-created'],
      );
    });

    test('records merged delivered keys after successful send', () async {
      final bridge = _ConfiguredTelegramBridgeStub();
      final coordinator = TelegramPushCoordinator(
        telegramBridge: bridge,
        telegramBridgeResolver: _resolver(
          clientTargets: const <TelegramBridgeTarget>[
            TelegramBridgeTarget(
              chatId: 'client-chat',
              threadId: 11,
              label: 'Client Lane',
            ),
          ],
        ),
        deliveryMemory: const TelegramBridgeDeliveryMemory(),
        messageBodyForItem: (item) => item.body,
        replyMarkupForItem: (_) => null,
        isFreshExternalPushCandidate: (_) => true,
        isBlockedReason: (_) => false,
        nowUtc: () => DateTime.utc(2026, 4, 6, 20, 3),
      );

      final result = await coordinator.forwardPushQueueToTelegram(
        candidates: <ClientAppPushDeliveryItem>[
          _pushItem(messageKey: 'dispatch-created'),
        ],
        allowPreviouslyDelivered: false,
        defaultClientId: 'CLIENT-MS-VALLEE',
        defaultSiteId: 'SITE-MS-VALLEE-RESIDENCE',
        scopeKeyFor: (clientId, siteId) => '$clientId|$siteId',
        deliveredMessageKeysForScope: (_, _) => <String>{'older-key'},
      );

      expect(result.healthLabel, 'ok');
      expect(
        result.deliveredMessageKeysByScope['CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE'],
        <String>[
          'dispatch-created:telegram:client-chat:11',
          'older-key',
        ],
      );
    });
  });
}

TelegramBridgeResolver _resolver({
  List<TelegramBridgeTarget> clientTargets = const <TelegramBridgeTarget>[
    TelegramBridgeTarget(
      chatId: 'client-chat',
      threadId: 11,
      label: 'Client Lane',
    ),
  ],
}) {
  return _StubTelegramBridgeResolver(clientTargets: clientTargets);
}

ClientAppPushDeliveryItem _pushItem({
  required String messageKey,
  ClientPushDeliveryStatus status = ClientPushDeliveryStatus.queued,
}) {
  return ClientAppPushDeliveryItem(
    messageKey: messageKey,
    title: 'Dispatch created',
    body: 'Response team activated for the selected site.',
    occurredAt: DateTime.utc(2026, 4, 6, 20, 0),
    clientId: 'CLIENT-MS-VALLEE',
    siteId: 'SITE-MS-VALLEE-RESIDENCE',
    targetChannel: ClientAppAcknowledgementChannel.client,
    deliveryProvider: ClientPushDeliveryProvider.telegram,
    priority: true,
    status: status,
  );
}

class _ConfiguredTelegramBridgeStub implements TelegramBridgeService {
  final List<TelegramBridgeMessage> sentMessages = <TelegramBridgeMessage>[];

  @override
  bool get isConfigured => true;

  @override
  Future<bool> answerCallbackQuery({
    required String callbackQueryId,
    String? text,
  }) async {
    return true;
  }

  @override
  Future<List<TelegramBridgeInboundMessage>> fetchUpdates({
    int? offset,
    int limit = 30,
    int timeoutSeconds = 0,
  }) async {
    return const <TelegramBridgeInboundMessage>[];
  }

  @override
  Future<TelegramBridgeSendResult> sendMessages({
    required List<TelegramBridgeMessage> messages,
  }) async {
    sentMessages.addAll(messages);
    return TelegramBridgeSendResult(sent: messages, failed: const []);
  }
}

class _StubTelegramBridgeResolver extends TelegramBridgeResolver {
  _StubTelegramBridgeResolver({
    required List<TelegramBridgeTarget> clientTargets,
  }) : super(
         readManagedTelegramEndpointRecordsForScope:
             ({
               required String clientId,
               required String siteId,
             }) async => clientTargets
                 .map(
                   (target) => ClientTelegramEndpointRecord(
                     endpointId:
                         'endpoint-${target.chatId}-${target.threadId ?? ''}',
                     displayLabel: target.label,
                     chatId: target.chatId,
                     threadId: target.threadId,
                     siteId: siteId,
                   ),
                 )
                 .toList(growable: false),
         isPartnerEndpointLabel: (label) =>
             label.trim().toUpperCase().startsWith('PARTNER'),
         normalizePartnerEndpointLabel: (label) => label,
         resolvedTelegramClientChatId: () => '',
         resolvedTelegramClientThreadId: () => null,
         initialClientLaneClientId: '',
         initialClientLaneSiteId: '',
         resolvedTelegramPartnerChatId: () => '',
         resolvedTelegramPartnerThreadId: () => null,
         resolvedTelegramPartnerClientId: () => '',
         resolvedTelegramPartnerSiteId: () => '',
         telegramPartnerLabelEnv: '',
       );
}
