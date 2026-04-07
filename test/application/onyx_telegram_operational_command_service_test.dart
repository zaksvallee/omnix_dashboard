import 'package:omnix_dashboard/application/client_camera_health_fact_packet_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/onyx_telegram_command_gateway.dart';
import 'package:omnix_dashboard/application/onyx_telegram_operational_command_service.dart';
import 'package:omnix_dashboard/domain/authority/onyx_authority_scope.dart';
import 'package:omnix_dashboard/domain/authority/onyx_command_intent.dart';
import 'package:omnix_dashboard/domain/authority/telegram_scope_binding.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/incident_closed.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/patrol_completed.dart';

void main() {
  const service = OnyxTelegramOperationalCommandService();
  const binding = TelegramScopeBinding(
    telegramGroupId: 'tg-sandton',
    allowedClientIds: {'CLIENT-SANDTON'},
    allowedSiteIds: {'SITE-SANDTON', 'SITE-VALLEE'},
    allowedActions: {
      OnyxAuthorityAction.read,
      OnyxAuthorityAction.propose,
      OnyxAuthorityAction.stage,
    },
  );

  test('telegram operational service carries gateway denial forward', () {
    final response = service.handle(
      request: const OnyxTelegramCommandRequest(
        telegramUserId: 'tg-user-17',
        telegramGroupId: 'tg-sandton',
        role: OnyxAuthorityRole.supervisor,
        prompt: 'Show Vallee Residence incidents',
        groupBinding: TelegramScopeBinding(
          telegramGroupId: 'tg-sandton',
          allowedClientIds: {'CLIENT-SANDTON'},
          allowedSiteIds: {'SITE-SANDTON'},
        ),
        userAllowedClientIds: {'CLIENT-SANDTON'},
        userAllowedSiteIds: {'SITE-SANDTON'},
        requestedClientId: 'CLIENT-SANDTON',
        requestedSiteId: 'SITE-VALLEE',
        requestedSiteLabel: 'Vallee Residence',
      ),
      events: const [],
    );

    expect(response.handled, isTrue);
    expect(response.allowed, isFalse);
    expect(
      response.text,
      'Restricted access. This Telegram group is not authorized for Vallee Residence.\n'
      'Try this room instead: "show dispatches today", "check status of Guard001", or "show incidents last night".',
    );
  });

  test(
    'telegram operational service keeps the messy client conversational matrix stable',
    () {
      final now = DateTime.now().toUtc();

      List<DispatchEvent> buildStatusResolvedEvents() => <DispatchEvent>[
        IntelligenceReceived(
          eventId: 'client-status-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 18)),
          intelligenceId: 'INT-CS-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-cs-1',
          clientId: 'CLIENT-SANDTON',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          headline: 'Front gate movement',
          summary: 'Movement was detected near the front gate.',
          riskScore: 54,
          canonicalHash: 'hash-cs-1',
        ),
        DecisionCreated(
          eventId: 'client-status-decision-1',
          sequence: 2,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 17)),
          dispatchId: 'DSP-CS-1',
          clientId: 'CLIENT-SANDTON',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
        ),
        IncidentClosed(
          eventId: 'client-status-closed-1',
          sequence: 3,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 9)),
          dispatchId: 'DSP-CS-1',
          resolutionType: 'all_clear',
          clientId: 'CLIENT-SANDTON',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
        ),
      ];

      List<DispatchEvent> buildVerificationEvents() => <DispatchEvent>[
        IntelligenceReceived(
          eventId: 'client-verify-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 6)),
          intelligenceId: 'INT-CV-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-cv-1',
          clientId: 'CLIENT-SANDTON',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          zone: 'Front Gate',
          headline: 'Front gate alert',
          summary: 'Person detected near the front gate.',
          riskScore: 68,
          canonicalHash: 'hash-cv-1',
        ),
      ];

      List<DispatchEvent> buildAlarmEvents() => <DispatchEvent>[
        IntelligenceReceived(
          eventId: 'client-serious-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 11)),
          intelligenceId: 'INT-CA-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-ca-1',
          clientId: 'CLIENT-SANDTON',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          headline: 'Perimeter breach alert',
          summary: 'Repeated movement triggered the perimeter alarm.',
          riskScore: 86,
          canonicalHash: 'hash-ca-1',
        ),
        DecisionCreated(
          eventId: 'client-serious-decision-1',
          sequence: 2,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 9)),
          dispatchId: 'DSP-CA-1',
          clientId: 'CLIENT-SANDTON',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
        ),
      ];

      final cases =
          <
            ({
              String prompt,
              List<DispatchEvent> events,
              OnyxCommandIntent expectedIntent,
              List<String> expected,
              List<String> excluded,
            })
          >[
            (
              prompt: 'whatst happednin at the siter',
              events: buildStatusResolvedEvents(),
              expectedIntent: OnyxCommandIntent.triageNextMove,
              expected: const <String>[
                'I do not see a confirmed issue at Sandton Estate right now.',
                'It is not an active incident now.',
                'I do not have live visual confirmation right now.',
              ],
              excluded: const <String>[],
            ),
            (
              prompt: 'is evrything okay',
              events: const <DispatchEvent>[],
              expectedIntent: OnyxCommandIntent.triageNextMove,
              expected: const <String>[
                'I do not see a confirmed issue at Sandton Estate right now.',
                'I do not have live visual confirmation right now.',
              ],
              excluded: const <String>['Unsupported command'],
            ),
            (
              prompt: 'is the site okay?',
              events: const <DispatchEvent>[],
              expectedIntent: OnyxCommandIntent.triageNextMove,
              expected: const <String>[
                'I do not see a confirmed issue at Sandton Estate right now.',
                'I do not have live visual confirmation right now.',
              ],
              excluded: const <String>['Unsupported command'],
            ),
            (
              prompt: 'whats happenong at the siter',
              events: buildStatusResolvedEvents(),
              expectedIntent: OnyxCommandIntent.triageNextMove,
              expected: const <String>[
                'I do not see a confirmed issue at Sandton Estate right now.',
                'It is not an active incident now.',
                'I do not have live visual confirmation right now.',
              ],
              excluded: const <String>[],
            ),
            (
              prompt: 'pls check front gate',
              events: buildVerificationEvents(),
              expectedIntent: OnyxCommandIntent.triageNextMove,
              expected: const <String>[
                'The latest verified activity near Front Gate was',
                'I do not have live visual confirmation on Front Gate',
              ],
              excluded: const <String>['appears closed'],
            ),
            (
              prompt: 'was tht alrm serious',
              events: buildAlarmEvents(),
              expectedIntent: OnyxCommandIntent.summarizeIncident,
              expected: const <String>[
                'It was treated as a serious signal.',
                'Response is still active.',
                'I do not have live visual confirmation',
              ],
              excluded: const <String>[],
            ),
            (
              prompt: 'I heard something outside',
              events: const <DispatchEvent>[],
              expectedIntent: OnyxCommandIntent.triageNextMove,
              expected: const <String>[
                "I'm treating that as a live concern.",
                'I do not see a confirmed active incident in the current operational picture.',
                'I do not have live visual confirmation right now.',
                'I can have the outside area verified immediately.',
              ],
              excluded: const <String>[],
            ),
          ];

      for (var index = 0; index < cases.length; index += 1) {
        final scenario = cases[index];
        final response = service.handle(
          request: OnyxTelegramCommandRequest(
            telegramUserId: 'tg-client-conversation-$index',
            telegramGroupId: 'tg-sandton',
            role: OnyxAuthorityRole.client,
            prompt: scenario.prompt,
            groupBinding: binding,
            userAllowedClientIds: const {'CLIENT-SANDTON'},
            userAllowedSiteIds: const {'SITE-SANDTON'},
            requestedClientId: 'CLIENT-SANDTON',
            requestedSiteId: 'SITE-SANDTON',
            requestedSiteLabel: 'Sandton Estate',
          ),
          events: scenario.events,
        );

        expect(response.handled, isTrue, reason: scenario.prompt);
        expect(response.allowed, isTrue, reason: scenario.prompt);
        expect(
          response.intent,
          scenario.expectedIntent,
          reason: scenario.prompt,
        );
        for (final text in scenario.expected) {
          expect(response.text, contains(text), reason: scenario.prompt);
        }
        for (final text in scenario.excluded) {
          expect(response.text, isNot(contains(text)), reason: scenario.prompt);
        }
      }
    },
  );

  test(
    'telegram operational service humanizes raw hikvision event metadata for client status replies',
    () {
      final now = DateTime.now().toUtc();
      final response = service.handle(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-hik-status',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt: 'whats happening?',
          groupBinding: binding,
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
        ),
        events: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'hik-status-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 4)),
            intelligenceId: 'INT-HIK-1',
            provider: 'hikvision_dvr_monitor_only',
            sourceType: 'dvr',
            externalId: 'evt-hik-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            cameraId: 'channel-11',
            headline: 'HIKVISION_DVR_MONITOR_ONLY VIDEO_EVENT',
            summary:
                'provider:hikvision_dvr_monitor_only | camera:channel-11 | channel:11 | snapshot:pending',
            riskScore: 58,
            canonicalHash: 'hash-hik-1',
          ),
        ],
      );

      expect(response.handled, isTrue);
      expect(response.allowed, isTrue);
      expect(response.intent, OnyxCommandIntent.triageNextMove);
      expect(response.text, contains('a recorder event on Camera 11'));
      expect(
        response.text,
        contains('I do not have live visual confirmation right now.'),
      );
      expect(
        response.text,
        isNot(contains('provider:hikvision_dvr_monitor_only')),
      );
      expect(response.text, isNot(contains('stable at the moment')));
      expect(response.text, isNot(contains('current operational picture')));
    },
  );

  test(
    'telegram operational service deduplicates whitespace in derived scope labels',
    () {
      final response = service.handle(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-whitespace-scope',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt: 'is everything okay',
          groupBinding: TelegramScopeBinding(
            telegramGroupId: 'tg-sandton',
            allowedClientIds: {'CLIENT-SANDTON'},
            allowedSiteIds: {'SITE__MS   VALLEE'},
            allowedActions: {
              OnyxAuthorityAction.read,
              OnyxAuthorityAction.propose,
              OnyxAuthorityAction.stage,
            },
          ),
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE__MS   VALLEE'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE__MS   VALLEE',
        ),
        events: const <DispatchEvent>[],
      );

      expect(response.handled, isTrue);
      expect(response.allowed, isTrue);
      expect(response.text, contains('Site Ms Vallee'));
      expect(response.text, isNot(contains('Site Ms   Vallee')));
    },
  );

  test(
    'telegram operational service surfaces normalized video-loss signals without implying movement',
    () {
      final now = DateTime.now().toUtc();
      final response = service.handle(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-hik-video-loss',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt: 'whats happening?',
          groupBinding: binding,
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
        ),
        events: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'hik-video-loss-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 3)),
            intelligenceId: 'INT-HIK-VIDLOSS-1',
            provider: 'hikvision_dvr_monitor_only',
            sourceType: 'dvr',
            externalId: 'evt-hik-vidloss-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            cameraId: 'channel-11',
            headline: 'HIKVISION_DVR_MONITOR_ONLY VIDEO_LOSS',
            summary:
                'provider:hikvision_dvr_monitor_only | camera:channel-11 | channel:11 | snapshot:pending',
            riskScore: 18,
            canonicalHash: 'hash-hik-vidloss-1',
          ),
        ],
      );

      expect(response.handled, isTrue);
      expect(response.allowed, isTrue);
      expect(response.text, contains('a video-loss signal on Camera 11'));
      expect(response.text, isNot(contains('motion')));
      expect(response.text, isNot(contains('a recorder event')));
    },
  );

  test(
    'telegram operational service hides detector branding in client semantic status replies',
    () {
      final now = DateTime.now().toUtc();
      final response = service.handle(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-yolo-status',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt: 'whats happening on site?',
          groupBinding: binding,
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
        ),
        events: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'yolo-status-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 2)),
            intelligenceId: 'INT-YOLO-1',
            provider: 'hikvision_dvr_yolo',
            sourceType: 'dvr',
            externalId: 'evt-yolo-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            cameraId: 'channel-4',
            objectLabel: 'vehicle',
            headline: 'YOLO detected vehicle activity near Camera channel-4',
            summary:
                'YOLO detected vehicle activity. Confidence 0.84. Ultralytics detected vehicle activity.',
            riskScore: 61,
            canonicalHash: 'hash-yolo-1',
          ),
        ],
      );

      expect(response.handled, isTrue);
      expect(response.allowed, isTrue);
      expect(response.intent, OnyxCommandIntent.triageNextMove);
      expect(response.text, contains('vehicle movement on Camera 4'));
      expect(response.text, isNot(contains('YOLO')));
      expect(response.text, isNot(contains('Ultralytics')));
      expect(response.text, isNot(contains('Confidence 0.84')));
    },
  );

  test(
    'telegram operational service humanizes hik-connect face-match alerts without leaking FR metadata',
    () {
      final now = DateTime.now().toUtc();
      final response = service.handle(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-hik-fr-status',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt: 'whats happening on site?',
          groupBinding: binding,
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
        ),
        events: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'hik-fr-status-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 2)),
            intelligenceId: 'INT-HIK-FR-1',
            provider: 'hik_connect_openapi',
            sourceType: 'dvr',
            externalId: 'evt-hik-fr-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            cameraId: 'camera-lobby',
            zone: 'Reception',
            objectLabel: 'person',
            faceMatchId: 'RESIDENT-44',
            faceConfidence: 91.2,
            headline: 'HIK_CONNECT_OPENAPI FR_MATCH',
            summary:
                'provider:hik_connect_openapi | camera:Lobby Camera | area:Reception | rule:Face Match | FR:RESIDENT-44 | snapshot:missing | clip:not_expected',
            riskScore: 82,
            canonicalHash: 'hash-hik-fr-1',
          ),
        ],
      );

      expect(response.handled, isTrue);
      expect(response.allowed, isTrue);
      expect(response.intent, OnyxCommandIntent.triageNextMove);
      expect(response.text, contains('person movement on Lobby Camera'));
      expect(
        response.text,
        contains('I do not have live visual confirmation right now.'),
      );
      expect(response.text, isNot(contains('FR_MATCH')));
      expect(response.text, isNot(contains('FR:RESIDENT-44')));
      expect(response.text, isNot(contains('Face Match')));
      expect(response.text, isNot(contains('provider:hik_connect_openapi')));
    },
  );

  test(
    'telegram operational service handles canonical current-site-view phrasing without falling through to unsupported fallback',
    () {
      final now = DateTime.now().toUtc();
      final response = service.handle(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-canonical-status',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt: 'what is happening on site?',
          groupBinding: binding,
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
        ),
        events: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'canonical-status-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 2)),
            intelligenceId: 'INT-CANONICAL-1',
            provider: 'hikvision_dvr_yolo',
            sourceType: 'dvr',
            externalId: 'evt-canonical-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            cameraId: 'channel-4',
            objectLabel: 'vehicle',
            headline: 'YOLO detected vehicle activity near Camera channel-4',
            summary:
                'YOLO detected vehicle activity. Confidence 0.84. Ultralytics detected vehicle activity.',
            riskScore: 61,
            canonicalHash: 'hash-canonical-1',
          ),
        ],
      );

      expect(response.handled, isTrue);
      expect(response.allowed, isTrue);
      expect(response.intent, OnyxCommandIntent.triageNextMove);
      expect(response.text, contains('vehicle movement on Camera 4'));
      expect(
        response.text,
        isNot(
          contains(
            'ONYX understood the request, but this Telegram command is not wired yet.',
          ),
        ),
      );
    },
  );

  test(
    'telegram operational service answers generic movement-detected asks with movement-focused truth',
    () {
      final now = DateTime.now().toUtc();
      final response = service.handle(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-movement-status',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt: 'is there any movement detected?',
          groupBinding: binding,
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
        ),
        events: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'movement-status-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 2)),
            intelligenceId: 'INT-MOVEMENT-1',
            provider: 'hikvision_dvr_yolo',
            sourceType: 'dvr',
            externalId: 'evt-movement-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            cameraId: 'channel-4',
            objectLabel: 'vehicle',
            headline: 'YOLO detected vehicle activity near Camera channel-4',
            summary:
                'YOLO detected vehicle activity. Confidence 0.84. Ultralytics detected vehicle activity.',
            riskScore: 61,
            canonicalHash: 'hash-movement-1',
          ),
        ],
      );

      expect(response.handled, isTrue);
      expect(response.allowed, isTrue);
      expect(response.intent, OnyxCommandIntent.triageNextMove);
      expect(
        response.text,
        contains(
          'The latest verified movement on site was vehicle movement on Camera 4 at',
        ),
      );
      expect(
        response.text,
        contains('It is not sitting as an open incident at the moment.'),
      );
      expect(
        response.text,
        isNot(
          contains(
            'ONYX understood the request, but this Telegram command is not wired yet.',
          ),
        ),
      );
    },
  );

  test(
    'telegram operational service routes issue-on-site asks into deterministic status reassurance replies',
    () {
      final now = DateTime.now().toUtc();
      final response = service.handle(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-issue-status',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt: 'is there any issue on site?',
          groupBinding: binding,
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
        ),
        events: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'issue-status-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 2)),
            intelligenceId: 'INT-ISSUE-1',
            provider: 'hikvision_dvr_yolo',
            sourceType: 'dvr',
            externalId: 'evt-issue-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            cameraId: 'channel-4',
            objectLabel: 'vehicle',
            headline: 'YOLO detected vehicle activity near Camera channel-4',
            summary:
                'YOLO detected vehicle activity. Confidence 0.84. Ultralytics detected vehicle activity.',
            riskScore: 61,
            canonicalHash: 'hash-issue-1',
          ),
        ],
      );

      expect(response.handled, isTrue);
      expect(response.allowed, isTrue);
      expect(
        response.text,
        contains('I do not see a confirmed issue at Sandton Estate right now.'),
      );
      expect(
        response.text,
        isNot(
          contains(
            'ONYX understood the request, but this Telegram command is not wired yet.',
          ),
        ),
      );
    },
  );

  test(
    'telegram operational service uses scoped live visual confirmation for generic client status replies when camera facts are live',
    () {
      final now = DateTime.now().toUtc();
      final response = service.handle(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-hik-status-live',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt: 'whats happening right now?',
          groupBinding: binding,
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
        ),
        events: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'hik-status-live-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 4)),
            intelligenceId: 'INT-HIK-LIVE-1',
            provider: 'hikvision_dvr_monitor_only',
            sourceType: 'dvr',
            externalId: 'evt-hik-live-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            cameraId: 'channel-11',
            headline: 'HIKVISION_DVR_MONITOR_ONLY VIDEO_EVENT',
            summary:
                'provider:hikvision_dvr_monitor_only | camera:channel-11 | channel:11 | snapshot:pending',
            riskScore: 58,
            canonicalHash: 'hash-hik-live-1',
          ),
        ],
        cameraHealthFactPacket: ClientCameraHealthFactPacket(
          clientId: 'CLIENT-SANDTON',
          siteId: 'SITE-SANDTON',
          siteReference: 'Sandton Estate',
          status: ClientCameraHealthStatus.live,
          reason: ClientCameraHealthReason.legacyProxyActive,
          path: ClientCameraHealthPath.legacyLocalProxy,
          lastSuccessfulVisualAtUtc: now.subtract(const Duration(seconds: 20)),
          lastSuccessfulUpstreamProbeAtUtc: now.subtract(
            const Duration(seconds: 10),
          ),
          safeClientExplanation:
              'We currently have visual confirmation at Sandton Estate through a temporary local recorder bridge while the newer API credentials are still pending.',
          nextAction:
              'Keep the interim recorder bridge in place until the newer API path is ready.',
        ),
      );

      expect(response.handled, isTrue);
      expect(response.allowed, isTrue);
      expect(response.intent, OnyxCommandIntent.triageNextMove);
      expect(response.text, contains('a recorder event on Camera 11'));
      expect(
        response.text,
        contains('We currently have visual confirmation at Sandton Estate.'),
      );
      expect(
        response.text,
        isNot(contains('I do not have live visual confirmation right now.')),
      );
    },
  );

  test(
    'telegram operational service avoids claiming a current visual view after an unusable image reply',
    () {
      final now = DateTime.now().toUtc();
      final response = service.handle(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-current-view-1',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt: 'Give me a current view of whats happening on site',
          groupBinding: binding,
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
          recentThreadContextTexts: <String>[
            'ONYX: I do not have a usable current verified image to send right now.',
          ],
        ),
        events: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'hik-status-unusable-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 2)),
            intelligenceId: 'INT-HIK-UNUSABLE-1',
            provider: 'hikvision_dvr_monitor_only',
            sourceType: 'dvr',
            externalId: 'evt-hik-unusable-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            cameraId: 'channel-11',
            headline: 'Motion event on Camera 11',
            summary: 'Motion was detected on Camera 11.',
            riskScore: 54,
            canonicalHash: 'hash-hik-unusable-1',
          ),
        ],
        cameraHealthFactPacket: ClientCameraHealthFactPacket(
          clientId: 'CLIENT-SANDTON',
          siteId: 'SITE-SANDTON',
          siteReference: 'Sandton Estate',
          status: ClientCameraHealthStatus.live,
          reason: ClientCameraHealthReason.legacyProxyActive,
          path: ClientCameraHealthPath.legacyLocalProxy,
          lastSuccessfulVisualAtUtc: now.subtract(const Duration(seconds: 30)),
          lastSuccessfulUpstreamProbeAtUtc: now.subtract(
            const Duration(seconds: 10),
          ),
          safeClientExplanation:
              'We currently have visual confirmation at Sandton Estate through a temporary local recorder bridge while the newer API credentials are still pending.',
          nextAction:
              'Keep the interim recorder bridge in place until the newer API path is ready.',
        ),
      );

      expect(response.handled, isTrue);
      expect(response.allowed, isTrue);
      expect(response.text, contains('The latest logged signal was'));
      expect(
        response.text,
        contains('I do not have a usable current image to share right now.'),
      );
      expect(
        response.text,
        isNot(
          contains(
            'We currently have visual confirmation at Sandton Estate through the temporary local recorder bridge.',
          ),
        ),
      );
    },
  );

  test(
    'telegram operational service uses partial coverage wording when a camera is down',
    () {
      final now = DateTime.now().toUtc();
      final response = service.handle(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-partial-coverage-1',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt: 'whats happening right now?',
          groupBinding: binding,
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
          recentThreadContextTexts: <String>[
            'ONYX: Camera 11 is currently down, but we have visual confirmation through a temporary local recorder bridge covering other cameras at Sandton Estate.',
          ],
        ),
        events: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'hik-status-partial-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 3)),
            intelligenceId: 'INT-HIK-PARTIAL-1',
            provider: 'hikvision_dvr_monitor_only',
            sourceType: 'dvr',
            externalId: 'evt-hik-partial-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            cameraId: 'channel-11',
            headline: 'Motion event on Camera 11',
            summary: 'Motion was detected on Camera 11.',
            riskScore: 54,
            canonicalHash: 'hash-hik-partial-1',
          ),
        ],
        cameraHealthFactPacket: ClientCameraHealthFactPacket(
          clientId: 'CLIENT-SANDTON',
          siteId: 'SITE-SANDTON',
          siteReference: 'Sandton Estate',
          status: ClientCameraHealthStatus.live,
          reason: ClientCameraHealthReason.legacyProxyActive,
          path: ClientCameraHealthPath.legacyLocalProxy,
          lastSuccessfulVisualAtUtc: now.subtract(const Duration(seconds: 30)),
          lastSuccessfulUpstreamProbeAtUtc: now.subtract(
            const Duration(seconds: 10),
          ),
          safeClientExplanation:
              'We currently have visual confirmation at Sandton Estate through a temporary local recorder bridge while the newer API credentials are still pending.',
          nextAction:
              'Keep the interim recorder bridge in place until the newer API path is ready.',
        ),
      );

      expect(response.handled, isTrue);
      expect(response.allowed, isTrue);
      expect(response.text, contains('The latest logged signal was'));
      expect(response.text, contains('Camera 11 is down.'));
      expect(response.text, contains('some visual coverage'));
      expect(
        response.text,
        isNot(
          contains(
            'We currently have visual confirmation at Sandton Estate through the temporary local recorder bridge.',
          ),
        ),
      );
    },
  );

  test(
    'telegram operational service answers timed breach questions from the closest logged alert',
    () {
      final now = DateTime.now().toLocal();
      final previousDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
      final fourAmLocal = DateTime(
        previousDay.year,
        previousDay.month,
        previousDay.day,
        4,
        3,
      );
      final laterLocal = DateTime(
        previousDay.year,
        previousDay.month,
        previousDay.day,
        9,
        9,
      );

      final response = service.handle(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-hik-history',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt:
              'there was an alarm at around 4am. can you check if there was any breach?',
          groupBinding: binding,
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
        ),
        events: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'hik-history-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: fourAmLocal.toUtc(),
            intelligenceId: 'INT-HIK-HISTORY-1',
            provider: 'hikvision_dvr_monitor_only',
            sourceType: 'dvr',
            externalId: 'evt-hik-history-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            cameraId: 'channel-11',
            headline: 'HIKVISION_DVR_MONITOR_ONLY VIDEO_EVENT',
            summary:
                'provider:hikvision_dvr_monitor_only | camera:channel-11 | channel:11 | snapshot:pending',
            riskScore: 74,
            canonicalHash: 'hash-hik-history-1',
          ),
          IntelligenceReceived(
            eventId: 'hik-history-intel-2',
            sequence: 2,
            version: 1,
            occurredAt: laterLocal.toUtc(),
            intelligenceId: 'INT-HIK-HISTORY-2',
            provider: 'hikvision_dvr_monitor_only',
            sourceType: 'dvr',
            externalId: 'evt-hik-history-2',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            cameraId: 'channel-11',
            headline: 'HIKVISION_DVR_MONITOR_ONLY VIDEO_EVENT',
            summary:
                'provider:hikvision_dvr_monitor_only | camera:channel-11 | channel:11 | snapshot:pending',
            riskScore: 41,
            canonicalHash: 'hash-hik-history-2',
          ),
        ],
      );

      expect(response.handled, isTrue);
      expect(response.allowed, isTrue);
      expect(response.intent, OnyxCommandIntent.summarizeIncident);
      expect(response.text, contains('closest to 04:00'));
      expect(response.text, contains('04:03'));
      expect(response.text, contains('a recorder event on Camera 11'));
      expect(
        response.text,
        contains(
          'I do not have evidence here confirming a breach from that logged history alone.',
        ),
      );
      expect(
        response.text,
        isNot(contains('I do not have live visual confirmation right now.')),
      );
      expect(response.text, isNot(contains('09:09')));
      expect(
        response.text,
        isNot(contains('latest verified signal near Camera')),
      );
    },
  );

  test(
    'telegram operational service keeps unmatched timed breach questions historical and concise',
    () {
      final now = DateTime.now().toLocal();
      final previousDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
      final nineAmLocal = DateTime(
        previousDay.year,
        previousDay.month,
        previousDay.day,
        9,
        9,
      );

      final response = service.handle(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-hik-history-miss',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt:
              'there was an alarm at 4am on security system. can you check to see if there was an attempted breach please',
          groupBinding: binding,
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
        ),
        events: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'hik-history-miss-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: nineAmLocal.toUtc(),
            intelligenceId: 'INT-HIK-HISTORY-MISS-1',
            provider: 'hikvision_dvr_monitor_only',
            sourceType: 'dvr',
            externalId: 'evt-hik-history-miss-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            cameraId: 'channel-11',
            headline: 'HIKVISION_DVR_MONITOR_ONLY VIDEO_EVENT',
            summary:
                'provider:hikvision_dvr_monitor_only | camera:channel-11 | channel:11 | snapshot:pending',
            riskScore: 41,
            canonicalHash: 'hash-hik-history-miss-1',
          ),
        ],
      );

      expect(response.handled, isTrue);
      expect(response.allowed, isTrue);
      expect(response.intent, OnyxCommandIntent.summarizeIncident);
      expect(
        response.text,
        contains(
          'I do not have a confirmed alert tied to around 04:00 in the logged history available to me.',
        ),
      );
      expect(
        response.text,
        contains(
          'I do not have evidence here confirming a breach from that logged history alone.',
        ),
      );
      expect(
        response.text,
        isNot(contains('I do not have live visual confirmation right now.')),
      );
      expect(
        response.text,
        isNot(contains('logged history I can see right now')),
      );
      expect(response.text, isNot(contains('09:09')));
    },
  );

  test(
    'telegram operational service keeps historical robbery awareness prompts out of live escalation',
    () {
      final response = service.handle(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-robbery-history',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt:
              'I am asking if you were aware of the robbery that took place earlier today.',
          groupBinding: binding,
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
        ),
        events: const <DispatchEvent>[],
      );

      expect(response.handled, isTrue);
      expect(response.allowed, isTrue);
      expect(response.intent, OnyxCommandIntent.summarizeIncident);
      expect(
        response.text,
        contains('earlier reported incident, not a live emergency'),
      );
      expect(response.text, isNot(contains('move to safety')));
      expect(response.text, isNot(contains('call SAPS')));
    },
  );

  test('telegram operational service keeps whole-site review asks grounded', () {
    final now = DateTime.now().toUtc();
    final response = service.handle(
      request: const OnyxTelegramCommandRequest(
        telegramUserId: 'tg-client-full-site-review',
        telegramGroupId: 'tg-sandton',
        role: OnyxAuthorityRole.client,
        prompt: 'check every area',
        groupBinding: binding,
        userAllowedClientIds: {'CLIENT-SANDTON'},
        userAllowedSiteIds: {'SITE-SANDTON'},
        requestedClientId: 'CLIENT-SANDTON',
        requestedSiteId: 'SITE-SANDTON',
        requestedSiteLabel: 'Sandton Estate',
        replyToText:
            'there was an alarm at around 4am. can you check if there was any breach?',
      ),
      events: <DispatchEvent>[
        IntelligenceReceived(
          eventId: 'full-site-review-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 5)),
          intelligenceId: 'INT-FULL-SITE-1',
          provider: 'hikvision_dvr_monitor_only',
          sourceType: 'dvr',
          externalId: 'evt-full-site-1',
          clientId: 'CLIENT-SANDTON',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          cameraId: 'channel-11',
          headline: 'HIKVISION_DVR_MONITOR_ONLY VIDEO_EVENT',
          summary:
              'provider:hikvision_dvr_monitor_only | camera:channel-11 | channel:11 | snapshot:pending',
          riskScore: 61,
          canonicalHash: 'hash-full-site-1',
        ),
      ],
    );

    expect(response.handled, isTrue);
    expect(response.allowed, isTrue);
    expect(response.intent, OnyxCommandIntent.triageNextMove);
    expect(
      response.text,
      'Yes. I can review the logged site signals across Sandton Estate and send you the confirmed result here. I do not have live visual confirmation across every area right now.',
    );
  });

  test(
    'telegram operational service keeps site-wide breach checks out of the unresolved-queue branch',
    () {
      final now = DateTime.now().toUtc();
      final response = service.handle(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-breach-site-check',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt: 'check site for any breaches',
          groupBinding: binding,
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
        ),
        events: const <DispatchEvent>[],
        cameraHealthFactPacket: ClientCameraHealthFactPacket(
          clientId: 'CLIENT-SANDTON',
          siteId: 'SITE-SANDTON',
          siteReference: 'Sandton Estate',
          status: ClientCameraHealthStatus.live,
          reason: ClientCameraHealthReason.legacyProxyActive,
          path: ClientCameraHealthPath.legacyLocalProxy,
          lastSuccessfulVisualAtUtc: now.subtract(const Duration(seconds: 25)),
          lastSuccessfulUpstreamProbeAtUtc: now.subtract(
            const Duration(seconds: 10),
          ),
          safeClientExplanation:
              'We currently have visual confirmation at Sandton Estate through a temporary local recorder bridge while the newer API credentials are still pending.',
          nextAction:
              'Keep the interim recorder bridge in place until the newer API path is ready.',
        ),
      );

      expect(response.handled, isTrue);
      expect(response.allowed, isTrue);
      expect(response.intent, OnyxCommandIntent.triageNextMove);
      expect(
        response.text,
        contains(
          'I do not have evidence here confirming a breach across Sandton Estate right now.',
        ),
      );
      expect(
        response.text,
        contains('We currently have visual confirmation at Sandton Estate.'),
      );
      expect(response.text, isNot(contains('No unresolved incidents')));
    },
  );

  test(
    'telegram operational service uses the live packet in area verification replies',
    () {
      final now = DateTime.now().toUtc();
      final response = service.handle(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-live-verify',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt: 'did someone check the front gate?',
          groupBinding: binding,
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
        ),
        events: const <DispatchEvent>[],
        cameraHealthFactPacket: ClientCameraHealthFactPacket(
          clientId: 'CLIENT-SANDTON',
          siteId: 'SITE-SANDTON',
          siteReference: 'Sandton Estate',
          status: ClientCameraHealthStatus.live,
          reason: ClientCameraHealthReason.legacyProxyActive,
          path: ClientCameraHealthPath.legacyLocalProxy,
          lastSuccessfulVisualAtUtc: now.subtract(const Duration(seconds: 25)),
          lastSuccessfulUpstreamProbeAtUtc: now.subtract(
            const Duration(seconds: 10),
          ),
          safeClientExplanation:
              'We currently have visual confirmation at Sandton Estate through a temporary local recorder bridge while the newer API credentials are still pending.',
          nextAction:
              'Keep the interim recorder bridge in place until the newer API path is ready.',
        ),
      );

      expect(response.handled, isTrue);
      expect(response.allowed, isTrue);
      expect(response.intent, OnyxCommandIntent.triageNextMove);
      expect(
        response.text,
        contains('We currently have visual confirmation at Sandton Estate.'),
      );
      expect(
        response.text,
        isNot(contains('I do not have live visual confirmation on Front Gate')),
      );
    },
  );

  test(
    'telegram operational service uses packetized issue labels when response arrival is still unconfirmed',
    () {
      final now = DateTime.now().toUtc();
      final response = service.handle(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-front-gate-arrival-packet',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt: 'did anyone get to the front gate yet?',
          groupBinding: binding,
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
          recentThreadContextTexts: <String>[
            'The latest confirmed alert was front gate movement at 21:14.',
          ],
        ),
        events: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'packetized-arrival-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 11)),
            intelligenceId: 'INT-PACKET-ARRIVAL-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-packet-arrival-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: 'Front Gate',
            headline: 'Front gate motion alert',
            summary:
                'Repeated line crossing triggered review at the front gate.',
            riskScore: 78,
            canonicalHash: 'hash-packet-arrival-1',
          ),
          DecisionCreated(
            eventId: 'packetized-arrival-decision-1',
            sequence: 2,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 9)),
            dispatchId: 'DSP-PACKET-ARRIVAL-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
        ],
        cameraHealthFactPacket: ClientCameraHealthFactPacket(
          clientId: 'CLIENT-SANDTON',
          siteId: 'SITE-SANDTON',
          siteReference: 'Sandton Estate',
          status: ClientCameraHealthStatus.limited,
          reason: ClientCameraHealthReason.unknown,
          path: ClientCameraHealthPath.hikConnectApi,
          lastSuccessfulVisualAtUtc: null,
          lastSuccessfulUpstreamProbeAtUtc: now.subtract(
            const Duration(minutes: 1),
          ),
          liveSiteIssueStatus: ClientLiveSiteIssueStatus.recentSignals,
          recentIssueSignalLabel:
              'recent line-crossing signals around Front Gate',
          recentMovementHotspotLabel: 'Front Gate',
          nextAction: 'Verify the latest visual path.',
          safeClientExplanation:
              'Live camera visibility at Sandton Estate is limited right now.',
        ),
      );

      expect(response.handled, isTrue);
      expect(response.allowed, isTrue);
      expect(
        response.text,
        contains(
          'I do not have a confirmed response arrival tied to Front Gate yet.',
        ),
      );
      expect(
        response.text,
        contains(
          'The current operational picture still shows recent line-crossing signals around Front Gate.',
        ),
      );
      expect(
        response.text,
        isNot(
          contains(
            'The current operational picture still shows Front Gate under review.',
          ),
        ),
      );
    },
  );

  test(
    'telegram operational service uses packetized active issue summaries for same-issue follow-ups',
    () {
      final now = DateTime.now().toUtc();
      final response = service.handle(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-front-gate-persistence-packet',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt: 'is it still the same issue?',
          groupBinding: binding,
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
          recentThreadContextTexts: <String>[
            'The latest confirmed alert was front gate movement at 21:14.',
          ],
        ),
        events: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'packetized-persistence-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 10)),
            intelligenceId: 'INT-PACKET-PERSISTENCE-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-packet-persistence-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: 'Front Gate',
            headline: 'Front gate motion alert',
            summary: 'Repeated movement triggered review at the front gate.',
            riskScore: 80,
            canonicalHash: 'hash-packet-persistence-1',
          ),
          DecisionCreated(
            eventId: 'packetized-persistence-decision-1',
            sequence: 2,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 8)),
            dispatchId: 'DSP-PACKET-PERSISTENCE-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
        ],
        cameraHealthFactPacket: ClientCameraHealthFactPacket(
          clientId: 'CLIENT-SANDTON',
          siteId: 'SITE-SANDTON',
          siteReference: 'Sandton Estate',
          status: ClientCameraHealthStatus.live,
          reason: ClientCameraHealthReason.legacyProxyActive,
          path: ClientCameraHealthPath.legacyLocalProxy,
          lastSuccessfulVisualAtUtc: now.subtract(const Duration(seconds: 25)),
          lastSuccessfulUpstreamProbeAtUtc: now.subtract(
            const Duration(seconds: 10),
          ),
          liveSiteIssueStatus: ClientLiveSiteIssueStatus.activeSignals,
          recentMovementHotspotLabel: 'Front Gate',
          nextAction:
              'Keep the interim recorder bridge in place until the newer API path is ready.',
          safeClientExplanation:
              'We currently have visual confirmation at Sandton Estate.',
        ),
      );

      expect(response.handled, isTrue);
      expect(response.allowed, isTrue);
      expect(
        response.text,
        contains(
          'The current operational picture still shows live activity around Front Gate.',
        ),
      );
      expect(response.text, contains('Response is still active.'));
      expect(response.text, isNot(contains('still points to Front Gate')));
    },
  );

  test(
    'telegram operational service keeps historical perimeter camera reviews tied to the alarm window',
    () {
      final now = DateTime.now().toLocal();
      final previousDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
      final fourAmLocal = DateTime(
        previousDay.year,
        previousDay.month,
        previousDay.day,
        4,
        3,
      );
      final laterLocal = DateTime(
        previousDay.year,
        previousDay.month,
        previousDay.day,
        9,
        42,
      );

      final response = service.handle(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-perimeter-history',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt:
              'there was an alarm trigger at around 4am. can you check perimeter - all outdoor cameras',
          groupBinding: binding,
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
        ),
        events: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'perimeter-history-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: fourAmLocal.toUtc(),
            intelligenceId: 'INT-PERIMETER-HISTORY-1',
            provider: 'hikvision_dvr_monitor_only',
            sourceType: 'dvr',
            externalId: 'evt-perimeter-history-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            cameraId: 'channel-11',
            headline: 'HIKVISION_DVR_MONITOR_ONLY VIDEO_EVENT',
            summary:
                'provider:hikvision_dvr_monitor_only | camera:channel-11 | channel:11 | snapshot:pending',
            riskScore: 74,
            canonicalHash: 'hash-perimeter-history-1',
          ),
          IntelligenceReceived(
            eventId: 'perimeter-history-intel-2',
            sequence: 2,
            version: 1,
            occurredAt: laterLocal.toUtc(),
            intelligenceId: 'INT-PERIMETER-HISTORY-2',
            provider: 'hikvision_dvr_monitor_only',
            sourceType: 'dvr',
            externalId: 'evt-perimeter-history-2',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            cameraId: 'channel-11',
            headline: 'HIKVISION_DVR_MONITOR_ONLY VIDEO_EVENT',
            summary:
                'provider:hikvision_dvr_monitor_only | camera:channel-11 | channel:11 | snapshot:pending',
            riskScore: 41,
            canonicalHash: 'hash-perimeter-history-2',
          ),
        ],
      );

      expect(response.handled, isTrue);
      expect(response.allowed, isTrue);
      expect(response.intent, OnyxCommandIntent.summarizeIncident);
      expect(
        response.text,
        contains(
          'I do not have a confirmed alert tied to Perimeter or the outdoor cameras around 04:00',
        ),
      );
      expect(
        response.text,
        isNot(
          contains(
            'I do not have live visual confirmation on Perimeter right now.',
          ),
        ),
      );
      expect(response.text, isNot(contains('09:42')));
      expect(
        response.text,
        isNot(contains('latest verified activity near Perimeter')),
      );
    },
  );

  test('telegram operational service keeps the soft action language matrix stable', () {
    final now = DateTime.now().toUtc();
    final activeAreaEvents = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'client-action-open-intel-1',
        sequence: 1,
        version: 1,
        occurredAt: now.subtract(const Duration(minutes: 11)),
        intelligenceId: 'INT-CLIENT-ACTION-OPEN-1',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'evt-client-action-open-1',
        clientId: 'CLIENT-SANDTON',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        zone: 'Front Gate',
        headline: 'Front gate movement alert',
        summary: 'Repeated movement near the front gate triggered review.',
        riskScore: 74,
        canonicalHash: 'hash-client-action-open-1',
      ),
      DecisionCreated(
        eventId: 'client-action-open-decision-1',
        sequence: 2,
        version: 1,
        occurredAt: now.subtract(const Duration(minutes: 8)),
        dispatchId: 'DSP-CLIENT-ACTION-OPEN-1',
        clientId: 'CLIENT-SANDTON',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
    ];

    final cases =
        <
          ({
            String prompt,
            List<DispatchEvent> events,
            List<String> expected,
            List<String> excluded,
          })
        >[
          (
            prompt: 'pls send someone to frnt gte',
            events: const <DispatchEvent>[],
            expected: const <String>[
              'I do not see a fresh verified event tied to Front Gate right now.',
              'I have not initiated a dispatch from this message alone',
              'I can prioritise Front Gate for immediate verification.',
              'I do not have live visual confirmation on Front Gate',
            ],
            excluded: const <String>[],
          ),
          (
            prompt: 'have someone check the perimeter side',
            events: const <DispatchEvent>[],
            expected: const <String>[
              'I do not see a fresh verified event tied to Perimeter right now.',
              'I have not initiated a dispatch from this message alone',
              'I can prioritise Perimeter for immediate verification.',
              'I do not have live visual confirmation on Perimeter',
            ],
            excluded: const <String>[],
          ),
          (
            prompt: 'pls snd smone',
            events: const <DispatchEvent>[],
            expected: const <String>[
              'I’m not fully certain which area you want actioned first.',
              'If you tell me which gate, entrance, or perimeter point matters most',
            ],
            excluded: const <String>[],
          ),
          (
            prompt: 'can a gaurd chek',
            events: const <DispatchEvent>[],
            expected: const <String>[
              'I’m not fully certain which area you want actioned first.',
              'If you tell me which gate, entrance, or perimeter point matters most',
            ],
            excluded: const <String>[],
          ),
          (
            prompt: 'pls send someone to frnt gte',
            events: activeAreaEvents,
            expected: const <String>[
              'There is already an active operational response around Front Gate.',
              'I have not initiated a second dispatch from this message alone.',
            ],
            excluded: const <String>[
              'I can prioritise Front Gate for immediate verification.',
            ],
          ),
        ];

    for (var index = 0; index < cases.length; index += 1) {
      final scenario = cases[index];
      final response = service.handle(
        request: OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-soft-action-$index',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt: scenario.prompt,
          groupBinding: binding,
          userAllowedClientIds: const {'CLIENT-SANDTON'},
          userAllowedSiteIds: const {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
        ),
        events: scenario.events,
      );

      expect(response.handled, isTrue, reason: scenario.prompt);
      expect(response.allowed, isTrue, reason: scenario.prompt);
      expect(
        response.intent,
        OnyxCommandIntent.triageNextMove,
        reason: scenario.prompt,
      );
      for (final text in scenario.expected) {
        expect(response.text, contains(text), reason: scenario.prompt);
      }
      for (final text in scenario.excluded) {
        expect(response.text, isNot(contains(text)), reason: scenario.prompt);
      }
    }
  });

  test(
    'telegram operational service keeps the early thread-context carryover matrix stable',
    () {
      final now = DateTime.now().toUtc();
      final sameGateIncidentEvents = <DispatchEvent>[
        IntelligenceReceived(
          eventId: 'client-same-gate-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 10)),
          intelligenceId: 'INT-SAME-GATE-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-same-gate-1',
          clientId: 'CLIENT-SANDTON',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          zone: 'Front Gate',
          headline: 'Front gate motion alert',
          summary: 'Repeated movement triggered review at the front gate.',
          riskScore: 79,
          canonicalHash: 'hash-same-gate-1',
        ),
        DecisionCreated(
          eventId: 'client-same-gate-decision-1',
          sequence: 2,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 8)),
          dispatchId: 'DSP-SAME-GATE-1',
          clientId: 'CLIENT-SANDTON',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
        ),
      ];

      final cases =
          <
            ({
              String prompt,
              List<String> context,
              List<DispatchEvent> events,
              OnyxCommandIntent expectedIntent,
              String expectedLead,
              String? expectedFollowUp,
              String expectedVisualArea,
            })
          >[
            (
              prompt: 'check the same gate again',
              context: const <String>[
                'The latest verified activity near Front Gate was routine movement at 21:14.',
              ],
              events: const <DispatchEvent>[],
              expectedIntent: OnyxCommandIntent.triageNextMove,
              expectedLead:
                  'I do not have a fresh verified event tied to Front Gate right now',
              expectedFollowUp: null,
              expectedVisualArea: 'Front Gate',
            ),
            (
              prompt: 'was that the same gate as before?',
              context: const <String>[
                'The latest confirmed alert was front gate movement at 21:14.',
              ],
              events: sameGateIncidentEvents,
              expectedIntent: OnyxCommandIntent.summarizeIncident,
              expectedLead:
                  'The latest confirmed alert points to Front Gate again.',
              expectedFollowUp: 'Response is still active.',
              expectedVisualArea: 'Front Gate',
            ),
            (
              prompt: 'send someone there',
              context: const <String>[
                'The latest verified activity near Front Gate was routine movement at 21:14.',
              ],
              events: const <DispatchEvent>[],
              expectedIntent: OnyxCommandIntent.triageNextMove,
              expectedLead:
                  'I do not see a fresh verified event tied to Front Gate right now.',
              expectedFollowUp:
                  'I can prioritise Front Gate for immediate verification.',
              expectedVisualArea: 'Front Gate',
            ),
          ];

      for (final scenario in cases) {
        final response = service.handle(
          request: OnyxTelegramCommandRequest(
            telegramUserId: 'tg-client-30',
            telegramGroupId: 'tg-sandton',
            role: OnyxAuthorityRole.client,
            prompt: scenario.prompt,
            groupBinding: binding,
            userAllowedClientIds: const {'CLIENT-SANDTON'},
            userAllowedSiteIds: const {'SITE-SANDTON'},
            requestedClientId: 'CLIENT-SANDTON',
            requestedSiteId: 'SITE-SANDTON',
            requestedSiteLabel: 'Sandton Estate',
            recentThreadContextTexts: scenario.context,
          ),
          events: scenario.events,
        );

        expect(response.handled, isTrue, reason: scenario.prompt);
        expect(response.allowed, isTrue, reason: scenario.prompt);
        expect(
          response.intent,
          scenario.expectedIntent,
          reason: scenario.prompt,
        );
        expect(
          response.text,
          contains(scenario.expectedLead),
          reason: scenario.prompt,
        );
        if (scenario.expectedFollowUp case final expectedFollowUp?) {
          expect(
            response.text,
            contains(expectedFollowUp),
            reason: scenario.prompt,
          );
        }
        expect(
          response.text,
          contains(
            'I do not have live visual confirmation on ${scenario.expectedVisualArea}',
          ),
          reason: scenario.prompt,
        );
      }
    },
  );

  test(
    'telegram operational service keeps the premium camera carryover reassurance matrix stable',
    () {
      const sameCameraContext = <String>[
        'The latest verified activity near Back Camera was routine movement at 21:18.',
      ];
      const sameCctvContext = <String>[
        'The latest verified activity near Back Cctv was routine movement at 21:18.',
      ];

      final cases =
          <({String prompt, List<String> context, String expectedArea})>[
            for (final prompt in const <String>[
              'is it safe at the same camera now?',
              'is it all clear at the same camera now?',
              'is it calm at the same camera now?',
              'is it caln at the same camra now?',
              'is it saef at the sme camra now?',
            ])
              (
                prompt: prompt,
                context: sameCameraContext,
                expectedArea: 'Back Camera',
              ),
            for (final prompt in const <String>[
              'is it clear at the same cctv then?',
              'is it quiet at the same cctv then?',
              'has it stayed calm at the same cctv?',
              'has it staid calm at the same cctvv?',
              'is it cleer at the sme cctvv then?',
            ])
              (
                prompt: prompt,
                context: sameCctvContext,
                expectedArea: 'Back Cctv',
              ),
          ];

      for (final scenario in cases) {
        final response = service.handle(
          request: OnyxTelegramCommandRequest(
            telegramUserId: 'tg-client-33gl',
            telegramGroupId: 'tg-sandton',
            role: OnyxAuthorityRole.client,
            prompt: scenario.prompt,
            groupBinding: binding,
            userAllowedClientIds: const {'CLIENT-SANDTON'},
            userAllowedSiteIds: const {'SITE-SANDTON'},
            requestedClientId: 'CLIENT-SANDTON',
            requestedSiteId: 'SITE-SANDTON',
            requestedSiteLabel: 'Sandton Estate',
            recentThreadContextTexts: scenario.context,
          ),
          events: const [],
        );

        expect(response.handled, isTrue, reason: scenario.prompt);
        expect(response.allowed, isTrue, reason: scenario.prompt);
        expect(
          response.intent,
          OnyxCommandIntent.triageNextMove,
          reason: scenario.prompt,
        );
        expect(
          response.text,
          contains(
            'I do not have a fresh verified event tied to ${scenario.expectedArea} right now',
          ),
          reason: scenario.prompt,
        );
        expect(
          response.text,
          contains(
            'I do not have live visual confirmation on ${scenario.expectedArea}',
          ),
          reason: scenario.prompt,
        );
      }
    },
  );

  test(
    'telegram operational service keeps the premium camera carryover ambiguity matrix stable',
    () {
      final cases = <({String prompt, List<String> context, Pattern expected})>[
        for (final prompt in const <String>[
          'is it safe at the same camera now?',
          'is it all clear at the same camera now?',
          'is it calm at the same camera now?',
          'is it caln at the same camra now?',
          'is it saef at the sme camra now?',
        ])
          (
            prompt: prompt,
            context: const <String>[
              'Front camera had movement at 21:14.',
              'Back camera had movement at 21:18.',
            ],
            expected: RegExp(
              'I’m not fully certain whether you mean (Front Camera or Back Camera|Back Camera or Front Camera)\\.',
            ),
          ),
        for (final prompt in const <String>[
          'is it clear at the same cctv then?',
          'is it quiet at the same cctv then?',
          'has it stayed calm at the same cctv?',
          'has it staid calm at the same cctvv?',
          'is it cleer at the sme cctvv then?',
        ])
          (
            prompt: prompt,
            context: const <String>[
              'Front cctv had movement at 21:14.',
              'Back cctv had movement at 21:18.',
            ],
            expected: RegExp(
              'I’m not fully certain whether you mean (Front Cctv or Back Cctv|Back Cctv or Front Cctv)\\.',
            ),
          ),
      ];

      for (final scenario in cases) {
        final response = service.handle(
          request: OnyxTelegramCommandRequest(
            telegramUserId: 'tg-client-33gm',
            telegramGroupId: 'tg-sandton',
            role: OnyxAuthorityRole.client,
            prompt: scenario.prompt,
            groupBinding: binding,
            userAllowedClientIds: const {'CLIENT-SANDTON'},
            userAllowedSiteIds: const {'SITE-SANDTON'},
            requestedClientId: 'CLIENT-SANDTON',
            requestedSiteId: 'SITE-SANDTON',
            requestedSiteLabel: 'Sandton Estate',
            recentThreadContextTexts: scenario.context,
          ),
          events: const [],
        );

        expect(response.handled, isTrue, reason: scenario.prompt);
        expect(response.allowed, isTrue, reason: scenario.prompt);
        expect(
          response.intent,
          OnyxCommandIntent.triageNextMove,
          reason: scenario.prompt,
        );
        expect(
          response.text,
          matches(scenario.expected),
          reason: scenario.prompt,
        );
        expect(
          response.text,
          contains(
            'If you tell me which one you want checked first, I’ll focus the next verified update there.',
          ),
          reason: scenario.prompt,
        );
      }
    },
  );

  test(
    'telegram operational service keeps the premium explicit area carryover reassurance matrix stable',
    () {
      const sameGateContext = <String>[
        'The latest verified activity near Back Gate was routine movement at 21:18.',
      ];
      const sameEntranceContext = <String>[
        'The latest verified activity near Back Entrance was routine movement at 21:18.',
      ];
      const latestGateContext = <String>[
        'The latest verified activity near Front Gate was routine movement at 21:18.',
        'Back Entrance had movement at 21:14.',
      ];
      const latestEntranceContext = <String>[
        'The latest verified activity near Back Entrance was routine movement at 21:18.',
        'Front Gate had movement at 21:14.',
      ];

      final cases = <({String prompt, List<String> context, String expectedArea})>[
        (
          prompt: 'is that entrance okay now?',
          context: const <String>[
            'The latest verified activity near Entrance was routine movement at 21:14.',
          ],
          expectedArea: 'Entrance',
        ),
        for (final prompt in const <String>[
          'is it all clear at the same gate now?',
          'is it caln at the same gate now?',
        ])
          (prompt: prompt, context: sameGateContext, expectedArea: 'Back Gate'),
        for (final prompt in const <String>[
          'is the entrance side okay now?',
          'is it quiet at the same entrance then?',
          'has it staid calm at the same entrance?',
        ])
          (
            prompt: prompt,
            context: sameEntranceContext,
            expectedArea: 'Back Entrance',
          ),
        for (final prompt in const <String>[
          'is it still safe at the sme gate?',
          'is it okay at the sme gate now?',
          'is it oaky at the sme gate now?',
          'is it saef at the sme gate now?',
          'is it all clear at the sme gate now?',
          'is it all cleer at the sme gate now?',
          'is it quiet at the sme gate now?',
          'is it qiuet at the sme gate now?',
          'is it calm at the sme gate now?',
          'is it caln at the sme gate now?',
          'has it stayed calm at the sme gate?',
          'has it staid calm at the sme gate?',
        ])
          (
            prompt: prompt,
            context: latestGateContext,
            expectedArea: 'Front Gate',
          ),
        for (final prompt in const <String>[
          'is it still clear at the sme entrance?',
          'is it okay at the sme entrance then?',
          'is it oaky at the sme entrance then?',
          'is it saef at the sme entrance then?',
          'is it all clear at the sme entrance then?',
          'is it all cleer at the sme entrance then?',
          'is it quiet at the sme entrance then?',
          'is it qiuet at the sme entrance then?',
          'is it calm at the sme entrance then?',
          'is it caln at the sme entrance then?',
          'has it stayed calm at the sme entrance?',
          'has it staid calm at the sme entrance?',
        ])
          (
            prompt: prompt,
            context: latestEntranceContext,
            expectedArea: 'Back Entrance',
          ),
      ];

      for (final scenario in cases) {
        final response = service.handle(
          request: OnyxTelegramCommandRequest(
            telegramUserId: 'tg-client-33gn',
            telegramGroupId: 'tg-sandton',
            role: OnyxAuthorityRole.client,
            prompt: scenario.prompt,
            groupBinding: binding,
            userAllowedClientIds: const {'CLIENT-SANDTON'},
            userAllowedSiteIds: const {'SITE-SANDTON'},
            requestedClientId: 'CLIENT-SANDTON',
            requestedSiteId: 'SITE-SANDTON',
            requestedSiteLabel: 'Sandton Estate',
            recentThreadContextTexts: scenario.context,
          ),
          events: const [],
        );

        expect(response.handled, isTrue, reason: scenario.prompt);
        expect(response.allowed, isTrue, reason: scenario.prompt);
        expect(
          response.intent,
          OnyxCommandIntent.triageNextMove,
          reason: scenario.prompt,
        );
        expect(
          response.text,
          contains(
            'I do not have a fresh verified event tied to ${scenario.expectedArea} right now',
          ),
          reason: scenario.prompt,
        );
        expect(
          response.text,
          contains(
            'I do not have live visual confirmation on ${scenario.expectedArea}',
          ),
          reason: scenario.prompt,
        );
      }
    },
  );

  test(
    'telegram operational service keeps the premium explicit area carryover ambiguity matrix stable',
    () {
      final cases = <({String prompt, List<String> context, Pattern expected})>[
        (
          prompt: 'is it safe at the same gate now?',
          context: const <String>[
            'Front Gate had movement at 21:14.',
            'Back Gate had movement at 21:18.',
          ],
          expected: RegExp(
            'I’m not fully certain whether you mean (Front Gate or Back Gate|Back Gate or Front Gate)\\.',
          ),
        ),
        (
          prompt: 'is it all clear at the same gate now?',
          context: const <String>[
            'Front Gate had movement at 21:14.',
            'Back Gate had movement at 21:18.',
          ],
          expected: RegExp(
            'I’m not fully certain whether you mean (Front Gate or Back Gate|Back Gate or Front Gate)\\.',
          ),
        ),
        (
          prompt: 'is it caln at the same gate now?',
          context: const <String>[
            'Front Gate had movement at 21:14.',
            'Back Gate had movement at 21:18.',
          ],
          expected: RegExp(
            'I’m not fully certain whether you mean (Front Gate or Back Gate|Back Gate or Front Gate)\\.',
          ),
        ),
        (
          prompt: 'is the entrance side okay now?',
          context: const <String>[
            'The latest verified activity near Front Entrance was routine movement at 21:14.',
            'The latest verified activity near Back Entrance was routine movement at 21:09.',
          ],
          expected: RegExp(
            'I’m not fully certain whether you mean (Front Entrance or Back Entrance|Back Entrance or Front Entrance)\\.',
          ),
        ),
        (
          prompt: 'is the entrance side still okay now?',
          context: const <String>[
            'The latest verified activity near Front Entrance was routine movement at 21:14.',
            'The latest verified activity near Back Entrance was routine movement at 21:09.',
          ],
          expected: RegExp(
            'I’m not fully certain whether you mean (Front Entrance or Back Entrance|Back Entrance or Front Entrance)\\.',
          ),
        ),
        (
          prompt: 'is tht side safe then?',
          context: const <String>[
            'The latest verified activity near Front Entrance was routine movement at 21:14.',
            'The latest verified activity near Back Entrance was routine movement at 21:09.',
          ],
          expected: RegExp(
            'I’m not fully certain whether you mean (Front Entrance or Back Entrance|Back Entrance or Front Entrance)\\.',
          ),
        ),
        (
          prompt: 'is tht side clear then?',
          context: const <String>[
            'The latest verified activity near Front Entrance was routine movement at 21:14.',
            'The latest verified activity near Back Entrance was routine movement at 21:09.',
          ],
          expected: RegExp(
            'I’m not fully certain whether you mean (Front Entrance or Back Entrance|Back Entrance or Front Entrance)\\.',
          ),
        ),
        (
          prompt: 'is it clear at the same entrance then?',
          context: const <String>[
            'Front Entrance had movement at 21:14.',
            'Back Entrance had movement at 21:18.',
          ],
          expected: RegExp(
            'I’m not fully certain whether you mean (Front Entrance or Back Entrance|Back Entrance or Front Entrance)\\.',
          ),
        ),
        (
          prompt: 'is it quiet at the same entrance then?',
          context: const <String>[
            'Front Entrance had movement at 21:14.',
            'Back Entrance had movement at 21:18.',
          ],
          expected: RegExp(
            'I’m not fully certain whether you mean (Front Entrance or Back Entrance|Back Entrance or Front Entrance)\\.',
          ),
        ),
        (
          prompt: 'has it staid calm at the same entrance?',
          context: const <String>[
            'Front Entrance had movement at 21:14.',
            'Back Entrance had movement at 21:18.',
          ],
          expected: RegExp(
            'I’m not fully certain whether you mean (Front Entrance or Back Entrance|Back Entrance or Front Entrance)\\.',
          ),
        ),
      ];

      for (final scenario in cases) {
        final response = service.handle(
          request: OnyxTelegramCommandRequest(
            telegramUserId: 'tg-client-33go',
            telegramGroupId: 'tg-sandton',
            role: OnyxAuthorityRole.client,
            prompt: scenario.prompt,
            groupBinding: binding,
            userAllowedClientIds: const {'CLIENT-SANDTON'},
            userAllowedSiteIds: const {'SITE-SANDTON'},
            requestedClientId: 'CLIENT-SANDTON',
            requestedSiteId: 'SITE-SANDTON',
            requestedSiteLabel: 'Sandton Estate',
            recentThreadContextTexts: scenario.context,
          ),
          events: const [],
        );

        expect(response.handled, isTrue, reason: scenario.prompt);
        expect(response.allowed, isTrue, reason: scenario.prompt);
        expect(
          response.intent,
          OnyxCommandIntent.triageNextMove,
          reason: scenario.prompt,
        );
        expect(
          response.text,
          matches(scenario.expected),
          reason: scenario.prompt,
        );
        expect(
          response.text,
          contains(
            'If you tell me which one you want checked first, I’ll focus the next verified update there.',
          ),
          reason: scenario.prompt,
        );
      }
    },
  );

  test(
    'telegram operational service keeps the softer contextual carryover reassurance matrix stable',
    () {
      final cases =
          <
            ({
              String prompt,
              List<String> context,
              String expectedArea,
              String? unexpectedArea,
            })
          >[
            (
              prompt: 'is tht side okay now?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:14.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: null,
            ),
            (
              prompt: 'is tht side still okay then?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:14.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: null,
            ),
            (
              prompt: 'is tht side safe then?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:14.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: null,
            ),
            (
              prompt: 'is tht side clear then?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:14.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: null,
            ),
            (
              prompt: 'is it safe ovr ther now?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:14.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: null,
            ),
            (
              prompt: 'is it clear ovr ther now?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:14.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: null,
            ),
            (
              prompt: 'is it safe ovr ther then?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:18.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: null,
            ),
            (
              prompt: 'is it clear ovr ther then?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:18.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: null,
            ),
            (
              prompt: 'is it still clear ovr ther?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:18.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: null,
            ),
            (
              prompt: 'is it still safe on the othr side?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:14.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: null,
            ),
            (
              prompt: 'is it still clear on the othr side?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:14.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: null,
            ),
            (
              prompt: 'is it still safe on the othr one?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:14.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: null,
            ),
            (
              prompt: 'is it still clear on the othr one?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:14.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: null,
            ),
            (
              prompt: 'is it still safe on tht one?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:14.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: null,
            ),
            (
              prompt: 'is it still clear on tht one?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:14.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: null,
            ),
            (
              prompt: 'is it still safe on tht side?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:18.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: null,
            ),
            (
              prompt: 'is it still clear on tht side?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:18.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: null,
            ),
            (
              prompt: 'is it still safe on the same one?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:18.',
                'Front Gate had movement at 21:14.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: 'Front Gate',
            ),
            (
              prompt: 'is it still clear on the same one?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:18.',
                'Front Gate had movement at 21:14.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: 'Front Gate',
            ),
            (
              prompt: 'is it still safe on the same side?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:18.',
                'Front Gate had movement at 21:14.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: 'Front Gate',
            ),
            (
              prompt: 'is it still clear on the same side?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:18.',
                'Front Gate had movement at 21:14.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: 'Front Gate',
            ),
            (
              prompt: 'is it still safe on the sme side?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:18.',
                'Front Gate had movement at 21:14.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: 'Front Gate',
            ),
            (
              prompt: 'is it still clear on the sme side?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:18.',
                'Front Gate had movement at 21:14.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: 'Front Gate',
            ),
            (
              prompt: 'is it still safe on the sme one?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:18.',
                'Front Gate had movement at 21:14.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: 'Front Gate',
            ),
            (
              prompt: 'is it still clear on the sme one?',
              context: const <String>[
                'The latest verified activity near Back Entrance was routine movement at 21:18.',
                'Front Gate had movement at 21:14.',
              ],
              expectedArea: 'Back Entrance',
              unexpectedArea: 'Front Gate',
            ),
          ];

      for (final scenario in cases) {
        final response = service.handle(
          request: OnyxTelegramCommandRequest(
            telegramUserId: 'tg-client-33gp',
            telegramGroupId: 'tg-sandton',
            role: OnyxAuthorityRole.client,
            prompt: scenario.prompt,
            groupBinding: binding,
            userAllowedClientIds: const {'CLIENT-SANDTON'},
            userAllowedSiteIds: const {'SITE-SANDTON'},
            requestedClientId: 'CLIENT-SANDTON',
            requestedSiteId: 'SITE-SANDTON',
            requestedSiteLabel: 'Sandton Estate',
            recentThreadContextTexts: scenario.context,
          ),
          events: const [],
        );

        expect(response.handled, isTrue, reason: scenario.prompt);
        expect(response.allowed, isTrue, reason: scenario.prompt);
        expect(
          response.intent,
          OnyxCommandIntent.triageNextMove,
          reason: scenario.prompt,
        );
        expect(
          response.text,
          contains(
            'I do not have a fresh verified event tied to ${scenario.expectedArea} right now',
          ),
          reason: scenario.prompt,
        );
        expect(
          response.text,
          contains(
            'I do not have live visual confirmation on ${scenario.expectedArea}',
          ),
          reason: scenario.prompt,
        );
        if (scenario.unexpectedArea case final unexpectedArea?) {
          expect(
            response.text,
            isNot(contains(unexpectedArea)),
            reason: scenario.prompt,
          );
        }
      }
    },
  );

  test(
    'telegram operational service keeps the softer contextual carryover ambiguity matrix stable',
    () {
      final cases = <String>[
        'is it safe ovr ther now?',
        'is it clear ovr ther now?',
        'is it safe ovr ther then?',
        'is it clear ovr ther then?',
        'is it still clear ovr ther?',
        'is it still safe on the othr side?',
        'is it still clear on the othr side?',
        'is it still safe on the othr one?',
        'is it still clear on the othr one?',
        'is it still safe on tht side?',
        'is it still clear on tht side?',
        'is it still safe on tht one?',
        'is it still clear on tht one?',
      ];

      for (final prompt in cases) {
        final response = service.handle(
          request: OnyxTelegramCommandRequest(
            telegramUserId: 'tg-client-33gq',
            telegramGroupId: 'tg-sandton',
            role: OnyxAuthorityRole.client,
            prompt: prompt,
            groupBinding: binding,
            userAllowedClientIds: const {'CLIENT-SANDTON'},
            userAllowedSiteIds: const {'SITE-SANDTON'},
            requestedClientId: 'CLIENT-SANDTON',
            requestedSiteId: 'SITE-SANDTON',
            requestedSiteLabel: 'Sandton Estate',
            recentThreadContextTexts: const <String>[
              'Front Gate had movement at 21:14.',
              'Back Entrance had movement at 21:18.',
            ],
          ),
          events: const [],
        );

        expect(response.handled, isTrue, reason: prompt);
        expect(response.allowed, isTrue, reason: prompt);
        expect(
          response.intent,
          OnyxCommandIntent.triageNextMove,
          reason: prompt,
        );
        expect(
          response.text,
          matches(
            RegExp(
              'I’m not fully certain whether you mean (Front Gate or Back Entrance|Back Entrance or Front Gate)\\.',
            ),
          ),
          reason: prompt,
        );
        expect(
          response.text,
          contains(
            'If you tell me which one you want checked first, I’ll focus the next verified update there.',
          ),
          reason: prompt,
        );
      }
    },
  );

  test(
    'telegram operational service keeps the softer contextual presence-history matrix stable',
    () {
      final now = DateTime.now().toUtc();

      List<DispatchEvent> missingResponseHistory({
        required String prefix,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 20)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
          DecisionCreated(
            eventId: '$prefix-decision-1',
            sequence: 2,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 16)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
        ];
      }

      List<DispatchEvent> missingPatrolHistory({
        required String prefix,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 20)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
        ];
      }

      List<DispatchEvent> responseArrivalHistory({
        required String prefix,
        required String zone,
        required String alertHeadline,
        required String alertSummary,
        required String arrivalSummary,
        required int riskScore,
      }) {
        return <DispatchEvent>[
          ...missingResponseHistory(
            prefix: prefix,
            zone: zone,
            headline: alertHeadline,
            summary: alertSummary,
            riskScore: riskScore,
          ),
          IntelligenceReceived(
            eventId: '$prefix-intel-2',
            sequence: 3,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 8)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-2',
            provider: 'field-ops',
            sourceType: 'ops',
            externalId: 'evt-$prefix-2',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: 'Response arrival',
            summary: arrivalSummary,
            riskScore: 28,
            canonicalHash: 'hash-$prefix-2',
          ),
        ];
      }

      List<DispatchEvent> patrolHistory({
        required String prefix,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
      }) {
        return <DispatchEvent>[
          ...missingPatrolHistory(
            prefix: prefix,
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
          ),
          PatrolCompleted(
            eventId: '$prefix-patrol-1',
            sequence: 2,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 11)),
            routeId: 'back-entrance-route',
            guardId: 'Guard014',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            durationSeconds: 420,
          ),
        ];
      }

      final cases =
          <
            ({
              String prompt,
              List<String> context,
              List<DispatchEvent> events,
              String expectedArea,
              bool expectsArrival,
              bool expectsGuardCheck,
              bool expectsGuardCheckLogged,
            })
          >[
            (
              prompt: 'so still no one there after that then?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement earlier tonight.',
              ],
              events: missingResponseHistory(
                prefix: 'contextual-presence-missing-perimeter',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 74,
              ),
              expectedArea: 'Perimeter',
              expectsArrival: false,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'so still no one there then?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement earlier tonight.',
              ],
              events: missingResponseHistory(
                prefix: 'contextual-presence-missing-still-there',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 74,
              ),
              expectedArea: 'Perimeter',
              expectsArrival: false,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'so no one got there after that then?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement earlier tonight.',
              ],
              events: missingResponseHistory(
                prefix: 'contextual-presence-missing-after-that',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 74,
              ),
              expectedArea: 'Perimeter',
              expectsArrival: false,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'so no one got there yet then?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement earlier tonight.',
              ],
              events: missingResponseHistory(
                prefix: 'contextual-presence-missing-yet',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 74,
              ),
              expectedArea: 'Perimeter',
              expectsArrival: false,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'did any1 get there since earlier or not yet?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement earlier tonight.',
              ],
              events: missingResponseHistory(
                prefix: 'contextual-presence-missing-any1-get-since-earlier',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 74,
              ),
              expectedArea: 'Perimeter',
              expectsArrival: false,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'did they get there yet?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: missingResponseHistory(
                prefix: 'contextual-presence-missing-did-they-get-there-yet',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 74,
              ),
              expectedArea: 'Perimeter',
              expectsArrival: false,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'did anyone get to that side yet?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: missingResponseHistory(
                prefix:
                    'contextual-presence-missing-did-anyone-get-that-side-yet',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 74,
              ),
              expectedArea: 'Perimeter',
              expectsArrival: false,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'did someone check that side yet?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: missingPatrolHistory(
                prefix:
                    'contextual-presence-missing-did-someone-check-side-yet',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 69,
              ),
              expectedArea: 'Perimeter',
              expectsArrival: false,
              expectsGuardCheck: true,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'did they arrive yet there?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: <DispatchEvent>[
                IntelligenceReceived(
                  eventId:
                      'contextual-presence-arrival-did-they-arrive-yet-there-intel-1',
                  sequence: 1,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 18)),
                  intelligenceId: 'INT-DID-THEY-ARRIVE-YET-THERE-1',
                  provider: 'hikvision-dvr',
                  sourceType: 'dvr',
                  externalId: 'evt-did-they-arrive-yet-there-1',
                  clientId: 'CLIENT-SANDTON',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON',
                  zone: 'Perimeter',
                  headline: 'Perimeter movement alert',
                  summary:
                      'Movement along the outer perimeter triggered review.',
                  riskScore: 74,
                  canonicalHash: 'hash-did-they-arrive-yet-there-1',
                ),
                IntelligenceReceived(
                  eventId:
                      'contextual-presence-arrival-did-they-arrive-yet-there-intel-2',
                  sequence: 2,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 9)),
                  intelligenceId: 'INT-DID-THEY-ARRIVE-YET-THERE-2',
                  provider: 'field-ops',
                  sourceType: 'ops',
                  externalId: 'evt-did-they-arrive-yet-there-2',
                  clientId: 'CLIENT-SANDTON',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON',
                  zone: 'Perimeter',
                  headline: 'Response arrival',
                  summary: 'A field response unit arrived on site.',
                  riskScore: 28,
                  canonicalHash: 'hash-did-they-arrive-yet-there-2',
                ),
              ],
              expectedArea: 'Perimeter',
              expectsArrival: true,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'so no one checked that side yet then?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: missingPatrolHistory(
                prefix: 'contextual-presence-missing-check-yet',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 69,
              ),
              expectedArea: 'Back Entrance',
              expectsArrival: false,
              expectsGuardCheck: true,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'so still no one checked that side then?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: missingPatrolHistory(
                prefix: 'contextual-presence-missing-check-still',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 69,
              ),
              expectedArea: 'Back Entrance',
              expectsArrival: false,
              expectsGuardCheck: true,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'so no one has checked that side since then?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: missingPatrolHistory(
                prefix:
                    'contextual-presence-missing-has-checked-side-since-then',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 69,
              ),
              expectedArea: 'Back Entrance',
              expectsArrival: false,
              expectsGuardCheck: true,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'has any1 checked that side since then or still no?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: missingPatrolHistory(
                prefix:
                    'contextual-presence-missing-any1-checked-side-since-then',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 69,
              ),
              expectedArea: 'Back Entrance',
              expectsArrival: false,
              expectsGuardCheck: true,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'so someone did check that side then?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: patrolHistory(
                prefix: 'contextual-presence-patrol-did-check-side',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 69,
              ),
              expectedArea: 'Back Entrance',
              expectsArrival: false,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: true,
            ),
            (
              prompt: 'so someone has checked that side then?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: patrolHistory(
                prefix: 'contextual-presence-patrol-has-checked-side',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 69,
              ),
              expectedArea: 'Back Entrance',
              expectsArrival: false,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: true,
            ),
            (
              prompt: 'has any1 checked that side yet?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: patrolHistory(
                prefix: 'contextual-presence-patrol-any1-checked-side-yet',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 69,
              ),
              expectedArea: 'Back Entrance',
              expectsArrival: false,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: true,
            ),
            (
              prompt: 'so someone has checked that side since then?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: patrolHistory(
                prefix:
                    'contextual-presence-patrol-has-checked-side-since-then',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 69,
              ),
              expectedArea: 'Back Entrance',
              expectsArrival: false,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: true,
            ),
            (
              prompt: 'has any1 checked that side since then?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: patrolHistory(
                prefix:
                    'contextual-presence-patrol-any1-checked-side-since-then',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 69,
              ),
              expectedArea: 'Back Entrance',
              expectsArrival: false,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: true,
            ),
            (
              prompt: 'has someone looked there yet?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: <DispatchEvent>[
                IntelligenceReceived(
                  eventId: 'contextual-presence-patrol-looked-there-intel-1',
                  sequence: 1,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 20)),
                  intelligenceId:
                      'INT-CONTEXTUAL-PRESENCE-PATROL-LOOKED-THERE-1',
                  provider: 'hikvision-dvr',
                  sourceType: 'dvr',
                  externalId: 'evt-contextual-presence-patrol-looked-there-1',
                  clientId: 'CLIENT-SANDTON',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON',
                  zone: 'Perimeter',
                  headline: 'Perimeter movement alert',
                  summary:
                      'Movement along the outer perimeter triggered review.',
                  riskScore: 69,
                  canonicalHash:
                      'hash-contextual-presence-patrol-looked-there-1',
                ),
                PatrolCompleted(
                  eventId: 'contextual-presence-patrol-looked-there-patrol-1',
                  sequence: 2,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 11)),
                  routeId: 'perimeter-route',
                  guardId: 'Guard011',
                  clientId: 'CLIENT-SANDTON',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON',
                  durationSeconds: 420,
                ),
              ],
              expectedArea: 'Perimeter',
              expectsArrival: false,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: true,
            ),
            (
              prompt: 'has any1 looked there yet?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: <DispatchEvent>[
                IntelligenceReceived(
                  eventId:
                      'contextual-presence-patrol-any1-looked-there-intel-1',
                  sequence: 1,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 20)),
                  intelligenceId:
                      'INT-CONTEXTUAL-PRESENCE-PATROL-ANY1-LOOKED-THERE-1',
                  provider: 'hikvision-dvr',
                  sourceType: 'dvr',
                  externalId:
                      'evt-contextual-presence-patrol-any1-looked-there-1',
                  clientId: 'CLIENT-SANDTON',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON',
                  zone: 'Perimeter',
                  headline: 'Perimeter movement alert',
                  summary:
                      'Movement along the outer perimeter triggered review.',
                  riskScore: 69,
                  canonicalHash:
                      'hash-contextual-presence-patrol-any1-looked-there-1',
                ),
                PatrolCompleted(
                  eventId:
                      'contextual-presence-patrol-any1-looked-there-patrol-1',
                  sequence: 2,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 11)),
                  routeId: 'perimeter-route',
                  guardId: 'Guard011',
                  clientId: 'CLIENT-SANDTON',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON',
                  durationSeconds: 420,
                ),
              ],
              expectedArea: 'Perimeter',
              expectsArrival: false,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: true,
            ),
            (
              prompt: 'did sm1 check there yet?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: <DispatchEvent>[
                IntelligenceReceived(
                  eventId: 'contextual-presence-patrol-sm1-check-there-intel-1',
                  sequence: 1,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 20)),
                  intelligenceId:
                      'INT-CONTEXTUAL-PRESENCE-PATROL-SM1-CHECK-THERE-1',
                  provider: 'hikvision-dvr',
                  sourceType: 'dvr',
                  externalId:
                      'evt-contextual-presence-patrol-sm1-check-there-1',
                  clientId: 'CLIENT-SANDTON',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON',
                  zone: 'Perimeter',
                  headline: 'Perimeter movement alert',
                  summary:
                      'Movement along the outer perimeter triggered review.',
                  riskScore: 69,
                  canonicalHash:
                      'hash-contextual-presence-patrol-sm1-check-there-1',
                ),
                PatrolCompleted(
                  eventId:
                      'contextual-presence-patrol-sm1-check-there-patrol-1',
                  sequence: 2,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 11)),
                  routeId: 'perimeter-route',
                  guardId: 'Guard011',
                  clientId: 'CLIENT-SANDTON',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON',
                  durationSeconds: 420,
                ),
              ],
              expectedArea: 'Perimeter',
              expectsArrival: false,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: true,
            ),
            (
              prompt: 'so still no one on that side since then?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: missingResponseHistory(
                prefix: 'contextual-presence-missing-back-entrance',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 69,
              ),
              expectedArea: 'Back Entrance',
              expectsArrival: false,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'so still no one over ther then?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: missingResponseHistory(
                prefix: 'contextual-presence-missing-over-ther',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 69,
              ),
              expectedArea: 'Back Entrance',
              expectsArrival: false,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'so still no one over there then?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: missingResponseHistory(
                prefix: 'contextual-presence-missing-over-there',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 69,
              ),
              expectedArea: 'Back Entrance',
              expectsArrival: false,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'so still someone there after that then?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement earlier tonight.',
              ],
              events: responseArrivalHistory(
                prefix: 'contextual-presence-arrival-perimeter',
                zone: 'Perimeter',
                alertHeadline: 'Perimeter movement alert',
                alertSummary:
                    'Movement along the outer perimeter triggered review.',
                arrivalSummary: 'A field response unit arrived on site.',
                riskScore: 74,
              ),
              expectedArea: 'Perimeter',
              expectsArrival: true,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'so someone did get there then?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement earlier tonight.',
              ],
              events: responseArrivalHistory(
                prefix: 'contextual-presence-arrival-did-get-there',
                zone: 'Perimeter',
                alertHeadline: 'Perimeter movement alert',
                alertSummary:
                    'Movement along the outer perimeter triggered review.',
                arrivalSummary: 'A field response unit arrived on site.',
                riskScore: 74,
              ),
              expectedArea: 'Perimeter',
              expectsArrival: true,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'did they get there yet?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: responseArrivalHistory(
                prefix: 'contextual-presence-arrival-did-they-get-there-yet',
                zone: 'Perimeter',
                alertHeadline: 'Perimeter movement alert',
                alertSummary:
                    'Movement along the outer perimeter triggered review.',
                arrivalSummary: 'A field response unit arrived on site.',
                riskScore: 74,
              ),
              expectedArea: 'Perimeter',
              expectsArrival: true,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'did any1 get there since earlier?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement earlier tonight.',
              ],
              events: <DispatchEvent>[
                IntelligenceReceived(
                  eventId: 'contextual-presence-arrival-any1-earlier-intel-1',
                  sequence: 1,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 22)),
                  intelligenceId:
                      'INT-CONTEXTUAL-PRESENCE-ARRIVAL-ANY1-EARLIER-1',
                  provider: 'hikvision-dvr',
                  sourceType: 'dvr',
                  externalId: 'evt-contextual-presence-arrival-any1-earlier-1',
                  clientId: 'CLIENT-SANDTON',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON',
                  zone: 'Perimeter',
                  headline: 'Perimeter movement alert',
                  summary:
                      'Movement along the outer perimeter triggered review.',
                  riskScore: 74,
                  canonicalHash:
                      'hash-contextual-presence-arrival-any1-earlier-1',
                ),
                IntelligenceReceived(
                  eventId: 'contextual-presence-arrival-any1-earlier-intel-2',
                  sequence: 2,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 10)),
                  intelligenceId:
                      'INT-CONTEXTUAL-PRESENCE-ARRIVAL-ANY1-EARLIER-2',
                  provider: 'field-ops',
                  sourceType: 'ops',
                  externalId: 'evt-contextual-presence-arrival-any1-earlier-2',
                  clientId: 'CLIENT-SANDTON',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON',
                  zone: 'Perimeter',
                  headline: 'Response arrival',
                  summary: 'A field response unit arrived on site.',
                  riskScore: 28,
                  canonicalHash:
                      'hash-contextual-presence-arrival-any1-earlier-2',
                ),
              ],
              expectedArea: 'Perimeter',
              expectsArrival: true,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'did any1 get there yet?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: responseArrivalHistory(
                prefix: 'contextual-presence-arrival-did-any1-get-there-yet',
                zone: 'Perimeter',
                alertHeadline: 'Perimeter movement alert',
                alertSummary:
                    'Movement along the outer perimeter triggered review.',
                arrivalSummary: 'A field response unit arrived on site.',
                riskScore: 74,
              ),
              expectedArea: 'Perimeter',
              expectsArrival: true,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'did any1 get to the gate yet?',
              context: const <String>[
                'The latest confirmed alert was front gate movement at 21:14.',
              ],
              events: <DispatchEvent>[
                IntelligenceReceived(
                  eventId: 'contextual-presence-arrival-any1-gate-intel-1',
                  sequence: 1,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 18)),
                  intelligenceId: 'INT-CONTEXTUAL-PRESENCE-ARRIVAL-ANY1-GATE-1',
                  provider: 'hikvision-dvr',
                  sourceType: 'dvr',
                  externalId: 'evt-contextual-presence-arrival-any1-gate-1',
                  clientId: 'CLIENT-SANDTON',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON',
                  zone: 'Front Gate',
                  headline: 'Front gate movement alert',
                  summary: 'Movement at the front gate triggered review.',
                  riskScore: 72,
                  canonicalHash: 'hash-contextual-presence-arrival-any1-gate-1',
                ),
                IntelligenceReceived(
                  eventId: 'contextual-presence-arrival-any1-gate-intel-2',
                  sequence: 2,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 9)),
                  intelligenceId: 'INT-CONTEXTUAL-PRESENCE-ARRIVAL-ANY1-GATE-2',
                  provider: 'field-ops',
                  sourceType: 'ops',
                  externalId: 'evt-contextual-presence-arrival-any1-gate-2',
                  clientId: 'CLIENT-SANDTON',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON',
                  zone: 'Front Gate',
                  headline: 'Response arrival',
                  summary: 'A field response unit arrived on site.',
                  riskScore: 28,
                  canonicalHash: 'hash-contextual-presence-arrival-any1-gate-2',
                ),
              ],
              expectedArea: 'Front Gate',
              expectsArrival: true,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'did they get to the gate after that?',
              context: const <String>[
                'The latest confirmed alert was front gate movement at 21:14.',
              ],
              events: <DispatchEvent>[
                IntelligenceReceived(
                  eventId:
                      'contextual-presence-arrival-gate-after-that-intel-1',
                  sequence: 1,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 18)),
                  intelligenceId:
                      'INT-CONTEXTUAL-PRESENCE-ARRIVAL-GATE-AFTER-THAT-1',
                  provider: 'hikvision-dvr',
                  sourceType: 'dvr',
                  externalId:
                      'evt-contextual-presence-arrival-gate-after-that-1',
                  clientId: 'CLIENT-SANDTON',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON',
                  zone: 'Front Gate',
                  headline: 'Front gate movement alert',
                  summary: 'Movement at the front gate triggered review.',
                  riskScore: 72,
                  canonicalHash:
                      'hash-contextual-presence-arrival-gate-after-that-1',
                ),
                IntelligenceReceived(
                  eventId:
                      'contextual-presence-arrival-gate-after-that-intel-2',
                  sequence: 2,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 8)),
                  intelligenceId:
                      'INT-CONTEXTUAL-PRESENCE-ARRIVAL-GATE-AFTER-THAT-2',
                  provider: 'field-ops',
                  sourceType: 'ops',
                  externalId:
                      'evt-contextual-presence-arrival-gate-after-that-2',
                  clientId: 'CLIENT-SANDTON',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON',
                  zone: 'Front Gate',
                  headline: 'Response arrival',
                  summary: 'A field response unit arrived on site.',
                  riskScore: 28,
                  canonicalHash:
                      'hash-contextual-presence-arrival-gate-after-that-2',
                ),
              ],
              expectedArea: 'Front Gate',
              expectsArrival: true,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'so someone is there then?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement earlier tonight.',
              ],
              events: responseArrivalHistory(
                prefix: 'contextual-presence-arrival-is-there',
                zone: 'Perimeter',
                alertHeadline: 'Perimeter movement alert',
                alertSummary:
                    'Movement along the outer perimeter triggered review.',
                arrivalSummary: 'A field response unit arrived on site.',
                riskScore: 74,
              ),
              expectedArea: 'Perimeter',
              expectsArrival: true,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'so someone got there after that then?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement earlier tonight.',
              ],
              events: responseArrivalHistory(
                prefix: 'contextual-presence-arrival-after-that',
                zone: 'Perimeter',
                alertHeadline: 'Perimeter movement alert',
                alertSummary:
                    'Movement along the outer perimeter triggered review.',
                arrivalSummary: 'A field response unit arrived on site.',
                riskScore: 74,
              ),
              expectedArea: 'Perimeter',
              expectsArrival: true,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'so someone on that side since then?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: responseArrivalHistory(
                prefix: 'contextual-presence-arrival-that-side',
                zone: 'Back Entrance',
                alertHeadline: 'Back entrance motion alert',
                alertSummary: 'Movement at the back entrance triggered review.',
                arrivalSummary:
                    'A field response unit arrived at the back entrance.',
                riskScore: 69,
              ),
              expectedArea: 'Back Entrance',
              expectsArrival: true,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'so someone on tht side since then?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: responseArrivalHistory(
                prefix: 'contextual-presence-arrival-tht-side',
                zone: 'Back Entrance',
                alertHeadline: 'Back entrance motion alert',
                alertSummary: 'Movement at the back entrance triggered review.',
                arrivalSummary:
                    'A field response unit arrived at the back entrance.',
                riskScore: 69,
              ),
              expectedArea: 'Back Entrance',
              expectsArrival: true,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'did they get there on tht side?',
              context: const <String>[
                'The latest confirmed alert was back entrance motion at 21:14.',
              ],
              events: responseArrivalHistory(
                prefix:
                    'contextual-presence-arrival-tht-side-did-they-get-there',
                zone: 'Back Entrance',
                alertHeadline: 'Back entrance motion alert',
                alertSummary: 'Movement at the back entrance triggered review.',
                arrivalSummary:
                    'A field response unit arrived at the back entrance.',
                riskScore: 74,
              ),
              expectedArea: 'Back Entrance',
              expectsArrival: true,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'did they get there on tht side after that?',
              context: const <String>[
                'The latest confirmed alert was back entrance motion at 21:14.',
              ],
              events: responseArrivalHistory(
                prefix:
                    'contextual-presence-arrival-tht-side-did-they-get-there-after',
                zone: 'Back Entrance',
                alertHeadline: 'Back entrance motion alert',
                alertSummary: 'Movement at the back entrance triggered review.',
                arrivalSummary:
                    'A field response unit arrived at the back entrance.',
                riskScore: 74,
              ),
              expectedArea: 'Back Entrance',
              expectsArrival: true,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'so still someone over there then?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: responseArrivalHistory(
                prefix: 'contextual-presence-arrival-over-there',
                zone: 'Back Entrance',
                alertHeadline: 'Back entrance motion alert',
                alertSummary: 'Movement at the back entrance triggered review.',
                arrivalSummary:
                    'A field response unit arrived at the back entrance.',
                riskScore: 69,
              ),
              expectedArea: 'Back Entrance',
              expectsArrival: true,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
            (
              prompt: 'so still someone ovr ther then?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: responseArrivalHistory(
                prefix: 'contextual-presence-arrival-ovr-ther',
                zone: 'Back Entrance',
                alertHeadline: 'Back entrance motion alert',
                alertSummary: 'Movement at the back entrance triggered review.',
                arrivalSummary:
                    'A field response unit arrived at the back entrance.',
                riskScore: 69,
              ),
              expectedArea: 'Back Entrance',
              expectsArrival: true,
              expectsGuardCheck: false,
              expectsGuardCheckLogged: false,
            ),
          ];

      for (final scenario in cases) {
        final response = service.handle(
          request: OnyxTelegramCommandRequest(
            telegramUserId: 'tg-client-33gr',
            telegramGroupId: 'tg-sandton',
            role: OnyxAuthorityRole.client,
            prompt: scenario.prompt,
            groupBinding: binding,
            userAllowedClientIds: const {'CLIENT-SANDTON'},
            userAllowedSiteIds: const {'SITE-SANDTON'},
            requestedClientId: 'CLIENT-SANDTON',
            requestedSiteId: 'SITE-SANDTON',
            requestedSiteLabel: 'Sandton Estate',
            recentThreadContextTexts: scenario.context,
          ),
          events: scenario.events,
        );

        expect(response.handled, isTrue, reason: scenario.prompt);
        expect(response.allowed, isTrue, reason: scenario.prompt);
        expect(
          response.intent,
          scenario.expectsGuardCheck || scenario.expectsGuardCheckLogged
              ? OnyxCommandIntent.triageNextMove
              : OnyxCommandIntent.summarizeIncident,
          reason: scenario.prompt,
        );
        final arrivalStillActive = scenario.events.any(
          (event) => event is DecisionCreated,
        );
        if (scenario.expectsGuardCheck) {
          expect(
            response.text,
            contains(
              'I do not have a confirmed guard check tied to ${scenario.expectedArea} yet.',
            ),
            reason: scenario.prompt,
          );
        } else if (scenario.expectsGuardCheckLogged) {
          final latestPatrol = scenario.events
              .whereType<PatrolCompleted>()
              .last;
          expect(
            response.text,
            contains(
              'Yes. The latest guard check tied to ${scenario.expectedArea} was logged by ${latestPatrol.guardId} at ',
            ),
            reason: scenario.prompt,
          );
        } else if (scenario.expectsArrival) {
          expect(
            response.text,
            contains(
              'Yes. A response arrival tied to ${scenario.expectedArea} was logged at ',
            ),
            reason: scenario.prompt,
          );
          if (arrivalStillActive) {
            expect(
              response.text,
              contains(
                'Response remains active while that area is being verified.',
              ),
              reason: scenario.prompt,
            );
          } else {
            expect(
              response.text,
              contains('It is not sitting as an active incident now.'),
              reason: scenario.prompt,
            );
          }
        } else {
          expect(
            response.text,
            contains(
              'I do not have a confirmed response arrival tied to ${scenario.expectedArea} yet.',
            ),
            reason: scenario.prompt,
          );
          expect(
            response.text,
            contains(
              'The current operational picture still shows ${scenario.expectedArea} under review.',
            ),
            reason: scenario.prompt,
          );
        }
        expect(
          response.text,
          contains(
            'I do not have live visual confirmation on ${scenario.expectedArea}',
          ),
          reason: scenario.prompt,
        );
      }
    },
  );

  test(
    'telegram operational service keeps the softer contextual presence-history ambiguity matrix stable',
    () {
      final cases = <String>[
        'so someone on the other side since then?',
        'so still someone over there then?',
      ];

      for (final prompt in cases) {
        final response = service.handle(
          request: OnyxTelegramCommandRequest(
            telegramUserId: 'tg-client-33gs',
            telegramGroupId: 'tg-sandton',
            role: OnyxAuthorityRole.client,
            prompt: prompt,
            groupBinding: binding,
            userAllowedClientIds: const {'CLIENT-SANDTON'},
            userAllowedSiteIds: const {'SITE-SANDTON'},
            requestedClientId: 'CLIENT-SANDTON',
            requestedSiteId: 'SITE-SANDTON',
            requestedSiteLabel: 'Sandton Estate',
            recentThreadContextTexts: const <String>[
              'Front Gate had movement at 21:14.',
              'Back Entrance had movement at 21:18.',
            ],
          ),
          events: const <DispatchEvent>[],
        );

        expect(response.handled, isTrue, reason: prompt);
        expect(response.allowed, isTrue, reason: prompt);
        expect(
          response.intent,
          OnyxCommandIntent.summarizeIncident,
          reason: prompt,
        );
        expect(
          response.text,
          matches(
            RegExp(
              'I’m not fully certain whether you mean (Front Gate or Back Entrance|Back Entrance or Front Gate)\\.',
            ),
          ),
          reason: prompt,
        );
        expect(
          response.text,
          contains(
            'If you tell me which one you mean, I’ll confirm whether response has arrived there.',
          ),
          reason: prompt,
        );
      }
    },
  );

  test(
    'telegram operational service keeps the softer completed-action continuity matrix stable',
    () {
      final now = DateTime.now().toUtc();

      List<DispatchEvent> patrolHistory({
        required String prefix,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
        required String routeId,
        required String guardId,
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 20)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
          PatrolCompleted(
            eventId: '$prefix-patrol-1',
            sequence: 2,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 11)),
            routeId: routeId,
            guardId: guardId,
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            durationSeconds: 420,
          ),
        ];
      }

      List<DispatchEvent> patrolMissingHistory({
        required String prefix,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 18)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
        ];
      }

      List<DispatchEvent> arrivalHistory({
        required String prefix,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
        required String arrivalSummary,
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 18)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
          DecisionCreated(
            eventId: '$prefix-decision-1',
            sequence: 2,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 16)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
          IntelligenceReceived(
            eventId: '$prefix-intel-2',
            sequence: 3,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 9)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-2',
            provider: 'field-ops',
            sourceType: 'ops',
            externalId: 'evt-$prefix-2',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: 'Response arrival',
            summary: arrivalSummary,
            riskScore: 28,
            canonicalHash: 'hash-$prefix-2',
          ),
        ];
      }

      List<DispatchEvent> arrivalMissingHistory({
        required String prefix,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 18)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
          DecisionCreated(
            eventId: '$prefix-decision-1',
            sequence: 2,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 16)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
        ];
      }

      final cases =
          <
            ({
              String prompt,
              List<String> context,
              List<DispatchEvent> events,
              String expectedArea,
              OnyxCommandIntent expectedIntent,
              String expectedLead,
              String? expectedFollowUp,
            })
          >[
            (
              prompt: 'did sm1 check there yet?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: patrolHistory(
                prefix: 'completed-action-patrol-typo',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 69,
                routeId: 'perimeter-route',
                guardId: 'Guard011',
              ),
              expectedArea: 'Perimeter',
              expectedIntent: OnyxCommandIntent.triageNextMove,
              expectedLead:
                  'Yes. The latest guard check tied to Perimeter was logged by Guard011 at ',
              expectedFollowUp: null,
            ),
            (
              prompt: 'did they get there yet?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: arrivalHistory(
                prefix: 'completed-action-arrival-generic',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 74,
                arrivalSummary: 'A field response unit arrived on site.',
              ),
              expectedArea: 'Perimeter',
              expectedIntent: OnyxCommandIntent.summarizeIncident,
              expectedLead:
                  'Yes. A response arrival tied to Perimeter was logged at ',
              expectedFollowUp:
                  'Response remains active while that area is being verified.',
            ),
            (
              prompt: 'has someone looked there yet?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: patrolHistory(
                prefix: 'completed-action-patrol-looked',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 69,
                routeId: 'perimeter-route',
                guardId: 'Guard011',
              ),
              expectedArea: 'Perimeter',
              expectedIntent: OnyxCommandIntent.triageNextMove,
              expectedLead:
                  'Yes. The latest guard check tied to Perimeter was logged by Guard011 at ',
              expectedFollowUp: null,
            ),
            (
              prompt: 'did someone check that side yet?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: patrolMissingHistory(
                prefix: 'completed-action-patrol-missing',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 69,
              ),
              expectedArea: 'Perimeter',
              expectedIntent: OnyxCommandIntent.triageNextMove,
              expectedLead:
                  'I do not have a confirmed guard check tied to Perimeter yet.',
              expectedFollowUp: null,
            ),
            (
              prompt: 'did anyone get to that side yet?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: arrivalMissingHistory(
                prefix: 'completed-action-arrival-missing',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 74,
              ),
              expectedArea: 'Perimeter',
              expectedIntent: OnyxCommandIntent.summarizeIncident,
              expectedLead:
                  'I do not have a confirmed response arrival tied to Perimeter yet.',
              expectedFollowUp:
                  'The current operational picture still shows Perimeter under review.',
            ),
          ];

      for (final scenario in cases) {
        final response = service.handle(
          request: OnyxTelegramCommandRequest(
            telegramUserId: 'tg-client-33gt',
            telegramGroupId: 'tg-sandton',
            role: OnyxAuthorityRole.client,
            prompt: scenario.prompt,
            groupBinding: binding,
            userAllowedClientIds: const {'CLIENT-SANDTON'},
            userAllowedSiteIds: const {'SITE-SANDTON'},
            requestedClientId: 'CLIENT-SANDTON',
            requestedSiteId: 'SITE-SANDTON',
            requestedSiteLabel: 'Sandton Estate',
            recentThreadContextTexts: scenario.context,
          ),
          events: scenario.events,
        );

        expect(response.handled, isTrue, reason: scenario.prompt);
        expect(response.allowed, isTrue, reason: scenario.prompt);
        expect(
          response.intent,
          scenario.expectedIntent,
          reason: scenario.prompt,
        );
        expect(
          response.text,
          contains(scenario.expectedLead),
          reason: scenario.prompt,
        );
        if (scenario.expectedFollowUp case final expectedFollowUp?) {
          expect(
            response.text,
            contains(expectedFollowUp),
            reason: scenario.prompt,
          );
        }
        expect(
          response.text,
          contains(
            'I do not have live visual confirmation on ${scenario.expectedArea}',
          ),
          reason: scenario.prompt,
        );
      }
    },
  );

  test(
    'telegram operational service keeps the softer completed-action continuity ambiguity matrix stable',
    () {
      final cases = <String>[
        'did they get to the other side yet?',
        'did they get to the othr side yet?',
        'did they get there on the other side?',
      ];

      for (final prompt in cases) {
        final response = service.handle(
          request: OnyxTelegramCommandRequest(
            telegramUserId: 'tg-client-33gu',
            telegramGroupId: 'tg-sandton',
            role: OnyxAuthorityRole.client,
            prompt: prompt,
            groupBinding: binding,
            userAllowedClientIds: const {'CLIENT-SANDTON'},
            userAllowedSiteIds: const {'SITE-SANDTON'},
            requestedClientId: 'CLIENT-SANDTON',
            requestedSiteId: 'SITE-SANDTON',
            requestedSiteLabel: 'Sandton Estate',
            recentThreadContextTexts: const <String>[
              'Front Gate had movement at 21:14.',
              'Back Entrance had movement at 21:18.',
            ],
          ),
          events: const <DispatchEvent>[],
        );

        expect(response.handled, isTrue, reason: prompt);
        expect(response.allowed, isTrue, reason: prompt);
        expect(
          response.intent,
          OnyxCommandIntent.summarizeIncident,
          reason: prompt,
        );
        expect(
          response.text,
          matches(
            RegExp(
              'I’m not fully certain whether you mean (Front Gate or Back Entrance|Back Entrance or Front Gate)\\.',
            ),
          ),
          reason: prompt,
        );
        expect(
          response.text,
          contains(
            'If you tell me which one you mean, I’ll confirm whether response has arrived there.',
          ),
          reason: prompt,
        );
      }
    },
  );

  test(
    'telegram operational service keeps the anchored calm follow-up matrix stable',
    () {
      final now = DateTime.now().toUtc();

      List<DispatchEvent> guardSettledHistory({
        required String prefix,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
        required String routeId,
        required String guardId,
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 21)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
          DecisionCreated(
            eventId: '$prefix-decision-1',
            sequence: 2,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 19)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
          PatrolCompleted(
            eventId: '$prefix-patrol-1',
            sequence: 3,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 11)),
            routeId: routeId,
            guardId: guardId,
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            durationSeconds: 480,
          ),
          IncidentClosed(
            eventId: '$prefix-closed-1',
            sequence: 4,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 5)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            resolutionType: 'all_clear',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
        ];
      }

      List<DispatchEvent> guardActiveHistory({
        required String prefix,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
        required String routeId,
        required String guardId,
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 19)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
          DecisionCreated(
            eventId: '$prefix-decision-1',
            sequence: 2,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 17)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
          PatrolCompleted(
            eventId: '$prefix-patrol-1',
            sequence: 3,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 8)),
            routeId: routeId,
            guardId: guardId,
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            durationSeconds: 14 * 60,
          ),
        ];
      }

      List<DispatchEvent> dispatchSettledHistory({
        required String prefix,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 24)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
          DecisionCreated(
            eventId: '$prefix-decision-1',
            sequence: 2,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 22)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
          IncidentClosed(
            eventId: '$prefix-closed-1',
            sequence: 3,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 6)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            resolutionType: 'all_clear',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
        ];
      }

      List<DispatchEvent> cameraReviewSettledHistory({
        required String prefix,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
        required String reviewSummary,
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 21)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
          DecisionCreated(
            eventId: '$prefix-decision-1',
            sequence: 2,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 19)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
          IntelligenceReceived(
            eventId: '$prefix-intel-2',
            sequence: 3,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 12)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-2',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-2',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: 'Camera check complete',
            summary: reviewSummary,
            riskScore: 18,
            canonicalHash: 'hash-$prefix-2',
          ),
          IncidentClosed(
            eventId: '$prefix-closed-1',
            sequence: 4,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 5)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            resolutionType: 'all_clear',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
        ];
      }

      List<DispatchEvent> cameraReviewMissingHistory({
        required String prefix,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 21)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
          DecisionCreated(
            eventId: '$prefix-decision-1',
            sequence: 2,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 19)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
        ];
      }

      List<DispatchEvent> arrivalSettledHistory({
        required String prefix,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
        required String arrivalSummary,
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 18)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
          DecisionCreated(
            eventId: '$prefix-decision-1',
            sequence: 2,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 16)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
          IntelligenceReceived(
            eventId: '$prefix-intel-2',
            sequence: 3,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 9)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-2',
            provider: 'field-ops',
            sourceType: 'ops',
            externalId: 'evt-$prefix-2',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: 'Response arrival',
            summary: arrivalSummary,
            riskScore: 28,
            canonicalHash: 'hash-$prefix-2',
          ),
          IncidentClosed(
            eventId: '$prefix-closed-1',
            sequence: 4,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 4)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            resolutionType: 'all_clear',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
        ];
      }

      List<DispatchEvent> arrivalActiveHistory({
        required String prefix,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
        required String arrivalSummary,
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 18)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
          DecisionCreated(
            eventId: '$prefix-decision-1',
            sequence: 2,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 16)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
          IntelligenceReceived(
            eventId: '$prefix-intel-2',
            sequence: 3,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 8)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-2',
            provider: 'field-ops',
            sourceType: 'ops',
            externalId: 'evt-$prefix-2',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: 'Response arrival',
            summary: arrivalSummary,
            riskScore: 28,
            canonicalHash: 'hash-$prefix-2',
          ),
        ];
      }

      final cases =
          <
            ({
              String prompt,
              List<String> context,
              List<DispatchEvent> events,
              String expectedLead,
              String? expectedAnchorLine,
              String? expectedStatusLine,
              String? expectedArea,
            })
          >[
            (
              prompt: 'has it been quiet since the guard checked?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: guardSettledHistory(
                prefix: 'anchored-calm-guard',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary:
                    'Repeated movement triggered review at the back entrance.',
                riskScore: 68,
                routeId: 'BACK-ENTRANCE',
                guardId: 'Guard014',
              ),
              expectedLead:
                  'Yes. Back Entrance has been calm since the guard check at ',
              expectedAnchorLine:
                  'The latest guard check tied to Back Entrance was logged by Guard014 at ',
              expectedStatusLine:
                  'It was reviewed properly and is not sitting as an active incident now.',
              expectedArea: 'Back Entrance',
            ),
            (
              prompt: 'has that side been calm since the patrol passed?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: guardActiveHistory(
                prefix: 'anchored-calm-patrol-active',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 74,
                routeId: 'NORTH-PERIMETER',
                guardId: 'Guard009',
              ),
              expectedLead:
                  'No. The current operational picture still points to Perimeter.',
              expectedAnchorLine:
                  'The latest guard check tied to Perimeter was logged by Guard009 at ',
              expectedStatusLine: 'Response is still active.',
              expectedArea: 'Perimeter',
            ),
            (
              prompt:
                  'has that side been calm since dispatch was opened there?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: dispatchSettledHistory(
                prefix: 'anchored-calm-dispatch',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 69,
              ),
              expectedLead:
                  'Yes. Perimeter has remained calm since dispatch was opened at ',
              expectedAnchorLine:
                  'The dispatch tied to Perimeter was opened at ',
              expectedStatusLine:
                  'It was reviewed properly and is not sitting as an active incident now.',
              expectedArea: 'Perimeter',
            ),
            (
              prompt:
                  'has the entrance side been calm since dispatch was opened?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: dispatchSettledHistory(
                prefix: 'anchored-calm-dispatch-entrance',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary:
                    'Repeated movement triggered review at the back entrance.',
                riskScore: 69,
              ),
              expectedLead:
                  'Yes. Back Entrance has remained calm since dispatch was opened at ',
              expectedAnchorLine:
                  'The dispatch tied to Back Entrance was opened at ',
              expectedStatusLine:
                  'It was reviewed properly and is not sitting as an active incident now.',
              expectedArea: 'Back Entrance',
            ),
            (
              prompt:
                  'has the entrance side been calm since the cameras were checked there?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: cameraReviewSettledHistory(
                prefix: 'anchored-calm-camera-check',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary:
                    'Repeated movement triggered review at the back entrance.',
                riskScore: 69,
                reviewSummary:
                    'Cameras were checked at the back entrance and no further movement was confirmed.',
              ),
              expectedLead:
                  'Yes. Back Entrance has appeared calm since the last confirmed camera review at ',
              expectedAnchorLine:
                  'A confirmed camera review marker tied to Back Entrance was logged at ',
              expectedStatusLine:
                  'It was reviewed properly and is not sitting as an active incident now.',
              expectedArea: 'Back Entrance',
            ),
            (
              prompt: 'has that entrance been quiet since they checked it?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: guardSettledHistory(
                prefix: 'anchored-calm-they-checked',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary:
                    'Repeated movement triggered review at the back entrance.',
                riskScore: 69,
                routeId: 'back-entrance-route',
                guardId: 'Guard009',
              ),
              expectedLead:
                  'Yes. Back Entrance has been calm since the guard check at ',
              expectedAnchorLine:
                  'The latest guard check tied to Back Entrance was logged by Guard009 at ',
              expectedStatusLine:
                  'It was reviewed properly and is not sitting as an active incident now.',
              expectedArea: 'Back Entrance',
            ),
            (
              prompt: 'has the gate been quiet since sm1 checked the gate?',
              context: const <String>[
                'The latest confirmed alert was front gate movement at 21:14.',
              ],
              events: guardSettledHistory(
                prefix: 'anchored-calm-sm1-checked-gate',
                zone: 'Front Gate',
                headline: 'Front gate motion alert',
                summary:
                    'Repeated movement triggered review at the front gate.',
                riskScore: 69,
                routeId: 'front-gate-route',
                guardId: 'Guard003',
              ),
              expectedLead:
                  'Yes. Front Gate has been calm since the guard check at ',
              expectedAnchorLine:
                  'The latest guard check tied to Front Gate was logged by Guard003 at ',
              expectedStatusLine:
                  'It was reviewed properly and is not sitting as an active incident now.',
              expectedArea: 'Front Gate',
            ),
            (
              prompt: 'has the gate been quiet since they checked the gate?',
              context: const <String>[
                'The latest confirmed alert was front gate movement at 21:14.',
              ],
              events: guardSettledHistory(
                prefix: 'anchored-calm-they-checked-gate',
                zone: 'Front Gate',
                headline: 'Front gate motion alert',
                summary:
                    'Repeated movement triggered review at the front gate.',
                riskScore: 69,
                routeId: 'front-gate-route',
                guardId: 'Guard003',
              ),
              expectedLead:
                  'Yes. Front Gate has been calm since the guard check at ',
              expectedAnchorLine:
                  'The latest guard check tied to Front Gate was logged by Guard003 at ',
              expectedStatusLine:
                  'It was reviewed properly and is not sitting as an active incident now.',
              expectedArea: 'Front Gate',
            ),
            (
              prompt: 'has that side been calm since the response arrived?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: arrivalActiveHistory(
                prefix: 'anchored-calm-arrival-active',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 74,
                arrivalSummary: 'A field response unit arrived on site.',
              ),
              expectedLead:
                  'No. The current operational picture still points to Perimeter.',
              expectedAnchorLine:
                  'A response arrival tied to Perimeter was logged at ',
              expectedStatusLine: 'Response is still active.',
              expectedArea: 'Perimeter',
            ),
            (
              prompt: 'has it stayed calm since sm1 got there?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: arrivalSettledHistory(
                prefix: 'anchored-calm-arrival',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 74,
                arrivalSummary: 'A field response unit arrived on site.',
              ),
              expectedLead:
                  'Yes. Perimeter has appeared calm since the response arrived at ',
              expectedAnchorLine:
                  'A response arrival tied to Perimeter was logged at ',
              expectedStatusLine:
                  'It was reviewed properly and is not sitting as an active incident now.',
              expectedArea: 'Perimeter',
            ),
            (
              prompt: 'has it stayed calm since the team arrived there?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: arrivalSettledHistory(
                prefix: 'anchored-calm-team-arrived',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 74,
                arrivalSummary: 'A field response unit arrived on site.',
              ),
              expectedLead:
                  'Yes. Perimeter has appeared calm since the response arrived at ',
              expectedAnchorLine:
                  'A response arrival tied to Perimeter was logged at ',
              expectedStatusLine:
                  'It was reviewed properly and is not sitting as an active incident now.',
              expectedArea: 'Perimeter',
            ),
            (
              prompt: 'has it stayed calm since the guys got there?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: arrivalSettledHistory(
                prefix: 'anchored-calm-guys-arrived',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 74,
                arrivalSummary: 'A field response unit arrived on site.',
              ),
              expectedLead:
                  'Yes. Perimeter has appeared calm since the response arrived at ',
              expectedAnchorLine:
                  'A response arrival tied to Perimeter was logged at ',
              expectedStatusLine:
                  'It was reviewed properly and is not sitting as an active incident now.',
              expectedArea: 'Perimeter',
            ),
            (
              prompt: 'has it stayed calm since they got there?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: arrivalSettledHistory(
                prefix: 'anchored-calm-they-arrived',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 74,
                arrivalSummary: 'A field response unit arrived on site.',
              ),
              expectedLead:
                  'Yes. Perimeter has appeared calm since the response arrived at ',
              expectedAnchorLine:
                  'A response arrival tied to Perimeter was logged at ',
              expectedStatusLine:
                  'It was reviewed properly and is not sitting as an active incident now.',
              expectedArea: 'Perimeter',
            ),
            (
              prompt: 'has it stayed calm since thy got there?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: arrivalSettledHistory(
                prefix: 'anchored-calm-thy-arrived',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 74,
                arrivalSummary: 'A field response unit arrived on site.',
              ),
              expectedLead:
                  'Yes. Perimeter has appeared calm since the response arrived at ',
              expectedAnchorLine:
                  'A response arrival tied to Perimeter was logged at ',
              expectedStatusLine:
                  'It was reviewed properly and is not sitting as an active incident now.',
              expectedArea: 'Perimeter',
            ),
            (
              prompt: 'has that side been quiet since they looked at it?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: guardSettledHistory(
                prefix: 'anchored-calm-they-looked',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 69,
                routeId: 'perimeter-route',
                guardId: 'Guard011',
              ),
              expectedLead:
                  'Yes. Perimeter has been calm since the guard check at ',
              expectedAnchorLine:
                  'The latest guard check tied to Perimeter was logged by Guard011 at ',
              expectedStatusLine:
                  'It was reviewed properly and is not sitting as an active incident now.',
              expectedArea: 'Perimeter',
            ),
            (
              prompt:
                  'has that side been quiet since someone checked that side?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: guardSettledHistory(
                prefix: 'anchored-calm-someone-checked',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 69,
                routeId: 'perimeter-route',
                guardId: 'Guard011',
              ),
              expectedLead:
                  'Yes. Perimeter has been calm since the guard check at ',
              expectedAnchorLine:
                  'The latest guard check tied to Perimeter was logged by Guard011 at ',
              expectedStatusLine:
                  'It was reviewed properly and is not sitting as an active incident now.',
              expectedArea: 'Perimeter',
            ),
            (
              prompt: 'has that side been quiet since some1 looked there?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: guardSettledHistory(
                prefix: 'anchored-calm-some1-looked',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 69,
                routeId: 'perimeter-route',
                guardId: 'Guard011',
              ),
              expectedLead:
                  'Yes. Perimeter has been calm since the guard check at ',
              expectedAnchorLine:
                  'The latest guard check tied to Perimeter was logged by Guard011 at ',
              expectedStatusLine:
                  'It was reviewed properly and is not sitting as an active incident now.',
              expectedArea: 'Perimeter',
            ),
            (
              prompt:
                  'has the entrance side been calm since the cameras were reviewed?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: cameraReviewMissingHistory(
                prefix: 'anchored-calm-camera-missing',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary:
                    'Repeated movement triggered review at the back entrance.',
                riskScore: 69,
              ),
              expectedLead:
                  'I do not have a confirmed camera review marker tied to Back Entrance that I can anchor that calmness check to right now.',
              expectedAnchorLine: null,
              expectedStatusLine: null,
              expectedArea: null,
            ),
          ];

      for (final scenario in cases) {
        final response = service.handle(
          request: OnyxTelegramCommandRequest(
            telegramUserId: 'tg-client-33gv',
            telegramGroupId: 'tg-sandton',
            role: OnyxAuthorityRole.client,
            prompt: scenario.prompt,
            groupBinding: binding,
            userAllowedClientIds: const {'CLIENT-SANDTON'},
            userAllowedSiteIds: const {'SITE-SANDTON'},
            requestedClientId: 'CLIENT-SANDTON',
            requestedSiteId: 'SITE-SANDTON',
            requestedSiteLabel: 'Sandton Estate',
            recentThreadContextTexts: scenario.context,
          ),
          events: scenario.events,
        );

        expect(response.handled, isTrue, reason: scenario.prompt);
        expect(response.allowed, isTrue, reason: scenario.prompt);
        expect(
          response.intent,
          OnyxCommandIntent.summarizeIncident,
          reason: scenario.prompt,
        );
        expect(
          response.text,
          contains(scenario.expectedLead),
          reason: scenario.prompt,
        );
        if (scenario.expectedAnchorLine case final expectedAnchorLine?) {
          expect(
            response.text,
            contains(expectedAnchorLine),
            reason: scenario.prompt,
          );
        }
        if (scenario.expectedStatusLine case final expectedStatusLine?) {
          expect(
            response.text,
            contains(expectedStatusLine),
            reason: scenario.prompt,
          );
        }
        if (scenario.expectedArea case final expectedArea?) {
          expect(
            response.text,
            contains('I do not have live visual confirmation on $expectedArea'),
            reason: scenario.prompt,
          );
        }
      }
    },
  );

  test(
    'telegram operational service keeps the incident continuity calmness matrix stable',
    () {
      final now = DateTime.now().toUtc();
      final localNow = DateTime.now().toLocal();
      final localEarlierTonight = localNow.hour >= 18
          ? DateTime(localNow.year, localNow.month, localNow.day, 21, 14)
          : DateTime(
              localNow.year,
              localNow.month,
              localNow.day,
              21,
              14,
            ).subtract(const Duration(days: 1));

      List<DispatchEvent> activeHistory({
        required String prefix,
        required DateTime occurredAt,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: occurredAt,
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
          DecisionCreated(
            eventId: '$prefix-decision-1',
            sequence: 2,
            version: 1,
            occurredAt: occurredAt.add(const Duration(minutes: 2)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
        ];
      }

      List<DispatchEvent> settledHistory({
        required String prefix,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 18)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
          DecisionCreated(
            eventId: '$prefix-decision-1',
            sequence: 2,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 16)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
          IncidentClosed(
            eventId: '$prefix-closed-1',
            sequence: 3,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 4)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            resolutionType: 'all_clear',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
        ];
      }

      final cases =
          <
            ({
              String prompt,
              List<String> context,
              List<DispatchEvent> events,
              String expectedLead,
              String expectedStatusLine,
              String expectedArea,
            })
          >[
            (
              prompt: 'was the entrance side quiet since then?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: settledHistory(
                prefix: 'continuity-quiet-since-then',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary:
                    'Repeated movement triggered review at the back entrance.',
                riskScore: 70,
              ),
              expectedLead:
                  'Yes. Back Entrance has been calm since the earlier signal.',
              expectedStatusLine:
                  'It was reviewed properly and is not sitting as an active incident now.',
              expectedArea: 'Back Entrance',
            ),
            (
              prompt: 'is it still the same issue?',
              context: const <String>[
                'The latest confirmed alert was front gate movement at 21:14.',
              ],
              events: activeHistory(
                prefix: 'continuity-same-issue',
                occurredAt: now.subtract(const Duration(minutes: 10)),
                zone: 'Front Gate',
                headline: 'Front gate motion alert',
                summary:
                    'Repeated movement triggered review at the front gate.',
                riskScore: 79,
              ),
              expectedLead:
                  'The current operational picture still points to Front Gate.',
              expectedStatusLine: 'Response is still active.',
              expectedArea: 'Front Gate',
            ),
            (
              prompt: 'did that settle down?',
              context: const <String>[
                'The latest confirmed alert was front gate movement at 21:14.',
              ],
              events: settledHistory(
                prefix: 'continuity-settled',
                zone: 'Front Gate',
                headline: 'Front gate motion alert',
                summary:
                    'Repeated movement triggered review at the front gate.',
                riskScore: 74,
              ),
              expectedLead: 'The earlier Front Gate signal has settled.',
              expectedStatusLine:
                  'It was reviewed properly and is not sitting as an active incident now.',
              expectedArea: 'Front Gate',
            ),
            (
              prompt: 'was that from earlier tonight?',
              context: const <String>[
                'The latest confirmed alert was front gate movement at 21:14.',
              ],
              events: activeHistory(
                prefix: 'continuity-earlier-tonight',
                occurredAt: localEarlierTonight.toUtc(),
                zone: 'Front Gate',
                headline: 'Front gate motion alert',
                summary:
                    'Repeated movement triggered review at the front gate.',
                riskScore: 79,
              ),
              expectedLead:
                  'Yes. The latest confirmed alert was recorded earlier tonight at 21:14.',
              expectedStatusLine: 'Response is still active.',
              expectedArea: 'Front Gate',
            ),
            (
              prompt: 'was the perimeter side quiet earlier tonight?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: activeHistory(
                prefix: 'continuity-perimeter-earlier-tonight',
                occurredAt: localEarlierTonight.toUtc(),
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 72,
              ),
              expectedLead:
                  'No. The latest confirmed alert tied to Perimeter was recorded earlier tonight at 21:14.',
              expectedStatusLine: 'Response is still active.',
              expectedArea: 'Perimeter',
            ),
            (
              prompt: 'has the perimeter side been calm since earlier?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: activeHistory(
                prefix: 'continuity-perimeter-since-earlier',
                occurredAt: now.subtract(const Duration(minutes: 18)),
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 74,
              ),
              expectedLead:
                  'No. The current operational picture still points to Perimeter.',
              expectedStatusLine: 'Response is still active.',
              expectedArea: 'Perimeter',
            ),
            (
              prompt: 'did the same entrance settle down?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: settledHistory(
                prefix: 'continuity-same-entrance-settled',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary:
                    'Repeated movement triggered review at the back entrance.',
                riskScore: 71,
              ),
              expectedLead: 'The earlier Back Entrance signal has settled.',
              expectedStatusLine:
                  'It was reviewed properly and is not sitting as an active incident now.',
              expectedArea: 'Back Entrance',
            ),
          ];

      for (final scenario in cases) {
        final response = service.handle(
          request: OnyxTelegramCommandRequest(
            telegramUserId: 'tg-client-33gw',
            telegramGroupId: 'tg-sandton',
            role: OnyxAuthorityRole.client,
            prompt: scenario.prompt,
            groupBinding: binding,
            userAllowedClientIds: const {'CLIENT-SANDTON'},
            userAllowedSiteIds: const {'SITE-SANDTON'},
            requestedClientId: 'CLIENT-SANDTON',
            requestedSiteId: 'SITE-SANDTON',
            requestedSiteLabel: 'Sandton Estate',
            recentThreadContextTexts: scenario.context,
          ),
          events: scenario.events,
        );

        expect(response.handled, isTrue, reason: scenario.prompt);
        expect(response.allowed, isTrue, reason: scenario.prompt);
        expect(
          response.intent,
          OnyxCommandIntent.summarizeIncident,
          reason: scenario.prompt,
        );
        expect(
          response.text,
          contains(scenario.expectedLead),
          reason: scenario.prompt,
        );
        expect(
          response.text,
          contains(scenario.expectedStatusLine),
          reason: scenario.prompt,
        );
        expect(
          response.text,
          contains(
            'I do not have live visual confirmation on ${scenario.expectedArea}',
          ),
          reason: scenario.prompt,
        );
      }
    },
  );

  test(
    'telegram operational service keeps the directional and landmark context matrix stable',
    () {
      final now = DateTime.now().toUtc();
      final localNow = DateTime.now().toLocal();
      final localEarlierTonight = localNow.hour >= 18
          ? DateTime(localNow.year, localNow.month, localNow.day, 21, 14)
          : DateTime(
              localNow.year,
              localNow.month,
              localNow.day,
              21,
              14,
            ).subtract(const Duration(days: 1));

      List<DispatchEvent> verificationHistory({
        required String prefix,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
        Duration offset = const Duration(minutes: 10),
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(offset),
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
        ];
      }

      List<DispatchEvent> activeIncidentHistory({
        required String prefix,
        required DateTime occurredAt,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: occurredAt,
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
          DecisionCreated(
            eventId: '$prefix-decision-1',
            sequence: 2,
            version: 1,
            occurredAt: occurredAt.add(const Duration(minutes: 2)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
        ];
      }

      List<DispatchEvent> settledIncidentHistory({
        required String prefix,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 18)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
          DecisionCreated(
            eventId: '$prefix-decision-1',
            sequence: 2,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 16)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
          IncidentClosed(
            eventId: '$prefix-closed-1',
            sequence: 3,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 4)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            resolutionType: 'all_clear',
            clientId: 'CLIENT-SANDTON',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
        ];
      }

      final cases =
          <
            ({
              String prompt,
              List<String> context,
              List<DispatchEvent> events,
              OnyxCommandIntent expectedIntent,
              String expectedLead,
              String? expectedDetail,
              String expectedArea,
            })
          >[
            (
              prompt: 'was that the back one from earlier tonight?',
              context: const <String>[
                'The latest confirmed alert was back entrance movement at 21:14.',
              ],
              events: activeIncidentHistory(
                prefix: 'directional-back-one-earlier-tonight',
                occurredAt: localEarlierTonight.toUtc(),
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary:
                    'Repeated movement triggered review at the back entrance.',
                riskScore: 76,
              ),
              expectedIntent: OnyxCommandIntent.summarizeIncident,
              expectedLead:
                  'Yes. The latest confirmed alert was recorded earlier tonight at 21:14.',
              expectedDetail: 'Response is still active.',
              expectedArea: 'Back Entrance',
            ),
            (
              prompt: 'check the one by the driveway',
              context: const <String>[
                'The latest verified activity near Front Gate was routine movement at 21:14.',
                'The latest verified activity near Driveway was routine vehicle movement at 21:09.',
              ],
              events: verificationHistory(
                prefix: 'directional-driveway-landmark',
                zone: 'Driveway',
                headline: 'Driveway motion alert',
                summary: 'Vehicle movement triggered a review on the driveway.',
                riskScore: 59,
              ),
              expectedIntent: OnyxCommandIntent.triageNextMove,
              expectedLead: 'The latest verified activity near Driveway was',
              expectedDetail: null,
              expectedArea: 'Driveway',
            ),
            (
              prompt: 'check the driveway side',
              context: const <String>[],
              events: verificationHistory(
                prefix: 'directional-driveway-side',
                zone: 'Driveway',
                headline: 'Driveway motion alert',
                summary: 'Vehicle movement triggered a review on the driveway.',
                riskScore: 58,
                offset: const Duration(minutes: 11),
              ),
              expectedIntent: OnyxCommandIntent.triageNextMove,
              expectedLead: 'The latest verified activity near Driveway was',
              expectedDetail: null,
              expectedArea: 'Driveway',
            ),
            (
              prompt: 'was that the other entrance from before?',
              context: const <String>[
                'The latest confirmed alert was front gate movement at 21:14.',
                'The latest confirmed alert was back entrance movement at 21:09.',
              ],
              events: activeIncidentHistory(
                prefix: 'directional-other-entrance',
                occurredAt: now.subtract(const Duration(minutes: 18)),
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary:
                    'Repeated movement triggered review at the back entrance.',
                riskScore: 74,
              ),
              expectedIntent: OnyxCommandIntent.summarizeIncident,
              expectedLead:
                  'The latest confirmed alert points to Back Entrance again.',
              expectedDetail: 'Response is still active.',
              expectedArea: 'Back Entrance',
            ),
            (
              prompt: 'check the one by the entrance',
              context: const <String>[
                'The latest verified activity near Front Gate was routine movement at 21:14.',
                'The latest verified activity near Back Entrance was routine movement at 21:09.',
              ],
              events: verificationHistory(
                prefix: 'directional-entrance-proximity',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary:
                    'Repeated movement triggered review at the back entrance.',
                riskScore: 66,
                offset: const Duration(minutes: 13),
              ),
              expectedIntent: OnyxCommandIntent.triageNextMove,
              expectedLead:
                  'The latest verified activity near Back Entrance was',
              expectedDetail: null,
              expectedArea: 'Back Entrance',
            ),
            (
              prompt: 'did the perimeter side settle down?',
              context: const <String>[
                'The latest confirmed alert was perimeter movement at 21:14.',
              ],
              events: settledIncidentHistory(
                prefix: 'directional-perimeter-side-settled',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 63,
              ),
              expectedIntent: OnyxCommandIntent.summarizeIncident,
              expectedLead: 'The earlier Perimeter signal has settled.',
              expectedDetail:
                  'It was reviewed properly and is not sitting as an active incident now.',
              expectedArea: 'Perimeter',
            ),
            (
              prompt: 'check the one near the back',
              context: const <String>[
                'The latest verified activity near Front Gate was routine movement at 21:14.',
                'The latest verified activity near Back Entrance was routine movement at 21:09.',
              ],
              events: verificationHistory(
                prefix: 'directional-back-proximity',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary:
                    'Repeated movement triggered review at the back entrance.',
                riskScore: 69,
                offset: const Duration(minutes: 18),
              ),
              expectedIntent: OnyxCommandIntent.triageNextMove,
              expectedLead:
                  'The latest verified activity near Back Entrance was',
              expectedDetail:
                  'Repeated movement triggered review at the back entrance at',
              expectedArea: 'Back Entrance',
            ),
          ];

      for (final scenario in cases) {
        final response = service.handle(
          request: OnyxTelegramCommandRequest(
            telegramUserId: 'tg-client-33gx',
            telegramGroupId: 'tg-sandton',
            role: OnyxAuthorityRole.client,
            prompt: scenario.prompt,
            groupBinding: binding,
            userAllowedClientIds: const {'CLIENT-SANDTON'},
            userAllowedSiteIds: const {'SITE-SANDTON'},
            requestedClientId: 'CLIENT-SANDTON',
            requestedSiteId: 'SITE-SANDTON',
            requestedSiteLabel: 'Sandton Estate',
            recentThreadContextTexts: scenario.context,
          ),
          events: scenario.events,
        );

        expect(response.handled, isTrue, reason: scenario.prompt);
        expect(response.allowed, isTrue, reason: scenario.prompt);
        expect(
          response.intent,
          scenario.expectedIntent,
          reason: scenario.prompt,
        );
        expect(
          response.text,
          contains(scenario.expectedLead),
          reason: scenario.prompt,
        );
        if (scenario.expectedDetail case final expectedDetail?) {
          expect(
            response.text,
            contains(expectedDetail),
            reason: scenario.prompt,
          );
        }
        expect(
          response.text,
          contains(
            'I do not have live visual confirmation on ${scenario.expectedArea}',
          ),
          reason: scenario.prompt,
        );
      }
    },
  );

  test(
    'telegram operational service keeps the directional and landmark ambiguity matrix stable',
    () {
      final cases =
          <
            ({
              String prompt,
              OnyxCommandIntent expectedIntent,
              RegExp expectedAnchor,
              String expectedFollowUp,
            })
          >[
            (
              prompt: 'check the entrance side',
              expectedIntent: OnyxCommandIntent.triageNextMove,
              expectedAnchor: RegExp(
                'I’m not fully certain whether you mean (Front Entrance or Back Entrance|Back Entrance or Front Entrance)\\.',
              ),
              expectedFollowUp:
                  'If you tell me which one you want checked first, I’ll focus the next verified update there.',
            ),
            (
              prompt: 'did the far side settle down?',
              expectedIntent: OnyxCommandIntent.summarizeIncident,
              expectedAnchor: RegExp(
                'I’m not fully certain whether you mean (Front Gate or Back Gate|Back Gate or Front Gate)\\.',
              ),
              expectedFollowUp:
                  'If you tell me which one you mean, I’ll anchor the next verified answer there.',
            ),
            (
              prompt: 'did that side settle down?',
              expectedIntent: OnyxCommandIntent.summarizeIncident,
              expectedAnchor: RegExp(
                'I’m not fully certain whether you mean (Front Gate or Back Gate|Back Gate or Front Gate)\\.',
              ),
              expectedFollowUp:
                  'If you tell me which one you mean, I’ll anchor the next verified answer there.',
            ),
            (
              prompt: 'did the left side settle down?',
              expectedIntent: OnyxCommandIntent.summarizeIncident,
              expectedAnchor: RegExp(
                'I’m not fully certain whether you mean (Front Gate or Back Gate|Back Gate or Front Gate)\\.',
              ),
              expectedFollowUp:
                  'If you tell me which one you mean, I’ll anchor the next verified answer there.',
            ),
            (
              prompt: 'did they get to the other side yet?',
              expectedIntent: OnyxCommandIntent.summarizeIncident,
              expectedAnchor: RegExp(
                'I’m not fully certain whether you mean (Front Gate or Back Entrance|Back Entrance or Front Gate)\\.',
              ),
              expectedFollowUp:
                  'If you tell me which one you mean, I’ll confirm whether response has arrived there.',
            ),
            (
              prompt: 'did they get to the othr side yet?',
              expectedIntent: OnyxCommandIntent.summarizeIncident,
              expectedAnchor: RegExp(
                'I’m not fully certain whether you mean (Front Gate or Back Entrance|Back Entrance or Front Gate)\\.',
              ),
              expectedFollowUp:
                  'If you tell me which one you mean, I’ll confirm whether response has arrived there.',
            ),
            (
              prompt: 'did they get there on the other side?',
              expectedIntent: OnyxCommandIntent.summarizeIncident,
              expectedAnchor: RegExp(
                'I’m not fully certain whether you mean (Front Gate or Back Entrance|Back Entrance or Front Gate)\\.',
              ),
              expectedFollowUp:
                  'If you tell me which one you mean, I’ll confirm whether response has arrived there.',
            ),
            (
              prompt: 'so someone on the other side since then?',
              expectedIntent: OnyxCommandIntent.summarizeIncident,
              expectedAnchor: RegExp(
                'I’m not fully certain whether you mean (Front Gate or Back Entrance|Back Entrance or Front Gate)\\.',
              ),
              expectedFollowUp:
                  'If you tell me which one you mean, I’ll confirm whether response has arrived there.',
            ),
            (
              prompt: 'so still someone over there then?',
              expectedIntent: OnyxCommandIntent.summarizeIncident,
              expectedAnchor: RegExp(
                'I’m not fully certain whether you mean (Front Gate or Back Entrance|Back Entrance or Front Gate)\\.',
              ),
              expectedFollowUp:
                  'If you tell me which one you mean, I’ll confirm whether response has arrived there.',
            ),
          ];

      for (final scenario in cases) {
        final response = service.handle(
          request: OnyxTelegramCommandRequest(
            telegramUserId: 'tg-client-33gy',
            telegramGroupId: 'tg-sandton',
            role: OnyxAuthorityRole.client,
            prompt: scenario.prompt,
            groupBinding: binding,
            userAllowedClientIds: const {'CLIENT-SANDTON'},
            userAllowedSiteIds: const {'SITE-SANDTON'},
            requestedClientId: 'CLIENT-SANDTON',
            requestedSiteId: 'SITE-SANDTON',
            requestedSiteLabel: 'Sandton Estate',
            recentThreadContextTexts:
                scenario.prompt == 'check the entrance side'
                ? const <String>[
                    'The latest verified activity near Front Entrance was routine movement at 21:14.',
                    'The latest verified activity near Back Entrance was routine movement at 21:09.',
                  ]
                : scenario.prompt == 'did they get to the other side yet?' ||
                      scenario.prompt == 'did they get to the othr side yet?' ||
                      scenario.prompt ==
                          'did they get there on the other side?' ||
                      scenario.prompt ==
                          'so someone on the other side since then?' ||
                      scenario.prompt == 'so still someone over there then?'
                ? const <String>[
                    'Front Gate had movement at 21:14.',
                    'Back Entrance had movement at 21:18.',
                  ]
                : const <String>[
                    'The latest confirmed alert was front gate movement at 21:14.',
                    'The latest confirmed alert was back gate movement at 21:09.',
                  ],
          ),
          events: const <DispatchEvent>[],
        );

        expect(response.handled, isTrue, reason: scenario.prompt);
        expect(response.allowed, isTrue, reason: scenario.prompt);
        expect(
          response.intent,
          scenario.expectedIntent,
          reason: scenario.prompt,
        );
        expect(
          response.text,
          matches(scenario.expectedAnchor),
          reason: scenario.prompt,
        );
        expect(
          response.text,
          contains(scenario.expectedFollowUp),
          reason: scenario.prompt,
        );
      }
    },
  );

  test('telegram operational service keeps the other-one ambiguity matrix stable', () {
    final cases =
        <
          ({
            String prompt,
            OnyxCommandIntent expectedIntent,
            String expectedFollowUp,
          })
        >[
          (
            prompt: 'check the other one',
            expectedIntent: OnyxCommandIntent.triageNextMove,
            expectedFollowUp:
                'If you tell me which one you want checked first, I’ll focus the next verified update there.',
          ),
          (
            prompt: 'did they check the other one?',
            expectedIntent: OnyxCommandIntent.triageNextMove,
            expectedFollowUp:
                'If you tell me which one you mean, I’ll confirm whether it was checked.',
          ),
          (
            prompt: 'did they check the othr one?',
            expectedIntent: OnyxCommandIntent.triageNextMove,
            expectedFollowUp:
                'If you tell me which one you mean, I’ll confirm whether it was checked.',
          ),
          (
            prompt: 'did they check tht one?',
            expectedIntent: OnyxCommandIntent.triageNextMove,
            expectedFollowUp:
                'If you tell me which one you mean, I’ll confirm whether it was checked.',
          ),
        ];

    for (final scenario in cases) {
      final response = service.handle(
        request: OnyxTelegramCommandRequest(
          telegramUserId: 'tg-client-33gz',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.client,
          prompt: scenario.prompt,
          groupBinding: binding,
          userAllowedClientIds: const {'CLIENT-SANDTON'},
          userAllowedSiteIds: const {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
          recentThreadContextTexts: const <String>[
            'The latest verified activity near Front Gate was routine movement at 21:14.',
            'The latest verified activity near Back Gate was routine movement at 21:09.',
          ],
        ),
        events: const <DispatchEvent>[],
      );

      expect(response.handled, isTrue, reason: scenario.prompt);
      expect(response.allowed, isTrue, reason: scenario.prompt);
      expect(response.intent, scenario.expectedIntent, reason: scenario.prompt);
      expect(
        response.text,
        matches(
          RegExp(
            'I’m not fully certain whether you mean (Front Gate or Back Gate|Back Gate or Front Gate)\\.',
          ),
        ),
        reason: scenario.prompt,
      );
      expect(
        response.text,
        contains(scenario.expectedFollowUp),
        reason: scenario.prompt,
      );
    }
  });

  test(
    'telegram operational service keeps the common read prompt matrix stable',
    () {
      final now = DateTime.now().toUtc();
      final localNow = now.toLocal();
      final weekStart = DateTime(
        localNow.year,
        localNow.month,
        localNow.day,
      ).subtract(Duration(days: localNow.weekday - DateTime.monday));
      final overnightEnd = DateTime(
        localNow.year,
        localNow.month,
        localNow.day,
        6,
      );
      final overnightStart = DateTime(
        overnightEnd.year,
        overnightEnd.month,
        overnightEnd.day,
      ).subtract(const Duration(days: 1)).add(const Duration(hours: 18));

      final sharedEvents = <DispatchEvent>[
        PatrolCompleted(
          eventId: 'matrix-patrol-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 17)),
          guardId: 'Guard001',
          routeId: 'NORTH-PERIMETER',
          clientId: 'CLIENT-SANDTON',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          durationSeconds: 19 * 60,
        ),
        PatrolCompleted(
          eventId: 'matrix-patrol-2',
          sequence: 2,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 42)),
          guardId: 'Guard002',
          routeId: 'SOUTH-WALK',
          clientId: 'CLIENT-SANDTON',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          durationSeconds: 21 * 60,
        ),
        PatrolCompleted(
          eventId: 'matrix-patrol-3',
          sequence: 3,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 24)),
          guardId: 'Guard003',
          routeId: 'WEST-GATE',
          clientId: 'CLIENT-SANDTON',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          durationSeconds: 17 * 60,
        ),
        DecisionCreated(
          eventId: 'matrix-decision-unresolved',
          sequence: 4,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 15)),
          dispatchId: 'DSP-UNRESOLVED',
          clientId: 'CLIENT-SANDTON',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
        ),
        DecisionCreated(
          eventId: 'matrix-decision-closed',
          sequence: 5,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 25)),
          dispatchId: 'DSP-CLOSED',
          clientId: 'CLIENT-SANDTON',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
        ),
        IncidentClosed(
          eventId: 'matrix-closed',
          sequence: 6,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 10)),
          dispatchId: 'DSP-CLOSED',
          resolutionType: 'all_clear',
          clientId: 'CLIENT-SANDTON',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
        ),
        DecisionCreated(
          eventId: 'matrix-night-1',
          sequence: 7,
          version: 1,
          occurredAt: overnightStart
              .add(const Duration(hours: 2, minutes: 7))
              .toUtc(),
          dispatchId: 'DSP-N1',
          clientId: 'CLIENT-SANDTON',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
        ),
        DecisionCreated(
          eventId: 'matrix-night-2',
          sequence: 8,
          version: 1,
          occurredAt: overnightStart
              .add(const Duration(hours: 5, minutes: 4))
              .toUtc(),
          dispatchId: 'DSP-N2',
          clientId: 'CLIENT-SANDTON',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
        ),
        IntelligenceReceived(
          eventId: 'matrix-intel-1',
          sequence: 9,
          version: 1,
          occurredAt: weekStart.add(const Duration(hours: 2)).toUtc(),
          intelligenceId: 'INT-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-1',
          clientId: 'CLIENT-SANDTON',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          headline: 'Boundary alert',
          summary: 'Boundary alert detected.',
          riskScore: 60,
          canonicalHash: 'hash-1',
        ),
        IntelligenceReceived(
          eventId: 'matrix-intel-2',
          sequence: 10,
          version: 1,
          occurredAt: weekStart.add(const Duration(days: 1, hours: 1)).toUtc(),
          intelligenceId: 'INT-2',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-2',
          clientId: 'CLIENT-SANDTON',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          headline: 'Gate alert',
          summary: 'Unexpected person detected.',
          riskScore: 72,
          canonicalHash: 'hash-2',
        ),
        IntelligenceReceived(
          eventId: 'matrix-intel-3',
          sequence: 11,
          version: 1,
          occurredAt: weekStart.add(const Duration(days: 2, hours: 4)).toUtc(),
          intelligenceId: 'INT-3',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-3',
          clientId: 'CLIENT-SANDTON',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          headline: 'Driveway alert',
          summary: 'Vehicle detected near the driveway.',
          riskScore: 58,
          canonicalHash: 'hash-3',
        ),
      ];

      final cases =
          <
            ({
              String prompt,
              String expected,
              OnyxCommandIntent intent,
              String requestedSiteId,
              String requestedSiteLabel,
              String requestedClientLabel,
            })
          >[
            (
              prompt: 'Show unresolved incidents',
              expected: 'Unresolved incidents in Sandton Estate:',
              intent: OnyxCommandIntent.showUnresolvedIncidents,
              requestedSiteId: 'SITE-SANDTON',
              requestedSiteLabel: 'Sandton Estate',
              requestedClientLabel: '',
            ),
            (
              prompt: 'Which site has most alerts this week',
              expected: "This week's alert leader: Sandton (2 alerts)",
              intent: OnyxCommandIntent.showSiteMostAlertsThisWeek,
              requestedSiteId: '',
              requestedSiteLabel: '',
              requestedClientLabel: 'Sandton Portfolio',
            ),
            (
              prompt: 'Show incidents last night',
              expected: "Last night's incidents for Sandton Estate:",
              intent: OnyxCommandIntent.showIncidentsLastNight,
              requestedSiteId: 'SITE-SANDTON',
              requestedSiteLabel: 'Sandton Estate',
              requestedClientLabel: '',
            ),
            (
              prompt: 'Check tonights breaches',
              expected: "Tonight's incidents for Sandton Estate:",
              intent: OnyxCommandIntent.showIncidentsLastNight,
              requestedSiteId: 'SITE-SANDTON',
              requestedSiteLabel: 'Sandton Estate',
              requestedClientLabel: '',
            ),
            (
              prompt: 'Check status of Guard001',
              expected: 'Latest guard status for Guard001 in Sandton Estate:',
              intent: OnyxCommandIntent.guardStatusLookup,
              requestedSiteId: 'SITE-SANDTON',
              requestedSiteLabel: 'Sandton Estate',
              requestedClientLabel: '',
            ),
            (
              prompt: 'Show last patrol report for Guard001',
              expected: 'Last patrol report for Guard001 in Sandton Estate:',
              intent: OnyxCommandIntent.patrolReportLookup,
              requestedSiteId: 'SITE-SANDTON',
              requestedSiteLabel: 'Sandton Estate',
              requestedClientLabel: '',
            ),
            (
              prompt: 'Check guards',
              expected: 'Latest guard status in Sandton Estate:',
              intent: OnyxCommandIntent.guardStatusLookup,
              requestedSiteId: 'SITE-SANDTON',
              requestedSiteLabel: 'Sandton Estate',
              requestedClientLabel: '',
            ),
          ];

      for (final scenario in cases) {
        final response = service.handle(
          request: OnyxTelegramCommandRequest(
            telegramUserId: 'tg-user-17',
            telegramGroupId: 'tg-sandton',
            role: OnyxAuthorityRole.supervisor,
            prompt: scenario.prompt,
            groupBinding: binding,
            userAllowedClientIds: const {'CLIENT-SANDTON'},
            userAllowedSiteIds: const {'SITE-SANDTON', 'SITE-VALLEE'},
            requestedClientId: 'CLIENT-SANDTON',
            requestedSiteId: scenario.requestedSiteId,
            requestedSiteLabel: scenario.requestedSiteLabel,
            requestedClientLabel: scenario.requestedClientLabel,
          ),
          events: sharedEvents,
        );

        expect(response.handled, isTrue, reason: scenario.prompt);
        expect(response.allowed, isTrue, reason: scenario.prompt);
        expect(response.intent, scenario.intent, reason: scenario.prompt);
        expect(
          response.text,
          contains(scenario.expected),
          reason: scenario.prompt,
        );
      }
    },
  );
}
