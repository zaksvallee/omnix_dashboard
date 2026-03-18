import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/voip_call_service.dart';

void main() {
  test('unconfigured voip service declines call staging', () async {
    const service = UnconfiguredVoipCallService();

    final result = await service.stageCall(
      request: const VoipCallRequest(
        callKey: 'call-1',
        recipientPhone: '+27820000004',
        contactName: 'Sipho Ndlovu',
        summary: 'Guard welfare check',
      ),
    );

    expect(service.isConfigured, isFalse);
    expect(result.accepted, isFalse);
    expect(result.statusLabel, 'VoIP provider not configured');
  });

  test('http voip service posts call payload and marks accepted', () async {
    late Uri requestUri;
    late Map<String, dynamic> payload;
    final client = MockClient((request) async {
      requestUri = request.url;
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{"status":"queued"}', 202);
    });
    final service = HttpVoipCallService(
      client: client,
      provider: 'asterisk',
      endpoint: Uri.parse('https://voip.example.com/calls'),
      bearerToken: 'voip-token',
    );

    final result = await service.stageCall(
      request: const VoipCallRequest(
        callKey: 'call-ok',
        recipientPhone: '+27820000005',
        contactName: 'Nomsa Khumalo',
        clientId: 'CLIENT-VALLEE',
        siteId: 'SITE-VALLEE',
        incidentReference: 'INC-22',
        summary: 'Safe-word welfare verification',
      ),
    );

    expect(service.isConfigured, isTrue);
    expect(service.providerLabel, 'voip:asterisk');
    expect(requestUri.toString(), 'https://voip.example.com/calls');
    expect(payload['provider'], 'asterisk');
    expect(payload['to'], '+27820000005');
    expect(payload['contact_name'], 'Nomsa Khumalo');
    expect(payload['incident_reference'], 'INC-22');
    expect(result.accepted, isTrue);
    expect(result.statusLabel, 'VoIP call staged');
  });

  test(
    'asterisk ari service posts originate request with basic auth',
    () async {
      late Uri requestUri;
      late Map<String, dynamic> payload;
      late Map<String, String> headers;
      final client = MockClient((request) async {
        requestUri = request.url;
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        headers = request.headers;
        return http.Response('{"id":"call-ok"}', 200);
      });
      final service = AsteriskAriVoipCallService(
        client: client,
        baseUri: Uri.parse('https://pbx.example.com/ari'),
        username: 'ari-user',
        password: 'ari-pass',
        sipHost: 'onyx-trunk',
        dialplanContext: 'from-internal',
        dialplanExtension: 's',
        callerId: 'ONYX <1000>',
      );

      final result = await service.stageCall(
        request: const VoipCallRequest(
          callKey: 'call-ari-1',
          recipientPhone: '+27820000007',
          contactName: 'Zanele Dube',
          clientId: 'CLIENT-VALLEE',
          siteId: 'SITE-VALLEE',
          incidentReference: 'INC-77',
          summary: 'Welfare check',
        ),
      );

      expect(service.isConfigured, isTrue);
      expect(service.providerLabel, 'voip:asterisk');
      expect(requestUri.path, '/ari/channels');
      expect(
        requestUri.queryParameters['endpoint'],
        'PJSIP/+27820000007@onyx-trunk',
      );
      expect(requestUri.queryParameters['context'], 'from-internal');
      expect(requestUri.queryParameters['extension'], 's');
      expect(requestUri.queryParameters['priority'], '1');
      expect(requestUri.queryParameters['callerId'], 'ONYX <1000>');
      expect(requestUri.queryParameters['channelId'], 'call-ari-1');
      expect(headers['Authorization'], 'Basic YXJpLXVzZXI6YXJpLXBhc3M=');
      final variables = payload['variables'] as Map<String, dynamic>;
      expect(variables['ONYX_CONTACT_NAME'], 'Zanele Dube');
      expect(variables['ONYX_SITE_ID'], 'SITE-VALLEE');
      expect(result.accepted, isTrue);
      expect(result.statusLabel, 'Asterisk call staged');
    },
  );

  test('http voip service surfaces failure detail', () async {
    final client = MockClient((request) async {
      return http.Response('{"message":"provider offline"}', 503);
    });
    final service = HttpVoipCallService(
      client: client,
      provider: 'asterisk',
      endpoint: Uri.parse('https://voip.example.com/calls'),
    );

    final result = await service.stageCall(
      request: const VoipCallRequest(
        callKey: 'call-fail',
        recipientPhone: '+27820000006',
        contactName: 'Johan van Zyl',
        summary: 'Escalation call',
      ),
    );

    expect(result.accepted, isFalse);
    expect(result.statusLabel, 'VoIP stage failed');
    expect(result.detail, 'provider offline');
  });

  test('asterisk ari service surfaces provider failure detail', () async {
    final client = MockClient((request) async {
      return http.Response('{"message":"extension unavailable"}', 500);
    });
    final service = AsteriskAriVoipCallService(
      client: client,
      baseUri: Uri.parse('https://pbx.example.com/ari'),
      username: 'ari-user',
      password: 'ari-pass',
      dialplanContext: 'from-internal',
      dialplanExtension: 's',
    );

    final result = await service.stageCall(
      request: const VoipCallRequest(
        callKey: 'call-ari-fail',
        recipientPhone: '+27820000008',
        contactName: 'Sipho Ndlovu',
        summary: 'Escalation call',
      ),
    );

    expect(result.accepted, isFalse);
    expect(result.statusLabel, 'Asterisk originate failed');
    expect(result.detail, 'extension unavailable');
  });
}
