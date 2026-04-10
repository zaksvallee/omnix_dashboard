// This service uses dart:io (HttpClient for digest auth and streaming).
// It cannot run in Flutter Web.
// Run as Flutter Desktop (macOS/Windows/Linux) or as a standalone Dart CLI
// process.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../dvr_http_auth.dart';
import 'onyx_site_awareness_repository.dart';
import 'onyx_site_awareness_service.dart';
import 'onyx_site_awareness_snapshot.dart';

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
    final cameraZones = _repository == null
        ? const <String, OnyxCameraZone>{}
        : await _repository.readCameraZones(_siteId);
    _projector = OnyxSiteAwarenessProjector(
      siteId: _siteId,
      clientId: _clientId,
      knownFaultChannels: knownFaultChannels.toSet(),
      cameraZones: cameraZones,
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
          final projector = _projector;
          if (projector != null) {
            _emitSnapshot(projector.snapshot());
          }
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
          _ingestAlertPayload(
            payload,
            errorLabel:
                'Failed to parse Hikvision EventNotificationAlert payload.',
          );
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
          _ingestAlertPayload(
            payload,
            errorLabel: 'Failed to parse trailing Hikvision alert payload.',
          );
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

  void _ingestAlertPayload(String payload, {required String errorLabel}) {
    try {
      final event = OnyxSiteAwarenessEvent.fromAlertXml(
        payload,
        knownFaultChannels: knownFaultChannels.toSet(),
        clock: _clock,
      );
      _ingestEvent(event);
    } catch (error, stackTrace) {
      developer.log(
        errorLabel,
        name: 'OnyxHikIsapiStream',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    }
  }

  void _ingestEvent(OnyxSiteAwarenessEvent event) {
    final projector = _projector;
    if (projector == null) {
      return;
    }
    final snapshot = projector.ingest(event);
    _latestSnapshot = snapshot;
    final repository = _repository;
    if (repository != null && event.eventType == OnyxEventType.humanDetected) {
      unawaited(_persistOccupancy(repository, event));
    }
    if (event.shouldPublishImmediately) {
      _emitSnapshot(snapshot);
    }
  }

  void _publishProjectedSnapshot() {
    final projector = _projector;
    if (!_running || !_isConnected || projector == null) {
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

  Future<void> _persistOccupancy(
    OnyxSiteAwarenessRepository repository,
    OnyxSiteAwarenessEvent event,
  ) async {
    try {
      await repository.recordHumanDetection(
        siteId: _siteId,
        channelId: event.channelId,
        detectedAt: event.detectedAt,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to persist site occupancy session.',
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
