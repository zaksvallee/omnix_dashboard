import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_sections.dart';

import 'support/watch_drilldown_route_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onyx app restores limited watch drilldown into dispatch after restart', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final persistence = await DispatchPersistenceService.create();
    await persistence.saveDispatchWatchActionDrilldown(
      VideoFleetWatchActionDrilldown.limited,
    );
    await seedValleeLimitedWatchRuntime(persistence: persistence);

    await pumpValleeWatchDrilldownRouteApp(
      tester,
      route: OnyxRoute.dispatches,
    );

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
  });

  testWidgets(
    'onyx app keeps dispatch watch drilldown cleared after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveDispatchWatchActionDrilldown(
        VideoFleetWatchActionDrilldown.limited,
      );
      await seedValleeLimitedWatchRuntime(persistence: persistence);

      await pumpValleeWatchDrilldownRouteApp(
        tester,
        route: OnyxRoute.dispatches,
        key: const ValueKey('dispatch-clear-limited-source-app'),
      );

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
        route: OnyxRoute.dispatches,
        key: const ValueKey('dispatch-clear-limited-restart-app'),
      );

      expect(
        find.text('Focused watch action: Limited watch coverage'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'onyx app persists dispatch watch drilldown replacement after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveDispatchWatchActionDrilldown(
        VideoFleetWatchActionDrilldown.alerts,
      );
      await seedValleeLimitedWatchRuntime(
        persistence: persistence,
        alertCount: 1,
      );

      await pumpValleeWatchDrilldownRouteApp(
        tester,
        route: OnyxRoute.dispatches,
        key: const ValueKey('dispatch-replace-watch-action-source-app'),
      );

      await tester.scrollUntilVisible(
        find.text('Focused watch action: Alert actions'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Focused watch action: Alert actions'), findsOneWidget);

      await tester.tap(find.text('Limited 1'));
      await tester.pumpAndSettle();

      expect(
        find.text('Focused watch action: Limited watch coverage'),
        findsOneWidget,
      );

      await pumpValleeWatchDrilldownRouteApp(
        tester,
        route: OnyxRoute.dispatches,
        key: const ValueKey('dispatch-replace-watch-action-restart-app'),
      );

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
      expect(find.text('Focused watch action: Alert actions'), findsNothing);
    },
  );

  testWidgets('onyx app opens scoped reports from cleared dispatch action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? openedDispatchId;
    String? openedClientId;
    String? openedSiteId;

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.dispatches,
        onDispatchReportRouteOpened: (dispatchId, clientId, siteId) {
          openedDispatchId = dispatchId;
          openedClientId = clientId;
          openedSiteId = siteId;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DISPATCH COMMAND'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'VIEW REPORT').first);
    await tester.pumpAndSettle();

    expect(openedDispatchId, 'DSP-4');
    expect(openedClientId, 'CLIENT-MS-VALLEE');
    expect(openedSiteId, 'SITE-MS-VALLEE-RESIDENCE');
  });

  testWidgets('onyx app opens scoped reports from dispatch hero action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? openedDispatchId;
    String? openedClientId;
    String? openedSiteId;

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.dispatches,
        onDispatchReportRouteOpened: (dispatchId, clientId, siteId) {
          openedDispatchId = dispatchId;
          openedClientId = clientId;
          openedSiteId = siteId;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dispatch-open-report-button')));
    await tester.pumpAndSettle();

    expect(openedDispatchId, 'DSP-4');
    expect(openedClientId, 'CLIENT-MS-VALLEE');
    expect(openedSiteId, 'SITE-MS-VALLEE-RESIDENCE');
  });

  testWidgets('onyx app routes generate dispatch through shell callback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var generateTriggeredCount = 0;

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.dispatches,
        onDispatchGenerateTriggered: () {
          generateTriggeredCount += 1;
        },
      ),
    );
    await tester.pumpAndSettle();

    final generateButton = find.widgetWithText(
      FilledButton,
      'Generate Dispatch',
    );
    await tester.ensureVisible(generateButton);
    await tester.tap(generateButton);
    await tester.pumpAndSettle();

    expect(generateTriggeredCount, 1);
  });

  testWidgets('onyx app derives dispatch scope from incident route seed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? openedClientId;
    String? openedSiteId;
    String? openedFocusReference;

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.dispatches,
        initialDispatchIncidentReferenceOverride: 'DSP-4',
        onDispatchRouteOpened: (clientId, siteId, focusReference) {
          openedClientId = clientId;
          openedSiteId = siteId;
          openedFocusReference = focusReference;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DISPATCH COMMAND'), findsOneWidget);
    expect(openedClientId, 'CLIENT-MS-VALLEE');
    expect(openedSiteId, 'SITE-MS-VALLEE-RESIDENCE');
    expect(openedFocusReference, 'DSP-4');
    expect(find.textContaining('Focus Linked: DSP-4'), findsOneWidget);
  });
}
