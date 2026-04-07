import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/authority/onyx_route.dart';
import 'package:omnix_dashboard/ui/controller_login_page.dart';
import 'package:omnix_dashboard/ui/theme/onyx_design_tokens.dart';
import 'package:omnix_dashboard/ui/theme/onyx_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildHarness({
    required List<ControllerLoginAccount> accounts,
    required ValueChanged<ControllerLoginAccount> onAuthenticated,
  }) {
    return MaterialApp(
      theme: OnyxTheme.dark(),
      home: ControllerLoginPage(
        demoAccounts: accounts,
        onAuthenticated: onAuthenticated,
      ),
    );
  }

  testWidgets('login page never renders demo account passwords', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildHarness(
        accounts: const <ControllerLoginAccount>[
          ControllerLoginAccount(
            username: 'admin',
            password: 'secret123',
            displayName: 'Admin User',
            roleLabel: 'Admin',
            accessLabel: 'Full Access',
            landingRoute: OnyxRoute.dashboard,
          ),
        ],
        onAuthenticated: (_) {},
      ),
    );

    expect(find.text('admin'), findsOneWidget);
    expect(find.textContaining('secret123'), findsNothing);
  });

  testWidgets('login trims stored credential before matching user input', (
    tester,
  ) async {
    ControllerLoginAccount? authenticated;

    await tester.pumpWidget(
      buildHarness(
        accounts: const <ControllerLoginAccount>[
          ControllerLoginAccount(
            username: 'admin',
            password: '  onyx123  ',
            displayName: 'Admin User',
            roleLabel: 'Admin',
            accessLabel: 'Full Access',
            landingRoute: OnyxRoute.dashboard,
          ),
        ],
        onAuthenticated: (account) {
          authenticated = account;
        },
      ),
    );

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

    expect(authenticated, isNotNull);
    expect(authenticated!.username, 'admin');
  });

  testWidgets('login page uses the Onyx dark token background', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        accounts: const <ControllerLoginAccount>[],
        onAuthenticated: (_) {},
      ),
    );

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('controller-login-page')),
    );
    expect(scaffold.backgroundColor, OnyxDesignTokens.backgroundPrimary);
  });
}
