import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/ui/tactical_page.dart';
import 'package:omnix_dashboard/ui/track_overview_board.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_sections.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_view.dart';

DateTime _tacticalSuppressedReviewReviewedAtUtc() =>
    DateTime.utc(2026, 3, 13, 21, 14);

DateTime _tacticalNowUtc() => DateTime.now().toUtc();

Future<void> openDetailedWorkspaceIfVisible(WidgetTester tester) async {
  if (find
      .byKey(const ValueKey('tactical-workspace-panel-map'))
      .evaluate()
      .isNotEmpty) {
    return;
  }
  final toggle = find.byKey(
    const ValueKey('tactical-toggle-detailed-workspace'),
  );
  if (toggle.evaluate().isEmpty) {
    return;
  }
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tactical page stays stable on phone viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: TacticalPage(events: [])));
    await tester.pumpAndSettle();

    expect(find.text('TACTICAL MAP'), findsOneWidget);
    expect(find.text('VERIFICATION LENS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tactical page header dispatch button opens the scoped dispatch lane',
    (tester) async {
      String? tappedClientId;
      String? tappedSiteId;
      String? tappedReference;

      await tester.pumpWidget(
        MaterialApp(
          home: TacticalPage(
            events: const [],
            initialScopeClientId: 'CLIENT-A',
            initialScopeSiteId: 'SITE-A',
            onOpenFleetDispatchScope: (clientId, siteId, incidentReference) {
              tappedClientId = clientId;
              tappedSiteId = siteId;
              tappedReference = incidentReference;
            },
            fleetScopeHealth: const [
              VideoFleetScopeHealthView(
                clientId: 'CLIENT-A',
                siteId: 'SITE-A',
                siteName: 'MS Vallee Residence',
                endpointLabel: '192.168.8.105',
                statusLabel: 'LIMITED WATCH',
                watchLabel: 'LIMITED',
                recentEvents: 0,
                lastSeenLabel: '21:14 UTC',
                freshnessLabel: 'Fresh',
                isStale: false,
                latestIncidentReference: 'INT-VALLEE-1',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tactical Command'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('tactical-open-dispatches-button')),
      );
      await tester.pumpAndSettle();

      expect(tappedClientId, 'CLIENT-A');
      expect(tappedSiteId, 'SITE-A');
      expect(tappedReference, 'INT-VALLEE-1');
    },
  );

  testWidgets('tactical page hero asks agent for the scoped incident', (
    tester,
  ) async {
    String? openedIncidentReference;

    await tester.pumpWidget(
      MaterialApp(
        home: TacticalPage(
          events: const [],
          focusIncidentReference: 'INC-TRACK-77',
          onOpenAgentForIncident: (incidentReference) {
            openedIncidentReference = incidentReference;
          },
          fleetScopeHealth: const [
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-A',
              siteId: 'SITE-A',
              siteName: 'MS Vallee Residence',
              endpointLabel: '192.168.8.105',
              statusLabel: 'LIMITED WATCH',
              watchLabel: 'LIMITED',
              recentEvents: 0,
              lastSeenLabel: '21:14 UTC',
              freshnessLabel: 'Fresh',
              isStale: false,
              latestIncidentReference: 'INT-VALLEE-1',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final askAgentButton = find.byKey(
      const ValueKey('tactical-open-agent-button'),
    );
    await tester.ensureVisible(askAgentButton);
    await tester.tap(askAgentButton);
    await tester.pumpAndSettle();

    expect(openedIncidentReference, 'INC-TRACK-77');
  });

  testWidgets('tactical map focus opens dispatches for the focused scope', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? tappedClientId;
    String? tappedSiteId;
    String? tappedReference;

    await tester.pumpWidget(
      MaterialApp(
        home: TacticalPage(
          events: const [],
          initialScopeClientId: 'CLIENT-A',
          initialScopeSiteId: 'SITE-A',
          focusIncidentReference: 'INC-TRACK-88',
          onOpenFleetDispatchScope: (clientId, siteId, incidentReference) {
            tappedClientId = clientId;
            tappedSiteId = siteId;
            tappedReference = incidentReference;
          },
          fleetScopeHealth: const [
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-A',
              siteId: 'SITE-A',
              siteName: 'MS Vallee Residence',
              endpointLabel: '192.168.8.105',
              statusLabel: 'LIMITED WATCH',
              watchLabel: 'LIMITED',
              recentEvents: 0,
              lastSeenLabel: '21:14 UTC',
              freshnessLabel: 'Fresh',
              isStale: false,
              latestIncidentReference: 'INC-TRACK-88',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openDetailedWorkspaceIfVisible(tester);

    final openDispatchesButton = find.byKey(
      const ValueKey('tactical-map-focus-open-dispatches'),
    );
    await tester.ensureVisible(openDispatchesButton);
    await tester.tap(openDispatchesButton);
    await tester.pumpAndSettle();

    expect(tappedClientId, 'CLIENT-A');
    expect(tappedSiteId, 'SITE-A');
    expect(tappedReference, 'INC-TRACK-88');
  });

  testWidgets(
    'tactical page ingests agent returns into the focused track workspace',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? consumedIncidentReference;

      await tester.pumpWidget(
        MaterialApp(
          home: TacticalPage(
            events: const [],
            focusIncidentReference: 'INC-TRACK-77',
            agentReturnIncidentReference: 'INC-TRACK-77',
            onConsumeAgentReturnIncidentReference: (incidentReference) {
              consumedIncidentReference = incidentReference;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openDetailedWorkspaceIfVisible(tester);

      expect(
        find.byKey(const ValueKey('tactical-workspace-command-receipt')),
        findsOneWidget,
      );
      expect(find.text('AGENT RETURN'), findsOneWidget);
      expect(
        find.text('Returned from Agent for INC-TRACK-77.'),
        findsOneWidget,
      );
      expect(consumedIncidentReference, 'INC-TRACK-77');
    },
  );

  testWidgets(
    'tactical page only consumes the same agent return reference once across rebuilds',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final consumedIncidentReferences = <String>[];

      Widget buildHarness() {
        return MaterialApp(
          home: TacticalPage(
            events: const [],
            focusIncidentReference: 'INC-TRACK-77',
            agentReturnIncidentReference: 'INC-TRACK-77',
            onConsumeAgentReturnIncidentReference: (incidentReference) {
              consumedIncidentReferences.add(incidentReference);
            },
          ),
        );
      }

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      expect(consumedIncidentReferences, <String>['INC-TRACK-77']);
    },
  );

  testWidgets(
    'tactical page ingests evidence returns into the focused track workspace',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? consumedAuditId;

      await tester.pumpWidget(
        MaterialApp(
          home: TacticalPage(
            events: const [],
            focusIncidentReference: 'INC-DSP-2442',
            evidenceReturnReceipt: const TacticalEvidenceReturnReceipt(
              auditId: 'audit-track-2442',
              label: 'EVIDENCE RETURN',
              headline: 'Returned to Track for DSP-2442.',
              detail:
                  'The signed track handoff was verified in the ledger. Keep the same tactical view pinned and finish verification from here.',
              accent: Color(0xFF8FD1FF),
            ),
            onConsumeEvidenceReturnReceipt: (auditId) {
              consumedAuditId = auditId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openDetailedWorkspaceIfVisible(tester);

      expect(
        find.byKey(const ValueKey('tactical-workspace-command-receipt')),
        findsOneWidget,
      );
      expect(find.text('EVIDENCE RETURN'), findsOneWidget);
      expect(find.text('Returned to Track for DSP-2442.'), findsOneWidget);
      expect(consumedAuditId, 'audit-track-2442');
    },
  );

  testWidgets(
    'tactical page only consumes the same evidence return once across rebuilds',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final consumedAuditIds = <String>[];

      Widget buildHarness() {
        return MaterialApp(
          home: TacticalPage(
            events: const [],
            focusIncidentReference: 'INC-DSP-2442',
            evidenceReturnReceipt: const TacticalEvidenceReturnReceipt(
              auditId: 'audit-track-2442',
              label: 'EVIDENCE RETURN',
              headline: 'Returned to Track for DSP-2442.',
              detail:
                  'The signed track handoff was verified in the ledger. Keep the same tactical view pinned and finish verification from here.',
              accent: Color(0xFF8FD1FF),
            ),
            onConsumeEvidenceReturnReceipt: (auditId) {
              consumedAuditIds.add(auditId);
            },
          ),
        );
      }

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      expect(consumedAuditIds, <String>['audit-track-2442']);
    },
  );

  testWidgets(
    'tactical page renders desktop workspace shell and routes banner controls',
    (tester) async {
      tester.view.physicalSize = const Size(1680, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? tappedClientId;
      String? tappedSiteId;
      String? tappedReference;

      await tester.pumpWidget(
        MaterialApp(
          home: TacticalPage(
            events: const [],
            initialScopeClientId: 'CLIENT-A',
            initialScopeSiteId: 'SITE-A',
            onOpenFleetDispatchScope: (clientId, siteId, incidentReference) {
              tappedClientId = clientId;
              tappedSiteId = siteId;
              tappedReference = incidentReference;
            },
            fleetScopeHealth: const [
              VideoFleetScopeHealthView(
                clientId: 'CLIENT-A',
                siteId: 'SITE-A',
                siteName: 'MS Vallee Residence',
                endpointLabel: '192.168.8.105',
                statusLabel: 'LIMITED WATCH',
                watchLabel: 'LIMITED',
                recentEvents: 0,
                lastSeenLabel: '21:14 UTC',
                freshnessLabel: 'Fresh',
                isStale: false,
                latestIncidentReference: 'INT-VALLEE-1',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('track-live-map-board')),
        findsOneWidget,
      );
      expect(find.text('Live Tracking'), findsOneWidget);
      expect(find.byKey(const ValueKey('track-layer-sites')), findsOneWidget);
      expect(find.byKey(const ValueKey('track-layer-guards')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tactical-toggle-detailed-workspace')),
        findsOneWidget,
      );

      await openDetailedWorkspaceIfVisible(tester);

      expect(
        find.byKey(const ValueKey('tactical-workspace-status-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tactical-workspace-panel-rail')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tactical-workspace-panel-map')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tactical-workspace-panel-context')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tactical-workspace-command-receipt')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tactical-active-track-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tactical-verification-focus-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tactical-verification-queue-board')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tactical-lens-comparison-board')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('tactical-lens-comparison-review-matches')),
      );
      await tester.tap(
        find.byKey(const ValueKey('tactical-lens-comparison-review-matches')),
      );
      await tester.pumpAndSettle();

      expect(find.text('FR watchlist matches'), findsOneWidget);
      expect(
        find.text('Match queue foregrounded in verification rail.'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('tactical-verification-queue-assets')),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.byKey(const ValueKey('tactical-verification-queue-assets')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Snapshots ready'), findsOneWidget);
      expect(
        find.text('Asset queue foregrounded in verification rail.'),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('tactical-map-filter-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey('tactical-map-filter-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Filter: Responding'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('tactical-open-dispatches-button')),
      );
      await tester.pumpAndSettle();

      expect(tappedClientId, 'CLIENT-A');
      expect(tappedSiteId, 'SITE-A');
      expect(tappedReference, 'INT-VALLEE-1');
    },
  );

  testWidgets(
    'tactical page remount resets the track landing surface to overview',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: TacticalPage(key: ValueKey('tactical-remount-a'), events: []),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('track-live-map-board')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tactical-workspace-panel-map')),
        findsNothing,
      );

      await openDetailedWorkspaceIfVisible(tester);

      expect(
        find.byKey(const ValueKey('tactical-workspace-panel-map')),
        findsOneWidget,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TacticalPage(key: ValueKey('tactical-remount-b'), events: []),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('track-live-map-board')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tactical-workspace-panel-map')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('tactical-toggle-detailed-workspace')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tactical page keeps the modern workspace selected through parent rebuilds',
    (tester) async {
      tester.view.physicalSize = const Size(1680, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      StateSetter? hostSetState;
      var hostRevision = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              hostSetState = setState;
              return ColoredBox(
                color: hostRevision.isEven
                    ? const Color(0xFFF8FAFD)
                    : const Color(0xFFF2F6FB),
                child: const TacticalPage(events: []),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('track-live-map-board')),
        findsOneWidget,
      );

      await openDetailedWorkspaceIfVisible(tester);

      expect(
        find.byKey(const ValueKey('tactical-workspace-panel-map')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('track-live-map-board')), findsNothing);

      hostSetState!.call(() {
        hostRevision += 1;
      });
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('tactical-workspace-panel-map')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('track-live-map-board')), findsNothing);
    },
  );

  testWidgets('tactical page resets to track overview after a fresh remount', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1680, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    StateSetter? hostSetState;
    var showPage = true;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            hostSetState = setState;
            return showPage
                ? const TacticalPage(events: [])
                : const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('track-live-map-board')), findsOneWidget);

    await openDetailedWorkspaceIfVisible(tester);

    expect(
      find.byKey(const ValueKey('tactical-workspace-panel-map')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('track-live-map-board')), findsNothing);

    hostSetState!.call(() {
      showPage = false;
    });
    await tester.pumpAndSettle();

    hostSetState!.call(() {
      showPage = true;
    });
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('track-live-map-board')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tactical-workspace-panel-map')),
      findsNothing,
    );
  });

  testWidgets(
    'track overview keeps lower filters reachable on shorter desktop',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1366,
              height: 620,
              child: TrackOverviewBoard(onOpenDetailedWorkspace: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('track-live-map-board')),
        findsOneWidget,
      );
      final leftRail = find.byKey(const ValueKey('track-left-rail-scroll'));
      final leftRailScrollView = tester.widget<SingleChildScrollView>(leftRail);
      final leftRailController = leftRailScrollView.controller!;
      expect(leftRailController.offset, 0);

      await tester.drag(leftRail, const Offset(0, -260));
      await tester.pumpAndSettle();

      expect(leftRailController.offset, greaterThan(0));
      expect(find.text('Filter Clients'), findsOneWidget);
    },
  );

  testWidgets('track overview live clock ticks from the injected clock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var now = DateTime.parse('2026-04-07T08:15:09');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1500,
            height: 820,
            child: TrackOverviewBoard(
              onOpenDetailedWorkspace: () {},
              now: () => now,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('track-live-clock'))).data,
      '08:15:09',
    );

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('track-live-clock'))).data,
      '08:15:10',
    );
  });

  testWidgets('track overview search filters sites and updates layer counts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1500,
            height: 820,
            child: TrackOverviewBoard(onOpenDetailedWorkspace: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('track-search-field')),
      'alarm',
    );
    await tester.pumpAndSettle();

    expect(find.text('Sites (1)'), findsOneWidget);
    expect(find.text('Guards (1)'), findsOneWidget);
    expect(find.text('Incidents (1)'), findsOneWidget);
    expect(find.text('Cameras (1)'), findsOneWidget);
    expect(find.text('Morningside Office Park'), findsWidgets);
  });

  testWidgets('track overview clears stale focus when client filter changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1500,
            height: 820,
            child: TrackOverviewBoard(onOpenDetailedWorkspace: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Morningside Office Park'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(const ValueKey('track-client-filter-sandton-corp')),
    );
    await tester.tap(
      find.byKey(const ValueKey('track-client-filter-sandton-corp')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sandton Estate North'), findsWidgets);
    expect(find.text('Morningside Office Park'), findsNothing);
    expect(find.text('SE-01'), findsWidgets);
  });

  testWidgets('tactical page stays stable on landscape phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: TacticalPage(events: [])));
    await tester.pumpAndSettle();

    expect(find.text('TACTICAL MAP'), findsOneWidget);
    expect(find.text('VERIFICATION LENS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tactical page restores watch action focus from parent state', (
    tester,
  ) async {
    var showPage = true;
    VideoFleetWatchActionDrilldown? persistedDrilldown;
    late StateSetter hostSetState;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            hostSetState = setState;
            if (!showPage) {
              return const Scaffold(body: Center(child: Text('Away')));
            }
            return TacticalPage(
              events: const [],
              initialWatchActionDrilldown: persistedDrilldown,
              onWatchActionDrilldownChanged: (value) {
                hostSetState(() {
                  persistedDrilldown = value;
                });
              },
              fleetScopeHealth: const [
                VideoFleetScopeHealthView(
                  clientId: 'CLIENT-A',
                  siteId: 'SITE-A',
                  siteName: 'MS Vallee Residence',
                  endpointLabel: '192.168.8.105',
                  statusLabel: 'LIMITED WATCH',
                  watchLabel: 'LIMITED',
                  recentEvents: 0,
                  lastSeenLabel: '21:14 UTC',
                  freshnessLabel: 'Fresh',
                  isStale: false,
                  monitoringAvailabilityDetail:
                      'One remote camera feed is stale.',
                  latestIncidentReference: 'INT-VALLEE-1',
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Limited • 1'));
    await tester.tap(find.text('Limited • 1'));
    await tester.pumpAndSettle();
    expect(persistedDrilldown, VideoFleetWatchActionDrilldown.limited);
    expect(
      find.text('Focused watch action: Limited watch coverage'),
      findsOneWidget,
    );

    hostSetState(() {
      showPage = false;
    });
    await tester.pumpAndSettle();
    expect(find.text('Away'), findsOneWidget);

    hostSetState(() {
      showPage = true;
    });
    await tester.pumpAndSettle();

    expect(persistedDrilldown, VideoFleetWatchActionDrilldown.limited);
    expect(
      find.text('Focused watch action: Limited watch coverage'),
      findsOneWidget,
    );
    expect(
      find.text('ACTIONABLE (1) • Incident-backed limited-watch scopes'),
      findsOneWidget,
    );
  });

  testWidgets('tactical page shows CCTV telemetry counters from events', (
    tester,
  ) async {
    final now = _tacticalNowUtc();
    final events = <IntelligenceReceived>[
      IntelligenceReceived(
        eventId: 'intel-1',
        sequence: 1,
        version: 1,
        occurredAt: now.subtract(const Duration(minutes: 10)),
        intelligenceId: 'INT-1',
        provider: 'hikvision',
        sourceType: 'hardware',
        externalId: 'ext-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'fr_match watchlist',
        summary: 'fr: person matched breach pattern',
        riskScore: 91,
        snapshotUrl: 'https://edge.example.com/api/events/ext-1/snapshot.jpg',
        canonicalHash: 'hash-1',
      ),
      IntelligenceReceived(
        eventId: 'intel-2',
        sequence: 2,
        version: 1,
        occurredAt: now.subtract(const Duration(minutes: 8)),
        intelligenceId: 'INT-2',
        provider: 'hikvision',
        sourceType: 'hardware',
        externalId: 'ext-2',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'lpr_alert gate',
        summary: 'lpr: unauthorized vehicle',
        riskScore: 60,
        clipUrl: 'https://edge.example.com/api/events/ext-2/clip.mp4',
        canonicalHash: 'hash-2',
      ),
      IntelligenceReceived(
        eventId: 'intel-3',
        sequence: 3,
        version: 1,
        occurredAt: now.subtract(const Duration(minutes: 14)),
        intelligenceId: 'INT-3',
        provider: 'hikvision',
        sourceType: 'hardware',
        externalId: 'ext-3',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'intrusion perimeter',
        summary: 'line crossing detected',
        riskScore: 88,
        canonicalHash: 'hash-3',
      ),
      IntelligenceReceived(
        eventId: 'intel-4',
        sequence: 4,
        version: 1,
        occurredAt: now.subtract(const Duration(minutes: 44)),
        intelligenceId: 'INT-4',
        provider: 'hikvision',
        sourceType: 'hardware',
        externalId: 'ext-4',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'tamper camera',
        summary: 'tamper alert',
        riskScore: 82,
        canonicalHash: 'hash-4',
      ),
      IntelligenceReceived(
        eventId: 'intel-5',
        sequence: 5,
        version: 1,
        occurredAt: now.subtract(const Duration(minutes: 9)),
        intelligenceId: 'INT-5',
        provider: 'axis',
        sourceType: 'hardware',
        externalId: 'ext-5',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'intrusion side gate',
        summary: 'breach detected',
        riskScore: 89,
        canonicalHash: 'hash-5',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: TacticalPage(events: events, cctvProvider: 'hikvision'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CCTV Signal Counters (6h)'), findsOneWidget);
    expect(find.text('FR Matches • 1'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tactical-verification-signal-counters')),
        matching: find.text('Signals • 4'),
      ),
      findsOneWidget,
    );
    expect(find.text('LPR Hits • 1'), findsOneWidget);
    expect(find.text('Anomalies • 3'), findsWidgets);
    expect(find.text('Snapshots • 1'), findsOneWidget);
    expect(find.text('Clips • 1'), findsOneWidget);
    expect(find.text('Trend • UP'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tactical controls retarget the active track and queue', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TacticalPage(events: [])));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('tactical-active-track-card')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('tactical-marker-card-VEHICLE-R12')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('tactical-marker-card-VEHICLE-R12')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tactical-active-track-card')),
        matching: find.text('Vehicle R-12'),
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('tactical-map-focus-queue-assets')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('tactical-map-focus-queue-assets')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Snapshots ready'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('tactical-map-filter-button')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('tactical-map-filter-button')));
    await tester.pumpAndSettle();
    expect(find.text('Filter: Responding'), findsOneWidget);
  });

  testWidgets('tactical center track restores the preferred focused marker', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TacticalPage(events: [])));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tactical-active-track-card')),
        matching: find.text('INC-8829-QX'),
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('tactical-marker-card-VEHICLE-R12')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('tactical-marker-card-VEHICLE-R12')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tactical-active-track-card')),
        matching: find.text('Vehicle R-12'),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('tactical-map-focus-center-track')),
    );
    await tester.tap(
      find.byKey(const ValueKey('tactical-map-focus-center-track')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tactical-active-track-card')),
        matching: find.text('INC-8829-QX'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tactical page switches video counters label for DVR', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TacticalPage(
          events: [],
          videoOpsLabel: 'DVR',
          cctvRecentSignalSummary:
              'recent video intel 0 (6h) • intrusion 0 • line_crossing 0 • motion 0 • fr 0 • lpr 0',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DVR Signal Counters (6h)'), findsOneWidget);
    expect(
      find.textContaining('DVR Recent: recent video intel 0 (6h)'),
      findsOneWidget,
    );
  });

  testWidgets('tactical page counts DVR telemetry counters from events', (
    tester,
  ) async {
    final now = _tacticalNowUtc();
    final events = <IntelligenceReceived>[
      IntelligenceReceived(
        eventId: 'intel-dvr-1',
        sequence: 1,
        version: 1,
        occurredAt: now.subtract(const Duration(minutes: 10)),
        intelligenceId: 'INT-DVR-1',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'ext-dvr-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'lpr_alert bay',
        summary: 'lpr: unauthorized vehicle',
        riskScore: 74,
        clipUrl: 'https://dvr.example.com/api/events/ext-dvr-1/clip.mp4',
        canonicalHash: 'hash-dvr-1',
      ),
      IntelligenceReceived(
        eventId: 'intel-dvr-2',
        sequence: 2,
        version: 1,
        occurredAt: now.subtract(const Duration(minutes: 8)),
        intelligenceId: 'INT-DVR-2',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'ext-dvr-2',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'fr_match entry',
        summary: 'fr: person matched watchlist',
        riskScore: 88,
        snapshotUrl:
            'https://dvr.example.com/api/events/ext-dvr-2/snapshot.jpg',
        canonicalHash: 'hash-dvr-2',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: TacticalPage(
          events: events,
          videoOpsLabel: 'DVR',
          cctvProvider: 'hikvision-dvr',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DVR Signal Counters (6h)'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tactical-verification-signal-counters')),
        matching: find.text('Signals • 2'),
      ),
      findsOneWidget,
    );
    expect(find.text('FR Matches • 1'), findsOneWidget);
    expect(find.text('LPR Hits • 1'), findsOneWidget);
    expect(find.text('Snapshots • 1'), findsOneWidget);
    expect(find.text('Clips • 1'), findsOneWidget);
  });

  testWidgets('tactical page groups fleet scopes by incident context', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TacticalPage(
          events: [],
          fleetScopeHealth: [
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-A',
              siteId: 'SITE-A',
              siteName: 'MS Vallee Residence',
              endpointLabel: '192.168.8.105',
              statusLabel: 'LIVE',
              watchLabel: 'ACTIVE',
              recentEvents: 2,
              lastSeenLabel: '21:14 UTC',
              freshnessLabel: 'Fresh',
              isStale: false,
              watchWindowLabel: '18:00-06:00',
              watchWindowStateLabel: 'IN WINDOW',
              operatorOutcomeLabel: 'Resynced',
              alertCount: 1,
              escalationCount: 1,
              actionHistory: [
                '21:13 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
              ],
              latestEventLabel: 'Vehicle motion',
              latestIncidentReference: 'INT-VALLEE-1',
              latestEventTimeLabel: '21:14 UTC',
              latestCameraLabel: 'Camera 1',
              latestRiskScore: 84,
              latestFaceMatchId: 'PERSON-44',
              latestFaceConfidence: 91.2,
              latestPlateNumber: 'CA123456',
              latestPlateConfidence: 96.4,
              latestSceneReviewLabel:
                  'openai:gpt-4.1-mini • identity match concern • 21:14 UTC',
              latestSceneDecisionSummary:
                  'Escalated for urgent review because face match PERSON-44 was flagged and the event metadata suggested an unauthorized or watchlist context.',
            ),
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-B',
              siteId: 'SITE-B',
              siteName: 'Beta Watch',
              endpointLabel: '192.168.8.106',
              statusLabel: 'WATCH READY',
              watchLabel: 'SCHEDULED',
              recentEvents: 0,
              lastSeenLabel: 'idle',
              freshnessLabel: 'Idle',
              isStale: false,
              watchWindowLabel: '18:00-06:00',
              watchWindowStateLabel: 'IN WINDOW',
              repeatCount: 2,
              suppressedCount: 3,
              latestSceneDecisionLabel: 'Suppressed',
              latestSceneDecisionSummary:
                  'Suppressed because the activity remained below the client notification threshold.',
              watchActivationGapLabel: 'MISSED START',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('ACTIONABLE (1) • Incident-backed fleet scopes'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('video-fleet-panel-actionable-header')),
      findsOneWidget,
    );
    expect(
      find.text('WATCH-ONLY (1) • Watch scopes awaiting incident context'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('video-fleet-panel-watch-only-header')),
      findsOneWidget,
    );
    expect(find.text('Gap • 1'), findsOneWidget);
    expect(find.text('Cue • Resynced'), findsOneWidget);
    expect(find.text('Recovered 6h • 0'), findsWidgets);
    expect(find.text('Suppressed • 1'), findsOneWidget);
    expect(
      find.textContaining(
        'Recent action: 21:13 UTC • Camera 2 • Monitoring Alert',
      ),
      findsWidgets,
    );
    expect(
      find.textContaining('Identity policy: Flagged match'),
      findsOneWidget,
    );
    expect(find.text('Identity • Flagged'), findsOneWidget);
    expect(
      find.textContaining(
        'Identity match: Face PERSON-44 91.2% • Plate CA123456 96.4%',
      ),
      findsOneWidget,
    );
    expect(find.text('Latest: 21:14 UTC • Vehicle motion'), findsNothing);
    expect(find.text('Alerts • 1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tactical-fleet-summary-tile-alerts')),
      findsOneWidget,
    );
    expect(find.text('Repeat • 2'), findsOneWidget);
    expect(find.text('Escalated • 1'), findsOneWidget);
    expect(find.text('Filtered • 3'), findsOneWidget);
    expect(find.text('Flagged ID • 1'), findsOneWidget);
    expect(find.text('Allowed ID • 0'), findsOneWidget);
    expect(find.text('Window • 18:00-06:00'), findsNWidgets(2));
    expect(find.text('Phase • IN WINDOW'), findsNWidgets(2));
    expect(find.text('Gap • MISSED START'), findsOneWidget);
    expect(
      find.textContaining(
        'Scene action: Suppressed • Suppressed because the activity remained below the client notification threshold.',
      ),
      findsWidgets,
    );

    await tester.ensureVisible(find.text('Flagged ID • 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flagged ID • 1'));
    await tester.pumpAndSettle();
    expect(
      find.text('Focused identity policy: Flagged identity matches'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Showing fleet scopes where ONYX matched a flagged face or plate.',
      ),
      findsWidgets,
    );
    expect(
      find.text(
        'FLAGGED IDENTITY (1) • Incident-backed flagged-identity scopes',
      ),
      findsOneWidget,
    );
    expect(find.text('Beta Watch'), findsNothing);
  });

  testWidgets('tactical page shows suppressed scene review lane', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: TacticalPage(
          events: const [],
          videoOpsLabel: 'DVR',
          fleetScopeHealth: const [
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-B',
              siteId: 'SITE-B',
              siteName: 'Beta Watch',
              endpointLabel: '192.168.8.106',
              statusLabel: 'WATCH READY',
              watchLabel: 'SCHEDULED',
              recentEvents: 1,
              lastSeenLabel: '21:14 UTC',
              freshnessLabel: 'Recent',
              isStale: false,
              suppressedCount: 1,
              latestIncidentReference: 'INT-BETA-1',
              latestCameraLabel: 'Camera 2',
              latestSceneDecisionLabel: 'Suppressed',
              latestSceneDecisionSummary:
                  'Suppressed because the activity remained below the client notification threshold.',
            ),
          ],
          sceneReviewByIntelligenceId: {
            'INT-BETA-1': MonitoringSceneReviewRecord(
              intelligenceId: 'INT-BETA-1',
              sourceLabel: 'openai:gpt-4.1-mini',
              postureLabel: 'reviewed',
              decisionLabel: 'Suppressed',
              decisionSummary:
                  'Suppressed because the activity remained below the client notification threshold.',
              summary: 'Vehicle remained below escalation threshold.',
              reviewedAtUtc: _tacticalSuppressedReviewReviewedAtUtc(),
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.pixels, 0);
    final filteredChip = find.text('Filtered • 1');
    await tester.ensureVisible(filteredChip);
    await tester.tap(filteredChip);
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, greaterThan(0));
    expect(find.text('Focused watch action: Filtered reviews'), findsOneWidget);
    final textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(
      textWidgets.indexWhere(
        (widget) => widget.data == 'SUPPRESSED DVR REVIEWS',
      ),
      lessThan(
        textWidgets.indexWhere((widget) => widget.data == 'DVR FLEET HEALTH'),
      ),
    );
    expect(find.text('SUPPRESSED DVR REVIEWS'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tactical-suppressed-focus-card')),
      findsOneWidget,
    );
    expect(find.text('Internal • 1'), findsWidgets);
    expect(find.text('Beta Watch'), findsWidgets);
    expect(find.text('Action • Suppressed'), findsWidgets);
    expect(find.text('Camera • Camera 2'), findsWidgets);
    expect(find.text('Posture • reviewed'), findsWidgets);
    expect(
      find.textContaining(
        'Suppressed because the activity remained below the client notification threshold.',
      ),
      findsWidgets,
    );
    expect(
      find.text('Scene review: Vehicle remained below escalation threshold.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'tactical suppressed review focus routes tactical and dispatch handoff',
    (tester) async {
      tester.view.physicalSize = const Size(1680, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? tacticalClientId;
      String? tacticalSiteId;
      String? tacticalReference;
      String? dispatchClientId;
      String? dispatchSiteId;
      String? dispatchReference;

      await tester.pumpWidget(
        MaterialApp(
          home: TacticalPage(
            events: const [],
            videoOpsLabel: 'DVR',
            fleetScopeHealth: const [
              VideoFleetScopeHealthView(
                clientId: 'CLIENT-B',
                siteId: 'SITE-B',
                siteName: 'Beta Watch',
                endpointLabel: '192.168.8.106',
                statusLabel: 'WATCH READY',
                watchLabel: 'SCHEDULED',
                recentEvents: 1,
                lastSeenLabel: '21:14 UTC',
                freshnessLabel: 'Recent',
                isStale: false,
                suppressedCount: 1,
                latestIncidentReference: 'INT-BETA-1',
                latestCameraLabel: 'Camera 2',
                latestSceneDecisionLabel: 'Suppressed',
                latestSceneDecisionSummary:
                    'Suppressed because the activity remained below the client notification threshold.',
              ),
            ],
            sceneReviewByIntelligenceId: {
              'INT-BETA-1': MonitoringSceneReviewRecord(
                intelligenceId: 'INT-BETA-1',
                sourceLabel: 'openai:gpt-4.1-mini',
                postureLabel: 'reviewed',
                decisionLabel: 'Suppressed',
                decisionSummary:
                    'Suppressed because the activity remained below the client notification threshold.',
                summary: 'Vehicle remained below escalation threshold.',
                reviewedAtUtc: _tacticalSuppressedReviewReviewedAtUtc(),
              ),
            },
            onOpenFleetTacticalScope: (clientId, siteId, incidentReference) {
              tacticalClientId = clientId;
              tacticalSiteId = siteId;
              tacticalReference = incidentReference;
            },
            onOpenFleetDispatchScope: (clientId, siteId, incidentReference) {
              dispatchClientId = clientId;
              dispatchSiteId = siteId;
              dispatchReference = incidentReference;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openDetailedWorkspaceIfVisible(tester);

      expect(
        find.byKey(const ValueKey('tactical-suppressed-focus-card')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('tactical-suppressed-focus-open-tactical')),
      );
      await tester.tap(
        find.byKey(const ValueKey('tactical-suppressed-focus-open-tactical')),
      );
      await tester.pumpAndSettle();

      expect(tacticalClientId, 'CLIENT-B');
      expect(tacticalSiteId, 'SITE-B');
      expect(tacticalReference, 'INT-BETA-1');
      expect(
        find.text('Opened suppressed review in tactical lane.'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('tactical-suppressed-focus-open-dispatch')),
      );
      await tester.pumpAndSettle();

      expect(dispatchClientId, 'CLIENT-B');
      expect(dispatchSiteId, 'SITE-B');
      expect(dispatchReference, 'INT-BETA-1');
      expect(
        find.text('Opened suppressed review in dispatch lane.'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'tactical fleet actions pass incident reference and ignore watch-only scopes',
    (tester) async {
      String? tappedTacticalClientId;
      String? tappedTacticalSiteId;
      String? tappedTacticalReference;
      String? tappedDispatchClientId;
      String? tappedDispatchSiteId;
      String? tappedDispatchReference;
      String? recoveredClientId;
      String? recoveredSiteId;

      await tester.pumpWidget(
        MaterialApp(
          home: TacticalPage(
            events: const [],
            fleetScopeHealth: const [
              VideoFleetScopeHealthView(
                clientId: 'CLIENT-A',
                siteId: 'SITE-A',
                siteName: 'MS Vallee Residence',
                endpointLabel: '192.168.8.105',
                statusLabel: 'LIVE',
                watchLabel: 'ACTIVE',
                recentEvents: 2,
                lastSeenLabel: '21:14 UTC',
                freshnessLabel: 'Fresh',
                isStale: false,
                alertCount: 1,
                escalationCount: 1,
                actionHistory: [
                  '21:13 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
                  '21:09 UTC • Camera 4 • Monitoring Alert • Client alert sent because vehicle activity persisted near the entry gate.',
                ],
                latestEventLabel: 'Vehicle motion',
                latestIncidentReference: 'INT-VALLEE-1',
                latestEventTimeLabel: '21:14 UTC',
                latestCameraLabel: 'Camera 1',
                latestRiskScore: 84,
                latestFaceMatchId: 'PERSON-44',
                latestFaceConfidence: 91.2,
                latestPlateNumber: 'CA123456',
                latestPlateConfidence: 96.4,
                latestSceneReviewLabel:
                    'openai:gpt-4.1-mini • identity match concern • 21:14 UTC',
                latestSceneDecisionSummary:
                    'Escalated for urgent review because face match PERSON-44 was flagged and the event metadata suggested an unauthorized or watchlist context.',
              ),
              VideoFleetScopeHealthView(
                clientId: 'CLIENT-B',
                siteId: 'SITE-B',
                siteName: 'Beta Watch',
                endpointLabel: '192.168.8.106',
                statusLabel: 'WATCH READY',
                watchLabel: 'SCHEDULED',
                recentEvents: 0,
                lastSeenLabel: 'idle',
                freshnessLabel: 'Idle',
                isStale: false,
                watchWindowLabel: '18:00-06:00',
                watchWindowStateLabel: 'IN WINDOW',
                repeatCount: 2,
                suppressedCount: 3,
                lastRecoveryLabel: 'ADMIN • Resynced • 21:08 UTC',
                latestSceneDecisionLabel: 'Suppressed',
                latestSceneDecisionSummary:
                    'Suppressed because the activity remained below the client notification threshold.',
                watchActivationGapLabel: 'MISSED START',
              ),
            ],
            onOpenFleetTacticalScope: (clientId, siteId, incidentReference) {
              tappedTacticalClientId = clientId;
              tappedTacticalSiteId = siteId;
              tappedTacticalReference = incidentReference;
            },
            onOpenFleetDispatchScope: (clientId, siteId, incidentReference) {
              tappedDispatchClientId = clientId;
              tappedDispatchSiteId = siteId;
              tappedDispatchReference = incidentReference;
            },
            onRecoverFleetWatchScope: (clientId, siteId) {
              recoveredClientId = clientId;
              recoveredSiteId = siteId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recovered 6h • 1'), findsWidgets);
      expect(find.text('Suppressed • 1'), findsOneWidget);
      expect(find.text('Alerts • 1'), findsOneWidget);
      expect(find.text('Repeat • 2'), findsOneWidget);
      expect(find.text('Escalated • 1'), findsOneWidget);
      expect(find.text('Filtered • 3'), findsOneWidget);
      expect(
        find.text('Recovery • ADMIN • Resynced • 21:08 UTC'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Alerts • 1'));
      await tester.tap(find.text('Alerts • 1'));
      await tester.pumpAndSettle();
      expect(find.text('Focused watch action: Alert actions'), findsOneWidget);
      expect(
        find.text('Showing fleet scopes where ONYX sent a client alert.'),
        findsWidgets,
      );
      expect(
        find.text('ACTIONABLE (1) • Incident-backed alert scopes'),
        findsOneWidget,
      );
      expect(
        find.text(
          'WATCH-ONLY (0) • No watch-only alert scopes awaiting incident context',
        ),
        findsOneWidget,
      );
      expect(find.text('Beta Watch'), findsNothing);
      expect(find.text('MS Vallee Residence'), findsOneWidget);
      expect(
        find.textContaining(
          'Recent alert actions: 21:13 UTC • Camera 2 • Monitoring Alert',
        ),
        findsWidgets,
      );
      await tester.ensureVisible(
        find
            .textContaining(
              'Recent alert actions: 21:13 UTC • Camera 2 • Monitoring Alert',
            )
            .last,
      );
      await tester.tap(
        find
            .textContaining(
              'Recent alert actions: 21:13 UTC • Camera 2 • Monitoring Alert',
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(tappedTacticalClientId, 'CLIENT-A');
      expect(tappedTacticalSiteId, 'SITE-A');
      expect(tappedTacticalReference, 'INT-VALLEE-1');
      await tester.ensureVisible(find.text('Clear'));
      await tester.ensureVisible(find.text('Clear').last);
      await tester.tap(find.text('Clear').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Repeat • 2'));
      await tester.tap(find.text('Repeat • 2'));
      await tester.pumpAndSettle();
      expect(find.text('Focused watch action: Repeat updates'), findsOneWidget);
      expect(
        find.text(
          'Showing fleet scopes where ONYX stayed in monitoring with repeat updates.',
        ),
        findsWidgets,
      );
      expect(
        find.text(
          'ACTIONABLE (0) • No incident-backed repeat-update scopes right now',
        ),
        findsOneWidget,
      );
      expect(
        find.text('WATCH-ONLY (1) • Watch scopes with repeat-update actions'),
        findsOneWidget,
      );
      expect(find.text('MS Vallee Residence'), findsNothing);
      expect(find.text('Beta Watch'), findsOneWidget);
      await tester.ensureVisible(find.text('Clear').last);
      await tester.tap(find.text('Clear').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('MS Vallee Residence').first);
      await tester.tap(find.text('MS Vallee Residence').first);
      await tester.pumpAndSettle();
      expect(tappedTacticalClientId, 'CLIENT-A');
      expect(tappedTacticalSiteId, 'SITE-A');
      expect(tappedTacticalReference, 'INT-VALLEE-1');
      tappedTacticalClientId = null;
      tappedTacticalSiteId = null;
      tappedTacticalReference = null;
      await tester.ensureVisible(find.text('Flagged ID • 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flagged ID • 1'));
      await tester.pumpAndSettle();
      expect(
        find.text('Focused identity policy: Flagged identity matches'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find
            .textContaining(
              'Flagged identity: Face PERSON-44 91.2% • Plate CA123456 96.4%',
            )
            .last,
      );
      await tester.tap(
        find
            .textContaining(
              'Flagged identity: Face PERSON-44 91.2% • Plate CA123456 96.4%',
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(tappedTacticalClientId, 'CLIENT-A');
      expect(tappedTacticalSiteId, 'SITE-A');
      expect(tappedTacticalReference, 'INT-VALLEE-1');
      await tester.ensureVisible(find.text('Clear').last);
      await tester.tap(find.text('Clear').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Dispatch').first);
      await tester.tap(find.text('Dispatch').first);
      await tester.pumpAndSettle();
      expect(tappedDispatchClientId, 'CLIENT-A');
      expect(tappedDispatchSiteId, 'SITE-A');
      expect(tappedDispatchReference, 'INT-VALLEE-1');

      await tester.ensureVisible(find.text('Resync').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resync').first);
      await tester.pumpAndSettle();
      expect(recoveredClientId, 'CLIENT-B');
      expect(recoveredSiteId, 'SITE-B');

      tappedTacticalClientId = null;
      tappedTacticalSiteId = null;
      tappedTacticalReference = null;
      await tester.ensureVisible(find.text('Beta Watch').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beta Watch').first);
      await tester.pumpAndSettle();
      expect(tappedTacticalClientId, isNull);
      expect(tappedTacticalSiteId, isNull);
      expect(tappedTacticalReference, isNull);
    },
  );

  testWidgets('tactical fleet focus card routes lead lane actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1680, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    String? tappedTacticalClientId;
    String? tappedTacticalSiteId;
    String? tappedTacticalReference;
    String? tappedDispatchClientId;
    String? tappedDispatchSiteId;
    String? tappedDispatchReference;

    await tester.pumpWidget(
      MaterialApp(
        home: TacticalPage(
          events: const [],
          fleetScopeHealth: const [
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-A',
              siteId: 'SITE-A',
              siteName: 'MS Vallee Residence',
              endpointLabel: '192.168.8.105',
              statusLabel: 'LIVE',
              watchLabel: 'ACTIVE',
              recentEvents: 2,
              lastSeenLabel: '21:14 UTC',
              freshnessLabel: 'Fresh',
              isStale: false,
              alertCount: 1,
              latestIncidentReference: 'INT-VALLEE-1',
              latestEventLabel: 'Vehicle motion',
              latestEventTimeLabel: '21:14 UTC',
              latestCameraLabel: 'Camera 1',
              latestRiskScore: 84,
              actionHistory: [
                '21:13 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
              ],
            ),
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-B',
              siteId: 'SITE-B',
              siteName: 'Beta Watch',
              endpointLabel: '192.168.8.106',
              statusLabel: 'WATCH READY',
              watchLabel: 'SCHEDULED',
              recentEvents: 0,
              lastSeenLabel: 'idle',
              freshnessLabel: 'Idle',
              isStale: false,
            ),
          ],
          onOpenFleetTacticalScope: (clientId, siteId, incidentReference) {
            tappedTacticalClientId = clientId;
            tappedTacticalSiteId = siteId;
            tappedTacticalReference = incidentReference;
          },
          onOpenFleetDispatchScope: (clientId, siteId, incidentReference) {
            tappedDispatchClientId = clientId;
            tappedDispatchSiteId = siteId;
            tappedDispatchReference = incidentReference;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await openDetailedWorkspaceIfVisible(tester);

    expect(
      find.byKey(const ValueKey('tactical-fleet-focus-card')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('tactical-fleet-focus-open-drilldown')),
    );
    await tester.tap(
      find.byKey(const ValueKey('tactical-fleet-focus-open-drilldown')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Focused watch action: Alert actions'), findsOneWidget);
    expect(
      find.text('Alert actions foregrounded in fleet command rail.'),
      findsOneWidget,
    );

    final openTactical = find.byKey(
      const ValueKey('tactical-fleet-focus-open-tactical'),
    );
    await tester.ensureVisible(openTactical);
    await tester.tap(openTactical, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(tappedTacticalClientId, 'CLIENT-A');
    expect(tappedTacticalSiteId, 'SITE-A');
    expect(tappedTacticalReference, 'INT-VALLEE-1');
    expect(
      find.text('Opened lead fleet scope in tactical lane.'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('tactical-fleet-focus-open-dispatch')),
    );
    await tester.pumpAndSettle();

    expect(tappedDispatchClientId, 'CLIENT-A');
    expect(tappedDispatchSiteId, 'SITE-A');
    expect(tappedDispatchReference, 'INT-VALLEE-1');
    expect(
      find.text('Opened lead fleet scope in dispatch lane.'),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('tactical fleet summary command deck routes lane pivots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1680, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: TacticalPage(
          events: const [],
          fleetScopeHealth: const [
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-A',
              siteId: 'SITE-A',
              siteName: 'MS Vallee Residence',
              endpointLabel: '192.168.8.105',
              statusLabel: 'LIVE',
              watchLabel: 'ACTIVE',
              recentEvents: 2,
              lastSeenLabel: '21:14 UTC',
              freshnessLabel: 'Fresh',
              isStale: false,
              alertCount: 1,
              latestIncidentReference: 'INT-VALLEE-1',
              actionHistory: [
                '21:13 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
              ],
            ),
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-B',
              siteId: 'SITE-B',
              siteName: 'Beta Watch',
              endpointLabel: '192.168.8.106',
              statusLabel: 'WATCH READY',
              watchLabel: 'SCHEDULED',
              recentEvents: 0,
              lastSeenLabel: 'idle',
              freshnessLabel: 'Idle',
              isStale: false,
              repeatCount: 2,
              suppressedCount: 3,
              watchActivationGapLabel: 'MISSED START',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await openDetailedWorkspaceIfVisible(tester);

    expect(
      find.byKey(const ValueKey('tactical-fleet-summary-command')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('tactical-fleet-summary-primary')),
    );
    await tester.tap(
      find.byKey(const ValueKey('tactical-fleet-summary-primary')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Focused watch action: Alert actions'), findsOneWidget);
    expect(
      find.text('Alert actions foregrounded in fleet command rail.'),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('tactical-fleet-summary-secondary-repeat')),
    );
    await tester.tap(
      find.byKey(const ValueKey('tactical-fleet-summary-secondary-repeat')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Focused watch action: Repeat updates'), findsOneWidget);
    expect(
      find.text('Repeat updates foregrounded in fleet command rail.'),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('tactical-fleet-summary-clear')),
    );
    await tester.tap(
      find.byKey(const ValueKey('tactical-fleet-summary-clear')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cleared focused fleet watch action.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('tactical fleet scope cards expose command actions and receipts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1680, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    String? tappedTacticalClientId;
    String? tappedTacticalSiteId;
    String? tappedTacticalReference;
    String? tappedDispatchClientId;
    String? tappedDispatchSiteId;
    String? tappedDispatchReference;
    String? recoveredClientId;
    String? recoveredSiteId;

    await tester.pumpWidget(
      MaterialApp(
        home: TacticalPage(
          events: const [],
          fleetScopeHealth: const [
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-A',
              siteId: 'SITE-A',
              siteName: 'MS Vallee Residence',
              endpointLabel: '192.168.8.105',
              statusLabel: 'LIVE',
              watchLabel: 'ACTIVE',
              recentEvents: 2,
              lastSeenLabel: '21:14 UTC',
              freshnessLabel: 'Fresh',
              isStale: false,
              alertCount: 1,
              latestIncidentReference: 'INT-VALLEE-1',
              latestEventLabel: 'Vehicle motion',
              latestEventTimeLabel: '21:14 UTC',
              latestCameraLabel: 'Camera 1',
              latestRiskScore: 84,
              actionHistory: [
                '21:13 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
              ],
            ),
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-B',
              siteId: 'SITE-B',
              siteName: 'Beta Watch',
              endpointLabel: '192.168.8.106',
              statusLabel: 'WATCH READY',
              watchLabel: 'SCHEDULED',
              recentEvents: 0,
              lastSeenLabel: 'idle',
              freshnessLabel: 'Idle',
              isStale: false,
              repeatCount: 2,
              watchActivationGapLabel: 'MISSED START',
              lastRecoveryLabel: 'ADMIN • Resynced • 21:08 UTC',
            ),
          ],
          onOpenFleetTacticalScope: (clientId, siteId, incidentReference) {
            tappedTacticalClientId = clientId;
            tappedTacticalSiteId = siteId;
            tappedTacticalReference = incidentReference;
          },
          onOpenFleetDispatchScope: (clientId, siteId, incidentReference) {
            tappedDispatchClientId = clientId;
            tappedDispatchSiteId = siteId;
            tappedDispatchReference = incidentReference;
          },
          onRecoverFleetWatchScope: (clientId, siteId) {
            recoveredClientId = clientId;
            recoveredSiteId = siteId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await openDetailedWorkspaceIfVisible(tester);

    expect(
      find.byKey(const ValueKey('tactical-fleet-scope-command-SITE-A')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tactical-fleet-scope-identity-SITE-A')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tactical-fleet-scope-posture-SITE-A')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tactical-fleet-scope-context-SITE-A')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tactical-fleet-scope-latest-SITE-A')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tactical-fleet-scope-feed-SITE-A')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tactical-fleet-scope-actions-SITE-A')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tactical-fleet-scope-command-SITE-B')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('tactical-fleet-detail-SITE-A')),
    );
    await tester.tap(
      find.byKey(const ValueKey('tactical-fleet-detail-SITE-A')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Focused fleet scope detail for MS Vallee Residence.'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('tactical-fleet-tactical-SITE-A')),
    );
    await tester.pumpAndSettle();

    expect(tappedTacticalClientId, 'CLIENT-A');
    expect(tappedTacticalSiteId, 'SITE-A');
    expect(tappedTacticalReference, 'INT-VALLEE-1');
    expect(
      find.text('Opened MS Vallee Residence in tactical lane.'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('tactical-fleet-dispatch-SITE-A')),
    );
    await tester.pumpAndSettle();

    expect(tappedDispatchClientId, 'CLIENT-A');
    expect(tappedDispatchSiteId, 'SITE-A');
    expect(tappedDispatchReference, 'INT-VALLEE-1');
    expect(
      find.text('Opened MS Vallee Residence in dispatch lane.'),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('tactical-fleet-resync-SITE-B')),
    );
    await tester.tap(
      find.byKey(const ValueKey('tactical-fleet-resync-SITE-B')),
    );
    await tester.pumpAndSettle();

    expect(recoveredClientId, 'CLIENT-B');
    expect(recoveredSiteId, 'SITE-B');
    expect(
      find.text('Triggered coverage resync for Beta Watch.'),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('tactical page narrows fleet health to the scoped lane', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TacticalPage(
          events: const [],
          initialScopeClientId: 'CLIENT-B',
          initialScopeSiteId: 'SITE-B',
          fleetScopeHealth: const [
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-A',
              siteId: 'SITE-A',
              siteName: 'MS Vallee Residence',
              endpointLabel: '192.168.8.105',
              statusLabel: 'LIVE',
              watchLabel: 'ACTIVE',
              recentEvents: 2,
              lastSeenLabel: '21:14 UTC',
              freshnessLabel: 'Fresh',
              isStale: false,
              alertCount: 1,
              latestIncidentReference: 'INT-VALLEE-1',
            ),
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-B',
              siteId: 'SITE-B',
              siteName: 'Beta Watch',
              endpointLabel: '192.168.8.106',
              statusLabel: 'WATCH READY',
              watchLabel: 'SCHEDULED',
              recentEvents: 0,
              lastSeenLabel: 'idle',
              freshnessLabel: 'Idle',
              isStale: false,
              watchWindowLabel: '18:00-06:00',
              watchWindowStateLabel: 'IN WINDOW',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await openDetailedWorkspaceIfVisible(tester);

    expect(find.byKey(const ValueKey('tactical-scope-banner')), findsOneWidget);
    expect(find.text('Scope focus active'), findsOneWidget);
    expect(find.text('CLIENT-B/SITE-B'), findsWidgets);
    expect(find.text('Beta Watch'), findsOneWidget);
    expect(find.text('MS Vallee Residence'), findsNothing);
    expect(
      find.text('ACTIONABLE (0) • No incident-backed fleet scopes right now'),
      findsOneWidget,
    );
    expect(
      find.text('WATCH-ONLY (1) • Watch scopes awaiting incident context'),
      findsOneWidget,
    );
  });

  testWidgets('temporary identity summary opens incident-backed scope detail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1680, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    String? tappedTacticalClientId;
    String? tappedTacticalSiteId;
    String? tappedTacticalReference;
    String? extendedSite;
    String? expiredSite;

    await tester.pumpWidget(
      MaterialApp(
        home: TacticalPage(
          events: const [],
          fleetScopeHealth: const [
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-A',
              siteId: 'SITE-A',
              siteName: 'MS Vallee Residence',
              endpointLabel: '192.168.8.105',
              statusLabel: 'LIVE',
              watchLabel: 'ACTIVE',
              recentEvents: 1,
              lastSeenLabel: '21:14 UTC',
              freshnessLabel: 'Fresh',
              isStale: false,
              latestIncidentReference: 'INT-VALLEE-1',
              latestEventTimeLabel: '21:14 UTC',
              latestCameraLabel: 'Camera 1',
              latestFaceMatchId: 'VISITOR-01',
              latestFaceConfidence: 93.1,
              latestPlateNumber: 'CA777777',
              latestPlateConfidence: 97.4,
              latestSceneReviewLabel:
                  'openai:gpt-4.1-mini • known allowed identity • 21:14 UTC',
              latestSceneDecisionSummary:
                  'Suppressed because the matched identity has a one-time approval until 2026-03-15 18:00 UTC and the activity remained below the client notification threshold.',
            ),
          ],
          onOpenFleetTacticalScope: (clientId, siteId, incidentReference) {
            tappedTacticalClientId = clientId;
            tappedTacticalSiteId = siteId;
            tappedTacticalReference = incidentReference;
          },
          onExtendTemporaryIdentityApproval: (scope) async {
            extendedSite = scope.siteName;
            return 'Extended ${scope.siteName}.';
          },
          onExpireTemporaryIdentityApproval: (scope) async {
            expiredSite = scope.siteName;
            return 'Expired ${scope.siteName}.';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await openDetailedWorkspaceIfVisible(tester);

    expect(find.text('Temporary ID • 1'), findsOneWidget);
    expect(find.text('Identity • Temporary'), findsOneWidget);
    expect(
      find.textContaining(
        'Identity policy: Temporary approval until 2026-03-15 18:00 UTC',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Temporary ID • 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temporary ID • 1'));
    await tester.pumpAndSettle();
    expect(
      find.text('Focused identity policy: Temporary identity approvals'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Showing fleet scopes where ONYX matched a one-time approved face or plate. Each scope shows the approval expiry when available.',
      ),
      findsWidgets,
    );
    expect(find.text('Extend 2h'), findsOneWidget);
    expect(find.text('Expire now'), findsOneWidget);
    await tester.tap(find.text('Extend 2h'));
    await tester.pumpAndSettle();
    expect(extendedSite, 'MS Vallee Residence');
    expect(
      find.byKey(const ValueKey('tactical-workspace-command-receipt')),
      findsOneWidget,
    );
    expect(find.text('Extended MS Vallee Residence.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await tester.tap(find.text('Expire now'));
    await tester.pumpAndSettle();
    expect(find.text('Expire Temporary Approval?'), findsOneWidget);
    expect(
      find.textContaining(
        'This immediately removes the temporary identity approval for MS Vallee Residence.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(expiredSite, isNull);
    await tester.tap(find.text('Expire now'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Expire now'));
    await tester.pumpAndSettle();
    expect(expiredSite, 'MS Vallee Residence');
    expect(find.text('Expired MS Vallee Residence.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await tester.ensureVisible(
      find
          .textContaining(
            'Temporary identity until 2026-03-15 18:00 UTC: Face VISITOR-01 93.1% • Plate CA777777 97.4%',
          )
          .last,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .textContaining(
            'Temporary identity until 2026-03-15 18:00 UTC: Face VISITOR-01 93.1% • Plate CA777777 97.4%',
          )
          .last,
    );
    await tester.pumpAndSettle();
    expect(tappedTacticalClientId, 'CLIENT-A');
    expect(tappedTacticalSiteId, 'SITE-A');
    expect(tappedTacticalReference, 'INT-VALLEE-1');
  });

  testWidgets('tactical supports client-wide scope focus', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TacticalPage(
          events: const [],
          initialScopeClientId: 'CLIENT-A',
          initialScopeSiteId: '',
          fleetScopeHealth: const [
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-A',
              siteId: 'SITE-A',
              siteName: 'MS Vallee Residence',
              endpointLabel: '192.168.8.105',
              statusLabel: 'LIVE',
              watchLabel: 'ACTIVE',
              recentEvents: 2,
              lastSeenLabel: '21:14 UTC',
              freshnessLabel: 'Fresh',
              isStale: false,
            ),
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-A',
              siteId: 'SITE-B',
              siteName: 'MS Sandton Heights',
              endpointLabel: '192.168.8.106',
              statusLabel: 'WATCH READY',
              watchLabel: 'SCHEDULED',
              recentEvents: 0,
              lastSeenLabel: 'idle',
              freshnessLabel: 'Idle',
              isStale: false,
            ),
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-B',
              siteId: 'SITE-C',
              siteName: 'Beta Watch',
              endpointLabel: '192.168.8.107',
              statusLabel: 'LIVE',
              watchLabel: 'ACTIVE',
              recentEvents: 1,
              lastSeenLabel: '21:18 UTC',
              freshnessLabel: 'Fresh',
              isStale: false,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tactical-scope-banner')), findsOneWidget);
    expect(find.text('CLIENT-A/all sites'), findsOneWidget);
    expect(
      find.text('Tactical is focused on this client-wide DVR roll-up.'),
      findsOneWidget,
    );
    expect(find.text('MS Vallee Residence'), findsOneWidget);
    expect(find.text('MS Sandton Heights'), findsOneWidget);
    expect(find.text('Beta Watch'), findsNothing);
  });

  testWidgets(
    'tactical marks dispatch focus as scope-backed when lane matches',
    (tester) async {
      final now = _tacticalNowUtc();
      await tester.pumpWidget(
        MaterialApp(
          home: TacticalPage(
            focusIncidentReference: 'DSP-4',
            events: [
              DecisionCreated(
                eventId: 'decision-vallee',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 3)),
                dispatchId: 'DSP-4',
                clientId: 'CLIENT-A',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-A',
              ),
            ],
            fleetScopeHealth: const [
              VideoFleetScopeHealthView(
                clientId: 'CLIENT-A',
                siteId: 'SITE-A',
                siteName: 'MS Vallee Residence',
                endpointLabel: '192.168.8.105',
                statusLabel: 'LIVE',
                watchLabel: 'ACTIVE',
                recentEvents: 2,
                lastSeenLabel: '21:14 UTC',
                freshnessLabel: 'Fresh',
                isStale: false,
                latestIncidentReference: 'INT-VALLEE-1',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Focus • Scope-backed DSP-4'), findsOneWidget);
      expect(find.text('FOCUS SCOPE-BACKED • DSP-4'), findsOneWidget);
      expect(find.text('FOCUS SEEDED • DSP-4'), findsNothing);
    },
  );

  testWidgets(
    'tactical treats INC-prefixed dispatch focus as scope-backed when lane matches',
    (tester) async {
      final now = _tacticalNowUtc();
      await tester.pumpWidget(
        MaterialApp(
          home: TacticalPage(
            focusIncidentReference: 'INC-DSP-4',
            events: [
              DecisionCreated(
                eventId: 'decision-vallee-inc',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 3)),
                dispatchId: 'DSP-4',
                clientId: 'CLIENT-A',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-A',
              ),
            ],
            fleetScopeHealth: const [
              VideoFleetScopeHealthView(
                clientId: 'CLIENT-A',
                siteId: 'SITE-A',
                siteName: 'MS Vallee Residence',
                endpointLabel: '192.168.8.105',
                statusLabel: 'LIVE',
                watchLabel: 'ACTIVE',
                recentEvents: 2,
                lastSeenLabel: '21:14 UTC',
                freshnessLabel: 'Fresh',
                isStale: false,
                latestIncidentReference: 'INT-VALLEE-1',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FOCUS SCOPE-BACKED • INC-DSP-4'), findsOneWidget);
      expect(find.text('FOCUS SEEDED • INC-DSP-4'), findsNothing);
    },
  );

  testWidgets('allowlisted identity summary opens incident-backed scope detail', (
    tester,
  ) async {
    String? tappedTacticalClientId;
    String? tappedTacticalSiteId;
    String? tappedTacticalReference;

    await tester.pumpWidget(
      MaterialApp(
        home: TacticalPage(
          events: const [],
          fleetScopeHealth: const [
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-A',
              siteId: 'SITE-A',
              siteName: 'MS Vallee Residence',
              endpointLabel: '192.168.8.105',
              statusLabel: 'LIVE',
              watchLabel: 'ACTIVE',
              recentEvents: 1,
              lastSeenLabel: '21:14 UTC',
              freshnessLabel: 'Fresh',
              isStale: false,
              latestIncidentReference: 'INT-VALLEE-1',
              latestEventTimeLabel: '21:14 UTC',
              latestCameraLabel: 'Camera 1',
              latestFaceMatchId: 'RESIDENT-01',
              latestFaceConfidence: 94.1,
              latestPlateNumber: 'CA111111',
              latestPlateConfidence: 98.0,
              latestSceneReviewLabel:
                  'openai:gpt-4.1-mini • known allowed identity • 21:14 UTC',
              latestSceneDecisionSummary:
                  'Suppressed because RESIDENT-01 and plate CA111111 are allowlisted for this site.',
            ),
          ],
          onOpenFleetTacticalScope: (clientId, siteId, incidentReference) {
            tappedTacticalClientId = clientId;
            tappedTacticalSiteId = siteId;
            tappedTacticalReference = incidentReference;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Allowed ID • 1'), findsOneWidget);
    expect(find.text('Identity • Allowlisted'), findsOneWidget);
    await tester.ensureVisible(find.text('Allowed ID • 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allowed ID • 1'));
    await tester.pumpAndSettle();
    expect(
      find.text('Focused identity policy: Allowlisted identity matches'),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find
          .textContaining(
            'Allowlisted identity: Face RESIDENT-01 94.1% • Plate CA111111 98.0%',
          )
          .last,
    );
    await tester.tap(
      find
          .textContaining(
            'Allowlisted identity: Face RESIDENT-01 94.1% • Plate CA111111 98.0%',
          )
          .last,
    );
    await tester.pumpAndSettle();
    expect(tappedTacticalClientId, 'CLIENT-A');
    expect(tappedTacticalSiteId, 'SITE-A');
    expect(tappedTacticalReference, 'INT-VALLEE-1');
  });
}
