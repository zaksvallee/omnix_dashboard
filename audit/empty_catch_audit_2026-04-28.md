# Empty Catch Audit — 2026-04-28

Scope:
- `bin/onyx_telegram_webhook.dart`
- `bin/onyx_status_api.dart`
- `bin/onyx_telegram_bot_api_proxy.dart`
- `bin/onyx_telegram_ai_processor.dart`
- `bin/onyx_camera_worker.dart`

Why this exists:
- Follow-up to the 2026-04-28 `developer.log` / journald audit.
- A prior scratch note referenced 12 empty catches. The current tree has 17 live
  empty-catch sites, so this document classifies the on-disk state rather than
  the stale count.

## Summary

- Total findings: 17
- `defensible_silence`: 10
- `should_log_warn`: 5
- `should_log_error`: 0
- `needs_investigation`: 2

## Findings

| File / line | Function | What gets swallowed | Risk | Recommended fix | Notes |
| --- | --- | --- | --- | --- | --- |
| `bin/onyx_telegram_bot_api_proxy.dart:144` | `_handleRequest` | Failure while writing the fallback `502` JSON after the upstream proxy path already failed and logged. | `defensible_silence` | `keep_as_is` | At this point the response may already be partially committed; logging already happened in the outer catch. |
| `bin/onyx_telegram_bot_api_proxy.dart:147` | `_handleRequest` | Failure closing `request.response` after the fallback response write also failed. | `defensible_silence` | `keep_as_is` | Pure cleanup after a partial response; additional logs would be noise. |
| `bin/onyx_telegram_ai_processor.dart:1149` | `_fetchLatestSnapshotBytes` | RTSP frame fetch timeout / network / decode failure while trying to attach a snapshot to AI replies. | `should_log_warn` | `add_logWarn` | The caller cleanly falls back to a text-only reply, but repeated frame-server outages disappear completely today. |
| `bin/onyx_telegram_ai_processor.dart:2621` | `OpenAiTelegramAiAssistantService.draftReply` | Provider/network failure during OpenAI reply generation. | `should_log_warn` | `add_logWarn` | The operator still gets the canned fallback reply, but provider outages and auth/config regressions are silent. |
| `bin/onyx_telegram_ai_processor.dart:2660` | `_extractResponseText` | JSON parse / response-shape failure while decoding the OpenAI response body. | `needs_investigation` | `defer` | Logging here needs care: raw provider bodies may contain sensitive prompt/context data, and the safer fix may be logging at the caller with a redacted preview instead. |
| `bin/onyx_telegram_ai_processor.dart:2930` | `TelegramBotApi.answerCallbackQuery` | Telegram callback acknowledgement request failure. | `should_log_warn` | `add_logWarn` | Silent `false` hides callback-ack failures that leave Telegram buttons spinning without a visible diagnosis path. |
| `bin/onyx_telegram_ai_processor.dart:3015` | `TelegramBotApi._editMessage` | Telegram message edit request failure. | `should_log_warn` | `add_logWarn` | Silent `false` hides edit/update failures on live operator-facing Telegram messages. |
| `bin/onyx_telegram_ai_processor.dart:3029` | `TelegramBotApi._extractTelegramErrorDescription` | JSON parse failure while trying to extract a human-readable Telegram error description. | `defensible_silence` | `keep_as_is` | This helper is best-effort enrichment only; returning `null` already falls back to the raw failure path. |
| `bin/onyx_camera_worker.dart:1854` | `OnyxSiteAwarenessRepository._expireOnDemandExpectedVisitors` | Failure expiring stale on-demand expected visitors. | `defensible_silence` | `keep_as_is` | Explicitly documented as best-effort cleanup; primary detection/alert flow is unaffected. |
| `bin/onyx_camera_worker.dart:2845` | `OnyxHikIsapiStream._isYoloReady` | YOLO health probe request / parse failure, collapsed to `false`. | `defensible_silence` | `keep_as_is` | This path is polled and would spam badly if every failed health probe logged. The state-transition logs around unhealthy/recovered already carry most operator value. |
| `bin/onyx_camera_worker.dart:3662` | `OnyxHikIsapiStream._emitTelegramAlarm` | Failure persisting the degraded-send event after the critical stderr alarm was already emitted. | `defensible_silence` | `keep_as_is` | The critical operator-facing alarm has already been emitted to stderr/admin Telegram; the DB row is explicitly tier-2. |
| `bin/onyx_camera_worker.dart:5151` | `_sendCameraWorkerThreatModeAlert` | Failure sending the direct admin Telegram threat-mode alert. | `should_log_warn` | `add_logWarn` | This is not best-effort decoration: if it fails, the threat-mode notification disappears entirely today. |
| `bin/onyx_telegram_webhook.dart:164` | `_handleRequest` | Failure sending the fallback `200 OK` to Telegram after the top-level request handler already threw and logged. | `defensible_silence` | `keep_as_is` | Response may already be closed or committed; there is already a top-level error log. |
| `bin/onyx_telegram_webhook.dart:250` | `_respond` | Failure writing/closing the HTTP response, usually because the client disconnected. | `defensible_silence` | `keep_as_is` | Expected socket-close race on a tiny helper; noisy logs would not improve operator diagnosis. |
| `bin/onyx_telegram_webhook.dart:267` | `_readBody` | Request-stream read failure, currently collapsed into the same `null` path used for oversized bodies. | `needs_investigation` | `defer` | The current API conflates “body too large” and “stream read failed,” so adding a log here without splitting result states would produce misleading diagnostics. |
| `bin/onyx_status_api.dart:143` | `_handleRequest` | Failure writing the fallback `500` JSON after the top-level status request already failed and logged. | `defensible_silence` | `keep_as_is` | Same partial-response cleanup pattern as the webhook/proxy handlers. |
| `bin/onyx_status_api.dart:157` | `_handlePatrolScanRequest` | JSON parse failure on the caller-supplied patrol-scan request body. | `defensible_silence` | `keep_as_is` | The handler already returns a clean `400 invalid_json`; logging every malformed caller body would likely be noisy unless abuse detection becomes a goal. |

## Follow-up Order

1. Add `logWarn` at the five `should_log_warn` sites:
   - `bin/onyx_telegram_ai_processor.dart:1149`
   - `bin/onyx_telegram_ai_processor.dart:2621`
   - `bin/onyx_telegram_ai_processor.dart:2930`
   - `bin/onyx_telegram_ai_processor.dart:3015`
   - `bin/onyx_camera_worker.dart:5151`
2. Investigate the two ambiguous helper sites before adding logs:
   - `bin/onyx_telegram_ai_processor.dart:2660`
   - `bin/onyx_telegram_webhook.dart:267`
3. Leave the 10 `defensible_silence` sites alone unless future production evidence shows they are masking a real incident class.
