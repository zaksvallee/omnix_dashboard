import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../events/intelligence_received.dart';
import '../store/event_store.dart';

class NormalizedIntelRecord {
  final String provider;
  final String sourceType;
  final String externalId;
  final String clientId;
  final String regionId;
  final String siteId;
  final String headline;
  final String summary;
  final int riskScore;
  final DateTime occurredAtUtc;

  const NormalizedIntelRecord({
    required this.provider,
    required this.sourceType,
    required this.externalId,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.headline,
    required this.summary,
    required this.riskScore,
    required this.occurredAtUtc,
  });
}

abstract class IntelligenceProviderAdapter {
  String get providerName;

  List<NormalizedIntelRecord> normalizeBatch(
    List<Map<String, Object?>> payloads,
  );
}

class DeterministicIntelligenceIngestionService {
  final EventStore store;

  const DeterministicIntelligenceIngestionService({required this.store});

  IntelligenceBatchIngestResult ingestBatch(
    List<NormalizedIntelRecord> records, {
    Set<String>? existingIntelIds,
  }) {
    final knownIntelIds =
        existingIntelIds ??
        store
            .allEvents()
            .whereType<IntelligenceReceived>()
            .map((e) => e.intelligenceId)
            .toSet();

    final sorted = [...records]
      ..sort((a, b) {
        final ts = a.occurredAtUtc.compareTo(b.occurredAtUtc);
        if (ts != 0) return ts;
        final provider = a.provider.compareTo(b.provider);
        if (provider != 0) return provider;
        return a.externalId.compareTo(b.externalId);
      });

    var appended = 0;
    var skipped = 0;
    for (final record in sorted) {
      final canonicalPayload = _canonicalPayload(record);
      final canonicalHash = sha256
          .convert(
            Uint8List.fromList(utf8.encode(jsonEncode(canonicalPayload))),
          )
          .toString();
      final intelligenceId = 'INT-${canonicalHash.substring(0, 20)}';

      if (knownIntelIds.contains(intelligenceId)) {
        skipped++;
        continue;
      }

      store.append(
        IntelligenceReceived(
          eventId: 'E-$intelligenceId',
          sequence: 0,
          version: 1,
          occurredAt: record.occurredAtUtc.toUtc(),
          intelligenceId: intelligenceId,
          provider: record.provider,
          sourceType: record.sourceType,
          externalId: record.externalId,
          clientId: record.clientId,
          regionId: record.regionId,
          siteId: record.siteId,
          headline: record.headline,
          summary: record.summary,
          riskScore: record.riskScore,
          canonicalHash: canonicalHash,
        ),
      );
      knownIntelIds.add(intelligenceId);
      appended++;
    }

    return IntelligenceBatchIngestResult(
      attempted: sorted.length,
      appended: appended,
      skipped: skipped,
    );
  }

  Map<String, Object?> _canonicalPayload(NormalizedIntelRecord record) {
    return <String, Object?>{
      'provider': record.provider,
      'sourceType': record.sourceType,
      'externalId': record.externalId,
      'clientId': record.clientId,
      'regionId': record.regionId,
      'siteId': record.siteId,
      'headline': record.headline,
      'summary': record.summary,
      'riskScore': record.riskScore,
      'occurredAtUtc': record.occurredAtUtc.toUtc().toIso8601String(),
    };
  }
}

class IntelligenceBatchIngestResult {
  final int attempted;
  final int appended;
  final int skipped;

  const IntelligenceBatchIngestResult({
    required this.attempted,
    required this.appended,
    required this.skipped,
  });
}
