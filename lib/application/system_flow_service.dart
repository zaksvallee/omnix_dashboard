enum OnyxGlobalSystemState { nominal, elevatedWatch, activeIncident, critical }

abstract final class OnyxSystemFlowService {
  static OnyxGlobalSystemState deriveGlobalState({
    required int activeIncidentCount,
    required int aiActionCount,
    required int guardsOnlineCount,
    int complianceIssuesCount = 0,
    int tacticalSosAlerts = 0,
  }) {
    if (tacticalSosAlerts > 0) {
      return OnyxGlobalSystemState.critical;
    }
    if (activeIncidentCount > 0) {
      return OnyxGlobalSystemState.activeIncident;
    }
    if (aiActionCount > 0 ||
        complianceIssuesCount > 0 ||
        guardsOnlineCount <= 2) {
      return OnyxGlobalSystemState.elevatedWatch;
    }
    return OnyxGlobalSystemState.nominal;
  }

  static String stateLabel(OnyxGlobalSystemState state) {
    return switch (state) {
      OnyxGlobalSystemState.nominal => 'NOMINAL',
      OnyxGlobalSystemState.elevatedWatch => 'ELEVATED WATCH',
      OnyxGlobalSystemState.activeIncident => 'ACTIVE INCIDENT',
      OnyxGlobalSystemState.critical => 'CRITICAL',
    };
  }

  static String stateDetail(
    OnyxGlobalSystemState state, {
    required int activeIncidentCount,
    required int aiActionCount,
    required int guardsOnlineCount,
    int complianceIssuesCount = 0,
    int tacticalSosAlerts = 0,
  }) {
    return switch (state) {
      OnyxGlobalSystemState.nominal =>
        '$guardsOnlineCount guards ready across the current operating layer.',
      OnyxGlobalSystemState.elevatedWatch =>
        aiActionCount > 0
            ? '$aiActionCount decision cue${aiActionCount == 1 ? '' : 's'} waiting in Queue.'
            : complianceIssuesCount > 0
            ? '$complianceIssuesCount governance check${complianceIssuesCount == 1 ? '' : 's'} need review.'
            : 'Coverage posture is thin. Keep the next response unit staged.',
      OnyxGlobalSystemState.activeIncident =>
        '$activeIncidentCount incident${activeIncidentCount == 1 ? '' : 's'} moving through Queue and Dispatch.',
      OnyxGlobalSystemState.critical =>
        '$tacticalSosAlerts SOS trigger${tacticalSosAlerts == 1 ? '' : 's'} need immediate command attention.',
    };
  }

  static String incidentReference(
    String raw, {
    String fallback = 'INC-STANDBY',
  }) {
    final normalized = raw.trim().toUpperCase();
    if (normalized.isEmpty) {
      return fallback;
    }
    if (normalized.startsWith('INC-')) {
      return normalized;
    }
    if (normalized.startsWith('DSP-')) {
      return normalized.replaceFirst('DSP-', 'INC-');
    }
    final compact = normalized.replaceAll(RegExp(r'[^A-Z0-9]+'), '');
    if (compact.isEmpty) {
      return fallback;
    }
    final suffix = compact.length <= 8 ? compact : compact.substring(0, 8);
    return 'INC-$suffix';
  }

  static String dispatchReference(
    String raw, {
    String fallback = 'DSP-STANDBY',
  }) {
    final normalized = raw.trim().toUpperCase();
    if (normalized.isEmpty) {
      return fallback;
    }
    if (normalized.startsWith('DSP-')) {
      return normalized;
    }
    if (normalized.startsWith('INC-')) {
      return normalized.replaceFirst('INC-', 'DSP-');
    }
    final compact = normalized.replaceAll(RegExp(r'[^A-Z0-9]+'), '');
    if (compact.isEmpty) {
      return fallback;
    }
    final suffix = compact.length <= 8 ? compact : compact.substring(0, 8);
    return 'DSP-$suffix';
  }
}
