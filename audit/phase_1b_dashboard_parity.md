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

### 4.2 Operations

#### Page: `/clients` (v1 nav "Comms" | v2 nav "Clients")

| Feature | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| Client / site selector with room routing | present | `lib/ui/clients_page.dart:2455` (`_selectorSurface`), `:2399` (`_roomButton`) | present | `app/clients/_components/ClientsClient.tsx:104,126–132` (client row selection) | — |
| Client list filter (ALL / HEALTHY / AT RISK / RENEWAL) | unverified | not directly located; v1 surfaces client state via selectors rather than filter chips | present | `app/clients/_components/ClientsClient.tsx:109` | v2 audit: `RENEWAL` is disabled. |
| Hero actions (touchpoint / contract / ticket) | absent | not found in v1 (v1 routes these via direct message/agent flows) | present_stub | `app/clients/_components/ClientsClient.tsx:258–260` (all three buttons disabled) | v2-only UI, stubbed. |
| Message history with live thread context | present | `lib/ui/clients_page.dart:_messageHistoryKey` (`_messageHistoryKey`-scoped scroll anchor) | absent | not found | — |
| Pending drafts queue for AI replies | present | `lib/ui/clients_page.dart:3113` (`_pendingDraftsCard`) | absent | not found | — |
| Communication channels delivery status (Telegram / SMS / VoIP) | present | `lib/ui/clients_page.dart:2546` (`_communicationChannelsCard`) | absent | not found | — |
| Voice/tone selector (Auto / Concise / Reassuring / Formal) | present | `lib/ui/clients_page.dart:3268` (`_pinnedVoiceCard`) | absent | not found | — |
| Junior Analyst agent handoff | present | `lib/ui/clients_page.dart:2330` (`onPressed: () => openAgent(...)`) | absent | not found | — |
| Evidence return receipt banner | present | `lib/ui/clients_page.dart:1165` (`_acknowledgeEvidenceReturnReceipt`) | absent | not found | — |
| Desktop workspace toggle (3-panel vs compact) | present | `lib/ui/clients_page.dart:892` (`_clientsDetailedWorkspaceToggle`) | absent | not found | — |

#### Page: `/sites`

| Feature | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| Site list / roster with selection | present | `lib/ui/sites_page.dart:210` (`_buildRosterPanel`) | present | `app/sites/_components/SitesClient.tsx:190–222,255–257` (site list with posture pills) | — |
| Site detail card with stats | present | `lib/ui/sites_page.dart:414` (`_siteDetailContent`; guard on-site, cameras active, 24h incidents, avg response) | present | `app/sites/_components/SitesClient.tsx:238–277,354–406` (risk rating + client + zone labels) | v2 detail misses the 24h-incidents and avg-response counters listed in v1. |
| Site posture summary bar (totals + Strong / At-Risk / Critical) | present | `lib/ui/sites_page.dart:70` (`_buildPostureSummaryBar`) | absent | not found | — |
| Site posture filter (ALL / ARMED / ISSUES / VIP) | absent | not found (v1 uses summary bar counts, not filter chips) | present_stub | `app/sites/_components/SitesClient.tsx:45–50` (filter chip row; `ARMED`/`ISSUES`/`VIP` disabled per v2 audit) | — |
| Kind facet filter (RETAIL / RESI / OFFICE / INDUS / CONSUL) | absent | not found | present | `app/sites/_components/SitesClient.tsx:52–59,171–188` (kind facets work) | v2-only; Section 4 of v2 audit confirms these are wired. |
| Hero actions (Ops log / Cameras / Dispatch) | absent | not found (v1 surfaces these via LiveOps / Tactical routes) | present_stub | `app/sites/_components/SitesClient.tsx:281–290` (all three disabled per v2 audit) | — |
| Watch health status card | present | `lib/ui/sites_page.dart:542` (WATCH HEALTH STATUS container) | absent | not found | — |
| Navigate to tactical map button | present | `lib/ui/sites_page.dart:154` (`onPressed: () => _navigateToRoute(context, OnyxRoute.tactical)`) | absent | not found | — |

#### Page: Guards (v1: `/guards-workforce` | v2: `/guards`)

Renamed route.

| Feature | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| Guard roster list with status pills | present | `lib/ui/guards_workforce_page.dart:1180` (`onTap: () => _selectGuard(guard.id)`) | present | `app/guards/_components/GuardsClient.tsx:174–211` | — |
| Status filter (ALL / ON DUTY / INACTIVE / STANDBY / TRAINING / LEAVE) | unverified | not located as a single chip row in v1 | present_stub | `app/guards/_components/GuardsClient.tsx:43–50,159–172` (STANDBY/TRAINING/LEAVE disabled per v2 audit) | — |
| Guard detail dossier (PSIRA, badge, post, shift pattern, equipment) | present | `lib/ui/guards_workforce_page.dart:2027` (`_actionBar` over guard detail surface) | present | `app/guards/_components/GuardsClient.tsx:218–419` | v2 audit: PSIRA + badge + post + callsign + equipment all rendered read-only. |
| Hero actions (Message / Roster / Reassign) | unverified | v1 has `_actionBar` with Dispatch/Contact/Location/Activity — different set; grep didn't surface `Message/Roster/Reassign` handlers in v1 | present_stub | `app/guards/_components/GuardsClient.tsx:260–262` (all three disabled per v2 audit) | v1 has Dispatch/Contact/Location/Activity buttons instead (different action set). |
| Tabs: Active Guards / Shift Roster / Shift History | present | `lib/ui/guards_workforce_page.dart:34` (`enum _WorkforceTab`), `:609` (shiftRosterTab), `:614` (shiftHistoryTab) | absent | not found — v2 has no tab switcher on `/guards` | v2 is single-view. |
| ZARA continuity summary strip | present | `lib/ui/guards_workforce_page.dart:683` (`_zaraSummaryStrip`) | absent | not found | — |
| Workforce status bar (aggregate readiness pills + site selector) | present | `lib/ui/guards_workforce_page.dart:598` (`_workforceStatusBar`) | absent | not found | — |
| Shift coverage grid | present | `lib/ui/guards_workforce_page.dart:609` (`_shiftRosterTab`) | absent | not found (v2 audit: "will appear once shift tracking is enabled") | — |
| Shift history anomaly markers | present | `lib/ui/guards_workforce_page.dart:614` (`_shiftHistoryTab`) | absent | not found | — |
| 30-day attendance heatmap | absent | not found in v1 | present_stub | `app/guards/_components/GuardsClient.tsx:331–334` (empty-state rendered; v2 audit: "will appear once shift tracking is enabled") | — |
| Export workforce snapshot | present | `lib/ui/guards_workforce_page.dart:660` (`onPressed: _exportWorkforceSnapshot`) | absent | not found | — |

#### Page: `/events`

| Feature | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| Event list with row selection | present | `lib/ui/events_review_page.dart:4384` (`onTap: () => setState(() => _selectedEvent = event)`) | present | `app/events/_components/EventsClient.tsx:260–293` | — |
| Activity filter (ACTIVE / ALL / MINE / ESCAL) | absent | not found (v1 uses different filter axes — see next rows) | present_stub | `app/events/_components/EventsClient.tsx:43–52,209–220` (`MINE`/`ESCAL` disabled per v2 audit) | — |
| Event type filter (ALL / INCIDENT / DISPATCH / AI DECISION / ALARM) | present | `lib/ui/events_review_page.dart:2026` (`_scopeRailDropdown<String>` with `_filterOptions` at `:130`) | absent | not found (v2 has category chips auto-derived, not these explicit types) | — |
| Source + provider filter (cascading) | present | `lib/ui/events_review_page.dart:2034,2047` (two `_scopeRailDropdown<String>`) | absent | not found | — |
| Identity policy filter (flagged / temporary / allowlisted) | present | `lib/ui/events_review_page.dart:2058` (`_scopeRailDropdown<String>` with policy options) | absent | not found | — |
| Severity pills (P1 / P2 / P3 / CLSD) | unverified | not located in v1 events-review as a pill row | present | `app/events/_components/EventsClient.tsx:54,193–206` | — |
| Category chips (auto-derived) | absent | not found in v1 | present | `app/events/_components/EventsClient.tsx:116,222–246` | — |
| Hero actions (Note / Dispatch / Resolve) | absent | not found (v1 routes these via dispatch page + agent) | present_stub | `app/events/_components/EventsClient.tsx:344–346` (all three disabled per v2 audit) | — |
| Desktop workspace toggle (scoped detail vs full list) | present | `lib/ui/events_review_page.dart:146` (`_desktopWorkspaceActive`) | absent | not found | — |
| Scope rail with origin back-link chip | present | `lib/ui/events_review_page.dart:1998` (`_buildScopeRail`); URL encoding at `lib/routing/onyx_router.dart:133–172` | absent | not found (v2 has no deep-link origin chip) | v1 has full `origin=ledger&label=X` round-trip; v2 does not. |
| Row actions (copy JSON / copy CSV / open governance) | present | `lib/ui/events_review_page.dart:4384` (contextual row actions) | absent | not found | — |
| Site-scoped minimap | absent | not found in v1 | present_stub | `app/events/_components/EventsClient.tsx:352–364` (empty-state rendered per v2 audit) | — |
| Readiness / tomorrow banner | present | `lib/ui/events_review_page.dart:550` (`if (readinessScopeSummary != null)`) | absent | not found | — |

#### Page: `/vip`

| Feature | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| Principal list with selection | present | `lib/ui/vip_protection_page.dart:195` (`_vipDetailCard` clickable); scheduled-details section at `:162` | present | `app/vip/_components/VIPClient.tsx:644–645,672–676,744–752` (URL-persisted `?principal=`) | — |
| Principal filter (ALL / ACTIVE / TIER 1 / OFF) | absent | not found in v1 (single demo detail listing) | present | `app/vip/_components/VIPClient.tsx:678–683,732–742` | — |
| Scheduled details manifest | present | `lib/ui/vip_protection_page.dart:162–194` (scheduled-details list + for-loop) | present | `app/vip/_components/VIPClient.tsx:363–415` (today's movements manifest) | — |
| Advance brief / Zara-compiled | absent | not found in v1 | present | `app/vip/_components/VIPClient.tsx:347–361` | v2-only. |
| Detail roster / route / venue / vehicle cards | absent | not found in v1 | present | `app/vip/_components/VIPClient.tsx:417–557` | v2-only. |
| Threats & watches feed | absent | not found in v1 | present | `app/vip/_components/VIPClient.tsx:579–596` | v2-only. |
| Hero actions (Open on map / Itinerary / Link event / Hail detail) | absent | not found | present_stub | `app/vip/_components/VIPClient.tsx:322–342` (all four currently disabled; v2 audit flags "verify before demo") | Unclear whether `Link event` / `Hail detail` are actually wired (v2 audit flagged for deeper investigation). |
| New VIP detail button | present | `lib/ui/vip_protection_page.dart:136` (`onPressed: () => _createNewVipDetail(context)`) | absent | not found | — |
| VIP empty-state with templates (Executive / Diplomatic / High-Net-Worth) | present | `lib/ui/vip_protection_page.dart:493` (`_VipEmptyState` class) | absent | not found | — |
| Latest auto-audit receipt notice | present | `lib/ui/vip_protection_page.dart:157` (`_VipEmptyState` with `onOpenLatestAudit`) | absent | not found | — |

#### Page: `/intel`

| Feature | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| Thread / intel feed list | present | `lib/ui/risk_intelligence_page.dart:124` (`recentItems` + build) | present | `app/intel/_components/IntelClient.tsx:242–290` | — |
| Severity filter (ALL / ACTIVE / WATCH / CLOSED) | absent | not found in v1 (v1 filters by area-state instead) | present | `app/intel/_components/IntelClient.tsx:143–148,230–239` | — |
| Thread detail panel | unverified | v1 surfaces detail inline on each row; no separate panel found | present | `app/intel/_components/IntelClient.tsx:294–376` | — |
| Add manual intel button | present | `lib/ui/risk_intelligence_page.dart:118` (`onAddManualIntel`) | absent | not found | — |
| Risk-area state cards (STABLE / ELEVATED / HIGH ALERT with counts + View/Track) | present | `lib/ui/risk_intelligence_page.dart:685` (`_areaStateCard`) | absent | not found | v1-only area-state grid. |
| Predictive forecast block | present | `lib/ui/risk_intelligence_page.dart:532` (`_forecastBlock`) | absent | not found | — |
| Send area → track action | present | `lib/ui/risk_intelligence_page.dart:781` (`onSendAreaToTrack`) | absent | not found | — |
| Send individual signal → track action | present | `lib/ui/risk_intelligence_page.dart:966` (`onSendSignalToTrack`) | absent | not found | — |
| Pattern library tabs (FACES / PLATES / VOICES / SIGNATURES) | absent | not found in v1 | present | `app/intel/_components/IntelClient.tsx:150–159,384–445` | v2-only. v2 audit: only FACES has data. |
| Face registry display (photo count + role) | unverified | v1 FR is via the Zara/agent surface and `tool/face_gallery/` — not a UI registry here | present | `app/intel/_components/IntelClient.tsx:405–424` | — |
| Cross-site timeline | absent | not found in v1 | present_stub | `app/intel/_components/IntelClient.tsx:341–348` (empty-state) | — |
| Entity-link graph | absent | not found in v1 | present_stub | `app/intel/_components/IntelClient.tsx:350–357` (empty-state) | — |

---

### 4.3 Governance / Evidence / System

#### Page: `/governance`

| Feature | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| Operator attestations table (PSIRA dates) | unverified | v1 grep did not surface an attestations-only view — governance surface is wider (readiness signals, blockers, partner trends) | present | `app/governance/_components/GovernanceClient.tsx:224–248` (attestations from `guards` table per v2 audit) | v2 audit: this is the one live/honest surface on `/governance`. |
| KPI row (current / renewal / overdue counts) | unverified | not located as a KPI row; v1 has compliance blockers instead | present | `app/governance/_components/GovernanceClient.tsx:110–134` | — |
| Policy filter (ALL / AT-RISK / ZARA FLAGS / DRAFT) | absent | not found in v1 | present_stub | `app/governance/_components/GovernanceClient.tsx:148–159` (last three disabled per v2 audit) | — |
| Policy catalogue list | absent | not found (v1 doesn't expose a policy catalogue UI) | absent | `app/governance/_components/GovernanceClient.tsx:161–165` (empty-state: "will appear here once SOP registry is enabled") | both absent — v2 is explicit empty-state. |
| Selected policy detail (adherence + version history) | absent | not found | absent | `GovernanceClient.tsx:169–209` (empty-state) | — |
| Exception review queue | absent | not found | absent | `GovernanceClient.tsx:191–198` (empty-state) | — |
| Audit trail of signatures / amendments | absent | not found | absent | `GovernanceClient.tsx:250–256` (empty-state) | — |
| Zara observations panel | absent | not found | absent | `GovernanceClient.tsx:258–264` (empty-state) | — |
| Compliance blocker alerts (severity-tracked) | present | `lib/ui/governance_page.dart:2422` (`_readinessBlockersSurface`) | absent | not found | — |
| Partner trend analysis (7-day) | present | `lib/ui/governance_page.dart:8565` (`_partnerTrendRows`) | absent | not found | — |
| Operational readiness signals board | present | `lib/ui/governance_page.dart:2706` (`_readinessSignalsSurface`) | absent | not found | — |
| Scope context rail with handoff actions | present | `lib/ui/governance_page.dart:1604` (`_governanceContextRail`) | absent | not found | — |
| Quick actions recovery deck | present | `lib/ui/governance_page.dart:2596` (`_quickActionsSurface`) | absent | not found | — |
| Desktop workspace layout (embedded panels + ops/board/context rails) | present | `lib/ui/governance_page.dart:1117` (`_governanceDesktopWorkspace`) | absent | not found | — |

#### Page: Ledger (v1 nav "OB Log" → `/ledger` | v2 "Ledger" → `/ledger`)

| Feature | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| Ledger feed with entry selection | present | `lib/ui/sovereign_ledger_page.dart:1120` (`_buildDetailPanel`) | present | `app/ledger/_components/LedgerClient.tsx:357–448` (infinite-scroll "Load next 100") | — |
| Category / facet filter | present | `lib/ui/sovereign_ledger_page.dart:2921` (`enum _ObCategory`) + full-text search | present | `app/ledger/_components/LedgerClient.tsx:237–281` (facet chips: All / EVIDENCE / COMMUNICATIONS / DECISIONS / INTEL / VIP / DISPATCH / UNTYPED) | v1 includes free-text search; v2 is chip-only. |
| Block / entry detail inspector (canonical JSON payload) | present | `lib/ui/sovereign_ledger_page.dart:1120` (detail panel with payload, hash chain, related entries) | present | `app/ledger/_components/LedgerClient.tsx:450–487` | — |
| Chain integrity badge | present | `lib/ui/sovereign_ledger_page.dart:335` (`_buildHeroPanel`) | present | `app/ledger/_components/LedgerClient.tsx:291–340` (chain integrity badge + latest root hash) | — |
| Manual audit entry composer | present | `lib/ui/sovereign_ledger_page.dart:554` (`_buildComposerPanel`) | absent | not found (`LedgerClient.tsx:283–286` — panel placeholder only, no composer) | v1 ships the composer; v2 does not. |
| Multi-view toggle (Record / Chain / Linked) | present | `lib/ui/sovereign_ledger_page.dart:3004` (`enum _ObWorkspaceView`) | absent | not found | — |
| Hero actions (Verify chain / Export packet) | absent | not found in v1 | present_stub | `app/ledger/_components/LedgerClient.tsx:343–353` (both disabled per v2 audit) | — |
| Pinned audit entry highlight | present | `lib/ui/sovereign_ledger_page.dart:38–68` (class `SovereignLedgerPinnedAuditEntry`) | absent | not found | — |
| Cross-app navigation hooks (CCTV / Dispatch / Report / Track / Agent / Ops / Intel / VIP / Roster planner) | present | `lib/ui/sovereign_ledger_page.dart:97–107` (constructor callbacks) | absent | not found | — |

#### Page: `/reports`

| Feature | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| Report list with row selection | present | `lib/ui/client_intelligence_reports_page.dart:2379` (`_reportWorkbenchSurface`) | present | `app/reports/_components/ReportsClient.tsx:616–620,732–761` (URL-persisted) | — |
| Report tab filter | unverified | v1 has scope-based filtering with date range (`:164–166`) rather than fixed tabs | present | `app/reports/_components/ReportsClient.tsx:633–638,719–729` (Dash / Sched / QBR / Tpl) | — |
| Portfolio dashboard (30d stacked-area chart + KPIs) | absent | not found as a distinct chart view | present | `app/reports/_components/ReportsClient.tsx:284–424` (portfolio with 6 KPIs) | v2-only. |
| Export actions (PDF / Print / Share) on portfolio | absent | not found as PDF/Print/Share trio (v1 has proof-engine export flow instead) | present | `app/reports/_components/ReportsClient.tsx:322–331` | v2-only working action set. |
| Hero actions on non-portfolio reports | absent | not found | present_stub | `app/reports/_components/ReportsClient.tsx:451–458` (disabled per v2 audit) | — |
| Report generation with proof-engine verification | present | `lib/ui/client_intelligence_reports_page.dart:149–151` (static members) | absent | not found | v1-only. |
| Receipt history with JSON / CSV copy + status filters | present | `lib/ui/client_intelligence_reports_page.dart:10689` (`_exportCoordinator.copyJson()`) | absent | not found | — |
| Report preview dock (proof builder side-by-side) | present | `lib/ui/client_intelligence_reports_page.dart:3098` (`_reportPreviewSurface`) | absent | not found | — |
| Scope-based filtering with date range | present | `lib/ui/client_intelligence_reports_page.dart:164–166` (scope + start/end date state) | absent | not found | — |
| Governance handoff integration (send report to governance desk) | present | `lib/ui/client_intelligence_reports_page.dart:80–82` (callback params) | absent | not found | — |
| Scheduler / Recipients / Anomalies / Sign-off chain | absent | not found in v1 | absent | `app/reports/_components/ReportsClient.tsx:513–569` (empty-state sections) | both absent; v2 is honest empty-state. |

#### Page: `/admin`

| Feature | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| Tab navigation across admin sections | present | `lib/ui/admin_page.dart:5177` (Guards tab), `:5180` (Sites), `:5183` (Clients), `:10365` (`_systemTab`) | present | `app/admin/_components/AdminClient.tsx:99–111,883–906` (11 tabs) | v1 has entity tabs + system tab; v2 has System health + 10 platform-config tabs. |
| Directory sync and CSV bulk import/export | present | `lib/ui/admin_page.dart:5190–5246` (`_entityManagementView`) | absent | not found (v2 audit: no CSV import/export controls) | v1-only directory management. |
| Interactive entity tables with live counts | present | `lib/ui/admin_page.dart:10152–10290` (table builders) | unverified | v2 has row counts on System health (`AdminClient.tsx:170,186,202,218`); full entity tables not located in evidence pass | partial v2 overlap. |
| System health dashboard (multi-metric) | present | `lib/ui/admin_page.dart:10365–10415` (`_systemTab` aggregating 7+ cards: SLA compliance, policy effectiveness, AI comms, watch identity, listener parity) | present | `app/admin/_components/AdminClient.tsx:170–218` (real row counts on System health tab) | v1 has richer multi-metric; v2 shows row counts only. |
| Partner scorecard with trend filtering | present | `lib/ui/admin_page.dart:10417` (`_partnerScorecardSummaryCard`) | absent | not found | — |
| Global readiness policy monitor | present | `lib/ui/admin_page.dart:11047` (`_globalReadinessSummaryCard`) | absent | not found | — |
| Radio intent phrase / listener alarm tracking | present | `lib/ui/admin_page.dart:11526` (`_radioIntentPhraseCard`) | absent | not found | — |
| Identity & SSO / Roles & access / API keys / Webhooks / Feature flags / Billing & licence | absent | not found | present_stub | `app/admin/_components/AdminClient.tsx` 11-tab nav; all but System health show DUMMY DATA badge per `AdminClient.tsx:113–120` | v2-only surfaces; v2 audit: none are wired to real data. |
| Hero actions (Health check all / + Add integration / New flag) | absent | not found | present_stub | `app/admin/_components/AdminClient.tsx:396–400,573–575` (all disabled per v2 audit) | — |
| "Open in Ledger" link on audit tab | absent | not found | present | `app/admin/_components/AdminClient.tsx:329–331` | v2-only cross-nav hook. |

### 4.4 Additional v1-only pages

These have no v2 counterpart (see §3 row for each). All v2 status rows are therefore `absent`.

#### Page: v1 `ControllerLoginPage` (pre-router; mounted at `lib/main.dart:34521`)

| Feature | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| Username + password entry with validation | present | `lib/ui/controller_login_page.dart:184–203` (`_buildField` username/password) | absent | — | v2 has no login surface. |
| Demo account quick-select | present | `lib/ui/controller_login_page.dart:265–343` (autofill via `_fillDemoAccount`) | absent | — | — |
| Submit authentication → `onAuthenticated` callback | present | `lib/ui/controller_login_page.dart:220–244` (`_submit` at `:52`) | absent | — | — |
| Clear cache / reset preview | present | `lib/ui/controller_login_page.dart:347–373` (`_resetPreview` at `:85`; optional `onResetRequested`) | absent | — | — |
| Inline error display | present | `lib/ui/controller_login_page.dart:204–215` (conditional error text) | absent | — | — |

#### Page: v1 `GuardMobileShellPage` (alternate shell; returned at `lib/main.dart:40780`)

| Feature | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| Shift start verification screen | present | `lib/ui/guard_mobile_shell_page.dart:3200–3241` (`onShiftStartQueued` callback) | absent | — | — |
| Dispatch alert screen | present | `lib/ui/guard_mobile_shell_page.dart:3336–3363` (dispatch tab via `_screenChip`) | absent | — | — |
| Status update (on-duty / break / role-specific) | present | `lib/ui/guard_mobile_shell_page.dart:3442–3482` (`onStatusQueued`) | absent | — | — |
| NFC checkpoint scanning | present | `lib/ui/guard_mobile_shell_page.dart:3484–3545` (`onCheckpointQueued`) | absent | — | — |
| Emergency / panic button | present | `lib/ui/guard_mobile_shell_page.dart:3547–3695` (`onPanicQueued` at `:3605`) | absent | — | — |
| Sync history + queue management (retry failed ops) | present | `lib/ui/guard_mobile_shell_page.dart:2203–2450` (panel with filter chips + retry at `:2364`, `:2389`, `:2792`, `:2817`) | absent | — | — |
| Telemetry payload validation (test adapters / vendor connectors) | present | `lib/ui/guard_mobile_shell_page.dart:5048–5625` (payload replay + validation) | absent | — | — |

#### Page: v1 `OrganizationPage` (pushed via `Navigator.push` from `app_shell.dart:1049`)

| Feature | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| Hierarchy tree view (expandable) | present | `lib/ui/organization_page.dart:314–485` (`_hierarchyTreeView`, `_personCard` with expand/collapse at `:412`) | absent | — | — |
| By-division grouping view | present | `lib/ui/organization_page.dart:514–597` (`_byDivisionView`, `_divisionGroup` at `:550`) | absent | — | — |
| Organization summary stats (owner / ops manager / divisions / teams) | present | `lib/ui/organization_page.dart:216–310` (`_summaryStatsRow`, `_orgStatCard`) | absent | — | — |
| Tree node expand / collapse | present | `lib/ui/organization_page.dart:410–420` (GestureDetector + `setState` on `person.expanded`) | absent | — | — |

### 4.5 Feature row counts

| Batch | Pages | Feature rows |
|---|---|---|
| A — Command Center + `/agent` | 7 | 51 |
| B — Operations | 6 | 61 |
| C — Governance / Evidence / System + v1-only extras | 7 | 55 |
| **Total** | **20** | **167** |

167 rows. Above the upper-bound target (80–150) set in the brief; the overrun is driven by `/dispatches` (13 rows), `/events` (13), `/reports` (11), `/governance` (14), `/admin` (10), and `/clients` (10). These were pages where v1 shipped many named feature surfaces that have no v2 counterpart — each such surface is a row. A deliberate collapse below 150 would have required merging multiple v1 features per row, which would have lost file:line evidence precision. Noted; no action taken per the audit-rules rule "no judgement."

---

## 5. Cross-cutting concerns

One row per concern. Status values per column use the same vocabulary as §4 (`present`, `present_stub`, `absent`, `unverified`). "Evidence" is the file path + line or function name that establishes the status.

| Concern | v1 status | v1 evidence | v2 status | v2 evidence | Notes |
|---|---|---|---|---|---|
| **Authentication flow (login, session, logout)** | present | `lib/ui/controller_login_page.dart` (5 features documented in §4.4); mounted as pre-router `home:` at `lib/main.dart:34521`; `onAuthenticated` callback switches to `MaterialApp.router`. `lib/main.dart:842–848` initialises `Supabase` when `ONYX_SUPABASE_URL`/`SUPABASE_ANON_KEY` are set, otherwise falls back to in-memory ledger | absent | No `middleware.ts` anywhere (`find . -maxdepth 3 -name middleware.ts` returns empty); `app/providers.tsx:11–40` wraps only `QueryClientProvider` — no auth provider; `lib/supabase/server.ts` exists (29 LOC) but is not imported by any `app/api/**` handler (phase 1a §6.1) | v2 audit cross-cutting #1: "if you can reach the origin, you can read and triage every incident." |
| **Route guards / middleware** | present | GoRouter `refreshListenable` bridge at `lib/routing/onyx_router.dart:50`; `MaterialApp(home: ControllerLoginPage)` gates router instantiation at `lib/main.dart:34521` | absent | No `middleware.ts`; API handlers use same-origin header check only (phase 1a §6.1) | — |
| **Theme (dark mode, accent, typography)** | present | MaterialApp.router at `lib/main.dart:34529`; inline color constants (`Color(0xFF9D4BFF)` brand, `Color(0xFFF59E0B)` amber, `Color(0xFF63E6A1)` green at `lib/main.dart:21568–21620`, among ~100 similar constants); single theme (no dark-mode toggle surface found) | present | `app/globals.css` + `app/primitives.css` + `app/shell.css` (all imported by `app/layout.tsx:4`); Tailwind v4 `@theme` directive per v2 audit; single dark theme; no toggle surfaced (Zara home offers *accent* swatch toggle at `app/_components/ZaraClient.tsx` — UI-state only). Fonts Inter + JetBrains_Mono wired at `app/layout.tsx:2,6–14` | Both single-theme; v2 uses CSS-native tokens, v1 uses inline Dart `Color` constants. |
| **Responsive / mobile layout** | present | `lib/ui/app_shell.dart:342–570` uses `LayoutBuilder` with breakpoints `< 420` / `< 980` (mobile drawer via `Scaffold.openDrawer` at `:407`) / `>= 1280` / `>= 1320` / `>= 1440` / `>= 1500` / `>= 1580` / `>= 1760`; `lib/ui/guard_mobile_shell_page.dart` is the guard-side alternate shell | unverified | No per-page layout files; no explicit JS-level breakpoint hooks observed in `components/shell/*`; responsive behaviour (if any) is CSS-only via `app/shell.css` / `primitives.css` — not inspected in this pass | v1 has explicit breakpoint-driven layout switching; v2 likely relies on CSS media queries (unverified). |
| **Real-time subscriptions (Supabase channels vs polling)** | present | Supabase realtime channels on at least two surfaces: `lib/ui/alarms_page.dart:212,281–288` (`RealtimeChannel? _realtimeChannel; … .channel('alarms-page-incidents').onPostgresChanges(...).subscribe()`) and `lib/main.dart:1793,35154–35183` (`_tacticalGuardPositionsChannel`, `channel('tactical-map-$scopeKey').onPostgresChanges(...).subscribe()`) | present_stub | All 16 v2 pages use TanStack Query `useQuery` with `refetchInterval` (phase 1a §6.1 + v2 audit polling cadences 5s–5m). No `supabase.channel(...)` / `.subscribe()` call observed anywhere in `app/**/_components/*.tsx` or `lib/supabase/queries/*.ts`. Status `present_stub` because the capability is polling-backed rather than realtime — data does refresh, but via a different mechanism. | v1 uses Supabase realtime where freshness matters (alarms, tactical) and polling elsewhere; v2 uses polling everywhere. |
| **Error boundaries and error toasts** | present | `ScaffoldMessenger.of(context).showSnackBar(...)` used ≥ 6 times for error surfacing in `lib/main.dart:37614,37697,37773,37815,37847,37869`; Flutter's default `ErrorWidget.builder` applies globally | present | Per-route `error.tsx` on 6 of 16 routes (`/alarms`, `/clients`, `/events`, `/guards`, `/ledger`, `/sites` — see §2.5); `app/alarms/error.tsx:14–...` pattern: `useEffect(() => console.error(...))` + `Shell` wrapper + reset button; `/alarms` additionally has a client-side toast stack at `app/alarms/_components/AlarmsClient.tsx:338–346` (`role="status" aria-live="polite"`). 10 routes have no per-route error boundary — they fall back to the default Next.js handler (no `app/error.tsx` at the root; `find app -maxdepth 1 -name "error.tsx"` returns empty) | — |
| **Loading states** | present | Inline per-page loading — `FutureBuilder` / `CircularProgressIndicator` usage throughout (not enumerated) | present | Per-route `loading.tsx` on the same 6 routes above (`/alarms/loading.tsx:4–...` renders a `Shell`-wrapped skeleton). 10 routes have no per-route loading boundary. | — |
| **Navigation (sidebar, header, breadcrumbs)** | present | `lib/ui/app_shell.dart` (2277 LOC) renders the ShellRoute chrome: nav rail grouped by `OnyxRouteSection` (5 sections), shell header label from `route.shellHeaderLabel`, shell badges from `shellBadgeKind` / `shellBadgeColor`. Sections come from `OnyxRoute.section` at `lib/domain/authority/onyx_route.dart:39–185` | present | `components/shell/Shell.tsx` (46 LOC) → `Rail.tsx` (63) + `Topbar.tsx` (82) + `HeartbeatChip.tsx` (15). Nav is a flat array of 16 entries in `components/shell/nav.ts`; `activeIdForPathname(pathname)` in the same file picks the active nav id by longest-prefix match. No section headers, no badge counts. | v1 has section grouping + badges; v2 is flat + no badges. Both have one global shell (v1 via ShellRoute, v2 via root layout). |
| **Deep linking / URL state** | present | `/events?origin=&label=` deep-link round-trip encoded by `lib/routing/onyx_router.dart:133–172` (`_eventsOriginFromUri`, `_eventsOriginLabelFromUri`, `_eventsRouterLocation`); scope-rail back-link chip renders the decoded origin (§4.2 `/events` row) | present | URL-persisted selection on 4 routes — `?site=` on `/track` (`TrackClient.tsx:126–132`), `?principal=` on `/vip` (`VIPClient.tsx:644,744–752`), `?dispatch=` on `/dispatches` (`DispatchesClient.tsx:395–399`), `?task=` on `/ai-queue` (`AIQueueClient.tsx:321–325`). No equivalent to v1's `origin=&label=` back-link chip encoding on `/events`. | — |
| **Keyboard shortcuts** | absent | Grep for `RawKeyboardListener`, `Shortcuts`, `LogicalKeySet`, `HardwareKeyboard` in `lib/main.dart` returned no matches. The `buildReviewShortcuts(...)` calls at `lib/main.dart:8248,8428,9818,10103,24516,24763` are text command / review-history hint strings, not Flutter keyboard bindings. | absent | Single `onKeyDown` handler: `app/alarms/_components/AlarmCard.tsx:67` (alarm-card keyboard activation). No global hotkey registration in `components/shell/*` or `app/providers.tsx`. | Both effectively absent beyond default framework behaviour. |
| **Accessibility (focus, aria, semantic widgets)** | unverified | No `Semantics(...)` widget usage found in `lib/main.dart` via grep (though Flutter's default widgets carry semantic info automatically) | present_stub | Sparse but present: `aria-label="Primary"` on nav rail (`components/shell/Rail.tsx:23`), `aria-current="page"` on active nav link (`:52`), `aria-label="ONYX home"` on logo (`:24`), `role="status" aria-live="polite"` on alarm toast stack (`app/alarms/_components/AlarmsClient.tsx:339`). No systematic focus-management code observed in `components/shell/*` or `app/providers.tsx`. Status `present_stub` because a handful of attributes exist but there is no project-wide aria/focus discipline evidenced. | Not re-audited in depth — reserved for phase 2 accessibility review if scoped. |

### 5.1 Table summary

| Concern | v1 ↔ v2 |
|---|---|
| Auth | v1 `present` / v2 `absent` (gap) |
| Route guards | v1 `present` / v2 `absent` (gap) |
| Theme | both `present` |
| Responsive | v1 `present` / v2 `unverified` |
| Real-time | v1 `present` (channels) / v2 `present_stub` (polling substitute) |
| Error boundaries / toasts | both `present` (different shapes) |
| Loading states | both `present` |
| Navigation | both `present` (v1 sectioned+badged, v2 flat) |
| Deep linking | both `present` (v1 richer on `/events`) |
| Keyboard | both `absent` |
| Accessibility | v1 `unverified` / v2 `present_stub` |

---

*§6 (shared-code findings) pending.*
