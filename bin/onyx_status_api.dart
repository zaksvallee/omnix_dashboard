// ONYX Status API — standalone pure-Dart HTTP server.
//
// Nginx terminates TLS and reverse-proxies /v1/* to this process on
// 127.0.0.1:8444.
//
// Run with:
//   dart run bin/onyx_status_api.dart
//
// Environment variables:
//   ONYX_SUPABASE_URL            Supabase project URL           (required)
//   ONYX_SUPABASE_SERVICE_KEY    Service-role key               (required)
//   ONYX_STATUS_API_HOST         Bind address (default 127.0.0.1)
//   ONYX_STATUS_API_PORT         Bind port    (default 8444)

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:supabase/supabase.dart';

const String _defaultHost = '127.0.0.1';
const int _defaultPort = 8444;
const Duration _freshnessWindow = Duration(minutes: 30);
const Duration _saTimeOffset = Duration(hours: 2);

Future<void> main() async {
  final supabaseUrl = Platform.environment['ONYX_SUPABASE_URL'] ?? '';
  final serviceKey = Platform.environment['ONYX_SUPABASE_SERVICE_KEY'] ?? '';
  final host = Platform.environment['ONYX_STATUS_API_HOST'] ?? _defaultHost;
  final port =
      int.tryParse(Platform.environment['ONYX_STATUS_API_PORT'] ?? '') ??
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

  stdout.writeln('[ONYX] Status API listening on $host:$port');

  await for (final request in server) {
    unawaited(_handleRequest(request, supabase));
  }
}

Future<void> _handleRequest(
  HttpRequest request,
  SupabaseClient supabase,
) async {
  try {
    if (request.method == 'GET' && request.uri.path == '/health') {
      await _writeJsonResponse(request, HttpStatus.ok, <String, Object?>{
        'status': 'ok',
      });
      return;
    }

    if (request.method != 'GET') {
      await _writeJsonResponse(
        request,
        HttpStatus.methodNotAllowed,
        <String, Object?>{'error': 'method_not_allowed'},
      );
      return;
    }

    final route = _parseStatusRoute(request.uri);
    if (route == null) {
      await _writeJsonResponse(request, HttpStatus.notFound, <String, Object?>{
        'error': 'not_found',
      });
      return;
    }

    final token = _extractApiToken(request);
    if (token == null) {
      await _writeJsonResponse(
        request,
        HttpStatus.unauthorized,
        <String, Object?>{'error': 'missing_token'},
      );
      return;
    }

    final tokenId = await _validateToken(
      supabase,
      siteId: route.siteId,
      token: token,
    );
    if (tokenId == null) {
      await _writeJsonResponse(request, HttpStatus.forbidden, <String, Object?>{
        'error': 'invalid_token',
      });
      return;
    }
    unawaited(_touchTokenUsage(supabase, tokenId));

    final summary = await _buildStatusSummary(
      supabase,
      siteId: route.siteId,
      nowUtc: DateTime.now().toUtc(),
    );
    if (summary == null) {
      await _writeJsonResponse(request, HttpStatus.notFound, <String, Object?>{
        'error': 'site_not_found',
      });
      return;
    }

    if (route.json) {
      await _writeJsonResponse(request, HttpStatus.ok, summary.toJson());
      return;
    }

    await _writeTextResponse(request, HttpStatus.ok, summary.toVoiceText());
  } catch (error, stackTrace) {
    stderr.writeln('[ONYX] Status API request failed: $error');
    stderr.writeln(stackTrace);
    try {
      await _writeJsonResponse(
        request,
        HttpStatus.internalServerError,
        <String, Object?>{'error': 'internal_error'},
      );
    } catch (_) {
      // The connection may already be closed.
    }
  }
}

_StatusRoute? _parseStatusRoute(Uri uri) {
  final segments = uri.pathSegments;
  if (segments.length < 3) {
    return null;
  }
  if (segments[0] != 'v1' || segments[1] != 'status') {
    return null;
  }
  final siteId = segments[2].trim();
  if (siteId.isEmpty) {
    return null;
  }
  final asJson = segments.length >= 4 && segments[3] == 'json';
  if (segments.length > 4) {
    return null;
  }
  return _StatusRoute(siteId: siteId, json: asJson);
}

String? _extractApiToken(HttpRequest request) {
  final queryToken = request.uri.queryParameters['token']?.trim() ?? '';
  if (queryToken.isNotEmpty) {
    return queryToken;
  }
  final authHeader = request.headers.value(HttpHeaders.authorizationHeader);
  if (authHeader == null) {
    return null;
  }
  const bearerPrefix = 'Bearer ';
  if (!authHeader.startsWith(bearerPrefix)) {
    return null;
  }
  final token = authHeader.substring(bearerPrefix.length).trim();
  return token.isEmpty ? null : token;
}

Future<String?> _validateToken(
  SupabaseClient supabase, {
  required String siteId,
  required String token,
}) async {
  final rows = await supabase
      .from('site_api_tokens')
      .select('id')
      .eq('site_id', siteId)
      .eq('token', token)
      .limit(1);
  if (rows.isEmpty) {
    return null;
  }
  final row = Map<String, dynamic>.from(rows.first as Map);
  final id = row['id']?.toString().trim() ?? '';
  return id.isEmpty ? null : id;
}

Future<void> _touchTokenUsage(SupabaseClient supabase, String tokenId) async {
  try {
    await supabase
        .from('site_api_tokens')
        .update(<String, Object?>{
          'last_used_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', tokenId);
  } catch (error, stackTrace) {
    stderr.writeln(
      '[ONYX] Failed to update site_api_tokens.last_used_at: $error',
    );
    stderr.writeln(stackTrace);
  }
}

Future<_StatusSummary?> _buildStatusSummary(
  SupabaseClient supabase, {
  required String siteId,
  required DateTime nowUtc,
}) async {
  final siteRows = await supabase
      .from('sites')
      .select('site_id,name')
      .eq('site_id', siteId)
      .limit(1);
  if (siteRows.isEmpty) {
    return null;
  }
  final siteRow = Map<String, dynamic>.from(siteRows.first as Map);
  final siteName = _asString(siteRow['name']) ?? siteId;

  final snapshotRows = await supabase
      .from('site_awareness_snapshots')
      .select(
        'site_id,snapshot_at,perimeter_clear,detections,known_faults,active_alerts,channels',
      )
      .eq('site_id', siteId)
      .order('snapshot_at', ascending: false)
      .limit(1);
  final snapshotRow = snapshotRows.isEmpty
      ? null
      : Map<String, dynamic>.from(snapshotRows.first as Map);

  final configRows = await supabase
      .from('site_occupancy_config')
      .select('site_id,expected_occupancy,occupancy_label,site_type,reset_hour')
      .eq('site_id', siteId)
      .limit(1);
  final configRow = configRows.isEmpty
      ? null
      : Map<String, dynamic>.from(configRows.first as Map);

  final resetHour = _asInt(configRow?['reset_hour']) ?? 3;
  final sessionDate = _sessionDateString(
    nowUtc.add(_saTimeOffset),
    resetHour: resetHour,
  );
  final sessionRows = await supabase
      .from('site_occupancy_sessions')
      .select(
        'site_id,session_date,peak_detected,last_detection_at,channels_with_detections,updated_at',
      )
      .eq('site_id', siteId)
      .eq('session_date', sessionDate)
      .limit(1);
  final sessionRow = sessionRows.isEmpty
      ? null
      : Map<String, dynamic>.from(sessionRows.first as Map);

  final zoneRows = await supabase
      .from('site_camera_zones')
      .select('channel_id,zone_name')
      .eq('site_id', siteId);
  final zoneNamesByChannel = <String, String>{};
  for (final raw in zoneRows) {
    final row = Map<String, dynamic>.from(raw as Map);
    final channelId = row['channel_id']?.toString().trim() ?? '';
    final zoneName = _asString(row['zone_name']) ?? '';
    if (channelId.isNotEmpty && zoneName.isNotEmpty) {
      zoneNamesByChannel[channelId] = zoneName;
    }
  }

  final incidentRows = await supabase
      .from('incidents')
      .select('id,status')
      .eq('site_id', siteId)
      .neq('status', 'closed');
  final activeIncidentCount = incidentRows.length;

  final snapshotObservedAtUtc = _snapshotObservedAtUtc(snapshotRow);
  final freshSnapshot =
      snapshotObservedAtUtc != null &&
      nowUtc.difference(snapshotObservedAtUtc).abs() < _freshnessWindow;
  final perimeterClear = snapshotRow?['perimeter_clear'] == true;
  final detections = _asMap(snapshotRow?['detections']);
  final currentHumans =
      _asInt(detections?['human_count'] ?? detections?['humanCount']) ?? 0;
  final expectedOccupancy = _asInt(configRow?['expected_occupancy']) ?? 0;
  final occupancyLabel = _asString(configRow?['occupancy_label']) ?? 'people';
  final peakDetected = _asInt(sessionRow?['peak_detected']) ?? 0;
  final onSite = math.max(currentHumans, peakDetected);

  final offlineChannelIds = _offlineChannelIds(snapshotRow);
  final offlineChannels = offlineChannelIds
      .map(
        (channelId) =>
            '${zoneNamesByChannel[channelId] ?? 'Channel $channelId'} (Channel $channelId)',
      )
      .toList(growable: false);

  final channelCount = math.max(
    zoneNamesByChannel.length,
    _channelCount(snapshotRow),
  );
  final activeChannels = math.max(channelCount - offlineChannelIds.length, 0);

  final status = _deriveStatus(
    freshSnapshot: freshSnapshot,
    perimeterClear: perimeterClear,
    activeIncidentCount: activeIncidentCount,
  );
  final perimeter = !freshSnapshot
      ? 'unknown'
      : (perimeterClear ? 'clear' : 'alert');

  return _StatusSummary(
    siteId: siteId,
    siteName: siteName,
    status: status,
    perimeter: perimeter,
    onSite: onSite,
    expected: expectedOccupancy,
    occupancyLabel: occupancyLabel,
    activeIncidents: activeIncidentCount,
    lastUpdateUtc: snapshotObservedAtUtc,
    offlineChannels: offlineChannels,
    activeChannels: activeChannels,
    freshSnapshot: freshSnapshot,
  );
}

String _deriveStatus({
  required bool freshSnapshot,
  required bool perimeterClear,
  required int activeIncidentCount,
}) {
  if (!freshSnapshot) {
    return 'limited';
  }
  if (!perimeterClear || activeIncidentCount > 0) {
    return 'attention';
  }
  return 'clear';
}

DateTime? _snapshotObservedAtUtc(Map<String, dynamic>? row) {
  if (row == null) {
    return null;
  }
  final timestamps = <DateTime>[
    if (_asDateTime(row['snapshot_at']) != null)
      _asDateTime(row['snapshot_at'])!,
  ];
  final detections = _asMap(row['detections']);
  final detectionUpdatedAt = _asDateTime(
    detections?['last_updated'] ?? detections?['lastUpdated'],
  );
  if (detectionUpdatedAt != null) {
    timestamps.add(detectionUpdatedAt);
  }
  final channels = _asMap(row['channels']);
  if (channels != null) {
    for (final rawValue in channels.values) {
      final channel = _asMap(rawValue);
      final channelDate = _asDateTime(
        channel?['last_event_at'] ?? channel?['lastEventAt'],
      );
      if (channelDate != null) {
        timestamps.add(channelDate);
      }
    }
  }
  if (timestamps.isEmpty) {
    return null;
  }
  timestamps.sort((left, right) => right.compareTo(left));
  return timestamps.first;
}

Set<String> _offlineChannelIds(Map<String, dynamic>? row) {
  final offline = <String>{};
  final knownFaults = row?['known_faults'];
  if (knownFaults is List) {
    for (final entry in knownFaults) {
      final channelId = entry.toString().trim();
      if (channelId.isNotEmpty) {
        offline.add(channelId);
      }
    }
  }
  final channels = _asMap(row?['channels']);
  if (channels != null) {
    for (final entry in channels.entries) {
      final channel = _asMap(entry.value);
      final isFault =
          _asBool(channel?['is_fault'] ?? channel?['isFault']) ?? false;
      if (isFault) {
        final channelId =
            _asString(channel?['channel_id'] ?? channel?['channelId']) ??
            entry.key.toString();
        if (channelId.isNotEmpty) {
          offline.add(channelId);
        }
      }
    }
  }
  return offline;
}

int _channelCount(Map<String, dynamic>? row) {
  final channels = _asMap(row?['channels']);
  return channels?.length ?? 0;
}

Map<String, Object?>? _asMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return value.map(
    (key, entryValue) => MapEntry(key.toString(), entryValue as Object?),
  );
}

String? _asString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

bool? _asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    if (value == 1) return true;
    if (value == 0) return false;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return null;
}

DateTime? _asDateTime(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}

String _sessionDateString(DateTime observedAtLocal, {required int resetHour}) {
  final normalizedResetHour = resetHour.clamp(0, 23);
  final dayStart = DateTime(
    observedAtLocal.year,
    observedAtLocal.month,
    observedAtLocal.day,
    normalizedResetHour,
  );
  final sessionLocalDate = observedAtLocal.isBefore(dayStart)
      ? dayStart.subtract(const Duration(days: 1))
      : dayStart;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${sessionLocalDate.year.toString().padLeft(4, '0')}-${two(sessionLocalDate.month)}-${two(sessionLocalDate.day)}';
}

String _relativeTime(DateTime? observedAtUtc, DateTime nowUtc) {
  if (observedAtUtc == null) {
    return 'unknown';
  }
  final diff = nowUtc.difference(observedAtUtc).abs();
  if (diff < const Duration(minutes: 1)) {
    return 'just now';
  }
  if (diff < const Duration(hours: 1)) {
    final minutes = diff.inMinutes;
    return '$minutes minute${minutes == 1 ? '' : 's'} ago';
  }
  if (diff < const Duration(days: 1)) {
    final hours = diff.inHours;
    return '$hours hour${hours == 1 ? '' : 's'} ago';
  }
  final days = diff.inDays;
  return '$days day${days == 1 ? '' : 's'} ago';
}

Future<void> _writeJsonResponse(
  HttpRequest request,
  int statusCode,
  Map<String, Object?> body,
) async {
  request.response
    ..statusCode = statusCode
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  await request.response.close();
}

Future<void> _writeTextResponse(
  HttpRequest request,
  int statusCode,
  String body,
) async {
  request.response
    ..statusCode = statusCode
    ..headers.contentType = ContentType.text
    ..write(body);
  await request.response.close();
}

class _StatusRoute {
  final String siteId;
  final bool json;

  const _StatusRoute({required this.siteId, required this.json});
}

class _StatusSummary {
  final String siteId;
  final String siteName;
  final String status;
  final String perimeter;
  final int onSite;
  final int expected;
  final String occupancyLabel;
  final int activeIncidents;
  final DateTime? lastUpdateUtc;
  final List<String> offlineChannels;
  final int activeChannels;
  final bool freshSnapshot;

  const _StatusSummary({
    required this.siteId,
    required this.siteName,
    required this.status,
    required this.perimeter,
    required this.onSite,
    required this.expected,
    required this.occupancyLabel,
    required this.activeIncidents,
    required this.lastUpdateUtc,
    required this.offlineChannels,
    required this.activeChannels,
    required this.freshSnapshot,
  });

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'site': siteName,
      'status': status,
      'perimeter': perimeter,
      'on_site': onSite,
      'expected': expected,
      'active_incidents': activeIncidents,
      'last_update': lastUpdateUtc?.toIso8601String(),
      'channels': <String, Object?>{
        'offline': offlineChannels,
        'active': activeChannels,
      },
    };
  }

  String toVoiceText() {
    final nowUtc = DateTime.now().toUtc();
    final sentences = <String>[];
    switch (status) {
      case 'clear':
        sentences.add('All clear.');
        break;
      case 'attention':
        sentences.add('Attention required.');
        break;
      default:
        sentences.add('Monitoring is currently limited.');
        break;
    }

    if (expected > 0) {
      final label = onSite == 1 ? _singularize(occupancyLabel) : occupancyLabel;
      sentences.add('$onSite $label on site.');
    } else {
      sentences.add('$onSite people detected.');
    }

    if (perimeter == 'clear') {
      sentences.add('Perimeter secure.');
    } else if (perimeter == 'alert') {
      sentences.add('Perimeter attention required.');
    } else {
      sentences.add('Perimeter status is not current.');
    }

    if (activeIncidents <= 0) {
      sentences.add('No active incidents.');
    } else if (activeIncidents == 1) {
      sentences.add('1 active incident.');
    } else {
      sentences.add('$activeIncidents active incidents.');
    }

    sentences.add('Last updated ${_relativeTime(lastUpdateUtc, nowUtc)}.');
    return sentences.join(' ');
  }

  String _singularize(String label) {
    final trimmed = label.trim();
    if (trimmed.endsWith('s') && trimmed.length > 1) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
