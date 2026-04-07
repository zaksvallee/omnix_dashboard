# Audit: Export Coordinator — Clipboard, CSV, and JSON Duplication

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: All export/clipboard/download logic across `lib/ui/`
- Read-only: yes

---

## Executive Summary

The same three-line copy idiom — build payload → `JsonEncoder.withIndent` → `Clipboard.setData` — appears in **at least 9 UI files**, totalling **40+ distinct export method calls**. Each page reinvents its own feedback mechanism. `DispatchSnapshotFileService`, `TextShareService`, and `EmailBridgeService` are each instantiated redundantly as `static const` in two independent page states. There is no shared entry point for export logic anywhere in the codebase. A single `ExportCoordinator` service class could replace all of this with zero behaviour change.

---

## What Looks Good

- `onyx_camera_bridge_clipboard.dart` is a clean precedent: export logic already extracted to a standalone function file, separated from the widget that calls it.
- `dashboard_page.dart` has the most structured local wrapper: `_copyText`, `_downloadJson`, `_downloadText`, `_shareText`, `_openMailDraft` are all named, typed, and call `_setReceipt()` for feedback. This is the closest thing to a local coordinator pattern.
- `const JsonEncoder.withIndent('  ')` is used correctly as a compile-time constant in most locations, so there is no runtime allocation cost — but the textual repetition is still a maintenance hazard.

---

## Findings

### P1 — Clipboard JSON idiom duplicated across 9 files

- **Action:** AUTO
- **Finding:** The following three-step sequence is repeated verbatim or near-verbatim in every file that copies JSON to the clipboard:
  ```dart
  final encoded = const JsonEncoder.withIndent('  ').convert(payload);
  Clipboard.setData(ClipboardData(text: encoded));
  logUiAction('scope.action', context: {...});
  ```
- **Why it matters:** Any change to indentation, encoding, or the log call requires touching all 9 files. When one site swaps to `await`, another stays fire-and-forget. There are already two naming variants for the encoded variable (`payloadJson` vs `pretty` vs `encoded`) — these indicate divergence over time.
- **Evidence:**
  - `lib/ui/events_review_page.dart:5829–5832` (`_exportEventData`)
  - `lib/ui/events_review_page.dart:5841–5844` (`_copyActivityCaseFileJson`)
  - `lib/ui/events_review_page.dart:5853–5856` (`_copyReadinessCaseFileJson`)
  - `lib/ui/events_review_page.dart:5869–5872` (`_copyShadowCaseFileJson`)
  - `lib/ui/events_review_page.dart:5881–5884` (`_copySyntheticCaseFileJson`)
  - `lib/ui/events_review_page.dart:6198–6201` (`_copyTomorrowCaseFileJson`)
  - `lib/ui/client_intelligence_reports_page.dart:9542–9543` (`_copyAllReceipts`)
  - `lib/ui/client_intelligence_reports_page.dart:9552–9553` (`_copyPartnerScopeJson`)
  - `lib/ui/client_intelligence_reports_page.dart:9589–9590` (partner drill-in JSON)
  - `lib/ui/client_intelligence_reports_page.dart:9626–9627` (`_copyPartnerComparisonJson`)
  - `lib/ui/client_intelligence_reports_page.dart:9655–9656` (`_copyReceiptPolicyHistoryJson`)
  - `lib/ui/client_intelligence_reports_page.dart:9684–9685` (`_copyPartnerShiftJson`)
  - `lib/ui/client_intelligence_reports_page.dart:9723–9724` (`_copySiteActivityTruthJson`)
  - `lib/ui/client_intelligence_reports_page.dart:10894–10895`, `10936–10937` (receipt-level copies)
  - `lib/ui/governance_page.dart:4187–4189`, `4196–4198` (morning JSON/CSV)
  - `lib/ui/governance_page.dart:10479–10481` (inline shadow dossier)
  - `lib/ui/ai_queue_page.dart:4605–4609` (inline shadow dossier)
  - `lib/ui/live_operations_page.dart:14067–14070` (shadow MO dossier)
  - `lib/ui/sovereign_ledger_page.dart:2841–2843`, `2855–2857` (bulk + single entry export)
- **Suggested follow-up:** Codex can validate the full count and confirm all call sites are pure fire-and-forget before centralising.

---

### P1 — CSV copy idiom duplicated 6 times in `events_review_page.dart` alone

- **Action:** AUTO
- **Finding:** Six separate `_copy*CaseFileCsv` methods follow the exact same shape: build a `List<String> lines`, then `Clipboard.setData(ClipboardData(text: lines.join('\n')))`, then `logUiAction(...)`, then `_showActionMessage(...)`. The only difference is the payload content.
- **Why it matters:** The `lines.join('\n')` termination, the `logUiAction` call structure, and the `_showActionMessage` call are all separately maintained in each method. When the CSV format convention changes (e.g. `\r\n` for Windows compatibility, or a header change) all 6 must be updated.
- **Evidence:**
  - `lib/ui/events_review_page.dart:5895–5950` (`_copyActivityCaseFileCsv`)
  - `lib/ui/events_review_page.dart:5952–5991` (`_copyReadinessCaseFileCsv`)
  - `lib/ui/events_review_page.dart:5993–6080` (`_copyShadowCaseFileCsv`)
  - `lib/ui/events_review_page.dart:6082–6194` (`_copySyntheticCaseFileCsv`)
  - `lib/ui/events_review_page.dart:6212–6295` (`_copyTomorrowCaseFileCsv`)
  - `lib/ui/client_intelligence_reports_page.dart:9565–9577`, `9639–9650`, `9668–9679`, `9698–9711`, `9739–9757` (5 CSV methods)
- **Suggested follow-up:** Codex should confirm the `lines.join('\n')` separator is consistent across all call sites (it is in events_review; verify governance and client_intelligence_reports use the same convention).

---

### P2 — `DispatchSnapshotFileService` declared twice as `static const`

- **Action:** AUTO
- **Finding:** Both `_DashboardAdvancedExportPanelState` and `_GovernancePageState` declare `static const _snapshotFiles = DispatchSnapshotFileService()`. This is a stateless service, so there is no reason it cannot be a shared singleton or accessed via a coordinator.
- **Why it matters:** Any future constructor argument (e.g. a scoping prefix, a feature flag) would require two synchronised edits. `events_review_page.dart` and `client_intelligence_reports_page.dart` do not have file download at all — they are clipboard-only — which means there is a silent capability gap: users in those pages cannot download exports as files even when `DispatchSnapshotFileService.supported` is `true`.
- **Evidence:**
  - `lib/ui/dashboard_page.dart:4604` — `static const _snapshotFiles = DispatchSnapshotFileService()`
  - `lib/ui/governance_page.dart:862` — `static const _snapshotFiles = DispatchSnapshotFileService()`
  - `lib/ui/events_review_page.dart` — no `_snapshotFiles` declaration found (clipboard-only)
  - `lib/ui/client_intelligence_reports_page.dart` — no `_snapshotFiles` declaration found (clipboard-only)
- **Suggested follow-up:** Codex to confirm whether the download gap in `events_review_page` and `client_intelligence_reports_page` is intentional product scope or a capability regression.

---

### P2 — `TextShareService` and `EmailBridgeService` declared twice

- **Action:** AUTO
- **Finding:** Both `_DashboardAdvancedExportPanelState` and `_GovernancePageState` also declare `static const _textShare = TextShareService()` and `static const _emailBridge = EmailBridgeService()`. No other page in `lib/ui/` declares these — they are entirely absent from 7 other pages.
- **Why it matters:** Share and mail-draft are silently unavailable in all pages except `dashboard_page` and `governance_page`, despite those pages building the same kind of exportable payloads. The coordinator would make capability discovery uniform.
- **Evidence:**
  - `lib/ui/dashboard_page.dart:4605–4606`
  - `lib/ui/governance_page.dart:863–864`
- **Suggested follow-up:** No change needed until the coordinator is in place. Flag for Codex when coordinator is scoped.

---

### P2 — `guard_mobile_shell_page.dart` has 10+ inline `Clipboard.setData` calls with no shared wrapper

- **Action:** REVIEW
- **Finding:** `guard_mobile_shell_page.dart` contains at least 10 direct `Clipboard.setData(ClipboardData(...))` calls scattered across unrelated UI callbacks (lines ~4568, 4599, 4694, 4808, 5029, 5055, 5072, 5112, 5538, 5594, 6801). Each uses `_withSubmit(...)` or bare `await` inconsistently. There is no local clipboard wrapper like `dashboard_page.dart` has.
- **Why it matters:** `guard_mobile_shell_page.dart` is the guard-facing mobile shell — it is the most latency-sensitive surface. Inline `Clipboard.setData` calls without any error handling or feedback normalisation means clipboard failures are silently swallowed.
- **Evidence:** `lib/ui/guard_mobile_shell_page.dart` lines 4568, 4599, 4694, 4808, 5029, 5055, 5072, 5112, 5538, 5594, 6801
- **Suggested follow-up:** Codex should check whether `_withSubmit` wraps are consistently applied to all guard clipboard calls or only to some.

---

### P3 — `live_operations_page.dart` has inline `JsonEncoder.withIndent` without `logUiAction`

- **Action:** REVIEW
- **Finding:** `live_operations_page.dart:14067–14070` uses the JSON clipboard idiom but does not call `logUiAction`. The other three clipboard calls in this file (URI copies, lines 1477, 1516, 1536) also skip `logUiAction`. This is inconsistent with the rest of the codebase where clipboard actions are audited.
- **Why it matters:** Shadow MO dossier export at line 14070 is a high-value operational action. The missing log call means there is no audit trail for when operators copy this payload — a potential gap in ops accountability.
- **Evidence:**
  - `lib/ui/live_operations_page.dart:1477`, `1516`, `1536` — URI copy, no log
  - `lib/ui/live_operations_page.dart:14067–14070` — shadow MO dossier copy, no log
- **Suggested follow-up:** Codex to confirm whether `logUiAction` is intentionally omitted in `live_operations_page` (different log pathway) or accidentally missing.

---

### P3 — `events_review_page.dart` `_exportEventData` is fire-and-forget (unawaited)

- **Action:** REVIEW
- **Finding:** `_exportEventData` at line 5828 calls `Clipboard.setData(...)` without `await`. All other clipboard methods in the same file that are called from `onTap:` also skip `await`. This is inconsistent with `dashboard_page.dart` and `governance_page.dart` where clipboard writes are always `await`-ed inside `async` callbacks.
- **Why it matters:** On most platforms, `Clipboard.setData` is effectively synchronous, but the API contract is async. Fire-and-forget means any platform-level clipboard error is swallowed silently, and any code that follows assumes the clipboard was updated when it may not have been.
- **Evidence:** `lib/ui/events_review_page.dart:5832`, `5844`, `5856`, `5872`, `5884`, `5944`, `5981`, `6074`, `6186`, `6201`, `6287`
- **Suggested follow-up:** Codex to check whether these `onTap` callbacks are non-async (which would explain the missing `await`) and whether converting them to `async` is safe in the widget tree context.

---

## Duplication Summary

| Pattern | Files | Count |
|---|---|---|
| `JsonEncoder.withIndent('  ').convert(...) + Clipboard.setData` | `events_review_page`, `client_intelligence_reports_page`, `governance_page`, `ai_queue_page`, `live_operations_page`, `sovereign_ledger_page` | ~20 call sites |
| `lines.join('\n') + Clipboard.setData` (CSV) | `events_review_page`, `client_intelligence_reports_page` | ~11 call sites |
| `static const _snapshotFiles = DispatchSnapshotFileService()` | `dashboard_page`, `governance_page` | 2 |
| `static const _textShare = TextShareService()` | `dashboard_page`, `governance_page` | 2 |
| `static const _emailBridge = EmailBridgeService()` | `dashboard_page`, `governance_page` | 2 |
| Bare `Clipboard.setData` without log or wrapper | `guard_mobile_shell_page`, `live_operations_page`, `events_page` | ~15 call sites |

**Centralization candidate:** `lib/application/export_coordinator.dart` (new file — see design below).

---

## Proposed `ExportCoordinator` Design

### Placement

`lib/application/export_coordinator.dart` — application layer service, consistent with `DispatchSnapshotFileService`, `TextShareService`, `EmailBridgeService` which already live in `lib/application/`.

### Responsibility boundary

`ExportCoordinator` owns:
- Pretty-printing JSON with `JsonEncoder.withIndent('  ')`
- Writing to clipboard
- Triggering file downloads via `DispatchSnapshotFileService`
- Triggering text share via `TextShareService`
- Opening mail drafts via `EmailBridgeService`
- Calling `logUiAction` consistently

`ExportCoordinator` does NOT own:
- Feedback display (snack, receipt, action message) — this stays in each page's state, provided via callback
- Payload construction — each page builds its own payloads, passes result to coordinator

### Interface sketch (for Codex reference — not a patch)

```
ExportCoordinator {
  // Core clipboard operations
  Future<void> copyJson(Object? payload, {required String logAction, Map<String,Object?>? logContext})
  Future<void> copyCsv(List<String> lines, {required String logAction, Map<String,Object?>? logContext})
  Future<void> copyText(String text, {String? logAction, Map<String,Object?>? logContext})

  // File download operations
  bool get downloadSupported  // delegates to DispatchSnapshotFileService.supported
  Future<void> downloadJson({required String filename, required String contents, String? logAction})
  Future<void> downloadText({required String filename, required String contents, String? logAction})

  // Share / mail
  bool get shareSupported     // delegates to TextShareService.supported
  bool get mailSupported      // delegates to EmailBridgeService.supported
  Future<bool> shareText({required String title, required String text, String? logAction})
  Future<bool> openMailDraft({required String subject, required String body, String? logAction})
}
```

### Feedback architecture — DECISION required

Three options:

**Option A — Coordinator returns void, caller handles feedback**
Each page calls `await coordinator.copyJson(...)` then calls its own `_showSnack(...)` / `_showActionMessage(...)` / `_setReceipt(...)`. Minimal coordinator surface. No coupling to UI. Callers must not forget to add feedback.

**Option B — Coordinator accepts an optional `onComplete` callback**
```dart
await coordinator.copyJson(payload, logAction: '...', onComplete: () => _showSnack('Copied'));
```
Keeps feedback local but guarantees it is called. Adds a callback parameter to every method.

**Option C — Coordinator owns a stream/notifier for feedback**
Pages subscribe to `coordinator.feedbackStream` and map events to their own display. More complex but uniform. Risk: over-engineering for a utility class.

**Recommendation:** Option A is the safest initial cut. It matches how `DispatchSnapshotFileService` already works in `dashboard_page.dart` — the caller always adds its own receipt after the await. Option B is acceptable if Codex confirms feedback was being silently dropped in some places (which the unawaited calls in `events_review_page` suggest).

---

## Coverage Gaps

- No unit tests exist for any clipboard/export logic because it currently lives inside widget `State` classes. Extracting to `ExportCoordinator` would make the indentation logic, CSV join, and `logUiAction` call site testable in isolation.
- No test covers the `DispatchSnapshotFileService.supported == false` guard path in `events_review_page` (which has no download support at all — the guard never fires).
- No test covers the `TextShareService.supported == false` fallback path in `governance_page._shareText` equivalent.

---

## Performance / Stability Notes

- `const JsonEncoder.withIndent('  ')` is correct constant usage — no heap allocation per call. Not a performance issue.
- CSV construction uses `List<String>` + `join` which is fine for the payload sizes involved (tens of lines).
- No concerns about clipboard call volume — these are all user-initiated actions.

---

## Recommended Fix Order

1. **(AUTO)** Extract `copyJson` and `copyCsv` into `lib/application/export_coordinator.dart`. Start with these two — they cover ~31 of the ~40 call sites and have zero UI dependency. Wire `logUiAction` inside the coordinator. Confirm feedback is handled by callers post-await.

2. **(AUTO)** Add `downloadJson` and `downloadText` to the coordinator, consolidating the two `static const _snapshotFiles` declarations in `dashboard_page` and `governance_page`. After this, `events_review_page` and `client_intelligence_reports_page` gain download capability for free by injecting the coordinator.

3. **(REVIEW)** Add `shareText` and `openMailDraft` to the coordinator. These require confirming whether the `TextShareService` / `EmailBridgeService` fallback-to-clipboard behaviour belongs in the coordinator or should stay in page state (it encodes UI-level UX decision logic).

4. **(REVIEW)** Audit `guard_mobile_shell_page.dart` clipboard calls individually. The `_withSubmit` wrapper used in some calls (but not all) suggests there may be intentional behaviour differences that make bulk migration risky without per-call review.

5. **(REVIEW)** Add `logUiAction` to the four unlogged clipboard calls in `live_operations_page.dart`. Confirm with Zaks whether live ops uses a different audit path.

6. **(DECISION)** Decide on the feedback callback pattern (Option A vs B above) before Codex begins migration of the high-volume call sites in `events_review_page` and `client_intelligence_reports_page`.
