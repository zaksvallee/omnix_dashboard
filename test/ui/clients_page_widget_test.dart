import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/response_arrived.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/ui/clients_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('clients page incident feed opens events review when wired', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    List<String>? openedEventIds;
    String? openedSelectedEventId;

    await tester.pumpWidget(
      MaterialApp(
        home: ClientsPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: <DispatchEvent>[
            ResponseArrived(
              eventId: 'evt-arrival-1',
              sequence: 1,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 18, 19, 47),
              dispatchId: 'DSP-4',
              clientId: 'CLIENT-001',
              regionId: 'REGION-1',
              siteId: 'SITE-SANDTON',
              guardId: 'GUARD-1',
            ),
          ],
          onOpenEventsForScope: (eventIds, selectedEventId) {
            openedEventIds = eventIds;
            openedSelectedEventId = selectedEventId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final incidentRow = find.byKey(
      const ValueKey('clients-incident-row-Officer Arrived-19:47 UTC'),
    );
    await tester.ensureVisible(incidentRow);
    await tester.tap(incidentRow, warnIfMissed: false);
    await tester.pump();
    expect(openedEventIds, <String>['evt-arrival-1']);
    expect(openedSelectedEventId, 'evt-arrival-1');
  });

  testWidgets(
    'clients page fallback incident feed disables open detail when unwired',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: ClientsPage(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            events: <DispatchEvent>[],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final incidentRow = tester.widget<InkWell>(
        find.byKey(
          const ValueKey('clients-incident-row-Responder On Site-19:47 UTC'),
        ),
      );
      expect(incidentRow.onTap, isNull);
    },
  );

  testWidgets('clients page routes push retry and estate rooms when wired', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var pushRetryCount = 0;
    String? openedRoom;
    String? openedClientId;
    String? openedSiteId;

    await tester.pumpWidget(
      MaterialApp(
        home: ClientsPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: const <DispatchEvent>[],
          onRetryPushSync: () async {
            pushRetryCount += 1;
          },
          onOpenClientRoomForScope: (room, clientId, siteId) {
            openedRoom = room;
            openedClientId = clientId;
            openedSiteId = siteId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('clients-retry-push-sync-action')),
    );
    await tester.pump();
    expect(pushRetryCount, 1);

    await tester.tap(find.byKey(const ValueKey('clients-room-Residents')));
    await tester.pump();
    expect(openedRoom, 'Residents');
    expect(openedClientId, 'CLIENT-001');
    expect(openedSiteId, 'SITE-SANDTON');
  });

  testWidgets(
    'clients page disables push retry and estate rooms when unwired',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: ClientsPage(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            events: <DispatchEvent>[],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final retryPushSync = tester.widget<InkWell>(
        find.byKey(const ValueKey('clients-retry-push-sync-action')),
      );
      final residentsRoom = tester.widget<InkWell>(
        find.byKey(const ValueKey('clients-room-Residents')),
      );

      expect(retryPushSync.onTap, isNull);
      expect(residentsRoom.onTap, isNull);
      expect(
        find.text('Room routing is view-only in this session.'),
        findsOneWidget,
      );
    },
  );
}
