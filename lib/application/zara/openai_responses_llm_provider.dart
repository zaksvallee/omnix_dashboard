import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'llm_provider.dart';

class OpenAiResponsesLlmProviderConfig {
  static const String _defaultEndpoint = 'https://api.openai.com/v1/responses';

  final String apiKey;
  final String primaryModel;
  final String escalatedModel;
  final int defaultMaxOutputTokens;
  final Duration requestTimeout;
  final Uri endpoint;

  OpenAiResponsesLlmProviderConfig({
    required this.apiKey,
    this.primaryModel = 'gpt-4.1-mini',
    this.escalatedModel = 'gpt-4.1',
    this.defaultMaxOutputTokens = 320,
    this.requestTimeout = const Duration(seconds: 20),
    Uri? endpoint,
  }) : endpoint = endpoint ?? Uri.parse(_defaultEndpoint);

  factory OpenAiResponsesLlmProviderConfig.fromEnv(Map<String, String> env) {
    final rawEndpoint =
        (env['ONYX_ZARA_OPENAI_ENDPOINT'] ??
                env['ONYX_TELEGRAM_AI_OPENAI_ENDPOINT'] ??
                env['OPENAI_BASE_URL'] ??
                _defaultEndpoint)
            .trim();
    return OpenAiResponsesLlmProviderConfig(
      apiKey:
          (env['ONYX_ZARA_OPENAI_API_KEY'] ??
                  env['ONYX_TELEGRAM_AI_OPENAI_API_KEY'] ??
                  env['OPENAI_API_KEY'] ??
                  '')
              .trim(),
      primaryModel:
          (env['ONYX_ZARA_OPENAI_PRIMARY_MODEL'] ??
                  env['ONYX_TELEGRAM_AI_OPENAI_MODEL'] ??
                  env['OPENAI_MODEL'] ??
                  'gpt-4.1-mini')
              .trim(),
      escalatedModel: (env['ONYX_ZARA_OPENAI_ESCALATED_MODEL'] ?? 'gpt-4.1')
          .trim(),
      defaultMaxOutputTokens:
          int.tryParse(env['ONYX_ZARA_OPENAI_MAX_TOKENS'] ?? '') ?? 320,
      requestTimeout: Duration(
        seconds:
            int.tryParse(env['ONYX_ZARA_OPENAI_TIMEOUT_SECONDS'] ?? '') ?? 20,
      ),
      endpoint: _resolveEndpoint(rawEndpoint),
    );
  }

  bool get isConfigured => apiKey.trim().isNotEmpty;

  String modelFor(LlmServiceLevel serviceLevel) {
    return serviceLevel == LlmServiceLevel.escalated
        ? escalatedModel.trim()
        : primaryModel.trim();
  }
}

class OpenAiResponsesLlmProvider implements LlmProvider {
  final http.Client client;
  final OpenAiResponsesLlmProviderConfig config;

  const OpenAiResponsesLlmProvider({
    required this.client,
    required this.config,
  });

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
      final input = <Map<String, Object?>>[
        if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
          <String, Object?>{
            'role': 'system',
            'content': <Map<String, String>>[
              <String, String>{
                'type': 'input_text',
                'text': systemPrompt.trim(),
              },
            ],
          },
        ...messages.map(_messagePayload),
      ];
      final response = await client
          .post(
            config.endpoint,
            headers: <String, String>{
              'Authorization': 'Bearer ${config.apiKey}',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, Object?>{
              'model': modelId,
              'input': input,
              'max_output_tokens':
                  maxOutputTokens ?? config.defaultMaxOutputTokens,
              if (tools.isNotEmpty)
                'tools': tools.map(_toolPayload).toList(growable: false),
            }),
          )
          .timeout(config.requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        developer.log(
          'OpenAI responses provider fallback: HTTP ${response.statusCode}.',
          name: 'OpenAiResponsesLlmProvider',
          error: response.body,
        );
        return LlmResponse.fallback(
          providerLabel: 'openai:$modelId',
          modelId: modelId,
        );
      }

      final decoded = _stringKeyedMap(jsonDecode(response.body));
      if (decoded == null) {
        developer.log(
          'OpenAI responses provider fallback: response body was not string-keyed JSON.',
          name: 'OpenAiResponsesLlmProvider',
        );
        return LlmResponse.fallback(
          providerLabel: 'openai:$modelId',
          modelId: modelId,
        );
      }

      final text = _extractText(decoded);
      if (text == null || text.trim().isEmpty) {
        developer.log(
          'OpenAI responses provider fallback: no output text returned.',
          name: 'OpenAiResponsesLlmProvider',
        );
        return LlmResponse.fallback(
          providerLabel: 'openai:$modelId',
          modelId: modelId,
          rawResponse: decoded,
        );
      }

      final usage = _stringKeyedMap(decoded['usage']);
      return LlmResponse(
        text: text.trim(),
        providerLabel: 'openai:$modelId',
        modelId: modelId,
        inputTokens: _intFromValue(
          usage?['input_tokens'] ?? usage?['prompt_tokens'],
        ),
        outputTokens: _intFromValue(
          usage?['output_tokens'] ?? usage?['completion_tokens'],
        ),
        rawResponse: decoded,
      );
    } catch (error, stackTrace) {
      developer.log(
        'OpenAI responses provider fallback: request or parsing failed.',
        name: 'OpenAiResponsesLlmProvider',
        error: error,
        stackTrace: stackTrace,
      );
      return LlmResponse.fallback(
        providerLabel: 'openai:$modelId',
        modelId: modelId,
      );
    }
  }

  Map<String, Object?> _messagePayload(LlmMessage message) {
    return <String, Object?>{
      'role': _openAiRole(message.role),
      'content': <Map<String, String>>[
        <String, String>{
          'type': 'input_text',
          'text': message.toolName == null || message.toolName!.trim().isEmpty
              ? message.text
              : '${message.toolName!.trim()}: ${message.text}',
        },
      ],
    };
  }

  Map<String, Object?> _toolPayload(LlmTool tool) {
    return <String, Object?>{
      'type': 'function',
      'name': tool.name,
      'description': tool.description,
      'parameters': tool.inputSchema,
    };
  }
}

Uri _resolveEndpoint(String rawEndpoint) {
  final parsed = Uri.parse(rawEndpoint);
  final path = parsed.path.trim();
  if (path.endsWith('/responses')) {
    return parsed;
  }
  if (path.endsWith('/v1')) {
    return parsed.replace(path: '$path/responses');
  }
  if (path.isEmpty || path == '/') {
    return parsed.replace(path: '/v1/responses');
  }
  if (path.endsWith('/')) {
    return parsed.replace(path: '${path}responses');
  }
  return parsed.replace(path: '$path/v1/responses');
}

String _openAiRole(LlmMessageRole role) {
  return switch (role) {
    LlmMessageRole.system => 'system',
    LlmMessageRole.assistant => 'assistant',
    LlmMessageRole.tool => 'tool',
    LlmMessageRole.user => 'user',
  };
}

String? _extractText(Map<String, Object?> decoded) {
  final outputText = decoded['output_text'];
  if (outputText is String && outputText.trim().isNotEmpty) {
    return outputText.trim();
  }

  final output = decoded['output'];
  if (output is List) {
    final chunks = <String>[];
    for (final item in output) {
      if (item is! Map) {
        continue;
      }
      final content = item['content'];
      if (content is! List) {
        continue;
      }
      for (final part in content) {
        if (part is! Map) {
          continue;
        }
        final text = (part['text'] ?? '').toString().trim();
        if (text.isNotEmpty) {
          chunks.add(text);
        }
      }
    }
    if (chunks.isNotEmpty) {
      return chunks.join('\n').trim();
    }
  }

  final choices = decoded['choices'];
  if (choices is List && choices.isNotEmpty) {
    final first = choices.first;
    if (first is Map) {
      final message = first['message'];
      if (message is Map) {
        final content = (message['content'] ?? '').toString().trim();
        if (content.isNotEmpty) {
          return content;
        }
      }
    }
  }
  return null;
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
