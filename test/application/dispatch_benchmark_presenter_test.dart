import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/dispatch_benchmark_presenter.dart';
import 'package:omnix_dashboard/application/dispatch_models.dart';

void main() {
  IntakeRunSummary buildRun({
    required String label,
    required double throughput,
    required int verifyMs,
    bool cancelled = false,
    String scenarioLabel = '',
    List<String> tags = const [],
    String note = '',
    Map<String, int> siteDistribution = const {
      'SITE-SANDTON': 250,
      'SITE-MIDRAND': 250,
      'SITE-ROSEBANK': 250,
      'SITE-CENTURION': 250,
    },
  }) {
    return IntakeRunSummary(
      label: label,
      cancelled: cancelled,
      scenarioLabel: scenarioLabel,
      tags: tags,
      note: note,
      ranAtUtc: DateTime.utc(2026, 3, 3, 12),
      attempted: 1000,
      appended: 900,
      skipped: 100,
      decisions: 40,
      throughput: throughput,
      p50: throughput - 10,
      p95: throughput + 10,
      verifyMs: verifyMs,
      chunkSize: 600,
      chunks: 2,
      avgChunkMs: 24,
      maxChunkMs: 40,
      slowChunks: 0,
      duplicatesInjected: 0,
      uniqueFeeds: 2,
      peakPending: 400,
      siteDistribution: siteDistribution,
      feedDistribution: const {
        'feed-01': 250,
        'feed-02': 250,
        'feed-03': 250,
        'feed-04': 250,
      },
    );
  }

  group('DispatchBenchmarkPresenter', () {
    test('buildRows filters, computes deltas, and sorts by throughput', () {
      final runs = [
        buildRun(
          label: 'STR-03',
          throughput: 210,
          verifyMs: 55,
          scenarioLabel: 'Hotspot replay',
          tags: const ['soak', 'skew'],
        ),
        buildRun(label: 'STR-02', throughput: 160, verifyMs: 70),
        buildRun(
          label: 'STR-01',
          throughput: 180,
          verifyMs: 65,
          cancelled: true,
        ),
      ];

      final rows = DispatchBenchmarkPresenter.buildRows(
        runs: runs,
        showCancelledRuns: false,
        historyLimit: 3,
        baselineRunLabel: 'STR-02',
        tagFilter: null,
        noteFilter: null,
        statusFilters: const {'BASELINE', 'IMPROVED', 'STABLE', 'DEGRADED'},
        sort: DispatchBenchmarkSort.throughputDesc,
      );

      expect(rows, hasLength(2));
      expect(rows.first.run.label, 'STR-03');
      expect(rows.first.status, 'IMPROVED');
      expect(rows.first.tone, DispatchBenchmarkTone.positive);
      expect(rows.first.throughputDelta, 50);
      expect(rows.first.verifyDelta, -15);
      expect(rows.first.baselineThroughputDelta, 50);
      expect(rows.first.baselineVerifyDelta, -15);
      expect(rows.first.summary, contains('[IMPROVED] STR-03'));
      expect(rows.first.summary, contains('scenario Hotspot replay'));
      expect(rows.first.summary, contains('tags soak, skew'));
      expect(rows.first.summary, contains('vs STR-02: thr +50.0, verify -15'));
      expect(rows.last.run.label, 'STR-02');
      expect(rows.last.status, 'BASELINE');
    });

    test('buildRows filters by scenario label', () {
      final runs = [
        buildRun(
          label: 'STR-03',
          throughput: 210,
          verifyMs: 55,
          scenarioLabel: 'Hotspot replay',
        ),
        buildRun(
          label: 'STR-02',
          throughput: 160,
          verifyMs: 70,
          scenarioLabel: 'Baseline sweep',
        ),
      ];

      final rows = DispatchBenchmarkPresenter.buildRows(
        runs: runs,
        showCancelledRuns: true,
        historyLimit: 3,
        baselineRunLabel: null,
        tagFilter: null,
        scenarioFilter: 'Hotspot replay',
        noteFilter: null,
        statusFilters: const {'BASELINE', 'IMPROVED', 'STABLE', 'DEGRADED'},
        sort: DispatchBenchmarkSort.latest,
      );

      expect(rows, hasLength(1));
      expect(rows.single.run.label, 'STR-03');
    });

    test('buildRows filters by tag', () {
      final runs = [
        buildRun(
          label: 'STR-03',
          throughput: 210,
          verifyMs: 55,
          tags: const ['soak', 'skew'],
        ),
        buildRun(
          label: 'STR-02',
          throughput: 160,
          verifyMs: 70,
          tags: const ['baseline'],
        ),
      ];

      final rows = DispatchBenchmarkPresenter.buildRows(
        runs: runs,
        showCancelledRuns: true,
        historyLimit: 3,
        baselineRunLabel: null,
        scenarioFilter: null,
        tagFilter: 'skew',
        noteFilter: null,
        statusFilters: const {'BASELINE', 'IMPROVED', 'STABLE', 'DEGRADED'},
        sort: DispatchBenchmarkSort.latest,
      );

      expect(rows, hasLength(1));
      expect(rows.single.run.label, 'STR-03');
    });

    test('buildRows filters by note substring', () {
      final runs = [
        buildRun(
          label: 'STR-03',
          throughput: 210,
          verifyMs: 55,
          note: 'Shift handoff',
        ),
        buildRun(
          label: 'STR-02',
          throughput: 160,
          verifyMs: 70,
          note: 'Baseline pass',
        ),
      ];

      final rows = DispatchBenchmarkPresenter.buildRows(
        runs: runs,
        showCancelledRuns: true,
        historyLimit: 3,
        baselineRunLabel: null,
        scenarioFilter: null,
        tagFilter: null,
        noteFilter: 'handoff',
        statusFilters: const {'BASELINE', 'IMPROVED', 'STABLE', 'DEGRADED'},
        sort: DispatchBenchmarkSort.latest,
      );

      expect(rows, hasLength(1));
      expect(rows.single.run.label, 'STR-03');
    });

    test('buildRows honors status filters and verify sort', () {
      final runs = [
        buildRun(label: 'STR-03', throughput: 150, verifyMs: 180),
        buildRun(
          label: 'STR-02',
          throughput: 190,
          verifyMs: 50,
          siteDistribution: const {'SITE-SANDTON': 800, 'SITE-MIDRAND': 200},
        ),
        buildRun(label: 'STR-01', throughput: 195, verifyMs: 40),
      ];

      final rows = DispatchBenchmarkPresenter.buildRows(
        runs: runs,
        showCancelledRuns: true,
        historyLimit: 3,
        baselineRunLabel: null,
        scenarioFilter: null,
        tagFilter: null,
        noteFilter: null,
        statusFilters: const {'DEGRADED'},
        sort: DispatchBenchmarkSort.verifyAsc,
      );

      expect(rows, hasLength(2));
      expect(rows.first.run.label, 'STR-02');
      expect(rows.first.status, 'DEGRADED');
      expect(rows.first.tone, DispatchBenchmarkTone.negative);
      expect(rows.last.run.label, 'STR-03');
      expect(rows.last.status, 'DEGRADED');
    });

    test('medianThroughput and throughputTrend summarize runs', () {
      final runs = [
        buildRun(label: 'STR-03', throughput: 240, verifyMs: 50),
        buildRun(label: 'STR-02', throughput: 210, verifyMs: 50),
        buildRun(label: 'STR-01', throughput: 160, verifyMs: 50),
      ];

      expect(DispatchBenchmarkPresenter.medianThroughput(runs), 210);
      expect(DispatchBenchmarkPresenter.throughputTrend(runs), '↑↑');
      expect(DispatchBenchmarkPresenter.throughputTrend([runs.first]), 'N/A');
    });
  });
}
