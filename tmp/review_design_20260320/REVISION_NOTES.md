# ONYX Design Revision - What Was Added

## Overview
This revision focused on adding complete operational depth to the 9 remaining pages while keeping Live Operations and Admin direction unchanged.

---

## 1. Tactical Map - Watch & Fleet Operations

### Added:
- **Watch Health States** (3 variants):
  - Available (emerald) - "Watch Available" 
  - Limited (amber) - "Watch Limited" with reason detail
  - Unavailable (red) - "Watch Unavailable"

- **Limited Watch Reasons** (4 types):
  - Stale feed (142s ago)
  - Degraded connectivity
  - Fetch failure  
  - Manual verification needed

- **Watch Recovery**:
  - "Recover Watch" action button for degraded states
  - Visual feedback on recovery attempt

- **Fleet Summary Chips** (clickable filters):
  - Total fleet count
  - Available count (emerald)
  - Limited count (amber)
  - Unavailable count (red)

- **Guard Responder Pings**:
  - Active (emerald pulse)
  - Patrol (blue pulse)
  - SOS (red pulse with alert ring)

- **Geofence System**:
  - Visual geofence circles
  - Breach detection (red ring)
  - Entry/exit tracking

- **Layer Controls**:
  - Toggle Sites layer
  - Toggle Guards layer
  - Toggle Geofences layer

- **Temporary Identity Approvals**:
  - Expiration countdown (2h 14m, 45m, etc.)
  - Extend button
  - Expire button

---

## 2. Clients - Communication & Channel Management

### Added:
- **Channel States** (6 variants):
  - Telegram Available (green)
  - Telegram Blocked (red) - shows block reason
  - SMS Fallback (amber) - "Fallback Active"
  - VoIP Ready (green)
  - VoIP Staged (cyan) - "Staging"
  - Push Notifications (various states)

- **Push Sync System**:
  - Push sync history component
  - Delivery timeline (sent → delivered/failed)
  - "Needs Review" state (amber alert)
  - Delivery confirmation tracking

- **Backend Probe States**:
  - Healthy (emerald) - last check timestamp
  - Failed (red) - failure reason
  - Idle (gray) - awaiting next check

- **AI Draft Management**:
  - Pending AI drafts counter (2 drafts)
  - Draft preview in sidebar
  - Quick approve/edit actions

- **Learned Approval Style**:
  - Style display ("Reassuring with ETAs")
  - Override controls
  - Learn from history

- **Pinned Voice Controls**:
  - Auto mode
  - Formal tone
  - Concise tone
  - ONYX mode badge

- **Off-Scope Routing**:
  - Off-scope lane indicator (purple)
  - Partner routing info
  - Handoff confirmation

- **Room/Thread Awareness**:
  - Room ID display (ROOM-2441-MS-VALLEY)
  - Thread context (THREAD-DSP-4)
  - Message grouping by context

---

## 3. Dispatches - System Controls & Fleet Readiness

### Added:
- **Ingest Controls**:
  - Active/Paused toggle
  - Ingest rate display
  - Queue depth counter

- **Live Polling Controls**:
  - Poll interval selector (2s, 5s, 10s)
  - Active polling indicator
  - Pause/resume controls

- **Radio Queue**:
  - Listening/Paused states
  - Queue depth
  - Priority routing

- **Telemetry Controls**:
  - Normal view mode
  - Heavy view mode (detailed metrics)
  - Benchmark tools
  - Stress test controls
  - Soak test controls

- **Readiness Sections** (3 systems):
  - **Wearable Readiness**: Ready/Degraded states
  - **Radio Readiness**: Ready/Degraded states  
  - **Video Readiness**: Ready/Degraded states

- **Fleet Watch Drilldowns**:
  - "View Fleet Watch" toggle
  - Per-officer readiness detail
  - Equipment status tracking

- **Partner Dispatch Flow**:
  - Route to partner action
  - Partner selection
  - Handoff confirmation

- **Intelligence Filtering**:
  - Selected intelligence display
  - Pin action (keep visible)
  - Dismiss action (hide)

---

## 4. Governance - Compliance & Oversight

### Added:
- **Report Views** (2 modes):
  - Morning Sovereign Report view
  - Historical Report view

- **Blocker System**:
  - Critical blockers (red)
  - Warning blockers (amber)
  - Resolution workflow
  - Blocker source tracking

- **Non-Blockers**:
  - Info-level items (amber)
  - Awareness display
  - Lower priority treatment

- **Partner Dispatch Chains**:
  - Chain status (Pending/Acknowledged/Completed)
  - Partner name and ID
  - Routed incident tracking
  - Handoff timestamp

- **Scope Filters**:
  - All scope
  - Internal scope
  - Partner-scope

- **Compliance Summary**:
  - Verified status (emerald)
  - Pending status (amber)
  - Failed status (red)
  - Category tags (Evidence/Reporting/Response-Time/Verification)

- **Drilldown Actions**:
  - View Events (linked event navigation)
  - View Reports (linked report navigation)
  - View Ledger

---

## 5. Reports - Documentation & Verification

### Added:
- **Report States** (4 variants):
  - Verified (emerald) - downloadable
  - Pending (amber) - awaiting verification
  - Failed (red) - regeneration required
  - Generating (cyan) - in progress with spinner

- **Report Preview/Shell**:
  - Section completion status
  - Section item counts
  - Preview mode toggle

- **Report Types**:
  - Morning Sovereign Reports
  - Incident Reports
  - Site Audit Reports
  - Partner-Scope Reports

- **Partner-Scope Flow**:
  - Partner badge on reports
  - Partner routing detail
  - Handoff documentation

- **Evidence Context**:
  - CCTV footage count
  - Guard reports (OB entries) count
  - Scene review section

- **Verification Workflow**:
  - Verify Report action
  - Regenerate action
  - Download action (verified only)

- **Drilldown Actions**:
  - View Governance
  - View Events

---

## 6. Guards - Workforce Management

### Added:
- **Sync Health Emphasis** (3 states):
  - Healthy (emerald, Wifi icon) - "5s ago"
  - Stale (amber, AlertTriangle icon) - "142s ago"
  - Offline (red, WifiOff icon) - "6h ago"

- **Performance Panel**:
  - OB Entries count (24)
  - Incidents Handled count (8)
  - Avg Response Time (142s)
  - Rating score (4.8/5)

- **Quick Actions**:
  - Guard Schedule (Calendar icon)
  - Guard Reports (FileText icon)
  - Open Client Lane (MessageSquare icon)
  - Stage VoIP Call (Phone icon, disabled when not ready)

- **Site Filtering**:
  - All Sites filter
  - Per-site code filters (SE-01, WF-02, BR-03)

- **Guard States**:
  - On-Duty (emerald)
  - Off-Duty (gray)
  - On-Leave (blue)

- **Operational Detail**:
  - Current site assignment
  - Clocked-in timestamp
  - VoIP readiness indicator
  - Contact information

---

## 7. Sites - Deployment & Posture

### Added:
- **Site Posture Variants** (3 levels):
  - **Strong** (emerald):
    - "All systems operational. Guards present. Watch available."
    - No immediate concerns
  - **At-Risk** (amber):
    - "Limited watch capability or operational concerns detected."
    - Review Status action
  - **Critical** (red):
    - "Severe operational degradation. Watch unavailable."
    - Dispatch Response action (immediate)

- **Watch Health Detail**:
  - Available (emerald, Wifi icon)
  - Limited (amber, with reason):
    - Stale-feed
    - Degraded-connectivity
    - Manual-verification
  - Unavailable (red, WifiOff icon)

- **Site Metrics**:
  - Guards on-site count
  - Active cameras (7/8 format)
  - 24h incidents count
  - Average response time

- **Site Actions**:
  - Open Tactical Map
  - Site Settings
  - Guard Roster
  - Camera Feed

- **Posture Filtering**:
  - Filter by Strong
  - Filter by At-Risk
  - Filter by Critical

---

## 8. Events - Forensic Timeline

### Added:
- **Scoped Review Mode**:
  - All Events view
  - Incident-focused (INC-DSP-4)
  - Site-focused (SE-01)

- **Event Type Filtering** (6 types):
  - Incident (red)
  - Dispatch (orange)
  - Guard-action (blue)
  - Client-comms (cyan)
  - Watch (purple)
  - System (gray)

- **Selected Event State**:
  - Gradient background highlight
  - Expanded detail panel
  - Verification badge

- **Forensic Payload Detail**:
  - JSON payload viewer
  - Syntax-highlighted display
  - Copy-friendly monospace font

- **Event Metadata**:
  - Timestamp (UTC)
  - Actor (who triggered)
  - Subject (what was affected)
  - Severity (Critical/Warning/Info)
  - Verification status

- **Linked Resources**:
  - Linked Incident display
  - Linked Site display
  - View Incident action
  - View Site action

- **Drilldown Actions**:
  - View Governance
  - View Ledger

---

## 9. Ledger - Provenance & Verification

### Added:
- **View Modes** (2 types):
  - Full Chain view
  - Incident-Focused view (INC-DSP-4)

- **Verification States** (3 variants):
  - **Verified** (emerald):
    - "Chain integrity confirmed, no tampering detected"
    - Hash validation passed
  - **Pending** (amber):
    - "Awaiting cryptographic verification"
    - Verify Now action
  - **Compromised** (red):
    - "Integrity violation detected"
    - Critical alert state

- **Provenance Chain Detail**:
  - Current block hash display
  - Previous block hash display
  - Chain link visualization
  - Block height tracking

- **Evidence Chain**:
  - Linked evidence items (EVD-CCTV-2441, etc.)
  - Evidence count per block
  - View Evidence actions

- **Cryptographic Detail**:
  - Hash values (monospace display)
  - Hash verification badges
  - Link integrity indicators

- **Drilldown Actions**:
  - View Event (event detail)
  - View Incident (incident detail)

---

## Reusable Components Created

### 1. WatchBadge.tsx
- Available/Limited/Unavailable states
- Color-coded badges
- Icon variants

### 2. LimitedReasonIcon.tsx
- Icons for each limited reason type
- Tooltip support
- Consistent sizing

### 3. FleetSummaryChip.tsx
- Clickable fleet counters
- Filter activation
- Active state styling

### 4. CommsStateChip.tsx
- Channel state badges
- Semantic colors
- Status icons

### 5. PushSyncHistory.tsx
- Timeline visualization
- Delivery state tracking
- Expandable detail

### 6. ReadinessIndicator.tsx
- System readiness badges
- Ready/Degraded states
- Color-coded status

---

## Design System Consistency

### Maintained Throughout:
✅ Premium gradient headers on all pages
✅ Consistent color palette per operational area
✅ Unified border system (#21262D)
✅ Consistent backgrounds (#0A0E13, #0D1117)
✅ Status badge system with semantic colors
✅ Smooth hover transitions
✅ Professional shadow system
✅ Typography hierarchy (headings, labels, monospace for technical data)
✅ Icon consistency (lucide-react, consistent stroke weights)

### Page-Specific Colors:
- Tactical: Purple/Indigo
- Clients: Blue/Cyan
- Dispatches: Red/Orange
- Governance: Green/Emerald
- Reports: Indigo/Purple/Pink
- Guards: Orange/Red/Pink
- Sites: Cyan/Blue/Indigo
- Events: Violet/Purple/Indigo
- Ledger: Emerald/Teal/Cyan

---

## Cross-Page Navigation Added

### Drilldown Patterns:
- Tactical → Dispatches (officer handoff)
- Clients → Room/thread context awareness
- Governance → Events, Reports, Ledger
- Reports → Governance, Events
- Guards → Schedule, Reports, Client Lane, VoIP
- Sites → Tactical Map, Settings, Guard Roster, Camera Feed
- Events → Governance, Ledger, Incidents, Sites
- Ledger → Events, Incidents

---

## Operational Depth Summary

### State Variants Implemented:
- ✅ 3 watch health states with recovery
- ✅ 6 communication channel states with fallback chains
- ✅ 3 sync health states for guards
- ✅ 3 site posture levels with tactical responses
- ✅ 4 report verification states
- ✅ 3 ledger verification states
- ✅ 6 event types with forensic detail
- ✅ 3 readiness system states
- ✅ Multiple blocker/non-blocker classifications

### Filtering & Scoping:
- ✅ Fleet filtering (Available/Limited/Unavailable)
- ✅ Event type filtering (6 types)
- ✅ Scope filtering (All/Internal/Partner)
- ✅ Site filtering (per-site roster)
- ✅ Incident-focused views
- ✅ Report status filtering

### Workflows Added:
- ✅ Watch recovery workflow
- ✅ Channel fallback workflow
- ✅ Report verification workflow
- ✅ Ledger verification workflow
- ✅ Partner dispatch routing
- ✅ Temporary identity management
- ✅ VoIP staging workflow

---

## Files Modified/Created

### Pages Updated:
1. `/src/app/pages/TacticalMap.tsx`
2. `/src/app/pages/Clients.tsx`
3. `/src/app/pages/Dispatches.tsx`
4. `/src/app/pages/Governance.tsx`
5. `/src/app/pages/Reports.tsx`
6. `/src/app/pages/Guards.tsx`
7. `/src/app/pages/Sites.tsx`
8. `/src/app/pages/Events.tsx`
9. `/src/app/pages/Ledger.tsx`

### Components Created:
1. `/src/app/components/WatchBadge.tsx`
2. `/src/app/components/LimitedReasonIcon.tsx`
3. `/src/app/components/FleetSummaryChip.tsx`
4. `/src/app/components/CommsStateChip.tsx`
5. `/src/app/components/PushSyncHistory.tsx`
6. `/src/app/components/ReadinessIndicator.tsx`

### Routes:
- All 12 routes configured in `/src/app/routes.tsx`
- AppShell navigation updated with all pages

---

## Result

All 9 pages now have complete operational depth with:
- ✅ Full state coverage for all operational scenarios
- ✅ Action workflows for controller operations
- ✅ Filtering and scoping capabilities
- ✅ Cross-page navigation and drilldowns
- ✅ Forensic detail where needed
- ✅ Premium ONYX command-center visual style maintained

**No workflows simplified. No features removed. Full operational complexity achieved.**

The ONYX platform is now a production-ready, world-class security operations command center with complete feature parity across all surfaces. 🔥
