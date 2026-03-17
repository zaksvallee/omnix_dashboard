import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/morning_sovereign_report_service.dart';
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
          morningSovereignReportHistory: [
            SovereignReport(
              date: '2026-03-14',
              generatedAtUtc: DateTime.utc(2026, 3, 14, 6, 0),
              shiftWindowStartUtc: DateTime.utc(2026, 3, 13, 22, 0),
              shiftWindowEndUtc: DateTime.utc(2026, 3, 14, 6, 0),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 10,
                hashVerified: true,
                integrityScore: 99,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 1,
                humanOverrides: 0,
                overrideReasons: <String, int>{},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 1,
                driftDetected: 0,
                avgMatchScore: 100,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
              partnerProgression: SovereignReportPartnerProgression(
                dispatchCount: 1,
                declarationCount: 1,
                acceptedCount: 1,
                onSiteCount: 0,
                allClearCount: 0,
                cancelledCount: 1,
                summaryLine: '',
                scoreboardRows: [
                  SovereignReportPartnerScoreboardRow(
                    clientId: 'CLIENT-001',
                    siteId: 'SITE-SANDTON',
                    partnerLabel: 'Rapid Shield',
                    dispatchCount: 1,
                    strongCount: 0,
                    onTrackCount: 0,
                    watchCount: 0,
                    criticalCount: 1,
                    averageAcceptedDelayMinutes: 12.0,
                    averageOnSiteDelayMinutes: 22.0,
                    summaryLine:
                        'Dispatches 1 • Strong 0 • On track 0 • Watch 0 • Critical 1 • Avg accept 12.0m • Avg on site 22.0m',
                  ),
                ],
              ),
            ),
            SovereignReport(
              date: '2026-03-15',
              generatedAtUtc: DateTime.utc(2026, 3, 15, 6, 0),
              shiftWindowStartUtc: DateTime.utc(2026, 3, 14, 22, 0),
              shiftWindowEndUtc: DateTime.utc(2026, 3, 15, 6, 0),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 10,
                hashVerified: true,
                integrityScore: 99,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 1,
                humanOverrides: 0,
                overrideReasons: <String, int>{},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 1,
                driftDetected: 0,
                avgMatchScore: 100,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
              partnerProgression: SovereignReportPartnerProgression(
                dispatchCount: 1,
                declarationCount: 3,
                acceptedCount: 1,
                onSiteCount: 1,
                allClearCount: 1,
                cancelledCount: 0,
                summaryLine: '',
                scoreboardRows: [
                  SovereignReportPartnerScoreboardRow(
                    clientId: 'CLIENT-001',
                    siteId: 'SITE-SANDTON',
                    partnerLabel: 'Rapid Shield',
                    dispatchCount: 1,
                    strongCount: 1,
                    onTrackCount: 0,
                    watchCount: 0,
                    criticalCount: 0,
                    averageAcceptedDelayMinutes: 4.0,
                    averageOnSiteDelayMinutes: 10.0,
                    summaryLine:
                        'Dispatches 1 • Strong 1 • On track 0 • Watch 0 • Critical 0 • Avg accept 4.0m • Avg on site 10.0m',
                  ),
                ],
              ),
            ),
          ],
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
    expect(
      find.byKey(const ValueKey('events-partner-progress-card')),
      findsOneWidget,
    );
    expect(find.text('PARTNER DISPATCH CHAIN'), findsOneWidget);
    expect(find.text('INC-8821'), findsWidgets);
    expect(find.text('ALL CLEAR'), findsWidgets);
    expect(
      find.byKey(const ValueKey('events-partner-latest-status-pill')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('events-partner-milestone-accepted')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('events-partner-milestone-onSite')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('events-partner-milestone-allClear')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('events-partner-milestone-cancelled')),
      findsOneWidget,
    );
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('IMPROVING • 2d • STRONG'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('events-partner-trend-reason')),
      findsOneWidget,
    );
    expect(
      find.text('Acceptance timing improved against the prior 7-day average.'),
      findsOneWidget,
    );
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

  testWidgets('events review shows dedicated activity investigation banner', (
    tester,
  ) async {
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
        eventId: 'ACTIVITY-1',
        sequence: 3,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 16, 21, 0),
        intelligenceId: 'INTEL-ACTIVITY-1',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'dvr-activity-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        cameraId: 'gate-cam',
        objectLabel: 'person',
        headline: 'Watchlist subject detected',
        summary: 'Unauthorized person matched watchlist context.',
        riskScore: 93,
        canonicalHash: 'hash-activity-1',
      ),
      IntelligenceReceived(
        eventId: 'ACTIVITY-2',
        sequence: 2,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 16, 22, 0),
        intelligenceId: 'INTEL-ACTIVITY-2',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'dvr-activity-2',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        cameraId: 'gate-cam',
        objectLabel: 'human',
        headline: 'Guard conversation observed',
        summary: 'Guard talking to unknown individual near the gate.',
        riskScore: 66,
        canonicalHash: 'hash-activity-2',
      ),
      IntelligenceReceived(
        eventId: 'ACTIVITY-3',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 17, 0, 30),
        intelligenceId: 'INTEL-ACTIVITY-3',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'dvr-activity-3',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        cameraId: 'gate-cam',
        objectLabel: 'human',
        headline: 'Guard conversation continues',
        summary: 'Guard conversation with unknown individual continued.',
        riskScore: 68,
        canonicalHash: 'hash-activity-3',
      ),
      IntelligenceReceived(
        eventId: 'INT-UNRELATED',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 17, 1, 0),
        intelligenceId: 'INTEL-UNRELATED',
        provider: 'newsapi.org',
        sourceType: 'news',
        externalId: 'news-unrelated',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Unrelated perimeter movement',
        summary: 'General motion near the outer wall.',
        riskScore: 40,
        canonicalHash: 'hash-unrelated',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: EventsReviewPage(
          events: events,
          morningSovereignReportHistory: [
            SovereignReport(
              date: '2026-03-17',
              generatedAtUtc: DateTime.utc(2026, 3, 17, 6, 0),
              shiftWindowStartUtc: DateTime.utc(2026, 3, 16, 22, 0),
              shiftWindowEndUtc: DateTime.utc(2026, 3, 17, 6, 0),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 10,
                hashVerified: true,
                integrityScore: 100,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 1,
                humanOverrides: 0,
                overrideReasons: <String, int>{},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 1,
                driftDetected: 0,
                avgMatchScore: 100,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
              siteActivity: const SovereignReportSiteActivity(
                totalSignals: 3,
                personSignals: 3,
                vehicleSignals: 0,
                knownIdentitySignals: 0,
                flaggedIdentitySignals: 1,
                unknownSignals: 3,
                longPresenceSignals: 1,
                guardInteractionSignals: 2,
                executiveSummary: 'Activity rose overnight.',
                headline: 'Unknown activity rose.',
                summaryLine:
                    'Signals 3 • People 3 • Unknown 3 • Long presence 1 • Guard interactions 2 • Flagged IDs 1',
              ),
            ),
            SovereignReport(
              date: '2026-03-16',
              generatedAtUtc: DateTime.utc(2026, 3, 16, 6, 0),
              shiftWindowStartUtc: DateTime.utc(2026, 3, 15, 22, 0),
              shiftWindowEndUtc: DateTime.utc(2026, 3, 16, 6, 0),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 8,
                hashVerified: true,
                integrityScore: 100,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 1,
                humanOverrides: 0,
                overrideReasons: <String, int>{},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 1,
                driftDetected: 0,
                avgMatchScore: 100,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
              siteActivity: const SovereignReportSiteActivity(
                totalSignals: 1,
                personSignals: 1,
                vehicleSignals: 0,
                knownIdentitySignals: 0,
                flaggedIdentitySignals: 0,
                unknownSignals: 1,
                longPresenceSignals: 0,
                guardInteractionSignals: 0,
                executiveSummary: 'Quiet shift.',
                headline: 'Baseline stable.',
                summaryLine: 'Signals 1 • People 1 • Unknown 1',
              ),
            ),
          ],
          initialScopedEventIds: const [
            'ACTIVITY-1',
            'ACTIVITY-2',
            'ACTIVITY-3',
          ],
          initialSelectedEventId: 'ACTIVITY-3',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey('events-activity-scope-banner'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Activity investigation active for 3 linked CCTV signals • SITE-SANDTON.',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Signals 3 • People 3 • Unknown 3 • Long presence 1 • Guard interactions 2 • Flagged IDs 1',
        skipOffstage: false,
      ),
      findsWidgets,
    );
    expect(
      find.textContaining(
        'Flagged: Unknown person flagged near gate-cam',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Long presence: Unknown person remained near gate-cam for 3h 30m',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Guard note: Guard interaction observed near gate-cam',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Review refs: ACTIVITY-1, ACTIVITY-3',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('ACTIVITY RISING • 2d', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Current pressure 6 • Baseline 1.0 • Unknown, flagged, or guard-linked activity is above the recent baseline.',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '2026-03-17 • Signals 3 • People 3 • Unknown 3 • Long presence 1 • Guard interactions 2 • Flagged IDs 1',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '2026-03-16 • Signals 1 • People 1 • Unknown 1',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('events-activity-casefile-json-action'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('events-activity-casefile-csv-action'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    final copyJsonAction = tester.widget<InkWell>(
      find.byKey(
        const ValueKey('events-activity-casefile-json-action'),
        skipOffstage: false,
      ),
    );
    copyJsonAction.onTap!();
    await tester.pump();
    expect(copiedClipboardPayload, contains('"activityCaseFile"'));
    expect(copiedClipboardPayload, contains('"reportDate": "2026-03-17"'));
    expect(copiedClipboardPayload, contains('"liveReportDate": "2026-03-17"'));
    expect(copiedClipboardPayload, contains('"siteId": "SITE-SANDTON"'));
    expect(copiedClipboardPayload, contains('"reviewRefs": ['));
    expect(copiedClipboardPayload, contains('"ACTIVITY-1"'));
    expect(copiedClipboardPayload, contains('"reviewShortcuts"'));
    expect(
      copiedClipboardPayload,
      contains('"currentShiftReviewCommand": "/activityreview 2026-03-17"'),
    );
    expect(
      copiedClipboardPayload,
      contains(
        '"currentShiftCaseFileCommand": "/activitycase json 2026-03-17"',
      ),
    );
    expect(
      copiedClipboardPayload,
      contains('"previousShiftReviewCommand": "/activityreview 2026-03-16"'),
    );
    expect(
      copiedClipboardPayload,
      contains(
        '"previousShiftCaseFileCommand": "/activitycase json 2026-03-16"',
      ),
    );
    expect(copiedClipboardPayload, contains('"history"'));
    expect(
      copiedClipboardPayload,
      contains('"reviewCommand": "/activityreview 2026-03-16"'),
    );
    expect(
      copiedClipboardPayload,
      contains('"caseFileCommand": "/activitycase json 2026-03-16"'),
    );

    final copyCsvAction = tester.widget<InkWell>(
      find.byKey(
        const ValueKey('events-activity-casefile-csv-action'),
        skipOffstage: false,
      ),
    );
    copyCsvAction.onTap!();
    await tester.pump();
    expect(copiedClipboardPayload, contains('metric,value'));
    expect(copiedClipboardPayload, contains('report_date,2026-03-17'));
    expect(copiedClipboardPayload, contains('live_report_date,2026-03-17'));
    expect(copiedClipboardPayload, contains('site_id,SITE-SANDTON'));
    expect(
      copiedClipboardPayload,
      contains('review_refs,"ACTIVITY-1, ACTIVITY-3"'),
    );
    expect(
      copiedClipboardPayload,
      contains('current_review_command,/activityreview 2026-03-17'),
    );
    expect(
      copiedClipboardPayload,
      contains('current_case_file_command,/activitycase json 2026-03-17'),
    );
    expect(
      copiedClipboardPayload,
      contains('previous_review_command,/activityreview 2026-03-16'),
    );
    expect(
      copiedClipboardPayload,
      contains('previous_case_file_command,/activitycase json 2026-03-16'),
    );
    expect(copiedClipboardPayload, contains('history_1_date,2026-03-17'));
    expect(
      copiedClipboardPayload,
      contains('history_1_review_command,/activityreview 2026-03-17'),
    );
    expect(
      copiedClipboardPayload,
      contains('history_1_case_file_command,/activitycase json 2026-03-17'),
    );
    expect(find.textContaining('Visit-scoped review active for'), findsNothing);
    expect(find.text('Unrelated perimeter movement'), findsNothing);
  });

  testWidgets('events review shows dedicated shadow investigation banner', (
    tester,
  ) async {
    String? copiedClipboardPayload;
    var governanceOpened = false;
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

    await tester.pumpWidget(
      MaterialApp(
        home: EventsReviewPage(
          events: <DispatchEvent>[
            IntelligenceReceived(
              eventId: 'SHADOW-NEWS-1',
              sequence: 1,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 17, 0, 20),
              intelligenceId: 'SHADOW-NEWS-INTEL-1',
              provider: 'newsdesk',
              sourceType: 'news',
              externalId: 'shadow-news-1',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-ALPHA',
              headline: 'Contractors moved floor to floor in office park',
              summary:
                  'Suspects posed as maintenance contractors before moving across restricted office zones.',
              riskScore: 91,
              canonicalHash: 'shadow-news-hash-1',
            ),
            IntelligenceReceived(
              eventId: 'SHADOW-1',
              sequence: 2,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 17, 1, 0),
              intelligenceId: 'SHADOW-INTEL-1',
              provider: 'frigate',
              sourceType: 'cctv',
              externalId: 'shadow-1',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-ALPHA',
              headline: 'Unplanned contractor roaming',
              summary:
                  'Maintenance-like subject moved across restricted office doors.',
              riskScore: 92,
              canonicalHash: 'shadow-hash-1',
            ),
          ],
          sceneReviewByIntelligenceId: {
            'SHADOW-INTEL-1': MonitoringSceneReviewRecord(
              intelligenceId: 'SHADOW-INTEL-1',
              sourceLabel: 'openai:gpt-5.4-mini',
              postureLabel: 'service impersonation and roaming concern',
              decisionLabel: 'Escalation Candidate',
              decisionSummary:
                  'Likely spoofed service access with abnormal roaming.',
              summary:
                  'Likely maintenance impersonation moving across office zones.',
              reviewedAtUtc: DateTime.utc(2026, 3, 17, 1, 2),
            ),
          },
          initialScopedEventIds: const ['SHADOW-1'],
          initialSelectedEventId: 'SHADOW-1',
          initialScopedMode: 'shadow',
          morningSovereignReportHistory: [
            SovereignReport(
              date: '2026-03-16',
              generatedAtUtc: DateTime.utc(2026, 3, 16, 6, 0),
              shiftWindowStartUtc: DateTime.utc(2026, 3, 15, 22, 0),
              shiftWindowEndUtc: DateTime.utc(2026, 3, 16, 6, 0),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 0,
                hashVerified: true,
                integrityScore: 1,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 0,
                humanOverrides: 0,
                overrideReasons: <String, int>{},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 1,
                driftDetected: 0,
                avgMatchScore: 0.91,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
            ),
            SovereignReport(
              date: '2026-03-15',
              generatedAtUtc: DateTime.utc(2026, 3, 15, 6, 0),
              shiftWindowStartUtc: DateTime.utc(2026, 3, 14, 22, 0),
              shiftWindowEndUtc: DateTime.utc(2026, 3, 15, 6, 0),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 0,
                hashVerified: true,
                integrityScore: 1,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 0,
                humanOverrides: 0,
                overrideReasons: <String, int>{},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 1,
                driftDetected: 0,
                avgMatchScore: 0.88,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
            ),
          ],
          currentMorningSovereignReportDate: '2026-03-18',
          onOpenGovernance: () {
            governanceOpened = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey('events-shadow-scope-banner'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Shadow MO investigation active for 1 linked signal',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(find.textContaining('SITE-ALPHA'), findsWidgets);
    expect(
      find.textContaining(
        'Viewing command-targeted shift 2026-03-17 instead of live oversight 2026-03-18.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('RISING • 3d'), findsOneWidget);
    expect(
      find.textContaining(
        'Current matches 2 • Baseline 0.0 • Shadow-MO match pressure is increasing against recent shifts.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Contractors moved floor to floor in office park'),
      findsWidgets,
    );
    expect(find.textContaining('Review refs: SHADOW-INTEL-1'), findsOneWidget);

    final copyJsonAction = tester.widget<InkWell>(
      find.byKey(
        const ValueKey('events-shadow-casefile-json-action'),
        skipOffstage: false,
      ),
    );
    copyJsonAction.onTap!();
    await tester.pump();
    expect(copiedClipboardPayload, contains('"shadowMoCaseFile"'));
    expect(copiedClipboardPayload, contains('"reportDate": "2026-03-17"'));
    expect(copiedClipboardPayload, contains('"liveReportDate": "2026-03-18"'));
    expect(copiedClipboardPayload, contains('"reviewShortcuts"'));
    expect(
      copiedClipboardPayload,
      contains('"currentShiftReviewCommand": "/shadowreview 2026-03-17"'),
    );
    expect(
      copiedClipboardPayload,
      contains('"currentShiftCaseFileCommand": "/shadowcase json 2026-03-17"'),
    );
    expect(copiedClipboardPayload, contains('"reviewRefs": ['));
    expect(copiedClipboardPayload, contains('"siteId": "SITE-ALPHA"'));
    expect(
      copiedClipboardPayload,
      contains('"historyHeadline": "RISING • 3d"'),
    );
    expect(
      copiedClipboardPayload,
      contains(
        '"historySummary": "Current matches 2 • Baseline 0.0 • Shadow-MO match pressure is increasing against recent shifts."',
      ),
    );
    expect(copiedClipboardPayload, contains('"history": {'));
    expect(copiedClipboardPayload, contains('"date": "2026-03-17"'));

    final copyCsvAction = tester.widget<InkWell>(
      find.byKey(
        const ValueKey('events-shadow-casefile-csv-action'),
        skipOffstage: false,
      ),
    );
    copyCsvAction.onTap!();
    await tester.pump();
    expect(copiedClipboardPayload, contains('metric,value'));
    expect(copiedClipboardPayload, contains('report_date,2026-03-17'));
    expect(copiedClipboardPayload, contains('live_report_date,2026-03-18'));
    expect(
      copiedClipboardPayload,
      contains('current_review_command,/shadowreview 2026-03-17'),
    );
    expect(
      copiedClipboardPayload,
      contains('current_case_file_command,/shadowcase json 2026-03-17'),
    );
    expect(copiedClipboardPayload, contains('history_headline,"RISING • 3d"'));
    expect(
      copiedClipboardPayload,
      contains(
        'history_summary,"Current matches 2 • Baseline 0.0 • Shadow-MO match pressure is increasing against recent shifts."',
      ),
    );
    expect(copiedClipboardPayload, contains('history_1_date,2026-03-17'));
    expect(copiedClipboardPayload, contains('history_1_match_count,2'));

    final openGovernanceAction = tester.widget<InkWell>(
      find.byKey(
        const ValueKey('events-shadow-open-governance-action'),
        skipOffstage: false,
      ),
    );
    openGovernanceAction.onTap!();
    await tester.pump();
    expect(governanceOpened, isTrue);
  });

  testWidgets('events review shows dedicated readiness investigation banner', (
    tester,
  ) async {
    String? copiedClipboardPayload;
    var governanceOpened = false;
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

    await tester.pumpWidget(
      MaterialApp(
        home: EventsReviewPage(
          events: <DispatchEvent>[
            IntelligenceReceived(
              eventId: 'READY-1',
              sequence: 2,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 17, 1, 0),
              intelligenceId: 'READY-INTEL-1',
              provider: 'frigate',
              sourceType: 'cctv',
              externalId: 'ready-1',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-ALPHA',
              headline: 'Perimeter pressure building',
              summary: 'Repeated movement detected near the east wall.',
              riskScore: 93,
              canonicalHash: 'hash-ready-1',
            ),
            IntelligenceReceived(
              eventId: 'READY-2',
              sequence: 1,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 17, 1, 5),
              intelligenceId: 'READY-INTEL-2',
              provider: 'frigate',
              sourceType: 'cctv',
              externalId: 'ready-2',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-BRAVO',
              headline: 'Boundary movement repeated',
              summary: 'Linked activity detected at sibling site.',
              riskScore: 88,
              canonicalHash: 'hash-ready-2',
            ),
          ],
          sceneReviewByIntelligenceId: {
            'READY-INTEL-1': MonitoringSceneReviewRecord(
              intelligenceId: 'READY-INTEL-1',
              sourceLabel: 'openai:gpt-5.4-mini',
              postureLabel: 'boundary escalation',
              decisionLabel: 'Escalation Candidate',
              decisionSummary: 'Escalated due to repeat boundary pressure.',
              summary: 'Repeated movement near the east wall.',
              reviewedAtUtc: DateTime.utc(2026, 3, 17, 1, 2),
            ),
            'READY-INTEL-2': MonitoringSceneReviewRecord(
              intelligenceId: 'READY-INTEL-2',
              sourceLabel: 'openai:gpt-5.4-mini',
              postureLabel: 'boundary repeat pressure',
              decisionLabel: 'Repeat Watch',
              decisionSummary:
                  'Repeat pressure is spreading across the region.',
              summary: 'Sibling site movement linked to the same corridor.',
              reviewedAtUtc: DateTime.utc(2026, 3, 17, 1, 6),
            ),
          },
          initialScopedEventIds: const ['READY-1', 'READY-2'],
          initialSelectedEventId: 'READY-1',
          initialScopedMode: 'readiness',
          currentMorningSovereignReportDate: '2026-03-18',
          onOpenGovernance: () {
            governanceOpened = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey('events-readiness-scope-banner'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Global readiness investigation active for 2 linked signals',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Critical 1', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining('region REGION-GAUTENG', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining('site SITE-ALPHA', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Viewing command-targeted shift 2026-03-17 instead of live oversight 2026-03-18.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Postural echo: Echo 1 • target SITE-BRAVO'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Top intent: PREPOSITION RESPONSE'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Review refs: READY-INTEL-1, READY-INTEL-2'),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('events-readiness-casefile-json-action'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('events-readiness-casefile-csv-action'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );

    final copyJsonAction = tester.widget<InkWell>(
      find.byKey(
        const ValueKey('events-readiness-casefile-json-action'),
        skipOffstage: false,
      ),
    );
    copyJsonAction.onTap!();
    await tester.pump();
    expect(copiedClipboardPayload, contains('"readinessCaseFile"'));
    expect(copiedClipboardPayload, contains('"reportDate": "2026-03-17"'));
    expect(copiedClipboardPayload, contains('"liveReportDate": "2026-03-18"'));
    expect(
      copiedClipboardPayload,
      contains('"leadRegionId": "REGION-GAUTENG"'),
    );
    expect(copiedClipboardPayload, contains('"leadSiteId": "SITE-ALPHA"'));
    expect(copiedClipboardPayload, contains('"hazardSummary": ""'));
    expect(
      copiedClipboardPayload,
      contains(
        '"focusSummary": "Viewing command-targeted shift 2026-03-17 instead of live oversight 2026-03-18."',
      ),
    );
    expect(copiedClipboardPayload, contains('"reviewRefs": ['));
    expect(copiedClipboardPayload, contains('"reviewShortcuts"'));
    expect(
      copiedClipboardPayload,
      contains('"currentShiftReviewCommand": "/readinessreview 2026-03-17"'),
    );
    expect(
      copiedClipboardPayload,
      contains(
        '"currentShiftCaseFileCommand": "/readinesscase json 2026-03-17"',
      ),
    );
    expect(
      copiedClipboardPayload,
      contains('"previousShiftReviewCommand": "/readinessreview 2026-03-18"'),
    );
    expect(
      copiedClipboardPayload,
      contains(
        '"previousShiftCaseFileCommand": "/readinesscase json 2026-03-18"',
      ),
    );

    final copyCsvAction = tester.widget<InkWell>(
      find.byKey(
        const ValueKey('events-readiness-casefile-csv-action'),
        skipOffstage: false,
      ),
    );
    copyCsvAction.onTap!();
    await tester.pump();
    expect(copiedClipboardPayload, contains('metric,value'));
    expect(copiedClipboardPayload, contains('lead_region_id,REGION-GAUTENG'));
    expect(copiedClipboardPayload, contains('lead_site_id,SITE-ALPHA'));
    expect(
      copiedClipboardPayload,
      contains('focus_state,historical_command_target'),
    );
    expect(copiedClipboardPayload, contains('hazard_summary,""'));
    expect(copiedClipboardPayload, contains('historical_focus,true'));
    expect(
      copiedClipboardPayload,
      contains(
        'focus_summary,"Viewing command-targeted shift 2026-03-17 instead of live oversight 2026-03-18."',
      ),
    );
    expect(
      copiedClipboardPayload,
      contains('review_refs,"READY-INTEL-1, READY-INTEL-2"'),
    );
    expect(
      copiedClipboardPayload,
      contains('current_review_command,/readinessreview 2026-03-17'),
    );
    expect(
      copiedClipboardPayload,
      contains('current_case_file_command,/readinesscase json 2026-03-17'),
    );
    expect(
      copiedClipboardPayload,
      contains('previous_review_command,/readinessreview 2026-03-18'),
    );
    expect(
      copiedClipboardPayload,
      contains('previous_case_file_command,/readinesscase json 2026-03-18'),
    );

    final openGovernanceAction = tester.widget<InkWell>(
      find.byKey(
        const ValueKey('events-readiness-open-governance-action'),
        skipOffstage: false,
      ),
    );
    openGovernanceAction.onTap!();
    await tester.pump();
    expect(governanceOpened, isTrue);
  });

  testWidgets('events review shows dedicated synthetic investigation banner', (
    tester,
  ) async {
    String? copiedClipboardPayload;
    var governanceOpened = false;
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

    await tester.pumpWidget(
      MaterialApp(
        home: EventsReviewPage(
          events: <DispatchEvent>[
            IntelligenceReceived(
              eventId: 'SYN-1',
              sequence: 2,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 17, 1, 0),
              intelligenceId: 'SYN-INTEL-1',
              provider: 'frigate',
              sourceType: 'cctv',
              externalId: 'syn-1',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-ALPHA',
              headline: 'Perimeter pressure building',
              summary: 'Repeated movement detected near the east wall.',
              riskScore: 93,
              canonicalHash: 'hash-syn-1',
            ),
            IntelligenceReceived(
              eventId: 'SYN-2',
              sequence: 1,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 17, 1, 5),
              intelligenceId: 'SYN-INTEL-2',
              provider: 'frigate',
              sourceType: 'cctv',
              externalId: 'syn-2',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-BRAVO',
              headline: 'Boundary movement repeated',
              summary: 'Linked activity detected at sibling site.',
              riskScore: 88,
              canonicalHash: 'hash-syn-2',
            ),
          ],
          sceneReviewByIntelligenceId: {
            'SYN-INTEL-1': MonitoringSceneReviewRecord(
              intelligenceId: 'SYN-INTEL-1',
              sourceLabel: 'openai:gpt-5.4-mini',
              postureLabel: 'boundary escalation',
              decisionLabel: 'Escalation Candidate',
              decisionSummary: 'Escalated due to repeat boundary pressure.',
              summary: 'Repeated movement near the east wall.',
              reviewedAtUtc: DateTime.utc(2026, 3, 17, 1, 2),
            ),
            'SYN-INTEL-2': MonitoringSceneReviewRecord(
              intelligenceId: 'SYN-INTEL-2',
              sourceLabel: 'openai:gpt-5.4-mini',
              postureLabel: 'boundary repeat pressure',
              decisionLabel: 'Repeat Watch',
              decisionSummary:
                  'Repeat pressure is spreading across the region.',
              summary: 'Sibling site movement linked to the same corridor.',
              reviewedAtUtc: DateTime.utc(2026, 3, 17, 1, 6),
            ),
          },
          initialScopedEventIds: const ['SYN-1', 'SYN-2'],
          initialSelectedEventId: 'SYN-1',
          initialScopedMode: 'synthetic',
          morningSovereignReportHistory: [
            SovereignReport(
              date: '2026-03-17',
              generatedAtUtc: DateTime.utc(2026, 3, 17, 6, 0),
              shiftWindowStartUtc: DateTime.utc(2026, 3, 16, 22, 0),
              shiftWindowEndUtc: DateTime.utc(2026, 3, 17, 6, 0),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 10,
                hashVerified: true,
                integrityScore: 100,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 1,
                humanOverrides: 0,
                overrideReasons: <String, int>{},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 2,
                driftDetected: 0,
                avgMatchScore: 100,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
            ),
            SovereignReport(
              date: '2026-03-16',
              generatedAtUtc: DateTime.utc(2026, 3, 16, 6, 0),
              shiftWindowStartUtc: DateTime.utc(2026, 3, 15, 22, 0),
              shiftWindowEndUtc: DateTime.utc(2026, 3, 16, 6, 0),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 6,
                hashVerified: true,
                integrityScore: 100,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 1,
                humanOverrides: 0,
                overrideReasons: <String, int>{},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 2,
                driftDetected: 0,
                avgMatchScore: 100,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
            ),
          ],
          currentMorningSovereignReportDate: '2026-03-18',
          onOpenGovernance: () {
            governanceOpened = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey('events-synthetic-scope-banner'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Synthetic war-room investigation active for 2 linked signals',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Plans 2 • Policy 1 • region REGION-GAUTENG'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Viewing command-targeted shift 2026-03-17 instead of live oversight 2026-03-18.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Policy: earlier postural echo propagation into sibling sites',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Learning: Learned bias:'), findsOneWidget);
    expect(find.textContaining('Bias:'), findsOneWidget);
    expect(
      find.textContaining('Top intent: Replay the next-shift posture'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Review refs: SYN-INTEL-1, SYN-INTEL-2'),
      findsOneWidget,
    );
    expect(find.textContaining('RISING • 2d'), findsOneWidget);
    expect(
      find.textContaining('Current pressure 3 • Baseline 0.0'),
      findsOneWidget,
    );
    expect(
      find.textContaining('2026-03-17 • Plans 2 • region REGION-GAUTENG'),
      findsOneWidget,
    );
    expect(
      find.textContaining('2026-03-16 • No synthetic rehearsal triggered.'),
      findsOneWidget,
    );

    final copyJsonAction = tester.widget<InkWell>(
      find.byKey(
        const ValueKey('events-synthetic-casefile-json-action'),
        skipOffstage: false,
      ),
    );
    copyJsonAction.onTap!();
    await tester.pump();
    expect(copiedClipboardPayload, contains('"syntheticCaseFile"'));
    expect(copiedClipboardPayload, contains('"reportDate": "2026-03-17"'));
    expect(copiedClipboardPayload, contains('"liveReportDate": "2026-03-18"'));
    expect(copiedClipboardPayload, contains('"modeLabel": "POLICY SHIFT"'));
    expect(copiedClipboardPayload, contains('"historicalFocus": true'));
    expect(copiedClipboardPayload, contains('"hazardSummary": ""'));
    expect(copiedClipboardPayload, contains('"shadowLearningSummary": ""'));
    expect(copiedClipboardPayload, contains('"shadowMemorySummary": ""'));
    expect(copiedClipboardPayload, contains('"promotionSummary": ""'));
    expect(copiedClipboardPayload, contains('"learningSummary":'));
    expect(copiedClipboardPayload, contains('"learningMemorySummary":'));
    expect(copiedClipboardPayload, contains('"biasSummary":'));
    expect(
      copiedClipboardPayload,
      contains(
        '"policySummary": "earlier postural echo propagation into sibling sites"',
      ),
    );
    expect(copiedClipboardPayload, contains('"reviewShortcuts"'));
    expect(
      copiedClipboardPayload,
      contains('"currentShiftReviewCommand": "/syntheticreview 2026-03-17"'),
    );
    expect(
      copiedClipboardPayload,
      contains(
        '"currentShiftCaseFileCommand": "/syntheticcase json 2026-03-17"',
      ),
    );
    expect(
      copiedClipboardPayload,
      contains('"previousShiftReviewCommand": "/syntheticreview 2026-03-16"'),
    );
    expect(
      copiedClipboardPayload,
      contains(
        '"previousShiftCaseFileCommand": "/syntheticcase json 2026-03-16"',
      ),
    );
    expect(copiedClipboardPayload, contains('"history": {'));
    expect(copiedClipboardPayload, contains('"headline": "RISING • 2d"'));
    expect(copiedClipboardPayload, contains('"date": "2026-03-16"'));
    expect(
      copiedClipboardPayload,
      contains('"reviewCommand": "/syntheticreview 2026-03-16"'),
    );
    expect(
      copiedClipboardPayload,
      contains('"caseFileCommand": "/syntheticcase json 2026-03-16"'),
    );

    final copyCsvAction = tester.widget<InkWell>(
      find.byKey(
        const ValueKey('events-synthetic-casefile-csv-action'),
        skipOffstage: false,
      ),
    );
    copyCsvAction.onTap!();
    await tester.pump();
    expect(copiedClipboardPayload, contains('metric,value'));
    expect(copiedClipboardPayload, contains('report_date,2026-03-17'));
    expect(copiedClipboardPayload, contains('live_report_date,2026-03-18'));
    expect(
      copiedClipboardPayload,
      contains('focus_state,historical_command_target'),
    );
    expect(copiedClipboardPayload, contains('historical_focus,true'));
    expect(copiedClipboardPayload, contains('hazard_summary,""'));
    expect(copiedClipboardPayload, contains('learning_summary,"'));
    expect(copiedClipboardPayload, contains('learning_memory_summary,"'));
    expect(copiedClipboardPayload, contains('bias_summary,"'));
    expect(copiedClipboardPayload, contains('mode_label,"POLICY SHIFT"'));
    expect(
      copiedClipboardPayload,
      contains(
        'policy_summary,"earlier postural echo propagation into sibling sites"',
      ),
    );
    expect(copiedClipboardPayload, contains('history_headline,"RISING • 2d"'));
    expect(
      copiedClipboardPayload,
      contains('current_review_command,/syntheticreview 2026-03-17'),
    );
    expect(
      copiedClipboardPayload,
      contains('current_case_file_command,/syntheticcase json 2026-03-17'),
    );
    expect(
      copiedClipboardPayload,
      contains('previous_review_command,/syntheticreview 2026-03-16'),
    );
    expect(
      copiedClipboardPayload,
      contains('previous_case_file_command,/syntheticcase json 2026-03-16'),
    );
    expect(copiedClipboardPayload, contains('history_1_date,2026-03-17'));
    expect(
      copiedClipboardPayload,
      contains('history_1_review_command,/syntheticreview 2026-03-17'),
    );
    expect(
      copiedClipboardPayload,
      contains('history_1_case_file_command,/syntheticcase json 2026-03-17'),
    );
    expect(copiedClipboardPayload, contains('history_1_bias_summary,"'));
    expect(copiedClipboardPayload, contains('history_2_date,2026-03-16'));
    expect(
      copiedClipboardPayload,
      contains('history_2_review_command,/syntheticreview 2026-03-16'),
    );
    expect(
      copiedClipboardPayload,
      contains('history_2_case_file_command,/syntheticcase json 2026-03-16'),
    );

    final openGovernanceAction = tester.widget<InkWell>(
      find.byKey(
        const ValueKey('events-synthetic-open-governance-action'),
        skipOffstage: false,
      ),
    );
    openGovernanceAction.onTap!();
    await tester.pump();
    expect(governanceOpened, isTrue);
  });

  testWidgets('events review shows dedicated tomorrow posture investigation banner', (
    tester,
  ) async {
    String? copiedClipboardPayload;
    var governanceOpened = false;
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

    await tester.pumpWidget(
      MaterialApp(
        home: EventsReviewPage(
          events: <DispatchEvent>[
            IntelligenceReceived(
              eventId: 'TOM-1',
              sequence: 2,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 17, 1, 0),
              intelligenceId: 'TOM-INTEL-1',
              provider: 'hikvision',
              sourceType: 'dvr',
              externalId: 'tom-1',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-ALPHA',
              headline: 'Fire alarm visible',
              summary: 'Smoke visible inside the plant room.',
              riskScore: 96,
              canonicalHash: 'hash-tom-1',
            ),
            IntelligenceReceived(
              eventId: 'TOM-2',
              sequence: 1,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 17, 1, 5),
              intelligenceId: 'TOM-INTEL-2',
              provider: 'hikvision',
              sourceType: 'dvr',
              externalId: 'tom-2',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-ALPHA',
              headline: 'Smoke plume thickening',
              summary: 'Secondary smoke signature detected.',
              riskScore: 91,
              canonicalHash: 'hash-tom-2',
            ),
            IntelligenceReceived(
              eventId: 'TOM-PREV-1',
              sequence: 1,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 16, 1, 10),
              intelligenceId: 'TOM-PREV-INTEL-1',
              provider: 'hikvision',
              sourceType: 'dvr',
              externalId: 'tom-prev-1',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-ALPHA',
              headline: 'Earlier smoke signature',
              summary: 'Prior shift smoke evidence in the same room.',
              riskScore: 89,
              canonicalHash: 'hash-tom-prev-1',
            ),
          ],
          sceneReviewByIntelligenceId: {
            'TOM-INTEL-1': MonitoringSceneReviewRecord(
              intelligenceId: 'TOM-INTEL-1',
              sourceLabel: 'openai:gpt-5.4-mini',
              postureLabel: 'fire and smoke emergency',
              decisionLabel: 'Escalation Candidate',
              decisionSummary:
                  'Escalated because fire or smoke indicators were detected.',
              summary: 'Smoke plume visible inside the plant room.',
              reviewedAtUtc: DateTime.utc(2026, 3, 17, 1, 2),
            ),
            'TOM-INTEL-2': MonitoringSceneReviewRecord(
              intelligenceId: 'TOM-INTEL-2',
              sourceLabel: 'openai:gpt-5.4-mini',
              postureLabel: 'fire and smoke emergency',
              decisionLabel: 'Escalation Candidate',
              decisionSummary:
                  'Escalated because smoke pressure is increasing.',
              summary: 'Smoke signature is thickening on the same site.',
              reviewedAtUtc: DateTime.utc(2026, 3, 17, 1, 6),
            ),
            'TOM-PREV-INTEL-1': MonitoringSceneReviewRecord(
              intelligenceId: 'TOM-PREV-INTEL-1',
              sourceLabel: 'openai:gpt-5.4-mini',
              postureLabel: 'fire and smoke emergency',
              decisionLabel: 'Escalation Candidate',
              decisionSummary:
                  'Escalated because earlier fire indicators were detected.',
              summary: 'Previous shift smoke visible inside the plant room.',
              reviewedAtUtc: DateTime.utc(2026, 3, 16, 1, 12),
            ),
          },
          initialScopedEventIds: const ['TOM-1', 'TOM-2'],
          initialSelectedEventId: 'TOM-1',
          initialScopedMode: 'tomorrow',
          morningSovereignReportHistory: [
            SovereignReport(
              date: '2026-03-17',
              generatedAtUtc: DateTime.utc(2026, 3, 17, 6, 0),
              shiftWindowStartUtc: DateTime.utc(2026, 3, 16, 22, 0),
              shiftWindowEndUtc: DateTime.utc(2026, 3, 17, 6, 0),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 8,
                hashVerified: true,
                integrityScore: 100,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 1,
                humanOverrides: 0,
                overrideReasons: <String, int>{},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 1,
                driftDetected: 0,
                avgMatchScore: 100,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
            ),
            SovereignReport(
              date: '2026-03-16',
              generatedAtUtc: DateTime.utc(2026, 3, 16, 6, 0),
              shiftWindowStartUtc: DateTime.utc(2026, 3, 15, 22, 0),
              shiftWindowEndUtc: DateTime.utc(2026, 3, 16, 6, 0),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 6,
                hashVerified: true,
                integrityScore: 100,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 1,
                humanOverrides: 0,
                overrideReasons: <String, int>{},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 1,
                driftDetected: 0,
                avgMatchScore: 100,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
            ),
          ],
          currentMorningSovereignReportDate: '2026-03-18',
          onOpenGovernance: () {
            governanceOpened = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey('events-tomorrow-scope-banner'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Tomorrow posture investigation active for 2 linked signals',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'DRAFT NEXT-SHIFT FIRE READINESS • SITE-ALPHA • ADVANCE FIRE • x1',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Viewing command-targeted shift 2026-03-17 instead of live oversight 2026-03-18.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Prebuild next-shift fire readiness'),
      findsOneWidget,
    );
    expect(find.textContaining('Learning: ADVANCE FIRE'), findsOneWidget);
    expect(
      find.textContaining(
        'Memory: ADVANCE FIRE repeated across 2 linked shifts.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Hazard draft: fire playbook draft active'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Review refs: TOM-INTEL-1, TOM-INTEL-2'),
      findsOneWidget,
    );
    expect(find.textContaining('RISING • 2d'), findsOneWidget);
    expect(
      find.textContaining('Current drafts 1 • Baseline 0.0'),
      findsOneWidget,
    );
    expect(
      find.textContaining('2026-03-16 • No tomorrow-posture drafts triggered.'),
      findsOneWidget,
    );

    final copyJsonAction = tester.widget<InkWell>(
      find.byKey(
        const ValueKey('events-tomorrow-casefile-json-action'),
        skipOffstage: false,
      ),
    );
    copyJsonAction.onTap!();
    await tester.pump();
    expect(copiedClipboardPayload, contains('"tomorrowPostureCaseFile"'));
    expect(copiedClipboardPayload, contains('"reportDate": "2026-03-17"'));
    expect(copiedClipboardPayload, contains('"liveReportDate": "2026-03-18"'));
    expect(copiedClipboardPayload, contains('"draftCount": 1'));
    expect(
      copiedClipboardPayload,
      contains('"leadDraftActionType": "DRAFT NEXT-SHIFT FIRE READINESS"'),
    );
    expect(
      copiedClipboardPayload,
      contains('"learningSummary": "ADVANCE FIRE"'),
    );
    expect(
      copiedClipboardPayload,
      contains(
        '"learningMemorySummary": "Memory: ADVANCE FIRE repeated across 2 linked shifts."',
      ),
    );
    expect(
      copiedClipboardPayload,
      contains('"hazardSummary": "fire playbook draft active"'),
    );
    expect(copiedClipboardPayload, contains('"reviewShortcuts"'));
    expect(
      copiedClipboardPayload,
      contains('"currentShiftReviewCommand": "/tomorrowreview 2026-03-17"'),
    );
    expect(
      copiedClipboardPayload,
      contains(
        '"currentShiftCaseFileCommand": "/tomorrowcase json 2026-03-17"',
      ),
    );
    expect(
      copiedClipboardPayload,
      contains('"previousShiftReviewCommand": "/tomorrowreview 2026-03-16"'),
    );
    expect(
      copiedClipboardPayload,
      contains(
        '"previousShiftCaseFileCommand": "/tomorrowcase json 2026-03-16"',
      ),
    );
    expect(copiedClipboardPayload, contains('"history": {'));
    expect(
      copiedClipboardPayload,
      contains('"reviewCommand": "/tomorrowreview 2026-03-16"'),
    );
    expect(
      copiedClipboardPayload,
      contains('"caseFileCommand": "/tomorrowcase json 2026-03-16"'),
    );

    final copyCsvAction = tester.widget<InkWell>(
      find.byKey(
        const ValueKey('events-tomorrow-casefile-csv-action'),
        skipOffstage: false,
      ),
    );
    copyCsvAction.onTap!();
    await tester.pump();
    expect(copiedClipboardPayload, contains('metric,value'));
    expect(copiedClipboardPayload, contains('report_date,2026-03-17'));
    expect(copiedClipboardPayload, contains('live_report_date,2026-03-18'));
    expect(
      copiedClipboardPayload,
      contains('focus_state,historical_command_target'),
    );
    expect(copiedClipboardPayload, contains('historical_focus,true'));
    expect(copiedClipboardPayload, contains('draft_count,1'));
    expect(
      copiedClipboardPayload,
      contains('lead_draft_action_type,"DRAFT NEXT-SHIFT FIRE READINESS"'),
    );
    expect(copiedClipboardPayload, contains('learning_summary,"ADVANCE FIRE"'));
    expect(
      copiedClipboardPayload,
      contains(
        'learning_memory_summary,"Memory: ADVANCE FIRE repeated across 2 linked shifts."',
      ),
    );
    expect(
      copiedClipboardPayload,
      contains('hazard_summary,"fire playbook draft active"'),
    );
    expect(
      copiedClipboardPayload,
      contains('current_review_command,/tomorrowreview 2026-03-17'),
    );
    expect(
      copiedClipboardPayload,
      contains('current_case_file_command,/tomorrowcase json 2026-03-17'),
    );
    expect(
      copiedClipboardPayload,
      contains('previous_review_command,/tomorrowreview 2026-03-16'),
    );
    expect(
      copiedClipboardPayload,
      contains('previous_case_file_command,/tomorrowcase json 2026-03-16'),
    );
    expect(
      copiedClipboardPayload,
      contains('history_1_review_command,/tomorrowreview 2026-03-17'),
    );
    expect(
      copiedClipboardPayload,
      contains('history_1_case_file_command,/tomorrowcase json 2026-03-17'),
    );
    expect(
      copiedClipboardPayload,
      contains('history_2_review_command,/tomorrowreview 2026-03-16'),
    );
    expect(
      copiedClipboardPayload,
      contains('history_2_case_file_command,/tomorrowcase json 2026-03-16'),
    );

    final openGovernanceAction = tester.widget<InkWell>(
      find.byKey(
        const ValueKey('events-tomorrow-open-governance-action'),
        skipOffstage: false,
      ),
    );
    openGovernanceAction.onTap!();
    await tester.pump();
    expect(governanceOpened, isTrue);
  });

  testWidgets('events review prioritizes reviewed shadow evidence by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventsReviewPage(
          events: <DispatchEvent>[
            IntelligenceReceived(
              eventId: 'SHADOW-NEWS-1',
              sequence: 1,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 17, 0, 20),
              intelligenceId: 'SHADOW-NEWS-INTEL-1',
              provider: 'newsdesk',
              sourceType: 'news',
              externalId: 'shadow-news-1',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-ALPHA',
              headline: 'Contractors moved floor to floor in office park',
              summary:
                  'Suspects posed as maintenance contractors before moving across restricted office zones.',
              riskScore: 91,
              canonicalHash: 'shadow-news-hash-1',
            ),
            IntelligenceReceived(
              eventId: 'SHADOW-1',
              sequence: 2,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 17, 1, 0),
              intelligenceId: 'SHADOW-INTEL-1',
              provider: 'frigate',
              sourceType: 'cctv',
              externalId: 'shadow-1',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-ALPHA',
              headline: 'Unplanned contractor roaming',
              summary:
                  'Maintenance-like subject moved across restricted office doors.',
              riskScore: 92,
              canonicalHash: 'shadow-hash-1',
            ),
          ],
          sceneReviewByIntelligenceId: {
            'SHADOW-INTEL-1': MonitoringSceneReviewRecord(
              intelligenceId: 'SHADOW-INTEL-1',
              sourceLabel: 'openai:gpt-5.4-mini',
              postureLabel: 'service impersonation and roaming concern',
              decisionLabel: 'Escalation Candidate',
              decisionSummary:
                  'Likely spoofed service access with abnormal roaming.',
              summary:
                  'Likely maintenance impersonation moving across office zones.',
              reviewedAtUtc: DateTime.utc(2026, 3, 17, 1, 2),
            ),
          },
          initialScopedEventIds: const ['SHADOW-NEWS-1', 'SHADOW-1'],
          initialScopedMode: 'shadow',
          currentMorningSovereignReportDate: '2026-03-18',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('events-detail-SHADOW-1')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('events-detail-SHADOW-1')),
      findsOneWidget,
    );
    expect(find.text('SCENE REVIEW'), findsOneWidget);
    expect(
      find.text('Likely maintenance impersonation moving across office zones.'),
      findsOneWidget,
    );
  });
}
