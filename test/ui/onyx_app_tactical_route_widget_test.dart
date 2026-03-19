import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_sections.dart';

import 'support/watch_drilldown_route_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onyx app restores limited watch drilldown into tactical after restart', (
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
    'onyx app keeps tactical watch drilldown cleared after restart',
    (tester) async {
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

      expect(
        find.text('Focused watch action: Limited watch coverage'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'onyx app persists tactical watch drilldown replacement after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveTacticalWatchActionDrilldown(
        VideoFleetWatchActionDrilldown.alerts,
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

      await tester.scrollUntilVisible(
        find.text('Focused watch action: Alert actions'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Focused watch action: Alert actions'), findsOneWidget);

      await tester.tap(find.text('Limited • 1'));
      await tester.pumpAndSettle();

      expect(
        find.text('Focused watch action: Limited watch coverage'),
        findsOneWidget,
      );

      await pumpValleeWatchDrilldownRouteApp(
        tester,
        route: OnyxRoute.tactical,
        key: const ValueKey('tactical-replace-watch-action-restart-app'),
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
}
