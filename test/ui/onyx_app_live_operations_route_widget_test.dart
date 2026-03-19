import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnix_dashboard/application/client_conversation_repository.dart';
import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/application/sms_delivery_service.dart';
import 'package:omnix_dashboard/application/telegram_bridge_service.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/admin_page.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/client_app_page.dart';

import 'support/admin_route_state_harness.dart';
import 'support/admin_route_test_harness.dart';

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
    'onyx app live operations stays stable on wide short desktop viewport',
    (tester) async {
      tester.view.physicalSize = const Size(2100, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('INCIDENT QUEUE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'onyx app critical alert banner shifts focus to the active critical incident',
    (tester) async {
      final now = DateTime.now().toUtc();
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
          initialStoreEventsOverride: [
            DecisionCreated(
              eventId: 'decision-low',
              sequence: 9001,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 4)),
              dispatchId: 'DSP-LOW',
              clientId: 'CLIENT-MS-VALLEE',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
            ),
            IntelligenceReceived(
              eventId: 'intel-low',
              sequence: 9002,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 3)),
              intelligenceId: 'INTEL-LOW',
              sourceType: 'hardware',
              provider: 'dahua',
              externalId: 'evt-low',
              riskScore: 72,
              headline: 'Perimeter motion',
              summary: 'Moderate perimeter motion detected.',
              clientId: 'CLIENT-MS-VALLEE',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              faceConfidence: 0.82,
              canonicalHash: 'canon-low',
            ),
            DecisionCreated(
              eventId: 'decision-critical',
              sequence: 9003,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              dispatchId: 'DSP-CRIT',
              clientId: 'CLIENT-MS-VALLEE',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
            ),
            IntelligenceReceived(
              eventId: 'intel-critical',
              sequence: 9004,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 1)),
              intelligenceId: 'INTEL-CRIT',
              sourceType: 'hardware',
              provider: 'dahua',
              externalId: 'evt-crit',
              riskScore: 92,
              headline: 'Fire alarm escalation',
              summary: 'Critical hazard posture detected.',
              clientId: 'CLIENT-MS-VALLEE',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              faceConfidence: 0.97,
              canonicalHash: 'canon-crit',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('incident-card-INC-DSP-LOW')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('incident-card-INC-DSP-LOW')));
      await tester.pumpAndSettle();

      expect(find.text('Active Incident: INC-DSP-LOW'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(
          const ValueKey('live-operations-critical-alert-view-details'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('live-operations-critical-alert-view-details'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active Incident: INC-DSP-CRIT'), findsOneWidget);
    },
  );

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
      expect(find.textContaining('Client Communications'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app restores selected-lane sms fallback into live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await seedDefaultValleeQueuedDelivery(
        messageKey: 'test-live-ops-sms-fallback-1',
        occurredAtUtc: DateTime.utc(2026, 3, 18, 12, 50),
      );

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

      await tester.ensureVisible(
        find.byKey(const ValueKey('clients-retry-push-sync-action')),
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
      await tester.ensureVisible(find.text('Latest SMS fallback').first);
      await tester.pumpAndSettle();
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

      await seedDefaultValleeVoipStagePushSync(
        occurredAtUtc: DateTime.utc(2026, 3, 18, 12, 55),
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

      await saveLegacyLearnedApprovalStyles([
        'Control is checking the latest position now and will share the next confirmed step shortly.',
      ]);

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

      await savePinnedLaneVoice(profile: 'reassurance-forward');

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

      await savePendingTelegramDrafts([
        telegramPendingDraftEntry(
          inboundUpdateId: 501,
          messageThreadId: 88,
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          sourceText: 'Hi ONYX, are we still waiting on the patrol update?',
          originalDraftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          draftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          providerLabel: 'OpenAI',
          usedLearnedApprovalStyle: true,
          createdAtUtc: DateTime.utc(2026, 3, 18, 12, 40),
        ),
      ]);

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
      expect(find.text('Cue Next Step'), findsWidgets);
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

      await savePendingTelegramDrafts([
        telegramPendingDraftEntry(
          inboundUpdateId: 507,
          messageThreadId: 91,
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'WTF-MAIN',
          sourceText:
              'Please confirm if the Waterfall response team has already arrived.',
          originalDraftText:
              'We are checking the latest Waterfall position now and will send the next verified update shortly.',
          draftText:
              'Control is checking the latest Waterfall position now and will share the next confirmed step shortly.',
          providerLabel: 'OpenAI',
          createdAtUtc: DateTime.utc(2026, 3, 18, 12, 41),
        ),
      ]);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-other-scope-draft-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending ONYX Draft'), findsNothing);
      expect(find.text('1 High-priority Reply'), findsWidgets);

      await tester.scrollUntilVisible(
        find.textContaining('Waterfall response team has already arrived'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('CONTROL INBOX'), findsOneWidget);
      expect(find.byKey(const ValueKey('control-inbox-priority-badge')), findsOneWidget);
      expect(find.text('High priority 1'), findsOneWidget);
      expect(
        find.textContaining('Waterfall response team has already arrived'),
        findsOneWidget,
      );
      expect(find.text('Queue shape'), findsOneWidget);
      expect(find.text('1 timing'), findsOneWidget);
      expect(find.text('Cue Timing'), findsOneWidget);
      expect(
        find.text('Check that timing is not over-promised before sending.'),
        findsOneWidget,
      );
      expect(find.text('Other scope'), findsWidgets);

      final timingPill = find.byKey(
        const ValueKey('control-inbox-summary-pill-timing'),
      );
      await tester.ensureVisible(timingPill);
      await tester.tap(timingPill);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Showing timing only. Tap the same pill again or use Show all replies to return to the full queue.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('control-inbox-filtered-chip')), findsOneWidget);
      expect(find.text('Filtered 1'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app keeps the queue hint hidden in live operations after restart once it was seen',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await saveLiveOperationsQueueHintState(seen: true);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-queue-hint-hidden-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CONTROL INBOX'), findsOneWidget);
      expect(find.byKey(const ValueKey('control-inbox-queue-hint')), findsNothing);
      expect(find.text('Hide tip'), findsNothing);
    },
  );

  testWidgets(
    'onyx app can re-enable the queue hint in live operations and keep it after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await saveLiveOperationsQueueHintState(seen: true);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-queue-hint-reset-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('control-inbox-queue-hint')), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('control-inbox-show-queue-hint')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('control-inbox-queue-hint')), findsOneWidget);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-queue-hint-reset-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('control-inbox-queue-hint')), findsOneWidget);
      expect(find.text('Hide tip'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app opens the exact off-scope lane from the live operations control inbox',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await savePendingTelegramDrafts([
        telegramPendingDraftEntry(
          inboundUpdateId: 508,
          messageThreadId: 92,
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'WTF-MAIN',
          sourceText:
              'Please confirm if the Waterfall response team has already arrived.',
          originalDraftText:
              'Control is checking the latest Waterfall position now and will share the next confirmed step shortly.',
          draftText:
              'Control is checking the latest Waterfall position now and will share the next confirmed step shortly.',
          providerLabel: 'OpenAI',
          createdAtUtc: DateTime.utc(2026, 3, 18, 12, 42),
        ),
      ]);

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
      expect(find.textContaining('Client Communications'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app surfaces off-scope live client asks and opens the exact lane from shape reply',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await seedWaterfallResidentAsk();

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
      expect(find.textContaining('Client Communications'), findsOneWidget);
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

      await openAdminSystemAnchor(tester, 'LATEST CLIENT ASK');

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

      await savePendingTelegramDrafts([
        telegramPendingDraftEntry(
          inboundUpdateId: 601,
          messageThreadId: 88,
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          sourceText: 'Hi ONYX, are we still waiting on the patrol update?',
          originalDraftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          draftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          providerLabel: 'OpenAI',
          createdAtUtc: DateTime.utc(2026, 3, 18, 12, 41),
        ),
      ]);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-reject-draft-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending ONYX Draft'), findsOneWidget);
      final rejectButton = find.widgetWithText(OutlinedButton, 'Reject').first;
      await tester.ensureVisible(rejectButton);
      await tester.tap(rejectButton);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-reject-draft-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

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

      await savePendingTelegramDrafts([
        telegramPendingDraftEntry(
          inboundUpdateId: 701,
          messageThreadId: 88,
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          sourceText: 'Please update me on the patrol position.',
          originalDraftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          draftText:
              'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
          providerLabel: 'OpenAI',
          createdAtUtc: DateTime.utc(2026, 3, 18, 12, 42),
        ),
      ]);

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
      final approveButton = find.widgetWithText(
        FilledButton,
        'Approve + Send',
      ).first;
      await tester.ensureVisible(approveButton);
      await tester.tap(approveButton);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-approve-draft-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

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

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('live-ops-cross-surface-learn-clients-app'),
      );

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
      expect(
        find.text(
          'This draft is shaped for reassurance first, then the next confirmed step.',
        ),
        findsWidgets,
      );
      expect(find.textContaining(approvedDraftText), findsWidgets);
    },
  );

  testWidgets(
    'onyx app shows off-scope client-lane learned approval style in live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('live-ops-offscope-cross-surface-learn-clients-app'),
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );

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

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('live-ops-offscope-lane-reply-clients-app'),
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );

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

      await seedWaterfallPushPressure(
        messageKey: 'waterfall-queued-push-1',
        occurredAtUtc: DateTime.utc(2026, 3, 18, 13, 6),
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

      await seedWaterfallPushPressure(
        messageKey: 'waterfall-admin-to-liveops-push-1',
        occurredAtUtc: DateTime.utc(2026, 3, 18, 13, 9),
      );

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-to-liveops-push-pressure-admin-app'),
      );
      await openAdminSystemAnchor(tester, 'LATEST PUSH DETAIL');

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

      await seedWaterfallTelegramBlockedPushSyncAt(
        occurredAtUtc: DateTime.utc(2026, 3, 18, 13, 11),
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

      await seedWaterfallTelegramBlockedPushSyncAt(
        occurredAtUtc: DateTime.utc(2026, 3, 18, 13, 18),
      );

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-to-liveops-telegram-health-admin-app'),
      );
      await openAdminClientCommsAudit(tester);

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

      await seedWaterfallSmsFallbackPushSync(
        occurredAtUtc: DateTime.utc(2026, 3, 18, 13, 21),
      );

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-to-liveops-sms-fallback-admin-app'),
      );
      await openAdminSystemAnchor(tester, 'LATEST SMS FALLBACK');

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

      await seedWaterfallVoipStagePushSync(
        occurredAtUtc: DateTime.utc(2026, 3, 18, 13, 22),
      );

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-to-liveops-voip-history-admin-app'),
      );
      await openAdminSystemAnchor(tester, 'LATEST VOIP STAGE');

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

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('live-ops-cross-surface-voice-clients-app'),
      );

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

      await savePinnedLaneVoice(profile: 'reassurance-forward');
      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('live-ops-cross-surface-clear-voice-clients-app'),
      );

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

      await saveLegacyLearnedApprovalStyles([
        'Control is checking the latest position now and will share the next confirmed step shortly.',
      ]);
      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('live-ops-cross-surface-clear-learned-clients-app'),
      );

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

      await saveLegacyLearnedApprovalStyles([
        'Control is checking the latest position now and will share the next confirmed step shortly.',
      ]);

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('live-ops-admin-voice-source-app'),
      );
      await openAdminClientCommsAudit(tester);

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

      await saveTelegramAdminRuntimeState({
        ...pendingDraftRuntimeState([
          telegramPendingDraftEntry(
            inboundUpdateId: 901,
            messageThreadId: 88,
            clientId: 'CLIENT-MS-VALLEE',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            sourceText: 'Please update me on the patrol position.',
            originalDraftText:
                'We are checking the latest patrol position now and will send the next verified update shortly.',
            draftText:
                'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
            createdAtUtc: DateTime.utc(2026, 3, 18, 12, 46),
            usedLearnedApprovalStyle: true,
          ),
        ]),
        ...legacyLearnedApprovalRuntimeState([
          'Control is checking the latest position now and will share the next confirmed step shortly.',
        ]),
      });

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('live-ops-admin-clear-learned-source-app'),
      );
      await openAdminPendingDraftReview(tester);

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

      await savePendingTelegramDrafts([
        telegramPendingDraftEntry(
          inboundUpdateId: 902,
          messageThreadId: 88,
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          sourceText: 'Please update me on the patrol position.',
          originalDraftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          draftText:
              'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
          createdAtUtc: DateTime.utc(2026, 3, 18, 12, 47),
        ),
      ]);

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('live-ops-admin-approve-source-app'),
        telegramBridgeServiceOverride: const _SuccessfulTelegramBridgeStub(),
      );
      await openAdminPendingDraftReview(tester);

      final approveButton = find.widgetWithText(FilledButton, 'Approve + Send');
      await tester.ensureVisible(approveButton);
      await tester.tap(approveButton);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-admin-approve-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

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

      await savePendingTelegramDrafts([
        telegramPendingDraftEntry(
          inboundUpdateId: 904,
          messageThreadId: 88,
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          sourceText: 'Please update me on the patrol position.',
          originalDraftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          draftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          createdAtUtc: DateTime.utc(2026, 3, 18, 12, 49),
        ),
      ]);

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('live-ops-admin-reject-source-app'),
      );
      await openAdminPendingDraftReview(tester);

      final rejectButton = find.widgetWithText(OutlinedButton, 'Reject');
      await tester.ensureVisible(rejectButton);
      await tester.tap(rejectButton);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-admin-reject-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'We are checking the latest patrol position now and will send the next verified update shortly.',
        ),
        findsNothing,
      );
    },
  );
}
