import 'dart:async';
import 'dart:convert';
import 'dart:io';

const String _defaultHost = '127.0.0.1';
const int _defaultPort = 11637;
const String _healthPath = '/health';
const String _telegramApiHost = 'api.telegram.org';
const String _elevenLabsApiHost = 'api.elevenlabs.io';
const String _elevenLabsProxyPathPrefix = '/elevenlabs/tts/';

Future<void> main(List<String> args) async {
  final configPath = _readOption(args, '--config') ?? 'config/onyx.local.json';
  final configFile = File(configPath);
  if (!await configFile.exists()) {
    stderr.writeln('[ONYX] Telegram proxy config missing: $configPath');
    exit(1);
  }
  final config = await _readConfig(configFile);
  final bridgeEnabled = _readBool(
    config,
    'ONYX_TELEGRAM_BRIDGE_ENABLED',
    defaultValue: false,
  );
  final botToken = _readString(config, 'ONYX_TELEGRAM_BOT_TOKEN');
  final elevenLabsApiKey = _readStringFromEnvOrConfig(
    config,
    'ONYX_ELEVENLABS_API_KEY',
  );
  if (!bridgeEnabled || botToken.isEmpty) {
    stderr.writeln(
      '[ONYX] Telegram proxy disabled because bridge is off or bot token is missing.',
    );
    exit(1);
  }
  final host = _readString(
    config,
    'ONYX_TELEGRAM_PROXY_HOST',
    defaultValue: _defaultHost,
  );
  final port = _readInt(config, 'ONYX_TELEGRAM_PROXY_PORT') ?? _defaultPort;
  final server = await HttpServer.bind(host, port);
  server.idleTimeout = const Duration(seconds: 15);
  stdout.writeln(
    '[ONYX] Telegram Bot API proxy listening on http://$host:$port',
  );
  stdout.writeln(
    '[ONYX] Forwarding bot API requests to https://$_telegramApiHost',
  );
  if (elevenLabsApiKey.isNotEmpty) {
    stdout.writeln(
      '[ONYX] Forwarding ElevenLabs TTS requests to https://$_elevenLabsApiHost',
    );
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  await for (final request in server) {
    unawaited(_handleRequest(request, client, botToken, elevenLabsApiKey));
  }
}

Future<Map<String, Object?>> _readConfig(File configFile) async {
  final raw = await configFile.readAsString();
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw const FormatException('Config root must be a JSON object.');
  }
  return decoded.cast<String, Object?>();
}

Future<void> _handleRequest(
  HttpRequest request,
  HttpClient client,
  String botToken,
  String elevenLabsApiKey,
) async {
  try {
    if (request.method == 'OPTIONS') {
      _applyCors(request.response);
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }
    if (request.method == 'GET' && request.uri.path == _healthPath) {
      await _writeJsonResponse(request, HttpStatus.ok, <String, Object?>{
        'status': 'ok',
        'upstream': 'https://$_telegramApiHost',
        'configured': true,
        'elevenlabsConfigured': elevenLabsApiKey.isNotEmpty,
      });
      return;
    }
    if (request.uri.path.startsWith(_elevenLabsProxyPathPrefix)) {
      await _handleElevenLabsProxyRequest(request, client, elevenLabsApiKey);
      return;
    }
    final expectedPrefix = '/bot$botToken/';
    if (!request.uri.path.startsWith(expectedPrefix)) {
      await _writeJsonResponse(request, HttpStatus.notFound, <String, Object?>{
        'ok': false,
        'detail': 'Unknown Telegram proxy path.',
      });
      return;
    }
    stdout.writeln(
      '[ONYX] Telegram proxy ${request.method} '
      '${_redactBotPath(request.uri.path, botToken)}'
      '${request.uri.hasQuery ? '?${request.uri.query}' : ''}',
    );
    final upstreamRequest = await client.openUrl(
      request.method,
      Uri(
        scheme: 'https',
        host: _telegramApiHost,
        path: request.uri.path,
        query: request.uri.hasQuery ? request.uri.query : null,
      ),
    );
    _copyRequestHeaders(request.headers, upstreamRequest.headers);
    await for (final chunk in request) {
      upstreamRequest.add(chunk);
    }
    final upstreamResponse = await upstreamRequest.close();
    final response = request.response;
    response.statusCode = upstreamResponse.statusCode;
    _copyResponseHeaders(upstreamResponse.headers, response.headers);
    _applyCors(response);
    await for (final chunk in upstreamResponse) {
      response.add(chunk);
    }
    await response.close();
  } catch (error, stackTrace) {
    stderr.writeln('[ONYX] Telegram proxy request failed: $error');
    stderr.writeln(stackTrace);
    try {
      await _writeJsonResponse(
        request,
        HttpStatus.badGateway,
        <String, Object?>{
          'ok': false,
          'detail': 'Telegram proxy request failed.',
          'error': '$error',
        },
      );
    } catch (_) {
      try {
        await request.response.close();
      } catch (_) {
        // Ignore close failures after a partial response.
      }
    }
  }
}

Future<void> _handleElevenLabsProxyRequest(
  HttpRequest request,
  HttpClient client,
  String elevenLabsApiKey,
) async {
  if (request.method != 'POST') {
    await _writeJsonResponse(
      request,
      HttpStatus.methodNotAllowed,
      <String, Object?>{
        'ok': false,
        'detail': 'ElevenLabs proxy only accepts POST requests.',
      },
    );
    return;
  }
  if (elevenLabsApiKey.trim().isEmpty) {
    await _writeJsonResponse(
      request,
      HttpStatus.serviceUnavailable,
      <String, Object?>{
        'ok': false,
        'detail': 'ElevenLabs API key not configured in proxy.',
      },
    );
    return;
  }
  final voiceId = request.uri.path
      .substring(_elevenLabsProxyPathPrefix.length)
      .trim();
  if (voiceId.isEmpty) {
    await _writeJsonResponse(request, HttpStatus.badRequest, <String, Object?>{
      'ok': false,
      'detail': 'Missing ElevenLabs voice ID.',
    });
    return;
  }
  stdout.writeln(
    '[ONYX] ElevenLabs proxy ${request.method} '
    '$_elevenLabsProxyPathPrefix<voice>',
  );
  final upstreamRequest = await client.openUrl(
    request.method,
    Uri(
      scheme: 'https',
      host: _elevenLabsApiHost,
      path: '/v1/text-to-speech/$voiceId',
      query: request.uri.hasQuery ? request.uri.query : null,
    ),
  );
  _copyElevenLabsRequestHeaders(request.headers, upstreamRequest.headers);
  upstreamRequest.headers.set('xi-api-key', elevenLabsApiKey.trim());
  await for (final chunk in request) {
    upstreamRequest.add(chunk);
  }
  final upstreamResponse = await upstreamRequest.close();
  final response = request.response;
  response.statusCode = upstreamResponse.statusCode;
  _copyResponseHeaders(upstreamResponse.headers, response.headers);
  _applyCors(response);
  await for (final chunk in upstreamResponse) {
    response.add(chunk);
  }
  await response.close();
}

void _copyRequestHeaders(HttpHeaders source, HttpHeaders target) {
  source.forEach((name, values) {
    final normalized = name.toLowerCase();
    if (normalized == HttpHeaders.hostHeader ||
        normalized == 'origin' ||
        normalized == HttpHeaders.refererHeader ||
        normalized == HttpHeaders.connectionHeader ||
        normalized == HttpHeaders.contentLengthHeader) {
      return;
    }
    for (final value in values) {
      target.add(name, value);
    }
  });
}

void _copyElevenLabsRequestHeaders(HttpHeaders source, HttpHeaders target) {
  source.forEach((name, values) {
    final normalized = name.toLowerCase();
    if (normalized == HttpHeaders.hostHeader ||
        normalized == 'origin' ||
        normalized == HttpHeaders.refererHeader ||
        normalized == HttpHeaders.connectionHeader ||
        normalized == HttpHeaders.contentLengthHeader ||
        normalized == 'xi-api-key') {
      return;
    }
    for (final value in values) {
      target.add(name, value);
    }
  });
}

void _copyResponseHeaders(HttpHeaders source, HttpHeaders target) {
  source.forEach((name, values) {
    final normalized = name.toLowerCase();
    if (normalized == HttpHeaders.connectionHeader ||
        normalized == HttpHeaders.transferEncodingHeader ||
        normalized == HttpHeaders.contentLengthHeader) {
      return;
    }
    for (final value in values) {
      target.add(name, value);
    }
  });
}

Future<void> _writeJsonResponse(
  HttpRequest request,
  int statusCode,
  Map<String, Object?> payload,
) async {
  final response = request.response;
  response.statusCode = statusCode;
  response.headers.contentType = ContentType.json;
  _applyCors(response);
  response.write(jsonEncode(payload));
  await response.close();
}

void _applyCors(HttpResponse response) {
  response.headers
    ..set(HttpHeaders.accessControlAllowOriginHeader, '*')
    ..set(HttpHeaders.accessControlAllowMethodsHeader, 'GET, POST, OPTIONS')
    ..set(
      HttpHeaders.accessControlAllowHeadersHeader,
      'Content-Type, Accept, Authorization, X-Requested-With',
    )
    ..set(HttpHeaders.accessControlMaxAgeHeader, '600')
    ..set(HttpHeaders.cacheControlHeader, 'no-store');
}

String _redactBotPath(String path, String botToken) {
  return path.replaceFirst('/bot$botToken/', '/bot<redacted>/');
}

String? _readOption(List<String> args, String flag) {
  final index = args.indexOf(flag);
  if (index < 0 || index + 1 >= args.length) {
    return null;
  }
  return args[index + 1].trim();
}

bool _readBool(
  Map<String, Object?> config,
  String key, {
  required bool defaultValue,
}) {
  final value = config[key];
  if (value is bool) {
    return value;
  }
  final normalized = '$value'.trim().toLowerCase();
  if (normalized.isEmpty) {
    return defaultValue;
  }
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'yes' ||
      normalized == 'on';
}

String _readString(
  Map<String, Object?> config,
  String key, {
  String defaultValue = '',
}) {
  final value = config[key];
  if (value == null) {
    return defaultValue;
  }
  final normalized = '$value'.trim();
  return normalized.isEmpty ? defaultValue : normalized;
}

String _readStringFromEnvOrConfig(
  Map<String, Object?> config,
  String key, {
  String defaultValue = '',
}) {
  final envValue = Platform.environment[key]?.trim() ?? '';
  if (envValue.isNotEmpty) {
    return envValue;
  }
  return _readString(config, key, defaultValue: defaultValue);
}

int? _readInt(Map<String, Object?> config, String key) {
  final value = config[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('$value'.trim());
}
