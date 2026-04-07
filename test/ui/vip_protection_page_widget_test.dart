import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/ui/vip_protection_page.dart';

void main() {
  testWidgets('vip protection page opens create detail dialog', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VipProtectionPage(scheduledDetails: <VipScheduledDetail>[]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('vip-create-detail-button')),
    );
    await tester.tap(find.byKey(const ValueKey('vip-create-detail-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('vip-create-detail-dialog')),
      findsOneWidget,
    );
    expect(find.text('Package Desk'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('vip-create-detail-dialog')),
      findsNothing,
    );
  });

  testWidgets('vip protection page preserves create callback when provided', (
    tester,
  ) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: VipProtectionPage(
          scheduledDetails: const <VipScheduledDetail>[],
          onCreateDetail: () {
            called = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('vip-create-detail-button')),
        matching: find.text('OPEN PACKAGE DESK'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('vip-create-detail-button')));
    await tester.pump();

    expect(called, isTrue);
    expect(
      find.byKey(const ValueKey('vip-create-detail-dialog')),
      findsNothing,
    );
  });

  testWidgets('vip schedule cards open their review dialog', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VipProtectionPage()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('vip-schedule-ceo-airport-escort')),
    );
    await tester.tap(
      find.byKey(const ValueKey('vip-schedule-ceo-airport-escort')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('vip-schedule-detail-dialog')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('vip-schedule-detail-dialog')),
        matching: find.text('CEO Airport Escort'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('vip-schedule-detail-dialog')),
        matching: find.text('45km route'),
      ),
      findsOneWidget,
    );
    expect(find.text('OPEN PACKAGE REVIEW'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('Acknowledge'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('vip-schedule-detail-dialog')),
      findsNothing,
    );
  });

  testWidgets(
    'vip protection page uses provided review callback when supplied',
    (tester) async {
      VipScheduledDetail? reviewed;

      await tester.pumpWidget(
        MaterialApp(
          home: VipProtectionPage(
            onReviewScheduledDetail: (detail) {
              reviewed = detail;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('vip-schedule-ceo-airport-escort')),
      );
      await tester.tap(
        find.byKey(const ValueKey('vip-schedule-ceo-airport-escort')),
      );
      await tester.pumpAndSettle();

      expect(reviewed, isNotNull);
      expect(reviewed!.title, 'CEO Airport Escort');
      expect(
        find.byKey(const ValueKey('vip-schedule-detail-dialog')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'vip protection page shows empty scheduled state when no details exist',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VipProtectionPage(scheduledDetails: <VipScheduledDetail>[]),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('vip-no-scheduled-details-state')),
        findsOneWidget,
      );
      expect(find.text('No packages are queued.'), findsOneWidget);
    },
  );

  testWidgets(
    'vip protection page hides board-clear empty state when scheduled details exist',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VipProtectionPage()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('vip-empty-state')), findsNothing);
      expect(find.text('No Live VIP Run'), findsNothing);
    },
  );

  testWidgets('vip schedule dialog uses detail badge label and fact titles', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: VipProtectionPage()));
    await tester.pumpAndSettle();

    expect(find.text('YOU NEXT'), findsNothing);
    expect(find.text('TOMORROW'), findsAtLeastNWidgets(2));

    await tester.ensureVisible(
      find.byKey(const ValueKey('vip-schedule-ceo-airport-escort')),
    );
    await tester.tap(
      find.byKey(const ValueKey('vip-schedule-ceo-airport-escort')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Assignment detail'), findsNothing);
    expect(find.text('Time window'), findsOneWidget);
    expect(find.text('Detail team'), findsOneWidget);
    expect(find.text('Route plan'), findsOneWidget);
  });

  testWidgets('vip protection page shows latest auto-audit receipt', (
    tester,
  ) async {
    var openedLatestAudit = false;

    await tester.pumpWidget(
      MaterialApp(
        home: VipProtectionPage(
          latestAutoAuditReceipt: const VipAutoAuditReceipt(
            auditId: 'VIP-AUDIT-1',
            label: 'AUTO-AUDIT',
            headline: 'VIP action signed automatically.',
            detail: 'Opened VIP package review. • hash abc123def4',
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
      find.byKey(const ValueKey('vip-latest-audit-panel')),
      findsOneWidget,
    );
    expect(find.text('AUTO-AUDIT'), findsOneWidget);
    expect(find.text('VIP action signed automatically.'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('vip-view-latest-audit-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('vip-view-latest-audit-button')),
    );
    await tester.pumpAndSettle();

    expect(openedLatestAudit, isTrue);
  });
}
