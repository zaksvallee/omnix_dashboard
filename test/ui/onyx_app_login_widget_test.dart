import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('default controller startup shows the login gate', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(OnyxApp(supabaseReady: false));
    await tester.pump();

    expect(find.byKey(const ValueKey('controller-login-page')), findsOneWidget);
    expect(find.text('Controller Login'), findsOneWidget);
    expect(find.text('Command Center'), findsNothing);
  });

  testWidgets('demo account sign in opens the command surface', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(OnyxApp(supabaseReady: false));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('controller-login-username')),
      'admin',
    );
    await tester.enterText(
      find.byKey(const ValueKey('controller-login-password')),
      'onyx123',
    );
    await tester.tap(find.byKey(const ValueKey('controller-login-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('controller-login-page')), findsNothing);
    expect(find.text('Command Center'), findsOneWidget);
  });

  testWidgets('route overrides still bypass the login gate', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.reports),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('controller-login-page')), findsNothing);
    expect(find.text('Reports & Documentation'), findsOneWidget);
  });
}
