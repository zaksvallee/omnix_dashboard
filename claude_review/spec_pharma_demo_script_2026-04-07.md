# Spec: ONYX Demo Script — Pharmaceutical Wholesaler
- Date: 2026-04-07
- Author: Claude Code
- Type: Sales / Pre-Sales Demo Script
- Runtime: 15 minutes
- Audience: Pharma wholesaler security decision-maker (Head of Security, Risk, or Operations Director)
- Read-only: yes

---

## Context for the Presenter

A pharmaceutical wholesaler's security posture is not like retail or hospitality. They carry:

- Schedule 5 / controlled substance stock (regulatory chain-of-custody obligations)
- High-value biologics and cold-chain medications in bonded warehouses
- A constant flow of delivery vehicles through a controlled loading dock
- Regulatory exposure to SAHPRA, MCC, or equivalent bodies requiring tamper-evident audit records
- Guards who operate largely unsupervised on night shift in a high-theft environment

Their number-one fear is not a smash-and-grab. It is an **inside job they cannot prove happened** — or a regulatory audit they cannot survive because their records are paper-based or siloed across DVR footage, guard logbooks, and Excel sheets.

ONYX speaks directly to that fear.

---

## Before You Walk In

- Load the app on a tablet or laptop in **dark theme**, full screen
- Pre-navigate to the **Dashboard** (not Live Operations)
- Confirm demo data shows:
  - At least one morning sovereign report generated
  - 2–3 guard sync events in the last 24 h
  - At least one vehicle visit in the ledger
  - One AI alert ready in the queue (loading bay camera preferred)
- Silence all notifications except ONYX
- Know the prospect's site name — personalise it in the demo if the app supports it

---

## The 15-Minute Run

---

### Minute 0–1 | Opening — Plant the Problem

**What to say:**

> "Before I show you anything, let me ask you one question. If SAHPRA — or your insurance underwriter — called you right now and asked for a complete, timestamped, tamper-evident record of everything that happened at your loading dock last Tuesday night — could you hand them that in under an hour?"
>
> Most operations can't. They have camera footage on a DVR that may or may not be online, a guard logbook that was written in pen, and a dispatch SMS trail that lives in someone's WhatsApp. That is not a chain of custody. That is a liability.
>
> What I'm going to show you in the next 15 minutes is what it looks like when all of that is unified — in real time, on one screen, with a cryptographic audit trail that cannot be altered after the fact.

**Why this works:** You are not selling features. You are naming their single biggest regulatory and forensic risk in the first 60 seconds. Everything after this lands as a solution, not a pitch.

---

### Minute 1–3 | Screen 1 — Dashboard (Morning Sovereign Report)

**Navigate to:** `Dashboard` (default landing screen)

**What to click:**
- Point to the **Morning Sovereign Report** card at the top of the dashboard
- Open the report (tap/click the card or the "Open" button)
- Scroll through the summary: guard sync status, overnight event count, site health posture

**Story to tell:**

> "Every morning at 06:00, before your first shift supervisor even gets to site, ONYX has already compiled a full operational summary of the night before. Guard check-ins, camera health, incident count, and a posture score. It lands here automatically — no human had to write it.
>
> Your night-shift manager doesn't get to rewrite history in the morning. The report was already sealed at 06:00."

**What to emphasise:**

- The report is generated automatically — not manually
- It represents the state of the site as it was, not as someone remembered it
- For pharma: this is your first line of evidence for a regulatory query

---

### Minute 3–5 | Screen 2 — Live Operations (War Room + Camera Check)

**Navigate to:** `Live Operations`

**What to click:**
- Point to the **War Room Rail** — active site scope with live command status
- Point to the **Active Board** — current outstanding actions and decisions
- Click **CAMERA CHECK** — show the camera health state

**Story to tell:**

> "This is what your controller sees right now. Not a wall of camera feeds — those are useless at scale. What they see is structured: what needs attention, what has been actioned, and what is waiting on a decision.
>
> The Camera Check tile tells your controller which cameras are online, which are degraded, and which have not sent a heartbeat in the last cycle. In a bonded pharmaceutical warehouse, a camera that went dark at 02:17 and came back at 02:43 is not a 'technical issue'. It is a 26-minute window your insurer will ask you about. ONYX flags it."

**What to emphasise:**

- Structured command view — not passive footage monitoring
- Camera health gaps are surfaced, not hidden
- The controller is guided toward decisions, not left to watch feeds

---

### Minute 5–7 | Screen 3 — AI Queue (Anomaly at the Loading Bay)

**Navigate to:** `AI Queue` (via navigation rail or CCTV shortcut from Live Ops)

**What to click:**
- Open the AI Queue page
- Select the pre-loaded **AI Alert** for the loading bay camera
- Show the alert detail: site, camera, time, AI decision label
- Point to **View Camera** action
- Point to **Open Agent** action (if an incident reference is attached)

**Story to tell:**

> "Your overnight guard is doing his rounds. At 02:31, the AI detects a person in the loading bay area — outside the pre-cleared window. This is not a motion trigger. ONYX's vision model has assessed the scene and surfaced it as an anomaly worth reviewing.
>
> The controller doesn't need to scrub through eight hours of footage. The AI has already done the triage. The controller's job is now a binary decision: promote this to an incident, or mark it reviewed.
>
> For controlled substance storage, that distinction — and the timestamp of that decision — is what matters to your compliance team."

**What to emphasise:**

- AI does the triage; the human makes the decision
- Every decision is timestamped and attributed (who reviewed, at what time, with what outcome)
- No footage scrubbing — the alert is pre-located

---

### Minute 7–9 | Screen 4 — Dispatch (Deploy + Evidence Link)

**Navigate to:** `Dispatch` (from Live Ops or navigation rail)

**What to click:**
- Show the **Dispatch Board** with one or two active dispatch items
- Open a dispatch card
- Point to the **evidence return receipt** section if visible
- Point to the action row: execute, track, open report, open client handoff

**Story to tell:**

> "When the controller promotes that anomaly to a dispatch — either sending the on-site guard or calling an armed response — that action is now part of the record. The dispatch is logged, the time is locked, and when the guard responds, that response is appended to the same chain.
>
> Compare this to calling someone on a radio and hoping they log it. In ONYX, the dispatch, the response time, and the outcome are all in one place. If your insurer or regulator asks 'what happened at 02:31 on Tuesday', you open this screen and hand them the record."

**What to emphasise:**

- Dispatch is not a phone call — it is a logged, timestamped command
- Response time is automatically captured
- Every dispatch links back to the originating event and forward to the outcome

---

### Minute 9–11 | Screen 5 — Vehicle BI Dashboard (Loading Dock Throughput)

**Navigate to:** Dashboard → **Vehicle BI panel** (scroll down, or accessible via the Sovereign Report vehicle section)

**What to click:**
- Show the **Total Vehicles** card
- Show the **Average Dwell Time** card
- Show the **Repeat Customer Rate** card
- Show the **Hourly Bar Chart** — entry volume by hour
- Show the **Entry → Service → Exit Funnel**

**Story to tell:**

> "Now let me show you something specific to your operating context. Every vehicle that enters your loading dock is tracked — entry time, dwell time, exit time. The system builds this funnel automatically from camera events.
>
> You can immediately see: how many vehicles came in today, how long the average delivery vehicle stayed, and — critically — whether any vehicle entered the dock but didn't register an exit in the expected window. That's a vehicle that may still be on your property, or a vehicle whose exit was not captured.
>
> For a pharma operation, untracked dwell time at a loading dock is a controlled substance audit risk. This report gives you the data to close that gap."

**What to emphasise:**

- The funnel shows entry vs. service vs. exit — gap detection is built in
- Repeat vehicle rate tells you who is regular and who is anomalous
- Hourly chart reveals patterns (e.g., unexpected delivery volumes at 23:00)

---

### Minute 11–13 | Screen 6 — Sovereign Ledger (Chain of Custody)

**Navigate to:** `Sovereign Ledger` (via navigation rail or from a dispatch/evidence link)

**What to click:**
- Show the **ledger entry list** — each entry as a card with timestamp, actor, and record code
- Open one entry — show the `hash` and `previousHash` fields
- Click **Verify Chain** button
- Show the **Export Ledger** action
- Point to the cross-links: "Open Dispatch", "Open CCTV", "Open Report"

**Story to tell:**

> "This is the part that matters most for compliance. Every event in ONYX — guard check-ins, AI alerts, dispatch decisions, camera health flags — is written to this ledger as an immutable, hash-chained record.
>
> Each record carries its own cryptographic hash and the hash of the record before it. If any record is altered after the fact, the chain breaks. This is not a log file that someone can edit. It is a tamper-evident audit trail.
>
> When your regulator or insurer asks for evidence, you click Export Ledger. What comes out is a verifiable, signed record of exactly what happened and in what order. No human summary. No reconstructed timeline. The actual record."

**What to emphasise:**

- Hash-chained = tamper-evident (no editing after the fact)
- Verify Chain is a one-click integrity check
- Export goes directly to the regulator — no translation layer needed
- Every entry cross-links to the full event context (dispatch, CCTV, report)

---

### Minute 13–14.5 | Screen 7 — Governance (Posture at a Glance)

**Navigate to:** `Governance` page (or Tactical — pick whichever shows the oversight snapshot most cleanly)

**What to click:**
- Show the **Oversight Snapshot** — readiness score, critical count, event trail
- Point to **Open Reports Workspace**
- Point to **Open Events Scope**

**Story to tell:**

> "Finally — for your Head of Security or your Risk committee — this is the view that tells them whether the operation is in posture right now without calling anyone. Readiness score, outstanding critical items, and the full event trail for any time window they choose.
>
> No email to the shift manager. No waiting for a morning debrief. The state of your operation is visible, in real time, from any device."

**What to emphasise:**

- Governance view is for management — not controllers
- Posture score is a single number that summarises site health
- It eliminates the information gap between the control room floor and management

---

### Minute 14.5–15 | Close

**Navigate to:** Nothing — stay on Governance or return to Dashboard. Let the screen breathe.

**What to say:**

> "What you've just seen is not a CCTV upgrade. It is a compliance infrastructure. Every camera event, every guard action, every vehicle arrival, every dispatch decision — captured, chained, and ready to present to anyone who asks.
>
> For a pharmaceutical wholesaler, that is not a nice-to-have. In the current regulatory environment, it is the difference between surviving an audit and failing one.
>
> The next step I'd suggest is a scoping call with our integration team. We can have your first site connected — cameras, guards, dispatch — in two to three weeks. What does your current DVR setup look like?"

**Why this close works:**

- You end with a compliance framing, not a features summary
- The final question is diagnostic, not a price question — it moves the conversation into scoping
- You are already assuming they are buying; the question is about their environment, not their decision

---

## Fallback Moves

| If… | Do this… |
|-----|----------|
| The AI Queue has no pre-loaded alert | Go to Live Ops → Camera Check instead. Story: "The system flags when cameras go dark. Here's one that had a 26-minute gap last night." |
| Vehicle BI panel shows no data | Skip to Sovereign Ledger early. Say: "The vehicle intelligence layer needs one week of baseline data — let me show you what the audit chain looks like once vehicles are flowing." |
| They ask about integration with their existing DVR | "ONYX bridges Hikvision and generic RTSP natively. We can run a preflight against your DVR in the scoping call — the integration team will tell you in 30 minutes whether your current cameras are compatible." |
| They ask about cloud vs. on-prem | "ONYX runs edge-first — your footage stays on your infrastructure. The ledger hash and alert metadata sync to our cloud. No raw footage leaves your site unless you export it." |
| They push on price | "We price by site, not by camera count. For a single-warehouse operation your size, the number is straightforward. Let me get the right person on a call so we're quoting the actual scope." |

---

## Key Phrases to Land

- **"Tamper-evident audit trail"** — use this once, deliberately. It is the regulatory phrase that lands with pharma compliance officers.
- **"The chain breaks if anyone edits it"** — say this when showing the hash fields in the Sovereign Ledger.
- **"The dispatch is the record"** — use when showing the Dispatch Board. Contrasts with radio/WhatsApp.
- **"The AI triages; the human decides"** — use in the AI Queue section. Addresses the "will it replace my guards?" objection before they raise it.
- **"No footage leaves your site"** — proactively addresses data sovereignty concerns common in pharma.

---

## What NOT to Do

- Do not open raw camera feeds unless specifically asked — the story is about structured command, not CCTV.
- Do not mention specific competitor names.
- Do not promise specific regulatory certifications unless you have confirmed them with the product team.
- Do not show the Administration or Agent configuration pages — they read as complexity, not capability.
- Do not let the demo run over 15 minutes. End at the close even if they haven't asked every question — the questions come after.
