enum LlmMessageRole { system, user, assistant, tool }

enum LlmServiceLevel { primary, escalated }

class LlmToolCall {
  final String id;
  final String toolName;
  final Map<String, Object?> input;

  const LlmToolCall({
    required this.id,
    required this.toolName,
    required this.input,
  });
}

class LlmMessage {
  final LlmMessageRole role;
  final String text;
  final String? toolName;
  final String? toolUseId;
  final List<LlmToolCall> toolCalls;
  final bool isError;

  const LlmMessage({
    required this.role,
    this.text = '',
    this.toolName,
    this.toolUseId,
    this.toolCalls = const <LlmToolCall>[],
    this.isError = false,
  });
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
  final List<LlmToolCall> toolCalls;

  const LlmResponse({
    required this.text,
    required this.providerLabel,
    required this.modelId,
    this.usedFallback = false,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.rawResponse = const <String, Object?>{},
    this.toolCalls = const <LlmToolCall>[],
  });

  const LlmResponse.fallback({
    this.text = '',
    this.providerLabel = 'fallback',
    this.modelId = 'fallback',
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.rawResponse = const <String, Object?>{},
    this.toolCalls = const <LlmToolCall>[],
  }) : usedFallback = true;

  bool get hasText => text.trim().isNotEmpty;
  bool get hasToolCalls => toolCalls.isNotEmpty;
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
