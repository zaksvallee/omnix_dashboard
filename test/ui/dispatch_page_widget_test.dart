import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/morning_sovereign_report_service.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/partner_dispatch_status_declared.dart';
import 'package:omnix_dashboard/infrastructure/intelligence/news_intelligence_service.dart';
import 'package:omnix_dashboard/ui/dispatch_page.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_sections.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_view.dart';

void main() {
  Widget buildPage({
    String clientId = 'CLIENT-001',
    String siteId = 'SITE-SANDTON',
    required VoidCallback onGenerate,
    required VoidCallback onIngestFeeds,
    VoidCallback? onIngestRadioOps,
    VoidCallback? onIngestCctvEvents,
    VoidCallback? onIngestWearableOps,
    VoidCallback? onIngestNews,
    VoidCallback? onRetryRadioQueue,
    VoidCallback? onClearRadioQueue,
    VoidCallback? onLoadFeedFile,
    String? radioOpsQueueHealth,
    String? radioQueueIntentMix,
    String? radioAckRecentSummary,
    String focusIncidentReference = '',
    String videoOpsLabel = 'CCTV',
    String? cctvCapabilitySummary,
    String? cctvRecentSignalSummary,
    List<VideoFleetScopeHealthView> fleetScopeHealth = const [],
    Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId =
        const {},
    VideoFleetWatchActionDrilldown? initialWatchActionDrilldown,
    ValueChanged<VideoFleetWatchActionDrilldown?>?
    onWatchActionDrilldownChanged,
    String? initialSelectedDispatchId,
    ValueChanged<String?>? onSelectedDispatchChanged,
    void Function(String clientId, String siteId, String? incidentReference)?
    onOpenFleetTacticalScope,
    void Function(String clientId, String siteId, String? incidentReference)?
    onOpenFleetDispatchScope,
    void Function(String clientId, String siteId)? onRecoverFleetWatchScope,
    Future<String> Function(VideoFleetScopeHealthView scope)?
    onExtendTemporaryIdentityApproval,
    Future<String> Function(VideoFleetScopeHealthView scope)?
    onExpireTemporaryIdentityApproval,
    bool radioQueueHasPending = false,
    String? radioQueueFailureDetail,
    String? radioQueueManualActionDetail,
    List<SovereignReport> morningSovereignReportHistory = const [],
    List<DispatchEvent> events = const [],
    required ValueChanged<String> onExecute,
    ValueChanged<String>? onOpenReportForDispatch,
  }) {
    return MaterialApp(
      home: DispatchPage(
        clientId: clientId,
        regionId: 'REGION-GAUTENG',
        siteId: siteId,
        focusIncidentReference: focusIncidentReference,
        onGenerate: onGenerate,
        onIngestFeeds: onIngestFeeds,
        onIngestRadioOps: onIngestRadioOps,
        onIngestCctvEvents: onIngestCctvEvents,
        onIngestWearableOps: onIngestWearableOps,
        onIngestNews: onIngestNews,
        onRetryRadioQueue: onRetryRadioQueue,
        onClearRadioQueue: onClearRadioQueue,
        onLoadFeedFile: onLoadFeedFile,
        radioOpsQueueHealth:
            radioOpsQueueHealth ??
            'pending 0 • due 0 • deferred 0 • max-attempt 0',
        radioQueueIntentMix:
            radioQueueIntentMix ??
            'pending intent mix • all_clear 0 • panic 0 • duress 0 • status 0 • unknown 0',
        radioAckRecentSummary:
            radioAckRecentSummary ??
            'recent ack 0 (6h) • all_clear 0 • panic 0 • duress 0 • status 0',
        videoOpsLabel: videoOpsLabel,
        cctvCapabilitySummary: cctvCapabilitySummary ?? 'caps none',
        cctvRecentSignalSummary:
            cctvRecentSignalSummary ??
            'recent video intel 0 (6h) • intrusion 0 • line_crossing 0 • motion 0 • fr 0 • lpr 0',
        fleetScopeHealth: fleetScopeHealth,
        sceneReviewByIntelligenceId: sceneReviewByIntelligenceId,
        initialWatchActionDrilldown: initialWatchActionDrilldown,
        onWatchActionDrilldownChanged: onWatchActionDrilldownChanged,
        initialSelectedDispatchId: initialSelectedDispatchId,
        onSelectedDispatchChanged: onSelectedDispatchChanged,
        onOpenFleetTacticalScope: onOpenFleetTacticalScope,
        onOpenFleetDispatchScope: onOpenFleetDispatchScope,
        onRecoverFleetWatchScope: onRecoverFleetWatchScope,
        onExtendTemporaryIdentityApproval: onExtendTemporaryIdentityApproval,
        onExpireTemporaryIdentityApproval: onExpireTemporaryIdentityApproval,
        radioQueueHasPending: radioQueueHasPending,
        radioQueueFailureDetail:
            radioQueueFailureDetail ??
            'No failed radio responses pending retry.',
        radioQueueManualActionDetail:
            radioQueueManualActionDetail ??
            'No manual radio queue action in current session.',
        morningSovereignReportHistory: morningSovereignReportHistory,
        configuredNewsSources: const ['newsapi.org'],
        newsSourceDiagnostics: const [
          NewsSourceDiagnostic(
            provider: 'newsapi.org',
            status: 'reachable',
            detail: 'Healthy.',
          ),
        ],
        onRunStress: (_) async {},
        onRunSoak: (_) async {},
        onRunBenchmarkSuite: () async {},
        initialProfile: IntakeStressPreset.medium.profile,
        onProfileChanged: (_) {},
        onScenarioChanged: (scenarioLabel, tags) {},
        onRunNoteChanged: (_) {},
        onTelemetryImported: (_) {},
        onCancelStress: () {},
        onResetTelemetry: () {},
        onClearTelemetryPersistence: () {},
        onClearProfilePersistence: () {},
        stressRunning: false,
        intakeTelemetry: IntakeTelemetry.zero,
        events: events,
        onExecute: onExecute,
        onOpenReportForDispatch: onOpenReportForDispatch,
      ),
    );
  }

  testWidgets('dispatch page stays stable on phone viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildPage(onGenerate: () {}, onIngestFeeds: () {}, onExecute: (_) {}),
    );
    await tester.pumpAndSettle();

    expect(find.text('DISPATCH COMMAND'), findsOneWidget);
    expect(find.text('ACTIVE DISPATCH QUEUE'), findsOneWidget);
    expect(find.text('SYSTEM STATUS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dispatch page header open report uses selected dispatch', (
    tester,
  ) async {
    String? openedDispatchId;

    await tester.pumpWidget(
      buildPage(
        onGenerate: () {},
        onIngestFeeds: () {},
        onExecute: (_) {},
        onOpenReportForDispatch: (dispatchId) {
          openedDispatchId = dispatchId;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dispatch-open-report-button')));
    await tester.pumpAndSettle();

    expect(openedDispatchId, 'DSP-2441');
  });

  testWidgets('dispatch page stays stable on landscape phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildPage(onGenerate: () {}, onIngestFeeds: () {}, onExecute: (_) {}),
    );
    await tester.pumpAndSettle();

    expect(find.text('DISPATCH COMMAND'), findsOneWidget);
    expect(find.text('ACTIVE DISPATCH QUEUE'), findsOneWidget);
    expect(find.text('SYSTEM STATUS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dispatch page syncs parent selection to focused dispatch on first projection',
    (tester) async {
      String? selectedDispatchId = 'DSP-2441';

      await tester.pumpWidget(
        buildPage(
          onGenerate: () {},
          onIngestFeeds: () {},
          onExecute: (_) {},
          focusIncidentReference: 'DSP-2442',
          initialSelectedDispatchId: selectedDispatchId,
          onSelectedDispatchChanged: (value) {
            selectedDispatchId = value;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(selectedDispatchId, 'DSP-2442');
      expect(find.text('Focus Linked: DSP-2442'), findsOneWidget);
    },
  );

  testWidgets('dispatch page marks intelligence focus as scope-backed', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    String? selectedDispatchId;

    await tester.pumpWidget(
      buildPage(
        onGenerate: () {},
        onIngestFeeds: () {},
        onExecute: (_) {},
        focusIncidentReference: 'INT-VALLEE-1',
        onSelectedDispatchChanged: (value) {
          selectedDispatchId = value;
        },
        events: [
          DecisionCreated(
            eventId: 'decision-vallee',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 3)),
            dispatchId: 'DSP-2442',
            clientId: 'CLIENT-001',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
          IntelligenceReceived(
            eventId: 'intel-event-1',
            sequence: 2,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 1)),
            intelligenceId: 'INT-VALLEE-1',
            provider: 'dahua',
            sourceType: 'hardware',
            externalId: 'evt-vallee-1',
            clientId: 'CLIENT-001',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            headline: 'Perimeter motion detected',
            summary: 'Motion flagged near the Vallee perimeter fence.',
            riskScore: 81,
            canonicalHash: 'canon-vallee-1',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(selectedDispatchId, 'DSP-2442');
    expect(find.text('Focus Scope-backed: DSP-2442'), findsOneWidget);
    expect(find.text('Focused Dispatch Lane'), findsNothing);
  });

  testWidgets('dispatch page opens report flow for cleared dispatches', (
    tester,
  ) async {
    String? openedReportDispatchId;

    await tester.pumpWidget(
      buildPage(
        onGenerate: () {},
        onIngestFeeds: () {},
        onExecute: (_) {},
        initialSelectedDispatchId: 'DSP-2439',
        onOpenReportForDispatch: (dispatchId) {
          openedReportDispatchId = dispatchId;
        },
      ),
    );
    await tester.pumpAndSettle();

    final viewReportButton = find.widgetWithText(OutlinedButton, 'VIEW REPORT');
    expect(viewReportButton, findsOneWidget);

    await tester.ensureVisible(viewReportButton);
    await tester.tap(viewReportButton);
    await tester.pumpAndSettle();

    expect(openedReportDispatchId, 'DSP-2439');
  });

  testWidgets('dispatch page supports client-wide scope focus', (tester) async {
    final now = DateTime.now().toUtc();

    await tester.pumpWidget(
      buildPage(
        clientId: 'CLIENT-001',
        siteId: '',
        onGenerate: () {},
        onIngestFeeds: () {},
        onExecute: (_) {},
        events: [
          DecisionCreated(
            eventId: 'decision-sandton',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 4)),
            dispatchId: 'DSP-1001',
            clientId: 'CLIENT-001',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
          DecisionCreated(
            eventId: 'decision-vallee',
            sequence: 2,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 2)),
            dispatchId: 'DSP-2001',
            clientId: 'CLIENT-001',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-VALLEE',
          ),
          DecisionCreated(
            eventId: 'decision-other',
            sequence: 3,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 1)),
            dispatchId: 'DSP-3001',
            clientId: 'CLIENT-999',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-OTHER',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('CLIENT-001 / REGION-GAUTENG / all sites'),
      findsOneWidget,
    );
    expect(find.text('DSP-1001'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dispatch-card-DSP-2001')),
      findsOneWidget,
    );
    expect(find.text('DSP-3001'), findsNothing);
  });

  testWidgets(
    'dispatch page renders desktop workspace shell and routes banner actions',
    (tester) async {
      tester.view.physicalSize = const Size(1680, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? openedReportDispatchId;

      await tester.pumpWidget(
        buildPage(
          onGenerate: () {},
          onIngestFeeds: () {},
          onExecute: (_) {},
          onOpenReportForDispatch: (dispatchId) {
            openedReportDispatchId = dispatchId;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('dispatch-workspace-status-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dispatch-workspace-panel-rail')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dispatch-workspace-panel-board')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dispatch-workspace-panel-context')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dispatch-workspace-command-receipt')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dispatch-workspace-focus-card')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('dispatch-workspace-filter-cleared')),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('dispatch-selected-board')),
          matching: find.text('DSP-2439'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('dispatch-workspace-focus-open-report')),
      );
      await tester.pumpAndSettle();

      expect(openedReportDispatchId, 'DSP-2439');
    },
  );

  testWidgets(
    'dispatch page recovers mission focus when the selected lane becomes empty',
    (tester) async {
      tester.view.physicalSize = const Size(1680, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now().toUtc();
      await tester.pumpWidget(
        buildPage(
          onGenerate: () {},
          onIngestFeeds: () {},
          onExecute: (_) {},
          clientId: 'CLIENT-RECOVERY',
          siteId: 'SITE-RECOVERY',
          events: [
            DecisionCreated(
              eventId: 'dispatch-recovery-decision',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 3)),
              dispatchId: 'DSP-RECOVERY',
              clientId: 'CLIENT-RECOVERY',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-RECOVERY',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('dispatch-workspace-focus-card')),
          matching: find.text('DSP-RECOVERY • SITE-RECOVERY'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('dispatch-workspace-filter-cleared')),
      );
      await tester.pumpAndSettle();

      expect(find.text('No mission is pinned in the board.'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('dispatch-workspace-focus-open-active-lanes'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey('dispatch-workspace-focus-open-active-lanes'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('dispatch-selected-board')),
          matching: find.text('DSP-RECOVERY'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('dispatch queue filter retargets the selected mission board', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(onGenerate: () {}, onIngestFeeds: () {}, onExecute: (_) {}),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dispatch-selected-board')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('dispatch-selected-board')),
        matching: find.text('DSP-2441'),
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('dispatch-queue-filter-cleared')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('dispatch-queue-filter-cleared')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dispatch-card-DSP-2439')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('dispatch-selected-board')),
        matching: find.text('DSP-2439'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('dispatch page restores watch action focus from parent state', (
    tester,
  ) async {
    var showPage = true;
    VideoFleetWatchActionDrilldown? persistedDrilldown;
    String? persistedSelectedDispatchId;
    late StateSetter hostSetState;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            hostSetState = setState;
            if (!showPage) {
              return const Scaffold(body: Center(child: Text('Away')));
            }
            return DispatchPage(
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              onGenerate: () {},
              onIngestFeeds: () {},
              onTelemetryImported: (_) {},
              onRunStress: (_) async {},
              onRunSoak: (_) async {},
              onRunBenchmarkSuite: () async {},
              initialProfile: IntakeStressPreset.light.profile,
              onProfileChanged: (_) {},
              onScenarioChanged: (scenarioLabel, tags) {},
              onRunNoteChanged: (_) {},
              onCancelStress: () {},
              onResetTelemetry: () {},
              onClearTelemetryPersistence: () {},
              onClearProfilePersistence: () {},
              stressRunning: false,
              intakeTelemetry: IntakeTelemetry.zero,
              events: const [],
              onExecute: (_) {},
              initialWatchActionDrilldown: persistedDrilldown,
              onWatchActionDrilldownChanged: (value) {
                hostSetState(() {
                  persistedDrilldown = value;
                });
              },
              initialSelectedDispatchId: persistedSelectedDispatchId,
              onSelectedDispatchChanged: (value) {
                hostSetState(() {
                  persistedSelectedDispatchId = value;
                });
              },
              fleetScopeHealth: const [
                VideoFleetScopeHealthView(
                  clientId: 'CLIENT-B',
                  siteId: 'SITE-B',
                  siteName: 'Beta Watch',
                  endpointLabel: '192.168.8.106',
                  statusLabel: 'LIMITED WATCH',
                  watchLabel: 'LIMITED',
                  recentEvents: 0,
                  lastSeenLabel: '21:14 UTC',
                  freshnessLabel: 'Recent',
                  isStale: false,
                  monitoringAvailabilityDetail:
                      'One remote camera feed is stale.',
                  latestIncidentReference: 'INT-BETA-1',
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('DSP-2442'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DSP-2442'));
    await tester.pumpAndSettle();
    expect(persistedSelectedDispatchId, 'DSP-2442');

    await tester.ensureVisible(find.text('Limited 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limited 1'));
    await tester.pumpAndSettle();
    expect(persistedDrilldown, VideoFleetWatchActionDrilldown.limited);
    expect(
      find.text('Focused watch action: Limited watch coverage'),
      findsOneWidget,
    );

    hostSetState(() {
      showPage = false;
    });
    await tester.pumpAndSettle();
    expect(find.text('Away'), findsOneWidget);

    hostSetState(() {
      showPage = true;
    });
    await tester.pumpAndSettle();

    expect(persistedDrilldown, VideoFleetWatchActionDrilldown.limited);
    expect(persistedSelectedDispatchId, 'DSP-2442');
    expect(
      find.text('Focused watch action: Limited watch coverage'),
      findsOneWidget,
    );
    expect(
      find.text('ACTIONABLE (1) • Incident-backed limited-watch scopes'),
      findsOneWidget,
    );
  });

  testWidgets('dispatch command actions invoke callbacks', (tester) async {
    var generateCalls = 0;
    var ingestFeedCalls = 0;
    var ingestRadioCalls = 0;
    var ingestCctvCalls = 0;
    var ingestWearableCalls = 0;
    var ingestNewsCalls = 0;
    var loadFeedCalls = 0;
    String? executedDispatch;

    await tester.binding.setSurfaceSize(const Size(1400, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      buildPage(
        onGenerate: () {
          generateCalls += 1;
        },
        onIngestFeeds: () {
          ingestFeedCalls += 1;
        },
        onIngestRadioOps: () {
          ingestRadioCalls += 1;
        },
        onIngestCctvEvents: () {
          ingestCctvCalls += 1;
        },
        onIngestWearableOps: () {
          ingestWearableCalls += 1;
        },
        onIngestNews: () {
          ingestNewsCalls += 1;
        },
        onLoadFeedFile: () {
          loadFeedCalls += 1;
        },
        onExecute: (dispatchId) {
          executedDispatch = dispatchId;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate Dispatch').first);
    await tester.pump();

    await tester.ensureVisible(find.text('Ingest Live Feeds').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingest Live Feeds').first);
    await tester.pump();

    await tester.ensureVisible(find.text('Ingest Radio Ops').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingest Radio Ops').first);
    await tester.pump();

    await tester.ensureVisible(find.text('Ingest CCTV Events').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingest CCTV Events').first);
    await tester.pump();

    await tester.ensureVisible(find.text('Ingest Wearable Ops').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingest Wearable Ops').first);
    await tester.pump();

    await tester.ensureVisible(find.text('Ingest News Intel').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingest News Intel').first);
    await tester.pump();

    await tester.ensureVisible(find.text('Load Feed File').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load Feed File').first);
    await tester.pump();

    await tester.ensureVisible(find.text('TRACK LOCATION').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('TRACK LOCATION').first);
    await tester.pumpAndSettle();

    expect(generateCalls, 1);
    expect(ingestFeedCalls, 1);
    expect(ingestRadioCalls, 1);
    expect(ingestCctvCalls, 1);
    expect(ingestWearableCalls, 1);
    expect(ingestNewsCalls, 1);
    expect(loadFeedCalls, 1);
    expect(executedDispatch, isNotNull);
  });

  testWidgets('dispatch page shows partner progression on selected dispatch', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(
        onGenerate: () {},
        onIngestFeeds: () {},
        initialSelectedDispatchId: 'DSP-8821',
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
            occurredAt: DateTime.utc(2026, 3, 15, 21, 10),
            dispatchId: 'DSP-8821',
            clientId: 'CLIENT-001',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
          PartnerDispatchStatusDeclared(
            eventId: 'partner-1',
            sequence: 3,
            version: 1,
            occurredAt: DateTime.utc(2026, 3, 15, 21, 11),
            dispatchId: 'DSP-8821',
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
            occurredAt: DateTime.utc(2026, 3, 15, 21, 14),
            dispatchId: 'DSP-8821',
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
            occurredAt: DateTime.utc(2026, 3, 15, 21, 19),
            dispatchId: 'DSP-8821',
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
        onExecute: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DSP-8821'), findsWidgets);
    expect(
      find.byKey(const ValueKey('dispatch-partner-progress-card-DSP-8821')),
      findsOneWidget,
    );
    expect(find.text('PARTNER PROGRESSION'), findsWidgets);
    expect(
      find.textContaining('PARTNER • Alpha • Latest ALL CLEAR'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dispatch-partner-trend-reason-DSP-8821')),
      findsOneWidget,
    );
    expect(
      find.text('Acceptance timing improved against the prior 7-day average.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dispatch-partner-progress-DSP-8821-accepted')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('dispatch-partner-progress-DSP-8821-onSite')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('dispatch-partner-progress-DSP-8821-allClear')),
      findsWidgets,
    );
    expect(
      find.byKey(
        const ValueKey('dispatch-partner-progress-DSP-8821-cancelled'),
      ),
      findsWidgets,
    );
    expect(find.text('Pending'), findsWidgets);
  });

  testWidgets('dispatch page shows radio queue diagnostics', (tester) async {
    await tester.pumpWidget(
      buildPage(
        onGenerate: () {},
        onIngestFeeds: () {},
        radioOpsQueueHealth:
            'pending 6 • due 2 • deferred 4 • max-attempt 3 • next 10:05:30 UTC',
        radioQueueIntentMix:
            'pending intent mix • all_clear 2 • panic 1 • duress 2 • status 1 • unknown 0',
        radioAckRecentSummary:
            'recent ack 7 (6h) • all_clear 3 • panic 2 • duress 1 • status 1',
        radioQueueHasPending: true,
        radioQueueFailureDetail:
            'TRX-9001 • attempts 3 • reason send_failed • next 10:05:30 UTC',
        radioQueueManualActionDetail:
            'Retry requested for 6 queued • 10:06:00 UTC',
        onExecute: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Radio Queue'), findsOneWidget);
    expect(find.text('Radio Queue Intent Mix'), findsOneWidget);
    expect(find.text('Radio ACK Recent'), findsOneWidget);
    expect(find.text('Radio Queue Failure'), findsOneWidget);
    expect(find.text('Radio Queue Manual'), findsOneWidget);
    expect(
      find.textContaining('pending 6 • due 2 • deferred 4'),
      findsOneWidget,
    );
    expect(
      find.textContaining('all_clear 2 • panic 1 • duress 2 • status 1'),
      findsOneWidget,
    );
    expect(
      find.textContaining('recent ack 7 (6h) • all_clear 3 • panic 2'),
      findsOneWidget,
    );
    expect(find.textContaining('TRX-9001 • attempts 3'), findsOneWidget);
    expect(find.textContaining('Retry requested for 6 queued'), findsOneWidget);
  });

  testWidgets('dispatch page shows cctv diagnostics', (tester) async {
    await tester.pumpWidget(
      buildPage(
        onGenerate: () {},
        onIngestFeeds: () {},
        cctvCapabilitySummary: 'caps LIVE AI MONITORING • FR • LPR',
        cctvRecentSignalSummary:
            'recent video intel 8 (6h) • intrusion 3 • line_crossing 2 • motion 1 • fr 2 • lpr 3',
        onExecute: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CCTV Capabilities'), findsOneWidget);
    expect(find.text('CCTV Signals Recent'), findsOneWidget);
    expect(
      find.textContaining('LIVE AI MONITORING • FR • LPR'),
      findsOneWidget,
    );
    expect(
      find.textContaining('recent video intel 8 (6h) • intrusion 3'),
      findsOneWidget,
    );
  });

  testWidgets('dispatch page switches video labels for DVR ops', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(
        onGenerate: () {},
        onIngestFeeds: () {},
        videoOpsLabel: 'DVR',
        cctvCapabilitySummary: 'caps LIVE AI MONITORING • FR • LPR',
        cctvRecentSignalSummary:
            'recent video intel 8 (6h) • intrusion 3 • line_crossing 2 • motion 1 • fr 2 • lpr 3',
        onExecute: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ingest DVR Events'), findsOneWidget);
    expect(find.text('DVR Capabilities'), findsOneWidget);
    expect(find.text('DVR Signals Recent'), findsOneWidget);
    expect(
      find.textContaining('recent video intel 8 (6h) • intrusion 3'),
      findsOneWidget,
    );
  });

  testWidgets('dispatch page invokes radio queue action callbacks', (
    tester,
  ) async {
    var retryCalls = 0;
    var clearCalls = 0;
    await tester.pumpWidget(
      buildPage(
        onGenerate: () {},
        onIngestFeeds: () {},
        radioQueueHasPending: true,
        onRetryRadioQueue: () {
          retryCalls += 1;
        },
        onClearRadioQueue: () {
          clearCalls += 1;
        },
        onExecute: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Retry Now').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry Now').first);
    await tester.pump();

    await tester.ensureVisible(find.text('Clear Queue').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Queue').first);
    await tester.pumpAndSettle();
    expect(find.text('Clear Radio Queue?'), findsOneWidget);
    await tester.tap(find.text('Confirm Clear').first);
    await tester.pumpAndSettle();

    expect(retryCalls, 1);
    expect(clearCalls, 1);
  });

  testWidgets('dispatch page cancel clear queue keeps callbacks untouched', (
    tester,
  ) async {
    var clearCalls = 0;
    await tester.pumpWidget(
      buildPage(
        onGenerate: () {},
        onIngestFeeds: () {},
        radioQueueHasPending: true,
        onClearRadioQueue: () {
          clearCalls += 1;
        },
        onExecute: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Clear Queue').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Queue').first);
    await tester.pumpAndSettle();
    expect(find.text('Clear Radio Queue?'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    expect(clearCalls, 0);
  });

  testWidgets('dispatch page shows actionable empty state for watch-only fleet', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(
        onGenerate: () {},
        onIngestFeeds: () {},
        fleetScopeHealth: const [
          VideoFleetScopeHealthView(
            clientId: 'CLIENT-B',
            siteId: 'SITE-B',
            siteName: 'Beta Watch',
            endpointLabel: '192.168.8.106',
            statusLabel: 'WATCH READY',
            watchLabel: 'SCHEDULED',
            recentEvents: 0,
            lastSeenLabel: 'idle',
            freshnessLabel: 'Idle',
            isStale: false,
            watchWindowLabel: '18:00-06:00',
            watchWindowStateLabel: 'IN WINDOW',
            alertCount: 1,
            repeatCount: 2,
            escalationCount: 1,
            suppressedCount: 3,
            lastRecoveryLabel: 'ADMIN • Resynced • 21:08 UTC',
            latestSceneDecisionLabel: 'Suppressed',
            latestSceneDecisionSummary:
                'Suppressed because the activity remained below the client notification threshold.',
            watchActivationGapLabel: 'MISSED START',
          ),
        ],
        onExecute: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('ACTIONABLE (0) • No incident-backed fleet scopes right now'),
      findsOneWidget,
    );
    expect(
      find.text('WATCH-ONLY (1) • Watch scopes awaiting incident context'),
      findsOneWidget,
    );
    expect(find.text('Gap 1'), findsOneWidget);
    expect(find.text('Recovered 6h 1'), findsOneWidget);
    expect(find.text('Suppressed 1'), findsOneWidget);
    expect(find.text('Alerts 1'), findsOneWidget);
    expect(find.text('Repeat 2'), findsOneWidget);
    expect(find.text('Escalated 1'), findsOneWidget);
    expect(find.text('Filtered 3'), findsOneWidget);
    expect(find.text('Recovery ADMIN • Resynced • 21:08 UTC'), findsOneWidget);
    await tester.ensureVisible(find.text('Alerts 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alerts 1'));
    await tester.pumpAndSettle();
    expect(find.text('Focused watch action: Alert actions'), findsOneWidget);
    expect(
      find.text('Showing fleet scopes where ONYX sent a client alert.'),
      findsOneWidget,
    );
    expect(
      find.text('ACTIONABLE (0) • No incident-backed alert scopes right now'),
      findsOneWidget,
    );
    expect(
      find.text('WATCH-ONLY (1) • Watch scopes with client alert actions'),
      findsOneWidget,
    );
    expect(find.text('Beta Watch'), findsOneWidget);
    expect(find.text('Gap MISSED START'), findsOneWidget);
  });

  testWidgets('dispatch page narrows fleet health to limited watch scopes', (
    tester,
  ) async {
    VideoFleetWatchActionDrilldown? selectedDrilldown;

    await tester.pumpWidget(
      buildPage(
        onGenerate: () {},
        onIngestFeeds: () {},
        fleetScopeHealth: const [
          VideoFleetScopeHealthView(
            clientId: 'CLIENT-A',
            siteId: 'SITE-A',
            siteName: 'MS Vallee Residence',
            endpointLabel: '192.168.8.105',
            statusLabel: 'LIMITED WATCH',
            watchLabel: 'LIMITED',
            recentEvents: 0,
            lastSeenLabel: 'idle',
            freshnessLabel: 'Idle',
            isStale: false,
            monitoringAvailabilityDetail: 'One remote camera feed is stale.',
            latestIncidentReference: 'INT-VALLEE-1',
          ),
          VideoFleetScopeHealthView(
            clientId: 'CLIENT-B',
            siteId: 'SITE-B',
            siteName: 'Sandton Tower',
            endpointLabel: '192.168.8.106',
            statusLabel: 'LIVE',
            watchLabel: 'ACTIVE',
            recentEvents: 1,
            lastSeenLabel: '21:14 UTC',
            freshnessLabel: 'Fresh',
            isStale: false,
            latestIncidentReference: 'INT-TOWER-1',
          ),
        ],
        onWatchActionDrilldownChanged: (value) {
          selectedDrilldown = value;
        },
        onExecute: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Limited 1'), findsOneWidget);
    await tester.ensureVisible(find.text('Limited 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limited 1'));
    await tester.pumpAndSettle();

    expect(selectedDrilldown, VideoFleetWatchActionDrilldown.limited);
    expect(
      find.text('Focused watch action: Limited watch coverage'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Showing fleet scopes where remote monitoring is active but limited.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('ACTIONABLE (1) • Incident-backed limited-watch scopes'),
      findsOneWidget,
    );
    expect(find.text('MS Vallee Residence'), findsOneWidget);
    expect(find.text('Sandton Tower'), findsNothing);
    expect(
      find.textContaining('One remote camera feed is stale.'),
      findsWidgets,
    );
  });

  testWidgets('dispatch page shows suppressed scene review panel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      buildPage(
        onGenerate: () {},
        onIngestFeeds: () {},
        fleetScopeHealth: const [
          VideoFleetScopeHealthView(
            clientId: 'CLIENT-B',
            siteId: 'SITE-B',
            siteName: 'Beta Watch',
            endpointLabel: '192.168.8.106',
            statusLabel: 'WATCH READY',
            watchLabel: 'SCHEDULED',
            recentEvents: 1,
            lastSeenLabel: '21:14 UTC',
            freshnessLabel: 'Recent',
            isStale: false,
            suppressedCount: 1,
            latestIncidentReference: 'INT-BETA-1',
            latestCameraLabel: 'Camera 2',
            latestSceneDecisionLabel: 'Suppressed',
            latestSceneDecisionSummary:
                'Suppressed because the activity remained below the client notification threshold.',
          ),
        ],
        sceneReviewByIntelligenceId: {
          'INT-BETA-1': MonitoringSceneReviewRecord(
            intelligenceId: 'INT-BETA-1',
            sourceLabel: 'openai:gpt-4.1-mini',
            postureLabel: 'reviewed',
            decisionLabel: 'Suppressed',
            decisionSummary:
                'Suppressed because the activity remained below the client notification threshold.',
            summary: 'Vehicle remained below escalation threshold.',
            reviewedAtUtc: DateTime.utc(2026, 3, 13, 21, 14),
          ),
        },
        onExecute: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Filtered 1'));
    await tester.pumpAndSettle();
    final beforeTapOffset = scrollable.position.pixels;
    await tester.tap(find.text('Filtered 1'));
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, greaterThan(beforeTapOffset));
    expect(find.text('Focused watch action: Filtered reviews'), findsOneWidget);
    final textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(
      textWidgets.indexWhere(
        (widget) => widget.data == 'Suppressed CCTV Reviews',
      ),
      lessThan(
        textWidgets.indexWhere((widget) => widget.data == 'CCTV Fleet Health'),
      ),
    );
    expect(find.text('Suppressed CCTV Reviews'), findsOneWidget);
    expect(find.text('Internal 1'), findsOneWidget);
    expect(find.text('Beta Watch'), findsWidgets);
    expect(find.text('Action Suppressed'), findsOneWidget);
    expect(find.text('Camera Camera 2'), findsWidgets);
    expect(find.text('Posture reviewed'), findsOneWidget);
    expect(
      find.textContaining(
        'Suppressed because the activity remained below the client notification threshold.',
      ),
      findsWidgets,
    );
    expect(
      find.text('Scene review: Vehicle remained below escalation threshold.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'dispatch fleet actions pass incident reference and ignore watch-only scopes',
    (tester) async {
      String? tappedTacticalClientId;
      String? tappedTacticalSiteId;
      String? tappedTacticalReference;
      String? tappedDispatchClientId;
      String? tappedDispatchSiteId;
      String? tappedDispatchReference;
      String? recoveredClientId;
      String? recoveredSiteId;

      await tester.pumpWidget(
        buildPage(
          onGenerate: () {},
          onIngestFeeds: () {},
          fleetScopeHealth: const [
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-A',
              siteId: 'SITE-A',
              siteName: 'MS Vallee Residence',
              endpointLabel: '192.168.8.105',
              statusLabel: 'LIVE',
              watchLabel: 'ACTIVE',
              recentEvents: 2,
              lastSeenLabel: '21:14 UTC',
              freshnessLabel: 'Fresh',
              isStale: false,
              escalationCount: 1,
              actionHistory: [
                '21:13 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
                '21:12 UTC • Camera 3 • Escalation Candidate • Escalated for urgent review because perimeter activity remained high confidence.',
                '21:10 UTC • Camera 4 • Escalation Candidate • Escalated for urgent review because the vehicle remained in a restricted zone.',
              ],
              watchWindowLabel: '18:00-06:00',
              watchWindowStateLabel: 'IN WINDOW',
              latestEventLabel: 'Vehicle motion',
              latestIncidentReference: 'INT-VALLEE-1',
              latestEventTimeLabel: '21:14 UTC',
              latestCameraLabel: 'Camera 1',
              latestRiskScore: 84,
              latestFaceMatchId: 'PERSON-44',
              latestFaceConfidence: 91.2,
              latestPlateNumber: 'CA123456',
              latestPlateConfidence: 96.4,
              latestSceneReviewLabel:
                  'openai:gpt-4.1-mini • identity match concern • 21:14 UTC',
              latestSceneDecisionSummary:
                  'Escalated for urgent review because face match PERSON-44 was flagged and the event metadata suggested an unauthorized or watchlist context.',
            ),
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-B',
              siteId: 'SITE-B',
              siteName: 'Beta Watch',
              endpointLabel: '192.168.8.106',
              statusLabel: 'WATCH READY',
              watchLabel: 'SCHEDULED',
              recentEvents: 0,
              lastSeenLabel: 'idle',
              freshnessLabel: 'Idle',
              isStale: false,
              watchWindowLabel: '18:00-06:00',
              watchWindowStateLabel: 'IN WINDOW',
              watchActivationGapLabel: 'MISSED START',
            ),
          ],
          onOpenFleetTacticalScope: (clientId, siteId, incidentReference) {
            tappedTacticalClientId = clientId;
            tappedTacticalSiteId = siteId;
            tappedTacticalReference = incidentReference;
          },
          onOpenFleetDispatchScope: (clientId, siteId, incidentReference) {
            tappedDispatchClientId = clientId;
            tappedDispatchSiteId = siteId;
            tappedDispatchReference = incidentReference;
          },
          onRecoverFleetWatchScope: (clientId, siteId) {
            recoveredClientId = clientId;
            recoveredSiteId = siteId;
          },
          onExecute: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('dispatch-fleet-summary-command')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dispatch-fleet-summary-tile-flagged-id')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dispatch-fleet-scope-command-SITE-A')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dispatch-fleet-scope-identity-SITE-A')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dispatch-fleet-scope-posture-SITE-A')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dispatch-fleet-scope-context-SITE-A')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dispatch-fleet-scope-latest-SITE-A')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dispatch-fleet-scope-feed-SITE-A')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dispatch-fleet-scope-actions-SITE-A')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dispatch-fleet-scope-command-SITE-B')),
        findsOneWidget,
      );
      expect(find.text('Window 18:00-06:00'), findsNWidgets(2));
      expect(find.text('Phase IN WINDOW'), findsNWidgets(2));
      expect(
        find.textContaining('Identity policy: Flagged match'),
        findsOneWidget,
      );
      expect(find.text('Identity Flagged'), findsOneWidget);
      expect(find.text('Flagged ID 1'), findsOneWidget);
      expect(find.text('Allowed ID 0'), findsOneWidget);
      expect(
        find.textContaining(
          'Identity match: Face PERSON-44 91.2% • Plate CA123456 96.4%',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Flagged ID 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flagged ID 1'));
      await tester.pumpAndSettle();
      expect(
        find.text('Focused identity policy: Flagged identity matches'),
        findsOneWidget,
      );
      tappedDispatchClientId = null;
      tappedDispatchSiteId = null;
      tappedDispatchReference = null;
      await tester.ensureVisible(
        find.textContaining(
          'Flagged identity: Face PERSON-44 91.2% • Plate CA123456 96.4%',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.textContaining(
          'Flagged identity: Face PERSON-44 91.2% • Plate CA123456 96.4%',
        ),
      );
      await tester.pumpAndSettle();
      expect(tappedDispatchClientId, 'CLIENT-A');
      expect(tappedDispatchSiteId, 'SITE-A');
      expect(tappedDispatchReference, 'INT-VALLEE-1');
      await tester.ensureVisible(find.text('Clear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('MS Vallee Residence').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('MS Vallee Residence').first);
      await tester.pumpAndSettle();
      expect(tappedDispatchClientId, 'CLIENT-A');
      expect(tappedDispatchSiteId, 'SITE-A');
      expect(tappedDispatchReference, 'INT-VALLEE-1');

      await tester.ensureVisible(find.text('Tactical').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tactical').first);
      await tester.pumpAndSettle();
      expect(tappedTacticalClientId, 'CLIENT-A');
      expect(tappedTacticalSiteId, 'SITE-A');
      expect(tappedTacticalReference, 'INT-VALLEE-1');

      await tester.ensureVisible(find.text('Escalated 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escalated 1'));
      await tester.pumpAndSettle();
      expect(
        find.text('Focused watch action: Escalated reviews'),
        findsOneWidget,
      );
      final textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
      expect(
        textWidgets.indexWhere((widget) => widget.data == 'CCTV Fleet Health'),
        lessThan(
          textWidgets.indexWhere(
            (widget) => widget.data == 'Radio Ops • UNCONFIGURED',
          ),
        ),
      );
      expect(find.text('Beta Watch'), findsNothing);
      expect(find.text('MS Vallee Residence'), findsOneWidget);
      expect(
        find.textContaining(
          'Recent escalations: 21:12 UTC • Camera 3 • Escalation Candidate',
        ),
        findsOneWidget,
      );
      tappedDispatchClientId = null;
      tappedDispatchSiteId = null;
      tappedDispatchReference = null;
      await tester.ensureVisible(
        find.textContaining(
          'Recent escalations: 21:12 UTC • Camera 3 • Escalation Candidate',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.textContaining(
          'Recent escalations: 21:12 UTC • Camera 3 • Escalation Candidate',
        ),
      );
      await tester.pumpAndSettle();
      expect(tappedDispatchClientId, 'CLIENT-A');
      expect(tappedDispatchSiteId, 'SITE-A');
      expect(tappedDispatchReference, 'INT-VALLEE-1');
      expect(
        find.textContaining('Recent action: 21:13 UTC • Camera 2'),
        findsOneWidget,
      );
      expect(find.text('Latest: 21:14 UTC • Vehicle motion'), findsNothing);
      await tester.ensureVisible(find.text('Clear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Resync').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resync').first);
      await tester.pumpAndSettle();
      expect(recoveredClientId, 'CLIENT-B');
      expect(recoveredSiteId, 'SITE-B');

      tappedDispatchClientId = null;
      tappedDispatchSiteId = null;
      tappedDispatchReference = null;
      await tester.ensureVisible(find.text('Beta Watch').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beta Watch').first);
      await tester.pumpAndSettle();
      expect(tappedDispatchClientId, isNull);
      expect(tappedDispatchSiteId, isNull);
      expect(tappedDispatchReference, isNull);
    },
  );

  testWidgets('temporary identity summary opens incident-backed dispatch scope detail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1680, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    String? tappedDispatchClientId;
    String? tappedDispatchSiteId;
    String? tappedDispatchReference;
    String? extendedSite;
    String? expiredSite;

    await tester.pumpWidget(
      buildPage(
        onGenerate: () {},
        onIngestFeeds: () {},
        onOpenFleetDispatchScope: (clientId, siteId, incidentReference) {
          tappedDispatchClientId = clientId;
          tappedDispatchSiteId = siteId;
          tappedDispatchReference = incidentReference;
        },
        onExtendTemporaryIdentityApproval: (scope) async {
          extendedSite = scope.siteName;
          return 'Extended ${scope.siteName}.';
        },
        onExpireTemporaryIdentityApproval: (scope) async {
          expiredSite = scope.siteName;
          return 'Expired ${scope.siteName}.';
        },
        fleetScopeHealth: const [
          VideoFleetScopeHealthView(
            clientId: 'CLIENT-A',
            siteId: 'SITE-A',
            siteName: 'MS Vallee Residence',
            endpointLabel: '192.168.8.105',
            statusLabel: 'LIVE',
            watchLabel: 'ACTIVE',
            recentEvents: 1,
            lastSeenLabel: '21:14 UTC',
            freshnessLabel: 'Fresh',
            isStale: false,
            latestIncidentReference: 'INT-VALLEE-1',
            latestEventTimeLabel: '21:14 UTC',
            latestCameraLabel: 'Camera 1',
            latestFaceMatchId: 'VISITOR-01',
            latestFaceConfidence: 93.1,
            latestPlateNumber: 'CA777777',
            latestPlateConfidence: 97.4,
            latestSceneReviewLabel:
                'openai:gpt-4.1-mini • known allowed identity • 21:14 UTC',
            latestSceneDecisionSummary:
                'Suppressed because the matched identity has a one-time approval until 2026-03-15 18:00 UTC and the activity remained below the client notification threshold.',
          ),
        ],
        onExecute: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Temporary ID 1'), findsOneWidget);
    expect(
      find.textContaining(
        'Identity policy: Temporary approval until 2026-03-15 18:00 UTC',
      ),
      findsOneWidget,
    );
    expect(find.text('Identity Temporary'), findsOneWidget);
    await tester.ensureVisible(find.text('Temporary ID 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temporary ID 1'));
    await tester.pumpAndSettle();
    expect(
      find.text('Focused identity policy: Temporary identity approvals'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Showing fleet scopes where ONYX matched a one-time approved face or plate. Each scope shows the approval expiry when available.',
      ),
      findsOneWidget,
    );
    expect(find.text('Extend 2h'), findsOneWidget);
    expect(find.text('Expire now'), findsOneWidget);
    await tester.tap(find.text('Extend 2h'));
    await tester.pumpAndSettle();
    expect(extendedSite, 'MS Vallee Residence');
    expect(
      find.byKey(const ValueKey('dispatch-workspace-command-receipt')),
      findsOneWidget,
    );
    expect(find.text('Extended MS Vallee Residence.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await tester.tap(find.text('Expire now'));
    await tester.pumpAndSettle();
    expect(find.text('Expire Temporary Approval?'), findsOneWidget);
    expect(
      find.textContaining(
        'This immediately removes the temporary identity approval for MS Vallee Residence.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Expire now'));
    await tester.pumpAndSettle();
    expect(expiredSite, 'MS Vallee Residence');
    expect(find.text('Expired MS Vallee Residence.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await tester.ensureVisible(
      find.textContaining(
        'Temporary identity until 2026-03-15 18:00 UTC: Face VISITOR-01 93.1% • Plate CA777777 97.4%',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.textContaining(
        'Temporary identity until 2026-03-15 18:00 UTC: Face VISITOR-01 93.1% • Plate CA777777 97.4%',
      ),
    );
    await tester.pumpAndSettle();
    expect(tappedDispatchClientId, 'CLIENT-A');
    expect(tappedDispatchSiteId, 'SITE-A');
    expect(tappedDispatchReference, 'INT-VALLEE-1');
  });

  testWidgets(
    'allowlisted identity summary opens incident-backed dispatch scope detail',
    (tester) async {
      String? tappedDispatchClientId;
      String? tappedDispatchSiteId;
      String? tappedDispatchReference;

      await tester.pumpWidget(
        buildPage(
          onGenerate: () {},
          onIngestFeeds: () {},
          onOpenFleetDispatchScope: (clientId, siteId, incidentReference) {
            tappedDispatchClientId = clientId;
            tappedDispatchSiteId = siteId;
            tappedDispatchReference = incidentReference;
          },
          fleetScopeHealth: const [
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-A',
              siteId: 'SITE-A',
              siteName: 'MS Vallee Residence',
              endpointLabel: '192.168.8.105',
              statusLabel: 'LIVE',
              watchLabel: 'ACTIVE',
              recentEvents: 1,
              lastSeenLabel: '21:14 UTC',
              freshnessLabel: 'Fresh',
              isStale: false,
              latestIncidentReference: 'INT-VALLEE-1',
              latestEventTimeLabel: '21:14 UTC',
              latestCameraLabel: 'Camera 1',
              latestFaceMatchId: 'RESIDENT-01',
              latestFaceConfidence: 94.1,
              latestPlateNumber: 'CA111111',
              latestPlateConfidence: 98.0,
              latestSceneReviewLabel:
                  'openai:gpt-4.1-mini • known allowed identity • 21:14 UTC',
              latestSceneDecisionSummary:
                  'Suppressed because RESIDENT-01 and plate CA111111 are allowlisted for this site.',
            ),
          ],
          onExecute: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Allowed ID 1'), findsOneWidget);
      expect(find.text('Identity Allowlisted'), findsOneWidget);
      await tester.ensureVisible(find.text('Allowed ID 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allowed ID 1'));
      await tester.pumpAndSettle();
      expect(
        find.text('Focused identity policy: Allowlisted identity matches'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.textContaining(
          'Allowlisted identity: Face RESIDENT-01 94.1% • Plate CA111111 98.0%',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.textContaining(
          'Allowlisted identity: Face RESIDENT-01 94.1% • Plate CA111111 98.0%',
        ),
      );
      await tester.pumpAndSettle();
      expect(tappedDispatchClientId, 'CLIENT-A');
      expect(tappedDispatchSiteId, 'SITE-A');
      expect(tappedDispatchReference, 'INT-VALLEE-1');
    },
  );
}
