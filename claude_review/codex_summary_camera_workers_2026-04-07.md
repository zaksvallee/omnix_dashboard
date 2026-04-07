# Codex Summary — Camera Workers (2026-04-07)

## Batch
- Implemented construction-time credential injection for ONYX camera workers.
- Replaced the Hikvision staging-only execution path with live ISAPI verification, channel discovery, channel update, and read-back confirmation.
- Kept Dahua, Axis, Uniview, and Generic workers in staging mode, but made them credential-ready for future vendor API work.

## What Changed

### Credential carrier + injection
- Added camera-control auth parsing helpers to `lib/application/dvr_http_auth.dart`.
- Extended admin site metadata handling so site camera auth can be captured and persisted through:
  - `lib/application/admin/admin_directory_service.dart`
  - `lib/ui/admin_page.dart`
- Wired scope-specific credentials into camera worker construction through:
  - `lib/main.dart`
  - `lib/ui/onyx_route_system_builders.dart`
  - `lib/ui/onyx_route_command_center_builders.dart`

### Hikvision worker
- `lib/application/onyx_agent_camera_bridge_receiver.dart`
  - `HikvisionOnyxAgentCameraWorker` now:
    1. verifies reachability/auth with `GET /ISAPI/System/deviceInfo`
    2. discovers channels with `GET /ISAPI/Streaming/channels`
    3. applies the requested preset with `PUT /ISAPI/Streaming/channels/{id}`
    4. confirms the write with `GET /ISAPI/Streaming/channels/{id}`
  - Returns `success: true` only when read-back matches the requested preset.
  - Returns structured `success: false` outcomes for auth failure, unreachable devices, missing channels, rejected writes, and read-back mismatch.
- Fixed the XML channel update helper so tag replacement preserves valid XML during write-back.

### Non-Hikvision workers
- `DahuaOnyxAgentCameraWorker`
- `AxisOnyxAgentCameraWorker`
- `UniviewOnyxAgentCameraWorker`
- `GenericOnyxAgentCameraWorker`
- All now accept injected credentials and are ready for future vendor API implementations.
- Each still reports staging mode with TODO-backed vendor implementation notes.

### UX copy
- Removed the old simulated-worker wording.
- ONYX agent UI now surfaces staging copy as:
  - `Camera control in staging mode`
  - scope-specific live-control staging detail

## Validation
- `flutter test /Users/zaks/omnix_dashboard/test/application/onyx_agent_camera_bridge_receiver_test.dart /Users/zaks/omnix_dashboard/test/application/onyx_agent_camera_bridge_server_test.dart /Users/zaks/omnix_dashboard/test/application/onyx_agent_camera_change_service_test.dart /Users/zaks/omnix_dashboard/test/ui/onyx_agent_page_widget_test.dart`
- `dart analyze`

## Test Coverage Added / Updated
- `test/application/onyx_agent_camera_bridge_receiver_test.dart`
  - successful Hikvision verification + read-back confirmation
  - auth failure -> `success: false`
  - unreachable device -> `success: false`
  - read-back mismatch -> `success: false`
  - generic fallback stays staged
  - JSON handler returns structured metadata
- `test/application/onyx_agent_camera_bridge_server_test.dart`
  - execute path works with injected receiver worker
  - restart lifecycle remains covered
- `test/application/onyx_agent_camera_change_service_test.dart`
  - updated mode-label expectation
- `test/ui/onyx_agent_page_widget_test.dart`
  - updated staging copy expectation

## Remaining Intentional Limitation
- Only Hikvision performs live device writes in this batch.
- Dahua, Axis, Uniview, and Generic workers are credential-ready but still staged until their vendor-specific APIs are implemented.
