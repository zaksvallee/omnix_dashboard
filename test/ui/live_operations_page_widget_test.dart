import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/ui/live_operations_page.dart';

void main() {
  testWidgets('live operations stays stable on phone viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: LiveOperationsPage(events: [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('INCIDENT QUEUE'), findsOneWidget);
    expect(find.text('SOVEREIGN LEDGER FEED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live operations stays stable on landscape phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: LiveOperationsPage(events: [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('INCIDENT QUEUE'), findsOneWidget);
    expect(find.text('SOVEREIGN LEDGER FEED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live operations renders multi-incident layout panels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LiveOperationsPage(events: [])),
    );

    expect(find.text('INCIDENT QUEUE'), findsOneWidget);
    expect(find.text('ACTION LADDER'), findsOneWidget);
    expect(find.text('INCIDENT CONTEXT'), findsOneWidget);
    expect(find.text('SOVEREIGN LEDGER FEED'), findsOneWidget);
    expect(find.byKey(const Key('incident-card-INC-8829-QX')), findsOneWidget);
    expect(find.byKey(const Key('incident-card-INC-8830-RZ')), findsOneWidget);
  });

  testWidgets('manual override requires selecting a reason code', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LiveOperationsPage(events: [])),
    );

    await tester.ensureVisible(find.text('MANUAL OVERRIDE'));
    await tester.tap(find.text('MANUAL OVERRIDE'));
    await tester.pumpAndSettle();

    final submitFinder = find.byKey(const Key('override-submit-button'));
    expect(submitFinder, findsOneWidget);
    expect((tester.widget<FilledButton>(submitFinder)).onPressed, isNull);

    await tester.tap(find.byKey(const Key('reason-DUPLICATE_SIGNAL')));
    await tester.pumpAndSettle();

    expect((tester.widget<FilledButton>(submitFinder)).onPressed, isNotNull);

    await tester.tap(submitFinder);
    await tester.pumpAndSettle();
    expect(find.text('Select a reason code (required):'), findsNothing);
  });

  testWidgets('pause action records a ledger entry', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LiveOperationsPage(events: [])),
    );
    await tester.pumpAndSettle();

    final pauseButton = find.widgetWithText(OutlinedButton, 'Pause').first;
    await tester.ensureVisible(pauseButton);
    await tester.tap(pauseButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Automation paused for INC-8829-QX'),
      findsWidgets,
    );
  });

  testWidgets('live operations enriches incident context with CCTV evidence', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: [
            DecisionCreated(
              eventId: 'decision-1',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 3)),
              dispatchId: 'D-1001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            IntelligenceReceived(
              eventId: 'intel-1',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              intelligenceId: 'INT-1',
              provider: 'frigate',
              sourceType: 'hardware',
              externalId: 'evt-1',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              headline: 'FRIGATE INTRUSION',
              summary: 'CCTV person detected in north_gate',
              riskScore: 95,
              snapshotUrl:
                  'https://edge.example.com/api/events/evt-1/snapshot.jpg',
              clipUrl: 'https://edge.example.com/api/events/evt-1/clip.mp4',
              canonicalHash: 'hash-1',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Latest CCTV Intel'), findsOneWidget);
    expect(find.text('FRIGATE INTRUSION'), findsOneWidget);
    expect(find.text('Evidence Ready'), findsOneWidget);
    expect(find.text('snapshot + clip'), findsOneWidget);
    expect(find.textContaining('snapshot.jpg'), findsOneWidget);
    expect(find.textContaining('clip.mp4'), findsOneWidget);
  });

  testWidgets('live operations switches latest intel and ladder labels for DVR', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: [
            DecisionCreated(
              eventId: 'decision-1',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 3)),
              dispatchId: 'D-1001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            IntelligenceReceived(
              eventId: 'intel-1',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              intelligenceId: 'INT-1',
              provider: 'hikvision-dvr',
              sourceType: 'dvr',
              externalId: 'evt-1',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              headline: 'DVR INTRUSION',
              summary: 'DVR vehicle detected at bay_2',
              riskScore: 91,
              canonicalHash: 'hash-1',
            ),
          ],
          videoOpsLabel: 'DVR',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Latest DVR Intel'), findsOneWidget);
    expect(find.text('DVR ACTIVATION'), findsWidgets);
  });
}
