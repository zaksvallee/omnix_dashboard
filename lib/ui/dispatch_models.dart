// Shared dispatch stress/telemetry models extracted from dispatch_page.dart

enum IntakeStressPreset {
  light('Light'),
  medium('Medium'),
  heavy('Heavy');

  final String label;

  const IntakeStressPreset(this.label);

  IntakeStressProfile get profile {
    switch (this) {
      case IntakeStressPreset.light:
        return const IntakeStressProfile(
          feeds: 2,
          recordsPerFeed: 100,
          bursts: 1,
          highRiskPercent: 20,
          siteSpread: 1,
          maxAttemptedEvents: 20000,
          seed: 42,
          chunkSize: 600,
          duplicatePercent: 0,
          interBurstDelayMs: 0,
          verifyReplay: false,
          stopOnRegression: false,
          regressionThroughputDrop: 20,
          regressionVerifyIncreaseMs: 100,
          maxRegressionPressureSeverity: 2,
          maxRegressionImbalanceSeverity: 2,
          soakRuns: 1,
        );
      case IntakeStressPreset.medium:
        return const IntakeStressProfile(
          feeds: 3,
          recordsPerFeed: 200,
          bursts: 5,
          highRiskPercent: 35,
          siteSpread: 1,
          maxAttemptedEvents: 60000,
          seed: 42,
          chunkSize: 1200,
          duplicatePercent: 5,
          interBurstDelayMs: 25,
          verifyReplay: false,
          stopOnRegression: false,
          regressionThroughputDrop: 20,
          regressionVerifyIncreaseMs: 100,
          maxRegressionPressureSeverity: 2,
          maxRegressionImbalanceSeverity: 2,
          soakRuns: 3,
        );
      case IntakeStressPreset.heavy:
        return const IntakeStressProfile(
          feeds: 6,
          recordsPerFeed: 1000,
          bursts: 10,
          highRiskPercent: 50,
          siteSpread: 3,
          maxAttemptedEvents: 120000,
          seed: 1337,
          chunkSize: 2400,
          duplicatePercent: 10,
          interBurstDelayMs: 100,
          verifyReplay: true,
          stopOnRegression: true,
          regressionThroughputDrop: 20,
          regressionVerifyIncreaseMs: 100,
          maxRegressionPressureSeverity: 2,
          maxRegressionImbalanceSeverity: 2,
          soakRuns: 5,
        );
    }
  }
}

class IntakeStressProfile {
  final int feeds;
  final int recordsPerFeed;
  final int bursts;
  final int highRiskPercent;
  final int siteSpread;
  final int maxAttemptedEvents;
  final int seed;
  final int chunkSize;
  final int duplicatePercent;
  final int interBurstDelayMs;
  final bool verifyReplay;
  final bool stopOnRegression;
  final int regressionThroughputDrop;
  final int regressionVerifyIncreaseMs;
  final int maxRegressionPressureSeverity;
  final int maxRegressionImbalanceSeverity;
  final int soakRuns;

  const IntakeStressProfile({
    required this.feeds,
    required this.recordsPerFeed,
    required this.bursts,
    required this.highRiskPercent,
    required this.siteSpread,
    required this.maxAttemptedEvents,
    required this.seed,
    required this.chunkSize,
    required this.duplicatePercent,
    required this.interBurstDelayMs,
    required this.verifyReplay,
    required this.stopOnRegression,
    required this.regressionThroughputDrop,
    required this.regressionVerifyIncreaseMs,
    required this.maxRegressionPressureSeverity,
    required this.maxRegressionImbalanceSeverity,
    required this.soakRuns,
  });

  factory IntakeStressProfile.fromJson(Map<String, Object?> json) {
    return IntakeStressProfile(
      feeds: _asInt(json['feeds']),
      recordsPerFeed: _asInt(json['recordsPerFeed']),
      bursts: _asInt(json['bursts']),
      highRiskPercent: _asInt(json['highRiskPercent']),
      siteSpread: _asInt(json['siteSpread']),
      maxAttemptedEvents: _asInt(json['maxAttemptedEvents']),
      seed: _asInt(json['seed']),
      chunkSize: _asInt(json['chunkSize']),
      duplicatePercent: _asInt(json['duplicatePercent']),
      interBurstDelayMs: _asInt(json['interBurstDelayMs']),
      verifyReplay: json['verifyReplay'] as bool? ?? false,
      stopOnRegression: json['stopOnRegression'] as bool? ?? false,
      regressionThroughputDrop: _asInt(json['regressionThroughputDrop']) <= 0
          ? 20
          : _asInt(json['regressionThroughputDrop']),
      regressionVerifyIncreaseMs:
          _asInt(json['regressionVerifyIncreaseMs']) <= 0
          ? 100
          : _asInt(json['regressionVerifyIncreaseMs']),
      maxRegressionPressureSeverity:
          _asInt(json['maxRegressionPressureSeverity']) <= 0
          ? 2
          : _asInt(json['maxRegressionPressureSeverity']),
      maxRegressionImbalanceSeverity:
          _asInt(json['maxRegressionImbalanceSeverity']) <= 0
          ? 2
          : _asInt(json['maxRegressionImbalanceSeverity']),
      soakRuns: _asInt(json['soakRuns']),
    );
  }

  IntakeStressProfile copyWith({
    int? feeds,
    int? recordsPerFeed,
    int? bursts,
    int? highRiskPercent,
    int? siteSpread,
    int? maxAttemptedEvents,
    int? seed,
    int? chunkSize,
    int? duplicatePercent,
    int? interBurstDelayMs,
    bool? verifyReplay,
    bool? stopOnRegression,
    int? regressionThroughputDrop,
    int? regressionVerifyIncreaseMs,
    int? maxRegressionPressureSeverity,
    int? maxRegressionImbalanceSeverity,
    int? soakRuns,
  }) {
    return IntakeStressProfile(
      feeds: feeds ?? this.feeds,
      recordsPerFeed: recordsPerFeed ?? this.recordsPerFeed,
      bursts: bursts ?? this.bursts,
      highRiskPercent: highRiskPercent ?? this.highRiskPercent,
      siteSpread: siteSpread ?? this.siteSpread,
      maxAttemptedEvents: maxAttemptedEvents ?? this.maxAttemptedEvents,
      seed: seed ?? this.seed,
      chunkSize: chunkSize ?? this.chunkSize,
      duplicatePercent: duplicatePercent ?? this.duplicatePercent,
      interBurstDelayMs: interBurstDelayMs ?? this.interBurstDelayMs,
      verifyReplay: verifyReplay ?? this.verifyReplay,
      stopOnRegression: stopOnRegression ?? this.stopOnRegression,
      regressionThroughputDrop:
          regressionThroughputDrop ?? this.regressionThroughputDrop,
      regressionVerifyIncreaseMs:
          regressionVerifyIncreaseMs ?? this.regressionVerifyIncreaseMs,
      maxRegressionPressureSeverity:
          maxRegressionPressureSeverity ?? this.maxRegressionPressureSeverity,
      maxRegressionImbalanceSeverity:
          maxRegressionImbalanceSeverity ?? this.maxRegressionImbalanceSeverity,
      soakRuns: soakRuns ?? this.soakRuns,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'feeds': feeds,
      'recordsPerFeed': recordsPerFeed,
      'bursts': bursts,
      'highRiskPercent': highRiskPercent,
      'siteSpread': siteSpread,
      'maxAttemptedEvents': maxAttemptedEvents,
      'seed': seed,
      'chunkSize': chunkSize,
      'duplicatePercent': duplicatePercent,
      'interBurstDelayMs': interBurstDelayMs,
      'verifyReplay': verifyReplay,
      'stopOnRegression': stopOnRegression,
      'regressionThroughputDrop': regressionThroughputDrop,
      'regressionVerifyIncreaseMs': regressionVerifyIncreaseMs,
      'maxRegressionPressureSeverity': maxRegressionPressureSeverity,
      'maxRegressionImbalanceSeverity': maxRegressionImbalanceSeverity,
      'soakRuns': soakRuns,
    };
  }
}

class IntakeTelemetry {
  final int runs;
  final int totalAppended;
  final int totalSkipped;
  final int totalDecisions;
  final double lastThroughput;
  final double averageThroughput;
  final double bestThroughput;
  final double worstThroughput;
  final double lastP50Throughput;
  final double lastP95Throughput;
  final int lastVerifyMs;
  final double averageVerifyMs;
  final double bestVerifyMs;
  final double worstVerifyMs;
  final double averageChunkMs;
  final int lastMaxChunkMs;
  final int totalSlowChunks;
  final int peakPending;
  final Map<String, int> siteDistribution;
  final Map<String, int> feedDistribution;
  final int totalDuplicatesInjected;
  final int lastSoakRuns;
  final double lastSoakDriftThroughput;
  final int lastSoakDriftVerifyMs;
  final int lastBurstSize;
  final List<IntakeRunSummary> recentRuns;

  const IntakeTelemetry({
    required this.runs,
    required this.totalAppended,
    required this.totalSkipped,
    required this.totalDecisions,
    required this.lastThroughput,
    required this.averageThroughput,
    required this.bestThroughput,
    required this.worstThroughput,
    required this.lastP50Throughput,
    required this.lastP95Throughput,
    required this.lastVerifyMs,
    required this.averageVerifyMs,
    required this.bestVerifyMs,
    required this.worstVerifyMs,
    required this.averageChunkMs,
    required this.lastMaxChunkMs,
    required this.totalSlowChunks,
    required this.peakPending,
    required this.siteDistribution,
    required this.feedDistribution,
    required this.totalDuplicatesInjected,
    required this.lastSoakRuns,
    required this.lastSoakDriftThroughput,
    required this.lastSoakDriftVerifyMs,
    required this.lastBurstSize,
    required this.recentRuns,
  });

  static const zero = IntakeTelemetry(
    runs: 0,
    totalAppended: 0,
    totalSkipped: 0,
    totalDecisions: 0,
    lastThroughput: 0,
    averageThroughput: 0,
    bestThroughput: 0,
    worstThroughput: 0,
    lastP50Throughput: 0,
    lastP95Throughput: 0,
    lastVerifyMs: 0,
    averageVerifyMs: 0,
    bestVerifyMs: 0,
    worstVerifyMs: 0,
    averageChunkMs: 0,
    lastMaxChunkMs: 0,
    totalSlowChunks: 0,
    peakPending: 0,
    siteDistribution: {},
    feedDistribution: {},
    totalDuplicatesInjected: 0,
    lastSoakRuns: 0,
    lastSoakDriftThroughput: 0,
    lastSoakDriftVerifyMs: 0,
    lastBurstSize: 0,
    recentRuns: [],
  );

  factory IntakeTelemetry.fromJson(Map<String, Object?> json) {
    final totals = _asMap(json['totals']);
    final throughput = _asMap(json['throughput']);
    final verify = _asMap(json['verify']);
    final chunk = _asMap(json['chunk']);
    final soak = _asMap(json['soak']);
    final recentRuns = _asList(json['recentRuns'])
        .map((item) => IntakeRunSummary.fromJson(_asMap(item)))
        .toList(growable: false);

    return IntakeTelemetry(
      runs: _asInt(json['runs']),
      totalAppended: _asInt(totals['appended']),
      totalSkipped: _asInt(totals['skipped']),
      totalDecisions: _asInt(totals['decisions']),
      lastThroughput: _asDouble(throughput['last']),
      averageThroughput: _asDouble(throughput['average']),
      bestThroughput: _asDouble(throughput['best']),
      worstThroughput: _asDouble(throughput['worst']),
      lastP50Throughput: _asDouble(throughput['lastP50']),
      lastP95Throughput: _asDouble(throughput['lastP95']),
      lastVerifyMs: _asInt(verify['lastMs']),
      averageVerifyMs: _asDouble(verify['averageMs']),
      bestVerifyMs: _asDouble(verify['bestMs']),
      worstVerifyMs: _asDouble(verify['worstMs']),
      averageChunkMs: _asDouble(chunk['averageMs']),
      lastMaxChunkMs: _asInt(chunk['lastMaxMs']),
      totalSlowChunks: _asInt(chunk['totalSlowChunks']),
      peakPending: _asInt(chunk['peakPending']),
      siteDistribution: _asIntMap(chunk['siteDistribution']),
      feedDistribution: _asIntMap(chunk['feedDistribution']),
      totalDuplicatesInjected: _asInt(chunk['duplicatesInjected']),
      lastSoakRuns: _asInt(soak['lastRuns']),
      lastSoakDriftThroughput: _asDouble(soak['lastThroughputDrift']),
      lastSoakDriftVerifyMs: _asInt(soak['lastVerifyDriftMs']),
      lastBurstSize: _asInt(json['lastBurstSize']),
      recentRuns: recentRuns,
    );
  }

  IntakeTelemetry add({
    required String label,
    required bool cancelled,
    String sourceLabel = '',
    String scenarioLabel = '',
    List<String> tags = const [],
    String note = '',
    required int attempted,
    required int appended,
    required int skipped,
    required int decisions,
    required double throughput,
    required double p50Throughput,
    required double p95Throughput,
    required int verifyMs,
    int chunkSize = 0,
    int chunks = 0,
    double avgChunkMs = 0,
    int maxChunkMs = 0,
    int slowChunks = 0,
    int duplicatesInjected = 0,
    int uniqueFeeds = 0,
    int peakPending = 0,
    Map<String, int> siteDistribution = const {},
    Map<String, int> feedDistribution = const {},
    required int burstSize,
  }) {
    final nextRuns = runs + 1;
    final nextAverage = nextRuns == 1
        ? throughput
        : ((averageThroughput * runs) + throughput) / nextRuns;
    final nextAverageVerify = nextRuns == 1
        ? verifyMs.toDouble()
        : ((averageVerifyMs * runs) + verifyMs) / nextRuns;
    final nextBest = nextRuns == 1
        ? throughput
        : (throughput > bestThroughput ? throughput : bestThroughput);
    final nextWorst = nextRuns == 1
        ? throughput
        : (throughput < worstThroughput ? throughput : worstThroughput);
    final nextBestVerify = nextRuns == 1
        ? verifyMs.toDouble()
        : (verifyMs < bestVerifyMs ? verifyMs.toDouble() : bestVerifyMs);
    final nextWorstVerify = nextRuns == 1
        ? verifyMs.toDouble()
        : (verifyMs > worstVerifyMs ? verifyMs.toDouble() : worstVerifyMs);
    final nextAverageChunk = nextRuns == 1
        ? avgChunkMs
        : ((averageChunkMs * runs) + avgChunkMs) / nextRuns;
    final nextPeakPending = peakPending > this.peakPending
        ? peakPending
        : this.peakPending;
    final run = IntakeRunSummary(
      label: label,
      cancelled: cancelled,
      sourceLabel: sourceLabel.trim(),
      scenarioLabel: scenarioLabel.trim(),
      tags: tags
          .where((item) => item.trim().isNotEmpty)
          .map((item) => item.trim())
          .toList(growable: false),
      note: note.trim(),
      ranAtUtc: DateTime.now().toUtc(),
      attempted: attempted,
      appended: appended,
      skipped: skipped,
      decisions: decisions,
      throughput: throughput,
      p50: p50Throughput,
      p95: p95Throughput,
      verifyMs: verifyMs,
      chunkSize: chunkSize,
      chunks: chunks,
      avgChunkMs: avgChunkMs,
      maxChunkMs: maxChunkMs,
      slowChunks: slowChunks,
      duplicatesInjected: duplicatesInjected,
      uniqueFeeds: uniqueFeeds,
      peakPending: peakPending,
      siteDistribution: siteDistribution,
      feedDistribution: feedDistribution,
    );
    final history = [run, ...recentRuns].take(6).toList(growable: false);

    return IntakeTelemetry(
      runs: nextRuns,
      totalAppended: totalAppended + appended,
      totalSkipped: totalSkipped + skipped,
      totalDecisions: totalDecisions + decisions,
      lastThroughput: throughput,
      averageThroughput: nextAverage,
      bestThroughput: nextBest,
      worstThroughput: nextWorst,
      lastP50Throughput: p50Throughput,
      lastP95Throughput: p95Throughput,
      lastVerifyMs: verifyMs,
      averageVerifyMs: nextAverageVerify,
      bestVerifyMs: nextBestVerify,
      worstVerifyMs: nextWorstVerify,
      averageChunkMs: nextAverageChunk,
      lastMaxChunkMs: maxChunkMs,
      totalSlowChunks: totalSlowChunks + slowChunks,
      peakPending: nextPeakPending,
      siteDistribution: siteDistribution,
      feedDistribution: feedDistribution,
      totalDuplicatesInjected: totalDuplicatesInjected + duplicatesInjected,
      lastSoakRuns: lastSoakRuns,
      lastSoakDriftThroughput: lastSoakDriftThroughput,
      lastSoakDriftVerifyMs: lastSoakDriftVerifyMs,
      lastBurstSize: burstSize,
      recentRuns: history,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'runs': runs,
      'totals': {
        'appended': totalAppended,
        'skipped': totalSkipped,
        'decisions': totalDecisions,
      },
      'throughput': {
        'last': lastThroughput,
        'average': averageThroughput,
        'best': bestThroughput,
        'worst': worstThroughput,
        'lastP50': lastP50Throughput,
        'lastP95': lastP95Throughput,
      },
      'verify': {
        'lastMs': lastVerifyMs,
        'averageMs': averageVerifyMs,
        'bestMs': bestVerifyMs,
        'worstMs': worstVerifyMs,
      },
      'chunk': {
        'averageMs': averageChunkMs,
        'lastMaxMs': lastMaxChunkMs,
        'totalSlowChunks': totalSlowChunks,
        'peakPending': peakPending,
        'duplicatesInjected': totalDuplicatesInjected,
        'siteDistribution': siteDistribution,
        'feedDistribution': feedDistribution,
      },
      'lastBurstSize': lastBurstSize,
      'soak': {
        'lastRuns': lastSoakRuns,
        'lastThroughputDrift': lastSoakDriftThroughput,
        'lastVerifyDriftMs': lastSoakDriftVerifyMs,
      },
      'recentRuns': recentRuns
          .map((run) => run.toJson())
          .toList(growable: false),
    };
  }

  IntakeTelemetry withSoakSummary({
    required int runs,
    required double throughputDrift,
    required int verifyDriftMs,
  }) {
    return IntakeTelemetry(
      runs: this.runs,
      totalAppended: totalAppended,
      totalSkipped: totalSkipped,
      totalDecisions: totalDecisions,
      lastThroughput: lastThroughput,
      averageThroughput: averageThroughput,
      bestThroughput: bestThroughput,
      worstThroughput: worstThroughput,
      lastP50Throughput: lastP50Throughput,
      lastP95Throughput: lastP95Throughput,
      lastVerifyMs: lastVerifyMs,
      averageVerifyMs: averageVerifyMs,
      bestVerifyMs: bestVerifyMs,
      worstVerifyMs: worstVerifyMs,
      averageChunkMs: averageChunkMs,
      lastMaxChunkMs: lastMaxChunkMs,
      totalSlowChunks: totalSlowChunks,
      peakPending: peakPending,
      siteDistribution: siteDistribution,
      feedDistribution: feedDistribution,
      totalDuplicatesInjected: totalDuplicatesInjected,
      lastSoakRuns: runs,
      lastSoakDriftThroughput: throughputDrift,
      lastSoakDriftVerifyMs: verifyDriftMs,
      lastBurstSize: lastBurstSize,
      recentRuns: recentRuns,
    );
  }

  IntakeTelemetry updateRunNote({required String label, required String note}) {
    return updateRunMetadata(label: label, note: note);
  }

  IntakeTelemetry updateRunMetadata({
    required String label,
    String? scenarioLabel,
    List<String>? tags,
    String? note,
  }) {
    return IntakeTelemetry(
      runs: runs,
      totalAppended: totalAppended,
      totalSkipped: totalSkipped,
      totalDecisions: totalDecisions,
      lastThroughput: lastThroughput,
      averageThroughput: averageThroughput,
      bestThroughput: bestThroughput,
      worstThroughput: worstThroughput,
      lastP50Throughput: lastP50Throughput,
      lastP95Throughput: lastP95Throughput,
      lastVerifyMs: lastVerifyMs,
      averageVerifyMs: averageVerifyMs,
      bestVerifyMs: bestVerifyMs,
      worstVerifyMs: worstVerifyMs,
      averageChunkMs: averageChunkMs,
      lastMaxChunkMs: lastMaxChunkMs,
      totalSlowChunks: totalSlowChunks,
      peakPending: peakPending,
      siteDistribution: siteDistribution,
      feedDistribution: feedDistribution,
      totalDuplicatesInjected: totalDuplicatesInjected,
      lastSoakRuns: lastSoakRuns,
      lastSoakDriftThroughput: lastSoakDriftThroughput,
      lastSoakDriftVerifyMs: lastSoakDriftVerifyMs,
      lastBurstSize: lastBurstSize,
      recentRuns: recentRuns
          .map(
            (run) => run.label == label
                ? run.copyWith(
                    sourceLabel: run.sourceLabel,
                    scenarioLabel: scenarioLabel?.trim(),
                    tags: tags
                        ?.map((tag) => tag.trim())
                        .where((tag) => tag.isNotEmpty)
                        .toList(growable: false),
                    note: note?.trim(),
                  )
                : run,
          )
          .toList(growable: false),
    );
  }
}

class IntakeRunSummary {
  final String label;
  final bool cancelled;
  final String sourceLabel;
  final String scenarioLabel;
  final List<String> tags;
  final String note;
  final DateTime ranAtUtc;
  final int attempted;
  final int appended;
  final int skipped;
  final int decisions;
  final double throughput;
  final double p50;
  final double p95;
  final int verifyMs;
  final int chunkSize;
  final int chunks;
  final double avgChunkMs;
  final int maxChunkMs;
  final int slowChunks;
  final int duplicatesInjected;
  final int uniqueFeeds;
  final int peakPending;
  final Map<String, int> siteDistribution;
  final Map<String, int> feedDistribution;

  const IntakeRunSummary({
    required this.label,
    required this.cancelled,
    this.sourceLabel = '',
    this.scenarioLabel = '',
    this.tags = const [],
    this.note = '',
    required this.ranAtUtc,
    required this.attempted,
    required this.appended,
    required this.skipped,
    required this.decisions,
    required this.throughput,
    required this.p50,
    required this.p95,
    required this.verifyMs,
    required this.chunkSize,
    required this.chunks,
    required this.avgChunkMs,
    required this.maxChunkMs,
    required this.slowChunks,
    required this.duplicatesInjected,
    required this.uniqueFeeds,
    required this.peakPending,
    required this.siteDistribution,
    required this.feedDistribution,
  });

  factory IntakeRunSummary.fromJson(Map<String, Object?> json) {
    return IntakeRunSummary(
      label: (json['label'] as String?) ?? 'RESTORED',
      cancelled: json['cancelled'] as bool? ?? false,
      sourceLabel: _asString(json['sourceLabel']).trim(),
      scenarioLabel: _asString(json['scenarioLabel']).trim(),
      tags: _asList(json['tags'])
          .map((item) => _asString(item).trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      note: _asString(json['note']).trim(),
      ranAtUtc:
          DateTime.tryParse((json['ranAtUtc'] as String?) ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      attempted: _asInt(json['attempted']),
      appended: _asInt(json['appended']),
      skipped: _asInt(json['skipped']),
      decisions: _asInt(json['decisions']),
      throughput: _asDouble(json['throughput']),
      p50: _asDouble(json['p50']),
      p95: _asDouble(json['p95']),
      verifyMs: _asInt(json['verifyMs']),
      chunkSize: _asInt(json['chunkSize']),
      chunks: _asInt(json['chunks']),
      avgChunkMs: _asDouble(json['avgChunkMs']),
      maxChunkMs: _asInt(json['maxChunkMs']),
      slowChunks: _asInt(json['slowChunks']),
      duplicatesInjected: _asInt(json['duplicatesInjected']),
      uniqueFeeds: _asInt(json['uniqueFeeds']),
      peakPending: _asInt(json['peakPending']),
      siteDistribution: _asIntMap(json['siteDistribution']),
      feedDistribution: _asIntMap(json['feedDistribution']),
    );
  }

  IntakeRunSummary copyWith({
    String? sourceLabel,
    String? scenarioLabel,
    List<String>? tags,
    String? note,
  }) {
    return IntakeRunSummary(
      label: label,
      cancelled: cancelled,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      scenarioLabel: scenarioLabel ?? this.scenarioLabel,
      tags: tags ?? this.tags,
      note: note ?? this.note,
      ranAtUtc: ranAtUtc,
      attempted: attempted,
      appended: appended,
      skipped: skipped,
      decisions: decisions,
      throughput: throughput,
      p50: p50,
      p95: p95,
      verifyMs: verifyMs,
      chunkSize: chunkSize,
      chunks: chunks,
      avgChunkMs: avgChunkMs,
      maxChunkMs: maxChunkMs,
      slowChunks: slowChunks,
      duplicatesInjected: duplicatesInjected,
      uniqueFeeds: uniqueFeeds,
      peakPending: peakPending,
      siteDistribution: siteDistribution,
      feedDistribution: feedDistribution,
    );
  }

  MapEntry<String, int>? get hottestSite => _topEntry(siteDistribution);
  MapEntry<String, int>? get hottestFeed => _topEntry(feedDistribution);
  int get pressureSeverity {
    final backlogRatio = chunkSize <= 0 ? 0.0 : peakPending / chunkSize;
    if (slowChunks >= 3 || maxChunkMs >= 150 || backlogRatio >= 3.0) {
      return 2;
    }
    if (slowChunks >= 1 || maxChunkMs >= 75 || backlogRatio >= 1.5) {
      return 1;
    }
    return 0;
  }

  double get imbalanceScore {
    final siteScore = _distributionImbalance(siteDistribution);
    final feedScore = _distributionImbalance(feedDistribution);
    return siteScore > feedScore ? siteScore : feedScore;
  }

  int get imbalanceSeverity {
    if (imbalanceScore >= 0.65) {
      return 2;
    }
    if (imbalanceScore >= 0.45) {
      return 1;
    }
    return 0;
  }

  MapEntry<String, int>? _topEntry(Map<String, int> values) {
    MapEntry<String, int>? top;
    for (final entry in values.entries) {
      if (top == null || entry.value > top.value) {
        top = entry;
      }
    }
    return top;
  }

  double _distributionImbalance(Map<String, int> values) {
    if (values.isEmpty) return 0.0;
    final total = values.values.fold<int>(0, (sum, value) => sum + value);
    if (total <= 0) return 0.0;
    final top = _topEntry(values);
    return top == null ? 0.0 : top.value / total;
  }

  Map<String, Object?> toJson() {
    return {
      'label': label,
      'cancelled': cancelled,
      'sourceLabel': sourceLabel,
      'scenarioLabel': scenarioLabel,
      'tags': tags,
      'note': note,
      'ranAtUtc': ranAtUtc.toIso8601String(),
      'attempted': attempted,
      'appended': appended,
      'skipped': skipped,
      'decisions': decisions,
      'throughput': throughput,
      'p50': p50,
      'p95': p95,
      'verifyMs': verifyMs,
      'chunkSize': chunkSize,
      'chunks': chunks,
      'avgChunkMs': avgChunkMs,
      'maxChunkMs': maxChunkMs,
      'slowChunks': slowChunks,
      'duplicatesInjected': duplicatesInjected,
      'uniqueFeeds': uniqueFeeds,
      'peakPending': peakPending,
      'siteDistribution': siteDistribution,
      'feedDistribution': feedDistribution,
    };
  }
}

bool shouldStopSoakOnRegression({
  required IntakeRunSummary baseline,
  required IntakeRunSummary latest,
  double minThroughputDelta = -20,
  int maxVerifyDeltaMs = 100,
  int maxPressureSeverity = 2,
  int maxImbalanceSeverity = 2,
}) {
  final throughputDrop = latest.throughput - baseline.throughput;
  final verifyIncrease = latest.verifyMs - baseline.verifyMs;
  return throughputDrop <= minThroughputDelta ||
      verifyIncrease >= maxVerifyDeltaMs ||
      latest.pressureSeverity >= maxPressureSeverity ||
      latest.imbalanceSeverity >= maxImbalanceSeverity;
}

class DispatchProfileDraft {
  final IntakeStressProfile profile;
  final String scenarioLabel;
  final List<String> tags;
  final String runNote;
  final List<DispatchBenchmarkFilterPreset> filterPresets;
  final String intelligenceSourceFilter;
  final String intelligenceActionFilter;
  final List<String> pinnedWatchIntelligenceIds;
  final List<String> dismissedIntelligenceIds;
  final bool showPinnedWatchIntelligenceOnly;
  final bool showDismissedIntelligenceOnly;
  final String selectedIntelligenceId;

  const DispatchProfileDraft({
    required this.profile,
    this.scenarioLabel = '',
    this.tags = const [],
    this.runNote = '',
    this.filterPresets = const [],
    this.intelligenceSourceFilter = 'all',
    this.intelligenceActionFilter = 'all',
    this.pinnedWatchIntelligenceIds = const [],
    this.dismissedIntelligenceIds = const [],
    this.showPinnedWatchIntelligenceOnly = false,
    this.showDismissedIntelligenceOnly = false,
    this.selectedIntelligenceId = '',
  });

  factory DispatchProfileDraft.fromJson(Map<String, Object?> json) {
    return DispatchProfileDraft(
      profile: IntakeStressProfile.fromJson(_asMap(json['profile'])),
      scenarioLabel: _asString(json['scenarioLabel']).trim(),
      tags: _asList(json['tags'])
          .map((item) => _asString(item).trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      runNote: _asString(json['runNote']).trim(),
      filterPresets: _asList(json['filterPresets'])
          .map((item) => DispatchBenchmarkFilterPreset.fromJson(_asMap(item)))
          .toList(growable: false),
      intelligenceSourceFilter:
          _asString(json['intelligenceSourceFilter']).trim().isEmpty
          ? 'all'
          : _asString(json['intelligenceSourceFilter']).trim(),
      intelligenceActionFilter:
          _asString(json['intelligenceActionFilter']).trim().isEmpty
          ? 'all'
          : _asString(json['intelligenceActionFilter']).trim(),
      pinnedWatchIntelligenceIds: _asList(json['pinnedWatchIntelligenceIds'])
          .map((item) => _asString(item).trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      dismissedIntelligenceIds: _asList(json['dismissedIntelligenceIds'])
          .map((item) => _asString(item).trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      showPinnedWatchIntelligenceOnly:
          json['showPinnedWatchIntelligenceOnly'] == true,
      showDismissedIntelligenceOnly:
          json['showDismissedIntelligenceOnly'] == true,
      selectedIntelligenceId: _asString(json['selectedIntelligenceId']).trim(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'profile': profile.toJson(),
      'scenarioLabel': scenarioLabel,
      'tags': tags,
      'runNote': runNote,
      'filterPresets': filterPresets.map((preset) => preset.toJson()).toList(),
      'intelligenceSourceFilter': intelligenceSourceFilter,
      'intelligenceActionFilter': intelligenceActionFilter,
      'pinnedWatchIntelligenceIds': pinnedWatchIntelligenceIds,
      'dismissedIntelligenceIds': dismissedIntelligenceIds,
      'showPinnedWatchIntelligenceOnly': showPinnedWatchIntelligenceOnly,
      'showDismissedIntelligenceOnly': showDismissedIntelligenceOnly,
      'selectedIntelligenceId': selectedIntelligenceId,
    };
  }
}

class DispatchBenchmarkFilterPreset {
  final String name;
  final int revision;
  final String updatedAtUtc;
  final bool showCancelledRuns;
  final List<String> statusFilters;
  final String scenarioFilter;
  final String tagFilter;
  final String noteFilter;
  final String sort;
  final int historyLimit;

  const DispatchBenchmarkFilterPreset({
    required this.name,
    this.revision = 1,
    this.updatedAtUtc = '',
    this.showCancelledRuns = true,
    this.statusFilters = const ['BASELINE', 'IMPROVED', 'STABLE', 'DEGRADED'],
    this.scenarioFilter = '',
    this.tagFilter = '',
    this.noteFilter = '',
    this.sort = 'latest',
    this.historyLimit = 6,
  });

  factory DispatchBenchmarkFilterPreset.fromJson(Map<String, Object?> json) {
    return DispatchBenchmarkFilterPreset(
      name: _asString(json['name']).trim(),
      revision: _asInt(json['revision']) <= 0 ? 1 : _asInt(json['revision']),
      updatedAtUtc: _asString(json['updatedAtUtc']).trim(),
      showCancelledRuns: json['showCancelledRuns'] as bool? ?? true,
      statusFilters: _asList(json['statusFilters'])
          .map((item) => _asString(item).trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      scenarioFilter: _asString(json['scenarioFilter']).trim(),
      tagFilter: _asString(json['tagFilter']).trim(),
      noteFilter: _asString(json['noteFilter']).trim(),
      sort: _asString(json['sort']).trim().isEmpty
          ? 'latest'
          : _asString(json['sort']).trim(),
      historyLimit: _asInt(json['historyLimit']) <= 0
          ? 6
          : _asInt(json['historyLimit']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'revision': revision,
      'updatedAtUtc': updatedAtUtc,
      'showCancelledRuns': showCancelledRuns,
      'statusFilters': statusFilters,
      'scenarioFilter': scenarioFilter,
      'tagFilter': tagFilter,
      'noteFilter': noteFilter,
      'sort': sort,
      'historyLimit': historyLimit,
    };
  }
}

class DispatchSnapshot {
  final int version;
  final String scenarioLabel;
  final List<String> tags;
  final String runNote;
  final List<DispatchBenchmarkFilterPreset> filterPresets;
  final IntakeStressProfile profile;
  final IntakeTelemetry telemetry;

  const DispatchSnapshot({
    this.version = 2,
    this.scenarioLabel = '',
    this.tags = const [],
    this.runNote = '',
    this.filterPresets = const [],
    required this.profile,
    required this.telemetry,
  });

  factory DispatchSnapshot.fromJson(Map<String, Object?> json) {
    return DispatchSnapshot(
      version: _asInt(json['version']) <= 0 ? 2 : _asInt(json['version']),
      scenarioLabel: _asString(json['scenarioLabel']).trim(),
      tags: _asList(json['tags'])
          .map((item) => _asString(item).trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      runNote: _asString(json['runNote']).trim(),
      filterPresets: _asList(json['filterPresets'])
          .map((item) => DispatchBenchmarkFilterPreset.fromJson(_asMap(item)))
          .toList(growable: false),
      profile: IntakeStressProfile.fromJson(_asMap(json['profile'])),
      telemetry: IntakeTelemetry.fromJson(_asMap(json['telemetry'])),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'version': version,
      'scenarioLabel': scenarioLabel,
      'tags': tags,
      'runNote': runNote,
      'filterPresets': filterPresets.map((preset) => preset.toJson()).toList(),
      'profile': profile.toJson(),
      'telemetry': telemetry.toJson(),
    };
  }
}

Map<String, Object?> _asMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map(
      (key, entry) => MapEntry(key.toString(), entry as Object?),
    );
  }
  return const {};
}

List<Object?> _asList(Object? value) {
  if (value is List<Object?>) return value;
  if (value is List) return List<Object?>.from(value);
  return const [];
}

Map<String, int> _asIntMap(Object? value) {
  final map = _asMap(value);
  return {for (final entry in map.entries) entry.key: _asInt(entry.value)};
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _asDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

String _asString(Object? value) {
  if (value is String) return value;
  if (value == null) return '';
  return value.toString();
}
