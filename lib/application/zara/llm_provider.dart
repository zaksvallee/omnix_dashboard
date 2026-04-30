enum LlmMessageRole { system, user, assistant, tool }

enum LlmServiceLevel { primary, escalated }

class LlmMessage {
  final LlmMessageRole role;
  final String text;
  final String? toolName;

  const LlmMessage({required this.role, required this.text, this.toolName});
}

class LlmTool {
  final String name;
  final String description;
  final Map<String, Object?> inputSchema;

  const LlmTool({
    required this.name,
    required this.description,
    required this.inputSchema,
  });
}

class LlmResponse {
  final String text;
  final bool usedFallback;
  final String providerLabel;
  final String modelId;
  final int inputTokens;
  final int outputTokens;
  final Map<String, Object?> rawResponse;

  const LlmResponse({
    required this.text,
    required this.providerLabel,
    required this.modelId,
    this.usedFallback = false,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.rawResponse = const <String, Object?>{},
  });

  const LlmResponse.fallback({
    this.text = '',
    this.providerLabel = 'fallback',
    this.modelId = 'fallback',
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.rawResponse = const <String, Object?>{},
  }) : usedFallback = true;

  bool get hasText => text.trim().isNotEmpty;
}

abstract class LlmProvider {
  bool get isConfigured;

  Future<LlmResponse> complete({
    required List<LlmMessage> messages,
    String? systemPrompt,
    List<LlmTool> tools = const <LlmTool>[],
    LlmServiceLevel serviceLevel = LlmServiceLevel.primary,
    int? maxOutputTokens,
  });
}

class UnconfiguredLlmProvider implements LlmProvider {
  const UnconfiguredLlmProvider();

  @override
  bool get isConfigured => false;

  @override
  Future<LlmResponse> complete({
    required List<LlmMessage> messages,
    String? systemPrompt,
    List<LlmTool> tools = const <LlmTool>[],
    LlmServiceLevel serviceLevel = LlmServiceLevel.primary,
    int? maxOutputTokens,
  }) async {
    return const LlmResponse.fallback();
  }
}
