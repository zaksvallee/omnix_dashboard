import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:omnix_dashboard/application/site_awareness/onyx_hik_isapi_stream_awareness_service.dart';
import 'package:omnix_dashboard/application/site_awareness/onyx_site_awareness_snapshot.dart';

void main() {
  group('OnyxHikIsapiStreamAwarenessService', () {
    test('service starts and connects', () async {
      final now = DateTime.utc(2026, 4, 8, 12, 0);
      final controller = StreamController<List<int>>();
      final client = _FakeStreamClient((_, _) async {
        return http.StreamedResponse(controller.stream, 200);
      });
      final service = OnyxHikIsapiStreamAwarenessService(
        host: '192.168.0.117',
        username: 'admin',
        password: 'secret',
        client: client,
        publishInterval: const Duration(milliseconds: 30),
        clock: () => now,
      );
      addTearDown(() async {
        await service.stop();
        await controller.close();
      });

      await service.start(siteId: 'SITE-1', clientId: 'CLIENT-1');
      await _waitFor(() => service.isConnected);

      expect(service.isConnected, isTrue);
      expect(client.requestCount, 1);
    });

    test('processes multipart stream correctly', () async {
      final now = DateTime.utc(2026, 4, 8, 12, 0, 2);
      final controller = StreamController<List<int>>();
      final client = _FakeStreamClient((_, _) async {
        return http.StreamedResponse(controller.stream, 200);
      });
      final service = OnyxHikIsapiStreamAwarenessService(
        host: '192.168.0.117',
        username: 'admin',
        password: 'secret',
        client: client,
        publishInterval: const Duration(milliseconds: 30),
        clock: () => now,
      );
      addTearDown(() async {
        await service.stop();
        await controller.close();
      });

      await service.start(siteId: 'SITE-1', clientId: 'CLIENT-1');
      await _waitFor(() => service.isConnected);
      final snapshotFuture = service.snapshots.first.timeout(
        const Duration(seconds: 2),
      );
      controller.add(
        utf8.encode(
          _multipartPayload(<String>[
            _alertXml(
              channelId: '1',
              eventType: 'VMD',
              targetType: 'animal',
              dateTime: DateTime.utc(2026, 4, 8, 12, 0),
            ),
            _alertXml(
              channelId: '2',
              eventType: 'VMD',
              dateTime: DateTime.utc(2026, 4, 8, 12, 0, 1),
            ),
          ]),
        ),
      );

      final snapshot = await snapshotFuture;

      expect(snapshot.detections.animalCount, 1);
      expect(snapshot.detections.motionCount, 1);
      expect(snapshot.channels['1']!.status, OnyxChannelStatusType.active);
      expect(snapshot.channels['2']!.status, OnyxChannelStatusType.active);
    });

    test('publishes snapshot after 30 seconds', () async {
      final now = DateTime.utc(2026, 4, 8, 12, 1, 30);
      final controller = StreamController<List<int>>();
      final client = _FakeStreamClient((_, _) async {
        return http.StreamedResponse(controller.stream, 200);
      });
      final service = OnyxHikIsapiStreamAwarenessService(
        host: '192.168.0.117',
        username: 'admin',
        password: 'secret',
        client: client,
        publishInterval: const Duration(milliseconds: 30),
        clock: () => now,
      );
      addTearDown(() async {
        await service.stop();
        await controller.close();
      });

      await service.start(siteId: 'SITE-1', clientId: 'CLIENT-1');
      await _waitFor(() => service.isConnected);
      final snapshotFuture = service.snapshots.first.timeout(
        const Duration(seconds: 2),
      );
      controller.add(
        utf8.encode(
          _multipartPayload(<String>[
            _alertXml(
              channelId: '3',
              eventType: 'VMD',
              dateTime: DateTime.utc(2026, 4, 8, 12, 1),
            ),
          ]),
        ),
      );

      final snapshot = await snapshotFuture;

      expect(snapshot.detections.motionCount, 1);
      expect(
        snapshot.snapshotAt.isAfter(DateTime.utc(2026, 4, 8, 12, 1)),
        isTrue,
      );
    });

    test('publishes immediately on humanDetected', () async {
      final now = DateTime.utc(2026, 4, 8, 12, 2);
      final controller = StreamController<List<int>>();
      final client = _FakeStreamClient((_, _) async {
        return http.StreamedResponse(controller.stream, 200);
      });
      final service = OnyxHikIsapiStreamAwarenessService(
        host: '192.168.0.117',
        username: 'admin',
        password: 'secret',
        client: client,
        publishInterval: const Duration(days: 1),
        clock: () => now,
      );
      addTearDown(() async {
        await service.stop();
        await controller.close();
      });

      await service.start(siteId: 'SITE-1', clientId: 'CLIENT-1');
      await _waitFor(() => service.isConnected);
      final snapshotFuture = service.snapshots.first.timeout(
        const Duration(seconds: 2),
      );
      controller.add(
        utf8.encode(
          _multipartPayload(<String>[
            _alertXml(
              channelId: '4',
              eventType: 'VMD',
              targetType: 'human',
              dateTime: DateTime.utc(2026, 4, 8, 12, 2),
            ),
          ]),
        ),
      );

      final snapshot = await snapshotFuture;

      expect(snapshot.detections.humanCount, 1);
      expect(snapshot.perimeterClear, isFalse);
    });

    test('retries on connection loss', () async {
      final now = DateTime.utc(2026, 4, 8, 12, 2, 30);
      final controller = StreamController<List<int>>();
      final client = _FakeStreamClient((attempt, _) async {
        if (attempt == 0) {
          return http.StreamedResponse(Stream<List<int>>.empty(), 503);
        }
        return http.StreamedResponse(controller.stream, 200);
      });
      final service = OnyxHikIsapiStreamAwarenessService(
        host: '192.168.0.117',
        username: 'admin',
        password: 'secret',
        client: client,
        publishInterval: const Duration(milliseconds: 30),
        initialRetryDelay: const Duration(seconds: 1),
        maxRetryDelay: const Duration(seconds: 1),
        sleep: (_) => Future<void>.delayed(const Duration(milliseconds: 5)),
        clock: () => now,
      );
      addTearDown(() async {
        await service.stop();
        await controller.close();
      });

      await service.start(siteId: 'SITE-1', clientId: 'CLIENT-1');
      await _waitFor(() => client.requestCount >= 2 && service.isConnected);

      expect(client.requestCount, greaterThanOrEqualTo(2));
      expect(service.isConnected, isTrue);
    });

    test('known fault channels are flagged but not alarmed', () async {
      final now = DateTime.utc(2026, 4, 8, 12, 3);
      final controller = StreamController<List<int>>();
      final client = _FakeStreamClient((_, _) async {
        return http.StreamedResponse(controller.stream, 200);
      });
      final service = OnyxHikIsapiStreamAwarenessService(
        host: '192.168.0.117',
        username: 'admin',
        password: 'secret',
        client: client,
        knownFaultChannels: const <String>['11'],
        publishInterval: const Duration(milliseconds: 30),
        clock: () => now,
      );
      addTearDown(() async {
        await service.stop();
        await controller.close();
      });

      await service.start(siteId: 'SITE-1', clientId: 'CLIENT-1');
      await _waitFor(() => service.isConnected);
      final snapshotFuture = service.snapshots.first.timeout(
        const Duration(seconds: 2),
      );
      controller.add(
        utf8.encode(
          _multipartPayload(<String>[
            _alertXml(
              channelId: '11',
              eventType: 'videoloss',
              dateTime: DateTime.utc(2026, 4, 8, 12, 3),
            ),
          ]),
        ),
      );

      final snapshot = await snapshotFuture;

      expect(snapshot.knownFaults, contains('11'));
      expect(snapshot.channels['11']!.isFault, isTrue);
      expect(snapshot.activeAlerts, isEmpty);
    });
  });
}

class _FakeStreamClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(
    int attempt,
    http.BaseRequest request,
  )
  _handler;

  int requestCount = 0;

  _FakeStreamClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(requestCount, request);
    requestCount += 1;
    return response;
  }
}

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition not met before timeout.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

String _multipartPayload(List<String> xmlPayloads, {String boundary = 'hik'}) {
  return xmlPayloads
      .map(
        (payload) => [
          '--$boundary',
          'Content-Type: application/xml',
          '',
          payload,
        ].join('\r\n'),
      )
      .join('\r\n');
}

String _alertXml({
  required String channelId,
  required String eventType,
  required DateTime dateTime,
  String? targetType,
}) {
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<EventNotificationAlert version="2.0">
  <ipAddress>192.168.0.117</ipAddress>
  <portNo>80</portNo>
  <protocol>HTTP</protocol>
  <channelID>$channelId</channelID>
  <dateTime>${dateTime.toUtc().toIso8601String()}</dateTime>
  <eventType>$eventType</eventType>
  ${targetType == null ? '' : '<targetType>$targetType</targetType>'}
</EventNotificationAlert>
''';
}
