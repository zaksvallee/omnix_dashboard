# Audit: Camera Bridge — ONVIF / Hikvision / Frigate Integration

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/local_hikvision_dvr_proxy_*`, `lib/application/onyx_agent_camera_bridge_*`, `lib/application/onyx_agent_camera_change_service.dart`, `lib/application/onyx_agent_camera_probe_service.dart`, `lib/application/dvr_http_auth.dart`, matching UI files under `lib/ui/onyx_camera_bridge_*`
- Read-only: yes

---

## Executive Summary

The camera bridge subsystem is split across two distinct integration layers:

1. **Local Hikvision DVR Proxy** (`LocalHikvisionDvrProxyService`) — a real, working HTTP proxy that bridges the ONYX dashboard to an upstream Hikvision DVR. It performs real network I/O: alert stream relay, MJPEG snapshot polling, digest auth, and CORS headers. This layer is production-grade infrastructure.

2. **Camera Change Execution** (`OnyxAgentCameraBridgeReceiver` + vendor workers) — a fully **simulated** approval-and-dispatch layer. All five vendor workers (Hikvision, Dahua, Axis, Uniview, Generic ONVIF) return canned success strings. No device write, no ISAPI call, no ONVIF call is ever issued. When real Hikvision credentials arrive this layer is the gap that blocks end-to-end execution.

The credential path is the critical missing link: `OnyxAgentCameraExecutionPacket` carries a plain-text `credentialHandling` label (e.g. `"Keep device credentials local."`) — not actual credentials. There is no mechanism to pass a username/password into any worker today.

Risk is **high** if an operator believes approved packets are applying device changes. The UI will show green receipt status for executions that did nothing on the camera.

---

## What Looks Good

- `DvrHttpAuthConfig` (dvr_http_auth.dart) is fully implemented: none/bearer/digest with proper MD5 HA1/HA2/qop-auth flow, cnonce, nc. Hikvision digest auth is ready to use.
- `LocalHikvisionDvrProxyService` has a well-structured proxy: health endpoint, alert stream buffer with retention and pruning, MJPEG relay, passthrough, relay player page, CORS headers — all functional.
- The IO/stub conditional import pattern (`server_io.dart` vs `server_stub.dart`) is correctly done; web platform gets a silent no-op safely.
- `OnyxAgentCameraProbeService` does real TCP port probes (80, 443, 554, 8899) and HTTP status checks before any write action — correct gate before committing to a change packet.
- Receipt state management (current / stale / missing / unavailable) is clean and fully tested.
- Test coverage for the real infrastructure is solid: proxy service, bridge server, health service, receiver routing, probe service all have dedicated test files.
- `LocalHikvisionDvrProxyRuntimeConfigResolver` guards against loopback-only bind, self-loop endpoints, and empty credentials — defensive and correct.

---

## Findings

### P1 — Action: DECISION
**All vendor workers are simulated. Camera changes are never actually applied.**

`OnyxAgentCameraBridgeReceiver` dispatches execution packets to five workers. Every worker (`HikvisionOnyxAgentCameraWorker`, `DahuaOnyxAgentCameraWorker`, `AxisOnyxAgentCameraWorker`, `UniviewOnyxAgentCameraWorker`, `GenericOnyxAgentCameraWorker`) returns a hardcoded `OnyxAgentCameraExecutionOutcome` with `success: true` and a fixed `detail` string. No HTTP call, no ISAPI call, no ONVIF call.

**Why it matters:** An operator approving a camera change packet sees "Executed — Hikvision ONVIF Worker mapped alarm_verification onto media profile…" but nothing changed on the device. This is an ops correctness failure, not a cosmetic one.

**Evidence:**
- `lib/application/onyx_agent_camera_bridge_receiver.dart:115–130` — `HikvisionOnyxAgentCameraWorker.execute()` returns a canned string.
- `lib/application/onyx_agent_camera_bridge_receiver.dart:77–103` — `GenericOnyxAgentCameraWorker.execute()` is identical pattern.
- All remaining workers follow the same stub pattern.

**Decision needed:** Does Zaks want the workers to begin issuing real ISAPI/ONVIF calls when credentials are available, or remain intent-only scaffolding that Codex documents as "staged only"? The answer determines the design of the credential path (see P1 below).

---

### P1 — Action: DECISION
**No credential path exists in the execution packet.**

`OnyxAgentCameraExecutionPacket` has a `credentialHandling` field that is a plain-text operator note (e.g. `"Keep device credentials local."`). It carries no username, password, or credential reference. Workers never receive device credentials — even if they were real.

**Why it matters:** This is the integration blocker. Before Hikvision API credentials can be wired in, a design decision must be made:
- Option A: Packet carries a credential reference key; worker looks up credentials from a secure store (Supabase vault, local keychain, env config).
- Option B: Credentials are injected into the worker at construction time via the `OnyxAgentCameraBridgeReceiver` constructor.
- Option C: The bridge server receives credentials in the HTTP request alongside the execution packet (not recommended — exposes them in logs).

`DvrHttpAuthConfig` is already the right abstraction. `HikvisionOnyxAgentCameraWorker` just needs it injected.

**Evidence:**
- `lib/application/onyx_agent_camera_change_service.dart:19–42` — `OnyxAgentCameraExecutionPacket` definition; `credentialHandling` is `String`, not a `DvrHttpAuthConfig`.
- `lib/application/dvr_http_auth.dart:18–29` — `DvrHttpAuthConfig` exists and is ready.

---

### P1 — Action: REVIEW
**`_upstreamAlertConnected` reads as `false` during reconnect delay, even after a successful poll cycle.**

In `LocalHikvisionDvrProxyService._ensureUpstreamAlertSubscription()` (lines 384–432), the `finally` block at line 430 unconditionally sets `_upstreamAlertConnected = false`. This runs after every loop iteration — including successful ones — before the reconnect delay. The `/health` endpoint reports `upstream_stream_connected: false` during the `upstreamReconnectDelay` sleep even when the last cycle succeeded.

**Why it matters:** Operators monitoring bridge health see transient `false` signals after every poll. If they script on this field, they will see intermittent alerts. This does not affect actual proxy behaviour but is misleading.

**Evidence:**
- `lib/application/local_hikvision_dvr_proxy_service.dart:417–430` — `_upstreamAlertConnected = true` at line 408, then `finally { _upstreamAlertConnected = false; }` at line 430 unconditionally.

**Suggested Codex validation:** Check whether any test asserts `upstream_stream_connected: true` after a successful poll with a delay in between. If not, this is consistently mis-reporting.

---

### P2 — Action: AUTO
**MJPEG relay loop has no cap on consecutive upstream failures before closing the stream.**

`_relaySnapshotMjpeg` (lines 543–641) loops until `response.flush()` throws (client disconnect) or the upstream returns non-2xx. There is no consecutive-failure counter or max-retry guard. If the upstream intermittently returns 200 with empty bytes, `_fetchSnapshotFrame` returns a frame with `statusCode: 200` and `bytes: []`, which passes the 2xx check at line 619 — so the relay continues writing empty MJPEG frames to the client indefinitely.

**Why it matters:** A flapping upstream can pin relay client connections open, accumulating `activeClientCount` entries and consuming file descriptors.

**Evidence:**
- `lib/application/local_hikvision_dvr_proxy_service.dart:595–641`
- `lib/application/local_hikvision_dvr_proxy_service.dart:643–663` — `_fetchSnapshotFrame` returns a frame even with empty `bytes`.

**Suggested Codex validation:** Add a consecutive-empty-frame counter and break after N consecutive empty frames (e.g. 5). The `_relayStaleAfter` logic already exists as a quality proxy; a frame-failure threshold fits the same pattern.

---

### P2 — Action: REVIEW
**Digest nonce re-challenge mid-MJPEG session would terminate the relay silently.**

`DvrHttpAuthConfig.send()` retries once on 401 using the challenge from the initial response. If Hikvision rotates the nonce mid-session (which it does on some firmware revisions), the next `_fetchSnapshotFrame` call will receive a fresh 401. That 401 is non-2xx, so `_relaySnapshotMjpeg` breaks the loop at line 619–626 and closes the MJPEG stream without an operator-visible error beyond a stale relay state.

**Why it matters:** The relay silently drops mid-session for a known Hikvision behaviour. The operator sees a frozen image in the player rather than an error message.

**Evidence:**
- `lib/application/dvr_http_auth.dart:59–87` — single-retry digest flow.
- `lib/application/local_hikvision_dvr_proxy_service.dart:615–626` — non-2xx breaks the relay loop.

**Suggested Codex validation:** Check if `lastError` is populated when the relay closes due to non-2xx; confirm the player status endpoint (`/onyx/live/channels/{id}/status`) surfaces `error` state so operators are notified.

---

### P2 — Action: AUTO
**`OnyxAgentCameraBridgeServer` (IO impl) does not validate content-type before JSON decode.**

`LocalHttpOnyxAgentCameraBridgeServer._handleRequest()` (server_io.dart line 125) reads the raw body with `utf8.decoder.bind(request).join()` and then calls `jsonDecode` without first checking `Content-Type`. A request body that is valid UTF-8 but not JSON falls into the `FormatException` catch at line 146 — that is handled correctly — but a body with a trailing null byte or embedded binary produces an unhandled `StateError` from the Dart JSON decoder, which falls to the generic `catch (error)` at line 155 and returns a 500 with `error.toString()` in the response. This exposes an internal Dart error message to callers.

**Evidence:**
- `lib/application/onyx_agent_camera_bridge_server_io.dart:125–165`

**Suggested Codex validation:** Wrap `jsonDecode` in a try-catch that narrows to both `FormatException` and `Exception`; return a consistent 400 with a fixed detail string.

---

### P3 — Action: AUTO
**`frame_limit` query parameter in MJPEG relay is untested.**

`_relaySnapshotMjpeg` reads `frame_limit` from query parameters (line 547) and breaks after that many frames. No test exercises this code path. If `int.tryParse` returns null (malformed value), `frameLimit` is null and the relay runs until disconnect — correct but unverified.

**Evidence:**
- `lib/application/local_hikvision_dvr_proxy_service.dart:547–549`
- `test/application/local_hikvision_dvr_proxy_service_test.dart` — no `frame_limit` test case found.

---

### P3 — Action: REVIEW
**`LocalHikvisionDvrProxyService.close()` closes the injected `http.Client` — shared-client hazard.**

`close()` calls `client.close()` on the injected client (line 113). If the caller shares this `http.Client` instance with another service (e.g. the DVR event probe), closing the proxy will silently break all other HTTP calls on that client with `ClientException: HTTP request failed, statusCode: null`. The service does not own the client lifecycle, yet it terminates it.

**Evidence:**
- `lib/application/local_hikvision_dvr_proxy_service.dart:107–116` — `client.close()` unconditional.
- `lib/application/local_hikvision_dvr_proxy_service.dart:65–77` — `client` is injected via constructor with no ownership documentation.

**Suggested Codex validation:** Grep call sites in `main.dart` and any controller that constructs `LocalHikvisionDvrProxyService`. If the same `http.Client()` is passed here and to another service, either give the proxy its own dedicated client or remove `client.close()` from `close()`.

---

### P3 — Action: REVIEW
**`_bufferedAlertPayload()` produces an invalid multi-root XML fragment when more than one event is buffered.**

`_bufferedAlertPayload()` joins multiple `<EventNotificationAlert>` blocks with `'\n'`. The resulting string has multiple root elements and is not valid XML. Any downstream parser that calls `XmlDocument.parse()` on this payload will throw.

**Evidence:**
- `lib/application/local_hikvision_dvr_proxy_service.dart:454–457` — `.join('\n')` with no XML wrapper.
- `lib/application/local_hikvision_dvr_proxy_service.dart:436–452` — `_bufferAlertPayload` can push multiple events in a single poll cycle.

**Suggested Codex validation:** Check what consumes the `/ISAPI/Event/notification/alertStream` response from the proxy (DVR ingest adapter, AI assessment). If XML parsing is downstream, wrap the result in a single `<EventNotificationAlertList>` root element or serve one event per response with a queue-drain model.

---

### P3 — Action: REVIEW
**No test covers bridge server behaviour when `execute` is called while the bridge is not running.**

The bridge health flow (receipt state machine) tracks whether the server is live, but no test submits a POST /execute to the bridge when the server is stopped, or when the `UnsupportedOnyxAgentCameraBridgeServer` (web stub) is active.

**Evidence:**
- `test/application/onyx_agent_camera_bridge_server_test.dart` — present but scope unclear; needs review for stop/restart lifecycle coverage.
- `lib/application/onyx_agent_camera_bridge_server_stub.dart:24` — `start()` and `close()` are silent no-ops.

---

## Integration Path: Credentials → Real Camera Control

When Hikvision API credentials arrive, the following steps connect them to real device writes:

**Step 1 — Credential carrier (DECISION first)**
Add `DvrHttpAuthConfig? deviceAuth` to `OnyxAgentCameraExecutionPacket` or inject a `Map<String, DvrHttpAuthConfig>` keyed by device target into `HikvisionOnyxAgentCameraWorker`. The second form avoids credentials in serialized packets (audit trail) and matches the existing pattern in `LocalHikvisionDvrProxyService`.

**Step 2 — Replace the stub worker body**
`HikvisionOnyxAgentCameraWorker.execute()` (`onyx_agent_camera_bridge_receiver.dart:115–130`) needs to issue real ISAPI calls:
- `GET /ISAPI/System/deviceInfo` — confirm device identity before any write.
- `GET /ISAPI/Streaming/channels` — enumerate available channels.
- `PUT /ISAPI/Streaming/channels/{id}` — apply the approved stream profile.
- `GET /ISAPI/Streaming/channels/{id}` — verify the write took effect.

`DvrHttpAuthConfig.send()` is already the correct transport for all of these.

**Step 3 — Return a real `remoteExecutionId`**
Currently `remoteExecutionId` is `"worker-hikvision-{profileKey}-{packetId}"` (a synthetic string). With real calls it should be the Hikvision `sessionID` or the channel response `id` from the verify read.

**Step 4 — Failure handling**
The worker must set `success: false` on non-2xx upstream responses or verify-read mismatches. Currently `success` is always `true`.

**Step 5 — Wire credentials into the runtime**
`OnyxAgentCameraBridgeReceiver` is constructed in `main.dart` or a provider. The credential lookup (from `OpsIntegrationProfile` or local config) must be passed at construction time, not carried in the packet.

---

## Duplication

- The HTML player page in `LocalHikvisionDvrProxyService._writeRelayPlayerPage()` (lines 665–906) is a 240-line inline HTML/CSS/JS string. If a second relay player type is needed, this becomes a copy-paste target. Not urgent but a centralization candidate.
- `_writeCorsHeaders` appears in both `LocalHikvisionDvrProxyService` and `LocalHttpOnyxAgentCameraBridgeServer`. They differ only in allowed methods. Acceptable duplication at current scale.
- `_parseDigestChallenge` in `DvrHttpAuthConfig` could be shared if a second auth client is added for ISAPI write calls. Not a problem now.

---

## Coverage Gaps

| Gap | Risk |
|-----|------|
| No test for `frame_limit` query param in MJPEG relay | Low — fallback is correct, but feature is dark |
| No test for MJPEG relay with consecutive upstream failures | Medium — relates to the P2 empty-frame bug above |
| No test for `HikvisionOnyxAgentCameraWorker` with real ISAPI calls | Blocked — will be needed the moment credentials arrive |
| No test for bridge server stop/restart lifecycle | Low |
| No test for web stub platform (`UnsupportedOnyxAgentCameraBridgeServer`) surfacing in health UI | Low |
| No test for digest nonce re-challenge mid-MJPEG session | Medium — Hikvision-specific behaviour |
| `OnyxAgentCameraChangePlanResult.toOperatorSummary()` not directly tested | Low |
| No test for `_bufferedAlertPayload()` with multiple events (XML validity) | Medium — silent parse failure downstream |
| No test for proxy `close()` when `http.Client` is shared with another service | Medium — silent HTTP breakage |

---

## Performance / Stability Notes

- **MJPEG relay accumulates `activeClientCount` but never resets on server close.** If `close()` is called while relay loops are active, the loops will hit `response.flush()` errors and break, but `runtime.activeClientCount` is decremented only in the `finally` block of `_relaySnapshotMjpeg`. If the exception escapes before `finally` (it shouldn't in Dart but worth verifying), counts leak. This is stable by inspection but warrants a test.
  - Evidence: `lib/application/local_hikvision_dvr_proxy_service.dart:590–641`, `finally` at line 638.

- **Alert buffer is in-memory only.** `_bufferedAlertEvents` is a `List` that lives for the process lifetime. On a busy site (many VMD events), with 80-event cap and 3-minute retention this is bounded. No concern at current scale.

- **Proxy does not limit concurrent MJPEG relay clients.** Each `GET /onyx/live/channels/{id}.mjpg` spawns a new relay loop. If 10 browser tabs open the same channel, 10 loops poll the upstream independently at `mjpegFrameInterval`. For the current single-operator use case this is fine but will degrade under load.

---

## Recommended Fix Order

1. **(DECISION — block)** Agree on credential carrier design for `HikvisionOnyxAgentCameraWorker`. Until this is decided, no implementation can proceed for real camera writes.

2. **(REVIEW — before next operator demo)** Add a visible notice to the camera change UI that workers are currently in intent-only mode. Prevents operator confusion about whether changes were applied.

3. **(AUTO)** Fix `_ensureUpstreamAlertSubscription` `finally` block to only clear `_upstreamAlertConnected` when actually disconnecting, not after every successful poll.

4. **(AUTO)** Add consecutive-failure guard to `_relaySnapshotMjpeg` to close relay after N consecutive empty/failed frames.

5. **(AUTO)** Harden `LocalHttpOnyxAgentCameraBridgeServer` JSON decode to catch all decode exceptions and return a stable 400.

6. **(AUTO)** Add `frame_limit` test to `local_hikvision_dvr_proxy_service_test.dart`.

7. **(REVIEW)** Investigate digest nonce re-challenge mid-MJPEG relay and decide whether to add a re-auth retry loop in `_fetchSnapshotFrame`.

8. **(REVIEW)** Audit `LocalHikvisionDvrProxyService` call sites — if `http.Client` is shared, remove `client.close()` from `close()`.

9. **(REVIEW)** Decide whether `_bufferedAlertPayload()` needs a valid XML root wrapper before downstream consumers are built or expanded.
