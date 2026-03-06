# ONYX Daily Controller Shift Checklist (One-Page)

Date: ____________  Shift: ____________  Controller: ____________

## 1) Shift Start (First 10 Minutes)
- [ ] Open `Dashboard` and confirm overall posture (`STABLE`/`ELEVATED`/`CRITICAL`).
- [ ] Review guard sync state: queue depth, failed events/media, stale sync indicator.
- [ ] If alerting thresholds are exceeded, open `Guards` immediately.
- [ ] Open `Dispatches` and confirm:
  - [ ] ingest readiness
  - [ ] provider diagnostics
  - [ ] polling state (if live feed is configured)
- [ ] Confirm runtime health hints:
  - [ ] Supabase live (or fallback mode acknowledged)
  - [ ] telemetry provider readiness understood

## 2) Live Monitoring Loop (Repeat Every 30-60 Minutes)
- [ ] `Dispatches`: check active queue and intelligence triage.
- [ ] `Clients`: confirm pending acknowledgements are reducing.
- [ ] `Guards`: confirm pending/failed operations are not drifting upward.
- [ ] `Events`: spot-check timeline for anomalies or sequence gaps.
- [ ] `Ledger`: run quick chain check if a high-risk incident occurred.

## 3) Incident Handling Flow (Per Incident)
- [ ] Create/ingest and process in `Dispatches`.
- [ ] Confirm execution status updates in dispatch queue.
- [ ] Push/update communications in `Clients` to correct lane/audience.
- [ ] Confirm field progress in `Guards` (`En Route` -> `On Site` -> `Clear`).
- [ ] Verify closure and timeline consistency in `Events`.
- [ ] If evidence required: `Ledger` -> `Verify Chain`.
- [ ] If client report required: `Reports` -> preview -> replay verify -> download/print.

## 4) If Degraded/Failure State Appears
- [ ] In `Guards`, run `Sync Now`.
- [ ] Retry `Failed Events` and `Failed Media`.
- [ ] Probe telemetry provider and confirm facade/readiness status.
- [ ] Export failure trace and notify supervisor if failures persist.
- [ ] Log root cause (network/provider/config/operator).

## 5) Mid-Shift Supervisor Snapshot
- [ ] Dispatch queue state shared.
- [ ] Guard sync health shared.
- [ ] Critical/pinned intelligence items shared.
- [ ] Any unresolved telemetry/provider issues shared.

## 6) Shift Handover (Final 15 Minutes)
- [ ] `Dashboard`: final posture + guard sync health captured.
- [ ] `Dispatches`: unresolved incidents listed with current status.
- [ ] `Clients`: outstanding acknowledgements listed by lane.
- [ ] `Guards`: failed/pending operations summary recorded.
- [ ] `Ledger`: chain verification result recorded for critical incidents.
- [ ] `Reports`: generated outputs and receipt replay state recorded.
- [ ] Exported artifacts handed over (if applicable):
  - [ ] failure trace
  - [ ] sync report
  - [ ] closeout packet
  - [ ] PDF report

## 7) Handover Notes
1. ______________________________________________________
2. ______________________________________________________
3. ______________________________________________________

Incoming controller acknowledged: ____________________  Time: ____________
