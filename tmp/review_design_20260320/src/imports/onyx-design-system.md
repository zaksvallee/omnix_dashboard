Design a complete visual system and full product UI for ONYX, a premium security operations, dispatch, and intelligence platform.

Goal:
Create a cohesive, reusable design system and then apply it across the full ONYX product so every page feels like part of one polished enterprise-grade command platform.

About ONYX:
ONYX is a high-end security operations platform used by a control room / command center. It ingests alarms, live feeds, intelligence signals, and operational events, then supports:
- dispatch creation
- incident monitoring
- event forensics
- site monitoring
- guard operations
- intelligence triage
- client communication
- executive operational visibility

The platform must feel:
- premium
- operational
- calm under pressure
- data-rich but readable
- built for professionals in active security environments

Primary design problem:
The current product is functionally rich but visually overloaded. Many pages feel too dense, too flat, and too chaotic. The redesign must keep the platform information-rich while dramatically improving:
- readability
- hierarchy
- scan speed
- consistency
- composure
- visual trust

Create a reusable design system first, then apply it to the full site.

PART 1: Reusable ONYX Design System

Create a reusable design language for the whole product.

Define:
1. Color system
- Primary background colors
- Secondary/raised surface colors
- Borders/dividers
- Text hierarchy colors
- Accent colors
- Semantic state colors:
  - success
  - warning
  - danger
  - info/intelligence
- Ensure high contrast and premium dark-theme usability

2. Typography system
- Page titles
- Section titles
- Card titles
- KPI values
- Body text
- Dense data labels
- Utility metadata
- Button labels
- Make hierarchy obvious and scannable

3. Spacing and layout rules
- Desktop-first system
- Strong alignment and rhythm
- Comfortable density without clutter
- Reusable grid and panel spacing
- Clear grouping of controls and data

4. Component system
Create reusable styles/patterns for:
- app shell / nav
- page headers
- section containers
- KPI tiles
- metric bands
- status chips
- threat indicators
- action buttons (primary, secondary, tertiary)
- icon buttons
- dropdowns
- segmented controls
- filter bars
- search / input fields
- timeline rows
- data lists
- table-like metric groups
- side detail panels
- modals/dialogs
- empty states
- scrollable feed cards
- alert banners
- inline status messages

5. Product tone
- Dark enterprise command platform
- Expensive, calm, serious, disciplined
- Minimal visual noise
- Strong information hierarchy
- Avoid generic consumer SaaS visuals
- Avoid excessive glow or sci-fi gimmicks
- Avoid finance-dashboard cloning
- Make it feel like a real command center platform

Visual direction:
- Base: deep navy, graphite, black-blue
- Primary accent: cool blue/cyan
- Support accents: steel blue, violet for intelligence, amber for warnings, red for critical, green for healthy
- Crisp edges, subtle depth, polished surfaces
- Executive-grade dark UI with real operational authority

The design system must be reusable across all pages below.

PART 2: Full Site / Key Screens

Design a complete desktop product UI system across these ONYX pages. All pages should clearly share the same system but each should feel purpose-built for its workflow.

A. Dashboard
Purpose:
Executive operational overview

Needs:
- global status summary
- operational posture
- top KPIs
- site ranking / posture
- dispatch performance
- intelligence overview
- quick trend visibility

Design goal:
Clean executive summary page that is readable in seconds, not a cluttered analytics wall.

B. Dispatch Command
Purpose:
Primary control-room dispatch workspace

Needs:
- page header with client / region / site context
- top-level status chips
- primary action: Generate Dispatch
- ingest actions:
  - live feeds
  - news intelligence
  - file load
- structured control workspace for:
  - scenario and metadata
  - stress / benchmark controls
  - persistence / import / export / snapshot actions
- intelligence review panel
- telemetry / performance summary
- recent live ingest / operational history

Design goal:
This is the core command page. It must support heavy information density but feel ordered, powerful, and easy to operate under pressure.

C. Events
Purpose:
Forensic event review and timeline inspection

Needs:
- summary strip
- filter console
- searchable / filterable event timeline
- clearly readable event cards
- selected event detail panel
- event metadata presentation
- support for very detailed records without visual fatigue

Design goal:
Calm forensic review surface. Detailed, but structured and readable.

D. Sites
Purpose:
Monitor security posture by site

Needs:
- site cards or ranked rows
- health/status indicators
- active incidents
- response performance
- recent intelligence affecting each site
- site selection and detail panel
- ability to compare sites at a glance

Design goal:
Operational estate / site management view. Clean posture comparison and easy anomaly spotting.

E. Guards
Purpose:
Field team operations and guard visibility

Needs:
- active guards
- check-ins
- patrol progress
- arrivals / assignments
- readiness / availability
- high-level staffing visibility
- selected guard detail panel

Design goal:
Field operations view that makes human deployment readable and actionable, not just a list of names.

F. Ledger
Purpose:
Operational accountability / evidence / execution trace

Needs:
- clean trace-oriented layout
- readable event/accountability records
- strong metadata treatment
- filters
- detail panel or modal
- professional audit feel

Design goal:
Authoritative, structured, trustworthy audit surface.

G. Reports
Purpose:
Operational reporting and historical analysis

Needs:
- report summaries
- status / generation state
- trend sections
- report lists
- detail and export affordances

Design goal:
Readable, executive-friendly reporting page, not a raw admin page.

H. Client App / Client Surface
Purpose:
Client-facing operational communication

Needs:
- simplified, client-safe version of the ONYX system
- notifications / alerts
- incident feed
- direct chat
- community / estate chatrooms
- acknowledgement flows
- cleaner, softer hierarchy than control room pages
- still clearly part of the same brand/system

Design goal:
Trusted premium client experience derived from the same core design language, but less dense and more approachable.

PART 3: UX Principles

Apply these across the entire site:
- Every page must have a clear primary read path
- Use progressive disclosure for detailed data
- Dense data should be grouped, not scattered
- Controls should be organized into functional zones
- Summary first, detail second
- Avoid giant piles of buttons and chips with no hierarchy
- Use side panels, grouped cards, and structural spacing to control complexity
- Make each screen feel intentionally composed

PART 4: Implementation Awareness

Design these screens in a way that is realistic to implement in Flutter:
- reusable section patterns
- reusable card structures
- reusable chip and button styles
- reusable data panel layouts
- responsive desktop-first structure that can adapt later

Output requirements:
- Create a complete desktop design system applied across the major ONYX pages
- Show each page as part of one coherent product
- Desktop-first, ideally around 1440px to 1600px width
- Use realistic placeholder data and labels
- Make the result polished enough to serve as the primary implementation reference for the full app

Important:
The final result should look like a serious, premium security command platform with excellent information design, not a generic admin dashboard.
