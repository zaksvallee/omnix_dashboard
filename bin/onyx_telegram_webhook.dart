// ONYX Telegram Webhook Receiver — standalone pure-Dart HTTP server.
//
// Nginx terminates TLS and reverse-proxies to this process on 127.0.0.1:8443.
//
// Run with:
//   dart run bin/onyx_telegram_webhook.dart
//
// Environment variables:
//   ONYX_SUPABASE_URL               Supabase project URL          (required)
//   ONYX_SUPABASE_SERVICE_KEY       Service-role key — bypasses RLS (required)
//   ONYX_TELEGRAM_WEBHOOK_SECRET    Validates X-Telegram-Bot-Api-Secret-Token (optional)
//   ONYX_WEBHOOK_HOST               Bind address (default: 127.0.0.1)
//   ONYX_WEBHOOK_PORT               Bind port    (default: 8443)

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase/supabase.dart';

const String _defaultHost = String.fromEnvironment(
  'ONYX_WEBHOOK_HOST',
  defaultValue: '127.0.0.1',
);
const int _defaultPort = int.fromEnvironment(
  'ONYX_WEBHOOK_PORT',
  defaultValue: 8443,
);

Future<void> main() async {
  final supabaseUrl = Platform.environment['ONYX_SUPABASE_URL'] ?? '';
  final serviceKey = Platform.environment['ONYX_SUPABASE_SERVICE_KEY'] ?? '';
  final webhookSecret =
      Platform.environment['ONYX_TELEGRAM_WEBHOOK_SECRET'] ?? '';
  final host = Platform.environment['ONYX_WEBHOOK_HOST'] ?? _defaultHost;
  final port =
      int.tryParse(Platform.environment['ONYX_WEBHOOK_PORT'] ?? '') ??
      _defaultPort;

  if (supabaseUrl.isEmpty || serviceKey.isEmpty) {
    stderr.writeln(
      '[ONYX] ERROR: ONYX_SUPABASE_URL and ONYX_SUPABASE_SERVICE_KEY are required.',
    );
    exit(1);
  }

  final supabase = SupabaseClient(supabaseUrl, serviceKey);

  final server = await HttpServer.bind(
    InternetAddress(host, type: InternetAddressType.IPv4),
    port,
  );

  stdout.writeln('[ONYX] Telegram webhook receiver listening on $host:$port');
  if (webhookSecret.isNotEmpty) {
    stdout.writeln('[ONYX] Webhook secret validation: enabled');
  } else {
    stdout.writeln('[ONYX] Webhook secret validation: disabled (no secret set)');
  }

  await for (final request in server) {
    // Handle each request in the background — never block the accept loop.
    unawaited(_handleRequest(request, supabase, webhookSecret));
  }
}

Future<void> _handleRequest(
  HttpRequest request,
  SupabaseClient supabase,
  String webhookSecret,
) async {
  // Always respond 200 to Telegram, even on error — Telegram retries
  // endlessly on non-2xx, which would flood the queue.
  try {
    if (request.method == 'GET' && request.uri.path == '/health') {
      _respond(request, 200, '{"status":"ok"}');
      return;
    }

    if (request.method != 'POST' ||
        request.uri.path != '/telegram/webhook') {
      _respond(request, 404, '{"error":"not found"}');
      return;
    }

    // Validate secret token if configured.
    if (webhookSecret.isNotEmpty) {
      final token =
          request.headers.value('x-telegram-bot-api-secret-token') ?? '';
      if (token != webhookSecret) {
        // Respond 200 anyway — returning 403 causes Telegram to retry.
        stderr.writeln(
          '[ONYX] Rejected update — invalid secret token.',
        );
        _respond(request, 200, '{"ok":true}');
        return;
      }
    }

    // Validate Content-Type.
    final contentType = request.headers.contentType;
    final isJson =
        contentType != null &&
        contentType.mimeType == ContentType.json.mimeType;
    if (!isJson) {
      stderr.writeln(
        '[ONYX] Rejected update — Content-Type is not application/json '
        '(got: ${contentType?.mimeType ?? 'none'}).',
      );
      _respond(request, 200, '{"ok":true}');
      return;
    }

    // Read body with a hard cap to guard against oversized payloads.
    final body = await _readBody(request, maxBytes: 512 * 1024);
    if (body == null) {
      stderr.writeln('[ONYX] Rejected update — body exceeded size limit.');
      _respond(request, 200, '{"ok":true}');
      return;
    }

    // Parse JSON.
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (error) {
      stderr.writeln('[ONYX] Rejected update — invalid JSON: $error');
      _respond(request, 200, '{"ok":true}');
      return;
    }

    if (decoded is! Map) {
      stderr.writeln('[ONYX] Rejected update — JSON root is not an object.');
      _respond(request, 200, '{"ok":true}');
      return;
    }

    final update = decoded.cast<String, Object?>();
    final updateId = _extractUpdateId(update);
    final chatId = _extractChatId(update);

    // Respond to Telegram immediately — persistence happens async.
    _respond(request, 200, '{"ok":true}');

    // Insert into Supabase in the background.
    unawaited(_persistUpdate(supabase, updateId, chatId, update));
  } catch (error, stackTrace) {
    // Last-resort catch — log and swallow. We must not let any error
    // propagate without first having sent a 200 response to Telegram.
    stderr.writeln('[ONYX] Unhandled error in request handler: $error');
    stderr.writeln(stackTrace);
    try {
      _respond(request, 200, '{"ok":true}');
    } catch (_) {
      // Response already sent or connection closed — nothing to do.
    }
  }
}

Future<void> _persistUpdate(
  SupabaseClient supabase,
  int? updateId,
  String? chatId,
  Map<String, Object?> update,
) async {
  try {
    await supabase.from('telegram_inbound_updates').insert(<String, Object?>{
      'update_id': updateId,
      'chat_id': chatId,
      'update_json': update,
      'processed': false,
    });
    stdout.writeln(
      '[ONYX] Stored update${updateId != null ? ' #$updateId' : ''}'
      '${chatId != null ? ' chat=$chatId' : ''}',
    );
  } catch (error, stackTrace) {
    stderr.writeln('[ONYX] Failed to persist update to Supabase: $error');
    stderr.writeln(stackTrace);
  }
}

void _respond(HttpRequest request, int statusCode, String body) {
  try {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(body);
    unawaited(request.response.close());
  } catch (_) {
    // Connection may have been closed by the client already.
  }
}

/// Reads the request body up to [maxBytes].
/// Returns null if the body exceeds the limit or a read error occurs.
Future<String?> _readBody(HttpRequest request, {required int maxBytes}) async {
  try {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      builder.add(chunk);
      if (builder.length > maxBytes) {
        return null;
      }
    }
    return utf8.decode(builder.takeBytes(), allowMalformed: true);
  } catch (_) {
    return null;
  }
}

/// Extracts update_id from the Telegram update object.
int? _extractUpdateId(Map<String, Object?> update) {
  final raw = update['update_id'];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}

/// Extracts chat_id from the most common Telegram update shapes.
///
/// Telegram update types and their chat path:
///   message / edited_message / channel_post / edited_channel_post → .chat.id
///   callback_query → .message.chat.id
///   my_chat_member / chat_member / chat_join_request → .chat.id
String? _extractChatId(Map<String, Object?> update) {
  for (final key in const <String>[
    'message',
    'edited_message',
    'channel_post',
    'edited_channel_post',
    'my_chat_member',
    'chat_member',
    'chat_join_request',
  ]) {
    final entry = update[key];
    if (entry is Map) {
      final chat = entry['chat'];
      if (chat is Map) {
        final id = chat['id'];
        if (id != null) return id.toString();
      }
    }
  }
  // callback_query → message → chat → id
  final cbq = update['callback_query'];
  if (cbq is Map) {
    final msg = cbq['message'];
    if (msg is Map) {
      final chat = msg['chat'];
      if (chat is Map) {
        final id = chat['id'];
        if (id != null) return id.toString();
      }
    }
  }
  return null;
}
