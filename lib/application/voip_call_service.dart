import 'dart:convert';

import 'package:http/http.dart' as http;

class VoipCallRequest {
  final String callKey;
  final String recipientPhone;
  final String contactName;
  final String? clientId;
  final String? siteId;
  final String? incidentReference;
  final String summary;

  const VoipCallRequest({
    required this.callKey,
    required this.recipientPhone,
    required this.contactName,
    this.clientId,
    this.siteId,
    this.incidentReference,
    required this.summary,
  });
}

class VoipCallResult {
  final bool accepted;
  final String providerLabel;
  final String statusLabel;
  final String? detail;

  const VoipCallResult({
    required this.accepted,
    required this.providerLabel,
    required this.statusLabel,
    this.detail,
  });
}

abstract class VoipCallService {
  bool get isConfigured;
  String get providerLabel;

  Future<VoipCallResult> stageCall({required VoipCallRequest request});
}

class UnconfiguredVoipCallService implements VoipCallService {
  const UnconfiguredVoipCallService();

  @override
  bool get isConfigured => false;

  @override
  String get providerLabel => 'voip:unconfigured';

  @override
  Future<VoipCallResult> stageCall({required VoipCallRequest request}) async {
    return const VoipCallResult(
      accepted: false,
      providerLabel: 'voip:unconfigured',
      statusLabel: 'VoIP provider not configured',
    );
  }
}

class AsteriskAriVoipCallService implements VoipCallService {
  final http.Client client;
  final Uri baseUri;
  final String username;
  final String password;
  final String endpointTechnology;
  final String? sipHost;
  final String dialplanContext;
  final String dialplanExtension;
  final int dialplanPriority;
  final String? callerId;
  final Duration requestTimeout;

  const AsteriskAriVoipCallService({
    required this.client,
    required this.baseUri,
    required this.username,
    required this.password,
    this.endpointTechnology = 'PJSIP',
    this.sipHost,
    required this.dialplanContext,
    required this.dialplanExtension,
    this.dialplanPriority = 1,
    this.callerId,
    this.requestTimeout = const Duration(seconds: 12),
  });

  @override
  bool get isConfigured {
    return username.trim().isNotEmpty &&
        password.trim().isNotEmpty &&
        dialplanContext.trim().isNotEmpty &&
        dialplanExtension.trim().isNotEmpty;
  }

  @override
  String get providerLabel => 'voip:asterisk';

  @override
  Future<VoipCallResult> stageCall({required VoipCallRequest request}) async {
    final phone = request.recipientPhone.trim();
    if (phone.isEmpty) {
      return VoipCallResult(
        accepted: false,
        providerLabel: providerLabel,
        statusLabel: 'Missing call contact',
      );
    }
    if (!isConfigured) {
      return VoipCallResult(
        accepted: false,
        providerLabel: providerLabel,
        statusLabel: 'Asterisk ARI not configured',
      );
    }
    final endpoint = _endpointFor(phone);
    final uri = _channelsUri().replace(
      queryParameters: <String, String>{
        'endpoint': endpoint,
        'context': dialplanContext.trim(),
        'extension': dialplanExtension.trim(),
        'priority': '$dialplanPriority',
        'timeout': '30',
        if ((callerId ?? '').trim().isNotEmpty) 'callerId': callerId!.trim(),
        'channelId': request.callKey.trim(),
      },
    );
    try {
      final response = await client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': _basicAuthorizationHeader(),
            },
            body: jsonEncode({
              'variables': <String, String>{
                'ONYX_CONTACT_NAME': request.contactName,
                'ONYX_SUMMARY': request.summary,
                if ((request.clientId ?? '').trim().isNotEmpty)
                  'ONYX_CLIENT_ID': request.clientId!.trim(),
                if ((request.siteId ?? '').trim().isNotEmpty)
                  'ONYX_SITE_ID': request.siteId!.trim(),
                if ((request.incidentReference ?? '').trim().isNotEmpty)
                  'ONYX_INCIDENT_REF': request.incidentReference!.trim(),
              },
            }),
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return VoipCallResult(
          accepted: false,
          providerLabel: providerLabel,
          statusLabel: 'Asterisk originate failed',
          detail:
              _extractVoipFailureReason(response.body) ??
              'HTTP ${response.statusCode}',
        );
      }
      return VoipCallResult(
        accepted: true,
        providerLabel: providerLabel,
        statusLabel: 'Asterisk call staged',
      );
    } catch (error) {
      return VoipCallResult(
        accepted: false,
        providerLabel: providerLabel,
        statusLabel: 'Asterisk originate failed',
        detail: error.toString(),
      );
    }
  }

  Uri _channelsUri() {
    final path = baseUri.path.endsWith('/channels')
        ? baseUri.path
        : '${baseUri.path.replaceFirst(RegExp(r'/$'), '')}/channels';
    return baseUri.replace(path: path);
  }

  String _endpointFor(String phone) {
    final tech = endpointTechnology.trim().isEmpty
        ? 'PJSIP'
        : endpointTechnology.trim();
    final normalizedHost = (sipHost ?? '').trim();
    if (normalizedHost.isEmpty) {
      return '$tech/$phone';
    }
    return '$tech/$phone@$normalizedHost';
  }

  String _basicAuthorizationHeader() {
    final raw = '${username.trim()}:${password.trim()}';
    return 'Basic ${base64Encode(utf8.encode(raw))}';
  }
}

class HttpVoipCallService implements VoipCallService {
  final http.Client client;
  final String provider;
  final Uri endpoint;
  final String? bearerToken;
  final Duration requestTimeout;

  const HttpVoipCallService({
    required this.client,
    required this.provider,
    required this.endpoint,
    this.bearerToken,
    this.requestTimeout = const Duration(seconds: 12),
  });

  @override
  bool get isConfigured => provider.trim().isNotEmpty;

  @override
  String get providerLabel => 'voip:${provider.trim().toLowerCase()}';

  @override
  Future<VoipCallResult> stageCall({required VoipCallRequest request}) async {
    final phone = request.recipientPhone.trim();
    if (phone.isEmpty) {
      return VoipCallResult(
        accepted: false,
        providerLabel: providerLabel,
        statusLabel: 'Missing call contact',
      );
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
              'call_key': request.callKey,
              'to': phone,
              'contact_name': request.contactName,
              'summary': request.summary,
              if ((request.clientId ?? '').trim().isNotEmpty)
                'client_id': request.clientId!.trim(),
              if ((request.siteId ?? '').trim().isNotEmpty)
                'site_id': request.siteId!.trim(),
              if ((request.incidentReference ?? '').trim().isNotEmpty)
                'incident_reference': request.incidentReference!.trim(),
            }),
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return VoipCallResult(
          accepted: false,
          providerLabel: providerLabel,
          statusLabel: 'VoIP stage failed',
          detail:
              _extractVoipFailureReason(response.body) ??
              'HTTP ${response.statusCode}',
        );
      }
      return VoipCallResult(
        accepted: true,
        providerLabel: providerLabel,
        statusLabel: 'VoIP call staged',
      );
    } catch (error) {
      return VoipCallResult(
        accepted: false,
        providerLabel: providerLabel,
        statusLabel: 'VoIP stage failed',
        detail: error.toString(),
      );
    }
  }
}

String? _extractVoipFailureReason(String body) {
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
