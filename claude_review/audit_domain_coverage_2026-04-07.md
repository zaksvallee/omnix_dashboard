# Audit: Domain Layer Coverage Gaps

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/domain/` — 21% test coverage, zero-test files
- Read-only: yes

---

## Executive Summary

The domain layer contains 113 source files. Only 24 have corresponding tests — a coverage ratio of ~21%. The untested majority includes critical business-logic files: aggregate roots, projection engines, security policy, SLA tier factories, and timeline builders. These are the files whose bugs are hardest to catch in integration or UI testing and whose failure modes are most likely to produce silent incorrect state. This report identifies the 10 highest-value zero-test files and specifies the exact test cases needed for each.

---

## What Looks Good

- SLA breach evaluator, SLA clock, SLA dashboard projection, and incident service all have solid test coverage — the SLA chain's core evaluation path is locked.
- Guard domain (operational tiers, outcome label governance, coaching policy, selection scope) has comprehensive tests — the guard behaviour contract is well anchored.
- Evidence provenance and ledger service tests cover the chain-of-custody recording path.
- Escalation trend projection and report bundle assembler tests cover the reporting assembly pipeline.

---

## Findings

### P1 — `OperationsHealthProjection` (351 lines, zero tests)

- **Action:** AUTO
- **Finding:** The largest and most complex domain file has no tests. It contains: a `healthScore` formula with hard-coded penalty/bonus coefficients, a `controllerPressureIndex` formula, response-time averaging, site-key parsing (`|`-delimited string split), and live-signal / dispatch-feed truncation at hard limits (7 / 6 items respectively). Any bug in any of these branches is invisible.
- **Why it matters:** `OperationsHealthSnapshot` drives the live ops dashboard displayed to controllers. A wrong health score or pressure index directly misleads operational decisions.
- **Evidence:** `lib/domain/projection/operations_health_projection.dart` lines 322–347 (`_healthScore`), 287–300 (pressure index), 316–317 (signal truncation).

**Exact test cases required** (`test/domain/projection/operations_health_projection_test.dart`):

```dart
// FILE: test/domain/projection/operations_health_projection_test.dart
// Imports: flutter_test, package:omnix_dashboard/domain/projection/operations_health_projection.dart
// and all event types used below.

group('OperationsHealthProjection — empty', () {
  test('returns zero-state snapshot with epoch lastEventAtUtc', () {
    final snap = OperationsHealthProjection.build([]);
    expect(snap.totalSites, 0);
    expect(snap.totalDecisions, 0);
    expect(snap.totalExecuted, 0);
    expect(snap.totalDenied, 0);
    expect(snap.totalFailed, 0);
    expect(snap.averageResponseMinutes, 0.0);
    expect(snap.controllerPressureIndex, 0.0);
    expect(snap.liveSignals, isEmpty);
    expect(snap.dispatchFeed, isEmpty);
  });
});

group('OperationsHealthProjection — counters', () {
  test('counts DecisionCreated, ExecutionCompleted(success), ExecutionDenied correctly', () {
    // Build: 1 DecisionCreated, 1 ExecutionCompleted(success=true), 1 ExecutionDenied
    // Expect: totalDecisions=2, totalExecuted=1, totalDenied=1, totalFailed=0
  });

  test('counts ExecutionCompleted(success=false) as totalFailed, not totalExecuted', () {
    // Build: 1 DecisionCreated, 1 ExecutionCompleted(success=false)
    // Expect: totalExecuted=0, totalFailed=1
  });

  test('counts GuardCheckedIn across multiple sites', () {
    // Build: 2 GuardCheckedIn at siteA, 1 at siteB
    // Expect: totalCheckIns=3
  });

  test('counts PatrolCompleted', () {
    // Build: 3 PatrolCompleted events
    // Expect: totalPatrols=3
  });
});

group('OperationsHealthProjection — intelligence', () {
  test('totalIntelligenceReceived counts all intel events', () {
    // Build: 2 IntelligenceReceived with riskScore < 70, 1 with riskScore = 70
    // Expect: totalIntelligenceReceived=3, highRiskIntelligence=1
  });

  test('riskScore=69 is NOT high risk; riskScore=70 IS high risk', () {
    // Boundary: riskScore 69 → highRiskIntelligence unchanged; 70 → increments
  });
});

group('OperationsHealthProjection — response time', () {
  test('averageResponseMinutes computed from decision→response delta', () {
    final t0 = DateTime.utc(2026, 4, 7, 8, 0);
    final t1 = t0.add(const Duration(minutes: 6));
    // DecisionCreated at t0 for dispatch-1
    // ResponseArrived at t1 for dispatch-1
    // Expect: averageResponseMinutes == 6.0 (within tolerance)
  });

  test('ResponseArrived with no matching DecisionCreated is skipped (no crash)', () {
    // Build: ResponseArrived for dispatch-X with no prior DecisionCreated
    // Expect: no exception, averageResponseMinutes == 0.0
  });
});

group('OperationsHealthProjection — healthScore thresholds', () {
  // Uses _healthScore indirectly via site snapshots in the result.

  test('site with no failures, no denials, 10+ patrols, 10+ checkIns returns STRONG', () {
    // Build events: DecisionCreated + ExecutionCompleted(success) + 10 PatrolCompleted
    //               + 10 GuardCheckedIn, all for same site
    // Expect: site.healthStatus == 'STRONG', site.healthScore >= 85
  });

  test('site with 2 failures returns CRITICAL (score < 45)', () {
    // 2 * 12.0 = 24 deducted; base 100 − 24 = 76 but also active dispatch pushes lower
    // Build: 2 ExecutionCompleted(success=false), no bonuses
    // Expect: site.healthScore == (100 - 24).clamp(0,100) = 76 → WARNING
    // Adjust: 3 failures → 100 - 36 = 64 → WARNING; 5 → 40 → CRITICAL
    // Test exact boundary: failedCount=5, no bonuses → score=40 → CRITICAL
  });

  test('averageResponseMinutes > 10 triggers response penalty (2.0 per minute over 10)', () {
    // Response of 15 min → penalty = (15-10)*2 = 10.0 → score = 90.0 → STRONG
    // Response of 25 min → penalty = (25-10)*2 = 30.0 → score = 70.0 → STABLE
    // Response of 35 min → penalty = (35-10)*2 = 50.0 → clamped at 25 → score = 75 → STABLE
  });

  test('health score is clamped at 0.0 minimum and 100.0 maximum', () {
    // Extreme failure load: 20 failures, no bonuses → raw = 100 - 240 = -140 → clamped 0.0
    // Zero events: score = 100.0
  });
});

group('OperationsHealthProjection — pressure index', () {
  test('controllerPressureIndex clamped between 0 and 100', () {
    // Single site, 100 active dispatches → raw very high → result.controllerPressureIndex == 100.0
  });

  test('pressure index scales with active + failed*2 + denied', () {
    // 1 site, 2 active dispatches, 1 failed, 0 denied
    // raw = ((2 + 2 + 0) / 1) * 10.0 = 40.0
    // Expect: controllerPressureIndex == 40.0
  });
});

group('OperationsHealthProjection — signal truncation', () {
  test('liveSignals is capped at 7 entries (most recent)', () {
    // Build 10 GuardCheckedIn events for different guards
    // Expect: snap.liveSignals.length == 7
  });

  test('dispatchFeed is capped at 6 entries (most recent)', () {
    // Build 10 DecisionCreated events for different dispatches
    // Expect: snap.dispatchFeed.length == 6
  });
});

group('OperationsHealthProjection — lastEventAtUtc', () {
  test('lastEventAtUtc tracks the most recent event timestamp', () {
    final early = DateTime.utc(2026, 4, 7, 8, 0);
    final late = DateTime.utc(2026, 4, 7, 9, 0);
    // Build: one event at early, one at late
    // Expect: snap.lastEventAtUtc == late
  });
});
```

---

### P1 — `DispatchAggregate` (zero tests)

- **Action:** AUTO
- **Finding:** The aggregate root has no tests. It reconstructs status from a sorted event stream. The ordering sort is non-trivial: out-of-order event lists must be normalised before applying. The final-write-wins pattern between `DecisionCreated` and `ExecutionCompleted` is the core mutation rule.
- **Why it matters:** Wrong aggregate state = wrong dispatch status displayed/acted on across the whole system.
- **Evidence:** `lib/domain/aggregate/dispatch_aggregate.dart` lines 10–35.

**Exact test cases required** (`test/domain/aggregate/dispatch_aggregate_test.dart`):

```dart
group('DispatchAggregate.rebuild', () {
  test('empty event list produces unknown status (null)', () {
    final agg = DispatchAggregate.rebuild([]);
    expect(agg.statusOf('DISPATCH-1'), isNull);
  });

  test('DecisionCreated sets status to DECIDED', () {
    final agg = DispatchAggregate.rebuild([
      DecisionCreated(eventId: 'e1', sequence: 1, version: 1,
          occurredAt: DateTime.utc(2026,4,7),
          dispatchId: 'D1', clientId: 'C1', regionId: 'R1', siteId: 'S1'),
    ]);
    expect(agg.statusOf('D1'), 'DECIDED');
  });

  test('ExecutionCompleted(success=true) sets status to CONFIRMED', () {
    final agg = DispatchAggregate.rebuild([
      DecisionCreated(..., dispatchId: 'D1', sequence: 1),
      ExecutionCompleted(..., dispatchId: 'D1', success: true, sequence: 2),
    ]);
    expect(agg.statusOf('D1'), 'CONFIRMED');
  });

  test('ExecutionCompleted(success=false) sets status to FAILED', () {
    // Expect: 'FAILED'
  });

  test('out-of-order events are sorted by sequence before apply', () {
    // Provide ExecutionCompleted(seq=2) before DecisionCreated(seq=1) in list
    // Expect: final status is CONFIRMED/FAILED (not stuck at DECIDED from wrong order)
    final agg = DispatchAggregate.rebuild([
      ExecutionCompleted(..., dispatchId: 'D1', success: true, sequence: 2),
      DecisionCreated(..., dispatchId: 'D1', sequence: 1),
    ]);
    expect(agg.statusOf('D1'), 'CONFIRMED');
  });

  test('multiple dispatches tracked independently', () {
    final agg = DispatchAggregate.rebuild([
      DecisionCreated(..., dispatchId: 'D1', sequence: 1),
      DecisionCreated(..., dispatchId: 'D2', sequence: 2),
      ExecutionCompleted(..., dispatchId: 'D1', success: false, sequence: 3),
    ]);
    expect(agg.statusOf('D1'), 'FAILED');
    expect(agg.statusOf('D2'), 'DECIDED');
  });

  test('unknown dispatchId returns null', () {
    final agg = DispatchAggregate.rebuild([
      DecisionCreated(..., dispatchId: 'D1', sequence: 1),
    ]);
    expect(agg.statusOf('D-UNKNOWN'), isNull);
  });
});
```

---

### P1 — `DispatchProjection` (zero tests)

- **Action:** AUTO
- **Finding:** The primary dispatch read model has no tests. It uses a 4-level nested `Map` (clientId → regionId → siteId → dispatchId → status). The `rebuildFrom` path clears state and re-sorts before applying. Silent mutation order bugs here affect every consumer of the projection.
- **Why it matters:** Primary read model for the dispatch pipeline. Wrong state = controllers acting on stale data.
- **Evidence:** `lib/domain/projection/dispatch_projection.dart` lines 6–80.

**Exact test cases required** (`test/domain/projection/dispatch_projection_test.dart`):

```dart
group('DispatchProjection — apply', () {
  test('DecisionCreated sets DECIDED at correct 4-level path', () {
    final proj = DispatchProjection();
    proj.apply(DecisionCreated(
        eventId: 'e1', sequence: 1, version: 1, occurredAt: DateTime.utc(2026,4,7),
        dispatchId: 'D1', clientId: 'C1', regionId: 'R1', siteId: 'S1'));
    expect(proj.statusOf(clientId: 'C1', regionId: 'R1', siteId: 'S1', dispatchId: 'D1'),
        'DECIDED');
  });

  test('ExecutionCompleted(success=true) transitions status to CONFIRMED', () {
    final proj = DispatchProjection();
    proj.apply(DecisionCreated(..., dispatchId: 'D1', clientId: 'C1', regionId: 'R1', siteId: 'S1'));
    proj.apply(ExecutionCompleted(..., dispatchId: 'D1', clientId: 'C1',
        regionId: 'R1', siteId: 'S1', success: true));
    expect(proj.statusOf(...), 'CONFIRMED');
  });

  test('ExecutionCompleted(success=false) transitions status to FAILED', () {
    // Expect: 'FAILED'
  });

  test('ExecutionDenied sets DENIED', () {
    // Expect: 'DENIED'
  });

  test('statusOf returns null for unknown dispatchId', () {
    final proj = DispatchProjection();
    expect(proj.statusOf(clientId: 'C1', regionId: 'R1', siteId: 'S1', dispatchId: 'GHOST'),
        isNull);
  });

  test('events from different sites are tracked independently', () {
    final proj = DispatchProjection();
    proj.apply(DecisionCreated(..., dispatchId: 'D1', clientId: 'C1', regionId: 'R1', siteId: 'S1'));
    proj.apply(ExecutionDenied(..., dispatchId: 'D2', clientId: 'C1', regionId: 'R1', siteId: 'S2'));
    expect(proj.statusOf(clientId: 'C1', regionId: 'R1', siteId: 'S1', dispatchId: 'D1'), 'DECIDED');
    expect(proj.statusOf(clientId: 'C1', regionId: 'R1', siteId: 'S2', dispatchId: 'D2'), 'DENIED');
  });
});

group('DispatchProjection — rebuildFrom', () {
  test('clears existing state before replay', () {
    final proj = DispatchProjection();
    proj.apply(DecisionCreated(..., dispatchId: 'OLD', ...));
    proj.rebuildFrom([]);
    expect(proj.statusOf(..., dispatchId: 'OLD'), isNull);
  });

  test('out-of-order events are sorted by sequence before apply', () {
    final proj = DispatchProjection();
    proj.rebuildFrom([
      ExecutionCompleted(..., dispatchId: 'D1', success: true, sequence: 2, ...),
      DecisionCreated(..., dispatchId: 'D1', sequence: 1, ...),
    ]);
    expect(proj.statusOf(..., dispatchId: 'D1'), 'CONFIRMED');
  });
});

group('DispatchProjection — snapshot', () {
  test('snapshot returns unmodifiable map', () {
    final proj = DispatchProjection();
    proj.apply(DecisionCreated(...));
    final snap = proj.snapshot();
    expect(() => (snap as dynamic)['new'] = {}, throwsUnsupportedError);
  });
});
```

---

### P1 — `DashboardOverviewProjection` (zero tests)

- **Action:** AUTO
- **Finding:** The `worstStatus` priority ranking (`FAILED > CONFIRMED > DECIDED > DENIED > STABLE`) is a silent policy decision with no test. If this order is wrong, dashboard tiles display incorrect severity. Additionally, `DENIED`-only sites currently show `STABLE` — a priority ordering anomaly worth locking.
- **Why it matters:** `worstStatus` drives dashboard tile colouring and alert escalation. Wrong ranking = controllers triaged incorrectly.
- **Evidence:** `lib/domain/projection/dashboard_overview_projection.dart` lines 64–76.

**Exact test cases required** (`test/domain/projection/dashboard_overview_projection_test.dart`):

```dart
group('DashboardOverviewProjection — worstStatus', () {
  test('FAILED takes precedence over all other statuses', () {
    // Events: 1 DecisionCreated, 1 ExecutionCompleted(success=true), 1 ExecutionCompleted(success=false)
    // Expect: worstStatus == 'FAILED'
  });

  test('CONFIRMED takes precedence over DECIDED and DENIED when no FAILED', () {
    // Events: 1 DecisionCreated, 1 ExecutionCompleted(success=true)
    // Expect: worstStatus == 'CONFIRMED'
  });

  test('DECIDED takes precedence over DENIED when no FAILED or CONFIRMED', () {
    // Events: 1 DecisionCreated, 1 ExecutionDenied (for different dispatch)
    // Expect: worstStatus == 'DECIDED'
  });

  test('DENIED-only site shows DENIED (not STABLE)', () {
    // Events: 1 ExecutionDenied only (no DecisionCreated for same dispatch)
    // NOTE: This test may expose the anomaly — DENIED is currently reached
    //       only if no DECIDED, CONFIRMED, or FAILED is present.
    //       If projection never writes DENIED without a prior DecisionCreated
    //       in practice, this test locks the current behaviour.
    // Expect: worstStatus == 'DENIED'
  });

  test('site with only CONFIRMED returns CONFIRMED, not STABLE', () {
    // Events: 1 ExecutionCompleted(success=true) without DecisionCreated
    // (ExecutionCompleted without prior Decision is still tracked)
    // Expect: worstStatus == 'CONFIRMED'
  });

  test('empty event list produces empty SiteOverview list', () {
    expect(DashboardOverviewProjection.build([]), isEmpty);
  });
});

group('DashboardOverviewProjection — counts', () {
  test('activeDispatches counts DECIDED status only', () {
    // 2 DecisionCreated, 1 ExecutionCompleted(success=true), 1 ExecutionDenied (all same site)
    // Expect: activeDispatches==1, deniedCount==1, failedCount==0
  });

  test('failedCount counts ExecutionCompleted(success=false) only', () {
    // 1 DecisionCreated, 2 ExecutionCompleted(success=false)
    // Expect: failedCount==2
  });

  test('separate sites produce separate SiteOverview entries', () {
    // DecisionCreated for S1 and S2 under same client/region
    // Expect: results.length==2, each with correct siteId
  });
});
```

---

### P1 — `IncidentRiskProjection` (zero tests)

- **Action:** AUTO
- **Finding:** Severity classification thresholds (80 = critical, 50 = high, 20 = medium, <20 = low) are hard-coded policy. Score accumulation from `RiskTag.weight` fields drives case prioritisation. No test locks these boundaries or the extraction path.
- **Why it matters:** Wrong severity derivation = wrong escalation routing, wrong SLA clock tier applied.
- **Evidence:** `lib/domain/incidents/risk/incident_risk_projection.dart` lines 24–33.

**Exact test cases required** (`test/domain/incidents/risk/incident_risk_projection_test.dart`):

```dart
group('IncidentRiskProjection.extractTags', () {
  test('returns empty list when no events have risk_tag metadata', () {
    final events = [
      IncidentEvent(eventId: 'e1', incidentId: 'I1',
          type: IncidentEventType.incidentDetected,
          timestamp: '2026-04-07T08:00:00Z', metadata: {}),
    ];
    expect(IncidentRiskProjection.extractTags(events), isEmpty);
  });

  test('extracts tag and weight from event metadata', () {
    final events = [
      IncidentEvent(eventId: 'e1', incidentId: 'I1',
          type: IncidentEventType.incidentDetected,
          timestamp: '2026-04-07T08:00:00Z',
          metadata: {'risk_tag': 'perimeter_breach', 'weight': 30}),
    ];
    final tags = IncidentRiskProjection.extractTags(events);
    expect(tags.length, 1);
    expect(tags.first.tag, 'perimeter_breach');
    expect(tags.first.weight, 30);
  });

  test('skips events without risk_tag key', () {
    final events = [
      IncidentEvent(..., metadata: {'other_key': 'value'}),
      IncidentEvent(..., metadata: {'risk_tag': 'threat', 'weight': 10}),
    ];
    expect(IncidentRiskProjection.extractTags(events).length, 1);
  });
});

group('IncidentRiskProjection.computeRiskScore', () {
  test('returns 0 for empty tag list', () {
    expect(IncidentRiskProjection.computeRiskScore([]), 0);
  });

  test('sums all tag weights', () {
    final tags = [
      RiskTag(tag: 'a', weight: 30, addedAt: '2026-04-07T08:00:00Z'),
      RiskTag(tag: 'b', weight: 25, addedAt: '2026-04-07T08:01:00Z'),
    ];
    expect(IncidentRiskProjection.computeRiskScore(tags), 55);
  });
});

group('IncidentRiskProjection.deriveSeverity — boundary tests', () {
  test('score 79 → high (not critical)', () {
    expect(IncidentRiskProjection.deriveSeverity(79), IncidentSeverity.high);
  });

  test('score 80 → critical', () {
    expect(IncidentRiskProjection.deriveSeverity(80), IncidentSeverity.critical);
  });

  test('score 49 → medium (not high)', () {
    expect(IncidentRiskProjection.deriveSeverity(49), IncidentSeverity.medium);
  });

  test('score 50 → high', () {
    expect(IncidentRiskProjection.deriveSeverity(50), IncidentSeverity.high);
  });

  test('score 19 → low', () {
    expect(IncidentRiskProjection.deriveSeverity(19), IncidentSeverity.low);
  });

  test('score 20 → medium', () {
    expect(IncidentRiskProjection.deriveSeverity(20), IncidentSeverity.medium);
  });

  test('score 0 → low', () {
    expect(IncidentRiskProjection.deriveSeverity(0), IncidentSeverity.low);
  });
});
```

---

### P1 — `IncidentTimelineBuilder` (zero tests)

- **Action:** AUTO
- **Finding:** Maps all 9 `IncidentEventType` values to `TimelineEntry` labels. If any enum case is missing from the switch, Dart will not warn (non-exhaustive switch on an enum in a `void` context) and the event will produce no timeline entry — silent data loss. The sort by `timestamp` is also untested.
- **Why it matters:** Missing timeline entries = gap in incident audit trail. Silent loss is the worst failure mode for a security ops record.
- **Evidence:** `lib/domain/incidents/timeline/incident_timeline_builder.dart` lines 12–113.

**Exact test cases required** (`test/domain/incidents/timeline/incident_timeline_builder_test.dart`):

```dart
group('IncidentTimelineBuilder.build', () {
  test('returns empty list for empty input', () {
    expect(IncidentTimelineBuilder.build([]), isEmpty);
  });

  test('sorts events by timestamp before building entries', () {
    final events = [
      IncidentEvent(eventId: 'e2', incidentId: 'I1',
          type: IncidentEventType.incidentClassified,
          timestamp: '2026-04-07T08:05:00Z', metadata: {}),
      IncidentEvent(eventId: 'e1', incidentId: 'I1',
          type: IncidentEventType.incidentDetected,
          timestamp: '2026-04-07T08:00:00Z',
          metadata: {'type': 'intrusion', 'severity': 'high', 'geo_scope': 'zone-A'}),
    ];
    final timeline = IncidentTimelineBuilder.build(events);
    expect(timeline.first.label, 'Incident Detected');
    expect(timeline.last.label, 'Incident Classified');
  });

  // One test per IncidentEventType to catch any future enum gap:

  test('incidentDetected → label "Incident Detected" with type/severity/geo_scope metadata', () {
    final events = [
      IncidentEvent(eventId: 'e1', incidentId: 'I1',
          type: IncidentEventType.incidentDetected,
          timestamp: '2026-04-07T08:00:00Z',
          metadata: {'type': 'intrusion', 'severity': 'high', 'geo_scope': 'zone-A'}),
    ];
    final timeline = IncidentTimelineBuilder.build(events);
    expect(timeline.first.label, 'Incident Detected');
    expect(timeline.first.metadata['geo_scope'], 'zone-A');
  });

  test('incidentClassified → label "Incident Classified" with empty metadata', () {
    // metadata: {} → TimelineEntry.metadata == {}
  });

  test('incidentLinkedToDispatch → label "Dispatch Linked" with dispatch_id', () {
    // metadata: {'dispatch_id': 'D-42'} → entry.metadata['dispatch_id'] == 'D-42'
  });

  test('incidentEscalated → label "Escalated"', () {});

  test('incidentSlaBreached → label "SLA Breached" with due_at metadata', () {
    // metadata: {'due_at': '2026-04-07T09:00:00Z'} → entry.metadata['due_at'] preserved
  });

  test('incidentSlaClockDriftDetected → label "SLA Clock Drift Detected" with jump_seconds', () {
    // metadata: {'jump_seconds': 300} → entry.metadata['jump_seconds'] == 300
  });

  test('incidentSlaOverrideRecorded → label "SLA Override Recorded" with operator_id + reason', () {
    // metadata: {'operator_id': 'OP-1', 'reason': 'manual override'}
  });

  test('incidentResolved → label "Resolved"', () {});

  test('incidentClosed → label "Closed"', () {});

  test('all 9 event types in one stream produce 9 timeline entries', () {
    // Build one event for each IncidentEventType
    // Expect: timeline.length == 9
  });
});
```

---

### P1 — `TelegramRolePolicy` + `OnyxAuthorityScope` (zero tests)

- **Action:** REVIEW
- **Finding:** `TelegramRolePolicy.forRole` maps 4 roles to action sets. No test verifies the mapping. A typo or future merge conflict that drops an action from a role goes undetected. `OnyxAuthorityScope.allowsAction / allowsClient / allowsSite` contain normalisation logic (trim, empty-string wildcard) that is untested.
- **Why it matters:** These are security policy files. Wrong role mapping = privilege escalation or denial of access.
- **Evidence:** `lib/domain/authority/telegram_role_policy.dart` lines 13–33; `lib/domain/authority/onyx_authority_scope.dart` lines 22–40.

**Exact test cases required** (`test/domain/authority/telegram_role_policy_test.dart` + `onyx_authority_scope_test.dart`):

```dart
// telegram_role_policy_test.dart

group('TelegramRolePolicy.forRole', () {
  test('guard: can read and propose, cannot stage or execute', () {
    final policy = TelegramRolePolicy.forRole(OnyxAuthorityRole.guard);
    expect(policy.allowedActions, containsAll([OnyxAuthorityAction.read, OnyxAuthorityAction.propose]));
    expect(policy.allowedActions, isNot(contains(OnyxAuthorityAction.stage)));
    expect(policy.allowedActions, isNot(contains(OnyxAuthorityAction.execute)));
  });

  test('client: can read and propose, cannot stage or execute', () {
    // Same as guard — confirm both roles are intentionally equal
  });

  test('supervisor: can read, propose, and stage; cannot execute', () {
    final policy = TelegramRolePolicy.forRole(OnyxAuthorityRole.supervisor);
    expect(policy.allowedActions, contains(OnyxAuthorityAction.stage));
    expect(policy.allowedActions, isNot(contains(OnyxAuthorityAction.execute)));
  });

  test('admin: can read, propose, stage, and execute', () {
    final policy = TelegramRolePolicy.forRole(OnyxAuthorityRole.admin);
    expect(policy.allowedActions,
        containsAll([OnyxAuthorityAction.read, OnyxAuthorityAction.propose,
                     OnyxAuthorityAction.stage, OnyxAuthorityAction.execute]));
  });

  test('each role returns the correct role field', () {
    for (final role in OnyxAuthorityRole.values) {
      expect(TelegramRolePolicy.forRole(role).role, role);
    }
  });
});

// onyx_authority_scope_test.dart

group('OnyxAuthorityScope.allowsAction', () {
  test('returns true for action in set', () {
    final scope = OnyxAuthorityScope(
      principalId: 'P1', role: OnyxAuthorityRole.guard,
      allowedClientIds: {}, allowedSiteIds: {},
      allowedActions: {OnyxAuthorityAction.read},
    );
    expect(scope.allowsAction(OnyxAuthorityAction.read), isTrue);
    expect(scope.allowsAction(OnyxAuthorityAction.execute), isFalse);
  });
});

group('OnyxAuthorityScope.allowsClient', () {
  test('empty clientId is always allowed (wildcard behaviour)', () {
    final scope = OnyxAuthorityScope(
      principalId: 'P1', role: OnyxAuthorityRole.admin,
      allowedClientIds: {'C1'}, allowedSiteIds: {},
      allowedActions: {},
    );
    expect(scope.allowsClient(''), isTrue);
    expect(scope.allowsClient('  '), isTrue); // whitespace only → trimmed to empty
  });

  test('non-empty clientId not in set returns false', () {
    final scope = OnyxAuthorityScope(
      principalId: 'P1', role: OnyxAuthorityRole.admin,
      allowedClientIds: {'C1'}, allowedSiteIds: {},
      allowedActions: {},
    );
    expect(scope.allowsClient('C2'), isFalse);
  });

  test('clientId in set returns true', () {
    final scope = OnyxAuthorityScope(
      principalId: 'P1', role: OnyxAuthorityRole.admin,
      allowedClientIds: {'C1', 'C2'}, allowedSiteIds: {},
      allowedActions: {},
    );
    expect(scope.allowsClient('C1'), isTrue);
  });

  test('clientId with leading/trailing spaces is trimmed before check', () {
    final scope = OnyxAuthorityScope(
      principalId: 'P1', role: OnyxAuthorityRole.admin,
      allowedClientIds: {'C1'}, allowedSiteIds: {},
      allowedActions: {},
    );
    expect(scope.allowsClient('  C1  '), isTrue);
  });
});

group('OnyxAuthorityScope.allowsSite', () {
  // Mirrors allowsClient tests — same trim + empty-wildcard logic applies.
  test('empty siteId is always allowed', () { /* ... */ });
  test('siteId with spaces is trimmed', () { /* ... */ });
  test('unknown siteId returns false', () { /* ... */ });
});
```

---

### P1 — `SLATierFactory` (zero tests)

- **Action:** AUTO
- **Finding:** Three tiers (`core`, `protect`, `sovereign`) each have hard-coded minute thresholds for low/medium/high/critical SLA windows and corresponding weight multipliers. No test verifies these values. A future refactor that accidentally swaps or reorders tiers would go undetected.
- **Why it matters:** These values drive SLA breach evaluation for live incidents. Wrong values = wrong escalation timing.
- **Evidence:** `lib/domain/crm/sla_tier_factory.dart` lines 9–54.

**Exact test cases required** (`test/domain/crm/sla_tier_factory_test.dart`):

```dart
group('SLATierFactory.create — core', () {
  test('produces SLAProfile with correct minute thresholds for core tier', () {
    final profile = SLATierFactory.create(clientId: 'C1', tier: SLATier.core);
    expect(profile.clientId, 'C1');
    expect(profile.slaId, 'SLA-C1-core');
    expect(profile.lowMinutes, 180);
    expect(profile.mediumMinutes, 90);
    expect(profile.highMinutes, 45);
    expect(profile.criticalMinutes, 20);
  });

  test('core tier weight: criticalWeight is 3.0', () {
    final profile = SLATierFactory.create(clientId: 'C1', tier: SLATier.core);
    expect(profile.criticalWeight, 3.0);
  });
});

group('SLATierFactory.create — protect', () {
  test('protect tier has tighter thresholds than core', () {
    final protect = SLATierFactory.create(clientId: 'C1', tier: SLATier.protect);
    final core = SLATierFactory.create(clientId: 'C1', tier: SLATier.core);
    expect(protect.criticalMinutes, lessThan(core.criticalMinutes)); // 10 < 20
    expect(protect.highMinutes, lessThan(core.highMinutes));         // 30 < 45
  });

  test('protect tier criticalWeight is 5.0', () {
    final profile = SLATierFactory.create(clientId: 'C1', tier: SLATier.protect);
    expect(profile.criticalWeight, 5.0);
  });
});

group('SLATierFactory.create — sovereign', () {
  test('sovereign tier has tightest thresholds of all tiers', () {
    final sovereign = SLATierFactory.create(clientId: 'C1', tier: SLATier.sovereign);
    expect(sovereign.criticalMinutes, 5);
    expect(sovereign.highMinutes, 20);
    expect(sovereign.mediumMinutes, 45);
    expect(sovereign.lowMinutes, 90);
  });

  test('sovereign tier criticalWeight is 8.0', () {
    final profile = SLATierFactory.create(clientId: 'C1', tier: SLATier.sovereign);
    expect(profile.criticalWeight, 8.0);
  });
});

group('SLATierFactory.create — slaId', () {
  test('slaId includes clientId and tier name', () {
    for (final tier in SLATier.values) {
      final profile = SLATierFactory.create(clientId: 'CLIENT-X', tier: tier);
      expect(profile.slaId, contains('CLIENT-X'));
      expect(profile.slaId, contains(tier.name));
    }
  });
});
```

---

### P2 — `SLATierProjection` (zero tests)

- **Action:** AUTO
- **Finding:** Rebuilds the current SLA tier from a CRM event stream by filtering for `slaTierAssigned` events on the correct `aggregateId` and applying last-write-wins. Two bugs are possible: (1) events for a different `clientId` are incorrectly applied if the `aggregateId` filter is wrong; (2) an event with an unrecognised `tier` name causes `firstWhere` to throw `StateError`.
- **Why it matters:** Wrong tier returned = wrong SLA thresholds applied to a client's incidents.
- **Evidence:** `lib/domain/crm/sla_tier_projection.dart` lines 12–23.

**Exact test cases required** (`test/domain/crm/sla_tier_projection_test.dart`):

```dart
group('SLATierProjection.rebuild', () {
  test('returns null when no events exist for client', () {
    expect(
      SLATierProjection.rebuild(clientId: 'C1', events: []),
      isNull,
    );
  });

  test('returns null when events exist but none are slaTierAssigned', () {
    final events = [
      CRMEvent(eventId: 'e1', aggregateId: 'C1',
          type: CRMEventType.clientCreated,
          timestamp: '2026-04-07T08:00:00Z', payload: {}),
    ];
    expect(SLATierProjection.rebuild(clientId: 'C1', events: events), isNull);
  });

  test('returns tier from slaTierAssigned event', () {
    final events = [
      CRMEvent(eventId: 'e1', aggregateId: 'C1',
          type: CRMEventType.slaTierAssigned,
          timestamp: '2026-04-07T08:00:00Z',
          payload: {'clientId': 'C1', 'tier': 'protect', 'operatorId': 'OP-1'}),
    ];
    expect(SLATierProjection.rebuild(clientId: 'C1', events: events), SLATier.protect);
  });

  test('last slaTierAssigned wins (last-write-wins)', () {
    final events = [
      CRMEvent(eventId: 'e1', aggregateId: 'C1',
          type: CRMEventType.slaTierAssigned,
          timestamp: '2026-04-07T08:00:00Z',
          payload: {'tier': 'core'}),
      CRMEvent(eventId: 'e2', aggregateId: 'C1',
          type: CRMEventType.slaTierAssigned,
          timestamp: '2026-04-07T09:00:00Z',
          payload: {'tier': 'sovereign'}),
    ];
    expect(SLATierProjection.rebuild(clientId: 'C1', events: events), SLATier.sovereign);
  });

  test('events for a different clientId are ignored', () {
    final events = [
      CRMEvent(eventId: 'e1', aggregateId: 'C2', // different client
          type: CRMEventType.slaTierAssigned,
          timestamp: '2026-04-07T08:00:00Z',
          payload: {'tier': 'sovereign'}),
    ];
    expect(SLATierProjection.rebuild(clientId: 'C1', events: events), isNull);
  });
});
```

---

### P2 — `ExecutiveSummaryGenerator` (zero tests)

- **Action:** AUTO
- **Finding:** Generates narrative strings using threshold branches on `slaComplianceRate` (0.95 / 0.85) and `totalSlaBreaches` (0 / 3). The exact string content and tier name uppercasing are untested. Any change to these thresholds or strings silently breaks downstream report expectations.
- **Why it matters:** These strings appear directly in client-facing reports. Wrong headline at wrong compliance level misrepresents operational status.
- **Evidence:** `lib/domain/crm/reporting/executive_summary_generator.dart` lines 21–56.

**Exact test cases required** (`test/domain/crm/reporting/executive_summary_generator_test.dart`):

```dart
MonthlyReport _report({
  required double slaComplianceRate,
  required int totalSlaBreaches,
  int totalIncidents = 5,
  int totalEscalations = 1,
  int totalSlaOverrides = 0,
  String slaTierName = 'protect',
}) => MonthlyReport(
  clientId: 'C1',
  month: '2026-04',
  slaTierName: slaTierName,
  totalIncidents: totalIncidents,
  totalEscalations: totalEscalations,
  totalSlaBreaches: totalSlaBreaches,
  totalSlaOverrides: totalSlaOverrides,
  totalClientContacts: 0,
  slaComplianceRate: slaComplianceRate,
);

group('ExecutiveSummaryGenerator — headline', () {
  test('slaComplianceRate >= 0.95 → strong adherence headline', () {
    final summary = ExecutiveSummaryGenerator.generate(_report(
        slaComplianceRate: 0.95, totalSlaBreaches: 0));
    expect(summary.headline, contains('strong SLA adherence'));
  });

  test('slaComplianceRate 0.85..0.949 → minor variances headline', () {
    final summary = ExecutiveSummaryGenerator.generate(_report(
        slaComplianceRate: 0.85, totalSlaBreaches: 1));
    expect(summary.headline, contains('minor SLA variances'));
  });

  test('slaComplianceRate 0.849 → risk exposure headline', () {
    final summary = ExecutiveSummaryGenerator.generate(_report(
        slaComplianceRate: 0.849, totalSlaBreaches: 5));
    expect(summary.headline, contains('SLA risk exposure'));
  });
});

group('ExecutiveSummaryGenerator — SLA summary', () {
  test('tier name is uppercased in SLA summary', () {
    final summary = ExecutiveSummaryGenerator.generate(_report(
        slaComplianceRate: 0.95, totalSlaBreaches: 0, slaTierName: 'sovereign'));
    expect(summary.slaSummary, contains('SOVEREIGN'));
  });

  test('compliance percentage is formatted to 1 decimal place', () {
    final summary = ExecutiveSummaryGenerator.generate(_report(
        slaComplianceRate: 0.923, totalSlaBreaches: 0));
    expect(summary.slaSummary, contains('92.3%'));
  });

  test('breach count is included in SLA summary', () {
    final summary = ExecutiveSummaryGenerator.generate(_report(
        slaComplianceRate: 0.90, totalSlaBreaches: 3));
    expect(summary.slaSummary, contains('3 breach'));
  });
});

group('ExecutiveSummaryGenerator — risk summary', () {
  test('0 breaches → no structural risk pattern', () {
    final summary = ExecutiveSummaryGenerator.generate(_report(
        slaComplianceRate: 0.99, totalSlaBreaches: 0));
    expect(summary.riskSummary, contains('No structural SLA risk'));
  });

  test('1–3 breaches → isolated, manageable', () {
    final summary = ExecutiveSummaryGenerator.generate(_report(
        slaComplianceRate: 0.90, totalSlaBreaches: 3));
    expect(summary.riskSummary, contains('manageable tolerance'));
  });

  test('4+ breaches → systemic risk requiring review', () {
    final summary = ExecutiveSummaryGenerator.generate(_report(
        slaComplianceRate: 0.80, totalSlaBreaches: 4));
    expect(summary.riskSummary, contains('systemic risk'));
  });
});

group('ExecutiveSummaryGenerator — performance summary', () {
  test('includes totalIncidents and totalEscalations in text', () {
    final summary = ExecutiveSummaryGenerator.generate(_report(
        slaComplianceRate: 0.95, totalSlaBreaches: 0,
        totalIncidents: 12, totalEscalations: 3));
    expect(summary.performanceSummary, contains('12'));
    expect(summary.performanceSummary, contains('3'));
  });
});
```

---

### P2 — `InMemoryEventStore` (zero tests)

- **Action:** AUTO
- **Finding:** The in-memory event store has duplicate-ID protection (throws `StateError`), sequence auto-increment via `copyWithSequence`, and immutable `allEvents()`. None of these behaviours are tested. The `clear()` method also resets sequence to 0 — sequence continuity after clear is an important invariant.
- **Why it matters:** The event store is the write path for all dispatch events. A bug in sequence assignment or duplicate filtering corrupts the entire aggregate rebuild.
- **Evidence:** `lib/domain/store/in_memory_event_store.dart` lines 11–33.

**Exact test cases required** (`test/domain/store/in_memory_event_store_test.dart`):

```dart
group('InMemoryEventStore', () {
  test('appended event is assigned sequence 1 on first append', () {
    final store = InMemoryEventStore();
    store.append(DecisionCreated(
        eventId: 'e1', sequence: 0, version: 1, occurredAt: DateTime.utc(2026,4,7),
        dispatchId: 'D1', clientId: 'C1', regionId: 'R1', siteId: 'S1'));
    expect(store.allEvents().first.sequence, 1);
  });

  test('sequence increments monotonically across appends', () {
    final store = InMemoryEventStore();
    store.append(DecisionCreated(..., eventId: 'e1', sequence: 0, ...));
    store.append(ExecutionCompleted(..., eventId: 'e2', sequence: 0, ...));
    final events = store.allEvents();
    expect(events[0].sequence, 1);
    expect(events[1].sequence, 2);
  });

  test('duplicate eventId throws StateError', () {
    final store = InMemoryEventStore();
    store.append(DecisionCreated(..., eventId: 'DUP', sequence: 0, ...));
    expect(
      () => store.append(DecisionCreated(..., eventId: 'DUP', sequence: 0, ...)),
      throwsA(isA<StateError>()),
    );
  });

  test('duplicate detection does not prevent different eventIds', () {
    final store = InMemoryEventStore();
    store.append(DecisionCreated(..., eventId: 'e1', ...));
    expect(() => store.append(DecisionCreated(..., eventId: 'e2', ...)),
        returnsNormally);
  });

  test('allEvents returns unmodifiable list', () {
    final store = InMemoryEventStore();
    store.append(DecisionCreated(..., eventId: 'e1', ...));
    expect(() => (store.allEvents() as List).add(null),
        throwsUnsupportedError);
  });

  test('clear resets store: no events, sequence restarts at 1', () {
    final store = InMemoryEventStore();
    store.append(DecisionCreated(..., eventId: 'e1', ...));
    store.clear();
    expect(store.allEvents(), isEmpty);
    // After clear, next append should get sequence 1 again
    store.append(DecisionCreated(..., eventId: 'e2', ...));
    expect(store.allEvents().first.sequence, 1);
  });

  test('clear allows previously-used eventId to be reused', () {
    final store = InMemoryEventStore();
    store.append(DecisionCreated(..., eventId: 'e1', ...));
    store.clear();
    expect(() => store.append(DecisionCreated(..., eventId: 'e1', ...)),
        returnsNormally);
  });
});
```

---

## Duplication

- `lib/domain/policy/risk_policy.dart`, `lib/domain/risk/risk_policy.dart`, and `lib/domain/intelligence/risk_policy.dart` are three separate files with very similar or identical names. The canonical test (`test/domain/risk_policy_canonical_test.dart`) exists but it is unclear which file it exercises. This is an existing structural issue already noted in prior audits — surfaced here because any new risk policy tests must target the correct canonical file.

---

## Coverage Gaps — Summary Table

| File | Lines | Complexity | Priority |
|------|-------|------------|----------|
| `projection/operations_health_projection.dart` | 351 | Very High | P1 |
| `aggregate/dispatch_aggregate.dart` | 35 | Low-Medium | P1 |
| `projection/dispatch_projection.dart` | 80 | Medium | P1 |
| `projection/dashboard_overview_projection.dart` | 94 | Medium | P1 |
| `incidents/risk/incident_risk_projection.dart` | 34 | Low | P1 |
| `incidents/timeline/incident_timeline_builder.dart` | 114 | Medium | P1 |
| `authority/telegram_role_policy.dart` + `onyx_authority_scope.dart` | 35 + 41 | Low | P1 (security) |
| `crm/sla_tier_factory.dart` | 56 | Low | P1 (data) |
| `crm/sla_tier_projection.dart` | 25 | Low | P2 |
| `crm/reporting/executive_summary_generator.dart` | 57 | Low-Medium | P2 |
| `store/in_memory_event_store.dart` | 34 | Low | P2 |

**Additional zero-test files not in top 10 but warranting eventual coverage:**
- `crm/reporting/monthly_report_projection.dart` — month-boundary calculation has off-by-one risk (`add(32 days).copyWith(day:1).subtract(1s)`)
- `crm/reporting/multi_site_comparison_projection.dart` — SLA compliance formula: `1.0 - (breaches / incidents)` with no floor clamp; `breaches > incidents` is possible
- `crm/store/crm_event_log.dart` — `byClient` filter correctness
- `incidents/incidents/client/client_incident_log_projection.dart` — zero test
- `alarms/contact_id_event_mapper.dart` — currently a stub; no tests needed until implemented

---

## Performance / Stability Notes

- `OperationsHealthProjection.build` iterates the full event list in a single pass (O(n)) — acceptable. However, `liveSignals.reversed.take(7)` allocates a reversed iterable over the entire accumulated list on each build call. If signal accumulation is unbounded (no cap on the intermediate `liveSignals` list before reversal), this becomes a memory concern on long-running sessions with thousands of events.
- `MonthlyReportProjection.build` computes month boundaries using `DateTime.parse('$month-01T00:00:00Z').add(Duration(days: 32)).copyWith(day: 1)`. This is a fragile pattern — `add(32)` from a 28-day month (February) may drift into the wrong month if the `copyWith(day: 1)` assumption is violated. Recommend replacing with a standard `endOfMonth` utility.
- `SLATierProjection.rebuild` calls `SLATier.values.firstWhere((t) => t.name == tierName)` without a fallback `orElse`. If a stale event payload contains an unknown tier string, this throws `StateError` at projection time, crashing the caller silently.

---

## Recommended Fix Order

1. `test/domain/projection/operations_health_projection_test.dart` — highest complexity, drives live dashboard
2. `test/domain/aggregate/dispatch_aggregate_test.dart` — aggregate root, all downstream projections depend on correctness
3. `test/domain/projection/dispatch_projection_test.dart` — primary read model
4. `test/domain/authority/telegram_role_policy_test.dart` + `onyx_authority_scope_test.dart` — security policy
5. `test/domain/incidents/risk/incident_risk_projection_test.dart` — threshold policy
6. `test/domain/incidents/timeline/incident_timeline_builder_test.dart` — exhaustive enum coverage
7. `test/domain/crm/sla_tier_factory_test.dart` — hard-coded SLA data
8. `test/domain/projection/dashboard_overview_projection_test.dart` — status ranking policy
9. `test/domain/store/in_memory_event_store_test.dart` — write path integrity
10. `test/domain/crm/sla_tier_projection_test.dart` + `executive_summary_generator_test.dart` — reporting correctness
