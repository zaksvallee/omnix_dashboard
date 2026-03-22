Use this base prefix at the top of every prompt

Design for ONYX Sovereign Platform. Flutter implementation target. Dark theme only. No light mode. No extra features outside the requested page. Keep the existing ONYX visual language: deep navy backgrounds, cyan/emerald/red/amber status accents, high-density command UI, strong readability, touch-safe controls where required. Include component names, spacing rhythm, and state variants (loading, empty, error, active). Return a production-ready frame.
Controller - Live Operations
Create the ONYX Controller page: LIVE OPERATIONS (desktop only, 1440+ width).
Layout: 3-column command grid + bottom ledger strip.
Left: Incident Queue with priority ordering and active incident highlight.
Center: Action Ladder with step states (completed, active, thinking, pending, blocked) and manual override CTA.
Right: Incident Context with tabs (Details, VoIP, Visual) and guard vigilance card.
Bottom: Sovereign Ledger feed preview and Verify action.
Include top operational status bar and page-level metrics chips.
Variants: no incidents, multiple active incidents, P1 critical active, loading, error.
Controller - AI Queue
Create the ONYX Controller page: AI AUTOMATION QUEUE (desktop only).
Show one active automation card with large countdown timer and progress bar.
Primary controls: Cancel Action, Pause, Approve Now.
Below: queued actions list and execution timing.
Bottom stats row: total actions, executed, overridden, approval rate.
Add urgency styling by countdown phase (normal, warning, critical).
Variants: active automation, paused, empty queue, loading/error.
Controller - Dispatch Command
Create the ONYX Controller page: DISPATCH COMMAND (desktop only).
Sections: command posture stats, command actions, transport/intake controls, system status diagnostics, active dispatch queue.
Dispatch queue rows must show dispatch ID, site, response tags, state badge, primary action button.
System status panel should support dense diagnostics without visual clutter.
Variants: healthy operations, degraded telemetry, empty queue, loading/error.
Controller - Tactical Map
Create the ONYX Controller page: TACTICAL MAP (desktop only).
Left 8-column map canvas with guard pings, vehicles, incidents, geofence circles, route lines, SOS trigger banner.
Right 4-column verification lens: norm image vs live image, anomaly overlays, match score, anomaly list.
Top chips: active responders, geofence alerts, SOS count, mode/day window.
Map controls: zoom in/out, center active, filter status.
Variants: safe state, active breach/SOS, night/IR mode, loading/error.
Controller - Governance
Create the ONYX Controller page: GOVERNANCE (desktop only).
Sections:
1) Vigilance monitor with guard decay sparklines and status labels.
2) Compliance alerts list with expiry severity and DISPATCH BLOCKED badge.
3) Fleet readiness cards (vehicles/officers readiness split).
4) Morning sovereign report metrics block.
Include summary posture chips in header row.
Variants: healthy, at-risk, critical blockers, loading/error.
Controller - Events
Create the ONYX Controller page: EVENT REVIEW (desktop only).
Top summary cards (visible events, total events, latest sequence).
Filter strip with forensic filters and reset action.
Main split: timeline feed on left, selected event detail panel on right.
Timeline rows need type, sequence, site/guard tags, timestamp, summary text.
Detail panel needs eventId, sequence, version, payload preview scaffold.
Variants: populated timeline, empty results, loading, error.
Controller - Sites
Create the ONYX Controller page: SITE COMMAND GRID (desktop only).
Sections: top site metrics, site roster selector, selected site operational workspace.
Workspace should include site headline, posture badges, KPI cards, dispatch outcome mix, operational pulse.
Support 1-site and multi-site states.
Variants: single site strong, mixed health portfolio, no sites, loading/error.
Controller - Sovereign Ledger
Create the ONYX Controller page: SOVEREIGN LEDGER (desktop only).
Top integrity summary cards (source, visible rows, integrity state).
Primary content: ledger timeline cards ordered newest-first with type color coding.
Each row: event title, dispatch/site context, sequence badge, UTC timestamp.
Primary action: Verify Chain.
Variants: chain intact, pending verification, compromised state, empty/loading/error.
Controller - Reports
Create the ONYX Controller page: CLIENT INTELLIGENCE REPORTS (desktop only).
Sections: report scope summary, deterministic generation controls, generation lanes (Generate/Verify/Review), receipt history.
Primary actions: Preview Report, Refresh Replay Verification.
Show output mode and replay state clearly.
Variants: no receipts yet, receipts present, verification failed, loading/error.
Guard App - Main Field Screen (mobile first)
Create ONYX GUARD APP main screen (mobile 390x844 primary, optional tablet companion).
Focus: guard-only operations, no controller/admin workspace.
Sections: active dispatch inbox, quick status actions, checkpoint action, panic CTA, sync queue health.
Large touch targets, single main scroll, clear hierarchy.
Keep top compact status chips: guard id, site, sync state.
Variants: on-shift active dispatch, idle/no dispatch, sync failures pending, loading/error.
Guard App - Panic / Emergency
Create ONYX GUARD APP emergency screen (mobile first).
Primary red emergency action, threat labeling options, confirmation source selector, escalation feedback.
Design for speed and clarity under stress.
Include post-trigger confirmation state and retry/failure handling.
Variants: ready to trigger, triggered success, trigger failed/offline.
Guard App - Sync Queue
Create ONYX GUARD APP sync queue screen (mobile first).
Show pending events/media, failed events/media, last successful sync, last failure reason.
Primary actions: Sync Now, Retry Failed Events, Retry Failed Media.
Optional secondary actions: queue telemetry heartbeat/device health.
No dense diagnostics, no nested scrolling panes.
Variants: healthy queue, backlog warning, failed sync state, loading/error.
Client App - Overview
Create ONYX CLIENT APP overview screen (mobile first, optional desktop web companion).
Sections: unread alerts, active incidents, estate rooms, pending acknowledgements, push queue status.
Show clear client-safe language and incident transparency.
Include quick filter tabs (Client View, Control View, Resident View) if needed.
Variants: normal activity, high alert volume, no incidents, loading/error.
Client App - Incident Feed + Chat
Create ONYX CLIENT APP incident communication screen (mobile first).
Split by vertical flow: incident feed cards, room selector, direct chat thread, quick response templates, message composer.
Cards need status tags (dispatch/arrival/closure/advisory) and timestamps.
Support unread badges and acknowledgement actions.
Variants: active incident thread, quiet/no messages, delivery failure, loading/error.
When you generate each frame, send me:

Figma link
Node ID
Which state variant you want me to implement first
Then I’ll implement page-by-page in Flutter to match.