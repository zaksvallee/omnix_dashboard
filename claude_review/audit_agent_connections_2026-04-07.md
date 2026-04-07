# Audit: Agent Connections

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: All `*agent*` and `*brain*` files under `lib/`
- Read-only: yes

---

## Files Inspected

| File | Role |
|---|---|
| `lib/application/onyx_agent_local_brain_service.dart` | Local Ollama brain |
| `lib/application/onyx_agent_cloud_boost_service.dart` | OpenAI cloud brain + shared advisory types |
| `lib/application/onyx_agent_context_snapshot_service.dart` | Event-derived context snapshot |
| `lib/application/onyx_agent_client_draft_service.dart` | Client comms draft |
| `lib/application/onyx_command_brain_orchestrator.dart` | Brain fusion orchestrator |
| `lib/domain/authority/onyx_command_brain_contract.dart` | Brain decision contract types |
| `lib/application/onyx_agent_camera_probe_service.dart` | Camera TCP/HTTP reachability probe |
| `lib/application/onyx_agent_camera_change_service.dart` | Camera change stage + execute pipeline |
| `lib/application/onyx_agent_camera_bridge_receiver.dart` | Vendor worker dispatcher |
| `lib/application/onyx_agent_camera_bridge_server.dart` | Bridge server factory |
| `lib/application/onyx_agent_camera_bridge_server_io.dart` | Real HTTP server (IO only) |
| `lib/application/onyx_agent_camera_bridge_server_stub.dart` | No-op stub (web) |
| `lib/application/onyx_agent_camera_bridge_health_service.dart` | Bridge health probe + state resolution |
| `lib/application/onyx_agent_camera_bridge_server_contract.dart` | Bridge contract + status types |
| `lib/application/onyx_agent_tcp_probe_io.dart` | Real TCP socket probe (IO only) |
| `lib/application/onyx_agent_tcp_probe_stub.dart` | Always-false TCP stub (web) |
| `lib/ui/onyx_agent_page.dart` | Agent UI entry point (props injected) |

---

## Executive Summary

The AI brain agents (Ollama local, OpenAI cloud) have real live-data connections when properly configured; they are not hardcoded. The context snapshot pipeline is also real, derived from injected `DispatchEvent` lists.

The camera execution side is the structural weak point. All vendor workers (Hikvision, Dahua, Axis, Uniview, Generic) return simulated "success" outcomes with no real ONVIF writes. The TCP probe silently returns all-false on web builds. The camera bridge server never starts on web. Together these create a gap where an operator sees "success" or "closed" for states that have never been tested against real hardware.

Two brain services share identical silent `catch (_) → null` exception burial. The caller receives a null response with no way to distinguish AI failure from AI producing no recommendation.

---

## What Looks Good

- `OnyxAgentContextSnapshotService` is well-structured: pure derivation from real events, scoped filtering, site-priority scoring, and welfare signals without any hardcoded values.
- The brain advisory JSON parser (`_tryParseBrainAdvisory`) handles both valid JSON, markdown-wrapped JSON, and plain-text fallbacks robustly.
- The context highlight merging and planner pressure promotion logic is well-tested territory (extensive helpers like `onyxAgentPrioritizedContextHighlights`).
- The `OnyxCommandBrainOrchestrator` cleanly fuses deterministic triage, specialist assessments, replay biases, and AI advisory into one `BrainDecision` with legible rationale.
- Conditional imports (`dart.library.io`) for TCP probe and bridge server are correct and compile-safe.
- `HttpOnyxAgentCameraDeviceExecutor` has a real HTTP POST path to a camera bridge endpoint with proper auth header injection.

---

## Findings

### P1 — Camera vendor workers return simulated outcomes only

- **Action: DECISION**
- **Finding:** Every vendor worker in `OnyxAgentCameraBridgeReceiver` returns a hardcoded `success: true` outcome built entirely from packet fields. No ONVIF network call is made. No camera device is actually written.
- **Why it matters:** An operator approves a camera profile change, the UI reports "executed", but the camera is unchanged. Rollback labels are also phantom — there is no prior state to restore because no write ever happened. This is the highest-impact gap in the entire agent pipeline.
- **Evidence:**
  - `onyx_agent_camera_bridge_receiver.dart:87-103` (Generic worker): `return OnyxAgentCameraExecutionOutcome(success: true, providerLabel: 'local:camera-worker:generic-onvif', detail: '$workerLabel prepared ...')` — text is constructed from packet fields, no HTTP/ONVIF call.
  - Same pattern at lines 116-130 (Hikvision), 143-157 (Dahua), 174-186 (Axis), 200-212 (Uniview).
- **Suggested follow-up for Codex:** Confirm whether vendor workers are intentionally simulated as an approval-gating scaffold (i.e., real writes happen in an external process that POSTs to the bridge server). If so, document this contract and add a UI label such as "Pending device confirmation." If workers are expected to write directly, a real ONVIF HTTP layer is missing.

---

### P1 — TCP probe silently returns all-false on web builds

- **Action: REVIEW**
- **Finding:** `onyx_agent_tcp_probe_stub.dart` (the web platform implementation) unconditionally returns `false` for every port. `HttpOnyxAgentCameraProbeService` uses this via the `OnyxAgentPortProbe` typedef. On any web build, every camera appears to have all ports closed, and `hasAnyReachablePort` is always false, producing the "confirm device is on the LAN" message regardless of actual device state.
- **Why it matters:** The camera probe UI misleads web-build operators into thinking cameras are unreachable even when they are live on the LAN. It presents an incorrect operational picture without any caveat.
- **Evidence:**
  - `onyx_agent_tcp_probe_stub.dart:1-7`: body is `return false;`.
  - `onyx_agent_camera_probe_service.dart:67`: `portProbe = portProbe ?? tcp_probe.onyxAgentCanConnect` — picks the stub on web.
  - `onyx_agent_camera_probe_service.dart:34-44` (`toOperatorSummary`): the "Next step" message leads operator to check power/PoE if no reachable port.
- **Suggested follow-up for Codex:** Add a `isProbeSupported` flag to `OnyxAgentCameraProbeService` that returns false on web. The probe UI should show "Port probe not available on web" rather than showing all ports as closed.

---

### P1 — Silent exception swallowing in both brain services

- **Action: AUTO**
- **Finding:** Both `OllamaOnyxAgentLocalBrainService.synthesize()` and `OpenAiOnyxAgentCloudBoostService.boost()` have a bare `catch (_) { return null; }` wrapping the entire HTTP call and JSON parse. Network errors, auth failures (401), timeouts, and malformed JSON all produce the same null return. The caller cannot distinguish "AI returned no recommendation" from "AI call failed."
- **Why it matters:** A hard API key failure (expired token, quota exceeded) looks identical to a deliberate "no recommendation." Operators and the page have no way to surface a service degradation warning. This also hides bugs during development.
- **Evidence:**
  - `onyx_agent_local_brain_service.dart:115`: `catch (_) { return null; }`.
  - `onyx_agent_cloud_boost_service.dart:322`: `catch (_) { return null; }`.
- **Suggested follow-up for Codex:** Replace bare `catch (_)` with typed or named error capture. At minimum return a `OnyxAgentCloudBoostResponse` with an `isError` flag, or define a separate error return type. The caller in `OnyxAgentPage` can then surface a degraded-state chip.

---

### P1 — Camera bridge server is a no-op on web; UI still shows validation controls

- **Action: REVIEW**
- **Finding:** `UnsupportedOnyxAgentCameraBridgeServer.start()` is a no-op. The bridge server never binds on web. Yet the camera bridge UI (health validation, receipt state) is rendered in `OnyxAgentPage` regardless of platform. Operators on a web build can click "Run First Validation" and get a response driven by `UnconfiguredOnyxAgentCameraBridgeHealthService` which always returns `reachable: false`. The receipt state then shows `RECEIPT_MISSING` or `DISABLED`, which is accurate but potentially confusing if the operator expects the bridge to be functional.
- **Why it matters:** A controller running the web build will never have a functional camera bridge server. The UI does not communicate why. Operationally this means camera change approvals on web go through `HttpOnyxAgentCameraDeviceExecutor` (if configured at page level) posting to an external bridge process — but the bridge health UI is showing the state of the local embedded server, not that external one.
- **Evidence:**
  - `onyx_agent_camera_bridge_server_stub.dart:25`: `Future<void> start() async {}`.
  - `onyx_agent_camera_bridge_health_service.dart:1349-1371`: `UnconfiguredOnyxAgentCameraBridgeHealthService.probe()` always sets `reachable: false, running: false`.
  - `onyx_agent_page.dart:90-91`: Default value is `UnconfiguredOnyxAgentCameraBridgeHealthService()`.
- **Suggested follow-up for Codex:** Add a `isSupported` getter to `OnyxAgentCameraBridgeServer` that returns false on the stub. The UI layer should collapse or replace the bridge panel with an "only available on desktop" message when the server is unsupported.

---

### P2 — `LocalOnyxAgentClientDraftService` is always a fixed template; `isConfigured` is misleading

- **Action: REVIEW**
- **Finding:** `LocalOnyxAgentClientDraftService.isConfigured` returns `true` and `draft()` always succeeds, but the output is a static template string (`'We are verifying $incidentLabel now...'`). The `providerLabel = 'local:formatter'` correctly signals this, but the `isConfigured = true` response suggests full AI capability to any caller that gates on configuration state.
- **Why it matters:** If the page uses `isConfigured` to decide whether to show an "AI-assisted draft" badge or take an action, `LocalOnyxAgentClientDraftService` will always appear as a capable service. The operator may believe they are getting an AI-tuned draft when they are getting a boilerplate.
- **Evidence:**
  - `onyx_agent_client_draft_service.dart:34`: `bool get isConfigured => true;`
  - `onyx_agent_client_draft_service.dart:51-57`: Body is a static string interpolation.
- **Suggested follow-up for Codex:** Either rename this to `TemplateOnyxAgentClientDraftService` or add a `isAiAssisted` getter (false for template, true for AI). Callers should use this to label drafts accurately in the comms UI.

---

### P2 — `OnyxAgentContextSnapshotService` events dependency is invisible to the agent pipeline

- **Action: REVIEW**
- **Finding:** The entire brain context pipeline depends on `List<DispatchEvent> events` being injected into `OnyxAgentPage`. The agent files themselves have no enforcement of event freshness or connectivity. If the caller does not wire events to a live Supabase subscription, both brain services receive an empty context summary (`No scoped operational events are loaded yet`), and advisory quality degrades silently.
- **Why it matters:** A developer who integrates `OnyxAgentPage` without hooking up the Supabase event stream will get a working UI with degraded AI quality and no visible error. This is a silent misconfiguration that is hard to diagnose.
- **Evidence:**
  - `onyx_agent_context_snapshot_service.dart:163-169`: `capture` requires `List<DispatchEvent> events` — no null/empty guard with warning.
  - `onyx_agent_context_snapshot_service.dart:197-203`: Empty events produce `OnyxAgentContextSnapshot.empty(...)` with no error signal.
  - `onyx_agent_page.dart:48-49`: `events = const <DispatchEvent>[]` default.
- **Suggested follow-up for Codex:** Confirm in the calling code (the parent widget or route) that `events` is sourced from a live Supabase subscription, not a stale cache or empty default. Consider adding a `debugAssert(events.isNotEmpty, ...)` during development to catch misconfiguration early.

---

### P2 — `probeOnyxAgentCameraBridgeHealthSnapshot` has no exception guard

- **Action: AUTO**
- **Finding:** The top-level helper `probeOnyxAgentCameraBridgeHealthSnapshot` calls `await service.probe(endpoint)` with no try/catch. If the HTTP client throws (connection refused, network unreachable, OS-level socket error), the exception propagates up through `completeOnyxAgentCameraBridgeValidation` into the UI call site.
- **Why it matters:** On desktop IO builds with a real `HttpOnyxAgentCameraBridgeHealthService`, a connection refused at bridge startup (before the server is ready) will throw an uncaught exception. This can leave `validationInFlight = true` permanently if the future never settles in `OnyxAgentPage`.
- **Evidence:**
  - `onyx_agent_camera_bridge_health_service.dart:692-701`: no try/catch around `service.probe(endpoint)`.
  - `onyx_agent_camera_bridge_health_service.dart:1387-1427`: `HttpOnyxAgentCameraBridgeHealthService.probe()` has its own try/catch internally — but only for the HTTP response phase after the initial connection completes. `client.get(healthEndpoint)` can still throw before the try block catches.
- **Suggested follow-up for Codex:** Wrap the call in `probeOnyxAgentCameraBridgeHealthSnapshot` with a try/catch that returns an `OnyxAgentCameraBridgeHealthSnapshot` with `reachable: false, running: false` on any exception. This matches the behavior of `UnconfiguredOnyxAgentCameraBridgeHealthService`.

---

### P2 — `LocalOnyxAgentCameraDeviceExecutor.isConfigured` returns `false` despite being callable

- **Action: REVIEW**
- **Finding:** `LocalOnyxAgentCameraDeviceExecutor` at line 532 returns `isConfigured => false`. This class takes an `OnyxAgentCameraExecutionDelegate executeWith` and is fully callable. Any caller that checks `isConfigured` before calling `execute()` will skip this executor silently, even if it has a valid delegate.
- **Why it matters:** The executor exists as a DI point for testing or for scenarios where a custom delegate handles the actual write. The `false` value appears to be an oversight — it signals "not ready" for a class that is structurally complete.
- **Evidence:**
  - `onyx_agent_camera_change_service.dart:530-532`.
- **Suggested follow-up for Codex:** Confirm whether `LocalOnyxAgentCameraDeviceExecutor` is intentionally disabled or whether `isConfigured` should return `executeWith != null` (i.e., always true since the constructor requires the delegate).

---

## Duplication

### 1. Brain service prompt-assembly and post pipeline
- **Files:** `onyx_agent_local_brain_service.dart:56-117`, `onyx_agent_cloud_boost_service.dart:246-324`
- **Pattern:** Both services share identical structure: guard on `isConfigured + prompt empty`, inject pending follow-up block, inject operator focus block, inject context summary, POST, extract text, parse raw text via `onyxAgentCloudBoostResponseFromRawText`, call `onyxAgentMergePlannerMaintenancePriorityHighlight`. Differences are only the endpoint format and auth headers.
- **Risk:** A future change to context injection order (e.g., adding a new signal type) must be replicated in both services. Already happened with `hasPendingFollowUp` and `hasOperatorFocusContext` — both blocks are copy-pasted.
- **Centralization candidate:** An `OnyxBrainRequestBuilder` that assembles the message list given a scope, intent, and context summary. Each service calls the builder and handles only its own HTTP format.

### 2. Vendor worker `execute()` bodies
- **Files:** `onyx_agent_camera_bridge_receiver.dart:87-215`
- **Pattern:** All five vendor workers return `OnyxAgentCameraExecutionOutcome(success: true, ...)` with a vendor-specific `detail` string. The structure is identical.
- **Risk:** Extending workers (adding error simulation, partial success, or real ONVIF calls) requires touching each class separately.
- **Centralization candidate:** A shared `_buildSimulatedOutcome(String workerLabel, String vendorKey, OnyxAgentCameraExecutionPacket packet, String packetId)` helper function.

---

## Coverage Gaps

1. **Brain service failure paths are untested.** The `catch (_) → null` paths in both brain services have no test coverage. No test confirms that a 401, a timeout, or malformed JSON from Ollama or OpenAI produces a null return (vs. throwing).

2. **TCP stub behavior is untested.** No test confirms that `onyxAgentCanConnect` on the stub returns `false`. A test that runs the camera probe service with the stub and asserts `openPorts = {80: false, ...}` would lock this platform behaviour.

3. **Vendor worker simulate-only contract is unlocked.** The five vendor workers return `success: true` always. There is no test asserting the expected outcome shape for each vendor. This means a future edit to a worker detail string (e.g., to add real ONVIF content) will not be caught by a regression.

4. **`LocalOnyxAgentCameraDeviceExecutor` isConfigured gap.** No test covers the `isConfigured = false` behaviour, so the intent is ambiguous. A test labelling this as intentional (or as an oversight) would clarify the contract.

5. **Context snapshot with empty events.** No test confirms the brain receives `'No scoped operational events are loaded yet'` in the context summary when events are empty. This is the degraded-quality path that is easiest to miss.

---

## Performance / Stability Notes

1. **Bridge health validation leaves `validationInFlight = true` on uncaught exception.** Described in P2 finding above. If `completeOnyxAgentCameraBridgeValidation` throws, `OnyxAgentPage` state machine may be stuck showing "Checking Bridge..." indefinitely.

2. **`OnyxAgentCameraProbeService` probes 4 TCP ports + 2 HTTP endpoints sequentially.** All port probes run in a `for` loop with `await` — 4 × 1-second TCP timeout = 4 seconds minimum latency on a cold probe if all ports are closed. Parallel port probing (`Future.wait`) would bring this to 1 second.
   - Evidence: `onyx_agent_camera_probe_service.dart:76-78`.

3. **`OllamaOnyxAgentLocalBrainService` timeout is 25 seconds** vs OpenAI at 18 seconds. Both operate without a loading state that the user can cancel. If Ollama is running but slow, the UI is blocked for up to 25 seconds with no abort path visible in the agent pipeline.
   - Evidence: `onyx_agent_local_brain_service.dart:44`.

---

## Recommended Fix Order

1. **P1 — Vendor worker simulation contract (DECISION).** This must be clarified before any real device integration. Either document the simulate-only intent (and label it in the UI), or escalate to real ONVIF plumbing. This is the highest-risk gap for operational correctness.

2. **P1 — Silent brain exception swallowing (AUTO).** Low effort, high diagnostic value. Codex can add typed error capture and an `isError` field to `OnyxAgentCloudBoostResponse` without changing any existing caller behaviour.

3. **P2 — `probeOnyxAgentCameraBridgeHealthSnapshot` exception guard (AUTO).** Single try/catch wrapping the probe call, returns a safe failure snapshot. Prevents stuck loading state.

4. **P1 — TCP probe stub disclosure (REVIEW).** Add `isProbeSupported` to the probe service interface. The UI panel should handle false gracefully. Requires Zaks decision on whether to show or hide the probe section on web.

5. **P1 — Bridge server web no-op disclosure (REVIEW).** Add `isSupported` to `OnyxAgentCameraBridgeServer`. Collapse the bridge UI panel when the server cannot start. Requires Zaks decision on UX posture.

6. **P2 — `LocalOnyxAgentCameraDeviceExecutor.isConfigured` intent clarification (REVIEW).** One-line fix once intent is confirmed. Low risk, clarifies DI contract.

7. **Performance — Parallel TCP port probes.** `Future.wait` over the 4 port probes. Straightforward refactor, no behaviour change.
