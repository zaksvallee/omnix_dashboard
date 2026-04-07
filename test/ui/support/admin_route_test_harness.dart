import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_health_service.dart';
import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/application/telegram_bridge_service.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_server_contract.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/admin_page.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/client_app_page.dart';

const adminTelegramAiAssistantPanelKey = ValueKey(
  'admin-telegram-ai-assistant-panel',
);
const adminClientCommsAuditPanelKey = ValueKey(
  'admin-client-comms-audit-panel',
);

ValueKey<String> adminPendingDraftOpenClientCommsButtonKey(int updateId) =>
    ValueKey<String>('admin-telegram-ai-draft-open-client-comms-$updateId');

ValueKey<String> adminClientCommsAuditOpenClientCommsButtonKey(
  String clientId,
  String siteId,
) => ValueKey<String>(
  'admin-client-comms-audit-open-client-comms-${clientId.trim()}::${siteId.trim()}',
);

Future<void> prepareAdminRouteTest(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(1680, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> tapVisibleText(
  WidgetTester tester,
  String text, {
  bool first = true,
}) async {
  final finder = first ? find.text(text).first : find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> tapAdminDemoModeToggle(WidgetTester tester) async {
  final finder = find.byKey(adminDemoModeToggleKey);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> tapAdminToolbarPrimaryAction(WidgetTester tester) async {
  final finder = find
      .byKey(const ValueKey('admin-toolbar-primary-action'))
      .hitTestable();
  final target = finder.evaluate().isNotEmpty
      ? finder.last
      : find.byKey(const ValueKey('admin-toolbar-primary-action')).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> tapAdminClientDemoReady(WidgetTester tester) async {
  final finder = find.byKey(clientOnboardingDemoReadyButtonKey).hitTestable();
  final target = finder.evaluate().isNotEmpty
      ? finder.last
      : find.byKey(clientOnboardingDemoReadyButtonKey).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> tapAdminSiteDemoReady(WidgetTester tester) async {
  final finder = find.byKey(siteOnboardingDemoReadyButtonKey).hitTestable();
  final target = finder.evaluate().isNotEmpty
      ? finder.last
      : find.byKey(siteOnboardingDemoReadyButtonKey).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> tapAdminCreateReady(
  WidgetTester tester, {
  required Key commandDeckKey,
  required Key createButtonKey,
}) async {
  final submitButtonKey = switch (createButtonKey) {
    clientOnboardingCreateReadyButtonKey =>
      clientOnboardingCreateSubmitButtonKey,
    siteOnboardingCreateReadyButtonKey => siteOnboardingCreateSubmitButtonKey,
    employeeOnboardingCreateReadyButtonKey =>
      employeeOnboardingCreateSubmitButtonKey,
    _ => createButtonKey,
  };
  final submitFinder = find.byKey(submitButtonKey);
  final deckFinder = find.descendant(
    of: find.byKey(commandDeckKey),
    matching: find.byKey(createButtonKey),
  );
  final fallbackFinder = find.byKey(createButtonKey);
  final target = submitFinder.evaluate().isNotEmpty
      ? submitFinder.last
      : deckFinder.evaluate().isNotEmpty
      ? deckFinder.last
      : fallbackFinder.last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  final tappable = target.hitTestable();
  await tester.tap(
    tappable.evaluate().isNotEmpty ? tappable.last : target,
    warnIfMissed: false,
  );
  await tester.pumpAndSettle();
}

Future<void> tapAdminClientCreateReady(
  WidgetTester tester, {
  bool settle = true,
}) async {
  final submit = find.byKey(clientOnboardingCreateSubmitButtonKey);
  final readyAction = find.byKey(clientOnboardingCreateReadyButtonKey);
  final fallback = find.widgetWithText(FilledButton, 'Create Client (Ready)');
  final finder = submit.evaluate().isNotEmpty
      ? submit.last
      : readyAction.evaluate().isNotEmpty
      ? readyAction.last
      : fallback.first;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  final tappable = finder.hitTestable();
  await tester.tap(
    tappable.evaluate().isNotEmpty ? tappable.last : finder,
    warnIfMissed: false,
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> tapAdminSiteCreateReady(WidgetTester tester) async {
  final submit = find.byKey(siteOnboardingCreateSubmitButtonKey);
  final readyAction = find.byKey(siteOnboardingCreateReadyButtonKey);
  final fallback = find.widgetWithText(FilledButton, 'Create Site (Ready)');
  final finder = submit.evaluate().isNotEmpty
      ? submit.last
      : readyAction.evaluate().isNotEmpty
      ? readyAction.last
      : fallback.first;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  final tappable = finder.hitTestable();
  await tester.tap(
    tappable.evaluate().isNotEmpty ? tappable.last : finder,
    warnIfMissed: false,
  );
  await tester.pumpAndSettle();
}

Future<void> tapAdminEmployeeDemoReady(WidgetTester tester) async {
  final finder = find.byKey(employeeOnboardingDemoReadyButtonKey).hitTestable();
  final target = finder.evaluate().isNotEmpty
      ? finder.last
      : find.byKey(employeeOnboardingDemoReadyButtonKey).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> tapAdminCreateSuccessSupportAction(
  WidgetTester tester,
  Key actionKey,
) async {
  final finder = find.byKey(actionKey).first;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> waitForAdminCreateSuccessDialog(WidgetTester tester) async {
  final dialogFrame = find.byKey(const ValueKey('admin-create-success-frame'));
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (dialogFrame.evaluate().isNotEmpty) {
      break;
    }
  }
  expect(dialogFrame, findsOneWidget);
}

Future<void> tapAdminBuildDemoStack(WidgetTester tester) async {
  final finder = find.byKey(adminBuildDemoStackButtonKey);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> tapAdminEmployeeCreateReady(WidgetTester tester) async {
  final submit = find.byKey(employeeOnboardingCreateSubmitButtonKey);
  final readyAction = find.byKey(employeeOnboardingCreateReadyButtonKey);
  final fallback = find.widgetWithText(FilledButton, 'Create Employee (Ready)');
  final finder = submit.evaluate().isNotEmpty
      ? submit.first
      : readyAction.evaluate().isNotEmpty
      ? readyAction.first
      : fallback.first;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  final tappable = finder.hitTestable();
  await tester.tap(
    tappable.evaluate().isNotEmpty ? tappable.first : finder,
    warnIfMissed: false,
  );
  await tester.pumpAndSettle();
}

Future<void> pumpAdminRouteApp(
  WidgetTester tester, {
  Key? key,
  OnyxRoute initialRoute = OnyxRoute.admin,
  AdministrationPageTab initialAdminTab = AdministrationPageTab.system,
  void Function(String clientId, String siteId, String room)?
  onClientLaneRouteOpened,
  TelegramBridgeService? telegramBridgeServiceOverride,
  OnyxAgentCameraBridgeStatus? onyxAgentCameraBridgeStatusOverride,
  OnyxAgentCameraBridgeHealthService?
  onyxAgentCameraBridgeHealthServiceOverride,
  String? telegramAdminChatIdOverride,
  int? telegramAdminMessageThreadIdOverride,
  String? telegramChatIdOverride,
  int? telegramMessageThreadIdOverride,
  String? telegramPartnerChatIdOverride,
  String? telegramPartnerClientIdOverride,
  String? telegramPartnerSiteIdOverride,
  List<TelegramBridgeInboundMessage> initialTelegramInboundUpdatesOverride =
      const <TelegramBridgeInboundMessage>[],
  List<DispatchEvent> initialStoreEventsOverride = const <DispatchEvent>[],
}) async {
  await tester.pumpWidget(
    OnyxApp(
      key: key,
      supabaseReady: false,
      initialRouteOverride: initialRoute,
      initialAdminTabOverride: initialAdminTab,
      onClientLaneRouteOpened: onClientLaneRouteOpened,
      telegramBridgeServiceOverride: telegramBridgeServiceOverride,
      onyxAgentCameraBridgeStatusOverride: onyxAgentCameraBridgeStatusOverride,
      onyxAgentCameraBridgeHealthServiceOverride:
          onyxAgentCameraBridgeHealthServiceOverride,
      telegramAdminChatIdOverride: telegramAdminChatIdOverride,
      telegramAdminMessageThreadIdOverride: telegramAdminMessageThreadIdOverride,
      telegramChatIdOverride: telegramChatIdOverride,
      telegramMessageThreadIdOverride: telegramMessageThreadIdOverride,
      telegramPartnerChatIdOverride: telegramPartnerChatIdOverride,
      telegramPartnerClientIdOverride: telegramPartnerClientIdOverride,
      telegramPartnerSiteIdOverride: telegramPartnerSiteIdOverride,
      initialTelegramInboundUpdatesOverride:
          initialTelegramInboundUpdatesOverride,
      initialStoreEventsOverride: initialStoreEventsOverride,
    ),
  );
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pumpAndSettle();
}

Future<void> openAdminSystemAnchor(
  WidgetTester tester,
  String anchorText,
) async {
  final systemTab = find.text('SYSTEM CONTROLS').first;
  await tester.ensureVisible(systemTab);
  await tester.tap(systemTab);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text(anchorText),
    500,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> openAdminClientCommsAudit(WidgetTester tester) async {
  final aiTab = find.text('AI COMMUNICATIONS').first;
  await tester.ensureVisible(aiTab);
  await tester.tap(aiTab);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(adminClientCommsAuditPanelKey),
    500,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> openAdminPendingDraftReview(WidgetTester tester) async {
  final aiTab = find.text('AI COMMUNICATIONS').first;
  await tester.ensureVisible(aiTab);
  await tester.tap(aiTab);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(adminTelegramAiAssistantPanelKey),
    500,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> pumpAndOpenAdminClientCommsAudit(
  WidgetTester tester, {
  Key? key,
  void Function(String clientId, String siteId, String room)?
  onClientLaneRouteOpened,
  TelegramBridgeService? telegramBridgeServiceOverride,
  OnyxAgentCameraBridgeStatus? onyxAgentCameraBridgeStatusOverride,
  OnyxAgentCameraBridgeHealthService?
  onyxAgentCameraBridgeHealthServiceOverride,
}) async {
  await pumpAdminRouteApp(
    tester,
    key: key,
    onClientLaneRouteOpened: onClientLaneRouteOpened,
    telegramBridgeServiceOverride: telegramBridgeServiceOverride,
    onyxAgentCameraBridgeStatusOverride: onyxAgentCameraBridgeStatusOverride,
    onyxAgentCameraBridgeHealthServiceOverride:
        onyxAgentCameraBridgeHealthServiceOverride,
  );
  await openAdminClientCommsAudit(tester);
}

Future<void> pumpLiveOperationsSourceApp(
  WidgetTester tester, {
  Key? key,
  TelegramBridgeService? telegramBridgeServiceOverride,
}) async {
  await tester.pumpWidget(
    OnyxApp(
      key: key,
      supabaseReady: false,
      initialRouteOverride: OnyxRoute.dashboard,
      telegramBridgeServiceOverride: telegramBridgeServiceOverride,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pumpClientControlSourceApp(
  WidgetTester tester, {
  Key? key,
  String? clientId,
  String? siteId,
  List<DispatchEvent> initialStoreEventsOverride = const <DispatchEvent>[],
}) async {
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
      key: key,
      supabaseReady: false,
      initialRouteOverride: OnyxRoute.clients,
      initialClientLaneClientIdOverride: clientId,
      initialClientLaneSiteIdOverride: siteId,
      appModeOverride: OnyxAppMode.client,
      initialStoreEventsOverride: initialStoreEventsOverride,
    ),
  );
  await tester.pumpAndSettle();

  final controlViewChip = find.text('Control View');
  if (controlViewChip.evaluate().isNotEmpty) {
    await tester.ensureVisible(controlViewChip.first);
    await tester.tap(controlViewChip.first);
    await tester.pumpAndSettle();
  }
}

Future<void> openClientControlAnchor(
  WidgetTester tester,
  String anchorText,
) async {
  await tester.scrollUntilVisible(
    find.text(anchorText),
    500,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}
