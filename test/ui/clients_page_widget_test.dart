import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/ui/clients_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('clients page action cards are interactive', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: ClientsPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: <DispatchEvent>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final retryPushSync = find.text('Retry Push Sync').first;
    await tester.ensureVisible(retryPushSync);
    await tester.tap(retryPushSync, warnIfMissed: false);
    await tester.pump();
    expect(find.text('Push sync retry queued.'), findsOneWidget);

    final residents = find.text('Residents').first;
    await tester.ensureVisible(residents);
    await tester.tap(residents, warnIfMissed: false);
    await tester.pump();
    expect(find.text('Opened Residents room.'), findsOneWidget);

    final incidentRow = find.byKey(
      const ValueKey('clients-incident-row-Officer Arrived-19:47 UTC'),
    );
    await tester.ensureVisible(incidentRow);
    await tester.tap(incidentRow, warnIfMissed: false);
    await tester.pump();
    expect(find.text('Opened incident detail.'), findsOneWidget);
  });
}
