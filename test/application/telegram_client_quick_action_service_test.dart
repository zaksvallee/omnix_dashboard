import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/client_camera_health_fact_packet_service.dart';
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
    expect(
      service.parseActionText('Check cameras'),
      TelegramClientQuickAction.cameraCheck,
    );
    expect(
      service.parseActionText('Camera status here'),
      TelegramClientQuickAction.cameraCheck,
    );
    expect(
      service.parseActionText('What do the cameras show'),
      TelegramClientQuickAction.cameraCheck,
    );
    expect(
      service.parseActionText('Review cameras'),
      TelegramClientQuickAction.cameraCheck,
    );
    expect(
      service.parseActionText('Camera review'),
      TelegramClientQuickAction.cameraCheck,
    );
    expect(
      service.parseActionText('Check the feeds'),
      TelegramClientQuickAction.cameraCheck,
    );
    expect(
      service.parseActionText('Review CCTV'),
      TelegramClientQuickAction.cameraCheck,
    );
    expect(
      service.parseActionText('What should I do next'),
      TelegramClientQuickAction.nextStep,
    );
    expect(
      service.parseActionText('Brief this site'),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseActionText('Brief the site'),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseActionText('Give me a quick update'),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseActionText('Give me an update here'),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseActionText('Any update on site'),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseActionText('Just update me'),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseActionText("What's happening there"),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseActionText("What's happening on site?"),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseActionText("What's happening at the site?"),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseActionText('Is my site secure?'),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseActionText("What's going on there"),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseActionText('Give me the site brief'),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseActionText('Status here'),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseActionText('site stauts'),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseActionText('whatst happednin at the siter'),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseActionText('anyting rong there'),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseActionText('is evrything oky'),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseActionText('How is everything?'),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseActionText('check site status'),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseActionText('What changed since earlier'),
      TelegramClientQuickAction.statusFull,
    );
    expect(
      service.parseActionText('What changed here'),
      TelegramClientQuickAction.statusFull,
    );
    expect(
      service.parseActionText('What changed since last check'),
      TelegramClientQuickAction.statusFull,
    );
    expect(
      service.parseActionText('Anything new there'),
      TelegramClientQuickAction.statusFull,
    );
    expect(
      service.parseActionText('Anything else there'),
      TelegramClientQuickAction.statusFull,
    );
    expect(
      service.parseActionText('What do the feeds show'),
      TelegramClientQuickAction.cameraCheck,
    );
    expect(
      service.parseActionText('Camera update'),
      TelegramClientQuickAction.cameraCheck,
    );
    expect(
      service.parseActionText('pls chek cameras'),
      TelegramClientQuickAction.cameraCheck,
    );
    expect(service.parseActionText('REVIEW'), isNull);
  });

  test(
    'only explicit shortcut texts route through live quick-action handling',
    () {
      expect(
        service.parseExplicitShortcutText('STATUS'),
        TelegramClientQuickAction.status,
      );
      expect(
        service.parseExplicitShortcutText('Details'),
        TelegramClientQuickAction.statusFull,
      );
      expect(
        service.parseExplicitShortcutText('Sleep check'),
        TelegramClientQuickAction.sleepCheck,
      );
      expect(
        service.parseExplicitShortcutText("What's happening on site?"),
        isNull,
      );
      expect(service.parseExplicitShortcutText('Give me an update'), isNull);
      expect(service.parseExplicitShortcutText('Check cameras'), isNull);
      expect(
        service.parseExplicitShortcutText('What should I do next'),
        isNull,
      );
    },
  );

  test('inbound quick-action parsing accepts conversational status asks', () {
    expect(
      service.parseInboundActionText("What's happening on site?"),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseInboundActionText('whats happenong now?'),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseInboundActionText('How is everything?'),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseInboundActionText('check site status'),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseInboundActionText('is the site okay?'),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseInboundActionText('Give me an update here'),
      TelegramClientQuickAction.status,
    );
    expect(
      service.parseInboundActionText('STATUS'),
      TelegramClientQuickAction.status,
    );
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

    expect(
      response,
      contains('MS Vallee Residence is under active watch right now.'),
    );
    expect(
      response,
      contains('There is site activity under review right now.'),
    );
    expect(
      response,
      contains(
        'ONYX will message you here only if something important changes.',
      ),
    );
    expect(response, isNot(contains('Items reviewed:')));
    expect(response, isNot(contains('Latest signal:')));
    expect(response, isNot(contains('Current posture:')));
    expect(response, isNot(contains('Open follow-ups:')));
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
      contains('Nothing here currently points to a confirmed issue on site.'),
    );
    expect(response, isNot(contains('Assessment:')));
  });

  test(
    'concise status prefers packetized issue labels over stale review heuristics',
    () {
      final response = service.buildResponse(
        action: TelegramClientQuickAction.status,
        site: site,
        schedule: schedule,
        nowLocal: DateTime(2026, 4, 5, 9, 14),
        cameraHealthFactPacket: ClientCameraHealthFactPacket(
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          siteReference: 'MS Vallee Residence',
          status: ClientCameraHealthStatus.limited,
          reason: ClientCameraHealthReason.unknown,
          path: ClientCameraHealthPath.hikConnectApi,
          lastSuccessfulVisualAtUtc: null,
          lastSuccessfulUpstreamProbeAtUtc: DateTime.utc(2026, 4, 5, 7, 14),
          liveSiteIssueStatus: ClientLiveSiteIssueStatus.recentSignals,
          recentIssueSignalLabel:
              'recent line-crossing signals around Front Gate',
          recentMovementHotspotLabel: 'Front Gate',
          nextAction: 'Verify the latest visual path.',
          safeClientExplanation:
              'Live camera visibility at MS Vallee Residence is limited right now.',
        ),
        fallbackReviewedEvents: 8,
        fallbackActivitySource: 'Camera 13',
        fallbackAssessmentLabel: 'multi-camera site activity under review',
        fallbackPostureLabel: 'multi-camera activity under review',
      );

      expect(
        response,
        contains(
          'I do not have full remote visibility, but the current signals still show recent line-crossing signals around Front Gate.',
        ),
      );
      expect(
        response,
        isNot(contains('There is site activity under review right now.')),
      );
    },
  );

  test(
    'concise status honors packet no-confirmed-issue truth over fallback posture text',
    () {
      final response = service.buildResponse(
        action: TelegramClientQuickAction.status,
        site: site,
        schedule: schedule,
        nowLocal: DateTime(2026, 4, 5, 9, 14),
        cameraHealthFactPacket: ClientCameraHealthFactPacket(
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          siteReference: 'MS Vallee Residence',
          status: ClientCameraHealthStatus.live,
          reason: ClientCameraHealthReason.legacyProxyActive,
          path: ClientCameraHealthPath.legacyLocalProxy,
          lastSuccessfulVisualAtUtc: DateTime.utc(2026, 4, 5, 7, 13),
          lastSuccessfulUpstreamProbeAtUtc: DateTime.utc(2026, 4, 5, 7, 13),
          liveSiteIssueStatus: ClientLiveSiteIssueStatus.noConfirmedIssue,
          nextAction: 'Keep the interim bridge in place.',
          safeClientExplanation:
              'We currently have visual confirmation at MS Vallee Residence.',
        ),
        fallbackReviewedEvents: 5,
        fallbackActivitySource: 'Front Gate',
        fallbackAssessmentLabel: 'multi-camera site activity under review',
        fallbackPostureLabel: 'field activity observed',
        runtime: MonitoringWatchRuntimeState(
          startedAtUtc: DateTime.utc(2026, 4, 5, 7, 0),
          unresolvedActionCount: 1,
        ),
      );

      expect(
        response,
        contains(
          'Nothing in the current signals currently points to a confirmed issue on site.',
        ),
      );
      expect(
        response,
        isNot(contains('There is site activity under review right now.')),
      );
    },
  );

  test(
    'concise status prefers packet offline truth over runtime limited availability',
    () {
      final response = service.buildResponse(
        action: TelegramClientQuickAction.status,
        site: site,
        schedule: schedule,
        nowLocal: DateTime(2026, 4, 5, 9, 14),
        cameraHealthFactPacket: ClientCameraHealthFactPacket(
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          siteReference: 'MS Vallee Residence',
          status: ClientCameraHealthStatus.offline,
          reason: ClientCameraHealthReason.bridgeOffline,
          path: ClientCameraHealthPath.legacyLocalProxy,
          lastSuccessfulVisualAtUtc: null,
          lastSuccessfulUpstreamProbeAtUtc: null,
          liveSiteIssueStatus: ClientLiveSiteIssueStatus.noConfirmedIssue,
          nextAction: 'Restore the current bridge path.',
          safeClientExplanation:
              'Live camera visibility at MS Vallee Residence is unavailable right now.',
        ),
        runtime: MonitoringWatchRuntimeState(
          startedAtUtc: DateTime.utc(2026, 4, 5, 7, 0),
          monitoringAvailable: false,
        ),
      );

      expect(
        response,
        contains(
          'Remote monitoring is not active for this site right now.',
        ),
      );
      expect(response, isNot(contains('remote visibility is limited')));
    },
  );

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

    expect(
      response,
      contains('MS Vallee Residence is outside an active watch window'),
    );
    expect(response, contains('The next scheduled watch starts at 18:00.'));
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
      contains('Nothing here currently points to a confirmed issue on site.'),
    );
    expect(response, isNot(contains('Assessment:')));
  });

  test(
    'concise status stays client-safe when remote monitoring is unavailable',
    () {
      const offlineSchedule = MonitoringShiftSchedule(
        enabled: false,
        startHour: 18,
        startMinute: 0,
        endHour: 6,
        endMinute: 0,
      );

      final response = service.buildResponse(
        action: TelegramClientQuickAction.status,
        site: site,
        schedule: offlineSchedule,
        nowLocal: DateTime(2026, 4, 4, 8, 53),
        fallbackReviewedEvents: 19,
        fallbackActivitySource: 'Camera 11',
        fallbackAssessmentLabel: 'multi-camera site activity under review',
        fallbackPostureLabel: 'field activity observed',
      );

      expect(
        response,
        'Remote monitoring is not active for this site right now. Camera worker may be offline. I do not have full remote visibility, and nothing here confirms an issue on site. Message here if you want a manual follow-up.',
      );
      expect(response, isNot(contains('Items reviewed:')));
      expect(response, isNot(contains('Current posture:')));
      expect(response, isNot(contains('Open follow-ups:')));
      expect(response, isNot(contains('Assessment:')));
    },
  );

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

    expect(response, contains('MS Vallee Residence is under active watch'));
    expect(response, contains('The site is on a 24-hour watch cycle.'));
    expect(response, contains('Latest signal: MAIN GATE DRIVEWAY'));
    expect(response, contains('Open follow-ups: 0'));
    expect(
      response,
      contains(
        'All looks steady right now. Rest easy and we will message you only if the picture changes.',
      ),
    );
  });

  test('builds dedicated camera-check response for natural camera prompts', () {
    final response = service.buildResponse(
      action: TelegramClientQuickAction.cameraCheck,
      site: site,
      schedule: schedule,
      nowLocal: DateTime(2026, 3, 18, 22, 15),
      fallbackReviewedEvents: 5,
      fallbackActivitySource: 'Front Yard',
      fallbackActivitySummary: 'Front-yard movement detected.',
      fallbackAssessmentLabel: 'routine on-site team activity is visible',
      fallbackPostureLabel: 'field activity observed',
      fallbackReviewedAtLocal: DateTime(2026, 3, 18, 22, 12),
    );

    expect(
      response,
      contains(
        'The latest camera picture for MS Vallee Residence is based on 5 reviewed items.',
      ),
    );
    expect(response, contains('Latest signal: Front Yard'));
    expect(response, contains('Review note: Front-yard movement detected.'));
    expect(response, contains('Last check: 18/03/2026 22:12'));
  });

  test(
    'camera-check uses packet camera-health truth instead of a fabricated camera picture when visibility is limited',
    () {
      final response = service.buildResponse(
        action: TelegramClientQuickAction.cameraCheck,
        site: site,
        schedule: schedule,
        nowLocal: DateTime(2026, 4, 5, 20, 58),
        cameraHealthFactPacket: ClientCameraHealthFactPacket(
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          siteReference: 'MS Vallee Residence',
          status: ClientCameraHealthStatus.limited,
          reason: ClientCameraHealthReason.unknown,
          path: ClientCameraHealthPath.directRecorder,
          lastSuccessfulVisualAtUtc: null,
          lastSuccessfulUpstreamProbeAtUtc: DateTime.utc(2026, 4, 5, 18, 55),
          liveSiteIssueStatus: ClientLiveSiteIssueStatus.noConfirmedIssue,
          nextAction: 'Verify the latest visual path.',
          safeClientExplanation:
              'Live camera visibility at MS Vallee Residence is limited right now while I verify the latest view.',
        ),
        fallbackReviewedEvents: 19,
        fallbackActivitySource: 'Response arrival',
        fallbackActivitySummary:
            'A response-arrival signal was logged through ONYX field telemetry.',
        fallbackAssessmentLabel: 'routine on-site team activity is visible',
        fallbackPostureLabel: 'field activity observed',
        fallbackReviewedAtLocal: DateTime(2026, 4, 5, 21, 0),
      );

      expect(
        response,
        contains(
          'Live camera visibility at MS Vallee Residence is limited right now while I verify the latest view.',
        ),
      );
      expect(
        response,
        isNot(contains('The latest camera picture for MS Vallee Residence')),
      );
      expect(response, isNot(contains('Latest signal: Response arrival.')));
      expect(response, isNot(contains('Review note:')));
    },
  );

  test('builds dedicated next-step response for natural next-step prompts', () {
    final response = service.buildResponse(
      action: TelegramClientQuickAction.nextStep,
      site: site,
      schedule: schedule,
      nowLocal: DateTime(2026, 3, 18, 22, 15),
      fallbackAssessmentLabel: 'routine on-site team activity is visible',
      runtime: MonitoringWatchRuntimeState(
        startedAtUtc: DateTime.utc(2026, 3, 18, 16, 0),
        unresolvedActionCount: 1,
        latestSceneDecisionSummary: 'Control is checking cameras now.',
      ),
    );

    expect(
      response,
      contains('MS Vallee Residence is under active watch right now.'),
    );
    expect(response, contains('Open follow-ups: 1'));
    expect(
      response,
      contains('Current decision: Control is checking cameras now.'),
    );
    expect(
      response,
      contains(
        'Next step: ONYX is tracking the open follow-ups and will share the next confirmed change here.',
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
        'ONYX will send an update here only if something important changes.',
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

    expect(
      response,
      contains('MS Vallee Residence is temporarily without remote monitoring'),
    );
    expect(
      response,
      contains(
        'Remote watch is temporarily unavailable while the monitoring path is offline.',
      ),
    );
    expect(
      response,
      contains('Latest signal: Remote monitoring is offline for this site'),
    );
    expect(response, contains('Remote watch is unavailable.'));
    expect(
      response,
      contains(
        'Next step: use this chat if you want a manual follow-up while remote monitoring is offline.',
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

    expect(
      response,
      contains(
        'MS Vallee Residence is under watch with limited remote visibility',
      ),
    );
    expect(
      response,
      contains(
        'The current watch window runs 15:00-18:00, with limited remote visibility.',
      ),
    );
    expect(
      response,
      contains('Latest signal: Remote monitoring is limited for this site'),
    );
    expect(response, contains('Current posture: remote monitoring limited'));
    expect(response, contains('Remote watch is limited.'));
    expect(response, contains('Review note: One remote camera feed is stale.'));
    expect(
      response,
      contains(
        'Next step: ONYX will keep watching, and we will use this chat if a manual follow-up or welfare check is needed.',
      ),
    );
  });
}
