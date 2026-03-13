# ONYX Guard Pilot Config Matrix

Last updated: 2026-03-05 (Africa/Johannesburg)

## 1. Flutter Runtime (`--dart-define`)

Create your local config from the committed template:

```bash
cp config/onyx.local.example.json config/onyx.local.json
```

Use a local file for web/dev runs:

```bash
flutter run -d chrome --dart-define-from-file=config/onyx.local.json
```

Wrapper script (recommended):

```bash
./scripts/run_onyx_chrome_local.sh
```

Require Supabase-backed mode (fail fast if keys are missing):

```bash
./scripts/run_onyx_chrome_local.sh --require-supabase
```

Pilot live-telemetry gate command:

```bash
./scripts/guard_pilot_readiness_check.sh --full-tests --enforce-live-telemetry
```

Pilot gate with explicit Supabase configuration enforcement:

```bash
./scripts/guard_pilot_readiness_check.sh \
  --enforce-live-telemetry \
  --require-supabase-config
```

Pilot evidence-enforced gate command (requires latest Android artifact report to be PASS):

```bash
./scripts/guard_pilot_readiness_check.sh --enforce-live-telemetry --require-live-validation-artifacts
```

Pilot evidence freshness override (default max report age is 24h):

```bash
./scripts/guard_pilot_readiness_check.sh \
  --enforce-live-telemetry \
  --require-live-validation-artifacts \
  --max-live-validation-report-age-hours 12
```

Pilot real-device-only evidence gate:

```bash
./scripts/guard_pilot_readiness_check.sh \
  --enforce-live-telemetry \
  --require-live-validation-artifacts \
  --require-direct-sdk-connector \
  --require-real-device-artifacts \
  --max-live-validation-report-age-hours 12
```

Minimum keys for Supabase-backed runs:

```json
{
  "SUPABASE_URL": "https://<project-ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<anon-key>"
}
```

CCTV pilot minimum keys:

```json
{
  "ONYX_CCTV_PROVIDER": "frigate",
  "ONYX_CCTV_EVENTS_URL": "https://<edge-host>/api/events",
  "ONYX_CCTV_LIVE_MONITORING": "true",
  "ONYX_CCTV_FR": "false",
  "ONYX_CCTV_LPR": "false",
  "ONYX_CCTV_EVIDENCE_QUEUE_DEPTH": "12",
  "ONYX_CCTV_STALE_FRAME_SECONDS": "1800",
  "ONYX_CCTV_FALSE_POSITIVE_RULES_JSON": "[]"
}
```

DVR minimum keys:

```json
{
  "ONYX_DVR_PROVIDER": "hikvision_dvr",
  "ONYX_DVR_EVENTS_URL": "https://<dvr-host>/ISAPI/Event/notification/alertStream",
  "ONYX_DVR_EVIDENCE_QUEUE_DEPTH": "12",
  "ONYX_DVR_STALE_FRAME_SECONDS": "1800"
}
```

Guard telemetry adapter keys:
- `ONYX_GUARD_TELEMETRY_NATIVE_SDK` (`true` or `false`)
- `ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER` (default `android_native_sdk_stub`)
- `ONYX_GUARD_TELEMETRY_REQUIRED_PROVIDER` (expected provider ID in live-ready gate; defaults to native provider value when unset)
- `ONYX_GUARD_TELEMETRY_NATIVE_STUB` (`true` or `false`)
- `ONYX_GUARD_TELEMETRY_ENFORCE_LIVE_READY` (`true` forces payload health to `at_risk` when provider is not `ready` or facade mode is not `live`)
- `ONYX_WEARABLE_TELEMETRY_URL` (HTTP fallback endpoint)
- `ONYX_DEVICE_HEALTH_URL` (HTTP fallback endpoint)
- `ONYX_GUARD_TELEMETRY_BEARER_TOKEN`
- `ONYX_CLIENT_APP_LOCALE` (`en`, `zu`, `af`; default `en`)
- `ONYX_CLIENT_PUSH_DELIVERY_PROVIDER` (`in_app` or `telegram`; default `in_app`)
- `ONYX_TELEGRAM_BRIDGE_ENABLED` (`true` or `false`; default `false`)
- `ONYX_TELEGRAM_BOT_TOKEN` (required when Telegram bridge is enabled)
- `ONYX_TELEGRAM_CHAT_ID` (required when Telegram bridge is enabled)
- `ONYX_TELEGRAM_MESSAGE_THREAD_ID` (optional forum topic thread ID)
- `ONYX_TELEGRAM_ADMIN_CONTROL_ENABLED` (`true` enables admin command polling via Telegram Bot API)
- `ONYX_TELEGRAM_ADMIN_CHAT_ID` (optional explicit admin chat ID; defaults to `ONYX_TELEGRAM_CHAT_ID`)
- `ONYX_TELEGRAM_ADMIN_THREAD_ID` (optional admin forum topic thread ID filter)
- `ONYX_TELEGRAM_ADMIN_POLL_INTERVAL_SECONDS` (poll interval for admin command fetch; default `8`, clamped `3..60`)
- `ONYX_TELEGRAM_ADMIN_EXECUTION_ENABLED` (`true` allows execution commands such as `/syncguards`, `/pollops`, `/notifytest`, `/bindchat`, `/linkchat`, `/unlinkchat`, `/unlinkall`, `/demoflow`, `/autodemo`, `/demoscript`, `/democlean`, `/demolaunch`, `/demoplay`, `/demoplaystop`, demo controls; default `true`)
- `ONYX_TELEGRAM_ADMIN_CRITICAL_PUSH_ENABLED` (`true` sends automatic critical state alerts to admin chat; default `true`)
- `ONYX_TELEGRAM_ADMIN_CRITICAL_REMINDER_SECONDS` (repeat active critical alerts after this interval; default `300`, clamped `60..3600`)
- `ONYX_TELEGRAM_ADMIN_ALLOWED_USER_IDS` (optional comma-separated Telegram user IDs allowed to run admin commands)
- `ONYX_TELEGRAM_AI_ASSISTANT_ENABLED` (`true` enables inbound Telegram AI assistant routing)
- `ONYX_TELEGRAM_AI_APPROVAL_REQUIRED` (`true` requires manual approval before client AI replies are sent)
- `ONYX_TELEGRAM_AI_OPENAI_API_KEY` (optional OpenAI API key for model-backed drafts; fallback templates are used when unset)
- `ONYX_TELEGRAM_AI_OPENAI_MODEL` (default `gpt-4.1-mini`)
- `ONYX_TELEGRAM_AI_OPENAI_ENDPOINT` (optional override for the OpenAI Responses API endpoint)

CCTV pilot keys:
- `ONYX_CCTV_PROVIDER` (default empty; use `frigate` for the pilot edge path)
- `ONYX_CCTV_EVENTS_URL` (Frigate event feed, typically `https://<edge-host>/api/events`)
- `ONYX_CCTV_BEARER_TOKEN` (optional bearer token for protected edge endpoints)
- `ONYX_CCTV_LIVE_MONITORING` (`true` enables CCTV live-monitoring capability labels)
- `ONYX_CCTV_FR` (`true` advertises facial-recognition capability labels when enabled upstream)
- `ONYX_CCTV_LPR` (`true` advertises license-plate recognition capability labels when enabled upstream)
- `ONYX_CCTV_EVIDENCE_QUEUE_DEPTH` (bounded queue size for snapshot/clip verification; default `12`)
- `ONYX_CCTV_STALE_FRAME_SECONDS` (camera stale threshold; default `1800`)
- `ONYX_CCTV_FALSE_POSITIVE_RULES_JSON` (JSON array of suppression rules keyed by `zone`, `object_label`, `start_hour_local`, `end_hour_local`, and optional `min_confidence_percent`)

DVR keys:
- `ONYX_DVR_PROVIDER` (default empty; currently `hikvision_dvr` or `generic_dvr`)
- `ONYX_DVR_EVENTS_URL` (private DVR event endpoint, for example Hikvision ISAPI alert stream)
- `ONYX_DVR_BEARER_TOKEN` (optional bearer token for protected DVR endpoints)
- `ONYX_DVR_EVIDENCE_QUEUE_DEPTH` (bounded queue size for DVR snapshot/clip verification; default `12`)
- `ONYX_DVR_STALE_FRAME_SECONDS` (DVR camera stale threshold; default `1800`)

Video provider selection:
- ONYX prefers `ONYX_CCTV_*` when both CCTV and DVR are configured.
- If CCTV is unconfigured and DVR is configured, ONYX uses the DVR bridge path for video ingest, `/bridges`, and `/pollops`.

DVR pilot commands:
- `./scripts/onyx_dvr_capture_pack_init.sh`
- `./scripts/onyx_dvr_field_validation.sh`
- `./scripts/onyx_dvr_pilot_readiness_check.sh --require-real-artifacts`
- readiness writes `readiness_report.json` and `readiness_report.md` into the DVR validation artifact dir
- readiness can also enforce `release_gate.json` and `release_trend_report.json` with `--require-release-gate-pass --require-release-trend-pass`
- when enforced, readiness now also rejects release-gate signoff paths that point outside the active DVR artifact dir
- when enforced, readiness now also rejects staged signoff JSON that points at a different validation bundle or release gate
- when enforced, readiness now also rejects staged signoff JSON whose nested release-trend reference or `release_trend_status` no longer matches the active DVR artifact chain
- when enforced, readiness now also rejects staged signoff JSON whose nested release-trend gate links no longer point at the active current gate and a real canonical previous gate
- `./scripts/onyx_dvr_pilot_gate.sh`
- `./scripts/onyx_dvr_field_gate.sh`
- `./scripts/onyx_dvr_signoff_generate.sh`
- signoff now writes both markdown and sibling JSON audit output in the target directory
- signoff now rejects `PASS` release artifacts that point at a different validation or release chain than the active bundle
- signoff now also rejects release gates that point at different signoff markdown or signoff JSON paths than the signoff being generated
- `./scripts/onyx_dvr_release_gate.sh`
- `./scripts/onyx_dvr_release_trend_check.sh`
- release posture now validates audited signoff JSON alignment, not just signoff file presence
- release posture and release trend now also reject signoff that records a different release-trend artifact, a mismatched `release_trend_status`, or a required-but-missing/non-passing release trend
- release posture and release trend now also reject signoff whose nested release trend points at the wrong current gate or a missing/non-canonical previous gate
- release trend now also fails if a current or previous release gate points signoff artifacts outside its own artifact dir
- readiness and release trend now also reject top-level `signoff_status` summaries that drift from the referenced signoff report
- release posture and release trend now also reject contradictory readiness JSON and readiness summary drift
- release posture and release trend now also reject top-level validation/readiness path swaps outside the staged artifact dir
- release posture now also rejects top-level signoff markdown/report path swaps outside the staged artifact dir
- release posture and release trend now also require canonical staged names for `validation_report.json` and `readiness_report.json`
- release posture, readiness, and release trend now also require canonical staged names for `dvr_pilot_signoff.md` and `dvr_pilot_signoff.json`
- readiness and signoff now also require canonical staged names for `release_gate.json` and `release_trend_report.json`
- release trend now also requires canonical staged input names for current and previous `release_gate.json`
- readiness and signoff now also reject release-trend artifacts whose `previous_release_gate_json` is not named `release_gate.json`
- readiness and signoff now also reject release-trend artifacts whose `previous_release_gate_json` is missing or points at a nonexistent file
- `onyx_dvr_field_gate.sh --signoff-out ...` now exports an extra signoff copy while keeping the canonical staged signoff files for release gating

CCTV pilot commands:
- `./scripts/onyx_cctv_capture_pack_init.sh`
- `./scripts/onyx_cctv_field_validation.sh`
- `./scripts/onyx_cctv_pilot_readiness_check.sh --require-real-artifacts`
- `./scripts/onyx_cctv_pilot_gate.sh`
- `./scripts/onyx_cctv_signoff_generate.sh`

Telegram admin commands (when admin control is enabled):
- `/status [full]`
- `/next`
- `/ops`
- `/incidents`
- `/incident`
- `/critical [short]`
- `/syncguards`
- `/pollops`
- `/history`
- `/adminconfig`
- `/exec`
- `/pushcritical`
- `/setpoll`
- `/setreminder`
- `/target`
- `/settarget [client_id site_id|default]`
- `/acl [status|list|me|add <id>|remove <id>|open|default]`
- `/notifytest [client|control] [client_id site_id]`
- `/bindchat <client_id site_id> [label]`
- `/linkchat [client_id site_id] [label]`
- `/unlinkchat [client_id site_id]`
- `/unlinkall [client_id site_id]`
- `/chatcheck [client_id site_id]`
- `/demoprep [client_id site_id]`
- `/demoflow [client_id site_id]`
- `/autodemo <client_id site_id> [label]`
- `/demoscript [client_id site_id]`
- `/democlean [client_id site_id]`
- `/demolaunch <client_id site_id> [label]`
- `/demoplay [client_id site_id [interval_seconds]]`
- `/demoplaystop`
- `/demoplaystatus`
- `/targets [client_id site_id]`
- `/demostart`
- `/demofull`
- `/demostop`
- `/demostatus`
- `/snoozecritical`
- `/unsnoozecritical`
- `/ackcritical`
- `/unackcritical`
- `/guards`
- `/bridges`
- `/brief`
- `/aiassist [on|off|status|default]`
- `/aiapproval [on|off|status|default]`
- `/aidrafts`
- `/aiapprove <update_id>`
- `/aireject <update_id>`
- `/aiconv [client_id site_id]`
- `/ask <question>`
- `/ping`
- `/help`
- `/whoami`

Telegram admin runtime behavior:
- Runtime admin controls (poll override, reminder override, ACL override, default target override, critical snooze/ack, admin command history) are persisted locally and restored on restart.
- Runtime AI controls (assistant on/off, client approval on/off, pending draft queue) are persisted locally and restored on restart.
- Long admin command responses are chunked automatically for Telegram delivery safety.
- Plain-language admin prompts (without `/`) now auto-route for common intents such as status, brief/summary, critical risks, next actions, whoami, help, and question-form prompts.
- Telegram admin replies attach a persistent quick-action keyboard (`Brief`, `Critical risks`, `Next 5`, `Status`, `Ack critical`, `Status full`) to reduce manual command typing.
- Core admin snapshots (`brief`, `status`, `critical`, `next`) use rich Telegram formatting (bold headings, bullet points, and posture emojis) for one-glance readability.
- Site onboarding in Admin now supports an optional dedicated site-level Telegram lane (`endpoint label`, `chat_id`, optional `thread_id`) that persists into messaging bridge records.
- Client/site onboarding plus manual chat-lane binding now run an immediate Telegram chatcheck probe after Telegram lane save and surface `PASS/FAIL` feedback.
- Admin Clients and Sites cards now show a `CHATCHECK` status badge (PASS/FAIL/SKIP) with tooltip detail from the latest verification run; status is re-hydrated from endpoint `last_delivery_status`/`last_error` on reload and restart.
- Inbound AI routing handles non-command messages from linked client Telegram lanes; high-risk keywords are escalated to admin and logged to ledger instead of auto-resolved.
- Admin System tab now includes a Telegram AI assistant panel with live draft queue and one-click `Approve` / `Reject` actions.
- Use `/adminconfig` after restart to confirm active runtime values.

Admin command bootstrap behavior:
- On app startup, ONYX performs a one-time Telegram update offset bootstrap to avoid replaying stale historical commands from backlog.
- `/status` now includes `Admin offset bootstrap` so you can verify bootstrap completion time.

Readiness behavior:
- `--enforce-live-telemetry` validates both native and required provider IDs.
- If required provider is unset, readiness defaults it to the native provider.
- If required provider differs from native provider, readiness emits a warning to flag intentional cross-provider routing.

Guard sync alert threshold keys:
- `ONYX_GUARD_FAILURE_ALERT_THRESHOLD`
- `ONYX_GUARD_QUEUE_ALERT_THRESHOLD`
- `ONYX_GUARD_STALE_SYNC_ALERT_MINUTES`
- `ONYX_GUARD_FAILED_OPS_WARN_THRESHOLD`
- `ONYX_GUARD_FAILED_OPS_CRITICAL_THRESHOLD`
- `ONYX_GUARD_OLDEST_FAILED_WARN_MINUTES`
- `ONYX_GUARD_OLDEST_FAILED_CRITICAL_MINUTES`
- `ONYX_GUARD_FAILED_RETRY_WARN_THRESHOLD`
- `ONYX_GUARD_FAILED_RETRY_CRITICAL_THRESHOLD`
- `ONYX_GUARD_RESUME_SYNC_EVENT_THROTTLE_SECONDS`

Live feed/news ingestion keys:
- `ONYX_LIVE_FEED_URL`
- `ONYX_LIVE_FEED_BEARER_TOKEN`
- `ONYX_LIVE_FEED_HEADERS_JSON`
- `ONYX_LIVE_FEED_POLL_INTERVAL_SECONDS`
- `ONYX_NEWSAPI_ORG_KEY`
- `ONYX_NEWSAPI_AI_KEY`
- `ONYX_NEWSDATA_IO_KEY`
- `ONYX_WORLDNEWSAPI_KEY`
- `ONYX_OPENWEATHER_KEY`
- `ONYX_NEWS_QUERY`
- `ONYX_COMMUNITY_FEED_JSON`
- `ONYX_SITE_LAT`
- `ONYX_SITE_LON`

Optional governance key:
- `ONYX_GUARD_OUTCOME_GOVERNANCE_JSON`

## 2. Android Native Telemetry Toggle (Gradle / Manifest)

Gradle properties used by Android facade:
- `ONYX_USE_LIVE_FSK_SDK` (`true` enables live facade)
- `ONYX_FSK_SDK_HEARTBEAT_ACTION` (broadcast action for SDK callback)
- `ONYX_FSK_SDK_PAYLOAD_ADAPTER` (`standard`, `legacy_ptt`, or `hikvision_guardlink`)
- `ONYX_FSK_SDK_CONNECTOR_CLASS` (optional fully-qualified Kotlin class implementing `FskVendorSdkConnector`)
- `ONYX_FSK_SDK_MANAGER_CLASS_CANDIDATES` (optional comma-separated FSK manager class candidates for reflective lookup)
- `ONYX_FSK_SDK_ARTIFACT` (optional path to FSK vendor SDK `.aar`/`.jar`)
- `ONYX_FSK_SDK_MAVEN_COORD` (optional Maven coordinate for FSK SDK, for example `com.vendor:fsk-sdk:1.2.3`)
- `ONYX_USE_LIVE_HIKVISION_SDK` (`true` enables live Hikvision facade)
- `ONYX_HIKVISION_SDK_HEARTBEAT_ACTION` (broadcast action for Hikvision SDK callback)
- `ONYX_HIKVISION_SDK_PAYLOAD_ADAPTER` (`standard`, `legacy_ptt`, or `hikvision_guardlink`)
- `ONYX_HIKVISION_SDK_CONNECTOR_CLASS` (optional fully-qualified Kotlin class implementing `FskVendorSdkConnector`)
- `ONYX_HIKVISION_SDK_MANAGER_CLASS_CANDIDATES` (optional comma-separated Hikvision manager class candidates for reflective lookup)
- `ONYX_HIKVISION_SDK_ARTIFACT` (optional path to Hikvision SDK `.aar`/`.jar`)
- `ONYX_HIKVISION_SDK_MAVEN_COORD` (optional Maven coordinate for Hikvision SDK, for example `com.vendor:hikvision-sdk:4.5.6`)

Default behavior note:
- When `ONYX_USE_LIVE_FSK_SDK=true` or `ONYX_USE_LIVE_HIKVISION_SDK=true` and no connector class is provided, ONYX now defaults to built-in reflective vendor connectors and only falls back to broadcast mode if reflective startup fails.
- Vendor SDK dependency loading supports:
  - drop-in files in `android/app/libs/*.aar|*.jar`
  - Gradle property artifact path (`ONYX_*_SDK_ARTIFACT`)
  - Gradle property Maven coordinate (`ONYX_*_SDK_MAVEN_COORD`)

Build example:

```bash
./gradlew :app:assembleDebug \
  -PONYX_USE_LIVE_FSK_SDK=true \
  -PONYX_FSK_SDK_HEARTBEAT_ACTION=com.onyx.fsk.SDK_HEARTBEAT \
  -PONYX_FSK_SDK_PAYLOAD_ADAPTER=standard \
  -PONYX_FSK_SDK_CONNECTOR_CLASS=com.example.omnix_dashboard.telemetry.FskReflectiveVendorSdkConnector \
  -PONYX_FSK_SDK_ARTIFACT=libs/fsk-sdk.aar \
  -PONYX_USE_LIVE_HIKVISION_SDK=true \
  -PONYX_HIKVISION_SDK_HEARTBEAT_ACTION=com.onyx.hikvision.SDK_HEARTBEAT \
  -PONYX_HIKVISION_SDK_PAYLOAD_ADAPTER=hikvision_guardlink \
  -PONYX_HIKVISION_SDK_CONNECTOR_CLASS=com.example.omnix_dashboard.telemetry.HikvisionReflectiveVendorSdkConnector \
  -PONYX_HIKVISION_SDK_ARTIFACT=libs/hikvision-sdk.aar
```

On-device callback validation helper:

```bash
./scripts/guard_android_field_validation.sh \
  --provider fsk_sdk \
  --action com.onyx.fsk.SDK_HEARTBEAT \
  --samples 5 \
  --interval 1 \
  --adapter standard
```

Connector doctor (preflight strict direct-SDK validation):

```bash
./scripts/guard_android_connector_doctor.sh --provider fsk_sdk
```

One-command vendor SDK rollout + connector verification:

```bash
./scripts/guard_android_vendor_sdk_rollout.sh \
  --provider fsk_sdk \
  --sdk-artifact android/app/libs/fsk-sdk.aar \
  --connector-class com.onyx.vendor.fsk.LiveSdkConnector \
  --manager-classes com.onyx.vendor.fsk.LiveSdkManager
```

If exactly one provider-matching `.aar/.jar` exists in `android/app/libs`, `--sdk-artifact` is optional and rollout auto-detects it.

Auto-discover manager classes from artifact (recommended when class names are unknown):

```bash
./scripts/guard_android_vendor_sdk_rollout.sh \
  --provider fsk_sdk \
  --sdk-artifact android/app/libs/fsk-sdk.aar \
  --connector-class com.onyx.vendor.fsk.LiveSdkConnector \
  --auto-manager-classes
```

Vendor artifact class inspection helper:

```bash
./scripts/guard_android_vendor_sdk_inspect.sh \
  --artifact android/app/libs/fsk-sdk.aar \
  --provider fsk_sdk
```

End-to-end artifact capture helper:

```bash
./scripts/guard_android_live_validation.sh \
  --provider fsk_sdk \
  --action com.onyx.fsk.SDK_HEARTBEAT \
  --samples 5 \
  --interval 1 \
  --adapter standard \
  --expected-provider fsk_sdk
```

Hikvision artifact capture helper:

```bash
./scripts/guard_android_live_validation.sh \
  --provider hikvision_sdk \
  --action com.onyx.hikvision.SDK_HEARTBEAT \
  --samples 5 \
  --interval 1 \
  --adapter hikvision_guardlink \
  --expected-provider hikvision_sdk
```

Artifact report command:

```bash
./scripts/guard_android_live_validation_report.sh \
  --artifact-dir tmp/guard_field_validation/<timestamp> \
  --required-provider fsk_sdk
```

Note:
- Readiness artifact gate prefers `validation_report.json` and falls back to markdown report if JSON is unavailable.
- When JSON is available, readiness verifies embedded SHA-256 checksums against evidence files.
- `guard_gate_auto.sh` auto-aligns runtime config provider by generating a temporary
  `tmp/onyx.auto.*.json` file when `--provider` differs and `--config` is not supplied.
- If you explicitly pass `--config`, provider mismatch behavior remains strict by design.

One-command Android pilot gate:

```bash
./scripts/guard_android_pilot_gate.sh \
  --provider fsk_sdk \
  --action com.onyx.fsk.SDK_HEARTBEAT \
  --samples 5 \
  --interval 1 \
  --adapter standard \
  --expected-provider fsk_sdk \
  --require-real-device-artifacts \
  --max-report-age-hours 12
```

Hikvision one-command Android pilot gate:

```bash
./scripts/guard_android_pilot_gate.sh \
  --provider hikvision_sdk \
  --action com.onyx.hikvision.SDK_HEARTBEAT \
  --samples 5 \
  --interval 1 \
  --adapter hikvision_guardlink \
  --expected-provider hikvision_sdk \
  --require-real-device-artifacts \
  --max-report-age-hours 12
```

Direct connector gate behavior:
- `guard_android_pilot_gate.sh` now requires a direct SDK connector by default and fails if live mode falls back to broadcast.
- `guard_android_pilot_gate.sh` runs connector doctor automatically under strict mode.
- Strict mode also fails if the active connector is explicitly `broadcast_intent_connector`.
- Use `--allow-broadcast-fallback` only for intentional non-production debug runs.

No-device fallback (CI/local gate simulation):

```bash
./scripts/guard_android_mock_validation_artifacts.sh --samples 3
./scripts/guard_pilot_readiness_check.sh \
  --enforce-live-telemetry \
  --require-live-validation-artifacts \
  --max-live-validation-report-age-hours 12
```

Auditable readiness JSON wrapper:

```bash
./scripts/guard_pilot_gate_report.sh -- \
  --enforce-live-telemetry \
  --require-supabase-config \
  --require-live-validation-artifacts \
  --require-direct-sdk-connector \
  --require-real-device-artifacts \
  --max-live-validation-report-age-hours 12
```

Outputs:
- `tmp/guard_gate_reports/<timestamp>/gate_report.json`
- `tmp/guard_gate_reports/<timestamp>/readiness_output.log`
- `tmp/guard_gate_reports/<timestamp>/runtime_profile.txt`

Android live-validation artifact directories now also include:
- `runtime_profile.txt`
- `runtime_profile.json`

Runbook:
- [guard_android_live_validation_runbook.md](/Users/zaks/omnix_dashboard/docs/guard_android_live_validation_runbook.md)

## 3. Supabase Operational Retention Command

Run after migration `202603050009_add_guard_ops_replay_safety_retention.sql`:

```sql
select * from public.apply_guard_ops_retention_plan(90, 30, 365, 'pilot_schedule_run');
```

Audit views:
- `public.guard_projection_retention_runs`
- `public.guard_ops_replay_safety_checks`
- `public.guard_ops_retention_runs`

Policy note:
- Canonical `public.guard_ops_events` pruning is disabled by design.
- Replay safety checks are logged before any future archival decision.
