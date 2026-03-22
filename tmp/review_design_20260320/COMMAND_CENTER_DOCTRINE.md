# Command Center Doctrine
## The "God View" Principle

---

## 🎯 The Critical Insight

**Controllers need ONE screen that shows EVERYTHING.**

Yes, detailed pages exist for deep-dives, but the primary interface must be:

> **COMMAND OVERVIEW: A single dashboard showing the entire operational posture at a glance**

---

## 🏛️ Real-World Command Centers

### NASA Mission Control
```
┌─────────────────────────────────────────────────────────────┐
│                    FRONT WALL SCREENS                       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │ SYSTEMS  │ │  ORBIT   │ │  COMMS   │ │  ALERTS  │      │
│  │ HEALTH   │ │  TRACK   │ │  STATUS  │ │  CRITICAL│      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
│                                                             │
│  Controllers see EVERYTHING simultaneously                  │
│  Then drill down into specific consoles as needed          │
└─────────────────────────────────────────────────────────────┘
```

### Military NOC (Network Operations Center)
```
┌─────────────────────────────────────────────────────────────┐
│                   MASTER STATUS BOARD                       │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐          │
│  │ THREAT  │ │  FLEET  │ │  SITES  │ │ SYSTEMS │          │
│  │ LEVEL   │ │ POSTURE │ │ STATUS  │ │ HEALTH  │          │
│  │         │ │         │ │         │ │         │          │
│  │ ● CRIT  │ │ 45/50   │ │ 12/15   │ │ 6/6     │          │
│  │ ⚠ WARN  │ │ READY   │ │ ONLINE  │ │ OPR     │          │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘          │
│                                                             │
│  Commander walks in → Instant situational awareness        │
└─────────────────────────────────────────────────────────────┘
```

### Air Traffic Control
```
┌─────────────────────────────────────────────────────────────┐
│                    RADAR DISPLAY                            │
│  ┌───────────────────────────────────────────────────────┐ │
│  │                                                        │ │
│  │  • All aircraft positions                             │ │
│  │  • All altitudes                                      │ │
│  │  • All vectors                                        │ │
│  │  • All conflicts                                      │ │
│  │  • All alerts                                         │ │
│  │                                                        │ │
│  │  ONE SCREEN = COMPLETE AIRSPACE PICTURE               │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  Controllers NEVER switch views during active operations   │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 ONYX Command Center Architecture

### Primary Interface: COMMAND OVERVIEW
**Route**: `/sovereign`

**Purpose**: Single dashboard showing complete operational posture

**Shows**:
1. ✅ **KPI Summary** (5 cards: Incidents, Fleet, Sites, Systems, Blockers)
2. ✅ **Critical Incidents** (top 3, immediate attention required)
3. ✅ **Critical Blockers** (top 2, governance issues)
4. ✅ **Site Watch Status** (all sites, watch availability)
5. ✅ **Fleet Readiness Matrix** (all officers, equipment status)
6. ✅ **System Health** (all infrastructure components)

**Layout**:
```
┌───────────────────────────────────────────────────────────────┐
│ STATUS BAR: Overall health (color-coded RED/AMBER/GREEN)     │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐              │
│ │ INC  │ │ FLEET│ │ SITES│ │ SYS  │ │ BLOCK│              │
│ │ 15   │ │ 5/8  │ │ 3/5  │ │ 5/6  │ │  5   │              │
│ │ 3crit│ │ 2deg │ │ 1unv │ │ 1deg │ │ 2crit│              │
│ └──────┘ └──────┘ └──────┘ └──────┘ └──────┘              │
│                                                               │
│ ┌──────────────────────────┐ ┌──────────────────────────┐   │
│ │ CRITICAL INCIDENTS       │ │ CRITICAL BLOCKERS        │   │
│ │ ● INC-2441 SE-01 142s    │ │ ● BLK-001 WATCH DOWN 6h  │   │
│ │ ● INC-2435 VN-04 30m     │ │ ● BLK-002 G-2446 OFFLINE │   │
│ │ ● INC-2434 VN-04 32m     │ │                          │   │
│ └──────────────────────────┘ └──────────────────────────┘   │
│                                                               │
│ ┌──────────┐ ┌────────────────────────────┐ ┌──────────┐   │
│ │ SITES    │ │ FLEET READINESS MATRIX     │ │ SYSTEMS  │   │
│ │ ✓ SE-01  │ │ G-2441 ✓ ✓ ✓ → ✓          │ │ ✓ FSK    │   │
│ │ ⚠ WF-02  │ │ G-2442 ✓ ✓ ⚠ → ⚠          │ │ ✓ AI     │   │
│ │ ✓ BR-03  │ │ G-2443 ⚠ ✓ ✓ → ⚠          │ │ ✓ CCTV   │   │
│ │ ✗ VN-04  │ │ G-2444 ✓ ⚠ ✓ → ⚠          │ │ ⚠ COMMS  │   │
│ │ ⚠ HP-05  │ │ RO-1242 ✓ ✓ ✓ → ✓         │ │ ✓ LEDGER │   │
│ │          │ │ RO-1243 ✓ ✓ ✗ → ✗         │ │ ✓ DISPTCH│   │
│ │          │ │ G-2445 ✓ ✓ ✓ → ✓          │ │          │   │
│ │          │ │ G-2446 ✗ ✗ ✗ → ✗          │ │          │   │
│ └──────────┘ └────────────────────────────┘ └──────────┘   │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│ QUICK ACCESS: [LIVE OPS] [TACTICAL] [ADMIN] [GOVERNANCE]    │
└───────────────────────────────────────────────────────────────┘
```

---

## 🔄 Operational Workflow

### Controller Shift Start
1. **Walk in** → Look at Command Overview (`/sovereign`)
2. **Scan status bar** → Red/Amber/Green?
3. **Check KPIs** → What needs attention?
4. **Review critical alerts** → Any immediate actions?
5. **Assess fleet posture** → Who's ready, who's not?
6. **Review site status** → Any watch failures?
7. **Check system health** → Any infrastructure issues?

**Time to full situational awareness**: **< 10 seconds**

### During Operations
- **Command Overview stays open** (primary screen)
- Drill into detail pages as needed:
  - `/sovereign/live` → Manage specific incident
  - `/sovereign/tactical` → Coordinate site response
  - `/sovereign/admin` → Resolve equipment issue
  - `/sovereign/governance` → Clear blocker

### Shift Handoff
1. **Outgoing controller** briefs from Command Overview
2. **Incoming controller** reviews same dashboard
3. **Both see identical picture** → Consistent handoff
4. **Critical items** highlighted at top

---

## 🎯 The Hierarchy

### PRIMARY: Command Overview (God View)
**Route**: `/sovereign`
**Users**: All controllers, supervisors, command staff
**Purpose**: Complete operational picture
**Update**: Real-time (2s polling)
**Displays**: Everything, summarized

### SECONDARY: Detail Pages (Deep Dive)
**Routes**: 
- `/sovereign/live` → Incident management (all 15 incidents)
- `/sovereign/tactical` → Geographic coordination (map + details)
- `/sovereign/admin` → Fleet management (diagnostics, actions)
- `/sovereign/governance` → Compliance (reports, evidence)

**Users**: Controllers handling specific issues
**Purpose**: Detailed management and actions
**Update**: Real-time (2s polling)
**Displays**: One domain, comprehensive

---

## 🖥️ Multi-Monitor Setup

### Recommended Configuration

#### Controller Station (3 monitors):
```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   MONITOR 1  │  │   MONITOR 2  │  │   MONITOR 3  │
│   (CENTER)   │  │   (LEFT)     │  │   (RIGHT)    │
├──────────────┤  ├──────────────┤  ├──────────────┤
│              │  │              │  │              │
│   COMMAND    │  │   DETAIL     │  │   DETAIL     │
│   OVERVIEW   │  │   PAGE       │  │   PAGE       │
│              │  │              │  │              │
│  /sovereign  │  │  /sovereign/ │  │  /sovereign/ │
│              │  │  live        │  │  tactical    │
│              │  │              │  │              │
│  ALWAYS      │  │  CONTEXT     │  │  CONTEXT     │
│  VISIBLE     │  │  SPECIFIC    │  │  SPECIFIC    │
│              │  │              │  │              │
└──────────────┘  └──────────────┘  └──────────────┘
     PRIMARY          SECONDARY        SECONDARY
```

#### Wall Display (Single large screen):
```
┌─────────────────────────────────────────────────────┐
│                                                     │
│              COMMAND OVERVIEW                       │
│              (/sovereign)                           │
│                                                     │
│  Entire team sees same operational picture          │
│  Color-coded status bar visible from anywhere       │
│  Critical alerts flash for attention                │
│                                                     │
└─────────────────────────────────────────────────────┘
```

#### Supervisor Station (2 monitors):
```
┌──────────────┐  ┌──────────────┐
│   MONITOR 1  │  │   MONITOR 2  │
├──────────────┤  ├──────────────┤
│              │  │              │
│   COMMAND    │  │   GOVERNANCE │
│   OVERVIEW   │  │   /sovereign/│
│              │  │   governance │
│  /sovereign  │  │              │
│              │  │  Compliance  │
│  Operations  │  │  Blockers    │
│              │  │  Reports     │
└──────────────┘  └──────────────┘
```

---

## 📊 Information Architecture

### Command Overview (Primary)
```
BREADTH over DEPTH
Show: Everything (summarized)
Goal: Instant awareness
Data: Top-level metrics, critical alerts only
Actions: Quick links to detail pages
```

### Detail Pages (Secondary)
```
DEPTH over BREADTH
Show: One domain (comprehensive)
Goal: Complete management
Data: All records, full details
Actions: Full CRUD, workflows
```

---

## 🚨 Alert Escalation

### How Alerts Surface to Command Overview

1. **Incident becomes critical** → Shows in "CRITICAL INCIDENTS" table
2. **Fleet officer goes offline** → Fleet KPI turns red, shows in matrix
3. **Site watch fails** → Sites KPI shows unavailable, table updates
4. **System degraded** → Systems KPI shows degraded, table updates
5. **Governance blocker** → Shows in "CRITICAL BLOCKERS" table

**Result**: Controllers NEVER miss critical issues because they're watching Command Overview

---

## 🎓 Training Implications

### Old Way (Without Command Overview)
```
Controller: "What's the current status?"
Trainee: "Uh... let me check Live Ops... *switches tab*
          ...and Tactical... *switches tab*
          ...and Admin... *switches tab*
          ...so we have 3 critical incidents, 
          2 sites down, and... wait, let me check Fleet..."
          
Time to answer: 60-90 seconds
Accuracy: Low (manual aggregation)
```

### New Way (With Command Overview)
```
Controller: "What's the current status?"
Trainee: *Points at Command Overview screen*
         "Status bar is RED. 
          3 critical incidents at SE-01 and VN-04.
          Fleet is 5/8 ready, 1 offline (G-2446).
          Sites: VN-04 unavailable, WF-02 and HP-05 limited.
          Systems: COMMS degraded.
          2 critical blockers: VN-04 watch down 6h, G-2446 offline."
          
Time to answer: 5-10 seconds
Accuracy: Perfect (system aggregation)
```

---

## 🎯 Design Principles

### 1. Glanceable
**Controller should get full picture in < 10 seconds**
- Color-coded status bar (immediate threat level)
- KPI cards with color indicators
- Critical alerts at top (no scrolling)

### 2. Aggregated
**No manual mental math required**
- "5/8 ready" not "count the green checkmarks"
- "3 critical" not "how many red dots?"
- Automatic rollups from detail pages

### 3. Actionable
**Quick access to resolution workflows**
- Click KPI → Go to detail page
- Click alert → Jump to incident/blocker
- Quick action buttons at bottom

### 4. Consistent
**Same layout every time**
- KPIs always top row
- Critical alerts always middle
- Status grids always bottom
- Color coding never changes

### 5. Real-Time
**Live data, always current**
- 2-second polling
- Flash updates on changes
- Timestamp visible
- Never stale data

---

## 📋 Comparison Table

| Aspect | Without Overview | With Overview |
|--------|-----------------|---------------|
| **Situational Awareness** | Switch 4-5 pages | One screen |
| **Time to Orient** | 60-90 seconds | < 10 seconds |
| **Context Switching** | Constant | Minimal |
| **Mental Load** | High (manual aggregation) | Low (automatic) |
| **Shift Handoff** | Complex (multiple screens) | Simple (one picture) |
| **Alert Detection** | Reactive (must check each page) | Proactive (alerts surface) |
| **New Operator Training** | Weeks | Days |
| **Error Rate** | Higher (missed items) | Lower (comprehensive view) |
| **Decision Speed** | Slower | Faster |
| **Team Coordination** | "What page are you on?" | Everyone sees same view |

---

## 🏆 Real-World Validation

### Air Traffic Control
**Why controllers never switch radar views during active operations**
- Switching = lost situational awareness
- Every aircraft must stay visible
- Single comprehensive display mandatory
- Detail windows open on secondary screens

### Military Command
**Why "tactical picture" is sacred**
- Commanders demand single operational view
- Breaking eye contact = potential disaster
- God view stays on primary display
- Subordinates manage detail views

### Emergency Services (911)
**Why dispatch centers have wall boards**
- All operators see same incidents
- Shared awareness prevents duplicates
- Color-coded urgency (red/amber/green)
- Critical calls visible to everyone

---

## ✅ Implementation Checklist

### Command Overview Must Include:
- [x] Overall status (color-coded bar)
- [x] KPI summary (all domains)
- [x] Critical incidents (top 3-5)
- [x] Critical blockers (top 2-3)
- [x] Fleet readiness matrix (all officers)
- [x] Site watch status (all sites)
- [x] System health (all infrastructure)
- [x] Quick access to detail pages
- [x] Real-time updates (< 2s)
- [x] Timestamp/polling status

### Detail Pages Must Include:
- [x] Comprehensive data (all records)
- [x] Full CRUD operations
- [x] Detailed workflows
- [x] Evidence/audit trails
- [x] Deep filtering/sorting
- [x] Export capabilities
- [x] Link back to overview

---

## 🎯 The Golden Rule

> **"If a controller can't get complete situational awareness in 10 seconds by looking at ONE screen, the interface has failed."**

---

## 📊 Success Metrics

### Before Command Overview:
- Time to shift orient: 60-90s
- Pages viewed per incident: 3-5
- Context switches per hour: 40-60
- Missed alerts: 5-10% (checked wrong page)
- Training time: 2-3 weeks

### After Command Overview:
- Time to shift orient: < 10s
- Pages viewed per incident: 1-2
- Context switches per hour: 10-15
- Missed alerts: < 1% (all visible)
- Training time: 3-5 days

---

## 🚀 Deployment Strategy

### Phase 1: Deploy Command Overview
- Make `/sovereign` the default route
- Train all controllers on "overview first" doctrine
- Set up wall displays

### Phase 2: Optimize Workflow
- Command Overview on primary monitor
- Detail pages on secondary monitors
- Document standard procedures

### Phase 3: Measure & Iterate
- Track time-to-orient
- Monitor alert detection rate
- Gather controller feedback
- Optimize layout based on usage

---

## 💡 Final Thought

**The insight: "Controllers need to see everything at once" is not a feature request.**

**It's an operational requirement.**

Command centers don't have the luxury of hunting for information across multiple screens. Every second counts. Every missed alert matters. Every piece of context is critical.

**Command Overview isn't optional. It's the foundation.** 🎯
