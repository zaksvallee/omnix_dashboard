# ONYX Review Design Gap Checklist

This note compares the exported review design from:

- `/Users/zaks/Downloads/Review Design-3.zip`

against the current ONYX Flutter app surfaces in this repo.

It is intended to answer one question clearly:

- what can be adopted directly as visual direction
- what still needs design coverage because the real app is behaviorally richer

## Source Mapping

The design export includes these route pages:

- `LiveOperations`
- `AIQueue`
- `TacticalMap`
- `Governance`
- `Dispatches`
- `Guards`
- `Sites`
- `Clients`
- `Events`
- `Ledger`
- `Reports`
- `Admin`

The current Flutter app maps those ideas to:

- [live_operations_page.dart](/Users/zaks/omnix_dashboard/lib/ui/live_operations_page.dart)
- [ai_queue_page.dart](/Users/zaks/omnix_dashboard/lib/ui/ai_queue_page.dart)
- [tactical_page.dart](/Users/zaks/omnix_dashboard/lib/ui/tactical_page.dart)
- [governance_page.dart](/Users/zaks/omnix_dashboard/lib/ui/governance_page.dart)
- [dispatch_page.dart](/Users/zaks/omnix_dashboard/lib/ui/dispatch_page.dart)
- [guards_page.dart](/Users/zaks/omnix_dashboard/lib/ui/guards_page.dart)
- [sites_page.dart](/Users/zaks/omnix_dashboard/lib/ui/sites_page.dart)
- [client_app_page.dart](/Users/zaks/omnix_dashboard/lib/ui/client_app_page.dart)
- [clients_page.dart](/Users/zaks/omnix_dashboard/lib/ui/clients_page.dart)
- [events_review_page.dart](/Users/zaks/omnix_dashboard/lib/ui/events_review_page.dart)
- [sovereign_ledger_page.dart](/Users/zaks/omnix_dashboard/lib/ui/sovereign_ledger_page.dart)
- [client_intelligence_reports_page.dart](/Users/zaks/omnix_dashboard/lib/ui/client_intelligence_reports_page.dart)
- [admin_page.dart](/Users/zaks/omnix_dashboard/lib/ui/admin_page.dart)

## Global Assessment

The export is strong on:

- overall shell styling
- visual hierarchy
- premium command-center tone
- KPI card language
- dark operational theme
- route-level page concepts

The export is incomplete on:

- deep state coverage
- cross-route continuity
- draft review behavior
- learned voice / Telegram comms tooling
- fleet watch degradation states
- persistence-driven drilldowns
- evidence / governance depth

Recommendation:

- use the export as a visual system and layout direction
- do not treat it as a full feature spec
- preserve current ONYX behavior and extend the design to cover it

## Shell And Navigation

Design export strength:

- polished shell
- strong left rail
- credible operational brand treatment
- cleaner page-header rhythm than the current app in some places

Design gaps:

- export shell labels do not fully match current ONYX route structure
- current app has explicit routes for `AI Queue`, `Tactical`, `Governance`, `Clients`, `Sites`, `Guards`, `Dispatches`, `Events`, `Ledger`, `Reports`, and `Admin`
- current app also supports scope-driven route jumps and cross-route incident continuity through [main.dart](/Users/zaks/omnix_dashboard/lib/main.dart)

Checklist:

- redesign the shell using the export’s visual language
- keep the real route set from [main.dart](/Users/zaks/omnix_dashboard/lib/main.dart)
- add visual support for scope breadcrumbs, route drilldowns, and focus continuity

## Operations / Live Operations

Current app source:

- [live_operations_page.dart](/Users/zaks/omnix_dashboard/lib/ui/live_operations_page.dart)

Export covers:

- top KPIs
- critical banner
- active scope banner
- control inbox
- client lane watch
- sovereign ledger panel

Missing from export:

- queue-state chip modes: full, high priority, exact cue filters
- queue-shape interactive pills
- top-bar high-priority reply jump behavior
- filtered-state chips and restore behavior
- exact cue filtering across queue views
- first-run queue hint and reset behavior
- learned-lane cue text and draft review guidance
- draft refine dialog with live-updating cue
- cue chips on draft headers
- severity-specific priority labels like `Sensitive Reply`
- high-priority-only queue mode and breadcrumb state

Checklist:

- preserve the export’s overall composition
- redesign the control inbox using the real queue behaviors
- explicitly design all queue states already implemented in [live_operations_page.dart](/Users/zaks/omnix_dashboard/lib/ui/live_operations_page.dart)
- include empty, filtered, timing, sensitive, and cross-scope inbox states

## AI Queue

Current app source:

- [ai_queue_page.dart](/Users/zaks/omnix_dashboard/lib/ui/ai_queue_page.dart)

Export covers:

- strong featured automation card
- countdown / intervention concept
- queue framing
- AI-active posture

Missing from export:

- richer ONYX triage behavior and scoped event opening
- historical synthetic/shadow labels
- route-to-events workflow
- stronger filter, review, and queue-state variations

Checklist:

- keep the export’s strong hero treatment
- expand it to include ONYX triage filters and review states
- add explicit event drill-in and queue state coverage

## Tactical

Current app source:

- [tactical_page.dart](/Users/zaks/omnix_dashboard/lib/ui/tactical_page.dart)
- [video_fleet_scope_health_view.dart](/Users/zaks/omnix_dashboard/lib/ui/video_fleet_scope_health_view.dart)
- [video_fleet_scope_health_sections.dart](/Users/zaks/omnix_dashboard/lib/ui/video_fleet_scope_health_sections.dart)

Export covers:

- map-centric tactical layout
- responder pings
- geofence alert framing
- tactical chips and side detail

Missing from export:

- fleet health drilldowns
- limited watch vs unavailable watch vs available watch semantics
- limited-watch reason details
- recover watch actions
- temporary identity approval actions
- fleet summary chips including limited state
- route-to-dispatch / route-to-tactical fleet interactions

Checklist:

- preserve the export’s tactical visual energy
- replace generic guard/map-only patterns with ONYX fleet watch cards and watch badges
- explicitly design limited-watch and degraded-monitoring states

## Governance

Current app source:

- [governance_page.dart](/Users/zaks/omnix_dashboard/lib/ui/governance_page.dart)

Export covers:

- compliance issues
- severity framing
- a governance/control surface concept

Missing from export:

- morning sovereign report workflows
- partner dispatch chains
- readiness / blocker separation
- scope and partner-scope filtering
- export-oriented evidence summaries
- governance-to-events / governance-to-reports links

Checklist:

- keep the export’s simpler compliance visuals as the top layer
- add the much deeper report, partner, and readiness states from [governance_page.dart](/Users/zaks/omnix_dashboard/lib/ui/governance_page.dart)

## Dispatches

Current app source:

- [dispatch_page.dart](/Users/zaks/omnix_dashboard/lib/ui/dispatch_page.dart)

Export covers:

- dispatch queue concept
- active dispatch cards
- strong action-led framing

Missing from export:

- ingest controls
- radio queue controls
- live polling controls
- telemetry/stress/benchmark tooling
- fleet watch drilldowns
- wearable/video/radio readiness blocks
- partner dispatch and report-opening workflows

Checklist:

- use the export for the core command-board visual language
- retain the real app’s operational tooling density
- add explicit layouts for ingest/polling/telemetry panels rather than hiding them

## Guards

Current app source:

- [guards_page.dart](/Users/zaks/omnix_dashboard/lib/ui/guards_page.dart)

Export covers:

- workforce roster concept
- performance stats
- site filter direction

Missing from export:

- ONYX guard route actions such as opening schedules, reports, client lane, and staging VoIP calls
- sync health emphasis
- route crossover to site/client workflows

Checklist:

- keep the export’s roster clarity
- add guard action surfaces and sync-health affordances from the real page

## Sites

Current app source:

- [sites_page.dart](/Users/zaks/omnix_dashboard/lib/ui/sites_page.dart)
- [sites_command_page.dart](/Users/zaks/omnix_dashboard/lib/ui/sites_command_page.dart)

Export covers:

- site roster
- selected-site operational workspace
- posture-style summary

Missing from export:

- command-style site actions in the real app
- tactical map handoff
- settings / guard-roster / site-ops opening affordances
- stronger deployment / watch context

Checklist:

- keep the export’s roster + detail split
- align actions with the real ONYX command flows

## Clients

Current app source:

- [client_app_page.dart](/Users/zaks/omnix_dashboard/lib/ui/client_app_page.dart)
- [clients_page.dart](/Users/zaks/omnix_dashboard/lib/ui/clients_page.dart)

Export covers:

- client/site selector
- incident feed
- summary panels
- cleaner top-level client lane composition

Missing from export:

- room/thread behavior
- learned approval style
- pinned voice / ONYX mode
- pending AI draft handling
- push sync history
- Telegram blocked states
- SMS fallback
- VoIP stage history
- backend probe status/history
- cross-scope lane routing nuances

Checklist:

- use the export as a visual simplification pass
- do not lose current client-lane communication depth
- design explicit states for Telegram blocked, SMS fallback, VoIP staged, review-needed push sync, and pending drafts

## Events

Current app source:

- [events_review_page.dart](/Users/zaks/omnix_dashboard/lib/ui/events_review_page.dart)
- [events_page.dart](/Users/zaks/omnix_dashboard/lib/ui/events_page.dart)

Export covers:

- event review split view
- filter strip
- sequence-oriented forensic reading

Missing from export:

- richer scoped event-set handling
- governance and ledger drill-ins
- broader immutable timeline context
- shadow / scope-mode behaviors

Checklist:

- keep the export’s strong timeline/detail split
- add explicit support for scoped event focus and downstream drill-ins

## Ledger

Current app source:

- [sovereign_ledger_page.dart](/Users/zaks/omnix_dashboard/lib/ui/sovereign_ledger_page.dart)

Export covers:

- evidence-chain framing
- integrity summary
- entry detail model

Missing from export:

- real ONYX sovereign ledger scope filtering
- event-driven evidence linking
- incident focus continuity
- deeper provenance navigation

Checklist:

- export is a strong base here
- preserve audit-grade structure while wiring in the richer ONYX scope/focus model

## Reports

Current app source:

- [client_intelligence_reports_page.dart](/Users/zaks/omnix_dashboard/lib/ui/client_intelligence_reports_page.dart)
- [reports_page.dart](/Users/zaks/omnix_dashboard/lib/presentation/reports_page.dart)

Export covers:

- output mode
- generation controls
- report receipts
- verification language

Missing from export:

- report shell state behavior
- preview request flow
- governance/event drill-ins
- partner-scope reporting
- scene review integration

Checklist:

- use the export’s report-workbench layout
- extend it to support ONYX preview shell and report drill-ins

## Admin

Current app source:

- [admin_page.dart](/Users/zaks/omnix_dashboard/lib/ui/admin_page.dart)

Export covers:

- admin tabs
- entity management patterns for guards/sites/clients
- baseline settings surface

Missing from export:

- system tab depth
- client comms audit
- pending AI draft review
- learned style management
- pinned voice management
- tag suggestions and ordering
- live-ops queue tip reset controls
- watch-action drilldown persistence
- identity rule audit tooling
- runtime/demo controls

Checklist:

- treat the export Admin page as a base admin management shell
- separately design the current ONYX system/comms/runtime control surfaces from [admin_page.dart](/Users/zaks/omnix_dashboard/lib/ui/admin_page.dart)

## Highest-Risk Design Gaps Before Implementation

These need explicit design work before we push a broad widget refresh:

- live-ops queue states and exact filter modes
- limited-watch / unavailable-watch fleet health states
- Telegram / SMS / VoIP / push-sync communication states
- learned approval style and pinned voice control surfaces
- governance report depth and partner dispatch chains
- dispatch operational tooling density

## Safe First Implementation Slice

The lowest-risk visual refresh path is:

1. adopt the exported shell language and visual system
2. refresh top-level route headers, cards, and spacing
3. refresh Live Operations, Clients, and Tactical first
4. keep current real behaviors intact underneath
5. only then expand the design to deeper admin/governance/dispatch states

## Implementation Recommendation

Do not replace the current app route-for-route from the export.

Instead:

- use the export as the aesthetic and layout reference
- create missing state designs for the richer ONYX behaviors
- implement the redesign incrementally, route by route
- validate each route against both the export and the current feature set
