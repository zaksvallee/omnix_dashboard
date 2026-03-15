# Temporary Identity Approval Handoff (2026-03-15)

## Lane Status
- Extend and expire actions are already visible on the temporary identity focus banners in Tactical, Dispatch, and Admin.
- The live action plumbing for extend/expire is wired through the app state and page callbacks.
- The next implementation step is to add a confirmation dialog before the `Expire now` action executes.

## Resume Prompt
Continue temporary identity approval workflow from `omnix_dashboard`.

We just added `Extend 2h` / `Expire now` actions on Tactical, Dispatch, and Admin temporary-ID banners.

Next step: add confirm dialog for `Expire now`.

## Anchor Files
- Shared lane logic: [lib/ui/video_fleet_scope_health_sections.dart](/Users/zaks/omnix_dashboard/lib/ui/video_fleet_scope_health_sections.dart)
- Live action plumbing: [lib/main.dart](/Users/zaks/omnix_dashboard/lib/main.dart)
- Page wiring: [lib/ui/tactical_page.dart](/Users/zaks/omnix_dashboard/lib/ui/tactical_page.dart), [lib/ui/dispatch_page.dart](/Users/zaks/omnix_dashboard/lib/ui/dispatch_page.dart), [lib/ui/admin_page.dart](/Users/zaks/omnix_dashboard/lib/ui/admin_page.dart)

## Implementation Notes
- The current `Expire now` buttons invoke the callback immediately and then show a snackbar with the returned message.
- The confirmation dialog should be added in each page banner before calling `onExpireTemporaryIdentityApproval`.
- Keep the existing `Extend 2h` flow unchanged.
- After adding the dialog, update the widget tests that currently tap `Expire now` directly.

## Caution
- The working tree contains a much larger batch of unrelated monitoring/reporting changes.
- Avoid a broad "save progress" commit from the repo root unless you intentionally want to include that wider work.
