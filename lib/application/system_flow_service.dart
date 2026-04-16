enum OnyxGlobalSystemState { nominal, elevatedWatch, activeIncident, critical }

enum OnyxZaraVoiceRole {
  predictive,
  decisive,
  confirmatory,
  evaluative,
  communicative,
}

enum OnyxIncidentLifecycleActor { zara, client, officer, system, dispatch }

enum OnyxIncidentLifecycleStage {
  detection,
  verification,
  decision,
  dispatch,
  confirmation,
  resolution,
  recorded,
}

class OnyxSystemStateSnapshot {
  final OnyxGlobalSystemState state;
  final int activeIncidentCount;
  final int aiActionCount;
  final int guardsOnlineCount;
  final int complianceIssuesCount;
  final int tacticalSosAlerts;
  final int elevatedRiskCount;
  final int liveAlarmCount;

  const OnyxSystemStateSnapshot({
    required this.state,
    required this.activeIncidentCount,
    required this.aiActionCount,
    required this.guardsOnlineCount,
    required this.complianceIssuesCount,
    required this.tacticalSosAlerts,
    required this.elevatedRiskCount,
    required this.liveAlarmCount,
  });
}

class OnyxFlowBreadcrumbData {
  final String chainLabel;
  final String? sourceLabel;
  final String? nextActionLabel;
  final String? referenceLabel;

  const OnyxFlowBreadcrumbData({
    required this.chainLabel,
    this.sourceLabel,
    this.nextActionLabel,
    this.referenceLabel,
  });
}

class OnyxZaraContinuitySnapshot {
  final OnyxZaraVoiceRole role;
  final String headline;
  final List<String> lines;

  const OnyxZaraContinuitySnapshot({
    required this.role,
    required this.headline,
    required this.lines,
  });
}

class OnyxIncidentLifecycleEntry {
  final OnyxIncidentLifecycleStage stage;
  final OnyxIncidentLifecycleActor actor;
  final String title;
  final String detail;
  final DateTime occurredAtUtc;
  final String reference;
  final bool major;

  const OnyxIncidentLifecycleEntry({
    required this.stage,
    required this.actor,
    required this.title,
    required this.detail,
    required this.occurredAtUtc,
    required this.reference,
    this.major = true,
  });
}

class OnyxIncidentLifecycleSnapshot {
  final String incidentReference;
  final String summary;
  final bool active;
  final List<OnyxIncidentLifecycleEntry> entries;

  const OnyxIncidentLifecycleSnapshot({
    required this.incidentReference,
    required this.summary,
    required this.active,
    required this.entries,
  });

  factory OnyxIncidentLifecycleSnapshot.standby() {
    return OnyxIncidentLifecycleSnapshot(
      incidentReference: 'INC-STANDBY',
      summary:
          'No active lifecycle in focus. Awaiting the next verified incident.',
      active: false,
      entries: const [],
    );
  }
}

abstract final class OnyxSystemStateService {
  static OnyxSystemStateSnapshot deriveSnapshot({
    required int activeIncidentCount,
    required int aiActionCount,
    required int guardsOnlineCount,
    int complianceIssuesCount = 0,
    int tacticalSosAlerts = 0,
    int elevatedRiskCount = 0,
    int liveAlarmCount = 0,
  }) {
    final state = _deriveState(
      activeIncidentCount: activeIncidentCount,
      aiActionCount: aiActionCount,
      guardsOnlineCount: guardsOnlineCount,
      complianceIssuesCount: complianceIssuesCount,
      tacticalSosAlerts: tacticalSosAlerts,
      elevatedRiskCount: elevatedRiskCount,
      liveAlarmCount: liveAlarmCount,
    );
    return OnyxSystemStateSnapshot(
      state: state,
      activeIncidentCount: activeIncidentCount,
      aiActionCount: aiActionCount,
      guardsOnlineCount: guardsOnlineCount,
      complianceIssuesCount: complianceIssuesCount,
      tacticalSosAlerts: tacticalSosAlerts,
      elevatedRiskCount: elevatedRiskCount,
      liveAlarmCount: liveAlarmCount,
    );
  }

  static OnyxGlobalSystemState _deriveState({
    required int activeIncidentCount,
    required int aiActionCount,
    required int guardsOnlineCount,
    required int complianceIssuesCount,
    required int tacticalSosAlerts,
    required int elevatedRiskCount,
    required int liveAlarmCount,
  }) {
    if (tacticalSosAlerts > 0 || liveAlarmCount >= 2) {
      return OnyxGlobalSystemState.critical;
    }
    if (activeIncidentCount > 0) {
      return OnyxGlobalSystemState.activeIncident;
    }
    if (aiActionCount > 0 ||
        elevatedRiskCount > 0 ||
        liveAlarmCount > 0 ||
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

  static String detailFor(OnyxSystemStateSnapshot snapshot) {
    return switch (snapshot.state) {
      OnyxGlobalSystemState.nominal =>
        '${snapshot.guardsOnlineCount} guards ready. Monitoring posture is stable across the active operating layer.',
      OnyxGlobalSystemState.elevatedWatch =>
        snapshot.liveAlarmCount > 0
            ? '${snapshot.liveAlarmCount} monitoring alarm${snapshot.liveAlarmCount == 1 ? '' : 's'} surfaced. Track and Queue should stay warm.'
            : snapshot.elevatedRiskCount > 0
            ? '${snapshot.elevatedRiskCount} elevated intelligence cue${snapshot.elevatedRiskCount == 1 ? '' : 's'} need review before the next shift handoff.'
            : snapshot.aiActionCount > 0
            ? '${snapshot.aiActionCount} decision cue${snapshot.aiActionCount == 1 ? '' : 's'} waiting in Queue.'
            : snapshot.complianceIssuesCount > 0
            ? '${snapshot.complianceIssuesCount} governance check${snapshot.complianceIssuesCount == 1 ? '' : 's'} need review.'
            : 'Guard availability is thin. Keep the next response unit staged.',
      OnyxGlobalSystemState.activeIncident =>
        '${snapshot.activeIncidentCount} incident${snapshot.activeIncidentCount == 1 ? '' : 's'} moving through Queue and Dispatch.',
      OnyxGlobalSystemState.critical =>
        snapshot.tacticalSosAlerts > 0
            ? '${snapshot.tacticalSosAlerts} SOS trigger${snapshot.tacticalSosAlerts == 1 ? '' : 's'} need immediate command attention.'
            : '${snapshot.liveAlarmCount} live monitoring alarm${snapshot.liveAlarmCount == 1 ? '' : 's'} are breaking normal posture.',
    };
  }
}

abstract final class OnyxFlowIndicatorService {
  static OnyxFlowBreadcrumbData intelToTrack({
    required String sourceLabel,
    required String nextActionLabel,
    String? referenceLabel,
  }) {
    return OnyxFlowBreadcrumbData(
      chainLabel: 'Intel → Track',
      sourceLabel: sourceLabel,
      nextActionLabel: nextActionLabel,
      referenceLabel: referenceLabel,
    );
  }

  static OnyxFlowBreadcrumbData trackToQueue({
    required String sourceLabel,
    required String nextActionLabel,
    String? referenceLabel,
  }) {
    return OnyxFlowBreadcrumbData(
      chainLabel: 'Track → Queue',
      sourceLabel: sourceLabel,
      nextActionLabel: nextActionLabel,
      referenceLabel: referenceLabel,
    );
  }

  static OnyxFlowBreadcrumbData queueToDispatch({
    required String sourceLabel,
    required String nextActionLabel,
    String? referenceLabel,
  }) {
    return OnyxFlowBreadcrumbData(
      chainLabel: 'Track → Queue',
      sourceLabel: sourceLabel,
      nextActionLabel: nextActionLabel,
      referenceLabel: referenceLabel,
    );
  }

  static OnyxFlowBreadcrumbData dispatchLifecycle({
    required String sourceLabel,
    required String nextActionLabel,
    String? referenceLabel,
  }) {
    return OnyxFlowBreadcrumbData(
      chainLabel: 'Track → Queue → Dispatch',
      sourceLabel: sourceLabel,
      nextActionLabel: nextActionLabel,
      referenceLabel: referenceLabel,
    );
  }

  static OnyxFlowBreadcrumbData guardsToDispatch({
    required String sourceLabel,
    required String nextActionLabel,
    String? referenceLabel,
  }) {
    return OnyxFlowBreadcrumbData(
      chainLabel: 'Guards → Queue → Dispatch',
      sourceLabel: sourceLabel,
      nextActionLabel: nextActionLabel,
      referenceLabel: referenceLabel,
    );
  }

  static OnyxFlowBreadcrumbData dispatchToClient({
    required String sourceLabel,
    required String nextActionLabel,
    String? referenceLabel,
  }) {
    return OnyxFlowBreadcrumbData(
      chainLabel: 'Dispatch → Comms → Client',
      sourceLabel: sourceLabel,
      nextActionLabel: nextActionLabel,
      referenceLabel: referenceLabel,
    );
  }

  static OnyxFlowBreadcrumbData shellFlow({
    required OnyxSystemStateSnapshot snapshot,
    required String incidentReference,
  }) {
    switch (snapshot.state) {
      case OnyxGlobalSystemState.nominal:
        return OnyxFlowBreadcrumbData(
          chainLabel: 'Intel → Track → Queue → Dispatch',
          sourceLabel: 'System memory → No active incident in focus',
          nextActionLabel:
              'Next action → Hold readiness and monitor the next signal',
          referenceLabel: incidentReference,
        );
      case OnyxGlobalSystemState.elevatedWatch:
        return OnyxFlowBreadcrumbData(
          chainLabel: 'Intel → Track → Queue',
          sourceLabel: snapshot.elevatedRiskCount > 0
              ? 'Source → ${snapshot.elevatedRiskCount} elevated signal${snapshot.elevatedRiskCount == 1 ? '' : 's'} in predictive watch'
              : 'Source → Monitoring posture needs verification attention',
          nextActionLabel:
              'Next action → Keep Track and Queue aligned before dispatch',
          referenceLabel: incidentReference,
        );
      case OnyxGlobalSystemState.activeIncident:
        return OnyxFlowBreadcrumbData(
          chainLabel: 'Track → Queue → Dispatch',
          sourceLabel:
              'Source → Active response chain following $incidentReference',
          nextActionLabel:
              'Next action → Confirm resolution and preserve the record',
          referenceLabel: incidentReference,
        );
      case OnyxGlobalSystemState.critical:
        return OnyxFlowBreadcrumbData(
          chainLabel: 'Alarm → Queue → Dispatch',
          sourceLabel: 'Source → Critical alarm posture breaking normal flow',
          nextActionLabel:
              'Next action → Force command attention and protect the response lane',
          referenceLabel: incidentReference,
        );
    }
  }
}

abstract final class OnyxZaraContinuityService {
  static OnyxZaraContinuitySnapshot predictiveForecast({
    required String areaLabel,
    required bool elevatedArea,
    required String signalLine,
  }) {
    return OnyxZaraContinuitySnapshot(
      role: OnyxZaraVoiceRole.predictive,
      headline: 'ZARA · THREAT FORECAST',
      lines: [
        elevatedArea
            ? '$areaLabel elevated activity detected.'
            : 'All areas stable.',
        signalLine,
        'Recommend review before next shift.',
      ],
    );
  }

  static OnyxZaraContinuitySnapshot trackDetection({
    required int totalSignals,
    required int reviewCount,
    required int geofenceAlerts,
    required String? topSignalTitle,
    required String summaryTime,
  }) {
    final verificationCount = reviewCount >= geofenceAlerts
        ? reviewCount
        : geofenceAlerts;
    return OnyxZaraContinuitySnapshot(
      role: OnyxZaraVoiceRole.predictive,
      headline: 'ZARA · DETECTION SUMMARY',
      lines: [
        '$totalSignals anomalies detected across active zones.',
        '$verificationCount require verification before escalation.',
        topSignalTitle == null
            ? 'No likely actionable signal is active right now.'
            : '1 likely actionable — $topSignalTitle at $summaryTime.',
      ],
    );
  }

  static String queueDecisionNarrative({
    required String recommendationLabel,
    required bool showContextPanel,
    required bool verificationComplete,
    required String cameraLabel,
  }) {
    if (!showContextPanel) {
      return 'ZARA: $recommendationLabel';
    }
    if (verificationComplete) {
      return 'ZARA: Verification complete. No movement detected. Recommendation unchanged: $recommendationLabel';
    }
    return 'ZARA: Verifying before decision. Reviewing $cameraLabel and signal data.';
  }

  static OnyxZaraContinuitySnapshot workforceSummary({
    required String tabKey,
    required int readyCount,
    required int engagedCount,
    required int syncIssues,
    required int siteCount,
    required int gaps,
    required int thin,
    required int anomalyCount,
    required int extendedCount,
    required int noMovementCount,
  }) {
    switch (tabKey) {
      case 'roster':
        return OnyxZaraContinuitySnapshot(
          role: OnyxZaraVoiceRole.evaluative,
          headline: 'ZARA · COVERAGE SUMMARY',
          lines: [
            gaps > 0
                ? '$gaps site coverage gap${gaps == 1 ? '' : 's'} detected in the current seven-day layer.'
                : 'Coverage grid is fully staffed across the current seven-day horizon.',
            thin > 0
                ? '$thin site lane${thin == 1 ? '' : 's'} running thin. Add a coverage layer before shift rollover.'
                : 'No thin lanes detected. Each site keeps at least two operational names on the board.',
            'Coverage stable when Blue Ridge and Waterfall stay under watch before the next turnover.',
          ],
        );
      case 'history':
        return OnyxZaraContinuitySnapshot(
          role: OnyxZaraVoiceRole.evaluative,
          headline: 'ZARA · PERFORMANCE SUMMARY',
          lines: [
            anomalyCount > 0
                ? '$anomalyCount historical shift anomaly${anomalyCount == 1 ? '' : 'ies'} surfaced in the latest operating window.'
                : 'Historical shift performance is stable across the current review window.',
            extendedCount > 0
                ? '$extendedCount extended shift${extendedCount == 1 ? '' : 's'} should be reviewed before the next roster publish.'
                : 'No extended shifts are distorting the current performance baseline.',
            noMovementCount > 0
                ? '$noMovementCount no-movement flag${noMovementCount == 1 ? '' : 's'} should be correlated with patrol expectations.'
                : 'No latent movement anomalies are distorting the patrol baseline.',
          ],
        );
      default:
        return OnyxZaraContinuitySnapshot(
          role: OnyxZaraVoiceRole.evaluative,
          headline: 'ZARA · WORKFORCE SUMMARY',
          lines: [
            '$readyCount guards ready for immediate response across $siteCount active sites.',
            engagedCount > 0
                ? '$engagedCount guard engaged on a live task. Queue handoff should prefer the next ready unit.'
                : 'All active guards are available for controlled dispatch handoff.',
            syncIssues > 0
                ? '$syncIssues sync issue flagged. Verify telemetry before rotating that guard into the next incident.'
                : 'Readiness optimal. Real-time guard position hooks are ready for live map binding.',
          ],
        );
    }
  }

  static List<String> dispatchFinalLines({
    required String outcomeKey,
    required String dispatchReference,
    required bool resolved,
  }) {
    switch (outcomeKey) {
      case 'real_emergency':
        return [
          'Client confirmed real emergency linked to $dispatchReference.',
          resolved
              ? 'Response chain complete and sealed.'
              : 'Real emergency confirmed. Monitoring officer approach.',
          'No further escalation required.',
        ];
      case 'false_alarm':
        return [
          'Client confirmed false alarm.',
          'Dispatch was not required.',
          'Record sealed.',
        ];
      case 'safe_word':
        return [
          'Client safe word activated the protected flow.',
          resolved
              ? 'Protected response chain complete.'
              : 'Response chain is still active.',
          'No further escalation required.',
        ];
      case 'no_response':
      default:
        return [
          'Client did not provide verified confirmation.',
          resolved
              ? 'Response chain completed without a confirmed client statement.'
              : 'Response chain remains active pending field confirmation.',
          'Record remains ready for operator review.',
        ];
    }
  }

  static List<String> communicationsStatusLines({
    required String? lastIncidentReference,
  }) {
    final reference = (lastIncidentReference ?? '').trim();
    return [
      'No pending client communications.',
      reference.isEmpty
          ? 'System ready to draft and send updates.'
          : 'System ready to resume client updates for $reference.',
    ];
  }

  static String communicationsToneLine(String selectedTone) {
    final label = switch (selectedTone) {
      'Reassuring' => 'Using reassuring tone',
      'Concise' => 'Using concise tone',
      'Formal' => 'Using formal tone',
      _ => 'Using contextual tone',
    };
    return 'ZARA: $label for client-facing updates.';
  }
}

abstract final class OnyxSystemFlowService {
  static OnyxGlobalSystemState deriveGlobalState({
    required int activeIncidentCount,
    required int aiActionCount,
    required int guardsOnlineCount,
    int complianceIssuesCount = 0,
    int tacticalSosAlerts = 0,
    int elevatedRiskCount = 0,
    int liveAlarmCount = 0,
  }) {
    return OnyxSystemStateService.deriveSnapshot(
      activeIncidentCount: activeIncidentCount,
      aiActionCount: aiActionCount,
      guardsOnlineCount: guardsOnlineCount,
      complianceIssuesCount: complianceIssuesCount,
      tacticalSosAlerts: tacticalSosAlerts,
      elevatedRiskCount: elevatedRiskCount,
      liveAlarmCount: liveAlarmCount,
    ).state;
  }

  static String stateLabel(OnyxGlobalSystemState state) {
    return OnyxSystemStateService.stateLabel(state);
  }

  static String stateDetail(
    OnyxGlobalSystemState state, {
    required int activeIncidentCount,
    required int aiActionCount,
    required int guardsOnlineCount,
    int complianceIssuesCount = 0,
    int tacticalSosAlerts = 0,
    int elevatedRiskCount = 0,
    int liveAlarmCount = 0,
  }) {
    return OnyxSystemStateService.detailFor(
      OnyxSystemStateService.deriveSnapshot(
        activeIncidentCount: activeIncidentCount,
        aiActionCount: aiActionCount,
        guardsOnlineCount: guardsOnlineCount,
        complianceIssuesCount: complianceIssuesCount,
        tacticalSosAlerts: tacticalSosAlerts,
        elevatedRiskCount: elevatedRiskCount,
        liveAlarmCount: liveAlarmCount,
      ),
    );
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
