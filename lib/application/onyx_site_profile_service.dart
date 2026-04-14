import 'dart:math' as math;

import 'onyx_fr_service.dart';
import 'onyx_proactive_alert_service.dart';

enum AlertLevel { info, warning, critical }

class AlertThresholds {
  final AlertLevel duringHoursLevel;
  final AlertLevel afterHoursLevel;
  final bool monitorVehiclesAfterHours;
  final bool monitorRestrictedZones;

  const AlertThresholds({
    required this.duringHoursLevel,
    required this.afterHoursLevel,
    required this.monitorVehiclesAfterHours,
    required this.monitorRestrictedZones,
  });
}

class AlertDecision {
  final bool shouldAlert;
  final AlertLevel alertLevel;
  final String reason;
  final String? suggestedAction;
  final String? contextNote;
  final bool afterHours;

  const AlertDecision({
    required this.shouldAlert,
    required this.alertLevel,
    required this.reason,
    this.suggestedAction,
    this.contextNote,
    required this.afterHours,
  });

  factory AlertDecision.noAlert({
    required String reason,
    required bool afterHours,
  }) {
    return AlertDecision(
      shouldAlert: false,
      alertLevel: AlertLevel.info,
      reason: reason,
      afterHours: afterHours,
    );
  }
}

class DetectionEvent {
  final String siteId;
  final int channelId;
  final String zoneName;
  final String zoneType;
  final bool isPerimeter;
  final bool isIndoor;
  final OnyxProactiveDetectionKind detectionKind;
  final DateTime detectedAtUtc;
  final bool isLoitering;
  final bool isPerimeterSequence;
  final int observedDistinctPresenceCount;
  final bool frEvaluated;
  final OnyxFrMatchContext? frMatch;
  final bool unknownHuman;

  const DetectionEvent({
    required this.siteId,
    required this.channelId,
    required this.zoneName,
    required this.zoneType,
    required this.isPerimeter,
    required this.isIndoor,
    required this.detectionKind,
    required this.detectedAtUtc,
    required this.isLoitering,
    required this.isPerimeterSequence,
    required this.observedDistinctPresenceCount,
    this.frEvaluated = false,
    this.frMatch,
    this.unknownHuman = false,
  });
}

class SiteExpectedVisitor {
  final String siteId;
  final String visitorName;
  final String visitorRole;
  final String visitType;
  final List<String> visitDays;
  final String? visitStart;
  final String? visitEnd;
  final bool isActive;
  final String? notes;
  final DateTime? visitDate;
  final DateTime? expiresAtUtc;

  const SiteExpectedVisitor({
    required this.siteId,
    required this.visitorName,
    required this.visitorRole,
    required this.visitType,
    required this.visitDays,
    required this.visitStart,
    required this.visitEnd,
    required this.isActive,
    required this.notes,
    required this.visitDate,
    required this.expiresAtUtc,
  });

  factory SiteExpectedVisitor.fromRow(Map<String, dynamic> row) {
    return SiteExpectedVisitor(
      siteId: _profileString(row['site_id']),
      visitorName: _profileString(row['visitor_name']),
      visitorRole: (_nullableProfileString(row['visitor_role']) ?? 'visitor')
          .toLowerCase(),
      visitType: (_nullableProfileString(row['visit_type']) ?? 'scheduled')
          .toLowerCase(),
      visitDays: _stringList(row['visit_days']),
      visitStart: _nullableProfileString(row['visit_start']),
      visitEnd: _nullableProfileString(row['visit_end']),
      isActive: _profileBool(row['is_active']) ?? true,
      notes: _nullableProfileString(row['notes']),
      visitDate: _profileDate(row['visit_date']),
      expiresAtUtc: _profileDateTimeUtc(row['expires_at']),
    );
  }

  String get displayName {
    if (visitorName.trim().isNotEmpty) {
      return visitorName.trim();
    }
    return switch (visitorRole.trim().toLowerCase()) {
      'cleaner' => 'Cleaner',
      'gardener' => 'Gardener',
      'contractor' => 'Contractor',
      'delivery' => 'Delivery',
      'regular_visitor' => 'Visitor',
      _ => 'Visitor',
    };
  }

  bool isExpectedAt({
    required DateTime observedAtUtc,
    required String timezone,
  }) {
    if (!isActive) {
      return false;
    }
    final observedUtc = observedAtUtc.toUtc();
    if (expiresAtUtc != null && observedUtc.isAfter(expiresAtUtc!)) {
      return false;
    }
    final local = _profileLocalTime(timezone, observedUtc);
    if (visitType == 'on_demand' && visitDate == null) {
      return false;
    }
    if (visitDate != null) {
      if (local.year != visitDate!.year ||
          local.month != visitDate!.month ||
          local.day != visitDate!.day) {
        return false;
      }
    } else if (visitDays.isNotEmpty &&
        !visitDays.contains(_weekdayLabel(local.weekday))) {
      return false;
    }
    final start = visitStart == null ? null : _parseClock(visitStart!);
    final end = visitEnd == null ? null : _parseClock(visitEnd!);
    if (start == null || end == null) {
      return true;
    }
    final nowMinutes = local.hour * 60 + local.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    if (startMinutes == endMinutes) {
      return true;
    }
    if (startMinutes < endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    }
    return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
  }
}

class SiteSnapshot {
  final String siteId;
  final String siteName;
  final DateTime observedAtUtc;
  final bool perimeterClear;
  final int onSiteCount;
  final int expectedPeopleCount;
  final int vehicleCount;
  final int activeIncidents;
  final List<String> offlineChannels;
  final bool fresh;
  final int activeAlerts;

  const SiteSnapshot({
    required this.siteId,
    required this.siteName,
    required this.observedAtUtc,
    required this.perimeterClear,
    required this.onSiteCount,
    required this.expectedPeopleCount,
    required this.vehicleCount,
    required this.activeIncidents,
    required this.offlineChannels,
    required this.fresh,
    required this.activeAlerts,
  });
}

class SiteZoneRule {
  final String siteId;
  final String zoneName;
  final String zoneType;
  final List<String> allowedRoles;
  final String? accessHoursStart;
  final String? accessHoursEnd;
  final List<String> accessDays;
  final String violationAction;
  final int? maxDwellMinutes;
  final bool requiresEscort;
  final bool isRestricted;

  const SiteZoneRule({
    required this.siteId,
    required this.zoneName,
    required this.zoneType,
    required this.allowedRoles,
    required this.accessHoursStart,
    required this.accessHoursEnd,
    required this.accessDays,
    required this.violationAction,
    required this.maxDwellMinutes,
    required this.requiresEscort,
    required this.isRestricted,
  });

  factory SiteZoneRule.fromRow(Map<String, dynamic> row) {
    return SiteZoneRule(
      siteId: _profileString(row['site_id']),
      zoneName: _profileString(row['zone_name']),
      zoneType: _normalizedZoneType(_profileString(row['zone_type'])),
      allowedRoles: _stringList(row['allowed_roles']),
      accessHoursStart: _nullableProfileString(row['access_hours_start']),
      accessHoursEnd: _nullableProfileString(row['access_hours_end']),
      accessDays: _stringList(row['access_days']),
      violationAction:
          (_nullableProfileString(row['violation_action']) ?? 'alert')
              .toLowerCase(),
      maxDwellMinutes: _profileInt(row['max_dwell_minutes']),
      requiresEscort: _profileBool(row['requires_escort']) ?? false,
      isRestricted: _profileBool(row['is_restricted']) ?? false,
    );
  }
}

class SiteIntelligenceProfile {
  final String siteId;
  final String industryType;
  final String operatingHoursStart;
  final String operatingHoursEnd;
  final List<String> operatingDays;
  final String timezone;
  final bool is24hOperation;
  final int expectedStaffCount;
  final int expectedResidentCount;
  final int expectedVehicleCount;
  final bool hasGuard;
  final bool hasArmedResponse;
  final String afterHoursSensitivity;
  final String duringHoursSensitivity;
  final bool monitorStaffActivity;
  final int inactiveStaffAlertMinutes;
  final bool monitorTillAttendance;
  final int tillUnattendedMinutes;
  final bool monitorRestrictedZones;
  final bool monitorVehicleMovement;
  final bool afterHoursVehicleAlert;
  final bool sendShiftStartBriefing;
  final bool sendShiftEndReport;
  final bool sendDailySummary;
  final String dailySummaryTime;
  final bool alertWithSnapshot;
  final bool alertWithButtons;
  final String responseMode;
  final List<Map<String, dynamic>> customRules;

  const SiteIntelligenceProfile({
    required this.siteId,
    required this.industryType,
    required this.operatingHoursStart,
    required this.operatingHoursEnd,
    required this.operatingDays,
    required this.timezone,
    required this.is24hOperation,
    required this.expectedStaffCount,
    required this.expectedResidentCount,
    required this.expectedVehicleCount,
    required this.hasGuard,
    required this.hasArmedResponse,
    required this.afterHoursSensitivity,
    required this.duringHoursSensitivity,
    required this.monitorStaffActivity,
    required this.inactiveStaffAlertMinutes,
    required this.monitorTillAttendance,
    required this.tillUnattendedMinutes,
    required this.monitorRestrictedZones,
    required this.monitorVehicleMovement,
    required this.afterHoursVehicleAlert,
    required this.sendShiftStartBriefing,
    required this.sendShiftEndReport,
    required this.sendDailySummary,
    required this.dailySummaryTime,
    required this.alertWithSnapshot,
    required this.alertWithButtons,
    required this.responseMode,
    required this.customRules,
  });

  factory SiteIntelligenceProfile.fromRow(Map<String, dynamic> row) {
    return SiteIntelligenceProfile(
      siteId: _profileString(row['site_id']),
      industryType:
          (_nullableProfileString(row['industry_type']) ?? 'residential')
              .toLowerCase(),
      operatingHoursStart:
          _nullableProfileString(row['operating_hours_start']) ?? '08:00',
      operatingHoursEnd:
          _nullableProfileString(row['operating_hours_end']) ?? '18:00',
      operatingDays: _stringList(row['operating_days']),
      timezone:
          _nullableProfileString(row['timezone']) ?? 'Africa/Johannesburg',
      is24hOperation: _profileBool(row['is_24h_operation']) ?? false,
      expectedStaffCount: _profileInt(row['expected_staff_count']) ?? 0,
      expectedResidentCount: _profileInt(row['expected_resident_count']) ?? 0,
      expectedVehicleCount: _profileInt(row['expected_vehicle_count']) ?? 0,
      hasGuard: _profileBool(row['has_guard']) ?? false,
      hasArmedResponse: _profileBool(row['has_armed_response']) ?? false,
      afterHoursSensitivity:
          (_nullableProfileString(row['after_hours_sensitivity']) ?? 'high')
              .toLowerCase(),
      duringHoursSensitivity:
          (_nullableProfileString(row['during_hours_sensitivity']) ?? 'medium')
              .toLowerCase(),
      monitorStaffActivity:
          _profileBool(row['monitor_staff_activity']) ?? false,
      inactiveStaffAlertMinutes:
          _profileInt(row['inactive_staff_alert_minutes']) ?? 30,
      monitorTillAttendance:
          _profileBool(row['monitor_till_attendance']) ?? false,
      tillUnattendedMinutes: _profileInt(row['till_unattended_minutes']) ?? 5,
      monitorRestrictedZones:
          _profileBool(row['monitor_restricted_zones']) ?? false,
      monitorVehicleMovement:
          _profileBool(row['monitor_vehicle_movement']) ?? true,
      afterHoursVehicleAlert:
          _profileBool(row['after_hours_vehicle_alert']) ?? true,
      sendShiftStartBriefing:
          _profileBool(row['send_shift_start_briefing']) ?? true,
      sendShiftEndReport: _profileBool(row['send_shift_end_report']) ?? true,
      sendDailySummary: _profileBool(row['send_daily_summary']) ?? true,
      dailySummaryTime:
          _nullableProfileString(row['daily_summary_time']) ?? '07:00',
      alertWithSnapshot: _profileBool(row['alert_with_snapshot']) ?? true,
      alertWithButtons: _profileBool(row['alert_with_buttons']) ?? true,
      responseMode: (_nullableProfileString(row['response_mode']) ?? 'passive')
          .toLowerCase(),
      customRules: _jsonRuleList(row['custom_rules']),
    );
  }

  factory SiteIntelligenceProfile.defaults(String siteId) {
    return SiteIntelligenceProfile(
      siteId: siteId.trim(),
      industryType: 'residential',
      operatingHoursStart: '08:00',
      operatingHoursEnd: '18:00',
      operatingDays: const <String>[
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
      ],
      timezone: 'Africa/Johannesburg',
      is24hOperation: false,
      expectedStaffCount: 0,
      expectedResidentCount: 0,
      expectedVehicleCount: 0,
      hasGuard: false,
      hasArmedResponse: false,
      afterHoursSensitivity: 'high',
      duringHoursSensitivity: 'medium',
      monitorStaffActivity: false,
      inactiveStaffAlertMinutes: 30,
      monitorTillAttendance: false,
      tillUnattendedMinutes: 5,
      monitorRestrictedZones: false,
      monitorVehicleMovement: true,
      afterHoursVehicleAlert: true,
      sendShiftStartBriefing: true,
      sendShiftEndReport: true,
      sendDailySummary: true,
      dailySummaryTime: '07:00',
      alertWithSnapshot: true,
      alertWithButtons: true,
      responseMode: 'passive',
      customRules: const <Map<String, dynamic>>[],
    );
  }

  int get expectedPeopleCount {
    return switch (industryType) {
      'residential' => expectedResidentCount,
      _ => expectedStaffCount,
    };
  }

  String get peopleLabel {
    return switch (industryType) {
      'residential' => expectedResidentCount == 1 ? 'resident' : 'residents',
      'retail' => expectedStaffCount == 1 ? 'staff member' : 'staff',
      'warehouse' => expectedStaffCount == 1 ? 'staff member' : 'staff',
      'office' => expectedStaffCount == 1 ? 'staff member' : 'staff',
      'school' => 'people',
      'hospital' => 'staff',
      'construction' => 'crew',
      'farm' => 'workers',
      _ => 'people',
    };
  }
}

typedef SiteProfileRowReader =
    Future<Map<String, dynamic>?> Function(String siteId);
typedef SiteZoneRuleRowsReader =
    Future<List<Map<String, dynamic>>> Function(String siteId);
typedef SiteExpectedVisitorRowsReader =
    Future<List<Map<String, dynamic>>> Function(String siteId);

class OnyxSiteProfileService {
  final SiteProfileRowReader? readProfileRow;
  final SiteZoneRuleRowsReader? readZoneRuleRows;
  final SiteExpectedVisitorRowsReader? readExpectedVisitorRows;

  const OnyxSiteProfileService({
    this.readProfileRow,
    this.readZoneRuleRows,
    this.readExpectedVisitorRows,
  });

  Future<SiteIntelligenceProfile> loadProfile(String siteId) async {
    final normalizedSiteId = siteId.trim();
    if (normalizedSiteId.isEmpty) {
      return SiteIntelligenceProfile.defaults(siteId);
    }
    final row = await readProfileRow?.call(normalizedSiteId);
    if (row == null || row.isEmpty) {
      return SiteIntelligenceProfile.defaults(normalizedSiteId);
    }
    return SiteIntelligenceProfile.fromRow(row);
  }

  Future<List<SiteZoneRule>> loadZoneRules(String siteId) async {
    final normalizedSiteId = siteId.trim();
    if (normalizedSiteId.isEmpty) {
      return const <SiteZoneRule>[];
    }
    final rows =
        await readZoneRuleRows?.call(normalizedSiteId) ??
        const <Map<String, dynamic>>[];
    return rows.map(SiteZoneRule.fromRow).toList(growable: false);
  }

  Future<List<SiteExpectedVisitor>> loadExpectedVisitors(String siteId) async {
    final normalizedSiteId = siteId.trim();
    if (normalizedSiteId.isEmpty) {
      return const <SiteExpectedVisitor>[];
    }
    final rows =
        await readExpectedVisitorRows?.call(normalizedSiteId) ??
        const <Map<String, dynamic>>[];
    return rows.map(SiteExpectedVisitor.fromRow).toList(growable: false);
  }

  Future<List<SiteExpectedVisitor>> loadActiveExpectedVisitors({
    required String siteId,
    required String timezone,
    required DateTime atUtc,
  }) async {
    final visitors = await loadExpectedVisitors(siteId);
    return visitors
        .where(
          (visitor) => visitor.isExpectedAt(
            observedAtUtc: atUtc.toUtc(),
            timezone: timezone,
          ),
        )
        .toList(growable: false);
  }

  AlertThresholds getAlertThresholds(SiteIntelligenceProfile profile) {
    return AlertThresholds(
      duringHoursLevel: _alertLevelForSensitivity(
        profile.duringHoursSensitivity,
      ),
      afterHoursLevel: _alertLevelForSensitivity(profile.afterHoursSensitivity),
      monitorVehiclesAfterHours: profile.afterHoursVehicleAlert,
      monitorRestrictedZones: profile.monitorRestrictedZones,
    );
  }

  bool isAfterHours({
    required SiteIntelligenceProfile profile,
    required DateTime observedAtUtc,
  }) {
    return !_isWithinOperatingSchedule(profile, observedAtUtc.toUtc());
  }

  Future<AlertDecision> evaluateDetection({
    required String siteId,
    required DetectionEvent event,
    required SiteIntelligenceProfile profile,
  }) async {
    final afterHours = !_isWithinOperatingSchedule(
      profile,
      event.detectedAtUtc,
    );
    final thresholds = getAlertThresholds(profile);
    final zoneRules = await loadZoneRules(siteId);
    final matchingRule = _matchZoneRule(zoneRules, event);
    final activeExpectedVisitors = await loadActiveExpectedVisitors(
      siteId: siteId,
      timezone: profile.timezone,
      atUtc: event.detectedAtUtc,
    );
    final expectedVisitorNote = activeExpectedVisitors.isEmpty
        ? null
        : 'Note: Expected visitor '
              '(${_expectedVisitorLabel(activeExpectedVisitors)}) '
              'on site during these hours.';

    if (event.unknownHuman &&
        event.detectionKind == OnyxProactiveDetectionKind.human) {
      return AlertDecision(
        shouldAlert: true,
        alertLevel: afterHours || event.isPerimeter
            ? AlertLevel.critical
            : AlertLevel.warning,
        reason: 'Unknown person detected with no face match.',
        suggestedAction: profile.hasArmedResponse
            ? 'Review live cameras and verify whether response is needed.'
            : 'Review live cameras and notify the client.',
        contextNote: !afterHours ? expectedVisitorNote : null,
        afterHours: afterHours,
      );
    }

    if (event.isIndoor && profile.industryType == 'residential') {
      return AlertDecision.noAlert(
        reason: 'Indoor residential activity is expected.',
        afterHours: afterHours,
      );
    }

    if (matchingRule != null && matchingRule.isRestricted) {
      final violation = _isZoneAccessViolation(
        rule: matchingRule,
        profile: profile,
        detectedAtUtc: event.detectedAtUtc,
      );
      if (violation) {
        return AlertDecision(
          shouldAlert: true,
          alertLevel: matchingRule.violationAction == 'dispatch'
              ? AlertLevel.critical
              : AlertLevel.warning,
          reason: '${event.zoneName} is a restricted zone.',
          suggestedAction: _suggestedActionForViolation(matchingRule),
          afterHours: afterHours,
        );
      }
    }

    if (event.frEvaluated) {
      final frMatch = event.frMatch;
      if (frMatch != null && frMatch.person.role.toLowerCase() == 'resident') {
        return AlertDecision.noAlert(
          reason: 'Recognized resident detected on site.',
          afterHours: afterHours,
        );
      }
      if (frMatch != null && frMatch.isExpectedNow) {
        return AlertDecision.noAlert(
          reason:
              'Recognized ${frMatch.person.role} is scheduled to be on site.',
          afterHours: afterHours,
        );
      }
      if (frMatch != null && !frMatch.isExpectedNow) {
        return AlertDecision(
          shouldAlert: true,
          alertLevel: AlertLevel.info,
          reason:
              'Recognized ${frMatch.person.role} detected outside expected hours.',
          suggestedAction: 'Verify whether this visit is expected.',
          afterHours: afterHours,
        );
      }
      if (frMatch == null &&
          event.detectionKind == OnyxProactiveDetectionKind.human &&
          event.isIndoor) {
        return AlertDecision.noAlert(
          reason: 'Unknown indoor person noted for review only.',
          afterHours: afterHours,
        );
      }
      if (frMatch == null &&
          event.detectionKind == OnyxProactiveDetectionKind.human &&
          afterHours &&
          event.isPerimeter) {
        return AlertDecision(
          shouldAlert: true,
          alertLevel: AlertLevel.critical,
          reason: 'Unknown person detected on the perimeter after hours.',
          suggestedAction: profile.hasArmedResponse
              ? 'Escalate for response verification.'
              : 'Review live cameras and contact the client.',
          afterHours: afterHours,
        );
      }
    }

    if (event.detectionKind == OnyxProactiveDetectionKind.vehicle &&
        !profile.monitorVehicleMovement) {
      return AlertDecision.noAlert(
        reason: 'Vehicle movement monitoring is disabled for this site.',
        afterHours: afterHours,
      );
    }

    if (profile.industryType == 'residential' &&
        !afterHours &&
        activeExpectedVisitors.isNotEmpty) {
      if (event.zoneType == 'semi_perimeter' || event.isIndoor) {
        return AlertDecision.noAlert(
          reason: 'Expected visitor is scheduled on site during daytime hours.',
          afterHours: afterHours,
        );
      }
      if (event.zoneType == 'perimeter' &&
          !_isStreetFacingPerimeterZone(event.zoneName)) {
        return AlertDecision.noAlert(
          reason: 'Expected visitor is scheduled on site during daytime hours.',
          afterHours: afterHours,
        );
      }
      if (event.zoneType == 'perimeter' &&
          _isStreetFacingPerimeterZone(event.zoneName)) {
        return AlertDecision(
          shouldAlert: true,
          alertLevel: AlertLevel.warning,
          reason:
              'Street-facing perimeter movement detected while an expected visitor is on site.',
          contextNote: expectedVisitorNote,
          afterHours: afterHours,
        );
      }
    }

    if (profile.industryType == 'residential' && !afterHours) {
      final withinExpectedRange =
          event.observedDistinctPresenceCount <=
          math.max(profile.expectedResidentCount, 1);
      if (event.detectionKind == OnyxProactiveDetectionKind.vehicle) {
        return AlertDecision.noAlert(
          reason: 'Daytime residential vehicle movement is normal.',
          afterHours: afterHours,
        );
      }
      if (withinExpectedRange &&
          !event.isLoitering &&
          !event.isPerimeterSequence) {
        return AlertDecision.noAlert(
          reason: 'Daytime residential movement is within expected occupancy.',
          afterHours: afterHours,
        );
      }
    }

    if (event.zoneType == 'semi_perimeter' &&
        !afterHours &&
        !event.isLoitering &&
        !event.isPerimeterSequence) {
      return AlertDecision.noAlert(
        reason:
            'Single semi-perimeter pass during operating hours is not suspicious.',
        afterHours: afterHours,
      );
    }

    if (event.zoneType == 'perimeter' &&
        !afterHours &&
        !event.isLoitering &&
        !event.isPerimeterSequence &&
        profile.duringHoursSensitivity != 'high' &&
        profile.duringHoursSensitivity != 'critical') {
      return AlertDecision.noAlert(
        reason:
            'Single perimeter pass during operating hours does not meet threshold.',
        afterHours: afterHours,
      );
    }

    if (event.detectionKind == OnyxProactiveDetectionKind.vehicle &&
        afterHours &&
        !thresholds.monitorVehiclesAfterHours) {
      return AlertDecision.noAlert(
        reason: 'After-hours vehicle alerts are disabled.',
        afterHours: afterHours,
      );
    }

    final sensitivityLevel = afterHours
        ? thresholds.afterHoursLevel
        : thresholds.duringHoursLevel;
    final suspicious = event.isLoitering || event.isPerimeterSequence;
    final shouldAlert = switch (sensitivityLevel) {
      AlertLevel.critical => true,
      AlertLevel.warning => afterHours || suspicious,
      AlertLevel.info => suspicious,
    };
    if (!shouldAlert) {
      return AlertDecision.noAlert(
        reason: 'Detection stayed below the configured threshold.',
        afterHours: afterHours,
      );
    }
    return AlertDecision(
      shouldAlert: true,
      alertLevel: sensitivityLevel,
      reason: _reasonForDetection(profile, event, afterHours),
      suggestedAction: _suggestedActionForProfile(profile, event, afterHours),
      contextNote: !afterHours ? expectedVisitorNote : null,
      afterHours: afterHours,
    );
  }

  String formatStatusMessage({
    required SiteIntelligenceProfile profile,
    required SiteSnapshot snapshot,
  }) {
    final perimeterLine = snapshot.perimeterClear
        ? 'Perimeter clear.'
        : 'Perimeter alert active.';
    final incidentLine = snapshot.activeIncidents <= 0
        ? 'No active incidents.'
        : '${snapshot.activeIncidents} active incident${snapshot.activeIncidents == 1 ? '' : 's'}.';
    switch (profile.industryType) {
      case 'residential':
        if (snapshot.onSiteCount <= 0) {
          return 'No movement detected on site. $perimeterLine';
        }
        final peopleLabel = snapshot.onSiteCount == 1 ? 'person' : 'people';
        return 'Movement detected — ${snapshot.onSiteCount} $peopleLabel on site (identity unconfirmed). $perimeterLine';
      case 'retail':
        final tillLine = profile.monitorTillAttendance
            ? 'Till attendance monitored.'
            : 'No till issues detected.';
        return '${snapshot.onSiteCount} staff on site. $tillLine $incidentLine';
      case 'warehouse':
        final guardLine = profile.hasGuard
            ? 'Guard coverage active.'
            : 'No guard assigned.';
        return '${snapshot.onSiteCount} staff in monitored zones. Loading areas clear. $guardLine';
      case 'office':
        final receptionLine =
            _isWithinOperatingSchedule(profile, snapshot.observedAtUtc)
            ? 'Reception active.'
            : 'Reception closed.';
        final vehicleLine = snapshot.vehicleCount > 0
            ? '${snapshot.vehicleCount} vehicle${snapshot.vehicleCount == 1 ? '' : 's'} recorded.'
            : 'No vehicle issues.';
        return '$vehicleLine $receptionLine $perimeterLine';
      default:
        return '${snapshot.onSiteCount} ${profile.peopleLabel} on site. $perimeterLine $incidentLine';
    }
  }

  bool _isWithinOperatingSchedule(
    SiteIntelligenceProfile profile,
    DateTime detectedAtUtc,
  ) {
    if (profile.is24hOperation) {
      return true;
    }
    final local = _profileLocalTime(profile.timezone, detectedAtUtc.toUtc());
    final weekday = _weekdayLabel(local.weekday);
    if (profile.operatingDays.isNotEmpty &&
        !profile.operatingDays.contains(weekday)) {
      return false;
    }
    final start = _parseClock(profile.operatingHoursStart);
    final end = _parseClock(profile.operatingHoursEnd);
    if (start == null || end == null) {
      return true;
    }
    final nowMinutes = local.hour * 60 + local.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    if (startMinutes == endMinutes) {
      return true;
    }
    if (startMinutes < endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    }
    return nowMinutes >= startMinutes || nowMinutes < endMinutes;
  }

  SiteZoneRule? _matchZoneRule(List<SiteZoneRule> rules, DetectionEvent event) {
    for (final rule in rules) {
      if (rule.zoneName.trim().toLowerCase() ==
          event.zoneName.trim().toLowerCase()) {
        return rule;
      }
    }
    for (final rule in rules) {
      if (rule.zoneType == event.zoneType) {
        return rule;
      }
    }
    return null;
  }

  bool _isZoneAccessViolation({
    required SiteZoneRule rule,
    required SiteIntelligenceProfile profile,
    required DateTime detectedAtUtc,
  }) {
    if (!rule.isRestricted) {
      return false;
    }
    if (rule.accessHoursStart == null || rule.accessHoursEnd == null) {
      return true;
    }
    final local = _profileLocalTime(profile.timezone, detectedAtUtc);
    final weekday = _weekdayLabel(local.weekday);
    if (rule.accessDays.isNotEmpty && !rule.accessDays.contains(weekday)) {
      return true;
    }
    final start = _parseClock(rule.accessHoursStart!);
    final end = _parseClock(rule.accessHoursEnd!);
    if (start == null || end == null) {
      return true;
    }
    final nowMinutes = local.hour * 60 + local.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    if (startMinutes < endMinutes) {
      return nowMinutes < startMinutes || nowMinutes >= endMinutes;
    }
    return nowMinutes < startMinutes && nowMinutes >= endMinutes;
  }

  AlertLevel _alertLevelForSensitivity(String sensitivity) {
    return switch (sensitivity.trim().toLowerCase()) {
      'critical' => AlertLevel.critical,
      'high' => AlertLevel.critical,
      'medium' => AlertLevel.warning,
      'low' => AlertLevel.info,
      'off' => AlertLevel.info,
      _ => AlertLevel.warning,
    };
  }

  String _reasonForDetection(
    SiteIntelligenceProfile profile,
    DetectionEvent event,
    bool afterHours,
  ) {
    final subject = event.detectionKind == OnyxProactiveDetectionKind.vehicle
        ? 'Vehicle'
        : 'Movement';
    if (afterHours) {
      return '$subject detected after normal operating hours at ${event.zoneName}.';
    }
    if (event.isPerimeterSequence) {
      return 'Movement detected across multiple monitored perimeter points.';
    }
    if (event.isLoitering) {
      return 'Sustained presence detected at ${event.zoneName}.';
    }
    return '$subject detected at ${event.zoneName}.';
  }

  String? _suggestedActionForProfile(
    SiteIntelligenceProfile profile,
    DetectionEvent event,
    bool afterHours,
  ) {
    if (profile.hasArmedResponse && afterHours && event.isPerimeter) {
      return 'Review immediately and prepare armed response escalation.';
    }
    if (profile.hasGuard) {
      return 'Verify with on-site guard and review the camera.';
    }
    if (event.isPerimeter) {
      return 'Review the perimeter camera and confirm whether follow-up is needed.';
    }
    return null;
  }

  String _suggestedActionForViolation(SiteZoneRule rule) {
    return switch (rule.violationAction) {
      'dispatch' => 'Escalate to dispatch immediately.',
      'critical_alert' => 'Raise a critical alert and review immediately.',
      'log' => 'Record the event for audit review.',
      _ => 'Alert the control channel for review.',
    };
  }

  String _expectedVisitorLabel(List<SiteExpectedVisitor> visitors) {
    if (visitors.isEmpty) {
      return 'visitor';
    }
    final labels = visitors
        .map((visitor) => visitor.displayName.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (labels.isEmpty) {
      return 'visitor';
    }
    if (labels.length == 1) {
      return labels.first;
    }
    return '${labels.first} and ${labels.length - 1} more';
  }

  bool _isStreetFacingPerimeterZone(String zoneName) {
    final normalized = zoneName.trim().toLowerCase();
    return normalized.contains('street') ||
        normalized.contains('front') ||
        normalized.contains('main gate') ||
        normalized.contains('driveway');
  }
}

DateTime _profileLocalTime(String timezone, DateTime utc) {
  final normalized = timezone.trim();
  if (normalized == 'Africa/Johannesburg') {
    return utc.toUtc().add(const Duration(hours: 2));
  }
  if (normalized.toUpperCase() == 'UTC') {
    return utc.toUtc();
  }
  return utc.toLocal();
}

String _weekdayLabel(int weekday) {
  return switch (weekday) {
    DateTime.monday => 'monday',
    DateTime.tuesday => 'tuesday',
    DateTime.wednesday => 'wednesday',
    DateTime.thursday => 'thursday',
    DateTime.friday => 'friday',
    DateTime.saturday => 'saturday',
    DateTime.sunday => 'sunday',
    _ => 'unknown',
  };
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((entry) => entry.toString().trim().toLowerCase())
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}

List<Map<String, dynamic>> _jsonRuleList(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value
      .whereType<Map>()
      .map((entry) => Map<String, dynamic>.from(entry))
      .toList(growable: false);
}

String _profileString(Object? value) => value?.toString().trim() ?? '';

String? _nullableProfileString(Object? value) {
  final trimmed = value?.toString().trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

int? _profileInt(Object? value) {
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

DateTime? _profileDate(Object? value) {
  final raw = _nullableProfileString(value);
  if (raw == null) {
    return null;
  }
  return DateTime.tryParse(raw);
}

DateTime? _profileDateTimeUtc(Object? value) {
  final raw = _nullableProfileString(value);
  if (raw == null) {
    return null;
  }
  return DateTime.tryParse(raw)?.toUtc();
}

bool? _profileBool(Object? value) {
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

String _normalizedZoneType(String raw) {
  return raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
}

_ClockTime? _parseClock(String value) {
  final normalized = value.trim();
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(normalized);
  if (match == null) {
    return null;
  }
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null) {
    return null;
  }
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }
  return _ClockTime(hour, minute);
}

class _ClockTime {
  final int hour;
  final int minute;

  const _ClockTime(this.hour, this.minute);
}
