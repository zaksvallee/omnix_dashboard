import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/ui/ledger_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'ledger page shows fallback runtime hint when Supabase is disabled',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LedgerPage(
            clientId: 'CLIENT-001',
            supabaseEnabled: false,
            events: [],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('EventStore'), findsOneWidget);
      expect(
        find.textContaining('Run with local defines: ./scripts/run_onyx_chrome_local.sh'),
        findsOneWidget,
      );
    },
  );
}
