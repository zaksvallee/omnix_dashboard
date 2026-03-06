import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/infrastructure/intelligence/configured_live_feed_service.dart';

void main() {
  test('returns null when no configured live feed is present', () {
    const service = ConfiguredLiveFeedService();

    final batch = service.loadFromEnvironment();

    expect(batch, isNull);
  });

  test('parses a multi-feed payload bundle', () {
    const service = ConfiguredLiveFeedService();

    final batch = service.parseJson('''
{
  "feeds": [
    {
      "provider": "watchtower",
      "payloads": [
        {
          "external_id": "WT-1",
          "client_id": "CLIENT-001",
          "region_id": "REGION-GAUTENG",
          "site_id": "SITE-SANDTON",
          "headline": "Perimeter alarm",
          "summary": "Gate motion anomaly",
          "risk_score": 81,
          "occurred_at_utc": "2026-03-03T10:00:00Z"
        }
      ]
    },
    {
      "provider": "sentinelwire",
      "payloads": [
        {
          "external_id": "SW-2",
          "client_id": "CLIENT-001",
          "region_id": "REGION-GAUTENG",
          "site_id": "SITE-ROSEBANK",
          "headline": "Crowd signal",
          "summary": "Escalation risk near checkpoint",
          "risk_score": 73,
          "occurred_at_utc": "2026-03-03T10:01:00Z"
        }
      ]
    }
  ]
}
''');

    expect(batch.isConfigured, isTrue);
    expect(batch.feedCount, 2);
    expect(batch.feedDistribution, {'watchtower': 1, 'sentinelwire': 1});
    expect(batch.records, hasLength(2));
    expect(batch.records.first.provider, 'watchtower');
    expect(batch.records.first.sourceType, 'hardware');
    expect(batch.records.last.siteId, 'SITE-ROSEBANK');
  });
}
