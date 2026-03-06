import 'operational_tiers.dart';

enum GuardDutyStatus { available, enRoute, onSite, clear, offline, panic }

enum GuardMediaType { photo, video }

enum GuardSyncOperationType {
  statusUpdate,
  locationHeartbeat,
  checkpointScan,
  incidentCapture,
  panicSignal,
}

enum GuardSyncOperationStatus { queued, synced, failed }

class GuardAssignment {
  final String assignmentId;
  final String dispatchId;
  final String clientId;
  final String siteId;
  final String guardId;
  final DateTime issuedAt;
  final DateTime? acknowledgedAt;
  final GuardDutyStatus status;

  const GuardAssignment({
    required this.assignmentId,
    required this.dispatchId,
    required this.clientId,
    required this.siteId,
    required this.guardId,
    required this.issuedAt,
    this.acknowledgedAt,
    this.status = GuardDutyStatus.available,
  });

  GuardAssignment copyWith({
    DateTime? acknowledgedAt,
    GuardDutyStatus? status,
  }) {
    return GuardAssignment(
      assignmentId: assignmentId,
      dispatchId: dispatchId,
      clientId: clientId,
      siteId: siteId,
      guardId: guardId,
      issuedAt: issuedAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      status: status ?? this.status,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'assignmentId': assignmentId,
      'dispatchId': dispatchId,
      'clientId': clientId,
      'siteId': siteId,
      'guardId': guardId,
      'issuedAt': issuedAt.toUtc().toIso8601String(),
      'acknowledgedAt': acknowledgedAt?.toUtc().toIso8601String(),
      'status': status.name,
    };
  }

  factory GuardAssignment.fromJson(Map<String, Object?> json) {
    return GuardAssignment(
      assignmentId: (json['assignmentId'] as String? ?? '').trim(),
      dispatchId: (json['dispatchId'] as String? ?? '').trim(),
      clientId: (json['clientId'] as String? ?? '').trim(),
      siteId: (json['siteId'] as String? ?? '').trim(),
      guardId: (json['guardId'] as String? ?? '').trim(),
      issuedAt:
          DateTime.tryParse(
            (json['issuedAt'] as String? ?? '').trim(),
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      acknowledgedAt: DateTime.tryParse(
        (json['acknowledgedAt'] as String? ?? '').trim(),
      )?.toUtc(),
      status: GuardDutyStatus.values.firstWhere(
        (value) => value.name == (json['status'] as String? ?? '').trim(),
        orElse: () => GuardDutyStatus.available,
      ),
    );
  }
}

class GuardLocationHeartbeat {
  final String guardId;
  final String clientId;
  final String siteId;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime recordedAt;

  const GuardLocationHeartbeat({
    required this.guardId,
    required this.clientId,
    required this.siteId,
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    required this.recordedAt,
  });
}

class GuardCheckpointScan {
  final String scanId;
  final String guardId;
  final String clientId;
  final String siteId;
  final String checkpointId;
  final String nfcTagId;
  final double? latitude;
  final double? longitude;
  final DateTime scannedAt;

  const GuardCheckpointScan({
    required this.scanId,
    required this.guardId,
    required this.clientId,
    required this.siteId,
    required this.checkpointId,
    required this.nfcTagId,
    this.latitude,
    this.longitude,
    required this.scannedAt,
  });
}

class GuardIncidentCapture {
  final String captureId;
  final String guardId;
  final String clientId;
  final String siteId;
  final GuardMediaType mediaType;
  final String localReference;
  final String? dispatchId;
  final DateTime capturedAt;

  const GuardIncidentCapture({
    required this.captureId,
    required this.guardId,
    required this.clientId,
    required this.siteId,
    required this.mediaType,
    required this.localReference,
    this.dispatchId,
    required this.capturedAt,
  });
}

class GuardPanicSignal {
  final String signalId;
  final String guardId;
  final String clientId;
  final String siteId;
  final double? latitude;
  final double? longitude;
  final DateTime triggeredAt;

  const GuardPanicSignal({
    required this.signalId,
    required this.guardId,
    required this.clientId,
    required this.siteId,
    this.latitude,
    this.longitude,
    required this.triggeredAt,
  });
}

class GuardSyncOperation {
  final String operationId;
  final GuardSyncOperationType type;
  final GuardSyncOperationStatus status;
  final String? failureReason;
  final int retryCount;
  final DateTime createdAt;
  final Map<String, Object?> payload;

  const GuardSyncOperation({
    required this.operationId,
    required this.type,
    this.status = GuardSyncOperationStatus.queued,
    this.failureReason,
    this.retryCount = 0,
    required this.createdAt,
    required this.payload,
  });

  Map<String, Object?> toJson() {
    return {
      'operationId': operationId,
      'type': type.name,
      'status': status.name,
      'failureReason': failureReason,
      'retryCount': retryCount,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'payload': payload,
    };
  }

  factory GuardSyncOperation.fromJson(Map<String, Object?> json) {
    final payloadRaw = json['payload'];
    return GuardSyncOperation(
      operationId: (json['operationId'] as String? ?? '').trim(),
      type: GuardSyncOperationType.values.firstWhere(
        (value) => value.name == (json['type'] as String? ?? '').trim(),
        orElse: () => GuardSyncOperationType.statusUpdate,
      ),
      status: GuardSyncOperationStatus.values.firstWhere(
        (value) => value.name == (json['status'] as String? ?? '').trim(),
        orElse: () => GuardSyncOperationStatus.queued,
      ),
      failureReason: (json['failureReason'] as String?)?.trim(),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(
            (json['createdAt'] as String? ?? '').trim(),
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      payload: payloadRaw is Map
          ? payloadRaw.map((key, value) => MapEntry(key.toString(), value))
          : const {},
    );
  }

  GuardSyncOperation copyWith({
    GuardSyncOperationStatus? status,
    String? failureReason,
    int? retryCount,
  }) {
    return GuardSyncOperation(
      operationId: operationId,
      type: type,
      status: status ?? this.status,
      failureReason: failureReason,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt,
      payload: payload,
    );
  }
}

abstract class GuardMobileSyncQueue {
  Future<void> enqueue(GuardSyncOperation operation);
  Future<List<GuardSyncOperation>> peekBatch({int limit = 50});
  Future<void> markSynced(List<String> operationIds);
}

class InMemoryGuardMobileSyncQueue implements GuardMobileSyncQueue {
  final List<GuardSyncOperation> _operations = <GuardSyncOperation>[];

  @override
  Future<void> enqueue(GuardSyncOperation operation) async {
    _operations.add(operation);
  }

  @override
  Future<List<GuardSyncOperation>> peekBatch({int limit = 50}) async {
    return _operations.take(limit).toList(growable: false);
  }

  @override
  Future<void> markSynced(List<String> operationIds) async {
    _operations.removeWhere((op) => operationIds.contains(op.operationId));
  }
}

abstract class GuardSyncOperationStore {
  Future<List<GuardSyncOperation>> readQueuedOperations();
  Future<void> saveQueuedOperations(List<GuardSyncOperation> operations);
  Future<void> markOperationsSynced(List<String> operationIds);
}

class RepositoryBackedGuardMobileSyncQueue implements GuardMobileSyncQueue {
  final GuardSyncOperationStore store;

  const RepositoryBackedGuardMobileSyncQueue(this.store);

  @override
  Future<void> enqueue(GuardSyncOperation operation) async {
    final existing = await store.readQueuedOperations();
    final updated = [...existing, operation];
    await store.saveQueuedOperations(updated);
  }

  @override
  Future<List<GuardSyncOperation>> peekBatch({int limit = 50}) async {
    final existing = await store.readQueuedOperations();
    return existing.take(limit).toList(growable: false);
  }

  @override
  Future<void> markSynced(List<String> operationIds) async {
    await store.markOperationsSynced(operationIds);
  }
}

class GuardMobileOpsService {
  final GuardTierProfile tierProfile;
  final GuardMobileSyncQueue syncQueue;
  final Map<String, Object?> Function()? operationContextBuilder;

  const GuardMobileOpsService({
    required this.tierProfile,
    required this.syncQueue,
    this.operationContextBuilder,
  });

  Future<GuardAssignment> acknowledgeAssignment(
    GuardAssignment assignment, {
    required DateTime acknowledgedAt,
  }) async {
    final updated = assignment.copyWith(
      acknowledgedAt: acknowledgedAt,
      status: GuardDutyStatus.enRoute,
    );
    await _enqueueStatusUpdate(
      updated,
      GuardDutyStatus.enRoute,
      acknowledgedAt,
    );
    return updated;
  }

  Future<void> updateStatus({
    required GuardAssignment assignment,
    required GuardDutyStatus status,
    required DateTime occurredAt,
  }) async {
    await _enqueueStatusUpdate(assignment, status, occurredAt);
  }

  Future<void> recordLocationHeartbeat(GuardLocationHeartbeat heartbeat) async {
    await syncQueue.enqueue(
      GuardSyncOperation(
        operationId:
            'loc:${heartbeat.guardId}:${heartbeat.recordedAt.toIso8601String()}',
        type: GuardSyncOperationType.locationHeartbeat,
        createdAt: heartbeat.recordedAt,
        payload: _withOperationContext({
          'guard_id': heartbeat.guardId,
          'client_id': heartbeat.clientId,
          'site_id': heartbeat.siteId,
          'latitude': heartbeat.latitude,
          'longitude': heartbeat.longitude,
          'accuracy_meters': heartbeat.accuracyMeters,
          'recorded_at': heartbeat.recordedAt.toIso8601String(),
        }),
      ),
    );
  }

  Future<void> recordCheckpointScan(GuardCheckpointScan scan) async {
    if (!tierProfile.nfcCheckpointingMandatory) {
      throw StateError(
        'NFC checkpoint scans are disabled for ${tierProfile.label}.',
      );
    }
    await syncQueue.enqueue(
      GuardSyncOperation(
        operationId: 'scan:${scan.scanId}',
        type: GuardSyncOperationType.checkpointScan,
        createdAt: scan.scannedAt,
        payload: _withOperationContext({
          'scan_id': scan.scanId,
          'guard_id': scan.guardId,
          'client_id': scan.clientId,
          'site_id': scan.siteId,
          'checkpoint_id': scan.checkpointId,
          'nfc_tag_id': scan.nfcTagId,
          'latitude': scan.latitude,
          'longitude': scan.longitude,
          'scanned_at': scan.scannedAt.toIso8601String(),
        }),
      ),
    );
  }

  Future<void> captureIncidentMedia(GuardIncidentCapture capture) async {
    if (capture.mediaType == GuardMediaType.video &&
        !tierProfile.bodyCameraOrEventVideoEnabled) {
      throw StateError('Video capture is disabled for ${tierProfile.label}.');
    }
    await syncQueue.enqueue(
      GuardSyncOperation(
        operationId: 'media:${capture.captureId}',
        type: GuardSyncOperationType.incidentCapture,
        createdAt: capture.capturedAt,
        payload: _withOperationContext({
          'capture_id': capture.captureId,
          'guard_id': capture.guardId,
          'client_id': capture.clientId,
          'site_id': capture.siteId,
          'media_type': capture.mediaType.name,
          'local_reference': capture.localReference,
          'dispatch_id': capture.dispatchId,
          'captured_at': capture.capturedAt.toIso8601String(),
        }),
      ),
    );
  }

  Future<void> triggerPanic(GuardPanicSignal signal) async {
    await syncQueue.enqueue(
      GuardSyncOperation(
        operationId: 'panic:${signal.signalId}',
        type: GuardSyncOperationType.panicSignal,
        createdAt: signal.triggeredAt,
        payload: _withOperationContext({
          'signal_id': signal.signalId,
          'guard_id': signal.guardId,
          'client_id': signal.clientId,
          'site_id': signal.siteId,
          'latitude': signal.latitude,
          'longitude': signal.longitude,
          'triggered_at': signal.triggeredAt.toIso8601String(),
        }),
      ),
    );
  }

  Future<void> _enqueueStatusUpdate(
    GuardAssignment assignment,
    GuardDutyStatus status,
    DateTime occurredAt,
  ) async {
    await syncQueue.enqueue(
      GuardSyncOperation(
        operationId:
            'status:${assignment.assignmentId}:${status.name}:${occurredAt.toIso8601String()}',
        type: GuardSyncOperationType.statusUpdate,
        createdAt: occurredAt,
        payload: _withOperationContext({
          'assignment_id': assignment.assignmentId,
          'dispatch_id': assignment.dispatchId,
          'guard_id': assignment.guardId,
          'client_id': assignment.clientId,
          'site_id': assignment.siteId,
          'status': status.name,
          'occurred_at': occurredAt.toIso8601String(),
        }),
      ),
    );
  }

  Map<String, Object?> _withOperationContext(Map<String, Object?> payload) {
    final context = operationContextBuilder?.call();
    if (context == null || context.isEmpty) {
      return payload;
    }
    return <String, Object?>{...payload, 'onyx_runtime_context': context};
  }
}
