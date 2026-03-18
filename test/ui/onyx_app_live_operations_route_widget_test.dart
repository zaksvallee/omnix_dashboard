import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnix_dashboard/application/client_conversation_repository.dart';
import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/application/sms_delivery_service.dart';
import 'package:omnix_dashboard/application/telegram_bridge_service.dart';
import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/admin_page.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/client_app_page.dart';

class _ConfiguredTelegramBridgeStub implements TelegramBridgeService {
  const _ConfiguredTelegramBridgeStub();

  @override
  bool get isConfigured => true;

  @override
  Future<bool> answerCallbackQuery({
    required String callbackQueryId,
    String? text,
  }) async {
    return false;
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
    return TelegramBridgeSendResult(
      sent: const [],
      failed: messages,
      failureReasonsByMessageKey: {
        for (final message in messages)
          message.messageKey: 'BLOCKED_BY_TEST_STUB',
      },
    );
  }
}

class _SuccessfulTelegramBridgeStub implements TelegramBridgeService {
  const _SuccessfulTelegramBridgeStub();

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
    return TelegramBridgeSendResult(
      sent: messages,
      failed: const [],
      telegramMessageIdsByMessageKey: {
        for (final message in messages) message.messageKey: 9001,
      },
    );
  }
}

class _SuccessfulSmsDeliveryStub implements SmsDeliveryService {
  const _SuccessfulSmsDeliveryStub();

  @override
  bool get isConfigured => true;

  @override
  String get providerLabel => 'sms:bulksms';

  @override
  Future<SmsDeliverySendResult> sendMessages({
    required List<SmsDeliveryMessage> messages,
  }) async {
    return SmsDeliverySendResult(sent: messages, failed: const []);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'onyx app opens client lane from live operations without invalid room state',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? openedClientId;
      String? openedSiteId;
      String? openedRoom;

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          onClientLaneRouteOpened: (clientId, siteId, room) {
            openedClientId = clientId;
            openedSiteId = siteId;
            openedRoom = room;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT LANE WATCH'), findsOneWidget);

      await tester.tap(find.text('Open Client Lane').first);
      await tester.pumpAndSettle();

      expect(openedClientId, 'CLIENT-MS-VALLEE');
      expect(openedSiteId, 'SITE-MS-VALLEE-RESIDENCE');
      expect(openedRoom, isEmpty);
      expect(find.textContaining('Client Operations'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app restores selected-lane sms fallback into live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final conversation = SharedPrefsClientConversationRepository(persistence);
      final nowUtc = DateTime.utc(2026, 3, 18, 12, 50);
      await conversation.savePushQueue(<ClientAppPushDeliveryItem>[
        ClientAppPushDeliveryItem(
          messageKey: 'test-live-ops-sms-fallback-1',
          title: 'Delivery check',
          body: 'This is a queued client delivery check.',
          occurredAt: nowUtc,
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          targetChannel: ClientAppAcknowledgementChannel.client,
          deliveryProvider: ClientPushDeliveryProvider.inApp,
          priority: true,
          status: ClientPushDeliveryStatus.queued,
        ),
      ]);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          telegramBridgeServiceOverride: const _ConfiguredTelegramBridgeStub(),
          smsDeliveryServiceOverride: const _SuccessfulSmsDeliveryStub(),
          activeContactPhonesResolverOverride: (clientId, siteId) async =>
              const <String>['+27825550441', '+27834440442'],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('clients-retry-push-sync-action')),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT LANE WATCH'), findsOneWidget);
      expect(find.text('Latest SMS fallback'), findsWidgets);
      expect(
        find.textContaining(
          'BulkSMS reached 2/2 contacts after telegram target failure.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app restores selected-lane voip history into live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final conversation = SharedPrefsClientConversationRepository(persistence);
      final occurredAtUtc = DateTime.utc(2026, 3, 18, 12, 55);
      await conversation.savePushSyncState(
        ClientPushSyncState(
          statusLabel: 'degraded',
          lastSyncedAtUtc: occurredAtUtc,
          failureReason: 'voip:asterisk staged call for Vallee command desk.',
          retryCount: 0,
          history: <ClientPushSyncAttempt>[
            ClientPushSyncAttempt(
              occurredAt: occurredAtUtc,
              status: 'voip-staged',
              failureReason: 'voip:asterisk staged call for Vallee command desk.',
              queueSize: 1,
            ),
          ],
          backendProbeStatusLabel: 'idle',
          backendProbeHistory: const <ClientBackendProbeAttempt>[],
        ),
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-voip-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT LANE WATCH'), findsOneWidget);
      expect(find.text('Latest VoIP stage'), findsWidgets);
      expect(
        find.textContaining('Asterisk staged a call for Vallee command desk.'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app keeps guard voip staging isolated from unrelated live operations lanes after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-guard-voip-source-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.guards,
        ),
      );
      await tester.pumpAndSettle();

      final callButton = find.widgetWithText(OutlinedButton, 'Call').first;
      await tester.ensureVisible(callButton);
      await tester.tap(callButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stage VoIP Call'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-guard-voip-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT LANE WATCH'), findsOneWidget);
      expect(find.text('Latest VoIP stage'), findsNothing);
      expect(
        find.textContaining(
          'VoIP staging is not configured for Thabo Mokoena yet.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'onyx app restores selected-lane learned approval style into live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTelegramAdminRuntimeState({
        'ai_approved_rewrite_examples_by_scope': {
          'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE': <String>[
            'Control is checking the latest position now and will share the next confirmed step shortly.',
          ],
        },
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-learned-style-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT LANE WATCH'), findsOneWidget);
      expect(find.text('Learned style 1'), findsWidgets);
      expect(find.text('Learned approval style'), findsWidgets);
      expect(
        find.textContaining(
          'Control is checking the latest position now and will share the next confirmed step shortly.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app restores selected-lane pinned voice into live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTelegramAdminRuntimeState({
        'ai_client_profile_overrides': {
          'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE': 'reassurance-forward',
        },
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-voice-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT LANE WATCH'), findsOneWidget);
      expect(find.text('Lane voice Reassuring'), findsWidgets);
      expect(find.text('Clear Learned Style'), findsNothing);
    },
  );

  testWidgets(
    'onyx app restores selected-lane pending ai draft into live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTelegramAdminRuntimeState({
        'ai_pending_drafts': <Map<String, Object?>>[
          {
            'inbound_update_id': 501,
            'chat_id': '123456',
            'message_thread_id': 88,
            'audience': 'client',
            'client_id': 'CLIENT-MS-VALLEE',
            'site_id': 'SITE-MS-VALLEE-RESIDENCE',
            'source_text': 'Hi ONYX, are we still waiting on the patrol update?',
            'original_draft_text':
                'We are checking the latest patrol position now and will send the next verified update shortly.',
            'draft_text':
                'We are checking the latest patrol position now and will send the next verified update shortly.',
            'provider_label': 'OpenAI',
            'used_learned_approval_style': true,
            'created_at_utc': DateTime.utc(2026, 3, 18, 12, 40)
                .toIso8601String(),
          },
        ],
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-pending-draft-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT LANE WATCH'), findsOneWidget);
      expect(find.text('Pending ONYX Draft'), findsOneWidget);
      expect(
        find.textContaining(
          'We are checking the latest patrol position now and will send the next verified update shortly.',
        ),
        findsWidgets,
      );
      expect(find.text('ONYX using learned style'), findsWidgets);
    },
  );

  testWidgets(
    'onyx app keeps unrelated pending drafts out of the selected lane while surfacing them in the control inbox',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTelegramAdminRuntimeState({
        'ai_pending_drafts': <Map<String, Object?>>[
          {
            'inbound_update_id': 507,
            'chat_id': '123456',
            'message_thread_id': 91,
            'audience': 'client',
            'client_id': 'CLIENT-MS-VALLEE',
            'site_id': 'WTF-MAIN',
            'source_text':
                'Please confirm if the Waterfall response team has already arrived.',
            'original_draft_text':
                'We are checking the latest Waterfall position now and will send the next verified update shortly.',
            'draft_text':
                'Control is checking the latest Waterfall position now and will share the next confirmed step shortly.',
            'provider_label': 'OpenAI',
            'used_learned_approval_style': false,
            'created_at_utc': DateTime.utc(2026, 3, 18, 12, 41)
                .toIso8601String(),
          },
        ],
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-other-scope-draft-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending ONYX Draft'), findsNothing);

      await tester.scrollUntilVisible(
        find.textContaining('Waterfall response team has already arrived'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('CONTROL INBOX'), findsOneWidget);
      expect(
        find.textContaining('Waterfall response team has already arrived'),
        findsOneWidget,
      );
      expect(find.text('Other scope'), findsWidgets);
    },
  );

  testWidgets(
    'onyx app opens the exact off-scope lane from the live operations control inbox',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTelegramAdminRuntimeState({
        'ai_pending_drafts': <Map<String, Object?>>[
          {
            'inbound_update_id': 508,
            'chat_id': '123456',
            'message_thread_id': 92,
            'audience': 'client',
            'client_id': 'CLIENT-MS-VALLEE',
            'site_id': 'WTF-MAIN',
            'source_text':
                'Please confirm if the Waterfall response team has already arrived.',
            'original_draft_text':
                'Control is checking the latest Waterfall position now and will share the next confirmed step shortly.',
            'draft_text':
                'Control is checking the latest Waterfall position now and will share the next confirmed step shortly.',
            'provider_label': 'OpenAI',
            'used_learned_approval_style': false,
            'created_at_utc': DateTime.utc(2026, 3, 18, 12, 42)
                .toIso8601String(),
          },
        ],
      });

      String? openedClientId;
      String? openedSiteId;
      String? openedRoom;

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-open-other-scope-draft-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
          onClientLaneRouteOpened: (clientId, siteId, room) {
            openedClientId = clientId;
            openedSiteId = siteId;
            openedRoom = room;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('control-inbox-draft-508')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final otherDraft = find.byKey(const ValueKey('control-inbox-draft-508'));
      await tester.tap(
        find.descendant(
          of: otherDraft,
          matching: find.widgetWithText(OutlinedButton, 'Open Client Lane'),
        ),
      );
      await tester.pumpAndSettle();

      expect(openedClientId, 'CLIENT-MS-VALLEE');
      expect(openedSiteId, 'WTF-MAIN');
      expect(openedRoom, isEmpty);
      expect(find.textContaining('Client Operations'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app surfaces off-scope live client asks and opens the exact lane from shape reply',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final scopedConversation = ScopedSharedPrefsClientConversationRepository(
        persistence: persistence,
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );
      await scopedConversation.saveMessages(<ClientAppMessage>[
        ClientAppMessage(
          author: '@waterfall_resident',
          body:
              'Please confirm whether the Waterfall response team has already arrived.',
          occurredAt: DateTime.utc(2026, 3, 18, 12, 43),
          roomKey: 'Residents',
          viewerRole: ClientAppViewerRole.client.name,
          incidentStatusLabel: 'Update',
          messageSource: 'telegram',
          messageProvider: 'telegram',
        ),
      ]);

      String? openedClientId;
      String? openedSiteId;
      String? openedRoom;

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-other-scope-ask-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
          onClientLaneRouteOpened: (clientId, siteId, room) {
            openedClientId = clientId;
            openedSiteId = siteId;
            openedRoom = room;
          },
        ),
      );
      await tester.pumpAndSettle();

      final otherAsk = find.byKey(
        const ValueKey(
          'control-inbox-ask-CLIENT-MS-VALLEE-WTF-MAIN-2026-03-18T12:43:00.000Z',
        ),
      );
      await tester.scrollUntilVisible(
        otherAsk,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('LIVE CLIENT ASKS'), findsOneWidget);
      expect(find.text('Other scope'), findsWidgets);

      await tester.tap(
        find.descendant(
          of: otherAsk,
          matching: find.widgetWithText(OutlinedButton, 'Shape Reply'),
        ),
      );
      await tester.pumpAndSettle();

      expect(openedClientId, 'CLIENT-MS-VALLEE');
      expect(openedSiteId, 'WTF-MAIN');
      expect(openedRoom, isEmpty);
      expect(find.textContaining('Client Operations'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app carries off-scope live client asks from admin audit into live operations inbox after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final scopedConversation = ScopedSharedPrefsClientConversationRepository(
        persistence: persistence,
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );
      await scopedConversation.saveMessages(<ClientAppMessage>[
        ClientAppMessage(
          author: '@waterfall_resident',
          body:
              'Please confirm whether the Waterfall response team has already arrived.',
          occurredAt: DateTime.utc(2026, 3, 18, 12, 43),
          roomKey: 'Residents',
          viewerRole: ClientAppViewerRole.client.name,
          incidentStatusLabel: 'Update',
          messageSource: 'telegram',
          messageProvider: 'telegram',
        ),
      ]);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-off-scope-live-ask-source-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('System').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('LATEST CLIENT ASK'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Client Comms Audit'), findsOneWidget);
      expect(find.text('Cross-scope'), findsWidgets);
      expect(find.text('LATEST CLIENT ASK'), findsOneWidget);
      expect(
        find.textContaining(
          'Please confirm whether the Waterfall response team has already arrived.',
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-off-scope-live-ask-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(
          const ValueKey(
            'control-inbox-ask-CLIENT-MS-VALLEE-WTF-MAIN-2026-03-18T12:43:00.000Z',
          ),
        ),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('CONTROL INBOX'), findsOneWidget);
      expect(find.text('LIVE CLIENT ASKS'), findsOneWidget);
      expect(find.text('Other scope'), findsWidgets);
      expect(
        find.textContaining(
          'Please confirm whether the Waterfall response team has already arrived.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx app persists rejected pending ai draft clearing from live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTelegramAdminRuntimeState({
        'ai_pending_drafts': <Map<String, Object?>>[
          {
            'inbound_update_id': 601,
            'chat_id': '123456',
            'message_thread_id': 88,
            'audience': 'client',
            'client_id': 'CLIENT-MS-VALLEE',
            'site_id': 'SITE-MS-VALLEE-RESIDENCE',
            'source_text': 'Hi ONYX, are we still waiting on the patrol update?',
            'original_draft_text':
                'We are checking the latest patrol position now and will send the next verified update shortly.',
            'draft_text':
                'We are checking the latest patrol position now and will send the next verified update shortly.',
            'provider_label': 'OpenAI',
            'used_learned_approval_style': false,
            'created_at_utc': DateTime.utc(2026, 3, 18, 12, 41)
                .toIso8601String(),
          },
        ],
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-reject-draft-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending ONYX Draft'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Reject').first);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-reject-draft-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending ONYX Draft'), findsNothing);
      expect(
        find.textContaining(
          'We are checking the latest patrol position now and will send the next verified update shortly.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'onyx app persists approved pending ai draft learning from live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTelegramAdminRuntimeState({
        'ai_pending_drafts': <Map<String, Object?>>[
          {
            'inbound_update_id': 701,
            'chat_id': '123456',
            'message_thread_id': 88,
            'audience': 'client',
            'client_id': 'CLIENT-MS-VALLEE',
            'site_id': 'SITE-MS-VALLEE-RESIDENCE',
            'source_text': 'Please update me on the patrol position.',
            'original_draft_text':
                'We are checking the latest patrol position now and will send the next verified update shortly.',
            'draft_text':
                'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
            'provider_label': 'OpenAI',
            'used_learned_approval_style': false,
            'created_at_utc': DateTime.utc(2026, 3, 18, 12, 42)
                .toIso8601String(),
          },
        ],
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-approve-draft-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
          telegramBridgeServiceOverride: const _SuccessfulTelegramBridgeStub(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending ONYX Draft'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Approve + Send').first);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-approve-draft-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending ONYX Draft'), findsNothing);
      expect(find.text('Learned style 1'), findsWidgets);
      expect(find.text('Learned approval style'), findsWidgets);
      expect(
        find.textContaining(
          'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app shows client-lane learned approval memory in live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveClientAppDraft(
        const ClientAppDraft(
          viewerRole: ClientAppViewerRole.control,
          selectedRoom: 'Residents',
          selectedRoomByRole: <String, String>{
            'client': 'Residents',
            'control': 'Residents',
            'resident': 'Residents',
          },
          showAllRoomItemsByRole: <String, bool>{
            'client': false,
            'control': false,
            'resident': false,
          },
        ),
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-cross-surface-learn-clients-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      final controlViewChip = find.text('Control View');
      if (controlViewChip.evaluate().isNotEmpty) {
        await tester.ensureVisible(controlViewChip.first);
        await tester.tap(controlViewChip.first);
        await tester.pumpAndSettle();
      }

      final reviewButton = find.textContaining(
        'Review dispatch draft for Resident Feed',
      );
      await tester.ensureVisible(reviewButton.first);
      await tester.tap(reviewButton.first);
      await tester.pumpAndSettle();

      const approvedDraftText =
          'Control is checking the dispatch response for Resident Feed now and will share the next confirmed step shortly.';
      await tester.enterText(find.byType(TextField).first, approvedDraftText);
      await tester.pumpAndSettle();

      final sendReviewedDraftButton = find.widgetWithText(
        FilledButton,
        'Log Dispatch Review for Resident Feed',
      );
      await tester.ensureVisible(sendReviewedDraftButton);
      await tester.tap(sendReviewedDraftButton);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-cross-surface-learn-dashboard-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Learned style 1'), findsWidgets);
      expect(find.text('Learned approval style'), findsWidgets);
      expect(find.textContaining(approvedDraftText), findsWidgets);
    },
  );

  testWidgets(
    'onyx app shows off-scope client-lane learned approval style in live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveClientAppDraft(
        const ClientAppDraft(
          viewerRole: ClientAppViewerRole.control,
          selectedRoom: 'Residents',
          selectedRoomByRole: <String, String>{
            'client': 'Residents',
            'control': 'Residents',
            'resident': 'Residents',
          },
          showAllRoomItemsByRole: <String, bool>{
            'client': false,
            'control': false,
            'resident': false,
          },
        ),
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-offscope-cross-surface-learn-clients-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-MS-VALLEE',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      final controlViewChip = find.text('Control View');
      if (controlViewChip.evaluate().isNotEmpty) {
        await tester.ensureVisible(controlViewChip.first);
        await tester.tap(controlViewChip.first);
        await tester.pumpAndSettle();
      }

      final reviewButton = find.textContaining(
        'Review dispatch draft for Resident Feed',
      );
      await tester.ensureVisible(reviewButton.first);
      await tester.tap(reviewButton.first);
      await tester.pumpAndSettle();

      const approvedDraftText =
          'Control is checking the Waterfall dispatch response for Resident Feed now and will share the next confirmed step shortly.';
      await tester.enterText(find.byType(TextField).first, approvedDraftText);
      await tester.pumpAndSettle();

      final sendReviewedDraftButton = find.widgetWithText(
        FilledButton,
        'Log Dispatch Review for Resident Feed',
      );
      await tester.ensureVisible(sendReviewedDraftButton);
      await tester.tap(sendReviewedDraftButton);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-offscope-cross-surface-learn-dashboard-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
          initialOperationsScopeClientIdOverride: 'CLIENT-MS-VALLEE',
          initialOperationsScopeSiteIdOverride: 'WTF-MAIN',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT LANE WATCH'), findsOneWidget);
      expect(find.textContaining('WTF-MAIN'), findsWidgets);
      expect(find.text('Learned style 1'), findsWidgets);
      expect(find.text('Learned approval style'), findsWidgets);
      expect(find.textContaining(approvedDraftText), findsWidgets);
    },
  );

  testWidgets(
    'onyx app shows off-scope client-lane manual reply in live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveClientAppDraft(
        const ClientAppDraft(
          viewerRole: ClientAppViewerRole.control,
          selectedRoom: 'Residents',
          selectedRoomByRole: <String, String>{
            'client': 'Residents',
            'control': 'Residents',
            'resident': 'Residents',
          },
          showAllRoomItemsByRole: <String, bool>{
            'client': false,
            'control': false,
            'resident': false,
          },
        ),
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-offscope-lane-reply-clients-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-MS-VALLEE',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      final controlViewChip = find.text('Control View');
      if (controlViewChip.evaluate().isNotEmpty) {
        await tester.ensureVisible(controlViewChip.first);
        await tester.tap(controlViewChip.first);
        await tester.pumpAndSettle();
      }

      const controlUpdateBody =
          'Waterfall control lane update: desk has logged the resident follow-up.';
      await tester.enterText(find.byType(TextField).first, controlUpdateBody);
      final sendControlUpdateButton = find.widgetWithText(
        FilledButton,
        'Log Resident Update',
      );
      await tester.ensureVisible(sendControlUpdateButton);
      await tester.tap(sendControlUpdateButton);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-offscope-lane-reply-dashboard-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
          initialOperationsScopeClientIdOverride: 'CLIENT-MS-VALLEE',
          initialOperationsScopeSiteIdOverride: 'WTF-MAIN',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT LANE WATCH'), findsOneWidget);
      expect(find.textContaining('WTF-MAIN'), findsWidgets);
      expect(find.text('Pending ONYX Draft'), findsNothing);
      expect(find.textContaining(controlUpdateBody), findsWidgets);
    },
  );

  testWidgets(
    'onyx app restores off-scope push queue and push sync state into live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final scopedConversation = ScopedSharedPrefsClientConversationRepository(
        persistence: persistence,
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );
      final occurredAtUtc = DateTime.utc(2026, 3, 18, 13, 6);
      await scopedConversation.savePushQueue(<ClientAppPushDeliveryItem>[
        ClientAppPushDeliveryItem(
          messageKey: 'waterfall-queued-push-1',
          title: 'Waterfall delivery check',
          body: 'Queued client update for the Waterfall lane.',
          occurredAt: occurredAtUtc,
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'WTF-MAIN',
          targetChannel: ClientAppAcknowledgementChannel.client,
          deliveryProvider: ClientPushDeliveryProvider.inApp,
          priority: true,
          status: ClientPushDeliveryStatus.queued,
        ),
      ]);
      await scopedConversation.savePushSyncState(
        ClientPushSyncState(
          statusLabel: 'failed',
          lastSyncedAtUtc: occurredAtUtc,
          failureReason:
              'Waterfall push sync needs operator review before retry.',
          retryCount: 2,
          history: <ClientPushSyncAttempt>[
            ClientPushSyncAttempt(
              occurredAt: occurredAtUtc,
              status: 'failed',
              failureReason:
                  'Waterfall push sync needs operator review before retry.',
              queueSize: 1,
            ),
          ],
          backendProbeStatusLabel: 'idle',
          backendProbeHistory: const <ClientBackendProbeAttempt>[],
        ),
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-offscope-push-state-dashboard-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
          initialOperationsScopeClientIdOverride: 'CLIENT-MS-VALLEE',
          initialOperationsScopeSiteIdOverride: 'WTF-MAIN',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT LANE WATCH'), findsOneWidget);
      expect(find.textContaining('WTF-MAIN'), findsWidgets);
      expect(find.text('Push FAILED'), findsWidgets);
      expect(find.textContaining('1 push item queued'), findsWidgets);
      expect(find.text('Recent delivery history'), findsWidgets);
      expect(
        find.textContaining('13:06 UTC • needs review • queue:1'),
        findsWidgets,
      );
      expect(
        find.textContaining(
          'Push detail: Waterfall push sync needs operator review before retry.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app carries off-scope push pressure from admin audit into the exact live operations lane after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final scopedConversation = ScopedSharedPrefsClientConversationRepository(
        persistence: persistence,
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );
      final occurredAtUtc = DateTime.utc(2026, 3, 18, 13, 9);
      await scopedConversation.savePushQueue(<ClientAppPushDeliveryItem>[
        ClientAppPushDeliveryItem(
          messageKey: 'waterfall-admin-to-liveops-push-1',
          title: 'Waterfall delivery check',
          body: 'Queued client update for the Waterfall lane.',
          occurredAt: occurredAtUtc,
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'WTF-MAIN',
          targetChannel: ClientAppAcknowledgementChannel.client,
          deliveryProvider: ClientPushDeliveryProvider.inApp,
          priority: true,
          status: ClientPushDeliveryStatus.queued,
        ),
      ]);
      await scopedConversation.savePushSyncState(
        ClientPushSyncState(
          statusLabel: 'failed',
          lastSyncedAtUtc: occurredAtUtc,
          failureReason:
              'Waterfall push sync needs operator review before retry.',
          retryCount: 2,
          history: <ClientPushSyncAttempt>[
            ClientPushSyncAttempt(
              occurredAt: occurredAtUtc,
              status: 'failed',
              failureReason:
                  'Waterfall push sync needs operator review before retry.',
              queueSize: 1,
            ),
          ],
          backendProbeStatusLabel: 'idle',
          backendProbeHistory: const <ClientBackendProbeAttempt>[],
        ),
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-to-liveops-push-pressure-admin-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('System').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('LATEST PUSH DETAIL'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Client Comms Audit'), findsOneWidget);
      expect(find.text('Push FAILED'), findsWidgets);
      expect(find.text('1 push item queued'), findsWidgets);
      expect(find.text('RECENT DELIVERY HISTORY'), findsOneWidget);
      expect(
        find.textContaining('13:09 UTC • needs review • queue:1'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Waterfall push sync needs operator review before retry.',
        ),
        findsWidgets,
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-to-liveops-push-pressure-dashboard-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
          initialOperationsScopeClientIdOverride: 'CLIENT-MS-VALLEE',
          initialOperationsScopeSiteIdOverride: 'WTF-MAIN',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT LANE WATCH'), findsOneWidget);
      expect(find.textContaining('WTF-MAIN'), findsWidgets);
      expect(find.text('Push FAILED'), findsWidgets);
      expect(find.textContaining('1 push item queued'), findsWidgets);
      expect(find.text('Recent delivery history'), findsWidgets);
      expect(
        find.textContaining('13:09 UTC • needs review • queue:1'),
        findsWidgets,
      );
      expect(
        find.textContaining(
          'Push detail: Waterfall push sync needs operator review before retry.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app restores off-scope telegram bridge health into live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final scopedConversation = ScopedSharedPrefsClientConversationRepository(
        persistence: persistence,
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );
      final occurredAtUtc = DateTime.utc(2026, 3, 18, 13, 11);
      await scopedConversation.savePushSyncState(
        ClientPushSyncState(
          statusLabel: 'failed',
          lastSyncedAtUtc: occurredAtUtc,
          failureReason:
              'Telegram bridge failed for 1/1 message(s). Reasons: BLOCKED_BY_TEST_STUB',
          retryCount: 1,
          history: <ClientPushSyncAttempt>[
            ClientPushSyncAttempt(
              occurredAt: occurredAtUtc,
              status: 'telegram-blocked',
              failureReason:
                  'Telegram bridge failed for 1/1 message(s). Reasons: BLOCKED_BY_TEST_STUB',
              queueSize: 1,
            ),
          ],
          backendProbeStatusLabel: 'idle',
          backendProbeHistory: const <ClientBackendProbeAttempt>[],
        ),
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-offscope-telegram-health-dashboard-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
          initialOperationsScopeClientIdOverride: 'CLIENT-MS-VALLEE',
          initialOperationsScopeSiteIdOverride: 'WTF-MAIN',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT LANE WATCH'), findsOneWidget);
      expect(find.textContaining('WTF-MAIN'), findsWidgets);
      expect(find.text('Telegram BLOCKED'), findsWidgets);
      expect(find.textContaining('Telegram fallback is active'), findsWidgets);
      expect(
        find.textContaining(
          'Telegram could not deliver 1/1 client update. Bridge reported: BLOCKED_BY_TEST_STUB.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app carries off-scope telegram health from admin audit into the exact live operations lane after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final scopedConversation = ScopedSharedPrefsClientConversationRepository(
        persistence: persistence,
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );
      final occurredAtUtc = DateTime.utc(2026, 3, 18, 13, 18);
      await scopedConversation.savePushSyncState(
        ClientPushSyncState(
          statusLabel: 'failed',
          lastSyncedAtUtc: occurredAtUtc,
          failureReason:
              'Telegram bridge failed for 1/1 message(s). Reasons: BLOCKED_BY_TEST_STUB',
          retryCount: 1,
          history: <ClientPushSyncAttempt>[
            ClientPushSyncAttempt(
              occurredAt: occurredAtUtc,
              status: 'telegram-blocked',
              failureReason:
                  'Telegram bridge failed for 1/1 message(s). Reasons: BLOCKED_BY_TEST_STUB',
              queueSize: 1,
            ),
          ],
          backendProbeStatusLabel: 'idle',
          backendProbeHistory: const <ClientBackendProbeAttempt>[],
        ),
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-to-liveops-telegram-health-admin-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('System').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Client Comms Audit'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Client Comms Audit'), findsOneWidget);
      expect(find.text('Telegram BLOCKED'), findsWidgets);
      expect(
        find.textContaining(
          'Telegram could not deliver 1/1 client update. Bridge reported: BLOCKED_BY_TEST_STUB.',
        ),
        findsWidgets,
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-to-liveops-telegram-health-dashboard-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
          initialOperationsScopeClientIdOverride: 'CLIENT-MS-VALLEE',
          initialOperationsScopeSiteIdOverride: 'WTF-MAIN',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT LANE WATCH'), findsOneWidget);
      expect(find.textContaining('WTF-MAIN'), findsWidgets);
      expect(find.text('Telegram BLOCKED'), findsWidgets);
      expect(find.textContaining('Telegram fallback is active'), findsWidgets);
      expect(
        find.textContaining(
          'Telegram could not deliver 1/1 client update. Bridge reported: BLOCKED_BY_TEST_STUB.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app carries off-scope sms fallback from admin audit into the exact live operations lane after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final scopedConversation = ScopedSharedPrefsClientConversationRepository(
        persistence: persistence,
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );
      final occurredAtUtc = DateTime.utc(2026, 3, 18, 13, 21);
      await scopedConversation.savePushSyncState(
        ClientPushSyncState(
          statusLabel: 'degraded',
          lastSyncedAtUtc: occurredAtUtc,
          failureReason:
              'BulkSMS reached 2/2 contacts after telegram target failure.',
          retryCount: 1,
          history: <ClientPushSyncAttempt>[
            ClientPushSyncAttempt(
              occurredAt: occurredAtUtc,
              status: 'sms-fallback-ok',
              failureReason:
                  'BulkSMS reached 2/2 contacts after telegram target failure.',
              queueSize: 1,
            ),
          ],
          backendProbeStatusLabel: 'idle',
          backendProbeHistory: const <ClientBackendProbeAttempt>[],
        ),
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-to-liveops-sms-fallback-admin-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('System').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('LATEST SMS FALLBACK'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Client Comms Audit'), findsOneWidget);
      expect(find.text('LATEST SMS FALLBACK'), findsWidgets);
      expect(
        find.textContaining(
          'BulkSMS reached 2/2 contacts after telegram target failure.',
        ),
        findsWidgets,
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-to-liveops-sms-fallback-dashboard-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
          initialOperationsScopeClientIdOverride: 'CLIENT-MS-VALLEE',
          initialOperationsScopeSiteIdOverride: 'WTF-MAIN',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT LANE WATCH'), findsOneWidget);
      expect(find.textContaining('WTF-MAIN'), findsWidgets);
      expect(find.text('Latest SMS fallback'), findsWidgets);
      expect(
        find.textContaining(
          'BulkSMS reached 2/2 contacts after telegram target failure.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app carries off-scope voip history from admin audit into the exact live operations lane after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final scopedConversation = ScopedSharedPrefsClientConversationRepository(
        persistence: persistence,
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );
      final occurredAtUtc = DateTime.utc(2026, 3, 18, 13, 22);
      await scopedConversation.savePushSyncState(
        ClientPushSyncState(
          statusLabel: 'degraded',
          lastSyncedAtUtc: occurredAtUtc,
          failureReason: 'voip:asterisk staged call for Waterfall command desk.',
          retryCount: 0,
          history: <ClientPushSyncAttempt>[
            ClientPushSyncAttempt(
              occurredAt: occurredAtUtc,
              status: 'voip-staged',
              failureReason:
                  'voip:asterisk staged call for Waterfall command desk.',
              queueSize: 1,
            ),
          ],
          backendProbeStatusLabel: 'idle',
          backendProbeHistory: const <ClientBackendProbeAttempt>[],
        ),
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-to-liveops-voip-history-admin-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('System').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('LATEST VOIP STAGE'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Client Comms Audit'), findsOneWidget);
      expect(find.text('LATEST VOIP STAGE'), findsWidgets);
      expect(
        find.textContaining('Asterisk staged a call for Waterfall command desk.'),
        findsWidgets,
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-to-liveops-voip-history-dashboard-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
          initialOperationsScopeClientIdOverride: 'CLIENT-MS-VALLEE',
          initialOperationsScopeSiteIdOverride: 'WTF-MAIN',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT LANE WATCH'), findsOneWidget);
      expect(find.textContaining('WTF-MAIN'), findsWidgets);
      expect(find.text('Latest VoIP stage'), findsWidgets);
      expect(
        find.textContaining('Asterisk staged a call for Waterfall command desk.'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app shows client-lane pinned voice in live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveClientAppDraft(
        const ClientAppDraft(
          viewerRole: ClientAppViewerRole.control,
          selectedRoom: 'Residents',
          selectedRoomByRole: <String, String>{
            'client': 'Residents',
            'control': 'Residents',
            'resident': 'Residents',
          },
          showAllRoomItemsByRole: <String, bool>{
            'client': false,
            'control': false,
            'resident': false,
          },
        ),
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-cross-surface-voice-clients-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      final controlViewChip = find.text('Control View');
      if (controlViewChip.evaluate().isNotEmpty) {
        await tester.ensureVisible(controlViewChip.first);
        await tester.tap(controlViewChip.first);
        await tester.pumpAndSettle();
      }

      final reassuringChip = find.widgetWithText(ChoiceChip, 'Reassuring');
      await tester.ensureVisible(reassuringChip);
      await tester.tap(reassuringChip);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-cross-surface-voice-dashboard-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lane voice Reassuring'), findsWidgets);
    },
  );

  testWidgets(
    'onyx app clears client-lane pinned voice from live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveClientAppDraft(
        const ClientAppDraft(
          viewerRole: ClientAppViewerRole.control,
          selectedRoom: 'Residents',
          selectedRoomByRole: <String, String>{
            'client': 'Residents',
            'control': 'Residents',
            'resident': 'Residents',
          },
          showAllRoomItemsByRole: <String, bool>{
            'client': false,
            'control': false,
            'resident': false,
          },
        ),
      );
      await persistence.saveTelegramAdminRuntimeState({
        'ai_client_profile_overrides': {
          'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE': 'reassurance-forward',
        },
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-cross-surface-clear-voice-clients-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      final controlViewChip = find.text('Control View');
      if (controlViewChip.evaluate().isNotEmpty) {
        await tester.ensureVisible(controlViewChip.first);
        await tester.tap(controlViewChip.first);
        await tester.pumpAndSettle();
      }

      final autoChip = find.widgetWithText(ChoiceChip, 'Auto');
      await tester.ensureVisible(autoChip);
      await tester.tap(autoChip);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-cross-surface-clear-voice-dashboard-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lane voice Reassuring'), findsNothing);
    },
  );

  testWidgets(
    'onyx app clears client-lane learned approval style from live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveClientAppDraft(
        const ClientAppDraft(
          viewerRole: ClientAppViewerRole.control,
          selectedRoom: 'Residents',
          selectedRoomByRole: <String, String>{
            'client': 'Residents',
            'control': 'Residents',
            'resident': 'Residents',
          },
          showAllRoomItemsByRole: <String, bool>{
            'client': false,
            'control': false,
            'resident': false,
          },
        ),
      );
      await persistence.saveTelegramAdminRuntimeState({
        'ai_approved_rewrite_examples_by_scope': {
          'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE': <String>[
            'Control is checking the latest position now and will share the next confirmed step shortly.',
          ],
        },
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-cross-surface-clear-learned-clients-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      final controlViewChip = find.text('Control View');
      if (controlViewChip.evaluate().isNotEmpty) {
        await tester.ensureVisible(controlViewChip.first);
        await tester.tap(controlViewChip.first);
        await tester.pumpAndSettle();
      }

      final clearLearnedStyleButton = find.widgetWithText(
        OutlinedButton,
        'Clear Learned Style',
      );
      await tester.ensureVisible(clearLearnedStyleButton);
      await tester.tap(clearLearnedStyleButton);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey(
            'live-ops-cross-surface-clear-learned-dashboard-app',
          ),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Learned style 1'), findsNothing);
      expect(find.text('Learned approval style'), findsNothing);
      expect(find.text('ONYX using learned style'), findsNothing);
    },
  );

  testWidgets(
    'onyx app reflects admin lane voice changes in live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTelegramAdminRuntimeState({
        'ai_approved_rewrite_examples_by_scope': {
          'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE': <String>[
            'Control is checking the latest position now and will share the next confirmed step shortly.',
          ],
        },
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-admin-voice-source-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('System').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Client Comms Audit'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final reassuringButton = find.widgetWithText(OutlinedButton, 'Reassuring');
      await tester.ensureVisible(reassuringButton.first);
      await tester.tap(reassuringButton.first);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-admin-voice-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lane voice Reassuring'), findsWidgets);
    },
  );

  testWidgets(
    'onyx app reflects admin learned-style clearing in live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTelegramAdminRuntimeState({
        'ai_pending_drafts': <Map<String, Object?>>[
          {
            'inbound_update_id': 901,
            'chat_id': '123456',
            'message_thread_id': 88,
            'audience': 'client',
            'client_id': 'CLIENT-MS-VALLEE',
            'site_id': 'SITE-MS-VALLEE-RESIDENCE',
            'source_text': 'Please update me on the patrol position.',
            'original_draft_text':
                'We are checking the latest patrol position now and will send the next verified update shortly.',
            'draft_text':
                'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
            'provider_label': 'openai:gpt-4.1-mini',
            'used_learned_approval_style': true,
            'created_at_utc': DateTime.utc(2026, 3, 18, 12, 46)
                .toIso8601String(),
          },
        ],
        'ai_approved_rewrite_examples_by_scope': {
          'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE': <String>[
            'Control is checking the latest position now and will share the next confirmed step shortly.',
          ],
        },
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-admin-clear-learned-source-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('System').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('CLIENT ASKED'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final clearLearnedStyleButton = find.widgetWithText(
        OutlinedButton,
        'Clear Learned Style',
      );
      await tester.ensureVisible(clearLearnedStyleButton.first);
      await tester.tap(clearLearnedStyleButton.first);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-admin-clear-learned-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Learned style 1'), findsNothing);
      expect(find.text('Learned approval style'), findsNothing);
    },
  );

  testWidgets(
    'onyx app reflects admin approved pending draft in live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTelegramAdminRuntimeState({
        'ai_pending_drafts': <Map<String, Object?>>[
          {
            'inbound_update_id': 902,
            'chat_id': '123456',
            'message_thread_id': 88,
            'audience': 'client',
            'client_id': 'CLIENT-MS-VALLEE',
            'site_id': 'SITE-MS-VALLEE-RESIDENCE',
            'source_text': 'Please update me on the patrol position.',
            'original_draft_text':
                'We are checking the latest patrol position now and will send the next verified update shortly.',
            'draft_text':
                'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
            'provider_label': 'openai:gpt-4.1-mini',
            'used_learned_approval_style': false,
            'created_at_utc': DateTime.utc(2026, 3, 18, 12, 47)
                .toIso8601String(),
          },
        ],
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-admin-approve-source-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
          telegramBridgeServiceOverride: const _SuccessfulTelegramBridgeStub(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('System').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('CLIENT ASKED'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Approve + Send'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-admin-approve-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending ONYX Draft'), findsNothing);
      expect(find.text('Learned style 1'), findsWidgets);
      expect(find.text('Learned approval style'), findsWidgets);
      expect(
        find.textContaining(
          'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app reflects admin rejected pending draft in live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTelegramAdminRuntimeState({
        'ai_pending_drafts': <Map<String, Object?>>[
          {
            'inbound_update_id': 904,
            'chat_id': '123456',
            'message_thread_id': 88,
            'audience': 'client',
            'client_id': 'CLIENT-MS-VALLEE',
            'site_id': 'SITE-MS-VALLEE-RESIDENCE',
            'source_text': 'Please update me on the patrol position.',
            'original_draft_text':
                'We are checking the latest patrol position now and will send the next verified update shortly.',
            'draft_text':
                'We are checking the latest patrol position now and will send the next verified update shortly.',
            'provider_label': 'openai:gpt-4.1-mini',
            'used_learned_approval_style': false,
            'created_at_utc': DateTime.utc(2026, 3, 18, 12, 49)
                .toIso8601String(),
          },
        ],
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-admin-reject-source-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('System').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('CLIENT ASKED'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-admin-reject-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending ONYX Draft'), findsNothing);
    },
  );
}
