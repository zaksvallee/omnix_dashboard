# ONYX Design Revision Changelog

## Overview
This revision adds **complete operational depth** to the ONYX platform while maintaining the premium command-center visual language. This is a **completeness pass**, not a redesign.

---

## ✅ **Completed Pages (5 of 12)**

### **1. Live Operations** ✨ (Top Priority - COMPLETE)
- **Queue filtering system** - 5 modes (Full, High Priority, Timing, Sensitive, Validation)
- **Draft cards** with AI cue chips (timing, sensitive, detail, reassurance, concise, next-step, formal)
- **Refine dialog** - Full draft editor with live AI cue updates, quick voice adjustments
- **Priority badges** - Visual distinction: "High Priority" (red) vs "Sensitive Reply" (purple)
- **First-run hint** - Dismissible queue filtering tutorial with "show tip again" control
- **"Show All" restore** - Clear active filter and return to full queue
- **Empty states** - Context-aware messaging for filtered vs full queue
- **Active incident comms pulse** in KPI cards
- **Client lane watch panel** - Communication channel status, voice profiles, incident context

### **2. Admin** ✨ (Second Priority - COMPLETE)
- **4 tabs**: AI Communications, System Controls, Entity Management, Watch & Identity
- **Learned Approval Styles section**:
  - Top learned style badge with gradient
  - Confidence progress bars (0-100%)
  - Usage count metrics
  - Tag system (timing, reassurance, dispatch, sensitive, tone, etc.)
  - Promote/Demote actions
  - View Context action
  - Add Tag action with suggested tags panel
- **Pending AI Draft Review**:
  - Awaiting Review count
  - High Priority count
  - Approved Today count
  - "Jump to Queue" action button
- **Pinned Voice Controls** - Global default voice (Auto, Concise, Reassuring, Formal)
- **Live Ops Tip Reset** - 4-state feedback (idle/busy/success/failure with icons)
- **Client Comms Audit** - 24h message stats, AI vs human approval rates, avg review time

### **3. Tactical** ✨ (Third Priority - COMPLETE)
- **Fleet watch system** with map visualization
- **Fleet summary row** with clickable chips:
  - Total Sites
  - Available (green)
  - Limited (amber)
  - Unavailable (red)
- **Watch state badges**: Available, Limited, Unavailable
- **Limited watch reasons**:
  - Stale Feed (with timestamp)
  - Degraded Connectivity
  - Fetch Failure
  - Manual Verification Required
- **Limited reason detail panels** - Specific error messages, "Recover Watch" action
- **Unavailable state handling** - Offline duration, "Alert Dispatch" button
- **Site metrics** - Camera count, guards on site
- **Temporary identity approvals**:
  - Active contractor/visitor list
  - Expiration countdowns
  - Extend/Expire action buttons
- **Route to Dispatch** and **Route to Tactical** drilldown actions
- **Fleet filtering** - Click chips to filter map view, "Show All" restore

### **4. Clients** ✨ (Fourth Priority - COMPLETE)
- **Client lane selector** - Multiple client lanes with pending draft badges
- **Communication channel states** (per lane):
  - Telegram: Ready / Blocked
  - SMS: Ready / Fallback / Idle
  - VoIP: Ready / Staging / Idle
  - Push: Idle / Needs Review
- **Channel state detail panels**:
  - **Telegram Blocked** - Error message, "Contact Client Support" action
  - **SMS Fallback Active** - Fallback reason explanation
  - **VoIP Call Staged** - "Place Call Now" / "Cancel Stage" actions
  - **Push Sync Needs Review** - "Review Push History" action
- **Backend probe status** - Healthy / Failed / Idle with last probe timestamp, "Retry Probe"
- **Off-scope routed lane indicator** - Partner dispatch routing notification
- **Pending AI drafts count** - Per-lane pending review metric with "Review Drafts" action
- **Learned approval style display** - AI-detected communication patterns per client
- **Pinned voice controls** - Per-lane voice profile override (Auto, Concise, Reassuring, Formal)
- **Message history** - Timeline with state badges (Delivered, Queued, Blocked, Draft)

### **5. Dispatches** ✨ (Fifth Priority - COMPLETE)
- **System controls panel**:
  - Ingest Controls (Active/Paused with pulse indicator)
  - Live Polling Controls (Active/Paused with refresh animation)
  - Radio Queue Controls (Listening/Paused with pulse)
  - Telemetry View (Normal/Heavy toggle)
- **Readiness indicators**:
  - Wearable Readiness (Ready/Degraded/Offline)
  - Radio Readiness (Ready/Degraded/Offline)
  - Video Readiness (Ready/Degraded/Offline)
- **Active dispatch queue**:
  - Priority badges (P1-CRITICAL red, P2-HIGH orange, P3-MEDIUM amber)
  - Status states (ACTIVE, EN_ROUTE, ON_SITE, CLEARED)
  - Officer assignments
  - Dispatch timestamps
- **Queue states**:
  - Quiet queue (empty state)
  - Active queue (live dispatches)
  - Cleared dispatches
- **Intelligence panel**:
  - Severity levels (Info, Warning, Critical)
  - Pinned/Dismissed states
  - Pin/Dismiss actions per item
- **Partner dispatch workflow** - "Route Dispatch" to off-scope partners
- **Open Report workflow** - Generate incident reports

---

## 🎨 **New Reusable Components Created**

1. **QueueStateChip.tsx** - Filterable queue state buttons (5 variants)
2. **CueChip.tsx** - AI review cue badges (8 types)
3. **DraftCard.tsx** - Client communication draft cards with priority gradients
4. **RefineDialog.tsx** - Full-screen draft editor with live AI feedback
5. **LearnedStyleCard.tsx** - AI-detected approval pattern cards
6. **WatchBadge.tsx** - Fleet watch health indicators (Available/Limited/Unavailable)
7. **FleetSummaryChip.tsx** - Fleet summary statistics with click filters
8. **CommsStateChip.tsx** - Communication channel state indicators
9. **ReadinessIndicator.tsx** - System readiness cards (Ready/Degraded/Offline)

---

## 📊 **State Coverage Added**

### **Live Operations States:**
- ✅ No pending replies (empty)
- ✅ Filtered queue empty
- ✅ Full queue with drafts
- ✅ High-priority only view
- ✅ Timing-only view
- ✅ Sensitive-only view
- ✅ Validation-only view
- ✅ First-run hint visible/dismissed

### **Admin States:**
- ✅ No learned styles
- ✅ One learned style
- ✅ Multiple learned styles
- ✅ Pending draft review (0, 1, 2+ drafts)
- ✅ Reset tip: idle/busy/success/failure

### **Tactical States:**
- ✅ Available watch (healthy)
- ✅ Limited watch (stale feed)
- ✅ Limited watch (degraded connectivity)
- ✅ Limited watch (fetch failure)
- ✅ Limited watch (manual verification)
- ✅ Unavailable watch (offline)
- ✅ Mixed fleet (some healthy, some limited)
- ✅ Temp identity active/expiring

### **Client States:**
- ✅ Telegram ready
- ✅ Telegram blocked
- ✅ SMS fallback active
- ✅ SMS idle
- ✅ VoIP staging
- ✅ VoIP ready
- ✅ VoIP idle
- ✅ Push needs review
- ✅ Push idle
- ✅ Backend probe healthy
- ✅ Backend probe failed
- ✅ Backend probe idle
- ✅ Off-scope routed lane
- ✅ Message states (delivered, queued, blocked, draft)

### **Dispatch States:**
- ✅ Ingest active/paused
- ✅ Live poll active/paused
- ✅ Radio queue active/paused
- ✅ Telemetry normal/heavy
- ✅ Wearable ready/degraded/offline
- ✅ Radio ready/degraded/offline
- ✅ Video ready/degraded/offline
- ✅ Queue empty (quiet)
- ✅ Queue active
- ✅ Dispatch: ACTIVE/EN_ROUTE/ON_SITE/CLEARED
- ✅ Intelligence: pinned/dismissed

---

## 🚧 **Remaining Pages (7 of 12)**

### **To Complete:**
6. **Governance** - Morning sovereign report, readiness blockers, partner chains
7. **Reports** - Report shell, preview workflow, partner-scope reporting
8. **Guards** - Sync health, schedule/reports actions, workforce ops
9. **Sites** - Watch posture, tactical drilldown, health variants
10. **Events** - Scoped filtering, forensic drilldowns, immutable audit
11. **Ledger** - Incident focus, verification states, provenance navigation
12. **App Shell** - Full route set, scope breadcrumbs, cross-route continuity

---

## ✅ **Design Principles Maintained**

✅ Premium dark command-center aesthetic  
✅ Gradient accent cards for priority/severity  
✅ Color-coded semantics (red=critical, amber=warning, cyan=operational, emerald=success, purple=analysis)  
✅ Uppercase tracking on section headers  
✅ Tabular numbers for all metrics  
✅ Hover states with border glow effects  
✅ Professional Lucide icon usage  
✅ Dense information layout optimized for 1920px+ screens  
✅ Consistent border radius (lg=12px, xl=16px, 2xl=24px)  
✅ Consistent spacing scale (p-4/5/6 for density control)  

---

## 📈 **Progress**

**Status:** 5 of 12 pages complete with full operational depth  
**Visual Quality:** Premium command-center design maintained  
**Operational Completeness:** Live Ops, Admin, Tactical, Clients, Dispatches are implementation-ready  
**Next Priority:** Governance, Reports, Guards, Sites, Events, Ledger, Shell
