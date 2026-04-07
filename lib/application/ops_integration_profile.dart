import 'dart:convert';

import 'dvr_scope_config.dart';
import 'dvr_ingest_contract.dart';

class OnyxRadioIntegrationProfile {
  final String provider;
  final Uri? listenUrl;
  final Uri? respondUrl;
  final String channel;
  final bool aiAutoAllClearEnabled;

  const OnyxRadioIntegrationProfile({
    required this.provider,
    required this.listenUrl,
    required this.respondUrl,
    required this.channel,
    required this.aiAutoAllClearEnabled,
  });

  bool get configured => provider.isNotEmpty && listenUrl != null;

  bool get duplexEnabled => configured && respondUrl != null;

  String get readinessLabel {
    if (!configured) {
      return 'UNCONFIGURED';
    }
    return duplexEnabled ? 'LISTEN + RESPOND' : 'LISTEN ONLY';
  }

  String get detailLabel {
    if (!configured) {
      return 'Configure ONYX_RADIO_PROVIDER and ONYX_RADIO_LISTEN_URL.';
    }
    final channelLabel = channel.isEmpty ? 'default channel' : channel;
    final aiLabel = aiAutoAllClearEnabled
        ? 'AI all-clear enabled'
        : 'AI review only';
    return '$provider • $channelLabel • $aiLabel';
  }
}

class OnyxCctvIntegrationProfile {
  final String provider;
  final Uri? eventsUrl;
  final bool liveMonitoringEnabled;
  final bool facialRecognitionEnabled;
  final bool licensePlateRecognitionEnabled;

  const OnyxCctvIntegrationProfile({
    required this.provider,
    required this.eventsUrl,
    required this.liveMonitoringEnabled,
    required this.facialRecognitionEnabled,
    required this.licensePlateRecognitionEnabled,
  });

  bool get configured => provider.isNotEmpty && eventsUrl != null;

  List<String> get capabilityLabels {
    final labels = <String>[];
    if (liveMonitoringEnabled) {
      labels.add('LIVE AI MONITORING');
    }
    if (facialRecognitionEnabled) {
      labels.add('FR');
    }
    if (licensePlateRecognitionEnabled) {
      labels.add('LPR');
    }
    return labels;
  }

  String get readinessLabel {
    if (!configured) {
      return 'UNCONFIGURED';
    }
    if (!liveMonitoringEnabled) {
      return 'PARTIAL';
    }
    return 'ACTIVE';
  }

  String get detailLabel {
    if (!configured) {
      return 'Configure ONYX_CCTV_PROVIDER and ONYX_CCTV_EVENTS_URL.';
    }
    final caps = capabilityLabels.isEmpty
        ? 'No capabilities enabled'
        : capabilityLabels.join(' • ');
    return '$provider • $caps';
  }

  OnyxVideoIntegrationProfile toVideoProfile() {
    return OnyxVideoIntegrationProfile(
      kind: 'cctv',
      provider: provider,
      eventsUrl: eventsUrl,
      liveMonitoringEnabled: liveMonitoringEnabled,
      facialRecognitionEnabled: facialRecognitionEnabled,
      licensePlateRecognitionEnabled: licensePlateRecognitionEnabled,
    );
  }
}

class OnyxDvrIntegrationProfile {
  final String provider;
  final Uri? eventsUrl;
  final bool liveMonitoringEnabled;
  final bool facialRecognitionEnabled;
  final bool licensePlateRecognitionEnabled;

  const OnyxDvrIntegrationProfile({
    required this.provider,
    required this.eventsUrl,
    required this.liveMonitoringEnabled,
    required this.facialRecognitionEnabled,
    required this.licensePlateRecognitionEnabled,
  });

  bool get configured => provider.isNotEmpty && eventsUrl != null;

  String get readinessLabel {
    if (!configured) {
      return 'UNCONFIGURED';
    }
    if (!liveMonitoringEnabled) {
      return 'PARTIAL';
    }
    return 'ACTIVE';
  }

  List<String> get capabilityLabels {
    final labels = <String>[];
    if (liveMonitoringEnabled) {
      labels.add('LIVE AI MONITORING');
    }
    if (facialRecognitionEnabled) {
      labels.add('FR');
    }
    if (licensePlateRecognitionEnabled) {
      labels.add('LPR');
    }
    return labels;
  }

  String get detailLabel {
    if (!configured) {
      return 'Configure ONYX_DVR_PROVIDER and ONYX_DVR_EVENTS_URL.';
    }
    final caps = capabilityLabels.isEmpty
        ? 'No capabilities enabled'
        : capabilityLabels.join(' • ');
    return '$provider • $caps';
  }

  OnyxVideoIntegrationProfile toVideoProfile() {
    return OnyxVideoIntegrationProfile(
      kind: 'dvr',
      provider: provider,
      eventsUrl: eventsUrl,
      liveMonitoringEnabled: liveMonitoringEnabled,
      facialRecognitionEnabled: facialRecognitionEnabled,
      licensePlateRecognitionEnabled: licensePlateRecognitionEnabled,
    );
  }
}

class OnyxVideoIntegrationProfile {
  final String kind;
  final String provider;
  final Uri? eventsUrl;
  final bool liveMonitoringEnabled;
  final bool facialRecognitionEnabled;
  final bool licensePlateRecognitionEnabled;

  const OnyxVideoIntegrationProfile({
    required this.kind,
    required this.provider,
    required this.eventsUrl,
    required this.liveMonitoringEnabled,
    required this.facialRecognitionEnabled,
    required this.licensePlateRecognitionEnabled,
  });

  bool get configured => provider.isNotEmpty && eventsUrl != null;

  bool get isDvr => kind == 'dvr';

  bool get supportsMonitoringWatch =>
      isDvr && configured && liveMonitoringEnabled;

  List<String> get capabilityLabels {
    final labels = <String>[];
    if (liveMonitoringEnabled) {
      labels.add('LIVE AI MONITORING');
    }
    if (facialRecognitionEnabled) {
      labels.add('FR');
    }
    if (licensePlateRecognitionEnabled) {
      labels.add('LPR');
    }
    return labels;
  }

  String get readinessLabel {
    if (!configured) {
      return 'UNCONFIGURED';
    }
    if (!liveMonitoringEnabled) {
      return 'PARTIAL';
    }
    return 'ACTIVE';
  }

  String get detailLabel {
    if (!configured) {
      return 'Configure ONYX_CCTV_PROVIDER and ONYX_CCTV_EVENTS_URL, or ONYX_DVR_PROVIDER and ONYX_DVR_EVENTS_URL.';
    }
    final caps = capabilityLabels.isEmpty
        ? 'No capabilities enabled'
        : capabilityLabels.join(' • ');
    return '$provider • $caps';
  }
}

class OnyxOpsIntegrationProfile {
  final OnyxRadioIntegrationProfile radio;
  final OnyxCctvIntegrationProfile cctv;
  final OnyxDvrIntegrationProfile dvr;

  const OnyxOpsIntegrationProfile({
    required this.radio,
    required this.cctv,
    required this.dvr,
  });

  OnyxVideoIntegrationProfile get activeVideo {
    if (cctv.configured) {
      return cctv.toVideoProfile();
    }
    if (dvr.configured) {
      return dvr.toVideoProfile();
    }
    return cctv.toVideoProfile();
  }

  static OnyxVideoIntegrationProfile activeVideoFromDvrScopes(
    List<DvrScopeConfig> scopes, {
    String preferredClientId = '',
    String preferredSiteId = '',
  }) {
    final configuredScopes = scopes
        .where((scope) => scope.configured || scope.hikConnectConfigured)
        .toList(growable: false);
    if (configuredScopes.isEmpty) {
      return const OnyxVideoIntegrationProfile(
        kind: 'dvr',
        provider: '',
        eventsUrl: null,
        liveMonitoringEnabled: false,
        facialRecognitionEnabled: false,
        licensePlateRecognitionEnabled: false,
      );
    }
    final preferred = configuredScopes.cast<DvrScopeConfig?>().firstWhere(
      (scope) =>
          scope?.clientId.trim() == preferredClientId.trim() &&
          scope?.siteId.trim() == preferredSiteId.trim(),
      orElse: () => null,
    );
    final selectedScope = preferred ?? configuredScopes.first;
    final providerProfile = DvrProviderProfile.fromProvider(
      selectedScope.provider.trim(),
    );
    return OnyxVideoIntegrationProfile(
      kind: 'dvr',
      provider: selectedScope.provider,
      eventsUrl: selectedScope.eventsUri ?? selectedScope.apiBaseUri,
      liveMonitoringEnabled:
          providerProfile?.capabilities.liveMonitoringEnabled ?? false,
      facialRecognitionEnabled:
          providerProfile?.capabilities.facialRecognitionEnabled ?? false,
      licensePlateRecognitionEnabled:
          providerProfile?.capabilities.licensePlateRecognitionEnabled ?? false,
    );
  }

  factory OnyxOpsIntegrationProfile.fromEnvironment({
    required String radioProvider,
    required String radioListenUrl,
    required String radioRespondUrl,
    required String radioChannel,
    required bool radioAiAutoAllClearEnabled,
    required String cctvProvider,
    required String cctvEventsUrl,
    required bool cctvLiveMonitoringEnabled,
    required bool cctvFacialRecognitionEnabled,
    required bool cctvLicensePlateRecognitionEnabled,
    required String dvrProvider,
    required String dvrEventsUrl,
  }) {
    final dvrProfile = DvrProviderProfile.fromProvider(dvrProvider.trim());
    return OnyxOpsIntegrationProfile(
      radio: OnyxRadioIntegrationProfile(
        provider: radioProvider.trim(),
        listenUrl: _usableHttpUri(radioListenUrl),
        respondUrl: _usableHttpUri(radioRespondUrl),
        channel: radioChannel.trim(),
        aiAutoAllClearEnabled: radioAiAutoAllClearEnabled,
      ),
      cctv: OnyxCctvIntegrationProfile(
        provider: cctvProvider.trim(),
        eventsUrl: _usableHttpUri(cctvEventsUrl),
        liveMonitoringEnabled: cctvLiveMonitoringEnabled,
        facialRecognitionEnabled: cctvFacialRecognitionEnabled,
        licensePlateRecognitionEnabled: cctvLicensePlateRecognitionEnabled,
      ),
      dvr: OnyxDvrIntegrationProfile(
        provider: dvrProvider.trim(),
        eventsUrl: _usableHttpUri(dvrEventsUrl),
        liveMonitoringEnabled:
            dvrProfile?.capabilities.liveMonitoringEnabled ?? false,
        facialRecognitionEnabled:
            dvrProfile?.capabilities.facialRecognitionEnabled ?? false,
        licensePlateRecognitionEnabled:
            dvrProfile?.capabilities.licensePlateRecognitionEnabled ?? false,
      ),
    );
  }

  static Uri? _usableHttpUri(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return null;
    }
    if (!uri.isScheme('http') && !uri.isScheme('https')) {
      return null;
    }
    return uri;
  }
}

enum OnyxRadioIntent { allClear, panic, duress, status, unknown }

class OnyxRadioIntentPhraseCatalog {
  final List<String> allClearPhrases;
  final List<String> panicPhrases;
  final List<String> duressPhrases;
  final List<String> statusPhrases;

  const OnyxRadioIntentPhraseCatalog({
    required this.allClearPhrases,
    required this.panicPhrases,
    required this.duressPhrases,
    required this.statusPhrases,
  });

  factory OnyxRadioIntentPhraseCatalog.defaults() {
    return const OnyxRadioIntentPhraseCatalog(
      allClearPhrases: [
        'all clear',
        'all okay',
        'all ok',
        'client safe',
        'false alarm confirmed',
        'situation normal',
      ],
      panicPhrases: [
        'panic',
        'panic button',
        'need backup now',
        'send backup now',
        'officer down',
        'man down',
        'under attack',
        'shots fired',
      ],
      duressPhrases: [
        'duress',
        'silent duress',
        'covert duress',
        'unsafe code',
        'distress code',
        'code black',
      ],
      statusPhrases: [
        'status update',
        'on site',
        'arrived on site',
        'en route',
        'stand by',
        'standing by',
        'checkpoint complete',
      ],
    );
  }

  factory OnyxRadioIntentPhraseCatalog.fromJsonString(
    String raw, {
    required OnyxRadioIntentPhraseCatalog fallback,
  }) {
    final parsed = tryParseJsonString(raw);
    return parsed ?? fallback;
  }

  static OnyxRadioIntentPhraseCatalog? tryParseJsonString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        return null;
      }
      final source = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final allClear = _phraseListOptional(
        source,
        keys: const ['all_clear', 'allClear', 'allclear', 'allClearPhrases'],
      );
      final panic = _phraseListOptional(
        source,
        keys: const ['panic', 'panicPhrases'],
      );
      final duress = _phraseListOptional(
        source,
        keys: const ['duress', 'duressPhrases'],
      );
      final status = _phraseListOptional(
        source,
        keys: const ['status', 'statusPhrases'],
      );
      if (allClear == null &&
          panic == null &&
          duress == null &&
          status == null) {
        return null;
      }
      final defaults = OnyxRadioIntentPhraseCatalog.defaults();
      return OnyxRadioIntentPhraseCatalog(
        allClearPhrases: allClear ?? defaults.allClearPhrases,
        panicPhrases: panic ?? defaults.panicPhrases,
        duressPhrases: duress ?? defaults.duressPhrases,
        statusPhrases: status ?? defaults.statusPhrases,
      );
    } catch (_) {
      return null;
    }
  }

  static List<String>? _phraseListOptional(
    Map<String, Object?> source, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final raw = source[key];
      if (raw is! List) {
        continue;
      }
      final phrases = <String>{};
      for (final entry in raw) {
        final phrase = entry.toString().trim().toLowerCase();
        if (phrase.isNotEmpty) {
          phrases.add(phrase);
        }
      }
      if (phrases.isNotEmpty) {
        return phrases.toList(growable: false);
      }
    }
    return null;
  }
}

class OnyxRadioIntentClassifier {
  static final OnyxRadioIntentPhraseCatalog _catalog =
      OnyxRadioIntentPhraseCatalog.fromJsonString(
        const String.fromEnvironment('ONYX_RADIO_INTENT_PHRASES_JSON'),
        fallback: OnyxRadioIntentPhraseCatalog.defaults(),
      );
  static OnyxRadioIntentPhraseCatalog? _runtimeCatalog;

  static OnyxRadioIntentPhraseCatalog get activeCatalog =>
      _runtimeCatalog ?? _catalog;

  static void setRuntimePhraseCatalog(OnyxRadioIntentPhraseCatalog? catalog) {
    _runtimeCatalog = catalog;
  }

  static OnyxRadioIntent detect(String transcript) {
    return detectWithCatalog(transcript, activeCatalog);
  }

  static OnyxRadioIntent detectWithCatalog(
    String transcript,
    OnyxRadioIntentPhraseCatalog catalog,
  ) {
    final normalized = transcript.toLowerCase().trim();
    if (normalized.isEmpty) {
      return OnyxRadioIntent.unknown;
    }
    if (_containsAny(normalized, catalog.duressPhrases)) {
      return OnyxRadioIntent.duress;
    }
    if (_containsAny(normalized, catalog.panicPhrases)) {
      return OnyxRadioIntent.panic;
    }
    if (_containsAny(normalized, catalog.allClearPhrases)) {
      return OnyxRadioIntent.allClear;
    }
    if (_containsAny(normalized, catalog.statusPhrases)) {
      return OnyxRadioIntent.status;
    }
    return OnyxRadioIntent.unknown;
  }

  static bool _containsAny(String input, List<String> phrases) {
    for (final phrase in phrases) {
      if (input.contains(phrase)) {
        return true;
      }
    }
    return false;
  }
}

class OnyxRadioAllClearClassifier {
  static bool indicatesAllClear(String transcript) {
    return OnyxRadioIntentClassifier.detect(transcript) ==
        OnyxRadioIntent.allClear;
  }
}
