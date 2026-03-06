import '../domain/events/decision_created.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/intelligence/intel_ingestion.dart';
import '../domain/store/event_store.dart';
import '../infrastructure/intelligence/generic_feed_adapter.dart';
import '../ui/dispatch_models.dart';
import 'dispatch_application_service.dart';

class IntakeStressRunResult {
  final int effectiveBursts;
  final int attemptedTotal;
  final int appendedTotal;
  final int skippedTotal;
  final int decisionsTotal;
  final bool cancelled;
  final double throughput;
  final double p50;
  final double p95;
  final int verifyMs;
  final int totalMs;
  final double avgChunkMs;
  final int maxChunkMs;
  final int slowChunks;
  final int duplicatesInjected;
  final int peakPending;
  final Map<String, int> siteDistribution;
  final Map<String, int> feedDistribution;

  const IntakeStressRunResult({
    required this.effectiveBursts,
    required this.attemptedTotal,
    required this.appendedTotal,
    required this.skippedTotal,
    required this.decisionsTotal,
    required this.cancelled,
    required this.throughput,
    required this.p50,
    required this.p95,
    required this.verifyMs,
    required this.totalMs,
    required this.avgChunkMs,
    required this.maxChunkMs,
    required this.slowChunks,
    required this.duplicatesInjected,
    required this.peakPending,
    required this.siteDistribution,
    required this.feedDistribution,
  });
}

class IntakeStressService {
  final EventStore store;
  final DispatchApplicationService service;

  const IntakeStressService({required this.store, required this.service});

  Future<IntakeStressRunResult> run({
    required IntakeStressProfile profile,
    required String runId,
    required String clientId,
    required String regionId,
    required String primarySiteId,
    required bool Function() shouldCancel,
    required Future<void> Function({
      required int burstIndex,
      required int effectiveBursts,
      required int appendedTotal,
      required int skippedTotal,
      required int decisionsTotal,
      required int peakPending,
      required int slowChunks,
    })
    onBurstProgress,
  }) async {
    final maxAttemptedEvents = profile.maxAttemptedEvents;
    final eventsPerBurst = profile.feeds * profile.recordsPerFeed;
    final maxBursts = eventsPerBurst <= 0
        ? 1
        : (maxAttemptedEvents ~/ eventsPerBurst);
    final effectiveBursts = maxBursts < 1
        ? 1
        : (profile.bursts > maxBursts ? maxBursts : profile.bursts);

    final started = DateTime.now().toUtc();
    final sites = [
      primarySiteId,
      'SITE-ROSEBANK',
      'SITE-MIDRAND',
    ].take(profile.siteSpread).toList(growable: false);
    final knownIntelIds = store
        .allEvents()
        .whereType<IntelligenceReceived>()
        .map((event) => event.intelligenceId)
        .toSet();
    final knownDispatchIds = store
        .allEvents()
        .whereType<DecisionCreated>()
        .map((event) => event.dispatchId)
        .toSet();

    var attemptedTotal = 0;
    var appendedTotal = 0;
    var skippedTotal = 0;
    var decisionsTotal = 0;
    var cancelled = false;
    final chunkThroughputs = <double>[];
    final chunkDurationsMs = <int>[];
    var slowChunks = 0;
    var duplicatesInjected = 0;
    var peakPending = 0;
    final siteDistribution = <String, int>{};
    final feedDistribution = <String, int>{};
    final stopwatch = Stopwatch()..start();

    for (int burst = 0; burst < effectiveBursts; burst++) {
      if (shouldCancel()) {
        cancelled = true;
        break;
      }
      final normalizedBurst = <NormalizedIntelRecord>[];

      for (int feed = 0; feed < profile.feeds; feed++) {
        final feedName = 'feed-${(feed + 1).toString().padLeft(2, '0')}';
        final provider = GenericFeedAdapter(providerName: feedName);
        final batch = <Map<String, Object?>>[];

        for (int i = 0; i < profile.recordsPerFeed; i++) {
          final riskSeed =
              ((i * 31) + (feed * 17) + (burst * 13) + (profile.seed * 19)) %
              100;
          final isHighRisk = riskSeed < profile.highRiskPercent;
          final riskScore = isHighRisk
              ? 75 + (riskSeed % 25)
              : 20 + (riskSeed % 45);
          final eventTime = started.subtract(
            Duration(
              seconds: (profile.recordsPerFeed - i) + (burst * 7) + feed,
            ),
          );

          final siteId = sites[i % sites.length];
          batch.add({
            'external_id': 'SEED${profile.seed}-$runId-B$burst-F$feed-I$i',
            'client_id': clientId,
            'region_id': regionId,
            'site_id': siteId,
            'headline': isHighRisk
                ? 'High-risk intake signal burst=$burst feed=$feed'
                : 'Routine intake signal burst=$burst feed=$feed',
            'summary':
                'Synthetic load test payload index=$i riskSeed=$riskSeed',
            'risk_score': riskScore,
            'occurred_at_utc': eventTime.toIso8601String(),
          });
          siteDistribution.update(
            siteId,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
          feedDistribution.update(
            feedName,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }

        final duplicateCount =
            (profile.recordsPerFeed * profile.duplicatePercent) ~/ 100;
        for (int dup = 0; dup < duplicateCount && dup < batch.length; dup++) {
          batch.add({...batch[dup]});
          duplicatesInjected += 1;
        }

        normalizedBurst.addAll(provider.normalizeBatch(batch));
      }

      final maxChunkSize = profile.chunkSize;
      var pendingInBurst = normalizedBurst.length;
      if (pendingInBurst > peakPending) {
        peakPending = pendingInBurst;
      }

      for (
        int start = 0;
        start < normalizedBurst.length;
        start += maxChunkSize
      ) {
        if (shouldCancel()) {
          cancelled = true;
          break;
        }
        final end = (start + maxChunkSize) > normalizedBurst.length
            ? normalizedBurst.length
            : (start + maxChunkSize);
        final chunk = normalizedBurst.sublist(start, end);
        final chunkStopwatch = Stopwatch()..start();

        final outcome = service.ingestNormalizedIntelligence(
          records: chunk,
          autoGenerateDispatches: true,
          verifyReplay: false,
          existingDispatchIdsCache: knownDispatchIds,
          existingIntelIdsCache: knownIntelIds,
        );
        chunkStopwatch.stop();
        final chunkElapsedMs = chunkStopwatch.elapsedMilliseconds;
        chunkDurationsMs.add(chunkElapsedMs);
        if (chunkElapsedMs >= 75) {
          slowChunks += 1;
        }
        final chunkElapsedSeconds = chunkElapsedMs / 1000.0;
        if (chunkElapsedSeconds > 0) {
          chunkThroughputs.add(
            outcome.appendedIntelligence / chunkElapsedSeconds,
          );
        }
        attemptedTotal += outcome.attemptedIntelligence;
        appendedTotal += outcome.appendedIntelligence;
        skippedTotal += outcome.skippedIntelligence;
        decisionsTotal += outcome.createdDecisions;
        pendingInBurst -= chunk.length;
        if (pendingInBurst > peakPending) {
          peakPending = pendingInBurst;
        }
      }

      if (cancelled) {
        break;
      }

      await onBurstProgress(
        burstIndex: burst,
        effectiveBursts: effectiveBursts,
        appendedTotal: appendedTotal,
        skippedTotal: skippedTotal,
        decisionsTotal: decisionsTotal,
        peakPending: peakPending,
        slowChunks: slowChunks,
      );

      if (profile.interBurstDelayMs > 0) {
        await Future<void>.delayed(
          Duration(milliseconds: profile.interBurstDelayMs),
        );
      }
      await Future<void>.delayed(Duration.zero);
    }

    final verifyStopwatch = Stopwatch()..start();
    if (profile.verifyReplay) {
      service.verifyReplayConsistency();
    }
    verifyStopwatch.stop();
    stopwatch.stop();

    final elapsedSeconds = stopwatch.elapsedMilliseconds / 1000.0;
    final throughput = elapsedSeconds <= 0
        ? appendedTotal.toDouble()
        : appendedTotal / elapsedSeconds;
    final p50 = _percentile(chunkThroughputs, 0.50);
    final p95 = _percentile(chunkThroughputs, 0.95);
    final avgChunkMs = chunkDurationsMs.isEmpty
        ? 0.0
        : chunkDurationsMs.reduce((a, b) => a + b) / chunkDurationsMs.length;
    final maxChunkMs = chunkDurationsMs.isEmpty
        ? 0
        : chunkDurationsMs.reduce((a, b) => a > b ? a : b);

    return IntakeStressRunResult(
      effectiveBursts: effectiveBursts,
      attemptedTotal: attemptedTotal,
      appendedTotal: appendedTotal,
      skippedTotal: skippedTotal,
      decisionsTotal: decisionsTotal,
      cancelled: cancelled,
      throughput: throughput,
      p50: p50,
      p95: p95,
      verifyMs: profile.verifyReplay ? verifyStopwatch.elapsedMilliseconds : 0,
      totalMs: stopwatch.elapsedMilliseconds,
      avgChunkMs: avgChunkMs,
      maxChunkMs: maxChunkMs,
      slowChunks: slowChunks,
      duplicatesInjected: duplicatesInjected,
      peakPending: peakPending,
      siteDistribution: siteDistribution,
      feedDistribution: feedDistribution,
    );
  }

  double _percentile(List<double> values, double p) {
    if (values.isEmpty) return 0.0;
    final sorted = [...values]..sort();
    final idx = (p * (sorted.length - 1)).round();
    return sorted[idx];
  }
}
