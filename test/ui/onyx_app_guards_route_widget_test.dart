import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/admin_page.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/client_intelligence_reports_page.dart';
import 'package:omnix_dashboard/ui/clients_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'onyx app opens client lane from guards message handoff without invalid room state',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? openedClientId;
      String? openedSiteId;
      String? openedRoom;

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.guards,
          onClientLaneRouteOpened: (clientId, siteId, room) {
            openedClientId = clientId;
            openedSiteId = siteId;
            openedRoom = room;
          },
        ),
      );
      await tester.pumpAndSettle();

      final clientLaneButton = find.byKey(
        const ValueKey('guards-quick-client-lane'),
      );
      await tester.ensureVisible(clientLaneButton);
      await tester.tap(clientLaneButton);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('guards-contact-primary-button')),
      );
      await tester.pumpAndSettle();

      expect(openedClientId, 'CLIENT-DEMO');
      expect(openedSiteId, isNotEmpty);
      expect(openedRoom, isEmpty);
      expect(find.byType(ClientsPage), findsOneWidget);
      expect(
        tester.widget<ClientsPage>(find.byType(ClientsPage)).clientId,
        'CLIENT-DEMO',
      );
      expect(
        tester.widget<ClientsPage>(find.byType(ClientsPage)).siteId,
        openedSiteId,
      );
    },
  );

  testWidgets('onyx app stages guard voip call into scoped comms persistence', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1680, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.guards),
    );
    await tester.pumpAndSettle();

    final stageVoipButton = find.byKey(
      const ValueKey('guards-quick-stage-voip'),
    );
    await tester.ensureVisible(stageVoipButton);
    await tester.tap(stageVoipButton);
    await tester.pumpAndSettle();

    expect(find.text('Voice Call Staging'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('guards-contact-primary-button')),
    );
    await tester.pumpAndSettle();

    final persistence = await DispatchPersistenceService.create();
    final scopeKeys = await persistence.readClientConversationScopeKeys();
    final scopedPushSyncState = await persistence
        .readScopedClientAppPushSyncState(
          clientId: 'CLIENT-DEMO',
          siteId: 'WTF-MAIN',
        );

    expect(scopeKeys, contains('CLIENT-DEMO|WTF-MAIN'));
    expect(scopedPushSyncState.history, isNotEmpty);
    expect(scopedPushSyncState.history.first.status, 'voip-failed');
    expect(
      scopedPushSyncState.history.first.failureReason,
      contains('VoIP staging is not configured for Thabo Mokoena yet.'),
    );
  });

  testWidgets('onyx app opens reports from guards hero action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.guards),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('guards-view-reports-button')));
    await tester.pumpAndSettle();

    expect(find.byType(ClientIntelligenceReportsPage), findsOneWidget);
    expect(
      tester
          .widget<ClientIntelligenceReportsPage>(
            find.byType(ClientIntelligenceReportsPage),
          )
          .selectedClient,
      'CLIENT-DEMO',
    );
    expect(
      tester
          .widget<ClientIntelligenceReportsPage>(
            find.byType(ClientIntelligenceReportsPage),
          )
          .selectedSite,
      'WTF-MAIN',
    );
  });

  testWidgets('onyx app opens admin guards tab from guards schedule action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.guards),
    );
    await tester.pumpAndSettle();

    final scheduleButton = find.byKey(const ValueKey('guards-quick-schedule'));
    await tester.ensureVisible(scheduleButton);
    await tester.tap(scheduleButton);
    await tester.pumpAndSettle();

    expect(find.byType(AdministrationPage), findsOneWidget);
    expect(
      tester
          .widget<AdministrationPage>(find.byType(AdministrationPage))
          .initialTab,
      AdministrationPageTab.guards,
    );
    expect(find.text('Administration'), findsOneWidget);
    expect(find.text('Guards'), findsWidgets);
  });

  testWidgets('onyx app keeps month planner intent when opening admin', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.guards),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('guards-view-tab-roster')));
    await tester.pumpAndSettle();

    final createButton = find.byKey(
      const ValueKey('guards-roster-create-button'),
    );
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(find.byType(AdministrationPage), findsOneWidget);
    final adminPage = tester.widget<AdministrationPage>(
      find.byType(AdministrationPage),
    );
    expect(adminPage.initialTab, AdministrationPageTab.guards);
    expect(adminPage.initialCommandLabel, 'MONTH PLANNER');
    expect(adminPage.initialCommandHeadline, 'Start the next roster month');
    expect(
      adminPage.initialCommandDetail,
      'Build the next month, place shifts, and lock the board before coverage slips.',
    );
    expect(
      find.byKey(const ValueKey('admin-guard-planner-dialog')),
      findsOneWidget,
    );
    expect(find.text('Create Month Planner'), findsOneWidget);
  });
}
