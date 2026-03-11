import 'package:flutter/material.dart';
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
}
