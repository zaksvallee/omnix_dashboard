import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/ui/sovereign_ledger_page.dart';

import '../fixtures/report_test_receipt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sovereign ledger hero view events opens selected entry scope', (
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

    expect(find.text('Sovereign Ledger'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ledger-hero-view-events-button')));
    await tester.pumpAndSettle();

    expect(openedEventIds, equals(const ['INT-LEDGER-HERO-1']));
    expect(openedSelectedEventId, 'INT-LEDGER-HERO-1');
  });

  testWidgets('sovereign ledger export actions are interactive', (
    tester,
  ) async {
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

    final exportLedger = find.text('EXPORT LEDGER').first;
    await tester.ensureVisible(exportLedger);
    await tester.tap(exportLedger);
    await tester.pump();
    expect(find.textContaining('Ledger export copied'), findsOneWidget);

    final exportEntryData = find.text('EXPORT ENTRY DATA').first;
    await tester.ensureVisible(exportEntryData);
    await tester.tap(exportEntryData, warnIfMissed: false);
    await tester.pump();
    expect(find.textContaining('Entry export copied'), findsOneWidget);
    expect(copiedClipboardPayload, contains('"sceneReview"'));
    expect(
      copiedClipboardPayload,
      contains('"decision_label": "Escalation Candidate"'),
    );
    expect(
      copiedClipboardPayload,
      contains('Person visible near the boundary line.'),
    );

    final viewInEventReview = find.text('VIEW IN EVENT REVIEW').first;
    await tester.ensureVisible(viewInEventReview);
    await tester.tap(viewInEventReview, warnIfMissed: false);
    await tester.pump();
    expect(openedEventIds, <String>['INT-LEDGER-1']);
    expect(openedSelectedEventId, 'INT-LEDGER-1');
    expect(find.text('SCENE REVIEW'), findsOneWidget);
    expect(find.text('openai:gpt-4.1-mini'), findsOneWidget);
    expect(find.text('Escalation Candidate'), findsOneWidget);
    expect(find.textContaining('Escalated for urgent review'), findsOneWidget);
  });

  testWidgets(
    'sovereign ledger shows tracked report section configuration for generated receipts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final events = <DispatchEvent>[
        buildTestReportGenerated(
          eventId: 'RPT-LEDGER-1',
          sequence: 1,
          occurredAt: DateTime.utc(2026, 3, 15, 6, 0),
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
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: SovereignLedgerPage(clientId: 'CLIENT-001', events: events),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('REPORT'), findsWidgets);
      expect(
        find.textContaining(
          '2 sections omitted • custom branding override • governance handoff',
        ),
        findsWidgets,
      );
      expect(find.text('REPORT CONFIGURATION'), findsOneWidget);
      expect(find.text('Tracked'), findsOneWidget);
      expect(find.text('Custom Override'), findsOneWidget);
      expect(find.text('PARTNER • Alpha'), findsWidgets);
      expect(
        find.text(
          'Branding: custom override from default partner lane PARTNER • Alpha.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Included: Incident Timeline, Dispatch Summary, Checkpoint Compliance. Omitted: AI Decision Log, Guard Metrics.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Incident Timeline, Dispatch Summary, Checkpoint Compliance'),
        findsOneWidget,
      );
      expect(find.text('AI Decision Log, Guard Metrics'), findsWidgets);
    },
  );

  testWidgets('sovereign ledger labels legacy report receipt configuration', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final events = <DispatchEvent>[
      buildTestReportGenerated(
        eventId: 'RPT-LEDGER-LEGACY-1',
        sequence: 1,
        occurredAt: DateTime.utc(2026, 3, 15, 6, 0),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        month: '2026-03',
        reportSchemaVersion: 1,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(clientId: 'CLIENT-001', events: events),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('legacy receipt config'), findsWidgets);
    expect(find.text('REPORT CONFIGURATION'), findsOneWidget);
    expect(find.text('Legacy'), findsOneWidget);
    expect(
      find.text(
        'Legacy receipt. Per-section report configuration was not captured for this generated report.',
      ),
      findsOneWidget,
    );
    expect(find.text('Legacy receipt'), findsOneWidget);
    expect(find.text('Not captured'), findsOneWidget);
  });

  testWidgets('sovereign ledger narrows entries to the scoped lane', (
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
    expect(find.text('Scope focus active'), findsOneWidget);
    expect(find.text('CLIENT-001/SITE-VALLEE'), findsOneWidget);
    expect(find.text('Vallee gate alert'), findsWidgets);
    expect(find.text('Sandton boundary alert'), findsNothing);
    expect(find.textContaining('Focus LINKED • INTEL-LEDGER-SCOPE-2'), findsOneWidget);
  });

  testWidgets(
    'sovereign ledger marks incident focus as scope-backed when lane matches',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final events = <DispatchEvent>[
        DecisionCreated(
          eventId: 'DEC-LEDGER-SCOPE-1',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 16, 8, 0),
          dispatchId: 'DSP-4401',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
        ),
        IntelligenceReceived(
          eventId: 'INT-LEDGER-SCOPE-3',
          sequence: 2,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 16, 8, 5),
          intelligenceId: 'INTEL-LEDGER-SCOPE-3',
          provider: 'hikvision_dvr_monitor_only',
          sourceType: 'dvr',
          externalId: 'ext-scope-3',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          headline: 'Vallee patrol movement',
          summary: 'Tracked movement near the Vallee patrol corridor.',
          riskScore: 73,
          canonicalHash: 'hash-scope-3',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: SovereignLedgerPage(
            clientId: 'CLIENT-001',
            initialScopeClientId: 'CLIENT-001',
            initialScopeSiteId: 'SITE-VALLEE',
            events: events,
            initialFocusReference: 'INC-DSP-4401',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Focus SCOPE-BACKED • INC-DSP-4401'),
        findsOneWidget,
      );
      expect(find.text('Vallee patrol movement'), findsWidgets);
      expect(find.textContaining('Focused lane is waiting'), findsNothing);
    },
  );
}
