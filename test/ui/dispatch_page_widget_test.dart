import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/infrastructure/intelligence/news_intelligence_service.dart';
import 'package:omnix_dashboard/ui/dispatch_page.dart';

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
    String videoOpsLabel = 'CCTV',
    String? cctvCapabilitySummary,
    String? cctvRecentSignalSummary,
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
}
