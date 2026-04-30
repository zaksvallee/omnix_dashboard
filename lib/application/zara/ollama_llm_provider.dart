import '../ai/ollama_service.dart';
import 'llm_provider.dart';

class OllamaLlmProvider implements LlmProvider {
  final OllamaService ollamaService;
  final String primaryModel;
  final String escalatedModel;

  const OllamaLlmProvider({
    required this.ollamaService,
    required this.primaryModel,
    String? escalatedModel,
  }) : escalatedModel = escalatedModel ?? primaryModel;

  @override
  bool get isConfigured => ollamaService.isConfigured;

  @override
  Future<LlmResponse> complete({
    required List<LlmMessage> messages,
    String? systemPrompt,
    List<LlmTool> tools = const <LlmTool>[],
    LlmServiceLevel serviceLevel = LlmServiceLevel.primary,
    int? maxOutputTokens,
  }) async {
    if (!isConfigured) {
      return const LlmResponse.fallback();
    }

    final modelId = serviceLevel == LlmServiceLevel.escalated
        ? escalatedModel.trim()
        : primaryModel.trim();
    final resolvedSystemPrompt = [
      if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
        systemPrompt.trim(),
      ...messages
          .where((message) => message.role == LlmMessageRole.system)
          .map((message) => message.text.trim())
          .where((text) => text.isNotEmpty),
    ].join('\n\n');
    final userPrompt = messages
        .where((message) => message.role != LlmMessageRole.system)
        .map((message) {
          final role = switch (message.role) {
            LlmMessageRole.assistant => 'ASSISTANT',
            LlmMessageRole.tool => 'TOOL',
            LlmMessageRole.user => 'USER',
            LlmMessageRole.system => 'SYSTEM',
          };
          final prefix =
              message.toolName == null || message.toolName!.trim().isEmpty
              ? role
              : '$role ${message.toolName!.trim()}';
          return '$prefix: ${message.text.trim()}';
        })
        .where((line) => !line.endsWith(':'))
        .join('\n');
    final text = await ollamaService.generate(
      systemPrompt: resolvedSystemPrompt,
      userPrompt: userPrompt,
      model: modelId,
    );
    if (text == null || text.trim().isEmpty) {
      return LlmResponse.fallback(
        providerLabel: 'ollama:$modelId',
        modelId: modelId,
      );
    }
    return LlmResponse(
      text: text.trim(),
      providerLabel: 'ollama:$modelId',
      modelId: modelId,
    );
  }
}
