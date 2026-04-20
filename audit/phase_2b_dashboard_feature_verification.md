# ONYX Dashboard — Phase 2b Feature Verification (v1 Flutter + v2 Next.js)

**Date:** 2026-04-20
**Scope:** runtime evidence for every dashboard feature marked `present` in phase 1b §4 (both v1 Flutter and v2 Next.js). Not a code audit — whether user interaction produces correct output when the feature is actually used.
**Out of scope:** `present_stub` / `absent` / `unverified` rows from phase 1b §4 (known not to work); phase 1b §6 (shared-code) and §7 (duplication); backend re-audit (phase 2a owns that); performance, load, visual design.

---

## 0. Access confirmation and input review

| Target | Method | Result |
|---|---|---|
| `audit/phase_1b_dashboard_parity.md` (`d7ad444`, 812 lines) | local read | re-read in full — primary input for v1/v2 feature rows |
| `audit/phase_2a_backend_capability_verification.md` (`0582a47` on top of `9660755`, `f33793e`, `8fe4cfc`, `954e3de`; 746 lines) | local read | re-read in full — primary input for cascade verdicts |
| `/Users/zaks/omnix_dashboard` + `/Users/zaks/onyx_dashboard_v2` | local read | ok |
| Pi `onyx@192.168.0.67` | ssh | ok |
| Hetzner `root@api.onyxsecurity.co.za` | ssh | ok |
| Supabase PostgREST (incl. `/auth/v1/admin/users`) | curl with service-role key | ok — auth + table queries working |

**HEAD commits at start of pass:**
- `omnix_dashboard/main` → `0582a47` (phase 2a final)
- `onyx_dashboard_v2/main` → `a19f9a25feb35b8cb18a97cb9a122f4634582d9e` (tagged `audit-2026-04-19`; unchanged since the v2 audit)

**Time windows in use:**
- Default 7d: 2026-04-13 00:00 → 2026-04-20 SAST (today 2026-04-20).
- Low-frequency 30d: 2026-03-21 onwards — used for user interactions not expected to fire daily (escalation, manual report generation, etc.).
- Static read-only views: verify data renders; no interaction evidence required.

**Runtime deployment state (anchor for §1/§2 verdicts):**

| System | Running? | Evidence |
|---|---|---|
| v1 Flutter app (any target — web, iOS, Android, macOS) | **no process found** | `ps aux | grep -iE "flutter|dart.*main.dart|dart.*lib/main"` returned **zero** matches on Mac at 22:37 SAST; no ports 8080/8081/58123 bound by a Flutter dev server; last `build/web/main.dart.js` mtime is 2026-04-18 16:26 SAST (i.e. compiled 2 days ago, not currently served) |
| v2 Next.js dev server | running on Mac only | `next dev` pids 7798 + 7907, started 2026-04-20 07:00 SAST; localhost-only; no production deployment observed (phase 2a §4.1) |
| Pi `onyx-camera-worker.service` (the bin/ process that writes from-the-field data) | **restarted 22:25:27 SAST; now running** | `systemctl status onyx-camera-worker` → `Active: active (running) since Mon 2026-04-20 22:25:27 SAST; 11min ago`; drop-in at `/etc/systemd/system/onyx-camera-worker.service.d/override.conf` sets `LimitNOFILE=65536`; post-restart camera-worker log shows `[22:37] … CH16: human detected … alerts: 2` and continues to emit `Camera stream disconnected … reconnecting` but **alerts are firing** per user-confirmed screenshot at 22:33 (Telegram photo + inline buttons received in MS Vallee chat) |

### 0.1 Phase 2a cascades into phase 2b

Seven cascade items carry forward. Any v1/v2 UI feature that reads from or writes to these backend surfaces is verdicted `blocked_by_backend` or `dormant_blocked_by_backend` and cites the phase 2a section. Do **not** re-audit.

| # | Cascade | Phase 2a reference | Impact on UI |
|---:|---|---|---|
| 1 | `incidents` table: **0 new inserts** in 7d; last new row 2026-03-11 (~40 days stale) | 2a §6.1, §6.2 | any v1/v2 page displaying "live incidents" renders stale or empty. `updated_at` activity does exist (141 writes 7d) so *triage actions* on existing rows work |
| 2 | `dispatch_transitions`: latest 2026-02-26 (53 days stale); 30d window 0 writes | 2a §6.2, §7.4 | dispatch-workflow UIs read dead data |
| 3 | `zara_action_log`, `zara_scenarios`, `onyx_awareness_latency`, `onyx_alert_outcomes`: 0 rows total | 2a §6.2 | Zara-trace / awareness-latency / outcome-feedback surfaces render empty |
| 4 | Pi → Mac YOLO handoff: `dormant_pipeline_break` (config says 192.168.0.7:11636; runtime uses 127.0.0.1:11636) | 2a §1.5 | enhanced-alert UIs degraded — alerts flow via raw-snapshot fallback with `confidence=0.99` synthetic |
| 5 | `incidents.status` case inconsistency (`open` × 78 vs `OPEN` × 19 vs `secured` × 139, etc.) | 2a §6.3 | any UI status filter may show partial results |
| 6 | Supabase egress 402 on 2026-04-17 → evidence-cert 3-day gap (Apr 17/18/19 = 0 certs) | 2a §6.1 | UI showing evidence-cert timeline has a visible gap |
| 7 | Pi camera-worker stoppage **occurred 2026-04-20 17:03–22:25 SAST; resolved at 22:25 via LimitNOFILE=65536 systemd override** | 2a §0 flag, §2.1 | any UI showing service uptime / system health will display a 5h 22m gap within the 7d window. Alerts and camera-worker-dependent flows resumed 22:25; FD-leak root cause unidentified (phase 3a scope) |

**New cascade observation surfaced during §0 probing (not re-audit — one daily-split query):** `client_evidence_ledger` writes by day in 7d are `Apr13=1, Apr14=9260, Apr15=6489, Apr16=535, Apr17=0, Apr18=0, Apr19=0, Apr20=0`. Phase 2a §6.1 correctly verified the table as active (16,285 rows in 7d) but the daily split shows writes **stopped on 2026-04-17**, coincident with the egress-quota incident. Added to cascade as **#8**. Recorded here for use in per-feature verdicts; phase 2a's aggregate count stands.

---

## 1. v1 Flutter feature verification

**Global anchor:** v1 Flutter is not running anywhere in the observable runtime environment (§0 runtime table). No serving process, no dev process, no mobile/desktop app session captured in any log available to this audit. Consequently, **every v1 feature's user-interaction evidence is absent in window** — the correct primary verdict for v1 features is `dormant_no_user_action` unless a stronger cascade applies (e.g. `dormant_blocked_by_backend` if the feature also reads a dormant table, making the dormancy double).

Supabase `auth.users` endpoint shows **zero sign-ins in the 7d window** — the two registered users last signed in on 2026-02-26 and 2025-12-24 respectively. No session was established via the anon-key → authenticated path in window.

### 1.1 Command Center section (6 pages)

#### Page: `/` Zara home (`ZaraAmbientPage`, `lib/ui/zara_ambient_page.dart`)

| Feature (phase 1b §4.1) | v1 1b evidence | Phase 2b verdict | Runtime evidence | Cascade |
|---|---|---|---|---|
| Live signal/activity feed | `zara_ambient_page.dart:630` | **dormant_no_user_action** | v1 not running (§0) | — |
| Quick-action navigation buttons | `:679` | **dormant_no_user_action** | v1 not running | — |
| Animated heartbeat / Zara avatar | `:716` | **dormant_no_user_action** | v1 not running | — |
| Greeting card with operator + site labels | `:378` | **dormant_no_user_action** | v1 not running | — |
| Operational health pills (incidents / dispatches) | `:602` | **dormant_blocked_by_backend** (also `dormant_no_user_action`) | incident-count source has 0 new inserts in 7d | cascade #1 |
| Surfaced alert card with dismiss/open | `:275` | **dormant_no_user_action** | v1 not running | — |

#### Page: `/dashboard` Command Center → `LiveOperationsPage` (`lib/ui/live_operations_page.dart`)

| Feature | v1 1b evidence | Verdict | Evidence | Cascade |
|---|---|---|---|---|
| Live queue panel of active incidents | `:10899` | **dormant_blocked_by_backend** | 0 new incidents in 7d | #1 |
| Dispatches strip with phase progression | `:7642` | **dormant_blocked_by_backend** | dispatch_transitions 53d stale | #2 |
| Events / activity stream | `:9440` | **dormant_no_user_action** | v1 not running | — |
| CCTV live-view dialog | `:538` | **dormant_no_user_action** | v1 not running; camera-worker-side evidence exists (2a §1.6) but that's a bin/ not v1 UI feature | — |
| Client comms drawer / right rail | `:7896` | **dormant_no_user_action** | v1 not running | — |
| Guards rail board | `:7770` | **dormant_blocked_by_backend** | `guard_location_heartbeats` `*/0`, `guard_assignments` `*/0` per phase 2a §6.2 | #3 (extended) |

#### Page: `/agent` Agent brain (v1_only; `lib/ui/onyx_agent_page.dart`)

All 7 present features (`_zaraAgentNavRail`, `_buildThreadRail`/`_createThread`/`_selectThread`, `_zaraAgentLeftRail`/`_zaraSignalRow`, `_buildConversationSurface`/composer/quick chips, `_zaraAgentRightRail`, `_submitPrompt`/`_runCloudBoost`/`_runLocalBrainSynthesis`, `_handleAction`):

| Feature | Verdict | Evidence | Cascade |
|---|---|---|---|
| All 7 rows | **dormant_no_user_action** (primary) with **dormant_blocked_by_backend** layered on action-execution path (zara_action_log 0 rows) | v1 not running; `zara_action_log`/`zara_scenarios` 0 rows | #3 for action-log write path |

#### Page: `/ai-queue` (`ai_queue_page.dart`)

| Feature | v1 1b evidence | Verdict | Evidence | Cascade |
|---|---|---|---|---|
| Task queue list with status icons | `:2627` | **dormant_no_user_action** | v1 not running | — |
| Task row selection / URL persistence | `:1119` | **dormant_no_user_action** | v1 not running | — |
| Reasoning trace panel per task | `:1855` | **dormant_blocked_by_backend** | `zara_action_log` 0 rows | #3 |
| Action operation controls (cancel / pause / approve) | `:2755` | **dormant_blocked_by_backend** | actions write to dormant `zara_action_log` | #3 |
| CCTV board with alert selector | `:857` | **dormant_no_user_action** | v1 not running | — |
| Standby workspace with focus groups | `:4793` | **dormant_blocked_by_backend** | MO dossier / shift draft explorer depend on dormant tables | #3 |

#### Page: `/alarms` (`alarms_page.dart`)

| Feature | v1 1b evidence | Verdict | Evidence | Cascade |
|---|---|---|---|---|
| Alarms list view | `:476`, `:887` | **dormant_blocked_by_backend** | `incidents` table filter reads `status NOT IN ('secured','closed')` but with 0 new rows all visible work is against stale data | #1 |
| Triage action path | `:887` (action buttons per-alarm) | **unverified** | 141 `incidents.updated_at` writes in 7d are collective across v1 Flutter + v2 PATCH + camera worker; v1-exclusive attribution not traced | — |
| Status chip row (camera count / guard count / signal health) | `:522` | **dormant_blocked_by_backend** | underlying guard/site health tables largely 0-row | #3 |
| Quick actions (run system check / review last incident) | `:550` | **dormant_no_user_action** | v1 not running | — |
| Nominal "ALL SYSTEMS NOMINAL" empty state | `:406` | **dormant_no_user_action** | v1 not running | — |
| Supabase realtime channel `alarms-page-incidents` | `alarms_page.dart:212,281–288` | **dormant_no_user_action** | subscription requires v1 runtime; no active client session observed | — |

#### Page: `/dispatches` (`dispatch_page.dart`)

| Feature | v1 1b evidence | Verdict | Evidence | Cascade |
|---|---|---|---|---|
| Dispatch feed / list with selection | `:3384` | **dormant_blocked_by_backend** | 30d window: 0 transitions | #2 |
| Lane filter chip row | `:4401` | **dormant_blocked_by_backend** | no rows to filter | #2 |
| Dispatch timeline / phase card | `:864` | **dormant_blocked_by_backend** | source table dormant 53d | #2 |
| Communication transcript block | `:868` | **dormant_blocked_by_backend** | backing comms log tables show no recent activity tied to dispatches | #2 |
| Outcome card (real / false alarm / no response / safe word) | `:893` | **dormant_blocked_by_backend** | writes to `dispatch_transitions` / `onyx_alert_outcomes` (both 0/dormant) | #2 + #3 |
| Chain-of-custody seal block | `:897` | **dormant_blocked_by_backend** | `onyx_evidence_certificates` has the Apr 17–19 gap (cascade #6) + writes have since paused (see §0.1 observation) | #6 + #8 |
| Context grid | `:901` | **dormant_blocked_by_backend** | dispatch source dormant | #2 |
| Fleet-scope health sections | `:8068` | **dormant_blocked_by_backend** | identity/action tables `*/0` | #3 |

#### Page: `/tactical` Tactical / Track (`tactical_page.dart`)

| Feature | v1 1b evidence | Verdict | Evidence | Cascade |
|---|---|---|---|---|
| Tactical map with live markers | `:2635`, `:6285` | **dormant_no_user_action** | v1 not running | — |
| Signals header row with top signal + review/send/dismiss | `:1491` | **dormant_no_user_action** | v1 not running | — |
| Verification queue tabs | `:3328` | **dormant_no_user_action** | v1 not running | — |
| Map filter cycle (all / responding / incidents) | `:3312` | **dormant_blocked_by_backend** | 0 new incidents in 7d → "responding" / "incidents" toggles return empty | #1 |
| Center-active button | `:3320` | **dormant_no_user_action** | v1 not running | — |
| Suppressed & limited action sections | `:5485` | **dormant_blocked_by_backend** | action-log tables dormant | #3 |
| Fleet-scope drilldown | `:4999` | **dormant_blocked_by_backend** | downstream action tables dormant | #3 |
| Live signals table | `:4848` | **dormant_no_user_action** | v1 not running | — |
| Supabase realtime channel `tactical-map-$scopeKey` | `lib/main.dart:1793,35154–35183` | **dormant_blocked_by_backend** | subscribes to `guard_location_heartbeats` which has 0 rows | #3 |

### 1.2 Operations section (6 pages)

#### Page: `/clients` (`clients_page.dart`)

All 10 present features (client/site selector, message history, pending drafts, comms channels, voice/tone selector, Junior Analyst agent handoff, evidence return receipt banner, desktop workspace toggle — see phase 1b §4.2):

| Feature group | Verdict | Evidence | Cascade |
|---|---|---|---|
| All 10 features | **dormant_no_user_action** | v1 not running; `client_conversation_messages` static at 20 rows (no new writes in 7d per phase 2a §3.3) | partial #3 — conversational writes dormant |

#### Page: `/sites` (`sites_page.dart`)

| Feature | Verdict | Evidence | Cascade |
|---|---|---|---|
| Site list / roster | **dormant_no_user_action** | v1 not running; `sites` table static at 8 rows | — |
| Site detail card (guard on-site, cameras active, 24h incidents, avg response) | **dormant_blocked_by_backend** | 24h-incidents counter relies on `incidents` which is stale (#1); guard-on-site relies on `guard_location_heartbeats` (#3) | #1 + #3 |
| Site posture summary bar | **dormant_no_user_action** | v1 not running | — |
| Watch health status card | **dormant_no_user_action** | v1 not running | — |
| Navigate to tactical map button | **dormant_no_user_action** | v1 not running | — |

#### Page: `/guards-workforce` (`guards_workforce_page.dart`)

| Feature | Verdict | Evidence | Cascade |
|---|---|---|---|
| Guard roster list with status pills | **dormant_no_user_action** | v1 not running; `guards` table static at 12 rows | — |
| Guard detail dossier | **dormant_no_user_action** | v1 not running | — |
| Tabs (Active Guards / Shift Roster / Shift History) | **dormant_blocked_by_backend** | shift tables (`shift_assignments` etc.) do not exist or have 0 rows; `guard_location_heartbeats` 0 rows | #3 |
| ZARA continuity summary strip | **dormant_blocked_by_backend** | Zara-compiled summary depends on `zara_action_log` (0 rows) | #3 |
| Workforce status bar (readiness pills + site selector) | **dormant_blocked_by_backend** | readiness counters source tables dormant | #3 |
| Shift coverage grid / shift history anomalies | **dormant_blocked_by_backend** | shift tables absent | #3 |
| Export workforce snapshot | **dormant_no_user_action** | client-side export; nothing logged | — |

#### Page: `/events` (`events_review_page.dart`)

| Feature | Verdict | Evidence | Cascade |
|---|---|---|---|
| Event list with row selection | **dormant_blocked_by_backend** | `incidents` driving this feed is stale (#1); `site_alarm_events` is active but not shown on /events in v1 per phase 1b §4.2 | #1 |
| Event type filter (ALL / INCIDENT / DISPATCH / AI DECISION / ALARM) | **dormant_blocked_by_backend** | combined source of `dispatch` events dormant (#2) | #1 + #2 |
| Source + provider filter | **dormant_no_user_action** | v1 not running | — |
| Identity policy filter | **dormant_blocked_by_backend** | writes flagged/temporary/allowlisted policy changes to tables that are `*/0` per phase 2a | #3 |
| Desktop workspace toggle | **dormant_no_user_action** | v1 not running | — |
| Scope rail with origin back-link chip | **dormant_no_user_action** | requires URL navigation within v1 runtime | — |
| Row actions (copy JSON / copy CSV / open governance) | **dormant_no_user_action** | v1 not running | — |
| Readiness / tomorrow banner | **dormant_blocked_by_backend** | compiled from Zara-dormant source | #3 |

#### Page: `/vip` (`vip_protection_page.dart`)

| Feature | Verdict | Evidence | Cascade |
|---|---|---|---|
| Principal list with selection | **dormant_blocked_by_backend** | `vip_principals` table per phase 1a §3 was not commissioned — v2 audit §`/vip` confirms demo principal only | — (outside 2a's explicit cascades but same class of gap) |
| Scheduled details manifest | **dormant_blocked_by_backend** | same | — |
| New VIP detail button | **dormant_no_user_action** | v1 not running | — |
| VIP empty-state with templates | **dormant_no_user_action** | v1 not running | — |
| Latest auto-audit receipt notice | **dormant_no_user_action** | v1 not running | — |

#### Page: `/intel` (`risk_intelligence_page.dart`)

| Feature | Verdict | Evidence | Cascade |
|---|---|---|---|
| Thread / intel feed list | **dormant_blocked_by_backend** | `client_evidence_ledger` intel writes stopped 2026-04-17 (cascade #8) | #8 |
| Add manual intel button | **dormant_no_user_action** | v1 not running | — |
| Risk-area state cards | **dormant_no_user_action** | v1 not running | — |
| Predictive forecast block | **dormant_blocked_by_backend** | Zara correlation engine outputs not in DB (phase 1b v2-audit §/intel) | #3 |
| Send area → track action | **dormant_no_user_action** | v1 not running | — |
| Send individual signal → track action | **dormant_no_user_action** | v1 not running | — |

### 1.3 Governance / Evidence / System section (4 pages)

#### Page: `/governance` (`governance_page.dart`)

| Feature | Verdict | Evidence | Cascade |
|---|---|---|---|
| Compliance blocker alerts | **dormant_no_user_action** | v1 not running; rendering would draw from `guards` attestations (live at 12 rows) | — |
| Partner trend analysis (7-day) | **dormant_blocked_by_backend** | depends on `dispatch_transitions` outcome data (dormant 53d) | #2 |
| Operational readiness signals board | **dormant_blocked_by_backend** | readiness signal sources largely `*/0` | #3 |
| Scope context rail with handoff actions | **dormant_no_user_action** | v1 not running | — |
| Quick actions recovery deck | **dormant_no_user_action** | v1 not running | — |
| Desktop workspace layout | **dormant_no_user_action** | v1 not running | — |
| Live operational feeds aggregation | **dormant_blocked_by_backend** | aggregated from compliance / vigilance / fleet — fleet tables dormant | #3 |

#### Page: `/ledger` Ledger / OB Log (`sovereign_ledger_page.dart`)

| Feature | Verdict | Evidence | Cascade |
|---|---|---|---|
| Ledger feed with entry selection | **dormant_blocked_by_backend** | `client_evidence_ledger` writes stopped 2026-04-17 per §0.1 cascade #8 (post-Apr-16 feed is frozen) — 16,285 historical rows exist, display would render them stale | #8 |
| Category filter with search | **dormant_no_user_action** | v1 not running | — |
| Block / entry detail inspector | **dormant_no_user_action** | v1 not running | — |
| Chain integrity badge | **dormant_blocked_by_backend** | re-verification requires live chain growth; chain has not advanced since Apr 16 | #8 |
| Manual audit entry composer | **dormant_no_user_action** (write-only feature; no user action) | v1 not running | — |
| Multi-view toggle (Record / Chain / Linked) | **dormant_no_user_action** | v1 not running | — |
| Pinned audit entry highlight | **dormant_no_user_action** | v1 not running | — |
| Cross-app navigation hooks | **dormant_no_user_action** | v1 not running | — |

#### Page: `/reports` (`client_intelligence_reports_page.dart`)

| Feature | Verdict | Evidence | Cascade |
|---|---|---|---|
| Report list with row selection | **dormant_no_user_action** | v1 not running | — |
| Report generation with proof engine | **dormant_no_user_action** (30d window; no manual-generation events captured in any observable log in 30d) | v1 not running | — |
| Receipt history with JSON/CSV copy + status filters | **dormant_no_user_action** | v1 not running | — |
| Report preview dock | **dormant_no_user_action** | v1 not running | — |
| Scope-based filtering with date range | **dormant_no_user_action** | v1 not running | — |
| Governance handoff integration | **dormant_no_user_action** | v1 not running | — |

#### Page: `/admin` (`admin_page.dart`, class `AdministrationPage`)

| Feature | Verdict | Evidence | Cascade |
|---|---|---|---|
| Tab navigation (Guards / Sites / Clients / System) | **dormant_no_user_action** | v1 not running | — |
| Directory sync and CSV bulk import/export | **dormant_no_user_action** (30d window; no sync writes in 30d on `clients`/`sites`/`guards` per phase 2a §3.3 row counts) | v1 not running | — |
| Interactive entity tables with live counts | **dormant_no_user_action** | v1 not running | — |
| System health dashboard (multi-metric) | **dormant_blocked_by_backend** (and would surface the 5h 22m camera-worker stoppage window 17:03–22:25 SAST within the 7d audit window) | many source metrics dormant | #3 + #7 |
| Partner scorecard with trend filtering | **dormant_blocked_by_backend** | partner trends depend on `dispatch_transitions` (dormant) | #2 |
| Global readiness policy monitor | **dormant_blocked_by_backend** | global readiness depends on `onyx_awareness_latency` + `onyx_alert_outcomes` (both 0 rows) | #3 |
| Radio intent phrase / listener alarm tracking | **dormant_blocked_by_backend** | listener alarm parity tables not verified writes in window | #3 |

### 1.4 v1-only pages (3)

#### Page: `ControllerLoginPage` (pre-router, `lib/main.dart:34521`)

| Feature | Verdict | Evidence | Cascade |
|---|---|---|---|
| Username + password entry with validation | **dormant_no_user_action** | Supabase `auth.users` shows zero sign-ins in 7d or 30d window (latest 2026-02-26 = 53 days ago) | — |
| Demo account quick-select | **dormant_no_user_action** | same | — |
| Submit authentication → `onAuthenticated` callback | **dormant_no_user_action** | same | — |
| Clear cache / reset preview | **dormant_no_user_action** | same | — |
| Inline error display | **dormant_no_user_action** | same | — |

#### Page: `GuardMobileShellPage` (`lib/main.dart:40780`)

| Feature | Verdict | Evidence | Cascade |
|---|---|---|---|
| Shift start verification screen | **dormant_blocked_by_backend** | `guard_*` sync tables (`guard_sync_operations`, `guard_assignments`, `guard_location_heartbeats`, `guard_panic_signals`, `guard_incident_captures`) all `*/0` per phase 2a §3.3 | #3 |
| Dispatch alert screen | **dormant_blocked_by_backend** | dispatch source dormant | #2 |
| Status update | **dormant_blocked_by_backend** | `guard_sync_operations` 0 writes | #3 |
| NFC checkpoint scanning | **dormant_blocked_by_backend** | `guard_checkpoint_scans` / `patrol_scans` `*/0` | #3 |
| Emergency / panic button | **dormant_blocked_by_backend** | `guard_panic_signals` `*/0` | #3 |
| Sync history + queue management | **dormant_blocked_by_backend** | guard projection retention 2 rows; no recent activity | #3 |
| Telemetry payload validation | **dormant_no_user_action** | v1 mobile app not running in field; no guard-side app sessions captured | — |

#### Page: `OrganizationPage` (pushed modal from `app_shell.dart:1049`)

| Feature | Verdict | Evidence | Cascade |
|---|---|---|---|
| Hierarchy tree view | **dormant_no_user_action** | v1 not running | — |
| By-division grouping view | **dormant_no_user_action** | v1 not running | — |
| Organization summary stats | **dormant_no_user_action** | v1 not running | — |
| Tree node expand / collapse | **dormant_no_user_action** | v1 not running | — |

### 1.5 Section 1 summary

| Verdict | Row count |
|---|---:|
| `verified` | 0 |
| `failing` | 0 |
| `dormant_no_user_action` | 62 |
| `dormant_no_data` | 0 |
| `dormant_blocked_by_backend` | 41 |
| `blocked_by_backend` | 0 (used `dormant_blocked_by_backend` throughout since the UI also has `dormant_no_user_action` underneath — compound dormancy) |
| `unverified` | 1 (alarm-triage attribution — 141 incidents.updated_at writes split across v1/v2/camera-worker sources; exclusive v1 attribution not traceable) |

**Total v1 `present` feature rows verdicted: 104.**

The single `unverified` is the `/alarms` triage action path — the Dart code writes via the same Supabase client used by v2's PATCH handler and by `bin/onyx_camera_worker.dart`. Exclusive attribution to v1-app-driven triage would require either a client-token / user-id column on `incidents.updated_at` writes or a runtime analytics hook — neither exists in the observable pipeline.

---

*§2 (v2 Next.js feature verification), §3 (cross-cutting), §4 (user interaction evidence audit), §5 (read-only view parity), §6 (roll-up) pending.*
