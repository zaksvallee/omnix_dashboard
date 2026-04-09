import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/client_messaging_bridge_repository.dart';
import 'package:omnix_dashboard/application/telegram_bridge_resolver.dart';

void main() {
  group('TelegramBridgeResolver', () {
    TelegramBridgeResolver buildResolver({
      Future<List<ClientTelegramEndpointRecord>> Function({
        required String clientId,
        required String siteId,
      })?
      readManagedTelegramEndpointRecordsForScope,
      String initialClientLaneClientId = 'CLIENT-MS-VALLEE',
      String initialClientLaneSiteId = 'SITE-MS-VALLEE-RESIDENCE',
      String telegramPartnerLabelEnv = 'response',
      String clientFallbackChatId = 'client-chat',
      int? clientFallbackThreadId,
      String partnerFallbackChatId = 'partner-chat',
      int? partnerFallbackThreadId,
      String partnerFallbackClientId = 'CLIENT-MS-VALLEE',
      String partnerFallbackSiteId = 'SITE-MS-VALLEE-RESIDENCE',
    }) {
      return TelegramBridgeResolver(
        readManagedTelegramEndpointRecordsForScope:
            readManagedTelegramEndpointRecordsForScope ??
            ({required String clientId, required String siteId}) async =>
                const <ClientTelegramEndpointRecord>[],
        isPartnerEndpointLabel: (label) =>
            label.trim().toUpperCase().startsWith('PARTNER'),
        normalizePartnerEndpointLabel: (label) {
          final trimmed = label.trim();
          if (trimmed.isEmpty) {
            return 'PARTNER • Response';
          }
          if (trimmed.toUpperCase().startsWith('PARTNER')) {
            return trimmed;
          }
          return 'PARTNER • $trimmed';
        },
        resolvedTelegramClientChatId: () => clientFallbackChatId,
        resolvedTelegramClientThreadId: () => clientFallbackThreadId,
        initialClientLaneClientId: initialClientLaneClientId,
        initialClientLaneSiteId: initialClientLaneSiteId,
        resolvedTelegramPartnerChatId: () => partnerFallbackChatId,
        resolvedTelegramPartnerThreadId: () => partnerFallbackThreadId,
        resolvedTelegramPartnerClientId: () => partnerFallbackClientId,
        resolvedTelegramPartnerSiteId: () => partnerFallbackSiteId,
        telegramPartnerLabelEnv: telegramPartnerLabelEnv,
      );
    }

    test('resolves client targets from managed endpoint records', () async {
      final resolver = buildResolver(
        readManagedTelegramEndpointRecordsForScope:
            ({required String clientId, required String siteId}) async =>
                const <ClientTelegramEndpointRecord>[
                  ClientTelegramEndpointRecord(
                    endpointId: 'endpoint-client',
                    displayLabel: 'Client Lane',
                    chatId: 'client-managed-chat',
                    threadId: 11,
                    siteId: 'SITE-MS-VALLEE-RESIDENCE',
                  ),
                  ClientTelegramEndpointRecord(
                    endpointId: 'endpoint-partner',
                    displayLabel: 'PARTNER • Response',
                    chatId: 'partner-chat',
                    threadId: 12,
                    siteId: 'SITE-MS-VALLEE-RESIDENCE',
                  ),
                ],
      );

      final targets = await resolver.resolveClientTargets(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
      );

      expect(targets, hasLength(1));
      expect(targets.single.chatId, 'client-managed-chat');
      expect(targets.single.threadId, 11);
      expect(targets.single.label, 'Client Lane');
    });

    test(
      'falls back to configured client env target when directory lookup fails',
      () async {
        final resolver = buildResolver(
          readManagedTelegramEndpointRecordsForScope:
              ({required String clientId, required String siteId}) =>
                  Future<List<ClientTelegramEndpointRecord>>.error(
                    StateError('lookup failed'),
                  ),
          clientFallbackChatId: 'client-env-chat',
          clientFallbackThreadId: 17,
        );

        final targets = await resolver.resolveClientTargets(
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
        );

        expect(targets, hasLength(1));
        expect(targets.single.chatId, 'client-env-chat');
        expect(targets.single.threadId, 17);
        expect(targets.single.label, 'Telegram');
      },
    );

    test(
      'falls back to normalized partner env target when no partner lane exists',
      () async {
        final resolver = buildResolver(
          readManagedTelegramEndpointRecordsForScope:
              ({required String clientId, required String siteId}) async =>
                  const <ClientTelegramEndpointRecord>[
                    ClientTelegramEndpointRecord(
                      endpointId: 'endpoint-client',
                      displayLabel: 'Client Lane',
                      chatId: 'client-chat',
                      threadId: 3,
                      siteId: 'SITE-MS-VALLEE-RESIDENCE',
                    ),
                  ],
          telegramPartnerLabelEnv: 'Field Response',
          partnerFallbackChatId: 'partner-env-chat',
          partnerFallbackThreadId: 19,
        );

        final targets = await resolver.resolvePartnerTargets(
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
        );

        expect(targets, hasLength(1));
        expect(targets.single.chatId, 'partner-env-chat');
        expect(targets.single.threadId, 19);
        expect(targets.single.label, 'PARTNER • Field Response');
      },
    );
  });
}
