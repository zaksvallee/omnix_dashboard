import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/partner_dispatch_status_declared.dart';
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

  testWidgets('events review shows persisted scene review context', (
    tester,
  ) async {
    final events = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'INT-DVR-2',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 11, 5),
        intelligenceId: 'INTEL-DVR-002',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'dvr-2',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Perimeter alert',
        summary: 'Motion detected at the boundary.',
        riskScore: 90,
        canonicalHash: 'hash-dvr-2',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: EventsReviewPage(
          events: events,
          sceneReviewByIntelligenceId: {
            'INTEL-DVR-002': MonitoringSceneReviewRecord(
              intelligenceId: 'INTEL-DVR-002',
              sourceLabel: 'openai:gpt-4.1-mini',
              postureLabel: 'escalation candidate',
              decisionLabel: 'Escalation Candidate',
              decisionSummary:
                  'Escalated for urgent review because person activity was detected, the scene suggested boundary proximity, and confidence remained high.',
              summary: 'Person visible near the boundary line.',
              reviewedAtUtc: DateTime.utc(2026, 3, 6, 11, 5),
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SCENE REVIEW'), findsOneWidget);
    expect(find.text('openai:gpt-4.1-mini'), findsOneWidget);
    expect(find.text('escalation candidate'), findsOneWidget);
    expect(find.text('Escalation Candidate'), findsOneWidget);
    expect(find.text('Person visible near the boundary line.'), findsOneWidget);
    expect(find.textContaining('Escalated for urgent review'), findsOneWidget);
  });

  testWidgets('events review shows identity policy from scene review', (
    tester,
  ) async {
    final events = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'INT-DVR-4',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 11, 8),
        intelligenceId: 'INTEL-DVR-004',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'dvr-4',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Identity alert',
        summary: 'Face and plate matched flagged records.',
        riskScore: 93,
        canonicalHash: 'hash-dvr-4',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: EventsReviewPage(
          events: events,
          sceneReviewByIntelligenceId: {
            'INTEL-DVR-004': MonitoringSceneReviewRecord(
              intelligenceId: 'INTEL-DVR-004',
              sourceLabel: 'openai:gpt-4.1-mini',
              postureLabel: 'identity match concern',
              decisionLabel: 'Escalation Candidate',
              decisionSummary:
                  'Escalated for urgent review because face match PERSON-44 was flagged and the event metadata suggested an unauthorized or watchlist context.',
              summary: 'Flagged face and plate remained in frame.',
              reviewedAtUtc: DateTime.utc(2026, 3, 6, 11, 8),
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Identity Policy'), findsOneWidget);
    expect(find.text('Flagged match'), findsOneWidget);
  });

  testWidgets('events review exposes identity policy filter and applies it', (
    tester,
  ) async {
    final events = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'INT-DVR-FLAGGED',
        sequence: 3,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 11, 9),
        intelligenceId: 'INTEL-DVR-FLAGGED',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'dvr-flagged',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Flagged visitor vehicle',
        summary: 'Face and plate matched flagged records.',
        riskScore: 93,
        canonicalHash: 'hash-dvr-flagged',
      ),
      IntelligenceReceived(
        eventId: 'INT-DVR-ALLOWLISTED',
        sequence: 2,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 11, 8),
        intelligenceId: 'INTEL-DVR-ALLOWLISTED',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'dvr-allowlisted',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Resident vehicle entry',
        summary: 'Known resident vehicle entered the driveway.',
        riskScore: 41,
        canonicalHash: 'hash-dvr-allowlisted',
      ),
      IntelligenceReceived(
        eventId: 'INT-DVR-OTHER',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 11, 7),
        intelligenceId: 'INTEL-DVR-OTHER',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'dvr-other',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Vehicle motion',
        summary: 'Vehicle remained near the loading bay.',
        riskScore: 61,
        canonicalHash: 'hash-dvr-other',
      ),
      IntelligenceReceived(
        eventId: 'INT-DVR-TEMP',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 11, 6),
        intelligenceId: 'INTEL-DVR-TEMP',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'dvr-temp',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Expected visitor arrival',
        summary: 'One-time approved visitor entered the gate lane.',
        riskScore: 38,
        canonicalHash: 'hash-dvr-temp',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: EventsReviewPage(
          events: events,
          sceneReviewByIntelligenceId: {
            'INTEL-DVR-FLAGGED': MonitoringSceneReviewRecord(
              intelligenceId: 'INTEL-DVR-FLAGGED',
              sourceLabel: 'openai:gpt-4.1-mini',
              postureLabel: 'identity match concern',
              decisionLabel: 'Escalation Candidate',
              decisionSummary:
                  'Escalated for urgent review because face match PERSON-44 was flagged and the event metadata suggested an unauthorized or watchlist context.',
              summary: 'Flagged face and plate remained in frame.',
              reviewedAtUtc: DateTime.utc(2026, 3, 6, 11, 9),
            ),
            'INTEL-DVR-ALLOWLISTED': MonitoringSceneReviewRecord(
              intelligenceId: 'INTEL-DVR-ALLOWLISTED',
              sourceLabel: 'openai:gpt-4.1-mini',
              postureLabel: 'known allowed identity',
              decisionLabel: 'Suppressed',
              decisionSummary:
                  'Suppressed because the face and plate were allowlisted for this site.',
              summary: 'Resident remained within the expected arrival lane.',
              reviewedAtUtc: DateTime.utc(2026, 3, 6, 11, 8),
            ),
            'INTEL-DVR-TEMP': MonitoringSceneReviewRecord(
              intelligenceId: 'INTEL-DVR-TEMP',
              sourceLabel: 'openai:gpt-4.1-mini',
              postureLabel: 'known allowed identity',
              decisionLabel: 'Suppressed',
              decisionSummary:
                  'Suppressed because the matched identity has a one-time approval until 2026-03-15 18:00 UTC and the activity remained below the client notification threshold.',
              summary: 'Visitor remained within the expected arrival lane.',
              reviewedAtUtc: DateTime.utc(2026, 3, 6, 11, 6),
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ALL POLICIES'), findsOneWidget);
    expect(find.text('FLAGGED MATCH'), findsOneWidget);
    expect(find.text('TEMPORARY APPROVAL'), findsOneWidget);
    expect(find.text('ALLOWLISTED MATCH'), findsOneWidget);

    await tester.tap(find.text('FLAGGED MATCH'));
    await tester.pumpAndSettle();

    expect(find.text('Flagged visitor vehicle'), findsWidgets);
    expect(find.text('Resident vehicle entry'), findsNothing);
    expect(find.text('Expected visitor arrival'), findsNothing);
    expect(find.text('Vehicle motion'), findsNothing);

    await tester.tap(find.text('TEMPORARY APPROVAL'));
    await tester.pumpAndSettle();

    expect(find.text('Expected visitor arrival'), findsWidgets);
    expect(find.text('Flagged visitor vehicle'), findsNothing);
    expect(find.text('Resident vehicle entry'), findsNothing);
  });

  testWidgets('events review filters to visit-scoped event ids', (
    tester,
  ) async {
    final events = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'VISIT-EVT-1',
        sequence: 4,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 11, 8),
        intelligenceId: 'INTEL-VISIT-001',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'visit-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        zone: 'entry_lane',
        headline: 'Vehicle entered lane',
        summary: 'Vehicle entered the gate lane.',
        riskScore: 71,
        canonicalHash: 'hash-visit-1',
      ),
      IntelligenceReceived(
        eventId: 'VISIT-EVT-2',
        sequence: 3,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 11, 10),
        intelligenceId: 'INTEL-VISIT-002',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'visit-2',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        zone: 'wash_bay',
        headline: 'Vehicle entered wash bay',
        summary: 'Vehicle remained in the wash bay.',
        riskScore: 69,
        canonicalHash: 'hash-visit-2',
      ),
      IntelligenceReceived(
        eventId: 'VISIT-EVT-3',
        sequence: 2,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 11, 12),
        intelligenceId: 'INTEL-VISIT-003',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'visit-3',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        zone: 'exit_lane',
        headline: 'Vehicle exited lane',
        summary: 'Vehicle exited the gate lane.',
        riskScore: 67,
        canonicalHash: 'hash-visit-3',
      ),
      IntelligenceReceived(
        eventId: 'OTHER-EVT-1',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 11, 8),
        intelligenceId: 'INTEL-OTHER-001',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'other-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Unrelated vehicle pass',
        summary: 'Different vehicle crossed the outer lane.',
        riskScore: 42,
        canonicalHash: 'hash-other-1',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: EventsReviewPage(
          events: events,
          initialSelectedEventId: 'VISIT-EVT-3',
          initialScopedEventIds: const [
            'VISIT-EVT-1',
            'VISIT-EVT-2',
            'VISIT-EVT-3',
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final visitTimelineCard = find.byKey(
      const ValueKey('events-visit-timeline-card'),
    );
    await tester.ensureVisible(visitTimelineCard);
    expect(visitTimelineCard, findsOneWidget);
    expect(find.text('Vehicle entered lane'), findsWidgets);
    expect(find.text('Vehicle entered wash bay'), findsWidgets);
    expect(find.text('Vehicle exited lane'), findsWidgets);
    expect(find.text('Unrelated vehicle pass'), findsNothing);
    expect(find.text('LINKED EVENTS'), findsOneWidget);
    expect(find.text('LINKED INTEL'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('events-visit-status-pill')),
      findsOneWidget,
    );
    expect(find.text('COMPLETED'), findsOneWidget);
    expect(find.text('ENTRY'), findsWidgets);
    expect(find.text('SERVICE'), findsWidgets);
    expect(find.text('EXIT'), findsWidgets);
    expect(find.textContaining('VISIT-EVT-1'), findsWidgets);
    expect(find.textContaining('VISIT-EVT-2'), findsWidgets);
    expect(find.textContaining('VISIT-EVT-3'), findsWidgets);
    expect(
      find.byKey(const ValueKey('events-selected-event-id')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('events-selected-event-id')))
          .data,
      'VISIT-EVT-3',
    );

    await tester.tap(
      find.byKey(const ValueKey('events-visit-step-VISIT-EVT-2')),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('events-selected-event-id')))
          .data,
      'VISIT-EVT-2',
    );
  });

  testWidgets('events review shows partner dispatch scope banner', (
    tester,
  ) async {
    final events = <DispatchEvent>[
      PartnerDispatchStatusDeclared(
        eventId: 'PARTNER-EVT-1',
        sequence: 4,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 23, 14),
        dispatchId: 'INC-8821',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        partnerLabel: 'Rapid Shield',
        actorLabel: 'RS-CTRL-01',
        status: PartnerDispatchStatus.accepted,
        sourceChannel: 'telegram',
        sourceMessageKey: 'tg:partner:8821:1',
      ),
      PartnerDispatchStatusDeclared(
        eventId: 'PARTNER-EVT-2',
        sequence: 3,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 23, 19),
        dispatchId: 'INC-8821',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        partnerLabel: 'Rapid Shield',
        actorLabel: 'RS-UNIT-04',
        status: PartnerDispatchStatus.onSite,
        sourceChannel: 'telegram',
        sourceMessageKey: 'tg:partner:8821:2',
      ),
      PartnerDispatchStatusDeclared(
        eventId: 'PARTNER-EVT-3',
        sequence: 2,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 23, 27),
        dispatchId: 'INC-8821',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        partnerLabel: 'Rapid Shield',
        actorLabel: 'RS-UNIT-04',
        status: PartnerDispatchStatus.allClear,
        sourceChannel: 'telegram',
        sourceMessageKey: 'tg:partner:8821:3',
      ),
      IntelligenceReceived(
        eventId: 'OTHER-EVT-2',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 23, 30),
        intelligenceId: 'INTEL-OTHER-002',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'other-2',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Unrelated perimeter movement',
        summary: 'General motion near the outer wall.',
        riskScore: 41,
        canonicalHash: 'hash-other-2',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: EventsReviewPage(
          events: events,
          initialSelectedEventId: 'PARTNER-EVT-3',
          initialScopedEventIds: const [
            'PARTNER-EVT-1',
            'PARTNER-EVT-2',
            'PARTNER-EVT-3',
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Partner dispatch review active for 3 declared actions.',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Rapid Shield • SITE-SANDTON', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.textContaining('Visit-scoped review active for'), findsNothing);
    expect(find.textContaining('Rapid Shield declared'), findsWidgets);
    expect(find.text('Unrelated perimeter movement'), findsNothing);
  });

  testWidgets('events review surfaces FR and LPR context for DVR events', (
    tester,
  ) async {
    final events = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'INT-DVR-3',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 11, 7),
        intelligenceId: 'INTEL-DVR-003',
        provider: 'hikvision_dvr',
        sourceType: 'dvr',
        externalId: 'dvr-3',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        cameraId: 'channel-3',
        zone: 'loading_bay',
        objectLabel: 'vehicle',
        objectConfidence: 94.2,
        faceMatchId: 'PERSON-44',
        faceConfidence: 91.2,
        plateNumber: 'CA123456',
        plateConfidence: 96.4,
        headline: 'Vehicle detection alert',
        summary: 'Matched visitor vehicle entered loading bay.',
        riskScore: 88,
        canonicalHash: 'hash-dvr-3',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(home: EventsReviewPage(events: events)),
    );
    await tester.pumpAndSettle();

    expect(find.text('hikvision_dvr'), findsWidgets);
    expect(find.text('channel-3'), findsOneWidget);
    expect(find.text('loading_bay'), findsOneWidget);
    expect(find.text('vehicle • 94.2%'), findsOneWidget);
    expect(find.text('PERSON-44 • 91.2%'), findsOneWidget);
    expect(find.text('CA123456 • 96.4%'), findsOneWidget);
    expect(find.textContaining('"faceMatchId": "PERSON-44"'), findsOneWidget);
    expect(find.textContaining('"plateNumber": "CA123456"'), findsOneWidget);
    expect(
      find.textContaining('"detailSummary": "Matched visitor vehicle entered'),
      findsOneWidget,
    );
  });
}
