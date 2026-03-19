import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/monitoring_shift_notification_service.dart';
import 'package:omnix_dashboard/application/monitoring_shift_schedule_service.dart';
import 'package:omnix_dashboard/application/monitoring_watch_runtime_store.dart';
import 'package:omnix_dashboard/application/telegram_client_quick_action_service.dart';

void main() {
  const service = TelegramClientQuickActionService();
  const site = MonitoringSiteProfile(
    siteName: 'MS Vallee Residence',
    clientName: 'Muhammed Vallee',
  );
  const enterpriseSite = MonitoringSiteProfile(
    siteName: 'Sandton Tower',
    clientName: 'Sandton Corporate',
  );
  const schedule = MonitoringShiftSchedule(
    enabled: true,
    startHour: 18,
    startMinute: 0,
    endHour: 18,
    endMinute: 0,
  );

  test('parses supported client quick actions', () {
    expect(service.parseActionText('STATUS'), TelegramClientQuickAction.status);
    expect(
      service.parseActionText('status full'),
      TelegramClientQuickAction.statusFull,
    );
    expect(
      service.parseActionText('DETAILS'),
      TelegramClientQuickAction.statusFull,
    );
    expect(
      service.parseActionText('All in order?'),
      TelegramClientQuickAction.sleepCheck,
    );
    expect(service.parseActionText('REVIEW'), isNull);
  });

  test('builds concise active status response from watch runtime', () {
    final response = service.buildResponse(
      action: TelegramClientQuickAction.status,
      site: site,
      schedule: schedule,
      nowLocal: DateTime(2026, 3, 17, 22, 15),
      runtime: MonitoringWatchRuntimeState(
        startedAtUtc: DateTime.utc(2026, 3, 17, 16, 0),
        reviewedEvents: 6,
        primaryActivitySource: 'INNER PEDESTRIAN GATE',
        latestSceneReviewPostureLabel: 'monitored movement alert',
      ),
    );

    expect(response, contains('🛡️ ONYX STATUS'));
    expect(response, contains('Current status'));
    expect(response, contains('Monitoring is active.'));
    expect(response, contains('Watch window: 24h watch (started 18:00)'));
    expect(response, contains('What we see now'));
    expect(response, contains('Items reviewed: 6'));
    expect(response, contains('Latest signal: INNER PEDESTRIAN GATE'));
    expect(response, contains('Current posture: monitored movement alert'));
    expect(response, contains('Next'));
  });

  test('concise status includes current assessment when available', () {
    final response = service.buildResponse(
      action: TelegramClientQuickAction.status,
      site: site,
      schedule: schedule,
      nowLocal: DateTime(2026, 3, 18, 11, 4),
      fallbackReviewedEvents: 8,
      fallbackActivitySource: 'Camera 13',
      fallbackAssessmentLabel: 'likely routine on-site team activity',
      fallbackPostureLabel: 'multi-camera activity under review',
    );

    expect(
      response,
      contains('Assessment: likely routine on-site team activity'),
    );
  });

  test('does not treat expired runtime as an active watch window', () {
    const overnightSchedule = MonitoringShiftSchedule(
      enabled: true,
      startHour: 18,
      startMinute: 0,
      endHour: 6,
      endMinute: 0,
    );

    final response = service.buildResponse(
      action: TelegramClientQuickAction.statusFull,
      site: site,
      schedule: overnightSchedule,
      nowLocal: DateTime(2026, 3, 18, 8, 35),
      runtime: MonitoringWatchRuntimeState(
        startedAtUtc: DateTime.utc(2026, 3, 17, 16, 0),
        reviewedEvents: 0,
      ),
    );

    expect(response, contains('Monitoring is on standby.'));
    expect(response, contains('Watch window: next watch starts 18:00'));
  });

  test(
    'falls back to field activity when no watch review has been recorded',
    () {
      const overnightSchedule = MonitoringShiftSchedule(
        enabled: true,
        startHour: 18,
        startMinute: 0,
        endHour: 6,
        endMinute: 0,
      );

      final response = service.buildResponse(
        action: TelegramClientQuickAction.statusFull,
        site: site,
        schedule: overnightSchedule,
        nowLocal: DateTime(2026, 3, 18, 11, 4),
        fallbackReviewedEvents: 3,
        fallbackActivitySource: 'Front Yard',
        fallbackActivitySummary:
            'A guard checkpoint scan landed at Front Yard.',
        fallbackPostureLabel: 'field activity observed',
        fallbackReviewedAtLocal: DateTime(2026, 3, 18, 11, 2),
      );

      expect(response, contains('Items reviewed: 3'));
      expect(response, contains('Latest signal: Front Yard'));
      expect(response, contains('Current posture: field activity observed'));
      expect(response, isNot(contains('Assessment:')));
      expect(
        response,
        contains('Review note: A guard checkpoint scan landed at Front Yard.'),
      );
      expect(response, contains('Last check: 18/03/2026 11:02'));
    },
  );

  test('renders current site narrative when provided', () {
    final response = service.buildResponse(
      action: TelegramClientQuickAction.statusFull,
      site: site,
      schedule: schedule,
      nowLocal: DateTime(2026, 3, 18, 11, 4),
      fallbackReviewedEvents: 8,
      fallbackActivitySource: 'Camera 13',
      fallbackActivitySummary: 'AI-assisted review remains active.',
      fallbackAssessmentLabel: 'likely routine on-site team activity',
      fallbackNarrativeSummary:
          'Recent camera review saw person activity on Camera 13, Camera 12, and Camera 6, plus vehicle activity on Camera 5. Latest signal landed at 11:03.',
      fallbackPostureLabel: 'multi-camera activity under review',
      fallbackReviewedAtLocal: DateTime(2026, 3, 18, 11, 3),
    );

    expect(
      response,
      contains('Assessment: likely routine on-site team activity'),
    );
    expect(
      response,
      contains(
        'Summary: Recent camera review saw person activity on Camera 13, Camera 12, and Camera 6, plus vehicle activity on Camera 5. Latest signal landed at 11:03.',
      ),
    );
    expect(
      response,
      contains('Review note: AI-assisted review remains active.'),
    );
  });

  test(
    'prefers fresher scoped signal details over stale runtime source and summary',
    () {
      final response = service.buildResponse(
        action: TelegramClientQuickAction.statusFull,
        site: site,
        schedule: schedule,
        nowLocal: DateTime(2026, 3, 18, 15, 1),
        runtime: MonitoringWatchRuntimeState(
          startedAtUtc: DateTime.utc(2026, 3, 18, 13, 0),
          reviewedEvents: 875,
          primaryActivitySource: 'Camera 15',
          latestSceneReviewPostureLabel: 'escalation candidate',
          latestSceneReviewSummary: 'Metadata-only review.',
          latestSceneReviewUpdatedAtUtc: DateTime.utc(2026, 3, 18, 13, 18),
        ),
        fallbackActivitySource: 'Front Yard',
        fallbackActivitySummary: 'Front-yard movement detected.',
        fallbackNarrativeSummary:
            'Recent camera review saw 2 person signals across Back Yard and Front Yard, plus 1 vehicle signal across Driveway.',
        fallbackAssessmentLabel: 'likely routine on-site team activity',
        fallbackReviewedAtLocal: DateTime(2026, 3, 18, 15, 0),
      );

      expect(response, contains('Latest signal: Front Yard'));
      expect(response, contains('Review note: Front-yard movement detected.'));
      expect(response, contains('Last check: 18/03/2026 15:18'));
      expect(response, isNot(contains('Latest signal: Camera 15')));
      expect(response, isNot(contains('Review note: Metadata-only review.')));
    },
  );

  test('concise status includes field assessment when provided', () {
    final response = service.buildResponse(
      action: TelegramClientQuickAction.status,
      site: site,
      schedule: schedule,
      nowLocal: DateTime(2026, 3, 18, 11, 4),
      fallbackReviewedEvents: 3,
      fallbackActivitySource: 'Front Yard',
      fallbackAssessmentLabel: 'routine on-site team activity is visible',
      fallbackPostureLabel: 'field activity observed',
    );

    expect(
      response,
      contains('Assessment: routine on-site team activity is visible'),
    );
  });

  test('builds reassuring sleep-check response when no follow-up is open', () {
    final response = service.buildResponse(
      action: TelegramClientQuickAction.sleepCheck,
      site: site,
      schedule: schedule,
      nowLocal: DateTime(2026, 3, 17, 22, 30),
      runtime: MonitoringWatchRuntimeState(
        startedAtUtc: DateTime.utc(2026, 3, 17, 16, 0),
        reviewedEvents: 3,
        primaryActivitySource: 'MAIN GATE DRIVEWAY',
        latestSceneReviewPostureLabel: 'calm',
        unresolvedActionCount: 0,
      ),
    );

    expect(response, contains('🌙 ONYX SLEEP CHECK'));
    expect(response, contains('Monitoring is active.'));
    expect(response, contains('Latest signal: MAIN GATE DRIVEWAY'));
    expect(response, contains('Open follow-ups: 0'));
    expect(
      response,
      contains(
        'All looks steady right now. Rest easy and we will message you only if the picture changes.',
      ),
    );
  });

  test('uses more formal enterprise wording for quiet active status', () {
    final response = service.buildResponse(
      action: TelegramClientQuickAction.status,
      site: enterpriseSite,
      schedule: schedule,
      nowLocal: DateTime(2026, 3, 17, 22, 15),
      runtime: MonitoringWatchRuntimeState(
        startedAtUtc: DateTime.utc(2026, 3, 17, 16, 0),
        reviewedEvents: 4,
        primaryActivitySource: 'LOBBY',
        latestSceneReviewPostureLabel: 'calm',
        unresolvedActionCount: 0,
      ),
    );

    expect(
      response,
      contains(
        'ONYX remains on watch and will send an update only if something important changes.',
      ),
    );
    expect(
      response,
      isNot(
        contains(
          'ONYX stays close on watch and will message you only if something important changes.',
        ),
      ),
    );
  });

  test('uses warmer residential next-step wording for open follow-ups', () {
    final response = service.buildResponse(
      action: TelegramClientQuickAction.statusFull,
      site: site,
      schedule: schedule,
      nowLocal: DateTime(2026, 3, 17, 22, 15),
      runtime: MonitoringWatchRuntimeState(
        startedAtUtc: DateTime.utc(2026, 3, 17, 16, 0),
        reviewedEvents: 4,
        primaryActivitySource: 'FRONT YARD',
        latestSceneReviewPostureLabel: 'under review',
        unresolvedActionCount: 2,
      ),
    );

    expect(
      response,
      contains(
        'Next step: ONYX is tracking the open follow-ups and will share the next confirmed change here.',
      ),
    );
  });

  test('marks monitoring as unavailable when the site is offline', () {
    const offlineSchedule = MonitoringShiftSchedule(
      enabled: false,
      startHour: 18,
      startMinute: 0,
      endHour: 6,
      endMinute: 0,
    );

    final response = service.buildResponse(
      action: TelegramClientQuickAction.statusFull,
      site: site,
      schedule: offlineSchedule,
      nowLocal: DateTime(2026, 3, 18, 15, 20),
    );

    expect(response, contains('Remote monitoring is currently unavailable.'));
    expect(
      response,
      contains(
        'Watch window: remote monitoring is currently unavailable for this site',
      ),
    );
    expect(
      response,
      contains('Latest signal: Remote monitoring is offline for this site'),
    );
    expect(response, contains('Remote watch: unavailable'));
    expect(
      response,
      contains(
        'Next step: use this chat for any manual follow-up while the site is offline.',
      ),
    );
  });

  test('marks monitoring as limited when remote visibility is unstable', () {
    final response = service.buildResponse(
      action: TelegramClientQuickAction.statusFull,
      site: site,
      schedule: schedule,
      nowLocal: DateTime(2026, 3, 18, 15, 20),
      runtime: MonitoringWatchRuntimeState(
        startedAtUtc: DateTime.utc(2026, 3, 18, 13, 0),
        monitoringAvailable: false,
        monitoringAvailabilityDetail: 'One remote camera feed is stale.',
        unresolvedActionCount: 0,
      ),
    );

    expect(response, contains('Remote monitoring is active but limited.'));
    expect(
      response,
      contains('Watch window: 15:00-18:00 with limited remote visibility'),
    );
    expect(
      response,
      contains('Latest signal: Remote monitoring is limited for this site'),
    );
    expect(response, contains('Current posture: remote monitoring limited'));
    expect(response, contains('Remote watch: limited'));
    expect(response, contains('Review note: One remote camera feed is stale.'));
    expect(
      response,
      contains(
        'Next step: ONYX will keep watching, and we will use this chat if a manual follow-up or welfare check is needed.',
      ),
    );
  });
}
