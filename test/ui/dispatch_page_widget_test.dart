import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/infrastructure/intelligence/news_intelligence_service.dart';
import 'package:omnix_dashboard/ui/dispatch_page.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_sections.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_view.dart';

void main() {
  Widget buildPage({
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
    required ValueChanged<String> onExecute,
  }) {
    return MaterialApp(
      home: DispatchPage(
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
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
        events: const [],
        onExecute: onExecute,
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
                  statusLabel: 'WATCH READY',
                  watchLabel: 'SCHEDULED',
                  recentEvents: 1,
                  lastSeenLabel: '21:14 UTC',
                  freshnessLabel: 'Recent',
                  isStale: false,
                  alertCount: 1,
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

    await tester.ensureVisible(find.text('Alerts 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alerts 1'));
    await tester.pumpAndSettle();
    expect(persistedDrilldown, VideoFleetWatchActionDrilldown.alerts);
    expect(find.text('Focused watch action: Alert actions'), findsOneWidget);

    hostSetState(() {
      showPage = false;
    });
    await tester.pumpAndSettle();
    expect(find.text('Away'), findsOneWidget);

    hostSetState(() {
      showPage = true;
    });
    await tester.pumpAndSettle();

    expect(persistedDrilldown, VideoFleetWatchActionDrilldown.alerts);
    expect(persistedSelectedDispatchId, 'DSP-2442');
    expect(find.text('Focused watch action: Alert actions'), findsOneWidget);
    expect(
      find.text('WATCH-ONLY (1) • Watch scopes with client alert actions'),
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
      await tester.tap(
        find.textContaining(
          'Flagged identity: Face PERSON-44 91.2% • Plate CA123456 96.4%',
        ),
      );
      await tester.pumpAndSettle();
      expect(tappedDispatchClientId, 'CLIENT-A');
      expect(tappedDispatchSiteId, 'SITE-A');
      expect(tappedDispatchReference, 'INT-VALLEE-1');
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
        findsNothing,
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
        'Showing fleet scopes where ONYX matched a one-time approved face or plate. Each scope shows the approval expiry when available. Soonest expiry: MS Vallee Residence Temporary approval expires in',
      ),
      findsOneWidget,
    );
    expect(find.text('Extend 2h'), findsOneWidget);
    expect(find.text('Expire now'), findsOneWidget);
    await tester.tap(find.text('Extend 2h'));
    await tester.pumpAndSettle();
    expect(extendedSite, 'MS Vallee Residence');
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
