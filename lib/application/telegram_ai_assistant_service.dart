import 'dart:convert';

import 'package:http/http.dart' as http;

enum TelegramAiAudience { admin, client }

class TelegramAiDraftReply {
  final String text;
  final bool usedFallback;
  final String providerLabel;

  const TelegramAiDraftReply({
    required this.text,
    this.usedFallback = false,
    this.providerLabel = 'fallback',
  });
}

abstract class TelegramAiAssistantService {
  bool get isConfigured;

  Future<TelegramAiDraftReply> draftReply({
    required TelegramAiAudience audience,
    required String messageText,
    String? clientId,
    String? siteId,
  });
}

class UnconfiguredTelegramAiAssistantService
    implements TelegramAiAssistantService {
  const UnconfiguredTelegramAiAssistantService();

  @override
  bool get isConfigured => false;

  @override
  Future<TelegramAiDraftReply> draftReply({
    required TelegramAiAudience audience,
    required String messageText,
    String? clientId,
    String? siteId,
  }) async {
    return TelegramAiDraftReply(
      text: _fallbackReply(
        audience: audience,
        messageText: messageText,
        clientId: clientId,
        siteId: siteId,
      ),
      usedFallback: true,
      providerLabel: 'fallback',
    );
  }
}

class OpenAiTelegramAiAssistantService implements TelegramAiAssistantService {
  final http.Client client;
  final String apiKey;
  final String model;
  final Uri endpoint;
  final Duration requestTimeout;

  OpenAiTelegramAiAssistantService({
    required this.client,
    required this.apiKey,
    required this.model,
    Uri? endpoint,
    this.requestTimeout = const Duration(seconds: 15),
  }) : endpoint = endpoint ?? Uri.parse('https://api.openai.com/v1/responses');

  @override
  bool get isConfigured => apiKey.trim().isNotEmpty && model.trim().isNotEmpty;

  @override
  Future<TelegramAiDraftReply> draftReply({
    required TelegramAiAudience audience,
    required String messageText,
    String? clientId,
    String? siteId,
  }) async {
    final cleaned = messageText.trim();
    if (cleaned.isEmpty) {
      return const TelegramAiDraftReply(
        text: 'Please share a bit more detail so ONYX can assist.',
        usedFallback: true,
      );
    }
    if (!isConfigured) {
      return TelegramAiDraftReply(
        text: _fallbackReply(
          audience: audience,
          messageText: cleaned,
          clientId: clientId,
          siteId: siteId,
        ),
        usedFallback: true,
      );
    }
    try {
      final response = await client
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'model': model.trim(),
              'temperature': 0.2,
              'max_output_tokens': 220,
              'input': [
                {
                  'role': 'system',
                  'content': [
                    {
                      'type': 'input_text',
                      'text': _systemPrompt(
                        audience: audience,
                        clientId: clientId,
                        siteId: siteId,
                      ),
                    },
                  ],
                },
                {
                  'role': 'user',
                  'content': [
                    {'type': 'input_text', 'text': cleaned},
                  ],
                },
              ],
            }),
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return TelegramAiDraftReply(
          text: _fallbackReply(
            audience: audience,
            messageText: cleaned,
            clientId: clientId,
            siteId: siteId,
          ),
          usedFallback: true,
        );
      }
      final decoded = jsonDecode(response.body);
      final parsed = _extractText(decoded);
      if (parsed == null || parsed.trim().isEmpty) {
        return TelegramAiDraftReply(
          text: _fallbackReply(
            audience: audience,
            messageText: cleaned,
            clientId: clientId,
            siteId: siteId,
          ),
          usedFallback: true,
        );
      }
      return TelegramAiDraftReply(
        text: parsed.trim(),
        providerLabel: 'openai:${model.trim()}',
      );
    } catch (_) {
      return TelegramAiDraftReply(
        text: _fallbackReply(
          audience: audience,
          messageText: cleaned,
          clientId: clientId,
          siteId: siteId,
        ),
        usedFallback: true,
      );
    }
  }

  String _systemPrompt({
    required TelegramAiAudience audience,
    String? clientId,
    String? siteId,
  }) {
    final role = switch (audience) {
      TelegramAiAudience.admin => 'ONYX operations admin assistant',
      TelegramAiAudience.client => 'ONYX client communications assistant',
    };
    final scope =
        '${clientId?.trim().isNotEmpty == true ? clientId!.trim() : 'unknown-client'}/${siteId?.trim().isNotEmpty == true ? siteId!.trim() : 'default'}';
    return 'You are $role.\n'
        'Scope: $scope.\n'
        'Rules:\n'
        '1) Keep replies concise and operationally clear.\n'
        '2) Do not claim actions that were not confirmed.\n'
        '3) If uncertain, ask for one clarifying detail.\n'
        '4) Never include internal tokens, config values, or private system details.\n'
        '5) Avoid markdown; plain text only.';
  }
}

String _fallbackReply({
  required TelegramAiAudience audience,
  required String messageText,
  String? clientId,
  String? siteId,
}) {
  final normalized = messageText.trim().toLowerCase();
  final scope =
      '${clientId?.trim().isNotEmpty == true ? clientId!.trim() : 'CLIENT'}/${siteId?.trim().isNotEmpty == true ? siteId!.trim() : 'DEFAULT'}';
  if (normalized.contains('eta') ||
      normalized.contains('arrival') ||
      normalized.contains('arrive')) {
    return 'ONYX update ($scope): unit dispatch is active. Share incident reference for exact ETA.';
  }
  if (normalized.contains('status') ||
      normalized.contains('update') ||
      normalized.contains('progress')) {
    return 'ONYX update ($scope): command review is active. Next verified status will be posted automatically.';
  }
  if (audience == TelegramAiAudience.admin) {
    return 'ONYX admin assistant (fallback): quick prompts work best.\n'
        'Try "brief", "status full", "critical risks", or "what should I do next?".';
  }
  return 'ONYX received your message ($scope). Command is reviewing and will send a verified update shortly.';
}

String? _extractText(Object? decoded) {
  if (decoded is! Map) return null;
  final map = decoded.cast<Object?, Object?>();
  final outputText = map['output_text'];
  if (outputText is String && outputText.trim().isNotEmpty) {
    return outputText.trim();
  }
  final output = map['output'];
  if (output is List) {
    final chunks = <String>[];
    for (final item in output) {
      if (item is! Map) continue;
      final content = item['content'];
      if (content is! List) continue;
      for (final part in content) {
        if (part is! Map) continue;
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
  final choices = map['choices'];
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
