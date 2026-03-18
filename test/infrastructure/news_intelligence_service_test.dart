import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/infrastructure/intelligence/news_intelligence_service.dart';

void main() {
  test(
    'NewsIntelligenceService requires at least one configured provider',
    () async {
      final service = NewsIntelligenceService(
        client: MockClient((_) async => http.Response('{}', 200)),
        newsApiOrgKey: '',
        newsApiAiKey: '',
        newsDataIoKey: '',
        worldNewsApiKey: '',
        openWeatherKey: '',
        communityFeedJson: '',
        baseQuery: 'crime',
      );

      await expectLater(
        () => service.fetchLatest(
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('No news or community providers configured'),
          ),
        ),
      );
    },
  );

  test(
    'NewsIntelligenceService normalizes configured provider payloads',
    () async {
      final client = MockClient((request) async {
        if (request.url.host == 'newsapi.org') {
          return http.Response('''
          {
            "articles": [
              {
                "url": "https://example.com/a",
                "title": "Armed robbery warning in Sandton",
                "description": "Security teams warn of syndicate activity near office parks.",
                "publishedAt": "2026-03-03T10:00:00Z"
              }
            ]
          }
          ''', 200);
        }
        if (request.url.host == 'newsdata.io') {
          return http.Response('''
          {
            "results": [
              {
                "article_id": "nd-1",
                "title": "Storm alert issued for Gauteng",
                "description": "Weather alert may disrupt patrol routes tonight.",
                "pubDate": "2026-03-03T11:00:00Z"
              }
            ]
          }
          ''', 200);
        }
        return http.Response('{}', 404);
      });

      final service = NewsIntelligenceService(
        client: client,
        newsApiOrgKey: 'org-key',
        newsDataIoKey: 'data-key',
        newsApiAiKey: '',
        worldNewsApiKey: '',
        openWeatherKey: '',
        baseQuery: 'crime',
      );

      final batch = await service.fetchLatest(
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );

      expect(batch.sourceLabel, 'news intelligence');
      expect(batch.feedDistribution, {'newsapi.org': 1, 'newsdata.io': 1});
      expect(batch.records, hasLength(2));
      expect(batch.records.first.provider, 'newsapi.org');
      expect(batch.records.first.clientId, 'CLIENT-001');
      expect(batch.records.first.regionId, 'REGION-GAUTENG');
      expect(batch.records.first.siteId, 'SITE-SANDTON');
      expect(batch.records.first.sourceType, 'news');
      expect(batch.records.first.riskScore, greaterThanOrEqualTo(70));
      expect(batch.records.last.provider, 'newsdata.io');
      expect(batch.records.last.sourceType, 'news');
      expect(batch.records.last.riskScore, greaterThanOrEqualTo(50));
    },
  );

  test(
    'NewsIntelligenceService normalizes configured community payloads',
    () async {
      final service = NewsIntelligenceService(
        client: MockClient((_) async => http.Response('{}', 200)),
        newsApiOrgKey: '',
        newsApiAiKey: '',
        newsDataIoKey: '',
        worldNewsApiKey: '',
        openWeatherKey: '',
        communityFeedJson: '''
      {
        "items": [
          {
            "id": "COMM-1",
            "message": "Residents report suspicious white Toyota Hilux scouting Sandton offices.",
            "timestamp": "2026-03-04T09:15:00Z"
          }
        ]
      }
      ''',
        baseQuery: 'crime',
      );

      final batch = await service.fetchLatest(
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );

      expect(batch.feedDistribution, {'community-feed': 1});
      expect(batch.records, hasLength(1));
      expect(batch.records.first.provider, 'community-feed');
      expect(batch.records.first.sourceType, 'community');
      expect(
        batch.records.first.headline,
        contains('Residents report suspicious'),
      );
      expect(batch.records.first.riskScore, greaterThanOrEqualTo(55));
    },
  );

  test(
    'NewsIntelligenceService can probe a configured provider',
    () async {
      final client = MockClient((request) async {
        if (request.url.host == 'newsapi.org') {
          return http.Response('''
          {
            "articles": [
              {
                "url": "https://example.com/probe",
                "title": "Probe event",
                "description": "Probe reached provider.",
                "publishedAt": "2026-03-03T10:00:00Z"
              }
            ]
          }
          ''', 200);
        }
        return http.Response('{}', 404);
      });

      final service = NewsIntelligenceService(
        client: client,
        newsApiOrgKey: 'org-key',
        newsApiAiKey: '',
        newsDataIoKey: '',
        worldNewsApiKey: '',
        openWeatherKey: '',
      );

      final result = await service.probeProvider(
        provider: 'newsapi.org',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );

      expect(result.provider, 'newsapi.org');
      expect(result.status, 'reachable');
      expect(result.detail, contains('1 ingestible record'));
      expect(result.checkedAtUtc, isNotEmpty);
    },
  );

  test(
    'NewsIntelligenceService treats placeholder keys as missing config',
    () async {
      final service = NewsIntelligenceService(
        client: MockClient((_) async => http.Response('{}', 200)),
        newsApiOrgKey: 'replace-me',
        newsApiAiKey: 'your_newsapi_ai_key_here',
        newsDataIoKey: '',
        worldNewsApiKey: 'replace-me',
        openWeatherKey: 'replace-me',
        communityFeedJson: '''
      {
        "items": [
          {
            "id": "COMM-1",
            "message": "Residents report suspicious movement.",
            "timestamp": "2026-03-04T09:15:00Z"
          }
        ]
      }
      ''',
      );

      expect(service.configuredProviders, ['community-feed']);
      expect(
        service.configurationHint,
        contains('Replace the placeholder ONYX_NEWSAPI_ORG_KEY value'),
      );
      expect(
        service.configurationHint,
        contains('Replace the placeholder ONYX_WORLDNEWSAPI_KEY value'),
      );

      final diagnosticsByProvider = {
        for (final diagnostic in service.diagnostics)
          diagnostic.provider: diagnostic,
      };
      expect(
        diagnosticsByProvider['newsapi.org']?.status,
        'missing key (placeholder)',
      );
      expect(
        diagnosticsByProvider['newsapi.ai']?.status,
        'missing key (placeholder)',
      );
      expect(
        diagnosticsByProvider['worldnewsapi.com']?.status,
        'missing key (placeholder)',
      );
      expect(
        diagnosticsByProvider['openweather.org']?.status,
        'missing key (placeholder)',
      );
      expect(
        diagnosticsByProvider['community-feed']?.status,
        'configured',
      );
    },
  );

  test(
    'NewsIntelligenceService treats angle-bracket placeholder keys as missing config',
    () async {
      final service = NewsIntelligenceService(
        client: MockClient((request) async {
          fail('placeholder keys should not trigger ${request.url}');
        }),
        newsApiOrgKey: '<newsapi-org-key>',
        newsApiAiKey: '<newsapi-ai-key>',
        newsDataIoKey: '',
        worldNewsApiKey: '<worldnewsapi-key>',
        openWeatherKey: '<openweather-key>',
      );

      expect(service.configuredProviders, isEmpty);

      final diagnosticsByProvider = {
        for (final diagnostic in service.diagnostics)
          diagnostic.provider: diagnostic,
      };
      expect(
        diagnosticsByProvider['newsapi.org']?.status,
        'missing key (placeholder)',
      );
      expect(
        diagnosticsByProvider['newsapi.ai']?.status,
        'missing key (placeholder)',
      );
      expect(
        diagnosticsByProvider['worldnewsapi.com']?.status,
        'missing key (placeholder)',
      );
      expect(
        diagnosticsByProvider['openweather.org']?.status,
        'missing key (placeholder)',
      );

      final probe = await service.probeProvider(
        provider: 'newsapi.org',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-VALLEE',
      );
      expect(probe.status, 'missing key (placeholder)');
    },
  );

  test(
    'NewsIntelligenceService retries world news with query auth and alternate article key',
    () async {
      final client = MockClient((request) async {
        if (request.url.host != 'api.worldnewsapi.com') {
          return http.Response('{}', 404);
        }
        if (request.headers['x-api-key'] == 'world-key' &&
            !request.url.queryParameters.containsKey('api-key')) {
          return http.Response('{"message":"Invalid API key header"}', 401);
        }
        if (request.url.queryParameters['api-key'] == 'world-key') {
          return http.Response('''
          {
            "articles": [
              {
                "url": "https://example.com/world",
                "title": "World probe event",
                "text": "Provider returned an alternate article shape.",
                "publish_date": "2026-03-03T12:00:00Z"
              }
            ]
          }
          ''', 200);
        }
        return http.Response('{}', 401);
      });

      final service = NewsIntelligenceService(
        client: client,
        newsApiOrgKey: '',
        newsApiAiKey: '',
        newsDataIoKey: '',
        worldNewsApiKey: 'world-key',
        openWeatherKey: '',
      );

      final result = await service.probeProvider(
        provider: 'worldnewsapi.com',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );

      expect(result.provider, 'worldnewsapi.com');
      expect(result.status, 'reachable');
      expect(result.detail, contains('1 ingestible record'));
    },
  );

  test(
    'NewsIntelligenceService includes provider error detail in failed probe results',
    () async {
      final client = MockClient((request) async {
        if (request.url.host == 'api.worldnewsapi.com') {
          return http.Response('{"message":"Invalid API key"}', 401);
        }
        return http.Response('{}', 404);
      });

      final service = NewsIntelligenceService(
        client: client,
        newsApiOrgKey: '',
        newsApiAiKey: '',
        newsDataIoKey: '',
        worldNewsApiKey: 'bad-key',
        openWeatherKey: '',
      );

      final result = await service.probeProvider(
        provider: 'worldnewsapi.com',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );

      expect(result.status, 'probe failed');
      expect(result.detail, contains('Invalid API key'));
    },
  );
}
