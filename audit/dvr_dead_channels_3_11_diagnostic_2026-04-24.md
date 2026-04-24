# DVR dead channels 3 & 11 — diagnostic 2026-04-24

## Observation trigger

`videoloss` events on DVR channels 3 and 11 were observed during the
2026-04-24 interactive direct-to-DVR curl probe while diagnosing the camera
worker reconnect churn.

## Data gathered

The direct reachability probe from the operator workstation / Codex execution
environment failed:

```text
$ curl --max-time 5 -s -o /dev/null -w '%{http_code}\n' http://192.168.0.117/
000
```

No DVR-side ISAPI queries were executed in this task after that failure. The
multitask prompt for this session explicitly treats a failed step 4.1
reachability probe as a blocker for the rest of the read-only DVR diagnostic.

## Channel 3 state

Unknown. The DVR was unreachable from this task's execution vantage, so no
channel-state query was run.

## Channel 11 state

Unknown. The DVR was unreachable from this task's execution vantage, so no
channel-state query was run.

## Classification

DEFERRED

The DVR was unreachable at the time of investigation from the environment this
task was authorized to use, so the diagnostic could not distinguish between:
physical channel loss, DVR-side misconfiguration, failing upstream cameras, or
expected-noise conditions that should be filtered by the platform.

## Recommended next action

Re-run the read-only ISAPI diagnostic from a network vantage that can reach
`192.168.0.117` directly and capture the per-channel `InputProxy` / video-input
responses for channels 3 and 11. If workstation reachability remains blocked,
explicitly authorize the same diagnostic from the Pi as a separate task rather
than inferring channel health from the earlier incident probe.
