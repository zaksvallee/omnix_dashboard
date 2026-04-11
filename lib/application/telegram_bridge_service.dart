import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class TelegramBridgeMessage {
  final String messageKey;
  final String chatId;
  final int? messageThreadId;
  final String text;
  final List<int>? photoBytes;
  final String? photoFilename;
  final Map<String, Object?>? replyMarkup;
  final String? parseMode;

  const TelegramBridgeMessage({
    required this.messageKey,
    required this.chatId,
    this.messageThreadId,
    required this.text,
    this.photoBytes,
    this.photoFilename,
    this.replyMarkup,
    this.parseMode,
  });

  bool get isPhoto => photoBytes != null && photoBytes!.isNotEmpty;
}

class TelegramBridgeInboundMessage {
  final int updateId;
  final String? callbackQueryId;
  final int? messageId;
  final String chatId;
  final String chatType;
  final String? chatTitle;
  final int? messageThreadId;
  final int? replyToMessageId;
  final String? replyToText;
  final int? fromUserId;
  final String? fromUsername;
  final bool fromIsBot;
  final String text;
  final DateTime? sentAtUtc;

  const TelegramBridgeInboundMessage({
    required this.updateId,
    this.callbackQueryId,
    this.messageId,
    required this.chatId,
    required this.chatType,
    this.chatTitle,
    this.messageThreadId,
    this.replyToMessageId,
    this.replyToText,
    this.fromUserId,
    this.fromUsername,
    this.fromIsBot = false,
    required this.text,
    this.sentAtUtc,
  });
}

class TelegramBridgeSendResult {
  final List<TelegramBridgeMessage> sent;
  final List<TelegramBridgeMessage> failed;
  final Map<String, String> failureReasonsByMessageKey;
  final Map<String, int> telegramMessageIdsByMessageKey;

  const TelegramBridgeSendResult({
    required this.sent,
    required this.failed,
    this.failureReasonsByMessageKey = const <String, String>{},
    this.telegramMessageIdsByMessageKey = const <String, int>{},
  });

  int get sentCount => sent.length;
  int get failedCount => failed.length;
}

abstract class TelegramBridgeService {
  bool get isConfigured;

  Future<TelegramBridgeSendResult> sendMessages({
    required List<TelegramBridgeMessage> messages,
  });

  Future<List<TelegramBridgeInboundMessage>> fetchUpdates({
    int? offset,
    int limit = 30,
    int timeoutSeconds = 0,
  });

  Future<bool> answerCallbackQuery({
    required String callbackQueryId,
    String? text,
  });

  Future<void> sendVoiceMessage(
    String chatId,
    Uint8List audioBytes, {
    int? messageThreadId,
  });
}

class UnconfiguredTelegramBridgeService implements TelegramBridgeService {
  const UnconfiguredTelegramBridgeService();

  @override
  bool get isConfigured => false;

  @override
  Future<TelegramBridgeSendResult> sendMessages({
    required List<TelegramBridgeMessage> messages,
  }) async {
    return TelegramBridgeSendResult(
      sent: const [],
      failed: messages,
      failureReasonsByMessageKey: {
        for (final message in messages)
          message.messageKey: 'Telegram bridge not configured.',
      },
    );
  }

  @override
  Future<List<TelegramBridgeInboundMessage>> fetchUpdates({
    int? offset,
    int limit = 30,
    int timeoutSeconds = 0,
  }) async {
    return const <TelegramBridgeInboundMessage>[];
  }

  @override
  Future<bool> answerCallbackQuery({
    required String callbackQueryId,
    String? text,
  }) async {
    return false;
  }

  @override
  Future<void> sendVoiceMessage(
    String chatId,
    Uint8List audioBytes, {
    int? messageThreadId,
  }) async {}
}

class HttpTelegramBridgeService implements TelegramBridgeService {
  final http.Client client;
  final String botToken;
  final Uri? apiBaseUri;
  final bool disableInboundPolling;
  final Duration requestTimeout;

  const HttpTelegramBridgeService({
    required this.client,
    required this.botToken,
    this.apiBaseUri,
    this.disableInboundPolling = false,
    this.requestTimeout = const Duration(seconds: 12),
  });

  @override
  bool get isConfigured {
    return botToken.trim().isNotEmpty;
  }

  @override
  Future<TelegramBridgeSendResult> sendMessages({
    required List<TelegramBridgeMessage> messages,
  }) async {
    if (messages.isEmpty) {
      return const TelegramBridgeSendResult(sent: [], failed: []);
    }
    if (!isConfigured) {
      return TelegramBridgeSendResult(sent: const [], failed: messages);
    }
    final endpoint = _buildEndpoint('sendMessage');
    final sent = <TelegramBridgeMessage>[];
    final failed = <TelegramBridgeMessage>[];
    final failureReasons = <String, String>{};
    final telegramMessageIds = <String, int>{};
    for (final message in messages) {
      final chatId = message.chatId.trim();
      if (chatId.isEmpty) {
        failed.add(message);
        failureReasons[message.messageKey] = 'Missing Telegram chat_id.';
        continue;
      }
      try {
        final response = message.isPhoto
            ? await _sendPhotoMessage(message).timeout(requestTimeout)
            : await client
                  .post(
                    endpoint,
                    headers: const {
                      'Content-Type': 'application/json',
                      'Accept': 'application/json',
                    },
                    body: jsonEncode({
                      'chat_id': chatId,
                      if (message.messageThreadId != null)
                        'message_thread_id': message.messageThreadId,
                      'text': message.text,
                      if ((message.parseMode ?? '').trim().isNotEmpty)
                        'parse_mode': message.parseMode!.trim(),
                      if (message.replyMarkup != null)
                        'reply_markup': message.replyMarkup,
                      'disable_web_page_preview': true,
                    }),
                  )
                  .timeout(requestTimeout);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          failed.add(message);
          failureReasons[message.messageKey] =
              _extractTelegramErrorDescription(response.body) ??
              'HTTP ${response.statusCode}';
          continue;
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map || decoded['ok'] != true) {
          failed.add(message);
          failureReasons[message.messageKey] =
              _extractTelegramErrorDescription(response.body) ??
              'Telegram response invalid';
          continue;
        }
        final resultPayload = decoded['result'];
        if (resultPayload is Map) {
          final messageId = _asInt(resultPayload['message_id']);
          if (messageId != null && messageId > 0) {
            telegramMessageIds[message.messageKey] = messageId;
          }
        }
        sent.add(message);
      } catch (error) {
        failed.add(message);
        failureReasons[message.messageKey] = error.toString();
      }
    }
    return TelegramBridgeSendResult(
      sent: sent,
      failed: failed,
      failureReasonsByMessageKey: failureReasons,
      telegramMessageIdsByMessageKey: telegramMessageIds,
    );
  }

  Future<http.Response> _sendPhotoMessage(TelegramBridgeMessage message) async {
    final endpoint = _buildEndpoint('sendPhoto');
    final request = http.MultipartRequest('POST', endpoint)
      ..fields['chat_id'] = message.chatId.trim();
    if (message.messageThreadId != null) {
      request.fields['message_thread_id'] = '${message.messageThreadId!}';
    }
    if (message.text.trim().isNotEmpty) {
      request.fields['caption'] = message.text.trim();
    }
    if ((message.parseMode ?? '').trim().isNotEmpty) {
      request.fields['parse_mode'] = message.parseMode!.trim();
    }
    if (message.replyMarkup != null) {
      request.fields['reply_markup'] = jsonEncode(message.replyMarkup);
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'photo',
        message.photoBytes!,
        filename: (message.photoFilename ?? '').trim().isEmpty
            ? 'snapshot.jpg'
            : message.photoFilename!.trim(),
      ),
    );
    final streamed = await client.send(request);
    return http.Response.fromStream(streamed);
  }

  @override
  Future<List<TelegramBridgeInboundMessage>> fetchUpdates({
    int? offset,
    int limit = 30,
    int timeoutSeconds = 0,
  }) async {
    if (!isConfigured || disableInboundPolling) {
      return const <TelegramBridgeInboundMessage>[];
    }
    final query = <String, String>{
      'limit': '${limit.clamp(1, 100)}',
      'timeout': '${timeoutSeconds.clamp(0, 30)}',
      'allowed_updates': jsonEncode(const ['message', 'callback_query']),
    };
    if (offset != null) {
      query['offset'] = '$offset';
    }
    final endpoint = _buildEndpoint('getUpdates', queryParameters: query);
    final response = await client
        .get(endpoint, headers: const {'Accept': 'application/json'})
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const <TelegramBridgeInboundMessage>[];
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['ok'] != true) {
      return const <TelegramBridgeInboundMessage>[];
    }
    final result = decoded['result'];
    if (result is! List) {
      return const <TelegramBridgeInboundMessage>[];
    }
    final updates = <TelegramBridgeInboundMessage>[];
    for (final item in result) {
      if (item is! Map) continue;
      final row = item.cast<Object?, Object?>();
      final updateId = _asInt(row['update_id']);
      if (updateId == null) continue;
      final messageRaw = row['message'];
      Map<Object?, Object?>? message;
      String? callbackQueryId;
      String text = '';
      Map<Object?, Object?> from = const <Object?, Object?>{};
      if (messageRaw is Map) {
        message = messageRaw.cast<Object?, Object?>();
        text = (message['text'] ?? '').toString().trim();
        final fromRaw = message['from'];
        from = fromRaw is Map
            ? fromRaw.cast<Object?, Object?>()
            : const <Object?, Object?>{};
      } else {
        final callbackRaw = row['callback_query'];
        if (callbackRaw is! Map) continue;
        final callback = callbackRaw.cast<Object?, Object?>();
        callbackQueryId = (callback['id'] ?? '').toString().trim();
        if (callbackQueryId.isEmpty) continue;
        text = (callback['data'] ?? '').toString().trim();
        final callbackFromRaw = callback['from'];
        from = callbackFromRaw is Map
            ? callbackFromRaw.cast<Object?, Object?>()
            : const <Object?, Object?>{};
        final callbackMessageRaw = callback['message'];
        if (callbackMessageRaw is! Map) continue;
        message = callbackMessageRaw.cast<Object?, Object?>();
      }
      if (text.isEmpty) continue;
      final chatRaw = message['chat'];
      if (chatRaw is! Map) continue;
      final chat = chatRaw.cast<Object?, Object?>();
      final chatId = (chat['id'] ?? '').toString().trim();
      if (chatId.isEmpty) continue;
      final replyToRaw = message['reply_to_message'];
      final replyTo = replyToRaw is Map
          ? replyToRaw.cast<Object?, Object?>()
          : const <Object?, Object?>{};
      final sentAtSeconds = _asInt(message['date']);
      updates.add(
        TelegramBridgeInboundMessage(
          updateId: updateId,
          callbackQueryId: callbackQueryId,
          messageId: _asInt(message['message_id']),
          chatId: chatId,
          chatType: (chat['type'] ?? '').toString().trim(),
          chatTitle: (chat['title'] ?? '').toString().trim().isEmpty
              ? null
              : (chat['title'] ?? '').toString().trim(),
          messageThreadId: _asInt(message['message_thread_id']),
          replyToMessageId: _asInt(replyTo['message_id']),
          replyToText: (replyTo['text'] ?? '').toString().trim().isEmpty
              ? null
              : (replyTo['text'] ?? '').toString().trim(),
          fromUserId: _asInt(from['id']),
          fromUsername: (from['username'] ?? '').toString().trim().isEmpty
              ? null
              : (from['username'] ?? '').toString().trim(),
          fromIsBot: from['is_bot'] == true,
          text: text,
          sentAtUtc: sentAtSeconds == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  sentAtSeconds * 1000,
                  isUtc: true,
                ),
        ),
      );
    }
    updates.sort((a, b) => a.updateId.compareTo(b.updateId));
    return updates;
  }

  @override
  Future<bool> answerCallbackQuery({
    required String callbackQueryId,
    String? text,
  }) async {
    if (!isConfigured || callbackQueryId.trim().isEmpty) {
      return false;
    }
    final endpoint = _buildEndpoint('answerCallbackQuery');
    try {
      final response = await client
          .post(
            endpoint,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'callback_query_id': callbackQueryId.trim(),
              if ((text ?? '').trim().isNotEmpty) 'text': text!.trim(),
            }),
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final decoded = jsonDecode(response.body);
      return decoded is Map && decoded['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> sendVoiceMessage(
    String chatId,
    Uint8List audioBytes, {
    int? messageThreadId,
  }) async {
    if (!isConfigured || chatId.trim().isEmpty || audioBytes.isEmpty) {
      developer.log(
        '[ONYX] TelegramBridge: sendVoice skipped configured=$isConfigured '
        'chat_empty=${chatId.trim().isEmpty} bytes=${audioBytes.length}',
        name: 'ElevenLabs',
      );
      return;
    }
    try {
      developer.log(
        '[ONYX] TelegramBridge: sendVoice start chat=${chatId.trim()} '
        'thread=${messageThreadId ?? 0} bytes=${audioBytes.length}',
        name: 'ElevenLabs',
      );
      final endpoint = _buildEndpoint('sendVoice');
      final request = http.MultipartRequest('POST', endpoint)
        ..fields['chat_id'] = chatId.trim();
      if (messageThreadId != null) {
        request.fields['message_thread_id'] = '$messageThreadId';
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          'voice',
          audioBytes,
          filename: 'onyx-status.mp3',
        ),
      );
      final streamed = await client.send(request).timeout(requestTimeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        developer.log(
          '[ONYX] TelegramBridge: sendVoice failed HTTP ${response.statusCode} '
          '${response.body}',
          name: 'ElevenLabs',
        );
        return;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['ok'] != true) {
        developer.log(
          '[ONYX] TelegramBridge: sendVoice invalid response ${response.body}',
          name: 'ElevenLabs',
        );
        return;
      }
      final resultPayload = decoded['result'];
      final messageId = resultPayload is Map
          ? _asInt(resultPayload['message_id'])
          : null;
      developer.log(
        '[ONYX] TelegramBridge: sendVoice ok message_id=${messageId ?? 0}',
        name: 'ElevenLabs',
      );
    } catch (error, stackTrace) {
      developer.log(
        '[ONYX] TelegramBridge: sendVoice exception',
        name: 'ElevenLabs',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  String? _extractTelegramErrorDescription(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final description = (decoded['description'] ?? '').toString().trim();
        if (description.isNotEmpty) {
          return description;
        }
      }
    } catch (_) {
      // Ignore decode errors and fall back to generic labels.
    }
    return null;
  }

  Uri _buildEndpoint(String method, {Map<String, String>? queryParameters}) {
    final normalizedToken = botToken.trim();
    final normalizedMethod = method.trim();
    final baseUri = apiBaseUri;
    if (baseUri == null) {
      return Uri.https(
        'api.telegram.org',
        '/bot$normalizedToken/$normalizedMethod',
        queryParameters,
      );
    }
    final basePath = baseUri.path.trim();
    final normalizedBasePath = basePath.isEmpty || basePath == '/'
        ? ''
        : (basePath.endsWith('/')
              ? basePath.substring(0, basePath.length - 1)
              : basePath);
    return baseUri.replace(
      path: '$normalizedBasePath/bot$normalizedToken/$normalizedMethod',
      queryParameters: queryParameters?.isEmpty == true
          ? null
          : queryParameters,
      fragment: null,
    );
  }
}
