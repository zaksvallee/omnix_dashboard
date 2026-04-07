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

    final addSite = find.text('OPEN SITE DESK').first;
    await tester.ensureVisible(addSite);
    await tester.tap(addSite, warnIfMissed: false);
    await tester.pump();
    expect(addSiteTapped, 1);

    final viewOnMap = find.text('OPEN SITE MAP').first;
    await tester.ensureVisible(viewOnMap);
    await tester.tap(viewOnMap, warnIfMissed: false);
    await tester.pump();
    expect(mappedSiteId, isNotNull);

    final siteSettings = find.text('OPEN SITE SETTINGS').first;
    await tester.ensureVisible(siteSettings);
    await tester.tap(siteSettings, warnIfMissed: false);
    await tester.pump();
    expect(settingsSiteId, isNotNull);

    final guardRoster = find.text('OPEN GUARD ROSTER').first;
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
      const MaterialApp(home: SitesCommandPage(events: <DispatchEvent>[])),
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

  testWidgets(
    'sites command hero tactical action shows helper dialog fallback',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: SitesCommandPage(events: <DispatchEvent>[])),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('sites-view-tactical-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Site Map Ready'), findsOneWidget);
      expect(
        find.textContaining('watch posture, limited coverage'),
        findsOneWidget,
      );
    },
  );

  testWidgets('sites command lane filters and workspace tabs change the body', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? mappedSiteId;
    String? rosterSiteName;

    await tester.pumpWidget(
      MaterialApp(
        home: SitesCommandPage(
          events: const <DispatchEvent>[],
          onOpenMapForSite: (siteId, siteName) {
            mappedSiteId = siteId;
          },
          onOpenGuardRoster: (siteId, siteName) {
            rosterSiteName = siteName;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('sites-workspace-status-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('sites-workspace-panel-response')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('sites-roster-filter-watch')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('sites-roster-card-SITE-003')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('sites-roster-card-SITE-001')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('sites-workspace-view-coverage')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('sites-workspace-panel-coverage')),
      findsOneWidget,
    );
    expect(find.text('COVERAGE GRID'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sites-view-on-map-button')));
    await tester.pumpAndSettle();

    expect(mappedSiteId, 'SITE-003');

    await tester.tap(find.byKey(const ValueKey('sites-guard-roster-button')));
    await tester.pumpAndSettle();

    expect(rosterSiteName, 'Blue Ridge Security');

    await tester.tap(
      find.byKey(const ValueKey('sites-workspace-view-checkpoints')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('sites-workspace-panel-checkpoints')),
      findsOneWidget,
    );
    expect(find.text('CHECKPOINT BOARD'), findsOneWidget);
  });

  testWidgets('sites command shows latest auto-audit receipt and opens audit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var openedLatestAudit = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SitesCommandPage(
          events: const <DispatchEvent>[],
          latestAutoAuditReceipt: const SitesAutoAuditReceipt(
            auditId: 'SITES-AUDIT-1',
            label: 'AUTO-AUDIT',
            headline: 'Sites action signed automatically.',
            detail:
                'Opened site settings for Meridian Tower. • hash 1234567890',
            accent: Color(0xFF63E6A1),
          ),
          onOpenLatestAudit: () {
            openedLatestAudit = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('sites-latest-audit-panel')),
      findsOneWidget,
    );
    expect(find.text('Sites action signed automatically.'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('sites-view-latest-audit-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('sites-view-latest-audit-button')),
    );
    await tester.pumpAndSettle();

    expect(openedLatestAudit, isTrue);
  });
}
