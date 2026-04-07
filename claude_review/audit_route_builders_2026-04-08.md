# Audit: Route Builders — Data Injection Survey

- Date: 2026-04-08
- Auditor: Claude Code
- Scope: `lib/ui/onyx_route_builders.dart`, `onyx_route_command_center_builders.dart`, `onyx_route_evidence_builders.dart`, `onyx_route_governance_builders.dart`, `onyx_route_operations_builders.dart`, `onyx_route_system_builders.dart`
- Read-only: yes

---

## Executive Summary

Six route-builder files wire `_OnyxAppState` state into 15 pages. Eleven pages receive genuine runtime data. Two pages — VIP Protection and Risk Intelligence — expose hardcoded demo defaults in production paths. One page — Tactical — renders an empty map until an async Supabase load completes, and stays empty permanently when `supabaseReady = false`. The guard identity (`GUARD-001`) is hardcoded app-wide, which is systemic rather than isolated to the route builders. No page produces a blank screen from a missing injection, but three pages can silently show fake content instead of real operational data.

---

## What Looks Good

- **Dashboard, Dispatches, Agent, AI Queue, Admin** — richly injected with events, scope IDs, comms snapshots, telemetry labels, audit receipts, and service constructors. No visible data gaps.
- **Ledger, Reports, Governance, Events** — all receive event lists, scope parameters, and the full set of return receipts. Governance defers its compliance load to a lazy Future callback rather than blocking the widget build — correct pattern.
- **Guards (controller mode), Clients (both modes)** — controller-mode guards route passes `_guardSyncRepositoryFuture` and the full evidence receipt chain. Non-controller `_buildClientPage` has equally thorough injection of comms, push-sync state, Telegram health, and learned style examples.
- **Sites** — passes events and the correct set of audit callbacks. Clean.
- **Scope resolution pattern** — all multi-route pages (Dashboard, Dispatches, Tactical, Clients, Ledger) use the consistent `routeXxx.isNotEmpty ? routeXxx : _selectedClient` fallback, which prevents empty-scope pages from being shown to users.

---

## Findings

### P1 — VipProtectionPage always renders hardcoded demo data

- **Action: REVIEW**
- `_buildVipRoute` never passes the `scheduledDetails` parameter to `VipProtectionPage`.
- The constructor default is `VipProtectionPage.defaultScheduledDetails`, which contains two hardcoded fake VIP operations: "CEO Airport Escort — Sandton to OR Tambo" and "Board Meeting Security — Hyde Park Complex".
- No database query, event scan, or real schedule source is wired into this route. The page is a static demo template in all runtime modes.
- **Why it matters:** A user viewing the VIP tab in a live deployment will always see the demo items regardless of actual configured operations. There is no mechanism for the hardcoded items to be replaced until a real schedule source is injected.
- **Evidence:** `lib/ui/onyx_route_operations_builders.dart:4–11` — no `scheduledDetails` argument passed; `lib/ui/vip_protection_page.dart:73` — `scheduledDetails = defaultScheduledDetails`; `lib/ui/vip_protection_page.dart:79–104` — hardcoded CEO/board-meeting entries.
- **Suggested follow-up for Codex:** Confirm whether a real VIP schedule source exists anywhere in the domain layer. If yes, identify where to load it and how to pass it into this builder. If no source exists, this is a DECISION item.

---

### P2 — RiskIntelligencePage exposes hardcoded demo defaults when intel events are absent

- **Action: REVIEW**
- `_buildIntelRoute` falls back to `RiskIntelligencePage.defaultAreas` when no `IntelligenceReceived` events are present. It also passes `defaultRecentItems` when `intelligenceEvents.isEmpty`.
- `defaultAreas` contains four hardcoded South African geographic names: Sandton, Hyde Park, Waterfall, Rosebank — all statically set to LOW. `defaultRecentItems` contains three fake items with provider IDs `intel-twitter-rosebank`, `intel-news24-loadshedding`, `intel-scanner-waterfall` — these are static strings with no `eventId`, no real timestamp, and a hardcoded `timeLabel`.
- Even when events are present, area matching uses `_matchesRiskIntelArea`, which runs a simple `.contains(needle)` on a concatenation of `event.headline + event.summary + event.siteId + event.zone`. Areas that do not appear literally in any of those fields will never receive live data and will remain at the hardcoded LOW level.
- **Why it matters:** On first launch, or on any deployment where no intelligence has yet been ingested, the Intel tab looks populated with real-looking signals that are entirely fabricated. An operator cannot distinguish live LOW signals from the placeholder state.
- **Evidence:** `lib/ui/onyx_route_operations_builders.dart:37–46` (defaultRecentItems fallback); `lib/ui/onyx_route_operations_builders.dart:83–91` (defaultAreas fallback); `lib/ui/risk_intelligence_page.dart:116–167` (hardcoded content); `lib/ui/onyx_route_operations_builders.dart:190–202` (_matchesRiskIntelArea substring logic).
- **Suggested follow-up for Codex:** Validate whether any real-deployment site names would match the hardcoded area titles. Consider whether an "empty state" UI (no signals yet) would be more honest than the demo defaults. If the area list should be configurable, this escalates to DECISION.

---

### P2 — TacticalPage map is permanently empty when `supabaseReady = false`

- **Action: AUTO**
- `_buildTacticalRoute` passes `guardPositions: _tacticalGuardPositions` and `siteMarkers: _tacticalSiteMarkers`, both of which are initialized to `const []` and populated asynchronously.
- `_refreshTacticalSiteMarkers` short-circuits at line 29427 when `!widget.supabaseReady`, explicitly setting `_tacticalSiteMarkers = const []` and returning without scheduling a retry.
- Similarly, the guard-positions refresh path has no retry or degradation signal when Supabase is unavailable — positions will silently remain empty.
- The TacticalPage receives no `supabaseReady` flag and no loading indicator from the route builder, so the user sees a map with no markers and no explanation.
- **Why it matters:** In offline or degraded-Supabase scenarios the tactical map is completely empty with no feedback. The user cannot tell if the map is loading, if Supabase is down, or if there are genuinely no guards deployed.
- **Evidence:** `lib/main.dart:29427–29434` (supabaseReady guard, returns empty, no retry); `lib/main.dart:1666–1668` (fields initialized to const []); `lib/ui/onyx_route_command_center_builders.dart:331–332` (injected as-is, no readiness flag).
- **Suggested follow-up for Codex:** Pass a `supabaseReady` or `positionsAvailable` flag into TacticalPage so it can distinguish "loading" from "no data". Add a scheduled retry when Supabase becomes ready rather than permanently silencing the load.

---

### P3 — `guardId: 'GUARD-001'` is hardcoded system-wide

- **Action: DECISION**
- `_buildGuardPage` passes `guardId: 'GUARD-001'` to `GuardMobileShellPage`. The same literal string appears 16 times across `lib/main.dart` — in shift IDs, media upload paths, event payloads, acknowledgement keys, and telemetry dispatch.
- This is not isolated to the route builder; the guard identity is a global constant baked into state mutators and domain operations.
- **Why it matters:** Multi-guard deployments or any scenario requiring distinct guard identities (audit trails, shift handoffs, media attribution) will produce collisions. All events, shifts, and media from any guard device will be attributed to `GUARD-001`.
- **Evidence:** `lib/main.dart:3174, 5673, 5683, 5701, 5741, 5764, 5776, 5829, 5851, 6015, 6127, 6149, 34856, 35125` — all hardcoded; `lib/ui/onyx_route_operations_builders.dart:364–379` — guardId sourced from `_buildGuardPage`.
- **Suggested follow-up:** This is a product-architecture decision. Codex should not act without Zaks approval on how guard identity should be resolved (env var, auth token, admin directory, or continued single-guard mode).

---

### P3 — Governance compliance silently empty when Supabase unavailable

- **Action: AUTO**
- `_loadGovernanceAdminDirectorySnapshot` returns `null` when `!widget.supabaseReady` (line 29427 equivalent in governance: `lib/ui/onyx_route_governance_builders.dart:137–139`).
- When the directory is null, `_buildGovernanceComplianceFeeds` is skipped and `complianceAvailable: false` is passed to the page. No degradation label or retry signal is surfaced.
- **Why it matters:** In a degraded-Supabase session, the compliance panel disappears without feedback. An operator reviewing PSIRA expiry compliance has no way to know whether the empty view means "all clear" or "data unavailable".
- **Evidence:** `lib/ui/onyx_route_governance_builders.dart:137–150` (null return on !supabaseReady); `lib/ui/onyx_route_governance_builders.dart:84–92` (null directory collapses compliance to empty list, `complianceAvailable: false`).
- **Suggested follow-up for Codex:** Confirm whether `GovernancePage` renders a distinct UI for `complianceAvailable: false`. If not, add a degradation label or consider passing a separate `complianceDataUnavailable` flag.

---

## Duplication

- **Default-fallback pattern repeated in two routes**: Both `_buildIntelRoute` and `_buildVipRoute` expose hardcoded static content as the default when no real data source is connected. The mechanism is structurally identical — constructor defaults serving as permanent fallbacks. This suggests a broader pattern issue: pages should declare an explicit empty state rather than shipping with demo data in their defaults.
- **`_governanceScopeMatches` / `_governanceOperationScopeMatches` / `_governanceMonitoringScopeMatches`**: Three near-identical scope-matching functions in `onyx_route_governance_builders.dart` (lines 383–439). All delegate to `_governanceScopeMatches` for the core logic but with different key parsing overhead. Centralisation candidate if a shared `ScopeFilter` model is introduced.

---

## Coverage Gaps

- No test verifies that `_buildVipRoute` passes a real `scheduledDetails` list when one exists. The current test surface would pass regardless of whether real data is injected.
- No test covers the `supabaseReady = false` path for `_buildTacticalRoute` (empty-markers silent state).
- No test exercises `_matchesRiskIntelArea` with area titles that do not appear in event fields — confirming that the non-matching area retains its hardcoded level rather than being cleared.
- Route-level behavior for the `OnyxAppMode.guard` / `OnyxAppMode.client` branching in `_buildGuardsRoute` and `_buildClientsRoute` is not locked with widget tests at the app shell boundary.

---

## Performance / Stability Notes

- `_buildGovernanceRoute` triggers `_loadGovernanceOperationalFeeds` as a `Future`-returning callback on every rebuild of the governance page. If the page rebuilds frequently, multiple concurrent Supabase reads could be in flight simultaneously. The callback has no debounce or in-flight guard visible in the route builder.
  - Evidence: `lib/ui/onyx_route_governance_builders.dart:61–63` — `operationalFeedsLoader: () => _loadGovernanceOperationalFeeds(events: events)`.

---

## Recommended Fix Order

1. **(P1) VipProtectionPage real-data injection** — confirm whether a real VIP schedule source exists; if yes, wire it. If no source exists, escalate to DECISION before any implementation. Risk: demo data shown in all live sessions.
2. **(P2) TacticalPage supabaseReady degradation** — add a readiness/loading flag into the TacticalPage route injection and a retry path so the map doesn't silently stay empty in degraded sessions. LOW implementation risk.
3. **(P2) RiskIntelligencePage empty-state design** — replace `defaultAreas`/`defaultRecentItems` fallback with an explicit empty state or a configurable area list. Requires product input on whether the SA area names are intentional demo scaffolding or a real configuration gap.
4. **(P3) Governance compliance degradation label** — verify GovernancePage empty-compliance rendering and add a `dataUnavailable` signal if the page currently shows nothing on null directory.
5. **(P3) Guard identity** — DECISION required from Zaks before any change. Document current scope (single-guard device) in CLAUDE.md if intentional.
