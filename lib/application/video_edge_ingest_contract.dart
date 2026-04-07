import '../domain/intelligence/intel_ingestion.dart';

enum VideoEvidenceAccessMode { privateFetch, directUrl, unavailable }

class VideoAnalyticsCapabilities {
  final bool liveMonitoringEnabled;
  final bool facialRecognitionEnabled;
  final bool licensePlateRecognitionEnabled;

  const VideoAnalyticsCapabilities({
    required this.liveMonitoringEnabled,
    required this.facialRecognitionEnabled,
    required this.licensePlateRecognitionEnabled,
  });
}

class VideoEvidenceReference {
  final String? snapshotUrl;
  final String? clipUrl;
  final bool snapshotExpected;
  final bool clipExpected;
  final VideoEvidenceAccessMode accessMode;

  const VideoEvidenceReference({
    this.snapshotUrl,
    this.clipUrl,
    this.snapshotExpected = false,
    this.clipExpected = false,
    this.accessMode = VideoEvidenceAccessMode.unavailable,
  });

  String snapshotStatus() {
    if (!snapshotExpected) {
      return 'not_expected';
    }
    if ((snapshotUrl ?? '').isEmpty) {
      return 'missing';
    }
    return switch (accessMode) {
      VideoEvidenceAccessMode.privateFetch => 'private-fetch',
      VideoEvidenceAccessMode.directUrl => 'available',
      VideoEvidenceAccessMode.unavailable => 'missing',
    };
  }

  String clipStatus() {
    if (!clipExpected) {
      return 'not_expected';
    }
    if ((clipUrl ?? '').isEmpty) {
      return 'missing';
    }
    return switch (accessMode) {
      VideoEvidenceAccessMode.privateFetch => 'private-fetch',
      VideoEvidenceAccessMode.directUrl => 'available',
      VideoEvidenceAccessMode.unavailable => 'missing',
    };
  }
}

class VideoEdgeEventContract {
  final String provider;
  final String sourceType;
  final String externalId;
  final String clientId;
  final String regionId;
  final String siteId;
  final String? cameraId;
  final String? channelId;
  final String? zone;
  final String? objectLabel;
  final double? objectConfidence;
  final String? trackId;
  final String? faceMatchId;
  final double? faceConfidence;
  final String? plateNumber;
  final double? plateConfidence;
  final String headline;
  final int riskScore;
  final DateTime occurredAtUtc;
  final String? summaryOverride;
  final VideoAnalyticsCapabilities capabilities;
  final VideoEvidenceReference evidence;
  final Map<String, Object?> attributes;

  const VideoEdgeEventContract({
    required this.provider,
    required this.sourceType,
    required this.externalId,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    this.cameraId,
    this.channelId,
    this.zone,
    this.objectLabel,
    this.objectConfidence,
    this.trackId,
    this.faceMatchId,
    this.faceConfidence,
    this.plateNumber,
    this.plateConfidence,
    required this.headline,
    required this.riskScore,
    required this.occurredAtUtc,
    this.summaryOverride,
    required this.capabilities,
    required this.evidence,
    this.attributes = const {},
  });

  String buildSummary() {
    if (summaryOverride != null && summaryOverride!.trim().isNotEmpty) {
      return summaryOverride!.trim();
    }
    final parts = <String>[
      'provider:$provider',
      if ((cameraId ?? '').isNotEmpty) 'camera:$cameraId',
      if ((channelId ?? '').isNotEmpty) 'channel:$channelId',
      if ((zone ?? '').isNotEmpty) 'zone:$zone',
      if ((objectLabel ?? '').isNotEmpty)
        'label:$objectLabel${_formatPercent(objectConfidence)}',
      if (capabilities.facialRecognitionEnabled &&
          (faceMatchId ?? '').isNotEmpty)
        'FR:$faceMatchId${_formatPercent(faceConfidence)}',
      if (capabilities.licensePlateRecognitionEnabled &&
          (plateNumber ?? '').isNotEmpty)
        'LPR:$plateNumber${_formatPercent(plateConfidence)}',
      'snapshot:${evidence.snapshotStatus()}',
      'clip:${evidence.clipStatus()}',
    ];
    return parts.join(' | ');
  }

  NormalizedIntelRecord toNormalizedIntelRecord() {
    return NormalizedIntelRecord(
      provider: provider,
      sourceType: sourceType,
      externalId: externalId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      cameraId: cameraId ?? channelId,
      zone: zone,
      objectLabel: objectLabel,
      objectConfidence: objectConfidence,
      trackId: trackId,
      faceMatchId: faceMatchId,
      faceConfidence: faceConfidence,
      plateNumber: plateNumber,
      plateConfidence: plateConfidence,
      headline: headline,
      summary: buildSummary(),
      riskScore: riskScore,
      occurredAtUtc: occurredAtUtc.toUtc(),
      snapshotUrl: evidence.snapshotUrl,
      clipUrl: evidence.clipUrl,
    );
  }

  String _formatPercent(double? value) {
    if (value == null) {
      return '';
    }
    return ' ${value.toStringAsFixed(1)}%';
  }
}
