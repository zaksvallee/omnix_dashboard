import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/ui/sovereign_ledger_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sovereign ledger export actions are interactive', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
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
    expect(copiedClipboardPayload, contains('"decision_label": "Escalation Candidate"'));
    expect(copiedClipboardPayload, contains('Person visible near the boundary line.'));

    final viewInEventReview = find.text('VIEW IN EVENT REVIEW').first;
    await tester.ensureVisible(viewInEventReview);
    await tester.tap(viewInEventReview, warnIfMissed: false);
    await tester.pump();
    expect(find.textContaining('Open Event Review to inspect'), findsOneWidget);
    expect(find.text('SCENE REVIEW'), findsOneWidget);
    expect(find.text('openai:gpt-4.1-mini'), findsOneWidget);
    expect(find.text('Escalation Candidate'), findsOneWidget);
    expect(find.textContaining('Escalated for urgent review'), findsOneWidget);
  });
}
