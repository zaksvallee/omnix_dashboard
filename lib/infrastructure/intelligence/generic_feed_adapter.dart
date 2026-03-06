import '../../domain/intelligence/intel_ingestion.dart';

class GenericFeedAdapter implements IntelligenceProviderAdapter {
  @override
  final String providerName;
  final String sourceType;

  const GenericFeedAdapter({
    required this.providerName,
    this.sourceType = 'hardware',
  });

  @override
  List<NormalizedIntelRecord> normalizeBatch(
    List<Map<String, Object?>> payloads,
  ) {
    return payloads
        .map(_normalizeOne)
        .whereType<NormalizedIntelRecord>()
        .toList(growable: false);
  }

  NormalizedIntelRecord? _normalizeOne(Map<String, Object?> payload) {
    final externalId = payload['external_id'] as String?;
    final clientId = payload['client_id'] as String?;
    final regionId = payload['region_id'] as String?;
    final siteId = payload['site_id'] as String?;
    final headline = payload['headline'] as String?;
    final summary = payload['summary'] as String?;
    final riskScore = payload['risk_score'] as int?;
    final occurredAtRaw = payload['occurred_at_utc'] as String?;

    if (externalId == null ||
        clientId == null ||
        regionId == null ||
        siteId == null ||
        headline == null ||
        summary == null ||
        riskScore == null ||
        occurredAtRaw == null) {
      return null;
    }

    final occurredAtUtc = DateTime.tryParse(occurredAtRaw)?.toUtc();
    if (occurredAtUtc == null) {
      return null;
    }

    return NormalizedIntelRecord(
      provider: providerName,
      sourceType: sourceType,
      externalId: externalId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      headline: headline,
      summary: summary,
      riskScore: riskScore,
      occurredAtUtc: occurredAtUtc,
    );
  }
}
