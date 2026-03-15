import 'dart:convert';

class DvrScopeConfig {
  final String clientId;
  final String regionId;
  final String siteId;
  final String provider;
  final Uri? eventsUri;
  final String authMode;
  final String username;
  final String password;
  final String bearerToken;

  const DvrScopeConfig({
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.provider,
    required this.eventsUri,
    required this.authMode,
    required this.username,
    required this.password,
    required this.bearerToken,
  });

  String get scopeKey => '${clientId.trim()}|${siteId.trim()}';

  bool get configured =>
      clientId.trim().isNotEmpty &&
      regionId.trim().isNotEmpty &&
      siteId.trim().isNotEmpty &&
      provider.trim().isNotEmpty &&
      eventsUri != null;

  static List<DvrScopeConfig> parseJson(
    String rawJson, {
    required String fallbackClientId,
    required String fallbackRegionId,
    required String fallbackSiteId,
    required String fallbackProvider,
    required Uri? fallbackEventsUri,
    required String fallbackAuthMode,
    required String fallbackUsername,
    required String fallbackPassword,
    required String fallbackBearerToken,
  }) {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(trimmed);
    final rawItems = switch (decoded) {
      List value => value,
      Map value => value['items'] is List ? value['items'] as List : const [],
      _ => const [],
    };
    final configs = <DvrScopeConfig>[];
    for (final item in rawItems.whereType<Map>()) {
      String readString(String key, {String fallback = ''}) {
        return (item[key] ?? fallback).toString().trim();
      }

      final eventsUrl = readString(
        'events_url',
        fallback: fallbackEventsUri?.toString() ?? '',
      );
      configs.add(
        DvrScopeConfig(
          clientId: readString('client_id', fallback: fallbackClientId),
          regionId: readString('region_id', fallback: fallbackRegionId),
          siteId: readString('site_id', fallback: fallbackSiteId),
          provider: readString('provider', fallback: fallbackProvider),
          eventsUri: Uri.tryParse(eventsUrl),
          authMode: readString('auth_mode', fallback: fallbackAuthMode),
          username: readString('username', fallback: fallbackUsername),
          password: readString('password', fallback: fallbackPassword),
          bearerToken: readString(
            'bearer_token',
            fallback: fallbackBearerToken,
          ),
        ),
      );
    }
    return configs.where((entry) => entry.configured).toList(growable: false);
  }
}
