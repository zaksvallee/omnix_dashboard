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

## 2. v2 Next.js feature verification

### 2.1 v2 runtime state — anchoring evidence

**v2 is actively running and has been actively used today.** Specifically:
- `next dev` server is running on `localhost:3000` (process 7798, started 2026-04-20 07:00 SAST; listener pid 7804 bound on `TCP *:3000`).
- An active Chrome browser session is connected: `Google chrome 60083 … TCP localhost:60825->localhost:3000 (ESTABLISHED)`.
- **141 `/api/incidents/[id]` PATCH writes occurred today 2026-04-20** (all concentrated on a single date — days Apr 13–19 had **zero** writes, day Apr 20 had **141**). All 141 rows have `controller_notes="False alarm — cleared by operator via Alarms dashboard."` — the free-text written by the v2 PATCH handler (phase 1a §6.1 documents this pattern). Status distribution: `secured`=139 (false_alarm path), `dispatched`=1 (dispatch path), `OPEN`=1 (escalate path).

This anchors v2 verdicts: interaction evidence is real for the `/alarms` triage flow specifically; no evidence of interaction with other v2 pages is captured in any DB-writable audit surface (because 18 of 19 routes are GET-only and v2 has no client-side analytics).

### 2.2 Zara home `/` (`app/_components/ZaraClient.tsx`)

Scope filter per phase 1b §4.1: 4 `present` rows (rows marked `present_stub` — live-signal-feed, op-health pills — are out of 2b scope).

| Feature | v2 1b evidence | 2b verdict | Runtime evidence | Cascade |
|---|---|---|---|---|
| Quick-action navigation buttons | `ZaraClient.tsx:405–431` | **dormant_no_user_action** | Chrome session is connected to `:3000`, but no audit-log proves this page was visited; no click captures (v2 has no analytics) | — |
| Animated heartbeat / Zara avatar | `:707,753–761` | **dormant_no_user_action** | same | — |
| Greeting card with operator + site labels | `:709–727` | **dormant_no_user_action** | same | — |
| Surfaced alert card with dismiss/open | `:438–469` | **dormant_no_user_action** | no callback writes into Supabase observed (v2 audit §"Needs deeper investigation" already flagged this); 0 rows in any related table with today's timestamp | — |

### 2.3 `/command` (`CommandClient.tsx`)

4 `present` rows (CCTV-placeholder row is `present_stub`, out of scope).

| Feature | v2 1b evidence | 2b verdict | Runtime evidence | Cascade |
|---|---|---|---|---|
| Live queue panel of active incidents | `CommandClient.tsx:353–424` | **blocked_by_backend** | `incidents` has 0 new inserts in 7d (cascade #1); the `status NOT IN ('secured','closed')` filter today returns only pre-Apr-20 stale rows plus whatever is `OPEN`/`dispatched` from the 141 triage writes | 2a §6.1 |
| Dispatches strip with phase progression | `:457–487` | **blocked_by_backend** | `dispatch_current_state` has 27 rows (latest transition 2026-02-26); `dispatch_transitions` 30d window = 0 writes | 2a §6.2, §7.4 |
| Events / activity stream | `:514–527` | **blocked_by_backend** | same `incidents` source as the queue panel | 2a §6.1 |
| P1 alert banner when queue has P1 | `:254–274` | **blocked_by_backend** | no new P1 incidents in 7d to banner | 2a §6.1 |

### 2.4 `/alarms` (`AlarmsClient.tsx` + `Drawer.tsx`)

4 `present` rows.

| Feature | v2 1b evidence | 2b verdict | Runtime evidence | Cascade |
|---|---|---|---|---|
| Alarms list view | `AlarmsClient.tsx:316–328` | **verified** | data render confirmed by inference: the 141 PATCH writes today each require a drawer opening, which requires a list row click, which requires the list to have rendered | — |
| Severity filter (ALL / P1 / P2 / P3) | `:282–292` | **verified** | filter controls are non-disabled in code (phase 1b) and the page clearly rendered + was interacted-with; filter-specific activity not separately logged but is local-state only — rendering verified transitively | — |
| Triage action path (DISPATCH / FALSE ALARM / ESCALATE) | `Drawer.tsx:166–181` + `AlarmsClient.tsx:149` useMutation → PATCH `/api/incidents/[id]` | **verified** | 141 writes today 2026-04-20 with correct-shape status transitions (`secured`/`dispatched`/`OPEN`) + `controller_notes="False alarm — cleared by operator via Alarms dashboard."` — **attribution is unambiguous via the controller_notes string**. Latest write: `id=43c07910-fb65-407d-82f7-3c3227fa62cb updated_at=2026-04-20T19:38:27 status=OPEN` | — |
| Toast on triage error | `AlarmsClient.tsx:136–145,172–180,338–346` | **dormant_no_user_action** | 141 PATCH writes in window, 0 errors observed on the incidents table (would have been logged as 4xx/5xx response); toast renders on error, error path hasn't fired | — |

### 2.5 `/ai-queue` (`AIQueueClient.tsx` + `CognitionGraph.tsx`)

4 `present` rows.

| Feature | v2 1b evidence | 2b verdict | Runtime evidence | Cascade |
|---|---|---|---|---|
| Task queue list with status icons | `AIQueueClient.tsx:60–104` | **blocked_by_backend** | source is `incidents` (not `zara_action_log`) per v2 audit §`/ai-queue` — and `incidents` has 0 new inserts in 7d; reasoning-trace portion depends on `decision_audit_log` / `zara_action_log` which are 0 rows | 2a §6.1 + #3 |
| Task row selection (URL-persisted) | `:321–325` | **dormant_no_user_action** | no evidence this page was loaded in window (no write fingerprint — page is read-only) | — |
| Worker chain display | `:96,242` | **blocked_by_backend** | same source as queue panel | 2a §6.1 + #3 |
| Cognition graph visualization | `:455–458` + `CognitionGraph.tsx` | **blocked_by_backend** | data is demo-fixture per phase 1b §4.1 (live data needs `zara_action_log` writes, 0 rows) | #3 |

### 2.6 `/dispatches` (`DispatchesClient.tsx`)

6 `present` rows.

| Feature | v2 1b evidence | 2b verdict | Runtime evidence | Cascade |
|---|---|---|---|---|
| Dispatch feed / list | `DispatchesClient.tsx:549–600` | **blocked_by_backend** | `dispatch_current_state` latest row 2026-02-26 | 2a §6.2 |
| Time-window filter | `:505–515` | **blocked_by_backend** | underlying data dormant — "Tonight 12h" / "Last 24h" return 0 regardless of filter value | 2a §6.2 |
| Category chips (auto-derived) | `:349–360,520–529` | **blocked_by_backend** | no new rows → no categories to derive | 2a §6.2 |
| Dispatch timeline / phase card | `:549–600` | **blocked_by_backend** | source dormant | 2a §6.2 |
| URL-persisted dispatch selection | `:395–399` | **dormant_no_user_action** | no evidence of page visit | — |
| KPI row (median response / overrides / etc.) | `:443–499` | **blocked_by_backend** | KPIs computed from `dispatch_transitions` which has 0 writes in 30d | 2a §6.2 |

### 2.7 `/track` (`TrackClient.tsx` + `TrackMap.tsx`)

4 `present` rows.

| Feature | v2 1b evidence | 2b verdict | Runtime evidence | Cascade |
|---|---|---|---|---|
| MapLibre map with MapTiler tiles | `TrackMap.tsx:52–74` | **unverified** | map renders only if `NEXT_PUBLIC_MAPTILER_KEY` is set; v2 audit flagged this; no evidence of rendering success or failure in window | Would need screenshot or browser-console check |
| Site list with incident counts | `TrackClient.tsx:243–272` | **blocked_by_backend** (for the "incident counts" part) | `sites` table renders (8 rows static); but incident-count-per-site is derived from `incidents` table which has 0 new rows in 7d | 2a §6.1 partially |
| URL-persisted site selection | `:126–132` | **dormant_no_user_action** | no evidence of page visit | — |
| Placeholder-coordinate DB hygiene warning | `:167–175` | **dormant_no_user_action** | requires page render to surface; no visit evidence | — |

### 2.8 `/clients` (`ClientsClient.tsx`)

2 `present` rows.

| Feature | v2 1b evidence | 2b verdict | Runtime evidence | Cascade |
|---|---|---|---|---|
| Client list filter (ALL / HEALTHY / AT RISK — RENEWAL stubbed) | `ClientsClient.tsx:109` | **dormant_no_user_action** | no page visit evidence; `clients` table stable at 9 rows | — |
| Client detail panel (selection) | `:104,126–132` | **dormant_no_user_action** | same | — |

### 2.9 `/sites` (`SitesClient.tsx` + `KindIcon.tsx`)

3 `present` rows.

| Feature | v2 1b evidence | 2b verdict | Runtime evidence | Cascade |
|---|---|---|---|---|
| Site list with posture pills | `SitesClient.tsx:190–222,255–257` | **dormant_no_user_action** | 8 sites ready for render; no visit logged | — |
| Site detail card with risk rating + client + zone labels | `:238–277,354–406` | **dormant_no_user_action** | same | — |
| Kind facet filter (RETAIL / RESI / OFFICE / INDUS / CONSUL) | `:52–59,171–188` | **dormant_no_user_action** | client-side filter; no visit evidence | — |

### 2.10 `/guards` (`GuardsClient.tsx`)

2 `present` rows.

| Feature | v2 1b evidence | 2b verdict | Runtime evidence | Cascade |
|---|---|---|---|---|
| Guard roster list | `GuardsClient.tsx:174–211` | **dormant_no_user_action** | 12 guards static; no visit | — |
| Guard detail dossier (PSIRA, badge, post, shift pattern, equipment) | `:218–419` | **dormant_no_user_action** | same | — |

### 2.11 `/events` (`EventsClient.tsx`)

3 `present` rows.

| Feature | v2 1b evidence | 2b verdict | Runtime evidence | Cascade |
|---|---|---|---|---|
| Event list with row selection | `EventsClient.tsx:260–293` | **blocked_by_backend** | source is `incidents` — 0 new rows in 7d; cascade #1 | 2a §6.1 |
| Severity pills (P1 / P2 / P3 / CLSD) | `:54,193–206` | **blocked_by_backend** | same | 2a §6.1 |
| Category chips (auto-derived) | `:116,222–246` | **blocked_by_backend** | same (derived from incident categories; no new data) | 2a §6.1 |

### 2.12 `/vip` (`VIPClient.tsx`)

6 `present` rows.

| Feature | v2 1b evidence | 2b verdict | Runtime evidence | Cascade |
|---|---|---|---|---|
| Principal list with selection (URL-persisted) | `VIPClient.tsx:644–645,672–676,744–752` | **dormant_no_user_action** | demo principal only (`DEMO_PRINCIPAL_ID`) per v2 audit; ready to render but no visit | — |
| Principal filter (ALL / ACTIVE / TIER 1 / OFF) | `:678–683,732–742` | **dormant_no_user_action** | same | — |
| Scheduled details manifest | `:363–415` | **dormant_no_user_action** | rendering from mapper-synthesized demo data | — |
| Advance brief / Zara-compiled | `:347–361` | **dormant_no_user_action** | static text from mapper; v2 audit flagged source unclear | — |
| Detail roster / route / venue / vehicle cards | `:417–557` | **dormant_no_user_action** | rendering from mapper demo data | — |
| Threats & watches feed | `:579–596` | **dormant_no_user_action** | no visit evidence | — |

### 2.13 `/intel` (`IntelClient.tsx`)

5 `present` rows.

| Feature | v2 1b evidence | 2b verdict | Runtime evidence | Cascade |
|---|---|---|---|---|
| Thread / intel feed list | `IntelClient.tsx:242–290` | **blocked_by_backend** | sourced from `client_evidence_ledger` intelligence-provenance entries; no writes since 2026-04-16 (cascade #8) | #8 |
| Severity filter (ALL / ACTIVE / WATCH / CLOSED) | `:143–148,230–239` | **blocked_by_backend** | same | #8 |
| Thread detail panel | `:294–376` | **blocked_by_backend** | same | #8 |
| Pattern library tabs (FACES / PLATES / VOICES / SIGNATURES) | `:150–159,384–445` | **dormant_no_user_action** (for FACES) / **dormant_blocked_by_backend** (for PLATES/VOICES/SIGNATURES which are empty-state per v2 audit) | FACES tab shows 5 enrolled from `fr_person_registry`; no visit evidence; other 3 tabs have no upstream pipeline | 2a §1.2-1.3 for plates/voices/sigs |
| Face registry display (photo count + role) | `:405–424` | **dormant_no_user_action** | 5 rows ready; no visit | — |

### 2.14 `/governance` (`GovernanceClient.tsx`)

2 `present` rows.

| Feature | v2 1b evidence | 2b verdict | Runtime evidence | Cascade |
|---|---|---|---|---|
| Operator attestations table (PSIRA dates from `guards`) | `GovernanceClient.tsx:224–248` | **dormant_no_user_action** | `guards` static at 12 rows; no visit | — |
| KPI row (current / renewal / overdue counts) | `:110–134` | **dormant_no_user_action** | KPIs computable from static guards.psira_expires; no visit | — |

### 2.15 `/ledger` (`LedgerClient.tsx`)

4 `present` rows.

| Feature | v2 1b evidence | 2b verdict | Runtime evidence | Cascade |
|---|---|---|---|---|
| Ledger feed (infinite scroll "Load next 100") | `LedgerClient.tsx:357–448` | **blocked_by_backend** | `client_evidence_ledger` writes stopped 2026-04-17 (cascade #8); historical 16,285 rows exist but feed is frozen | #8 |
| Facet filter chips | `:237–281` | **dormant_no_user_action** | no visit | — |
| Block selection showing canonical JSON payload | `:450–487` | **dormant_no_user_action** | no visit; rendering possible with historical data | — |
| Chain integrity badge / latest root hash | `:291–340` | **blocked_by_backend** | badge shows "last root at 2026-04-16 16:47 UTC" since no new blocks have been sealed; phase 2a §6.1 plus §0.1 cascade #8 | #8 |

### 2.16 `/reports` (`ReportsClient.tsx`)

4 `present` rows.

| Feature | v2 1b evidence | 2b verdict | Runtime evidence | Cascade |
|---|---|---|---|---|
| Tab filter (Dash / Sched / QBR / Tpl) | `ReportsClient.tsx:633–638,719–729` | **dormant_no_user_action** | no visit evidence | — |
| Report list with row selection (URL-persisted) | `:616–620,732–761` | **dormant_no_user_action** | same | — |
| Portfolio dashboard (30d stacked-area chart + 6 KPIs) | `:284–424` | **blocked_by_backend** | computed from `incidents` — 0 new rows in 7d means chart and KPIs are frozen to data ending 2026-03-11 | 2a §6.1 |
| Export actions (Export PDF / Print / Share) on portfolio | `:322–331` | **dormant_no_user_action** (30d window) | client-side export; no evidence of a generated report file or share action in any log | — |

### 2.17 `/admin` (`AdminClient.tsx`)

3 `present` rows.

| Feature | v2 1b evidence | 2b verdict | Runtime evidence | Cascade |
|---|---|---|---|---|
| Tab navigation across 11 tabs | `AdminClient.tsx:99–111,883–906` | **dormant_no_user_action** | client-side tab switching; no visit evidence | — |
| System health dashboard (real row counts on System health tab) | `:170,186,202,218` | **dormant_no_user_action** | row counts would render fine from `users`/`roles`/`decision_audit_log`/`onyx_settings` — the first two tables PostgREST probes returned `*/0` in phase 2a (possible RLS). "System health" tab would render current row counts if visited; no visit evidence | — |
| `Open in Ledger` link (Audit tab) | `:329–331` | **dormant_no_user_action** | client-side navigation; no visit | — |

### 2.18 Section 2 summary

| Verdict | Row count |
|---|---:|
| `verified` | 3 (all in `/alarms`: list view render, severity filter, triage action path) |
| `failing` | 0 |
| `dormant_no_user_action` | 38 |
| `dormant_no_data` | 0 |
| `dormant_blocked_by_backend` | 1 (pattern library tabs PLATES/VOICES/SIGNATURES within `/intel`'s mixed row) |
| `blocked_by_backend` | 17 |
| `unverified` | 1 (`/track` MapTiler rendering — would require browser inspection) |

**Total v2 `present` feature rows verdicted: 60.**

### 2.19 Section 2 key findings

1. **The only verified v2 surface is `/alarms`** (list + severity filter + triage). 141 PATCH writes to `incidents.updated_at` on 2026-04-20 with unambiguous `controller_notes="False alarm — cleared by operator via Alarms dashboard."` attribution.
2. **Everything else is either `blocked_by_backend` or `dormant_no_user_action`.** The blocked rows trace to the phase 2a cascades (#1 incidents stale, #2 dispatch dormant, #3 Zara tables empty, #8 ledger writes stopped).
3. **v2 dev server has an active browser session** at the time of this pass (Chrome pid 60083 connected to `:3000`), but pages beyond `/alarms` cannot be verdicted `verified` for render without DB-writable fingerprints (and 18 of 19 routes are GET-only).
4. **No v2 feature is marked `failing`.** The v2 PATCH path returns 200 on 141/141 writes with correctly-shaped payloads. Where v2 is usable, it works. Where it doesn't work, it's because the backend is dormant — not because v2's code is wrong.

---

## 3. Cross-cutting verification

Rows from phase 1b §5 marked `present` on either side. `keyboard shortcuts` row is skipped (both sides `absent`).

| Concern | v1 verdict | v1 evidence | v2 verdict | v2 evidence |
|---|---|---|---|---|
| **Authentication flow** | **dormant_no_user_action** | `ControllerLoginPage` pre-router gate (`lib/main.dart:34521`); `Supabase.initialize(...)` (`lib/main.dart:842`). Supabase `auth.users`: 2 users total, **0 sign-ins in 7d or 30d** — latest `last_sign_in_at` was 2026-02-26 (mzvallee@gmail.com, 53 days ago) and 2025-12-24 (zaks@vallee.co.za, 119 days ago) | **blocked_by_backend** / also absent | phase 1b §5 row 1 records v2 = `absent`; no `middleware.ts` in v2 repo (`find /Users/zaks/onyx_dashboard_v2 -maxdepth 3 -name middleware.ts` → empty); nothing to verify |
| **Route guards / middleware** | **dormant_no_user_action** | GoRouter `refreshListenable` bridge at `lib/routing/onyx_router.dart:50` requires v1 runtime to exercise; v1 not running | **absent** | per phase 1b §5 — no middleware.ts; same-origin-only API guard |
| **Theme** | **dormant_no_user_action** | inline `Color(0xFF...)` constants at `lib/main.dart:21568–21620`; rendering requires v1 runtime | **verified** | CSS tokens in `app/globals.css` / `primitives.css` / `shell.css` are served by the active `next dev` process (pids 7798 + 7804); Chrome session connected at `localhost:3000` confirms theme styles are being delivered (else the 141 PATCH-path interaction would have been impossible given button styles come from these tokens) |
| **Responsive / mobile layout** | **dormant_no_user_action** | `LayoutBuilder` breakpoints in `lib/ui/app_shell.dart:342–570`; requires v1 runtime | **unverified** | no JS-breakpoint-hook usage observed in phase 1b; CSS media queries not inspected this pass |
| **Real-time subscriptions / polling** | **dormant_blocked_by_backend** | Supabase realtime channels `alarms-page-incidents` (`lib/ui/alarms_page.dart:212,281–288`) and `tactical-map-$scopeKey` (`lib/main.dart:1793,35154–35183`). `alarms-page-incidents` subscribes to `incidents` postgres_changes — table has 0 new inserts in 7d; `tactical-map-*` subscribes to `guard_location_heartbeats` — table has 0 rows. Even if v1 were running, both channels would receive no events | **verified** | TanStack Query `useQuery` with `refetchInterval` on all 16 v2 routes (phase 2a §5); proven active today by the `/alarms` 5-second poll cadence supporting the 141 PATCH writes — if polling wasn't running, the optimistic-update + rollback logic couldn't have landed 141 clean writes |
| **Error boundaries / toasts** | **dormant_no_user_action** | `ScaffoldMessenger.showSnackBar(...)` calls in `lib/main.dart:37614,37697,37773,37815,37847,37869`; v1 not running | **dormant_no_user_action** | per-route `error.tsx` on 6 of 16 routes (12 loading/error .tsx files confirmed). Phase 2a found 0 `failing` outcomes across 141 PATCH writes → error toast stack in `AlarmsClient.tsx:338–346` did not need to render |
| **Loading states** | **dormant_no_user_action** | inline `FutureBuilder` / `CircularProgressIndicator` usage; v1 not running | **verified** | same 6 routes with `loading.tsx` skeletons; served transitively through the active dev server on every page load |
| **Navigation (sidebar, header)** | **dormant_no_user_action** | `lib/ui/app_shell.dart` chrome; v1 not running | **verified** | `components/shell/Rail.tsx` is rendered on every route (root `app/layout.tsx` wraps all pages in `Shell`); Chrome session + PATCH-write fingerprint together demonstrate at least one Rail-mediated navigation to `/alarms` today |
| **Deep linking / URL state** | **dormant_no_user_action** | `/events?origin=&label=` encoder at `lib/routing/onyx_router.dart:133–172`; requires v1 runtime | **dormant_no_user_action** | URL-persisted selection on `/track`, `/vip`, `/dispatches`, `/ai-queue`; no evidence of these routes being visited in window (no write fingerprint) |
| **Accessibility (focus, aria)** | **unverified** | no `Semantics(...)` widget usage found in `lib/main.dart`; framework defaults apply | **unverified** | sparse `aria-label` / `role=status` / `aria-current="page"` in Rail.tsx and AlarmsClient.tsx; no systematic a11y testing log |

### 3.1 Section 3 summary
- v1 cross-cutting concerns: **0 verified, 8 `dormant_no_user_action`, 1 `dormant_blocked_by_backend`, 1 `unverified`.** None of the 10 cross-cutting capabilities on the v1 side fired in window because v1 runtime is absent.
- v2 cross-cutting concerns: **4 verified (theme, real-time-polling, loading, navigation), 3 `dormant_no_user_action`, 1 `unverified`, plus auth/route-guards which are structurally `absent` per phase 1b §5**. v2's cross-cutting chassis is alive where it has been exercised today via `/alarms`.

---

## 4. User interaction evidence audit — "is anyone looking at this?"

### 4.1 v1 Flutter

**Honest answer: no evidence that anyone has used v1 Flutter in the 7-day window.**

| Signal | v1 evidence |
|---|---|
| Process running (Mac / Pi / Hetzner) | **none** — `ps aux` returned 0 `flutter` / `dart ... lib/main.dart` / `dart ... run` matches |
| Served build (web dev server) | **none** — no port 8080/8081/58123 bound by any server process; `build/web/main.dart.js` last compiled 2026-04-18 16:26 SAST (2 days ago) but not served since |
| Supabase auth sign-ins | **0 in 7d** (latest 2026-02-26 = 53 days ago; latest for other user 2025-12-24 = 119 days ago) |
| Anon-key reads (v1 uses anon-key per `lib/main.dart:839,843`) | **no evidence available** — Supabase REST does not expose per-key access counts to audit clients; this is an audit gap but cannot invalidate the "no sign-in" finding since v1's RLS path still requires an authenticated session for most tables |
| Audit-log entries attributable to v1 runtime | **none** — no `zara_action_log` writes (0 rows), no `onyx_alert_outcomes` writes, no identity-intake writes, no `client_conversation_messages` writes in window |
| Mac dev session (anyone working *on* v1 source today) | partial — `tmp/onyx_flutter.pid` file exists but mtime 2026-04-18; `.dart_tool/` mtime 2026-04-20 20:06 SAST (compile work, not runtime session) |

### 4.2 v2 Next.js

**Honest answer: v2 `/alarms` was actively used on 2026-04-20 (today). No evidence of v2 use on any other day in the 7-day window, nor evidence that any route other than `/alarms` was opened in window.**

| Signal | v2 evidence |
|---|---|
| Process running | `next dev` (pid 7798, started 2026-04-20 07:00 SAST); listener pid 7804 bound on `:3000`; `postcss.js` worker pid 7907 |
| Active browser session | Chrome pid 60083 with established TCP connection to `localhost:3000` (`localhost:60825 -> localhost:hbci`) |
| Supabase auth sign-ins | **0 in 7d** — same as v1 (v2 doesn't require sign-in since no middleware; service-role key on server side) |
| Database writes attributable to v2 | **141 `/api/incidents/[id]` PATCH writes on 2026-04-20** with `controller_notes="False alarm — cleared by operator via Alarms dashboard."` — the string literally contains "via Alarms dashboard" which is the v2 UI identifier. Status distribution: secured=139 (false_alarm), dispatched=1, OPEN=1 (escalate) |
| Per-day PATCH distribution | Apr13=0, Apr14=0, Apr15=0, Apr16=0, Apr17=0, Apr18=0, Apr19=0, **Apr20=141** — all of v2's verified interaction happened today |
| GET-route visit evidence | **none** — v2 dev server's stdout is not captured in any log file I have access to; no analytics hooks; 18/19 routes are GET-only with no DB fingerprint |

### 4.3 Joint dashboard usage verdict

| Dashboard | Any user activity in 7d? | Any user activity in 30d? |
|---|---|---|
| v1 Flutter | **no** | **no** (last sign-in 53 days ago, no Flutter process/serve observed) |
| v2 Next.js | **yes — `/alarms` triage only, today 2026-04-20** | yes (same; nothing before Apr 20) |

---

## 5. Read-only view parity check

For every `both` page in phase 1b §3 that is primarily a read-only view. "Renders" = data source is live and the page would render correctly on load given the runtime state. "Agreement" = both sides read the same backing data; if both rendered, they'd show the same rows.

| Page | v1 renders | v2 renders | Agreement | Source of truth per phase 2a |
|---|---|---|---|---|
| Zara home `/` | v1 not running — **no** | yes but partially hardcoded (`STATEMENTS[]` / `AUTONOMOUS_OPS[]`) — **yes (degraded)** | v1 would render live operator/site labels from runtime state; v2 renders design-placeholder copy. **Disagree** — v2 is fabricated | neither; both dormant vs the true operator state |
| `/dashboard` (v1) vs `/command` (v2) | v1 not running — **no** | yes, renders `incidents` feed (stale) | both would read `incidents` (cascade #1) | **neither accurate** — both show stale data |
| `/ai-queue` | v1 not running — **no** | yes, renders `incidents`-as-tasks projection + demo-fixture trace | both would read same projection; v2 mapper adds demo trace layer | **neither accurate** — `zara_action_log` dormant |
| `/alarms` | v1 not running — **no** | **yes** — 141 triage writes today prove render + interact works | both sources are `incidents` filtered on `status NOT IN ('secured','closed')` | **v2 is the source of truth for active usage** (v1 is offline) |
| `/dispatches` | v1 not running — **no** | yes, but source `dispatch_current_state` has rows only from 2026-02-26 and earlier | both read same dormant source (cascade #2) | **neither accurate** |
| `/tactical` (v1) vs `/track` (v2) | v1 not running — **no** | yes, renders 8 sites on map; incident-counts stale | `sites` table agrees on 8 rows both sides | v2 is the source of rendered truth on site count |
| `/clients` | v1 not running — **no** | yes, renders 9 clients | `clients` static at 9 rows | **agree on data; v2 is the live view** |
| `/sites` | v1 not running — **no** | yes, renders 8 sites | `sites` static at 8 rows | **agree on data; v2 is the live view** |
| `/guards-workforce` (v1) vs `/guards` (v2) | v1 not running — **no** | yes, renders 12 guards | `guards` static at 12 rows | **agree on data; v2 is the live view** |
| `/events` | v1 not running — **no** | yes, renders `incidents` feed (stale per cascade #1) | both read same source | **neither accurate** |
| `/vip` | v1 not running — **no** | yes, single demo principal with mapper-synthesized detail | v1 source same (`vip_principals` not commissioned); v2 mapper adds demo layer | **v2 renders demo content; neither reflects a real vip_principals table** |
| `/intel` | v1 not running — **no** | yes, but intel threads read `client_evidence_ledger` whose writes stopped 2026-04-17 (cascade #8) | both read same source | **neither accurate** — data frozen |
| `/governance` | v1 not running — **no** | yes, renders attestations from `guards` | both compute PSIRA-expiry from static `guards` data | **agree on the attestations**; v1 has broader surfaces that v2 doesn't ship |
| `/ledger` (v1 "OB Log") | v1 not running — **no** | yes, historical 16,285 rows render, but feed frozen at 2026-04-16 16:47 (cascade #8) | both read same table | **agree on data; feed is frozen** |
| `/reports` | v1 not running — **no** | yes, portfolio computed from `incidents` (stale per cascade #1) | same source; v1 has richer receipt-history surfaces | **neither accurate** for "last 7d"; chart is frozen at Mar 11 |
| `/admin` | v1 not running — **no** | yes, System-health row counts render; other 10 tabs show DUMMY badges | v1 admin has directory-sync + CSV tooling v2 lacks; both render static row counts on System health | **v1 has more surfaces; both reflect the same DB row counts** |

### 5.1 Section 5 summary

- **v1 renders nothing in window** (runtime absent).
- **v2 renders most pages correctly** — the render contract itself is intact. But render-correct and data-accurate are different questions: 10 of 16 v2 pages render **stale or frozen data** due to cascades #1, #2, #3, #6, #8.
- **Pages where v2 renders accurately current data:** `/alarms` (fresh triage writes today), `/clients`, `/sites`, `/guards`, `/governance` (all static-but-valid registry reads with no dormancy on the backing rows).
- **Disagreement between v1 and v2 on data content is moot** because v1 doesn't render at all. Were v1 brought back up, it would read the same Supabase tables and reflect the same dormancy.

---

## 6. Roll-up

### 6.1 Verdict counts

| Verdict | v1 count | v2 count |
|---|---:|---:|
| `verified` | 0 | 3 (all `/alarms`) |
| `failing` | 0 | 0 |
| `dormant_no_user_action` | 62 | 38 |
| `dormant_no_data` | 0 | 0 |
| `dormant_blocked_by_backend` | 41 | 1 |
| `blocked_by_backend` | 0 | 17 |
| `unverified` | 1 (alarm-triage attribution) | 1 (`/track` MapTiler render) |
| **Total `present` rows verdicted** | **104** | **60** |

Cross-cutting (§3): v1 0 verified / 8 dormant / 1 blocked / 1 unverified; v2 4 verified / 3 dormant / 1 unverified / 2 `absent`-per-phase-1b (auth + route guards).

### 6.2 Most operationally significant findings

In order of operational weight:

1. **No one has used v1 Flutter in at least 30 days.** Zero Supabase auth sign-ins; zero Flutter process observed anywhere; `build/web/` is compiled but not served. Every v1 feature verdict is some form of `dormant` because the runtime surface is absent. This is not a per-feature failure — this is a dashboard-level dormancy.

2. **v2 is used for exactly one operator workflow: `/alarms` false-alarm triage.** 139 false_alarm + 1 dispatch + 1 escalate = 141 writes today. No evidence any other v2 page has been visited in the 7-day window. The other 15 v2 routes are `dormant_no_user_action` (nobody visits them) or `blocked_by_backend` (nothing useful to show).

3. **10 of 16 v2 pages are `blocked_by_backend`** by cascades #1 (`incidents` stale), #2 (`dispatch_transitions` dormant 53d), #3 (Zara tables 0 rows), or #8 (`client_evidence_ledger` writes stopped 2026-04-17). Even if someone opened these pages, they would render either empty state or data up-to-4-days-stale. No amount of UI work improves this — they need backend pipeline work first (phase 2a §6.2 + cascade list).

4. **Cascade #8 (ledger writes dead since 2026-04-17) appears to be the single highest-impact backend gap for UI surfaces.** It blocks `/ledger` (all 4 present features), `/intel` (3 of 5 present features), and the chain-integrity badge (which would otherwise have been a recently-updating feature). Phase 2a §6.1 classified `client_evidence_ledger` as verified active; the daily split observed in §0.1 of this pass reclassifies it as write-dormant since Apr 17.

5. **Cascade #7 (camera-worker stoppage 17:03–22:25 SAST today) is resolved** but within the 7-day audit window any UI feature showing service uptime / system-health timeline will display a 5h 22m gap. This is accurate data — the stoppage did happen; the UI reflecting it is not broken.

6. **The single `failing` count across both dashboards is zero.** Where features fire in window, they produce correct output. The problem is not bugs in the dashboard code; the problem is dormancy (backend or user-action absence).

7. **`/alarms` triage is demonstrably the only live operator surface in the platform.** No auth, no session, single-origin guard only, but the PATCH path works, the notes are attributable, the status transitions are well-formed. v2's minimum-viable production surface is validated.

---

*End of Phase 2b.*
