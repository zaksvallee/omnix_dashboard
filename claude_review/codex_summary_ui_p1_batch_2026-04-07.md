# Codex Summary — UI P1 Batch — 2026-04-07

## Scope completed

Implemented the requested AUTO fixes across:

- `lib/ui/clients_page.dart`
- `lib/ui/guards_page.dart`
- `lib/ui/ai_queue_page.dart`
- `lib/ui/onyx_route_operations_builders.dart`

Updated focused widget coverage in:

- `test/ui/clients_page_widget_test.dart`
- `test/ui/guards_page_widget_test.dart`
- `test/ui/ai_queue_page_widget_test.dart`

## Clients Page

Completed:

- Removed build-time mutation of `_selectedClientId` / `_selectedSiteId`.
  - `build()` now derives effective selection locally.
  - `_scheduleSelectionReconcile(...)` applies state changes post-frame through `setState(...)` only.
- Added `try/finally` in `_retryPushSync()`.
  - Push status now always returns to `push idle` after the callback completes.
- Replaced hardcoded `_voipStageStatus = 'staged'` with a nullable state.
  - Default state is now unconfigured.
  - Delivery chip shows `VoIP unconfigured` instead of pretending the lane is staged.
  - The staged / active VoIP panel only renders when VoIP is actually configured.
- Added a real data guard for the learned-style card.
  - The learned-style rail does not render when no learned-style data exists for the scoped lane.
- Added explicit evidence-return acknowledgement.
  - The banner now renders an `Acknowledge` action.
  - `_activeEvidenceReturnReceipt` is cleared once the operator acknowledges it.

Result:

- No more build-time selection mutation.
- Push retry state no longer gets stuck in review mode.
- VoIP no longer presents a fake staged state.
- Learned-style UI no longer displays hardcoded placeholder copy.
- Evidence return receipts now have a clean operator-driven lifecycle.

## Guards Page

Completed:

- Added an optional live repository path:
  - `GuardsPage.guardSyncRepositoryFuture`
- Wired controller-mode route construction to pass `_guardSyncRepositoryFuture`.
- Added `_loadLiveGuards()` to read `GuardAssignment` and `GuardSyncOperation` data from `GuardSyncRepository`.
- Added live-data derivation helpers for:
  - guard status
  - site resolution
  - sync health
  - last-sync labels
  - roster rows
  - shift history rows
- Replaced hardcoded site-filter chips with filters derived from the effective guard dataset.

Behavior:

- The page now overlays live repository state onto the workforce surfaces when repository data is available.
- Seeded guard metadata remains as fallback enrichment when the scoped repository does not expose richer profile fields yet.
- Roster and history surfaces now derive from the effective guard dataset instead of being permanently frozen to the original static snapshot.

Note:

- The current repository available to the page is still scoped, so this batch intentionally uses live repository state as the source of truth where present and keeps seeded profile richness as fallback for incomplete backend coverage.

## AI Queue

Completed:

- Fixed paused progress bar behavior.
  - `LinearProgressIndicator` now uses `0.0` when the active action is paused.
- Fixed `_nextShiftDrafts`.
  - Getter now reuses `_isNextShiftDraft(...)`, restoring trim / uppercase normalization.
- Fixed daily stats refresh.
  - `_stats` is no longer `final`.
  - `didUpdateWidget(...)` now recomputes daily stats when the source event set changes.
- Fixed CCTV dismiss handling.
  - Dismissing an alert no longer clears `_selectedCctvFeedId` unless the dismissed alert actually owns the current selected feed state.
  - Shared/manual feed selection now survives alert dismissal correctly.

Result:

- Paused actions no longer show misleading countdown progress.
- Next-shift drafts use the same normalization path as the rest of the queue.
- Daily stats update when fresh events arrive.
- CCTV feed selection is no longer accidentally cleared by unrelated alert dismissal.

## Validation

### Analyze

Passed:

- `dart analyze lib/ui/clients_page.dart lib/ui/ai_queue_page.dart lib/ui/guards_page.dart lib/ui/onyx_route_operations_builders.dart test/ui/clients_page_widget_test.dart test/ui/guards_page_widget_test.dart test/ui/ai_queue_page_widget_test.dart`
- `dart analyze`

### Widget tests

Passed:

- `flutter test test/ui/clients_page_widget_test.dart test/ui/guards_page_widget_test.dart test/ui/ai_queue_page_widget_test.dart`

## Notes

- Tactical map data was not touched.
- The guards live-data path is now in place without changing tactical-map work or pending mapping decisions.
