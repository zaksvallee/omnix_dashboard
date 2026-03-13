import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/guard_checked_in.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/response_arrived.dart';
import 'package:omnix_dashboard/ui/events_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('events page stays stable on phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: EventsPage(events: <DispatchEvent>[])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Event Review'), findsOneWidget);
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

    expect(find.text('Event Review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('events page shows empty timeline state when no events exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: EventsPage(events: <DispatchEvent>[])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Event Review'), findsOneWidget);
    expect(find.text('Forensic Filters'), findsOneWidget);
  });

  testWidgets('events page renders timeline rows and selected detail pane', (
    tester,
  ) async {
    final events = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'INT-1',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 11, 0),
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
        occurredAt: DateTime.utc(2026, 3, 6, 11, 5),
        dispatchId: 'DSP-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
      GuardCheckedIn(
        eventId: 'CHK-1',
        sequence: 3,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 11, 7),
        guardId: 'GUARD-001',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
      ResponseArrived(
        eventId: 'ARR-1',
        sequence: 4,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 11, 9),
        dispatchId: 'DSP-1',
        guardId: 'GUARD-001',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
    ];

    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(home: EventsPage(events: events)));
    await tester.pumpAndSettle();

    expect(find.text('Timeline Feed'), findsOneWidget);
    expect(find.text('Advanced Filters'), findsOneWidget);
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

    final rowSummary = find.textContaining('newsapi.org/news-1').first;
    await tester.ensureVisible(rowSummary);
    final rowCard = find.ancestor(
      of: rowSummary,
      matching: find.byType(InkWell),
    );
    await tester.tap(rowCard.first);
    await tester.pumpAndSettle();

    expect(find.text('Selected Event'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
