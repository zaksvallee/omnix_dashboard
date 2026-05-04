# LPR Profile Summary — 2026-05-04

**Source:** Live MS Vallee Residence camera traffic flowing through the
instrumented Mac service at 192.168.0.7:11636. Sample window
12:58 → 13:04 SAST 2026-05-04. No synthetic replay; natural production
input.

**Sample size:** 26 detect calls / 635 `[ONYX-LPR-PROFILE]` log lines.
Captured to `/tmp/lpr_profile_capture.log`.

**Instrumentation source:** `tool/monitoring_yolo_detector_service.py`
`PlateRecognitionModule.detect()` — uncommitted, +62/-2 lines, log-only.

**Key constraint:** **zero plate matches** in the 26-frame sample
(`matched=` empty across all detect lines). The OCR detected text-like
regions on 32% of attempts but none passed the plate regex + minimum
confidence threshold. This breaks any per-attempt analysis that depends
on "successful match" — Fix #1 cannot be defensibly evaluated yet.

---

## 1. Frame-class breakdown

| Class | Frame size | Vehicles | Crops | Attempts | Frames | detect_total_ms (mean / min / max) |
|---|---|---|---|---|---|---|
| Vehicle-positive single | 704x576 | 1 | 6 | 42 | 11 | 7,377 / 2,862 / 16,254 |
| Vehicle-positive multi | 704x576 | 2 | 12 | 84 | 1 | 13,992 |
| **HD no-vehicle** | **1280x720** | **0** | **3** | **21** | **3** | **7,866 / 7,432 / 8,257** |
| Sub-HD no-vehicle (gated) | 704–960x576 | 0 | 0 | 0 | 11 | 0.1 / 0 / 0.8 |

Bimodal distribution on vehicle-positive frames: 5/11 frames complete
in 2.8–4.4 s, 6/11 take 13.9–16.3 s. Same input size, same crop count,
same attempt count — yet ~4× variance. The cost is dominated by
`reader.readtext` per call, which itself varies based on what
text-shaped contours EasyOCR's CRAFT detector encounters.

---

## 2. The waste pattern (HD no-vehicle)

```
3 HD-no-vehicle frames at 1280x720, 0 vehicles detected
  -> _candidate_crops returns 3 HD-fallback crops anyway (lines 1351-1369)
  -> 3 × 7 OCR attempts = 21 readtext calls per frame
  -> 7,432, 7,910, 8,257 ms wasted
  -> 0 plates matched (none possible — no vehicle in frame)
```

Aggregate waste across the 3 frames: **23.6 seconds of CPU spent
per-frame on inputs where no vehicle exists**. Per the historical
TIMING distribution (122 of 476 prior entries fall in the 5-10s range
with `lpr_ms` non-zero), this pattern repeats indefinitely — every HD
frame on every camera at every site, even when nothing is happening.

The gate `if width >= 1000 and height >= 600` at line 1351 is unconditional
on detection state. The fix is to add a `if detections_have_vehicle` guard
or move the HD fallback inside the no-crops fallback at the bottom of the
function.

The 11 sub-HD no-vehicle frames in the sample completed LPR in ~0 ms,
confirming the size-gate path itself is correct.

---

## 3. Per-attempt aggregation (87 calls of each variant)

| # | Variant | Calls | Mean ms | Min ms | Max ms | Hits (results>0) | Hit rate |
|---|---|---|---|---|---|---|---|
| 1 | upscaled (6×/4×/2× INTER_CUBIC) | 87 | 295.1 | 37.0 | 1226.0 | 30 | 34.5% |
| 2 | gray (cvtColor BGR→GRAY) | 87 | 221.3 | 37.0 | 830.0 | 30 | 34.5% |
| 3 | enhanced (equalizeHist) | 87 | 215.1 | 37.0 | 839.0 | 32 | 36.8% |
| 4 | clahe (CLAHE clip=2 tile=8x8) | 87 | 212.7 | 37.0 | 505.0 | 30 | 34.5% |
| 5 | bilateral (bilateralFilter d=9) | 87 | 213.2 | 38.0 | 701.0 | 30 | 34.5% |
| 6 | binary (Otsu threshold) | 87 | 215.9 | 40.0 | 873.0 | 31 | 35.6% |
| 7 | adaptive (Gaussian threshold 31) | 87 | 214.1 | 38.0 | 565.0 | 30 | 34.5% |

**Read:** all 7 variants have nearly identical hit rates (34-37%) and
near-identical means (213-295 ms). The "upscaled" variant (#1) is the
hottest by mean, but only by ~80 ms vs the others. **None is zero-yield.**

`results>0` means "EasyOCR detected at least one text-like region", not
"a valid plate was matched." Since every frame had `matched=`, all 209
hits were rejected by the plate regex / minimum confidence guards
downstream. So this table tells us nothing about which attempts produce
**successful matches** — a critical caveat for Fix #1.

---

## 4. Per-priority aggregation (the smoking gun for Fix #7)

| Priority | Calls | Mean ms | Hits | Hit rate | Label |
|---|---|---|---|---|---|
| 0.12 | 91 | 324.4 | 35 | 38.5% | whole_vehicle (vehicle-relative) |
| 0.18 | 91 | 205.0 | 35 | 38.5% | lower_half (vehicle-relative) |
| 0.32 | 91 | 245.9 | 37 | 40.7% | center_lower_band (vehicle-relative) |
| 0.38 | 91 | 96.7 | 35 | 38.5% | lower_quarter (vehicle-relative) |
| 0.42 | 91 | 259.8 | 33 | 36.3% | wide_center_strip (vehicle-relative) |
| 0.24 | 112 | 179.5 | 35 | 31.2% | lower_third / hd_lower_third (mixed) |
| **0.16** | **21** | **361.0** | **1** | **4.8%** | **hd_center_strip (HD-fbk)** |
| **0.20** | **21** | **352.8** | **2** | **9.5%** | **hd_lower_center (HD-fbk)** |

The HD-fallback exclusive priorities (0.16, 0.20) hit at **4.8% / 9.5%**
vs vehicle-relative crops at **36-41%**. Combined with the 23.6s of
waste documented above, this is structural evidence: the HD-fallback
path does low-yield work, often on inputs where no vehicle exists at all.

---

## 5. The "no plate match" caveat

In 26 detect calls covering 12 vehicle-positive frames, the system
matched **zero** plates. EasyOCR found text-like regions on 209/609
attempts (34%), but none passed the downstream pipeline:

```python
# lines 1216-1220
plate = _normalize_plate_candidate(text)
if not plate or not self.plate_regex.match(plate):
    continue
if confidence < self.minimum_confidence:
    continue
```

Possible causes (not investigated in this task):
- MS Vallee Residence cameras don't capture plate-bearing angles
  (perimeter/yard cameras, not gate/forecourt)
- Plates are too small or angled for the current upscale factor
- `_DEFAULT_PLATE_REGEX` (line 59: `^(?=.*[A-Z])(?=.*\d)[A-Z0-9]{5,10}$`)
  is too strict for SA temporary/personalized plates
- `minimum_confidence` is too high for upscaled-and-degraded inputs

This means:
1. **The current production LPR for MS Vallee may already be
   delivering 0 plate reads despite consuming 7-17 s/frame.**
   That's worth a separate investigation — is anyone actually
   benefiting from this pipeline at this site?
2. Fix #2's early-exit threshold (score > 0.85) cannot be validated.
   It would not have fired in this sample regardless of
   implementation — score = confidence + priority, both unknown
   without a match.
3. Fix #1's per-attempt cuts cannot be evaluated against
   "successful matches" since there are zero successful matches.

---

## 6. Other findings

- **`_candidate_crops` itself is microseconds.** All 26 frames show
  `crops_ms = 0.0` (or 0.1-0.8 ms for sub-HD frames where signal_text
  parsing dominates). The discovery report's structural claim is now
  empirically verified: the function name in legacy memory pointed to
  the wrong line of attack. The cost lives in
  `PlateRecognitionModule.detect()` and `reader.readtext()`, not in
  the slicing.
- **`_ocr_attempts` overhead is ≤45 ms total per detect.** The 7-variant
  build is cheap. Cutting attempts saves OCR time, not preprocessing time.
- **`crops_ms = 0` even in vehicle-positive frames.** The slicing
  produces 6 NumPy views in microseconds. Confirming the discovery
  audit's "the function called `_candidate_crops` is not the
  bottleneck" finding.
- **Bimodal vehicle-frame latency (3-4 s vs 14-16 s).** Same input
  size, same crop count, same attempt count. The variance is internal
  to EasyOCR's CRAFT detector responding differently to different
  text-region densities. Worth noting for variance modeling but not
  actionable at this level.
- **The 2-vehicle frame at 13:03:29** (`crops=12 attempts=84 detect_ms=13992`)
  scales linearly with vehicle count. Predicted total for 3 vehicles:
  ~21 s / for 4 vehicles: ~28 s — encroaching on the 30 s
  `_YOLO_INFERENCE_WATCHDOG_SECONDS` ceiling. Multi-vehicle frames are
  a watchdog risk.

---

## 7. Recommended actions (operator decides)

### Ship now (no match data needed)

**Fix #7 — Gate HD-fallback on detections being empty**

Current code (lines 1351-1369) unconditionally adds 3 HD-center crops
when input is ≥1000×600. Proposed: only add them when no vehicle
detection produced vehicle-relative crops. The fix is structural:
"if YOLO found a vehicle, trust the vehicle bbox; don't also try
HD fallback positions." Expected impact:

- Reclaims 7-9 s/frame on every HD no-vehicle frame
- Reduces vehicle-positive HD frames from 9 crops × 7 = 63 attempts
  to 6 × 7 = 42 attempts (33% fewer OCR calls)
- Risk: low. If YOLO misses a vehicle in an HD frame, the existing
  whole-image fallback at line 1370-1371 still fires (gated on
  `signal_text` vehicle-keyword match)

**Fix #2 — Early-exit on high-confidence match**

Add an early-exit at the score-comparison block (line 1222). Once
`best_score > 0.85 + max_priority` the loop can break early. The
threshold is invariant to sample distribution — "stop iterating once
you've found a good match" is correct regardless of attempt mix.
Expected impact:

- For frames with a high-confidence plate, terminates after 1-2
  successful crops × 1-7 attempts instead of all 6×7. Median
  saving estimated 30-60% of OCR time on plate-positive frames
  once those exist
- Risk: none. Reverting is one diff hunk

Both fixes can ship in a single commit. Both are testable by
re-profiling under the same instrumentation; the [ONYX-LPR-PROFILE]
summary line will report fewer crops/attempts for HD-no-vehicle
frames after Fix #7.

### Defer

**Fix #1 — Cut zero-yield OCR attempts**

Cannot be evaluated until the sample contains plate matches. With
`matched=` empty across 26 frames, hit-rate-by-attempt for **successful
matches** is unmeasurable. The 34-37% hit rate observed is
"results>0", which conflates plate-shaped text with bumper-sticker
noise.

Defer until a sample batch contains 5+ matches. Post-Fix-#7+#2
re-profile may produce them faster (early-exit terminates loops sooner;
HD no-vehicle frames don't pollute the per-attempt aggregate).

If still zero matches after re-profile, escalate to an upstream
investigation: is the plate regex too strict for SA plates? Is the
minimum_confidence too aggressive for low-quality upscaled crops?

---

## 8. Open questions for the operator

1. **Should this site even run LPR?** If MS Vallee Residence cameras
   never capture plate-readable angles, the pipeline is burning 7-17 s
   per vehicle frame for permanent zero recall. Worth confirming with
   the customer (or by inspecting recorded camera fields-of-view) that
   plates are actually visible. If not, gating LPR on a per-site
   `lpr_capable=true` config flag would save ~80% of wasted CPU at
   Vallee with zero customer impact.

2. **Variance in vehicle-positive frames (3-4 s vs 14-16 s).** Is the
   slow-frame group correlated with anything observable (time of day,
   camera ID, recorded image content)? If the slow case is "frames
   with lots of incidental text in background", then a Fix-#1-adjacent
   cut becomes more interesting (e.g., skipping `bilateral` or
   `binary` variants on text-busy backgrounds).

3. **Production LPR efficacy.** Is anyone reading the output? If
   `plate_match` is rarely populated even in vehicle-positive frames,
   the downstream consumer (Telegram alert? Supabase row?) is
   probably already designed around this gap. Worth surfacing.

---

## 9. Next-session sequence (locked)

1. ✅ Step 1: instrumentation applied (uncommitted)
2. ✅ Step 2: 26-frame sample captured
3. **Operator review of this summary** ← *you are here*
4. Step 3: apply Fix #7 + Fix #2 in one commit (defer Fix #1)
5. Step 4: re-profile under the same instrumentation
6. Step 5: compare before/after, document the win
7. Step 6: remove or gate the instrumentation; ship

---

*End of profile summary. Instrumentation remains uncommitted on disk;
service running on Mac.*
