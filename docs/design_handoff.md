# ONYX Design Handoff

This document is the working design brief for the ONYX controller product.

It is intended to be the single handoff artifact for Figma structure, screen
inventory, component families, responsive rules, and screen-level design goals
while implementation continues in parallel.

## Source Of Truth

- Route authority: `/Users/zaks/omnix_dashboard/lib/domain/authority/onyx_route.dart`
- Shell/navigation: `/Users/zaks/omnix_dashboard/lib/ui/app_shell.dart`
- Layout rules: `/Users/zaks/omnix_dashboard/lib/ui/layout_breakpoints.dart`
- Shared surface primitives: `/Users/zaks/omnix_dashboard/lib/ui/onyx_surface.dart`
- Route builders: `/Users/zaks/omnix_dashboard/lib/ui/onyx_route_builders.dart`
- Command center builders: `/Users/zaks/omnix_dashboard/lib/ui/onyx_route_command_center_builders.dart`

## Figma File Structure

### 00 Foundations

Define the system-level design tokens and layout rules.

- Breakpoints
- Spacing scale
- Grid rules
- Typography scale
- Radius tokens
- Border weights
- Shadow and elevation tokens
- Icon sizing
- Surface colors
- Status colors
- Alert colors
- Chart/data-viz colors
- Chips, pills, badges, counters
- Command receipt styles

### 01 App Shell

Design the persistent product shell and route-switching experience.

- Sidebar grouped into:
  - COMMAND CENTER
  - OPERATIONS
  - GOVERNANCE
  - EVIDENCE
  - SYSTEM
- Top bar
- Quick jump modal
- Intel ticker
- Operator chip
- Shift chip
- Autopilot chip
- Route badges and counts
- Mobile shell variant

### 02 Command Center

- Dashboard / Live Operations
- Agent
- AI Queue / CCTV
- Tactical / Track
- Dispatches / Alarms

### 03 Operations

- Clients
- Client App / Comms
- Sites
- Sites Command
- Guards
- Events
- Events Review
- VIP Protection
- Risk Intelligence

### 04 Governance

- Governance overview
- Compliance and readiness trends
- Scope banners
- Focused scene actions
- Morning report and export strips

### 05 Evidence & Reports

- Ledger
- Sovereign Ledger
- Reports workspace
- Report preview and export

### 06 System & Admin

- Admin runtime
- Camera bridge system controls
- Onboarding and entity management
- Import/export/reset flows
- Controller login

### 07 Mobile Guard

- Guard mobile shell
- Sync states
- Offline states
- Dispatch-first state
- Operation detail state

### 08 Component Library

- Shared surfaces
- Workspace shell
- Shell primitives
- Fleet health components
- Camera bridge components
- Client comms queue components
- KPI and metric cards
- Map controls
- Banners
- Command receipts
- Action strips

### 09 States & Flows

- Empty states
- Loading states
- Error states
- Offline and degraded states
- Focused states
- Drilldown states
- Export/copy success states
- Modal/dialog states
- Route-to-route prototype flows

## Responsive Rules

Source: `/Users/zaks/omnix_dashboard/lib/ui/layout_breakpoints.dart`

- Handset: under `900px` width or under `700px` shortest side
- Embedded multi-panel desktop: `>=1280px` width and `>=820px` height
- Widescreen: `>=2560px`
- Ultrawide: `>=3440px`

Design every important screen in at least these variants:

- Mobile
- Desktop
- Ultrawide command wall

## Shared Design Language

Source: `/Users/zaks/omnix_dashboard/lib/ui/onyx_surface.dart`

- Dark command-center visual language
- Dense cards and information-rich panels
- Strong border-driven panel separation
- Rajdhani for headings, route labels, hero labels
- Inter for body text, controls, dense data, status copy
- Operational status should always be legible at a glance
- Actions should be grouped into clear primary, secondary, and diagnostic lanes

## Shell Spec

### App Shell

Source: `/Users/zaks/omnix_dashboard/lib/ui/app_shell.dart`

Goal:

- Let the operator understand where they are, what needs attention, and switch
  routes quickly.

Primary actions:

- Change route
- Open quick jump
- Inspect active route badges
- Watch intel ticker
- Pause, skip, or stop autopilot

Core panels:

- Sidebar navigation
- Top bar
- Route header
- Operator context
- Autopilot controls
- Intel ticker
- Quick jump modal

Required states:

- Expanded sidebar
- Collapsed sidebar
- Active route
- Active route with badge
- Mobile shell
- Intel ticker hidden
- Autopilot active
- Autopilot paused

## Command Center Screen Specs

### Dashboard / Live Operations

Source: `/Users/zaks/omnix_dashboard/lib/ui/live_operations_page.dart`

Goal:

- Monitor active posture and pivot into the right route in one move.

Primary actions:

- Open alarms
- Open CCTV
- Open agent
- Open tactical
- Open comms
- Open guards
- Open VIP
- Open risk intelligence

Core panels:

- Command hero
- Command card launcher rail
- Critical alert banner
- Recent activity
- Control inbox
- Client-lane workspace
- Queue hint/recovery surfaces

Required states:

- Default command overview
- Focused incident
- Off-scope inbox surfaced
- Empty client lane
- Queue hint visible
- Queue hint dismissed
- Return-from-agent state

### Agent

Source: `/Users/zaks/omnix_dashboard/lib/ui/onyx_agent_page.dart`

Goal:

- Provide a controller copilot that routes specialist work and operator actions.

Primary actions:

- Send prompt
- Use quick prompts
- Open CCTV
- Open alarms
- Open tactical
- Open comms
- Open live operations
- Stage client draft

Core panels:

- Thread rail
- Message feed
- Composer
- Quick prompts
- Persona definitions
- Action cards
- Camera bridge shell
- Camera bridge health and audit

Required states:

- Local-only brain
- Cloud assist available
- Camera bridge healthy
- Camera bridge degraded
- Camera bridge disconnected
- Draft staged for comms
- Route resume buttons visible

### AI Queue / CCTV

Source: `/Users/zaks/omnix_dashboard/lib/ui/ai_queue_page.dart`

Goal:

- Review AI detections, promote the right ones, and route action quickly.

Primary actions:

- View camera
- Open agent
- Dispatch guard
- Open event scope
- Open policy
- Open context
- Promote selected incident

Core panels:

- Alert lanes
- Feed board
- Selected focus card
- Runbook panel
- Policy panel
- Context panel
- Command receipt
- Daily stats

Required states:

- Empty lane
- Standby recovery
- Selected focus
- Shadow dossier open
- Escalated / promoted
- Focus incident mode

### Tactical / Track

Sources:

- `/Users/zaks/omnix_dashboard/lib/ui/tactical_page.dart`
- `/Users/zaks/omnix_dashboard/lib/ui/track_overview_board.dart`

Goal:

- Verify spatial posture, field movement, and CCTV-linked fleet truth.

Primary actions:

- Center active track
- Queue anomalies
- Queue matches
- Queue assets
- Open dispatches
- Open agent
- Resync fleet scope

Core panels:

- Map canvas
- SOS banner
- Geofence banner
- Active track card
- Fleet summary tiles
- Fleet scope cards
- Verification queue
- Lens comparison
- Fleet command actions

Required states:

- Map focus mode
- Fleet scope selected
- Suppressed review focus
- No incident
- Stale feed
- Limited watch

### Dispatches / Alarms

Source: `/Users/zaks/omnix_dashboard/lib/ui/dispatch_page.dart`

Goal:

- Triage, execute, and track active alarms with full system readiness context.

Primary actions:

- Generate dispatch
- Ingest feeds
- Retry radio queue
- Clear radio queue
- Start live polling
- Stop live polling
- Open tactical for dispatch
- Open CCTV for dispatch
- Open client for dispatch
- Open agent for dispatch
- Open report for dispatch

Core panels:

- Alarm attention strip
- Dispatch board
- Officer banner / action row
- Radio readiness cluster
- CCTV readiness cluster
- Wearable readiness cluster
- Telemetry gate cluster
- Benchmark/stress workspace
- Command receipt

Required states:

- Live polling enabled
- Live polling disabled
- Radio queue pending
- Radio queue clear
- Telemetry pass
- Telemetry fail
- Wearable configured
- Wearable unconfigured
- Focused dispatch
- Return-from-agent state

## Operations Screen Specs

### Clients

Source: `/Users/zaks/omnix_dashboard/lib/ui/clients_page.dart`

Goal:

- Let operators manage client lanes, review AI drafts, and control outbound
  communication.

Primary actions:

- Open agent
- Open thread
- Review queued draft
- Place call now
- Retry push sync
- Stage or cancel voice action

Core panels:

- Workspace rail
- Lane board
- Context panel
- Incident rows
- Room cards
- Draft review panels
- Pinned voice surfaces
- Learned tone surfaces

Required states:

- Pending AI draft
- Approved draft
- Rejected draft
- Learned voice
- Learned approval style
- Push queue pressure
- SMS fallback
- VoIP history
- Off-scope lane surfaced

### Client App / Comms

Source: `/Users/zaks/omnix_dashboard/lib/ui/client_app_page.dart`

Goal:

- Present the detailed communication workspace for client-facing operations.

Primary actions:

- Open thread
- Focus composer
- Toggle scoped room
- View sent message
- Retry sync
- Review queue

Core panels:

- Chat panel
- Rooms panel
- Notifications panel
- Context panel
- Focus banner
- Delivery queue panel

Required states:

- Focused room
- Notification present
- Sent-message confirmation
- Queue issue
- Empty room

### Guards

Source: `/Users/zaks/omnix_dashboard/lib/ui/guards_page.dart`

Goal:

- Track field force state, roster health, and selected guard readiness.

Primary actions:

- Open schedule
- Open reports
- Open client lane
- Stage VoIP
- Clock out

Core panels:

- Active / roster / history tabs
- Selected guard panel
- Performance panel
- Quick actions panel
- Shift roster
- Shift history

Required states:

- No selection
- Active guard selected
- Overdue shift
- Performance warning

### Sites

Source: `/Users/zaks/omnix_dashboard/lib/ui/sites_page.dart`

Goal:

- Compare site posture and drill into operational outcomes and trace.

Primary actions:

- Open tactical
- Open trace
- Open command
- Filter site roster view

Core panels:

- Overview grid
- Selected site card
- Workspace banner
- Command view
- Outcomes view
- Trace view

Required states:

- No site selected
- Filtered roster
- Trace-focused
- Tactical handoff

### Sites Command

Source: `/Users/zaks/omnix_dashboard/lib/ui/sites_command_page.dart`

Goal:

- Provide a command view for site-by-site readiness and response posture.

Primary actions:

- Open map-like command actions
- Open settings-style actions
- Open guard roster

Core panels:

- Site roster
- Response workspace
- Coverage workspace
- Checkpoints workspace
- Site KPI cards

Required states:

- Active site
- No response events
- Checkpoint gap

### Events

Source: `/Users/zaks/omnix_dashboard/lib/ui/events_page.dart`

Goal:

- Review event chains, evidence, and related operational context.

Primary actions:

- Open casefile
- Open evidence
- Open chain
- Open intelligence
- Open ledger
- Open all-time view

Core panels:

- Overview grid
- Selected event card
- Casefile panel
- Evidence panel
- Chain panel
- Workspace status banner

Required states:

- Empty result
- Selected event
- Related-chain recovery
- Reset filters

### Events Review

Source: `/Users/zaks/omnix_dashboard/lib/ui/events_review_page.dart`

Goal:

- Review event groups operationally with richer scope and export actions.

Primary actions:

- Reset filters
- Focus AI decision
- Focus alarm trigger
- Open governance
- Open ledger
- Copy selected detail
- Export selected detail

Core panels:

- Ops panel
- Timeline panel
- Detail panel
- Scope banners
- Partner progress card
- Visit timeline card
- Selected focus card

Required states:

- Focused fallback
- Partner scope
- Readiness scope
- Tomorrow scope
- Synthetic scope
- Selected detail
- Empty detail

### VIP Protection

Source: `/Users/zaks/omnix_dashboard/lib/ui/vip_protection_page.dart`

Goal:

- Manage close-protection missions and convoy posture.

Important note:

- The current code is scaffold-stage. Do not only mirror the current empty
  state. Design the intended product.

Primary actions to design for:

- Create detail
- Open active mission
- View convoy timeline
- Escalate mission risk
- Reassign or reroute

Core panels to design:

- Active mission board
- Convoy timeline
- Protectee profile
- Escort team stack
- Route risk map
- Escalation drawer
- Scheduled missions

Required states:

- Empty
- Active mission
- Delayed convoy
- Reroute
- Escalation

### Risk Intelligence

Source: `/Users/zaks/omnix_dashboard/lib/ui/risk_intelligence_page.dart`

Goal:

- Monitor threat posture and escalate credible intelligence quickly.

Important note:

- The current code is scaffold-stage. Do not only mirror the current static
  area cards. Design the intended product.

Primary actions to design for:

- Add manual intel
- Escalate threat
- Open source detail
- Inspect region posture

Core panels to design:

- Live intel feed
- Source credibility panel
- Map / zone heat surface
- Threat trend
- Area posture cards
- Manual intel composer
- Escalation rail

Required states:

- Low threat
- Medium threat
- High threat
- Urgent incoming intel
- Manual intel submitted
- Degraded source feed

## Governance Screen Specs

### Governance

Source: `/Users/zaks/omnix_dashboard/lib/ui/governance_page.dart`

Goal:

- Show operational truth, readiness drift, compliance pressure, and reportable
  governance context.

Primary actions:

- Open events
- Open reports
- Open ledger
- Generate report
- Copy JSON / CSV
- Export / share / email
- Focus or clear focus

Core panels:

- Workspace rail
- Workspace board
- Workspace context
- Status banner
- KPI grid
- Trend cards
- Scope banners
- Focused scene action surfaces
- Command receipt

Required states:

- Focused scene action
- Partner scope
- Historical shift
- Receipt policy drill-in
- Site activity drill-in
- Empty metric recovery

## Evidence And Reports Screen Specs

### Ledger

Source: `/Users/zaks/omnix_dashboard/lib/ui/ledger_page.dart`

Goal:

- Verify continuity and integrity of evidence-linked operational records.

Primary actions:

- View events
- Verify chain
- Open attention lane

Core panels:

- Overview grid
- Lane cards
- Casefile panel
- Integrity panel
- Trace panel

Required states:

- Empty lane
- Selected record
- Chain verification success
- Chain verification failure

### Sovereign Ledger

Source: `/Users/zaks/omnix_dashboard/lib/ui/sovereign_ledger_page.dart`

Goal:

- Create and inspect signed operational log entries.

Primary actions:

- Compose entry
- Submit entry
- Verify chain
- Export ledger
- Open event review

Core panels:

- Scope banner
- Hero action row
- Entry form
- Entry list
- Command receipt
- Case file view
- Chain view
- Trace view

Required states:

- Draft entry
- Signed entry success
- Verification open
- Export ready

### Reports Workspace

Source: `/Users/zaks/omnix_dashboard/lib/ui/client_intelligence_reports_page.dart`

Goal:

- Manage report generation, proof, and related report context.

Primary actions:

- Generate
- Preview
- Copy
- Download
- Open governance
- Open events
- Save/reset branding

Core panels:

- Receipts panel
- Selected report panel
- Context panel
- KPI strip
- Focus banner
- Export strip

Required states:

- No report selected
- Export ready
- Copied
- Filtered receipts
- Branding override

### Report Preview / Export

Sources:

- `/Users/zaks/omnix_dashboard/lib/presentation/reports/report_preview_page.dart`
- `/Users/zaks/omnix_dashboard/lib/presentation/reports/report_preview_dock_card.dart`

Goal:

- Preview the final report artifact before export or share.

Primary actions:

- Open preview
- Copy preview target
- Clear preview target

Core panels:

- Preview page
- Filter banner
- Filter controls
- Preview dock
- Entry context banner

Required states:

- No preview target
- Preview loaded
- Copied
- Dock open
- Dock closed

## System And Admin Screen Specs

### Admin / System

Source: `/Users/zaks/omnix_dashboard/lib/ui/admin_page.dart`

Goal:

- Control runtime behavior, system health, seeding, onboarding, and admin data.

Primary actions:

- Open entity
- Open AI comms
- Open system controls
- Validate camera bridge
- Export data
- Import CSV
- Reset demo
- Launch storyboard

Core panels:

- Workspace rail
- Active panel
- Context panel
- Status banner
- Command receipt
- Runtime controls
- Demo storyboard
- Entity editors
- Listener alarm surfaces
- Partner scorecard
- Import/export/reset flows

Required states:

- Runtime healthy
- Runtime degraded
- Validation running
- Validation success
- Validation fail
- Reset confirmation
- Import success
- Import fail

### Controller Login

Source: `/Users/zaks/omnix_dashboard/lib/ui/controller_login_page.dart`

Goal:

- Provide a clean, credible operator entry experience.

Primary actions:

- Enter operator credentials or identity
- Continue into app

Core panels:

- Login surface
- Operator identity fields
- Role and shift context
- Validation feedback

Required states:

- Default
- Validating
- Invalid
- Success handoff

## Mobile Guard Screen Specs

### Guard Mobile Shell

Source: `/Users/zaks/omnix_dashboard/lib/ui/guard_mobile_shell_page.dart`

Goal:

- Support field-operator workflows on mobile with sync, dispatch, and recovery
  visibility.

Primary actions:

- Sync now
- Open dispatch
- Resume operation
- Inspect offline spool status

Core panels:

- Mobile shell header
- Summary strip
- Sync status
- Operations list
- Operation detail
- Coaching prompt

Required states:

- Online
- Offline
- Syncing
- Sync failed
- Dispatch-first
- Resumed operation

## Component Library Spec

### Shared Primitive Families

- Page scaffold
- Page header
- Story hero
- Section card
- Dense data card
- Command receipt
- Status banner
- Focus banner
- Scope banner
- Recovery banner
- KPI tile
- Trend card
- Action strip
- Segmented tab
- Filter chip
- Badge
- Counter pill

### Shell Primitives

Source: `/Users/zaks/omnix_dashboard/lib/ui/app_shell.dart`

- Sidebar item
- Sidebar section header
- Top chip
- Operator chip
- Autopilot chip
- Intel ticker item
- Quick jump result row

### Fleet Health Family

Sources in `/Users/zaks/omnix_dashboard/lib/ui/`:

- `video_fleet_scope_health_panel.dart`
- `video_fleet_scope_health_card.dart`
- `video_fleet_scope_health_view.dart`

Design:

- Scope card
- Summary chip row
- Drilldown state
- Watch-only vs actionable state

### Camera Bridge Family

Sources in `/Users/zaks/omnix_dashboard/lib/ui/`:

- `onyx_camera_bridge_health_panel.dart`
- `onyx_camera_bridge_shell_panel.dart`
- `onyx_camera_bridge_summary_panel.dart`
- `onyx_camera_bridge_validation_panel.dart`
- `onyx_camera_bridge_shell_actions.dart`
- `onyx_camera_bridge_status_badge.dart`
- and the rest of the `onyx_camera_bridge_*` files

Design:

- Status badge
- Lead badge
- Chip list
- Detail line
- Summary panel
- Metadata panel
- Validation panel
- Shell card
- Shell actions

### Client Comms Queue Family

Source: `/Users/zaks/omnix_dashboard/lib/ui/client_comms_queue_board.dart`

- Queue strip
- Queue card
- Severity badge
- Draft action row
- Detailed workspace toggle

### Tactical Map Controls

Source: `/Users/zaks/omnix_dashboard/lib/ui/tactical_page.dart`

- Map control chip
- Overlay style
- Route overlay
- Marker style
- Geofence style

## States And Flows Spec

### Required State Matrix

Every major screen should define:

- Empty
- Loading
- Loaded
- Error
- Degraded
- Stale
- Offline
- Unconfigured
- Active / live
- Paused
- Focused
- Drilldown open
- Copied / exported success
- Modal confirmation
- Route return

### Required Prototype Flows

- Shell route switch
- Dashboard to alarms
- Dashboard to CCTV
- Dashboard to agent
- Dashboard to tactical
- Dashboard to comms
- Agent back to source route
- AI queue to agent
- AI queue to dispatch
- Dispatch to tactical
- Dispatch to CCTV
- Dispatch to client
- Dispatch to agent
- Dispatch to report
- Governance to reports
- Governance to events
- Governance to ledger
- Reports to preview
- Reports to export
- Admin to camera bridge validation

## Design Priority Order

1. `/Users/zaks/omnix_dashboard/lib/ui/app_shell.dart`
2. `/Users/zaks/omnix_dashboard/lib/ui/live_operations_page.dart`
3. `/Users/zaks/omnix_dashboard/lib/ui/dispatch_page.dart`
4. `/Users/zaks/omnix_dashboard/lib/ui/tactical_page.dart`
5. `/Users/zaks/omnix_dashboard/lib/ui/onyx_agent_page.dart`
6. `/Users/zaks/omnix_dashboard/lib/ui/ai_queue_page.dart`
7. `/Users/zaks/omnix_dashboard/lib/ui/clients_page.dart`
8. `/Users/zaks/omnix_dashboard/lib/ui/client_app_page.dart`
9. `/Users/zaks/omnix_dashboard/lib/ui/guards_page.dart`
10. `/Users/zaks/omnix_dashboard/lib/ui/sites_page.dart`
11. `/Users/zaks/omnix_dashboard/lib/ui/events_page.dart`
12. `/Users/zaks/omnix_dashboard/lib/ui/events_review_page.dart`
13. `/Users/zaks/omnix_dashboard/lib/ui/vip_protection_page.dart`
14. `/Users/zaks/omnix_dashboard/lib/ui/risk_intelligence_page.dart`
15. `/Users/zaks/omnix_dashboard/lib/ui/governance_page.dart`
16. `/Users/zaks/omnix_dashboard/lib/ui/ledger_page.dart`
17. `/Users/zaks/omnix_dashboard/lib/ui/sovereign_ledger_page.dart`
18. `/Users/zaks/omnix_dashboard/lib/ui/admin_page.dart`

## Build Notes For Design

- `VIP Protection` and `Risk Intelligence` are still scaffold-stage in code.
  Design the intended product, not only the current placeholders.
- The route/module architecture is stable enough for design work to proceed in
  parallel with implementation.
- The largest implementation pressure points still are:
  - `/Users/zaks/omnix_dashboard/lib/ui/admin_page.dart`
  - `/Users/zaks/omnix_dashboard/lib/ui/governance_page.dart`
  - `/Users/zaks/omnix_dashboard/lib/ui/live_operations_page.dart`
  - `/Users/zaks/omnix_dashboard/lib/main.dart`
