# Codex Summary — Agent Brain Error Signals

Date: 2026-04-07
Workspace: /Users/zaks/omnix_dashboard

## Batch

Implemented the highest-priority verified remaining AUTO item from the agent audit:

- `P1 AUTO` — brain-service failure signaling

Verified open before change:

- `lib/application/onyx_agent_cloud_boost_service.dart` still collapsed provider failures to `null`
- `lib/application/onyx_agent_local_brain_service.dart` still collapsed provider failures to `null`
- `lib/ui/onyx_agent_page.dart` treated `null` as "no advisory", so real provider failures were silent

## Changes

Implemented in:

- `/Users/zaks/omnix_dashboard/lib/application/onyx_agent_cloud_boost_service.dart`
- `/Users/zaks/omnix_dashboard/lib/application/onyx_agent_local_brain_service.dart`
- `/Users/zaks/omnix_dashboard/lib/application/telegram_ai_assistant_service.dart`
- `/Users/zaks/omnix_dashboard/lib/ui/onyx_agent_page.dart`

Behavior changes:

- Added explicit failure metadata to `OnyxAgentCloudBoostResponse`:
  - `isError`
  - `errorSummary`
  - `errorDetail`
- Added `onyxAgentCloudBoostErrorResponse(...)` helper for structured degraded-provider returns.
- OpenAI and Ollama service failures now return structured error responses for:
  - non-2xx HTTP responses
  - thrown transport/runtime exceptions
  - invalid JSON response bodies
- `OnyxAgentPage` now surfaces those structured failures as operator-visible tool messages instead of silently treating them as missing advisories.
- `OnyxFirstTelegramAiAssistantService` now ignores ONYX error responses and continues to direct-provider / fallback drafting instead of treating provider errors as reply content.

## Tests Added / Updated

- `/Users/zaks/omnix_dashboard/test/application/onyx_agent_cloud_boost_service_test.dart`
  - structured error on non-2xx
  - structured error on thrown request failure
- `/Users/zaks/omnix_dashboard/test/application/onyx_agent_local_brain_service_test.dart`
  - structured error on non-2xx
  - structured error on thrown request failure
- `/Users/zaks/omnix_dashboard/test/application/telegram_ai_assistant_service_test.dart`
  - ONYX-first assistant falls back to direct provider when ONYX cloud returns an error response
- `/Users/zaks/omnix_dashboard/test/ui/onyx_agent_page_widget_test.dart`
  - local brain error response is surfaced to the operator
  - cloud boost error response is surfaced to the operator

## Validation

Passed:

- `dart analyze lib/application/onyx_agent_cloud_boost_service.dart lib/application/onyx_agent_local_brain_service.dart lib/application/telegram_ai_assistant_service.dart lib/ui/onyx_agent_page.dart test/application/onyx_agent_cloud_boost_service_test.dart test/application/onyx_agent_local_brain_service_test.dart test/application/telegram_ai_assistant_service_test.dart test/ui/onyx_agent_page_widget_test.dart`
- `flutter test /Users/zaks/omnix_dashboard/test/application/onyx_agent_cloud_boost_service_test.dart /Users/zaks/omnix_dashboard/test/application/onyx_agent_local_brain_service_test.dart`
- `flutter test /Users/zaks/omnix_dashboard/test/application/telegram_ai_assistant_service_test.dart --plain-name "onyx-first telegram assistant falls back to direct provider when onyx cloud returns an error response"`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/onyx_agent_page_widget_test.dart --plain-name "onyx agent page surfaces local brain error responses"`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/onyx_agent_page_widget_test.dart --plain-name "onyx agent page surfaces cloud boost error responses"`

## Remaining verified open candidates after this batch

- `P2 AUTO` — `lib/application/onyx_agent_camera_bridge_server_io.dart` still decodes request JSON directly and only special-cases `FormatException`
- `P2/P1` health-reporting fix — `lib/application/local_hikvision_dvr_proxy_service.dart` still clears `_upstreamAlertConnected` in the per-loop `finally`
- `P3 AUTO` — `frame_limit` relay coverage in `test/application/local_hikvision_dvr_proxy_service_test.dart` still appears open
