import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/ui/guards_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('guards page stays stable on phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: GuardsPage(events: <DispatchEvent>[])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guards & Workforce'), findsOneWidget);
    expect(find.text('Active Guards'), findsOneWidget);
    expect(find.text('Guard Profile'), findsOneWidget);
    expect(find.text('Recent Activity'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guards page stays stable on landscape phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: GuardsPage(events: <DispatchEvent>[])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guards & Workforce'), findsOneWidget);
    expect(find.text('Active Guards'), findsOneWidget);
    expect(find.text('System Alerts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guards page renders figma-aligned command surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: GuardsPage(events: <DispatchEvent>[])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guards & Workforce'), findsOneWidget);
    expect(find.byKey(const ValueKey('guards-overview-grid')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('guards-overview-selected-card')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Real-time guard monitoring, shift verification, and performance tracking.',
      ),
      findsOneWidget,
    );
    expect(find.text('Manage Schedule'), findsOneWidget);
    expect(find.text('Offline Alert'), findsOneWidget);
    expect(find.text('Thabo Mokoena'), findsWidgets);
    expect(find.text('Recent Activity'), findsOneWidget);
    expect(find.text('System Alerts'), findsOneWidget);
  });

  testWidgets('guards page switches roster lanes and workspace views', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? openedReportSiteId;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1440, 980)),
          child: GuardsPage(
            events: const <DispatchEvent>[],
            onOpenGuardReportsForSite: (siteId) {
              openedReportSiteId = siteId;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('guards-workspace-status-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('guards-overview-selected-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('guards-workspace-panel-command')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('guards-workspace-command-receipt')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('guards-overview-selected-open-reports')),
    );
    await tester.tap(
      find.byKey(const ValueKey('guards-overview-selected-open-reports')),
    );
    await tester.pumpAndSettle();

    expect(openedReportSiteId, 'WTF-MAIN');

    await tester.tap(
      find.byKey(const ValueKey('guards-workspace-banner-open-attention')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('guards-roster-card-GRD-447')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('guards-roster-card-GRD-441')),
      findsNothing,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('guards-overview-selected-open-readiness')),
    );
    await tester.tap(
      find.byKey(const ValueKey('guards-overview-selected-open-readiness')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('guards-workspace-panel-readiness')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('guards-overview-selected-open-trace')),
    );
    await tester.tap(
      find.byKey(const ValueKey('guards-overview-selected-open-trace')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('guards-workspace-panel-trace')),
      findsOneWidget,
    );
  });

  testWidgets('guards page reports action opens helper dialog', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: GuardsPage(events: <DispatchEvent>[])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('guards-view-reports-button')));
    await tester.pumpAndSettle();

    expect(find.text('Reports Link Ready'), findsOneWidget);
    expect(
      find.textContaining('workforce documentation, schedule exports'),
      findsOneWidget,
    );
  });

  testWidgets('guards page hero reports action opens selected site reports', (
    tester,
  ) async {
    String? openedReportSiteId;

    await tester.pumpWidget(
      MaterialApp(
        home: GuardsPage(
          events: const <DispatchEvent>[],
          onOpenGuardReportsForSite: (siteId) {
            openedReportSiteId = siteId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('guards-view-reports-button')));
    await tester.pumpAndSettle();

    expect(openedReportSiteId, 'WTF-MAIN');
  });

  testWidgets('guards page filters by search query', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: GuardsPage(events: <DispatchEvent>[])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sipho Ndlovu'), findsWidgets);
    expect(find.text('Nomsa Khumalo'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'Nomsa');
    await tester.pumpAndSettle();

    expect(find.text('Nomsa Khumalo'), findsWidgets);
    expect(find.text('EMP-443'), findsWidgets);
    expect(find.text('EMP-442'), findsNothing);
    expect(find.text('No guards match current filters.'), findsNothing);
  });

  testWidgets('guards page applies initial site filter from routing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: GuardsPage(
          events: <DispatchEvent>[],
          initialSiteFilter: 'Blue Ridge Security',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sipho Ndlovu'), findsWidgets);
    expect(find.text('EMP-442'), findsWidgets);
    expect(find.text('EMP-441'), findsNothing);
  });

  testWidgets('guards page routes schedule and report actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? openedReportSiteId;
    var openedSchedule = false;

    await tester.pumpWidget(
      MaterialApp(
        home: GuardsPage(
          events: const <DispatchEvent>[],
          onOpenGuardSchedule: () {
            openedSchedule = true;
          },
          onOpenGuardReportsForSite: (siteId) {
            openedReportSiteId = siteId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manage Schedule'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export Report'));
    await tester.pumpAndSettle();

    expect(openedSchedule, isTrue);
    expect(openedReportSiteId, 'WTF-MAIN');
  });

  testWidgets('guards page opens message handoff and jumps to client lane', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? openedClientLaneSiteId;

    await tester.pumpWidget(
      MaterialApp(
        home: GuardsPage(
          events: const <DispatchEvent>[],
          initialSiteFilter: 'Blue Ridge Security',
          onOpenClientLaneForSite: (siteId) {
            openedClientLaneSiteId = siteId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final messageButton = find.widgetWithText(OutlinedButton, 'Message').first;
    await tester.ensureVisible(messageButton);
    await tester.tap(messageButton);
    await tester.pumpAndSettle();

    expect(find.text('Message Guard Lane'), findsOneWidget);
    expect(find.text('SMS fallback standby'), findsOneWidget);

    await tester.tap(find.text('Open Client Lane'));
    await tester.pumpAndSettle();

    expect(openedClientLaneSiteId, 'BLR-MAIN');
  });

  testWidgets('guards page stages voip call through callback', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? stagedGuardId;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1440, 980)),
          child: GuardsPage(
            events: const <DispatchEvent>[],
            onStageGuardVoipCall: (guardId, guardName, siteId, phone) async {
              stagedGuardId = guardId;
              return 'staged $guardName';
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final callButton = find.widgetWithText(OutlinedButton, 'Call').first;
    await tester.ensureVisible(callButton);
    await tester.tap(callButton);
    await tester.pumpAndSettle();

    expect(find.text('Voice Call Staging'), findsOneWidget);

    await tester.tap(find.text('Stage VoIP Call'));
    await tester.pumpAndSettle();

    expect(stagedGuardId, 'GRD-441');
    expect(
      find.byKey(const ValueKey('guards-workspace-command-receipt')),
      findsOneWidget,
    );
    expect(find.text('staged Thabo Mokoena'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('guards page shows disabled readiness for unavailable actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? copiedContact;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = (call.arguments as Map<dynamic, dynamic>);
          copiedContact = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(1440, 980)),
          child: GuardsPage(events: <DispatchEvent>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Export Report'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Manage Schedule'),
          )
          .onPressed,
      isNull,
    );

    final messageButton = find.widgetWithText(OutlinedButton, 'Message').first;
    await tester.ensureVisible(messageButton);
    await tester.tap(messageButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Client lane routing is not connected in this session',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Open Client Lane'),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Copy Contact'));
    await tester.pumpAndSettle();
    expect(copiedContact, '+27 82 555 0441');
    expect(find.text('Thabo Mokoena contact copied.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    final callButton = find.widgetWithText(OutlinedButton, 'Call').first;
    await tester.ensureVisible(callButton);
    await tester.tap(callButton);
    await tester.pumpAndSettle();

    expect(find.text('VoIP offline'), findsOneWidget);
    expect(
      find.textContaining('VoIP staging is not connected in this session'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Stage VoIP Call'),
          )
          .onPressed,
      isNull,
    );
  });
}
