import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/guard_checked_in.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/response_arrived.dart';
import 'package:omnix_dashboard/ui/events_page.dart';

import '../fixtures/report_test_receipt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('events page stays stable on phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: EventsPage(events: <DispatchEvent>[])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Events & Forensic Timeline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('events page stays stable on landscape phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: EventsPage(events: <DispatchEvent>[])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Events & Forensic Timeline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('events page shows empty timeline state when no events exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: EventsPage(events: <DispatchEvent>[])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Events & Forensic Timeline'), findsOneWidget);
    expect(find.byKey(const ValueKey('events-overview-grid')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('events-overview-selected-card')),
      findsOneWidget,
    );
    expect(find.text('No case pinned'), findsOneWidget);
  });

  testWidgets('events page empty state recovers timeline and lane focus', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final olderEventTime = DateTime.now().toUtc().subtract(
      const Duration(days: 2),
    );
    final events = <DispatchEvent>[
      DecisionCreated(
        eventId: 'DEC-EMPTY-1',
        sequence: 1,
        version: 1,
        occurredAt: olderEventTime,
        dispatchId: 'DSP-EMPTY-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1440, 1200)),
          child: EventsPage(events: events),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('events-empty-state')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('events-empty-detail-recovery')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('events-overview-selected-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('events-overview-selected-open-all-time')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('events-overview-selected-open-all-time')),
    );
    await tester.tap(
      find.byKey(const ValueKey('events-overview-selected-open-all-time')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Event ID DEC-EMPTY-1'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('events-lane-filter-intelligence')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('events-empty-state')), findsOneWidget);
    expect(
      find.textContaining('still available outside this lane'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('events-empty-detail-open-all')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Event ID DEC-EMPTY-1'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('events page ledger action opens helper dialog', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: EventsPage(events: <DispatchEvent>[])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('events-view-ledger-button')));
    await tester.pumpAndSettle();

    expect(find.text('Ledger Link Ready'), findsOneWidget);
    expect(
      find.textContaining('provenance, evidence continuity'),
      findsOneWidget,
    );
  });

  testWidgets('events page renders forensic timeline rows', (tester) async {
    final recentBase = DateTime.now().toUtc().subtract(
      const Duration(hours: 2),
    );
    final events = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'INT-1',
        sequence: 1,
        version: 1,
        occurredAt: recentBase,
        intelligenceId: 'INTEL-001',
        provider: 'newsapi.org',
        sourceType: 'news',
        externalId: 'news-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Armed robbery alert',
        summary: 'Suspects reported near Sandton gate perimeter.',
        riskScore: 81,
        canonicalHash: 'hash-int-1',
      ),
      DecisionCreated(
        eventId: 'DEC-1',
        sequence: 2,
        version: 1,
        occurredAt: recentBase.add(const Duration(minutes: 5)),
        dispatchId: 'DSP-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
      GuardCheckedIn(
        eventId: 'CHK-1',
        sequence: 3,
        version: 1,
        occurredAt: recentBase.add(const Duration(minutes: 7)),
        guardId: 'GUARD-001',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
      ResponseArrived(
        eventId: 'ARR-1',
        sequence: 4,
        version: 1,
        occurredAt: recentBase.add(const Duration(minutes: 9)),
        dispatchId: 'DSP-1',
        guardId: 'GUARD-001',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
    ];

    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1440, 1200)),
          child: EventsPage(events: events),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Event Review'), findsOneWidget);
    final rowLabel = find.text('Event ID ARR-1');
    await tester.scrollUntilVisible(
      rowLabel,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    final rowCard = find.ancestor(of: rowLabel, matching: find.byType(InkWell));
    expect(rowCard, findsWidgets);
    expect(rowLabel, findsOneWidget);
  });

  testWidgets('events page switches review lanes and linked focus', (
    tester,
  ) async {
    final recentBase = DateTime.now().toUtc().subtract(
      const Duration(hours: 2),
    );
    final events = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'INT-1',
        sequence: 1,
        version: 1,
        occurredAt: recentBase,
        intelligenceId: 'INTEL-001',
        provider: 'newsapi.org',
        sourceType: 'news',
        externalId: 'news-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Armed robbery alert',
        summary: 'Suspects reported near Sandton gate perimeter.',
        riskScore: 81,
        canonicalHash: 'hash-int-1',
      ),
      DecisionCreated(
        eventId: 'DEC-1',
        sequence: 2,
        version: 1,
        occurredAt: recentBase.add(const Duration(minutes: 5)),
        dispatchId: 'DSP-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
      GuardCheckedIn(
        eventId: 'CHK-1',
        sequence: 3,
        version: 1,
        occurredAt: recentBase.add(const Duration(minutes: 7)),
        guardId: 'GUARD-001',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
      ResponseArrived(
        eventId: 'ARR-1',
        sequence: 4,
        version: 1,
        occurredAt: recentBase.add(const Duration(minutes: 9)),
        dispatchId: 'DSP-1',
        guardId: 'GUARD-001',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
    ];

    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1440, 1200)),
          child: EventsPage(events: events),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('events-workspace-status-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('events-overview-selected-card')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('events-lane-filter-intelligence')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('events-lane-card-INT-1')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('events-lane-card-ARR-1')), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('events-overview-selected-open-evidence')),
    );
    await tester.tap(
      find.byKey(const ValueKey('events-overview-selected-open-evidence')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('events-workspace-panel-evidence')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('events-view-ledger-button')));
    await tester.pumpAndSettle();

    expect(find.text('Ledger Link Ready'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    final focusRelatedButton = find.byKey(
      const ValueKey('events-context-focus-related-button'),
    );
    await tester.ensureVisible(focusRelatedButton);
    await tester.pumpAndSettle();
    await tester.tap(focusRelatedButton);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('events-lane-card-ARR-1')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('events-lane-card-INT-1')), findsNothing);
    expect(
      find.byKey(const ValueKey('events-workspace-panel-chain')),
      findsOneWidget,
    );
  });

  testWidgets('events page context rail recovers chain focus in place', (
    tester,
  ) async {
    final recentBase = DateTime.now().toUtc().subtract(
      const Duration(hours: 2),
    );
    final events = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'INT-SOLO-1',
        sequence: 1,
        version: 1,
        occurredAt: recentBase,
        intelligenceId: 'INTEL-SOLO-001',
        provider: 'newsapi.org',
        sourceType: 'news',
        externalId: 'news-solo-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Single forensic lead',
        summary: 'One isolated lead remains on the board.',
        riskScore: 77,
        canonicalHash: 'hash-int-solo-1',
      ),
    ];

    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1440, 1200)),
          child: EventsPage(events: events),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('events-context-chain-recovery')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('events-context-chain-review-evidence')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('events-context-chain-review-evidence')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('events-workspace-panel-evidence')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('events-context-chain-open-ledger')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ledger Link Ready'), findsOneWidget);
    expect(
      find.textContaining('provenance, evidence continuity'),
      findsOneWidget,
    );
  });

  testWidgets('events page opens mobile detail drawer without overflow', (
    tester,
  ) async {
    final occurredAt = DateTime.now().toUtc().subtract(
      const Duration(hours: 1),
    );
    final events = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'INT-1',
        sequence: 1,
        version: 1,
        occurredAt: occurredAt,
        intelligenceId: 'INTEL-001',
        provider: 'newsapi.org',
        sourceType: 'news',
        externalId: 'news-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Armed robbery alert',
        summary: 'Suspects reported near Sandton gate perimeter.',
        riskScore: 81,
        canonicalHash: 'hash-int-1',
      ),
    ];

    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(home: EventsPage(events: events)));
    await tester.pumpAndSettle();

    await tester.dragFrom(const Offset(389, 200), const Offset(-280, 0));
    await tester.pumpAndSettle();

    expect(find.text('Selected Event'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'events page lists tracked report receipts in the forensic timeline',
    (tester) async {
      final reportEvent = buildTestReportGenerated(
        eventId: 'RPT-EVT-1',
        occurredAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        month: '2026-03',
        reportSchemaVersion: 3,
        primaryBrandLabel: 'VISION Tactical',
        endorsementLine: 'Powered by ONYX',
        brandingSourceLabel: 'PARTNER • Alpha',
        brandingUsesOverride: true,
        investigationContextKey: 'governance_branding_drift',
        includeAiDecisionLog: false,
        includeGuardMetrics: false,
      );

      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(home: EventsPage(events: <DispatchEvent>[reportEvent])),
      );
      await tester.pumpAndSettle();

      final rowLabel = find.text('Event ID RPT-EVT-1');
      await tester.scrollUntilVisible(
        rowLabel,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(rowLabel, findsOneWidget);
    },
  );

  testWidgets(
    'events page lists legacy report receipts in the forensic timeline',
    (tester) async {
      final reportEvent = buildTestReportGenerated(
        eventId: 'RPT-EVT-LEGACY-1',
        occurredAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        month: '2026-03',
        reportSchemaVersion: 1,
      );

      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(home: EventsPage(events: <DispatchEvent>[reportEvent])),
      );
      await tester.pumpAndSettle();

      final rowLabel = find.text('Event ID RPT-EVT-LEGACY-1');
      await tester.scrollUntilVisible(
        rowLabel,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(rowLabel, findsOneWidget);
    },
  );

  testWidgets('integrity certificate preview card opens certificate dialog', (
    tester,
  ) async {
    final occurredAt = DateTime.utc(2026, 3, 13, 10, 5);
    final event = IntelligenceReceived(
      eventId: 'INT-CERT-1',
      sequence: 1,
      version: 1,
      occurredAt: occurredAt,
      intelligenceId: 'INTEL-CERT-001',
      provider: 'frigate',
      sourceType: 'hardware',
      externalId: 'evt-9001',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
      headline: 'Person detected',
      summary: 'Intrusion candidate at east gate.',
      riskScore: 92,
      canonicalHash: 'canon-hash-001',
      snapshotUrl: 'https://edge.example.com/snap.jpg',
      clipUrl: 'https://edge.example.com/clip.mp4',
      snapshotReferenceHash: 'snap-hash-001',
      clipReferenceHash: 'clip-hash-001',
      evidenceRecordHash: 'record-hash-001',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IntegrityCertificatePreviewCard(event: event)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Integrity Certificate'), findsOneWidget);
    await tester.tap(find.text('View Certificate'));
    await tester.pumpAndSettle();

    expect(find.text('ONYX Evidence Integrity Certificate'), findsOneWidget);
    expect(find.textContaining('record-hash-001'), findsOneWidget);
    expect(find.text('Markdown'), findsOneWidget);
    expect(find.text('JSON'), findsOneWidget);
    expect(find.text('Copy JSON'), findsOneWidget);
    expect(find.text('Copy Markdown'), findsOneWidget);
  });
}
