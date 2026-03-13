import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/video_bridge_health_formatter.dart';
import 'package:omnix_dashboard/application/video_bridge_runtime.dart';
import 'package:omnix_dashboard/domain/intelligence/intel_ingestion.dart';

void main() {
  const evidence = VideoEvidenceProbeSnapshot(
    queueDepth: 1,
    boundedQueueLimit: 12,
    droppedCount: 0,
    verifiedCount: 2,
    failureCount: 0,
    lastAlert: 'queue stable',
    cameras: [
      VideoCameraHealth(
        cameraId: 'front-gate',
        lastZone: 'north_gate',
        staleFrameAgeSeconds: 60,
        status: 'healthy',
      ),
    ],
  );

  test('bridge status formats shared video bridge summary', () {
    final value = VideoBridgeHealthFormatter.bridgeStatus(
      configured: true,
      provider: 'frigate',
      endpointLabel: 'edge.example.com',
      capabilitySummary: 'caps LIVE AI MONITORING',
      evidence: evidence,
      pilotEdge: true,
    );

    expect(value, contains('configured • pilot edge'));
    expect(value, contains('provider frigate'));
    expect(value, contains('edge edge.example.com'));
    expect(value, contains('caps LIVE AI MONITORING'));
    expect(value, contains('verified 2'));
  });

  test('pilot context formats provider, recent summary, and camera health', () {
    final value = VideoBridgeHealthFormatter.pilotContext(
      configured: true,
      provider: 'hikvision_dvr',
      recentSignalSummary: 'recent hardware intel 3 (6h) • intrusion 1',
      evidence: evidence,
    );

    expect(value, contains('provider hikvision_dvr'));
    expect(value, contains('recent hardware intel 3 (6h)'));
    expect(value, contains('front-gate:healthy'));
  });

  test('ingest detail uses latest record and evidence alert', () {
    final value = VideoBridgeHealthFormatter.ingestDetail(
      provider: 'generic_dvr',
      records: [
        NormalizedIntelRecord(
          provider: 'generic_dvr',
          sourceType: 'dvr',
          externalId: 'evt-1',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          headline: 'GENERIC_DVR MOTION',
          summary:
              'provider:generic_dvr | camera:GEN-CAM-7 | zone:parking_north',
          riskScore: 72,
          occurredAtUtc: DateTime.utc(2026, 3, 13, 10, 20),
        ),
      ],
      attempted: 1,
      appended: 1,
      evidence: evidence,
      compactDetail: (value, {maxLength = 84}) {
        final trimmed = value.trim();
        if (trimmed.length <= maxLength) {
          return trimmed;
        }
        return '${trimmed.substring(0, maxLength).trimRight()}...';
      },
    );

    expect(value, contains('1/1 appended'));
    expect(value, contains('generic_dvr'));
    expect(value, contains('camera:GEN-CAM-7'));
    expect(value, contains('queue stable'));
  });
}
