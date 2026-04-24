# Pre-existing test failures — recorded 2026-04-24

Two tests currently fail on clean main HEAD. These failures were
confirmed present on commit `0eba3eb` before the worker FD fix
landed, so they are NOT regressions introduced by today's work.

## File

`test/application/onyx_hik_isapi_stream_awareness_service_test.dart`

## Failing tests

- `publishes immediately on humanDetected`
- `records occupancy tracking for human detections only`

## Evidence

Baseline verification was performed by Codex during Phase B of the
worker FD fix (commit 0249acf). Codex reproduced the failures on a
clean detached worktree at `0eba3eb` to confirm they were not
introduced by the FD fix patch. Test output:
    00:02 +4 -1: OnyxHikIsapiStreamAwarenessService publishes immediately on humanDetected
    [E] TimeoutException after 0:00:02.000000: Future not completed

    00:11 +4 -2: OnyxHikIsapiStreamAwarenessService records occupancy tracking for human detections only
    [E] Condition not met before timeout.
## Classification

Not yet triaged. The failures could represent:
- Real runtime defects in the site-awareness service (tests catching
  actual broken behavior that needs fixing)
- Stale test expectations that no longer match correct service
  behavior after some earlier refactor (tests need updating, service
  is correct)
- Environmental/timing issues specific to test setup (e.g. a mock
  that stopped firing)

## Next action

Triage required before deciding whether these represent real
site-awareness defects that need code fixes, or stale test
expectations that need test updates. Not in scope for the current
work thread; tracked here so they don't get lost.

Not currently folded into Layer 3 Workstream 3 body — that workstream
already has the camera-worker reconnect work scoped, and the nature
of these failures (classification pending) makes it premature to
assign them to a workstream.
