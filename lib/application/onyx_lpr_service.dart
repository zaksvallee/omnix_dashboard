import 'package:omnix_dashboard/application/site_awareness/onyx_live_snapshot_yolo_service.dart';

class OnyxLprResult {
  final String? plateNumber;
  final double? plateConfidence;
  final String? summary;
  final String? error;

  const OnyxLprResult({
    required this.plateNumber,
    required this.plateConfidence,
    required this.summary,
    required this.error,
  });

  bool get hasPlate => (plateNumber ?? '').trim().isNotEmpty;
}

class OnyxLprService {
  final OnyxLiveSnapshotYoloService detector;

  const OnyxLprService({required this.detector});

  bool get isConfigured => detector.isConfigured;

  Future<OnyxLprResult?> detectPlate({
    required String recordKey,
    required String provider,
    required String sourceType,
    required String clientId,
    required String siteId,
    required String cameraId,
    required String zone,
    required DateTime occurredAtUtc,
    required List<int> imageBytes,
  }) async {
    final result = await detector.detectSnapshot(
      recordKey: recordKey,
      provider: provider,
      sourceType: sourceType,
      clientId: clientId,
      siteId: siteId,
      cameraId: cameraId,
      zone: zone,
      occurredAtUtc: occurredAtUtc,
      imageBytes: imageBytes,
      headline: 'Vehicle LPR snapshot',
      summary: 'Live vehicle detection snapshot',
      objectLabel: 'vehicle',
    );
    if (result == null) {
      return null;
    }
    return OnyxLprResult(
      plateNumber: result.plateNumber,
      plateConfidence: result.plateConfidence,
      summary: result.summary,
      error: result.error,
    );
  }
}
