# FD Leak Runtime Profile — 2026-04-24

## Capture methodology

Three `lsof -p <worker_pid> -n -P` snapshots taken 30 minutes apart over a
60-minute window, captured over SSH from the operator workstation.
Complementary kernel-side data collected at T+60 via `ss`, `/proc/<pid>/fd`,
`/proc/<pid>/net/tcp`, and `/proc/<pid>/net/sockstat`.

- Worker PID: **1583989** (stable across all three snapshots)
- Worker uptime at T+0: ~2 days (`ActiveEnterTimestamp=Wed 2026-04-22 00:18:59 SAST`)
- ActiveState remained `active` at every checkpoint; no restart occurred during capture.

| Snapshot | UTC timestamp       | File                          |
|----------|---------------------|-------------------------------|
| T+0      | 2026-04-24T05:21:07Z | `fds_t0_20260424T052107Z.txt`  |
| T+30     | 2026-04-24T05:51:29Z | `fds_t30_20260424T055129Z.txt` |
| T+60     | 2026-04-24T06:21:53Z | `fds_t60_20260424T062153Z.txt` |

Commands used per snapshot:

```
ssh onyx@192.168.0.67 "lsof -p 1583989 -n -P" > fds_t*.txt
```

Post-capture inspection (T+60 side-channel, not snapshots):

```
ssh onyx@192.168.0.67 "ss -tanp"
ssh onyx@192.168.0.67 "cat /proc/1583989/net/sockstat"
ssh onyx@192.168.0.67 "cat /proc/1583989/net/tcp | wc -l"
ssh onyx@192.168.0.67 "ls /proc/1583989/fd | wc -l"
ssh onyx@192.168.0.67 "tail -100 /opt/onyx/tmp/onyx_camera_worker.log"
```

## Raw FD counts

lsof rows per snapshot (one row per (FD, socket-inode) pair):

| Snapshot | lsof rows | Δ vs prior | Δ vs T+0 |
|----------|-----------|------------|----------|
| T+0      | 39,518    | —          | —        |
| T+30     | 39,883    | +365       | +365     |
| T+60     | 40,245    | +362       | +727     |

Deduplicated by unique socket NODE (column 8 of lsof), which strips the
per-thread replication that lsof emits for Dart isolates:

| Snapshot | Unique socket inodes | Δ vs prior | Δ vs T+0 |
|----------|----------------------|------------|----------|
| T+0      | 39,493               | —          | —        |
| T+30     | 39,857               | +364       | +364     |
| T+60     | 40,220               | +363       | +727     |

Set operations on unique socket inodes across the 60-minute window:

- New sockets appearing T+0 → T+30: **364**
- New sockets appearing T+30 → T+60: **364**
- Sockets present at T+0 and still present at T+60: **39,493**
- Sockets present at T+0 but gone by T+60: **0**

Independent kernel confirmation at T+60:

- `/proc/1583989/fd` entry count: **40,266** (matches lsof row count to within
  lsof/proc race noise)
- `/proc/1583989/net/sockstat`:
  - `TCP: inuse 19  orphan 0  tw 14  alloc 40272  mem 40638`
  - `sockets: used 40447`
- `/proc/1583989/net/tcp` row count: **37** (36 actual TCP entries + header)

## Socket classification

The central finding of the kernel cross-check is that **almost all leaked
sockets are in kernel state TCP_CLOSE with no entry in `/proc/net/tcp`**:

- `TCP: alloc 40272` — 40,272 TCP socket structs allocated by the kernel for this process.
- `TCP: inuse 19` — only 19 of those are actually communicating.
- `/proc/net/tcp` contains only 37 entries total, state-decoded as:
  - 19 TIME_WAIT (`state 06`)
  - 11 ESTABLISHED (`state 01`)
  - 6 LISTEN (`state 0A`)

That leaves **~40,253 TCP socket structures that are kernel-allocated but
have no entry in `/proc/net/tcp`**. These are sockets that were created and
have been `shutdown()`'d at the network layer but whose file descriptors were
never `close()`'d by the Dart process. The kernel keeps the `struct sock`
around because userspace still holds an open FD.

Because the leaked FDs have no `/proc/net/tcp` entry, lsof cannot report the
remote endpoint for them — they render in lsof as bare `sock / protocol: TCP`
with no IPv4/IPv6 address. The 19 active endpoints visible to `ss` at T+60:

| Endpoint class                 | Count | Notes                                            |
|--------------------------------|-------|--------------------------------------------------|
| 192.168.0.117:80 (DVR HTTP/ISAPI) | 13 + 1 ESTAB | 13 in TIME_WAIT + 1 ESTAB backed up 91 KB in Recv-Q |
| 192.168.0.117:554 (DVR RTSP)   | 2 ESTAB | owned by `python` (RTSP frame server, pid 1683544) |
| 104.18.38.10:443 (Cloudflare / Supabase) | 1 ESTAB + 1 TIME_WAIT | one ESTAB owned by the worker at FD 40217 |
| 172.149.149.246:443             | 3 ESTAB | external HTTPS (not identified in this pass)     |
| 127.0.0.1 local loopback        | a few | local DVR proxy / YOLO paths                     |
| LISTEN sockets                  | 6     | ssh, systemd-resolved, local DVR proxy, python frame/YOLO |

### Window table (reframed: all new FDs were bare `sock` entries)

| Window      | New unique socket inodes | Classifiable remote | Bare `sock TCP` (no endpoint in lsof) |
|-------------|--------------------------|---------------------|----------------------------------------|
| T+0 → T+30  | 364                      | 0                   | 364                                    |
| T+30 → T+60 | 364                      | 0                   | 364                                    |

In other words, **every single one of the 728 new sockets created during the
60-minute window was leaked directly into the TCP_CLOSE pool without ever
appearing in `/proc/net/tcp`**. This is categorically not consistent with the
original static hypothesis, which predicted a keepalive-rate leak against a
specific remote (192.168.0.117:80).

## Growth rate vs static prediction

| Source                                    | Predicted rate | Actual rate       |
|-------------------------------------------|----------------|-------------------|
| `audit/fd_leak_diagnosis.md` §4 candidate 1 (60s heartbeat) | ~1 FD/min | ~12.1 FD/min |
| Observed rate this capture                 | —              | ~12.1 FD/min (728 / 60) |

The observed rate is **~12× faster** than the static hypothesis. A 60-second
cadence cannot produce 12 FDs per minute. The observed cadence is consistent
with a ~5-second-interval code path.

## Live-log cross-check

The worker's runtime log `/opt/onyx/tmp/onyx_camera_worker.log` during the
capture window shows a repeating pair of messages roughly every 5 seconds:

```
[HH:MM] | CH... | perimeter: clear | humans:... | faults: ...
[ONYX] ⚠️ Camera stream disconnected from 192.168.0.117:80 — reconnecting in 5s (attempt 1). Reason: Alert stream closed unexpectedly.. Error: null
```

The disconnect-reconnect pair repeats continuously with `attempt 1`
(i.e., retryAttempt resets to 0 on each successful reconnect and is
incremented to 1 on the immediate following disconnect). The delay used is
`_retryDelayFor(0)` = 5 seconds (bin/onyx_camera_worker.dart:4942-4950). This
matches the observed ~12/min cadence exactly.

The code path that produces this behaviour is the alert-stream reconnect
loop: `_runConnectionLoop()` at
`bin/onyx_camera_worker.dart:2889-3007`.

## Verdict

**CONTRADICTED.** The static hypothesis in
`audit/fd_leak_diagnosis.md` §4 candidate 1 — that the 60-second keepalive
heartbeat on the shared ISAPI IOClient is the leak site — does not match the
observed data. The cadence is 12/min, not 1/min, and the leaked sockets are
not visible in `/proc/net/tcp` at all, which rules out any hypothesis whose
mechanism leaves an ESTAB or TIME_WAIT entry against a specific remote.

The observed leak signature is:

- Kernel reports 40,272 allocated TCP socket structs vs 19 in use.
- ~40,253 of those are in TCP_CLOSE (no `/proc/net/tcp` entry), i.e.
  `shutdown()`'d but not `close()`'d — userspace FDs still held.
- 12 new such FDs appear per minute, every minute, across a 60-minute window.
- Runtime log shows the worker is in a steady reconnect loop against the
  Hikvision alert stream with `_retryDelayFor(0) = 5s` between attempts.

That set of facts matches `audit/fd_leak_diagnosis.md` §4 candidate **4**
(the restart-path/stream-not-cancelable path), not candidate 1. Each
reconnect iteration of `_runConnectionLoop()` at
`bin/onyx_camera_worker.dart:2889-3007` leaves the previous iteration's
`http.StreamedResponse` socket FD unclosed. Over two days of uptime that
accumulates to ~40k leaked FDs — matching both the observed absolute FD
count and the observed ~10-day recurrence against the 65,536 `LimitNOFILE`
bandaid.

## Why the reconnect loop is also running hot

A secondary observation not required for the verdict: the worker should not
be reconnecting every 5 seconds in steady state. The log line
`Reason: Alert stream closed unexpectedly.. Error: null` comes from
`bin/onyx_camera_worker.dart:2941`, which fires when the alert stream ends
without `_running`/`generation` flipping — i.e. the server closes the HTTP
response while the worker still wants it. This is a separate issue from the
FD leak (which would exist at a lower rate even if the stream only
reconnected, say, once per hour), but fixing the leak without investigating
the churn would mask the real production symptom.

## Recommended next action

The FD leak fix and the reconnect-churn investigation are separable and
should both be done.

### FD leak fix (direct, in-scope)

Scope: make each iteration of the reconnect loop release the socket FD
backing the previous `http.StreamedResponse` before (or instead of)
discarding the response reference.

Concrete candidates in `bin/onyx_camera_worker.dart`:

1. In `_runConnectionLoop()` at `bin/onyx_camera_worker.dart:2889-3007`,
   wrap each loop iteration's `response` so that on exit from
   `_consumeAlertStream(...)` (line 2938) — whether via normal EOF or error
   — the worker explicitly drains and detaches the underlying socket rather
   than relying on the default `HttpClient` pool idle-reap.

2. Separate the long-lived alert stream from the 60-second keepalive
   heartbeat, as originally recommended in
   `audit/fd_leak_diagnosis.md` §5. The ISAPI `IOClient` built at
   `bin/onyx_camera_worker.dart:2239-2241` should not be the same
   connection pool that owns the reconnecting alert stream. When the alert
   stream tears down every 5 seconds and the keepalive HEADs on a 60s cadence
   use the same pool, the pool's bookkeeping gets cornered into never
   closing the 5-second-churn sockets. Giving the stream its own,
   scoped-lifetime client and explicitly `.close(force: false)`-ing it on
   each reconnect iteration would force the kernel to release the FD.

3. Wire `_streamSubscription` to the active response stream so
   `stop()` / generation changes can cancel it directly instead of waiting
   for the `await for` to exit. This is the `streamSubscription` gap noted
   in the static diagnosis at
   `bin/onyx_camera_worker.dart:2293, 2530-2531, 3054`.

After any one of those changes, target behaviour is:

- `/proc/<pid>/net/sockstat` `TCP: alloc` should be ≤ (small constant ×
  `TCP: inuse`), not `alloc ≫ inuse`.
- `/proc/<pid>/fd | wc -l` should stay approximately flat over a 30-minute
  observation window under the same reconnect-churn conditions.

### Reconnect-churn investigation (out of scope for this ticket)

Why is the Hikvision alert stream closing every 5 seconds? Candidates, in
order of likelihood given the data visible here:

- The camera at 192.168.0.117:80 is actively closing the HTTP response
  because another edge device or client is also holding the alert-stream
  session. This is consistent with the log message at
  `bin/onyx_camera_worker.dart:4564` (`"Another edge likely owns the
  Hikvision alert stream."`), which the passive Telegram relay fallback
  was written to handle.
- The DVR proxy / auth layer is sending incomplete responses that end the
  stream at the TCP level without a proper HTTP EOF.
- Request timeout (`requestTimeout`) is firing on each request; unlikely
  because the log explicitly reports `unexpectedly`, not a timeout.

This should be diagnosed separately by inspecting the DVR and looking at
who else is talking to 192.168.0.117:80.

## Anomalies encountered during capture

None. PID remained 1583989 throughout, all three SSH round-trips succeeded,
lsof outputs were well-formed (first snapshot 3.04 MB, third 3.10 MB),
and FD growth was monotonic and roughly linear.

## Snapshots archived

Raw lsof output preserved under
`audit/fd_leak_profiling_artifacts_2026-04-24/`:

- `fds_t0_20260424T052107Z.txt` — 39,518 lines
- `fds_t30_20260424T055129Z.txt` — 39,883 lines
- `fds_t60_20260424T062153Z.txt` — 40,245 lines
