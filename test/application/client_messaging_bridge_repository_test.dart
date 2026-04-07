import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/client_messaging_bridge_repository.dart';

void main() {
  group('expandActiveTelegramScopeTargets', () {
    test('includes direct site-scoped endpoints and expands global endpoints to active sites', () {
      final scopes = expandActiveTelegramScopeTargets(
        endpointRows: <Map<String, dynamic>>[
          <String, dynamic>{'client_id': 'CLIENT-1', 'site_id': 'SITE-1'},
          <String, dynamic>{'client_id': 'CLIENT-2', 'site_id': ''},
        ],
        siteRows: <Map<String, dynamic>>[
          <String, dynamic>{'client_id': 'CLIENT-2', 'site_id': 'SITE-2A'},
          <String, dynamic>{'client_id': 'CLIENT-2', 'site_id': 'SITE-2B'},
          <String, dynamic>{'client_id': 'CLIENT-3', 'site_id': 'SITE-3A'},
        ],
      );

      expect(
        scopes
            .map((scope) => '${scope.clientId}|${scope.siteId}')
            .toList(growable: false),
        <String>[
          'CLIENT-1|SITE-1',
          'CLIENT-2|SITE-2A',
          'CLIENT-2|SITE-2B',
        ],
      );
    });

    test('dedupes overlapping direct and expanded scopes', () {
      final scopes = expandActiveTelegramScopeTargets(
        endpointRows: <Map<String, dynamic>>[
          <String, dynamic>{'client_id': 'CLIENT-1', 'site_id': ''},
          <String, dynamic>{'client_id': 'CLIENT-1', 'site_id': 'SITE-1'},
        ],
        siteRows: <Map<String, dynamic>>[
          <String, dynamic>{'client_id': 'CLIENT-1', 'site_id': 'SITE-1'},
          <String, dynamic>{'client_id': 'CLIENT-1', 'site_id': 'SITE-2'},
        ],
      );

      expect(
        scopes
            .map((scope) => '${scope.clientId}|${scope.siteId}')
            .toList(growable: false),
        <String>[
          'CLIENT-1|SITE-1',
          'CLIENT-1|SITE-2',
        ],
      );
    });
  });

  group('selectTelegramTargetsForLane', () {
    bool isPartnerLabel(String label) =>
        label.toLowerCase().contains('partner');

    test('prefers scoped records for the selected lane before falling back to global', () {
      final clientTargets = selectTelegramTargetsForLane(
        records: const <ClientTelegramEndpointRecord>[
          ClientTelegramEndpointRecord(
            endpointId: 'global-client',
            displayLabel: 'Primary Telegram Bridge',
            chatId: 'chat-global',
            threadId: 1,
            siteId: null,
          ),
          ClientTelegramEndpointRecord(
            endpointId: 'scoped-partner',
            displayLabel: 'Partner Telegram',
            chatId: 'chat-scoped-partner',
            threadId: 2,
            siteId: 'SITE-001',
          ),
        ],
        partnerTargets: false,
        isPartnerLabel: isPartnerLabel,
      );

      expect(
        clientTargets.map((target) => target.endpointId).toList(),
        <String>['global-client'],
      );
    });

    test('dedupes after lane filtering so partner and client rows can share a chat', () {
      final clientTargets = selectTelegramTargetsForLane(
        records: const <ClientTelegramEndpointRecord>[
          ClientTelegramEndpointRecord(
            endpointId: 'partner-endpoint',
            displayLabel: 'Partner Telegram',
            chatId: 'chat-1',
            threadId: 7,
            siteId: 'SITE-001',
          ),
          ClientTelegramEndpointRecord(
            endpointId: 'client-endpoint',
            displayLabel: 'Primary Telegram Bridge',
            chatId: 'chat-1',
            threadId: 7,
            siteId: 'SITE-001',
          ),
        ],
        partnerTargets: false,
        isPartnerLabel: isPartnerLabel,
      );

      final partnerTargets = selectTelegramTargetsForLane(
        records: const <ClientTelegramEndpointRecord>[
          ClientTelegramEndpointRecord(
            endpointId: 'partner-endpoint',
            displayLabel: 'Partner Telegram',
            chatId: 'chat-1',
            threadId: 7,
            siteId: 'SITE-001',
          ),
          ClientTelegramEndpointRecord(
            endpointId: 'client-endpoint',
            displayLabel: 'Primary Telegram Bridge',
            chatId: 'chat-1',
            threadId: 7,
            siteId: 'SITE-001',
          ),
        ],
        partnerTargets: true,
        isPartnerLabel: isPartnerLabel,
      );

      expect(
        clientTargets.map((target) => target.endpointId).toList(),
        <String>['client-endpoint'],
      );
      expect(
        partnerTargets.map((target) => target.endpointId).toList(),
        <String>['partner-endpoint'],
      );
    });
  });

  group('selectActiveTelegramEndpointRowsForScope', () {
    test('prefers scoped endpoint rows over global rows for site-scoped reads', () {
      final rows = selectActiveTelegramEndpointRowsForScope(
        rows: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'endpoint-global',
            'site_id': '',
            'display_label': 'Global Telegram',
            'telegram_chat_id': 'chat-global',
            'telegram_thread_id': '1',
          },
          <String, dynamic>{
            'id': 'endpoint-site',
            'site_id': 'SITE-001',
            'display_label': 'Site Telegram',
            'telegram_chat_id': 'chat-site',
            'telegram_thread_id': '2',
          },
        ],
        siteId: 'SITE-001',
      );

      expect(rows.map((row) => row['id']).toList(), <Object?>['endpoint-site']);
    });

    test('falls back to global rows when no scoped endpoint rows exist', () {
      final rows = selectActiveTelegramEndpointRowsForScope(
        rows: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'endpoint-global',
            'site_id': '',
            'display_label': 'Global Telegram',
            'telegram_chat_id': 'chat-global',
            'telegram_thread_id': '1',
          },
          <String, dynamic>{
            'id': 'endpoint-other-site',
            'site_id': 'SITE-002',
            'display_label': 'Other Site Telegram',
            'telegram_chat_id': 'chat-other',
            'telegram_thread_id': '3',
          },
        ],
        siteId: 'SITE-001',
      );

      expect(rows.map((row) => row['id']).toList(), <Object?>['endpoint-global']);
    });

    test('client-wide reads ignore site-specific endpoint rows', () {
      final rows = selectActiveTelegramEndpointRowsForScope(
        rows: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'endpoint-global',
            'site_id': '',
            'display_label': 'Global Telegram',
            'telegram_chat_id': 'chat-global',
            'telegram_thread_id': '1',
          },
          <String, dynamic>{
            'id': 'endpoint-site',
            'site_id': 'SITE-001',
            'display_label': 'Site Telegram',
            'telegram_chat_id': 'chat-site',
            'telegram_thread_id': '2',
          },
        ],
        siteId: null,
      );

      expect(rows.map((row) => row['id']).toList(), <Object?>['endpoint-global']);
    });
  });

  group('selectManagedTelegramEndpointRowsForScope', () {
    test('includes both scoped and global rows for site-scoped management reads', () {
      final rows = selectManagedTelegramEndpointRowsForScope(
        rows: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'endpoint-global',
            'site_id': '',
            'display_label': 'Global Telegram',
            'telegram_chat_id': 'chat-global',
            'telegram_thread_id': '1',
          },
          <String, dynamic>{
            'id': 'endpoint-site',
            'site_id': 'SITE-001',
            'display_label': 'Site Telegram',
            'telegram_chat_id': 'chat-site',
            'telegram_thread_id': '2',
          },
          <String, dynamic>{
            'id': 'endpoint-other-site',
            'site_id': 'SITE-002',
            'display_label': 'Other Site Telegram',
            'telegram_chat_id': 'chat-other',
            'telegram_thread_id': '3',
          },
        ],
        siteId: 'SITE-001',
      );

      expect(rows.map((row) => row['id']).toList(), <Object?>[
        'endpoint-global',
        'endpoint-site',
      ]);
    });

    test('client-wide management reads still ignore site-specific rows', () {
      final rows = selectManagedTelegramEndpointRowsForScope(
        rows: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'endpoint-global',
            'site_id': '',
            'display_label': 'Global Telegram',
            'telegram_chat_id': 'chat-global',
            'telegram_thread_id': '1',
          },
          <String, dynamic>{
            'id': 'endpoint-site',
            'site_id': 'SITE-001',
            'display_label': 'Site Telegram',
            'telegram_chat_id': 'chat-site',
            'telegram_thread_id': '2',
          },
        ],
        siteId: null,
      );

      expect(rows.map((row) => row['id']).toList(), <Object?>['endpoint-global']);
    });
  });

  group('selectActiveContactPhonesForScope', () {
    test('prefers scoped primary client contacts over non-primary rows', () {
      final phones = selectActiveContactPhonesForScope(
        rows: <Map<String, dynamic>>[
          <String, dynamic>{
            'site_id': 'SITE-001',
            'phone': '+27110000001',
            'role': 'sovereign_contact',
            'is_primary': false,
          },
          <String, dynamic>{
            'site_id': 'SITE-001',
            'phone': '+27110000002',
            'role': 'sovereign_contact',
            'is_primary': true,
          },
        ],
        siteId: 'SITE-001',
      );

      expect(phones, <String>['+27110000002']);
    });

    test('prefers scoped primary contacts over global primary contacts', () {
      final phones = selectActiveContactPhonesForScope(
        rows: <Map<String, dynamic>>[
          <String, dynamic>{
            'site_id': '',
            'phone': '+27110000001',
            'role': 'sovereign_contact',
            'is_primary': true,
          },
          <String, dynamic>{
            'site_id': 'SITE-001',
            'phone': '+27110000002',
            'role': 'sovereign_contact',
            'is_primary': true,
          },
        ],
        siteId: 'SITE-001',
      );

      expect(phones, <String>['+27110000002']);
    });

    test('falls back to global primary contacts when no scoped contact exists', () {
      final phones = selectActiveContactPhonesForScope(
        rows: <Map<String, dynamic>>[
          <String, dynamic>{
            'site_id': '',
            'phone': '+27110000001',
            'role': 'sovereign_contact',
            'is_primary': true,
          },
          <String, dynamic>{
            'site_id': 'SITE-002',
            'phone': '+27110000002',
            'role': 'sovereign_contact',
            'is_primary': true,
          },
        ],
        siteId: 'SITE-001',
      );

      expect(phones, <String>['+27110000001']);
    });

    test('client-wide scope ignores site-specific contact phones', () {
      final phones = selectActiveContactPhonesForScope(
        rows: <Map<String, dynamic>>[
          <String, dynamic>{
            'site_id': '',
            'phone': '+27110000001',
            'role': 'sovereign_contact',
            'is_primary': false,
          },
          <String, dynamic>{
            'site_id': 'SITE-001',
            'phone': '+27110000002',
            'role': 'sovereign_contact',
            'is_primary': true,
          },
        ],
        siteId: null,
      );

      expect(phones, <String>['+27110000001']);
    });

    test('excludes response partner contacts from client fallback phones', () {
      final phones = selectActiveContactPhonesForScope(
        rows: <Map<String, dynamic>>[
          <String, dynamic>{
            'site_id': 'SITE-001',
            'phone': '+27110000001',
            'role': 'response_partner',
            'is_primary': true,
          },
          <String, dynamic>{
            'site_id': 'SITE-001',
            'phone': '+27110000002',
            'role': 'sovereign_contact',
            'is_primary': false,
          },
        ],
        siteId: 'SITE-001',
      );

      expect(phones, <String>['+27110000002']);
    });
  });

  group('primaryContactIdsToDemoteForUpsert', () {
    test('returns older same-role primaries in the same scope', () {
      final ids = primaryContactIdsToDemoteForUpsert(
        rows: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'contact-1',
            'site_id': 'SITE-001',
            'role': 'sovereign_contact',
            'is_primary': true,
          },
          <String, dynamic>{
            'id': 'contact-2',
            'site_id': 'SITE-001',
            'role': 'sovereign_contact',
            'is_primary': true,
          },
          <String, dynamic>{
            'id': 'contact-3',
            'site_id': 'SITE-001',
            'role': 'response_partner',
            'is_primary': true,
          },
        ],
        siteId: 'SITE-001',
        contactRole: 'sovereign_contact',
        keepContactId: 'contact-2',
      );

      expect(ids, <String>['contact-1']);
    });
  });

  group('resolvedContactConsentAtForUpsert', () {
    test('preserves an existing consent timestamp when later saves are unchecked', () {
      final resolved = resolvedContactConsentAtForUpsert(
        existingRow: <String, dynamic>{'consent_at': '2026-03-01T10:15:00.000Z'},
        contactConsentConfirmed: false,
        nowUtc: DateTime.utc(2026, 4, 5, 12, 0),
      );

      expect(resolved, '2026-03-01T10:15:00.000Z');
    });

    test('writes a fresh consent timestamp when consent is confirmed', () {
      final resolved = resolvedContactConsentAtForUpsert(
        existingRow: <String, dynamic>{'consent_at': '2026-03-01T10:15:00.000Z'},
        contactConsentConfirmed: true,
        nowUtc: DateTime.utc(2026, 4, 5, 12, 0),
      );

      expect(resolved, '2026-04-05T12:00:00.000Z');
    });

    test('keeps consent empty when nothing has been captured yet', () {
      final resolved = resolvedContactConsentAtForUpsert(
        existingRow: const <String, dynamic>{},
        contactConsentConfirmed: false,
        nowUtc: DateTime.utc(2026, 4, 5, 12, 0),
      );

      expect(resolved, isNull);
    });
  });

  group('staleSubscriptionPairsToDeactivateForUpsert', () {
    test('deactivates older active subscription pairs for the same scope provider and role', () {
      final stalePairs = staleSubscriptionPairsToDeactivateForUpsert(
        subscriptionRows: <Map<String, dynamic>>[
          <String, dynamic>{
            'contact_id': 'contact-1',
            'endpoint_id': 'endpoint-1',
            'site_id': 'SITE-001',
            'is_active': true,
          },
          <String, dynamic>{
            'contact_id': 'contact-2',
            'endpoint_id': 'endpoint-2',
            'site_id': 'SITE-001',
            'is_active': true,
          },
        ],
        contactRows: <Map<String, dynamic>>[
          <String, dynamic>{'id': 'contact-1', 'role': 'sovereign_contact'},
          <String, dynamic>{'id': 'contact-2', 'role': 'sovereign_contact'},
        ],
        endpointRows: <Map<String, dynamic>>[
          <String, dynamic>{'id': 'endpoint-1', 'provider': 'telegram'},
          <String, dynamic>{'id': 'endpoint-2', 'provider': 'telegram'},
        ],
        siteId: 'SITE-001',
        provider: 'telegram',
        contactRole: 'sovereign_contact',
        keepContactId: 'contact-2',
        keepEndpointId: 'endpoint-2',
      );

      expect(stalePairs, <Map<String, String>>[
        <String, String>{
          'contact_id': 'contact-1',
          'endpoint_id': 'endpoint-1',
        },
      ]);
    });

    test('keeps other scopes providers and roles active', () {
      final stalePairs = staleSubscriptionPairsToDeactivateForUpsert(
        subscriptionRows: <Map<String, dynamic>>[
          <String, dynamic>{
            'contact_id': 'contact-1',
            'endpoint_id': 'endpoint-1',
            'site_id': 'SITE-001',
            'is_active': true,
          },
          <String, dynamic>{
            'contact_id': 'contact-3',
            'endpoint_id': 'endpoint-3',
            'site_id': 'SITE-001',
            'is_active': true,
          },
          <String, dynamic>{
            'contact_id': 'contact-4',
            'endpoint_id': 'endpoint-4',
            'site_id': 'SITE-002',
            'is_active': true,
          },
          <String, dynamic>{
            'contact_id': 'contact-5',
            'endpoint_id': 'endpoint-5',
            'site_id': 'SITE-001',
            'is_active': false,
          },
        ],
        contactRows: <Map<String, dynamic>>[
          <String, dynamic>{'id': 'contact-1', 'role': 'sovereign_contact'},
          <String, dynamic>{'id': 'contact-2', 'role': 'sovereign_contact'},
          <String, dynamic>{'id': 'contact-3', 'role': 'response_partner'},
          <String, dynamic>{'id': 'contact-4', 'role': 'sovereign_contact'},
          <String, dynamic>{'id': 'contact-5', 'role': 'sovereign_contact'},
        ],
        endpointRows: <Map<String, dynamic>>[
          <String, dynamic>{'id': 'endpoint-1', 'provider': 'telegram'},
          <String, dynamic>{'id': 'endpoint-2', 'provider': 'telegram'},
          <String, dynamic>{'id': 'endpoint-3', 'provider': 'telegram'},
          <String, dynamic>{'id': 'endpoint-4', 'provider': 'telegram'},
          <String, dynamic>{'id': 'endpoint-5', 'provider': 'telegram'},
          <String, dynamic>{'id': 'endpoint-6', 'provider': 'in_app'},
        ],
        siteId: 'SITE-001',
        provider: 'telegram',
        contactRole: 'sovereign_contact',
        keepContactId: 'contact-2',
        keepEndpointId: 'endpoint-2',
      );

      expect(stalePairs, <Map<String, String>>[
        <String, String>{
          'contact_id': 'contact-1',
          'endpoint_id': 'endpoint-1',
        },
      ]);
    });
  });

  group('activeSubscriptionPairsForEndpointIds', () {
    test('returns only active pairs for the targeted endpoints', () {
      final activePairs = activeSubscriptionPairsForEndpointIds(
        subscriptionRows: <Map<String, dynamic>>[
          <String, dynamic>{
            'contact_id': 'contact-1',
            'endpoint_id': 'endpoint-1',
            'is_active': true,
          },
          <String, dynamic>{
            'contact_id': 'contact-2',
            'endpoint_id': 'endpoint-2',
            'is_active': false,
          },
          <String, dynamic>{
            'contact_id': 'contact-3',
            'endpoint_id': 'endpoint-3',
            'is_active': true,
          },
        ],
        endpointIds: <String>['endpoint-1', 'endpoint-2'],
      );

      expect(activePairs, <Map<String, String>>[
        <String, String>{
          'contact_id': 'contact-1',
          'endpoint_id': 'endpoint-1',
        },
      ]);
    });
  });

  group('findExistingEndpointRowForUpsert', () {
    test('matches telegram rows by chat and thread within the same scope', () {
      final existing = findExistingEndpointRowForUpsert(
        rows: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'endpoint-1',
            'site_id': 'SITE-001',
            'provider': 'telegram',
            'telegram_chat_id': 'chat-1',
            'telegram_thread_id': '10',
          },
          <String, dynamic>{
            'id': 'endpoint-2',
            'site_id': 'SITE-001',
            'provider': 'telegram',
            'telegram_chat_id': 'chat-1',
            'telegram_thread_id': '20',
          },
        ],
        siteId: 'SITE-001',
        provider: 'telegram',
        telegramChatId: 'chat-1',
        telegramThreadId: '20',
      );

      expect(existing?['id'], 'endpoint-2');
    });

    test('does not treat a different telegram thread as the same endpoint', () {
      final existing = findExistingEndpointRowForUpsert(
        rows: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'endpoint-1',
            'site_id': 'SITE-001',
            'provider': 'telegram',
            'telegram_chat_id': 'chat-1',
            'telegram_thread_id': '10',
          },
        ],
        siteId: 'SITE-001',
        provider: 'telegram',
        telegramChatId: 'chat-1',
        telegramThreadId: '20',
      );

      expect(existing, isNull);
    });

    test('matches non-telegram rows by scope and provider', () {
      final existing = findExistingEndpointRowForUpsert(
        rows: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'endpoint-1',
            'site_id': 'SITE-001',
            'provider': 'in_app',
            'telegram_chat_id': null,
            'telegram_thread_id': null,
          },
        ],
        siteId: 'SITE-001',
        provider: 'in_app',
      );

      expect(existing?['id'], 'endpoint-1');
    });
  });
}
