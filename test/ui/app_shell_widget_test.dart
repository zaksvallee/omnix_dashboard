import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/ui/app_shell.dart';

void main() {
  testWidgets('AppShell uses drawer navigation on mobile widths', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    OnyxRoute? selectedRoute;
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          currentRoute: OnyxRoute.dashboard,
          onRouteChanged: (route) => selectedRoute = route,
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Events'), findsOneWidget);
    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();

    expect(selectedRoute, OnyxRoute.events);
  });

  testWidgets('AppShell uses drawer navigation on landscape phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          currentRoute: OnyxRoute.dashboard,
          onRouteChanged: (_) {},
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });

  testWidgets('AppShell renders command shell chrome on desktop layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          currentRoute: OnyxRoute.dashboard,
          onRouteChanged: (_) {},
          activeIncidentCount: 12,
          aiActionCount: 7,
          guardsOnlineCount: 9,
          complianceIssuesCount: 4,
          tacticalSosAlerts: 2,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('COMMAND'), findsOneWidget);
    expect(find.text('SYSTEMS NOMINAL'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('7 ACTIVE'), findsOneWidget);
    expect(find.text('9 On Shift'), findsOneWidget);
  });

  testWidgets('AppShell renders dynamic sidebar badges and shell top bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2100, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          currentRoute: OnyxRoute.dashboard,
          onRouteChanged: (_) {},
          activeIncidentCount: 41,
          aiActionCount: 37,
          guardsOnlineCount: 29,
          complianceIssuesCount: 23,
          tacticalSosAlerts: 19,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('COMMAND'), findsOneWidget);
    expect(find.text('SYSTEMS NOMINAL'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('app-shell-quick-jump-field')),
      findsOneWidget,
    );
    expect(find.text('41'), findsOneWidget);
    expect(find.text('37'), findsOneWidget);
    expect(find.text('23'), findsOneWidget);
    expect(find.text('19'), findsOneWidget);
  });

  testWidgets('AppShell shows the active operator session chip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          currentRoute: OnyxRoute.dashboard,
          onRouteChanged: (_) {},
          operatorLabel: 'Emily Davis',
          operatorRoleLabel: 'Admin',
          operatorShiftLabel: '0h 1m',
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Emily Davis'), findsOneWidget);
    expect(find.text('ADMIN'), findsOneWidget);
    expect(find.text('Shift: 0h 1m'), findsOneWidget);
  });

  testWidgets('AppShell renders intel ticker entries on desktop layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          currentRoute: OnyxRoute.aiQueue,
          onRouteChanged: (_) {},
          intelTickerItems: [
            OnyxIntelTickerItem(
              id: 'INT-1',
              sourceType: 'radio',
              provider: 'zello',
              headline: 'All clear confirmed on north gate channel',
              occurredAtUtc: DateTime.utc(2026, 3, 11, 10, 14),
            ),
            OnyxIntelTickerItem(
              id: 'INT-2',
              sourceType: 'hardware',
              provider: 'hikvision',
              headline: 'Perimeter line-crossing alert camera CAM-22',
              occurredAtUtc: DateTime.utc(2026, 3, 11, 10, 15),
            ),
          ],
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('RADIO • zello'), findsOneWidget);
    expect(
      find.text('All clear confirmed on north gate channel'),
      findsOneWidget,
    );
    expect(find.textContaining('HARDWARE • hikvision'), findsOneWidget);
  });

  testWidgets('AppShell filters intel ticker entries by source', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          currentRoute: OnyxRoute.aiQueue,
          onRouteChanged: (_) {},
          intelTickerItems: [
            OnyxIntelTickerItem(
              id: 'INT-N-1',
              sourceType: 'news',
              provider: 'newsapi.org',
              headline: 'Regional protest planned near Sandton',
              occurredAtUtc: DateTime.utc(2026, 3, 11, 10, 10),
            ),
            OnyxIntelTickerItem(
              id: 'INT-H-1',
              sourceType: 'hardware',
              provider: 'hikvision',
              headline: 'Perimeter line crossing CAM-22',
              occurredAtUtc: DateTime.utc(2026, 3, 11, 10, 12),
            ),
            OnyxIntelTickerItem(
              id: 'INT-R-1',
              sourceType: 'radio',
              provider: 'zello',
              headline: 'Control room acknowledged all clear',
              occurredAtUtc: DateTime.utc(2026, 3, 11, 10, 14),
            ),
          ],
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ALL • 3'), findsOneWidget);
    expect(find.text('NEWS • 1'), findsOneWidget);
    expect(find.text('CCTV • 1'), findsOneWidget);
    expect(find.text('RADIO • 1'), findsOneWidget);

    await tester.tap(find.text('NEWS • 1'));
    await tester.pumpAndSettle();

    expect(find.text('Regional protest planned near Sandton'), findsOneWidget);
    expect(find.text('Perimeter line crossing CAM-22'), findsNothing);
    expect(find.text('Control room acknowledged all clear'), findsNothing);
  });

  testWidgets('AppShell exposes a dedicated DVR source chip and filter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          currentRoute: OnyxRoute.aiQueue,
          onRouteChanged: (_) {},
          intelTickerItems: [
            OnyxIntelTickerItem(
              id: 'INT-D-1',
              sourceType: 'dvr',
              provider: 'hikvision-dvr',
              headline: 'Vehicle detected at loading bay',
              occurredAtUtc: DateTime.utc(2026, 3, 11, 10, 16),
            ),
            OnyxIntelTickerItem(
              id: 'INT-H-1',
              sourceType: 'hardware',
              provider: 'frigate',
              headline: 'Perimeter line crossing CAM-22',
              occurredAtUtc: DateTime.utc(2026, 3, 11, 10, 12),
            ),
          ],
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DVR • 1'), findsOneWidget);
    expect(find.text('CCTV • 1'), findsOneWidget);

    await tester.tap(find.text('DVR • 1'));
    await tester.pumpAndSettle();

    expect(find.text('Vehicle detected at loading bay'), findsOneWidget);
    expect(find.text('Perimeter line crossing CAM-22'), findsNothing);
  });

  testWidgets('AppShell emits ticker tap callback with selected item', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    OnyxIntelTickerItem? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          currentRoute: OnyxRoute.aiQueue,
          onRouteChanged: (_) {},
          onIntelTickerTap: (item) => tapped = item,
          intelTickerItems: [
            OnyxIntelTickerItem(
              id: 'INT-N-2',
              sourceType: 'news',
              provider: 'newsapi.org',
              headline: 'New threat advisory issued',
              occurredAtUtc: DateTime.utc(2026, 3, 11, 11, 14),
            ),
          ],
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New threat advisory issued'));
    await tester.pumpAndSettle();

    expect(tapped, isNotNull);
    expect(tapped!.id, 'INT-N-2');
    expect(tapped!.sourceType, 'news');
  });

  testWidgets('AppShell quick jump opens route picker and navigates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1680, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    OnyxRoute? selectedRoute;
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          currentRoute: OnyxRoute.dashboard,
          onRouteChanged: (route) => selectedRoute = route,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('app-shell-quick-jump-field')));
    await tester.pumpAndSettle();

    expect(find.text('Quick jump'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('app-shell-quick-jump-input')),
      'OB Log',
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(InkWell, 'OB Log'),
      ),
    );
    await tester.pumpAndSettle();

    expect(selectedRoute, OnyxRoute.ledger);
  });

  testWidgets(
    'AppShell exposes compact quick jump when the full field is hidden',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      OnyxRoute? selectedRoute;
      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            currentRoute: OnyxRoute.dashboard,
            onRouteChanged: (route) => selectedRoute = route,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('app-shell-quick-jump-field')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('app-shell-quick-jump-icon')));
      await tester.pumpAndSettle();

      expect(find.text('Quick jump'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('app-shell-quick-jump-input')),
        'Admin',
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.widgetWithText(InkWell, 'Admin'),
        ),
      );
      await tester.pumpAndSettle();

      expect(selectedRoute, OnyxRoute.admin);
    },
  );

  testWidgets('AppShell status button shows the live summary snack', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1680, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          currentRoute: OnyxRoute.dashboard,
          onRouteChanged: (_) {},
          activeIncidentCount: 5,
          aiActionCount: 2,
          guardsOnlineCount: 7,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('app-shell-status-button')));
    await tester.pump();

    expect(
      find.text(
        'Systems nominal. 5 active incidents, 2 AI actions, 7 guards online.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('AppShell opens quick jump with Meta+K', (tester) async {
    tester.view.physicalSize = const Size(2100, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          currentRoute: OnyxRoute.dashboard,
          onRouteChanged: (_) {},
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    expect(find.text('Quick jump'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('app-shell-quick-jump-input')),
      findsOneWidget,
    );
  });

  testWidgets('AppShell opens quick jump with Control+K', (tester) async {
    tester.view.physicalSize = const Size(2100, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          currentRoute: OnyxRoute.dashboard,
          onRouteChanged: (_) {},
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.text('Quick jump'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('app-shell-quick-jump-input')),
      findsOneWidget,
    );
  });
}
