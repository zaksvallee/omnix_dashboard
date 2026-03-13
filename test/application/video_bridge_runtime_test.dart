import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/cctv_evidence_probe_service.dart';
import 'package:omnix_dashboard/application/video_bridge_runtime.dart';

void main() {
  test('video evidence snapshot round-trips persisted CCTV health shape', () {
    const source = CctvEvidenceProbeSnapshot(
      queueDepth: 2,
      boundedQueueLimit: 12,
      droppedCount: 1,
      verifiedCount: 4,
      failureCount: 0,
      lastAlert: 'queue stable',
      cameras: [
        CctvCameraHealth(
          cameraId: 'front-gate',
          eventCount: 3,
          snapshotRefs: 3,
          clipRefs: 2,
          snapshotVerified: 3,
          clipVerified: 2,
          probeFailures: 0,
          lastZone: 'north_gate',
          lastObjectLabel: 'person',
          staleFrameAgeSeconds: 45,
          status: 'healthy',
        ),
      ],
    );

    final snapshot = VideoEvidenceProbeSnapshot.fromCctv(source);
    final restored = VideoEvidenceProbeSnapshot.fromJson(snapshot.toJson());

    expect(restored.queueDepth, 2);
    expect(restored.boundedQueueLimit, 12);
    expect(restored.verifiedCount, 4);
    expect(restored.cameras.single.cameraId, 'front-gate');
    expect(restored.cameras.single.lastZone, 'north_gate');
    expect(restored.summaryLabel(), contains('verified 4'));
    expect(restored.cameraSummaryLabel(), contains('front-gate:healthy'));
  });
}
