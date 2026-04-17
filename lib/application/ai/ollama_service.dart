import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

abstract class OllamaService {
  bool get isConfigured;

  Future<String?> generate({
    required String systemPrompt,
    required String userPrompt,
    required String model,
  });
}

extension OllamaServiceJsonExtension on OllamaService {
  Future<Map<String, Object?>?> generateJson({
    required String systemPrompt,
    required String userPrompt,
    required String model,
  }) async {
    final response = await generate(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      model: model,
    );
    if (response == null || response.trim().isEmpty) {
      return null;
    }
    return _decodeJson(response);
  }
}

class UnconfiguredOllamaService implements OllamaService {
  const UnconfiguredOllamaService();

  @override
  bool get isConfigured => false;

  @override
  Future<String?> generate({
    required String systemPrompt,
    required String userPrompt,
    required String model,
  }) async {
    return null;
  }
}

class HttpOllamaService implements OllamaService {
  final http.Client client;
  final Uri endpoint;
  final Duration requestTimeout;

  HttpOllamaService({
    required this.client,
    Uri? endpoint,
    this.requestTimeout = const Duration(seconds: 12),
  }) : endpoint = _resolveChatEndpoint(
         endpoint ?? Uri.parse('http://127.0.0.1:11434'),
       );

  @override
  bool get isConfigured => true;

  @override
  Future<String?> generate({
    required String systemPrompt,
    required String userPrompt,
    required String model,
  }) async {
    if (model.trim().isEmpty) {
      return null;
    }
    try {
      final response = await client
          .post(
            endpoint,
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, Object?>{
              'model': model.trim(),
              'stream': false,
              'messages': <Map<String, String>>[
                <String, String>{'role': 'system', 'content': systemPrompt},
                <String, String>{'role': 'user', 'content': userPrompt},
              ],
              'options': <String, Object?>{
                'temperature': 0.1,
                'num_predict': 320,
              },
            }),
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        developer.log(
          'Ollama request failed with HTTP ${response.statusCode}.',
          name: 'OllamaService',
          level: 900,
        );
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<Object?, Object?>) {
        return null;
      }
      final message = decoded['message'];
      if (message is Map<Object?, Object?>) {
        final content = (message['content'] ?? '').toString().trim();
        if (content.isNotEmpty) {
          return content;
        }
      }
      final responseText = (decoded['response'] ?? '').toString().trim();
      return responseText.isEmpty ? null : responseText;
    } catch (error, stackTrace) {
      developer.log(
        'Ollama request failed.',
        name: 'OllamaService',
        error: error,
        stackTrace: stackTrace,
        level: 900,
      );
      return null;
    }
  }
}

Uri _resolveChatEndpoint(Uri endpoint) {
  final normalizedPath = endpoint.path.trim();
  if (normalizedPath.endsWith('/api/chat')) {
    return endpoint;
  }
  if (normalizedPath.isEmpty || normalizedPath == '/') {
    return endpoint.replace(path: '/api/chat');
  }
  if (normalizedPath.endsWith('/')) {
    return endpoint.replace(path: '${normalizedPath}api/chat');
  }
  return endpoint.replace(path: '$normalizedPath/api/chat');
}

Map<String, Object?>? _decodeJson(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final normalized = _extractJsonObject(trimmed);
  if (normalized == null) {
    return null;
  }
  try {
    final decoded = jsonDecode(normalized);
    if (decoded is! Map) {
      return null;
    }
    return decoded.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
  } catch (_) {
    return null;
  }
}

String? _extractJsonObject(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) {
    return null;
  }
  return raw.substring(start, end + 1);
}
