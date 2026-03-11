import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/ui/tactical_page.dart';

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

  testWidgets('tactical page shows CCTV telemetry counters from events', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
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
    expect(find.text('Signals • 4'), findsOneWidget);
    expect(find.text('LPR Hits • 1'), findsOneWidget);
    expect(find.text('Anomalies • 3'), findsOneWidget);
    expect(find.text('Trend • UP'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
