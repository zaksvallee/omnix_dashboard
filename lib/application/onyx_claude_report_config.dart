class OnyxClaudeReportConfig {
  final String apiKey;
  final String model;
  final int maxTokens;
  final int timeoutSeconds;

  const OnyxClaudeReportConfig({
    required this.apiKey,
    this.model = 'claude-sonnet-4-6',
    this.maxTokens = 2048,
    this.timeoutSeconds = 30,
  });

  factory OnyxClaudeReportConfig.fromEnv(Map<String, String> env) {
    return OnyxClaudeReportConfig(
      apiKey: (env['ONYX_CLAUDE_API_KEY'] ?? '').trim(),
      model: (env['ONYX_CLAUDE_MODEL'] ?? 'claude-sonnet-4-6').trim(),
      maxTokens: int.tryParse(env['ONYX_CLAUDE_MAX_TOKENS'] ?? '') ?? 2048,
      timeoutSeconds:
          int.tryParse(env['ONYX_CLAUDE_TIMEOUT_SECONDS'] ?? '') ?? 30,
    );
  }

  bool get isConfigured => apiKey.trim().isNotEmpty;
}
