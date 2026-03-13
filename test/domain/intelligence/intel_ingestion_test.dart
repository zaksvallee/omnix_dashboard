import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/evidence/evidence_provenance.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/intelligence/intel_ingestion.dart';
import 'package:omnix_dashboard/domain/store/in_memory_event_store.dart';

void main() {
  test(
    'deterministic intelligence ingestion preserves CCTV media references',
    () {
      final store = InMemoryEventStore();
      final service = DeterministicIntelligenceIngestionService(store: store);

      final result = service.ingestBatch([
        NormalizedIntelRecord(
          provider: 'frigate',
          sourceType: 'hardware',
          externalId: 'evt-1',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          headline: 'FRIGATE INTRUSION',
          summary: 'CCTV person detected in north_gate',
          riskScore: 94,
          occurredAtUtc: DateTime.utc(2026, 3, 13, 8, 15, 0),
          snapshotUrl: 'https://edge.example.com/api/events/evt-1/snapshot.jpg',
          clipUrl: 'https://edge.example.com/api/events/evt-1/clip.mp4',
        ),
      ]);

      expect(result.attempted, 1);
      expect(result.appended, 1);
      expect(result.skipped, 0);
      expect(result.appendedEvents, hasLength(1));

      final ingested = store
          .allEvents()
          .whereType<IntelligenceReceived>()
          .single;
      expect(
        ingested.snapshotUrl,
        'https://edge.example.com/api/events/evt-1/snapshot.jpg',
      );
      expect(
        ingested.clipUrl,
        'https://edge.example.com/api/events/evt-1/clip.mp4',
      );
      expect(
        ingested.snapshotReferenceHash,
        evidenceLocatorHash(
          'https://edge.example.com/api/events/evt-1/snapshot.jpg',
        ),
      );
      expect(
        ingested.clipReferenceHash,
        evidenceLocatorHash(
          'https://edge.example.com/api/events/evt-1/clip.mp4',
        ),
      );
      expect(ingested.evidenceRecordHash, isNotEmpty);
    },
  );
}
