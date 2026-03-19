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
import 'package:omnix_dashboard/ui/sites_command_page.dart';
import 'package:omnix_dashboard/ui/sovereign_ledger_page.dart';

void main() {
  final sampleEvents = <DispatchEvent>[
    DecisionCreated(
      eventId: 'DEC-1',
      sequence: 1,
      version: 1,
      occurredAt: DateTime.utc(2026, 3, 10, 14, 53, 24),
      dispatchId: 'DSP-4',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    ),
    ResponseArrived(
      eventId: 'ARR-1',
      sequence: 2,
      version: 1,
      occurredAt: DateTime.utc(2026, 3, 10, 15, 1, 24),
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
      occurredAt: DateTime.utc(2026, 3, 10, 15, 30, 24),
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
    await tester.scrollUntilVisible(
      find.text('Push Delivery Queue'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Push Delivery Queue'), findsOneWidget);
  });

  testWidgets('sites controller page renders grid workspace', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SitesCommandPage(events: sampleEvents)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sites & Deployment'), findsOneWidget);
    expect(find.textContaining('SITE OPERATIONS WORKSPACE'), findsOneWidget);
  });

  testWidgets('events controller page renders timeline and selected detail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: EventsReviewPage(events: sampleEvents)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Events & Forensic Timeline'), findsOneWidget);
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
          occurredAt: DateTime.utc(2026, 3, 10, 15, 32, 24),
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

  testWidgets('sovereign ledger page renders chain controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(clientId: 'CLIENT-001', events: sampleEvents),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sovereign Ledger'), findsOneWidget);
    expect(find.text('Chain Controls'), findsOneWidget);
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
    expect(find.text('Deterministic Generation'), findsOneWidget);
  });
}
