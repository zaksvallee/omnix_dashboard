import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/cctv_evidence_probe_service.dart';
import 'package:omnix_dashboard/domain/intelligence/intel_ingestion.dart';

void main() {
  test(
    'evidence probe verifies snapshot and clip refs with bounded retries',
    () async {
      final client = MockClient((request) async {
        if (request.method == 'HEAD' &&
            request.url.toString().endsWith('/snapshot.jpg')) {
          return http.Response('', 200);
        }
        if (request.method == 'HEAD' &&
            request.url.toString().endsWith('/clip.mp4')) {
          return http.Response('', 405);
        }
        if (request.method == 'GET' &&
            request.url.toString().endsWith('/clip.mp4')) {
          return http.Response('', 206);
        }
        return http.Response('', 404);
      });
      final service = HttpCctvEvidenceProbeService(
        client: client,
        maxQueueDepth: 4,
      );

      final result = await service.probeBatch([
        NormalizedIntelRecord(
          provider: 'frigate',
          sourceType: 'hardware',
          externalId: 'evt-1',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          cameraId: 'front-gate',
          zone: 'north_gate',
          objectLabel: 'person',
          headline: 'FRIGATE INTRUSION',
          summary: 'CCTV person detected in north_gate',
          riskScore: 94,
          occurredAtUtc: DateTime.now().toUtc(),
          snapshotUrl: 'https://edge.example.com/api/events/evt-1/snapshot.jpg',
          clipUrl: 'https://edge.example.com/api/events/evt-1/clip.mp4',
        ),
      ]);

      expect(result.snapshot.verifiedCount, 2);
      expect(result.snapshot.failureCount, 0);
      expect(result.snapshot.droppedCount, 0);
      expect(result.snapshot.cameras, hasLength(1));
      expect(result.snapshot.cameras.first.cameraId, 'front-gate');
      expect(result.snapshot.cameras.first.snapshotVerified, 1);
      expect(result.snapshot.cameras.first.clipVerified, 1);
      expect(result.snapshot.cameras.first.status, 'healthy');
    },
  );

  test('evidence probe drops overflow when queue limit is exceeded', () async {
    final client = MockClient((request) async => http.Response('', 200));
    final service = HttpCctvEvidenceProbeService(
      client: client,
      maxQueueDepth: 1,
    );

    final result = await service.probeBatch([
      NormalizedIntelRecord(
        provider: 'frigate',
        sourceType: 'hardware',
        externalId: 'evt-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        cameraId: 'front-gate',
        headline: 'FRIGATE INTRUSION',
        summary: 'First',
        riskScore: 95,
        occurredAtUtc: DateTime.now().toUtc(),
        snapshotUrl: 'https://edge.example.com/api/events/evt-1/snapshot.jpg',
      ),
      NormalizedIntelRecord(
        provider: 'frigate',
        sourceType: 'hardware',
        externalId: 'evt-2',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        cameraId: 'rear-gate',
        headline: 'FRIGATE INTRUSION',
        summary: 'Second',
        riskScore: 50,
        occurredAtUtc: DateTime.now().toUtc(),
        snapshotUrl: 'https://edge.example.com/api/events/evt-2/snapshot.jpg',
        clipUrl: 'https://edge.example.com/api/events/evt-2/clip.mp4',
      ),
    ]);

    expect(result.snapshot.queueDepth, 1);
    expect(result.snapshot.droppedCount, 2);
    expect(result.snapshot.lastAlert, contains('queue drop 2'));
  });

  test(
    'evidence probe persists vehicle semantics for plate-hit records without object labels',
    () async {
      final client = MockClient((request) async => http.Response('', 200));
      final service = HttpCctvEvidenceProbeService(
        client: client,
        maxQueueDepth: 2,
      );

      final result = await service.probeBatch([
        NormalizedIntelRecord(
          provider: 'hik_connect_openapi',
          sourceType: 'hardware',
          externalId: 'evt-lpr-1',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          cameraId: 'driveway-cam',
          zone: 'front_drive',
          objectLabel: '',
          plateNumber: 'CA123456',
          headline: 'HIK CONNECT ANPR',
          summary: 'plate hit without semantic label',
          riskScore: 68,
          occurredAtUtc: DateTime.now().toUtc(),
          snapshotUrl:
              'https://edge.example.com/api/events/evt-lpr-1/snapshot.jpg',
        ),
      ]);

      expect(result.snapshot.cameras, hasLength(1));
      expect(result.snapshot.cameras.single.lastObjectLabel, 'vehicle');
    },
  );
}
