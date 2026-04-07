import 'dart:async';

import 'package:http/http.dart' as http;

import '../domain/intelligence/intel_ingestion.dart';
import 'dvr_http_auth.dart';
import 'intelligence_event_object_semantics.dart';
import 'dvr_scope_config.dart';

class DvrCameraHealth {
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

  const DvrCameraHealth({
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
}

class DvrEvidenceProbeSnapshot {
  final int queueDepth;
  final int boundedQueueLimit;
  final int droppedCount;
  final int verifiedCount;
  final int failureCount;
  final DateTime? lastRunAtUtc;
  final String lastAlert;
  final List<DvrCameraHealth> cameras;

  const DvrEvidenceProbeSnapshot({
    this.queueDepth = 0,
    this.boundedQueueLimit = 0,
    this.droppedCount = 0,
    this.verifiedCount = 0,
    this.failureCount = 0,
    this.lastRunAtUtc,
    this.lastAlert = '',
    this.cameras = const [],
  });
}

class DvrEvidenceProbeBatchResult {
  final DvrEvidenceProbeSnapshot snapshot;

  const DvrEvidenceProbeBatchResult({required this.snapshot});
}

class HttpDvrEvidenceProbeService {
  final http.Client client;
  final DvrHttpAuthMode authMode;
  final int maxQueueDepth;
  final int retryAttempts;
  final Duration initialBackoff;
  final Duration requestTimeout;
  final Duration staleFrameThreshold;
  final String? bearerToken;
  final String? username;
  final String? password;

  const HttpDvrEvidenceProbeService({
    required this.client,
    this.authMode = DvrHttpAuthMode.none,
    this.maxQueueDepth = 12,
    this.retryAttempts = 3,
    this.initialBackoff = const Duration(milliseconds: 150),
    this.requestTimeout = const Duration(seconds: 3),
    this.staleFrameThreshold = const Duration(minutes: 30),
    this.bearerToken,
    this.username,
    this.password,
  });

  Future<DvrEvidenceProbeBatchResult> probeBatch(
    List<NormalizedIntelRecord> records,
  ) async {
    final nowUtc = DateTime.now().toUtc();
    final probes = <_DvrProbeItem>[];
    for (final record in records) {
      if (record.sourceType != 'dvr') {
        continue;
      }
      final cameraId = (record.cameraId ?? '').trim();
      if ((record.snapshotUrl ?? '').trim().isNotEmpty) {
        probes.add(
          _DvrProbeItem(
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
          _DvrProbeItem(
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

    final perCamera = <String, _DvrCameraAggregate>{};
    for (final record in records.where((entry) => entry.sourceType == 'dvr')) {
      final key = (record.cameraId ?? '').trim().isEmpty
          ? 'camera-unknown'
          : record.cameraId!.trim();
      final aggregate = perCamera.putIfAbsent(
        key,
        () => _DvrCameraAggregate(cameraId: key),
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
        aggregate.lastObjectLabel = resolveIdentityBackedObjectLabelFromSignals(
          directObjectLabel: (record.objectLabel ?? '').trim(),
          faceMatchId: record.faceMatchId,
          plateNumber: record.plateNumber,
        );
      }
    }

    for (final probe in kept) {
      final aggregate = perCamera.putIfAbsent(
        probe.cameraId.isEmpty ? 'camera-unknown' : probe.cameraId,
        () => _DvrCameraAggregate(
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
              return DvrCameraHealth(
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

    return DvrEvidenceProbeBatchResult(
      snapshot: DvrEvidenceProbeSnapshot(
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
      final head = await _auth.head(client, uri).timeout(requestTimeout);
      if (head.statusCode >= 200 && head.statusCode < 300) {
        return true;
      }
      if (head.statusCode == 405 ||
          head.statusCode == 403 ||
          head.statusCode == 400) {
        final get = await _auth
            .get(client, uri, headers: const {'Range': 'bytes=0-0'})
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

  static String _verificationKey(_DvrProbeItem probe) {
    return '${probe.cameraId}|${probe.mediaType}|${probe.url}';
  }

  DvrHttpAuthConfig get _auth => DvrHttpAuthConfig(
    mode: authMode,
    bearerToken: bearerToken,
    username: username,
    password: password,
  );
}

HttpDvrEvidenceProbeService createDvrEvidenceProbeService({
  required http.Client client,
  String authMode = '',
  String bearerToken = '',
  String username = '',
  String password = '',
  int maxQueueDepth = 12,
  Duration staleFrameThreshold = const Duration(minutes: 30),
}) {
  return HttpDvrEvidenceProbeService(
    client: client,
    authMode: parseDvrHttpAuthMode(authMode),
    bearerToken: bearerToken.trim().isEmpty ? null : bearerToken.trim(),
    username: username.trim().isEmpty ? null : username.trim(),
    password: password.isEmpty ? null : password,
    maxQueueDepth: maxQueueDepth,
    staleFrameThreshold: staleFrameThreshold,
  );
}

HttpDvrEvidenceProbeService createDvrEvidenceProbeServiceForScope(
  DvrScopeConfig scope, {
  required http.Client client,
  int maxQueueDepth = 12,
  Duration staleFrameThreshold = const Duration(minutes: 30),
}) {
  return createDvrEvidenceProbeService(
    client: client,
    authMode: scope.authMode,
    bearerToken: scope.bearerToken,
    username: scope.username,
    password: scope.password,
    maxQueueDepth: maxQueueDepth,
    staleFrameThreshold: staleFrameThreshold,
  );
}

class _DvrProbeItem {
  final String cameraId;
  final String mediaType;
  final String url;
  final DateTime occurredAtUtc;
  final int riskScore;

  const _DvrProbeItem({
    required this.cameraId,
    required this.mediaType,
    required this.url,
    required this.occurredAtUtc,
    required this.riskScore,
  });
}

class _DvrCameraAggregate {
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

  _DvrCameraAggregate({required this.cameraId});
}
