import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/morning_sovereign_report_service.dart';
import 'package:omnix_dashboard/application/mo_promotion_decision_store.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/listener_alarm_advisory_recorded.dart';
import 'package:omnix_dashboard/domain/events/listener_alarm_feed_cycle_recorded.dart';
import 'package:omnix_dashboard/domain/events/listener_alarm_parity_cycle_recorded.dart';
import 'package:omnix_dashboard/domain/events/partner_dispatch_status_declared.dart';
import 'package:omnix_dashboard/domain/events/report_generated.dart';
import 'package:omnix_dashboard/domain/events/vehicle_visit_review_recorded.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/governance_page.dart';

DateTime _governanceReportGeneratedAtUtc(int day) =>
    DateTime.utc(2026, 3, day, 6, 0);

DateTime _governanceNightShiftStartedAtUtc(int day) =>
    DateTime.utc(2026, 3, day, 22, 0);

DateTime _governanceMidnightShiftStartedAtUtc(int day) =>
    DateTime.utc(2026, 3, day, 0, 0);

DateTime _governanceMarch16NightOccurredAtUtc(int minute) =>
    DateTime.utc(2026, 3, 16, 22, minute);

DateTime _governanceMarch10OccurredAtUtc(int hour, int minute) =>
    DateTime.utc(2026, 3, 10, hour, minute);

DateTime _governanceMarch14OccurredAtUtc(int hour, int minute) =>
    DateTime.utc(2026, 3, 14, hour, minute);

DateTime _governanceMarch15OccurredAtUtc(int hour, int minute) =>
    DateTime.utc(2026, 3, 15, hour, minute);

DateTime _governanceMarch16OccurredAtUtc(int hour, int minute) =>
    DateTime.utc(2026, 3, 16, hour, minute);

DateTime _governanceMarch17OccurredAtUtc(int hour, int minute) =>
    DateTime.utc(2026, 3, 17, hour, minute);

DateTime _governanceMarch9OccurredAtUtc(int hour, int minute) =>
    DateTime.utc(2026, 3, 9, hour, minute);

const String _governanceFilteredPatternSummary =
    '2026-03-10T01:10:00.000Z • Camera 2 • Vehicle remained below escalation threshold.';

const String _governanceLatestActionSummary =
    '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line.';

const String _governanceRecentActionsSummary =
    '2026-03-10T00:30:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary line. (+1 more)';

const String _governanceActionMixSummary =
    '2 alerts • 2 repeat updates • 2 escalations • 1 suppressed review';

const String _governanceShadowHistoryHeadline = 'STABLE • 2d';

const String _governanceShadowHistorySummary =
    'Current matches 0 • Baseline 0.0 • Shadow-MO match pressure is holding close to the recent baseline.';

const String _governanceReceiptPolicyHeadline =
    '1 generated reports omitted sections';

const String _governanceReceiptPolicySummaryLine =
    'Reports 2 • Tracked 1 • Legacy 1 • Full 0 • Omitted 1 • AI log omitted 1 • Guard metrics omitted 1';

const String _governanceReceiptPolicyBrandingSummaryLine =
    'Reports 2 • Tracked 1 • Legacy 1 • Full 0 • Omitted 1 • AI log omitted 1 • Guard metrics omitted 1 • Standard branding 1 • Default partner branding 0 • Custom branding 1';

const String _governanceReceiptPolicyLatestReportSummary =
    'CLIENT-1/SITE-42 2026-03 omitted AI Decision Log, Guard Metrics.';

const String _governanceReceiptPolicyExecutiveSummary =
    '1 client-facing receipt omitted sections • 1 legacy receipt lacked tracked policy';

const String _governanceReceiptPolicyBrandingExecutiveSummary =
    '1 receipt used custom branding override';

const String _governanceReceiptPolicyInvestigationExecutiveSummary =
    '1 receipt investigation came from Governance branding drift • 1 receipt investigation remained routine review';

const String _governanceReceiptPolicyLatestBrandingSummary =
    'CLIENT-1/SITE-42 2026-03 used custom branding override from Partner Alpha.';

const String _governanceReceiptPolicyLatestInvestigationSummary =
    'CLIENT-1/SITE-42 2026-03 remained routine report review.';

const String _governanceSiteActivityExecutiveSummary =
    '3 vehicle signals • 4 person signals • 2 known identity hits • 1 flagged identity signal • 1 long-presence pattern • 1 guard interaction';

const String _governanceSiteActivityRecordedHeadline =
    '7 site-activity signals recorded';

const String _governanceSiteActivitySummaryLine =
    'Signals 7 • Vehicles 3 • People 4 • Known IDs 2 • Unknown 3 • Long presence 1 • Guard interactions 1 • Flagged IDs 1';

const String _governancePartnerPerformanceHeadline =
    '1 strong response • 1 critical response';

const String _governancePartnerCompletedResponseReason =
    'Partner completed response inside targets.';

const String _governancePartnerAllClearReason =
    'Partner reached ALL CLEAR inside target acceptance and on-site windows.';

const String _governancePartnerCancelledReason =
    'Dispatch was cancelled before partner completion.';

const String _governancePartnerWorkflowHeadline =
    '1 partner dispatch reached ALL CLEAR • 1 partner dispatch was CANCELLED';

const String _governancePartnerAllClearWorkflowSummary =
    'ACCEPT -> ON SITE -> ALL CLEAR (LATEST ALL CLEAR)';

const String _governancePartnerCancelledWorkflowSummary =
    'ACCEPT -> CANCELLED (LATEST CANCELLED)';

const String _governancePartnerAlphaScopeLabel =
    'CLIENT-1/SITE-42 • Partner Alpha';

const String _governancePartnerAlphaScoreboardSummary =
    'Dispatches 2 • Strong 1 • On track 0 • Watch 0 • Critical 1 • Avg accept 5.0m • Avg on site 13.0m';

const String _governancePartnerSlaHeadline =
    'Avg accept 5.0m • Avg on site 12.0m';

const String _governancePartnerProgressionSummaryLine =
    'Dispatches 2 • Declarations 5 • Accept 2 • On site 1 • All clear 1 • Cancelled 1';

const String _governancePartnerInProgressWorkflowHeadline =
    '2 partner dispatches in progress';

const String _governancePartnerInProgressSlaHeadline =
    'Avg accept 7.0m • Avg on site 15.0m';

const String _governancePartnerClientWideWorkflowHeadline =
    'Partner Alpha carried both client lanes cleanly.';

const String _governancePartnerClientWidePerformanceHeadline =
    '1 strong response • 1 on track response';

const String _governancePartnerClientWideSummaryLine =
    'Dispatches 3 • Declarations 6';

const String _governancePartnerStrongResponseSummary = '1 strong response';

const String _governancePartnerOnTrackResponseSummary = '1 on track response';

const String _governancePartnerWatchResponseSummary = '1 watch response';

const String _governancePartnerOnSiteReason =
    'Partner is on site and progressing cleanly.';

const String _governancePartnerOnSiteWorkflowSummary =
    'ACCEPT -> ON SITE (LATEST ON SITE)';

const String _governancePartnerWatchReason = 'Partner is slower than target.';

const String _governancePartnerMarch14CancelledScopeSummary =
    'Dispatches 1 • Declarations 2 • Latest CANCELLED @ 2026-03-14T02:12:00.000Z';

const String _governancePartnerMarch14AllClearScopeSummary =
    'Dispatches 1 • Declarations 3 • Latest ALL CLEAR @ 2026-03-14T03:10:00.000Z';

const String _governancePartnerMarch15AllClearScopeSummary =
    'Dispatches 1 • Declarations 3 • Latest ALL CLEAR @ 2026-03-15T01:18:00.000Z';

const String _governancePartnerMarch15CancelledScopeSummary =
    'Dispatches 1 • Declarations 2 • Latest CANCELLED @ 2026-03-15T04:08:00.000Z';

const String _governancePartnerMarch14CriticalScoreboardSummary =
    'Dispatches 1 • Strong 0 • On track 0 • Watch 0 • Critical 1 • Avg accept 12.0m • Avg on site 0.0m';

const String _governancePartnerMarch14StrongScoreboardSummary =
    'Dispatches 1 • Strong 1 • On track 0 • Watch 0 • Critical 0 • Avg accept 6.0m • Avg on site 14.0m';

const String _governancePartnerMarch15StrongScoreboardSummary =
    'Dispatches 1 • Strong 1 • On track 0 • Watch 0 • Critical 0 • Avg accept 4.0m • Avg on site 12.0m';

const String _governancePartnerMarch15CriticalScoreboardSummary =
    'Dispatches 1 • Strong 0 • On track 0 • Watch 0 • Critical 1 • Avg accept 10.0m • Avg on site 0.0m';

const String _governanceContractorOfficeHeadline =
    'Contractors moved floor to floor in office park';

const String _governanceContractorProbeHeadline =
    'Maintenance contractor probing office doors';

const String _governanceContractorProbeSummary =
    'Contractor-like person moved floor to floor and tried several restricted office doors.';

const String _governanceSyntheticDecisionSummary =
    'Likely spoofed service access with abnormal roaming.';

const String _governanceSyntheticReviewSummary =
    'Likely maintenance impersonation moving across office zones.';

const String _governanceVehicleThroughputWorkflowHeadline =
    '15 completed visits reached EXIT • 1 incomplete visit stalled at SERVICE';

const String _governanceVehicleSingleVisitWorkflowHeadline =
    '1 incomplete visit stalled at SERVICE';

const String _governanceVehicleSingleVisitSummaryLine =
    'Visits 1 • Entry 1 • Completed 0 • Active 0 • Incomplete 1 • Unique 1';

const String _governanceVehicleIncompleteReasonLabel = 'Incomplete visit';

const String _governanceVehicleServiceIncompleteWorkflow =
    'ENTRY -> SERVICE (INCOMPLETE)';

const String _governanceVehicleServiceCompletedWorkflow =
    'ENTRY -> SERVICE (COMPLETED)';

const String _governanceVehicleServiceActiveWorkflow =
    'ENTRY -> SERVICE (ACTIVE)';

String _governanceLatestFilteredPatternLabel() =>
    'Latest filtered pattern: $_governanceFilteredPatternSummary';

String _governanceFocusedFilteredPatternLabel() =>
    'Focused filtered pattern • $_governanceFilteredPatternSummary';

String _governanceFilteredPatternDetailLabel() =>
    'Filtered pattern: $_governanceFilteredPatternSummary';

String _governanceFocusedFilteredPatternHeading() =>
    'Focused scene action: Filtered pattern';

String _governanceFocusedFilteredPatternDeckTitle() =>
    'Forensic replay of combat window (22:00-06:00) • Focused Filtered Pattern';

String _governanceFilteredPatternDetailCopiedMessage() =>
    'Filtered pattern detail copied for command review';

String _governanceFilteredPatternCopyJsonLabel() =>
    'Copy Morning JSON (Filtered Pattern)';

String _governanceFilteredPatternCopyCsvLabel() =>
    'Copy Morning CSV (Filtered Pattern)';

String _governanceFilteredPatternDetailCopyLabel() =>
    'Copy Filtered Pattern Detail';

String _governanceFilteredPatternDownloadJsonLabel() =>
    'Download Morning JSON (Filtered Pattern)';

String _governanceFilteredPatternDownloadCsvLabel() =>
    'Download Morning CSV (Filtered Pattern)';

String _governanceFilteredPatternSharePackLabel() =>
    'Share Morning Pack (Filtered Pattern)';

String _governanceFilteredPatternEmailReportLabel() =>
    'Email Morning Report (Filtered Pattern)';

String _governanceLatestActionLabel() =>
    'Latest action taken: $_governanceLatestActionSummary';

String _governanceRecentActionsLabel() =>
    'Recent actions: $_governanceRecentActionsSummary';

String _governanceFocusedRecentActionsLabel() =>
    'Focused recent actions • $_governanceRecentActionsSummary';

String _governanceActionMixLabel() =>
    'Action mix: $_governanceActionMixSummary';

String _governanceFocusedRecentActionsHeading() =>
    'Focused scene action: Recent actions';

String _governanceFocusedRecentActionsDeckTitle() =>
    'Forensic replay of combat window (22:00-06:00) • Focused Recent Actions';

String _governanceRecentActionsDetailCopiedMessage() =>
    'Recent actions detail copied for command review';

String _governanceRecentActionsCopyJsonLabel() =>
    'Copy Morning JSON (Recent Actions)';

String _governanceRecentActionsCopyCsvLabel() =>
    'Copy Morning CSV (Recent Actions)';

String _governanceRecentActionsDetailCopyLabel() =>
    'Copy Recent Actions Detail';

String _governanceRecentActionsDownloadJsonLabel() =>
    'Download Morning JSON (Recent Actions)';

String _governanceRecentActionsDownloadCsvLabel() =>
    'Download Morning CSV (Recent Actions)';

String _governanceRecentActionsSharePackLabel() =>
    'Share Morning Pack (Recent Actions)';

String _governanceRecentActionsEmailReportLabel() =>
    'Email Morning Report (Recent Actions)';

String _governancePartnerAllClearScorecardLabel() =>
    'Scorecard: $_governancePartnerAllClearReason';

String _governanceHistoricalShiftLabel() => 'Historical Shift 2026-03-09';

String _governanceHistoricalShiftSharePackLabel() =>
    'Share Morning Pack (${_governanceHistoricalShiftLabel()})';

String _governanceHistoricalShiftEmailReportLabel() =>
    'Email Morning Report (${_governanceHistoricalShiftLabel()})';

String _governanceHistoricalShiftDownloadJsonLabel() =>
    'Download Morning JSON (${_governanceHistoricalShiftLabel()})';

String _governanceHistoricalShiftDownloadCsvLabel() =>
    'Download Morning CSV (${_governanceHistoricalShiftLabel()})';

String _governanceHistoricalShiftCopyJsonLabel() =>
    'Copy Morning JSON (${_governanceHistoricalShiftLabel()})';

String _governanceHistoricalShiftCopyCsvLabel() =>
    'Copy Morning CSV (${_governanceHistoricalShiftLabel()})';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const promotionDecisionStore = MoPromotionDecisionStore();

  void expectTextButtonDisabled(WidgetTester tester, String label) {
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, label),
    );
    expect(button.onPressed, isNull, reason: '$label should be disabled');
  }

  setUp(() {
    promotionDecisionStore.reset();
  });

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

    expect(find.text('READINESS BLOCKERS'), findsOneWidget);
    expect(find.text('COMPLIANCE SUMMARY'), findsOneWidget);
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

    expect(find.text('READINESS BLOCKERS'), findsOneWidget);
    expect(find.text('COMPLIANCE SUMMARY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('governance page renders live operational feeds when available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const <DispatchEvent>[],
          operationalFeedsLoader: () async => GovernanceOperationalFeeds(
            complianceAvailable: true,
            compliance: <GovernanceComplianceIssueFeed>[
              GovernanceComplianceIssueFeed(
                type: 'PSIRA',
                employeeName: 'Guard Alpha',
                employeeId: 'GUARD-001',
                expiryDate: DateTime.utc(2026, 4, 20),
                daysRemaining: 13,
                blockingDispatch: true,
              ),
            ],
            vigilance: const GovernanceVigilanceFeed(
              monitoredScopeCount: 2,
              availableScopeCount: 1,
              degradedScopeCount: 1,
              alertCount: 4,
              escalationCount: 1,
              unresolvedActionCount: 2,
              averageResponseMinutes: 2.5,
              availabilityDetail: '1 of 2 monitored scopes are live.',
            ),
            fleet: const GovernanceFleetStatusFeed(
              activeOfficerCount: 2,
              activeAssignmentCount: 2,
              dispatchQueueDepth: 3,
              failedOperationCount: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pending live feed'), findsNothing);
    expect(find.text('Watch Scopes Live'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Avg Response'), findsOneWidget);
    expect(find.text('2.5m'), findsOneWidget);
    expect(find.text('Queue Depth'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
  });

  testWidgets('governance desktop workspace rail routes command actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 980);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    List<String>? openedEventIds;
    String? openedSelectedEventId;
    String? openedReportsClientId;
    String? openedReportsSiteId;
    String? openedReportsPartnerLabel;
    String? openedLedgerClientId;
    String? openedLedgerSiteId;
    var generatedReportCount = 0;
    final focusChanges = <GovernanceSceneActionFocus?>[];

    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
        headline: _governanceReceiptPolicyHeadline,
        summaryLine: _governanceReceiptPolicySummaryLine,
        latestReportSummary: _governanceReceiptPolicyLatestReportSummary,
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
        actionMixSummary: _governanceActionMixSummary,
        latestActionTaken: _governanceLatestActionSummary,
        recentActionsSummary: _governanceRecentActionsSummary,
        latestSuppressedPattern: _governanceFilteredPatternSummary,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: <DispatchEvent>[
            IntelligenceReceived(
              eventId: 'evt-workspace-1',
              sequence: 1,
              version: 1,
              occurredAt: _governanceNightShiftStartedAtUtc(16),
              intelligenceId: 'intel-workspace-1',
              provider: 'hikvision_dvr_monitor_only',
              sourceType: 'dvr',
              externalId: 'ext-workspace-1',
              clientId: 'CLIENT-1',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-42',
              cameraId: 'gate-cam',
              objectLabel: 'person',
              objectConfidence: 0.95,
              headline: 'Scoped workspace event',
              summary: 'Scoped site event',
              riskScore: 92,
              snapshotUrl: 'https://edge.example.com/intel-workspace-1.jpg',
              canonicalHash: 'hash-workspace-1',
            ),
          ],
          morningSovereignReport: report,
          initialScopeClientId: 'CLIENT-1',
          initialScopeSiteId: 'SITE-42',
          onOpenEventsForScope: (eventIds, selectedEventId, {originLabel = ''}) {
            openedEventIds = eventIds;
            openedSelectedEventId = selectedEventId;
          },
          onOpenReportsForPartnerScope: (clientId, siteId, partnerLabel) {
            openedReportsClientId = clientId;
            openedReportsSiteId = siteId;
            openedReportsPartnerLabel = partnerLabel;
          },
          onOpenLedgerForScope: (clientId, siteId) {
            openedLedgerClientId = clientId;
            openedLedgerSiteId = siteId;
          },
          onGenerateMorningSovereignReport: () async {
            generatedReportCount += 1;
          },
          onSceneActionFocusChanged: focusChanges.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('governance-workspace-panel-rail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('governance-workspace-panel-board')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('governance-workspace-panel-context')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('governance-command-receipt')),
      findsOneWidget,
    );
    expect(find.text('Board ready'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-view-events-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-view-events-button')),
    );
    await tester.pumpAndSettle();
    expect(openedEventIds, ['evt-workspace-1']);
    expect(openedSelectedEventId, 'evt-workspace-1');
    expect(find.text('Events scope opened'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-quick-view-reports-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-quick-view-reports-button')),
    );
    await tester.pumpAndSettle();
    expect(openedReportsClientId, 'CLIENT-1');
    expect(openedReportsSiteId, 'SITE-42');
    expect(openedReportsPartnerLabel, 'ONYX');
    expect(find.text('Reports workspace opened'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('governance-quick-view-ledger-button')),
    );
    await tester.pumpAndSettle();
    expect(openedLedgerClientId, 'CLIENT-1');
    expect(openedLedgerSiteId, 'SITE-42');
    expect(find.text('Sovereign ledger opened'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-generate-report-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-generate-report-button')),
    );
    await tester.pumpAndSettle();
    expect(generatedReportCount, 1);
    expect(find.text('Morning report generated'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('governance-workspace-focus-latest-action')),
    );
    await tester.pumpAndSettle();
    expect(focusChanges.last, GovernanceSceneActionFocus.latestAction);

    await tester.tap(
      find.byKey(const ValueKey('governance-workspace-clear-focus')),
    );
    await tester.pumpAndSettle();
    expect(focusChanges.last, isNull);
  });

  testWidgets('governance desktop recovery decks keep empty scope actionable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 980);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var reportsOpenCount = 0;
    String? openedReportsClientId;
    String? openedReportsSiteId;
    var generatedReportCount = 0;

    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 12,
        hashVerified: true,
        integrityScore: 99,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 4,
        humanOverrides: 0,
        overrideReasons: <String, int>{},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 2,
        driftDetected: 0,
        avgMatchScore: 96,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 0,
        pdpExpired: 0,
        totalBlocked: 0,
      ),
      receiptPolicy: const SovereignReportReceiptPolicy(
        generatedReports: 0,
        trackedConfigurationReports: 0,
        legacyConfigurationReports: 0,
        fullyIncludedReports: 0,
        reportsWithOmittedSections: 0,
        omittedAiDecisionLogReports: 0,
        omittedGuardMetricsReports: 0,
        headline: '',
        summaryLine: '',
        latestReportSummary: '',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const <DispatchEvent>[],
          morningSovereignReport: report,
          initialScopeClientId: 'CLIENT-1',
          initialScopeSiteId: 'SITE-42',
          onOpenReportsForScope: (clientId, siteId) {
            reportsOpenCount += 1;
            openedReportsClientId = clientId;
            openedReportsSiteId = siteId;
          },
          onGenerateMorningSovereignReport: () async {
            generatedReportCount += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RECOVER EVENTS SCOPE'), findsWidgets);
    expect(find.text('RECOVER SOVEREIGN LEDGER'), findsWidgets);
    expect(find.text('RECEIPT SUMMARY PENDING'), findsOneWidget);
    expect(find.text('EVENT TRAIL AWAITING NEW SIGNALS'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-quick-view-events-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-quick-view-events-button')),
    );
    await tester.pumpAndSettle();

    expect(reportsOpenCount, 1);
    expect(openedReportsClientId, 'CLIENT-1');
    expect(openedReportsSiteId, 'SITE-42');
    expect(find.text('Reports workspace opened'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-quick-view-ledger-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-quick-view-ledger-button')),
    );
    await tester.pumpAndSettle();

    expect(reportsOpenCount, 2);

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-context-events-open-reports')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-context-events-open-reports')),
    );
    await tester.pumpAndSettle();

    expect(reportsOpenCount, 3);

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-context-receipt-refresh-report')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-context-receipt-refresh-report')),
    );
    await tester.pumpAndSettle();

    expect(generatedReportCount, 1);
    expect(find.text('Morning report generated'), findsOneWidget);
  });

  testWidgets(
    'governance empty partner chain surface routes scoped recovery actions',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 980);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      List<String>? openedEventIds;
      String? openedSelectedEventId;
      String? openedReportsClientId;
      String? openedReportsSiteId;
      String? openedLedgerClientId;
      String? openedLedgerSiteId;

      await tester.pumpWidget(
        MaterialApp(
          home: GovernancePage(
            events: <DispatchEvent>[
              IntelligenceReceived(
                eventId: 'evt-partner-empty-1',
                sequence: 1,
                version: 1,
                occurredAt: _governanceNightShiftStartedAtUtc(16),
                intelligenceId: 'intel-partner-empty-1',
                provider: 'hikvision_dvr_monitor_only',
                sourceType: 'dvr',
                externalId: 'ext-partner-empty-1',
                clientId: 'CLIENT-1',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-42',
                cameraId: 'gate-cam',
                objectLabel: 'person',
                objectConfidence: 0.95,
                headline: 'Scoped event',
                summary: 'Scoped site event',
                riskScore: 92,
                snapshotUrl:
                    'https://edge.example.com/intel-partner-empty-1.jpg',
                canonicalHash: 'hash-partner-empty-1',
              ),
            ],
            morningSovereignReport: SovereignReport(
              date: '2026-03-10',
              generatedAtUtc: _governanceReportGeneratedAtUtc(10),
              shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
              shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 40,
                hashVerified: true,
                integrityScore: 98,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 8,
                humanOverrides: 1,
                overrideReasons: {'FALSE_ALARM': 1},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 4,
                driftDetected: 1,
                avgMatchScore: 88,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
              partnerProgression: const SovereignReportPartnerProgression(
                dispatchCount: 0,
                declarationCount: 0,
                acceptedCount: 0,
                onSiteCount: 0,
                allClearCount: 0,
                cancelledCount: 0,
                workflowHeadline: 'No partner dispatches in progress',
                performanceHeadline: 'Awaiting next escalation',
                slaHeadline: 'No partner handoff timing available',
                summaryLine: 'Dispatches 0 • Declarations 0',
                scopeBreakdowns: <SovereignReportPartnerScopeBreakdown>[],
                scoreboardRows: <SovereignReportPartnerScoreboardRow>[],
                dispatchChains: <SovereignReportPartnerDispatchChain>[],
              ),
            ),
            initialScopeClientId: 'CLIENT-1',
            initialScopeSiteId: 'SITE-42',
            onOpenEventsForScope: (eventIds, selectedEventId, {originLabel = ''}) {
              openedEventIds = eventIds;
              openedSelectedEventId = selectedEventId;
            },
            onOpenReportsForScope: (clientId, siteId) {
              openedReportsClientId = clientId;
              openedReportsSiteId = siteId;
            },
            onOpenLedgerForScope: (clientId, siteId) {
              openedLedgerClientId = clientId;
              openedLedgerSiteId = siteId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No active partner handoffs'), findsOneWidget);
      expect(
        find.textContaining('scoped recovery actions below'),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('governance-partner-empty-open-events')),
      );
      await tester.tap(
        find.byKey(const ValueKey('governance-partner-empty-open-events')),
      );
      await tester.pumpAndSettle();

      expect(openedEventIds, equals(const ['evt-partner-empty-1']));
      expect(openedSelectedEventId, 'evt-partner-empty-1');
      expect(find.text('Events scope opened'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('governance-partner-empty-open-reports')),
      );
      await tester.pumpAndSettle();

      expect(openedReportsClientId, 'CLIENT-1');
      expect(openedReportsSiteId, 'SITE-42');
      expect(find.text('Reports workspace opened'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('governance-partner-empty-open-ledger')),
      );
      await tester.pumpAndSettle();

      expect(openedLedgerClientId, 'CLIENT-1');
      expect(openedLedgerSiteId, 'SITE-42');
      expect(find.text('Sovereign ledger opened'), findsOneWidget);
    },
  );

  testWidgets('governance header view events opens the scoped event review', (
    tester,
  ) async {
    List<String>? openedEventIds;
    String? openedSelectedEventId;

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: <DispatchEvent>[
            IntelligenceReceived(
              eventId: 'evt-scope-1',
              sequence: 1,
              version: 1,
              occurredAt: _governanceNightShiftStartedAtUtc(16),
              intelligenceId: 'intel-scope-1',
              provider: 'hikvision_dvr_monitor_only',
              sourceType: 'dvr',
              externalId: 'ext-scope-1',
              clientId: 'CLIENT-VALLEE',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-VALLEE',
              cameraId: 'gate-cam',
              objectLabel: 'person',
              objectConfidence: 0.95,
              headline: 'Scoped event',
              summary: 'Scoped site event',
              riskScore: 92,
              snapshotUrl: 'https://edge.example.com/intel-scope-1.jpg',
              canonicalHash: 'hash-scope-1',
            ),
            IntelligenceReceived(
              eventId: 'evt-other-1',
              sequence: 1,
              version: 1,
              occurredAt: _governanceMarch16NightOccurredAtUtc(5),
              intelligenceId: 'intel-other-1',
              provider: 'hikvision_dvr_monitor_only',
              sourceType: 'dvr',
              externalId: 'ext-other-1',
              clientId: 'CLIENT-WATERFALL',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-WATERFALL',
              cameraId: 'entry-cam',
              objectLabel: 'vehicle',
              objectConfidence: 0.88,
              headline: 'Off-scope event',
              summary: 'Other site event',
              riskScore: 61,
              snapshotUrl: 'https://edge.example.com/intel-other-1.jpg',
              canonicalHash: 'hash-other-1',
            ),
          ],
          initialScopeClientId: 'CLIENT-VALLEE',
          initialScopeSiteId: 'SITE-VALLEE',
          onOpenEventsForScope: (eventIds, selectedEventId, {originLabel = ''}) {
            openedEventIds = eventIds;
            openedSelectedEventId = selectedEventId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('governance-view-events-button')),
    );
    await tester.pumpAndSettle();

    expect(openedEventIds, ['evt-scope-1']);
    expect(openedSelectedEventId, 'evt-scope-1');
  });

  testWidgets('governance quick actions open ledger for the scoped view', (
    tester,
  ) async {
    String? openedClientId;
    String? openedSiteId;

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: <DispatchEvent>[
            IntelligenceReceived(
              eventId: 'evt-ledger-1',
              sequence: 1,
              version: 1,
              occurredAt: _governanceNightShiftStartedAtUtc(16),
              intelligenceId: 'intel-ledger-1',
              provider: 'hikvision_dvr_monitor_only',
              sourceType: 'dvr',
              externalId: 'ext-ledger-1',
              clientId: 'CLIENT-VALLEE',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-VALLEE',
              cameraId: 'gate-cam',
              objectLabel: 'person',
              objectConfidence: 0.95,
              headline: 'Scoped ledger event',
              summary: 'Scoped site event',
              riskScore: 92,
              snapshotUrl: 'https://edge.example.com/intel-ledger-1.jpg',
              canonicalHash: 'hash-ledger-1',
            ),
          ],
          initialScopeClientId: 'CLIENT-VALLEE',
          initialScopeSiteId: 'SITE-VALLEE',
          onOpenLedgerForScope: (clientId, siteId) {
            openedClientId = clientId;
            openedSiteId = siteId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-quick-view-ledger-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-quick-view-ledger-button')),
    );
    await tester.pumpAndSettle();

    expect(openedClientId, 'CLIENT-VALLEE');
    expect(openedSiteId, 'SITE-VALLEE');
  });

  testWidgets('governance readiness blockers resolve in place', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const <DispatchEvent>[],
          initialOperationalFeeds: GovernanceOperationalFeeds(
            complianceAvailable: true,
            compliance: <GovernanceComplianceIssueFeed>[
              GovernanceComplianceIssueFeed(
                type: 'PSIRA',
                employeeName: 'Guard Alpha',
                employeeId: 'GUARD-001',
                expiryDate: DateTime.utc(2026, 4, 20),
                daysRemaining: 13,
                blockingDispatch: true,
              ),
              GovernanceComplianceIssueFeed(
                type: 'Medical',
                employeeName: 'Guard Bravo',
                employeeId: 'GUARD-002',
                expiryDate: DateTime.utc(2026, 4, 18),
                daysRemaining: 11,
                blockingDispatch: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final resolveButtons = find.widgetWithText(TextButton, 'Resolve');
    expect(resolveButtons, findsNWidgets(2));

    await tester.ensureVisible(resolveButtons.first);
    final resolveButton = tester.widget<TextButton>(resolveButtons.first);
    resolveButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(find.text('Resolve'), findsOneWidget);
  });

  testWidgets('governance readiness detail opens scoped events review', (
    tester,
  ) async {
    List<String>? openedEventIds;
    String? openedSelectedEventId;

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: <DispatchEvent>[
            IntelligenceReceived(
              eventId: 'evt-readiness-1',
              sequence: 1,
              version: 1,
              occurredAt: _governanceNightShiftStartedAtUtc(16),
              intelligenceId: 'intel-readiness-1',
              provider: 'hikvision_dvr_monitor_only',
              sourceType: 'dvr',
              externalId: 'ext-readiness-1',
              clientId: 'CLIENT-VALLEE',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-VALLEE',
              cameraId: 'gate-cam',
              objectLabel: 'person',
              objectConfidence: 0.95,
              headline: 'Scoped readiness event',
              summary: 'Scoped site event',
              riskScore: 92,
              snapshotUrl: 'https://edge.example.com/intel-readiness-1.jpg',
              canonicalHash: 'hash-readiness-1',
            ),
          ],
          initialScopeClientId: 'CLIENT-VALLEE',
          initialScopeSiteId: 'SITE-VALLEE',
          onOpenEventsForScope: (eventIds, selectedEventId, {originLabel = ''}) {
            openedEventIds = eventIds;
            openedSelectedEventId = selectedEventId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('View Readiness Detail'));
    await tester.tap(find.text('View Readiness Detail'));
    await tester.pumpAndSettle();

    expect(openedEventIds, <String>['evt-readiness-1']);
    expect(openedSelectedEventId, 'evt-readiness-1');
  });

  testWidgets(
    'governance page shows global readiness metric from scene reviews',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GovernancePage(
            events: <DispatchEvent>[
              IntelligenceReceived(
                eventId: 'evt-1',
                sequence: 1,
                version: 1,
                occurredAt: _governanceNightShiftStartedAtUtc(16),
                intelligenceId: 'intel-1',
                provider: 'hikvision_dvr_monitor_only',
                sourceType: 'dvr',
                externalId: 'ext-1',
                clientId: 'CLIENT-1',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-VALLEE',
                cameraId: 'gate-cam',
                faceMatchId: 'PERSON-44',
                objectLabel: 'person',
                objectConfidence: 0.95,
                headline: 'HIKVISION ALERT',
                summary: 'Boundary activity detected',
                riskScore: 93,
                snapshotUrl: 'https://edge.example.com/intel-1.jpg',
                canonicalHash: 'hash-1',
              ),
            ],
            sceneReviewByIntelligenceId: {
              'intel-1': MonitoringSceneReviewRecord(
                intelligenceId: 'intel-1',
                sourceLabel: 'openai:gpt-5.4-mini',
                postureLabel: 'boundary identity concern',
                decisionLabel: 'Escalation Candidate',
                decisionSummary: 'Escalation posture requires response review.',
                summary: 'Boundary activity at gate.',
                reviewedAtUtc: _governanceMarch16NightOccurredAtUtc(1),
              ),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('governance-metric-global-readiness')),
        findsWidgets,
      );
      expect(find.text('Global Readiness'), findsWidgets);
      expect(
        find.byKey(const ValueKey('governance-metric-synthetic-war-room')),
        findsWidgets,
      );
      expect(find.text('Synthetic War-Room'), findsWidgets);
    },
  );

  testWidgets('governance page includes shadow MO intelligence in readiness', (
    tester,
  ) async {
    String? copiedPayload;
    List<String>? openedEventIds;
    String? openedSelectedEventId;
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
    SovereignReport buildReport({
      required String date,
      required DateTime generatedAtUtc,
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
      );
    }

    final priorReport = buildReport(
      date: '2026-03-16',
      generatedAtUtc: _governanceReportGeneratedAtUtc(16),
    );
    final currentReport = buildReport(
      date: '2026-03-17',
      generatedAtUtc: _governanceReportGeneratedAtUtc(17),
    );
    promotionDecisionStore.accept(
      moId: 'MO-EXT-INTEL-NEWS',
      targetValidationStatus: 'validated',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: <DispatchEvent>[
            IntelligenceReceived(
              eventId: 'evt-news-prior',
              sequence: 1,
              version: 1,
              occurredAt: _governanceMarch16OccurredAtUtc(0, 20),
              intelligenceId: 'intel-news-prior',
              provider: 'news_feed_monitor',
              sourceType: 'news',
              externalId: 'ext-news-prior',
              clientId: 'CLIENT-VALLEE',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-OFFICE',
              cameraId: 'feed-news-prior',
              objectLabel: 'person',
              objectConfidence: 0.7,
              headline: _governanceContractorOfficeHeadline,
              summary:
                  'Suspects posed as maintenance contractors before moving floor to floor through restricted office zones.',
              riskScore: 73,
              snapshotUrl: 'https://edge.example.com/news-office-prior.jpg',
              canonicalHash: 'hash-news-office-prior',
            ),
            IntelligenceReceived(
              eventId: 'evt-office-prior',
              sequence: 1,
              version: 1,
              occurredAt: _governanceMarch16OccurredAtUtc(1, 0),
              intelligenceId: 'intel-office-prior',
              provider: 'hikvision_dvr_monitor_only',
              sourceType: 'dvr',
              externalId: 'ext-office-prior',
              clientId: 'CLIENT-VALLEE',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-OFFICE',
              cameraId: 'office-cam-prior',
              objectLabel: 'person',
              objectConfidence: 0.94,
              headline: _governanceContractorProbeHeadline,
              summary: _governanceContractorProbeSummary,
              riskScore: 84,
              snapshotUrl: 'https://edge.example.com/office-prior.jpg',
              canonicalHash: 'hash-office-prior',
            ),
            IntelligenceReceived(
              eventId: 'evt-news',
              sequence: 1,
              version: 1,
              occurredAt: _governanceMarch17OccurredAtUtc(0, 0),
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
              headline: _governanceContractorOfficeHeadline,
              summary:
                  'Suspects posed as maintenance contractors, moved floor to floor through a business park, and tried several restricted office doors before stealing devices.',
              riskScore: 75,
              snapshotUrl: 'https://edge.example.com/news-office.jpg',
              canonicalHash: 'hash-news-office',
            ),
            IntelligenceReceived(
              eventId: 'evt-office',
              sequence: 2,
              version: 1,
              occurredAt: _governanceMarch17OccurredAtUtc(1, 0),
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
              headline: _governanceContractorProbeHeadline,
              summary: _governanceContractorProbeSummary,
              riskScore: 86,
              snapshotUrl: 'https://edge.example.com/office.jpg',
              canonicalHash: 'hash-office',
            ),
          ],
          sceneReviewByIntelligenceId: {
            'intel-office-prior': MonitoringSceneReviewRecord(
              intelligenceId: 'intel-office-prior',
              sourceLabel: 'openai:gpt-5.4-mini',
              postureLabel: 'service impersonation and roaming concern',
              decisionLabel: 'Escalation Candidate',
              decisionSummary: _governanceSyntheticDecisionSummary,
              summary: _governanceSyntheticReviewSummary,
              reviewedAtUtc: _governanceMarch16OccurredAtUtc(1, 1),
            ),
            'intel-office': MonitoringSceneReviewRecord(
              intelligenceId: 'intel-office',
              sourceLabel: 'openai:gpt-5.4-mini',
              postureLabel: 'service impersonation and roaming concern',
              decisionLabel: 'Escalation Candidate',
              decisionSummary: _governanceSyntheticDecisionSummary,
              summary: _governanceSyntheticReviewSummary,
              reviewedAtUtc: _governanceMarch17OccurredAtUtc(1, 1),
            ),
          },
          morningSovereignReport: currentReport,
          morningSovereignReportHistory: [priorReport],
          onOpenEventsForScope: (eventIds, selectedEventId, {originLabel = ''}) {
            openedEventIds = eventIds;
            openedSelectedEventId = selectedEventId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('shadow $_governanceContractorOfficeHeadline'),
      findsWidgets,
    );
    expect(
      find.textContaining(
        'shadow bias HARDEN ACCESS • SITE-OFFICE • $_governanceContractorOfficeHeadline • x1',
      ),
      findsWidgets,
    );
    expect(
      find.textContaining(
        'tomorrow shadow HARDEN ACCESS • SITE-OFFICE • $_governanceContractorOfficeHeadline • x1',
      ),
      findsWidgets,
    );

    final readinessTrendCard = find.byKey(
      const ValueKey('governance-global-readiness-trend-card'),
    );
    await tester.ensureVisible(readinessTrendCard);
    await tester.tap(readinessTrendCard);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('governance-global-readiness-dialog')),
      findsOneWidget,
    );
    expect(find.text('SHADOW MO INTELLIGENCE'), findsOneWidget);
    expect(find.text('COPY SHADOW JSON'), findsOneWidget);
    expect(find.text(_governanceContractorOfficeHeadline), findsWidgets);
    expect(find.textContaining('Posture weight weight '), findsOneWidget);
    expect(find.textContaining('Strength '), findsWidgets);
    expect(find.textContaining('VALIDATED'), findsWidgets);

    await tester.tap(find.text('COPY SHADOW JSON'));
    await tester.pumpAndSettle();

    expect(copiedPayload, isNotNull);
    expect(copiedPayload, contains('"shadowSiteCount": 1'));
    expect(copiedPayload, contains('"sites": ['));
    expect(
      find.byKey(const ValueKey('governance-global-readiness-shadow-receipt')),
      findsOneWidget,
    );
    expect(find.text('Shadow dossier copied'), findsWidgets);

    final openEvidenceButton = find.text('OPEN EVIDENCE').last;
    await tester.ensureVisible(openEvidenceButton);
    await tester.tap(openEvidenceButton);
    await tester.pumpAndSettle();

    expect(openedEventIds, equals(const ['evt-office']));
    expect(openedSelectedEventId, 'evt-office');
  });

  testWidgets('governance page highlights hazard playbook summaries', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: [
            IntelligenceReceived(
              eventId: 'evt-fire',
              sequence: 1,
              version: 1,
              occurredAt: _governanceNightShiftStartedAtUtc(16),
              intelligenceId: 'intel-fire',
              provider: 'hikvision_dvr_monitor_only',
              sourceType: 'dvr',
              externalId: 'ext-fire',
              clientId: 'CLIENT-1',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-VALLEE',
              cameraId: 'generator-room-cam',
              objectLabel: 'smoke',
              objectConfidence: 0.95,
              headline: 'HIKVISION FIRE ALERT',
              summary: 'Smoke visible in the generator room.',
              riskScore: 93,
              snapshotUrl: 'https://edge.example.com/intel-fire.jpg',
              canonicalHash: 'hash-fire',
            ),
          ],
          sceneReviewByIntelligenceId: {
            'intel-fire': MonitoringSceneReviewRecord(
              intelligenceId: 'intel-fire',
              sourceLabel: 'openai:gpt-5.4-mini',
              postureLabel: 'fire and smoke emergency',
              decisionLabel: 'Escalation Candidate',
              decisionSummary:
                  'Escalation posture requires fire response review.',
              summary: 'Smoke plume visible inside the generator room.',
              reviewedAtUtc: _governanceMarch16NightOccurredAtUtc(1),
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('fire playbook active'), findsWidgets);
    expect(find.textContaining('fire rehearsal recommended'), findsWidgets);
  });

  testWidgets('governance page highlights historical readiness focus mode', (
    tester,
  ) async {
    SovereignReport buildReport({
      required String date,
      required DateTime generatedAtUtc,
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
      );
    }

    final currentReport = buildReport(
      date: '2026-03-10',
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
    );
    final focusedReport = buildReport(
      date: '2026-03-09',
      generatedAtUtc: _governanceReportGeneratedAtUtc(9),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const <DispatchEvent>[],
          morningSovereignReport: focusedReport,
          morningSovereignReportHistory: [currentReport],
          currentMorningSovereignReportDate: '2026-03-10',
          initialReportFocusDate: '2026-03-09',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('governance-report-focus-banner')),
      findsOneWidget,
    );
    expect(find.text('Historical readiness focus active'), findsOneWidget);
    expect(
      find.text(
        'Viewing command-targeted shift 2026-03-09 instead of live oversight 2026-03-10.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(_governanceHistoricalShiftSharePackLabel()),
      findsOneWidget,
    );
    expect(
      find.text(_governanceHistoricalShiftEmailReportLabel()),
      findsOneWidget,
    );
    expect(
      find.text(_governanceHistoricalShiftDownloadJsonLabel()),
      findsOneWidget,
    );
    expect(
      find.text(_governanceHistoricalShiftDownloadCsvLabel()),
      findsOneWidget,
    );
    expect(
      find.text(_governanceHistoricalShiftCopyJsonLabel()),
      findsOneWidget,
    );
    expect(find.text(_governanceHistoricalShiftCopyCsvLabel()), findsOneWidget);
  });

  testWidgets('governance page shows global readiness drift and drill-in', (
    tester,
  ) async {
    SovereignReport buildReport({
      required String date,
      required DateTime generatedAtUtc,
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
      );
    }

    final priorReport = buildReport(
      date: '2026-03-09',
      generatedAtUtc: _governanceReportGeneratedAtUtc(9),
    );
    final currentReport = buildReport(
      date: '2026-03-10',
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
    );

    final events = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'evt-prior',
        sequence: 1,
        version: 1,
        occurredAt: _governanceMarch9OccurredAtUtc(1, 0),
        intelligenceId: 'intel-prior',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-prior',
        clientId: 'CLIENT-1',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-VALLEE',
        cameraId: 'gate-cam',
        objectLabel: 'person',
        objectConfidence: 0.71,
        headline: 'Prior watch',
        summary: 'Routine watch posture only.',
        riskScore: 34,
        snapshotUrl: 'https://edge.example.com/prior.jpg',
        canonicalHash: 'hash-prior',
      ),
      IntelligenceReceived(
        eventId: 'evt-current-1',
        sequence: 1,
        version: 1,
        occurredAt: _governanceMarch10OccurredAtUtc(1, 0),
        intelligenceId: 'intel-current-1',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-current-1',
        clientId: 'CLIENT-1',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-VALLEE',
        cameraId: 'gate-cam',
        faceMatchId: 'PERSON-44',
        objectLabel: 'person',
        objectConfidence: 0.95,
        headline: 'Current escalation',
        summary: 'Boundary activity detected.',
        riskScore: 92,
        snapshotUrl: 'https://edge.example.com/current-1.jpg',
        canonicalHash: 'hash-current-1',
      ),
      IntelligenceReceived(
        eventId: 'evt-current-2',
        sequence: 1,
        version: 1,
        occurredAt: _governanceMarch10OccurredAtUtc(1, 10),
        intelligenceId: 'intel-current-2',
        provider: 'community-feed',
        sourceType: 'community',
        externalId: 'ext-current-2',
        clientId: 'CLIENT-2',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        cameraId: 'community-feed',
        objectLabel: 'vehicle',
        objectConfidence: 0.8,
        headline: 'Neighborhood watch alert',
        summary: 'Suspicious vehicle circling nearby estates.',
        riskScore: 76,
        snapshotUrl: 'https://edge.example.com/current-2.jpg',
        canonicalHash: 'hash-current-2',
      ),
    ];

    final reviews = <String, MonitoringSceneReviewRecord>{
      'intel-prior': MonitoringSceneReviewRecord(
        intelligenceId: 'intel-prior',
        sourceLabel: 'openai:gpt-5.4-mini',
        postureLabel: 'monitored movement',
        decisionLabel: 'Suppressed',
        decisionSummary: 'Routine monitored movement only.',
        summary: 'No escalation needed.',
        reviewedAtUtc: _governanceMarch9OccurredAtUtc(1, 1),
      ),
      'intel-current-1': MonitoringSceneReviewRecord(
        intelligenceId: 'intel-current-1',
        sourceLabel: 'openai:gpt-5.4-mini',
        postureLabel: 'boundary identity concern',
        decisionLabel: 'Escalation Candidate',
        decisionSummary: 'Escalation posture requires response review.',
        summary: 'Boundary activity at gate.',
        reviewedAtUtc: _governanceMarch10OccurredAtUtc(1, 1),
      ),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: events,
          sceneReviewByIntelligenceId: reviews,
          morningSovereignReport: currentReport,
          morningSovereignReportHistory: [priorReport],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Global readiness drift (7 days)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('governance-global-readiness-trend-card')),
      findsOneWidget,
    );
    expect(find.text('CRITICAL POSTURE'), findsWidgets);
    expect(find.text('SLIPPING'), findsWidgets);
    expect(find.text('Current Critical: 1'), findsOneWidget);
    expect(find.text('Current Elevated: 1'), findsOneWidget);
    expect(find.text('Baseline Critical: 0.0'), findsOneWidget);
    expect(find.text('Baseline Elevated: 0.0'), findsOneWidget);
    expect(
      find.textContaining(
        'Critical and elevated site pressure increased against recent shifts.',
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-global-readiness-trend-card')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('governance-global-readiness-trend-card')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('governance-global-readiness-dialog')),
      findsOneWidget,
    );
    expect(find.text('GLOBAL READINESS DRILL-IN'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('governance-global-readiness-history-2026-03-10'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('governance-global-readiness-history-2026-03-09'),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Sites 2 • Critical 1 • Elevated 1 • Intents'),
      findsOneWidget,
    );
  });

  testWidgets('governance page shows site activity truth drift and drill-in', (
    tester,
  ) async {
    SovereignReport buildReport({
      required String date,
      required DateTime generatedAtUtc,
      required SovereignReportSiteActivity siteActivity,
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
        siteActivity: siteActivity,
      );
    }

    final priorReport = buildReport(
      date: '2026-03-09',
      generatedAtUtc: _governanceReportGeneratedAtUtc(9),
      siteActivity: const SovereignReportSiteActivity(
        totalSignals: 2,
        personSignals: 1,
        vehicleSignals: 1,
        knownIdentitySignals: 1,
        flaggedIdentitySignals: 0,
        unknownSignals: 0,
        longPresenceSignals: 0,
        guardInteractionSignals: 0,
        executiveSummary: 'Routine visitor flow only.',
        headline: '2 site activity signals observed',
        summaryLine:
            'Signals 2 • Vehicles 1 • People 1 • Known IDs 1 • Unknown 0 • Long presence 0 • Guard interactions 0 • Flagged IDs 0',
      ),
    );
    final currentReport = buildReport(
      date: '2026-03-10',
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
      siteActivity: const SovereignReportSiteActivity(
        totalSignals: 7,
        personSignals: 4,
        vehicleSignals: 3,
        knownIdentitySignals: 2,
        flaggedIdentitySignals: 1,
        unknownSignals: 3,
        longPresenceSignals: 1,
        guardInteractionSignals: 1,
        executiveSummary:
            'Unknown visitors and flagged identity traffic increased overnight.',
        headline: '7 site activity signals observed',
        summaryLine: _governanceSiteActivitySummaryLine,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const <DispatchEvent>[],
          morningSovereignReport: currentReport,
          morningSovereignReportHistory: [priorReport],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Site activity truth (7 days)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('governance-site-activity-trend-card')),
      findsOneWidget,
    );
    expect(find.text('FLAGGED TRAFFIC'), findsWidgets);
    expect(find.text('RISING'), findsWidgets);
    expect(find.text('Current Signals: 7'), findsOneWidget);
    expect(find.text('Current Unknown: 3'), findsOneWidget);
    expect(find.text('Current Flagged: 1'), findsOneWidget);
    expect(find.text('Baseline Signals: 2.0'), findsOneWidget);
    expect(
      find.textContaining('Flagged identity traffic is pushing'),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-site-activity-trend-card')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('governance-site-activity-trend-card')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('governance-site-activity-dialog')),
      findsOneWidget,
    );
    expect(find.text('SITE ACTIVITY TRUTH DRILL-IN'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('governance-site-activity-history-2026-03-10')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('governance-site-activity-history-2026-03-09')),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Signals 7 • Vehicles 3 • People 4 • Known 2 • Unknown 3 • Flagged 1 • Guard 1',
      ),
      findsOneWidget,
    );
  });

  testWidgets('governance site activity metric opens quiet-state drill-in', (
    tester,
  ) async {
    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
      siteActivity: const SovereignReportSiteActivity(
        totalSignals: 0,
        personSignals: 0,
        vehicleSignals: 0,
        knownIdentitySignals: 0,
        flaggedIdentitySignals: 0,
        unknownSignals: 0,
        longPresenceSignals: 0,
        guardInteractionSignals: 0,
        executiveSummary: '',
        headline: '',
        summaryLine: '',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const <DispatchEvent>[],
          morningSovereignReport: report,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-metric-site-activity')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-metric-site-activity')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('governance-site-activity-dialog')),
      findsOneWidget,
    );
    expect(find.text('SITE ACTIVITY TRUTH DRILL-IN'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('governance-site-activity-history-2026-03-10')),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Signals 0 • Vehicles 0 • People 0 • Known 0 • Unknown 0 • Flagged 0 • Guard 0',
      ),
      findsOneWidget,
    );
  });

  testWidgets('governance vehicle throughput metric opens BI dashboard', (
    tester,
  ) async {
    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
      vehicleThroughput: SovereignReportVehicleThroughput(
        totalVisits: 24,
        entryCount: 24,
        serviceCount: 18,
        exitCount: 16,
        completedVisits: 16,
        activeVisits: 6,
        incompleteVisits: 2,
        uniqueVehicles: 20,
        repeatVehicles: 5,
        unknownVehicleEvents: 1,
        peakHourLabel: '10:00-11:00',
        peakHourVisitCount: 8,
        averageCompletedDwellMinutes: 14.5,
        suspiciousShortVisitCount: 1,
        loiteringVisitCount: 0,
        workflowHeadline: '16 completed visits reached EXIT',
        summaryLine:
            'Visits 24 • Entry 24 • Completed 16 • Active 6 • Incomplete 2 • Unique 20 • Repeat 5',
        hourlyBreakdown: <int, int>{8: 4, 9: 7, 10: 8, 11: 5},
        exceptionVisits: [
          SovereignReportVehicleVisitException(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            vehicleLabel: 'GP 87421',
            statusLabel: 'WATCH',
            reasonLabel: 'After-hours loitering',
            workflowSummary: 'ENTRY -> EXIT LANE (WATCH)',
            primaryEventId: 'INT-GOV-BI-1',
            startedAtUtc: DateTime.utc(2026, 3, 10, 10, 2),
            lastSeenAtUtc: DateTime.utc(2026, 3, 10, 10, 28),
            dwellMinutes: 26,
            zoneLabels: <String>['Delivery Bay', 'Exit Lane'],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const <DispatchEvent>[],
          morningSovereignReport: report,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-metric-vehicle-throughput')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-metric-vehicle-throughput')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('governance-vehicle-bi-dialog')),
      findsOneWidget,
    );
    expect(find.text('VEHICLE BI DASHBOARD'), findsOneWidget);
    expect(find.text('Vehicle BI dashboard'), findsOneWidget);
    expect(find.text('25.0%'), findsOneWidget);
    expect(find.text('Peak hour: 10:00-11:00 • 8 visits'), findsOneWidget);
    expect(find.text('After-hours loitering'), findsOneWidget);
    expect(find.byKey(const ValueKey('vehicle-bi-hour-bar-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('vehicle-bi-peak-badge-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('vehicle-bi-funnel-service')), findsOneWidget);
  });

  testWidgets('governance page shows synthetic war-room drift and drill-in', (
    tester,
  ) async {
    SovereignReport buildReport({
      required String date,
      required DateTime generatedAtUtc,
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
      );
    }

    final priorReport = buildReport(
      date: '2026-03-09',
      generatedAtUtc: _governanceReportGeneratedAtUtc(9),
    );
    final currentReport = buildReport(
      date: '2026-03-10',
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
    );

    final events = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'evt-prior',
        sequence: 1,
        version: 1,
        occurredAt: _governanceMarch9OccurredAtUtc(1, 0),
        intelligenceId: 'intel-prior',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-prior',
        clientId: 'CLIENT-1',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-VALLEE',
        cameraId: 'gate-cam',
        objectLabel: 'person',
        objectConfidence: 0.71,
        headline: 'Prior watch',
        summary: 'Routine watch posture only.',
        riskScore: 34,
        snapshotUrl: 'https://edge.example.com/prior.jpg',
        canonicalHash: 'hash-prior',
      ),
      IntelligenceReceived(
        eventId: 'evt-current-1',
        sequence: 1,
        version: 1,
        occurredAt: _governanceMarch10OccurredAtUtc(1, 0),
        intelligenceId: 'intel-current-1',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-current-1',
        clientId: 'CLIENT-1',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-VALLEE',
        cameraId: 'gate-cam',
        faceMatchId: 'PERSON-44',
        objectLabel: 'person',
        objectConfidence: 0.95,
        headline: 'Current escalation',
        summary: 'Boundary activity detected.',
        riskScore: 92,
        snapshotUrl: 'https://edge.example.com/current-1.jpg',
        canonicalHash: 'hash-current-1',
      ),
      IntelligenceReceived(
        eventId: 'evt-current-2',
        sequence: 1,
        version: 1,
        occurredAt: _governanceMarch10OccurredAtUtc(1, 10),
        intelligenceId: 'intel-current-2',
        provider: 'community-feed',
        sourceType: 'community',
        externalId: 'ext-current-2',
        clientId: 'CLIENT-2',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        cameraId: 'community-feed',
        objectLabel: 'vehicle',
        objectConfidence: 0.8,
        headline: 'Neighborhood watch alert',
        summary: 'Suspicious vehicle circling nearby estates.',
        riskScore: 76,
        snapshotUrl: 'https://edge.example.com/current-2.jpg',
        canonicalHash: 'hash-current-2',
      ),
    ];

    final reviews = <String, MonitoringSceneReviewRecord>{
      'intel-prior': MonitoringSceneReviewRecord(
        intelligenceId: 'intel-prior',
        sourceLabel: 'openai:gpt-5.4-mini',
        postureLabel: 'monitored movement',
        decisionLabel: 'Suppressed',
        decisionSummary: 'Routine monitored movement only.',
        summary: 'No escalation needed.',
        reviewedAtUtc: _governanceMarch9OccurredAtUtc(1, 1),
      ),
      'intel-current-1': MonitoringSceneReviewRecord(
        intelligenceId: 'intel-current-1',
        sourceLabel: 'openai:gpt-5.4-mini',
        postureLabel: 'boundary identity concern',
        decisionLabel: 'Escalation Candidate',
        decisionSummary: 'Escalation posture requires response review.',
        summary: 'Boundary activity at gate.',
        reviewedAtUtc: _governanceMarch10OccurredAtUtc(1, 1),
      ),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: events,
          sceneReviewByIntelligenceId: reviews,
          morningSovereignReport: currentReport,
          morningSovereignReportHistory: [priorReport],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Synthetic war-room drift (7 days)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('governance-synthetic-war-room-trend-card')),
      findsOneWidget,
    );
    expect(find.text('POLICY SHIFT'), findsWidgets);
    expect(find.text('RISING'), findsWidgets);
    expect(find.text('Current Plans: 2'), findsOneWidget);
    expect(find.text('Current Policy: 1'), findsOneWidget);
    expect(find.text('Baseline Plans: 0.0'), findsOneWidget);
    expect(find.text('Baseline Policy: 0.0'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-synthetic-war-room-trend-card')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('governance-synthetic-war-room-trend-card')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('governance-synthetic-war-room-dialog')),
      findsOneWidget,
    );
    expect(find.text('SYNTHETIC WAR-ROOM DRILL-IN'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('governance-synthetic-war-room-history-2026-03-10'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('governance-synthetic-war-room-history-2026-03-09'),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Plans 2 • Policy 1 • Region REGION-GAUTENG • Lead SITE-VALLEE',
      ),
      findsOneWidget,
    );
  });

  testWidgets('governance synthetic history rows show promotion decisions', (
    tester,
  ) async {
    Future<void> pumpSubject() async {
      SovereignReport buildReport({
        required String date,
        required DateTime generatedAtUtc,
      }) {
        return SovereignReport(
          date: date,
          generatedAtUtc: generatedAtUtc,
          shiftWindowStartUtc: generatedAtUtc.subtract(
            const Duration(hours: 8),
          ),
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
        );
      }

      final priorReport = buildReport(
        date: '2026-03-16',
        generatedAtUtc: _governanceReportGeneratedAtUtc(16),
      );
      final currentReport = buildReport(
        date: '2026-03-17',
        generatedAtUtc: _governanceReportGeneratedAtUtc(17),
      );

      final events = <DispatchEvent>[
        IntelligenceReceived(
          eventId: 'evt-prior-news',
          sequence: 1,
          version: 1,
          occurredAt: _governanceMarch16OccurredAtUtc(0, 20),
          intelligenceId: 'intel-prior-news',
          provider: 'newsdesk',
          sourceType: 'news',
          externalId: 'ext-prior-news',
          clientId: 'CLIENT-VALLEE',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          cameraId: 'news-feed',
          objectLabel: 'person',
          objectConfidence: 0.8,
          headline: _governanceContractorOfficeHeadline,
          summary:
              'Suspects posed as maintenance contractors before moving across restricted office zones.',
          riskScore: 89,
          snapshotUrl: 'https://edge.example.com/prior-news.jpg',
          canonicalHash: 'hash-prior-news',
        ),
        IntelligenceReceived(
          eventId: 'evt-prior-live',
          sequence: 2,
          version: 1,
          occurredAt: _governanceMarch16OccurredAtUtc(1, 0),
          intelligenceId: 'intel-prior-live',
          provider: 'hikvision_dvr_monitor_only',
          sourceType: 'dvr',
          externalId: 'ext-prior-live',
          clientId: 'CLIENT-VALLEE',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          cameraId: 'office-cam-prior',
          objectLabel: 'person',
          objectConfidence: 0.94,
          headline: _governanceContractorProbeHeadline,
          summary: _governanceContractorProbeSummary,
          riskScore: 82,
          snapshotUrl: 'https://edge.example.com/prior-live.jpg',
          canonicalHash: 'hash-prior-live',
        ),
        IntelligenceReceived(
          eventId: 'evt-current-news',
          sequence: 1,
          version: 1,
          occurredAt: _governanceMarch17OccurredAtUtc(0, 20),
          intelligenceId: 'intel-current-news',
          provider: 'newsdesk',
          sourceType: 'news',
          externalId: 'ext-current-news',
          clientId: 'CLIENT-VALLEE',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          cameraId: 'news-feed',
          objectLabel: 'person',
          objectConfidence: 0.8,
          headline: _governanceContractorOfficeHeadline,
          summary:
              'Suspects posed as maintenance contractors before moving across restricted office zones.',
          riskScore: 91,
          snapshotUrl: 'https://edge.example.com/current-news.jpg',
          canonicalHash: 'hash-current-news',
        ),
        IntelligenceReceived(
          eventId: 'evt-current-live',
          sequence: 2,
          version: 1,
          occurredAt: _governanceMarch17OccurredAtUtc(1, 0),
          intelligenceId: 'intel-current-live',
          provider: 'hikvision_dvr_monitor_only',
          sourceType: 'dvr',
          externalId: 'ext-current-live',
          clientId: 'CLIENT-VALLEE',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          cameraId: 'office-cam-current',
          objectLabel: 'person',
          objectConfidence: 0.94,
          headline: _governanceContractorProbeHeadline,
          summary: _governanceContractorProbeSummary,
          riskScore: 84,
          snapshotUrl: 'https://edge.example.com/current-live.jpg',
          canonicalHash: 'hash-current-live',
        ),
      ];

      final reviews = <String, MonitoringSceneReviewRecord>{
        'intel-prior-live': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-prior-live',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'service impersonation and roaming concern',
          decisionLabel: 'Escalation Candidate',
          decisionSummary: _governanceSyntheticDecisionSummary,
          summary: _governanceSyntheticReviewSummary,
          reviewedAtUtc: _governanceMarch16OccurredAtUtc(1, 2),
        ),
        'intel-current-live': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-current-live',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'service impersonation and roaming concern',
          decisionLabel: 'Escalation Candidate',
          decisionSummary: _governanceSyntheticDecisionSummary,
          summary: _governanceSyntheticReviewSummary,
          reviewedAtUtc: _governanceMarch17OccurredAtUtc(1, 2),
        ),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: GovernancePage(
            events: events,
            sceneReviewByIntelligenceId: reviews,
            morningSovereignReport: currentReport,
            morningSovereignReportHistory: [priorReport],
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpSubject();

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-synthetic-war-room-trend-card')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-synthetic-war-room-trend-card')),
    );
    await tester.pumpAndSettle();

    final currentHistoryCard = find.byKey(
      const ValueKey('governance-synthetic-war-room-history-2026-03-17'),
    );
    expect(currentHistoryCard, findsOneWidget);
    expect(
      find.descendant(
        of: currentHistoryCard,
        matching: find.textContaining('Promotion • Promote '),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: currentHistoryCard,
        matching: find.textContaining('Shadow validation •'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const ValueKey('governance-synthetic-promotion-accept-action'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: currentHistoryCard,
        matching: find.textContaining('Accepted toward '),
      ),
      findsOneWidget,
    );
  });

  testWidgets('governance page renders persisted morning report metadata', (
    tester,
  ) async {
    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
        executiveSummary: _governanceReceiptPolicyExecutiveSummary,
        brandingExecutiveSummary:
            _governanceReceiptPolicyBrandingExecutiveSummary,
        investigationExecutiveSummary:
            _governanceReceiptPolicyInvestigationExecutiveSummary,
        headline: _governanceReceiptPolicyHeadline,
        summaryLine: _governanceReceiptPolicyBrandingSummaryLine,
        latestReportSummary: _governanceReceiptPolicyLatestReportSummary,
        latestBrandingSummary: _governanceReceiptPolicyLatestBrandingSummary,
        latestInvestigationSummary:
            _governanceReceiptPolicyLatestInvestigationSummary,
      ),
      siteActivity: const SovereignReportSiteActivity(
        totalSignals: 7,
        personSignals: 4,
        vehicleSignals: 3,
        knownIdentitySignals: 2,
        flaggedIdentitySignals: 1,
        unknownSignals: 3,
        longPresenceSignals: 1,
        guardInteractionSignals: 1,
        executiveSummary: _governanceSiteActivityExecutiveSummary,
        headline: _governanceSiteActivityRecordedHeadline,
        summaryLine: _governanceSiteActivitySummaryLine,
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
        actionMixSummary: _governanceActionMixSummary,
        latestActionTaken: _governanceLatestActionSummary,
        recentActionsSummary: _governanceRecentActionsSummary,
        latestSuppressedPattern: _governanceFilteredPatternSummary,
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
        workflowHeadline: _governanceVehicleThroughputWorkflowHeadline,
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
            reasonLabel: _governanceVehicleIncompleteReasonLabel,
            workflowSummary: _governanceVehicleServiceIncompleteWorkflow,
            primaryEventId: 'EVT-201',
            startedAtUtc: _governanceMarch10OccurredAtUtc(0, 40),
            lastSeenAtUtc: _governanceMarch10OccurredAtUtc(1, 22),
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
        workflowHeadline: _governancePartnerWorkflowHeadline,
        performanceHeadline: _governancePartnerPerformanceHeadline,
        slaHeadline: _governancePartnerSlaHeadline,
        summaryLine: _governancePartnerProgressionSummaryLine,
        scopeBreakdowns: [
          SovereignReportPartnerScopeBreakdown(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            dispatchCount: 2,
            declarationCount: 5,
            latestStatus: PartnerDispatchStatus.cancelled,
            latestOccurredAtUtc: _governanceMarch10OccurredAtUtc(2, 18),
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
            summaryLine: _governancePartnerAlphaScoreboardSummary,
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
            latestOccurredAtUtc: _governanceMarch10OccurredAtUtc(1, 55),
            dispatchCreatedAtUtc: _governanceMarch10OccurredAtUtc(1, 35),
            acceptedAtUtc: _governanceMarch10OccurredAtUtc(1, 40),
            onSiteAtUtc: _governanceMarch10OccurredAtUtc(1, 48),
            allClearAtUtc: _governanceMarch10OccurredAtUtc(1, 55),
            acceptedDelayMinutes: 5.0,
            onSiteDelayMinutes: 13.0,
            scoreLabel: 'STRONG',
            scoreReason: _governancePartnerAllClearReason,
            workflowSummary: _governancePartnerAllClearWorkflowSummary,
          ),
          SovereignReportPartnerDispatchChain(
            dispatchId: 'DSP-43',
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            partnerLabel: 'Partner Alpha',
            declarationCount: 2,
            latestStatus: PartnerDispatchStatus.cancelled,
            latestOccurredAtUtc: _governanceMarch10OccurredAtUtc(2, 18),
            dispatchCreatedAtUtc: _governanceMarch10OccurredAtUtc(2, 0),
            acceptedAtUtc: _governanceMarch10OccurredAtUtc(2, 5),
            cancelledAtUtc: _governanceMarch10OccurredAtUtc(2, 18),
            acceptedDelayMinutes: 5.0,
            scoreLabel: 'CRITICAL',
            scoreReason:
                'Dispatch was cancelled before the partner completed the response chain.',
            workflowSummary: _governancePartnerCancelledWorkflowSummary,
          ),
        ],
      ),
    );

    final priorReport = SovereignReport(
      date: '2026-03-09',
      generatedAtUtc: _governanceReportGeneratedAtUtc(9),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(8),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(9),
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
        headline: _governanceReceiptPolicyHeadline,
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
    expect(find.text('Receipt Policy'), findsWidgets);
    expect(find.text('2 reports'), findsWidgets);
    expect(
      find.textContaining(_governanceReceiptPolicyExecutiveSummary),
      findsWidgets,
    );
    expect(
      find.textContaining(_governanceReceiptPolicyBrandingExecutiveSummary),
      findsWidgets,
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
        _governanceReceiptPolicyInvestigationExecutiveSummary,
      ),
      findsWidgets,
    );
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining(_governanceReceiptPolicyLatestReportSummary),
      findsWidgets,
    );
    expect(
      find.textContaining(
        'Model 5 • Alerts 2 • Repeat 2 • Escalations 2 • Top escalation candidate',
      ),
      findsWidgets,
    );
    expect(find.textContaining(_governanceActionMixLabel()), findsWidgets);
    expect(find.textContaining(_governanceLatestActionLabel()), findsOneWidget);
    expect(
      find.textContaining(_governanceRecentActionsLabel()),
      findsOneWidget,
    );
    expect(
      find.textContaining(_governanceLatestFilteredPatternLabel()),
      findsOneWidget,
    );
    expect(find.text('Vehicle Throughput'), findsOneWidget);
    expect(find.text('Partner Progression'), findsWidgets);
    expect(
      find.text(_governanceVehicleThroughputWorkflowHeadline),
      findsOneWidget,
    );
    expect(find.text(_governancePartnerWorkflowHeadline), findsWidgets);
    expect(find.text(_governancePartnerPerformanceHeadline), findsNWidgets(2));
    expect(find.text(_governancePartnerSlaHeadline), findsOneWidget);
    expect(find.text('Vehicle site ledger'), findsOneWidget);
    expect(find.text('Vehicle exception review'), findsOneWidget);
    expect(find.text('Partner dispatch sites'), findsOneWidget);
    expect(find.text('Partner scoreboard'), findsOneWidget);
    expect(find.text('Partner dispatch progression'), findsOneWidget);
    expect(
      find.textContaining(_governancePartnerAlphaScopeLabel),
      findsNWidgets(2),
    );
    expect(find.text(_governancePartnerAlphaScoreboardSummary), findsOneWidget);
    expect(find.textContaining('Partner Alpha • DSP-42'), findsWidgets);
    expect(
      find.text('Workflow: $_governancePartnerAllClearWorkflowSummary'),
      findsWidgets,
    );
    expect(find.text('SLA: accepted in 5.0m • on site in 13.0m'), findsWidgets);
    expect(find.text('STRONG'), findsWidgets);
    expect(find.text(_governancePartnerAllClearScorecardLabel()), findsWidgets);
    expect(find.textContaining('CLIENT-1/SITE-42'), findsWidgets);
    expect(
      find.textContaining(
        '$_governanceVehicleIncompleteReasonLabel • CA123456',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Workflow: $_governanceVehicleServiceIncompleteWorkflow'),
      findsWidgets,
    );
    expect(find.text('Copy Morning JSON'), findsOneWidget);
    expect(find.text('Download Morning CSV'), findsOneWidget);
    expectTextButtonDisabled(tester, 'Download Morning JSON');
    expectTextButtonDisabled(tester, 'Download Morning CSV');
    expectTextButtonDisabled(tester, 'Share Morning Pack');
    expectTextButtonDisabled(tester, 'Email Morning Report');
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
      generatedAtUtc: _governanceReportGeneratedAtUtc(9),
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
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
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
          latestOccurredAtUtc: _governanceMarch10OccurredAtUtc(1, 30),
          dispatchCreatedAtUtc: _governanceMarch10OccurredAtUtc(1, 0),
          acceptedAtUtc: _governanceMarch10OccurredAtUtc(1, 4),
          onSiteAtUtc: _governanceMarch10OccurredAtUtc(1, 10),
          allClearAtUtc: _governanceMarch10OccurredAtUtc(1, 30),
          acceptedDelayMinutes: 4.0,
          onSiteDelayMinutes: 10.0,
          scoreLabel: 'STRONG',
          scoreReason: _governancePartnerAllClearReason,
          workflowSummary: _governancePartnerAllClearWorkflowSummary,
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
      find.text(_governancePartnerAllClearWorkflowSummary),
      findsOneWidget,
    );
  });

  testWidgets('governance receipt policy metric drills into shift receipts', (
    tester,
  ) async {
    String? openedReceiptEventId;
    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
        executiveSummary: _governanceReceiptPolicyExecutiveSummary,
        brandingExecutiveSummary:
            _governanceReceiptPolicyBrandingExecutiveSummary,
        investigationExecutiveSummary:
            _governanceReceiptPolicyInvestigationExecutiveSummary,
        headline: _governanceReceiptPolicyHeadline,
        summaryLine: _governanceReceiptPolicyBrandingSummaryLine,
        latestReportSummary: _governanceReceiptPolicyLatestReportSummary,
        latestBrandingSummary: _governanceReceiptPolicyLatestBrandingSummary,
        latestInvestigationSummary:
            _governanceReceiptPolicyLatestInvestigationSummary,
      ),
      siteActivity: const SovereignReportSiteActivity(
        totalSignals: 7,
        personSignals: 4,
        vehicleSignals: 3,
        knownIdentitySignals: 2,
        flaggedIdentitySignals: 1,
        unknownSignals: 3,
        longPresenceSignals: 1,
        guardInteractionSignals: 1,
        executiveSummary: _governanceSiteActivityExecutiveSummary,
        headline: _governanceSiteActivityRecordedHeadline,
        summaryLine: _governanceSiteActivitySummaryLine,
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
        actionMixSummary: _governanceActionMixSummary,
        latestActionTaken: _governanceLatestActionSummary,
        recentActionsSummary: _governanceRecentActionsSummary,
        latestSuppressedPattern: _governanceFilteredPatternSummary,
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
              occurredAt: _governanceMarch10OccurredAtUtc(2, 20),
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
              occurredAt: _governanceMarch10OccurredAtUtc(2, 40),
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
              occurredAt: _governanceMarch10OccurredAtUtc(8, 0),
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
    expect(find.text(_governanceReceiptPolicyExecutiveSummary), findsWidgets);
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
    expect(find.text('OPEN EVENTS SCOPE'), findsWidgets);

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

  testWidgets('governance receipt policy empty shift exposes recovery pivots', (
    tester,
  ) async {
    String? openedReportsClientId;
    String? openedReportsSiteId;
    String? openedLedgerClientId;
    String? openedLedgerSiteId;
    var generatedReportCount = 0;

    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
      receiptPolicy: const SovereignReportReceiptPolicy(
        generatedReports: 0,
        trackedConfigurationReports: 0,
        legacyConfigurationReports: 0,
        fullyIncludedReports: 0,
        reportsWithOmittedSections: 0,
        omittedAiDecisionLogReports: 0,
        omittedGuardMetricsReports: 0,
        headline: '',
        summaryLine: '',
        latestReportSummary: '',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const <DispatchEvent>[],
          morningSovereignReport: report,
          initialScopeClientId: 'CLIENT-1',
          initialScopeSiteId: 'SITE-42',
          onOpenReportsForScope: (clientId, siteId) {
            openedReportsClientId = clientId;
            openedReportsSiteId = siteId;
          },
          onOpenLedgerForScope: (clientId, siteId) {
            openedLedgerClientId = clientId;
            openedLedgerSiteId = siteId;
          },
          onGenerateMorningSovereignReport: () async {
            generatedReportCount += 1;
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
      find.byKey(const ValueKey('governance-receipt-policy-empty-recovery')),
      findsOneWidget,
    );
    expect(find.text('RECEIPT BOARD RECOVERY READY'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey('governance-receipt-policy-empty-open-reports'),
      ),
    );
    await tester.pumpAndSettle();

    expect(openedReportsClientId, 'CLIENT-1');
    expect(openedReportsSiteId, 'SITE-42');
    expect(find.text('Reports workspace opened'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-metric-receipt-policy')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-metric-receipt-policy')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('governance-receipt-policy-empty-open-ledger')),
    );
    await tester.pumpAndSettle();

    expect(openedLedgerClientId, 'CLIENT-1');
    expect(openedLedgerSiteId, 'SITE-42');
    expect(find.text('Sovereign ledger opened'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-metric-receipt-policy')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-metric-receipt-policy')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey('governance-receipt-policy-empty-refresh-report'),
      ),
    );
    await tester.pumpAndSettle();

    expect(generatedReportCount, 1);
    expect(find.text('Morning report generated'), findsOneWidget);
  });

  testWidgets('governance page shows listener alarm metric from audit events', (
    tester,
  ) async {
    List<String>? openedEventIds;
    String? openedSelectedEventId;
    var generatedReportCount = 0;
    final report = SovereignReport(
      date: '2026-03-16',
      generatedAtUtc: _governanceReportGeneratedAtUtc(16),
      shiftWindowStartUtc: _governanceMidnightShiftStartedAtUtc(16),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(16),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 12,
        hashVerified: true,
        integrityScore: 99,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 2,
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
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: [
            ListenerAlarmFeedCycleRecorded(
              eventId: 'alarm-cycle-1',
              sequence: 1,
              version: 1,
              occurredAt: _governanceMarch16OccurredAtUtc(2, 0),
              sourceLabel: 'listener-http',
              acceptedCount: 5,
              mappedCount: 4,
              unmappedCount: 1,
              duplicateCount: 0,
              rejectedCount: 0,
              normalizationSkippedCount: 0,
              deliveredCount: 4,
              failedCount: 0,
              clearCount: 3,
              suspiciousCount: 1,
              unavailableCount: 0,
              pendingCount: 0,
              rejectSummary: '',
            ),
            ListenerAlarmAdvisoryRecorded(
              eventId: 'alarm-advisory-1',
              sequence: 2,
              version: 1,
              occurredAt: _governanceMarch16OccurredAtUtc(2, 1),
              clientId: 'CLIENT-1',
              regionId: 'REGION-1',
              siteId: 'SITE-1',
              externalAlarmId: 'EXT-1',
              accountNumber: '1234',
              partition: '1',
              zone: '004',
              zoneLabel: 'Front gate',
              eventLabel: 'Burglary',
              dispositionLabel: 'suspicious',
              summary: 'Person detected near the front gate camera.',
              recommendation: 'Escalation recommended.',
              deliveredCount: 1,
              failedCount: 0,
            ),
            ListenerAlarmParityCycleRecorded(
              eventId: 'alarm-parity-1',
              sequence: 3,
              version: 1,
              occurredAt: _governanceMarch16OccurredAtUtc(2, 2),
              sourceLabel: 'listener-http',
              legacySourceLabel: 'oryx-http',
              statusLabel: 'ok',
              serialCount: 5,
              legacyCount: 5,
              matchedCount: 4,
              unmatchedSerialCount: 1,
              unmatchedLegacyCount: 1,
              maxAllowedSkewSeconds: 90,
              maxSkewSecondsObserved: 22,
              averageSkewSeconds: 8.4,
              driftSummary: 'serial 5 • legacy 5 • matched 4',
              driftReasonCounts: const {'zone_mismatch': 1, 'skew_exceeded': 1},
            ),
          ],
          morningSovereignReport: report,
          initialScopeClientId: 'CLIENT-1',
          initialScopeSiteId: 'SITE-1',
          onOpenEventsForScope: (eventIds, selectedEventId, {originLabel = ''}) {
            openedEventIds = eventIds;
            openedSelectedEventId = selectedEventId;
          },
          onGenerateMorningSovereignReport: () async {
            generatedReportCount += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('governance-metric-listener-alarm')),
      findsOneWidget,
    );
    expect(find.text('1 advisories'), findsOneWidget);
    expect(
      find.textContaining('Latest cycle mapped 4/5 • missed 1'),
      findsOneWidget,
    );
    expect(find.textContaining('parity ok 4/5'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-metric-listener-alarm')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('governance-metric-listener-alarm')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('governance-listener-alarm-parity-dialog')),
      findsOneWidget,
    );
    expect(find.text('LISTENER ALARM PARITY DRILL-IN'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('governance-listener-latest-cycle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('governance-listener-latest-advisory')),
      findsOneWidget,
    );
    expect(find.text('zone_mismatch: 1'), findsOneWidget);
    expect(find.text('skew_exceeded: 1'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('governance-listener-drill-open-events')),
    );
    await tester.pumpAndSettle();

    expect(openedEventIds, equals(const ['alarm-advisory-1']));
    expect(openedSelectedEventId, 'alarm-advisory-1');
    expect(find.text('Events scope opened'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-metric-listener-alarm')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-metric-listener-alarm')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('governance-listener-drill-refresh-report')),
    );
    await tester.pumpAndSettle();

    expect(generatedReportCount, 1);
    expect(find.text('Morning report generated'), findsOneWidget);
  });

  testWidgets(
    'governance listener alarm quiet parity state exposes recovery pivots',
    (tester) async {
      List<String>? openedEventIds;
      String? openedSelectedEventId;
      String? openedReportsClientId;
      String? openedReportsSiteId;
      var generatedReportCount = 0;

      final report = SovereignReport(
        date: '2026-03-16',
        generatedAtUtc: _governanceReportGeneratedAtUtc(16),
        shiftWindowStartUtc: _governanceMidnightShiftStartedAtUtc(16),
        shiftWindowEndUtc: _governanceReportGeneratedAtUtc(16),
        ledgerIntegrity: const SovereignReportLedgerIntegrity(
          totalEvents: 12,
          hashVerified: true,
          integrityScore: 99,
        ),
        aiHumanDelta: const SovereignReportAiHumanDelta(
          aiDecisions: 2,
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
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GovernancePage(
            events: [
              ListenerAlarmFeedCycleRecorded(
                eventId: 'alarm-cycle-quiet-1',
                sequence: 1,
                version: 1,
                occurredAt: _governanceMarch16OccurredAtUtc(2, 0),
                sourceLabel: 'listener-http',
                acceptedCount: 5,
                mappedCount: 4,
                unmappedCount: 1,
                duplicateCount: 0,
                rejectedCount: 0,
                normalizationSkippedCount: 0,
                deliveredCount: 4,
                failedCount: 0,
                clearCount: 3,
                suspiciousCount: 1,
                unavailableCount: 0,
                pendingCount: 0,
                rejectSummary: '',
              ),
              ListenerAlarmAdvisoryRecorded(
                eventId: 'alarm-advisory-quiet-1',
                sequence: 2,
                version: 1,
                occurredAt: _governanceMarch16OccurredAtUtc(2, 1),
                clientId: 'CLIENT-1',
                regionId: 'REGION-1',
                siteId: 'SITE-42',
                externalAlarmId: 'EXT-1',
                accountNumber: '1234',
                partition: '1',
                zone: '004',
                zoneLabel: 'Front gate',
                eventLabel: 'Burglary',
                dispositionLabel: 'suspicious',
                summary: 'Person detected near the front gate camera.',
                recommendation: 'Escalation recommended.',
                deliveredCount: 1,
                failedCount: 0,
              ),
            ],
            morningSovereignReport: report,
            initialScopeClientId: 'CLIENT-1',
            initialScopeSiteId: 'SITE-42',
            onOpenEventsForScope: (eventIds, selectedEventId, {originLabel = ''}) {
              openedEventIds = eventIds;
              openedSelectedEventId = selectedEventId;
            },
            onOpenReportsForScope: (clientId, siteId) {
              openedReportsClientId = clientId;
              openedReportsSiteId = siteId;
            },
            onGenerateMorningSovereignReport: () async {
              generatedReportCount += 1;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('governance-metric-listener-alarm')),
      );
      await tester.tap(
        find.byKey(const ValueKey('governance-metric-listener-alarm')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('governance-listener-parity-empty-recovery')),
        findsOneWidget,
      );
      expect(find.text('LISTENER PARITY PENDING'), findsOneWidget);
      expect(find.text('Escalation recommended.'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey('governance-listener-parity-empty-open-events'),
        ),
      );
      await tester.pumpAndSettle();

      expect(openedEventIds, equals(const ['alarm-advisory-quiet-1']));
      expect(openedSelectedEventId, 'alarm-advisory-quiet-1');
      expect(find.text('Events scope opened'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('governance-metric-listener-alarm')),
      );
      await tester.tap(
        find.byKey(const ValueKey('governance-metric-listener-alarm')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('governance-listener-parity-empty-open-reports'),
        ),
      );
      await tester.pumpAndSettle();

      expect(openedReportsClientId, 'CLIENT-1');
      expect(openedReportsSiteId, 'SITE-42');
      expect(find.text('Reports workspace opened'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('governance-metric-listener-alarm')),
      );
      await tester.tap(
        find.byKey(const ValueKey('governance-metric-listener-alarm')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('governance-listener-parity-empty-refresh-report'),
        ),
      );
      await tester.pumpAndSettle();

      expect(generatedReportCount, 1);
      expect(find.text('Morning report generated'), findsOneWidget);
    },
  );

  testWidgets('governance partner scorecard drill-in can open scoped reports', (
    tester,
  ) async {
    Map<String, String>? openedScope;
    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
            latestOccurredAtUtc: _governanceMarch10OccurredAtUtc(1, 30),
            dispatchCreatedAtUtc: _governanceMarch10OccurredAtUtc(1, 0),
            acceptedAtUtc: _governanceMarch10OccurredAtUtc(1, 4),
            onSiteAtUtc: _governanceMarch10OccurredAtUtc(1, 10),
            allClearAtUtc: _governanceMarch10OccurredAtUtc(1, 30),
            acceptedDelayMinutes: 4.0,
            onSiteDelayMinutes: 10.0,
            scoreLabel: 'STRONG',
            scoreReason: _governancePartnerAllClearReason,
            workflowSummary: _governancePartnerAllClearWorkflowSummary,
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
    expect(
      find.textContaining('Opening Reports Workspace for SITE-42'),
      findsOneWidget,
    );
  });

  testWidgets(
    'governance partner scorecard empty chains expose recovery pivots',
    (tester) async {
      String? openedLedgerClientId;
      String? openedLedgerSiteId;
      var generatedReportCount = 0;
      final report = SovereignReport(
        date: '2026-03-10',
        generatedAtUtc: _governanceReportGeneratedAtUtc(10),
        shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
        shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
          acceptedCount: 0,
          onSiteCount: 0,
          allClearCount: 0,
          cancelledCount: 0,
          summaryLine: '',
          scoreboardRows: [
            SovereignReportPartnerScoreboardRow(
              clientId: 'CLIENT-1',
              siteId: 'SITE-42',
              partnerLabel: 'Partner Alpha',
              dispatchCount: 1,
              strongCount: 0,
              onTrackCount: 1,
              watchCount: 0,
              criticalCount: 0,
              averageAcceptedDelayMinutes: 0,
              averageOnSiteDelayMinutes: 0,
              summaryLine:
                  'Dispatches 1 • Strong 0 • On track 1 • Watch 0 • Critical 0 • Avg accept 0.0m • Avg on site 0.0m',
            ),
          ],
          dispatchChains: const [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GovernancePage(
            events: const [],
            morningSovereignReport: report,
            onOpenLedgerForScope: (clientId, siteId) {
              openedLedgerClientId = clientId;
              openedLedgerSiteId = siteId;
            },
            onGenerateMorningSovereignReport: () async {
              generatedReportCount += 1;
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

      expect(
        find.byKey(const ValueKey('governance-partner-scorecard-empty-chains')),
        findsOneWidget,
      );
      expect(find.text('CHAIN RECOVERY READY'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey('governance-partner-scorecard-empty-open-ledger'),
        ),
      );
      await tester.pumpAndSettle();

      expect(openedLedgerClientId, 'CLIENT-1');
      expect(openedLedgerSiteId, 'SITE-42');
      expect(find.text('Sovereign ledger opened'), findsOneWidget);

      await tester.ensureVisible(scoreboardFinder);
      await tester.tap(scoreboardFinder);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('governance-partner-scorecard-empty-refresh-report'),
        ),
      );
      await tester.pumpAndSettle();

      expect(generatedReportCount, 1);
      expect(find.text('Morning report generated'), findsOneWidget);
    },
  );

  testWidgets(
    'governance workspace reports action falls back to scoped Reports Workspace',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 980);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? openedClientId;
      String? openedSiteId;
      final report = SovereignReport(
        date: '2026-03-10',
        generatedAtUtc: _governanceReportGeneratedAtUtc(10),
        shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
        shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
          scoreboardRows: const [],
          dispatchChains: [
            SovereignReportPartnerDispatchChain(
              dispatchId: 'DSP-200',
              clientId: 'CLIENT-1',
              siteId: 'SITE-42',
              partnerLabel: 'Partner Alpha',
              declarationCount: 3,
              latestStatus: PartnerDispatchStatus.allClear,
              latestOccurredAtUtc: _governanceMarch10OccurredAtUtc(1, 30),
              dispatchCreatedAtUtc: _governanceMarch10OccurredAtUtc(1, 0),
              acceptedAtUtc: _governanceMarch10OccurredAtUtc(1, 4),
              onSiteAtUtc: _governanceMarch10OccurredAtUtc(1, 10),
              allClearAtUtc: _governanceMarch10OccurredAtUtc(1, 30),
              acceptedDelayMinutes: 4.0,
              onSiteDelayMinutes: 10.0,
              scoreLabel: 'STRONG',
              scoreReason: _governancePartnerAllClearReason,
              workflowSummary: _governancePartnerAllClearWorkflowSummary,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GovernancePage(
            events: const <DispatchEvent>[],
            morningSovereignReport: report,
            initialScopeClientId: 'CLIENT-1',
            initialScopeSiteId: 'SITE-42',
            onOpenReportsForScope: (clientId, siteId) {
              openedClientId = clientId;
              openedSiteId = siteId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('governance-quick-view-reports-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey('governance-quick-view-reports-button')),
      );
      await tester.pumpAndSettle();

      expect(openedClientId, 'CLIENT-1');
      expect(openedSiteId, 'SITE-42');
      expect(find.text('Reports workspace opened'), findsOneWidget);
      expect(
        find.textContaining(
          'keeping Partner Alpha as the active partner context',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'governance workspace reports action opens receipt drill-in when no reports route is available',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 980);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final report = SovereignReport(
        date: '2026-03-10',
        generatedAtUtc: _governanceReportGeneratedAtUtc(10),
        shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
        shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
        receiptPolicy: const SovereignReportReceiptPolicy(
          generatedReports: 2,
          trackedConfigurationReports: 1,
          legacyConfigurationReports: 1,
          fullyIncludedReports: 0,
          reportsWithOmittedSections: 1,
          omittedAiDecisionLogReports: 1,
          omittedGuardMetricsReports: 1,
          headline: _governanceReceiptPolicyHeadline,
          summaryLine: _governanceReceiptPolicySummaryLine,
          latestReportSummary: _governanceReceiptPolicyLatestReportSummary,
        ),
        partnerProgression: SovereignReportPartnerProgression(
          dispatchCount: 1,
          declarationCount: 3,
          acceptedCount: 1,
          onSiteCount: 1,
          allClearCount: 1,
          cancelledCount: 0,
          summaryLine: '',
          scoreboardRows: const [],
          dispatchChains: const [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GovernancePage(
            events: const <DispatchEvent>[],
            morningSovereignReport: report,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('governance-quick-view-reports-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey('governance-quick-view-reports-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('governance-receipt-policy-dialog')),
        findsOneWidget,
      );
      expect(find.text('Receipt policy drill-in opened'), findsOneWidget);
      expect(
        find.textContaining('no scoped Reports Workspace was available'),
        findsOneWidget,
      );
    },
  );

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
        generatedAtUtc: _governanceReportGeneratedAtUtc(10),
        shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
        shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
        standardBrandingReports: 0,
        defaultPartnerBrandingReports: 0,
        customBrandingOverrideReports: 1,
        brandingExecutiveSummary:
            _governanceReceiptPolicyBrandingExecutiveSummary,
        latestBrandingSummary: _governanceReceiptPolicyLatestBrandingSummary,
      );
      final priorReport = buildReport(
        date: '2026-03-09',
        generatedAtUtc: _governanceReportGeneratedAtUtc(9),
        shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(8),
        shiftWindowEndUtc: _governanceReportGeneratedAtUtc(9),
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
                occurredAt: _governanceMarch10OccurredAtUtc(2, 30),
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
                occurredAt: _governanceMarch9OccurredAtUtc(2, 0),
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
        find.textContaining('Opening Reports Workspace for SITE-42'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'governance page scopes partner reporting to a selected site and partner',
    (tester) async {
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
          shiftWindowStartUtc: generatedAtUtc.subtract(
            const Duration(hours: 8),
          ),
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
            workflowHeadline: _governancePartnerInProgressWorkflowHeadline,
            performanceHeadline: _governancePartnerPerformanceHeadline,
            slaHeadline: _governancePartnerInProgressSlaHeadline,
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
        generatedAtUtc: _governanceReportGeneratedAtUtc(14),
        scopeBreakdowns: [
          SovereignReportPartnerScopeBreakdown(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            dispatchCount: 1,
            declarationCount: 2,
            latestStatus: PartnerDispatchStatus.cancelled,
            latestOccurredAtUtc: _governanceMarch14OccurredAtUtc(2, 12),
            summaryLine: _governancePartnerMarch14CancelledScopeSummary,
          ),
          SovereignReportPartnerScopeBreakdown(
            clientId: 'CLIENT-2',
            siteId: 'SITE-77',
            dispatchCount: 1,
            declarationCount: 3,
            latestStatus: PartnerDispatchStatus.allClear,
            latestOccurredAtUtc: _governanceMarch14OccurredAtUtc(3, 10),
            summaryLine: _governancePartnerMarch14AllClearScopeSummary,
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
            summaryLine: _governancePartnerMarch14CriticalScoreboardSummary,
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
            summaryLine: _governancePartnerMarch14StrongScoreboardSummary,
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
            latestOccurredAtUtc: _governanceMarch14OccurredAtUtc(2, 12),
            dispatchCreatedAtUtc: _governanceMarch14OccurredAtUtc(2, 0),
            acceptedAtUtc: _governanceMarch14OccurredAtUtc(2, 12),
            cancelledAtUtc: _governanceMarch14OccurredAtUtc(2, 12),
            acceptedDelayMinutes: 12.0,
            scoreLabel: 'CRITICAL',
            scoreReason: _governancePartnerCancelledReason,
            workflowSummary: _governancePartnerCancelledWorkflowSummary,
          ),
          SovereignReportPartnerDispatchChain(
            dispatchId: 'DSP-200',
            clientId: 'CLIENT-2',
            siteId: 'SITE-77',
            partnerLabel: 'Partner Beta',
            declarationCount: 3,
            latestStatus: PartnerDispatchStatus.allClear,
            latestOccurredAtUtc: _governanceMarch14OccurredAtUtc(3, 10),
            dispatchCreatedAtUtc: _governanceMarch14OccurredAtUtc(2, 56),
            acceptedAtUtc: _governanceMarch14OccurredAtUtc(3, 2),
            onSiteAtUtc: _governanceMarch14OccurredAtUtc(3, 10),
            allClearAtUtc: _governanceMarch14OccurredAtUtc(3, 12),
            acceptedDelayMinutes: 6.0,
            onSiteDelayMinutes: 14.0,
            scoreLabel: 'STRONG',
            scoreReason: _governancePartnerCompletedResponseReason,
            workflowSummary: _governancePartnerAllClearWorkflowSummary,
          ),
        ],
      );
      final currentReport = buildReport(
        date: '2026-03-15',
        generatedAtUtc: _governanceReportGeneratedAtUtc(15),
        scopeBreakdowns: [
          SovereignReportPartnerScopeBreakdown(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            dispatchCount: 1,
            declarationCount: 3,
            latestStatus: PartnerDispatchStatus.allClear,
            latestOccurredAtUtc: _governanceMarch15OccurredAtUtc(1, 18),
            summaryLine: _governancePartnerMarch15AllClearScopeSummary,
          ),
          SovereignReportPartnerScopeBreakdown(
            clientId: 'CLIENT-2',
            siteId: 'SITE-77',
            dispatchCount: 1,
            declarationCount: 2,
            latestStatus: PartnerDispatchStatus.cancelled,
            latestOccurredAtUtc: _governanceMarch15OccurredAtUtc(4, 08),
            summaryLine: _governancePartnerMarch15CancelledScopeSummary,
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
            summaryLine: _governancePartnerMarch15StrongScoreboardSummary,
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
            summaryLine: _governancePartnerMarch15CriticalScoreboardSummary,
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
            latestOccurredAtUtc: _governanceMarch15OccurredAtUtc(1, 18),
            dispatchCreatedAtUtc: _governanceMarch15OccurredAtUtc(1, 0),
            acceptedAtUtc: _governanceMarch15OccurredAtUtc(1, 4),
            onSiteAtUtc: _governanceMarch15OccurredAtUtc(1, 12),
            allClearAtUtc: _governanceMarch15OccurredAtUtc(1, 18),
            acceptedDelayMinutes: 4.0,
            onSiteDelayMinutes: 12.0,
            scoreLabel: 'STRONG',
            scoreReason: _governancePartnerCompletedResponseReason,
            workflowSummary: _governancePartnerAllClearWorkflowSummary,
          ),
          SovereignReportPartnerDispatchChain(
            dispatchId: 'DSP-201',
            clientId: 'CLIENT-2',
            siteId: 'SITE-77',
            partnerLabel: 'Partner Beta',
            declarationCount: 2,
            latestStatus: PartnerDispatchStatus.cancelled,
            latestOccurredAtUtc: _governanceMarch15OccurredAtUtc(4, 8),
            dispatchCreatedAtUtc: _governanceMarch15OccurredAtUtc(4, 0),
            acceptedAtUtc: _governanceMarch15OccurredAtUtc(4, 5),
            cancelledAtUtc: _governanceMarch15OccurredAtUtc(4, 8),
            acceptedDelayMinutes: 10.0,
            scoreLabel: 'CRITICAL',
            scoreReason: _governancePartnerCancelledReason,
            workflowSummary: _governancePartnerCancelledWorkflowSummary,
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
        find.textContaining(_governancePartnerAlphaScopeLabel),
        findsWidgets,
      );
      expect(
        find.textContaining('CLIENT-2/SITE-77 • Partner Beta'),
        findsNothing,
      );
      expect(find.text(_governancePartnerStrongResponseSummary), findsWidgets);
      expect(find.text('Avg accept 4.0m • Avg on site 12.0m'), findsOneWidget);
      expect(find.text('IMPROVING'), findsOneWidget);
      expect(find.textContaining('Partner Alpha • DSP-101'), findsWidgets);
      expect(find.textContaining('Partner Beta • DSP-201'), findsNothing);
    },
  );

  testWidgets('governance page supports client-wide scope focus', (
    tester,
  ) async {
    final report = SovereignReport(
      date: '2026-03-15',
      generatedAtUtc: _governanceReportGeneratedAtUtc(15),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(14),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(15),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 12,
        hashVerified: true,
        integrityScore: 100,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 3,
        humanOverrides: 1,
        overrideReasons: {'PSIRA expired': 1},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 2,
        driftDetected: 0,
        avgMatchScore: 97,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 0,
        pdpExpired: 0,
        totalBlocked: 0,
      ),
      partnerProgression: SovereignReportPartnerProgression(
        dispatchCount: 3,
        declarationCount: 6,
        acceptedCount: 3,
        onSiteCount: 2,
        allClearCount: 1,
        cancelledCount: 0,
        workflowHeadline: _governancePartnerClientWideWorkflowHeadline,
        performanceHeadline: _governancePartnerClientWidePerformanceHeadline,
        slaHeadline: _governancePartnerSlaHeadline,
        summaryLine: _governancePartnerClientWideSummaryLine,
        scopeBreakdowns: [
          SovereignReportPartnerScopeBreakdown(
            clientId: 'CLIENT-1',
            siteId: 'SITE-42',
            dispatchCount: 1,
            declarationCount: 3,
            latestStatus: PartnerDispatchStatus.allClear,
            latestOccurredAtUtc: _governanceMarch15OccurredAtUtc(1, 18),
            summaryLine: _governancePartnerMarch15AllClearScopeSummary,
          ),
          SovereignReportPartnerScopeBreakdown(
            clientId: 'CLIENT-1',
            siteId: 'SITE-99',
            dispatchCount: 1,
            declarationCount: 2,
            latestStatus: PartnerDispatchStatus.onSite,
            latestOccurredAtUtc: _governanceMarch15OccurredAtUtc(2, 12),
            summaryLine:
                'Dispatches 1 • Declarations 2 • Latest ON SITE @ 2026-03-15T02:12:00.000Z',
          ),
          SovereignReportPartnerScopeBreakdown(
            clientId: 'CLIENT-2',
            siteId: 'SITE-77',
            dispatchCount: 1,
            declarationCount: 1,
            latestStatus: PartnerDispatchStatus.accepted,
            latestOccurredAtUtc: _governanceMarch15OccurredAtUtc(4, 5),
            summaryLine:
                'Dispatches 1 • Declarations 1 • Latest ACCEPTED @ 2026-03-15T04:05:00.000Z',
          ),
        ],
        scoreboardRows: const [
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
            summaryLine: _governancePartnerStrongResponseSummary,
          ),
          SovereignReportPartnerScoreboardRow(
            clientId: 'CLIENT-1',
            siteId: 'SITE-99',
            partnerLabel: 'Partner Alpha',
            dispatchCount: 1,
            strongCount: 0,
            onTrackCount: 1,
            watchCount: 0,
            criticalCount: 0,
            averageAcceptedDelayMinutes: 6.0,
            averageOnSiteDelayMinutes: 12.0,
            summaryLine: _governancePartnerOnTrackResponseSummary,
          ),
          SovereignReportPartnerScoreboardRow(
            clientId: 'CLIENT-2',
            siteId: 'SITE-77',
            partnerLabel: 'Partner Beta',
            dispatchCount: 1,
            strongCount: 0,
            onTrackCount: 0,
            watchCount: 1,
            criticalCount: 0,
            averageAcceptedDelayMinutes: 5.0,
            averageOnSiteDelayMinutes: 0.0,
            summaryLine: _governancePartnerWatchResponseSummary,
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
            latestOccurredAtUtc: _governanceMarch15OccurredAtUtc(1, 18),
            dispatchCreatedAtUtc: _governanceMarch15OccurredAtUtc(1, 2),
            acceptedAtUtc: _governanceMarch15OccurredAtUtc(1, 6),
            onSiteAtUtc: _governanceMarch15OccurredAtUtc(1, 14),
            allClearAtUtc: _governanceMarch15OccurredAtUtc(1, 18),
            acceptedDelayMinutes: 4.0,
            onSiteDelayMinutes: 12.0,
            scoreLabel: 'STRONG',
            scoreReason: _governancePartnerCompletedResponseReason,
            workflowSummary: _governancePartnerAllClearWorkflowSummary,
          ),
          SovereignReportPartnerDispatchChain(
            dispatchId: 'DSP-102',
            clientId: 'CLIENT-1',
            siteId: 'SITE-99',
            partnerLabel: 'Partner Alpha',
            declarationCount: 2,
            latestStatus: PartnerDispatchStatus.onSite,
            latestOccurredAtUtc: _governanceMarch15OccurredAtUtc(2, 12),
            dispatchCreatedAtUtc: _governanceMarch15OccurredAtUtc(2, 0),
            acceptedAtUtc: _governanceMarch15OccurredAtUtc(2, 6),
            onSiteAtUtc: _governanceMarch15OccurredAtUtc(2, 12),
            acceptedDelayMinutes: 6.0,
            onSiteDelayMinutes: 12.0,
            scoreLabel: 'ON TRACK',
            scoreReason: _governancePartnerOnSiteReason,
            workflowSummary: _governancePartnerOnSiteWorkflowSummary,
          ),
          SovereignReportPartnerDispatchChain(
            dispatchId: 'DSP-201',
            clientId: 'CLIENT-2',
            siteId: 'SITE-77',
            partnerLabel: 'Partner Beta',
            declarationCount: 1,
            latestStatus: PartnerDispatchStatus.accepted,
            latestOccurredAtUtc: _governanceMarch15OccurredAtUtc(4, 5),
            dispatchCreatedAtUtc: _governanceMarch15OccurredAtUtc(4, 0),
            acceptedAtUtc: _governanceMarch15OccurredAtUtc(4, 5),
            acceptedDelayMinutes: 5.0,
            scoreLabel: 'WATCH',
            scoreReason: _governancePartnerWatchReason,
            workflowSummary: 'ACCEPT (LATEST ACCEPT)',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const [],
          morningSovereignReport: report,
          initialScopeClientId: 'CLIENT-1',
          initialScopeSiteId: '',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('governance-scope-banner')),
      findsOneWidget,
    );
    expect(find.text('CLIENT-1/all sites'), findsOneWidget);
    expect(
      find.textContaining('CLIENT-2/SITE-77 • Partner Beta'),
      findsNothing,
    );
    expect(find.textContaining('Partner Alpha • DSP-101'), findsWidgets);
    expect(find.textContaining('Partner Alpha • DSP-102'), findsWidgets);
    expect(find.textContaining('Partner Beta • DSP-201'), findsNothing);
  });

  testWidgets('governance page filters partner insights to client site scope', (
    tester,
  ) async {
    SovereignReport buildReport({
      required String date,
      required DateTime generatedAtUtc,
      required List<SovereignReportPartnerScopeBreakdown> scopeBreakdowns,
      required List<SovereignReportPartnerScoreboardRow> scoreboardRows,
      required List<SovereignReportPartnerDispatchChain> dispatchChains,
    }) {
      return SovereignReport(
        date: date,
        generatedAtUtc: generatedAtUtc,
        shiftWindowStartUtc: generatedAtUtc.subtract(const Duration(hours: 8)),
        shiftWindowEndUtc: generatedAtUtc,
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
          workflowHeadline: _governancePartnerInProgressWorkflowHeadline,
          performanceHeadline: _governancePartnerPerformanceHeadline,
          slaHeadline: _governancePartnerInProgressSlaHeadline,
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
      generatedAtUtc: _governanceReportGeneratedAtUtc(14),
      scopeBreakdowns: [
        SovereignReportPartnerScopeBreakdown(
          clientId: 'CLIENT-1',
          siteId: 'SITE-42',
          dispatchCount: 1,
          declarationCount: 2,
          latestStatus: PartnerDispatchStatus.cancelled,
          latestOccurredAtUtc: _governanceMarch14OccurredAtUtc(2, 12),
          summaryLine: _governancePartnerMarch14CancelledScopeSummary,
        ),
        SovereignReportPartnerScopeBreakdown(
          clientId: 'CLIENT-2',
          siteId: 'SITE-77',
          dispatchCount: 1,
          declarationCount: 3,
          latestStatus: PartnerDispatchStatus.allClear,
          latestOccurredAtUtc: _governanceMarch14OccurredAtUtc(3, 10),
          summaryLine: _governancePartnerMarch14AllClearScopeSummary,
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
          summaryLine: _governancePartnerMarch14CriticalScoreboardSummary,
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
          summaryLine: _governancePartnerMarch14StrongScoreboardSummary,
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
          latestOccurredAtUtc: _governanceMarch14OccurredAtUtc(2, 12),
          dispatchCreatedAtUtc: _governanceMarch14OccurredAtUtc(2, 0),
          acceptedAtUtc: _governanceMarch14OccurredAtUtc(2, 12),
          cancelledAtUtc: _governanceMarch14OccurredAtUtc(2, 12),
          acceptedDelayMinutes: 12.0,
          scoreLabel: 'CRITICAL',
          scoreReason: _governancePartnerCancelledReason,
          workflowSummary: _governancePartnerCancelledWorkflowSummary,
        ),
        SovereignReportPartnerDispatchChain(
          dispatchId: 'DSP-200',
          clientId: 'CLIENT-2',
          siteId: 'SITE-77',
          partnerLabel: 'Partner Beta',
          declarationCount: 3,
          latestStatus: PartnerDispatchStatus.allClear,
          latestOccurredAtUtc: _governanceMarch14OccurredAtUtc(3, 10),
          dispatchCreatedAtUtc: _governanceMarch14OccurredAtUtc(2, 56),
          acceptedAtUtc: _governanceMarch14OccurredAtUtc(3, 2),
          onSiteAtUtc: _governanceMarch14OccurredAtUtc(3, 10),
          allClearAtUtc: _governanceMarch14OccurredAtUtc(3, 12),
          acceptedDelayMinutes: 6.0,
          onSiteDelayMinutes: 14.0,
          scoreLabel: 'STRONG',
          scoreReason: _governancePartnerCompletedResponseReason,
          workflowSummary: _governancePartnerAllClearWorkflowSummary,
        ),
      ],
    );
    final currentReport = buildReport(
      date: '2026-03-15',
      generatedAtUtc: _governanceReportGeneratedAtUtc(15),
      scopeBreakdowns: [
        SovereignReportPartnerScopeBreakdown(
          clientId: 'CLIENT-1',
          siteId: 'SITE-42',
          dispatchCount: 1,
          declarationCount: 3,
          latestStatus: PartnerDispatchStatus.allClear,
          latestOccurredAtUtc: _governanceMarch15OccurredAtUtc(1, 18),
          summaryLine: _governancePartnerMarch15AllClearScopeSummary,
        ),
        SovereignReportPartnerScopeBreakdown(
          clientId: 'CLIENT-2',
          siteId: 'SITE-77',
          dispatchCount: 1,
          declarationCount: 2,
          latestStatus: PartnerDispatchStatus.cancelled,
          latestOccurredAtUtc: _governanceMarch15OccurredAtUtc(4, 08),
          summaryLine: _governancePartnerMarch15CancelledScopeSummary,
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
          summaryLine: _governancePartnerMarch15StrongScoreboardSummary,
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
          summaryLine: _governancePartnerMarch15CriticalScoreboardSummary,
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
          latestOccurredAtUtc: _governanceMarch15OccurredAtUtc(1, 18),
          dispatchCreatedAtUtc: _governanceMarch15OccurredAtUtc(1, 0),
          acceptedAtUtc: _governanceMarch15OccurredAtUtc(1, 4),
          onSiteAtUtc: _governanceMarch15OccurredAtUtc(1, 12),
          allClearAtUtc: _governanceMarch15OccurredAtUtc(1, 18),
          acceptedDelayMinutes: 4.0,
          onSiteDelayMinutes: 12.0,
          scoreLabel: 'STRONG',
          scoreReason: _governancePartnerCompletedResponseReason,
          workflowSummary: _governancePartnerAllClearWorkflowSummary,
        ),
        SovereignReportPartnerDispatchChain(
          dispatchId: 'DSP-201',
          clientId: 'CLIENT-2',
          siteId: 'SITE-77',
          partnerLabel: 'Partner Beta',
          declarationCount: 2,
          latestStatus: PartnerDispatchStatus.cancelled,
          latestOccurredAtUtc: _governanceMarch15OccurredAtUtc(4, 8),
          dispatchCreatedAtUtc: _governanceMarch15OccurredAtUtc(4, 0),
          acceptedAtUtc: _governanceMarch15OccurredAtUtc(4, 5),
          cancelledAtUtc: _governanceMarch15OccurredAtUtc(4, 8),
          acceptedDelayMinutes: 10.0,
          scoreLabel: 'CRITICAL',
          scoreReason: _governancePartnerCancelledReason,
          workflowSummary: _governancePartnerCancelledWorkflowSummary,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: const [],
          morningSovereignReport: currentReport,
          morningSovereignReportHistory: [priorReport],
          initialScopeClientId: 'CLIENT-1',
          initialScopeSiteId: 'SITE-42',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('governance-scope-banner')),
      findsOneWidget,
    );
    expect(find.text('Scope focus active'), findsOneWidget);
    expect(find.textContaining('CLIENT-1/SITE-42'), findsWidgets);
    expect(
      find.textContaining('CLIENT-2/SITE-77 • Partner Beta'),
      findsNothing,
    );
    expect(find.text(_governancePartnerStrongResponseSummary), findsWidgets);
    expect(find.text('Avg accept 4.0m • Avg on site 12.0m'), findsOneWidget);
    expect(find.text('IMPROVING'), findsOneWidget);
    expect(find.textContaining('Partner Alpha • DSP-101'), findsWidgets);
    expect(find.textContaining('Partner Beta • DSP-201'), findsNothing);
  });

  testWidgets('governance page focuses scene action detail from chips', (
    tester,
  ) async {
    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
        executiveSummary: _governanceReceiptPolicyExecutiveSummary,
        brandingExecutiveSummary:
            _governanceReceiptPolicyBrandingExecutiveSummary,
        investigationExecutiveSummary:
            _governanceReceiptPolicyInvestigationExecutiveSummary,
        headline: _governanceReceiptPolicyHeadline,
        summaryLine: _governanceReceiptPolicyBrandingSummaryLine,
        latestReportSummary: _governanceReceiptPolicyLatestReportSummary,
        latestBrandingSummary: _governanceReceiptPolicyLatestBrandingSummary,
        latestInvestigationSummary:
            _governanceReceiptPolicyLatestInvestigationSummary,
      ),
      siteActivity: const SovereignReportSiteActivity(
        totalSignals: 7,
        personSignals: 4,
        vehicleSignals: 3,
        knownIdentitySignals: 2,
        flaggedIdentitySignals: 1,
        unknownSignals: 3,
        longPresenceSignals: 1,
        guardInteractionSignals: 1,
        executiveSummary: _governanceSiteActivityExecutiveSummary,
        headline: _governanceSiteActivityRecordedHeadline,
        summaryLine: _governanceSiteActivitySummaryLine,
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
        actionMixSummary: _governanceActionMixSummary,
        latestActionTaken: _governanceLatestActionSummary,
        recentActionsSummary: _governanceRecentActionsSummary,
        latestSuppressedPattern: _governanceFilteredPatternSummary,
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
            reasonLabel: _governanceVehicleIncompleteReasonLabel,
            primaryEventId: 'EVT-201',
            startedAtUtc: _governanceMarch10OccurredAtUtc(0, 40),
            lastSeenAtUtc: _governanceMarch10OccurredAtUtc(1, 22),
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
        workflowHeadline: _governancePartnerWorkflowHeadline,
        performanceHeadline: _governancePartnerPerformanceHeadline,
        slaHeadline: _governancePartnerSlaHeadline,
        summaryLine: _governancePartnerProgressionSummaryLine,
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
            summaryLine: _governancePartnerAlphaScoreboardSummary,
          ),
        ],
      ),
    );

    final priorReport = SovereignReport(
      date: '2026-03-09',
      generatedAtUtc: _governanceReportGeneratedAtUtc(9),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(8),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(9),
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

    expect(find.text(_governanceFocusedRecentActionsHeading()), findsOneWidget);
    expect(find.text(_governanceRecentActionsSummary), findsWidgets);
    expect(
      find.text(_governanceFocusedRecentActionsDeckTitle()),
      findsOneWidget,
    );
    expect(
      find.text(_governanceRecentActionsDetailCopyLabel()),
      findsOneWidget,
    );
    expect(find.text(_governanceRecentActionsCopyJsonLabel()), findsOneWidget);
    expect(find.text(_governanceRecentActionsCopyCsvLabel()), findsOneWidget);
    expect(
      find.text(_governanceRecentActionsDownloadJsonLabel()),
      findsOneWidget,
    );
    expect(
      find.text(_governanceRecentActionsDownloadCsvLabel()),
      findsOneWidget,
    );
    expect(find.text(_governanceRecentActionsSharePackLabel()), findsOneWidget);
    expect(
      find.text(_governanceRecentActionsEmailReportLabel()),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('governance-scene-detail-recentActions')),
      findsOneWidget,
    );
    expect(
      find.textContaining(_governanceFocusedRecentActionsLabel()),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(find.textContaining(_governanceRecentActionsLabel()))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.textContaining(_governanceLatestActionLabel()))
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

    expect(
      find.text(_governanceFocusedFilteredPatternHeading()),
      findsOneWidget,
    );
    expect(find.text(_governanceFilteredPatternSummary), findsWidgets);
    expect(
      find.text(_governanceFocusedFilteredPatternDeckTitle()),
      findsOneWidget,
    );
    expect(
      find.text(_governanceFilteredPatternDetailCopyLabel()),
      findsOneWidget,
    );
    expect(
      find.text(_governanceFilteredPatternCopyJsonLabel()),
      findsOneWidget,
    );
    expect(find.text(_governanceFilteredPatternCopyCsvLabel()), findsOneWidget);
    expect(
      find.text(_governanceFilteredPatternDownloadJsonLabel()),
      findsOneWidget,
    );
    expect(
      find.text(_governanceFilteredPatternDownloadCsvLabel()),
      findsOneWidget,
    );
    expect(
      find.text(_governanceFilteredPatternSharePackLabel()),
      findsOneWidget,
    );
    expect(
      find.text(_governanceFilteredPatternEmailReportLabel()),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('governance-scene-detail-filteredPattern')),
      findsOneWidget,
    );
    expect(
      find.textContaining(_governanceFocusedFilteredPatternLabel()),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(
            find.textContaining(_governanceLatestFilteredPatternLabel()),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(find.textContaining(_governanceRecentActionsLabel()))
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
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
        headline: _governanceReceiptPolicyHeadline,
        summaryLine: _governanceReceiptPolicySummaryLine,
        latestReportSummary: _governanceReceiptPolicyLatestReportSummary,
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
        actionMixSummary: _governanceActionMixSummary,
        latestActionTaken: _governanceLatestActionSummary,
        recentActionsSummary: _governanceRecentActionsSummary,
        latestSuppressedPattern: _governanceFilteredPatternSummary,
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
            reasonLabel: _governanceVehicleIncompleteReasonLabel,
            primaryEventId: 'EVT-201',
            startedAtUtc: _governanceMarch10OccurredAtUtc(0, 40),
            lastSeenAtUtc: _governanceMarch10OccurredAtUtc(1, 22),
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
        workflowHeadline: _governancePartnerWorkflowHeadline,
        performanceHeadline: _governancePartnerPerformanceHeadline,
        slaHeadline: 'Avg accept 5.0m • Avg on site 13.0m',
        summaryLine: _governancePartnerProgressionSummaryLine,
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
            summaryLine: _governancePartnerAlphaScoreboardSummary,
          ),
        ],
      ),
    );

    final priorReport = SovereignReport(
      date: '2026-03-09',
      generatedAtUtc: _governanceReportGeneratedAtUtc(9),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(8),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(9),
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

    expect(find.text(_governanceFocusedRecentActionsHeading()), findsOneWidget);
    expect(
      find.byKey(const ValueKey('governance-scene-detail-recentActions')),
      findsOneWidget,
    );
    expect(find.text(_governanceRecentActionsCopyJsonLabel()), findsOneWidget);
    expect(find.text('Tap to clear'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-scene-detail-row-recentActions')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-scene-detail-row-recentActions')),
    );
    await tester.pumpAndSettle();

    expect(find.text(_governanceFocusedRecentActionsHeading()), findsNothing);
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
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
        headline: _governanceReceiptPolicyHeadline,
        summaryLine: _governanceReceiptPolicySummaryLine,
        latestReportSummary: _governanceReceiptPolicyLatestReportSummary,
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
        actionMixSummary: _governanceActionMixSummary,
        latestActionTaken: _governanceLatestActionSummary,
        recentActionsSummary: _governanceRecentActionsSummary,
        latestSuppressedPattern: _governanceFilteredPatternSummary,
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
            reasonLabel: _governanceVehicleIncompleteReasonLabel,
            primaryEventId: 'EVT-201',
            startedAtUtc: _governanceMarch10OccurredAtUtc(0, 40),
            lastSeenAtUtc: _governanceMarch10OccurredAtUtc(1, 22),
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
    expect(find.text(_governanceFocusedRecentActionsHeading()), findsOneWidget);
    expect(
      find.text(_governanceFocusedRecentActionsDeckTitle()),
      findsOneWidget,
    );

    await tester.tap(find.text('Hide Governance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Governance'));
    await tester.pumpAndSettle();

    expect(find.text(_governanceFocusedRecentActionsHeading()), findsOneWidget);
    expect(
      find.text(_governanceFocusedRecentActionsDeckTitle()),
      findsOneWidget,
    );
    expect(find.text(_governanceRecentActionsCopyJsonLabel()), findsOneWidget);
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
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
        headline: _governanceReceiptPolicyHeadline,
        summaryLine: _governanceReceiptPolicySummaryLine,
        latestReportSummary: _governanceReceiptPolicyLatestReportSummary,
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
        actionMixSummary: _governanceActionMixSummary,
        latestActionTaken: _governanceLatestActionSummary,
        recentActionsSummary: _governanceRecentActionsSummary,
        latestSuppressedPattern: _governanceFilteredPatternSummary,
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
    expect(find.text(_governanceFocusedRecentActionsHeading()), findsOneWidget);

    await tester.tap(find.text('Command').first);
    await tester.pumpAndSettle();
    expect(find.text('Live Operations Stub'), findsOneWidget);

    await tester.tap(find.text('Governance').first);
    await tester.pumpAndSettle();

    expect(find.text(_governanceFocusedRecentActionsHeading()), findsOneWidget);
    expect(find.text(_governanceRecentActionsCopyJsonLabel()), findsOneWidget);
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
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
        headline: _governanceReceiptPolicyHeadline,
        summaryLine: _governanceReceiptPolicySummaryLine,
        latestReportSummary: _governanceReceiptPolicyLatestReportSummary,
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
        actionMixSummary: _governanceActionMixSummary,
        latestActionTaken: _governanceLatestActionSummary,
        recentActionsSummary: _governanceRecentActionsSummary,
        latestSuppressedPattern: _governanceFilteredPatternSummary,
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
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
        headline: _governanceReceiptPolicyHeadline,
        summaryLine: _governanceReceiptPolicySummaryLine,
        latestReportSummary: _governanceReceiptPolicyLatestReportSummary,
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
        actionMixSummary: _governanceActionMixSummary,
        latestActionTaken: _governanceLatestActionSummary,
        recentActionsSummary: _governanceRecentActionsSummary,
        latestSuppressedPattern: _governanceFilteredPatternSummary,
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

    expect(find.text(_governanceFocusedFilteredPatternHeading()), findsNothing);
    expect(find.text('Copy Morning JSON'), findsOneWidget);

    await tester.tap(find.text('Parent Focus Filtered'));
    await tester.pumpAndSettle();

    expect(
      find.text(_governanceFocusedFilteredPatternHeading()),
      findsOneWidget,
    );
    expect(
      find.text(_governanceFocusedFilteredPatternDeckTitle()),
      findsOneWidget,
    );
    expect(
      find.text(_governanceFilteredPatternCopyJsonLabel()),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('governance-scene-detail-filteredPattern')),
      findsOneWidget,
    );

    await tester.tap(find.text('Parent Clear Focus'));
    await tester.pumpAndSettle();

    expect(find.text(_governanceFocusedFilteredPatternHeading()), findsNothing);
    expect(
      find.text(_governanceFocusedFilteredPatternDeckTitle()),
      findsNothing,
    );
    expect(find.text('Copy Morning JSON'), findsOneWidget);
  });

  testWidgets('governance page ignores invalid incoming scene action focus', (
    tester,
  ) async {
    final report = SovereignReport(
      date: '2026-03-11',
      generatedAtUtc: _governanceReportGeneratedAtUtc(11),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(10),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(11),
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

    expect(find.text(_governanceFocusedRecentActionsHeading()), findsNothing);
    expect(find.text(_governanceRecentActionsCopyJsonLabel()), findsNothing);
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
        generatedAtUtc: _governanceReportGeneratedAtUtc(11),
        shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(10),
        shiftWindowEndUtc: _governanceReportGeneratedAtUtc(11),
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
        generatedAtUtc: _governanceReportGeneratedAtUtc(12),
        shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(11),
        shiftWindowEndUtc: _governanceReportGeneratedAtUtc(12),
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

      expect(find.text(_governanceFocusedRecentActionsHeading()), findsNothing);
      expect(focusChanges, isEmpty);

      await tester.tap(find.text('Swap Report'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text(_governanceFocusedRecentActionsHeading()),
        findsOneWidget,
      );
      expect(
        find.text(_governanceFocusedRecentActionsDeckTitle()),
        findsOneWidget,
      );
      expect(
        find.text(_governanceRecentActionsCopyJsonLabel()),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('governance-scene-detail-recentActions')),
        findsOneWidget,
      );
      expect(focusChanges, isEmpty);
    },
  );

  testWidgets(
    'governance page clears stale focused scene action when report changes',
    (tester) async {
      final reportWithRecentActions = SovereignReport(
        date: '2026-03-10',
        generatedAtUtc: _governanceReportGeneratedAtUtc(10),
        shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
        shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
          actionMixSummary: _governanceActionMixSummary,
          latestActionTaken: _governanceLatestActionSummary,
          recentActionsSummary: _governanceRecentActionsSummary,
          latestSuppressedPattern: _governanceFilteredPatternSummary,
        ),
      );
      final reportWithoutRecentActions = SovereignReport(
        date: '2026-03-11',
        generatedAtUtc: _governanceReportGeneratedAtUtc(11),
        shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(10),
        shiftWindowEndUtc: _governanceReportGeneratedAtUtc(11),
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

      expect(
        find.text(_governanceFocusedRecentActionsHeading()),
        findsOneWidget,
      );
      expect(
        find.text(_governanceFocusedRecentActionsDeckTitle()),
        findsOneWidget,
      );
      expect(
        find.text(_governanceRecentActionsCopyJsonLabel()),
        findsOneWidget,
      );

      await tester.tap(find.text('Swap Report'));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(persistedFocus, isNull);
      expect(find.text(_governanceFocusedRecentActionsHeading()), findsNothing);
      expect(
        find.text(_governanceFocusedRecentActionsDeckTitle()),
        findsNothing,
      );
      expect(find.text(_governanceRecentActionsCopyJsonLabel()), findsNothing);
      expect(find.text('Copy Morning JSON'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('governance-scene-focus-recent-actions')),
        findsNothing,
      );
    },
  );

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
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
        executiveSummary: _governanceReceiptPolicyExecutiveSummary,
        brandingExecutiveSummary:
            _governanceReceiptPolicyBrandingExecutiveSummary,
        investigationExecutiveSummary:
            _governanceReceiptPolicyInvestigationExecutiveSummary,
        headline: _governanceReceiptPolicyHeadline,
        summaryLine: _governanceReceiptPolicyBrandingSummaryLine,
        latestReportSummary: _governanceReceiptPolicyLatestReportSummary,
        latestBrandingSummary: _governanceReceiptPolicyLatestBrandingSummary,
        latestInvestigationSummary:
            _governanceReceiptPolicyLatestInvestigationSummary,
      ),
      siteActivity: const SovereignReportSiteActivity(
        totalSignals: 7,
        personSignals: 4,
        vehicleSignals: 3,
        knownIdentitySignals: 2,
        flaggedIdentitySignals: 1,
        unknownSignals: 3,
        longPresenceSignals: 1,
        guardInteractionSignals: 1,
        executiveSummary: _governanceSiteActivityExecutiveSummary,
        headline: _governanceSiteActivityRecordedHeadline,
        summaryLine: _governanceSiteActivitySummaryLine,
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
        actionMixSummary: _governanceActionMixSummary,
        latestActionTaken: _governanceLatestActionSummary,
        recentActionsSummary: _governanceRecentActionsSummary,
        latestSuppressedPattern: _governanceFilteredPatternSummary,
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
            reasonLabel: _governanceVehicleIncompleteReasonLabel,
            primaryEventId: 'EVT-201',
            startedAtUtc: _governanceMarch10OccurredAtUtc(0, 40),
            lastSeenAtUtc: _governanceMarch10OccurredAtUtc(1, 22),
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
        workflowHeadline: _governancePartnerWorkflowHeadline,
        performanceHeadline: _governancePartnerPerformanceHeadline,
        slaHeadline: 'Avg accept 5.0m • Avg on site 13.0m',
        summaryLine: _governancePartnerProgressionSummaryLine,
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
            summaryLine: _governancePartnerAlphaScoreboardSummary,
          ),
        ],
      ),
    );

    final priorReport = SovereignReport(
      date: '2026-03-09',
      generatedAtUtc: _governanceReportGeneratedAtUtc(9),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(8),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(9),
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

    await tester.ensureVisible(
      find.text(_governanceRecentActionsCopyJsonLabel()),
    );
    await tester.tap(find.text(_governanceRecentActionsCopyJsonLabel()));
    await tester.pump();

    expect(copiedPayload, isNotNull);
    expect(
      find.text(
        'Morning report JSON copied for command review with Recent actions focus',
      ),
      findsOneWidget,
    );
    expect(copiedPayload, contains('"focusedLens"'));
    expect(copiedPayload, contains('"key": "recentActions"'));
    expect(copiedPayload, contains('"label": "Recent actions"'));
    expect(copiedPayload, contains('"globalReadiness"'));
    expect(copiedPayload, contains('"focusState": "live_current_shift"'));
    expect(copiedPayload, contains('"historicalFocus": false'));
    expect(
      copiedPayload,
      contains('"focusSummary": "Viewing live oversight shift 2026-03-10."'),
    );
    expect(copiedPayload, contains('"liveReportDate": "2026-03-10"'));
    expect(copiedPayload, contains('"baselineCriticalAverage"'));
    expect(copiedPayload, contains('"baselineElevatedAverage"'));
    expect(copiedPayload, contains('"baselineIntentAverage"'));
    expect(copiedPayload, contains('"receiptPolicy"'));
    expect(copiedPayload, contains('"generatedReports": 2'));
    expect(
      copiedPayload,
      contains(
        '"executiveSummary": "$_governanceReceiptPolicyExecutiveSummary"',
      ),
    );
    expect(
      copiedPayload,
      contains(
        '"brandingExecutiveSummary": "$_governanceReceiptPolicyBrandingExecutiveSummary"',
      ),
    );
    expect(copiedPayload, contains('"governanceHandoffReports": 1'));
    expect(copiedPayload, contains('"routineReviewReports": 1'));
    expect(
      copiedPayload,
      contains(
        '"investigationExecutiveSummary": "$_governanceReceiptPolicyInvestigationExecutiveSummary"',
      ),
    );
    expect(
      copiedPayload,
      contains('"headline": "$_governanceReceiptPolicyHeadline"'),
    );
    expect(
      copiedPayload,
      contains(
        '"latestBrandingSummary": "$_governanceReceiptPolicyLatestBrandingSummary"',
      ),
    );
    expect(
      copiedPayload,
      contains(
        '"latestInvestigationSummary": "$_governanceReceiptPolicyLatestInvestigationSummary"',
      ),
    );
    expect(copiedPayload, contains('"investigationTrend"'));
    expect(copiedPayload, contains('"trendLabel": "NEW"'));
    expect(copiedPayload, contains('"currentModeLabel": "OVERSIGHT HANDOFF"'));
    expect(copiedPayload, contains('"investigationComparison"'));
    expect(copiedPayload, contains('"currentGovernanceHandoffReports": 1'));
    expect(copiedPayload, contains('"currentRoutineReviewReports": 1'));
    expect(copiedPayload, contains('"baselineGovernanceAverage": 0.0'));
    expect(copiedPayload, contains('"baselineRoutineAverage": 0.0'));
    expect(copiedPayload, contains('"baselineReportDays": 0'));
    expect(copiedPayload, contains('"investigationHistory"'));
    expect(copiedPayload, contains('"current": true'));
    expect(copiedPayload, contains('"siteActivity"'));
    expect(copiedPayload, contains('"totalSignals": 7'));
    expect(copiedPayload, contains('"personSignals": 4'));
    expect(copiedPayload, contains('"vehicleSignals": 3'));
    expect(copiedPayload, contains('"flaggedIdentitySignals": 1'));
    expect(copiedPayload, contains('"syntheticWarRoom"'));
    expect(copiedPayload, contains('"focusState": "live_current_shift"'));
    expect(copiedPayload, contains('"historicalFocus": false'));
    expect(
      copiedPayload,
      contains('"focusSummary": "Viewing live oversight shift 2026-03-10."'),
    );
    expect(copiedPayload, contains('"liveReportDate": "2026-03-10"'));
    expect(copiedPayload, contains('"shadowMo"'));
    expect(
      copiedPayload,
      contains('"currentShiftReviewCommand": "/shadowreview 2026-03-10"'),
    );
    expect(
      copiedPayload,
      contains('"currentShiftCaseFileCommand": "/shadowcase json 2026-03-10"'),
    );
    expect(
      copiedPayload,
      contains('"historyHeadline": "$_governanceShadowHistoryHeadline"'),
    );
    expect(
      copiedPayload,
      contains('"historySummary": "$_governanceShadowHistorySummary"'),
    );
    expect(copiedPayload, contains('"postureStrengthSummary": ""'));
    expect(copiedPayload, contains('"validationSummary": ""'));
    expect(copiedPayload, contains('"strengthSummary": ""'));
    expect(copiedPayload, contains('"strengthHistorySummary": ""'));
    expect(copiedPayload, contains('"promotionCurrentValidationStatus": ""'));
    expect(copiedPayload, contains('"promotionShadowReviewCommand": ""'));
    expect(copiedPayload, contains('"tomorrowUrgencySummary": ""'));
    expect(copiedPayload, contains('"tomorrowPromotionPressureSummary": ""'));
    expect(copiedPayload, contains('"tomorrowPromotionExecutionSummary": ""'));
    expect(copiedPayload, contains('"previousTomorrowUrgencySummary": ""'));
    expect(copiedPayload, contains('"planCount": 0'));
    expect(copiedPayload, contains('"policyCount": 0'));
    expect(copiedPayload, contains('"modeLabel": "QUIET REHEARSAL"'));
    expect(copiedPayload, contains('"learningLabel": ""'));
    expect(copiedPayload, contains('"learningSummary": ""'));
    expect(copiedPayload, contains('"shadowSummary": ""'));
    expect(copiedPayload, contains('"shadowValidationSummary": ""'));
    expect(copiedPayload, contains('"shadowTomorrowUrgencySummary": ""'));
    expect(
      copiedPayload,
      contains('"previousShadowTomorrowUrgencySummary": ""'),
    );
    expect(copiedPayload, contains('"shadowLearningSummary": ""'));
    expect(copiedPayload, contains('"shadowMemorySummary": ""'));
    expect(copiedPayload, contains('"promotionPressureSummary": ""'));
    expect(copiedPayload, contains('"promotionExecutionSummary": ""'));
    expect(copiedPayload, contains('"promotionSummary": ""'));
    expect(copiedPayload, contains('"promotionCurrentValidationStatus": ""'));
    expect(copiedPayload, contains('"promotionShadowReviewCommand": ""'));
    expect(copiedPayload, contains('"learningMemorySummary": ""'));
    expect(copiedPayload, contains('"actionBias": ""'));
    expect(copiedPayload, contains('"memoryPriorityBoost": ""'));
    expect(copiedPayload, contains('"memoryCountdownBias": ""'));
    expect(copiedPayload, contains('"baselinePlanAverage": 0.0'));
    expect(copiedPayload, contains('"baselinePolicyAverage": 0.0'));
    expect(copiedPayload, contains('"trendLabel": "STABLE"'));
    expect(copiedPayload, contains('"recommendationSummary": ""'));
    expect(copiedPayload, contains('"reviewShortcuts"'));
    expect(
      copiedPayload,
      contains('"currentShiftReviewCommand": "/syntheticreview 2026-03-10"'),
    );
    expect(
      copiedPayload,
      contains(
        '"currentShiftCaseFileCommand": "/syntheticcase json 2026-03-10"',
      ),
    );
    expect(
      copiedPayload,
      contains('"previousShiftReviewCommand": "/syntheticreview 2026-03-09"'),
    );
    expect(
      copiedPayload,
      contains(
        '"previousShiftCaseFileCommand": "/syntheticcase json 2026-03-09"',
      ),
    );
    expect(copiedPayload, contains('"comparison"'));
    expect(copiedPayload, contains('"baselineSignalsAverage": 0.0'));
    expect(copiedPayload, contains('"baselineUnknownAverage": 0.0'));
    expect(copiedPayload, contains('"reviewShortcuts"'));
    expect(
      copiedPayload,
      contains('"currentShiftReviewCommand": "/activityreview 2026-03-10"'),
    );
    expect(
      copiedPayload,
      contains(
        '"currentShiftCaseFileCommand": "/activitycase json 2026-03-10"',
      ),
    );
    expect(copiedPayload, contains('"targetScopeRequired": true'));
    expect(copiedPayload, contains('"trend"'));
    expect(copiedPayload, contains('"currentModeLabel": "FLAGGED TRAFFIC"'));
    expect(copiedPayload, contains('"history"'));
    expect(
      copiedPayload,
      contains('"summaryLine": "$_governanceSiteActivitySummaryLine"'),
    );
    expect(
      copiedPayload,
      contains('"reviewCommand": "/activityreview 2026-03-10"'),
    );
    expect(
      copiedPayload,
      contains('"caseFileCommand": "/activitycase json 2026-03-10"'),
    );
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
    expect(
      copiedPayload,
      contains('"reasonLabel": "$_governanceVehicleIncompleteReasonLabel"'),
    );
    expect(
      copiedPayload,
      contains('"detail": "$_governanceRecentActionsSummary"'),
    );

    await tester.ensureVisible(
      find.text(_governanceRecentActionsCopyCsvLabel()),
    );
    await tester.tap(find.text(_governanceRecentActionsCopyCsvLabel()));
    await tester.pump();

    expect(copiedPayload, contains('site_activity_total_signals,7'));
    expect(
      copiedPayload,
      contains('global_readiness_focus_state,live_current_shift'),
    );
    expect(copiedPayload, contains('global_readiness_historical_focus,false'));
    expect(
      copiedPayload,
      contains(
        'global_readiness_focus_summary,"Viewing live oversight shift 2026-03-10."',
      ),
    );
    expect(
      copiedPayload,
      contains('global_readiness_live_report_date,2026-03-10'),
    );
    expect(
      copiedPayload,
      contains('global_readiness_next_shift_draft_count,0'),
    );
    expect(copiedPayload, contains('global_readiness_shadow_bias_summary,""'));
    expect(
      copiedPayload,
      contains('global_readiness_tomorrow_posture_summary,""'),
    );
    expect(
      copiedPayload,
      contains('global_readiness_tomorrow_shadow_summary,""'),
    );
    expect(
      copiedPayload,
      contains('global_readiness_tomorrow_urgency_summary,""'),
    );
    expect(
      copiedPayload,
      contains('global_readiness_tomorrow_promotion_pressure_summary,""'),
    );
    expect(
      copiedPayload,
      contains('global_readiness_tomorrow_promotion_execution_summary,""'),
    );
    expect(
      copiedPayload,
      contains(
        'global_readiness_tomorrow_review_command,/tomorrowreview 2026-03-10',
      ),
    );
    expect(
      copiedPayload,
      contains(
        'global_readiness_tomorrow_case_file_command,/tomorrowcase json 2026-03-10',
      ),
    );
    expect(
      copiedPayload,
      contains(
        'global_readiness_shadow_review_command,/shadowreview 2026-03-10',
      ),
    );
    expect(
      copiedPayload,
      contains(
        'global_readiness_shadow_case_file_command,/shadowcase json 2026-03-10',
      ),
    );
    expect(
      copiedPayload,
      contains(
        'global_readiness_shadow_history_headline,"$_governanceShadowHistoryHeadline"',
      ),
    );
    expect(
      copiedPayload,
      contains(
        'global_readiness_shadow_history_summary,"$_governanceShadowHistorySummary"',
      ),
    );
    expect(
      copiedPayload,
      contains('global_readiness_shadow_validation_summary,""'),
    );
    expect(
      copiedPayload,
      contains('global_readiness_shadow_strength_summary,""'),
    );
    expect(
      copiedPayload,
      contains('global_readiness_shadow_posture_strength_summary,""'),
    );
    expect(
      copiedPayload,
      contains('global_readiness_tomorrow_shadow_posture_summary,""'),
    );
    expect(
      copiedPayload,
      contains('global_readiness_shadow_strength_history_summary,""'),
    );
    expect(copiedPayload, contains('synthetic_war_room_plan_count,0'));
    expect(copiedPayload, contains('synthetic_war_room_policy_count,0'));
    expect(
      copiedPayload,
      contains('synthetic_war_room_focus_state,live_current_shift'),
    );
    expect(
      copiedPayload,
      contains('synthetic_war_room_historical_focus,false'),
    );
    expect(
      copiedPayload,
      contains(
        'synthetic_war_room_focus_summary,"Viewing live oversight shift 2026-03-10."',
      ),
    );
    expect(
      copiedPayload,
      contains('synthetic_war_room_live_report_date,2026-03-10'),
    );
    expect(
      copiedPayload,
      contains('synthetic_war_room_mode,"QUIET REHEARSAL"'),
    );
    expect(copiedPayload, contains('synthetic_war_room_learning_label,'));
    expect(copiedPayload, contains('synthetic_war_room_learning_summary,""'));
    expect(
      copiedPayload,
      contains('synthetic_war_room_shadow_posture_summary,""'),
    );
    expect(
      copiedPayload,
      contains('synthetic_war_room_shadow_posture_bias_summary,""'),
    );
    expect(
      copiedPayload,
      contains('synthetic_war_room_promotion_pressure_summary,""'),
    );
    expect(
      copiedPayload,
      contains('synthetic_war_room_shadow_validation_summary,""'),
    );
    expect(
      copiedPayload,
      contains('synthetic_war_room_learning_memory_summary,""'),
    );
    expect(copiedPayload, contains('synthetic_war_room_action_bias,""'));
    expect(
      copiedPayload,
      contains('synthetic_war_room_memory_priority_boost,'),
    );
    expect(
      copiedPayload,
      contains('synthetic_war_room_memory_countdown_bias,'),
    );
    expect(copiedPayload, contains('synthetic_war_room_trend_label,STABLE'));
    expect(
      copiedPayload,
      contains('synthetic_war_room_baseline_plan_average,0.0'),
    );
    expect(
      copiedPayload,
      contains(
        'synthetic_war_room_current_review_command,/syntheticreview 2026-03-10',
      ),
    );
    expect(
      copiedPayload,
      contains(
        'synthetic_war_room_current_case_file_command,/syntheticcase json 2026-03-10',
      ),
    );
    expect(
      copiedPayload,
      contains(
        'synthetic_war_room_previous_review_command,/syntheticreview 2026-03-09',
      ),
    );
    expect(
      copiedPayload,
      contains(
        'synthetic_war_room_previous_case_file_command,/syntheticcase json 2026-03-09',
      ),
    );
    expect(
      copiedPayload,
      contains(
        'synthetic_war_room_history_1,"2026-03-10 • CURRENT • Plans 0 • Policy 0 • QUIET REHEARSAL',
      ),
    );
    expect(copiedPayload, contains('site_activity_people,4'));
    expect(copiedPayload, contains('site_activity_vehicles,3'));
    expect(copiedPayload, contains('site_activity_flagged_ids,1'));
    expect(copiedPayload, contains('site_activity_trend_label,RISING'));
    expect(
      copiedPayload,
      contains('site_activity_trend_current_mode,"FLAGGED TRAFFIC"'),
    );
    expect(
      copiedPayload,
      contains('site_activity_baseline_signals_average,0.0'),
    );
    expect(copiedPayload, contains('site_activity_target_scope_required,true'));
    expect(
      copiedPayload,
      contains(
        'site_activity_current_review_command,/activityreview 2026-03-10',
      ),
    );
    expect(
      copiedPayload,
      contains(
        'site_activity_current_case_file_command,/activitycase json 2026-03-10',
      ),
    );
    expect(
      copiedPayload,
      contains(
        'site_activity_history_1,"2026-03-10 • CURRENT • Signals 7 • Vehicles 3 • People 4 • Known IDs 2 • Unknown 3 • Guard interactions 1 • Flagged IDs 1 • FLAGGED TRAFFIC"',
      ),
    );
    expect(
      copiedPayload,
      contains(
        'site_activity_history_1_review_command,/activityreview 2026-03-10',
      ),
    );
    expect(
      copiedPayload,
      contains(
        'site_activity_history_1_case_file_command,/activitycase json 2026-03-10',
      ),
    );
    expect(
      copiedPayload,
      contains('site_activity_summary,"$_governanceSiteActivitySummaryLine"'),
    );

    expect(copiedPayload, isNotNull);
    expect(copiedPayload, contains('scene_focused_lens_key,recentActions'));
    expect(copiedPayload, contains('receipt_generated_reports,2'));
    expect(
      copiedPayload,
      contains(
        'receipt_executive_summary,"$_governanceReceiptPolicyExecutiveSummary"',
      ),
    );
    expect(
      copiedPayload,
      contains(
        'receipt_branding_executive_summary,"$_governanceReceiptPolicyBrandingExecutiveSummary"',
      ),
    );
    expect(
      copiedPayload,
      contains('receipt_headline,"$_governanceReceiptPolicyHeadline"'),
    );
    expect(
      copiedPayload,
      contains(
        'receipt_latest_branding_summary,"$_governanceReceiptPolicyLatestBrandingSummary"',
      ),
    );
    expect(copiedPayload, contains('receipt_investigation_trend_label,NEW'));
    expect(
      copiedPayload,
      contains('receipt_investigation_trend_current_mode,"OVERSIGHT HANDOFF"'),
    );
    expect(
      copiedPayload,
      contains('receipt_investigation_current_governance_reports,1'),
    );
    expect(
      copiedPayload,
      contains('receipt_investigation_current_routine_reports,1'),
    );
    expect(
      copiedPayload,
      contains('receipt_investigation_baseline_governance_average,0.0'),
    );
    expect(
      copiedPayload,
      contains('receipt_investigation_baseline_routine_average,0.0'),
    );
    expect(
      copiedPayload,
      contains('receipt_investigation_baseline_report_days,0'),
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
      contains(
        'vehicle_exception_1,"$_governanceVehicleIncompleteReasonLabel • INCOMPLETE • CA123456',
      ),
    );
    expect(
      copiedPayload,
      contains(
        'partner_scoreboard_history_1,"2026-03-10 • CURRENT • $_governancePartnerAlphaScopeLabel',
      ),
    );
    expect(
      copiedPayload,
      contains(
        'partner_scoreboard_history_2,"2026-03-09 • HISTORY • $_governancePartnerAlphaScopeLabel',
      ),
    );
    expect(
      copiedPayload,
      contains('scene_focused_lens_label,"Recent actions"'),
    );
    expect(
      copiedPayload,
      contains('scene_focused_lens_detail,"$_governanceRecentActionsSummary"'),
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
      generatedAtUtc: _governanceReportGeneratedAtUtc(10),
      shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
      shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
        actionMixSummary: _governanceActionMixSummary,
        latestActionTaken: _governanceLatestActionSummary,
        recentActionsSummary: _governanceRecentActionsSummary,
        latestSuppressedPattern: _governanceFilteredPatternSummary,
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
    expect(
      find.text(_governanceFilteredPatternDetailCopyLabel()),
      findsOneWidget,
    );
    await tester.ensureVisible(focusedCopyAction);
    await tester.tap(focusedCopyAction);
    await tester.pumpAndSettle();

    expect(copiedPayload, _governanceFilteredPatternDetailLabel());
    expect(
      find.text(_governanceFilteredPatternDetailCopiedMessage()),
      findsOneWidget,
    );
  });

  testWidgets(
    'governance page copies focused scene action detail from banner',
    (tester) async {
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
        generatedAtUtc: _governanceReportGeneratedAtUtc(10),
        shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
        shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
          actionMixSummary: _governanceActionMixSummary,
          latestActionTaken: _governanceLatestActionSummary,
          recentActionsSummary: _governanceRecentActionsSummary,
          latestSuppressedPattern: _governanceFilteredPatternSummary,
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

      expect(copiedPayload, _governanceRecentActionsLabel());
      expect(
        find.text(_governanceRecentActionsDetailCopiedMessage()),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'governance page expands vehicle exception detail and opens events review',
    (tester) async {
      String? openedEventId;
      final report = SovereignReport(
        date: '2026-03-10',
        generatedAtUtc: _governanceReportGeneratedAtUtc(10),
        shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
        shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
          summaryLine: _governanceVehicleSingleVisitSummaryLine,
          scopeBreakdowns: const [
            SovereignReportVehicleScopeBreakdown(
              clientId: 'CLIENT-1',
              siteId: 'SITE-42',
              totalVisits: 1,
              completedVisits: 0,
              activeVisits: 0,
              incompleteVisits: 1,
              unknownVehicleEvents: 0,
              summaryLine: _governanceVehicleSingleVisitSummaryLine,
            ),
          ],
          exceptionVisits: [
            SovereignReportVehicleVisitException(
              clientId: 'CLIENT-1',
              siteId: 'SITE-42',
              vehicleLabel: 'CA123456',
              statusLabel: 'INCOMPLETE',
              reasonLabel: _governanceVehicleIncompleteReasonLabel,
              workflowSummary: _governanceVehicleServiceIncompleteWorkflow,
              primaryEventId: 'EVT-201',
              startedAtUtc: _governanceMarch10OccurredAtUtc(0, 40),
              lastSeenAtUtc: _governanceMarch10OccurredAtUtc(1, 22),
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
        find.textContaining(
          'Workflow: $_governanceVehicleServiceIncompleteWorkflow',
        ),
        findsWidgets,
      );
      await tester.tap(
        find.byKey(const ValueKey('governance-vehicle-exception-open-EVT-201')),
      );
      await tester.pumpAndSettle();

      expect(openedEventId, 'EVT-201');
      expect(find.text('OPEN EVENTS SCOPE'), findsWidgets);
    },
  );

  testWidgets(
    'governance page shows vehicle review audit history from ledger events',
    (tester) async {
      final report = SovereignReport(
        date: '2026-03-10',
        generatedAtUtc: _governanceReportGeneratedAtUtc(10),
        shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
        shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
          workflowHeadline: _governanceVehicleSingleVisitWorkflowHeadline,
          summaryLine: _governanceVehicleSingleVisitSummaryLine,
          scopeBreakdowns: const [
            SovereignReportVehicleScopeBreakdown(
              clientId: 'CLIENT-1',
              siteId: 'SITE-42',
              totalVisits: 1,
              completedVisits: 0,
              activeVisits: 0,
              incompleteVisits: 1,
              unknownVehicleEvents: 0,
              summaryLine: _governanceVehicleSingleVisitSummaryLine,
            ),
          ],
          exceptionVisits: [
            SovereignReportVehicleVisitException(
              clientId: 'CLIENT-1',
              siteId: 'SITE-42',
              vehicleLabel: 'CA123456',
              statusLabel: 'COMPLETED',
              reasonLabel: _governanceVehicleIncompleteReasonLabel,
              workflowSummary: _governanceVehicleServiceCompletedWorkflow,
              operatorReviewed: true,
              operatorReviewedAtUtc: _governanceMarch10OccurredAtUtc(8, 15),
              operatorStatusOverride: 'COMPLETED',
              primaryEventId: 'EVT-201',
              startedAtUtc: _governanceMarch10OccurredAtUtc(0, 40),
              lastSeenAtUtc: _governanceMarch10OccurredAtUtc(1, 22),
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
                occurredAt: _governanceMarch10OccurredAtUtc(7, 55),
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
                reasonLabel: _governanceVehicleIncompleteReasonLabel,
                workflowSummary: _governanceVehicleServiceActiveWorkflow,
                sourceSurface: 'governance',
              ),
              VehicleVisitReviewRecorded(
                eventId: 'VR-101',
                sequence: 31,
                version: 1,
                occurredAt: _governanceMarch10OccurredAtUtc(8, 15),
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
                reasonLabel: _governanceVehicleIncompleteReasonLabel,
                workflowSummary: _governanceVehicleServiceCompletedWorkflow,
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
          '2026-03-10 08:15 UTC • $_governanceVehicleIncompleteReasonLabel • $_governanceVehicleServiceCompletedWorkflow',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'governance page lets operators review and override vehicle visits',
    (tester) async {
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
        generatedAtUtc: _governanceReportGeneratedAtUtc(10),
        shiftWindowStartUtc: _governanceNightShiftStartedAtUtc(9),
        shiftWindowEndUtc: _governanceReportGeneratedAtUtc(10),
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
          workflowHeadline: _governanceVehicleSingleVisitWorkflowHeadline,
          summaryLine: _governanceVehicleSingleVisitSummaryLine,
          scopeBreakdowns: const [
            SovereignReportVehicleScopeBreakdown(
              clientId: 'CLIENT-1',
              siteId: 'SITE-42',
              totalVisits: 1,
              completedVisits: 0,
              activeVisits: 0,
              incompleteVisits: 1,
              unknownVehicleEvents: 0,
              summaryLine: _governanceVehicleSingleVisitSummaryLine,
            ),
          ],
          exceptionVisits: [
            SovereignReportVehicleVisitException(
              clientId: 'CLIENT-1',
              siteId: 'SITE-42',
              vehicleLabel: 'CA123456',
              statusLabel: 'INCOMPLETE',
              reasonLabel: _governanceVehicleIncompleteReasonLabel,
              workflowSummary: _governanceVehicleServiceIncompleteWorkflow,
              primaryEventId: 'EVT-201',
              startedAtUtc: _governanceMarch10OccurredAtUtc(0, 40),
              lastSeenAtUtc: _governanceMarch10OccurredAtUtc(1, 22),
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
      expect(
        find.text('Workflow: $_governanceVehicleServiceCompletedWorkflow'),
        findsWidgets,
      );

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
      expect(
        find.text('Workflow: $_governanceVehicleServiceCompletedWorkflow'),
        findsWidgets,
      );
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
        contains(
          '"workflowSummary": "$_governanceVehicleServiceCompletedWorkflow"',
        ),
      );
    },
  );
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
