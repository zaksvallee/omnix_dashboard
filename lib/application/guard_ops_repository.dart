import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/guard/guard_ops_event.dart';

class GuardOpsSyncResult {
  final int syncedCount;
  final int failedCount;
  final int pendingCount;
  final String? failureReason;

  const GuardOpsSyncResult({
    required this.syncedCount,
    required this.failedCount,
    required this.pendingCount,
    this.failureReason,
  });
}

abstract class GuardOpsRepository {
  Future<GuardOpsEvent> enqueueEvent({
    required String guardId,
    required String siteId,
    required String shiftId,
    required GuardOpsEventType eventType,
    required String deviceId,
    required String appVersion,
    required Map<String, Object?> payload,
    DateTime? occurredAt,
  });

  Future<void> enqueueMedia(GuardOpsMediaUpload media);
  Future<List<GuardOpsEvent>> pendingEvents();
  Future<List<GuardOpsMediaUpload>> pendingMedia();
  Future<List<GuardOpsEvent>> recentEvents({int limit = 20});
  Future<List<GuardOpsMediaUpload>> recentMedia({int limit = 20});
  Future<List<GuardOpsEvent>> failedEvents();
  Future<List<GuardOpsMediaUpload>> failedMedia();
  Future<int> shiftSequenceWatermark(String shiftId);
  Future<int> retryFailedEvents();
  Future<int> retryFailedMedia();
  Future<GuardOpsSyncResult> syncPendingEvents({int batchSize = 100});
  Future<GuardOpsSyncResult> uploadPendingMedia({int batchSize = 20});
}

abstract class GuardOpsRemoteGateway {
  Future<void> upsertEvents(List<GuardOpsEvent> events);
  Future<void> upsertMediaMetadata(List<GuardOpsMediaUpload> media);
}

class NoopGuardOpsRemoteGateway implements GuardOpsRemoteGateway {
  const NoopGuardOpsRemoteGateway();

  @override
  Future<void> upsertEvents(List<GuardOpsEvent> events) async {
    throw StateError('Guard ops remote sync is not configured.');
  }

  @override
  Future<void> upsertMediaMetadata(List<GuardOpsMediaUpload> media) async {
    throw StateError('Guard ops media upload is not configured.');
  }
}

class SupabaseGuardOpsRemoteGateway implements GuardOpsRemoteGateway {
  final SupabaseClient client;

  const SupabaseGuardOpsRemoteGateway(this.client);

  @override
  Future<void> upsertEvents(List<GuardOpsEvent> events) async {
    if (events.isEmpty) return;
    await client
        .from('guard_ops_events')
        .upsert(
          events
              .map(
                (event) => {
                  'event_id': event.eventId,
                  'guard_id': event.guardId,
                  'site_id': event.siteId,
                  'shift_id': event.shiftId,
                  'event_type': event.eventType.name,
                  'sequence': event.sequence,
                  'occurred_at': event.occurredAt.toUtc().toIso8601String(),
                  'device_id': event.deviceId,
                  'app_version': event.appVersion,
                  'payload': event.payload,
                },
              )
              .toList(growable: false),
          onConflict: 'shift_id,sequence',
        );
  }

  @override
  Future<void> upsertMediaMetadata(List<GuardOpsMediaUpload> media) async {
    if (media.isEmpty) return;
    await client
        .from('guard_ops_media')
        .upsert(
          media
              .map(
                (entry) => {
                  'media_id': entry.mediaId,
                  'event_id': entry.eventId,
                  'guard_id': entry.guardId,
                  'site_id': entry.siteId,
                  'shift_id': entry.shiftId,
                  'bucket': entry.bucket,
                  'path': entry.path,
                  'local_path': entry.localPath,
                  'captured_at': entry.capturedAt.toUtc().toIso8601String(),
                  'uploaded_at': DateTime.now().toUtc().toIso8601String(),
                  'sha256': entry.sha256,
                  'upload_status': 'uploaded',
                  'retry_count': entry.retryCount,
                  'failure_reason': entry.failureReason,
                  'visual_norm_mode': entry.visualNorm.mode.name,
                  'visual_norm_metadata': entry.visualNorm.toJson(),
                },
              )
              .toList(growable: false),
          onConflict: 'event_id,path',
        );
  }
}

class SharedPrefsGuardOpsRepository implements GuardOpsRepository {
  static const _eventsKey = 'onyx_guard_ops_events_v1';
  static const _mediaKey = 'onyx_guard_ops_media_v1';
  static const _sequenceMapKey = 'onyx_guard_ops_shift_sequence_v1';

  final SharedPreferences prefs;
  final GuardOpsRemoteGateway remote;
  final Random _random = Random();

  SharedPrefsGuardOpsRepository({required this.prefs, required this.remote});

  static Future<SharedPrefsGuardOpsRepository> create({
    required GuardOpsRemoteGateway remote,
  }) async {
    return SharedPrefsGuardOpsRepository(
      prefs: await SharedPreferences.getInstance(),
      remote: remote,
    );
  }

  @override
  Future<GuardOpsEvent> enqueueEvent({
    required String guardId,
    required String siteId,
    required String shiftId,
    required GuardOpsEventType eventType,
    required String deviceId,
    required String appVersion,
    required Map<String, Object?> payload,
    DateTime? occurredAt,
  }) async {
    final nextSequence = await _nextSequence(shiftId);
    final event = GuardOpsEvent(
      eventId: _nextEventId(),
      guardId: guardId.trim(),
      siteId: siteId.trim(),
      shiftId: shiftId.trim(),
      eventType: eventType,
      sequence: nextSequence,
      occurredAt: (occurredAt ?? DateTime.now()).toUtc(),
      deviceId: deviceId.trim(),
      appVersion: appVersion.trim(),
      payload: Map<String, Object?>.from(payload),
    );
    final all = await _readEvents();
    all.add(event);
    await _saveEvents(all);
    return event;
  }

  @override
  Future<void> enqueueMedia(GuardOpsMediaUpload media) async {
    final all = await _readMedia();
    all.add(media);
    await _saveMedia(all);
  }

  @override
  Future<List<GuardOpsEvent>> pendingEvents() async {
    final pending = (await _readEvents())
        .where((event) => event.isPending)
        .toList(growable: false);
    pending.sort((a, b) {
      final shiftCmp = a.shiftId.compareTo(b.shiftId);
      if (shiftCmp != 0) return shiftCmp;
      return a.sequence.compareTo(b.sequence);
    });
    return pending;
  }

  @override
  Future<List<GuardOpsMediaUpload>> pendingMedia() async {
    return (await _readMedia())
        .where((entry) => entry.isPending)
        .toList(growable: false);
  }

  @override
  Future<List<GuardOpsEvent>> recentEvents({int limit = 20}) async {
    final all = await _readEvents();
    all.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return all.take(limit).toList(growable: false);
  }

  @override
  Future<List<GuardOpsMediaUpload>> recentMedia({int limit = 20}) async {
    final all = await _readMedia();
    all.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return all.take(limit).toList(growable: false);
  }

  @override
  Future<List<GuardOpsEvent>> failedEvents() async {
    return (await _readEvents())
        .where(
          (entry) =>
              entry.failureReason != null && entry.failureReason!.isNotEmpty,
        )
        .toList(growable: false);
  }

  @override
  Future<List<GuardOpsMediaUpload>> failedMedia() async {
    return (await _readMedia())
        .where((entry) => entry.status == GuardMediaUploadStatus.failed)
        .toList(growable: false);
  }

  @override
  Future<int> shiftSequenceWatermark(String shiftId) async {
    final key = shiftId.trim();
    if (key.isEmpty) return 0;
    final map = await _readSequenceMap();
    return map[key] ?? 0;
  }

  @override
  Future<int> retryFailedEvents() async {
    final all = await _readEvents();
    var retried = 0;
    final updated = all
        .map((entry) {
          if (entry.failureReason == null || entry.failureReason!.isEmpty) {
            return entry;
          }
          retried += 1;
          return entry.copyWith(failureReason: null);
        })
        .toList(growable: false);
    await _saveEvents(updated);
    return retried;
  }

  @override
  Future<int> retryFailedMedia() async {
    final all = await _readMedia();
    var retried = 0;
    final updated = all
        .map((entry) {
          if (entry.status != GuardMediaUploadStatus.failed) {
            return entry;
          }
          retried += 1;
          return entry.copyWith(
            status: GuardMediaUploadStatus.queued,
            failureReason: null,
          );
        })
        .toList(growable: false);
    await _saveMedia(updated);
    return retried;
  }

  @override
  Future<GuardOpsSyncResult> syncPendingEvents({int batchSize = 100}) async {
    final all = await _readEvents();
    final pending = all
        .where((event) => event.isPending)
        .toList(growable: false);
    if (pending.isEmpty) {
      return const GuardOpsSyncResult(
        syncedCount: 0,
        failedCount: 0,
        pendingCount: 0,
      );
    }
    final batch = pending.take(batchSize).toList(growable: false);
    try {
      await remote.upsertEvents(batch);
      final syncedAt = DateTime.now().toUtc();
      final syncedIds = batch.map((event) => event.eventId).toSet();
      final updated = all
          .map((event) {
            if (!syncedIds.contains(event.eventId)) return event;
            return event.copyWith(
              syncedAt: syncedAt,
              retryCount: event.retryCount,
              failureReason: null,
            );
          })
          .toList(growable: false);
      await _saveEvents(updated);
      final remaining = updated.where((event) => event.isPending).length;
      return GuardOpsSyncResult(
        syncedCount: batch.length,
        failedCount: 0,
        pendingCount: remaining,
      );
    } catch (error) {
      final failedIds = batch.map((event) => event.eventId).toSet();
      final updated = all
          .map((event) {
            if (!failedIds.contains(event.eventId)) return event;
            return event.copyWith(
              retryCount: event.retryCount + 1,
              failureReason: error.toString(),
            );
          })
          .toList(growable: false);
      await _saveEvents(updated);
      final pendingCount = updated.where((event) => event.isPending).length;
      return GuardOpsSyncResult(
        syncedCount: 0,
        failedCount: batch.length,
        pendingCount: pendingCount,
        failureReason: error.toString(),
      );
    }
  }

  @override
  Future<GuardOpsSyncResult> uploadPendingMedia({int batchSize = 20}) async {
    final all = await _readMedia();
    final pending = all
        .where((entry) => entry.isPending)
        .toList(growable: false);
    if (pending.isEmpty) {
      return const GuardOpsSyncResult(
        syncedCount: 0,
        failedCount: 0,
        pendingCount: 0,
      );
    }
    final batch = pending.take(batchSize).toList(growable: false);
    try {
      await remote.upsertMediaMetadata(batch);
      final uploadedAt = DateTime.now().toUtc();
      final uploadedIds = batch.map((entry) => entry.mediaId).toSet();
      final updated = all
          .map((entry) {
            if (!uploadedIds.contains(entry.mediaId)) return entry;
            return entry.copyWith(
              uploadedAt: uploadedAt,
              status: GuardMediaUploadStatus.uploaded,
              retryCount: entry.retryCount,
              failureReason: null,
            );
          })
          .toList(growable: false);
      await _saveMedia(updated);
      final remaining = updated.where((entry) => entry.isPending).length;
      return GuardOpsSyncResult(
        syncedCount: batch.length,
        failedCount: 0,
        pendingCount: remaining,
      );
    } catch (error) {
      final failedIds = batch.map((entry) => entry.mediaId).toSet();
      final updated = all
          .map((entry) {
            if (!failedIds.contains(entry.mediaId)) return entry;
            return entry.copyWith(
              status: GuardMediaUploadStatus.failed,
              retryCount: entry.retryCount + 1,
              failureReason: error.toString(),
            );
          })
          .toList(growable: false);
      await _saveMedia(updated);
      final pendingCount = updated.where((entry) => entry.isPending).length;
      return GuardOpsSyncResult(
        syncedCount: 0,
        failedCount: batch.length,
        pendingCount: pendingCount,
        failureReason: error.toString(),
      );
    }
  }

  Future<int> _nextSequence(String shiftId) async {
    final map = await _readSequenceMap();
    final key = shiftId.trim();
    final next = (map[key] ?? 0) + 1;
    map[key] = next;
    await prefs.setString(_sequenceMapKey, jsonEncode(map));
    return next;
  }

  String _nextEventId() {
    final millis = DateTime.now().toUtc().millisecondsSinceEpoch;
    final randomPart = _random
        .nextInt(1 << 32)
        .toRadixString(16)
        .padLeft(8, '0');
    return 'evt-$millis-$randomPart';
  }

  Future<List<GuardOpsEvent>> _readEvents() async {
    final raw = prefs.getString(_eventsKey);
    if (raw == null || raw.isEmpty) return <GuardOpsEvent>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <GuardOpsEvent>[];
      return decoded
          .whereType<Map>()
          .map(
            (entry) => GuardOpsEvent.fromJson(
              entry.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where(
            (entry) =>
                entry.eventId.isNotEmpty &&
                entry.shiftId.isNotEmpty &&
                entry.sequence > 0,
          )
          .toList(growable: true);
    } catch (_) {
      await prefs.remove(_eventsKey);
      return <GuardOpsEvent>[];
    }
  }

  Future<void> _saveEvents(List<GuardOpsEvent> events) async {
    await prefs.setString(
      _eventsKey,
      jsonEncode(events.map((entry) => entry.toJson()).toList(growable: false)),
    );
  }

  Future<List<GuardOpsMediaUpload>> _readMedia() async {
    final raw = prefs.getString(_mediaKey);
    if (raw == null || raw.isEmpty) return <GuardOpsMediaUpload>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <GuardOpsMediaUpload>[];
      return decoded
          .whereType<Map>()
          .map(
            (entry) => GuardOpsMediaUpload.fromJson(
              entry.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where(
            (entry) =>
                entry.mediaId.isNotEmpty &&
                entry.eventId.isNotEmpty &&
                entry.path.isNotEmpty,
          )
          .toList(growable: true);
    } catch (_) {
      await prefs.remove(_mediaKey);
      return <GuardOpsMediaUpload>[];
    }
  }

  Future<void> _saveMedia(List<GuardOpsMediaUpload> media) async {
    await prefs.setString(
      _mediaKey,
      jsonEncode(media.map((entry) => entry.toJson()).toList(growable: false)),
    );
  }

  Future<Map<String, int>> _readSequenceMap() async {
    final raw = prefs.getString(_sequenceMapKey);
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int>{};
      return decoded.map((key, value) {
        final parsed = (value as num?)?.toInt() ?? 0;
        return MapEntry(key.toString(), parsed < 0 ? 0 : parsed);
      });
    } catch (_) {
      await prefs.remove(_sequenceMapKey);
      return <String, int>{};
    }
  }
}
