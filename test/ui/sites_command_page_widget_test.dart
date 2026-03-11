import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/ui/sites_command_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sites command action chips are interactive', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: SitesCommandPage(events: <DispatchEvent>[])),
    );
    await tester.pumpAndSettle();

    final addSite = find.text('ADD SITE').first;
    await tester.ensureVisible(addSite);
    await tester.tap(addSite, warnIfMissed: false);
    await tester.pump();
    expect(find.text('Site onboarding request captured.'), findsOneWidget);

    final siteSettings = find.text('SITE SETTINGS').first;
    await tester.ensureVisible(siteSettings);
    await tester.tap(siteSettings, warnIfMissed: false);
    await tester.pump();
    expect(find.textContaining('Site settings opened for'), findsOneWidget);
  });
}
