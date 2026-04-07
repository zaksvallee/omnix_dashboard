import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/response_arrived.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/ui/clients_page.dart';
import 'package:omnix_dashboard/ui/client_comms_queue_board.dart';

Future<void> _openDetailedWorkspaceIfPresent(WidgetTester tester) async {
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

final DateTime _clientsAgentDraftBaseUtc = DateTime.now().toUtc().subtract(
  const Duration(minutes: 10),
);

DateTime _agentDraftCreatedAtUtc(int minute) =>
    _clientsAgentDraftBaseUtc.add(Duration(minutes: minute - 15));

DateTime _clientsPageScenarioOccurredAtUtc(int hour, int minute) =>
    DateTime.utc(2026, 3, 18, hour, minute);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('clients page renders simple comms approval queue by default', (
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
    expect(
      find.text('AI-generated messages awaiting approval'),
      findsOneWidget,
    );
    expect(find.text('3 PENDING MESSAGES'), findsOneWidget);
    expect(find.text('Sandton Corp'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('clients-simple-queue-board')),
      findsOneWidget,
    );
    expect(find.text('ACTIVE LANES'), findsNothing);
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
              occurredAt: _clientsPageScenarioOccurredAtUtc(19, 38),
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
    await _openDetailedWorkspaceIfPresent(tester);

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

    final reviewAction = find.byKey(
      const ValueKey('clients-review-drafts-action'),
    );
    await tester.ensureVisible(reviewAction);
    final reviewInkWell = tester.widget<InkWell>(reviewAction);
    expect(reviewInkWell.onTap, isNotNull);
    reviewInkWell.onTap!.call();
    await tester.pump();
    expect(openedEventIds, <String>['evt-workspace-1']);
    expect(openedSelectedEventId, 'evt-workspace-1');

    final roomAction = find.byKey(const ValueKey('clients-room-Residents'));
    await tester.ensureVisible(roomAction);
    final roomInkWell = tester.widget<InkWell>(roomAction);
    expect(roomInkWell.onTap, isNotNull);
    roomInkWell.onTap!.call();
    await tester.pump();
    expect(openedRoom, 'Residents');
    expect(openedRoomClientId, 'CLIENT-001');
    expect(openedRoomSiteId, 'SITE-SANDTON');

    final retryAction = find.byKey(
      const ValueKey('clients-retry-push-sync-action'),
    );
    await tester.ensureVisible(retryAction);
    final retryInkWell = tester.widget<InkWell>(retryAction);
    expect(retryInkWell.onTap, isNotNull);
    retryInkWell.onTap!.call();
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
                occurredAt: _clientsPageScenarioOccurredAtUtc(20, 4),
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
                occurredAt: _clientsPageScenarioOccurredAtUtc(20, 14),
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
      await _openDetailedWorkspaceIfPresent(tester);

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

      final roomAction = find.byKey(const ValueKey('clients-room-Residents'));
      await tester.ensureVisible(roomAction);
      final roomInkWell = tester.widget<InkWell>(roomAction);
      expect(roomInkWell.onTap, isNotNull);
      roomInkWell.onTap!.call();
      await tester.pump();
      expect(openedRoom, 'Residents');
      expect(openedRoomClientId, 'CLIENT-002');
      expect(openedRoomSiteId, 'SITE-BLR');

      final reviewAction = find.byKey(
        const ValueKey('clients-review-drafts-action'),
      );
      await tester.ensureVisible(reviewAction);
      final reviewInkWell = tester.widget<InkWell>(reviewAction);
      expect(reviewInkWell.onTap, isNotNull);
      reviewInkWell.onTap!.call();
      await tester.pump();
      expect(openedEventIds, <String>['evt-lane-review-1']);
      expect(openedSelectedEventId, 'evt-lane-review-1');

      final retryAction = find.byKey(
        const ValueKey('clients-retry-push-sync-action'),
      );
      await tester.ensureVisible(retryAction);
      final retryInkWell = tester.widget<InkWell>(retryAction);
      expect(retryInkWell.onTap, isNotNull);
      retryInkWell.onTap!.call();
      await tester.pump();
      expect(pushRetryCount, 1);
    },
  );

  testWidgets(
    'clients page routes scoped agent handoffs from draft rail, hero, banner, and incident feed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? openedIncidentReference;

      await tester.pumpWidget(
        MaterialApp(
          home: ClientsPage(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            events: <DispatchEvent>[
              IntelligenceReceived(
                eventId: 'evt-agent-1',
                sequence: 8,
                version: 1,
                occurredAt: _clientsPageScenarioOccurredAtUtc(20, 14),
                intelligenceId: 'INC-CLIENT-77',
                provider: 'ai',
                sourceType: 'telegram',
                externalId: 'ext-agent-1',
                clientId: 'CLIENT-001',
                regionId: 'REGION-1',
                siteId: 'SITE-SANDTON',
                headline: 'Resident lane asks for an updated ETA.',
                summary:
                    'Agent handoff should preserve the current lane scope.',
                riskScore: 76,
                canonicalHash: 'hash-agent-1',
              ),
              DecisionCreated(
                eventId: 'evt-agent-2',
                sequence: 7,
                version: 1,
                occurredAt: _clientsPageScenarioOccurredAtUtc(20, 4),
                dispatchId: 'DSP-CLIENT-19',
                clientId: 'CLIENT-002',
                regionId: 'REGION-1',
                siteId: 'SITE-BLR',
              ),
            ],
            onOpenAgentForIncident: (incidentReference) {
              openedIncidentReference = incidentReference;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openDetailedWorkspaceIfPresent(tester);

      final heroAgentAction = find.byKey(
        const ValueKey('clients-open-agent-button'),
      );
      final draftRailAgentAction = find.byKey(
        const ValueKey('clients-review-drafts-open-agent'),
      );
      final threadAgentAction = find.byKey(
        const ValueKey('clients-thread-open-agent'),
      );
      final channelAgentAction = find.byKey(
        const ValueKey('clients-channel-open-agent'),
      );
      await tester.ensureVisible(draftRailAgentAction);
      await tester.tap(draftRailAgentAction);
      await tester.pump();
      expect(openedIncidentReference, 'INC-CLIENT-77');

      await tester.ensureVisible(threadAgentAction);
      await tester.tap(threadAgentAction);
      await tester.pump();
      expect(openedIncidentReference, 'INC-CLIENT-77');

      await tester.ensureVisible(channelAgentAction);
      await tester.tap(channelAgentAction);
      await tester.pump();
      expect(openedIncidentReference, 'INC-CLIENT-77');

      final updateRowAgentAction = find.byKey(
        const ValueKey('clients-incident-redraft-agent-evt-agent-1'),
      );
      await tester.ensureVisible(updateRowAgentAction);
      await tester.tap(updateRowAgentAction);
      await tester.pump();
      expect(openedIncidentReference, 'INC-CLIENT-77');
      expect(updateRowAgentAction, findsOneWidget);

      await tester.ensureVisible(heroAgentAction);
      await tester.tap(heroAgentAction);
      await tester.pump();
      expect(openedIncidentReference, 'INC-CLIENT-77');

      await tester.tap(
        find.byKey(
          const ValueKey('clients-active-lane-card-CLIENT-002-SITE-BLR'),
        ),
      );
      await tester.pumpAndSettle();

      final bannerAgentAction = find.byKey(
        const ValueKey('clients-workspace-open-agent'),
      );
      await tester.ensureVisible(bannerAgentAction);
      await tester.tap(bannerAgentAction);
      await tester.pump();
      expect(openedIncidentReference, 'DSP-CLIENT-19');

      final feedRowAgentAction = find.byKey(
        const ValueKey('clients-incident-open-agent-evt-agent-2'),
      );
      await tester.ensureVisible(feedRowAgentAction);
      await tester.tap(feedRowAgentAction);
      await tester.pump();
      expect(openedIncidentReference, 'DSP-CLIENT-19');
    },
  );

  testWidgets(
    'clients page imports staged agent drafts into the simple approval queue',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? consumedHandoffId;
      String? openedIncidentReference;

      await tester.pumpWidget(
        MaterialApp(
          home: ClientsPage(
            clientId: 'CLIENT-AGENT',
            siteId: 'SITE-AGENT',
            events: const <DispatchEvent>[],
            stagedAgentDraftHandoff: ClientsAgentDraftHandoff(
              id: 'agent-draft-1',
              clientId: 'CLIENT-AGENT',
              siteId: 'SITE-AGENT',
              room: 'Residents',
              incidentReference: 'INC-AGENT-9',
              draftText: 'Controller handoff draft from Agent.',
              originalDraftText: 'Controller handoff draft from Agent.',
              sourceRouteLabel: 'Clients',
              createdAtUtc: _agentDraftCreatedAtUtc(15),
            ),
            onConsumeStagedAgentDraftHandoff: (handoffId) {
              consumedHandoffId = handoffId;
            },
            onOpenAgentForIncident: (incidentReference) {
              openedIncidentReference = incidentReference;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(consumedHandoffId, 'agent-draft-1');
      expect(
        find.byKey(const ValueKey('clients-simple-card-agent-draft-1')),
        findsOneWidget,
      );
      expect(find.text('INC-AGENT-9'), findsOneWidget);
      expect(
        find.textContaining('Agent handoff ready for Residents from Clients.'),
        findsOneWidget,
      );
      expect(find.text('Controller handoff draft from Agent.'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('clients-open-agent-INC-AGENT-9')),
      );
      await tester.pump();
      expect(openedIncidentReference, 'INC-AGENT-9');

      await tester.tap(
        find.byKey(const ValueKey('clients-send-draft-agent-draft-1')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('clients-simple-card-agent-draft-1')),
        findsNothing,
      );
    },
  );

  testWidgets('clients page ingests evidence returns into the status banner', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? consumedAuditId;

    await tester.pumpWidget(
      MaterialApp(
        home: ClientsPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: const <DispatchEvent>[],
          evidenceReturnReceipt: const ClientsEvidenceReturnReceipt(
            auditId: 'OPS-AUDIT-COMMS-1',
            label: 'LIVE OPS RETURN',
            headline: 'Returned to client handoff for DSP-2443.',
            detail:
                'The signed client handoff was verified in the ledger. Keep the same lane open and finish the operator reply from this thread.',
            accent: Color(0xFF22D3EE),
          ),
          onConsumeEvidenceReturnReceipt: (auditId) {
            consumedAuditId = auditId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openDetailedWorkspaceIfPresent(tester);

    expect(find.text('EVIDENCE RETURN'), findsOneWidget);
    expect(find.text('LIVE OPS RETURN'), findsOneWidget);
    expect(
      find.text('Returned to client handoff for DSP-2443.'),
      findsOneWidget,
    );
    expect(consumedAuditId, 'OPS-AUDIT-COMMS-1');

    await tester.tap(
      find.byKey(const ValueKey('clients-acknowledge-evidence-return')),
    );
    await tester.pumpAndSettle();

    expect(find.text('EVIDENCE RETURN'), findsNothing);
  });

  testWidgets(
    'clients page uses staged agent draft scope for the detailed workspace agent handoff',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? openedIncidentReference;

      await tester.pumpWidget(
        MaterialApp(
          home: ClientsPage(
            clientId: 'CLIENT-AGENT',
            siteId: 'SITE-AGENT',
            events: const <DispatchEvent>[],
            stagedAgentDraftHandoff: ClientsAgentDraftHandoff(
              id: 'agent-draft-2',
              clientId: 'CLIENT-AGENT',
              siteId: 'SITE-AGENT',
              room: 'Residents',
              incidentReference: 'INC-AGENT-11',
              draftText: 'Second controller handoff draft from Agent.',
              originalDraftText: 'Second controller handoff draft from Agent.',
              sourceRouteLabel: 'Clients',
              createdAtUtc: _agentDraftCreatedAtUtc(17),
            ),
            onOpenAgentForIncident: (incidentReference) {
              openedIncidentReference = incidentReference;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openDetailedWorkspaceIfPresent(tester);

      final heroAgentAction = find.byKey(
        const ValueKey('clients-open-agent-button'),
      );
      await tester.ensureVisible(heroAgentAction);
      await tester.tap(heroAgentAction);
      await tester.pump();

      expect(openedIncidentReference, 'INC-AGENT-11');
    },
  );

  testWidgets(
    'clients page reflects staged agent drafts across the detailed comms workspace',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? openedIncidentReference;

      await tester.pumpWidget(
        MaterialApp(
          home: ClientsPage(
            clientId: 'CLIENT-AGENT',
            siteId: 'SITE-AGENT',
            events: const <DispatchEvent>[],
            stagedAgentDraftHandoff: ClientsAgentDraftHandoff(
              id: 'agent-draft-3',
              clientId: 'CLIENT-AGENT',
              siteId: 'SITE-AGENT',
              room: 'Security Desk',
              incidentReference: 'INC-AGENT-12',
              draftText: 'Third controller handoff draft from Agent.',
              originalDraftText: 'Third controller handoff draft from Agent.',
              sourceRouteLabel: 'Clients',
              createdAtUtc: _agentDraftCreatedAtUtc(20),
            ),
            onOpenAgentForIncident: (incidentReference) {
              openedIncidentReference = incidentReference;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openDetailedWorkspaceIfPresent(tester);

      expect(find.text('Redraft with Junior Analyst'), findsWidgets);
      expect(find.text('Open queued draft'), findsWidgets);

      final reviewDraftsOpenAgent = find.byKey(
        const ValueKey('clients-review-drafts-open-agent'),
      );
      final threadAgentAction = find.byKey(
        const ValueKey('clients-thread-open-agent'),
      );
      final threadQueuedDraftAction = find.byKey(
        const ValueKey('clients-thread-review-queued-draft'),
      );
      final channelAgentAction = find.byKey(
        const ValueKey('clients-channel-open-agent'),
      );
      final channelQueuedDraftAction = find.byKey(
        const ValueKey('clients-channel-review-queued-draft'),
      );

      await tester.ensureVisible(reviewDraftsOpenAgent);
      await tester.tap(reviewDraftsOpenAgent);
      await tester.pump();
      expect(openedIncidentReference, 'INC-AGENT-12');

      await tester.ensureVisible(threadAgentAction);
      await tester.tap(threadAgentAction);
      await tester.pump();
      expect(openedIncidentReference, 'INC-AGENT-12');

      await tester.ensureVisible(channelAgentAction);
      await tester.tap(channelAgentAction);
      await tester.pump();
      expect(openedIncidentReference, 'INC-AGENT-12');

      await tester.ensureVisible(threadQueuedDraftAction);
      await tester.tap(threadQueuedDraftAction);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('clients-simple-card-focus-agent-draft-3')),
        findsOneWidget,
      );
      expect(find.text('RESUME THREAD CONTEXT'), findsOneWidget);

      await _openDetailedWorkspaceIfPresent(tester);
      await tester.ensureVisible(channelQueuedDraftAction);
      await tester.tap(channelQueuedDraftAction);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('clients-simple-card-focus-agent-draft-3')),
        findsOneWidget,
      );
      expect(find.text('RESUME CHANNEL REVIEW'), findsOneWidget);

      await _openDetailedWorkspaceIfPresent(tester);
      final reviewDraftsAction = find.byKey(
        const ValueKey('clients-review-drafts-action'),
      );
      await tester.ensureVisible(reviewDraftsAction);
      await tester.tap(reviewDraftsAction);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('clients-simple-queue-board')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('clients-simple-card-agent-draft-3')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('clients-simple-card-focus-agent-draft-3')),
        findsOneWidget,
      );
      expect(find.text('RESUME DRAFT RAIL'), findsOneWidget);
    },
  );

  testWidgets(
    'clients page resumes detailed comms from the focused queue draft',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: ClientsPage(
            clientId: 'CLIENT-AGENT',
            siteId: 'SITE-AGENT',
            events: const <DispatchEvent>[],
            stagedAgentDraftHandoff: ClientsAgentDraftHandoff(
              id: 'agent-draft-4',
              clientId: 'CLIENT-AGENT',
              siteId: 'SITE-AGENT',
              room: 'Residents',
              incidentReference: 'INC-AGENT-13',
              draftText: 'Fourth controller handoff draft from Agent.',
              originalDraftText: 'Fourth controller handoff draft from Agent.',
              sourceRouteLabel: 'Clients',
              createdAtUtc: _agentDraftCreatedAtUtc(24),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final resumeDetailedCommsAction = find.byKey(
        const ValueKey('clients-resume-detailed-workspace-agent-draft-4'),
      );
      await tester.ensureVisible(resumeDetailedCommsAction);
      expect(find.text('RESUME DRAFT RAIL'), findsOneWidget);
      await tester.tap(resumeDetailedCommsAction);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('clients-workspace-panel-board')),
        findsOneWidget,
      );
      expect(find.text('Open queued draft'), findsWidgets);
      expect(
        find.byKey(const ValueKey('clients-thread-review-queued-draft')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('clients-channel-review-queued-draft')),
        findsOneWidget,
      );
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
              occurredAt: _clientsPageScenarioOccurredAtUtc(19, 47),
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
    await _openDetailedWorkspaceIfPresent(tester);

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
      await _openDetailedWorkspaceIfPresent(tester);

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
    await _openDetailedWorkspaceIfPresent(tester);

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
              occurredAt: _clientsPageScenarioOccurredAtUtc(19, 38),
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
    await _openDetailedWorkspaceIfPresent(tester);

    final reviewDrafts = find.byKey(
      const ValueKey('clients-review-drafts-action'),
    );
    await tester.ensureVisible(reviewDrafts);
    await tester.tap(reviewDrafts, warnIfMissed: false);
    await tester.pump();

    expect(openedEventIds, <String>['evt-draft-1']);
    expect(openedSelectedEventId, 'evt-draft-1');
  });

  testWidgets(
    'clients page hides unconfigured voip controls and keeps pinned voice interactive',
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
    await _openDetailedWorkspaceIfPresent(tester);

    expect(find.text('VoIP unconfigured'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('clients-place-call-now-action')),
      findsNothing,
    );
    expect(find.text('Learned tone'), findsNothing);

    final formalVoice = find.byKey(
      const ValueKey('clients-pinned-voice-Formal'),
    );
    await tester.ensureVisible(formalVoice);
    await tester.tap(formalVoice);
    await tester.pumpAndSettle();

    final formalText = tester.widget<Text>(
      find.descendant(of: formalVoice, matching: find.text('Formal')),
    );
    expect(formalText.style?.color, const Color(0xFF325996));
  });

  testWidgets('clients page resets push retry status after callback completes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final completer = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: ClientsPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: const <DispatchEvent>[],
          onRetryPushSync: () => completer.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openDetailedWorkspaceIfPresent(tester);

    expect(find.text('Push idle'), findsOneWidget);

    final retryAction = find.byKey(
      const ValueKey('clients-retry-push-sync-action'),
    );
    await tester.ensureVisible(retryAction);
    await tester.tap(retryAction, warnIfMissed: false);
    await tester.pump();
    expect(find.text('Push review'), findsOneWidget);

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.text('Push idle'), findsOneWidget);
  });

  testWidgets('clients page edit draft modal exposes AI assist for staged replies', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var aiAssistCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ClientsPage(
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          events: const <DispatchEvent>[],
          stagedAgentDraftHandoff: ClientsAgentDraftHandoff(
            id: 'agent-draft-1',
            clientId: 'CLIENT-MS-VALLEE',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            room: 'Residents',
            incidentReference: '',
            draftText: 'Control confirms that everything is good.',
            originalDraftText: 'Control confirms that everything is good.',
            sourceRouteLabel: 'Live Follow-up',
            createdAtUtc: _agentDraftCreatedAtUtc(22),
            severity: ClientCommsQueueSeverity.high,
          ),
          onAiAssistQueueDraft: (clientId, siteId, room, currentDraftText) async {
            aiAssistCalls += 1;
            expect(clientId, 'CLIENT-MS-VALLEE');
            expect(siteId, 'SITE-MS-VALLEE-RESIDENCE');
            expect(room, 'Residents');
            expect(
              currentDraftText,
              'Control confirms that everything is good.',
            );
            return 'Control has followed up and there is no confirmed problem on site right now. We will update you again as soon as remote monitoring is restored.';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editAction = find.byKey(
      const ValueKey('clients-edit-draft-agent-draft-1'),
    );
    await tester.ensureVisible(editAction);
    await tester.tap(editAction);
    await tester.pumpAndSettle();

    expect(find.text('Edit Draft'), findsOneWidget);
    final aiAssistAction = find.byKey(
      const ValueKey('clients-edit-draft-ai-assist'),
    );
    expect(aiAssistAction, findsOneWidget);

    await tester.tap(aiAssistAction);
    await tester.pumpAndSettle();

    expect(aiAssistCalls, 1);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Control has followed up and there is no confirmed problem on site right now. We will update you again as soon as remote monitoring is restored.',
    );
  });

  testWidgets(
    'clients page preserves scoped thread focus across route handoffs without placeholder contamination',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1880, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: ClientsPage(
            clientId: 'CLIENT-VALLEE',
            siteId: 'SITE-VALLEE',
            events: <DispatchEvent>[],
            usePlaceholderDataWhenEmpty: false,
            routeHandoffToken: 1,
            routeHandoffTarget: ClientsRouteHandoffTarget.threadContext,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('clients-workspace-panel-board')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('clients-simple-queue-board')),
        findsNothing,
      );
      expect(find.text('Vallee'), findsWidgets);
      expect(find.text('Sandton Corp'), findsNothing);

      await tester.pumpWidget(
        const MaterialApp(
          home: ClientsPage(
            clientId: 'CLIENT-SANDTON',
            siteId: 'SITE-SANDTON',
            events: <DispatchEvent>[],
            usePlaceholderDataWhenEmpty: false,
            routeHandoffToken: 2,
            routeHandoffTarget: ClientsRouteHandoffTarget.threadContext,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('clients-workspace-panel-board')),
        findsOneWidget,
      );
      expect(find.text('Sandton'), findsWidgets);
      expect(find.text('Vallee'), findsNothing);
    },
  );

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
      await _openDetailedWorkspaceIfPresent(tester);

      final retryPushSync = tester.widget<InkWell>(
        find.byKey(const ValueKey('clients-retry-push-sync-action')),
      );
      final residentsRoom = tester.widget<InkWell>(
        find.byKey(const ValueKey('clients-room-Residents')),
      );

      expect(retryPushSync.onTap, isNull);
      expect(residentsRoom.onTap, isNull);
      expect(
        find.text('Room switching is view-only in this session.'),
        findsOneWidget,
      );
    },
  );
}
