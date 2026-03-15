import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/morning_sovereign_report_service.dart';
import 'package:omnix_dashboard/application/report_output_mode.dart';
import 'package:omnix_dashboard/application/report_preview_request.dart';
import 'package:omnix_dashboard/application/report_preview_surface.dart';
import 'package:omnix_dashboard/application/report_receipt_scene_filter.dart';
import 'package:omnix_dashboard/application/report_shell_state.dart';
import 'package:omnix_dashboard/domain/events/partner_dispatch_status_declared.dart';
import 'package:omnix_dashboard/domain/events/report_generated.dart';
import 'package:omnix_dashboard/domain/store/in_memory_event_store.dart';
import 'package:omnix_dashboard/ui/client_intelligence_reports_page.dart';

import '../fixtures/report_test_receipt.dart';
import '../fixtures/report_test_reviewed_workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('client reports export all button is actionable', (tester) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          clipboardText = args['text'] as String?;
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
        home: ClientIntelligenceReportsPage(
          store: InMemoryEventStore(),
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final exportAllButton = find.byKey(
      const ValueKey('reports-export-all-button'),
    );
    expect(find.text('REVIEWED'), findsOneWidget);
    expect(find.text('ALERTS'), findsOneWidget);
    expect(find.text('REPEAT'), findsOneWidget);
    expect(find.text('ESCALATION'), findsOneWidget);
    expect(find.text('SUPPRESSED'), findsOneWidget);
    expect(find.text('SCENE PENDING'), findsOneWidget);
    expect(find.text('All Receipts (3)'), findsOneWidget);
    expect(find.textContaining('Scene Pending'), findsWidgets);
    await tester.ensureVisible(exportAllButton);
    await tester.tap(exportAllButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Exported 3 receipt records to clipboard.'),
      findsWidgets,
    );
    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('"context"'));
    expect(clipboardText, contains('"receipts"'));
    expect(clipboardText, contains('"key": "all"'));
    expect(clipboardText, contains('"eventId": "RPT-2024-03-10-001"'));
    expect(clipboardText, contains('"reportSchemaVersion": 1'));
    expect(clipboardText, contains('"sceneReviewIncluded": false'));
  });

  testWidgets('client reports shows partner scope card and exports scoped scorecard', (
    tester,
  ) async {
    String? clipboardText;
    Map<String, String>? openedGovernanceScope;
    Map<String, Object?>? openedEventsScope;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          clipboardText = args['text'] as String?;
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

    final priorReport = SovereignReport(
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
        dispatchCount: 1,
        declarationCount: 2,
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
            averageOnSiteDelayMinutes: 0.0,
            summaryLine:
                'Dispatches 1 • Strong 0 • On track 0 • Watch 0 • Critical 1 • Avg accept 12.0m • Avg on site 0.0m',
          ),
          SovereignReportPartnerScoreboardRow(
            clientId: 'CLIENT-002',
            siteId: 'SITE-OTHER',
            partnerLabel: 'PARTNER • Beta',
            dispatchCount: 1,
            strongCount: 1,
            onTrackCount: 0,
            watchCount: 0,
            criticalCount: 0,
            averageAcceptedDelayMinutes: 5.0,
            averageOnSiteDelayMinutes: 11.0,
            summaryLine:
                'Dispatches 1 • Strong 1 • On track 0 • Watch 0 • Critical 0 • Avg accept 5.0m • Avg on site 11.0m',
          ),
        ],
      ),
    );
    final currentReport = SovereignReport(
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
        dispatchChains: [
          SovereignReportPartnerDispatchChain(
            dispatchId: 'DSP-9001',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            partnerLabel: 'PARTNER • Alpha',
            declarationCount: 3,
            latestStatus: PartnerDispatchStatus.allClear,
            latestOccurredAtUtc: DateTime.utc(2026, 3, 15, 1, 18),
            dispatchCreatedAtUtc: DateTime.utc(2026, 3, 15, 1, 0),
            acceptedAtUtc: DateTime.utc(2026, 3, 15, 1, 4),
            onSiteAtUtc: DateTime.utc(2026, 3, 15, 1, 10),
            allClearAtUtc: DateTime.utc(2026, 3, 15, 1, 18),
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
    final store = InMemoryEventStore();
    store.append(
      PartnerDispatchStatusDeclared(
        eventId: 'PARTNER-EVT-1',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 15, 1, 4),
        dispatchId: 'DSP-9001',
        clientId: 'CLIENT-001',
        regionId: 'REGION-1',
        siteId: 'SITE-SANDTON',
        partnerLabel: 'PARTNER • Alpha',
        actorLabel: 'Partner Controller',
        status: PartnerDispatchStatus.accepted,
        sourceChannel: 'telegram',
        sourceMessageKey: 'MSG-1',
      ),
    );
    store.append(
      PartnerDispatchStatusDeclared(
        eventId: 'PARTNER-EVT-2',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 15, 1, 10),
        dispatchId: 'DSP-9001',
        clientId: 'CLIENT-001',
        regionId: 'REGION-1',
        siteId: 'SITE-SANDTON',
        partnerLabel: 'PARTNER • Alpha',
        actorLabel: 'Partner Controller',
        status: PartnerDispatchStatus.onSite,
        sourceChannel: 'telegram',
        sourceMessageKey: 'MSG-2',
      ),
    );
    store.append(
      PartnerDispatchStatusDeclared(
        eventId: 'PARTNER-EVT-3',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 15, 1, 18),
        dispatchId: 'DSP-9001',
        clientId: 'CLIENT-001',
        regionId: 'REGION-1',
        siteId: 'SITE-SANDTON',
        partnerLabel: 'PARTNER • Alpha',
        actorLabel: 'Partner Controller',
        status: PartnerDispatchStatus.allClear,
        sourceChannel: 'telegram',
        sourceMessageKey: 'MSG-3',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          morningSovereignReportHistory: [priorReport, currentReport],
          initialPartnerScopeClientId: 'CLIENT-001',
          initialPartnerScopeSiteId: 'SITE-SANDTON',
          initialPartnerScopePartnerLabel: 'PARTNER • Alpha',
          onOpenGovernanceForPartnerScope: (clientId, siteId, partnerLabel) {
            openedGovernanceScope = <String, String>{
              'clientId': clientId,
              'siteId': siteId,
              'partnerLabel': partnerLabel,
            };
          },
          onOpenEventsForScope: (eventIds, selectedEventId) {
            openedEventsScope = <String, Object?>{
              'eventIds': eventIds,
              'selectedEventId': selectedEventId,
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('reports-partner-scope-banner')),
      findsOneWidget,
    );
    expect(find.text('PARTNER SCOPE ACTIVE'), findsOneWidget);
    expect(
      find.text('CLIENT-001/SITE-SANDTON • PARTNER • Alpha'),
      findsOneWidget,
    );
    expect(find.text('IMPROVING'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reports-partner-scope-chain-DSP-9001')),
      findsOneWidget,
    );
    expect(
      find.text('ACCEPT -> ON SITE -> ALL CLEAR (LATEST ALL CLEAR)'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reports-partner-chain-open-events-DSP-9001')),
      findsOneWidget,
    );

    final copyJsonButton = find.byKey(
      const ValueKey('reports-partner-scorecard-copy-json'),
    );
    await tester.ensureVisible(copyJsonButton);
    await tester.tap(copyJsonButton);
    await tester.pumpAndSettle();

    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('"partnerLabel": "PARTNER • Alpha"'));
    expect(clipboardText, contains('"trendLabel": "IMPROVING"'));
    expect(clipboardText, contains('"dispatchId": "DSP-9001"'));
    expect(clipboardText, isNot(contains('CLIENT-002')));

    final copyCsvButton = find.byKey(
      const ValueKey('reports-partner-scorecard-copy-csv'),
    );
    await tester.ensureVisible(copyCsvButton);
    await tester.tap(copyCsvButton);
    await tester.pumpAndSettle();

    expect(clipboardText, contains('partner_label,"PARTNER • Alpha"'));
    expect(clipboardText, contains('trend_label,IMPROVING'));
    expect(clipboardText, contains('dispatch_chain_1,"DSP-9001'));

    final openGovernanceButton = find.byKey(
      const ValueKey('reports-partner-scorecard-open-governance'),
    );
    await tester.ensureVisible(openGovernanceButton);
    await tester.tap(openGovernanceButton);
    await tester.pumpAndSettle();

    expect(openedGovernanceScope, <String, String>{
      'clientId': 'CLIENT-001',
      'siteId': 'SITE-SANDTON',
      'partnerLabel': 'PARTNER • Alpha',
    });

    final openEventsButton = find.byKey(
      const ValueKey('reports-partner-chain-open-events-DSP-9001'),
    );
    await tester.ensureVisible(openEventsButton);
    await tester.tap(openEventsButton);
    await tester.pumpAndSettle();

    expect(openedEventsScope, <String, Object?>{
      'eventIds': ['PARTNER-EVT-1', 'PARTNER-EVT-2', 'PARTNER-EVT-3'],
      'selectedEventId': 'PARTNER-EVT-3',
    });
  });

  testWidgets('client reports can focus and clear a partner lane locally', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          clipboardText = args['text'] as String?;
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

    final priorReport = SovereignReport(
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
        dispatchCount: 2,
        declarationCount: 4,
        acceptedCount: 2,
        onSiteCount: 1,
        allClearCount: 1,
        cancelledCount: 1,
        summaryLine: '',
        scoreboardRows: [
          SovereignReportPartnerScoreboardRow(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            partnerLabel: 'PARTNER • Alpha',
            dispatchCount: 1,
            strongCount: 0,
            onTrackCount: 1,
            watchCount: 0,
            criticalCount: 0,
            averageAcceptedDelayMinutes: 7.0,
            averageOnSiteDelayMinutes: 14.0,
            summaryLine:
                'Dispatches 1 • Strong 0 • On track 1 • Watch 0 • Critical 0 • Avg accept 7.0m • Avg on site 14.0m',
          ),
          SovereignReportPartnerScoreboardRow(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            partnerLabel: 'PARTNER • Beta',
            dispatchCount: 1,
            strongCount: 0,
            onTrackCount: 0,
            watchCount: 1,
            criticalCount: 0,
            averageAcceptedDelayMinutes: 9.0,
            averageOnSiteDelayMinutes: 18.0,
            summaryLine:
                'Dispatches 1 • Strong 0 • On track 0 • Watch 1 • Critical 0 • Avg accept 9.0m • Avg on site 18.0m',
          ),
        ],
      ),
    );
    final currentReport = SovereignReport(
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
        dispatchCount: 2,
        declarationCount: 6,
        acceptedCount: 2,
        onSiteCount: 2,
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
          SovereignReportPartnerScoreboardRow(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            partnerLabel: 'PARTNER • Beta',
            dispatchCount: 1,
            strongCount: 0,
            onTrackCount: 1,
            watchCount: 0,
            criticalCount: 0,
            averageAcceptedDelayMinutes: 6.0,
            averageOnSiteDelayMinutes: 12.0,
            summaryLine:
                'Dispatches 1 • Strong 0 • On track 1 • Watch 0 • Critical 0 • Avg accept 6.0m • Avg on site 12.0m',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: InMemoryEventStore(),
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          morningSovereignReportHistory: [priorReport, currentReport],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partner Comparison'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey(
          'reports-partner-comparison-CLIENT-001/SITE-SANDTON/PARTNER • Alpha',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('LEADER'), findsOneWidget);
    expect(find.text('Accept +2.0m • On site +2.0m vs leader'), findsOneWidget);
    expect(find.text('Recent shifts'), findsNWidgets(2));
    expect(find.text('2026-03-15 • 1 strong'), findsOneWidget);
    expect(find.text('2026-03-14 • 1 on track'), findsOneWidget);
    expect(find.text('2026-03-15 • 1 on track'), findsOneWidget);
    expect(find.text('Partner Scorecard Lanes'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reports-partner-scope-banner')),
      findsNothing,
    );

    final copyComparisonJsonButton = find.byKey(
      const ValueKey('reports-partner-comparison-copy-json'),
    );
    await tester.ensureVisible(copyComparisonJsonButton);
    await tester.tap(copyComparisonJsonButton);
    await tester.pumpAndSettle();

    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('"partnerLabel": "PARTNER • Alpha"'));
    expect(clipboardText, contains('"partnerLabel": "PARTNER • Beta"'));
    expect(clipboardText, contains('"isLeader": true'));
    expect(clipboardText, contains('"trendLabel": "IMPROVING"'));
    expect(clipboardText, contains('"reportDate": "2026-03-14"'));

    final copyComparisonCsvButton = find.byKey(
      const ValueKey('reports-partner-comparison-copy-csv'),
    );
    await tester.ensureVisible(copyComparisonCsvButton);
    await tester.tap(copyComparisonCsvButton);
    await tester.pumpAndSettle();

    expect(clipboardText, contains('client_id,CLIENT-001'));
    expect(clipboardText, contains('site_id,SITE-SANDTON'));
    expect(clipboardText, contains('comparison_1,"PARTNER • Alpha"'));
    expect(
      clipboardText,
      contains(
        'comparison_2_history_2,"2026-03-14 • HISTORY • CLIENT-001/SITE-SANDTON • PARTNER • Beta',
      ),
    );

    final focusLaneButton = find.byKey(
      const ValueKey(
        'reports-partner-lane-focus-CLIENT-001/SITE-SANDTON/PARTNER • Beta',
      ),
    );
    await tester.ensureVisible(focusLaneButton);
    await tester.tap(focusLaneButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('reports-partner-scope-banner')),
      findsOneWidget,
    );
    expect(
      find.text('CLIENT-001/SITE-SANDTON • PARTNER • Beta'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Focused Reports on SITE-SANDTON • PARTNER • Beta.'),
      findsOneWidget,
    );

    final clearFocusButton = find.byKey(
      const ValueKey('reports-partner-scorecard-clear-focus'),
    );
    await tester.ensureVisible(clearFocusButton);
    await tester.tap(clearFocusButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('reports-partner-scope-banner')),
      findsNothing,
    );
    expect(
      find.textContaining('Partner scorecard focus cleared.'),
      findsOneWidget,
    );
  });

  testWidgets('client reports export all includes latest-action lens context', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          clipboardText = args['text'] as String?;
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

    final fixture = buildReviewedReportWorkspaceFixture();

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: fixture.store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          sceneReviewByIntelligenceId: fixture.sceneReviewByIntelligenceId,
          reportShellState: const ReportShellState(
            receiptFilter: ReportReceiptSceneFilter.latestAlerts,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final exportAllButton = find.byKey(
      const ValueKey('reports-export-all-button'),
    );
    await tester.ensureVisible(exportAllButton);
    await tester.tap(exportAllButton);
    await tester.pumpAndSettle();

    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('"key": "latestAlerts"'));
    expect(clipboardText, contains('"statusLabel": "Latest Alert receipts"'));
    expect(clipboardText, contains('"focusedReceipt"'));
    expect(
      clipboardText,
      contains('"eventId": "${fixture.reviewedReceiptEventId}"'),
    );
    expect(clipboardText, contains('"latestActionBucket": "alerts"'));
    expect(clipboardText, contains('"latestActionTaken": "'));
    expect(clipboardText, contains('Monitoring Alert'));
    expect(clipboardText, contains('Camera 1'));
  });

  testWidgets('client reports row copy exports single receipt payload', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          clipboardText = args['text'] as String?;
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

    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-COPY-1',
        occurredAt: DateTime.utc(2026, 3, 14, 22, 0),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final copyButton = find.byKey(
      const ValueKey('report-receipt-copy-RPT-COPY-1'),
    );
    await tester.ensureVisible(copyButton);
    await tester.tap(copyButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Receipt export copied for RPT-COPY-1.'),
      findsWidgets,
    );
    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('"context"'));
    expect(clipboardText, contains('"receipts"'));
    expect(clipboardText, contains('"key": "all"'));
    expect(clipboardText, contains('"eventId": "RPT-COPY-1"'));
    expect(clipboardText, contains('"reportSchemaVersion": 1'));
    expect(clipboardText, contains('"sceneReviewIncluded": false'));
  });

  testWidgets('sample receipt preview and download actions are actionable', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          clipboardText = args['text'] as String?;
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
        home: ClientIntelligenceReportsPage(
          store: InMemoryEventStore(),
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final previewButton = find.byKey(
      const ValueKey('report-receipt-preview-RPT-2024-03-10-001'),
    );
    await tester.ensureVisible(previewButton);
    await tester.tap(previewButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Sample receipt preview unavailable. Generate a live report first.',
      ),
      findsWidgets,
    );

    final downloadButton = find.byKey(
      const ValueKey('report-receipt-download-RPT-2024-03-10-001'),
    );
    await tester.ensureVisible(downloadButton);
    await tester.tap(downloadButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Sample receipt metadata copied for RPT-2024-03-10-001.',
      ),
      findsWidgets,
    );
    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('"context"'));
    expect(clipboardText, contains('"receipts"'));
    expect(clipboardText, contains('"key": "all"'));
    expect(clipboardText, contains('"eventId": "RPT-2024-03-10-001"'));
    expect(clipboardText, contains('"reportSchemaVersion": 1'));
    expect(clipboardText, contains('"sceneReviewIncluded": false'));
  });

  testWidgets('client reports filter shows filtered empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: InMemoryEventStore(),
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final filter = find.byKey(const ValueKey('reports-receipt-filter'));
    await tester.ensureVisible(filter);
    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Escalation').last);
    await tester.pumpAndSettle();

    expect(find.text('No receipts match the selected filter.'), findsOneWidget);
  });

  testWidgets('client reports escalation KPI applies receipt filter', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: InMemoryEventStore(),
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final escalationKpi = find.byKey(const ValueKey('reports-kpi-escalation'));
    await tester.ensureVisible(escalationKpi);
    await tester.tap(escalationKpi);
    await tester.pumpAndSettle();

    expect(
      find.text('CLIENT-001 • SITE-SANDTON • Escalation receipts'),
      findsOneWidget,
    );
    expect(find.text('Viewing Escalation receipts (0/3)'), findsOneWidget);
    expect(find.text('No receipts match the selected filter.'), findsOneWidget);

    await tester.tap(escalationKpi);
    await tester.pumpAndSettle();

    expect(
      find.text('CLIENT-001 • SITE-SANDTON • Escalation receipts'),
      findsNothing,
    );
    expect(find.text('Viewing Escalation receipts (0/3)'), findsNothing);
    expect(find.text('No receipts match the selected filter.'), findsNothing);
  });

  testWidgets('client reports suppressed KPI applies receipt filter', (
    tester,
  ) async {
    final fixture = buildSuppressedReportWorkspaceFixture();

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: fixture.store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          sceneReviewByIntelligenceId: fixture.sceneReviewByIntelligenceId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final suppressedKpi = find.byKey(const ValueKey('reports-kpi-suppressed'));
    await tester.ensureVisible(suppressedKpi);
    await tester.tap(suppressedKpi);
    await tester.pumpAndSettle();

    expect(
      find.text('CLIENT-001 • SITE-SANDTON • Suppressed receipts'),
      findsOneWidget,
    );
    expect(find.text('Viewing Suppressed receipts (1/2)'), findsOneWidget);
    expect(
      find.textContaining('Vehicle remained below escalation threshold.'),
      findsOneWidget,
    );
    expect(find.text('No receipts match the selected filter.'), findsNothing);
  });

  testWidgets('client reports alerts KPI applies receipt filter', (
    tester,
  ) async {
    final fixture = buildReviewedReportWorkspaceFixture();

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: fixture.store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          sceneReviewByIntelligenceId: fixture.sceneReviewByIntelligenceId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final alertsKpi = find.byKey(const ValueKey('reports-kpi-alerts'));
    await tester.ensureVisible(alertsKpi);
    await tester.tap(alertsKpi);
    await tester.pumpAndSettle();

    expect(
      find.text('CLIENT-001 • SITE-SANDTON • Alert receipts'),
      findsOneWidget,
    );
    expect(find.text('Viewing Alert receipts (1/2)'), findsOneWidget);
    expect(
      find.textContaining(
        'Scene review stayed below escalation threshold across 1 reviewed CCTV event with 1 alert.',
      ),
      findsOneWidget,
    );
    expect(find.text('No receipts match the selected filter.'), findsNothing);
  });

  testWidgets(
    'client reports latest alert dropdown filter applies receipt filter',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture();

      await tester.pumpWidget(
        MaterialApp(
          home: ClientIntelligenceReportsPage(
            store: fixture.store,
            selectedClient: 'CLIENT-001',
            selectedSite: 'SITE-SANDTON',
            sceneReviewByIntelligenceId: fixture.sceneReviewByIntelligenceId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final filter = find.byKey(const ValueKey('reports-receipt-filter'));
      await tester.ensureVisible(filter);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Latest Alert').last);
      await tester.pumpAndSettle();

      expect(
        find.text('CLIENT-001 • SITE-SANDTON • Latest Alert receipts'),
        findsOneWidget,
      );
      expect(find.text('Viewing Latest Alert receipts (1/2)'), findsOneWidget);
      expect(find.text('No receipts match the selected filter.'), findsNothing);
    },
  );

  testWidgets('client reports latest action pill applies receipt filter', (
    tester,
  ) async {
    final fixture = buildReviewedReportWorkspaceFixture();

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: fixture.store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          sceneReviewByIntelligenceId: fixture.sceneReviewByIntelligenceId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Latest Alert'));
    await tester.tap(find.text('Latest Alert').first);
    await tester.pumpAndSettle();

    expect(
      find.text('CLIENT-001 • SITE-SANDTON • Latest Alert receipts'),
      findsOneWidget,
    );
    expect(find.text('Viewing Latest Alert receipts (1/2)'), findsOneWidget);
  });

  testWidgets(
    'client reports latest-action banner shortcut opens matching receipt preview',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture();
      final shellState = ValueNotifier(
        const ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.latestAlerts,
        ),
      );
      final previewRequests = <ReportPreviewRequest>[];
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ClientIntelligenceReportsPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
                onRequestPreview: previewRequests.add,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Open Focused Receipt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Focused Receipt'));
      await tester.pumpAndSettle();

      expect(previewRequests, hasLength(1));
      expect(
        previewRequests.single.receiptEvent?.eventId,
        fixture.reviewedReceiptEventId,
      );
      expect(
        shellState.value.selectedReceiptEventId,
        fixture.reviewedReceiptEventId,
      );
      expect(
        shellState.value.previewReceiptEventId,
        fixture.reviewedReceiptEventId,
      );
    },
  );

  testWidgets(
    'client reports latest-action banner copy exports focused receipt',
    (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            clipboardText = args['text'] as String?;
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

      final fixture = buildReviewedReportWorkspaceFixture();
      final shellState = ValueNotifier(
        const ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.latestAlerts,
        ),
      );
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ClientIntelligenceReportsPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Copy Focused Receipt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy Focused Receipt'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Receipt export copied for ${fixture.reviewedReceiptEventId}.',
        ),
        findsWidgets,
      );
      expect(clipboardText, isNotNull);
      expect(clipboardText, contains('"context"'));
      expect(clipboardText, contains('"receipts"'));
      expect(
        clipboardText,
        contains('"eventId": "${fixture.reviewedReceiptEventId}"'),
      );
    },
  );

  testWidgets(
    'client reports latest-action filter control shortcut opens matching receipt preview',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture();
      final shellState = ValueNotifier(
        const ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.latestAlerts,
        ),
      );
      final previewRequests = <ReportPreviewRequest>[];
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ClientIntelligenceReportsPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
                onRequestPreview: previewRequests.add,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(
          const ValueKey('report-receipt-filter-control-open-focused'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('report-receipt-filter-control-open-focused'),
        ),
      );
      await tester.pumpAndSettle();

      expect(previewRequests, hasLength(1));
      expect(
        previewRequests.single.receiptEvent?.eventId,
        fixture.reviewedReceiptEventId,
      );
      expect(
        shellState.value.selectedReceiptEventId,
        fixture.reviewedReceiptEventId,
      );
      expect(
        shellState.value.previewReceiptEventId,
        fixture.reviewedReceiptEventId,
      );
    },
  );

  testWidgets(
    'client reports active latest action pill opens matching receipt preview',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture();
      final shellState = ValueNotifier(
        const ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.latestAlerts,
        ),
      );
      final previewRequests = <ReportPreviewRequest>[];
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ClientIntelligenceReportsPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
                onRequestPreview: previewRequests.add,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Latest Alert').first);
      await tester.tap(find.text('Latest Alert').first);
      await tester.pumpAndSettle();

      expect(previewRequests, hasLength(1));
      expect(
        previewRequests.single.receiptEvent?.eventId,
        fixture.reviewedReceiptEventId,
      );
      expect(
        shellState.value.selectedReceiptEventId,
        fixture.reviewedReceiptEventId,
      );
      expect(
        shellState.value.previewReceiptEventId,
        fixture.reviewedReceiptEventId,
      );
    },
  );

  testWidgets('client reports syncs receipt filter from parent updates', (
    tester,
  ) async {
    final shellState = ValueNotifier(const ReportShellState());
    addTearDown(shellState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<ReportShellState>(
          valueListenable: shellState,
          builder: (context, value, _) {
            return ClientIntelligenceReportsPage(
              store: InMemoryEventStore(),
              selectedClient: 'CLIENT-001',
              selectedSite: 'SITE-SANDTON',
              reportShellState: value,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    shellState.value = shellState.value.copyWith(
      receiptFilter: ReportReceiptSceneFilter.pending,
    );
    await tester.pumpAndSettle();

    expect(
      find.text('CLIENT-001 • SITE-SANDTON • Scene Pending receipts'),
      findsOneWidget,
    );
    expect(find.text('Viewing Scene Pending receipts (3/3)'), findsOneWidget);
  });

  testWidgets('client reports syncs output mode from parent updates', (
    tester,
  ) async {
    final shellState = ValueNotifier(const ReportShellState());
    addTearDown(shellState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<ReportShellState>(
          valueListenable: shellState,
          builder: (context, value, _) {
            return ClientIntelligenceReportsPage(
              store: InMemoryEventStore(),
              selectedClient: 'CLIENT-001',
              selectedSite: 'SITE-SANDTON',
              reportShellState: value,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    shellState.value = shellState.value.copyWith(
      outputMode: ReportOutputMode.json,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('reports-output-mode-json')),
      findsOneWidget,
    );
    expect(find.text('JSON'), findsWidgets);
  });

  testWidgets('client reports output mode control updates shell state', (
    tester,
  ) async {
    final shellState = ValueNotifier(const ReportShellState());
    addTearDown(shellState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<ReportShellState>(
          valueListenable: shellState,
          builder: (context, value, _) {
            return ClientIntelligenceReportsPage(
              store: InMemoryEventStore(),
              selectedClient: 'CLIENT-001',
              selectedSite: 'SITE-SANDTON',
              reportShellState: value,
              onReportShellStateChanged: (next) => shellState.value = next,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final jsonControl = find.byKey(const ValueKey('reports-output-mode-json'));
    await tester.ensureVisible(jsonControl);
    await tester.tap(jsonControl);
    await tester.pumpAndSettle();

    expect(shellState.value.outputMode, ReportOutputMode.json);
    expect(find.text('JSON'), findsWidgets);
  });

  testWidgets(
    'client reports preserves reviewed target across output mode switches',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-LIVE-OUTPUT-REVIEWED-1',
        pendingReceiptEventId: 'RPT-LIVE-OUTPUT-PENDING-1',
        intelligenceEventId: 'INTEL-OUTPUT-REVIEWED-1',
        intelligenceId: 'intel-output-reviewed-1',
      );
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
      final shellState = ValueNotifier(
        ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.reviewed,
          selectedReceiptEventId: reviewedReceiptEventId,
          previewReceiptEventId: reviewedReceiptEventId,
        ),
      );
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ClientIntelligenceReportsPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(find.text('Open Preview Target'), findsOneWidget);

      final jsonControl = find.byKey(
        const ValueKey('reports-output-mode-json'),
      );
      await tester.ensureVisible(jsonControl);
      await tester.tap(jsonControl);
      await tester.pumpAndSettle();

      expect(shellState.value.outputMode, ReportOutputMode.json);
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
      expect(shellState.value.previewReceiptEventId, reviewedReceiptEventId);
      expect(find.text('JSON'), findsWidgets);
      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(find.text('Open Preview Target'), findsOneWidget);
    },
  );

  testWidgets(
    'client reports syncs selected receipt focus from parent updates',
    (tester) async {
      final shellState = ValueNotifier(const ReportShellState());
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ClientIntelligenceReportsPage(
                store: InMemoryEventStore(),
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                reportShellState: value,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      shellState.value = shellState.value.copyWith(
        selectedReceiptEventId: 'RPT-2024-03-10-001',
      );
      await tester.pumpAndSettle();

      expect(find.text('Open Selected Receipt'), findsOneWidget);
      expect(find.text('FOCUSED'), findsNWidgets(2));
    },
  );

  testWidgets(
    'client reports restores focused reviewed receipt after filter detour',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-LIVE-FILTER-REVIEWED-1',
        pendingReceiptEventId: 'RPT-LIVE-FILTER-PENDING-1',
        intelligenceEventId: 'INTEL-FILTER-REVIEWED-1',
        intelligenceId: 'intel-filter-reviewed-1',
      );
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
      final shellState = ValueNotifier(
        ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.reviewed,
          selectedReceiptEventId: reviewedReceiptEventId,
        ),
      );
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ClientIntelligenceReportsPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(find.text('Open Selected Receipt'), findsOneWidget);

      final escalationKpi = find.byKey(
        const ValueKey('reports-kpi-escalation'),
      );
      await tester.ensureVisible(escalationKpi);
      await tester.tap(escalationKpi);
      await tester.pumpAndSettle();

      expect(find.text('Viewing Escalation receipts (0/2)'), findsOneWidget);
      expect(
        find.text('No receipts match the selected filter.'),
        findsOneWidget,
      );
      expect(find.text('No Receipt Selected'), findsOneWidget);
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);

      final reviewedKpi = find.byKey(const ValueKey('reports-kpi-reviewed'));
      await tester.ensureVisible(reviewedKpi);
      await tester.tap(reviewedKpi);
      await tester.pumpAndSettle();

      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(find.text('Open Selected Receipt'), findsOneWidget);
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
    },
  );

  testWidgets(
    'client reports restores reviewed preview target after filter detour',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-LIVE-FILTER-TARGET-REVIEWED-1',
        pendingReceiptEventId: 'RPT-LIVE-FILTER-TARGET-PENDING-1',
        intelligenceEventId: 'INTEL-FILTER-TARGET-REVIEWED-1',
        intelligenceId: 'intel-filter-target-reviewed-1',
      );
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
      final shellState = ValueNotifier(
        ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.reviewed,
          selectedReceiptEventId: reviewedReceiptEventId,
          previewReceiptEventId: reviewedReceiptEventId,
        ),
      );
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ClientIntelligenceReportsPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(find.text('Open Preview Target'), findsOneWidget);

      final escalationKpi = find.byKey(
        const ValueKey('reports-kpi-escalation'),
      );
      await tester.ensureVisible(escalationKpi);
      await tester.tap(escalationKpi);
      await tester.pumpAndSettle();

      expect(find.text('Viewing Escalation receipts (0/2)'), findsOneWidget);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(
        find.text('No receipts match the selected filter.'),
        findsOneWidget,
      );
      expect(find.text('No Receipt Selected'), findsOneWidget);
      expect(shellState.value.previewReceiptEventId, reviewedReceiptEventId);

      final reviewedKpi = find.byKey(const ValueKey('reports-kpi-reviewed'));
      await tester.ensureVisible(reviewedKpi);
      await tester.tap(reviewedKpi);
      await tester.pumpAndSettle();

      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(find.text('Open Preview Target'), findsOneWidget);
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
      expect(shellState.value.previewReceiptEventId, reviewedReceiptEventId);
    },
  );

  testWidgets(
    'client reports preserves reviewed target across preview surface switches',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-LIVE-SURFACE-REVIEWED-1',
        pendingReceiptEventId: 'RPT-LIVE-SURFACE-PENDING-1',
        intelligenceEventId: 'INTEL-SURFACE-REVIEWED-1',
        intelligenceId: 'intel-surface-reviewed-1',
      );
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
      final shellState = ValueNotifier(
        ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.reviewed,
          selectedReceiptEventId: reviewedReceiptEventId,
          previewReceiptEventId: reviewedReceiptEventId,
          previewSurface: ReportPreviewSurface.route,
        ),
      );
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ClientIntelligenceReportsPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(find.text('Open Preview Target'), findsOneWidget);

      final dockControl = find.byKey(
        const ValueKey('reports-preview-surface-dock'),
      );
      await tester.ensureVisible(dockControl);
      await tester.tap(dockControl);
      await tester.pumpAndSettle();

      expect(shellState.value.previewSurface, ReportPreviewSurface.dock);
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
      expect(shellState.value.previewReceiptEventId, reviewedReceiptEventId);
      expect(find.text('Preview Dock'), findsOneWidget);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(find.text('Open Full Preview'), findsWidgets);

      final routeControl = find.byKey(
        const ValueKey('reports-preview-surface-route'),
      );
      await tester.ensureVisible(routeControl);
      await tester.tap(routeControl);
      await tester.pumpAndSettle();

      expect(shellState.value.previewSurface, ReportPreviewSurface.route);
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
      expect(shellState.value.previewReceiptEventId, reviewedReceiptEventId);
      expect(find.text('Preview Dock'), findsNothing);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(find.text('Open Preview Target'), findsOneWidget);
    },
  );

  testWidgets('client reports syncs preview target from parent updates', (
    tester,
  ) async {
    final shellState = ValueNotifier(const ReportShellState());
    addTearDown(shellState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<ReportShellState>(
          valueListenable: shellState,
          builder: (context, value, _) {
            return ClientIntelligenceReportsPage(
              store: InMemoryEventStore(),
              selectedClient: 'CLIENT-001',
              selectedSite: 'SITE-SANDTON',
              reportShellState: value,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    shellState.value = shellState.value.copyWith(
      previewReceiptEventId: 'RPT-2024-03-10-001',
    );
    await tester.pumpAndSettle();

    expect(find.text('Preview target: RPT-2024-03-10-001'), findsOneWidget);
    expect(find.text('Open Preview Target'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reports-preview-target-open')),
      findsOneWidget,
    );
  });

  testWidgets('client reports syncs preview surface from parent updates', (
    tester,
  ) async {
    final shellState = ValueNotifier(const ReportShellState());
    addTearDown(shellState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<ReportShellState>(
          valueListenable: shellState,
          builder: (context, value, _) {
            return ClientIntelligenceReportsPage(
              store: InMemoryEventStore(),
              selectedClient: 'CLIENT-001',
              selectedSite: 'SITE-SANDTON',
              reportShellState: value,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    shellState.value = shellState.value.copyWith(
      previewReceiptEventId: 'RPT-2024-03-10-001',
      previewSurface: ReportPreviewSurface.dock,
    );
    await tester.pumpAndSettle();

    expect(find.text('Preview Dock'), findsOneWidget);
    expect(find.text('Docked'), findsOneWidget);
    expect(find.text('Open Full Preview'), findsWidgets);
    expect(
      find.byKey(const ValueKey('reports-preview-dock-open')),
      findsOneWidget,
    );
  });

  testWidgets('client reports preview surface control updates shell state', (
    tester,
  ) async {
    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-LIVE-DOCK-1',
        occurredAt: DateTime.utc(2026, 3, 15, 0, 15),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 2,
        projectionVersion: 2,
      ),
    );
    final shellState = ValueNotifier(
      const ReportShellState(previewReceiptEventId: 'RPT-LIVE-DOCK-1'),
    );
    addTearDown(shellState.dispose);
    ReportShellState? changedState;

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<ReportShellState>(
          valueListenable: shellState,
          builder: (context, value, _) {
            return ClientIntelligenceReportsPage(
              store: store,
              selectedClient: 'CLIENT-001',
              selectedSite: 'SITE-SANDTON',
              reportShellState: value,
              onReportShellStateChanged: (next) => changedState = next,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preview Dock'), findsNothing);

    final dockControl = find.byKey(
      const ValueKey('reports-preview-surface-dock'),
    );
    await tester.ensureVisible(dockControl);
    await tester.tap(dockControl);
    await tester.pump();
    shellState.value = changedState!;
    await tester.pumpAndSettle();

    expect(shellState.value.previewSurface, ReportPreviewSurface.dock);
    expect(find.text('Preview Dock'), findsOneWidget);
    expect(find.text('Docked'), findsOneWidget);
  });

  testWidgets('client reports preview target clear updates shell state', (
    tester,
  ) async {
    final shellState = ValueNotifier(const ReportShellState());
    addTearDown(shellState.dispose);
    ReportShellState? changedState;

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<ReportShellState>(
          valueListenable: shellState,
          builder: (context, value, _) {
            return ClientIntelligenceReportsPage(
              store: InMemoryEventStore(),
              selectedClient: 'CLIENT-001',
              selectedSite: 'SITE-SANDTON',
              reportShellState: value,
              onReportShellStateChanged: (next) {
                changedState = next;
                shellState.value = next;
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    shellState.value = shellState.value.copyWith(
      previewReceiptEventId: 'RPT-2024-03-10-001',
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('reports-preview-target-clear')),
    );
    await tester.pumpAndSettle();

    expect(changedState?.previewReceiptEventId, isNull);
    expect(find.text('Preview target: RPT-2024-03-10-001'), findsNothing);
  });

  testWidgets(
    'client reports preview target clear keeps reviewed receipt focused',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-LIVE-CLEAR-REVIEWED-1',
        pendingReceiptEventId: 'RPT-LIVE-CLEAR-PENDING-1',
        intelligenceEventId: 'INTEL-CLEAR-REVIEWED-1',
        intelligenceId: 'intel-clear-reviewed-1',
      );
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
      final shellState = ValueNotifier(
        ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.reviewed,
          selectedReceiptEventId: reviewedReceiptEventId,
          previewReceiptEventId: reviewedReceiptEventId,
        ),
      );
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ClientIntelligenceReportsPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('reports-preview-target-clear')),
      );
      await tester.pumpAndSettle();

      expect(shellState.value.previewReceiptEventId, isNull);
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsNothing,
      );
      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(find.text('Open Selected Receipt'), findsOneWidget);
    },
  );

  testWidgets('client reports dock clear updates shell state', (tester) async {
    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-LIVE-DOCK-CLEAR-1',
        occurredAt: DateTime.utc(2026, 3, 15, 0, 20),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 2,
        projectionVersion: 2,
      ),
    );
    final shellState = ValueNotifier(
      const ReportShellState(
        previewReceiptEventId: 'RPT-LIVE-DOCK-CLEAR-1',
        previewSurface: ReportPreviewSurface.dock,
      ),
    );
    addTearDown(shellState.dispose);
    ReportShellState? changedState;

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<ReportShellState>(
          valueListenable: shellState,
          builder: (context, value, _) {
            return ClientIntelligenceReportsPage(
              store: store,
              selectedClient: 'CLIENT-001',
              selectedSite: 'SITE-SANDTON',
              reportShellState: value,
              onReportShellStateChanged: (next) {
                changedState = next;
                shellState.value = next;
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preview Dock'), findsOneWidget);

    final dockClear = find.byKey(const ValueKey('reports-preview-dock-clear'));
    await tester.scrollUntilVisible(
      dockClear,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(dockClear);
    await tester.pumpAndSettle();

    expect(changedState?.previewReceiptEventId, isNull);
    expect(find.text('Preview Dock'), findsNothing);
  });

  testWidgets('client reports dock clear keeps reviewed receipt focused', (
    tester,
  ) async {
    final fixture = buildReviewedReportWorkspaceFixture(
      reviewedReceiptEventId: 'RPT-LIVE-DOCK-CLEAR-REVIEWED-1',
      pendingReceiptEventId: 'RPT-LIVE-DOCK-CLEAR-PENDING-1',
      intelligenceEventId: 'INTEL-DOCK-CLEAR-REVIEWED-1',
      intelligenceId: 'intel-dock-clear-reviewed-1',
    );
    final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
    final shellState = ValueNotifier(
      ReportShellState(
        receiptFilter: ReportReceiptSceneFilter.reviewed,
        selectedReceiptEventId: reviewedReceiptEventId,
        previewReceiptEventId: reviewedReceiptEventId,
        previewSurface: ReportPreviewSurface.dock,
      ),
    );
    addTearDown(shellState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<ReportShellState>(
          valueListenable: shellState,
          builder: (context, value, _) {
            return ClientIntelligenceReportsPage(
              store: fixture.store,
              selectedClient: 'CLIENT-001',
              selectedSite: 'SITE-SANDTON',
              sceneReviewByIntelligenceId: fixture.sceneReviewByIntelligenceId,
              reportShellState: value,
              onReportShellStateChanged: (next) => shellState.value = next,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preview Dock'), findsOneWidget);
    expect(
      find.text('Preview target: $reviewedReceiptEventId'),
      findsOneWidget,
    );

    final dockClear = find.byKey(const ValueKey('reports-preview-dock-clear'));
    await tester.ensureVisible(dockClear);
    await tester.tap(dockClear);
    await tester.pumpAndSettle();

    expect(shellState.value.previewReceiptEventId, isNull);
    expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
    expect(find.text('Preview Dock'), findsNothing);
    expect(find.text('Preview target: $reviewedReceiptEventId'), findsNothing);
    expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
    expect(find.text('Open Selected Receipt'), findsOneWidget);
  });

  testWidgets('client reports uses shared preview callback when provided', (
    tester,
  ) async {
    ReportPreviewRequest? previewRequest;
    ReportShellState? changedState;
    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-LIVE-1',
        occurredAt: DateTime.utc(2026, 3, 14, 23, 55),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          onReportShellStateChanged: (next) => changedState = next,
          onRequestPreview: (value) => previewRequest = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final previewButton = find.byKey(
      const ValueKey('report-receipt-preview-RPT-LIVE-1'),
    );
    await tester.ensureVisible(previewButton);
    await tester.tap(previewButton);
    await tester.pumpAndSettle();

    expect(previewRequest?.receiptEvent?.eventId, 'RPT-LIVE-1');
    expect(changedState?.selectedReceiptEventId, 'RPT-LIVE-1');
    expect(changedState?.previewReceiptEventId, 'RPT-LIVE-1');
  });

  testWidgets('client reports dock open triggers preview request', (
    tester,
  ) async {
    ReportPreviewRequest? previewRequest;
    ReportShellState? changedState;
    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-LIVE-DOCK-OPEN-1',
        occurredAt: DateTime.utc(2026, 3, 15, 0, 45),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          reportShellState: const ReportShellState(
            previewReceiptEventId: 'RPT-LIVE-DOCK-OPEN-1',
            previewSurface: ReportPreviewSurface.dock,
          ),
          onReportShellStateChanged: (next) => changedState = next,
          onRequestPreview: (value) => previewRequest = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preview Dock'), findsOneWidget);

    final dockOpen = find.byKey(const ValueKey('reports-preview-dock-open'));
    await tester.ensureVisible(dockOpen);
    await tester.tap(dockOpen);
    await tester.pumpAndSettle();

    expect(previewRequest?.receiptEvent?.eventId, 'RPT-LIVE-DOCK-OPEN-1');
    expect(changedState?.selectedReceiptEventId, 'RPT-LIVE-DOCK-OPEN-1');
    expect(changedState?.previewReceiptEventId, 'RPT-LIVE-DOCK-OPEN-1');
    expect(find.text('Scene Review Brief'), findsNothing);
    expect(find.text('Preview Dock'), findsOneWidget);
    expect(find.text('Preview target: RPT-LIVE-DOCK-OPEN-1'), findsOneWidget);
  });

  testWidgets(
    'client reports dock open stays docked without preview callback',
    (tester) async {
      final store = InMemoryEventStore();
      store.append(
        buildTestReportGenerated(
          eventId: 'RPT-LIVE-DOCK-ROUTE-1',
          occurredAt: DateTime.utc(2026, 3, 15, 0, 55),
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          reportSchemaVersion: 2,
          projectionVersion: 2,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClientIntelligenceReportsPage(
            store: store,
            selectedClient: 'CLIENT-001',
            selectedSite: 'SITE-SANDTON',
            reportShellState: const ReportShellState(
              previewReceiptEventId: 'RPT-LIVE-DOCK-ROUTE-1',
              previewSurface: ReportPreviewSurface.dock,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Preview Dock'), findsOneWidget);

      final dockOpen = find.byKey(const ValueKey('reports-preview-dock-open'));
      await tester.ensureVisible(dockOpen);
      await tester.tap(dockOpen);
      await tester.pumpAndSettle();

      expect(find.text('Scene Review Brief'), findsNothing);
      expect(find.text('Preview Dock'), findsOneWidget);
      expect(
        find.text('Preview target: RPT-LIVE-DOCK-ROUTE-1'),
        findsOneWidget,
      );
    },
  );

  testWidgets('client reports dock copy exports targeted receipt', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          clipboardText = args['text'] as String?;
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

    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-LIVE-DOCK-COPY-1',
        occurredAt: DateTime.utc(2026, 3, 15, 0, 55),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 2,
        projectionVersion: 2,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          reportShellState: const ReportShellState(
            previewReceiptEventId: 'RPT-LIVE-DOCK-COPY-1',
            previewSurface: ReportPreviewSurface.dock,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dockCopy = find.byKey(const ValueKey('reports-preview-dock-copy'));
    await tester.ensureVisible(dockCopy);
    await tester.tap(dockCopy);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Receipt export copied for RPT-LIVE-DOCK-COPY-1.'),
      findsWidgets,
    );
    expect(clipboardText, contains('"eventId": "RPT-LIVE-DOCK-COPY-1"'));
  });

  testWidgets('client reports preview target open triggers preview request', (
    tester,
  ) async {
    ReportPreviewRequest? previewRequest;
    ReportShellState? changedState;
    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-LIVE-TARGET-1',
        occurredAt: DateTime.utc(2026, 3, 15, 0, 40),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          reportShellState: const ReportShellState(
            previewReceiptEventId: 'RPT-LIVE-TARGET-1',
          ),
          onReportShellStateChanged: (next) => changedState = next,
          onRequestPreview: (value) => previewRequest = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final openTarget = find.byKey(
      const ValueKey('reports-preview-target-open'),
    );
    await tester.ensureVisible(openTarget);
    await tester.tap(openTarget);
    await tester.pumpAndSettle();

    expect(previewRequest?.receiptEvent?.eventId, 'RPT-LIVE-TARGET-1');
    expect(changedState?.selectedReceiptEventId, 'RPT-LIVE-TARGET-1');
    expect(changedState?.previewReceiptEventId, 'RPT-LIVE-TARGET-1');
  });

  testWidgets('client reports preview target copy exports targeted receipt', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          clipboardText = args['text'] as String?;
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

    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-LIVE-TARGET-COPY-1',
        occurredAt: DateTime.utc(2026, 3, 15, 0, 40),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          reportShellState: const ReportShellState(
            previewReceiptEventId: 'RPT-LIVE-TARGET-COPY-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final copyTarget = find.byKey(
      const ValueKey('reports-preview-target-copy'),
    );
    await tester.ensureVisible(copyTarget);
    await tester.tap(copyTarget);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Receipt export copied for RPT-LIVE-TARGET-COPY-1.'),
      findsWidgets,
    );
    expect(clipboardText, contains('"eventId": "RPT-LIVE-TARGET-COPY-1"'));
  });

  testWidgets(
    'client reports preview target emits reviewed scene payload for reviewed receipt',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-LIVE-TARGET-REVIEWED-1',
        pendingReceiptEventId: 'RPT-LIVE-TARGET-PENDING-1',
        intelligenceEventId: 'INTEL-TARGET-REVIEWED-1',
        intelligenceId: 'intel-target-reviewed-1',
      );
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
      final shellState = ValueNotifier(
        ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.reviewed,
          previewReceiptEventId: reviewedReceiptEventId,
        ),
      );
      final previewRequests = <ReportPreviewRequest>[];
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ClientIntelligenceReportsPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
                onRequestPreview: previewRequests.add,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );

      final openTarget = find.byKey(
        const ValueKey('reports-preview-target-open'),
      );
      await tester.ensureVisible(openTarget);
      await tester.tap(openTarget);
      await tester.pumpAndSettle();

      expect(previewRequests, hasLength(1));
      expect(
        previewRequests.single.receiptEvent?.eventId,
        reviewedReceiptEventId,
      );
      expect(previewRequests.single.bundle.sceneReview.totalReviews, 1);
      expect(
        previewRequests.single.bundle.sceneReview.highlights.single.summary,
        'Vehicle remained below escalation threshold.',
      );
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
      expect(shellState.value.previewReceiptEventId, reviewedReceiptEventId);
    },
  );

  testWidgets(
    'client reports preview target opens reviewed preview route and returns focused',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-LIVE-TARGET-ROUTE-REVIEWED-1',
        pendingReceiptEventId: 'RPT-LIVE-TARGET-ROUTE-PENDING-1',
        intelligenceEventId: 'INTEL-TARGET-ROUTE-REVIEWED-1',
        intelligenceId: 'intel-target-route-reviewed-1',
      );
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
      final shellState = ValueNotifier(
        ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.reviewed,
          previewReceiptEventId: reviewedReceiptEventId,
          previewSurface: ReportPreviewSurface.route,
        ),
      );
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ClientIntelligenceReportsPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final openTarget = find.byKey(
        const ValueKey('reports-preview-target-open'),
      );
      await tester.ensureVisible(openTarget);
      await tester.tap(openTarget);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Scene Review Brief'), findsOneWidget);
      expect(find.text('Receipt Integrity'), findsOneWidget);
      expect(find.textContaining(reviewedReceiptEventId), findsWidgets);
      expect(
        find.textContaining('Vehicle remained below escalation threshold.'),
        findsOneWidget,
      );

      Navigator.of(tester.element(find.text('Scene Review Brief'))).pop();
      await tester.pumpAndSettle();

      expect(find.text('Scene Review Brief'), findsNothing);
      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
      expect(shellState.value.previewReceiptEventId, reviewedReceiptEventId);
    },
  );

  testWidgets('client reports review lane opens focused receipt', (
    tester,
  ) async {
    ReportPreviewRequest? previewRequest;
    ReportShellState? changedState;
    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-LIVE-LANE-1',
        occurredAt: DateTime.utc(2026, 3, 15, 0, 30),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          reportShellState: const ReportShellState(
            selectedReceiptEventId: 'RPT-LIVE-LANE-1',
          ),
          onReportShellStateChanged: (next) => changedState = next,
          onRequestPreview: (value) => previewRequest = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reviewAction = find.text('Open Selected Receipt').first;
    await tester.ensureVisible(reviewAction);
    await tester.tap(reviewAction);
    await tester.pumpAndSettle();

    expect(previewRequest?.receiptEvent?.eventId, 'RPT-LIVE-LANE-1');
    expect(changedState?.selectedReceiptEventId, 'RPT-LIVE-LANE-1');
  });

  testWidgets('client reports review lane copy exports focused receipt', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          clipboardText = args['text'] as String?;
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

    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-LIVE-LANE-COPY-1',
        occurredAt: DateTime.utc(2026, 3, 15, 0, 30),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          reportShellState: const ReportShellState(
            selectedReceiptEventId: 'RPT-LIVE-LANE-COPY-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final copyAction = find.byKey(const ValueKey('reports-review-copy-button'));
    await tester.ensureVisible(copyAction);
    await tester.tap(copyAction);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Receipt export copied for RPT-LIVE-LANE-COPY-1.'),
      findsWidgets,
    );
    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('"context"'));
    expect(clipboardText, contains('"receipts"'));
    expect(clipboardText, contains('"eventId": "RPT-LIVE-LANE-COPY-1"'));
  });

  testWidgets(
    'client reports review lane emits reviewed scene payload for focused reviewed receipt',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-LIVE-LANE-REVIEWED-1',
        pendingReceiptEventId: 'RPT-LIVE-LANE-PENDING-1',
        intelligenceEventId: 'INTEL-LANE-REVIEWED-1',
        intelligenceId: 'intel-lane-reviewed-1',
      );
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
      final shellState = ValueNotifier(
        ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.reviewed,
          selectedReceiptEventId: reviewedReceiptEventId,
        ),
      );
      final previewRequests = <ReportPreviewRequest>[];
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ClientIntelligenceReportsPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
                onRequestPreview: previewRequests.add,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(find.text('Open Selected Receipt'), findsOneWidget);

      final reviewAction = find.text('Open Selected Receipt').first;
      await tester.ensureVisible(reviewAction);
      await tester.tap(reviewAction);
      await tester.pumpAndSettle();

      expect(previewRequests, hasLength(1));
      expect(
        previewRequests.single.receiptEvent?.eventId,
        reviewedReceiptEventId,
      );
      expect(previewRequests.single.bundle.sceneReview.totalReviews, 1);
      expect(
        previewRequests.single.bundle.sceneReview.highlights.single.summary,
        'Vehicle remained below escalation threshold.',
      );
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
      expect(shellState.value.previewReceiptEventId, reviewedReceiptEventId);
    },
  );

  testWidgets(
    'client reports review lane opens reviewed preview route and returns focused',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-LIVE-LANE-ROUTE-REVIEWED-1',
        pendingReceiptEventId: 'RPT-LIVE-LANE-ROUTE-PENDING-1',
        intelligenceEventId: 'INTEL-LANE-ROUTE-REVIEWED-1',
        intelligenceId: 'intel-lane-route-reviewed-1',
      );
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
      final shellState = ValueNotifier(
        ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.reviewed,
          selectedReceiptEventId: reviewedReceiptEventId,
          previewSurface: ReportPreviewSurface.route,
        ),
      );
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ClientIntelligenceReportsPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final reviewAction = find.text('Open Selected Receipt').first;
      await tester.ensureVisible(reviewAction);
      await tester.tap(reviewAction);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Scene Review Brief'), findsOneWidget);
      expect(find.text('Receipt Integrity'), findsOneWidget);
      expect(find.textContaining(reviewedReceiptEventId), findsWidgets);
      expect(
        find.textContaining('Vehicle remained below escalation threshold.'),
        findsOneWidget,
      );

      Navigator.of(tester.element(find.text('Scene Review Brief'))).pop();
      await tester.pumpAndSettle();

      expect(find.text('Scene Review Brief'), findsNothing);
      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
      expect(shellState.value.previewReceiptEventId, reviewedReceiptEventId);
    },
  );

  testWidgets(
    'client reports opens preview route when no callback is provided in route mode',
    (tester) async {
      final store = InMemoryEventStore();
      store.append(
        buildTestReportGenerated(
          eventId: 'RPT-LIVE-ROUTE-1',
          occurredAt: DateTime.utc(2026, 3, 15, 0, 5),
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          reportSchemaVersion: 2,
          projectionVersion: 2,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClientIntelligenceReportsPage(
            store: store,
            selectedClient: 'CLIENT-001',
            selectedSite: 'SITE-SANDTON',
            reportShellState: const ReportShellState(
              previewSurface: ReportPreviewSurface.route,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final previewButton = find.byKey(
        const ValueKey('report-receipt-preview-RPT-LIVE-ROUTE-1'),
      );
      await tester.ensureVisible(previewButton);
      await tester.tap(previewButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Scene Review Brief'), findsOneWidget);
      expect(find.text('Receipt'), findsOneWidget);
    },
  );

  testWidgets('client reports supports a reviewed dock workflow end to end', (
    tester,
  ) async {
    final fixture = buildReviewedReportWorkspaceFixture(
      reviewedReceiptEventId: 'RPT-LIVE-REVIEWED-1',
      pendingReceiptEventId: 'RPT-LIVE-PENDING-1',
      intelligenceEventId: 'INTEL-REVIEWED-1',
      intelligenceId: 'intel-reviewed-1',
    );
    final store = fixture.store;
    final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
    final pendingReceiptEventId = fixture.pendingReceiptEventId;

    final shellState = ValueNotifier(const ReportShellState());
    final previewRequests = <ReportPreviewRequest>[];
    addTearDown(shellState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<ReportShellState>(
          valueListenable: shellState,
          builder: (context, value, _) {
            return ClientIntelligenceReportsPage(
              store: store,
              selectedClient: 'CLIENT-001',
              selectedSite: 'SITE-SANDTON',
              sceneReviewByIntelligenceId: fixture.sceneReviewByIntelligenceId,
              reportShellState: value,
              onReportShellStateChanged: (next) => shellState.value = next,
              onRequestPreview: previewRequests.add,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reviewedKpi = find.byKey(const ValueKey('reports-kpi-reviewed'));
    await tester.ensureVisible(reviewedKpi);
    await tester.tap(reviewedKpi);
    await tester.pumpAndSettle();

    expect(
      find.text('CLIENT-001 • SITE-SANDTON • Reviewed receipts'),
      findsOneWidget,
    );
    expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
    expect(
      find.byKey(ValueKey('report-receipt-preview-$reviewedReceiptEventId')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('report-receipt-preview-$pendingReceiptEventId')),
      findsNothing,
    );

    final dockControl = find.byKey(
      const ValueKey('reports-preview-surface-dock'),
    );
    await tester.ensureVisible(dockControl);
    await tester.tap(dockControl);
    await tester.pumpAndSettle();

    expect(shellState.value.previewSurface, ReportPreviewSurface.dock);

    final previewButton = find.byKey(
      ValueKey('report-receipt-preview-$reviewedReceiptEventId'),
    );
    await tester.ensureVisible(previewButton);
    await tester.tap(previewButton);
    await tester.pumpAndSettle();

    expect(
      previewRequests.single.receiptEvent?.eventId,
      reviewedReceiptEventId,
    );
    expect(previewRequests.single.bundle.sceneReview.totalReviews, 1);
    expect(
      previewRequests.single.bundle.sceneReview.highlights.single.summary,
      'Vehicle remained below escalation threshold.',
    );
    expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
    expect(shellState.value.previewReceiptEventId, reviewedReceiptEventId);
    expect(find.text('Alert 1'), findsOneWidget);
    expect(find.text('Latest Alert'), findsOneWidget);
    expect(find.textContaining('Latest action taken:'), findsOneWidget);
    expect(find.text('Preview Dock'), findsOneWidget);
    expect(
      find.text('Preview target: $reviewedReceiptEventId'),
      findsOneWidget,
    );
    expect(find.text(reviewedReceiptEventId), findsWidgets);
  });

  testWidgets(
    'client reports opens reviewed receipt into preview route end to end',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-LIVE-ROUTE-REVIEWED-1',
        pendingReceiptEventId: 'RPT-LIVE-ROUTE-PENDING-1',
        intelligenceEventId: 'INTEL-ROUTE-REVIEWED-1',
        intelligenceId: 'intel-route-reviewed-1',
      );
      final store = fixture.store;
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;

      await tester.pumpWidget(
        MaterialApp(
          home: ClientIntelligenceReportsPage(
            store: store,
            selectedClient: 'CLIENT-001',
            selectedSite: 'SITE-SANDTON',
            sceneReviewByIntelligenceId: fixture.sceneReviewByIntelligenceId,
            reportShellState: const ReportShellState(
              previewSurface: ReportPreviewSurface.route,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final reviewedKpi = find.byKey(const ValueKey('reports-kpi-reviewed'));
      await tester.ensureVisible(reviewedKpi);
      await tester.tap(reviewedKpi);
      await tester.pumpAndSettle();

      final previewButton = find.byKey(
        ValueKey('report-receipt-preview-$reviewedReceiptEventId'),
      );
      await tester.ensureVisible(previewButton);
      await tester.tap(previewButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Scene Review Brief'), findsOneWidget);
      expect(find.text('Receipt Integrity'), findsOneWidget);
      expect(find.textContaining(reviewedReceiptEventId), findsWidgets);
      expect(
        find.textContaining('Vehicle remained below escalation threshold.'),
        findsOneWidget,
      );

      Navigator.of(tester.element(find.text('Scene Review Brief'))).pop();
      await tester.pumpAndSettle();

      expect(find.text('Scene Review Brief'), findsNothing);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('report-receipt-preview-$reviewedReceiptEventId')),
        findsOneWidget,
      );
      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
    },
  );

  testWidgets(
    'client reports preview report generates live reviewed receipt and opens preview',
    (tester) async {
      final fixture = buildReviewedReportGenerationFixture(
        intelligenceEventId: 'INTEL-GENERATE-REVIEWED-1',
        intelligenceId: 'intel-generate-reviewed-1',
      );
      final store = fixture.store;
      final shellState = ValueNotifier(const ReportShellState());
      final previewRequests = <ReportPreviewRequest>[];
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ClientIntelligenceReportsPage(
                store: store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
                onRequestPreview: previewRequests.add,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('reports-kpi-all')),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('reports-kpi-reviewed')),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );

      final previewReportAction = find.text('Preview Report').first;
      await tester.ensureVisible(previewReportAction);
      await tester.tap(previewReportAction);
      await tester.pumpAndSettle();

      final reportEvents = store
          .allEvents()
          .whereType<ReportGenerated>()
          .toList();
      expect(reportEvents, hasLength(1));

      final generatedReceipt = reportEvents.single;
      expect(previewRequests, hasLength(1));
      expect(
        previewRequests.single.receiptEvent?.eventId,
        generatedReceipt.eventId,
      );
      expect(previewRequests.single.bundle.sceneReview.totalReviews, 1);
      expect(
        previewRequests.single.bundle.sceneReview.highlights.single.summary,
        'Vehicle remained below escalation threshold.',
      );
      expect(shellState.value.selectedReceiptEventId, generatedReceipt.eventId);
      expect(shellState.value.previewReceiptEventId, generatedReceipt.eventId);
      expect(
        find.byKey(
          ValueKey('report-receipt-preview-${generatedReceipt.eventId}'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('report-receipt-preview-RPT-2024-03-10-001')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('reports-kpi-all')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('reports-kpi-reviewed')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('reports-kpi-scene-pending')),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Preview target: ${generatedReceipt.eventId}'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'client reports preview report opens reviewed preview route without callback',
    (tester) async {
      final fixture = buildReviewedReportGenerationFixture(
        intelligenceEventId: 'INTEL-GENERATE-ROUTE-REVIEWED-1',
        intelligenceId: 'intel-generate-route-reviewed-1',
      );
      final store = fixture.store;

      await tester.pumpWidget(
        MaterialApp(
          home: ClientIntelligenceReportsPage(
            store: store,
            selectedClient: 'CLIENT-001',
            selectedSite: 'SITE-SANDTON',
            sceneReviewByIntelligenceId: fixture.sceneReviewByIntelligenceId,
            reportShellState: const ReportShellState(
              previewSurface: ReportPreviewSurface.route,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final previewReportAction = find.text('Preview Report').first;
      await tester.ensureVisible(previewReportAction);
      await tester.tap(previewReportAction);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final reportEvents = store
          .allEvents()
          .whereType<ReportGenerated>()
          .toList();
      expect(reportEvents, hasLength(1));
      expect(find.text('Scene Review Brief'), findsOneWidget);
      expect(find.text('Receipt Integrity'), findsOneWidget);
      expect(
        find.textContaining('Vehicle remained below escalation threshold.'),
        findsOneWidget,
      );
      expect(find.textContaining(reportEvents.single.eventId), findsWidgets);

      Navigator.of(tester.element(find.text('Scene Review Brief'))).pop();
      await tester.pumpAndSettle();

      expect(find.text('Scene Review Brief'), findsNothing);
      expect(
        find.text('Preview target: ${reportEvents.single.eventId}'),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey('report-receipt-preview-${reportEvents.single.eventId}'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('reports-kpi-all')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('reports-kpi-reviewed')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    },
  );
}
