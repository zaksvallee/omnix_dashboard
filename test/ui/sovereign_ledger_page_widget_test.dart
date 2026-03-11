import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/ui/sovereign_ledger_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sovereign ledger export actions are interactive', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: <DispatchEvent>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final exportLedger = find.text('EXPORT LEDGER').first;
    await tester.ensureVisible(exportLedger);
    await tester.tap(exportLedger);
    await tester.pump();
    expect(find.textContaining('Ledger export copied'), findsOneWidget);

    final exportEntryData = find.text('EXPORT ENTRY DATA').first;
    await tester.ensureVisible(exportEntryData);
    await tester.tap(exportEntryData, warnIfMissed: false);
    await tester.pump();
    expect(find.textContaining('Entry export copied'), findsOneWidget);

    final viewInEventReview = find.text('VIEW IN EVENT REVIEW').first;
    await tester.ensureVisible(viewInEventReview);
    await tester.tap(viewInEventReview, warnIfMissed: false);
    await tester.pump();
    expect(find.textContaining('Open Event Review to inspect'), findsOneWidget);
  });
}
