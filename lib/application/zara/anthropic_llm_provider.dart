import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'llm_provider.dart';

class AnthropicLlmProviderConfig {
  static const String _defaultEndpoint =
      'https://api.anthropic.com/v1/messages';

  final String apiKey;
  final String primaryModel;
  final String escalatedModel;
  final int defaultMaxOutputTokens;
  final Duration requestTimeout;
  final Uri endpoint;

  AnthropicLlmProviderConfig({
    required this.apiKey,
    this.primaryModel = 'claude-haiku-4-5',
    this.escalatedModel = 'claude-sonnet-4-6',
    this.defaultMaxOutputTokens = 1024,
    this.requestTimeout = const Duration(seconds: 20),
    Uri? endpoint,
  }) : endpoint = endpoint ?? Uri.parse(_defaultEndpoint);

  factory AnthropicLlmProviderConfig.fromEnv(Map<String, String> env) {
    return AnthropicLlmProviderConfig(
      apiKey:
          (env['ONYX_ZARA_ANTHROPIC_API_KEY'] ??
                  env['ONYX_CLAUDE_API_KEY'] ??
                  '')
              .trim(),
      primaryModel:
          (env['ONYX_ZARA_ANTHROPIC_PRIMARY_MODEL'] ?? 'claude-haiku-4-5')
              .trim(),
      escalatedModel:
          (env['ONYX_ZARA_ANTHROPIC_ESCALATED_MODEL'] ?? 'claude-sonnet-4-6')
              .trim(),
      defaultMaxOutputTokens:
          int.tryParse(env['ONYX_ZARA_ANTHROPIC_MAX_TOKENS'] ?? '') ?? 1024,
      requestTimeout: Duration(
        seconds:
            int.tryParse(env['ONYX_ZARA_ANTHROPIC_TIMEOUT_SECONDS'] ?? '') ??
            20,
      ),
      endpoint: Uri.parse(
        (env['ONYX_ZARA_ANTHROPIC_ENDPOINT'] ?? _defaultEndpoint).trim(),
      ),
    );
  }

  bool get isConfigured => apiKey.trim().isNotEmpty;

  String modelFor(LlmServiceLevel serviceLevel) {
    return serviceLevel == LlmServiceLevel.escalated
        ? escalatedModel.trim()
        : primaryModel.trim();
  }
}

class AnthropicLlmProvider implements LlmProvider {
  static const String _anthropicVersion = '2023-06-01';

  final http.Client client;
  final AnthropicLlmProviderConfig config;

  const AnthropicLlmProvider({required this.client, required this.config});

  @override
  bool get isConfigured => config.isConfigured;

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

    final modelId = config.modelFor(serviceLevel);
    try {
      final response = await client
          .post(
            config.endpoint,
            headers: <String, String>{
              'content-type': 'application/json',
              'x-api-key': config.apiKey,
              'anthropic-version': _anthropicVersion,
            },
            body: jsonEncode(<String, Object?>{
              'model': modelId,
              'max_tokens': maxOutputTokens ?? config.defaultMaxOutputTokens,
              if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
                'system': systemPrompt.trim(),
              'messages': messages
                  .where((message) => message.role != LlmMessageRole.system)
                  .map(_messagePayload)
                  .toList(growable: false),
              if (tools.isNotEmpty)
                'tools': tools.map(_toolPayload).toList(growable: false),
            }),
          )
          .timeout(config.requestTimeout);

      if (response.statusCode != 200) {
        developer.log(
          'Anthropic LLM provider fallback: HTTP ${response.statusCode}.',
          name: 'AnthropicLlmProvider',
          error: response.body,
        );
        return LlmResponse.fallback(
          providerLabel: 'anthropic:$modelId',
          modelId: modelId,
        );
      }

      final responseBody = _stringKeyedMap(jsonDecode(response.body));
      if (responseBody == null) {
        developer.log(
          'Anthropic LLM provider fallback: response body was not string-keyed JSON.',
          name: 'AnthropicLlmProvider',
        );
        return LlmResponse.fallback(
          providerLabel: 'anthropic:$modelId',
          modelId: modelId,
        );
      }

      final text = _extractTextBlock(responseBody['content']);
      if (text.isEmpty) {
        developer.log(
          'Anthropic LLM provider fallback: no text content block returned.',
          name: 'AnthropicLlmProvider',
        );
        return LlmResponse.fallback(
          providerLabel: 'anthropic:$modelId',
          modelId: modelId,
          rawResponse: responseBody,
        );
      }

      final usage = _stringKeyedMap(responseBody['usage']);
      return LlmResponse(
        text: text,
        providerLabel: 'anthropic:$modelId',
        modelId: modelId,
        inputTokens: _intFromValue(usage?['input_tokens']),
        outputTokens: _intFromValue(usage?['output_tokens']),
        rawResponse: responseBody,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Anthropic LLM provider fallback: request or parsing failed.',
        name: 'AnthropicLlmProvider',
        error: error,
        stackTrace: stackTrace,
      );
      return LlmResponse.fallback(
        providerLabel: 'anthropic:$modelId',
        modelId: modelId,
      );
    }
  }

  Map<String, Object?> _messagePayload(LlmMessage message) {
    return <String, Object?>{
      'role': _anthropicRole(message.role),
      'content': message.toolName == null || message.toolName!.trim().isEmpty
          ? message.text
          : '${message.toolName!.trim()}: ${message.text}',
    };
  }

  Map<String, Object?> _toolPayload(LlmTool tool) {
    return <String, Object?>{
      'name': tool.name,
      'description': tool.description,
      'input_schema': tool.inputSchema,
    };
  }
}

String _anthropicRole(LlmMessageRole role) {
  return switch (role) {
    LlmMessageRole.assistant => 'assistant',
    LlmMessageRole.tool => 'user',
    LlmMessageRole.user || LlmMessageRole.system => 'user',
  };
}

String _extractTextBlock(Object? contentValue) {
  if (contentValue is! List) {
    return '';
  }
  for (final block in contentValue) {
    final map = _stringKeyedMap(block);
    if (map == null) {
      continue;
    }
    if ((map['type'] ?? '').toString() == 'text') {
      final text = (map['text'] ?? '').toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
  }
  return '';
}

int _intFromValue(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse((value ?? '').toString()) ?? 0;
}

Map<String, Object?>? _stringKeyedMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return value.map(
    (key, nested) => MapEntry(key.toString(), nested as Object?),
  );
}
