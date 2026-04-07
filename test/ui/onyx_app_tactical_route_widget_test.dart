import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnix_dashboard/application/dvr_scope_config.dart';
import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/dispatch_page.dart';
import 'package:omnix_dashboard/ui/onyx_agent_page.dart';
import 'package:omnix_dashboard/ui/tactical_page.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_sections.dart';

import 'support/watch_drilldown_route_test_harness.dart';

Future<void> openDetailedWorkspaceIfVisible(WidgetTester tester) async {
  if (find
      .byKey(const ValueKey('tactical-workspace-panel-map'))
      .evaluate()
      .isNotEmpty) {
    return;
  }
  final toggle = find.byKey(
    const ValueKey('tactical-toggle-detailed-workspace'),
  );
  if (toggle.evaluate().isEmpty) {
    return;
  }
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

DateTime _tacticalRouteScenarioBaseUtc() =>
    DateTime.now().toUtc().subtract(const Duration(minutes: 20));

DateTime _tacticalScenarioOccurredAtUtc(int minute) =>
    _tacticalRouteScenarioBaseUtc().add(Duration(minutes: minute));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onyx app keeps track overview on compact desktop shell widths', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.tactical),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('track-live-map-board')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tactical-workspace-panel-map')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('tactical-toggle-detailed-workspace')),
      findsOneWidget,
    );
  });

  testWidgets('onyx app keeps track overview on narrow desktop shell widths', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1120, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.tactical),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('track-live-map-board')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tactical-workspace-panel-map')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('tactical-toggle-detailed-workspace')),
      findsOneWidget,
    );
  });

  testWidgets(
    'onyx app opens the modern tactical workspace on standard desktop shell widths',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.tactical),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('track-live-map-board')),
        findsOneWidget,
      );

      await openDetailedWorkspaceIfVisible(tester);

      expect(
        find.byKey(const ValueKey('tactical-workspace-panel-map')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tactical-workspace-panel-context')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('track-live-map-board')), findsNothing);
    },
  );

  testWidgets('onyx app opens agent from tactical command hero', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.tactical,
        dvrScopeConfigsOverride: [
          DvrScopeConfig(
            clientId: 'CLIENT-MS-VALLEE',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            provider: 'monitor_only_dvr',
            eventsUri: Uri.parse('https://edge.example.com/events'),
            authMode: 'bearer',
            username: '',
            password: '',
            bearerToken: 'token',
          ),
        ],
        initialStoreEventsOverride: <DispatchEvent>[
          DecisionCreated(
            eventId: 'decision-track-hero',
            sequence: 1,
            version: 1,
            occurredAt: _tacticalScenarioOccurredAtUtc(10),
            dispatchId: 'DSP-TRACK-77',
            clientId: 'CLIENT-MS-VALLEE',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
          ),
          IntelligenceReceived(
            eventId: 'intel-track-hero',
            sequence: 2,
            version: 1,
            occurredAt: _tacticalScenarioOccurredAtUtc(11),
            intelligenceId: 'INC-TRACK-77',
            sourceType: 'dvr',
            provider: 'monitor_only_dvr',
            externalId: 'evt-track-hero',
            riskScore: 79,
            headline: 'Track handoff route',
            summary:
                'Tactical command should escalate the active scoped incident into Agent.',
            clientId: 'CLIENT-MS-VALLEE',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            canonicalHash: 'canon-track-hero',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await openDetailedWorkspaceIfVisible(tester);

    final askAgentButton = find.byKey(
      const ValueKey('tactical-open-agent-button'),
    );
    await tester.ensureVisible(askAgentButton);
    await tester.tap(askAgentButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(OnyxAgentPage), findsOneWidget);
    expect(find.text('Junior Analyst'), findsOneWidget);
    expect(
      tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).sourceRouteLabel,
      'Track',
    );
    expect(
      tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).scopeClientId,
      'CLIENT-MS-VALLEE',
    );
    expect(
      tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).scopeSiteId,
      'SITE-MS-VALLEE-RESIDENCE',
    );
    expect(
      tester
          .widget<OnyxAgentPage>(find.byType(OnyxAgentPage))
          .focusIncidentReference,
      'INC-TRACK-77',
    );
  });

  testWidgets('onyx app opens dispatches from tactical map focus action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.tactical,
        dvrScopeConfigsOverride: [
          DvrScopeConfig(
            clientId: 'CLIENT-MS-VALLEE',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            provider: 'monitor_only_dvr',
            eventsUri: Uri.parse('https://edge.example.com/events'),
            authMode: 'bearer',
            username: '',
            password: '',
            bearerToken: 'token',
          ),
        ],
        initialStoreEventsOverride: <DispatchEvent>[
          DecisionCreated(
            eventId: 'decision-track-dispatch-map',
            sequence: 1,
            version: 1,
            occurredAt: _tacticalScenarioOccurredAtUtc(10),
            dispatchId: 'DSP-TRACK-66',
            clientId: 'CLIENT-MS-VALLEE',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
          ),
          IntelligenceReceived(
            eventId: 'intel-track-dispatch-map',
            sequence: 2,
            version: 1,
            occurredAt: _tacticalScenarioOccurredAtUtc(11),
            intelligenceId: 'INC-TRACK-66',
            sourceType: 'dvr',
            provider: 'monitor_only_dvr',
            externalId: 'evt-track-dispatch-map',
            riskScore: 79,
            headline: 'Track dispatch map route',
            summary:
                'Detailed tactical map focus should hand the scoped incident into dispatches.',
            clientId: 'CLIENT-MS-VALLEE',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            canonicalHash: 'canon-track-dispatch-map',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await openDetailedWorkspaceIfVisible(tester);

    final openDispatchesButton = find.byKey(
      const ValueKey('tactical-map-focus-open-dispatches'),
    );
    await tester.ensureVisible(openDispatchesButton);
    await tester.tap(openDispatchesButton);
    await tester.pumpAndSettle();

    expect(find.byType(DispatchPage), findsOneWidget);
    expect(find.text('Dispatch Board'), findsOneWidget);
    expect(
      tester
          .widget<DispatchPage>(find.byType(DispatchPage))
          .focusIncidentReference,
      'INC-TRACK-66',
    );
  });

  testWidgets('onyx app resumes track directly from the agent header', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.tactical,
        dvrScopeConfigsOverride: [
          DvrScopeConfig(
            clientId: 'CLIENT-MS-VALLEE',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            provider: 'monitor_only_dvr',
            eventsUri: Uri.parse('https://edge.example.com/events'),
            authMode: 'bearer',
            username: '',
            password: '',
            bearerToken: 'token',
          ),
        ],
        initialStoreEventsOverride: <DispatchEvent>[
          DecisionCreated(
            eventId: 'decision-track-resume',
            sequence: 1,
            version: 1,
            occurredAt: _tacticalScenarioOccurredAtUtc(12),
            dispatchId: 'DSP-TRACK-88',
            clientId: 'CLIENT-MS-VALLEE',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
          ),
          IntelligenceReceived(
            eventId: 'intel-track-resume',
            sequence: 2,
            version: 1,
            occurredAt: _tacticalScenarioOccurredAtUtc(13),
            intelligenceId: 'INC-TRACK-88',
            sourceType: 'dvr',
            provider: 'monitor_only_dvr',
            externalId: 'evt-track-resume',
            riskScore: 81,
            headline: 'Track resume route',
            summary:
                'The Agent header should resume the same tactical incident.',
            clientId: 'CLIENT-MS-VALLEE',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            canonicalHash: 'canon-track-resume',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await openDetailedWorkspaceIfVisible(tester);

    final askAgentButton = find.byKey(
      const ValueKey('tactical-open-agent-button'),
    );
    await tester.ensureVisible(askAgentButton);
    await tester.tap(askAgentButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(OnyxAgentPage), findsOneWidget);
    expect(
      tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).sourceRouteLabel,
      'Track',
    );
    expect(
      tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).scopeClientId,
      'CLIENT-MS-VALLEE',
    );
    expect(
      tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).scopeSiteId,
      'SITE-MS-VALLEE-RESIDENCE',
    );
    expect(
      tester
          .widget<OnyxAgentPage>(find.byType(OnyxAgentPage))
          .focusIncidentReference,
      'INC-TRACK-88',
    );

    final resumeTrackButton = find.byKey(
      const ValueKey('onyx-agent-resume-track-button'),
    );
    await tester.ensureVisible(resumeTrackButton);
    await tester.tap(resumeTrackButton);
    await tester.pumpAndSettle();

    await openDetailedWorkspaceIfVisible(tester);

    expect(find.byType(TacticalPage), findsOneWidget);
    expect(find.text('AGENT RETURN'), findsOneWidget);
    expect(
      tester
          .widget<TacticalPage>(find.byType(TacticalPage))
          .focusIncidentReference,
      'INC-TRACK-88',
    );
  });

  testWidgets('onyx app returns from agent into the focused tactical board', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.tactical,
        dvrScopeConfigsOverride: [
          DvrScopeConfig(
            clientId: 'CLIENT-MS-VALLEE',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            provider: 'monitor_only_dvr',
            eventsUri: Uri.parse('https://edge.example.com/events'),
            authMode: 'bearer',
            username: '',
            password: '',
            bearerToken: 'token',
          ),
        ],
        initialStoreEventsOverride: <DispatchEvent>[
          DecisionCreated(
            eventId: 'decision-track-return',
            sequence: 1,
            version: 1,
            occurredAt: _tacticalScenarioOccurredAtUtc(15),
            dispatchId: 'DSP-TRACK-90',
            clientId: 'CLIENT-MS-VALLEE',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
          ),
          IntelligenceReceived(
            eventId: 'intel-track-return',
            sequence: 2,
            version: 1,
            occurredAt: _tacticalScenarioOccurredAtUtc(16),
            intelligenceId: 'INC-TRACK-90',
            sourceType: 'dvr',
            provider: 'monitor_only_dvr',
            externalId: 'evt-track-return',
            riskScore: 83,
            headline: 'Track return route',
            summary:
                'Agent should return the controller to the same tactical focus.',
            clientId: 'CLIENT-MS-VALLEE',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            canonicalHash: 'canon-track-return',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await openDetailedWorkspaceIfVisible(tester);
    final initialTacticalPage = tester.widget<TacticalPage>(
      find.byType(TacticalPage),
    );
    final expectedIncidentReference =
        initialTacticalPage.focusIncidentReference.trim().isEmpty
        ? 'INC-TRACK-90'
        : initialTacticalPage.focusIncidentReference.trim();

    final askAgentButton = find.byKey(
      const ValueKey('tactical-open-agent-button'),
    );
    await tester.ensureVisible(askAgentButton);
    await tester.tap(askAgentButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(OnyxAgentPage), findsOneWidget);
    expect(
      tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).sourceRouteLabel,
      'Track',
    );
    expect(
      tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).scopeClientId,
      'CLIENT-MS-VALLEE',
    );
    expect(
      tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).scopeSiteId,
      'SITE-MS-VALLEE-RESIDENCE',
    );
    expect(
      tester
          .widget<OnyxAgentPage>(find.byType(OnyxAgentPage))
          .focusIncidentReference,
      expectedIncidentReference,
    );

    await tester.enterText(
      find.byKey(const ValueKey('onyx-agent-composer-field')),
      'Review telemetry posture for the active incident',
    );
    await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final messageListScrollable = find.descendant(
      of: find.byKey(const ValueKey('onyx-agent-message-list')),
      matching: find.byType(Scrollable),
    );
    final reopenTrackAction = find.byKey(
      const ValueKey('onyx-agent-action-telemetry-open-track'),
    );
    await tester.scrollUntilVisible(
      reopenTrackAction,
      220,
      scrollable: messageListScrollable,
    );
    final reopenTrackButton = tester.widget<OutlinedButton>(reopenTrackAction);
    expect(reopenTrackButton.onPressed, isNotNull);
    reopenTrackButton.onPressed!.call();
    await tester.pumpAndSettle();
    await openDetailedWorkspaceIfVisible(tester);

    expect(find.byType(TacticalPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tactical-workspace-command-receipt')),
      findsOneWidget,
    );
    expect(find.text('AGENT RETURN'), findsOneWidget);
    expect(find.textContaining('Returned from Agent'), findsOneWidget);
    expect(
      tester
          .widget<TacticalPage>(find.byType(TacticalPage))
          .focusIncidentReference,
      expectedIncidentReference,
    );
    expect(
      tester
          .widget<TacticalPage>(find.byType(TacticalPage))
          .initialScopeClientId,
      'CLIENT-MS-VALLEE',
    );
    expect(
      tester.widget<TacticalPage>(find.byType(TacticalPage)).initialScopeSiteId,
      'SITE-MS-VALLEE-RESIDENCE',
    );
  });

  testWidgets(
    'onyx app restores limited watch drilldown into tactical after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTacticalWatchActionDrilldown(
        VideoFleetWatchActionDrilldown.limited,
      );
      await seedValleeLimitedWatchRuntime(persistence: persistence);

      await pumpValleeWatchDrilldownRouteApp(tester, route: OnyxRoute.tactical);

      await openDetailedWorkspaceIfVisible(tester);

      await tester.scrollUntilVisible(
        find.text('Focused watch action: Limited watch coverage'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Focused watch action: Limited watch coverage'),
        findsOneWidget,
      );
    },
  );

  testWidgets('onyx app keeps tactical watch drilldown cleared after restart', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final persistence = await DispatchPersistenceService.create();
    await persistence.saveTacticalWatchActionDrilldown(
      VideoFleetWatchActionDrilldown.limited,
    );
    await seedValleeLimitedWatchRuntime(persistence: persistence);

    await pumpValleeWatchDrilldownRouteApp(
      tester,
      route: OnyxRoute.tactical,
      key: const ValueKey('tactical-clear-limited-source-app'),
    );

    await openDetailedWorkspaceIfVisible(tester);

    await tester.scrollUntilVisible(
      find.text('Focused watch action: Limited watch coverage'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Focused watch action: Limited watch coverage'),
      findsOneWidget,
    );

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(
      find.text('Focused watch action: Limited watch coverage'),
      findsNothing,
    );

    await pumpValleeWatchDrilldownRouteApp(
      tester,
      route: OnyxRoute.tactical,
      key: const ValueKey('tactical-clear-limited-restart-app'),
    );

    await openDetailedWorkspaceIfVisible(tester);

    expect(
      find.text('Focused watch action: Limited watch coverage'),
      findsNothing,
    );
  });

  testWidgets(
    'onyx app persists tactical watch drilldown replacement after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTacticalWatchActionDrilldown(
        VideoFleetWatchActionDrilldown.limited,
      );
      await seedValleeLimitedWatchRuntime(
        persistence: persistence,
        alertCount: 1,
      );

      await pumpValleeWatchDrilldownRouteApp(
        tester,
        route: OnyxRoute.tactical,
        key: const ValueKey('tactical-replace-watch-action-source-app'),
      );

      await openDetailedWorkspaceIfVisible(tester);

      await tester.scrollUntilVisible(
        find.text('Focused watch action: Limited watch coverage'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Focused watch action: Limited watch coverage'),
        findsOneWidget,
      );

      final alertsChip = find.byKey(
        const ValueKey('tactical-fleet-summary-tile-alerts'),
      );
      await tester.ensureVisible(alertsChip);
      final alertsButton = find.descendant(
        of: alertsChip,
        matching: find.byType(InkWell),
      );
      expect(alertsButton, findsOneWidget);
      await tester.tap(alertsButton);
      await tester.pumpAndSettle();

      expect(find.text('Focused watch action: Alert actions'), findsOneWidget);

      await pumpValleeWatchDrilldownRouteApp(
        tester,
        route: OnyxRoute.tactical,
        key: const ValueKey('tactical-replace-watch-action-restart-app'),
      );

      await openDetailedWorkspaceIfVisible(tester);

      await tester.scrollUntilVisible(
        find.text('Focused watch action: Alert actions'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Focused watch action: Alert actions'), findsOneWidget);
      expect(
        find.text('Focused watch action: Limited watch coverage'),
        findsNothing,
      );
    },
  );
}
