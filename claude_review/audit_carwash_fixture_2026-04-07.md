# Audit: carwash_bi_demo_report.json — Fixture Review

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `test/fixtures/carwash_bi_demo_report.json`
- Read-only: yes

---

## Executive Summary

The fixture tells a coherent Saturday carwash story with a realistic morning rush curve, two concrete anomaly moments, and internally consistent counts. As a demo asset it is 70% of the way there. The remaining 30% is undermined by three structural problems: the entire `receiptPolicy` block is null-state garbage that will render as empty on screen, three "suspicious short visits" are referenced in the headline numbers but have no corresponding exception entries, and both loitering vehicles are still `ACTIVE` at end-of-shift despite having last-seen timestamps 4–6 hours before the window closed — which will either look like a bug or demand an explanation that the fixture doesn't provide.

Fix those three issues and this becomes a genuinely strong demo moment.

---

## Business Story Assessment

**Does it tell a compelling story?** Mostly yes. The Saturday morning peak curve (2 → 4 → 6 → 12 → 10 → 5 → 3 → 2 → 2 → 1) is immediately readable and credible. A business owner will recognise it as their own Saturday. The two loitering flags give the AI a visible "win" — it caught something the human hadn't acted on. The 27% repeat-customer rate (10/37 unique vehicles) is the kind of loyalty metric an owner will find personally satisfying if surfaced clearly.

What the fixture currently buries or omits:
- There is no revenue proxy (even an estimated wash count × avg price would ground the story)
- The repeat rate is computable from the raw numbers but never stated as a rate anywhere
- The peak-hour story (`peakHourVisitCount: 12` at 10:00–11:00) is present but the operational implication (schedule extra staff from 09:45) is left for the viewer to derive

---

## Are the Numbers Realistic for a SA Carwash?

**Overall: believable for a small-to-medium hand-wash operation.**

| Metric | Fixture value | SA benchmark assessment |
|---|---|---|
| Total visits (Saturday, 10 hrs) | 47 | Low-end plausible. A busy Joburg hand-wash does 80–150. 47 suits a quieter site or a single-bay tunnel. |
| Peak hour | 12 vehicles (10:00–11:00) | Correct day-part. SA carwash peaks are 09:00–12:00 Saturday. |
| Average dwell time | 14.6 min | Realistic for a basic exterior wash + vacuum. Full valet would be 30–45 min. |
| Repeat vehicles | 10 / 37 unique = 27% | Plausible for a neighbourhood site with regulars. |
| Hourly breakdown sum | 2+4+6+12+10+5+3+2+2+1 = **47** ✓ | Internally consistent. |
| Entry / exit reconciliation | 47 in − 41 exit − 4 active − 2 incomplete = **0** ✓ | Clean. |
| AI decisions vs overrides | 8 AI / 1 human | Reasonable 12.5% override rate for a quiet Saturday. |
| Integrity score | 99 / 100 | Fine for a demo; the missing point should be explainable on demand. |

One number that looks off: `unknownSignals: 47` matches the vehicle count exactly, implying 100% of vehicle signals are unidentified. Combined with `knownIdentitySignals: 0`, this suggests the license-plate identity layer has no enrolled plates at all. For a live site this would be a real gap; for a demo it will look like the feature is broken rather than simply empty. See P2 below.

---

## What Would a Business Owner Find Most Impressive?

Ranked by likely impact in a live demo:

1. **Loitering at Wash Bay 1 for 45 minutes** — ND456783 entered at 08:58, still stuck in Wash Bay 1 at 09:43. That is a bay blockage during the pre-peak ramp. The system caught it; the manager may not have noticed. This is the single most visceral demo moment.
2. **Exit-lane blockage during peak hour** — GP128440 held the exit lane from 10:36 to 11:22 (46 min) while 12 cars were trying to flow through the peak hour. That is a direct revenue and queue-length story.
3. **27% repeat customer rate** — owners love knowing regulars are coming back. Surfacing this as a loyalty KPI would land well.
4. **Peak hour traffic curve** — visual proof that staffing decisions are now data-driven.
5. **AI decision ratio** — 8 decisions, 1 override. This tells the owner "the system is working autonomously and your manager only had to intervene once."

---

## Suspicious Patterns — Good Demo Moments

Both loitering exceptions are the right kind of anomaly for a demo:

- **ND456783** (`scoreLabel: WATCH`) — 45 minutes in Wash Bay 1, stuck at `ENTRY -> WASH BAY 1 (ACTIVE)`. Good scenario: bay equipment failure? customer dispute? staff distraction?
- **GP128440** (`scoreLabel: WATCH`) — 46 minutes holding the exit lane during peak hour. Good scenario: customer waiting for a manager? blocked by a double-parked car?

However, **three "suspicious short visits" are counted but invisible**. `suspiciousShortVisitCount: 3` appears in the summary line but there are zero matching entries in `exceptionVisits`. For a demo, this is a missed opportunity — short drive-offs (entered, didn't pay, left) are exactly the kind of theft-vector story that justifies the platform to a security-conscious owner. Either populate those three entries or drop the count to zero.

---

## Findings

### P1 — `receiptPolicy` block is entirely null-state
- **Action:** REVIEW
- **Finding:** Every field in `receiptPolicy` is either `0`, `""`, or an empty string. The `executiveSummary`, `headline`, `summaryLine`, `latestReportSummary`, and all branding/investigation fields are blank.
- **Why it matters:** If any UI widget reads this block, it will render as an empty card or flash a "no data" state mid-demo. This is the most visually damaging issue in the fixture.
- **Evidence:** `carwash_bi_demo_report.json` lines 55–76 — all values are `0` or `""`
- **Suggested follow-up:** Either populate the block with plausible values for the scenario (e.g. `generatedReports: 1`, a `headline` and `summaryLine` matching the shift) or strip the block from the demo fixture entirely so the UI never tries to render it.

### P1 — Three suspicious short visits have no exception entries
- **Action:** REVIEW
- **Finding:** `vehicleThroughput.suspiciousShortVisitCount: 3` is stated in the summary line (`"Short visits 3"`) but `exceptionVisits` contains only the two loitering entries. The short-visit exceptions are missing.
- **Why it matters:** A business owner asking "show me those three suspicious short visits" will see nothing. Worse, any list widget that iterates `exceptionVisits` will show only 2 rows while the header says 3. The count and the data contradict each other.
- **Evidence:** Lines 93–94 (summaryLine with "Short visits 3"), lines 119–150 (exceptionVisits with only 2 entries)
- **Suggested follow-up:** Add three short-visit exception entries (sub-5-minute visits, e.g. drive-offs), or set `suspiciousShortVisitCount: 0` and remove "Short visits 3" from the summaryLine.

### P2 — Both loitering vehicles are ACTIVE with last-seen timestamps 4–6 hours before shift end
- **Action:** REVIEW
- **Finding:** ND456783 was last seen at 09:43; GP128440 at 11:22. The shift window closes at 16:00. Both are still `statusLabel: ACTIVE`. Either the system lost track of them for hours (a tracking gap) or they were truly there until 16:00 (an extreme edge case). Neither interpretation is obvious from the data.
- **Why it matters:** A sharp demo viewer will notice the time gap and ask why a vehicle last seen at 09:43 is still "active" six hours later. Without an explanation, it reads as a tracking fault.
- **Evidence:** Lines 127–128 (`lastSeenAtUtc: "2026-04-04T09:43:00.000Z"`, `statusLabel: ACTIVE`) and lines 143–144
- **Suggested follow-up:** Two clean options — (a) update `lastSeenAtUtc` for both exceptions to something within 30 min of the report generation time (`16:00–16:30`), or (b) change `statusLabel` to `RESOLVED` and add a resolution timestamp and reason (e.g. "Vehicle exited at 10:15 after manager intervention").

### P2 — `knownIdentitySignals: 0` contradicts `repeatVehicles: 10`
- **Action:** REVIEW
- **Finding:** Ten repeat vehicles were counted, implying the system recognised plates it had seen before. But `knownIdentitySignals: 0` says no signal was from a known identity. These two numbers tell opposite stories about whether identity recognition is working.
- **Why it matters:** A technically-aware prospect will catch this in seconds. It either means the repeat-vehicle logic uses a different identity layer than the known-signal layer (which is fine but needs to be visible), or the fixture was assembled from two different data sources without reconciliation.
- **Evidence:** Lines 35 (`knownIdentitySignals: 0`) and line 86 (`repeatVehicles: 10`)
- **Suggested follow-up:** If repeat vehicles are tracked by plate re-occurrence (not a named profile), set `knownIdentitySignals` to a non-zero value reflecting enrolled plates, or add a clarifying field distinguishing "profile-enrolled" from "plate-recurrence" repeat detection.

### P3 — `partnerProgression` is entirely empty
- **Action:** REVIEW
- **Finding:** All counts are zero, all arrays are empty, and all headline strings are blank. For a carwash demo where no armed response dispatch is expected, this makes semantic sense — but visually it will render as a dead section.
- **Why it matters:** Lower severity than `receiptPolicy` because zero-dispatch is plausible. But the empty `scopeBreakdowns`, `scoreboardRows`, and `dispatchChains` arrays next to blank headline strings still look like an unfinished feature rather than a quiet shift.
- **Evidence:** Lines 152–166
- **Suggested follow-up:** Add a `workflowHeadline` such as `"No dispatch required this shift"` and a `slaHeadline` such as `"All activity resolved within monitoring scope"` to communicate deliberate calm rather than missing data.

### P3 — `aiHumanDelta.overrideReasons` is generic
- **Action:** REVIEW
- **Finding:** The one human override is classified only as `operator_review: 1`. There is no narrative linking it to any specific event.
- **Why it matters:** Small issue, but in a demo the "1 override" stat is a natural conversation starter. If an operator asks "what did the manager override?", there is nothing to show.
- **Evidence:** Lines 13–16
- **Suggested follow-up:** Either wire this to one of the loitering exceptions (e.g., the human confirmed the ND456783 flag and marked it reviewed), or add an `overrideSummary` string like `"Manager confirmed loitering flag for ND456783 at 09:45"`.

---

## Suggested Improvements — Prioritised

1. **Populate or remove `receiptPolicy`** — single biggest visual risk in the fixture
2. **Add 3 short-visit exception entries** or zero out `suspiciousShortVisitCount` — resolves the count/data contradiction
3. **Fix loitering visit timestamps or statuses** — remove the ambiguity of a 4–6 hour ACTIVE gap
4. **Reconcile `knownIdentitySignals` vs `repeatVehicles`** — these tell opposite stories
5. **Add a `repeatCustomerRate` computed field** (e.g. `0.27`) — saves the UI from computing it and makes the loyalty story explicit
6. **Add a revenue proxy** (e.g. `estimatedRevenue: { completedVisits: 41, avgWashPriceZAR: 95, estimatedTotalZAR: 3895 }`) — business owners anchor on money
7. **Add `workflowHeadline` to `partnerProgression`** — converts dead empty arrays into a positive "quiet shift" narrative
8. **Link the 1 human override to a named exception** via `overrideSummary` — gives the demo moment a story

---

## What Looks Good

- Hourly breakdown sums correctly to 47 with a natural bell curve
- Entry / exit / active / incomplete counts reconcile cleanly to zero
- The two loitering exception entries are well-formed with zone labels, score reasons, and workflow summaries — they are the strongest part of the fixture
- `normDrift.avgMatchScore: 98.1` with zero drift detected is a clean story for a well-behaved site
- `aiHumanDelta` ratio (8:1) is believable and favourable without looking fabricated
- The `executiveSummary` and narrative strings in `siteActivity` and `sceneReview` are specific to the scenario and not generic boilerplate
- `complianceBlockage` all-zero is appropriate — a carwash doesn't have complex PSIRA/PDP concerns and zero-blocked sends a clean signal
