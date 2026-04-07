# Audit: live_operations_page.dart — REVIEW Items Follow-Up

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: Three flagged REVIEW items from the initial audit of `lib/ui/live_operations_page.dart`
- Read-only: yes

---

## Executive Summary

All three items were confirmed in source. Two are real bugs with meaningful operator or test-isolation risk (`catch (_)` swallowing camera errors, `onQueueStateHintSeen?.call()` inside `setState`). One is an intentional design choice (session singletons) with a partially-mitigated but incomplete test isolation risk. Action labels are assigned below.

---

## Item 1 — Static mutable fields: `_queueStateHintSeenThisSession` and `_replayHistoryMemoryByScopeThisSession`

### Are these intentional session singletons or test isolation bugs?

**Answer: Intentional session singletons with an incomplete test isolation mitigation.**

**Design intent (confirmed from source):**
The fields are declared as `static` on `_LiveOpsPageState` (lines 1282–1285) so they survive widget dispose/recreate within the same app session. The `queueStateHintSeen` widget prop provides the durable, persisted value from the parent; the static acts as an in-memory cross-instance cache so that navigating away and back does not re-show a hint the operator already dismissed. The replay history memory map serves the same cross-instance continuity purpose.

**Evidence of design intent:**
- `initState` (line 2462–2465): seeds the static FROM the widget prop, so parent-persisted state wins on first mount.
- `didUpdateWidget` (line 2501–2507): syncs the static to the prop if the parent flips it externally.
- `debugResetQueueStateHintSession()` / `debugResetReplayHistoryMemorySession()` (lines 1643–1650): explicit test-only reset hooks were added, confirming awareness of the test isolation risk.

**The actual test isolation risk:**

The debug resets are called selectively — only in tests that directly exercise the hint or replay memory features. This leaves an incomplete safety net.

| Reset usage | File | Lines | Has `addTearDown`? |
|---|---|---|---|
| `debugResetQueueStateHintSession()` | `live_operations_page_widget_test.dart` | 6653 | No |
| `debugResetQueueStateHintSession()` | `live_operations_page_widget_test.dart` | 6810 | Yes (line 6810+addTearDown) |
| `debugResetQueueStateHintSession()` | `onyx_app_admin_route_widget_test.dart` | 4538 | Yes (line 4542) |
| `debugResetReplayHistoryMemorySession()` | `live_operations_page_widget_test.dart` | 2695–2696, 2823–2824, 2930–2931, 3000–3001, 3055–3056 | All have `addTearDown` |

**Specific gap identified:**
The test at line 6650 (`live operations shows queue-state first-run hint until queue interaction`) resets the static at entry but has **no `addTearDown`**. This test taps the queue chip, which triggers `_markQueueStateHintSeen()` and leaves `_queueStateHintSeenThisSession = true`. Any subsequent test in the same file that:
- expects the queue hint to be visible
- passes `queueStateHintSeen: false` (the default)
- does NOT call `debugResetQueueStateHintSession()`

…will silently see no hint and may pass or fail for the wrong reason.

The broader risk is structural: any new test author who exercises the hint without knowing about the reset requirement will write an order-dependent test.

**Risk:** MEDIUM — the existing hint tests reset correctly, but the safety net is implicit knowledge, not enforced.

**Suggested fix for Codex to validate:**
1. Add `addTearDown(LiveOperationsPage.debugResetQueueStateHintSession)` to the test at line 6650 (currently missing).
2. Audit all `testWidgets` blocks that interact with queue chip controls (`control-inbox-queue-state-chip`, `top-bar-queue-state-chip`) to confirm none of them inadvertently leave the static set and affect downstream hint-visibility tests.
3. Consider a shared `setUp` block at the top of the `live_operations_page_widget_test.dart` file that calls both resets unconditionally, eliminating the per-test boilerplate and the missed-tearDown class of bug.

**Action: REVIEW** — the session singleton pattern is intentional and should not be removed. The fix scope is test harness only, but Zaks should confirm that a blanket `setUp` reset is acceptable before Codex applies it (it changes test execution assumptions for the whole file).

---

## Item 2 — Silent `catch (_)` in `_loadClientLaneCameraHealth`

### What is being swallowed and what is the operator impact?

**Evidence:** Lines 1420–1424 in `lib/ui/live_operations_page.dart`:

```dart
try {
  packet = await loader(snapshot.clientId, snapshot.siteId);
} catch (_) {
  packet = null;
}
```

**What is swallowed:**
The catch is untyped (`catch (_)`) and discards both the exception and the stack trace entirely. Any throwable from `loader(...)` — which is `widget.onLoadCameraHealthFactPacketForScope` — is silently converted to `null`. This includes but is not limited to:

- `SocketException` / `TimeoutException` — network unreachable or camera API timeout
- HTTP 401/403 from a Supabase or proxy layer — auth token expired or revoked
- `FormatException` / `TypeError` — malformed camera health response
- Any custom exception thrown by the camera bridge service
- `FlutterError` or assertion failures bubbling from a mocked loader in tests

**Operator impact — two paths:**

1. **Auto-refresh path** (`showFeedback: false`, the default): called from `initState` (line 2469) and from the periodic timer (line 1630). When the loader throws, the spinner disappears, `_clientLaneCameraHealthFactPacket` becomes `null`, and the UI renders exactly as if no cameras are configured. **No error state, no log, no feedback.** The operator has no way to distinguish between "no cameras registered" and "camera API is broken."

2. **Manual refresh path** (`showFeedback: true`): triggered by the refresh button (line 9294). When the loader throws, `packet = null`, and the feedback message at line 1443 reads `'Camera health could not be loaded for the selected scope.'` — which at least signals a failure. However, the message conflates a legitimate "no cameras" state with an exception state, and the root cause is still invisible.

**Secondary risk:** The periodic timer at line 1624–1632 continues firing after failures. Each timer tick triggers a new `_loadClientLaneCameraHealth()` call, which catches and discards the same exception. In a degraded network or a revoked-auth scenario, this produces repeated silent failures with no backoff or circuit break.

**Risk:** HIGH for operational correctness. An operator monitoring a live site with a broken camera feed has zero indication from the UI that the feed is failing. This is a safety-relevant gap for a security operations platform.

**Suggested fix for Codex to validate:**
1. At minimum, log the caught exception: `debugPrint` or a proper logger call inside the catch block, with the scope key and error type.
2. Add a separate boolean state field (e.g., `_clientLaneCameraHealthLoadFailed`) that is set to `true` on exception and `false` on successful load. The UI camera panel should render a distinct "failed to load" state when this flag is true, separate from the "no cameras" null state.
3. Narrow the catch type if possible (e.g., `catch (e, st)`) and log both the error and stack trace.
4. Consider adding a failure counter or backoff guard to the periodic timer so repeated auth failures do not produce unbounded silent retries.

**Action: AUTO** — logging the exception is a safe, non-behavioural addition. The error-state flag and UI change are also low-risk. Codex may implement without asking, but should not change the `null`-returns-gracefully behavior for the case where `loader` is null or `snapshot` is null (lines 1393–1405), which is a legitimate expected-null path.

---

## Item 3 — `onQueueStateHintSeen?.call()` invoked inside `setState` closure

### Is this causing issues?

**Evidence:** `_markQueueStateHintSeen()` (lines 1652–1656):

```dart
void _markQueueStateHintSeen() {
  _queueStateHintSeenThisSession = true;
  _showQueueStateHint = false;
  widget.onQueueStateHintSeen?.call();   // ← external callback
}
```

Called exclusively from within `setState` closures:
- Line 1776–1778: `setState(() { _markQueueStateHintSeen(); })`
- Line 1784–1787: `setState(() { _controlInboxPriorityOnly = false; _markQueueStateHintSeen(); })`
- Line 1793–1795: `setState(() { _markQueueStateHintSeen(); })`
- Line 1804–1806: `setState(() { _markQueueStateHintSeen(); })`

**Flutter's contract for `setState` closures:**
The closure passed to `setState` is defined as a synchronous function that should only mutate local `State` fields. Flutter schedules a rebuild after `setState` returns. Side-effect callbacks — particularly external callbacks that may call `setState` on ancestor widgets — are not supposed to be placed inside the closure.

**Is it actively causing failures?**
Based on current code, **probably not** in production or in the test suite. `onQueueStateHintSeen` is a `VoidCallback?`, and looking at its typical usage (persisting the "seen" flag to `SharedPreferences` or equivalent), the callback likely only updates an ancestor's state variable asynchronously or schedules a `setState` on the next frame. Flutter's dirty-flag mechanism tolerates this in most cases because the parent's `setState` would be scheduled after the current build completes.

**Where it could cause a real failure:**
If `onQueueStateHintSeen` synchronously triggers `setState` on a widget that is currently being built (e.g., in a `Builder` or `StatefulBuilder` higher in the tree), Flutter will throw:
```
setState() or markNeedsBuild() called during build.
```
This is an intermittent error that is easy to miss in testing because it depends on the widget tree's current phase when the callback fires.

**Additionally,** Flutter's documentation for `setState` states: *"The provided callback is immediately called synchronously. It must not return a future... The setState callback must not call setState itself... it also must not start any asynchronous operations."* Calling an external `VoidCallback` that may itself call `setState` violates this contract, even if no crash currently materialises.

**Root cause of the design:**
`_markQueueStateHintSeen()` bundles three things: updating the static field, updating local state, and firing the external notification. It was designed as a single "mark seen" operation, but the external callback should not be inside `setState`.

**Suggested fix for Codex to validate:**
Restructure each call site to move the callback outside the `setState` closure. Pattern:

```dart
// Instead of:
setState(() { _markQueueStateHintSeen(); });

// Use:
setState(() {
  _queueStateHintSeenThisSession = true;
  _showQueueStateHint = false;
});
widget.onQueueStateHintSeen?.call();
```

The `_markQueueStateHintSeen()` helper can be either removed or split into a state-only mutation helper plus a separate notification call at each call site.

**Note:** `_restoreQueueStateHint()` (lines 1658–1661) calls `widget.onQueueStateHintReset?.call()` but does NOT appear to be called from within `setState` (it has its own `setState` at line 1804 that calls `_markQueueStateHintSeen`, not `_restoreQueueStateHint`). Codex should verify all call sites of `_restoreQueueStateHint` to confirm it is not also wrapped in `setState` somewhere.

**Action: REVIEW** — the fix is mechanical but touches four `setState` call sites plus the helper method. The pattern change also affects `_LiveOpsPageState`'s public contract with the widget props (`onQueueStateHintSeen`, `onQueueStateHintReset`). Zaks should confirm the intended timing semantics: should the parent be notified synchronously with the state change or immediately after the `setState` completes?

---

## Recommended Fix Order

1. **Item 2 — Camera loader silent catch** (AUTO): Log the caught exception and add a distinct error flag. No logic change, pure observability gain. Highest operator safety value.

2. **Item 3 — Callback inside `setState`** (REVIEW): Move `widget.onQueueStateHintSeen?.call()` outside the `setState` closure at all four call sites. Low-risk mechanical fix once Zaks confirms timing intent.

3. **Item 1 — Static field test isolation** (REVIEW): Add missing `addTearDown` to the queue hint test at line 6650, and consider a shared `setUp` reset for the full test file. Lowest urgency — existing tests pass — but high future-proofing value.
