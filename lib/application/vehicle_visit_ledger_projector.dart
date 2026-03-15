import '../domain/events/intelligence_received.dart';

enum VehicleVisitZoneStage { entry, service, exit, unknown }

enum VehicleVisitStatus { active, completed, incomplete }

class VehicleVisitRecord {
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
  final int eventCount;
  final List<String> intelligenceIds;
  final List<String> zoneLabels;

  const VehicleVisitRecord({
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
    required this.eventCount,
    this.intelligenceIds = const <String>[],
    this.zoneLabels = const <String>[],
  });

  VehicleVisitStatus statusAt(
    DateTime nowUtc, {
    Duration staleAfter = const Duration(minutes: 45),
  }) {
    if (completedAtUtc != null || sawExit) {
      return VehicleVisitStatus.completed;
    }
    if (nowUtc.toUtc().difference(lastSeenAtUtc.toUtc()) > staleAfter) {
      return VehicleVisitStatus.incomplete;
    }
    return VehicleVisitStatus.active;
  }

  Duration get dwell {
    final endAtUtc = completedAtUtc ?? lastSeenAtUtc;
    return endAtUtc.toUtc().difference(startedAtUtc.toUtc());
  }
}

class VehicleThroughputSummary {
  final int totalVisits;
  final int entryCount;
  final int exitCount;
  final int completedCount;
  final int activeCount;
  final int incompleteCount;
  final int uniqueVehicles;
  final int repeatVehicles;
  final int unknownVehicleEvents;
  final double averageCompletedDwellMinutes;
  final String peakHourLabel;
  final int peakHourVisitCount;
  final int suspiciousShortVisitCount;
  final int loiteringVisitCount;

  const VehicleThroughputSummary({
    required this.totalVisits,
    required this.entryCount,
    required this.exitCount,
    required this.completedCount,
    required this.activeCount,
    required this.incompleteCount,
    required this.uniqueVehicles,
    required this.repeatVehicles,
    required this.unknownVehicleEvents,
    required this.averageCompletedDwellMinutes,
    required this.peakHourLabel,
    required this.peakHourVisitCount,
    required this.suspiciousShortVisitCount,
    required this.loiteringVisitCount,
  });
}

class VehicleVisitLedgerSnapshot {
  final List<VehicleVisitRecord> visits;
  final VehicleThroughputSummary summary;

  const VehicleVisitLedgerSnapshot({
    required this.visits,
    required this.summary,
  });
}

class VehicleVisitLedgerProjector {
  const VehicleVisitLedgerProjector();

  Map<String, VehicleVisitLedgerSnapshot> projectByScope({
    required Iterable<IntelligenceReceived> events,
    required DateTime nowUtc,
    Duration visitMergeGap = const Duration(minutes: 45),
    Duration shortVisitThreshold = const Duration(minutes: 2),
    Duration loiteringThreshold = const Duration(minutes: 30),
  }) {
    final vehicleEventsByScope = <String, List<IntelligenceReceived>>{};
    final unknownVehicleEventsByScope = <String, int>{};

    for (final event in events) {
      if (event.sourceType != 'dvr') {
        continue;
      }
      if (!_isVehicleSignal(event)) {
        continue;
      }
      final scopeKey = _scopeKey(event.clientId, event.siteId);
      final plate = _normalizePlate(event.plateNumber);
      if (plate.isEmpty) {
        unknownVehicleEventsByScope[scopeKey] =
            (unknownVehicleEventsByScope[scopeKey] ?? 0) + 1;
        continue;
      }
      vehicleEventsByScope
          .putIfAbsent(scopeKey, () => <IntelligenceReceived>[])
          .add(event);
    }

    final output = <String, VehicleVisitLedgerSnapshot>{};
    final scopeKeys = <String>{
      ...vehicleEventsByScope.keys,
      ...unknownVehicleEventsByScope.keys,
    }.toList(growable: false)..sort();

    for (final scopeKey in scopeKeys) {
      final scopedEvents =
          (vehicleEventsByScope[scopeKey] ?? const <IntelligenceReceived>[])
            ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      final visits = _buildVisits(scopedEvents, visitMergeGap);
      output[scopeKey] = VehicleVisitLedgerSnapshot(
        visits: visits,
        summary: _buildSummary(
          visits,
          nowUtc: nowUtc,
          unknownVehicleEvents: unknownVehicleEventsByScope[scopeKey] ?? 0,
          shortVisitThreshold: shortVisitThreshold,
          loiteringThreshold: loiteringThreshold,
        ),
      );
    }

    return output;
  }

  List<VehicleVisitRecord> _buildVisits(
    List<IntelligenceReceived> events,
    Duration visitMergeGap,
  ) {
    final visits = <_MutableVehicleVisit>[];
    final activeByVehicle = <String, _MutableVehicleVisit>{};

    for (final event in events) {
      final plate = _normalizePlate(event.plateNumber);
      if (plate.isEmpty) {
        continue;
      }
      final zoneStage = _classifyZoneStage(event);
      final eventAtUtc = event.occurredAt.toUtc();
      final active = activeByVehicle[plate];
      final shouldStartNew =
          active == null ||
          active.completedAtUtc != null ||
          eventAtUtc.difference(active.lastSeenAtUtc) > visitMergeGap ||
          (zoneStage == VehicleVisitZoneStage.entry && active.sawEntry);
      final visit = shouldStartNew
          ? _MutableVehicleVisit.start(
              clientId: event.clientId,
              siteId: event.siteId,
              vehicleKey: plate,
              plateNumber: plate,
              event: event,
              zoneStage: zoneStage,
            )
          : active;
      if (shouldStartNew) {
        visits.add(visit);
        activeByVehicle[plate] = visit;
      }
      if (!shouldStartNew) {
        visit.absorb(event, zoneStage);
      }
    }

    final records =
        visits.map((visit) => visit.toRecord()).toList(growable: false)
          ..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    return records;
  }

  VehicleThroughputSummary _buildSummary(
    List<VehicleVisitRecord> visits, {
    required DateTime nowUtc,
    required int unknownVehicleEvents,
    required Duration shortVisitThreshold,
    required Duration loiteringThreshold,
  }) {
    var entryCount = 0;
    var exitCount = 0;
    var completedCount = 0;
    var activeCount = 0;
    var incompleteCount = 0;
    var totalCompletedMinutes = 0.0;
    var suspiciousShortVisitCount = 0;
    var loiteringVisitCount = 0;
    final vehicleVisitCount = <String, int>{};
    final visitsByHour = <int, int>{};

    for (final visit in visits) {
      vehicleVisitCount[visit.vehicleKey] =
          (vehicleVisitCount[visit.vehicleKey] ?? 0) + 1;
      visitsByHour[visit.startedAtUtc.toUtc().hour] =
          (visitsByHour[visit.startedAtUtc.toUtc().hour] ?? 0) + 1;
      if (visit.sawEntry) {
        entryCount += 1;
      }
      if (visit.sawExit) {
        exitCount += 1;
      }
      final status = visit.statusAt(nowUtc);
      if (status == VehicleVisitStatus.completed) {
        completedCount += 1;
        totalCompletedMinutes += visit.dwell.inSeconds / 60.0;
      } else if (status == VehicleVisitStatus.active) {
        activeCount += 1;
      } else {
        incompleteCount += 1;
      }
      if (visit.statusAt(nowUtc) == VehicleVisitStatus.completed &&
          visit.dwell < shortVisitThreshold) {
        suspiciousShortVisitCount += 1;
      }
      if (visit.dwell >= loiteringThreshold) {
        loiteringVisitCount += 1;
      }
    }

    final peakHourEntry = visitsByHour.entries.fold<MapEntry<int, int>?>(null, (
      best,
      entry,
    ) {
      if (best == null || entry.value > best.value) {
        return entry;
      }
      if (entry.value == best.value && entry.key < best.key) {
        return entry;
      }
      return best;
    });
    final peakHour = peakHourEntry?.key;
    final repeatVehicles = vehicleVisitCount.values.where((count) => count > 1);

    return VehicleThroughputSummary(
      totalVisits: visits.length,
      entryCount: entryCount,
      exitCount: exitCount,
      completedCount: completedCount,
      activeCount: activeCount,
      incompleteCount: incompleteCount,
      uniqueVehicles: vehicleVisitCount.length,
      repeatVehicles: repeatVehicles.length,
      unknownVehicleEvents: unknownVehicleEvents,
      averageCompletedDwellMinutes: completedCount == 0
          ? 0
          : totalCompletedMinutes / completedCount,
      peakHourLabel: peakHour == null
          ? 'none'
          : '${peakHour.toString().padLeft(2, '0')}:00-${((peakHour + 1) % 24).toString().padLeft(2, '0')}:00',
      peakHourVisitCount: peakHourEntry?.value ?? 0,
      suspiciousShortVisitCount: suspiciousShortVisitCount,
      loiteringVisitCount: loiteringVisitCount,
    );
  }

  static bool _isVehicleSignal(IntelligenceReceived event) {
    final object = (event.objectLabel ?? '').trim().toLowerCase();
    if ((event.plateNumber ?? '').trim().isNotEmpty) {
      return true;
    }
    return object == 'vehicle' ||
        object == 'car' ||
        object == 'truck' ||
        object == 'van' ||
        object == 'suv' ||
        object == 'bakkie' ||
        object == 'bus';
  }

  static String _scopeKey(String clientId, String siteId) {
    return '${clientId.trim()}|${siteId.trim()}';
  }

  static String _normalizePlate(String? raw) {
    return (raw ?? '').trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  static VehicleVisitZoneStage _classifyZoneStage(IntelligenceReceived event) {
    final text = [
      event.zone ?? '',
      event.headline,
      event.summary,
    ].join(' ').toLowerCase();
    if (_containsAny(text, const [
      'entry',
      'ingress',
      'entrance',
      'gate in',
      'arrival lane',
      'arrivals',
      'boom in',
    ])) {
      return VehicleVisitZoneStage.entry;
    }
    if (_containsAny(text, const [
      'exit',
      'egress',
      'departure',
      'gate out',
      'exit lane',
      'boom out',
      'outbound',
    ])) {
      return VehicleVisitZoneStage.exit;
    }
    if (_containsAny(text, const [
      'wash',
      'bay',
      'service',
      'vacuum',
      'processing',
      'queue',
      'loading',
      'yard',
    ])) {
      return VehicleVisitZoneStage.service;
    }
    return VehicleVisitZoneStage.unknown;
  }

  static bool _containsAny(String text, List<String> needles) {
    for (final needle in needles) {
      if (text.contains(needle)) {
        return true;
      }
    }
    return false;
  }
}

class _MutableVehicleVisit {
  final String clientId;
  final String siteId;
  final String vehicleKey;
  final String plateNumber;
  DateTime startedAtUtc;
  DateTime lastSeenAtUtc;
  DateTime? completedAtUtc;
  bool sawEntry;
  bool sawService;
  bool sawExit;
  int eventCount;
  final List<String> intelligenceIds;
  final List<String> zoneLabels;

  _MutableVehicleVisit({
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
    required this.eventCount,
    required this.intelligenceIds,
    required this.zoneLabels,
  });

  factory _MutableVehicleVisit.start({
    required String clientId,
    required String siteId,
    required String vehicleKey,
    required String plateNumber,
    required IntelligenceReceived event,
    required VehicleVisitZoneStage zoneStage,
  }) {
    final atUtc = event.occurredAt.toUtc();
    return _MutableVehicleVisit(
      clientId: clientId,
      siteId: siteId,
      vehicleKey: vehicleKey,
      plateNumber: plateNumber,
      startedAtUtc: atUtc,
      lastSeenAtUtc: atUtc,
      completedAtUtc: zoneStage == VehicleVisitZoneStage.exit ? atUtc : null,
      sawEntry: zoneStage == VehicleVisitZoneStage.entry,
      sawService: zoneStage == VehicleVisitZoneStage.service,
      sawExit: zoneStage == VehicleVisitZoneStage.exit,
      eventCount: 1,
      intelligenceIds: <String>[event.intelligenceId],
      zoneLabels: <String>[
        if ((event.zone ?? '').trim().isNotEmpty) event.zone!.trim(),
      ],
    );
  }

  void absorb(IntelligenceReceived event, VehicleVisitZoneStage zoneStage) {
    final atUtc = event.occurredAt.toUtc();
    if (atUtc.isBefore(startedAtUtc)) {
      startedAtUtc = atUtc;
    }
    if (atUtc.isAfter(lastSeenAtUtc)) {
      lastSeenAtUtc = atUtc;
    }
    if (zoneStage == VehicleVisitZoneStage.entry) {
      sawEntry = true;
    } else if (zoneStage == VehicleVisitZoneStage.service) {
      sawService = true;
    } else if (zoneStage == VehicleVisitZoneStage.exit) {
      sawExit = true;
      completedAtUtc = atUtc;
    }
    eventCount += 1;
    intelligenceIds.add(event.intelligenceId);
    final zone = (event.zone ?? '').trim();
    if (zone.isNotEmpty && !zoneLabels.contains(zone)) {
      zoneLabels.add(zone);
    }
  }

  VehicleVisitRecord toRecord() {
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
      intelligenceIds: List<String>.unmodifiable(intelligenceIds),
      zoneLabels: List<String>.unmodifiable(zoneLabels),
    );
  }
}
