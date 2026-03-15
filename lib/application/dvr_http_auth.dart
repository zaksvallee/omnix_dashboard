import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

enum DvrHttpAuthMode { none, bearer, digest }

DvrHttpAuthMode parseDvrHttpAuthMode(String raw) {
  final normalized = raw.trim().toLowerCase().replaceAll('-', '_');
  return switch (normalized) {
    'bearer' => DvrHttpAuthMode.bearer,
    'digest' => DvrHttpAuthMode.digest,
    _ => DvrHttpAuthMode.none,
  };
}

class DvrHttpAuthConfig {
  final DvrHttpAuthMode mode;
  final String? bearerToken;
  final String? username;
  final String? password;

  const DvrHttpAuthConfig({
    required this.mode,
    this.bearerToken,
    this.username,
    this.password,
  });

  Future<http.Response> get(
    http.Client client,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    final response = await send(
      client,
      'GET',
      uri,
      headers: headers,
    );
    return http.Response.fromStream(response);
  }

  Future<http.Response> head(
    http.Client client,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    final response = await send(
      client,
      'HEAD',
      uri,
      headers: headers,
    );
    return http.Response.fromStream(response);
  }

  Future<http.StreamedResponse> send(
    http.Client client,
    String method,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    final baseHeaders = _withBearer(headers);
    final initialRequest = http.Request(method, uri)..headers.addAll(baseHeaders);
    final initialResponse = await client.send(initialRequest);
    if (mode != DvrHttpAuthMode.digest || initialResponse.statusCode != 401) {
      return initialResponse;
    }

    final challenge = initialResponse.headers['www-authenticate'] ?? '';
    final digestHeader = _buildDigestAuthorization(
      challenge,
      method: method,
      uri: uri,
    );
    if (digestHeader == null) {
      return initialResponse;
    }

    await initialResponse.stream.drain<void>();
    final retryRequest = http.Request(method, uri)
      ..headers.addAll(baseHeaders)
      ..headers['Authorization'] = digestHeader;
    return client.send(retryRequest);
  }

  Map<String, String> _withBearer(Map<String, String> headers) {
    final resolved = <String, String>{...headers};
    final token = bearerToken?.trim();
    if (mode == DvrHttpAuthMode.bearer &&
        token != null &&
        token.isNotEmpty &&
        !resolved.containsKey('Authorization')) {
      resolved['Authorization'] = 'Bearer $token';
    }
    return resolved;
  }

  String? _buildDigestAuthorization(
    String challenge, {
    required String method,
    required Uri uri,
  }) {
    final user = username?.trim() ?? '';
    final pass = password ?? '';
    if (user.isEmpty || pass.isEmpty) {
      return null;
    }
    final attributes = _parseDigestChallenge(challenge);
    final realm = attributes['realm'];
    final nonce = attributes['nonce'];
    if (realm == null || nonce == null || realm.isEmpty || nonce.isEmpty) {
      return null;
    }

    final uriPath = uri.path.isEmpty
        ? '/'
        : uri.path + (uri.hasQuery ? '?${uri.query}' : '');
    final qop = (attributes['qop'] ?? '').split(',').map((entry) => entry.trim()).contains('auth')
        ? 'auth'
        : '';
    final nc = '00000001';
    final cnonce = md5
        .convert(
          utf8.encode(
            '${DateTime.now().microsecondsSinceEpoch}|$uriPath|${Random().nextInt(1 << 32)}',
          ),
        )
        .toString()
        .substring(0, 16);
    final ha1 = md5.convert(utf8.encode('$user:$realm:$pass')).toString();
    final ha2 = md5.convert(utf8.encode('${method.toUpperCase()}:$uriPath')).toString();
    final response = qop.isNotEmpty
        ? md5.convert(utf8.encode('$ha1:$nonce:$nc:$cnonce:$qop:$ha2')).toString()
        : md5.convert(utf8.encode('$ha1:$nonce:$ha2')).toString();

    final parts = <String>[
      'Digest username="$user"',
      'realm="$realm"',
      'nonce="$nonce"',
      'uri="$uriPath"',
      if ((attributes['opaque'] ?? '').isNotEmpty)
        'opaque="${attributes['opaque']}"',
      if ((attributes['algorithm'] ?? '').isNotEmpty)
        'algorithm=${attributes['algorithm']}',
      if (qop.isNotEmpty) 'qop=$qop',
      if (qop.isNotEmpty) 'nc=$nc',
      if (qop.isNotEmpty) 'cnonce="$cnonce"',
      'response="$response"',
    ];
    return parts.join(', ');
  }

  Map<String, String> _parseDigestChallenge(String challenge) {
    final normalized = challenge.trim();
    if (!normalized.toLowerCase().startsWith('digest')) {
      return const <String, String>{};
    }
    final matches = RegExp(
      r'(\w+)=(?:"([^"]*)"|([^,\s]+))',
    ).allMatches(normalized);
    final values = <String, String>{};
    for (final match in matches) {
      final key = match.group(1)?.trim();
      final quoted = match.group(2);
      final plain = match.group(3);
      if (key == null || key.isEmpty) {
        continue;
      }
      values[key.toLowerCase()] = (quoted ?? plain ?? '').trim();
    }
    return values;
  }
}
