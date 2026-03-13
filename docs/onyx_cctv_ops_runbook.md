# ONYX CCTV Operations Runbook

Last updated: 2026-03-13 (Africa/Johannesburg)

## 1. Daily Controller Routine

- Run `/bridges` at shift start.
- Confirm CCTV shows `configured` and review:
  - evidence queue summary
  - per-camera stale/degraded markers
  - latest CCTV recent-signal line
- Run `/pollops` once after `/bridges` to force a fresh ingest pass.
- If CCTV shows `probe fail`, `queue drop`, `stale camera`, or repeated `fail` counts:
  - escalate to controller lead
  - open Tactical and Live Operations to confirm incident context is still populated
  - capture the `/bridges` output in the shift notes

## 2. Weekly Edge Health Review

- Verify the pilot Frigate edge endpoint still resolves from ONYX.
- Review camera stale age summaries in admin/system diagnostics.
- Confirm the false-positive suppression rules still match current zone naming.
- Check evidence queue limits are not saturating during normal traffic.
- Review any repeated probe failures by camera and compare against site network incidents.

## 3. Incident Evidence Retrieval Drill

- Trigger or replay a recent CCTV event.
- Initialize a capture pack before the drill:
  ```bash
  ./scripts/onyx_cctv_capture_pack_init.sh \
    --out-dir tmp/cctv_capture \
    --site-id <site_id> \
    --edge-url https://<edge-host> \
    --camera-id <camera_id> \
    --zone <zone> \
    --event-id <frigate_event_id>
  ```
- Or run the full pilot gate after the artifacts are captured:
  ```bash
  ./scripts/onyx_cctv_pilot_gate.sh \
    --edge-url https://<edge-host> \
    --site-id <site_id> \
    --camera-id <camera_id> \
    --zone <zone> \
    --event-id <frigate_event_id> \
    --capture-dir tmp/cctv_capture
  ```
- Confirm the event appears in:
  - `/pollops`
  - `/bridges`
  - Tactical counters
  - Live Operations incident context
- Verify snapshot and clip references are present for the event where expected.
- Record the event ID, intelligence ID, snapshot ref, and clip ref in the drill log.
- Save the captured `/bridges`, `/pollops`, and Live Operations or timeline text into `tmp/cctv_capture/`.
- Run:
  ```bash
  ./scripts/onyx_cctv_field_validation.sh \
    --edge-url https://<edge-host> \
    --event-id <frigate_event_id> \
    --expect-camera <camera_id> \
    --expect-zone <zone> \
    --capture-dir tmp/cctv_capture
  ```
- Attach the generated `tmp/cctv_field_validation/<timestamp>/validation_report.md` to the shift or rollout notes.
- Keep `validation_report.json` with the same artifact set so later gates can verify checksums and overall status automatically.

## 4. Degraded Mode Response

When CCTV is degraded but ONYX is still online:

- Continue dispatch using radio/wearable/news sources.
- Treat `stale camera` as reduced confidence, not as proof of no activity.
- If evidence probe failures persist:
  - preserve the deterministic reference already captured by ONYX
  - do not overwrite or mutate the recorded snapshot/clip reference
- Re-run `/bridges` after connectivity stabilizes.

## 5. Bridge Failure Drills

### Camera Offline

- Expected signal:
  - per-camera health moves to `stale` or `degraded`
- Controller action:
  - verify the affected camera in `/bridges`
  - confirm no silent suppression rules are hiding the feed

### MQTT/Event Feed Down

- Expected signal:
  - `/pollops` CCTV fail count rises
  - recent-signal activity stalls
- Controller action:
  - confirm Frigate event feed path
  - verify ONYX still resolves the edge endpoint

### VPN / Overlay Flap

- Expected signal:
  - evidence probe failures increase
  - queue drop alerts can appear under sustained bursts
- Controller action:
  - keep deterministic refs already recorded
  - re-run `/bridges` after tunnel recovery

## 6. Retention and Audit Controls

- ONYX stores deterministic snapshot/clip references with each intelligence record.
- ONYX should not rewrite media references after ingest.
- Retention baseline for the pilot:
  - snapshots: 14 days on edge
  - clips: 30 days on edge
  - ONYX references: retained with the intelligence timeline
- Any policy change must update both:
  - edge retention settings
  - this runbook/checklist
- Evidence drill logs should include:
  - time
  - controller
  - event/intelligence identifiers
  - whether snapshot/clip references resolved successfully

## 7. Runtime Configuration Notes

- `ONYX_CCTV_FALSE_POSITIVE_RULES_JSON`
  - JSON array of suppression rules keyed by `zone`, `object_label`, `start_hour_local`, `end_hour_local`, and optional `min_confidence_percent`
- `ONYX_CCTV_EVIDENCE_QUEUE_DEPTH`
  - bounded queue limit for evidence verification probes
- `ONYX_CCTV_STALE_FRAME_SECONDS`
  - threshold after which a camera is reported as stale

## 8. Field Validation Gate

- `make cctv-validate`
  - runs `scripts/onyx_cctv_field_validation.sh`
- `make cctv-readiness`
  - runs `scripts/onyx_cctv_pilot_readiness_check.sh`
  - verifies the latest CCTV validation artifact is fresh, `PASS`, and checksum-clean
  - use `--require-real-artifacts` for real pilot signoff to reject mock bundles
- `make cctv-mock-artifacts`
  - runs `scripts/onyx_cctv_mock_validation_artifacts.sh`
  - tooling-only path for validating the CCTV gate scripts without a live edge node
- `make cctv-capture-pack`
  - runs `scripts/onyx_cctv_capture_pack_init.sh`
  - scaffolds `tmp/cctv_capture/` with the expected files for field capture
- `make cctv-pilot-gate`
  - runs `scripts/onyx_cctv_pilot_gate.sh`
  - executes validation + readiness in one command once the capture pack is filled
- `make cctv-signoff`
  - runs `scripts/onyx_cctv_signoff_generate.sh`
  - writes a pilot signoff note plus `signoff.json` from the latest validation bundle and field notes
- `make cctv-release-gate`
  - runs `scripts/onyx_cctv_release_gate.sh`
  - writes `release_gate.json` plus `release_gate.md` from the staged validation bundle, integrity certificate, and CCTV signoff JSON
- `make cctv-release-trend`
  - runs `scripts/onyx_cctv_release_trend_check.sh`
  - writes `release_trend_report.json` plus `release_trend_report.md` by comparing the current and previous staged CCTV `release_gate.json`
- Exit codes:
  - `0`: pass
  - `1`: fail
  - `2`: incomplete evidence capture
- Reports:
  - `validation_report.md` for operator signoff
  - `validation_report.json` for machine-readable gate checks and evidence checksums
  - `signoff.json` for machine-readable CCTV signoff posture, including integrity-certificate refs/status and failure codes on blocked signoff
  - `release_gate.json` / `release_gate.md` for final CCTV release posture
  - `release_trend_report.json` / `release_trend_report.md` for cross-run CCTV release posture regression checks
