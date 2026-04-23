Layer 2 Post-Cutover Smoke Checklist — MS Vallee
Date: 2026-04-23
Status: Draft operator checklist
Purpose: confirm the preserved deployment is stable after the Layer 2 wipe and
constraint application, before deeper Layer 3 repair work starts.

References

- audit/layer_2_cutover_ms_vallee_2026-04-23.md
- supabase/manual/cutover/RUNBOOK.md
- audit/phase_5_section_3_cutover_policy.md

Suggested timing

- pass 1: immediately after cutover completion
- pass 2: after the first 24 hours of normal runtime

Checklist

1. Site configuration still present
- Open the site-facing dashboard surfaces.
- Confirm `MS Vallee` still appears as the active site.
- Confirm the preserved dummy site rows were not accidentally deleted.
- Pass if site list and site detail load without missing-reference errors.

2. Face gallery still present
- Confirm the enrolled resident identities are still visible.
- Spot-check expected enrolled count against the preserved registry.
- Pass if the resident roster is intact and readable.

3. Vehicle registry still present
- Confirm registered vehicles still load.
- Spot-check that the operator-recognised vehicles are present.
- Pass if the registry appears unchanged from pre-cutover preserved state.

4. Zones and camera-zone mappings still present
- Open the site/zones view.
- Confirm zone definitions and camera associations still render.
- Pass if no zone redraw is required and no mapping is obviously missing.

5. Telegram bridge still works
- Send a harmless operator-side test interaction (`/start` or equivalent
  non-destructive handshake if needed).
- Confirm the bot responds and the site/operator mapping still behaves as
  expected.
- Pass if the bridge responds without re-pairing work.

6. Edge device registration still present
- Confirm the Pi / edge device record still exists.
- Confirm post-cutover heartbeat or health state reappears if that table is
  regenerated automatically.
- Pass if the device is still recognised by the platform.

7. Camera-worker runtime is alive
- Check the camera worker service state on the Pi.
- Confirm the process is running and not in a restart storm.
- Pass if the worker is alive and no immediate crash loop is visible.

8. Fresh alerts still flow
- Trigger one controlled, safe alert-producing event if practical.
- Confirm the event shows up in the live operator path (Telegram and/or
  dashboard).
- Pass if the system still produces a fresh post-cutover alert.

9. Preservation invariants hold
- Spot-check row counts or visible counts for:
  - faces
  - vehicles
  - sites
  - zones
  - Telegram/operator mapping
- Pass if counts match the preserved export expectations and no preserved table
  appears partially wiped.

10. Wipe-set remained wiped
- Confirm previously noisy event surfaces no longer show the old test corpus.
- Pass if live screens are visibly reset and only fresh post-cutover activity
  appears.

Escalation rule

- If a preserved surface is missing or broken, stop Layer 3 repair work and
  treat it as a Layer 2 regression.
- If preserved surfaces are intact but fresh operational writes are still absent,
  continue into Layer 3 capability repair.
