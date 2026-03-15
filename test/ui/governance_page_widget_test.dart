import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/morning_sovereign_report_service.dart';
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
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: [],
          morningSovereignReport: report,
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
    expect(
      find.text(
        '15 completed visits reached EXIT • 1 incomplete visit stalled at SERVICE',
      ),
      findsOneWidget,
    );
    expect(find.text('Vehicle site ledger'), findsOneWidget);
    expect(find.text('Vehicle exception review'), findsOneWidget);
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
    expect(copiedPayload, contains('"vehicleThroughput"'));
    expect(copiedPayload, contains('"totalVisits": 18'));
    expect(
      copiedPayload,
      contains('"summaryLine": "Visits 18 • Entry 18 • Completed 15'),
    );
    expect(copiedPayload, contains('"scopeBreakdowns"'));
    expect(copiedPayload, contains('"exceptionVisits"'));
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
