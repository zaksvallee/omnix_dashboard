import '../domain/intelligence/intel_ingestion.dart';
import 'video_bridge_runtime.dart';

typedef VideoBridgeCompactDetail =
    String Function(String value, {int maxLength});

class VideoBridgeHealthFormatter {
  const VideoBridgeHealthFormatter._();

  static String bridgeStatus({
    required bool configured,
    required String provider,
    required String endpointLabel,
    required String capabilitySummary,
    required VideoEvidenceProbeSnapshot evidence,
    bool pilotEdge = false,
  }) {
    if (!configured) {
      return 'disabled • configure ONYX_CCTV_PROVIDER and ONYX_CCTV_EVENTS_URL.';
    }
    final providerLabel = provider.trim().isEmpty ? 'video' : provider.trim();
    final endpoint = endpointLabel.trim();
    final edgeLabel = endpoint.isEmpty ? '' : ' • edge $endpoint';
    final pilotLabel = pilotEdge ? 'configured • pilot edge' : 'configured';
    final evidenceLabel = evidenceSummary(evidence);
    return '$pilotLabel • provider $providerLabel$edgeLabel • $capabilitySummary${evidenceLabel.isEmpty ? '' : ' • $evidenceLabel'}';
  }

  static String pilotContext({
    required bool configured,
    required String provider,
    required String recentSignalSummary,
    required VideoEvidenceProbeSnapshot evidence,
  }) {
    if (!configured) {
      return '';
    }
    final providerLabel = provider.trim().isEmpty ? 'video' : provider.trim();
    final cameraHealth = cameraHealthSummary(evidence);
    return 'provider $providerLabel • $recentSignalSummary${cameraHealth.isEmpty ? '' : ' • $cameraHealth'}';
  }

  static String ingestDetail({
    required String provider,
    required List<NormalizedIntelRecord> records,
    required int attempted,
    required int appended,
    required VideoEvidenceProbeSnapshot evidence,
    required VideoBridgeCompactDetail compactDetail,
  }) {
    final providerLabel = provider.trim().isEmpty ? 'video' : provider.trim();
    final latest = records.isEmpty
        ? null
        : records.reduce(
            (current, next) => next.occurredAtUtc.isAfter(current.occurredAtUtc)
                ? next
                : current,
          );
    final latestSummary = latest == null
        ? 'no events'
        : compactDetail(latest.summary);
    final evidenceLabel = evidence.lastAlert.trim().isEmpty
        ? 'evidence ok ${evidence.verifiedCount}'
        : compactDetail(evidence.lastAlert.trim(), maxLength: 32);
    return '$appended/$attempted appended • $providerLabel • $latestSummary • $evidenceLabel';
  }

  static String evidenceSummary(VideoEvidenceProbeSnapshot evidence) {
    if (evidence.boundedQueueLimit <= 0 && evidence.lastRunAtUtc == null) {
      return '';
    }
    return evidence.summaryLabel();
  }

  static String cameraHealthSummary(VideoEvidenceProbeSnapshot evidence) {
    if (evidence.cameras.isEmpty) {
      return '';
    }
    return evidence.cameraSummaryLabel();
  }
}
