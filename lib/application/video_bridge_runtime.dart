import '../domain/intelligence/intel_ingestion.dart';
import 'cctv_bridge_service.dart';
import 'cctv_evidence_probe_service.dart';

abstract class VideoBridgeService {
  Future<List<NormalizedIntelRecord>> fetchLatest({
    required String clientId,
    required String regionId,
    required String siteId,
  });
}

abstract class VideoEvidenceProbeService {
  Future<VideoEvidenceProbeBatchResult> probeBatch(
    List<NormalizedIntelRecord> records,
  );
}

class VideoCameraHealth {
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

  const VideoCameraHealth({
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

  factory VideoCameraHealth.fromJson(Map<String, Object?> json) {
    return VideoCameraHealth(
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

  factory VideoCameraHealth.fromCctv(CctvCameraHealth source) {
    return VideoCameraHealth(
      cameraId: source.cameraId,
      eventCount: source.eventCount,
      snapshotRefs: source.snapshotRefs,
      clipRefs: source.clipRefs,
      snapshotVerified: source.snapshotVerified,
      clipVerified: source.clipVerified,
      probeFailures: source.probeFailures,
      lastSeenAtUtc: source.lastSeenAtUtc,
      lastZone: source.lastZone,
      lastObjectLabel: source.lastObjectLabel,
      staleFrameAgeSeconds: source.staleFrameAgeSeconds,
      status: source.status,
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

class VideoEvidenceProbeSnapshot {
  final int queueDepth;
  final int boundedQueueLimit;
  final int droppedCount;
  final int verifiedCount;
  final int failureCount;
  final DateTime? lastRunAtUtc;
  final String lastAlert;
  final List<VideoCameraHealth> cameras;

  const VideoEvidenceProbeSnapshot({
    this.queueDepth = 0,
    this.boundedQueueLimit = 0,
    this.droppedCount = 0,
    this.verifiedCount = 0,
    this.failureCount = 0,
    this.lastRunAtUtc,
    this.lastAlert = '',
    this.cameras = const [],
  });

  factory VideoEvidenceProbeSnapshot.fromJson(Map<String, Object?> json) {
    final rawCameras = json['cameras'];
    final cameras = rawCameras is List
        ? rawCameras
              .whereType<Map>()
              .map(
                (entry) => VideoCameraHealth.fromJson(
                  entry.map(
                    (key, value) => MapEntry(key.toString(), value as Object?),
                  ),
                ),
              )
              .where((entry) => entry.cameraId.isNotEmpty)
              .toList(growable: false)
        : const <VideoCameraHealth>[];
    return VideoEvidenceProbeSnapshot(
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

  factory VideoEvidenceProbeSnapshot.fromCctv(
    CctvEvidenceProbeSnapshot source,
  ) {
    return VideoEvidenceProbeSnapshot(
      queueDepth: source.queueDepth,
      boundedQueueLimit: source.boundedQueueLimit,
      droppedCount: source.droppedCount,
      verifiedCount: source.verifiedCount,
      failureCount: source.failureCount,
      lastRunAtUtc: source.lastRunAtUtc,
      lastAlert: source.lastAlert,
      cameras: source.cameras
          .map(VideoCameraHealth.fromCctv)
          .toList(growable: false),
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

class VideoEvidenceProbeBatchResult {
  final VideoEvidenceProbeSnapshot snapshot;

  const VideoEvidenceProbeBatchResult({required this.snapshot});
}

class CctvBackedVideoBridgeService implements VideoBridgeService {
  final CctvBridgeService delegate;

  const CctvBackedVideoBridgeService({required this.delegate});

  @override
  Future<List<NormalizedIntelRecord>> fetchLatest({
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    return delegate.fetchLatest(
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );
  }
}

class CctvBackedVideoEvidenceProbeService implements VideoEvidenceProbeService {
  final HttpCctvEvidenceProbeService delegate;

  const CctvBackedVideoEvidenceProbeService({required this.delegate});

  @override
  Future<VideoEvidenceProbeBatchResult> probeBatch(
    List<NormalizedIntelRecord> records,
  ) async {
    final result = await delegate.probeBatch(records);
    return VideoEvidenceProbeBatchResult(
      snapshot: VideoEvidenceProbeSnapshot.fromCctv(result.snapshot),
    );
  }
}

int _jsonAsInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse((value ?? '').toString()) ?? 0;
}

DateTime? _jsonAsDate(Object? value) {
  final raw = (value ?? '').toString().trim();
  if (raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw)?.toUtc();
}
