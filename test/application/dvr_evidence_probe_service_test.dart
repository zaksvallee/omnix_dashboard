import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/dvr_evidence_probe_service.dart';
import 'package:omnix_dashboard/application/dvr_http_auth.dart';
import 'package:omnix_dashboard/application/video_bridge_runtime.dart';
import 'package:omnix_dashboard/domain/intelligence/intel_ingestion.dart';

void main() {
  test(
    'dvr evidence probe verifies snapshot and clip refs with digest auth',
    () async {
      final requests = <http.BaseRequest>[];
      final client = MockClient((request) async {
        requests.add(request);
        final authorized = (request.headers['Authorization'] ?? '').startsWith(
          'Digest ',
        );
        if (!authorized) {
          return http.Response(
            '',
            401,
            headers: {
              'www-authenticate':
                  'Digest realm="Hikvision", nonce="probe123", qop="auth"',
            },
          );
        }
        if (request.method == 'HEAD' &&
            request.url.toString().endsWith('/picture')) {
          return http.Response('', 200);
        }
        if (request.method == 'HEAD' &&
            request.url.toString().endsWith('/clip.mp4')) {
          return http.Response('', 405);
        }
        if (request.method == 'GET' &&
            request.url.toString().endsWith('/clip.mp4')) {
          expect(request.headers['Range'], 'bytes=0-0');
          return http.Response('', 206);
        }
        return http.Response('', 404);
      });
      final service = HttpDvrEvidenceProbeService(
        client: client,
        authMode: DvrHttpAuthMode.digest,
        username: 'operator',
        password: 'secret',
        maxQueueDepth: 4,
      );

      final result = await service.probeBatch([
        NormalizedIntelRecord(
          provider: 'hikvision_dvr_monitor_only',
          sourceType: 'dvr',
          externalId: 'DVR-EVT-1001',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          cameraId: 'channel-1',
          zone: 'loading_bay',
          objectLabel: 'vehicle',
          headline: 'HIKVISION_DVR_MONITOR_ONLY MOTION',
          summary: 'provider:hikvision_dvr_monitor_only | camera:channel-1',
          riskScore: 88,
          occurredAtUtc: DateTime.now().toUtc(),
          snapshotUrl:
              'http://192.168.8.105/ISAPI/Streaming/channels/101/picture',
          clipUrl: 'http://192.168.8.105/api/dvr/events/DVR-EVT-1001/clip.mp4',
        ),
      ]);

      expect(result.snapshot.verifiedCount, 2);
      expect(result.snapshot.failureCount, 0);
      expect(result.snapshot.cameras, hasLength(1));
      expect(result.snapshot.cameras.single.cameraId, 'channel-1');
      expect(result.snapshot.cameras.single.snapshotVerified, 1);
      expect(result.snapshot.cameras.single.clipVerified, 1);
      expect(result.snapshot.cameras.single.status, 'healthy');
      expect(
        requests.where((request) {
          return (request.headers['Authorization'] ?? '').startsWith('Digest ');
        }).length,
        greaterThanOrEqualTo(3),
      );
    },
  );

  test(
    'dvr evidence probe ignores non-dvr records and reports stale cameras',
    () async {
      final client = MockClient((request) async => http.Response('', 200));
      final service = HttpDvrEvidenceProbeService(
        client: client,
        maxQueueDepth: 1,
        staleFrameThreshold: const Duration(minutes: 10),
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
          summary: 'ignored',
          riskScore: 90,
          occurredAtUtc: DateTime.now().toUtc(),
          snapshotUrl: 'https://edge.example.com/api/events/evt-1/snapshot.jpg',
        ),
        NormalizedIntelRecord(
          provider: 'generic_dvr',
          sourceType: 'dvr',
          externalId: 'GEN-DVR-1',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          cameraId: 'GEN-CAM-1',
          zone: 'parking_north',
          headline: 'GENERIC_DVR MOTION',
          summary: 'included',
          riskScore: 72,
          occurredAtUtc: DateTime.now().toUtc().subtract(
            const Duration(hours: 1),
          ),
          snapshotUrl:
              'https://dvr.example.com/api/dvr/events/GEN-DVR-1/snapshot.jpg',
        ),
      ]);

      expect(result.snapshot.queueDepth, 1);
      expect(result.snapshot.cameras, hasLength(1));
      expect(result.snapshot.cameras.single.cameraId, 'GEN-CAM-1');
      expect(result.snapshot.cameras.single.status, 'stale');
    },
  );

  test('dvr-backed video evidence probe adapts dvr probe snapshot', () async {
    final service = DvrBackedVideoEvidenceProbeService(
      delegate: _FakeDvrEvidenceProbeService(),
    );

    final result = await service.probeBatch(const []);

    expect(result.snapshot.verifiedCount, 3);
    expect(result.snapshot.cameras.single.cameraId, 'DVR-001');
    expect(result.snapshot.cameras.single.status, 'healthy');
  });
}

class _FakeDvrEvidenceProbeService extends HttpDvrEvidenceProbeService {
  _FakeDvrEvidenceProbeService()
    : super(client: MockClient((_) async => http.Response('', 200)));

  @override
  Future<DvrEvidenceProbeBatchResult> probeBatch(
    List<NormalizedIntelRecord> records,
  ) async {
    return DvrEvidenceProbeBatchResult(
      snapshot: DvrEvidenceProbeSnapshot(
        verifiedCount: 3,
        cameras: const [
          DvrCameraHealth(
            cameraId: 'DVR-001',
            snapshotVerified: 2,
            clipVerified: 1,
            status: 'healthy',
          ),
        ],
      ),
    );
  }
}
