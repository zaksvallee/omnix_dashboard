# ONYX Platform — Phase 1a Backend & Services Inventory

**Date:** 2026-04-20
**Scope:** backend, services, data layer, infrastructure.
**Out of scope:** Flutter `lib/` UI in `/Users/zaks/omnix_dashboard`; Next.js `app/` pages in `/Users/zaks/onyx_dashboard_v2` (only `app/api/**` is in scope).
**Rules:** evidence-only; "unknown" when data unavailable; no labels; no synthesis.

---

## 0. Access confirmation and gaps

| Target | Method | Result |
|---|---|---|
| `/Users/zaks/omnix_dashboard` | local read | ok |
| `/Users/zaks/onyx_dashboard_v2` | local read | ok |
| Pi `onyx@192.168.0.67` | ssh | ok — uptime 6d 5h |
| Hetzner `root@api.onyxsecurity.co.za` | ssh | ok — uptime 11d 9h |
| Supabase CLI, linked `omnix-core` (`mnbloeoiiwenlywnnoxe`) | `supabase` | ok for `projects list`, `functions list`, `functions download`; `db dump` blocked (requires Docker) |
| Supabase PostgREST (service role) | curl | ok — row counts read for 51+ tables |
| Supabase edge function source | `supabase functions download` | ok — 6 functions pulled to `/tmp/sb_edge/supabase/functions/` |
| Supabase storage REST | curl | ok — 3 buckets enumerated |

**Access gaps:**
- `supabase db dump --schema public --linked` requires Docker Desktop and could not be executed. Column types, nullability, indexes, foreign keys, and RLS policy bodies are **inferred from migration SQL** rather than pulled from live `information_schema`. Flagged where used.
- No direct `psql` connection string was available (the service role key was used via PostgREST instead).
- Supabase 7-day-ago row counts are not derivable from REST alone (no historical snapshot table found); marked `unknown`.
- Mac enhancement tier has no launchd unit — processes are started from foreground shells. Restart counts and last-success timestamps for the Mac enhancement process are not derivable from a system supervisor.

---

## 1. Backend file map

### `/Users/zaks/omnix_dashboard`

#### `bin/` — Dart entry points (production services)

| Path | Purpose (from code) | LOC | Last modified |
|---|---|---:|---|
| `bin/onyx_camera_worker.dart` | Hikvision ISAPI alert-stream worker: ingests alerts → pulls snapshots → classifies via YOLO endpoint → writes to Supabase → emits Telegram alerts with inline keyboard | 5441 | 2026-04-20 |
| `bin/onyx_telegram_ai_processor.dart` | Polls `telegram_inbound_updates`, intent-routes via `OnyxTelegramCommandRouter`, calls OpenAI Responses API when configured, replies via Telegram Bot API | 3498 | 2026-04-14 |
| `bin/onyx_status_api.dart` | HTTP status API bound to 127.0.0.1:8444 (proxied by nginx at `/v1/`); serves status and relays Telegram calls | 1231 | 2026-04-13 |
| `bin/onyx_telegram_webhook.dart` | HTTP webhook receiver on 127.0.0.1:8443 (proxied by nginx at `/telegram/webhook`); persists updates to `telegram_inbound_updates` | 338 | 2026-04-11 |
| `bin/onyx_telegram_bot_api_proxy.dart` | Local proxy forwarding to `api.telegram.org` and `api.elevenlabs.io` (TTS); runs on Mac dev only | 357 | 2026-04-09 |

#### `tool/` — Dart + Python supporting services

| Path | Purpose (from code) | LOC | Last modified |
|---|---|---:|---|
| `tool/monitoring_yolo_detector_service.py` | HTTP inference service on port 11636: YOLO (ultralytics) + optional face-recognition + optional EasyOCR LPR; per-source locking; 30s watchdog | 2261 | 2026-04-20 |
| `tool/onyx_rtsp_frame_server.py` | Persistent RTSP ingestion via OpenCV (`cv2.VideoCapture` with `cv2.CAP_FFMPEG`); HTTP frame server on port 11638 | 583 | 2026-04-11 |
| `tool/local_hikvision_dvr_proxy.dart` | Dart wrapper over `lib/application/local_hikvision_dvr_proxy_service.dart`; port 11635 | 123 | 2026-04-07 |
| `tool/run_onyx_scenario.dart` | Scenario runner / simulation harness (called by `scripts/clean_zara_smoke.dart`) | 7673 | 2026-04-07 |
| `tool/onboard_new_site.py` | Site onboarding helper; inserts rows across site, camera, zone tables | 683 | 2026-04-10 |
| `tool/enroll_person.py` | FR gallery enrollment: crops face, writes into `tool/face_gallery/` | 188 | 2026-04-14 |
| `tool/test_yolo_tracker.py` | Local YOLO tracker smoke test | 192 | 2026-04-20 |
| `tool/monitoring_yolo_detector_service_test.py` | Test harness for YOLO service | 158 | 2026-04-07 |
| `tool/onboarding_checklist.py` | Text checklist output | 101 | 2026-04-10 |
| `tool/generate_patrol_qr.py` | Patrol QR generator | 59 | 2026-04-13 |
| `tool/hik_connect_*.dart` (9 files) | Hik-Connect preflight / bundle / smoke scripts (hik-connect.example.com default host — stub URLs) | 40–174 each | 2026-04-07 |
| `tool/setup_monitoring_yolo_detector.sh` | Installer for YOLO venv | 38 | 2026-04-14 |
| `tool/start_monitoring_yolo_detector.sh` | Thin start wrapper | 24 | 2026-04-20 |

#### `supabase/` — schema + SQL

| Path | Purpose | LOC | Last modified |
|---|---|---:|---|
| `supabase/migrations/` | 44 SQL migration files spanning 2026-03-04 → 2026-04-17 | — | — |
| `supabase/manual/guard_storage_policies_owner.sql` | Storage owner RLS helper | unknown | unknown |
| `supabase/sql/guard_actor_contract_checks.sql` | Guard contract checks | unknown | unknown |
| `supabase/sql/guard_readiness_smoke_checks.sql` | Guard readiness smoke checks | unknown | unknown |
| `supabase/verification/guard_directory_registry_sync_smoke.sql` | Directory sync smoke | unknown | unknown |
| `supabase/verification/guard_directory_registry_validation.sql` | Directory validation | unknown | unknown |
| `supabase/verification/guard_rls_policy_validation.sql` | RLS policy validation | unknown | unknown |
| `supabase/verification/guard_storage_policy_validation.sql` | Storage policy validation | unknown | unknown |
| `supabase/functions/` | **does not exist locally** — edge functions live only on the Supabase side |

#### `deploy/` — deployment artifacts

| Path | Purpose | LOC |
|---|---|---:|
| `deploy/onyx-telegram-ai-processor.service` | systemd unit for Hetzner | 14 |
| `deploy/cctv_pilot_edge/docker-compose.yml` | Frigate + Mosquitto edge bundle (CCTV pilot) | unknown |
| `deploy/cctv_pilot_edge/frigate/` | Frigate config | — |
| `deploy/cctv_pilot_edge/mosquitto/` | Mosquitto broker config | — |
| `deploy/cctv_pilot_edge/README.md` | Pilot notes | — |
| `deploy/cctv_pilot_edge/validate_pilot.sh` | Pilot validator | unknown |
| `deploy/supabase_migrations/` | 10 additional SQL files dated 2026-04-13 → 2026-04-14 (parallel set; see Section 3) | — |

#### Repo root

| Path | Purpose | LOC |
|---|---|---:|
| `Dockerfile.telegram-ai-processor` | Container build for Telegram AI processor | unknown (small) |
| `pubspec.yaml` | Flutter app pubspec | — |
| `pubspec_ai_processor.yaml` | Dart-only pubspec for the AI processor binary | — |
| `pubspec_worker.yaml` (on Hetzner at `/opt/worker/`) | Dart-only pubspec for worker binaries | — |
| `Makefile` | Build targets | — |
| `CLAUDE_CODE_ROLE.md`, `ONYX_BACKLOG.md`, `SESSION.md`, `README.md` | Docs (not backend code) | — |

#### `scripts/` — 85 files (full enumeration in Section 7)

### `/Users/zaks/onyx_dashboard_v2`

**`lib/` (server-side only, excluding UI):**

| Path | Purpose (from code) | LOC | Last modified |
|---|---|---:|---|
| `lib/supabase/admin.ts` | Service-role Supabase client (bypasses RLS), cached singleton, `import "server-only"` | 31 | 2026-04-19 |
| `lib/supabase/server.ts` | Session-respecting Supabase client via `@supabase/ssr` and Next.js cookies (defined, not currently consumed by API handlers — see Section 6) | 29 | 2026-04-18 |
| `lib/supabase/client.ts` | Browser client via `@supabase/ssr` | 9 | 2026-04-18 |
| `lib/supabase/types.ts` | Generated DB types | 7371 | 2026-04-18 |
| `lib/supabase/queries/*.ts` | 15 typed query files (admin, ai-queue, clients, command, dispatches, events, governance, guards, incidents, intel, ledger, reports, sites, track, vip) | 27–148 each | 2026-04-19 |
| `lib/mappers/*.ts` | 17 mappers from DB rows to UI view-models | 76–665 each | 2026-04-19 |
| `lib/fixtures/admin.ts` | 14 DUMMY_* fixture exports (only imported by `/admin` per audit-2026-04-19) | 885 | 2026-04-19 |
| `lib/format/time.ts` | `formatSAST`, `formatAgeDistance` | 64 | 2026-04-19 |

**`app/api/` (all 19 route handlers):** see Section 6 for full table.

---

## 2. Service inventory

### Pi (`onyx-pi-msvallee`, `aarch64`, Ubuntu 6.8.0-1051-raspi)

| Unit | Entry point | Consumes | Produces | Status | Last started | Restarts (7d, `Started` lines in journal) |
|---|---|---|---|---|---|---:|
| `onyx-camera-worker.service` | `./scripts/run_camera_worker.sh --config /opt/onyx/config/onyx.local.json` → `bin/onyx_camera_worker.dart` | Hikvision ISAPI alert stream (192.168.0.117 via `onyx-dvr-proxy` on 11635); ISAPI snapshots; `tool/onyx_rtsp_frame_server.py` on 11638; YOLO detector on 11636 | Supabase inserts into `incidents`, `site_alarm_events`; Telegram messages via `api.telegram.org` | active, since 2026-04-20 17:03:38 SAST | 2026-04-20 17:03:38 | 6780 |
| `onyx-dvr-proxy.service` | `dart run tool/local_hikvision_dvr_proxy.dart --config /opt/onyx/config/onyx.local.json` | Hikvision DVR at 192.168.0.117 (upstream) | Alert stream on 127.0.0.1:11635 | active, since 2026-04-20 07:51:46 SAST | 2026-04-20 07:51:46 | 48 |
| `onyx-rtsp-frame-server.service` | `./.venv-monitoring-yolo/bin/python ./tool/onyx_rtsp_frame_server.py --config /opt/onyx/config/onyx.local.json` | RTSP streams on DVR at 192.168.0.117 port 554 (ffmpeg backend) | HTTP snapshot endpoint on 127.0.0.1:11638 | active, since 2026-04-20 00:30:47 SAST | 2026-04-20 00:30:47 | 4 |
| `onyx-yolo-detector.service` | `./scripts/start_yolo_server.sh --config /opt/onyx/config/onyx.local.json` → `tool/monitoring_yolo_detector_service.py` | JPEG frames via HTTP POST (from camera worker) | HTTP detect response on 127.0.0.1:11636 | active, since 2026-04-20 17:03:18 SAST (unit file is marked `disabled`; still loaded & running) | 2026-04-20 17:03:18 | 54 |

Journal shows one `oom-kill` on `onyx-yolo-detector.service` at 2026-04-20 13:16:50 and two `timeout` results on `onyx-rtsp-frame-server.service` around 2026-04-20 00:27:48–00:30:47.

No user or system cron jobs for the `onyx` account (`no crontab for onyx`). Only OS-default timers (logrotate, man-db, apt-daily, sysstat, fstrim, certbot).

### Hetzner (`ubuntu-4gb-nbg1-onyx-prod-1`, `x86_64`, Ubuntu 6.8.0-107-generic)

| Unit | Entry point | Consumes | Produces | Status | Last started | Restarts (7d) |
|---|---|---|---|---|---|---:|
| `onyx-telegram-ai-processor.service` | `/opt/onyx/bin/onyx_telegram_ai_processor` (compiled Dart AOT) | Supabase `telegram_inbound_updates`; OpenAI Responses API (`api.openai.com/v1/responses`) when configured | Telegram replies via `api.telegram.org`; Supabase writes (reply metadata) | active, since 2026-04-17 15:18:38 UTC | 2026-04-17 15:18:38 | 2 |
| `onyx-telegram-webhook.service` | `/opt/worker/bin/telegram_webhook` (compiled Dart AOT, `bin/onyx_telegram_webhook.dart` source) | Telegram bot webhook POSTs via nginx (`/telegram/webhook` → `127.0.0.1:8443`) | Supabase `insert` into `telegram_inbound_updates` (observed 402 egress-quota errors on 2026-04-17 11:27–11:31 UTC) | active, since 2026-04-17 15:18:38 UTC | 2026-04-17 15:18:38 | 1 |
| `onyx-status-api.service` | `/opt/worker/build/status_api/bundle/bin/onyx_status_api` (compiled Dart AOT, `bin/onyx_status_api.dart` source) | Supabase reads | HTTP responses on 127.0.0.1:8444 (proxied by nginx `/v1/`) | active, since 2026-04-17 15:18:38 UTC | 2026-04-17 15:18:38 | 1 |
| `onyx-camera-worker.service` (Hetzner) | `/opt/worker/bin/camera_worker` (compiled Dart AOT) | — | — | inactive (dead); unit file present but `disabled` | never in 7d | 0 |
| `nginx.service` | nginx reverse proxy | HTTPS 443 / HTTP 80→443 | `/telegram/webhook` → 8443, `/v1/` → 8444, `/health` → 200 literal | active | — | — |
| `docker.service` | systemd (Docker installed; no compose stack active in `/opt/*` observed) | — | — | active | — | — |
| `containerd.service` | systemd | — | — | active | — | — |

TLS cert via Let's Encrypt at `/etc/letsencrypt/live/api.onyxsecurity.co.za/`. `/etc/cron.d/certbot` refreshes 2× daily (superseded by systemd timer per comment).

### Mac (`/Users/zaks/omnix_dashboard`)

No launchd plists matching `onyx*` were found in `~/Library/LaunchAgents/`, `/Library/LaunchDaemons/`, or `/Library/LaunchAgents/`. All Mac processes are started from foreground shells under session `s000`:

| Process | Command | PID | Started | Supervisor |
|---|---|---:|---|---|
| Mac enhancement YOLO service | `/Users/zaks/omnix_dashboard/.venv-mac-enhancement/... python -u tool/monitoring_yolo_detector_service.py --config config/onyx.mac_enhancement.json` | 21967 | Sat 17:30 | `scripts/mac_enhancement_start.sh` (foreground) |
| Mac camera worker (dev) | `dart bin/onyx_camera_worker.dart` | 23714 | Sat 20:06 | `scripts/ensure_camera_worker.sh --config config/onyx.local.json --watchdog-loop` (foreground, PID 73037) |
| Mac camera worker log sink | `python scripts/rotating_log_sink.py --file tmp/onyx_camera_worker.log --max-bytes 52428800 --backups 3 --tee` | 23717 | Sat 20:06 | piped from `ensure_camera_worker.sh` |
| DVR CORS proxy (dev) | `python scripts/onyx_dvr_cors_proxy.py --config config/onyx.local.json --port 11635` | 72888 | Sat 20:06 | `scripts/ensure_dvr_proxy.sh --config config/onyx.local.json` (foreground, PID 72889) |
| Telegram Bot API + ElevenLabs TTS proxy (dev) | `dart bin/onyx_telegram_bot_api_proxy.dart --config config/onyx.local.json` | 72608 | Sat 20:06 | unknown (foreground) |

Persistent log file `/Users/zaks/omnix_dashboard/tmp/onyx_mac_enhancement.log` referenced by `scripts/mac_enhancement_start.sh` does not currently exist on disk.

### Supabase (cloud, `omnix-core`)

| Function | Version | Updated | Entry point |
|---|---:|---|---|
| `generate_patrol_triggers` | 4 | 2026-01-14 06:51:41 UTC | `supabase/functions/generate_patrol_triggers/index.ts` |
| `ingest-gdelt` | 7 | 2026-02-22 13:04:47 UTC | `supabase/functions/ingest-gdelt/index.ts` |
| `ingest_global_event` | 9 | 2026-02-25 13:28:48 UTC | `supabase/functions/ingest_global_event/index.ts` |
| `correlate_signals` | 8 | 2026-02-22 22:10:08 UTC | `supabase/functions/correlate_signals/index.ts` |
| `process_watch_decay` | 4 | 2026-02-22 22:39:12 UTC | `supabase/functions/process_watch_decay/index.ts` |
| `smart-handler` | 3 | 2026-02-24 23:15:17 UTC | `supabase/functions/smart-handler/index.ts` |

All `ACTIVE`. Trigger schedule (cron-like) not derivable from this CLI output — flagged `unknown — requires dashboard or `pg_cron` query`.

---

## 3. Database inventory (Supabase `omnix-core`, project ref `mnbloeoiiwenlywnnoxe`)

### 3.1 Method and limitations

Schema structure (columns, FK, indexes, RLS policies) is **inferred from SQL in `supabase/migrations/` and `deploy/supabase_migrations/`**. Live row counts and last-write timestamps were pulled via PostgREST (`Prefer: count=exact`, `order=...desc&limit=1`). The `information_schema`-level definitions were not executed against live DB (`supabase db dump` requires Docker).

### 3.2 Migration directories

- `supabase/migrations/` — 44 files, 2026-03-04 → 2026-04-17 (latest: `202604170002_zara_action_log.sql`)
- `deploy/supabase_migrations/` — 10 additional files, 2026-04-13 → 2026-04-14 (a **parallel set** that does not merge with the main migrations folder; presence-probe for live tables shows 9 of 10 are applied)

### 3.3 Tables in `public` schema — enumerated from migration SQL, live row counts via REST

| Table | Rows (live) | Last-write timestamp | Origin migration |
|---|---:|---|---|
| `alarm_accounts` | unknown (`*/0` from PostgREST) | unknown | `202604070002_create_alarm_receiver_registry.sql` |
| `client_contact_endpoint_subscriptions` | unknown (`*/0`) | unknown | `202603120007_create_client_messaging_bridge_tables.sql` |
| `client_contacts` | unknown (`*/0`) | unknown | `202603120007` |
| `client_conversation_acknowledgements` | 22 | unknown (no `created_at` visible) | `20260304_create_client_conversation_tables.sql` |
| `client_conversation_messages` | 20 | `created_at` latest `2026-03-10T10:50:13.203672+00:00` | `20260304` |
| `client_conversation_push_queue` | 11 | unknown | `202603050005` |
| `client_conversation_push_sync_state` | 2 | unknown | `202603050006` |
| `client_evidence_ledger` | **16388** | unknown — not listed in migrations in scope; queried by v2 (`lib/supabase/queries/ledger.ts`) | unknown — defined outside the scanned migration set |
| `client_messaging_endpoints` | 1 | unknown | `202603120007` |
| `clients` | 9 | unknown | `202603120001_create_guard_directory_tables.sql` |
| `controllers` | 3 | unknown | `202603120001` |
| `dispatch_current_state` | 27 | unknown — referenced by v2 | not in scanned migrations |
| `dispatch_intents` | 27 | unknown — referenced by v2 | not in scanned migrations |
| `dispatch_transitions` | 34 | unknown — referenced by v2 | not in scanned migrations |
| `employee_site_assignments` | 6 | unknown | `202603120002_expand_onyx_operational_registry.sql` |
| `employees` | 6 | unknown | `202603120002` |
| `fr_person_registry` | 5 | unknown | `20260410_create_fr_person_registry.sql` |
| `global_events` | 96 | unknown — written by `smart-handler`/`ingest_global_event`/`ingest-gdelt` edge functions | not in scanned migrations |
| `guard_assignments` | unknown (`*/0`) | unknown | `202603050001` / `20260410_create_guard_patrol_system.sql` |
| `guard_checkpoint_scans` | unknown (`*/0`) | unknown | `202603050001` |
| `guard_incident_captures` | unknown (`*/0`) | unknown | `202603050001` |
| `guard_location_heartbeats` | unknown (`*/0`) | unknown | `202603050001` |
| `guard_ops_events` | 3 | `occurred_at` latest `2026-03-11T11:20:06+00:00`; `received_at` latest `2026-03-11T11:20:07.212649+00:00` | `202603050002` |
| `guard_ops_media` | unknown (`*/0`) | unknown | `202603050002` |
| `guard_ops_replay_safety_checks` | 1 | unknown | `202603050009` |
| `guard_ops_retention_runs` | 1 | unknown | `202603050009` |
| `guard_panic_signals` | unknown (`*/0`) | unknown | `202603050001` |
| `guard_projection_retention_runs` | 2 | unknown | `202603050008` |
| `guard_sync_operations` | unknown (`*/0`) | unknown | `202603050001` |
| `guards` | 12 | unknown | `202603120001` |
| `hourly_throughput` | unknown (`*/0`) | unknown | `202604070003` |
| `incidents` | 241 | `signal_received_at` latest `2026-03-11T23:21:54.516128+00:00`; `updated_at` same | `202603120002` |
| `onyx_alert_outcomes` | unknown (`*/0`) | unknown | `deploy/supabase_migrations/202604140005_alert_outcomes.sql` |
| `onyx_awareness_latency` | unknown (`*/0`) | unknown | `deploy/supabase_migrations/202604140003_create_onyx_awareness_latency.sql` |
| `onyx_client_trust_snapshots` | unknown (`*/0`) | unknown | `deploy/supabase_migrations/202604140006_client_trust.sql` |
| `onyx_event_store` | unknown (`*/0`) | unknown | `deploy/supabase_migrations/202604130002_create_onyx_event_store.sql` |
| `onyx_evidence_certificates` | 282 | unknown | `deploy/supabase_migrations/202604140001_create_evidence_certificates.sql` |
| `onyx_operator_scores` | unknown (`*/0`) | unknown | `deploy/supabase_migrations/202604140004_operator_discipline.sql` |
| `onyx_operator_simulations` | unknown (`*/0`) | unknown | `deploy/supabase_migrations/202604140004` |
| `onyx_power_mode_events` | 31 | unknown | `deploy/supabase_migrations/202604140002_power_mode_events.sql` |
| `onyx_settings` | 1 | unknown | `202604070002` |
| `patrol_checkpoint_scans` | unknown (`*/0`) | unknown | `deploy/supabase_migrations/202604130004_patrol_checkpoint_scans.sql` |
| `patrol_checkpoints` | unknown (`*/0`) | unknown | `20260410_create_guard_patrol_system.sql` |
| `patrol_compliance` | unknown (`*/0`) | unknown | `20260410_create_guard_patrol_system.sql` |
| `patrol_routes` | unknown (`*/0`) | unknown | `20260410_create_guard_patrol_system.sql` |
| `patrol_scans` | unknown (`*/0`) | unknown | `20260410_create_guard_patrol_system.sql` |
| `roles` | unknown (`*/0`) | unknown — referenced by v2 `lib/supabase/queries/admin.ts` | not in scanned migrations |
| `site_alarm_events` | 11220 | `occurred_at` latest `2026-04-18T02:27:32.0703+00:00` | `20260409_create_site_alarm_events.sql` |
| `site_alert_config` | 1 | unknown | `20260410_create_site_alert_config.sql` |
| `site_api_tokens` | 2 | unknown | `20260410_create_site_api_tokens.sql` |
| `site_camera_zones` | 16 | unknown | `20260410_add_site_camera_zones.sql` |
| `site_expected_visitors` | 2 | unknown | `20260410_create_site_visitors.sql` |
| `site_identity_approval_decisions` | unknown (`*/0`) | unknown | `202603150001_create_site_identity_registry_tables.sql` |
| `site_identity_profiles` | unknown (`*/0`) | unknown | `202603150001` |
| `site_intelligence_profiles` | 1 | unknown | `20260410_create_site_intelligence_profile.sql` |
| `site_occupancy_config` | 1 | unknown | `20260409z_create_site_occupancy_tracking.sql` |
| `site_occupancy_sessions` | 10 | unknown | `20260409z` |
| `site_vehicle_presence` | unknown (REST returned empty content-range header) | unknown | `20260410_create_vehicle_presence.sql` |
| `site_zone_rules` | unknown (`*/0`) | unknown | `20260410_create_site_intelligence_profile.sql` |
| `site_zones` | 5 | unknown — referenced by v2 `lib/supabase/queries/sites.ts` | not in scanned migrations |
| `sites` | 8 | unknown | `202603120001` |
| `staff` | 3 | unknown | `202603120001` |
| `telegram_identity_intake` | unknown (`*/0`) | unknown | `202603150001` |
| `telegram_inbound_updates` | 98 | `received_at` latest `2026-04-19T23:08:23.988713+00:00` | `20260409_create_telegram_inbound_updates.sql` |
| `users` | unknown (`*/0`) | unknown — referenced by v2 `lib/supabase/queries/admin.ts` | not in scanned migrations |
| `vehicle_visits` | unknown (`*/0`) | unknown | `202604070003` |
| `vehicles` | 3 | unknown | `202603120002` |
| `zara_action_log` | unknown (`*/0`) | unknown | `202604170002_zara_action_log.sql` |
| `zara_scenarios` | unknown (`*/0`, empty array returned) | unknown | `202604170001_zara_scenarios.sql` |

Tables referenced by migrations but returned HTTP 404 on PostgREST probe (not applied to live DB):
- `telegram_operator_context` — defined in `deploy/supabase_migrations/202604130001`
- `site_shift_schedules` — defined in `deploy/supabase_migrations/202604130003`

Tables referenced by edge-function source but 404 on probe (may live in non-`public` schema or were renamed):
- `ingest_logs`, `correlation_signals`, `watch_decay_events` — 404
- `ledger_entries` — 404 (v2's `lib/supabase/queries/ledger.ts` writes `from("client_evidence_ledger")` instead — verified live with 16388 rows)
- `patrols`, `duty_states`, `watch_current_state` (referenced in `generate_patrol_triggers` and `process_watch_decay`) — not probed against live; flagged `unknown`.

Row counts for 7 days ago: **unknown** — no historical snapshot table is exposed via REST; derivation would require `pg_stat_statements` or a custom snapshot table.

### 3.4 Column lists, FK, indexes, RLS

**Method:** inferred from migration SQL; not verified against live `information_schema`.

A full per-column schema listing would require ~2000 lines of migration SQL to be reproduced here; the authoritative reference is `supabase/migrations/*.sql` (44 files) + `deploy/supabase_migrations/*.sql` (10 files). Flagged as **inferred from migrations — not verified against live DB**.

Headline RLS facts derivable from migration filenames:
- `202603050003_apply_guard_rls_storage_policies.sql` installs guard-scope RLS policies and helper functions `onyx_client_id()`, `onyx_guard_id()`, `onyx_has_site()`, `onyx_is_control_role()`, `onyx_role_type()`.
- `202603050010_add_guard_rls_storage_readiness_checks.sql` defines views `guard_rls_readiness_checks` and `guard_storage_readiness_checks`.
- `202603120005_add_directory_delete_policies.sql` adds DELETE policies on directory tables.
- `20260409_site_awareness_anon_read.sql` grants anon-read on site-awareness tables.
- `supabase/verification/guard_rls_policy_validation.sql` and `guard_storage_policy_validation.sql` are validation scripts.

RLS policy **presence** is therefore evidenced per table; policy body correctness is not in scope for Phase 1a.

### 3.5 Views, functions, triggers, RPCs

From migration scan (aggregated across `supabase/migrations/`):

- **Views:** `guard_rls_readiness_checks`, `guard_storage_readiness_checks` (both in `202603050010`).
- **Functions:**
  - `set_client_conversation_updated_at`, `set_client_conversation_push_queue_updated_at`, `set_client_conversation_push_sync_state_updated_at`
  - `set_guard_sync_updated_at`, `set_guard_ops_media_updated_at`, `set_guard_directory_updated_at`
  - `guard_ops_events_reject_mutation`
  - `onyx_client_id`, `onyx_guard_id`, `onyx_has_site`, `onyx_is_control_role`, `onyx_role_type`
  - `apply_guard_projection_retention`, `apply_guard_ops_retention_plan`, `assess_guard_ops_replay_safety`
  - `apply_site_risk_defaults`, `incidents_lock_closed_rows`
  - `sync_legacy_directory_employee`, `sync_legacy_directory_employee_trigger`, `sync_legacy_directory_assignment_trigger`
- **Triggers:** referenced implicitly via the `*_trigger` functions above; concrete `CREATE TRIGGER` statements exist in the same migrations.
- **RPC endpoints** exposed to PostgREST: not enumerated in this pass (would require `information_schema.routines` on live DB).

### 3.6 Storage buckets (live via `/storage/v1/bucket`)

| Bucket ID | Public | Type | Created | File count |
|---|---|---|---|---|
| `guard-shift-verification` | false | STANDARD | 2026-03-04T21:55:29Z | unknown |
| `guard-patrol-images` | false | STANDARD | 2026-03-04T21:55:29Z | unknown |
| `guard-incident-media` | false | STANDARD | 2026-03-04T21:55:29Z | unknown |

File counts per bucket: `unknown` — `/storage/v1/object/list/<bucket>` was not queried in this pass.

### 3.7 Edge functions

See Section 2 for the live list. Source now at `/tmp/sb_edge/supabase/functions/`:

| Function | LOC | External APIs called | Tables read/written |
|---|---:|---|---|
| `generate_patrol_triggers` | 76 | — | reads `patrols`, `duty_states` (both not probed live) |
| `ingest-gdelt` | 86 | `https://eventregistry.org/api/v1/article/getArticles` (requires `NEWSAPI_AI_KEY`) | writes `global_events` |
| `ingest_global_event` | 263 | `https://newsapi.org/v2/everything` (`NEWSAPI_KEY`), plus `NEWSDATA_KEY`, `NEWSAPI_AI_KEY` paths | writes `global_events` |
| `correlate_signals` | 165 | — | reads/writes with 500m / 30min haversine clustering (tables not extracted in this pass; flagged) |
| `process_watch_decay` | 124 | — | reads/writes `watch_current_state` (not probed live) |
| `smart-handler` | 35 | `https://newsapi.org/v2/everything` (`NEWS_API_KEY`, `NEWSDATA_KEY`) | in-memory collection (no DB writes observed in the 35 LOC) |

Trigger schedule: `unknown` — edge function CRON schedules are managed via Supabase dashboard and `pg_cron`; not surfaced by `supabase functions list`.

---

## 4. External integrations

| Service | Called from | Credentials source | Purpose |
|---|---|---|---|
| Supabase PostgREST | `bin/onyx_camera_worker.dart`; `bin/onyx_telegram_ai_processor.dart`; `bin/onyx_telegram_webhook.dart`; `bin/onyx_status_api.dart`; all v2 API routes via `lib/supabase/admin.ts`; all edge functions | env `ONYX_SUPABASE_URL`, `ONYX_SUPABASE_SERVICE_KEY` (Pi, Hetzner); `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (v2); `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (edge fns) | primary datastore |
| Telegram Bot API | `bin/onyx_camera_worker.dart:5025` + `:5075` (`Uri.https('api.telegram.org', '/bot$botToken/sendMessage')`); `bin/onyx_telegram_ai_processor.dart:2927`; `bin/onyx_telegram_webhook.dart:208`; `bin/onyx_status_api.dart:856`; `bin/onyx_telegram_bot_api_proxy.dart:8` | env `ONYX_TELEGRAM_BOT_TOKEN` | outbound alerts, inline keyboards, webhook registration |
| Hikvision ISAPI (alert stream + snapshot) | `bin/onyx_camera_worker.dart:2389` (`/ISAPI/Event/notification/alertStream`); `:2412` (`/ISAPI/System/status`); `:2435` (`/ISAPI/Streaming/channels/{id}/picture`); `tool/local_hikvision_dvr_proxy.dart` | env `ONYX_HIK_HOST`, `ONYX_HIK_PORT`, `ONYX_HIK_USERNAME`, `ONYX_HIK_PASSWORD`, `ONYX_HIK_KNOWN_FAULT_CHANNELS` (on Hetzner `/opt/onyx/config/worker.env`); config file on Pi `/opt/onyx/config/onyx.local.json` | DVR alert ingestion + camera snapshots |
| Hikvision RTSP | `tool/onyx_rtsp_frame_server.py:118` (`cv2.VideoCapture(self._rtsp_url, cv2.CAP_FFMPEG)`) | config keys in `onyx.local.json` (NVR host / password) | persistent frame grabbing per channel |
| Hik-Connect (cloud) | `tool/hik_connect_*.dart` (9 files) — default host `https://api.hik-connect.example.com` (stub / example) | env `ONYX_DVR_API_BASE_URL` | preflight / bundle tooling (not observed in live service journal) |
| OpenAI Responses API | `bin/onyx_telegram_ai_processor.dart:2302` (`https://api.openai.com/v1/responses`) | env `ONYX_TELEGRAM_AI_OPENAI_API_KEY` / `ONYX_TELEGRAM_AI_OPENAI_MODEL` / `ONYX_TELEGRAM_AI_OPENAI_ENDPOINT`; fallback env `OPENAI_API_KEY`, `OPENAI_MODEL`, `OPENAI_BASE_URL` | intent classification + reply generation for natural-language Telegram messages |
| ElevenLabs TTS | `bin/onyx_telegram_bot_api_proxy.dart:9` (`api.elevenlabs.io`); proxied via `/elevenlabs/tts/...` prefix | env `ONYX_ELEVENLABS_API_KEY` (not observed populated in Hetzner `worker.env` subset shown); voice ID passed per-request | text-to-speech voice generation (Mac dev environment only) |
| NewsAPI.org | edge `ingest_global_event`, `smart-handler` | env `NEWSAPI_KEY`, `NEWS_API_KEY` | global events ingestion |
| NewsData.io | edge `ingest_global_event`, `smart-handler` | env `NEWSDATA_KEY` | global events ingestion |
| NewsAPI.ai / EventRegistry | edge `ingest-gdelt`, `ingest_global_event` (`https://eventregistry.org/api/v1/article/getArticles`) | env `NEWSAPI_AI_KEY` | global events ingestion |
| `face_recognition` (Python lib, dlib-backed) | `tool/monitoring_yolo_detector_service.py:72,175,616,...` (lazy import) | env `ONYX_FR_ENABLED`; gallery `tool/face_gallery/` | face recognition (Mac enhancement tier only on this deployment — FR code path disabled on Pi per `ONYX_FR_ENABLED`) |
| OpenCV face recognition (`FaceDetectorYN_create`, `FaceRecognizerSF_create`) | `tool/monitoring_yolo_detector_service.py:717,723` | ONNX model paths auto-downloaded from `https://github.com/opencv/opencv_zoo/.../face_detection_yunet_2023mar.onnx` and `.../face_recognition_sface_2021dec.onnx`; cached at `tool/model_cache/opencv_face` | alternative FR pipeline (ONNX) — no credentials |
| EasyOCR | `tool/monitoring_yolo_detector_service.py:79,189,972,1069` (lazy import) | env `ONYX_LPR_ENABLED` | license plate recognition |
| Ultralytics YOLO | `tool/monitoring_yolo_detector_service.py` (model loading + `model.track(...)` at `:1544`) | model file path from `ONYX_MONITORING_YOLO_MODEL` (e.g. `models/yolo11l.pt` for Mac, `yolov8s.pt` on Pi) | object detection |
| ByteTrack (via ultralytics) | `tool/monitoring_yolo_detector_service.py:1488` (`bytetrack.yaml`); `:1544` (`model.track(..., tracker=..., persist=True)`) | env `ONYX_MONITORING_YOLO_TRACKING_ENABLED` (default `false`), `ONYX_MONITORING_YOLO_TRACKER` (default `bytetrack`) | multi-object tracking (disabled by default on Pi per Mac enhancement config) |
| OpenCV (`cv2`) | `tool/monitoring_yolo_detector_service.py`, `tool/onyx_rtsp_frame_server.py` | — | video I/O, image manipulation |
| Pillow (PIL) | `tool/onyx_rtsp_frame_server.py:17` | — | JPEG encode/decode |

**Hardcoded credentials:** none observed in the grepped source. All keys pulled from env or config files.

**Not observed in the backend code sampled:**
- Anthropic API, WhatsApp, Twilio, Olarm, SIA DC-09 receiver, Ollama — no matching imports or URLs found in the grep sweep. Flagged `not observed — unknown if used elsewhere`.

---

## 5. Telegram bot surface

### 5.1 Architecture

- **Inbound path:** Telegram → nginx at `api.onyxsecurity.co.za/telegram/webhook` → `127.0.0.1:8443` (`onyx-telegram-webhook.service`, source `bin/onyx_telegram_webhook.dart`) → `insert` into Supabase `telegram_inbound_updates`.
- **Processing:** `onyx-telegram-ai-processor.service` (source `bin/onyx_telegram_ai_processor.dart`) polls `telegram_inbound_updates` every 2s (default), passes text to `OnyxTelegramCommandRouter`, optionally queries OpenAI, replies via Telegram API.
- **Outbound alert path (Pi):** `bin/onyx_camera_worker.dart` sends alert messages directly to `api.telegram.org/bot<token>/sendMessage` with an inline-keyboard reply markup; callbacks come back via the same `telegram_inbound_updates` pipeline.

### 5.2 Intent router — `OnyxTelegramCommandRouter`

Defined at `lib/application/telegram_command_router.dart` (515 LOC, last modified 2026-04-07) **and re-declared inline at `bin/onyx_telegram_ai_processor.dart:2956–...`**. The router matches normalized input text against fixed phrase sets; it is not a slash-command parser.

| Intent type (`OnyxTelegramCommandType`) | Trigger phrases (sample, verbatim) | Handler location |
|---|---|---|
| `liveStatus` | `"status"`, `"what's happening"`, `"any activity"`, `"everything okay"`, `"all good"`, `"whats on site"`, `"how many people"`, `"count"`, `"occupancy"`, `"how many residents"`, `"anyone home"`, `"who is home"`, `"which cars are home"` (22 phrases) | `bin/onyx_telegram_ai_processor.dart` `_handleLiveStatus(...)` |
| `gateAccess` | `"gate"`, `"door"`, `"locked"`, `"closed"`, `"open"`, `"access"`, `"entry"` | `_handleGateAccess(...)` |
| `incident` | `"incident"`, `"what happened"`, `"last night"`, `"today"`, `"yesterday"`, `"show incident"` | `_handleIncident(...)` |
| `dispatch` | `"response"`, `"dispatch"`, `"eta"`, `"arrived"`, `"who responded"` | `_handleDispatch(...)` |
| `guard` | `"guard"`, `"patrol"`, `"checkpoint"`, `"guard on site"`, `"missed patrol"`, `"did guard patrol"`, `"guard status"` | `_handleGuard(...)` |
| `report` | `"report"`, `"summary"`, `"weekly"`, `"monthly"`, `"send report"`, `"patrol report"` | `_handleReport(...)` |
| `camera` | `"show me"`, `"camera"`, `"visual"`, `"clip"`, `"what triggered"` | `_handleCamera(...)` |
| `intelligence` | `"most risky"`, `"worst day"`, `"getting worse"`, `"trends"`, `"patterns"`, `"unusual"` | `_handleIntelligence(...)` |
| `actionRequest` | `"send response"`, `"escalate"`, `"call guard"`, `"dispatch"` | `_handleActionRequest(...)` |
| `visitorRegistration` | `"cleaner is coming"`, `"cleaner is here"`, `"expecting a visitor"`, `"contractor coming tomorrow"`, `"gardener today"`, `"just arrived"`, `"came in"`, `"letting in"`, `"leaving now"` (~25 phrases) | `bin/onyx_telegram_ai_processor.dart:347` → `_handleVisitorRegistration(...)` at `:630` |
| `frOnboarding` | `_frOnboardingTriggers` set (contents truncated in scan) | `_handleFrOnboarding(...)` |
| `clientStatement` | (fall-through for identity/clarification phrases) | handled by identity intake path |
| `unknown` | (no match) | falls through to LLM / generic reply |

### 5.3 Callback handlers (inline-keyboard actions on alert messages)

Defined in `bin/onyx_camera_worker.dart:4764` (`_telegramInlineKeyboardForAlert`) and dispatched in `bin/onyx_telegram_ai_processor.dart:717`:

| Callback action (`_OnyxAlertCallbackAction`) | Handler | Line |
|---|---|---|
| `dispatch` | `_handleDispatchCallback(...)` | `bin/onyx_telegram_ai_processor.dart:809` |
| (additional actions exist in `_OnyxAlertCallbackAction` enum) | sibling `_handle*Callback(...)` methods | flagged: full enum list not extracted — `unknown without re-reading 4700+-line file` |

`removeInlineKeyboard: true` is passed through `_sendReply(...)` at `:1257` / `:1268` to clear the keyboard after action.

### 5.4 Slash commands

No literal `/` slash-command parser was found via grep of `bin/onyx_telegram_ai_processor.dart`. The bot dispatches on **natural-language triggers** (phrase-set matching), not Telegram slash commands.

### 5.5 Handler routing code path

`bin/onyx_telegram_ai_processor.dart:347`:
```
OnyxTelegramCommandType.visitorRegistration => _handleVisitorRegistration(
```

indicates the router uses a Dart 3 `switch expression` mapping each `OnyxTelegramCommandType` to a `_handle*` method. Full dispatch table not dumped; evidence: 1 match for `visitorRegistration` shown, structure implies a symmetric switch across all 13 enum cases.

---

## 6. API and endpoint inventory

### 6.1 Next.js Route Handlers (`/Users/zaks/onyx_dashboard_v2/app/api/**`)

All handlers import from `@/lib/supabase/admin` (service-role client) and apply a same-origin guard. `lib/supabase/server.ts` exists but **no probe showed it being imported by any handler in this pass**.

| Method | Path | Purpose | LOC | Last modified |
|---|---|---|---:|---|
| GET | `/api/admin` | admin-panel data (reads `users`, `roles`) | 43 | 2026-04-19 20:47 |
| GET | `/api/ai-queue` | Zara task queue projection | 43 | 2026-04-19 16:52 |
| GET | `/api/clients` | clients list | 50 | 2026-04-19 09:12 |
| GET | `/api/command/dispatches` | command-center slow feed | 41 | 2026-04-19 13:17 |
| GET | `/api/command/events` | command-center event stream | 43 | 2026-04-19 13:17 |
| GET | `/api/command/queue` | command-center active queue | 43 | 2026-04-19 13:17 |
| GET | `/api/dispatches` | dispatches page feed | 43 | 2026-04-19 20:22 |
| GET | `/api/events` | events page feed | 44 | 2026-04-19 10:22 |
| GET | `/api/governance` | governance/attestations | 43 | 2026-04-19 13:56 |
| GET | `/api/guards` | guards list | 44 | 2026-04-19 08:40 |
| GET | `/api/incidents` | incidents list | 55 | 2026-04-19 07:44 |
| PATCH | `/api/incidents/[id]` | triage mutation — sets one of `dispatch`/`false_alarm`/`escalate` with `controller_notes`; same-origin guard only, no user session | 106 | 2026-04-19 07:56 |
| GET | `/api/intel` | intel snapshot | 43 | 2026-04-19 14:14 |
| GET | `/api/ledger` | ledger feed (paged) | 60 | 2026-04-19 12:43 |
| GET | `/api/ledger/facets` | ledger facet counts (bulk-type sampled) | 52 | 2026-04-19 12:43 |
| GET | `/api/reports` | reports portfolio | 43 | 2026-04-19 16:09 |
| GET | `/api/sites` | sites snapshot | 45 | 2026-04-19 08:12 |
| GET | `/api/track` | map/track snapshot | 43 | 2026-04-19 16:40 |
| GET | `/api/vip` | VIP principal snapshot | 43 | 2026-04-19 15:52 |

**Count:** 19 handlers, 18 GET + 1 PATCH.

### 6.2 Supabase edge functions

See Section 3.7 for the per-function breakdown. Each is reachable at `https://mnbloeoiiwenlywnnoxe.supabase.co/functions/v1/<slug>`.

### 6.3 Python HTTP services (Pi)

| Service | Bind | Path(s) (from code) | Source |
|---|---|---|---|
| `onyx-yolo-detector.service` | `127.0.0.1:11636` (config default; `ONYX_MONITORING_YOLO_HOST`, `ONYX_MONITORING_YOLO_PORT`) | `/detect` (POST JPEG); plus other paths evidenced by the 2261-LOC file but not enumerated in this pass | `tool/monitoring_yolo_detector_service.py` |
| `onyx-rtsp-frame-server.service` | `127.0.0.1:11638` (default; `--port 11638`, `--host` arg) | `/snapshot/<channel>` referenced from `bin/onyx_camera_worker.dart:1312` as `http://192.168.0.67:11638/snapshot/$normalizedChannelId` | `tool/onyx_rtsp_frame_server.py` |

### 6.4 Dart HTTP services

| Service | Host | Bind | Path | Source |
|---|---|---|---|---|
| `onyx-dvr-proxy.service` | Pi | `127.0.0.1:11635` | transparently proxies `/ISAPI/...` upstream to DVR at 192.168.0.117 | `tool/local_hikvision_dvr_proxy.dart` + `lib/application/local_hikvision_dvr_proxy_service.dart` |
| `onyx-telegram-webhook.service` | Hetzner | `127.0.0.1:8443` (proxied by nginx `/telegram/webhook`) | accepts Telegram webhook POSTs | `bin/onyx_telegram_webhook.dart` |
| `onyx-status-api.service` | Hetzner | `127.0.0.1:8444` (proxied by nginx `/v1/*`) | status endpoints (paths not enumerated in this pass — `_getPath == '/v1'` / `/responses` observed in code) | `bin/onyx_status_api.dart` |
| `onyx_telegram_bot_api_proxy.dart` (Mac dev) | Mac | listens locally (port not in this probe output — flagged `unknown`) | `/elevenlabs/tts/<voice>` + wildcard Telegram passthrough | `bin/onyx_telegram_bot_api_proxy.dart` |

### 6.5 Nginx (Hetzner) routes

| Location | Upstream | Notes |
|---|---|---|
| `/telegram/webhook` | `http://127.0.0.1:8443` | Telegram webhook |
| `/v1/` | `http://127.0.0.1:8444` | Status API |
| `/health` | literal `200 "ONYX API OK"` | health probe |
| `:80 → :443 301` | — | HTTP redirect |
| `:443 ssl` | via Let's Encrypt cert | — |

No other listening ports on Hetzner besides `22/SSH`, `80/443/nginx`, loopback `53/systemd-resolved`, and the two loopback dart services.

---

## 7. Scripts and tooling

**Total:** 85 files in `/Users/zaks/omnix_dashboard/scripts/`. Grouped by role below; last-modified dates from `git log`.

### 7.1 Deployment / setup

| Path | Purpose | Triggered |
|---|---|---|
| `scripts/deploy_to_pi.sh` | wraps rsync + remote systemctl restart to push to `onyx@192.168.0.67:/opt/onyx` | manual |
| `scripts/deploy_pi_msvallee.sh` | older Pi-specific deploy (not in git log — probably gitignored) | manual |
| `scripts/deploy_ai_processor.sh` | deploys `bin/onyx_telegram_ai_processor.dart` to Hetzner | manual |
| `scripts/setup_pi.sh` | Pi installer: apt deps, venv, systemd units, swap file, yolov8s | manual (one-shot per Pi) |
| `scripts/mac_enhancement_setup.sh` | creates `.venv-mac-enhancement`, pulls YOLO model | manual |
| `scripts/mac_enhancement_start.sh` | foreground runner for Mac enhancement tier (YOLO11l + MPS + FR + LPR) on port 11636 | manual |
| `scripts/install-hooks.sh` | installs git hooks | manual |
| `scripts/post-commit-hook.sh` | hook body — writes `SESSION_STATE.md` | git hook |

### 7.2 Service supervisors (development and Pi)

| Path | Purpose | Triggered |
|---|---|---|
| `scripts/ensure_camera_worker.sh` | watchdog loop for camera worker | foreground / systemd-equivalent on dev |
| `scripts/ensure_dvr_proxy.sh` | watchdog for DVR proxy | foreground |
| `scripts/ensure_rtsp_frame_server.sh` | watchdog for RTSP frame server | foreground |
| `scripts/ensure_yolo_server.sh` | watchdog for YOLO server | foreground |
| `scripts/ensure_telegram_bot_api_proxy.sh` | watchdog for Telegram API proxy | foreground |
| `scripts/run_camera_worker.sh` | invoked by systemd `ExecStart` | by `onyx-camera-worker.service` |
| `scripts/start_yolo_server.sh` | invoked by systemd `ExecStart` | by `onyx-yolo-detector.service` |
| `scripts/restart_onyx.sh` | restart helper | manual |
| `scripts/stop_onyx.sh` | stop helper | manual |
| `scripts/onyx_watchdog.sh` | watchdog harness | manual |
| `scripts/onyx_status.sh` | status reporter | manual |

### 7.3 Utilities

| Path | Purpose | Triggered |
|---|---|---|
| `scripts/rotating_log_sink.py` | stdin → rotated-file log adapter | piped by `ensure_*.sh` |
| `scripts/onyx_dvr_cors_proxy.py` | Mac-dev DVR CORS proxy (port 11635) | foreground |
| `scripts/watch_onyx_quick_actions.py` | quick-action log watcher | manual |
| `scripts/watch_telegram_updates.py` | Supabase `telegram_inbound_updates` tailer | manual |
| `scripts/onyx_ops_preflight.sh` | pre-ops checks | manual |
| `scripts/onyx_runtime_profile.sh` | runtime profile dumper | manual |
| `scripts/clean_zara_smoke.dart` | scenario cleanup | manual |
| `scripts/run_onyx_chrome_local.sh` | launches web build in Chrome | manual |
| `scripts/run_claude_audit.sh` | Claude audit runner (101 LOC) | manual |
| `scripts/telegram_quick_action_live_smoke.sh` | Telegram smoke test | manual |
| `scripts/ui_compact_smoke.sh` | UI compact smoke test | manual |
| `scripts/guard_supabase_remote_smoke.sh` | Supabase smoke | manual |

### 7.4 Validation / gate / signoff (CI-oriented)

55 scripts matching `scripts/guard_android_*.sh` (14), `scripts/onyx_cctv_*.sh` (9), `scripts/onyx_dvr_*.sh` (9), `scripts/onyx_listener_*.sh` (14), `scripts/guard_*_gate*.sh` / `guard_*_readiness_*.sh` (5), plus `scripts/onyx_validation_bundle_certificate.sh`. All dated 2026-03-06 → 2026-03-19. Individual purposes are captured in filenames (`_field_gate.sh`, `_mock_validation_artifacts.sh`, `_pilot_gate.sh`, `_release_gate.sh`, `_release_trend_check.sh`, `_signoff_generate.sh`, `_parity_report.sh`, `_cutover_decision.sh`, etc.). Trigger: manual or invoked from higher-level gate scripts; not wired to any cron or systemd unit.

---

## 8. Inference pipeline map

### 8.1 Frame ingestion path

1. Hikvision DVR at `192.168.0.117` exposes RTSP streams (port 554) and ISAPI event/picture endpoints (port 80).
2. `onyx-rtsp-frame-server.service` on Pi runs `tool/onyx_rtsp_frame_server.py`:
   - opens one `cv2.VideoCapture(rtsp_url, cv2.CAP_FFMPEG)` per channel (per-channel thread; `ChannelState` dataclass holds `latest_jpeg`, `latest_resolution`, `connected`, `source`, `error`)
   - exposes HTTP on `127.0.0.1:11638` with path `/snapshot/<channel>` (referenced from camera worker at `bin/onyx_camera_worker.dart:1312` as `http://192.168.0.67:11638/snapshot/$normalizedChannelId`)
3. `onyx-dvr-proxy.service` on Pi proxies the DVR's `/ISAPI/*` endpoints via `127.0.0.1:11635`.
4. `onyx-camera-worker.service` subscribes to the ISAPI alert stream via the local DVR proxy, pulls snapshots (either from the RTSP frame server or directly from ISAPI `/ISAPI/Streaming/channels/{id}/picture`), and forwards to YOLO for inference.

### 8.2 YOLO service

- **Entry point:** `tool/monitoring_yolo_detector_service.py` (2261 LOC)
- **Bind:** `127.0.0.1:11636` (`ONYX_MONITORING_YOLO_HOST`, `ONYX_MONITORING_YOLO_PORT`)
- **Model:** `ONYX_MONITORING_YOLO_MODEL` env — `yolov8s.pt` on Pi (see `/opt/onyx/yolov8s.pt`), `models/yolo11l.pt` on Mac enhancement (see `config/onyx.mac_enhancement.json`)
- **Device:** `ONYX_MONITORING_YOLO_DEVICE` — `mps` on Mac, default (CPU) on Pi
- **Per-source locking:** enabled — each source has its own lock to serialize inference
- **Watchdog:** per-inference ceiling `_YOLO_INFERENCE_WATCHDOG_SECONDS = 30.0` (file header comment: "If one call exceeds this, the main request thread abandons it, logs `[ONYX-YOLO-WATCHDOG] …`, returns a synthetic failure … releases the per-source lock. The stuck thread keeps running — Python can't terminate a thread stuck in a native call — so repeated hangs WILL accumulate memory")
- **Per-stage timing:** observed in the file (commit history refers to commits 370fa10 + 1be22c3 adding per-stage timing)

### 8.3 Face recognition

- **Entry point:** `tool/monitoring_yolo_detector_service.py` (same process)
- **Gate:** `ONYX_FR_ENABLED` env (default `false` on Pi; `true` on Mac enhancement per `config/onyx.mac_enhancement.json`)
- **Primary backend:** `face_recognition` Python lib (dlib-backed) — `face_locations(rgb, model="cnn")` with fallback to `model="hog"`; gallery at `tool/face_gallery/` refreshed via `_refresh_gallery(...)`.
- **Secondary / ONNX backend:** OpenCV `FaceDetectorYN_create` + `FaceRecognizerSF_create` with ONNX models from `opencv_zoo` cached in `tool/model_cache/opencv_face`.
- **Threshold:** `ONYX_MONITORING_FR_MATCH_THRESHOLD` (0.37 in Mac enhancement config)
- **Gallery location:** `tool/face_gallery/` (PII — gitignored)
- **Output destination:** HTTP response to camera worker (same JSON envelope as YOLO detection response).

### 8.4 LPR (EasyOCR)

- **Entry point:** `tool/monitoring_yolo_detector_service.py`
- **Gate:** `ONYX_LPR_ENABLED` env
- **Model:** `easyocr` Python module (lazy import at `:79` / `:189`)
- **Config:** languages from `ONYX_MONITORING_LPR_LANGS` (`en`), min confidence `ONYX_MONITORING_LPR_MIN_CONFIDENCE` (`0.55`), allowlist `ONYX_MONITORING_LPR_ALLOWLIST`, plate regex `ONYX_MONITORING_LPR_PLATE_REGEX`
- **Output destination:** same JSON envelope as YOLO detection response (returned to camera worker).

### 8.5 ByteTrack (multi-object tracking)

- **Wiring:** `tool/monitoring_yolo_detector_service.py:1544` — `model.track(..., tracker=self._tracker_config_name(), persist=True)`
- **Config name:** `"bytetrack.yaml"` (`_tracker_config_name(...)` at `:1488`)
- **Gate:** `ONYX_MONITORING_YOLO_TRACKING_ENABLED` (default **false** on Pi; **true** in Mac enhancement config)
- **Track TTL:** `ONYX_MONITORING_YOLO_TRACK_TTL_SECONDS` (180s in Mac enhancement config)
- **Note (code comment at `:1220`):** "set `ONYX_MONITORING_YOLO_TRACKING_ENABLED=true` to opt in"

### 8.6 Alert pipeline (end-to-end)

1. ISAPI alert event hits `bin/onyx_camera_worker.dart` via `onyx-dvr-proxy` (`/ISAPI/Event/notification/alertStream`).
2. Camera worker resolves the snapshot (RTSP frame server first, ISAPI snapshot fallback) — see `bin/onyx_camera_worker.dart:2833`: `'[ONYX] FR: Falling back to ISAPI snapshot for CH${channelId.trim()}.'`.
3. Camera worker POSTs the JPEG to the YOLO detector at `ONYX_MONITORING_YOLO_ENDPOINT` (default `http://127.0.0.1:11636/detect`) with timeout `ONYX_MONITORING_YOLO_REQUEST_TIMEOUT_MS` (default 3000ms per `config/onyx.local.example.json` note).
4. Camera worker enriches the alert (adds detection metadata, YOLO-fallback synthetic confidence `0.99` when YOLO is unreachable), writes to Supabase (`incidents`, `site_alarm_events`), and sends Telegram alert via `api.telegram.org/bot<token>/sendMessage` with inline keyboard (`_telegramInlineKeyboardForAlert` at `bin/onyx_camera_worker.dart:4764`).
5. Operator clicks a callback button (e.g. `dispatch` / `false_alarm`) → update arrives via webhook (Hetzner) → `telegram_inbound_updates` → processor routes to `_handleDispatchCallback(...)` at `bin/onyx_telegram_ai_processor.dart:809`.

### 8.7 Pi → Mac enhancement handoff

- **Protocol:** HTTP POST JPEG to `ONYX_MONITORING_YOLO_ENDPOINT`, same endpoint shape as the Pi-local YOLO.
- **Current wiring:** the Pi can be pointed at the Mac (e.g. `http://192.168.0.7:11636/detect` per `config/onyx.local.example.json` note) by setting `ONYX_MONITORING_YOLO_ENDPOINT` in the Pi's config. The default on the Pi is `http://127.0.0.1:11636/detect` (local YOLO).
- **Fallback timeout:** `ONYX_MONITORING_YOLO_REQUEST_TIMEOUT_MS` (3000ms default per `config/onyx.local.example.json` comment "Default 3000ms. Camera worker falls through to raw-snapshot Telegram delivery (commit 85ca876) if the timeout fires").
- **Decision point:** the camera worker at `bin/onyx_camera_worker.dart` around line 4969–5131 resolves the endpoint URL, issues the POST, and on timeout emits a raw-snapshot Telegram alert with synthetic confidence rather than blocking on enhancement.
- **Mac service** (`scripts/mac_enhancement_start.sh`) binds the YOLO detector to `0.0.0.0:11636` per `config/onyx.mac_enhancement.json` so the Pi on the LAN can reach it. The script tees to `tmp/onyx_mac_enhancement.log` (currently missing on disk).
- **Supervision:** Mac is foreground-only (no launchd). Pi service is `onyx-yolo-detector.service`.

---

*End of inventory — Phase 1a. Next phase: 1b (dashboard parity), to read Flutter `lib/` UI and v2 `app/` pages against the data substrate mapped above.*
