import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/events/intelligence_received.dart';
import 'dvr_bridge_service.dart';
import 'dvr_http_auth.dart';
import 'dvr_ingest_contract.dart';
import 'dvr_scope_config.dart';
import 'intelligence_event_object_semantics.dart';
import 'monitoring_watch_continuous_visual_service.dart';
import 'monitoring_watch_runtime_store.dart';
import 'video_bridge_runtime.dart';

enum ClientCameraHealthStatus { live, limited, offline }

enum ClientCameraHealthReason {
  credentialsMissing,
  bridgeOffline,
  recorderUnreachable,
  legacyProxyActive,
  unknown,
}

enum ClientCameraHealthPath {
  hikConnectApi,
  legacyLocalProxy,
  directRecorder,
  unknown,
}

enum ClientCameraRelayStatus {
  active,
  ready,
  starting,
  stale,
  error,
  idle,
  unknown,
}

enum ClientLiveSiteMovementStatus {
  active,
  recentSignals,
  noConfirmedMovement,
  unknown,
}

enum ClientLiveSiteIssueStatus {
  activeSignals,
  recentSignals,
  noConfirmedIssue,
  unknown,
}

extension ClientCameraHealthStatusValue on ClientCameraHealthStatus {
  String get wireValue => switch (this) {
    ClientCameraHealthStatus.live => 'live',
    ClientCameraHealthStatus.limited => 'limited',
    ClientCameraHealthStatus.offline => 'offline',
  };
}

extension ClientCameraHealthReasonValue on ClientCameraHealthReason {
  String get wireValue => switch (this) {
    ClientCameraHealthReason.credentialsMissing => 'credentials_missing',
    ClientCameraHealthReason.bridgeOffline => 'bridge_offline',
    ClientCameraHealthReason.recorderUnreachable => 'recorder_unreachable',
    ClientCameraHealthReason.legacyProxyActive => 'legacy_proxy_active',
    ClientCameraHealthReason.unknown => 'unknown',
  };
}

extension ClientCameraHealthPathValue on ClientCameraHealthPath {
  String get wireValue => switch (this) {
    ClientCameraHealthPath.hikConnectApi => 'hik_connect_api',
    ClientCameraHealthPath.legacyLocalProxy => 'legacy_local_proxy',
    ClientCameraHealthPath.directRecorder => 'direct_recorder',
    ClientCameraHealthPath.unknown => 'unknown',
  };
}

extension ClientCameraRelayStatusValue on ClientCameraRelayStatus {
  String get wireValue => switch (this) {
    ClientCameraRelayStatus.active => 'active',
    ClientCameraRelayStatus.ready => 'ready',
    ClientCameraRelayStatus.starting => 'starting',
    ClientCameraRelayStatus.stale => 'stale',
    ClientCameraRelayStatus.error => 'error',
    ClientCameraRelayStatus.idle => 'idle',
    ClientCameraRelayStatus.unknown => 'unknown',
  };
}

extension ClientLiveSiteMovementStatusValue on ClientLiveSiteMovementStatus {
  String get wireValue => switch (this) {
    ClientLiveSiteMovementStatus.active => 'active',
    ClientLiveSiteMovementStatus.recentSignals => 'recent_signals',
    ClientLiveSiteMovementStatus.noConfirmedMovement => 'no_confirmed_movement',
    ClientLiveSiteMovementStatus.unknown => 'unknown',
  };
}

extension ClientLiveSiteIssueStatusValue on ClientLiveSiteIssueStatus {
  String get wireValue => switch (this) {
    ClientLiveSiteIssueStatus.activeSignals => 'active_signals',
    ClientLiveSiteIssueStatus.recentSignals => 'recent_signals',
    ClientLiveSiteIssueStatus.noConfirmedIssue => 'no_confirmed_issue',
    ClientLiveSiteIssueStatus.unknown => 'unknown',
  };
}

class LocalHikvisionDvrProxyHealthSnapshot {
  final Uri healthEndpoint;
  final Uri? proxyEndpoint;
  final Uri? upstreamAlertStreamUri;
  final bool reachable;
  final bool running;
  final String upstreamStreamStatus;
  final bool upstreamStreamConnected;
  final int bufferedAlertCount;
  final DateTime? lastAlertAtUtc;
  final DateTime? lastSuccessAtUtc;
  final String lastError;

  const LocalHikvisionDvrProxyHealthSnapshot({
    required this.healthEndpoint,
    this.proxyEndpoint,
    this.upstreamAlertStreamUri,
    required this.reachable,
    required this.running,
    this.upstreamStreamStatus = 'disconnected',
    this.upstreamStreamConnected = false,
    this.bufferedAlertCount = 0,
    this.lastAlertAtUtc,
    this.lastSuccessAtUtc,
    this.lastError = '',
  });
}

class LocalHikvisionDvrVisualProbeSnapshot {
  final Uri snapshotUri;
  final String cameraId;
  final bool reachable;
  final DateTime? verifiedAtUtc;
  final String lastError;

  const LocalHikvisionDvrVisualProbeSnapshot({
    required this.snapshotUri,
    required this.cameraId,
    required this.reachable,
    this.verifiedAtUtc,
    this.lastError = '',
  });
}

class LocalHikvisionDvrRelayProbeSnapshot {
  final Uri streamUri;
  final Uri playerUri;
  final Uri? statusUri;
  final bool streamReachable;
  final bool playerReachable;
  final DateTime? checkedAtUtc;
  final DateTime? verifiedAtUtc;
  final ClientCameraRelayStatus relayStatus;
  final DateTime? lastFrameAtUtc;
  final int activeClientCount;
  final String lastError;

  const LocalHikvisionDvrRelayProbeSnapshot({
    required this.streamUri,
    required this.playerUri,
    this.statusUri,
    required this.streamReachable,
    required this.playerReachable,
    this.checkedAtUtc,
    this.verifiedAtUtc,
    this.relayStatus = ClientCameraRelayStatus.unknown,
    this.lastFrameAtUtc,
    this.activeClientCount = 0,
    this.lastError = '',
  });

  bool get ready => streamReachable && playerReachable && verifiedAtUtc != null;
}

abstract class LocalHikvisionDvrProxyHealthService {
  Future<LocalHikvisionDvrProxyHealthSnapshot?> read(Uri eventsUri);
}

abstract class LocalHikvisionDvrVisualProbeService {
  Future<LocalHikvisionDvrVisualProbeSnapshot?> read(
    DvrScopeConfig scope, {
    Iterable<IntelligenceReceived> recentIntelligence =
        const <IntelligenceReceived>[],
  });
}

abstract class LocalHikvisionDvrRelayProbeService {
  Future<LocalHikvisionDvrRelayProbeSnapshot?> read(
    LocalHikvisionDvrVisualProbeSnapshot visualProbe,
  );
}

class HttpLocalHikvisionDvrProxyHealthService
    implements LocalHikvisionDvrProxyHealthService {
  final http.Client client;
  final Duration timeout;

  const HttpLocalHikvisionDvrProxyHealthService({
    required this.client,
    this.timeout = const Duration(seconds: 2),
  });

  @override
  Future<LocalHikvisionDvrProxyHealthSnapshot?> read(Uri eventsUri) async {
    final healthUri = eventsUri.replace(
      path: '/health',
      query: null,
      fragment: null,
    );
    try {
      final response = await client
          .get(healthUri, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return LocalHikvisionDvrProxyHealthSnapshot(
          healthEndpoint: healthUri,
          reachable: false,
          running: false,
          lastError: 'Proxy health HTTP ${response.statusCode}',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return LocalHikvisionDvrProxyHealthSnapshot(
          healthEndpoint: healthUri,
          reachable: false,
          running: false,
          lastError: 'Proxy health returned an invalid payload.',
        );
      }
      final map = decoded.cast<Object?, Object?>();
      final upstreamStreamConnected = map['upstream_stream_connected'] == true;
      return LocalHikvisionDvrProxyHealthSnapshot(
        healthEndpoint: healthUri,
        proxyEndpoint: Uri.tryParse((map['endpoint'] ?? '').toString().trim()),
        upstreamAlertStreamUri: Uri.tryParse(
          (map['upstream_alert_stream'] ?? '').toString().trim(),
        ),
        reachable: true,
        running: map['running'] != false,
        upstreamStreamStatus: _normalizedLocalProxyUpstreamStreamStatus(
          (map['upstream_stream_status'] ?? '').toString(),
          connected: upstreamStreamConnected,
        ),
        upstreamStreamConnected: upstreamStreamConnected,
        bufferedAlertCount:
            int.tryParse((map['buffered_alert_count'] ?? '').toString()) ?? 0,
        lastAlertAtUtc: DateTime.tryParse(
          (map['last_alert_at_utc'] ?? '').toString().trim(),
        )?.toUtc(),
        lastSuccessAtUtc: DateTime.tryParse(
          (map['last_success_at_utc'] ?? '').toString().trim(),
        )?.toUtc(),
        lastError: (map['last_error'] ?? '').toString().trim(),
      );
    } catch (error) {
      return LocalHikvisionDvrProxyHealthSnapshot(
        healthEndpoint: healthUri,
        reachable: false,
        running: false,
        lastError: error.toString(),
      );
    }
  }
}

String _normalizedLocalProxyUpstreamStreamStatus(
  String raw, {
  required bool connected,
}) {
  final normalized = raw.trim().toLowerCase();
  if (normalized == 'connected' ||
      normalized == 'reconnecting' ||
      normalized == 'disconnected') {
    return normalized;
  }
  return connected ? 'connected' : 'disconnected';
}

class HttpLocalHikvisionDvrVisualProbeService
    implements LocalHikvisionDvrVisualProbeService {
  final http.Client client;
  final Duration timeout;

  const HttpLocalHikvisionDvrVisualProbeService({
    required this.client,
    this.timeout = const Duration(seconds: 3),
  });

  @override
  Future<LocalHikvisionDvrVisualProbeSnapshot?> read(
    DvrScopeConfig scope, {
    Iterable<IntelligenceReceived> recentIntelligence =
        const <IntelligenceReceived>[],
  }) async {
    final baseUri = scope.eventsUri;
    final profile = DvrProviderProfile.fromProvider(scope.provider);
    if (baseUri == null || profile == null) {
      return null;
    }
    final auth = DvrHttpAuthConfig(
      mode: parseDvrHttpAuthMode(scope.authMode),
      bearerToken: scope.bearerToken.trim().isEmpty ? null : scope.bearerToken,
      username: scope.username.trim().isEmpty ? null : scope.username,
      password: scope.password.isEmpty ? null : scope.password,
    );

    Uri? lastTriedUri;
    String lastCameraId = 'channel-unknown';
    String lastError = '';
    for (final channelId in _candidateChannelIds(
      scope,
      recentIntelligence: recentIntelligence,
    )) {
      final snapshotUrl = profile.buildSnapshotUrl(
        baseUri,
        'visual-probe',
        channelId: channelId,
      );
      if (snapshotUrl == null || snapshotUrl.trim().isEmpty) {
        continue;
      }
      final snapshotUri = Uri.tryParse(snapshotUrl);
      if (snapshotUri == null) {
        continue;
      }
      lastTriedUri = snapshotUri;
      lastCameraId = 'channel-$channelId';
      try {
        final head = await auth.head(client, snapshotUri).timeout(timeout);
        if (head.statusCode >= 200 && head.statusCode < 300) {
          return LocalHikvisionDvrVisualProbeSnapshot(
            snapshotUri: snapshotUri,
            cameraId: lastCameraId,
            reachable: true,
            verifiedAtUtc: DateTime.now().toUtc(),
          );
        }
        if (head.statusCode == 405 ||
            head.statusCode == 403 ||
            head.statusCode == 400) {
          final get = await auth
              .get(client, snapshotUri, headers: const {'Range': 'bytes=0-0'})
              .timeout(timeout);
          if (get.statusCode >= 200 && get.statusCode < 300) {
            return LocalHikvisionDvrVisualProbeSnapshot(
              snapshotUri: snapshotUri,
              cameraId: lastCameraId,
              reachable: true,
              verifiedAtUtc: DateTime.now().toUtc(),
            );
          }
          lastError = 'Snapshot probe HTTP ${get.statusCode}';
          continue;
        }
        lastError = 'Snapshot probe HTTP ${head.statusCode}';
      } catch (error) {
        lastError = error.toString();
      }
    }

    if (lastTriedUri == null) {
      return null;
    }
    return LocalHikvisionDvrVisualProbeSnapshot(
      snapshotUri: lastTriedUri,
      cameraId: lastCameraId,
      reachable: false,
      lastError: lastError,
    );
  }

  List<String> _candidateChannelIds(
    DvrScopeConfig scope, {
    required Iterable<IntelligenceReceived> recentIntelligence,
  }) {
    final candidates = <String>[];
    final seen = <String>{};

    void addCandidate(String raw) {
      final match = RegExp(r'(\d+)').firstMatch(raw.trim());
      final digits = match?.group(1) ?? '';
      final parsed = int.tryParse(digits);
      if (parsed == null || parsed <= 0) {
        return;
      }
      final normalized = '$parsed';
      if (seen.add(normalized)) {
        candidates.add(normalized);
      }
    }

    final recent =
        recentIntelligence
            .where(
              (event) =>
                  event.clientId.trim() == scope.clientId.trim() &&
                  event.siteId.trim() == scope.siteId.trim(),
            )
            .toList(growable: false)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    for (final event in recent) {
      addCandidate(event.cameraId ?? '');
    }
    for (final label in scope.cameraLabels.keys) {
      addCandidate(label);
    }
    for (var channel = 1; channel <= 16; channel += 1) {
      addCandidate('$channel');
    }
    return candidates;
  }
}

class HttpLocalHikvisionDvrRelayProbeService
    implements LocalHikvisionDvrRelayProbeService {
  final http.Client client;
  final Duration timeout;

  const HttpLocalHikvisionDvrRelayProbeService({
    required this.client,
    this.timeout = const Duration(seconds: 3),
  });

  @override
  Future<LocalHikvisionDvrRelayProbeSnapshot?> read(
    LocalHikvisionDvrVisualProbeSnapshot visualProbe,
  ) async {
    if (!visualProbe.reachable) {
      return null;
    }
    final snapshotUri = visualProbe.snapshotUri;
    final streamId = _streamIdFromSnapshotUri(snapshotUri);
    if (streamId == null || !_isLocalRelayHost(snapshotUri.host)) {
      return null;
    }
    final streamUri = snapshotUri.replace(
      path: '/onyx/live/channels/$streamId.mjpg',
      queryParameters: null,
      fragment: null,
    );
    final playerUri = snapshotUri.replace(
      path: '/onyx/live/channels/$streamId/player',
      queryParameters: null,
      fragment: null,
    );
    final statusUri = snapshotUri.replace(
      path: '/onyx/live/channels/$streamId/status',
      queryParameters: null,
      fragment: null,
    );

    var streamReachable = false;
    var playerReachable = false;
    var relayStatus = ClientCameraRelayStatus.unknown;
    DateTime? lastFrameAtUtc;
    var activeClientCount = 0;
    var lastError = '';

    try {
      final statusResponse = await client
          .get(statusUri, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
      if (statusResponse.statusCode >= 200 && statusResponse.statusCode < 300) {
        final decoded = jsonDecode(statusResponse.body);
        if (decoded is Map) {
          final map = decoded.cast<Object?, Object?>();
          relayStatus = _parseRelayStatus((map['status'] ?? '').toString());
          lastFrameAtUtc = DateTime.tryParse(
            (map['last_frame_at_utc'] ?? '').toString().trim(),
          )?.toUtc();
          activeClientCount =
              int.tryParse((map['active_clients'] ?? '').toString().trim()) ??
              0;
          final statusError = (map['last_error'] ?? '').toString().trim();
          if (statusError.isNotEmpty) {
            lastError = statusError;
          }
        } else {
          lastError = 'Relay status returned an invalid payload.';
        }
      } else if (statusResponse.statusCode != 404) {
        lastError = 'Relay status HTTP ${statusResponse.statusCode}';
      }
    } catch (error) {
      if (lastError.isEmpty) {
        lastError = error.toString();
      }
    }

    try {
      final streamHead = await client.head(streamUri).timeout(timeout);
      streamReachable =
          streamHead.statusCode >= 200 && streamHead.statusCode < 300;
      if (!streamReachable) {
        lastError = 'Relay stream HTTP ${streamHead.statusCode}';
      }
    } catch (error) {
      lastError = error.toString();
    }

    try {
      final playerHead = await client.head(playerUri).timeout(timeout);
      playerReachable =
          playerHead.statusCode >= 200 && playerHead.statusCode < 300;
      if (!playerReachable && lastError.isEmpty) {
        lastError = 'Relay player HTTP ${playerHead.statusCode}';
      }
    } catch (error) {
      if (lastError.isEmpty) {
        lastError = error.toString();
      }
    }

    final checkedAtUtc = DateTime.now().toUtc();
    return LocalHikvisionDvrRelayProbeSnapshot(
      streamUri: streamUri,
      playerUri: playerUri,
      statusUri: statusUri,
      streamReachable: streamReachable,
      playerReachable: playerReachable,
      checkedAtUtc: checkedAtUtc,
      verifiedAtUtc: streamReachable && playerReachable ? checkedAtUtc : null,
      relayStatus: relayStatus,
      lastFrameAtUtc: lastFrameAtUtc,
      activeClientCount: activeClientCount,
      lastError: lastError,
    );
  }

  String? _streamIdFromSnapshotUri(Uri snapshotUri) {
    final match = RegExp(
      r'^/ISAPI/Streaming/channels/(\d+)/picture$',
      caseSensitive: false,
    ).firstMatch(snapshotUri.path);
    return match?.group(1);
  }

  bool _isLocalRelayHost(String host) {
    final normalized = host.trim().toLowerCase();
    return normalized == '127.0.0.1' || normalized == 'localhost';
  }

  ClientCameraRelayStatus _parseRelayStatus(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'active' => ClientCameraRelayStatus.active,
      'ready' => ClientCameraRelayStatus.ready,
      'starting' => ClientCameraRelayStatus.starting,
      'stale' => ClientCameraRelayStatus.stale,
      'error' => ClientCameraRelayStatus.error,
      'idle' => ClientCameraRelayStatus.idle,
      _ => ClientCameraRelayStatus.unknown,
    };
  }
}

class ClientCameraHealthFactPacket {
  final String clientId;
  final String siteId;
  final String siteReference;
  final ClientCameraHealthStatus status;
  final ClientCameraHealthReason reason;
  final ClientCameraHealthPath path;
  final DateTime? lastSuccessfulVisualAtUtc;
  final DateTime? lastSuccessfulUpstreamProbeAtUtc;
  final Uri? localProxyEndpoint;
  final Uri? localProxyUpstreamAlertStreamUri;
  final bool? localProxyReachable;
  final bool? localProxyRunning;
  final String? localProxyUpstreamStreamStatus;
  final bool? localProxyUpstreamStreamConnected;
  final int? localProxyBufferedAlertCount;
  final DateTime? localProxyLastAlertAtUtc;
  final DateTime? localProxyLastSuccessAtUtc;
  final String? localProxyLastError;
  final Uri? currentVisualSnapshotUri;
  final Uri? currentVisualRelayStreamUri;
  final Uri? currentVisualRelayPlayerUri;
  final String? currentVisualCameraId;
  final DateTime? currentVisualVerifiedAtUtc;
  final DateTime? currentVisualRelayCheckedAtUtc;
  final ClientCameraRelayStatus? currentVisualRelayStatus;
  final DateTime? currentVisualRelayLastFrameAtUtc;
  final int? currentVisualRelayActiveClientCount;
  final String? currentVisualRelayLastError;
  final String? continuousVisualWatchStatus;
  final String? continuousVisualWatchSummary;
  final DateTime? continuousVisualWatchLastSweepAtUtc;
  final DateTime? continuousVisualWatchLastCandidateAtUtc;
  final int? continuousVisualWatchReachableCameraCount;
  final int? continuousVisualWatchBaselineReadyCameraCount;
  final String? continuousVisualWatchHotCameraId;
  final String? continuousVisualWatchHotCameraLabel;
  final String? continuousVisualWatchHotZoneLabel;
  final String? continuousVisualWatchHotAreaLabel;
  final String? continuousVisualWatchHotWatchRuleKey;
  final String? continuousVisualWatchHotWatchPriorityLabel;
  final int? continuousVisualWatchHotCameraChangeStreakCount;
  final String? continuousVisualWatchHotCameraChangeStage;
  final DateTime? continuousVisualWatchHotCameraChangeActiveSinceUtc;
  final double? continuousVisualWatchHotCameraSceneDeltaScore;
  final String? continuousVisualWatchCorrelatedContextLabel;
  final String? continuousVisualWatchCorrelatedAreaLabel;
  final String? continuousVisualWatchCorrelatedZoneLabel;
  final String? continuousVisualWatchCorrelatedWatchRuleKey;
  final String? continuousVisualWatchCorrelatedWatchPriorityLabel;
  final String? continuousVisualWatchCorrelatedChangeStage;
  final DateTime? continuousVisualWatchCorrelatedActiveSinceUtc;
  final int? continuousVisualWatchCorrelatedCameraCount;
  final List<String> continuousVisualWatchCorrelatedCameraLabels;
  final String? continuousVisualWatchPostureKey;
  final String? continuousVisualWatchPostureLabel;
  final String? continuousVisualWatchAttentionLabel;
  final String? continuousVisualWatchSourceLabel;
  final ClientLiveSiteMovementStatus liveSiteMovementStatus;
  final ClientLiveSiteIssueStatus liveSiteIssueStatus;
  final DateTime? lastMovementSignalAtUtc;
  final int recentMovementSignalCount;
  final String? recentMovementSignalLabel;
  final String? recentIssueSignalLabel;
  final String? recentMovementHotspotLabel;
  final String? recentMovementObjectLabel;
  final String nextAction;
  final String safeClientExplanation;

  const ClientCameraHealthFactPacket({
    required this.clientId,
    required this.siteId,
    required this.siteReference,
    required this.status,
    required this.reason,
    required this.path,
    required this.lastSuccessfulVisualAtUtc,
    required this.lastSuccessfulUpstreamProbeAtUtc,
    this.localProxyEndpoint,
    this.localProxyUpstreamAlertStreamUri,
    this.localProxyReachable,
    this.localProxyRunning,
    this.localProxyUpstreamStreamStatus,
    this.localProxyUpstreamStreamConnected,
    this.localProxyBufferedAlertCount,
    this.localProxyLastAlertAtUtc,
    this.localProxyLastSuccessAtUtc,
    this.localProxyLastError,
    this.currentVisualSnapshotUri,
    this.currentVisualRelayStreamUri,
    this.currentVisualRelayPlayerUri,
    this.currentVisualCameraId,
    this.currentVisualVerifiedAtUtc,
    this.currentVisualRelayCheckedAtUtc,
    this.currentVisualRelayStatus,
    this.currentVisualRelayLastFrameAtUtc,
    this.currentVisualRelayActiveClientCount,
    this.currentVisualRelayLastError,
    this.continuousVisualWatchStatus,
    this.continuousVisualWatchSummary,
    this.continuousVisualWatchLastSweepAtUtc,
    this.continuousVisualWatchLastCandidateAtUtc,
    this.continuousVisualWatchReachableCameraCount,
    this.continuousVisualWatchBaselineReadyCameraCount,
    this.continuousVisualWatchHotCameraId,
    this.continuousVisualWatchHotCameraLabel,
    this.continuousVisualWatchHotZoneLabel,
    this.continuousVisualWatchHotAreaLabel,
    this.continuousVisualWatchHotWatchRuleKey,
    this.continuousVisualWatchHotWatchPriorityLabel,
    this.continuousVisualWatchHotCameraChangeStreakCount,
    this.continuousVisualWatchHotCameraChangeStage,
    this.continuousVisualWatchHotCameraChangeActiveSinceUtc,
    this.continuousVisualWatchHotCameraSceneDeltaScore,
    this.continuousVisualWatchCorrelatedContextLabel,
    this.continuousVisualWatchCorrelatedAreaLabel,
    this.continuousVisualWatchCorrelatedZoneLabel,
    this.continuousVisualWatchCorrelatedWatchRuleKey,
    this.continuousVisualWatchCorrelatedWatchPriorityLabel,
    this.continuousVisualWatchCorrelatedChangeStage,
    this.continuousVisualWatchCorrelatedActiveSinceUtc,
    this.continuousVisualWatchCorrelatedCameraCount,
    this.continuousVisualWatchCorrelatedCameraLabels = const <String>[],
    this.continuousVisualWatchPostureKey,
    this.continuousVisualWatchPostureLabel,
    this.continuousVisualWatchAttentionLabel,
    this.continuousVisualWatchSourceLabel,
    this.liveSiteMovementStatus = ClientLiveSiteMovementStatus.unknown,
    this.liveSiteIssueStatus = ClientLiveSiteIssueStatus.unknown,
    this.lastMovementSignalAtUtc,
    this.recentMovementSignalCount = 0,
    this.recentMovementSignalLabel,
    this.recentIssueSignalLabel,
    this.recentMovementHotspotLabel,
    this.recentMovementObjectLabel,
    required this.nextAction,
    required this.safeClientExplanation,
  });

  ClientCameraHealthFactPacket copyWith({
    String? siteReference,
    ClientCameraHealthStatus? status,
    ClientCameraHealthReason? reason,
    DateTime? lastSuccessfulVisualAtUtc,
    DateTime? lastSuccessfulUpstreamProbeAtUtc,
    ClientLiveSiteMovementStatus? liveSiteMovementStatus,
    ClientLiveSiteIssueStatus? liveSiteIssueStatus,
    DateTime? lastMovementSignalAtUtc,
    int? recentMovementSignalCount,
    String? recentMovementSignalLabel,
    String? recentIssueSignalLabel,
    String? recentMovementHotspotLabel,
    String? recentMovementObjectLabel,
    String? nextAction,
    String? safeClientExplanation,
  }) {
    return ClientCameraHealthFactPacket(
      clientId: clientId,
      siteId: siteId,
      siteReference: siteReference ?? this.siteReference,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      path: path,
      lastSuccessfulVisualAtUtc:
          lastSuccessfulVisualAtUtc ?? this.lastSuccessfulVisualAtUtc,
      lastSuccessfulUpstreamProbeAtUtc:
          lastSuccessfulUpstreamProbeAtUtc ??
          this.lastSuccessfulUpstreamProbeAtUtc,
      localProxyEndpoint: localProxyEndpoint,
      localProxyUpstreamAlertStreamUri: localProxyUpstreamAlertStreamUri,
      localProxyReachable: localProxyReachable,
      localProxyRunning: localProxyRunning,
      localProxyUpstreamStreamStatus: localProxyUpstreamStreamStatus,
      localProxyUpstreamStreamConnected: localProxyUpstreamStreamConnected,
      localProxyBufferedAlertCount: localProxyBufferedAlertCount,
      localProxyLastAlertAtUtc: localProxyLastAlertAtUtc,
      localProxyLastSuccessAtUtc: localProxyLastSuccessAtUtc,
      localProxyLastError: localProxyLastError,
      currentVisualSnapshotUri: currentVisualSnapshotUri,
      currentVisualRelayStreamUri: currentVisualRelayStreamUri,
      currentVisualRelayPlayerUri: currentVisualRelayPlayerUri,
      currentVisualCameraId: currentVisualCameraId,
      currentVisualVerifiedAtUtc: currentVisualVerifiedAtUtc,
      currentVisualRelayCheckedAtUtc: currentVisualRelayCheckedAtUtc,
      currentVisualRelayStatus: currentVisualRelayStatus,
      currentVisualRelayLastFrameAtUtc: currentVisualRelayLastFrameAtUtc,
      currentVisualRelayActiveClientCount: currentVisualRelayActiveClientCount,
      currentVisualRelayLastError: currentVisualRelayLastError,
      continuousVisualWatchStatus: continuousVisualWatchStatus,
      continuousVisualWatchSummary: continuousVisualWatchSummary,
      continuousVisualWatchLastSweepAtUtc: continuousVisualWatchLastSweepAtUtc,
      continuousVisualWatchLastCandidateAtUtc:
          continuousVisualWatchLastCandidateAtUtc,
      continuousVisualWatchReachableCameraCount:
          continuousVisualWatchReachableCameraCount,
      continuousVisualWatchBaselineReadyCameraCount:
          continuousVisualWatchBaselineReadyCameraCount,
      continuousVisualWatchHotCameraId: continuousVisualWatchHotCameraId,
      continuousVisualWatchHotCameraLabel: continuousVisualWatchHotCameraLabel,
      continuousVisualWatchHotZoneLabel: continuousVisualWatchHotZoneLabel,
      continuousVisualWatchHotAreaLabel: continuousVisualWatchHotAreaLabel,
      continuousVisualWatchHotWatchRuleKey:
          continuousVisualWatchHotWatchRuleKey,
      continuousVisualWatchHotWatchPriorityLabel:
          continuousVisualWatchHotWatchPriorityLabel,
      continuousVisualWatchHotCameraChangeStreakCount:
          continuousVisualWatchHotCameraChangeStreakCount,
      continuousVisualWatchHotCameraChangeStage:
          continuousVisualWatchHotCameraChangeStage,
      continuousVisualWatchHotCameraChangeActiveSinceUtc:
          continuousVisualWatchHotCameraChangeActiveSinceUtc,
      continuousVisualWatchHotCameraSceneDeltaScore:
          continuousVisualWatchHotCameraSceneDeltaScore,
      continuousVisualWatchCorrelatedContextLabel:
          continuousVisualWatchCorrelatedContextLabel,
      continuousVisualWatchCorrelatedAreaLabel:
          continuousVisualWatchCorrelatedAreaLabel,
      continuousVisualWatchCorrelatedZoneLabel:
          continuousVisualWatchCorrelatedZoneLabel,
      continuousVisualWatchCorrelatedWatchRuleKey:
          continuousVisualWatchCorrelatedWatchRuleKey,
      continuousVisualWatchCorrelatedWatchPriorityLabel:
          continuousVisualWatchCorrelatedWatchPriorityLabel,
      continuousVisualWatchCorrelatedChangeStage:
          continuousVisualWatchCorrelatedChangeStage,
      continuousVisualWatchCorrelatedActiveSinceUtc:
          continuousVisualWatchCorrelatedActiveSinceUtc,
      continuousVisualWatchCorrelatedCameraCount:
          continuousVisualWatchCorrelatedCameraCount,
      continuousVisualWatchCorrelatedCameraLabels:
          continuousVisualWatchCorrelatedCameraLabels,
      continuousVisualWatchPostureKey: continuousVisualWatchPostureKey,
      continuousVisualWatchPostureLabel: continuousVisualWatchPostureLabel,
      continuousVisualWatchAttentionLabel: continuousVisualWatchAttentionLabel,
      continuousVisualWatchSourceLabel: continuousVisualWatchSourceLabel,
      liveSiteMovementStatus:
          liveSiteMovementStatus ?? this.liveSiteMovementStatus,
      liveSiteIssueStatus: liveSiteIssueStatus ?? this.liveSiteIssueStatus,
      lastMovementSignalAtUtc:
          lastMovementSignalAtUtc ?? this.lastMovementSignalAtUtc,
      recentMovementSignalCount:
          recentMovementSignalCount ?? this.recentMovementSignalCount,
      recentMovementSignalLabel:
          recentMovementSignalLabel ?? this.recentMovementSignalLabel,
      recentIssueSignalLabel:
          recentIssueSignalLabel ?? this.recentIssueSignalLabel,
      recentMovementHotspotLabel:
          recentMovementHotspotLabel ?? this.recentMovementHotspotLabel,
      recentMovementObjectLabel:
          recentMovementObjectLabel ?? this.recentMovementObjectLabel,
      nextAction: nextAction ?? this.nextAction,
      safeClientExplanation:
          safeClientExplanation ?? this.safeClientExplanation,
    );
  }

  bool get hasLiveVisualAccess => status == ClientCameraHealthStatus.live;

  bool get hasScopedLocalProxyHealth => localProxyReachable != null;

  String get scopedLocalProxyStatusLabel {
    final upstreamStatus = (localProxyUpstreamStreamStatus ?? '')
        .trim()
        .toLowerCase();
    if (!hasScopedLocalProxyHealth) {
      return 'unknown';
    }
    if (localProxyReachable != true || localProxyRunning != true) {
      return 'offline';
    }
    if (upstreamStatus == 'connected' ||
        (upstreamStatus.isEmpty && localProxyUpstreamStreamConnected == true)) {
      return 'connected';
    }
    if (upstreamStatus == 'reconnecting') {
      return 'reconnecting';
    }
    if ((localProxyBufferedAlertCount ?? 0) > 0 ||
        localProxyLastSuccessAtUtc != null) {
      return 'ready';
    }
    if ((localProxyLastError ?? '').trim().isNotEmpty) {
      return 'degraded';
    }
    return 'ready';
  }

  bool get hasCurrentVisualConfirmation =>
      currentVisualSnapshotUri != null && currentVisualVerifiedAtUtc != null;

  bool get hasCurrentVisualStreamRelay =>
      currentVisualRelayStreamUri != null &&
      currentVisualRelayPlayerUri != null;

  bool get hasContinuousVisualCoverage {
    final normalized = _normalizedWatchValue(continuousVisualWatchStatus);
    return normalized == 'learning' ||
        normalized == 'active' ||
        normalized == 'alerting';
  }

  bool get hasActiveContinuousVisualChange {
    final normalizedStatus = _normalizedWatchValue(continuousVisualWatchStatus);
    return normalizedStatus == 'alerting' ||
        _isAlertStage(continuousVisualWatchHotCameraChangeStage) ||
        _isAlertStage(continuousVisualWatchCorrelatedChangeStage);
  }

  bool get hasOngoingContinuousVisualChange {
    final normalizedStatus = _normalizedWatchValue(continuousVisualWatchStatus);
    if (hasActiveContinuousVisualChange) {
      return true;
    }
    return normalizedStatus == 'active' &&
        (_isWatchingStage(continuousVisualWatchHotCameraChangeStage) ||
            _isWatchingStage(continuousVisualWatchCorrelatedChangeStage));
  }

  bool get hasRecentMovementSignals =>
      liveSiteMovementStatus == ClientLiveSiteMovementStatus.active ||
      liveSiteMovementStatus == ClientLiveSiteMovementStatus.recentSignals;

  bool get hasNoConfirmedMovement =>
      liveSiteMovementStatus ==
      ClientLiveSiteMovementStatus.noConfirmedMovement;

  bool get hasActiveSiteIssueSignals =>
      liveSiteIssueStatus == ClientLiveSiteIssueStatus.activeSignals;

  bool get hasRecentSiteIssueSignals =>
      liveSiteIssueStatus == ClientLiveSiteIssueStatus.activeSignals ||
      liveSiteIssueStatus == ClientLiveSiteIssueStatus.recentSignals;

  bool get hasNoConfirmedSiteIssue =>
      liveSiteIssueStatus == ClientLiveSiteIssueStatus.noConfirmedIssue;

  String? get continuousVisualHotspotLabel {
    final candidates = <String?>[
      continuousVisualWatchCorrelatedContextLabel,
      continuousVisualWatchCorrelatedAreaLabel,
      continuousVisualWatchHotAreaLabel,
      continuousVisualWatchHotZoneLabel,
      continuousVisualWatchHotCameraLabel,
      continuousVisualWatchHotCameraId,
    ];
    for (final candidate in candidates) {
      final normalized = candidate?.trim() ?? '';
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  String? get liveSiteMovementHotspotLabel {
    final candidates = <String?>[
      recentMovementHotspotLabel,
      continuousVisualHotspotLabel,
    ];
    for (final candidate in candidates) {
      final normalized = candidate?.trim() ?? '';
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  String? operatorIssueSignalLabel({String? preferredAreaLabel}) {
    if (!hasRecentSiteIssueSignals) {
      return null;
    }
    final scopedArea = preferredAreaLabel?.trim() ?? '';
    final label = _resolvedOperatorIssueSignalLabel(
      fallbackAreaLabel: scopedArea.isEmpty ? null : scopedArea,
    );
    if (label == null) {
      return null;
    }
    if (scopedArea.isEmpty || _issueLabelMatchesArea(label, scopedArea)) {
      return label;
    }
    return null;
  }

  String get _continuousVisualWatchStatusLabel {
    final normalized = (continuousVisualWatchStatus ?? '').trim();
    return normalized.isEmpty ? 'unknown' : normalized;
  }

  static String _normalizedWatchValue(String? value) {
    return (value ?? '').trim().toLowerCase();
  }

  static bool _isAlertStage(String? stage) {
    final normalized = _normalizedWatchValue(stage);
    return normalized == 'sustained' || normalized == 'persistent';
  }

  static bool _isWatchingStage(String? stage) {
    final normalized = _normalizedWatchValue(stage);
    return normalized == 'watching' || _isAlertStage(stage);
  }

  String? _resolvedOperatorIssueSignalLabel({String? fallbackAreaLabel}) {
    final explicit = (recentIssueSignalLabel ?? '').trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }
    final hotspot = (liveSiteMovementHotspotLabel ?? fallbackAreaLabel ?? '')
        .trim();
    final objectLabel = (recentMovementObjectLabel ?? '').trim();
    if (hasActiveSiteIssueSignals) {
      if (hotspot.isNotEmpty && objectLabel.isNotEmpty) {
        return 'live $objectLabel activity around $hotspot';
      }
      if (hotspot.isNotEmpty) {
        return 'live activity around $hotspot';
      }
      if (objectLabel.isNotEmpty) {
        return 'live $objectLabel activity on site';
      }
      return 'live site activity';
    }
    if (liveSiteIssueStatus == ClientLiveSiteIssueStatus.recentSignals) {
      if (hotspot.isNotEmpty && objectLabel.isNotEmpty) {
        return 'recent $objectLabel activity around $hotspot';
      }
      if (hotspot.isNotEmpty) {
        return 'recent activity around $hotspot';
      }
      if (objectLabel.isNotEmpty) {
        return 'recent $objectLabel activity on site';
      }
      return 'recent site activity';
    }
    return null;
  }

  bool _issueLabelMatchesArea(String label, String areaLabel) {
    final normalizedLabel = _normalizeIssueAreaText(label);
    final normalizedArea = _normalizeIssueAreaText(areaLabel);
    if (normalizedLabel.isEmpty || normalizedArea.isEmpty) {
      return false;
    }
    return normalizedLabel.contains(normalizedArea) ||
        normalizedArea.contains(normalizedLabel);
  }

  String _normalizeIssueAreaText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _cameraFactValue(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? 'unknown' : normalized;
  }

  String get operatorSummary =>
      'camera_status=${status.wireValue} • '
      'camera_reason=${reason.wireValue} • '
      'camera_path=${path.wireValue} • '
      'local_proxy_status=$scopedLocalProxyStatusLabel • '
      'local_proxy_upstream_status=${_cameraFactValue(localProxyUpstreamStreamStatus)} • '
      'local_proxy_upstream_connected=${localProxyUpstreamStreamConnected == true ? 'true' : 'false'} • '
      'local_proxy_buffered_alerts=${localProxyBufferedAlertCount ?? 0} • '
      'local_proxy_last_alert_utc=${_utcLabel(localProxyLastAlertAtUtc)} • '
      'local_proxy_last_success_utc=${_utcLabel(localProxyLastSuccessAtUtc)} • '
      'stream_relay=${hasCurrentVisualStreamRelay ? 'ready' : 'unavailable'} • '
      'stream_relay_status=${(currentVisualRelayStatus ?? ClientCameraRelayStatus.unknown).wireValue} • '
      'continuous_visual_watch=$_continuousVisualWatchStatusLabel • '
      'stream_relay_checked_utc=${_utcLabel(currentVisualRelayCheckedAtUtc)} • '
      'continuous_visual_watch_last_sweep_utc=${_utcLabel(continuousVisualWatchLastSweepAtUtc)} • '
      'continuous_visual_watch_hot_camera=${(continuousVisualWatchHotCameraLabel ?? continuousVisualWatchHotCameraId ?? 'unknown').trim()} • '
      'continuous_visual_watch_hot_area=${(continuousVisualWatchHotAreaLabel ?? 'unknown').trim()} • '
      'continuous_visual_watch_hot_priority=${(continuousVisualWatchHotWatchPriorityLabel ?? 'unknown').trim()} • '
      'continuous_visual_watch_hot_stage=${(continuousVisualWatchHotCameraChangeStage ?? 'unknown').trim()} • '
      'continuous_visual_watch_correlated_context=${(continuousVisualWatchCorrelatedContextLabel ?? 'unknown').trim()} • '
      'continuous_visual_watch_posture=${(continuousVisualWatchPostureLabel ?? 'unknown').trim()} • '
      'continuous_visual_watch_attention=${(continuousVisualWatchAttentionLabel ?? 'unknown').trim()} • '
      'continuous_visual_watch_correlated_stage=${(continuousVisualWatchCorrelatedChangeStage ?? 'unknown').trim()} • '
      'stream_relay_last_frame_utc=${_utcLabel(currentVisualRelayLastFrameAtUtc)} • '
      'last_visual_utc=${_utcLabel(lastSuccessfulVisualAtUtc)} • '
      'current_visual_verified_utc=${_utcLabel(currentVisualVerifiedAtUtc)} • '
      'last_probe_utc=${_utcLabel(lastSuccessfulUpstreamProbeAtUtc)} • '
      'live_site_movement=${liveSiteMovementStatus.wireValue} • '
      'live_site_issue=${liveSiteIssueStatus.wireValue} • '
      'last_movement_signal_utc=${_utcLabel(lastMovementSignalAtUtc)}';

  String toPromptBlock() {
    return [
      '- camera_status: ${status.wireValue}',
      '- camera_reason: ${reason.wireValue}',
      '- camera_path: ${path.wireValue}',
      '- local_proxy_status: $scopedLocalProxyStatusLabel',
      '- local_proxy_upstream_status: ${_cameraFactValue(localProxyUpstreamStreamStatus)}',
      '- local_proxy_upstream_connected: ${localProxyUpstreamStreamConnected == true ? 'true' : 'false'}',
      '- local_proxy_buffered_alert_count: ${localProxyBufferedAlertCount ?? 0}',
      '- local_proxy_last_alert_utc: ${_utcLabel(localProxyLastAlertAtUtc)}',
      '- local_proxy_last_success_utc: ${_utcLabel(localProxyLastSuccessAtUtc)}',
      '- current_visual_stream_relay_ready: ${hasCurrentVisualStreamRelay ? 'true' : 'false'}',
      '- current_visual_stream_relay_status: ${(currentVisualRelayStatus ?? ClientCameraRelayStatus.unknown).wireValue}',
      '- current_visual_stream_relay_checked_utc: ${_utcLabel(currentVisualRelayCheckedAtUtc)}',
      '- continuous_visual_watch_status: $_continuousVisualWatchStatusLabel',
      '- continuous_visual_watch_last_sweep_utc: ${_utcLabel(continuousVisualWatchLastSweepAtUtc)}',
      '- continuous_visual_watch_last_candidate_utc: ${_utcLabel(continuousVisualWatchLastCandidateAtUtc)}',
      '- current_visual_stream_last_frame_utc: ${_utcLabel(currentVisualRelayLastFrameAtUtc)}',
      '- last_successful_visual_utc: ${_utcLabel(lastSuccessfulVisualAtUtc)}',
      '- current_visual_verified_utc: ${_utcLabel(currentVisualVerifiedAtUtc)}',
      if ((currentVisualCameraId ?? '').trim().isNotEmpty)
        '- current_visual_camera_id: ${currentVisualCameraId!.trim()}',
      if (currentVisualRelayActiveClientCount != null)
        '- current_visual_stream_active_clients: ${currentVisualRelayActiveClientCount!}',
      if (continuousVisualWatchReachableCameraCount != null)
        '- continuous_visual_watch_reachable_cameras: ${continuousVisualWatchReachableCameraCount!}',
      if (continuousVisualWatchBaselineReadyCameraCount != null)
        '- continuous_visual_watch_baseline_ready_cameras: ${continuousVisualWatchBaselineReadyCameraCount!}',
      if ((continuousVisualWatchPostureKey ?? '').trim().isNotEmpty)
        '- continuous_visual_watch_posture_key: ${continuousVisualWatchPostureKey!.trim()}',
      if ((continuousVisualWatchPostureLabel ?? '').trim().isNotEmpty)
        '- continuous_visual_watch_posture_label: ${continuousVisualWatchPostureLabel!.trim()}',
      if ((continuousVisualWatchAttentionLabel ?? '').trim().isNotEmpty)
        '- continuous_visual_watch_attention_label: ${continuousVisualWatchAttentionLabel!.trim()}',
      if ((continuousVisualWatchSourceLabel ?? '').trim().isNotEmpty)
        '- continuous_visual_watch_source_label: ${continuousVisualWatchSourceLabel!.trim()}',
      if ((continuousVisualWatchHotCameraId ?? '').trim().isNotEmpty)
        '- continuous_visual_watch_hot_camera_id: ${continuousVisualWatchHotCameraId!.trim()}',
      if ((continuousVisualWatchHotCameraLabel ?? '').trim().isNotEmpty)
        '- continuous_visual_watch_hot_camera_label: ${continuousVisualWatchHotCameraLabel!.trim()}',
      if ((continuousVisualWatchHotZoneLabel ?? '').trim().isNotEmpty)
        '- continuous_visual_watch_hot_zone_label: ${continuousVisualWatchHotZoneLabel!.trim()}',
      if ((continuousVisualWatchHotAreaLabel ?? '').trim().isNotEmpty)
        '- continuous_visual_watch_hot_area_label: ${continuousVisualWatchHotAreaLabel!.trim()}',
      if ((continuousVisualWatchHotWatchRuleKey ?? '').trim().isNotEmpty)
        '- continuous_visual_watch_hot_watch_rule_key: ${continuousVisualWatchHotWatchRuleKey!.trim()}',
      if ((continuousVisualWatchHotWatchPriorityLabel ?? '').trim().isNotEmpty)
        '- continuous_visual_watch_hot_watch_priority_label: ${continuousVisualWatchHotWatchPriorityLabel!.trim()}',
      if (continuousVisualWatchHotCameraChangeStreakCount != null)
        '- continuous_visual_watch_hot_camera_streak: ${continuousVisualWatchHotCameraChangeStreakCount!}',
      if ((continuousVisualWatchHotCameraChangeStage ?? '').trim().isNotEmpty)
        '- continuous_visual_watch_hot_camera_stage: ${continuousVisualWatchHotCameraChangeStage!.trim()}',
      if (continuousVisualWatchHotCameraChangeActiveSinceUtc != null)
        '- continuous_visual_watch_hot_camera_since_utc: ${_utcLabel(continuousVisualWatchHotCameraChangeActiveSinceUtc)}',
      if (continuousVisualWatchHotCameraSceneDeltaScore != null)
        '- continuous_visual_watch_hot_camera_delta_score: ${continuousVisualWatchHotCameraSceneDeltaScore!.toStringAsFixed(3)}',
      if ((continuousVisualWatchCorrelatedContextLabel ?? '').trim().isNotEmpty)
        '- continuous_visual_watch_correlated_context_label: ${continuousVisualWatchCorrelatedContextLabel!.trim()}',
      if ((continuousVisualWatchCorrelatedAreaLabel ?? '').trim().isNotEmpty)
        '- continuous_visual_watch_correlated_area_label: ${continuousVisualWatchCorrelatedAreaLabel!.trim()}',
      if ((continuousVisualWatchCorrelatedZoneLabel ?? '').trim().isNotEmpty)
        '- continuous_visual_watch_correlated_zone_label: ${continuousVisualWatchCorrelatedZoneLabel!.trim()}',
      if ((continuousVisualWatchCorrelatedWatchRuleKey ?? '').trim().isNotEmpty)
        '- continuous_visual_watch_correlated_watch_rule_key: ${continuousVisualWatchCorrelatedWatchRuleKey!.trim()}',
      if ((continuousVisualWatchCorrelatedWatchPriorityLabel ?? '')
          .trim()
          .isNotEmpty)
        '- continuous_visual_watch_correlated_watch_priority_label: ${continuousVisualWatchCorrelatedWatchPriorityLabel!.trim()}',
      if ((continuousVisualWatchCorrelatedChangeStage ?? '').trim().isNotEmpty)
        '- continuous_visual_watch_correlated_stage: ${continuousVisualWatchCorrelatedChangeStage!.trim()}',
      if (continuousVisualWatchCorrelatedActiveSinceUtc != null)
        '- continuous_visual_watch_correlated_since_utc: ${_utcLabel(continuousVisualWatchCorrelatedActiveSinceUtc)}',
      if (continuousVisualWatchCorrelatedCameraCount != null)
        '- continuous_visual_watch_correlated_camera_count: ${continuousVisualWatchCorrelatedCameraCount!}',
      if (continuousVisualWatchCorrelatedCameraLabels.isNotEmpty)
        '- continuous_visual_watch_correlated_camera_labels: ${continuousVisualWatchCorrelatedCameraLabels.join(', ')}',
      if ((continuousVisualWatchSummary ?? '').trim().isNotEmpty)
        '- continuous_visual_watch_summary: ${continuousVisualWatchSummary!.trim()}',
      '- live_site_movement_status: ${liveSiteMovementStatus.wireValue}',
      '- live_site_issue_status: ${liveSiteIssueStatus.wireValue}',
      '- last_movement_signal_utc: ${_utcLabel(lastMovementSignalAtUtc)}',
      '- recent_movement_signal_count: $recentMovementSignalCount',
      if ((recentMovementSignalLabel ?? '').trim().isNotEmpty)
        '- recent_movement_signal_label: ${recentMovementSignalLabel!.trim()}',
      if ((recentIssueSignalLabel ?? '').trim().isNotEmpty)
        '- recent_issue_signal_label: ${recentIssueSignalLabel!.trim()}',
      if ((recentMovementHotspotLabel ?? '').trim().isNotEmpty)
        '- recent_movement_hotspot_label: ${recentMovementHotspotLabel!.trim()}',
      if ((recentMovementObjectLabel ?? '').trim().isNotEmpty)
        '- recent_movement_object_label: ${recentMovementObjectLabel!.trim()}',
      if (currentVisualRelayStreamUri != null)
        '- current_visual_stream_relay_url: ${currentVisualRelayStreamUri!.toString()}',
      if (currentVisualRelayPlayerUri != null)
        '- current_visual_stream_player_url: ${currentVisualRelayPlayerUri!.toString()}',
      if ((currentVisualRelayLastError ?? '').trim().isNotEmpty)
        '- current_visual_stream_relay_error: ${currentVisualRelayLastError!.trim()}',
      if (localProxyEndpoint != null)
        '- local_proxy_health_url: ${localProxyEndpoint!.toString()}',
      if (localProxyUpstreamAlertStreamUri != null)
        '- local_proxy_upstream_alert_url: ${localProxyUpstreamAlertStreamUri!.toString()}',
      if ((localProxyLastError ?? '').trim().isNotEmpty)
        '- local_proxy_last_error: ${localProxyLastError!.trim()}',
      '- last_successful_upstream_probe_utc: ${_utcLabel(lastSuccessfulUpstreamProbeAtUtc)}',
      '- next_action: $nextAction',
      '- safe_client_explanation: $safeClientExplanation',
    ].join('\n');
  }

  static String _utcLabel(DateTime? value) {
    return value?.toUtc().toIso8601String() ?? 'unknown';
  }
}

ClientCameraHealthFactPacket reconcileClientCameraHealthWithSiteAwareness({
  required ClientCameraHealthFactPacket packet,
  required DateTime observedAtUtc,
  required bool perimeterClear,
  int humanCount = 0,
  int vehicleCount = 0,
  int animalCount = 0,
  int motionCount = 0,
}) {
  final normalizedObservedAtUtc = observedAtUtc.toUtc();
  final signalCount = humanCount + vehicleCount + animalCount + motionCount;
  final movementObjectLabel = _siteAwarenessMovementObjectLabel(
    humanCount: humanCount,
    vehicleCount: vehicleCount,
    animalCount: animalCount,
    motionCount: motionCount,
  );
  final movementSignalLabel = _siteAwarenessMovementSignalLabel(
    humanCount: humanCount,
    vehicleCount: vehicleCount,
    animalCount: animalCount,
    motionCount: motionCount,
  );
  final liveSiteMovementStatus = signalCount > 0
      ? ClientLiveSiteMovementStatus.active
      : packet.hasRecentMovementSignals
      ? packet.liveSiteMovementStatus
      : ClientLiveSiteMovementStatus.noConfirmedMovement;
  final liveSiteIssueStatus = perimeterClear
      ? (packet.hasRecentSiteIssueSignals
            ? packet.liveSiteIssueStatus
            : ClientLiveSiteIssueStatus.noConfirmedIssue)
      : ClientLiveSiteIssueStatus.activeSignals;
  final nextStatus = packet.status == ClientCameraHealthStatus.offline
      ? ClientCameraHealthStatus.limited
      : packet.status;
  final nextReason = nextStatus == ClientCameraHealthStatus.live
      ? packet.reason
      : packet.path == ClientCameraHealthPath.legacyLocalProxy
      ? ClientCameraHealthReason.legacyProxyActive
      : ClientCameraHealthReason.unknown;

  return packet.copyWith(
    status: nextStatus,
    reason: nextReason,
    lastSuccessfulUpstreamProbeAtUtc: _latestUtc(
      packet.lastSuccessfulUpstreamProbeAtUtc,
      normalizedObservedAtUtc,
    ),
    liveSiteMovementStatus: liveSiteMovementStatus,
    liveSiteIssueStatus: liveSiteIssueStatus,
    lastMovementSignalAtUtc: signalCount > 0
        ? _latestUtc(packet.lastMovementSignalAtUtc, normalizedObservedAtUtc)
        : packet.lastMovementSignalAtUtc,
    recentMovementSignalCount: signalCount > packet.recentMovementSignalCount
        ? signalCount
        : packet.recentMovementSignalCount,
    recentMovementSignalLabel:
        movementSignalLabel ?? packet.recentMovementSignalLabel,
    recentIssueSignalLabel: perimeterClear
        ? packet.recentIssueSignalLabel
        : 'active perimeter alert',
    recentMovementObjectLabel:
        movementObjectLabel ?? packet.recentMovementObjectLabel,
    nextAction: _siteAwarenessNextAction(
      siteReference: packet.siteReference,
      perimeterClear: perimeterClear,
    ),
    safeClientExplanation: _siteAwarenessSafeClientExplanation(
      siteReference: packet.siteReference,
      perimeterClear: perimeterClear,
      signalCount: signalCount,
      humanCount: humanCount,
    ),
  );
}

DateTime? _latestUtc(DateTime? first, DateTime? second) {
  final normalizedFirst = first?.toUtc();
  final normalizedSecond = second?.toUtc();
  if (normalizedFirst == null) {
    return normalizedSecond;
  }
  if (normalizedSecond == null) {
    return normalizedFirst;
  }
  return normalizedSecond.isAfter(normalizedFirst)
      ? normalizedSecond
      : normalizedFirst;
}

String? _siteAwarenessMovementObjectLabel({
  required int humanCount,
  required int vehicleCount,
  required int animalCount,
  required int motionCount,
}) {
  if (humanCount > 0) {
    return humanCount == 1 ? 'human' : 'humans';
  }
  if (vehicleCount > 0) {
    return vehicleCount == 1 ? 'vehicle' : 'vehicles';
  }
  if (animalCount > 0) {
    return animalCount == 1 ? 'animal' : 'animals';
  }
  if (motionCount > 0) {
    return 'movement';
  }
  return null;
}

String? _siteAwarenessMovementSignalLabel({
  required int humanCount,
  required int vehicleCount,
  required int animalCount,
  required int motionCount,
}) {
  final labels = <String>[];
  if (humanCount > 0) {
    labels.add('$humanCount human${humanCount == 1 ? '' : 's'}');
  }
  if (vehicleCount > 0) {
    labels.add('$vehicleCount vehicle${vehicleCount == 1 ? '' : 's'}');
  }
  if (animalCount > 0) {
    labels.add('$animalCount animal${animalCount == 1 ? '' : 's'}');
  }
  if (motionCount > 0) {
    labels.add('$motionCount motion signal${motionCount == 1 ? '' : 's'}');
  }
  if (labels.isEmpty) {
    return null;
  }
  return 'live site awareness: ${labels.join(', ')}';
}

String _siteAwarenessNextAction({
  required String siteReference,
  required bool perimeterClear,
}) {
  final resolvedSiteReference = siteReference.trim().isEmpty
      ? 'the site'
      : siteReference.trim();
  if (!perimeterClear) {
    return 'Keep the live site-awareness feed under watch at $resolvedSiteReference and confirm the clearest visual view while the perimeter alert is active.';
  }
  return 'Keep the live site-awareness feed under watch at $resolvedSiteReference and confirm the clearest visual view before promising direct camera confirmation.';
}

String _siteAwarenessSafeClientExplanation({
  required String siteReference,
  required bool perimeterClear,
  required int signalCount,
  required int humanCount,
}) {
  final resolvedSiteReference = siteReference.trim().isEmpty
      ? 'the site'
      : siteReference.trim();
  if (!perimeterClear) {
    return 'I have live site-awareness signals at $resolvedSiteReference right now, including an active perimeter alert, and I am verifying the clearest visual view.';
  }
  if (humanCount > 0) {
    return 'I have live site-awareness signals at $resolvedSiteReference right now. The latest snapshot shows people on site with no perimeter breach.';
  }
  if (signalCount > 0) {
    return 'I have live site-awareness signals at $resolvedSiteReference right now, and there are no active perimeter alerts in the latest snapshot.';
  }
  return 'I have live site-awareness signals at $resolvedSiteReference right now. There are no active alerts in the latest snapshot.';
}

class ClientCameraHealthFactPacketService {
  final Duration recentVisualWindow;
  final Duration recentProbeWindow;
  final Duration recentMovementSignalWindow;

  const ClientCameraHealthFactPacketService({
    this.recentVisualWindow = const Duration(hours: 2),
    this.recentProbeWindow = const Duration(minutes: 45),
    this.recentMovementSignalWindow = const Duration(minutes: 20),
  });

  ClientCameraHealthFactPacket build({
    required String clientId,
    required String siteId,
    required String siteReference,
    DvrScopeConfig? scope,
    DvrBridgeHealthSnapshot? dvrBridgeHealth,
    VideoEvidenceProbeSnapshot? evidenceSnapshot,
    MonitoringWatchRuntimeState? watchRuntime,
    Iterable<IntelligenceReceived> recentIntelligence =
        const <IntelligenceReceived>[],
    LocalHikvisionDvrProxyHealthSnapshot? localProxyHealth,
    LocalHikvisionDvrVisualProbeSnapshot? localVisualProbe,
    LocalHikvisionDvrRelayProbeSnapshot? localRelayProbe,
    MonitoringWatchContinuousVisualScopeSnapshot? continuousVisualWatch,
    DateTime? nowUtc,
  }) {
    final resolvedNowUtc = (nowUtc ?? DateTime.now()).toUtc();
    final path = _resolvePath(scope);
    final lastSuccessfulVisualAtUtc = _lastSuccessfulVisualAtUtc(
      clientId: clientId,
      siteId: siteId,
      evidenceSnapshot: evidenceSnapshot,
      recentIntelligence: recentIntelligence,
      localVisualProbe: localVisualProbe,
    );
    final lastSuccessfulUpstreamProbeAtUtc = _lastSuccessfulProbeAtUtc(
      clientId: clientId,
      siteId: siteId,
      dvrBridgeHealth: dvrBridgeHealth,
      evidenceSnapshot: evidenceSnapshot,
      recentIntelligence: recentIntelligence,
      localProxyHealth: localProxyHealth,
      localRelayProbe: localRelayProbe,
    );
    final localProxyEndpoint = localProxyHealth?.proxyEndpoint;
    final localProxyUpstreamAlertStreamUri =
        localProxyHealth?.upstreamAlertStreamUri;
    final localProxyReachable = localProxyHealth?.reachable;
    final localProxyRunning = localProxyHealth?.running;
    final localProxyUpstreamStreamStatus =
        localProxyHealth?.upstreamStreamStatus;
    final localProxyUpstreamStreamConnected =
        localProxyHealth?.upstreamStreamConnected;
    final localProxyBufferedAlertCount = localProxyHealth?.bufferedAlertCount;
    final localProxyLastAlertAtUtc = localProxyHealth?.lastAlertAtUtc?.toUtc();
    final localProxyLastSuccessAtUtc = localProxyHealth?.lastSuccessAtUtc
        ?.toUtc();
    final localProxyLastError =
        (localProxyHealth?.lastError ?? '').trim().isEmpty
        ? null
        : localProxyHealth!.lastError.trim();
    final currentVisualSnapshotUri =
        localVisualProbe != null &&
            localVisualProbe.reachable &&
            localVisualProbe.verifiedAtUtc != null
        ? localVisualProbe.snapshotUri
        : null;
    final currentVisualCameraId = currentVisualSnapshotUri == null
        ? null
        : localVisualProbe!.cameraId.trim();
    final currentVisualVerifiedAtUtc = currentVisualSnapshotUri == null
        ? null
        : localVisualProbe!.verifiedAtUtc?.toUtc();
    final currentVisualRelayStreamUri =
        currentVisualSnapshotUri == null || localRelayProbe?.ready != true
        ? null
        : localRelayProbe!.streamUri;
    final currentVisualRelayPlayerUri =
        currentVisualSnapshotUri == null || localRelayProbe?.ready != true
        ? null
        : localRelayProbe!.playerUri;
    final currentVisualRelayCheckedAtUtc = localRelayProbe?.checkedAtUtc
        ?.toUtc();
    final currentVisualRelayStatus = localRelayProbe?.relayStatus;
    final currentVisualRelayLastFrameAtUtc = localRelayProbe?.lastFrameAtUtc
        ?.toUtc();
    final currentVisualRelayActiveClientCount =
        localRelayProbe?.activeClientCount;
    final currentVisualRelayLastError =
        (localRelayProbe?.lastError ?? '').trim().isEmpty
        ? null
        : localRelayProbe!.lastError.trim();
    final continuousVisualWatchStatus = continuousVisualWatch?.status.wireValue;
    final continuousVisualWatchSummary = continuousVisualWatch?.summary.trim();
    final continuousVisualWatchLastSweepAtUtc = continuousVisualWatch
        ?.lastSweepAtUtc
        ?.toUtc();
    final continuousVisualWatchLastCandidateAtUtc = continuousVisualWatch
        ?.lastCandidateAtUtc
        ?.toUtc();
    final continuousVisualWatchReachableCameraCount =
        continuousVisualWatch?.reachableCameraCount;
    final continuousVisualWatchBaselineReadyCameraCount =
        continuousVisualWatch?.baselineReadyCameraCount;
    final continuousVisualWatchHotCameraId = continuousVisualWatch?.hotCameraId
        ?.trim();
    final continuousVisualWatchHotCameraLabel = continuousVisualWatch
        ?.hotCameraLabel
        ?.trim();
    final continuousVisualWatchHotZoneLabel = continuousVisualWatch
        ?.hotZoneLabel
        ?.trim();
    final continuousVisualWatchHotAreaLabel = continuousVisualWatch
        ?.hotAreaLabel
        ?.trim();
    final continuousVisualWatchHotWatchRuleKey = continuousVisualWatch
        ?.hotWatchRuleKey
        ?.trim();
    final continuousVisualWatchHotWatchPriorityLabel = continuousVisualWatch
        ?.hotWatchPriorityLabel
        ?.trim();
    final continuousVisualWatchHotCameraChangeStreakCount =
        continuousVisualWatch?.hotCameraChangeStreakCount;
    final continuousVisualWatchHotCameraChangeStage =
        continuousVisualWatch?.hotCameraChangeStage?.wireValue;
    final continuousVisualWatchHotCameraChangeActiveSinceUtc =
        continuousVisualWatch?.hotCameraChangeActiveSinceUtc?.toUtc();
    final continuousVisualWatchHotCameraSceneDeltaScore =
        continuousVisualWatch?.hotCameraSceneDeltaScore;
    final continuousVisualWatchCorrelatedContextLabel = continuousVisualWatch
        ?.correlatedContextLabel
        ?.trim();
    final continuousVisualWatchCorrelatedAreaLabel = continuousVisualWatch
        ?.correlatedAreaLabel
        ?.trim();
    final continuousVisualWatchCorrelatedZoneLabel = continuousVisualWatch
        ?.correlatedZoneLabel
        ?.trim();
    final continuousVisualWatchCorrelatedWatchRuleKey = continuousVisualWatch
        ?.correlatedWatchRuleKey
        ?.trim();
    final continuousVisualWatchCorrelatedWatchPriorityLabel =
        continuousVisualWatch?.correlatedWatchPriorityLabel?.trim();
    final continuousVisualWatchCorrelatedChangeStage =
        continuousVisualWatch?.correlatedChangeStage?.wireValue;
    final continuousVisualWatchCorrelatedActiveSinceUtc = continuousVisualWatch
        ?.correlatedActiveSinceUtc
        ?.toUtc();
    final continuousVisualWatchCorrelatedCameraCount =
        continuousVisualWatch?.correlatedCameraCount;
    final continuousVisualWatchCorrelatedCameraLabels =
        continuousVisualWatch?.correlatedCameraLabels
            .where((label) => label.trim().isNotEmpty)
            .map((label) => label.trim())
            .toList(growable: false) ??
        const <String>[];
    final continuousVisualWatchPostureKey = continuousVisualWatch
        ?.watchPostureKey
        ?.trim();
    final continuousVisualWatchPostureLabel = continuousVisualWatch
        ?.watchPostureLabel
        ?.trim();
    final continuousVisualWatchAttentionLabel = continuousVisualWatch
        ?.watchAttentionLabel
        ?.trim();
    final continuousVisualWatchSourceLabel = continuousVisualWatch
        ?.watchSourceLabel
        ?.trim();
    final recentMovementSignals = _recentMovementSignals(
      clientId: clientId,
      siteId: siteId,
      recentIntelligence: recentIntelligence,
      nowUtc: resolvedNowUtc,
    );
    final reason = _resolveReason(
      scope: scope,
      path: path,
      evidenceSnapshot: evidenceSnapshot,
      watchRuntime: watchRuntime,
      localProxyHealth: localProxyHealth,
      localRelayProbe: localRelayProbe,
      dvrBridgeHealth: dvrBridgeHealth,
      lastSuccessfulUpstreamProbeAtUtc: lastSuccessfulUpstreamProbeAtUtc,
      nowUtc: resolvedNowUtc,
    );
    final status = _resolveStatus(
      path: path,
      reason: reason,
      evidenceSnapshot: evidenceSnapshot,
      watchRuntime: watchRuntime,
      localProxyHealth: localProxyHealth,
      localRelayProbe: localRelayProbe,
      lastSuccessfulVisualAtUtc: lastSuccessfulVisualAtUtc,
      lastSuccessfulUpstreamProbeAtUtc: lastSuccessfulUpstreamProbeAtUtc,
      nowUtc: resolvedNowUtc,
    );
    final liveSiteMovementStatus = _resolveLiveSiteMovementStatus(
      status: status,
      continuousVisualWatchStatus: continuousVisualWatchStatus,
      continuousVisualWatchHotCameraChangeStage:
          continuousVisualWatchHotCameraChangeStage,
      continuousVisualWatchCorrelatedChangeStage:
          continuousVisualWatchCorrelatedChangeStage,
      recentMovementSignals: recentMovementSignals,
      currentVisualSnapshotUri: currentVisualSnapshotUri,
      currentVisualRelayStreamUri: currentVisualRelayStreamUri,
    );
    final liveSiteIssueStatus = _resolveLiveSiteIssueStatus(
      liveSiteMovementStatus: liveSiteMovementStatus,
      status: status,
      continuousVisualWatchStatus: continuousVisualWatchStatus,
      currentVisualSnapshotUri: currentVisualSnapshotUri,
      currentVisualRelayStreamUri: currentVisualRelayStreamUri,
    );
    return ClientCameraHealthFactPacket(
      clientId: clientId.trim(),
      siteId: siteId.trim(),
      siteReference: siteReference.trim().isEmpty
          ? 'the site'
          : siteReference.trim(),
      status: status,
      reason: reason,
      path: path,
      lastSuccessfulVisualAtUtc: lastSuccessfulVisualAtUtc,
      lastSuccessfulUpstreamProbeAtUtc: lastSuccessfulUpstreamProbeAtUtc,
      localProxyEndpoint: localProxyEndpoint,
      localProxyUpstreamAlertStreamUri: localProxyUpstreamAlertStreamUri,
      localProxyReachable: localProxyReachable,
      localProxyRunning: localProxyRunning,
      localProxyUpstreamStreamStatus: localProxyUpstreamStreamStatus,
      localProxyUpstreamStreamConnected: localProxyUpstreamStreamConnected,
      localProxyBufferedAlertCount: localProxyBufferedAlertCount,
      localProxyLastAlertAtUtc: localProxyLastAlertAtUtc,
      localProxyLastSuccessAtUtc: localProxyLastSuccessAtUtc,
      localProxyLastError: localProxyLastError,
      currentVisualSnapshotUri: currentVisualSnapshotUri,
      currentVisualRelayStreamUri: currentVisualRelayStreamUri,
      currentVisualRelayPlayerUri: currentVisualRelayPlayerUri,
      currentVisualCameraId: currentVisualCameraId,
      currentVisualVerifiedAtUtc: currentVisualVerifiedAtUtc,
      currentVisualRelayCheckedAtUtc: currentVisualRelayCheckedAtUtc,
      currentVisualRelayStatus: currentVisualRelayStatus,
      currentVisualRelayLastFrameAtUtc: currentVisualRelayLastFrameAtUtc,
      currentVisualRelayActiveClientCount: currentVisualRelayActiveClientCount,
      currentVisualRelayLastError: currentVisualRelayLastError,
      continuousVisualWatchStatus: continuousVisualWatchStatus,
      continuousVisualWatchSummary:
          continuousVisualWatchSummary?.isEmpty == true
          ? null
          : continuousVisualWatchSummary,
      continuousVisualWatchLastSweepAtUtc: continuousVisualWatchLastSweepAtUtc,
      continuousVisualWatchLastCandidateAtUtc:
          continuousVisualWatchLastCandidateAtUtc,
      continuousVisualWatchReachableCameraCount:
          continuousVisualWatchReachableCameraCount,
      continuousVisualWatchBaselineReadyCameraCount:
          continuousVisualWatchBaselineReadyCameraCount,
      continuousVisualWatchHotCameraId:
          continuousVisualWatchHotCameraId?.isEmpty == true
          ? null
          : continuousVisualWatchHotCameraId,
      continuousVisualWatchHotCameraLabel:
          continuousVisualWatchHotCameraLabel?.isEmpty == true
          ? null
          : continuousVisualWatchHotCameraLabel,
      continuousVisualWatchHotZoneLabel:
          continuousVisualWatchHotZoneLabel?.isEmpty == true
          ? null
          : continuousVisualWatchHotZoneLabel,
      continuousVisualWatchHotAreaLabel:
          continuousVisualWatchHotAreaLabel?.isEmpty == true
          ? null
          : continuousVisualWatchHotAreaLabel,
      continuousVisualWatchHotWatchRuleKey:
          continuousVisualWatchHotWatchRuleKey?.isEmpty == true
          ? null
          : continuousVisualWatchHotWatchRuleKey,
      continuousVisualWatchHotWatchPriorityLabel:
          continuousVisualWatchHotWatchPriorityLabel?.isEmpty == true
          ? null
          : continuousVisualWatchHotWatchPriorityLabel,
      continuousVisualWatchHotCameraChangeStreakCount:
          continuousVisualWatchHotCameraChangeStreakCount,
      continuousVisualWatchHotCameraChangeStage:
          continuousVisualWatchHotCameraChangeStage?.isEmpty == true
          ? null
          : continuousVisualWatchHotCameraChangeStage,
      continuousVisualWatchHotCameraChangeActiveSinceUtc:
          continuousVisualWatchHotCameraChangeActiveSinceUtc,
      continuousVisualWatchHotCameraSceneDeltaScore:
          continuousVisualWatchHotCameraSceneDeltaScore,
      continuousVisualWatchCorrelatedContextLabel:
          continuousVisualWatchCorrelatedContextLabel?.isEmpty == true
          ? null
          : continuousVisualWatchCorrelatedContextLabel,
      continuousVisualWatchCorrelatedAreaLabel:
          continuousVisualWatchCorrelatedAreaLabel?.isEmpty == true
          ? null
          : continuousVisualWatchCorrelatedAreaLabel,
      continuousVisualWatchCorrelatedZoneLabel:
          continuousVisualWatchCorrelatedZoneLabel?.isEmpty == true
          ? null
          : continuousVisualWatchCorrelatedZoneLabel,
      continuousVisualWatchCorrelatedWatchRuleKey:
          continuousVisualWatchCorrelatedWatchRuleKey?.isEmpty == true
          ? null
          : continuousVisualWatchCorrelatedWatchRuleKey,
      continuousVisualWatchCorrelatedWatchPriorityLabel:
          continuousVisualWatchCorrelatedWatchPriorityLabel?.isEmpty == true
          ? null
          : continuousVisualWatchCorrelatedWatchPriorityLabel,
      continuousVisualWatchCorrelatedChangeStage:
          continuousVisualWatchCorrelatedChangeStage?.isEmpty == true
          ? null
          : continuousVisualWatchCorrelatedChangeStage,
      continuousVisualWatchCorrelatedActiveSinceUtc:
          continuousVisualWatchCorrelatedActiveSinceUtc,
      continuousVisualWatchCorrelatedCameraCount:
          continuousVisualWatchCorrelatedCameraCount,
      continuousVisualWatchCorrelatedCameraLabels:
          continuousVisualWatchCorrelatedCameraLabels,
      continuousVisualWatchPostureKey:
          continuousVisualWatchPostureKey?.isEmpty == true
          ? null
          : continuousVisualWatchPostureKey,
      continuousVisualWatchPostureLabel:
          continuousVisualWatchPostureLabel?.isEmpty == true
          ? null
          : continuousVisualWatchPostureLabel,
      continuousVisualWatchAttentionLabel:
          continuousVisualWatchAttentionLabel?.isEmpty == true
          ? null
          : continuousVisualWatchAttentionLabel,
      continuousVisualWatchSourceLabel:
          continuousVisualWatchSourceLabel?.isEmpty == true
          ? null
          : continuousVisualWatchSourceLabel,
      liveSiteMovementStatus: liveSiteMovementStatus,
      liveSiteIssueStatus: liveSiteIssueStatus,
      lastMovementSignalAtUtc: recentMovementSignals.lastOccurredAtUtc,
      recentMovementSignalCount: recentMovementSignals.count,
      recentMovementSignalLabel: recentMovementSignals.label?.isEmpty == true
          ? null
          : recentMovementSignals.label,
      recentIssueSignalLabel: recentMovementSignals.issueLabel?.isEmpty == true
          ? null
          : recentMovementSignals.issueLabel,
      recentMovementHotspotLabel:
          recentMovementSignals.hotspotLabel?.isEmpty == true
          ? null
          : recentMovementSignals.hotspotLabel,
      recentMovementObjectLabel:
          recentMovementSignals.objectLabel?.isEmpty == true
          ? null
          : recentMovementSignals.objectLabel,
      nextAction: _nextAction(status: status, reason: reason, path: path),
      safeClientExplanation: _safeClientExplanation(
        siteReference: siteReference,
        status: status,
        reason: reason,
        path: path,
      ),
    );
  }

  ClientCameraHealthPath _resolvePath(DvrScopeConfig? scope) {
    final normalizedProvider = _normalizedProvider(scope?.provider ?? '');
    if (_providerUsesHikConnect(normalizedProvider)) {
      return ClientCameraHealthPath.hikConnectApi;
    }
    final eventsUri = scope?.eventsUri;
    if (eventsUri == null) {
      return ClientCameraHealthPath.unknown;
    }
    final host = eventsUri.host.trim().toLowerCase();
    if (host == '127.0.0.1' || host == 'localhost') {
      return ClientCameraHealthPath.legacyLocalProxy;
    }
    return ClientCameraHealthPath.directRecorder;
  }

  ClientCameraHealthReason _resolveReason({
    required DvrScopeConfig? scope,
    required ClientCameraHealthPath path,
    required VideoEvidenceProbeSnapshot? evidenceSnapshot,
    required MonitoringWatchRuntimeState? watchRuntime,
    required LocalHikvisionDvrProxyHealthSnapshot? localProxyHealth,
    required LocalHikvisionDvrRelayProbeSnapshot? localRelayProbe,
    required DvrBridgeHealthSnapshot? dvrBridgeHealth,
    required DateTime? lastSuccessfulUpstreamProbeAtUtc,
    required DateTime nowUtc,
  }) {
    final detailParts = <String>[
      if ((watchRuntime?.monitoringAvailabilityDetail ?? '').trim().isNotEmpty)
        watchRuntime!.monitoringAvailabilityDetail,
      if ((evidenceSnapshot?.lastAlert ?? '').trim().isNotEmpty)
        evidenceSnapshot!.lastAlert,
      if ((localProxyHealth?.lastError ?? '').trim().isNotEmpty)
        localProxyHealth!.lastError,
      if ((dvrBridgeHealth?.lastError ?? '').trim().isNotEmpty)
        dvrBridgeHealth!.lastError,
    ];
    final detail = detailParts.join(' ').toLowerCase();
    final relayBridgeAvailable = _relayBridgeLooksAvailable(localRelayProbe);
    final recentUpstreamSignalFresh =
        lastSuccessfulUpstreamProbeAtUtc != null &&
        nowUtc.difference(lastSuccessfulUpstreamProbeAtUtc).abs() <=
            recentProbeWindow;

    if (path == ClientCameraHealthPath.hikConnectApi &&
        (scope == null || !scope.hikConnectConfigured)) {
      return ClientCameraHealthReason.credentialsMissing;
    }
    if (path == ClientCameraHealthPath.legacyLocalProxy &&
        localProxyHealth != null &&
        (!localProxyHealth.reachable || !localProxyHealth.running) &&
        !relayBridgeAvailable) {
      return ClientCameraHealthReason.bridgeOffline;
    }
    if (_containsAny(detail, const [
      'scope fetch failed',
      'verification is failing',
      'failing verification',
      'proxy health http',
      'upstream',
      'timed out',
      'connection reset',
      'connection refused',
      'dvr bridge http',
      'http 5',
      'http 4',
    ])) {
      if (recentUpstreamSignalFresh) {
        return path == ClientCameraHealthPath.legacyLocalProxy &&
                (localProxyHealth?.lastSuccessAtUtc != null ||
                    relayBridgeAvailable)
            ? ClientCameraHealthReason.legacyProxyActive
            : ClientCameraHealthReason.unknown;
      }
      return path == ClientCameraHealthPath.legacyLocalProxy &&
              localProxyHealth != null &&
              (!localProxyHealth.reachable || !localProxyHealth.running) &&
              !relayBridgeAvailable
          ? ClientCameraHealthReason.bridgeOffline
          : relayBridgeAvailable
          ? ClientCameraHealthReason.legacyProxyActive
          : ClientCameraHealthReason.recorderUnreachable;
    }
    if (path == ClientCameraHealthPath.legacyLocalProxy &&
        (localProxyHealth?.lastSuccessAtUtc != null || relayBridgeAvailable)) {
      return ClientCameraHealthReason.legacyProxyActive;
    }
    return ClientCameraHealthReason.unknown;
  }

  ClientCameraHealthStatus _resolveStatus({
    required ClientCameraHealthPath path,
    required ClientCameraHealthReason reason,
    required VideoEvidenceProbeSnapshot? evidenceSnapshot,
    required MonitoringWatchRuntimeState? watchRuntime,
    required LocalHikvisionDvrProxyHealthSnapshot? localProxyHealth,
    required LocalHikvisionDvrRelayProbeSnapshot? localRelayProbe,
    required DateTime? lastSuccessfulVisualAtUtc,
    required DateTime? lastSuccessfulUpstreamProbeAtUtc,
    required DateTime nowUtc,
  }) {
    final monitoringAvailable =
        watchRuntime?.monitoringAvailable ??
        _monitoringAvailable(evidenceSnapshot);
    final visualFresh =
        lastSuccessfulVisualAtUtc != null &&
        nowUtc.difference(lastSuccessfulVisualAtUtc).abs() <=
            recentVisualWindow;
    final verifiedVisualProbeFresh =
        evidenceSnapshot?.lastRunAtUtc != null &&
        evidenceSnapshot!.verifiedCount > 0 &&
        evidenceSnapshot.failureCount <= 0 &&
        evidenceSnapshot.droppedCount <= 0 &&
        nowUtc.difference(evidenceSnapshot.lastRunAtUtc!).abs() <=
            recentProbeWindow;
    final probeFresh =
        lastSuccessfulUpstreamProbeAtUtc != null &&
        nowUtc.difference(lastSuccessfulUpstreamProbeAtUtc).abs() <=
            recentProbeWindow;
    final relayBridgeAvailable = _relayBridgeLooksAvailable(localRelayProbe);
    final relayFrameFresh = _relayFrameLooksFresh(localRelayProbe, nowUtc);

    if (reason == ClientCameraHealthReason.bridgeOffline ||
        reason == ClientCameraHealthReason.recorderUnreachable) {
      return ClientCameraHealthStatus.offline;
    }
    if (path == ClientCameraHealthPath.hikConnectApi &&
        reason == ClientCameraHealthReason.credentialsMissing) {
      return ClientCameraHealthStatus.offline;
    }
    if (visualFresh ||
        relayFrameFresh ||
        (monitoringAvailable && verifiedVisualProbeFresh)) {
      return ClientCameraHealthStatus.live;
    }
    if (path == ClientCameraHealthPath.legacyLocalProxy &&
        localProxyHealth != null &&
        localProxyHealth.reachable &&
        localProxyHealth.running) {
      return ClientCameraHealthStatus.limited;
    }
    if (path == ClientCameraHealthPath.legacyLocalProxy &&
        relayBridgeAvailable) {
      return ClientCameraHealthStatus.limited;
    }
    if (visualFresh ||
        probeFresh ||
        reason == ClientCameraHealthReason.legacyProxyActive ||
        (watchRuntime?.monitoringAvailabilityDetail ?? '').trim().isNotEmpty ||
        (evidenceSnapshot?.lastAlert ?? '').trim().isNotEmpty) {
      return ClientCameraHealthStatus.limited;
    }
    return ClientCameraHealthStatus.offline;
  }

  DateTime? _lastSuccessfulVisualAtUtc({
    required String clientId,
    required String siteId,
    required VideoEvidenceProbeSnapshot? evidenceSnapshot,
    required Iterable<IntelligenceReceived> recentIntelligence,
    required LocalHikvisionDvrVisualProbeSnapshot? localVisualProbe,
  }) {
    DateTime? latest = localVisualProbe?.verifiedAtUtc?.toUtc();
    for (final camera
        in evidenceSnapshot?.cameras ?? const <VideoCameraHealth>[]) {
      final hasVerifiedVisual =
          camera.snapshotVerified > 0 || camera.clipVerified > 0;
      if (!hasVerifiedVisual || camera.lastSeenAtUtc == null) {
        continue;
      }
      if (latest == null || camera.lastSeenAtUtc!.isAfter(latest)) {
        latest = camera.lastSeenAtUtc;
      }
    }
    for (final event in recentIntelligence) {
      if (event.clientId.trim() != clientId.trim() ||
          event.siteId.trim() != siteId.trim()) {
        continue;
      }
      final sourceType = event.sourceType.trim().toLowerCase();
      if (sourceType != 'dvr' &&
          sourceType != 'hardware' &&
          sourceType != 'cctv') {
        continue;
      }
      final hasVisualEvidence =
          (event.snapshotUrl ?? '').trim().isNotEmpty ||
          (event.clipUrl ?? '').trim().isNotEmpty ||
          (event.snapshotReferenceHash ?? '').trim().isNotEmpty ||
          (event.clipReferenceHash ?? '').trim().isNotEmpty ||
          (event.evidenceRecordHash ?? '').trim().isNotEmpty;
      if (!hasVisualEvidence) {
        continue;
      }
      if (latest == null || event.occurredAt.isAfter(latest)) {
        latest = event.occurredAt.toUtc();
      }
    }
    return latest?.toUtc();
  }

  DateTime? _lastSuccessfulProbeAtUtc({
    required String clientId,
    required String siteId,
    required DvrBridgeHealthSnapshot? dvrBridgeHealth,
    required VideoEvidenceProbeSnapshot? evidenceSnapshot,
    required Iterable<IntelligenceReceived> recentIntelligence,
    required LocalHikvisionDvrProxyHealthSnapshot? localProxyHealth,
    required LocalHikvisionDvrRelayProbeSnapshot? localRelayProbe,
  }) {
    DateTime? latest;

    void consider(DateTime? candidate) {
      final normalized = candidate?.toUtc();
      if (normalized == null) {
        return;
      }
      if (latest == null || normalized.isAfter(latest!)) {
        latest = normalized;
      }
    }

    consider(localProxyHealth?.lastSuccessAtUtc);
    consider(localRelayProbe?.verifiedAtUtc);
    consider(dvrBridgeHealth?.lastHealthyAtUtc);

    if (evidenceSnapshot == null || evidenceSnapshot.lastRunAtUtc == null) {
      consider(
        _lastSuccessfulUpstreamSignalAtUtc(
          clientId: clientId,
          siteId: siteId,
          recentIntelligence: recentIntelligence,
        ),
      );
      return latest;
    }
    if (evidenceSnapshot.verifiedCount <= 0 ||
        evidenceSnapshot.failureCount > 0 ||
        evidenceSnapshot.droppedCount > 0) {
      consider(
        _lastSuccessfulUpstreamSignalAtUtc(
          clientId: clientId,
          siteId: siteId,
          recentIntelligence: recentIntelligence,
        ),
      );
      return latest;
    }
    consider(evidenceSnapshot.lastRunAtUtc);
    return latest;
  }

  DateTime? _lastSuccessfulUpstreamSignalAtUtc({
    required String clientId,
    required String siteId,
    required Iterable<IntelligenceReceived> recentIntelligence,
  }) {
    DateTime? latest;
    for (final event in recentIntelligence) {
      if (event.clientId.trim() != clientId.trim() ||
          event.siteId.trim() != siteId.trim()) {
        continue;
      }
      final sourceType = event.sourceType.trim().toLowerCase();
      if (sourceType != 'dvr' &&
          sourceType != 'hardware' &&
          sourceType != 'cctv') {
        continue;
      }
      final occurredAtUtc = event.occurredAt.toUtc();
      if (latest == null || occurredAtUtc.isAfter(latest)) {
        latest = occurredAtUtc;
      }
    }
    return latest;
  }

  bool _relayBridgeLooksAvailable(
    LocalHikvisionDvrRelayProbeSnapshot? localRelayProbe,
  ) {
    if (localRelayProbe == null) {
      return false;
    }
    return localRelayProbe.ready ||
        (localRelayProbe.streamReachable && localRelayProbe.playerReachable) ||
        localRelayProbe.relayStatus == ClientCameraRelayStatus.active ||
        localRelayProbe.relayStatus == ClientCameraRelayStatus.ready;
  }

  bool _relayFrameLooksFresh(
    LocalHikvisionDvrRelayProbeSnapshot? localRelayProbe,
    DateTime nowUtc,
  ) {
    final lastFrameAtUtc = localRelayProbe?.lastFrameAtUtc?.toUtc();
    if (lastFrameAtUtc == null) {
      return false;
    }
    return nowUtc.difference(lastFrameAtUtc).abs() <= recentVisualWindow;
  }

  bool _monitoringAvailable(VideoEvidenceProbeSnapshot? snapshot) {
    if (snapshot == null) {
      return false;
    }
    if (snapshot.failureCount > 0 ||
        snapshot.droppedCount > 0 ||
        snapshot.lastAlert.trim().isNotEmpty) {
      return false;
    }
    return !snapshot.cameras.any((camera) {
      final normalized = camera.status.trim().toLowerCase();
      return normalized == 'degraded' || normalized == 'stale';
    });
  }

  String _nextAction({
    required ClientCameraHealthStatus status,
    required ClientCameraHealthReason reason,
    required ClientCameraHealthPath path,
  }) {
    if (reason == ClientCameraHealthReason.legacyProxyActive) {
      return 'Keep the legacy local Hikvision proxy on 127.0.0.1:11635 in place until the Hik-Connect credentials arrive, then switch this site to the Hik-Connect API path.';
    }
    if (reason == ClientCameraHealthReason.credentialsMissing) {
      return 'Wait for the approved Hik-Connect credentials, keep the current fallback path where available, and only switch this site to the Hik-Connect API path once those credentials arrive.';
    }
    if (reason == ClientCameraHealthReason.bridgeOffline) {
      return 'Restore the local camera bridge and confirm a healthy upstream alert stream before promising live camera access.';
    }
    if (reason == ClientCameraHealthReason.recorderUnreachable) {
      return 'Verify the recorder on the approved path and confirm a successful upstream probe before promising live camera access.';
    }
    return switch (status) {
      ClientCameraHealthStatus.live =>
        'Keep the current monitoring path under watch and only change the site path after a confirmed cutover.',
      ClientCameraHealthStatus.limited =>
        'Recheck the monitoring path and confirm the next successful probe before promising live camera access.',
      ClientCameraHealthStatus.offline =>
        'Verify the current monitoring path and confirm a successful probe before promising live camera access.',
    };
  }

  String _safeClientExplanation({
    required String siteReference,
    required ClientCameraHealthStatus status,
    required ClientCameraHealthReason reason,
    required ClientCameraHealthPath path,
  }) {
    final resolvedSiteReference = siteReference.trim().isEmpty
        ? 'the site'
        : siteReference.trim();
    if (status == ClientCameraHealthStatus.live) {
      return 'We currently have visual confirmation at $resolvedSiteReference.';
    }
    if (status == ClientCameraHealthStatus.limited) {
      switch (reason) {
        case ClientCameraHealthReason.credentialsMissing:
          return 'Live camera visibility at $resolvedSiteReference is limited right now while access is being restored.';
        case ClientCameraHealthReason.bridgeOffline:
          return 'Live camera visibility at $resolvedSiteReference is limited right now.';
        case ClientCameraHealthReason.recorderUnreachable:
          return 'Live camera visibility at $resolvedSiteReference is limited right now.';
        case ClientCameraHealthReason.legacyProxyActive:
          return 'I still have site signals for $resolvedSiteReference, but I cannot rely on them alone as a clean live view right now.';
        case ClientCameraHealthReason.unknown:
          if (path == ClientCameraHealthPath.legacyLocalProxy) {
            return 'I still have site signals for $resolvedSiteReference, but I am verifying the latest visual view before I overstate what I can confirm.';
          }
          return 'Live camera visibility at $resolvedSiteReference is limited right now while I verify the latest view.';
      }
    }
    switch (reason) {
      case ClientCameraHealthReason.credentialsMissing:
        return 'Live camera visibility at $resolvedSiteReference is unavailable right now.';
      case ClientCameraHealthReason.bridgeOffline:
        return 'Live camera visibility at $resolvedSiteReference is unavailable right now.';
      case ClientCameraHealthReason.recorderUnreachable:
        return 'Live camera visibility at $resolvedSiteReference is unavailable right now.';
      case ClientCameraHealthReason.legacyProxyActive:
        return 'Live camera visibility at $resolvedSiteReference is unavailable right now.';
      case ClientCameraHealthReason.unknown:
        return 'Live camera visibility at $resolvedSiteReference is unavailable right now.';
    }
  }

  _RecentMovementSignals _recentMovementSignals({
    required String clientId,
    required String siteId,
    required Iterable<IntelligenceReceived> recentIntelligence,
    required DateTime nowUtc,
  }) {
    final matchingSignals =
        recentIntelligence
            .where(
              (event) =>
                  event.clientId.trim() == clientId.trim() &&
                  event.siteId.trim() == siteId.trim() &&
                  nowUtc.difference(event.occurredAt.toUtc()).abs() <=
                      recentMovementSignalWindow &&
                  _intelligenceImpliesMovement(event),
            )
            .toList(growable: false)
          ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
    if (matchingSignals.isEmpty) {
      return const _RecentMovementSignals();
    }
    final latest = matchingSignals.first;
    return _RecentMovementSignals(
      lastOccurredAtUtc: latest.occurredAt.toUtc(),
      count: matchingSignals.length,
      label: _movementSignalLabelFor(latest, count: matchingSignals.length),
      issueLabel: _issueSignalLabelFor(latest, count: matchingSignals.length),
      hotspotLabel: _movementHotspotLabelFor(latest),
      objectLabel: _movementSemanticLabelFor(latest),
    );
  }

  ClientLiveSiteMovementStatus _resolveLiveSiteMovementStatus({
    required ClientCameraHealthStatus status,
    required String? continuousVisualWatchStatus,
    required String? continuousVisualWatchHotCameraChangeStage,
    required String? continuousVisualWatchCorrelatedChangeStage,
    required _RecentMovementSignals recentMovementSignals,
    required Uri? currentVisualSnapshotUri,
    required Uri? currentVisualRelayStreamUri,
  }) {
    final normalizedWatchStatus =
        ClientCameraHealthFactPacket._normalizedWatchValue(
          continuousVisualWatchStatus,
        );
    final hotStageActive =
        ClientCameraHealthFactPacket._isWatchingStage(
          continuousVisualWatchHotCameraChangeStage,
        ) ||
        ClientCameraHealthFactPacket._isWatchingStage(
          continuousVisualWatchCorrelatedChangeStage,
        );
    if (normalizedWatchStatus == 'alerting' || hotStageActive) {
      return ClientLiveSiteMovementStatus.active;
    }
    if (recentMovementSignals.count > 0) {
      return ClientLiveSiteMovementStatus.recentSignals;
    }
    final hasVisualCoverage =
        status != ClientCameraHealthStatus.offline ||
        currentVisualSnapshotUri != null ||
        currentVisualRelayStreamUri != null ||
        normalizedWatchStatus == 'learning' ||
        normalizedWatchStatus == 'active';
    if (hasVisualCoverage) {
      return ClientLiveSiteMovementStatus.noConfirmedMovement;
    }
    return ClientLiveSiteMovementStatus.unknown;
  }

  ClientLiveSiteIssueStatus _resolveLiveSiteIssueStatus({
    required ClientLiveSiteMovementStatus liveSiteMovementStatus,
    required ClientCameraHealthStatus status,
    required String? continuousVisualWatchStatus,
    required Uri? currentVisualSnapshotUri,
    required Uri? currentVisualRelayStreamUri,
  }) {
    if (liveSiteMovementStatus == ClientLiveSiteMovementStatus.active) {
      return ClientLiveSiteIssueStatus.activeSignals;
    }
    if (liveSiteMovementStatus == ClientLiveSiteMovementStatus.recentSignals) {
      return ClientLiveSiteIssueStatus.recentSignals;
    }
    final normalizedWatchStatus =
        ClientCameraHealthFactPacket._normalizedWatchValue(
          continuousVisualWatchStatus,
        );
    final hasVisualCoverage =
        status != ClientCameraHealthStatus.offline ||
        currentVisualSnapshotUri != null ||
        currentVisualRelayStreamUri != null ||
        normalizedWatchStatus == 'learning' ||
        normalizedWatchStatus == 'active';
    if (hasVisualCoverage) {
      return ClientLiveSiteIssueStatus.noConfirmedIssue;
    }
    return ClientLiveSiteIssueStatus.unknown;
  }

  bool _intelligenceImpliesMovement(IntelligenceReceived event) {
    final objectLabel = _movementSemanticLabelFor(event);
    if (objectLabel != null) {
      return true;
    }
    final combined = [
      event.headline,
      event.summary,
      event.zone ?? '',
      event.cameraId ?? '',
    ].join(' ').toLowerCase();
    if (_containsAny(combined, const [
      'videoloss',
      'video loss',
      'offline',
      'signal loss',
      'tamper cleared',
      'tamper clear',
    ])) {
      return false;
    }
    return _containsAny(combined, const [
      'motion',
      'movement',
      'moving',
      'person',
      'human',
      'vehicle',
      'car',
      'backpack',
      'bag',
      'knife',
      'weapon',
      'firearm',
      'intruder',
      'intrusion',
      'perimeter',
      'trespass',
      'loiter',
      'line_crossing',
      'line crossing',
      'line-crossing',
      'tripwire',
      'gate activity',
      'scene change',
      'repeat activity',
    ]);
  }

  String? _normalizedMovementObjectLabel(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'unknown') {
      return null;
    }
    if (_containsAny(normalized, const ['person', 'human'])) {
      return 'person';
    }
    if (_containsAny(normalized, const [
      'vehicle',
      'car',
      'truck',
      'van',
      'motorbike',
      'motorcycle',
      'bus',
      'bakkie',
      'pickup',
      'suv',
    ])) {
      return 'vehicle';
    }
    if (_containsAny(normalized, const ['animal', 'dog', 'cat', 'bird'])) {
      return 'animal';
    }
    if (_containsAny(normalized, const ['backpack', 'back pack', 'rucksack'])) {
      return 'backpack';
    }
    if (_containsAny(normalized, const [
      'bag',
      'handbag',
      'purse',
      'suitcase',
      'luggage',
      'duffel',
      'satchel',
    ])) {
      return 'bag';
    }
    if (_containsAny(normalized, const ['knife', 'blade', 'machete'])) {
      return 'knife';
    }
    if (_containsAny(normalized, const ['crowbar', 'prybar', 'pry bar'])) {
      return 'weapon';
    }
    if (_containsAny(normalized, const [
      'firearm',
      'pistol',
      'gun',
      'rifle',
      'shotgun',
      'revolver',
    ])) {
      return 'firearm';
    }
    if (normalized.contains('weapon')) {
      return 'weapon';
    }
    return null;
  }

  String _movementSignalLabelFor(
    IntelligenceReceived event, {
    required int count,
  }) {
    final objectLabel = _movementSemanticLabelFor(event);
    final hotspotLabel = _movementHotspotLabelFor(event);
    final countLead = count > 1 ? '$count recent ' : 'recent ';
    final usesDetectionLabel =
        objectLabel == 'backpack' ||
        objectLabel == 'bag' ||
        objectLabel == 'knife' ||
        objectLabel == 'weapon' ||
        objectLabel == 'firearm';
    if (objectLabel != null && hotspotLabel != null) {
      return usesDetectionLabel
          ? '$countLead$objectLabel detections around $hotspotLabel'
          : '$countLead$objectLabel movement signals around $hotspotLabel';
    }
    if (objectLabel != null) {
      return usesDetectionLabel
          ? '$countLead$objectLabel detections on site'
          : '$countLead$objectLabel movement signals on site';
    }
    final tacticalSignalLabel = _movementTacticalSignalLabelFor(event);
    if (tacticalSignalLabel != null && hotspotLabel != null) {
      return '$countLead$tacticalSignalLabel around $hotspotLabel';
    }
    if (tacticalSignalLabel != null) {
      return '$countLead$tacticalSignalLabel on site';
    }
    if (hotspotLabel != null) {
      return '${countLead}movement signals around $hotspotLabel';
    }
    return '${countLead}movement signals on site';
  }

  String _issueSignalLabelFor(
    IntelligenceReceived event, {
    required int count,
  }) {
    final objectLabel = _movementSemanticLabelFor(event);
    final hotspotLabel = _movementHotspotLabelFor(event);
    final tacticalSignalLabel = _movementTacticalSignalLabelFor(event);
    final countLead = count > 1 ? '$count recent ' : 'recent ';
    final usesDetectionLabel =
        objectLabel == 'backpack' ||
        objectLabel == 'bag' ||
        objectLabel == 'knife' ||
        objectLabel == 'weapon' ||
        objectLabel == 'firearm';
    if (tacticalSignalLabel != null && hotspotLabel != null) {
      return '$countLead$tacticalSignalLabel around $hotspotLabel';
    }
    if (tacticalSignalLabel != null) {
      return '$countLead$tacticalSignalLabel on site';
    }
    if (objectLabel != null && hotspotLabel != null) {
      return usesDetectionLabel
          ? '$countLead$objectLabel detections around $hotspotLabel'
          : '$countLead$objectLabel activity around $hotspotLabel';
    }
    if (objectLabel != null) {
      return usesDetectionLabel
          ? '$countLead$objectLabel detections on site'
          : '$countLead$objectLabel activity on site';
    }
    if (hotspotLabel != null) {
      return '${countLead}activity around $hotspotLabel';
    }
    return '${countLead}activity on site';
  }

  String? _movementSemanticLabelFor(IntelligenceReceived event) {
    final directObjectLabel =
        _normalizedMovementObjectLabel(event.objectLabel) ?? '';
    final resolvedObjectLabel = resolveIdentityBackedObjectLabel(
      event: event,
      directObjectLabel: directObjectLabel,
    );
    if (resolvedObjectLabel.isNotEmpty) {
      return resolvedObjectLabel;
    }
    final combined = [
      event.headline,
      event.summary,
      event.zone ?? '',
      event.cameraId ?? '',
    ].join(' ').toLowerCase();
    return _normalizedMovementObjectLabel(combined);
  }

  String? _movementTacticalSignalLabelFor(IntelligenceReceived event) {
    final combined = [
      event.headline,
      event.summary,
      event.zone ?? '',
      event.cameraId ?? '',
    ].join(' ').toLowerCase();
    if (_containsAny(combined, const [
      'line_crossing',
      'line crossing',
      'line-crossing',
      'tripwire',
    ])) {
      return 'line-crossing signals';
    }
    if (_containsAny(combined, const [
      'intrusion',
      'perimeter',
      'trespass',
      'breach',
    ])) {
      return 'intrusion signals';
    }
    return null;
  }

  String? _movementHotspotLabelFor(IntelligenceReceived event) {
    final zone = (event.zone ?? '').trim();
    if (zone.isNotEmpty) {
      return zone;
    }
    final cameraId = (event.cameraId ?? '').trim();
    if (cameraId.isNotEmpty) {
      return 'Camera $cameraId';
    }
    return null;
  }

  bool _providerUsesHikConnect(String provider) {
    return provider.contains('hik_connect') ||
        provider.contains('hikconnect') ||
        provider.contains('hikcentral_connect');
  }

  String _normalizedProvider(String provider) {
    return provider.trim().toLowerCase().replaceAll('-', '_');
  }

  bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (needle.isEmpty) {
        continue;
      }
      if (haystack.contains(needle)) {
        return true;
      }
    }
    return false;
  }
}

class _RecentMovementSignals {
  final DateTime? lastOccurredAtUtc;
  final int count;
  final String? label;
  final String? issueLabel;
  final String? hotspotLabel;
  final String? objectLabel;

  const _RecentMovementSignals({
    this.lastOccurredAtUtc,
    this.count = 0,
    this.label,
    this.issueLabel,
    this.hotspotLabel,
    this.objectLabel,
  });
}
