import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/domain/guard/guard_mobile_ops.dart';
import 'package:omnix_dashboard/infrastructure/intelligence/news_intelligence_service.dart';
import 'package:omnix_dashboard/application/radio_bridge_service.dart';
import 'package:omnix_dashboard/ui/client_app_page.dart';
import 'package:omnix_dashboard/ui/dispatch_page.dart';

void main() {
  group('DispatchPersistenceService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and restores telemetry', () async {
      final service = await DispatchPersistenceService.create();
      final telemetry = IntakeTelemetry.zero
          .add(
            label: 'STR-PERSIST',
            cancelled: false,
            attempted: 1000,
            appended: 900,
            skipped: 100,
            decisions: 50,
            throughput: 220,
            p50Throughput: 210,
            p95Throughput: 230,
            verifyMs: 70,
            chunkSize: 600,
            chunks: 2,
            avgChunkMs: 24,
            maxChunkMs: 40,
            slowChunks: 0,
            duplicatesInjected: 10,
            uniqueFeeds: 2,
            peakPending: 1000,
            siteDistribution: const {'SITE-SANDTON': 700, 'SITE-MIDRAND': 300},
            feedDistribution: const {'feed-01': 500, 'feed-02': 500},
            burstSize: 1000,
          )
          .withSoakSummary(runs: 2, throughputDrift: -12.5, verifyDriftMs: 90);

      await service.saveTelemetry(telemetry);
      final restored = await service.readTelemetry();

      expect(restored, isNotNull);
      expect(restored!.toJson(), telemetry.toJson());
    });

    test('saves and restores stress profile draft', () async {
      final service = await DispatchPersistenceService.create();
      final profile = IntakeStressPreset.heavy.profile.copyWith(
        regressionThroughputDrop: 40,
        regressionVerifyIncreaseMs: 200,
        maxRegressionPressureSeverity: 1,
        maxRegressionImbalanceSeverity: 1,
      );
      final draft = DispatchProfileDraft(
        profile: profile,
        scenarioLabel: 'Hotspot replay',
        tags: const ['soak', 'skew'],
        runNote: 'Shift handoff',
        filterPresets: const [
          DispatchBenchmarkFilterPreset(
            name: 'Degraded Only',
            updatedAtUtc: '2026-03-03T12:00:00.000Z',
            showCancelledRuns: false,
            statusFilters: ['DEGRADED'],
            scenarioFilter: 'Hotspot replay',
            tagFilter: 'soak',
            noteFilter: 'Shift',
            sort: 'throughputDesc',
            historyLimit: 3,
          ),
        ],
      );

      await service.saveStressProfile(draft);
      final restored = await service.readStressProfile();

      expect(restored, isNotNull);
      expect(restored!.toJson(), draft.toJson());
    });

    test('saves and restores live poll history', () async {
      final service = await DispatchPersistenceService.create();
      const history = [
        '20:10:00Z • OK • 120ms • 3 records',
        '20:09:45Z • FAIL • 98ms • HTTP 500',
      ];

      await service.saveLivePollHistory(history);
      final restored = await service.readLivePollHistory();

      expect(restored, history);
    });

    test('saves, restores, and clears radio intent phrase json', () async {
      final service = await DispatchPersistenceService.create();
      const rawJson =
          '{"all_clear":["all clear"],"panic":["panic"],"duress":["duress"],"status":["status"]}';

      await service.saveRadioIntentPhrasesJson(rawJson);
      final restored = await service.readRadioIntentPhrasesJson();

      expect(restored, rawJson);

      await service.clearRadioIntentPhrasesJson();
      final cleared = await service.readRadioIntentPhrasesJson();
      expect(cleared, isNull);
    });

    test(
      'saves, restores, and clears pending radio automated responses',
      () async {
        final service = await DispatchPersistenceService.create();
        final responses = const [
          RadioAutomatedResponse(
            transmissionId: 'ZEL-9001',
            provider: 'zello',
            channel: 'ops-primary',
            clientId: 'CLIENT-001',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            dispatchId: 'DSP-9',
            message: 'ONYX AI marked dispatch DSP-9 all clear.',
          ),
        ];

        await service.savePendingRadioAutomatedResponses(responses);
        final restored = await service.readPendingRadioAutomatedResponses();

        expect(restored, hasLength(1));
        expect(restored.single.toJson(), responses.single.toJson());

        await service.clearPendingRadioAutomatedResponses();
        final cleared = await service.readPendingRadioAutomatedResponses();
        expect(cleared, isEmpty);
      },
    );

    test('saves, restores, and clears pending radio retry state', () async {
      final service = await DispatchPersistenceService.create();
      final retryState = <String, Map<String, Object?>>{
        'ZEL-9001||ops-primary|ack': {
          'attempts': 3,
          'next_attempt_at_utc': '2026-03-11T12:15:00.000Z',
          'last_error': 'send_failed',
        },
      };

      await service.savePendingRadioAutomatedResponsesRetryState(retryState);
      final restored = await service
          .readPendingRadioAutomatedResponsesRetryState();

      expect(restored, retryState);

      await service.clearPendingRadioAutomatedResponsesRetryState();
      final cleared = await service
          .readPendingRadioAutomatedResponsesRetryState();
      expect(cleared, isEmpty);
    });

    test(
      'saves, restores, and clears radio queue manual action detail',
      () async {
        final service = await DispatchPersistenceService.create();
        const detail = 'Retry requested for 3 queued • 10:05:30 UTC';

        await service.savePendingRadioQueueManualActionDetail(detail);
        final restored = await service
            .readPendingRadioQueueManualActionDetail();

        expect(restored, detail);

        await service.clearPendingRadioQueueManualActionDetail();
        final cleared = await service.readPendingRadioQueueManualActionDetail();
        expect(cleared, isNull);
      },
    );

    test('saves, restores, and clears radio queue failure snapshot', () async {
      final service = await DispatchPersistenceService.create();
      const detail =
          'ZEL-9001 • reason send_failed • count 2 • at 10:05:30 UTC';

      await service.savePendingRadioQueueFailureSnapshot(detail);
      final restored = await service.readPendingRadioQueueFailureSnapshot();

      expect(restored, detail);

      await service.clearPendingRadioQueueFailureSnapshot();
      final cleared = await service.readPendingRadioQueueFailureSnapshot();
      expect(cleared, isNull);
    });

    test(
      'saves, restores, and clears radio queue failure audit detail',
      () async {
        final service = await DispatchPersistenceService.create();
        const detail = 'Failure snapshot cleared • 10:06:00 UTC';

        await service.savePendingRadioQueueFailureAuditDetail(detail);
        final restored = await service
            .readPendingRadioQueueFailureAuditDetail();

        expect(restored, detail);

        await service.clearPendingRadioQueueFailureAuditDetail();
        final cleared = await service.readPendingRadioQueueFailureAuditDetail();
        expect(cleared, isNull);
      },
    );

    test(
      'saves, restores, and clears radio queue state change detail',
      () async {
        final service = await DispatchPersistenceService.create();
        const detail = 'Queue updated via ingest • 10:06:20 UTC';

        await service.savePendingRadioQueueStateChangeDetail(detail);
        final restored = await service.readPendingRadioQueueStateChangeDetail();

        expect(restored, detail);

        await service.clearPendingRadioQueueStateChangeDetail();
        final cleared = await service.readPendingRadioQueueStateChangeDetail();
        expect(cleared, isNull);
      },
    );

    test(
      'saves, restores, and clears ops integration health snapshot',
      () async {
        final service = await DispatchPersistenceService.create();
        final snapshot = <String, Object?>{
          'radio': {
            'ok_count': 4,
            'fail_count': 1,
            'skip_count': 0,
            'last_run_at_utc': '2026-03-11T10:06:20.000Z',
            'last_detail': '4/4 appended',
          },
          'cctv': {
            'ok_count': 2,
            'fail_count': 0,
            'skip_count': 1,
            'last_run_at_utc': '2026-03-11T10:06:20.000Z',
            'last_detail': '2/2 appended',
          },
        };

        await service.saveOpsIntegrationHealthSnapshot(snapshot);
        final restored = await service.readOpsIntegrationHealthSnapshot();

        expect(restored, snapshot);

        await service.clearOpsIntegrationHealthSnapshot();
        final cleared = await service.readOpsIntegrationHealthSnapshot();
        expect(cleared, isEmpty);
      },
    );

    test('saves and restores live poll summary', () async {
      final service = await DispatchPersistenceService.create();
      final summary = <String, Object?>{
        'latencyMs': 120,
        'successAtUtc': '2026-03-03T20:10:00.000Z',
        'failureAtUtc': '2026-03-03T20:09:45.000Z',
        'error': 'HTTP 500',
        'failures': 2,
        'delaySeconds': 60,
      };

      await service.saveLivePollSummary(summary);
      final restored = await service.readLivePollSummary();

      expect(restored, summary);
    });

    test('saves and restores news source diagnostics', () async {
      final service = await DispatchPersistenceService.create();
      const diagnostics = [
        NewsSourceDiagnostic(
          provider: 'newsapi.org',
          status: 'reachable',
          detail: 'Probe succeeded with 2 ingestible record(s).',
          checkedAtUtc: '2026-03-04T10:15:00.000Z',
        ),
      ];

      await service.saveNewsSourceDiagnostics(diagnostics);
      final restored = await service.readNewsSourceDiagnostics();

      expect(restored.map((entry) => entry.toJson()).toList(), [
        diagnostics.first.toJson(),
      ]);
    });

    test('saves and restores client app draft', () async {
      final service = await DispatchPersistenceService.create();
      final draft = ClientAppDraft(
        viewerRole: ClientAppViewerRole.control,
        selectedRoom: 'Trustees',
        selectedRoomByRole: const {
          'client': 'Trustees',
          'control': 'Security Desk',
        },
        showAllRoomItemsByRole: const {'client': true, 'control': false},
        expandedIncidentReference: 'DISP-001',
        hasTouchedIncidentExpansion: true,
        selectedIncidentReferenceByRole: const {
          'client': 'DISP-SELECTED-001',
          'control': 'DISP-CTRL-SELECTED',
        },
        expandedIncidentReferenceByRole: const {
          'client': 'DISP-001',
          'control': 'DISP-CTRL-002',
        },
        hasTouchedIncidentExpansionByRole: const {
          'client': true,
          'control': true,
        },
        focusedIncidentReferenceByRole: const {
          'client': 'DISP-FOCUS-001',
          'control': 'DISP-CTRL-FOCUS',
        },
      );

      await service.saveClientAppDraft(draft);
      final restored = await service.readClientAppDraft();

      expect(restored, isNotNull);
      expect(restored!.toJson(), draft.toJson());
      expect(restored.viewerRole, ClientAppViewerRole.control);
      expect(
        restored.selectedRoomFor(ClientAppViewerRole.control),
        'Security Desk',
      );
      expect(restored.expandedIncidentReference, 'DISP-001');
      expect(restored.hasTouchedIncidentExpansion, isTrue);
      expect(
        restored.selectedIncidentReferenceFor(ClientAppViewerRole.control),
        'DISP-CTRL-SELECTED',
      );
      expect(
        restored.expandedIncidentReferenceFor(ClientAppViewerRole.control),
        'DISP-CTRL-002',
      );
      expect(
        restored.hasTouchedIncidentExpansionFor(ClientAppViewerRole.control),
        isTrue,
      );
      expect(
        restored.focusedIncidentReferenceByRole[ClientAppViewerRole
            .control
            .name],
        'DISP-CTRL-FOCUS',
      );
      expect(restored.legacyManualMessages, isEmpty);
      expect(restored.legacyAcknowledgements, isEmpty);
    });

    test('saves and restores client conversation state', () async {
      final service = await DispatchPersistenceService.create();
      final messages = [
        ClientAppMessage(
          author: 'Control',
          body: 'Desk ops update logged.',
          occurredAt: DateTime.utc(2026, 3, 4, 11, 5),
          roomKey: 'Security Desk',
          viewerRole: 'control',
          incidentStatusLabel: 'Opened',
          messageSource: 'telegram',
          messageProvider: 'openai',
        ),
      ];
      final acknowledgements = [
        ClientAppAcknowledgement(
          messageKey: 'client:1710000000000:Control',
          channel: ClientAppAcknowledgementChannel.control,
          acknowledgedBy: 'Control',
          acknowledgedAt: DateTime.utc(2026, 3, 4, 11, 6),
        ),
      ];
      final pushQueue = [
        ClientAppPushDeliveryItem(
          messageKey: 'system:1710000000000:Dispatch created',
          title: 'Dispatch created',
          body: 'Response team activated for SITE-SANDTON.',
          occurredAt: DateTime.utc(2026, 3, 4, 11, 7),
          targetChannel: ClientAppAcknowledgementChannel.client,
          priority: true,
          status: ClientPushDeliveryStatus.queued,
        ),
      ];

      await service.saveClientAppMessages(messages);
      await service.saveClientAppAcknowledgements(acknowledgements);
      await service.saveClientAppPushQueue(pushQueue);

      final restoredMessages = await service.readClientAppMessages();
      final restoredAcknowledgements = await service
          .readClientAppAcknowledgements();
      final restoredPushQueue = await service.readClientAppPushQueue();

      expect(
        restoredMessages.map((entry) => entry.toJson()).toList(),
        messages.map((entry) => entry.toJson()).toList(),
      );
      expect(
        restoredAcknowledgements.map((entry) => entry.toJson()).toList(),
        acknowledgements.map((entry) => entry.toJson()).toList(),
      );
      expect(
        restoredPushQueue.map((entry) => entry.toJson()).toList(),
        pushQueue.map((entry) => entry.toJson()).toList(),
      );
    });

    test('saves and restores client push sync state', () async {
      final service = await DispatchPersistenceService.create();
      final state = ClientPushSyncState(
        statusLabel: 'failed',
        lastSyncedAtUtc: DateTime.utc(2026, 3, 5, 10, 30),
        failureReason: 'timeout',
        retryCount: 2,
        history: [
          ClientPushSyncAttempt(
            occurredAt: DateTime.utc(2026, 3, 5, 10, 31),
            status: 'ok',
            queueSize: 0,
          ),
          ClientPushSyncAttempt(
            occurredAt: DateTime.utc(2026, 3, 5, 10, 30),
            status: 'failed',
            failureReason: 'timeout',
            queueSize: 2,
          ),
        ],
        backendProbeStatusLabel: 'failed',
        backendProbeLastRunAtUtc: DateTime.utc(2026, 3, 5, 10, 32),
        backendProbeFailureReason: 'network down',
        backendProbeHistory: [
          ClientBackendProbeAttempt(
            occurredAt: DateTime.utc(2026, 3, 5, 10, 32),
            status: 'failed',
            failureReason: 'network down',
          ),
        ],
      );

      await service.saveClientAppPushSyncState(state);
      final restored = await service.readClientAppPushSyncState();

      expect(restored.toJson(), state.toJson());
    });

    test('saves, restores, and clears telegram admin runtime state', () async {
      final service = await DispatchPersistenceService.create();
      final state = <String, Object?>{
        'execution_enabled_override': false,
        'poll_interval_override_seconds': 5,
        'critical_reminder_override_seconds': 180,
        'critical_snoozed_until_utc': '2026-03-12T15:30:00.000Z',
        'critical_ack_fingerprint': 'a|b|c',
        'critical_ack_at_utc': '2026-03-12T15:00:00.000Z',
        'critical_alert_fingerprint': 'x|y|z',
        'last_critical_alert_at_utc': '2026-03-12T14:58:00.000Z',
        'last_critical_alert_summary': 'active(2) via admin-control-loop',
        'last_command_at_utc': '2026-03-12T15:01:00.000Z',
        'last_command_summary': '/status by @owner',
        'command_audit': <String>[
          '/status by @owner (-5247743742) @ 2026-03-12T15:01:00.000Z',
        ],
      };

      await service.saveTelegramAdminRuntimeState(state);
      final restored = await service.readTelegramAdminRuntimeState();

      expect(restored, state);

      await service.clearTelegramAdminRuntimeState();
      final cleared = await service.readTelegramAdminRuntimeState();
      expect(cleared, isEmpty);
    });

    test('saves and restores guard assignments and sync operations', () async {
      final service = await DispatchPersistenceService.create();
      final assignments = [
        GuardAssignment(
          assignmentId: 'ASSIGN-001',
          dispatchId: 'DISP-001',
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          guardId: 'GUARD-001',
          issuedAt: DateTime.utc(2026, 3, 4, 11, 20),
          acknowledgedAt: DateTime.utc(2026, 3, 4, 11, 21),
          status: GuardDutyStatus.enRoute,
        ),
      ];
      final operations = [
        GuardSyncOperation(
          operationId: 'status:ASSIGN-001:enRoute:2026-03-04T11:21:00.000Z',
          type: GuardSyncOperationType.statusUpdate,
          createdAt: DateTime.utc(2026, 3, 4, 11, 21),
          payload: const {'assignment_id': 'ASSIGN-001', 'status': 'enRoute'},
        ),
      ];

      await service.saveGuardAssignments(assignments);
      await service.saveGuardSyncOperations(operations);

      final restoredAssignments = await service.readGuardAssignments();
      final restoredOperations = await service.readGuardSyncOperations();

      expect(
        restoredAssignments.map((entry) => entry.toJson()).toList(),
        assignments.map((entry) => entry.toJson()).toList(),
      );
      expect(
        restoredOperations.map((entry) => entry.toJson()).toList(),
        operations.map((entry) => entry.toJson()).toList(),
      );
    });

    test('saves and restores guard sync history filter', () async {
      final service = await DispatchPersistenceService.create();

      await service.saveGuardSyncHistoryFilter('failed');
      final restored = await service.readGuardSyncHistoryFilter();

      expect(restored, 'failed');
    });

    test('saves and restores guard sync operation mode filter', () async {
      final service = await DispatchPersistenceService.create();

      await service.saveGuardSyncOperationModeFilter('live');
      final restored = await service.readGuardSyncOperationModeFilter();

      expect(restored, 'live');
    });

    test('saves and restores guard sync selected facade id', () async {
      final service = await DispatchPersistenceService.create();

      await service.saveGuardSyncSelectedFacadeId('fsk_sdk_facade_live');
      final restored = await service.readGuardSyncSelectedFacadeId();

      expect(restored, 'fsk_sdk_facade_live');
    });

    test('saves and restores guard sync selected operation ids', () async {
      final service = await DispatchPersistenceService.create();
      final selection = <String, String>{
        'failed': 'panic:PANIC-1',
        'queued': 'status:ASSIGN-001:enRoute',
      };

      await service.saveGuardSyncSelectedOperationIds(selection);
      final restored = await service.readGuardSyncSelectedOperationIds();

      expect(restored, selection);
    });

    test('saves and restores guard outcome governance telemetry', () async {
      final service = await DispatchPersistenceService.create();
      final telemetry = <String, Object?>{
        'totalDenied': 4,
        'lastDeniedReason': 'Supervisor required for true_threat.',
        'deniedAtUtc': <String>[
          '2026-03-05T12:00:00.000Z',
          '2026-03-05T12:10:00.000Z',
        ],
      };

      await service.saveGuardOutcomeGovernanceTelemetry(telemetry);
      final restored = await service.readGuardOutcomeGovernanceTelemetry();

      expect(restored, telemetry);
    });

    test('saves and restores guard coaching prompt snoozes', () async {
      final service = await DispatchPersistenceService.create();
      final snoozes = <String, Object?>{
        'high_failure_backlog': '2026-03-05T13:30:00.000Z',
        'queue_pressure': '2026-03-05T13:10:00.000Z',
      };

      await service.saveGuardCoachingPromptSnoozes(snoozes);
      final restored = await service.readGuardCoachingPromptSnoozes();

      expect(restored, snoozes);
    });

    test('saves and restores guard coaching telemetry', () async {
      final service = await DispatchPersistenceService.create();
      final telemetry = <String, Object?>{
        'ackCount': 3,
        'snoozeCount': 2,
        'snoozeExpiryCount': 1,
        'recentHistory': <String>[
          '[2026-03-05T12:00:00.000Z] high_failure_backlog acknowledged @ sync by guard',
        ],
      };

      await service.saveGuardCoachingTelemetry(telemetry);
      final restored = await service.readGuardCoachingTelemetry();

      expect(restored, telemetry);
    });

    test(
      'client app draft still reads legacy embedded conversation state',
      () async {
        SharedPreferences.setMockInitialValues({
          DispatchPersistenceService.clientAppDraftKey: jsonEncode({
            'viewerRole': 'client',
            'selectedRoom': 'Residents',
            'manualMessages': [
              {
                'author': 'Client',
                'body': 'Legacy update',
                'roomKey': 'Residents',
                'viewerRole': 'client',
                'incidentStatusLabel': 'Advisory',
                'occurredAt': '2026-03-04T10:25:00.000Z',
              },
            ],
            'acknowledgements': [
              {
                'messageKey': 'system:legacy',
                'channel': 'client',
                'acknowledgedBy': 'Client',
                'acknowledgedAt': '2026-03-04T10:26:00.000Z',
              },
            ],
          }),
        });
        final service = await DispatchPersistenceService.create();

        final restored = await service.readClientAppDraft();

        expect(restored, isNotNull);
        expect(restored!.legacyManualMessages, hasLength(1));
        expect(restored.legacyManualMessages.single.body, 'Legacy update');
        expect(restored.legacyAcknowledgements, hasLength(1));
        expect(
          restored.legacyAcknowledgements.single.messageKey,
          'system:legacy',
        );
        expect(restored.toJson().containsKey('manualMessages'), isFalse);
        expect(restored.toJson().containsKey('acknowledgements'), isFalse);
      },
    );

    test('clears corrupt telemetry cache', () async {
      SharedPreferences.setMockInitialValues({
        DispatchPersistenceService.intakeTelemetryKey: '{not-json',
      });
      final service = await DispatchPersistenceService.create();

      final restored = await service.readTelemetry();

      expect(restored, isNull);
      expect(
        service.prefs.containsKey(
          DispatchPersistenceService.intakeTelemetryKey,
        ),
        isFalse,
      );
    });

    test('clears corrupt stress profile cache', () async {
      SharedPreferences.setMockInitialValues({
        DispatchPersistenceService.stressProfileKey: '{not-json',
      });
      final service = await DispatchPersistenceService.create();

      final restored = await service.readStressProfile();

      expect(restored, isNull);
      expect(
        service.prefs.containsKey(DispatchPersistenceService.stressProfileKey),
        isFalse,
      );
    });

    test('clears corrupt live poll history cache', () async {
      SharedPreferences.setMockInitialValues({
        DispatchPersistenceService.livePollHistoryKey: '{not-json',
      });
      final service = await DispatchPersistenceService.create();

      final restored = await service.readLivePollHistory();

      expect(restored, isEmpty);
      expect(
        service.prefs.containsKey(
          DispatchPersistenceService.livePollHistoryKey,
        ),
        isFalse,
      );
    });

    test('clears corrupt live poll summary cache', () async {
      SharedPreferences.setMockInitialValues({
        DispatchPersistenceService.livePollSummaryKey: '{not-json',
      });
      final service = await DispatchPersistenceService.create();

      final restored = await service.readLivePollSummary();

      expect(restored, isEmpty);
      expect(
        service.prefs.containsKey(
          DispatchPersistenceService.livePollSummaryKey,
        ),
        isFalse,
      );
    });

    test('clears corrupt news source diagnostics cache', () async {
      SharedPreferences.setMockInitialValues({
        DispatchPersistenceService.newsSourceDiagnosticsKey: '{not-json',
      });
      final service = await DispatchPersistenceService.create();

      final restored = await service.readNewsSourceDiagnostics();

      expect(restored, isEmpty);
      expect(
        service.prefs.containsKey(
          DispatchPersistenceService.newsSourceDiagnosticsKey,
        ),
        isFalse,
      );
    });

    test('clears corrupt client app draft cache', () async {
      SharedPreferences.setMockInitialValues({
        DispatchPersistenceService.clientAppDraftKey: '{not-json',
      });
      final service = await DispatchPersistenceService.create();

      final restored = await service.readClientAppDraft();

      expect(restored, isNull);
      expect(
        service.prefs.containsKey(DispatchPersistenceService.clientAppDraftKey),
        isFalse,
      );
    });

    test('clears corrupt client app messages cache', () async {
      SharedPreferences.setMockInitialValues({
        DispatchPersistenceService.clientAppMessagesKey: '{not-json',
      });
      final service = await DispatchPersistenceService.create();

      final restored = await service.readClientAppMessages();

      expect(restored, isEmpty);
      expect(
        service.prefs.containsKey(
          DispatchPersistenceService.clientAppMessagesKey,
        ),
        isFalse,
      );
    });

    test('clears corrupt client app acknowledgements cache', () async {
      SharedPreferences.setMockInitialValues({
        DispatchPersistenceService.clientAppAcknowledgementsKey: '{not-json',
      });
      final service = await DispatchPersistenceService.create();

      final restored = await service.readClientAppAcknowledgements();

      expect(restored, isEmpty);
      expect(
        service.prefs.containsKey(
          DispatchPersistenceService.clientAppAcknowledgementsKey,
        ),
        isFalse,
      );
    });

    test('clears corrupt client app push queue cache', () async {
      SharedPreferences.setMockInitialValues({
        DispatchPersistenceService.clientAppPushQueueKey: '{not-json',
      });
      final service = await DispatchPersistenceService.create();

      final restored = await service.readClientAppPushQueue();

      expect(restored, isEmpty);
      expect(
        service.prefs.containsKey(
          DispatchPersistenceService.clientAppPushQueueKey,
        ),
        isFalse,
      );
    });

    test('clears corrupt guard assignments cache', () async {
      SharedPreferences.setMockInitialValues({
        DispatchPersistenceService.guardAssignmentsKey: '{not-json',
      });
      final service = await DispatchPersistenceService.create();

      final restored = await service.readGuardAssignments();

      expect(restored, isEmpty);
      expect(
        service.prefs.containsKey(
          DispatchPersistenceService.guardAssignmentsKey,
        ),
        isFalse,
      );
    });

    test('clears corrupt guard sync operations cache', () async {
      SharedPreferences.setMockInitialValues({
        DispatchPersistenceService.guardSyncOperationsKey: '{not-json',
      });
      final service = await DispatchPersistenceService.create();

      final restored = await service.readGuardSyncOperations();

      expect(restored, isEmpty);
      expect(
        service.prefs.containsKey(
          DispatchPersistenceService.guardSyncOperationsKey,
        ),
        isFalse,
      );
    });

    test('clears corrupt guard sync selected operation ids cache', () async {
      SharedPreferences.setMockInitialValues({
        DispatchPersistenceService.guardSyncSelectedOperationIdsKey:
            '{not-json',
      });
      final service = await DispatchPersistenceService.create();

      final restored = await service.readGuardSyncSelectedOperationIds();

      expect(restored, isEmpty);
      expect(
        service.prefs.containsKey(
          DispatchPersistenceService.guardSyncSelectedOperationIdsKey,
        ),
        isFalse,
      );
    });

    test('normalizes blank guard sync selected facade id to null', () async {
      final service = await DispatchPersistenceService.create();

      await service.saveGuardSyncSelectedFacadeId('   ');
      final restored = await service.readGuardSyncSelectedFacadeId();

      expect(restored, isNull);
      expect(
        service.prefs.containsKey(
          DispatchPersistenceService.guardSyncSelectedFacadeIdKey,
        ),
        isFalse,
      );
    });

    test('normalizes blank guard sync operation mode filter to null', () async {
      final service = await DispatchPersistenceService.create();

      await service.saveGuardSyncOperationModeFilter('   ');
      final restored = await service.readGuardSyncOperationModeFilter();

      expect(restored, isNull);
      expect(
        service.prefs.containsKey(
          DispatchPersistenceService.guardSyncOperationModeFilterKey,
        ),
        isFalse,
      );
    });

    test('clears corrupt guard outcome governance telemetry cache', () async {
      SharedPreferences.setMockInitialValues({
        DispatchPersistenceService.guardOutcomeGovernanceTelemetryKey:
            '{not-json',
      });
      final service = await DispatchPersistenceService.create();

      final restored = await service.readGuardOutcomeGovernanceTelemetry();

      expect(restored, isEmpty);
      expect(
        service.prefs.containsKey(
          DispatchPersistenceService.guardOutcomeGovernanceTelemetryKey,
        ),
        isFalse,
      );
    });

    test('clears corrupt guard coaching prompt snoozes cache', () async {
      SharedPreferences.setMockInitialValues({
        DispatchPersistenceService.guardCoachingPromptSnoozesKey: '{not-json',
      });
      final service = await DispatchPersistenceService.create();

      final restored = await service.readGuardCoachingPromptSnoozes();

      expect(restored, isEmpty);
      expect(
        service.prefs.containsKey(
          DispatchPersistenceService.guardCoachingPromptSnoozesKey,
        ),
        isFalse,
      );
    });

    test('clears corrupt guard coaching telemetry cache', () async {
      SharedPreferences.setMockInitialValues({
        DispatchPersistenceService.guardCoachingTelemetryKey: '{not-json',
      });
      final service = await DispatchPersistenceService.create();

      final restored = await service.readGuardCoachingTelemetry();

      expect(restored, isEmpty);
      expect(
        service.prefs.containsKey(
          DispatchPersistenceService.guardCoachingTelemetryKey,
        ),
        isFalse,
      );
    });
  });
}
