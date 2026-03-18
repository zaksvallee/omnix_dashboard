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
    expect(response, contains('Monitoring: ACTIVE'));
    expect(response, contains('Window: 24h watch (started 18:00)'));
    expect(response, contains('Reviewed activity: 6'));
    expect(response, contains('Latest activity: INNER PEDESTRIAN GATE'));
    expect(response, contains('Latest posture: monitored movement alert'));
  });

  test('concise status includes current assessment when available', () {
    final response = service.buildResponse(
      action: TelegramClientQuickAction.status,
      site: site,
      schedule: schedule,
      nowLocal: DateTime(2026, 3, 18, 11, 4),
      fallbackReviewedEvents: 8,
      fallbackActivitySource: 'Camera 13',
      fallbackAssessmentLabel: 'likely routine distributed field activity',
      fallbackPostureLabel: 'multi-camera activity under review',
    );

    expect(
      response,
      contains(
        'Current assessment: likely routine distributed field activity',
      ),
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

    expect(response, contains('Monitoring: STANDBY'));
    expect(response, contains('Window: next watch starts 18:00'));
  });

  test('falls back to field activity when no watch review has been recorded', () {
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
          'A worker checkpoint scan landed at Front Yard.',
      fallbackPostureLabel: 'field activity observed',
      fallbackReviewedAtLocal: DateTime(2026, 3, 18, 11, 2),
    );

    expect(response, contains('Reviewed activity: 3'));
    expect(response, contains('Latest activity source: Front Yard'));
    expect(response, contains('Latest posture: field activity observed'));
    expect(response, isNot(contains('Current assessment:')));
    expect(
      response,
      contains('Latest review summary: A worker checkpoint scan landed at Front Yard.'),
    );
    expect(response, contains('Last reviewed at: 18/03/2026 11:02'));
  });

  test('renders current site narrative when provided', () {
    final response = service.buildResponse(
      action: TelegramClientQuickAction.statusFull,
      site: site,
      schedule: schedule,
      nowLocal: DateTime(2026, 3, 18, 11, 4),
      fallbackReviewedEvents: 8,
      fallbackActivitySource: 'Camera 13',
      fallbackActivitySummary: 'AI-assisted review remains active.',
      fallbackAssessmentLabel: 'likely routine distributed field activity',
      fallbackNarrativeSummary:
          'Recent ONYX review saw person activity on Camera 13, Camera 12, and Camera 6, plus vehicle activity on Camera 5. Latest signal landed at 11:03.',
      fallbackPostureLabel: 'multi-camera activity under review',
      fallbackReviewedAtLocal: DateTime(2026, 3, 18, 11, 3),
    );

    expect(
      response,
      contains(
        'Current assessment: likely routine distributed field activity',
      ),
    );
    expect(
      response,
      contains(
        'Current site narrative: Recent ONYX review saw person activity on Camera 13, Camera 12, and Camera 6, plus vehicle activity on Camera 5. Latest signal landed at 11:03.',
      ),
    );
    expect(response, contains('Latest review summary: AI-assisted review remains active.'));
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
            'Recent ONYX review saw 2 person signals across Back Yard and Front Yard, plus 1 vehicle signal across Driveway.',
        fallbackAssessmentLabel: 'likely routine distributed field activity',
        fallbackReviewedAtLocal: DateTime(2026, 3, 18, 15, 0),
      );

      expect(response, contains('Latest activity source: Front Yard'));
      expect(
        response,
        contains('Latest review summary: Front-yard movement detected.'),
      );
      expect(response, contains('Last reviewed at: 18/03/2026 15:18'));
      expect(response, isNot(contains('Latest activity source: Camera 15')));
      expect(response, isNot(contains('Latest review summary: Metadata-only review.')));
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
      fallbackAssessmentLabel: 'field activity active on site',
      fallbackPostureLabel: 'field activity observed',
    );

    expect(response, contains('Current assessment: field activity active on site'));
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
    expect(response, contains('Monitoring: ACTIVE'));
    expect(response, contains('Latest activity: MAIN GATE DRIVEWAY'));
    expect(response, contains('Open follow-up actions: 0'));
    expect(response, contains('All in order right now. Sleep well.'));
  });
}
