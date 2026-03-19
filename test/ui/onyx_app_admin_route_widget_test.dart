import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/application/telegram_bridge_service.dart';
import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/admin_page.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/clients_page.dart';
import 'package:omnix_dashboard/ui/client_intelligence_reports_page.dart';
import 'package:omnix_dashboard/ui/dispatch_page.dart';
import 'package:omnix_dashboard/ui/governance_page.dart';
import 'package:omnix_dashboard/ui/live_operations_page.dart';
import 'package:omnix_dashboard/ui/tactical_page.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_sections.dart';

import 'support/admin_route_test_harness.dart';
import 'support/admin_route_state_harness.dart';

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
    'onyx app exports system admin data from the hero action',
    (tester) async {
      String? copiedPayload;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            copiedPayload = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await prepareAdminRouteTest(tester);

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-export-route-app'),
        initialAdminTab: AdministrationPageTab.system,
      );
      await openAdminSystemAnchor(tester, 'System Information');

      final exportButton = find.byKey(
        const ValueKey('admin-export-data-button'),
      );
      await tester.ensureVisible(exportButton);
      await tester.tap(exportButton);
      await tester.pumpAndSettle();

      expect(copiedPayload, isNotNull);
      expect(copiedPayload, contains('"operator_id"'));
      expect(copiedPayload, contains('"telegram_bridge_health_label"'));
    },
  );

  testWidgets(
    'onyx app opens the admin csv import dialog from the hero action',
    (tester) async {
      await prepareAdminRouteTest(tester);

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-import-route-app'),
        initialAdminTab: AdministrationPageTab.system,
      );
      await openAdminSystemAnchor(tester, 'System Information');

      final importButton = find.byKey(
        const ValueKey('admin-import-csv-button'),
      );
      await tester.ensureVisible(importButton);
      await tester.tap(importButton);
      await tester.pumpAndSettle();

      expect(find.text('Import CSV'), findsWidgets);
      expect(find.text('Target'), findsOneWidget);
      expect(find.text('Import'), findsWidgets);
    },
  );

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
      expect(find.textContaining('Client Communications'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app restores scoped guard voip history into admin comms audit after restart',
    (tester) async {
      await prepareAdminRouteTest(tester);

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

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-app'),
      );
      await openAdminClientCommsAudit(tester);

      expect(find.text('Client Comms Audit'), findsOneWidget);
      expect(find.text('LATEST VOIP STAGE'), findsOneWidget);
      expect(
        find.textContaining(
          'VoIP staging is not configured for Thabo Mokoena yet.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app opens reports from admin client demo ready action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.clients,
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

      await tester.tap(find.text('Open Reports'));
      await tester.pumpAndSettle();

      expect(find.byType(ClientIntelligenceReportsPage), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app opens dispatches from admin site demo ready action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.sites,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Demo Mode'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      final demoReadyButton = find.widgetWithText(
        FilledButton,
        'Demo Ready 0/6',
      );
      final fallbackDemoReadyButton = find.textContaining('Demo Ready');
      final demoReadyFinder = demoReadyButton.evaluate().isNotEmpty
          ? demoReadyButton.first
          : fallbackDemoReadyButton.first;
      await tester.ensureVisible(demoReadyFinder);
      await tester.tap(demoReadyFinder);
      await tester.pumpAndSettle();

      final createSiteReadyFinder = find.text('Create Site (Ready)').last;
      await tester.ensureVisible(createSiteReadyFinder);
      await tester.tap(createSiteReadyFinder);
      await tester.pumpAndSettle();

      expect(find.text('Site Demo Ready'), findsOneWidget);

      await tester.tap(find.text('Open Dispatches'));
      await tester.pumpAndSettle();

      expect(find.byType(DispatchPage), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app opens governance from admin client demo ready action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.clients,
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

      await tester.tap(find.text('Open Governance'));
      await tester.pumpAndSettle();

      expect(find.byType(GovernancePage), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app opens operations from admin client demo ready action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.clients,
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

      await tester.tap(find.text('Open Operations'));
      await tester.pumpAndSettle();

      expect(find.byType(LiveOperationsPage), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app opens client communications from admin client demo ready action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.clients,
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

      expect(find.byType(ClientsPage), findsOneWidget);
      expect(find.textContaining('Client Communications'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app opens tactical from admin site demo ready action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.sites,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Demo Mode'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      final demoReadyButton = find.widgetWithText(
        FilledButton,
        'Demo Ready 0/6',
      );
      final fallbackDemoReadyButton = find.textContaining('Demo Ready');
      final demoReadyFinder = demoReadyButton.evaluate().isNotEmpty
          ? demoReadyButton.first
          : fallbackDemoReadyButton.first;
      await tester.ensureVisible(demoReadyFinder);
      await tester.tap(demoReadyFinder);
      await tester.pumpAndSettle();

      final createSiteReadyFinder = find.text('Create Site (Ready)').last;
      await tester.ensureVisible(createSiteReadyFinder);
      await tester.tap(createSiteReadyFinder);
      await tester.pumpAndSettle();

      expect(find.text('Site Demo Ready'), findsOneWidget);

      await tester.tap(find.text('Open Tactical'));
      await tester.pumpAndSettle();

      expect(find.byType(TacticalPage), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app opens operations from admin site demo ready action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.sites,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Demo Mode'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      final demoReadyButton = find.widgetWithText(
        FilledButton,
        'Demo Ready 0/6',
      );
      final fallbackDemoReadyButton = find.textContaining('Demo Ready');
      final demoReadyFinder = demoReadyButton.evaluate().isNotEmpty
          ? demoReadyButton.first
          : fallbackDemoReadyButton.first;
      await tester.ensureVisible(demoReadyFinder);
      await tester.tap(demoReadyFinder);
      await tester.pumpAndSettle();

      final createSiteReadyFinder = find.text('Create Site (Ready)').last;
      await tester.ensureVisible(createSiteReadyFinder);
      await tester.tap(createSiteReadyFinder);
      await tester.pumpAndSettle();

      expect(find.text('Site Demo Ready'), findsOneWidget);

      await tester.tap(find.text('Open Operations'));
      await tester.pumpAndSettle();

      expect(find.byType(LiveOperationsPage), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app opens tactical from admin employee demo ready action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.guards,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Demo Mode'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      final demoReadyButton = find.widgetWithText(
        FilledButton,
        'Demo Ready 0/6',
      );
      final fallbackDemoReadyButton = find.textContaining('Demo Ready');
      final demoReadyFinder = demoReadyButton.evaluate().isNotEmpty
          ? demoReadyButton.first
          : fallbackDemoReadyButton.first;
      await tester.ensureVisible(demoReadyFinder);
      await tester.tap(demoReadyFinder);
      await tester.pumpAndSettle();

      final createEmployeeReadyFinder = find.text(
        'Create Employee (Ready)',
      ).last;
      await tester.ensureVisible(createEmployeeReadyFinder);
      await tester.tap(createEmployeeReadyFinder);
      await tester.pumpAndSettle();

      expect(find.text('Employee Demo Ready'), findsOneWidget);

      await tester.tap(find.text('Open Tactical'));
      await tester.pumpAndSettle();

      expect(find.byType(TacticalPage), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app opens dispatches from admin employee demo ready action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.guards,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Demo Mode'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      final demoReadyButton = find.widgetWithText(
        FilledButton,
        'Demo Ready 0/6',
      );
      final fallbackDemoReadyButton = find.textContaining('Demo Ready');
      final demoReadyFinder = demoReadyButton.evaluate().isNotEmpty
          ? demoReadyButton.first
          : fallbackDemoReadyButton.first;
      await tester.ensureVisible(demoReadyFinder);
      await tester.tap(demoReadyFinder);
      await tester.pumpAndSettle();

      final createEmployeeReadyFinder = find.text(
        'Create Employee (Ready)',
      ).last;
      await tester.ensureVisible(createEmployeeReadyFinder);
      await tester.tap(createEmployeeReadyFinder);
      await tester.pumpAndSettle();

      expect(find.text('Employee Demo Ready'), findsOneWidget);

      await tester.tap(find.text('Open Dispatches'));
      await tester.pumpAndSettle();

      expect(find.byType(DispatchPage), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app opens operations from admin employee demo ready action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.guards,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Demo Mode'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      final demoReadyButton = find.widgetWithText(
        FilledButton,
        'Demo Ready 0/6',
      );
      final fallbackDemoReadyButton = find.textContaining('Demo Ready');
      final demoReadyFinder = demoReadyButton.evaluate().isNotEmpty
          ? demoReadyButton.first
          : fallbackDemoReadyButton.first;
      await tester.ensureVisible(demoReadyFinder);
      await tester.tap(demoReadyFinder);
      await tester.pumpAndSettle();

      final createEmployeeReadyFinder = find.text(
        'Create Employee (Ready)',
      ).last;
      await tester.ensureVisible(createEmployeeReadyFinder);
      await tester.tap(createEmployeeReadyFinder);
      await tester.pumpAndSettle();

      expect(find.text('Employee Demo Ready'), findsOneWidget);

      await tester.tap(find.text('Open Operations'));
      await tester.pumpAndSettle();

      expect(find.byType(LiveOperationsPage), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app opens operations from admin build demo stack action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.guards,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Demo Mode'));
      await tester.pumpAndSettle();

      final buildDemoStackFinder = find.widgetWithText(
        FilledButton,
        'Build Demo Stack',
      ).first;
      await tester.ensureVisible(buildDemoStackFinder);
      await tester.tap(buildDemoStackFinder);
      await tester.pumpAndSettle();

      expect(find.byType(LiveOperationsPage), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app restores limited watch drilldown into admin after restart',
    (tester) async {
      await prepareAdminRouteTest(tester);

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveAdminPageTab(AdministrationPageTab.guards);
      await persistence.saveAdminWatchActionDrilldown(
        VideoFleetWatchActionDrilldown.limited,
      );

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-limited-watch-drilldown-restart-app'),
        initialAdminTab: AdministrationPageTab.guards,
      );

      expect(find.text('System Information'), findsOneWidget);
      expect(find.text('SLA Tiers'), findsOneWidget);
      expect(find.textContaining('Thabo Mokoena'), findsNothing);
    },
  );

  testWidgets(
    'onyx app surfaces off-lane comms history in admin audit as cross-scope',
    (tester) async {
      await prepareAdminRouteTest(tester);

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

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-cross-scope-audit-app'),
      );
      await openAdminClientCommsAudit(tester);

      expect(find.text('Client Comms Audit'), findsOneWidget);
      expect(find.text('Cross-scope'), findsOneWidget);
      expect(find.text('LATEST VOIP STAGE'), findsOneWidget);
      expect(
        find.textContaining(
          'VoIP staging is not configured for Thabo Mokoena yet.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets('onyx app surfaces off-scope live client asks in admin audit', (
    tester,
  ) async {
    await prepareAdminRouteTest(tester);

    await seedWaterfallResidentAsk();

    await pumpAdminRouteApp(
      tester,
      key: const ValueKey('admin-cross-scope-live-ask-app'),
    );
    await openAdminClientCommsAudit(tester);

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
  });

  testWidgets(
    'onyx app opens the exact off-scope lane from an ask-driven admin audit card',
    (tester) async {
      await prepareAdminRouteTest(tester);

      await seedWaterfallResidentAsk();

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

      await openAdminSystemAnchor(tester, 'LATEST CLIENT ASK');

      await tester.ensureVisible(find.text('Open This Lane').first);
      await tester.tap(find.text('Open This Lane').first);
      await tester.pumpAndSettle();

      expect(openedClientId, 'CLIENT-MS-VALLEE');
      expect(openedSiteId, 'WTF-MAIN');
      expect(openedRoom, isEmpty);
      expect(find.textContaining('Client Communications'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app restores learned approval style into admin comms audit after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await saveLearnedApprovalStyles([
        learnedApprovalEntry(
          text:
              'Control is checking the latest position now and will share the next confirmed step shortly.',
          operatorTag: 'Warm reassurance',
        ),
      ]);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-learned-style-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await openAdminClientCommsAudit(tester);

      expect(find.text('Client Comms Audit'), findsOneWidget);
      expect(find.text('Learned style (1)'), findsOneWidget);
      expect(find.text('LEARNED APPROVAL STYLE'), findsOneWidget);
      expect(find.text('Warm reassurance'), findsOneWidget);
      expect(find.textContaining('Approved 1x'), findsOneWidget);
      expect(
        find.textContaining(
          'Control is checking the latest position now and will share the next confirmed step shortly.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx app tags the second learned approval style in admin comms audit and persists it',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await saveLearnedApprovalStyles([
        learnedApprovalEntry(
          text:
              'Control is checking the latest position now and will share the next confirmed step shortly.',
          approvalCount: 3,
        ),
        learnedApprovalEntry(
          text:
              'You are not alone. Control is checking now and will keep this lane updated.',
          approvalCount: 2,
        ),
      ]);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-tag-learned-style-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await openAdminClientCommsAudit(tester);

      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Tag #2'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Tag #2'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Resident comfort',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save Tag'));
      await tester.pumpAndSettle();

      expect(find.text('Resident comfort'), findsOneWidget);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-tag-learned-style-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await openAdminClientCommsAudit(tester);

      expect(find.text('Resident comfort'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app restores pinned lane voice into admin comms audit after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await savePinnedLaneVoice(profile: 'reassurance-forward');

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-voice-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await openAdminClientCommsAudit(tester);

      expect(find.text('Client Comms Audit'), findsOneWidget);
      expect(find.textContaining('Voice Reassuring'), findsOneWidget);
      expect(find.text('Lane voice: Reassuring'), findsOneWidget);
      expect(find.text('Voice-adjusted'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app demotes the top learned approval style in admin comms audit and persists it',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await saveLearnedApprovalStyles([
        learnedApprovalEntry(
          text:
              'Control is checking the latest position now and will share the next confirmed step shortly.',
          approvalCount: 3,
        ),
        learnedApprovalEntry(
          text:
              'You are not alone. Control is checking now and will keep this lane updated.',
          approvalCount: 2,
        ),
      ]);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-demote-learned-style-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await openAdminClientCommsAudit(tester);

      expect(
        find.textContaining(
          'Control is checking the latest position now and will share the next confirmed step shortly.',
        ),
        findsOneWidget,
      );
      expect(find.text('NEXT LEARNED OPTIONS'), findsOneWidget);
      expect(
        find.textContaining(
          '#2 You are not alone. Control is checking now and will keep this lane updated.',
        ),
        findsOneWidget,
      );

      await tapVisibleText(tester, 'Demote Top Style', first: false);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'You are not alone. Control is checking now and will keep this lane updated.',
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-demote-learned-style-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await openAdminClientCommsAudit(tester);

      expect(
        find.textContaining(
          'You are not alone. Control is checking now and will keep this lane updated.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx app promotes the second learned approval style in admin comms audit and persists it',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await saveLearnedApprovalStyles([
        learnedApprovalEntry(
          text:
              'Control is checking the latest position now and will share the next confirmed step shortly.',
          approvalCount: 3,
        ),
        learnedApprovalEntry(
          text:
              'You are not alone. Control is checking now and will keep this lane updated.',
          approvalCount: 2,
        ),
        learnedApprovalEntry(
          text:
              'Control is checking cameras now and will share the next confirmed camera check shortly.',
          approvalCount: 1,
        ),
      ]);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-promote-learned-style-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await openAdminClientCommsAudit(tester);

      expect(
        find.textContaining(
          'Control is checking the latest position now and will share the next confirmed step shortly.',
        ),
        findsOneWidget,
      );
      expect(find.text('NEXT LEARNED OPTIONS'), findsOneWidget);
      expect(
        find.textContaining(
          '#2 You are not alone. Control is checking now and will keep this lane updated.',
        ),
        findsOneWidget,
      );

      await tapVisibleText(tester, 'Promote #2', first: false);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'You are not alone. Control is checking now and will keep this lane updated.',
        ),
        findsWidgets,
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-promote-learned-style-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await openAdminClientCommsAudit(tester);

      expect(
        find.textContaining(
          'You are not alone. Control is checking now and will keep this lane updated.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app restores pending telegram ai draft into admin review after restart',
    (tester) async {
      await prepareAdminRouteTest(tester);

      await savePendingTelegramDrafts([
        telegramPendingDraftEntry(
          inboundUpdateId: 42,
          messageThreadId: 88,
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          sourceText: 'Can you please tell me what is happening at the house?',
          originalDraftText:
              'We are checking the latest position now and will send the next confirmed update shortly.',
          draftText:
              'We are checking the latest position now and will send the next confirmed update shortly.',
          createdAtUtc: DateTime.utc(2026, 3, 18, 12, 30),
        ),
      ]);

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-pending-draft-app'),
      );
      await openAdminPendingDraftReview(tester);

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
    'onyx app can re-enable the live operations queue hint from admin and keep it after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      LiveOperationsPage.debugResetQueueStateHintSession();
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() {
        tester.binding.setSurfaceSize(null);
        LiveOperationsPage.debugResetQueueStateHintSession();
      });

      await saveLiveOperationsQueueHintState(
        seen: true,
        legacyLearnedStyles: const <String>[
          'Control is checking the latest position now and will share the next confirmed step shortly.',
        ],
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-reset-live-ops-queue-hint-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await openAdminSystemAnchor(tester, 'LEARNED APPROVAL STYLE');
      expect(find.text('Client Comms Audit'), findsOneWidget);
      expect(find.text('LEARNED APPROVAL STYLE'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('admin-reset-live-ops-queue-hint-audit-button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('admin-reset-live-ops-queue-hint-audit-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Live Ops tip will show again.'), findsOneWidget);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('dashboard-after-admin-reset-live-ops-queue-hint'),
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
    'onyx app surfaces off-scope pending telegram ai drafts in admin review',
    (tester) async {
      await prepareAdminRouteTest(tester);

      await savePendingTelegramDrafts([
        telegramPendingDraftEntry(
          inboundUpdateId: 43,
          messageThreadId: 89,
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'WTF-MAIN',
          sourceText:
              'Can you confirm whether the Waterfall team is already on site?',
          originalDraftText:
              'We are checking the latest Waterfall position now and will send the next confirmed update shortly.',
          draftText:
              'We are checking the latest Waterfall position now and will send the next confirmed update shortly.',
          createdAtUtc: DateTime.utc(2026, 3, 18, 12, 30),
        ),
      ]);

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-off-scope-pending-draft-app'),
      );
      await openAdminPendingDraftReview(tester);

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

  testWidgets('onyx app opens the exact off-scope lane from admin draft review', (
    tester,
  ) async {
    await prepareAdminRouteTest(tester);

    await savePendingTelegramDrafts([
      telegramPendingDraftEntry(
        inboundUpdateId: 44,
        messageThreadId: 90,
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
        sourceText:
            'Please confirm whether the Waterfall desk has eyes on the lane yet.',
        originalDraftText:
            'Control is checking the latest Waterfall visual now and will share the next confirmed step shortly.',
        draftText:
            'Control is checking the latest Waterfall visual now and will share the next confirmed step shortly.',
        createdAtUtc: DateTime.utc(2026, 3, 18, 12, 31),
      ),
    ]);

    String? openedClientId;
    String? openedSiteId;
    String? openedRoom;

    await pumpAdminRouteApp(
      tester,
      key: const ValueKey('admin-open-off-scope-draft-lane-app'),
      onClientLaneRouteOpened: (clientId, siteId, room) {
        openedClientId = clientId;
        openedSiteId = siteId;
        openedRoom = room;
      },
    );
    await openAdminPendingDraftReview(tester);

    await tester.ensureVisible(find.text('Open This Lane').first);
    await tester.tap(find.text('Open This Lane').first);
    await tester.pumpAndSettle();

    expect(openedClientId, 'CLIENT-MS-VALLEE');
    expect(openedSiteId, 'WTF-MAIN');
    expect(openedRoom, isEmpty);
    expect(find.textContaining('Client Communications'), findsOneWidget);
  });

  testWidgets(
    'onyx app persists rejected telegram ai draft clearing after restart',
    (tester) async {
      await prepareAdminRouteTest(tester);

      await savePendingTelegramDrafts([
        telegramPendingDraftEntry(
          inboundUpdateId: 77,
          messageThreadId: 88,
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          sourceText: 'Please update me on the patrol position.',
          originalDraftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          draftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          createdAtUtc: DateTime.utc(2026, 3, 18, 12, 31),
        ),
      ]);

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-reject-draft-app'),
      );
      await openAdminPendingDraftReview(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
      await tester.pumpAndSettle();

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-reject-draft-restart-app'),
      );

      expect(find.text('CLIENT ASKED'), findsNothing);
      expect(find.text('ONYX WILL SAY'), findsNothing);
      expect(find.text('Awaiting human sign-off'), findsNothing);
    },
  );

  testWidgets('onyx app persists approved telegram ai draft learning after restart', (
    tester,
  ) async {
    await prepareAdminRouteTest(tester);

    await savePendingTelegramDrafts([
      telegramPendingDraftEntry(
        inboundUpdateId: 91,
        messageThreadId: 88,
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        sourceText: 'Please update me on the patrol position.',
        originalDraftText:
            'We are checking the latest patrol position now and will send the next verified update shortly.',
        draftText:
            'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
        createdAtUtc: DateTime.utc(2026, 3, 18, 12, 32),
      ),
    ]);

    await pumpAdminRouteApp(
      tester,
      key: const ValueKey('admin-approve-draft-app'),
      telegramBridgeServiceOverride: const _SuccessfulTelegramBridgeStub(),
    );
    await openAdminPendingDraftReview(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Approve + Send'));
    await tester.pumpAndSettle();

    await pumpAdminRouteApp(
      tester,
      key: const ValueKey('admin-approve-draft-restart-app'),
    );
    await openAdminClientCommsAudit(tester);

    expect(find.text('CLIENT ASKED'), findsNothing);
    expect(find.text('Learned style (1)'), findsOneWidget);
    expect(find.text('LEARNED APPROVAL STYLE'), findsOneWidget);
    expect(
      find.textContaining(
        'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
      ),
      findsWidgets,
    );
  });

  testWidgets(
    'onyx app shows client-lane learned approval memory in admin audit after restart',
    (tester) async {
      await prepareAdminRouteTest(tester);

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('admin-cross-surface-learn-clients-app'),
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

      await pumpAndOpenAdminClientCommsAudit(
        tester,
        key: const ValueKey('admin-cross-surface-learn-admin-app'),
      );

      expect(find.text('Learned style (1)'), findsOneWidget);
      expect(find.text('LEARNED APPROVAL STYLE'), findsOneWidget);
      expect(find.textContaining(approvedDraftText), findsWidgets);
    },
  );

  testWidgets(
    'onyx app shows off-scope client-lane learned approval style in admin audit after restart',
    (tester) async {
      await prepareAdminRouteTest(tester);

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('admin-offscope-cross-surface-learn-clients-app'),
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

      await pumpAndOpenAdminClientCommsAudit(
        tester,
        key: const ValueKey('admin-offscope-cross-surface-learn-admin-app'),
      );

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
      await prepareAdminRouteTest(tester);

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('admin-offscope-lane-reply-clients-app'),
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

      await pumpAndOpenAdminClientCommsAudit(
        tester,
        key: const ValueKey('admin-offscope-lane-reply-admin-app'),
      );
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
      await prepareAdminRouteTest(tester);

      await seedWaterfallPushPressure(
        messageKey: 'waterfall-admin-push-1',
      );

      await pumpAndOpenAdminClientCommsAudit(
        tester,
        key: const ValueKey('admin-offscope-push-pressure-app'),
      );

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
      await prepareAdminRouteTest(tester);

      await seedWaterfallPushPressure(
        messageKey: 'waterfall-admin-push-open-lane-1',
      );

      String? openedClientId;
      String? openedSiteId;
      String? openedRoom;

      await pumpAndOpenAdminClientCommsAudit(
        tester,
        key: const ValueKey('admin-open-off-scope-push-pressure-lane-app'),
        onClientLaneRouteOpened: (clientId, siteId, room) {
          openedClientId = clientId;
          openedSiteId = siteId;
          openedRoom = room;
        },
      );
      await openAdminSystemAnchor(tester, 'LATEST PUSH DETAIL');

      await tester.ensureVisible(find.text('Open This Lane').first);
      await tester.tap(find.text('Open This Lane').first);
      await tester.pumpAndSettle();

      expect(openedClientId, 'CLIENT-MS-VALLEE');
      expect(openedSiteId, 'WTF-MAIN');
      expect(openedRoom, isEmpty);
      expect(find.textContaining('Client Communications'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app humanizes off-scope telegram bridge detail in admin audit after restart',
    (tester) async {
      await prepareAdminRouteTest(tester);

      await seedWaterfallTelegramBlockedPushSync();

      await pumpAndOpenAdminClientCommsAudit(
        tester,
        key: const ValueKey('admin-telegram-detail-humanized-app'),
      );
      await openAdminSystemAnchor(tester, 'LATEST PUSH DETAIL');

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
      await prepareAdminRouteTest(tester);

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('admin-cross-surface-voice-clients-app'),
      );

      final reassuringChip = find.widgetWithText(ChoiceChip, 'Reassuring');
      await tester.ensureVisible(reassuringChip);
      await tester.tap(reassuringChip);
      await tester.pumpAndSettle();

      await pumpAndOpenAdminClientCommsAudit(
        tester,
        key: const ValueKey('admin-cross-surface-voice-admin-app'),
      );

      expect(find.textContaining('Voice Reassuring'), findsOneWidget);
      expect(find.text('Lane voice: Reassuring'), findsOneWidget);
      expect(find.text('Voice-adjusted'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app clears client-lane pinned voice from admin audit after restart',
    (tester) async {
      await prepareAdminRouteTest(tester);

      await savePinnedLaneVoice(profile: 'reassurance-forward');

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('admin-cross-surface-clear-voice-clients-app'),
      );

      final autoChip = find.widgetWithText(ChoiceChip, 'Auto');
      await tester.ensureVisible(autoChip);
      await tester.tap(autoChip);
      await tester.pumpAndSettle();

      await pumpAndOpenAdminClientCommsAudit(
        tester,
        key: const ValueKey('admin-cross-surface-clear-voice-admin-app'),
      );

      expect(find.textContaining('Voice Reassuring'), findsNothing);
      expect(find.text('Lane voice: Reassuring'), findsNothing);
      expect(find.text('Voice-adjusted'), findsNothing);
    },
  );

  testWidgets(
    'onyx app clears client-lane learned approval style from admin audit after restart',
    (tester) async {
      await prepareAdminRouteTest(tester);

      await saveLegacyLearnedApprovalStyles(const <String>[
        'Control is checking the latest position now and will share the next confirmed step shortly.',
      ]);

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('admin-cross-surface-clear-learned-clients-app'),
      );

      final clearLearnedStyleButton = find.widgetWithText(
        OutlinedButton,
        'Clear Learned Style',
      );
      await tester.ensureVisible(clearLearnedStyleButton);
      await tester.tap(clearLearnedStyleButton);
      await tester.pumpAndSettle();

      await pumpAndOpenAdminClientCommsAudit(
        tester,
        key: const ValueKey('admin-cross-surface-clear-learned-admin-app'),
      );

      expect(find.text('Learned style (1)'), findsNothing);
      expect(find.text('LEARNED APPROVAL STYLE'), findsNothing);
      expect(find.text('ONYX using learned style'), findsNothing);
    },
  );

  testWidgets(
    'onyx app reflects live operations learned-style clearing in admin audit after restart',
    (tester) async {
      await prepareAdminRouteTest(tester);

      await saveLegacyLearnedApprovalStyles(const <String>[
        'Control is checking the latest position now and will share the next confirmed step shortly.',
      ]);

      await pumpLiveOperationsSourceApp(
        tester,
        key: const ValueKey('admin-live-ops-clear-learned-source-app'),
      );

      final clearLearnedStyleButton = find.widgetWithText(
        OutlinedButton,
        'Clear Learned Style',
      );
      await tester.ensureVisible(clearLearnedStyleButton.first);
      await tester.tap(clearLearnedStyleButton.first);
      await tester.pumpAndSettle();

      await pumpAndOpenAdminClientCommsAudit(
        tester,
        key: const ValueKey('admin-live-ops-clear-learned-restart-app'),
      );

      expect(find.text('Learned style (1)'), findsNothing);
      expect(find.text('LEARNED APPROVAL STYLE'), findsNothing);
      expect(find.text('ONYX using learned style'), findsNothing);
    },
  );

  testWidgets(
    'onyx app reflects live operations lane voice changes in admin audit after restart',
    (tester) async {
      await prepareAdminRouteTest(tester);

      await pumpLiveOperationsSourceApp(
        tester,
        key: const ValueKey('admin-live-ops-voice-source-app'),
      );

      final reassuringButton = find.widgetWithText(
        OutlinedButton,
        'Reassuring',
      );
      await tester.ensureVisible(reassuringButton.first);
      await tester.tap(reassuringButton.first);
      await tester.pumpAndSettle();

      await pumpAndOpenAdminClientCommsAudit(
        tester,
        key: const ValueKey('admin-live-ops-voice-restart-app'),
      );

      expect(find.textContaining('Voice Reassuring'), findsOneWidget);
      expect(find.text('Lane voice: Reassuring'), findsOneWidget);
      expect(find.text('Voice-adjusted'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app reflects live operations rejected pending draft in admin review after restart',
    (tester) async {
      await prepareAdminRouteTest(tester);

      await savePendingTelegramDrafts([
        telegramPendingDraftEntry(
          inboundUpdateId: 903,
          messageThreadId: 88,
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          sourceText: 'Please update me on the patrol position.',
          originalDraftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          draftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          createdAtUtc: DateTime.utc(2026, 3, 18, 12, 48),
        ),
      ]);

      await pumpLiveOperationsSourceApp(
        tester,
        key: const ValueKey('admin-live-ops-reject-source-app'),
      );

      expect(find.text('Pending ONYX Draft'), findsOneWidget);
      final rejectButton = find.widgetWithText(OutlinedButton, 'Reject').first;
      await tester.ensureVisible(rejectButton);
      await tester.tap(rejectButton);
      await tester.pumpAndSettle();

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-live-ops-reject-restart-app'),
      );

      expect(
        find.text('Please update me on the patrol position.'),
        findsNothing,
      );
      expect(
        find.text(
          'We are checking the latest patrol position now and will send the next verified update shortly.',
        ),
        findsNothing,
      );
      expect(find.text('Awaiting human sign-off'), findsNothing);
    },
  );

  testWidgets(
    'onyx app reflects live operations approved pending draft in admin review after restart',
    (tester) async {
      await prepareAdminRouteTest(tester);

      await savePendingTelegramDrafts([
        telegramPendingDraftEntry(
          inboundUpdateId: 905,
          messageThreadId: 88,
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          sourceText: 'Please update me on the patrol position.',
          originalDraftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          draftText:
              'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
          createdAtUtc: DateTime.utc(2026, 3, 18, 12, 50),
        ),
      ]);

      await pumpLiveOperationsSourceApp(
        tester,
        key: const ValueKey('admin-live-ops-approve-source-app'),
        telegramBridgeServiceOverride: const _SuccessfulTelegramBridgeStub(),
      );

      expect(find.text('Pending ONYX Draft'), findsOneWidget);
      final approveButton = find.widgetWithText(
        FilledButton,
        'Approve + Send',
      ).first;
      await tester.ensureVisible(approveButton);
      await tester.tap(approveButton);
      await tester.pumpAndSettle();

      await pumpAndOpenAdminClientCommsAudit(
        tester,
        key: const ValueKey('admin-live-ops-approve-restart-app'),
      );

      expect(
        find.text('Please update me on the patrol position.'),
        findsNothing,
      );
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
