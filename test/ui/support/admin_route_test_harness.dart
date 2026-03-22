import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/application/telegram_bridge_service.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/admin_page.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/client_app_page.dart';

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

Future<void> pumpAdminRouteApp(
  WidgetTester tester, {
  Key? key,
  OnyxRoute initialRoute = OnyxRoute.admin,
  AdministrationPageTab initialAdminTab = AdministrationPageTab.system,
  void Function(String clientId, String siteId, String room)?
  onClientLaneRouteOpened,
  TelegramBridgeService? telegramBridgeServiceOverride,
}) async {
  await tester.pumpWidget(
    OnyxApp(
      key: key,
      supabaseReady: false,
      initialRouteOverride: initialRoute,
      initialAdminTabOverride: initialAdminTab,
      onClientLaneRouteOpened: onClientLaneRouteOpened,
      telegramBridgeServiceOverride: telegramBridgeServiceOverride,
    ),
  );
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
    find.text('Client Comms Audit'),
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
    find.text('CLIENT ASKED'),
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
}) async {
  await pumpAdminRouteApp(
    tester,
    key: key,
    onClientLaneRouteOpened: onClientLaneRouteOpened,
    telegramBridgeServiceOverride: telegramBridgeServiceOverride,
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
