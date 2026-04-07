import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omnix_dashboard/application/monitoring_yolo_detector_health_service.dart';

void main() {
  group('MonitoringYoloDetectorHealthService', () {
    test('parses ready detector health payload', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'http://127.0.0.1:11636/health');
        return http.Response(
          jsonEncode(<String, Object?>{
            'status': 'ok',
            'backend': 'ultralytics',
            'ready': true,
            'detail': '',
            'last_error': null,
            'last_request_error': null,
            'last_request_at_epoch': 1775331628.9498339,
            'last_success_at_epoch': 1775331628.9498339,
            'successful_request_count': 4,
            'modules': <String, Object?>{
              'object_model': <String, Object?>{
                'enabled': true,
                'configured': true,
                'ready': true,
                'model': 'yolov8l.pt',
              },
              'face_recognition': <String, Object?>{
                'enabled': true,
                'configured': true,
                'ready': false,
                'detail': 'Gallery empty.',
                'gallery_dir': '/tmp/gallery',
                'gallery_image_count': 0,
              },
            },
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      });
      final service = HttpMonitoringYoloDetectorHealthService(client: client);

      final snapshot = await service.read(
        Uri.parse('http://127.0.0.1:11636/detect'),
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.endpoint.toString(), 'http://127.0.0.1:11636/health');
      expect(snapshot.reachable, isTrue);
      expect(snapshot.ready, isTrue);
      expect(snapshot.backend, 'ultralytics');
      expect(snapshot.lastError, isNull);
      expect(snapshot.successfulRequestCount, 4);
      expect(snapshot.lastRequestAtUtc, isNotNull);
      expect(snapshot.lastSuccessAtUtc, isNotNull);
      expect(snapshot.modules.keys, containsAll(<String>[
        'object_model',
        'face_recognition',
      ]));
      expect(snapshot.modules['object_model']!.ready, isTrue);
      expect(snapshot.modules['face_recognition']!.ready, isFalse);
      expect(snapshot.modules['face_recognition']!.detail, 'Gallery empty.');
      expect(snapshot.unhealthyEnabledModules.map((module) => module.name), [
        'face_recognition',
      ]);
    });

    test(
      'returns unreachable snapshot when the detector health probe fails',
      () async {
        final client = MockClient((request) async {
          throw http.ClientException('connection refused');
        });
        final service = HttpMonitoringYoloDetectorHealthService(client: client);

        final snapshot = await service.read(
          Uri.parse('http://127.0.0.1:11636/detect'),
        );

        expect(snapshot, isNotNull);
        expect(snapshot!.reachable, isFalse);
        expect(snapshot.ready, isFalse);
        expect(snapshot.detail, contains('connection refused'));
      },
    );
  });
}
