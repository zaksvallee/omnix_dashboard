import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/ui/sites_command_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void expectInkWellDisabled(WidgetTester tester, Finder finder) {
    final button = tester.widget<InkWell>(finder);
    expect(button.onTap, isNull);
  }

  testWidgets('sites command action chips are interactive', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var addSiteTapped = 0;
    String? mappedSiteId;
    String? settingsSiteId;
    String? rosterSiteName;

    await tester.pumpWidget(
      MaterialApp(
        home: SitesCommandPage(
          events: const <DispatchEvent>[],
          onAddSite: () {
            addSiteTapped += 1;
          },
          onOpenMapForSite: (siteId, siteName) {
            mappedSiteId = siteId;
          },
          onOpenSiteSettings: (siteId, siteName) {
            settingsSiteId = siteId;
          },
          onOpenGuardRoster: (siteId, siteName) {
            rosterSiteName = siteName;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addSite = find.text('ADD SITE').first;
    await tester.ensureVisible(addSite);
    await tester.tap(addSite, warnIfMissed: false);
    await tester.pump();
    expect(addSiteTapped, 1);

    final viewOnMap = find.text('VIEW ON MAP').first;
    await tester.ensureVisible(viewOnMap);
    await tester.tap(viewOnMap, warnIfMissed: false);
    await tester.pump();
    expect(mappedSiteId, isNotNull);

    final siteSettings = find.text('SITE SETTINGS').first;
    await tester.ensureVisible(siteSettings);
    await tester.tap(siteSettings, warnIfMissed: false);
    await tester.pump();
    expect(settingsSiteId, isNotNull);

    final guardRoster = find.text('GUARD ROSTER').first;
    await tester.ensureVisible(guardRoster);
    await tester.tap(guardRoster, warnIfMissed: false);
    await tester.pump();
    expect(rosterSiteName, isNotNull);
  });

  testWidgets('sites command action chips disable when callbacks are absent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: SitesCommandPage(events: <DispatchEvent>[]),
      ),
    );
    await tester.pumpAndSettle();

    expectInkWellDisabled(
      tester,
      find.byKey(const ValueKey('sites-add-site-button')),
    );
    expectInkWellDisabled(
      tester,
      find.byKey(const ValueKey('sites-view-on-map-button')).first,
    );
    expectInkWellDisabled(
      tester,
      find.byKey(const ValueKey('sites-site-settings-button')).first,
    );
    expectInkWellDisabled(
      tester,
      find.byKey(const ValueKey('sites-guard-roster-button')).first,
    );
  });

  testWidgets('sites command hero tactical action opens selected site map', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? mappedSiteId;

    await tester.pumpWidget(
      MaterialApp(
        home: SitesCommandPage(
          events: const <DispatchEvent>[],
          onOpenMapForSite: (siteId, siteName) {
            mappedSiteId = siteId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sites-view-tactical-button')));
    await tester.pumpAndSettle();

    expect(mappedSiteId, isNotNull);
  });

  testWidgets('sites command hero tactical action shows helper dialog fallback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: SitesCommandPage(events: <DispatchEvent>[]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sites-view-tactical-button')));
    await tester.pumpAndSettle();

    expect(find.text('Tactical Link Ready'), findsOneWidget);
    expect(
      find.textContaining('watch posture, limited coverage'),
      findsOneWidget,
    );
  });
}
