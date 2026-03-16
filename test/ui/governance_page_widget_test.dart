import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/morning_sovereign_report_service.dart';
import 'package:omnix_dashboard/domain/events/partner_dispatch_status_declared.dart';
import 'package:omnix_dashboard/domain/events/report_generated.dart';
import 'package:omnix_dashboard/domain/events/vehicle_visit_review_recorded.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/governance_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('governance page stays stable on phone viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: GovernancePage(events: [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('VIGILANCE MONITOR'), findsOneWidget);
    expect(find.text('COMPLIANCE ALERTS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('governance page stays stable on landscape phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: GovernancePage(events: [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('VIGILANCE MONITOR'), findsOneWidget);
    expect(find.text('COMPLIANCE ALERTS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('governance page renders persisted morning report metadata', (
    tester,
  ) async {
    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: DateTime.utc(2026, 3, 10, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 9, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 10, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 184,
        hashVerified: true,
        integrityScore: 98,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 24,
        humanOverrides: 3,
        overrideReasons: {'PSIRA expired': 2},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 14,
        driftDetected: 2,
        avgMatchScore: 84,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 2,
        pdpExpired: 1,
        totalBlocked: 3,
      ),
      receiptPolicy: const SovereignReportReceiptPolicy(
        generatedReports: 2,
        trackedConfigurationReports: 1,
        legacyConfigurationReports: 1,
        fullyIncludedReports: 0,
        reportsWithOmittedSections: 1,
        omittedAiDecisionLogReports: 1,
        omittedGuardMetricsReports: 1,
        standardBrandingReports: 1,
        defaultPartnerBrandingReports: 0,
        customBrandingOverrideReports: 1,
        governanceHandoffReports: 1,
        routineReviewReports: 1,
        executiveSummary:
            '1 client-facing receipt omitted sections • 1 legacy receipt lacked tracked policy',
        brandingExecutiveSummary: '1 receipt used custom branding override',
        investigationExecutiveSummary:
            '1 receipt investigation came from Governance branding drift • 1 receipt investigation remained routine review',
        headline: '1 generated reports omitted sections',
        summaryLine:
            'Reports 2 • Tracked 1 • Legacy 1 • Full 0 • Omitted 1 • AI log omitted 1 • Guard metrics omitted 1 • Standard branding 1 • Default partner branding 0 • Custom branding 1',
        latestReportSummary:
            'CLIENT-1/SITE-42 2026-03 omitted AI Decision Log, Guard Metrics.',
        latestBrandingSummary:
            'CLIENT-1/SITE-42 2026-03 used custom branding override from Partner Alpha.',
        latestInvestigationSummary:
            'CLIENT-1/SITE-42 2026-03 remained routine report review.',
      ),
      sceneReview: const SovereignReportSceneReview(
        totalReviews: 7,
        modelReviews: 5,
        metadataFallbackReviews: 2,
        suppressedActions: 1,
        incidentAlerts: 2,
        repeatUpdates: 2,
        escalationCandidates: 2,
        topPosture: 'escalation candidate',
        actionMixSummary:
            '2 alerts • 2 repeat updates • 2 escalations • 1 suppressed review',
        latestActionTaken:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line.',
        recentActionsSummary:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)',
        latestSuppressedPattern:
            '2026-03-10T01:10:00.000Z • Camera 2 • Vehicle remained below escalation threshold.',
      ),
      vehicleThroughput: SovereignReportVehicleThroughput(
        totalVisits: 18,
        completedVisits: 15,
        activeVisits: 2,
        incompleteVisits: 1,
        uniqueVehicles: 16,
        repeatVehicles: 2,
        unknownVehicleEvents: 1,
        peakHourLabel: '23:00-00:00',
        peakHourVisitCount: 6,
        averageCompletedDwellMinutes: 17.4,
        suspiciousShortVisitCount: 1,
        loiteringVisitCount: 0,
        workflowHeadline:
            '15 completed visits reached EXIT • 1 incomplete visit stalled at SERVICE',
        summaryLine:
            'Visits 18 • Entry 18 • Completed 15 • Active 2 • Incomplete 1 • Unique 16 • Repeat 2 • Avg dwell 17.4m • Peak 23:00-00:00 (6) • Short visits 1 • Unknown vehicle events 1',
        scopeBreakdowns: const [
          SovereignReportVehicleScopeBreakdown(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            totalVisits: 12,
            completedVisits: 10,
            activeVisits: 1,
            incompleteVisits: 1,
            unknownVehicleEvents: 1,
            summaryLine:
                'Visits 12 • Entry 12 • Completed 10 • Active 1 • Incomplete 1 • Unique 11 • Avg dwell 16.1m • Peak 23:00-00:00 (4) • Unknown vehicle events 1',
          ),
          SovereignReportVehicleScopeBreakdown(
            clientId: 'CLIENT-1',
            siteId: 'SITE-88',
            totalVisits: 6,
            completedVisits: 5,
            activeVisits: 1,
            incompleteVisits: 0,
            unknownVehicleEvents: 0,
            summaryLine:
                'Visits 6 • Entry 6 • Completed 5 • Active 1 • Incomplete 0 • Unique 5 • Repeat 1 • Avg dwell 20.0m • Peak 01:00-02:00 (2)',
          ),
        ],
        exceptionVisits: [
          SovereignReportVehicleVisitException(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            vehicleLabel: 'CA123456',
            statusLabel: 'INCOMPLETE',
            reasonLabel: 'Incomplete visit',
            workflowSummary: 'ENTRY -> SERVICE (INCOMPLETE)',
            primaryEventId: 'EVT-201',
            startedAtUtc: DateTime.utc(2026, 3, 10, 0, 40),
            lastSeenAtUtc: DateTime.utc(2026, 3, 10, 1, 22),
            dwellMinutes: 42.0,
            eventIds: ['EVT-201', 'EVT-202'],
            zoneLabels: ['Entry Lane', 'Wash Bay'],
            intelligenceIds: ['INT-201', 'INT-202'],
          ),
        ],
      ),
      partnerProgression: SovereignReportPartnerProgression(
        dispatchCount: 2,
        declarationCount: 5,
        acceptedCount: 2,
        onSiteCount: 1,
        allClearCount: 1,
        cancelledCount: 1,
        workflowHeadline:
            '1 partner dispatch reached ALL CLEAR • 1 partner dispatch was CANCELLED',
        performanceHeadline: '1 strong response • 1 critical response',
        slaHeadline: 'Avg accept 5.0m • Avg on site 12.0m',
        summaryLine:
            'Dispatches 2 • Declarations 5 • Accept 2 • On site 1 • All clear 1 • Cancelled 1',
        scopeBreakdowns: [
          SovereignReportPartnerScopeBreakdown(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            dispatchCount: 2,
            declarationCount: 5,
            latestStatus: PartnerDispatchStatus.cancelled,
            latestOccurredAtUtc: DateTime.utc(2026, 3, 10, 2, 18),
            summaryLine:
                'Dispatches 2 • Declarations 5 • Latest CANCELLED @ 2026-03-10T02:18:00.000Z',
          ),
        ],
        scoreboardRows: [
          SovereignReportPartnerScoreboardRow(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            partnerLabel: 'Partner Alpha',
            dispatchCount: 2,
            strongCount: 1,
            onTrackCount: 0,
            watchCount: 0,
            criticalCount: 1,
            averageAcceptedDelayMinutes: 5.0,
            averageOnSiteDelayMinutes: 13.0,
            summaryLine:
                'Dispatches 2 • Strong 1 • On track 0 • Watch 0 • Critical 1 • Avg accept 5.0m • Avg on site 13.0m',
          ),
        ],
        dispatchChains: [
          SovereignReportPartnerDispatchChain(
            dispatchId: 'DSP-42',
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            partnerLabel: 'Partner Alpha',
            declarationCount: 3,
            latestStatus: PartnerDispatchStatus.allClear,
            latestOccurredAtUtc: DateTime.utc(2026, 3, 10, 1, 55),
            dispatchCreatedAtUtc: DateTime.utc(2026, 3, 10, 1, 35),
            acceptedAtUtc: DateTime.utc(2026, 3, 10, 1, 40),
            onSiteAtUtc: DateTime.utc(2026, 3, 10, 1, 48),
            allClearAtUtc: DateTime.utc(2026, 3, 10, 1, 55),
            acceptedDelayMinutes: 5.0,
            onSiteDelayMinutes: 13.0,
            scoreLabel: 'STRONG',
            scoreReason:
                'Partner reached ALL CLEAR inside target acceptance and on-site windows.',
            workflowSummary:
                'ACCEPT -> ON SITE -> ALL CLEAR (LATEST ALL CLEAR)',
          ),
          SovereignReportPartnerDispatchChain(
            dispatchId: 'DSP-43',
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            partnerLabel: 'Partner Alpha',
            declarationCount: 2,
            latestStatus: PartnerDispatchStatus.cancelled,
            latestOccurredAtUtc: DateTime.utc(2026, 3, 10, 2, 18),
            dispatchCreatedAtUtc: DateTime.utc(2026, 3, 10, 2, 0),
            acceptedAtUtc: DateTime.utc(2026, 3, 10, 2, 5),
            cancelledAtUtc: DateTime.utc(2026, 3, 10, 2, 18),
            acceptedDelayMinutes: 5.0,
            scoreLabel: 'CRITICAL',
            scoreReason:
                'Dispatch was cancelled before the partner completed the response chain.',
            workflowSummary: 'ACCEPT -> CANCELLED (LATEST CANCELLED)',
          ),
        ],
      ),
    );

    final priorReport = SovereignReport(
      date: '2026-03-09',
      generatedAtUtc: DateTime.utc(2026, 3, 9, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 8, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 9, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 150,
        hashVerified: true,
        integrityScore: 97,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 18,
        humanOverrides: 2,
        overrideReasons: <String, int>{},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 12,
        driftDetected: 1,
        avgMatchScore: 82,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 0,
        pdpExpired: 0,
        totalBlocked: 0,
      ),
      receiptPolicy: const SovereignReportReceiptPolicy(
        generatedReports: 2,
        trackedConfigurationReports: 2,
        legacyConfigurationReports: 0,
        fullyIncludedReports: 1,
        reportsWithOmittedSections: 1,
        omittedAiDecisionLogReports: 1,
        omittedGuardMetricsReports: 0,
        standardBrandingReports: 1,
        defaultPartnerBrandingReports: 1,
        customBrandingOverrideReports: 0,
        executiveSummary:
            '1 client-facing receipt omitted sections • 1 client-facing receipt kept full policy',
        brandingExecutiveSummary:
            '1 receipt used default partner branding • 1 receipt used standard ONYX branding',
        headline: '1 generated reports omitted sections',
        summaryLine:
            'Reports 2 • Tracked 2 • Legacy 0 • Full 1 • Omitted 1 • AI log omitted 1 • Guard metrics omitted 0 • Standard branding 1 • Default partner branding 1 • Custom branding 0',
        latestReportSummary:
            'CLIENT-1/SITE-42 2026-03 omitted AI Decision Log.',
        latestBrandingSummary:
            'CLIENT-1/SITE-42 2026-03 used default partner branding from Partner Alpha.',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: [],
          morningSovereignReport: report,
          morningSovereignReportHistory: [priorReport],
          morningSovereignReportAutoRunKey: '2026-03-10',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Auto generated for shift ending 2026-03-10'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Generated 2026-03-10 06:00 UTC'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Override Reasons: PSIRA expired (2)'),
      findsOneWidget,
    );
    expect(find.text('Receipt Policy'), findsOneWidget);
    expect(find.text('2 reports'), findsOneWidget);
    expect(
      find.textContaining(
        '1 client-facing receipt omitted sections • 1 legacy receipt lacked tracked policy',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('1 receipt used custom branding override'),
      findsOneWidget,
    );
    expect(find.text('Receipt branding drift (7 days)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('governance-receipt-branding-trend-card')),
      findsOneWidget,
    );
    expect(find.text('CUSTOM BRANDING'), findsWidgets);
    expect(find.text('SLIPPING'), findsWidgets);
    expect(
      find.textContaining(
        'Custom branding overrides increased against recent shifts.',
      ),
      findsOneWidget,
    );
    expect(find.text('Receipt investigation drift (7 days)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('governance-receipt-investigation-trend-card')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-receipt-investigation-trend-card')),
    );
    await tester.pumpAndSettle();
    expect(find.text('OVERSIGHT HANDOFF'), findsWidgets);
    expect(find.text('Current Governance: 1'), findsOneWidget);
    expect(find.text('Current Routine: 1'), findsOneWidget);
    expect(find.text('Baseline Governance: 0.0'), findsOneWidget);
    expect(find.text('Baseline Routine: 0.0'), findsOneWidget);
    expect(
      find.textContaining(
        'Governance-opened receipt investigations increased against recent shifts.',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-receipt-branding-trend-card')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('governance-receipt-branding-trend-card')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('governance-receipt-branding-dialog')),
      findsOneWidget,
    );
    expect(find.text('RECEIPT BRANDING DRILL-IN'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('governance-receipt-branding-history-2026-03-10'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('governance-receipt-branding-history-2026-03-09'),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Reports 2 • Shift receipts 0 • Custom 1 • Default 0 • Standard 1',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '1 receipt used default partner branding • 1 receipt used standard ONYX branding',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-receipt-investigation-trend-card')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-receipt-investigation-trend-card')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('governance-receipt-investigation-dialog')),
      findsOneWidget,
    );
    expect(find.text('RECEIPT INVESTIGATION DRILL-IN'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('governance-receipt-investigation-history-2026-03-10'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('governance-receipt-investigation-history-2026-03-09'),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Reports 2 • Shift receipts 0 • Governance 1 • Routine 1',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '1 receipt investigation came from Governance branding drift • 1 receipt investigation remained routine review',
      ),
      findsWidgets,
    );
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'CLIENT-1/SITE-42 2026-03 omitted AI Decision Log, Guard Metrics.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Model 5 • Alerts 2 • Repeat 2 • Escalations 2 • Top escalation candidate',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Action mix: 2 alerts • 2 repeat updates • 2 escalations • 1 suppressed review',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Latest action taken: 2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Recent actions: 2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Latest filtered pattern: 2026-03-10T01:10:00.000Z • Camera 2 • Vehicle remained below escalation threshold.',
      ),
      findsOneWidget,
    );
    expect(find.text('Vehicle Throughput'), findsOneWidget);
    expect(find.text('Partner Progression'), findsOneWidget);
    expect(
      find.text(
        '15 completed visits reached EXIT • 1 incomplete visit stalled at SERVICE',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '1 partner dispatch reached ALL CLEAR • 1 partner dispatch was CANCELLED',
      ),
      findsOneWidget,
    );
    expect(
      find.text('1 strong response • 1 critical response'),
      findsNWidgets(2),
    );
    expect(find.text('Avg accept 5.0m • Avg on site 12.0m'), findsOneWidget);
    expect(find.text('Vehicle site ledger'), findsOneWidget);
    expect(find.text('Vehicle exception review'), findsOneWidget);
    expect(find.text('Partner dispatch sites'), findsOneWidget);
    expect(find.text('Partner scoreboard'), findsOneWidget);
    expect(find.text('Partner dispatch progression'), findsOneWidget);
    expect(
      find.textContaining('CLIENT-1/SITE-42 • Partner Alpha'),
      findsNWidgets(2),
    );
    expect(
      find.text(
        'Dispatches 2 • Strong 1 • On track 0 • Watch 0 • Critical 1 • Avg accept 5.0m • Avg on site 13.0m',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Partner Alpha • DSP-42'), findsOneWidget);
    expect(
      find.text('Workflow: ACCEPT -> ON SITE -> ALL CLEAR (LATEST ALL CLEAR)'),
      findsOneWidget,
    );
    expect(
      find.text('SLA: accepted in 5.0m • on site in 13.0m'),
      findsOneWidget,
    );
    expect(find.text('STRONG'), findsOneWidget);
    expect(
      find.text(
        'Scorecard: Partner reached ALL CLEAR inside target acceptance and on-site windows.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('CLIENT-1/SITE-42'), findsWidgets);
    expect(find.textContaining('Incomplete visit • CA123456'), findsOneWidget);
    expect(
      find.text('Workflow: ENTRY -> SERVICE (INCOMPLETE)'),
      findsOneWidget,
    );
    expect(find.text('Copy Morning JSON'), findsOneWidget);
    expect(find.text('Download Morning CSV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('governance page renders partner trends from report history', (
    tester,
  ) async {
    SovereignReport buildReport({
      required String date,
      required DateTime generatedAtUtc,
      required int dispatchCount,
      required int strongCount,
      required int onTrackCount,
      required int watchCount,
      required int criticalCount,
      required double acceptedDelayMinutes,
      required double onSiteDelayMinutes,
      required String summaryLine,
      List<SovereignReportPartnerDispatchChain> dispatchChains =
          const <SovereignReportPartnerDispatchChain>[],
    }) {
      return SovereignReport(
        date: date,
        generatedAtUtc: generatedAtUtc,
        shiftWindowStartUtc: generatedAtUtc.subtract(const Duration(hours: 8)),
        shiftWindowEndUtc: generatedAtUtc,
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
          dispatchCount: dispatchCount,
          declarationCount: dispatchCount,
          acceptedCount: dispatchCount,
          onSiteCount: criticalCount == 0 ? dispatchCount : 0,
          allClearCount: strongCount,
          cancelledCount: criticalCount,
          workflowHeadline: '',
          performanceHeadline: '',
          slaHeadline: '',
          summaryLine: '',
          scoreboardRows: [
            SovereignReportPartnerScoreboardRow(
              clientId: 'CLIENT-1',
              siteId: 'SITE-42',
              partnerLabel: 'Partner Alpha',
              dispatchCount: dispatchCount,
              strongCount: strongCount,
              onTrackCount: onTrackCount,
              watchCount: watchCount,
              criticalCount: criticalCount,
              averageAcceptedDelayMinutes: acceptedDelayMinutes,
              averageOnSiteDelayMinutes: onSiteDelayMinutes,
              summaryLine: summaryLine,
            ),
          ],
          dispatchChains: dispatchChains,
        ),
      );
    }

    final priorReport = buildReport(
      date: '2026-03-09',
      generatedAtUtc: DateTime.utc(2026, 3, 9, 6, 0),
      dispatchCount: 2,
      strongCount: 0,
      onTrackCount: 0,
      watchCount: 1,
      criticalCount: 1,
      acceptedDelayMinutes: 12.0,
      onSiteDelayMinutes: 22.0,
      summaryLine:
          'Dispatches 2 • Strong 0 • On track 0 • Watch 1 • Critical 1 • Avg accept 12.0m • Avg on site 22.0m',
    );
    final currentReport = buildReport(
      date: '2026-03-10',
      generatedAtUtc: DateTime.utc(2026, 3, 10, 6, 0),
      dispatchCount: 2,
      strongCount: 2,
      onTrackCount: 0,
      watchCount: 0,
      criticalCount: 0,
      acceptedDelayMinutes: 4.0,
      onSiteDelayMinutes: 10.0,
      summaryLine:
          'Dispatches 2 • Strong 2 • On track 0 • Watch 0 • Critical 0 • Avg accept 4.0m • Avg on site 10.0m',
      dispatchChains: [
        SovereignReportPartnerDispatchChain(
          dispatchId: 'DSP-200',
          clientId: 'CLIENT-1',
          siteId: 'SITE-42',
          partnerLabel: 'Partner Alpha',
          declarationCount: 3,
          latestStatus: PartnerDispatchStatus.allClear,
          latestOccurredAtUtc: DateTime.utc(2026, 3, 10, 1, 30),
          dispatchCreatedAtUtc: DateTime.utc(2026, 3, 10, 1, 0),
          acceptedAtUtc: DateTime.utc(2026, 3, 10, 1, 4),
          onSiteAtUtc: DateTime.utc(2026, 3, 10, 1, 10),
          allClearAtUtc: DateTime.utc(2026, 3, 10, 1, 30),
          acceptedDelayMinutes: 4.0,
          onSiteDelayMinutes: 10.0,
          scoreLabel: 'STRONG',
          scoreReason:
              'Partner reached ALL CLEAR inside target acceptance and on-site windows.',
          workflowSummary: 'ACCEPT -> ON SITE -> ALL CLEAR (LATEST ALL CLEAR)',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const [],
          morningSovereignReport: currentReport,
          morningSovereignReportHistory: [priorReport],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partner trends (7 days)'), findsOneWidget);
    expect(find.text('IMPROVING'), findsOneWidget);
    expect(
      find.textContaining(
        'Days 2 • Dispatches 4 • Strong 2 • On track 0 • Watch 1 • Critical 1',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Acceptance timing improved against the prior 7-day average.'),
      findsOneWidget,
    );

    final scoreboardFinder = find.byKey(
      const ValueKey(
        'governance-partner-scoreboard-CLIENT-1/SITE-42-Partner Alpha',
      ),
    );
    await tester.ensureVisible(scoreboardFinder);
    await tester.tap(scoreboardFinder);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('governance-partner-scoreboard-dialog')),
      findsOneWidget,
    );
    expect(find.text('PARTNER SCORECARD DRILL-IN'), findsOneWidget);
    expect(find.text('7-day scoreboard history'), findsOneWidget);
    expect(find.text('2026-03-10 • CURRENT'), findsOneWidget);
    expect(find.text('2026-03-09'), findsOneWidget);
    expect(find.text('Current dispatch chains'), findsOneWidget);
    expect(find.textContaining('DSP-200 • STRONG'), findsOneWidget);
    expect(
      find.text('ACCEPT -> ON SITE -> ALL CLEAR (LATEST ALL CLEAR)'),
      findsOneWidget,
    );
  });

  testWidgets('governance receipt policy metric drills into shift receipts', (
    tester,
  ) async {
    String? openedReceiptEventId;
    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: DateTime.utc(2026, 3, 10, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 9, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 10, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 184,
        hashVerified: true,
        integrityScore: 98,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 24,
        humanOverrides: 3,
        overrideReasons: {'PSIRA expired': 2},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 14,
        driftDetected: 2,
        avgMatchScore: 84,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 2,
        pdpExpired: 1,
        totalBlocked: 3,
      ),
      receiptPolicy: const SovereignReportReceiptPolicy(
        generatedReports: 2,
        trackedConfigurationReports: 1,
        legacyConfigurationReports: 1,
        fullyIncludedReports: 0,
        reportsWithOmittedSections: 1,
        omittedAiDecisionLogReports: 1,
        omittedGuardMetricsReports: 1,
        standardBrandingReports: 1,
        defaultPartnerBrandingReports: 0,
        customBrandingOverrideReports: 1,
        governanceHandoffReports: 1,
        routineReviewReports: 1,
        executiveSummary:
            '1 client-facing receipt omitted sections • 1 legacy receipt lacked tracked policy',
        brandingExecutiveSummary: '1 receipt used custom branding override',
        investigationExecutiveSummary:
            '1 receipt investigation came from Governance branding drift • 1 receipt investigation remained routine review',
        headline: '1 generated reports omitted sections',
        summaryLine:
            'Reports 2 • Tracked 1 • Legacy 1 • Full 0 • Omitted 1 • AI log omitted 1 • Guard metrics omitted 1 • Standard branding 1 • Default partner branding 0 • Custom branding 1',
        latestReportSummary:
            'CLIENT-1/SITE-42 2026-03 omitted AI Decision Log, Guard Metrics.',
        latestBrandingSummary:
            'CLIENT-1/SITE-42 2026-03 used custom branding override from Partner Alpha.',
        latestInvestigationSummary:
            'CLIENT-1/SITE-42 2026-03 remained routine report review.',
      ),
      sceneReview: const SovereignReportSceneReview(
        totalReviews: 7,
        modelReviews: 5,
        metadataFallbackReviews: 2,
        suppressedActions: 1,
        incidentAlerts: 2,
        repeatUpdates: 2,
        escalationCandidates: 2,
        topPosture: 'escalation candidate',
        actionMixSummary:
            '2 alerts • 2 repeat updates • 2 escalations • 1 suppressed review',
        latestActionTaken:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line.',
        recentActionsSummary:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)',
        latestSuppressedPattern:
            '2026-03-10T01:10:00.000Z • Camera 2 • Vehicle remained below escalation threshold.',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: [
            ReportGenerated(
              eventId: 'RPT-TRACKED',
              sequence: 40,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 10, 2, 20),
              clientId: 'CLIENT-1',
              siteId: 'SITE-42',
              month: '2026-03',
              contentHash: 'content-hash-1',
              pdfHash: 'pdf-hash-1',
              eventRangeStart: 10,
              eventRangeEnd: 18,
              eventCount: 9,
              reportSchemaVersion: 3,
              projectionVersion: 1,
              primaryBrandLabel: 'VISION Tactical',
              endorsementLine: 'Powered by ONYX',
              brandingSourceLabel: 'PARTNER • Alpha',
              brandingUsesOverride: true,
              investigationContextKey: 'governance_branding_drift',
              includeAiDecisionLog: false,
              includeGuardMetrics: false,
            ),
            ReportGenerated(
              eventId: 'RPT-LEGACY',
              sequence: 41,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 10, 2, 40),
              clientId: 'CLIENT-1',
              siteId: 'SITE-7',
              month: '2026-03',
              contentHash: 'content-hash-2',
              pdfHash: 'pdf-hash-2',
              eventRangeStart: 19,
              eventRangeEnd: 25,
              eventCount: 7,
              reportSchemaVersion: 1,
              projectionVersion: 1,
            ),
            ReportGenerated(
              eventId: 'RPT-OLD',
              sequence: 42,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 10, 8, 0),
              clientId: 'CLIENT-1',
              siteId: 'SITE-OLD',
              month: '2026-03',
              contentHash: 'content-hash-3',
              pdfHash: 'pdf-hash-3',
              eventRangeStart: 26,
              eventRangeEnd: 30,
              eventCount: 5,
              reportSchemaVersion: 3,
              projectionVersion: 1,
            ),
          ],
          morningSovereignReport: report,
          morningSovereignReportAutoRunKey: '2026-03-10',
          onOpenReceiptPolicyEvent: (eventId) {
            openedReceiptEventId = eventId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-metric-receipt-policy')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-metric-receipt-policy')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('governance-receipt-policy-dialog')),
      findsOneWidget,
    );
    expect(find.text('RECEIPT POLICY DRILL-IN'), findsOneWidget);
    expect(
      find.text(
        '1 client-facing receipt omitted sections • 1 legacy receipt lacked tracked policy',
      ),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('governance-receipt-policy-entry-RPT-TRACKED')),
      findsOneWidget,
    );
    expect(find.text('CUSTOM BRANDING'), findsWidgets);
    expect(find.text('2 sections omitted • Custom branding'), findsOneWidget);
    expect(
      find.text(
        'Branding: custom override from default partner lane PARTNER • Alpha. Included: Incident Timeline, Dispatch Summary, Checkpoint Compliance. Omitted: AI Decision Log, Guard Metrics.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('governance-receipt-policy-entry-RPT-LEGACY')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('governance-receipt-policy-entry-RPT-OLD')),
      findsNothing,
    );
    expect(find.text('All sections included'), findsNothing);
    expect(find.text('2 sections omitted • Custom branding'), findsOneWidget);
    expect(find.text('Legacy receipt configuration'), findsOneWidget);
    expect(
      find.textContaining(
        'Included: Incident Timeline, Dispatch Summary, Checkpoint Compliance. Omitted: AI Decision Log, Guard Metrics.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Per-section report configuration was not captured for this generated receipt.',
      ),
      findsOneWidget,
    );
    expect(find.text('Open Events Review'), findsNWidgets(2));

    await tester.tap(
      find.byKey(
        const ValueKey('governance-receipt-policy-open-events-RPT-TRACKED'),
      ),
    );
    await tester.pumpAndSettle();

    expect(openedReceiptEventId, 'RPT-TRACKED');
    expect(
      find.byKey(const ValueKey('governance-receipt-policy-dialog')),
      findsNothing,
    );
  });

  testWidgets('governance partner scorecard drill-in can open scoped reports', (
    tester,
  ) async {
    Map<String, String>? openedScope;
    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: DateTime.utc(2026, 3, 10, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 9, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 10, 6, 0),
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
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            partnerLabel: 'Partner Alpha',
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
        dispatchChains: [
          SovereignReportPartnerDispatchChain(
            dispatchId: 'DSP-200',
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            partnerLabel: 'Partner Alpha',
            declarationCount: 3,
            latestStatus: PartnerDispatchStatus.allClear,
            latestOccurredAtUtc: DateTime.utc(2026, 3, 10, 1, 30),
            dispatchCreatedAtUtc: DateTime.utc(2026, 3, 10, 1, 0),
            acceptedAtUtc: DateTime.utc(2026, 3, 10, 1, 4),
            onSiteAtUtc: DateTime.utc(2026, 3, 10, 1, 10),
            allClearAtUtc: DateTime.utc(2026, 3, 10, 1, 30),
            acceptedDelayMinutes: 4.0,
            onSiteDelayMinutes: 10.0,
            scoreLabel: 'STRONG',
            scoreReason:
                'Partner reached ALL CLEAR inside target acceptance and on-site windows.',
            workflowSummary:
                'ACCEPT -> ON SITE -> ALL CLEAR (LATEST ALL CLEAR)',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const [],
          morningSovereignReport: report,
          onOpenReportsForPartnerScope: (clientId, siteId, partnerLabel) {
            openedScope = <String, String>{
              'clientId': clientId,
              'siteId': siteId,
              'partnerLabel': partnerLabel,
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scoreboardFinder = find.byKey(
      const ValueKey(
        'governance-partner-scoreboard-CLIENT-1/SITE-42-Partner Alpha',
      ),
    );
    await tester.ensureVisible(scoreboardFinder);
    await tester.tap(scoreboardFinder);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey('governance-partner-scorecard-open-reports-scope'),
      ),
    );
    await tester.pumpAndSettle();

    expect(openedScope, <String, String>{
      'clientId': 'CLIENT-1',
      'siteId': 'SITE-42',
      'partnerLabel': 'Partner Alpha',
    });
    expect(find.textContaining('Opening Reports for SITE-42'), findsOneWidget);
  });

  testWidgets(
    'governance receipt branding drill-in can open reports for the selected shift',
    (tester) async {
      Map<String, String>? openedReceiptScope;
      SovereignReport buildReport({
        required String date,
        required DateTime generatedAtUtc,
        required DateTime shiftWindowStartUtc,
        required DateTime shiftWindowEndUtc,
        required int standardBrandingReports,
        required int defaultPartnerBrandingReports,
        required int customBrandingOverrideReports,
        required String brandingExecutiveSummary,
        required String latestBrandingSummary,
      }) {
        return SovereignReport(
          date: date,
          generatedAtUtc: generatedAtUtc,
          shiftWindowStartUtc: shiftWindowStartUtc,
          shiftWindowEndUtc: shiftWindowEndUtc,
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
          receiptPolicy: SovereignReportReceiptPolicy(
            generatedReports: 1,
            trackedConfigurationReports: 1,
            legacyConfigurationReports: 0,
            fullyIncludedReports: 1,
            reportsWithOmittedSections: 0,
            omittedAiDecisionLogReports: 0,
            omittedGuardMetricsReports: 0,
            standardBrandingReports: standardBrandingReports,
            defaultPartnerBrandingReports: defaultPartnerBrandingReports,
            customBrandingOverrideReports: customBrandingOverrideReports,
            executiveSummary: '1 client-facing receipt kept full policy',
            brandingExecutiveSummary: brandingExecutiveSummary,
            headline: '1 generated report kept full policy',
            summaryLine:
                'Reports 1 • Tracked 1 • Legacy 0 • Full 1 • Omitted 0',
            latestReportSummary: 'CLIENT-1/SITE-42 $date kept full policy.',
            latestBrandingSummary: latestBrandingSummary,
          ),
        );
      }

      final currentReport = buildReport(
        date: '2026-03-10',
        generatedAtUtc: DateTime.utc(2026, 3, 10, 6, 0),
        shiftWindowStartUtc: DateTime.utc(2026, 3, 9, 22, 0),
        shiftWindowEndUtc: DateTime.utc(2026, 3, 10, 6, 0),
        standardBrandingReports: 0,
        defaultPartnerBrandingReports: 0,
        customBrandingOverrideReports: 1,
        brandingExecutiveSummary: '1 receipt used custom branding override',
        latestBrandingSummary:
            'CLIENT-1/SITE-42 2026-03 used custom branding override from Partner Alpha.',
      );
      final priorReport = buildReport(
        date: '2026-03-09',
        generatedAtUtc: DateTime.utc(2026, 3, 9, 6, 0),
        shiftWindowStartUtc: DateTime.utc(2026, 3, 8, 22, 0),
        shiftWindowEndUtc: DateTime.utc(2026, 3, 9, 6, 0),
        standardBrandingReports: 1,
        defaultPartnerBrandingReports: 0,
        customBrandingOverrideReports: 0,
        brandingExecutiveSummary: '1 receipt used standard ONYX branding',
        latestBrandingSummary:
            'CLIENT-1/SITE-42 2026-03 used standard ONYX branding.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GovernancePage(
            events: [
              ReportGenerated(
                eventId: 'RPT-CURRENT',
                sequence: 50,
                version: 1,
                occurredAt: DateTime.utc(2026, 3, 10, 2, 30),
                clientId: 'CLIENT-1',
                siteId: 'SITE-42',
                month: '2026-03',
                contentHash: 'content-current',
                pdfHash: 'pdf-current',
                eventRangeStart: 1,
                eventRangeEnd: 10,
                eventCount: 10,
                reportSchemaVersion: 3,
                projectionVersion: 1,
                primaryBrandLabel: 'VISION Tactical',
                endorsementLine: 'Powered by ONYX',
                brandingSourceLabel: 'PARTNER • Alpha',
                brandingUsesOverride: true,
              ),
              ReportGenerated(
                eventId: 'RPT-PRIOR',
                sequence: 40,
                version: 1,
                occurredAt: DateTime.utc(2026, 3, 9, 2, 0),
                clientId: 'CLIENT-1',
                siteId: 'SITE-42',
                month: '2026-03',
                contentHash: 'content-prior',
                pdfHash: 'pdf-prior',
                eventRangeStart: 11,
                eventRangeEnd: 18,
                eventCount: 8,
                reportSchemaVersion: 3,
                projectionVersion: 1,
              ),
            ],
            morningSovereignReport: currentReport,
            morningSovereignReportHistory: [priorReport],
            onOpenReportsForReceiptEvent: (clientId, siteId, receiptEventId) {
              openedReceiptScope = <String, String>{
                'clientId': clientId,
                'siteId': siteId,
                'receiptEventId': receiptEventId,
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final trendFinder = find.byKey(
        const ValueKey('governance-receipt-branding-trend-card'),
      );
      await tester.ensureVisible(trendFinder);
      await tester.tap(trendFinder);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('governance-receipt-branding-open-reports-2026-03-10'),
        ),
      );
      await tester.pumpAndSettle();

      expect(openedReceiptScope, <String, String>{
        'clientId': 'CLIENT-1',
        'siteId': 'SITE-42',
        'receiptEventId': 'RPT-CURRENT',
      });
      expect(
        find.textContaining('Opening Reports for SITE-42'),
        findsOneWidget,
      );
    },
  );

  testWidgets('governance page scopes partner reporting to a selected site and partner', (
    tester,
  ) async {
    SovereignReport buildReport({
      required String date,
      required DateTime generatedAtUtc,
      required List<SovereignReportPartnerScoreboardRow> scoreboardRows,
      required List<SovereignReportPartnerDispatchChain> dispatchChains,
      required List<SovereignReportPartnerScopeBreakdown> scopeBreakdowns,
    }) {
      return SovereignReport(
        date: date,
        generatedAtUtc: generatedAtUtc,
        shiftWindowStartUtc: generatedAtUtc.subtract(const Duration(hours: 8)),
        shiftWindowEndUtc: generatedAtUtc,
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
          sitesMonitored: 2,
          driftDetected: 0,
          avgMatchScore: 100,
        ),
        complianceBlockage: const SovereignReportComplianceBlockage(
          psiraExpired: 0,
          pdpExpired: 0,
          totalBlocked: 0,
        ),
        partnerProgression: SovereignReportPartnerProgression(
          dispatchCount: dispatchChains.length,
          declarationCount: dispatchChains.fold<int>(
            0,
            (sum, chain) => sum + chain.declarationCount,
          ),
          acceptedCount: dispatchChains
              .where((chain) => chain.acceptedAtUtc != null)
              .length,
          onSiteCount: dispatchChains
              .where((chain) => chain.onSiteAtUtc != null)
              .length,
          allClearCount: dispatchChains
              .where((chain) => chain.allClearAtUtc != null)
              .length,
          cancelledCount: dispatchChains
              .where((chain) => chain.cancelledAtUtc != null)
              .length,
          workflowHeadline: '2 partner dispatches in progress',
          performanceHeadline: '1 strong response • 1 critical response',
          slaHeadline: 'Avg accept 7.0m • Avg on site 15.0m',
          summaryLine:
              'Dispatches ${dispatchChains.length} • Declarations ${dispatchChains.fold<int>(0, (sum, chain) => sum + chain.declarationCount)}',
          scopeBreakdowns: scopeBreakdowns,
          scoreboardRows: scoreboardRows,
          dispatchChains: dispatchChains,
        ),
      );
    }

    final priorReport = buildReport(
      date: '2026-03-14',
      generatedAtUtc: DateTime.utc(2026, 3, 14, 6, 0),
      scopeBreakdowns: [
        SovereignReportPartnerScopeBreakdown(
          clientId: 'CLIENT-1',
          siteId: 'SITE-42',
          dispatchCount: 1,
          declarationCount: 2,
          latestStatus: PartnerDispatchStatus.cancelled,
          latestOccurredAtUtc: DateTime.utc(2026, 3, 14, 2, 12),
          summaryLine:
              'Dispatches 1 • Declarations 2 • Latest CANCELLED @ 2026-03-14T02:12:00.000Z',
        ),
        SovereignReportPartnerScopeBreakdown(
          clientId: 'CLIENT-2',
          siteId: 'SITE-77',
          dispatchCount: 1,
          declarationCount: 3,
          latestStatus: PartnerDispatchStatus.allClear,
          latestOccurredAtUtc: DateTime.utc(2026, 3, 14, 3, 10),
          summaryLine:
              'Dispatches 1 • Declarations 3 • Latest ALL CLEAR @ 2026-03-14T03:10:00.000Z',
        ),
      ],
      scoreboardRows: [
        SovereignReportPartnerScoreboardRow(
          clientId: 'CLIENT-1',
          siteId: 'SITE-42',
          partnerLabel: 'Partner Alpha',
          dispatchCount: 1,
          strongCount: 0,
          onTrackCount: 0,
          watchCount: 0,
          criticalCount: 1,
          averageAcceptedDelayMinutes: 12.0,
          averageOnSiteDelayMinutes: 0,
          summaryLine:
              'Dispatches 1 • Strong 0 • On track 0 • Watch 0 • Critical 1 • Avg accept 12.0m • Avg on site 0.0m',
        ),
        SovereignReportPartnerScoreboardRow(
          clientId: 'CLIENT-2',
          siteId: 'SITE-77',
          partnerLabel: 'Partner Beta',
          dispatchCount: 1,
          strongCount: 1,
          onTrackCount: 0,
          watchCount: 0,
          criticalCount: 0,
          averageAcceptedDelayMinutes: 6.0,
          averageOnSiteDelayMinutes: 14.0,
          summaryLine:
              'Dispatches 1 • Strong 1 • On track 0 • Watch 0 • Critical 0 • Avg accept 6.0m • Avg on site 14.0m',
        ),
      ],
      dispatchChains: [
        SovereignReportPartnerDispatchChain(
          dispatchId: 'DSP-100',
          clientId: 'CLIENT-1',
          siteId: 'SITE-42',
          partnerLabel: 'Partner Alpha',
          declarationCount: 2,
          latestStatus: PartnerDispatchStatus.cancelled,
          latestOccurredAtUtc: DateTime.utc(2026, 3, 14, 2, 12),
          dispatchCreatedAtUtc: DateTime.utc(2026, 3, 14, 2, 0),
          acceptedAtUtc: DateTime.utc(2026, 3, 14, 2, 12),
          cancelledAtUtc: DateTime.utc(2026, 3, 14, 2, 12),
          acceptedDelayMinutes: 12.0,
          scoreLabel: 'CRITICAL',
          scoreReason: 'Dispatch was cancelled before partner completion.',
          workflowSummary: 'ACCEPT -> CANCELLED (LATEST CANCELLED)',
        ),
        SovereignReportPartnerDispatchChain(
          dispatchId: 'DSP-200',
          clientId: 'CLIENT-2',
          siteId: 'SITE-77',
          partnerLabel: 'Partner Beta',
          declarationCount: 3,
          latestStatus: PartnerDispatchStatus.allClear,
          latestOccurredAtUtc: DateTime.utc(2026, 3, 14, 3, 10),
          dispatchCreatedAtUtc: DateTime.utc(2026, 3, 14, 2, 56),
          acceptedAtUtc: DateTime.utc(2026, 3, 14, 3, 2),
          onSiteAtUtc: DateTime.utc(2026, 3, 14, 3, 10),
          allClearAtUtc: DateTime.utc(2026, 3, 14, 3, 12),
          acceptedDelayMinutes: 6.0,
          onSiteDelayMinutes: 14.0,
          scoreLabel: 'STRONG',
          scoreReason: 'Partner completed response inside targets.',
          workflowSummary: 'ACCEPT -> ON SITE -> ALL CLEAR (LATEST ALL CLEAR)',
        ),
      ],
    );
    final currentReport = buildReport(
      date: '2026-03-15',
      generatedAtUtc: DateTime.utc(2026, 3, 15, 6, 0),
      scopeBreakdowns: [
        SovereignReportPartnerScopeBreakdown(
          clientId: 'CLIENT-1',
          siteId: 'SITE-42',
          dispatchCount: 1,
          declarationCount: 3,
          latestStatus: PartnerDispatchStatus.allClear,
          latestOccurredAtUtc: DateTime.utc(2026, 3, 15, 1, 18),
          summaryLine:
              'Dispatches 1 • Declarations 3 • Latest ALL CLEAR @ 2026-03-15T01:18:00.000Z',
        ),
        SovereignReportPartnerScopeBreakdown(
          clientId: 'CLIENT-2',
          siteId: 'SITE-77',
          dispatchCount: 1,
          declarationCount: 2,
          latestStatus: PartnerDispatchStatus.cancelled,
          latestOccurredAtUtc: DateTime.utc(2026, 3, 15, 4, 08),
          summaryLine:
              'Dispatches 1 • Declarations 2 • Latest CANCELLED @ 2026-03-15T04:08:00.000Z',
        ),
      ],
      scoreboardRows: [
        SovereignReportPartnerScoreboardRow(
          clientId: 'CLIENT-1',
          siteId: 'SITE-42',
          partnerLabel: 'Partner Alpha',
          dispatchCount: 1,
          strongCount: 1,
          onTrackCount: 0,
          watchCount: 0,
          criticalCount: 0,
          averageAcceptedDelayMinutes: 4.0,
          averageOnSiteDelayMinutes: 12.0,
          summaryLine:
              'Dispatches 1 • Strong 1 • On track 0 • Watch 0 • Critical 0 • Avg accept 4.0m • Avg on site 12.0m',
        ),
        SovereignReportPartnerScoreboardRow(
          clientId: 'CLIENT-2',
          siteId: 'SITE-77',
          partnerLabel: 'Partner Beta',
          dispatchCount: 1,
          strongCount: 0,
          onTrackCount: 0,
          watchCount: 0,
          criticalCount: 1,
          averageAcceptedDelayMinutes: 10.0,
          averageOnSiteDelayMinutes: 0,
          summaryLine:
              'Dispatches 1 • Strong 0 • On track 0 • Watch 0 • Critical 1 • Avg accept 10.0m • Avg on site 0.0m',
        ),
      ],
      dispatchChains: [
        SovereignReportPartnerDispatchChain(
          dispatchId: 'DSP-101',
          clientId: 'CLIENT-1',
          siteId: 'SITE-42',
          partnerLabel: 'Partner Alpha',
          declarationCount: 3,
          latestStatus: PartnerDispatchStatus.allClear,
          latestOccurredAtUtc: DateTime.utc(2026, 3, 15, 1, 18),
          dispatchCreatedAtUtc: DateTime.utc(2026, 3, 15, 1, 0),
          acceptedAtUtc: DateTime.utc(2026, 3, 15, 1, 4),
          onSiteAtUtc: DateTime.utc(2026, 3, 15, 1, 12),
          allClearAtUtc: DateTime.utc(2026, 3, 15, 1, 18),
          acceptedDelayMinutes: 4.0,
          onSiteDelayMinutes: 12.0,
          scoreLabel: 'STRONG',
          scoreReason: 'Partner completed response inside targets.',
          workflowSummary: 'ACCEPT -> ON SITE -> ALL CLEAR (LATEST ALL CLEAR)',
        ),
        SovereignReportPartnerDispatchChain(
          dispatchId: 'DSP-201',
          clientId: 'CLIENT-2',
          siteId: 'SITE-77',
          partnerLabel: 'Partner Beta',
          declarationCount: 2,
          latestStatus: PartnerDispatchStatus.cancelled,
          latestOccurredAtUtc: DateTime.utc(2026, 3, 15, 4, 8),
          dispatchCreatedAtUtc: DateTime.utc(2026, 3, 15, 4, 0),
          acceptedAtUtc: DateTime.utc(2026, 3, 15, 4, 5),
          cancelledAtUtc: DateTime.utc(2026, 3, 15, 4, 8),
          acceptedDelayMinutes: 10.0,
          scoreLabel: 'CRITICAL',
          scoreReason: 'Dispatch was cancelled before partner completion.',
          workflowSummary: 'ACCEPT -> CANCELLED (LATEST CANCELLED)',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const [],
          morningSovereignReport: currentReport,
          morningSovereignReportHistory: [priorReport],
          initialPartnerScopeClientId: 'CLIENT-1',
          initialPartnerScopeSiteId: 'SITE-42',
          initialPartnerScopePartnerLabel: 'Partner Alpha',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('governance-partner-scope-banner')),
      findsOneWidget,
    );
    expect(find.text('Partner scope focus active'), findsOneWidget);
    expect(
      find.textContaining('CLIENT-1/SITE-42 • Partner Alpha'),
      findsWidgets,
    );
    expect(
      find.textContaining('CLIENT-2/SITE-77 • Partner Beta'),
      findsNothing,
    );
    expect(find.text('1 strong response'), findsWidgets);
    expect(find.text('Avg accept 4.0m • Avg on site 12.0m'), findsOneWidget);
    expect(find.text('IMPROVING'), findsOneWidget);
    expect(find.textContaining('Partner Alpha • DSP-101'), findsOneWidget);
    expect(find.textContaining('Partner Beta • DSP-201'), findsNothing);
  });

  testWidgets('governance page focuses scene action detail from chips', (
    tester,
  ) async {
    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: DateTime.utc(2026, 3, 10, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 9, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 10, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 184,
        hashVerified: true,
        integrityScore: 98,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 24,
        humanOverrides: 3,
        overrideReasons: {'PSIRA expired': 2},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 14,
        driftDetected: 2,
        avgMatchScore: 84,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 2,
        pdpExpired: 1,
        totalBlocked: 3,
      ),
      receiptPolicy: const SovereignReportReceiptPolicy(
        generatedReports: 2,
        trackedConfigurationReports: 1,
        legacyConfigurationReports: 1,
        fullyIncludedReports: 0,
        reportsWithOmittedSections: 1,
        omittedAiDecisionLogReports: 1,
        omittedGuardMetricsReports: 1,
        standardBrandingReports: 1,
        defaultPartnerBrandingReports: 0,
        customBrandingOverrideReports: 1,
        governanceHandoffReports: 1,
        routineReviewReports: 1,
        executiveSummary:
            '1 client-facing receipt omitted sections • 1 legacy receipt lacked tracked policy',
        brandingExecutiveSummary: '1 receipt used custom branding override',
        investigationExecutiveSummary:
            '1 receipt investigation came from Governance branding drift • 1 receipt investigation remained routine review',
        headline: '1 generated reports omitted sections',
        summaryLine:
            'Reports 2 • Tracked 1 • Legacy 1 • Full 0 • Omitted 1 • AI log omitted 1 • Guard metrics omitted 1 • Standard branding 1 • Default partner branding 0 • Custom branding 1',
        latestReportSummary:
            'CLIENT-1/SITE-42 2026-03 omitted AI Decision Log, Guard Metrics.',
        latestBrandingSummary:
            'CLIENT-1/SITE-42 2026-03 used custom branding override from Partner Alpha.',
        latestInvestigationSummary:
            'CLIENT-1/SITE-42 2026-03 remained routine report review.',
      ),
      sceneReview: const SovereignReportSceneReview(
        totalReviews: 7,
        modelReviews: 5,
        metadataFallbackReviews: 2,
        suppressedActions: 1,
        incidentAlerts: 2,
        repeatUpdates: 2,
        escalationCandidates: 2,
        topPosture: 'escalation candidate',
        actionMixSummary:
            '2 alerts • 2 repeat updates • 2 escalations • 1 suppressed review',
        latestActionTaken:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line.',
        recentActionsSummary:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)',
        latestSuppressedPattern:
            '2026-03-10T01:10:00.000Z • Camera 2 • Vehicle remained below escalation threshold.',
      ),
      vehicleThroughput: SovereignReportVehicleThroughput(
        totalVisits: 18,
        completedVisits: 15,
        activeVisits: 2,
        incompleteVisits: 1,
        uniqueVehicles: 16,
        repeatVehicles: 2,
        unknownVehicleEvents: 1,
        peakHourLabel: '23:00-00:00',
        peakHourVisitCount: 6,
        averageCompletedDwellMinutes: 17.4,
        suspiciousShortVisitCount: 1,
        loiteringVisitCount: 0,
        summaryLine:
            'Visits 18 • Entry 18 • Completed 15 • Active 2 • Incomplete 1 • Unique 16 • Repeat 2 • Avg dwell 17.4m • Peak 23:00-00:00 (6) • Short visits 1 • Unknown vehicle events 1',
        scopeBreakdowns: const [
          SovereignReportVehicleScopeBreakdown(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            totalVisits: 12,
            completedVisits: 10,
            activeVisits: 1,
            incompleteVisits: 1,
            unknownVehicleEvents: 1,
            summaryLine:
                'Visits 12 • Entry 12 • Completed 10 • Active 1 • Incomplete 1 • Unique 11 • Avg dwell 16.1m • Peak 23:00-00:00 (4) • Unknown vehicle events 1',
          ),
        ],
        exceptionVisits: [
          SovereignReportVehicleVisitException(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            vehicleLabel: 'CA123456',
            statusLabel: 'INCOMPLETE',
            reasonLabel: 'Incomplete visit',
            primaryEventId: 'EVT-201',
            startedAtUtc: DateTime.utc(2026, 3, 10, 0, 40),
            lastSeenAtUtc: DateTime.utc(2026, 3, 10, 1, 22),
            dwellMinutes: 42.0,
            eventIds: ['EVT-201', 'EVT-202'],
            zoneLabels: ['Entry Lane', 'Wash Bay'],
            intelligenceIds: ['INT-201', 'INT-202'],
          ),
        ],
      ),
      partnerProgression: SovereignReportPartnerProgression(
        dispatchCount: 2,
        declarationCount: 5,
        acceptedCount: 2,
        onSiteCount: 1,
        allClearCount: 1,
        cancelledCount: 1,
        workflowHeadline:
            '1 partner dispatch reached ALL CLEAR • 1 partner dispatch was CANCELLED',
        performanceHeadline: '1 strong response • 1 critical response',
        slaHeadline: 'Avg accept 5.0m • Avg on site 12.0m',
        summaryLine:
            'Dispatches 2 • Declarations 5 • Accept 2 • On site 1 • All clear 1 • Cancelled 1',
        scoreboardRows: [
          SovereignReportPartnerScoreboardRow(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            partnerLabel: 'Partner Alpha',
            dispatchCount: 2,
            strongCount: 1,
            onTrackCount: 0,
            watchCount: 0,
            criticalCount: 1,
            averageAcceptedDelayMinutes: 5.0,
            averageOnSiteDelayMinutes: 13.0,
            summaryLine:
                'Dispatches 2 • Strong 1 • On track 0 • Watch 0 • Critical 1 • Avg accept 5.0m • Avg on site 13.0m',
          ),
        ],
      ),
    );

    final priorReport = SovereignReport(
      date: '2026-03-09',
      generatedAtUtc: DateTime.utc(2026, 3, 9, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 8, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 9, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 160,
        hashVerified: true,
        integrityScore: 99,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 12,
        humanOverrides: 1,
        overrideReasons: <String, int>{},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 14,
        driftDetected: 1,
        avgMatchScore: 85,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 0,
        pdpExpired: 0,
        totalBlocked: 0,
      ),
      partnerProgression: SovereignReportPartnerProgression(
        dispatchCount: 2,
        declarationCount: 2,
        acceptedCount: 2,
        onSiteCount: 0,
        allClearCount: 0,
        cancelledCount: 1,
        summaryLine: '',
        scoreboardRows: [
          SovereignReportPartnerScoreboardRow(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            partnerLabel: 'Partner Alpha',
            dispatchCount: 2,
            strongCount: 0,
            onTrackCount: 0,
            watchCount: 1,
            criticalCount: 1,
            averageAcceptedDelayMinutes: 12.0,
            averageOnSiteDelayMinutes: 22.0,
            summaryLine:
                'Dispatches 2 • Strong 0 • On track 0 • Watch 1 • Critical 1 • Avg accept 12.0m • Avg on site 22.0m',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const [],
          morningSovereignReport: report,
          morningSovereignReportHistory: [priorReport],
          morningSovereignReportAutoRunKey: '2026-03-10',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-scene-focus-recent-actions')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-scene-focus-recent-actions')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Focused scene action: Recent actions'), findsOneWidget);
    expect(
      find.text(
        '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)',
      ),
      findsWidgets,
    );
    expect(
      find.text(
        'Forensic replay of combat window (22:00-06:00) • Focused Recent Actions',
      ),
      findsOneWidget,
    );
    expect(find.text('Copy Recent Actions Detail'), findsOneWidget);
    expect(find.text('Copy Morning JSON (Recent Actions)'), findsOneWidget);
    expect(find.text('Copy Morning CSV (Recent Actions)'), findsOneWidget);
    expect(find.text('Download Morning JSON (Recent Actions)'), findsOneWidget);
    expect(find.text('Download Morning CSV (Recent Actions)'), findsOneWidget);
    expect(find.text('Share Morning Pack (Recent Actions)'), findsOneWidget);
    expect(find.text('Email Morning Report (Recent Actions)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('governance-scene-detail-recentActions')),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Focused recent actions • 2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(
            find.textContaining(
              'Recent actions: 2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)',
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.textContaining(
                'Latest action taken: 2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line.',
              ),
            )
            .dy,
      ),
    );
    expect(
      _comesBefore(
        tester.getTopLeft(
          find.byKey(const ValueKey('governance-scene-focus-recent-actions')),
        ),
        tester.getTopLeft(
          find.byKey(const ValueKey('governance-scene-focus-latest-action')),
        ),
      ),
      isTrue,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-scene-focus-filtered-pattern')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-scene-focus-filtered-pattern')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Focused scene action: Filtered pattern'), findsOneWidget);
    expect(
      find.text(
        '2026-03-10T01:10:00.000Z • Camera 2 • Vehicle remained below escalation threshold.',
      ),
      findsWidgets,
    );
    expect(
      find.text(
        'Forensic replay of combat window (22:00-06:00) • Focused Filtered Pattern',
      ),
      findsOneWidget,
    );
    expect(find.text('Copy Filtered Pattern Detail'), findsOneWidget);
    expect(find.text('Copy Morning JSON (Filtered Pattern)'), findsOneWidget);
    expect(find.text('Copy Morning CSV (Filtered Pattern)'), findsOneWidget);
    expect(
      find.text('Download Morning JSON (Filtered Pattern)'),
      findsOneWidget,
    );
    expect(
      find.text('Download Morning CSV (Filtered Pattern)'),
      findsOneWidget,
    );
    expect(find.text('Share Morning Pack (Filtered Pattern)'), findsOneWidget);
    expect(
      find.text('Email Morning Report (Filtered Pattern)'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('governance-scene-detail-filteredPattern')),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Focused filtered pattern • 2026-03-10T01:10:00.000Z • Camera 2 • Vehicle remained below escalation threshold.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(
            find.textContaining(
              'Latest filtered pattern: 2026-03-10T01:10:00.000Z • Camera 2 • Vehicle remained below escalation threshold.',
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.textContaining(
                'Recent actions: 2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)',
              ),
            )
            .dy,
      ),
    );
    expect(
      _comesBefore(
        tester.getTopLeft(
          find.byKey(const ValueKey('governance-scene-focus-filtered-pattern')),
        ),
        tester.getTopLeft(
          find.byKey(const ValueKey('governance-scene-focus-recent-actions')),
        ),
      ),
      isTrue,
    );

    final sceneReviewMetric = tester.getTopLeft(
      find.byKey(const ValueKey('governance-metric-scene-review')),
    );
    final ledgerMetric = tester.getTopLeft(
      find.byKey(const ValueKey('governance-metric-ledger-integrity')),
    );
    expect(_comesBefore(sceneReviewMetric, ledgerMetric), isTrue);
  });

  testWidgets('governance page focuses scene action detail from detail rows', (
    tester,
  ) async {
    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: DateTime.utc(2026, 3, 10, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 9, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 10, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 184,
        hashVerified: true,
        integrityScore: 98,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 24,
        humanOverrides: 3,
        overrideReasons: {'PSIRA expired': 2},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 14,
        driftDetected: 2,
        avgMatchScore: 84,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 2,
        pdpExpired: 1,
        totalBlocked: 3,
      ),
      receiptPolicy: const SovereignReportReceiptPolicy(
        generatedReports: 2,
        trackedConfigurationReports: 1,
        legacyConfigurationReports: 1,
        fullyIncludedReports: 0,
        reportsWithOmittedSections: 1,
        omittedAiDecisionLogReports: 1,
        omittedGuardMetricsReports: 1,
        headline: '1 generated reports omitted sections',
        summaryLine:
            'Reports 2 • Tracked 1 • Legacy 1 • Full 0 • Omitted 1 • AI log omitted 1 • Guard metrics omitted 1',
        latestReportSummary:
            'CLIENT-1/SITE-42 2026-03 omitted AI Decision Log, Guard Metrics.',
      ),
      sceneReview: const SovereignReportSceneReview(
        totalReviews: 7,
        modelReviews: 5,
        metadataFallbackReviews: 2,
        suppressedActions: 1,
        incidentAlerts: 2,
        repeatUpdates: 2,
        escalationCandidates: 2,
        topPosture: 'escalation candidate',
        actionMixSummary:
            '2 alerts • 2 repeat updates • 2 escalations • 1 suppressed review',
        latestActionTaken:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line.',
        recentActionsSummary:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)',
        latestSuppressedPattern:
            '2026-03-10T01:10:00.000Z • Camera 2 • Vehicle remained below escalation threshold.',
      ),
      vehicleThroughput: SovereignReportVehicleThroughput(
        totalVisits: 18,
        completedVisits: 15,
        activeVisits: 2,
        incompleteVisits: 1,
        uniqueVehicles: 16,
        repeatVehicles: 2,
        unknownVehicleEvents: 1,
        peakHourLabel: '23:00-00:00',
        peakHourVisitCount: 6,
        averageCompletedDwellMinutes: 17.4,
        suspiciousShortVisitCount: 1,
        loiteringVisitCount: 0,
        summaryLine:
            'Visits 18 • Entry 18 • Completed 15 • Active 2 • Incomplete 1 • Unique 16 • Repeat 2 • Avg dwell 17.4m • Peak 23:00-00:00 (6) • Short visits 1 • Unknown vehicle events 1',
        scopeBreakdowns: const [
          SovereignReportVehicleScopeBreakdown(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            totalVisits: 12,
            completedVisits: 10,
            activeVisits: 1,
            incompleteVisits: 1,
            unknownVehicleEvents: 1,
            summaryLine:
                'Visits 12 • Entry 12 • Completed 10 • Active 1 • Incomplete 1 • Unique 11 • Avg dwell 16.1m • Peak 23:00-00:00 (4) • Unknown vehicle events 1',
          ),
        ],
        exceptionVisits: [
          SovereignReportVehicleVisitException(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            vehicleLabel: 'CA123456',
            statusLabel: 'INCOMPLETE',
            reasonLabel: 'Incomplete visit',
            primaryEventId: 'EVT-201',
            startedAtUtc: DateTime.utc(2026, 3, 10, 0, 40),
            lastSeenAtUtc: DateTime.utc(2026, 3, 10, 1, 22),
            dwellMinutes: 42.0,
            eventIds: ['EVT-201', 'EVT-202'],
            zoneLabels: ['Entry Lane', 'Wash Bay'],
            intelligenceIds: ['INT-201', 'INT-202'],
          ),
        ],
      ),
      partnerProgression: SovereignReportPartnerProgression(
        dispatchCount: 2,
        declarationCount: 5,
        acceptedCount: 2,
        onSiteCount: 1,
        allClearCount: 1,
        cancelledCount: 1,
        workflowHeadline:
            '1 partner dispatch reached ALL CLEAR • 1 partner dispatch was CANCELLED',
        performanceHeadline: '1 strong response • 1 critical response',
        slaHeadline: 'Avg accept 5.0m • Avg on site 13.0m',
        summaryLine:
            'Dispatches 2 • Declarations 5 • Accept 2 • On site 1 • All clear 1 • Cancelled 1',
        scoreboardRows: [
          SovereignReportPartnerScoreboardRow(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            partnerLabel: 'Partner Alpha',
            dispatchCount: 2,
            strongCount: 1,
            onTrackCount: 0,
            watchCount: 0,
            criticalCount: 1,
            averageAcceptedDelayMinutes: 5.0,
            averageOnSiteDelayMinutes: 13.0,
            summaryLine:
                'Dispatches 2 • Strong 1 • On track 0 • Watch 0 • Critical 1 • Avg accept 5.0m • Avg on site 13.0m',
          ),
        ],
      ),
    );

    final priorReport = SovereignReport(
      date: '2026-03-09',
      generatedAtUtc: DateTime.utc(2026, 3, 9, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 8, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 9, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 150,
        hashVerified: true,
        integrityScore: 97,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 18,
        humanOverrides: 2,
        overrideReasons: <String, int>{},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 12,
        driftDetected: 1,
        avgMatchScore: 82,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 0,
        pdpExpired: 0,
        totalBlocked: 0,
      ),
      partnerProgression: SovereignReportPartnerProgression(
        dispatchCount: 2,
        declarationCount: 2,
        acceptedCount: 2,
        onSiteCount: 0,
        allClearCount: 0,
        cancelledCount: 1,
        summaryLine: '',
        scoreboardRows: [
          SovereignReportPartnerScoreboardRow(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            partnerLabel: 'Partner Alpha',
            dispatchCount: 2,
            strongCount: 0,
            onTrackCount: 0,
            watchCount: 1,
            criticalCount: 1,
            averageAcceptedDelayMinutes: 12.0,
            averageOnSiteDelayMinutes: 22.0,
            summaryLine:
                'Dispatches 2 • Strong 0 • On track 0 • Watch 1 • Critical 1 • Avg accept 12.0m • Avg on site 22.0m',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const [],
          morningSovereignReport: report,
          morningSovereignReportHistory: [priorReport],
          morningSovereignReportAutoRunKey: '2026-03-10',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tap to focus'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-scene-detail-row-recentActions')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-scene-detail-row-recentActions')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Focused scene action: Recent actions'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('governance-scene-detail-recentActions')),
      findsOneWidget,
    );
    expect(find.text('Copy Morning JSON (Recent Actions)'), findsOneWidget);
    expect(find.text('Tap to clear'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-scene-detail-row-recentActions')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-scene-detail-row-recentActions')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Focused scene action: Recent actions'), findsNothing);
    expect(
      find.byKey(const ValueKey('governance-scene-detail-recentActions')),
      findsNothing,
    );
    expect(find.text('Copy Morning JSON'), findsOneWidget);
    expect(find.text('Tap to focus'), findsWidgets);
  });

  testWidgets('governance page restores focused scene action after remount', (
    tester,
  ) async {
    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: DateTime.utc(2026, 3, 10, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 9, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 10, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 184,
        hashVerified: true,
        integrityScore: 98,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 24,
        humanOverrides: 3,
        overrideReasons: {'PSIRA expired': 2},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 14,
        driftDetected: 2,
        avgMatchScore: 84,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 2,
        pdpExpired: 1,
        totalBlocked: 3,
      ),
      receiptPolicy: const SovereignReportReceiptPolicy(
        generatedReports: 2,
        trackedConfigurationReports: 1,
        legacyConfigurationReports: 1,
        fullyIncludedReports: 0,
        reportsWithOmittedSections: 1,
        omittedAiDecisionLogReports: 1,
        omittedGuardMetricsReports: 1,
        headline: '1 generated reports omitted sections',
        summaryLine:
            'Reports 2 • Tracked 1 • Legacy 1 • Full 0 • Omitted 1 • AI log omitted 1 • Guard metrics omitted 1',
        latestReportSummary:
            'CLIENT-1/SITE-42 2026-03 omitted AI Decision Log, Guard Metrics.',
      ),
      sceneReview: const SovereignReportSceneReview(
        totalReviews: 7,
        modelReviews: 5,
        metadataFallbackReviews: 2,
        suppressedActions: 1,
        incidentAlerts: 2,
        repeatUpdates: 2,
        escalationCandidates: 2,
        topPosture: 'escalation candidate',
        actionMixSummary:
            '2 alerts • 2 repeat updates • 2 escalations • 1 suppressed review',
        latestActionTaken:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line.',
        recentActionsSummary:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)',
        latestSuppressedPattern:
            '2026-03-10T01:10:00.000Z • Camera 2 • Vehicle remained below escalation threshold.',
      ),
      vehicleThroughput: SovereignReportVehicleThroughput(
        totalVisits: 18,
        completedVisits: 15,
        activeVisits: 2,
        incompleteVisits: 1,
        uniqueVehicles: 16,
        repeatVehicles: 2,
        unknownVehicleEvents: 1,
        peakHourLabel: '23:00-00:00',
        peakHourVisitCount: 6,
        averageCompletedDwellMinutes: 17.4,
        suspiciousShortVisitCount: 1,
        loiteringVisitCount: 0,
        summaryLine:
            'Visits 18 • Entry 18 • Completed 15 • Active 2 • Incomplete 1 • Unique 16 • Repeat 2 • Avg dwell 17.4m • Peak 23:00-00:00 (6) • Short visits 1 • Unknown vehicle events 1',
        scopeBreakdowns: const [
          SovereignReportVehicleScopeBreakdown(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            totalVisits: 12,
            completedVisits: 10,
            activeVisits: 1,
            incompleteVisits: 1,
            unknownVehicleEvents: 1,
            summaryLine:
                'Visits 12 • Entry 12 • Completed 10 • Active 1 • Incomplete 1 • Unique 11 • Avg dwell 16.1m • Peak 23:00-00:00 (4) • Unknown vehicle events 1',
          ),
        ],
        exceptionVisits: [
          SovereignReportVehicleVisitException(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            vehicleLabel: 'CA123456',
            statusLabel: 'INCOMPLETE',
            reasonLabel: 'Incomplete visit',
            primaryEventId: 'EVT-201',
            startedAtUtc: DateTime.utc(2026, 3, 10, 0, 40),
            lastSeenAtUtc: DateTime.utc(2026, 3, 10, 1, 22),
            dwellMinutes: 42.0,
            eventIds: ['EVT-201', 'EVT-202'],
            zoneLabels: ['Entry Lane', 'Wash Bay'],
            intelligenceIds: ['INT-201', 'INT-202'],
          ),
        ],
      ),
    );
    GovernanceSceneActionFocus? persistedFocus;
    var showGovernance = true;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                TextButton(
                  onPressed: () => setState(() => showGovernance = true),
                  child: const Text('Show Governance'),
                ),
                TextButton(
                  onPressed: () => setState(() => showGovernance = false),
                  child: const Text('Hide Governance'),
                ),
                Expanded(
                  child: showGovernance
                      ? GovernancePage(
                          events: const [],
                          morningSovereignReport: report,
                          morningSovereignReportAutoRunKey: '2026-03-10',
                          initialSceneActionFocus: persistedFocus,
                          onSceneActionFocusChanged: (value) {
                            persistedFocus = value;
                          },
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-scene-focus-recent-actions')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-scene-focus-recent-actions')),
    );
    await tester.pumpAndSettle();

    expect(persistedFocus, GovernanceSceneActionFocus.recentActions);
    expect(find.text('Focused scene action: Recent actions'), findsOneWidget);
    expect(
      find.text(
        'Forensic replay of combat window (22:00-06:00) • Focused Recent Actions',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Hide Governance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Governance'));
    await tester.pumpAndSettle();

    expect(find.text('Focused scene action: Recent actions'), findsOneWidget);
    expect(
      find.text(
        'Forensic replay of combat window (22:00-06:00) • Focused Recent Actions',
      ),
      findsOneWidget,
    );
    expect(find.text('Copy Morning JSON (Recent Actions)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('governance-scene-detail-recentActions')),
      findsOneWidget,
    );
  });

  testWidgets('governance scene action focus survives app shell route swap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: DateTime.utc(2026, 3, 10, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 9, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 10, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 184,
        hashVerified: true,
        integrityScore: 98,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 24,
        humanOverrides: 3,
        overrideReasons: {'PSIRA expired': 2},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 14,
        driftDetected: 2,
        avgMatchScore: 84,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 2,
        pdpExpired: 1,
        totalBlocked: 3,
      ),
      receiptPolicy: const SovereignReportReceiptPolicy(
        generatedReports: 2,
        trackedConfigurationReports: 1,
        legacyConfigurationReports: 1,
        fullyIncludedReports: 0,
        reportsWithOmittedSections: 1,
        omittedAiDecisionLogReports: 1,
        omittedGuardMetricsReports: 1,
        headline: '1 generated reports omitted sections',
        summaryLine:
            'Reports 2 • Tracked 1 • Legacy 1 • Full 0 • Omitted 1 • AI log omitted 1 • Guard metrics omitted 1',
        latestReportSummary:
            'CLIENT-1/SITE-42 2026-03 omitted AI Decision Log, Guard Metrics.',
      ),
      sceneReview: const SovereignReportSceneReview(
        totalReviews: 7,
        modelReviews: 5,
        metadataFallbackReviews: 2,
        suppressedActions: 1,
        incidentAlerts: 2,
        repeatUpdates: 2,
        escalationCandidates: 2,
        topPosture: 'escalation candidate',
        actionMixSummary:
            '2 alerts • 2 repeat updates • 2 escalations • 1 suppressed review',
        latestActionTaken:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line.',
        recentActionsSummary:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)',
        latestSuppressedPattern:
            '2026-03-10T01:10:00.000Z • Camera 2 • Vehicle remained below escalation threshold.',
      ),
    );
    GovernanceSceneActionFocus? persistedFocus;
    var route = OnyxRoute.governance;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return AppShell(
              currentRoute: route,
              onRouteChanged: (value) {
                setState(() {
                  route = value;
                });
              },
              child: route == OnyxRoute.governance
                  ? GovernancePage(
                      events: const [],
                      morningSovereignReport: report,
                      morningSovereignReportAutoRunKey: '2026-03-10',
                      initialSceneActionFocus: persistedFocus,
                      onSceneActionFocusChanged: (value) {
                        persistedFocus = value;
                      },
                    )
                  : const Center(child: Text('Live Operations Stub')),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-scene-focus-recent-actions')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-scene-focus-recent-actions')),
    );
    await tester.pumpAndSettle();

    expect(persistedFocus, GovernanceSceneActionFocus.recentActions);
    expect(find.text('Focused scene action: Recent actions'), findsOneWidget);

    await tester.tap(find.text('Live Operations').first);
    await tester.pumpAndSettle();
    expect(find.text('Live Operations Stub'), findsOneWidget);

    await tester.tap(find.text('Compliance').first);
    await tester.pumpAndSettle();

    expect(find.text('Focused scene action: Recent actions'), findsOneWidget);
    expect(find.text('Copy Morning JSON (Recent Actions)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('governance-scene-detail-recentActions')),
      findsOneWidget,
    );
  });

  testWidgets('governance page reports scene action focus changes to parent', (
    tester,
  ) async {
    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: DateTime.utc(2026, 3, 10, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 9, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 10, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 184,
        hashVerified: true,
        integrityScore: 98,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 24,
        humanOverrides: 3,
        overrideReasons: {'PSIRA expired': 2},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 14,
        driftDetected: 2,
        avgMatchScore: 84,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 2,
        pdpExpired: 1,
        totalBlocked: 3,
      ),
      receiptPolicy: const SovereignReportReceiptPolicy(
        generatedReports: 2,
        trackedConfigurationReports: 1,
        legacyConfigurationReports: 1,
        fullyIncludedReports: 0,
        reportsWithOmittedSections: 1,
        omittedAiDecisionLogReports: 1,
        omittedGuardMetricsReports: 1,
        headline: '1 generated reports omitted sections',
        summaryLine:
            'Reports 2 • Tracked 1 • Legacy 1 • Full 0 • Omitted 1 • AI log omitted 1 • Guard metrics omitted 1',
        latestReportSummary:
            'CLIENT-1/SITE-42 2026-03 omitted AI Decision Log, Guard Metrics.',
      ),
      sceneReview: const SovereignReportSceneReview(
        totalReviews: 7,
        modelReviews: 5,
        metadataFallbackReviews: 2,
        suppressedActions: 1,
        incidentAlerts: 2,
        repeatUpdates: 2,
        escalationCandidates: 2,
        topPosture: 'escalation candidate',
        actionMixSummary:
            '2 alerts • 2 repeat updates • 2 escalations • 1 suppressed review',
        latestActionTaken:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line.',
        recentActionsSummary:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)',
        latestSuppressedPattern:
            '2026-03-10T01:10:00.000Z • Camera 2 • Vehicle remained below escalation threshold.',
      ),
    );
    final focusChanges = <GovernanceSceneActionFocus?>[];

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const [],
          morningSovereignReport: report,
          morningSovereignReportAutoRunKey: '2026-03-10',
          onSceneActionFocusChanged: focusChanges.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-scene-focus-recent-actions')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-scene-focus-recent-actions')),
    );
    await tester.pumpAndSettle();

    expect(focusChanges, [GovernanceSceneActionFocus.recentActions]);

    await tester.ensureVisible(find.text('Clear'));
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(focusChanges, [GovernanceSceneActionFocus.recentActions, isNull]);
  });

  testWidgets('governance page syncs scene action focus from parent updates', (
    tester,
  ) async {
    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: DateTime.utc(2026, 3, 10, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 9, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 10, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 184,
        hashVerified: true,
        integrityScore: 98,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 24,
        humanOverrides: 3,
        overrideReasons: {'PSIRA expired': 2},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 14,
        driftDetected: 2,
        avgMatchScore: 84,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 2,
        pdpExpired: 1,
        totalBlocked: 3,
      ),
      receiptPolicy: const SovereignReportReceiptPolicy(
        generatedReports: 2,
        trackedConfigurationReports: 1,
        legacyConfigurationReports: 1,
        fullyIncludedReports: 0,
        reportsWithOmittedSections: 1,
        omittedAiDecisionLogReports: 1,
        omittedGuardMetricsReports: 1,
        headline: '1 generated reports omitted sections',
        summaryLine:
            'Reports 2 • Tracked 1 • Legacy 1 • Full 0 • Omitted 1 • AI log omitted 1 • Guard metrics omitted 1',
        latestReportSummary:
            'CLIENT-1/SITE-42 2026-03 omitted AI Decision Log, Guard Metrics.',
      ),
      sceneReview: const SovereignReportSceneReview(
        totalReviews: 7,
        modelReviews: 5,
        metadataFallbackReviews: 2,
        suppressedActions: 1,
        incidentAlerts: 2,
        repeatUpdates: 2,
        escalationCandidates: 2,
        topPosture: 'escalation candidate',
        actionMixSummary:
            '2 alerts • 2 repeat updates • 2 escalations • 1 suppressed review',
        latestActionTaken:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line.',
        recentActionsSummary:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)',
        latestSuppressedPattern:
            '2026-03-10T01:10:00.000Z • Camera 2 • Vehicle remained below escalation threshold.',
      ),
    );
    GovernanceSceneActionFocus? parentFocus;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      parentFocus = GovernanceSceneActionFocus.filteredPattern;
                    });
                  },
                  child: const Text('Parent Focus Filtered'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      parentFocus = null;
                    });
                  },
                  child: const Text('Parent Clear Focus'),
                ),
                Expanded(
                  child: GovernancePage(
                    events: const [],
                    morningSovereignReport: report,
                    morningSovereignReportAutoRunKey: '2026-03-10',
                    initialSceneActionFocus: parentFocus,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Focused scene action: Filtered pattern'), findsNothing);
    expect(find.text('Copy Morning JSON'), findsOneWidget);

    await tester.tap(find.text('Parent Focus Filtered'));
    await tester.pumpAndSettle();

    expect(find.text('Focused scene action: Filtered pattern'), findsOneWidget);
    expect(
      find.text(
        'Forensic replay of combat window (22:00-06:00) • Focused Filtered Pattern',
      ),
      findsOneWidget,
    );
    expect(find.text('Copy Morning JSON (Filtered Pattern)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('governance-scene-detail-filteredPattern')),
      findsOneWidget,
    );

    await tester.tap(find.text('Parent Clear Focus'));
    await tester.pumpAndSettle();

    expect(find.text('Focused scene action: Filtered pattern'), findsNothing);
    expect(
      find.text(
        'Forensic replay of combat window (22:00-06:00) • Focused Filtered Pattern',
      ),
      findsNothing,
    );
    expect(find.text('Copy Morning JSON'), findsOneWidget);
  });

  testWidgets('governance page ignores invalid incoming scene action focus', (
    tester,
  ) async {
    final report = SovereignReport(
      date: '2026-03-11',
      generatedAtUtc: DateTime.utc(2026, 3, 11, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 10, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 11, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 122,
        hashVerified: true,
        integrityScore: 99,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 18,
        humanOverrides: 1,
        overrideReasons: {'Manual override': 1},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 9,
        driftDetected: 1,
        avgMatchScore: 88,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 1,
        pdpExpired: 0,
        totalBlocked: 1,
      ),
      sceneReview: const SovereignReportSceneReview(
        totalReviews: 3,
        modelReviews: 3,
        metadataFallbackReviews: 0,
        suppressedActions: 0,
        incidentAlerts: 1,
        repeatUpdates: 0,
        escalationCandidates: 1,
        topPosture: 'escalation candidate',
        actionMixSummary: '1 alert • 1 escalation',
        latestActionTaken:
            '2026-03-11T01:00:00.000Z • Camera 3 • Escalation Candidate • Person remained in restricted zone.',
        recentActionsSummary: '',
        latestSuppressedPattern: '',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const [],
          morningSovereignReport: report,
          morningSovereignReportAutoRunKey: '2026-03-11',
          initialSceneActionFocus: GovernanceSceneActionFocus.recentActions,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Focused scene action: Recent actions'), findsNothing);
    expect(find.text('Copy Morning JSON (Recent Actions)'), findsNothing);
    expect(find.text('Copy Morning JSON'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('governance-scene-focus-recent-actions')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('governance-scene-focus-latest-action')),
      findsOneWidget,
    );
  });

  testWidgets(
    'governance page restores previously invalid parent focus when report later supports it',
    (tester) async {
      final reportWithoutRecentActions = SovereignReport(
        date: '2026-03-11',
        generatedAtUtc: DateTime.utc(2026, 3, 11, 6, 0),
        shiftWindowStartUtc: DateTime.utc(2026, 3, 10, 22, 0),
        shiftWindowEndUtc: DateTime.utc(2026, 3, 11, 6, 0),
        ledgerIntegrity: const SovereignReportLedgerIntegrity(
          totalEvents: 122,
          hashVerified: true,
          integrityScore: 99,
        ),
        aiHumanDelta: const SovereignReportAiHumanDelta(
          aiDecisions: 18,
          humanOverrides: 1,
          overrideReasons: {'Manual override': 1},
        ),
        normDrift: const SovereignReportNormDrift(
          sitesMonitored: 9,
          driftDetected: 1,
          avgMatchScore: 88,
        ),
        complianceBlockage: const SovereignReportComplianceBlockage(
          psiraExpired: 1,
          pdpExpired: 0,
          totalBlocked: 1,
        ),
        sceneReview: const SovereignReportSceneReview(
          totalReviews: 3,
          modelReviews: 3,
          metadataFallbackReviews: 0,
          suppressedActions: 0,
          incidentAlerts: 1,
          repeatUpdates: 0,
          escalationCandidates: 1,
          topPosture: 'escalation candidate',
          actionMixSummary: '1 alert • 1 escalation',
          latestActionTaken:
              '2026-03-11T01:00:00.000Z • Camera 3 • Escalation Candidate • Person remained in restricted zone.',
          recentActionsSummary: '',
          latestSuppressedPattern: '',
        ),
      );
      final reportWithRecentActions = SovereignReport(
        date: '2026-03-12',
        generatedAtUtc: DateTime.utc(2026, 3, 12, 6, 0),
        shiftWindowStartUtc: DateTime.utc(2026, 3, 11, 22, 0),
        shiftWindowEndUtc: DateTime.utc(2026, 3, 12, 6, 0),
        ledgerIntegrity: const SovereignReportLedgerIntegrity(
          totalEvents: 160,
          hashVerified: true,
          integrityScore: 97,
        ),
        aiHumanDelta: const SovereignReportAiHumanDelta(
          aiDecisions: 20,
          humanOverrides: 2,
          overrideReasons: {'Manual override': 2},
        ),
        normDrift: const SovereignReportNormDrift(
          sitesMonitored: 11,
          driftDetected: 2,
          avgMatchScore: 86,
        ),
        complianceBlockage: const SovereignReportComplianceBlockage(
          psiraExpired: 1,
          pdpExpired: 0,
          totalBlocked: 1,
        ),
        sceneReview: const SovereignReportSceneReview(
          totalReviews: 5,
          modelReviews: 5,
          metadataFallbackReviews: 0,
          suppressedActions: 1,
          incidentAlerts: 2,
          repeatUpdates: 1,
          escalationCandidates: 1,
          topPosture: 'escalation candidate',
          actionMixSummary:
              '2 alerts • 1 repeat update • 1 escalation • 1 suppressed review',
          latestActionTaken:
              '2026-03-12T00:20:00.000Z • Camera 5 • Monitoring Alert • Vehicle paused near loading bay.',
          recentActionsSummary:
              '2026-03-12T00:20:00.000Z • Camera 5 • Monitoring Alert • Vehicle paused near loading bay. (+1 more)',
          latestSuppressedPattern:
              '2026-03-12T01:40:00.000Z • Camera 4 • Person remained below escalation threshold.',
        ),
      );
      final focusChanges = <GovernanceSceneActionFocus?>[];
      var activeReport = reportWithoutRecentActions;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      activeReport = reportWithRecentActions;
                    }),
                    child: const Text('Swap Report'),
                  ),
                  Expanded(
                    child: GovernancePage(
                      events: const [],
                      morningSovereignReport: activeReport,
                      morningSovereignReportAutoRunKey: activeReport.date,
                      initialSceneActionFocus:
                          GovernanceSceneActionFocus.recentActions,
                      onSceneActionFocusChanged: focusChanges.add,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Focused scene action: Recent actions'), findsNothing);
      expect(focusChanges, isEmpty);

      await tester.tap(find.text('Swap Report'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Focused scene action: Recent actions'), findsOneWidget);
      expect(
        find.text(
          'Forensic replay of combat window (22:00-06:00) • Focused Recent Actions',
        ),
        findsOneWidget,
      );
      expect(find.text('Copy Morning JSON (Recent Actions)'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('governance-scene-detail-recentActions')),
        findsOneWidget,
      );
      expect(focusChanges, isEmpty);
    },
  );

  testWidgets('governance page clears stale focused scene action when report changes', (
    tester,
  ) async {
    final reportWithRecentActions = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: DateTime.utc(2026, 3, 10, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 9, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 10, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 184,
        hashVerified: true,
        integrityScore: 98,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 24,
        humanOverrides: 3,
        overrideReasons: {'PSIRA expired': 2},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 14,
        driftDetected: 2,
        avgMatchScore: 84,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 2,
        pdpExpired: 1,
        totalBlocked: 3,
      ),
      sceneReview: const SovereignReportSceneReview(
        totalReviews: 7,
        modelReviews: 5,
        metadataFallbackReviews: 2,
        suppressedActions: 1,
        incidentAlerts: 2,
        repeatUpdates: 2,
        escalationCandidates: 2,
        topPosture: 'escalation candidate',
        actionMixSummary:
            '2 alerts • 2 repeat updates • 2 escalations • 1 suppressed review',
        latestActionTaken:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line.',
        recentActionsSummary:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)',
        latestSuppressedPattern:
            '2026-03-10T01:10:00.000Z • Camera 2 • Vehicle remained below escalation threshold.',
      ),
    );
    final reportWithoutRecentActions = SovereignReport(
      date: '2026-03-11',
      generatedAtUtc: DateTime.utc(2026, 3, 11, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 10, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 11, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 122,
        hashVerified: true,
        integrityScore: 99,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 18,
        humanOverrides: 1,
        overrideReasons: {'Manual override': 1},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 9,
        driftDetected: 1,
        avgMatchScore: 88,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 1,
        pdpExpired: 0,
        totalBlocked: 1,
      ),
      sceneReview: const SovereignReportSceneReview(
        totalReviews: 3,
        modelReviews: 3,
        metadataFallbackReviews: 0,
        suppressedActions: 0,
        incidentAlerts: 1,
        repeatUpdates: 0,
        escalationCandidates: 1,
        topPosture: 'escalation candidate',
        actionMixSummary: '1 alert • 1 escalation',
        latestActionTaken:
            '2026-03-11T01:00:00.000Z • Camera 3 • Escalation Candidate • Person remained in restricted zone.',
        recentActionsSummary: '',
        latestSuppressedPattern: '',
      ),
    );
    GovernanceSceneActionFocus? persistedFocus =
        GovernanceSceneActionFocus.recentActions;
    var activeReport = reportWithRecentActions;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    activeReport = reportWithoutRecentActions;
                  }),
                  child: const Text('Swap Report'),
                ),
                Expanded(
                  child: GovernancePage(
                    events: const [],
                    morningSovereignReport: activeReport,
                    morningSovereignReportAutoRunKey: activeReport.date,
                    initialSceneActionFocus: persistedFocus,
                    onSceneActionFocusChanged: (value) {
                      persistedFocus = value;
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Focused scene action: Recent actions'), findsOneWidget);
    expect(
      find.text(
        'Forensic replay of combat window (22:00-06:00) • Focused Recent Actions',
      ),
      findsOneWidget,
    );
    expect(find.text('Copy Morning JSON (Recent Actions)'), findsOneWidget);

    await tester.tap(find.text('Swap Report'));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(persistedFocus, isNull);
    expect(find.text('Focused scene action: Recent actions'), findsNothing);
    expect(
      find.text(
        'Forensic replay of combat window (22:00-06:00) • Focused Recent Actions',
      ),
      findsNothing,
    );
    expect(find.text('Copy Morning JSON (Recent Actions)'), findsNothing);
    expect(find.text('Copy Morning JSON'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('governance-scene-focus-recent-actions')),
      findsNothing,
    );
  });

  testWidgets('governance page exports active scene action focus in json and csv', (
    tester,
  ) async {
    String? copiedPayload;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          copiedPayload = args['text'] as String?;
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

    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: DateTime.utc(2026, 3, 10, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 9, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 10, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 184,
        hashVerified: true,
        integrityScore: 98,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 24,
        humanOverrides: 3,
        overrideReasons: {'PSIRA expired': 2},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 14,
        driftDetected: 2,
        avgMatchScore: 84,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 2,
        pdpExpired: 1,
        totalBlocked: 3,
      ),
      receiptPolicy: const SovereignReportReceiptPolicy(
        generatedReports: 2,
        trackedConfigurationReports: 1,
        legacyConfigurationReports: 1,
        fullyIncludedReports: 0,
        reportsWithOmittedSections: 1,
        omittedAiDecisionLogReports: 1,
        omittedGuardMetricsReports: 1,
        standardBrandingReports: 1,
        defaultPartnerBrandingReports: 0,
        customBrandingOverrideReports: 1,
        governanceHandoffReports: 1,
        routineReviewReports: 1,
        executiveSummary:
            '1 client-facing receipt omitted sections • 1 legacy receipt lacked tracked policy',
        brandingExecutiveSummary: '1 receipt used custom branding override',
        investigationExecutiveSummary:
            '1 receipt investigation came from Governance branding drift • 1 receipt investigation remained routine review',
        headline: '1 generated reports omitted sections',
        summaryLine:
            'Reports 2 • Tracked 1 • Legacy 1 • Full 0 • Omitted 1 • AI log omitted 1 • Guard metrics omitted 1 • Standard branding 1 • Default partner branding 0 • Custom branding 1',
        latestReportSummary:
            'CLIENT-1/SITE-42 2026-03 omitted AI Decision Log, Guard Metrics.',
        latestBrandingSummary:
            'CLIENT-1/SITE-42 2026-03 used custom branding override from Partner Alpha.',
        latestInvestigationSummary:
            'CLIENT-1/SITE-42 2026-03 remained routine report review.',
      ),
      sceneReview: const SovereignReportSceneReview(
        totalReviews: 7,
        modelReviews: 5,
        metadataFallbackReviews: 2,
        suppressedActions: 1,
        incidentAlerts: 2,
        repeatUpdates: 2,
        escalationCandidates: 2,
        topPosture: 'escalation candidate',
        actionMixSummary:
            '2 alerts • 2 repeat updates • 2 escalations • 1 suppressed review',
        latestActionTaken:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line.',
        recentActionsSummary:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)',
        latestSuppressedPattern:
            '2026-03-10T01:10:00.000Z • Camera 2 • Vehicle remained below escalation threshold.',
      ),
      vehicleThroughput: SovereignReportVehicleThroughput(
        totalVisits: 18,
        completedVisits: 15,
        activeVisits: 2,
        incompleteVisits: 1,
        uniqueVehicles: 16,
        repeatVehicles: 2,
        unknownVehicleEvents: 1,
        peakHourLabel: '23:00-00:00',
        peakHourVisitCount: 6,
        averageCompletedDwellMinutes: 17.4,
        suspiciousShortVisitCount: 1,
        loiteringVisitCount: 0,
        summaryLine:
            'Visits 18 • Entry 18 • Completed 15 • Active 2 • Incomplete 1 • Unique 16 • Repeat 2 • Avg dwell 17.4m • Peak 23:00-00:00 (6) • Short visits 1 • Unknown vehicle events 1',
        scopeBreakdowns: const [
          SovereignReportVehicleScopeBreakdown(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            totalVisits: 12,
            completedVisits: 10,
            activeVisits: 1,
            incompleteVisits: 1,
            unknownVehicleEvents: 1,
            summaryLine:
                'Visits 12 • Entry 12 • Completed 10 • Active 1 • Incomplete 1 • Unique 11 • Avg dwell 16.1m • Peak 23:00-00:00 (4) • Unknown vehicle events 1',
          ),
        ],
        exceptionVisits: [
          SovereignReportVehicleVisitException(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            vehicleLabel: 'CA123456',
            statusLabel: 'INCOMPLETE',
            reasonLabel: 'Incomplete visit',
            primaryEventId: 'EVT-201',
            startedAtUtc: DateTime.utc(2026, 3, 10, 0, 40),
            lastSeenAtUtc: DateTime.utc(2026, 3, 10, 1, 22),
            dwellMinutes: 42.0,
            eventIds: ['EVT-201', 'EVT-202'],
            zoneLabels: ['Entry Lane', 'Wash Bay'],
            intelligenceIds: ['INT-201', 'INT-202'],
          ),
        ],
      ),
      partnerProgression: SovereignReportPartnerProgression(
        dispatchCount: 2,
        declarationCount: 5,
        acceptedCount: 2,
        onSiteCount: 1,
        allClearCount: 1,
        cancelledCount: 1,
        workflowHeadline:
            '1 partner dispatch reached ALL CLEAR • 1 partner dispatch was CANCELLED',
        performanceHeadline: '1 strong response • 1 critical response',
        slaHeadline: 'Avg accept 5.0m • Avg on site 13.0m',
        summaryLine:
            'Dispatches 2 • Declarations 5 • Accept 2 • On site 1 • All clear 1 • Cancelled 1',
        scoreboardRows: [
          SovereignReportPartnerScoreboardRow(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            partnerLabel: 'Partner Alpha',
            dispatchCount: 2,
            strongCount: 1,
            onTrackCount: 0,
            watchCount: 0,
            criticalCount: 1,
            averageAcceptedDelayMinutes: 5.0,
            averageOnSiteDelayMinutes: 13.0,
            summaryLine:
                'Dispatches 2 • Strong 1 • On track 0 • Watch 0 • Critical 1 • Avg accept 5.0m • Avg on site 13.0m',
          ),
        ],
      ),
    );

    final priorReport = SovereignReport(
      date: '2026-03-09',
      generatedAtUtc: DateTime.utc(2026, 3, 9, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 8, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 9, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 150,
        hashVerified: true,
        integrityScore: 97,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 18,
        humanOverrides: 2,
        overrideReasons: <String, int>{},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 12,
        driftDetected: 1,
        avgMatchScore: 82,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 0,
        pdpExpired: 0,
        totalBlocked: 0,
      ),
      partnerProgression: SovereignReportPartnerProgression(
        dispatchCount: 2,
        declarationCount: 2,
        acceptedCount: 2,
        onSiteCount: 0,
        allClearCount: 0,
        cancelledCount: 1,
        summaryLine: '',
        scoreboardRows: [
          SovereignReportPartnerScoreboardRow(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            partnerLabel: 'Partner Alpha',
            dispatchCount: 2,
            strongCount: 0,
            onTrackCount: 0,
            watchCount: 1,
            criticalCount: 1,
            averageAcceptedDelayMinutes: 12.0,
            averageOnSiteDelayMinutes: 22.0,
            summaryLine:
                'Dispatches 2 • Strong 0 • On track 0 • Watch 1 • Critical 1 • Avg accept 12.0m • Avg on site 22.0m',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const [],
          morningSovereignReport: report,
          morningSovereignReportHistory: [priorReport],
          morningSovereignReportAutoRunKey: '2026-03-10',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-scene-focus-recent-actions')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-scene-focus-recent-actions')),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Copy Morning JSON (Recent Actions)'));
    await tester.tap(find.text('Copy Morning JSON (Recent Actions)'));
    await tester.pump();

    expect(copiedPayload, isNotNull);
    expect(
      find.text('Morning report JSON copied with Recent actions focus'),
      findsOneWidget,
    );
    expect(copiedPayload, contains('"focusedLens"'));
    expect(copiedPayload, contains('"key": "recentActions"'));
    expect(copiedPayload, contains('"label": "Recent actions"'));
    expect(copiedPayload, contains('"receiptPolicy"'));
    expect(copiedPayload, contains('"generatedReports": 2'));
    expect(
      copiedPayload,
      contains(
        '"executiveSummary": "1 client-facing receipt omitted sections • 1 legacy receipt lacked tracked policy"',
      ),
    );
    expect(
      copiedPayload,
      contains(
        '"brandingExecutiveSummary": "1 receipt used custom branding override"',
      ),
    );
    expect(copiedPayload, contains('"governanceHandoffReports": 1'));
    expect(copiedPayload, contains('"routineReviewReports": 1'));
    expect(
      copiedPayload,
      contains(
        '"investigationExecutiveSummary": "1 receipt investigation came from Governance branding drift • 1 receipt investigation remained routine review"',
      ),
    );
    expect(
      copiedPayload,
      contains('"headline": "1 generated reports omitted sections"'),
    );
    expect(
      copiedPayload,
      contains(
        '"latestBrandingSummary": "CLIENT-1/SITE-42 2026-03 used custom branding override from Partner Alpha."',
      ),
    );
    expect(
      copiedPayload,
      contains(
        '"latestInvestigationSummary": "CLIENT-1/SITE-42 2026-03 remained routine report review."',
      ),
    );
    expect(copiedPayload, contains('"investigationTrend"'));
    expect(copiedPayload, contains('"trendLabel": "NEW"'));
    expect(copiedPayload, contains('"currentModeLabel": "OVERSIGHT HANDOFF"'));
    expect(copiedPayload, contains('"investigationHistory"'));
    expect(copiedPayload, contains('"current": true'));
    expect(copiedPayload, contains('"vehicleThroughput"'));
    expect(copiedPayload, contains('"totalVisits": 18'));
    expect(
      copiedPayload,
      contains('"summaryLine": "Visits 18 • Entry 18 • Completed 15'),
    );
    expect(copiedPayload, contains('"scopeBreakdowns"'));
    expect(copiedPayload, contains('"exceptionVisits"'));
    expect(copiedPayload, contains('"partnerProgression"'));
    expect(copiedPayload, contains('"scoreboardHistory"'));
    expect(copiedPayload, contains('"date": "2026-03-10"'));
    expect(copiedPayload, contains('"reportDate": "2026-03-10"'));
    expect(copiedPayload, contains('"reportDate": "2026-03-09"'));
    expect(copiedPayload, contains('"siteId": "SITE-42"'));
    expect(copiedPayload, contains('"reasonLabel": "Incomplete visit"'));
    expect(
      copiedPayload,
      contains(
        '"detail": "2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)"',
      ),
    );

    await tester.ensureVisible(find.text('Copy Morning CSV (Recent Actions)'));
    await tester.tap(find.text('Copy Morning CSV (Recent Actions)'));
    await tester.pump();

    expect(copiedPayload, isNotNull);
    expect(copiedPayload, contains('scene_focused_lens_key,recentActions'));
    expect(copiedPayload, contains('receipt_generated_reports,2'));
    expect(
      copiedPayload,
      contains(
        'receipt_executive_summary,"1 client-facing receipt omitted sections • 1 legacy receipt lacked tracked policy"',
      ),
    );
    expect(
      copiedPayload,
      contains(
        'receipt_branding_executive_summary,"1 receipt used custom branding override"',
      ),
    );
    expect(
      copiedPayload,
      contains('receipt_headline,"1 generated reports omitted sections"'),
    );
    expect(
      copiedPayload,
      contains(
        'receipt_latest_branding_summary,"CLIENT-1/SITE-42 2026-03 used custom branding override from Partner Alpha."',
      ),
    );
    expect(copiedPayload, contains('receipt_investigation_trend_label,NEW'));
    expect(
      copiedPayload,
      contains('receipt_investigation_trend_current_mode,"OVERSIGHT HANDOFF"'),
    );
    expect(
      copiedPayload,
      contains(
        'receipt_investigation_history_1,"2026-03-10 • CURRENT • Reports 2 • Shift receipts 0 • Governance 1 • Routine 1',
      ),
    );
    expect(copiedPayload, contains('vehicle_total_visits,18'));
    expect(copiedPayload, contains('vehicle_completed_visits,15'));
    expect(
      copiedPayload,
      contains('vehicle_summary,"Visits 18 • Entry 18 • Completed 15'),
    );
    expect(
      copiedPayload,
      contains('vehicle_scope_1,"CLIENT-1/SITE-42 • Visits 12'),
    );
    expect(
      copiedPayload,
      contains('vehicle_exception_1,"Incomplete visit • INCOMPLETE • CA123456'),
    );
    expect(
      copiedPayload,
      contains(
        'partner_scoreboard_history_1,"2026-03-10 • CURRENT • CLIENT-1/SITE-42 • Partner Alpha',
      ),
    );
    expect(
      copiedPayload,
      contains(
        'partner_scoreboard_history_2,"2026-03-09 • HISTORY • CLIENT-1/SITE-42 • Partner Alpha',
      ),
    );
    expect(
      copiedPayload,
      contains('scene_focused_lens_label,"Recent actions"'),
    );
    expect(
      copiedPayload,
      contains(
        'scene_focused_lens_detail,"2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)"',
      ),
    );
  });

  testWidgets('governance page copies focused scene action detail', (
    tester,
  ) async {
    String? copiedPayload;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          copiedPayload = args['text'] as String?;
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

    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: DateTime.utc(2026, 3, 10, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 9, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 10, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 184,
        hashVerified: true,
        integrityScore: 98,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 24,
        humanOverrides: 3,
        overrideReasons: {'PSIRA expired': 2},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 14,
        driftDetected: 2,
        avgMatchScore: 84,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 2,
        pdpExpired: 1,
        totalBlocked: 3,
      ),
      sceneReview: const SovereignReportSceneReview(
        totalReviews: 7,
        modelReviews: 5,
        metadataFallbackReviews: 2,
        suppressedActions: 1,
        incidentAlerts: 2,
        repeatUpdates: 2,
        escalationCandidates: 2,
        topPosture: 'escalation candidate',
        actionMixSummary:
            '2 alerts • 2 repeat updates • 2 escalations • 1 suppressed review',
        latestActionTaken:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line.',
        recentActionsSummary:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)',
        latestSuppressedPattern:
            '2026-03-10T01:10:00.000Z • Camera 2 • Vehicle remained below escalation threshold.',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const [],
          morningSovereignReport: report,
          morningSovereignReportAutoRunKey: '2026-03-10',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-scene-focus-filtered-pattern')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-scene-focus-filtered-pattern')),
    );
    await tester.pumpAndSettle();

    final focusedCopyAction = find.byKey(
      const ValueKey('governance-copy-focused-detail-action'),
    );
    expect(find.text('Copy Filtered Pattern Detail'), findsOneWidget);
    await tester.ensureVisible(focusedCopyAction);
    await tester.tap(focusedCopyAction);
    await tester.pumpAndSettle();

    expect(
      copiedPayload,
      'Filtered pattern: 2026-03-10T01:10:00.000Z • Camera 2 • Vehicle remained below escalation threshold.',
    );
    expect(find.text('Filtered pattern detail copied'), findsOneWidget);
  });

  testWidgets('governance page copies focused scene action detail from banner', (
    tester,
  ) async {
    String? copiedPayload;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          copiedPayload = args['text'] as String?;
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

    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: DateTime.utc(2026, 3, 10, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 9, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 10, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 184,
        hashVerified: true,
        integrityScore: 98,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 24,
        humanOverrides: 3,
        overrideReasons: {'PSIRA expired': 2},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 14,
        driftDetected: 2,
        avgMatchScore: 84,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 2,
        pdpExpired: 1,
        totalBlocked: 3,
      ),
      sceneReview: const SovereignReportSceneReview(
        totalReviews: 7,
        modelReviews: 5,
        metadataFallbackReviews: 2,
        suppressedActions: 1,
        incidentAlerts: 2,
        repeatUpdates: 2,
        escalationCandidates: 2,
        topPosture: 'escalation candidate',
        actionMixSummary:
            '2 alerts • 2 repeat updates • 2 escalations • 1 suppressed review',
        latestActionTaken:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line.',
        recentActionsSummary:
            '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)',
        latestSuppressedPattern:
            '2026-03-10T01:10:00.000Z • Camera 2 • Vehicle remained below escalation threshold.',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const [],
          morningSovereignReport: report,
          morningSovereignReportAutoRunKey: '2026-03-10',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-scene-focus-recent-actions')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-scene-focus-recent-actions')),
    );
    await tester.pumpAndSettle();

    final bannerCopyTarget = find.byKey(
      const ValueKey('governance-focused-scene-detail-copy'),
    );
    await tester.ensureVisible(bannerCopyTarget);
    await tester.tap(bannerCopyTarget);
    await tester.pumpAndSettle();

    expect(
      copiedPayload,
      'Recent actions: 2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)',
    );
    expect(find.text('Recent actions detail copied'), findsOneWidget);
  });

  testWidgets(
    'governance page expands vehicle exception detail and opens events review',
    (tester) async {
      String? openedEventId;
      final report = SovereignReport(
        date: '2026-03-10',
        generatedAtUtc: DateTime.utc(2026, 3, 10, 6, 0),
        shiftWindowStartUtc: DateTime.utc(2026, 3, 9, 22, 0),
        shiftWindowEndUtc: DateTime.utc(2026, 3, 10, 6, 0),
        ledgerIntegrity: const SovereignReportLedgerIntegrity(
          totalEvents: 184,
          hashVerified: true,
          integrityScore: 98,
        ),
        aiHumanDelta: const SovereignReportAiHumanDelta(
          aiDecisions: 24,
          humanOverrides: 3,
          overrideReasons: {'PSIRA expired': 2},
        ),
        normDrift: const SovereignReportNormDrift(
          sitesMonitored: 14,
          driftDetected: 2,
          avgMatchScore: 84,
        ),
        complianceBlockage: const SovereignReportComplianceBlockage(
          psiraExpired: 2,
          pdpExpired: 1,
          totalBlocked: 3,
        ),
        vehicleThroughput: SovereignReportVehicleThroughput(
          totalVisits: 1,
          completedVisits: 0,
          activeVisits: 0,
          incompleteVisits: 1,
          uniqueVehicles: 1,
          repeatVehicles: 0,
          unknownVehicleEvents: 0,
          peakHourLabel: '00:00-01:00',
          peakHourVisitCount: 1,
          averageCompletedDwellMinutes: 0,
          suspiciousShortVisitCount: 0,
          loiteringVisitCount: 0,
          summaryLine:
              'Visits 1 • Entry 1 • Completed 0 • Active 0 • Incomplete 1 • Unique 1',
          scopeBreakdowns: const [
            SovereignReportVehicleScopeBreakdown(
              clientId: 'CLIENT-1',
              siteId: 'SITE-42',
              totalVisits: 1,
              completedVisits: 0,
              activeVisits: 0,
              incompleteVisits: 1,
              unknownVehicleEvents: 0,
              summaryLine:
                  'Visits 1 • Entry 1 • Completed 0 • Active 0 • Incomplete 1 • Unique 1',
            ),
          ],
          exceptionVisits: [
            SovereignReportVehicleVisitException(
              clientId: 'CLIENT-1',
              siteId: 'SITE-42',
              vehicleLabel: 'CA123456',
              statusLabel: 'INCOMPLETE',
              reasonLabel: 'Incomplete visit',
              workflowSummary: 'ENTRY -> SERVICE (INCOMPLETE)',
              primaryEventId: 'EVT-201',
              startedAtUtc: DateTime.utc(2026, 3, 10, 0, 40),
              lastSeenAtUtc: DateTime.utc(2026, 3, 10, 1, 22),
              dwellMinutes: 42.0,
              eventIds: ['EVT-201'],
              zoneLabels: ['Entry Lane', 'Wash Bay'],
              intelligenceIds: ['INT-201', 'INT-202'],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GovernancePage(
            events: const [],
            morningSovereignReport: report,
            morningSovereignReportAutoRunKey: '2026-03-10',
            onOpenVehicleExceptionEvent: (value) {
              openedEventId = value;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exceptionRow = find.byKey(
        const ValueKey('governance-vehicle-exception-CA123456-SITE-42'),
      );
      await tester.ensureVisible(exceptionRow);
      await tester.tap(exceptionRow);
      await tester.pumpAndSettle();

      expect(openedEventId, isNull);
      expect(find.text('Visit timeline'), findsOneWidget);
      expect(find.textContaining('Linked events: EVT-201'), findsOneWidget);
      expect(
        find.textContaining('Workflow: ENTRY -> SERVICE (INCOMPLETE)'),
        findsWidgets,
      );
      await tester.tap(
        find.byKey(const ValueKey('governance-vehicle-exception-open-EVT-201')),
      );
      await tester.pumpAndSettle();

      expect(openedEventId, 'EVT-201');
      expect(find.text('Open Events Review'), findsOneWidget);
    },
  );

  testWidgets('governance page shows vehicle review audit history from ledger events', (
    tester,
  ) async {
    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: DateTime.utc(2026, 3, 10, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 9, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 10, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 184,
        hashVerified: true,
        integrityScore: 98,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 24,
        humanOverrides: 3,
        overrideReasons: {'PSIRA expired': 2},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 14,
        driftDetected: 2,
        avgMatchScore: 84,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 2,
        pdpExpired: 1,
        totalBlocked: 3,
      ),
      vehicleThroughput: SovereignReportVehicleThroughput(
        totalVisits: 1,
        completedVisits: 0,
        activeVisits: 0,
        incompleteVisits: 1,
        uniqueVehicles: 1,
        repeatVehicles: 0,
        unknownVehicleEvents: 0,
        peakHourLabel: '00:00-01:00',
        peakHourVisitCount: 1,
        averageCompletedDwellMinutes: 0,
        suspiciousShortVisitCount: 0,
        loiteringVisitCount: 0,
        workflowHeadline: '1 incomplete visit stalled at SERVICE',
        summaryLine:
            'Visits 1 • Entry 1 • Completed 0 • Active 0 • Incomplete 1 • Unique 1',
        scopeBreakdowns: const [
          SovereignReportVehicleScopeBreakdown(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            totalVisits: 1,
            completedVisits: 0,
            activeVisits: 0,
            incompleteVisits: 1,
            unknownVehicleEvents: 0,
            summaryLine:
                'Visits 1 • Entry 1 • Completed 0 • Active 0 • Incomplete 1 • Unique 1',
          ),
        ],
        exceptionVisits: [
          SovereignReportVehicleVisitException(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            vehicleLabel: 'CA123456',
            statusLabel: 'COMPLETED',
            reasonLabel: 'Incomplete visit',
            workflowSummary: 'ENTRY -> SERVICE (COMPLETED)',
            operatorReviewed: true,
            operatorReviewedAtUtc: DateTime.utc(2026, 3, 10, 8, 15),
            operatorStatusOverride: 'COMPLETED',
            primaryEventId: 'EVT-201',
            startedAtUtc: DateTime.utc(2026, 3, 10, 0, 40),
            lastSeenAtUtc: DateTime.utc(2026, 3, 10, 1, 22),
            dwellMinutes: 42.0,
            eventIds: ['EVT-201'],
            zoneLabels: ['Entry Lane', 'Wash Bay'],
            intelligenceIds: ['INT-201', 'INT-202'],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: [
            VehicleVisitReviewRecorded(
              eventId: 'VR-100',
              sequence: 30,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 10, 7, 55),
              vehicleVisitKey: 'EVT-201',
              primaryEventId: 'EVT-201',
              clientId: 'CLIENT-1',
              regionId: 'REGION-1',
              siteId: 'SITE-42',
              vehicleLabel: 'CA123456',
              actorLabel: 'GOVERNANCE_OPERATOR',
              reviewed: true,
              statusOverride: 'ACTIVE',
              effectiveStatusLabel: 'ACTIVE',
              reasonLabel: 'Incomplete visit',
              workflowSummary: 'ENTRY -> SERVICE (ACTIVE)',
              sourceSurface: 'governance',
            ),
            VehicleVisitReviewRecorded(
              eventId: 'VR-101',
              sequence: 31,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 10, 8, 15),
              vehicleVisitKey: 'EVT-201',
              primaryEventId: 'EVT-201',
              clientId: 'CLIENT-1',
              regionId: 'REGION-1',
              siteId: 'SITE-42',
              vehicleLabel: 'CA123456',
              actorLabel: 'GOVERNANCE_OPERATOR',
              reviewed: true,
              statusOverride: 'COMPLETED',
              effectiveStatusLabel: 'COMPLETED',
              reasonLabel: 'Incomplete visit',
              workflowSummary: 'ENTRY -> SERVICE (COMPLETED)',
              sourceSurface: 'governance',
            ),
          ],
          morningSovereignReport: report,
          morningSovereignReportAutoRunKey: '2026-03-10',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final exceptionRow = find.byKey(
      const ValueKey('governance-vehicle-exception-CA123456-SITE-42'),
    );
    await tester.ensureVisible(exceptionRow);
    expect(
      find.textContaining(
        'Review audit: 2 actions • latest 2026-03-10 08:15 UTC • GOVERNANCE_OPERATOR set COMPLETED',
      ),
      findsOneWidget,
    );

    await tester.tap(exceptionRow);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('governance-vehicle-review-audit-EVT-201')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('governance-vehicle-review-audit-entry-VR-101'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('governance-vehicle-review-audit-entry-VR-100'),
      ),
      findsOneWidget,
    );
    expect(find.text('GOVERNANCE_OPERATOR set COMPLETED'), findsOneWidget);
    expect(
      find.text(
        '2026-03-10 08:15 UTC • Incomplete visit • ENTRY -> SERVICE (COMPLETED)',
      ),
      findsOneWidget,
    );
  });

  testWidgets('governance page lets operators review and override vehicle visits', (
    tester,
  ) async {
    String? copiedPayload;
    SovereignReport? updatedReport;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          copiedPayload = args['text'] as String?;
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

    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: DateTime.utc(2026, 3, 10, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 9, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 10, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 184,
        hashVerified: true,
        integrityScore: 98,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 24,
        humanOverrides: 3,
        overrideReasons: {'PSIRA expired': 2},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 14,
        driftDetected: 2,
        avgMatchScore: 84,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 2,
        pdpExpired: 1,
        totalBlocked: 3,
      ),
      vehicleThroughput: SovereignReportVehicleThroughput(
        totalVisits: 1,
        completedVisits: 0,
        activeVisits: 0,
        incompleteVisits: 1,
        uniqueVehicles: 1,
        repeatVehicles: 0,
        unknownVehicleEvents: 0,
        peakHourLabel: '00:00-01:00',
        peakHourVisitCount: 1,
        averageCompletedDwellMinutes: 0,
        suspiciousShortVisitCount: 0,
        loiteringVisitCount: 0,
        workflowHeadline: '1 incomplete visit stalled at SERVICE',
        summaryLine:
            'Visits 1 • Entry 1 • Completed 0 • Active 0 • Incomplete 1 • Unique 1',
        scopeBreakdowns: const [
          SovereignReportVehicleScopeBreakdown(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            totalVisits: 1,
            completedVisits: 0,
            activeVisits: 0,
            incompleteVisits: 1,
            unknownVehicleEvents: 0,
            summaryLine:
                'Visits 1 • Entry 1 • Completed 0 • Active 0 • Incomplete 1 • Unique 1',
          ),
        ],
        exceptionVisits: [
          SovereignReportVehicleVisitException(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            vehicleLabel: 'CA123456',
            statusLabel: 'INCOMPLETE',
            reasonLabel: 'Incomplete visit',
            workflowSummary: 'ENTRY -> SERVICE (INCOMPLETE)',
            primaryEventId: 'EVT-201',
            startedAtUtc: DateTime.utc(2026, 3, 10, 0, 40),
            lastSeenAtUtc: DateTime.utc(2026, 3, 10, 1, 22),
            dwellMinutes: 42.0,
            eventIds: ['EVT-201'],
            zoneLabels: ['Entry Lane', 'Wash Bay'],
            intelligenceIds: ['INT-201', 'INT-202'],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const [],
          morningSovereignReport: report,
          morningSovereignReportAutoRunKey: '2026-03-10',
          onMorningSovereignReportChanged: (value) {
            updatedReport = value;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final exceptionRow = find.byKey(
      const ValueKey('governance-vehicle-exception-CA123456-SITE-42'),
    );
    await tester.ensureVisible(exceptionRow);
    await tester.tap(exceptionRow);
    await tester.pumpAndSettle();

    expect(find.text('Visit timeline'), findsOneWidget);

    final setCompletedAction = find.byKey(
      const ValueKey('governance-vehicle-review-completed-EVT-201'),
    );
    await tester.ensureVisible(setCompletedAction);
    await tester.tap(setCompletedAction);
    await tester.pumpAndSettle();
    expect(find.text('Workflow: ENTRY -> SERVICE (COMPLETED)'), findsWidgets);

    final markReviewedAction = find.byKey(
      const ValueKey('governance-vehicle-review-mark-EVT-201'),
    );
    await tester.ensureVisible(markReviewedAction);
    await tester.tap(markReviewedAction);
    await tester.pumpAndSettle();
    expect(find.text('REVIEWED'), findsOneWidget);
    expect(updatedReport, isNotNull);
    final persistedException =
        updatedReport!.vehicleThroughput.exceptionVisits.single;
    expect(persistedException.operatorReviewed, isTrue);
    expect(persistedException.operatorStatusOverride, 'COMPLETED');
    expect(persistedException.statusLabel, 'INCOMPLETE');

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const [],
          morningSovereignReport: updatedReport,
          morningSovereignReportAutoRunKey: '2026-03-10',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final restoredExceptionRow = find.byKey(
      const ValueKey('governance-vehicle-exception-CA123456-SITE-42'),
    );
    await tester.ensureVisible(restoredExceptionRow);
    await tester.tap(restoredExceptionRow);
    await tester.pumpAndSettle();
    expect(find.text('Workflow: ENTRY -> SERVICE (COMPLETED)'), findsWidgets);
    expect(find.text('REVIEWED'), findsOneWidget);

    await tester.ensureVisible(find.text('Copy Morning JSON'));
    await tester.tap(find.text('Copy Morning JSON'));
    await tester.pump();

    expect(copiedPayload, isNotNull);
    expect(copiedPayload, contains('"operatorReviewed": true'));
    expect(copiedPayload, contains('"operatorStatusOverride": "COMPLETED"'));
    expect(copiedPayload, contains('"statusLabel": "COMPLETED"'));
    expect(
      copiedPayload,
      contains('"workflowSummary": "ENTRY -> SERVICE (COMPLETED)"'),
    );
  });
}

bool _comesBefore(Offset left, Offset right) {
  if (left.dy < right.dy) {
    return true;
  }
  if (left.dy > right.dy) {
    return false;
  }
  return left.dx < right.dx;
}
