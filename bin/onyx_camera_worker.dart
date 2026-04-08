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
//   ONYX_SUPABASE_ANON_KEY        Supabase anon key
//   ONYX_SUPABASE_SERVICE_KEY     Supabase service key (bypasses RLS — preferred)
//   ONYX_CLIENT_ID                Client ID (default: CLIENT-MS-VALLEE)
//   ONYX_SITE_ID                  Site ID (default: SITE-MS-VALLEE-RESIDENCE)

import 'dart:io';

import 'package:omnix_dashboard/application/site_awareness/onyx_hik_isapi_stream_awareness_service.dart';
import 'package:omnix_dashboard/application/site_awareness/onyx_site_awareness_repository.dart';
import 'package:omnix_dashboard/application/site_awareness/onyx_site_awareness_snapshot.dart';

// Config read from dart-define at compile time (safe for non-secrets).
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
const String _supabaseUrl = String.fromEnvironment('ONYX_SUPABASE_URL');
const String _supabaseAnonKey = String.fromEnvironment(
  'ONYX_SUPABASE_ANON_KEY',
);
const String _supabaseServiceKey = String.fromEnvironment(
  'ONYX_SUPABASE_SERVICE_KEY',
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
  final port = int.tryParse(
        Platform.environment['ONYX_HIK_PORT'] ?? '',
      ) ??
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

  final supabaseUrl =
      Platform.environment['ONYX_SUPABASE_URL'] ?? _supabaseUrl;
  final supabaseAnonKey =
      Platform.environment['ONYX_SUPABASE_ANON_KEY'] ?? _supabaseAnonKey;
  final supabaseServiceKey =
      Platform.environment['ONYX_SUPABASE_SERVICE_KEY'] ?? _supabaseServiceKey;

  stdout.writeln('[ONYX] Camera worker starting.');
  stdout.writeln('[ONYX] Target: $host:$port  user=$username');
  stdout.writeln('[ONYX] Scope:  client=$clientId  site=$siteId');
  stdout.writeln('[ONYX] Fault channels: ${knownFaultChannels.join(', ')}');
  stdout.writeln(
    '[ONYX] Supabase: ${supabaseUrl.isNotEmpty ? supabaseUrl : '(not configured — persistence disabled)'}',
  );

  final repository = OnyxSiteAwarenessRepository(
    supabaseUrl: supabaseUrl,
    anonKey: supabaseAnonKey,
    serviceKey: supabaseServiceKey,
  );

  final service = OnyxHikIsapiStreamAwarenessService(
    host: host,
    port: port,
    username: username,
    password: password,
    knownFaultChannels: knownFaultChannels,
    repository: repository,
  );

  // Subscribe to snapshots before starting so no events are missed.
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

  // Keep the process alive — the service runs its own connection loop.
  await Future<Never>.delayed(const Duration(days: 365 * 100));
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

  final perimeterLabel =
      snapshot.perimeterClear ? 'clear' : 'BREACHED';
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
