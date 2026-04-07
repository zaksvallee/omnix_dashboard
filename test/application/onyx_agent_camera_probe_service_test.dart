import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:omnix_dashboard/application/onyx_agent_camera_probe_service.dart';

void main() {
  group('HttpOnyxAgentCameraProbeService', () {
    test(
      'normalizes targets and collects port plus HTTP status data',
      () async {
        final requestedPorts = <int>[];
        final requestedUris = <Uri>[];
        final service = HttpOnyxAgentCameraProbeService(
          client: http.Client(),
          portProbe: (host, port, timeout) async {
            expect(host, '192.168.1.64');
            requestedPorts.add(port);
            return port == 80 || port == 554;
          },
          httpStatusProbe: (uri, timeout) async {
            requestedUris.add(uri);
            if (uri.path == '/') {
              return 200;
            }
            return 404;
          },
        );

        final result = await service.probe('http://192.168.1.64:8080/live');

        expect(result.target, '192.168.1.64');
        expect(requestedPorts, <int>[80, 443, 554, 8899]);
        expect(result.openPorts[80], isTrue);
        expect(result.openPorts[443], isFalse);
        expect(result.openPorts[554], isTrue);
        expect(result.openPorts[8899], isFalse);
        expect(result.rootHttpStatus, 200);
        expect(result.onvifHttpStatus, 404);
        expect(
          requestedUris,
          contains(Uri.parse('http://192.168.1.64/onvif/device_service')),
        );
      },
    );

    test(
      'operator summary points to LAN checks when no ports are reachable',
      () {
        const result = OnyxAgentCameraProbeResult(
          target: '192.168.1.99',
          openPorts: <int, bool>{
            80: false,
            443: false,
            554: false,
            8899: false,
          },
        );

        final summary = result.toOperatorSummary();

        expect(summary, contains('HTTP 80: closed'));
        expect(summary, contains('RTSP 554: closed'));
        expect(summary, contains('verify power/PoE'));
      },
    );

    test('probes TCP ports in parallel before collecting statuses', () async {
      final startedPorts = <int>[];
      final release = Completer<void>();
      final service = HttpOnyxAgentCameraProbeService(
        client: http.Client(),
        portProbe: (host, port, timeout) async {
          startedPorts.add(port);
          if (startedPorts.length == 4 && !release.isCompleted) {
            release.complete();
          }
          await release.future.timeout(const Duration(milliseconds: 100));
          return port == 80;
        },
        httpStatusProbe: (_, _) async => 200,
      );

      final result = await service.probe('192.168.1.64');

      expect(startedPorts, <int>[80, 443, 554, 8899]);
      expect(result.openPorts[80], isTrue);
    });
  });
}
