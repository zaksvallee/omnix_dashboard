Design a premium reusable design system for ONYX, a high-end security operations and intelligence platform, and apply it to a polished desktop “Dispatch Command” page.

Context:
ONYX is a command-and-control platform for private security operations. It ingests alarms, intelligence feeds, and operational events, then supports dispatch creation, incident handling, intelligence review, and client communication. The interface must feel like a real executive-grade security control room product, not a generic SaaS dashboard.

Primary problem to solve:
The current Dispatch page is overloaded with too much data and too many controls presented with weak hierarchy. Redesign it so it remains data-rich, but becomes calm, readable, structured, and fast to use under pressure.

Create the design system first, then use it on the page.

Design system requirements:
Define a reusable UI system that can scale across Dispatch, Events, Sites, Guards, Dashboard, and client-facing surfaces.

Include reusable patterns for:
- page headers
- section containers
- KPI summary cards
- compact metric bands
- status chips
- alert / threat indicators
- primary / secondary / tertiary actions
- filter bars
- dropdown controls
- segmented controls
- data tables or structured lists
- timeline rows
- side detail panels
- empty states
- scrollable intelligence/activity panels
- modal/dialog styling

Design system guidance:
- Dark enterprise interface
- Premium and expensive-looking
- Clean, structured, disciplined
- High-density but not cluttered
- Built for operations, not marketing
- Sharp hierarchy, obvious scan paths
- Serious and trustworthy, not flashy
- Avoid generic “card soup”
- Avoid excessive glow, gimmicky sci-fi chrome, or gamer aesthetics

Visual direction:
- Base palette: deep navy, graphite, near-black blue
- Accent palette: cool blue/cyan primary
- Status colors:
  - green for healthy/executed
  - amber for warning/review
  - red for failed/critical
  - violet or steel-blue for intelligence/secondary data
- Use restrained color with strong contrast
- Strong typography hierarchy with bold page titles and compact utility labels
- Enterprise-quality spacing and alignment
- Crisp borders, subtle surfaces, clean separation
- Minimal visual noise

Typography:
- Bold, modern, technical, confident
- Clear distinction between:
  - page titles
  - section titles
  - KPI values
  - metadata labels
  - dense list content
- Prioritize readability at a glance

Layout goals:
- Design for desktop first (1440px to 1600px wide)
- The page should support large information density while staying easy to scan
- Organize content into clearly grouped operational zones
- Keep the most important status and actions above the fold
- Make the page feel intentionally composed, not like stacked controls

Now apply the system to a desktop “Dispatch Command” page.

Dispatch page requirements:

1. Header
- Title: Dispatch Command
- Context line: client / region / site
- Top-level operational status chips such as Decisions, Executed, Denied
- One clear primary action: Generate Dispatch
- Secondary actions for:
  - ingesting live feeds
  - ingesting news intelligence
  - loading feed files
- The header must feel clean and executive, not button-chaotic

2. Command Summary Zone
- A prominent summary area that immediately explains current operational posture
- Include:
  - threat / posture state
  - controller load / pressure
  - response timing
  - decision volume
  - intelligence volume
  - current operational issues
- This should be one of the strongest visual anchors on the page

3. Control Workspace
- Redesign the overloaded operational control area into clear grouped sections
- Include visual groupings for:
  - ingest / source operations
  - stress / benchmark controls
  - scenario and metadata inputs
  - persistence / import / export / snapshot actions
- The goal is to preserve many controls while making them visually manageable
- Reduce the feeling of a giant unstructured wall of pills/buttons

4. Intelligence Visibility
- Include a dedicated area for intelligence and recent feed awareness
- Support a compact, scrollable list of relevant intelligence items
- Show urgency/action states such as:
  - Advisory
  - Watch
  - Dispatch Candidate
- This should feel like operational triage, not just a generic news widget

5. Telemetry / Performance
- Include a structured telemetry section
- Present operational throughput, verification, performance, and benchmark metrics in a clean grouped format
- Replace noisy endless chips with clearer clusters, bands, or summary blocks

6. Historical / Recent Operational Activity
- Include a readable section for recent live ingests, poll health, benchmark history, or other recent operational traces
- Make this secondary but still useful
- It should not overpower the top summary or control workspace

7. Design for extensibility
- This Dispatch page must become the visual foundation for the rest of ONYX
- The patterns used here should clearly translate into:
  - Events page (forensic timeline / detail review)
  - Sites page (location posture / coverage)
  - Guards page (field team monitoring)
  - Dashboard page (executive overview)
  - Client app surfaces (simplified client-safe views)

Content expectations:
- Use realistic placeholder operational labels and metrics
- Make it feel like a real security operations product
- Use sections and component patterns that can be implemented cleanly in Flutter

Important constraints:
- Do not make it look like a finance dashboard clone
- Do not make it look like a consumer analytics app
- Do not rely on decorative visuals that add noise without function
- Keep it elegant, operational, dense, and highly legible

Output:
- One polished desktop frame for the reusable ONYX design system applied to the Dispatch Command page
- The result should be implementation-friendly and suitable as the core design reference for the rest of the app
