import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/ui/dispatch_page.dart';

void main() {
  group('IntakeStressProfile', () {
    test('round-trips through json', () {
      const profile = IntakeStressProfile(
        feeds: 4,
        recordsPerFeed: 500,
        bursts: 3,
        highRiskPercent: 35,
        siteSpread: 2,
        maxAttemptedEvents: 60000,
        seed: 1337,
        chunkSize: 1200,
        duplicatePercent: 10,
        interBurstDelayMs: 25,
        verifyReplay: true,
        stopOnRegression: true,
        regressionThroughputDrop: 20,
        regressionVerifyIncreaseMs: 100,
        maxRegressionPressureSeverity: 2,
        maxRegressionImbalanceSeverity: 2,
        soakRuns: 5,
      );

      final restored = IntakeStressProfile.fromJson(profile.toJson());

      expect(restored.toJson(), profile.toJson());
    });

    test('restores defaults for missing regression thresholds', () {
      final restored = IntakeStressProfile.fromJson(const {
        'feeds': 3,
        'recordsPerFeed': 200,
        'bursts': 5,
        'highRiskPercent': 35,
        'siteSpread': 1,
        'maxAttemptedEvents': 60000,
        'seed': 42,
        'chunkSize': 1200,
        'duplicatePercent': 5,
        'interBurstDelayMs': 25,
        'verifyReplay': false,
        'stopOnRegression': true,
        'soakRuns': 3,
      });

      expect(restored.regressionThroughputDrop, 20);
      expect(restored.regressionVerifyIncreaseMs, 100);
      expect(restored.maxRegressionPressureSeverity, 2);
      expect(restored.maxRegressionImbalanceSeverity, 2);
    });
  });

  group('IntakeRunSummary', () {
    test('derives pressure and imbalance severity', () {
      final run = IntakeRunSummary(
        label: 'STR-0001',
        cancelled: false,
        ranAtUtc: DateTime.utc(2026, 3, 3, 10),
        attempted: 1000,
        appended: 900,
        skipped: 100,
        decisions: 50,
        throughput: 180.0,
        p50: 170.0,
        p95: 190.0,
        verifyMs: 120,
        chunkSize: 300,
        chunks: 4,
        avgChunkMs: 82.0,
        maxChunkMs: 165,
        slowChunks: 3,
        duplicatesInjected: 100,
        uniqueFeeds: 4,
        peakPending: 1000,
        siteDistribution: const {'SITE-SANDTON': 800, 'SITE-ROSEBANK': 200},
        feedDistribution: const {
          'feed-01': 250,
          'feed-02': 250,
          'feed-03': 250,
          'feed-04': 250,
        },
      );

      expect(run.pressureSeverity, 2);
      expect(run.imbalanceSeverity, 2);
      expect(run.imbalanceScore, closeTo(0.8, 0.0001));
      expect(run.hottestSite?.key, 'SITE-SANDTON');
      expect(run.hottestSite?.value, 800);
    });
  });

  group('IntakeTelemetry', () {
    test('accumulates runs and preserves soak summary across add', () {
      final withSoak = IntakeTelemetry.zero.withSoakSummary(
        runs: 3,
        throughputDrift: -24.5,
        verifyDriftMs: 180,
      );

      final telemetry = withSoak.add(
        label: 'STR-0002',
        cancelled: false,
        scenarioLabel: 'Hotspot replay',
        tags: const ['soak', 'skew'],
        note: 'Shift handoff',
        attempted: 1000,
        appended: 900,
        skipped: 100,
        decisions: 40,
        throughput: 225.0,
        p50Throughput: 210.0,
        p95Throughput: 240.0,
        verifyMs: 75,
        chunkSize: 600,
        chunks: 2,
        avgChunkMs: 24.0,
        maxChunkMs: 40,
        slowChunks: 0,
        duplicatesInjected: 50,
        uniqueFeeds: 3,
        peakPending: 1000,
        siteDistribution: const {'SITE-SANDTON': 600, 'SITE-ROSEBANK': 400},
        feedDistribution: const {
          'feed-01': 350,
          'feed-02': 350,
          'feed-03': 300,
        },
        burstSize: 1000,
      );

      expect(telemetry.runs, 1);
      expect(telemetry.totalAppended, 900);
      expect(telemetry.totalSkipped, 100);
      expect(telemetry.totalDecisions, 40);
      expect(telemetry.averageThroughput, 225.0);
      expect(telemetry.averageVerifyMs, 75.0);
      expect(telemetry.averageChunkMs, 24.0);
      expect(telemetry.totalDuplicatesInjected, 50);
      expect(telemetry.lastSoakRuns, 3);
      expect(telemetry.lastSoakDriftThroughput, -24.5);
      expect(telemetry.lastSoakDriftVerifyMs, 180);
      expect(telemetry.recentRuns.first.scenarioLabel, 'Hotspot replay');
      expect(telemetry.recentRuns.first.tags, const ['soak', 'skew']);
      expect(telemetry.recentRuns.first.note, 'Shift handoff');
    });

    test('round-trips through json with recent runs', () {
      final telemetry = IntakeTelemetry.zero
          .add(
            label: 'STR-0003',
            cancelled: false,
            attempted: 1200,
            appended: 1000,
            skipped: 200,
            decisions: 60,
            throughput: 250.0,
            p50Throughput: 240.0,
            p95Throughput: 260.0,
            verifyMs: 90,
            chunkSize: 600,
            chunks: 2,
            avgChunkMs: 30.0,
            maxChunkMs: 48,
            slowChunks: 0,
            duplicatesInjected: 60,
            uniqueFeeds: 2,
            peakPending: 1200,
            siteDistribution: const {'SITE-SANDTON': 700, 'SITE-MIDRAND': 500},
            feedDistribution: const {'feed-01': 600, 'feed-02': 600},
            burstSize: 1200,
          )
          .withSoakSummary(runs: 2, throughputDrift: 12.5, verifyDriftMs: -10);

      final restored = IntakeTelemetry.fromJson(telemetry.toJson());

      expect(restored.toJson(), telemetry.toJson());
      expect(restored.recentRuns, hasLength(1));
      expect(restored.recentRuns.first.pressureSeverity, 1);
      expect(restored.recentRuns.first.imbalanceSeverity, 1);
    });

    test('updates a historical run note by label', () {
      final telemetry = IntakeTelemetry.zero.add(
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

      final updated = telemetry.updateRunNote(label: 'STR-EDIT', note: 'After');

      expect(updated.recentRuns.first.note, 'After');
      expect(updated.runs, telemetry.runs);
      expect(updated.totalAppended, telemetry.totalAppended);
    });

    test('updates historical run metadata by label', () {
      final telemetry = IntakeTelemetry.zero.add(
        label: 'STR-META',
        cancelled: false,
        scenarioLabel: 'Original scenario',
        tags: const ['one'],
        note: 'Original note',
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

      final updated = telemetry.updateRunMetadata(
        label: 'STR-META',
        scenarioLabel: 'Updated scenario',
        tags: const ['alpha', 'beta'],
        note: 'Updated note',
      );

      expect(updated.recentRuns.first.scenarioLabel, 'Updated scenario');
      expect(updated.recentRuns.first.tags, const ['alpha', 'beta']);
      expect(updated.recentRuns.first.note, 'Updated note');
      expect(updated.totalAppended, telemetry.totalAppended);
      expect(updated.totalSkipped, telemetry.totalSkipped);
    });
  });

  group('shouldStopSoakOnRegression', () {
    IntakeRunSummary buildRun({
      required double throughput,
      required int verifyMs,
      required int chunkSize,
      required int maxChunkMs,
      required int slowChunks,
      required int peakPending,
      required Map<String, int> siteDistribution,
    }) {
      return IntakeRunSummary(
        label: 'STR-X',
        cancelled: false,
        ranAtUtc: DateTime.utc(2026, 3, 3, 12),
        attempted: 1000,
        appended: 900,
        skipped: 100,
        decisions: 40,
        throughput: throughput,
        p50: throughput - 10,
        p95: throughput + 10,
        verifyMs: verifyMs,
        chunkSize: chunkSize,
        chunks: 3,
        avgChunkMs: 40.0,
        maxChunkMs: maxChunkMs,
        slowChunks: slowChunks,
        duplicatesInjected: 0,
        uniqueFeeds: 3,
        peakPending: peakPending,
        siteDistribution: siteDistribution,
        feedDistribution: const {
          'feed-01': 334,
          'feed-02': 333,
          'feed-03': 333,
        },
      );
    }

    test('returns false when no regression threshold is hit', () {
      final baseline = buildRun(
        throughput: 200,
        verifyMs: 50,
        chunkSize: 600,
        maxChunkMs: 40,
        slowChunks: 0,
        peakPending: 600,
        siteDistribution: const {'SITE-SANDTON': 500, 'SITE-MIDRAND': 500},
      );
      final latest = buildRun(
        throughput: 195,
        verifyMs: 80,
        chunkSize: 600,
        maxChunkMs: 60,
        slowChunks: 0,
        peakPending: 700,
        siteDistribution: const {'SITE-SANDTON': 520, 'SITE-MIDRAND': 480},
      );

      expect(
        shouldStopSoakOnRegression(baseline: baseline, latest: latest),
        isFalse,
      );
    });

    test('returns true on throughput regression', () {
      final baseline = buildRun(
        throughput: 200,
        verifyMs: 50,
        chunkSize: 600,
        maxChunkMs: 40,
        slowChunks: 0,
        peakPending: 600,
        siteDistribution: const {'SITE-SANDTON': 500, 'SITE-MIDRAND': 500},
      );
      final latest = buildRun(
        throughput: 175,
        verifyMs: 50,
        chunkSize: 600,
        maxChunkMs: 40,
        slowChunks: 0,
        peakPending: 600,
        siteDistribution: const {'SITE-SANDTON': 500, 'SITE-MIDRAND': 500},
      );

      expect(
        shouldStopSoakOnRegression(baseline: baseline, latest: latest),
        isTrue,
      );
    });

    test('returns true on severe pressure or imbalance', () {
      final baseline = buildRun(
        throughput: 200,
        verifyMs: 50,
        chunkSize: 600,
        maxChunkMs: 40,
        slowChunks: 0,
        peakPending: 600,
        siteDistribution: const {'SITE-SANDTON': 500, 'SITE-MIDRAND': 500},
      );
      final latest = buildRun(
        throughput: 205,
        verifyMs: 60,
        chunkSize: 300,
        maxChunkMs: 180,
        slowChunks: 3,
        peakPending: 1000,
        siteDistribution: const {'SITE-SANDTON': 800, 'SITE-MIDRAND': 200},
      );

      expect(
        shouldStopSoakOnRegression(baseline: baseline, latest: latest),
        isTrue,
      );
    });

    test('respects overridden thresholds', () {
      final baseline = buildRun(
        throughput: 200,
        verifyMs: 50,
        chunkSize: 600,
        maxChunkMs: 40,
        slowChunks: 0,
        peakPending: 600,
        siteDistribution: const {'SITE-SANDTON': 500, 'SITE-MIDRAND': 500},
      );
      final latest = buildRun(
        throughput: 188,
        verifyMs: 120,
        chunkSize: 600,
        maxChunkMs: 40,
        slowChunks: 0,
        peakPending: 600,
        siteDistribution: const {'SITE-SANDTON': 500, 'SITE-MIDRAND': 500},
      );

      expect(
        shouldStopSoakOnRegression(
          baseline: baseline,
          latest: latest,
          minThroughputDelta: -15,
          maxVerifyDeltaMs: 60,
        ),
        isTrue,
      );
    });
  });

  group('DispatchSnapshot', () {
    test('round-trips profile and telemetry', () {
      final profile = IntakeStressPreset.heavy.profile.copyWith(
        regressionThroughputDrop: 40,
        regressionVerifyIncreaseMs: 200,
      );
      final telemetry = IntakeTelemetry.zero.add(
        label: 'STR-SNAPSHOT',
        cancelled: false,
        attempted: 900,
        appended: 850,
        skipped: 50,
        decisions: 30,
        throughput: 205,
        p50Throughput: 190,
        p95Throughput: 215,
        verifyMs: 70,
        chunkSize: 600,
        chunks: 2,
        avgChunkMs: 21,
        maxChunkMs: 39,
        slowChunks: 0,
        duplicatesInjected: 10,
        uniqueFeeds: 2,
        peakPending: 900,
        siteDistribution: const {'SITE-SANDTON': 500, 'SITE-MIDRAND': 400},
        feedDistribution: const {'feed-01': 450, 'feed-02': 450},
        burstSize: 900,
      );
      final snapshot = DispatchSnapshot(
        scenarioLabel: 'Load skew probe',
        tags: const ['stress', 'skew'],
        runNote: 'Shift handoff',
        filterPresets: const [
          DispatchBenchmarkFilterPreset(
            name: 'Ops View',
            updatedAtUtc: '2026-03-03T12:00:00.000Z',
            showCancelledRuns: false,
            statusFilters: ['DEGRADED'],
            scenarioFilter: 'Load skew probe',
            tagFilter: 'stress',
            noteFilter: 'handoff',
            sort: 'verifyAsc',
            historyLimit: 3,
          ),
        ],
        profile: profile,
        telemetry: telemetry,
      );

      final restored = DispatchSnapshot.fromJson(snapshot.toJson());

      expect(restored.version, 2);
      expect(restored.scenarioLabel, 'Load skew probe');
      expect(restored.tags, const ['stress', 'skew']);
      expect(restored.runNote, 'Shift handoff');
      expect(restored.filterPresets, hasLength(1));
      expect(restored.filterPresets.first.name, 'Ops View');
      expect(restored.profile.toJson(), profile.toJson());
      expect(restored.telemetry.toJson(), telemetry.toJson());
      expect(restored.toJson(), snapshot.toJson());
    });

    test('defaults version when missing or invalid', () {
      final snapshot = DispatchSnapshot.fromJson({
        'version': 0,
        'profile': IntakeStressPreset.light.profile.toJson(),
        'telemetry': IntakeTelemetry.zero.toJson(),
      });

      expect(snapshot.version, 2);
      expect(snapshot.scenarioLabel, '');
      expect(snapshot.tags, isEmpty);
      expect(snapshot.runNote, '');
      expect(snapshot.filterPresets, isEmpty);
    });

    test('preserves older snapshot version 1 on import', () {
      final snapshot = DispatchSnapshot.fromJson({
        'version': 1,
        'profile': IntakeStressPreset.light.profile.toJson(),
        'telemetry': IntakeTelemetry.zero.toJson(),
      });

      expect(snapshot.version, 1);
    });
  });

  group('DispatchProfileDraft', () {
    test('round-trips profile and scenario metadata', () {
      final draft = DispatchProfileDraft(
        profile: IntakeStressPreset.medium.profile,
        scenarioLabel: 'Replay soak',
        tags: const ['stress', 'replay'],
        runNote: 'Shift handoff',
        filterPresets: const [
          DispatchBenchmarkFilterPreset(
            name: 'Hotspot View',
            updatedAtUtc: '2026-03-03T12:00:00.000Z',
            showCancelledRuns: false,
            statusFilters: ['DEGRADED'],
            scenarioFilter: 'Replay soak',
            tagFilter: 'stress',
            noteFilter: 'handoff',
            sort: 'verifyAsc',
            historyLimit: 3,
          ),
        ],
      );

      final restored = DispatchProfileDraft.fromJson(draft.toJson());

      expect(restored.toJson(), draft.toJson());
    });
  });

  test('DispatchProfileDraft round-trips intelligence filters', () {
    final draft = DispatchProfileDraft(
      profile: IntakeStressPreset.medium.profile,
      scenarioLabel: 'Night watch',
      tags: ['community', 'intel'],
      runNote: 'Persist filters',
      intelligenceSourceFilter: 'community',
      intelligenceActionFilter: 'Watch',
      pinnedWatchIntelligenceIds: const ['INT-001'],
      dismissedIntelligenceIds: const ['INT-002'],
      showPinnedWatchIntelligenceOnly: true,
      showDismissedIntelligenceOnly: false,
      selectedIntelligenceId: 'INT-001',
    );

    final restored = DispatchProfileDraft.fromJson(draft.toJson());

    expect(restored.toJson(), draft.toJson());
    expect(restored.intelligenceSourceFilter, 'community');
    expect(restored.intelligenceActionFilter, 'Watch');
    expect(restored.pinnedWatchIntelligenceIds, ['INT-001']);
    expect(restored.dismissedIntelligenceIds, ['INT-002']);
    expect(restored.showPinnedWatchIntelligenceOnly, isTrue);
    expect(restored.showDismissedIntelligenceOnly, isFalse);
    expect(restored.selectedIntelligenceId, 'INT-001');
  });
}
