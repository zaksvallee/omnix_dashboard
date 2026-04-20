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

*§2 (v2 Next.js UI page inventory) pending — to be committed separately per per-section rule.*
