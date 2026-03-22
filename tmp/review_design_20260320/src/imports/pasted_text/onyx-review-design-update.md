Please revise the ONYX review design again.

This is not a redesign from scratch. Keep the current visual direction and the recent improvements, especially the stronger Live Operations and Admin work. The goal now is to complete the remaining route and state gaps so the design is implementation-ready for the real app.

Keep:
- the premium command-center tone
- the dark operational theme
- the current shell direction
- the improved queue/draft/admin visual language
- the stronger reusable operational components

Do not remove depth.
Do not simplify workflows.
Do not replace operational detail with generic dashboard cards.

Current status:
- Live Operations is much closer
- Admin is much closer
- the remaining pages still need more operational depth to match the real ONYX app

Please revise these areas page by page:

1. Tactical
This is the next highest-priority page after Live Operations and Admin.

Keep:
- tactical map
- responder ping concept
- geofence visual language
- side detail panel

Add:
- fleet watch cards
- fleet summary row
- watch health variants:
  - available watch
  - limited watch
  - unavailable watch
- limited-watch reason detail
- stale feed state
- degraded connectivity state
- fetch failure state
- manual verification required state
- recover watch action
- route-to-dispatch and route-to-tactical fleet drilldowns
- temporary identity approval controls:
  - extend
  - expire
- mixed fleet state examples

Need explicit visual states for:
- healthy fleet
- mixed fleet with limited coverage
- unavailable watch
- one site needing manual verification

2. Clients
This page still needs major operational depth.

Keep:
- client/site selector
- incident feed direction
- summary cards
- overall cleaner client-lane look

Add:
- room/thread awareness
- pending AI draft state
- learned approval style state
- pinned voice / ONYX mode state
- push sync status
- push sync history
- Telegram blocked state
- SMS fallback state
- VoIP staged state
- backend probe state/history
- off-scope routed lane state
- delivered / queued / blocked / draft message states
- direct client communication workflow states

Need explicit variants for:
- healthy lane
- Telegram blocked
- SMS fallback active
- VoIP staged
- pending AI draft awaiting review
- off-scope routed lane
- push sync needs review

3. Dispatches
Keep:
- command-board feel
- active dispatch queue visual language
- strong priority hierarchy

Add:
- ingest controls
- live polling controls
- radio queue controls
- telemetry controls
- stress / soak / benchmark controls
- selected intelligence and filters
- pinned/dismissed intelligence states
- wearable readiness
- radio readiness
- video readiness
- fleet watch drilldown states
- partner dispatch workflow
- open-report workflow

Need explicit variants for:
- quiet queue
- active queue
- queue under pressure
- live polling active
- telemetry-heavy control state

4. Governance
Keep:
- strong compliance visual tone
- severity framing

Add:
- morning sovereign report view
- historical report view
- readiness blockers vs non-blockers
- partner dispatch chain view
- scope filters
- partner-scope filters
- governance-to-events drilldown
- governance-to-reports drilldown
- compliance/evidence summary states

Need explicit variants for:
- clean readiness
- blocker present
- partner chain populated
- report-focused governance

5. Reports
Keep:
- report workbench structure
- receipt list
- generation controls

Add:
- report shell / preview states
- report preview workflow
- partner-scope reporting
- scene review / evidence context
- governance drill-in
- events drill-in
- verified / pending / failed output states

Need explicit variants for:
- ready
- generating
- verified
- pending verification
- failed output

6. Guards
Keep:
- roster direction
- guard profile direction
- performance panel idea

Add:
- sync health emphasis
- schedule action
- reports action
- open client lane action
- stage VoIP call action
- stronger workforce operational state language

Need explicit variants for:
- healthy guard roster
- sync issue state
- action-ready selected guard
- site-filtered roster

7. Sites
Keep:
- site roster + selected site workspace
- site posture direction

Add:
- tactical map open action
- site settings action
- guard roster action
- stronger deployment/watch posture
- site health variants
- clearer status models tied to operations

Need explicit variants for:
- strong site
- at-risk site
- critical site
- no site selected

8. Events
Keep:
- timeline + detail split
- forensic review style
- filter strip direction

Add:
- scoped event-set review
- selected event emphasis
- governance drill-in
- ledger drill-in
- immutable audit context
- stronger payload/detail treatment

Need explicit variants for:
- all events
- filtered events
- selected forensic event
- scoped review mode

9. Ledger
Keep:
- sovereign ledger feel
- integrity summary
- timeline/detail structure

Add:
- incident-focused ledger state
- scope-focused ledger state
- stronger verification state variants
- provenance navigation
- event-linked evidence chain relationships

Need explicit variants for:
- chain intact
- pending verification
- compromised / alert state
- focused incident ledger review

10. App Shell / Global Continuity
Revise the shell so it fully matches the real route set:
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
- better page-level action zoning
- cross-route continuity for selected client/site/incident

Please also make sure the revised component system includes reusable patterns for:
- watch badges
- limited-watch reason labels
- fleet summary chips
- comms state chips
- push sync status blocks
- learned-style cards
- pending draft cards
- queue-state chips
- priority chips
- audit cards
- timeline rows
- verification states

State coverage still required across the remaining design:
- loading
- empty
- no incident selected
- no site selected
- Telegram blocked
- SMS fallback active
- VoIP staged
- push sync needs review
- backend probe failed
- backend probe idle
- limited watch
- unavailable watch
- filtered queue
- cross-scope surfaced items

Important:
The current revised design is now strong enough in Live Operations and Admin to use as reference.
Please keep those pages aligned with the new direction and focus this revision on the remaining routes and missing states.

Output requested:
- revised page designs for Tactical, Clients, Dispatches, Governance, Reports, Guards, Sites, Events, and Ledger
- missing state variants for those pages
- reusable component variants needed by those pages
- one short annotation page listing what was added in this revision
