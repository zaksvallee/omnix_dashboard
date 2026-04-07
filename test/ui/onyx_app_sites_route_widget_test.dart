import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/admin_page.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/guards_page.dart';
import 'package:omnix_dashboard/ui/sovereign_ledger_page.dart';
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
    expect(
      tester.widget<TacticalPage>(find.byType(TacticalPage)).initialScopeClientId,
      'CLIENT-MS-VALLEE',
    );
    expect(
      tester.widget<TacticalPage>(find.byType(TacticalPage)).initialScopeSiteId,
      'SITE-MS-VALLEE-RESIDENCE',
    );
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
    expect(
      tester
          .widget<AdministrationPage>(find.byType(AdministrationPage))
          .initialTab,
      AdministrationPageTab.sites,
    );
    expect(find.text('Administration'), findsOneWidget);
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
    expect(find.text('Active Now'), findsOneWidget);
    expect(
      tester.widget<GuardsPage>(find.byType(GuardsPage)).initialSiteFilter,
      'Ms Vallee Residence',
    );
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
    expect(
      tester
          .widget<AdministrationPage>(find.byType(AdministrationPage))
          .initialTab,
      AdministrationPageTab.sites,
    );
    expect(find.text('Administration'), findsOneWidget);
    expect(find.text('Sites'), findsWidgets);
  });

  testWidgets(
    'onyx app reopens guards warm from signed sites roster evidence',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.ledger,
          initialPinnedLedgerAuditEntryOverride:
              SovereignLedgerPinnedAuditEntry(
                auditId: 'SITES-AUDIT-GUARDS-1',
                clientId: 'CLIENT-MS-VALLEE',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
                recordCode: 'OB-AUDIT',
                title: 'Guard roster opened from Sites.',
                description:
                    'Opened guard roster for Ms Vallee Residence from Sites.',
                occurredAt: DateTime.utc(2026, 3, 27, 22, 45),
                actorLabel: 'Control-1',
                sourceLabel: 'Sites War Room',
                hash: 'sitesguardhash1',
                previousHash: 'sitesguardprev1',
                accent: const Color(0xFF63E6A1),
                payload: const <String, Object?>{
                  'type': 'sites_auto_audit',
                  'action': 'site_guard_roster_opened',
                  'site_id': 'SITE-MS-VALLEE-RESIDENCE',
                  'site_name': 'Ms Vallee Residence',
                },
              ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sovereign Ledger'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('ledger-entry-open-sites-action')),
      );
      await tester.tap(find.byKey(const ValueKey('ledger-entry-open-sites-action')));
      await tester.pumpAndSettle();

      expect(find.byType(GuardsPage), findsOneWidget);
      expect(
        tester.widget<GuardsPage>(find.byType(GuardsPage)).initialSiteFilter,
        'Ms Vallee Residence',
      );
      expect(
        find.byKey(const ValueKey('guards-evidence-return-banner')),
        findsOneWidget,
      );
      expect(find.text('EVIDENCE RETURN'), findsOneWidget);
      expect(
        find.text('Returned to Guard Roster for Ms Vallee Residence.'),
        findsOneWidget,
      );
    },
  );
}
