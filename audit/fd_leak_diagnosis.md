# FD Leak Root Cause Diagnosis

Static analysis of `/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart` and its transitive `lib/application/**` imports did **not** find a direct per-request `HttpClient()` instantiation leak. The visible network objects in this scope are almost all long-lived shared clients. The strongest static candidate is the worker's **60-second keepalive heartbeat** running on the same never-closed ISAPI `IOClient` that also owns the long-lived alert-stream connection; that cadence best matches the observed "~1 new socket FD per minute" symptom, but **runtime profiling is still required to prove it**.

## 1. HttpClient instantiations

| File | Line | Pattern | Close called? | Response drained? | Leak risk |
| --- | --- | --- | --- | --- | --- |
| `/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart` | 2239-2241 | `_buildIsapiHttpClient()` creates `HttpClient()` and wraps it in `IOClient` for the inlined Hikvision ISAPI service | **No**. `_client.close()` is never called in `OnyxHikIsapiStreamAwarenessService.stop()` (`2499-2549`) or SIGINT shutdown (`5356-5365`) | Mixed. `GET`/`HEAD` helper calls are drained via `http.Response.fromStream(...)` in `DvrHttpAuthConfig.get/head` (`965-980`); the long-lived alert stream is consumed until EOF in `_consumeAlertStream(...)` (`2985-3030`) | **High (candidate)** because it is the only direct `HttpClient()` in a 60-second network path and is never closed |
| `/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart` | 5239 | `final yoloHttpClient = http.Client();` shared by `OnyxLiveSnapshotYoloService` | **Yes**, on SIGINT only (`5361`) | Yes. `fetchRtspFrame()` reads `response.bodyBytes` (`/Users/zaks/omnix_dashboard/lib/application/site_awareness/onyx_live_snapshot_yolo_service.dart:97-107`); `detectSnapshot()` reads `response.body` (`138-176`); `_isYoloReady()` reads `response.body` (`2793-2813`) | Low |
| `/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart` | 5250 | `HttpTelegramBridgeService(client: http.Client(), ...)` | **Yes**, on SIGINT only (`5362-5363`) | Yes. `sendMessages()` reads `response.body` (`/Users/zaks/omnix_dashboard/lib/application/telegram_bridge_service.dart:286-333`), `_sendPhotoMessage()` converts to `http.Response.fromStream(...)` (`347-376`), `fetchUpdates()` reads `response.body` (`379-409`) | Low |

Notes:

- No other direct `HttpClient()` or `http.Client()` instantiations were found in the analyzed scope.
- Multiple `SupabaseClient(...)` objects are created in the worker (`/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart:5172, 5182, 5185, 5188, 5272`). Those SDK clients may own sockets internally, but that lifecycle is inside the Supabase package rather than visible in this source. They are discussed in the ranked candidates section because they are timer-driven.

## 2. RTSP socket usage

| File | Line | Pattern | Close called? | Response drained? | Leak risk |
| --- | --- | --- | --- | --- | --- |
| `/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart` | 3074-3092 | `_primeSocketConnection()` performs raw `Socket.connect(...)` before ISAPI requests | **Yes**. `await socket?.close()` in `finally` | N/A | Low |
| `/Users/zaks/omnix_dashboard/lib/application/site_awareness/onyx_live_snapshot_yolo_service.dart` | 85-107 | `fetchRtspFrame()` reads an RTSP frame from the local frame-server over shared `http.Client` | Client is shared; no per-call close (expected) | **Yes**, `response.bodyBytes` fully materializes the body | Low |
| `/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart` | 2819-2852 | `fetchSnapshotBytes()` falls back to ISAPI JPEG snapshot via `_auth.get(_client, ...)` | Shared `_client` is **not** closed in service stop | **Yes**, `DvrHttpAuthConfig.get(...)` returns `http.Response.fromStream(...)` (`965-972`) and `bodyBytes` is then read | Low |
| `/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart` | 2865-2915 | `_runConnectionLoop()` opens the long-lived Hikvision alert stream via `_streamAuth.send(_client, 'GET', ...)` | No explicit close call; connection lifetime is tied to stream EOF / request cancellation | Partially. Non-200 responses are drained via `http.Response.fromStream(...)` (`2889-2891`); success path relies on `_consumeAlertStream(...)` reading until stream end (`2914`, `2985-3030`) | Medium |
| `/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart` | 3035-3053 | `_sendKeepaliveHeartbeat()` performs a `HEAD` every 60 seconds over the same shared `_client` as the long-lived alert stream | No per-call client close; shared `_client` is never closed by the service | **Yes**, `DvrHttpAuthConfig.head(...)` returns `http.Response.fromStream(...)` (`974-980`) | **High (candidate)** because the 60-second cadence matches the observed FD growth |

Notes:

- There is **no** direct raw RTSP socket reader in the analyzed scope. RTSP frames are fetched over HTTP from a separate frame-server endpoint.
- `_streamSubscription` is declared (`/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart:2293`) and only ever nulled (`2530-2531`, `3029-3030`); no assignment to a live stream subscription was found. That means `stop()` cannot actively cancel the current alert-stream socket. This is a restart/stop leak risk, but it does not by itself explain the observed steady 1-FD-per-minute growth.

## 3. Subprocess spawns

| File | Line | Pattern | Close called? | Response drained? | Leak risk |
| --- | --- | --- | --- | --- | --- |
| N/A | N/A | No `Process.start`, `Process.run`, or `Process.runSync` invocations were found in the analyzed scope | N/A | N/A | Low |

## 4. Ranked leak candidates

Static analysis does **not** prove a single definitive leak site. The list below is ranked by how well each path matches the observed symptom: approximately one additional open socket FD per minute during steady-state operation.

1. **[Highest-likelihood static candidate]** `/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart:2478-2480`, `3035-3053`, `2239-2241` — the 60-second `_sendKeepaliveHeartbeat()` runs for the lifetime of the worker on the same never-closed ISAPI `IOClient` that also owns the long-lived alert-stream connection. That is the only direct network path in this code with a **1/minute cadence**, which matches the observed growth rate. If the underlying `HttpClient` does not reclaim or reuse the heartbeat connection while the stream connection remains open, this path will accumulate one additional ESTAB socket per minute. **Estimated leak rate:** ~1 FD/minute. **Status:** requires runtime profiling to confirm.
2. **[SDK-internal candidate]** `/Users/zaks/omnix_dashboard/lib/application/onyx_power_mode_service.dart:66-71`, `138-145` plus `/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart:5270-5274` — `OnyxPowerModeService` runs a Supabase query every 60 seconds using a dedicated `SupabaseClient`. The timer cadence also matches the observed rate. Socket ownership happens inside the Supabase SDK, not in this source, so static analysis cannot prove whether each poll leaks a socket. **Estimated leak rate:** ~1 FD/minute if the SDK path is leaking.
3. **[Enabled-path candidate]** `/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart:4513-4661`, `5166-5172` — passive Telegram relay polling uses another dedicated `SupabaseClient` every 5 seconds. If enabled and if the SDK path leaks, this would leak **faster** than the observed rate (up to ~12 polls/minute), which makes it a weaker fit for the April 20 symptom unless passive relay was disabled or mostly short-circuited.
4. **[Restart-path candidate]** `/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart:2865-3030`, `2293`, `2530-2531` — the long-lived alert stream is not wired through `_streamSubscription`, so `stop()` cannot actively cancel the current stream socket. This can strand a socket across a restart or generation change, but it should leak **per restart**, not per minute.
5. **[Confirmed lifecycle bug, weak rate match]** `/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart:2239-2241`, `2499-2549`, `5356-5365` — the ISAPI `IOClient` created by `_buildIsapiHttpClient()` is never closed by the service. This is a real ownership bug, but because the client is instantiated only once per worker start, it does not by itself explain the steady minute-by-minute growth.
6. **[Low risk]** `/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart:5239-5265` and `/Users/zaks/omnix_dashboard/lib/application/site_awareness/onyx_live_snapshot_yolo_service.dart:97-107, 138-176` — the YOLO/RTSP client is shared and its response bodies are fully materialized; no direct leak pattern is visible here.
7. **[Low risk]** `/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart:5247-5253` and `/Users/zaks/omnix_dashboard/lib/application/telegram_bridge_service.dart:286-399` — the Telegram client is shared and response bodies are drained. No direct leak pattern is visible.

## 5. Proposed fix

For the top static candidate:

- **Exact file + line:** `/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart:2239-2241`, `2478-2480`, `3035-3053`
- **Current code (offending block):**

```dart
http.Client _buildIsapiHttpClient() {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  return IOClient(client);
}

_heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
  unawaited(_sendKeepaliveHeartbeat(_generation));
});

final response = await _streamAuth
    .head(
      _client,
      _resolvedKeepaliveUri,
      headers: const <String, String>{'Accept': '*/*'},
    )
    .timeout(const Duration(seconds: 10));
```

- **Fix (inline patch as comment, not applied):**

```dart
// Proposed fix (not applied):
// 1. Make OnyxHikIsapiStreamAwarenessService explicitly own the IOClient it
//    creates in _buildIsapiHttpClient().
// 2. Close that owned client in stop() after timers/subscriptions are cancelled.
// 3. Move the 60-second keepalive HEAD onto a short-lived client (or a
//    separately-owned heartbeat client) that is closed after each request, so
//    the infinite alert-stream connection and the keepalive path cannot grow
//    the same HttpClient's socket pool indefinitely.
```

- **Expected behavior after fix:**
  - The worker should keep **one** long-lived alert-stream connection plus a bounded number of helper sockets, rather than adding a new ESTAB socket roughly every minute.
  - `/proc/<pid>/fd` should stop showing linear growth in unique socket inodes during steady-state operation.
  - If the leak persists unchanged after this fix, the next suspect is the minute-cadence Supabase poll path in `OnyxPowerModeService`, which requires runtime profiling because its socket lifecycle is inside the SDK.

## 6. Secondary candidates

- **`/Users/zaks/omnix_dashboard/lib/application/onyx_power_mode_service.dart:66-71`, `138-145` + `/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart:5270-5274`**
  - Dedicated `SupabaseClient` polled every 60 seconds.
  - Brief fix note: if runtime profiling shows the leak is on Supabase sockets rather than Hikvision sockets, keep one client and add an explicit worker shutdown `dispose()` path for every standalone `SupabaseClient`; if the SDK still leaks, wrap the poll in an isolated short-lived client that is disposed after use.

- **`/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart:4513-4661`, `5166-5172`**
  - Passive Telegram relay polling uses its own `SupabaseClient` every 5 seconds.
  - Brief fix note: if passive relay is enabled in the leaking environment and profiling shows socket growth against the Supabase host, either dispose this client on shutdown and/or gate the poll more aggressively.

- **`/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart:2865-3030`, `2293`, `2530-2531`**
  - Long-lived alert stream is not cancelable through `_streamSubscription`.
  - Brief fix note: wire the active response stream into a cancelable subscription or explicit request cancellation so `stop()` can terminate the socket immediately instead of waiting for the next chunk/EOF.

- **`/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart:2239-2241`, `2499-2549`, `5356-5365`**
  - ISAPI `IOClient` is never closed by the service.
  - Brief fix note: close the owned client in `stop()` and in the SIGINT shutdown path.

## 7. Verification plan

1. Run the camera worker in the same environment that reproduced the April 20 leak.
2. Capture the worker PID.
3. Monitor FD count every 5 minutes:

   ```bash
   ls /proc/PID/fd | wc -l
   ```

4. In parallel, sample open sockets to see which remote endpoint is growing:

   ```bash
   lsof -nP -p PID | grep TCP
   ```

5. Target outcome after the fix:
   - FD count remains approximately stable over a **30-minute** observation window (no linear growth).
   - TCP socket counts to the Hikvision host, Supabase host, YOLO host, and Telegram host remain bounded instead of climbing monotonically.

If the FD count still rises linearly after the keepalive/client-ownership fix, the next action is runtime profiling around the two minute-cadence paths: `_sendKeepaliveHeartbeat()` and `OnyxPowerModeService.evaluateNow()`.
