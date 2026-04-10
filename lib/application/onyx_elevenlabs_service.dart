import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

const kOnyxDefaultElevenLabsVoiceId = 'pNInz6obpgDQGcFmaJgB';
const kOnyxDefaultElevenLabsModelId = 'eleven_turbo_v2_5';
const kOnyxDefaultElevenLabsProxyBaseUri = 'http://127.0.0.1:11637';
const kOnyxDefaultDeterrentMessage =
    'This property is under active ONYX Security monitoring. '
    'You have been detected. A security response has been notified.';

abstract class OnyxElevenLabsService {
  bool get isConfigured;
  int get apiKeyLength;

  Future<Uint8List?> synthesize(String text);
  Future<Uint8List?> synthesizeDeterrent(String message);
}

class UnconfiguredOnyxElevenLabsService implements OnyxElevenLabsService {
  const UnconfiguredOnyxElevenLabsService();

  @override
  bool get isConfigured => false;

  @override
  int get apiKeyLength => 0;

  @override
  Future<Uint8List?> synthesize(String text) async => null;

  @override
  Future<Uint8List?> synthesizeDeterrent(String message) async => null;
}

class HttpOnyxElevenLabsService implements OnyxElevenLabsService {
  final http.Client client;
  final String apiKey;
  final String voiceId;
  final Uri? apiBaseUri;
  final Duration timeout;

  const HttpOnyxElevenLabsService({
    required this.client,
    required this.apiKey,
    this.voiceId = kOnyxDefaultElevenLabsVoiceId,
    this.apiBaseUri,
    this.timeout = const Duration(seconds: 10),
  });

  @override
  bool get isConfigured {
    return apiKey.trim().isNotEmpty && voiceId.trim().isNotEmpty;
  }

  @override
  int get apiKeyLength => apiKey.trim().length;

  @override
  Future<Uint8List?> synthesize(String text) async {
    final normalized = _normalizeInput(text);
    return _synthesizeNormalizedText(normalized);
  }

  @override
  Future<Uint8List?> synthesizeDeterrent(String message) async {
    final normalized = _normalizeInput(
      message.trim().isEmpty ? kOnyxDefaultDeterrentMessage : message,
    );
    return _synthesizeNormalizedText(normalized);
  }

  Future<Uint8List?> _synthesizeNormalizedText(String normalized) async {
    if (!isConfigured || normalized.isEmpty) {
      return null;
    }
    try {
      final configuredVoiceId = voiceId.trim();
      var response = await _synthesizeForVoice(
        voiceId: configuredVoiceId,
        text: normalized,
      );
      if (_shouldRetryWithFallbackVoice(response) &&
          configuredVoiceId != kOnyxDefaultElevenLabsVoiceId) {
        developer.log(
          'Configured ElevenLabs voice requires a paid plan; retrying with premade fallback.',
          name: 'OnyxElevenLabsService',
        );
        response = await _synthesizeForVoice(
          voiceId: kOnyxDefaultElevenLabsVoiceId,
          text: normalized,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        developer.log(
          'ElevenLabs synth failed with HTTP ${response.statusCode}: ${response.body}',
          name: 'OnyxElevenLabsService',
        );
        return null;
      }
      if (response.bodyBytes.isEmpty) {
        return null;
      }
      return Uint8List.fromList(response.bodyBytes);
    } catch (error, stackTrace) {
      developer.log(
        'ElevenLabs synth failed',
        name: 'OnyxElevenLabsService',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<http.Response> _synthesizeForVoice({
    required String voiceId,
    required String text,
  }) {
    final endpoint = _buildEndpoint(voiceId);
    final usesProxy = apiBaseUri != null;
    final headers = <String, String>{
      'Accept': 'audio/mpeg',
      'Content-Type': 'application/json',
    };
    if (!usesProxy) {
      headers['xi-api-key'] = apiKey.trim();
    }
    return client
        .post(
          endpoint,
          headers: headers,
          body: jsonEncode(<String, Object?>{
            'text': text,
            'model_id': kOnyxDefaultElevenLabsModelId,
            'voice_settings': <String, Object?>{
              'stability': 0.5,
              'similarity_boost': 0.75,
            },
          }),
        )
        .timeout(timeout);
  }

  Uri _buildEndpoint(String voiceId) {
    final baseUri = apiBaseUri;
    if (baseUri == null) {
      return Uri.https('api.elevenlabs.io', '/v1/text-to-speech/$voiceId');
    }
    final basePath = baseUri.path.trim();
    final normalizedBasePath = basePath.isEmpty || basePath == '/'
        ? ''
        : (basePath.endsWith('/')
              ? basePath.substring(0, basePath.length - 1)
              : basePath);
    return baseUri.replace(
      path: '$normalizedBasePath/elevenlabs/tts/$voiceId',
      queryParameters: null,
      fragment: null,
    );
  }

  bool _shouldRetryWithFallbackVoice(http.Response response) {
    if (response.statusCode != 402) {
      return false;
    }
    final body = response.body.toLowerCase();
    return body.contains('paid_plan_required') ||
        body.contains('payment_required');
  }

  String _normalizeInput(String text) {
    final collapsed = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\S\r\n]+'), ' ')
        .trim();
    if (collapsed.isEmpty) {
      return '';
    }
    if (collapsed.length <= 500) {
      return collapsed;
    }
    return collapsed.substring(0, 500).trimRight();
  }
}
