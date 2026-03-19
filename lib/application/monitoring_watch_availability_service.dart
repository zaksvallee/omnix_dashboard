import 'video_bridge_runtime.dart';

class MonitoringWatchAvailabilityService {
  const MonitoringWatchAvailabilityService();

  bool isMonitoringAvailable(VideoEvidenceProbeSnapshot snapshot) {
    if (snapshot.failureCount > 0) {
      return false;
    }
    if (snapshot.droppedCount > 0) {
      return false;
    }
    if (snapshot.cameras.any(
      (camera) => _cameraStatusIsLimited(camera.status),
    )) {
      return false;
    }
    if (snapshot.lastAlert.trim().isNotEmpty) {
      return false;
    }
    return true;
  }

  String availabilityDetail(VideoEvidenceProbeSnapshot snapshot) {
    final alert = snapshot.lastAlert.trim();
    if (alert.isNotEmpty) {
      return _sentenceCase(alert);
    }
    if (snapshot.failureCount > 0) {
      return snapshot.failureCount == 1
          ? 'Remote evidence verification is failing on one feed.'
          : 'Remote evidence verification is failing on multiple feeds.';
    }
    if (snapshot.droppedCount > 0) {
      return snapshot.droppedCount == 1
          ? 'The remote watch queue is dropping one item.'
          : 'The remote watch queue is dropping items.';
    }
    final staleCount = snapshot.cameras
        .where((camera) => camera.status.trim().toLowerCase() == 'stale')
        .length;
    if (staleCount > 0) {
      return staleCount == 1
          ? 'One remote camera feed is stale.'
          : '$staleCount remote camera feeds are stale.';
    }
    final degradedCount = snapshot.cameras
        .where((camera) => camera.status.trim().toLowerCase() == 'degraded')
        .length;
    if (degradedCount > 0) {
      return degradedCount == 1
          ? 'One remote camera feed is failing verification.'
          : '$degradedCount remote camera feeds are failing verification.';
    }
    return '';
  }

  bool _cameraStatusIsLimited(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'degraded' || normalized == 'stale';
  }

  String _sentenceCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final first = trimmed.substring(0, 1).toUpperCase();
    final rest = trimmed.length == 1 ? '' : trimmed.substring(1);
    return '$first$rest';
  }
}
