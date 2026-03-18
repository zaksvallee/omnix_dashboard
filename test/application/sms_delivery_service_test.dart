import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/sms_delivery_service.dart';

void main() {
  test('unconfigured sms delivery marks all messages as failed', () async {
    const service = UnconfiguredSmsDeliveryService();

    final result = await service.sendMessages(
      messages: const [
        SmsDeliveryMessage(
          messageKey: 'sms-1',
          recipientPhone: '+27820000001',
          body: 'ONYX update',
        ),
      ],
    );

    expect(service.isConfigured, isFalse);
    expect(result.sentCount, 0);
    expect(result.failedCount, 1);
    expect(
      result.failureReasonsByMessageKey['sms-1'],
      'SMS delivery service not configured.',
    );
  });

  test('http sms delivery posts json payload and marks success', () async {
    late Uri requestUri;
    late Map<String, dynamic> payload;
    late Map<String, String> headers;
    final client = MockClient((request) async {
      requestUri = request.url;
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      headers = request.headers;
      return http.Response('{"status":"queued"}', 202);
    });
    final service = HttpSmsDeliveryService(
      client: client,
      provider: 'bulksms',
      endpoint: Uri.parse('https://sms.example.com/send'),
      bearerToken: 'secret-token',
    );

    final result = await service.sendMessages(
      messages: const [
        SmsDeliveryMessage(
          messageKey: 'sms-ok',
          recipientPhone: '+27820000002',
          body: 'ONYX fallback test',
          clientId: 'CLIENT-VALLEE',
          siteId: 'SITE-VALLEE',
        ),
      ],
    );

    expect(service.isConfigured, isTrue);
    expect(service.providerLabel, 'sms:bulksms');
    expect(requestUri.toString(), 'https://sms.example.com/send');
    expect(headers['Authorization'], 'Bearer secret-token');
    expect(payload['provider'], 'bulksms');
    expect(payload['to'], '+27820000002');
    expect(payload['body'], 'ONYX fallback test');
    expect(payload['client_id'], 'CLIENT-VALLEE');
    expect(payload['site_id'], 'SITE-VALLEE');
    expect(result.sentCount, 1);
    expect(result.failedCount, 0);
  });

  test(
    'bulksms delivery posts official json payload with basic auth',
    () async {
      late Uri requestUri;
      late Map<String, dynamic> payload;
      late Map<String, String> headers;
      final client = MockClient((request) async {
        requestUri = request.url;
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        headers = request.headers;
        return http.Response(
          '{"id":"4023457654","type":"SENT","to":"+27820000009"}',
          201,
        );
      });
      final service = BulkSmsDeliveryService(
        client: client,
        credentialIdentity: 'token-id',
        credentialSecret: 'token-secret',
      );

      final result = await service.sendMessages(
        messages: const [
          SmsDeliveryMessage(
            messageKey: 'sms-bulk-ok',
            recipientPhone: '+27820000009',
            body: 'ONYX fallback test',
          ),
        ],
      );

      expect(service.isConfigured, isTrue);
      expect(service.providerLabel, 'sms:bulksms');
      expect(
        requestUri.toString(),
        'https://api.bulksms.com/v1/messages?auto-unicode=true',
      );
      expect(headers['Authorization'], 'Basic dG9rZW4taWQ6dG9rZW4tc2VjcmV0');
      expect(headers['X-Bulksms-Deduplication-Id'], 'sms-bulk-ok');
      expect(payload['to'], '+27820000009');
      expect(payload['body'], 'ONYX fallback test');
      expect(result.sentCount, 1);
      expect(result.failedCount, 0);
    },
  );

  test('http sms delivery returns body error when request fails', () async {
    final client = MockClient((request) async {
      return http.Response('{"error":"blocked"}', 403);
    });
    final service = HttpSmsDeliveryService(
      client: client,
      provider: 'bulksms',
      endpoint: Uri.parse('https://sms.example.com/send'),
    );

    final result = await service.sendMessages(
      messages: const [
        SmsDeliveryMessage(
          messageKey: 'sms-fail',
          recipientPhone: '+27820000003',
          body: 'fail me',
        ),
      ],
    );

    expect(result.sentCount, 0);
    expect(result.failedCount, 1);
    expect(result.failureReasonsByMessageKey['sms-fail'], 'blocked');
  });

  test('bulksms delivery surfaces provider error body', () async {
    final client = MockClient((request) async {
      return http.Response('{"description":"No credits available"}', 402);
    });
    final service = BulkSmsDeliveryService(
      client: client,
      credentialIdentity: 'token-id',
      credentialSecret: 'token-secret',
    );

    final result = await service.sendMessages(
      messages: const [
        SmsDeliveryMessage(
          messageKey: 'sms-bulk-fail',
          recipientPhone: '+27820000010',
          body: 'fail me',
        ),
      ],
    );

    expect(result.sentCount, 0);
    expect(result.failedCount, 1);
    expect(
      result.failureReasonsByMessageKey['sms-bulk-fail'],
      'No credits available',
    );
  });
}
