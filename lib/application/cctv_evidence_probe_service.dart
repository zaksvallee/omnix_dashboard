import 'dart:async';

import 'package:http/http.dart' as http;

import '../domain/intelligence/intel_ingestion.dart';

class CctvCameraHealth {
  final String cameraId;
  final int eventCount;
  final int snapshotRefs;
  final int clipRefs;
  final int snapshotVerified;
  final int clipVerified;
  final int probeFailures;
  final DateTime? lastSeenAtUtc;
  final String lastZone;
  final String lastObjectLabel;
  final int staleFrameAgeSeconds;
  final String status;

  const CctvCameraHealth({
    required this.cameraId,
    this.eventCount = 0,
    this.snapshotRefs = 0,
    this.clipRefs = 0,
    this.snapshotVerified = 0,
    this.clipVerified = 0,
    this.probeFailures = 0,
    this.lastSeenAtUtc,
    this.lastZone = '',
    this.lastObjectLabel = '',
    this.staleFrameAgeSeconds = 0,
    this.status = 'unknown',
  });

  factory CctvCameraHealth.fromJson(Map<String, Object?> json) {
    return CctvCameraHealth(
      cameraId: (json['camera_id'] ?? '').toString().trim(),
      eventCount: _jsonAsInt(json['event_count']),
      snapshotRefs: _jsonAsInt(json['snapshot_refs']),
      clipRefs: _jsonAsInt(json['clip_refs']),
      snapshotVerified: _jsonAsInt(json['snapshot_verified']),
      clipVerified: _jsonAsInt(json['clip_verified']),
      probeFailures: _jsonAsInt(json['probe_failures']),
      lastSeenAtUtc: _jsonAsDate(json['last_seen_at_utc']),
      lastZone: (json['last_zone'] ?? '').toString().trim(),
      lastObjectLabel: (json['last_object_label'] ?? '').toString().trim(),
      staleFrameAgeSeconds: _jsonAsInt(json['stale_frame_age_seconds']),
      status: (json['status'] ?? 'unknown').toString().trim(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'camera_id': cameraId,
      'event_count': eventCount,
      'snapshot_refs': snapshotRefs,
      'clip_refs': clipRefs,
      'snapshot_verified': snapshotVerified,
      'clip_verified': clipVerified,
      'probe_failures': probeFailures,
      'last_seen_at_utc': lastSeenAtUtc?.toIso8601String(),
      'last_zone': lastZone,
      'last_object_label': lastObjectLabel,
      'stale_frame_age_seconds': staleFrameAgeSeconds,
      'status': status,
    };
  }
}

class CctvEvidenceProbeSnapshot {
  final int queueDepth;
  final int boundedQueueLimit;
  final int droppedCount;
  final int verifiedCount;
  final int failureCount;
  final DateTime? lastRunAtUtc;
  final String lastAlert;
  final List<CctvCameraHealth> cameras;

  const CctvEvidenceProbeSnapshot({
    this.queueDepth = 0,
    this.boundedQueueLimit = 0,
    this.droppedCount = 0,
    this.verifiedCount = 0,
    this.failureCount = 0,
    this.lastRunAtUtc,
    this.lastAlert = '',
    this.cameras = const [],
  });

  factory CctvEvidenceProbeSnapshot.fromJson(Map<String, Object?> json) {
    final rawCameras = json['cameras'];
    final cameras = rawCameras is List
        ? rawCameras
              .whereType<Map>()
              .map(
                (entry) => CctvCameraHealth.fromJson(
                  entry.map(
                    (key, value) => MapEntry(key.toString(), value as Object?),
                  ),
                ),
              )
              .where((entry) => entry.cameraId.isNotEmpty)
              .toList(growable: false)
        : const <CctvCameraHealth>[];
    return CctvEvidenceProbeSnapshot(
      queueDepth: _jsonAsInt(json['queue_depth']),
      boundedQueueLimit: _jsonAsInt(json['bounded_queue_limit']),
      droppedCount: _jsonAsInt(json['dropped_count']),
      verifiedCount: _jsonAsInt(json['verified_count']),
      failureCount: _jsonAsInt(json['failure_count']),
      lastRunAtUtc: _jsonAsDate(json['last_run_at_utc']),
      lastAlert: (json['last_alert'] ?? '').toString().trim(),
      cameras: cameras,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'queue_depth': queueDepth,
      'bounded_queue_limit': boundedQueueLimit,
      'dropped_count': droppedCount,
      'verified_count': verifiedCount,
      'failure_count': failureCount,
      'last_run_at_utc': lastRunAtUtc?.toIso8601String(),
      'last_alert': lastAlert,
      'cameras': cameras.map((entry) => entry.toJson()).toList(growable: false),
    };
  }

  String summaryLabel() {
    final runLabel = lastRunAtUtc == null
        ? 'never'
        : '${lastRunAtUtc!.hour.toString().padLeft(2, '0')}:${lastRunAtUtc!.minute.toString().padLeft(2, '0')}:${lastRunAtUtc!.second.toString().padLeft(2, '0')} UTC';
    final alert = lastAlert.trim();
    return 'verified $verifiedCount • fail $failureCount • dropped $droppedCount • queue $queueDepth/$boundedQueueLimit • last $runLabel${alert.isEmpty ? '' : ' • $alert'}';
  }

  String cameraSummaryLabel({int limit = 3}) {
    if (cameras.isEmpty) {
      return 'cameras none';
    }
    final visible = cameras
        .take(limit)
        .map((camera) {
          final zone = camera.lastZone.trim().isEmpty
              ? 'zone n/a'
              : 'zone ${camera.lastZone.trim()}';
          final ageMinutes = (camera.staleFrameAgeSeconds / 60).floor();
          return '${camera.cameraId}:${camera.status} • $zone • stale ${ageMinutes}m';
        })
        .join(' | ');
    final hidden = cameras.length - limit;
    return hidden > 0 ? '$visible | +$hidden more' : visible;
  }
}

class CctvEvidenceProbeBatchResult {
  final CctvEvidenceProbeSnapshot snapshot;

  const CctvEvidenceProbeBatchResult({required this.snapshot});
}

class HttpCctvEvidenceProbeService {
  final http.Client client;
  final int maxQueueDepth;
  final int retryAttempts;
  final Duration initialBackoff;
  final Duration requestTimeout;
  final Duration staleFrameThreshold;

  const HttpCctvEvidenceProbeService({
    required this.client,
    this.maxQueueDepth = 12,
    this.retryAttempts = 3,
    this.initialBackoff = const Duration(milliseconds: 150),
    this.requestTimeout = const Duration(seconds: 3),
    this.staleFrameThreshold = const Duration(minutes: 30),
  });

  Future<CctvEvidenceProbeBatchResult> probeBatch(
    List<NormalizedIntelRecord> records,
  ) async {
    final nowUtc = DateTime.now().toUtc();
    final probes = <_ProbeItem>[];
    for (final record in records) {
      final cameraId = (record.cameraId ?? '').trim();
      if ((record.snapshotUrl ?? '').trim().isNotEmpty) {
        probes.add(
          _ProbeItem(
            cameraId: cameraId,
            mediaType: 'snapshot',
            url: record.snapshotUrl!.trim(),
            occurredAtUtc: record.occurredAtUtc,
            riskScore: record.riskScore,
          ),
        );
      }
      if ((record.clipUrl ?? '').trim().isNotEmpty) {
        probes.add(
          _ProbeItem(
            cameraId: cameraId,
            mediaType: 'clip',
            url: record.clipUrl!.trim(),
            occurredAtUtc: record.occurredAtUtc,
            riskScore: record.riskScore,
          ),
        );
      }
    }

    final prioritized = [...probes]
      ..sort((a, b) {
        final byRisk = b.riskScore.compareTo(a.riskScore);
        if (byRisk != 0) return byRisk;
        return b.occurredAtUtc.compareTo(a.occurredAtUtc);
      });
    final kept = prioritized.take(maxQueueDepth).toList(growable: false);
    final droppedCount = prioritized.length > maxQueueDepth
        ? prioritized.length - maxQueueDepth
        : 0;

    final verification = <String, bool>{};
    var verifiedCount = 0;
    var failureCount = 0;
    for (final probe in kept) {
      final ok = await _probeWithRetry(probe.url);
      verification[_verificationKey(probe)] = ok;
      if (ok) {
        verifiedCount += 1;
      } else {
        failureCount += 1;
      }
    }

    final perCamera = <String, _CameraAggregate>{};
    for (final record in records) {
      final key = (record.cameraId ?? '').trim().isEmpty
          ? 'camera-unknown'
          : record.cameraId!.trim();
      final aggregate = perCamera.putIfAbsent(
        key,
        () => _CameraAggregate(cameraId: key),
      );
      aggregate.eventCount += 1;
      if ((record.snapshotUrl ?? '').trim().isNotEmpty) {
        aggregate.snapshotRefs += 1;
      }
      if ((record.clipUrl ?? '').trim().isNotEmpty) {
        aggregate.clipRefs += 1;
      }
      if (aggregate.lastSeenAtUtc == null ||
          record.occurredAtUtc.isAfter(aggregate.lastSeenAtUtc!)) {
        aggregate.lastSeenAtUtc = record.occurredAtUtc;
        aggregate.lastZone = (record.zone ?? '').trim();
        aggregate.lastObjectLabel = (record.objectLabel ?? '').trim();
      }
    }

    for (final probe in kept) {
      final aggregate = perCamera.putIfAbsent(
        probe.cameraId.isEmpty ? 'camera-unknown' : probe.cameraId,
        () => _CameraAggregate(
          cameraId: probe.cameraId.isEmpty ? 'camera-unknown' : probe.cameraId,
        ),
      );
      final ok = verification[_verificationKey(probe)] ?? false;
      if (ok) {
        if (probe.mediaType == 'snapshot') {
          aggregate.snapshotVerified += 1;
        } else {
          aggregate.clipVerified += 1;
        }
      } else {
        aggregate.probeFailures += 1;
      }
    }

    final cameras =
        perCamera.values
            .map((aggregate) {
              final lastSeen = aggregate.lastSeenAtUtc;
              final staleSeconds = lastSeen == null
                  ? staleFrameThreshold.inSeconds
                  : nowUtc.difference(lastSeen).inSeconds;
              final status = aggregate.probeFailures > 0
                  ? 'degraded'
                  : staleSeconds >= staleFrameThreshold.inSeconds
                  ? 'stale'
                  : 'healthy';
              return CctvCameraHealth(
                cameraId: aggregate.cameraId,
                eventCount: aggregate.eventCount,
                snapshotRefs: aggregate.snapshotRefs,
                clipRefs: aggregate.clipRefs,
                snapshotVerified: aggregate.snapshotVerified,
                clipVerified: aggregate.clipVerified,
                probeFailures: aggregate.probeFailures,
                lastSeenAtUtc: lastSeen,
                lastZone: aggregate.lastZone,
                lastObjectLabel: aggregate.lastObjectLabel,
                staleFrameAgeSeconds: staleSeconds < 0 ? 0 : staleSeconds,
                status: status,
              );
            })
            .toList(growable: false)
          ..sort((a, b) {
            final statusRank = _statusRank(
              a.status,
            ).compareTo(_statusRank(b.status));
            if (statusRank != 0) return statusRank;
            return a.cameraId.compareTo(b.cameraId);
          });

    final alerts = <String>[];
    if (droppedCount > 0) {
      alerts.add('queue drop $droppedCount');
    }
    if (failureCount > 0) {
      alerts.add('probe fail $failureCount');
    }
    if (cameras.any((entry) => entry.status == 'stale')) {
      alerts.add('stale camera');
    }

    return CctvEvidenceProbeBatchResult(
      snapshot: CctvEvidenceProbeSnapshot(
        queueDepth: kept.length,
        boundedQueueLimit: maxQueueDepth,
        droppedCount: droppedCount,
        verifiedCount: verifiedCount,
        failureCount: failureCount,
        lastRunAtUtc: nowUtc,
        lastAlert: alerts.join(' • '),
        cameras: cameras,
      ),
    );
  }

  Future<bool> _probeWithRetry(String url) async {
    var wait = initialBackoff;
    for (var attempt = 0; attempt < retryAttempts; attempt += 1) {
      final ok = await _probeOnce(url);
      if (ok) {
        return true;
      }
      if (attempt < retryAttempts - 1) {
        await Future<void>.delayed(wait);
        wait *= 2;
      }
    }
    return false;
  }

  Future<bool> _probeOnce(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }
    try {
      final head = await client.head(uri).timeout(requestTimeout);
      if (head.statusCode >= 200 && head.statusCode < 300) {
        return true;
      }
      if (head.statusCode == 405 ||
          head.statusCode == 403 ||
          head.statusCode == 400) {
        final get = await client
            .get(uri, headers: const {'Range': 'bytes=0-0'})
            .timeout(requestTimeout);
        return get.statusCode >= 200 && get.statusCode < 300;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static int _statusRank(String status) {
    return switch (status) {
      'degraded' => 0,
      'stale' => 1,
      'healthy' => 2,
      _ => 3,
    };
  }

  static String _verificationKey(_ProbeItem probe) {
    return '${probe.cameraId}|${probe.mediaType}|${probe.url}';
  }
}

class _ProbeItem {
  final String cameraId;
  final String mediaType;
  final String url;
  final DateTime occurredAtUtc;
  final int riskScore;

  const _ProbeItem({
    required this.cameraId,
    required this.mediaType,
    required this.url,
    required this.occurredAtUtc,
    required this.riskScore,
  });
}

class _CameraAggregate {
  final String cameraId;
  int eventCount = 0;
  int snapshotRefs = 0;
  int clipRefs = 0;
  int snapshotVerified = 0;
  int clipVerified = 0;
  int probeFailures = 0;
  DateTime? lastSeenAtUtc;
  String lastZone = '';
  String lastObjectLabel = '';

  _CameraAggregate({required this.cameraId});
}

int _jsonAsInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

DateTime? _jsonAsDate(Object? value) {
  if (value is DateTime) return value.toUtc();
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim())?.toUtc();
  }
  return null;
}
