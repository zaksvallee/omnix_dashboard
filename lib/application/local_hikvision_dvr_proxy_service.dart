import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'dvr_http_auth.dart';

class _ProxySnapshotFrame {
  final int statusCode;
  final String contentType;
  final List<int> bytes;

  const _ProxySnapshotFrame({
    required this.statusCode,
    required this.contentType,
    required this.bytes,
  });
}

class _RelayStreamRuntime {
  DateTime? lastFrameAtUtc;
  DateTime? lastRequestAtUtc;
  String lastError = '';
  int activeClientCount = 0;
}

class _BufferedAlertEvent {
  final String payload;
  final DateTime capturedAtUtc;

  const _BufferedAlertEvent({
    required this.payload,
    required this.capturedAtUtc,
  });
}

class LocalHikvisionDvrProxyService {
  static const _mjpegBoundary = 'onyxframe';
  static const _upstreamStreamStatusConnected = 'connected';
  static const _upstreamStreamStatusReconnecting = 'reconnecting';
  static const _upstreamStreamStatusDisconnected = 'disconnected';

  final Uri upstreamAlertStreamUri;
  final DvrHttpAuthConfig upstreamAuth;
  final String host;
  final int port;
  final http.Client client;
  final Duration upstreamRequestTimeout;
  final Duration alertStreamIdleWindow;
  final Duration upstreamReconnectDelay;
  final Duration bufferedAlertRetentionWindow;
  final int maxBufferedAlertCount;
  final Duration mjpegFrameInterval;

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;
  DateTime? _lastSuccessAtUtc;
  DateTime? _lastAlertAtUtc;
  String _lastError = '';
  final Map<String, _RelayStreamRuntime> _relayRuntimeByStream =
      <String, _RelayStreamRuntime>{};
  final List<_BufferedAlertEvent> _bufferedAlertEvents =
      <_BufferedAlertEvent>[];
  String _upstreamAlertStreamStatus = _upstreamStreamStatusDisconnected;
  bool _upstreamAlertLoopRunning = false;

  LocalHikvisionDvrProxyService({
    required this.upstreamAlertStreamUri,
    required this.upstreamAuth,
    required this.host,
    required this.port,
    required this.client,
    this.upstreamRequestTimeout = const Duration(seconds: 12),
    this.alertStreamIdleWindow = const Duration(seconds: 8),
    this.upstreamReconnectDelay = const Duration(seconds: 2),
    this.bufferedAlertRetentionWindow = const Duration(minutes: 3),
    this.maxBufferedAlertCount = 80,
    this.mjpegFrameInterval = const Duration(milliseconds: 800),
  });

  bool get isRunning => _server != null;

  bool get _upstreamAlertConnected =>
      _upstreamAlertStreamStatus == _upstreamStreamStatusConnected;

  Uri? get endpoint {
    final server = _server;
    if (server == null) {
      return Uri(
        scheme: 'http',
        host: host.trim().isEmpty ? '127.0.0.1' : host.trim(),
        port: port,
      );
    }
    return Uri(scheme: 'http', host: server.address.host, port: server.port);
  }

  Future<void> start() async {
    if (_server != null) {
      return;
    }
    final resolvedHost = host.trim().isEmpty ? '127.0.0.1' : host.trim();
    final server = await HttpServer.bind(resolvedHost, port);
    server.idleTimeout = const Duration(seconds: 5);
    _server = server;
    _subscription = server.listen((request) {
      unawaited(_handleRequest(request));
    });
    unawaited(_ensureUpstreamAlertSubscription());
  }

  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
    client.close();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.method == 'OPTIONS') {
        await _writeEmptyResponse(request, HttpStatus.ok);
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/health') {
        await _writeJsonResponse(request, HttpStatus.ok, <String, Object?>{
          'status': 'ok',
          'running': isRunning,
          'endpoint': endpoint?.toString(),
          'upstream_alert_stream': upstreamAlertStreamUri.toString(),
          'upstream_stream_status': _upstreamAlertStreamStatus,
          'upstream_stream_connected': _upstreamAlertConnected,
          'buffered_alert_count': _bufferedAlertEvents.length,
          'last_alert_at_utc': _lastAlertAtUtc?.toIso8601String(),
          'last_success_at_utc': _lastSuccessAtUtc?.toIso8601String(),
          'last_error': _lastError,
        });
        return;
      }
      if (request.method != 'GET' && request.method != 'HEAD') {
        await _writeJsonResponse(
          request,
          HttpStatus.methodNotAllowed,
          <String, Object?>{
            'ok': false,
            'detail': 'Use GET /health or GET/HEAD Hikvision paths only.',
          },
        );
        return;
      }
      if (_isAlertStreamRequest(request.uri)) {
        await _relayAlertStreamBatch(request);
        return;
      }
      final relayStreamId = _relayStreamIdFor(request.uri);
      if (relayStreamId != null) {
        await _relaySnapshotMjpeg(request, relayStreamId);
        return;
      }
      final relayStatusStreamId = _relayStatusStreamIdFor(request.uri);
      if (relayStatusStreamId != null) {
        await _writeRelayStatus(request, relayStatusStreamId);
        return;
      }
      final playerStreamId = _relayPlayerStreamIdFor(request.uri);
      if (playerStreamId != null) {
        await _writeRelayPlayerPage(request, playerStreamId);
        return;
      }
      await _relayPassthrough(request);
    } catch (error) {
      _lastError = error.toString();
      await _writeJsonResponse(
        request,
        HttpStatus.badGateway,
        <String, Object?>{
          'ok': false,
          'detail': 'The local Hikvision proxy could not reach the upstream.',
          'error': error.toString(),
        },
      );
    }
  }

  bool _isAlertStreamRequest(Uri requestUri) {
    return requestUri.path == upstreamAlertStreamUri.path;
  }

  Uri _resolveUpstreamUri(Uri requestUri) {
    return upstreamAlertStreamUri.replace(
      path: requestUri.path,
      query: requestUri.hasQuery ? requestUri.query : null,
      fragment: null,
    );
  }

  String? _relayStreamIdFor(Uri requestUri) {
    final match = RegExp(
      r'^/onyx/live/channels/(\d+)\.mjpg$',
      caseSensitive: false,
    ).firstMatch(requestUri.path);
    return match?.group(1);
  }

  String? _relayPlayerStreamIdFor(Uri requestUri) {
    final match = RegExp(
      r'^/onyx/live/channels/(\d+)/player$',
      caseSensitive: false,
    ).firstMatch(requestUri.path);
    return match?.group(1);
  }

  String? _relayStatusStreamIdFor(Uri requestUri) {
    final match = RegExp(
      r'^/onyx/live/channels/(\d+)/status$',
      caseSensitive: false,
    ).firstMatch(requestUri.path);
    return match?.group(1);
  }

  Uri _relaySnapshotUri(String streamId) {
    return upstreamAlertStreamUri.resolve(
      '/ISAPI/Streaming/channels/${Uri.encodeComponent(streamId)}/picture',
    );
  }

  Uri _relayStreamUri(String streamId) {
    return endpoint!.resolve(
      '/onyx/live/channels/${Uri.encodeComponent(streamId)}.mjpg',
    );
  }

  Uri _relayPlayerUri(String streamId) {
    return endpoint!.resolve(
      '/onyx/live/channels/${Uri.encodeComponent(streamId)}/player',
    );
  }

  Uri _relayStatusUri(String streamId) {
    return endpoint!.resolve(
      '/onyx/live/channels/${Uri.encodeComponent(streamId)}/status',
    );
  }

  _RelayStreamRuntime _relayRuntimeFor(String streamId) {
    return _relayRuntimeByStream.putIfAbsent(
      streamId,
      () => _RelayStreamRuntime(),
    );
  }

  Duration get _relayStaleAfter {
    final seconds = math.max(
      5,
      ((mjpegFrameInterval.inMilliseconds * 4) / 1000).ceil(),
    );
    return Duration(seconds: seconds);
  }

  String _relayStatusValue(
    _RelayStreamRuntime runtime, {
    required DateTime nowUtc,
  }) {
    final lastFrameAtUtc = runtime.lastFrameAtUtc;
    final staleAfter = _relayStaleAfter;
    final lastError = runtime.lastError.trim();
    final hasFreshFrame =
        lastFrameAtUtc != null &&
        nowUtc.difference(lastFrameAtUtc).abs() <= staleAfter;

    if (runtime.activeClientCount > 0 && hasFreshFrame) {
      return 'active';
    }
    if (runtime.activeClientCount > 0 && lastFrameAtUtc == null) {
      return 'starting';
    }
    if (hasFreshFrame) {
      return 'ready';
    }
    if (lastFrameAtUtc != null) {
      return 'stale';
    }
    if (lastError.isNotEmpty) {
      return 'error';
    }
    return 'idle';
  }

  Future<void> _relayAlertStreamBatch(HttpRequest request) async {
    final bufferedPayload = _bufferedAlertPayload();
    if (bufferedPayload.isNotEmpty) {
      _lastSuccessAtUtc = DateTime.now().toUtc();
      _lastError = '';
      final response = request.response;
      response.statusCode = HttpStatus.ok;
      _writeCorsHeaders(response.headers);
      response.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/xml; charset=utf-8',
      );
      response.write(bufferedPayload);
      await response.close();
      return;
    }
    final upstreamUri = _resolveUpstreamUri(request.uri);
    final upstream = await upstreamAuth
        .send(
          client,
          'GET',
          upstreamUri,
          headers: const <String, String>{
            'Accept': 'multipart/x-mixed-replace, application/xml, text/xml',
          },
        )
        .timeout(upstreamRequestTimeout);
    if (upstream.statusCode < 200 || upstream.statusCode >= 300) {
      _lastError = 'Upstream alert stream HTTP ${upstream.statusCode}';
      await _writeUpstreamFailure(request, upstream.statusCode);
      await upstream.stream.drain<void>();
      return;
    }
    final payload = await _captureAlertPayload(
      upstream.stream,
    ).timeout(upstreamRequestTimeout + alertStreamIdleWindow);
    if (payload.trim().isEmpty) {
      _lastSuccessAtUtc = DateTime.now().toUtc();
      _lastError = '';
      await _writeEmptyResponse(request, HttpStatus.noContent);
      return;
    }
    _lastSuccessAtUtc = DateTime.now().toUtc();
    _lastError = '';
    final response = request.response;
    response.statusCode = HttpStatus.ok;
    _writeCorsHeaders(response.headers);
    response.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/xml; charset=utf-8',
    );
    response.write(payload);
    await response.close();
  }

  Future<String> _captureAlertPayload(Stream<List<int>> stream) {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    StreamSubscription<List<int>>? subscription;
    Timer? idleTimer;

    void finish([String payload = '']) {
      idleTimer?.cancel();
      if (!completer.isCompleted) {
        completer.complete(payload);
      }
      unawaited(subscription?.cancel());
    }

    void armIdleTimer() {
      idleTimer?.cancel();
      idleTimer = Timer(alertStreamIdleWindow, () {
        finish(_extractAlertPayload(buffer.toString()));
      });
    }

    subscription = stream.listen(
      (chunk) {
        buffer.write(utf8.decode(chunk, allowMalformed: true));
        final payload = _extractAlertPayload(buffer.toString());
        if (payload.isNotEmpty) {
          finish(payload);
          return;
        }
        armIdleTimer();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
      onDone: () => finish(_extractAlertPayload(buffer.toString())),
      cancelOnError: true,
    );
    return completer.future;
  }

  Future<void> _ensureUpstreamAlertSubscription() async {
    if (_upstreamAlertLoopRunning || _server == null) {
      return;
    }
    _upstreamAlertLoopRunning = true;
    try {
      while (_server != null) {
        try {
          final upstream = await upstreamAuth
              .send(
                client,
                'GET',
                upstreamAlertStreamUri,
                headers: const <String, String>{
                  'Accept':
                      'multipart/x-mixed-replace, application/xml, text/xml',
                },
              )
              .timeout(upstreamRequestTimeout);
          if (upstream.statusCode < 200 || upstream.statusCode >= 300) {
            _upstreamAlertStreamStatus = _upstreamStreamStatusDisconnected;
            _lastError = 'Upstream alert stream HTTP ${upstream.statusCode}';
            await upstream.stream.drain<void>();
          } else {
            _upstreamAlertStreamStatus = _upstreamStreamStatusConnected;
            _lastError = '';
            _lastSuccessAtUtc = DateTime.now().toUtc();
            final payload = await _captureAlertPayload(
              upstream.stream,
            ).timeout(upstreamRequestTimeout + alertStreamIdleWindow);
            if (payload.trim().isNotEmpty) {
              _bufferAlertPayload(payload);
            }
          }
        } catch (error) {
          _upstreamAlertStreamStatus = _upstreamStreamStatusDisconnected;
          _lastError = error.toString();
        }
        if (_server == null) {
          _upstreamAlertStreamStatus = _upstreamStreamStatusDisconnected;
          break;
        }
        _upstreamAlertStreamStatus = _upstreamStreamStatusReconnecting;
        await Future<void>.delayed(upstreamReconnectDelay);
      }
    } finally {
      _upstreamAlertLoopRunning = false;
      _upstreamAlertStreamStatus = _upstreamStreamStatusDisconnected;
    }
  }

  void _bufferAlertPayload(String payload) {
    final matches = RegExp(
      r'<EventNotificationAlert\b[^>]*>[\s\S]*?</EventNotificationAlert>',
    ).allMatches(payload);
    for (final match in matches) {
      final xml = match.group(0)?.trim() ?? '';
      if (xml.isEmpty) {
        continue;
      }
      final capturedAtUtc = DateTime.now().toUtc();
      _bufferedAlertEvents.add(
        _BufferedAlertEvent(payload: xml, capturedAtUtc: capturedAtUtc),
      );
      _lastAlertAtUtc = capturedAtUtc;
      _lastSuccessAtUtc = capturedAtUtc;
    }
    _pruneBufferedAlerts();
  }

  String _bufferedAlertPayload() {
    _pruneBufferedAlerts();
    return _bufferedAlertEvents.map((event) => event.payload).join('\n');
  }

  void _pruneBufferedAlerts() {
    final nowUtc = DateTime.now().toUtc();
    _bufferedAlertEvents.removeWhere(
      (event) =>
          nowUtc.difference(event.capturedAtUtc).abs() >
          bufferedAlertRetentionWindow,
    );
    if (_bufferedAlertEvents.length <= maxBufferedAlertCount) {
      return;
    }
    _bufferedAlertEvents.removeRange(
      0,
      _bufferedAlertEvents.length - maxBufferedAlertCount,
    );
  }

  String _extractAlertPayload(String raw) {
    final matches = RegExp(
      r'<EventNotificationAlert\b[^>]*>[\s\S]*?</EventNotificationAlert>',
    ).allMatches(raw);
    return matches
        .map((match) => match.group(0)?.trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .join('\n');
  }

  Future<void> _relayPassthrough(HttpRequest request) async {
    final upstreamUri = _resolveUpstreamUri(request.uri);
    final requestHeaders = <String, String>{
      if ((request.headers.value(HttpHeaders.acceptHeader) ?? '')
          .trim()
          .isNotEmpty)
        HttpHeaders.acceptHeader: request.headers
            .value(HttpHeaders.acceptHeader)!
            .trim(),
      if ((request.headers.value(HttpHeaders.rangeHeader) ?? '')
          .trim()
          .isNotEmpty)
        HttpHeaders.rangeHeader: request.headers
            .value(HttpHeaders.rangeHeader)!
            .trim(),
    };
    final upstream = await upstreamAuth
        .send(client, request.method, upstreamUri, headers: requestHeaders)
        .timeout(upstreamRequestTimeout);
    final response = request.response;
    response.statusCode = upstream.statusCode;
    _writeCorsHeaders(response.headers);
    _copyHeader(
      upstream.headers,
      response.headers,
      HttpHeaders.contentTypeHeader,
    );
    _copyHeader(
      upstream.headers,
      response.headers,
      HttpHeaders.contentLengthHeader,
    );
    _copyHeader(
      upstream.headers,
      response.headers,
      HttpHeaders.acceptRangesHeader,
    );
    _copyHeader(
      upstream.headers,
      response.headers,
      HttpHeaders.contentRangeHeader,
    );
    _copyHeader(
      upstream.headers,
      response.headers,
      HttpHeaders.cacheControlHeader,
    );
    if (request.method == 'HEAD') {
      await upstream.stream.drain<void>();
      await response.close();
      return;
    }
    _lastSuccessAtUtc = DateTime.now().toUtc();
    _lastError = '';
    await response.addStream(upstream.stream);
    await response.close();
  }

  Future<void> _relaySnapshotMjpeg(HttpRequest request, String streamId) async {
    final frameLimit = int.tryParse(
      (request.uri.queryParameters['frame_limit'] ?? '').trim(),
    );
    final runtime = _relayRuntimeFor(streamId);
    runtime.lastRequestAtUtc = DateTime.now().toUtc();
    final snapshotUri = _relaySnapshotUri(streamId);
    final firstFrame = await _fetchSnapshotFrame(snapshotUri);
    if (firstFrame == null) {
      _lastError = 'Snapshot relay frame was empty for stream $streamId';
      runtime.lastError = _lastError;
      await _writeJsonResponse(
        request,
        HttpStatus.badGateway,
        <String, Object?>{
          'ok': false,
          'detail': 'The live relay could not fetch the first snapshot frame.',
        },
      );
      return;
    }
    if (firstFrame.statusCode < 200 || firstFrame.statusCode >= 300) {
      _lastError = 'Snapshot relay upstream HTTP ${firstFrame.statusCode}';
      runtime.lastError = _lastError;
      await _writeUpstreamFailure(request, firstFrame.statusCode);
      return;
    }

    final response = request.response;
    response.statusCode = HttpStatus.ok;
    response.bufferOutput = false;
    _writeCorsHeaders(response.headers);
    response.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/x-mixed-replace; boundary=$_mjpegBoundary',
    );
    response.headers.set(
      HttpHeaders.cacheControlHeader,
      'no-store, no-cache, must-revalidate',
    );
    response.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
    if (request.method == 'HEAD') {
      await response.close();
      return;
    }

    var sentFrames = 0;
    var currentFrame = firstFrame;
    _lastSuccessAtUtc = DateTime.now().toUtc();
    _lastError = '';
    runtime.activeClientCount += 1;
    runtime.lastError = '';
    try {
      while (true) {
        final frameTime = DateTime.now().toUtc();
        runtime.lastFrameAtUtc = frameTime;
        try {
          response.write('--$_mjpegBoundary\r\n');
          response.write(
            'Content-Type: ${currentFrame.contentType}\r\n'
            'Content-Length: ${currentFrame.bytes.length}\r\n'
            '\r\n',
          );
          response.add(currentFrame.bytes);
          response.write('\r\n');
          await response.flush();
        } catch (_) {
          break;
        }
        sentFrames += 1;
        if (frameLimit != null && sentFrames >= frameLimit) {
          break;
        }
        await Future<void>.delayed(mjpegFrameInterval);
        final nextFrame = await _fetchSnapshotFrame(snapshotUri);
        if (nextFrame == null ||
            nextFrame.statusCode < 200 ||
            nextFrame.statusCode >= 300) {
          if (nextFrame != null &&
              (nextFrame.statusCode < 200 || nextFrame.statusCode >= 300)) {
            _lastError = 'Snapshot relay upstream HTTP ${nextFrame.statusCode}';
            runtime.lastError = _lastError;
          }
          break;
        }
        _lastSuccessAtUtc = DateTime.now().toUtc();
        _lastError = '';
        runtime.lastError = '';
        currentFrame = nextFrame;
      }
      try {
        response.write('--$_mjpegBoundary--\r\n');
        await response.close();
      } catch (_) {
        // Ignore client disconnects while shutting the relay down.
      }
    } finally {
      runtime.activeClientCount = math.max(0, runtime.activeClientCount - 1);
    }
  }

  Future<_ProxySnapshotFrame?> _fetchSnapshotFrame(Uri snapshotUri) async {
    final upstream = await upstreamAuth
        .send(
          client,
          'GET',
          snapshotUri,
          headers: const <String, String>{
            'Accept': 'image/jpeg, image/*;q=0.9, */*;q=0.1',
          },
        )
        .timeout(upstreamRequestTimeout);
    final bytes = await upstream.stream.toBytes();
    return _ProxySnapshotFrame(
      statusCode: upstream.statusCode,
      contentType:
          (upstream.headers[HttpHeaders.contentTypeHeader] ?? '').trim().isEmpty
          ? 'image/jpeg'
          : upstream.headers[HttpHeaders.contentTypeHeader]!.trim(),
      bytes: bytes,
    );
  }

  Future<void> _writeRelayPlayerPage(
    HttpRequest request,
    String streamId,
  ) async {
    final streamUri = _relayStreamUri(streamId);
    final playerUri = _relayPlayerUri(streamId);
    final statusUri = _relayStatusUri(streamId);
    final response = request.response;
    response.statusCode = HttpStatus.ok;
    _writeCorsHeaders(response.headers);
    response.headers.set(
      HttpHeaders.contentTypeHeader,
      'text/html; charset=utf-8',
    );
    response.headers.set(
      HttpHeaders.cacheControlHeader,
      'no-store, no-cache, must-revalidate',
    );
    if (request.method == 'HEAD') {
      await response.close();
      return;
    }
    final encodedPlayerUri = jsonEncode(playerUri.toString());
    final encodedStatusUri = jsonEncode(statusUri.toString());
    response.write('''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>ONYX Live Relay • Channel $streamId</title>
  <style>
    :root { color-scheme: light; }
    body {
      margin: 0;
      font-family: Inter, Arial, sans-serif;
      background: linear-gradient(180deg, #f6f9fd 0%, #edf4fb 100%);
      color: #162436;
    }
    main {
      max-width: 1200px;
      margin: 0 auto;
      padding: 24px;
    }
    .card {
      background: rgba(255, 255, 255, 0.94);
      border: 1px solid #c8d8e8;
      border-radius: 18px;
      box-shadow: 0 16px 44px rgba(22, 36, 54, 0.08);
      overflow: hidden;
    }
    .header {
      padding: 20px 22px 12px;
      border-bottom: 1px solid #d9e5f1;
    }
    .eyebrow {
      color: #2e6ea8;
      font-size: 12px;
      font-weight: 800;
      letter-spacing: 0.12em;
      text-transform: uppercase;
    }
    h1 {
      margin: 8px 0 6px;
      font-size: 28px;
      line-height: 1.1;
    }
    p {
      margin: 0;
      color: #4f6479;
      font-size: 14px;
      line-height: 1.5;
    }
    .meta {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-top: 14px;
    }
    .chip {
      border-radius: 999px;
      padding: 8px 12px;
      background: #eaf4ff;
      border: 1px solid #bed6ef;
      color: #1c4567;
      font-size: 12px;
      font-weight: 700;
    }
    .frame {
      background: #0f1a26;
      padding: 16px;
    }
    img {
      display: block;
      width: 100%;
      height: auto;
      aspect-ratio: 16 / 9;
      object-fit: contain;
      background: #08111b;
    }
    .footer {
      padding: 14px 22px 22px;
      font-size: 12px;
      color: #5f7387;
    }
    .status-row {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      align-items: center;
      margin-top: 14px;
    }
    .status-pill {
      background: #eef3f8;
      border-color: #d4e0eb;
      color: #304454;
    }
    .status-pill[data-state="active"],
    .status-pill[data-state="ready"] {
      background: #e9fbf4;
      border-color: #aae8cd;
      color: #0f6b52;
    }
    .status-pill[data-state="starting"],
    .status-pill[data-state="stale"] {
      background: #fff6e8;
      border-color: #f0d7a7;
      color: #8a5d00;
    }
    .status-pill[data-state="error"] {
      background: #fff0f0;
      border-color: #f0b8b8;
      color: #a12c2c;
    }
    .status-detail {
      font-size: 12px;
      font-weight: 700;
      color: #4f6479;
    }
    code {
      font-family: "Roboto Mono", monospace;
      font-size: 12px;
      word-break: break-all;
    }
  </style>
</head>
<body>
  <main>
    <section class="card">
      <div class="header">
        <div class="eyebrow">ONYX Operator Relay</div>
        <h1>Live Relay • Channel $streamId</h1>
        <p>This browser player is fed by the temporary ONYX local Hikvision bridge. It relays fresh frames for operator use and should not be described to residents as a native recorder live stream.</p>
        <div class="meta">
          <span class="chip">MJPEG relay</span>
          <span class="chip">Temporary local bridge</span>
          <span class="chip">Path: <code>${streamUri.toString()}</code></span>
        </div>
        <div class="status-row">
          <span class="chip status-pill" id="status-pill" data-state="idle">Checking relay status</span>
          <span class="status-detail" id="status-detail">Waiting for the latest relay heartbeat from ONYX.</span>
        </div>
      </div>
      <div class="frame">
        <img src="${streamUri.toString()}" alt="ONYX live relay for channel $streamId">
      </div>
      <div class="footer">
        Player URL: <code>${playerUri.toString()}</code>
      </div>
    </section>
  </main>
  <script>
    const playerUrl = $encodedPlayerUri;
    const statusUrl = $encodedStatusUri;
    const statusPill = document.getElementById('status-pill');
    const statusDetail = document.getElementById('status-detail');

    function formatMoment(raw) {
      if (!raw) {
        return 'unknown';
      }
      const value = new Date(raw);
      if (Number.isNaN(value.getTime())) {
        return raw;
      }
      return value.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    }

    function setStatus(state, label, detail) {
      statusPill.dataset.state = state;
      statusPill.textContent = label;
      statusDetail.textContent = detail;
    }

    function applyStatus(payload) {
      const state = String(payload.status || 'idle').toLowerCase();
      const activeClients = Number(payload.active_clients || 0);
      const frameTime = formatMoment(payload.last_frame_at_utc);
      const lastError = String(payload.last_error || '').trim();
      if (state === 'active') {
        setStatus('active', 'Relay active', 'ONYX is currently serving moving frames through the local bridge.');
        return;
      }
      if (state === 'ready') {
        setStatus('ready', 'Relay ready', 'The last frame was confirmed at ' + frameTime + '. Open or refresh ' + playerUrl + ' if you need motion video again.');
        return;
      }
      if (state === 'starting') {
        setStatus('starting', 'Relay starting', 'A stream request is open and ONYX is waiting for the next frame.');
        return;
      }
      if (state === 'stale') {
        setStatus('stale', 'Relay stale', 'The last frame reached ONYX at ' + frameTime + '. Refresh the player if motion looks frozen.');
        return;
      }
      if (state === 'error') {
        setStatus('error', 'Relay error', lastError || 'The relay reported an error on the latest check.');
        return;
      }
      setStatus('idle', activeClients > 0 ? 'Relay waiting' : 'Relay idle', activeClients > 0
        ? 'A player is open, but ONYX has not confirmed a fresh frame yet.'
        : 'Open or refresh the stream player to start pulling frames through the local bridge.');
    }

    async function refreshRelayStatus() {
      try {
        const response = await fetch(statusUrl, { cache: 'no-store' });
        if (!response.ok) {
          throw new Error('Relay status HTTP ' + response.status);
        }
        const payload = await response.json();
        applyStatus(payload);
      } catch (error) {
        setStatus('error', 'Relay status unavailable', error instanceof Error ? error.message : String(error));
      }
    }

    refreshRelayStatus();
    window.setInterval(refreshRelayStatus, 3000);
  </script>
</body>
</html>''');
    await response.close();
  }

  Future<void> _writeRelayStatus(HttpRequest request, String streamId) async {
    final runtime = _relayRuntimeFor(streamId);
    final nowUtc = DateTime.now().toUtc();
    await _writeJsonResponse(request, HttpStatus.ok, <String, Object?>{
      'ok': true,
      'stream_id': streamId,
      'status': _relayStatusValue(runtime, nowUtc: nowUtc),
      'player_url': _relayPlayerUri(streamId).toString(),
      'stream_url': _relayStreamUri(streamId).toString(),
      'active_clients': runtime.activeClientCount,
      'last_frame_at_utc': runtime.lastFrameAtUtc?.toIso8601String(),
      'last_request_at_utc': runtime.lastRequestAtUtc?.toIso8601String(),
      'last_error': runtime.lastError,
      'stale_after_seconds': _relayStaleAfter.inSeconds,
      'frame_interval_millis': mjpegFrameInterval.inMilliseconds,
    });
  }

  void _copyHeader(
    Map<String, String> from,
    HttpHeaders to,
    String headerName,
  ) {
    final value = from[headerName];
    if (value == null || value.trim().isEmpty) {
      return;
    }
    to.set(headerName, value);
  }

  Future<void> _writeUpstreamFailure(HttpRequest request, int statusCode) {
    return _writeJsonResponse(request, HttpStatus.badGateway, <String, Object?>{
      'ok': false,
      'detail': 'Upstream Hikvision request failed with HTTP $statusCode.',
    });
  }

  Future<void> _writeEmptyResponse(HttpRequest request, int statusCode) async {
    final response = request.response;
    response.statusCode = statusCode;
    _writeCorsHeaders(response.headers);
    await response.close();
  }

  Future<void> _writeJsonResponse(
    HttpRequest request,
    int statusCode,
    Map<String, Object?> body,
  ) async {
    final response = request.response;
    response.statusCode = statusCode;
    _writeCorsHeaders(response.headers);
    response.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/json; charset=utf-8',
    );
    response.write(jsonEncode(body));
    await response.close();
  }

  void _writeCorsHeaders(HttpHeaders headers) {
    headers
      ..set(HttpHeaders.accessControlAllowOriginHeader, '*')
      ..set(
        HttpHeaders.accessControlAllowHeadersHeader,
        'content-type, authorization, range',
      )
      ..set(HttpHeaders.accessControlAllowMethodsHeader, 'GET, HEAD, OPTIONS');
  }
}
