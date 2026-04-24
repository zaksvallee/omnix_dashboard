import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:omnix_dashboard/application/dvr_http_auth.dart';
import 'package:omnix_dashboard/application/local_hikvision_dvr_proxy_service.dart';

void main() {
  test(
    'local Hikvision DVR proxy relays alert stream as multipart/mixed with '
    'upstream boundary',
    () async {
      final upstream = await HttpServer.bind('127.0.0.1', 0);
      upstream.listen((request) async {
        expect(request.uri.path, '/ISAPI/Event/notification/alertStream');
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.set(
          HttpHeaders.contentTypeHeader,
          'multipart/mixed; boundary=boundary',
        );
        request.response.write(
          '--boundary\r\n'
          'Content-Type: application/xml\r\n\r\n'
          '<EventNotificationAlert version="2.0">'
          '<channelID>16</channelID>'
          '<dateTime>2026-04-03T15:11:00Z</dateTime>'
          '<eventType>VMD</eventType>'
          '<eventState>active</eventState>'
          '<eventDescription>Motion alarm</eventDescription>'
          '</EventNotificationAlert>\r\n',
        );
        await request.response.flush();
        // Hold the upstream connection open briefly so the downstream response
        // is demonstrably held open as well (streaming semantics, not a
        // single-document response).
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await request.response.close();
      });

      final proxy = LocalHikvisionDvrProxyService(
        upstreamAlertStreamUri: Uri.parse(
          'http://127.0.0.1:${upstream.port}/ISAPI/Event/notification/alertStream',
        ),
        upstreamAuth: const DvrHttpAuthConfig(mode: DvrHttpAuthMode.none),
        host: '127.0.0.1',
        port: 0,
        client: http.Client(),
        upstreamReconnectDelay: const Duration(milliseconds: 25),
        upstreamRequestTimeout: const Duration(seconds: 2),
      );
      await proxy.start();
      addTearDown(() async {
        await proxy.close();
        await upstream.close(force: true);
      });

      final endpoint = proxy.endpoint!;
      await _waitForBufferedAlertCount(endpoint, atLeast: 1);

      final httpClient = http.Client();
      addTearDown(httpClient.close);
      final streamed = await httpClient.send(
        http.Request(
          'GET',
          endpoint.resolve('/ISAPI/Event/notification/alertStream'),
        ),
      );
      expect(streamed.statusCode, HttpStatus.ok);
      expect(
        streamed.headers[HttpHeaders.contentTypeHeader],
        contains('multipart/mixed'),
      );
      expect(
        streamed.headers[HttpHeaders.contentTypeHeader],
        contains('boundary=boundary'),
      );
      expect(
        streamed.headers[HttpHeaders.accessControlAllowOriginHeader],
        equals('*'),
      );
      expect(
        streamed.headers[HttpHeaders.contentLengthHeader],
        isNull,
        reason:
            'Streaming alertStream must not carry a Content-Length header; '
            'Content-Length indicates a finite single-document response.',
      );

      final body = await _readStreamedBodyUntil(streamed, minBytes: 150);
      expect(body, contains('--boundary'));
      expect(body, contains('<EventNotificationAlert'));
      expect(body, contains('<eventType>VMD</eventType>'));

      final health = await http.get(endpoint.resolve('/health'));
      expect(health.statusCode, HttpStatus.ok);
      final payload = jsonDecode(health.body) as Map<String, Object?>;
      expect(payload['running'], isTrue);
      expect(
        (payload['upstream_alert_stream'] ?? '').toString(),
        contains('${upstream.port}'),
      );
    },
  );

  test(
    'local Hikvision DVR proxy relays snapshot HEAD and GET requests',
    () async {
      final upstream = await HttpServer.bind('127.0.0.1', 0);
      upstream.listen((request) async {
        if (request.uri.path == '/ISAPI/Event/notification/alertStream') {
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
          return;
        }
        expect(request.uri.path, '/ISAPI/Streaming/channels/1601/picture');
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.set(
          HttpHeaders.contentTypeHeader,
          'image/jpeg',
        );
        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        if (request.method == 'GET') {
          request.response.add(const <int>[1, 2, 3, 4]);
        }
        await request.response.close();
      });

      final proxy = LocalHikvisionDvrProxyService(
        upstreamAlertStreamUri: Uri.parse(
          'http://127.0.0.1:${upstream.port}/ISAPI/Event/notification/alertStream',
        ),
        upstreamAuth: const DvrHttpAuthConfig(mode: DvrHttpAuthMode.none),
        host: '127.0.0.1',
        port: 0,
        client: http.Client(),
        upstreamRequestTimeout: const Duration(seconds: 2),
      );
      await proxy.start();
      addTearDown(() async {
        await proxy.close();
        await upstream.close(force: true);
      });

      final endpoint = proxy.endpoint!;
      final head = await http.head(
        endpoint.resolve('/ISAPI/Streaming/channels/1601/picture'),
      );
      expect(head.statusCode, HttpStatus.ok);
      expect(
        head.headers[HttpHeaders.contentTypeHeader],
        contains('image/jpeg'),
      );
      expect(
        head.headers[HttpHeaders.accessControlAllowOriginHeader],
        equals('*'),
      );

      final get = await http.get(
        endpoint.resolve('/ISAPI/Streaming/channels/1601/picture'),
      );
      expect(get.statusCode, HttpStatus.ok);
      expect(
        get.headers[HttpHeaders.contentTypeHeader],
        contains('image/jpeg'),
      );
      expect(get.bodyBytes, equals(const <int>[1, 2, 3, 4]));
    },
  );

  test(
    'local Hikvision DVR proxy exposes an MJPEG relay and browser player page',
    () async {
      final upstream = await HttpServer.bind('127.0.0.1', 0);
      var snapshotHits = 0;
      upstream.listen((request) async {
        if (request.uri.path == '/ISAPI/Streaming/channels/1601/picture') {
          snapshotHits += 1;
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.set(
            HttpHeaders.contentTypeHeader,
            'image/jpeg',
          );
          request.response.add(const <int>[1, 2, 3, 4]);
          await request.response.close();
          return;
        }
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });

      final proxy = LocalHikvisionDvrProxyService(
        upstreamAlertStreamUri: Uri.parse(
          'http://127.0.0.1:${upstream.port}/ISAPI/Event/notification/alertStream',
        ),
        upstreamAuth: const DvrHttpAuthConfig(mode: DvrHttpAuthMode.none),
        host: '127.0.0.1',
        port: 0,
        client: http.Client(),
        upstreamRequestTimeout: const Duration(seconds: 2),
        mjpegFrameInterval: const Duration(milliseconds: 10),
      );
      await proxy.start();
      addTearDown(() async {
        await proxy.close();
        await upstream.close(force: true);
      });

      final endpoint = proxy.endpoint!;
      final relayHead = await http.head(
        endpoint.resolve('/onyx/live/channels/1601.mjpg'),
      );
      expect(relayHead.statusCode, HttpStatus.ok);
      expect(
        relayHead.headers[HttpHeaders.contentTypeHeader],
        contains('multipart/x-mixed-replace'),
      );

      final relayGet = await http.get(
        endpoint.resolve('/onyx/live/channels/1601.mjpg?frame_limit=1'),
      );
      expect(relayGet.statusCode, HttpStatus.ok);
      expect(
        relayGet.headers[HttpHeaders.contentTypeHeader],
        contains('multipart/x-mixed-replace'),
      );
      expect(relayGet.body, contains('--onyxframe'));
      expect(
        _containsBytes(relayGet.bodyBytes, const <int>[1, 2, 3, 4]),
        isTrue,
      );
      expect(snapshotHits, greaterThanOrEqualTo(2));

      final status = await http.get(
        endpoint.resolve('/onyx/live/channels/1601/status'),
      );
      expect(status.statusCode, HttpStatus.ok);
      expect(
        status.headers[HttpHeaders.contentTypeHeader],
        contains('application/json'),
      );
      final statusPayload = jsonDecode(status.body) as Map<String, Object?>;
      expect(statusPayload['ok'], isTrue);
      expect(statusPayload['stream_id'], '1601');
      expect(statusPayload['status'], 'ready');
      expect(statusPayload['active_clients'], 0);
      expect((statusPayload['last_frame_at_utc'] ?? '').toString(), isNotEmpty);
      expect(statusPayload['last_error'], isEmpty);

      final player = await http.get(
        endpoint.resolve('/onyx/live/channels/1601/player'),
      );
      expect(player.statusCode, HttpStatus.ok);
      expect(
        player.headers[HttpHeaders.contentTypeHeader],
        contains('text/html'),
      );
      expect(player.body, contains('Live Relay • Channel 1601'));
      expect(player.body, contains('/onyx/live/channels/1601.mjpg'));
      expect(player.body, contains('/onyx/live/channels/1601/status'));
      expect(player.body, contains('Checking relay status'));
    },
  );

  test(
    'local Hikvision DVR proxy honors MJPEG frame_limit query parameter',
    () async {
      final upstream = await HttpServer.bind('127.0.0.1', 0);
      var snapshotHits = 0;
      upstream.listen((request) async {
        if (request.uri.path == '/ISAPI/Streaming/channels/1601/picture') {
          snapshotHits += 1;
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.set(
            HttpHeaders.contentTypeHeader,
            'image/jpeg',
          );
          switch (snapshotHits) {
            case 1:
              request.response.add(const <int>[10, 11, 12, 13]);
              break;
            case 2:
              request.response.add(const <int>[20, 21, 22, 23]);
              break;
            default:
              request.response.add(const <int>[30, 31, 32, 33]);
              break;
          }
          await request.response.close();
          return;
        }
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });

      final proxy = LocalHikvisionDvrProxyService(
        upstreamAlertStreamUri: Uri.parse(
          'http://127.0.0.1:${upstream.port}/ISAPI/Event/notification/alertStream',
        ),
        upstreamAuth: const DvrHttpAuthConfig(mode: DvrHttpAuthMode.none),
        host: '127.0.0.1',
        port: 0,
        client: http.Client(),
        upstreamRequestTimeout: const Duration(seconds: 2),
        mjpegFrameInterval: const Duration(milliseconds: 10),
      );
      await proxy.start();
      addTearDown(() async {
        await proxy.close();
        await upstream.close(force: true);
      });

      final endpoint = proxy.endpoint!;
      final relayGet = await http.get(
        endpoint.resolve('/onyx/live/channels/1601.mjpg?frame_limit=2'),
      );

      expect(relayGet.statusCode, HttpStatus.ok);
      expect(snapshotHits, 2);
      expect(relayGet.body, contains('--onyxframe'));
      expect(
        _containsBytes(relayGet.bodyBytes, const <int>[10, 11, 12, 13]),
        isTrue,
      );
      expect(
        _containsBytes(relayGet.bodyBytes, const <int>[20, 21, 22, 23]),
        isTrue,
      );
      expect(
        _containsBytes(relayGet.bodyBytes, const <int>[30, 31, 32, 33]),
        isFalse,
      );
    },
  );

  test(
    'local Hikvision DVR proxy prepends buffered alerts as catch-up when a '
    'downstream subscriber connects',
    () async {
      final upstream = await HttpServer.bind('127.0.0.1', 0);
      var connectionCount = 0;
      upstream.listen((request) async {
        expect(request.uri.path, '/ISAPI/Event/notification/alertStream');
        connectionCount += 1;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.set(
          HttpHeaders.contentTypeHeader,
          'multipart/mixed; boundary=boundary',
        );
        if (connectionCount == 1) {
          request.response.write(
            '--boundary\r\n'
            'Content-Type: application/xml\r\n\r\n'
            '<EventNotificationAlert version="2.0">'
            '<channelID>11</channelID>'
            '<dateTime>2026-04-04T18:02:00Z</dateTime>'
            '<eventType>VMD</eventType>'
            '<eventState>active</eventState>'
            '<eventDescription>Motion alarm</eventDescription>'
            '</EventNotificationAlert>\r\n',
          );
          await request.response.flush();
        }
        // Hold the upstream open briefly on each connect; downstream subscriber
        // connects between event emission and upstream close.
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await request.response.close();
      });

      final proxy = LocalHikvisionDvrProxyService(
        upstreamAlertStreamUri: Uri.parse(
          'http://127.0.0.1:${upstream.port}/ISAPI/Event/notification/alertStream',
        ),
        upstreamAuth: const DvrHttpAuthConfig(mode: DvrHttpAuthMode.none),
        host: '127.0.0.1',
        port: 0,
        client: http.Client(),
        upstreamReconnectDelay: const Duration(milliseconds: 25),
        bufferedAlertRetentionWindow: const Duration(seconds: 30),
        upstreamRequestTimeout: const Duration(seconds: 2),
      );
      await proxy.start();
      addTearDown(() async {
        await proxy.close();
        await upstream.close(force: true);
      });

      final endpoint = proxy.endpoint!;
      await _waitForBufferedAlertCount(endpoint, atLeast: 1);

      final httpClient = http.Client();
      addTearDown(httpClient.close);
      final streamed = await httpClient.send(
        http.Request(
          'GET',
          endpoint.resolve('/ISAPI/Event/notification/alertStream'),
        ),
      );
      expect(streamed.statusCode, HttpStatus.ok);
      expect(
        streamed.headers[HttpHeaders.contentTypeHeader],
        contains('multipart/mixed'),
      );

      final body = await _readStreamedBodyUntil(streamed, minBytes: 150);
      expect(body, contains('--boundary'));
      expect(body, contains('<EventNotificationAlert'));
      expect(body, contains('<channelID>11</channelID>'));

      final health = await http.get(endpoint.resolve('/health'));
      final payload = jsonDecode(health.body) as Map<String, Object?>;
      expect((payload['last_alert_at_utc'] ?? '').toString(), isNotEmpty);
    },
  );

  test(
    'local Hikvision DVR proxy reports reconnecting during upstream reconnect delay',
    () async {
      final upstream = await HttpServer.bind('127.0.0.1', 0);
      var connectionCount = 0;
      upstream.listen((request) async {
        expect(request.uri.path, '/ISAPI/Event/notification/alertStream');
        connectionCount += 1;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.set(
          HttpHeaders.contentTypeHeader,
          'multipart/x-mixed-replace; boundary=boundary',
        );
        request.response.write('''
--boundary
Content-Type: application/xml

<EventNotificationAlert version="2.0">
  <channelID>19</channelID>
  <dateTime>2026-04-05T06:31:00Z</dateTime>
  <eventType>VMD</eventType>
  <eventState>active</eventState>
  <eventDescription>Motion alarm</eventDescription>
</EventNotificationAlert>
''');
        await request.response.close();
      });

      final proxy = LocalHikvisionDvrProxyService(
        upstreamAlertStreamUri: Uri.parse(
          'http://127.0.0.1:${upstream.port}/ISAPI/Event/notification/alertStream',
        ),
        upstreamAuth: const DvrHttpAuthConfig(mode: DvrHttpAuthMode.none),
        host: '127.0.0.1',
        port: 0,
        client: http.Client(),
        alertStreamIdleWindow: const Duration(milliseconds: 20),
        upstreamReconnectDelay: const Duration(milliseconds: 250),
        upstreamRequestTimeout: const Duration(seconds: 2),
      );
      await proxy.start();
      addTearDown(() async {
        await proxy.close();
        await upstream.close(force: true);
      });

      final endpoint = proxy.endpoint!;
      Map<String, Object?> payload = const <String, Object?>{};
      for (var attempt = 0; attempt < 10; attempt += 1) {
        final health = await http.get(endpoint.resolve('/health'));
        payload = jsonDecode(health.body) as Map<String, Object?>;
        if ((payload['upstream_stream_status'] ?? '') == 'reconnecting') {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }

      expect(connectionCount, greaterThanOrEqualTo(1));
      expect(payload['upstream_stream_status'], 'reconnecting');
      expect(payload['upstream_stream_connected'], isFalse);
      expect(payload['buffered_alert_count'], greaterThanOrEqualTo(1));
    },
  );
}

Future<void> _waitForBufferedAlertCount(
  Uri endpoint, {
  required int atLeast,
  int attempts = 40,
  Duration pollInterval = const Duration(milliseconds: 25),
}) async {
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    await Future<void>.delayed(pollInterval);
    final response = await http.get(endpoint.resolve('/health'));
    if (response.statusCode != HttpStatus.ok) continue;
    final payload = jsonDecode(response.body) as Map<String, Object?>;
    final count =
        int.tryParse((payload['buffered_alert_count'] ?? '0').toString()) ?? 0;
    if (count >= atLeast) return;
  }
}

Future<String> _readStreamedBodyUntil(
  http.StreamedResponse streamed, {
  required int minBytes,
  Duration timeout = const Duration(seconds: 3),
}) async {
  final bytes = <int>[];
  final done = Completer<void>();
  final subscription = streamed.stream.listen(
    (chunk) {
      bytes.addAll(chunk);
      if (bytes.length >= minBytes && !done.isCompleted) {
        done.complete();
      }
    },
    onDone: () {
      if (!done.isCompleted) done.complete();
    },
    onError: (_) {
      if (!done.isCompleted) done.complete();
    },
    cancelOnError: false,
  );
  final giveUp = Timer(timeout, () {
    if (!done.isCompleted) done.complete();
  });
  await done.future;
  giveUp.cancel();
  await subscription.cancel();
  return utf8.decode(bytes, allowMalformed: true);
}

bool _containsBytes(List<int> haystack, List<int> needle) {
  if (needle.isEmpty || haystack.length < needle.length) {
    return false;
  }
  for (var index = 0; index <= haystack.length - needle.length; index += 1) {
    var matches = true;
    for (var offset = 0; offset < needle.length; offset += 1) {
      if (haystack[index + offset] != needle[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      return true;
    }
  }
  return false;
}
