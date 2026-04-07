# ONYX Telegram Admin Handoff 2026-03-29

This document is the single handoff note for the ONYX Telegram, Admin, and
camera-bridge hardening stream as of 2026-03-29.

Use this file the next time the question is: "Where did we leave off?"

## Scope

This handoff covers the work around:

- ONYX admin Telegram commands
- client and partner Telegram reads
- Telegram onboarding intake and approval
- Admin system controls for Telegram
- Telegram -> onboarding -> bridge -> live-ops handoff
- test coverage and test-harness cleanup for those flows

It does not try to summarize every unrelated modified file in the current dirty
worktree.

## Primary Source Files

- `lib/main.dart`
- `lib/application/onyx_command_parser.dart`
- `lib/application/onyx_telegram_operational_command_service.dart`
- `lib/application/telegram_client_quick_action_service.dart`
- `lib/application/onyx_scope_guard.dart`
- `lib/application/onyx_telegram_command_gateway.dart`
- `lib/ui/admin_page.dart`
- `lib/ui/onyx_route_system_builders.dart`
- `lib/ui/onyx_camera_bridge_actions.dart`
- `lib/ui/onyx_camera_bridge_clipboard.dart`

## Primary Test Files

- `test/application/onyx_command_parser_test.dart`
- `test/application/onyx_telegram_operational_command_service_test.dart`
- `test/application/telegram_client_quick_action_service_test.dart`
- `test/application/onyx_scope_guard_test.dart`
- `test/application/onyx_telegram_command_gateway_test.dart`
- `test/ui/onyx_app_admin_route_widget_test.dart`
- `test/ui/onyx_app_clients_route_widget_test.dart`
- `test/ui/admin_page_widget_test.dart`

## What Is Done

### 1. Telegram lane separation

- Admin `Onyx` and client `MS Vallee Residence` lanes are treated as distinct
  runtime paths.
- The borrowed/inherited admin path no longer steals client-room prompts before
  the client quick-action path sees them.
- Admin handled, denied, and failed-send prompts now show up in the recent-feed
  audit instead of disappearing.

### 2. Natural-language command widening

Admin room coverage was widened to reliably handle phrases like:

- `brief ops`
- `check the system`
- `what changed today`
- `review cameras`
- `what do the feeds show`
- `check tonights breaches`
- onboarding starters like `client onboarding`, `onboard ...`,
  `create new client ...`, `set up new client ...`

Client room coverage was widened to reliably handle phrases like:

- `check cameras`
- `sleep check`
- `brief this site`
- `status here`
- `what changed here`
- `what changed tonight`
- `anything new there`
- `give me an update`

Partner/supervisor reads were widened for scoped operational lookups like:

- dispatch lookups
- guard status
- overnight incidents
- scoped read-only operational asks

### 3. Better fallback and denial behavior

- Common prompts no longer fall through to the old generic
  "I can respond directly..." helper as often.
- Read-only denials now suggest useful next asks instead of only saying
  "not allowed".
- Cross-scope denials remain strict but now point the operator toward an
  in-scope question.

### 4. Stateful Telegram onboarding intake

- ONYX stages onboarding intake instead of only replying with generic helper
  copy.
- Intake now asks for the next missing field one step at a time.
- Label-first follow-ups like `cameras 32` and `vendor Hikvision` are accepted.
- Cleaner follow-up examples are shown to the operator.
- Some unlabeled contact-like replies can be inferred when the rest of the
  intake is already clear.
- The onboarding draft is stateful across multiple Telegram messages.
- The onboarding draft can survive app restarts.

### 5. Approval and operational follow-through

- `continue setup` and `approve this client` are recognized on the pending
  draft.
- Approval promotes the staged intake into the next operational step.
- Admin target scope is updated to the suggested client/site pair.
- When local/backend upsert is not available, ONYX stays honest and syncs
  locally instead of pretending the backend write definitely happened.

### 6. Admin handoff after approval

- Approved Telegram onboarding now feeds into Admin instead of dying inside the
  chat flow.
- Clients and Sites surfaces can reflect the locally synced Telegram onboarding.
- System Controls shows local sync context for the newly approved scope.
- A `Telegram Onboarding Follow-Up` card appears with:
  - `Open Client Onboarding`
  - `Open Site Onboarding`
- Those onboarding dialogs open prefilled from the approved Telegram draft.
- The follow-up card and approved prefill can survive app restarts.
- Dismissing the follow-up card can also survive app restarts.

### 7. Admin Telegram visibility improvements

System Controls now includes:

- `Telegram Wiring Checklist`
- effective runtime snippet / copy-ready values
- prompt catalog for admin, client, and partner lanes
- `Recent Live Telegram Asks`
- grouped room sections
- counts per room
- latest handled time
- outcome labels
- `Copy Latest` header actions

### 8. Bridge and CCTV handoff

Approved Telegram onboarding can now seed the camera-bridge workflow.

That seeded path now supports:

- bridge setup payloads that include approved Telegram context
- `Copy Camera Brief`
- `Copy CCTV Review Brief`
- `Validate Bridge + Vendor Brief`
- `Poll CCTV Now`
- `Open Command Scope`

The seeded bridge surface now behaves like a mini-runbook instead of a static
card.

### 9. Bridge runbook persistence

- Runbook progress for validate, CCTV poll, and command-scope opening is stored
  and restored.
- A newer approval resets runbook progress for the new site.
- Persistence is last-write-wins so older async bridge snapshots do not clobber
  newer runbook progress.

### 10. Test and harness cleanup

The main route/widget suites were significantly cleaned up with shared helpers
for:

- admin Telegram prompts
- client Telegram prompts
- partner Telegram prompts
- admin Telegram conversations
- pending onboarding restart flows
- approved onboarding restart flows
- Telegram bridge handoff flows
- Admin system-tab widget fixtures
- AI draft widgets
- client-comms audit widgets
- partner lane health widgets

This reduces repeated route boilerplate and makes future failures easier to
read.

## What Was Re-Smoked Near The End

These high-value targeted smokes were re-run and green late in the session:

### Admin route

- `onyx app keeps the common admin telegram prompt matrix stable`
- `onyx app approves a complete pending onboarding draft from admin telegram`
- `onyx app opens client onboarding from telegram follow-up actions after approval`
- `onyx app opens site onboarding from telegram follow-up actions after approval`
- `onyx app opens operations from telegram camera bridge seed`

### Client/partner route

- `onyx app keeps the common client telegram prompt matrix stable`
- `onyx app answers incidents last night lookups in partner telegram chats`

### Admin widgets

- `admin tables surface partner lane health summaries`
- `client comms bridge keeps link wording across dialog actions`
- `system tab humanizes telegram bridge detail in audit cards`
- `system tab renders client comms audit cards`
- `system tab shows client comms audit empty state copy`
- `system tab can refine telegram ai draft before approval`

## What Is Still Left

### 1. Live environment verification

The biggest remaining gap is a short real-world Telegram smoke in the live or
staging environment, especially for:

- admin room prompt handling
- client room prompt handling
- partner room overnight read path
- onboarding approval
- post-approval Admin follow-up actions

### 2. Invite-link limitation

ONYX still does not autonomously join a Telegram group from an invite link by
itself.

The practical workflow remains:

- create group
- add bot
- send a message in that group
- bind/link the chat

### 3. Vendor bridge action proof gap

Coverage is strong, but one thing is still slightly imperfect:

- direct Admin bridge validation is route-proven with injected bridge overrides
- Telegram vendor seed presence is route-proven
- vendor progress persistence after restart is route-proven

What is not yet locked as one perfect all-in-one route proof is:

- Telegram vendor seed action pressed
- real bridge validate path completes
- resulting seeded state updates end to end in one stable assertion

### 4. No full-suite claim

We intentionally stayed on focused tests and smokes to conserve weekly budget.
The honest claim is:

- the critical Telegram/Admin paths we touched are heavily tested and re-smoked

The claim is not:

- the entire repo has been re-run and is globally green

### 5. Dirty worktree caution

The repo has many unrelated modified files. Do not treat this handoff as a
ready-to-ship isolated change set without first separating or reviewing the
broader worktree.

## Safest Next Starting Point

If work resumes later, the safest next step is:

1. Run a short live Telegram smoke in the real rooms.
2. If that is clean, tighten the vendor bridge action with one more stable
   route proof if possible.
3. Only after that, consider packaging/isolating this feature stream from the
   broader dirty worktree.

## Recommended First Checks To Re-Run

If you want a quick confidence pass before touching more code, re-run these:

- `flutter test test/ui/onyx_app_admin_route_widget_test.dart --plain-name 'onyx app keeps the common admin telegram prompt matrix stable' -r compact`
- `flutter test test/ui/onyx_app_clients_route_widget_test.dart --plain-name 'onyx app keeps the common client telegram prompt matrix stable' -r compact`
- `flutter test test/ui/onyx_app_admin_route_widget_test.dart --plain-name 'onyx app approves a complete pending onboarding draft from admin telegram' -r compact`
- `flutter test test/ui/onyx_app_admin_route_widget_test.dart --plain-name 'onyx app opens operations from telegram camera bridge seed' -r compact`
- `flutter test test/ui/admin_page_widget_test.dart --plain-name 'system tab can refine telegram ai draft before approval' -r compact`

## One-Line Memory

We left off with ONYX Telegram mostly hardened end to end: admin/client/partner
prompt handling is much broader, onboarding is stateful and flows into Admin,
the bridge/runbook handoff exists and persists, the highest-value route/widget
smokes are green, and the next best move is a short live Telegram verification
plus optional vendor-bridge route tightening.
