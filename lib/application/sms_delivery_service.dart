import 'dart:convert';

import 'package:http/http.dart' as http;

class SmsDeliveryMessage {
  final String messageKey;
  final String recipientPhone;
  final String body;
  final String? clientId;
  final String? siteId;

  const SmsDeliveryMessage({
    required this.messageKey,
    required this.recipientPhone,
    required this.body,
    this.clientId,
    this.siteId,
  });
}

class SmsDeliverySendResult {
  final List<SmsDeliveryMessage> sent;
  final List<SmsDeliveryMessage> failed;
  final Map<String, String> failureReasonsByMessageKey;

  const SmsDeliverySendResult({
    required this.sent,
    required this.failed,
    this.failureReasonsByMessageKey = const <String, String>{},
  });

  int get sentCount => sent.length;
  int get failedCount => failed.length;
}

abstract class SmsDeliveryService {
  bool get isConfigured;
  String get providerLabel;

  Future<SmsDeliverySendResult> sendMessages({
    required List<SmsDeliveryMessage> messages,
  });
}

class UnconfiguredSmsDeliveryService implements SmsDeliveryService {
  const UnconfiguredSmsDeliveryService();

  @override
  bool get isConfigured => false;

  @override
  String get providerLabel => 'sms:unconfigured';

  @override
  Future<SmsDeliverySendResult> sendMessages({
    required List<SmsDeliveryMessage> messages,
  }) async {
    return SmsDeliverySendResult(
      sent: const [],
      failed: messages,
      failureReasonsByMessageKey: {
        for (final message in messages)
          message.messageKey: 'SMS delivery service not configured.',
      },
    );
  }
}

class BulkSmsDeliveryService implements SmsDeliveryService {
  final http.Client client;
  final String credentialIdentity;
  final String credentialSecret;
  final Uri endpoint;
  final Duration requestTimeout;

  BulkSmsDeliveryService({
    required this.client,
    required this.credentialIdentity,
    required this.credentialSecret,
    Uri? endpoint,
    this.requestTimeout = const Duration(seconds: 12),
  }) : endpoint =
           endpoint ??
           Uri.parse('https://api.bulksms.com/v1/messages?auto-unicode=true');

  @override
  bool get isConfigured {
    return credentialIdentity.trim().isNotEmpty &&
        credentialSecret.trim().isNotEmpty;
  }

  @override
  String get providerLabel => 'sms:bulksms';

  @override
  Future<SmsDeliverySendResult> sendMessages({
    required List<SmsDeliveryMessage> messages,
  }) async {
    if (messages.isEmpty) {
      return const SmsDeliverySendResult(sent: [], failed: []);
    }
    if (!isConfigured) {
      return SmsDeliverySendResult(
        sent: const [],
        failed: messages,
        failureReasonsByMessageKey: {
          for (final message in messages)
            message.messageKey: 'BulkSMS credentials are not configured.',
        },
      );
    }

    final sent = <SmsDeliveryMessage>[];
    final failed = <SmsDeliveryMessage>[];
    final failureReasons = <String, String>{};

    for (final message in messages) {
      final phone = message.recipientPhone.trim();
      if (phone.isEmpty) {
        failed.add(message);
        failureReasons[message.messageKey] = 'Missing SMS phone number.';
        continue;
      }
      final deduplicationId = _deduplicationIdFor(message.messageKey);
      try {
        final response = await client
            .post(
              endpoint,
              headers: <String, String>{
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': _basicAuthorizationHeader(),
                'X-Bulksms-Deduplication-Id': deduplicationId,
              },
              body: jsonEncode({'to': phone, 'body': message.body}),
            )
            .timeout(requestTimeout);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          failed.add(message);
          failureReasons[message.messageKey] =
              _extractSmsFailureReason(response.body) ??
              'HTTP ${response.statusCode}';
          continue;
        }
        sent.add(message);
      } catch (error) {
        failed.add(message);
        failureReasons[message.messageKey] = error.toString();
      }
    }

    return SmsDeliverySendResult(
      sent: sent,
      failed: failed,
      failureReasonsByMessageKey: failureReasons,
    );
  }

  String _basicAuthorizationHeader() {
    final raw = '${credentialIdentity.trim()}:${credentialSecret.trim()}';
    return 'Basic ${base64Encode(utf8.encode(raw))}';
  }

  static String _deduplicationIdFor(String messageKey) {
    final sanitized = messageKey.trim().replaceAll(
      RegExp(r'[^A-Za-z0-9._-]+'),
      '-',
    );
    if (sanitized.isEmpty) {
      return 'onyx-sms';
    }
    if (sanitized.length <= 64) {
      return sanitized;
    }
    return sanitized.substring(0, 64);
  }
}

class HttpSmsDeliveryService implements SmsDeliveryService {
  final http.Client client;
  final String provider;
  final Uri endpoint;
  final String? bearerToken;
  final Duration requestTimeout;

  const HttpSmsDeliveryService({
    required this.client,
    required this.provider,
    required this.endpoint,
    this.bearerToken,
    this.requestTimeout = const Duration(seconds: 12),
  });

  @override
  bool get isConfigured => provider.trim().isNotEmpty;

  @override
  String get providerLabel => 'sms:${provider.trim().toLowerCase()}';

  @override
  Future<SmsDeliverySendResult> sendMessages({
    required List<SmsDeliveryMessage> messages,
  }) async {
    if (messages.isEmpty) {
      return const SmsDeliverySendResult(sent: [], failed: []);
    }
    final sent = <SmsDeliveryMessage>[];
    final failed = <SmsDeliveryMessage>[];
    final failureReasons = <String, String>{};

    for (final message in messages) {
      final phone = message.recipientPhone.trim();
      if (phone.isEmpty) {
        failed.add(message);
        failureReasons[message.messageKey] = 'Missing SMS phone number.';
        continue;
      }
      try {
        final response = await client
            .post(
              endpoint,
              headers: <String, String>{
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                if ((bearerToken ?? '').trim().isNotEmpty)
                  'Authorization': 'Bearer ${bearerToken!.trim()}',
              },
              body: jsonEncode({
                'provider': provider.trim(),
                'message_key': message.messageKey,
                'to': phone,
                'body': message.body,
                if ((message.clientId ?? '').trim().isNotEmpty)
                  'client_id': message.clientId!.trim(),
                if ((message.siteId ?? '').trim().isNotEmpty)
                  'site_id': message.siteId!.trim(),
              }),
            )
            .timeout(requestTimeout);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          failed.add(message);
          failureReasons[message.messageKey] =
              _extractSmsFailureReason(response.body) ??
              'HTTP ${response.statusCode}';
          continue;
        }
        sent.add(message);
      } catch (error) {
        failed.add(message);
        failureReasons[message.messageKey] = error.toString();
      }
    }
    return SmsDeliverySendResult(
      sent: sent,
      failed: failed,
      failureReasonsByMessageKey: failureReasons,
    );
  }
}

String? _extractSmsFailureReason(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) {
      for (final key in const ['error', 'message', 'detail', 'description']) {
        final value = decoded[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
    }
  } catch (_) {
    // Fall through to raw body.
  }
  return trimmed;
}
