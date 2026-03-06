# ONYX Controller Assessment Checklist

## 1) Use
This checklist is for controller onboarding, probation sign-off, and refresher audits.

Scoring model:
- `2` = Completed independently and correctly
- `1` = Completed with coaching or partial correctness
- `0` = Not completed / incorrect

Suggested pass thresholds:
- Route-level pass: `>= 80%`
- Overall onboarding pass: `>= 85%`
- Critical lanes (`Dispatches`, `Guards`, `Ledger`) must each be `>= 80%`

---

## 2) Global Skills (Core)

| Task | Score (0-2) | Notes |
|---|---:|---|
| Navigate correctly between all left-sidebar routes without guidance |  |  |
| Explain meaning of KPI color states (info/healthy/warn/critical) |  |  |
| Identify when to use `Dispatches` vs `Guards` vs `Ledger` vs `Reports` |  |  |
| Follow incident chain: detect -> dispatch -> field update -> verify -> report |  |  |

Subtotal (Core): ____ / 8

---

## 3) Dashboard Assessment

| Task | Score (0-2) | Notes |
|---|---:|---|
| Read current guard sync health and identify whether state is stable/at risk |  |  |
| Open Guard Sync from Dashboard and explain why |  |  |
| Interpret queue pressure, failures, stale sync indicators |  |  |
| Export and share a failure/policy/coaching telemetry artifact |  |  |
| Clear policy telemetry only when instructed and state impact |  |  |

Subtotal (Dashboard): ____ / 10

---

## 4) Clients Route Assessment

| Task | Score (0-2) | Notes |
|---|---:|---|
| Switch viewer role (`Client/Control/Resident`) and explain lane impact |  |  |
| Toggle `Show all` / `Show pending` and explain operational difference |  |  |
| Select correct room/lane for incident communication |  |  |
| Use acknowledgement controls (`Client Ack`, `Control Ack`, `Resident Seen`) correctly |  |  |
| Use notification actions (draft/send-now) without wrong audience targeting |  |  |
| Open incident detail and identify current status/milestones |  |  |
| Read push queue status and interpret sync/probe lines |  |  |
| Execute `Run Backend Probe` and explain result |  |  |

Subtotal (Clients): ____ / 16

---

## 5) Sites Route Assessment

| Task | Score (0-2) | Notes |
|---|---:|---|
| Select site from roster and explain health score + status |  |  |
| Identify active dispatch exposure and recent events for selected site |  |  |
| Explain when site health requires dispatch or supervisor escalation |  |  |

Subtotal (Sites): ____ / 6

---

## 6) Guards Route Assessment (Android Guard Shell)

| Task | Score (0-2) | Notes |
|---|---:|---|
| Move through all guard flow screens (`Shift Start`, `Dispatch`, `Status`, `Checkpoint`, `Panic`, `Sync`) |  |  |
| Queue shift start/end correctly |  |  |
| Queue dispatch acceptance and status transitions correctly |  |  |
| Queue checkpoint scan and patrol image event correctly |  |  |
| Trigger and clear panic flow correctly |  |  |
| Interpret pending/synced/failed filters and scope selection state |  |  |
| Run `Sync Now` and explain expected post-sync state |  |  |
| Retry failed events/media correctly |  |  |
| Use telemetry probe and explain facade readiness outcome |  |  |
| Generate closeout/replay/sync report exports and identify audit timeline |  |  |

Subtotal (Guards): ____ / 20

---

## 7) Dispatches Route Assessment

| Task | Score (0-2) | Notes |
|---|---:|---|
| Explain top command actions (`Generate Dispatch`, ingest actions) |  |  |
| Run diagnostics and identify missing vs configured vs failing providers |  |  |
| Execute a stress/soak/benchmark action and read resulting status KPIs |  |  |
| Manage snapshot/profile import/export flows correctly |  |  |
| Use saved-view/snapshot inspector to interpret merge/replace and collision diffs |  |  |
| Triaging intelligence: pin, dismiss, restore, escalate correctly |  |  |
| Confirm runtime readiness strips (supabase/telemetry/polling) |  |  |
| Move dispatch through queue execution lifecycle correctly |  |  |

Subtotal (Dispatches): ____ / 16

---

## 8) Events Route Assessment

| Task | Score (0-2) | Notes |
|---|---:|---|
| Apply event filters (type/site/guard/time) to isolate target incident |  |  |
| Select event and interpret detail pane accurately |  |  |
| Identify sequence and timeline ordering correctly |  |  |

Subtotal (Events): ____ / 6

---

## 9) Ledger Route Assessment

| Task | Score (0-2) | Notes |
|---|---:|---|
| Explain ledger source mode (`Supabase` vs `EventStore fallback`) |  |  |
| Run `Verify Chain` and interpret result |  |  |
| Explain what to do when integrity state is `Failed` |  |  |
| Identify runtime fallback warning and required operator action |  |  |

Subtotal (Ledger): ____ / 8

---

## 10) Reports Route Assessment

| Task | Score (0-2) | Notes |
|---|---:|---|
| Generate a report preview for current client/site scope |  |  |
| Refresh replay verification and interpret `Matched` vs `Review/Failed` |  |  |
| Open historical receipt and confirm deterministic replay behavior |  |  |
| Print/download workflow executed correctly |  |  |

Subtotal (Reports): ____ / 8

---

## 11) Scenario Drills

### Drill A: Standard Dispatch Cycle
1. Generate/ingest incident in `Dispatches`
2. Send client comms in `Clients`
3. Confirm field progression in `Guards`
4. Verify evidence in `Ledger`
5. Produce PDF in `Reports`

Score (0-10): ____ / 10

### Drill B: Degraded Connectivity + Recovery
1. Identify queue growth in `Guards`
2. Run retry/sync actions
3. Confirm reduced failure state
4. Document outcome via export

Score (0-10): ____ / 10

---

## 12) Final Scoring

| Section | Max | Score |
|---|---:|---:|
| Core | 8 |  |
| Dashboard | 10 |  |
| Clients | 16 |  |
| Sites | 6 |  |
| Guards | 20 |  |
| Dispatches | 16 |  |
| Events | 6 |  |
| Ledger | 8 |  |
| Reports | 8 |  |
| Drill A | 10 |  |
| Drill B | 10 |  |
| **Total** | **118** |  |

Final percentage: `Total / 118 * 100 = ____ %`

Result:
- [ ] Pass
- [ ] Conditional Pass (needs targeted retraining)
- [ ] Fail (repeat onboarding)

---

## 13) Sign-Off

Controller name: ____________________  
Assessor name: ____________________  
Date: ____________________  

Operational notes:

1. ___________________________________________
2. ___________________________________________
3. ___________________________________________
