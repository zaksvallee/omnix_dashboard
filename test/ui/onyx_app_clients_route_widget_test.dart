import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnix_dashboard/application/client_conversation_repository.dart';
import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/application/dvr_scope_config.dart';
import 'package:omnix_dashboard/application/monitoring_shift_schedule_service.dart';
import 'package:omnix_dashboard/application/monitoring_shift_scope_config.dart';
import 'package:omnix_dashboard/application/sms_delivery_service.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
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

class _RecordingTelegramBridgeStub implements TelegramBridgeService {
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
    return TelegramBridgeSendResult(
      sent: messages,
      failed: const <TelegramBridgeMessage>[],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onyx app stores exact client room handoff from clients page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? openedRoom;
    String? openedClientId;
    String? openedSiteId;

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.clients,
        onClientRoomRouteOpened: (room, clientId, siteId) {
          openedRoom = room;
          openedClientId = clientId;
          openedSiteId = siteId;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Client Operations'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('clients-room-Residents')));
    await tester.pumpAndSettle();

    expect(openedRoom, 'Residents');
    expect(openedClientId, 'CLIENT-MS-VALLEE');
    expect(openedSiteId, 'SITE-MS-VALLEE-RESIDENCE');
  });

  testWidgets('onyx app opens scoped events from clients incident feed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    List<String>? openedEventIds;
    String? openedSelectedEventId;
    String? openedScopeMode;

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.clients,
        onEventsScopeOpened: (eventIds, selectedEventId, scopeMode) {
          openedEventIds = eventIds;
          openedSelectedEventId = selectedEventId;
          openedScopeMode = scopeMode;
        },
      ),
    );
    await tester.pumpAndSettle();

    final incidentResolvedRow = find
        .ancestor(
          of: find.text('Incident Resolved').first,
          matching: find.byType(InkWell),
        )
        .first;
    await tester.ensureVisible(incidentResolvedRow);
    await tester.tap(incidentResolvedRow);
    await tester.pumpAndSettle();

    expect(openedEventIds, <String>['CLOSE-4']);
    expect(openedSelectedEventId, 'CLOSE-4');
    expect(openedScopeMode, isEmpty);
  });

  testWidgets(
    'onyx app handles inbound client quick action through the real telegram path',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bridge = _RecordingTelegramBridgeStub();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-telegram-quick-action-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          appModeOverride: OnyxAppMode.client,
          telegramBridgeServiceOverride: bridge,
          telegramChatIdOverride: 'test-client-chat',
          monitoringShiftScopeConfigsOverride: const <MonitoringShiftScopeConfig>[
            MonitoringShiftScopeConfig(
              clientId: 'CLIENT-MS-VALLEE',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              schedule: MonitoringShiftSchedule(
                enabled: true,
                startHour: 18,
                startMinute: 0,
                endHour: 6,
                endMinute: 0,
              ),
            ),
          ],
          initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
            TelegramBridgeInboundMessage(
              updateId: 9001,
              chatId: 'test-client-chat',
              chatType: 'private',
              text: 'Details',
              sentAtUtc: DateTime.utc(2026, 3, 18, 6, 35),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(bridge.sentMessages, isNotEmpty);
      final quickActionResponse = bridge.sentMessages
          .map((message) => message.text)
          .firstWhere((text) => text.contains('🧾 ONYX STATUS (FULL)'));
      expect(quickActionResponse, contains('Monitoring: STANDBY'));
      expect(quickActionResponse, contains('Window: next watch starts 18:00'));
      expect(
        quickActionResponse,
        contains('Current assessment: field activity active on site'),
      );
    },
  );

  testWidgets(
    'onyx app quick action uses scoped camera zone labels in the reply narrative',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bridge = _RecordingTelegramBridgeStub();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-telegram-zone-aware-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          appModeOverride: OnyxAppMode.client,
          telegramBridgeServiceOverride: bridge,
          telegramChatIdOverride: 'test-client-chat',
          monitoringShiftScopeConfigsOverride: const <MonitoringShiftScopeConfig>[
            MonitoringShiftScopeConfig(
              clientId: 'CLIENT-MS-VALLEE',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              schedule: MonitoringShiftSchedule(
                enabled: true,
                startHour: 18,
                startMinute: 0,
                endHour: 18,
                endMinute: 0,
              ),
            ),
          ],
          dvrScopeConfigsOverride: const <DvrScopeConfig>[
            DvrScopeConfig(
              clientId: 'CLIENT-MS-VALLEE',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              provider: 'hikvision_dvr_monitor_only',
              eventsUri: null,
              authMode: 'digest',
              username: 'admin',
              password: 'secret',
              bearerToken: '',
              cameraLabels: <String, String>{
                'channel-13': 'Front Yard',
                'channel-12': 'Back Yard',
                'channel-6': 'Driveway',
              },
            ),
          ],
          initialStoreEventsOverride: <DispatchEvent>[
            _intel(
              intelligenceId: 'zone-aware-13',
              cameraId: 'channel-13',
              occurredAt: DateTime.utc(2026, 3, 18, 11, 2),
              objectLabel: 'person',
              summary: 'Front-yard movement detected.',
            ),
            _intel(
              intelligenceId: 'zone-aware-12',
              cameraId: 'channel-12',
              occurredAt: DateTime.utc(2026, 3, 18, 11, 1),
              objectLabel: 'person',
              summary: 'Back-yard movement detected.',
            ),
            _intel(
              intelligenceId: 'zone-aware-6',
              cameraId: 'channel-6',
              occurredAt: DateTime.utc(2026, 3, 18, 11, 0),
              objectLabel: 'vehicle',
              summary: 'Driveway movement detected.',
            ),
          ],
          initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
            TelegramBridgeInboundMessage(
              updateId: 9002,
              chatId: 'test-client-chat',
              chatType: 'private',
              text: 'Details',
              sentAtUtc: DateTime.utc(2026, 3, 18, 9, 4),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final quickActionResponse = bridge.sentMessages
          .map((message) => message.text)
          .firstWhere((text) => text.contains('🧾 ONYX STATUS (FULL)'));
      expect(
        quickActionResponse,
        contains(
          'Current site narrative: Recent ONYX review saw 2 person signals across Back Yard and Front Yard, plus 1 vehicle signal across Driveway.',
        ),
      );
      expect(
        quickActionResponse,
        contains('Latest activity source: Front Yard'),
      );
      expect(
        quickActionResponse,
        contains('Latest review summary: Front-yard movement detected.'),
      );
      expect(
        quickActionResponse,
        contains(
          'Current assessment: likely routine distributed field activity',
        ),
      );
    },
  );

  testWidgets('onyx app routes clients push retry through shell callback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var retryTriggeredCount = 0;

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.clients,
        onClientPushRetryTriggered: () {
          retryTriggeredCount += 1;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('clients-retry-push-sync-action')),
    );
    await tester.pumpAndSettle();

    expect(retryTriggeredCount, 1);
  });

  testWidgets(
    'onyx app restores sms fallback audit after clients push retry and restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final conversation = SharedPrefsClientConversationRepository(persistence);
      final nowUtc = DateTime.utc(2026, 3, 18, 12, 45);
      await conversation.savePushQueue(<ClientAppPushDeliveryItem>[
        ClientAppPushDeliveryItem(
          messageKey: 'test-sms-fallback-1',
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
          key: const ValueKey('admin-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Client Comms Audit'),
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
    },
  );

  testWidgets(
    'onyx app retries push sync for an off-scope client lane and persists sms fallback to that scope',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final conversation = ScopedSharedPrefsClientConversationRepository(
        persistence: persistence,
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );
      await conversation.savePushQueue(<ClientAppPushDeliveryItem>[
        ClientAppPushDeliveryItem(
          messageKey: 'offscope-sms-fallback-1',
          title: 'Waterfall delivery check',
          body: 'This queued client update belongs to the Waterfall lane.',
          occurredAt: DateTime.utc(2026, 3, 18, 13, 11),
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'WTF-MAIN',
          targetChannel: ClientAppAcknowledgementChannel.client,
          deliveryProvider: ClientPushDeliveryProvider.inApp,
          priority: true,
          status: ClientPushDeliveryStatus.queued,
        ),
      ]);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-offscope-retry-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-MS-VALLEE',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
          telegramBridgeServiceOverride: const _ConfiguredTelegramBridgeStub(),
          smsDeliveryServiceOverride: const _SuccessfulSmsDeliveryStub(),
          activeContactPhonesResolverOverride: (clientId, siteId) async =>
              clientId == 'CLIENT-MS-VALLEE' && siteId == 'WTF-MAIN'
              ? const <String>['+27825550441', '+27834440442']
              : const <String>[],
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.widgetWithText(TextButton, 'Retry Push Sync'),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Retry Push Sync'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-offscope-retry-audit'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Client Comms Audit'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Cross-scope'), findsWidgets);
      expect(find.textContaining('WTF-MAIN'), findsWidgets);
      expect(find.text('LATEST SMS FALLBACK'), findsWidgets);
      expect(
        find.textContaining(
          'BulkSMS reached 2/2 contacts after telegram target failure.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app restores push sync history into client lane after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final conversation = SharedPrefsClientConversationRepository(persistence);
      await conversation.savePushSyncState(
        ClientPushSyncState(
          statusLabel: 'degraded',
          lastSyncedAtUtc: DateTime.utc(2026, 3, 18, 13, 5),
          failureReason:
              'voip:asterisk staged call for Vallee command desk.',
          retryCount: 0,
          history: <ClientPushSyncAttempt>[
            ClientPushSyncAttempt(
              occurredAt: DateTime.utc(2026, 3, 18, 13, 5),
              status: 'voip-staged',
              failureReason:
                  'voip:asterisk staged call for Vallee command desk.',
              queueSize: 1,
            ),
            ClientPushSyncAttempt(
              occurredAt: DateTime.utc(2026, 3, 18, 13, 4),
              status: 'sms-fallback-ok',
              failureReason:
                  'BulkSMS reached 2/2 contacts after telegram target failure.',
              queueSize: 2,
            ),
          ],
          backendProbeStatusLabel: 'idle',
          backendProbeHistory: const <ClientBackendProbeAttempt>[],
        ),
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-history-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Push Sync: delivery under watch',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Failure: Asterisk staged a call for Vallee command desk.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Last Sync: 13:05 UTC • Retries: 0',
        ),
        findsOneWidget,
      );
      expect(find.text('Push Sync History'), findsOneWidget);
      expect(
        find.textContaining(
          '13:05 UTC • voip staged • queue:1 • Asterisk staged a call for Vallee command desk.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          '13:04 UTC • sms fallback sent • queue:2 • BulkSMS reached 2/2 contacts after telegram target failure.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx app keeps unrelated scoped push sync history out of the default client lane',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveScopedClientAppPushSyncState(
        ClientPushSyncState(
          statusLabel: 'degraded',
          lastSyncedAtUtc: DateTime.utc(2026, 3, 18, 13, 6),
          failureReason:
              'VoIP staging is not configured for Thabo Mokoena yet.',
          retryCount: 0,
          history: <ClientPushSyncAttempt>[
            ClientPushSyncAttempt(
              occurredAt: DateTime.utc(2026, 3, 18, 13, 6),
              status: 'voip-failed',
              failureReason:
                  'VoIP staging is not configured for Thabo Mokoena yet.',
              queueSize: 1,
            ),
          ],
          backendProbeStatusLabel: 'idle',
          backendProbeHistory: const <ClientBackendProbeAttempt>[],
        ),
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-scope-isolation-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Client Ops App'), findsOneWidget);
      expect(
        find.textContaining(
          'VoIP staging is not configured for Thabo Mokoena yet.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'onyx app shows scoped push sync state when the client lane opens on an off-scope route',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveScopedClientAppPushSyncState(
        ClientPushSyncState(
          statusLabel: 'degraded',
          lastSyncedAtUtc: DateTime.utc(2026, 3, 18, 13, 7),
          failureReason:
              'VoIP staging is not configured for Thabo Mokoena yet.',
          retryCount: 1,
          history: <ClientPushSyncAttempt>[
            ClientPushSyncAttempt(
              occurredAt: DateTime.utc(2026, 3, 18, 13, 7),
              status: 'voip-failed',
              failureReason:
                  'VoIP staging is not configured for Thabo Mokoena yet.',
              queueSize: 1,
            ),
          ],
          backendProbeStatusLabel: 'failed',
          backendProbeLastRunAtUtc: DateTime.utc(2026, 3, 18, 13, 8),
          backendProbeFailureReason: 'Probe marker readback failed.',
          backendProbeHistory: <ClientBackendProbeAttempt>[
            ClientBackendProbeAttempt(
              occurredAt: DateTime.utc(2026, 3, 18, 13, 8),
              status: 'failed',
              failureReason: 'Probe marker readback failed.',
            ),
          ],
        ),
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-off-scope-state-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-MS-VALLEE',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Client Ops App — CLIENT-MS-VALLEE / WTF-MAIN'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Push Sync: degraded',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Failure: VoIP staging is not configured for Thabo Mokoena yet.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Last Sync: 13:07 UTC • Retries: 1',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Backend Probe: failed • Last Run: 13:08 UTC',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Probe marker readback failed.'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app runs and clears backend probe for an off-scope client lane across restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-offscope-probe-run'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-MS-VALLEE',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.widgetWithText(TextButton, 'Run Backend Probe'),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Run Backend Probe'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-offscope-probe-restart'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-MS-VALLEE',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Backend Probe: ok • Last Run:'),
        findsOneWidget,
      );
      expect(find.textContaining('ok'), findsWidgets);

      await tester.ensureVisible(
        find.widgetWithText(TextButton, 'Clear Probe History'),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Clear Probe History'));
      await tester.pumpAndSettle();
      expect(find.text('Clear Probe History?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-offscope-probe-cleared'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-MS-VALLEE',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Backend Probe: idle • Last Run: none'),
        findsOneWidget,
      );
      expect(
        find.text('Backend Probe History: no runs yet.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx app restores scoped push queue and acknowledgements into an off-scope client lane',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final conversation = ScopedSharedPrefsClientConversationRepository(
        persistence: persistence,
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );
      const messageKey = 'route-scope-queue-1';
      await conversation.savePushQueue(<ClientAppPushDeliveryItem>[
        ClientAppPushDeliveryItem(
          messageKey: messageKey,
          title: 'Scoped queue update',
          body: 'Waterfall lane is holding this queued update for client review.',
          occurredAt: DateTime.utc(2026, 3, 18, 13, 9),
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'WTF-MAIN',
          targetChannel: ClientAppAcknowledgementChannel.client,
          deliveryProvider: ClientPushDeliveryProvider.inApp,
          priority: true,
          status: ClientPushDeliveryStatus.queued,
        ),
      ]);
      await conversation.saveAcknowledgements(<ClientAppAcknowledgement>[
        ClientAppAcknowledgement(
          messageKey: messageKey,
          channel: ClientAppAcknowledgementChannel.client,
          acknowledgedBy: 'Client',
          acknowledgedAt: DateTime.utc(2026, 3, 18, 13, 10),
        ),
      ]);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-off-scope-queue-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-MS-VALLEE',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Client Ops App — CLIENT-MS-VALLEE / WTF-MAIN'),
        findsOneWidget,
      );
      expect(find.text('Scoped queue update'), findsOneWidget);
      expect(
        find.text(
          'Waterfall lane is holding this queued update for client review.',
        ),
        findsOneWidget,
      );
      expect(find.text('Delivered'), findsWidgets);
      expect(
        find.text('Client Ops App — CLIENT-MS-VALLEE / SITE-MS-VALLEE-RESIDENCE'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'onyx app restores scoped telegram bridge health into an off-scope client lane',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final conversation = ScopedSharedPrefsClientConversationRepository(
        persistence: persistence,
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );
      await conversation.savePushSyncState(
        ClientPushSyncState(
          statusLabel: 'failed',
          lastSyncedAtUtc: DateTime.utc(2026, 3, 18, 13, 12),
          failureReason:
              'Telegram bridge failed for 1/1 message(s). Reasons: BLOCKED_BY_TEST_STUB',
          retryCount: 1,
          history: <ClientPushSyncAttempt>[
            ClientPushSyncAttempt(
              occurredAt: DateTime.utc(2026, 3, 18, 13, 12),
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
          key: const ValueKey('clients-off-scope-telegram-health-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-MS-VALLEE',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Client Ops App — CLIENT-MS-VALLEE / WTF-MAIN'),
        findsOneWidget,
      );
      expect(find.text('Telegram: BLOCKED'), findsOneWidget);
      expect(find.text('Telegram fallback is active.'), findsOneWidget);
      expect(
        find.textContaining(
          'Telegram could not deliver 1/1 client update. Bridge reported: BLOCKED_BY_TEST_STUB.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app carries off-scope push pressure from admin audit into the exact client lane after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final conversation = ScopedSharedPrefsClientConversationRepository(
        persistence: persistence,
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );
      final occurredAtUtc = DateTime.utc(2026, 3, 18, 13, 16);
      await conversation.savePushQueue(<ClientAppPushDeliveryItem>[
        ClientAppPushDeliveryItem(
          messageKey: 'waterfall-admin-to-client-push-1',
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
      await conversation.savePushSyncState(
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
          key: const ValueKey('admin-to-client-push-pressure-admin-app'),
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
      expect(
        find.textContaining(
          'Waterfall push sync needs operator review before retry.',
        ),
        findsWidgets,
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-to-client-push-pressure-client-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-MS-VALLEE',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Client Ops App — CLIENT-MS-VALLEE / WTF-MAIN'),
        findsOneWidget,
      );
      expect(find.text('Push Sync: needs review'), findsWidgets);
      expect(find.text('Push Sync History'), findsOneWidget);
      expect(
        find.textContaining('13:16 UTC • needs review • queue:1'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Waterfall push sync needs operator review before retry.'),
        findsWidgets,
      );
      expect(find.text('Waterfall delivery check'), findsOneWidget);
      expect(
        find.text('Queued client update for the Waterfall lane.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx app carries off-scope telegram health from admin audit into the exact client lane after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final conversation = ScopedSharedPrefsClientConversationRepository(
        persistence: persistence,
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );
      final occurredAtUtc = DateTime.utc(2026, 3, 18, 13, 19);
      await conversation.savePushSyncState(
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
          key: const ValueKey('admin-to-client-telegram-health-admin-app'),
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
          'Telegram bridge failed for 1/1 message(s). Reasons: BLOCKED_BY_TEST_STUB',
        ),
        findsWidgets,
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-to-client-telegram-health-client-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-MS-VALLEE',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Client Ops App — CLIENT-MS-VALLEE / WTF-MAIN'),
        findsOneWidget,
      );
      expect(find.text('Telegram: BLOCKED'), findsOneWidget);
      expect(find.text('Telegram fallback is active.'), findsOneWidget);
      expect(
        find.textContaining(
          'Telegram could not deliver 1/1 client update. Bridge reported: BLOCKED_BY_TEST_STUB.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app carries off-scope sms fallback from admin audit into the exact client lane after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final conversation = ScopedSharedPrefsClientConversationRepository(
        persistence: persistence,
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );
      final occurredAtUtc = DateTime.utc(2026, 3, 18, 13, 23);
      await conversation.savePushSyncState(
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
          key: const ValueKey('admin-to-client-sms-fallback-admin-app'),
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
          key: const ValueKey('admin-to-client-sms-fallback-client-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-MS-VALLEE',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Client Ops App — CLIENT-MS-VALLEE / WTF-MAIN'),
        findsOneWidget,
      );
      expect(find.text('Push Sync: delivery under watch'), findsWidgets);
      expect(
        find.textContaining(
          'BulkSMS reached 2/2 contacts after telegram target failure.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app carries off-scope voip history from admin audit into the exact client lane after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final conversation = ScopedSharedPrefsClientConversationRepository(
        persistence: persistence,
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );
      final occurredAtUtc = DateTime.utc(2026, 3, 18, 13, 24);
      await conversation.savePushSyncState(
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
          key: const ValueKey('admin-to-client-voip-history-admin-app'),
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
          key: const ValueKey('admin-to-client-voip-history-client-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-MS-VALLEE',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Client Ops App — CLIENT-MS-VALLEE / WTF-MAIN'),
        findsOneWidget,
      );
      expect(find.text('Push Sync: delivery under watch'), findsWidgets);
      expect(
        find.textContaining('Asterisk staged a call for Waterfall command desk.'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app keeps off-scope client acknowledgements on the routed lane after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-off-scope-ack-run'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-MS-VALLEE',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Client Ack').first);
      await tester.tap(find.text('Client Ack').first);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-off-scope-ack-restart'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-MS-VALLEE',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Client Ops App — CLIENT-MS-VALLEE / WTF-MAIN'),
        findsOneWidget,
      );
      expect(find.text('Delivered'), findsWidgets);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-default-ack-isolation'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Client Ops App — CLIENT-MS-VALLEE / SITE-MS-VALLEE-RESIDENCE'),
        findsOneWidget,
      );
      expect(find.text('Delivered'), findsNothing);
    },
  );

  testWidgets(
    'onyx app keeps off-scope manual client messages on the routed lane after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const manualMessage =
          'Waterfall lane manual update: resident confirmed access gate is clear.';

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-off-scope-message-run'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-MS-VALLEE',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, manualMessage);
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Send'));
      await tester.tap(find.widgetWithText(FilledButton, 'Send'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-off-scope-message-restart'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-MS-VALLEE',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Client Ops App — CLIENT-MS-VALLEE / WTF-MAIN'),
        findsOneWidget,
      );
      expect(find.text(manualMessage), findsWidgets);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-default-message-isolation'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Client Ops App — CLIENT-MS-VALLEE / SITE-MS-VALLEE-RESIDENCE'),
        findsOneWidget,
      );
      expect(find.text(manualMessage), findsNothing);
    },
  );

  testWidgets(
    'onyx app restores learned approval style into client control lane after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
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
        'ai_approved_rewrite_examples_by_scope': {
          'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE': <String>[
            'Control is checking the latest position now and will share the next confirmed step shortly.',
          ],
        },
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-learned-style-app'),
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

      await tester.scrollUntilVisible(
        find.text('Learned approval style'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('ONYX mode: Pinned voice + learned approvals'),
        findsOneWidget,
      );
      expect(find.text('Pinned voice Reassuring'), findsOneWidget);
      expect(find.text('Learned approvals (1)'), findsOneWidget);
      expect(find.text('Learned approval style'), findsOneWidget);
      expect(
        find.textContaining(
          'Control is checking the latest position now and will share the next confirmed step shortly.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx app restores pinned voice into client control lane after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
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
          key: const ValueKey('clients-voice-app'),
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

      await tester.scrollUntilVisible(
        find.textContaining('ONYX mode: Pinned voice'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Lane voice: Reassuring'), findsOneWidget);
      expect(find.text('ONYX mode: Pinned voice'), findsOneWidget);
      expect(find.text('Pinned voice Reassuring'), findsOneWidget);
      expect(find.text('Learned approval style'), findsNothing);
    },
  );

  testWidgets(
    'onyx app learns from reviewed client control draft sends after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
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
          key: const ValueKey('clients-learn-review-app'),
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
          key: const ValueKey('clients-learn-review-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      final restartedControlViewChip = find.text('Control View');
      if (restartedControlViewChip.evaluate().isNotEmpty) {
        await tester.ensureVisible(restartedControlViewChip.first);
        await tester.tap(restartedControlViewChip.first);
        await tester.pumpAndSettle();
      }

      await tester.scrollUntilVisible(
        find.text('Learned approval style'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('ONYX mode: Learned approvals'), findsOneWidget);
      expect(find.text('Learned approvals (1)'), findsOneWidget);
      expect(find.text('Learned approval style'), findsOneWidget);
      expect(find.textContaining(approvedDraftText), findsWidgets);
    },
  );

  testWidgets(
    'onyx app keeps off-scope reviewed draft learning on the routed control lane after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
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
          key: const ValueKey('clients-offscope-learn-review-app'),
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
          key: const ValueKey('clients-offscope-learn-review-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-MS-VALLEE',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      final restartedControlViewChip = find.text('Control View');
      if (restartedControlViewChip.evaluate().isNotEmpty) {
        await tester.ensureVisible(restartedControlViewChip.first);
        await tester.tap(restartedControlViewChip.first);
        await tester.pumpAndSettle();
      }

      await tester.scrollUntilVisible(
        find.text('Learned approval style'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Security Desk Console — CLIENT-MS-VALLEE / WTF-MAIN'),
        findsOneWidget,
      );
      expect(find.text('ONYX mode: Learned approvals'), findsOneWidget);
      expect(find.text('Learned approvals (1)'), findsOneWidget);
      expect(find.textContaining(approvedDraftText), findsWidgets);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-default-learn-review-isolation'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      final defaultControlViewChip = find.text('Control View');
      if (defaultControlViewChip.evaluate().isNotEmpty) {
        await tester.ensureVisible(defaultControlViewChip.first);
        await tester.tap(defaultControlViewChip.first);
        await tester.pumpAndSettle();
      }

      expect(
        find.text(
          'Security Desk Console — CLIENT-MS-VALLEE / SITE-MS-VALLEE-RESIDENCE',
        ),
        findsOneWidget,
      );
      expect(find.text('Learned approval style'), findsNothing);
      expect(find.textContaining(approvedDraftText), findsNothing);
    },
  );

  testWidgets(
    'onyx app keeps off-scope control manual updates on the routed lane after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
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
          key: const ValueKey('clients-offscope-control-update-app'),
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
          key: const ValueKey('clients-offscope-control-update-restart'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-MS-VALLEE',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      final restartedControlViewChip = find.text('Control View');
      if (restartedControlViewChip.evaluate().isNotEmpty) {
        await tester.ensureVisible(restartedControlViewChip.first);
        await tester.tap(restartedControlViewChip.first);
        await tester.pumpAndSettle();
      }

      expect(
        find.text('Security Desk Console — CLIENT-MS-VALLEE / WTF-MAIN'),
        findsOneWidget,
      );
      expect(find.textContaining(controlUpdateBody), findsWidgets);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-default-control-update-isolation'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      final defaultControlViewChip = find.text('Control View');
      if (defaultControlViewChip.evaluate().isNotEmpty) {
        await tester.ensureVisible(defaultControlViewChip.first);
        await tester.tap(defaultControlViewChip.first);
        await tester.pumpAndSettle();
      }

      expect(
        find.text(
          'Security Desk Console — CLIENT-MS-VALLEE / SITE-MS-VALLEE-RESIDENCE',
        ),
        findsOneWidget,
      );
      expect(find.textContaining(controlUpdateBody), findsNothing);
    },
  );

  testWidgets(
    'onyx app reflects admin lane voice changes in client control lane after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
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
          key: const ValueKey('clients-admin-voice-source-app'),
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
          key: const ValueKey('clients-admin-voice-restart-app'),
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

      await tester.scrollUntilVisible(
        find.text('Learned approval style'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Lane voice: Reassuring'), findsOneWidget);
      expect(
        find.text('ONYX mode: Pinned voice + learned approvals'),
        findsOneWidget,
      );
      expect(find.text('Pinned voice Reassuring'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app reflects admin learned-style clearing in client control lane after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
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
        'ai_pending_drafts': <Map<String, Object?>>[
          {
            'inbound_update_id': 801,
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
            'created_at_utc': DateTime.utc(2026, 3, 18, 12, 45)
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
          key: const ValueKey('clients-admin-clear-learned-source-app'),
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
          key: const ValueKey('clients-admin-clear-learned-restart-app'),
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

      expect(find.text('Learned approval style'), findsNothing);
      expect(find.text('Learned approvals (1)'), findsNothing);
      expect(find.text('Pinned voice Reassuring'), findsNothing);
      expect(find.text('ONYX mode: Auto'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app reflects live operations lane voice changes in client control lane after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
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
          key: const ValueKey('clients-live-ops-voice-source-app'),
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
          key: const ValueKey('clients-live-ops-voice-restart-app'),
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

      await tester.scrollUntilVisible(
        find.textContaining('ONYX mode: Pinned voice'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Lane voice: Reassuring'), findsOneWidget);
      expect(find.text('ONYX mode: Pinned voice'), findsOneWidget);
      expect(find.text('Pinned voice Reassuring'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app reflects live operations learned-style clearing in client control lane after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
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
          key: const ValueKey('clients-live-ops-clear-learned-source-app'),
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
          key: const ValueKey('clients-live-ops-clear-learned-restart-app'),
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

      expect(find.text('Learned approval style'), findsNothing);
      expect(find.text('Learned approvals (1)'), findsNothing);
      expect(find.text('ONYX mode: Auto'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app renders the exact off-scope ask lane in the real client surface',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
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
          key: const ValueKey('clients-off-scope-ask-lane-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-MS-VALLEE',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Client Ops App — CLIENT-MS-VALLEE / WTF-MAIN'),
        findsOneWidget,
      );
      expect(
        find.text('Client Ops App — CLIENT-MS-VALLEE / SITE-MS-VALLEE-RESIDENCE'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'onyx app keeps pending telegram ai drafts on command surfaces and out of the client lane',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
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
        'ai_pending_drafts': <Map<String, Object?>>[
          {
            'inbound_update_id': 906,
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
            'created_at_utc': DateTime.utc(2026, 3, 18, 12, 51)
                .toIso8601String(),
          },
        ],
      });

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-command-only-pending-draft-app'),
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

      expect(find.text('CLIENT ASKED'), findsNothing);
      expect(find.text('ONYX WILL SAY'), findsNothing);
      expect(find.text('Awaiting human sign-off'), findsNothing);
      expect(find.text('Pending ONYX Draft'), findsNothing);
    },
  );
}

IntelligenceReceived _intel({
  required String intelligenceId,
  required String cameraId,
  required DateTime occurredAt,
  required String objectLabel,
  required String summary,
}) {
  return IntelligenceReceived(
    eventId: 'evt-$intelligenceId',
    sequence: 1,
    version: 1,
    occurredAt: occurredAt,
    intelligenceId: intelligenceId,
    provider: 'hikvision_dvr_monitor_only',
    sourceType: 'dvr',
    externalId: 'ext-$intelligenceId',
    clientId: 'CLIENT-MS-VALLEE',
    regionId: 'REGION-GAUTENG',
    siteId: 'SITE-MS-VALLEE-RESIDENCE',
    cameraId: cameraId,
    objectLabel: objectLabel,
    objectConfidence: 0.9,
    headline: 'Zone-aware movement',
    summary: summary,
    riskScore: 68,
    snapshotUrl: null,
    canonicalHash: 'hash-$intelligenceId',
  );
}
