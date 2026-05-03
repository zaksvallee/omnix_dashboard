# 2026-05-03 — Zara Architectural Cleanup Arc

## Summary

Four items closed in one session: detection-confidence framing, FR backend commit, footfall→peak_occupancy rename, legacy command router deletion. Each fix builds on the previous. Net effect: Zara now operates on a single text-routing path with honestly-named capabilities and consistently-hedged framing.

## Items closed

| # | Title | Commits | Outcome |
|---|---|---|---|
| 6 | System prompt hedging | a6891f0 | Detection counts framed as "currently detected" not ground truth |
| 9 | FR backend commit | aed477f | OpenCV YuNet+SFace backend committed (verified 40x faster: 14s → 110-330ms) |
| 7 | peak_occupancy rename | c2a4ca3, a0fb3ba, migration 20260503140000 | footfall_count → peak_occupancy across capability/data source/tool/classifier |
| 10 | Legacy command router deletion | 2fc2865 | OnyxTelegramCommandRouter + 8 _build*Reply helpers + 6 orphans deleted (-752 lines) |

All commits on origin/main. Migration applied to Supabase. AI processor deployed to Hetzner. Mac service running with new FR backend.

## Architectural state changes

- **Detection framing.** Production Zara now hedges detection counts ("currently detected: 2 people, 0 vehicles, 0 animals" not "there are 2 people on site"). Excludes perimeter status, active alerts count, incident records (database-derived). Anti-overcorrection guard prevents disclaimer padding.

- **Repo truth.** The +260/-58 OpenCV FR backend work that had been running uncommitted on Mac since April is now on origin/main. Future fresh-checkout deploys won't lose it.

- **Capability surface honesty.** "Footfall" implied retail visitor counting; the tool returns peak occupancy. Renamed top-to-bottom: capability key, display name, data source, tool file, tool class, tool definition name, classifier phrase routing. Visitor-shaped phrases ("how many came today", "footfall") drop entirely to fallback because no honest tool answers them.

- **Single text-routing path.** Telegram → Zara classifier → capability or fallback. Two narrow guards preserved at parallel-path level: visitor registration (Supabase side effects via _pollOnce parallel branch), frOnboarding (static instructions inline above Zara call). Callback path (alert button taps) untouched and operating independently.

## Sequencing rationale (why this order)

The four items shipped in a specific order because each later fix depended on behavior that the earlier fix put in place:

1. **#6 first** because it's the smallest scope and applies universally. Once shipped, every subsequent Zara response had honest framing — the hedging is foundational, not a Tier 1 nice-to-have.

2. **#9 second** because it's pure repo truth with zero risk. Same family as Friday's repo-truth restoration. ~15 minutes. Lands the proven FR backend improvement before any future deploy could lose it.

3. **#7 third** because the rename + classifier rebuild needed #6's hedging already in place. The new "currently detected" framing covers the monitoring_status_brief route that absorbed the current-occupancy questions ("how many on site right now"). Without #6, those answers would have been confidently wrong instead of confidently honest.

4. **#10 fourth** because the legacy router deletion needed #7's classifier already in place. Pre-#7, "how many people came today" routed to footfall_count and the legacy router never got a chance. Post-#7, that phrase fell through to legacy via the bare 'today' incident trigger. Deleting legacy without first dropping the visitor-shaped phrases would have left a different gap. The order is forced by the data flow.

## Smoke verification record

10 phrases tested live from production Telegram after final deploy:

| Phrase | Expected | Result |
|---|---|---|
| `peak occupancy today` | Zara peak_occupancy capability, real number | "Peak occupancy today is 8" ✅ |
| `how many on site right now` | Zara monitoring_status_brief, hedged framing | "Currently detected on site: 2 people, 0 vehicles, 0 animals" ✅ |
| `how many people came today` | Zara fallback (regression fix) | "Message received. Monitoring continues." ✅ |
| `today` | Zara fallback (regression fix) | "Message received. Monitoring continues." ✅ |
| `all good` | Zara monitoring_status_brief, contradiction-aware | "Not fully. Perimeter is clear, but there are 3 active alerts..." ✅ |
| `show me camera 3` | Zara fallback (camera gap) | "Message received. Monitoring continues." ✅ |
| `the cleaner is here` | Visitor parallel path + INSERT side effect | "Got it. Cleaner's visit noted until 23:59" + row landed in site_expected_visitors ✅ |
| `add resident` | frOnboarding inline guard | Static 4-line enrollment instructions ✅ |
| `hello` | Zara fallback | "Message received. Monitoring continues." ✅ |

Visitor INSERT side effect verified via direct Supabase query: row with visitor_name='Cleaner', visit_type='on_demand', is_active=true, created_at matching the Telegram message timestamp.

## Production state at session close

- **Hetzner** (api.onyxsecurity.co.za / 178.104.91.182): commit 2fc2865 deployed, onyx-telegram-ai-processor active, ai=configured.
- **Mac** (192.168.0.7): monitoring_yolo_detector_service.py running with ONYX_FR_BACKEND=opencv (default), bound to 0.0.0.0:11636. FR pass 110-330ms, LPR pass 10-17s (bottleneck, deferred).
- **Pi** (192.168.0.67): camera-worker pointed at Mac via ONYX_MONITORING_YOLO_ENDPOINT=http://192.168.0.7:11636/detect.
- **Supabase**: migration 20260503140000_rename_footfall_to_peak_occupancy applied. zara_capabilities row updated, client_data_sources row for MS Vallee updated.
- **Repo**: origin/main at 2fc2865. All today's commits pushed.

## Known gaps after today

- **Detection accuracy ceiling.** Zara responses report what cameras detect, which is consistently under-counting reality (2 vs 4 people, 0 vs 4 vehicles, 0 vs cats present). Hedging from #6 frames this honestly, but the underlying detection layer is the actual fix needed. Items #2/#3/#4.

- **LPR HD-strip bottleneck.** Vehicle detection takes 10-17 seconds per frame on Mac. Bug at `_candidate_crops:1149-1167` in monitoring_yolo_detector_service.py, deferred since April. Item #1 (Tier 1).

- **Camera snapshot capability missing.** Pre-deletion, "show me camera 3" routed to legacy `_buildCameraReply`. Post-deletion, falls to Zara fallback. No new capability added; queued for #16 as `fetch_camera_snapshot` tool.

- **Multi-channel offline detection.** System surfaces only the most recent failed channel; if multiple channels are down, only one is reported. Item #5.

- **Real `clients.tier` column.** Currently using metadata JSON. Tier 3 #15.

## Next session warm-up

Open with **#11 (delete OpenAiTelegramAiAssistantService)** as a 30-minute smaller-scope confirmation of momentum, then move to **#1 (LPR HD-strip bug)** as the substantial fix.

Investigation prompts for both are pre-drafted below; queue them as session openers.

### Tomorrow's #11 investigation prompt

```
Read-only investigation. No edits. No commits.

Goal: Map OpenAiTelegramAiAssistantService for deletion planning. After commit
2fc2865 (legacy router deletion), this class is the next vestigial layer in the
Zara routing path.

Q1: Find the class.
  - Search /Users/zaks/omnix_dashboard/lib/ and /bin/ for "OpenAiTelegramAiAssistantService"
    (class name) and "openai_telegram_ai_assistant_service" (likely filename pattern).
  - Report the file location and line count.
  - Report the class signature and full public method list.

Q2: Find every call site.
  - grep for "OpenAiTelegramAiAssistantService" across the entire repo (lib/, bin/, test/).
  - Report each call site verbatim with surrounding 5 lines context.

Q3: Determine current invocation conditions.
  - Is this class instantiated unconditionally, or behind a feature flag / config check / fallback path?
  - What does the AI processor (bin/onyx_telegram_ai_processor.dart) currently use as its primary AI assistant — ZaraTelegramAiAssistantService, OpenAiTelegramAiAssistantService, or both with fallback logic?

Q4: Tests.
  - Any test files referencing OpenAiTelegramAiAssistantService?
  - Report verbatim if found.

Q5: Deletion shape (assessment, not action).
  - Single-file deletion or multi-file?
  - Estimated LOC delta?
  - Any guards or fallback logic that needs to be preserved?

Output format:
=== Q1: Class location ===
=== Q2: Call sites ===
=== Q3: Invocation conditions ===
=== Q4: Tests ===
=== Q5: Deletion shape ===

Time budget: 10 minutes.
```

### Tomorrow's #1 LPR investigation prompt

```
Read-only investigation. No edits, no commits, no service restart.

Goal: Diagnose where the 10-17 second wall-clock time goes in the LPR pipeline
on Mac. Memory entry from April flags _candidate_crops:1149-1167 as the
suspected bug, but no diagnosis was completed at that time. We need actual
sub-stage timings before drafting a fix.

Q1: Read the LPR pipeline code.
  - Open /Users/zaks/omnix_dashboard/tool/monitoring_yolo_detector_service.py
  - Report verbatim:
    - The function or method containing _candidate_crops, lines 1100-1250
    - The LPR entry point (where vehicle detections enter the LPR pipeline)
    - The LPR exit point (where plate text is returned)
  - Identify the sub-stages of LPR processing:
    - Crop candidate generation (the suspected bug area)
    - Image preprocessing per candidate
    - OCR call(s)
    - Result aggregation
  - Report which sub-stage CC believes is most likely the bottleneck based on
    code inspection alone.

Q2: Identify timing instrumentation hooks.
  - Are there existing timing measurements anywhere in the LPR path?
  - The _ONYX-YOLO-TIMING log line shows total lpr_ms, but is there sub-stage
    granularity already wired?
  - If there isn't, identify the cleanest insertion points for temporary
    sub-stage timing.

Q3: Look at the EasyOCR integration.
  - How many candidate crops typically get passed to EasyOCR per vehicle frame?
  - Is OCR called per-candidate sequentially, or batched?
  - Is there a candidate-count limit, or could a single frame be generating
    dozens of OCR calls?

Q4: Check the candidate crop generation algorithm.
  - What's the algorithm in _candidate_crops? Sliding window? Edge-detection
    based regions? YOLO-detected plate boxes?
  - What parameters control how many crops get generated?
  - Is there a known-cheap fast path that's been disabled, or is the slow path
    the only path?

Output format:
=== Q1: LPR pipeline shape ===
[verbatim code sections]
[CC's best guess at bottleneck]

=== Q2: Existing timing instrumentation ===
[what exists, what's missing, where to add]

=== Q3: OCR call shape ===
[per-candidate vs batched, count limits]

=== Q4: Candidate generation algorithm ===
[algorithm description, parameters, fast/slow paths]

Time budget: 30 minutes. Pure investigation, no diagnostic-script writing.

After this investigation lands clean, the next step is to add temporary
sub-stage timing instrumentation, capture 10 real vehicle frames, and report
the breakdown. That's a separate phase.
```

## Updated remaining-items list

```
Tier 1 — Customer-visible quality
  [ ] #1  LPR HD-strip bug at _candidate_crops:1149-1167 (10-17s per vehicle frame)
  [ ] #8  fetch_active_alerts tool (Zara explicitly offered alert summaries, no tool yet)

Tier 2 — Detection accuracy
  [ ] #2  People under-count detection gaps (2 detected vs 4 actual)
  [ ] #3  Vehicle under-count detection gaps (0 detected vs 4 actual)
  [ ] #4  Animal class detection (cats missing entirely)
  [ ] #5  Multi-channel offline detection (catches only most recent down)

Tier 3 — Commercial groundwork
  [ ] #15 Real clients.tier column (currently using metadata JSON)
  [ ] #16 More tools (fetch_camera_snapshot, fetch_recent_incidents, fetch_dispatch_status)

Tier 4 — Cleanup
  [ ] #11 Delete OpenAiTelegramAiAssistantService (warm-up next session)
  [ ] #12 Pi dual-webhook footgun (latent risk in setup_pi.sh)
  [ ] #13 developer.log Bucket 3 (25 high-volume traces)
  [ ] #14 Empty-catch fixes (audit shipped 130602b, fixes deferred)
  [ ] #17 Diagnostic wrapper scripts (tools/diag/ with scoped credentials)

Closed today (2026-05-03):
  [x] #6  System prompt hedging — commit a6891f0
  [x] #9  FR backend commit — commit aed477f
  [x] #7  footfall_count → peak_occupancy rename — commits c2a4ca3, a0fb3ba, migration 20260503140000
  [x] #10 Legacy command router deletion — commit 2fc2865
```
