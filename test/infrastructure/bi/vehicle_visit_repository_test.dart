import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omnix_dashboard/application/vehicle_visit_ledger_projector.dart';
import 'package:omnix_dashboard/infrastructure/bi/vehicle_visit_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseVehicleVisitRepository', () {
    test('upsert creates a new vehicle visit row', () async {
      final api = _FakeVehicleBiApi();
      final repository = SupabaseVehicleVisitRepository(
        client: _buildSupabaseClient(api.handle),
      );

      await repository.upsertVisit(
        _visit(
          clientId: 'CLIENT-A',
          siteId: 'SITE-1',
          vehicleKey: 'CA123456',
          plateNumber: 'CA 123 456',
          startedAtUtc: DateTime.utc(2026, 4, 7, 8, 0),
          lastSeenAtUtc: DateTime.utc(2026, 4, 7, 8, 7),
          completedAtUtc: DateTime.utc(2026, 4, 7, 8, 7),
        ),
        nowUtc: DateTime.utc(2026, 4, 7, 9, 0),
      );

      final rows = await repository.listVisitsForClient('CLIENT-A');

      expect(rows, hasLength(1));
      expect(rows.single.vehicleKey, 'CA123456');
      expect(rows.single.visitStatus, 'completed');
      expect(rows.single.eventCount, 1);
    });

    test('upsert updates an existing vehicle visit row idempotently', () async {
      final api = _FakeVehicleBiApi();
      final repository = SupabaseVehicleVisitRepository(
        client: _buildSupabaseClient(api.handle),
      );
      final startedAt = DateTime.utc(2026, 4, 7, 8, 0);

      await repository.upsertVisit(
        _visit(
          clientId: 'CLIENT-A',
          siteId: 'SITE-1',
          vehicleKey: 'CA123456',
          plateNumber: 'CA 123 456',
          startedAtUtc: startedAt,
          lastSeenAtUtc: DateTime.utc(2026, 4, 7, 8, 5),
          completedAtUtc: null,
          sawEntry: true,
          sawService: false,
          sawExit: false,
          eventCount: 1,
        ),
        nowUtc: DateTime.utc(2026, 4, 7, 8, 10),
      );
      await repository.upsertVisit(
        _visit(
          clientId: 'CLIENT-A',
          siteId: 'SITE-1',
          vehicleKey: 'CA123456',
          plateNumber: 'CA 123 456',
          startedAtUtc: startedAt,
          lastSeenAtUtc: DateTime.utc(2026, 4, 7, 8, 12),
          completedAtUtc: DateTime.utc(2026, 4, 7, 8, 12),
          sawEntry: true,
          sawService: true,
          sawExit: true,
          eventCount: 3,
          eventIds: const <String>['evt-1', 'evt-2', 'evt-3'],
        ),
        nowUtc: DateTime.utc(2026, 4, 7, 8, 15),
      );

      final rows = await repository.listVisitsForClient('CLIENT-A');

      expect(rows, hasLength(1));
      expect(rows.single.lastSeenAtUtc, DateTime.utc(2026, 4, 7, 8, 12));
      expect(rows.single.completedAtUtc, DateTime.utc(2026, 4, 7, 8, 12));
      expect(rows.single.sawService, isTrue);
      expect(rows.single.sawExit, isTrue);
      expect(rows.single.eventCount, 3);
      expect(rows.single.eventIds, const <String>['evt-1', 'evt-2', 'evt-3']);
    });

    test('RLS rejects cross-client reads', () async {
      final repository = SupabaseVehicleVisitRepository(
        client: _buildSupabaseClient((request) async {
          if (request.url.path.endsWith('/vehicle_visits') &&
              request.method == 'GET' &&
              request.url.queryParameters['client_id'] == 'eq.CLIENT-B') {
            return http.Response(
              '{"message":"new row violates row-level security policy"}',
              403,
              request: request,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('[]', 200, request: request);
        }),
      );

      expect(
        () => repository.listVisitsForClient('CLIENT-B'),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}

VehicleVisitRecord _visit({
  required String clientId,
  required String siteId,
  required String vehicleKey,
  required String plateNumber,
  required DateTime startedAtUtc,
  required DateTime lastSeenAtUtc,
  required DateTime? completedAtUtc,
  bool sawEntry = true,
  bool sawService = true,
  bool sawExit = true,
  int eventCount = 1,
  List<String> eventIds = const <String>['evt-1'],
}) {
  return VehicleVisitRecord(
    clientId: clientId,
    siteId: siteId,
    vehicleKey: vehicleKey,
    plateNumber: plateNumber,
    startedAtUtc: startedAtUtc,
    lastSeenAtUtc: lastSeenAtUtc,
    completedAtUtc: completedAtUtc,
    sawEntry: sawEntry,
    sawService: sawService,
    sawExit: sawExit,
    eventCount: eventCount,
    eventIds: eventIds,
    intelligenceIds: const <String>['intel-1'],
    zoneLabels: const <String>['Entry Lane'],
  );
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

class _FakeVehicleBiApi {
  final Map<String, Map<String, Object?>> _visitRows =
      <String, Map<String, Object?>>{};

  Future<http.Response> handle(http.Request request) async {
    if (request.url.path.endsWith('/vehicle_visits')) {
      if (request.method == 'POST') {
        final decoded = jsonDecode(request.body);
        if (decoded is Map<String, Object?>) {
          final row = Map<String, Object?>.from(decoded);
          _visitRows[_visitKey(row)] = row;
        } else if (decoded is List) {
          for (final item in decoded.whereType<Map>()) {
            final row = Map<String, Object?>.from(
              item.map((key, value) => MapEntry(key.toString(), value)),
            );
            _visitRows[_visitKey(row)] = row;
          }
        }
        return http.Response('[]', 201, request: request);
      }
      if (request.method == 'GET') {
        final clientFilter = request.url.queryParameters['client_id'];
        final clientId = clientFilter?.startsWith('eq.') == true
            ? clientFilter!.substring(3)
            : '';
        final rows = _visitRows.values
            .where((row) => (row['client_id'] ?? '').toString() == clientId)
            .toList(growable: false);
        return http.Response(jsonEncode(rows), 200, request: request);
      }
    }
    if (request.url.path.endsWith('/hourly_throughput')) {
      return http.Response('[]', 201, request: request);
    }
    return http.Response('[]', 200, request: request);
  }

  static String _visitKey(Map<String, Object?> row) {
    return [
      row['client_id'],
      row['site_id'],
      row['vehicle_key'],
      row['started_at_utc'],
    ].join('|');
  }
}
