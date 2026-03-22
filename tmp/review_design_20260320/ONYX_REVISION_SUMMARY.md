# ONYX Design Revision Summary
## Operational Depth Enhancement - Pages 3-12

This revision adds complete operational depth to 9 pages while keeping Live Operations and Admin unchanged.

---

## ✅ 1. TACTICAL MAP

### Watch Health States (3 variants)
```
✓ Available (emerald) - "Watch Available"
✓ Limited (amber) - "Watch Limited" + reason detail
✓ Unavailable (red) - "Watch Unavailable"
```

### Limited Watch Reasons (4 types)
```
✓ Stale Feed - "Feed has not updated recently"
✓ Degraded Connectivity - "Network latency detected"  
✓ Fetch Failure - "Unable to retrieve feed"
✓ Manual Verification - "Requires manual verification"
```

### Watch Recovery
```
✓ "Recover Watch" action button
✓ Visual feedback on recovery attempt
✓ State transition handling
```

### Fleet Summary (clickable chips)
```
✓ Total fleet count (gray)
✓ Available count (emerald) - filters to available
✓ Limited count (amber) - filters to limited
✓ Unavailable count (red) - filters to unavailable
```

### Guard Responder Pings
```
✓ Active (emerald pulse) - on duty, monitoring
✓ Patrol (blue pulse) - actively patrolling
✓ SOS (red pulse + alert ring) - emergency signal
```

### Geofence System
```
✓ Visual geofence circles on map
✓ Breach detection (red ring)
✓ Entry/exit event tracking
```

### Layer Controls
```
✓ Toggle Sites layer
✓ Toggle Guards layer  
✓ Toggle Geofences layer
```

### Temporary Identities
```
✓ Expiration countdown (2h 14m, 45m, 8m formats)
✓ Extend button
✓ Expire button
✓ Site association display
```

**File:** `/src/app/pages/TacticalMap.tsx`
**Components:** `WatchBadge.tsx`, `LimitedReasonIcon.tsx`, `FleetSummaryChip.tsx`

---

## ✅ 2. CLIENTS

### Communication Channel States (6+ variants)
```
✓ Telegram Available (green badge)
✓ Telegram Blocked (red badge) - shows block reason
✓ SMS Fallback (amber badge) - "Fallback Active"
✓ VoIP Ready (green badge)
✓ VoIP Staged (cyan badge) - "Staging"
✓ Push Notifications (various delivery states)
```

### Push Sync History
```
✓ Timeline visualization component
✓ Sent → Delivered tracking
✓ Sent → Failed tracking
✓ Timestamp for each event
✓ Retry indicators
```

### Push Sync Review State
```
✓ "Needs Review" amber alert badge
✓ Review action button
✓ Sync failure detail
```

### Backend Probe States (3 variants)
```
✓ Healthy (emerald) - "Last check: 12s ago"
✓ Failed (red) - shows failure reason
✓ Idle (gray) - "Awaiting next check"
```

### Pending AI Drafts
```
✓ Draft counter badge (e.g., "2 drafts")
✓ Draft preview in sidebar
✓ Quick approve/edit actions
```

### Learned Approval Style
```
✓ Style display ("Reassuring with ETAs")
✓ Learn from history tracking
✓ Override controls
```

### Pinned Voice Controls
```
✓ Auto mode (default)
✓ Formal tone
✓ Concise tone
✓ ONYX mode indicator badge
```

### Off-Scope Routed Lane
```
✓ Purple lane indicator
✓ Partner routing information
✓ Handoff confirmation display
```

### Room/Thread Awareness
```
✓ Room ID display (ROOM-2441-MS-VALLEY)
✓ Thread context (THREAD-DSP-4)
✓ Message grouping by context
✓ Thread-specific actions
```

**File:** `/src/app/pages/Clients.tsx`
**Components:** `PushSyncHistory.tsx`, `CommsStateChip.tsx`

---

## ✅ 3. DISPATCHES

### Ingest Controls
```
✓ Active/Paused toggle
✓ Ingest rate display
✓ Queue depth counter
✓ Real-time status indicator
```

### Live Polling Controls
```
✓ Poll interval selector (2s default)
✓ Active polling indicator (green pulse)
✓ Pause/resume controls
✓ Manual poll trigger
```

### Radio Queue Controls
```
✓ Listening/Paused states
✓ Queue depth display
✓ Priority routing toggle
✓ Clear queue action
```

### Telemetry Controls
```
✓ Normal view mode
✓ Heavy view mode (detailed metrics)
✓ Stress test controls
✓ Soak test controls
✓ Benchmark tools
```

### Readiness Sections (3 systems)
```
✓ Wearable Readiness - Ready/Degraded states
✓ Radio Readiness - Ready/Degraded states
✓ Video Readiness - Ready/Degraded states
```

### Fleet Watch Drilldowns
```
✓ "View Fleet Watch" toggle
✓ Per-officer readiness detail
✓ Equipment status per officer
✓ Officer-level diagnostics
```

### Partner Dispatch Flow
```
✓ "Route Dispatch" action
✓ Partner selection dropdown
✓ Handoff confirmation dialog
✓ Routing history tracking
```

### Intelligence Filtering
```
✓ Selected intelligence display
✓ Pin action (keep visible)
✓ Dismiss action (hide from view)
✓ Filter persistence
```

**File:** `/src/app/pages/Dispatches.tsx`
**Components:** `ReadinessIndicator.tsx`

---

## ✅ 4. GOVERNANCE

### Report View Modes (2 types)
```
✓ Morning Sovereign Report view
✓ Historical Report view
✓ Toggle between views
```

### Blocker System
```
✓ Critical blockers (red, "Action Required")
✓ Warning blockers (amber)
✓ Resolution workflow
✓ Blocker source tracking (Tactical Watch, Client Comms, etc.)
✓ Timestamp display
```

### Non-Blockers
```
✓ Info-level items (amber, lower priority)
✓ Awareness-only display
✓ "For awareness" label
```

### Partner Dispatch Chains
```
✓ Partner name and ID
✓ Routed incident ID
✓ Chain status (Pending/Acknowledged/Completed)
✓ Routing timestamp
✓ Visual status badges
```

### Scope Filters (3 types)
```
✓ All scope
✓ Internal scope
✓ Partner-scope
```

### Compliance Summary
```
✓ Verified status (emerald, checkmark)
✓ Pending status (amber, clock)
✓ Failed status (red, x-circle)
✓ Category tags (Evidence/Reporting/Response-Time/Verification)
```

### Drilldown Actions
```
✓ View Events (linked event ID)
✓ View Reports (linked report ID)
✓ View Ledger
```

**File:** `/src/app/pages/Governance.tsx`

---

## ✅ 5. REPORTS

### Report States (4 variants)
```
✓ Verified (emerald) - downloadable, complete
✓ Pending (amber) - awaiting final verification
✓ Failed (red) - regeneration required
✓ Generating (cyan) - in progress, spinner active
```

### Report Preview/Shell
```
✓ Section completion tracking
✓ Section item counts
✓ Preview mode toggle
✓ Section status (Complete/Incomplete)
```

### Report Types
```
✓ Morning Sovereign Reports
✓ Incident Reports
✓ Site Audit Reports
✓ Partner-Scope Reports
```

### Partner-Scope Flow
```
✓ Partner badge on reports
✓ Partner routing detail display
✓ Handoff documentation
✓ Scope filter (All/Internal/Partner)
```

### Evidence Context
```
✓ CCTV footage count (12 clips)
✓ Guard reports count (8 OB entries)
✓ Scene review section
✓ Evidence summary panel
```

### Verification Workflow
```
✓ Verify Report action (pending → verified)
✓ Regenerate action (failed → generating)
✓ Download action (verified only)
```

### Drilldown Actions
```
✓ View Governance
✓ View Events
```

**File:** `/src/app/pages/Reports.tsx`

---

## ✅ 6. GUARDS

### Sync Health Emphasis (3 states)
```
✓ Healthy (emerald, Wifi icon) - "Last sync: 5s ago"
✓ Stale (amber, AlertTriangle icon) - "Last sync: 142s ago"
✓ Offline (red, WifiOff icon) - "Last sync: 6h ago"
```

### Performance Panel (4 metrics)
```
✓ OB Entries count (24 entries this period)
✓ Incidents Handled count (8 incidents)
✓ Avg Response Time (142s average)
✓ Rating score (4.8/5.0)
```

### Quick Actions (4 buttons)
```
✓ Guard Schedule (Calendar icon)
✓ Guard Reports (FileText icon)
✓ Open Client Lane (MessageSquare icon)
✓ Stage VoIP Call (Phone icon, disabled when not ready)
```

### Site Filtering
```
✓ All Sites filter
✓ Per-site code filters (SE-01, WF-02, BR-03)
✓ Active filter highlighting
```

### Guard Operational States
```
✓ On-Duty (emerald badge)
✓ Off-Duty (gray badge)
✓ On-Leave (blue badge)
```

### Guard Detail Display
```
✓ Current site assignment
✓ Clocked-in timestamp
✓ VoIP readiness indicator
✓ Contact information
✓ Guard code (G-2441)
```

**File:** `/src/app/pages/Guards.tsx`

---

## ✅ 7. SITES

### Site Posture Variants (3 levels)
```
✓ Strong (emerald gradient):
  "All systems operational. Guards present. Watch available."
  No immediate action required

✓ At-Risk (amber gradient):
  "Limited watch capability or operational concerns detected."
  "Review Status" action button

✓ Critical (red gradient):
  "Severe operational degradation. Watch unavailable."
  "Dispatch Response" action button (immediate)
```

### Watch Health Detail
```
✓ Available (emerald, Wifi icon)
✓ Limited (amber, AlertTriangle icon) with reasons:
  - Stale-feed
  - Degraded-connectivity
  - Manual-verification
✓ Unavailable (red, WifiOff icon)
```

### Site Metrics (4 key metrics)
```
✓ Guards on-site count
✓ Active cameras display (7/8 format)
✓ 24h incidents count
✓ Average response time
```

### Site Actions (4 buttons)
```
✓ Open Tactical Map (Map icon)
✓ Site Settings (Settings icon)
✓ Guard Roster (Users icon)
✓ Camera Feed (Camera icon)
```

### Posture Filtering
```
✓ All sites view
✓ Filter by Strong
✓ Filter by At-Risk
✓ Filter by Critical
```

**File:** `/src/app/pages/Sites.tsx`

---

## ✅ 8. EVENTS

### Scoped Review Mode (3 scopes)
```
✓ All Events view
✓ Incident-focused (INC-DSP-4 filter)
✓ Site-focused (SE-01 filter)
```

### Event Type Filtering (6 types)
```
✓ Incident (red badge)
✓ Dispatch (orange badge)
✓ Guard-action (blue badge)
✓ Client-comms (cyan badge)
✓ Watch (purple badge)
✓ System (gray badge)
```

### Selected Event State
```
✓ Gradient background highlight
✓ Expanded detail panel
✓ Verification badge display
✓ Border emphasis
```

### Forensic Payload Detail
```
✓ JSON payload viewer
✓ Syntax-highlighted monospace display
✓ Copy-friendly formatting
✓ Expandable/collapsible sections
```

### Event Metadata (5 fields)
```
✓ Timestamp (UTC format)
✓ Actor (who triggered)
✓ Subject (what was affected)
✓ Severity (Critical/Warning/Info)
✓ Verification status (Verified/Pending)
```

### Linked Resources
```
✓ Linked Incident display with badge
✓ Linked Site display with badge
✓ "View Incident" action
✓ "View Site" action
```

### Drilldown Actions
```
✓ View Governance
✓ View Ledger
```

**File:** `/src/app/pages/Events.tsx`

---

## ✅ 9. LEDGER

### View Modes (2 types)
```
✓ Full Chain view (all blocks)
✓ Incident-Focused view (INC-DSP-4 filter)
```

### Verification States (3 variants)
```
✓ Verified (emerald):
  "Chain integrity confirmed, no tampering detected"
  Hash validation passed, checkmark icon

✓ Pending (amber):
  "Awaiting cryptographic verification"
  Clock icon, "Verify Now" action

✓ Compromised (red):
  "Integrity violation detected"
  X-circle icon, critical alert state
```

### Provenance Chain Detail
```
✓ Current block hash display (monospace)
✓ Previous block hash display (monospace)
✓ Chain link visualization (link icon)
✓ Block height tracking (#2441)
```

### Evidence Chain
```
✓ Linked evidence items (EVD-CCTV-2441, EVD-GPS-2441)
✓ Evidence count per block
✓ "View Evidence" actions
✓ Evidence type badges
```

### Cryptographic Detail
```
✓ Hash values in monospace font
✓ Hash verification badges
✓ Link integrity indicators
✓ Color-coded verification states
```

### Drilldown Actions
```
✓ View Event (event detail page)
✓ View Incident (incident detail page)
```

**File:** `/src/app/pages/Ledger.tsx`

---

## 🎨 Reusable Components

### 1. WatchBadge.tsx
```typescript
// Available/Limited/Unavailable states
// Color-coded badges with icons
// Props: state, reason (optional)
```

### 2. LimitedReasonIcon.tsx
```typescript
// Icons for each limited reason type
// Tooltip support
// Consistent sizing (14px)
```

### 3. FleetSummaryChip.tsx
```typescript
// Clickable fleet counters
// Filter activation on click
// Active state styling
// Props: label, count, color, onClick
```

### 4. CommsStateChip.tsx
```typescript
// Channel state badges
// Semantic colors per state
// Status icons (check/x/clock)
// Props: channel, state
```

### 5. PushSyncHistory.tsx
```typescript
// Timeline visualization
// Delivery state tracking
// Expandable detail view
// Props: events[]
```

### 6. ReadinessIndicator.tsx
```typescript
// System readiness badges
// Ready/Degraded states
// Color-coded status
// Props: system, status
```

**Location:** `/src/app/components/`

---

## 🎯 Design Consistency Maintained

### Visual Language
```
✓ Premium gradient headers on all pages
✓ Consistent color palette per operational area
✓ Unified border system (#21262D)
✓ Consistent backgrounds (#0A0E13, #0D1117)
✓ Status badge system with semantic colors
✓ Smooth hover transitions (all interactive elements)
✓ Professional shadow system (shadow-xl, shadow-2xl)
```

### Typography
```
✓ Heading hierarchy (text-2xl → text-lg → text-sm)
✓ Label styling (text-xs, uppercase, tracking-wider)
✓ Monospace for technical data (font-mono)
✓ Tabular numbers for metrics (tabular-nums)
✓ Consistent font weights (font-bold, font-semibold)
```

### Icons
```
✓ Lucide React icons throughout
✓ Consistent stroke weights (2 default, 2.5 active)
✓ Color-coded by context
✓ Size variants (w-4 h-4 for inline, w-5 h-5 for emphasis)
```

### Page-Specific Colors
```
Tactical:    Purple/Indigo (#8B5CF6, #6366F1)
Clients:     Blue/Cyan (#3B82F6, #06B6D4)
Dispatches:  Red/Orange (#EF4444, #F97316)
Governance:  Green/Emerald (#10B981, #14B8A6)
Reports:     Indigo/Purple (#6366F1, #8B5CF6)
Guards:      Orange/Red (#F97316, #EF4444)
Sites:       Cyan/Blue (#06B6D4, #3B82F6)
Events:      Violet/Purple (#8B5CF6, #A855F7)
Ledger:      Emerald/Teal (#10B981, #14B8A6)
```

---

## 🔗 Cross-Page Navigation

### Navigation Patterns Added
```
Tactical → Dispatches (officer handoff)
Clients → Room/thread context awareness
Governance → Events, Reports, Ledger
Reports → Governance, Events
Guards → Schedule, Reports, Client Lane, VoIP
Sites → Tactical Map, Settings, Guard Roster, Camera Feed
Events → Governance, Ledger, Incidents, Sites
Ledger → Events, Incidents
```

---

## 📊 Operational Depth Summary

### State Variants: 35+ Total
```
✓ 3 watch health states (available/limited/unavailable)
✓ 4 limited watch reasons
✓ 6 communication channel states
✓ 3 sync health states for guards
✓ 3 site posture levels
✓ 4 report verification states
✓ 3 ledger verification states
✓ 6 event types
✓ 3 readiness system states
✓ Multiple blocker/non-blocker classifications
```

### Filtering Capabilities: 10+ Filters
```
✓ Fleet filtering (Available/Limited/Unavailable)
✓ Event type filtering (6 types)
✓ Scope filtering (All/Internal/Partner)
✓ Site filtering (per-site roster)
✓ Posture filtering (Strong/At-Risk/Critical)
✓ Incident-focused views
✓ Report status filtering
✓ Guard site filtering
✓ Ledger chain/incident modes
```

### Action Workflows: 25+ Actions
```
✓ Watch recovery workflow
✓ Channel fallback workflow
✓ Report verification workflow
✓ Ledger verification workflow
✓ Partner dispatch routing
✓ Temporary identity extend/expire
✓ VoIP staging workflow
✓ Ingest/polling/radio controls
✓ Intelligence pin/dismiss
✓ Blocker resolution
✓ Evidence viewing
✓ Cross-page drilldowns
```

---

## 📁 Files Modified

### Pages (9 files)
```
/src/app/pages/TacticalMap.tsx
/src/app/pages/Clients.tsx
/src/app/pages/Dispatches.tsx
/src/app/pages/Governance.tsx
/src/app/pages/Reports.tsx
/src/app/pages/Guards.tsx
/src/app/pages/Sites.tsx
/src/app/pages/Events.tsx
/src/app/pages/Ledger.tsx
```

### Components (6 files)
```
/src/app/components/WatchBadge.tsx
/src/app/components/LimitedReasonIcon.tsx
/src/app/components/FleetSummaryChip.tsx
/src/app/components/CommsStateChip.tsx
/src/app/components/PushSyncHistory.tsx
/src/app/components/ReadinessIndicator.tsx
```

### Routes
```
/src/app/routes.tsx (all 12 routes configured)
/src/app/components/AppShell.tsx (navigation updated)
```

---

## ✅ Completion Checklist

### Requirements Met
- ✅ Live Operations direction unchanged
- ✅ Admin direction unchanged
- ✅ All 9 remaining pages enhanced
- ✅ No workflows simplified
- ✅ No features removed
- ✅ Premium ONYX command-center style maintained
- ✅ Complete state coverage added
- ✅ Action workflows implemented
- ✅ Cross-page navigation added
- ✅ Reusable components created
- ✅ Consistent design system applied

### Operational Depth Achieved
- ✅ Watch health: 3 states + 4 reasons + recovery
- ✅ Client comms: 6+ channel states + push sync + probe + drafts + style + voice + off-scope
- ✅ Dispatch controls: ingest + polling + radio + telemetry + readiness + fleet
- ✅ Governance: morning/historical + blockers + partners + drilldowns
- ✅ Reports: preview + 4 states + partner-scope + evidence
- ✅ Guards: sync health + performance + 4 actions
- ✅ Sites: 3 posture levels + watch detail + 4 actions
- ✅ Events: scoped review + forensic payload + drilldowns
- ✅ Ledger: 3 verification states + provenance + evidence chain

---

## 🚀 Result

The ONYX platform now features **complete operational depth** across all 12 pages:

**Production-Ready Features:**
- 35+ state variants covering all operational scenarios
- 10+ filtering capabilities for data scoping
- 25+ action workflows for controller operations
- 6 reusable components for consistency
- Full cross-page navigation system
- Forensic detail and audit trail support
- Premium command-center visual design

**No compromises. Full complexity. World-class execution.** 🔥
