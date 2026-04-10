import 'dart:math' as math;

class OnyxPatrolRoute {
  final String id;
  final String siteId;
  final String routeName;
  final bool isActive;

  const OnyxPatrolRoute({
    required this.id,
    required this.siteId,
    required this.routeName,
    required this.isActive,
  });

  factory OnyxPatrolRoute.fromRow(Map<String, dynamic> row) {
    return OnyxPatrolRoute(
      id: _stringValue(row['id']),
      siteId: _stringValue(row['site_id']),
      routeName: _stringValue(row['route_name']),
      isActive: _boolValue(row['is_active']) ?? true,
    );
  }
}

class OnyxPatrolCheckpoint {
  final String id;
  final String routeId;
  final String siteId;
  final String checkpointName;
  final String checkpointCode;
  final int sequenceOrder;
  final bool isActive;

  const OnyxPatrolCheckpoint({
    required this.id,
    required this.routeId,
    required this.siteId,
    required this.checkpointName,
    required this.checkpointCode,
    required this.sequenceOrder,
    required this.isActive,
  });

  factory OnyxPatrolCheckpoint.fromRow(Map<String, dynamic> row) {
    return OnyxPatrolCheckpoint(
      id: _stringValue(row['id']),
      routeId: _stringValue(row['route_id']),
      siteId: _stringValue(row['site_id']),
      checkpointName: _stringValue(row['checkpoint_name']),
      checkpointCode: _stringValue(row['checkpoint_code']),
      sequenceOrder: _intValue(row['sequence_order']) ?? 0,
      isActive: _boolValue(row['is_active']) ?? true,
    );
  }
}

class OnyxGuardPatrolAssignment {
  final String id;
  final String siteId;
  final String guardId;
  final String guardName;
  final String routeId;
  final Duration shiftStartOffset;
  final Duration shiftEndOffset;
  final int patrolIntervalMinutes;
  final bool isActive;

  const OnyxGuardPatrolAssignment({
    required this.id,
    required this.siteId,
    required this.guardId,
    required this.guardName,
    required this.routeId,
    required this.shiftStartOffset,
    required this.shiftEndOffset,
    required this.patrolIntervalMinutes,
    required this.isActive,
  });

  factory OnyxGuardPatrolAssignment.fromRow(Map<String, dynamic> row) {
    return OnyxGuardPatrolAssignment(
      id: _stringValue(row['id']),
      siteId: _stringValue(row['site_id']),
      guardId: _stringValue(row['guard_id']),
      guardName: _stringValue(row['guard_name']),
      routeId: _stringValue(row['route_id']),
      shiftStartOffset: _parseSqlTimeOffset(row['shift_start']),
      shiftEndOffset: _parseSqlTimeOffset(row['shift_end']),
      patrolIntervalMinutes: (_intValue(row['patrol_interval_minutes']) ?? 60)
          .clamp(1, 24 * 60),
      isActive: _boolValue(row['is_active']) ?? true,
    );
  }

  bool get isOvernightShift => shiftEndOffset <= shiftStartOffset;
}

class OnyxPatrolScan {
  final String id;
  final String siteId;
  final String guardId;
  final String checkpointId;
  final String checkpointName;
  final DateTime scannedAtUtc;
  final double? latitude;
  final double? longitude;
  final String? note;

  const OnyxPatrolScan({
    required this.id,
    required this.siteId,
    required this.guardId,
    required this.checkpointId,
    required this.checkpointName,
    required this.scannedAtUtc,
    this.latitude,
    this.longitude,
    this.note,
  });

  factory OnyxPatrolScan.fromRow(Map<String, dynamic> row) {
    return OnyxPatrolScan(
      id: _stringValue(row['id']),
      siteId: _stringValue(row['site_id']),
      guardId: _stringValue(row['guard_id']),
      checkpointId: _stringValue(row['checkpoint_id']),
      checkpointName: _stringValue(row['checkpoint_name']),
      scannedAtUtc:
          _dateTimeValue(row['scanned_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      latitude: _doubleValue(row['lat']),
      longitude: _doubleValue(row['lon']),
      note: _nullableStringValue(row['note']),
    );
  }
}

class OnyxPatrolComplianceSnapshot {
  final String siteId;
  final String guardId;
  final String guardName;
  final String routeId;
  final DateTime windowStartLocal;
  final DateTime windowEndLocal;
  final DateTime complianceDateLocal;
  final int expectedPatrols;
  final int completedPatrols;
  final List<String> missedCheckpoints;
  final double compliancePercent;
  final DateTime? lastScanAtUtc;
  final String? lastCheckpointName;
  final bool onDuty;

  const OnyxPatrolComplianceSnapshot({
    required this.siteId,
    required this.guardId,
    required this.guardName,
    required this.routeId,
    required this.windowStartLocal,
    required this.windowEndLocal,
    required this.complianceDateLocal,
    required this.expectedPatrols,
    required this.completedPatrols,
    required this.missedCheckpoints,
    required this.compliancePercent,
    required this.lastScanAtUtc,
    required this.lastCheckpointName,
    required this.onDuty,
  });

  String get complianceDateValue {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${complianceDateLocal.year.toString().padLeft(4, '0')}-${two(complianceDateLocal.month)}-${two(complianceDateLocal.day)}';
  }
}

class OnyxMissedPatrolAlert {
  final String alertKey;
  final String siteId;
  final String guardId;
  final String guardName;
  final String? lastCheckpointName;
  final DateTime? lastScanAtUtc;
  final DateTime expectedNextPatrolByUtc;
  final DateTime currentTimeUtc;

  const OnyxMissedPatrolAlert({
    required this.alertKey,
    required this.siteId,
    required this.guardId,
    required this.guardName,
    required this.lastCheckpointName,
    required this.lastScanAtUtc,
    required this.expectedNextPatrolByUtc,
    required this.currentTimeUtc,
  });
}

class OnyxPatrolMonitorOutcome {
  final List<OnyxPatrolComplianceSnapshot> complianceSnapshots;
  final List<OnyxMissedPatrolAlert> missedAlerts;

  const OnyxPatrolMonitorOutcome({
    required this.complianceSnapshots,
    required this.missedAlerts,
  });
}

class OnyxPatrolMonitorService {
  const OnyxPatrolMonitorService();

  OnyxPatrolMonitorOutcome evaluate({
    required String siteId,
    required List<OnyxGuardPatrolAssignment> assignments,
    required List<OnyxPatrolCheckpoint> checkpoints,
    required List<OnyxPatrolScan> scans,
    required DateTime nowLocal,
  }) {
    final normalizedSiteId = siteId.trim();
    final activeAssignments = assignments
        .where(
          (assignment) =>
              assignment.isActive &&
              assignment.siteId.trim() == normalizedSiteId &&
              assignment.guardId.trim().isNotEmpty,
        )
        .toList(growable: false);
    final complianceSnapshots = <OnyxPatrolComplianceSnapshot>[];
    final missedAlerts = <OnyxMissedPatrolAlert>[];

    for (final assignment in activeAssignments) {
      final routeCheckpoints = checkpoints
          .where(
            (checkpoint) =>
                checkpoint.isActive &&
                checkpoint.siteId.trim() == normalizedSiteId &&
                checkpoint.routeId.trim() == assignment.routeId.trim(),
          )
          .toList(growable: false)
        ..sort((left, right) => left.sequenceOrder.compareTo(right.sequenceOrder));
      final guardScans = scans
          .where(
            (scan) =>
                scan.siteId.trim() == normalizedSiteId &&
                scan.guardId.trim() == assignment.guardId.trim(),
          )
          .toList(growable: false)
        ..sort((left, right) => right.scannedAtUtc.compareTo(left.scannedAtUtc));

      final shiftWindow = _resolveRelevantShiftWindow(assignment, nowLocal);
      final shiftScans = guardScans.where((scan) {
        final scanLocal = scan.scannedAtUtc.toLocal();
        return !scanLocal.isBefore(shiftWindow.startLocal) &&
            scanLocal.isBefore(shiftWindow.endLocal);
      }).toList(growable: false)
        ..sort((left, right) => right.scannedAtUtc.compareTo(left.scannedAtUtc));

      final lastScan = shiftScans.isEmpty ? null : shiftScans.first;
      final elapsed = _clampShiftElapsed(
        shiftWindow.startLocal,
        shiftWindow.endLocal,
        nowLocal,
      );
      final expectedPatrols = _expectedPatrolCount(
        elapsed,
        assignment.patrolIntervalMinutes,
        hasAnySignal: shiftScans.isNotEmpty || shiftWindow.isCurrentShift,
      );
      final completedPatrols = _completedPatrolCount(
        shiftScans,
        shiftStartLocal: shiftWindow.startLocal,
        patrolIntervalMinutes: assignment.patrolIntervalMinutes,
      );
      final missedCheckpoints = _missedCheckpointLabels(
        routeCheckpoints,
        shiftScans,
      );
      final denominator = math.max(expectedPatrols, 1);
      final compliancePercent = expectedPatrols <= 0
          ? 0.0
          : ((math.min(completedPatrols, expectedPatrols) / denominator) *
                  100.0)
              .toDouble();

      complianceSnapshots.add(
        OnyxPatrolComplianceSnapshot(
          siteId: normalizedSiteId,
          guardId: assignment.guardId,
          guardName: assignment.guardName,
          routeId: assignment.routeId,
          windowStartLocal: shiftWindow.startLocal,
          windowEndLocal: shiftWindow.endLocal,
          complianceDateLocal: DateTime(
            nowLocal.year,
            nowLocal.month,
            nowLocal.day,
          ),
          expectedPatrols: expectedPatrols,
          completedPatrols: completedPatrols,
          missedCheckpoints: missedCheckpoints,
          compliancePercent: compliancePercent,
          lastScanAtUtc: lastScan?.scannedAtUtc,
          lastCheckpointName: lastScan?.checkpointName,
          onDuty: shiftWindow.isCurrentShift,
        ),
      );

      if (!shiftWindow.isCurrentShift) {
        continue;
      }
      final nextDueLocal = (lastScan?.scannedAtUtc.toLocal() ??
              shiftWindow.startLocal)
          .add(Duration(minutes: assignment.patrolIntervalMinutes));
      if (!nowLocal.isAfter(nextDueLocal)) {
        continue;
      }
      missedAlerts.add(
        OnyxMissedPatrolAlert(
          alertKey:
              '${assignment.id}:${nextDueLocal.toUtc().toIso8601String()}',
          siteId: normalizedSiteId,
          guardId: assignment.guardId,
          guardName: assignment.guardName,
          lastCheckpointName: lastScan?.checkpointName,
          lastScanAtUtc: lastScan?.scannedAtUtc,
          expectedNextPatrolByUtc: nextDueLocal.toUtc(),
          currentTimeUtc: nowLocal.toUtc(),
        ),
      );
    }

    return OnyxPatrolMonitorOutcome(
      complianceSnapshots: List<OnyxPatrolComplianceSnapshot>.unmodifiable(
        complianceSnapshots,
      ),
      missedAlerts:
          List<OnyxMissedPatrolAlert>.unmodifiable(missedAlerts),
    );
  }

  _ShiftWindow _resolveRelevantShiftWindow(
    OnyxGuardPatrolAssignment assignment,
    DateTime nowLocal,
  ) {
    final todayStart = _dateWithOffset(nowLocal, assignment.shiftStartOffset);
    final todayEnd = _dateWithOffset(nowLocal, assignment.shiftEndOffset);
    final overnight = assignment.isOvernightShift;
    final candidateWindows = <_ShiftWindow>[
      _buildShiftWindow(
        startLocal: todayStart,
        endLocal: todayEnd,
        overnight: overnight,
        nowLocal: nowLocal,
      ),
      _buildShiftWindow(
        startLocal: todayStart.subtract(const Duration(days: 1)),
        endLocal: todayEnd.subtract(const Duration(days: 1)),
        overnight: overnight,
        nowLocal: nowLocal,
      ),
    ];
    for (final candidate in candidateWindows) {
      if (candidate.isCurrentShift) {
        return candidate;
      }
    }
    candidateWindows.sort((left, right) => right.endLocal.compareTo(left.endLocal));
    for (final candidate in candidateWindows) {
      if (!candidate.endLocal.isAfter(nowLocal)) {
        return candidate;
      }
    }
    return candidateWindows.first;
  }

  _ShiftWindow _buildShiftWindow({
    required DateTime startLocal,
    required DateTime endLocal,
    required bool overnight,
    required DateTime nowLocal,
  }) {
    final normalizedEnd = overnight ? endLocal.add(const Duration(days: 1)) : endLocal;
    final isCurrentShift =
        !nowLocal.isBefore(startLocal) && nowLocal.isBefore(normalizedEnd);
    return _ShiftWindow(
      startLocal: startLocal,
      endLocal: normalizedEnd,
      isCurrentShift: isCurrentShift,
    );
  }

  DateTime _dateWithOffset(DateTime referenceLocal, Duration offset) {
    final hours = offset.inHours;
    final minutes = offset.inMinutes.remainder(60);
    final seconds = offset.inSeconds.remainder(60);
    return DateTime(
      referenceLocal.year,
      referenceLocal.month,
      referenceLocal.day,
      hours,
      minutes,
      seconds,
    );
  }

  Duration _clampShiftElapsed(
    DateTime shiftStartLocal,
    DateTime shiftEndLocal,
    DateTime nowLocal,
  ) {
    if (nowLocal.isBefore(shiftStartLocal)) {
      return Duration.zero;
    }
    final effectiveNow = nowLocal.isAfter(shiftEndLocal) ? shiftEndLocal : nowLocal;
    return effectiveNow.difference(shiftStartLocal);
  }

  int _expectedPatrolCount(
    Duration elapsed,
    int patrolIntervalMinutes, {
    required bool hasAnySignal,
  }) {
    if (patrolIntervalMinutes <= 0) {
      return 0;
    }
    if (elapsed <= Duration.zero) {
      return hasAnySignal ? 1 : 0;
    }
    return math.max(1, (elapsed.inMinutes / patrolIntervalMinutes).ceil());
  }

  int _completedPatrolCount(
    List<OnyxPatrolScan> scans, {
    required DateTime shiftStartLocal,
    required int patrolIntervalMinutes,
  }) {
    if (scans.isEmpty || patrolIntervalMinutes <= 0) {
      return 0;
    }
    final buckets = <int>{};
    for (final scan in scans) {
      final elapsedMinutes =
          scan.scannedAtUtc.toLocal().difference(shiftStartLocal).inMinutes;
      if (elapsedMinutes < 0) {
        continue;
      }
      buckets.add(elapsedMinutes ~/ patrolIntervalMinutes);
    }
    return buckets.length;
  }

  List<String> _missedCheckpointLabels(
    List<OnyxPatrolCheckpoint> checkpoints,
    List<OnyxPatrolScan> scans,
  ) {
    if (checkpoints.isEmpty) {
      return const <String>[];
    }
    final scannedCheckpointIds = scans
        .map((scan) => scan.checkpointId.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    return checkpoints
        .where((checkpoint) => !scannedCheckpointIds.contains(checkpoint.id.trim()))
        .map((checkpoint) => checkpoint.checkpointName)
        .toList(growable: false);
  }
}

class _ShiftWindow {
  final DateTime startLocal;
  final DateTime endLocal;
  final bool isCurrentShift;

  const _ShiftWindow({
    required this.startLocal,
    required this.endLocal,
    required this.isCurrentShift,
  });
}

String _stringValue(Object? value) => value?.toString().trim() ?? '';

String? _nullableStringValue(Object? value) {
  final trimmed = value?.toString().trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

double? _doubleValue(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}

bool? _boolValue(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    if (value == 1) {
      return true;
    }
    if (value == 0) {
      return false;
    }
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return null;
}

DateTime? _dateTimeValue(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value.trim())?.toUtc();
}

Duration _parseSqlTimeOffset(Object? value) {
  final raw = value?.toString().trim() ?? '';
  final parts = raw.split(':');
  if (parts.length < 2) {
    return Duration.zero;
  }
  final hours = int.tryParse(parts[0]) ?? 0;
  final minutes = int.tryParse(parts[1]) ?? 0;
  final seconds = parts.length >= 3 ? (int.tryParse(parts[2]) ?? 0) : 0;
  return Duration(hours: hours, minutes: minutes, seconds: seconds);
}
