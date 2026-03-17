import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/morning_sovereign_report_service.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/partner_dispatch_status_declared.dart';
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
                    partnerLabel: 'PARTNER • Alpha',
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
                    partnerLabel: 'PARTNER • Alpha',
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

  testWidgets('live operations classifies fire scenes as emergency incidents', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          historicalSyntheticLearningLabels: const ['ADVANCE FIRE'],
          events: [
            DecisionCreated(
              eventId: 'decision-fire',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 3)),
              dispatchId: 'D-2001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-FIRE',
            ),
            IntelligenceReceived(
              eventId: 'intel-fire',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              intelligenceId: 'INT-FIRE',
              provider: 'hikvision_dvr_monitor_only',
              sourceType: 'dvr',
              externalId: 'evt-fire',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-FIRE',
              cameraId: 'generator-room-cam',
              objectLabel: 'smoke',
              objectConfidence: 0.94,
              headline: 'HIKVISION FIRE ALERT',
              summary: 'Smoke visible in the generator room.',
              riskScore: 74,
              snapshotUrl: 'https://edge.example.com/fire.jpg',
              canonicalHash: 'hash-fire',
            ),
          ],
          sceneReviewByIntelligenceId: {
            'INT-FIRE': MonitoringSceneReviewRecord(
              intelligenceId: 'INT-FIRE',
              sourceLabel: 'openai:gpt-5.4-mini',
              postureLabel: 'fire and smoke emergency',
              decisionLabel: 'Escalation Candidate',
              decisionSummary:
                  'Escalated for urgent review because fire or smoke indicators were detected.',
              summary: 'Smoke plume visible inside the generator room.',
              reviewedAtUtc: now.subtract(const Duration(minutes: 1)),
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fire / Smoke Emergency'), findsWidgets);
    expect(find.text('Next-Shift Drafts'), findsOneWidget);
    expect(find.text('DRAFT NEXT-SHIFT FIRE READINESS'), findsOneWidget);
    expect(
      find.textContaining('Prebuild next-shift fire readiness'),
      findsOneWidget,
    );
    expect(find.text('P1'), findsWidgets);
    expect(find.textContaining('fire and smoke emergency'), findsOneWidget);
    expect(find.text('FIRE RESPONSE'), findsOneWidget);
    expect(find.text('CLIENT SAFETY CALL'), findsOneWidget);
    expect(find.text('FIRE VERIFY'), findsOneWidget);
    expect(
      find.textContaining(
        'Dispatching fire response, holding emergency notification, and staging occupant welfare checks.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Fire emergency dispatch staged • welfare check hot'),
      findsOneWidget,
    );
  });

  testWidgets('live operations shows shadow readiness bias for repeated MO pressure', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          historicalShadowMoLabels: const ['HARDEN ACCESS'],
          events: [
            DecisionCreated(
              eventId: 'decision-shadow',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 3)),
              dispatchId: 'D-3001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-OFFICE',
            ),
            IntelligenceReceived(
              eventId: 'intel-shadow-news',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              intelligenceId: 'INT-SHADOW-NEWS',
              provider: 'news_feed_monitor',
              sourceType: 'news',
              externalId: 'ext-shadow-news',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-OFFICE',
              cameraId: 'feed-news',
              objectLabel: 'person',
              objectConfidence: 0.70,
              headline: 'Contractors moved floor to floor in office park',
              summary:
                  'Suspects posed as maintenance contractors before moving across restricted office zones.',
              riskScore: 67,
              snapshotUrl: 'https://edge.example.com/shadow-news.jpg',
              canonicalHash: 'hash-shadow-news',
            ),
            IntelligenceReceived(
              eventId: 'intel-shadow-live',
              sequence: 3,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 1)),
              intelligenceId: 'INT-SHADOW-LIVE',
              provider: 'hikvision_dvr_monitor_only',
              sourceType: 'dvr',
              externalId: 'ext-shadow-live',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-OFFICE',
              cameraId: 'office-cam',
              objectLabel: 'person',
              objectConfidence: 0.95,
              headline: 'Maintenance contractor probing office doors',
              summary:
                  'Contractor-like person moved floor to floor and tried several restricted office doors.',
              riskScore: 86,
              snapshotUrl: 'https://edge.example.com/shadow-live.jpg',
              canonicalHash: 'hash-shadow-live',
            ),
          ],
          sceneReviewByIntelligenceId: {
            'INT-SHADOW-LIVE': MonitoringSceneReviewRecord(
              intelligenceId: 'INT-SHADOW-LIVE',
              sourceLabel: 'openai:gpt-5.4-mini',
              postureLabel: 'service impersonation and roaming concern',
              decisionLabel: 'Escalation Candidate',
              decisionSummary:
                  'Likely spoofed service access with abnormal roaming.',
              summary:
                  'Likely maintenance impersonation moving across office zones.',
              reviewedAtUtc: now,
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Next-Shift Drafts'), findsOneWidget);
    expect(find.text('DRAFT NEXT-SHIFT ACCESS HARDENING'), findsOneWidget);
    expect(find.text('Shadow'), findsOneWidget);
    expect(find.textContaining('HARDEN ACCESS'), findsWidgets);
    expect(find.text('Readiness bias'), findsOneWidget);
    expect(
      find.textContaining('earlier access hardening'),
      findsOneWidget,
    );
  });

  testWidgets(
    'live operations switches latest intel and ladder labels for DVR',
    (tester) async {
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
    },
  );

  testWidgets('live operations shows scene review alongside latest intel', (
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
              eventId: 'intel-2',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              intelligenceId: 'INT-2',
              provider: 'hikvision-dvr',
              sourceType: 'dvr',
              externalId: 'evt-2',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              headline: 'DVR BOUNDARY ALERT',
              summary: 'Motion detected at boundary line',
              riskScore: 92,
              canonicalHash: 'hash-2',
            ),
          ],
          videoOpsLabel: 'DVR',
          sceneReviewByIntelligenceId: {
            'INT-2': MonitoringSceneReviewRecord(
              intelligenceId: 'INT-2',
              sourceLabel: 'openai:gpt-4.1-mini',
              postureLabel: 'escalation candidate',
              decisionLabel: 'Escalation Candidate',
              decisionSummary:
                  'Escalated for urgent review because person activity was detected, the scene suggested boundary proximity, and confidence remained high.',
              summary: 'Person visible near the boundary line.',
              reviewedAtUtc: now.subtract(const Duration(minutes: 2)),
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scene Review'), findsOneWidget);
    expect(find.text('Review Detail'), findsOneWidget);
    expect(find.text('Scene Action'), findsOneWidget);
    expect(find.text('Action Detail'), findsOneWidget);
    expect(
      find.textContaining('openai:gpt-4.1-mini • escalation candidate'),
      findsOneWidget,
    );
    expect(find.text('Escalation Candidate'), findsOneWidget);
    expect(
      find.textContaining('Person visible near the boundary line.'),
      findsOneWidget,
    );
    expect(find.textContaining('Escalated for urgent review'), findsOneWidget);
  });

  testWidgets(
    'live operations shows shadow MO intelligence for matched incident context',
    (tester) async {
      final now = DateTime.now().toUtc();
      List<String>? openedEventIds;
      String? openedSelectedEventId;
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: [
              DecisionCreated(
                eventId: 'decision-shadow',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 3)),
                dispatchId: 'D-3001',
                clientId: 'CLIENT-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-OFFICE',
              ),
              IntelligenceReceived(
                eventId: 'evt-news',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(hours: 4)),
                intelligenceId: 'intel-news',
                provider: 'security_bulletin',
                sourceType: 'news',
                externalId: 'news-1',
                clientId: 'CLIENT-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-OFFICE',
                cameraId: 'feed-news',
                objectLabel: 'person',
                objectConfidence: 0.7,
                headline: 'Contractors moved floor to floor in office park',
                summary:
                    'Suspects posed as maintenance contractors, moved floor to floor through a business park, and tried several restricted office doors before stealing devices.',
                riskScore: 75,
                snapshotUrl: 'https://edge.example.com/news-office.jpg',
                canonicalHash: 'hash-news-office',
              ),
              IntelligenceReceived(
                eventId: 'evt-office',
                sequence: 3,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                intelligenceId: 'intel-office',
                provider: 'hikvision_dvr_monitor_only',
                sourceType: 'dvr',
                externalId: 'ext-office',
                clientId: 'CLIENT-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-OFFICE',
                cameraId: 'office-cam',
                objectLabel: 'person',
                objectConfidence: 0.95,
                headline: 'Maintenance contractor probing office doors',
                summary:
                    'Contractor-like person moved floor to floor and tried several restricted office doors.',
                riskScore: 86,
                snapshotUrl: 'https://edge.example.com/office.jpg',
                canonicalHash: 'hash-office',
              ),
            ],
            sceneReviewByIntelligenceId: {
              'intel-office': MonitoringSceneReviewRecord(
                intelligenceId: 'intel-office',
                sourceLabel: 'openai:gpt-5.4-mini',
                postureLabel: 'service impersonation and roaming concern',
                decisionLabel: 'Escalation Candidate',
                decisionSummary:
                    'Likely spoofed service access with abnormal roaming.',
                summary:
                    'Likely maintenance impersonation moving across office zones.',
                reviewedAtUtc: now.subtract(const Duration(minutes: 1)),
              ),
            },
            onOpenEventsForScope: (eventIds, selectedEventId) {
              openedEventIds = eventIds;
              openedSelectedEventId = selectedEventId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('live-mo-shadow-card-INC-D-3001')),
        findsOneWidget,
      );
      expect(find.text('Shadow MO Intelligence'), findsOneWidget);
      expect(
        find.textContaining('Contractors moved floor to floor in office park'),
        findsOneWidget,
      );
      expect(find.text('mo_shadow'), findsOneWidget);

      final dossierButton = find.byKey(
        const ValueKey('live-mo-shadow-open-dossier-INC-D-3001'),
      );
      await tester.ensureVisible(dossierButton);
      await tester.tap(dossierButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('live-mo-shadow-dialog-INC-D-3001')),
        findsOneWidget,
      );
      expect(find.text('SHADOW MO DOSSIER'), findsOneWidget);
      expect(
        find.textContaining('Actions RAISE READINESS • PREPOSITION RESPONSE'),
        findsWidgets,
      );

      await tester.tap(find.text('OPEN EVIDENCE').last);
      await tester.pumpAndSettle();

      expect(openedEventIds, equals(const ['evt-office']));
      expect(openedSelectedEventId, 'evt-office');
    },
  );

  testWidgets('live operations shows partner progression in incident context', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
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
                    partnerLabel: 'PARTNER • Alpha',
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
                    partnerLabel: 'PARTNER • Alpha',
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
          events: [
            DecisionCreated(
              eventId: 'decision-1',
              sequence: 4,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 4)),
              dispatchId: 'D-1001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            PartnerDispatchStatusDeclared(
              eventId: 'partner-1',
              sequence: 3,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 3)),
              dispatchId: 'D-1001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              partnerLabel: 'PARTNER • Alpha',
              actorLabel: '@partner.alpha',
              status: PartnerDispatchStatus.accepted,
              sourceChannel: 'telegram',
              sourceMessageKey: 'tg-partner-1',
            ),
            PartnerDispatchStatusDeclared(
              eventId: 'partner-2',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              dispatchId: 'D-1001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              partnerLabel: 'PARTNER • Alpha',
              actorLabel: '@partner.alpha',
              status: PartnerDispatchStatus.onSite,
              sourceChannel: 'telegram',
              sourceMessageKey: 'tg-partner-2',
            ),
            PartnerDispatchStatusDeclared(
              eventId: 'partner-3',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 1)),
              dispatchId: 'D-1001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              partnerLabel: 'PARTNER • Alpha',
              actorLabel: '@partner.alpha',
              status: PartnerDispatchStatus.allClear,
              sourceChannel: 'telegram',
              sourceMessageKey: 'tg-partner-3',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('live-partner-progress-card-INC-D-1001')),
      findsOneWidget,
    );
    expect(find.text('Partner Progression'), findsOneWidget);
    expect(
      find.textContaining('PARTNER • Alpha • Latest ALL CLEAR'),
      findsOneWidget,
    );
    expect(find.text('Dispatch D-1001'), findsOneWidget);
    expect(find.text('3 declarations'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('live-partner-progress-INC-D-1001-accepted')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('live-partner-progress-INC-D-1001-onSite')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('live-partner-progress-INC-D-1001-allClear')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('live-partner-progress-INC-D-1001-cancelled')),
      findsOneWidget,
    );
    expect(find.textContaining('CANCEL Pending'), findsOneWidget);
    expect(find.text('7D IMPROVING • 2d'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('live-partner-trend-reason-INC-D-1001')),
      findsOneWidget,
    );
    expect(
      find.text('Acceptance timing improved against the prior 7-day average.'),
      findsOneWidget,
    );
  });

  testWidgets('live operations shows suppressed scene review queue for active site', (
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
              occurredAt: now.subtract(const Duration(minutes: 4)),
              dispatchId: 'D-1001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            IntelligenceReceived(
              eventId: 'intel-suppressed',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 3)),
              intelligenceId: 'INT-SUPPRESSED-1',
              provider: 'hikvision-dvr',
              sourceType: 'dvr',
              externalId: 'evt-suppressed',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              cameraId: 'Camera 2',
              zone: 'north_gate',
              headline: 'DVR VEHICLE PASS',
              summary: 'Vehicle passed through the north gate approach lane.',
              riskScore: 41,
              canonicalHash: 'hash-suppressed',
            ),
            IntelligenceReceived(
              eventId: 'intel-latest',
              sequence: 3,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              intelligenceId: 'INT-LATEST-1',
              provider: 'hikvision-dvr',
              sourceType: 'dvr',
              externalId: 'evt-latest',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              headline: 'DVR BOUNDARY ALERT',
              summary: 'Motion detected at boundary line',
              riskScore: 92,
              canonicalHash: 'hash-latest',
            ),
          ],
          videoOpsLabel: 'DVR',
          sceneReviewByIntelligenceId: {
            'INT-SUPPRESSED-1': MonitoringSceneReviewRecord(
              intelligenceId: 'INT-SUPPRESSED-1',
              sourceLabel: 'openai:gpt-4.1-mini',
              postureLabel: 'reviewed',
              decisionLabel: 'Suppressed',
              decisionSummary:
                  'Suppressed because the vehicle activity remained below the client notification threshold.',
              summary: 'Vehicle remained below escalation threshold.',
              reviewedAtUtc: now.subtract(const Duration(minutes: 3)),
            ),
            'INT-LATEST-1': MonitoringSceneReviewRecord(
              intelligenceId: 'INT-LATEST-1',
              sourceLabel: 'openai:gpt-4.1-mini',
              postureLabel: 'escalation candidate',
              decisionLabel: 'Escalation Candidate',
              decisionSummary:
                  'Escalated for urgent review because person activity was detected near the boundary line.',
              summary: 'Person visible near the boundary line.',
              reviewedAtUtc: now.subtract(const Duration(minutes: 2)),
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Suppressed DVR Reviews'), findsOneWidget);
    expect(find.text('1 internal'), findsOneWidget);
    expect(find.text('DVR VEHICLE PASS'), findsOneWidget);
    expect(
      find.textContaining(
        'Suppressed because the vehicle activity remained below the client notification threshold.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Scene review: Vehicle remained below escalation threshold.'),
      findsOneWidget,
    );
    expect(find.text('Camera 2'), findsOneWidget);
    expect(find.text('north_gate'), findsOneWidget);
    expect(find.text('openai:gpt-4.1-mini'), findsOneWidget);
    expect(find.text('reviewed'), findsOneWidget);
    expect(find.text('Escalation Candidate'), findsOneWidget);
  });

  testWidgets('live operations shows activity truth and opens scoped events', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    List<String>? openedEventIds;
    String? openedSelectedEventId;

    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: [
            DecisionCreated(
              eventId: 'decision-activity-1',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 4)),
              dispatchId: 'D-2001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            IntelligenceReceived(
              eventId: 'ACTIVITY-7',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(hours: 3, minutes: 10)),
              intelligenceId: 'INT-ACTIVITY-7',
              provider: 'hikvision-dvr',
              sourceType: 'dvr',
              externalId: 'evt-activity-7',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              cameraId: 'gate-cam',
              objectLabel: 'person',
              headline: 'Watchlist subject detected',
              summary: 'Unauthorized person matched watchlist context.',
              riskScore: 84,
              canonicalHash: 'hash-activity-7',
            ),
            IntelligenceReceived(
              eventId: 'ACTIVITY-11',
              sequence: 3,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 40)),
              intelligenceId: 'INT-ACTIVITY-11',
              provider: 'hikvision-dvr',
              sourceType: 'dvr',
              externalId: 'evt-activity-11',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              cameraId: 'gate-cam',
              objectLabel: 'human',
              headline: 'Guard conversation observed',
              summary: 'Guard talking to unknown individual near the gate.',
              riskScore: 66,
              canonicalHash: 'hash-activity-11',
            ),
          ],
          videoOpsLabel: 'DVR',
          onOpenEventsForScope: (eventIds, selectedEventId) {
            openedEventIds = eventIds;
            openedSelectedEventId = selectedEventId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('live-activity-truth-card-INC-D-2001')),
      findsOneWidget,
    );
    expect(find.text('Activity Truth'), findsOneWidget);
    expect(find.textContaining('Signals 2 • People 2'), findsOneWidget);
    expect(find.textContaining('Long presence 1'), findsOneWidget);
    expect(find.textContaining('Guard interactions 1'), findsOneWidget);
    expect(find.textContaining('Flagged IDs 1'), findsOneWidget);
    expect(find.text('Review Refs'), findsOneWidget);
    expect(find.text('ACTIVITY-7, ACTIVITY-11'), findsOneWidget);

    final openEventsButton = find.byKey(
      const ValueKey('live-activity-truth-open-events-INC-D-2001'),
    );
    await tester.ensureVisible(openEventsButton);
    await tester.tap(openEventsButton);
    await tester.pumpAndSettle();

    expect(openedEventIds, equals(const ['ACTIVITY-7', 'ACTIVITY-11']));
    expect(openedSelectedEventId, 'ACTIVITY-11');
  });
}
