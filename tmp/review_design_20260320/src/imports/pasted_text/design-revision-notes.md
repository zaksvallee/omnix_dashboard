Revise the ONYX review design page by page. Keep the current visual language, but add the missing operational depth and state coverage listed below.

Global instruction:
Do not redesign from scratch.
Do not simplify workflows.
Keep the current premium command-center look.
This is a completeness pass so the design matches the real app.

1. App Shell / Navigation
Revise the shell to support the real route set exactly:
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

Add:
- scope breadcrumbs
- stronger route context
- better distinction between global nav and page-level controls
- support for cross-route drilldown continuity
- support for focused client/site/incident context

2. Operations / Live Operations
This is the top priority page.

Keep:
- KPI cards
- critical alert banner
- active scope banner
- control inbox
- client lane watch
- ledger/evidence side panel feel

Add or revise:
- queue-state chips:
  - full queue
  - high priority
  - timing only
  - sensitive only
  - validation only
- top-bar priority chip
- top-bar queue-state chip
- queue-shape pill summary
- filtered-state chip and note
- “show all replies” restore action
- draft cards with cue chips
- cue types:
  - timing
  - sensitive
  - validation
  - detail
  - reassurance
  - concise
  - next step
  - formal
- draft refine dialog
- live-updating review cue inside refine dialog
- active incident comms pulse
- selected lane watch panel
- empty inbox state
- filtered queue state
- cross-scope surfaced items
- first-run queue hint state
- “show tip again” state
- high-priority jump-to-inbox behavior
- sensitive vs generic high-priority badge language

Need variants for:
- no pending replies
- one timing draft
- one sensitive draft
- mixed queue
- filtered exact-cue queue
- high-priority-only queue

3. AI Queue
Keep:
- active automation hero card
- queue framing
- intervention timer concept
- AI-active status language

Add or revise:
- clearer queue list states
- filter states
- review states
- safe suggestion vs urgent suggestion vs dismissed
- event drill-in affordance
- confidence / intent / action clarity
- historical AI/shadow state support
- better operator intervention controls

Need variants for:
- active automation
- no active automation
- multiple queued actions
- dismissed / reviewed item states

4. Tactical
Keep:
- tactical map feel
- responder ping concept
- geofence alert concept
- side detail panel

Add or revise:
- fleet watch cards
- watch badges
- available watch state
- limited watch state
- unavailable watch state
- limited-watch reason detail
- stale feed state
- degraded connectivity state
- fetch failure state
- manual verification required state
- fleet summary chips
- limited summary chip
- recover watch action
- route to dispatch / route to tactical from fleet state
- temporary identity approval actions:
  - extend
  - expire

Need variants for:
- healthy watch
- limited watch
- unavailable watch
- mixed fleet summary

5. Governance
Keep:
- compliance / control visual direction
- severity framing

Add or revise:
- morning sovereign report view
- historical report view
- readiness blockers vs non-blockers
- partner dispatch chain view
- scope filters
- partner-scope filters
- governance-to-events drilldown
- governance-to-reports drilldown
- evidence / compliance summary states

Need variants for:
- clean readiness
- blocker present
- partner workflow populated
- report-focused governance view

6. Dispatches
Keep:
- command-board feel
- active dispatch queue style
- priority-driven visual hierarchy

Add or revise:
- ingest controls
- live polling controls
- radio queue controls
- telemetry controls
- stress / soak / benchmark controls
- wearable readiness
- radio readiness
- video readiness
- fleet watch drilldown
- partner dispatch interactions
- open report interaction
- selected intelligence / filters / triage states

Need variants for:
- quiet queue
- active dispatch queue
- pending queue pressure
- ingest / live polling active
- telemetry-heavy view

7. Guards
Keep:
- roster concept
- guard profile concept
- performance panel concept

Add or revise:
- sync health emphasis
- guard schedule action
- guard reports action
- open client lane action
- stage VoIP call action
- stronger field-force operational state language

Need variants for:
- all healthy
- sync issues
- action-ready guard
- site-filtered view

8. Sites
Keep:
- site roster + selected site workspace
- site posture summary direction

Add or revise:
- tactical map open action
- site settings action
- guard roster action
- stronger deployment / watch posture display
- site health with operational context
- clearer status variants

Need variants for:
- strong site
- at-risk site
- critical site
- no site selected

9. Clients
Keep:
- client/site selector
- incident feed concept
- summary cards

Add or revise:
- room/thread awareness
- pending AI draft states
- learned approval style display
- pinned voice / ONYX mode display
- push sync state
- push sync history
- Telegram blocked state
- SMS fallback state
- VoIP stage state
- backend probe state/history
- cross-scope lane routing state
- delivered / queued / blocked / draft states
- direct client communication posture

Need variants for:
- healthy lane
- Telegram blocked
- SMS fallback active
- VoIP staged
- pending draft
- off-scope routed lane

10. Events
Keep:
- timeline + detail split
- filter strip
- forensic/event review feel

Add or revise:
- scoped event-set handling
- selected event emphasis
- governance drill-in
- ledger drill-in
- immutable timeline / audit context
- stronger event detail payload treatment

Need variants for:
- all events
- filtered events
- selected forensic event
- scoped event review mode

11. Ledger
Keep:
- sovereign ledger feel
- integrity summary
- ledger timeline/detail split

Add or revise:
- incident/scope focus states
- evidence-chain continuity
- deeper provenance navigation
- stronger verification states
- event-linked evidence relationships

Need variants for:
- chain intact
- pending verification
- compromised / alert state
- focused incident ledger review

12. Reports
Keep:
- report workbench structure
- receipt list
- generation controls

Add or revise:
- report shell / preview states
- report preview workflow
- partner-scope reporting
- scene review context
- governance drill-in
- event drill-in
- stronger verified / pending / failed output states

Need variants for:
- ready to generate
- generating
- verified report
- pending verification
- failed output

13. Admin
This is the second highest-priority revision after Live Operations.

Keep:
- admin entity management foundation
- tab structure concept

Add or revise:
- real system tab depth
- client comms audit
- pending AI draft review
- learned approval style panel
- top learned style
- next learned options
- promote / demote actions
- tag actions
- suggested tags
- context-aware suggestions
- pinned voice controls
- review cues
- live ops tip reset control
- success / failure / busy feedback states
- watch-action drilldown states
- identity rule audit states
- runtime control depth

Need variants for:
- no learned styles
- one learned style
- multiple learned styles
- pending draft review
- cross-scope comms audit
- reset tip success / failure / busy

Design-system/component punch list
Please make sure the revised design includes reusable components for:
- page headers
- KPI cards
- queue-state chips
- priority chips
- cue chips
- queue-shape pills
- fleet watch badges
- limited-watch reason sublabels
- learned-style cards
- audit cards
- draft cards
- detail drawers
- refine-draft modal
- timeline rows
- evidence/ledger rows
- admin action feedback states

State coverage required across the whole design
Make sure the revised design explicitly covers:
- loading
- empty
- no incident selected
- no site selected
- blocked Telegram
- SMS fallback active
- VoIP staged
- push sync needs review
- limited watch
- unavailable watch
- backend probe failed
- backend probe idle
- filtered queue
- cross-scope surfaced item
- success / failure / busy admin action feedback

Output needed
Please return:
- revised page designs for the pages above
- missing state variants
- component variants for the core operational chips/cards
- one short annotation page listing which missing operational states were added in this revision
