# Codex Summary — Demo Hygiene Fixes

Date: 2026-04-07

## Scope

Completed the urgent demo hygiene batch requested before any demo run:

1. Removed personal client/site defaults from `main.dart`.
2. Removed the hardcoded `Muhammed Vallee` / `MS Vallee Residence` monitoring profile branch.
3. Gated `DEMO-CLT` / `DEMO-SITE` fallback injection in `events_review_page.dart` so release builds do not synthesize those IDs.
4. Gated demo-only autopilot narration in `onyx_route.dart` with `kDebugMode`.
5. Removed fake VAT, SA ID, and Telegram chat ID autofill defaults from `admin_page.dart`.
6. Increased client comms agent `max_output_tokens` from `220` to `500`.
7. Replaced hardcoded `MS Vallee Residence` prompt examples with `[CLIENT_NAME]`.
8. Separated client comms `watchStatus` from `cameraStatus` so they no longer reflect the same signal path.

## Files Changed

- `lib/main.dart`
- `lib/ui/events_review_page.dart`
- `lib/domain/authority/onyx_route.dart`
- `lib/ui/admin_page.dart`
- `lib/application/telegram_ai_assistant_service.dart`

## Notes

- `main.dart`
  - `ONYX_CLIENT_ID` default is now `CLIENT-DEMO`.
  - `ONYX_SITE_ID` default is now `SITE-DEMO`.
  - `_selectedClient` / `_selectedSite` fallback values were also aligned to `CLIENT-DEMO` / `SITE-DEMO`.
  - `_monitoringSiteProfileFor(...)` now resolves client/site labels from directory seed data when available and otherwise falls back to neutral humanized labels instead of a personal hardcoded branch.
  - The demo monitoring camera label shortcut was retargeted from the old personal scope IDs to the neutral demo IDs.

- `events_review_page.dart`
  - Focused fallback seeding now returns the base event list in release builds if there is no real scope to use.
  - Debug builds still keep the synthetic fallback event behavior for local tooling.

- `onyx_route.dart`
  - `Reports` and `Admin` autopilot narration remain demo-specific only in debug builds.
  - Release builds now use neutral operational wording.

- `admin_page.dart`
  - Removed fake VAT defaults from client demo autofill and scenario apply flows.
  - Removed fake SA ID defaults from employee demo autofill, suggestion helpers, and scenario apply flows.
  - Removed fake Telegram chat ID defaults from client demo autofill and scenario apply flows.
  - While in the same file, also scrubbed remaining visible personal demo rows/prompts:
    - static client/site admin rows now use `CLIENT-DEMO` / `SITE-DEMO`
    - personal contact names were replaced with neutral `Operations Desk`
    - JSON hint text was updated to use neutral demo IDs
    - the Telegram prompt catalog label now uses `Demo Client`

- `telegram_ai_assistant_service.dart`
  - Client comms request budget increased to `500` output tokens.
  - Prompt examples now use `[CLIENT_NAME]` instead of a real site name.
  - `watchStatus` now reflects monitoring/watch posture signals first:
    - `available` when continuous watch coverage or active watch change is present
    - `limited` when monitoring context exists but full active watch posture is not confirmed
    - `offline` only when the watch path has no useful monitoring signal and the camera health is offline
  - `cameraStatus` continues to reflect the visual access path (`available` / `limited` / `offline`).

## Validation

- `dart analyze`
  - Result: `No issues found!`

## Follow-Up

- No runtime activation changes were made beyond the requested hygiene cleanup.
- No widget or service tests were run in this batch; this pass was validated with static analysis only, per request.
