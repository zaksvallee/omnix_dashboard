import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/store/in_memory_event_store.dart';
import 'package:omnix_dashboard/ui/client_app_page.dart';
import 'package:omnix_dashboard/ui/client_intelligence_reports_page.dart';
import 'package:omnix_dashboard/ui/clients_page.dart';
import 'package:omnix_dashboard/ui/events_review_page.dart';
import 'package:omnix_dashboard/ui/live_operations_page.dart';
import 'package:omnix_dashboard/ui/sites_command_page.dart';
import 'package:omnix_dashboard/ui/sovereign_ledger_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('critical CTAs are tappable in default state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final events = <DispatchEvent>[
      DecisionCreated(
        eventId: 'DEC-CTA-1',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 11, 10, 0),
        dispatchId: 'DISP-CTA-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
      IntelligenceReceived(
        eventId: 'INT-CTA-1',
        sequence: 2,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 11, 10, 5),
        intelligenceId: 'INTEL-CTA-1',
        provider: 'newsapi.org',
        sourceType: 'news',
        externalId: 'news-cta-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'CTA smoke advisory',
        summary: 'Smoke test advisory payload.',
        riskScore: 60,
        canonicalHash: 'hash-cta-1',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SitesCommandPage(
          events: events,
          onAddSite: () {},
          onOpenMapForSite: (siteId, siteName) {},
          onOpenSiteSettings: (siteId, siteName) {},
          onOpenGuardRoster: (siteId, siteName) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final addSite = tester.widget<InkWell>(
      find.widgetWithText(InkWell, 'ADD SITE'),
    );
    expect(addSite.onTap, isNotNull);

    await tester.pumpWidget(
      MaterialApp(home: EventsReviewPage(events: events)),
    );
    await tester.pumpAndSettle();
    final viewLedger = tester.widget<InkWell>(
      find.byKey(const ValueKey('events-view-ledger-action')),
    );
    final exportEvent = tester.widget<InkWell>(
      find.byKey(const ValueKey('events-export-data-action')),
    );
    expect(viewLedger.onTap, isNotNull);
    expect(exportEvent.onTap, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(clientId: 'CLIENT-001', events: events),
      ),
    );
    await tester.pumpAndSettle();
    final verifyChain = tester.widget<InkWell>(
      find.widgetWithText(InkWell, 'VERIFY CHAIN'),
    );
    final exportLedger = tester.widget<InkWell>(
      find.widgetWithText(InkWell, 'EXPORT LEDGER'),
    );
    expect(verifyChain.onTap, isNotNull);
    expect(exportLedger.onTap, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        home: ClientsPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: events,
          onRetryPushSync: () async {},
          onOpenClientRoomForScope: (room, clientId, siteId) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final retryPushSync = tester.widget<InkWell>(
      find.widgetWithText(InkWell, 'Retry Push Sync'),
    );
    final residentsRoom = tester.widget<InkWell>(
      find.widgetWithText(InkWell, 'Residents'),
    );
    expect(retryPushSync.onTap, isNotNull);
    expect(residentsRoom.onTap, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: InMemoryEventStore(),
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final exportAllReports = tester.widget<TextButton>(
      find.byKey(const ValueKey('reports-export-all-button')),
    );
    final previewSample = tester.widget<TextButton>(
      find.byKey(const ValueKey('report-receipt-preview-RPT-2024-03-10-001')),
    );
    expect(exportAllReports.onPressed, isNotNull);
    expect(previewSample.onPressed, isNotNull);

    await tester.pumpWidget(
      const MaterialApp(home: LiveOperationsPage(events: [])),
    );
    await tester.pumpAndSettle();
    final pauseAction = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Pause').first,
    );
    expect(pauseAction.onPressed, isNotNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: <DispatchEvent>[],
          initialHasTouchedIncidentExpansionByRole: {'client': true},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final noIncidentAction = tester.widget<TextButton>(
      find.byKey(const ValueKey('incident-feed-open-first-action')),
    );
    expect(noIncidentAction.onPressed, isNull);
  });
}
