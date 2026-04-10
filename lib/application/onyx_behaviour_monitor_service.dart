import 'dart:math' as math;

import 'onyx_site_profile_service.dart';

class InactivityAlert {
  final String siteId;
  final String zoneName;
  final DateTime lastSeenAtUtc;
  final int inactiveMinutes;

  const InactivityAlert({
    required this.siteId,
    required this.zoneName,
    required this.lastSeenAtUtc,
    required this.inactiveMinutes,
  });
}

class TillAlert {
  final String siteId;
  final String zoneName;
  final DateTime lastSeenAtUtc;
  final int unattendedMinutes;

  const TillAlert({
    required this.siteId,
    required this.zoneName,
    required this.lastSeenAtUtc,
    required this.unattendedMinutes,
  });
}

class ZoneViolation {
  final String siteId;
  final String zoneName;
  final DateTime detectedAtUtc;
  final String violationAction;

  const ZoneViolation({
    required this.siteId,
    required this.zoneName,
    required this.detectedAtUtc,
    required this.violationAction,
  });
}

class OnyxBehaviourMonitorService {
  final Map<String, _PresenceRecord> _presenceByScope =
      <String, _PresenceRecord>{};

  Future<void> recordPresence({
    required String siteId,
    required int channelId,
    required String zoneName,
    required DateTime detectedAt,
  }) async {
    final normalizedSiteId = siteId.trim();
    final normalizedZoneName = zoneName.trim().isEmpty
        ? 'Channel $channelId'
        : zoneName.trim();
    if (normalizedSiteId.isEmpty || channelId <= 0) {
      return;
    }
    final key = '$normalizedSiteId|$channelId|$normalizedZoneName';
    final nowUtc = detectedAt.toUtc();
    final existing = _presenceByScope[key];
    _presenceByScope[key] = _PresenceRecord(
      siteId: normalizedSiteId,
      channelId: channelId,
      zoneName: normalizedZoneName,
      firstSeenAtUtc: existing?.firstSeenAtUtc ?? nowUtc,
      lastSeenAtUtc: nowUtc,
    );
    _prune(nowUtc);
  }

  Future<List<InactivityAlert>> checkInactivity(
    String siteId,
    SiteIntelligenceProfile profile,
  ) async {
    if (!profile.monitorStaffActivity) {
      return const <InactivityAlert>[];
    }
    final nowUtc = DateTime.now().toUtc();
    final threshold = math.max(profile.inactiveStaffAlertMinutes, 1);
    return _presenceByScope.values
        .where((record) => record.siteId == siteId.trim())
        .where(
          (record) =>
              nowUtc.difference(record.lastSeenAtUtc).inMinutes >= threshold,
        )
        .map(
          (record) => InactivityAlert(
            siteId: record.siteId,
            zoneName: record.zoneName,
            lastSeenAtUtc: record.lastSeenAtUtc,
            inactiveMinutes:
                nowUtc.difference(record.lastSeenAtUtc).inMinutes,
          ),
        )
        .toList(growable: false);
  }

  Future<List<TillAlert>> checkTillAttendance(
    String siteId,
    SiteIntelligenceProfile profile,
  ) async {
    if (!profile.monitorTillAttendance) {
      return const <TillAlert>[];
    }
    final nowUtc = DateTime.now().toUtc();
    final threshold = math.max(profile.tillUnattendedMinutes, 1);
    return _presenceByScope.values
        .where((record) => record.siteId == siteId.trim())
        .where((record) => _looksLikeTillZone(record.zoneName))
        .where(
          (record) =>
              nowUtc.difference(record.lastSeenAtUtc).inMinutes >= threshold,
        )
        .map(
          (record) => TillAlert(
            siteId: record.siteId,
            zoneName: record.zoneName,
            lastSeenAtUtc: record.lastSeenAtUtc,
            unattendedMinutes:
                nowUtc.difference(record.lastSeenAtUtc).inMinutes,
          ),
        )
        .toList(growable: false);
  }

  Future<List<ZoneViolation>> checkZoneViolations(
    String siteId,
    List<SiteZoneRule> rules,
  ) async {
    if (rules.isEmpty) {
      return const <ZoneViolation>[];
    }
    final restrictedNames = rules
        .where((rule) => rule.isRestricted)
        .map((rule) => rule.zoneName.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (restrictedNames.isEmpty) {
      return const <ZoneViolation>[];
    }
    return _presenceByScope.values
        .where((record) => record.siteId == siteId.trim())
        .where((record) => restrictedNames.contains(record.zoneName.toLowerCase()))
        .map(
          (record) => ZoneViolation(
            siteId: record.siteId,
            zoneName: record.zoneName,
            detectedAtUtc: record.lastSeenAtUtc,
            violationAction: 'alert',
          ),
        )
        .toList(growable: false);
  }

  void _prune(DateTime nowUtc) {
    final cutoff = nowUtc.subtract(const Duration(hours: 12));
    _presenceByScope.removeWhere(
      (_, record) => record.lastSeenAtUtc.isBefore(cutoff),
    );
  }

  bool _looksLikeTillZone(String zoneName) {
    final normalized = zoneName.toLowerCase();
    return normalized.contains('till') ||
        normalized.contains('cashier') ||
        normalized.contains('checkout') ||
        normalized.contains('point of sale');
  }
}

class _PresenceRecord {
  final String siteId;
  final int channelId;
  final String zoneName;
  final DateTime firstSeenAtUtc;
  final DateTime lastSeenAtUtc;

  const _PresenceRecord({
    required this.siteId,
    required this.channelId,
    required this.zoneName,
    required this.firstSeenAtUtc,
    required this.lastSeenAtUtc,
  });
}
