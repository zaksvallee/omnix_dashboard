import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/ui/events_review_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('events review action buttons are interactive', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? copiedClipboardPayload;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = (call.arguments as Map<dynamic, dynamic>);
          copiedClipboardPayload = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

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
    ];

    await tester.pumpWidget(
      MaterialApp(home: EventsReviewPage(events: events)),
    );
    await tester.pumpAndSettle();

    final exportEventData = find.byKey(
      const ValueKey('events-export-data-action'),
    );
    await tester.ensureVisible(exportEventData.first);
    final exportAction = tester.widget<InkWell>(exportEventData.first);
    expect(exportAction.onTap, isNotNull);
    exportAction.onTap!();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('events-last-action-feedback')),
      findsOneWidget,
    );
    expect(find.text('Event payload copied for INT-1.'), findsWidgets);
    expect(copiedClipboardPayload, isNotNull);
    expect(copiedClipboardPayload, contains('"eventId": "INT-1"'));

    final viewInLedger = find.byKey(
      const ValueKey('events-view-ledger-action'),
    );
    await tester.ensureVisible(viewInLedger.first);
    final ledgerAction = tester.widget<InkWell>(viewInLedger.first);
    expect(ledgerAction.onTap, isNotNull);
    ledgerAction.onTap!();
    await tester.pump();
    expect(find.text('Open Sovereign Ledger to inspect INT-1.'), findsWidgets);
  });

  testWidgets('events review exposes DVR source filter and applies it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final events = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'INT-DVR-1',
        sequence: 3,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 11, 2),
        intelligenceId: 'INTEL-DVR-001',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'dvr-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Loading bay vehicle alert',
        summary: 'Unauthorized vehicle at loading bay.',
        riskScore: 72,
        canonicalHash: 'hash-dvr-1',
      ),
      IntelligenceReceived(
        eventId: 'INT-HW-1',
        sequence: 2,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 11, 1),
        intelligenceId: 'INTEL-HW-001',
        provider: 'frigate',
        sourceType: 'hardware',
        externalId: 'hw-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Perimeter line crossing',
        summary: 'Motion detected on perimeter camera.',
        riskScore: 79,
        canonicalHash: 'hash-hw-1',
      ),
      IntelligenceReceived(
        eventId: 'INT-NEWS-1',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 11, 0),
        intelligenceId: 'INTEL-NEWS-001',
        provider: 'newsapi.org',
        sourceType: 'news',
        externalId: 'news-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Regional protest alert',
        summary: 'Protest expected near Sandton corridor.',
        riskScore: 61,
        canonicalHash: 'hash-news-1',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(home: EventsReviewPage(events: events)),
    );
    await tester.pumpAndSettle();

    expect(find.text('NEWS'), findsOneWidget);
    expect(find.text('HARDWARE'), findsOneWidget);
    expect(find.text('DVR'), findsOneWidget);

    await tester.tap(find.text('DVR').first);
    await tester.pumpAndSettle();

    expect(find.text('Loading bay vehicle alert'), findsWidgets);
    expect(find.text('Perimeter line crossing'), findsNothing);
    expect(find.text('Regional protest alert'), findsNothing);
  });
}
