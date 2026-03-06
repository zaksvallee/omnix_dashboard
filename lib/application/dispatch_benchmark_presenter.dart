import '../ui/dispatch_models.dart';

enum DispatchBenchmarkTone { neutral, positive, negative }

enum DispatchBenchmarkSort {
  latest('Latest'),
  throughputDesc('Throughput Desc'),
  verifyAsc('Verify Asc');

  final String label;
  const DispatchBenchmarkSort(this.label);
}

class DispatchBenchmarkRow {
  final IntakeRunSummary run;
  final String status;
  final DispatchBenchmarkTone tone;
  final String summary;
  final double? throughputDelta;
  final int? verifyDelta;
  final double? baselineThroughputDelta;
  final int? baselineVerifyDelta;

  const DispatchBenchmarkRow({
    required this.run,
    required this.status,
    required this.tone,
    required this.summary,
    required this.throughputDelta,
    required this.verifyDelta,
    required this.baselineThroughputDelta,
    required this.baselineVerifyDelta,
  });
}

class DispatchBenchmarkPresenter {
  const DispatchBenchmarkPresenter._();

  static List<DispatchBenchmarkRow> buildRows({
    required List<IntakeRunSummary> runs,
    required bool showCancelledRuns,
    required int historyLimit,
    required String? baselineRunLabel,
    String? scenarioFilter,
    String? tagFilter,
    String? noteFilter,
    required Set<String> statusFilters,
    required DispatchBenchmarkSort sort,
  }) {
    final normalizedNoteFilter = noteFilter?.trim().toLowerCase() ?? '';
    final filtered = runs
        .where((run) => showCancelledRuns || !run.cancelled)
        .where(
          (run) =>
              scenarioFilter == null ||
              scenarioFilter.isEmpty ||
              run.scenarioLabel == scenarioFilter,
        )
        .where(
          (run) =>
              tagFilter == null ||
              tagFilter.isEmpty ||
              run.tags.contains(tagFilter),
        )
        .where(
          (run) =>
              normalizedNoteFilter.isEmpty ||
              run.note.toLowerCase().contains(normalizedNoteFilter),
        )
        .take(historyLimit)
        .toList(growable: false);
    if (filtered.isEmpty) {
      return const [];
    }

    final baseline = baselineRunLabel == null
        ? null
        : filtered.where((run) => run.label == baselineRunLabel).firstOrNull;

    final rows = filtered
        .asMap()
        .entries
        .map((entry) {
          final idx = entry.key;
          final run = entry.value;
          final prev = idx + 1 < filtered.length ? filtered[idx + 1] : null;
          final throughputDelta = prev == null
              ? null
              : (run.throughput - prev.throughput);
          final verifyDelta = prev == null
              ? null
              : (run.verifyMs - prev.verifyMs);
          final baselineThroughputDelta = baseline == null
              ? null
              : (run.throughput - baseline.throughput);
          final baselineVerifyDelta = baseline == null
              ? null
              : (run.verifyMs - baseline.verifyMs);
          final status = _runStatus(run, throughputDelta, verifyDelta);
          return DispatchBenchmarkRow(
            run: run,
            status: status,
            tone: _toneForStatus(status),
            summary: _summary(
              run: run,
              status: status,
              baseline: baseline,
              throughputDelta: throughputDelta,
              verifyDelta: verifyDelta,
              baselineThroughputDelta: baselineThroughputDelta,
              baselineVerifyDelta: baselineVerifyDelta,
            ),
            throughputDelta: throughputDelta,
            verifyDelta: verifyDelta,
            baselineThroughputDelta: baselineThroughputDelta,
            baselineVerifyDelta: baselineVerifyDelta,
          );
        })
        .where((row) => statusFilters.contains(row.status))
        .toList(growable: true);

    switch (sort) {
      case DispatchBenchmarkSort.latest:
        break;
      case DispatchBenchmarkSort.throughputDesc:
        rows.sort((a, b) => b.run.throughput.compareTo(a.run.throughput));
        break;
      case DispatchBenchmarkSort.verifyAsc:
        rows.sort((a, b) => a.run.verifyMs.compareTo(b.run.verifyMs));
        break;
    }

    return rows;
  }

  static double medianThroughput(List<IntakeRunSummary> runs) {
    if (runs.isEmpty) return 0.0;
    final sorted = runs.map((run) => run.throughput).toList()..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return (sorted[mid - 1] + sorted[mid]) / 2.0;
  }

  static String throughputTrend(List<IntakeRunSummary> runs) {
    if (runs.length < 2) return 'N/A';
    final oldestFirst = runs.reversed.toList(growable: false);
    final arrows = <String>[];
    for (int i = 1; i < oldestFirst.length; i++) {
      final delta = oldestFirst[i].throughput - oldestFirst[i - 1].throughput;
      if (delta >= 20) {
        arrows.add('↑');
      } else if (delta <= -20) {
        arrows.add('↓');
      } else {
        arrows.add('→');
      }
    }
    return arrows.join('');
  }

  static String _runStatus(
    IntakeRunSummary run,
    double? throughputDelta,
    int? verifyDelta,
  ) {
    if (throughputDelta == null || verifyDelta == null) {
      return 'BASELINE';
    }
    if (run.pressureSeverity >= 2 ||
        run.imbalanceSeverity >= 2 ||
        throughputDelta <= -20 ||
        verifyDelta >= 100) {
      return 'DEGRADED';
    }
    if (run.pressureSeverity == 0 &&
        run.imbalanceSeverity == 0 &&
        throughputDelta >= 20 &&
        verifyDelta <= 0) {
      return 'IMPROVED';
    }
    return 'STABLE';
  }

  static DispatchBenchmarkTone _toneForStatus(String status) {
    return switch (status) {
      'IMPROVED' => DispatchBenchmarkTone.positive,
      'DEGRADED' => DispatchBenchmarkTone.negative,
      _ => DispatchBenchmarkTone.neutral,
    };
  }

  static String _summary({
    required IntakeRunSummary run,
    required String status,
    required IntakeRunSummary? baseline,
    required double? throughputDelta,
    required int? verifyDelta,
    required double? baselineThroughputDelta,
    required int? baselineVerifyDelta,
  }) {
    return '[$status] ${run.label} • app ${run.appended}/${run.attempted} • '
        '${run.scenarioLabel.isEmpty ? '' : 'scenario ${run.scenarioLabel} • '}'
        '${run.tags.isEmpty ? '' : 'tags ${run.tags.join(', ')} • '}'
        'skip ${run.skipped} • dec ${run.decisions}'
        '${run.cancelled ? ' • CANCELLED' : ''} • '
        'p50 ${run.p50.toStringAsFixed(1)} • '
        'p95 ${run.p95.toStringAsFixed(1)} • '
        '${run.throughput.toStringAsFixed(1)} ev/s'
        '${_signedDoubleDelta(throughputDelta)} • '
        'verify ${run.verifyMs} ms • '
        'chunk ${run.chunkSize}/${run.chunks} avg ${run.avgChunkMs.toStringAsFixed(1)} ms '
        'max ${run.maxChunkMs} ms • slow ${run.slowChunks} • '
        'dup ${run.duplicatesInjected} • feeds ${run.uniqueFeeds} • '
        'qpeak ${run.peakPending} • pressure ${_pressureLabel(run)} • '
        'site ${_hotspotLabel(run.hottestSite)} • '
        'feed ${_hotspotLabel(run.hottestFeed)} • '
        'imbalance ${(run.imbalanceScore * 100).toStringAsFixed(0)}%'
        '${_signedIntDelta(verifyDelta)} • '
        '${_baselineSummary(baseline: baseline, baselineThroughputDelta: baselineThroughputDelta, baselineVerifyDelta: baselineVerifyDelta)}'
        '${_runTs(run.ranAtUtc)}';
  }

  static String _baselineSummary({
    required IntakeRunSummary? baseline,
    required double? baselineThroughputDelta,
    required int? baselineVerifyDelta,
  }) {
    if (baseline == null ||
        baselineThroughputDelta == null ||
        baselineVerifyDelta == null) {
      return '';
    }
    final throughputPrefix = baselineThroughputDelta >= 0 ? '+' : '';
    final verifyPrefix = baselineVerifyDelta >= 0 ? '+' : '';
    return 'vs ${baseline.label}: thr $throughputPrefix'
        '${baselineThroughputDelta.toStringAsFixed(1)}, '
        'verify $verifyPrefix$baselineVerifyDelta • ';
  }

  static String _signedDoubleDelta(double? value) {
    if (value == null) return '';
    final prefix = value >= 0 ? '+' : '';
    return ' (Δ $prefix${value.toStringAsFixed(1)})';
  }

  static String _signedIntDelta(int? value) {
    if (value == null) return '';
    final prefix = value >= 0 ? '+' : '';
    return ' (Δ $prefix$value)';
  }

  static String _pressureLabel(IntakeRunSummary run) {
    return switch (run.pressureSeverity) {
      2 => 'HIGH',
      1 => 'ELEVATED',
      _ => 'LOW',
    };
  }

  static String _hotspotLabel(MapEntry<String, int>? hotspot) {
    if (hotspot == null) return 'N/A';
    return '${hotspot.key} (${hotspot.value})';
  }

  static String _runTs(DateTime utc) {
    final z = utc.toIso8601String();
    return z.length > 19 ? '${z.substring(0, 19)}Z' : z;
  }
}

extension on Iterable<IntakeRunSummary> {
  IntakeRunSummary? get firstOrNull {
    for (final item in this) {
      return item;
    }
    return null;
  }
}
