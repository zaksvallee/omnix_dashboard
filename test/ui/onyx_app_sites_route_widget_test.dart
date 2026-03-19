import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/admin_page.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/guards_page.dart';
import 'package:omnix_dashboard/ui/tactical_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onyx app opens tactical from sites hero action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.sites,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sites-view-tactical-button')));
    await tester.pumpAndSettle();

    expect(find.byType(TacticalPage), findsOneWidget);
  });

  testWidgets('onyx app opens admin sites tab from sites settings action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.sites,
      ),
    );
    await tester.pumpAndSettle();

    final settingsButton = find.byKey(
      const ValueKey('sites-site-settings-button'),
    );
    await tester.ensureVisible(settingsButton);
    await tester.tap(settingsButton);
    await tester.pumpAndSettle();

    expect(find.byType(AdministrationPage), findsOneWidget);
    expect(find.text('Administration Console'), findsOneWidget);
    expect(find.text('Sites'), findsWidgets);
  });

  testWidgets('onyx app opens guards roster from sites workspace action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.sites,
      ),
    );
    await tester.pumpAndSettle();

    final guardRosterButton = find.byKey(
      const ValueKey('sites-guard-roster-button'),
    );
    await tester.ensureVisible(guardRosterButton);
    await tester.tap(guardRosterButton);
    await tester.pumpAndSettle();

    expect(find.byType(GuardsPage), findsOneWidget);
    expect(find.text('Guards & Workforce'), findsOneWidget);
    expect(find.text('Active Guards'), findsOneWidget);
  });

  testWidgets('onyx app opens admin sites tab from add site action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.sites,
      ),
    );
    await tester.pumpAndSettle();

    final addSiteButton = find.byKey(const ValueKey('sites-add-site-button'));
    await tester.ensureVisible(addSiteButton);
    await tester.tap(addSiteButton);
    await tester.pumpAndSettle();

    expect(find.byType(AdministrationPage), findsOneWidget);
    expect(find.text('Administration Console'), findsOneWidget);
    expect(find.text('Sites'), findsWidgets);
  });
}
