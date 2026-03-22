Please revise the current ONYX design export again, but only for the pages that still need more operational depth.

Do not redesign the whole system.
Keep the current direction of Live Operations and Admin as-is unless a small consistency tweak is needed.
This revision is only for the remaining incomplete pages and missing states.

Pages to revise:
- Tactical
- Clients
- Dispatches
- Governance
- Reports
- Guards
- Sites
- Events
- Ledger

Please add the following missing design coverage:

1. Tactical
Add:
- available watch
- limited watch
- unavailable watch
- limited-watch reason detail
- stale feed / degraded connectivity / fetch failure / manual verification needed
- recover watch action
- fleet summary chips
- limited summary chip
- temporary identity approval actions
- route-to-dispatch / route-to-tactical fleet drilldowns

2. Clients
Add:
- Telegram blocked state
- SMS fallback state
- VoIP staged state
- push sync history
- push sync needs review
- backend probe state/history
- pending AI draft state
- learned approval style state
- pinned voice / ONYX mode state
- off-scope routed lane state
- delivered / queued / blocked / draft communication states
- room/thread-aware communication layout

3. Dispatches
Add:
- ingest controls
- live polling controls
- radio queue controls
- telemetry / stress / soak / benchmark controls
- selected intelligence / filter states
- wearable / radio / video readiness sections
- fleet watch drilldowns
- partner dispatch workflow
- open report workflow

4. Governance
Add:
- morning sovereign report view
- historical report view
- readiness blockers vs non-blockers
- partner dispatch chain view
- scope filters
- partner-scope filters
- governance-to-events drilldown
- governance-to-reports drilldown
- evidence/compliance summary states

5. Reports
Add:
- report shell / preview workflow
- verified / pending / failed report states
- partner-scope report flow
- scene review / evidence context
- governance drill-in
- event drill-in

6. Guards
Add:
- sync health emphasis
- guard schedule action
- guard reports action
- open client lane action
- stage VoIP call action
- stronger workforce operational-state treatment

7. Sites
Add:
- tactical map open action
- site settings action
- guard roster action
- stronger site posture / watch-health treatment
- stronger site status variants

8. Events
Add:
- scoped event review mode
- stronger selected-event state
- governance drill-in
- ledger drill-in
- stronger forensic payload/detail treatment

9. Ledger
Add:
- incident-focused ledger state
- verification-state variants
- provenance/evidence-chain detail
- stronger evidence-linked navigation

Important:
Keep the current premium command-center visual language.
Do not simplify the product.
This is a completeness pass for the remaining routes only.

Output requested:
- revised versions of the pages above
- the missing state variants for those pages
- any reusable components needed for those pages
- one short annotation page listing exactly what was added in this pass
