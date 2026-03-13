# ONYX CCTV + Listener Rollout Checklist

Last updated: 2026-03-13 (Africa/Johannesburg)

## Scope and Priority

- Current priority: CCTV ingestion + ONYX bridge hardening.
- Deferred: Falcon/FSK listener bypass path (marked **TBC** until hardware is on hand).

---

## 1) CCTV Package Decision (Now)

- [x] Confirm primary package: **Frigate + go2rtc at site edge**.
- [x] Confirm ONYX stance: no dependency on Hikvision cloud event API for core detection.
- [x] Confirm architecture:
  - Edge: Frigate + go2rtc + MQTT broker.
  - ONYX: consume MQTT events + fetch snapshot/clip on demand.
  - Evidence: hash metadata + media references into ONYX ledger flow.
- [x] Confirm security posture:
  - VPN/overlay networking (WireGuard/Tailscale).
  - No public RTSP port forwarding.

---

## 2) CCTV MVP Build (Next)

- [ ] Provision one edge node (pilot site).
- [ ] Add camera stream profiles:
  - Sub-stream for continuous detection.
  - Main stream for evidence/snapshot quality.
- [ ] Enable Frigate event transport (MQTT topics) for ONYX bridge.
- [ ] Implement ONYX `cctv_bridge_service` event mapping:
  - Camera ID, site ID, zone, label, confidence, timestamp.
- [ ] Implement ONYX media pull path:
  - Snapshot URL fetch on event.
  - Clip reference fetch for post-incident timeline.
- [ ] Persist normalized CCTV events into ONYX event flow.
- [ ] Add operator visibility:
  - Health state in `/bridges` and `/pollops`.
  - Incident enrichment in Tactical/Operations views.

Acceptance for MVP:
- [ ] Motion/intrusion event reaches ONYX in near real time.
- [ ] Snapshot is retrievable per event.
- [ ] Event appears in status/incident context without manual refresh.

---

## 3) CCTV Hardening (After MVP)

- [ ] Add per-camera health checks (stream up/down, stale frame age).
- [ ] Add retry/backoff for snapshot/clip fetch.
- [ ] Add queue protection (bounded queue + drop policy + alerting).
- [ ] Add false-positive tuning workflow by zone/time window.
- [ ] Add retention policy for snapshots/clips + audit controls.
- [ ] Add bridge failure drills (camera offline, MQTT down, VPN flap).

Acceptance for hardening:
- [ ] ONYX bridge survives transient outages without silent data loss.
- [ ] Health degradation is visible in admin commands.
- [ ] Evidence references remain deterministic for replay/reporting.

---

## 4) Listener / Falcon / FSK Path (**TBC**)

Status: **TBC** (not current priority; start only after hardware arrives).

- [ ] Acquire hardware:
  - USB-to-TTL adapter (CP2102 or FT232).
  - Isolation/protection accessories for field-safe serial capture.
- [ ] Bench-test read-only serial sniff:
  - Connect GND + RX only (no TX control path initially).
  - No VCC pin link.
- [ ] Validate actual wire protocol from panel/Falcon output.
- [ ] Define ONYX serial ingestor schema (normalized event envelope).
- [ ] Run dual-path pilot (existing path + serial path) for parity checks.
- [ ] Decide cutover only after parity/latency pass criteria are met.

Notes:
- Contract/commercial exposure from bypassing third-party listener remains **TBC**.
- Production rollout decision for listener bypass remains **TBC**.

---

## 5) Operations Runbook Hooks

- [ ] Add CCTV bridge checks to daily controller routine.
- [ ] Add weekly edge node health review.
- [ ] Add “incident evidence retrieval” drill to demo/prep routine.
- [ ] Add “CCTV degraded mode” response steps for controllers.

---

## 6) Immediate Next Actions

- [ ] Stand up pilot Frigate/go2rtc edge compose.
- [ ] Wire one camera to ONYX `cctv_bridge_service`.
- [ ] Verify `/pollops` and `/bridges` reflect CCTV health.
- [ ] Capture first end-to-end event + snapshot + ONYX timeline record.

