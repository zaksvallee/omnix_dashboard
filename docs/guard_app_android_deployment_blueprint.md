# ONYX Guard App (Android) Deployment Blueprint

## Objective
Deliver an Android-first Guard App linked to ONYX command/control with:
- dispatch receive + acknowledgement
- status updates
- NFC checkpoint verification
- panic signaling
- GPS heartbeat
- offline queue + sync to Supabase

---

## Scope Lock (Current Priority)
Do not branch into unrelated modules until these are complete:
1. Add Supabase-backed guard sync repository tables/contracts for queued guard ops.
2. Wire guard ops service into app state.
3. Start Android Guard UI shell (dispatch/status/checkpoint/panic flow).

---

## What Is Already Done

### Product/Tier Foundation
- [x] Guard tier and capability model defined in code.
- [x] Tier 1 baseline includes mandatory NFC + patrol verification.
- [x] Tier 2/3 evidence/intelligence capability expansion modeled.

Files:
- [operational_tiers.dart](/Users/zaks/omnix_dashboard/lib/domain/guard/operational_tiers.dart)
- [operational_tiers_test.dart](/Users/zaks/omnix_dashboard/test/domain/guard/operational_tiers_test.dart)
- [onyx_guard_device_operational_tiers.md](/Users/zaks/omnix_dashboard/docs/onyx_guard_device_operational_tiers.md)

### Guard Mobile Ops Domain Core
- [x] Guard assignment/status domain objects.
- [x] GPS heartbeat domain object.
- [x] NFC checkpoint scan domain object.
- [x] Incident capture domain object with tier gating for video.
- [x] Panic signal domain object.
- [x] Offline sync queue contract + in-memory queue.
- [x] Guard mobile ops service with enqueue behavior.

Files:
- [guard_mobile_ops.dart](/Users/zaks/omnix_dashboard/lib/domain/guard/guard_mobile_ops.dart)
- [guard_mobile_ops_test.dart](/Users/zaks/omnix_dashboard/test/domain/guard/guard_mobile_ops_test.dart)

### Shared Conversation Backend Readiness (Completed Earlier)
- [x] Supabase-backed client conversation repository with fallback.
- [x] Supabase conversation tables deployed and verified.
- [x] In-app client message writes confirmed in Supabase.

---

## Phase 1 — Supabase Guard Sync Tables & Contracts

### 1.1 Database Schema
- [x] Create `guard_sync_operations` table (offline op journal).
- [x] Create `guard_assignments` table (current assignment state).
- [x] Create `guard_location_heartbeats` table.
- [x] Create `guard_checkpoint_scans` table.
- [x] Create `guard_incident_captures` table.
- [x] Create `guard_panic_signals` table.
- [x] Add indexes by `(client_id, site_id, guard_id, occurred_at/created_at)`.
- [x] Add `updated_at` trigger pattern.
- [x] Add retention strategy (heartbeats especially).

### 1.2 REST Contract
- [x] Document exact read/write columns per table.
- [x] Define idempotency keys for sync ops.
- [x] Define conflict strategy for duplicate/offline replay.
- [x] Define operation status transitions (`queued`, `synced`, `failed`).

Deliverables:
- [x] New migration SQL file under `/supabase/migrations`.
- [x] Contract doc under `/docs`.
- [x] Retention function added:
  `public.apply_guard_projection_retention(keep_days, synced_operation_keep_days, note)`.

---

## Phase 2 — Guard Sync Repository Layer

### 2.1 Repository Interfaces
- [x] Add `GuardSyncRepository` abstraction.
- [x] Add `SharedPrefsGuardSyncRepository` (fallback/local queue).
- [x] Add `SupabaseGuardSyncRepository` (primary backend).
- [x] Add `FallbackGuardSyncRepository` (primary+fallback wrapper).

### 2.2 Service Integration
- [x] Wire `GuardMobileOpsService` to repository-backed queue.
- [ ] Add flush API (`syncPendingOperations`) with batch strategy.
- [ ] Add retry/backoff policy for transient failures.
- [ ] Add permanent-failure handling for malformed payloads.

### 2.3 Tests
- [x] Repository unit tests (primary success, fallback path, replay safety).
- [ ] Queue ordering tests.
- [ ] Sync idempotency tests.

---

## Phase 3 — App State Wiring

### 3.1 Main App Integration
- [x] Add guard sync repository initialization in `main.dart`.
- [x] Add hydration of guard assignment + queue state.
- [ ] Add periodic/background sync trigger (safe interval).
- [ ] Add online/offline awareness and sync-on-reconnect.

### 3.2 Operational Visibility
- [x] Add guard sync status line in UI (backend active vs fallback).
- [ ] Add last sync timestamp + pending queue count.
- [ ] Add sync failure diagnostics surface.

---

## Phase 4 — Android Guard UI Shell (MVP)

### 4.1 Screens
- [x] Dispatch Inbox screen:
  - assignment cards
  - accept/acknowledge
  - current status
- [x] Duty Status screen:
  - `Available`, `En Route`, `On Site`, `Clear`
- [x] Checkpoint Scan screen:
  - NFC checkpoint action
  - recent scans
  - missed checkpoint warnings
- [x] Panic screen:
  - immediate panic trigger
  - confirmation + sent state
- [ ] Evidence Capture screen:
  - photo capture (Tier 1+)
  - video capture (Tier 2+)

### 4.2 UX Rules
- [ ] Offline-first interactions (no blocking UI on connectivity).
- [x] Every action queues locally first.
- [ ] Immediate operator feedback (`queued`, `synced`, `retrying`).
- [ ] Large touch targets for field conditions.

---

## Phase 5 — Integration Hardening

- [ ] End-to-end test: assignment -> ack -> status -> checkpoint -> panic -> sync.
- [ ] Verify Supabase writes for each operation type.
- [ ] Verify fallback behavior when backend unavailable.
- [ ] Verify replay on reconnect does not duplicate records.
- [ ] Load test heartbeat throughput and retention.

---

## Phase 6 — Deployment Readiness

### 6.1 Security/Policy
- [ ] Supabase RLS policies for guard-scoped write/read.
- [ ] Device identity / auth token model finalized.
- [ ] API key and secret management finalized.

### 6.2 Device Fleet Readiness
- [ ] Android build signing + release channels.
- [ ] Managed device policy (kiosk/lockdown where needed).
- [ ] NFC permissions and runtime checks validated.
- [ ] Battery + background location behavior validated.

### 6.3 Rollout
- [ ] Pilot site rollout.
- [ ] Controller/guard SOP training.
- [ ] Incident runbook and escalation matrix.
- [ ] Production launch checklist signoff.

---

## Deployment Exit Criteria
Guard Android MVP is deployable when all are true:
- [ ] Guard ops sync tables/contracts are live in Supabase.
- [ ] Guard sync repository uses backend primary + local fallback.
- [ ] Android guard shell covers dispatch/status/checkpoint/panic.
- [ ] Offline queue + reconnect sync works end-to-end.
- [ ] RLS/auth/security policies are enforced.
- [ ] Pilot acceptance criteria passed.
