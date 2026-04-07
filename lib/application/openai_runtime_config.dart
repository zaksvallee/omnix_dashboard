class OpenAiRuntimeConfig {
  final String apiKey;
  final String model;
  final Uri? endpoint;

  const OpenAiRuntimeConfig({
    required this.apiKey,
    required this.model,
    required this.endpoint,
  });

  bool get isConfigured => apiKey.trim().isNotEmpty && model.trim().isNotEmpty;

  static OpenAiRuntimeConfig resolve({
    required String primaryApiKey,
    required String primaryModel,
    required String primaryEndpoint,
    String secondaryApiKey = '',
    String secondaryModel = '',
    String secondaryEndpoint = '',
    String genericApiKey = '',
    String genericModel = '',
    String genericBaseUrl = '',
  }) {
    final apiKey = _firstNonEmpty(
      primaryApiKey,
      secondaryApiKey,
      genericApiKey,
    );
    final model = _firstNonEmpty(primaryModel, secondaryModel, genericModel);
    final endpointRaw = _firstNonEmpty(
      primaryEndpoint,
      secondaryEndpoint,
      genericBaseUrl,
    );
    return OpenAiRuntimeConfig(
      apiKey: apiKey,
      model: model,
      endpoint: _resolveResponsesEndpoint(endpointRaw),
    );
  }

  static String _firstNonEmpty(String first, String second, String third) {
    if (first.trim().isNotEmpty) {
      return first.trim();
    }
    if (second.trim().isNotEmpty) {
      return second.trim();
    }
    return third.trim();
  }

  static Uri? _resolveResponsesEndpoint(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) {
      return null;
    }
    final normalizedPath = parsed.path.trim();
    if (normalizedPath.isEmpty || normalizedPath == '/') {
      return parsed.replace(path: '/v1/responses');
    }
    if (normalizedPath.endsWith('/responses') ||
        normalizedPath == '/responses') {
      return parsed;
    }
    if (normalizedPath == '/v1' || normalizedPath == 'v1') {
      return parsed.replace(path: '/v1/responses');
    }
    return parsed;
  }
}
