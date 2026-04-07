import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:omnix_dashboard/application/dvr_http_auth.dart';
import 'package:omnix_dashboard/application/local_hikvision_dvr_proxy_service.dart';

Future<void> main(List<String> args) async {
  final configPath = _resolveConfigPath(args);
  final config = await _readConfig(configPath);
  final bindHost = _readString(
    config,
    'ONYX_DVR_PROXY_HOST',
    fallback: '127.0.0.1',
  );
  final bindPort = _readInt(config, 'ONYX_DVR_PROXY_PORT', fallback: 11635);
  final upstreamUrl = _readString(
    config,
    'ONYX_DVR_PROXY_UPSTREAM_URL',
    fallback: _readString(config, 'ONYX_DVR_EVENTS_URL'),
  );
  final upstreamUri = Uri.tryParse(upstreamUrl);
  if (upstreamUri == null) {
    stderr.writeln(
      'Missing or invalid ONYX_DVR_PROXY_UPSTREAM_URL in ${configPath.path}.',
    );
    exitCode = 64;
    return;
  }
  final upstreamAuthMode = _readString(
    config,
    'ONYX_DVR_PROXY_UPSTREAM_AUTH_MODE',
    fallback: _readString(config, 'ONYX_DVR_AUTH_MODE'),
  );
  final upstreamUsername = _readString(
    config,
    'ONYX_DVR_PROXY_UPSTREAM_USERNAME',
    fallback: _readString(config, 'ONYX_DVR_USERNAME'),
  );
  final upstreamPassword = _readString(
    config,
    'ONYX_DVR_PROXY_UPSTREAM_PASSWORD',
    fallback: _readString(config, 'ONYX_DVR_PASSWORD'),
  );

  final service = LocalHikvisionDvrProxyService(
    upstreamAlertStreamUri: upstreamUri,
    upstreamAuth: DvrHttpAuthConfig(
      mode: parseDvrHttpAuthMode(upstreamAuthMode),
      username: upstreamUsername.trim().isEmpty
          ? null
          : upstreamUsername.trim(),
      password: upstreamPassword.isEmpty ? null : upstreamPassword,
    ),
    host: bindHost,
    port: bindPort,
    client: http.Client(),
  );

  await service.start();
  final endpoint = service.endpoint;
  stdout.writeln('ONYX local Hikvision DVR proxy is live.');
  stdout.writeln('Bind: ${endpoint ?? 'http://$bindHost:$bindPort'}');
  stdout.writeln(
    'Health: ${(endpoint ?? Uri(scheme: 'http', host: bindHost, port: bindPort)).resolve('/health')}',
  );
  stdout.writeln('Upstream: $upstreamUri');

  final completer = Completer<void>();
  late final StreamSubscription<ProcessSignal> sigint;
  StreamSubscription<ProcessSignal>? sigterm;
  Future<void> shutdown() async {
    if (!completer.isCompleted) {
      completer.complete();
    }
    await sigint.cancel();
    await sigterm?.cancel();
    await service.close();
  }

  sigint = ProcessSignal.sigint.watch().listen((_) {
    unawaited(shutdown());
  });
  if (!Platform.isWindows) {
    sigterm = ProcessSignal.sigterm.watch().listen((_) {
      unawaited(shutdown());
    });
  }
  await completer.future;
}

File _resolveConfigPath(List<String> args) {
  final index = args.indexOf('--config');
  if (index >= 0 && index + 1 < args.length) {
    return File(args[index + 1]).absolute;
  }
  return File('config/onyx.local.json').absolute;
}

Future<Map<String, Object?>> _readConfig(File path) async {
  final raw = await path.readAsString();
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw const FormatException('Config must be a JSON object.');
  }
  return decoded.map(
    (key, value) => MapEntry(key.toString(), value as Object?),
  );
}

String _readString(
  Map<String, Object?> config,
  String key, {
  String fallback = '',
}) {
  return (config[key] ?? fallback).toString().trim();
}

int _readInt(Map<String, Object?> config, String key, {int fallback = 0}) {
  return int.tryParse(_readString(config, key, fallback: '$fallback')) ??
      fallback;
}
