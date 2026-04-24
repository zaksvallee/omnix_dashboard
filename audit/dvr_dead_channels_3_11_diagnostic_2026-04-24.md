# DVR dead channels 3 & 11 — diagnostic 2026-04-24

## Observation trigger

`videoloss` events on DVR channels 3 and 11 were observed during the
2026-04-24 interactive direct-to-DVR curl probe while diagnosing the camera
worker reconnect churn.

## Investigation retry

The first Codex pass on this diagnostic deferred too early because it used
`timeout 5 curl ...` on macOS, where `timeout` is not installed by default.
This retry used `curl --max-time 5` directly from the operator's Mac to answer
the real question: whether the DVR is reachable from the Mac at all.

## Data gathered

The direct reachability probe from the operator's Mac failed again, this time
with the correct command:

```text
$ curl --max-time 5 -s -o /dev/null -w '%{http_code}\n' http://192.168.0.117/
000
$ echo $?
28
```

Interpretation:

- HTTP code `000` + curl exit status `28` = client-side timeout
- the operator's Mac could not establish an HTTP session to the DVR within the
  5-second window

No DVR-side ISAPI queries were executed in this retry after that failure. Under
the session prompt, a failed direct reachability check keeps the diagnostic in
deferred state.

This does **not** mean the DVR is globally unreachable. Earlier the same day,
the Pi-side proxy fix verification showed a stable upstream connection from the
Pi proxy to `192.168.0.117:80`. The most likely explanation is network-path
asymmetry: the Pi can reach the DVR on the local segment, while the Mac cannot
because it is on a different segment/VLAN or is blocked by host/network policy.

## Channel 3 state

Unknown. The DVR was unreachable from this task's execution vantage, so no
channel-state query was run.

## Channel 11 state

Unknown. The DVR was unreachable from this task's execution vantage, so no
channel-state query was run.

## Classification

DEFERRED

Retry confirms the DVR is unreachable from the operator's Mac, so this task
still cannot distinguish between: physical channel loss, DVR-side
misconfiguration, failing upstream cameras, or expected-noise conditions that
should be filtered by the platform.

## Recommended next action

Run the read-only ISAPI channel diagnostic from a network vantage that is known
to share the DVR's reachable path, most likely the Pi itself. If Mac-side DVR
inspection is still desired later, first confirm whether the Mac is on a
different network segment or behind a rule that blocks Mac→DVR while still
allowing Pi→DVR.
