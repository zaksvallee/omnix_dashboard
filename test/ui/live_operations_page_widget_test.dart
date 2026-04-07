import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/client_camera_health_fact_packet_service.dart';
import 'package:omnix_dashboard/application/morning_sovereign_report_service.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/application/onyx_agent_client_draft_service.dart';
import 'package:omnix_dashboard/application/simulation/scenario_replay_history_signal_service.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/partner_dispatch_status_declared.dart';
import 'package:omnix_dashboard/domain/events/patrol_completed.dart';
import 'package:omnix_dashboard/ui/live_operations_page.dart';

Future<void> _openDetailedWorkspace(WidgetTester tester) async {
  final toggle = find.byKey(
    const ValueKey('live-operations-toggle-detailed-workspace'),
  );
  if (toggle.evaluate().isEmpty) {
    return;
  }
  final button = tester.widget<OutlinedButton>(toggle);
  button.onPressed?.call();
  await tester.pumpAndSettle();
}

DateTime _liveOperationsControlInboxDraftCreatedAtUtc(int hour, int minute) =>
    DateTime.utc(2026, 3, 18, hour, minute);

DateTime _liveOperationsRecentActivityBaseUtc() =>
    _liveOperationsNowUtc().subtract(const Duration(hours: 3));

DateTime _liveOperationsRecentActivityOccurredAtUtc(int hour, int minute) =>
    _liveOperationsRecentActivityBaseUtc().add(
      Duration(hours: hour - 10, minutes: minute),
    );

DateTime _liveOperationsHeroScenarioNowUtc() => _liveOperationsNowUtc();

DateTime _liveOperationsNowUtc() => DateTime.now().toUtc();

DateTime _liveOperationsMorningReportGeneratedAtUtc(int day) =>
    DateTime.utc(2026, 3, day, 6, 0);

DateTime _liveOperationsNightShiftStartedAtUtc(int day) =>
    DateTime.utc(2026, 3, day, 22, 0);

class _FakeClientDraftService implements OnyxAgentClientDraftService {
  const _FakeClientDraftService();

  @override
  bool get isConfigured => true;

  @override
  Future<OnyxAgentClientDraftResult> draft({
    required String prompt,
    required String clientId,
    required String siteId,
    required String incidentReference,
  }) async {
    return OnyxAgentClientDraftResult(
      telegramDraft:
          'Telegram draft for $clientId / $siteId about $incidentReference',
      smsDraft: 'SMS draft based on: $prompt',
      providerLabel: 'local:test-client-draft',
    );
  }
}

const _promotedReplayConflictSignal = ScenarioReplayHistorySignal(
  scenarioId: 'parser_monitoring_review_action_specialist_conflict_v1',
  scope: ScenarioReplayHistorySignalScope.specialistConflict,
  trend: 'stabilizing',
  message: 'Specialist conflict remains unresolved.',
  count: 2,
  baseSeverity: 'low',
  effectiveSeverity: 'medium',
  policyMatchType: 'scope_severity_override',
  policyMatchValue: 'specialist_conflict:medium',
  policyMatchSource: 'scenario_set_category',
  latestSummary: 'CCTV holds review while Track pushes tactical track.',
  latestSpecialists: <String>['cctv', 'track'],
  latestTargets: <String>['cctvReview', 'tacticalTrack'],
);

const _sequenceFallbackReplaySignal = ScenarioReplayHistorySignal(
  scenarioId: 'parser_monitoring_priority_sequence_review_track_v1',
  scope: ScenarioReplayHistorySignalScope.sequenceFallback,
  trend: 'stabilizing',
  message: 'Replay sequence fallback remains active.',
  count: 2,
  baseSeverity: 'low',
  effectiveSeverity: 'low',
  latestSummary:
      'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
  latestTarget: 'tacticalTrack',
  latestBiasSource: 'replayPolicy',
  latestBiasScope: 'sequenceFallback',
  latestBiasSignature: 'replayPolicy:sequenceFallback',
  latestBiasPolicySourceLabel: 'scenario sequence policy',
  latestBranch: 'active',
);

const _promotedSequenceFallbackReplaySignal = ScenarioReplayHistorySignal(
  scenarioId: 'monitoring_priority_sequence_review_track_validation_v1',
  scope: ScenarioReplayHistorySignalScope.sequenceFallback,
  trend: 'worsening',
  message: 'Replay sequence fallback remains active under policy escalation.',
  count: 3,
  baseSeverity: 'high',
  effectiveSeverity: 'critical',
  policyMatchType: 'scope_severity_override',
  policyMatchValue: 'sequence_fallback:critical',
  policyMatchSource: 'scenario_set_scenario_id',
  latestSummary:
      'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
  latestTarget: 'tacticalTrack',
  latestBiasSource: 'replayPolicy',
  latestBiasScope: 'sequenceFallback',
  latestBiasSignature: 'replayPolicy:sequenceFallback',
  latestBiasPolicySourceLabel: 'scenario set/scenario policy',
  latestBranch: 'active',
);

const _stackedSequenceFallbackReplaySignal = ScenarioReplayHistorySignal(
  scenarioId: 'monitoring_priority_sequence_review_track_validation_v1',
  scope: ScenarioReplayHistorySignalScope.sequenceFallback,
  trend: 'stabilizing',
  message: 'Replay sequence fallback remains active.',
  count: 2,
  baseSeverity: 'low',
  effectiveSeverity: 'low',
  latestSummary:
      'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
  latestTarget: 'tacticalTrack',
  latestBiasSource: 'replayPolicy',
  latestBiasScope: 'sequenceFallback',
  latestBiasSignature: 'replayPolicy:sequenceFallback',
  latestBiasPolicySourceLabel: 'scenario sequence policy',
  latestBranch: 'active',
  latestReplayBiasStackSignature:
      'replayPolicy:sequenceFallback:tacticalTrack -> replayPolicy:specialistConflict:cctvReview',
  latestReplayBiasStackPosition: 0,
);

const _stackedReplayConflictSignal = ScenarioReplayHistorySignal(
  scenarioId: 'monitoring_priority_sequence_review_track_validation_v1',
  scope: ScenarioReplayHistorySignalScope.specialistConflict,
  trend: 'worsening',
  message: 'Specialist conflict opened for review.',
  count: 1,
  baseSeverity: 'low',
  effectiveSeverity: 'medium',
  latestSummary:
      'Replay history: specialist conflict still leans back to CCTV Review.',
  latestTarget: 'cctvReview',
  latestBiasSource: 'replayPolicy',
  latestBiasScope: 'specialistConflict',
  latestBiasSignature: 'replayPolicy:specialistConflict',
  latestReplayBiasStackSignature:
      'replayPolicy:sequenceFallback:tacticalTrack -> replayPolicy:specialistConflict:cctvReview',
  latestReplayBiasStackPosition: 1,
);

const _replayBiasStackDriftSignal = ScenarioReplayHistorySignal(
  scenarioId: 'monitoring_priority_sequence_review_track_validation_v1',
  scope: ScenarioReplayHistorySignalScope.replayBiasStackDrift,
  trend: 'worsening',
  message: 'Replay bias stack reordered after a cleaner run.',
  count: 1,
  baseSeverity: 'critical',
  effectiveSeverity: 'critical',
  latestSummary:
      'Replay bias stack changed. Previous pressure: Primary replay pressure: sequence fallback -> Tactical Track. Latest pressure: Primary replay pressure: sequence fallback -> Tactical Track. Secondary replay pressure: specialist conflict -> CCTV Review.',
  latestReplayBiasStackSignature:
      'replayPolicy:sequenceFallback:tacticalTrack -> replayPolicy:specialistConflict:cctvReview',
  previousReplayBiasStackSignature:
      'replayPolicy:sequenceFallback:tacticalTrack',
);

const _sequenceFallbackRecoverySignal = ScenarioReplayHistorySignal(
  scenarioId: 'parser_monitoring_priority_sequence_review_track_v1',
  scope: ScenarioReplayHistorySignalScope.sequenceFallback,
  trend: 'clean_again',
  message:
      'Dispatch Board is back in front after replay fallback cleared from Tactical Track.',
  count: 2,
  baseSeverity: 'info',
  effectiveSeverity: 'info',
  latestSummary:
      'Dispatch Board is back in front after replay fallback cleared from Tactical Track.',
  latestTarget: 'dispatchBoard',
  latestBiasSource: 'replayPolicy',
  latestBiasScope: 'sequenceFallback',
  latestBiasSignature: 'replayPolicy:sequenceFallback',
  latestBiasPolicySourceLabel: 'scenario sequence policy',
  latestBranch: 'clean',
  latestRestoredTarget: 'dispatchBoard',
);

class _FakeReplayHistorySignalService
    extends ScenarioReplayHistorySignalService {
  const _FakeReplayHistorySignalService(
    this.signal, {
    this.signalStack = const <ScenarioReplayHistorySignal>[],
  });

  final ScenarioReplayHistorySignal? signal;
  final List<ScenarioReplayHistorySignal> signalStack;

  @override
  Future<List<ScenarioReplayHistorySignal>> loadSignalStack({
    int limit = 3,
  }) async {
    final stack = signalStack.isNotEmpty
        ? signalStack
        : <ScenarioReplayHistorySignal>[?signal];
    return stack.take(limit).toList(growable: false);
  }
}

class _ThrowingReplayHistorySignalService
    extends ScenarioReplayHistorySignalService {
  const _ThrowingReplayHistorySignalService();

  @override
  Future<List<ScenarioReplayHistorySignal>> loadSignalStack({
    int limit = 3,
  }) async {
    throw StateError('replay history unavailable');
  }
}

void main() {
  testWidgets('live operations stays stable on phone viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: LiveOperationsPage(events: [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('INCIDENT QUEUE'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('live-operations-command-memory')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('live operations stays stable on landscape phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: LiveOperationsPage(events: [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('INCIDENT QUEUE'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('live-operations-command-memory')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('live operations renders multi-incident layout panels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LiveOperationsPage(events: [])),
    );

    expect(find.text('INCIDENT QUEUE'), findsOneWidget);
    expect(find.text('ACTION LADDER'), findsOneWidget);
    expect(find.text('INCIDENT CONTEXT'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('live-operations-command-memory')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('incident-card-INC-8829-QX')), findsOneWidget);
    expect(find.byKey(const Key('incident-card-INC-8830-RZ')), findsOneWidget);
  });

  testWidgets('live operations renders command overview cards', (tester) async {
    tester.view.physicalSize = const Size(2240, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: LiveOperationsPage(events: [])),
    );
    await tester.pumpAndSettle();
    await _openDetailedWorkspace(tester);

    expect(
      find.byKey(const ValueKey('live-operations-command-overview-rail')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('live-operations-command-card-active-incidents'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('live-operations-command-card-pending-actions'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('live-operations-command-card-active-lanes')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('live-operations-command-card-sites-under-watch'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('live operations renders command center hero', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LiveOperationsPage(events: [])),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('live-operations-command-center-hero')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('live-operations-command-queue')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('live-operations-command-current-focus')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('live-operations-command-quick-open')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('live-operations-command-memory')),
      findsOneWidget,
    );
  });

  testWidgets(
    'live operations routes a plain-language command into client comms',
    (tester) async {
      String? openedClientId;
      String? openedSiteId;
      String? stagedClientId;
      String? stagedSiteId;
      String? stagedDraftText;
      String? stagedIncidentReference;

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const [],
            initialScopeClientId: 'CLIENT-MS-VALLEE',
            initialScopeSiteId: 'SITE-MS-VALLEE-RESIDENCE',
            clientDraftService: const _FakeClientDraftService(),
            clientCommsSnapshot: LiveClientCommsSnapshot(
              clientId: 'CLIENT-MS-VALLEE',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              clientVoiceProfileLabel: 'Calm',
              learnedApprovalStyleCount: 0,
              learnedApprovalStyleExample: '',
              pendingLearnedStyleDraftCount: 0,
              totalMessages: 2,
              clientInboundCount: 1,
              pendingApprovalCount: 0,
              queuedPushCount: 0,
              telegramHealthLabel: 'ok',
              telegramHealthDetail: 'Telegram is healthy.',
              pushSyncStatusLabel: 'live',
              smsFallbackLabel: 'SMS standby',
              smsFallbackReady: true,
              voiceReadinessLabel: 'VoIP staged',
              deliveryReadinessDetail:
                  'Primary delivery stays inside Client Comms.',
              latestClientMessage: 'Any update from the site?',
              latestPendingDraft:
                  'Control is checking now and will share the next confirmed move.',
            ),
            onOpenClientViewForScope: (clientId, siteId) {
              openedClientId = clientId;
              openedSiteId = siteId;
            },
            onStageClientDraftForScope:
                ({
                  required clientId,
                  required siteId,
                  required draftText,
                  required originalDraftText,
                  room = 'Residents',
                  incidentReference = '',
                }) {
                  stagedClientId = clientId;
                  stagedSiteId = siteId;
                  stagedDraftText = draftText;
                  stagedIncidentReference = incidentReference;
                },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('live-operations-command-input')),
        'Draft a client update for this site',
      );
      await tester.tap(
        find.byKey(const ValueKey('live-operations-command-submit')),
      );
      await tester.pumpAndSettle();

      expect(openedClientId, 'CLIENT-MS-VALLEE');
      expect(openedSiteId, 'SITE-MS-VALLEE-RESIDENCE');
      expect(
        find.byKey(const ValueKey('live-operations-command-intent-preview')),
        findsOneWidget,
      );
      expect(stagedClientId, 'CLIENT-MS-VALLEE');
      expect(stagedSiteId, 'SITE-MS-VALLEE-RESIDENCE');
      expect(
        stagedDraftText,
        contains(
          'Telegram draft for CLIENT-MS-VALLEE / SITE-MS-VALLEE-RESIDENCE',
        ),
      );
      expect(stagedIncidentReference, isEmpty);
      expect(find.text('CLIENT DRAFT READY'), findsOneWidget);
      expect(
        find.text('Scoped client update is waiting in Client Comms.'),
        findsOneWidget,
      );
      expect(find.textContaining('Last command:'), findsOneWidget);
    },
  );

  testWidgets('live operations answers a guard status command in place', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LiveOperationsPage(events: [])),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('live-operations-command-input')),
      'Check status of Echo-3',
    );
    await tester.tap(
      find.byKey(const ValueKey('live-operations-command-submit')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('live-operations-command-intent-preview')),
      findsOneWidget,
    );
    final commandPreview = find.byKey(
      const ValueKey('live-operations-command-intent-preview'),
    );
    expect(
      find.descendant(of: commandPreview, matching: find.text('GUARD STATUS')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: commandPreview,
        matching: find.text('Last check-in 22:12. Vigilance decay 67%.'),
      ),
      findsOneWidget,
    );
    expect(find.text('Echo-3 is still active in Command.'), findsWidgets);
    expect(find.textContaining('Last command:'), findsOneWidget);
  });

  testWidgets('live operations answers a patrol report command in place', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          initialScopeClientId: 'CLIENT-MS-VALLEE',
          initialScopeSiteId: 'SITE-MS-VALLEE-RESIDENCE',
          events: [
            PatrolCompleted(
              eventId: 'patrol-1',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 18)),
              guardId: 'Guard001',
              routeId: 'NORTH-PERIMETER',
              clientId: 'CLIENT-MS-VALLEE',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              durationSeconds: 17 * 60,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('live-operations-command-input')),
      'Show last patrol report for Guard001',
    );
    await tester.tap(
      find.byKey(const ValueKey('live-operations-command-submit')),
    );
    await tester.pumpAndSettle();

    final commandPreview = find.byKey(
      const ValueKey('live-operations-command-intent-preview'),
    );
    expect(commandPreview, findsOneWidget);
    expect(
      find.descendant(of: commandPreview, matching: find.text('PATROL REPORT')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: commandPreview,
        matching: find.textContaining('North Perimeter'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: commandPreview,
        matching: find.textContaining('Duration 17 min.'),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Guard001 completed the last patrol at'),
      findsWidgets,
    );
  });

  testWidgets('live operations answers when no active incident is pinned', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LiveOperationsPage(
          events: [],
          initialScopeClientId: 'CLIENT-EMPTY',
          initialScopeSiteId: 'SITE-EMPTY',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('live-operations-command-input')),
      'Summarize the active incident',
    );
    await tester.tap(
      find.byKey(const ValueKey('live-operations-command-submit')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('live-operations-command-intent-preview')),
      findsOneWidget,
    );
    final commandPreview = find.byKey(
      const ValueKey('live-operations-command-intent-preview'),
    );
    expect(
      find.descendant(
        of: commandPreview,
        matching: find.text('INCIDENT SUMMARY'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: commandPreview,
        matching: find.text(
          'Select or seed one incident first so ONYX can summarize the current signal cleanly.',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('No active incident is pinned yet'), findsWidgets);
  });

  testWidgets('live operations lists unresolved incidents in place', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LiveOperationsPage(events: [])),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('live-operations-command-input')),
      'Show unresolved incidents',
    );
    await tester.tap(
      find.byKey(const ValueKey('live-operations-command-submit')),
    );
    await tester.pumpAndSettle();

    final commandPreview = find.byKey(
      const ValueKey('live-operations-command-intent-preview'),
    );
    expect(commandPreview, findsOneWidget);
    expect(
      find.descendant(
        of: commandPreview,
        matching: find.text('UNRESOLVED INCIDENTS'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: commandPreview,
        matching: find.text(
          'INC-8829-QX • INVESTIGATING • North Residential Cluster  |  INC-8830-RZ • DISPATCHED • Central Access Gate  |  INC-8827-PX • TRIAGING • East Patrol Sector',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.text('4 unresolved incidents are live in Command.'),
      findsWidgets,
    );
  });

  testWidgets(
    'live operations ranks sites by alert volume this week in place',
    (tester) async {
      final localNow = DateTime.now().toLocal();
      final weekStart = DateTime(
        localNow.year,
        localNow.month,
        localNow.day,
      ).subtract(Duration(days: localNow.weekday - DateTime.monday));
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            initialScopeClientId: 'CLIENT-001',
            initialScopeSiteId: 'SITE-SANDTON',
            events: [
              IntelligenceReceived(
                eventId: 'intel-this-week-1',
                sequence: 1,
                version: 1,
                occurredAt: weekStart.add(const Duration(hours: 1)).toUtc(),
                intelligenceId: 'INT-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-1',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SANDTON',
                headline: 'North perimeter alert',
                summary: 'Vehicle paused near the perimeter.',
                riskScore: 61,
                canonicalHash: 'hash-1',
              ),
              IntelligenceReceived(
                eventId: 'intel-this-week-2',
                sequence: 2,
                version: 1,
                occurredAt: weekStart
                    .add(const Duration(days: 1, hours: 3))
                    .toUtc(),
                intelligenceId: 'INT-2',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-2',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SANDTON',
                headline: 'Boundary motion alert',
                summary: 'Motion detected on the east boundary.',
                riskScore: 58,
                canonicalHash: 'hash-2',
              ),
              IntelligenceReceived(
                eventId: 'intel-this-week-3',
                sequence: 3,
                version: 1,
                occurredAt: weekStart
                    .add(const Duration(days: 2, hours: 2))
                    .toUtc(),
                intelligenceId: 'INT-3',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-3',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-VALLEE',
                headline: 'Gate alert',
                summary: 'Unexpected person detected at the gate.',
                riskScore: 72,
                canonicalHash: 'hash-3',
              ),
              IntelligenceReceived(
                eventId: 'intel-old',
                sequence: 4,
                version: 1,
                occurredAt: weekStart
                    .subtract(const Duration(hours: 4))
                    .toUtc(),
                intelligenceId: 'INT-OLD',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-old',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-OLD',
                headline: 'Old alert',
                summary: 'Older alert outside the weekly window.',
                riskScore: 40,
                canonicalHash: 'hash-old',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('live-operations-command-input')),
        'Which site has most alerts this week',
      );
      await tester.tap(
        find.byKey(const ValueKey('live-operations-command-submit')),
      );
      await tester.pumpAndSettle();

      final commandPreview = find.byKey(
        const ValueKey('live-operations-command-intent-preview'),
      );
      expect(commandPreview, findsOneWidget);
      expect(
        find.descendant(
          of: commandPreview,
          matching: find.text('THIS WEEK\'S ALERT LEADER'),
        ),
        findsOneWidget,
      );
      expect(find.text('Sandton leads this week with 2 alerts.'), findsWidgets);
      expect(
        find.descendant(
          of: commandPreview,
          matching: find.textContaining('Sandton • 2 alerts'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: commandPreview,
          matching: find.textContaining('Vallee • 1 alert'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: commandPreview,
          matching: find.textContaining('Old'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('live operations lists today dispatches in place', (
    tester,
  ) async {
    final localNow = DateTime.now().toLocal();
    final now = DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
      12,
    ).toUtc();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: [
            DecisionCreated(
              eventId: 'decision-today-1',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 12)),
              dispatchId: 'DSP-TODAY-1',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            DecisionCreated(
              eventId: 'decision-yesterday',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(days: 1, hours: 2)),
              dispatchId: 'DSP-YESTERDAY',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-OLD',
            ),
            DecisionCreated(
              eventId: 'decision-today-2',
              sequence: 3,
              version: 1,
              occurredAt: now.subtract(const Duration(hours: 2)),
              dispatchId: 'DSP-TODAY-2',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-VALLEE',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('live-operations-command-input')),
      'Show dispatches today',
    );
    await tester.tap(
      find.byKey(const ValueKey('live-operations-command-submit')),
    );
    await tester.pumpAndSettle();

    final commandPreview = find.byKey(
      const ValueKey('live-operations-command-intent-preview'),
    );
    expect(commandPreview, findsOneWidget);
    expect(
      find.descendant(
        of: commandPreview,
        matching: find.text('TODAY\'S DISPATCHES'),
      ),
      findsOneWidget,
    );
    expect(find.text('2 dispatches were created today.'), findsWidgets);
    expect(
      find.descendant(
        of: commandPreview,
        matching: find.textContaining('DSP-TODAY-1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: commandPreview,
        matching: find.textContaining('DSP-TODAY-2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: commandPreview,
        matching: find.textContaining('DSP-YESTERDAY'),
      ),
      findsNothing,
    );
  });

  testWidgets('live operations lists incidents from last night in place', (
    tester,
  ) async {
    final localNow = DateTime.now().toLocal();
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

    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: [
            DecisionCreated(
              eventId: 'decision-last-night-1',
              sequence: 1,
              version: 1,
              occurredAt: overnightStart.add(const Duration(hours: 1)).toUtc(),
              dispatchId: 'DSP-NIGHT-1',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            DecisionCreated(
              eventId: 'decision-too-early',
              sequence: 2,
              version: 1,
              occurredAt: overnightStart
                  .subtract(const Duration(hours: 2))
                  .toUtc(),
              dispatchId: 'DSP-OLD',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-OLD',
            ),
            DecisionCreated(
              eventId: 'decision-last-night-2',
              sequence: 3,
              version: 1,
              occurredAt: overnightStart
                  .add(const Duration(hours: 5, minutes: 30))
                  .toUtc(),
              dispatchId: 'DSP-NIGHT-2',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-VALLEE',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('live-operations-command-input')),
      'Show incidents last night',
    );
    await tester.tap(
      find.byKey(const ValueKey('live-operations-command-submit')),
    );
    await tester.pumpAndSettle();

    final commandPreview = find.byKey(
      const ValueKey('live-operations-command-intent-preview'),
    );
    expect(commandPreview, findsOneWidget);
    expect(
      find.descendant(
        of: commandPreview,
        matching: find.text('LAST NIGHT\'S INCIDENTS'),
      ),
      findsOneWidget,
    );
    expect(find.text('2 incidents landed last night.'), findsWidgets);
    expect(
      find.descendant(
        of: commandPreview,
        matching: find.textContaining('INC-DSP-NIGHT-1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: commandPreview,
        matching: find.textContaining('INC-DSP-NIGHT-2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: commandPreview,
        matching: find.textContaining('INC-DSP-OLD'),
      ),
      findsNothing,
    );
  });

  testWidgets('live operations shows guard roster signal in the war room', (
    tester,
  ) async {
    var plannerOpened = false;
    var auditOpened = false;
    String? recordedAuditAction;
    String? recordedAuditDetail;
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: [],
          onOpenRosterPlanner: () {
            plannerOpened = true;
          },
          onOpenRosterAudit: () {
            auditOpened = true;
          },
          onAutoAuditAction: (action, detail) {
            recordedAuditAction = action;
            recordedAuditDetail = detail;
          },
          guardRosterSignalLabel: 'ROSTER WATCH',
          guardRosterSignalHeadline:
              'Fill two open posts before night handoff.',
          guardRosterSignalDetail:
              'Month planner has gaps at Sandton and Midrand.',
          guardRosterSignalAccent: Color(0xFFF59E0B),
          guardRosterSignalNeedsAttention: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('live-operations-roster-signal-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('live-operations-command-item-roster-signal')),
      findsOneWidget,
    );
    expect(find.text('ROSTER WATCH'), findsOneWidget);
    expect(find.text('ACT NOW'), findsOneWidget);
    expect(
      find.text('Fill two open posts before night handoff.'),
      findsAtLeastNWidgets(2),
    );
    expect(find.text('OPEN MONTH PLANNER'), findsOneWidget);
    final openPlannerAction = find.byKey(
      const ValueKey('live-operations-command-action-roster-open-planner'),
    );
    await tester.ensureVisible(openPlannerAction);
    await tester.tap(openPlannerAction);
    await tester.pumpAndSettle();
    expect(plannerOpened, isTrue);
    expect(recordedAuditAction, 'roster_planner_opened');
    expect(
      recordedAuditDetail,
      'Opened the month planner from the live operations war room to close a live coverage gap.',
    );
    expect(find.text('Month planner warmed from war room.'), findsOneWidget);
    expect(find.text('OPEN SIGNED AUDIT'), findsWidgets);
    await tester.tap(
      find.byKey(
        const ValueKey('live-operations-command-action-roster-view-audit'),
      ),
    );
    await tester.pumpAndSettle();
    expect(auditOpened, isTrue);
    expect(
      find.text('Signed roster audit opened from war room.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'live operations command hero can hand off the active incident to agent',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 980);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = _liveOperationsHeroScenarioNowUtc();
      String? openedIncidentReference;
      String? recordedAuditAction;
      String? recordedAuditDetail;

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            focusIncidentReference: 'INC-DSP-HERO',
            onOpenAgentForIncident: (incidentReference) {
              openedIncidentReference = incidentReference;
            },
            onAutoAuditAction: (action, detail) {
              recordedAuditAction = action;
              recordedAuditDetail = detail;
            },
            events: [
              DecisionCreated(
                eventId: 'decision-dsp-hero',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                dispatchId: 'DSP-HERO',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-HERO',
              ),
              IntelligenceReceived(
                eventId: 'intel-dsp-hero',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INTEL-DSP-HERO',
                sourceType: 'hardware',
                provider: 'dahua',
                externalId: 'evt-dsp-hero',
                riskScore: 74,
                headline: 'Perimeter breach',
                summary: 'Live motion alert pushed into the command hero.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-HERO',
                canonicalHash: 'canon-dsp-hero',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DO THIS FIRST'), findsOneWidget);

      final askAgentButton = find.byKey(
        const ValueKey('live-operations-command-open-agent'),
      );
      await tester.ensureVisible(askAgentButton);
      await tester.tap(askAgentButton);
      await tester.pumpAndSettle();

      expect(openedIncidentReference, 'INC-DSP-HERO');
      expect(recordedAuditAction, 'agent_handoff_opened');
      expect(
        recordedAuditDetail,
        'Opened AI Copilot from the live operations war room for INC-DSP-HERO.',
      );
    },
  );

  testWidgets('live operations ingests agent returns into the focused board', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 980);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = _liveOperationsHeroScenarioNowUtc();
    String? consumedIncidentReference;

    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          focusIncidentReference: 'INC-DSP-HERO',
          agentReturnIncidentReference: 'INC-DSP-HERO',
          onConsumeAgentReturnIncidentReference: (incidentReference) {
            consumedIncidentReference = incidentReference;
          },
          events: [
            DecisionCreated(
              eventId: 'decision-dsp-hero',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              dispatchId: 'DSP-HERO',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-HERO',
            ),
            IntelligenceReceived(
              eventId: 'intel-dsp-hero',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 1)),
              intelligenceId: 'INTEL-DSP-HERO',
              sourceType: 'hardware',
              provider: 'dahua',
              externalId: 'evt-dsp-hero',
              riskScore: 74,
              headline: 'Perimeter breach',
              summary: 'Live motion alert pushed into the command hero.',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-HERO',
              canonicalHash: 'canon-dsp-hero',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openDetailedWorkspace(tester);

    expect(
      find.byKey(const ValueKey('live-operations-command-receipt')),
      findsOneWidget,
    );
    expect(find.text('AGENT RETURN'), findsOneWidget);
    expect(find.text('Returned from Agent for INC-DSP-HERO.'), findsOneWidget);
    expect(consumedIncidentReference, 'INC-DSP-HERO');
  });

  testWidgets('live operations surfaces latest auto-audit receipt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2240, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var openedLatestAudit = false;

    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: const [],
          onOpenLatestAudit: () {
            openedLatestAudit = true;
          },
          latestAutoAuditReceipt: const LiveOpsAutoAuditReceipt(
            auditId: 'ops-audit-1',
            label: 'AUTO-AUDIT',
            headline: 'War-room action signed automatically.',
            detail:
                'Opened the month planner from the live operations war room • hash 2d7f4c91ab',
            accent: Color(0xFF63E6A1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openDetailedWorkspace(tester);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('live-operations-command-receipt')),
      findsOneWidget,
    );
    expect(find.text('AUTO-AUDIT'), findsOneWidget);
    expect(find.text('War-room action signed automatically.'), findsOneWidget);
    expect(find.textContaining('hash 2d7f4c91ab'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('live-operations-command-view-latest-audit')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('live-operations-command-view-latest-audit')),
    );
    await tester.tap(
      find.byKey(const ValueKey('live-operations-command-view-latest-audit')),
    );
    await tester.pumpAndSettle();

    expect(openedLatestAudit, isTrue);
  });

  testWidgets(
    'live operations attention queue incident opens alarms route before legacy recovery',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? openedIncidentId;
      String? recordedAuditAction;
      String? recordedAuditDetail;
      final now = _liveOperationsRecentActivityOccurredAtUtc(10, 10);

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            focusIncidentReference: 'INC-DSP-4',
            events: [
              DecisionCreated(
                eventId: 'decision-dsp-4',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 4)),
                dispatchId: 'DSP-4',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
              IntelligenceReceived(
                eventId: 'intel-dsp-4',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 3)),
                intelligenceId: 'INTEL-DSP-4',
                sourceType: 'hardware',
                provider: 'dahua',
                externalId: 'evt-dsp-4',
                riskScore: 78,
                headline: 'Perimeter motion',
                summary: 'Moderate perimeter motion detected.',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
                canonicalHash: 'canon-dsp-4',
              ),
            ],
            onOpenAlarmsForIncident: (incidentReference) {
              openedIncidentId = incidentReference;
            },
            onAutoAuditAction: (action, detail) {
              recordedAuditAction = action;
              recordedAuditDetail = detail;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final incidentActivity = find.byKey(
        const ValueKey('live-operations-command-item-incident-INC-DSP-4'),
      );
      await tester.ensureVisible(incidentActivity);
      await tester.tap(incidentActivity);
      await tester.pumpAndSettle();

      expect(openedIncidentId, 'INC-DSP-4');
      expect(recordedAuditAction, 'dispatch_handoff_opened');
      expect(
        recordedAuditDetail,
        'Opened dispatch board from the live operations war room for INC-DSP-4.',
      );
    },
  );

  testWidgets(
    'live operations attention queue opens scoped client comms route before legacy recovery',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? openedClientId;
      String? openedSiteId;
      String? recordedAuditAction;
      String? recordedAuditDetail;

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const [],
            clientCommsSnapshot: const LiveClientCommsSnapshot(
              clientId: 'CLIENT-MS-VALLEE',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
            ),
            controlInboxSnapshot: LiveControlInboxSnapshot(
              selectedClientId: 'CLIENT-MS-VALLEE',
              selectedSiteId: 'SITE-MS-VALLEE-RESIDENCE',
              liveClientAsks: [
                LiveControlInboxClientAsk(
                  clientId: 'CLIENT-MS-VALLEE',
                  siteId: 'SITE-MS-VALLEE-RESIDENCE',
                  author: 'Client',
                  body: 'Any update from the gate?',
                  messageProvider: 'telegram',
                  occurredAtUtc: _liveOperationsRecentActivityOccurredAtUtc(
                    12,
                    0,
                  ),
                ),
              ],
            ),
            onOpenClientViewForScope: (clientId, siteId) {
              openedClientId = clientId;
              openedSiteId = siteId;
            },
            onAutoAuditAction: (action, detail) {
              recordedAuditAction = action;
              recordedAuditDetail = detail;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final activityRow = find.byKey(
        const ValueKey(
          'live-operations-command-item-comms-SITE-MS-VALLEE-RESIDENCE',
        ),
      );
      await tester.ensureVisible(activityRow);
      await tester.tap(activityRow);
      await tester.pumpAndSettle();

      expect(openedClientId, 'CLIENT-MS-VALLEE');
      expect(openedSiteId, 'SITE-MS-VALLEE-RESIDENCE');
      expect(recordedAuditAction, 'client_handoff_opened');
      expect(
        recordedAuditDetail,
        'Opened Client Comms from the live operations war room for Ms Vallee Residence.',
      );
    },
  );

  testWidgets(
    'live operations review action emits CCTV auto-audit and opens scoped CCTV route',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? openedIncidentId;
      String? recordedAuditAction;
      String? recordedAuditDetail;
      final now = _liveOperationsHeroScenarioNowUtc();

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            focusIncidentReference: 'INC-DSP-VISUAL',
            onOpenCctvForIncident: (incidentReference) {
              openedIncidentId = incidentReference;
            },
            onAutoAuditAction: (action, detail) {
              recordedAuditAction = action;
              recordedAuditDetail = detail;
            },
            sceneReviewByIntelligenceId: {
              'INTEL-DSP-VISUAL': MonitoringSceneReviewRecord(
                intelligenceId: 'INTEL-DSP-VISUAL',
                evidenceRecordHash: 'evidence-visual-1',
                sourceLabel: 'openai:gpt-5.4-mini',
                postureLabel: 'visual review',
                decisionLabel: 'Visual Review',
                decisionSummary:
                    'Camera review should be opened before the incident is dismissed.',
                summary: 'Shadow movement is visible near the perimeter line.',
                reviewedAtUtc: now.subtract(const Duration(seconds: 30)),
              ),
            },
            events: [
              DecisionCreated(
                eventId: 'decision-dsp-visual',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                dispatchId: 'DSP-VISUAL',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-VISUAL',
              ),
              IntelligenceReceived(
                eventId: 'intel-dsp-visual',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INTEL-DSP-VISUAL',
                sourceType: 'hardware',
                provider: 'dahua',
                externalId: 'evt-dsp-visual',
                riskScore: 76,
                headline: 'Visual anomaly',
                summary: 'Thermal and CCTV review recommended.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-VISUAL',
                canonicalHash: 'canon-dsp-visual',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final reviewButton = find.byKey(
        const ValueKey('live-operations-command-action-review-INC-DSP-VISUAL'),
      );
      await tester.ensureVisible(reviewButton);
      await tester.tap(reviewButton);
      await tester.pumpAndSettle();

      expect(openedIncidentId, 'INC-DSP-VISUAL');
      expect(recordedAuditAction, 'cctv_handoff_opened');
      expect(
        recordedAuditDetail,
        'Opened CCTV review from the live operations war room for INC-DSP-VISUAL.',
      );
    },
  );

  testWidgets(
    'live operations track action emits tactical auto-audit and opens scoped track route',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? openedIncidentId;
      String? recordedAuditAction;
      String? recordedAuditDetail;
      final now = _liveOperationsHeroScenarioNowUtc();

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            focusIncidentReference: 'INC-DSP-TRACK',
            onOpenTrackForIncident: (incidentReference) {
              openedIncidentId = incidentReference;
            },
            onAutoAuditAction: (action, detail) {
              recordedAuditAction = action;
              recordedAuditDetail = detail;
            },
            events: [
              DecisionCreated(
                eventId: 'decision-dsp-track',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                dispatchId: 'DSP-TRACK',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-TRACK',
              ),
              IntelligenceReceived(
                eventId: 'intel-dsp-track',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INTEL-DSP-TRACK',
                sourceType: 'hardware',
                provider: 'dahua',
                externalId: 'evt-dsp-track',
                riskScore: 94,
                headline: 'Responder moving',
                summary: 'Track the field movement through Tactical.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-TRACK',
                canonicalHash: 'canon-dsp-track',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final trackButton = find.byKey(
        const ValueKey('live-operations-command-action-track-INC-DSP-TRACK'),
      );
      await tester.ensureVisible(trackButton);
      await tester.tap(trackButton);
      await tester.pumpAndSettle();

      expect(openedIncidentId, 'INC-DSP-TRACK');
      expect(recordedAuditAction, 'track_handoff_opened');
      expect(
        recordedAuditDetail,
        'Opened tactical track from the live operations war room for INC-DSP-TRACK.',
      );
    },
  );

  testWidgets(
    'live operations attention queue opens scoped client comms from pending draft approval',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? openedClientId;
      String? openedSiteId;

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const [],
            controlInboxSnapshot: LiveControlInboxSnapshot(
              selectedClientId: 'CLIENT-MS-VALLEE',
              selectedSiteId: 'SITE-MS-VALLEE-RESIDENCE',
              pendingDrafts: [
                LiveControlInboxDraft(
                  updateId: 501,
                  clientId: 'CLIENT-MS-VALLEE',
                  siteId: 'SITE-MS-VALLEE-RESIDENCE',
                  sourceText:
                      'Please confirm if the response team has already arrived.',
                  draftText:
                      'Command is confirming arrival now and will share the verified position as soon as it is locked.',
                  providerLabel: 'OpenAI',
                  createdAtUtc: _liveOperationsRecentActivityOccurredAtUtc(
                    12,
                    4,
                  ),
                ),
              ],
            ),
            onOpenClientViewForScope: (clientId, siteId) {
              openedClientId = clientId;
              openedSiteId = siteId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final activityRow = find.byKey(
        const ValueKey(
          'live-operations-command-item-comms-SITE-MS-VALLEE-RESIDENCE',
        ),
      );
      await tester.ensureVisible(activityRow);
      await tester.tap(activityRow);
      await tester.pumpAndSettle();

      expect(openedClientId, 'CLIENT-MS-VALLEE');
      expect(openedSiteId, 'SITE-MS-VALLEE-RESIDENCE');
    },
  );

  testWidgets(
    'live operations attention queue opens scoped client comms from latest lane activity fallback',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? openedClientId;
      String? openedSiteId;

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const [],
            clientCommsSnapshot: LiveClientCommsSnapshot(
              clientId: 'CLIENT-MS-VALLEE',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              latestClientMessage: 'Any update from the gate?',
              latestClientMessageAtUtc:
                  _liveOperationsRecentActivityOccurredAtUtc(12, 6),
            ),
            onOpenClientViewForScope: (clientId, siteId) {
              openedClientId = clientId;
              openedSiteId = siteId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final activityRow = find.byKey(
        const ValueKey(
          'live-operations-command-item-comms-SITE-MS-VALLEE-RESIDENCE',
        ),
      );
      await tester.ensureVisible(activityRow);
      await tester.tap(activityRow);
      await tester.pumpAndSettle();

      expect(openedClientId, 'CLIENT-MS-VALLEE');
      expect(openedSiteId, 'SITE-MS-VALLEE-RESIDENCE');
    },
  );

  testWidgets(
    'live operations command client comms card opens simple client route before legacy recovery',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var openedClientView = false;

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const [],
            onOpenClientView: () {
              openedClientView = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final clientCommsCard = find.byKey(
        const ValueKey('live-operations-quick-open-client-comms'),
      );
      await tester.ensureVisible(clientCommsCard);
      await tester.tap(clientCommsCard);
      await tester.pumpAndSettle();

      expect(openedClientView, isTrue);
    },
  );

  testWidgets(
    'live operations keeps the detailed workspace hidden on standard desktop',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 980);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(home: LiveOperationsPage(events: [])),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('live-operations-command-center-hero')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('live-operations-toggle-detailed-workspace')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('live-operations-workspace-panel-rail')),
        findsNothing,
      );
      expect(find.text('INCIDENT QUEUE'), findsNothing);
    },
  );

  testWidgets('live operations command overview cards pivot workspace state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2240, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = _liveOperationsNowUtc();
    String? openedClientId;
    String? openedSiteId;
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          focusIncidentReference: 'INC-DSP-LOW',
          clientCommsSnapshot: const LiveClientCommsSnapshot(
            clientId: 'CLIENT-001',
            siteId: 'SITE-CRIT',
          ),
          onOpenClientViewForScope: (clientId, siteId) {
            openedClientId = clientId;
            openedSiteId = siteId;
          },
          events: [
            DecisionCreated(
              eventId: 'decision-low-overview',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 4)),
              dispatchId: 'DSP-LOW',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-LOW',
            ),
            IntelligenceReceived(
              eventId: 'intel-low-overview',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 3)),
              intelligenceId: 'INTEL-LOW',
              sourceType: 'hardware',
              provider: 'dahua',
              externalId: 'evt-low-overview',
              riskScore: 72,
              headline: 'Perimeter motion',
              summary: 'Moderate perimeter motion detected.',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-LOW',
              faceConfidence: 0.82,
              canonicalHash: 'canon-low-overview',
            ),
            DecisionCreated(
              eventId: 'decision-critical-overview',
              sequence: 3,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              dispatchId: 'DSP-CRIT',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-CRIT',
            ),
            IntelligenceReceived(
              eventId: 'intel-critical-overview',
              sequence: 4,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 1)),
              intelligenceId: 'INTEL-CRIT',
              sourceType: 'hardware',
              provider: 'dahua',
              externalId: 'evt-crit-overview',
              riskScore: 92,
              headline: 'Fire alarm escalation',
              summary: 'Critical hazard posture detected.',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-CRIT',
              faceConfidence: 0.97,
              canonicalHash: 'canon-crit-overview',
              snapshotUrl: 'https://edge.example.com/crit.jpg',
              clipUrl: 'https://edge.example.com/crit.mp4',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openDetailedWorkspace(tester);

    expect(find.text('Active Incident: INC-DSP-LOW'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey('live-operations-command-card-active-incidents'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Active Incident: INC-DSP-CRIT'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('live-operations-command-card-active-lanes')),
    );
    await tester.pumpAndSettle();
    expect(openedClientId, 'CLIENT-001');
    expect(openedSiteId, 'SITE-CRIT');
  });

  testWidgets(
    'live operations command overview recovers missing queue and lane handoffs in place',
    (tester) async {
      tester.view.physicalSize = const Size(2240, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = _liveOperationsNowUtc();
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            focusIncidentReference: 'INC-DSP-LOW',
            clientCommsSnapshot: const LiveClientCommsSnapshot(
              clientId: 'CLIENT-001',
              siteId: 'SITE-CRIT',
            ),
            events: [
              DecisionCreated(
                eventId: 'decision-low-recovery',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 4)),
                dispatchId: 'DSP-LOW',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-LOW',
              ),
              IntelligenceReceived(
                eventId: 'intel-low-recovery',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 3)),
                intelligenceId: 'INTEL-LOW',
                sourceType: 'hardware',
                provider: 'dahua',
                externalId: 'evt-low-recovery',
                riskScore: 72,
                headline: 'Perimeter motion',
                summary: 'Moderate perimeter motion detected.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-LOW',
                faceConfidence: 0.82,
                canonicalHash: 'canon-low-recovery',
              ),
              DecisionCreated(
                eventId: 'decision-critical-recovery',
                sequence: 3,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                dispatchId: 'DSP-CRIT',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-CRIT',
              ),
              IntelligenceReceived(
                eventId: 'intel-critical-recovery',
                sequence: 4,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INTEL-CRIT',
                sourceType: 'hardware',
                provider: 'dahua',
                externalId: 'evt-crit-recovery',
                riskScore: 92,
                headline: 'Fire alarm escalation',
                summary: 'Critical hazard posture detected.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-CRIT',
                faceConfidence: 0.97,
                canonicalHash: 'canon-crit-recovery',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openDetailedWorkspace(tester);

      expect(find.text('Inbox offline'), findsOneWidget);
      expect(find.text('Active Incident: INC-DSP-LOW'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey('live-operations-command-card-pending-actions'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active Incident: INC-DSP-CRIT'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('live-operations-command-receipt')),
        findsOneWidget,
      );
      expect(find.text('Pending actions recovery opened.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('live-operations-command-card-active-lanes')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('VoIP Call Active - Recording in progress'),
        findsOneWidget,
      );
      expect(
        find.text('Client Comms fallback opened in place.'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'live operations command current focus uses typed triage for distress incidents',
    (tester) async {
      tester.view.physicalSize = const Size(2240, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = _liveOperationsNowUtc();
      String? openedTrackIncident;
      String? recordedAuditAction;
      String? recordedAuditDetail;

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: [
              DecisionCreated(
                eventId: 'decision-dsp-duress',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                dispatchId: 'DSP-DURESS',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-HERO',
              ),
              IntelligenceReceived(
                eventId: 'intel-dsp-duress',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INTEL-DSP-DURESS',
                sourceType: 'wearable',
                provider: 'onyx',
                externalId: 'evt-dsp-duress',
                riskScore: 89,
                headline: 'Guard distress telemetry',
                summary:
                    'Heart rate spike plus no movement detected for Guard001.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-HERO',
                canonicalHash: 'canon-dsp-duress',
              ),
            ],
            onOpenTrackForIncident: (incidentReference) {
              openedTrackIncident = incidentReference;
            },
            onAutoAuditAction: (action, detail) {
              recordedAuditAction = action;
              recordedAuditDetail = detail;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OPEN TACTICAL TRACK'), findsOneWidget);
      expect(
        find.textContaining('Command brain: deterministic hold'),
        findsOneWidget,
      );

      final openBoardButton = find.byKey(
        const ValueKey('live-operations-command-open-board'),
      );
      await tester.ensureVisible(openBoardButton);
      await tester.tap(openBoardButton);
      await tester.pumpAndSettle();

      expect(openedTrackIncident, 'INC-DSP-DURESS');
      expect(recordedAuditAction, 'track_handoff_opened');
      expect(
        recordedAuditDetail,
        'Opened tactical track from the live operations war room for INC-DSP-DURESS.',
      );
      expect(find.text('Tactical Track handoff sealed.'), findsOneWidget);
    },
  );

  testWidgets(
    'live operations command current focus surfaces replay specialist risk',
    (tester) async {
      tester.view.physicalSize = const Size(2240, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = _liveOperationsNowUtc();

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: [
              DecisionCreated(
                eventId: 'decision-dsp-replay',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                dispatchId: 'DSP-REPLAY',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-HERO',
              ),
              IntelligenceReceived(
                eventId: 'intel-dsp-replay',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INTEL-DSP-REPLAY',
                sourceType: 'wearable',
                provider: 'onyx',
                externalId: 'evt-dsp-replay',
                riskScore: 89,
                headline: 'Guard distress telemetry',
                summary:
                    'Heart rate spike plus no movement detected for Guard001.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-HERO',
                canonicalHash: 'canon-dsp-replay',
              ),
            ],
            scenarioReplayHistorySignalService:
                const _FakeReplayHistorySignalService(
                  _promotedReplayConflictSignal,
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('live-operations-command-replay-history')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Replay history: specialist conflict promoted low -> medium via scenario set/category policy.',
        ),
        findsWidgets,
      );
      expect(
        find.textContaining(
          'Replay policy bias: Replay history: specialist conflict promoted low -> medium',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'CCTV holds review while Track pushes tactical track.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'live operations command current focus lets replay conflict bias the recovery desk',
    (tester) async {
      tester.view.physicalSize = const Size(2240, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = _liveOperationsNowUtc();
      String? openedTrackIncident;
      String? openedCctvIncident;

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: [
              DecisionCreated(
                eventId: 'decision-dsp-replay-bias',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                dispatchId: 'DSP-REPLAY-BIAS',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-HERO',
              ),
              IntelligenceReceived(
                eventId: 'intel-dsp-replay-bias',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INTEL-DSP-REPLAY-BIAS',
                sourceType: 'wearable',
                provider: 'onyx',
                externalId: 'evt-dsp-replay-bias',
                riskScore: 89,
                headline: 'Guard distress telemetry',
                summary:
                    'Heart rate spike plus no movement detected for Guard001.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-HERO',
                canonicalHash: 'canon-dsp-replay-bias',
              ),
            ],
            scenarioReplayHistorySignalService:
                const _FakeReplayHistorySignalService(
                  _promotedReplayConflictSignal,
                ),
            onOpenTrackForIncident: (incidentReference) {
              openedTrackIncident = incidentReference;
            },
            onOpenCctvForIncident: (incidentReference) {
              openedCctvIncident = incidentReference;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OPEN CCTV REVIEW'), findsOneWidget);
      expect(
        find.textContaining('Replay priority keeps CCTV Review in front'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Replay policy bias: Replay history: specialist conflict promoted low -> medium',
        ),
        findsOneWidget,
      );

      final openBoardButton = find.byKey(
        const ValueKey('live-operations-command-open-board'),
      );
      await tester.ensureVisible(openBoardButton);
      await tester.tap(openBoardButton);
      await tester.pumpAndSettle();

      expect(openedCctvIncident, 'INC-DSP-REPLAY-BIAS');
      expect(openedTrackIncident, isNull);
      expect(find.text('CCTV Review handoff sealed.'), findsOneWidget);
    },
  );

  testWidgets(
    'live operations command current focus lets sequence fallback bias tactical track directly',
    (tester) async {
      tester.view.physicalSize = const Size(2240, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = _liveOperationsNowUtc();
      String? openedTrackIncident;
      String? openedCctvIncident;

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: [
              DecisionCreated(
                eventId: 'decision-dsp-sequence-fallback',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                dispatchId: 'DSP-SEQUENCE-FALLBACK',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-HERO',
              ),
              IntelligenceReceived(
                eventId: 'intel-dsp-sequence-fallback',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INTEL-DSP-SEQUENCE-FALLBACK',
                sourceType: 'wearable',
                provider: 'onyx',
                externalId: 'evt-dsp-sequence-fallback',
                riskScore: 89,
                headline: 'Guard distress telemetry',
                summary:
                    'Heart rate spike plus no movement detected for Guard001.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-HERO',
                canonicalHash: 'canon-dsp-sequence-fallback',
              ),
            ],
            scenarioReplayHistorySignalService:
                const _FakeReplayHistorySignalService(
                  _sequenceFallbackReplaySignal,
                ),
            onOpenTrackForIncident: (incidentReference) {
              openedTrackIncident = incidentReference;
            },
            onOpenCctvForIncident: (incidentReference) {
              openedCctvIncident = incidentReference;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OPEN TACTICAL TRACK'), findsOneWidget);
      expect(
        find.textContaining(
          'Replay priority keeps Tactical Track in front while sequence fallback stays active.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Replay policy bias: Replay history: sequence fallback low.',
        ),
        findsOneWidget,
      );

      final openBoardButton = find.byKey(
        const ValueKey('live-operations-command-open-board'),
      );
      await tester.ensureVisible(openBoardButton);
      await tester.tap(openBoardButton);
      await tester.pumpAndSettle();

      expect(openedTrackIncident, 'INC-DSP-SEQUENCE-FALLBACK');
      expect(openedCctvIncident, isNull);
      expect(find.text('Tactical Track handoff sealed.'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('live-operations-command-memory-command-brain-replay'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey(
              'live-operations-command-memory-command-brain-replay',
            ),
          ),
          matching: find.textContaining(
            'Replay policy bias: Replay history: sequence fallback low.',
          ),
        ),
        findsOneWidget,
      );

      await _openDetailedWorkspace(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey(
            'live-operations-command-receipt-command-brain-replay',
          ),
        ),
        findsOneWidget,
      );
      final receiptReplayContext = tester.widget<Text>(
        find.byKey(
          const ValueKey(
            'live-operations-command-receipt-command-brain-replay',
          ),
        ),
      );
      expect(
        receiptReplayContext.data,
        contains('Replay policy bias: Replay history: sequence fallback low.'),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('live-operations-command-receipt')),
          matching: find.byKey(
            const ValueKey('live-operations-command-receipt-command-outcome'),
          ),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey(
                  'live-operations-command-receipt-command-outcome',
                ),
              ),
            )
            .data,
        'Replay priority keeps Tactical Track in front while sequence fallback stays active.',
      );
    },
  );

  testWidgets(
    'live operations command current focus frames promoted sequence fallback as policy escalation',
    (tester) async {
      tester.view.physicalSize = const Size(2240, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = _liveOperationsNowUtc();

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: [
              DecisionCreated(
                eventId: 'decision-dsp-sequence-fallback-critical',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                dispatchId: 'DSP-SEQUENCE-FALLBACK-CRITICAL',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-HERO',
              ),
              IntelligenceReceived(
                eventId: 'intel-dsp-sequence-fallback-critical',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INTEL-DSP-SEQUENCE-FALLBACK-CRITICAL',
                sourceType: 'wearable',
                provider: 'onyx',
                externalId: 'evt-dsp-sequence-fallback-critical',
                riskScore: 89,
                headline: 'Guard distress telemetry',
                summary:
                    'Heart rate spike plus no movement detected for Guard001.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-HERO',
                canonicalHash: 'canon-dsp-sequence-fallback-critical',
              ),
            ],
            scenarioReplayHistorySignalService:
                const _FakeReplayHistorySignalService(
                  _promotedSequenceFallbackReplaySignal,
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OPEN TACTICAL TRACK'), findsOneWidget);
      expect(find.text('Policy escalation'), findsOneWidget);
      expect(
        find.textContaining(
          'Replay policy escalation keeps Tactical Track in front while sequence fallback stays active.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Replay policy escalation: Replay history: sequence fallback promoted high -> critical via scenario set/scenario policy.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'live operations command current focus shows ordered replay pressure stack',
    (tester) async {
      tester.view.physicalSize = const Size(2240, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = _liveOperationsNowUtc();

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: [
              DecisionCreated(
                eventId: 'decision-dsp-sequence-stack',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                dispatchId: 'DSP-SEQUENCE-STACK',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-HERO',
              ),
              IntelligenceReceived(
                eventId: 'intel-dsp-sequence-stack',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INTEL-DSP-SEQUENCE-STACK',
                sourceType: 'wearable',
                provider: 'onyx',
                externalId: 'evt-dsp-sequence-stack',
                riskScore: 89,
                headline: 'Guard distress telemetry',
                summary:
                    'Heart rate spike plus no movement detected for Guard001.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-HERO',
                canonicalHash: 'canon-dsp-sequence-stack',
              ),
            ],
            scenarioReplayHistorySignalService:
                const _FakeReplayHistorySignalService(
                  _promotedSequenceFallbackReplaySignal,
                  signalStack: <ScenarioReplayHistorySignal>[
                    _promotedSequenceFallbackReplaySignal,
                    _promotedReplayConflictSignal,
                  ],
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Secondary replay pressure: Replay history: specialist conflict',
        ),
        findsWidgets,
      );
      final replayHistoryText = tester.widget<Text>(
        find.byKey(const ValueKey('live-operations-command-replay-history')),
      );
      expect(
        replayHistoryText.data,
        contains(
          'Primary replay pressure: Replay history: sequence fallback promoted high -> critical',
        ),
      );
      expect(
        find.textContaining(
          'Primary replay pressure: Replay policy escalation: Replay history: sequence fallback promoted high -> critical',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'live operations command current focus shows cleared sequence fallback without rebiasing dispatch',
    (tester) async {
      tester.view.physicalSize = const Size(2240, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = _liveOperationsNowUtc();

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: [
              DecisionCreated(
                eventId: 'decision-dsp-sequence-recovery',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                dispatchId: 'DSP-SEQUENCE-RECOVERY',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-HERO',
              ),
              IntelligenceReceived(
                eventId: 'intel-dsp-sequence-recovery',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INTEL-DSP-SEQUENCE-RECOVERY',
                sourceType: 'wearable',
                provider: 'onyx',
                externalId: 'evt-dsp-sequence-recovery',
                riskScore: 89,
                headline: 'Guard distress telemetry',
                summary:
                    'Heart rate spike plus no movement detected for Guard001.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-HERO',
                canonicalHash: 'canon-dsp-sequence-recovery',
              ),
            ],
            scenarioReplayHistorySignalService:
                const _FakeReplayHistorySignalService(
                  _sequenceFallbackRecoverySignal,
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OPEN TACTICAL TRACK'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('live-operations-command-replay-history')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Replay history: sequence fallback cleared.'),
        findsWidgets,
      );
      expect(
        find.textContaining(
          'Dispatch Board is back in front after replay fallback cleared from Tactical Track.',
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey('live-operations-command-current-focus'),
          ),
          matching: find.textContaining('Replay policy bias:'),
        ),
        findsNothing,
      );
      expect(find.text('Clear replay risk first.'), findsNothing);
    },
  );

  testWidgets(
    'live operations command current focus surfaces replay bias stack drift without inventing a tertiary stack slot',
    (tester) async {
      tester.view.physicalSize = const Size(2240, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = _liveOperationsNowUtc();

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: [
              DecisionCreated(
                eventId: 'decision-dsp-sequence-stack-drift',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                dispatchId: 'DSP-SEQUENCE-STACK-DRIFT',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-HERO',
              ),
              IntelligenceReceived(
                eventId: 'intel-dsp-sequence-stack-drift',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INTEL-DSP-SEQUENCE-STACK-DRIFT',
                sourceType: 'wearable',
                provider: 'onyx',
                externalId: 'evt-dsp-sequence-stack-drift',
                riskScore: 89,
                headline: 'Guard distress telemetry',
                summary:
                    'Heart rate spike plus no movement detected for Guard001.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-HERO',
                canonicalHash: 'canon-dsp-sequence-stack-drift',
              ),
            ],
            scenarioReplayHistorySignalService:
                const _FakeReplayHistorySignalService(
                  _stackedSequenceFallbackReplaySignal,
                  signalStack: <ScenarioReplayHistorySignal>[
                    _stackedSequenceFallbackReplaySignal,
                    _stackedReplayConflictSignal,
                    _replayBiasStackDriftSignal,
                  ],
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final replayHistoryText = tester.widget<Text>(
        find.byKey(const ValueKey('live-operations-command-replay-history')),
      );
      expect(
        replayHistoryText.data,
        contains(
          'Primary replay pressure: Replay history: sequence fallback low.',
        ),
      );
      expect(
        replayHistoryText.data,
        contains(
          'Secondary replay pressure: Replay history: specialist conflict promoted low -> medium.',
        ),
      );
      expect(
        replayHistoryText.data,
        contains('Replay history: replay bias stack drift critical.'),
      );
      expect(
        replayHistoryText.data,
        contains(
          'Previous pressure: Primary replay pressure: sequence fallback -> Tactical Track.',
        ),
      );
      expect(
        replayHistoryText.data,
        contains(
          'Latest pressure: Primary replay pressure: sequence fallback -> Tactical Track. Secondary replay pressure: specialist conflict -> CCTV Review.',
        ),
      );
      expect(
        replayHistoryText.data,
        isNot(contains('Tertiary replay pressure')),
      );
    },
  );

  testWidgets(
    'live operations command current focus restores replay bias stack drift from session memory when replay history reload fails',
    (tester) async {
      LiveOperationsPage.debugResetReplayHistoryMemorySession();
      addTearDown(LiveOperationsPage.debugResetReplayHistoryMemorySession);
      tester.view.physicalSize = const Size(2240, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = _liveOperationsNowUtc();

      final List<DispatchEvent> continuityEvents = [
        DecisionCreated(
          eventId: 'decision-dsp-sequence-stack-drift-memory',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 2)),
          dispatchId: 'DSP-SEQUENCE-STACK-DRIFT-MEMORY',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-HERO',
        ),
        IntelligenceReceived(
          eventId: 'intel-dsp-sequence-stack-drift-memory',
          sequence: 2,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 1)),
          intelligenceId: 'INTEL-DSP-SEQUENCE-STACK-DRIFT-MEMORY',
          sourceType: 'wearable',
          provider: 'onyx',
          externalId: 'evt-dsp-sequence-stack-drift-memory',
          riskScore: 89,
          headline: 'Guard distress telemetry',
          summary: 'Heart rate spike plus no movement detected for Guard001.',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-HERO',
          canonicalHash: 'canon-dsp-sequence-stack-drift-memory',
        ),
      ];

      Future<void> pumpLiveOps(
        ScenarioReplayHistorySignalService replayHistorySignalService, {
        List<DispatchEvent>? events,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: LiveOperationsPage(
              events: events ?? continuityEvents,
              scenarioReplayHistorySignalService: replayHistorySignalService,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpLiveOps(
        const _FakeReplayHistorySignalService(_replayBiasStackDriftSignal),
      );

      expect(
        find.textContaining(
          'Replay bias stack changed. Previous pressure: Primary replay pressure: sequence fallback -> Tactical Track.',
        ),
        findsWidgets,
      );
      expect(
        find.textContaining(
          'Latest pressure: Primary replay pressure: sequence fallback -> Tactical Track. Secondary replay pressure: specialist conflict -> CCTV Review.',
        ),
        findsWidgets,
      );
      expect(
        find.byKey(
          const ValueKey('live-operations-command-memory-replay-history'),
        ),
        findsOneWidget,
      );

      await pumpLiveOps(
        const _ThrowingReplayHistorySignalService(),
        events: continuityEvents,
      );

      expect(
        find.textContaining(
          'Remembered replay continuity: Replay history: replay bias stack drift critical.',
        ),
        findsOneWidget,
      );

      await pumpLiveOps(
        const _ThrowingReplayHistorySignalService(),
        events: const <DispatchEvent>[],
      );

      expect(
        find.textContaining(
          'Replay bias stack changed. Previous pressure: Primary replay pressure: sequence fallback -> Tactical Track.',
        ),
        findsWidgets,
      );
      expect(
        find.textContaining(
          'Latest pressure: Primary replay pressure: sequence fallback -> Tactical Track. Secondary replay pressure: specialist conflict -> CCTV Review.',
        ),
        findsWidgets,
      );
      expect(
        find.byKey(
          const ValueKey('live-operations-command-memory-replay-history'),
        ),
        findsOneWidget,
      );
      await _openDetailedWorkspace(tester);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey('live-operations-command-receipt-replay-history'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'live operations restores replay-backed command receipt from session memory when replay history reload fails',
    (tester) async {
      LiveOperationsPage.debugResetReplayHistoryMemorySession();
      addTearDown(LiveOperationsPage.debugResetReplayHistoryMemorySession);
      tester.view.physicalSize = const Size(2240, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = _liveOperationsNowUtc();
      final continuityEvents = <DispatchEvent>[
        DecisionCreated(
          eventId: 'decision-dsp-sequence-receipt-memory',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 2)),
          dispatchId: 'DSP-SEQUENCE-RECEIPT-MEMORY',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-HERO',
        ),
        IntelligenceReceived(
          eventId: 'intel-dsp-sequence-receipt-memory',
          sequence: 2,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 1)),
          intelligenceId: 'INTEL-DSP-SEQUENCE-RECEIPT-MEMORY',
          sourceType: 'wearable',
          provider: 'onyx',
          externalId: 'evt-dsp-sequence-receipt-memory',
          riskScore: 89,
          headline: 'Guard distress telemetry',
          summary: 'Heart rate spike plus no movement detected for Guard001.',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-HERO',
          canonicalHash: 'canon-dsp-sequence-receipt-memory',
        ),
      ];

      Future<void> pumpLiveOps(
        ScenarioReplayHistorySignalService replayHistorySignalService,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: LiveOperationsPage(
              events: continuityEvents,
              scenarioReplayHistorySignalService: replayHistorySignalService,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpLiveOps(
        const _FakeReplayHistorySignalService(_sequenceFallbackReplaySignal),
      );

      await tester.tap(
        find.byKey(const ValueKey('live-operations-command-open-board')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tactical Track handoff sealed.'), findsOneWidget);

      await pumpLiveOps(const _ThrowingReplayHistorySignalService());

      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey(
              'live-operations-command-memory-command-brain-replay',
            ),
          ),
          matching: find.textContaining(
            'Replay policy bias: Replay history: sequence fallback low.',
          ),
        ),
        findsOneWidget,
      );

      await _openDetailedWorkspace(tester);

      final receiptReplayContext = tester.widget<Text>(
        find.byKey(
          const ValueKey(
            'live-operations-command-receipt-command-brain-replay',
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('live-operations-command-receipt')),
          matching: find.text('Tactical Track handoff sealed.'),
        ),
        findsOneWidget,
      );
      expect(
        receiptReplayContext.data,
        contains('Replay policy bias: Replay history: sequence fallback low.'),
      );
    },
  );

  testWidgets(
    'live operations restores command preview from session memory without restoring raw command text',
    (tester) async {
      LiveOperationsPage.debugResetReplayHistoryMemorySession();
      addTearDown(LiveOperationsPage.debugResetReplayHistoryMemorySession);

      Future<void> pumpLiveOps(
        ScenarioReplayHistorySignalService replayHistorySignalService,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: LiveOperationsPage(
              events: const <DispatchEvent>[],
              scenarioReplayHistorySignalService: replayHistorySignalService,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpLiveOps(
        const _FakeReplayHistorySignalService(_sequenceFallbackReplaySignal),
      );

      await tester.enterText(
        find.byKey(const ValueKey('live-operations-command-input')),
        'Check status of Echo-3',
      );
      await tester.tap(
        find.byKey(const ValueKey('live-operations-command-submit')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('live-operations-command-intent-preview')),
        findsOneWidget,
      );
      expect(find.textContaining('Last command:'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await pumpLiveOps(const _ThrowingReplayHistorySignalService());

      final restoredPreview = find.byKey(
        const ValueKey('live-operations-command-intent-preview'),
      );
      expect(restoredPreview, findsOneWidget);
      expect(
        find.descendant(
          of: restoredPreview,
          matching: find.text('GUARD STATUS'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: restoredPreview,
          matching: find.text('Last check-in 22:12. Vigilance decay 67%.'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Last command preview restored from command memory.'),
        findsOneWidget,
      );
      expect(find.textContaining('Last command:'), findsNothing);
    },
  );

  testWidgets(
    'live operations does not restore replay continuity across scoped workspace changes',
    (tester) async {
      LiveOperationsPage.debugResetReplayHistoryMemorySession();
      addTearDown(LiveOperationsPage.debugResetReplayHistoryMemorySession);

      Future<void> pumpLiveOps({
        required String clientId,
        required String siteId,
        required ScenarioReplayHistorySignalService replayHistorySignalService,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: LiveOperationsPage(
              events: const <DispatchEvent>[],
              initialScopeClientId: clientId,
              initialScopeSiteId: siteId,
              scenarioReplayHistorySignalService: replayHistorySignalService,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpLiveOps(
        clientId: 'CLIENT-001',
        siteId: 'SITE-HERO',
        replayHistorySignalService: const _FakeReplayHistorySignalService(
          _sequenceFallbackReplaySignal,
        ),
      );

      expect(
        find.byKey(
          const ValueKey('live-operations-command-memory-replay-history'),
        ),
        findsOneWidget,
      );

      await pumpLiveOps(
        clientId: 'CLIENT-002',
        siteId: 'SITE-OTHER',
        replayHistorySignalService: const _ThrowingReplayHistorySignalService(),
      );

      expect(
        find.textContaining('Remembered replay continuity:'),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('live-operations-command-memory-replay-history'),
        ),
        findsNothing,
      );
      expect(
        find.textContaining('Replay history: sequence fallback low.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'live operations does not restore command preview across scoped workspace changes',
    (tester) async {
      LiveOperationsPage.debugResetReplayHistoryMemorySession();
      addTearDown(LiveOperationsPage.debugResetReplayHistoryMemorySession);

      Future<void> pumpLiveOps({
        required String clientId,
        required String siteId,
        required ScenarioReplayHistorySignalService replayHistorySignalService,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: LiveOperationsPage(
              events: const <DispatchEvent>[],
              initialScopeClientId: clientId,
              initialScopeSiteId: siteId,
              scenarioReplayHistorySignalService: replayHistorySignalService,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpLiveOps(
        clientId: 'CLIENT-001',
        siteId: 'SITE-HERO',
        replayHistorySignalService: const _FakeReplayHistorySignalService(
          _sequenceFallbackReplaySignal,
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('live-operations-command-input')),
        'Check status of Echo-3',
      );
      await tester.tap(
        find.byKey(const ValueKey('live-operations-command-submit')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('live-operations-command-intent-preview')),
        findsOneWidget,
      );

      await pumpLiveOps(
        clientId: 'CLIENT-002',
        siteId: 'SITE-OTHER',
        replayHistorySignalService: const _ThrowingReplayHistorySignalService(),
      );

      expect(
        find.byKey(const ValueKey('live-operations-command-intent-preview')),
        findsNothing,
      );
      expect(
        find.text('Last command preview restored from command memory.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'live operations renders desktop workspace shell and routes workspace controls',
    (tester) async {
      tester.view.physicalSize = const Size(2240, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = _liveOperationsNowUtc();
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            focusIncidentReference: 'INC-DSP-LOW',
            events: [
              DecisionCreated(
                eventId: 'decision-low-workspace',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 4)),
                dispatchId: 'DSP-LOW',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-LOW',
              ),
              IntelligenceReceived(
                eventId: 'intel-low-workspace',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 3)),
                intelligenceId: 'INTEL-LOW',
                sourceType: 'hardware',
                provider: 'dahua',
                externalId: 'evt-low-workspace',
                riskScore: 72,
                headline: 'Perimeter motion',
                summary: 'Moderate perimeter motion detected.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-LOW',
                faceConfidence: 0.82,
                canonicalHash: 'canon-low-workspace',
              ),
              DecisionCreated(
                eventId: 'decision-critical-workspace',
                sequence: 3,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                dispatchId: 'DSP-CRIT',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-CRIT',
              ),
              IntelligenceReceived(
                eventId: 'intel-critical-workspace',
                sequence: 4,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INTEL-CRIT',
                sourceType: 'hardware',
                provider: 'dahua',
                externalId: 'evt-crit-workspace',
                riskScore: 92,
                headline: 'Fire alarm escalation',
                summary: 'Critical hazard posture detected.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-CRIT',
                faceConfidence: 0.97,
                canonicalHash: 'canon-crit-workspace',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openDetailedWorkspace(tester);

      expect(
        find.byKey(const ValueKey('live-operations-workspace-status-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('live-operations-workspace-panel-rail')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('live-operations-workspace-panel-board')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('live-operations-workspace-panel-context')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('live-operations-command-receipt')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('live-operations-board-focus-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('live-operations-incident-focus-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('live-operations-context-focus-card')),
        findsOneWidget,
      );
      final incidentFocusCard = tester.widget<Container>(
        find.byKey(const ValueKey('live-operations-incident-focus-card')),
      );
      final incidentFocusDecoration =
          incidentFocusCard.decoration! as BoxDecoration;
      final incidentFocusGradient =
          incidentFocusDecoration.gradient! as LinearGradient;
      expect(incidentFocusGradient.colors, const [
        Color(0xFFF3F9FD),
        Color(0xFFFFFFFF),
      ]);
      final boardFocusCard = tester.widget<Container>(
        find.byKey(const ValueKey('live-operations-board-focus-card')),
      );
      final boardFocusDecoration = boardFocusCard.decoration! as BoxDecoration;
      final boardFocusGradient =
          boardFocusDecoration.gradient! as LinearGradient;
      expect(boardFocusGradient.colors, const [
        Color(0xFFFFFFFF),
        Color(0xFFF4F8FC),
      ]);
      expect(find.text('Active Incident: INC-DSP-LOW'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('live-operations-incident-focus-open-board')),
        160,
        scrollable: find.descendant(
          of: find.byKey(
            const ValueKey('live-operations-incident-queue-scroll-view'),
          ),
          matching: find.byType(Scrollable),
        ),
      );
      final incidentBoardAction = find
          .ancestor(
            of: find.byKey(
              const ValueKey('live-operations-incident-focus-open-board'),
            ),
            matching: find.byType(InkWell),
          )
          .first;
      final incidentBoardTap = tester.widget<InkWell>(incidentBoardAction);
      expect(incidentBoardTap.onTap, isNotNull);
      incidentBoardTap.onTap!();
      await tester.pumpAndSettle();

      expect(find.text('Board focus opened for INC-DSP-LOW.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.scrollUntilVisible(
        find.byKey(
          const ValueKey('live-operations-incident-focus-focus-critical'),
        ),
        100,
        scrollable: find.descendant(
          of: find.byKey(
            const ValueKey('live-operations-incident-queue-scroll-view'),
          ),
          matching: find.byType(Scrollable),
        ),
      );
      final incidentCriticalAction = find
          .ancestor(
            of: find.byKey(
              const ValueKey('live-operations-incident-focus-focus-critical'),
            ),
            matching: find.byType(InkWell),
          )
          .first;
      final incidentCriticalTap = tester.widget<InkWell>(
        incidentCriticalAction,
      );
      expect(incidentCriticalTap.onTap, isNotNull);
      incidentCriticalTap.onTap!();
      await tester.pumpAndSettle();

      expect(find.text('Active Incident: INC-DSP-CRIT'), findsOneWidget);
      expect(
        find.text('Critical incident focused for INC-DSP-CRIT.'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('live-operations-incident-focus-open-queue')),
        100,
        scrollable: find.descendant(
          of: find.byKey(
            const ValueKey('live-operations-incident-queue-scroll-view'),
          ),
          matching: find.byType(Scrollable),
        ),
      );
      final incidentQueueAction = find
          .ancestor(
            of: find.byKey(
              const ValueKey('live-operations-incident-focus-open-queue'),
            ),
            matching: find.byType(InkWell),
          )
          .first;
      final incidentQueueTap = tester.widget<InkWell>(incidentQueueAction);
      expect(incidentQueueTap.onTap, isNotNull);
      incidentQueueTap.onTap!();
      await tester.pumpAndSettle();

      expect(find.text('Queue focus opened for INC-DSP-CRIT.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('live-operations-board-focus-open-voip')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('VoIP Call Active - Recording in progress'),
        findsOneWidget,
      );
      expect(
        find.text('VOIP context opened for INC-DSP-CRIT.'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('live-operations-context-focus-open-visual')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Match Score'), findsOneWidget);
      expect(
        find.text('Context rail opened VISUAL for INC-DSP-CRIT.'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(
        find.byKey(
          const ValueKey('live-operations-context-focus-guard-attention'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Guard attention centered on Alpha-5.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('live-operations-context-focus-guard-chip')),
        findsOneWidget,
      );
      expect(find.text('Alpha-5 • 98%'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('live operations recovers empty desktop context tabs in place', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2240, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = _liveOperationsNowUtc();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          initialScopeClientId: 'CLIENT-RECOVERY',
          initialScopeSiteId: 'SITE-RECOVERY',
          clientCommsSnapshot: const LiveClientCommsSnapshot(
            clientId: 'CLIENT-RECOVERY',
            siteId: 'SITE-RECOVERY',
          ),
          events: [
            DecisionCreated(
              eventId: 'decision-other-scope-recovery',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 3)),
              dispatchId: 'DSP-OTHER',
              clientId: 'CLIENT-OTHER',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-OTHER',
            ),
            IntelligenceReceived(
              eventId: 'intel-other-scope-recovery',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              intelligenceId: 'INTEL-OTHER',
              sourceType: 'hardware',
              provider: 'dahua',
              externalId: 'evt-other-scope-recovery',
              riskScore: 78,
              headline: 'Other scope motion',
              summary: 'This event should stay outside the scoped workspace.',
              clientId: 'CLIENT-OTHER',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-OTHER',
              faceConfidence: 0.84,
              canonicalHash: 'canon-other-scope-recovery',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openDetailedWorkspace(tester);

    await tester.tap(
      find.byKey(const ValueKey('live-operations-workspace-tab-voip')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('live-operations-voip-recovery')),
      findsOneWidget,
    );
    expect(find.text('No live call is pinned yet.'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(
        const ValueKey('live-operations-context-recovery-open-client-lane'),
      ),
    );
    await tester.tap(
      find.byKey(
        const ValueKey('live-operations-context-recovery-open-client-lane'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Client Comms fallback opened in place.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('live-operations-workspace-tab-visual')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('live-operations-visual-recovery')),
      findsOneWidget,
    );
    expect(find.text('No camera comparison is pinned yet.'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('live-operations-context-recovery-open-queue')),
    );
    await tester.tap(
      find.byKey(const ValueKey('live-operations-context-recovery-open-queue')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pending actions recovery opened.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'live operations verifies pending ledger chain entries in place',
    (tester) async {
      tester.view.physicalSize = const Size(2240, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = _liveOperationsNowUtc();
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            focusIncidentReference: 'INC-DSP-LEDGER',
            events: [
              DecisionCreated(
                eventId: 'decision-ledger',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 3)),
                dispatchId: 'DSP-LEDGER',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-LEDGER',
              ),
              PartnerDispatchStatusDeclared(
                eventId: 'partner-ledger',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                dispatchId: 'DSP-LEDGER',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-LEDGER',
                partnerLabel: 'PARTNER • Alpha',
                actorLabel: '@partner.alpha',
                status: PartnerDispatchStatus.accepted,
                sourceChannel: 'telegram',
                sourceMessageKey: 'tg-ledger',
              ),
              IntelligenceReceived(
                eventId: 'intel-ledger',
                sequence: 3,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INTEL-LEDGER',
                sourceType: 'hardware',
                provider: 'dahua',
                externalId: 'evt-ledger',
                riskScore: 78,
                headline: 'Activity cluster detected',
                summary: 'Cross-checking a partner escalation in the lane.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-LEDGER',
                faceConfidence: 0.9,
                canonicalHash: 'canon-ledger',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openDetailedWorkspace(tester);

      final ledgerPanel = find.byKey(
        const ValueKey('live-operations-ledger-preview'),
      );
      expect(ledgerPanel, findsOneWidget);
      expect(find.text('Chain status: Pending verification'), findsOneWidget);
      expect(
        find.descendant(of: ledgerPanel, matching: find.text('PENDING')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('live-operations-ledger-verify-chain')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chain status: Verified'), findsOneWidget);
      expect(
        find.descendant(of: ledgerPanel, matching: find.text('PENDING')),
        findsNothing,
      );
      expect(find.text('Re-run Verify'), findsOneWidget);
    },
  );

  testWidgets('live operations narrows incidents to the scoped lane', (
    tester,
  ) async {
    final now = _liveOperationsNowUtc();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          initialScopeClientId: 'CLIENT-001',
          initialScopeSiteId: 'SITE-VALLEE',
          events: [
            DecisionCreated(
              eventId: 'decision-sandton',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 4)),
              dispatchId: 'D-1001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            DecisionCreated(
              eventId: 'decision-vallee',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              dispatchId: 'D-2001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-VALLEE',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('live-operations-scope-banner')),
      findsOneWidget,
    );
    expect(find.text('Scope focus active'), findsOneWidget);
    expect(find.text('CLIENT-001/SITE-VALLEE'), findsOneWidget);
    expect(find.byKey(const Key('incident-card-INC-D-2001')), findsOneWidget);
    expect(find.byKey(const Key('incident-card-INC-D-1001')), findsNothing);
  });

  testWidgets(
    'live operations reprojects scoped incidents when same-length event inputs are replaced',
    (tester) async {
      final now = _liveOperationsNowUtc();
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            initialScopeClientId: 'CLIENT-001',
            initialScopeSiteId: 'SITE-VALLEE',
            events: [
              DecisionCreated(
                eventId: 'decision-sandton-initial',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 4)),
                dispatchId: 'D-1001',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SANDTON',
              ),
              DecisionCreated(
                eventId: 'decision-vallee-initial',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                dispatchId: 'D-2001',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-VALLEE',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('incident-card-INC-D-2001')), findsOneWidget);
      expect(find.byKey(const Key('incident-card-INC-D-2002')), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            initialScopeClientId: 'CLIENT-001',
            initialScopeSiteId: 'SITE-VALLEE',
            events: [
              DecisionCreated(
                eventId: 'decision-sandton-replaced',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 4)),
                dispatchId: 'D-1001',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SANDTON',
              ),
              DecisionCreated(
                eventId: 'decision-vallee-replaced',
                sequence: 2,
                version: 2,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                dispatchId: 'D-2002',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-VALLEE',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('incident-card-INC-D-2002')), findsOneWidget);
      expect(find.byKey(const Key('incident-card-INC-D-2001')), findsNothing);
    },
  );

  testWidgets('live operations supports client-wide scope focus', (
    tester,
  ) async {
    final now = _liveOperationsNowUtc();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          initialScopeClientId: 'CLIENT-001',
          initialScopeSiteId: '',
          events: [
            DecisionCreated(
              eventId: 'decision-sandton',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 4)),
              dispatchId: 'D-1001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            DecisionCreated(
              eventId: 'decision-vallee',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              dispatchId: 'D-2001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-VALLEE',
            ),
            DecisionCreated(
              eventId: 'decision-other-client',
              sequence: 3,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 1)),
              dispatchId: 'D-3001',
              clientId: 'CLIENT-999',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-OTHER',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('live-operations-scope-banner')),
      findsOneWidget,
    );
    expect(find.text('CLIENT-001/all sites'), findsOneWidget);
    expect(find.byKey(const Key('incident-card-INC-D-2001')), findsOneWidget);
    expect(find.byKey(const Key('incident-card-INC-D-1001')), findsOneWidget);
    expect(find.byKey(const Key('incident-card-INC-D-3001')), findsNothing);
  });

  testWidgets(
    'live operations links intelligence focus to live dispatch lane',
    (tester) async {
      final now = _liveOperationsNowUtc();
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            focusIncidentReference: 'INTEL-VALLEE-1',
            events: [
              DecisionCreated(
                eventId: 'decision-vallee',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 3)),
                dispatchId: 'DSP-4',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-VALLEE',
              ),
              IntelligenceReceived(
                eventId: 'intel-event-1',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INTEL-VALLEE-1',
                sourceType: 'hardware',
                provider: 'dahua',
                externalId: 'evt-vallee-1',
                riskScore: 81,
                headline: 'Perimeter motion detected',
                summary: 'Motion flagged near the Vallee perimeter fence.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-VALLEE',
                faceConfidence: 0.94,
                canonicalHash: 'canon-vallee-1',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('incident-card-INC-DSP-4')), findsOneWidget);
      expect(find.text('Focus Scope-backed: INC-DSP-4'), findsOneWidget);
      expect(find.text('Focused Operations Lane'), findsNothing);
    },
  );

  testWidgets(
    'live operations critical alert banner focuses the critical incident',
    (tester) async {
      final now = _liveOperationsNowUtc();
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            focusIncidentReference: 'INC-DSP-LOW',
            events: [
              DecisionCreated(
                eventId: 'decision-low',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 4)),
                dispatchId: 'DSP-LOW',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-LOW',
              ),
              IntelligenceReceived(
                eventId: 'intel-low',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 3)),
                intelligenceId: 'INTEL-LOW',
                sourceType: 'hardware',
                provider: 'dahua',
                externalId: 'evt-low',
                riskScore: 72,
                headline: 'Perimeter motion',
                summary: 'Moderate perimeter motion detected.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-LOW',
                faceConfidence: 0.82,
                canonicalHash: 'canon-low',
              ),
              DecisionCreated(
                eventId: 'decision-critical',
                sequence: 3,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                dispatchId: 'DSP-CRIT',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-CRIT',
              ),
              IntelligenceReceived(
                eventId: 'intel-critical',
                sequence: 4,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INTEL-CRIT',
                sourceType: 'hardware',
                provider: 'dahua',
                externalId: 'evt-crit',
                riskScore: 92,
                headline: 'Fire alarm escalation',
                summary: 'Critical hazard posture detected.',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-CRIT',
                faceConfidence: 0.97,
                canonicalHash: 'canon-crit',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('live-operations-critical-alert-banner')),
        findsOneWidget,
      );
      expect(find.text('CRITICAL ALERT'), findsOneWidget);
      expect(find.text('Active Incident: INC-DSP-LOW'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey('live-operations-critical-alert-view-details'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active Incident: INC-DSP-CRIT'), findsOneWidget);
    },
  );

  testWidgets('manual override requires selecting a reason code', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LiveOperationsPage(events: [])),
    );

    final overrideButton = find.byKey(
      const ValueKey('live-operations-board-focus-override'),
    );
    await tester.ensureVisible(overrideButton);
    await tester.tap(overrideButton);
    await tester.pumpAndSettle();

    final submitFinder = find.byKey(const Key('override-submit-button'));
    expect(submitFinder, findsOneWidget);
    expect((tester.widget<FilledButton>(submitFinder)).onPressed, isNull);

    await tester.tap(find.byKey(const Key('reason-DUPLICATE_SIGNAL')));
    await tester.pumpAndSettle();

    expect((tester.widget<FilledButton>(submitFinder)).onPressed, isNotNull);

    await tester.tap(submitFinder);
    await tester.pumpAndSettle();
    expect(find.text('Select a reason code (required):'), findsNothing);
  });

  testWidgets('pause action records a ledger entry', (tester) async {
    tester.view.physicalSize = const Size(2240, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: LiveOperationsPage(events: [])),
    );
    await tester.pumpAndSettle();
    await _openDetailedWorkspace(tester);

    final pauseButton = find.byKey(
      const ValueKey('live-operations-board-focus-pause'),
    );
    await tester.ensureVisible(pauseButton);
    await tester.tap(pauseButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('live-operations-command-receipt')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Automation paused for INC-8829-QX'),
      findsWidgets,
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('live operations enriches incident context with CCTV evidence', (
    tester,
  ) async {
    final now = _liveOperationsNowUtc();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          morningSovereignReportHistory: [
            SovereignReport(
              date: '2026-03-14',
              generatedAtUtc: _liveOperationsMorningReportGeneratedAtUtc(14),
              shiftWindowStartUtc: _liveOperationsNightShiftStartedAtUtc(13),
              shiftWindowEndUtc: _liveOperationsMorningReportGeneratedAtUtc(14),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 10,
                hashVerified: true,
                integrityScore: 99,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 1,
                humanOverrides: 0,
                overrideReasons: <String, int>{},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 1,
                driftDetected: 0,
                avgMatchScore: 100,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
              partnerProgression: SovereignReportPartnerProgression(
                dispatchCount: 1,
                declarationCount: 1,
                acceptedCount: 1,
                onSiteCount: 0,
                allClearCount: 0,
                cancelledCount: 1,
                summaryLine: '',
                scoreboardRows: [
                  SovereignReportPartnerScoreboardRow(
                    clientId: 'CLIENT-001',
                    siteId: 'SITE-SANDTON',
                    partnerLabel: 'PARTNER • Alpha',
                    dispatchCount: 1,
                    strongCount: 0,
                    onTrackCount: 0,
                    watchCount: 0,
                    criticalCount: 1,
                    averageAcceptedDelayMinutes: 12.0,
                    averageOnSiteDelayMinutes: 22.0,
                    summaryLine:
                        'Dispatches 1 • Strong 0 • On track 0 • Watch 0 • Critical 1 • Avg accept 12.0m • Avg on site 22.0m',
                  ),
                ],
              ),
            ),
            SovereignReport(
              date: '2026-03-15',
              generatedAtUtc: _liveOperationsMorningReportGeneratedAtUtc(15),
              shiftWindowStartUtc: _liveOperationsNightShiftStartedAtUtc(14),
              shiftWindowEndUtc: _liveOperationsMorningReportGeneratedAtUtc(15),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 10,
                hashVerified: true,
                integrityScore: 99,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 1,
                humanOverrides: 0,
                overrideReasons: <String, int>{},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 1,
                driftDetected: 0,
                avgMatchScore: 100,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
              partnerProgression: SovereignReportPartnerProgression(
                dispatchCount: 1,
                declarationCount: 3,
                acceptedCount: 1,
                onSiteCount: 1,
                allClearCount: 1,
                cancelledCount: 0,
                summaryLine: '',
                scoreboardRows: [
                  SovereignReportPartnerScoreboardRow(
                    clientId: 'CLIENT-001',
                    siteId: 'SITE-SANDTON',
                    partnerLabel: 'PARTNER • Alpha',
                    dispatchCount: 1,
                    strongCount: 1,
                    onTrackCount: 0,
                    watchCount: 0,
                    criticalCount: 0,
                    averageAcceptedDelayMinutes: 4.0,
                    averageOnSiteDelayMinutes: 10.0,
                    summaryLine:
                        'Dispatches 1 • Strong 1 • On track 0 • Watch 0 • Critical 0 • Avg accept 4.0m • Avg on site 10.0m',
                  ),
                ],
              ),
            ),
          ],
          events: [
            DecisionCreated(
              eventId: 'decision-1',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 3)),
              dispatchId: 'D-1001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            IntelligenceReceived(
              eventId: 'intel-1',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              intelligenceId: 'INT-1',
              provider: 'frigate',
              sourceType: 'hardware',
              externalId: 'evt-1',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              headline: 'FRIGATE INTRUSION',
              summary: 'CCTV person detected in north_gate',
              riskScore: 95,
              snapshotUrl:
                  'https://edge.example.com/api/events/evt-1/snapshot.jpg',
              clipUrl: 'https://edge.example.com/api/events/evt-1/clip.mp4',
              canonicalHash: 'hash-1',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Latest CCTV Intel'), findsOneWidget);
    expect(find.text('FRIGATE INTRUSION'), findsOneWidget);
    expect(find.text('Evidence Ready'), findsOneWidget);
    expect(find.text('snapshot + clip'), findsWidgets);
    expect(find.textContaining('snapshot.jpg'), findsOneWidget);
    expect(find.textContaining('clip.mp4'), findsOneWidget);
  });

  testWidgets('live operations classifies fire scenes as emergency incidents', (
    tester,
  ) async {
    final now = _liveOperationsNowUtc();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          historicalSyntheticLearningLabels: const ['ADVANCE FIRE'],
          events: [
            DecisionCreated(
              eventId: 'decision-fire',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 3)),
              dispatchId: 'D-2001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-FIRE',
            ),
            IntelligenceReceived(
              eventId: 'intel-fire',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              intelligenceId: 'INT-FIRE',
              provider: 'hikvision_dvr_monitor_only',
              sourceType: 'dvr',
              externalId: 'evt-fire',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-FIRE',
              cameraId: 'generator-room-cam',
              objectLabel: 'smoke',
              objectConfidence: 0.94,
              headline: 'HIKVISION FIRE ALERT',
              summary: 'Smoke visible in the generator room.',
              riskScore: 74,
              snapshotUrl: 'https://edge.example.com/fire.jpg',
              canonicalHash: 'hash-fire',
            ),
          ],
          sceneReviewByIntelligenceId: {
            'INT-FIRE': MonitoringSceneReviewRecord(
              intelligenceId: 'INT-FIRE',
              sourceLabel: 'openai:gpt-5.4-mini',
              postureLabel: 'fire and smoke emergency',
              decisionLabel: 'Escalation Candidate',
              decisionSummary:
                  'Escalated for urgent review because fire or smoke indicators were detected.',
              summary: 'Smoke plume visible inside the generator room.',
              reviewedAtUtc: now.subtract(const Duration(minutes: 1)),
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fire / Smoke Emergency'), findsWidgets);
    expect(find.text('Next-Shift Drafts'), findsOneWidget);
    expect(find.text('DRAFT NEXT-SHIFT FIRE READINESS'), findsOneWidget);
    expect(
      find.textContaining('Prebuild next-shift fire readiness'),
      findsOneWidget,
    );
    expect(find.text('P1'), findsWidgets);
    expect(find.textContaining('fire and smoke emergency'), findsOneWidget);
    expect(find.text('FIRE RESPONSE'), findsWidgets);
    expect(find.text('CLIENT SAFETY CALL'), findsOneWidget);
    expect(find.text('FIRE VERIFY'), findsOneWidget);
    expect(
      find.textContaining(
        'Dispatching fire response, holding emergency notification, and staging occupant welfare checks.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Fire emergency dispatch staged • welfare check hot'),
      findsOneWidget,
    );
  });

  testWidgets(
    'live operations shows shadow readiness bias for repeated MO pressure',
    (tester) async {
      final now = _liveOperationsNowUtc();
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            previousTomorrowUrgencySummary: 'strength stable • high • 28s',
            historicalShadowMoLabels: const ['HARDEN ACCESS'],
            historicalShadowStrengthLabels: const ['strength rising'],
            events: [
              DecisionCreated(
                eventId: 'decision-shadow',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 3)),
                dispatchId: 'D-3001',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-OFFICE',
              ),
              IntelligenceReceived(
                eventId: 'intel-shadow-news',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                intelligenceId: 'INT-SHADOW-NEWS',
                provider: 'news_feed_monitor',
                sourceType: 'news',
                externalId: 'ext-shadow-news',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-OFFICE',
                cameraId: 'feed-news',
                objectLabel: 'person',
                objectConfidence: 0.70,
                headline: 'Contractors moved floor to floor in office park',
                summary:
                    'Suspects posed as maintenance contractors before moving across restricted office zones.',
                riskScore: 67,
                snapshotUrl: 'https://edge.example.com/shadow-news.jpg',
                canonicalHash: 'hash-shadow-news',
              ),
              IntelligenceReceived(
                eventId: 'intel-shadow-live',
                sequence: 3,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INT-SHADOW-LIVE',
                provider: 'hikvision_dvr_monitor_only',
                sourceType: 'dvr',
                externalId: 'ext-shadow-live',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-OFFICE',
                cameraId: 'office-cam',
                objectLabel: 'person',
                objectConfidence: 0.95,
                headline: 'Maintenance contractor probing office doors',
                summary:
                    'Contractor-like person moved floor to floor and tried several restricted office doors.',
                riskScore: 86,
                snapshotUrl: 'https://edge.example.com/shadow-live.jpg',
                canonicalHash: 'hash-shadow-live',
              ),
            ],
            sceneReviewByIntelligenceId: {
              'INT-SHADOW-LIVE': MonitoringSceneReviewRecord(
                intelligenceId: 'INT-SHADOW-LIVE',
                sourceLabel: 'openai:gpt-5.4-mini',
                postureLabel: 'service impersonation and roaming concern',
                decisionLabel: 'Escalation Candidate',
                decisionSummary:
                    'Likely spoofed service access with abnormal roaming.',
                summary:
                    'Likely maintenance impersonation moving across office zones.',
                reviewedAtUtc: now,
              ),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Next-Shift Drafts'), findsOneWidget);
      expect(find.text('DRAFT NEXT-SHIFT ACCESS HARDENING'), findsOneWidget);
      expect(find.text('Shadow'), findsOneWidget);
      expect(find.textContaining('HARDEN ACCESS'), findsWidgets);
      expect(find.text('Urgency'), findsOneWidget);
      expect(find.textContaining('strength rising • critical'), findsOneWidget);
      expect(find.text('Previous urgency'), findsOneWidget);
      expect(
        find.textContaining('strength stable • high • 28s'),
        findsOneWidget,
      );
      expect(find.text('Readiness bias'), findsOneWidget);
      expect(find.textContaining('earlier access hardening'), findsOneWidget);
    },
  );

  testWidgets(
    'live operations explains posture-heated promotion pressure in next-shift card',
    (tester) async {
      final now = _liveOperationsNowUtc();
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            historicalShadowMoLabels: const ['HARDEN ACCESS'],
            events: [
              DecisionCreated(
                eventId: 'decision-promo',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 4)),
                dispatchId: 'D-4100',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-VALLEE',
              ),
              IntelligenceReceived(
                eventId: 'promo-news',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 3)),
                intelligenceId: 'INT-PROMO-NEWS',
                provider: 'news_feed_monitor',
                sourceType: 'news',
                externalId: 'ext-promo-news',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SEED',
                cameraId: 'feed-news',
                objectLabel: 'person',
                objectConfidence: 0.70,
                headline: 'Contractors moved floor to floor in office park',
                summary:
                    'Suspects posed as maintenance contractors before moving across restricted office zones.',
                riskScore: 67,
                snapshotUrl: 'https://edge.example.com/promo-news.jpg',
                canonicalHash: 'hash-promo-news',
              ),
              IntelligenceReceived(
                eventId: 'promo-live-1',
                sequence: 3,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                intelligenceId: 'INT-PROMO-LIVE-1',
                provider: 'hikvision_dvr_monitor_only',
                sourceType: 'dvr',
                externalId: 'ext-promo-live-1',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-VALLEE',
                cameraId: 'office-cam-1',
                objectLabel: 'person',
                objectConfidence: 0.95,
                headline: 'Unplanned contractor roaming',
                summary:
                    'Maintenance-like subject moved across restricted office doors.',
                riskScore: 86,
                snapshotUrl: 'https://edge.example.com/promo-live-1.jpg',
                canonicalHash: 'hash-promo-live-1',
              ),
              IntelligenceReceived(
                eventId: 'promo-live-2',
                sequence: 4,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                intelligenceId: 'INT-PROMO-LIVE-2',
                provider: 'hikvision_dvr_monitor_only',
                sourceType: 'dvr',
                externalId: 'ext-promo-live-2',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-VALLEE',
                cameraId: 'office-cam-2',
                objectLabel: 'person',
                objectConfidence: 0.95,
                headline: 'Contractor repeating office sweep',
                summary:
                    'Maintenance-like subject kept probing multiple office doors.',
                riskScore: 87,
                snapshotUrl: 'https://edge.example.com/promo-live-2.jpg',
                canonicalHash: 'hash-promo-live-2',
              ),
              IntelligenceReceived(
                eventId: 'promo-live-3',
                sequence: 5,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INT-PROMO-LIVE-3',
                provider: 'hikvision_dvr_monitor_only',
                sourceType: 'dvr',
                externalId: 'ext-promo-live-3',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-VALLEE',
                cameraId: 'office-cam-3',
                objectLabel: 'person',
                objectConfidence: 0.95,
                headline: 'Contractor revisits office floors',
                summary:
                    'Service-looking subject returned to several restricted office zones.',
                riskScore: 89,
                snapshotUrl: 'https://edge.example.com/promo-live-3.jpg',
                canonicalHash: 'hash-promo-live-3',
              ),
              IntelligenceReceived(
                eventId: 'promo-live-4',
                sequence: 6,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                intelligenceId: 'INT-PROMO-LIVE-4',
                provider: 'hikvision_dvr_monitor_only',
                sourceType: 'dvr',
                externalId: 'ext-promo-live-4',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-VALLEE',
                cameraId: 'office-cam-4',
                objectLabel: 'person',
                objectConfidence: 0.96,
                headline: 'Contractor returns to office zone again',
                summary:
                    'Service-looking subject kept sweeping office floors and retrying access.',
                riskScore: 92,
                snapshotUrl: 'https://edge.example.com/promo-live-4.jpg',
                canonicalHash: 'hash-promo-live-4',
              ),
            ],
            sceneReviewByIntelligenceId: {
              'INT-PROMO-LIVE-1': MonitoringSceneReviewRecord(
                intelligenceId: 'INT-PROMO-LIVE-1',
                sourceLabel: 'openai:gpt-5.4-mini',
                postureLabel: 'service impersonation and roaming concern',
                decisionLabel: 'Escalation Candidate',
                decisionSummary:
                    'Likely spoofed service access with abnormal roaming.',
                summary:
                    'Likely maintenance impersonation moving across office zones.',
                reviewedAtUtc: now.subtract(const Duration(minutes: 2)),
              ),
              'INT-PROMO-LIVE-2': MonitoringSceneReviewRecord(
                intelligenceId: 'INT-PROMO-LIVE-2',
                sourceLabel: 'openai:gpt-5.4-mini',
                postureLabel: 'service impersonation and roaming concern',
                decisionLabel: 'Escalation Candidate',
                decisionSummary:
                    'Likely spoofed service access with abnormal roaming.',
                summary:
                    'Likely maintenance impersonation moving across office zones repeatedly.',
                reviewedAtUtc: now.subtract(const Duration(minutes: 2)),
              ),
              'INT-PROMO-LIVE-3': MonitoringSceneReviewRecord(
                intelligenceId: 'INT-PROMO-LIVE-3',
                sourceLabel: 'openai:gpt-5.4-mini',
                postureLabel: 'service impersonation and roaming concern',
                decisionLabel: 'Escalation Candidate',
                decisionSummary:
                    'Likely spoofed service access with abnormal roaming.',
                summary:
                    'Likely maintenance impersonation moving across office zones again.',
                reviewedAtUtc: now.subtract(const Duration(minutes: 1)),
              ),
              'INT-PROMO-LIVE-4': MonitoringSceneReviewRecord(
                intelligenceId: 'INT-PROMO-LIVE-4',
                sourceLabel: 'openai:gpt-5.4-mini',
                postureLabel: 'service impersonation and roaming concern',
                decisionLabel: 'Escalation Candidate',
                decisionSummary:
                    'Likely spoofed service access with abnormal roaming.',
                summary:
                    'Likely maintenance impersonation continuing across office zones.',
                reviewedAtUtc: now.subtract(const Duration(minutes: 1)),
              ),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Next-Shift Drafts'), findsOneWidget);
      expect(find.text('Promotion pressure'), findsOneWidget);
      expect(find.text('Promotion execution'), findsOneWidget);
      expect(find.textContaining('high • 40s'), findsWidgets);
      expect(find.textContaining('toward validated review'), findsWidgets);
      expect(find.textContaining('posture POSTURE'), findsOneWidget);
    },
  );

  testWidgets(
    'live operations switches latest intel and ladder labels for DVR',
    (tester) async {
      final now = _liveOperationsNowUtc();
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: [
              DecisionCreated(
                eventId: 'decision-1',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 3)),
                dispatchId: 'D-1001',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SANDTON',
              ),
              IntelligenceReceived(
                eventId: 'intel-1',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                intelligenceId: 'INT-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-1',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SANDTON',
                headline: 'DVR INTRUSION',
                summary: 'DVR vehicle detected at bay_2',
                riskScore: 91,
                canonicalHash: 'hash-1',
              ),
            ],
            videoOpsLabel: 'DVR',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Latest DVR Intel'), findsOneWidget);
      expect(find.text('DVR ACTIVATION'), findsWidgets);
    },
  );

  testWidgets('live operations shows scene review alongside latest intel', (
    tester,
  ) async {
    final now = _liveOperationsNowUtc();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: [
            DecisionCreated(
              eventId: 'decision-1',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 3)),
              dispatchId: 'D-1001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            IntelligenceReceived(
              eventId: 'intel-2',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              intelligenceId: 'INT-2',
              provider: 'hikvision-dvr',
              sourceType: 'dvr',
              externalId: 'evt-2',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              headline: 'DVR BOUNDARY ALERT',
              summary: 'Motion detected at boundary line',
              riskScore: 92,
              canonicalHash: 'hash-2',
            ),
          ],
          videoOpsLabel: 'DVR',
          sceneReviewByIntelligenceId: {
            'INT-2': MonitoringSceneReviewRecord(
              intelligenceId: 'INT-2',
              sourceLabel: 'openai:gpt-4.1-mini',
              postureLabel: 'escalation candidate',
              decisionLabel: 'Escalation Candidate',
              decisionSummary:
                  'Escalated for urgent review because person activity was detected, the scene suggested boundary proximity, and confidence remained high.',
              summary: 'Person visible near the boundary line.',
              reviewedAtUtc: now.subtract(const Duration(minutes: 2)),
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scene Review'), findsOneWidget);
    expect(find.text('Review Detail'), findsOneWidget);
    expect(find.text('Scene Action'), findsOneWidget);
    expect(find.text('Action Detail'), findsOneWidget);
    expect(
      find.textContaining('openai:gpt-4.1-mini • escalation candidate'),
      findsOneWidget,
    );
    expect(find.text('Escalation Candidate'), findsOneWidget);
    expect(
      find.textContaining('Person visible near the boundary line.'),
      findsWidgets,
    );
    expect(find.textContaining('Escalated for urgent review'), findsOneWidget);
  });

  testWidgets(
    'live operations shows shadow MO intelligence for matched incident context',
    (tester) async {
      final now = _liveOperationsNowUtc();
      List<String>? openedEventIds;
      String? openedSelectedEventId;
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: [
              DecisionCreated(
                eventId: 'decision-shadow',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 3)),
                dispatchId: 'D-3001',
                clientId: 'CLIENT-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-OFFICE',
              ),
              IntelligenceReceived(
                eventId: 'evt-news',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(hours: 4)),
                intelligenceId: 'intel-news',
                provider: 'security_bulletin',
                sourceType: 'news',
                externalId: 'news-1',
                clientId: 'CLIENT-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-OFFICE',
                cameraId: 'feed-news',
                objectLabel: 'person',
                objectConfidence: 0.7,
                headline: 'Contractors moved floor to floor in office park',
                summary:
                    'Suspects posed as maintenance contractors, moved floor to floor through a business park, and tried several restricted office doors before stealing devices.',
                riskScore: 75,
                snapshotUrl: 'https://edge.example.com/news-office.jpg',
                canonicalHash: 'hash-news-office',
              ),
              IntelligenceReceived(
                eventId: 'evt-office',
                sequence: 3,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                intelligenceId: 'intel-office',
                provider: 'hikvision_dvr_monitor_only',
                sourceType: 'dvr',
                externalId: 'ext-office',
                clientId: 'CLIENT-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-OFFICE',
                cameraId: 'office-cam',
                objectLabel: 'person',
                objectConfidence: 0.95,
                headline: 'Maintenance contractor probing office doors',
                summary:
                    'Contractor-like person moved floor to floor and tried several restricted office doors.',
                riskScore: 86,
                snapshotUrl: 'https://edge.example.com/office.jpg',
                canonicalHash: 'hash-office',
              ),
            ],
            sceneReviewByIntelligenceId: {
              'intel-office': MonitoringSceneReviewRecord(
                intelligenceId: 'intel-office',
                sourceLabel: 'openai:gpt-5.4-mini',
                postureLabel: 'service impersonation and roaming concern',
                decisionLabel: 'Escalation Candidate',
                decisionSummary:
                    'Likely spoofed service access with abnormal roaming.',
                summary:
                    'Likely maintenance impersonation moving across office zones.',
                reviewedAtUtc: now.subtract(const Duration(minutes: 1)),
              ),
            },
            onOpenEventsForScope: (eventIds, selectedEventId) {
              openedEventIds = eventIds;
              openedSelectedEventId = selectedEventId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('live-mo-shadow-card-INC-D-3001')),
        findsOneWidget,
      );
      expect(find.text('Shadow MO Intelligence'), findsOneWidget);
      expect(
        find.textContaining('Contractors moved floor to floor in office park'),
        findsOneWidget,
      );
      expect(find.text('mo_shadow'), findsOneWidget);
      expect(find.text('Posture Weight'), findsOneWidget);
      expect(find.textContaining('weight '), findsOneWidget);

      final dossierButton = find.byKey(
        const ValueKey('live-mo-shadow-open-dossier-INC-D-3001'),
      );
      await tester.ensureVisible(dossierButton);
      await tester.tap(dossierButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('live-mo-shadow-dialog-INC-D-3001')),
        findsOneWidget,
      );
      expect(
        tester.widget<Dialog>(find.byType(Dialog).last).backgroundColor,
        const Color(0xFFFFFFFF),
      );
      expect(find.text('SHADOW MO DOSSIER'), findsOneWidget);
      expect(
        find.textContaining('Actions RAISE READINESS • PREPOSITION RESPONSE'),
        findsWidgets,
      );
      expect(find.textContaining('Strength'), findsWidgets);

      await tester.tap(find.text('OPEN EVIDENCE').last);
      await tester.pumpAndSettle();

      expect(openedEventIds, equals(const ['evt-office']));
      expect(openedSelectedEventId, 'evt-office');
    },
  );

  testWidgets('live operations shows partner progression in incident context', (
    tester,
  ) async {
    final now = _liveOperationsNowUtc();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          morningSovereignReportHistory: [
            SovereignReport(
              date: '2026-03-14',
              generatedAtUtc: _liveOperationsMorningReportGeneratedAtUtc(14),
              shiftWindowStartUtc: _liveOperationsNightShiftStartedAtUtc(13),
              shiftWindowEndUtc: _liveOperationsMorningReportGeneratedAtUtc(14),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 10,
                hashVerified: true,
                integrityScore: 99,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 1,
                humanOverrides: 0,
                overrideReasons: <String, int>{},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 1,
                driftDetected: 0,
                avgMatchScore: 100,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
              partnerProgression: SovereignReportPartnerProgression(
                dispatchCount: 1,
                declarationCount: 1,
                acceptedCount: 1,
                onSiteCount: 0,
                allClearCount: 0,
                cancelledCount: 1,
                summaryLine: '',
                scoreboardRows: [
                  SovereignReportPartnerScoreboardRow(
                    clientId: 'CLIENT-001',
                    siteId: 'SITE-SANDTON',
                    partnerLabel: 'PARTNER • Alpha',
                    dispatchCount: 1,
                    strongCount: 0,
                    onTrackCount: 0,
                    watchCount: 0,
                    criticalCount: 1,
                    averageAcceptedDelayMinutes: 12.0,
                    averageOnSiteDelayMinutes: 22.0,
                    summaryLine:
                        'Dispatches 1 • Strong 0 • On track 0 • Watch 0 • Critical 1 • Avg accept 12.0m • Avg on site 22.0m',
                  ),
                ],
              ),
            ),
            SovereignReport(
              date: '2026-03-15',
              generatedAtUtc: _liveOperationsMorningReportGeneratedAtUtc(15),
              shiftWindowStartUtc: _liveOperationsNightShiftStartedAtUtc(14),
              shiftWindowEndUtc: _liveOperationsMorningReportGeneratedAtUtc(15),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 10,
                hashVerified: true,
                integrityScore: 99,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 1,
                humanOverrides: 0,
                overrideReasons: <String, int>{},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 1,
                driftDetected: 0,
                avgMatchScore: 100,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
              partnerProgression: SovereignReportPartnerProgression(
                dispatchCount: 1,
                declarationCount: 3,
                acceptedCount: 1,
                onSiteCount: 1,
                allClearCount: 1,
                cancelledCount: 0,
                summaryLine: '',
                scoreboardRows: [
                  SovereignReportPartnerScoreboardRow(
                    clientId: 'CLIENT-001',
                    siteId: 'SITE-SANDTON',
                    partnerLabel: 'PARTNER • Alpha',
                    dispatchCount: 1,
                    strongCount: 1,
                    onTrackCount: 0,
                    watchCount: 0,
                    criticalCount: 0,
                    averageAcceptedDelayMinutes: 4.0,
                    averageOnSiteDelayMinutes: 10.0,
                    summaryLine:
                        'Dispatches 1 • Strong 1 • On track 0 • Watch 0 • Critical 0 • Avg accept 4.0m • Avg on site 10.0m',
                  ),
                ],
              ),
            ),
          ],
          events: [
            DecisionCreated(
              eventId: 'decision-1',
              sequence: 4,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 4)),
              dispatchId: 'D-1001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            PartnerDispatchStatusDeclared(
              eventId: 'partner-1',
              sequence: 3,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 3)),
              dispatchId: 'D-1001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              partnerLabel: 'PARTNER • Alpha',
              actorLabel: '@partner.alpha',
              status: PartnerDispatchStatus.accepted,
              sourceChannel: 'telegram',
              sourceMessageKey: 'tg-partner-1',
            ),
            PartnerDispatchStatusDeclared(
              eventId: 'partner-2',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              dispatchId: 'D-1001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              partnerLabel: 'PARTNER • Alpha',
              actorLabel: '@partner.alpha',
              status: PartnerDispatchStatus.onSite,
              sourceChannel: 'telegram',
              sourceMessageKey: 'tg-partner-2',
            ),
            PartnerDispatchStatusDeclared(
              eventId: 'partner-3',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 1)),
              dispatchId: 'D-1001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              partnerLabel: 'PARTNER • Alpha',
              actorLabel: '@partner.alpha',
              status: PartnerDispatchStatus.allClear,
              sourceChannel: 'telegram',
              sourceMessageKey: 'tg-partner-3',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('live-partner-progress-card-INC-D-1001')),
      findsOneWidget,
    );
    expect(find.text('Partner Progression'), findsOneWidget);
    expect(
      find.textContaining('PARTNER • Alpha • Latest ALL CLEAR'),
      findsOneWidget,
    );
    expect(find.text('Dispatch D-1001'), findsOneWidget);
    expect(find.text('3 declarations'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('live-partner-progress-INC-D-1001-accepted')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('live-partner-progress-INC-D-1001-onSite')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('live-partner-progress-INC-D-1001-allClear')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('live-partner-progress-INC-D-1001-cancelled')),
      findsOneWidget,
    );
    expect(find.textContaining('CANCEL Pending'), findsOneWidget);
    expect(find.text('7D IMPROVING • 2d'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('live-partner-trend-reason-INC-D-1001')),
      findsOneWidget,
    );
    expect(
      find.text('Acceptance timing improved against the prior 7-day average.'),
      findsOneWidget,
    );
  });

  testWidgets('live operations shows suppressed scene review queue for active site', (
    tester,
  ) async {
    final now = _liveOperationsNowUtc();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: [
            DecisionCreated(
              eventId: 'decision-1',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 4)),
              dispatchId: 'D-1001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            IntelligenceReceived(
              eventId: 'intel-suppressed',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 3)),
              intelligenceId: 'INT-SUPPRESSED-1',
              provider: 'hikvision-dvr',
              sourceType: 'dvr',
              externalId: 'evt-suppressed',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              cameraId: 'Camera 2',
              zone: 'north_gate',
              headline: 'DVR VEHICLE PASS',
              summary: 'Vehicle passed through the north gate approach lane.',
              riskScore: 41,
              canonicalHash: 'hash-suppressed',
            ),
            IntelligenceReceived(
              eventId: 'intel-latest',
              sequence: 3,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 2)),
              intelligenceId: 'INT-LATEST-1',
              provider: 'hikvision-dvr',
              sourceType: 'dvr',
              externalId: 'evt-latest',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              headline: 'DVR BOUNDARY ALERT',
              summary: 'Motion detected at boundary line',
              riskScore: 92,
              canonicalHash: 'hash-latest',
            ),
          ],
          videoOpsLabel: 'DVR',
          sceneReviewByIntelligenceId: {
            'INT-SUPPRESSED-1': MonitoringSceneReviewRecord(
              intelligenceId: 'INT-SUPPRESSED-1',
              sourceLabel: 'openai:gpt-4.1-mini',
              postureLabel: 'reviewed',
              decisionLabel: 'Suppressed',
              decisionSummary:
                  'Suppressed because the vehicle activity remained below the client notification threshold.',
              summary: 'Vehicle remained below escalation threshold.',
              reviewedAtUtc: now.subtract(const Duration(minutes: 3)),
            ),
            'INT-LATEST-1': MonitoringSceneReviewRecord(
              intelligenceId: 'INT-LATEST-1',
              sourceLabel: 'openai:gpt-4.1-mini',
              postureLabel: 'escalation candidate',
              decisionLabel: 'Escalation Candidate',
              decisionSummary:
                  'Escalated for urgent review because person activity was detected near the boundary line.',
              summary: 'Person visible near the boundary line.',
              reviewedAtUtc: now.subtract(const Duration(minutes: 2)),
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Suppressed DVR Reviews'), findsOneWidget);
    expect(find.text('1 internal'), findsOneWidget);
    expect(find.text('DVR VEHICLE PASS'), findsOneWidget);
    expect(
      find.textContaining(
        'Suppressed because the vehicle activity remained below the client notification threshold.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Scene review: Vehicle remained below escalation threshold.'),
      findsOneWidget,
    );
    expect(find.text('Camera 2'), findsOneWidget);
    expect(find.text('north_gate'), findsOneWidget);
    expect(find.text('openai:gpt-4.1-mini'), findsOneWidget);
    expect(find.text('reviewed'), findsOneWidget);
    expect(find.text('Escalation Candidate'), findsOneWidget);
  });

  testWidgets('live operations shows activity truth and opens scoped events', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2240, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = _liveOperationsNowUtc();
    List<String>? openedEventIds;
    String? openedSelectedEventId;

    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: [
            DecisionCreated(
              eventId: 'decision-activity-1',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 4)),
              dispatchId: 'D-2001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            IntelligenceReceived(
              eventId: 'ACTIVITY-7',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(hours: 3, minutes: 10)),
              intelligenceId: 'INT-ACTIVITY-7',
              provider: 'hikvision-dvr',
              sourceType: 'dvr',
              externalId: 'evt-activity-7',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              cameraId: 'gate-cam',
              objectLabel: 'person',
              headline: 'Watchlist subject detected',
              summary: 'Unauthorized person matched watchlist context.',
              riskScore: 84,
              canonicalHash: 'hash-activity-7',
            ),
            IntelligenceReceived(
              eventId: 'ACTIVITY-11',
              sequence: 3,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 40)),
              intelligenceId: 'INT-ACTIVITY-11',
              provider: 'hikvision-dvr',
              sourceType: 'dvr',
              externalId: 'evt-activity-11',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              cameraId: 'gate-cam',
              objectLabel: 'human',
              headline: 'Guard conversation observed',
              summary: 'Guard talking to unknown individual near the gate.',
              riskScore: 66,
              canonicalHash: 'hash-activity-11',
            ),
          ],
          videoOpsLabel: 'DVR',
          onOpenEventsForScope: (eventIds, selectedEventId) {
            openedEventIds = eventIds;
            openedSelectedEventId = selectedEventId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openDetailedWorkspace(tester);

    final activityTruthCard = find.byKey(
      const ValueKey('live-activity-truth-card-INC-D-2001'),
    );
    await tester.scrollUntilVisible(
      activityTruthCard,
      220,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('live-operations-details-scroll-view')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(activityTruthCard, findsOneWidget);
    expect(find.text('Activity Truth'), findsOneWidget);
    expect(find.textContaining('Signals 2 • People 2'), findsOneWidget);
    expect(find.textContaining('Long presence 1'), findsOneWidget);
    expect(find.textContaining('Guard interactions 1'), findsOneWidget);
    expect(find.textContaining('Flagged IDs 1'), findsOneWidget);
    expect(find.text('Review Refs'), findsOneWidget);
    expect(find.text('ACTIVITY-7, ACTIVITY-11'), findsOneWidget);

    final openEventsButton = find.byKey(
      const ValueKey('live-activity-truth-open-events-INC-D-2001'),
    );
    await tester.ensureVisible(openEventsButton);
    final openEventsAction = tester.widget<OutlinedButton>(openEventsButton);
    expect(openEventsAction.onPressed, isNotNull);
    openEventsAction.onPressed!();
    await tester.pumpAndSettle();

    expect(openedEventIds, equals(const ['ACTIVITY-7', 'ACTIVITY-11']));
    expect(openedSelectedEventId, 'ACTIVITY-11');
    expect(
      find.byKey(const ValueKey('live-operations-command-receipt')),
      findsOneWidget,
    );
    expect(
      find.text('Events scope warmed for activity truth.'),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('live operations shows client comms pulse for active incident', (
    tester,
  ) async {
    final now = _liveOperationsNowUtc();
    String? openedClientId;
    String? openedSiteId;
    String? clearedClientId;
    String? clearedSiteId;
    String? profiledClientId;
    String? profiledSiteId;
    String? profiledSignal;

    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: [
            DecisionCreated(
              eventId: 'decision-comms-1',
              sequence: 1,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 5)),
              dispatchId: 'D-4001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            IntelligenceReceived(
              eventId: 'intel-comms-1',
              sequence: 2,
              version: 1,
              occurredAt: now.subtract(const Duration(minutes: 4)),
              intelligenceId: 'INT-COMMS-1',
              provider: 'hikvision-dvr',
              sourceType: 'dvr',
              externalId: 'evt-comms-1',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              headline: 'Boundary concern raised',
              summary:
                  'Client Comms has become active after suspicious movement.',
              riskScore: 77,
              canonicalHash: 'hash-comms-1',
            ),
          ],
          clientCommsSnapshot: LiveClientCommsSnapshot(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            clientVoiceProfileLabel: 'Reassuring',
            learnedApprovalStyleCount: 2,
            learnedApprovalStyleExample:
                'Control is checking the latest position now and will share the next confirmed step shortly.',
            pendingLearnedStyleDraftCount: 1,
            totalMessages: 4,
            clientInboundCount: 2,
            pendingApprovalCount: 1,
            queuedPushCount: 1,
            telegramHealthLabel: 'ok',
            telegramHealthDetail:
                'Telegram delivery confirmed for the current lane.',
            pushSyncStatusLabel: 'syncing',
            smsFallbackLabel: 'SMS standby',
            smsFallbackReady: true,
            voiceReadinessLabel: 'VoIP staged',
            deliveryReadinessDetail:
                'Telegram remains primary for this scope; SMS only steps in after confirmed Telegram trouble.',
            latestSmsFallbackStatus:
                'sms:bulksms sent 2/2 after telegram blocked.',
            latestSmsFallbackAtUtc: now.subtract(const Duration(seconds: 45)),
            latestVoipStageStatus:
                'voip:asterisk staged call for Sandton Alpha.',
            latestVoipStageAtUtc: now.subtract(const Duration(seconds: 20)),
            recentDeliveryHistoryLines: const <String>[
              '12:36 UTC • voip staged • queue:1 • Asterisk staged a call for Sandton Alpha.',
              '12:35 UTC • sms fallback sent • queue:1 • BulkSMS reached 2/2 contacts after Telegram was blocked.',
            ],
            latestClientMessage:
                'Hi ONYX, just checking if the team is still on this please.',
            latestClientMessageAtUtc: now.subtract(const Duration(minutes: 2)),
            latestPendingDraft:
                'We are on it and command is checking the latest site position now.',
            latestPendingDraftAtUtc: now.subtract(const Duration(minutes: 1)),
            latestOnyxReply:
                'Control is still tracking the incident and will share the next verified update shortly.',
            latestOnyxReplyAtUtc: now.subtract(const Duration(minutes: 3)),
          ),
          onOpenClientViewForScope: (clientId, siteId) {
            openedClientId = clientId;
            openedSiteId = siteId;
          },
          onClearLearnedLaneStyleForScope: (clientId, siteId) async {
            clearedClientId = clientId;
            clearedSiteId = siteId;
          },
          onSetLaneVoiceProfileForScope:
              (clientId, siteId, profileSignal) async {
                profiledClientId = clientId;
                profiledSiteId = siteId;
                profiledSignal = profileSignal;
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('client-lane-watch-panel')),
      findsOneWidget,
    );
    expect(find.text('CLIENT COMMS WATCH'), findsOneWidget);
    expect(find.text('OPEN CLIENT COMMS'), findsWidgets);
    expect(find.text('Client Comms Pulse'), findsOneWidget);
    expect(find.text('OPEN CLIENT COMMS'), findsWidgets);
    expect(find.text('Latest Client Message'), findsOneWidget);
    expect(find.text('Pending ONYX Draft'), findsOneWidget);
    expect(find.text('Latest SMS fallback'), findsWidgets);
    expect(find.text('Latest VoIP stage'), findsWidgets);
    expect(find.text('Recent delivery history'), findsWidgets);
    expect(
      find.textContaining(
        'Hi ONYX, just checking if the team is still on this please.',
      ),
      findsWidgets,
    );
    expect(
      find.textContaining(
        'We are on it and command is checking the latest site position now.',
      ),
      findsWidgets,
    );
    expect(find.text('Telegram OK'), findsWidgets);
    expect(find.text('SMS standby'), findsWidgets);
    expect(find.text('VoIP staged'), findsWidgets);
    expect(find.text('Client voice Reassuring'), findsOneWidget);
    expect(find.text('Cue Reassurance'), findsWidgets);
    expect(find.text('Learned style 2'), findsWidgets);
    expect(find.text('ONYX using learned style'), findsWidgets);
    expect(find.text('Learned approval style'), findsWidgets);
    expect(
      find.text(
        'Lead with calm reassurance first, then the next confirmed step.',
      ),
      findsWidgets,
    );
    expect(
      find.textContaining(
        'BulkSMS reached 2/2 contacts after Telegram was blocked.',
      ),
      findsWidgets,
    );
    expect(
      find.textContaining('Asterisk staged a call for Sandton Alpha.'),
      findsWidgets,
    );
    expect(
      find.textContaining('12:36 UTC • voip staged • queue:1'),
      findsWidgets,
    );
    expect(
      find.textContaining(
        'Control is checking the latest position now and will share the next confirmed step shortly.',
      ),
      findsWidgets,
    );
    expect(find.widgetWithText(OutlinedButton, 'Concise'), findsWidgets);
    expect(find.text('Clear Learned Style'), findsWidgets);

    final conciseButton = find.widgetWithText(OutlinedButton, 'Concise').first;
    await tester.ensureVisible(conciseButton);
    await tester.tap(conciseButton);
    await tester.pumpAndSettle();

    expect(profiledClientId, 'CLIENT-001');
    expect(profiledSiteId, 'SITE-SANDTON');
    expect(profiledSignal, 'concise-updates');

    final clearLearnedStyleButton = find.byKey(
      const ValueKey(
        'client-lane-watch-clear-learned-style-CLIENT-001-SITE-SANDTON',
      ),
    );
    await tester.ensureVisible(clearLearnedStyleButton);
    await tester.tap(clearLearnedStyleButton);
    await tester.pumpAndSettle();

    expect(clearedClientId, 'CLIENT-001');
    expect(clearedSiteId, 'SITE-SANDTON');

    final openLaneButton = find.descendant(
      of: find.byKey(const ValueKey('client-lane-watch-panel')),
      matching: find.widgetWithText(OutlinedButton, 'OPEN CLIENT COMMS'),
    );
    await tester.ensureVisible(openLaneButton);
    await tester.tap(openLaneButton);
    await tester.pumpAndSettle();

    expect(openedClientId, 'CLIENT-001');
    expect(openedSiteId, 'SITE-SANDTON');
  });

  testWidgets('live operations shows control inbox drafts with quick actions', (
    tester,
  ) async {
    int? approvedUpdateId;
    int? rejectedUpdateId;
    String? openedClientId;
    String? openedSiteId;
    String? profiledClientId;
    String? profiledSiteId;
    String? profiledSignal;

    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: const [],
          controlInboxSnapshot: LiveControlInboxSnapshot(
            selectedClientId: 'CLIENT-001',
            selectedSiteId: 'SITE-SANDTON',
            selectedScopeClientVoiceProfileLabel: 'Validation-heavy',
            pendingApprovalCount: 2,
            selectedScopePendingCount: 1,
            telegramHealthLabel: 'degraded',
            telegramHealthDetail:
                'Telegram bridge is delayed, so approvals need close operator attention.',
            pendingDrafts: [
              LiveControlInboxDraft(
                updateId: 501,
                clientId: 'CLIENT-001',
                siteId: 'SITE-SANDTON',
                sourceText:
                    'Hi ONYX, are we still waiting on the patrol update?',
                draftText:
                    'We are checking the latest patrol position now and will send the next verified update shortly.',
                providerLabel: 'OpenAI',
                usesLearnedApprovalStyle: true,
                createdAtUtc: _liveOperationsControlInboxDraftCreatedAtUtc(
                  6,
                  0,
                ),
                clientVoiceProfileLabel: 'Validation-heavy',
                matchesSelectedScope: true,
              ),
              LiveControlInboxDraft(
                updateId: 502,
                clientId: 'CLIENT-VALLEE',
                siteId: 'SITE-RESIDENCE',
                sourceText:
                    'Please confirm if the response team has already arrived.',
                draftText:
                    'Command is confirming arrival now and will share the verified position as soon as it is locked.',
                providerLabel: 'OpenAI',
                createdAtUtc: _liveOperationsControlInboxDraftCreatedAtUtc(
                  5,
                  56,
                ),
                clientVoiceProfileLabel: 'Concise',
              ),
            ],
          ),
          onApproveClientReplyDraft: (updateId, {approvedText}) async {
            approvedUpdateId = updateId;
            return 'approved=$updateId';
          },
          onRejectClientReplyDraft: (updateId) async {
            rejectedUpdateId = updateId;
            return 'rejected=$updateId';
          },
          onSetLaneVoiceProfileForScope:
              (clientId, siteId, profileSignal) async {
                profiledClientId = clientId;
                profiledSiteId = siteId;
                profiledSignal = profileSignal;
              },
          onOpenClientViewForScope: (clientId, siteId) {
            openedClientId = clientId;
            openedSiteId = siteId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('control-inbox-panel')), findsOneWidget);
    expect(find.text('CONTROL INBOX'), findsOneWidget);
    expect(find.text('1 High-priority Reply'), findsWidgets);
    expect(
      find.byKey(const ValueKey('control-inbox-priority-badge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('control-inbox-queue-state-chip')),
      findsOneWidget,
    );
    expect(find.text('Queue Full'), findsWidgets);
    expect(find.text('High priority 1'), findsOneWidget);
    expect(find.textContaining('2 client replies waiting'), findsOneWidget);
    expect(find.text('Selected scope'), findsOneWidget);
    expect(find.text('Other scope'), findsOneWidget);
    expect(find.text('Client voice Validation-heavy'), findsOneWidget);
    expect(find.text('Voice Validation-heavy'), findsOneWidget);
    expect(find.text('Voice Concise'), findsOneWidget);
    expect(find.text('Cue Validation'), findsOneWidget);
    expect(find.text('Cue Timing'), findsOneWidget);
    expect(find.text('Queue shape'), findsOneWidget);
    expect(find.text('1 timing'), findsOneWidget);
    expect(find.text('1 validation'), findsOneWidget);
    expect(find.text('Voice-adjusted'), findsNWidgets(2));
    expect(find.text('Uses learned approval style'), findsOneWidget);
    expect(
      find.text(
        'Keep the exact check concrete and make sure the next confirmed step is clear before sending.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Check that timing is not over-promised before sending.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'This draft is already leaning on learned approval wording from this Client Comms flow.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Reassuring'), findsWidgets);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('control-inbox-draft-502')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('control-inbox-draft-501')))
            .dy,
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('control-inbox-priority-badge')),
    );
    await tester.tap(
      find.byKey(const ValueKey('control-inbox-priority-badge')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Queue shape'), findsOneWidget);
    expect(find.text('1 timing'), findsOneWidget);
    expect(find.text('1 validation'), findsNothing);
    expect(
      find.text(
        'Showing high-priority only. Tap the badge again to return to the full queue.',
      ),
      findsOneWidget,
    );
    expect(find.text('Queue High priority'), findsWidgets);
    expect(
      find.byKey(const ValueKey('control-inbox-filtered-chip')),
      findsOneWidget,
    );
    expect(find.text('Filtered 1'), findsWidgets);
    expect(
      find.byKey(const ValueKey('control-inbox-draft-502')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('control-inbox-draft-501')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('control-inbox-priority-badge')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Queue shape'), findsOneWidget);
    expect(find.text('1 timing'), findsOneWidget);
    expect(find.text('1 validation'), findsOneWidget);
    expect(find.text('Queue Full'), findsWidgets);
    expect(
      find.byKey(const ValueKey('control-inbox-filtered-chip')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('control-inbox-draft-501')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('control-inbox-summary-pill-timing')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Queue shape'), findsOneWidget);
    expect(find.text('1 timing'), findsOneWidget);
    expect(find.text('1 validation'), findsNothing);
    expect(
      find.byKey(const ValueKey('control-inbox-filtered-chip')),
      findsOneWidget,
    );
    expect(find.text('Filtered 1'), findsWidgets);
    expect(
      find.text(
        'Showing timing only. Tap the same pill again or use Show all replies to return to the full queue.',
      ),
      findsOneWidget,
    );
    expect(find.text('Queue Timing only'), findsWidgets);
    expect(find.byKey(const ValueKey('top-bar-cue-filter-chip')), findsWidgets);
    expect(find.text('Timing only'), findsWidgets);
    expect(
      find.byKey(const ValueKey('control-inbox-draft-502')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('control-inbox-draft-501')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('control-inbox-summary-pill-timing')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Queue shape'), findsOneWidget);
    expect(find.text('1 timing'), findsOneWidget);
    expect(find.text('1 validation'), findsOneWidget);
    expect(find.text('Queue Full'), findsWidgets);
    expect(find.byKey(const ValueKey('top-bar-cue-filter-chip')), findsNothing);
    expect(
      find.byKey(const ValueKey('control-inbox-filtered-chip')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('control-inbox-draft-501')),
      findsOneWidget,
    );

    final reassuringButton = find
        .widgetWithText(OutlinedButton, 'Reassuring')
        .first;
    await tester.ensureVisible(reassuringButton);
    await tester.tap(reassuringButton);
    await tester.pumpAndSettle();

    expect(profiledClientId, 'CLIENT-001');
    expect(profiledSiteId, 'SITE-SANDTON');
    expect(profiledSignal, 'reassurance-forward');

    final selectedDraft = find.byKey(const ValueKey('control-inbox-draft-501'));
    await tester.ensureVisible(selectedDraft);
    await tester.tap(
      find.descendant(
        of: selectedDraft,
        matching: find.widgetWithText(FilledButton, 'Approve + Send'),
      ),
    );
    await tester.pumpAndSettle();

    expect(approvedUpdateId, 501);
    expect(find.text('approved=501'), findsOneWidget);

    final otherDraft = find.byKey(const ValueKey('control-inbox-draft-502'));
    await tester.ensureVisible(otherDraft);
    await tester.tap(
      find.descendant(
        of: otherDraft,
        matching: find.widgetWithText(OutlinedButton, 'Reject'),
      ),
    );
    await tester.pumpAndSettle();

    expect(rejectedUpdateId, 502);
    expect(find.text('rejected=502'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: otherDraft,
        matching: find.widgetWithText(OutlinedButton, 'OPEN CLIENT COMMS'),
      ),
    );
    await tester.pumpAndSettle();

    expect(openedClientId, 'CLIENT-VALLEE');
    expect(openedSiteId, 'SITE-RESIDENCE');
  });

  testWidgets(
    'live operations ignores async control inbox approval completions after the page is removed',
    (tester) async {
      final approvalCompleter = Completer<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const [],
            controlInboxSnapshot: LiveControlInboxSnapshot(
              selectedClientId: 'CLIENT-001',
              selectedSiteId: 'SITE-SANDTON',
              pendingApprovalCount: 1,
              selectedScopePendingCount: 1,
              pendingDrafts: [
                LiveControlInboxDraft(
                  updateId: 501,
                  clientId: 'CLIENT-001',
                  siteId: 'SITE-SANDTON',
                  sourceText: 'Please confirm what is happening on site.',
                  draftText: 'Command is confirming the latest position now.',
                  providerLabel: 'OpenAI',
                  createdAtUtc: _liveOperationsControlInboxDraftCreatedAtUtc(
                    6,
                    0,
                  ),
                  matchesSelectedScope: true,
                ),
              ],
            ),
            onApproveClientReplyDraft: (updateId, {approvedText}) {
              return approvalCompleter.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final draftCard = find.byKey(const ValueKey('control-inbox-draft-501'));
      await tester.ensureVisible(draftCard);
      await tester.tap(
        find.descendant(
          of: draftCard,
          matching: find.widgetWithText(FilledButton, 'Approve + Send'),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();

      approvalCompleter.complete('approved=501');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'live operations shows the scoped camera preview panel for client comms watch',
    (tester) async {
      var cameraLoadCount = 0;
      Uri? openedExternalUri;
      final now = DateTime.utc(2026, 4, 3, 20, 40);

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const <DispatchEvent>[],
            clientCommsSnapshot: LiveClientCommsSnapshot(
              clientId: 'CLIENT-MS-VALLEE',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              clientVoiceProfileLabel: 'Concise',
              clientInboundCount: 1,
              latestClientMessage: 'Can you see what is happening now?',
              latestClientMessageAtUtc: now.subtract(
                const Duration(minutes: 2),
              ),
              latestOnyxReply:
                  'ONYX is checking the latest confirmed camera position now.',
              latestOnyxReplyAtUtc: now.subtract(const Duration(minutes: 1)),
              telegramHealthLabel: 'ok',
              smsFallbackLabel: 'SMS standby',
              voiceReadinessLabel: 'VoIP staged',
              pushSyncStatusLabel: 'ready',
            ),
            onOpenExternalUri: (uri) async {
              openedExternalUri = uri;
              return true;
            },
            onLoadCameraHealthFactPacketForScope: (clientId, siteId) async {
              cameraLoadCount += 1;
              return ClientCameraHealthFactPacket(
                clientId: clientId,
                siteId: siteId,
                siteReference: 'MS Vallee Residence',
                status: ClientCameraHealthStatus.live,
                reason: ClientCameraHealthReason.legacyProxyActive,
                path: ClientCameraHealthPath.legacyLocalProxy,
                lastSuccessfulVisualAtUtc: now.subtract(
                  const Duration(seconds: 20),
                ),
                lastSuccessfulUpstreamProbeAtUtc: now.subtract(
                  const Duration(seconds: 10),
                ),
                localProxyEndpoint: Uri.parse('http://127.0.0.1:11635'),
                localProxyUpstreamAlertStreamUri: Uri.parse(
                  'http://192.168.0.117/ISAPI/Event/notification/alertStream',
                ),
                localProxyReachable: true,
                localProxyRunning: true,
                localProxyUpstreamStreamConnected: true,
                localProxyBufferedAlertCount: 3,
                localProxyLastAlertAtUtc: now.subtract(
                  const Duration(seconds: 6),
                ),
                localProxyLastSuccessAtUtc: now.subtract(
                  const Duration(seconds: 5),
                ),
                currentVisualSnapshotUri: Uri.parse(
                  'http://127.0.0.1:11635/ISAPI/Streaming/channels/101/picture',
                ),
                currentVisualRelayStreamUri: Uri.parse(
                  'http://127.0.0.1:11635/onyx/live/channels/101.mjpg',
                ),
                currentVisualRelayPlayerUri: Uri.parse(
                  'http://127.0.0.1:11635/onyx/live/channels/101/player',
                ),
                currentVisualCameraId: 'channel-1',
                currentVisualVerifiedAtUtc: now.subtract(
                  const Duration(seconds: 20),
                ),
                currentVisualRelayCheckedAtUtc: now.subtract(
                  const Duration(seconds: 3),
                ),
                currentVisualRelayStatus: ClientCameraRelayStatus.active,
                currentVisualRelayLastFrameAtUtc: now.subtract(
                  const Duration(seconds: 2),
                ),
                currentVisualRelayActiveClientCount: 1,
                continuousVisualWatchStatus: 'active',
                continuousVisualWatchSummary:
                    'Continuous visual watch still sees a sustained high-priority perimeter pressure near Front Gate across 2 cameras.',
                continuousVisualWatchLastSweepAtUtc: now.subtract(
                  const Duration(seconds: 4),
                ),
                continuousVisualWatchLastCandidateAtUtc: now.subtract(
                  const Duration(minutes: 6),
                ),
                continuousVisualWatchReachableCameraCount: 3,
                continuousVisualWatchBaselineReadyCameraCount: 2,
                continuousVisualWatchHotCameraId: 'channel-11',
                continuousVisualWatchHotCameraLabel: 'Perimeter Camera 11',
                continuousVisualWatchHotZoneLabel: 'Perimeter',
                continuousVisualWatchHotAreaLabel: 'Front Gate',
                continuousVisualWatchHotWatchRuleKey: 'perimeter_watch',
                continuousVisualWatchHotWatchPriorityLabel: 'High',
                continuousVisualWatchHotCameraChangeStreakCount: 1,
                continuousVisualWatchHotCameraChangeStage: 'watching',
                continuousVisualWatchHotCameraChangeActiveSinceUtc: now
                    .subtract(const Duration(seconds: 18)),
                continuousVisualWatchHotCameraSceneDeltaScore: 0.417,
                continuousVisualWatchCorrelatedContextLabel: 'Front Gate',
                continuousVisualWatchCorrelatedAreaLabel: 'Front Gate',
                continuousVisualWatchCorrelatedZoneLabel: 'Perimeter',
                continuousVisualWatchCorrelatedWatchRuleKey: 'perimeter_watch',
                continuousVisualWatchCorrelatedWatchPriorityLabel: 'High',
                continuousVisualWatchCorrelatedChangeStage: 'sustained',
                continuousVisualWatchCorrelatedActiveSinceUtc: now.subtract(
                  const Duration(seconds: 14),
                ),
                continuousVisualWatchCorrelatedCameraCount: 2,
                continuousVisualWatchCorrelatedCameraLabels: const <String>[
                  'Front Gate Entry',
                  'Front Gate Perimeter',
                ],
                continuousVisualWatchPostureKey: 'perimeter_pressure',
                continuousVisualWatchPostureLabel: 'Perimeter pressure',
                continuousVisualWatchAttentionLabel: 'high',
                continuousVisualWatchSourceLabel: 'cross_camera',
                nextAction:
                    'Keep the legacy local Hikvision proxy on 127.0.0.1:11635 in place until the Hik-Connect credentials arrive, then switch this site to the Hik-Connect API path.',
                safeClientExplanation:
                    'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(cameraLoadCount, 1);
      expect(
        find.byKey(const ValueKey('client-lane-camera-preview-panel')),
        findsOneWidget,
      );
      expect(find.text('CURRENT CAMERA CHECK'), findsOneWidget);
      expect(find.text('REFRESH FRAME'), findsOneWidget);
      expect(find.text('COPY FRAME URL'), findsOneWidget);
      expect(find.text('COPY PLAYER URL'), findsOneWidget);
      expect(find.text('OPEN LIVE VIEW'), findsOneWidget);
      expect(find.text('OPEN STREAM PLAYER'), findsOneWidget);
      expect(find.text('PAUSE PREVIEW'), findsOneWidget);
      expect(find.textContaining('Refreshing stills every 5s'), findsOneWidget);
      expect(
        find.textContaining('visual confirmation at MS Vallee Residence'),
        findsOneWidget,
      );
      expect(find.text('Proxy CONNECTED'), findsOneWidget);
      expect(find.text('Upstream CONNECTED'), findsOneWidget);
      expect(find.text('Buffered alerts 3'), findsOneWidget);
      expect(
        find.textContaining('Current visual confirmation'),
        findsOneWidget,
      );
      expect(find.text('Relay ACTIVE'), findsWidgets);
      expect(find.text('Watch ACTIVE'), findsOneWidget);
      expect(find.text('Posture PERIMETER PRESSURE'), findsOneWidget);
      expect(find.text('Attention HIGH'), findsOneWidget);
      expect(find.text('Source CROSS-CAMERA'), findsOneWidget);
      expect(find.text('Hot Perimeter Camera 11 • Perimeter'), findsOneWidget);
      expect(find.text('Area FRONT GATE'), findsOneWidget);
      expect(find.text('Rule HIGH PRIORITY'), findsOneWidget);
      expect(find.text('Streak x1'), findsOneWidget);
      expect(find.text('Deviation WATCHING'), findsOneWidget);
      expect(find.text('Correlation FRONT GATE x2'), findsOneWidget);
      expect(find.text('Cross-camera HIGH'), findsOneWidget);
      expect(find.text('Stage SUSTAINED'), findsOneWidget);
      expect(
        find.textContaining(
          'Scoped local proxy is connected. The upstream alert stream is connected right now. 3 alerts buffered for this scope.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'actively serving frames on the temporary local bridge',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'sustained high-priority perimeter pressure near Front Gate across 2 cameras',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Watch posture: Perimeter pressure • high attention • cross-camera',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Focus camera: Perimeter Camera 11 • Front Gate • delta 42%',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Change since'), findsOneWidget);
      expect(
        find.textContaining('Cross-camera focus: Front Gate • 2 cameras'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Linked cameras: Front Gate Entry, Front Gate Perimeter.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('browser-safe player URL is ready'),
        findsOneWidget,
      );

      final toggleButton = find.byKey(
        const ValueKey(
          'client-lane-camera-toggle-CLIENT-MS-VALLEE-SITE-MS-VALLEE-RESIDENCE',
        ),
      );
      await tester.ensureVisible(toggleButton);
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(find.text('RESUME PREVIEW'), findsOneWidget);

      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(find.text('PAUSE PREVIEW'), findsOneWidget);

      final openLiveViewButton = find.byKey(
        const ValueKey(
          'client-lane-camera-open-live-CLIENT-MS-VALLEE-SITE-MS-VALLEE-RESIDENCE',
        ),
      );
      await tester.ensureVisible(openLiveViewButton);
      await tester.tap(openLiveViewButton);
      await tester.pumpAndSettle();

      expect(find.text('LIVE VIEW (REFRESHING STILLS)'), findsOneWidget);
      expect(find.text('PAUSE LIVE VIEW'), findsOneWidget);

      final dialogToggleButton = find.byKey(
        const ValueKey('client-lane-live-view-toggle'),
      );
      await tester.ensureVisible(dialogToggleButton);
      await tester.tap(dialogToggleButton);
      await tester.pumpAndSettle();
      expect(find.text('RESUME LIVE VIEW'), findsOneWidget);
      expect(find.text('OPEN STREAM PLAYER'), findsNWidgets(2));

      final dialogCloseButton = find.byKey(
        const ValueKey('client-lane-live-view-close'),
      );
      await tester.ensureVisible(dialogCloseButton);
      await tester.tap(dialogCloseButton);
      await tester.pumpAndSettle();
      expect(find.text('LIVE VIEW (REFRESHING STILLS)'), findsNothing);

      final openStreamButton = find.byKey(
        const ValueKey(
          'client-lane-camera-open-stream-CLIENT-MS-VALLEE-SITE-MS-VALLEE-RESIDENCE',
        ),
      );
      await tester.ensureVisible(openStreamButton);
      await tester.tap(openStreamButton);
      await tester.pumpAndSettle();

      expect(find.text('STREAM RELAY PLAYER'), findsOneWidget);
      expect(find.text('OPEN IN BROWSER'), findsOneWidget);
      expect(find.text('COPY PLAYER URL'), findsNWidgets(2));
      expect(find.text('Relay ACTIVE'), findsWidgets);
      expect(
        find.textContaining(
          'actively serving frames on the temporary local bridge',
        ),
        findsWidgets,
      );
      expect(
        find.textContaining('Inline stream embedding is only available'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Player URL: http://127.0.0.1:11635/onyx/live/channels/101/player',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Relay URL: http://127.0.0.1:11635/onyx/live/channels/101.mjpg',
        ),
        findsOneWidget,
      );

      final openInBrowserButton = find.byKey(
        const ValueKey('client-lane-stream-relay-open-browser'),
      );
      await tester.ensureVisible(openInBrowserButton);
      await tester.tap(openInBrowserButton);
      await tester.pumpAndSettle();

      expect(
        openedExternalUri?.toString(),
        'http://127.0.0.1:11635/onyx/live/channels/101/player',
      );

      final closeStreamRelayButton = find.byKey(
        const ValueKey('client-lane-stream-relay-close'),
      );
      await tester.ensureVisible(closeStreamRelayButton);
      await tester.tap(closeStreamRelayButton);
      await tester.pumpAndSettle();
      expect(find.text('STREAM RELAY PLAYER'), findsNothing);

      final refreshButton = find.byKey(
        const ValueKey(
          'client-lane-camera-refresh-CLIENT-MS-VALLEE-SITE-MS-VALLEE-RESIDENCE',
        ),
      );
      await tester.ensureVisible(refreshButton);
      await tester.tap(refreshButton);
      await tester.pumpAndSettle();

      expect(cameraLoadCount, greaterThanOrEqualTo(2));
    },
  );

  testWidgets(
    'live operations shows reconnecting local proxy status in the camera preview panel',
    (tester) async {
      final now = DateTime.utc(2026, 4, 3, 20, 40);

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const <DispatchEvent>[],
            clientCommsSnapshot: LiveClientCommsSnapshot(
              clientId: 'CLIENT-MS-VALLEE',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              clientVoiceProfileLabel: 'Concise',
              clientInboundCount: 1,
              latestClientMessage: 'Can you see what is happening now?',
              latestClientMessageAtUtc: now.subtract(
                const Duration(minutes: 2),
              ),
              latestOnyxReply:
                  'ONYX is checking the latest confirmed camera position now.',
              latestOnyxReplyAtUtc: now.subtract(const Duration(minutes: 1)),
              telegramHealthLabel: 'ok',
              smsFallbackLabel: 'SMS standby',
              voiceReadinessLabel: 'VoIP staged',
              pushSyncStatusLabel: 'ready',
            ),
            onLoadCameraHealthFactPacketForScope: (clientId, siteId) async {
              return ClientCameraHealthFactPacket(
                clientId: clientId,
                siteId: siteId,
                siteReference: 'MS Vallee Residence',
                status: ClientCameraHealthStatus.live,
                reason: ClientCameraHealthReason.legacyProxyActive,
                path: ClientCameraHealthPath.legacyLocalProxy,
                lastSuccessfulVisualAtUtc: now.subtract(
                  const Duration(seconds: 20),
                ),
                lastSuccessfulUpstreamProbeAtUtc: now.subtract(
                  const Duration(seconds: 10),
                ),
                localProxyEndpoint: Uri.parse('http://127.0.0.1:11635'),
                localProxyUpstreamAlertStreamUri: Uri.parse(
                  'http://192.168.0.117/ISAPI/Event/notification/alertStream',
                ),
                localProxyReachable: true,
                localProxyRunning: true,
                localProxyUpstreamStreamStatus: 'reconnecting',
                localProxyUpstreamStreamConnected: false,
                localProxyBufferedAlertCount: 2,
                localProxyLastAlertAtUtc: now.subtract(
                  const Duration(seconds: 16),
                ),
                localProxyLastSuccessAtUtc: now.subtract(
                  const Duration(seconds: 15),
                ),
                currentVisualSnapshotUri: Uri.parse(
                  'http://127.0.0.1:11635/ISAPI/Streaming/channels/101/picture',
                ),
                currentVisualVerifiedAtUtc: now.subtract(
                  const Duration(seconds: 20),
                ),
                nextAction:
                    'Keep the legacy local Hikvision proxy online while ONYX retries the upstream alert stream attachment.',
                safeClientExplanation:
                    'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('client-lane-camera-preview-panel')),
        findsOneWidget,
      );
      expect(find.text('Proxy RECONNECTING...'), findsOneWidget);
      expect(find.text('Upstream RECONNECTING...'), findsOneWidget);
      expect(find.text('Upstream CONNECTED'), findsNothing);
      expect(
        find.textContaining(
          'Scoped local proxy is reconnecting. The upstream alert stream is reconnecting right now. 2 alerts buffered for this scope.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'live operations distinguishes camera health load failure from empty state',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const <DispatchEvent>[],
            clientCommsSnapshot: LiveClientCommsSnapshot(
              clientId: 'CLIENT-MS-VALLEE',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              clientVoiceProfileLabel: 'Concise',
              clientInboundCount: 1,
              latestClientMessage: 'Can you see what is happening now?',
              latestClientMessageAtUtc: DateTime.utc(2026, 4, 3, 20, 38),
            ),
            onLoadCameraHealthFactPacketForScope: (_, _) async {
              throw StateError('camera bridge unavailable');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('client-lane-camera-preview-panel')),
        findsOneWidget,
      );
      expect(find.text('Load failed'), findsOneWidget);
      expect(
        find.textContaining('The scoped camera health check failed.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'live operations shows relay diagnostics when a current frame exists but the stream relay is unavailable',
    (tester) async {
      final now = DateTime.utc(2026, 4, 3, 20, 40);

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const <DispatchEvent>[],
            clientCommsSnapshot: LiveClientCommsSnapshot(
              clientId: 'CLIENT-MS-VALLEE',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              clientVoiceProfileLabel: 'Concise',
              clientInboundCount: 1,
              latestClientMessage: 'Can you see what is happening now?',
              latestClientMessageAtUtc: now.subtract(
                const Duration(minutes: 2),
              ),
              latestOnyxReply:
                  'ONYX is checking the latest confirmed camera position now.',
              latestOnyxReplyAtUtc: now.subtract(const Duration(minutes: 1)),
              telegramHealthLabel: 'ok',
              smsFallbackLabel: 'SMS standby',
              voiceReadinessLabel: 'VoIP staged',
              pushSyncStatusLabel: 'ready',
            ),
            onLoadCameraHealthFactPacketForScope: (clientId, siteId) async {
              return ClientCameraHealthFactPacket(
                clientId: clientId,
                siteId: siteId,
                siteReference: 'MS Vallee Residence',
                status: ClientCameraHealthStatus.live,
                reason: ClientCameraHealthReason.legacyProxyActive,
                path: ClientCameraHealthPath.legacyLocalProxy,
                lastSuccessfulVisualAtUtc: now.subtract(
                  const Duration(seconds: 20),
                ),
                lastSuccessfulUpstreamProbeAtUtc: now.subtract(
                  const Duration(seconds: 10),
                ),
                currentVisualSnapshotUri: Uri.parse(
                  'http://127.0.0.1:11635/ISAPI/Streaming/channels/101/picture',
                ),
                currentVisualCameraId: 'channel-1',
                currentVisualVerifiedAtUtc: now.subtract(
                  const Duration(seconds: 20),
                ),
                currentVisualRelayCheckedAtUtc: now.subtract(
                  const Duration(seconds: 5),
                ),
                currentVisualRelayLastError: 'Relay player HTTP 404',
                nextAction:
                    'Keep the legacy local Hikvision proxy on 127.0.0.1:11635 in place until the Hik-Connect credentials arrive, then switch this site to the Hik-Connect API path.',
                safeClientExplanation:
                    'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Stream relay unavailable'), findsOneWidget);
      expect(
        find.textContaining(
          'A current frame is verified, but the operator stream relay is not ready yet.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'The browser player endpoint returned HTTP 404 on the latest check.',
        ),
        findsOneWidget,
      );
      expect(find.text('COPY PLAYER URL'), findsNothing);
      expect(find.text('OPEN STREAM PLAYER'), findsOneWidget);
      expect(find.text('COPY FRAME URL'), findsOneWidget);
    },
  );

  testWidgets('live operations humanizes telegram bridge detail in comms view', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: const [],
          clientCommsSnapshot: LiveClientCommsSnapshot(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            telegramHealthLabel: 'blocked',
            telegramHealthDetail:
                'Telegram bridge failed for 1/1 message(s). Reasons: BLOCKED_BY_TEST_STUB',
            telegramFallbackActive: true,
            pushSyncStatusLabel: 'failed',
            latestClientMessage: 'Is Telegram still failing there?',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Telegram BLOCKED'), findsWidgets);
    expect(find.textContaining('Telegram fallback is active'), findsWidgets);
    expect(
      find.textContaining(
        'Telegram could not deliver 1/1 client update. Bridge reported: BLOCKED_BY_TEST_STUB.',
      ),
      findsWidgets,
    );
  });

  testWidgets('live operations shows live client asks before draft staging', (
    tester,
  ) async {
    String? openedClientId;
    String? openedSiteId;
    final nowUtc = _liveOperationsNowUtc();

    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: const [],
          controlInboxSnapshot: LiveControlInboxSnapshot(
            selectedClientId: 'CLIENT-001',
            selectedSiteId: 'SITE-SANDTON',
            awaitingResponseCount: 1,
            telegramHealthLabel: 'ok',
            liveClientAsks: [
              LiveControlInboxClientAsk(
                clientId: 'CLIENT-001',
                siteId: 'SITE-SANDTON',
                author: '@resident_12',
                body:
                    'Hi ONYX, can you please tell me if the patrol has arrived yet?',
                messageProvider: 'telegram',
                occurredAtUtc: nowUtc.subtract(const Duration(minutes: 2)),
                matchesSelectedScope: true,
              ),
            ],
          ),
          onOpenClientViewForScope: (clientId, siteId) {
            openedClientId = clientId;
            openedSiteId = siteId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LIVE CLIENT ASKS'), findsOneWidget);
    expect(
      find.textContaining('1 live client ask waiting for response shaping'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Hi ONYX, can you please tell me if the patrol has arrived yet?',
      ),
      findsOneWidget,
    );
    expect(find.text('Selected scope'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Shape Reply'), findsOneWidget);

    final selectedShapeReplyButton = find.widgetWithText(
      OutlinedButton,
      'Shape Reply',
    );
    await tester.ensureVisible(selectedShapeReplyButton);
    await tester.tap(selectedShapeReplyButton);
    await tester.pumpAndSettle();

    expect(openedClientId, 'CLIENT-001');
    expect(openedSiteId, 'SITE-SANDTON');
  });

  testWidgets('live operations shows other-scope client asks with lane handoff', (
    tester,
  ) async {
    String? openedClientId;
    String? openedSiteId;
    final nowUtc = _liveOperationsNowUtc();

    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: const [],
          controlInboxSnapshot: LiveControlInboxSnapshot(
            selectedClientId: 'CLIENT-001',
            selectedSiteId: 'SITE-SANDTON',
            awaitingResponseCount: 1,
            telegramHealthLabel: 'ok',
            liveClientAsks: [
              LiveControlInboxClientAsk(
                clientId: 'CLIENT-VALLEE',
                siteId: 'WTF-MAIN',
                author: '@waterfall_resident',
                body:
                    'Please confirm whether the Waterfall response team has already arrived.',
                messageProvider: 'telegram',
                occurredAtUtc: nowUtc.subtract(const Duration(minutes: 1)),
                matchesSelectedScope: false,
              ),
            ],
          ),
          onOpenClientViewForScope: (clientId, siteId) {
            openedClientId = clientId;
            openedSiteId = siteId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LIVE CLIENT ASKS'), findsOneWidget);
    expect(find.text('Other scope'), findsOneWidget);
    expect(
      find.textContaining(
        'Please confirm whether the Waterfall response team has already arrived.',
      ),
      findsOneWidget,
    );

    final offScopeShapeReplyButton = find.widgetWithText(
      OutlinedButton,
      'Shape Reply',
    );
    await tester.ensureVisible(offScopeShapeReplyButton);
    await tester.tap(offScopeShapeReplyButton);
    await tester.pumpAndSettle();

    expect(openedClientId, 'CLIENT-VALLEE');
    expect(openedSiteId, 'WTF-MAIN');
  });

  testWidgets('live operations can refine client draft before approval', (
    tester,
  ) async {
    String draftText =
        'We are checking the latest patrol position now and will send the next verified update shortly.';
    String? approvedDraftText;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return LiveOperationsPage(
              events: const [],
              controlInboxSnapshot: LiveControlInboxSnapshot(
                selectedClientId: 'CLIENT-001',
                selectedSiteId: 'SITE-SANDTON',
                pendingApprovalCount: 1,
                selectedScopePendingCount: 1,
                telegramHealthLabel: 'ok',
                pendingDrafts: [
                  LiveControlInboxDraft(
                    updateId: 501,
                    clientId: 'CLIENT-001',
                    siteId: 'SITE-SANDTON',
                    sourceText:
                        'Hi ONYX, are we still waiting on the patrol update?',
                    draftText: draftText,
                    providerLabel: 'OpenAI',
                    usesLearnedApprovalStyle: true,
                    createdAtUtc: _liveOperationsControlInboxDraftCreatedAtUtc(
                      6,
                      0,
                    ),
                    clientVoiceProfileLabel: 'Reassuring',
                    matchesSelectedScope: true,
                  ),
                ],
              ),
              onUpdateClientReplyDraftText: (updateId, nextText) async {
                setState(() {
                  draftText = nextText;
                });
              },
              onApproveClientReplyDraft:
                  (updateId, {String? approvedText}) async {
                    approvedDraftText = approvedText;
                    return 'approved=$updateId';
                  },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editDraftButton = find.widgetWithText(OutlinedButton, 'Edit Draft');
    await tester.ensureVisible(editDraftButton);
    await tester.tap(editDraftButton);
    await tester.pumpAndSettle();

    expect(
      tester.widget<AlertDialog>(find.byType(AlertDialog)).backgroundColor,
      const Color(0xFFFFFFFF),
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(
          'Lead with calm reassurance first, then the next confirmed step.',
        ),
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byType(TextField).last,
      'ETA is about 4 minutes. We will confirm arrival as soon as the team reaches Sandton.',
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(
          'Check that timing is not over-promised before sending.',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save Draft'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'ETA is about 4 minutes. We will confirm arrival as soon as the team reaches Sandton.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Approve + Send'));
    await tester.pumpAndSettle();

    expect(
      approvedDraftText,
      'ETA is about 4 minutes. We will confirm arrival as soon as the team reaches Sandton.',
    );
  });

  testWidgets('live operations top-bar priority chip jumps to control inbox', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: const [],
          clientCommsSnapshot: LiveClientCommsSnapshot(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            clientVoiceProfileLabel: 'Reassuring',
            pendingApprovalCount: 1,
            clientInboundCount: 1,
            latestClientMessage:
                'Hi ONYX, are we still waiting on the patrol update?',
            latestPendingDraft:
                'We are checking the latest patrol position now and will send the next verified update shortly.',
            telegramHealthLabel: 'ok',
            smsFallbackLabel: 'SMS standby',
            voiceReadinessLabel: 'VoIP staged',
          ),
          controlInboxSnapshot: LiveControlInboxSnapshot(
            selectedClientId: 'CLIENT-001',
            selectedSiteId: 'SITE-SANDTON',
            selectedScopeClientVoiceProfileLabel: 'Validation-heavy',
            pendingApprovalCount: 2,
            selectedScopePendingCount: 1,
            telegramHealthLabel: 'degraded',
            pendingDrafts: [
              LiveControlInboxDraft(
                updateId: 502,
                clientId: 'CLIENT-VALLEE',
                siteId: 'SITE-RESIDENCE',
                sourceText:
                    'Please confirm if the response team has already arrived.',
                draftText:
                    'Command is confirming arrival now and will share the verified position as soon as it is locked.',
                providerLabel: 'OpenAI',
                createdAtUtc: _liveOperationsControlInboxDraftCreatedAtUtc(
                  5,
                  56,
                ),
                clientVoiceProfileLabel: 'Concise',
              ),
              LiveControlInboxDraft(
                updateId: 501,
                clientId: 'CLIENT-001',
                siteId: 'SITE-SANDTON',
                sourceText:
                    'Hi ONYX, are we still waiting on the patrol update?',
                draftText:
                    'We are checking the latest patrol position now and will send the next verified update shortly.',
                providerLabel: 'OpenAI',
                createdAtUtc: _liveOperationsControlInboxDraftCreatedAtUtc(
                  6,
                  0,
                ),
                clientVoiceProfileLabel: 'Validation-heavy',
                matchesSelectedScope: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final controlInboxPanel = find.byKey(const ValueKey('control-inbox-panel'));
    expect(tester.getTopLeft(controlInboxPanel).dy, greaterThan(320));
    expect(
      find.byKey(const ValueKey('top-bar-queue-state-chip')),
      findsWidgets,
    );
    expect(find.text('Queue Full'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('top-bar-priority-chip')).first);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(controlInboxPanel).dy, lessThan(320));
    expect(find.text('Queue High priority'), findsWidgets);
    expect(find.text('Queue shape'), findsOneWidget);
    expect(find.text('1 timing'), findsOneWidget);
    expect(
      find.text(
        'Showing high-priority only. Tap the badge again to return to the full queue.',
      ),
      findsOneWidget,
    );
    expect(find.text('Show all replies (1)'), findsWidgets);
    expect(find.byKey(const ValueKey('control-inbox-draft-501')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('top-bar-show-all-chip')).first);
    await tester.pumpAndSettle();

    expect(find.text('Queue Full'), findsWidgets);
    expect(find.text('Queue shape'), findsOneWidget);
    expect(find.text('1 timing'), findsOneWidget);
    expect(find.text('1 validation'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('control-inbox-draft-501')),
      findsOneWidget,
    );
  });

  testWidgets('live operations control inbox queue-state chip cycles queue modes', (
    tester,
  ) async {
    String? profiledClientId;
    String? profiledSiteId;
    String? profiledSignal;

    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: const [],
          clientCommsSnapshot: LiveClientCommsSnapshot(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            clientVoiceProfileLabel: 'Validation-heavy',
            pendingApprovalCount: 1,
            clientInboundCount: 1,
            latestClientMessage:
                'Hi ONYX, are we still waiting on the patrol update?',
            latestPendingDraft:
                'We are checking the latest patrol position now and will send the next verified update shortly.',
            telegramHealthLabel: 'ok',
            smsFallbackLabel: 'SMS standby',
            voiceReadinessLabel: 'VoIP staged',
          ),
          controlInboxSnapshot: LiveControlInboxSnapshot(
            selectedClientId: 'CLIENT-001',
            selectedSiteId: 'SITE-SANDTON',
            selectedScopeClientVoiceProfileLabel: 'Validation-heavy',
            pendingApprovalCount: 2,
            selectedScopePendingCount: 1,
            telegramHealthLabel: 'degraded',
            pendingDrafts: [
              LiveControlInboxDraft(
                updateId: 502,
                clientId: 'CLIENT-VALLEE',
                siteId: 'SITE-RESIDENCE',
                sourceText:
                    'Please confirm if the response team has already arrived.',
                draftText:
                    'Command is confirming arrival now and will share the verified position as soon as it is locked.',
                providerLabel: 'OpenAI',
                createdAtUtc: _liveOperationsControlInboxDraftCreatedAtUtc(
                  5,
                  56,
                ),
                clientVoiceProfileLabel: 'Concise',
              ),
              LiveControlInboxDraft(
                updateId: 501,
                clientId: 'CLIENT-001',
                siteId: 'SITE-SANDTON',
                sourceText:
                    'Hi ONYX, are we still waiting on the patrol update?',
                draftText:
                    'We are checking the latest patrol position now and will send the next verified update shortly.',
                providerLabel: 'OpenAI',
                createdAtUtc: _liveOperationsControlInboxDraftCreatedAtUtc(
                  6,
                  0,
                ),
                clientVoiceProfileLabel: 'Validation-heavy',
                usesLearnedApprovalStyle: true,
                matchesSelectedScope: true,
              ),
            ],
          ),
          onSetLaneVoiceProfileForScope:
              (clientId, siteId, profileSignal) async {
                profiledClientId = clientId;
                profiledSiteId = siteId;
                profiledSignal = profileSignal;
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final queueStateChip = find.byKey(
      const ValueKey('control-inbox-queue-state-chip'),
    );
    expect(queueStateChip, findsOneWidget);
    expect(find.text('Queue Full'), findsWidgets);
    expect(
      find.descendant(
        of: queueStateChip,
        matching: find.byIcon(Icons.inbox_rounded),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(queueStateChip);
    await tester.tap(queueStateChip);
    await tester.pumpAndSettle();

    expect(find.text('Queue High priority'), findsWidgets);
    expect(
      find.descendant(
        of: queueStateChip,
        matching: find.byIcon(Icons.priority_high_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('control-inbox-filtered-chip')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('control-inbox-draft-502')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('control-inbox-draft-501')), findsNothing);

    await tester.tap(queueStateChip);
    await tester.pumpAndSettle();

    expect(find.text('Queue Full'), findsWidgets);
    expect(
      find.byKey(const ValueKey('control-inbox-filtered-chip')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('control-inbox-draft-501')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('control-inbox-summary-pill-timing')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Queue Timing only'), findsWidgets);
    expect(
      find.descendant(
        of: queueStateChip,
        matching: find.byIcon(Icons.schedule_rounded),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('control-inbox-draft-501')), findsNothing);

    await tester.tap(queueStateChip);
    await tester.pumpAndSettle();

    expect(find.text('Queue High priority'), findsWidgets);
    expect(find.byKey(const ValueKey('top-bar-cue-filter-chip')), findsNothing);
    expect(
      find.byKey(const ValueKey('control-inbox-draft-502')),
      findsOneWidget,
    );

    await tester.tap(queueStateChip);
    await tester.pumpAndSettle();

    expect(find.text('Queue Full'), findsWidgets);
    expect(
      find.byKey(const ValueKey('control-inbox-filtered-chip')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('control-inbox-draft-501')),
      findsOneWidget,
    );

    expect(profiledClientId, isNull);
    expect(profiledSiteId, isNull);
    expect(profiledSignal, isNull);
  });

  testWidgets('live operations shows queue-state first-run hint until queue interaction', (
    tester,
  ) async {
    LiveOperationsPage.debugResetQueueStateHintSession();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: const [],
          clientCommsSnapshot: LiveClientCommsSnapshot(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            clientVoiceProfileLabel: 'Validation-heavy',
            pendingApprovalCount: 1,
            clientInboundCount: 1,
            latestClientMessage:
                'Hi ONYX, are we still waiting on the patrol update?',
            latestPendingDraft:
                'We are checking the latest patrol position now and will send the next verified update shortly.',
            telegramHealthLabel: 'ok',
            smsFallbackLabel: 'SMS standby',
            voiceReadinessLabel: 'VoIP staged',
          ),
          controlInboxSnapshot: LiveControlInboxSnapshot(
            selectedClientId: 'CLIENT-001',
            selectedSiteId: 'SITE-SANDTON',
            selectedScopeClientVoiceProfileLabel: 'Validation-heavy',
            pendingApprovalCount: 2,
            selectedScopePendingCount: 1,
            telegramHealthLabel: 'degraded',
            pendingDrafts: [
              LiveControlInboxDraft(
                updateId: 502,
                clientId: 'CLIENT-VALLEE',
                siteId: 'SITE-RESIDENCE',
                sourceText:
                    'Please confirm if the response team has already arrived.',
                draftText:
                    'Command is confirming arrival now and will share the verified position as soon as it is locked.',
                providerLabel: 'OpenAI',
                createdAtUtc: _liveOperationsControlInboxDraftCreatedAtUtc(
                  5,
                  56,
                ),
                clientVoiceProfileLabel: 'Concise',
              ),
              LiveControlInboxDraft(
                updateId: 501,
                clientId: 'CLIENT-001',
                siteId: 'SITE-SANDTON',
                sourceText:
                    'Hi ONYX, are we still waiting on the patrol update?',
                draftText:
                    'We are checking the latest patrol position now and will send the next verified update shortly.',
                providerLabel: 'OpenAI',
                createdAtUtc: _liveOperationsControlInboxDraftCreatedAtUtc(
                  6,
                  0,
                ),
                clientVoiceProfileLabel: 'Validation-heavy',
                matchesSelectedScope: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('control-inbox-queue-hint')),
      findsOneWidget,
    );
    expect(find.text('Hide tip'), findsOneWidget);

    final queueStateChip = find.byKey(
      const ValueKey('control-inbox-queue-state-chip'),
    );
    await tester.ensureVisible(queueStateChip);
    await tester.tap(queueStateChip);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('control-inbox-queue-hint')),
      findsNothing,
    );
    expect(find.text('Queue High priority'), findsWidgets);

    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: const [],
          clientCommsSnapshot: LiveClientCommsSnapshot(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            clientVoiceProfileLabel: 'Validation-heavy',
            pendingApprovalCount: 1,
            clientInboundCount: 1,
            latestClientMessage:
                'Hi ONYX, are we still waiting on the patrol update?',
            latestPendingDraft:
                'We are checking the latest patrol position now and will send the next verified update shortly.',
            telegramHealthLabel: 'ok',
            smsFallbackLabel: 'SMS standby',
            voiceReadinessLabel: 'VoIP staged',
          ),
          controlInboxSnapshot: LiveControlInboxSnapshot(
            selectedClientId: 'CLIENT-001',
            selectedSiteId: 'SITE-SANDTON',
            selectedScopeClientVoiceProfileLabel: 'Validation-heavy',
            pendingApprovalCount: 2,
            selectedScopePendingCount: 1,
            telegramHealthLabel: 'degraded',
            pendingDrafts: [
              LiveControlInboxDraft(
                updateId: 502,
                clientId: 'CLIENT-VALLEE',
                siteId: 'SITE-RESIDENCE',
                sourceText:
                    'Please confirm if the response team has already arrived.',
                draftText:
                    'Command is confirming arrival now and will share the verified position as soon as it is locked.',
                providerLabel: 'OpenAI',
                createdAtUtc: _liveOperationsControlInboxDraftCreatedAtUtc(
                  5,
                  56,
                ),
                clientVoiceProfileLabel: 'Concise',
              ),
              LiveControlInboxDraft(
                updateId: 501,
                clientId: 'CLIENT-001',
                siteId: 'SITE-SANDTON',
                sourceText:
                    'Hi ONYX, are we still waiting on the patrol update?',
                draftText:
                    'We are checking the latest patrol position now and will send the next verified update shortly.',
                providerLabel: 'OpenAI',
                createdAtUtc: _liveOperationsControlInboxDraftCreatedAtUtc(
                  6,
                  0,
                ),
                clientVoiceProfileLabel: 'Validation-heavy',
                matchesSelectedScope: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('control-inbox-queue-hint')),
      findsNothing,
    );
  });

  testWidgets('live operations can show the queue hint again after hiding it', (
    tester,
  ) async {
    LiveOperationsPage.debugResetQueueStateHintSession();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: const [],
          clientCommsSnapshot: LiveClientCommsSnapshot(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            clientVoiceProfileLabel: 'Validation-heavy',
            pendingApprovalCount: 1,
            clientInboundCount: 1,
            latestClientMessage:
                'Hi ONYX, are we still waiting on the patrol update?',
            latestPendingDraft:
                'We are checking the latest patrol position now and will send the next verified update shortly.',
            telegramHealthLabel: 'ok',
            smsFallbackLabel: 'SMS standby',
            voiceReadinessLabel: 'VoIP staged',
          ),
          controlInboxSnapshot: LiveControlInboxSnapshot(
            selectedClientId: 'CLIENT-001',
            selectedSiteId: 'SITE-SANDTON',
            selectedScopeClientVoiceProfileLabel: 'Validation-heavy',
            pendingApprovalCount: 2,
            selectedScopePendingCount: 1,
            telegramHealthLabel: 'degraded',
            pendingDrafts: [
              LiveControlInboxDraft(
                updateId: 502,
                clientId: 'CLIENT-VALLEE',
                siteId: 'SITE-RESIDENCE',
                sourceText:
                    'Please confirm if the response team has already arrived.',
                draftText:
                    'Command is confirming arrival now and will share the verified position as soon as it is locked.',
                providerLabel: 'OpenAI',
                createdAtUtc: _liveOperationsControlInboxDraftCreatedAtUtc(
                  5,
                  56,
                ),
                clientVoiceProfileLabel: 'Concise',
              ),
              LiveControlInboxDraft(
                updateId: 501,
                clientId: 'CLIENT-001',
                siteId: 'SITE-SANDTON',
                sourceText:
                    'Hi ONYX, are we still waiting on the patrol update?',
                draftText:
                    'We are checking the latest patrol position now and will send the next verified update shortly.',
                providerLabel: 'OpenAI',
                createdAtUtc: _liveOperationsControlInboxDraftCreatedAtUtc(
                  6,
                  0,
                ),
                clientVoiceProfileLabel: 'Validation-heavy',
                matchesSelectedScope: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final queueStateChip = find.byKey(
      const ValueKey('control-inbox-queue-state-chip'),
    );
    await tester.ensureVisible(queueStateChip);
    await tester.tap(queueStateChip);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('control-inbox-queue-hint')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('control-inbox-show-queue-hint')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('control-inbox-show-queue-hint')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('control-inbox-queue-hint')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('control-inbox-show-queue-hint')),
      findsNothing,
    );
  });

  testWidgets('live operations queue-state chips explain queue modes on long press', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOperationsPage(
          events: const [],
          clientCommsSnapshot: LiveClientCommsSnapshot(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            clientVoiceProfileLabel: 'Validation-heavy',
            pendingApprovalCount: 1,
            clientInboundCount: 1,
            latestClientMessage:
                'Hi ONYX, are we still waiting on the patrol update?',
            latestPendingDraft:
                'We are checking the latest patrol position now and will send the next verified update shortly.',
            telegramHealthLabel: 'ok',
            smsFallbackLabel: 'SMS standby',
            voiceReadinessLabel: 'VoIP staged',
          ),
          controlInboxSnapshot: LiveControlInboxSnapshot(
            selectedClientId: 'CLIENT-001',
            selectedSiteId: 'SITE-SANDTON',
            selectedScopeClientVoiceProfileLabel: 'Validation-heavy',
            pendingApprovalCount: 2,
            selectedScopePendingCount: 1,
            telegramHealthLabel: 'degraded',
            pendingDrafts: [
              LiveControlInboxDraft(
                updateId: 502,
                clientId: 'CLIENT-VALLEE',
                siteId: 'SITE-RESIDENCE',
                sourceText:
                    'Please confirm if the response team has already arrived.',
                draftText:
                    'Command is confirming arrival now and will share the verified position as soon as it is locked.',
                providerLabel: 'OpenAI',
                createdAtUtc: _liveOperationsControlInboxDraftCreatedAtUtc(
                  5,
                  56,
                ),
                clientVoiceProfileLabel: 'Concise',
              ),
              LiveControlInboxDraft(
                updateId: 501,
                clientId: 'CLIENT-001',
                siteId: 'SITE-SANDTON',
                sourceText:
                    'Hi ONYX, are we still waiting on the patrol update?',
                draftText:
                    'We are checking the latest patrol position now and will send the next verified update shortly.',
                providerLabel: 'OpenAI',
                createdAtUtc: _liveOperationsControlInboxDraftCreatedAtUtc(
                  6,
                  0,
                ),
                clientVoiceProfileLabel: 'Validation-heavy',
                matchesSelectedScope: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final queueStateChip = find.byKey(
      const ValueKey('control-inbox-queue-state-chip'),
    );

    await tester.ensureVisible(queueStateChip);
    await tester.longPress(queueStateChip);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Queue Full is showing every pending reply. Tap to narrow the inbox to the high-priority queue.',
      ),
      findsOneWidget,
    );

    await tester.tap(queueStateChip);
    await tester.pumpAndSettle();

    await tester.longPress(queueStateChip);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Queue High priority is showing only sensitive and timing replies. Tap to return to the full queue.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'live operations top-bar cue filter chip widens priority filters and jumps to control inbox',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const [],
            clientCommsSnapshot: LiveClientCommsSnapshot(
              clientId: 'CLIENT-001',
              siteId: 'SITE-SANDTON',
              clientVoiceProfileLabel: 'Reassuring',
              pendingApprovalCount: 1,
              clientInboundCount: 1,
              latestClientMessage:
                  'Hi ONYX, are we still waiting on the patrol update?',
              latestPendingDraft:
                  'We are checking the latest patrol position now and will send the next verified update shortly.',
              telegramHealthLabel: 'ok',
              smsFallbackLabel: 'SMS standby',
              voiceReadinessLabel: 'VoIP staged',
            ),
            controlInboxSnapshot: LiveControlInboxSnapshot(
              selectedClientId: 'CLIENT-001',
              selectedSiteId: 'SITE-SANDTON',
              selectedScopeClientVoiceProfileLabel: 'Validation-heavy',
              pendingApprovalCount: 2,
              selectedScopePendingCount: 1,
              telegramHealthLabel: 'degraded',
              pendingDrafts: [
                LiveControlInboxDraft(
                  updateId: 502,
                  clientId: 'CLIENT-VALLEE',
                  siteId: 'SITE-RESIDENCE',
                  sourceText:
                      'Please confirm if the response team has already arrived.',
                  draftText:
                      'Command is confirming arrival now and will share the verified position as soon as it is locked.',
                  providerLabel: 'OpenAI',
                  createdAtUtc: _liveOperationsControlInboxDraftCreatedAtUtc(
                    5,
                    56,
                  ),
                  clientVoiceProfileLabel: 'Concise',
                ),
                LiveControlInboxDraft(
                  updateId: 501,
                  clientId: 'CLIENT-001',
                  siteId: 'SITE-SANDTON',
                  sourceText:
                      'Hi ONYX, are we still waiting on the patrol update?',
                  draftText:
                      'We are checking the latest patrol position now and will send the next verified update shortly.',
                  providerLabel: 'OpenAI',
                  createdAtUtc: _liveOperationsControlInboxDraftCreatedAtUtc(
                    6,
                    0,
                  ),
                  clientVoiceProfileLabel: 'Validation-heavy',
                  matchesSelectedScope: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final controlInboxPanel = find.byKey(
        const ValueKey('control-inbox-panel'),
      );
      expect(tester.getTopLeft(controlInboxPanel).dy, greaterThan(300));

      await tester.tap(
        find.byKey(const ValueKey('top-bar-priority-chip')).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('control-inbox-summary-pill-timing')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Queue Timing only'), findsWidgets);
      expect(find.text('Timing only'), findsWidgets);
      expect(
        find.text(
          'Showing timing only. Tap the same pill again or use Show all replies to return to the full queue.',
        ),
        findsOneWidget,
      );

      final topBarCueChip = find
          .byKey(const ValueKey('top-bar-cue-filter-chip'))
          .first;
      await tester.ensureVisible(topBarCueChip);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 260));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(controlInboxPanel).dy, greaterThan(300));

      await tester.tap(topBarCueChip);
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(controlInboxPanel).dy, lessThan(320));
      expect(find.text('Queue High priority'), findsWidgets);
      expect(
        find.byKey(const ValueKey('top-bar-cue-filter-chip')),
        findsNothing,
      );
      expect(find.text('Show all replies (1)'), findsWidgets);
      expect(
        find.text(
          'Showing high-priority only. Tap the badge again to return to the full queue.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('control-inbox-draft-501')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('control-inbox-draft-502')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('top-bar-priority-chip')).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Queue Full'), findsWidgets);
      expect(find.text('1 validation'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('control-inbox-draft-501')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'live operations top-bar priority chip turns red for sensitive drafts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const [],
            controlInboxSnapshot: LiveControlInboxSnapshot(
              selectedClientId: 'CLIENT-001',
              selectedSiteId: 'SITE-SANDTON',
              pendingApprovalCount: 1,
              selectedScopePendingCount: 1,
              telegramHealthLabel: 'degraded',
              pendingDrafts: [
                LiveControlInboxDraft(
                  updateId: 503,
                  clientId: 'CLIENT-001',
                  siteId: 'SITE-SANDTON',
                  sourceText: 'Fire alarm triggered. Is everyone safe?',
                  draftText:
                      'We are treating this as active and checking the fire response now.',
                  providerLabel: 'OpenAI',
                  createdAtUtc: _liveOperationsControlInboxDraftCreatedAtUtc(
                    6,
                    5,
                  ),
                  clientVoiceProfileLabel: 'Reassuring',
                  matchesSelectedScope: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final priorityChip = tester.widget<Container>(
        find.byKey(const ValueKey('top-bar-priority-chip')).first,
      );
      final decoration = priorityChip.decoration! as BoxDecoration;

      expect(find.text('1 Sensitive Reply'), findsWidgets);
      expect(find.text('1 sensitive'), findsOneWidget);
      expect(decoration.color, const Color(0x33EF4444));
      expect(decoration.border, isNotNull);
      expect((decoration.border! as Border).top.color, const Color(0x66EF4444));
    },
  );

  testWidgets(
    'live operations control inbox badge says sensitive for sensitive drafts',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOperationsPage(
            events: const [],
            controlInboxSnapshot: LiveControlInboxSnapshot(
              selectedClientId: 'CLIENT-001',
              selectedSiteId: 'SITE-SANDTON',
              pendingApprovalCount: 1,
              selectedScopePendingCount: 1,
              telegramHealthLabel: 'degraded',
              pendingDrafts: [
                LiveControlInboxDraft(
                  updateId: 503,
                  clientId: 'CLIENT-001',
                  siteId: 'SITE-SANDTON',
                  sourceText: 'Fire alarm triggered. Is everyone safe?',
                  draftText:
                      'We are treating this as active and checking the fire response now.',
                  providerLabel: 'OpenAI',
                  createdAtUtc: _liveOperationsControlInboxDraftCreatedAtUtc(
                    6,
                    5,
                  ),
                  clientVoiceProfileLabel: 'Reassuring',
                  matchesSelectedScope: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('control-inbox-priority-badge')),
        findsOneWidget,
      );
      expect(find.text('Sensitive 1'), findsOneWidget);
      expect(find.text('1 sensitive'), findsOneWidget);
    },
  );
}
