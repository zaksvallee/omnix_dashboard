import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_watch_availability_service.dart';
import 'package:omnix_dashboard/application/video_bridge_runtime.dart';

void main() {
  const service = MonitoringWatchAvailabilityService();

  group('MonitoringWatchAvailabilityService', () {
    test('stays available when probe snapshot is clean', () {
      const snapshot = VideoEvidenceProbeSnapshot(
        queueDepth: 2,
        boundedQueueLimit: 12,
        verifiedCount: 2,
        cameras: [VideoCameraHealth(cameraId: 'camera-1', status: 'healthy')],
      );

      expect(service.isMonitoringAvailable(snapshot), isTrue);
    });

    test('marks monitoring limited when probe failures exist', () {
      const snapshot = VideoEvidenceProbeSnapshot(failureCount: 1);

      expect(service.isMonitoringAvailable(snapshot), isFalse);
    });

    test('marks monitoring limited when queue drops exist', () {
      const snapshot = VideoEvidenceProbeSnapshot(droppedCount: 2);

      expect(service.isMonitoringAvailable(snapshot), isFalse);
    });

    test('marks monitoring limited when a camera is stale or degraded', () {
      const staleSnapshot = VideoEvidenceProbeSnapshot(
        cameras: [VideoCameraHealth(cameraId: 'camera-1', status: 'stale')],
      );
      const degradedSnapshot = VideoEvidenceProbeSnapshot(
        cameras: [VideoCameraHealth(cameraId: 'camera-1', status: 'degraded')],
      );

      expect(service.isMonitoringAvailable(staleSnapshot), isFalse);
      expect(service.isMonitoringAvailable(degradedSnapshot), isFalse);
    });

    test('marks monitoring limited when probe alerts exist', () {
      const snapshot = VideoEvidenceProbeSnapshot(
        lastAlert: 'scope fetch failed: timeout',
      );

      expect(service.isMonitoringAvailable(snapshot), isFalse);
      expect(
        service.availabilityDetail(snapshot),
        'Scope fetch failed: timeout',
      );
    });

    test('builds readable detail for stale and degraded camera states', () {
      const staleSnapshot = VideoEvidenceProbeSnapshot(
        cameras: [VideoCameraHealth(cameraId: 'camera-1', status: 'stale')],
      );
      const degradedSnapshot = VideoEvidenceProbeSnapshot(
        cameras: [
          VideoCameraHealth(cameraId: 'camera-1', status: 'degraded'),
          VideoCameraHealth(cameraId: 'camera-2', status: 'degraded'),
        ],
      );

      expect(
        service.availabilityDetail(staleSnapshot),
        'One remote camera feed is stale.',
      );
      expect(
        service.availabilityDetail(degradedSnapshot),
        '2 remote camera feeds are failing verification.',
      );
    });
  });
}
