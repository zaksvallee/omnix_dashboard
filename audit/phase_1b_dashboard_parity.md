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

## 4. Feature-level matrix

One table per page. v1 file paths are relative to `/Users/zaks/omnix_dashboard/`; v2 file paths are relative to `/Users/zaks/onyx_dashboard_v2/`. Status values: `present`, `present_stub`, `absent`, `unverified`.

### 4.1 Command Center

#### Page: `/` Zara home (v1: `ZaraAmbientPage` | v2: `ZaraClient`)

| Feature | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| Live signal/activity feed | present | `lib/ui/zara_ambient_page.dart:630` (recent-signals scroll) | present_stub | `app/_components/ZaraClient.tsx:329–360` (`AutonomousLog` renders hardcoded `AUTONOMOUS_OPS[]` per v2 audit) | v2 array is fabricated (v2 audit cross-cutting #4); no live read. |
| Quick-action navigation buttons | present | `lib/ui/zara_ambient_page.dart:679` (navigates to Command Center / Alarms / Dispatches / Guards / CCTV via `onOpen*` callbacks) | present | `app/_components/ZaraClient.tsx:405–431` (`QuickNav` with `href` links) | — |
| Animated heartbeat / Zara avatar | present | `lib/ui/zara_ambient_page.dart:716` (pulsing animation + status badge) | present | `app/_components/ZaraClient.tsx:707,753–761` (presence variants + heartbeat shelf) | v2 offers Orb/Rings/Field toggles (v2 audit §`/` interactive elements). |
| Greeting card with operator + site labels | present | `lib/ui/zara_ambient_page.dart:378` | present | `app/_components/ZaraClient.tsx:709–727` | v1 takes `operatorLabel`/`siteLabel` as widget props; v2 uses `initialTimeIso` for server-rendered time-of-day greeting. |
| Operational health pills (incidents / dispatches) | present | `lib/ui/zara_ambient_page.dart:602` | present_stub | `app/_components/ZaraClient.tsx:720–723` (rendered from `STATEMENTS[]` hardcoded array per v2 audit) | v2 fabricated, not live. |
| Surfaced alert card with dismiss/open | present | `lib/ui/zara_ambient_page.dart:275` | present | `app/_components/ZaraClient.tsx:438–469` (`AlertChip` with `onDismiss`/`onOpen` handlers) | Per v2 audit Flagged-for-deeper-investigation: whether dismiss writes anywhere is not traced. |

#### Page: Command Center (v1: `/dashboard` → `CommandCenterPage` → `LiveOperationsPage` | v2: `/command` → `CommandClient`)

Renamed route. Feature rows are against `LiveOperationsPage` (21176-LOC body) vs `CommandClient` (551 LOC).

| Feature | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| Live queue panel of active incidents | present | `lib/ui/live_operations_page.dart:10899` (`_toggleTopBarPriorityFilter`, queue filter cue) | present | `app/command/_components/CommandClient.tsx:353–424` (`cc-queue` section) | v2 polls queue every 10s; v1 updates via `setState` + `_routerRefreshNotifier`. |
| Dispatches strip with phase progression | present | `lib/ui/live_operations_page.dart:7642` (incident decision ledger with phase lifecycle rendering) | present | `app/command/_components/CommandClient.tsx:457–487` (`dispatch-strip` with `dispatchPhaseFor`) | — |
| Events / activity stream | present | `lib/ui/live_operations_page.dart:9440` (workspace status banner + context tabs) | present | `app/command/_components/CommandClient.tsx:514–527` (`events-list`) | — |
| P1 alert banner when queue has a P1 | unverified | not found by grep of `P1 banner` / `showBanner` in `live_operations_page.dart`; v1 surfaces severity differently (shell badges via `OnyxRouteShellBadgeKind.activeIncidents`) | present | `app/command/_components/CommandClient.tsx:254–274` (conditional `showBanner` with `p1Count`) | v1 may not have a dedicated P1 banner; noted `unverified` rather than `absent` because shell badge bar is a potential equivalent surface. |
| CCTV live-view dialog | present | `lib/ui/live_operations_page.dart:538` (client lane live-view: `_refreshFrame`, `_toggleAutoRefresh`, `onCopyFrameUrl`, `onOpenStreamPlayer`) | present_stub | `app/command/_components/CommandClient.tsx:533–547` (`cc-cctv-strip` with `BOTTOM_CAMERAS` placeholder frames; v2 audit: "Live feed pending — camera pipeline wiring") | v1 has real camera frame refresh; v2 is placeholder. |
| Client comms drawer / right rail | present | `lib/ui/live_operations_page.dart:7896` (`_openCommandClientLane`) | absent | not found | No v2 comms drawer on `/command`. |
| Guards rail board | present | `lib/ui/live_operations_page.dart:7770` (`_openCommandGuardsBoard`) | absent | not found | — |

#### Page: `/agent` Agent brain (v1_only)

| Feature | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| Multi-tab nav rail (Dispatch / CCTV / Comms / Track / Board) | present | `lib/ui/onyx_agent_page.dart:1697–1770` (`_zaraAgentNavRail`) | absent | — | No `/agent` route in v2. |
| Thread / conversation rail | present | `lib/ui/onyx_agent_page.dart:3676–3760` (`_buildThreadRail`, `_createThread` at `:7099`, `_selectThread` at `:7137`) | absent | — | — |
| Active signals panel (left rail) | present | `lib/ui/onyx_agent_page.dart:1831–1920` (`_zaraAgentLeftRail`, `_zaraSignalRow` at `:1923`) | absent | — | — |
| Conversation composer with quick prompts | present | `lib/ui/onyx_agent_page.dart:3512–4794` (`_buildConversationSurface`, composer at `:4674`, quick-action chips at `:4712`) | absent | — | — |
| Agent recommendation actions panel (right rail) | present | `lib/ui/onyx_agent_page.dart:2741–2830` (`_zaraAgentRightRail`) | absent | — | — |
| Prompt submission → LLM synthesis | present | `lib/ui/onyx_agent_page.dart:7243–7559` (`_submitPrompt` → `_runCloudBoost` / `_runLocalBrainSynthesis`) | absent | — | v1 calls cloud or local-brain path. No v2 equivalent (Zara surfaces on `/` and `/ai-queue` are display-only). |
| Action executor dispatcher | present | `lib/ui/onyx_agent_page.dart:9220–9589` (`_handleAction` with sub-handlers for each action kind) | absent | — | — |

#### Page: `/ai-queue`

| Feature | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| Task queue list with status icons | present | `lib/ui/ai_queue_page.dart:2627` (`_setWorkspaceView` lane selector) | present | `app/ai-queue/_components/AIQueueClient.tsx:60–104` (`iconForStatus`, `TaskFeedRow`) | — |
| Task row selection / URL persistence | present | `lib/ui/ai_queue_page.dart:1119` (`_openDetailedWorkspace`) | present | `app/ai-queue/_components/AIQueueClient.tsx:321–325` (`selectTask` updates URL param) | — |
| Reasoning trace panel per task | present | `lib/ui/ai_queue_page.dart:1855` (runbook/policy/context tabs in focused action) | present_stub | `app/ai-queue/_components/AIQueueClient.tsx:135–287` (`Inspector` with `demoTrace`/`demoThink`/`demoSteps`) | v2 audit: "Live traces will populate once Zara engine writes `decision_audit_log`"; status `present_stub` because rendering works but data is fixture. |
| Action operation controls (cancel / pause / approve) | present | `lib/ui/ai_queue_page.dart:2755` (`_cancelAction`, `_promoteAction`, `_approveAction`) | absent | not found | v2 has no action-on-task controls. |
| CCTV board with alert selector | present | `lib/ui/ai_queue_page.dart:857` (`_viewCctvAlert`) | absent | not found | — |
| Worker chain display | unverified | not explicitly named in v1 grep; v1 focuses on approved/denied/shadow lanes instead (`ai_queue_page.dart:91` daily stats) | present | `app/ai-queue/_components/AIQueueClient.tsx:96,242` (`task.workers` rendered) | v1 may surface worker chain inside detailed workspace; not verified from static analysis. |
| Cognition graph visualization | absent | not found in v1 | present | `app/ai-queue/_components/AIQueueClient.tsx:455–458` (`CognitionGraph` with workers/edges) + `app/ai-queue/_components/CognitionGraph.tsx` | — |
| Standby workspace with focus groups (MO dossier, shift draft) | present | `lib/ui/ai_queue_page.dart:4793` (`_openStandbyWorkspace`) | absent | not found | — |

#### Page: `/alarms`

| Feature | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| Alarms list view | present | `lib/ui/alarms_page.dart:476` (ListView with `_buildAlarmCard`); `lib/ui/alarms_page.dart:887` (full alarm record detail) | present | `app/alarms/_components/AlarmsClient.tsx:316–328` (`Lane` components over `LANES`) + `AlarmCard.tsx` | — |
| Severity filter (P1 / P2 / P3 / ALL) | unverified | not located via targeted grep in `alarms_page.dart`; v1 uses pagewide state filter idiom | present | `app/alarms/_components/AlarmsClient.tsx:282–292` (`SEV_FILTERS` with `onClick setSevFilter`) | — |
| Kind filter (PERIMETER / PANIC / VEHICLE / AUDIO / FACE) | unverified | not located | present_stub | `app/alarms/_components/AlarmsClient.tsx:296–304` (`KIND_FILTERS` buttons; `onClick` not wired — per v2 audit a LOCAL no-op) | — |
| Triage action path (dispatch / false alarm / escalate) | present | `lib/ui/alarms_page.dart:887` (`_buildAlarmCard` contains action buttons per-alarm); v1 routes triage through dispatch page workflows | present | `app/alarms/_components/Drawer.tsx:166–181` (`fire("dispatch")`/`fire("escalate")`/`fire("false_alarm")` → `PATCH /api/incidents/[id]` via useMutation at `AlarmsClient.tsx:149`) | v2's sole mutation path; same-origin, no user session (phase 1a §6.1). |
| Status chip row (camera count / guard count / signal health) | present | `lib/ui/alarms_page.dart:522` (`_statusStatChip`) | absent | not found | v2's status surface lives elsewhere (command page). |
| Quick actions (run system check / review last incident) | present | `lib/ui/alarms_page.dart:550` (`_quickActionButton`) | absent | not found | — |
| Nominal "ALL SYSTEMS NOMINAL" empty state | present | `lib/ui/alarms_page.dart:406` | unverified | empty-state for v2 alarms not located in evidence pass | flagged for phase 2. |
| Time/grouping toggles (LAST HOUR / GROUPED) | absent | not found | present_stub | `app/alarms/_components/AlarmsClient.tsx:307–312` (buttons exist, no `onClick` wired) | v2-only UI, stubbed. |
| Toast on triage error | absent | not found | present | `app/alarms/_components/AlarmsClient.tsx:136–145,172–180,338–346` (`pushToast` on `onError`) | — |

#### Page: `/dispatches`

| Feature | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| Dispatch feed / list with selection | present | `lib/ui/dispatch_page.dart:3384` (`_setSelectedDispatchId`) | present | `app/dispatches/_components/DispatchesClient.tsx:549–600` (`dsp-table` with `TruthRail`) | — |
| Lane filter chip row (status: all/active/pending/cleared) | present | `lib/ui/dispatch_page.dart:4401` (`_DispatchLaneFilter`) | unverified | v2 has a category-chip row (`:349–360,520–529`) but a status-lane chip row is not located; this may be the same thing reshaped | — |
| Time-window filter (Tonight·12h / 24h / 7d / All) | absent | not found | present | `app/dispatches/_components/DispatchesClient.tsx:505–515` (`TIME_FILTERS` with `onClick setTimeFilter`) | v2-only. |
| Category chips auto from `event.category` | absent | not found | present | `app/dispatches/_components/DispatchesClient.tsx:349–360,520–529` (`categoryChips` derived from `data.categoryCounts`) | v2-only. |
| Dispatch timeline / phase card | present | `lib/ui/dispatch_page.dart:864` (`_incidentTimelineCard`) | present | `app/dispatches/_components/DispatchesClient.tsx:549–600` (truth-rail with intent + transitions) | — |
| Communication transcript block | present | `lib/ui/dispatch_page.dart:868` (`_communicationTranscriptBlock`) | absent | not found | — |
| Outcome card (real / false alarm / no response / safe word) | present | `lib/ui/dispatch_page.dart:893` (`_outcomeCard`) | absent | not found | — |
| Chain-of-custody seal block | present | `lib/ui/dispatch_page.dart:897` (`_chainSealBlock`) | absent | not found | — |
| Context grid (scene details / equipment / observations) | present | `lib/ui/dispatch_page.dart:901` (`_contextGrid`) | absent | not found | — |
| Fleet-scope health sections (limited / alert / repeat / escalation) | present | `lib/ui/dispatch_page.dart:8068` (section tap handlers) | absent | not found | — |
| Truth-rail actions (Full log / Add to report / Concur) | absent | not found as a named primitive | present_stub | `app/dispatches/_components/DispatchesClient.tsx:306–317` (all three buttons `disabled`) | v2-only UI, stubbed. |
| URL-persisted dispatch selection (`?dispatch=`) | unverified | not located in v1 dispatch page | present | `app/dispatches/_components/DispatchesClient.tsx:395–399` (`selectDispatch` updates URL) | — |
| KPI row (tonight count / Zara concurrence % / median response / overrides / executed) | absent | not found | present | `app/dispatches/_components/DispatchesClient.tsx:443–499` (`dsp-kpis` with 6 cards) | v2-only. |

#### Page: Tactical / Track (v1: `/tactical` → `TacticalPage` | v2: `/track` → `TrackClient` + `TrackMap`)

Renamed route.

| Feature | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| Map surface with live markers | present | `lib/ui/tactical_page.dart:2635` (map expand toggle), `:6285` (zoom controls) | present | `app/track/_components/TrackMap.tsx:52–74` (MapLibre GL with MapTiler tiles, `NEXT_PUBLIC_MAPTILER_KEY`) | v1 uses Flutter map widget; v2 uses MapLibre GL JS. |
| Signals header row with top signal + review/send/dismiss | present | `lib/ui/tactical_page.dart:1491` (`_buildSignalsHeaderRow`) | absent | not found | — |
| Verification queue tabs (Anomalies / Matches / Assets) | present | `lib/ui/tactical_page.dart:3328` (`onSetQueueTab`) | absent | not found | — |
| Map filter cycle (all / responding / incidents) | present | `lib/ui/tactical_page.dart:3312` (`_cycleFilter`) | present_stub | `app/track/_components/TrackClient.tsx:220–241` (`tr-layer-pill` buttons with `toggleLayer`; only `sites` layer has data per v2 audit) | v2 offers 6 layer toggles (sites/guards/response/vip/patrols/awareness); 5 are aspirational. |
| Center-active button (jump to active unit) | present | `lib/ui/tactical_page.dart:3320` (`_centerActive`) | absent | not found | — |
| Site list with incident counts | absent | not found as a list (v1 uses map markers) | present | `app/track/_components/TrackClient.tsx:243–272` (`tr-sites` mapping `data.sites` with incidents count) | — |
| Inspector actions (Open in Sites / Hail site / Dispatch) | present | `lib/ui/tactical_page.dart:5485` (section tap handlers for suppressed/limited actions with drilldown) | present_stub | `app/track/_components/TrackClient.tsx:412–429` (`tr-insp-actions`: `Open in Sites` as href link = `present`; `Hail site` + `Dispatch` disabled) | mixed — one working link, two stubs. |
| URL-persisted site selection (`?site=`) | unverified | not located | present | `app/track/_components/TrackClient.tsx:126–132` (`selectSite` updates URL) | — |
| Placeholder-coordinate DB hygiene warning | absent | not found | present | `app/track/_components/TrackClient.tsx:167–175` (`coordOverrideCount` warning text) | v2-only surfaced. |
| Fleet-scope drilldown (recovery / tactical / dispatch / detail) | present | `lib/ui/tactical_page.dart:4999` (drilldown navigation) | absent | not found | — |
| Live signals table | present | `lib/ui/tactical_page.dart:4848` (signal row with `onOpenTactical`, `onOpenDispatch`) | absent | not found | — |

---

*§4 Batch A (Command Center, 7 pages) written — Operations, Governance/Evidence/System, and remaining v1-only batches pending.*
