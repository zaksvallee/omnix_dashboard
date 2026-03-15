# Site Identity Registry Supabase Contract

This first-pass contract supports the workflow we want for ONYX:

- controllers can manually maintain allowed / flagged people and vehicles
- clients can send visitor details through Telegram
- AI can parse free text into a proposed identity record
- ONYX can keep permanent allowlists separate from one-off approvals

App-side contract:

- [/Users/zaks/omnix_dashboard/lib/application/site_identity_registry_repository.dart](/Users/zaks/omnix_dashboard/lib/application/site_identity_registry_repository.dart)

## Tables

### `public.site_identity_profiles`

Source of truth for known identities at a site.

Key uses:

- permanent allowlisted residents, employees, and family members
- flagged people or vehicles
- temporary visitor / contractor approvals with expiry windows

Important columns:

- `client_id`
- `site_id`
- `identity_type` (`person` or `vehicle`)
- `category` (`employee`, `family`, `resident`, `visitor`, `contractor`, `delivery`, `unknown`)
- `status` (`allowed`, `flagged`, `pending`, `expired`)
- `display_name`
- `face_match_id`
- `plate_number`
- `valid_from`
- `valid_until`
- `external_reference`
- `notes`
- `metadata`

Repository behavior:

- list profiles by `client_id + site_id`
- upsert profiles for Admin/manual/Telegram-confirmed flows

Recommended usage:

- `approve once` creates or updates a temporary profile with `valid_until`
- `always allow` creates or updates a persistent `allowed` profile
- `flagged` creates or updates a persistent `flagged` profile

### `public.site_identity_approval_decisions`

Audit trail of every approval decision.

Key uses:

- remember how a person or vehicle got allowlisted
- distinguish `approve_once` from `approve_always`
- keep Telegram/client approvals separate from controller decisions

Important columns:

- `client_id`
- `site_id`
- `profile_id`
- `intelligence_id`
- `decision`
- `source`
- `decided_by`
- `decision_summary`
- `decided_at`
- `metadata`

Repository behavior:

- insert-only audit log

### `public.telegram_identity_intake`

Stores raw client Telegram intake plus AI-parsed proposal fields.

Key uses:

- keep original free text
- store parsed display name / plate / face token
- allow human review before permanent allowlisting

Important columns:

- `client_id`
- `site_id`
- `endpoint_id`
- `raw_text`
- `parsed_display_name`
- `parsed_face_match_id`
- `parsed_plate_number`
- `parsed_category`
- `valid_from`
- `valid_until`
- `ai_confidence`
- `approval_state`
- `metadata`

Repository behavior:

- insert-only intake log

## Migration

Apply:

- [/Users/zaks/omnix_dashboard/supabase/migrations/202603150001_create_site_identity_registry_tables.sql](/Users/zaks/omnix_dashboard/supabase/migrations/202603150001_create_site_identity_registry_tables.sql)

## Workflow Recommendation

1. ONYX detects a person or vehicle.
2. If it is not already matched to an allowed / flagged profile, ONYX may ask the client on Telegram.
3. Client chooses:
   - `ALLOW ONCE`
   - `ALWAYS ALLOW`
   - `REVIEW`
   - `ESCALATE`
4. ONYX records the decision in `site_identity_approval_decisions`.
5. If the client chose `ALWAYS ALLOW` and the event has a stable identity token such as `face_match_id` or `plate_number`, ONYX upserts `site_identity_profiles`.
6. If the client sends free-text visitor details first, ONYX writes `telegram_identity_intake`, AI parses the fields, and a controller/client can confirm the proposal into `site_identity_profiles`.

## Safety Note

Permanent memory should only be created when ONYX has a stable identity token:

- `face_match_id`
- `plate_number`
- or another confirmed vendor identity key

Without that, ONYX should prefer:

- temporary approval
- review
- or a pending proposal that requires human confirmation
