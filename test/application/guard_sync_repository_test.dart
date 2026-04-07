import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/application/guard_sync_repository.dart';
import 'package:omnix_dashboard/domain/guard/guard_position_summary.dart';
import 'package:omnix_dashboard/domain/guard/guard_mobile_ops.dart';

void main() {
  group('SharedPrefsGuardSyncRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and restores assignments and queued operations', () async {
      final persistence = await DispatchPersistenceService.create();
      final repository = SharedPrefsGuardSyncRepository(persistence);
      final assignments = [
        GuardAssignment(
          assignmentId: 'ASSIGN-001',
          dispatchId: 'DISP-001',
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          guardId: 'GUARD-001',
          issuedAt: DateTime.utc(2026, 3, 4, 12, 0),
          acknowledgedAt: DateTime.utc(2026, 3, 4, 12, 1),
          status: GuardDutyStatus.enRoute,
        ),
      ];
      final operations = [
        GuardSyncOperation(
          operationId: 'status:ASSIGN-001:enRoute:2026-03-04T12:01:00.000Z',
          type: GuardSyncOperationType.statusUpdate,
          createdAt: DateTime.utc(2026, 3, 4, 12, 1),
          payload: const {
            'assignment_id': 'ASSIGN-001',
            'dispatch_id': 'DISP-001',
            'status': 'enRoute',
          },
        ),
      ];

      await repository.saveAssignments(assignments);
      await repository.saveQueuedOperations(operations);

      final restoredAssignments = await repository.readAssignments();
      final restoredOperations = await repository.readQueuedOperations();

      expect(
        restoredAssignments.map((entry) => entry.toJson()).toList(),
        assignments.map((entry) => entry.toJson()).toList(),
      );
      expect(
        restoredOperations.map((entry) => entry.toJson()).toList(),
        operations.map((entry) => entry.toJson()).toList(),
      );
    });

    test('markOperationsSynced removes synced rows from local queue', () async {
      final persistence = await DispatchPersistenceService.create();
      final repository = SharedPrefsGuardSyncRepository(persistence);
      final operations = [
        GuardSyncOperation(
          operationId: 'status:ASSIGN-001:enRoute:2026-03-04T12:01:00.000Z',
          type: GuardSyncOperationType.statusUpdate,
          createdAt: DateTime.utc(2026, 3, 4, 12, 1),
          payload: const {'status': 'enRoute'},
        ),
        GuardSyncOperation(
          operationId: 'panic:PANIC-1',
          type: GuardSyncOperationType.panicSignal,
          createdAt: DateTime.utc(2026, 3, 4, 12, 2),
          payload: const {'signal_id': 'PANIC-1'},
        ),
      ];
      await repository.saveQueuedOperations(operations);

      await repository.markOperationsSynced([
        'status:ASSIGN-001:enRoute:2026-03-04T12:01:00.000Z',
      ]);
      final restoredOperations = await repository.readQueuedOperations();

      expect(restoredOperations, hasLength(1));
      expect(restoredOperations.single.operationId, 'panic:PANIC-1');
    });

    test(
      'retryFailedOperations requeues failed rows and increments retry',
      () async {
        final persistence = await DispatchPersistenceService.create();
        final repository = SharedPrefsGuardSyncRepository(persistence);
        final operations = [
          GuardSyncOperation(
            operationId: 'panic:PANIC-1',
            type: GuardSyncOperationType.panicSignal,
            status: GuardSyncOperationStatus.failed,
            failureReason: 'network unavailable',
            retryCount: 2,
            createdAt: DateTime.utc(2026, 3, 4, 12, 2),
            payload: const {'signal_id': 'PANIC-1'},
          ),
        ];
        await repository.saveQueuedOperations(operations);

        final retried = await repository.retryFailedOperations([
          'panic:PANIC-1',
        ]);
        final restoredOperations = await repository.readQueuedOperations();

        expect(retried, 1);
        expect(restoredOperations, hasLength(1));
        expect(
          restoredOperations.single.status,
          GuardSyncOperationStatus.queued,
        );
        expect(restoredOperations.single.failureReason, isNull);
        expect(restoredOperations.single.retryCount, 3);
      },
    );

    test(
      'readOperations applies status/facade filters and deterministic ordering',
      () async {
        final persistence = await DispatchPersistenceService.create();
        final repository = SharedPrefsGuardSyncRepository(persistence);
        final operations = [
          GuardSyncOperation(
            operationId: 'op-live-queued-newer',
            type: GuardSyncOperationType.statusUpdate,
            status: GuardSyncOperationStatus.queued,
            createdAt: DateTime.utc(2026, 3, 4, 12, 3),
            payload: const {
              'onyx_runtime_context': {
                'telemetry_facade_id': 'fsk_live',
                'telemetry_facade_live_mode': true,
              },
            },
          ),
          GuardSyncOperation(
            operationId: 'op-live-queued-older',
            type: GuardSyncOperationType.statusUpdate,
            status: GuardSyncOperationStatus.queued,
            createdAt: DateTime.utc(2026, 3, 4, 12, 1),
            payload: const {
              'onyx_runtime_context': {
                'telemetry_facade_id': 'fsk_live',
                'telemetry_facade_live_mode': true,
              },
            },
          ),
          GuardSyncOperation(
            operationId: 'op-stub-failed',
            type: GuardSyncOperationType.panicSignal,
            status: GuardSyncOperationStatus.failed,
            createdAt: DateTime.utc(2026, 3, 4, 12, 2),
            payload: const {
              'onyx_runtime_context': {
                'telemetry_facade_id': 'fsk_stub',
                'telemetry_facade_live_mode': false,
              },
            },
          ),
        ];
        await repository.saveQueuedOperations(operations);

        final filtered = await repository.readOperations(
          statuses: const {GuardSyncOperationStatus.queued},
          facadeMode: 'live',
          facadeId: 'fsk_live',
        );
        expect(filtered.map((entry) => entry.operationId).toList(), [
          'op-live-queued-newer',
          'op-live-queued-older',
        ]);

        final limited = await repository.readOperations(
          statuses: const {
            GuardSyncOperationStatus.queued,
            GuardSyncOperationStatus.failed,
          },
          limit: 1,
        );
        expect(limited, hasLength(1));
        expect(limited.single.operationId, 'op-live-queued-newer');
      },
    );

    test('readLatestGuardPositions returns newest heartbeat per guard', () async {
      final persistence = await DispatchPersistenceService.create();
      final repository = SharedPrefsGuardSyncRepository(persistence);
      final operations = [
        GuardSyncOperation(
          operationId: 'loc:GUARD-001:old',
          type: GuardSyncOperationType.locationHeartbeat,
          createdAt: DateTime.utc(2026, 4, 7, 7, 0),
          payload: const {
            'guard_id': 'GUARD-001',
            'client_id': 'CLIENT-001',
            'site_id': 'SITE-SANDTON',
            'latitude': -26.2041,
            'longitude': 28.0473,
            'accuracy_meters': 5.0,
            'recorded_at': '2026-04-07T07:00:00.000Z',
          },
        ),
        GuardSyncOperation(
          operationId: 'loc:GUARD-001:new',
          type: GuardSyncOperationType.locationHeartbeat,
          createdAt: DateTime.utc(2026, 4, 7, 7, 5),
          payload: const {
            'guard_id': 'GUARD-001',
            'client_id': 'CLIENT-001',
            'site_id': 'SITE-SANDTON',
            'latitude': -26.2045,
            'longitude': 28.0479,
            'accuracy_meters': 4.0,
            'recorded_at': '2026-04-07T07:05:00.000Z',
          },
        ),
        GuardSyncOperation(
          operationId: 'loc:GUARD-002',
          type: GuardSyncOperationType.locationHeartbeat,
          createdAt: DateTime.utc(2026, 4, 7, 7, 2),
          payload: const {
            'guard_id': 'GUARD-002',
            'client_id': 'CLIENT-001',
            'site_id': 'SITE-SANDTON',
            'latitude': -26.2050,
            'longitude': 28.0481,
            'accuracy_meters': 6.0,
            'recorded_at': '2026-04-07T07:02:00.000Z',
          },
        ),
      ];
      await repository.saveQueuedOperations(operations);

      final positions = await repository.readLatestGuardPositions();

      expect(positions, hasLength(2));
      expect(positions.first.guardId, 'GUARD-001');
      expect(positions.first.recordedAtUtc, DateTime.utc(2026, 4, 7, 7, 5));
      expect(positions.first.latitude, -26.2045);
      expect(positions[1].guardId, 'GUARD-002');
    });
  });

  group('FallbackGuardSyncRepository', () {
    test('reads from fallback when primary fails', () async {
      final fallback = _FakeGuardSyncRepository(
        assignments: [
          GuardAssignment(
            assignmentId: 'ASSIGN-LOCAL',
            dispatchId: 'DISP-LOCAL',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            guardId: 'GUARD-001',
            issuedAt: DateTime.utc(2026, 3, 4, 12, 5),
          ),
        ],
      );
      final repository = FallbackGuardSyncRepository(
        primary: _FakeGuardSyncRepository(throwOnRead: true),
        fallback: fallback,
      );

      final restored = await repository.readAssignments();

      expect(restored, hasLength(1));
      expect(restored.single.assignmentId, 'ASSIGN-LOCAL');
    });

    test('mirrors queue writes into fallback when primary fails', () async {
      final fallback = _FakeGuardSyncRepository();
      final repository = FallbackGuardSyncRepository(
        primary: _FakeGuardSyncRepository(throwOnWrite: true),
        fallback: fallback,
      );
      final operations = [
        GuardSyncOperation(
          operationId: 'panic:PANIC-1',
          type: GuardSyncOperationType.panicSignal,
          createdAt: DateTime.utc(2026, 3, 4, 12, 10),
          payload: const {'signal_id': 'PANIC-1'},
        ),
      ];

      await repository.saveQueuedOperations(operations);

      expect(fallback.operations, hasLength(1));
      expect(fallback.operations.single.operationId, 'panic:PANIC-1');
    });

    test('reads latest guard positions from fallback when primary fails', () async {
      final fallback = _FakeGuardSyncRepository(
        positions: [
          GuardPositionSummary(
            guardId: 'GUARD-LOCAL',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            latitude: -26.2041,
            longitude: 28.0473,
            recordedAtUtc: DateTime.utc(2026, 4, 7, 7, 10),
          ),
        ],
      );
      final repository = FallbackGuardSyncRepository(
        primary: _FakeGuardSyncRepository(throwOnRead: true),
        fallback: fallback,
      );

      final restored = await repository.readLatestGuardPositions();

      expect(restored, hasLength(1));
      expect(restored.single.guardId, 'GUARD-LOCAL');
    });
  });

  group('SupabaseGuardSyncRepository', () {
    test('saveAssignments does not delete scoped rows when upsert fails', () async {
      final requests = <String>[];
      final repository = SupabaseGuardSyncRepository(
        client: _buildSupabaseClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.method == 'POST' &&
              request.url.path.endsWith('/guard_assignments')) {
            return http.Response(
              '{"message":"write failed"}',
              500,
              request: request,
            );
          }
          return http.Response('[]', 200, request: request);
        }),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        guardId: 'GUARD-001',
      );

      await expectLater(
        repository.saveAssignments([
          GuardAssignment(
            assignmentId: 'ASSIGN-001',
            dispatchId: 'DISP-001',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            guardId: 'GUARD-001',
            issuedAt: DateTime.utc(2026, 4, 7, 7, 0),
          ),
        ]),
        throwsA(anything),
      );

      expect(
        requests.where((entry) => entry.startsWith('DELETE ')),
        isEmpty,
      );
      expect(
        requests.where((entry) => entry.startsWith('POST ')),
        hasLength(1),
      );
    });

    test('saveAssignments upserts before pruning stale rows', () async {
      final requests = <String>[];
      final repository = SupabaseGuardSyncRepository(
        client: _buildSupabaseClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          return http.Response(
            '[]',
            request.method == 'POST' ? 201 : 200,
            request: request,
          );
        }),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        guardId: 'GUARD-001',
      );

      await repository.saveAssignments([
        GuardAssignment(
          assignmentId: 'ASSIGN-001',
          dispatchId: 'DISP-001',
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          guardId: 'GUARD-001',
          issuedAt: DateTime.utc(2026, 4, 7, 7, 0),
        ),
      ]);

      expect(requests, [
        'POST /rest/v1/guard_assignments',
        'DELETE /rest/v1/guard_assignments',
      ]);
    });

    test(
      'saveQueuedOperations does not delete scoped queue rows when upsert fails',
      () async {
        final requests = <String>[];
        final repository = SupabaseGuardSyncRepository(
          client: _buildSupabaseClient((request) async {
            requests.add('${request.method} ${request.url.path}');
            if (request.method == 'POST' &&
                request.url.path.endsWith('/guard_sync_operations')) {
              return http.Response(
                '{"message":"write failed"}',
                500,
                request: request,
              );
            }
            return http.Response('[]', 200, request: request);
          }),
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          guardId: 'GUARD-001',
        );

        await expectLater(
          repository.saveQueuedOperations([
            GuardSyncOperation(
              operationId: 'panic:PANIC-1',
              type: GuardSyncOperationType.panicSignal,
              createdAt: DateTime.utc(2026, 4, 7, 7, 5),
              payload: const {'signal_id': 'PANIC-1'},
            ),
          ]),
          throwsA(anything),
        );

        expect(
          requests.where((entry) => entry.startsWith('DELETE ')),
          isEmpty,
        );
        expect(
          requests.where((entry) => entry.startsWith('POST ')),
          hasLength(1),
        );
      },
    );

    test('saveQueuedOperations upserts before pruning stale queued rows', () async {
      final requests = <String>[];
      final repository = SupabaseGuardSyncRepository(
        client: _buildSupabaseClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          return http.Response(
            '[]',
            request.method == 'POST' ? 201 : 200,
            request: request,
          );
        }),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        guardId: 'GUARD-001',
      );

      await repository.saveQueuedOperations([
        GuardSyncOperation(
          operationId: 'panic:PANIC-1',
          type: GuardSyncOperationType.panicSignal,
          createdAt: DateTime.utc(2026, 4, 7, 7, 5),
          payload: const {'signal_id': 'PANIC-1'},
        ),
      ]);

      expect(requests, [
        'POST /rest/v1/guard_sync_operations',
        'DELETE /rest/v1/guard_sync_operations',
      ]);
    });

    test('readLatestGuardPositions returns latest heartbeat per guard for site', () async {
      final requests = <Uri>[];
      final repository = SupabaseGuardSyncRepository(
        client: _buildSupabaseClient((request) async {
          requests.add(request.url);
          return http.Response(
            '''
[
  {
    "guard_id":"GUARD-001",
    "client_id":"CLIENT-001",
    "site_id":"SITE-SANDTON",
    "occurred_at":"2026-04-07T07:05:00.000Z",
    "operation_type":"locationHeartbeat",
    "payload":{
      "guard_id":"GUARD-001",
      "client_id":"CLIENT-001",
      "site_id":"SITE-SANDTON",
      "latitude":-26.2045,
      "longitude":28.0479,
      "accuracy_meters":4.0,
      "recorded_at":"2026-04-07T07:05:00.000Z"
    }
  },
  {
    "guard_id":"GUARD-001",
    "client_id":"CLIENT-001",
    "site_id":"SITE-SANDTON",
    "occurred_at":"2026-04-07T07:00:00.000Z",
    "operation_type":"locationHeartbeat",
    "payload":{
      "guard_id":"GUARD-001",
      "client_id":"CLIENT-001",
      "site_id":"SITE-SANDTON",
      "latitude":-26.2041,
      "longitude":28.0473,
      "accuracy_meters":5.0,
      "recorded_at":"2026-04-07T07:00:00.000Z"
    }
  },
  {
    "guard_id":"GUARD-002",
    "client_id":"CLIENT-001",
    "site_id":"SITE-SANDTON",
    "occurred_at":"2026-04-07T07:02:00.000Z",
    "operation_type":"locationHeartbeat",
    "payload":{
      "guard_id":"GUARD-002",
      "client_id":"CLIENT-001",
      "site_id":"SITE-SANDTON",
      "latitude":-26.2050,
      "longitude":28.0481,
      "accuracy_meters":6.0,
      "recorded_at":"2026-04-07T07:02:00.000Z"
    }
  }
]
''',
            200,
            request: request,
          );
        }),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        guardId: 'GUARD-001',
      );

      final positions = await repository.readLatestGuardPositions();

      expect(positions, hasLength(2));
      expect(positions.first.guardId, 'GUARD-001');
      expect(positions.first.recordedAtUtc, DateTime.utc(2026, 4, 7, 7, 5));
      expect(
        requests.single.queryParameters['operation_type'],
        'eq.locationHeartbeat',
      );
    });
  });
}

SupabaseClient _buildSupabaseClient(
  Future<http.Response> Function(http.Request request) handler,
) {
  return SupabaseClient(
    'https://example.supabase.co',
    'anon-key',
    accessToken: () async => null,
    httpClient: MockClient(handler),
  );
}

class _FakeGuardSyncRepository implements GuardSyncRepository {
  final bool throwOnRead;
  final bool throwOnWrite;
  List<GuardAssignment> assignments;
  List<GuardSyncOperation> operations;
  List<GuardPositionSummary> positions;

  _FakeGuardSyncRepository({
    this.throwOnRead = false,
    this.throwOnWrite = false,
    this.assignments = const [],
    List<GuardSyncOperation>? operations,
    List<GuardPositionSummary>? positions,
  }) : operations = operations ?? const [],
       positions = positions ?? const [];

  @override
  Future<List<GuardAssignment>> readAssignments() async {
    if (throwOnRead) {
      throw StateError('read failed');
    }
    return assignments;
  }

  @override
  Future<void> saveAssignments(List<GuardAssignment> assignments) async {
    if (throwOnWrite) {
      throw StateError('write failed');
    }
    this.assignments = List<GuardAssignment>.from(assignments);
  }

  @override
  Future<List<GuardPositionSummary>> readLatestGuardPositions() async {
    if (throwOnRead) {
      throw StateError('read failed');
    }
    return positions;
  }

  @override
  Future<List<GuardSyncOperation>> readQueuedOperations() async {
    if (throwOnRead) {
      throw StateError('read failed');
    }
    return operations;
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
    if (throwOnRead) {
      throw StateError('read failed');
    }
    final filtered = operations
        .where((operation) => statuses.contains(operation.status))
        .toList(growable: false);
    if (filtered.length <= limit) {
      return filtered;
    }
    return filtered.sublist(0, limit);
  }

  @override
  Future<void> saveQueuedOperations(List<GuardSyncOperation> operations) async {
    if (throwOnWrite) {
      throw StateError('write failed');
    }
    this.operations = List<GuardSyncOperation>.from(operations);
  }

  @override
  Future<void> markOperationsSynced(List<String> operationIds) async {
    if (throwOnWrite) {
      throw StateError('write failed');
    }
    operations = operations
        .where((operation) => !operationIds.contains(operation.operationId))
        .toList(growable: false);
  }

  @override
  Future<int> retryFailedOperations(List<String> operationIds) async {
    if (throwOnWrite) {
      throw StateError('write failed');
    }
    var retried = 0;
    operations = operations
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
    return retried;
  }
}
