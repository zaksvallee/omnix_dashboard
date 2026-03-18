import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';

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

      final messageButton = find
          .widgetWithText(OutlinedButton, 'Message')
          .first;
      await tester.ensureVisible(messageButton);
      await tester.tap(messageButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Client Lane'));
      await tester.pumpAndSettle();

      expect(openedClientId, 'CLIENT-MS-VALLEE');
      expect(openedSiteId, isNotEmpty);
      expect(openedRoom, isEmpty);
      expect(find.textContaining('Client Operations'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app stages guard voip call into scoped comms persistence',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.guards,
        ),
      );
      await tester.pumpAndSettle();

      final callButton = find.widgetWithText(OutlinedButton, 'Call').first;
      await tester.ensureVisible(callButton);
      await tester.tap(callButton);
      await tester.pumpAndSettle();

      expect(find.text('Voice Call Staging'), findsOneWidget);

      await tester.tap(find.text('Stage VoIP Call'));
      await tester.pumpAndSettle();

      final persistence = await DispatchPersistenceService.create();
      final scopeKeys = await persistence.readClientConversationScopeKeys();
      final scopedPushSyncState = await persistence.readScopedClientAppPushSyncState(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );

      expect(scopeKeys, contains('CLIENT-MS-VALLEE|WTF-MAIN'));
      expect(scopedPushSyncState.history, isNotEmpty);
      expect(scopedPushSyncState.history.first.status, 'voip-failed');
      expect(
        scopedPushSyncState.history.first.failureReason,
        contains('VoIP staging is not configured for Thabo Mokoena yet.'),
      );
    },
  );
}
