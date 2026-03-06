import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/intelligence/intel_ingestion.dart';

class NewsIntelligenceBatch {
  final List<NormalizedIntelRecord> records;
  final Map<String, int> feedDistribution;
  final String sourceLabel;

  const NewsIntelligenceBatch({
    required this.records,
    required this.feedDistribution,
    required this.sourceLabel,
  });

  int get feedCount => feedDistribution.length;
}

class NewsSourceDiagnostic {
  final String provider;
  final String status;
  final String detail;
  final String checkedAtUtc;

  const NewsSourceDiagnostic({
    required this.provider,
    required this.status,
    required this.detail,
    this.checkedAtUtc = '',
  });

  factory NewsSourceDiagnostic.fromJson(Map<String, Object?> json) {
    return NewsSourceDiagnostic(
      provider: (json['provider'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? '').trim(),
      detail: (json['detail'] as String? ?? '').trim(),
      checkedAtUtc: (json['checkedAtUtc'] as String? ?? '').trim(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'provider': provider,
      'status': status,
      'detail': detail,
      'checkedAtUtc': checkedAtUtc,
    };
  }
}

class NewsIntelligenceService {
  final http.Client _client;
  final String newsApiOrgKey;
  final String newsApiAiKey;
  final String newsDataIoKey;
  final String worldNewsApiKey;
  final String openWeatherKey;
  final String communityFeedJson;
  final String baseQuery;
  final double? weatherLat;
  final double? weatherLon;

  NewsIntelligenceService({
    http.Client? client,
    String? newsApiOrgKey,
    String? newsApiAiKey,
    String? newsDataIoKey,
    String? worldNewsApiKey,
    String? openWeatherKey,
    String? communityFeedJson,
    String? baseQuery,
    double? weatherLat,
    double? weatherLon,
  }) : _client = client ?? http.Client(),
       newsApiOrgKey = (newsApiOrgKey ?? _defaultNewsApiOrgKey()).trim(),
       newsApiAiKey = (newsApiAiKey ?? _defaultNewsApiAiKey()).trim(),
       newsDataIoKey = (newsDataIoKey ?? _defaultNewsDataIoKey()).trim(),
       worldNewsApiKey = (worldNewsApiKey ?? _defaultWorldNewsApiKey()).trim(),
       openWeatherKey = (openWeatherKey ?? _defaultOpenWeatherKey()).trim(),
       communityFeedJson = (communityFeedJson ?? _defaultCommunityFeedJson())
           .trim(),
       baseQuery = (baseQuery ?? _defaultNewsQuery()).trim(),
       weatherLat = weatherLat ?? _parseDouble(_defaultSiteLat()),
       weatherLon = weatherLon ?? _parseDouble(_defaultSiteLon());

  List<String> get configuredProviders {
    final providers = <String>[];
    if (_hasUsableCredential(newsApiOrgKey)) {
      providers.add('newsapi.org');
    }
    if (_hasUsableCredential(newsDataIoKey)) {
      providers.add('newsdata.io');
    }
    if (_hasUsableCredential(newsApiAiKey)) {
      providers.add('newsapi.ai');
    }
    if (_hasUsableCredential(worldNewsApiKey)) {
      providers.add('worldnewsapi.com');
    }
    if (_hasUsableCredential(openWeatherKey) &&
        weatherLat != null &&
        weatherLon != null) {
      providers.add('openweather.org');
    }
    if (communityFeedJson.isNotEmpty) {
      providers.add('community-feed');
    }
    return List<String>.unmodifiable(providers);
  }

  String? get configurationHint {
    final issues = <String>[];
    if (_hasPlaceholderCredential(newsApiOrgKey)) {
      issues.add('Replace the placeholder ONYX_NEWSAPI_ORG_KEY value');
    }
    if (_hasPlaceholderCredential(newsDataIoKey)) {
      issues.add('Replace the placeholder ONYX_NEWSDATA_IO_KEY value');
    }
    if (_hasPlaceholderCredential(newsApiAiKey)) {
      issues.add('Replace the placeholder ONYX_NEWSAPI_AI_KEY value');
    }
    if (_hasPlaceholderCredential(worldNewsApiKey)) {
      issues.add('Replace the placeholder ONYX_WORLDNEWSAPI_KEY value');
    }
    if (_hasPlaceholderCredential(openWeatherKey)) {
      issues.add('Replace the placeholder ONYX_OPENWEATHER_KEY value');
    }
    if (_hasUsableCredential(openWeatherKey) &&
        (weatherLat == null || weatherLon == null)) {
      issues.add('openweather.org requires ONYX_SITE_LAT and ONYX_SITE_LON');
    }
    if (configuredProviders.isEmpty && issues.isEmpty) {
      return 'Add at least one ONYX_* news source key or ONYX_COMMUNITY_FEED_JSON.';
    }
    if (issues.isEmpty) {
      return null;
    }
    return issues.join(' | ');
  }

  List<NewsSourceDiagnostic> get diagnostics {
    return List<NewsSourceDiagnostic>.unmodifiable([
      NewsSourceDiagnostic(
        provider: 'newsapi.org',
        status: _diagnosticStatusForCredential(newsApiOrgKey),
        detail: _diagnosticDetailForCredential(
          newsApiOrgKey,
          configuredDetail: 'Ready via ONYX_NEWSAPI_ORG_KEY.',
          missingDetail: 'Set ONYX_NEWSAPI_ORG_KEY.',
          placeholderDetail:
              'Replace the placeholder ONYX_NEWSAPI_ORG_KEY value.',
        ),
      ),
      NewsSourceDiagnostic(
        provider: 'newsdata.io',
        status: _diagnosticStatusForCredential(newsDataIoKey),
        detail: _diagnosticDetailForCredential(
          newsDataIoKey,
          configuredDetail: 'Ready via ONYX_NEWSDATA_IO_KEY.',
          missingDetail: 'Set ONYX_NEWSDATA_IO_KEY.',
          placeholderDetail:
              'Replace the placeholder ONYX_NEWSDATA_IO_KEY value.',
        ),
      ),
      NewsSourceDiagnostic(
        provider: 'newsapi.ai',
        status: _diagnosticStatusForCredential(newsApiAiKey),
        detail: _diagnosticDetailForCredential(
          newsApiAiKey,
          configuredDetail: 'Ready via ONYX_NEWSAPI_AI_KEY.',
          missingDetail: 'Set ONYX_NEWSAPI_AI_KEY.',
          placeholderDetail:
              'Replace the placeholder ONYX_NEWSAPI_AI_KEY value.',
        ),
      ),
      NewsSourceDiagnostic(
        provider: 'worldnewsapi.com',
        status: _diagnosticStatusForCredential(worldNewsApiKey),
        detail: _diagnosticDetailForCredential(
          worldNewsApiKey,
          configuredDetail: 'Ready via ONYX_WORLDNEWSAPI_KEY.',
          missingDetail: 'Set ONYX_WORLDNEWSAPI_KEY.',
          placeholderDetail:
              'Replace the placeholder ONYX_WORLDNEWSAPI_KEY value.',
        ),
      ),
      NewsSourceDiagnostic(
        provider: 'openweather.org',
        status: !_hasUsableCredential(openWeatherKey)
            ? _diagnosticStatusForCredential(openWeatherKey)
            : weatherLat == null || weatherLon == null
            ? 'missing site coords'
            : 'configured',
        detail: !_hasUsableCredential(openWeatherKey)
            ? _diagnosticDetailForCredential(
                openWeatherKey,
                configuredDetail: 'Ready via ONYX_OPENWEATHER_KEY.',
                missingDetail: 'Set ONYX_OPENWEATHER_KEY.',
                placeholderDetail:
                    'Replace the placeholder ONYX_OPENWEATHER_KEY value.',
              )
            : weatherLat == null || weatherLon == null
            ? 'Requires ONYX_SITE_LAT and ONYX_SITE_LON.'
            : 'Ready via ONYX_OPENWEATHER_KEY and site coordinates.',
      ),
      NewsSourceDiagnostic(
        provider: 'community-feed',
        status: communityFeedJson.isNotEmpty ? 'configured' : 'missing feed',
        detail: communityFeedJson.isNotEmpty
            ? 'Ready via ONYX_COMMUNITY_FEED_JSON.'
            : 'Set ONYX_COMMUNITY_FEED_JSON for structured community intake.',
      ),
    ]);
  }

  Future<NewsSourceDiagnostic> probeProvider({
    required String provider,
    required String clientId,
    required String regionId,
    required String siteId,
  }) async {
    final checkedAtUtc = DateTime.now().toUtc().toIso8601String();
    try {
      final records = switch (provider) {
        'newsapi.org' when newsApiOrgKey.isNotEmpty => await _fetchNewsApiOrg(
            clientId: clientId,
            regionId: regionId,
            siteId: siteId,
            query: _locationQuery(regionId: regionId, siteId: siteId),
          ),
        'newsdata.io' when newsDataIoKey.isNotEmpty => await _fetchNewsDataIo(
            clientId: clientId,
            regionId: regionId,
            siteId: siteId,
            query: _locationQuery(regionId: regionId, siteId: siteId),
          ),
        'newsapi.ai' when newsApiAiKey.isNotEmpty => await _fetchNewsApiAi(
            clientId: clientId,
            regionId: regionId,
            siteId: siteId,
            query: _locationQuery(regionId: regionId, siteId: siteId),
          ),
        'worldnewsapi.com' when worldNewsApiKey.isNotEmpty =>
          await _fetchWorldNewsApi(
            clientId: clientId,
            regionId: regionId,
            siteId: siteId,
            query: _locationQuery(regionId: regionId, siteId: siteId),
          ),
        'openweather.org'
            when openWeatherKey.isNotEmpty &&
                weatherLat != null &&
                weatherLon != null =>
          await _fetchOpenWeatherAlerts(
            clientId: clientId,
            regionId: regionId,
            siteId: siteId,
          ),
        'community-feed' when communityFeedJson.isNotEmpty => _parseCommunityFeed(
            clientId: clientId,
            regionId: regionId,
            siteId: siteId,
          ),
        _ => const <NormalizedIntelRecord>[],
      };
      final baseline = diagnostics.firstWhere(
        (entry) => entry.provider == provider,
        orElse: () => NewsSourceDiagnostic(
          provider: provider,
          status: 'unsupported',
          detail: 'No probe is available for this provider.',
        ),
      );
      if (baseline.status.startsWith('missing')) {
        return NewsSourceDiagnostic(
          provider: baseline.provider,
          status: baseline.status,
          detail: baseline.detail,
          checkedAtUtc: checkedAtUtc,
        );
      }
      if (records.isEmpty) {
        return NewsSourceDiagnostic(
          provider: provider,
          status: 'reachable-empty',
          detail: 'Probe succeeded but returned no ingestible records.',
          checkedAtUtc: checkedAtUtc,
        );
      }
      return NewsSourceDiagnostic(
        provider: provider,
        status: 'reachable',
        detail: 'Probe succeeded with ${records.length} ingestible record(s).',
        checkedAtUtc: checkedAtUtc,
      );
    } on FormatException catch (error) {
      return NewsSourceDiagnostic(
        provider: provider,
        status: 'probe failed',
        detail: error.message,
        checkedAtUtc: checkedAtUtc,
      );
    } catch (error) {
      return NewsSourceDiagnostic(
        provider: provider,
        status: 'probe failed',
        detail: error.toString(),
        checkedAtUtc: checkedAtUtc,
      );
    }
  }

  Future<NewsIntelligenceBatch> fetchLatest({
    required String clientId,
    required String regionId,
    required String siteId,
  }) async {
    final requests = <Future<List<NormalizedIntelRecord>>>[];
    final feedDistribution = <String, int>{};
    final locationQuery = _locationQuery(regionId: regionId, siteId: siteId);

    Future<void> collect(
      String provider,
      Future<List<NormalizedIntelRecord>> Function() action,
    ) async {
      final records = await action();
      if (records.isEmpty) {
        return;
      }
      feedDistribution[provider] = records.length;
      requests.add(Future<List<NormalizedIntelRecord>>.value(records));
    }

    if (newsApiOrgKey.isNotEmpty) {
      await collect(
        'newsapi.org',
        () => _fetchNewsApiOrg(
          clientId: clientId,
          regionId: regionId,
          siteId: siteId,
          query: locationQuery,
        ),
      );
    }
    if (newsDataIoKey.isNotEmpty) {
      await collect(
        'newsdata.io',
        () => _fetchNewsDataIo(
          clientId: clientId,
          regionId: regionId,
          siteId: siteId,
          query: locationQuery,
        ),
      );
    }
    if (newsApiAiKey.isNotEmpty) {
      await collect(
        'newsapi.ai',
        () => _fetchNewsApiAi(
          clientId: clientId,
          regionId: regionId,
          siteId: siteId,
          query: locationQuery,
        ),
      );
    }
    if (worldNewsApiKey.isNotEmpty) {
      await collect(
        'worldnewsapi.com',
        () => _fetchWorldNewsApi(
          clientId: clientId,
          regionId: regionId,
          siteId: siteId,
          query: locationQuery,
        ),
      );
    }
    if (openWeatherKey.isNotEmpty && weatherLat != null && weatherLon != null) {
      await collect(
        'openweather.org',
        () => _fetchOpenWeatherAlerts(
          clientId: clientId,
          regionId: regionId,
          siteId: siteId,
        ),
      );
    }
    if (communityFeedJson.isNotEmpty) {
      await collect(
        'community-feed',
        () async => _parseCommunityFeed(
          clientId: clientId,
          regionId: regionId,
          siteId: siteId,
        ),
      );
    }

    if (feedDistribution.isEmpty) {
      throw const FormatException(
        'No news or community providers configured. Add at least one ONYX_* source.',
      );
    }

    final records = <NormalizedIntelRecord>[];
    for (final batch in requests) {
      records.addAll(await batch);
    }

    if (records.isEmpty) {
      throw const FormatException(
        'Configured news providers returned no ingestible records.',
      );
    }

    return NewsIntelligenceBatch(
      records: records,
      feedDistribution: feedDistribution,
      sourceLabel: 'news intelligence',
    );
  }

  Future<List<NormalizedIntelRecord>> _fetchNewsApiOrg({
    required String clientId,
    required String regionId,
    required String siteId,
    required String query,
  }) async {
    final uri = Uri.https('newsapi.org', '/v2/everything', {
      'q': query,
      'language': 'en',
      'pageSize': '10',
      'sortBy': 'publishedAt',
      'apiKey': newsApiOrgKey,
    });
    final response = await _client.get(uri);
    _throwIfFailed(response, provider: 'newsapi.org');
    final decoded = _decodeMap(response.body, provider: 'newsapi.org');
    return _normalizeArticles(
      provider: 'newsapi.org',
      sourceType: 'news',
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      articles: _asList(decoded['articles']),
      idFromArticle: (article, index) =>
          _asString(article['url']).trim().isEmpty
          ? 'newsapi-org-$index'
          : _asString(article['url']).trim(),
      titleFromArticle: (article) => _asString(article['title']).trim(),
      summaryFromArticle: (article) => _firstNonEmpty([
        _asString(article['description']).trim(),
        _asString(article['content']).trim(),
      ]),
      occurredAtFromArticle: (article) =>
          _asString(article['publishedAt']).trim(),
    );
  }

  Future<List<NormalizedIntelRecord>> _fetchNewsDataIo({
    required String clientId,
    required String regionId,
    required String siteId,
    required String query,
  }) async {
    final uri = Uri.https('newsdata.io', '/api/1/latest', {
      'apikey': newsDataIoKey,
      'q': query,
      'language': 'en',
      'size': '10',
    });
    final response = await _client.get(uri);
    _throwIfFailed(response, provider: 'newsdata.io');
    final decoded = _decodeMap(response.body, provider: 'newsdata.io');
    return _normalizeArticles(
      provider: 'newsdata.io',
      sourceType: 'news',
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      articles: _asList(decoded['results']),
      idFromArticle: (article, index) => _firstNonEmpty([
        _asString(article['article_id']).trim(),
        _asString(article['link']).trim(),
        'newsdata-io-$index',
      ]),
      titleFromArticle: (article) => _asString(article['title']).trim(),
      summaryFromArticle: (article) => _firstNonEmpty([
        _asString(article['description']).trim(),
        _asString(article['content']).trim(),
      ]),
      occurredAtFromArticle: (article) => _firstNonEmpty([
        _asString(article['pubDate']).trim(),
        _asString(article['pubDateTZ']).trim(),
      ]),
    );
  }

  Future<List<NormalizedIntelRecord>> _fetchNewsApiAi({
    required String clientId,
    required String regionId,
    required String siteId,
    required String query,
  }) async {
    final uri = Uri.https('eventregistry.org', '/api/v1/article/getArticles');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'apiKey': newsApiAiKey,
        'keyword': query,
        'lang': 'eng',
        'articlesCount': 10,
        'resultType': 'articles',
      }),
    );
    _throwIfFailed(response, provider: 'newsapi.ai');
    final decoded = _decodeMap(response.body, provider: 'newsapi.ai');
    final articles = _asMap(decoded['articles'])['results'] is List
        ? _asList(_asMap(decoded['articles'])['results'])
        : _asList(decoded['articles']);
    return _normalizeArticles(
      provider: 'newsapi.ai',
      sourceType: 'news',
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      articles: articles,
      idFromArticle: (article, index) => _firstNonEmpty([
        _asString(article['uri']).trim(),
        _asString(article['url']).trim(),
        'newsapi-ai-$index',
      ]),
      titleFromArticle: (article) => _asString(article['title']).trim(),
      summaryFromArticle: (article) => _firstNonEmpty([
        _asString(article['body']).trim(),
        _asString(article['summary']).trim(),
      ]),
      occurredAtFromArticle: (article) => _firstNonEmpty([
        _asString(article['dateTimePub']).trim(),
        _asString(article['date']).trim(),
      ]),
    );
  }

  Future<List<NormalizedIntelRecord>> _fetchWorldNewsApi({
    required String clientId,
    required String regionId,
    required String siteId,
    required String query,
  }) async {
    final uri = Uri.https('api.worldnewsapi.com', '/search-news', {
      'text': query,
      'language': 'en',
      'number': '10',
    });
    final queryAuthUri = uri.replace(
      queryParameters: <String, String>{
        'api-key': worldNewsApiKey,
        ...uri.queryParameters,
      },
    );
    final attempts = <({Uri uri, Map<String, String> headers})>[
      (uri: uri, headers: {'x-api-key': worldNewsApiKey}),
      (uri: queryAuthUri, headers: const <String, String>{}),
    ];
    http.Response? response;
    for (final attemptRequest in attempts) {
      final attempt = await _client.get(
        attemptRequest.uri,
        headers: attemptRequest.headers,
      );
      response = attempt;
      if (attempt.statusCode >= 200 && attempt.statusCode < 300) {
        break;
      }
    }
    if (response == null) {
      throw const FormatException(
        'worldnewsapi.com request failed before a response was received.',
      );
    }
    _throwIfFailed(response, provider: 'worldnewsapi.com');
    final decoded = _decodeMap(response.body, provider: 'worldnewsapi.com');
    final articles = _firstNonEmptyList([
      _asList(decoded['news']),
      _asList(decoded['articles']),
      _asList(decoded['data']),
    ]);
    return _normalizeArticles(
      provider: 'worldnewsapi.com',
      sourceType: 'news',
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      articles: articles,
      idFromArticle: (article, index) => _firstNonEmpty([
        _asString(article['url']).trim(),
        'worldnews-$index',
      ]),
      titleFromArticle: (article) => _asString(article['title']).trim(),
      summaryFromArticle: (article) => _firstNonEmpty([
        _asString(article['text']).trim(),
        _asString(article['summary']).trim(),
      ]),
      occurredAtFromArticle: (article) => _firstNonEmpty([
        _asString(article['publish_date']).trim(),
        _asString(article['publishedAt']).trim(),
      ]),
    );
  }

  Future<List<NormalizedIntelRecord>> _fetchOpenWeatherAlerts({
    required String clientId,
    required String regionId,
    required String siteId,
  }) async {
    final lat = weatherLat;
    final lon = weatherLon;
    if (lat == null || lon == null) {
      return const [];
    }
    final uri = Uri.https('api.openweathermap.org', '/data/3.0/onecall', {
      'lat': lat.toString(),
      'lon': lon.toString(),
      'exclude': 'current,minutely,hourly,daily',
      'appid': openWeatherKey,
    });
    final response = await _client.get(uri);
    _throwIfFailed(response, provider: 'openweather.org');
    final decoded = _decodeMap(response.body, provider: 'openweather.org');
    return _normalizeArticles(
      provider: 'openweather.org',
      sourceType: 'weather',
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      articles: _asList(decoded['alerts']),
      idFromArticle: (article, index) => _firstNonEmpty([
        _asString(article['event']).trim(),
        'openweather-$index',
      ]),
      titleFromArticle: (article) => _asString(article['event']).trim(),
      summaryFromArticle: (article) => _firstNonEmpty([
        _asString(article['description']).trim(),
        _asString(article['sender_name']).trim(),
      ]),
      occurredAtFromArticle: (article) =>
          _unixSecondsToIso(_asInt(article['start'])),
    );
  }

  List<NormalizedIntelRecord> _parseCommunityFeed({
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    final decoded = jsonDecode(communityFeedJson);
    final entries = decoded is List
        ? _asList(decoded)
        : (() {
            final map = _asMap(decoded);
            if (map['items'] is List) {
              return _asList(map['items']);
            }
            if (map['messages'] is List) {
              return _asList(map['messages']);
            }
            return const <Object?>[];
          })();
    return _normalizeArticles(
      provider: 'community-feed',
      sourceType: 'community',
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      articles: entries,
      idFromArticle: (article, index) => _firstNonEmpty([
        _asString(article['id']).trim(),
        _asString(article['message_id']).trim(),
        _asString(article['url']).trim(),
        'community-$index',
      ]),
      titleFromArticle: (article) => _firstNonEmpty([
        _asString(article['headline']).trim(),
        _asString(article['title']).trim(),
        _summarizeCommunityText(
          _firstNonEmpty([
            _asString(article['message']).trim(),
            _asString(article['text']).trim(),
            _asString(article['summary']).trim(),
          ]),
        ),
      ]),
      summaryFromArticle: (article) => _firstNonEmpty([
        _asString(article['summary']).trim(),
        _asString(article['message']).trim(),
        _asString(article['text']).trim(),
      ]),
      occurredAtFromArticle: (article) => _firstNonEmpty([
        _asString(article['occurred_at_utc']).trim(),
        _asString(article['timestamp']).trim(),
        _asString(article['created_at']).trim(),
      ]),
      riskScoreFromArticle: (article, headline, summary) {
        final explicitRisk = _asInt(article['risk_score']);
        if (explicitRisk > 0) {
          return explicitRisk.clamp(0, 100);
        }
        final score = _scoreArticle(headline: headline, summary: summary) + 5;
        return score.clamp(0, 100);
      },
    );
  }

  List<NormalizedIntelRecord> _normalizeArticles({
    required String provider,
    required String sourceType,
    required String clientId,
    required String regionId,
    required String siteId,
    required List<Object?> articles,
    required String Function(Map<String, Object?> article, int index)
    idFromArticle,
    required String Function(Map<String, Object?> article) titleFromArticle,
    required String Function(Map<String, Object?> article) summaryFromArticle,
    required String Function(Map<String, Object?> article)
    occurredAtFromArticle,
    int Function(Map<String, Object?> article, String headline, String summary)?
    riskScoreFromArticle,
  }) {
    final records = <NormalizedIntelRecord>[];
    for (int index = 0; index < articles.length; index++) {
      final article = _asMap(articles[index]);
      final externalId = idFromArticle(article, index).trim();
      final headline = titleFromArticle(article).trim();
      final summary = summaryFromArticle(article).trim();
      final occurredAt = DateTime.tryParse(
        occurredAtFromArticle(article).trim(),
      )?.toUtc();
      if (externalId.isEmpty ||
          headline.isEmpty ||
          summary.isEmpty ||
          occurredAt == null) {
        continue;
      }
      records.add(
        NormalizedIntelRecord(
          provider: provider,
          sourceType: sourceType,
          externalId: externalId,
          clientId: clientId,
          regionId: regionId,
          siteId: siteId,
          headline: headline,
          summary: summary,
          riskScore:
              riskScoreFromArticle?.call(article, headline, summary) ??
              _scoreArticle(headline: headline, summary: summary),
          occurredAtUtc: occurredAt,
        ),
      );
    }
    return records;
  }

  int _scoreArticle({required String headline, required String summary}) {
    final haystack = '${headline.toLowerCase()} ${summary.toLowerCase()}';
    var score = 35;
    const severeTerms = [
      'hijack',
      'armed',
      'shooting',
      'kidnap',
      'home invasion',
      'hostage',
    ];
    const highTerms = [
      'robbery',
      'burglary',
      'intruder',
      'syndicate',
      'attack',
      'loot',
      'stolen vehicle',
      'lpr',
      'vehicle theft',
    ];
    const elevatedTerms = [
      'protest',
      'suspicious',
      'trespass',
      'gang',
      'security alert',
      'warning',
      'weather alert',
      'storm',
    ];
    if (severeTerms.any(haystack.contains)) {
      score += 35;
    } else if (highTerms.any(haystack.contains)) {
      score += 25;
    } else if (elevatedTerms.any(haystack.contains)) {
      score += 15;
    }
    if (haystack.contains('sandton') || haystack.contains('gauteng')) {
      score += 10;
    }
    return score.clamp(0, 100);
  }

  String _locationQuery({required String regionId, required String siteId}) {
    final locationTerms = [
      _cleanLocationToken(regionId),
      _cleanLocationToken(siteId),
    ].where((value) => value.isNotEmpty).join(' OR ');
    if (locationTerms.isEmpty) {
      return baseQuery;
    }
    if (baseQuery.isEmpty) {
      return locationTerms;
    }
    return '($baseQuery) AND ($locationTerms)';
  }

  String _cleanLocationToken(String raw) {
    return raw
        .replaceAll(RegExp(r'^[A-Z]+-'), '')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();
  }

  void _throwIfFailed(http.Response response, {required String provider}) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    final detail = _extractErrorDetail(response.body);
    throw FormatException(
      detail.isEmpty
          ? '$provider request failed with HTTP ${response.statusCode}'
          : '$provider request failed with HTTP ${response.statusCode}: $detail',
    );
  }

  Map<String, Object?> _decodeMap(String raw, {required String provider}) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
    }
    throw FormatException('$provider returned an invalid JSON payload.');
  }

  Map<String, Object?> _asMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, entry) => MapEntry(key.toString(), entry as Object?),
      );
    }
    return const {};
  }

  List<Object?> _asList(Object? value) {
    if (value is List<Object?>) {
      return value;
    }
    if (value is List) {
      return List<Object?>.from(value);
    }
    return const [];
  }

  List<Object?> _firstNonEmptyList(List<List<Object?>> values) {
    for (final value in values) {
      if (value.isNotEmpty) {
        return value;
      }
    }
    return const [];
  }

  String _asString(Object? value) => value is String ? value : '';

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  String _extractErrorDetail(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    try {
      final decoded = jsonDecode(trimmed);
      final map = _asMap(decoded);
      return _firstNonEmpty([
        _asString(map['message']).trim(),
        _asString(map['error']).trim(),
        _asString(map['detail']).trim(),
        _asString(map['status_message']).trim(),
      ]);
    } catch (_) {
      if (trimmed.length <= 180) {
        return trimmed;
      }
      return '${trimmed.substring(0, 177)}...';
    }
  }

  String _summarizeCommunityText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.length <= 64) {
      return trimmed;
    }
    return '${trimmed.substring(0, 61)}...';
  }

  static double? _parseDouble(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  static bool _hasUsableCredential(String raw) {
    final trimmed = raw.trim();
    return trimmed.isNotEmpty && !_hasPlaceholderCredential(trimmed);
  }

  static bool _hasPlaceholderCredential(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    if (normalized == 'replace-me') {
      return true;
    }
    return normalized.startsWith('your_') && normalized.endsWith('_here');
  }

  static String _diagnosticStatusForCredential(String raw) {
    if (_hasPlaceholderCredential(raw)) {
      return 'missing key (placeholder)';
    }
    return raw.isNotEmpty ? 'configured' : 'missing key';
  }

  static String _diagnosticDetailForCredential(
    String raw, {
    required String configuredDetail,
    required String missingDetail,
    required String placeholderDetail,
  }) {
    if (_hasPlaceholderCredential(raw)) {
      return placeholderDetail;
    }
    return raw.isNotEmpty ? configuredDetail : missingDetail;
  }

  String _unixSecondsToIso(int seconds) {
    if (seconds <= 0) {
      return '';
    }
    return DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    ).toIso8601String();
  }

  static String _defaultNewsApiOrgKey() => _firstConfigured([
    const String.fromEnvironment('ONYX_NEWSAPI_ORG_KEY'),
    const String.fromEnvironment('NEWSAPI_ORG_KEY'),
  ]);

  static String _defaultNewsApiAiKey() => _firstConfigured([
    const String.fromEnvironment('ONYX_NEWSAPI_AI_KEY'),
    const String.fromEnvironment('NEWSAPI_AI_KEY'),
  ]);

  static String _defaultNewsDataIoKey() => _firstConfigured([
    const String.fromEnvironment('ONYX_NEWSDATA_IO_KEY'),
    const String.fromEnvironment('NEWSDATA_IO_KEY'),
  ]);

  static String _defaultWorldNewsApiKey() => _firstConfigured([
    const String.fromEnvironment('ONYX_WORLDNEWSAPI_KEY'),
    const String.fromEnvironment('WORLDNEWSAPI_COM_KEY'),
  ]);

  static String _defaultOpenWeatherKey() => _firstConfigured([
    const String.fromEnvironment('ONYX_OPENWEATHER_KEY'),
    const String.fromEnvironment('OPENWEATHER_ORG_KEY'),
  ]);

  static String _defaultNewsQuery() => _firstConfigured([
    const String.fromEnvironment('ONYX_NEWS_QUERY'),
    const String.fromEnvironment('NEWS_QUERY'),
    'security OR crime OR burglary OR robbery OR hijacking',
  ]);

  static String _defaultCommunityFeedJson() => _firstConfigured([
    const String.fromEnvironment('ONYX_COMMUNITY_FEED_JSON'),
    const String.fromEnvironment('COMMUNITY_FEED_JSON'),
  ]);

  static String _defaultSiteLat() => _firstConfigured([
    const String.fromEnvironment('ONYX_SITE_LAT'),
    const String.fromEnvironment('SITE_LAT'),
  ]);

  static String _defaultSiteLon() => _firstConfigured([
    const String.fromEnvironment('ONYX_SITE_LON'),
    const String.fromEnvironment('SITE_LON'),
  ]);

  static String _firstConfigured(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }
}
