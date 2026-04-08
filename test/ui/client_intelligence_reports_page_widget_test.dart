import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/morning_sovereign_report_service.dart';
import 'package:omnix_dashboard/application/report_entry_context.dart';
import 'package:omnix_dashboard/application/report_output_mode.dart';
import 'package:omnix_dashboard/application/report_partner_comparison_window.dart';
import 'package:omnix_dashboard/application/report_preview_request.dart';
import 'package:omnix_dashboard/application/report_preview_surface.dart';
import 'package:omnix_dashboard/application/report_receipt_scene_filter.dart';
import 'package:omnix_dashboard/application/report_shell_state.dart';
import 'package:omnix_dashboard/domain/events/partner_dispatch_status_declared.dart';
import 'package:omnix_dashboard/domain/events/report_generated.dart';
import 'package:omnix_dashboard/domain/store/in_memory_event_store.dart';
import 'package:omnix_dashboard/ui/client_intelligence_reports_page.dart';

import '../fixtures/report_test_receipt.dart';
import '../fixtures/report_test_bundle.dart';
import '../fixtures/report_test_intelligence.dart';
import '../fixtures/report_test_reviewed_workspace.dart';

DateTime _clientReportsGeneratedAtUtc(int day) =>
    DateTime.utc(2026, 3, day, 6, 0);

DateTime _clientReportsShiftStartedAtUtc(int day) =>
    DateTime.utc(2026, 3, day, 22, 0);

DateTime _clientReportsHistoryOccurredAtUtc(int day, {int minute = 30}) =>
    DateTime.utc(2026, 3, day, 23, minute);

DateTime _clientReportsOvernightOccurredAtUtc(int day, int minute) =>
    DateTime.utc(2026, 3, day, 1, minute);

DateTime _clientReportsScenarioOccurredAtUtc(int hour, int minute) =>
    DateTime.utc(2026, 3, 15, hour, minute);

DateTime _clientReportsPreviewOccurredAtUtc(int minute) =>
    _clientReportsScenarioOccurredAtUtc(0, minute);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('client reports renders routed hero and opens governance scope', (
    tester,
  ) async {
    Map<String, String>? openedGovernanceScope;
    Map<String, Object?>? openedEventsScope;

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: InMemoryEventStore(),
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          onOpenGovernanceForScope: (clientId, siteId) {
            openedGovernanceScope = {'clientId': clientId, 'siteId': siteId};
          },
          onOpenEventsForScope: (eventIds, selectedEventId) {
            openedEventsScope = {
              'eventIds': eventIds,
              'selectedEventId': selectedEventId,
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reports & Documentation'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reports-routed-view-governance-button')),
      findsOneWidget,
    );
    expect(find.text('Generate New Report'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('reports-routed-view-governance-button')),
    );
    await tester.pumpAndSettle();

    expect(
      openedGovernanceScope,
      equals({'clientId': 'CLIENT-001', 'siteId': 'SITE-SANDTON'}),
    );

    final viewEventsButton = find.byKey(
      const ValueKey('reports-related-events-button'),
    );
    await tester.ensureVisible(viewEventsButton);
    await tester.tap(viewEventsButton);
    await tester.pumpAndSettle();

    expect(openedEventsScope, isNotNull);
    expect(openedEventsScope!['eventIds'], <String>['RPT-2026-04-07-001']);
    expect(openedEventsScope!['selectedEventId'], 'RPT-2026-04-07-001');
  });

  testWidgets('client reports workspace shell routes command strip actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Map<String, String>? openedGovernanceScope;

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: InMemoryEventStore(),
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          onOpenGovernanceForScope: (clientId, siteId) {
            openedGovernanceScope = {'clientId': clientId, 'siteId': siteId};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('reports-workspace-panel-receipts')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reports-workspace-panel-selected')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reports-workspace-panel-context')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reports-workspace-status-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reports-workspace-focus-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reports-workspace-command-receipt')),
      findsOneWidget,
    );

    expect(
      find.byKey(const ValueKey('reports-workspace-open-governance')),
      findsNothing,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('reports-routed-view-governance-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('reports-routed-view-governance-button')),
    );
    await tester.pumpAndSettle();

    expect(
      openedGovernanceScope,
      equals({'clientId': 'CLIENT-001', 'siteId': 'SITE-SANDTON'}),
    );

    expect(
      find.byKey(const ValueKey('reports-workspace-open-active')),
      findsNothing,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('reports-selected-preview-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('reports-selected-preview-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Receipt preview will unlock once the first live report lands on this board.',
      ),
      findsWidgets,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('reports-kpi-alerts')),
    );
    await tester.tap(find.byKey(const ValueKey('reports-kpi-alerts')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('report-receipt-filter-banner-shell')),
      findsWidgets,
    );
    expect(find.text('Receipt board recovery ready.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reports-workspace-focus-open-active')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reports-workspace-focus-recover-all')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('reports-workspace-open-active')),
    );
    await tester.tap(
      find.byKey(const ValueKey('reports-workspace-open-active')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Receipt board recovery ready.'), findsNothing);
    expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);
  });

  testWidgets('client reports ingests evidence return into the command rail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? consumedAuditId;

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: InMemoryEventStore(),
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          evidenceReturnReceipt: const ReportsEvidenceReturnReceipt(
            auditId: 'DSP-AUDIT-REPORT-1',
            label: 'EVIDENCE RETURN',
            message: 'Returned to the reports workspace for DSP-2442.',
            detail:
                'The signed report handoff was verified in the ledger. Keep the delivery rail pinned and finish the report from the same workspace.',
            accent: Color(0xFF8FD1FF),
          ),
          onConsumeEvidenceReturnReceipt: (auditId) {
            consumedAuditId = auditId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('EVIDENCE RETURN'), findsOneWidget);
    expect(
      find.text('Returned to the reports workspace for DSP-2442.'),
      findsOneWidget,
    );
    expect(consumedAuditId, 'DSP-AUDIT-REPORT-1');
  });

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
    expect(clipboardText, contains('"eventId": "RPT-2026-04-07-001"'));
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
      generatedAtUtc: _clientReportsGeneratedAtUtc(14),
      shiftWindowStartUtc: _clientReportsShiftStartedAtUtc(13),
      shiftWindowEndUtc: _clientReportsGeneratedAtUtc(14),
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
      generatedAtUtc: _clientReportsGeneratedAtUtc(15),
      shiftWindowStartUtc: _clientReportsShiftStartedAtUtc(14),
      shiftWindowEndUtc: _clientReportsGeneratedAtUtc(15),
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
            latestOccurredAtUtc: _clientReportsOvernightOccurredAtUtc(15, 18),
            dispatchCreatedAtUtc: _clientReportsOvernightOccurredAtUtc(15, 0),
            acceptedAtUtc: _clientReportsOvernightOccurredAtUtc(15, 4),
            onSiteAtUtc: _clientReportsOvernightOccurredAtUtc(15, 10),
            allClearAtUtc: _clientReportsOvernightOccurredAtUtc(15, 18),
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
        occurredAt: _clientReportsOvernightOccurredAtUtc(15, 4),
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
        occurredAt: _clientReportsOvernightOccurredAtUtc(15, 10),
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
        occurredAt: _clientReportsOvernightOccurredAtUtc(15, 18),
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
    store.append(
      ReportGenerated(
        eventId: 'PARTNER-RPT-1',
        sequence: 4,
        version: 1,
        occurredAt: _clientReportsHistoryOccurredAtUtc(13),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        month: '2026-03',
        contentHash: 'partner-content-hash-1',
        pdfHash: 'partner-pdf-hash-1',
        eventRangeStart: 1,
        eventRangeEnd: 20,
        eventCount: 20,
        reportSchemaVersion: 3,
        projectionVersion: 1,
      ),
    );
    store.append(
      ReportGenerated(
        eventId: 'PARTNER-RPT-2',
        sequence: 5,
        version: 1,
        occurredAt: _clientReportsHistoryOccurredAtUtc(14),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        month: '2026-03',
        contentHash: 'partner-content-hash-2',
        pdfHash: 'partner-pdf-hash-2',
        eventRangeStart: 21,
        eventRangeEnd: 40,
        eventCount: 20,
        reportSchemaVersion: 3,
        projectionVersion: 1,
      ),
    );
    store.append(
      ReportGenerated(
        eventId: 'PARTNER-RPT-3',
        sequence: 6,
        version: 1,
        occurredAt: _clientReportsHistoryOccurredAtUtc(15),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        month: '2026-03',
        contentHash: 'partner-content-hash-3',
        pdfHash: 'partner-pdf-hash-3',
        eventRangeStart: 41,
        eventRangeEnd: 64,
        eventCount: 24,
        reportSchemaVersion: 3,
        projectionVersion: 1,
        investigationContextKey: 'governance_branding_drift',
      ),
    );
    store.append(
      buildTestIntelligenceReceived(
        eventId: 'ACTIVITY-1',
        sequence: 7,
        occurredAt: _clientReportsScenarioOccurredAtUtc(0, 20),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        intelligenceId: 'activity-1',
        headline: 'Authorized vehicle detected',
        summary: 'Partner patrol vehicle entered the site.',
        objectLabel: 'vehicle',
        plateNumber: 'ABC123GP',
      ),
    );
    store.append(
      buildTestIntelligenceReceived(
        eventId: 'ACTIVITY-2',
        sequence: 8,
        occurredAt: _clientReportsScenarioOccurredAtUtc(0, 40),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        intelligenceId: 'activity-2',
        headline: 'Known person detected',
        summary: 'Known family member approached the gate.',
        objectLabel: 'person',
        faceMatchId: 'PERSON-001',
      ),
    );
    store.append(
      buildTestIntelligenceReceived(
        eventId: 'ACTIVITY-3',
        sequence: 9,
        occurredAt: _clientReportsScenarioOccurredAtUtc(2, 10),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        intelligenceId: 'activity-3',
        headline: 'Unknown person interaction',
        summary:
            'Unauthorized person seen in guard conversation near the service gate.',
        objectLabel: 'person',
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
    expect(find.text('Client-facing branding'), findsOneWidget);
    expect(
      find.text('CLIENT-001/SITE-SANDTON • PARTNER • Alpha'),
      findsOneWidget,
    );
    expect(find.text('Powered by ONYX'), findsOneWidget);
    expect(find.text('IMPROVING'), findsOneWidget);
    expect(find.text('Receipt OVERSIGHT RISING'), findsWidgets);
    expect(find.text('Site Activity'), findsWidgets);
    expect(find.text('Current Governance: 1'), findsWidgets);
    expect(find.text('Current Routine: 0'), findsWidgets);
    expect(find.text('Baseline Governance: 0.0'), findsWidgets);
    expect(find.text('Baseline Routine: 1.0'), findsWidgets);
    expect(
      find.text('Receipt OVERSIGHT HANDOFF • Governance 1 • Routine 0'),
      findsWidgets,
    );
    expect(
      find.text('Receipt ROUTINE REVIEW • Governance 0 • Routine 1'),
      findsWidgets,
    );
    expect(
      find.text(
        'Signals 3 • Vehicles 1 • People 2 • Known IDs 2 • Unknown 1 • Guard interactions 1 • Flagged IDs 1',
      ),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('reports-partner-scorecard-open-activity')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reports-partner-scope-chain-DSP-9001')),
      findsWidgets,
    );
    expect(
      find.text('ACCEPT -> ON SITE -> ALL CLEAR (LATEST ALL CLEAR)'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reports-partner-chain-open-events-DSP-9001')),
      findsOneWidget,
    );

    final openActivityTruthButton = find.byKey(
      const ValueKey('reports-partner-scorecard-open-activity'),
    );
    await tester.ensureVisible(openActivityTruthButton);
    await tester.tap(openActivityTruthButton);
    await tester.pumpAndSettle();

    expect(find.text('Visitor / Activity Truth'), findsOneWidget);
    expect(find.text('Activity truth by shift'), findsOneWidget);
    expect(find.text('CURRENT TRUTH'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey(
          'reports-site-activity-history-CLIENT-001/SITE-SANDTON/2026-03-15',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('reports-site-activity-open-events-2026-03-15'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('reports-site-activity-truth-copy-json')),
    );
    await tester.pumpAndSettle();

    expect(clipboardText, contains('"currentTruth"'));
    expect(clipboardText, contains('"siteId": "SITE-SANDTON"'));
    expect(clipboardText, contains('"reviewShortcuts"'));
    expect(
      clipboardText,
      contains(
        '"currentShiftReviewCommand": "/activityreview CLIENT-001 SITE-SANDTON 2026-03-15"',
      ),
    );
    expect(
      clipboardText,
      contains(
        '"currentShiftCaseFileCommand": "/activitycase json CLIENT-001 SITE-SANDTON 2026-03-15"',
      ),
    );
    expect(clipboardText, contains('"totalSignals": 3'));
    expect(clipboardText, contains('"eventIds": ['));
    expect(clipboardText, contains('"ACTIVITY-3"'));
    expect(
      clipboardText,
      contains(
        '"reviewCommand": "/activityreview CLIENT-001 SITE-SANDTON 2026-03-15"',
      ),
    );
    expect(
      clipboardText,
      contains(
        '"caseFileCommand": "/activitycase json CLIENT-001 SITE-SANDTON 2026-03-15"',
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('reports-site-activity-truth-copy-csv')),
    );
    await tester.pumpAndSettle();

    expect(clipboardText, contains('current_total_signals,3'));
    expect(
      clipboardText,
      contains(
        'current_review_command,/activityreview CLIENT-001 SITE-SANDTON 2026-03-15',
      ),
    );
    expect(
      clipboardText,
      contains(
        'current_case_file_command,/activitycase json CLIENT-001 SITE-SANDTON 2026-03-15',
      ),
    );
    expect(clipboardText, contains('current_guard_interactions,1'));
    expect(
      clipboardText,
      contains(
        'history_1,"2026-03-15 • CURRENT • Signals 3 • Vehicles 1 • People 2 • Known IDs 2 • Unknown 1 • Guard interactions 1 • Flagged IDs 1"',
      ),
    );
    expect(clipboardText, contains('history_1_event_3,ACTIVITY-3'));
    expect(
      clipboardText,
      contains(
        'history_1_review_command,/activityreview CLIENT-001 SITE-SANDTON 2026-03-15',
      ),
    );
    expect(
      clipboardText,
      contains(
        'history_1_case_file_command,/activitycase json CLIENT-001 SITE-SANDTON 2026-03-15',
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey('reports-site-activity-open-events-2026-03-15'),
      ),
    );
    await tester.pumpAndSettle();

    expect(openedEventsScope, isNotNull);
    expect(openedEventsScope!['eventIds'], <String>[
      'ACTIVITY-1',
      'ACTIVITY-2',
      'ACTIVITY-3',
    ]);
    expect(openedEventsScope!['selectedEventId'], 'ACTIVITY-3');

    await tester.tap(
      find.byKey(const ValueKey('reports-site-activity-truth-close')),
    );
    await tester.pumpAndSettle();

    final openDrillInButton = find.byKey(
      const ValueKey('reports-partner-scorecard-open-drill-in'),
    );
    await tester.ensureVisible(openDrillInButton);
    await tester.tap(openDrillInButton);
    await tester.pumpAndSettle();

    expect(find.text('Partner Scorecard Drill-In'), findsOneWidget);
    expect(find.text('Receipt provenance by shift'), findsOneWidget);
    expect(find.text('Scorecard history'), findsWidgets);
    expect(find.text('Dispatch chains'), findsOneWidget);
    expect(
      find.text('Receipt OVERSIGHT HANDOFF • Governance 1 • Routine 0'),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('reports-partner-scorecard-drill-in-close')),
      findsOneWidget,
    );

    final openShiftButton = find.byKey(
      const ValueKey('reports-partner-scope-history-open-2026-03-15'),
    );
    await tester.ensureVisible(openShiftButton);
    await tester.tap(openShiftButton);
    await tester.pumpAndSettle();

    expect(find.text('Partner Shift Detail'), findsOneWidget);
    expect(
      find.text('2026-03-15 • CLIENT-001/SITE-SANDTON • PARTNER • Alpha'),
      findsOneWidget,
    );
    expect(find.text('Shift receipts'), findsOneWidget);
    expect(find.text('Shift dispatch chains'), findsOneWidget);
    expect(find.text('CURRENT SHIFT'), findsOneWidget);
    expect(
      find.text('Receipt OVERSIGHT HANDOFF • Governance 1 • Routine 0'),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('reports-partner-scope-chain-DSP-9001')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('reports-partner-shift-detail-close')),
      findsOneWidget,
    );

    final copyShiftJsonButton = find.byKey(
      const ValueKey('reports-partner-shift-copy-json-2026-03-15'),
    );
    await tester.ensureVisible(copyShiftJsonButton);
    await tester.tap(copyShiftJsonButton);
    await tester.pumpAndSettle();

    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('"reportDate": "2026-03-15"'));
    expect(clipboardText, contains('"primaryLabel": "STRONG"'));
    expect(clipboardText, contains('"siteActivity": {'));
    expect(clipboardText, contains('"totalSignals": 3'));
    expect(clipboardText, contains('"guardInteractionSignals": 1'));
    expect(clipboardText, contains('"eventIds": ['));
    expect(clipboardText, contains('"PARTNER-EVT-1"'));
    expect(clipboardText, contains('"PARTNER-RPT-3"'));

    final copyShiftCsvButton = find.byKey(
      const ValueKey('reports-partner-shift-copy-csv-2026-03-15'),
    );
    await tester.ensureVisible(copyShiftCsvButton);
    await tester.tap(copyShiftCsvButton);
    await tester.pumpAndSettle();

    expect(clipboardText, contains('report_date,2026-03-15'));
    expect(clipboardText, contains('primary_label,STRONG'));
    expect(clipboardText, contains('site_activity_total_signals,3'));
    expect(clipboardText, contains('site_activity_guard_interactions,1'));
    expect(
      clipboardText,
      contains(
        'receipt_investigation_summary,"Receipt OVERSIGHT HANDOFF • Governance 1 • Routine 0"',
      ),
    );
    expect(clipboardText, contains('dispatch_chain_1,"DSP-9001'));
    expect(clipboardText, contains('event_id_4,PARTNER-RPT-3'));

    final openShiftEventsButton = find.byKey(
      const ValueKey('reports-partner-shift-open-events-2026-03-15'),
    );
    await tester.ensureVisible(openShiftEventsButton);
    await tester.tap(openShiftEventsButton);
    await tester.pumpAndSettle();

    expect(find.text('Partner Shift Detail'), findsNothing);
    expect(openedEventsScope, isNotNull);
    expect(openedEventsScope!['eventIds'], <String>[
      'PARTNER-EVT-1',
      'PARTNER-EVT-2',
      'PARTNER-EVT-3',
      'PARTNER-RPT-3',
    ]);
    expect(openedEventsScope!['selectedEventId'], 'PARTNER-RPT-3');

    await tester.tap(openShiftButton);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('reports-partner-shift-detail-close')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('reports-partner-scorecard-drill-in-close')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partner Scorecard Drill-In'), findsNothing);

    final copyJsonButton = find.byKey(
      const ValueKey('reports-partner-scorecard-copy-json'),
    );
    await tester.ensureVisible(copyJsonButton);
    await tester.tap(copyJsonButton);
    await tester.pumpAndSettle();

    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('"partnerLabel": "PARTNER • Alpha"'));
    expect(clipboardText, contains('"trendLabel": "IMPROVING"'));
    expect(clipboardText, contains('"siteActivity": {'));
    expect(clipboardText, contains('"totalSignals": 3'));
    expect(clipboardText, contains('"receiptInvestigation": {'));
    expect(clipboardText, contains('"trendLabel": "OVERSIGHT RISING"'));
    expect(clipboardText, contains('"currentGovernanceHandoffCount": 1'));
    expect(clipboardText, contains('"currentRoutineReviewCount": 0'));
    expect(clipboardText, contains('"baselineGovernanceAverage": 0.0'));
    expect(clipboardText, contains('"baselineRoutineAverage": 1.0'));
    expect(clipboardText, contains('"baselineReceiptCount": 2'));
    expect(clipboardText, contains('"historyRows": ['));
    expect(clipboardText, contains('"modeLabel": "OVERSIGHT HANDOFF"'));
    expect(clipboardText, contains('"modeLabel": "ROUTINE REVIEW"'));
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
    expect(clipboardText, contains('site_activity_total_signals,3'));
    expect(
      clipboardText,
      contains(
        'site_activity_summary,"Signals 3 • Vehicles 1 • People 2 • Known IDs 2 • Unknown 1 • Guard interactions 1 • Flagged IDs 1"',
      ),
    );
    expect(
      clipboardText,
      contains('receipt_investigation_trend_label,"OVERSIGHT RISING"'),
    );
    expect(
      clipboardText,
      contains('receipt_investigation_current_governance_handoff_count,1'),
    );
    expect(
      clipboardText,
      contains('receipt_investigation_current_routine_review_count,0'),
    );
    expect(
      clipboardText,
      contains('receipt_investigation_baseline_governance_average,0.0'),
    );
    expect(
      clipboardText,
      contains('receipt_investigation_baseline_routine_average,1.0'),
    );
    expect(
      clipboardText,
      contains('receipt_investigation_baseline_receipt_count,2'),
    );
    expect(
      clipboardText,
      contains(
        'history_row_1,"2026-03-15 • CURRENT • CLIENT-001/SITE-SANDTON • PARTNER • Alpha',
      ),
    );
    expect(
      clipboardText,
      contains('Receipt OVERSIGHT HANDOFF • Governance 1 • Routine 0'),
    );
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
    final openEventsAction = tester.widget<TextButton>(openEventsButton);
    expect(openEventsAction.onPressed, isNotNull);
    openEventsAction.onPressed!.call();
    await tester.pumpAndSettle();

    expect(openedEventsScope, <String, Object?>{
      'eventIds': [
        'PARTNER-EVT-1',
        'PARTNER-EVT-2',
        'PARTNER-EVT-3',
        'PARTNER-RPT-3',
      ],
      'selectedEventId': 'PARTNER-RPT-3',
    });
  });

  testWidgets(
    'client reports partner shift empty chains exposes recovery actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fixture = buildReviewedReportWorkspaceFixture();
      final currentReport = SovereignReport(
        date: '2026-03-15',
        generatedAtUtc: _clientReportsGeneratedAtUtc(15),
        shiftWindowStartUtc: _clientReportsShiftStartedAtUtc(14),
        shiftWindowEndUtc: _clientReportsGeneratedAtUtc(15),
        ledgerIntegrity: const SovereignReportLedgerIntegrity(
          totalEvents: 2,
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
          dispatchCount: 0,
          declarationCount: 0,
          acceptedCount: 0,
          onSiteCount: 0,
          allClearCount: 0,
          cancelledCount: 0,
          summaryLine: '',
          scoreboardRows: [
            SovereignReportPartnerScoreboardRow(
              clientId: 'CLIENT-001',
              siteId: 'SITE-SANDTON',
              partnerLabel: 'PARTNER • Alpha',
              dispatchCount: 0,
              strongCount: 0,
              onTrackCount: 1,
              watchCount: 0,
              criticalCount: 0,
              averageAcceptedDelayMinutes: 0,
              averageOnSiteDelayMinutes: 0,
              summaryLine:
                  'Dispatches 0 • Strong 0 • On track 1 • Watch 0 • Critical 0 • Avg accept 0.0m • Avg on site 0.0m',
            ),
          ],
        ),
      );

      Map<String, String>? openedGovernanceScope;
      Map<String, Object?>? openedEventsScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ClientIntelligenceReportsPage(
            store: fixture.store,
            selectedClient: 'CLIENT-001',
            selectedSite: 'SITE-SANDTON',
            morningSovereignReportHistory: [currentReport],
            initialPartnerScopeClientId: 'CLIENT-001',
            initialPartnerScopeSiteId: 'SITE-SANDTON',
            initialPartnerScopePartnerLabel: 'PARTNER • Alpha',
            sceneReviewByIntelligenceId: fixture.sceneReviewByIntelligenceId,
            onOpenGovernanceForPartnerScope: (clientId, siteId, partnerLabel) {
              openedGovernanceScope = {
                'clientId': clientId,
                'siteId': siteId,
                'partnerLabel': partnerLabel,
              };
            },
            onOpenEventsForScope: (eventIds, selectedEventId) {
              openedEventsScope = {
                'eventIds': eventIds,
                'selectedEventId': selectedEventId,
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final openDrillInButton = find.byKey(
        const ValueKey('reports-partner-scorecard-open-drill-in'),
      );
      await tester.ensureVisible(openDrillInButton);
      final openDrillInAction = tester.widget<TextButton>(openDrillInButton);
      expect(openDrillInAction.onPressed, isNotNull);
      openDrillInAction.onPressed!.call();
      await tester.pumpAndSettle();

      final openShiftButton = find.byKey(
        const ValueKey('reports-partner-scope-history-open-2026-03-15'),
      );
      await tester.ensureVisible(openShiftButton.last);
      await tester.tap(openShiftButton.last);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey(
            'reports-partner-shift-empty-chains-recovery-2026-03-15',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'No partner dispatch chains formed during this shift window.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey(
            'reports-partner-shift-empty-chains-open-receipts-2026-03-15',
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey(
            'reports-partner-shift-empty-chains-open-governance-2026-03-15',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Partner Shift Detail'), findsNothing);
      expect(
        openedGovernanceScope,
        equals({
          'clientId': 'CLIENT-001',
          'siteId': 'SITE-SANDTON',
          'partnerLabel': 'PARTNER • Alpha',
        }),
      );
      expect(
        find.textContaining(
          'Opening Governance for 2026-03-15 • PARTNER • Alpha.',
        ),
        findsWidgets,
      );

      openDrillInAction.onPressed!.call();
      await tester.pumpAndSettle();
      await tester.tap(openShiftButton.last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey(
            'reports-partner-shift-empty-chains-open-events-2026-03-15',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Partner Shift Detail'), findsNothing);
      expect(openedEventsScope, isNotNull);
      expect(openedEventsScope!['eventIds'], <String>[
        fixture.pendingReceiptEventId,
        fixture.reviewedReceiptEventId,
      ]);
      expect(
        openedEventsScope!['selectedEventId'],
        fixture.reviewedReceiptEventId,
      );
    },
  );

  testWidgets(
    'client reports partner shift empty receipts exposes recovery actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fixture = buildReviewedReportWorkspaceFixture();
      fixture.store.append(
        PartnerDispatchStatusDeclared(
          eventId: 'PARTNER-EMPTY-RPT-EVT-1',
          sequence: 20,
          version: 1,
          occurredAt: _clientReportsOvernightOccurredAtUtc(16, 5),
          dispatchId: 'DSP-EMPTY-RPT-1',
          clientId: 'CLIENT-001',
          regionId: 'REGION-1',
          siteId: 'SITE-SANDTON',
          partnerLabel: 'PARTNER • Alpha',
          actorLabel: 'Partner Controller',
          status: PartnerDispatchStatus.accepted,
          sourceChannel: 'telegram',
          sourceMessageKey: 'SHIFT-EMPTY-RPT-1',
        ),
      );
      fixture.store.append(
        PartnerDispatchStatusDeclared(
          eventId: 'PARTNER-EMPTY-RPT-EVT-2',
          sequence: 21,
          version: 1,
          occurredAt: _clientReportsOvernightOccurredAtUtc(16, 18),
          dispatchId: 'DSP-EMPTY-RPT-1',
          clientId: 'CLIENT-001',
          regionId: 'REGION-1',
          siteId: 'SITE-SANDTON',
          partnerLabel: 'PARTNER • Alpha',
          actorLabel: 'Partner Controller',
          status: PartnerDispatchStatus.onSite,
          sourceChannel: 'telegram',
          sourceMessageKey: 'SHIFT-EMPTY-RPT-2',
        ),
      );

      final currentReport = SovereignReport(
        date: '2026-03-16',
        generatedAtUtc: _clientReportsGeneratedAtUtc(16),
        shiftWindowStartUtc: _clientReportsShiftStartedAtUtc(15),
        shiftWindowEndUtc: _clientReportsGeneratedAtUtc(16),
        ledgerIntegrity: const SovereignReportLedgerIntegrity(
          totalEvents: 2,
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
          declarationCount: 2,
          acceptedCount: 1,
          onSiteCount: 1,
          allClearCount: 0,
          cancelledCount: 0,
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
              averageAcceptedDelayMinutes: 5.0,
              averageOnSiteDelayMinutes: 18.0,
              summaryLine:
                  'Dispatches 1 • Strong 0 • On track 1 • Watch 0 • Critical 0 • Avg accept 5.0m • Avg on site 18.0m',
            ),
          ],
          dispatchChains: [
            SovereignReportPartnerDispatchChain(
              dispatchId: 'DSP-EMPTY-RPT-1',
              clientId: 'CLIENT-001',
              siteId: 'SITE-SANDTON',
              partnerLabel: 'PARTNER • Alpha',
              declarationCount: 2,
              latestStatus: PartnerDispatchStatus.onSite,
              latestOccurredAtUtc: _clientReportsOvernightOccurredAtUtc(16, 18),
              dispatchCreatedAtUtc: _clientReportsOvernightOccurredAtUtc(16, 0),
              acceptedAtUtc: _clientReportsOvernightOccurredAtUtc(16, 5),
              onSiteAtUtc: _clientReportsOvernightOccurredAtUtc(16, 18),
              acceptedDelayMinutes: 5.0,
              onSiteDelayMinutes: 18.0,
              scoreLabel: 'ON TRACK',
              scoreReason:
                  'Partner accepted quickly and reached site inside the current shift window.',
              workflowSummary: 'ACCEPT -> ON SITE (LATEST ON SITE)',
            ),
          ],
        ),
      );

      Map<String, String>? openedGovernanceScope;
      Map<String, Object?>? openedEventsScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ClientIntelligenceReportsPage(
            store: fixture.store,
            selectedClient: 'CLIENT-001',
            selectedSite: 'SITE-SANDTON',
            morningSovereignReportHistory: [currentReport],
            initialPartnerScopeClientId: 'CLIENT-001',
            initialPartnerScopeSiteId: 'SITE-SANDTON',
            initialPartnerScopePartnerLabel: 'PARTNER • Alpha',
            sceneReviewByIntelligenceId: fixture.sceneReviewByIntelligenceId,
            onOpenGovernanceForPartnerScope: (clientId, siteId, partnerLabel) {
              openedGovernanceScope = {
                'clientId': clientId,
                'siteId': siteId,
                'partnerLabel': partnerLabel,
              };
            },
            onOpenEventsForScope: (eventIds, selectedEventId) {
              openedEventsScope = {
                'eventIds': eventIds,
                'selectedEventId': selectedEventId,
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final openDrillInButton = find.byKey(
        const ValueKey('reports-partner-scorecard-open-drill-in'),
      );
      await tester.ensureVisible(openDrillInButton);
      final openDrillInAction = tester.widget<TextButton>(openDrillInButton);
      expect(openDrillInAction.onPressed, isNotNull);
      openDrillInAction.onPressed!.call();
      await tester.pumpAndSettle();

      final openShiftButton = find.byKey(
        const ValueKey('reports-partner-scope-history-open-2026-03-16'),
      );
      await tester.ensureVisible(openShiftButton.last);
      await tester.tap(openShiftButton.last);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey(
            'reports-partner-shift-empty-receipts-recovery-2026-03-16',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text('No generated receipts landed in this shift window.'),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey(
            'reports-partner-shift-empty-receipts-open-lane-2026-03-16',
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey(
            'reports-partner-shift-empty-receipts-open-governance-2026-03-16',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Partner Shift Detail'), findsNothing);
      expect(
        openedGovernanceScope,
        equals({
          'clientId': 'CLIENT-001',
          'siteId': 'SITE-SANDTON',
          'partnerLabel': 'PARTNER • Alpha',
        }),
      );

      openDrillInAction.onPressed!.call();
      await tester.pumpAndSettle();
      await tester.tap(openShiftButton.last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey(
            'reports-partner-shift-empty-receipts-open-lane-2026-03-16',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Partner Shift Detail'), findsNothing);
      expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);
      expect(
        find.textContaining(
          'Focused shift receipt board for 2026-03-16 • PARTNER • Alpha.',
        ),
        findsWidgets,
      );

      openDrillInAction.onPressed!.call();
      await tester.pumpAndSettle();
      await tester.tap(openShiftButton.last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey(
            'reports-partner-shift-empty-receipts-open-events-2026-03-16',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Partner Shift Detail'), findsNothing);
      expect(openedEventsScope, isNotNull);
      expect(openedEventsScope!['eventIds'], <String>[
        'PARTNER-EMPTY-RPT-EVT-1',
        'PARTNER-EMPTY-RPT-EVT-2',
      ]);
      expect(openedEventsScope!['selectedEventId'], 'PARTNER-EMPTY-RPT-EVT-2');
    },
  );

  testWidgets('client reports quiet activity truth exposes recovery actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-QUIET-1',
        occurredAt: _clientReportsScenarioOccurredAtUtc(0, 45),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 2,
        projectionVersion: 2,
        eventRangeStart: 1,
        eventRangeEnd: 3,
        eventCount: 3,
      ),
    );

    final currentReport = SovereignReport(
      date: '2026-03-15',
      generatedAtUtc: _clientReportsGeneratedAtUtc(15),
      shiftWindowStartUtc: _clientReportsShiftStartedAtUtc(14),
      shiftWindowEndUtc: _clientReportsGeneratedAtUtc(15),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 1,
        hashVerified: true,
        integrityScore: 99,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 0,
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
        dispatchCount: 0,
        declarationCount: 0,
        acceptedCount: 0,
        onSiteCount: 0,
        allClearCount: 0,
        cancelledCount: 0,
        summaryLine: '',
        scoreboardRows: [
          SovereignReportPartnerScoreboardRow(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            partnerLabel: 'PARTNER • Alpha',
            dispatchCount: 0,
            strongCount: 0,
            onTrackCount: 1,
            watchCount: 0,
            criticalCount: 0,
            averageAcceptedDelayMinutes: 0,
            averageOnSiteDelayMinutes: 0,
            summaryLine:
                'Dispatches 0 • Strong 0 • On track 1 • Watch 0 • Critical 0 • Avg accept 0.0m • Avg on site 0.0m',
          ),
        ],
      ),
    );

    Map<String, String>? openedGovernanceScope;

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          morningSovereignReportHistory: [currentReport],
          initialPartnerScopeClientId: 'CLIENT-001',
          initialPartnerScopeSiteId: 'SITE-SANDTON',
          initialPartnerScopePartnerLabel: 'PARTNER • Alpha',
          onOpenGovernanceForPartnerScope: (clientId, siteId, partnerLabel) {
            openedGovernanceScope = {
              'clientId': clientId,
              'siteId': siteId,
              'partnerLabel': partnerLabel,
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final openActivityTruthButton = find.byKey(
      const ValueKey('reports-partner-scorecard-open-activity'),
    );
    await tester.ensureVisible(openActivityTruthButton);
    await tester.tap(openActivityTruthButton);
    await tester.pumpAndSettle();

    expect(find.text('Visitor / Activity Truth'), findsOneWidget);
    expect(find.text('This scope is quiet so far.'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey(
          'reports-site-activity-quiet-recovery-CLIENT-001/SITE-SANDTON/PARTNER • Alpha',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        const ValueKey(
          'reports-site-activity-quiet-open-receipts-CLIENT-001/SITE-SANDTON/PARTNER • Alpha',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Visitor / Activity Truth'), findsNothing);
    expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);
    expect(
      find.textContaining(
        'Focused quiet activity scope on receipt board RPT-QUIET-1.',
      ),
      findsWidgets,
    );

    await tester.tap(openActivityTruthButton);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey(
          'reports-site-activity-quiet-open-governance-CLIENT-001/SITE-SANDTON/PARTNER • Alpha',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Visitor / Activity Truth'), findsNothing);
    expect(
      openedGovernanceScope,
      equals({
        'clientId': 'CLIENT-001',
        'siteId': 'SITE-SANDTON',
        'partnerLabel': 'PARTNER • Alpha',
      }),
    );
  });

  testWidgets(
    'client reports pending partner scorecard recovers through receipts and governance',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = InMemoryEventStore();
      store.append(
        buildTestReportGenerated(
          eventId: 'RPT-PENDING-1',
          occurredAt: _clientReportsOvernightOccurredAtUtc(15, 15),
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          reportSchemaVersion: 2,
          projectionVersion: 2,
          eventRangeStart: 1,
          eventRangeEnd: 3,
          eventCount: 3,
        ),
      );

      Map<String, String>? openedGovernanceScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ClientIntelligenceReportsPage(
            store: store,
            selectedClient: 'CLIENT-001',
            selectedSite: 'SITE-SANDTON',
            morningSovereignReportHistory: const <SovereignReport>[],
            initialPartnerScopeClientId: 'CLIENT-001',
            initialPartnerScopeSiteId: 'SITE-SANDTON',
            initialPartnerScopePartnerLabel: 'PARTNER • Alpha',
            onOpenGovernanceForScope: (clientId, siteId) {
              openedGovernanceScope = {'clientId': clientId, 'siteId': siteId};
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('reports-partner-scope-banner')),
        findsOneWidget,
      );
      expect(
        find.text('Morning partner scorecard sync pending for this scope.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('reports-partner-scope-recovery-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('reports-partner-scope-recovery-open-receipts'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('reports-partner-scope-recovery-open-activity'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('reports-partner-scope-recovery-open-governance'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('reports-partner-scorecard-open-governance')),
        findsOneWidget,
      );

      final recoverReceiptsButton = find.byKey(
        const ValueKey('reports-partner-scope-recovery-open-receipts'),
      );
      await tester.ensureVisible(recoverReceiptsButton);
      await tester.tap(recoverReceiptsButton);
      await tester.pumpAndSettle();

      expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);
      expect(
        find.textContaining(
          'Recovered pending partner scorecard scope around RPT-PENDING-1.',
        ),
        findsWidgets,
      );

      final openGovernanceButton = find.byKey(
        const ValueKey('reports-partner-scorecard-open-governance'),
      );
      await tester.ensureVisible(openGovernanceButton);
      await tester.tap(openGovernanceButton);
      await tester.pumpAndSettle();

      expect(
        openedGovernanceScope,
        equals({'clientId': 'CLIENT-001', 'siteId': 'SITE-SANDTON'}),
      );
    },
  );

  testWidgets('client reports empty partner drill-in exposes recovery pivots', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-DRILL-EMPTY-1',
        occurredAt: _clientReportsScenarioOccurredAtUtc(2, 0),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 2,
        projectionVersion: 2,
        eventRangeStart: 1,
        eventRangeEnd: 3,
        eventCount: 3,
      ),
    );

    Map<String, String>? openedGovernanceScope;

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          morningSovereignReportHistory: const <SovereignReport>[],
          initialPartnerScopeClientId: 'CLIENT-001',
          initialPartnerScopeSiteId: 'SITE-SANDTON',
          initialPartnerScopePartnerLabel: 'PARTNER • Alpha',
          onOpenGovernanceForScope: (clientId, siteId) {
            openedGovernanceScope = {'clientId': clientId, 'siteId': siteId};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final openDrillInButton = find.byKey(
      const ValueKey('reports-partner-scorecard-open-drill-in'),
    );
    await tester.ensureVisible(openDrillInButton);
    await tester.tap(openDrillInButton);
    await tester.pumpAndSettle();

    expect(find.text('Partner Scorecard Drill-In'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reports-partner-drill-in-recovery-card')),
      findsOneWidget,
    );
    expect(
      find.text('No scorecard history has landed for this partner scope yet.'),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('reports-partner-drill-in-recovery-open-activity'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('reports-partner-drill-in-recovery-open-governance'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        const ValueKey('reports-partner-drill-in-recovery-open-activity'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partner Scorecard Drill-In'), findsNothing);
    expect(find.text('Visitor / Activity Truth'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey(
          'reports-site-activity-quiet-recovery-CLIENT-001/SITE-SANDTON/PARTNER • Alpha',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('reports-site-activity-truth-close')),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(openDrillInButton);
    await tester.tap(openDrillInButton);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey('reports-partner-drill-in-recovery-open-governance'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partner Scorecard Drill-In'), findsNothing);
    expect(
      openedGovernanceScope,
      equals({'clientId': 'CLIENT-001', 'siteId': 'SITE-SANDTON'}),
    );
  });

  testWidgets('client reports thin comparison lane exposes recovery pivots', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-CMP-RECOVERY-1',
        occurredAt: _clientReportsScenarioOccurredAtUtc(2, 20),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 2,
        projectionVersion: 2,
        eventRangeStart: 1,
        eventRangeEnd: 3,
        eventCount: 3,
      ),
    );

    final currentReport = SovereignReport(
      date: '2026-03-15',
      generatedAtUtc: _clientReportsGeneratedAtUtc(15),
      shiftWindowStartUtc: _clientReportsShiftStartedAtUtc(14),
      shiftWindowEndUtc: _clientReportsGeneratedAtUtc(15),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 1,
        hashVerified: true,
        integrityScore: 99,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 0,
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
        declarationCount: 0,
        acceptedCount: 0,
        onSiteCount: 0,
        allClearCount: 0,
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
            averageAcceptedDelayMinutes: 4,
            averageOnSiteDelayMinutes: 9,
            summaryLine:
                'Dispatches 1 • Strong 1 • On track 0 • Watch 0 • Critical 0 • Avg accept 4.0m • Avg on site 9.0m',
          ),
        ],
      ),
    );

    Map<String, String>? openedGovernanceScope;

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          morningSovereignReportHistory: [currentReport],
          onOpenGovernanceForScope: (clientId, siteId) {
            openedGovernanceScope = {'clientId': clientId, 'siteId': siteId};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey(
          'reports-partner-comparison-recovery-CLIENT-001/SITE-SANDTON/PARTNER • Alpha',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('BASELINE FORMING'), findsOneWidget);

    final openActivityButton = find.byKey(
      const ValueKey(
        'reports-partner-comparison-recovery-open-activity-CLIENT-001/SITE-SANDTON/PARTNER • Alpha',
      ),
    );
    await tester.ensureVisible(openActivityButton);
    await tester.tap(openActivityButton);
    await tester.pumpAndSettle();

    expect(find.text('Visitor / Activity Truth'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey(
          'reports-site-activity-quiet-recovery-CLIENT-001/SITE-SANDTON/PARTNER • Alpha',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('reports-site-activity-truth-close')),
    );
    await tester.pumpAndSettle();

    final openGovernanceButton = find.byKey(
      const ValueKey(
        'reports-partner-comparison-recovery-open-governance-CLIENT-001/SITE-SANDTON/PARTNER • Alpha',
      ),
    );
    await tester.ensureVisible(openGovernanceButton);
    await tester.tap(openGovernanceButton);
    await tester.pumpAndSettle();

    expect(
      openedGovernanceScope,
      equals({'clientId': 'CLIENT-001', 'siteId': 'SITE-SANDTON'}),
    );
  });

  testWidgets('client reports comparison shell exposes command banner pivots', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-CMP-SHELL-1',
        occurredAt: _clientReportsScenarioOccurredAtUtc(3, 10),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 2,
        projectionVersion: 2,
        eventRangeStart: 1,
        eventRangeEnd: 3,
        eventCount: 3,
      ),
    );

    final currentReport = SovereignReport(
      date: '2026-03-15',
      generatedAtUtc: _clientReportsGeneratedAtUtc(15),
      shiftWindowStartUtc: _clientReportsShiftStartedAtUtc(14),
      shiftWindowEndUtc: _clientReportsGeneratedAtUtc(15),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 1,
        hashVerified: true,
        integrityScore: 99,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 0,
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
        declarationCount: 0,
        acceptedCount: 0,
        onSiteCount: 0,
        allClearCount: 0,
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
            averageAcceptedDelayMinutes: 4,
            averageOnSiteDelayMinutes: 9,
            summaryLine:
                'Dispatches 1 • Strong 1 • On track 0 • Watch 0 • Critical 0 • Avg accept 4.0m • Avg on site 9.0m',
          ),
        ],
      ),
    );

    Map<String, String>? openedGovernanceScope;

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          morningSovereignReportHistory: [currentReport],
          onOpenGovernanceForScope: (clientId, siteId) {
            openedGovernanceScope = {'clientId': clientId, 'siteId': siteId};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('reports-partner-comparison-command-banner')),
      findsOneWidget,
    );
    expect(find.text('COMPARISON COMMAND'), findsOneWidget);

    final openReceiptsButton = find.byKey(
      const ValueKey('reports-partner-comparison-command-open-receipts'),
    );
    await tester.ensureVisible(openReceiptsButton);
    await tester.tap(openReceiptsButton);
    await tester.pumpAndSettle();

    expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);
    expect(
      find.textContaining('Recovered comparison shell around RPT-CMP-SHELL-1.'),
      findsWidgets,
    );

    final focusLeaderButton = find.byKey(
      const ValueKey('reports-partner-comparison-command-focus-leader'),
    );
    await tester.ensureVisible(focusLeaderButton);
    await tester.tap(focusLeaderButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('reports-partner-scope-banner')),
      findsOneWidget,
    );
    expect(
      find.text('CLIENT-001/SITE-SANDTON • PARTNER • Alpha'),
      findsWidgets,
    );

    final openGovernanceButton = find.byKey(
      const ValueKey('reports-partner-comparison-command-open-governance'),
    );
    await tester.ensureVisible(openGovernanceButton);
    await tester.tap(openGovernanceButton);
    await tester.pumpAndSettle();

    expect(
      openedGovernanceScope,
      equals({'clientId': 'CLIENT-001', 'siteId': 'SITE-SANDTON'}),
    );
  });

  testWidgets('client reports scorecard lanes command banner exposes pivots', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-LANES-SHELL-1',
        occurredAt: _clientReportsScenarioOccurredAtUtc(3, 30),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 2,
        projectionVersion: 2,
        eventRangeStart: 1,
        eventRangeEnd: 3,
        eventCount: 3,
      ),
    );

    final currentReport = SovereignReport(
      date: '2026-03-15',
      generatedAtUtc: _clientReportsGeneratedAtUtc(15),
      shiftWindowStartUtc: _clientReportsShiftStartedAtUtc(14),
      shiftWindowEndUtc: _clientReportsGeneratedAtUtc(15),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 1,
        hashVerified: true,
        integrityScore: 99,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 0,
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
        declarationCount: 0,
        acceptedCount: 0,
        onSiteCount: 0,
        allClearCount: 0,
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
            averageAcceptedDelayMinutes: 4,
            averageOnSiteDelayMinutes: 9,
            summaryLine:
                'Dispatches 1 • Strong 1 • On track 0 • Watch 0 • Critical 0 • Avg accept 4.0m • Avg on site 9.0m',
          ),
        ],
      ),
    );

    Map<String, String>? openedGovernanceScope;

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          morningSovereignReportHistory: [currentReport],
          onOpenGovernanceForScope: (clientId, siteId) {
            openedGovernanceScope = {'clientId': clientId, 'siteId': siteId};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('reports-partner-lanes-command-banner')),
      findsOneWidget,
    );
    expect(find.text('SCORECARD COMMAND'), findsOneWidget);

    final openReceiptsButton = find.byKey(
      const ValueKey('reports-partner-lanes-command-open-receipts'),
    );
    await tester.ensureVisible(openReceiptsButton);
    await tester.tap(openReceiptsButton);
    await tester.pumpAndSettle();

    expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);
    expect(
      find.textContaining(
        'Recovered scorecard lanes around RPT-LANES-SHELL-1.',
      ),
      findsWidgets,
    );

    final focusLeaderButton = find.byKey(
      const ValueKey('reports-partner-lanes-command-focus-leader'),
    );
    await tester.ensureVisible(focusLeaderButton);
    await tester.tap(focusLeaderButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('reports-partner-scope-banner')),
      findsOneWidget,
    );
    expect(
      find.text('CLIENT-001/SITE-SANDTON • PARTNER • Alpha'),
      findsWidgets,
    );

    final openGovernanceButton = find.byKey(
      const ValueKey('reports-partner-lanes-command-open-governance'),
    );
    await tester.ensureVisible(openGovernanceButton);
    await tester.tap(openGovernanceButton);
    await tester.pumpAndSettle();

    expect(
      openedGovernanceScope,
      equals({'clientId': 'CLIENT-001', 'siteId': 'SITE-SANDTON'}),
    );

    final clearFocusButton = find.byKey(
      const ValueKey('reports-partner-lanes-command-clear-focus'),
    );
    await tester.ensureVisible(clearFocusButton);
    await tester.tap(clearFocusButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('reports-partner-scope-banner')),
      findsNothing,
    );
  });

  testWidgets('client reports board cards expose richer command actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-LANE-ROW-1',
        occurredAt: _clientReportsScenarioOccurredAtUtc(4, 0),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 2,
        projectionVersion: 2,
        eventRangeStart: 1,
        eventRangeEnd: 3,
        eventCount: 3,
      ),
    );

    final currentReport = SovereignReport(
      date: '2026-03-15',
      generatedAtUtc: _clientReportsGeneratedAtUtc(15),
      shiftWindowStartUtc: _clientReportsShiftStartedAtUtc(14),
      shiftWindowEndUtc: _clientReportsGeneratedAtUtc(15),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 1,
        hashVerified: true,
        integrityScore: 99,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 0,
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
        declarationCount: 0,
        acceptedCount: 0,
        onSiteCount: 0,
        allClearCount: 0,
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
            averageAcceptedDelayMinutes: 4,
            averageOnSiteDelayMinutes: 9,
            summaryLine:
                'Dispatches 1 • Strong 1 • On track 0 • Watch 0 • Critical 0 • Avg accept 4.0m • Avg on site 9.0m',
          ),
        ],
      ),
    );

    Map<String, String>? openedGovernanceScope;

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          morningSovereignReportHistory: [currentReport],
          onOpenGovernanceForScope: (clientId, siteId) {
            openedGovernanceScope = {'clientId': clientId, 'siteId': siteId};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recommended next move'), findsOneWidget);

    final primaryActionButton = find.byKey(
      const ValueKey(
        'reports-partner-lane-primary-action-CLIENT-001/SITE-SANDTON/PARTNER • Alpha',
      ),
    );
    await tester.ensureVisible(primaryActionButton);
    await tester.tap(primaryActionButton);
    await tester.pumpAndSettle();

    expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);
    expect(find.text('Open Receipt Board'), findsWidgets);
    expect(
      find.textContaining(
        'Recovered lane PARTNER • Alpha around RPT-LANE-ROW-1.',
      ),
      findsWidgets,
    );

    final openReceiptsButton = find.byKey(
      const ValueKey(
        'reports-partner-lane-open-receipts-CLIENT-001/SITE-SANDTON/PARTNER • Alpha',
      ),
    );
    await tester.ensureVisible(openReceiptsButton);
    await tester.tap(openReceiptsButton);
    await tester.pumpAndSettle();

    expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);
    expect(
      find.textContaining(
        'Recovered lane PARTNER • Alpha around RPT-LANE-ROW-1.',
      ),
      findsWidgets,
    );

    final openActivityButton = find.byKey(
      const ValueKey(
        'reports-partner-lane-open-activity-CLIENT-001/SITE-SANDTON/PARTNER • Alpha',
      ),
    );
    await tester.ensureVisible(openActivityButton);
    await tester.tap(openActivityButton);
    await tester.pumpAndSettle();

    expect(find.text('Visitor / Activity Truth'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('reports-site-activity-truth-close')),
    );
    await tester.pumpAndSettle();

    final openDrillInButton = find.byKey(
      const ValueKey(
        'reports-partner-lane-open-drill-in-CLIENT-001/SITE-SANDTON/PARTNER • Alpha',
      ),
    );
    await tester.ensureVisible(openDrillInButton);
    await tester.tap(openDrillInButton);
    await tester.pumpAndSettle();

    expect(find.text('Partner Scorecard Drill-In'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('reports-partner-scorecard-drill-in-close')),
    );
    await tester.pumpAndSettle();

    final openGovernanceButton = find.byKey(
      const ValueKey(
        'reports-partner-lane-open-governance-CLIENT-001/SITE-SANDTON/PARTNER • Alpha',
      ),
    );
    await tester.ensureVisible(openGovernanceButton);
    await tester.tap(openGovernanceButton);
    await tester.pumpAndSettle();

    expect(
      openedGovernanceScope,
      equals({'clientId': 'CLIENT-001', 'siteId': 'SITE-SANDTON'}),
    );
  });

  testWidgets('client reports can focus and clear a partner lane locally', (
    tester,
  ) async {
    String? clipboardText;
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
      generatedAtUtc: _clientReportsGeneratedAtUtc(14),
      shiftWindowStartUtc: _clientReportsShiftStartedAtUtc(13),
      shiftWindowEndUtc: _clientReportsGeneratedAtUtc(14),
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
      generatedAtUtc: _clientReportsGeneratedAtUtc(15),
      shiftWindowStartUtc: _clientReportsShiftStartedAtUtc(14),
      shiftWindowEndUtc: _clientReportsGeneratedAtUtc(15),
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

    final store = InMemoryEventStore();
    store.append(
      ReportGenerated(
        eventId: 'CMP-RPT-1',
        sequence: 1,
        version: 1,
        occurredAt: _clientReportsHistoryOccurredAtUtc(13),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        month: '2026-03',
        contentHash: 'cmp-content-hash-1',
        pdfHash: 'cmp-pdf-hash-1',
        eventRangeStart: 1,
        eventRangeEnd: 20,
        eventCount: 20,
        reportSchemaVersion: 3,
        projectionVersion: 1,
      ),
    );
    store.append(
      ReportGenerated(
        eventId: 'CMP-RPT-2',
        sequence: 2,
        version: 1,
        occurredAt: _clientReportsHistoryOccurredAtUtc(14),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        month: '2026-03',
        contentHash: 'cmp-content-hash-2',
        pdfHash: 'cmp-pdf-hash-2',
        eventRangeStart: 21,
        eventRangeEnd: 40,
        eventCount: 20,
        reportSchemaVersion: 3,
        projectionVersion: 1,
      ),
    );
    store.append(
      ReportGenerated(
        eventId: 'CMP-RPT-3',
        sequence: 3,
        version: 1,
        occurredAt: _clientReportsHistoryOccurredAtUtc(15),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        month: '2026-03',
        contentHash: 'cmp-content-hash-3',
        pdfHash: 'cmp-pdf-hash-3',
        eventRangeStart: 41,
        eventRangeEnd: 64,
        eventCount: 24,
        reportSchemaVersion: 3,
        projectionVersion: 1,
        investigationContextKey: 'governance_branding_drift',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          morningSovereignReportHistory: [priorReport, currentReport],
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
    expect(find.text('Receipt OVERSIGHT RISING'), findsOneWidget);
    expect(find.text('Current Governance: 1'), findsWidgets);
    expect(find.text('Current Routine: 0'), findsWidgets);
    expect(find.text('Baseline Governance: 0.0'), findsWidgets);
    expect(find.text('Baseline Routine: 1.0'), findsWidgets);
    expect(find.text('Partner Scorecard Lanes'), findsOneWidget);
    expect(find.text('Latest shift'), findsWidgets);
    expect(find.text('BEST CURRENT'), findsOneWidget);
    expect(find.text('BEST SHIFT'), findsOneWidget);
    expect(find.text('SITE PACE'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey(
          'reports-partner-comparison-latest-shift-CLIENT-001/SITE-SANDTON/PARTNER • Alpha',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Dispatches 1 • Strong 1 • On track 0 • Watch 0 • Critical 0 • Avg accept 4.0m • Avg on site 10.0m',
      ),
      findsWidgets,
    );
    expect(
      find.text('Latest shift is currently setting the site pace.'),
      findsOneWidget,
    );
    expect(
      find.text('This lane is currently defining the site comparison pace.'),
      findsOneWidget,
    );
    expect(find.text('1 dispatches'), findsWidgets);
    expect(find.text('Accept 4.0m'), findsWidgets);
    expect(find.text('On site 10.0m'), findsWidgets);
    expect(find.text('Accept Δ +2.0m'), findsWidgets);
    expect(find.text('On site Δ +2.0m'), findsWidgets);
    expect(find.text('Gov 1'), findsWidgets);
    expect(find.text('Routine 0'), findsWidgets);
    expect(
      find.text('Receipt OVERSIGHT HANDOFF • Governance 1 • Routine 0'),
      findsWidgets,
    );
    expect(find.text('OVERSIGHT PRESSURE'), findsOneWidget);
    expect(
      find.text(
        'Receipt investigations are leaning toward the Governance Desk on this shift.',
      ),
      findsOneWidget,
    );
    expect(find.text('Investigate'), findsWidgets);
    expect(find.text('Export'), findsWidgets);
    expect(
      find.byKey(const ValueKey('reports-partner-scope-banner')),
      findsNothing,
    );

    final comparisonCopyJsonButton = find.byKey(
      const ValueKey(
        'reports-partner-comparison-copy-json-CLIENT-001/SITE-SANDTON/PARTNER • Alpha',
      ),
    );
    await tester.ensureVisible(comparisonCopyJsonButton);
    await tester.tap(comparisonCopyJsonButton);
    await tester.pumpAndSettle();

    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('"clientId": "CLIENT-001"'));
    expect(clipboardText, contains('"siteId": "SITE-SANDTON"'));
    expect(clipboardText, contains('"partnerLabel": "PARTNER • Alpha"'));

    final comparisonCopyCsvButton = find.byKey(
      const ValueKey(
        'reports-partner-comparison-copy-csv-CLIENT-001/SITE-SANDTON/PARTNER • Alpha',
      ),
    );
    await tester.ensureVisible(comparisonCopyCsvButton);
    await tester.tap(comparisonCopyCsvButton);
    await tester.pumpAndSettle();

    expect(clipboardText, contains('client_id,CLIENT-001'));
    expect(clipboardText, contains('site_id,SITE-SANDTON'));
    expect(clipboardText, contains('partner_label,"PARTNER • Alpha"'));

    final comparisonOpenEventsButton = find.byKey(
      const ValueKey(
        'reports-partner-comparison-open-events-CLIENT-001/SITE-SANDTON/PARTNER • Alpha',
      ),
    );
    await tester.ensureVisible(comparisonOpenEventsButton);
    await tester.tap(comparisonOpenEventsButton);
    await tester.pumpAndSettle();

    expect(openedEventsScope, isNotNull);
    expect(openedEventsScope!['eventIds'], <String>['CMP-RPT-3']);
    expect(openedEventsScope!['selectedEventId'], 'CMP-RPT-3');

    final comparisonOpenLatestShiftButton = find.byKey(
      const ValueKey(
        'reports-partner-comparison-open-latest-shift-CLIENT-001/SITE-SANDTON/PARTNER • Alpha',
      ),
    );
    await tester.ensureVisible(comparisonOpenLatestShiftButton);
    await tester.tap(comparisonOpenLatestShiftButton);
    await tester.pumpAndSettle();

    expect(find.text('Partner Shift Detail'), findsOneWidget);
    expect(
      find.text('2026-03-15 • CLIENT-001/SITE-SANDTON • PARTNER • Alpha'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('reports-partner-shift-detail-close')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partner Shift Detail'), findsNothing);

    final comparisonOpenDrillInButton = find.byKey(
      const ValueKey(
        'reports-partner-comparison-open-drill-in-CLIENT-001/SITE-SANDTON/PARTNER • Beta',
      ),
    );
    await tester.ensureVisible(comparisonOpenDrillInButton);
    await tester.tap(comparisonOpenDrillInButton);
    await tester.pumpAndSettle();

    expect(find.text('Partner Scorecard Drill-In'), findsOneWidget);
    expect(
      find.text('CLIENT-001/SITE-SANDTON • PARTNER • Beta'),
      findsOneWidget,
    );
    expect(find.text('Receipt provenance by shift'), findsOneWidget);
    expect(find.text('Scorecard history'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey('reports-partner-scorecard-drill-in-copy-json'),
      ),
    );
    await tester.pumpAndSettle();

    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('"clientId": "CLIENT-001"'));
    expect(clipboardText, contains('"siteId": "SITE-SANDTON"'));
    expect(clipboardText, contains('"partnerLabel": "PARTNER • Beta"'));

    await tester.tap(
      find.byKey(const ValueKey('reports-partner-scorecard-drill-in-copy-csv')),
    );
    await tester.pumpAndSettle();

    expect(clipboardText, contains('client_id,CLIENT-001'));
    expect(clipboardText, contains('site_id,SITE-SANDTON'));
    expect(clipboardText, contains('partner_label,"PARTNER • Beta"'));

    await tester.tap(
      find.byKey(const ValueKey('reports-partner-scorecard-drill-in-close')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partner Scorecard Drill-In'), findsNothing);

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
    expect(clipboardText, contains('"receiptInvestigation": {'));
    expect(clipboardText, contains('"trendLabel": "OVERSIGHT RISING"'));
    expect(clipboardText, contains('"currentGovernanceHandoffCount": 1'));
    expect(clipboardText, contains('"currentRoutineReviewCount": 0'));
    expect(clipboardText, contains('"baselineGovernanceAverage": 0.0'));
    expect(clipboardText, contains('"baselineRoutineAverage": 1.0'));
    expect(clipboardText, contains('"baselineReceiptCount": 2'));

    final copyComparisonCsvButton = find.byKey(
      const ValueKey('reports-partner-comparison-copy-csv'),
    );
    await tester.ensureVisible(copyComparisonCsvButton);
    await tester.tap(copyComparisonCsvButton);
    await tester.pumpAndSettle();

    expect(clipboardText, contains('client_id,CLIENT-001'));
    expect(clipboardText, contains('site_id,SITE-SANDTON'));
    expect(
      clipboardText,
      contains('receipt_investigation_trend_label,"OVERSIGHT RISING"'),
    );
    expect(
      clipboardText,
      contains('receipt_investigation_current_governance_handoff_count,1'),
    );
    expect(
      clipboardText,
      contains('receipt_investigation_current_routine_review_count,0'),
    );
    expect(
      clipboardText,
      contains('receipt_investigation_baseline_governance_average,0.0'),
    );
    expect(
      clipboardText,
      contains('receipt_investigation_baseline_routine_average,1.0'),
    );
    expect(
      clipboardText,
      contains('receipt_investigation_baseline_receipt_count,2'),
    );
    expect(clipboardText, contains('comparison_1,"PARTNER • Alpha"'));
    expect(
      clipboardText,
      contains(
        'comparison_2_history_2,"2026-03-14 • HISTORY • CLIENT-001/SITE-SANDTON • PARTNER • Beta',
      ),
    );

    final comparisonHistoryChip = find.byKey(
      const ValueKey(
        'reports-partner-comparison-history-CLIENT-001/SITE-SANDTON/PARTNER • Alpha-2026-03-15',
      ),
    );
    await tester.ensureVisible(comparisonHistoryChip);
    await tester.tap(comparisonHistoryChip);
    await tester.pumpAndSettle();

    expect(find.text('Partner Shift Detail'), findsOneWidget);
    expect(
      find.text('2026-03-15 • CLIENT-001/SITE-SANDTON • PARTNER • Alpha'),
      findsOneWidget,
    );
    expect(find.text('Shift receipts'), findsOneWidget);
    expect(find.text('Shift dispatch chains'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('reports-partner-shift-detail-close')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partner Shift Detail'), findsNothing);

    final baselineWindowButton = find.byKey(
      const ValueKey('reports-partner-comparison-window-baseline'),
    );
    await tester.ensureVisible(baselineWindowButton);
    await tester.tap(baselineWindowButton);
    await tester.pumpAndSettle();

    expect(
      find.text(
        '3-shift baseline • Strong 1 • On track 1 • Watch 0 • Critical 0 • Avg accept 5.5m • Avg on site 12.0m',
      ),
      findsOneWidget,
    );
    expect(find.text('Accept +2.0m • On site +3.0m vs leader'), findsOneWidget);

    await tester.ensureVisible(copyComparisonJsonButton);
    await tester.tap(copyComparisonJsonButton);
    await tester.pumpAndSettle();

    expect(clipboardText, contains('"comparisonWindow": "baseline3Shift"'));
    expect(clipboardText, contains('"metricAcceptedDelayMinutes": 5.5'));
    expect(clipboardText, contains('"metricOnSiteDelayMinutes": 12.0'));

    await tester.ensureVisible(copyComparisonCsvButton);
    await tester.tap(copyComparisonCsvButton);
    await tester.pumpAndSettle();

    expect(clipboardText, contains('comparison_window,baseline3Shift'));
    expect(clipboardText, contains('metric_accept=5.5'));
    expect(clipboardText, contains('metric_on_site=15.0'));

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

  testWidgets('client reports shows receipt policy history and exports it', (
    tester,
  ) async {
    String? clipboardText;
    Map<String, Object?>? openedEventsScope;
    String? openedGovernanceClientId;
    String? openedGovernanceSiteId;
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
      ReportGenerated(
        eventId: 'RPT-1',
        sequence: 1,
        version: 1,
        occurredAt: _clientReportsHistoryOccurredAtUtc(13),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        month: '2026-03',
        contentHash: 'content-hash-1',
        pdfHash: 'pdf-hash-1',
        eventRangeStart: 1,
        eventRangeEnd: 20,
        eventCount: 20,
        reportSchemaVersion: 3,
        projectionVersion: 1,
      ),
    );
    store.append(
      ReportGenerated(
        eventId: 'RPT-2',
        sequence: 2,
        version: 1,
        occurredAt: _clientReportsHistoryOccurredAtUtc(14),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        month: '2026-03',
        contentHash: 'content-hash-2',
        pdfHash: 'pdf-hash-2',
        eventRangeStart: 21,
        eventRangeEnd: 40,
        eventCount: 20,
        reportSchemaVersion: 1,
        projectionVersion: 1,
      ),
    );
    store.append(
      ReportGenerated(
        eventId: 'RPT-3',
        sequence: 3,
        version: 1,
        occurredAt: _clientReportsHistoryOccurredAtUtc(15),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        month: '2026-03',
        contentHash: 'content-hash-3',
        pdfHash: 'pdf-hash-3',
        eventRangeStart: 41,
        eventRangeEnd: 64,
        eventCount: 24,
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
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          onOpenGovernanceForScope: (clientId, siteId) {
            openedGovernanceClientId = clientId;
            openedGovernanceSiteId = siteId;
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

    expect(find.text('Receipt Policy History'), findsOneWidget);
    expect(find.text('SLIPPING'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reports-receipt-policy-investigation-lens')),
      findsOneWidget,
    );
    expect(find.text('OVERSIGHT HANDOFF'), findsWidgets);
    expect(find.text('ROUTINE BASELINE'), findsOneWidget);
    expect(
      find.text('Omitted AI Decision Log, Guard Metrics • Custom branding'),
      findsWidgets,
    );
    expect(
      find.text(
        'The latest receipt introduced a custom branding override against the recent receipt baseline.',
      ),
      findsOneWidget,
    );
    expect(find.text('OVERSIGHT RISING'), findsWidgets);
    expect(find.text('1 oversight'), findsOneWidget);
    expect(find.text('2 routine'), findsOneWidget);
    expect(find.text('Current Governance: 1'), findsOneWidget);
    expect(find.text('Current Routine: 0'), findsOneWidget);
    expect(find.text('Baseline Governance: 0.0'), findsOneWidget);
    expect(find.text('Baseline Routine: 1.0'), findsOneWidget);
    expect(find.text('OPEN GOVERNANCE DESK'), findsWidgets);
    expect(find.text('OVERSIGHT HANDOFFS'), findsOneWidget);
    expect(find.text('ROUTINE REVIEW'), findsWidgets);
    expect(find.text('INVESTIGATION DRIFT'), findsOneWidget);
    expect(
      find.text(
        'The latest receipt entered Reports through a Governance branding-drift handoff against a more routine recent baseline.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reports-receipt-policy-row-RPT-3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reports-receipt-policy-row-RPT-2')),
      findsOneWidget,
    );
    expect(find.text('LEGACY'), findsOneWidget);
    expect(find.text('2 OMITTED'), findsWidgets);
    expect(find.text('CUSTOM BRANDING'), findsWidgets);
    expect(find.text('OVERSIGHT HANDOFF'), findsWidgets);

    final openHistoryButton = find.byKey(
      const ValueKey('reports-receipt-policy-open-investigation-history'),
    );
    await tester.ensureVisible(openHistoryButton);
    await tester.tap(openHistoryButton);
    await tester.pumpAndSettle();

    expect(find.text('Receipt Investigation History'), findsOneWidget);
    expect(find.text('OVERSIGHT RISING'), findsWidgets);
    expect(find.text('Baseline Receipts: 2'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('reports-receipt-policy-investigation-history-close'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reports-receipt-policy-row-RPT-1')),
      findsNWidgets(2),
    );

    await tester.tap(
      find.byKey(
        const ValueKey('reports-receipt-policy-investigation-history-close'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Receipt Investigation History'), findsNothing);

    final copyJsonButton = find.byKey(
      const ValueKey('reports-receipt-policy-copy-json'),
    );
    await tester.ensureVisible(copyJsonButton);
    await tester.tap(copyJsonButton);
    await tester.pumpAndSettle();

    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('"investigationLens": {'));
    expect(clipboardText, contains('"modeKey": "governance_branding_drift"'));
    expect(clipboardText, contains('"modeLabel": "OVERSIGHT HANDOFF"'));
    expect(clipboardText, contains('"investigationBreakdown": {'));
    expect(clipboardText, contains('"governanceHandoffCount": 1'));
    expect(clipboardText, contains('"routineReviewCount": 2'));
    expect(clipboardText, contains('"investigationComparison": {'));
    expect(clipboardText, contains('"currentGovernanceHandoffCount": 1'));
    expect(clipboardText, contains('"currentRoutineReviewCount": 0'));
    expect(clipboardText, contains('"baselineGovernanceAverage": 0.0'));
    expect(clipboardText, contains('"baselineRoutineAverage": 1.0'));
    expect(clipboardText, contains('"baselineReceiptCount": 2'));
    expect(clipboardText, contains('"trendLabel": "SLIPPING"'));
    expect(clipboardText, contains('"investigationTrend": {'));
    expect(clipboardText, contains('"label": "OVERSIGHT RISING"'));
    expect(
      clipboardText,
      contains(
        '"reason": "The latest receipt entered Reports through a Governance branding-drift handoff against a more routine recent baseline."',
      ),
    );
    expect(clipboardText, contains('"eventId": "RPT-3"'));
    expect(clipboardText, contains('"brandingMode": "CUSTOM BRANDING"'));
    expect(
      clipboardText,
      contains('"investigationContextKey": "governance_branding_drift"'),
    );
    expect(
      clipboardText,
      contains('"investigationContextLabel": "OVERSIGHT HANDOFF"'),
    );
    expect(
      clipboardText,
      contains(
        '"brandingSummary": "Branding: custom override from default partner lane PARTNER • Alpha."',
      ),
    );
    expect(clipboardText, contains('"stateLabel": "LEGACY"'));
    expect(clipboardText, contains('"omittedSections": ['));

    final copyCsvButton = find.byKey(
      const ValueKey('reports-receipt-policy-copy-csv'),
    );
    await tester.ensureVisible(copyCsvButton);
    await tester.tap(copyCsvButton);
    await tester.pumpAndSettle();

    expect(
      clipboardText,
      contains('investigation_mode,governance_branding_drift'),
    );
    expect(
      clipboardText,
      contains('investigation_mode_label,"OVERSIGHT HANDOFF"'),
    );
    expect(clipboardText, contains('investigation_governance_handoff_count,1'));
    expect(clipboardText, contains('investigation_routine_review_count,2'));
    expect(
      clipboardText,
      contains('investigation_current_governance_handoff_count,1'),
    );
    expect(
      clipboardText,
      contains('investigation_current_routine_review_count,0'),
    );
    expect(
      clipboardText,
      contains('investigation_baseline_governance_average,0.0'),
    );
    expect(
      clipboardText,
      contains('investigation_baseline_routine_average,1.0'),
    );
    expect(clipboardText, contains('investigation_baseline_receipt_count,2'));
    expect(
      clipboardText,
      contains('investigation_trend_label,"OVERSIGHT RISING"'),
    );
    expect(
      clipboardText,
      contains(
        'investigation_trend_reason,"The latest receipt entered Reports through a Governance branding-drift handoff against a more routine recent baseline."',
      ),
    );
    expect(clipboardText, contains('trend_label,SLIPPING'));
    expect(
      clipboardText,
      contains(
        'receipt_1,"RPT-3",state=2 OMITTED,branding=CUSTOM BRANDING,investigation=governance_branding_drift',
      ),
    );
    expect(clipboardText, contains('receipt_2,"RPT-2",state=LEGACY'));

    final openEventsButton = find.byKey(
      const ValueKey('reports-receipt-policy-open-events-RPT-3'),
    );
    await tester.ensureVisible(openEventsButton);
    await tester.tap(openEventsButton);
    await tester.pumpAndSettle();

    expect(openedEventsScope, <String, Object?>{
      'eventIds': ['RPT-3'],
      'selectedEventId': 'RPT-3',
    });

    final openGovernanceButton = find.byKey(
      const ValueKey('reports-receipt-policy-open-governance'),
    );
    await tester.ensureVisible(openGovernanceButton);
    await tester.tap(openGovernanceButton);
    await tester.pumpAndSettle();

    expect(openedGovernanceClientId, 'CLIENT-001');
    expect(openedGovernanceSiteId, 'SITE-SANDTON');
    expect(find.text('Opening Governance for SITE-SANDTON.'), findsOneWidget);
  });

  testWidgets(
    'client reports shows and clears governance branding drift entry context',
    (tester) async {
      String? clipboardText;
      String? openedGovernanceClientId;
      String? openedGovernanceSiteId;
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
        ReportGenerated(
          eventId: 'RPT-CTX-1',
          sequence: 1,
          version: 1,
          occurredAt: _clientReportsHistoryOccurredAtUtc(15),
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          month: '2026-03',
          contentHash: 'content-hash-ctx-1',
          pdfHash: 'pdf-hash-ctx-1',
          eventRangeStart: 1,
          eventRangeEnd: 20,
          eventCount: 20,
          reportSchemaVersion: 3,
          projectionVersion: 1,
        ),
      );

      final shellState = ValueNotifier(
        const ReportShellState(
          previewReceiptEventId: 'RPT-CTX-1',
          entryContext: ReportEntryContext.governanceBrandingDrift,
        ),
      );
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
                reportShellState: value,
                onOpenGovernanceForScope: (clientId, siteId) {
                  openedGovernanceClientId = clientId;
                  openedGovernanceSiteId = siteId;
                },
                onReportShellStateChanged: (next) => shellState.value = next,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final policyCopyJson = find.byKey(
        const ValueKey('reports-receipt-policy-copy-json'),
      );
      await tester.ensureVisible(policyCopyJson);
      await tester.tap(policyCopyJson);
      await tester.pumpAndSettle();

      expect(clipboardText, isNotNull);
      expect(clipboardText, contains('"entryContext": {'));
      expect(clipboardText, contains('"key": "governance_branding_drift"'));
      expect(
        clipboardText,
        contains('"title": "OPENED FROM GOVERNANCE BRANDING DRIFT"'),
      );
      expect(clipboardText, contains('"investigationLens": {'));
      expect(clipboardText, contains('"modeKey": "governance_branding_drift"'));
      expect(clipboardText, contains('"modeLabel": "OVERSIGHT HANDOFF"'));

      expect(
        find.byKey(
          const ValueKey('reports-receipt-policy-entry-context-banner'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('OPENED FROM GOVERNANCE BRANDING DRIFT'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'This receipt scope was opened from Governance so operators can inspect the generated-report history behind a branding-drift shift.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('reports-receipt-policy-investigation-lens')),
        findsOneWidget,
      );
      expect(find.text('OVERSIGHT HANDOFF'), findsOneWidget);
      expect(find.text('ROUTINE BASELINE'), findsOneWidget);
      expect(find.text('Receipt • RPT-CTX-1'), findsOneWidget);
      expect(find.text('GOVERNANCE TARGET'), findsOneWidget);

      final openGovernanceButton = find.byKey(
        const ValueKey('reports-receipt-policy-entry-context-open-governance'),
      );
      await tester.ensureVisible(openGovernanceButton);
      await tester.tap(openGovernanceButton);
      await tester.pumpAndSettle();

      expect(openedGovernanceClientId, 'CLIENT-001');
      expect(openedGovernanceSiteId, 'SITE-SANDTON');
      expect(find.text('Opening Governance for SITE-SANDTON.'), findsOneWidget);

      final dismissButton = find.byKey(
        const ValueKey('reports-receipt-policy-entry-context-clear'),
      );
      await tester.ensureVisible(dismissButton);
      await tester.tap(dismissButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('reports-receipt-policy-entry-context-banner'),
        ),
        findsNothing,
      );
      expect(find.text('GOVERNANCE TARGET'), findsNothing);
      expect(shellState.value.entryContext, isNull);
      expect(shellState.value.previewReceiptEventId, 'RPT-CTX-1');
      expect(find.text('FOCUSED'), findsOneWidget);
      expect(
        find.textContaining('Governance branding-drift context cleared.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('client reports persists comparison window through remount', (
    tester,
  ) async {
    final shellState = ValueNotifier(const ReportShellState());
    addTearDown(shellState.dispose);

    final priorReport = SovereignReport(
      date: '2026-03-14',
      generatedAtUtc: _clientReportsGeneratedAtUtc(14),
      shiftWindowStartUtc: _clientReportsShiftStartedAtUtc(13),
      shiftWindowEndUtc: _clientReportsGeneratedAtUtc(14),
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
      generatedAtUtc: _clientReportsGeneratedAtUtc(15),
      shiftWindowStartUtc: _clientReportsShiftStartedAtUtc(14),
      shiftWindowEndUtc: _clientReportsGeneratedAtUtc(15),
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

    Widget buildReports() {
      return MaterialApp(
        home: ValueListenableBuilder<ReportShellState>(
          valueListenable: shellState,
          builder: (context, value, _) {
            return ClientIntelligenceReportsPage(
              key: ValueKey(value.partnerComparisonWindow),
              store: InMemoryEventStore(),
              selectedClient: 'CLIENT-001',
              selectedSite: 'SITE-SANDTON',
              morningSovereignReportHistory: [priorReport, currentReport],
              reportShellState: value,
              onReportShellStateChanged: (next) => shellState.value = next,
            );
          },
        ),
      );
    }

    await tester.pumpWidget(buildReports());
    await tester.pumpAndSettle();

    final baselineWindow = find.byKey(
      const ValueKey('reports-partner-comparison-window-baseline'),
    );
    await tester.ensureVisible(baselineWindow);
    await tester.tap(baselineWindow);
    await tester.pumpAndSettle();

    expect(
      shellState.value.partnerComparisonWindow,
      ReportPartnerComparisonWindow.baseline3Shift,
    );
    expect(
      find.text(
        '3-shift baseline • Strong 1 • On track 1 • Watch 0 • Critical 0 • Avg accept 5.5m • Avg on site 12.0m',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(buildReports());
    await tester.pumpAndSettle();

    expect(
      shellState.value.partnerComparisonWindow,
      ReportPartnerComparisonWindow.baseline3Shift,
    );
    expect(
      find.text(
        '3-shift baseline • Strong 1 • On track 1 • Watch 0 • Critical 0 • Avg accept 5.5m • Avg on site 12.0m',
      ),
      findsOneWidget,
    );
  });

  testWidgets('client reports persists focused partner scope through remount', (
    tester,
  ) async {
    final shellState = ValueNotifier(const ReportShellState());
    addTearDown(shellState.dispose);

    final currentReport = SovereignReport(
      date: '2026-03-15',
      generatedAtUtc: _clientReportsGeneratedAtUtc(15),
      shiftWindowStartUtc: _clientReportsShiftStartedAtUtc(14),
      shiftWindowEndUtc: _clientReportsGeneratedAtUtc(15),
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

    Widget buildReports() {
      return MaterialApp(
        home: ValueListenableBuilder<ReportShellState>(
          valueListenable: shellState,
          builder: (context, value, _) {
            return ClientIntelligenceReportsPage(
              key: ValueKey(
                '${value.partnerScopeClientId}|${value.partnerScopeSiteId}|${value.partnerScopePartnerLabel}',
              ),
              store: InMemoryEventStore(),
              selectedClient: 'CLIENT-001',
              selectedSite: 'SITE-SANDTON',
              morningSovereignReportHistory: [currentReport],
              reportShellState: value,
              onReportShellStateChanged: (next) => shellState.value = next,
            );
          },
        ),
      );
    }

    await tester.pumpWidget(buildReports());
    await tester.pumpAndSettle();

    final focusLaneButton = find.byKey(
      const ValueKey(
        'reports-partner-lane-focus-CLIENT-001/SITE-SANDTON/PARTNER • Beta',
      ),
    );
    await tester.ensureVisible(focusLaneButton);
    await tester.tap(focusLaneButton);
    await tester.pumpAndSettle();

    expect(shellState.value.partnerScopeClientId, 'CLIENT-001');
    expect(shellState.value.partnerScopeSiteId, 'SITE-SANDTON');
    expect(shellState.value.partnerScopePartnerLabel, 'PARTNER • Beta');
    expect(
      find.byKey(const ValueKey('reports-partner-scope-banner')),
      findsOneWidget,
    );
    expect(
      find.text('CLIENT-001/SITE-SANDTON • PARTNER • Beta'),
      findsOneWidget,
    );

    await tester.pumpWidget(buildReports());
    await tester.pumpAndSettle();

    expect(shellState.value.partnerScopeClientId, 'CLIENT-001');
    expect(shellState.value.partnerScopeSiteId, 'SITE-SANDTON');
    expect(shellState.value.partnerScopePartnerLabel, 'PARTNER • Beta');
    expect(
      find.byKey(const ValueKey('reports-partner-scope-banner')),
      findsOneWidget,
    );
    expect(
      find.text('CLIENT-001/SITE-SANDTON • PARTNER • Beta'),
      findsOneWidget,
    );
  });

  testWidgets(
    'client reports persists report configuration toggles through remount',
    (tester) async {
      final shellState = ValueNotifier(const ReportShellState());
      addTearDown(shellState.dispose);

      Widget buildReports() {
        return MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ClientIntelligenceReportsPage(
                key: ValueKey(
                  '${value.includeAiDecisionLog}|${value.includeGuardMetrics}',
                ),
                store: InMemoryEventStore(),
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
              );
            },
          ),
        );
      }

      await tester.pumpWidget(buildReports());
      await tester.pumpAndSettle();

      final includeAiDecisionLogToggle = find.widgetWithText(
        CheckboxListTile,
        'Include AI decision log',
      );
      final includeGuardMetricsToggle = find.widgetWithText(
        CheckboxListTile,
        'Include guard performance metrics',
      );

      await tester.ensureVisible(includeAiDecisionLogToggle);
      await tester.tap(includeAiDecisionLogToggle);
      await tester.pumpAndSettle();
      await tester.ensureVisible(includeGuardMetricsToggle);
      await tester.tap(includeGuardMetricsToggle);
      await tester.pumpAndSettle();

      expect(shellState.value.includeAiDecisionLog, isTrue);
      expect(shellState.value.includeGuardMetrics, isTrue);

      await tester.pumpWidget(buildReports());
      await tester.pumpAndSettle();

      expect(shellState.value.includeAiDecisionLog, isTrue);
      expect(shellState.value.includeGuardMetrics, isTrue);
      expect(
        tester.widget<CheckboxListTile>(includeAiDecisionLogToggle).value,
        isTrue,
      );
      expect(
        tester.widget<CheckboxListTile>(includeGuardMetricsToggle).value,
        isTrue,
      );
    },
  );

  testWidgets('client reports persists branding overrides through remount', (
    tester,
  ) async {
    final shellState = ValueNotifier(
      const ReportShellState(
        partnerScopeClientId: 'CLIENT-001',
        partnerScopeSiteId: 'SITE-SANDTON',
        partnerScopePartnerLabel: 'PARTNER • Alpha',
      ),
    );
    addTearDown(shellState.dispose);

    Widget buildReports() {
      return MaterialApp(
        home: ValueListenableBuilder<ReportShellState>(
          valueListenable: shellState,
          builder: (context, value, _) {
            return ClientIntelligenceReportsPage(
              key: ValueKey(
                '${value.brandingPrimaryLabelOverride}|${value.brandingEndorsementLineOverride}',
              ),
              store: InMemoryEventStore(),
              selectedClient: 'CLIENT-001',
              selectedSite: 'SITE-SANDTON',
              reportShellState: value,
              onReportShellStateChanged: (next) => shellState.value = next,
            );
          },
        ),
      );
    }

    await tester.pumpWidget(buildReports());
    await tester.pumpAndSettle();

    expect(find.text('PARTNER • Alpha'), findsWidgets);
    expect(find.text('Powered by ONYX'), findsOneWidget);

    final editBrandingButton = find.byKey(
      const ValueKey('reports-branding-edit-button'),
    );
    await tester.ensureVisible(editBrandingButton);
    await tester.tap(editBrandingButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('reports-branding-primary-field')),
      'VISION Tactical',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reports-branding-endorsement-field')),
      'Intelligence by ONYX',
    );
    await tester.tap(
      find.byKey(const ValueKey('reports-branding-save-button')),
    );
    await tester.pumpAndSettle();

    expect(shellState.value.brandingPrimaryLabelOverride, 'VISION Tactical');
    expect(
      shellState.value.brandingEndorsementLineOverride,
      'Intelligence by ONYX',
    );

    await tester.pumpWidget(buildReports());
    await tester.pumpAndSettle();

    expect(find.text('VISION Tactical'), findsWidgets);
    expect(find.text('Intelligence by ONYX'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reports-branding-reset-button')),
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
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
        occurredAt: _clientReportsShiftStartedAtUtc(14),
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

    expect(
      find.byKey(const ValueKey('reports-workspace-command-receipt')),
      findsOneWidget,
    );

    final copyButton = find.byKey(
      const ValueKey('report-receipt-copy-RPT-COPY-1'),
    );
    await tester.ensureVisible(copyButton);
    await tester.tap(copyButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Receipt export copied for command review: RPT-COPY-1.',
      ),
      findsWidgets,
    );
    expect(find.byType(SnackBar), findsNothing);
    expect(clipboardText, isNotNull);
    expect(
      clipboardText,
      contains('"exportModeLabel": "STANDARD RECEIPT EXPORT"'),
    );
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
      const ValueKey('report-receipt-preview-RPT-2026-04-07-001'),
    );
    await tester.ensureVisible(previewButton);
    await tester.tap(previewButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Receipt preview will unlock once the first live report lands on this board.',
      ),
      findsWidgets,
    );

    final downloadButton = find.byKey(
      const ValueKey('report-receipt-download-RPT-2026-04-07-001'),
    );
    await tester.ensureVisible(downloadButton);
    await tester.tap(downloadButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Sample receipt metadata copied for command review: RPT-2026-04-07-001.',
      ),
      findsWidgets,
    );
    expect(clipboardText, isNotNull);
    expect(
      clipboardText,
      contains('"exportModeLabel": "STANDARD RECEIPT EXPORT"'),
    );
    expect(clipboardText, contains('"context"'));
    expect(clipboardText, contains('"receipts"'));
    expect(clipboardText, contains('"key": "all"'));
    expect(clipboardText, contains('"eventId": "RPT-2026-04-07-001"'));
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

    expect(
      find.text('No receipts fit the current filter right now.'),
      findsOneWidget,
    );
  });

  testWidgets('client reports filtered empty state offers recovery pivots', (
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
      find.byKey(const ValueKey('reports-history-empty-state')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reports-history-empty-open-all')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reports-history-empty-open-pending')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reports-selected-recovery-open-all')),
      findsOneWidget,
    );

    final selectedRecovery = find.byKey(
      const ValueKey('reports-selected-recovery-open-all'),
    );
    await tester.ensureVisible(selectedRecovery);
    await tester.tap(selectedRecovery);
    await tester.pumpAndSettle();

    expect(
      find.text('No receipts fit the current filter right now.'),
      findsNothing,
    );
    expect(find.text('Viewing Escalation receipts (0/3)'), findsNothing);
    expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);
    expect(find.byType(SnackBar), findsNothing);
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

    expect(find.text('Viewing Escalation receipts (0/3)'), findsOneWidget);
    expect(
      find.text('No receipts fit the current filter right now.'),
      findsOneWidget,
    );

    await tester.ensureVisible(escalationKpi);
    await tester.tap(escalationKpi);
    await tester.pumpAndSettle();

    expect(find.text('Viewing Escalation receipts (0/3)'), findsNothing);
    expect(
      find.text('No receipts fit the current filter right now.'),
      findsNothing,
    );
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

    expect(find.text('Viewing Suppressed receipts (1/2)'), findsOneWidget);
    expect(
      find.textContaining(reportTestSuppressedDecisionSummary),
      findsOneWidget,
    );
    expect(
      find.text('No receipts fit the current filter right now.'),
      findsNothing,
    );
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

    expect(find.text('Viewing Alert receipts (1/2)'), findsOneWidget);
    expect(
      find.textContaining(
        'Scene review stayed below escalation threshold across 1 reviewed CCTV event with 1 alert.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('No receipts fit the current filter right now.'),
      findsNothing,
    );
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

      expect(find.text('Viewing Latest Alert receipts (1/2)'), findsOneWidget);
      expect(
        find.text('No receipts fit the current filter right now.'),
        findsNothing,
      );
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
          'Receipt export copied for command review: ${fixture.reviewedReceiptEventId}.',
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
      expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);

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
      expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);
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
        selectedReceiptEventId: 'RPT-2026-04-07-001',
      );
      await tester.pumpAndSettle();

      expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);
      expect(find.text('FOCUSED'), findsWidgets);
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
      expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);

      final escalationKpi = find.byKey(
        const ValueKey('reports-kpi-escalation'),
      );
      await tester.ensureVisible(escalationKpi);
      await tester.tap(escalationKpi);
      await tester.pumpAndSettle();

      expect(find.text('Viewing Escalation receipts (0/2)'), findsOneWidget);
      expect(
        find.text('No receipts fit the current filter right now.'),
        findsOneWidget,
      );
      expect(find.text('No Receipt Selected'), findsOneWidget);
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);

      final reviewedKpi = find.byKey(const ValueKey('reports-kpi-reviewed'));
      await tester.ensureVisible(reviewedKpi);
      await tester.tap(reviewedKpi);
      await tester.pumpAndSettle();

      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);
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
      expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);

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
        find.text('No receipts fit the current filter right now.'),
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
      expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);
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
      expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);

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
      expect(find.text('OPEN PREVIEW DOCK'), findsWidgets);

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
      expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);
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
      previewReceiptEventId: 'RPT-2026-04-07-001',
    );
    await tester.pumpAndSettle();

    expect(find.text('Preview target: RPT-2026-04-07-001'), findsOneWidget);
    expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);
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
      previewReceiptEventId: 'RPT-2026-04-07-001',
      previewSurface: ReportPreviewSurface.dock,
    );
    await tester.pumpAndSettle();

    expect(find.text('Preview Dock'), findsOneWidget);
    expect(find.text('Docked'), findsOneWidget);
    expect(find.text('OPEN PREVIEW DOCK'), findsWidgets);
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
        occurredAt: _clientReportsPreviewOccurredAtUtc(15),
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
      previewReceiptEventId: 'RPT-2026-04-07-001',
    );
    await tester.pumpAndSettle();

    final clearPreviewTarget = find.byKey(
      const ValueKey('reports-preview-target-clear'),
    );
    await tester.ensureVisible(clearPreviewTarget);
    await tester.tap(clearPreviewTarget);
    await tester.pumpAndSettle();

    expect(changedState?.previewReceiptEventId, isNull);
    expect(find.text('Preview target: RPT-2026-04-07-001'), findsNothing);
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

      final clearPreviewTarget = find.byKey(
        const ValueKey('reports-preview-target-clear'),
      );
      await tester.ensureVisible(clearPreviewTarget);
      await tester.tap(clearPreviewTarget);
      await tester.pumpAndSettle();

      expect(shellState.value.previewReceiptEventId, isNull);
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsNothing,
      );
      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);
    },
  );

  testWidgets('client reports dock clear updates shell state', (tester) async {
    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-LIVE-DOCK-CLEAR-1',
        occurredAt: _clientReportsPreviewOccurredAtUtc(20),
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
    expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);
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
        occurredAt: _clientReportsHistoryOccurredAtUtc(14, minute: 55),
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
        occurredAt: _clientReportsPreviewOccurredAtUtc(45),
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
          occurredAt: _clientReportsPreviewOccurredAtUtc(55),
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
        occurredAt: _clientReportsPreviewOccurredAtUtc(55),
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
      findsNothing,
    );
    expect(
      find.textContaining(
        'Receipt export copied for command review: RPT-LIVE-DOCK-COPY-1.',
      ),
      findsWidgets,
    );
    expect(clipboardText, contains('"eventId": "RPT-LIVE-DOCK-COPY-1"'));
  });

  testWidgets(
    'client reports governance dock shows governance-specific actions',
    (tester) async {
      final store = InMemoryEventStore();
      store.append(
        buildTestReportGenerated(
          eventId: 'RPT-LIVE-DOCK-GOV-1',
          occurredAt: _clientReportsPreviewOccurredAtUtc(55),
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
              previewReceiptEventId: 'RPT-LIVE-DOCK-GOV-1',
              previewSurface: ReportPreviewSurface.dock,
              entryContext: ReportEntryContext.governanceBrandingDrift,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Governance Preview Dock'), findsOneWidget);
      expect(find.text('OPEN GOVERNANCE PREVIEW DOCK'), findsWidgets);
      expect(find.text('Copy Governance Receipt'), findsWidgets);
      expect(find.text('Download Governance PDF'), findsWidgets);
      expect(
        find.byKey(const ValueKey('reports-preview-dock-download')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'client reports governance dock download opens governance preview request',
    (tester) async {
      ReportPreviewRequest? previewRequest;
      ReportShellState? changedState;
      final store = InMemoryEventStore();
      store.append(
        buildTestReportGenerated(
          eventId: 'RPT-LIVE-DOCK-DOWNLOAD-GOV-1',
          occurredAt: _clientReportsPreviewOccurredAtUtc(55),
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
              previewReceiptEventId: 'RPT-LIVE-DOCK-DOWNLOAD-GOV-1',
              previewSurface: ReportPreviewSurface.dock,
              entryContext: ReportEntryContext.governanceBrandingDrift,
            ),
            onReportShellStateChanged: (next) => changedState = next,
            onRequestPreview: (value) => previewRequest = value,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dockDownload = find.byKey(
        const ValueKey('reports-preview-dock-download'),
      );
      await tester.ensureVisible(dockDownload);
      await tester.tap(dockDownload);
      await tester.pumpAndSettle();

      expect(
        previewRequest?.receiptEvent?.eventId,
        'RPT-LIVE-DOCK-DOWNLOAD-GOV-1',
      );
      expect(
        previewRequest?.entryContext,
        ReportEntryContext.governanceBrandingDrift,
      );
      expect(
        changedState?.selectedReceiptEventId,
        'RPT-LIVE-DOCK-DOWNLOAD-GOV-1',
      );
      expect(
        changedState?.previewReceiptEventId,
        'RPT-LIVE-DOCK-DOWNLOAD-GOV-1',
      );
    },
  );

  testWidgets('client reports preview target open triggers preview request', (
    tester,
  ) async {
    ReportPreviewRequest? previewRequest;
    ReportShellState? changedState;
    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-LIVE-TARGET-1',
        occurredAt: _clientReportsPreviewOccurredAtUtc(40),
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

  testWidgets(
    'client reports governance preview target shows governance-specific actions',
    (tester) async {
      final store = InMemoryEventStore();
      store.append(
        buildTestReportGenerated(
          eventId: 'RPT-LIVE-TARGET-GOV-1',
          occurredAt: _clientReportsPreviewOccurredAtUtc(40),
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
              previewReceiptEventId: 'RPT-LIVE-TARGET-GOV-1',
              entryContext: ReportEntryContext.governanceBrandingDrift,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OPEN GOVERNANCE PREVIEW DOCK'), findsOneWidget);
      expect(find.text('Copy Governance Receipt'), findsOneWidget);
      expect(find.text('Clear Governance Target'), findsOneWidget);
    },
  );

  testWidgets(
    'client reports governance receipt rows show governance-specific actions',
    (tester) async {
      final store = InMemoryEventStore();
      store.append(
        buildTestReportGenerated(
          eventId: 'RPT-LIVE-ROW-GOV-1',
          occurredAt: _clientReportsPreviewOccurredAtUtc(40),
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
              entryContext: ReportEntryContext.governanceBrandingDrift,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Governance Preview'), findsWidgets);
      expect(find.text('Governance Copy'), findsWidgets);
      expect(find.text('Governance Download'), findsWidgets);
    },
  );

  testWidgets(
    'client reports governance receipt copy feedback uses governance wording',
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

      final store = InMemoryEventStore();
      store.append(
        buildTestReportGenerated(
          eventId: 'RPT-GOV-COPY-1',
          occurredAt: _clientReportsPreviewOccurredAtUtc(40),
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
              entryContext: ReportEntryContext.governanceBrandingDrift,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final copyButton = find.byKey(
        const ValueKey('report-receipt-copy-RPT-GOV-COPY-1'),
      );
      await tester.ensureVisible(copyButton);
      await tester.tap(copyButton);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Governance receipt export copied for command review: RPT-GOV-COPY-1.',
        ),
        findsWidgets,
      );
      expect(
        clipboardText,
        contains('"exportModeLabel": "GOVERNANCE HANDOFF"'),
      );
    },
  );

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
        occurredAt: _clientReportsPreviewOccurredAtUtc(40),
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
      find.textContaining(
        'Receipt export copied for command review: RPT-LIVE-TARGET-COPY-1.',
      ),
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
        reportTestSuppressedDecisionSummary,
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
        find.textContaining(reportTestSuppressedDecisionSummary),
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
        occurredAt: _clientReportsPreviewOccurredAtUtc(30),
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

    final reviewAction = find.text('OPEN PREVIEW TARGET').first;
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
        occurredAt: _clientReportsPreviewOccurredAtUtc(30),
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
            entryContext: ReportEntryContext.governanceBrandingDrift,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final copyAction = find.byKey(
      const ValueKey('reports-selected-copy-button'),
    );
    await tester.ensureVisible(copyAction);
    await tester.tap(copyAction);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Governance receipt export copied for command review: RPT-LIVE-LANE-COPY-1.',
      ),
      findsWidgets,
    );
    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('"context"'));
    expect(clipboardText, contains('"exportModeLabel": "GOVERNANCE HANDOFF"'));
    expect(clipboardText, contains('"receipts"'));
    expect(clipboardText, contains('"eventId": "RPT-LIVE-LANE-COPY-1"'));
    expect(clipboardText, contains('"entryContext": {'));
    expect(clipboardText, contains('"key": "governance_branding_drift"'));
    expect(
      clipboardText,
      contains('"title": "OPENED FROM GOVERNANCE BRANDING DRIFT"'),
    );
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
      expect(find.text('OPEN PREVIEW TARGET'), findsWidgets);

      final reviewAction = find.text('OPEN PREVIEW TARGET').first;
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
        reportTestSuppressedDecisionSummary,
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

      final reviewAction = find.text('OPEN PREVIEW TARGET').first;
      await tester.ensureVisible(reviewAction);
      await tester.tap(reviewAction);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Scene Review Brief'), findsOneWidget);
      expect(find.text('Receipt Integrity'), findsOneWidget);
      expect(find.textContaining(reviewedReceiptEventId), findsWidgets);
      expect(
        find.textContaining(reportTestSuppressedDecisionSummary),
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
          occurredAt: _clientReportsPreviewOccurredAtUtc(5),
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
      reportTestSuppressedDecisionSummary,
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
        find.textContaining(reportTestSuppressedDecisionSummary),
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
      final shellState = ValueNotifier(
        const ReportShellState(includeAiDecisionLog: true),
      );
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

      final previewReportAction = find.byKey(
        const ValueKey('reports-routed-generate-button'),
      );
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
        reportTestSuppressedDecisionSummary,
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
        find.byKey(const ValueKey('report-receipt-preview-RPT-2026-04-07-001')),
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
    'client reports shows tracked section configuration on generated receipts before preview',
    (tester) async {
      final fixture = buildReviewedReportGenerationFixture(
        intelligenceEventId: 'INTEL-GENERATE-CONFIG-1',
        intelligenceId: 'intel-generate-config-1',
      );
      final store = fixture.store;
      final shellState = ValueNotifier(
        const ReportShellState(
          includeAiDecisionLog: false,
          includeGuardMetrics: false,
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

      final previewReportAction = find.byKey(
        const ValueKey('reports-routed-generate-button'),
      );
      await tester.ensureVisible(previewReportAction);
      await tester.tap(previewReportAction);
      await tester.pumpAndSettle();

      final generatedReceipt = store
          .allEvents()
          .whereType<ReportGenerated>()
          .single;
      expect(generatedReceipt.reportSchemaVersion, 3);
      expect(generatedReceipt.investigationContextKey, isEmpty);
      expect(generatedReceipt.includeAiDecisionLog, isFalse);
      expect(generatedReceipt.includeGuardMetrics, isFalse);

      expect(
        find.byKey(
          ValueKey('report-receipt-config-${generatedReceipt.eventId}'),
        ),
        findsOneWidget,
      );
      expect(find.text('Tracked Config'), findsOneWidget);
      expect(find.text('2 Sections Omitted'), findsWidgets);
      expect(
        find.text(
          'Included: Incident Timeline, Dispatch Summary, Checkpoint Compliance. Omitted: AI Decision Log, Guard Metrics.',
        ),
        findsWidgets,
      );
      expect(
        find.text('Preview target: ${generatedReceipt.eventId}'),
        findsOneWidget,
      );
      expect(find.text('2 Sections Omitted'), findsWidgets);
      expect(previewRequests, hasLength(1));
      expect(previewRequests.single.entryContext, isNull);
    },
  );

  testWidgets(
    'client reports stamps branding overrides onto generated receipts',
    (tester) async {
      final fixture = buildReviewedReportGenerationFixture(
        intelligenceEventId: 'INTEL-GENERATE-BRANDING-1',
        intelligenceId: 'intel-generate-branding-1',
      );
      final store = fixture.store;
      final shellState = ValueNotifier(
        const ReportShellState(
          partnerScopeClientId: 'CLIENT-001',
          partnerScopeSiteId: 'SITE-SANDTON',
          partnerScopePartnerLabel: 'PARTNER • Alpha',
          brandingPrimaryLabelOverride: 'VISION Tactical',
          brandingEndorsementLineOverride: 'Intelligence by ONYX',
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

      final previewReportAction = find.byKey(
        const ValueKey('reports-routed-generate-button'),
      );
      await tester.ensureVisible(previewReportAction);
      await tester.tap(previewReportAction);
      await tester.pumpAndSettle();

      final generatedReceipt = store
          .allEvents()
          .whereType<ReportGenerated>()
          .single;
      expect(generatedReceipt.primaryBrandLabel, 'VISION Tactical');
      expect(generatedReceipt.endorsementLine, 'Intelligence by ONYX');
      expect(
        previewRequests.single.bundle.brandingConfiguration.primaryLabel,
        'VISION Tactical',
      );
      expect(
        previewRequests.single.bundle.brandingConfiguration.endorsementLine,
        'Intelligence by ONYX',
      );
    },
  );

  testWidgets('client reports labels legacy receipt configuration in history', (
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

    expect(find.text('Legacy Config'), findsWidgets);
    expect(
      find.text(
        'Legacy receipt. Per-section report configuration was not captured for this generation.',
      ),
      findsWidgets,
    );
  });

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
              includeAiDecisionLog: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final previewReportAction = find.byKey(
        const ValueKey('reports-routed-generate-button'),
      );
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
        find.textContaining(reportTestSuppressedDecisionSummary),
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
