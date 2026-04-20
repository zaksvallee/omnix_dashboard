import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

/// OnyxLiveSnapshotYoloService connects to an OPTIONAL enhancement tier
/// that provides YOLO object detection, face recognition, and license plate
/// reading. The core alert pipeline does NOT require this service.
///
/// Two-tier architecture:
///   Always-on: DVR proxy + camera worker + raw-snapshot Telegram delivery
///   Enhancement: YOLO/FR/LPR HTTP service at configurable URL (optional)
///
/// When enhancement is:
///   - reachable + fast (<3s): alerts include bounding boxes, confidence,
///     face matches, plate reads, track IDs
///   - reachable + slow (>3s): timeout, fall through to raw-snapshot
///   - unreachable: isConfigured=false at startup, worker skips enhancement
///
/// Set ONYX_MONITORING_YOLO_ENDPOINT to any URL:
///   - http://127.0.0.1:11636/detect  (local — not used in production since
///     Pi 4B CPU is too slow for real-time inference)
///   - http://192.168.0.NN:11636/detect  (Mac on LAN, for dev enhancement)
///   - https://inference.onyxsecurity.co.za/detect  (future Hetzner)
///
/// Set ONYX_MONITORING_YOLO_REQUEST_TIMEOUT_MS to adjust timeout (default 3000).
///
/// If endpoint returns non-200 OR takes >timeout OR is unreachable, the
/// raw-snapshot Telegram fallback fires with synthetic confidence 0.99
/// (see commit 85ca876 in onyx_camera_worker.dart).

class OnyxLiveSnapshotYoloResult {
  final String? primaryLabel;
  final bool personDetected;
  final double? personConfidence;
  final String? faceMatchId;
  final double? faceConfidence;
  final double? faceDistance;
  final String? plateNumber;
  final double? plateConfidence;
  final String? summary;
  final String? error;

  const OnyxLiveSnapshotYoloResult({
    required this.primaryLabel,
    required this.personDetected,
    required this.personConfidence,
    required this.faceMatchId,
    required this.faceConfidence,
    required this.faceDistance,
    required this.plateNumber,
    required this.plateConfidence,
    required this.summary,
    required this.error,
  });

  bool get matchedPerson => (faceMatchId ?? '').trim().isNotEmpty;
  bool get unknownPerson => personDetected && !matchedPerson;
}

class OnyxLiveSnapshotYoloService {
  final http.Client client;
  final Uri endpoint;
  final String authToken;
  final Duration requestTimeout;
  final Uri? rtspFrameServerBaseUri;

  OnyxLiveSnapshotYoloService({
    required this.client,
    required this.endpoint,
    this.authToken = '',
    // 3 seconds is right for Mac on LAN (normal response 1-2s) and Hetzner
    // over internet (2-3s). Pi-local YOLO (30-120s on 4B CPU) always trips
    // this, which is intentional — Pi-local YOLO is no longer the expected
    // path. Override via ONYX_MONITORING_YOLO_REQUEST_TIMEOUT_MS on the
    // camera worker side.
    this.requestTimeout = const Duration(seconds: 3),
    this.rtspFrameServerBaseUri,
  });

  bool get isConfigured => endpoint.toString().trim().isNotEmpty;
  bool get isRtspFrameServerConfigured =>
      (rtspFrameServerBaseUri?.toString().trim() ?? '').isNotEmpty;

  Future<List<int>?> fetchRtspFrame(String channelId) async {
    if (!isRtspFrameServerConfigured) {
      return null;
    }
    final normalizedChannelId = channelId.trim();
    if (normalizedChannelId.isEmpty) {
      return null;
    }
    final frameUri = rtspFrameServerBaseUri!.replace(
      path:
          '${rtspFrameServerBaseUri!.path.endsWith('/') ? rtspFrameServerBaseUri!.path.substring(0, rtspFrameServerBaseUri!.path.length - 1) : rtspFrameServerBaseUri!.path}/frame/$normalizedChannelId',
    );
    try {
      final response = await client
          .get(
            frameUri,
            headers: const <String, String>{'Accept': 'image/jpeg,image/*,*/*'},
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return response.bodyBytes;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to fetch RTSP frame snapshot for channel $normalizedChannelId.',
        name: 'OnyxLiveSnapshotYolo',
        error: error,
        stackTrace: stackTrace,
        level: 900,
      );
      return null;
    }
  }

  Future<OnyxLiveSnapshotYoloResult?> detectSnapshot({
    required String recordKey,
    required String provider,
    required String sourceType,
    required String clientId,
    required String siteId,
    required String cameraId,
    required String zone,
    required DateTime occurredAtUtc,
    required List<int> imageBytes,
    String headline = 'Site awareness snapshot',
    String summary = 'Live human detection snapshot',
    String objectLabel = 'person',
  }) async {
    if (!isConfigured || imageBytes.isEmpty) {
      return null;
    }
    try {
      final response = await client
          .post(
            endpoint,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (authToken.trim().isNotEmpty)
                'Authorization': 'Bearer ${authToken.trim()}',
            },
            body: jsonEncode(<String, Object?>{
              'items': <Map<String, Object?>>[
                <String, Object?>{
                  'record_key': recordKey,
                  'provider': provider,
                  'source_type': sourceType,
                  'client_id': clientId,
                  'site_id': siteId,
                  'camera_id': cameraId,
                  'zone': zone,
                  'headline': headline,
                  'summary': summary,
                  'object_label': objectLabel,
                  'occurred_at_utc': occurredAtUtc.toUtc().toIso8601String(),
                  'image_url':
                      'data:image/jpeg;base64,${base64Encode(imageBytes)}',
                },
              ],
            }),
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        developer.log(
          'YOLO snapshot detect returned HTTP ${response.statusCode}.',
          name: 'OnyxLiveSnapshotYolo',
          level: 900,
        );
        return null;
      }
      return _parseResult(response.body);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to run live snapshot detection through YOLO.',
        name: 'OnyxLiveSnapshotYolo',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      return null;
    }
  }

  OnyxLiveSnapshotYoloResult? _parseResult(String rawBody) {
    final decoded = jsonDecode(rawBody);
    if (decoded is! Map) {
      return null;
    }
    final payload = decoded.cast<Object?, Object?>();
    final items = switch (payload['results'] ?? payload['items']) {
      List value => value,
      _ => const <Object?>[],
    };
    if (items.isEmpty) {
      return const OnyxLiveSnapshotYoloResult(
        primaryLabel: null,
        personDetected: false,
        personConfidence: null,
        faceMatchId: null,
        faceConfidence: null,
        faceDistance: null,
        plateNumber: null,
        plateConfidence: null,
        summary: null,
        error: null,
      );
    }
    final first = items.first;
    if (first is! Map) {
      return null;
    }
    final item = first.map((key, value) => MapEntry(key.toString(), value));
    final faceMatch = switch (item['face_match'] ?? item['faceMatch']) {
      Map value => value.map((key, value) => MapEntry(key.toString(), value)),
      _ => const <String, Object?>{},
    };
    final detections = switch (item['detections']) {
      List value => value,
      _ => const <Object?>[],
    };
    final personDetected =
        (item['primary_label'] ?? item['primaryLabel'] ?? '')
                .toString()
                .trim()
                .toLowerCase() ==
            'person' ||
        detections.whereType<Map>().any((rawDetection) {
          final label = (rawDetection['label'] ?? rawDetection['class'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          return label == 'person';
        }) ||
        (item['face_match_id'] ?? item['faceMatchId'] ?? '')
            .toString()
            .trim()
            .isNotEmpty;
    return OnyxLiveSnapshotYoloResult(
      primaryLabel: _yoloString(item['primary_label'] ?? item['primaryLabel']),
      personDetected: personDetected,
      personConfidence: _yoloDouble(
        item['confidence'] ?? item['primary_confidence'],
      ),
      faceMatchId: _yoloString(
        item['face_match_id'] ??
            item['faceMatchId'] ??
            faceMatch['person_id'] ??
            faceMatch['face_match_id'],
      ),
      faceConfidence: _yoloDouble(
        item['face_confidence'] ??
            item['faceConfidence'] ??
            faceMatch['confidence'] ??
            faceMatch['face_confidence'],
      ),
      faceDistance: _yoloDouble(
        item['face_distance'] ??
            item['faceDistance'] ??
            faceMatch['distance'] ??
            faceMatch['face_distance'],
      ),
      plateNumber: _yoloString(item['plate_number'] ?? item['plateNumber']),
      plateConfidence: _yoloDouble(
        item['plate_confidence'] ?? item['plateConfidence'],
      ),
      summary: _yoloString(item['summary']),
      error: _yoloString(item['error']),
    );
  }
}

String? _yoloString(Object? value) {
  final normalized = (value?.toString() ?? '').trim();
  return normalized.isEmpty ? null : normalized;
}

double? _yoloDouble(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}
