import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/cctv_bridge_service.dart';
import 'package:omnix_dashboard/application/cctv_evidence_probe_service.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/intelligence/intel_ingestion.dart';
import 'package:omnix_dashboard/domain/projection/operations_health_projection.dart';
import 'package:omnix_dashboard/domain/store/in_memory_event_store.dart';

void main() {
  test(
    'phase 1 pilot flow ingests frigate event with evidence and ops visibility',
    () async {
      final eventTime = DateTime.now().toUtc().subtract(
        const Duration(minutes: 2),
      );
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (url == 'https://edge.example.com/api/events') {
          return http.Response('''
[
  {
    "id": "evt-1001",
    "camera": "pilot_gate",
    "label": "person",
    "entered_zones": ["north_gate"],
    "top_score": 0.96,
    "start_time": "${eventTime.toIso8601String()}",
    "has_snapshot": true,
    "has_clip": true
  }
]
''', 200);
        }
        if (request.method == 'HEAD' && url.endsWith('/snapshot.jpg')) {
          return http.Response('', 200);
        }
        if (request.method == 'HEAD' && url.endsWith('/clip.mp4')) {
          return http.Response('', 405);
        }
        if (request.method == 'GET' && url.endsWith('/clip.mp4')) {
          return http.Response('', 206);
        }
        return http.Response('', 404);
      });

      final bridge = HttpCctvBridgeService(
        provider: 'frigate',
        eventsUri: Uri.parse('https://edge.example.com/api/events'),
        client: client,
        liveMonitoringEnabled: true,
        facialRecognitionEnabled: false,
        licensePlateRecognitionEnabled: false,
      );
      final evidence = HttpCctvEvidenceProbeService(client: client);
      final store = InMemoryEventStore();
      final ingestion = DeterministicIntelligenceIngestionService(store: store);

      final records = await bridge.fetchLatest(
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );
      expect(records, hasLength(1));

      final probe = await evidence.probeBatch(records);
      expect(probe.snapshot.verifiedCount, 2);
      expect(probe.snapshot.failureCount, 0);
      expect(probe.snapshot.cameras.single.cameraId, 'pilot_gate');
      expect(probe.snapshot.cameras.single.status, 'healthy');

      final result = ingestion.ingestBatch(records);
      expect(result.attempted, 1);
      expect(result.appended, 1);

      final intel = store.allEvents().whereType<IntelligenceReceived>().single;
      expect(intel.provider, 'frigate');
      expect(intel.cameraId, 'pilot_gate');
      expect(intel.zone, 'north_gate');
      expect(intel.objectLabel, 'person');
      expect(intel.snapshotUrl, contains('/evt-1001/snapshot.jpg'));
      expect(intel.clipUrl, contains('/evt-1001/clip.mp4'));

      final projection = OperationsHealthProjection.build(store.allEvents());
      expect(projection.totalIntelligenceReceived, 1);
      expect(projection.highRiskIntelligence, 1);
      expect(
        projection.liveSignals.single,
        contains('Intel frigate/evt-1001 risk'),
      );
    },
  );

  test(
    'phase 1 pilot flow recovers from transient outage without silent data loss',
    () async {
      final recoveredEventTime = DateTime.now().toUtc().subtract(
        const Duration(minutes: 2),
      );
      var eventPolls = 0;
      var snapshotHeads = 0;
      var clipHeads = 0;
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (url == 'https://edge.example.com/api/events') {
          eventPolls += 1;
          if (eventPolls == 1) {
            return http.Response('upstream unavailable', 503);
          }
          return http.Response('''
[
  {
    "id": "evt-recover-1",
    "camera": "pilot_gate",
    "label": "vehicle",
    "entered_zones": ["north_gate"],
    "top_score": 0.91,
    "start_time": "${recoveredEventTime.toIso8601String()}",
    "has_snapshot": true,
    "has_clip": true
  }
]
''', 200);
        }
        if (request.method == 'HEAD' && url.endsWith('/snapshot.jpg')) {
          snapshotHeads += 1;
          return http.Response('', snapshotHeads == 1 ? 503 : 200);
        }
        if (request.method == 'HEAD' && url.endsWith('/clip.mp4')) {
          clipHeads += 1;
          return http.Response('', 405);
        }
        if (request.method == 'GET' && url.endsWith('/clip.mp4')) {
          return http.Response('', 206);
        }
        return http.Response('', 404);
      });

      final bridge = HttpCctvBridgeService(
        provider: 'frigate',
        eventsUri: Uri.parse('https://edge.example.com/api/events'),
        client: client,
        liveMonitoringEnabled: true,
        facialRecognitionEnabled: false,
        licensePlateRecognitionEnabled: false,
      );
      final evidence = HttpCctvEvidenceProbeService(
        client: client,
        retryAttempts: 2,
        initialBackoff: Duration.zero,
      );
      final store = InMemoryEventStore();
      final ingestion = DeterministicIntelligenceIngestionService(store: store);

      await expectLater(
        bridge.fetchLatest(
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(store.allEvents(), isEmpty);

      final recoveredRecords = await bridge.fetchLatest(
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );
      expect(recoveredRecords, hasLength(1));

      final probe = await evidence.probeBatch(recoveredRecords);
      expect(probe.snapshot.failureCount, 0);
      expect(probe.snapshot.verifiedCount, 2);
      expect(probe.snapshot.lastAlert, isEmpty);
      expect(probe.snapshot.cameras.single.status, 'healthy');

      final recovered = ingestion.ingestBatch(recoveredRecords);
      expect(recovered.attempted, 1);
      expect(recovered.appended, 1);

      final replayRecords = await bridge.fetchLatest(
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );
      expect(replayRecords, hasLength(1));
      final replay = ingestion.ingestBatch(replayRecords);
      expect(replay.attempted, 1);
      expect(replay.appended, 0);

      final intel = store.allEvents().whereType<IntelligenceReceived>().single;
      expect(intel.externalId, 'evt-recover-1');
      expect(intel.objectLabel, 'vehicle');
      expect(intel.snapshotUrl, contains('/evt-recover-1/snapshot.jpg'));
      expect(intel.clipUrl, contains('/evt-recover-1/clip.mp4'));
      expect(eventPolls, 3);
      expect(snapshotHeads, 2);
      expect(clipHeads, 1);
    },
  );
}
