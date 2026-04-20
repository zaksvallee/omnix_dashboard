# ONYX Dashboard — Phase 1b Parity Audit (v1 Flutter ↔ v2 Next.js)

**Date:** 2026-04-20
**Scope:** UI only. v1 Flutter `lib/pages/** · lib/widgets/** · lib/theme/** · lib/routing/** · lib/app.dart · UI portions of lib/main.dart`; v2 Next.js `app/**` (excluding `app/api/**`) + `components/**` + client hooks/contexts.
**Out of scope:** everything covered by phase 1a (backend, services, data layer, Telegram logic, inference, v2 `app/api/**`).
**Rules:** evidence only; statuses in §4 are restricted to `present`, `present_stub`, `absent`, `unverified`; no recommendations, no prioritisation, no labels beyond those.

---

## 0. Access confirmation and input review

| Target | Method | Result |
|---|---|---|
| `/Users/zaks/omnix_dashboard` | local read | ok |
| `/Users/zaks/onyx_dashboard_v2` | local read | ok |
| `audit/phase_1a_backend_inventory.md` | local read | read in full — 617 lines |
| `onyx_dashboard_v2/docs/audit-2026-04-19.md` | local read | read in full — 273 lines |

**HEAD commits anchoring this pass:**

- `omnix_dashboard` `main` → `f216695f2025952d092e9e3dfcf17c7b2cbad8cd` (phase 1a appendix on top of `58fa062` phase 1a inventory on top of `1be22c3` mac-enhancement log tee)
- `onyx_dashboard_v2` `main` → `a19f9a25feb35b8cb18a97cb9a122f4634582d9e` (tagged `audit-2026-04-19`, matches the date of the input audit document)

**Structural deviations from the brief's assumed layout:**

- `lib/pages/**` — does not exist in v1. The page widgets live in `lib/ui/*_page.dart` (plus a smaller, older set in `lib/presentation/`).
- `lib/widgets/**` — does not exist. UI widgets are in `lib/ui/*.dart` (non-page files) and `lib/ui/components/`.
- `lib/theme/**` — does not exist. Theme wiring is inline inside `lib/main.dart`.
- `lib/app.dart` — does not exist; per the brief's note, treated as `absent`. The application root is `_OnyxAppState` inside `lib/main.dart`.
- `lib/routing/** `— exists as a single file, `lib/routing/onyx_router.dart` (174 LOC). The file is a `part of '../main.dart';` partial; the enum it iterates (`OnyxRoute`) is defined at `lib/domain/authority/onyx_route.dart`, and the 16 builder functions live in `lib/ui/onyx_route_*_builders.dart` (also partials of `main.dart`).
- `lib/main.dart` — 42,987 LOC. Absorbs the role of `app.dart`, the theme, the ShellRoute chrome, every route builder, and substantial business logic. §1 enumerates routes via the `OnyxRoute` enum; any per-page widgets instantiated from lib/ui are named against their file path.

---

## 1. v1 Flutter UI page inventory

### 1.1 Canonical route table

Sourced from `OnyxRoute` (at `lib/domain/authority/onyx_route.dart:39`) iterated by the `GoRouter` at `lib/routing/onyx_router.dart:50–66`, plus the pre-enum root `/` wired at `lib/routing/onyx_router.dart:42–49`. Purpose strings are the `autopilotNarration` field on each enum variant (code-authoritative).

#### COMMAND CENTER (`OnyxRouteSection.commandCenter`)

| Route | Enum variant | Page widget | Page file | LOC | Last modified |
|---|---|---|---|---|---|
| `/` | (zaraHome — not enum-backed, wired as a top-level `GoRoute` outside the ShellRoute at `lib/routing/onyx_router.dart:42`) | `ZaraAmbientPage` | `lib/ui/zara_ambient_page.dart` | 1096 | 2026-04-17 |
| `/dashboard` | `OnyxRoute.dashboard` — "Operational overview." | `CommandCenterPage` wrapper, which renders `LiveOperationsPage` at `lib/ui/command_center_page.dart:198` | `lib/ui/command_center_page.dart` (wrapper) + `lib/ui/live_operations_page.dart` (body) | 269 (wrapper) / 21176 (body) | 2026-04-17 / 2026-04-17 |
| `/agent` | `OnyxRoute.agent` — "Local-first controller brain with specialist agent handoffs." | `OnyxAgentPage` | `lib/ui/onyx_agent_page.dart` | 13549 | 2026-04-16 |
| `/ai-queue` | `OnyxRoute.aiQueue` — "AI-powered surveillance and alert review." | `AIQueuePage` | `lib/ui/ai_queue_page.dart` | 6812 | 2026-04-17 |
| `/tactical` | `OnyxRoute.tactical` (nav label "Track") — "Verify units, geofence, and site posture." | `TacticalPage` | `lib/ui/tactical_page.dart` | 9134 | 2026-04-17 |
| `/alarms` | `OnyxRoute.alarms` — "Monitor active alarms and dispatch armed response." | `AlarmsPage` | `lib/ui/alarms_page.dart` | 1530 | 2026-04-17 |
| `/dispatches` | `OnyxRoute.dispatches` — "Execute with focused dispatch context." | `DispatchPage` | `lib/ui/dispatch_page.dart` | 9855 | 2026-04-17 |

Route builders: `lib/ui/onyx_route_command_center_builders.dart` (`_buildZaraHomeRoute`, `_buildDashboardRoute`, `_buildAgentRoute`, `_buildAiQueueRoute`, `_buildTacticalRoute`, `_buildAlarmsRoute`, `_buildDispatchesRoute`).

#### OPERATIONS (`OnyxRouteSection.operations`)

| Route | Enum variant | Page widget | Page file | LOC | Last modified |
|---|---|---|---|---|---|
| `/vip` | `OnyxRoute.vip` — "Quiet convoy posture and upcoming VIP details." | `VipProtectionPage` | `lib/ui/vip_protection_page.dart` | 1047 | 2026-04-16 |
| `/intel` | `OnyxRoute.intel` — "Threat posture and intelligence watch." | `RiskIntelligencePage` | `lib/ui/risk_intelligence_page.dart` | 1342 | 2026-04-16 |
| `/clients` | `OnyxRoute.clients` (nav label "Comms") — "Client-facing confidence and Client Comms desk." | `ClientsPage` (primary); `ClientAppPage` (ternary alternate at `lib/ui/onyx_route_operations_builders.dart:313`) | `lib/ui/clients_page.dart` (primary) + `lib/ui/client_app_page.dart` (alternate) | 4598 / 10975 | 2026-04-17 / 2026-04-15 |
| `/sites` | `OnyxRoute.sites` — "Deployment footprint and zone definitions." | `SitesPage` | `lib/ui/sites_page.dart` | 1274 | 2026-04-15 |
| `/guards-workforce` | `OnyxRoute.guards` (nav label "Guards") — "Operational readiness intelligence for the workforce layer." | `GuardsWorkforcePage` (primary); `GuardsPage` (ternary alternate at `lib/ui/onyx_route_operations_builders.dart:362`) | `lib/ui/guards_workforce_page.dart` (primary) + `lib/ui/guards_page.dart` (alternate) | 3555 / 2811 | 2026-04-16 / 2026-04-16 |
| `/events` | `OnyxRoute.events` — "Replay immutable incident timeline." | `EventsReviewPage` | `lib/ui/events_review_page.dart` | 7307 | 2026-04-17 |

Route builders: `lib/ui/onyx_route_operations_builders.dart` (`_buildVipRoute`, `_buildIntelRoute`, `_buildClientsRoute`, `_buildSitesRoute`, `_buildGuardsRoute`, `_buildEventsRoute`).

#### GOVERNANCE (`OnyxRouteSection.governance`)

| Route | Enum variant | Page widget | Page file | LOC | Last modified |
|---|---|---|---|---|---|
| `/governance` | `OnyxRoute.governance` — "Show compliance and readiness controls." | `GovernancePage` | `lib/ui/governance_page.dart` | 14813 | 2026-04-17 |

Route builder: `lib/ui/onyx_route_governance_builders.dart` (`_buildGovernanceRoute`).

#### EVIDENCE (`OnyxRouteSection.evidence`)

| Route | Enum variant | Page widget | Page file | LOC | Last modified |
|---|---|---|---|---|---|
| `/ledger` | `OnyxRoute.ledger` (nav label "OB Log") — "Review clean operational records and linked continuity." | `SovereignLedgerPage` | `lib/ui/sovereign_ledger_page.dart` | 3996 | 2026-04-17 |
| `/reports` | `OnyxRoute.reports` — "Review export proof and generated reports." | `ClientIntelligenceReportsPage` | `lib/ui/client_intelligence_reports_page.dart` | 12384 | 2026-04-17 |

Route builders: `lib/ui/onyx_route_evidence_builders.dart` (`_buildLedgerRoute`, `_buildReportsRoute`).

#### SYSTEM (`OnyxRouteSection.system`)

| Route | Enum variant | Page widget | Page file | LOC | Last modified |
|---|---|---|---|---|---|
| `/admin` | `OnyxRoute.admin` — "Manage runtime controls and system settings." | `AdministrationPage` | `lib/ui/admin_page.dart` | 47091 | 2026-04-17 |

Route builder: `lib/ui/onyx_route_system_builders.dart` (`_buildAdminRoute`).

**Total go_router-registered pages:** 17 (root `/` + 16 `OnyxRoute` variants).

### 1.2 Non-router-mounted pages (referenced elsewhere in `lib/main.dart` or `lib/ui/`)

These page widgets exist and are mounted via mechanisms other than GoRouter — either at pre-router bootstrap, or via `Navigator.push(...)` / a separate shell.

| Page widget | File | LOC | Last modified | How mounted |
|---|---|---|---|---|
| `ControllerLoginPage` | `lib/ui/controller_login_page.dart` | 473 | 2026-04-07 | `home: ControllerLoginPage(...)` at `lib/main.dart:34521` — pre-router login gate before `MaterialApp.router` is returned |
| `GuardMobileShellPage` | `lib/ui/guard_mobile_shell_page.dart` | 6851 | 2026-04-07 | `return GuardMobileShellPage(...)` at `lib/main.dart:40780` — alternate app shell selected at build time for guard-side experience |
| `OrganizationPage` | `lib/ui/organization_page.dart` | 758 | 2026-04-17 | Pushed via `Navigator.push(...)` through `openOrganizationPage(context)` helper (`lib/ui/organization_page.dart:29`); invoked from `lib/ui/app_shell.dart:1049` |

### 1.3 Non-mounted page files (class defined; no inbound reference from router or `main.dart`)

These files exist with `class XxxPage extends StatefulWidget` or `StatelessWidget` but are not reached by the router, the login gate, the guard shell, the organization modal, or any `lib/ui/` page imported in this pass. Status: `defined but not mounted in this build` based on the grep evidence listed.

| Page widget | File | LOC | Last modified | Evidence of non-mount |
|---|---|---|---|---|
| `DashboardPage` | `lib/ui/dashboard_page.dart` | 5464 | 2026-04-17 | grep across `lib/main.dart`, `lib/routing/`, `lib/ui/` shows no inbound reference; `/dashboard` route is served by `CommandCenterPage` → `LiveOperationsPage`, not `DashboardPage` |
| `LedgerPage` | `lib/ui/ledger_page.dart` | 2788 | 2026-04-14 | `/ledger` is served by `SovereignLedgerPage`; no inbound reference to `LedgerPage` in the router or shell |
| `SitesCommandPage` | `lib/ui/sites_command_page.dart` | 2783 | 2026-04-14 | `/sites` is served by `SitesPage`; no inbound reference to `SitesCommandPage` in the router or shell |
| `ReportsPage` (v1 — older) | `lib/presentation/reports_page.dart` | 1040 | 2026-04-08 | `/reports` is served by `ClientIntelligenceReportsPage`; this older `ReportsPage` is in the `lib/presentation/` tree and has no router binding |
| `lib/presentation/incidents_page.dart` | 7 | 2026-03-06 | 7-LOC stub; no router binding |
| `lib/presentation/operations_page.dart` | 9 | 2026-03-06 | 9-LOC stub; no router binding |
| `lib/presentation/overview_page.dart` | 7 | 2026-03-06 | 7-LOC stub; no router binding |
| `lib/presentation/incidents/manual_incident_page.dart` | 152 | 2026-04-07 | referenced via its own file scope only; not routed |
| `lib/presentation/reports/report_preview_page.dart` | 1025 | 2026-04-07 | referenced from other `lib/presentation/reports/` files but not from router; its mounting path (if any) is outside this audit's grep |

> Mount-verification method: `grep -rn "ClassName\b" lib/main.dart lib/ui/ lib/routing/ lib/presentation/` for each page. Absent hits beyond the file itself = "not mounted in this build". This is a static grep; dynamic mounting via reflection is not used in Dart for widgets, so this is sufficient evidence.

### 1.4 Files backing §2 comparison but not themselves pages

For completeness, the supporting UI-scaffolding files that appear in `lib/ui/` but do not themselves represent a route:

- `lib/ui/app_shell.dart` — 2277 LOC, 2026-04-17 — ShellRoute chrome (nav rail + header + badge bar) used by `_buildControllerShell` at `lib/main.dart:34577`.
- `lib/ui/layout_breakpoints.dart` — responsive layout helper.
- `lib/ui/events_route_source.dart` — deep-link query-param encoder for `/events` (used at `lib/routing/onyx_router.dart:133`).
- `lib/ui/onyx_camera_bridge_*.dart` (7 files) — camera-bridge sub-widgets.
- `lib/ui/components/onyx_incident_lifecycle_view.dart`, `onyx_status_banner.dart`, `onyx_system_flow_widgets.dart` — cross-page components.
- `lib/ui/client_comms_queue_board.dart` — used inside `/clients` page.

These are documented here rather than in §1.1/1.2 so §3 (page-level matrix) only counts user-facing routes.

---

## 2. v2 Next.js UI page inventory

### 2.1 Canonical route table

Sourced from `app/**/page.tsx` (Next.js App Router — every folder under `app/` that contains a `page.tsx` is a route; underscore-prefixed folders like `_components` and `_scaffold` are opted out of routing). Nav grouping is taken from the `NAV` array in `components/shell/nav.ts` (flat, no section headers). Rows here are ordered as they appear in the left rail so cross-mapping to v1's sectioned nav is explicit in §3.

All 16 routes declare `export const dynamic = "force-dynamic"` and `export const revalidate = 0` in their `page.tsx`. The `page.tsx` file per route is a thin server component that renders a client component (`*Client.tsx`) under `_components/` — the server→client boundary is consistent across all 16 routes.

| Nav order | Route | Server page | Client shell | Extra `_components/*.tsx` | Server LOC | Client LOC | Last modified |
|---:|---|---|---|---|---:|---:|---|
| 1 | `/` | `app/page.tsx` | `app/_components/ZaraClient.tsx` | — (`Zara.css` sibling) | 12 | 783 | 2026-04-19 |
| 2 | `/command` | `app/command/page.tsx` | `app/command/_components/CommandClient.tsx` | — | 33 | 551 | 2026-04-19 |
| 3 | `/alarms` | `app/alarms/page.tsx` | `app/alarms/_components/AlarmsClient.tsx` | `AlarmCard.tsx` (143), `Drawer.tsx` (199), `EvidenceBox.tsx` (64), `Lane.tsx` (54), `Waveform.tsx` (31) | 17 | 349 | 2026-04-19 |
| 4 | `/ai-queue` | `app/ai-queue/page.tsx` | `app/ai-queue/_components/AIQueueClient.tsx` | `CognitionGraph.tsx` (76) | 15 | 467 | 2026-04-19 |
| 5 | `/track` | `app/track/page.tsx` | `app/track/_components/TrackClient.tsx` | `TrackMap.tsx` (164, dynamic-import, `ssr:false`) | 15 | 445 | 2026-04-19 |
| 6 | `/intel` | `app/intel/page.tsx` | `app/intel/_components/IntelClient.tsx` | — | 15 | 450 | 2026-04-19 |
| 7 | `/vip` | `app/vip/page.tsx` | `app/vip/_components/VIPClient.tsx` | — | 15 | 794 | 2026-04-19 |
| 8 | `/governance` | `app/governance/page.tsx` | `app/governance/_components/GovernanceClient.tsx` | — | 15 | 270 | 2026-04-19 |
| 9 | `/clients` | `app/clients/page.tsx` | `app/clients/_components/ClientsClient.tsx` | — | 22 | 527 | 2026-04-19 |
| 10 | `/sites` | `app/sites/page.tsx` | `app/sites/_components/SitesClient.tsx` | `KindIcon.tsx` (56) | 16 | 520 | 2026-04-19 |
| 11 | `/guards` | `app/guards/page.tsx` | `app/guards/_components/GuardsClient.tsx` | — | 16 | 468 | 2026-04-19 |
| 12 | `/dispatches` | `app/dispatches/page.tsx` | `app/dispatches/_components/DispatchesClient.tsx` | — | 15 | 613 | 2026-04-19 |
| 13 | `/events` | `app/events/page.tsx` | `app/events/_components/EventsClient.tsx` | — | 16 | 540 | 2026-04-19 |
| 14 | `/ledger` | `app/ledger/page.tsx` | `app/ledger/_components/LedgerClient.tsx` | — | 35 | 559 | 2026-04-19 |
| 15 | `/reports` | `app/reports/page.tsx` | `app/reports/_components/ReportsClient.tsx` | — | 15 | 784 | 2026-04-19 |
| 16 | `/admin` | `app/admin/page.tsx` | `app/admin/_components/AdminClient.tsx` | — | 15 | 967 | 2026-04-19 |

**Total routes:** 16. Matches the v2 audit at `a19f9a2` (the current HEAD of `onyx_dashboard_v2` main, tagged `audit-2026-04-19`).

### 2.2 Discrepancies vs the v2 audit

HEAD of `onyx_dashboard_v2/main` is `a19f9a25feb35b8cb18a97cb9a122f4634582d9e` — the same commit the v2 audit was written against. `git log --oneline ..HEAD` on `onyx_dashboard_v2` returns empty. No pages added or removed since `a19f9a2`; the page list in the v2 audit (§Page-by-page inventory) is current.

### 2.3 Non-routed v2 files

| Path | LOC | Last modified | Role |
|---|---:|---|---|
| `app/_scaffold/page.tsx` | 74 | 2026-04-19 | underscore-prefixed folder → not a route; colour-swatch showcase for design-system visual inspection |
| `app/_components/ZaraClient.tsx` | 783 | 2026-04-19 | mounted by `app/page.tsx`; private folder opted out of routing |
| `app/_components/Zara.css` | — | 2026-04-19 | styles for ZaraClient |
| `app/layout.tsx` | 36 | — | root layout: fonts (Inter, JetBrains_Mono), `Providers`, global + primitive + shell CSS imports |
| `app/providers.tsx` | 42 | 2026-04-18 | TanStack Query client provider + (no auth provider observed) |
| `app/globals.css` / `app/primitives.css` / `app/shell.css` | — | — | Tailwind v4 `@theme` CSS + primitive tokens + shell tokens |
| `app/favicon.ico` | — | — | favicon asset |

### 2.4 Chrome / scaffolding components

One global shell — no per-page layouts.

**`components/shell/` (chrome):**

| File | LOC | Role |
|---|---:|---|
| `components/shell/Shell.tsx` | 46 | outer shell wrapper (Rail + Topbar + children) |
| `components/shell/Rail.tsx` | 63 | left nav rail; consumes `NAV` + `activeIdForPathname` from `nav.ts` |
| `components/shell/Topbar.tsx` | 82 | top bar (title, heartbeat, actions) |
| `components/shell/HeartbeatChip.tsx` | 15 | live-pulse indicator |
| `components/shell/nav.ts` | 46 | `NAV` array (16 entries, flat) + `activeIdForPathname(pathname)` |
| `components/shell/index.ts` | — | barrel export |

**`components/primitives/` (13 shared primitives):**

`Button.tsx` (27) · `Card.tsx` (15) · `Chip.tsx` (17) · `FlowRow.tsx` (29) · `KPI.tsx` (24) · `PillGroup.tsx` (36) · `SectionHead.tsx` (24) · `StatusChip.tsx` (60) · `StatusDot.tsx` (14) · `Tabs.tsx` (36) · `ZaraSummary.tsx` (63) · `ZAvatar.tsx` (39) · `index.ts` (barrel).

**`components/shared/`:**

`EmptyState.tsx` (26) + `EmptyState.css`.

### 2.5 Error and loading boundaries per page

6 of 16 routes ship Next.js `error.tsx` + `loading.tsx` files in their route folder; the other 10 do not. Listed in alphabetical order:

| Route | `error.tsx` LOC | `loading.tsx` LOC |
|---|---:|---:|
| `/alarms` | 78 | 75 |
| `/clients` | 73 | 35 |
| `/events` | 81 | 35 |
| `/guards` | 73 | 35 |
| `/ledger` | 81 | 33 |
| `/sites` | 73 | 35 |

Routes with no per-page error or loading boundary: `/`, `/admin`, `/ai-queue`, `/command`, `/dispatches`, `/governance`, `/intel`, `/reports`, `/track`, `/vip`. These fall back to the root `app/layout.tsx` error handling (no top-level `error.tsx` or `loading.tsx` exists at the app root — verified via `find app -maxdepth 1 -name "error.tsx" -o -name "loading.tsx"` returning empty).

---

## 3. Page-level matrix

Rows sorted by v1 functional area (from `OnyxRouteSection`), then by page name within section. v2-only rows appended where no v1 counterpart exists; v1-only rows appended where no v2 counterpart exists.

Abbreviations:
- v1 files live under `lib/ui/` unless otherwise prefixed.
- v2 server-page files are listed as `app/<route>/page.tsx`; the client shell is implied (see §2.1).
- **Notes** distinguishes renamed/relocated pages and any known mount caveats.

| Section | Page name | v1 route | v1 file | v2 route | v2 file | Status | Notes |
|---|---|---|---|---|---|---|---|
| (pre-shell / landing) | Zara home | `/` | `zara_ambient_page.dart` | `/` | `app/page.tsx` + `app/_components/ZaraClient.tsx` | both | Both pages render ambient surface without the nav rail chrome. v1 passes `events`, `operatorLabel`, `siteLabel` and four `onOpen*` callbacks into `ZaraAmbientPage` (`lib/ui/zara_ambient_page.dart:11`). v2 renders `ZaraClient` with only a server-emitted `initialTimeIso`. |
| Command Center | Command Center | `/dashboard` | `command_center_page.dart` (wrapper) + `live_operations_page.dart` (21176-LOC body) | `/command` | `app/command/page.tsx` + `CommandClient.tsx` | renamed | v1 enum label is "Command"; the underlying path `/dashboard` was repurposed to the command surface. v2 consolidated the path to `/command`. Both serve the same role (unified operator surface). |
| Command Center | Agent (Zara brain) | `/agent` | `onyx_agent_page.dart` | — | — | v1_only | 13549-LOC page; v2 has no `/agent` route. v2's Zara surface is split across `/` (ambient), `/ai-queue` (task queue), and the Zara summary primitive (`components/primitives/ZaraSummary.tsx`). |
| Command Center | AI Queue | `/ai-queue` | `ai_queue_page.dart` | `/ai-queue` | `app/ai-queue/page.tsx` + `AIQueueClient.tsx` (+ `CognitionGraph.tsx`) | both | — |
| Command Center | Alarms | `/alarms` | `alarms_page.dart` | `/alarms` | `app/alarms/page.tsx` + `AlarmsClient.tsx` (+ `AlarmCard`, `Drawer`, `EvidenceBox`, `Lane`, `Waveform`) | both | — |
| Command Center | Dispatches | `/dispatches` | `dispatch_page.dart` | `/dispatches` | `app/dispatches/page.tsx` + `DispatchesClient.tsx` | both | — |
| Command Center | Tactical / Track | `/tactical` | `tactical_page.dart` | `/track` | `app/track/page.tsx` + `TrackClient.tsx` + `TrackMap.tsx` | renamed | v1 route `/tactical`; v1 nav label "Track"; v2 route collapsed to `/track` matching the nav label. |
| Operations | Clients / Comms | `/clients` | `clients_page.dart` (primary) + `client_app_page.dart` (alternate) | `/clients` | `app/clients/page.tsx` + `ClientsClient.tsx` | both | v1 nav label "Comms"; v2 nav label "Clients". v1 has a ternary fallback that renders `ClientAppPage` under some condition (see `lib/ui/onyx_route_operations_builders.dart:313`); v2 has one unconditional client. |
| Operations | Events | `/events` | `events_review_page.dart` | `/events` | `app/events/page.tsx` + `EventsClient.tsx` | both | v1 supports deep-link query params `origin=…&label=…` decoded at `lib/routing/onyx_router.dart:133`. |
| Operations | Guards | `/guards-workforce` | `guards_workforce_page.dart` (primary) + `guards_page.dart` (alternate) | `/guards` | `app/guards/page.tsx` + `GuardsClient.tsx` | renamed | v1 route `/guards-workforce`; v1 nav label "Guards". v2 path matches nav label. |
| Operations | Intel | `/intel` | `risk_intelligence_page.dart` | `/intel` | `app/intel/page.tsx` + `IntelClient.tsx` | both | — |
| Operations | Sites | `/sites` | `sites_page.dart` | `/sites` | `app/sites/page.tsx` + `SitesClient.tsx` + `KindIcon.tsx` | both | — |
| Operations | VIP | `/vip` | `vip_protection_page.dart` | `/vip` | `app/vip/page.tsx` + `VIPClient.tsx` | both | — |
| Governance | Governance | `/governance` | `governance_page.dart` | `/governance` | `app/governance/page.tsx` + `GovernanceClient.tsx` | both | — |
| Evidence | Ledger / OB Log | `/ledger` | `sovereign_ledger_page.dart` | `/ledger` | `app/ledger/page.tsx` + `LedgerClient.tsx` | both | v1 nav label "OB Log"; v2 nav label "Ledger". |
| Evidence | Reports | `/reports` | `client_intelligence_reports_page.dart` | `/reports` | `app/reports/page.tsx` + `ReportsClient.tsx` | both | v1 widget class is `ClientIntelligenceReportsPage`; v2 client shell is `ReportsClient`. |
| System | Admin | `/admin` | `admin_page.dart` (class `AdministrationPage`, 47091 LOC) | `/admin` | `app/admin/page.tsx` + `AdminClient.tsx` | both | — |
| (pre-router / login) | Controller login | *(not go_router; `home: ControllerLoginPage` at `lib/main.dart:34521`)* | `controller_login_page.dart` | — | — | v1_only | v2 has no login surface; per the v2 audit (cross-cutting finding #1), no `middleware.ts`, no session client wired to any page — no auth flow. |
| (alternate shell) | Guard mobile shell | *(not go_router; `return GuardMobileShellPage` at `lib/main.dart:40780`)* | `guard_mobile_shell_page.dart` | — | — | v1_only | v1's guard-side mobile experience. No v2 equivalent observed. |
| (modal) | Organization | *(pushed via `Navigator.push` from `app_shell.dart:1049`)* | `organization_page.dart` | — | — | v1_only | Pushed as modal screen, not a top-level route. No v2 equivalent. |

### 3.1 Status counts

- **both:** 14 rows (Zara home, Command Center, AI Queue, Alarms, Dispatches, Tactical/Track, Clients, Events, Guards, Intel, Sites, VIP, Governance, Ledger, Reports, Admin = 16 rows in the table; but "Command Center", "Tactical/Track", "Guards", "Clients/Comms" are marked `renamed` → both-routes-exist, counted under `both` for §4 feature-row scope). Total pages with a counterpart in both systems: **16**.
- **renamed** (subset of `both`): 4 — Command Center (`/dashboard` ↔ `/command`), Tactical/Track (`/tactical` ↔ `/track`), Guards (`/guards-workforce` ↔ `/guards`), Clients/Comms (same path; nav labels differ only).
- **v1_only:** 4 rows — Agent (`/agent`), Controller login, Guard mobile shell, Organization.
- **v2_only:** 0 rows — every v2 route has a v1 counterpart with the same semantic meaning.

Routes that match on path-exact basis in both systems (no rename): `/`, `/admin`, `/ai-queue`, `/alarms`, `/clients`, `/dispatches`, `/events`, `/governance`, `/intel`, `/ledger`, `/reports`, `/sites`, `/vip` (13 path-exact matches).

Routes that match semantically but differ by path (`renamed`): `/dashboard` → `/command`, `/tactical` → `/track`, `/guards-workforce` → `/guards` (3 renames).

**§4 feature-row scope** — based on these counts, §4 will produce feature tables for:
- 16 `both` pages (including the 4 renames)
- 4 `v1_only` pages (Agent, Controller login, Guard mobile shell, Organization)
- 0 `v2_only` pages
- Total = 20 per-page feature tables.

---

*§4 (feature-level matrix) pending.*
