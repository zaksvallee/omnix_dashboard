class MonitoringSiteProfile {
  final String siteName;
  final String clientName;

  const MonitoringSiteProfile({
    required this.siteName,
    required this.clientName,
  });

  String get greetingName {
    final trimmed = clientName.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.split(RegExp(r'\s+')).first.trim();
  }
}

class MonitoringShiftWindow {
  final DateTime startedAt;
  final DateTime endsAt;

  const MonitoringShiftWindow({required this.startedAt, required this.endsAt});
}

class MonitoringIncidentUpdate {
  final DateTime occurredAt;
  final String cameraLabel;
  final String objectLabel;
  final String postureLabel;
  final bool dispatchInitiated;

  const MonitoringIncidentUpdate({
    required this.occurredAt,
    required this.cameraLabel,
    this.objectLabel = 'vehicle',
    this.postureLabel = 'monitored movement alert',
    this.dispatchInitiated = false,
  });
}

class MonitoringShiftSummary {
  final MonitoringShiftWindow window;
  final int reviewedEvents;
  final String primaryActivitySource;
  final int dispatchCount;
  final int alertCount;
  final int repeatCount;
  final int escalationCount;
  final int suppressedCount;
  final List<String> actionHistory;
  final List<String> suppressedHistory;
  final bool monitoringAvailable;
  final int unresolvedActionCount;

  const MonitoringShiftSummary({
    required this.window,
    required this.reviewedEvents,
    required this.primaryActivitySource,
    required this.dispatchCount,
    this.alertCount = 0,
    this.repeatCount = 0,
    required this.escalationCount,
    this.suppressedCount = 0,
    this.actionHistory = const <String>[],
    this.suppressedHistory = const <String>[],
    this.monitoringAvailable = true,
    this.unresolvedActionCount = 0,
  });
}

class MonitoringShiftNotificationService {
  const MonitoringShiftNotificationService();

  String formatShiftStart({
    required MonitoringSiteProfile site,
    required MonitoringShiftWindow window,
  }) {
    return _compose(
      header: '🛡️ ONYX Control',
      context: '${site.siteName} | ${_timeLabel(window.startedAt)}',
      lines: [
        _greeting(site, fallbackPeriod: 'evening'),
        'ONYX monitoring is now active for ${site.siteName}.',
        'We will contact you only if activity reaches a level that warrants your attention or if the monitoring posture changes materially.',
        'A full sitrep will be issued at the close of the watch.',
        'ONYX is now on active observation.',
      ],
    );
  }

  String formatIncident({
    required MonitoringSiteProfile site,
    required MonitoringIncidentUpdate incident,
  }) {
    final incidentLead = _incidentLeadLine(incident);
    final verificationLine = _verificationLine(incident);
    final dispatchLine = _dispatchLine(
      incident,
      initiatedLine: 'A response deployment has been initiated.',
      defaultPendingLine: 'No dispatch action has been initiated at this stage.',
    );
    final monitoringLine = _monitoringLine(
      incident,
      defaultLine:
          'Monitoring remains focused on ${incident.cameraLabel} for any repeat or escalating activity.',
    );
    return _compose(
      header: '🛡️ ONYX Control',
      context: '${site.siteName} | ${_timeLabel(incident.occurredAt)}',
      lines: [
        _greeting(site, fallbackPeriod: 'evening'),
        '$incidentLead at ${site.siteName}.',
        verificationLine,
        'The event is currently being managed as a ${incident.postureLabel}.',
        dispatchLine,
        monitoringLine,
        'We will update you immediately should the situation change.',
      ],
    );
  }

  String formatRepeatActivity({
    required MonitoringSiteProfile site,
    required MonitoringIncidentUpdate incident,
  }) {
    final dispatchLine = incident.dispatchInitiated
        ? 'A response deployment has been initiated while ONYX maintains observation on the affected camera.'
        : 'No dispatch action has been initiated at this stage.';
    return _compose(
      header: '🛡️ ONYX Control',
      context: '${site.siteName} | ${_timeLabel(incident.occurredAt)}',
      lines: [
        _directAddress(site),
        'ONYX has identified repeat movement activity on ${incident.cameraLabel} following the initial alert.',
        'A fresh review cycle is underway and the monitoring posture has been elevated for continued observation.',
        'The event is currently being managed as repeat monitored activity.',
        dispatchLine,
        'Monitoring remains fixed on ${incident.cameraLabel} while ONYX reviews for any escalation indicators.',
        'A further update will follow immediately if the posture changes.',
      ],
    );
  }

  String formatEscalationCandidate({
    required MonitoringSiteProfile site,
    required MonitoringIncidentUpdate incident,
  }) {
    final incidentLead = _incidentEscalationLeadLine(incident);
    final verificationLine = _verificationLine(incident);
    final dispatchLine = _dispatchLine(
      incident,
      initiatedLine:
          'A response deployment has been initiated while ONYX maintains focused observation on the affected camera.',
      defaultPendingLine:
          _isFireEmergency(incident)
              ? 'No dispatch action has been initiated yet. ONYX has elevated this event for urgent fire review.'
              : _isLeakEmergency(incident)
              ? 'No dispatch action has been initiated yet. ONYX has elevated this event for urgent flood or leak review.'
              : _isEnvironmentHazard(incident)
              ? 'No dispatch action has been initiated yet. ONYX has elevated this event for urgent hazard review.'
              : 'No dispatch action has been initiated yet. ONYX has elevated this event for urgent review.',
    );
    final monitoringLine = _monitoringLine(
      incident,
      defaultLine:
          'Monitoring remains fixed on ${incident.cameraLabel} while ONYX continues urgent assessment.',
    );
    return _compose(
      header: '🛡️ ONYX Control',
      context: '${site.siteName} | ${_timeLabel(incident.occurredAt)}',
      lines: [
        _directAddress(site),
        '$incidentLead at ${site.siteName}.',
        verificationLine,
        'Current posture: ${incident.postureLabel}.',
        dispatchLine,
        monitoringLine,
        'A further update will follow immediately if the posture changes.',
      ],
    );
  }

  String formatClientVerificationPrompt({
    required MonitoringSiteProfile site,
    required MonitoringIncidentUpdate incident,
    String? identityHint,
  }) {
    final normalizedIdentityHint = (identityHint ?? '').trim();
    return _compose(
      header: '🛡️ ONYX Verification Required',
      context: '${site.siteName} | ${_timeLabel(incident.occurredAt)}',
      lines: [
        _directAddress(site),
        'ONYX detected a person requiring verification on ${incident.cameraLabel} at ${site.siteName}.',
        'Current posture: ${incident.postureLabel}.',
        if (normalizedIdentityHint.isNotEmpty)
          'Observed identity signal: $normalizedIdentityHint.',
        'Please confirm how ONYX should handle this person.',
        'Reply APPROVE if the person is expected, REVIEW to keep the event open for manual checking, or ESCALATE if this person should be treated as suspicious.',
        'Your response will be routed to control immediately.',
      ],
    );
  }

  String formatClientAllowancePrompt({
    required MonitoringSiteProfile site,
    required MonitoringIncidentUpdate incident,
    required String identityHint,
  }) {
    return _compose(
      header: '🛡️ ONYX Allowlist Option',
      context: '${site.siteName} | ${_timeLabel(incident.occurredAt)}',
      lines: [
        _directAddress(site),
        'ONYX has logged this person as expected on ${incident.cameraLabel}.',
        'Observed identity signal: ${identityHint.trim()}.',
        'Reply ALLOW ONCE to keep this as a one-time approval, or ALWAYS ALLOW if ONYX should remember this person for future matches at ${site.siteName}.',
      ],
    );
  }

  String formatShiftSitrep({
    required MonitoringSiteProfile site,
    required MonitoringShiftSummary summary,
  }) {
    final availabilityLine = summary.monitoringAvailable
        ? 'Monitoring remained available throughout the watch, and no unresolved response actions remain open from this period.'
        : 'Monitoring availability degraded during the watch and requires follow-up review.';
    return _compose(
      header: '🛡️ ONYX Shift Sitrep',
      context:
          '${site.siteName}\n${_dateLabel(summary.window.startedAt)} | ${_timeLabel(summary.window.startedAt)}-${_timeLabel(summary.window.endsAt)}',
      lines: [
        _greeting(site, fallbackPeriod: 'morning'),
        'ONYX monitoring for this watch period is now complete.',
        'Executive summary:',
        '- Activity alerts reviewed: ${summary.reviewedEvents}',
        '- Primary activity source: ${summary.primaryActivitySource}',
        '- Dispatches triggered: ${summary.dispatchCount}',
        if (_actionMixSummary(summary) != null)
          '- Action mix: ${_actionMixSummary(summary)!}',
        '- Escalations issued: ${summary.escalationCount}',
        if (_latestActionPattern(summary) != null)
          '- Latest action taken: ${_latestActionPattern(summary)!}',
        if (_recentActionSummary(summary) != null)
          '- Recent actions: ${_recentActionSummary(summary)!}',
        if (summary.suppressedCount > 0)
          '- Filtered internally: ${summary.suppressedCount}',
        if (_latestSuppressedPattern(summary) != null)
          '- Latest filtered pattern: ${_latestSuppressedPattern(summary)!}',
        availabilityLine,
        summary.unresolvedActionCount <= 0
            ? 'ONYX is now transitioning to standby.'
            : 'ONYX remains in controlled follow-up posture pending ${summary.unresolvedActionCount} open action(s).',
        'Next monitoring window begins at ${_timeLabel(summary.window.startedAt)}.',
      ],
    );
  }

  String _compose({
    required String header,
    required String context,
    required List<String> lines,
  }) {
    final body = lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n\n');
    return '$header\n$context\n\n$body';
  }

  String _greeting(
    MonitoringSiteProfile site, {
    required String fallbackPeriod,
  }) {
    final name = site.greetingName;
    if (name.isEmpty) {
      return 'Good $fallbackPeriod.';
    }
    return 'Good $fallbackPeriod, $name.';
  }

  bool _isFireEmergency(MonitoringIncidentUpdate incident) {
    final posture = incident.postureLabel.trim().toLowerCase();
    final object = incident.objectLabel.trim().toLowerCase();
    return posture.contains('fire') ||
        posture.contains('smoke') ||
        object == 'fire' ||
        object == 'smoke';
  }

  bool _isLeakEmergency(MonitoringIncidentUpdate incident) {
    final posture = incident.postureLabel.trim().toLowerCase();
    final object = incident.objectLabel.trim().toLowerCase();
    return posture.contains('flood') ||
        posture.contains('leak') ||
        object == 'water' ||
        object == 'leak';
  }

  bool _isEnvironmentHazard(MonitoringIncidentUpdate incident) {
    final posture = incident.postureLabel.trim().toLowerCase();
    final object = incident.objectLabel.trim().toLowerCase();
    return posture.contains('hazard') || object == 'equipment';
  }

  String _incidentLeadLine(MonitoringIncidentUpdate incident) {
    if (_isFireEmergency(incident)) {
      return 'ONYX has detected likely fire or smoke indicators on ${incident.cameraLabel}';
    }
    if (_isLeakEmergency(incident)) {
      return 'ONYX has detected likely water leak or flooding indicators on ${incident.cameraLabel}';
    }
    if (_isEnvironmentHazard(incident)) {
      return 'ONYX has detected likely environmental hazard indicators on ${incident.cameraLabel}';
    }
    final objectLabel = incident.objectLabel.trim().isEmpty
        ? 'movement'
        : '${incident.objectLabel.trim()} movement';
    return 'ONYX has detected $objectLabel on ${incident.cameraLabel}';
  }

  String _incidentEscalationLeadLine(MonitoringIncidentUpdate incident) {
    if (_isFireEmergency(incident)) {
      return 'ONYX has identified a likely fire or smoke emergency on ${incident.cameraLabel}';
    }
    if (_isLeakEmergency(incident)) {
      return 'ONYX has identified a likely flood or leak emergency on ${incident.cameraLabel}';
    }
    if (_isEnvironmentHazard(incident)) {
      return 'ONYX has identified an elevated environmental hazard on ${incident.cameraLabel}';
    }
    final objectLabel = incident.objectLabel.trim().isEmpty
        ? 'activity'
        : '${incident.objectLabel.trim()} activity';
    return 'ONYX has identified elevated $objectLabel on ${incident.cameraLabel}';
  }

  String _verificationLine(MonitoringIncidentUpdate incident) {
    if (_isFireEmergency(incident)) {
      return 'A verification image has been retrieved and ONYX is validating a likely fire emergency.';
    }
    if (_isLeakEmergency(incident)) {
      return 'A verification image has been retrieved and ONYX is validating a likely water-loss emergency.';
    }
    if (_isEnvironmentHazard(incident)) {
      return 'A verification image has been retrieved and ONYX is validating a likely environmental hazard.';
    }
    return 'A verification image has been retrieved and submitted for AI-assisted review.';
  }

  String _dispatchLine(
    MonitoringIncidentUpdate incident, {
    required String initiatedLine,
    required String defaultPendingLine,
  }) {
    if (incident.dispatchInitiated) {
      return initiatedLine;
    }
    return defaultPendingLine;
  }

  String _monitoringLine(
    MonitoringIncidentUpdate incident, {
    required String defaultLine,
  }) {
    if (_isFireEmergency(incident)) {
      return 'Monitoring remains fixed on ${incident.cameraLabel} while ONYX checks for spread or worsening smoke conditions.';
    }
    if (_isLeakEmergency(incident)) {
      return 'Monitoring remains fixed on ${incident.cameraLabel} while ONYX checks for spread, pooling, or worsening water loss.';
    }
    if (_isEnvironmentHazard(incident)) {
      return 'Monitoring remains fixed on ${incident.cameraLabel} while ONYX checks for worsening hazard conditions.';
    }
    return defaultLine;
  }

  String _directAddress(MonitoringSiteProfile site) {
    final name = site.greetingName;
    return name.isEmpty ? 'ONYX update.' : '$name,';
  }

  String _dateLabel(DateTime value) {
    final utc = value.toUtc();
    final day = utc.day.toString().padLeft(2, '0');
    final month = _monthShortLabel(utc.month);
    final year = utc.year.toString();
    return '$day $month $year';
  }

  String _timeLabel(DateTime value) {
    final utc = value.toUtc();
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _monthShortLabel(int month) {
    return switch (month) {
      1 => 'Jan',
      2 => 'Feb',
      3 => 'Mar',
      4 => 'Apr',
      5 => 'May',
      6 => 'Jun',
      7 => 'Jul',
      8 => 'Aug',
      9 => 'Sep',
      10 => 'Oct',
      11 => 'Nov',
      12 => 'Dec',
      _ => 'Jan',
    };
  }

  String? _latestSuppressedPattern(MonitoringShiftSummary summary) {
    if (summary.suppressedHistory.isEmpty) {
      return null;
    }
    final latest = summary.suppressedHistory.first.trim();
    return latest.isEmpty ? null : latest;
  }

  String? _latestActionPattern(MonitoringShiftSummary summary) {
    if (summary.actionHistory.isEmpty) {
      return null;
    }
    final latest = summary.actionHistory.first.trim();
    return latest.isEmpty ? null : latest;
  }

  String? _recentActionSummary(MonitoringShiftSummary summary) {
    final normalized = summary.actionHistory
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
    if (normalized.length <= 1) {
      return null;
    }
    final latest = normalized.first;
    final remaining = normalized.length - 1;
    return '$latest (+$remaining more)';
  }

  String? _actionMixSummary(MonitoringShiftSummary summary) {
    final parts = <String>[];
    if (summary.alertCount > 0) {
      parts.add(summary.alertCount == 1 ? '1 alert' : '${summary.alertCount} alerts');
    }
    if (summary.repeatCount > 0) {
      parts.add(
        summary.repeatCount == 1
            ? '1 repeat update'
            : '${summary.repeatCount} repeat updates',
      );
    }
    if (summary.escalationCount > 0) {
      parts.add(
        summary.escalationCount == 1
            ? '1 escalation'
            : '${summary.escalationCount} escalations',
      );
    }
    if (summary.suppressedCount > 0) {
      parts.add(
        summary.suppressedCount == 1
            ? '1 suppressed review'
            : '${summary.suppressedCount} suppressed reviews',
      );
    }
    if (parts.isEmpty) {
      return null;
    }
    if (parts.length == 1) {
      return parts.first;
    }
    if (parts.length == 2) {
      return '${parts.first} • ${parts.last}';
    }
    return parts.join(' • ');
  }
}
