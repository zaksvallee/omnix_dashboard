import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/vehicle_visit_ledger_projector.dart';

class VehicleVisitPersistenceRow {
  final String clientId;
  final String siteId;
  final String vehicleKey;
  final String plateNumber;
  final DateTime startedAtUtc;
  final DateTime lastSeenAtUtc;
  final DateTime? completedAtUtc;
  final bool sawEntry;
  final bool sawService;
  final bool sawExit;
  final double? dwellMinutes;
  final String visitStatus;
  final bool isSuspiciousShort;
  final bool isLoitering;
  final int eventCount;
  final List<String> eventIds;
  final List<String> intelligenceIds;
  final List<String> zoneLabels;

  const VehicleVisitPersistenceRow({
    required this.clientId,
    required this.siteId,
    required this.vehicleKey,
    required this.plateNumber,
    required this.startedAtUtc,
    required this.lastSeenAtUtc,
    required this.completedAtUtc,
    required this.sawEntry,
    required this.sawService,
    required this.sawExit,
    required this.dwellMinutes,
    required this.visitStatus,
    required this.isSuspiciousShort,
    required this.isLoitering,
    required this.eventCount,
    required this.eventIds,
    required this.intelligenceIds,
    required this.zoneLabels,
  });

  factory VehicleVisitPersistenceRow.fromJson(Map<String, Object?> json) {
    List<String> normalizeList(Object? raw) {
      if (raw is! List) {
        return const <String>[];
      }
      return raw
          .map((value) => value?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    }

    return VehicleVisitPersistenceRow(
      clientId: (json['client_id'] ?? '').toString().trim(),
      siteId: (json['site_id'] ?? '').toString().trim(),
      vehicleKey: (json['vehicle_key'] ?? '').toString().trim(),
      plateNumber: (json['plate_number'] ?? '').toString().trim(),
      startedAtUtc:
          DateTime.tryParse((json['started_at_utc'] ?? '').toString())
              ?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lastSeenAtUtc:
          DateTime.tryParse((json['last_seen_at_utc'] ?? '').toString())
              ?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      completedAtUtc: DateTime.tryParse(
        (json['completed_at_utc'] ?? '').toString(),
      )?.toUtc(),
      sawEntry: json['saw_entry'] == true,
      sawService: json['saw_service'] == true,
      sawExit: json['saw_exit'] == true,
      dwellMinutes: (json['dwell_minutes'] as num?)?.toDouble(),
      visitStatus: (json['visit_status'] ?? '').toString().trim(),
      isSuspiciousShort: json['is_suspicious_short'] == true,
      isLoitering: json['is_loitering'] == true,
      eventCount: (json['event_count'] as num?)?.toInt() ?? 0,
      eventIds: normalizeList(json['event_ids']),
      intelligenceIds: normalizeList(json['intelligence_ids']),
      zoneLabels: normalizeList(json['zone_labels']),
    );
  }
}

abstract interface class VehicleVisitRepository {
  Future<void> upsertVisit(VehicleVisitRecord visit, {required DateTime nowUtc});

  Future<void> upsertHourlyThroughput(
    Map<int, int> hourlyData,
    String clientId,
    String siteId,
    DateTime date, {
    required Iterable<VehicleVisitRecord> visits,
    required DateTime nowUtc,
  });

  Future<List<VehicleVisitPersistenceRow>> listVisitsForClient(String clientId);
}

class SupabaseVehicleVisitRepository implements VehicleVisitRepository {
  final SupabaseClient client;

  const SupabaseVehicleVisitRepository({required this.client});

  @override
  Future<void> upsertVisit(
    VehicleVisitRecord visit, {
    required DateTime nowUtc,
  }) async {
    final status = visit.statusAt(nowUtc.toUtc());
    final dwellMinutes = visit.dwell.inSeconds / 60.0;
    try {
      await client.from('vehicle_visits').upsert(
        {
          'client_id': visit.clientId,
          'site_id': visit.siteId,
          'vehicle_key': visit.vehicleKey,
          'plate_number': visit.plateNumber,
          'started_at_utc': visit.startedAtUtc.toUtc().toIso8601String(),
          'last_seen_at_utc': visit.lastSeenAtUtc.toUtc().toIso8601String(),
          'completed_at_utc': visit.completedAtUtc?.toUtc().toIso8601String(),
          'saw_entry': visit.sawEntry,
          'saw_service': visit.sawService,
          'saw_exit': visit.sawExit,
          'dwell_minutes': dwellMinutes,
          'visit_status': status.name,
          'is_suspicious_short':
              status == VehicleVisitStatus.completed &&
              visit.dwell < const Duration(minutes: 2),
          'is_loitering': visit.dwell >= const Duration(minutes: 30),
          'event_count': visit.eventCount,
          'event_ids': visit.eventIds,
          'intelligence_ids': visit.intelligenceIds,
          'zone_labels': visit.zoneLabels,
        },
        onConflict: 'client_id,site_id,vehicle_key,started_at_utc',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to upsert BI vehicle visit for ${visit.clientId}/${visit.siteId}/${visit.vehicleKey}.',
        name: 'SupabaseVehicleVisitRepository',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> upsertHourlyThroughput(
    Map<int, int> hourlyData,
    String clientId,
    String siteId,
    DateTime date, {
    required Iterable<VehicleVisitRecord> visits,
    required DateTime nowUtc,
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    if (normalizedClientId.isEmpty ||
        normalizedSiteId.isEmpty ||
        hourlyData.isEmpty) {
      return;
    }
    final visitDate = _utcDateKey(date);
    final visitsByHour = <int, List<VehicleVisitRecord>>{};
    for (final visit in visits) {
      final visitAtUtc = visit.startedAtUtc.toUtc();
      if (_utcDateKey(visitAtUtc) != visitDate) {
        continue;
      }
      visitsByHour.putIfAbsent(visitAtUtc.hour, () => <VehicleVisitRecord>[]).add(
        visit,
      );
    }
    final rows = <Map<String, Object?>>[];
    for (final entry in hourlyData.entries) {
      final hour = entry.key;
      final visitCount = entry.value;
      if (hour < 0 || hour > 23 || visitCount <= 0) {
        continue;
      }
      final hourVisits = visitsByHour[hour] ?? const <VehicleVisitRecord>[];
      final completedVisits = hourVisits
          .where((visit) => visit.statusAt(nowUtc.toUtc()) == VehicleVisitStatus.completed)
          .toList(growable: false);
      final avgDwellMinutes = completedVisits.isEmpty
          ? null
          : completedVisits
                  .map((visit) => visit.dwell.inSeconds / 60.0)
                  .reduce((left, right) => left + right) /
              completedVisits.length;
      rows.add({
        'client_id': normalizedClientId,
        'site_id': normalizedSiteId,
        'visit_date': visitDate,
        'hour_of_day': hour,
        'visit_count': visitCount,
        'completed_count': completedVisits.length,
        'entry_count': hourVisits.where((visit) => visit.sawEntry).length,
        'exit_count': hourVisits.where((visit) => visit.sawExit).length,
        'service_count': hourVisits.where((visit) => visit.sawService).length,
        'avg_dwell_minutes': avgDwellMinutes,
      });
    }
    if (rows.isEmpty) {
      return;
    }
    try {
      await client.from('hourly_throughput').upsert(
        rows,
        onConflict: 'client_id,site_id,visit_date,hour_of_day',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to upsert BI hourly throughput for $normalizedClientId/$normalizedSiteId/$visitDate.',
        name: 'SupabaseVehicleVisitRepository',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<List<VehicleVisitPersistenceRow>> listVisitsForClient(
    String clientId,
  ) async {
    try {
      final response = await client
          .from('vehicle_visits')
          .select(
            'client_id, site_id, vehicle_key, plate_number, started_at_utc, last_seen_at_utc, completed_at_utc, saw_entry, saw_service, saw_exit, dwell_minutes, visit_status, is_suspicious_short, is_loitering, event_count, event_ids, intelligence_ids, zone_labels',
          )
          .eq('client_id', clientId)
          .order('started_at_utc', ascending: true);
      return response
          .whereType<Map>()
          .map(
            (row) => VehicleVisitPersistenceRow.fromJson(
              row.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to list BI vehicle visits for $clientId.',
        name: 'SupabaseVehicleVisitRepository',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static String _utcDateKey(DateTime value) {
    return value.toUtc().toIso8601String().split('T').first;
  }
}
