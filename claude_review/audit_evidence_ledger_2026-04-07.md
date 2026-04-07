# Audit: Evidence and Ledger Layer

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `client_ledger_repository.dart`, `client_ledger_service.dart`, `evidence_provenance.dart`, `dvr_evidence_probe_service.dart`, `cctv_evidence_probe_service.dart`, `evidence_certificate_export_service.dart`, `vehicle_visit_ledger_projector.dart`
- Read-only: yes

---

## Executive Summary

The evidence and ledger layer has genuine structural intent — a hash-chained ledger, provenance certificates, and HTTP probes — but has three critical correctness flaws that undermine legal admissibility: (1) `sealDispatch` serialises events with `.toString()`, producing near-identical garbage for every dispatch, (2) the fetch-hash → insert sequence is not atomic, allowing concurrent seals to fork the chain silently, and (3) all Supabase errors are swallowed, meaning evidence is silently discarded during load shedding without any retry or signal. The probe services confirm URL reachability, not content-hash integrity, but this distinction is nowhere documented or surfaced to the dashboard. PSIRA compliance requires explicit gaps to be closed before this layer can be treated as legally admissible.

---

## What Looks Good

- `ClientLedgerRepository` interface is append-only — no update or delete operations exposed at the domain boundary.
- `_sealCanonical` chains hashes correctly via `previousHash` inclusion in the SHA-256 input.
- `EvidenceProvenanceCertificate.buildEvidenceRecordHash` produces a deterministic, field-stable canonical hash covering provider, sourceType, externalId, clientId, regionId, siteId, occurredAtUtc — a solid provenance fingerprint.
- DVR probe prioritises high-risk items when the queue is bounded — keeps the most forensically relevant evidence reachable.
- DVR probe correctly filters to `sourceType == 'dvr'` before probing.
- `VehicleVisitLedgerProjector` uses deterministic sort → merge logic; visit boundary conditions (merge gap, dual-entry guard) are coherent.
- Both probe services use exponential backoff on retry (150 ms, 300 ms, 600 ms), not blind polling.

---

## Findings

### P1-A — `sealDispatch` serialises events with `.toString()`, making dispatch records forensically void
- **Action: AUTO**
- `ClientLedgerService.sealDispatch` (line 72) calls `e.toString()` on each `DispatchEvent`. Without explicit `toString()` overrides on `DecisionCreated` and `ExecutionCompleted`, this produces `"Instance of 'DecisionCreated'"` for every event. Every sealed dispatch record contains identical useless strings in the `events` array.
- Why it matters: the dispatch ledger entry is meant to be the canonical audit trail for operator decisions. If the serialised payload is meaningless, the ledger provides no forensic value and the chain hash is being anchored to junk data.
- Evidence: `lib/application/client_ledger_service.dart:69-78`
- Suggested follow-up: Codex should check whether `DecisionCreated` and `ExecutionCompleted` have `toJson()` methods and, if so, replace `e.toString()` with `e.toJson()`. Also verify no other event type is sealed through `sealDispatch`.

### P1-B — `fetchPreviousHash → insertLedgerRow` is not atomic; concurrent seals fork the chain
- **Action: REVIEW**
- `_sealCanonical` reads `previousHash`, computes a new hash, then writes — across two separate Supabase round-trips. If two events for the same `clientId` are sealed concurrently, both reads return the same `previousHash`, both compute their hash anchored to the same predecessor, and both inserts succeed. The chain now has two entries with identical `previousHash` — a fork. Subsequent chain verification would fail unless the verifier knows which branch is canonical.
- Why it matters: in a load-shedding scenario where a batch of events is caught up in parallel, the chain can silently fork, invalidating any hash-chain verification pass.
- Evidence: `lib/domain/evidence/client_ledger_service.dart:21-39`, `lib/infrastructure/events/supabase_client_ledger_repository.dart:10-26`
- Suggested follow-up: Zaks needs to decide whether atomic sealing is enforced via a DB-level unique constraint on `(client_id, dispatch_id)` with an `INSERT ... ON CONFLICT DO NOTHING`, or via a Postgres advisory lock / serialisable transaction. Resolution requires schema knowledge.

### P1-C — Supabase `insertLedgerRow` swallows all exceptions silently; evidence is permanently lost during load shedding
- **Action: REVIEW**
- `SupabaseClientLedgerRepository.insertLedgerRow` (lines 73-76) wraps the insert in `try/catch (_) {}` with a comment "Keep command flow active." If Supabase is unavailable — which in South Africa means any load-shedding stage — the ledger entry is discarded with no retry, no queue, and no error signal to the caller.
- Similarly `fetchPreviousHash` (line 23) swallows errors and returns `null`. A DB failure during a batch seal causes the new entry to be anchored as `previousHash = null`, breaking the chain even if the DB recovers.
- Why it matters: this is the single most likely failure mode in the operational environment. Evidence produced during a 2-hour Stage 4 block is provably absent from the ledger. A chain gap is also not detectable from the ledger itself — `null` previousHash is valid for a first entry.
- Evidence: `lib/infrastructure/events/supabase_client_ledger_repository.dart:59-77` (insert), `lib/infrastructure/events/supabase_client_ledger_repository.dart:11-26` (fetch)
- Suggested follow-up: Zaks to decide on the durability contract — options are: (a) surface the error to the caller and let the caller queue/retry, (b) add a local spool for offline sealing, (c) accept the loss and log it explicitly. This is a product decision before Codex can implement.

### P1-D — `sealIntelligenceBatch` can seal the same event twice if called twice; no idempotency guard
- **Action: AUTO**
- `insertLedgerRow` does a plain `.insert()` with no `ON CONFLICT` handling. There is no guard in `_sealCanonical` checking whether a row for `(clientId, recordId)` already exists before writing. If `sealIntelligenceBatch` is called twice (e.g., on reconnect), the same intelligence event produces two ledger rows with different hashes (because the second one has the first as its predecessor), corrupting the chain.
- Evidence: `lib/domain/evidence/client_ledger_service.dart:81-102`, `lib/infrastructure/events/supabase_client_ledger_repository.dart:59-77`
- Suggested follow-up: Codex to add a pre-check in `_sealCanonical` using `fetchLedgerRow` before inserting, or push idempotency to the DB via unique constraint on `(client_id, dispatch_id)`.

### P2-A — CCTV probe service has no source-type filter; it processes ALL record types
- **Action: AUTO**
- `HttpDvrEvidenceProbeService.probeBatch` correctly skips non-DVR records at line 99: `if (record.sourceType != 'dvr') continue;`. `HttpCctvEvidenceProbeService.probeBatch` has no equivalent filter — it processes every record in the list regardless of `sourceType`.
- Why it matters: if a mixed list of DVR and CCTV records is passed to the CCTV probe, DVR URLs will be probed unauthenticated (CCTV service has no auth mechanism). DVR endpoints behind bearer auth will return 401/403, counted as `probeFailures`, making DVR cameras appear degraded in the CCTV dashboard.
- Evidence: `lib/application/cctv_evidence_probe_service.dart:183-213` (no filter), `lib/application/dvr_evidence_probe_service.dart:99` (has filter)
- Suggested follow-up: Codex to add `if (record.sourceType != 'cctv') continue;` (or whatever the canonical sourceType string is) at the top of the CCTV `probeBatch` loop.

### P2-B — CCTV probe has no authentication mechanism; all probes against auth-protected cameras silently fail
- **Action: DECISION**
- `HttpCctvEvidenceProbeService` (lines 166-182) accepts only an `http.Client` — no bearer token, no basic auth, no API key mechanism. DVR probe has `DvrHttpAuthConfig` covering bearer, basic-auth, and none modes.
- Why it matters: commercial IP cameras (Hikvision, Dahua, Axis) require authentication on their snapshot/clip endpoints. All CCTV probes against real hardware will return 401, be counted as failures, and cameras will permanently show `degraded` — masking genuine outages.
- Evidence: `lib/application/cctv_evidence_probe_service.dart:166-182`
- Suggested follow-up: Zaks to decide whether CCTV cameras in the deployment use the same auth pattern as DVR or a different one (API key, cookie, VMS proxy). Codex can then mirror the DVR auth pattern.

### P2-C — Probe "verified" means URL reachable, not content-hash matched; distinction not surfaced
- **Action: REVIEW**
- Both probe services perform a HEAD/GET-range check (lines 274-296 DVR, 361-383 CCTV). They confirm the URL returns 2xx. They do not download the file and verify its SHA-256 against the stored `snapshotReferenceHash` or `clipReferenceHash`. The `verifiedCount` field in probe snapshots reports URL-reachability.
- Why it matters: evidence media could be silently replaced or corrupted on the storage server. The probe passes even if the content no longer matches the committed hash. Dashboard operators and PSIRA reviewers may assume `verified` means integrity-verified.
- The distinction is nowhere documented in the codebase.
- Evidence: `lib/application/dvr_evidence_probe_service.dart:274-296`, `lib/application/cctv_evidence_probe_service.dart:361-383`
- Suggested follow-up: Zaks to decide whether full content-hash probes are in scope (bandwidth cost vs integrity guarantee). At minimum, the dashboard label should read "URL reachable" not "verified."

### P2-D — `fetchPreviousHash` ordering depends on `created_at`; ordering is non-deterministic if column is missing or if two rows share the same timestamp
- **Action: REVIEW**
- `SupabaseClientLedgerRepository.fetchPreviousHash` orders by `created_at DESC` (line 16). If the table's `created_at` column is not set by a `DEFAULT now()` at the DB level, or if two inserts arrive in the same millisecond, the ordering is non-deterministic. The chain predecessor used for the next hash may be wrong.
- Evidence: `lib/infrastructure/events/supabase_client_ledger_repository.dart:14-17`
- Suggested follow-up: Codex to verify the Supabase migration has `created_at TIMESTAMPTZ DEFAULT now()` with a `NOT NULL` constraint. Consider adding a monotonic sequence column as a tiebreaker.

### P2-E — Exported certificate has no export timestamp and no digital signature
- **Action: DECISION**
- `EvidenceCertificateExportService.exportForIntelligence` produces a markdown certificate (lines 56-73) with no field indicating when the certificate was exported, and no cryptographic signature binding the certificate to the exporter's identity.
- Why it matters: without an export timestamp, a defending attorney can argue the certificate was produced retroactively. Without a signature, the certificate can be silently modified after export. PSIRA-compliant evidence needs to demonstrate chain of custody.
- Evidence: `lib/application/evidence_certificate_export_service.dart:56-73`
- Suggested follow-up: Zaks to decide on the signing mechanism (server-side signature via Supabase Edge Function, operator keypair, or HMAC using an org secret). Export timestamp is a simpler fix Codex can add immediately.

### P2-F — `EvidenceCertificateExportService` does not verify the ledger hash before export
- **Action: AUTO**
- When exporting, `fetchLedgerRow` is called and the stored `hash` field is included in the certificate. The service never re-computes SHA-256 from `ledgerRow.canonicalJson + ledgerRow.previousHash` to confirm the stored hash is correct. A tampered or corrupted ledger row exports with a mismatched hash presented as legitimate.
- Evidence: `lib/application/evidence_certificate_export_service.dart:23-47`
- Suggested follow-up: Codex to add a verification step: re-derive the expected hash from `canonicalJson` and `previousHash`, compare to `ledgerRow.hash`, and set a `ledger.hashVerified` boolean in the export payload (false if mismatch).

### P3-A — `VehicleVisitLedgerProjector` silently drops all non-DVR vehicle events including CCTV ALPR
- **Action: DECISION**
- Line 117: `if (event.sourceType != 'dvr') { continue; }`. CCTV sources with plate detection are excluded. For sites with mixed CCTV/DVR coverage, vehicle throughput reporting covers only DVR cameras.
- Evidence: `lib/application/vehicle_visit_ledger_projector.dart:117`
- Suggested follow-up: Zaks to decide whether CCTV plate events should contribute to vehicle visits. If yes, Codex removes the sourceType filter or expands it to include `cctv`.

### P3-B — Zone stage classification uses raw text keyword matching; brittle against label variations
- **Action: REVIEW**
- `_classifyZoneStage` (lines 312-353) scans `zone + headline + summary` for keywords. `'boom in'` → entry, `'boom out'` → exit. A label `'boom_in'` or `'BOOM IN'` (upper-case is normalised to lower but underscores are not stripped) is missed; `_` is not in the keyword list.
- Evidence: `lib/application/vehicle_visit_ledger_projector.dart:312-353`
- Suggested follow-up: Codex to add underscore-to-space normalisation before keyword matching, and verify with zone label samples from the actual DVR integration.

---

## Duplication

- **`DvrCameraHealth` ↔ `CctvCameraHealth`**: identical fields, identical `_CameraAggregate` mutable accumulator pattern, identical status ranking logic, identical `_probeWithRetry` / `_probeOnce` structure. The only differences are: DVR has auth support and a `sourceType == 'dvr'` filter; CCTV has `fromJson`/`toJson` on its snapshot model.
  - Files: `dvr_evidence_probe_service.dart`, `cctv_evidence_probe_service.dart`
  - Centralisation candidate: a shared `EvidenceProbeEngine` accepting an auth strategy and source type filter. Each service becomes a thin wrapper. This would also guarantee the auth fix lands in one place.

- **Probe loop structure** duplicated verbatim (sort by risk, take queue limit, count dropped, iterate probes, aggregate per camera, build alerts).
  - Files: `dvr_evidence_probe_service.dart:127-256`, `cctv_evidence_probe_service.dart:213-343`
  - ~130 lines of near-identical code that will diverge as bugs are fixed in one but not the other.

---

## Coverage Gaps

- `client_ledger_service_test.dart`: one happy-path test only. Missing:
  - Re-sealing the same event twice (idempotency bug from P1-D).
  - Concurrent sealing of two events for the same client (race from P1-B).
  - `sealDispatch` with real `DecisionCreated` / `ExecutionCompleted` events (would expose P1-A immediately).
  - Behaviour when `fetchPreviousHash` returns an error (load-shedding chain break from P1-C).
  
- `evidence_certificate_export_service_test.dart`: one happy-path test only. Missing:
  - Export for an event that was never sealed (ledger row null).
  - Export where ledger hash does not match re-derived hash (tamper detection from P2-F).
  - Export timestamp presence check.

- No test exists for either probe service. Missing:
  - CCTV probe with a mixed DVR+CCTV record list (exposes P2-A).
  - DVR probe with queue overflow (verifies drop count).
  - Probe with a URL that returns 401 vs 404 — currently both count as `probeFailure`.

- No test for `VehicleVisitLedgerProjector` zone stage classification with real zone label strings (would catch P3-B underscore issue).

---

## Performance / Stability Notes

- **Sequential probing in both services**: `probeBatch` awaits each URL probe in sequence inside a `for` loop (DVR line 141, CCTV line 228). With `maxQueueDepth = 12` and a 3-second timeout plus up to 3 retries, the worst case is 12 × 3 × 3s = 108 seconds per batch before the method returns. This will block any async UI refresh waiting on the result.
  - Concretely risky if called from a timer-based update path.

- **`staleFrameThreshold = 30 minutes`** is not configurable per site. Remote or farm sites with long polling intervals will permanently show cameras as `stale`. The default should likely be injectable per site profile.

- **`_probeOnce` swallows all exceptions with `catch (_) {}`** (DVR line 293, CCTV line 380). DNS failure, TLS mismatch, socket timeout, and genuine 404 are all collapsed into `false`. There is no way for the alert system to distinguish "network is down" (transient) from "file was deleted" (permanent evidence loss).

---

## PSIRA Compliance Gaps Summary

For legal admissibility under PSIRA, the following are currently absent:

| Requirement | Status | Finding |
|---|---|---|
| Append-only evidence chain | Partial — interface is, DB insert may duplicate | P1-B, P1-D |
| Hash-chain integrity verification | Missing — stored hashes not re-verified on export | P2-F |
| Content-hash verification of media | Missing — probes are reachability-only | P2-C |
| Evidence durability during outages | Missing — silent discard on DB error | P1-C |
| Canonical event serialisation for dispatch records | Broken — `.toString()` produces non-canonical output | P1-A |
| Export timestamp and chain of custody | Missing — no timestamp or signature on certificate | P2-E |
| Idempotent sealing (no duplicate entries) | Missing | P1-D |

---

## Recommended Fix Order

1. **P1-A** (AUTO) — Fix `sealDispatch` event serialisation. Replace `.toString()` with `.toJson()`. Every dispatch sealed today is forensically void. Zero risk to fix.
2. **P1-D** (AUTO) — Add pre-insert existence check or DB unique constraint on `(client_id, dispatch_id)` to prevent double-sealing. Required before P1-B fix lands.
3. **P2-F** (AUTO) — Add hash re-derivation step in `EvidenceCertificateExportService.exportForIntelligence` before export. Adds tamper detection with no schema changes.
4. **P2-A** (AUTO) — Add `sourceType` filter to CCTV `probeBatch` loop.
5. **P1-C** (REVIEW/DECISION) — Durability contract during load shedding. Zaks must decide before Codex can implement.
6. **P1-B** (REVIEW) — Atomic hash-chain sealing. Requires DB schema decision.
7. **P2-C** (REVIEW) — Clarify probe "verified" semantics in dashboard labels. Content-hash probing is a larger scope decision.
8. **P2-B** (DECISION) — CCTV auth mechanism. Blocks real probe accuracy.
9. **P2-E** (DECISION) — Certificate signing. Blocks PSIRA submission.
10. **Probe service refactor** (low urgency) — Merge duplicated probe engine once P2-A and P2-B are resolved, so auth and filter fixes land once.
