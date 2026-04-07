# Codex Summary - Client Comms Agent Prompt Refresh

Date: 2026-04-07

## Completed

- Replaced the client-facing ONYX system prompt in `/Users/zaks/omnix_dashboard/lib/application/telegram_ai_assistant_service.dart` with the approved ONYX Security Intelligence prompt.
- Added prompt-time context injection with non-empty fallbacks for:
  - `clientName`
  - `siteName`
  - `watchStatus`
  - `cameraStatus`
  - `activeIncidents`
  - `lastActivity`
  - `guardOnSite`
  - `lastGuardCheckin`
- All missing values now resolve to `"unknown"` instead of leaving blank prompt fields.
- Preserved recent thread/style grounding as internal context blocks after the new base prompt so the assistant still has lane memory without exposing raw internal labels to clients.

## Broad Status Tone Fix

- Updated `/Users/zaks/omnix_dashboard/lib/application/telegram_ai_assistant_site_view.dart` so truth-grounded broad status checks now use the new client-safe tone.
- `"check site status"` and similar broad status asks now resolve to brief ONYX wording such as:
  - `Based on what I can see, there are no active alerts ...`
  - `My visual monitoring is limited right now.`
  - `Want me to flag your guard for a check?`
- This removes the old harsher fallback wording on the main forced-fallback path for broad site-status asks.

## Validation

- `dart analyze /Users/zaks/omnix_dashboard/lib/application/telegram_ai_assistant_service.dart /Users/zaks/omnix_dashboard/lib/application/telegram_ai_assistant_site_view.dart /Users/zaks/omnix_dashboard/test/application/telegram_ai_assistant_service_test.dart`
- `flutter test /Users/zaks/omnix_dashboard/test/application/telegram_ai_assistant_service_test.dart --plain-name "openai assistant injects ONYX client comms prompt context"`
- `flutter test /Users/zaks/omnix_dashboard/test/application/telegram_ai_assistant_service_test.dart --plain-name "openai assistant treats broad status checks as packet-grounded current-site-view asks during a bridge outage"`
- `flutter test /Users/zaks/omnix_dashboard/test/application/telegram_ai_assistant_service_test.dart --plain-name "openai assistant rejects camera-only reassurance wording for broad status checks during a bridge outage"`
- `flutter test /Users/zaks/omnix_dashboard/test/application/telegram_ai_assistant_service_test.dart --plain-name "openai assistant treats broad live-status checks as packet-grounded current-site-view asks"`
- `flutter test /Users/zaks/omnix_dashboard/test/application/telegram_ai_assistant_service_test.dart --plain-name "openai assistant answers check site status with the updated monitoring tone"`

All of the above passed.

## Notes

- I removed a set of now-unused prompt-note helpers from `telegram_ai_assistant_service.dart` after the prompt swap so `dart analyze` stayed clean.
- I did not widen the batch into every legacy client fallback phrase in the file. The primary broad-status path requested by Zaks is now aligned with the approved tone.
