import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnix_dashboard/application/client_conversation_repository.dart';
import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/application/sms_delivery_service.dart';
import 'package:omnix_dashboard/application/telegram_bridge_service.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/admin_page.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/client_app_page.dart';
import 'package:omnix_dashboard/ui/dispatch_page.dart';
import 'package:omnix_dashboard/ui/events_review_page.dart';
import 'package:omnix_dashboard/ui/live_operations_page.dart';
import 'package:omnix_dashboard/ui/risk_intelligence_page.dart';
import 'package:omnix_dashboard/ui/sovereign_ledger_page.dart';
import 'package:omnix_dashboard/ui/vip_protection_page.dart';

import 'support/admin_route_state_harness.dart';
import 'support/admin_route_test_harness.dart';

DateTime _liveOperationsTestOccurredAtUtc(int hour, int minute) =>
    DateTime.utc(2026, 3, 18, hour, minute);

DateTime _liveOperationsPendingDraftCreatedAtUtc(int minute) =>
    _liveOperationsTestOccurredAtUtc(12, minute);

DateTime _liveOperationsRouteOccurredAtUtc(int minute) =>
    _liveOperationsPendingDraftCreatedAtUtc(minute);

DateTime _liveOperationsOffScopeSyncOccurredAtUtc(int minute) =>
    _liveOperationsTestOccurredAtUtc(13, minute);

DateTime _liveOperationsOffScopeOccurredAtUtc(int minute) =>
    DateTime.utc(2026, 3, 19, 6, minute);

DateTime _liveOperationsScenarioNowUtc() => DateTime.now().toUtc();

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

  @override
  Future<void> sendVoiceMessage(
    String chatId,
    Uint8List audioBytes, {
    int? messageThreadId,
  }) async {}
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

  @override
  Future<void> sendVoiceMessage(
    String chatId,
    Uint8List audioBytes, {
    int? messageThreadId,
  }) async {}
}

Future<void> _openClientsDetailedWorkspaceIfPresent(WidgetTester tester) async {
  final toggle = find.byKey(
    const ValueKey('clients-toggle-detailed-workspace'),
  );
  if (toggle.evaluate().isEmpty) {
    return;
  }
  await tester.ensureVisible(toggle.first);
  await tester.tap(toggle.first);
  await tester.pumpAndSettle();
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

Future<void> _openLiveOpsDetailedWorkspaceIfPresent(WidgetTester tester) async {
  final toggle = find.byKey(
    const ValueKey('live-operations-toggle-detailed-workspace'),
  );
  if (toggle.evaluate().isEmpty) {
    return;
  }
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

Future<void> _showLiveOpsOverviewIfNeeded(WidgetTester tester) async {
  final currentFocus = find.byKey(
    const ValueKey('live-operations-command-current-focus'),
  );
  final quickOpen = find.byKey(
    const ValueKey('live-operations-command-quick-open'),
  );
  if (currentFocus.evaluate().isNotEmpty || quickOpen.evaluate().isNotEmpty) {
    return;
  }
  final toggle = find.byKey(
    const ValueKey('live-operations-toggle-detailed-workspace'),
  );
  if (toggle.evaluate().isEmpty) {
    return;
  }
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

Future<void> _openDispatchDetailedWorkspaceIfPresent(
  WidgetTester tester,
) async {
  final toggle = find.byKey(
    const ValueKey('dispatch-toggle-detailed-workspace'),
  );
  if (toggle.evaluate().isEmpty) {
    return;
  }
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onyx app opens dispatch warm from signed live ops evidence', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.ledger,
        initialPinnedLedgerAuditEntryOverride: SovereignLedgerPinnedAuditEntry(
          auditId: 'OPS-AUDIT-DISPATCH-1',
          clientId: 'CLIENT-DEMO',
          siteId: 'SITE-DEMO',
          recordCode: 'OB-AUDIT',
          title: 'Dispatch board opened from Live Ops.',
          description:
              'Opened the dispatch board for DSP-2442 from the Live Ops war room.',
          occurredAt: DateTime.utc(2026, 3, 27, 22, 52),
          actorLabel: 'Control-1',
          sourceLabel: 'Live Ops War Room',
          hash: 'liveopsdispatchhash1',
          previousHash: 'liveopsdispatchprev1',
          accent: const Color(0xFF8FD1FF),
          payload: const <String, Object?>{
            'type': 'live_ops_auto_audit',
            'action': 'dispatch_handoff_opened',
            'dispatch_id': 'DSP-2442',
            'incident_reference': 'INC-DSP-2442',
            'source_route': 'dashboard',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sovereign Ledger'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-open-live-ops-dispatch')),
    );
    await tester.tap(
      find.byKey(const ValueKey('ledger-entry-open-live-ops-dispatch')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DispatchPage), findsOneWidget);
    await _openDispatchDetailedWorkspaceIfPresent(tester);

    expect(
      find.byKey(const ValueKey('dispatch-workspace-command-receipt')),
      findsOneWidget,
    );
    expect(find.text('EVIDENCE RETURN'), findsOneWidget);
    expect(
      find.text('Returned to dispatch board for DSP-2442.'),
      findsOneWidget,
    );
  });

  testWidgets('onyx app returns to live ops warm from signed live ops evidence', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.ledger,
        initialPinnedLedgerAuditEntryOverride: SovereignLedgerPinnedAuditEntry(
          auditId: 'OPS-AUDIT-RETURN-1',
          clientId: 'CLIENT-DEMO',
          siteId: 'SITE-DEMO',
          recordCode: 'OB-AUDIT',
          title: 'Dispatch board opened from Live Ops.',
          description:
              'Opened the dispatch board for DSP-2442 from the Live Ops war room.',
          occurredAt: DateTime.utc(2026, 3, 27, 22, 53),
          actorLabel: 'Control-1',
          sourceLabel: 'Live Ops War Room',
          hash: 'liveopsreturnhash1',
          previousHash: 'liveopsreturnprev1',
          accent: const Color(0xFF8FD1FF),
          payload: const <String, Object?>{
            'type': 'live_ops_auto_audit',
            'action': 'dispatch_handoff_opened',
            'dispatch_id': 'DSP-2442',
            'incident_reference': 'INC-DSP-2442',
            'source_route': 'dashboard',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sovereign Ledger'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-back-to-war-room')),
    );
    await tester.tap(
      find.byKey(const ValueKey('ledger-entry-back-to-war-room')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LiveOperationsPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('live-operations-command-center-hero')),
      findsOneWidget,
    );
    expect(find.text('Active Incident: INC-DSP-2442'), findsOneWidget);
    expect(
      tester
          .widget<LiveOperationsPage>(find.byType(LiveOperationsPage))
          .focusIncidentReference,
      'INC-DSP-2442',
    );
    expect(
      tester
          .widget<LiveOperationsPage>(find.byType(LiveOperationsPage))
          .initialScopeClientId,
      'CLIENT-DEMO',
    );
    expect(
      tester
          .widget<LiveOperationsPage>(find.byType(LiveOperationsPage))
          .initialScopeSiteId,
      'SITE-DEMO',
    );
  });

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
          initialStoreEventsOverride: [
            DecisionCreated(
              eventId: 'decision-agent-return-route',
              sequence: 4301,
              version: 1,
              occurredAt: _liveOperationsTestOccurredAtUtc(14, 20),
              dispatchId: 'DSP-4',
              clientId: 'CLIENT-DEMO',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-DEMO',
            ),
            IntelligenceReceived(
              eventId: 'intel-agent-return-route',
              sequence: 4302,
              version: 1,
              occurredAt: _liveOperationsTestOccurredAtUtc(14, 21),
              intelligenceId: 'INTEL-DSP-4-RETURN',
              sourceType: 'cctv',
              provider: 'onyx',
              externalId: 'evt-agent-return-route',
              riskScore: 86,
              headline: 'Dispatch escalation',
              summary: 'Control needs the board back on DSP-4.',
              clientId: 'CLIENT-DEMO',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-DEMO',
              canonicalHash: 'canon-agent-return-route',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _showLiveOpsOverviewIfNeeded(tester);
      await _showLiveOpsOverviewIfNeeded(tester);

      expect(
        find.byKey(const ValueKey('live-operations-command-center-hero')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('live-operations-command-queue')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('live-operations-command-current-focus')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('onyx app renders vip protection route', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.vip),
    );
    await tester.pumpAndSettle();

    expect(find.byType(VipProtectionPage), findsOneWidget);
    expect(find.text('No Live VIP Run'), findsOneWidget);
  });

  testWidgets('vip protection stage package action opens admin system tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.vip),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('vip-create-detail-button')),
    );
    await tester.tap(find.byKey(const ValueKey('vip-create-detail-button')));
    await tester.pumpAndSettle();

    final adminPage = tester.widget<AdministrationPage>(
      find.byType(AdministrationPage),
    );
    expect(adminPage.initialTab, AdministrationPageTab.system);
    expect(find.text('Administration'), findsOneWidget);
  });

  testWidgets(
    'vip protection route hides stale scheduled review actions by default',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.vip),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('vip-schedule-ceo-airport-escort')),
        findsNothing,
      );
      expect(find.text('No Live VIP Run'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('vip-create-detail-button')),
        findsOneWidget,
      );
    },
  );

  testWidgets('onyx app renders risk intelligence route', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.intel),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RiskIntelligencePage), findsOneWidget);
    expect(find.text('AI OPINION FEED'), findsOneWidget);
  });

  testWidgets('risk intelligence manual intel action opens admin system tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.intel),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('intel-add-manual-button')),
    );
    await tester.tap(find.byKey(const ValueKey('intel-add-manual-button')));
    await tester.pumpAndSettle();

    final adminPage = tester.widget<AdministrationPage>(
      find.byType(AdministrationPage),
    );
    expect(adminPage.initialTab, AdministrationPageTab.system);
    expect(find.text('Administration'), findsOneWidget);
  });

  testWidgets(
    'risk intelligence detail action opens events for that intel item',
    (tester) async {
      final now = _liveOperationsScenarioNowUtc();
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.intel,
          initialStoreEventsOverride: [
            IntelligenceReceived(
              eventId: 'intel-route-event-1',
              sequence: 9201,
              version: 1,
              occurredAt: now,
              intelligenceId: 'intel-route-1',
              provider: 'newsapi.org',
              sourceType: 'news',
              externalId: 'news-route-1',
              clientId: 'CLIENT-DEMO',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-DEMO',
              headline: 'Route-level intelligence item',
              summary: 'A route-level intelligence item for events handoff.',
              riskScore: 73,
              canonicalHash: 'hash-intel-route-1',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('intel-detail-newsapi-org-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey('intel-detail-newsapi-org-button')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EventsReviewPage), findsOneWidget);
      final selectedIdText = tester.widget<Text>(
        find.byKey(const ValueKey('events-selected-event-id')),
      );
      expect(selectedIdText.data, 'intel-route-event-1');
    },
  );

  testWidgets(
    'risk intelligence area action opens scoped events when matched',
    (tester) async {
      final now = _liveOperationsScenarioNowUtc();
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.intel,
          initialStoreEventsOverride: [
            IntelligenceReceived(
              eventId: 'intel-area-event-1',
              sequence: 9202,
              version: 1,
              occurredAt: now,
              intelligenceId: 'intel-area-1',
              provider: 'newsapi.org',
              sourceType: 'news',
              externalId: 'news-area-1',
              clientId: 'CLIENT-DEMO',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-DEMO',
              headline: 'Sandton advisory issued',
              summary: 'Sandton posture advisory requires operator review.',
              riskScore: 61,
              canonicalHash: 'hash-intel-area-1',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final sandtonAreaButton = find.byKey(
        const ValueKey('intel-area-sandton-button'),
      );
      await tester.ensureVisible(sandtonAreaButton);
      await tester.tap(sandtonAreaButton);
      await tester.pumpAndSettle();

      expect(find.byType(EventsReviewPage), findsOneWidget);
      final selectedIdText = tester.widget<Text>(
        find.byKey(const ValueKey('events-selected-event-id')),
      );
      expect(selectedIdText.data, 'intel-area-event-1');
    },
  );

  testWidgets(
    'onyx app critical alert banner shifts focus to the active critical incident',
    (tester) async {
      final now = _liveOperationsScenarioNowUtc();
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
              clientId: 'CLIENT-DEMO',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-DEMO',
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
              clientId: 'CLIENT-DEMO',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-DEMO',
              faceConfidence: 0.82,
              canonicalHash: 'canon-low',
            ),
            DecisionCreated(
              eventId: 'decision-critical',
              sequence: 9003,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              dispatchId: 'DSP-CRIT',
              clientId: 'CLIENT-DEMO',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-DEMO',
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
              clientId: 'CLIENT-DEMO',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-DEMO',
              faceConfidence: 0.97,
              canonicalHash: 'canon-crit',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _openLiveOpsDetailedWorkspaceIfPresent(tester);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('live-operations-incident-tile-INC-DSP-LOW')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('live-operations-incident-tile-INC-DSP-LOW')),
      );
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
    'onyx app opens client comms from live operations without invalid room state',
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

      await tester.enterText(
        find.byKey(const ValueKey('controller-login-username')),
        'admin',
      );
      await tester.enterText(
        find.byKey(const ValueKey('controller-login-password')),
        'onyx123',
      );
      await tester.tap(find.byKey(const ValueKey('controller-login-submit')));
      await tester.pumpAndSettle();
      await _openLiveOpsDetailedWorkspaceIfPresent(tester);

      expect(find.text('CLIENT COMMS WATCH'), findsOneWidget);

      final openClientLaneAction = find.text('OPEN CLIENT COMMS').first;
      await tester.ensureVisible(openClientLaneAction);
      await tester.tap(openClientLaneAction);
      await tester.pumpAndSettle();

      expect(openedClientId, 'CLIENT-DEMO');
      expect(openedSiteId, 'SITE-DEMO');
      expect(openedRoom, isEmpty);
      expect(find.textContaining('Client Communications'), findsWidgets);
    },
  );

  testWidgets(
    'onyx app opens client comms from live operations into the scoped workspace without seed queue items',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? openedClientId;
      String? openedSiteId;

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          onClientLaneRouteOpened: (clientId, siteId, room) {
            openedClientId = clientId;
            openedSiteId = siteId;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('controller-login-username')),
        'admin',
      );
      await tester.enterText(
        find.byKey(const ValueKey('controller-login-password')),
        'onyx123',
      );
      await tester.tap(find.byKey(const ValueKey('controller-login-submit')));
      await tester.pumpAndSettle();
      await _openLiveOpsDetailedWorkspaceIfPresent(tester);

      final openClientLaneAction = find.text('OPEN CLIENT COMMS').first;
      await tester.ensureVisible(openClientLaneAction);
      await tester.tap(openClientLaneAction);
      await tester.pumpAndSettle();

      expect(openedClientId, 'CLIENT-DEMO');
      expect(openedSiteId, 'SITE-DEMO');
      expect(
        find.byKey(const ValueKey('clients-workspace-panel-board')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('clients-simple-queue-board')),
        findsNothing,
      );
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
        occurredAtUtc: _liveOperationsRouteOccurredAtUtc(50),
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
      await _openClientsDetailedWorkspaceIfPresent(tester);

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
      await _openLiveOpsDetailedWorkspaceIfPresent(tester);

      expect(find.text('CLIENT COMMS WATCH'), findsOneWidget);
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
        occurredAtUtc: _liveOperationsRouteOccurredAtUtc(55),
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-voip-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();
      await _openLiveOpsDetailedWorkspaceIfPresent(tester);

      expect(find.text('CLIENT COMMS WATCH'), findsOneWidget);
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

      final stageVoipButton = find.byKey(
        const ValueKey('guards-quick-stage-voip'),
      );
      await tester.ensureVisible(stageVoipButton);
      await tester.tap(stageVoipButton);
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
      await _openLiveOpsDetailedWorkspaceIfPresent(tester);

      expect(find.text('CLIENT COMMS WATCH'), findsOneWidget);
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
      ], scopeKey: 'CLIENT-DEMO|SITE-DEMO');

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-learned-style-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();
      await _openLiveOpsDetailedWorkspaceIfPresent(tester);

      expect(find.text('CLIENT COMMS WATCH'), findsOneWidget);
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

      await savePinnedLaneVoice(
        profile: 'reassurance-forward',
        scopeKey: 'CLIENT-DEMO|SITE-DEMO',
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-voice-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();
      await _openLiveOpsDetailedWorkspaceIfPresent(tester);

      expect(find.text('CLIENT COMMS WATCH'), findsOneWidget);
      expect(find.text('Client voice Reassuring'), findsWidgets);
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
          clientId: 'CLIENT-DEMO',
          siteId: 'SITE-DEMO',
          sourceText: 'Hi ONYX, are we still waiting on the patrol update?',
          originalDraftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          draftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          providerLabel: 'OpenAI',
          usedLearnedApprovalStyle: true,
          createdAtUtc: _liveOperationsPendingDraftCreatedAtUtc(40),
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
      await _openLiveOpsDetailedWorkspaceIfPresent(tester);

      expect(find.text('CLIENT COMMS WATCH'), findsOneWidget);
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
          clientId: 'CLIENT-DEMO',
          siteId: 'WTF-MAIN',
          sourceText:
              'Please confirm if the Waterfall response team has already arrived.',
          originalDraftText:
              'We are checking the latest Waterfall position now and will send the next verified update shortly.',
          draftText:
              'Control is checking the latest Waterfall position now and will share the next confirmed step shortly.',
          providerLabel: 'OpenAI',
          createdAtUtc: _liveOperationsPendingDraftCreatedAtUtc(41),
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
      expect(
        find.byKey(const ValueKey('control-inbox-priority-badge')),
        findsOneWidget,
      );
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
      expect(
        find.byKey(const ValueKey('control-inbox-filtered-chip')),
        findsOneWidget,
      );
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
      expect(
        find.byKey(const ValueKey('control-inbox-queue-hint')),
        findsNothing,
      );
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

      expect(
        find.byKey(const ValueKey('control-inbox-queue-hint')),
        findsNothing,
      );

      final showQueueHintAction = find.byKey(
        const ValueKey('control-inbox-show-queue-hint'),
      );
      await tester.ensureVisible(showQueueHintAction);
      await tester.tap(showQueueHintAction);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('control-inbox-queue-hint')),
        findsOneWidget,
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-queue-hint-reset-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('control-inbox-queue-hint')),
        findsOneWidget,
      );
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
          clientId: 'CLIENT-DEMO',
          siteId: 'WTF-MAIN',
          sourceText:
              'Please confirm if the Waterfall response team has already arrived.',
          originalDraftText:
              'Control is checking the latest Waterfall position now and will share the next confirmed step shortly.',
          draftText:
              'Control is checking the latest Waterfall position now and will share the next confirmed step shortly.',
          providerLabel: 'OpenAI',
          createdAtUtc: _liveOperationsPendingDraftCreatedAtUtc(42),
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
          matching: find.widgetWithText(OutlinedButton, 'OPEN CLIENT COMMS'),
        ),
      );
      await tester.pumpAndSettle();

      expect(openedClientId, 'CLIENT-DEMO');
      expect(openedSiteId, 'WTF-MAIN');
      expect(openedRoom, isEmpty);
      expect(find.textContaining('Client Communications'), findsWidgets);
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

      final otherAsk = find.textContaining(
        'Please confirm whether the Waterfall response team has already arrived.',
      );
      await tester.scrollUntilVisible(
        otherAsk,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('LIVE CLIENT ASKS'), findsOneWidget);
      expect(find.text('Other scope'), findsWidgets);

      final shapeReplyButton = find.text('Shape Reply');
      await tester.ensureVisible(shapeReplyButton.first);
      await tester.tap(shapeReplyButton.first);
      await tester.pumpAndSettle();

      expect(openedClientId, 'CLIENT-DEMO');
      expect(openedSiteId, 'WTF-MAIN');
      expect(openedRoom, isEmpty);
      expect(find.textContaining('Client Communications'), findsWidgets);
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
        clientId: 'CLIENT-DEMO',
        siteId: 'WTF-MAIN',
      );
      await scopedConversation.saveMessages(<ClientAppMessage>[
        ClientAppMessage(
          author: '@waterfall_resident',
          body:
              'Please confirm whether the Waterfall response team has already arrived.',
          occurredAt: _liveOperationsRouteOccurredAtUtc(43),
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
        find.textContaining(
          'Please confirm whether the Waterfall response team has already arrived.',
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
          clientId: 'CLIENT-DEMO',
          siteId: 'SITE-DEMO',
          sourceText: 'Hi ONYX, are we still waiting on the patrol update?',
          originalDraftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          draftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          providerLabel: 'OpenAI',
          createdAtUtc: _liveOperationsPendingDraftCreatedAtUtc(41),
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
      await _openLiveOpsDetailedWorkspaceIfPresent(tester);

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
          clientId: 'CLIENT-DEMO',
          siteId: 'SITE-DEMO',
          sourceText: 'Please update me on the patrol position.',
          originalDraftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          draftText:
              'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
          providerLabel: 'OpenAI',
          createdAtUtc: _liveOperationsPendingDraftCreatedAtUtc(42),
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
      await _openLiveOpsDetailedWorkspaceIfPresent(tester);

      expect(find.text('Pending ONYX Draft'), findsOneWidget);
      final approveButton = find
          .widgetWithText(FilledButton, 'Approve + Send')
          .first;
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
      await _openLiveOpsDetailedWorkspaceIfPresent(tester);

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
      await tester.scrollUntilVisible(
        reviewButton.first,
        400,
        scrollable: find.byType(Scrollable).first,
      );
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
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey(
          'live-ops-offscope-cross-surface-learn-clients-app',
        ),
        clientId: 'CLIENT-DEMO',
        siteId: 'WTF-MAIN',
        initialStoreEventsOverride: <DispatchEvent>[
          DecisionCreated(
            eventId: 'evt-DISP-WTF-LEARN-1',
            sequence: 1,
            version: 1,
            occurredAt: _liveOperationsOffScopeOccurredAtUtc(41),
            dispatchId: 'DISP-WTF-LEARN-1',
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'WTF-MAIN',
          ),
        ],
      );

      final reviewButton = find.textContaining(
        'Review dispatch draft for Resident Feed',
      );
      await tester.scrollUntilVisible(
        reviewButton.first,
        400,
        scrollable: find.byType(Scrollable).first,
      );
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
      await tester.scrollUntilVisible(
        sendReviewedDraftButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(sendReviewedDraftButton);
      await tester.pumpAndSettle();

      await tester.binding.setSurfaceSize(const Size(1440, 980));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey(
            'live-ops-offscope-cross-surface-learn-dashboard-app',
          ),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
          initialOperationsScopeClientIdOverride: 'CLIENT-DEMO',
          initialOperationsScopeSiteIdOverride: 'WTF-MAIN',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT COMMS WATCH'), findsOneWidget);
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
        clientId: 'CLIENT-DEMO',
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
          initialOperationsScopeClientIdOverride: 'CLIENT-DEMO',
          initialOperationsScopeSiteIdOverride: 'WTF-MAIN',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT COMMS WATCH'), findsOneWidget);
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
        occurredAtUtc: _liveOperationsOffScopeSyncOccurredAtUtc(6),
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('live-ops-offscope-push-state-dashboard-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
          initialOperationsScopeClientIdOverride: 'CLIENT-DEMO',
          initialOperationsScopeSiteIdOverride: 'WTF-MAIN',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT COMMS WATCH'), findsOneWidget);
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
        occurredAtUtc: _liveOperationsOffScopeSyncOccurredAtUtc(9),
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
          initialOperationsScopeClientIdOverride: 'CLIENT-DEMO',
          initialOperationsScopeSiteIdOverride: 'WTF-MAIN',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT COMMS WATCH'), findsOneWidget);
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
        occurredAtUtc: _liveOperationsOffScopeSyncOccurredAtUtc(11),
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey(
            'live-ops-offscope-telegram-health-dashboard-app',
          ),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
          initialOperationsScopeClientIdOverride: 'CLIENT-DEMO',
          initialOperationsScopeSiteIdOverride: 'WTF-MAIN',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT COMMS WATCH'), findsOneWidget);
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
        occurredAtUtc: _liveOperationsOffScopeSyncOccurredAtUtc(18),
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
          initialOperationsScopeClientIdOverride: 'CLIENT-DEMO',
          initialOperationsScopeSiteIdOverride: 'WTF-MAIN',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT COMMS WATCH'), findsOneWidget);
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
        occurredAtUtc: _liveOperationsOffScopeSyncOccurredAtUtc(21),
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
          initialOperationsScopeClientIdOverride: 'CLIENT-DEMO',
          initialOperationsScopeSiteIdOverride: 'WTF-MAIN',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT COMMS WATCH'), findsOneWidget);
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
        occurredAtUtc: _liveOperationsOffScopeSyncOccurredAtUtc(22),
      );

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-to-liveops-voip-history-admin-app'),
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
          key: const ValueKey('admin-to-liveops-voip-history-dashboard-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
          initialOperationsScopeClientIdOverride: 'CLIENT-DEMO',
          initialOperationsScopeSiteIdOverride: 'WTF-MAIN',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT COMMS WATCH'), findsOneWidget);
      expect(find.textContaining('WTF-MAIN'), findsWidgets);
      expect(find.text('Latest VoIP stage'), findsWidgets);
      expect(
        find.textContaining(
          'Asterisk staged a call for Waterfall command desk.',
        ),
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
      await _openLiveOpsDetailedWorkspaceIfPresent(tester);

      expect(find.text('Client voice Reassuring'), findsWidgets);
    },
  );

  testWidgets(
    'onyx app clears client-lane pinned voice from live operations after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await savePinnedLaneVoice(
        profile: 'reassurance-forward',
        scopeKey: 'CLIENT-DEMO|SITE-DEMO',
      );
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
          key: const ValueKey(
            'live-ops-cross-surface-clear-voice-dashboard-app',
          ),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();
      await _openLiveOpsDetailedWorkspaceIfPresent(tester);

      expect(find.text('Client voice Reassuring'), findsNothing);
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
      ], scopeKey: 'CLIENT-DEMO|SITE-DEMO');
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
      await _openLiveOpsDetailedWorkspaceIfPresent(tester);

      expect(find.text('Learned style 1'), findsNothing);
      expect(find.text('Learned approval style'), findsNothing);
      expect(find.text('ONYX using learned style'), findsNothing);
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
            clientId: 'CLIENT-DEMO',
            siteId: 'SITE-DEMO',
            sourceText: 'Please update me on the patrol position.',
            originalDraftText:
                'We are checking the latest patrol position now and will send the next verified update shortly.',
            draftText:
                'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
            createdAtUtc: _liveOperationsPendingDraftCreatedAtUtc(46),
            usedLearnedApprovalStyle: true,
          ),
        ]),
        ...legacyLearnedApprovalRuntimeState([
          'Control is checking the latest position now and will share the next confirmed step shortly.',
        ], scopeKey: 'CLIENT-DEMO|SITE-DEMO'),
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
      await _openLiveOpsDetailedWorkspaceIfPresent(tester);

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
          clientId: 'CLIENT-DEMO',
          siteId: 'SITE-DEMO',
          sourceText: 'Please update me on the patrol position.',
          originalDraftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          draftText:
              'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
          createdAtUtc: _liveOperationsPendingDraftCreatedAtUtc(47),
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
      await _openLiveOpsDetailedWorkspaceIfPresent(tester);

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
          clientId: 'CLIENT-DEMO',
          siteId: 'SITE-DEMO',
          sourceText: 'Please update me on the patrol position.',
          originalDraftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          draftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          createdAtUtc: _liveOperationsPendingDraftCreatedAtUtc(49),
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
