import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'onyx_site_awareness_snapshot.dart';

class OnyxSiteAwarenessRepository {
  final SupabaseClient? _client;

  OnyxSiteAwarenessRepository({
    SupabaseClient? client,
    http.Client? httpClient,
    String supabaseUrl = const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: '',
    ),
    String anonKey = const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '',
    ),
    String serviceKey = const String.fromEnvironment(
      'ONYX_SUPABASE_SERVICE_KEY',
      defaultValue: '',
    ),
  }) : _client =
           client ??
           _buildClient(
             supabaseUrl: supabaseUrl,
             anonKey: anonKey,
             serviceKey: serviceKey,
             httpClient: httpClient,
           );

  Future<void> upsertSnapshot(OnyxSiteAwarenessSnapshot snapshot) async {
    final client = _client;
    if (client == null) {
      developer.log(
        'Supabase client is not configured. Snapshot persistence skipped for ${snapshot.siteId}.',
        name: 'OnyxSiteAwarenessRepository',
        level: 900,
      );
      return;
    }
    try {
      await client.from('site_awareness_snapshots').upsert(<String, Object?>{
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

  static SupabaseClient? _buildClient({
    required String supabaseUrl,
    required String anonKey,
    required String serviceKey,
    http.Client? httpClient,
  }) {
    final url = supabaseUrl.trim();
    final resolvedServiceKey = serviceKey.trim();
    final resolvedAnonKey = anonKey.trim();
    if (url.isEmpty) {
      developer.log(
        'SUPABASE_URL is empty. Site awareness persistence is disabled.',
        name: 'OnyxSiteAwarenessRepository',
        level: 900,
      );
      return null;
    }
    final resolvedKey = resolvedServiceKey.isNotEmpty
        ? resolvedServiceKey
        : resolvedAnonKey;
    if (resolvedKey.isEmpty) {
      developer.log(
        'Neither ONYX_SUPABASE_SERVICE_KEY nor SUPABASE_ANON_KEY is configured. Site awareness persistence is disabled.',
        name: 'OnyxSiteAwarenessRepository',
        level: 900,
      );
      return null;
    }
    if (resolvedServiceKey.isEmpty) {
      developer.log(
        'ONYX_SUPABASE_SERVICE_KEY is empty. Falling back to SUPABASE_ANON_KEY for site awareness writes.',
        name: 'OnyxSiteAwarenessRepository',
        level: 900,
      );
    }
    return SupabaseClient(
      url,
      resolvedKey,
      httpClient: httpClient,
      accessToken: () async => null,
    );
  }
}
