Revise the ONYX review design so it is implementation-ready for the real app, not just visually strong.

Keep the current visual direction, tone, and overall quality:
- premium command-center look
- dark operational theme
- strong KPI cards
- crisp left navigation
- clear page headers
- high-trust, high-signal interface

Do not redesign from scratch. This is a revision pass to close the gap between the current design and the real ONYX app behavior.

Primary goal:
Preserve the current visual language, but expand the design so it fully supports the deeper operational states and workflows already present in the app.

Important principle:
The current exported design is strong visually, but it is still too shallow in some workflows. This pass must add missing states, control patterns, and drilldown behavior without losing clarity.

Revise these pages/components:

1. Live Operations / Operations
This is the highest-priority revision area.
Add full design coverage for:
- queue-state modes:
  - full queue
  - high priority only
  - exact cue filters like timing only / sensitive only / validation only
- top-bar priority chip
- top-bar queue-state chip
- queue-shape summary pills
- filtered state chips and restore-to-full behavior
- control inbox draft cards with cue chips
- draft refine dialog
- live-updating review cue inside refine dialog
- selected lane watch states
- active incident comms pulse
- empty inbox state
- filtered queue state
- timing-only state
- sensitive-only state
- cross-scope/off-scope queue items
- first-run queue hint and “show tip again” state
- high-priority reply jump behavior
- explicit severity wording like sensitive reply vs high-priority reply

Keep the existing composition style, but make this page operationally complete.

2. Tactical
Add full watch-health state coverage:
- available watch
- limited watch
- unavailable watch
- limited-watch reason detail
- stale feed / degraded connectivity / fetch failure / manual verification needed
- recover watch action
- fleet summary chips including limited
- fleet card sublabels for limited reasons
- route-to-dispatch and route-to-tactical fleet drilldowns
- temporary identity approval actions:
  - extend
  - expire

The current tactical design is visually good but too map/generic. It needs ONYX fleet-watch operational depth.

3. Clients
Revise the client operations / client lane design to support:
- Telegram blocked state
- SMS fallback active state
- VoIP stage history
- push sync history
- push sync needs review state
- backend probe status/history
- pending AI draft visibility
- learned approval style display
- pinned voice / ONYX mode display
- multi-room / thread awareness
- off-scope routed lane state
- delivered / queued / blocked / draft states

Keep it clean and client-safe, but make it match the real communication system complexity.

4. Admin
This is the second major revision area after Live Operations.
Expand the design to support:
- system tab depth
- client comms audit
- pending AI draft review
- learned approval style section
- top learned style + next learned options
- promote / demote learned styles
- tag learned styles
- suggested tags
- context-aware profile suggestions
- pinned voice controls
- review cues
- live ops queue hint reset controls
- success / failure / busy feedback states
- runtime/system controls
- watch-action drilldown states
- identity policy / identity audit controls

The exported admin design is currently too much of a simple entity management panel. It must become a true ONYX operations-admin surface.

5. Governance
Keep the visual style, but add design coverage for:
- morning sovereign report
- report history
- readiness blockers vs non-blockers
- partner dispatch chains
- scope and partner-scope filtering
- governance-to-events drilldowns
- governance-to-reports drilldowns
- evidence/compliance summary states

6. Dispatches
Keep the command-board feel, but add design coverage for:
- ingest controls
- live polling controls
- radio queue controls
- telemetry and benchmarking controls
- wearable / radio / video readiness sections
- fleet watch drilldowns
- partner dispatch / report-opening interactions

7. Reports
Expand the report design to support:
- report shell / preview states
- report receipts
- deterministic generation controls
- partner scope reports
- governance and event drill-ins
- scene review / evidence context

8. Shell and Navigation
Revise the shell to match the real app route structure exactly:
- Operations
- AI Queue
- Tactical
- Governance
- Clients
- Sites
- Guards
- Dispatches
- Events
- Ledger
- Reports
- Admin

Add support for:
- scope breadcrumbs
- incident/context continuity
- cross-route drilldown states
- clearer distinction between global nav and page-specific controls

Required state coverage across the revised design:
- loading
- empty
- no incident selected
- no scoped site selected
- no drafts
- blocked Telegram
- SMS fallback active
- VoIP staged
- push sync needs review
- limited watch
- unavailable watch
- backend probe failed
- backend probe idle
- filtered queue
- cross-scope/off-scope surfaced items
- admin success/failure/busy states

Component work needed:
Revise or add reusable components for:
- queue-state chips
- queue-shape pills
- priority chips
- cue chips
- fleet watch badges
- limited-watch reason sublabels
- learned-style cards
- pinned voice controls
- draft review cards
- audit cards
- refined detail drawers / modals
- stronger operational tables and timeline cards

Output requested:
Please update the design so it is implementation-ready for the real ONYX app.
Provide:
- revised versions of the affected pages
- added missing states
- explicit variants for the key workflows above
- a small annotation page calling out the new operational states added in this revision

Very important:
Do not remove depth from the product.
Do not simplify away operations behavior for aesthetic cleanliness.
This revision should keep the current look, but make it truly complete.
