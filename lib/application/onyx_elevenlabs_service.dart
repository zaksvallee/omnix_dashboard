import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

const kOnyxDefaultElevenLabsVoiceId = '21m00Tcm4TlvDq8ikWAM';

abstract class OnyxElevenLabsService {
  bool get isConfigured;

  Future<Uint8List?> synthesize(String text);
}

class UnconfiguredOnyxElevenLabsService implements OnyxElevenLabsService {
  const UnconfiguredOnyxElevenLabsService();

  @override
  bool get isConfigured => false;

  @override
  Future<Uint8List?> synthesize(String text) async => null;
}

class HttpOnyxElevenLabsService implements OnyxElevenLabsService {
  final http.Client client;
  final String apiKey;
  final String voiceId;
  final Duration timeout;

  const HttpOnyxElevenLabsService({
    required this.client,
    required this.apiKey,
    this.voiceId = kOnyxDefaultElevenLabsVoiceId,
    this.timeout = const Duration(seconds: 10),
  });

  @override
  bool get isConfigured {
    return apiKey.trim().isNotEmpty && voiceId.trim().isNotEmpty;
  }

  @override
  Future<Uint8List?> synthesize(String text) async {
    final normalized = _normalizeInput(text);
    if (!isConfigured || normalized.isEmpty) {
      return null;
    }
    final endpoint = Uri.https(
      'api.elevenlabs.io',
      '/v1/text-to-speech/${voiceId.trim()}',
    );
    try {
      final response = await client
          .post(
            endpoint,
            headers: <String, String>{
              'Accept': 'audio/mpeg',
              'Content-Type': 'application/json',
              'xi-api-key': apiKey.trim(),
            },
            body: jsonEncode(<String, Object?>{
              'text': normalized,
              'model_id': 'eleven_monolingual_v1',
              'voice_settings': <String, Object?>{
                'stability': 0.5,
                'similarity_boost': 0.75,
              },
            }),
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        developer.log(
          'ElevenLabs synth failed with HTTP ${response.statusCode}',
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
