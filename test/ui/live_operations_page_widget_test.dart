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
    expect(find.text('SOVEREIGN LEDGER'), findsOneWidget);
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
    expect(find.text('SOVEREIGN LEDGER'), findsOneWidget);
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
    expect(find.text('SOVEREIGN LEDGER'), findsOneWidget);
    expect(find.byKey(const Key('incident-card-INC-8829-QX')), findsOneWidget);
    expect(find.byKey(const Key('incident-card-INC-8830-RZ')), findsOneWidget);
  });

  testWidgets('live operations renders command overview cards', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LiveOperationsPage(events: [])),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('live-operations-command-overview')),
      findsOneWidget,
    );
    expect(find.text('ACTIVE INCIDENTS'), findsOneWidget);
    expect(find.text('PENDING ACTIONS'), findsOneWidget);
    expect(find.text('ACTIVE LANES'), findsOneWidget);
    expect(find.text('SITES UNDER WATCH'), findsOneWidget);
  });

  testWidgets('live operations narrows incidents to the scoped lane', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          initialScopeClientId: 'CLIENT-001',
          initialScopeSiteId: 'SITE-VALLEE',
          events: [
            DecisionCreated(
              eventId: 'decision-sandton',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 4)),
              dispatchId: 'D-1001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            DecisionCreated(
              eventId: 'decision-vallee',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              dispatchId: 'D-2001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-VALLEE',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('live-operations-scope-banner')),
      findsOneWidget,
    );
    expect(find.text('Scope focus active'), findsOneWidget);
    expect(find.text('CLIENT-001/SITE-VALLEE'), findsOneWidget);
    expect(find.byKey(const Key('incident-card-INC-D-2001')), findsOneWidget);
    expect(find.byKey(const Key('incident-card-INC-D-1001')), findsNothing);
  });

  testWidgets('live operations supports client-wide scope focus', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          initialScopeClientId: 'CLIENT-001',
          initialScopeSiteId: '',
          events: [
            DecisionCreated(
              eventId: 'decision-sandton',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 4)),
              dispatchId: 'D-1001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            DecisionCreated(
              eventId: 'decision-vallee',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              dispatchId: 'D-2001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-VALLEE',
            ),
            DecisionCreated(
              eventId: 'decision-other-client',
              sequence: 3,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 1)),
              dispatchId: 'D-3001',
              clientId: 'CLIENT-999',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-OTHER',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('live-operations-scope-banner')),
      findsOneWidget,
    );
    expect(find.text('CLIENT-001/all sites'), findsOneWidget);
    expect(find.byKey(const Key('incident-card-INC-D-2001')), findsOneWidget);
    expect(find.byKey(const Key('incident-card-INC-D-1001')), findsOneWidget);
    expect(find.byKey(const Key('incident-card-INC-D-3001')), findsNothing);
  });

  testWidgets(
    'live operations links intelligence focus to live dispatch lane',
    (tester) async {
      final now = DateTime.now().toUtc();
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            focusIncidentReference: 'INTEL-VALLEE-1',
            events: [
              DecisionCreated(
                eventId: 'decision-vallee',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 3)),
                dispatchId: 'DSP-4',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-VALLEE',
              ),
              IntelligenceReceived(
                eventId: 'intel-event-1',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INTEL-VALLEE-1',
                sourceType: 'hardware',
                provider: 'dahua',
                externalId: 'evt-vallee-1',
                riskScore: 81,
                headline: 'Perimeter motion detected',
                summary: 'Motion flagged near the Vallee perimeter fence.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-VALLEE',
                faceConfidence: 0.94,
                canonicalHash: 'canon-vallee-1',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('incident-card-INC-DSP-4')), findsOneWidget);
      expect(find.text('Focus Scope-backed: INC-DSP-4'), findsOneWidget);
      expect(find.text('Focused Operations Lane'), findsNothing);
    },
  );

  testWidgets(
    'live operations critical alert banner focuses the critical incident',
    (tester) async {
      final now = DateTime.now().toUtc();
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            focusIncidentReference: 'INC-DSP-LOW',
            events: [
              DecisionCreated(
                eventId: 'decision-low',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 4)),
                dispatchId: 'DSP-LOW',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-LOW',
              ),
              IntelligenceReceived(
                eventId: 'intel-low',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 3)),
                intelligenceId: 'INTEL-LOW',
                sourceType: 'hardware',
                provider: 'dahua',
                externalId: 'evt-low',
                riskScore: 72,
                headline: 'Perimeter motion',
                summary: 'Moderate perimeter motion detected.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-LOW',
                faceConfidence: 0.82,
                canonicalHash: 'canon-low',
              ),
              DecisionCreated(
                eventId: 'decision-critical',
                sequence: 3,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                dispatchId: 'DSP-CRIT',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-CRIT',
              ),
              IntelligenceReceived(
                eventId: 'intel-critical',
                sequence: 4,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INTEL-CRIT',
                sourceType: 'hardware',
                provider: 'dahua',
                externalId: 'evt-crit',
                riskScore: 92,
                headline: 'Fire alarm escalation',
                summary: 'Critical hazard posture detected.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-CRIT',
                faceConfidence: 0.97,
                canonicalHash: 'canon-crit',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('live-operations-critical-alert-banner')),
        findsOneWidget,
      );
      expect(find.text('CRITICAL ALERT'), findsOneWidget);
      expect(find.text('Active Incident: INC-DSP-LOW'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey('live-operations-critical-alert-view-details'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active Incident: INC-DSP-CRIT'), findsOneWidget);
    },
  );

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

  testWidgets(
    'live operations shows shadow readiness bias for repeated MO pressure',
    (tester) async {
      final now = DateTime.now().toUtc();
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            previousTomorrowUrgencySummary: 'strength stable • high • 28s',
            historicalShadowMoLabels: const ['HARDEN ACCESS'],
            historicalShadowStrengthLabels: const ['strength rising'],
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
      expect(find.text('Urgency'), findsOneWidget);
      expect(find.textContaining('strength rising • critical'), findsOneWidget);
      expect(find.text('Previous urgency'), findsOneWidget);
      expect(
        find.textContaining('strength stable • high • 28s'),
        findsOneWidget,
      );
      expect(find.text('Readiness bias'), findsOneWidget);
      expect(find.textContaining('earlier access hardening'), findsOneWidget);
    },
  );

  testWidgets(
    'live operations explains posture-heated promotion pressure in next-shift card',
    (tester) async {
      final now = DateTime.now().toUtc();
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            historicalShadowMoLabels: const ['HARDEN ACCESS'],
            events: [
              DecisionCreated(
                eventId: 'decision-promo',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 4)),
                dispatchId: 'D-4100',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-VALLEE',
              ),
              IntelligenceReceived(
                eventId: 'promo-news',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 3)),
                intelligenceId: 'INT-PROMO-NEWS',
                provider: 'news_feed_monitor',
                sourceType: 'news',
                externalId: 'ext-promo-news',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SEED',
                cameraId: 'feed-news',
                objectLabel: 'person',
                objectConfidence: 0.70,
                headline: 'Contractors moved floor to floor in office park',
                summary:
                    'Suspects posed as maintenance contractors before moving across restricted office zones.',
                riskScore: 67,
                snapshotUrl: 'https://edge.example.com/promo-news.jpg',
                canonicalHash: 'hash-promo-news',
              ),
              IntelligenceReceived(
                eventId: 'promo-live-1',
                sequence: 3,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                intelligenceId: 'INT-PROMO-LIVE-1',
                provider: 'hikvision_dvr_monitor_only',
                sourceType: 'dvr',
                externalId: 'ext-promo-live-1',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-VALLEE',
                cameraId: 'office-cam-1',
                objectLabel: 'person',
                objectConfidence: 0.95,
                headline: 'Unplanned contractor roaming',
                summary:
                    'Maintenance-like subject moved across restricted office doors.',
                riskScore: 86,
                snapshotUrl: 'https://edge.example.com/promo-live-1.jpg',
                canonicalHash: 'hash-promo-live-1',
              ),
              IntelligenceReceived(
                eventId: 'promo-live-2',
                sequence: 4,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                intelligenceId: 'INT-PROMO-LIVE-2',
                provider: 'hikvision_dvr_monitor_only',
                sourceType: 'dvr',
                externalId: 'ext-promo-live-2',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-VALLEE',
                cameraId: 'office-cam-2',
                objectLabel: 'person',
                objectConfidence: 0.95,
                headline: 'Contractor repeating office sweep',
                summary:
                    'Maintenance-like subject kept probing multiple office doors.',
                riskScore: 87,
                snapshotUrl: 'https://edge.example.com/promo-live-2.jpg',
                canonicalHash: 'hash-promo-live-2',
              ),
              IntelligenceReceived(
                eventId: 'promo-live-3',
                sequence: 5,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INT-PROMO-LIVE-3',
                provider: 'hikvision_dvr_monitor_only',
                sourceType: 'dvr',
                externalId: 'ext-promo-live-3',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-VALLEE',
                cameraId: 'office-cam-3',
                objectLabel: 'person',
                objectConfidence: 0.95,
                headline: 'Contractor revisits office floors',
                summary:
                    'Service-looking subject returned to several restricted office zones.',
                riskScore: 89,
                snapshotUrl: 'https://edge.example.com/promo-live-3.jpg',
                canonicalHash: 'hash-promo-live-3',
              ),
              IntelligenceReceived(
                eventId: 'promo-live-4',
                sequence: 6,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INT-PROMO-LIVE-4',
                provider: 'hikvision_dvr_monitor_only',
                sourceType: 'dvr',
                externalId: 'ext-promo-live-4',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-VALLEE',
                cameraId: 'office-cam-4',
                objectLabel: 'person',
                objectConfidence: 0.96,
                headline: 'Contractor returns to office zone again',
                summary:
                    'Service-looking subject kept sweeping office floors and retrying access.',
                riskScore: 92,
                snapshotUrl: 'https://edge.example.com/promo-live-4.jpg',
                canonicalHash: 'hash-promo-live-4',
              ),
            ],
            sceneReviewByIntelligenceId: {
              'INT-PROMO-LIVE-1': MonitoringSceneReviewRecord(
                intelligenceId: 'INT-PROMO-LIVE-1',
                sourceLabel: 'openai:gpt-5.4-mini',
                postureLabel: 'service impersonation and roaming concern',
                decisionLabel: 'Escalation Candidate',
                decisionSummary:
                    'Likely spoofed service access with abnormal roaming.',
                summary:
                    'Likely maintenance impersonation moving across office zones.',
                reviewedAtUtc: now.subtract(const Duration(minutes: 2)),
              ),
              'INT-PROMO-LIVE-2': MonitoringSceneReviewRecord(
                intelligenceId: 'INT-PROMO-LIVE-2',
                sourceLabel: 'openai:gpt-5.4-mini',
                postureLabel: 'service impersonation and roaming concern',
                decisionLabel: 'Escalation Candidate',
                decisionSummary:
                    'Likely spoofed service access with abnormal roaming.',
                summary:
                    'Likely maintenance impersonation moving across office zones repeatedly.',
                reviewedAtUtc: now.subtract(const Duration(minutes: 2)),
              ),
              'INT-PROMO-LIVE-3': MonitoringSceneReviewRecord(
                intelligenceId: 'INT-PROMO-LIVE-3',
                sourceLabel: 'openai:gpt-5.4-mini',
                postureLabel: 'service impersonation and roaming concern',
                decisionLabel: 'Escalation Candidate',
                decisionSummary:
                    'Likely spoofed service access with abnormal roaming.',
                summary:
                    'Likely maintenance impersonation moving across office zones again.',
                reviewedAtUtc: now.subtract(const Duration(minutes: 1)),
              ),
              'INT-PROMO-LIVE-4': MonitoringSceneReviewRecord(
                intelligenceId: 'INT-PROMO-LIVE-4',
                sourceLabel: 'openai:gpt-5.4-mini',
                postureLabel: 'service impersonation and roaming concern',
                decisionLabel: 'Escalation Candidate',
                decisionSummary:
                    'Likely spoofed service access with abnormal roaming.',
                summary:
                    'Likely maintenance impersonation continuing across office zones.',
                reviewedAtUtc: now.subtract(const Duration(minutes: 1)),
              ),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Next-Shift Drafts'), findsOneWidget);
      expect(find.text('Promotion pressure'), findsOneWidget);
      expect(find.text('Promotion execution'), findsOneWidget);
      expect(find.textContaining('high • 40s'), findsWidgets);
      expect(find.textContaining('toward validated review'), findsWidgets);
      expect(find.textContaining('posture POSTURE'), findsOneWidget);
    },
  );

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
      expect(find.text('Posture Weight'), findsOneWidget);
      expect(find.textContaining('weight '), findsOneWidget);

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
      expect(find.textContaining('Strength'), findsWidgets);

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

  testWidgets('live operations shows client comms pulse for active incident', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    String? openedClientId;
    String? openedSiteId;
    String? clearedClientId;
    String? clearedSiteId;
    String? profiledClientId;
    String? profiledSiteId;
    String? profiledSignal;

    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: [
            DecisionCreated(
              eventId: 'decision-comms-1',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 5)),
              dispatchId: 'D-4001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            IntelligenceReceived(
              eventId: 'intel-comms-1',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 4)),
              intelligenceId: 'INT-COMMS-1',
              provider: 'hikvision-dvr',
              sourceType: 'dvr',
              externalId: 'evt-comms-1',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              headline: 'Boundary concern raised',
              summary:
                  'Client lane has become active after suspicious movement.',
              riskScore: 77,
              canonicalHash: 'hash-comms-1',
            ),
          ],
          clientCommsSnapshot: LiveClientCommsSnapshot(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            clientVoiceProfileLabel: 'Reassuring',
            learnedApprovalStyleCount: 2,
            learnedApprovalStyleExample:
                'Control is checking the latest position now and will share the next confirmed step shortly.',
            pendingLearnedStyleDraftCount: 1,
            totalMessages: 4,
            clientInboundCount: 2,
            pendingApprovalCount: 1,
            queuedPushCount: 1,
            telegramHealthLabel: 'ok',
            telegramHealthDetail:
                'Telegram delivery confirmed for the current lane.',
            pushSyncStatusLabel: 'syncing',
            smsFallbackLabel: 'SMS standby',
            smsFallbackReady: true,
            voiceReadinessLabel: 'VoIP staged',
            deliveryReadinessDetail:
                'Telegram remains primary for this scope; SMS only steps in after confirmed Telegram trouble.',
            latestSmsFallbackStatus:
                'sms:bulksms sent 2/2 after telegram blocked.',
            latestSmsFallbackAtUtc: now.subtract(const Duration(seconds: 45)),
            latestVoipStageStatus:
                'voip:asterisk staged call for Sandton Alpha.',
            latestVoipStageAtUtc: now.subtract(const Duration(seconds: 20)),
            recentDeliveryHistoryLines: const <String>[
              '12:36 UTC • voip staged • queue:1 • Asterisk staged a call for Sandton Alpha.',
              '12:35 UTC • sms fallback sent • queue:1 • BulkSMS reached 2/2 contacts after Telegram was blocked.',
            ],
            latestClientMessage:
                'Hi ONYX, just checking if the team is still on this please.',
            latestClientMessageAtUtc: now.subtract(const Duration(minutes: 2)),
            latestPendingDraft:
                'We are on it and command is checking the latest site position now.',
            latestPendingDraftAtUtc: now.subtract(const Duration(minutes: 1)),
            latestOnyxReply:
                'Control is still tracking the incident and will share the next verified update shortly.',
            latestOnyxReplyAtUtc: now.subtract(const Duration(minutes: 3)),
          ),
          onOpenClientViewForScope: (clientId, siteId) {
            openedClientId = clientId;
            openedSiteId = siteId;
          },
          onClearLearnedLaneStyleForScope: (clientId, siteId) async {
            clearedClientId = clientId;
            clearedSiteId = siteId;
          },
          onSetLaneVoiceProfileForScope:
              (clientId, siteId, profileSignal) async {
                profiledClientId = clientId;
                profiledSiteId = siteId;
                profiledSignal = profileSignal;
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('client-lane-watch-panel')),
      findsOneWidget,
    );
    expect(find.text('CLIENT LANE WATCH'), findsOneWidget);
    expect(find.text('Open Client Lane'), findsOneWidget);
    expect(find.text('Client Comms Pulse'), findsOneWidget);
    expect(find.text('Open Lane'), findsOneWidget);
    expect(find.text('Latest Client Message'), findsOneWidget);
    expect(find.text('Pending ONYX Draft'), findsOneWidget);
    expect(find.text('Latest SMS fallback'), findsWidgets);
    expect(find.text('Latest VoIP stage'), findsWidgets);
    expect(find.text('Recent delivery history'), findsWidgets);
    expect(
      find.textContaining(
        'Hi ONYX, just checking if the team is still on this please.',
      ),
      findsWidgets,
    );
    expect(
      find.textContaining(
        'We are on it and command is checking the latest site position now.',
      ),
      findsWidgets,
    );
    expect(find.text('Telegram OK'), findsWidgets);
    expect(find.text('SMS standby'), findsWidgets);
    expect(find.text('VoIP staged'), findsWidgets);
    expect(find.text('Lane voice Reassuring'), findsOneWidget);
    expect(find.text('Cue Reassurance'), findsWidgets);
    expect(find.text('Learned style 2'), findsWidgets);
    expect(find.text('ONYX using learned style'), findsWidgets);
    expect(find.text('Learned approval style'), findsWidgets);
    expect(
      find.text(
        'Lead with calm reassurance first, then the next confirmed step.',
      ),
      findsWidgets,
    );
    expect(
      find.textContaining(
        'BulkSMS reached 2/2 contacts after Telegram was blocked.',
      ),
      findsWidgets,
    );
    expect(
      find.textContaining('Asterisk staged a call for Sandton Alpha.'),
      findsWidgets,
    );
    expect(
      find.textContaining('12:36 UTC • voip staged • queue:1'),
      findsWidgets,
    );
    expect(
      find.textContaining(
        'Control is checking the latest position now and will share the next confirmed step shortly.',
      ),
      findsWidgets,
    );
    expect(find.widgetWithText(OutlinedButton, 'Concise'), findsWidgets);
    expect(find.text('Clear Learned Style'), findsWidgets);

    final conciseButton = find.widgetWithText(OutlinedButton, 'Concise').first;
    await tester.ensureVisible(conciseButton);
    await tester.tap(conciseButton);
    await tester.pumpAndSettle();

    expect(profiledClientId, 'CLIENT-001');
    expect(profiledSiteId, 'SITE-SANDTON');
    expect(profiledSignal, 'concise-updates');

    final clearLearnedStyleButton = find.byKey(
      const ValueKey(
        'client-lane-watch-clear-learned-style-CLIENT-001-SITE-SANDTON',
      ),
    );
    await tester.ensureVisible(clearLearnedStyleButton);
    await tester.tap(clearLearnedStyleButton);
    await tester.pumpAndSettle();

    expect(clearedClientId, 'CLIENT-001');
    expect(clearedSiteId, 'SITE-SANDTON');

    final openLaneButton = find.text('Open Lane');
    await tester.ensureVisible(openLaneButton);
    await tester.tap(openLaneButton);
    await tester.pumpAndSettle();

    expect(openedClientId, 'CLIENT-001');
    expect(openedSiteId, 'SITE-SANDTON');
  });

  testWidgets('live operations shows control inbox drafts with quick actions', (
    tester,
  ) async {
    int? approvedUpdateId;
    int? rejectedUpdateId;
    String? openedClientId;
    String? openedSiteId;
    String? profiledClientId;
    String? profiledSiteId;
    String? profiledSignal;

    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: const [],
          controlInboxSnapshot: LiveControlInboxSnapshot(
            selectedClientId: 'CLIENT-001',
            selectedSiteId: 'SITE-SANDTON',
            selectedScopeClientVoiceProfileLabel: 'Validation-heavy',
            pendingApprovalCount: 2,
            selectedScopePendingCount: 1,
            telegramHealthLabel: 'degraded',
            telegramHealthDetail:
                'Telegram bridge is delayed, so approvals need close operator attention.',
            pendingDrafts: [
              LiveControlInboxDraft(
                updateId: 501,
                clientId: 'CLIENT-001',
                siteId: 'SITE-SANDTON',
                sourceText:
                    'Hi ONYX, are we still waiting on the patrol update?',
                draftText:
                    'We are checking the latest patrol position now and will send the next verified update shortly.',
                providerLabel: 'OpenAI',
                usesLearnedApprovalStyle: true,
                createdAtUtc: DateTime.utc(2026, 3, 18, 6, 0),
                clientVoiceProfileLabel: 'Validation-heavy',
                matchesSelectedScope: true,
              ),
              LiveControlInboxDraft(
                updateId: 502,
                clientId: 'CLIENT-VALLEE',
                siteId: 'SITE-RESIDENCE',
                sourceText:
                    'Please confirm if the response team has already arrived.',
                draftText:
                    'Command is confirming arrival now and will share the verified position as soon as it is locked.',
                providerLabel: 'OpenAI',
                createdAtUtc: DateTime.utc(2026, 3, 18, 5, 56),
                clientVoiceProfileLabel: 'Concise',
              ),
            ],
          ),
          onApproveClientReplyDraft: (updateId, {approvedText}) async {
            approvedUpdateId = updateId;
            return 'approved=$updateId';
          },
          onRejectClientReplyDraft: (updateId) async {
            rejectedUpdateId = updateId;
            return 'rejected=$updateId';
          },
          onSetLaneVoiceProfileForScope:
              (clientId, siteId, profileSignal) async {
                profiledClientId = clientId;
                profiledSiteId = siteId;
                profiledSignal = profileSignal;
              },
          onOpenClientViewForScope: (clientId, siteId) {
            openedClientId = clientId;
            openedSiteId = siteId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('control-inbox-panel')), findsOneWidget);
    expect(find.text('CONTROL INBOX'), findsOneWidget);
    expect(find.text('1 High-priority Reply'), findsWidgets);
    expect(find.byKey(const ValueKey('control-inbox-priority-badge')), findsOneWidget);
    expect(find.byKey(const ValueKey('control-inbox-queue-state-chip')), findsOneWidget);
    expect(find.text('Queue Full'), findsWidgets);
    expect(find.text('High priority 1'), findsOneWidget);
    expect(find.textContaining('2 client replies waiting'), findsOneWidget);
    expect(find.text('Selected lane'), findsOneWidget);
    expect(find.text('Other scope'), findsOneWidget);
    expect(find.text('Lane voice Validation-heavy'), findsOneWidget);
    expect(find.text('Voice Validation-heavy'), findsOneWidget);
    expect(find.text('Voice Concise'), findsOneWidget);
    expect(find.text('Cue Validation'), findsOneWidget);
    expect(find.text('Cue Timing'), findsOneWidget);
    expect(find.text('Queue shape'), findsOneWidget);
    expect(find.text('1 timing'), findsOneWidget);
    expect(find.text('1 validation'), findsOneWidget);
    expect(find.text('Voice-adjusted'), findsNWidgets(2));
    expect(find.text('Uses learned approval style'), findsOneWidget);
    expect(
      find.text(
        'Keep the exact check concrete and make sure the next confirmed step is clear before sending.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Check that timing is not over-promised before sending.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'This draft is already leaning on learned approval wording from this lane.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Reassuring'), findsWidgets);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('control-inbox-draft-502'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('control-inbox-draft-501'))).dy,
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('control-inbox-priority-badge')),
    );
    await tester.tap(find.byKey(const ValueKey('control-inbox-priority-badge')));
    await tester.pumpAndSettle();

    expect(find.text('Queue shape'), findsOneWidget);
    expect(find.text('1 timing'), findsOneWidget);
    expect(find.text('1 validation'), findsNothing);
    expect(
      find.text(
        'Showing high-priority only. Tap the badge again to return to the full queue.',
      ),
      findsOneWidget,
    );
    expect(find.text('Queue High priority'), findsWidgets);
    expect(find.byKey(const ValueKey('control-inbox-filtered-chip')), findsOneWidget);
    expect(find.text('Filtered 1'), findsWidgets);
    expect(find.byKey(const ValueKey('control-inbox-draft-502')), findsOneWidget);
    expect(find.byKey(const ValueKey('control-inbox-draft-501')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('control-inbox-priority-badge')));
    await tester.pumpAndSettle();

    expect(find.text('Queue shape'), findsOneWidget);
    expect(find.text('1 timing'), findsOneWidget);
    expect(find.text('1 validation'), findsOneWidget);
    expect(find.text('Queue Full'), findsWidgets);
    expect(find.byKey(const ValueKey('control-inbox-filtered-chip')), findsNothing);
    expect(find.byKey(const ValueKey('control-inbox-draft-501')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('control-inbox-summary-pill-timing')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Queue shape'), findsOneWidget);
    expect(find.text('1 timing'), findsOneWidget);
    expect(find.text('1 validation'), findsNothing);
    expect(find.byKey(const ValueKey('control-inbox-filtered-chip')), findsOneWidget);
    expect(find.text('Filtered 1'), findsWidgets);
    expect(
      find.text(
        'Showing timing only. Tap the same pill again or use Show all replies to return to the full queue.',
      ),
      findsOneWidget,
    );
    expect(find.text('Queue Timing only'), findsWidgets);
    expect(find.byKey(const ValueKey('top-bar-cue-filter-chip')), findsWidgets);
    expect(find.text('Timing only'), findsWidgets);
    expect(find.byKey(const ValueKey('control-inbox-draft-502')), findsOneWidget);
    expect(find.byKey(const ValueKey('control-inbox-draft-501')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('control-inbox-summary-pill-timing')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Queue shape'), findsOneWidget);
    expect(find.text('1 timing'), findsOneWidget);
    expect(find.text('1 validation'), findsOneWidget);
    expect(find.text('Queue Full'), findsWidgets);
    expect(find.byKey(const ValueKey('top-bar-cue-filter-chip')), findsNothing);
    expect(find.byKey(const ValueKey('control-inbox-filtered-chip')), findsNothing);
    expect(find.byKey(const ValueKey('control-inbox-draft-501')), findsOneWidget);

    final reassuringButton = find
        .widgetWithText(OutlinedButton, 'Reassuring')
        .first;
    await tester.ensureVisible(reassuringButton);
    await tester.tap(reassuringButton);
    await tester.pumpAndSettle();

    expect(profiledClientId, 'CLIENT-001');
    expect(profiledSiteId, 'SITE-SANDTON');
    expect(profiledSignal, 'reassurance-forward');

    final selectedDraft = find.byKey(const ValueKey('control-inbox-draft-501'));
    await tester.ensureVisible(selectedDraft);
    await tester.tap(
      find.descendant(
        of: selectedDraft,
        matching: find.widgetWithText(FilledButton, 'Approve + Send'),
      ),
    );
    await tester.pumpAndSettle();

    expect(approvedUpdateId, 501);
    expect(find.text('approved=501'), findsOneWidget);

    final otherDraft = find.byKey(const ValueKey('control-inbox-draft-502'));
    await tester.ensureVisible(otherDraft);
    await tester.tap(
      find.descendant(
        of: otherDraft,
        matching: find.widgetWithText(OutlinedButton, 'Reject'),
      ),
    );
    await tester.pumpAndSettle();

    expect(rejectedUpdateId, 502);
    expect(find.text('rejected=502'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: otherDraft,
        matching: find.widgetWithText(OutlinedButton, 'Open Client Lane'),
      ),
    );
    await tester.pumpAndSettle();

    expect(openedClientId, 'CLIENT-VALLEE');
    expect(openedSiteId, 'SITE-RESIDENCE');
  });

  testWidgets('live operations humanizes telegram bridge detail in comms view', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: const [],
          clientCommsSnapshot: LiveClientCommsSnapshot(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            telegramHealthLabel: 'blocked',
            telegramHealthDetail:
                'Telegram bridge failed for 1/1 message(s). Reasons: BLOCKED_BY_TEST_STUB',
            telegramFallbackActive: true,
            pushSyncStatusLabel: 'failed',
            latestClientMessage: 'Is Telegram still failing there?',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Telegram BLOCKED'), findsWidgets);
    expect(find.textContaining('Telegram fallback is active'), findsWidgets);
    expect(
      find.textContaining(
        'Telegram could not deliver 1/1 client update. Bridge reported: BLOCKED_BY_TEST_STUB.',
      ),
      findsWidgets,
    );
  });

  testWidgets('live operations shows live client asks before draft staging', (
    tester,
  ) async {
    String? openedClientId;
    String? openedSiteId;

    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: const [],
          controlInboxSnapshot: LiveControlInboxSnapshot(
            selectedClientId: 'CLIENT-001',
            selectedSiteId: 'SITE-SANDTON',
            awaitingResponseCount: 1,
            telegramHealthLabel: 'ok',
            liveClientAsks: [
              LiveControlInboxClientAsk(
                clientId: 'CLIENT-001',
                siteId: 'SITE-SANDTON',
                author: '@resident_12',
                body:
                    'Hi ONYX, can you please tell me if the patrol has arrived yet?',
                messageProvider: 'telegram',
                occurredAtUtc: DateTime.now().toUtc().subtract(
                  const Duration(minutes: 2),
                ),
                matchesSelectedScope: true,
              ),
            ],
          ),
          onOpenClientViewForScope: (clientId, siteId) {
            openedClientId = clientId;
            openedSiteId = siteId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LIVE CLIENT ASKS'), findsOneWidget);
    expect(
      find.textContaining('1 live client ask waiting for response shaping'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Hi ONYX, can you please tell me if the patrol has arrived yet?',
      ),
      findsOneWidget,
    );
    expect(find.text('Selected lane'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Shape Reply'), findsOneWidget);

    final selectedShapeReplyButton = find.widgetWithText(
      OutlinedButton,
      'Shape Reply',
    );
    await tester.ensureVisible(selectedShapeReplyButton);
    await tester.tap(selectedShapeReplyButton);
    await tester.pumpAndSettle();

    expect(openedClientId, 'CLIENT-001');
    expect(openedSiteId, 'SITE-SANDTON');
  });

  testWidgets('live operations shows other-scope client asks with lane handoff', (
    tester,
  ) async {
    String? openedClientId;
    String? openedSiteId;

    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: const [],
          controlInboxSnapshot: LiveControlInboxSnapshot(
            selectedClientId: 'CLIENT-001',
            selectedSiteId: 'SITE-SANDTON',
            awaitingResponseCount: 1,
            telegramHealthLabel: 'ok',
            liveClientAsks: [
              LiveControlInboxClientAsk(
                clientId: 'CLIENT-VALLEE',
                siteId: 'WTF-MAIN',
                author: '@waterfall_resident',
                body:
                    'Please confirm whether the Waterfall response team has already arrived.',
                messageProvider: 'telegram',
                occurredAtUtc: DateTime.now().toUtc().subtract(
                  const Duration(minutes: 1),
                ),
                matchesSelectedScope: false,
              ),
            ],
          ),
          onOpenClientViewForScope: (clientId, siteId) {
            openedClientId = clientId;
            openedSiteId = siteId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LIVE CLIENT ASKS'), findsOneWidget);
    expect(find.text('Other scope'), findsOneWidget);
    expect(
      find.textContaining(
        'Please confirm whether the Waterfall response team has already arrived.',
      ),
      findsOneWidget,
    );

    final offScopeShapeReplyButton = find.widgetWithText(
      OutlinedButton,
      'Shape Reply',
    );
    await tester.ensureVisible(offScopeShapeReplyButton);
    await tester.tap(offScopeShapeReplyButton);
    await tester.pumpAndSettle();

    expect(openedClientId, 'CLIENT-VALLEE');
    expect(openedSiteId, 'WTF-MAIN');
  });

  testWidgets('live operations can refine client draft before approval', (
    tester,
  ) async {
    String draftText =
        'We are checking the latest patrol position now and will send the next verified update shortly.';
    String? approvedDraftText;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return LiveOperationsPage(
              events: const [],
              controlInboxSnapshot: LiveControlInboxSnapshot(
                selectedClientId: 'CLIENT-001',
                selectedSiteId: 'SITE-SANDTON',
                pendingApprovalCount: 1,
                selectedScopePendingCount: 1,
                telegramHealthLabel: 'ok',
                pendingDrafts: [
                  LiveControlInboxDraft(
                    updateId: 501,
                    clientId: 'CLIENT-001',
                    siteId: 'SITE-SANDTON',
                    sourceText:
                        'Hi ONYX, are we still waiting on the patrol update?',
                    draftText: draftText,
                    providerLabel: 'OpenAI',
                    usesLearnedApprovalStyle: true,
                    createdAtUtc: DateTime.utc(2026, 3, 18, 6, 0),
                    clientVoiceProfileLabel: 'Reassuring',
                    matchesSelectedScope: true,
                  ),
                ],
              ),
              onUpdateClientReplyDraftText: (updateId, nextText) async {
                setState(() {
                  draftText = nextText;
                });
              },
              onApproveClientReplyDraft:
                  (updateId, {String? approvedText}) async {
                    approvedDraftText = approvedText;
                    return 'approved=$updateId';
                  },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editDraftButton = find.widgetWithText(OutlinedButton, 'Edit Draft');
    await tester.ensureVisible(editDraftButton);
    await tester.tap(editDraftButton);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(
          'Lead with calm reassurance first, then the next confirmed step.',
        ),
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byType(TextField).last,
      'ETA is about 4 minutes. We will confirm arrival as soon as the team reaches Sandton.',
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(
          'Check that timing is not over-promised before sending.',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save Draft'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'ETA is about 4 minutes. We will confirm arrival as soon as the team reaches Sandton.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Approve + Send'));
    await tester.pumpAndSettle();

    expect(
      approvedDraftText,
      'ETA is about 4 minutes. We will confirm arrival as soon as the team reaches Sandton.',
    );
  });

  testWidgets('live operations top-bar priority chip jumps to control inbox', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: const [],
          clientCommsSnapshot: LiveClientCommsSnapshot(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            clientVoiceProfileLabel: 'Reassuring',
            pendingApprovalCount: 1,
            clientInboundCount: 1,
            latestClientMessage: 'Hi ONYX, are we still waiting on the patrol update?',
            latestPendingDraft:
                'We are checking the latest patrol position now and will send the next verified update shortly.',
            telegramHealthLabel: 'ok',
            smsFallbackLabel: 'SMS standby',
            voiceReadinessLabel: 'VoIP staged',
          ),
          controlInboxSnapshot: LiveControlInboxSnapshot(
            selectedClientId: 'CLIENT-001',
            selectedSiteId: 'SITE-SANDTON',
            selectedScopeClientVoiceProfileLabel: 'Validation-heavy',
            pendingApprovalCount: 2,
            selectedScopePendingCount: 1,
            telegramHealthLabel: 'degraded',
            pendingDrafts: [
              LiveControlInboxDraft(
                updateId: 502,
                clientId: 'CLIENT-VALLEE',
                siteId: 'SITE-RESIDENCE',
                sourceText:
                    'Please confirm if the response team has already arrived.',
                draftText:
                    'Command is confirming arrival now and will share the verified position as soon as it is locked.',
                providerLabel: 'OpenAI',
                createdAtUtc: DateTime.utc(2026, 3, 18, 5, 56),
                clientVoiceProfileLabel: 'Concise',
              ),
              LiveControlInboxDraft(
                updateId: 501,
                clientId: 'CLIENT-001',
                siteId: 'SITE-SANDTON',
                sourceText:
                    'Hi ONYX, are we still waiting on the patrol update?',
                draftText:
                    'We are checking the latest patrol position now and will send the next verified update shortly.',
                providerLabel: 'OpenAI',
                createdAtUtc: DateTime.utc(2026, 3, 18, 6, 0),
                clientVoiceProfileLabel: 'Validation-heavy',
                matchesSelectedScope: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final controlInboxPanel = find.byKey(const ValueKey('control-inbox-panel'));
    expect(tester.getTopLeft(controlInboxPanel).dy, greaterThan(320));
    expect(find.byKey(const ValueKey('top-bar-queue-state-chip')), findsWidgets);
    expect(find.text('Queue Full'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('top-bar-priority-chip')).first);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(controlInboxPanel).dy, lessThan(320));
    expect(find.text('Queue High priority'), findsWidgets);
    expect(find.text('Queue shape'), findsOneWidget);
    expect(find.text('1 timing'), findsOneWidget);
    expect(
      find.text(
        'Showing high-priority only. Tap the badge again to return to the full queue.',
      ),
      findsOneWidget,
    );
    expect(find.text('Show all replies (1)'), findsWidgets);
    expect(find.byKey(const ValueKey('control-inbox-draft-501')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('top-bar-show-all-chip')).first);
    await tester.pumpAndSettle();

    expect(find.text('Queue Full'), findsWidgets);
    expect(find.text('Queue shape'), findsOneWidget);
    expect(find.text('1 timing'), findsOneWidget);
    expect(find.text('1 validation'), findsOneWidget);
    expect(find.byKey(const ValueKey('control-inbox-draft-501')), findsOneWidget);
  });

  testWidgets(
    'live operations control inbox queue-state chip cycles queue modes',
    (tester) async {
      String? profiledClientId;
      String? profiledSiteId;
      String? profiledSignal;

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const [],
            clientCommsSnapshot: LiveClientCommsSnapshot(
              clientId: 'CLIENT-001',
              siteId: 'SITE-SANDTON',
              clientVoiceProfileLabel: 'Validation-heavy',
              pendingApprovalCount: 1,
              clientInboundCount: 1,
              latestClientMessage:
                  'Hi ONYX, are we still waiting on the patrol update?',
              latestPendingDraft:
                  'We are checking the latest patrol position now and will send the next verified update shortly.',
              telegramHealthLabel: 'ok',
              smsFallbackLabel: 'SMS standby',
              voiceReadinessLabel: 'VoIP staged',
            ),
            controlInboxSnapshot: LiveControlInboxSnapshot(
              selectedClientId: 'CLIENT-001',
              selectedSiteId: 'SITE-SANDTON',
              selectedScopeClientVoiceProfileLabel: 'Validation-heavy',
              pendingApprovalCount: 2,
              selectedScopePendingCount: 1,
              telegramHealthLabel: 'degraded',
              pendingDrafts: [
                LiveControlInboxDraft(
                  updateId: 502,
                  clientId: 'CLIENT-VALLEE',
                  siteId: 'SITE-RESIDENCE',
                  sourceText:
                      'Please confirm if the response team has already arrived.',
                  draftText:
                      'Command is confirming arrival now and will share the verified position as soon as it is locked.',
                  providerLabel: 'OpenAI',
                  createdAtUtc: DateTime.utc(2026, 3, 18, 5, 56),
                  clientVoiceProfileLabel: 'Concise',
                ),
                LiveControlInboxDraft(
                  updateId: 501,
                  clientId: 'CLIENT-001',
                  siteId: 'SITE-SANDTON',
                  sourceText:
                      'Hi ONYX, are we still waiting on the patrol update?',
                  draftText:
                      'We are checking the latest patrol position now and will send the next verified update shortly.',
                  providerLabel: 'OpenAI',
                  createdAtUtc: DateTime.utc(2026, 3, 18, 6, 0),
                  clientVoiceProfileLabel: 'Validation-heavy',
                  usesLearnedApprovalStyle: true,
                  matchesSelectedScope: true,
                ),
              ],
            ),
            onSetLaneVoiceProfileForScope:
                (clientId, siteId, profileSignal) async {
                  profiledClientId = clientId;
                  profiledSiteId = siteId;
                  profiledSignal = profileSignal;
                },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final queueStateChip = find.byKey(
        const ValueKey('control-inbox-queue-state-chip'),
      );
      expect(queueStateChip, findsOneWidget);
      expect(find.text('Queue Full'), findsWidgets);
      expect(
        find.descendant(
          of: queueStateChip,
          matching: find.byIcon(Icons.inbox_rounded),
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(queueStateChip);
      await tester.tap(queueStateChip);
      await tester.pumpAndSettle();

      expect(find.text('Queue High priority'), findsWidgets);
      expect(
        find.descendant(
          of: queueStateChip,
          matching: find.byIcon(Icons.priority_high_rounded),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('control-inbox-filtered-chip')), findsOneWidget);
      expect(find.byKey(const ValueKey('control-inbox-draft-502')), findsOneWidget);
      expect(find.byKey(const ValueKey('control-inbox-draft-501')), findsNothing);

      await tester.tap(queueStateChip);
      await tester.pumpAndSettle();

      expect(find.text('Queue Full'), findsWidgets);
      expect(find.byKey(const ValueKey('control-inbox-filtered-chip')), findsNothing);
      expect(find.byKey(const ValueKey('control-inbox-draft-501')), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('control-inbox-summary-pill-timing')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Queue Timing only'), findsWidgets);
      expect(
        find.descendant(
          of: queueStateChip,
          matching: find.byIcon(Icons.schedule_rounded),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('control-inbox-draft-501')), findsNothing);

      await tester.tap(queueStateChip);
      await tester.pumpAndSettle();

      expect(find.text('Queue High priority'), findsWidgets);
      expect(find.byKey(const ValueKey('top-bar-cue-filter-chip')), findsNothing);
      expect(find.byKey(const ValueKey('control-inbox-draft-502')), findsOneWidget);

      await tester.tap(queueStateChip);
      await tester.pumpAndSettle();

      expect(find.text('Queue Full'), findsWidgets);
      expect(find.byKey(const ValueKey('control-inbox-filtered-chip')), findsNothing);
      expect(find.byKey(const ValueKey('control-inbox-draft-501')), findsOneWidget);

      expect(profiledClientId, isNull);
      expect(profiledSiteId, isNull);
      expect(profiledSignal, isNull);
    },
  );

  testWidgets(
    'live operations shows queue-state first-run hint until queue interaction',
    (tester) async {
      LiveOperationsPage.debugResetQueueStateHintSession();
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const [],
            clientCommsSnapshot: LiveClientCommsSnapshot(
              clientId: 'CLIENT-001',
              siteId: 'SITE-SANDTON',
              clientVoiceProfileLabel: 'Validation-heavy',
              pendingApprovalCount: 1,
              clientInboundCount: 1,
              latestClientMessage:
                  'Hi ONYX, are we still waiting on the patrol update?',
              latestPendingDraft:
                  'We are checking the latest patrol position now and will send the next verified update shortly.',
              telegramHealthLabel: 'ok',
              smsFallbackLabel: 'SMS standby',
              voiceReadinessLabel: 'VoIP staged',
            ),
            controlInboxSnapshot: LiveControlInboxSnapshot(
              selectedClientId: 'CLIENT-001',
              selectedSiteId: 'SITE-SANDTON',
              selectedScopeClientVoiceProfileLabel: 'Validation-heavy',
              pendingApprovalCount: 2,
              selectedScopePendingCount: 1,
              telegramHealthLabel: 'degraded',
              pendingDrafts: [
                LiveControlInboxDraft(
                  updateId: 502,
                  clientId: 'CLIENT-VALLEE',
                  siteId: 'SITE-RESIDENCE',
                  sourceText:
                      'Please confirm if the response team has already arrived.',
                  draftText:
                      'Command is confirming arrival now and will share the verified position as soon as it is locked.',
                  providerLabel: 'OpenAI',
                  createdAtUtc: DateTime.utc(2026, 3, 18, 5, 56),
                  clientVoiceProfileLabel: 'Concise',
                ),
                LiveControlInboxDraft(
                  updateId: 501,
                  clientId: 'CLIENT-001',
                  siteId: 'SITE-SANDTON',
                  sourceText:
                      'Hi ONYX, are we still waiting on the patrol update?',
                  draftText:
                      'We are checking the latest patrol position now and will send the next verified update shortly.',
                  providerLabel: 'OpenAI',
                  createdAtUtc: DateTime.utc(2026, 3, 18, 6, 0),
                  clientVoiceProfileLabel: 'Validation-heavy',
                  matchesSelectedScope: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('control-inbox-queue-hint')), findsOneWidget);
      expect(find.text('Hide tip'), findsOneWidget);

      final queueStateChip = find.byKey(
        const ValueKey('control-inbox-queue-state-chip'),
      );
      await tester.ensureVisible(queueStateChip);
      await tester.tap(queueStateChip);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('control-inbox-queue-hint')), findsNothing);
      expect(find.text('Queue High priority'), findsWidgets);

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const [],
            clientCommsSnapshot: LiveClientCommsSnapshot(
              clientId: 'CLIENT-001',
              siteId: 'SITE-SANDTON',
              clientVoiceProfileLabel: 'Validation-heavy',
              pendingApprovalCount: 1,
              clientInboundCount: 1,
              latestClientMessage:
                  'Hi ONYX, are we still waiting on the patrol update?',
              latestPendingDraft:
                  'We are checking the latest patrol position now and will send the next verified update shortly.',
              telegramHealthLabel: 'ok',
              smsFallbackLabel: 'SMS standby',
              voiceReadinessLabel: 'VoIP staged',
            ),
            controlInboxSnapshot: LiveControlInboxSnapshot(
              selectedClientId: 'CLIENT-001',
              selectedSiteId: 'SITE-SANDTON',
              selectedScopeClientVoiceProfileLabel: 'Validation-heavy',
              pendingApprovalCount: 2,
              selectedScopePendingCount: 1,
              telegramHealthLabel: 'degraded',
              pendingDrafts: [
                LiveControlInboxDraft(
                  updateId: 502,
                  clientId: 'CLIENT-VALLEE',
                  siteId: 'SITE-RESIDENCE',
                  sourceText:
                      'Please confirm if the response team has already arrived.',
                  draftText:
                      'Command is confirming arrival now and will share the verified position as soon as it is locked.',
                  providerLabel: 'OpenAI',
                  createdAtUtc: DateTime.utc(2026, 3, 18, 5, 56),
                  clientVoiceProfileLabel: 'Concise',
                ),
                LiveControlInboxDraft(
                  updateId: 501,
                  clientId: 'CLIENT-001',
                  siteId: 'SITE-SANDTON',
                  sourceText:
                      'Hi ONYX, are we still waiting on the patrol update?',
                  draftText:
                      'We are checking the latest patrol position now and will send the next verified update shortly.',
                  providerLabel: 'OpenAI',
                  createdAtUtc: DateTime.utc(2026, 3, 18, 6, 0),
                  clientVoiceProfileLabel: 'Validation-heavy',
                  matchesSelectedScope: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('control-inbox-queue-hint')), findsNothing);
    },
  );

  testWidgets(
    'live operations can show the queue hint again after hiding it',
    (tester) async {
      LiveOperationsPage.debugResetQueueStateHintSession();
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const [],
            clientCommsSnapshot: LiveClientCommsSnapshot(
              clientId: 'CLIENT-001',
              siteId: 'SITE-SANDTON',
              clientVoiceProfileLabel: 'Validation-heavy',
              pendingApprovalCount: 1,
              clientInboundCount: 1,
              latestClientMessage:
                  'Hi ONYX, are we still waiting on the patrol update?',
              latestPendingDraft:
                  'We are checking the latest patrol position now and will send the next verified update shortly.',
              telegramHealthLabel: 'ok',
              smsFallbackLabel: 'SMS standby',
              voiceReadinessLabel: 'VoIP staged',
            ),
            controlInboxSnapshot: LiveControlInboxSnapshot(
              selectedClientId: 'CLIENT-001',
              selectedSiteId: 'SITE-SANDTON',
              selectedScopeClientVoiceProfileLabel: 'Validation-heavy',
              pendingApprovalCount: 2,
              selectedScopePendingCount: 1,
              telegramHealthLabel: 'degraded',
              pendingDrafts: [
                LiveControlInboxDraft(
                  updateId: 502,
                  clientId: 'CLIENT-VALLEE',
                  siteId: 'SITE-RESIDENCE',
                  sourceText:
                      'Please confirm if the response team has already arrived.',
                  draftText:
                      'Command is confirming arrival now and will share the verified position as soon as it is locked.',
                  providerLabel: 'OpenAI',
                  createdAtUtc: DateTime.utc(2026, 3, 18, 5, 56),
                  clientVoiceProfileLabel: 'Concise',
                ),
                LiveControlInboxDraft(
                  updateId: 501,
                  clientId: 'CLIENT-001',
                  siteId: 'SITE-SANDTON',
                  sourceText:
                      'Hi ONYX, are we still waiting on the patrol update?',
                  draftText:
                      'We are checking the latest patrol position now and will send the next verified update shortly.',
                  providerLabel: 'OpenAI',
                  createdAtUtc: DateTime.utc(2026, 3, 18, 6, 0),
                  clientVoiceProfileLabel: 'Validation-heavy',
                  matchesSelectedScope: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final queueStateChip = find.byKey(
        const ValueKey('control-inbox-queue-state-chip'),
      );
      await tester.ensureVisible(queueStateChip);
      await tester.tap(queueStateChip);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('control-inbox-queue-hint')), findsNothing);
      expect(
        find.byKey(const ValueKey('control-inbox-show-queue-hint')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('control-inbox-show-queue-hint')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('control-inbox-queue-hint')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('control-inbox-show-queue-hint')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'live operations queue-state chips explain queue modes on long press',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const [],
            clientCommsSnapshot: LiveClientCommsSnapshot(
              clientId: 'CLIENT-001',
              siteId: 'SITE-SANDTON',
              clientVoiceProfileLabel: 'Validation-heavy',
              pendingApprovalCount: 1,
              clientInboundCount: 1,
              latestClientMessage:
                  'Hi ONYX, are we still waiting on the patrol update?',
              latestPendingDraft:
                  'We are checking the latest patrol position now and will send the next verified update shortly.',
              telegramHealthLabel: 'ok',
              smsFallbackLabel: 'SMS standby',
              voiceReadinessLabel: 'VoIP staged',
            ),
            controlInboxSnapshot: LiveControlInboxSnapshot(
              selectedClientId: 'CLIENT-001',
              selectedSiteId: 'SITE-SANDTON',
              selectedScopeClientVoiceProfileLabel: 'Validation-heavy',
              pendingApprovalCount: 2,
              selectedScopePendingCount: 1,
              telegramHealthLabel: 'degraded',
              pendingDrafts: [
                LiveControlInboxDraft(
                  updateId: 502,
                  clientId: 'CLIENT-VALLEE',
                  siteId: 'SITE-RESIDENCE',
                  sourceText:
                      'Please confirm if the response team has already arrived.',
                  draftText:
                      'Command is confirming arrival now and will share the verified position as soon as it is locked.',
                  providerLabel: 'OpenAI',
                  createdAtUtc: DateTime.utc(2026, 3, 18, 5, 56),
                  clientVoiceProfileLabel: 'Concise',
                ),
                LiveControlInboxDraft(
                  updateId: 501,
                  clientId: 'CLIENT-001',
                  siteId: 'SITE-SANDTON',
                  sourceText:
                      'Hi ONYX, are we still waiting on the patrol update?',
                  draftText:
                      'We are checking the latest patrol position now and will send the next verified update shortly.',
                  providerLabel: 'OpenAI',
                  createdAtUtc: DateTime.utc(2026, 3, 18, 6, 0),
                  clientVoiceProfileLabel: 'Validation-heavy',
                  matchesSelectedScope: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final queueStateChip = find.byKey(
        const ValueKey('control-inbox-queue-state-chip'),
      );

      await tester.ensureVisible(queueStateChip);
      await tester.longPress(queueStateChip);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Queue Full is showing every pending reply. Tap to narrow the inbox to the high-priority queue.',
        ),
        findsOneWidget,
      );

      await tester.tap(queueStateChip);
      await tester.pumpAndSettle();

      await tester.longPress(queueStateChip);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Queue High priority is showing only sensitive and timing replies. Tap to return to the full queue.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'live operations top-bar cue filter chip widens priority filters and jumps to control inbox',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const [],
            clientCommsSnapshot: LiveClientCommsSnapshot(
              clientId: 'CLIENT-001',
              siteId: 'SITE-SANDTON',
              clientVoiceProfileLabel: 'Reassuring',
              pendingApprovalCount: 1,
              clientInboundCount: 1,
              latestClientMessage:
                  'Hi ONYX, are we still waiting on the patrol update?',
              latestPendingDraft:
                  'We are checking the latest patrol position now and will send the next verified update shortly.',
              telegramHealthLabel: 'ok',
              smsFallbackLabel: 'SMS standby',
              voiceReadinessLabel: 'VoIP staged',
            ),
            controlInboxSnapshot: LiveControlInboxSnapshot(
              selectedClientId: 'CLIENT-001',
              selectedSiteId: 'SITE-SANDTON',
              selectedScopeClientVoiceProfileLabel: 'Validation-heavy',
              pendingApprovalCount: 2,
              selectedScopePendingCount: 1,
              telegramHealthLabel: 'degraded',
              pendingDrafts: [
                LiveControlInboxDraft(
                  updateId: 502,
                  clientId: 'CLIENT-VALLEE',
                  siteId: 'SITE-RESIDENCE',
                  sourceText:
                      'Please confirm if the response team has already arrived.',
                  draftText:
                      'Command is confirming arrival now and will share the verified position as soon as it is locked.',
                  providerLabel: 'OpenAI',
                  createdAtUtc: DateTime.utc(2026, 3, 18, 5, 56),
                  clientVoiceProfileLabel: 'Concise',
                ),
                LiveControlInboxDraft(
                  updateId: 501,
                  clientId: 'CLIENT-001',
                  siteId: 'SITE-SANDTON',
                  sourceText:
                      'Hi ONYX, are we still waiting on the patrol update?',
                  draftText:
                      'We are checking the latest patrol position now and will send the next verified update shortly.',
                  providerLabel: 'OpenAI',
                  createdAtUtc: DateTime.utc(2026, 3, 18, 6, 0),
                  clientVoiceProfileLabel: 'Validation-heavy',
                  matchesSelectedScope: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final controlInboxPanel = find.byKey(const ValueKey('control-inbox-panel'));
      expect(tester.getTopLeft(controlInboxPanel).dy, greaterThan(320));

      await tester.tap(find.byKey(const ValueKey('top-bar-priority-chip')).first);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('control-inbox-summary-pill-timing')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Queue Timing only'), findsWidgets);
      expect(find.text('Timing only'), findsWidgets);
      expect(
        find.text(
          'Showing timing only. Tap the same pill again or use Show all replies to return to the full queue.',
        ),
        findsOneWidget,
      );

      final topBarCueChip = find.byKey(
        const ValueKey('top-bar-cue-filter-chip'),
      ).first;
      await tester.ensureVisible(topBarCueChip);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 260));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(controlInboxPanel).dy, greaterThan(320));

      await tester.tap(topBarCueChip);
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(controlInboxPanel).dy, lessThan(320));
      expect(find.text('Queue High priority'), findsWidgets);
      expect(find.byKey(const ValueKey('top-bar-cue-filter-chip')), findsNothing);
      expect(find.text('Show all replies (1)'), findsWidgets);
      expect(
        find.text(
          'Showing high-priority only. Tap the badge again to return to the full queue.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('control-inbox-draft-501')), findsNothing);
      expect(find.byKey(const ValueKey('control-inbox-draft-502')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('top-bar-priority-chip')).first);
      await tester.pumpAndSettle();

      expect(find.text('Queue Full'), findsWidgets);
      expect(find.text('1 validation'), findsOneWidget);
      expect(find.byKey(const ValueKey('control-inbox-draft-501')), findsOneWidget);
    },
  );

  testWidgets(
    'live operations top-bar priority chip turns red for sensitive drafts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const [],
            controlInboxSnapshot: LiveControlInboxSnapshot(
              selectedClientId: 'CLIENT-001',
              selectedSiteId: 'SITE-SANDTON',
              pendingApprovalCount: 1,
              selectedScopePendingCount: 1,
              telegramHealthLabel: 'degraded',
              pendingDrafts: [
                LiveControlInboxDraft(
                  updateId: 503,
                  clientId: 'CLIENT-001',
                  siteId: 'SITE-SANDTON',
                  sourceText: 'Fire alarm triggered. Is everyone safe?',
                  draftText:
                      'We are treating this as active and checking the fire response now.',
                  providerLabel: 'OpenAI',
                  createdAtUtc: DateTime.utc(2026, 3, 18, 6, 5),
                  clientVoiceProfileLabel: 'Reassuring',
                  matchesSelectedScope: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final priorityChip = tester.widget<Container>(
        find.byKey(const ValueKey('top-bar-priority-chip')).first,
      );
      final decoration = priorityChip.decoration! as BoxDecoration;

      expect(find.text('1 Sensitive Reply'), findsWidgets);
      expect(find.text('1 sensitive'), findsOneWidget);
      expect(decoration.color, const Color(0x33EF4444));
      expect(decoration.border, isNotNull);
      expect((decoration.border! as Border).top.color, const Color(0x66EF4444));
    },
  );

  testWidgets(
    'live operations control inbox badge says sensitive for sensitive drafts',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const [],
            controlInboxSnapshot: LiveControlInboxSnapshot(
              selectedClientId: 'CLIENT-001',
              selectedSiteId: 'SITE-SANDTON',
              pendingApprovalCount: 1,
              selectedScopePendingCount: 1,
              telegramHealthLabel: 'degraded',
              pendingDrafts: [
                LiveControlInboxDraft(
                  updateId: 503,
                  clientId: 'CLIENT-001',
                  siteId: 'SITE-SANDTON',
                  sourceText: 'Fire alarm triggered. Is everyone safe?',
                  draftText:
                      'We are treating this as active and checking the fire response now.',
                  providerLabel: 'OpenAI',
                  createdAtUtc: DateTime.utc(2026, 3, 18, 6, 5),
                  clientVoiceProfileLabel: 'Reassuring',
                  matchesSelectedScope: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('control-inbox-priority-badge')), findsOneWidget);
      expect(find.text('Sensitive 1'), findsOneWidget);
      expect(find.text('1 sensitive'), findsOneWidget);
    },
  );
}
