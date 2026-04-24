ONYX Codex follow-up session — 2026-04-24 afternoon

Task A — Layer 3 plan remaining review items
Status: complete
Commit hash: existing state already satisfied by `97027e6` (items 1, 3, 4, 5 + backlog) plus `8ff3982` (item 2 / Workstream 3 update)

Diff verification:

- [x] The "Not in scope" bullet about dispatch_id schema redesign is deleted
- [x] A "Prerequisite" sub-section appears in Workstream 2 body with the exact FK mismatch text
- [x] Workstream 2's exit criterion about "fresh operational event" is modified with the dispatch_id-unconstrained phrasing
- [x] Workstream 4 body contains the "dormant-by-design" paragraph
- [x] Workstream 4 contains "Tables confirmed dormant at MS Vallee:" header with existing table list preserved below
- [x] Workstream 5 body contains the "not operational at MS Vallee" paragraph
- [x] "Suggested sequence" section has a new note after step 4 about parallel execution
- [x] "Immediate backlog" list has a new bullet about FK type mismatch

Notes:

- The premise for Task A was stale at session start. Inspection of the current
  file showed all requested items already present in-tree before any new edit
  was made in this session.
- To avoid fabricating duplicate content or a no-op commit, the plan file was
  left unchanged.

Full diff:

No new diff was generated in this session because the target state already
matched the requested review-item outcome. Relevant existing commits:

- `97027e6` — `audit: layer 3 plan — apply review items 1-5 from 2026-04-23 pass`
- `8ff3982` — `audit: layer 3 plan — update workstream 3 post-proxy fix`

Task B — DVR diagnostic retry
Status: still DEFERRED
Commit hash: `fbd1a91`
DVR probe result: HTTP `000`, curl exit status `28`
Classification: DEFERRED
Key finding: retry with the correct macOS-safe command confirmed Mac-side
unreachability to `192.168.0.117`, which is consistent with network-path
asymmetry rather than the earlier missing-`timeout` shell issue.

Task C — Phase B CC prompt draft
Status: complete
Artifact: `audit/cc_prompt_worker_fd_fix_phase_b_2026-04-24.md` (untracked)

Full inlined prompt content for operator review

```text
ONYX — CC Phase B Prompt: Worker FD-release fix (2026-04-24)
Operator: Zaks
Scope: Implement the worker-side reconnect cleanup fix identified in the
2026-04-24 Phase A memo. Do not execute deployment; produce deployment
instructions only.

================================================================================
§0 — SELF-CONTAINED CONTEXT

The DVR proxy streaming fix landed earlier today in commit `1612f0d`
(`fix(dvr_proxy): forward multipart/mixed alertStream as streaming response`).
That removed the hot reconnect churn and stabilized the Pi worker at ~15 FDs,
but it did **not** resolve the worker's latent reconnect cleanup bug.

Source-of-truth artifacts:

- `audit/fd_leak_runtime_profile_2026-04-24.md`
- `audit/worker_fd_release_bug_phase_a_2026-04-24.md`

Runtime-profile conclusion:

- the original proxy bug was the immediate cause of the runaway churn
- the worker still has a latent FD-release bug in reconnect handling
- that latent bug will re-manifest on any legitimate reconnect event if the
  active alert-stream subscription still is not canceled / cleaned up properly

Phase A memo conclusion:

- recommend **Option 2**
- wire `_streamSubscription` to the active alert stream
- ensure `stop()` and generation changes can cancel the live stream
- ensure each reconnect iteration cleans up the previous iteration before the
  next begins

Important nuance from Phase A:

- there are two copies of `OnyxHikIsapiStreamAwarenessService`
  - runtime copy in `bin/onyx_camera_worker.dart`
  - duplicate library copy in
    `lib/application/site_awareness/onyx_hik_isapi_stream_awareness_service.dart`
- existing tests hit the library copy, not the runtime copy
- this pass must keep the two copies functionally equivalent, but it must NOT
  attempt a broader deduplication refactor

================================================================================
§1 — SCOPE

IN SCOPE

1. `bin/onyx_camera_worker.dart`
2. `lib/application/site_awareness/onyx_hik_isapi_stream_awareness_service.dart`
3. `test/application/onyx_hik_isapi_stream_awareness_service_test.dart`

OUT OF SCOPE

1. Consolidating the duplicate service implementations into one
2. Any `.dart` file outside the three listed above
3. Any `.md`, `.yaml`, `.py`, `.sql`, or infra/deploy file
4. Pi-side deployment execution

If you believe the correct fix requires touching anything outside the three
in-scope files, HALT and report rather than expanding scope.

================================================================================
§2 — WHAT CORRECT LOOKS LIKE

The completed fix must satisfy all of the following:

1. `_streamSubscription` is assigned to the active alert-stream subscription.
2. `stop()` and generation changes can cancel the active subscription.
3. Each reconnect iteration cleans up the previous iteration's subscription
   before starting the next.
4. The bin/ and lib/ copies remain functionally equivalent after the change.
5. Tests assert that the previous subscription is canceled on reconnect.

The target is not "FD count happens to look okay in a unit test." The target is
explicit ownership and cancellation of the active alert-stream subscription.

================================================================================
§3 — CONSTRAINTS

- LOC budget: ~35-50 net total across all three files
- Hard ceiling: 80 LOC net
- No new dependencies
- No opportunistic refactors
- No format-only churn
- Keep the bin/ and lib/ copies in sync; do not let them drift further

If you cross 80 LOC net, HALT and report the scope drift.

================================================================================
§4 — FOUR-PHASE EXECUTION

Work in strict sequence. Stop and report at the end of each phase. Do not
silently continue into the next phase.

PHASE A — Re-confirm and refine the fix approach

1. Read:
   - `audit/worker_fd_release_bug_phase_a_2026-04-24.md`
   - `audit/fd_leak_runtime_profile_2026-04-24.md`
   - the three in-scope source files
2. Re-confirm whether Option 2 is still the right minimal fix after looking at
   the code again.
3. If you agree with Option 2, say so and give a short implementation plan.
4. If you believe a refinement is needed, explain the refinement, but stay
   inside scope.

PHASE A stop-and-report:

- exact runtime and library line ranges you will edit
- whether Option 2 stands as-is or needs a minor refinement
- expected net LOC

Do not edit files until Phase A is acknowledged.

PHASE B — Implement fix and tests

1. Apply the minimal fix to both service copies.
2. Update / extend
   `test/application/onyx_hik_isapi_stream_awareness_service_test.dart`
   so reconnect behavior asserts prior subscription cancellation.
3. Run:
   - `dart analyze`
   - targeted tests for the touched test file
   - any minimal broader test run you believe is necessary

PHASE B stop-and-report:

- git diff summary
- exact LOC delta
- test output
- analyze output

Do not proceed to deployment instructions until Phase B is acknowledged.

PHASE C — Deployment instructions only (operator-supervised)

Produce deployment instructions for Zaks to run manually on the Pi. Do NOT
execute them yourself.

Instructions must include:

1. stop worker on Pi
2. scp both modified runtime files if both changed
3. restart worker (proxy does NOT need restart for this fix)
4. verification plan over 10 minutes with induced reconnects

Induced reconnect verification:

- restart the proxy once to force a legitimate worker reconnect
- observe that worker FD count does not grow across the 10-minute window
- observe that worker reconnects cleanly after the forced event

PHASE C stop-and-report:

- exact commands
- expected pass/fail signatures

Do not commit or push until Phase C is acknowledged.

PHASE D — Commit, push, update audit trail

If operator authorizes Phase D:

1. commit code/test changes
2. push `main`
3. append a short resolution note to the relevant audit artifact(s)
4. report hashes and final repo state

================================================================================
§5 — HALT CONDITIONS

HALT immediately and report if any of the following occurs:

1. The fix requires touching more than the three scoped files.
2. Tests reveal `_streamSubscription` is already used by some other code path
   that the Phase A memo missed.
3. Net LOC exceeds 80.
4. The runtime and library copies cannot be kept functionally equivalent
   without a broader refactor.
5. The reconnect-cancellation test cannot be expressed cleanly in the existing
   test harness without expanding scope.

================================================================================
§6 — DEPLOYMENT VERIFICATION PLAN (FOR PHASE C)

The deployment instructions must verify all of the following:

1. Worker process restarts cleanly.
2. A forced reconnect occurs (e.g. via proxy restart) without the worker
   entering a runaway reconnect loop.
3. Worker FD count remains approximately flat over 10 minutes after the forced
   reconnect event.
4. No new repeating "Alert stream closed unexpectedly" pattern appears.

Use explicit commands and expected output shape so the operator can evaluate the
result without interpretation.

================================================================================
§7 — REPORT FORMAT

Each phase report should use this structure:

`PHASE X REPORT`

- Findings
- Planned / completed edits
- LOC estimate or actual delta
- Risks / open questions
- Stop point

END OF PROMPT
```

Anomalies

- Task A did not require a new patch: the four allegedly-missing review items
  and the backlog bullet were already present in the current plan file before
  this session began.
- The earlier Task B deferral really was caused by the missing `timeout`
  command on macOS, but the corrected retry still produced a real network
  timeout from the Mac.
- No credentials were fetched or echoed during Task B because the DVR never
  cleared the initial reachability gate.

Decisions for operator

1. Review `audit/cc_prompt_worker_fd_fix_phase_b_2026-04-24.md` and send it to
   CC if you want to start the worker FD-release fix.
2. Decide whether the DVR dead-channel diagnostic should be re-run from the Pi
   or another network vantage that can actually reach `192.168.0.117`.
3. Decide whether `audit/amendments_3_4_5_summary.md` should remain an
   untracked working note or be promoted into a committed artifact later.
