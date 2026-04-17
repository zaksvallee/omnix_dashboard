import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/patrol_completed.dart';
import 'package:omnix_dashboard/ui/sovereign_ledger_page.dart';

DateTime _sovereignLedgerOccurredAtUtc(int day, int hour, int minute) =>
    DateTime.utc(2026, 3, day, hour, minute);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('occurrence book hero view events opens selected entry scope', (
    tester,
  ) async {
    List<String>? openedEventIds;
    String? openedSelectedEventId;

    final events = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'INT-LEDGER-HERO-1',
        sequence: 1,
        version: 1,
        occurredAt: _sovereignLedgerOccurredAtUtc(14, 21, 14),
        intelligenceId: 'INTEL-LEDGER-HERO-1',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-hero-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        cameraId: 'channel-1',
        objectLabel: 'person',
        objectConfidence: 0.94,
        headline: 'Boundary alert',
        summary: 'Person detected near line crossing.',
        riskScore: 94,
        evidenceRecordHash: 'evidence-hero-1',
        canonicalHash: 'hash-hero-1',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: events,
          onOpenEventsForScope: (eventIds, selectedEventId, {originLabel = ''}) {
            openedEventIds = eventIds;
            openedSelectedEventId = selectedEventId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sovereign Ledger'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('ledger-hero-view-events-button')),
    );
    await tester.pumpAndSettle();

    expect(openedEventIds, equals(const ['INT-LEDGER-HERO-1']));
    expect(openedSelectedEventId, 'INT-LEDGER-HERO-1');
  });

  testWidgets('occurrence book export actions are interactive', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? copiedClipboardPayload;
    List<String>? openedEventIds;
    String? openedSelectedEventId;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = (call.arguments as Map<dynamic, dynamic>);
          copiedClipboardPayload = args['text'] as String?;
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

    final events = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'INT-LEDGER-1',
        sequence: 1,
        version: 1,
        occurredAt: _sovereignLedgerOccurredAtUtc(14, 21, 14),
        intelligenceId: 'INTEL-LEDGER-1',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        cameraId: 'channel-1',
        objectLabel: 'person',
        objectConfidence: 0.94,
        headline: 'Boundary alert',
        summary: 'Person detected near line crossing.',
        riskScore: 94,
        evidenceRecordHash: 'evidence-1',
        canonicalHash: 'hash-1',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: events,
          onOpenEventsForScope: (eventIds, selectedEventId, {originLabel = ''}) {
            openedEventIds = eventIds;
            openedSelectedEventId = selectedEventId;
          },
          sceneReviewByIntelligenceId: {
            'INTEL-LEDGER-1': MonitoringSceneReviewRecord(
              intelligenceId: 'INTEL-LEDGER-1',
              evidenceRecordHash: 'evidence-1',
              sourceLabel: 'openai:gpt-4.1-mini',
              postureLabel: 'escalation candidate',
              decisionLabel: 'Escalation Candidate',
              decisionSummary:
                  'Escalated for urgent review because person activity was detected, the scene suggested boundary proximity, and confidence remained high.',
              summary: 'Person visible near the boundary line.',
              reviewedAtUtc: _sovereignLedgerOccurredAtUtc(14, 21, 14),
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-workspace-command-receipt')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('ledger-context-export-ledger')),
    );
    await tester.pump();
    expect(find.textContaining('Ledger export copied'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-export-data')),
    );
    await tester.tap(find.byKey(const ValueKey('ledger-entry-export-data')));
    await tester.pump();
    expect(find.textContaining('Entry export copied'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(copiedClipboardPayload, contains('"sceneReview"'));
    expect(
      copiedClipboardPayload,
      contains('"type": "intelligence_received"'),
    );
    expect(
      copiedClipboardPayload,
      contains('"decision_label": "Escalation Candidate"'),
    );
    expect(
      copiedClipboardPayload,
      contains('Person visible near the boundary line.'),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-view-event-review')),
    );
    await tester.tap(
      find.byKey(const ValueKey('ledger-entry-view-event-review')),
    );
    await tester.pump();
    expect(openedEventIds, <String>['INT-LEDGER-1']);
    expect(openedSelectedEventId, 'INT-LEDGER-1');
    expect(find.text('SCENE REVIEW'), findsOneWidget);
    expect(find.text('openai:gpt-4.1-mini'), findsOneWidget);
    expect(find.text('Escalation Candidate'), findsOneWidget);
    expect(find.textContaining('Escalated for urgent review'), findsWidgets);
  });

  testWidgets('occurrence book filters categories and switches views', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final events = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'INT-LEDGER-OPS-1',
        sequence: 1,
        version: 1,
        occurredAt: _sovereignLedgerOccurredAtUtc(15, 6, 30),
        intelligenceId: 'INTEL-LEDGER-OPS-1',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-ops-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Perimeter anomaly',
        summary: 'Movement detected near the north boundary.',
        riskScore: 82,
        canonicalHash: 'hash-ops-1',
      ),
      PatrolCompleted(
        eventId: 'PATROL-LEDGER-OPS-1',
        sequence: 2,
        version: 1,
        occurredAt: _sovereignLedgerOccurredAtUtc(15, 7, 0),
        guardId: 'GUARD-3',
        routeId: 'ROUTE-NORTH',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        durationSeconds: 720,
      ),
      DecisionCreated(
        eventId: 'DEC-LEDGER-OPS-1',
        sequence: 3,
        version: 1,
        occurredAt: _sovereignLedgerOccurredAtUtc(15, 7, 30),
        dispatchId: 'DSP-LEDGER-OPS-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1440, 1100)),
          child: SovereignLedgerPage(clientId: 'CLIENT-001', events: events),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-workspace-status-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ledger-workspace-command-receipt')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ledger-workspace-panel-case-file')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('ledger-lane-filter-patrol')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-entry-card-LED-2')),
      findsOneWidget,
    );
    expect(find.text('Patrol completed - Sandton Estate'), findsOneWidget);
    expect(find.text('Controller dispatched response'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ledger-workspace-view-chain')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-workspace-panel-chain')),
      findsOneWidget,
    );
    expect(find.text('CHECK CHAIN'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ledger-context-verify-chain')));
    await tester.pumpAndSettle();

    expect(find.text('INTACT'), findsWidgets);
    expect(find.text('Chain verification returned intact.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ledger-workspace-view-trace')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-workspace-panel-trace')),
      findsOneWidget,
    );
    expect(find.text('TRACE RAIL'), findsWidgets);
  });

  testWidgets('occurrence book shows pinned roster planner audit entry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var returnedToWarRoom = false;
    var openedRosterPlanner = false;

    final events = <DispatchEvent>[
      PatrolCompleted(
        eventId: 'PATROL-LEDGER-AUDIT-1',
        sequence: 2,
        version: 1,
        occurredAt: _sovereignLedgerOccurredAtUtc(15, 7, 0),
        guardId: 'GUARD-3',
        routeId: 'ROUTE-NORTH',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        durationSeconds: 720,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: events,
          initialFocusReference: 'OPS-AUDIT-ROSTER-1',
          onReturnToWarRoom: () {
            returnedToWarRoom = true;
          },
          onOpenRosterPlannerFromAudit: () {
            openedRosterPlanner = true;
          },
          pinnedAuditEntry: SovereignLedgerPinnedAuditEntry(
            auditId: 'OPS-AUDIT-ROSTER-1',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            recordCode: 'OB-AUDIT',
            title: 'Roster planner opened from Live Ops.',
            description:
                'Opened the month planner from the live operations war room to close a live coverage gap.',
            occurredAt: _sovereignLedgerOccurredAtUtc(15, 7, 30),
            actorLabel: 'Control-1',
            sourceLabel: 'Live Ops War Room',
            hash: 'abc123def456',
            previousHash: 'prev123hash456',
            accent: const Color(0xFFF59E0B),
            payload: const <String, Object?>{
              'type': 'live_ops_auto_audit',
              'action': 'roster_planner_opened',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-entry-card-OPS-AUDIT-ROSTER-1')),
      findsOneWidget,
    );
    expect(find.text('OB-AUDIT'), findsAtLeastNWidgets(1));
    expect(find.text('Roster planner opened from Live Ops.'), findsOneWidget);
    expect(find.textContaining('AUTO-AUDIT'), findsAtLeastNWidgets(1));
    expect(find.text('OB-AUDIT · Handover'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ledger-entry-open-roster-planner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ledger-audit-target-callout')),
      findsOneWidget,
    );
    expect(find.text('DESK TARGET • Month Planner'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ledger-entry-back-to-war-room')),
      findsOneWidget,
    );
    expect(find.text('Back to Live Ops'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-open-roster-planner')),
    );
    await tester.tap(
      find.byKey(const ValueKey('ledger-entry-open-roster-planner')),
    );
    await tester.pumpAndSettle();

    expect(openedRosterPlanner, isTrue);

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-back-to-war-room')),
    );
    await tester.tap(find.byKey(const ValueKey('ledger-entry-back-to-war-room')));
    await tester.pumpAndSettle();

    expect(returnedToWarRoom, isTrue);
  });

  testWidgets('occurrence book opens linked dispatch and client handoff from signed dispatch audit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    DispatchAuditOpenRequest? openedDispatchRequest;
    DispatchAuditOpenRequest? openedClientRequest;

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: const [],
          initialFocusReference: 'DSP-AUDIT-CLIENT-1',
          onOpenDispatchForIncident: (request) {
            openedDispatchRequest = request;
          },
          onOpenClientForIncident: (request) {
            openedClientRequest = request;
          },
          pinnedAuditEntry: SovereignLedgerPinnedAuditEntry(
            auditId: 'DSP-AUDIT-CLIENT-1',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            recordCode: 'OB-AUDIT',
            title: 'Client handoff opened for DSP-2442.',
            description:
                'Opened client communications handoff for DSP-2442 at Sandton Gate.',
            occurredAt: _sovereignLedgerOccurredAtUtc(15, 8, 0),
            actorLabel: 'Control-1',
            sourceLabel: 'Dispatch War Room',
            hash: 'dispatchhash123',
            previousHash: 'prevdispatchhash',
            accent: const Color(0xFF22D3EE),
            payload: const <String, Object?>{
              'type': 'dispatch_auto_audit',
              'action': 'client_handoff_opened',
              'dispatch_id': 'DSP-2442',
              'incident_reference': 'INC-DSP-2442',
              'room': 'Security Desk',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ledger-detail-room')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ledger-detail-room')),
        matching: find.text('Security Desk'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ledger-audit-target-callout')),
      findsOneWidget,
    );
    expect(find.text('ROOM TARGET • Security Desk'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ledger-entry-open-dispatch')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ledger-entry-open-client-handoff')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ledger-entry-open-client-handoff')),
        matching: find.text('Open Security Desk'),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-open-dispatch')),
    );
    await tester.tap(find.byKey(const ValueKey('ledger-entry-open-dispatch')));
    await tester.pumpAndSettle();
    expect(openedDispatchRequest?.incidentReference, 'INC-DSP-2442');
    expect(openedDispatchRequest?.action, 'client_handoff_opened');
    expect(openedDispatchRequest?.auditId, 'DSP-AUDIT-CLIENT-1');

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-open-client-handoff')),
    );
    await tester.tap(
      find.byKey(const ValueKey('ledger-entry-open-client-handoff')),
    );
    await tester.pumpAndSettle();
    expect(openedClientRequest?.incidentReference, 'INC-DSP-2442');
    expect(openedClientRequest?.action, 'client_handoff_opened');
    expect(openedClientRequest?.payloadType, 'dispatch_auto_audit');
  });

  testWidgets('occurrence book opens AI Copilot from signed dispatch agent audit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    DispatchAuditOpenRequest? openedAgentRequest;

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: const [],
          initialFocusReference: 'DSP-AUDIT-AGENT-1',
          onOpenAgentForIncident: (request) {
            openedAgentRequest = request;
          },
          pinnedAuditEntry: SovereignLedgerPinnedAuditEntry(
            auditId: 'DSP-AUDIT-AGENT-1',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            recordCode: 'OB-AUDIT',
            title: 'AI Copilot opened for DSP-2442.',
            description: 'Opened agent support handoff for DSP-2442.',
            occurredAt: _sovereignLedgerOccurredAtUtc(15, 8, 30),
            actorLabel: 'Control-1',
            sourceLabel: 'Dispatch War Room',
            hash: 'dispatchagenthash',
            previousHash: 'prevdispatchagenthash',
            accent: const Color(0xFFC084FC),
            payload: const <String, Object?>{
              'type': 'dispatch_auto_audit',
              'action': 'agent_handoff_opened',
              'dispatch_id': 'DSP-2442',
              'incident_reference': 'INC-DSP-2442',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-entry-open-ai-copilot')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ledger-audit-target-callout')),
      findsOneWidget,
    );
    expect(find.text('DESK TARGET • AI Copilot'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-open-ai-copilot')),
    );
    await tester.tap(
      find.byKey(const ValueKey('ledger-entry-open-ai-copilot')),
    );
    await tester.pumpAndSettle();
    expect(openedAgentRequest?.incidentReference, 'INC-DSP-2442');
    expect(openedAgentRequest?.action, 'agent_handoff_opened');
    expect(openedAgentRequest?.payloadType, 'dispatch_auto_audit');
    expect(openedAgentRequest?.dispatchId, 'DSP-2442');
  });

  testWidgets('occurrence book opens report from signed dispatch report audit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    DispatchAuditOpenRequest? openedReportRequest;

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: const [],
          initialFocusReference: 'DSP-AUDIT-REPORT-1',
          onOpenReportForDispatchAudit: (request) {
            openedReportRequest = request;
          },
          pinnedAuditEntry: SovereignLedgerPinnedAuditEntry(
            auditId: 'DSP-AUDIT-REPORT-1',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            recordCode: 'OB-AUDIT',
            title: 'Report handoff opened for DSP-2442.',
            description: 'Opened report handoff for DSP-2442 at Sandton Gate.',
            occurredAt: _sovereignLedgerOccurredAtUtc(15, 8, 40),
            actorLabel: 'Control-1',
            sourceLabel: 'Dispatch War Room',
            hash: 'dispatchreporthash',
            previousHash: 'prevdispatchreporthash',
            accent: const Color(0xFF8FD1FF),
            payload: const <String, Object?>{
              'type': 'dispatch_auto_audit',
              'action': 'report_handoff_opened',
              'dispatch_id': 'DSP-2442',
              'incident_reference': 'INC-DSP-2442',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-entry-open-dispatch-report')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ledger-audit-target-callout')),
      findsOneWidget,
    );
    expect(find.text('DESK TARGET • Reports Workspace'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-open-dispatch-report')),
    );
    await tester.tap(
      find.byKey(const ValueKey('ledger-entry-open-dispatch-report')),
    );
    await tester.pumpAndSettle();
    expect(openedReportRequest?.dispatchId, 'DSP-2442');
    expect(openedReportRequest?.incidentReference, 'INC-DSP-2442');
    expect(openedReportRequest?.action, 'report_handoff_opened');
    expect(openedReportRequest?.auditId, 'DSP-AUDIT-REPORT-1');
  });

  testWidgets('occurrence book labels dispatch launch audit as live dispatch', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    DispatchAuditOpenRequest? openedDispatchRequest;

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: const [],
          initialFocusReference: 'DSP-AUDIT-LAUNCH-1',
          onOpenDispatchForIncident: (request) {
            openedDispatchRequest = request;
          },
          pinnedAuditEntry: SovereignLedgerPinnedAuditEntry(
            auditId: 'DSP-AUDIT-LAUNCH-1',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            recordCode: 'OB-AUDIT',
            title: 'Dispatch launched for DSP-2441.',
            description:
                'Assigned an officer to DSP-2441 and moved the lane into live response tracking.',
            occurredAt: _sovereignLedgerOccurredAtUtc(15, 8, 41),
            actorLabel: 'Control-1',
            sourceLabel: 'Dispatch War Room',
            hash: 'dispatchlaunchhash',
            previousHash: 'prevdispatchlaunchhash',
            accent: const Color(0xFFF59E0B),
            payload: const <String, Object?>{
              'type': 'dispatch_auto_audit',
              'action': 'dispatch_launched',
              'dispatch_id': 'DSP-2441',
              'incident_reference': 'INC-DSP-2441',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OPEN LIVE DISPATCH'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-open-dispatch')),
    );
    await tester.tap(find.byKey(const ValueKey('ledger-entry-open-dispatch')));
    await tester.pumpAndSettle();

    expect(openedDispatchRequest?.incidentReference, 'INC-DSP-2441');
    expect(openedDispatchRequest?.action, 'dispatch_launched');
    expect(openedDispatchRequest?.auditId, 'DSP-AUDIT-LAUNCH-1');
  });

  testWidgets('occurrence book labels dispatch resolve audit as closure board', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    DispatchAuditOpenRequest? openedDispatchRequest;

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: const [],
          initialFocusReference: 'DSP-AUDIT-RESOLVE-1',
          onOpenDispatchForIncident: (request) {
            openedDispatchRequest = request;
          },
          pinnedAuditEntry: SovereignLedgerPinnedAuditEntry(
            auditId: 'DSP-AUDIT-RESOLVE-1',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            recordCode: 'OB-AUDIT',
            title: 'Dispatch resolved for DSP-2442.',
            description:
                'Marked DSP-2442 cleared on scene and moved the lane into clean closure flow.',
            occurredAt: _sovereignLedgerOccurredAtUtc(15, 8, 42),
            actorLabel: 'Control-1',
            sourceLabel: 'Dispatch War Room',
            hash: 'dispatchresolvehash',
            previousHash: 'prevdispatchresolvehash',
            accent: const Color(0xFF63E6A1),
            payload: const <String, Object?>{
              'type': 'dispatch_auto_audit',
              'action': 'dispatch_resolved',
              'dispatch_id': 'DSP-2442',
              'incident_reference': 'INC-DSP-2442',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OPEN CLOSURE BOARD'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-open-dispatch')),
    );
    await tester.tap(find.byKey(const ValueKey('ledger-entry-open-dispatch')));
    await tester.pumpAndSettle();

    expect(openedDispatchRequest?.incidentReference, 'INC-DSP-2442');
    expect(openedDispatchRequest?.action, 'dispatch_resolved');
    expect(openedDispatchRequest?.auditId, 'DSP-AUDIT-RESOLVE-1');
  });

  testWidgets('occurrence book opens AI Copilot from signed live ops agent audit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    DispatchAuditOpenRequest? openedAgentRequest;

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: const [],
          initialFocusReference: 'OPS-AUDIT-AGENT-1',
          onOpenOperationsAgentForIncident: (request) {
            openedAgentRequest = request;
          },
          pinnedAuditEntry: SovereignLedgerPinnedAuditEntry(
            auditId: 'OPS-AUDIT-AGENT-1',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            recordCode: 'OB-AUDIT',
            title: 'AI Copilot opened from Live Ops.',
            description: 'Opened AI Copilot from the live operations war room.',
            occurredAt: _sovereignLedgerOccurredAtUtc(15, 8, 45),
            actorLabel: 'Control-1',
            sourceLabel: 'Live Ops War Room',
            hash: 'liveopsagenthash',
            previousHash: 'prevliveopsagenthash',
            accent: const Color(0xFFC084FC),
            payload: const <String, Object?>{
              'type': 'live_ops_auto_audit',
              'action': 'agent_handoff_opened',
              'incident_reference': 'INC-OPS-2442',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-entry-open-live-ops-ai-copilot')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ledger-audit-target-callout')),
      findsOneWidget,
    );
    expect(find.text('DESK TARGET • AI Copilot'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-open-live-ops-ai-copilot')),
    );
    await tester.tap(
      find.byKey(const ValueKey('ledger-entry-open-live-ops-ai-copilot')),
    );
    await tester.pumpAndSettle();
    expect(openedAgentRequest?.incidentReference, 'INC-OPS-2442');
    expect(openedAgentRequest?.action, 'agent_handoff_opened');
    expect(openedAgentRequest?.payloadType, 'live_ops_auto_audit');
  });

  testWidgets('occurrence book opens client handoff from signed live ops client audit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    DispatchAuditOpenRequest? openedClientRequest;

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: const [],
          initialFocusReference: 'OPS-AUDIT-COMMS-1',
          onOpenClientForIncident: (request) {
            openedClientRequest = request;
          },
          pinnedAuditEntry: SovereignLedgerPinnedAuditEntry(
            auditId: 'OPS-AUDIT-COMMS-1',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            recordCode: 'OB-AUDIT',
            title: 'Client handoff opened from Live Ops.',
            description:
                'Opened client comms handoff from the live operations war room.',
            occurredAt: _sovereignLedgerOccurredAtUtc(15, 8, 50),
            actorLabel: 'Control-1',
            sourceLabel: 'Live Ops War Room',
            hash: 'liveopsclienthash',
            previousHash: 'prevliveopsclienthash',
            accent: const Color(0xFF22D3EE),
            payload: const <String, Object?>{
              'type': 'live_ops_auto_audit',
              'action': 'client_handoff_opened',
              'incident_reference': 'INC-OPS-2443',
              'room': 'Security Desk',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ledger-detail-room')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ledger-detail-room')),
        matching: find.text('Security Desk'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ledger-audit-target-callout')),
      findsOneWidget,
    );
    expect(find.text('ROOM TARGET • Security Desk'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ledger-entry-open-live-ops-client-handoff')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ledger-entry-open-live-ops-client-handoff')),
        matching: find.text('Open Security Desk'),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-open-live-ops-client-handoff')),
    );
    await tester.tap(
      find.byKey(const ValueKey('ledger-entry-open-live-ops-client-handoff')),
    );
    await tester.pumpAndSettle();
    expect(openedClientRequest?.incidentReference, 'INC-OPS-2443');
    expect(openedClientRequest?.action, 'client_handoff_opened');
    expect(openedClientRequest?.payloadType, 'live_ops_auto_audit');
  });

  testWidgets('occurrence book opens CCTV from signed dispatch CCTV audit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    DispatchAuditOpenRequest? openedCctvRequest;

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: const [],
          initialFocusReference: 'DSP-AUDIT-CCTV-1',
          onOpenCctvForIncident: (request) {
            openedCctvRequest = request;
          },
          pinnedAuditEntry: SovereignLedgerPinnedAuditEntry(
            auditId: 'DSP-AUDIT-CCTV-1',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            recordCode: 'OB-AUDIT',
            title: 'CCTV opened for DSP-2442.',
            description: 'Opened CCTV review for DSP-2442 at Sandton Gate.',
            occurredAt: _sovereignLedgerOccurredAtUtc(15, 8, 55),
            actorLabel: 'Control-1',
            sourceLabel: 'Dispatch War Room',
            hash: 'dispatchcctvhash',
            previousHash: 'prevdispatchcctvhash',
            accent: const Color(0xFF6EE7B7),
            payload: const <String, Object?>{
              'type': 'dispatch_auto_audit',
              'action': 'cctv_handoff_opened',
              'dispatch_id': 'DSP-2442',
              'incident_reference': 'INC-DSP-2442',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ledger-entry-open-cctv')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ledger-audit-target-callout')),
      findsOneWidget,
    );
    expect(find.text('DESK TARGET • CCTV Review'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ledger-entry-open-cctv')),
        matching: find.text('OPEN CCTV REVIEW'),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const ValueKey('ledger-entry-open-cctv')));
    await tester.tap(find.byKey(const ValueKey('ledger-entry-open-cctv')));
    await tester.pumpAndSettle();
    expect(openedCctvRequest?.incidentReference, 'INC-DSP-2442');
    expect(openedCctvRequest?.action, 'cctv_handoff_opened');
    expect(openedCctvRequest?.payloadType, 'dispatch_auto_audit');
    expect(openedCctvRequest?.dispatchId, 'DSP-2442');
  });

  testWidgets('occurrence book opens CCTV from signed live ops CCTV audit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    DispatchAuditOpenRequest? openedCctvRequest;

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: const [],
          initialFocusReference: 'OPS-AUDIT-CCTV-1',
          onOpenCctvForIncident: (request) {
            openedCctvRequest = request;
          },
          pinnedAuditEntry: SovereignLedgerPinnedAuditEntry(
            auditId: 'OPS-AUDIT-CCTV-1',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            recordCode: 'OB-AUDIT',
            title: 'CCTV opened from Live Ops.',
            description:
                'Opened CCTV review from the live operations war room.',
            occurredAt: _sovereignLedgerOccurredAtUtc(15, 8, 57),
            actorLabel: 'Control-1',
            sourceLabel: 'Live Ops War Room',
            hash: 'liveopscctvhash',
            previousHash: 'prevliveopscctvhash',
            accent: const Color(0xFF6EE7B7),
            payload: const <String, Object?>{
              'type': 'live_ops_auto_audit',
              'action': 'cctv_handoff_opened',
              'incident_reference': 'INC-OPS-2444',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-entry-open-live-ops-cctv')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ledger-audit-target-callout')),
      findsOneWidget,
    );
    expect(find.text('DESK TARGET • CCTV Review'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ledger-entry-open-live-ops-cctv')),
        matching: find.text('OPEN CCTV REVIEW'),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-open-live-ops-cctv')),
    );
    await tester.tap(
      find.byKey(const ValueKey('ledger-entry-open-live-ops-cctv')),
    );
    await tester.pumpAndSettle();
    expect(openedCctvRequest?.incidentReference, 'INC-OPS-2444');
    expect(openedCctvRequest?.action, 'cctv_handoff_opened');
    expect(openedCctvRequest?.payloadType, 'live_ops_auto_audit');
  });

  testWidgets('occurrence book opens dispatch from signed live ops dispatch audit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    DispatchAuditOpenRequest? openedDispatchRequest;

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: const [],
          initialFocusReference: 'OPS-AUDIT-DISPATCH-1',
          onOpenDispatchForIncident: (request) {
            openedDispatchRequest = request;
          },
          pinnedAuditEntry: SovereignLedgerPinnedAuditEntry(
            auditId: 'OPS-AUDIT-DISPATCH-1',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            recordCode: 'OB-AUDIT',
            title: 'Dispatch board opened from Live Ops.',
            description:
                'Opened dispatch board from the live operations war room.',
            occurredAt: _sovereignLedgerOccurredAtUtc(15, 8, 59),
            actorLabel: 'Control-1',
            sourceLabel: 'Live Ops War Room',
            hash: 'liveopsdispatchhash',
            previousHash: 'prevliveopsdispatchhash',
            accent: const Color(0xFF8FD1FF),
            payload: const <String, Object?>{
              'type': 'live_ops_auto_audit',
              'action': 'dispatch_handoff_opened',
              'incident_reference': 'INC-OPS-2445',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-entry-open-live-ops-dispatch')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-open-live-ops-dispatch')),
    );
    await tester.tap(
      find.byKey(const ValueKey('ledger-entry-open-live-ops-dispatch')),
    );
    await tester.pumpAndSettle();
    expect(openedDispatchRequest?.incidentReference, 'INC-OPS-2445');
    expect(openedDispatchRequest?.action, 'dispatch_handoff_opened');
    expect(openedDispatchRequest?.payloadType, 'live_ops_auto_audit');
  });

  testWidgets('occurrence book opens tactical track from signed live ops track audit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    DispatchAuditOpenRequest? openedTrackRequest;

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: const [],
          initialFocusReference: 'OPS-AUDIT-TRACK-1',
          onOpenTrackForIncident: (request) {
            openedTrackRequest = request;
          },
          pinnedAuditEntry: SovereignLedgerPinnedAuditEntry(
            auditId: 'OPS-AUDIT-TRACK-1',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            recordCode: 'OB-AUDIT',
            title: 'Track opened from Live Ops.',
            description:
                'Opened tactical track from the live operations war room.',
            occurredAt: _sovereignLedgerOccurredAtUtc(15, 9, 1),
            actorLabel: 'Control-1',
            sourceLabel: 'Live Ops War Room',
            hash: 'liveopstrackhash',
            previousHash: 'prevliveopstrackhash',
            accent: const Color(0xFF8FD1FF),
            payload: const <String, Object?>{
              'type': 'live_ops_auto_audit',
              'action': 'track_handoff_opened',
              'incident_reference': 'INC-OPS-2446',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-entry-open-live-ops-track')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ledger-audit-target-callout')),
      findsOneWidget,
    );
    expect(find.text('DESK TARGET • Tactical Track'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ledger-entry-open-live-ops-track')),
        matching: find.text('OPEN TACTICAL TRACK'),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-open-live-ops-track')),
    );
    await tester.tap(
      find.byKey(const ValueKey('ledger-entry-open-live-ops-track')),
    );
    await tester.pumpAndSettle();
    expect(openedTrackRequest?.incidentReference, 'INC-OPS-2446');
    expect(openedTrackRequest?.action, 'track_handoff_opened');
    expect(openedTrackRequest?.payloadType, 'live_ops_auto_audit');
  });

  testWidgets('occurrence book opens tactical track from signed dispatch track audit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    DispatchAuditOpenRequest? openedTrackRequest;

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: const [],
          initialFocusReference: 'DSP-AUDIT-TRACK-1',
          onOpenTrackForIncident: (request) {
            openedTrackRequest = request;
          },
          pinnedAuditEntry: SovereignLedgerPinnedAuditEntry(
            auditId: 'DSP-AUDIT-TRACK-1',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            recordCode: 'OB-AUDIT',
            title: 'Track opened for DSP-2441.',
            description:
                'Opened tactical tracking for DSP-2441 at Sandton Gate.',
            occurredAt: _sovereignLedgerOccurredAtUtc(15, 9, 2),
            actorLabel: 'Control-1',
            sourceLabel: 'Dispatch War Room',
            hash: 'dispatchtrackhash',
            previousHash: 'prevdispatchtrackhash',
            accent: const Color(0xFF8FD1FF),
            payload: const <String, Object?>{
              'type': 'dispatch_auto_audit',
              'action': 'track_handoff_opened',
              'dispatch_id': 'DSP-2441',
              'incident_reference': 'INC-DSP-2441',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-entry-open-dispatch-track')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ledger-audit-target-callout')),
      findsOneWidget,
    );
    expect(find.text('DESK TARGET • Tactical Track'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ledger-entry-open-dispatch-track')),
        matching: find.text('OPEN TACTICAL TRACK'),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-open-dispatch-track')),
    );
    await tester.tap(
      find.byKey(const ValueKey('ledger-entry-open-dispatch-track')),
    );
    await tester.pumpAndSettle();
    expect(openedTrackRequest?.incidentReference, 'INC-DSP-2441');
    expect(openedTrackRequest?.action, 'track_handoff_opened');
    expect(openedTrackRequest?.payloadType, 'dispatch_auto_audit');
    expect(openedTrackRequest?.dispatchId, 'DSP-2441');
  });

  testWidgets('occurrence book opens events from signed risk intel audit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    List<String>? openedEventIds;
    String? openedSelectedEventId;
    var returnedToRiskIntel = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: const [],
          initialFocusReference: 'INTEL-AUDIT-EVENTS-1',
          onReturnToWarRoom: () {
            returnedToRiskIntel = true;
          },
          onOpenEventsForScope: (eventIds, selectedEventId, {originLabel = ''}) {
            openedEventIds = eventIds;
            openedSelectedEventId = selectedEventId;
          },
          pinnedAuditEntry: SovereignLedgerPinnedAuditEntry(
            auditId: 'INTEL-AUDIT-EVENTS-1',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            recordCode: 'OB-AUDIT',
            title: 'Area signals opened from Risk Intel.',
            description: 'Opened Sandton signals from Risk Intel.',
            occurredAt: _sovereignLedgerOccurredAtUtc(15, 9, 3),
            actorLabel: 'Control-1',
            sourceLabel: 'Risk Intel War Room',
            hash: 'riskintelhsh1',
            previousHash: 'prevriskintelhsh1',
            accent: const Color(0xFFFFC533),
            payload: const <String, Object?>{
              'type': 'risk_intel_auto_audit',
              'action': 'area_scope_opened',
              'selected_event_id': 'INTEL-RISK-1',
              'scoped_event_ids': <String>['INTEL-RISK-1', 'INTEL-RISK-2'],
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-entry-open-risk-intel-events')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ledger-audit-target-callout')),
      findsOneWidget,
    );
    expect(find.text('DESK TARGET • Events Scope'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ledger-entry-open-risk-intel-events')),
        matching: find.text('OPEN EVENTS SCOPE'),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-open-risk-intel-events')),
    );
    await tester.tap(
      find.byKey(const ValueKey('ledger-entry-open-risk-intel-events')),
    );
    await tester.pumpAndSettle();

    expect(openedEventIds, <String>['INTEL-RISK-1', 'INTEL-RISK-2']);
    expect(openedSelectedEventId, 'INTEL-RISK-1');
    expect(find.text('Back to Risk Intel'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-back-to-war-room')),
    );
    await tester.tap(find.byKey(const ValueKey('ledger-entry-back-to-war-room')));
    await tester.pumpAndSettle();

    expect(returnedToRiskIntel, isTrue);
  });

  testWidgets('occurrence book opens manual intel intake from signed risk intel audit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var openedManualIntel = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: const [],
          initialFocusReference: 'INTEL-AUDIT-INTAKE-1',
          onOpenManualIntelFromAudit: () {
            openedManualIntel = true;
          },
          pinnedAuditEntry: SovereignLedgerPinnedAuditEntry(
            auditId: 'INTEL-AUDIT-INTAKE-1',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            recordCode: 'OB-AUDIT',
            title: 'Manual intel intake opened from Risk Intel.',
            description: 'Opened manual intel intake from Risk Intel.',
            occurredAt: _sovereignLedgerOccurredAtUtc(15, 9, 5),
            actorLabel: 'Control-1',
            sourceLabel: 'Risk Intel War Room',
            hash: 'riskintelmanualhash',
            previousHash: 'prevriskintelmanualhash',
            accent: const Color(0xFF54C8FF),
            payload: const <String, Object?>{
              'type': 'risk_intel_auto_audit',
              'action': 'manual_intel_opened',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-entry-open-manual-intel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ledger-audit-target-callout')),
      findsOneWidget,
    );
    expect(find.text('DESK TARGET • Intel Intake'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ledger-entry-open-manual-intel')),
        matching: find.text('OPEN INTEL INTAKE'),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-open-manual-intel')),
    );
    await tester.tap(find.byKey(const ValueKey('ledger-entry-open-manual-intel')));
    await tester.pumpAndSettle();

    expect(openedManualIntel, isTrue);
  });

  testWidgets('occurrence book opens VIP package desk from signed vip audit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var openedVipPackage = false;
    var returnedToVip = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: const [],
          initialFocusReference: 'VIP-AUDIT-1',
          onReturnToWarRoom: () {
            returnedToVip = true;
          },
          onOpenVipPackageFromAudit: () {
            openedVipPackage = true;
          },
          pinnedAuditEntry: SovereignLedgerPinnedAuditEntry(
            auditId: 'VIP-AUDIT-1',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            recordCode: 'OB-AUDIT',
            title: 'VIP package review opened from VIP.',
            description: 'Opened VIP package review for CEO Airport Escort.',
            occurredAt: _sovereignLedgerOccurredAtUtc(15, 9, 7),
            actorLabel: 'Control-1',
            sourceLabel: 'VIP War Room',
            hash: 'viphash1',
            previousHash: 'prevviphash1',
            accent: const Color(0xFF7DDCFF),
            payload: const <String, Object?>{
              'type': 'vip_auto_audit',
              'action': 'package_review_opened',
              'vip_title': 'CEO Airport Escort',
              'vip_subtitle': 'Sandton to OR Tambo International',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ledger-entry-open-vip-package')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ledger-audit-target-callout')),
      findsOneWidget,
    );
    expect(find.text('DESK TARGET • VIP Package Review'), findsOneWidget);
    expect(find.text('Back to VIP'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-open-vip-package')),
    );
    await tester.tap(find.byKey(const ValueKey('ledger-entry-open-vip-package')));
    await tester.pumpAndSettle();
    expect(openedVipPackage, isTrue);

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-back-to-war-room')),
    );
    await tester.tap(find.byKey(const ValueKey('ledger-entry-back-to-war-room')));
    await tester.pumpAndSettle();
    expect(returnedToVip, isTrue);
  });

  testWidgets('occurrence book opens Sites action from signed sites audit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var openedSitesAction = false;
    var returnedToSites = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          events: const [],
          initialFocusReference: 'SITES-AUDIT-1',
          onReturnToWarRoom: () {
            returnedToSites = true;
          },
          onOpenSitesActionFromAudit: () {
            openedSitesAction = true;
          },
          pinnedAuditEntry: SovereignLedgerPinnedAuditEntry(
            auditId: 'SITES-AUDIT-1',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            recordCode: 'OB-AUDIT',
            title: 'Site settings opened from Sites.',
            description: 'Opened site settings for Meridian Tower from Sites.',
            occurredAt: _sovereignLedgerOccurredAtUtc(15, 9, 9),
            actorLabel: 'Control-1',
            sourceLabel: 'Sites War Room',
            hash: 'siteshash1',
            previousHash: 'prevsiteshash1',
            accent: const Color(0xFFFFC247),
            payload: const <String, Object?>{
              'type': 'sites_auto_audit',
              'action': 'site_settings_opened',
              'site_id': 'SITE-SANDTON',
              'site_name': 'Meridian Tower',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ledger-entry-open-sites-action')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ledger-audit-target-callout')),
      findsOneWidget,
    );
    expect(find.text('DESK TARGET • Site Settings'), findsOneWidget);
    expect(find.text('Back to Sites'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-open-sites-action')),
    );
    await tester.tap(find.byKey(const ValueKey('ledger-entry-open-sites-action')));
    await tester.pumpAndSettle();
    expect(openedSitesAction, isTrue);

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-back-to-war-room')),
    );
    await tester.tap(find.byKey(const ValueKey('ledger-entry-back-to-war-room')));
    await tester.pumpAndSettle();
    expect(returnedToSites, isTrue);
  });

  testWidgets('occurrence book submits a new ob entry from the composer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: SovereignLedgerPage(clientId: 'CLIENT-001', events: []),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ledger-open-composer')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('ledger-form-location')),
      'North Gate',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ledger-form-description')),
      'False alarm caused by faulty gate sensor. No intrusion.',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-form-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('ledger-form-submit')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ledger-entry-card-MAN-2442')),
      findsOneWidget,
    );
    expect(
      find.textContaining('OB entry submitted (OB-2442).'),
      findsOneWidget,
    );
    expect(
      find.text('False alarm caused by faulty gate sensor. No intrusion.'),
      findsWidgets,
    );
  });

  testWidgets('occurrence book narrows entries to the scoped site', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final events = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'INT-LEDGER-SCOPE-1',
        sequence: 1,
        version: 1,
        occurredAt: _sovereignLedgerOccurredAtUtc(16, 8, 0),
        intelligenceId: 'INTEL-LEDGER-SCOPE-1',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-scope-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Sandton boundary alert',
        summary: 'Person detected near Sandton line crossing.',
        riskScore: 88,
        canonicalHash: 'hash-scope-1',
      ),
      IntelligenceReceived(
        eventId: 'INT-LEDGER-SCOPE-2',
        sequence: 2,
        version: 1,
        occurredAt: _sovereignLedgerOccurredAtUtc(16, 8, 5),
        intelligenceId: 'INTEL-LEDGER-SCOPE-2',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-scope-2',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-VALLEE',
        headline: 'Vallee gate alert',
        summary: 'Vehicle detected near Vallee gate.',
        riskScore: 77,
        canonicalHash: 'hash-scope-2',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SovereignLedgerPage(
          clientId: 'CLIENT-001',
          initialScopeClientId: 'CLIENT-001',
          initialScopeSiteId: 'SITE-VALLEE',
          events: events,
          initialFocusReference: 'INTEL-LEDGER-SCOPE-2',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ledger-scope-banner')), findsOneWidget);
    expect(find.textContaining('Client 001 / Site Vallee'), findsOneWidget);
    expect(find.text('Vallee gate alert'), findsWidgets);
    expect(find.text('Sandton boundary alert'), findsNothing);
    expect(find.textContaining('Focus: INTEL-LEDGER-SCOPE-2'), findsOneWidget);
  });
}
