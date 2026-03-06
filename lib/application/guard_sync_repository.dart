import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/guard/guard_mobile_ops.dart';
import 'dispatch_persistence_service.dart';

abstract class GuardSyncRepository implements GuardSyncOperationStore {
  Future<List<GuardAssignment>> readAssignments();
  Future<void> saveAssignments(List<GuardAssignment> assignments);
  Future<List<GuardSyncOperation>> readOperations({
    Set<GuardSyncOperationStatus> statuses = const {
      GuardSyncOperationStatus.queued,
    },
    int limit = 50,
    String? facadeMode,
    String? facadeId,
  });
  Future<int> retryFailedOperations(List<String> operationIds);
}

class SharedPrefsGuardSyncRepository implements GuardSyncRepository {
  final DispatchPersistenceService persistence;

  const SharedPrefsGuardSyncRepository(this.persistence);

  @override
  Future<List<GuardAssignment>> readAssignments() {
    return persistence.readGuardAssignments();
  }

  @override
  Future<void> saveAssignments(List<GuardAssignment> assignments) {
    return persistence.saveGuardAssignments(assignments);
  }

  @override
  Future<List<GuardSyncOperation>> readQueuedOperations() {
    return persistence.readGuardSyncOperations();
  }

  @override
  Future<List<GuardSyncOperation>> readOperations({
    Set<GuardSyncOperationStatus> statuses = const {
      GuardSyncOperationStatus.queued,
    },
    int limit = 50,
    String? facadeMode,
    String? facadeId,
  }) async {
    final operations = await persistence.readGuardSyncOperations();
    final modeFilter = _normalizedFacadeMode(facadeMode);
    final idFilter = facadeId?.trim();
    final filtered = operations
        .where((operation) {
          if (!statuses.contains(operation.status)) return false;
          if (modeFilter != null &&
              _operationFacadeMode(operation) != modeFilter) {
            return false;
          }
          if (idFilter != null &&
              idFilter.isNotEmpty &&
              _operationFacadeId(operation) != idFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
    filtered.sort((a, b) {
      final createdCmp = b.createdAt.compareTo(a.createdAt);
      if (createdCmp != 0) return createdCmp;
      return a.operationId.compareTo(b.operationId);
    });
    if (filtered.length <= limit) {
      return filtered;
    }
    return filtered.sublist(0, limit);
  }

  @override
  Future<void> saveQueuedOperations(List<GuardSyncOperation> operations) {
    return persistence.saveGuardSyncOperations(operations);
  }

  @override
  Future<void> markOperationsSynced(List<String> operationIds) async {
    if (operationIds.isEmpty) return;
    final existing = await persistence.readGuardSyncOperations();
    final updated = existing
        .where((op) => !operationIds.contains(op.operationId))
        .toList(growable: false);
    await persistence.saveGuardSyncOperations(updated);
  }

  @override
  Future<int> retryFailedOperations(List<String> operationIds) async {
    if (operationIds.isEmpty) return 0;
    final existing = await persistence.readGuardSyncOperations();
    var retried = 0;
    final updated = existing
        .map((operation) {
          if (!operationIds.contains(operation.operationId) ||
              operation.status != GuardSyncOperationStatus.failed) {
            return operation;
          }
          retried += 1;
          return operation.copyWith(
            status: GuardSyncOperationStatus.queued,
            failureReason: null,
            retryCount: operation.retryCount + 1,
          );
        })
        .toList(growable: false);
    await persistence.saveGuardSyncOperations(updated);
    return retried;
  }
}

class FallbackGuardSyncRepository implements GuardSyncRepository {
  final GuardSyncRepository primary;
  final GuardSyncRepository fallback;

  const FallbackGuardSyncRepository({
    required this.primary,
    required this.fallback,
  });

  @override
  Future<List<GuardAssignment>> readAssignments() async {
    try {
      final assignments = await primary.readAssignments();
      if (assignments.isNotEmpty) {
        await fallback.saveAssignments(assignments);
        return assignments;
      }
    } catch (_) {}
    return fallback.readAssignments();
  }

  @override
  Future<void> saveAssignments(List<GuardAssignment> assignments) async {
    try {
      await primary.saveAssignments(assignments);
    } catch (_) {
      // Local fallback remains authoritative when the primary backend fails.
    }
    await fallback.saveAssignments(assignments);
  }

  @override
  Future<List<GuardSyncOperation>> readQueuedOperations() async {
    try {
      final operations = await primary.readQueuedOperations();
      if (operations.isNotEmpty) {
        await fallback.saveQueuedOperations(operations);
        return operations;
      }
    } catch (_) {}
    return fallback.readQueuedOperations();
  }

  @override
  Future<List<GuardSyncOperation>> readOperations({
    Set<GuardSyncOperationStatus> statuses = const {
      GuardSyncOperationStatus.queued,
    },
    int limit = 50,
    String? facadeMode,
    String? facadeId,
  }) async {
    try {
      final operations = await primary.readOperations(
        statuses: statuses,
        limit: limit,
        facadeMode: facadeMode,
        facadeId: facadeId,
      );
      if (operations.isNotEmpty) {
        final queued = operations
            .where(
              (operation) =>
                  operation.status == GuardSyncOperationStatus.queued,
            )
            .toList(growable: false);
        if (queued.isNotEmpty) {
          await fallback.saveQueuedOperations(queued);
        }
        return operations;
      }
    } catch (_) {}
    return fallback.readOperations(
      statuses: statuses,
      limit: limit,
      facadeMode: facadeMode,
      facadeId: facadeId,
    );
  }

  @override
  Future<void> saveQueuedOperations(List<GuardSyncOperation> operations) async {
    try {
      await primary.saveQueuedOperations(operations);
    } catch (_) {}
    await fallback.saveQueuedOperations(operations);
  }

  @override
  Future<void> markOperationsSynced(List<String> operationIds) async {
    if (operationIds.isEmpty) return;
    try {
      await primary.markOperationsSynced(operationIds);
    } catch (_) {}
    await fallback.markOperationsSynced(operationIds);
  }

  @override
  Future<int> retryFailedOperations(List<String> operationIds) async {
    if (operationIds.isEmpty) return 0;
    int? primaryRetried;
    try {
      primaryRetried = await primary.retryFailedOperations(operationIds);
    } catch (_) {}
    final fallbackRetried = await fallback.retryFailedOperations(operationIds);
    return primaryRetried ?? fallbackRetried;
  }
}

class SupabaseGuardSyncRepository implements GuardSyncRepository {
  final SupabaseClient client;
  final String clientId;
  final String siteId;
  final String guardId;

  const SupabaseGuardSyncRepository({
    required this.client,
    required this.clientId,
    required this.siteId,
    required this.guardId,
  });

  @override
  Future<List<GuardAssignment>> readAssignments() async {
    final response = await client
        .from('guard_assignments')
        .select(
          'assignment_id, dispatch_id, client_id, site_id, guard_id, issued_at, acknowledged_at, duty_status',
        )
        .eq('client_id', clientId)
        .eq('site_id', siteId)
        .eq('guard_id', guardId)
        .order('issued_at', ascending: false);
    return response
        .whereType<Map>()
        .map(
          (row) => GuardAssignment(
            assignmentId: row['assignment_id']?.toString() ?? '',
            dispatchId: row['dispatch_id']?.toString() ?? '',
            clientId: row['client_id']?.toString() ?? clientId,
            siteId: row['site_id']?.toString() ?? siteId,
            guardId: row['guard_id']?.toString() ?? guardId,
            issuedAt:
                DateTime.tryParse(
                  row['issued_at']?.toString() ?? '',
                )?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            acknowledgedAt: DateTime.tryParse(
              row['acknowledged_at']?.toString() ?? '',
            )?.toUtc(),
            status: GuardDutyStatus.values.firstWhere(
              (value) => value.name == row['duty_status']?.toString(),
              orElse: () => GuardDutyStatus.available,
            ),
          ),
        )
        .where(
          (assignment) =>
              assignment.assignmentId.trim().isNotEmpty &&
              assignment.dispatchId.trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveAssignments(List<GuardAssignment> assignments) async {
    await client
        .from('guard_assignments')
        .delete()
        .eq('client_id', clientId)
        .eq('site_id', siteId)
        .eq('guard_id', guardId);
    if (assignments.isEmpty) return;
    await client
        .from('guard_assignments')
        .insert(
          assignments
              .map(
                (assignment) => {
                  'assignment_id': assignment.assignmentId,
                  'dispatch_id': assignment.dispatchId,
                  'client_id': assignment.clientId,
                  'site_id': assignment.siteId,
                  'guard_id': assignment.guardId,
                  'issued_at': assignment.issuedAt.toUtc().toIso8601String(),
                  'acknowledged_at': assignment.acknowledgedAt
                      ?.toUtc()
                      .toIso8601String(),
                  'duty_status': assignment.status.name,
                },
              )
              .toList(growable: false),
        );
  }

  @override
  Future<List<GuardSyncOperation>> readQueuedOperations() async {
    return readOperations(
      statuses: const {GuardSyncOperationStatus.queued},
      limit: 500,
    );
  }

  @override
  Future<List<GuardSyncOperation>> readOperations({
    Set<GuardSyncOperationStatus> statuses = const {
      GuardSyncOperationStatus.queued,
    },
    int limit = 50,
    String? facadeMode,
    String? facadeId,
  }) async {
    if (statuses.isEmpty) {
      return const [];
    }
    final modeFilter = _normalizedFacadeMode(facadeMode);
    final idFilter = facadeId?.trim();
    var query = client
        .from('guard_sync_operations')
        .select(
          'operation_id, operation_type, operation_status, occurred_at, payload, failure_reason, retry_count, facade_id, facade_mode',
        )
        .eq('client_id', clientId)
        .eq('site_id', siteId)
        .eq('guard_id', guardId)
        .inFilter(
          'operation_status',
          statuses.map((status) => status.name).toList(growable: false),
        );
    if (modeFilter != null) {
      query = query.eq('facade_mode', modeFilter);
    }
    if (idFilter != null && idFilter.isNotEmpty) {
      query = query.eq('facade_id', idFilter);
    }
    final response = await query
        .order('occurred_at', ascending: false)
        .limit(limit);
    return response
        .whereType<Map>()
        .map(
          (row) => GuardSyncOperation(
            operationId: row['operation_id']?.toString() ?? '',
            type: GuardSyncOperationType.values.firstWhere(
              (value) => value.name == row['operation_type']?.toString(),
              orElse: () => GuardSyncOperationType.statusUpdate,
            ),
            status: GuardSyncOperationStatus.values.firstWhere(
              (value) => value.name == row['operation_status']?.toString(),
              orElse: () => GuardSyncOperationStatus.queued,
            ),
            failureReason: (row['failure_reason'] as String?)?.trim(),
            retryCount: (row['retry_count'] as num?)?.toInt() ?? 0,
            createdAt:
                DateTime.tryParse(
                  row['occurred_at']?.toString() ?? '',
                )?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            payload: row['payload'] is Map
                ? (row['payload'] as Map).map(
                    (key, value) => MapEntry(key.toString(), value),
                  )
                : const {},
          ),
        )
        .where((operation) => operation.operationId.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> saveQueuedOperations(List<GuardSyncOperation> operations) async {
    await client
        .from('guard_sync_operations')
        .delete()
        .eq('client_id', clientId)
        .eq('site_id', siteId)
        .eq('guard_id', guardId)
        .eq('operation_status', 'queued');
    if (operations.isEmpty) return;
    await client
        .from('guard_sync_operations')
        .insert(
          operations
              .map((operation) {
                final facadeMode = _operationFacadeMode(operation);
                final facadeId = _operationFacadeId(operation);
                return {
                  'operation_id': operation.operationId,
                  'operation_type': operation.type.name,
                  'operation_status': 'queued',
                  'client_id': clientId,
                  'site_id': siteId,
                  'guard_id': guardId,
                  'occurred_at': operation.createdAt.toUtc().toIso8601String(),
                  'payload': operation.payload,
                  'facade_mode': facadeMode,
                  'facade_id': facadeId,
                };
              })
              .toList(growable: false),
        );
  }

  @override
  Future<void> markOperationsSynced(List<String> operationIds) async {
    if (operationIds.isEmpty) return;
    await client
        .from('guard_sync_operations')
        .update({'operation_status': 'synced'})
        .eq('client_id', clientId)
        .eq('site_id', siteId)
        .eq('guard_id', guardId)
        .inFilter('operation_id', operationIds)
        .eq('operation_status', 'queued');
  }

  @override
  Future<int> retryFailedOperations(List<String> operationIds) async {
    if (operationIds.isEmpty) return 0;
    final rows = await client
        .from('guard_sync_operations')
        .select('operation_id, retry_count')
        .eq('client_id', clientId)
        .eq('site_id', siteId)
        .eq('guard_id', guardId)
        .eq('operation_status', 'failed')
        .inFilter('operation_id', operationIds);
    final failedRows = rows.whereType<Map>().toList(growable: false);
    for (final row in failedRows) {
      final operationId = row['operation_id']?.toString();
      if (operationId == null || operationId.trim().isEmpty) continue;
      final retryCount = (row['retry_count'] as num?)?.toInt() ?? 0;
      await client
          .from('guard_sync_operations')
          .update({
            'operation_status': 'queued',
            'failure_reason': null,
            'retry_count': retryCount + 1,
          })
          .eq('client_id', clientId)
          .eq('site_id', siteId)
          .eq('guard_id', guardId)
          .eq('operation_id', operationId)
          .eq('operation_status', 'failed');
    }
    return failedRows.length;
  }
}

String? _normalizedFacadeMode(String? raw) {
  final value = raw?.trim().toLowerCase();
  if (value == null || value.isEmpty) return null;
  if (value == 'live' || value == 'stub' || value == 'unknown') {
    return value;
  }
  return null;
}

Map<String, Object?>? _operationRuntimeContext(GuardSyncOperation operation) {
  final raw = operation.payload['onyx_runtime_context'];
  if (raw is! Map) return null;
  return raw.map((key, value) => MapEntry(key.toString(), value));
}

String? _operationFacadeId(GuardSyncOperation operation) {
  final context = _operationRuntimeContext(operation);
  final raw = context?['telemetry_facade_id'];
  if (raw is! String) return null;
  final value = raw.trim();
  return value.isEmpty ? null : value;
}

String? _operationFacadeMode(GuardSyncOperation operation) {
  final context = _operationRuntimeContext(operation);
  final raw = context?['telemetry_facade_live_mode'];
  if (raw is bool) {
    return raw ? 'live' : 'stub';
  }
  if (raw is String) {
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'true') return 'live';
    if (normalized == 'false') return 'stub';
    if (normalized.isNotEmpty) return 'unknown';
  }
  if (context != null) return 'unknown';
  return null;
}
