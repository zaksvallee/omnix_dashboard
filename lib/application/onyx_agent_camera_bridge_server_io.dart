import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'onyx_agent_camera_bridge_receiver.dart';
import 'onyx_agent_camera_bridge_server_contract.dart';

OnyxAgentCameraBridgeServer createOnyxAgentCameraBridgeServer({
  required OnyxAgentCameraBridgeReceiver receiver,
  required String host,
  required int port,
  String authToken = '',
}) {
  return LocalHttpOnyxAgentCameraBridgeServer(
    receiver: receiver,
    host: host,
    port: port,
    authToken: authToken,
  );
}

class LocalHttpOnyxAgentCameraBridgeServer
    implements OnyxAgentCameraBridgeServer {
  final OnyxAgentCameraBridgeReceiver receiver;
  final String host;
  final int port;
  final String authToken;

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;

  LocalHttpOnyxAgentCameraBridgeServer({
    required this.receiver,
    required this.host,
    required this.port,
    this.authToken = '',
  });

  @override
  bool get isRunning => _server != null;

  @override
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

  @override
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
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.method == 'OPTIONS') {
        await _writeJsonResponse(
          request,
          HttpStatus.ok,
          const <String, Object?>{'ok': true},
        );
        return;
      }

      if (request.method == 'GET' && request.uri.path == '/health') {
        await _writeJsonResponse(request, HttpStatus.ok, <String, Object?>{
          'status': 'ok',
          'running': isRunning,
          'endpoint': endpoint?.toString(),
          'execute_path': '/execute',
        });
        return;
      }

      if (request.method != 'POST' || request.uri.path != '/execute') {
        await _writeJsonResponse(request, HttpStatus.notFound, <
          String,
          Object?
        >{
          'success': false,
          'detail':
              'Use POST /execute to submit a camera execution packet or GET /health for status.',
        });
        return;
      }

      if (!_isAuthorized(request)) {
        await _writeJsonResponse(request, HttpStatus.unauthorized, <
          String,
          Object?
        >{
          'success': false,
          'detail':
              'Unauthorized bridge request. Provide the configured bearer token before retrying.',
        });
        return;
      }

      final decoded = await _decodeExecuteRequestBody(request);
      if (decoded == null) {
        return;
      }
      if (decoded is! Map) {
        await _writeJsonResponse(
          request,
          HttpStatus.badRequest,
          _structuredRequestErrorBody(
            detail:
                'The bridge request body must be a JSON object matching the execution packet contract.',
            recommendedNextStep:
                'Re-stage the camera change packet as a JSON object and retry the approval flow.',
          ),
        );
        return;
      }

      final response = await receiver.handleExecutionJson(
        decoded.map((key, value) => MapEntry(key.toString(), value as Object?)),
      );
      final statusCode = response['success'] == false
          ? HttpStatus.unprocessableEntity
          : HttpStatus.ok;
      await _writeJsonResponse(request, statusCode, response);
    } catch (error) {
      await _writeJsonResponse(
        request,
        HttpStatus.internalServerError,
        _structuredRequestErrorBody(
          detail: 'The local camera bridge failed while handling the request.',
          recommendedNextStep:
              'Check the local bridge runtime and retry once the listener is healthy again.',
          error: error.toString(),
        ),
      );
    }
  }

  Future<Object?> _decodeExecuteRequestBody(HttpRequest request) async {
    try {
      final rawBody = await utf8.decoder.bind(request).join();
      return jsonDecode(rawBody);
    } on FormatException {
      await _writeJsonResponse(
        request,
        HttpStatus.badRequest,
        _structuredRequestErrorBody(
          detail:
              'The bridge request body could not be parsed as JSON. Re-stage the packet and retry.',
          recommendedNextStep:
              'Submit a valid JSON camera execution packet before retrying the approval flow.',
        ),
      );
      return null;
    } on Exception catch (error) {
      await _writeJsonResponse(
        request,
        HttpStatus.badRequest,
        _structuredRequestErrorBody(
          detail:
              'The bridge request body could not be decoded cleanly. Re-stage the packet and retry.',
          recommendedNextStep:
              'Submit a clean UTF-8 JSON camera execution packet before retrying the approval flow.',
          error: error.toString(),
        ),
      );
      return null;
    }
  }

  Map<String, Object?> _structuredRequestErrorBody({
    required String detail,
    required String recommendedNextStep,
    String? error,
  }) {
    final nowUtc = DateTime.now().toUtc();
    return <String, Object?>{
      'success': false,
      'provider_label': 'local:camera-bridge-server',
      'detail': detail,
      'recommended_next_step': recommendedNextStep,
      'recorded_at_utc': nowUtc.toIso8601String(),
      if ((error ?? '').trim().isNotEmpty) 'error': error!.trim(),
    };
  }

  bool _isAuthorized(HttpRequest request) {
    final expectedToken = authToken.trim();
    if (expectedToken.isEmpty) {
      return true;
    }
    final header = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    return header.trim() == 'Bearer $expectedToken';
  }

  Future<void> _writeJsonResponse(
    HttpRequest request,
    int statusCode,
    Map<String, Object?> body,
  ) async {
    final response = request.response;
    response.statusCode = statusCode;
    response.headers
      ..set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8')
      ..set(HttpHeaders.accessControlAllowOriginHeader, '*')
      ..set(
        HttpHeaders.accessControlAllowHeadersHeader,
        'content-type, authorization',
      )
      ..set(HttpHeaders.accessControlAllowMethodsHeader, 'GET, POST, OPTIONS');
    response.write(jsonEncode(body));
    await response.close();
  }
}
