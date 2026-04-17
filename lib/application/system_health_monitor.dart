enum SystemHealthLevel { green, amber, red }

class SystemStatusLine {
  final String label;
  final String value;
  final String detail;
  final SystemHealthLevel level;

  const SystemStatusLine({
    required this.label,
    required this.value,
    required this.detail,
    required this.level,
  });
}

class SystemIssue {
  final String detail;
  final SystemHealthLevel level;

  const SystemIssue({required this.detail, required this.level});
}

class SystemIntegrityMetrics {
  final int entityTotal;
  final int activeIncidentCount;
  final int queueItemCount;
  final int readyGuardCount;
  final int watchScopeCount;
  final int degradedWatchCount;
  final int dailyEventCount;
  final int communicationCount;
  final int verifiedEventCount;
  final double? averageResponseMinutes;
  final int? averageDetectionConfidence;

  const SystemIntegrityMetrics({
    required this.entityTotal,
    required this.activeIncidentCount,
    required this.queueItemCount,
    required this.readyGuardCount,
    required this.watchScopeCount,
    required this.degradedWatchCount,
    required this.dailyEventCount,
    required this.communicationCount,
    required this.verifiedEventCount,
    required this.averageResponseMinutes,
    required this.averageDetectionConfidence,
  });
}

class SystemRelationshipStatus {
  final String title;
  final List<String> lines;
  final SystemHealthLevel level;

  const SystemRelationshipStatus({
    required this.title,
    required this.lines,
    required this.level,
  });
}

class SystemIntegrityReport {
  final String headline;
  final String summary;
  final List<String> overviewLines;
  final List<String> verificationLines;
  final List<SystemRelationshipStatus> relationships;
  final List<SystemIssue> issues;
  final String recommendation;

  const SystemIntegrityReport({
    required this.headline,
    required this.summary,
    required this.overviewLines,
    required this.verificationLines,
    required this.relationships,
    required this.issues,
    required this.recommendation,
  });
}

class SystemHealthSnapshot {
  final SystemHealthLevel level;
  final String controlStateLabel;
  final String globalHealthLabel;
  final List<SystemStatusLine> statusRows;
  final List<String> zaraAssessments;
  final List<SystemIssue> issues;
  final String recommendation;
  final DateTime? lastAuditAtUtc;
  final DateTime nextAuditAtUtc;
  final SystemIntegrityMetrics metrics;

  const SystemHealthSnapshot({
    required this.level,
    required this.controlStateLabel,
    required this.globalHealthLabel,
    required this.statusRows,
    required this.zaraAssessments,
    required this.issues,
    required this.recommendation,
    required this.lastAuditAtUtc,
    required this.nextAuditAtUtc,
    required this.metrics,
  });
}

class SystemHealthMonitor {
  const SystemHealthMonitor();

  SystemHealthSnapshot buildSnapshot({
    required bool directorySynced,
    required String bridgeHealthLabel,
    required bool bridgeFallbackActive,
    required bool bridgeStaging,
    required int entityTotal,
    required int clientCount,
    required int siteCount,
    required int employeeCount,
    required int readyGuardCount,
    required int watchScopeCount,
    required int degradedWatchCount,
    required int issueChannelCount,
    required int queueItemCount,
    required int activeIncidentCount,
    required int criticalSiteCount,
    required int elevatedSiteCount,
    required int dailyEventCount,
    required int communicationCount,
    required int verifiedEventCount,
    required double? averageResponseMinutes,
    required int? averageDetectionConfidence,
    required List<DateTime> auditMomentsUtc,
  }) {
    final normalizedBridge = bridgeHealthLabel.trim().toLowerCase();
    final hasCriticalFault =
        normalizedBridge == 'blocked' || criticalSiteCount > 0;
    final hasElevatedFault =
        !hasCriticalFault &&
        (!directorySynced ||
            bridgeStaging ||
            normalizedBridge == 'degraded' ||
            normalizedBridge == 'disabled' ||
            normalizedBridge == 'no-target' ||
            degradedWatchCount > 0 ||
            elevatedSiteCount > 0 ||
            queueItemCount > 0 ||
            issueChannelCount > 0);
    final level = hasCriticalFault
        ? SystemHealthLevel.red
        : hasElevatedFault
        ? SystemHealthLevel.amber
        : SystemHealthLevel.green;
    final issues = <SystemIssue>[
      if (!directorySynced)
        const SystemIssue(
          detail: 'Directory sync is offline and needs review.',
          level: SystemHealthLevel.amber,
        ),
      if (normalizedBridge == 'blocked')
        const SystemIssue(
          detail:
              'Camera bridge is blocked and requires immediate intervention.',
          level: SystemHealthLevel.red,
        ),
      if (bridgeStaging && normalizedBridge != 'blocked')
        const SystemIssue(
          detail: 'Bridge remains in staging mode pending camera credentials.',
          level: SystemHealthLevel.amber,
        ),
      if (degradedWatchCount > 0)
        SystemIssue(
          detail:
              '$degradedWatchCount watch scope${degradedWatchCount == 1 ? '' : 's'} currently degraded.',
          level: SystemHealthLevel.amber,
        ),
      if (criticalSiteCount > 0)
        SystemIssue(
          detail:
              '$criticalSiteCount critical site posture signal${criticalSiteCount == 1 ? '' : 's'} active.',
          level: SystemHealthLevel.red,
        ),
      if (elevatedSiteCount > 0 && criticalSiteCount == 0)
        SystemIssue(
          detail:
              '$elevatedSiteCount elevated site posture signal${elevatedSiteCount == 1 ? '' : 's'} under watch.',
          level: SystemHealthLevel.amber,
        ),
      if (issueChannelCount > 0)
        SystemIssue(
          detail:
              '$issueChannelCount communication channel${issueChannelCount == 1 ? '' : 's'} require verification.',
          level: SystemHealthLevel.amber,
        ),
      if (queueItemCount > 0)
        SystemIssue(
          detail:
              '$queueItemCount queue item${queueItemCount == 1 ? '' : 's'} still awaiting operator action.',
          level: SystemHealthLevel.amber,
        ),
    ];
    final statusRows = <SystemStatusLine>[
      SystemStatusLine(
        label: 'COMMS VERIFIED',
        value: issueChannelCount == 0
            ? 'all channels operational'
            : '$issueChannelCount channels need review',
        detail: bridgeFallbackActive
            ? 'Telegram fallback is active but delivery remains available.'
            : queueItemCount == 0
            ? 'Telegram, push, and VoIP are ready for command traffic.'
            : 'Draft pressure is present but the comms lane remains live.',
        level: issueChannelCount > 0
            ? SystemHealthLevel.amber
            : SystemHealthLevel.green,
      ),
      SystemStatusLine(
        label: 'WATCH ACTIVE',
        value: watchScopeCount == 0
            ? 'watch scope standby'
            : '$watchScopeCount scope${watchScopeCount == 1 ? '' : 's'} monitored',
        detail: degradedWatchCount == 0
            ? 'DVR fleet monitoring is holding full coverage.'
            : '$degradedWatchCount scope${degradedWatchCount == 1 ? '' : 's'} are degraded but still visible.',
        level: watchScopeCount == 0
            ? SystemHealthLevel.amber
            : degradedWatchCount > 0
            ? SystemHealthLevel.amber
            : SystemHealthLevel.green,
      ),
      SystemStatusLine(
        label: 'DIRECTORY SYNCED',
        value: '$entityTotal entities tracked',
        detail:
            '$clientCount clients • $siteCount sites • $employeeCount employees',
        level: directorySynced
            ? SystemHealthLevel.green
            : SystemHealthLevel.amber,
      ),
      SystemStatusLine(
        label: 'BRIDGE READY',
        value: normalizedBridge == 'blocked'
            ? 'bridge blocked'
            : bridgeStaging
            ? 'staging mode'
            : normalizedBridge == 'degraded' ||
                  normalizedBridge == 'disabled' ||
                  normalizedBridge == 'no-target'
            ? 'limited functionality'
            : 'camera bridge ready',
        detail: bridgeStaging
            ? 'Camera credentials are still pending, but command surfaces remain available.'
            : 'Bridge status is available to the authority control layer.',
        level: normalizedBridge == 'blocked'
            ? SystemHealthLevel.red
            : bridgeStaging ||
                  normalizedBridge == 'degraded' ||
                  normalizedBridge == 'disabled' ||
                  normalizedBridge == 'no-target'
            ? SystemHealthLevel.amber
            : SystemHealthLevel.green,
      ),
      SystemStatusLine(
        label: 'NO CRITICAL FAULTS',
        value: hasCriticalFault
            ? '${issues.length} priority issues detected'
            : 'system integrity maintained',
        detail: hasCriticalFault
            ? 'Critical items should be reviewed before further runtime changes.'
            : 'No unreconciled control-plane faults are active.',
        level: hasCriticalFault
            ? SystemHealthLevel.red
            : SystemHealthLevel.green,
      ),
    ];
    final assessments = <String>[
      'Directory synchronization: ${directorySynced ? 'COMPLETE' : 'DEGRADED'} ($clientCount clients, $siteCount sites, $employeeCount employees).',
      'Communication channels: ${issueChannelCount == 0 ? 'ALL VERIFIED' : 'UNDER WATCH'} (${bridgeHealthLabel.toUpperCase()} bridge${queueItemCount > 0 ? ' • $queueItemCount queue item${queueItemCount == 1 ? '' : 's'} pending' : ''}).',
      'Watch infrastructure: $watchScopeCount active scope${watchScopeCount == 1 ? '' : 's'}${degradedWatchCount > 0 ? ' • $degradedWatchCount degraded' : ' • full coverage maintained'}.',
      'Bridge status: ${bridgeStaging ? 'STAGING MODE' : bridgeHealthLabel.toUpperCase()}${bridgeStaging ? ' (awaiting camera credentials)' : ''}.',
    ];
    final recommendation = hasCriticalFault
        ? 'Immediate authority review required before any additional operational escalation.'
        : hasElevatedFault
        ? 'System is operational with limited attention items. Resolve bridge and queue drift during the next control sweep.'
        : 'System ready for full operations.';
    final sortedAuditMoments = [...auditMomentsUtc]..sort();
    final metrics = SystemIntegrityMetrics(
      entityTotal: entityTotal,
      activeIncidentCount: activeIncidentCount,
      queueItemCount: queueItemCount,
      readyGuardCount: readyGuardCount,
      watchScopeCount: watchScopeCount,
      degradedWatchCount: degradedWatchCount,
      dailyEventCount: dailyEventCount,
      communicationCount: communicationCount,
      verifiedEventCount: verifiedEventCount,
      averageResponseMinutes: averageResponseMinutes,
      averageDetectionConfidence: averageDetectionConfidence,
    );
    return SystemHealthSnapshot(
      level: level,
      controlStateLabel: switch (level) {
        SystemHealthLevel.green => 'SYSTEM STABLE',
        SystemHealthLevel.amber => 'ELEVATED WATCH',
        SystemHealthLevel.red => 'CRITICAL FAULT',
      },
      globalHealthLabel: switch (level) {
        SystemHealthLevel.green => 'GREEN',
        SystemHealthLevel.amber => 'AMBER',
        SystemHealthLevel.red => 'RED',
      },
      statusRows: statusRows,
      zaraAssessments: assessments,
      issues: issues,
      recommendation: recommendation,
      lastAuditAtUtc: sortedAuditMoments.isEmpty
          ? null
          : sortedAuditMoments.last,
      nextAuditAtUtc: _nextAuditAtUtc(),
      metrics: metrics,
    );
  }

  List<SystemIssue> detectCrossModuleIssuesSync({
    required SystemHealthSnapshot snapshot,
  }) {
    final issues = <SystemIssue>[
      ...snapshot.issues,
      if (snapshot.metrics.degradedWatchCount > 0 &&
          snapshot.metrics.communicationCount > 0)
        SystemIssue(
          detail:
              'Watch degradation can reduce confidence for ${snapshot.metrics.communicationCount} logged communication${snapshot.metrics.communicationCount == 1 ? '' : 's'}.',
          level: SystemHealthLevel.amber,
        ),
      if (snapshot.metrics.queueItemCount > 0 &&
          snapshot.metrics.activeIncidentCount > 0)
        SystemIssue(
          detail:
              '${snapshot.metrics.activeIncidentCount} active incident${snapshot.metrics.activeIncidentCount == 1 ? '' : 's'} still share the floor with ${snapshot.metrics.queueItemCount} pending queue item${snapshot.metrics.queueItemCount == 1 ? '' : 's'}.',
          level: SystemHealthLevel.amber,
        ),
      if (snapshot.metrics.readyGuardCount == 0 &&
          snapshot.metrics.activeIncidentCount > 0)
        const SystemIssue(
          detail:
              'No ready guards are visible while an incident is active. Review workforce readiness immediately.',
          level: SystemHealthLevel.red,
        ),
    ];
    final seen = <String>{};
    return issues
        .where((issue) => seen.add(issue.detail))
        .toList(growable: false);
  }

  List<SystemRelationshipStatus> buildInterdependencies({
    required SystemHealthSnapshot snapshot,
  }) {
    final watchCommsLevel =
        snapshot.metrics.degradedWatchCount > 0 ||
            snapshot.metrics.queueItemCount > 0
        ? SystemHealthLevel.amber
        : SystemHealthLevel.green;
    final directoryCommsLevel =
        snapshot.statusRows
                .firstWhere((row) => row.label == 'DIRECTORY SYNCED')
                .level ==
            SystemHealthLevel.green
        ? SystemHealthLevel.green
        : SystemHealthLevel.amber;
    final bridgeWatchLevel = snapshot.statusRows
        .firstWhere((row) => row.label == 'BRIDGE READY')
        .level;
    return [
      SystemRelationshipStatus(
        title: 'Watch Identity ↔ AI Communications',
        level: watchCommsLevel,
        lines: [
          'DVR health influences communication reliability and escalation confidence.',
          'Camera gaps can reduce delivery certainty for verified client updates.',
          watchCommsLevel == SystemHealthLevel.green
              ? 'Current status: No degradation impact.'
              : 'Current status: Watch or queue pressure is visible.',
        ],
      ),
      SystemRelationshipStatus(
        title: 'AI Communications ↔ Entity Management',
        level: directoryCommsLevel,
        lines: [
          'Directory sync enables targeted messaging and scoped approvals.',
          'Guard and site assignments shape comms routing and audit context.',
          directoryCommsLevel == SystemHealthLevel.green
              ? 'Current status: Full integration active.'
              : 'Current status: Sync posture is degraded but functional.',
        ],
      ),
      SystemRelationshipStatus(
        title: 'Bridge Status ↔ Watch Identity',
        level: bridgeWatchLevel,
        lines: [
          'Camera credentials unlock advanced monitoring and footage verification.',
          'Bridge staging limits real-time footage access without breaking authority flow.',
          bridgeWatchLevel == SystemHealthLevel.green
              ? 'Current status: Bridge and watch are aligned.'
              : bridgeWatchLevel == SystemHealthLevel.red
              ? 'Current status: Bridge requires immediate remediation.'
              : 'Current status: Operational but limited functionality.',
        ],
      ),
    ];
  }

  SystemIntegrityReport buildIntegrityReport({
    required SystemHealthSnapshot snapshot,
  }) {
    final issues = detectCrossModuleIssuesSync(snapshot: snapshot);
    final relationships = buildInterdependencies(snapshot: snapshot);
    final totalEvents = snapshot.metrics.dailyEventCount > 0
        ? snapshot.metrics.dailyEventCount
        : snapshot.metrics.verifiedEventCount;
    final verifiedEvents = totalEvents == 0
        ? snapshot.metrics.verifiedEventCount
        : snapshot.metrics.verifiedEventCount.clamp(0, totalEvents);
    final overviewLines = [
      "Today's operations: ${snapshot.metrics.dailyEventCount}",
      'Incidents processed: ${snapshot.metrics.activeIncidentCount}',
      'Communications sent: ${snapshot.metrics.communicationCount}',
      'DVR sessions: ${snapshot.metrics.watchScopeCount}',
      'Ready guards: ${snapshot.metrics.readyGuardCount}',
    ];
    final verificationLines = [
      'EventStore: $verifiedEvents/$totalEvents events sealed and timestamped${verifiedEvents == totalEvents ? '' : ' • verification drift detected'}.',
      snapshot.metrics.communicationCount == 0
          ? 'Communication log: No client messages recorded in the current window.'
          : 'Communication log: ${snapshot.metrics.communicationCount} communication${snapshot.metrics.communicationCount == 1 ? '' : 's'} captured in the audit trail.',
      snapshot.metrics.degradedWatchCount == 0
          ? 'Watch records: Continuous monitoring verified across ${snapshot.metrics.watchScopeCount} active scope${snapshot.metrics.watchScopeCount == 1 ? '' : 's'}.'
          : 'Watch records: ${snapshot.metrics.degradedWatchCount} degraded scope${snapshot.metrics.degradedWatchCount == 1 ? '' : 's'} still visible for review.',
      'Directory sync: ${snapshot.metrics.entityTotal} entities current.',
    ];
    return SystemIntegrityReport(
      headline: switch (snapshot.level) {
        SystemHealthLevel.green => 'SYSTEM STABLE',
        SystemHealthLevel.amber => 'ELEVATED WATCH',
        SystemHealthLevel.red => 'CRITICAL FAULT',
      },
      summary:
          'Global health ${snapshot.globalHealthLabel}. ${snapshot.recommendation}',
      overviewLines: overviewLines,
      verificationLines: verificationLines,
      relationships: relationships,
      issues: issues,
      recommendation: snapshot.recommendation,
    );
  }

  Future<SystemIntegrityReport> generateIntegrityReport({
    required SystemHealthSnapshot snapshot,
  }) async {
    return buildIntegrityReport(snapshot: snapshot);
  }

  Future<List<SystemIssue>> detectCrossModuleIssues({
    required SystemHealthSnapshot snapshot,
  }) async {
    return detectCrossModuleIssuesSync(snapshot: snapshot);
  }

  DateTime _nextAuditAtUtc() {
    final now = DateTime.now().toUtc();
    final nextHalfHourMinute = now.minute < 30 ? 30 : 0;
    final nextHour = now.minute < 30 ? now.hour : now.hour + 1;
    return DateTime.utc(
      now.year,
      now.month,
      now.day,
      nextHour,
      nextHalfHourMinute,
    );
  }
}
