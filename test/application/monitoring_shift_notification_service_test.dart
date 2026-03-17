import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/monitoring_shift_notification_service.dart';

void main() {
  const service = MonitoringShiftNotificationService();
  const site = MonitoringSiteProfile(
    siteName: 'MS Vallee Residence',
    clientName: 'Muhammed Vallee',
  );

  test('formats premium shift-start message for residential monitoring', () {
    final message = service.formatShiftStart(
      site: site,
      window: MonitoringShiftWindow(
        startedAt: DateTime.utc(2026, 3, 13, 18, 0),
        endsAt: DateTime.utc(2026, 3, 14, 6, 0),
      ),
    );

    expect(message, contains('🛡️ ONYX Control'));
    expect(message, contains('MS Vallee Residence | 18:00'));
    expect(message, contains('Good evening, Muhammed.'));
    expect(
      message,
      contains('ONYX monitoring is now active for MS Vallee Residence.'),
    );
    expect(
      message,
      contains('A full sitrep will be issued at the close of the watch.'),
    );
  });

  test('formats evidence-safe incident message with camera specificity', () {
    final message = service.formatIncident(
      site: site,
      incident: MonitoringIncidentUpdate(
        occurredAt: DateTime.utc(2026, 3, 13, 23, 14),
        cameraLabel: 'Camera 1',
        objectLabel: 'vehicle',
      ),
    );

    expect(message, contains('MS Vallee Residence | 23:14'));
    expect(
      message,
      contains(
        'ONYX has detected vehicle movement on Camera 1 at MS Vallee Residence.',
      ),
    );
    expect(
      message,
      contains(
        'A verification image has been retrieved and submitted for AI-assisted review.',
      ),
    );
    expect(
      message,
      contains('No dispatch action has been initiated at this stage.'),
    );
    expect(
      message,
      contains(
        'Monitoring remains focused on Camera 1 for any repeat or escalating activity.',
      ),
    );
  });

  test('formats fire incident message with emergency-specific wording', () {
    final message = service.formatIncident(
      site: site,
      incident: MonitoringIncidentUpdate(
        occurredAt: DateTime.utc(2026, 3, 13, 23, 16),
        cameraLabel: 'Generator Room',
        objectLabel: 'smoke',
        postureLabel: 'fire and smoke emergency',
      ),
    );

    expect(
      message,
      contains(
        'ONYX has detected likely fire or smoke indicators on Generator Room at MS Vallee Residence.',
      ),
    );
    expect(
      message,
      contains(
        'A verification image has been retrieved and ONYX is validating a likely fire emergency.',
      ),
    );
    expect(
      message,
      contains(
        'Monitoring remains fixed on Generator Room while ONYX checks for spread or worsening smoke conditions.',
      ),
    );
  });

  test('formats repeat-activity update with premium direct address', () {
    final message = service.formatRepeatActivity(
      site: site,
      incident: MonitoringIncidentUpdate(
        occurredAt: DateTime.utc(2026, 3, 13, 23, 18),
        cameraLabel: 'Camera 1',
      ),
    );

    expect(message, contains('Muhammed,'));
    expect(
      message,
      contains(
        'ONYX has identified repeat movement activity on Camera 1 following the initial alert.',
      ),
    );
    expect(
      message,
      contains(
        'The event is currently being managed as repeat monitored activity.',
      ),
    );
    expect(
      message,
      contains(
        'Monitoring remains fixed on Camera 1 while ONYX reviews for any escalation indicators.',
      ),
    );
  });

  test('formats shift-end sitrep with executive summary structure', () {
    final message = service.formatShiftSitrep(
      site: site,
      summary: MonitoringShiftSummary(
        window: MonitoringShiftWindow(
          startedAt: DateTime.utc(2026, 3, 13, 18, 0),
          endsAt: DateTime.utc(2026, 3, 14, 6, 0),
        ),
        reviewedEvents: 2,
        primaryActivitySource: 'Camera 1',
        dispatchCount: 0,
        alertCount: 1,
        repeatCount: 1,
        escalationCount: 0,
        suppressedCount: 2,
        actionHistory: const [
          '05:44 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
          '05:38 UTC • Camera 1 • Repeat Activity • Repeat activity update sent because vehicle activity repeated.',
        ],
        suppressedHistory: const [
          '05:42 UTC • Camera 2 • Suppressed because the activity remained below the client notification threshold.',
          '03:11 UTC • Camera 1 • Suppressed because motion remained low-significance.',
        ],
      ),
    );

    expect(message, contains('🛡️ ONYX Shift Sitrep'));
    expect(message, contains('MS Vallee Residence\n13 Mar 2026 | 18:00-06:00'));
    expect(message, contains('Good morning, Muhammed.'));
    expect(message, contains('Executive summary:'));
    expect(message, contains('- Activity alerts reviewed: 2'));
    expect(message, contains('- Primary activity source: Camera 1'));
    expect(message, contains('- Dispatches triggered: 0'));
    expect(
      message,
      contains(
        '- Action mix: 1 alert • 1 repeat update • 2 suppressed reviews',
      ),
    );
    expect(message, contains('- Escalations issued: 0'));
    expect(
      message,
      contains(
        '- Latest action taken: 05:44 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
      ),
    );
    expect(
      message,
      contains(
        '- Recent actions: 05:44 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium. (+1 more)',
      ),
    );
    expect(message, contains('- Filtered internally: 2'));
    expect(
      message,
      contains(
        '- Latest filtered pattern: 05:42 UTC • Camera 2 • Suppressed because the activity remained below the client notification threshold.',
      ),
    );
    expect(message, contains('ONYX is now transitioning to standby.'));
    expect(message, contains('Next monitoring window begins at 18:00.'));
  });

  test('formats escalation-candidate update with urgent review wording', () {
    final message = service.formatEscalationCandidate(
      site: site,
      incident: MonitoringIncidentUpdate(
        occurredAt: DateTime.utc(2026, 3, 13, 23, 22),
        cameraLabel: 'Camera 1',
        objectLabel: 'person',
        postureLabel: 'escalation candidate',
      ),
    );

    expect(message, contains('Muhammed,'));
    expect(
      message,
      contains(
        'ONYX has identified elevated person activity on Camera 1 at MS Vallee Residence.',
      ),
    );
    expect(message, contains('Current posture: escalation candidate.'));
    expect(
      message,
      contains(
        'No dispatch action has been initiated yet. ONYX has elevated this event for urgent review.',
      ),
    );
  });

  test('formats leak escalation update with emergency-specific wording', () {
    final message = service.formatEscalationCandidate(
      site: site,
      incident: MonitoringIncidentUpdate(
        occurredAt: DateTime.utc(2026, 3, 13, 23, 25),
        cameraLabel: 'Stock Room',
        objectLabel: 'leak',
        postureLabel: 'flood or leak emergency',
      ),
    );

    expect(message, contains('Muhammed,'));
    expect(
      message,
      contains(
        'ONYX has identified a likely flood or leak emergency on Stock Room at MS Vallee Residence.',
      ),
    );
    expect(
      message,
      contains(
        'A verification image has been retrieved and ONYX is validating a likely water-loss emergency.',
      ),
    );
    expect(
      message,
      contains(
        'No dispatch action has been initiated yet. ONYX has elevated this event for urgent flood or leak review.',
      ),
    );
    expect(
      message,
      contains(
        'Monitoring remains fixed on Stock Room while ONYX checks for spread, pooling, or worsening water loss.',
      ),
    );
  });

  test('formats client verification prompt for unidentified person scenes', () {
    final message = service.formatClientVerificationPrompt(
      site: site,
      incident: MonitoringIncidentUpdate(
        occurredAt: DateTime.utc(2026, 3, 13, 21, 14),
        cameraLabel: 'Gate Camera',
        objectLabel: 'person',
        postureLabel: 'boundary concern',
      ),
    );

    expect(message, contains('🛡️ ONYX Verification Required'));
    expect(
      message,
      contains(
        'ONYX detected a person requiring verification on Gate Camera at MS Vallee Residence.',
      ),
    );
    expect(message, contains('Current posture: boundary concern.'));
    expect(
      message,
      contains(
        'Reply APPROVE if the person is expected, REVIEW to keep the event open for manual checking, or ESCALATE if this person should be treated as suspicious.',
      ),
    );
  });

  test('formats client allowance prompt for remembered visitors', () {
    final message = service.formatClientAllowancePrompt(
      site: site,
      incident: MonitoringIncidentUpdate(
        occurredAt: DateTime.utc(2026, 3, 13, 21, 16),
        cameraLabel: 'Gate Camera',
        objectLabel: 'person',
        postureLabel: 'identity match concern',
      ),
      identityHint: 'Face PERSON-44 91.2%',
    );

    expect(message, contains('🛡️ ONYX Allowlist Option'));
    expect(
      message,
      contains(
        'ONYX has logged this person as expected on Gate Camera.',
      ),
    );
    expect(message, contains('Observed identity signal: Face PERSON-44 91.2%.'));
    expect(
      message,
      contains(
        'Reply ALLOW ONCE to keep this as a one-time approval, or ALWAYS ALLOW if ONYX should remember this person for future matches at MS Vallee Residence.',
      ),
    );
  });
}
