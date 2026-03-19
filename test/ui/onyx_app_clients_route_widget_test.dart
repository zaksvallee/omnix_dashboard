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
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
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

    expect(find.textContaining('Client Communications'), findsOneWidget);

    final residentsRoom = find.byKey(const ValueKey('clients-room-Residents'));
    await tester.scrollUntilVisible(
      residentsRoom,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(residentsRoom);
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
          monitoringShiftScopeConfigsOverride:
              const <MonitoringShiftScopeConfig>[
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
      expect(quickActionResponse, contains('Current status'));
      expect(quickActionResponse, contains('Monitoring is '));
      expect(quickActionResponse, contains('Watch window:'));
      expect(quickActionResponse, contains('Remote watch: available'));
      expect(
        quickActionResponse,
        contains('Assessment: routine on-site team activity is visible'),
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
          monitoringShiftScopeConfigsOverride:
              const <MonitoringShiftScopeConfig>[
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
              occurredAt: DateTime.utc(2026, 3, 19, 5, 59),
              objectLabel: 'person',
              summary: 'Front-yard movement detected.',
            ),
            _intel(
              intelligenceId: 'zone-aware-12',
              cameraId: 'channel-12',
              occurredAt: DateTime.utc(2026, 3, 19, 5, 58),
              objectLabel: 'person',
              summary: 'Back-yard movement detected.',
            ),
            _intel(
              intelligenceId: 'zone-aware-6',
              cameraId: 'channel-6',
              occurredAt: DateTime.utc(2026, 3, 19, 5, 57),
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
          'Summary: Recent camera review saw 2 person signals across Back Yard and Front Yard, plus 1 vehicle signal across Driveway.',
        ),
      );
      expect(quickActionResponse, contains('Latest signal: Front Yard'));
      expect(
        quickActionResponse,
        contains('Review note: Front-yard movement detected.'),
      );
      expect(
        quickActionResponse,
        contains('Assessment: likely routine on-site team activity'),
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

      await seedDefaultValleeQueuedDelivery(
        messageKey: 'test-sms-fallback-1',
        occurredAtUtc: DateTime.utc(2026, 3, 18, 12, 45),
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

      await tester.tap(
        find.byKey(const ValueKey('clients-retry-push-sync-action')),
      );
      await tester.pumpAndSettle();

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-app'),
      );
      await openAdminClientCommsAudit(tester);

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

      await seedWaterfallQueuedDelivery(
        messageKey: 'offscope-sms-fallback-1',
        occurredAtUtc: DateTime.utc(2026, 3, 18, 13, 11),
        body: 'This queued client update belongs to the Waterfall lane.',
      );

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

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-offscope-retry-audit'),
      );
      await openAdminClientCommsAudit(tester);

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

      await seedDefaultValleeVoipAndSmsFallbackHistory();

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
        find.textContaining('Push Sync: delivery under watch'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Failure: Asterisk staged a call for Vallee command desk.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Last Sync: 13:05 UTC • Retries: 0'),
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

      await seedWaterfallScopedVoipFailurePushSync(
        occurredAtUtc: DateTime.utc(2026, 3, 18, 13, 6),
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

      await seedWaterfallScopedVoipFailurePushSync(
        occurredAtUtc: DateTime.utc(2026, 3, 18, 13, 7),
        retryCount: 1,
        backendProbeOccurredAtUtc: DateTime.utc(2026, 3, 18, 13, 8),
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
        find.textContaining('Push Sync: delivery under watch'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Failure: VoIP staging is not configured for Thabo Mokoena yet.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Last Sync: 13:07 UTC • Retries: 1'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Backend Probe: failed • Last Run: 13:08 UTC'),
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

      expect(find.text('Backend Probe: idle • Last Run: none'), findsOneWidget);
      expect(find.text('Backend Probe History: no runs yet.'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app restores scoped push queue and acknowledgements into an off-scope client lane',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const messageKey = 'route-scope-queue-1';
      await seedWaterfallQueuedDelivery(
        messageKey: messageKey,
        occurredAtUtc: DateTime.utc(2026, 3, 19, 6, 45),
        title: 'Scoped queue update',
        body: 'Waterfall lane is holding this queued update for client review.',
        status: ClientPushDeliveryStatus.acknowledged,
        acknowledgedAtUtc: DateTime.utc(2026, 3, 19, 6, 40),
      );

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
        find.text(
          'Client Ops App — CLIENT-MS-VALLEE / SITE-MS-VALLEE-RESIDENCE',
        ),
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

      await seedWaterfallTelegramBlockedPushSyncAt(
        occurredAtUtc: DateTime.utc(2026, 3, 18, 13, 12),
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

      await seedWaterfallPushPressure(
        messageKey: 'waterfall-admin-to-client-push-1',
        occurredAtUtc: DateTime.utc(2026, 3, 18, 13, 16),
      );

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-to-client-push-pressure-admin-app'),
      );
      await openAdminSystemAnchor(tester, 'LATEST PUSH DETAIL');

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
        find.textContaining(
          'Waterfall push sync needs operator review before retry.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app carries off-scope telegram health from admin audit into the exact client lane after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await seedWaterfallTelegramBlockedPushSync();

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-to-client-telegram-health-admin-app'),
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

      await seedWaterfallSmsFallbackPushSync(
        occurredAtUtc: DateTime.utc(2026, 3, 18, 13, 23),
      );

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-to-client-sms-fallback-admin-app'),
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

      await seedWaterfallVoipStagePushSync(
        occurredAtUtc: DateTime.utc(2026, 3, 18, 13, 24),
      );

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-to-client-voip-history-admin-app'),
      );
      await openAdminSystemAnchor(tester, 'LATEST VOIP STAGE');

      expect(find.text('Client Comms Audit'), findsOneWidget);
      expect(find.text('LATEST VOIP STAGE'), findsWidgets);
      expect(
        find.textContaining(
          'Asterisk staged a call for Waterfall command desk.',
        ),
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
        find.textContaining(
          'Asterisk staged a call for Waterfall command desk.',
        ),
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
        find.text(
          'Client Ops App — CLIENT-MS-VALLEE / SITE-MS-VALLEE-RESIDENCE',
        ),
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
        find.text(
          'Client Ops App — CLIENT-MS-VALLEE / SITE-MS-VALLEE-RESIDENCE',
        ),
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

      await saveTelegramAdminRuntimeState({
        ...pinnedLaneVoiceRuntimeState(profile: 'reassurance-forward'),
        ...legacyLearnedApprovalRuntimeState(const <String>[
          'Control is checking the latest position now and will share the next confirmed step shortly.',
        ]),
      });
      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('clients-learned-style-app'),
      );

      await openClientControlAnchor(tester, 'Learned approval style');

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

      await savePinnedLaneVoice(profile: 'reassurance-forward');
      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('clients-voice-app'),
      );

      await openClientControlAnchor(tester, 'ONYX mode: Pinned voice');

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

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('clients-learn-review-app'),
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

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('clients-learn-review-restart-app'),
      );

      await openClientControlAnchor(tester, 'Learned approval style');

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

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('clients-offscope-learn-review-app'),
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

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('clients-offscope-learn-review-restart-app'),
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );

      await openClientControlAnchor(tester, 'Learned approval style');

      expect(
        find.text('Security Desk Console — CLIENT-MS-VALLEE / WTF-MAIN'),
        findsOneWidget,
      );
      expect(find.text('ONYX mode: Learned approvals'), findsOneWidget);
      expect(find.text('Learned approvals (1)'), findsOneWidget);
      expect(find.textContaining(approvedDraftText), findsWidgets);

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('clients-default-learn-review-isolation'),
      );

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

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('clients-offscope-control-update-app'),
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

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('clients-offscope-control-update-restart'),
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );

      expect(
        find.text('Security Desk Console — CLIENT-MS-VALLEE / WTF-MAIN'),
        findsOneWidget,
      );
      expect(find.textContaining(controlUpdateBody), findsWidgets);

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('clients-default-control-update-isolation'),
      );

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

      await saveLegacyLearnedApprovalStyles(const <String>[
        'Control is checking the latest position now and will share the next confirmed step shortly.',
      ]);

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('clients-admin-voice-source-app'),
      );
      await openAdminClientCommsAudit(tester);

      final reassuringButton = find.widgetWithText(
        OutlinedButton,
        'Reassuring',
      );
      await tester.ensureVisible(reassuringButton.first);
      await tester.tap(reassuringButton.first);
      await tester.pumpAndSettle();

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('clients-admin-voice-restart-app'),
      );

      await openClientControlAnchor(tester, 'Learned approval style');

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

      await saveTelegramAdminRuntimeState({
        ...pendingDraftRuntimeState([
          telegramPendingDraftEntry(
            inboundUpdateId: 801,
            messageThreadId: 88,
            clientId: 'CLIENT-MS-VALLEE',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            sourceText: 'Please update me on the patrol position.',
            originalDraftText:
                'We are checking the latest patrol position now and will send the next verified update shortly.',
            draftText:
                'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
            createdAtUtc: DateTime.utc(2026, 3, 18, 12, 45),
            usedLearnedApprovalStyle: true,
          ),
        ]),
        ...legacyLearnedApprovalRuntimeState(const <String>[
          'Control is checking the latest position now and will share the next confirmed step shortly.',
        ]),
      });

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('clients-admin-clear-learned-source-app'),
      );
      await openAdminPendingDraftReview(tester);

      final clearLearnedStyleButton = find.widgetWithText(
        OutlinedButton,
        'Clear Learned Style',
      );
      await tester.ensureVisible(clearLearnedStyleButton.first);
      await tester.tap(clearLearnedStyleButton.first);
      await tester.pumpAndSettle();

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('clients-admin-clear-learned-restart-app'),
      );

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

      await pumpLiveOperationsSourceApp(
        tester,
        key: const ValueKey('clients-live-ops-voice-source-app'),
      );

      final reassuringButton = find.widgetWithText(
        OutlinedButton,
        'Reassuring',
      );
      await tester.ensureVisible(reassuringButton.first);
      await tester.tap(reassuringButton.first);
      await tester.pumpAndSettle();

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('clients-live-ops-voice-restart-app'),
      );
      await openClientControlAnchor(tester, 'ONYX mode: Pinned voice');

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

      await saveLegacyLearnedApprovalStyles(const <String>[
        'Control is checking the latest position now and will share the next confirmed step shortly.',
      ]);

      await pumpLiveOperationsSourceApp(
        tester,
        key: const ValueKey('clients-live-ops-clear-learned-source-app'),
      );

      final clearLearnedStyleButton = find.widgetWithText(
        OutlinedButton,
        'Clear Learned Style',
      );
      await tester.ensureVisible(clearLearnedStyleButton.first);
      await tester.tap(clearLearnedStyleButton.first);
      await tester.pumpAndSettle();

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('clients-live-ops-clear-learned-restart-app'),
      );

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
        find.text(
          'Client Ops App — CLIENT-MS-VALLEE / SITE-MS-VALLEE-RESIDENCE',
        ),
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

      await savePendingTelegramDrafts([
        telegramPendingDraftEntry(
          inboundUpdateId: 906,
          messageThreadId: 88,
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          sourceText: 'Please update me on the patrol position.',
          originalDraftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          draftText:
              'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
          providerLabel: 'openai:gpt-4.1-mini',
          createdAtUtc: DateTime.utc(2026, 3, 18, 12, 51),
        ),
      ]);
      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('clients-command-only-pending-draft-app'),
      );

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
