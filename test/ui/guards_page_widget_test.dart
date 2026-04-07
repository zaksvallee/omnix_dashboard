import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/guard_sync_repository.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/guard/guard_mobile_ops.dart';
import 'package:omnix_dashboard/domain/guard/guard_position_summary.dart';
import 'package:omnix_dashboard/ui/guards_page.dart';

class _FakeGuardSyncRepository implements GuardSyncRepository {
  List<GuardAssignment> assignments;
  List<GuardSyncOperation> operations;

  _FakeGuardSyncRepository({
    this.assignments = const <GuardAssignment>[],
    this.operations = const <GuardSyncOperation>[],
  });

  @override
  Future<List<GuardAssignment>> readAssignments() async {
    return assignments;
  }

  @override
  Future<void> saveAssignments(List<GuardAssignment> assignments) async {
    this.assignments = List<GuardAssignment>.from(assignments);
  }

  @override
  Future<List<GuardPositionSummary>> readLatestGuardPositions() async {
    return const <GuardPositionSummary>[];
  }

  @override
  Future<List<GuardSyncOperation>> readQueuedOperations() async {
    return operations
        .where(
          (operation) => operation.status == GuardSyncOperationStatus.queued,
        )
        .toList(growable: false);
  }

  @override
  Future<List<GuardSyncOperation>> readOperations({
    Set<GuardSyncOperationStatus> statuses = const {
      GuardSyncOperationStatus.queued,
    },
    int limit = 50,
    String? facadeMode,
    String? facadeId,
  }) async {
    final filtered = operations
        .where((operation) => statuses.contains(operation.status))
        .toList(growable: false);
    if (filtered.length <= limit) {
      return filtered;
    }
    return filtered.sublist(0, limit);
  }

  @override
  Future<void> saveQueuedOperations(List<GuardSyncOperation> operations) async {
    this.operations = List<GuardSyncOperation>.from(operations);
  }

  @override
  Future<void> markOperationsSynced(List<String> operationIds) async {
    operations = operations
        .map(
          (operation) => operationIds.contains(operation.operationId)
              ? operation.copyWith(status: GuardSyncOperationStatus.synced)
              : operation,
        )
        .toList(growable: false);
  }

  @override
  Future<int> retryFailedOperations(List<String> operationIds) async {
    var retried = 0;
    operations = operations
        .map((operation) {
          if (!operationIds.contains(operation.operationId) ||
              operation.status != GuardSyncOperationStatus.failed) {
            return operation;
          }
          retried += 1;
          return operation.copyWith(
            status: GuardSyncOperationStatus.queued,
            failureReason: null,
            retryCount: operation.retryCount + 1,
          );
        })
        .toList(growable: false);
    return retried;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('guards page stays stable on phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: GuardsPage(events: <DispatchEvent>[])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guards & Workforce'), findsOneWidget);
    expect(find.text('Active Now'), findsOneWidget);
    expect(find.text('GUARD ROSTER'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guards page renders redesigned workforce surfaces', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: GuardsPage(events: <DispatchEvent>[])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guards & Workforce'), findsOneWidget);
    expect(find.text('OPEN REPORTS WORKSPACE'), findsOneWidget);
    expect(find.text('5 On Duty'), findsOneWidget);
    expect(find.text('1 Sync Issues'), findsOneWidget);
    expect(find.text('T. Nkosi'), findsWidgets);
    expect(find.text('QUICK ACTIONS'), findsOneWidget);
    expect(find.text('Stage VoIP'), findsOneWidget);
    expect(find.text('Recent Activity'), findsNothing);
    expect(find.text('Guard Profile'), findsNothing);
  });

  testWidgets('guards page switches between workforce views', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: GuardsPage(events: <DispatchEvent>[])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('guards-view-tab-roster')));
    await tester.pumpAndSettle();

    expect(find.text('MONTH PLANNER'), findsOneWidget);
    expect(find.text('Create Month'), findsOneWidget);
    expect(find.text('Fill Gaps'), findsOneWidget);
    expect(find.text('Publish Now'), findsWidgets);
    expect(find.textContaining('OPEN POSTS'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('guards-view-tab-history')));
    await tester.pumpAndSettle();

    expect(find.text('SHIFT HISTORY & TIMESHEETS'), findsOneWidget);
    expect(find.text('5 Active'), findsOneWidget);
    expect(find.text('5 Completed'), findsOneWidget);
  });

  testWidgets('guards page applies initial site filter from routing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: GuardsPage(events: <DispatchEvent>[], initialSiteFilter: 'WF-02'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('J. van Wyk'), findsWidgets);
    expect(find.text('L. Ndlovu'), findsWidgets);
    expect(find.text('T. Nkosi'), findsNothing);
  });

  testWidgets('guards page overlays live repository status onto seeded roster', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _FakeGuardSyncRepository(
      assignments: <GuardAssignment>[
        GuardAssignment(
          assignmentId: 'ASSIGN-LIVE-441',
          dispatchId: 'DISP-LIVE-441',
          clientId: 'CLIENT-001',
          siteId: 'WF-02',
          guardId: 'GRD-441',
          issuedAt: DateTime.utc(2026, 3, 25, 18, 0),
          acknowledgedAt: DateTime.utc(2026, 3, 25, 18, 2),
          status: GuardDutyStatus.enRoute,
        ),
      ],
      operations: <GuardSyncOperation>[
        GuardSyncOperation(
          operationId: 'status-live-441',
          type: GuardSyncOperationType.statusUpdate,
          status: GuardSyncOperationStatus.failed,
          createdAt: DateTime.utc(2026, 3, 25, 18, 4),
          payload: const <String, Object?>{
            'guard_id': 'GRD-441',
            'site_id': 'WF-02',
            'status': 'enRoute',
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GuardsPage(
          events: const <DispatchEvent>[],
          initialSiteFilter: 'WF-02',
          guardSyncRepositoryFuture: Future<GuardSyncRepository>.value(
            repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('T. Nkosi'), findsWidgets);
    expect(find.text('WF-02 • Waterfall Estate'), findsWidgets);
    expect(find.text('Sync Watch'), findsOneWidget);
  });

  testWidgets('guards page ingests evidence returns into the workforce rail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? consumedAuditId;

    await tester.pumpWidget(
      MaterialApp(
        home: GuardsPage(
          events: const <DispatchEvent>[],
          initialSiteFilter: 'WF-02',
          evidenceReturnReceipt: const GuardsEvidenceReturnReceipt(
            auditId: 'AUD-ROSTER-1',
            label: 'EVIDENCE RETURN',
            headline: 'Returned to Guard Roster for Waterfall Estate.',
            detail:
                'The signed roster handoff was verified in the ledger. Keep Waterfall Estate pinned and cover the open posts from here.',
            accent: Color(0xFF63E6A1),
          ),
          onConsumeEvidenceReturnReceipt: (auditId) {
            consumedAuditId = auditId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('guards-evidence-return-banner')),
      findsOneWidget,
    );
    expect(find.text('EVIDENCE RETURN'), findsOneWidget);
    expect(
      find.text('Returned to Guard Roster for Waterfall Estate.'),
      findsOneWidget,
    );
    expect(consumedAuditId, 'AUD-ROSTER-1');
  });

  testWidgets('guards page routes schedule and report actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? openedReportSiteId;
    var openedSchedule = false;

    await tester.pumpWidget(
      MaterialApp(
        home: GuardsPage(
          events: const <DispatchEvent>[],
          onOpenGuardSchedule: () {
            openedSchedule = true;
          },
          onOpenGuardReportsForSite: (siteId) {
            openedReportSiteId = siteId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('guards-quick-schedule')),
    );
    await tester.tap(find.byKey(const ValueKey('guards-quick-schedule')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('guards-view-reports-button')),
    );
    await tester.tap(find.byKey(const ValueKey('guards-view-reports-button')));
    await tester.pumpAndSettle();

    expect(openedSchedule, isTrue);
    expect(openedReportSiteId, 'WTF-MAIN');
  });

  testWidgets('guards planner passes action intent and selected date', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? openedAction;
    DateTime? openedDate;

    await tester.pumpWidget(
      MaterialApp(
        home: GuardsPage(
          events: const <DispatchEvent>[],
          onOpenGuardScheduleForAction: (action, {date}) {
            openedAction = action;
            openedDate = date;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('guards-view-tab-roster')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('guards-roster-edit-button')));
    await tester.pumpAndSettle();

    expect(openedAction, 'edit-roster');
    expect(openedDate, DateTime.utc(2026, 3, 27));
  });

  testWidgets('guards page opens message handoff and jumps to client lane', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? openedClientLaneSiteId;

    await tester.pumpWidget(
      MaterialApp(
        home: GuardsPage(
          events: const <DispatchEvent>[],
          onOpenClientLaneForSite: (siteId) {
            openedClientLaneSiteId = siteId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('guards-quick-client-lane')),
    );
    await tester.tap(find.byKey(const ValueKey('guards-quick-client-lane')));
    await tester.pumpAndSettle();

    expect(find.text('Client Comms'), findsWidgets);
    expect(find.text('SMS fallback standby'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('guards-contact-primary-button')),
    );
    await tester.pumpAndSettle();

    expect(openedClientLaneSiteId, 'WTF-MAIN');
  });

  testWidgets('guards page stages voip call through callback', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? stagedGuardId;

    await tester.pumpWidget(
      MaterialApp(
        home: GuardsPage(
          events: const <DispatchEvent>[],
          onStageGuardVoipCall: (guardId, guardName, siteId, phone) async {
            stagedGuardId = guardId;
            return 'staged $guardName';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('guards-quick-stage-voip')),
    );
    await tester.tap(find.byKey(const ValueKey('guards-quick-stage-voip')));
    await tester.pumpAndSettle();

    expect(find.text('Voice Call Staging'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('guards-contact-primary-button')),
    );
    await tester.pumpAndSettle();

    expect(stagedGuardId, 'GRD-441');
    expect(find.text('staged Thabo Mokoena'), findsOneWidget);
  });

  testWidgets('guards page keeps unavailable handoffs view-only', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? copiedContact;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = (call.arguments as Map<dynamic, dynamic>);
          copiedContact = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: GuardsPage(events: <DispatchEvent>[])),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('guards-quick-client-lane')),
    );
    await tester.tap(find.byKey(const ValueKey('guards-quick-client-lane')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Client Comms routing is not connected'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('guards-contact-primary-button')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('guards-contact-copy-button')));
    await tester.pumpAndSettle();

    expect(copiedContact, '+27 82 555 0441');
    expect(find.text('Thabo Mokoena contact copied.'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('guards-quick-stage-voip')),
    );
    await tester.tap(find.byKey(const ValueKey('guards-quick-stage-voip')));
    await tester.pumpAndSettle();

    expect(find.text('VoIP offline'), findsOneWidget);
    expect(
      find.textContaining('VoIP staging is not connected'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('guards-contact-primary-button')),
          )
          .onPressed,
      isNull,
    );
  });
}
