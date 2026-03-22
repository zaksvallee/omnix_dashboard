import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/response_arrived.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/ui/clients_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('clients page renders figma-style communications body', (
    tester,
  ) async {
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

    expect(find.text('Client Communications'), findsOneWidget);
    expect(find.text('ACTIVE LANES'), findsOneWidget);
    expect(find.text('ROOM & THREAD CONTEXT'), findsOneWidget);
    expect(find.text('COMMUNICATION CHANNELS'), findsOneWidget);
    expect(find.text('MESSAGE HISTORY'), findsOneWidget);
    expect(find.text('PENDING AI DRAFTS'), findsOneWidget);
    expect(find.text('LEARNED STYLE'), findsOneWidget);
    expect(find.text('PINNED VOICE'), findsOneWidget);
  });

  testWidgets('clients page desktop workspace rail routes live actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var pushRetryCount = 0;
    String? openedRoom;
    String? openedRoomClientId;
    String? openedRoomSiteId;
    List<String>? openedEventIds;
    String? openedSelectedEventId;

    await tester.pumpWidget(
      MaterialApp(
        home: ClientsPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: <DispatchEvent>[
            IntelligenceReceived(
              eventId: 'evt-workspace-1',
              sequence: 4,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 18, 19, 38),
              intelligenceId: 'intel-workspace-1',
              provider: 'ai',
              sourceType: 'telegram',
              externalId: 'ext-workspace-1',
              clientId: 'CLIENT-001',
              regionId: 'REGION-1',
              siteId: 'SITE-SANDTON',
              headline: 'Workspace draft review',
              summary: 'Draft message is awaiting control approval.',
              riskScore: 71,
              canonicalHash: 'hash-workspace-1',
            ),
          ],
          onRetryPushSync: () async {
            pushRetryCount += 1;
          },
          onOpenClientRoomForScope: (room, clientId, siteId) {
            openedRoom = room;
            openedRoomClientId = clientId;
            openedRoomSiteId = siteId;
          },
          onOpenEventsForScope: (eventIds, selectedEventId) {
            openedEventIds = eventIds;
            openedSelectedEventId = selectedEventId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('clients-workspace-panel-rail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('clients-workspace-panel-board')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('clients-workspace-panel-context')),
      findsOneWidget,
    );

    final reviewAction = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('clients-workspace-open-review')),
    );
    expect(reviewAction.onPressed, isNotNull);
    reviewAction.onPressed!.call();
    await tester.pump();
    expect(openedEventIds, <String>['evt-workspace-1']);
    expect(openedSelectedEventId, 'evt-workspace-1');

    final roomAction = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('clients-workspace-open-residents-room')),
    );
    expect(roomAction.onPressed, isNotNull);
    roomAction.onPressed!.call();
    await tester.pump();
    expect(openedRoom, 'Residents');
    expect(openedRoomClientId, 'CLIENT-001');
    expect(openedRoomSiteId, 'SITE-SANDTON');

    final retryAction = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('clients-workspace-retry-sync')),
    );
    expect(retryAction.onPressed, isNotNull);
    retryAction.onPressed!.call();
    await tester.pump();
    expect(pushRetryCount, 1);
  });

  testWidgets(
    'clients page switches active lanes and routes workspace banner actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var pushRetryCount = 0;
      String? openedRoom;
      String? openedRoomClientId;
      String? openedRoomSiteId;
      List<String>? openedEventIds;
      String? openedSelectedEventId;

      await tester.pumpWidget(
        MaterialApp(
          home: ClientsPage(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            events: <DispatchEvent>[
              IntelligenceReceived(
                eventId: 'evt-lane-review-0',
                sequence: 6,
                version: 1,
                occurredAt: DateTime.utc(2026, 3, 18, 20, 4),
                intelligenceId: 'intel-lane-review-0',
                provider: 'ai',
                sourceType: 'telegram',
                externalId: 'ext-lane-review-0',
                clientId: 'CLIENT-001',
                regionId: 'REGION-1',
                siteId: 'SITE-SANDTON',
                headline: 'Sandton lane warmup',
                summary: 'Primary lane remains active.',
                riskScore: 44,
                canonicalHash: 'hash-lane-review-0',
              ),
              IntelligenceReceived(
                eventId: 'evt-lane-review-1',
                sequence: 7,
                version: 1,
                occurredAt: DateTime.utc(2026, 3, 18, 20, 14),
                intelligenceId: 'intel-lane-review-1',
                provider: 'ai',
                sourceType: 'telegram',
                externalId: 'ext-lane-review-1',
                clientId: 'CLIENT-002',
                regionId: 'REGION-1',
                siteId: 'SITE-BLR',
                headline: 'Blue Ridge lane draft review',
                summary: 'Blue Ridge draft message is awaiting approval.',
                riskScore: 76,
                canonicalHash: 'hash-lane-review-1',
              ),
            ],
            onRetryPushSync: () async {
              pushRetryCount += 1;
            },
            onOpenClientRoomForScope: (room, clientId, siteId) {
              openedRoom = room;
              openedRoomClientId = clientId;
              openedRoomSiteId = siteId;
            },
            onOpenEventsForScope: (eventIds, selectedEventId) {
              openedEventIds = eventIds;
              openedSelectedEventId = selectedEventId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('clients-workspace-status-banner')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey('clients-active-lane-card-CLIENT-002-SITE-BLR'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT-002 / SITE-BLR'), findsOneWidget);

      final roomAction = tester.widget<OutlinedButton>(
        find.byKey(
          const ValueKey('clients-workspace-banner-open-residents-room'),
        ),
      );
      expect(roomAction.onPressed, isNotNull);
      roomAction.onPressed!.call();
      await tester.pump();
      expect(openedRoom, 'Residents');
      expect(openedRoomClientId, 'CLIENT-002');
      expect(openedRoomSiteId, 'SITE-BLR');

      final reviewAction = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('clients-workspace-banner-open-review')),
      );
      expect(reviewAction.onPressed, isNotNull);
      reviewAction.onPressed!.call();
      await tester.pump();
      expect(openedEventIds, <String>['evt-lane-review-1']);
      expect(openedSelectedEventId, 'evt-lane-review-1');

      final retryAction = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('clients-workspace-banner-retry-sync')),
      );
      expect(retryAction.onPressed, isNotNull);
      retryAction.onPressed!.call();
      await tester.pump();
      expect(pushRetryCount, 1);
    },
  );

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
    await tester.pumpAndSettle();
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

    final retryAction = find.byKey(
      const ValueKey('clients-retry-push-sync-action'),
    );
    await tester.ensureVisible(retryAction);
    await tester.pumpAndSettle();
    await tester.tap(retryAction, warnIfMissed: false);
    await tester.pump();
    expect(pushRetryCount, 1);

    final residentsRoom = tester.widget<InkWell>(
      find.byKey(const ValueKey('clients-room-Residents')),
    );
    expect(residentsRoom.onTap, isNotNull);
    residentsRoom.onTap!.call();
    await tester.pump();
    expect(openedRoom, 'Residents');
    expect(openedClientId, 'CLIENT-001');
    expect(openedSiteId, 'SITE-SANDTON');
  });

  testWidgets('clients page review drafts opens scoped events when available', (
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
            IntelligenceReceived(
              eventId: 'evt-draft-1',
              sequence: 4,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 18, 19, 38),
              intelligenceId: 'intel-1',
              provider: 'ai',
              sourceType: 'telegram',
              externalId: 'ext-1',
              clientId: 'CLIENT-001',
              regionId: 'REGION-1',
              siteId: 'SITE-SANDTON',
              headline: 'Review unusual camera movement',
              summary: 'Draft message is awaiting control approval.',
              riskScore: 71,
              canonicalHash: 'hash-1',
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

    final reviewDrafts = find.byKey(
      const ValueKey('clients-review-drafts-action'),
    );
    await tester.ensureVisible(reviewDrafts);
    await tester.tap(reviewDrafts, warnIfMissed: false);
    await tester.pump();

    expect(openedEventIds, <String>['evt-draft-1']);
    expect(openedSelectedEventId, 'evt-draft-1');
  });

  testWidgets('clients page channel controls update stage and pinned voice', (
    tester,
  ) async {
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

    final placeCall = find.byKey(
      const ValueKey('clients-place-call-now-action'),
    );
    await tester.ensureVisible(placeCall);
    final placeCallInkWell = tester.widget<InkWell>(placeCall);
    placeCallInkWell.onTap!.call();
    await tester.pumpAndSettle();

    expect(find.text('Call In Progress'), findsOneWidget);
    expect(find.text('VoIP Ready'), findsOneWidget);

    await tester.tap(find.text('Formal'));
    await tester.pumpAndSettle();

    final formalText = tester.widget<Text>(find.text('Formal'));
    expect(formalText.style?.color, const Color(0xFF5DE1FF));

    final cancelStage = find.byKey(
      const ValueKey('clients-cancel-stage-action'),
    );
    await tester.ensureVisible(cancelStage);
    final cancelStageInkWell = tester.widget<InkWell>(cancelStage);
    cancelStageInkWell.onTap!.call();
    await tester.pumpAndSettle();

    expect(find.text('VoIP Call Active'), findsNothing);
    expect(find.text('VoIP Idle'), findsOneWidget);
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
