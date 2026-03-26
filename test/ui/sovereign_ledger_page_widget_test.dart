import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/patrol_completed.dart';
import 'package:omnix_dashboard/ui/sovereign_ledger_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('occurrence book hero view events opens selected entry scope', (
    tester,
  ) async {
    List<String>? openedEventIds;
    String? openedSelectedEventId;

    final events = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'INT-LEDGER-HERO-1',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 14, 21, 14),
        intelligenceId: 'INTEL-LEDGER-HERO-1',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-hero-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        cameraId: 'channel-1',
        objectLabel: 'person',
        objectConfidence: 0.94,
        headline: 'Boundary alert',
        summary: 'Person detected near line crossing.',
        riskScore: 94,
        evidenceRecordHash: 'evidence-hero-1',
        canonicalHash: 'hash-hero-1',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: events,
          onOpenEventsForScope: (eventIds, selectedEventId) {
            openedEventIds = eventIds;
            openedSelectedEventId = selectedEventId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Occurrence Book'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('ledger-hero-view-events-button')),
    );
    await tester.pumpAndSettle();

    expect(openedEventIds, equals(const ['INT-LEDGER-HERO-1']));
    expect(openedSelectedEventId, 'INT-LEDGER-HERO-1');
  });

  testWidgets('occurrence book export actions are interactive', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? copiedClipboardPayload;
    List<String>? openedEventIds;
    String? openedSelectedEventId;
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
        eventId: 'INT-LEDGER-1',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 14, 21, 14),
        intelligenceId: 'INTEL-LEDGER-1',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        cameraId: 'channel-1',
        objectLabel: 'person',
        objectConfidence: 0.94,
        headline: 'Boundary alert',
        summary: 'Person detected near line crossing.',
        riskScore: 94,
        evidenceRecordHash: 'evidence-1',
        canonicalHash: 'hash-1',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: events,
          onOpenEventsForScope: (eventIds, selectedEventId) {
            openedEventIds = eventIds;
            openedSelectedEventId = selectedEventId;
          },
          sceneReviewByIntelligenceId: {
            'INTEL-LEDGER-1': MonitoringSceneReviewRecord(
              intelligenceId: 'INTEL-LEDGER-1',
              evidenceRecordHash: 'evidence-1',
              sourceLabel: 'openai:gpt-4.1-mini',
              postureLabel: 'escalation candidate',
              decisionLabel: 'Escalation Candidate',
              decisionSummary:
                  'Escalated for urgent review because person activity was detected, the scene suggested boundary proximity, and confidence remained high.',
              summary: 'Person visible near the boundary line.',
              reviewedAtUtc: DateTime.utc(2026, 3, 14, 21, 14),
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-workspace-command-receipt')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('ledger-context-export-ledger')),
    );
    await tester.pump();
    expect(find.textContaining('Ledger export copied'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-export-data')),
    );
    await tester.tap(find.byKey(const ValueKey('ledger-entry-export-data')));
    await tester.pump();
    expect(find.textContaining('Entry export copied'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(copiedClipboardPayload, contains('"sceneReview"'));
    expect(
      copiedClipboardPayload,
      contains('"decision_label": "Escalation Candidate"'),
    );
    expect(
      copiedClipboardPayload,
      contains('Person visible near the boundary line.'),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-view-event-review')),
    );
    await tester.tap(
      find.byKey(const ValueKey('ledger-entry-view-event-review')),
    );
    await tester.pump();
    expect(openedEventIds, <String>['INT-LEDGER-1']);
    expect(openedSelectedEventId, 'INT-LEDGER-1');
    expect(find.text('SCENE REVIEW'), findsOneWidget);
    expect(find.text('openai:gpt-4.1-mini'), findsOneWidget);
    expect(find.text('Escalation Candidate'), findsOneWidget);
    expect(find.textContaining('Escalated for urgent review'), findsWidgets);
  });

  testWidgets('occurrence book filters categories and switches views', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final events = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'INT-LEDGER-OPS-1',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 15, 6, 30),
        intelligenceId: 'INTEL-LEDGER-OPS-1',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-ops-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Perimeter anomaly',
        summary: 'Movement detected near the north boundary.',
        riskScore: 82,
        canonicalHash: 'hash-ops-1',
      ),
      PatrolCompleted(
        eventId: 'PATROL-LEDGER-OPS-1',
        sequence: 2,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 15, 7, 0),
        guardId: 'GUARD-3',
        routeId: 'ROUTE-NORTH',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        durationSeconds: 720,
      ),
      DecisionCreated(
        eventId: 'DEC-LEDGER-OPS-1',
        sequence: 3,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 15, 7, 30),
        dispatchId: 'DSP-LEDGER-OPS-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1440, 1100)),
          child: SovereignLedgerPage(clientId: 'CLIENT-001', events: events),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-workspace-status-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ledger-workspace-command-receipt')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ledger-workspace-panel-case-file')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('ledger-lane-filter-patrol')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-entry-card-LED-2')),
      findsOneWidget,
    );
    expect(find.text('Patrol completed - Sandton Estate'), findsOneWidget);
    expect(find.text('Controller dispatched response'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ledger-workspace-view-chain')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-workspace-panel-chain')),
      findsOneWidget,
    );
    expect(find.text('Record Integrity'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ledger-context-verify-chain')));
    await tester.pumpAndSettle();

    expect(find.text('INTACT'), findsWidgets);
    expect(find.text('Chain verification returned intact.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ledger-workspace-view-trace')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-workspace-panel-trace')),
      findsOneWidget,
    );
    expect(find.text('Linked Context'), findsOneWidget);
  });

  testWidgets('occurrence book submits a new ob entry from the composer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: SovereignLedgerPage(clientId: 'CLIENT-001', events: []),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ledger-open-composer')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('ledger-form-location')),
      'North Gate',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ledger-form-description')),
      'False alarm caused by faulty gate sensor. No intrusion.',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-form-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('ledger-form-submit')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-entry-card-MAN-2442')),
      findsOneWidget,
    );
    expect(
      find.textContaining('OB entry submitted (OB-2442).'),
      findsOneWidget,
    );
    expect(
      find.text('False alarm caused by faulty gate sensor. No intrusion.'),
      findsWidgets,
    );
  });

  testWidgets('occurrence book narrows entries to the scoped site', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final events = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'INT-LEDGER-SCOPE-1',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 16, 8, 0),
        intelligenceId: 'INTEL-LEDGER-SCOPE-1',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-scope-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Sandton boundary alert',
        summary: 'Person detected near Sandton line crossing.',
        riskScore: 88,
        canonicalHash: 'hash-scope-1',
      ),
      IntelligenceReceived(
        eventId: 'INT-LEDGER-SCOPE-2',
        sequence: 2,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 16, 8, 5),
        intelligenceId: 'INTEL-LEDGER-SCOPE-2',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-scope-2',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-VALLEE',
        headline: 'Vallee gate alert',
        summary: 'Vehicle detected near Vallee gate.',
        riskScore: 77,
        canonicalHash: 'hash-scope-2',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          initialScopeClientId: 'CLIENT-001',
          initialScopeSiteId: 'SITE-VALLEE',
          events: events,
          initialFocusReference: 'INTEL-LEDGER-SCOPE-2',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ledger-scope-banner')), findsOneWidget);
    expect(find.textContaining('Client 001 / Site Vallee'), findsOneWidget);
    expect(find.text('Vallee gate alert'), findsWidgets);
    expect(find.text('Sandton boundary alert'), findsNothing);
    expect(find.textContaining('Focus: INTEL-LEDGER-SCOPE-2'), findsOneWidget);
  });
}
