import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/telegram_admin_command_formatter.dart';

void main() {
  test('/pollops formatter includes CCTV pilot context', () {
    final response = TelegramAdminCommandFormatter.pollOps(
      pollResult: 'Ops poll • ok 4/4',
      radioHealth: 'ok 2 • fail 0 • skip 0 • last 10:05:00 UTC',
      cctvHealth:
          'ok 3 • fail 0 • skip 0 • last 10:05:01 UTC • 1/1 appended • frigate • CCTV person detected in north_gate',
      cctvContext:
          'provider frigate • recent video intel 5 (6h) • intrusion 2 • line_crossing 1 • motion 1 • fr 0 • lpr 0',
      wearableHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:02 UTC',
      listenerHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:02 UTC',
      newsHealth: 'ok 4 • fail 0 • skip 0 • last 10:05:03 UTC',
      utcStamp: '2026-03-13T10:05:10Z',
    );

    expect(response, contains('<b>CCTV:</b> ok 3 • fail 0 • skip 0'));
    expect(
      response,
      contains(
        '<b>CCTV Context:</b> provider frigate • recent video intel 5 (6h)',
      ),
    );
    expect(response, contains('run <code>/bridges</code>'));
  });

  test('/pollops formatter supports DVR video label', () {
    final response = TelegramAdminCommandFormatter.pollOps(
      pollResult: 'Ops poll • ok 4/4',
      radioHealth: 'ok 2 • fail 0 • skip 0 • last 10:05:00 UTC',
      cctvHealth:
          'ok 3 • fail 0 • skip 0 • last 10:05:01 UTC • 1/1 appended • hikvision-dvr • DVR vehicle detected in bay_2',
      cctvContext:
          'provider hikvision-dvr • recent video intel 5 (6h) • intrusion 2 • line_crossing 1 • motion 1 • fr 0 • lpr 1',
      wearableHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:02 UTC',
      listenerHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:02 UTC',
      newsHealth: 'ok 4 • fail 0 • skip 0 • last 10:05:03 UTC',
      utcStamp: '2026-03-13T10:05:10Z',
      videoLabel: 'DVR',
    );

    expect(response, contains('<b>DVR:</b> ok 3 • fail 0 • skip 0'));
    expect(
      response,
      contains(
        '<b>DVR Context:</b> provider hikvision-dvr • recent video intel 5 (6h)',
      ),
    );
  });

  test('/bridges formatter includes CCTV health and recent signal summaries', () {
    final response = TelegramAdminCommandFormatter.bridges(
      telegramStatus: 'READY • admin chat bound',
      radioStatus:
          'configured • pending 0 • due 0 • deferred 0 • max-attempt 0',
      cctvStatus:
          'configured • pilot edge • provider frigate • edge edge.example.com • caps LIVE AI MONITORING',
      cctvHealth:
          'ok 2 • fail 0 • skip 0 • last 10:05:01 UTC • 1/1 appended • frigate • CCTV person detected in north_gate',
      cctvRecent:
          'recent video intel 5 (6h) • intrusion 2 • line_crossing 1 • motion 1 • fr 0 • lpr 0',
      wearableStatus: 'configured',
      livePollingLabel: 'enabled',
      utcStamp: '2026-03-13T10:05:10Z',
    );

    expect(
      response,
      contains(
        'CCTV: configured • pilot edge • provider frigate • edge edge.example.com',
      ),
    );
    expect(response, contains('CCTV Health: ok 2 • fail 0 • skip 0'));
    expect(
      response,
      contains(
        'CCTV Recent: recent video intel 5 (6h) • intrusion 2 • line_crossing 1',
      ),
    );
  });

  test('/bridges formatter supports DVR health and recent signal labels', () {
    final response = TelegramAdminCommandFormatter.bridges(
      telegramStatus: 'READY • admin chat bound',
      radioStatus:
          'configured • pending 0 • due 0 • deferred 0 • max-attempt 0',
      cctvStatus:
          'configured • pilot dvr • provider hikvision-dvr • edge dvr.example.com • caps LIVE AI MONITORING',
      cctvHealth:
          'ok 2 • fail 0 • skip 0 • last 10:05:01 UTC • 1/1 appended • hikvision-dvr • DVR vehicle detected in bay_2',
      cctvRecent:
          'recent video intel 5 (6h) • intrusion 2 • line_crossing 1 • motion 1 • fr 0 • lpr 1',
      wearableStatus: 'configured',
      livePollingLabel: 'enabled',
      utcStamp: '2026-03-13T10:05:10Z',
      videoLabel: 'DVR',
    );

    expect(
      response,
      contains(
        'DVR: configured • pilot dvr • provider hikvision-dvr • edge dvr.example.com',
      ),
    );
    expect(response, contains('DVR Health: ok 2 • fail 0 • skip 0'));
    expect(
      response,
      contains(
        'DVR Recent: recent video intel 5 (6h) • intrusion 2 • line_crossing 1',
      ),
    );
  });

  test('morning governance formatter includes target-aware activity shortcuts', () {
    final response = TelegramAdminCommandFormatter.morningGovernance(
      signalHeader:
          '[GREEN] ONYX SIGNAL | critical=0 | inc=0 | guards=2 | telemetry=ready/OK | tg=READY | utc=2026-03-17T04:00:00Z',
      reportDate: '2026-03-17',
      generatedAtUtc: '2026-03-17T04:00:00Z',
      sceneReviewSummary: 'Incident 2 • Repeat 1 • Escalation 1 • Suppressed 0',
      globalReadinessHeadline: 'ELEVATED WATCH',
      globalReadinessSummary:
          'Critical 1 • Elevated 2 • Intents 3 • region north-cluster critical',
      globalReadinessEchoSummary:
          'Echo 2 • lead site-alpha • target site-bravo, site-charlie',
      globalReadinessTopIntentSummary:
          'POSTURAL ECHO • site-bravo • Raise CCTV perimeter attention',
      currentShiftReadinessFocusSummary:
          'Viewing live oversight shift 2026-03-17.',
      currentShiftReadinessReviewCommand: '/readinessreview 2026-03-17',
      currentShiftReadinessCaseFileCommand: '/readinesscase json 2026-03-17',
      currentShiftReadinessGovernanceCommand: '/readinessgovernance 2026-03-17',
      previousShiftReadinessFocusSummary:
          'Viewing command-targeted shift 2026-03-16 instead of live oversight 2026-03-17.',
      previousShiftReadinessReviewCommand: '/readinessreview 2026-03-16',
      previousShiftReadinessCaseFileCommand: '/readinesscase json 2026-03-16',
      previousShiftReadinessGovernanceCommand:
          '/readinessgovernance 2026-03-16',
      syntheticWarRoomHeadline: 'POLICY SHIFT',
      syntheticWarRoomSummary:
          'Plans 2 • region north-cluster • lead site-alpha • top intent POSTURAL ECHO',
      syntheticWarRoomPolicySummary:
          'Raise perimeter review priority for north-cluster during the next shift.',
      currentShiftSyntheticReviewCommand: '/syntheticreview 2026-03-17',
      currentShiftSyntheticCaseFileCommand: '/syntheticcase json 2026-03-17',
      previousShiftSyntheticReviewCommand: '/syntheticreview 2026-03-16',
      previousShiftSyntheticCaseFileCommand: '/syntheticcase json 2026-03-16',
      siteActivityHeadline: 'ACTIVITY RISING',
      siteActivitySummary:
          'Unknown or flagged site activity increased against recent shifts.',
      currentShiftReviewCommand: '/activityreview 2026-03-17',
      currentShiftCaseFileCommand: '/activitycase json 2026-03-17',
      previousShiftReviewCommand: '/activityreview 2026-03-16',
      previousShiftCaseFileCommand: '/activitycase json 2026-03-16',
      targetScopeRequired: true,
      targetScope: 'client-alpha/site-1',
      utcStamp: '2026-03-17T04:00:05Z',
    );

    expect(response, contains('<b>ONYX MORNING GOVERNANCE</b>'));
    expect(
      response,
      contains('<b>Target scope:</b> <code>client-alpha/site-1</code>'),
    );
    expect(response, contains('<code>/activityreview 2026-03-17</code>'));
    expect(response, contains('<code>/activitycase json 2026-03-16</code>'));
    expect(response, contains('<b>Global Readiness</b>'));
    expect(
      response,
      contains('<b>Focus:</b> Viewing live oversight shift 2026-03-17.'),
    );
    expect(response, contains('<b>Postural echo:</b> Echo 2'));
    expect(response, contains('<b>Top intent:</b> POSTURAL ECHO'));
    expect(response, contains('<code>/readinessreview 2026-03-17</code>'));
    expect(response, contains('<code>/readinesscase json 2026-03-16</code>'));
    expect(response, contains('<code>/readinessgovernance 2026-03-17</code>'));
    expect(
      response,
      contains(
        '<b>Previous focus:</b> Viewing command-targeted shift 2026-03-16 instead of live oversight 2026-03-17.',
      ),
    );
    expect(response, contains('<b>Synthetic War-Room</b>'));
    expect(response, contains('<b>Mode:</b> POLICY SHIFT'));
    expect(response, contains('<b>Summary:</b> Plans 2'));
    expect(response, contains('<code>/syntheticreview 2026-03-17</code>'));
    expect(response, contains('<code>/syntheticcase json 2026-03-16</code>'));
    expect(
      response,
      contains(
        '<b>Policy:</b> Raise perimeter review priority for north-cluster during the next shift.',
      ),
    );
    expect(
      response,
      contains('Activity shortcuts use the current target scope.'),
    );
  });

  test('morning governance formatter prompts for target scope when unset', () {
    final response = TelegramAdminCommandFormatter.morningGovernance(
      signalHeader: '[AMBER] ONYX SIGNAL',
      reportDate: '2026-03-17',
      generatedAtUtc: '2026-03-17T04:00:00Z',
      sceneReviewSummary: 'No review actions recorded.',
      siteActivityHeadline: 'ACTIVITY STABLE',
      siteActivitySummary: 'No visitor or site-activity signals detected.',
      currentShiftReviewCommand: '/activityreview 2026-03-17',
      currentShiftCaseFileCommand: '/activitycase json 2026-03-17',
      targetScopeRequired: true,
      utcStamp: '2026-03-17T04:00:05Z',
    );

    expect(response, contains('<b>Target scope:</b> required'));
    expect(
      response,
      contains(
        'Run <code>/settarget CLIENT SITE</code> before the activity shortcuts.',
      ),
    );
  });
}
