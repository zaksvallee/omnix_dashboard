# ONYX Controller Feature Breakdown

## 1) Purpose
This handbook is for control-room onboarding. It explains what every active ONYX route is for, what each major widget does, and which buttons/controllers are available in production-facing UI flows.

Scope covered in this document:
- Global navigation and shell behavior
- Dashboard
- Clients
- Sites
- Guards (Android Guard App Shell simulator)
- Dispatches
- Events
- Ledger
- Reports

## 2) Global Navigation (Left Sidebar)
Primary route tabs:
- `Dashboard`
- `Clients`
- `Sites`
- `Guards`
- `Dispatches`
- `Events`
- `Ledger`
- `Reports`

Controller expectation:
- Treat left navigation as the operational lane switch.
- Keep active incident handling in `Dispatches`, guard sync/escalation in `Guards`, and evidence/replay verification in `Ledger` + `Reports`.

## 3) Widget Legend (Common Across Pages)
Standard reusable widgets you will see repeatedly:
- `OnyxPageHeader`: Page title/subtitle and top-right action buttons.
- `OnyxSummaryStat`: KPI card (label + value + accent color).
- `OnyxSectionCard`: Section/panel container with title/subtitle and inner controls.
- `OnyxEmptyState`: No-data fallback.
- Chips/Pills: Quick state markers (status, mode, filter, queue health).
- Table/List rows: Timeline, queue, roster, diagnostics, and history records.

Operational reading rule:
- Blue accents = info/state.
- Green accents = healthy/verified/success.
- Amber accents = warning/watch.
- Red accents = fail/critical/action needed.

## 4) Route-by-Route Breakdown

### 4.1 Dashboard
Primary purpose:
- Executive operations snapshot and guard-sync health triage.

Core panels/features:
- Operations threat posture and command pressure snapshot.
- Guard sync health panel with queue/failure/staleness telemetry.
- Policy outcome telemetry and coaching telemetry.
- Recent failure traces and operational signal summaries.

Action buttons (controller-facing):
- `Open Guard Sync`
- `Clear Policy Telemetry`
- `Copy Failure Trace`
- `Share Failure Trace`
- `Email Failure Trace`
- `Download Failure Trace`
- `Copy Policy Telemetry JSON`
- `Copy Policy Telemetry CSV`
- `Download Policy JSON`
- `Download Policy CSV`
- `Share Policy Pack`
- `Copy Coaching Telemetry JSON`
- `Copy Coaching Telemetry CSV`
- `Download Coaching JSON`
- `Share Coaching Pack`

When to use:
- Start of shift, after incidents, and before handover.

---

### 4.2 Clients
Primary purpose:
- Client-facing comms simulation surface for notifications, acknowledgements, incident feed, and chat lanes.

Major features/widgets:
- Viewer role chips:
  - `Client View`
  - `Control View`
  - `Resident View`
- KPI cards:
  - alerts
  - active incidents
  - estate rooms
  - thread volume
  - pending acknowledgements
  - push queue readiness
- `Push Delivery Queue` panel:
  - queue state (`Queued` / `Delivered`)
  - push sync history
  - backend probe history
- Incident feed panel:
  - grouped milestone timeline by dispatch reference
  - open/collapse per incident thread
  - detail drawer/dialog
- Notification/Rooms/Chat tri-panel:
  - lane focus (`Residents`, `Trustees`, `Security Desk`, etc.)
  - pending vs all toggle
  - per-role action labels

Key actions/buttons:
- `Show all` / `Show pending`
- `Retry Push Sync`
- `Run Backend Probe`
- `Clear Probe History`
- Notification actions (role-aware), examples:
  - `Request ETA for ...`
  - `Review Advisory for ...`
  - `Send Advisory to ...`
  - `Open Dispatch Draft for ...`
- Acknowledgement actions:
  - `Client Ack`
  - `Control Ack`
  - `Resident Seen`
- Composer send flow:
  - `Send`
  - quick-draft actions
  - status badge (`Ready: ...`)

Controller training focus:
- Understand lane-specific message targeting and acknowledgement accountability.

---

### 4.3 Sites
Primary purpose:
- Multi-site posture and site-level operational drilldown.

Major features/widgets:
- Site roster (left): health + active dispatch exposure per site.
- Site detail panel (right):
  - dispatch outcome mix
  - guards engaged
  - recent site events
  - health score and status tinting

Interaction model:
- Select site from roster.
- Review health, active dispatches, and recent operational trace.

---

### 4.4 Guards (Active Route = Android Guard App Shell)
Primary purpose:
- Controller/supervisor/reaction simulation for guard mobile operations and sync governance.

Major feature blocks:
- Screen-flow chips:
  - `Shift Start`
  - `Dispatch`
  - `Status`
  - `Checkpoint`
  - `Panic`
  - `Sync`
- Operator role modes:
  - Guard
  - Reaction
  - Supervisor
- Queue and sync telemetry:
  - pending/synced/failed filters
  - operation mode filters
  - facade/provider filters
  - scoped selection state
- Coaching and governance:
  - prompt cards
  - acknowledgements
  - snooze controls
- Export/audit utilities:
  - closeout packet
  - shift replay summary
  - sync report
  - export audit timeline

Key actions/buttons:
- Shift:
  - `Capture + Start Shift`
  - `Queue Shift End`
- Dispatch/status:
  - `Accept Incident`
  - `Mark Arrived`
  - status queue actions (`En Route`, `On Site`, `Clear`, `Offline`)
  - supervisor override actions
- Patrol + safety:
  - `Queue Checkpoint Scan`
  - `Queue Patrol Image`
  - `Trigger Panic`
  - `Queue Wearable Heartbeat`
  - `Queue Device Health`
- Sync ops:
  - `Sync Now`
  - `Retry Failed Events`
  - `Retry Failed Media`
  - `Resolve Sync Failures`
  - `Clear Queue`
- Telemetry bridge:
  - `Probe Telemetry Provider`
  - `Seed Wearable Bridge`
  - `Emit Debug SDK Heartbeat`
  - `Replay Payload (Legacy)`
- Export:
  - `Dispatch Closeout Packet`
  - `Copy Shift Replay Summary`
  - `Copy Sync Report`
  - `Clear Export Audits`

Controller training focus:
- Queue reliability, failure recovery, and telemetry facade readiness interpretation.

---

### 4.5 Dispatches
Primary purpose:
- Command center for dispatch generation, ingestion, stress harnessing, benchmark telemetry, saved views/snapshots, and intelligence triage.

Top command band actions:
- `Generate Dispatch`
- `Ingest Live Feeds`
- `Ingest News Intel`
- `Load Feed File`
- `Start Feed Polling` / `Stop Feed Polling`

Core workspaces:
- System status + source diagnostics:
  - provider health
  - missing config
  - runtime/supabase/telemetry readiness hints
  - news diagnostics modal and probe actions
- Control workspace:
  - scenario controls (seed, chunks, bursts, thresholds)
  - stress/soak/benchmark run controls
  - telemetry reset + persistence controls
  - draft metadata controls
- Import/export toolchain:
  - telemetry JSON/CSV copy/import
  - snapshot JSON/file copy/import/download/load
  - profile JSON copy/import
- Saved views + snapshot inspector:
  - merge/replace modes
  - collision diffs
  - incoming-only names
  - per-view selection imports
- Active dispatch queue:
  - execute/deny progression
  - response and closure timeline details
- Intelligence triage:
  - pin watch, dismiss, restore
  - escalation to dispatch
  - source/action filters

High-frequency buttons:
- `Run Stress Burst`
- `Run Soak x3`
- `Run Benchmark Suite`
- `Reset Telemetry`
- `Clear Saved History`
- `Clear Poll Health`
- `Clear Saved Views`
- `Clear Saved Draft`
- `Copy Telemetry JSON`
- `Import Telemetry JSON`
- `Copy Telemetry CSV`
- `Copy Snapshot JSON`
- `Download Snapshot File`
- `Import Snapshot JSON`
- `Load Snapshot File`
- `Copy Profile JSON`
- `Import Profile JSON`
- `News Source Diagnostics`
- `Run Probe` / `Reprobe ...`

Controller training focus:
- Distinguish ingest reliability operations from incident execution operations.

---

### 4.6 Events
Primary purpose:
- Forensic timeline review with calmer detail presentation.

Major features:
- Timeline feed (newest first)
- Filter bar:
  - type filter
  - site filter
  - guard filter
  - time-window filter
- Detail panel/drawer for selected event
- Summary strip showing filtered vs total context

Interaction:
- Select row -> open detail pane.
- Narrow scope with filters during investigation.

---

### 4.7 Ledger
Primary purpose:
- Evidence continuity and integrity verification.

Major features:
- Source mode:
  - Supabase ledger rows (when configured)
  - in-memory EventStore fallback
- Summary stats:
  - source
  - row count
  - integrity state
- Runtime warning strip when fallback mode is active
- Timeline rows with sequence/time/hash context

Key action:
- `Verify Chain` (recomputes hash-chain integrity).

Controller training focus:
- Always verify before formal evidence export/share.

---

### 4.8 Reports
Primary purpose:
- Deterministic PDF generation + replay verification using report receipts.

Report harness actions:
- `Preview Report`
- `Refresh Replay Verification`
- Open any receipt row for deterministic regeneration.

Report preview actions:
- Back
- `Print`
- `Download` (PDF share/export flow)

Major widgets:
- receipt/replay/range KPI strip
- receipt integrity card (hash + range + replay match)
- embedded PDF preview pane

Controller training focus:
- Report delivery is only valid after replay match is confirmed.

## 5) Controller Study Plan (Suggested)
1. Learn route intent and escalation order: `Dispatches -> Guards -> Ledger -> Reports`.
2. Drill Clients lane targeting and acknowledgement controls.
3. Run Dispatches ingest and diagnostics drills (including failed probe flows).
4. Run Guard sync failure/retry drills.
5. Execute evidence workflow: incident -> ledger verify -> report preview -> print/download.

## 6) Quick Command Sequences for Training Sessions
- Daily opening:
  1. `Dashboard` health sweep.
  2. `Dispatches` source diagnostics + poll status.
  3. `Guards` sync queue check.
- Incident cycle:
  1. `Dispatches` generate/execute.
  2. `Clients` send advisory + capture acks.
  3. `Guards` monitor arrival/status updates.
  4. `Ledger` verify chain.
  5. `Reports` produce deterministic PDF.

## 7) Notes
- Locale-aware client comms labels are enforced with automated key-completeness tests.
- Supabase disabled mode explicitly surfaces fallback banners in Clients and Ledger routes.
- Guard telemetry + sync surfaces are designed to continue operating in queue-first mode during degraded connectivity.
