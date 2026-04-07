import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/response_arrived.dart';
import 'package:omnix_dashboard/domain/store/in_memory_event_store.dart';
import 'package:omnix_dashboard/ui/client_intelligence_reports_page.dart';
import 'package:omnix_dashboard/ui/clients_page.dart';
import 'package:omnix_dashboard/ui/events_review_page.dart';
import 'package:omnix_dashboard/ui/risk_intelligence_page.dart';
import 'package:omnix_dashboard/ui/sites_command_page.dart';
import 'package:omnix_dashboard/ui/sovereign_ledger_page.dart';
import 'package:omnix_dashboard/ui/vip_protection_page.dart';

DateTime _controllerRedesignOccurredAtUtc(int hour, int minute) =>
    DateTime.utc(2026, 3, 10, hour, minute, 24);

void main() {
  final sampleEvents = <DispatchEvent>[
    DecisionCreated(
      eventId: 'DEC-1',
      sequence: 1,
      version: 1,
      occurredAt: _controllerRedesignOccurredAtUtc(14, 53),
      dispatchId: 'DSP-4',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    ),
    ResponseArrived(
      eventId: 'ARR-1',
      sequence: 2,
      version: 1,
      occurredAt: _controllerRedesignOccurredAtUtc(15, 1),
      dispatchId: 'DSP-4',
      guardId: 'GUARD-1',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    ),
    IntelligenceReceived(
      eventId: 'INT-1',
      sequence: 3,
      version: 1,
      occurredAt: _controllerRedesignOccurredAtUtc(15, 30),
      intelligenceId: 'INTEL-1',
      provider: 'newsapi.org',
      sourceType: 'news',
      externalId: 'news-1',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
      headline: 'Advisory issued',
      summary: 'Resident advisory pushed.',
      riskScore: 72,
      canonicalHash: 'hash-int-1',
    ),
  ];

  testWidgets('clients controller page renders redesigned title', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClientsPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: sampleEvents,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Client Communications'), findsOneWidget);
    expect(find.text('3 PENDING MESSAGES'), findsOneWidget);
  });

  testWidgets('sites controller page renders grid workspace', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SitesCommandPage(events: sampleEvents)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sites & Deployment'), findsOneWidget);
    expect(find.textContaining('SITE OPERATIONS WORKSPACE'), findsOneWidget);
  });

  testWidgets('vip protection page renders empty state and schedule', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: VipProtectionPage()));
    await tester.pumpAndSettle();

    expect(find.text('VIP Protection'), findsOneWidget);
    expect(find.text('WAR ROOM'), findsOneWidget);
    expect(find.text('No Live VIP Run'), findsOneWidget);
    expect(find.text('NEXT MOVES'), findsOneWidget);
    expect(find.text('CEO Airport Escort'), findsOneWidget);
  });

  testWidgets('vip protection page opens create-detail dialog by default', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: VipProtectionPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('vip-create-detail-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('vip-create-detail-dialog')),
      findsOneWidget,
    );
    expect(find.text('Package Desk'), findsOneWidget);
  });

  testWidgets('vip protection page delegates create-detail callback', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(home: VipProtectionPage(onCreateDetail: () => tapped = true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('vip-create-detail-button')));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
    expect(
      find.byKey(const ValueKey('vip-create-detail-dialog')),
      findsNothing,
    );
  });

  testWidgets('risk intelligence page renders area lanes and feed', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RiskIntelligencePage()));
    await tester.pumpAndSettle();

    expect(find.text('Risk Intelligence'), findsOneWidget);
    expect(find.text('WAR ROOM'), findsOneWidget);
    expect(find.text('WATCH HOTSPOTS'), findsOneWidget);
    expect(find.text('AI OPINION FEED'), findsOneWidget);
    expect(find.text('Sandton'), findsOneWidget);
  });

  testWidgets('risk intelligence page opens manual-intel dialog by default', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RiskIntelligencePage()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('intel-add-manual-button')));
    await tester.tap(find.byKey(const ValueKey('intel-add-manual-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('intel-add-manual-dialog')),
      findsOneWidget,
    );
    expect(find.text('Intel Intake'), findsOneWidget);
  });

  testWidgets(
    'risk intelligence page opens area and detail dialogs by default',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RiskIntelligencePage()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('intel-area-waterfall-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey('intel-area-waterfall-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('intel-area-waterfall-dialog')),
        findsOneWidget,
      );

      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('intel-detail-news24-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey('intel-detail-news24-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('intel-detail-news24-dialog')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'risk intelligence page delegates manual, area, and detail callbacks',
    (tester) async {
      var manualTapped = false;
      RiskIntelAreaSummary? selectedArea;
      RiskIntelFeedItem? selectedItem;

      await tester.pumpWidget(
        MaterialApp(
          home: RiskIntelligencePage(
            onAddManualIntel: () => manualTapped = true,
            onViewAreaIntel: (area) => selectedArea = area,
            onViewRecentIntel: (item) => selectedItem = item,
            areas: const [
              RiskIntelAreaSummary(
                title: 'Sandton',
                level: 'MEDIUM',
                accent: Color(0xFFFFC533),
                border: Color(0xFF70511F),
                signalCount: 1,
                eventIds: ['evt-1'],
                selectedEventId: 'evt-1',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('intel-add-manual-button')));
      await tester.tap(find.byKey(const ValueKey('intel-add-manual-button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('intel-area-sandton-button')));
      await tester.tap(find.byKey(const ValueKey('intel-area-sandton-button')));
      await tester.pumpAndSettle();
      final detailButton = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('intel-detail-twitter-button')),
      );
      detailButton.onPressed!.call();
      await tester.pumpAndSettle();

      expect(manualTapped, isTrue);
      expect(selectedArea?.title, 'Sandton');
      expect(selectedItem?.sourceLabel, 'TWITTER');
      expect(
        find.byKey(const ValueKey('intel-add-manual-dialog')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('intel-area-sandton-dialog')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('intel-detail-twitter-dialog')),
        findsNothing,
      );
    },
  );

  testWidgets('events controller page renders war-room timeline and selected detail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: EventsReviewPage(events: sampleEvents)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Events War Room'), findsOneWidget);
    expect(find.text('Selected Event'), findsOneWidget);
  });

  testWidgets('events controller page applies initial intel source filter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: EventsReviewPage(
          events: sampleEvents,
          initialSourceFilter: 'news',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selectedIdText = tester.widget<Text>(
      find.byKey(const ValueKey('events-selected-event-id')),
    );
    expect(selectedIdText.data, 'INT-1');
    expect(find.byKey(const ValueKey('events-detail-DEC-1')), findsNothing);
  });

  testWidgets(
    'events controller page applies initial intel source and provider filters',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final providerFocusedEvents = <DispatchEvent>[
        ...sampleEvents,
        IntelligenceReceived(
          eventId: 'INT-2',
          sequence: 4,
          version: 1,
          occurredAt: _controllerRedesignOccurredAtUtc(15, 32),
          intelligenceId: 'INTEL-2',
          provider: 'community-feed',
          sourceType: 'news',
          externalId: 'community-1',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          headline: 'Community update posted',
          summary: 'Local community bulletin published.',
          riskScore: 35,
          canonicalHash: 'hash-int-2',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: EventsReviewPage(
            events: providerFocusedEvents,
            initialSourceFilter: 'news',
            initialProviderFilter: 'newsapi.org',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final selectedIdText = tester.widget<Text>(
        find.byKey(const ValueKey('events-selected-event-id')),
      );
      expect(selectedIdText.data, 'INT-1');
      expect(find.text('Community update posted'), findsNothing);
      expect(find.byKey(const ValueKey('events-detail-DEC-1')), findsNothing);
    },
  );

  testWidgets('events controller page applies initial selected event id', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventsReviewPage(
          events: sampleEvents,
          initialSelectedEventId: 'DEC-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selectedIdText = tester.widget<Text>(
      find.byKey(const ValueKey('events-selected-event-id')),
    );
    expect(selectedIdText.data, 'DEC-1');
  });

  testWidgets('sovereign ledger page renders sovereign ledger workspace', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(clientId: 'CLIENT-001', events: sampleEvents),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sovereign Ledger'), findsOneWidget);
    expect(find.text('TRACE RAIL'), findsWidgets);
    expect(find.text('YOU ARE HERE'), findsOneWidget);
  });

  testWidgets('client intelligence reports page renders generation lanes', (
    tester,
  ) async {
    final store = InMemoryEventStore();
    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reports & Documentation'), findsOneWidget);
    expect(
      find.text('Pick the right receipt, preview it, and move it out cleanly.'),
      findsOneWidget,
    );
  });
}
