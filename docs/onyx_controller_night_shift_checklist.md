# ONYX Night Shift Controller Checklist

Date: ____________  Shift: ____________  Controller: ____________

## 1) Pre-Shift Hard Gate (First 10 Minutes)
- [ ] `Dashboard`: confirm current threat posture and note baseline.
- [ ] `Dispatches`: run news/source diagnostics and confirm ingest lane state.
- [ ] `Guards`: confirm sync queue baseline (`pending`, `failed`, `stale`).
- [ ] `Clients`: confirm push lane healthy (sync/probe status visible).
- [ ] Record baseline counts:
  - Pending guard events: ______
  - Failed guard events: ______
  - Failed guard media: ______
  - Active dispatches: ______

## 2) Night Monitoring Cadence (Strict)
- Every **15 minutes**:
  - [ ] `Dispatches`: active queue + fresh intelligence triage
  - [ ] `Guards`: queue drift and failed op checks
- Every **30 minutes**:
  - [ ] `Clients`: pending acknowledgements + push queue health
  - [ ] `Events`: timeline sanity check for new anomalies
- Every **60 minutes**:
  - [ ] `Dashboard`: posture refresh + threshold verification

## 3) Fast Escalation Triggers (Night)
Escalate to supervisor immediately if any occur:
- [ ] Guard failed events >= configured critical threshold
- [ ] Guard failed media >= configured critical threshold
- [ ] Queue depth exceeds critical pressure threshold
- [ ] Last successful sync exceeds stale-sync threshold
- [ ] Telemetry provider readiness drops from `ready` to degraded/offline
- [ ] Repeated dispatches from same site/zone within short window

Escalation logged at: ____________  Supervisor notified: ____________

## 4) Incident Execution (Night Protocol)
For each incident:
1. [ ] `Dispatches`: verify intake -> action -> status progression.
2. [ ] `Clients`: send role-correct advisory/update to required lane.
3. [ ] `Guards`: confirm field transitions (`En Route`, `On Site`, `Clear`).
4. [ ] `Events`: verify timeline sequence and closure signal.
5. [ ] `Ledger`: run chain verification for critical incidents.
6. [ ] `Reports`: generate and verify replay-safe PDF if required.

## 5) Degraded Operations Playbook
If sync/telemetry degrades:
- [ ] `Guards`: `Sync Now`
- [ ] `Retry Failed Events`
- [ ] `Retry Failed Media`
- [ ] `Probe Telemetry Provider`
- [ ] Export artifacts:
  - [ ] failure trace
  - [ ] sync report
  - [ ] closeout packet (if incident-related)
- [ ] Record root cause guess:
  - [ ] network
  - [ ] provider/API
  - [ ] runtime config
  - [ ] operator/action

## 6) High-Risk Hour Focus (Configurable)
Mark high-risk windows for tighter attention:
- Window A: ______ to ______  Zone/Site: __________________
- Window B: ______ to ______  Zone/Site: __________________

During each high-risk window:
- [ ] 10-minute checks on `Dispatches` and `Guards`
- [ ] active advisory lane watch in `Clients`
- [ ] immediate escalation on repeat anomaly patterns

## 7) End-of-Shift Handover (Final 20 Minutes)
- [ ] `Dashboard` summary captured.
- [ ] Open/active dispatch list prepared.
- [ ] Pending acknowledgements by lane prepared.
- [ ] Guard sync backlog and failures documented.
- [ ] Ledger verification results logged for critical incidents.
- [ ] Report outputs and replay status logged.

Handover package includes:
- [ ] incident summary
- [ ] unresolved actions
- [ ] exported evidence artifacts
- [ ] escalation notes

## 8) Handover Notes
1. ______________________________________________________
2. ______________________________________________________
3. ______________________________________________________

Incoming controller acknowledged: ____________________  Time: ____________
