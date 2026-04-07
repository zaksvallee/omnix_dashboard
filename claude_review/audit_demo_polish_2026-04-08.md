# Audit: Demo Polish — Live Demo Embarrassment Scan

- Date: 2026-04-08
- Auditor: Claude Code
- Scope: Full `lib/ui/` scan for empty states, no-op buttons, stale hardcoded demo text, and "not wired" messages visible during a live demo
- Read-only: yes

---

## Executive Summary

Seven issues that would embarrass in a live demo. One is a button that visibly activates but fires no action. Two pages display permanently hardcoded fictional content as if it were real operational data. Four strings use internal dev language ("not wired in this session", "being productized") that could surface to operators or clients.

The rest of the platform is reasonably demo-safe — empty-state handling, loading guards, and null-callback disabling patterns are consistently applied. Most `SizedBox.shrink()` returns are conditional and intentional.

---

## What Looks Good

- `isSeededPlaceholder` guard on dispatch board — clicking the placeholder shows a contextual snack, not a crash.
- Every `onPressed: x == null ? null : ...` guard is consistently applied across sovereign ledger, AI queue, events, guards pages — buttons that can't function are visually disabled.
- Empty-state recovery cards (Events, AI Queue, Governance, Client Reports) all include actionable escape routes.
- Loading spinners are all tied to concrete `_isLoading` / `_isGenerating` / `_isRefreshing` booleans; no permanent spinners found.
- `usePlaceholderDataWhenEmpty: false` is correctly set for the controller mode `ClientsPage` build, so placeholder client data is suppressed in live controller sessions.

---

## Findings

### P1 — Button fires no action

**Action: REVIEW**

The "JUMP TO QUEUE" button in the Admin System tab → AI Draft Queue panel has `onPressed: () {}` when pending drafts exist.

`AdministrationPage` has no `onOpenAiQueue` (or equivalent) callback field. There is no route out from this button. When a demo run has pending Telegram AI drafts, the operator can see the badge count and the active button, but clicking it does absolutely nothing.

- Evidence: `lib/ui/admin_page.dart:5218`
- Failure mode: operator clicks "JUMP TO QUEUE", nothing happens, no feedback, no navigation. The button is not disabled — it just fires `() {}`.
- Suggested follow-up: Codex to confirm whether an `onOpenAiQueue` callback field exists elsewhere or needs to be added to `AdministrationPage`. The nearest route target would be `OnyxRoute.aiQueue`.

---

### P2 — VIP Protection page shows permanently hardcoded fictional VIP details

**Action: DECISION**

`VipProtectionPage.defaultScheduledDetails` contains two hardcoded fictional bookings:
- "CEO Airport Escort — Sandton to OR Tambo International"
- "Board Meeting Security — Hyde Park Complex — Executive Suite"

`_buildVipRoute()` in `onyx_route_operations_builders.dart` does NOT pass `scheduledDetails`, so `VipProtectionPage` always receives its own `defaultScheduledDetails`. Because `hasScheduledDetails` is therefore always `true`, the page permanently renders these two fictional items. The "Create Detail" button is never shown (it only appears when `!hasScheduledDetails`). There is no live data path, no empty state, and no way for an operator to clear or replace these entries in a real session.

- Evidence:
  - `lib/ui/vip_protection_page.dart:79–130` (hardcoded defaults)
  - `lib/ui/onyx_route_operations_builders.dart:4–11` (no `scheduledDetails` passed)
  - `lib/ui/vip_protection_page.dart:134` (`hasScheduledDetails` always true, "Create Detail" always hidden)
- Failure mode: client navigates to VIP Protection and sees "CEO Airport Escort - Sandton to OR Tambo International" as a live operation. This looks real, is not, and cannot be dismissed.
- Suggested follow-up: Decide whether to (a) wire real VIP data from the store into `_buildVipRoute()`, or (b) pass `scheduledDetails: const []` so the empty state shows and the "Create Detail" button becomes visible.

---

### P3 — Risk Intelligence feed items are permanently stale hardcoded demo data

**Action: DECISION**

`RiskIntelligencePage.defaultRecentItems` (used as the fallback when no `IntelligenceReceived` events exist) contains three hardcoded fake items:
- "Protest planned near Rosebank Metro Station tomorrow at 10:00" (source: TWITTER, time: 23:15)
- "Load shedding Stage 3 announced — affects all monitored areas" (source: NEWS24, time: 22:45)
- "Armed robbery reported in Midrand — 5km from Waterfall Business Park" (source: POLICE SCANNER, time: 21:30)

These timestamps never update and the content never changes. In any session without real intelligence events, these render on the screen as if they are live operator intelligence.

Additionally, `_buildRiskIntelAreas()` always starts from `RiskIntelligencePage.defaultAreas` (Sandton, Hyde Park, Waterfall, Rosebank) regardless of which client is active. These area titles are hardwired South African suburbs that may have nothing to do with the actual client's operational footprint.

- Evidence:
  - `lib/ui/risk_intelligence_page.dart:143–175` (hardcoded items)
  - `lib/ui/onyx_route_operations_builders.dart:38–41` (fallback to default items)
  - `lib/ui/onyx_route_operations_builders.dart:84–91` (always starts from defaultAreas)
- Failure mode: client or prospect sees stale Sandton/Midrand/loadshedding content on their Risk Intelligence page. Time labels are frozen (23:15, 22:45, 21:30).
- Suggested follow-up: Product decision needed on what to show when intel events are empty — either a proper empty state ("No intel signals in the review window"), or a generic "last known" posture without specific fake times and locations.

---

### P4 — "Add Manual Intel" dialog exposes internal product roadmap language

**Action: AUTO**

When `onAddManualIntel` is null (i.e., the widget is rendered outside the route builder context), the fallback dialog shown to the operator says:

> "Use this as the intake brief while the full manual-intel workflow is being productized."

In the current production wiring `onAddManualIntel` IS set (it opens the admin system tab), so this dialog does not appear in a normal live session. However, the dialog text still exposes internal development status ("being productized") if the fallback path is ever hit — for example, during a test build, widget preview, or if the callback is inadvertently dropped.

- Evidence: `lib/ui/risk_intelligence_page.dart:207–211`
- Failure mode: operator sees dev-phase language in a modal dialog.
- Suggested follow-up: Codex may replace the "Operator Note" value from "Use this as the intake brief while the full manual-intel workflow is being productized." to "Log the area, source, confidence level, and affected client lane. Escalate via Events or Dispatch once the source is verified."

---

### P5 — Agent emits internal wiring-failure messages visible to operators

**Action: REVIEW**

Three agent tool-message bodies expose internal wiring state to the operator in the AI agent chat thread:

1. `'This action is not wired in the current session yet. The page shell is ready, but the route callback is missing.'`
   - `lib/ui/onyx_agent_page.dart:7104` — fires when `_openTrackRoute()` returns false and no other case matches in `_runNavigationAction()`.

2. `'Camera change approval is not wired in this session. Keep the packet local and use CCTV to verify the target manually.'`
   - `lib/ui/onyx_agent_page.dart:7207` — fires when `_cameraChangeAvailable` is false.

3. `'Rollback logging is not wired in this session. Record the rollback manually in the incident notes and recheck CCTV.'`
   - `lib/ui/onyx_agent_page.dart:7270` — fires when the rollback callback is unavailable.

In a live demo the operator types a natural-language command that routes into one of these, and the agent responds with dev-phase language like "the page shell is ready, but the route callback is missing". This is operator-visible in the chat thread.

- Suggested follow-up for Codex to validate: Confirm which of these three paths can actually be triggered in the current demo configuration. Messages 2 and 3 fire only when optional hardware/service integrations are absent — lower risk. Message 1 fires from the navigation action fallback and is higher risk if the track route is missing.

---

### P6 — Guard contact sheet and client comms surface "not connected in this session" strings

**Action: REVIEW**

Two strings in the guard contact sheet modal use session-internal language:

- `'Client Comms routing is not connected in this session yet, so this handoff stays view-only for now.'`
  — `lib/ui/guards_page.dart:3837`

- `'VoIP staging is not connected in this session yet, so this handoff stays view-only for now.'`
  — `lib/ui/guards_page.dart:3840`

These appear as a readiness note in the guard contact sheet when `clientLaneAvailable` or `voipAvailable` is false. A client sitting beside the operator during demo could read this on screen.

Additionally, `clients_page.dart:2307` shows `'Room switching is view-only in this session.'` as a small text label beneath the room selector when `roomRoutingAvailable` is false.

- Evidence: `lib/ui/guards_page.dart:3834–3840`, `lib/ui/clients_page.dart:2307`
- Suggested follow-up: Codex to assess whether `clientLaneAvailable` / `voipAvailable` / `roomRoutingAvailable` are typically true in a live demo session. If so, these are low risk. If they default to false in controller mode, the strings need rephrasing to remove "in this session" phrasing — e.g., "Client Comms offline" or "VoIP not available".

---

### P7 — Admin System tab `_activeEntityWorkspace()` returns blank for `system` case

**Action: AUTO** (suspicion, verify first)

`_activeEntityWorkspace()` at `lib/ui/admin_page.dart:5179–5185` returns `const SizedBox.shrink()` when `_activeTab == AdministrationPageTab.system`. This method is called at line 4939 as part of the desktop entity management layout.

The `system` tab has its own body via `_systemExperience()`, so the intent is that `_activeEntityWorkspace()` is suppressed for the system tab. However, if the desktop layout renders both `_activeEntityWorkspace()` and the system experience side by side, the shrink returns a blank workspace panel next to the system controls, which could look like a blank pane.

- Evidence: `lib/ui/admin_page.dart:5184`, call site at `lib/ui/admin_page.dart:4939`
- Suggested follow-up: Codex to check how `_activeEntityWorkspace()` is positioned in the desktop layout relative to the system tab experience — confirm whether the blank space is visible or suppressed by the surrounding layout constraint.

---

## Duplication

- The fallback pattern (`onCallback != null ? onCallback!.call() : _showFallbackDialog(context)`) is duplicated at least 6 times across `risk_intelligence_page.dart`, `vip_protection_page.dart`, and `onyx_agent_page.dart`. Not a demo risk, but worth centralizing if these widgets get used in more standalone contexts.

---

## Coverage Gaps

- No test covers the "JUMP TO QUEUE" button path in admin_page to verify it navigates anywhere — would catch the `() {}` no-op immediately.
- No test verifies that `VipProtectionPage` shows an empty state when `scheduledDetails` is empty (the `hasScheduledDetails` branch hiding the create button is never exercised with an empty list in the current test suite).
- No test asserts that `RiskIntelligencePage.defaultRecentItems` is not rendered in controller sessions that have a real client scope — the fallback is silently active.

---

## Performance / Stability Notes

- None specific to demo polish scope.

---

## Recommended Fix Order

1. **P1 — "JUMP TO QUEUE" no-op button** (`admin_page.dart:5218`): REVIEW first — an `onOpenAiQueue` callback needs to be added to `AdministrationPage` or the button should be removed/disabled until wired. This is the single highest-risk visible failure during a live admin demo.

2. **P2 — VIP page hardcoded fictional details** (`vip_protection_page.dart:79–130`): DECISION required — either wire real data or pass `scheduledDetails: const []` to expose the empty state path.

3. **P3 — Risk Intelligence stale hardcoded feed items** (`risk_intelligence_page.dart:143–175`): DECISION required — replace fake items with a proper empty state, or ensure sessions always seed at least one real `IntelligenceReceived` event.

4. **P4 — "being productized" dialog text** (`risk_intelligence_page.dart:210`): AUTO — safe string replacement, no behaviour change.

5. **P5 — Agent "not wired" messages** (`onyx_agent_page.dart:7104, 7207, 7270`): REVIEW — validate which paths are reachable in demo config first, then rephrase to operator-facing language.

6. **P6 — "not connected in this session" guard contact strings** (`guards_page.dart:3837, 3840`, `clients_page.dart:2307`): REVIEW — confirm availability defaults in demo mode before deciding whether to rephrase.

7. **P7 — Admin system tab blank workspace pane** (`admin_page.dart:5184`): AUTO verification — Codex checks layout context; if blank pane is visible, replace `SizedBox.shrink()` with a stub or hide the workspace pane entirely for the system tab.
