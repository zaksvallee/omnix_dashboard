enum GuardOpsEventType {
  shiftStart,
  shiftEnd,
  shiftVerificationImage,
  gpsHeartbeat,
  dispatchReceived,
  dispatchAcknowledged,
  statusChanged,
  checkpointScanned,
  patrolImageCaptured,
  panicTriggered,
  panicCleared,
  reactionIncidentAccepted,
  reactionOfficerArrived,
  reactionIncidentCleared,
  supervisorStatusOverride,
  supervisorCoachingAcknowledged,
  wearableHeartbeat,
  incidentReported,
  deviceHealth,
  syncStatus,
}

enum GuardMediaUploadStatus { queued, uploaded, failed }

class GuardOpsEvent {
  final String eventId;
  final String guardId;
  final String siteId;
  final String shiftId;
  final GuardOpsEventType eventType;
  final int sequence;
  final DateTime occurredAt;
  final DateTime? syncedAt;
  final String deviceId;
  final String appVersion;
  final Map<String, Object?> payload;
  final int retryCount;
  final String? failureReason;

  const GuardOpsEvent({
    required this.eventId,
    required this.guardId,
    required this.siteId,
    required this.shiftId,
    required this.eventType,
    required this.sequence,
    required this.occurredAt,
    this.syncedAt,
    required this.deviceId,
    required this.appVersion,
    required this.payload,
    this.retryCount = 0,
    this.failureReason,
  });

  bool get isPending => syncedAt == null;

  GuardOpsEvent copyWith({
    DateTime? syncedAt,
    int? retryCount,
    String? failureReason,
  }) {
    return GuardOpsEvent(
      eventId: eventId,
      guardId: guardId,
      siteId: siteId,
      shiftId: shiftId,
      eventType: eventType,
      sequence: sequence,
      occurredAt: occurredAt,
      syncedAt: syncedAt ?? this.syncedAt,
      deviceId: deviceId,
      appVersion: appVersion,
      payload: payload,
      retryCount: retryCount ?? this.retryCount,
      failureReason: failureReason,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'eventId': eventId,
      'guardId': guardId,
      'siteId': siteId,
      'shiftId': shiftId,
      'eventType': eventType.name,
      'sequence': sequence,
      'occurredAt': occurredAt.toUtc().toIso8601String(),
      'syncedAt': syncedAt?.toUtc().toIso8601String(),
      'deviceId': deviceId,
      'appVersion': appVersion,
      'payload': payload,
      'retryCount': retryCount,
      'failureReason': failureReason,
    };
  }

  factory GuardOpsEvent.fromJson(Map<String, Object?> json) {
    final payloadRaw = json['payload'];
    return GuardOpsEvent(
      eventId: (json['eventId'] as String? ?? '').trim(),
      guardId: (json['guardId'] as String? ?? '').trim(),
      siteId: (json['siteId'] as String? ?? '').trim(),
      shiftId: (json['shiftId'] as String? ?? '').trim(),
      eventType: GuardOpsEventType.values.firstWhere(
        (value) => value.name == (json['eventType'] as String? ?? '').trim(),
        orElse: () => GuardOpsEventType.syncStatus,
      ),
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      occurredAt:
          DateTime.tryParse(
            (json['occurredAt'] as String? ?? '').trim(),
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      syncedAt: DateTime.tryParse(
        (json['syncedAt'] as String? ?? '').trim(),
      )?.toUtc(),
      deviceId: (json['deviceId'] as String? ?? '').trim(),
      appVersion: (json['appVersion'] as String? ?? '').trim(),
      payload: payloadRaw is Map
          ? payloadRaw.map((key, value) => MapEntry(key.toString(), value))
          : const {},
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      failureReason: (json['failureReason'] as String?)?.trim(),
    );
  }
}

class GuardOpsMediaUpload {
  final String mediaId;
  final String eventId;
  final String guardId;
  final String siteId;
  final String shiftId;
  final String bucket;
  final String path;
  final String localPath;
  final DateTime capturedAt;
  final DateTime? uploadedAt;
  final String? sha256;
  final GuardMediaUploadStatus status;
  final int retryCount;
  final String? failureReason;

  const GuardOpsMediaUpload({
    required this.mediaId,
    required this.eventId,
    required this.guardId,
    required this.siteId,
    required this.shiftId,
    required this.bucket,
    required this.path,
    required this.localPath,
    required this.capturedAt,
    this.uploadedAt,
    this.sha256,
    this.status = GuardMediaUploadStatus.queued,
    this.retryCount = 0,
    this.failureReason,
  });

  bool get isPending => status == GuardMediaUploadStatus.queued;

  GuardOpsMediaUpload copyWith({
    DateTime? uploadedAt,
    GuardMediaUploadStatus? status,
    int? retryCount,
    String? failureReason,
  }) {
    return GuardOpsMediaUpload(
      mediaId: mediaId,
      eventId: eventId,
      guardId: guardId,
      siteId: siteId,
      shiftId: shiftId,
      bucket: bucket,
      path: path,
      localPath: localPath,
      capturedAt: capturedAt,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      sha256: sha256,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      failureReason: failureReason,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'mediaId': mediaId,
      'eventId': eventId,
      'guardId': guardId,
      'siteId': siteId,
      'shiftId': shiftId,
      'bucket': bucket,
      'path': path,
      'localPath': localPath,
      'capturedAt': capturedAt.toUtc().toIso8601String(),
      'uploadedAt': uploadedAt?.toUtc().toIso8601String(),
      'sha256': sha256,
      'status': status.name,
      'retryCount': retryCount,
      'failureReason': failureReason,
    };
  }

  factory GuardOpsMediaUpload.fromJson(Map<String, Object?> json) {
    return GuardOpsMediaUpload(
      mediaId: (json['mediaId'] as String? ?? '').trim(),
      eventId: (json['eventId'] as String? ?? '').trim(),
      guardId: (json['guardId'] as String? ?? '').trim(),
      siteId: (json['siteId'] as String? ?? '').trim(),
      shiftId: (json['shiftId'] as String? ?? '').trim(),
      bucket: (json['bucket'] as String? ?? '').trim(),
      path: (json['path'] as String? ?? '').trim(),
      localPath: (json['localPath'] as String? ?? '').trim(),
      capturedAt:
          DateTime.tryParse(
            (json['capturedAt'] as String? ?? '').trim(),
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      uploadedAt: DateTime.tryParse(
        (json['uploadedAt'] as String? ?? '').trim(),
      )?.toUtc(),
      sha256: (json['sha256'] as String?)?.trim(),
      status: GuardMediaUploadStatus.values.firstWhere(
        (value) => value.name == (json['status'] as String? ?? '').trim(),
        orElse: () => GuardMediaUploadStatus.queued,
      ),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      failureReason: (json['failureReason'] as String?)?.trim(),
    );
  }
}
