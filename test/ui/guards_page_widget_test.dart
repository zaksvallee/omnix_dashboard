import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/guard_checked_in.dart';
import 'package:omnix_dashboard/domain/events/patrol_completed.dart';
import 'package:omnix_dashboard/domain/events/response_arrived.dart';
import 'package:omnix_dashboard/ui/guards_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('guards page shows empty state when no guard events exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GuardsPage(events: <DispatchEvent>[]),
      ),
    );

    expect(
      find.text('No guard events available in current projection.'),
      findsOneWidget,
    );
  });

  testWidgets('guards page renders roster and selected guard details', (
    tester,
  ) async {
    final events = <DispatchEvent>[
      GuardCheckedIn(
        eventId: 'CHK-1',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 9, 55),
        guardId: 'GUARD-001',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
      PatrolCompleted(
        eventId: 'PAT-1',
        sequence: 2,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 10, 15),
        guardId: 'GUARD-001',
        routeId: 'R1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        durationSeconds: 840,
      ),
      ResponseArrived(
        eventId: 'ARR-1',
        sequence: 3,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 10, 20),
        dispatchId: 'DSP-1',
        guardId: 'GUARD-001',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
      DecisionCreated(
        eventId: 'DEC-1',
        sequence: 4,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 10, 0),
        dispatchId: 'DSP-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
      GuardCheckedIn(
        eventId: 'CHK-2',
        sequence: 5,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 10, 30),
        guardId: 'GUARD-002',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-BRYANSTON',
      ),
    ];

    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: GuardsPage(events: events),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Field Team Console'), findsOneWidget);
    expect(find.text('Guard Operations Workspace'), findsOneWidget);
    expect(find.text('GUARD-001'), findsWidgets);
    expect(find.text('GUARD-002'), findsWidgets);
    expect(find.text('Operational Ratios'), findsOneWidget);
    expect(find.text('Recent Guard Event Trace'), findsOneWidget);
  });
}
