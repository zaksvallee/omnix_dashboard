// ONYX Camera Worker — standalone Dart CLI process for site awareness streaming.
//
// Run with:
//   ONYX_HIK_PASSWORD=yourpassword dart run bin/onyx_camera_worker.dart
//
// All other config is read from environment variables or dart-define defaults.
// Never hardcode the password — pass it via the environment only.
//
// Full env vars:
//   ONYX_HIK_HOST                 Camera host (default: 192.168.0.117)
//   ONYX_HIK_PORT                 Camera port (default: 80)
//   ONYX_HIK_USERNAME             Camera username (default: admin)
//   ONYX_HIK_PASSWORD             Camera password — REQUIRED, no default
//   ONYX_HIK_KNOWN_FAULT_CHANNELS Comma-separated fault channel IDs (default: 11)
//   ONYX_SUPABASE_URL             Supabase project URL
//   ONYX_SUPABASE_SERVICE_KEY     Supabase service role key (bypasses RLS — preferred)
//   SUPABASE_ANON_KEY             Supabase anon key (fallback if service key absent)
//   ONYX_CLIENT_ID                Client ID (default: CLIENT-MS-VALLEE)
//   ONYX_SITE_ID                  Site ID (default: SITE-MS-VALLEE-RESIDENCE)

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';
import 'package:xml/xml.dart' as xml;

// ─── Inlined from lib/application/site_awareness/onyx_site_awareness_snapshot.dart ───

enum OnyxChannelStatusType { active, idle, videoloss, unknown }

enum OnyxEventType {
  humanDetected,
  vehicleDetected,
  animalDetected,
  motionDetected,
  perimeterBreach,
  videoloss,
  unknown,
}

class OnyxSiteAwarenessSnapshot {
  final String siteId;
  final String clientId;
  final DateTime snapshotAt;
  final Map<String, OnyxChannelStatus> channels;
  final OnyxDetectionSummary detections;
  final bool perimeterClear;
  final List<String> knownFaults;
  final List<OnyxSiteAlert> activeAlerts;

  OnyxSiteAwarenessSnapshot({
    required this.siteId,
    required this.clientId,
    required this.snapshotAt,
    required Map<String, OnyxChannelStatus> channels,
    required this.detections,
    required this.perimeterClear,
    List<String> knownFaults = const <String>[],
    List<OnyxSiteAlert> activeAlerts = const <OnyxSiteAlert>[],
  }) : channels = Map.unmodifiable(
         Map<String, OnyxChannelStatus>.from(channels),
       ),
       knownFaults = List.unmodifiable(List<String>.from(knownFaults)),
       activeAlerts = List.unmodifiable(List<OnyxSiteAlert>.from(activeAlerts));

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'site_id': siteId,
      'client_id': clientId,
      'snapshot_at': snapshotAt.toUtc().toIso8601String(),
      'channels': channels.map(
        (key, value) => MapEntry(key, value.toJsonMap()),
      ),
      'detections': detections.toJsonMap(),
      'perimeter_clear': perimeterClear,
      'known_faults': knownFaults,
      'active_alerts': activeAlerts
          .map((alert) => alert.toJsonMap())
          .toList(growable: false),
    };
  }
}

class OnyxChannelStatus {
  final String channelId;
  final OnyxChannelStatusType status;
  final OnyxEventType? lastEventType;
  final DateTime? lastEventAt;
  final bool isFault;
  final String? faultReason;

  const OnyxChannelStatus({
    required this.channelId,
    required this.status,
    this.lastEventType,
    this.lastEventAt,
    this.isFault = false,
    this.faultReason,
  });

  OnyxChannelStatus copyWith({
    String? channelId,
    OnyxChannelStatusType? status,
    OnyxEventType? lastEventType,
    DateTime? lastEventAt,
    bool? isFault,
    String? faultReason,
  }) {
    return OnyxChannelStatus(
      channelId: channelId ?? this.channelId,
      status: status ?? this.status,
      lastEventType: lastEventType ?? this.lastEventType,
      lastEventAt: lastEventAt ?? this.lastEventAt,
      isFault: isFault ?? this.isFault,
      faultReason: faultReason ?? this.faultReason,
    );
  }

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'channel_id': channelId,
      'status': status.name,
      'last_event_type': lastEventType?.name,
      'last_event_at': lastEventAt?.toUtc().toIso8601String(),
      'is_fault': isFault,
      'fault_reason': faultReason,
    };
  }
}

class OnyxDetectionSummary {
  final int humanCount;
  final int vehicleCount;
  final int animalCount;
  final int motionCount;
  final DateTime lastUpdated;

  const OnyxDetectionSummary({
    required this.humanCount,
    required this.vehicleCount,
    required this.animalCount,
    required this.motionCount,
    required this.lastUpdated,
  });

  factory OnyxDetectionSummary.empty(DateTime at) {
    return OnyxDetectionSummary(
      humanCount: 0,
      vehicleCount: 0,
      animalCount: 0,
      motionCount: 0,
      lastUpdated: at.toUtc(),
    );
  }

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'human_count': humanCount,
      'vehicle_count': vehicleCount,
      'animal_count': animalCount,
      'motion_count': motionCount,
      'last_updated': lastUpdated.toUtc().toIso8601String(),
    };
  }
}

class OnyxSiteAlert {
  final String alertId;
  final String channelId;
  final OnyxEventType eventType;
  final DateTime detectedAt;
  final bool isAcknowledged;

  const OnyxSiteAlert({
    required this.alertId,
    required this.channelId,
    required this.eventType,
    required this.detectedAt,
    this.isAcknowledged = false,
  });

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'alert_id': alertId,
      'channel_id': channelId,
      'event_type': eventType.name,
      'detected_at': detectedAt.toUtc().toIso8601String(),
      'is_acknowledged': isAcknowledged,
    };
  }
}

class OnyxSiteAwarenessEvent {
  final String channelId;
  final OnyxEventType eventType;
  final DateTime detectedAt;
  final String rawEventType;
  final String? targetType;
  final bool isKnownFaultChannel;

  const OnyxSiteAwarenessEvent({
    required this.channelId,
    required this.eventType,
    required this.detectedAt,
    required this.rawEventType,
    this.targetType,
    this.isKnownFaultChannel = false,
  });

  factory OnyxSiteAwarenessEvent.fromAlertXml(
    String payload, {
    Set<String> knownFaultChannels = const <String>{},
    DateTime Function()? clock,
  }) {
    final document = xml.XmlDocument.parse(payload);
    final channelId = _firstNonEmpty(
      _readTag(document, 'dynChannelID'),
      _readTag(document, 'channelID'),
      _readTag(document, 'channelId'),
    );
    final rawEventType = _firstNonEmpty(
      _readTag(document, 'eventType'),
      _readTag(document, 'eventDescription'),
    );
    final targetType = _readTag(document, 'targetType');
    final detectedAt =
        DateTime.tryParse(_readTag(document, 'dateTime'))?.toUtc() ??
        (clock ?? DateTime.now).call().toUtc();
    return OnyxSiteAwarenessEvent(
      channelId: channelId.isEmpty ? 'unknown' : channelId,
      eventType: mapOnyxEventType(
        rawEventType: rawEventType,
        targetType: targetType,
      ),
      detectedAt: detectedAt,
      rawEventType: rawEventType,
      targetType: targetType.isEmpty ? null : targetType,
      isKnownFaultChannel: knownFaultChannels.contains(channelId),
    );
  }

  bool get shouldRaiseAlert {
    if (isKnownFaultChannel) {
      return false;
    }
    return eventType != OnyxEventType.unknown;
  }

  bool get shouldPublishImmediately {
    if (eventType == OnyxEventType.perimeterBreach) {
      return true;
    }
    return !isKnownFaultChannel && eventType == OnyxEventType.humanDetected;
  }
}

class OnyxSiteAwarenessProjector {
  final String siteId;
  final String clientId;
  final Set<String> knownFaultChannels;
  final Duration detectionWindow;
  final DateTime Function() clock;
  final math.Random _random;

  final Map<String, OnyxChannelStatus> _channels =
      <String, OnyxChannelStatus>{};
  final List<OnyxSiteAwarenessEvent> _recentEvents = <OnyxSiteAwarenessEvent>[];
  final List<OnyxSiteAlert> _activeAlerts = <OnyxSiteAlert>[];

  OnyxSiteAwarenessProjector({
    required this.siteId,
    required this.clientId,
    Set<String> knownFaultChannels = const <String>{},
    this.detectionWindow = const Duration(minutes: 5),
    DateTime Function()? clock,
    math.Random? random,
  }) : knownFaultChannels = Set<String>.from(knownFaultChannels),
       clock = clock ?? DateTime.now,
       _random = random ?? math.Random.secure();

  OnyxSiteAwarenessSnapshot ingest(OnyxSiteAwarenessEvent event) {
    _prune(event.detectedAt);
    _recentEvents.add(event);
    _channels[event.channelId] = OnyxChannelStatus(
      channelId: event.channelId,
      status: event.eventType == OnyxEventType.videoloss
          ? OnyxChannelStatusType.videoloss
          : OnyxChannelStatusType.active,
      lastEventType: event.eventType,
      lastEventAt: event.detectedAt.toUtc(),
      isFault: event.eventType == OnyxEventType.videoloss,
      faultReason: event.eventType == OnyxEventType.videoloss
          ? event.isKnownFaultChannel
                ? 'Known wiring fault channel is reporting video loss.'
                : 'Video loss detected on the channel.'
          : null,
    );
    if (event.shouldRaiseAlert) {
      // Dedup: if an unacknowledged alert for the same channel+eventType
      // already exists within the window, update its timestamp instead of
      // adding a second alert for the same trigger.
      final dupIndex = _activeAlerts.indexWhere(
        (alert) =>
            !alert.isAcknowledged &&
            alert.channelId == event.channelId &&
            alert.eventType == event.eventType,
      );
      if (dupIndex >= 0) {
        _activeAlerts[dupIndex] = OnyxSiteAlert(
          alertId: _activeAlerts[dupIndex].alertId,
          channelId: event.channelId,
          eventType: event.eventType,
          detectedAt: event.detectedAt.toUtc(),
          isAcknowledged: false,
        );
      } else {
        _activeAlerts.add(
          OnyxSiteAlert(
            alertId: _uuidV4(_random),
            channelId: event.channelId,
            eventType: event.eventType,
            detectedAt: event.detectedAt.toUtc(),
            isAcknowledged: false,
          ),
        );
      }
    }
    return snapshot(at: event.detectedAt);
  }

  OnyxSiteAwarenessSnapshot snapshot({DateTime? at}) {
    final now = (at ?? clock()).toUtc();
    _prune(now);

    // Count distinct channels that reported each detection type within the
    // window — prevents one camera firing 20 VMD events from inflating counts.
    final humanChannels = <String>{};
    final vehicleChannels = <String>{};
    final animalChannels = <String>{};
    final motionChannels = <String>{};
    for (final event in _recentEvents) {
      switch (event.eventType) {
        case OnyxEventType.humanDetected:
          humanChannels.add(event.channelId);
        case OnyxEventType.vehicleDetected:
          vehicleChannels.add(event.channelId);
        case OnyxEventType.animalDetected:
          animalChannels.add(event.channelId);
        case OnyxEventType.motionDetected:
          motionChannels.add(event.channelId);
        case OnyxEventType.perimeterBreach:
        case OnyxEventType.videoloss:
        case OnyxEventType.unknown:
          break;
      }
    }
    final humanCount = humanChannels.length;
    final vehicleCount = vehicleChannels.length;
    final animalCount = animalChannels.length;
    final motionCount = motionChannels.length;

    final hasRecentHumanOrVehicle = _recentEvents.any(
      (event) =>
          !event.isKnownFaultChannel &&
          (event.eventType == OnyxEventType.humanDetected ||
              event.eventType == OnyxEventType.vehicleDetected),
    );

    final sortedChannelIds = _channels.keys.toList(growable: false)..sort();
    final channelMap = <String, OnyxChannelStatus>{};
    for (final channelId in sortedChannelIds) {
      final status = _channels[channelId]!;
      channelMap[channelId] = _resolvedChannelStatus(status, now);
    }

    final knownFaults =
        channelMap.values
            .where(
              (status) =>
                  knownFaultChannels.contains(status.channelId) &&
                  status.status == OnyxChannelStatusType.videoloss,
            )
            .map((status) => status.channelId)
            .toList(growable: false)
          ..sort();

    final activeAlerts = List<OnyxSiteAlert>.from(_activeAlerts)
      ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));

    final detectionLastUpdated = _recentEvents.isEmpty
        ? now
        : _recentEvents
              .map((event) => event.detectedAt)
              .reduce(
                (latest, candidate) =>
                    candidate.isAfter(latest) ? candidate : latest,
              );

    return OnyxSiteAwarenessSnapshot(
      siteId: siteId,
      clientId: clientId,
      snapshotAt: now,
      channels: channelMap,
      detections: OnyxDetectionSummary(
        humanCount: humanCount,
        vehicleCount: vehicleCount,
        animalCount: animalCount,
        motionCount: motionCount,
        lastUpdated: detectionLastUpdated,
      ),
      perimeterClear: !hasRecentHumanOrVehicle,
      knownFaults: knownFaults,
      activeAlerts: activeAlerts,
    );
  }

  /// Marks all active alerts as acknowledged and returns the updated snapshot.
  /// Call this when an operator sends a "clear" command via Telegram.
  OnyxSiteAwarenessSnapshot acknowledgeAllAlerts() {
    for (var i = 0; i < _activeAlerts.length; i++) {
      _activeAlerts[i] = OnyxSiteAlert(
        alertId: _activeAlerts[i].alertId,
        channelId: _activeAlerts[i].channelId,
        eventType: _activeAlerts[i].eventType,
        detectedAt: _activeAlerts[i].detectedAt,
        isAcknowledged: true,
      );
    }
    return snapshot();
  }

  void _prune(DateTime nowUtc) {
    final cutoff = nowUtc.subtract(detectionWindow);
    _recentEvents.removeWhere((event) => event.detectedAt.isBefore(cutoff));
    _activeAlerts.removeWhere((alert) => alert.detectedAt.isBefore(cutoff));
  }

  OnyxChannelStatus _resolvedChannelStatus(
    OnyxChannelStatus status,
    DateTime nowUtc,
  ) {
    if (status.status == OnyxChannelStatusType.videoloss) {
      return status;
    }
    final lastEventAt = status.lastEventAt;
    if (lastEventAt == null) {
      return status.copyWith(status: OnyxChannelStatusType.unknown);
    }
    if (nowUtc.difference(lastEventAt) >= detectionWindow) {
      return status.copyWith(status: OnyxChannelStatusType.idle);
    }
    return status.copyWith(status: OnyxChannelStatusType.active);
  }
}

OnyxEventType mapOnyxEventType({
  required String rawEventType,
  String? targetType,
}) {
  final normalizedEvent = _normalizeToken(rawEventType);
  final normalizedTarget = _normalizeToken(targetType ?? '');

  if (normalizedEvent == 'videoloss') {
    return OnyxEventType.videoloss;
  }
  if (normalizedEvent == 'linedetection' ||
      normalizedEvent == 'fielddetection') {
    return OnyxEventType.perimeterBreach;
  }
  if (normalizedEvent == 'vmd' ||
      normalizedEvent == 'motion' ||
      normalizedEvent == 'motiondetected' ||
      normalizedEvent == 'motiondetection') {
    return switch (normalizedTarget) {
      'human' || 'person' => OnyxEventType.humanDetected,
      'vehicle' || 'car' || 'truck' => OnyxEventType.vehicleDetected,
      'animal' => OnyxEventType.animalDetected,
      _ => OnyxEventType.motionDetected,
    };
  }
  return OnyxEventType.unknown;
}

String _firstNonEmpty(String first, String second, [String third = '']) {
  for (final candidate in <String>[first, second, third]) {
    if (candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
  }
  return '';
}

String _readTag(xml.XmlDocument document, String tagName) {
  final normalizedTag = tagName.toLowerCase();
  for (final element in document.descendants.whereType<xml.XmlElement>()) {
    if (element.name.local.toLowerCase() == normalizedTag) {
      return element.innerText.trim();
    }
  }
  return '';
}

String _normalizeToken(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String _uuidV4(math.Random random) {
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return [
    hex.substring(0, 8),
    hex.substring(8, 12),
    hex.substring(12, 16),
    hex.substring(16, 20),
    hex.substring(20, 32),
  ].join('-');
}

// ─── Inlined from lib/application/site_awareness/onyx_site_awareness_service.dart ───

abstract class OnyxSiteAwarenessService {
  Future<void> start({required String siteId, required String clientId});
  Future<void> stop();
  OnyxSiteAwarenessSnapshot? get latestSnapshot;
  Stream<OnyxSiteAwarenessSnapshot> get snapshots;
  bool get isConnected;
}

// ─── Inlined from lib/application/dvr_http_auth.dart ───

enum DvrHttpAuthMode { none, bearer, digest }

DvrHttpAuthMode parseDvrHttpAuthMode(String raw) {
  final normalized = raw.trim().toLowerCase().replaceAll('-', '_');
  return switch (normalized) {
    'bearer' => DvrHttpAuthMode.bearer,
    'digest' => DvrHttpAuthMode.digest,
    _ => DvrHttpAuthMode.none,
  };
}

class DvrHttpAuthConfig {
  final DvrHttpAuthMode mode;
  final String? bearerToken;
  final String? username;
  final String? password;

  const DvrHttpAuthConfig({
    required this.mode,
    this.bearerToken,
    this.username,
    this.password,
  });

  bool get configured {
    return switch (mode) {
      DvrHttpAuthMode.bearer => (bearerToken ?? '').trim().isNotEmpty,
      DvrHttpAuthMode.digest =>
        (username ?? '').trim().isNotEmpty && (password ?? '').isNotEmpty,
      DvrHttpAuthMode.none => false,
    };
  }

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'auth_mode': mode.name,
      'bearer_token': (bearerToken ?? '').trim().isEmpty
          ? null
          : bearerToken!.trim(),
      'username': (username ?? '').trim().isEmpty ? null : username!.trim(),
      'password': (password ?? '').isEmpty ? null : password,
    };
  }

  factory DvrHttpAuthConfig.fromJsonObject(Object? raw) {
    if (raw is! Map) {
      return const DvrHttpAuthConfig(mode: DvrHttpAuthMode.none);
    }
    final json = raw.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
    final bearerToken = (json['bearer_token'] ?? '').toString().trim();
    final username = (json['username'] ?? '').toString().trim();
    final password = (json['password'] ?? '').toString();
    return DvrHttpAuthConfig(
      mode: parseDvrHttpAuthMode((json['auth_mode'] ?? '').toString()),
      bearerToken: bearerToken.isEmpty ? null : bearerToken,
      username: username.isEmpty ? null : username,
      password: password.isEmpty ? null : password,
    );
  }

  Future<http.Response> get(
    http.Client client,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    final response = await send(client, 'GET', uri, headers: headers);
    return http.Response.fromStream(response);
  }

  Future<http.Response> head(
    http.Client client,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    final response = await send(client, 'HEAD', uri, headers: headers);
    return http.Response.fromStream(response);
  }

  Future<http.StreamedResponse> send(
    http.Client client,
    String method,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) async {
    final baseHeaders = _withBearer(headers);
    final initialRequest = http.Request(method, uri)
      ..headers.addAll(baseHeaders);
    _applyBody(initialRequest, body);
    final initialResponse = await client.send(initialRequest);
    if (mode != DvrHttpAuthMode.digest || initialResponse.statusCode != 401) {
      return initialResponse;
    }

    final challenge = initialResponse.headers['www-authenticate'] ?? '';
    final digestHeader = _buildDigestAuthorization(
      challenge,
      method: method,
      uri: uri,
    );
    if (digestHeader == null) {
      return initialResponse;
    }

    await initialResponse.stream.drain<void>();
    final retryRequest = http.Request(method, uri)
      ..headers.addAll(baseHeaders)
      ..headers['Authorization'] = digestHeader;
    _applyBody(retryRequest, body);
    return client.send(retryRequest);
  }

  void _applyBody(http.Request request, Object? body) {
    if (body == null) {
      return;
    }
    if (body is String) {
      request.body = body;
      return;
    }
    if (body is List<int>) {
      request.bodyBytes = body;
      return;
    }
    if (body is Map<String, String>) {
      request.bodyFields = body;
      return;
    }
    request.body = body.toString();
  }

  Map<String, String> _withBearer(Map<String, String> headers) {
    final resolved = <String, String>{...headers};
    final token = bearerToken?.trim();
    if (mode == DvrHttpAuthMode.bearer &&
        token != null &&
        token.isNotEmpty &&
        !resolved.containsKey('Authorization')) {
      resolved['Authorization'] = 'Bearer $token';
    }
    return resolved;
  }

  String? _buildDigestAuthorization(
    String challenge, {
    required String method,
    required Uri uri,
  }) {
    final user = username?.trim() ?? '';
    final pass = password ?? '';
    if (user.isEmpty || pass.isEmpty) {
      return null;
    }
    final attributes = _parseDigestChallenge(challenge);
    final realm = attributes['realm'];
    final nonce = attributes['nonce'];
    if (realm == null || nonce == null || realm.isEmpty || nonce.isEmpty) {
      return null;
    }

    final uriPath = uri.path.isEmpty
        ? '/'
        : uri.path + (uri.hasQuery ? '?${uri.query}' : '');
    final qop = (attributes['qop'] ?? '')
            .split(',')
            .map((entry) => entry.trim())
            .contains('auth')
        ? 'auth'
        : '';
    const nc = '00000001';
    final cnonce = md5
        .convert(
          utf8.encode(
            '${DateTime.now().microsecondsSinceEpoch}|$uriPath|${math.Random().nextInt(1 << 32)}',
          ),
        )
        .toString()
        .substring(0, 16);
    final ha1 = md5.convert(utf8.encode('$user:$realm:$pass')).toString();
    final ha2 =
        md5.convert(utf8.encode('${method.toUpperCase()}:$uriPath')).toString();
    final response = qop.isNotEmpty
        ? md5
              .convert(
                utf8.encode('$ha1:$nonce:$nc:$cnonce:$qop:$ha2'),
              )
              .toString()
        : md5.convert(utf8.encode('$ha1:$nonce:$ha2')).toString();

    final parts = <String>[
      'Digest username="$user"',
      'realm="$realm"',
      'nonce="$nonce"',
      'uri="$uriPath"',
      if ((attributes['opaque'] ?? '').isNotEmpty)
        'opaque="${attributes['opaque']}"',
      if ((attributes['algorithm'] ?? '').isNotEmpty)
        'algorithm=${attributes['algorithm']}',
      if (qop.isNotEmpty) 'qop=$qop',
      if (qop.isNotEmpty) 'nc=$nc',
      if (qop.isNotEmpty) 'cnonce="$cnonce"',
      'response="$response"',
    ];
    return parts.join(', ');
  }

  Map<String, String> _parseDigestChallenge(String challenge) {
    final normalized = challenge.trim();
    if (!normalized.toLowerCase().startsWith('digest')) {
      return const <String, String>{};
    }
    final matches = RegExp(
      r'(\w+)=(?:"([^"]*)"|([^,\s]+))',
    ).allMatches(normalized);
    final values = <String, String>{};
    for (final match in matches) {
      final key = match.group(1)?.trim();
      final quoted = match.group(2);
      final plain = match.group(3);
      if (key == null || key.isEmpty) {
        continue;
      }
      values[key.toLowerCase()] = (quoted ?? plain ?? '').trim();
    }
    return values;
  }
}

// ─── Inlined from lib/application/site_awareness/onyx_site_awareness_repository.dart ───

class OnyxSiteAwarenessRepository {
  final SupabaseClient _client;

  OnyxSiteAwarenessRepository(SupabaseClient client) : _client = client;

  Future<void> upsertSnapshot(OnyxSiteAwarenessSnapshot snapshot) async {
    try {
      await _client.from('site_awareness_snapshots').upsert(<String, Object?>{
        'site_id': snapshot.siteId,
        'client_id': snapshot.clientId,
        'snapshot_at': snapshot.snapshotAt.toUtc().toIso8601String(),
        'channels': snapshot.channels.map(
          (key, value) => MapEntry(key, value.toJsonMap()),
        ),
        'detections': snapshot.detections.toJsonMap(),
        'perimeter_clear': snapshot.perimeterClear,
        'known_faults': snapshot.knownFaults,
        'active_alerts': snapshot.activeAlerts
            .map((alert) => alert.toJsonMap())
            .toList(growable: false),
      }, onConflict: 'site_id');
    } catch (error, stackTrace) {
      developer.log(
        'Failed to upsert site awareness snapshot for ${snapshot.siteId}.',
        name: 'OnyxSiteAwarenessRepository',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      rethrow;
    }
  }
}

// ─── Inlined from lib/application/site_awareness/onyx_hik_isapi_stream_awareness_service.dart ───

class OnyxHikIsapiStreamAwarenessService implements OnyxSiteAwarenessService {
  final String host;
  final int port;
  final String username;
  final String password;
  final List<String> knownFaultChannels;
  final http.Client _client;
  final OnyxSiteAwarenessRepository? _repository;
  final Duration requestTimeout;
  final Duration publishInterval;
  final Duration detectionWindow;
  final Duration initialRetryDelay;
  final Duration maxRetryDelay;
  final DateTime Function() _clock;
  final Future<void> Function(Duration duration) _sleep;

  final StreamController<OnyxSiteAwarenessSnapshot> _snapshotController =
      StreamController<OnyxSiteAwarenessSnapshot>.broadcast();

  StreamSubscription<List<int>>? _streamSubscription;
  Timer? _publishTimer;
  OnyxSiteAwarenessProjector? _projector;
  OnyxSiteAwarenessSnapshot? _latestSnapshot;
  bool _isConnected = false;
  bool _running = false;
  int _generation = 0;
  String _siteId = '';
  String _clientId = '';

  OnyxHikIsapiStreamAwarenessService({
    required this.host,
    this.port = 80,
    required this.username,
    required this.password,
    this.knownFaultChannels = const <String>[],
    http.Client? client,
    OnyxSiteAwarenessRepository? repository,
    this.requestTimeout = const Duration(seconds: 15),
    this.publishInterval = const Duration(seconds: 30),
    this.detectionWindow = const Duration(minutes: 5),
    this.initialRetryDelay = const Duration(seconds: 1),
    this.maxRetryDelay = const Duration(seconds: 60),
    DateTime Function()? clock,
    Future<void> Function(Duration duration)? sleep,
  }) : _client = client ?? http.Client(),
       _repository = repository,
       _clock = clock ?? DateTime.now,
       _sleep = sleep ?? Future<void>.delayed;

  @override
  OnyxSiteAwarenessSnapshot? get latestSnapshot => _latestSnapshot;

  @override
  Stream<OnyxSiteAwarenessSnapshot> get snapshots => _snapshotController.stream;

  @override
  bool get isConnected => _isConnected;

  Uri get _alertStreamUri => Uri(
    scheme: 'http',
    host: host,
    port: port,
    path: '/ISAPI/Event/notification/alertStream',
  );

  Uri _snapshotUriForChannel(String channelId) {
    return Uri(
      scheme: 'http',
      host: host,
      port: port,
      path: '/ISAPI/Streaming/channels/$channelId/picture',
    );
  }

  @override
  Future<void> start({required String siteId, required String clientId}) async {
    await stop();
    _siteId = siteId.trim();
    _clientId = clientId.trim();
    _projector = OnyxSiteAwarenessProjector(
      siteId: _siteId,
      clientId: _clientId,
      knownFaultChannels: knownFaultChannels.toSet(),
      detectionWindow: detectionWindow,
      clock: _clock,
    );
    _latestSnapshot = null;
    _isConnected = false;
    _running = true;
    _generation += 1;
    _publishTimer = Timer.periodic(publishInterval, (_) {
      _publishProjectedSnapshot();
    });
    unawaited(_runConnectionLoop(_generation));
  }

  @override
  Future<void> stop() async {
    _running = false;
    _generation += 1;
    _isConnected = false;
    _publishTimer?.cancel();
    _publishTimer = null;
    final subscription = _streamSubscription;
    _streamSubscription = null;
    if (subscription != null) {
      try {
        await subscription.cancel();
      } catch (error, stackTrace) {
        developer.log(
          'Failed to cancel Hikvision alert stream subscription cleanly.',
          name: 'OnyxHikIsapiStream',
          error: error,
          stackTrace: stackTrace,
          level: 1000,
        );
      }
    }
  }

  Future<List<int>?> fetchSnapshotBytes(String channelId) async {
    try {
      final response = await _auth
          .get(
            _client,
            _snapshotUriForChannel(channelId.trim()),
            headers: const <String, String>{'Accept': 'image/jpeg,image/*,*/*'},
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        developer.log(
          'Snapshot request returned HTTP ${response.statusCode} for channel $channelId.',
          name: 'OnyxHikIsapiStream',
          level: 900,
        );
        return null;
      }
      return response.bodyBytes;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to fetch on-demand channel snapshot for $channelId.',
        name: 'OnyxHikIsapiStream',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      return null;
    }
  }

  Future<void> _runConnectionLoop(int generation) async {
    var retryAttempt = 0;
    while (_running && generation == _generation) {
      try {
        final response = await _auth
            .send(
              _client,
              'GET',
              _alertStreamUri,
              headers: const <String, String>{
                'Accept':
                    'multipart/x-mixed-replace, application/xml, text/xml',
              },
            )
            .timeout(requestTimeout);
        if (!_running || generation != _generation) {
          await response.stream.drain<void>();
          break;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          _isConnected = false;
          developer.log(
            'Alert stream returned HTTP ${response.statusCode}; retrying.',
            name: 'OnyxHikIsapiStream',
            level: 900,
          );
          await response.stream.drain<void>();
        } else {
          _isConnected = true;
          retryAttempt = 0;
          await _consumeAlertStream(response.stream, generation);
        }
      } catch (error, stackTrace) {
        _isConnected = false;
        developer.log(
          'Site awareness stream connection failed; retrying.',
          name: 'OnyxHikIsapiStream',
          error: error,
          stackTrace: stackTrace,
          level: 1000,
        );
      }
      if (!_running || generation != _generation) {
        break;
      }
      final delay = _retryDelayFor(retryAttempt);
      retryAttempt += 1;
      await _sleep(delay);
    }
    if (generation == _generation) {
      _isConnected = false;
    }
  }

  Future<void> _consumeAlertStream(
    Stream<List<int>> stream,
    int generation,
  ) async {
    final completer = Completer<void>();
    var buffer = '';
    _streamSubscription = stream.listen(
      (chunk) {
        buffer += utf8.decode(chunk, allowMalformed: true);
        final extraction = _extractAlertXml(buffer);
        buffer = extraction.remainder;
        for (final payload in extraction.payloads) {
          try {
            final event = OnyxSiteAwarenessEvent.fromAlertXml(
              payload,
              knownFaultChannels: knownFaultChannels.toSet(),
              clock: _clock,
            );
            final projector = _projector;
            if (projector == null) {
              continue;
            }
            final snapshot = projector.ingest(event);
            _latestSnapshot = snapshot;
            if (event.shouldPublishImmediately) {
              _emitSnapshot(snapshot);
            }
          } catch (error, stackTrace) {
            developer.log(
              'Failed to parse Hikvision EventNotificationAlert payload.',
              name: 'OnyxHikIsapiStream',
              error: error,
              stackTrace: stackTrace,
              level: 1000,
            );
          }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _isConnected = false;
        developer.log(
          'Alert stream subscription reported an error.',
          name: 'OnyxHikIsapiStream',
          error: error,
          stackTrace: stackTrace,
          level: 1000,
        );
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      onDone: () {
        _isConnected = false;
        final extraction = _extractAlertXml(buffer);
        for (final payload in extraction.payloads) {
          try {
            final event = OnyxSiteAwarenessEvent.fromAlertXml(
              payload,
              knownFaultChannels: knownFaultChannels.toSet(),
              clock: _clock,
            );
            final projector = _projector;
            if (projector == null) {
              continue;
            }
            final snapshot = projector.ingest(event);
            _latestSnapshot = snapshot;
            if (event.shouldPublishImmediately) {
              _emitSnapshot(snapshot);
            }
          } catch (error, stackTrace) {
            developer.log(
              'Failed to parse trailing Hikvision alert payload.',
              name: 'OnyxHikIsapiStream',
              error: error,
              stackTrace: stackTrace,
              level: 1000,
            );
          }
        }
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      cancelOnError: true,
    );
    await completer.future;
    if (generation == _generation) {
      _streamSubscription = null;
    }
  }

  void _publishProjectedSnapshot() {
    final projector = _projector;
    if (!_running || projector == null || _latestSnapshot == null) {
      return;
    }
    try {
      final snapshot = projector.snapshot();
      _emitSnapshot(snapshot);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to publish site awareness snapshot.',
        name: 'OnyxHikIsapiStream',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    }
  }

  void _emitSnapshot(OnyxSiteAwarenessSnapshot snapshot) {
    _latestSnapshot = snapshot;
    if (!_snapshotController.isClosed) {
      _snapshotController.add(snapshot);
    }
    final repository = _repository;
    if (repository != null) {
      unawaited(_persistSnapshot(repository, snapshot));
    }
  }

  Future<void> _persistSnapshot(
    OnyxSiteAwarenessRepository repository,
    OnyxSiteAwarenessSnapshot snapshot,
  ) async {
    try {
      await repository.upsertSnapshot(snapshot);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to persist site awareness snapshot.',
        name: 'OnyxHikIsapiStream',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    }
  }

  ({List<String> payloads, String remainder}) _extractAlertXml(String raw) {
    final matches = RegExp(
      r'<EventNotificationAlert\b[^>]*>[\s\S]*?</EventNotificationAlert>',
    ).allMatches(raw).toList(growable: false);
    if (matches.isEmpty) {
      return (payloads: const <String>[], remainder: raw);
    }
    final payloads = matches
        .map((match) => match.group(0) ?? '')
        .where((payload) => payload.trim().isNotEmpty)
        .toList(growable: false);
    return (payloads: payloads, remainder: raw.substring(matches.last.end));
  }

  Duration _retryDelayFor(int attempt) {
    final multiplier = math.pow(2, attempt).toInt();
    final seconds = math.min<int>(
      maxRetryDelay.inSeconds,
      initialRetryDelay.inSeconds * math.max(1, multiplier),
    );
    return Duration(seconds: seconds);
  }

  DvrHttpAuthConfig get _auth => DvrHttpAuthConfig(
    mode: DvrHttpAuthMode.digest,
    username: username,
    password: password,
  );
}

// ─── Non-secret config baked in at compile time via dart-define ───

const String _defaultHost = String.fromEnvironment(
  'ONYX_HIK_HOST',
  defaultValue: '192.168.0.117',
);
const int _defaultPort = int.fromEnvironment(
  'ONYX_HIK_PORT',
  defaultValue: 80,
);
const String _defaultUsername = String.fromEnvironment(
  'ONYX_HIK_USERNAME',
  defaultValue: 'admin',
);
const String _defaultKnownFaultChannels = String.fromEnvironment(
  'ONYX_HIK_KNOWN_FAULT_CHANNELS',
  defaultValue: '11',
);
const String _defaultClientId = String.fromEnvironment(
  'ONYX_CLIENT_ID',
  defaultValue: 'CLIENT-MS-VALLEE',
);
const String _defaultSiteId = String.fromEnvironment(
  'ONYX_SITE_ID',
  defaultValue: 'SITE-MS-VALLEE-RESIDENCE',
);

Future<void> main() async {
  // Password must come from the runtime environment — never compiled in.
  final password = Platform.environment['ONYX_HIK_PASSWORD'] ?? '';
  if (password.isEmpty) {
    stderr.writeln(
      '[ONYX] ERROR: ONYX_HIK_PASSWORD is not set.\n'
      '  Set it in your shell before running:\n'
      '    export ONYX_HIK_PASSWORD=yourpassword\n'
      '    dart run bin/onyx_camera_worker.dart',
    );
    exit(1);
  }

  final host = Platform.environment['ONYX_HIK_HOST'] ?? _defaultHost;
  final port =
      int.tryParse(Platform.environment['ONYX_HIK_PORT'] ?? '') ??
      _defaultPort;
  final username =
      Platform.environment['ONYX_HIK_USERNAME'] ?? _defaultUsername;
  final clientId =
      Platform.environment['ONYX_CLIENT_ID'] ?? _defaultClientId;
  final siteId = Platform.environment['ONYX_SITE_ID'] ?? _defaultSiteId;

  final rawFaultChannels =
      Platform.environment['ONYX_HIK_KNOWN_FAULT_CHANNELS'] ??
      _defaultKnownFaultChannels;
  final knownFaultChannels = rawFaultChannels
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);

  // Build Supabase client using pure Dart package (no Flutter dependency).
  // Service key is preferred — it bypasses RLS for server-side writes.
  final supabaseUrl = Platform.environment['ONYX_SUPABASE_URL'] ?? '';
  final serviceKey = Platform.environment['ONYX_SUPABASE_SERVICE_KEY'] ?? '';
  final anonKey = Platform.environment['SUPABASE_ANON_KEY'] ?? '';
  final supabaseKey = serviceKey.isNotEmpty ? serviceKey : anonKey;

  OnyxSiteAwarenessRepository? repository;
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    final supabaseClient = SupabaseClient(supabaseUrl, supabaseKey);
    repository = OnyxSiteAwarenessRepository(supabaseClient);
    stdout.writeln(
      '[ONYX] Supabase: $supabaseUrl '
      '(${serviceKey.isNotEmpty ? 'service key' : 'anon key'})',
    );
  } else {
    stdout.writeln(
      '[ONYX] Supabase: not configured — snapshot persistence disabled.',
    );
  }

  stdout.writeln('[ONYX] Camera worker starting.');
  stdout.writeln('[ONYX] Target: $host:$port  user=$username');
  stdout.writeln('[ONYX] Scope:  client=$clientId  site=$siteId');
  stdout.writeln('[ONYX] Fault channels: ${knownFaultChannels.join(', ')}');

  final service = OnyxHikIsapiStreamAwarenessService(
    host: host,
    port: port,
    username: username,
    password: password,
    knownFaultChannels: knownFaultChannels,
    repository: repository,
  );

  // Subscribe before starting so no events are missed.
  final subscription = service.snapshots.listen(
    (snapshot) {
      try {
        _printSnapshot(snapshot);
      } catch (error) {
        stderr.writeln('[ONYX] Failed to format snapshot: $error');
      }
    },
    onError: (Object error) {
      stderr.writeln('[ONYX] Snapshot stream error: $error');
    },
  );

  await service.start(siteId: siteId, clientId: clientId);
  stdout.writeln('[ONYX] Connected — listening for events.');

  // Handle Ctrl+C gracefully.
  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('\n[ONYX] Shutting down...');
    try {
      await subscription.cancel();
      await service.stop();
    } catch (error) {
      stderr.writeln('[ONYX] Error during shutdown: $error');
    }
    stdout.writeln('[ONYX] Done.');
    exit(0);
  });

  // Keep the process alive — the service owns its own connection/retry loop.
  await Future<void>.delayed(const Duration(days: 36500));
}

/// Prints a one-line summary of [snapshot] to stdout.
///
/// Example:
///   [19:37] CH5: human detected | CH11: videoloss (fault) | perimeter: clear | humans:1 vehicles:0 animals:0
void _printSnapshot(OnyxSiteAwarenessSnapshot snapshot) {
  final now = snapshot.snapshotAt.toLocal();
  final time =
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

  final channelParts = <String>[];
  final sortedChannels = snapshot.channels.keys.toList(growable: false)
    ..sort();
  for (final channelId in sortedChannels) {
    final ch = snapshot.channels[channelId]!;
    final statusLabel = switch (ch.status) {
      OnyxChannelStatusType.active => ch.lastEventType != null
          ? _eventLabel(ch.lastEventType!)
          : 'active',
      OnyxChannelStatusType.idle => 'idle',
      OnyxChannelStatusType.videoloss => 'videoloss',
      OnyxChannelStatusType.unknown => 'unknown',
    };
    final faultTag = ch.isFault ? ' (fault)' : '';
    channelParts.add('CH$channelId: $statusLabel$faultTag');
  }

  final perimeterLabel = snapshot.perimeterClear ? 'clear' : 'BREACHED';
  final d = snapshot.detections;
  final detectLabel =
      'humans:${d.humanCount} vehicles:${d.vehicleCount} animals:${d.animalCount}';

  final parts = <String>[
    '[$time]',
    if (channelParts.isNotEmpty) channelParts.join(' | '),
    'perimeter: $perimeterLabel',
    detectLabel,
  ];

  if (snapshot.knownFaults.isNotEmpty) {
    parts.add('faults: ${snapshot.knownFaults.join(',')}');
  }
  if (snapshot.activeAlerts.isNotEmpty) {
    parts.add('alerts: ${snapshot.activeAlerts.length}');
  }

  stdout.writeln(parts.join(' | '));
}

String _eventLabel(OnyxEventType type) {
  return switch (type) {
    OnyxEventType.humanDetected => 'human detected',
    OnyxEventType.vehicleDetected => 'vehicle detected',
    OnyxEventType.animalDetected => 'animal detected',
    OnyxEventType.motionDetected => 'motion detected',
    OnyxEventType.perimeterBreach => 'perimeter breach',
    OnyxEventType.videoloss => 'videoloss',
    OnyxEventType.unknown => 'unknown event',
  };
}
