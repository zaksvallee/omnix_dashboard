import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnix_dashboard/application/client_conversation_repository.dart';
import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/application/telegram_bridge_service.dart';
import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/admin_page.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/client_app_page.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'onyx app opens client lane from admin client demo without invalid room state',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? openedClientId;
      String? openedSiteId;
      String? openedRoom;

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.clients,
          onClientLaneRouteOpened: (clientId, siteId, room) {
            openedClientId = clientId;
            openedSiteId = siteId;
            openedRoom = room;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Demo Mode'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      final demoReadyButton = find.widgetWithText(
        FilledButton,
        'Demo Ready 0/7',
      );
      final fallbackDemoReadyButton = find.textContaining('Demo Ready');
      final demoReadyFinder = demoReadyButton.evaluate().isNotEmpty
          ? demoReadyButton.first
          : fallbackDemoReadyButton.first;
      await tester.ensureVisible(demoReadyFinder);
      await tester.tap(demoReadyFinder);
      await tester.pumpAndSettle();

      final createClientReadyFinder = find.text('Create Client (Ready)').last;
      await tester.ensureVisible(createClientReadyFinder);
      await tester.tap(createClientReadyFinder);
      await tester.pumpAndSettle();

      expect(find.text('Client Demo Ready'), findsOneWidget);

      await tester.tap(find.text('Open Client View'));
      await tester.pumpAndSettle();

      expect(openedClientId, startsWith('DEMO-CLT'));
      expect(openedSiteId, '');
      expect(openedRoom, isEmpty);
      expect(find.textContaining('Client Operations'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app restores scoped guard voip history into admin comms audit after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('guards-app'),
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
          key: const ValueKey('admin-app'),
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
      expect(find.text('LATEST VOIP STAGE'), findsOneWidget);
      expect(
        find.textContaining(
          'VoIP staging is not configured for Thabo Mokoena yet.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx app surfaces off-lane comms history in admin audit as cross-scope',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-cross-scope-guards-app'),
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
          key: const ValueKey('admin-cross-scope-audit-app'),
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
      expect(find.text('Cross-scope'), findsOneWidget);
      expect(find.text('LATEST VOIP STAGE'), findsOneWidget);
      expect(
        find.textContaining(
          'VoIP staging is not configured for Thabo Mokoena yet.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx app surfaces off-scope live client asks in admin audit',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
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
          key: const ValueKey('admin-cross-scope-live-ask-app'),
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
      expect(find.text('Cross-scope'), findsWidgets);
      expect(find.text('1 live ask'), findsOneWidget);
      expect(find.text('LATEST CLIENT ASK'), findsOneWidget);
      expect(
        find.textContaining(
          'Please confirm whether the Waterfall response team has already arrived.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx app opens the exact off-scope lane from an ask-driven admin audit card',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
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
          key: const ValueKey('admin-cross-scope-live-ask-open-lane-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
          onClientLaneRouteOpened: (clientId, siteId, room) {
            openedClientId = clientId;
            openedSiteId = siteId;
            openedRoom = room;
          },
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

      await tester.ensureVisible(find.text('Open This Lane').first);
      await tester.tap(find.text('Open This Lane').first);
      await tester.pumpAndSettle();

      expect(openedClientId, 'CLIENT-MS-VALLEE');
      expect(openedSiteId, 'WTF-MAIN');
      expect(openedRoom, isEmpty);
      expect(find.textContaining('Client Operations'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app restores learned approval style into admin comms audit after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
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
          key: const ValueKey('admin-learned-style-app'),
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
      expect(find.text('Learned style (1)'), findsOneWidget);
      expect(find.text('LEARNED APPROVAL STYLE'), findsOneWidget);
      expect(
        find.textContaining(
          'Control is checking the latest position now and will share the next confirmed step shortly.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx app restores pinned lane voice into admin comms audit after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTelegramAdminRuntimeState({
        'ai_client_profile_overrides': {
          'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE': 'reassurance-forward',
        },
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-voice-app'),
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
      expect(find.textContaining('Voice Reassuring'), findsOneWidget);
      expect(find.text('Lane voice: Reassuring'), findsOneWidget);
      expect(find.text('Voice-adjusted'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app restores pending telegram ai draft into admin review after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTelegramAdminRuntimeState({
        'ai_pending_drafts': <Map<String, Object?>>[
          {
            'inbound_update_id': 42,
            'chat_id': '123456',
            'message_thread_id': 88,
            'audience': 'client',
            'client_id': 'CLIENT-MS-VALLEE',
            'site_id': 'SITE-MS-VALLEE-RESIDENCE',
            'source_text':
                'Can you please tell me what is happening at the house?',
            'original_draft_text':
                'We are checking the latest position now and will send the next confirmed update shortly.',
            'draft_text':
                'We are checking the latest position now and will send the next confirmed update shortly.',
            'provider_label': 'openai:gpt-4.1-mini',
            'used_learned_approval_style': false,
            'created_at_utc': DateTime.utc(2026, 3, 18, 12, 30)
                .toIso8601String(),
          },
        ],
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-pending-draft-app'),
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

      expect(find.text('Awaiting human sign-off'), findsOneWidget);
      expect(find.text('CLIENT ASKED'), findsOneWidget);
      expect(find.text('ONYX WILL SAY'), findsOneWidget);
      expect(find.text('Selected lane'), findsWidgets);
      expect(
        find.textContaining(
          'Can you please tell me what is happening at the house?',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'We are checking the latest position now and will send the next confirmed update shortly.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx app surfaces off-scope pending telegram ai drafts in admin review',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTelegramAdminRuntimeState({
        'ai_pending_drafts': <Map<String, Object?>>[
          {
            'inbound_update_id': 43,
            'chat_id': '123456',
            'message_thread_id': 89,
            'audience': 'client',
            'client_id': 'CLIENT-MS-VALLEE',
            'site_id': 'WTF-MAIN',
            'source_text':
                'Can you confirm whether the Waterfall team is already on site?',
            'original_draft_text':
                'We are checking the latest Waterfall position now and will send the next confirmed update shortly.',
            'draft_text':
                'We are checking the latest Waterfall position now and will send the next confirmed update shortly.',
            'provider_label': 'openai:gpt-4.1-mini',
            'used_learned_approval_style': false,
            'created_at_utc': DateTime.utc(2026, 3, 18, 12, 30)
                .toIso8601String(),
          },
        ],
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-off-scope-pending-draft-app'),
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

      expect(find.text('Awaiting human sign-off'), findsOneWidget);
      expect(find.text('CLIENT ASKED'), findsOneWidget);
      expect(find.text('ONYX WILL SAY'), findsOneWidget);
      expect(find.text('Cross-scope'), findsWidgets);
      expect(
        find.textContaining(
          'Can you confirm whether the Waterfall team is already on site?',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'We are checking the latest Waterfall position now and will send the next confirmed update shortly.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx app opens the exact off-scope lane from admin draft review',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTelegramAdminRuntimeState({
        'ai_pending_drafts': <Map<String, Object?>>[
          {
            'inbound_update_id': 44,
            'chat_id': '123456',
            'message_thread_id': 90,
            'audience': 'client',
            'client_id': 'CLIENT-MS-VALLEE',
            'site_id': 'WTF-MAIN',
            'source_text':
                'Please confirm whether the Waterfall desk has eyes on the lane yet.',
            'original_draft_text':
                'Control is checking the latest Waterfall visual now and will share the next confirmed step shortly.',
            'draft_text':
                'Control is checking the latest Waterfall visual now and will share the next confirmed step shortly.',
            'provider_label': 'openai:gpt-4.1-mini',
            'used_learned_approval_style': false,
            'created_at_utc': DateTime.utc(2026, 3, 18, 12, 31)
                .toIso8601String(),
          },
        ],
      });

      String? openedClientId;
      String? openedSiteId;
      String? openedRoom;

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-open-off-scope-draft-lane-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
          onClientLaneRouteOpened: (clientId, siteId, room) {
            openedClientId = clientId;
            openedSiteId = siteId;
            openedRoom = room;
          },
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

      await tester.ensureVisible(find.text('Open This Lane').first);
      await tester.tap(find.text('Open This Lane').first);
      await tester.pumpAndSettle();

      expect(openedClientId, 'CLIENT-MS-VALLEE');
      expect(openedSiteId, 'WTF-MAIN');
      expect(openedRoom, isEmpty);
      expect(find.textContaining('Client Operations'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app persists rejected telegram ai draft clearing after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTelegramAdminRuntimeState({
        'ai_pending_drafts': <Map<String, Object?>>[
          {
            'inbound_update_id': 77,
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
            'created_at_utc': DateTime.utc(2026, 3, 18, 12, 31)
                .toIso8601String(),
          },
        ],
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-reject-draft-app'),
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
          key: const ValueKey('admin-reject-draft-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('System').first);
      await tester.pumpAndSettle();

      expect(find.text('CLIENT ASKED'), findsNothing);
      expect(find.text('ONYX WILL SAY'), findsNothing);
      expect(find.text('Awaiting human sign-off'), findsNothing);
    },
  );

  testWidgets(
    'onyx app persists approved telegram ai draft learning after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTelegramAdminRuntimeState({
        'ai_pending_drafts': <Map<String, Object?>>[
          {
            'inbound_update_id': 91,
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
            'created_at_utc': DateTime.utc(2026, 3, 18, 12, 32)
                .toIso8601String(),
          },
        ],
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-approve-draft-app'),
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
          key: const ValueKey('admin-approve-draft-restart-app'),
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

      expect(find.text('CLIENT ASKED'), findsNothing);
      expect(find.text('Learned style (1)'), findsOneWidget);
      expect(find.text('LEARNED APPROVAL STYLE'), findsOneWidget);
      expect(
        find.textContaining(
          'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app shows client-lane learned approval memory in admin audit after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
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
          key: const ValueKey('admin-cross-surface-learn-clients-app'),
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
          key: const ValueKey('admin-cross-surface-learn-admin-app'),
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

      expect(find.text('Learned style (1)'), findsOneWidget);
      expect(find.text('LEARNED APPROVAL STYLE'), findsOneWidget);
      expect(find.textContaining(approvedDraftText), findsWidgets);
    },
  );

  testWidgets(
    'onyx app shows off-scope client-lane learned approval style in admin audit after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
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
          key: const ValueKey('admin-offscope-cross-surface-learn-clients-app'),
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
          key: const ValueKey('admin-offscope-cross-surface-learn-admin-app'),
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
      expect(find.text('Cross-scope'), findsWidgets);
      expect(find.text('Learned style (1)'), findsWidgets);
      expect(find.text('LEARNED APPROVAL STYLE'), findsWidgets);
      expect(find.textContaining(approvedDraftText), findsWidgets);
    },
  );

  testWidgets(
    'onyx app shows off-scope client-lane manual reply in admin audit after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
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
          key: const ValueKey('admin-offscope-lane-reply-clients-app'),
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
          key: const ValueKey('admin-offscope-lane-reply-admin-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('System').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('LATEST LANE REPLY'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Client Comms Audit'), findsOneWidget);
      expect(find.text('Cross-scope'), findsWidgets);
      expect(find.text('LATEST LANE REPLY'), findsOneWidget);
      expect(find.textContaining(controlUpdateBody), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app shows off-scope push queue and push sync pressure in admin audit after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final scopedConversation = ScopedSharedPrefsClientConversationRepository(
        persistence: persistence,
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );
      final occurredAtUtc = DateTime.utc(2026, 3, 18, 13, 14);
      await scopedConversation.savePushQueue(<ClientAppPushDeliveryItem>[
        ClientAppPushDeliveryItem(
          messageKey: 'waterfall-admin-push-1',
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
          key: const ValueKey('admin-offscope-push-pressure-app'),
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
      expect(find.text('Push FAILED'), findsWidgets);
      expect(find.text('1 push item queued'), findsWidgets);
      expect(find.text('RECENT DELIVERY HISTORY'), findsOneWidget);
      expect(
        find.textContaining('13:14 UTC • needs review • queue:1'),
        findsOneWidget,
      );
      expect(find.text('LATEST PUSH DETAIL'), findsOneWidget);
      expect(
        find.textContaining(
          'Waterfall push sync needs operator review before retry.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app opens the exact off-scope lane from a push-pressure admin audit card',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final scopedConversation = ScopedSharedPrefsClientConversationRepository(
        persistence: persistence,
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );
      final occurredAtUtc = DateTime.utc(2026, 3, 18, 13, 14);
      await scopedConversation.savePushQueue(<ClientAppPushDeliveryItem>[
        ClientAppPushDeliveryItem(
          messageKey: 'waterfall-admin-push-open-lane-1',
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

      String? openedClientId;
      String? openedSiteId;
      String? openedRoom;

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-open-off-scope-push-pressure-lane-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
          onClientLaneRouteOpened: (clientId, siteId, room) {
            openedClientId = clientId;
            openedSiteId = siteId;
            openedRoom = room;
          },
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

      await tester.ensureVisible(find.text('Open This Lane').first);
      await tester.tap(find.text('Open This Lane').first);
      await tester.pumpAndSettle();

      expect(openedClientId, 'CLIENT-MS-VALLEE');
      expect(openedSiteId, 'WTF-MAIN');
      expect(openedRoom, isEmpty);
      expect(find.textContaining('Client Operations'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app humanizes off-scope telegram bridge detail in admin audit after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final scopedConversation = ScopedSharedPrefsClientConversationRepository(
        persistence: persistence,
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );
      final occurredAtUtc = DateTime.utc(2026, 3, 18, 13, 26);
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
          key: const ValueKey('admin-telegram-detail-humanized-app'),
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
      expect(find.text('Telegram BLOCKED'), findsWidgets);
      expect(find.text('LATEST PUSH DETAIL'), findsOneWidget);
      expect(
        find.textContaining(
          'Telegram could not deliver 1/1 client update. Bridge reported: BLOCKED_BY_TEST_STUB.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app shows client-lane pinned voice in admin audit after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
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
          key: const ValueKey('admin-cross-surface-voice-clients-app'),
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
          key: const ValueKey('admin-cross-surface-voice-admin-app'),
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

      expect(find.textContaining('Voice Reassuring'), findsOneWidget);
      expect(find.text('Lane voice: Reassuring'), findsOneWidget);
      expect(find.text('Voice-adjusted'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app clears client-lane pinned voice from admin audit after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
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
          key: const ValueKey('admin-cross-surface-clear-voice-clients-app'),
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
          key: const ValueKey('admin-cross-surface-clear-voice-admin-app'),
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

      expect(find.textContaining('Voice Reassuring'), findsNothing);
      expect(find.text('Lane voice: Reassuring'), findsNothing);
      expect(find.text('Voice-adjusted'), findsNothing);
    },
  );

  testWidgets(
    'onyx app clears client-lane learned approval style from admin audit after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
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
          key: const ValueKey('admin-cross-surface-clear-learned-clients-app'),
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
          key: const ValueKey('admin-cross-surface-clear-learned-admin-app'),
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

      expect(find.text('Learned style (1)'), findsNothing);
      expect(find.text('LEARNED APPROVAL STYLE'), findsNothing);
      expect(find.text('ONYX using learned style'), findsNothing);
    },
  );

  testWidgets(
    'onyx app reflects live operations learned-style clearing in admin audit after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
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
          key: const ValueKey('admin-live-ops-clear-learned-source-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
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
          key: const ValueKey('admin-live-ops-clear-learned-restart-app'),
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

      expect(find.text('Learned style (1)'), findsNothing);
      expect(find.text('LEARNED APPROVAL STYLE'), findsNothing);
      expect(find.text('ONYX using learned style'), findsNothing);
    },
  );

  testWidgets(
    'onyx app reflects live operations lane voice changes in admin audit after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-live-ops-voice-source-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      final reassuringButton = find.widgetWithText(OutlinedButton, 'Reassuring');
      await tester.ensureVisible(reassuringButton.first);
      await tester.tap(reassuringButton.first);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-live-ops-voice-restart-app'),
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

      expect(find.textContaining('Voice Reassuring'), findsOneWidget);
      expect(find.text('Lane voice: Reassuring'), findsOneWidget);
      expect(find.text('Voice-adjusted'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app reflects live operations rejected pending draft in admin review after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTelegramAdminRuntimeState({
        'ai_pending_drafts': <Map<String, Object?>>[
          {
            'inbound_update_id': 903,
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
            'created_at_utc': DateTime.utc(2026, 3, 18, 12, 48)
                .toIso8601String(),
          },
        ],
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-live-ops-reject-source-app'),
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
          key: const ValueKey('admin-live-ops-reject-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('System').first);
      await tester.pumpAndSettle();

      expect(find.text('CLIENT ASKED'), findsNothing);
      expect(find.text('ONYX WILL SAY'), findsNothing);
      expect(find.text('Awaiting human sign-off'), findsNothing);
    },
  );

  testWidgets(
    'onyx app reflects live operations approved pending draft in admin review after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTelegramAdminRuntimeState({
        'ai_pending_drafts': <Map<String, Object?>>[
          {
            'inbound_update_id': 905,
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
            'created_at_utc': DateTime.utc(2026, 3, 18, 12, 50)
                .toIso8601String(),
          },
        ],
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-live-ops-approve-source-app'),
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
          key: const ValueKey('admin-live-ops-approve-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('System').first);
      await tester.pumpAndSettle();

      expect(find.text('CLIENT ASKED'), findsNothing);
      expect(find.text('ONYX WILL SAY'), findsNothing);
      expect(find.text('Awaiting human sign-off'), findsNothing);
      expect(find.text('Learned style (1)'), findsOneWidget);
      expect(find.text('LEARNED APPROVAL STYLE'), findsOneWidget);
      expect(
        find.textContaining(
          'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
        ),
        findsWidgets,
      );
    },
  );
}
