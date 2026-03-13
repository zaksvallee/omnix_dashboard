import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/video_edge_ingest_contract.dart';

void main() {
  test('video edge contract preserves FR/LPR and private evidence fetch', () {
    final contract = VideoEdgeEventContract(
      provider: 'hikvision_dvr',
      sourceType: 'dvr',
      externalId: 'DVR-EVT-1001',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
      cameraId: 'DVR-001',
      channelId: '3',
      zone: 'loading_bay',
      objectLabel: 'line_crossing',
      objectConfidence: 94.2,
      faceMatchId: 'PERSON-44',
      faceConfidence: 91.2,
      plateNumber: 'CA123456',
      plateConfidence: 96.4,
      headline: 'HIKVISION_DVR LINE_CROSSING',
      riskScore: 92,
      occurredAtUtc: DateTime.utc(2026, 3, 13, 10, 15, 22),
      capabilities: VideoAnalyticsCapabilities(
        liveMonitoringEnabled: true,
        facialRecognitionEnabled: true,
        licensePlateRecognitionEnabled: true,
      ),
      evidence: VideoEvidenceReference(
        snapshotUrl:
            'https://dvr.example.com/ISAPI/ContentMgmt/events/DVR-EVT-1001/snapshot',
        clipUrl:
            'https://dvr.example.com/ISAPI/ContentMgmt/events/DVR-EVT-1001/clip',
        snapshotExpected: true,
        clipExpected: true,
        accessMode: VideoEvidenceAccessMode.privateFetch,
      ),
    );

    final summary = contract.buildSummary();
    final record = contract.toNormalizedIntelRecord();

    expect(summary, contains('provider:hikvision_dvr'));
    expect(summary, contains('camera:DVR-001'));
    expect(summary, contains('channel:3'));
    expect(summary, contains('zone:loading_bay'));
    expect(summary, contains('FR:PERSON-44 91.2%'));
    expect(summary, contains('LPR:CA123456 96.4%'));
    expect(summary, contains('snapshot:private-fetch'));
    expect(summary, contains('clip:private-fetch'));
    expect(record.provider, 'hikvision_dvr');
    expect(record.sourceType, 'dvr');
    expect(record.externalId, 'DVR-EVT-1001');
    expect(record.cameraId, 'DVR-001');
    expect(record.summary, summary);
    expect(record.snapshotUrl, contains('/snapshot'));
    expect(record.clipUrl, contains('/clip'));
  });
}
