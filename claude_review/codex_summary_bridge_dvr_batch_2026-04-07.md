# Codex Summary — Bridge + DVR Batch

Date: 2026-04-07
Repo: `/Users/zaks/omnix_dashboard`

## Scope completed

This batch closed the three explicitly requested remaining items:

1. Bridge server JSON hardening
2. Hikvision DVR reconnect-state misreport
3. `frame_limit` relay coverage
4. Bridge stop/restart lifecycle coverage

Per instruction, the repo remained the source of truth. No previously completed shell/VIP/authority/SLA work was reworked.

## 1. Bridge server JSON hardening

Files:

- `/Users/zaks/omnix_dashboard/lib/application/onyx_agent_camera_bridge_server_io.dart`
- `/Users/zaks/omnix_dashboard/test/application/onyx_agent_camera_bridge_server_test.dart`

What changed:

- Added a dedicated request-body decode path in `LocalHttpOnyxAgentCameraBridgeServer` so malformed request bodies no longer fall through into a generic server crash path.
- Malformed JSON now returns a structured `400` response with:
  - `success: false`
  - `provider_label: local:camera-bridge-server`
  - `detail`
  - `recommended_next_step`
  - `recorded_at_utc`
- Non-object JSON bodies now return a structured `400` response instead of relying on downstream type failures.
- The generic server-side exception path now also emits the same structured error envelope shape instead of an unstructured failure.
- Missing required execution fields remain handled by the receiver contract, and coverage was added to prove the server surfaces that path as a structured `422`.

Tests added/updated:

- malformed JSON -> structured `400`
- non-object JSON -> structured `400`
- missing required fields -> structured `422`

## 2. Hikvision DVR reconnect-state fix

Files:

- `/Users/zaks/omnix_dashboard/lib/application/local_hikvision_dvr_proxy_service.dart`
- `/Users/zaks/omnix_dashboard/lib/application/client_camera_health_fact_packet_service.dart`
- `/Users/zaks/omnix_dashboard/lib/ui/live_operations_page.dart`
- `/Users/zaks/omnix_dashboard/test/application/local_hikvision_dvr_proxy_service_test.dart`
- `/Users/zaks/omnix_dashboard/test/application/client_camera_health_fact_packet_service_test.dart`
- `/Users/zaks/omnix_dashboard/test/ui/live_operations_page_widget_test.dart`

What changed:

- Replaced the old boolean-only upstream health signal with an explicit upstream stream status:
  - `connected`
  - `reconnecting`
  - `disconnected`
- `/health` now exposes both:
  - `upstream_stream_status`
  - `upstream_stream_connected`
- During `upstreamReconnectDelay`, the proxy now reports:
  - `upstream_stream_status: reconnecting`
  - `upstream_stream_connected: false`
- This removes the earlier false-positive connected signal during reconnect delay.
- The camera-health fact packet service now parses and normalizes the new status field, preserves compatibility with the old boolean shape, and exposes:
  - `localProxyUpstreamStreamStatus`
  - reconnect-aware `scopedLocalProxyStatusLabel`
- Live Ops camera preview UI now distinguishes reconnecting from connected and surfaces operator-facing copy:
  - `Proxy RECONNECTING...`
  - `Upstream RECONNECTING...`
  - summary copy explaining the scoped local proxy and upstream alert stream are reconnecting

Tests added/updated:

- proxy `/health` reports reconnecting during delay
- camera-health fact packet parsing preserves reconnecting state
- live operations camera preview panel shows reconnecting labels and summary text

## 3. `frame_limit` relay coverage

File:

- `/Users/zaks/omnix_dashboard/test/application/local_hikvision_dvr_proxy_service_test.dart`

What changed:

- Added a dedicated regression proving the MJPEG relay honors `?frame_limit=N` rather than only incidentally touching the code path.
- The new test:
  - requests `frame_limit=2`
  - serves unique bytes for sequential upstream frames
  - verifies exactly two snapshot fetches occur
  - verifies frames 1 and 2 are present in the relay payload
  - verifies frame 3 is not present

This closes the audit note that the parameter existed but was not explicitly locked by a dedicated test.

## 4. Bridge stop/restart lifecycle coverage

Files:

- `/Users/zaks/omnix_dashboard/test/application/onyx_agent_camera_bridge_server_test.dart`

What changed:

- Added an explicit regression for the desktop IO bridge lifecycle:
  - `POST /execute` succeeds while the bridge is running
  - the same `POST /execute` fails after `close()`
  - `start()` after `close()` binds the bridge again and `POST /execute` succeeds once more
- Added a direct contract test for the unsupported web stub:
  - `UnsupportedOnyxAgentCameraBridgeServer` remains `isRunning == false`
  - `endpoint` remains `null`
  - `start()` and `close()` remain safe no-op lifecycle calls

This closes the audit follow-up that the bridge lifecycle paths were unverified in tests even though the implementation already supported them.

## Validation

Bridge hardening:

- `dart analyze lib/application/onyx_agent_camera_bridge_server_io.dart test/application/onyx_agent_camera_bridge_server_test.dart`
- `flutter test test/application/onyx_agent_camera_bridge_server_test.dart`

Reconnect-state batch:

- `dart analyze lib/application/local_hikvision_dvr_proxy_service.dart lib/application/client_camera_health_fact_packet_service.dart lib/ui/live_operations_page.dart test/application/local_hikvision_dvr_proxy_service_test.dart test/application/client_camera_health_fact_packet_service_test.dart test/ui/live_operations_page_widget_test.dart`
- `flutter test test/application/local_hikvision_dvr_proxy_service_test.dart`
- `flutter test test/application/client_camera_health_fact_packet_service_test.dart --plain-name "local proxy health service parses reconnecting upstream state"`
- `flutter test test/ui/live_operations_page_widget_test.dart --plain-name "live operations shows reconnecting local proxy status in the camera preview panel"`

Frame-limit coverage:

- `flutter test test/application/local_hikvision_dvr_proxy_service_test.dart`

Bridge lifecycle coverage:

- `dart analyze test/application/onyx_agent_camera_bridge_server_test.dart lib/application/onyx_agent_camera_bridge_server.dart lib/application/onyx_agent_camera_bridge_server_io.dart lib/application/onyx_agent_camera_bridge_server_stub.dart`
- `flutter test test/application/onyx_agent_camera_bridge_server_test.dart`

Final analyze sweep after all three:

- `dart analyze lib/application/onyx_agent_camera_bridge_server_io.dart lib/application/local_hikvision_dvr_proxy_service.dart lib/application/client_camera_health_fact_packet_service.dart lib/ui/live_operations_page.dart test/application/onyx_agent_camera_bridge_server_test.dart test/application/local_hikvision_dvr_proxy_service_test.dart test/application/client_camera_health_fact_packet_service_test.dart test/ui/live_operations_page_widget_test.dart`

Result:

- Final targeted `dart analyze` sweep passed with `No issues found!`
- Focused test runs for all three batches passed

## Remaining follow-up candidates

These requested bridge/DVR items are complete.

Higher-risk REVIEW items from the audit remain policy/UX decisions rather than safe AUTO changes:

- web-stub bridge support disclosure
- simulated vendor worker behavior vs real device-write contract
