import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/infrastructure/intelligence/news_intelligence_service.dart';
import 'package:omnix_dashboard/ui/dispatch_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? clipboardText;

  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              final args = Map<String, dynamic>.from(call.arguments as Map);
              clipboardText = args['text'] as String?;
              return null;
            case 'Clipboard.getData':
              if (clipboardText == null) return null;
              return {'text': clipboardText};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('dispatch control actions invoke callbacks', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var resetCalled = 0;
    var clearHistoryCalled = 0;
    var clearPollHealthCalled = 0;
    var clearSavedViewsCalled = 0;
    var clearProfileCalled = 0;
    var loadFeedCalled = 0;
    var ingestNewsCalled = 0;
    var startPollingCalled = 0;
    var stopPollingCalled = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DispatchPage(
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          onGenerate: () {},
          onIngestFeeds: () {},
          onIngestNews: () {
            ingestNewsCalled += 1;
          },
          onProbeNewsSource: (_) {},
          newsSourceDiagnostics: const [
            NewsSourceDiagnostic(
              provider: 'newsapi.org',
              status: 'missing key',
              detail: 'Set ONYX_NEWSAPI_ORG_KEY.',
              checkedAtUtc: '2020-03-04T10:00:00Z',
            ),
            NewsSourceDiagnostic(
              provider: 'openweather.org',
              status: 'missing site coords',
              detail: 'Requires ONYX_SITE_LAT and ONYX_SITE_LON.',
            ),
          ],
          newsSourceRequirementsHint:
              'Add at least one ONYX_* news source key or ONYX_COMMUNITY_FEED_JSON.',
          runtimeConfigHint:
              'Supabase is running in-memory because SUPABASE_URL or SUPABASE_ANON_KEY is not configured. Run with local defines: ./scripts/run_onyx_chrome_local.sh Live feed polling is disabled until ONYX_LIVE_FEED_URL is replaced.',
          onLoadFeedFile: () {
            loadFeedCalled += 1;
          },
          onStartLivePolling: () {
            startPollingCalled += 1;
          },
          onStopLivePolling: () {
            stopPollingCalled += 1;
          },
          onRunStress: (_) async {},
          onRunSoak: (_) async {},
          onRunBenchmarkSuite: () async {},
          initialProfile: IntakeStressPreset.medium.profile,
          initialFilterPresets: const [
            DispatchBenchmarkFilterPreset(
              name: 'Ops View',
              showCancelledRuns: true,
              statusFilters: ['IMPROVED', 'STABLE', 'DEGRADED'],
            ),
          ],
          onProfileChanged: (_) {},
          onScenarioChanged: (scenarioLabel, tags) {},
          onRunNoteChanged: (_) {},
          onTelemetryImported: (_) {},
          onCancelStress: () {},
          onResetTelemetry: () {
            resetCalled += 1;
          },
          onClearTelemetryPersistence: () {
            clearHistoryCalled += 1;
          },
          onClearLivePollHealth: () {
            clearPollHealthCalled += 1;
          },
          onClearProfilePersistence: () {
            clearProfileCalled += 1;
          },
          onClearSavedViewsPersistence: () {
            clearSavedViewsCalled += 1;
          },
          stressRunning: false,
          intakeTelemetry: IntakeTelemetry.zero,
          events: const [],
          onExecute: (_) {},
        ),
      ),
    );

    expect(find.text('News Sources Detected: none'), findsOneWidget);
    expect(
      find.text(
        'Provider Health: 0 reachable / 0 configured / 0 failed / 1 stale / 2 missing',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Missing Config: Add at least one ONYX_* news source key or ONYX_COMMUNITY_FEED_JSON.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Supabase is running in-memory because SUPABASE_URL or SUPABASE_ANON_KEY is not configured. Run with local defines: ./scripts/run_onyx_chrome_local.sh Live feed polling is disabled until ONYX_LIVE_FEED_URL is replaced.',
      ),
      findsOneWidget,
    );
    expect(find.text('News Source Diagnostics'), findsOneWidget);

    await tester.tap(
      find.text(
        'Provider Health: 0 reachable / 0 configured / 0 failed / 1 stale / 2 missing',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('News Source Diagnostics'), findsWidgets);
    expect(find.text('Showing: all providers (2)'), findsOneWidget);
    expect(find.text('Filter: All'), findsOneWidget);
    expect(find.text('All: 2'), findsOneWidget);
    expect(find.text('Reachable: 0'), findsOneWidget);
    expect(find.text('Stale: 1'), findsOneWidget);
    expect(find.text('Missing: 2'), findsOneWidget);
    expect(find.text('newsapi.org: missing key'), findsOneWidget);
    expect(find.text('Diagnostics Drilldown'), findsOneWidget);
    expect(
      find.textContaining('Detail: Set ONYX_NEWSAPI_ORG_KEY.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Last Checked: 2020-03-04T10:00:00Z'),
      findsOneWidget,
    );
    expect(find.text('Stale'), findsOneWidget);
    expect(find.text('openweather.org: missing site coords'), findsOneWidget);
    expect(find.text('Copy Checklist (2)'), findsOneWidget);
    expect(find.text('Run Probe'), findsNothing);
    expect(find.text('Run Probe (Unavailable)'), findsOneWidget);

    final disabledRunProbeButtons = tester.widgetList<TextButton>(
      find.widgetWithText(TextButton, 'Run Probe (Unavailable)'),
    );
    for (final button in disabledRunProbeButtons) {
      expect(button.onPressed, isNull);
    }

    await tester.tap(find.text('Reachable: 0'));
    await tester.pumpAndSettle();

    expect(find.text('Filter: All'), findsOneWidget);
    expect(find.text('Reset Filter'), findsNothing);
    expect(find.text('openweather.org: missing site coords'), findsOneWidget);

    await tester.tap(find.text('Stale: 1').first);
    await tester.pumpAndSettle();

    expect(find.text('Filter: Stale'), findsOneWidget);
    expect(find.text('Reset Filter'), findsOneWidget);
    expect(find.text('newsapi.org: missing key'), findsOneWidget);
    expect(find.text('openweather.org: missing site coords'), findsNothing);
    expect(find.text('Copy Checklist (1)'), findsOneWidget);

    await tester.tap(find.text('Reset Filter'));
    await tester.pumpAndSettle();

    expect(find.text('Filter: All'), findsOneWidget);
    expect(find.text('Reset Filter'), findsNothing);
    expect(find.text('openweather.org: missing site coords'), findsOneWidget);

    await tester.tap(find.text('Copy Checklist (2)'));
    await tester.pump();

    expect(
      clipboardText,
      'newsapi.org: missing key\n'
      'Set ONYX_NEWSAPI_ORG_KEY.\n\n'
      'openweather.org: missing site coords\n'
      'Requires ONYX_SITE_LAT and ONYX_SITE_LON.',
    );

    await tester.tap(find.text('Close').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reset Telemetry'));
    await tester.pump();
    await tester.tap(find.text('Clear Saved History'));
    await tester.pump();
    await tester.ensureVisible(find.text('Clear Poll Health'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Poll Health'));
    await tester.pump();
    await tester.ensureVisible(find.text('Clear Saved Views'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Saved Views'));
    await tester.pump();
    await tester.ensureVisible(find.text('Clear Saved Draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Saved Draft'));
    await tester.pump();
    final page = tester.widget<DispatchPage>(find.byType(DispatchPage));
    page.onIngestNews?.call();
    await tester.pump();
    page.onLoadFeedFile?.call();
    await tester.pump();
    page.onStartLivePolling?.call();
    await tester.pump();

    expect(resetCalled, 1);
    expect(clearHistoryCalled, 1);
    expect(clearPollHealthCalled, 1);
    expect(clearSavedViewsCalled, 1);
    expect(clearProfileCalled, 1);
    expect(ingestNewsCalled, 1);
    expect(loadFeedCalled, 1);
    expect(startPollingCalled, 1);
    expect(stopPollingCalled, 0);
  });

  testWidgets('news source diagnostics can trigger probe callbacks', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final probedProviders = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: DispatchPage(
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          onGenerate: () {},
          onIngestFeeds: () {},
          onIngestNews: () {},
          configuredNewsSources: const ['newsapi.org', 'newsdata.io'],
          newsSourceDiagnostics: const [
            NewsSourceDiagnostic(
              provider: 'newsapi.org',
              status: 'configured',
              detail: 'Ready via ONYX_NEWSAPI_ORG_KEY.',
              checkedAtUtc: '2020-03-04T10:00:00Z',
            ),
            NewsSourceDiagnostic(
              provider: 'newsdata.io',
              status: 'reachable',
              detail: 'Provider responded with 2 ingestible records.',
              checkedAtUtc: '2999-03-04T10:05:00Z',
            ),
            NewsSourceDiagnostic(
              provider: 'openweather.org',
              status: 'missing site coords',
              detail: 'Requires ONYX_SITE_LAT and ONYX_SITE_LON.',
            ),
          ],
          onProbeNewsSource: (provider) {
            probedProviders.add(provider);
          },
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
          onExecute: (_) {},
        ),
      ),
    );

    await tester.tap(
      find.text('News Sources Detected: newsapi.org, newsdata.io'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Configured News Sources'), findsOneWidget);
    expect(find.text('Showing: configured providers only (2)'), findsOneWidget);
    expect(find.text('All: 2'), findsOneWidget);
    expect(find.text('Reachable: 1'), findsOneWidget);
    expect(find.text('Stale: 1'), findsOneWidget);
    expect(find.text('Missing: 0'), findsOneWidget);
    expect(find.text('newsapi.org: configured'), findsOneWidget);
    expect(find.text('newsdata.io: reachable'), findsOneWidget);
    expect(find.text('openweather.org: missing site coords'), findsNothing);
    expect(
      find.text('2 probeable providers in the current filter.'),
      findsOneWidget,
    );
    expect(
      find.text('2 rows available to copy in the current filter.'),
      findsOneWidget,
    );
    expect(find.text('Diagnostics Drilldown'), findsOneWidget);
    expect(find.textContaining('Status Class: stale'), findsOneWidget);
    expect(
      find.textContaining('Failure Trace: stale probe result'),
      findsOneWidget,
    );
    expect(find.text('Reprobe All Configured (2)'), findsOneWidget);
    expect(find.text('Reprobe Stale (1)'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('News Source Diagnostics'));
    await tester.pumpAndSettle();
    expect(find.text('Run Probe'), findsOneWidget);
    expect(find.text('Run Probe (Unavailable)'), findsNothing);
    expect(find.text('Diagnostics Drilldown'), findsOneWidget);
    expect(find.textContaining('Status Class: stale'), findsOneWidget);
    expect(
      find.text('2 probeable providers in the current filter.'),
      findsOneWidget,
    );
    expect(
      find.text('3 rows available to copy in the current filter.'),
      findsOneWidget,
    );
    expect(find.text('Reprobe All Configured (2)'), findsOneWidget);
    expect(find.text('Reprobe Stale (1)'), findsOneWidget);

    await tester.tap(find.text('Missing: 1'));
    await tester.pumpAndSettle();

    final reprobeAllDisabled = tester.widget<TextButton>(
      find.widgetWithText(
        TextButton,
        'Reprobe All Configured (Unavailable: 0)',
      ),
    );
    final reprobeStaleDisabled = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Reprobe Stale (Unavailable: 0)'),
    );
    expect(reprobeAllDisabled.onPressed, isNull);
    expect(reprobeStaleDisabled.onPressed, isNull);
    expect(
      find.text('No probeable providers in the current filter.'),
      findsOneWidget,
    );
    expect(
      find.text('1 row available to copy in the current filter.'),
      findsOneWidget,
    );

    await tester.tap(find.text('All: 3'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reprobe Stale (1)'));
    await tester.pumpAndSettle();

    expect(probedProviders, ['newsapi.org']);

    probedProviders.clear();

    await tester.tap(find.text('News Source Diagnostics'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reprobe All Configured (2)'));
    await tester.pumpAndSettle();

    expect(probedProviders, ['newsapi.org', 'newsdata.io']);
  });

  testWidgets('system status surfaces runtime wiring badges', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: DispatchPage(
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          onGenerate: () {},
          onIngestFeeds: () {},
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
          events: const [],
          onExecute: (_) {},
          supabaseReady: true,
          guardSyncBackendEnabled: true,
          telemetryProviderReadiness: 'ready',
          telemetryProviderActiveId: 'fsk_sdk',
          telemetryProviderExpectedId: 'fsk_sdk',
          telemetryAdapterStubMode: false,
          telemetryLiveReadyGateEnabled: true,
          telemetryLiveReadyGateViolation: false,
          telemetryLiveReadyGateReason: 'live-ready gate satisfied',
        ),
      ),
    );

    expect(find.text('SUPABASE: LIVE'), findsOneWidget);
    expect(find.text('GUARD SYNC: BACKEND'), findsOneWidget);
    expect(find.text('TELEMETRY: LIVE'), findsOneWidget);
    expect(find.text('GATE: OK'), findsOneWidget);
    expect(
      find.text('Telemetry provider: fsk_sdk / fsk_sdk • readiness: ready'),
      findsOneWidget,
    );
    expect(
      find.text('Telemetry gate reason: live-ready gate satisfied'),
      findsOneWidget,
    );
  });

  testWidgets('news source diagnostics disables copy when no rows exist', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: DispatchPage(
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          onGenerate: () {},
          onIngestFeeds: () {},
          onIngestNews: () {},
          configuredNewsSources: const [],
          newsSourceDiagnostics: const [],
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
          onExecute: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('News Source Diagnostics'));
    await tester.pumpAndSettle();

    expect(find.text('Showing: all providers (0)'), findsOneWidget);
    expect(find.text('Filter: All'), findsOneWidget);
    expect(
      find.text('No news source diagnostics are available.'),
      findsOneWidget,
    );
    expect(
      find.text('No rows available to copy in the current filter.'),
      findsOneWidget,
    );

    final copyButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Copy Checklist (0)'),
    );
    expect(copyButton.onPressed, isNull);
  });

  testWidgets('placeholder news source diagnostics count as missing, not configured', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: DispatchPage(
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          onGenerate: () {},
          onIngestFeeds: () {},
          onIngestNews: () {},
          newsSourceDiagnostics: const [
            NewsSourceDiagnostic(
              provider: 'newsapi.org',
              status: 'missing key (placeholder)',
              detail: 'Replace the placeholder ONYX_NEWSAPI_ORG_KEY value.',
            ),
            NewsSourceDiagnostic(
              provider: 'worldnewsapi.com',
              status: 'missing key (placeholder)',
              detail: 'Replace the placeholder ONYX_WORLDNEWSAPI_KEY value.',
            ),
            NewsSourceDiagnostic(
              provider: 'community-feed',
              status: 'configured',
              detail: 'Ready via ONYX_COMMUNITY_FEED_JSON.',
            ),
          ],
          newsSourceRequirementsHint:
              'Replace the placeholder ONYX_NEWSAPI_ORG_KEY value | Replace the placeholder ONYX_WORLDNEWSAPI_KEY value',
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
          onExecute: (_) {},
        ),
      ),
    );

    expect(find.text('News Sources Detected: none'), findsOneWidget);
    expect(
      find.text(
        'Provider Health: 0 reachable / 1 configured / 0 failed / 0 stale / 2 missing',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Missing Config: Replace the placeholder ONYX_NEWSAPI_ORG_KEY value | Replace the placeholder ONYX_WORLDNEWSAPI_KEY value',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.text(
        'Provider Health: 0 reachable / 1 configured / 0 failed / 0 stale / 2 missing',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('newsapi.org: missing key (placeholder)'), findsOneWidget);
    expect(find.text('Diagnostics Drilldown'), findsOneWidget);
    expect(
      find.textContaining(
        'Detail: Replace the placeholder ONYX_NEWSAPI_ORG_KEY value.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('worldnewsapi.com: missing key (placeholder)'),
      findsOneWidget,
    );
    await tester.tap(find.text('worldnewsapi.com: missing key (placeholder)'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Detail: Replace the placeholder ONYX_WORLDNEWSAPI_KEY value.',
      ),
      findsOneWidget,
    );
    expect(find.text('community-feed: configured'), findsOneWidget);
  });

  testWidgets('preset buttons emit profile changes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    IntakeStressProfile? changedProfile;

    await tester.pumpWidget(
      MaterialApp(
        home: DispatchPage(
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          onGenerate: () {},
          onIngestFeeds: () {},
          onRunStress: (_) async {},
          onRunSoak: (_) async {},
          onRunBenchmarkSuite: () async {},
          initialProfile: IntakeStressPreset.medium.profile,
          onProfileChanged: (profile) {
            changedProfile = profile;
          },
          onScenarioChanged: (scenarioLabel, tags) {},
          onRunNoteChanged: (_) {},
          onTelemetryImported: (_) {},
          onCancelStress: () {},
          onResetTelemetry: () {},
          onClearTelemetryPersistence: () {},
          onClearProfilePersistence: () {},
          stressRunning: false,
          intakeTelemetry: IntakeTelemetry.zero.add(
            label: 'STR-FILE',
            cancelled: false,
            attempted: 100,
            appended: 100,
            skipped: 0,
            decisions: 4,
            throughput: 120,
            p50Throughput: 115,
            p95Throughput: 125,
            verifyMs: 24,
            chunkSize: 100,
            chunks: 1,
            avgChunkMs: 12,
            maxChunkMs: 12,
            slowChunks: 0,
            duplicatesInjected: 0,
            uniqueFeeds: 1,
            peakPending: 100,
            siteDistribution: const {'SITE-SANDTON': 100},
            feedDistribution: const {'feed-01': 100},
            burstSize: 100,
          ),
          events: const [],
          onExecute: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Light'));
    await tester.pump();

    expect(changedProfile, isNotNull);
    expect(changedProfile!.toJson(), IntakeStressPreset.light.profile.toJson());
  });

  testWidgets('regression controls emit updated profile values', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    IntakeStressProfile latestProfile = IntakeStressPreset.medium.profile;

    await tester.pumpWidget(
      MaterialApp(
        home: DispatchPage(
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          onGenerate: () {},
          onIngestFeeds: () {},
          onRunStress: (_) async {},
          onRunSoak: (_) async {},
          onRunBenchmarkSuite: () async {},
          initialProfile: IntakeStressPreset.medium.profile,
          onProfileChanged: (profile) {
            latestProfile = profile;
          },
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
          onExecute: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Stop On Regression'));
    await tester.pump();

    await tester.tap(find.text('Thr Drop: 20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thr Drop: 40').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Verify Rise: 100'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify Rise: 200').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Max Pressure: 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Max Pressure: 1').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Max Imbalance: 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Max Imbalance: 1').last);
    await tester.pumpAndSettle();

    expect(latestProfile.stopOnRegression, isTrue);
    expect(latestProfile.regressionThroughputDrop, 40);
    expect(latestProfile.regressionVerifyIncreaseMs, 200);
    expect(latestProfile.maxRegressionPressureSeverity, 1);
    expect(latestProfile.maxRegressionImbalanceSeverity, 1);
  });

  testWidgets(
    'scenario inputs emit metadata changes and update telemetry chips',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String latestScenarioLabel = '';
      List<String> latestTags = const [];
      String latestRunNote = '';

      await tester.pumpWidget(
        MaterialApp(
          home: DispatchPage(
            clientId: 'CLIENT-001',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            onGenerate: () {},
            onIngestFeeds: () {},
            onRunStress: (_) async {},
            onRunSoak: (_) async {},
            onRunBenchmarkSuite: () async {},
            initialProfile: IntakeStressPreset.medium.profile,
            onProfileChanged: (_) {},
            onScenarioChanged: (scenarioLabel, tags) {
              latestScenarioLabel = scenarioLabel;
              latestTags = tags;
            },
            onRunNoteChanged: (note) {
              latestRunNote = note;
            },
            onTelemetryImported: (_) {},
            onCancelStress: () {},
            onResetTelemetry: () {},
            onClearTelemetryPersistence: () {},
            onClearProfilePersistence: () {},
            stressRunning: false,
            intakeTelemetry: IntakeTelemetry.zero,
            events: const [],
            onExecute: (_) {},
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'Hotspot replay');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), 'soak, skew');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(2), 'Shift handoff');
      await tester.pump();

      expect(latestScenarioLabel, 'Hotspot replay');
      expect(latestTags, const ['soak', 'skew']);
      expect(latestRunNote, 'Shift handoff');
      expect(find.text('Scenario: Hotspot replay'), findsOneWidget);
      expect(find.text('Tags: soak, skew'), findsOneWidget);
      expect(find.text('Run Note: Shift handoff'), findsOneWidget);
    },
  );

  testWidgets('benchmark rows show scenario and tag chips', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final telemetry = IntakeTelemetry.zero
        .add(
          label: 'STR-HISTORY',
          cancelled: false,
          scenarioLabel: 'Hotspot replay',
          tags: const ['soak', 'skew'],
          note: 'Shift handoff',
          attempted: 1000,
          appended: 900,
          skipped: 100,
          decisions: 40,
          throughput: 210,
          p50Throughput: 200,
          p95Throughput: 220,
          verifyMs: 80,
          chunkSize: 600,
          chunks: 2,
          avgChunkMs: 22,
          maxChunkMs: 40,
          slowChunks: 0,
          duplicatesInjected: 0,
          uniqueFeeds: 2,
          peakPending: 1000,
          siteDistribution: const {'SITE-SANDTON': 600, 'SITE-MIDRAND': 400},
          feedDistribution: const {'feed-01': 500, 'feed-02': 500},
          burstSize: 1000,
        )
        .add(
          label: 'STR-OTHER',
          cancelled: false,
          scenarioLabel: 'Baseline sweep',
          tags: const ['baseline'],
          attempted: 900,
          appended: 850,
          skipped: 50,
          decisions: 30,
          throughput: 180,
          p50Throughput: 170,
          p95Throughput: 190,
          verifyMs: 60,
          chunkSize: 600,
          chunks: 2,
          avgChunkMs: 20,
          maxChunkMs: 35,
          slowChunks: 0,
          duplicatesInjected: 0,
          uniqueFeeds: 2,
          peakPending: 900,
          siteDistribution: const {'SITE-SANDTON': 500, 'SITE-MIDRAND': 350},
          feedDistribution: const {'feed-01': 450, 'feed-02': 450},
          burstSize: 900,
        );

    await tester.pumpWidget(
      MaterialApp(
        home: DispatchPage(
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          onGenerate: () {},
          onIngestFeeds: () {},
          onRunStress: (_) async {},
          onRunSoak: (_) async {},
          onRunBenchmarkSuite: () async {},
          initialProfile: IntakeStressPreset.medium.profile,
          initialFilterPresets: const [
            DispatchBenchmarkFilterPreset(
              name: 'Ops View',
              showCancelledRuns: true,
              statusFilters: ['IMPROVED', 'STABLE', 'DEGRADED'],
            ),
          ],
          onProfileChanged: (_) {},
          onScenarioChanged: (scenarioLabel, tags) {},
          onRunNoteChanged: (_) {},
          onTelemetryImported: (_) {},
          onCancelStress: () {},
          onResetTelemetry: () {},
          onClearTelemetryPersistence: () {},
          onClearProfilePersistence: () {},
          stressRunning: false,
          intakeTelemetry: telemetry,
          events: const [],
          onExecute: (_) {},
        ),
      ),
    );

    expect(find.text('Run Scenario: Hotspot replay'), findsOneWidget);
    expect(find.text('Run Tag: soak'), findsOneWidget);
    expect(find.text('Run Tag: skew'), findsOneWidget);
    expect(find.text('Run Note: Shift handoff'), findsOneWidget);
    expect(find.text('Showing 2/2 runs'), findsOneWidget);

    await tester.tap(find.text('Run Scenario: Hotspot replay'));
    await tester.pump();
    expect(find.text('Scenario: Hotspot replay'), findsOneWidget);
    expect(find.text('Showing 1/2 runs'), findsOneWidget);
    expect(
      find.text(
        'Active Filters: scenario Hotspot replay • tag all • note all • status all • baseline none',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Run Scenario: Hotspot replay'));
    await tester.pump();
    expect(find.text('Scenario: all'), findsOneWidget);
    expect(find.text('Showing 2/2 runs'), findsOneWidget);
    expect(
      find.text(
        'Active Filters: scenario all • tag all • note all • status all • baseline none',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Run Scenario: Hotspot replay'));
    await tester.pump();

    await tester.tap(find.text('Run Tag: soak'));
    await tester.pump();
    expect(find.text('Tag: soak'), findsOneWidget);
    expect(find.text('Showing 1/2 runs'), findsOneWidget);
    expect(
      find.text(
        'Active Filters: scenario Hotspot replay • tag soak • note all • status all • baseline none',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Run Tag: soak'));
    await tester.pump();
    expect(find.text('Tag: all'), findsOneWidget);
    expect(find.text('Showing 1/2 runs'), findsOneWidget);
    expect(
      find.text(
        'Active Filters: scenario Hotspot replay • tag all • note all • status all • baseline none',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Run Note: Shift handoff'));
    await tester.pump();
    expect(find.text('Shift handoff'), findsAtLeastNWidgets(1));
    expect(find.text('Showing 1/2 runs'), findsOneWidget);
    expect(
      find.text(
        'Active Filters: scenario Hotspot replay • tag all • note Shift handoff • status all • baseline none',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Run Note: Shift handoff'));
    await tester.pump();
    expect(find.text('Showing 1/2 runs'), findsOneWidget);
    expect(
      find.text(
        'Active Filters: scenario Hotspot replay • tag all • note all • status all • baseline none',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).at(3), 'no-match');
    await tester.pump();
    expect(find.text('Showing 0/2 runs'), findsOneWidget);
    expect(
      find.text('No benchmark runs match the current filters.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Active Filters: scenario Hotspot replay • tag all • note no-match • status all • baseline none',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Clear Filters'));
    await tester.pump();
    expect(find.text('Scenario: all'), findsOneWidget);
    expect(find.text('Tag: all'), findsOneWidget);
    expect(find.text('Showing 2/2 runs'), findsOneWidget);
    expect(
      find.text(
        'Active Filters: scenario all • tag all • note all • status all • baseline none',
      ),
      findsOneWidget,
    );
  });

  testWidgets('live ingest history shows source labels', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final telemetry = IntakeTelemetry.zero.add(
      label: 'FILE-0001',
      cancelled: false,
      sourceLabel: 'uploaded file',
      attempted: 3,
      appended: 2,
      skipped: 1,
      decisions: 1,
      throughput: 2,
      p50Throughput: 2,
      p95Throughput: 2,
      verifyMs: 0,
      uniqueFeeds: 1,
      siteDistribution: const {'SITE-SANDTON': 3},
      feedDistribution: const {'watchtower': 3},
      burstSize: 3,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DispatchPage(
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          onGenerate: () {},
          onIngestFeeds: () {},
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
          intakeTelemetry: telemetry,
          events: const [],
          onExecute: (_) {},
        ),
      ),
    );

    expect(find.text('Recent Live Ingests'), findsOneWidget);
    expect(find.text('Source: uploaded file'), findsOneWidget);
    expect(find.text('Run: FILE-0001'), findsOneWidget);
  });

  testWidgets('recent intelligence card shows KPI chips and scroll list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: DispatchPage(
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          onGenerate: () {},
          onIngestFeeds: () {},
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
          events: [
            IntelligenceReceived(
              eventId: 'E-INT-1',
              sequence: 1,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 3, 10),
              intelligenceId: 'INT-1',
              provider: 'newsapi.org',
              sourceType: 'news',
              externalId: 'article-1',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              headline: 'Armed robbery warning in Sandton',
              summary:
                  'Security teams warn of syndicate activity near offices.',
              riskScore: 82,
              canonicalHash: 'hash-1',
            ),
            IntelligenceReceived(
              eventId: 'E-INT-2',
              sequence: 2,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 3, 9, 45),
              intelligenceId: 'INT-2',
              provider: 'worldnewsapi.com',
              sourceType: 'news',
              externalId: 'article-2',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              headline: 'Syndicate robbery warning near Sandton offices',
              summary:
                  'Follow-up reporting confirms suspicious vehicles and robbery scouting.',
              riskScore: 74,
              canonicalHash: 'hash-2',
            ),
            IntelligenceReceived(
              eventId: 'E-INT-3',
              sequence: 3,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 3, 9),
              intelligenceId: 'INT-3',
              provider: 'newsdata.io',
              sourceType: 'weather',
              externalId: 'article-3',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              headline: 'Storm alert issued for Gauteng',
              summary: 'Weather alert may disrupt patrol routes tonight.',
              riskScore: 58,
              canonicalHash: 'hash-3',
            ),
            IntelligenceReceived(
              eventId: 'E-INT-4',
              sequence: 4,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 3, 9, 30),
              intelligenceId: 'INT-4',
              provider: 'community-feed',
              sourceType: 'community',
              externalId: 'community-4',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              headline: 'Community reports robbery scouting near Sandton gate',
              summary:
                  'WhatsApp group warns of a suspicious Hilux circling the office park.',
              riskScore: 67,
              canonicalHash: 'hash-4',
            ),
          ],
          onExecute: (_) {},
        ),
      ),
    );

    expect(find.text('Recent Intelligence'), findsOneWidget);
    expect(find.text('Relevant Intel: 4'), findsOneWidget);
    expect(find.text('High Risk: 2'), findsOneWidget);
    expect(find.text('Sources: 4'), findsOneWidget);
    expect(find.text('Pinned Watches: 0'), findsOneWidget);
    expect(find.text('Dismissed: 0'), findsOneWidget);
    expect(find.text('Peak Risk: 82'), findsOneWidget);
    expect(find.text('Armed robbery warning in Sandton'), findsOneWidget);
    expect(find.text('Dispatch Candidate'), findsWidgets);
    expect(find.text('Watch'), findsWidgets);
    expect(
      find.text('Triage Posture: A 1 • W 2 • DC 1 • Escalate 1'),
      findsOneWidget,
    );
    expect(find.textContaining('Top Triage Signals:'), findsOneWidget);
    expect(
      find.text('Community reports robbery scouting near Sandton gate'),
      findsOneWidget,
    );

    await tester.tap(find.text('Community'));
    await tester.pump();

    expect(find.text('Relevant Intel: 1'), findsOneWidget);
    expect(find.text('High Risk: 0'), findsOneWidget);
    expect(find.text('Sources: 1'), findsOneWidget);
    expect(find.text('Pinned Watches: 0'), findsOneWidget);
    expect(find.text('Dismissed: 0'), findsOneWidget);
    expect(find.text('Peak Risk: 67'), findsOneWidget);
    expect(
      find.text('Community reports robbery scouting near Sandton gate'),
      findsOneWidget,
    );
    expect(find.text('Armed robbery warning in Sandton'), findsNothing);
    expect(find.text('Clear Filters'), findsOneWidget);

    await tester.tap(find.text('All').first);
    await tester.pump();
    await tester.tap(find.text('Dispatch Candidate').first);
    await tester.pump();

    expect(find.text('Relevant Intel: 1'), findsOneWidget);
    expect(find.text('High Risk: 1'), findsOneWidget);
    expect(find.text('Sources: 1'), findsOneWidget);
    expect(find.text('Pinned Watches: 0'), findsOneWidget);
    expect(find.text('Dismissed: 0'), findsOneWidget);
    expect(find.text('Peak Risk: 82'), findsOneWidget);
    expect(find.text('Armed robbery warning in Sandton'), findsOneWidget);
    expect(
      find.text('Community reports robbery scouting near Sandton gate'),
      findsNothing,
    );

    await tester.tap(find.text('Clear Filters'));
    await tester.pump();

    expect(find.text('Relevant Intel: 4'), findsOneWidget);
    expect(find.text('High Risk: 2'), findsOneWidget);
    expect(find.text('Sources: 4'), findsOneWidget);
    expect(find.text('Pinned Watches: 0'), findsOneWidget);
    expect(find.text('Dismissed: 0'), findsOneWidget);
    expect(find.text('Peak Risk: 82'), findsOneWidget);
    expect(find.text('Clear Filters'), findsNothing);

    await tester.tap(find.text('Armed robbery warning in Sandton'));
    await tester.pumpAndSettle();

    expect(find.text('Intelligence Detail'), findsOneWidget);
    expect(
      find.text('Headline: Armed robbery warning in Sandton'),
      findsOneWidget,
    );
    expect(find.text('Action: Dispatch Candidate'), findsOneWidget);
    expect(find.text('Source Type: news'), findsOneWidget);
    expect(find.text('Provider: newsapi.org'), findsOneWidget);
    expect(find.text('Risk: 82'), findsOneWidget);
    expect(find.text('External: article-1'), findsOneWidget);
    expect(find.text('Intel ID: INT-1'), findsOneWidget);
    expect(
      find.text(
        'Summary: Security teams warn of syndicate activity near offices.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Intelligence Detail'), findsNothing);
  });

  testWidgets('intelligence detail actions update row state and escalate', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? escalatedIntelId;

    await tester.pumpWidget(
      MaterialApp(
        home: DispatchPage(
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          onGenerate: () {},
          onIngestFeeds: () {},
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
          onEscalateIntelligence: (intel) {
            escalatedIntelId = intel.intelligenceId;
          },
          stressRunning: false,
          intakeTelemetry: IntakeTelemetry.zero,
          events: [
            IntelligenceReceived(
              eventId: 'E-INT-ACT',
              sequence: 1,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 3, 10),
              intelligenceId: 'INT-ACT',
              provider: 'newsapi.org',
              sourceType: 'news',
              externalId: 'article-act',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              headline: 'Escalation candidate near Sandton',
              summary: 'Follow-up signal indicates coordinated scouting.',
              riskScore: 82,
              canonicalHash: 'hash-act',
            ),
            IntelligenceReceived(
              eventId: 'E-INT-ACT-2',
              sequence: 2,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 3, 9, 45),
              intelligenceId: 'INT-ACT-2',
              provider: 'worldnewsapi.com',
              sourceType: 'news',
              externalId: 'article-act-2',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              headline: 'Scouting confirmed near Sandton perimeter',
              summary:
                  'Second report corroborates the same suspicious pattern.',
              riskScore: 74,
              canonicalHash: 'hash-act-2',
            ),
          ],
          onExecute: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Escalation candidate near Sandton'));
    await tester.pumpAndSettle();
    expect(find.text('Pin as Watch'), findsOneWidget);
    expect(
      find.text('Escalate to Dispatch').evaluate().isNotEmpty ||
          find.text('Manual Escalate Override').evaluate().isNotEmpty,
      isTrue,
    );
    expect(find.text('Dismiss / Ignore'), findsOneWidget);
    expect(find.textContaining('Predictive Score:'), findsOneWidget);
    expect(find.textContaining('Corroborated: yes'), findsOneWidget);
    expect(find.textContaining('Rationale:'), findsOneWidget);

    await tester.tap(find.text('Pin as Watch'));
    await tester.pumpAndSettle();

    expect(find.text('Watch'), findsWidgets);

    await tester.tap(find.text('Escalation candidate near Sandton'));
    await tester.pumpAndSettle();
    expect(find.text('Pinned Watch: yes'), findsOneWidget);
    expect(find.text('Pin as Watch'), findsNothing);

    final escalateFinder = find.text('Escalate to Dispatch').evaluate().isNotEmpty
        ? find.text('Escalate to Dispatch')
        : find.text('Manual Escalate Override');
    await tester.tap(escalateFinder);
    await tester.pumpAndSettle();
    expect(escalatedIntelId, 'INT-ACT');
  });

  testWidgets(
    'initial intelligence triage restores pinned and dismissed state',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: DispatchPage(
            clientId: 'CLIENT-001',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            onGenerate: () {},
            onIngestFeeds: () {},
            onRunStress: (_) async {},
            onRunSoak: (_) async {},
            onRunBenchmarkSuite: () async {},
            initialProfile: IntakeStressPreset.medium.profile,
            initialPinnedWatchIntelligenceIds: const ['INT-PINNED'],
            initialDismissedIntelligenceIds: const ['INT-DISMISSED'],
            initialShowPinnedWatchIntelligenceOnly: true,
            initialSelectedIntelligenceId: 'INT-PINNED',
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
            events: [
              IntelligenceReceived(
                eventId: 'E-INT-PINNED',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 3, 3, 10),
                intelligenceId: 'INT-PINNED',
                provider: 'community-feed',
                sourceType: 'community',
                externalId: 'comm-pinned',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SANDTON',
                headline: 'Pinned community watch',
                summary: 'Visible and restored as watch.',
                riskScore: 40,
                canonicalHash: 'hash-pinned',
              ),
              IntelligenceReceived(
                eventId: 'E-INT-DISMISSED',
                sequence: 2,
                version: 1,
                occurredAt: DateTime.utc(2026, 3, 3, 9, 30),
                intelligenceId: 'INT-DISMISSED',
                provider: 'newsapi.org',
                sourceType: 'news',
                externalId: 'news-dismissed',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SANDTON',
                headline: 'Dismissed intelligence item',
                summary: 'Should not appear in the restored list.',
                riskScore: 75,
                canonicalHash: 'hash-dismissed',
              ),
              IntelligenceReceived(
                eventId: 'E-INT-WATCH',
                sequence: 3,
                version: 1,
                occurredAt: DateTime.utc(2026, 3, 3, 9, 15),
                intelligenceId: 'INT-WATCH',
                provider: 'community-feed',
                sourceType: 'community',
                externalId: 'comm-watch',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SANDTON',
                headline: 'Unpinned community watch',
                summary:
                    'Visible in normal view but excluded from pinned-only mode.',
                riskScore: 66,
                canonicalHash: 'hash-watch',
              ),
            ],
            onExecute: (_) {},
          ),
        ),
      );

      expect(find.text('Pinned community watch'), findsOneWidget);
      expect(find.text('Unpinned community watch'), findsNothing);
      expect(find.text('Dismissed intelligence item'), findsNothing);
      expect(find.text('Relevant Intel: 1'), findsOneWidget);
      expect(find.text('Pinned Watches: 1'), findsOneWidget);
      expect(find.text('Dismissed: 1'), findsOneWidget);
      expect(find.text('Selected'), findsOneWidget);

      await tester.tap(find.text('Clear Filters'));
      await tester.pump();

      expect(find.text('Pinned community watch'), findsOneWidget);
      expect(find.text('Unpinned community watch'), findsOneWidget);
      expect(find.text('Dismissed intelligence item'), findsNothing);
      expect(find.text('Selected'), findsOneWidget);

      await tester.tap(find.text('Dismissed: 1'));
      await tester.pump();

      expect(find.text('Dismissed intelligence item'), findsOneWidget);
      expect(find.text('Pinned community watch'), findsNothing);
      expect(find.text('Clear Filters'), findsOneWidget);

      await tester.tap(find.text('Dismissed intelligence item'));
      await tester.pumpAndSettle();
      expect(find.text('Dismissed: yes'), findsOneWidget);
      expect(find.text('Restore Intel'), findsOneWidget);
      expect(find.text('Restore & Pin'), findsOneWidget);

      await tester.tap(find.text('Restore & Pin'));
      await tester.pumpAndSettle();

      expect(find.text('Dismissed intelligence item'), findsNothing);
      expect(find.text('Dismissed: 0'), findsOneWidget);

      await tester.tap(find.text('Clear Filters'));
      await tester.pump();
      expect(find.text('Pinned Watches: 2'), findsOneWidget);
      await tester.tap(find.text('Pinned Watches: 2'));
      await tester.pump();

      expect(find.text('Pinned community watch'), findsOneWidget);
      expect(find.text('Dismissed intelligence item'), findsOneWidget);
      expect(find.text('Unpinned community watch'), findsNothing);
      expect(find.text('Relevant Intel: 2'), findsOneWidget);
      expect(find.text('Pinned Watches: 2'), findsOneWidget);
    },
  );

  testWidgets('poll health history renders recent entries', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: DispatchPage(
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          onGenerate: () {},
          onIngestFeeds: () {},
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
          livePollingLabel: 'Polling: active',
          livePollingHistory: const [
            '20:10:00Z • OK • 120ms • 3 records',
            '20:09:45Z • FAIL • 98ms • HTTP 500',
          ],
          events: const [],
          onExecute: (_) {},
        ),
      ),
    );

    expect(find.text('Poll Health'), findsOneWidget);
    expect(find.text('20:10:00Z • OK • 120ms • 3 records'), findsOneWidget);
    expect(find.text('20:09:45Z • FAIL • 98ms • HTTP 500'), findsOneWidget);
  });

  testWidgets('historical run note can be edited inline', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    IntakeTelemetry latestTelemetry = IntakeTelemetry.zero.add(
      label: 'STR-EDIT',
      cancelled: false,
      note: 'Before',
      attempted: 500,
      appended: 450,
      skipped: 50,
      decisions: 20,
      throughput: 180,
      p50Throughput: 170,
      p95Throughput: 190,
      verifyMs: 40,
      chunkSize: 500,
      chunks: 1,
      avgChunkMs: 10,
      maxChunkMs: 10,
      slowChunks: 0,
      duplicatesInjected: 0,
      uniqueFeeds: 1,
      peakPending: 500,
      siteDistribution: const {'SITE-SANDTON': 500},
      feedDistribution: const {'feed-01': 500},
      burstSize: 500,
    );

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            home: DispatchPage(
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              onGenerate: () {},
              onIngestFeeds: () {},
              onRunStress: (_) async {},
              onRunSoak: (_) async {},
              onRunBenchmarkSuite: () async {},
              initialProfile: IntakeStressPreset.medium.profile,
              onProfileChanged: (_) {},
              onScenarioChanged: (scenarioLabel, tags) {},
              onRunNoteChanged: (_) {},
              onTelemetryImported: (next) {
                setState(() {
                  latestTelemetry = next;
                });
              },
              onCancelStress: () {},
              onResetTelemetry: () {},
              onClearTelemetryPersistence: () {},
              onClearProfilePersistence: () {},
              stressRunning: false,
              intakeTelemetry: latestTelemetry,
              events: const [],
              onExecute: (_) {},
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('Edit Note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'After');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(latestTelemetry.recentRuns.first.note, 'After');
    expect(find.text('Run Note: After'), findsOneWidget);
  });

  testWidgets('historical run metadata can be edited inline', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    IntakeTelemetry latestTelemetry = IntakeTelemetry.zero.add(
      label: 'STR-META',
      cancelled: false,
      scenarioLabel: 'Before scenario',
      tags: const ['before'],
      note: 'Before note',
      attempted: 500,
      appended: 450,
      skipped: 50,
      decisions: 20,
      throughput: 180,
      p50Throughput: 170,
      p95Throughput: 190,
      verifyMs: 40,
      chunkSize: 500,
      chunks: 1,
      avgChunkMs: 10,
      maxChunkMs: 10,
      slowChunks: 0,
      duplicatesInjected: 0,
      uniqueFeeds: 1,
      peakPending: 500,
      siteDistribution: const {'SITE-SANDTON': 500},
      feedDistribution: const {'feed-01': 500},
      burstSize: 500,
    );

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            home: DispatchPage(
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              onGenerate: () {},
              onIngestFeeds: () {},
              onRunStress: (_) async {},
              onRunSoak: (_) async {},
              onRunBenchmarkSuite: () async {},
              initialProfile: IntakeStressPreset.medium.profile,
              onProfileChanged: (_) {},
              onScenarioChanged: (scenarioLabel, tags) {},
              onRunNoteChanged: (_) {},
              onTelemetryImported: (next) {
                setState(() {
                  latestTelemetry = next;
                });
              },
              onCancelStress: () {},
              onResetTelemetry: () {},
              onClearTelemetryPersistence: () {},
              onClearProfilePersistence: () {},
              stressRunning: false,
              intakeTelemetry: latestTelemetry,
              events: const [],
              onExecute: (_) {},
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('Edit Meta'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Run Metadata'), findsOneWidget);

    final dialog = find.byType(AlertDialog);
    final fields = find.descendant(
      of: dialog,
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(fields.at(0)).decoration!.hintText,
      'Scenario label',
    );
    expect(
      tester.widget<TextField>(fields.at(1)).decoration!.hintText,
      'Tags (comma separated)',
    );
    expect(
      tester.widget<TextField>(fields.at(2)).decoration!.hintText,
      'Operator annotation',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(latestTelemetry.recentRuns.first.scenarioLabel, 'Before scenario');
    expect(latestTelemetry.recentRuns.first.tags, const ['before']);
    expect(latestTelemetry.recentRuns.first.note, 'Before note');

    await tester.tap(find.text('Edit Meta'));
    await tester.pumpAndSettle();

    final saveDialog = find.byType(AlertDialog);
    final saveFields = find.descendant(
      of: saveDialog,
      matching: find.byType(TextField),
    );
    await tester.enterText(saveFields.at(0), 'After scenario');
    await tester.enterText(saveFields.at(1), 'alpha, beta');
    await tester.enterText(saveFields.at(2), 'After note');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(latestTelemetry.recentRuns.first.scenarioLabel, 'After scenario');
    expect(latestTelemetry.recentRuns.first.tags, const ['alpha', 'beta']);
    expect(latestTelemetry.recentRuns.first.note, 'After note');
    expect(find.text('Run Scenario: After scenario'), findsOneWidget);
    expect(find.text('Run Tag: alpha'), findsOneWidget);
    expect(find.text('Run Tag: beta'), findsOneWidget);
    expect(find.text('Run Note: After note'), findsOneWidget);
  });

  testWidgets('copy profile json writes current profile to clipboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final profile = IntakeStressPreset.heavy.profile;

    await tester.pumpWidget(
      MaterialApp(
        home: DispatchPage(
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          onGenerate: () {},
          onIngestFeeds: () {},
          onRunStress: (_) async {},
          onRunSoak: (_) async {},
          onRunBenchmarkSuite: () async {},
          initialProfile: profile,
          onProfileChanged: (_) {},
          onScenarioChanged: (scenarioLabel, tags) {},
          onRunNoteChanged: (_) {},
          onTelemetryImported: (_) {},
          onCancelStress: () {},
          onResetTelemetry: () {},
          onClearTelemetryPersistence: () {},
          onClearProfilePersistence: () {},
          stressRunning: false,
          intakeTelemetry: IntakeTelemetry.zero.add(
            label: 'STR-FILE',
            cancelled: false,
            attempted: 100,
            appended: 100,
            skipped: 0,
            decisions: 4,
            throughput: 120,
            p50Throughput: 115,
            p95Throughput: 125,
            verifyMs: 24,
            chunkSize: 100,
            chunks: 1,
            avgChunkMs: 12,
            maxChunkMs: 12,
            slowChunks: 0,
            duplicatesInjected: 0,
            uniqueFeeds: 1,
            peakPending: 100,
            siteDistribution: const {'SITE-SANDTON': 100},
            feedDistribution: const {'feed-01': 100},
            burstSize: 100,
          ),
          events: const [],
          onExecute: (_) {},
        ),
      ),
    );

    await _openAdvancedSnapshotProfileTools(tester);
    await tester.tap(find.text('Copy Profile JSON'));
    await tester.pump();

    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clipboard, isNotNull);
    final decoded = IntakeStressProfile.fromJson(
      _decodeClipboardMap(clipboard!.text!),
    );

    expect(decoded.toJson(), profile.toJson());
  });

  testWidgets('copy snapshot json includes scenario metadata', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: DispatchPage(
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          onGenerate: () {},
          onIngestFeeds: () {},
          onRunStress: (_) async {},
          onRunSoak: (_) async {},
          onRunBenchmarkSuite: () async {},
          initialProfile: IntakeStressPreset.medium.profile,
          initialFilterPresets: const [
            DispatchBenchmarkFilterPreset(
              name: 'Ops View',
              showCancelledRuns: false,
              statusFilters: ['DEGRADED'],
              scenarioFilter: 'Hotspot replay',
              tagFilter: 'soak',
              noteFilter: 'Shift',
              sort: 'verifyAsc',
              historyLimit: 3,
            ),
          ],
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
          onExecute: (_) {},
        ),
      ),
    );

    await _openAdvancedSnapshotProfileTools(tester);
    expect(find.text('Snapshot v2'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Hotspot replay');
    await tester.enterText(find.byType(TextField).at(1), 'soak, skew');
    await tester.enterText(find.byType(TextField).at(2), 'Shift handoff');
    await tester.tap(find.text('Copy Snapshot JSON'));
    await tester.pump();
    expect(find.text('Snapshot JSON v2 copied'), findsOneWidget);

    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clipboard, isNotNull);
    final snapshot = DispatchSnapshot.fromJson(
      _decodeClipboardMap(clipboard!.text!),
    );

    expect(snapshot.scenarioLabel, 'Hotspot replay');
    expect(snapshot.version, 2);
    expect(snapshot.tags, const ['soak', 'skew']);
    expect(snapshot.runNote, 'Shift handoff');
    expect(snapshot.filterPresets, hasLength(1));
    expect(snapshot.filterPresets.first.name, 'Ops View');
  });

  testWidgets('import actions read clipboard payloads and emit callbacks', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    IntakeStressProfile? importedProfile;
    IntakeTelemetry? importedTelemetry;
    List<DispatchBenchmarkFilterPreset>? importedFilterPresets;

    final telemetry = IntakeTelemetry.zero.add(
      label: 'STR-CLIP',
      cancelled: false,
      attempted: 1000,
      appended: 900,
      skipped: 100,
      decisions: 40,
      throughput: 210,
      p50Throughput: 200,
      p95Throughput: 220,
      verifyMs: 80,
      chunkSize: 600,
      chunks: 2,
      avgChunkMs: 22,
      maxChunkMs: 40,
      slowChunks: 0,
      duplicatesInjected: 0,
      uniqueFeeds: 2,
      peakPending: 1000,
      siteDistribution: const {'SITE-SANDTON': 600, 'SITE-MIDRAND': 400},
      feedDistribution: const {'feed-01': 500, 'feed-02': 500},
      burstSize: 1000,
    );
    final profile = IntakeStressPreset.light.profile.copyWith(
      regressionThroughputDrop: 40,
      regressionVerifyIncreaseMs: 200,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DispatchPage(
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          onGenerate: () {},
          onIngestFeeds: () {},
          onRunStress: (_) async {},
          onRunSoak: (_) async {},
          onRunBenchmarkSuite: () async {},
          initialProfile: IntakeStressPreset.medium.profile,
          initialFilterPresets: const [
            DispatchBenchmarkFilterPreset(
              name: 'Ops View',
              showCancelledRuns: true,
              statusFilters: ['IMPROVED', 'STABLE'],
            ),
            DispatchBenchmarkFilterPreset(
              name: 'Local View',
              showCancelledRuns: true,
              statusFilters: ['STABLE'],
            ),
          ],
          onProfileChanged: (next) {
            importedProfile = next;
          },
          onScenarioChanged: (scenarioLabel, tags) {},
          onRunNoteChanged: (_) {},
          onFilterPresetsChanged: (presets) {
            importedFilterPresets = presets;
          },
          onTelemetryImported: (next) {
            importedTelemetry = next;
          },
          onCancelStress: () {},
          onResetTelemetry: () {},
          onClearTelemetryPersistence: () {},
          onClearProfilePersistence: () {},
          stressRunning: false,
          intakeTelemetry: IntakeTelemetry.zero,
          events: const [],
          onExecute: (_) {},
        ),
      ),
    );

    await Clipboard.setData(
      ClipboardData(
        text: _encodeJson({
          'scenarioLabel': 'Hotspot replay',
          'tags': ['soak', 'skew'],
          'runNote': 'Shift handoff',
          'filterPresets': [
            {
              'name': 'Ops View',
              'showCancelledRuns': false,
              'statusFilters': ['DEGRADED'],
              'scenarioFilter': 'Hotspot replay',
              'tagFilter': 'soak',
              'noteFilter': 'Shift',
              'sort': 'verifyAsc',
              'historyLimit': 3,
            },
          ],
          'profile': profile.toJson(),
          'telemetry': telemetry.toJson(),
          'version': 1,
        }),
      ),
    );
    await _openAdvancedSnapshotProfileTools(tester);
    await tester.tap(find.text('Import Snapshot JSON'));
    await tester.pumpAndSettle();
    expect(find.text('Inspect Snapshot'), findsOneWidget);
    expect(find.text('Version: v1'), findsOneWidget);
    expect(find.text('Scenario: Hotspot replay'), findsOneWidget);
    expect(find.text('Saved Views: 1'), findsOneWidget);
    expect(find.text('Incoming Names: Ops View'), findsOneWidget);
    expect(
      find.widgetWithText(CheckboxListTile, 'Import Draft Metadata (on)'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CheckboxListTile, 'Import Saved Views (1 selected)'),
      findsOneWidget,
    );
    expect(find.text('Selected Views: 1 (Ops View)'), findsOneWidget);
    expect(find.text('View Collisions: 1'), findsOneWidget);
    expect(find.text('Collision Names: Ops View'), findsOneWidget);
    expect(find.text('Collision Changes: Ops View:'), findsOneWidget);
    expect(find.text('- cancelled: on -> off'), findsOneWidget);
    expect(find.text('- status: IMPROVED|STABLE -> DEGRADED'), findsOneWidget);
    expect(find.text('- scenario: all -> Hotspot replay'), findsOneWidget);
    expect(find.text('- tag: all -> soak'), findsOneWidget);
    expect(find.text('- note: all -> Shift'), findsOneWidget);
    expect(find.text('- sort: Latest -> Verify Asc'), findsOneWidget);
    expect(find.text('- history: 6 -> 3'), findsOneWidget);
    expect(find.text('Merge Result: 2 saved views'), findsOneWidget);
    expect(find.textContaining('Unchanged Collisions:'), findsNothing);
    expect(find.textContaining('Incoming Only:'), findsNothing);
    expect(find.text('Telemetry Runs: 1'), findsOneWidget);
    expect(find.text('Merge Views & Apply All'), findsOneWidget);
    expect(find.text('Replace Views & Apply All'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(importedProfile, isNull);
    expect(importedTelemetry, isNull);
    expect(importedFilterPresets, isNull);

    await tester.tap(find.text('Import Snapshot JSON'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Merge Views & Apply All'));
    await tester.pump();
    expect(find.text('Snapshot JSON v1 imported'), findsOneWidget);

    expect(importedProfile, isNotNull);
    expect(importedTelemetry, isNotNull);
    expect(importedFilterPresets, hasLength(2));
    expect(importedFilterPresets!.map((preset) => preset.name), [
      'Local View',
      'Ops View',
    ]);
    expect(importedProfile!.toJson(), profile.toJson());
    expect(importedTelemetry!.toJson(), telemetry.toJson());
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
      'Hotspot replay',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      'soak, skew',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text,
      'Shift handoff',
    );

    importedProfile = null;
    importedTelemetry = null;
    importedFilterPresets = null;
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await Clipboard.setData(
      ClipboardData(
        text: _encodeJson({
          'scenarioLabel': 'Hotspot replay',
          'tags': ['soak', 'skew'],
          'runNote': 'Shift handoff',
          'filterPresets': [
            {
              'name': 'Ops View',
              'showCancelledRuns': false,
              'statusFilters': ['DEGRADED'],
              'scenarioFilter': 'Hotspot replay',
              'tagFilter': 'soak',
              'noteFilter': 'Shift',
              'sort': 'verifyAsc',
              'historyLimit': 3,
            },
            {
              'name': 'Night Shift',
              'showCancelledRuns': true,
              'statusFilters': ['STABLE'],
              'scenarioFilter': 'Baseline sweep',
              'tagFilter': '',
              'noteFilter': '',
              'sort': 'latest',
              'historyLimit': 6,
            },
          ],
          'profile': profile.toJson(),
          'telemetry': telemetry.toJson(),
          'version': 1,
        }),
      ),
    );
    await tester.tap(find.text('Import Snapshot JSON'));
    await tester.pumpAndSettle();
    expect(find.text('Import Scope: Combined import'), findsOneWidget);
    expect(
      find.widgetWithText(CheckboxListTile, 'Import Draft Metadata (on)'),
      findsOneWidget,
    );
    expect(find.text('Merge Views & Apply All'), findsOneWidget);
    expect(find.text('Replace Views & Apply All'), findsOneWidget);
    expect(
      find.widgetWithText(CheckboxListTile, 'Import Saved Views (2 selected)'),
      findsOneWidget,
    );
    expect(find.text('Saved Views: 2'), findsOneWidget);
    expect(find.text('Incoming Names: Ops View, Night Shift'), findsOneWidget);
    expect(
      find.text('Selected Views: 2 (Ops View, Night Shift)'),
      findsOneWidget,
    );
    expect(find.text('View Collisions: 1'), findsOneWidget);
    expect(find.text('Unchanged Collisions: 1'), findsOneWidget);
    expect(find.text('Collision Changes: Ops View: none'), findsOneWidget);
    expect(find.text('Incoming Only: 1 (Night Shift)'), findsOneWidget);
    expect(find.text('Merge Result: 3 saved views'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Night Shift'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Import Draft Metadata (on)'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Import Scope: Saved views only'), findsOneWidget);
    expect(
      find.widgetWithText(CheckboxListTile, 'Import Draft Metadata (off)'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CheckboxListTile, 'Import Saved Views (1 selected)'),
      findsOneWidget,
    );
    expect(find.text('Merge Saved Views'), findsOneWidget);
    expect(find.text('Replace Saved Views'), findsOneWidget);
    expect(find.text('Selected Views: 1 (Ops View)'), findsOneWidget);
    expect(find.textContaining('Incoming Only:'), findsNothing);
    expect(find.text('Merge Result: 2 saved views'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ops View'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Night Shift'));
    await tester.pumpAndSettle();
    expect(find.text('Selected Views: 1 (Night Shift)'), findsOneWidget);
    expect(find.text('Import Scope: Saved views only'), findsOneWidget);
    expect(find.textContaining('View Collisions:'), findsNothing);
    expect(find.text('Incoming Only: 1 (Night Shift)'), findsOneWidget);
    expect(find.textContaining('Merge Result:'), findsNothing);
    expect(find.text('Merge Saved Views'), findsNothing);
    expect(find.text('Apply Saved Views'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Clear all'));
    await tester.pumpAndSettle();
    expect(find.text('Selected Views: 0 (none)'), findsOneWidget);
    expect(
      find.widgetWithText(CheckboxListTile, 'Import Saved Views (0 selected)'),
      findsOneWidget,
    );
    expect(
      find.text('Import Scope: Saved views only (selection required)'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Selection: Select at least one incoming saved view to import.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('View Collisions:'), findsNothing);
    expect(find.textContaining('Incoming Only:'), findsNothing);
    expect(find.textContaining('Merge Result:'), findsNothing);
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Apply Saved Views'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Select all'));
    await tester.pumpAndSettle();
    expect(
      find.text('Selected Views: 2 (Ops View, Night Shift)'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CheckboxListTile, 'Import Saved Views (2 selected)'),
      findsOneWidget,
    );
    expect(find.text('Merge Saved Views'), findsOneWidget);
    expect(find.text('Replace Saved Views'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Night Shift'));
    await tester.pumpAndSettle();
    expect(find.text('Selected Views: 1 (Ops View)'), findsOneWidget);
    expect(
      find.widgetWithText(CheckboxListTile, 'Import Saved Views (1 selected)'),
      findsOneWidget,
    );
    expect(find.text('Merge Saved Views'), findsOneWidget);
    expect(find.text('Replace Saved Views'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Import Draft Metadata (off)'),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Import Saved Views (1 selected)'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Import Scope: Draft metadata only'), findsOneWidget);
    expect(
      find.widgetWithText(CheckboxListTile, 'Import Draft Metadata (on)'),
      findsOneWidget,
    );
    expect(find.text('Merge Saved Views'), findsNothing);
    expect(find.text('Apply Metadata Only'), findsOneWidget);
    expect(
      find.widgetWithText(CheckboxListTile, 'Import Saved Views (0 selected)'),
      findsOneWidget,
    );
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Import Saved Views (0 selected)'),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Import Draft Metadata (on)'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Import Scope: Saved views only'), findsOneWidget);
    expect(find.text('Replace Saved Views'), findsOneWidget);
    await tester.tap(find.text('Replace Saved Views'));
    await tester.pump();
    expect(find.text('Snapshot JSON v1 imported'), findsOneWidget);

    expect(importedProfile, isNull);
    expect(importedTelemetry, isNull);
    expect(importedFilterPresets, hasLength(1));
    expect(importedFilterPresets!.map((preset) => preset.name), ['Ops View']);

    await Clipboard.setData(ClipboardData(text: _encodeJson(profile.toJson())));
    await tester.tap(find.text('Import Profile JSON'));
    await tester.pump();
    expect(importedProfile!.toJson(), profile.toJson());

    await Clipboard.setData(
      ClipboardData(text: _encodeJson(telemetry.toJson())),
    );
    await tester.tap(find.text('Import Telemetry JSON'));
    await tester.pump();
    expect(importedTelemetry!.toJson(), telemetry.toJson());
  });

  testWidgets('file snapshot actions show non-web fallback messages', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: DispatchPage(
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          onGenerate: () {},
          onIngestFeeds: () {},
          onRunStress: (_) async {},
          onRunSoak: (_) async {},
          onRunBenchmarkSuite: () async {},
          initialProfile: IntakeStressPreset.medium.profile,
          initialFilterPresets: const [
            DispatchBenchmarkFilterPreset(
              name: 'Ops View',
              showCancelledRuns: true,
              statusFilters: ['IMPROVED', 'STABLE', 'DEGRADED'],
            ),
          ],
          onProfileChanged: (_) {},
          onScenarioChanged: (scenarioLabel, tags) {},
          onRunNoteChanged: (_) {},
          onTelemetryImported: (_) {},
          onCancelStress: () {},
          onResetTelemetry: () {},
          onClearTelemetryPersistence: () {},
          onClearProfilePersistence: () {},
          stressRunning: false,
          intakeTelemetry: IntakeTelemetry.zero.add(
            label: 'STR-FILE',
            cancelled: false,
            attempted: 100,
            appended: 100,
            skipped: 0,
            decisions: 4,
            throughput: 120,
            p50Throughput: 115,
            p95Throughput: 125,
            verifyMs: 24,
            chunkSize: 100,
            chunks: 1,
            avgChunkMs: 12,
            maxChunkMs: 12,
            slowChunks: 0,
            duplicatesInjected: 0,
            uniqueFeeds: 1,
            peakPending: 100,
            siteDistribution: const {'SITE-SANDTON': 100},
            feedDistribution: const {'feed-01': 100},
            burstSize: 100,
          ),
          events: const [],
          onExecute: (_) {},
        ),
      ),
    );

    await _openAdvancedSnapshotProfileTools(tester);
    await tester.tap(find.text('Download Snapshot File'));
    await tester.pumpAndSettle();
    expect(find.text('File export is only available on web'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Load Snapshot File'));
    await tester.pumpAndSettle();
    expect(find.text('File import is only available on web'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.tap(find.text('View: none'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View: Ops View').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Download View File'));
    await tester.pumpAndSettle();
    expect(
      find.text('View file export is only available on web'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Load View File'));
    await tester.pumpAndSettle();
    expect(
      find.text('View file import is only available on web'),
      findsOneWidget,
    );
  });

  testWidgets('benchmark filter presets can be saved and reapplied', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    List<DispatchBenchmarkFilterPreset> latestPresets = const [];
    final telemetry = IntakeTelemetry.zero
        .add(
          label: 'STR-HISTORY',
          cancelled: false,
          scenarioLabel: 'Hotspot replay',
          tags: const ['soak'],
          attempted: 1000,
          appended: 900,
          skipped: 100,
          decisions: 40,
          throughput: 210,
          p50Throughput: 200,
          p95Throughput: 220,
          verifyMs: 80,
          chunkSize: 600,
          chunks: 2,
          avgChunkMs: 22,
          maxChunkMs: 40,
          slowChunks: 0,
          duplicatesInjected: 0,
          uniqueFeeds: 2,
          peakPending: 1000,
          siteDistribution: const {'SITE-SANDTON': 600, 'SITE-MIDRAND': 400},
          feedDistribution: const {'feed-01': 500, 'feed-02': 500},
          burstSize: 1000,
        )
        .add(
          label: 'STR-OTHER',
          cancelled: false,
          scenarioLabel: 'Baseline sweep',
          tags: const ['baseline'],
          attempted: 900,
          appended: 850,
          skipped: 50,
          decisions: 30,
          throughput: 180,
          p50Throughput: 170,
          p95Throughput: 190,
          verifyMs: 60,
          chunkSize: 600,
          chunks: 2,
          avgChunkMs: 20,
          maxChunkMs: 35,
          slowChunks: 0,
          duplicatesInjected: 0,
          uniqueFeeds: 2,
          peakPending: 900,
          siteDistribution: const {'SITE-SANDTON': 500, 'SITE-MIDRAND': 350},
          feedDistribution: const {'feed-01': 450, 'feed-02': 450},
          burstSize: 900,
        );

    await tester.pumpWidget(
      MaterialApp(
        home: DispatchPage(
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          onGenerate: () {},
          onIngestFeeds: () {},
          onRunStress: (_) async {},
          onRunSoak: (_) async {},
          onRunBenchmarkSuite: () async {},
          initialProfile: IntakeStressPreset.medium.profile,
          onProfileChanged: (_) {},
          onScenarioChanged: (scenarioLabel, tags) {},
          onRunNoteChanged: (_) {},
          onFilterPresetsChanged: (presets) {
            latestPresets = presets;
          },
          onTelemetryImported: (_) {},
          onCancelStress: () {},
          onResetTelemetry: () {},
          onClearTelemetryPersistence: () {},
          onClearProfilePersistence: () {},
          stressRunning: false,
          intakeTelemetry: telemetry,
          events: const [],
          onExecute: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Run Scenario: Hotspot replay'));
    await tester.pump();
    expect(find.text('Scenario: Hotspot replay'), findsOneWidget);

    await tester.tap(find.text('History: 6'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History: 3').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sort: Latest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort: Verify Asc').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save View'));
    await tester.pumpAndSettle();
    expect(find.text('Save Filter Preset'), findsOneWidget);
    expect(find.text('Preset name'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(latestPresets, isEmpty);
    expect(find.text('View: none'), findsOneWidget);

    await tester.tap(find.text('Save View'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextField)),
      'Hotspot View',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(latestPresets, hasLength(1));
    expect(latestPresets.first.name, 'Hotspot View');
    expect(latestPresets.first.revision, 1);
    expect(latestPresets.first.updatedAtUtc, isNotEmpty);
    expect(latestPresets.first.scenarioFilter, 'Hotspot replay');
    expect(latestPresets.first.historyLimit, 3);
    expect(latestPresets.first.sort, 'verifyAsc');
    expect(find.text('View: Hotspot View'), findsOneWidget);
    expect(find.text('View Synced'), findsOneWidget);

    await tester.tap(find.text('Rename View'));
    await tester.pumpAndSettle();
    expect(find.text('Rename Filter Preset'), findsOneWidget);
    expect(find.text('Preset name'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(latestPresets, hasLength(1));
    expect(latestPresets.first.name, 'Hotspot View');
    expect(find.text('View: Hotspot View'), findsOneWidget);

    await tester.tap(find.text('Rename View'));
    await tester.pumpAndSettle();
    final renameDialog = find.byType(AlertDialog);
    await tester.enterText(
      find.descendant(of: renameDialog, matching: find.byType(TextField)),
      'Ops View',
    );
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    expect(latestPresets, hasLength(1));
    expect(latestPresets.first.name, 'Ops View');
    expect(latestPresets.first.revision, 1);
    expect(latestPresets.first.updatedAtUtc, isNotEmpty);
    expect(find.text('View: Ops View'), findsWidgets);
    expect(find.text('View Synced'), findsOneWidget);
    expect(find.text('Rev 1'), findsOneWidget);
    expect(find.textContaining('Updated '), findsOneWidget);

    await tester.tap(find.text('Copy View JSON'));
    await tester.pump();
    final copiedViewClipboard = await Clipboard.getData(Clipboard.kTextPlain);
    expect(copiedViewClipboard, isNotNull);
    final copiedView = DispatchBenchmarkFilterPreset.fromJson(
      _decodeClipboardMap(copiedViewClipboard!.text!),
    );
    expect(copiedView.name, 'Ops View');
    expect(copiedView.revision, 1);

    await tester.tap(find.text('Delete View'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Filter Preset'), findsOneWidget);
    expect(find.text('Remove "Ops View"?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(latestPresets, hasLength(1));
    expect(find.text('View: Ops View'), findsWidgets);

    await tester.tap(find.text('Show Cancelled'));
    await tester.pump();
    expect(find.text('View Dirty'), findsOneWidget);

    await tester.tap(find.text('Overwrite View'));
    await tester.pump();
    expect(latestPresets, hasLength(1));
    expect(latestPresets.first.name, 'Ops View');
    expect(latestPresets.first.revision, 2);
    expect(latestPresets.first.updatedAtUtc, isNotEmpty);
    expect(latestPresets.first.showCancelledRuns, isFalse);
    expect(find.text('View Synced'), findsOneWidget);
    expect(find.text('Rev 2'), findsOneWidget);

    await tester.tap(find.text('Clear Filters'));
    await tester.pump();
    expect(find.text('Scenario: all'), findsOneWidget);

    await tester.tap(find.text('View: none'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View: Ops View').last);
    await tester.pumpAndSettle();

    expect(find.text('Scenario: Hotspot replay'), findsOneWidget);
    expect(find.text('History: 3'), findsOneWidget);
    expect(find.text('Sort: Verify Asc'), findsOneWidget);
    expect(find.text('View Synced'), findsOneWidget);
    expect(find.text('Rev 2'), findsOneWidget);
    expect(
      find.text(
        'Active Filters: scenario Hotspot replay • tag all • note all • status all • baseline none',
      ),
      findsOneWidget,
    );

    await tester.tap(find.textContaining('Ops View • Rev 2').first);
    await tester.pumpAndSettle();
    expect(find.text('View: Ops View'), findsOneWidget);
    expect(find.text('View Synced'), findsOneWidget);
    expect(find.text('History: 3'), findsOneWidget);
    expect(find.text('Sort: Verify Asc'), findsOneWidget);

    await tester.tap(find.text('Delete View'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(latestPresets, isEmpty);
    expect(find.text('View: none'), findsOneWidget);

    await Clipboard.setData(
      ClipboardData(
        text: _encodeJson({
          'name': 'Ops View',
          'revision': 4,
          'updatedAtUtc': '2026-03-03T15:22:10.000Z',
          'showCancelledRuns': true,
          'statusFilters': ['IMPROVED', 'STABLE'],
          'scenarioFilter': 'Baseline sweep',
          'tagFilter': 'baseline',
          'noteFilter': '',
          'sort': 'throughputDesc',
          'historyLimit': 6,
        }),
      ),
    );
    await tester.tap(find.text('Import View JSON'));
    await tester.pumpAndSettle();
    expect(find.text('Import Filter Preset'), findsOneWidget);
    expect(find.text('View: Ops View'), findsOneWidget);
    expect(find.text('Mode: New imported view'), findsOneWidget);
    expect(find.text('Revision: Rev 4'), findsOneWidget);
    expect(find.text('Sort: Throughput Desc'), findsOneWidget);
    expect(find.text('History: 6'), findsWidgets);
    await tester.tap(find.text('Import'));
    await tester.pump();
    expect(latestPresets, hasLength(1));
    expect(latestPresets.first.name, 'Ops View');
    expect(latestPresets.first.revision, 4);

    await Clipboard.setData(
      ClipboardData(
        text: _encodeJson({
          'name': 'Ops View',
          'revision': 6,
          'updatedAtUtc': '2026-03-03T15:52:10.000Z',
          'showCancelledRuns': true,
          'statusFilters': ['IMPROVED', 'STABLE'],
          'scenarioFilter': 'Baseline sweep',
          'tagFilter': 'baseline',
          'noteFilter': '',
          'sort': 'throughputDesc',
          'historyLimit': 6,
        }),
      ),
    );
    await tester.tap(find.text('Import View JSON'));
    await tester.pumpAndSettle();
    expect(find.text('Replace Filter Preset'), findsOneWidget);
    expect(find.text('Revision: Rev 6'), findsOneWidget);
    expect(find.text('Replacing: Rev 4'), findsOneWidget);
    expect(find.text('Changes: none'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(latestPresets, hasLength(1));
    expect(latestPresets.first.revision, 4);

    await Clipboard.setData(
      ClipboardData(
        text: _encodeJson({
          'name': 'Ops View',
          'revision': 5,
          'updatedAtUtc': '2026-03-03T16:22:10.000Z',
          'showCancelledRuns': false,
          'statusFilters': ['DEGRADED'],
          'scenarioFilter': 'Hotspot replay',
          'tagFilter': 'soak',
          'noteFilter': 'handoff',
          'sort': 'verifyAsc',
          'historyLimit': 3,
        }),
      ),
    );
    await tester.tap(find.text('Import View JSON'));
    await tester.pumpAndSettle();
    expect(find.text('Replace Filter Preset'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('View: Ops View'),
      ),
      findsOneWidget,
    );
    expect(find.text('Mode: Replace existing view'), findsOneWidget);
    expect(find.text('Revision: Rev 5'), findsOneWidget);
    expect(find.text('Replacing: Rev 4'), findsOneWidget);
    expect(find.text('Changes: cancelled: on -> off'), findsOneWidget);
    expect(find.text('- status: IMPROVED|STABLE -> DEGRADED'), findsOneWidget);
    expect(
      find.text('- scenario: Baseline sweep -> Hotspot replay'),
      findsOneWidget,
    );
    expect(find.text('- tag: baseline -> soak'), findsOneWidget);
    expect(find.text('- note: all -> handoff'), findsOneWidget);
    expect(find.text('- sort: Throughput Desc -> Verify Asc'), findsOneWidget);
    expect(find.text('- history: 6 -> 3'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(latestPresets, hasLength(1));
    expect(latestPresets.first.revision, 4);

    await tester.tap(find.text('Import View JSON'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(latestPresets, hasLength(1));
    expect(latestPresets.first.name, 'Ops View');
    expect(latestPresets.first.revision, 5);
    expect(find.text('View: Ops View'), findsWidgets);
    expect(find.text('Scenario: Hotspot replay'), findsOneWidget);
    expect(find.text('Tag: soak'), findsOneWidget);
    expect(find.text('Sort: Verify Asc'), findsOneWidget);
    expect(find.text('History: 3'), findsOneWidget);
  });
}

Map<String, dynamic> _decodeClipboardMap(String text) {
  return Map<String, dynamic>.from(_jsonDecode(text) as Map);
}

Future<void> _openAdvancedSnapshotProfileTools(WidgetTester tester) async {
  final advancedToolsToggle = find.text('Advanced Snapshot & Profile Tools');
  if (advancedToolsToggle.evaluate().isEmpty) {
    return;
  }
  await tester.ensureVisible(advancedToolsToggle);
  await tester.tap(advancedToolsToggle);
  await tester.pumpAndSettle();
}

Object _jsonDecode(String text) => const JsonDecoder().convert(text);

String _encodeJson(Map<String, Object?> value) =>
    const JsonEncoder().convert(value);
