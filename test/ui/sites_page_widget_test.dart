import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/execution_completed.dart';
import 'package:omnix_dashboard/domain/events/guard_checked_in.dart';
import 'package:omnix_dashboard/domain/events/patrol_completed.dart';
import 'package:omnix_dashboard/domain/events/response_arrived.dart';
import 'package:omnix_dashboard/ui/sites_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sites page shows empty state when no site events exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SitesPage(events: <DispatchEvent>[]),
      ),
    );

    expect(
      find.text('No sites available in the current projection.'),
      findsOneWidget,
    );
  });

  testWidgets('sites page renders roster and selected site details', (
    tester,
  ) async {
    final events = <DispatchEvent>[
      DecisionCreated(
        eventId: 'DEC-1',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 10, 0),
        dispatchId: 'DSP-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
      ExecutionCompleted(
        eventId: 'EXE-1',
        sequence: 2,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 10, 4),
        dispatchId: 'DSP-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        success: true,
      ),
      GuardCheckedIn(
        eventId: 'CHK-1',
        sequence: 3,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 10, 6),
        guardId: 'GUARD-001',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
      PatrolCompleted(
        eventId: 'PAT-1',
        sequence: 4,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 10, 10),
        guardId: 'GUARD-001',
        routeId: 'R1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        durationSeconds: 720,
      ),
      ResponseArrived(
        eventId: 'ARR-1',
        sequence: 5,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 10, 12),
        dispatchId: 'DSP-1',
        guardId: 'GUARD-001',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
      DecisionCreated(
        eventId: 'DEC-2',
        sequence: 6,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 11, 0),
        dispatchId: 'DSP-2',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-BRYANSTON',
      ),
    ];

    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SitesPage(events: events),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Site Command Grid'), findsOneWidget);
    expect(find.text('Site Operations Workspace'), findsOneWidget);
    expect(find.text('SITE-SANDTON'), findsWidgets);
    expect(find.text('SITE-BRYANSTON'), findsWidgets);
    expect(find.text('Dispatch Outcome Mix'), findsOneWidget);
    expect(find.text('Recent Site Event Trace'), findsOneWidget);
  });
}
